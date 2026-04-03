#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde_json::{json, Value};
use std::{
    collections::HashMap,
    fs,
    io::{BufRead, BufReader, Read, Write},
    path::{Path, PathBuf},
    process::{Child, ChildStdin, ChildStdout, Command, Stdio},
    sync::{
        atomic::{AtomicU64, Ordering},
        mpsc, Arc, Mutex,
    },
    thread,
    time::Duration,
};
use tauri::{Emitter, Manager, State};

const JSON_RPC_VERSION: &str = "2.0";
const PROTOCOL_VERSION: u64 = 1;
const NOTIFICATION_EVENT: &str = "app-server-notification";
const DISCONNECTED_EVENT: &str = "app-server-disconnected";
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

#[derive(Default)]
struct AppState {
    manager: Arc<SessionManager>,
}

#[derive(Default)]
struct SessionManager {
    current: Mutex<Option<Arc<Session>>>,
    next_session_id: AtomicU64,
}

struct Session {
    id: u64,
    child: Mutex<Child>,
    stdin: Mutex<ChildStdin>,
    pending: Mutex<HashMap<u64, mpsc::Sender<Result<Value, String>>>>,
    next_request_id: AtomicU64,
}

impl SessionManager {
    fn disconnect_current(&self) -> Result<(), String> {
        let current = self
            .current
            .lock()
            .map_err(|_| "failed to lock session manager".to_string())?
            .take();
        if let Some(session) = current {
            session.shutdown("session closed");
        }
        Ok(())
    }

    fn set_current(&self, session: Arc<Session>) -> Result<(), String> {
        let mut current = self
            .current
            .lock()
            .map_err(|_| "failed to lock session manager".to_string())?;
        *current = Some(session);
        Ok(())
    }

    fn current(&self) -> Result<Arc<Session>, String> {
        self.current
            .lock()
            .map_err(|_| "failed to lock session manager".to_string())?
            .clone()
            .ok_or_else(|| "not connected to app-server".to_string())
    }

    fn clear_if_current(&self, session_id: u64) -> Result<bool, String> {
        let mut current = self
            .current
            .lock()
            .map_err(|_| "failed to lock session manager".to_string())?;
        if current
            .as_ref()
            .map(|session| session.id == session_id)
            .unwrap_or(false)
        {
            *current = None;
            return Ok(true);
        }
        Ok(false)
    }

    fn next_session_id(&self) -> u64 {
        self.next_session_id.fetch_add(1, Ordering::SeqCst) + 1
    }
}

impl Session {
    fn request(&self, method: &str, params: Value) -> Result<Value, String> {
        let request_id = self.next_request_id.fetch_add(1, Ordering::SeqCst) + 1;
        let (tx, rx) = mpsc::channel();
        self.pending
            .lock()
            .map_err(|_| "failed to lock pending requests".to_string())?
            .insert(request_id, tx);

        let payload = json!({
            "jsonrpc": JSON_RPC_VERSION,
            "id": request_id,
            "method": method,
            "params": params,
        });
        let encoded =
            serde_json::to_vec(&payload).map_err(|error| format!("encode request: {error}"))?;

        if let Err(error) = self.write_frame(&encoded) {
            self.pending
                .lock()
                .map_err(|_| "failed to lock pending requests".to_string())?
                .remove(&request_id);
            return Err(error);
        }

        match rx.recv_timeout(REQUEST_TIMEOUT) {
            Ok(result) => result,
            Err(_) => {
                self.pending
                    .lock()
                    .map_err(|_| "failed to lock pending requests".to_string())?
                    .remove(&request_id);
                Err(format!("timed out waiting for {method} response"))
            }
        }
    }

    fn write_frame(&self, payload: &[u8]) -> Result<(), String> {
        let mut stdin = self
            .stdin
            .lock()
            .map_err(|_| "failed to lock app-server stdin".to_string())?;
        stdin
            .write_all(format!("Content-Length: {}\r\n\r\n", payload.len()).as_bytes())
            .map_err(|error| format!("write frame header: {error}"))?;
        stdin
            .write_all(payload)
            .map_err(|error| format!("write frame payload: {error}"))?;
        stdin
            .flush()
            .map_err(|error| format!("flush frame payload: {error}"))
    }

    fn reject_pending(&self, message: &str) {
        let pending = match self.pending.lock() {
            Ok(mut pending) => std::mem::take(&mut *pending),
            Err(_) => return,
        };
        for (_, sender) in pending {
            let _ = sender.send(Err(message.to_string()));
        }
    }

    fn shutdown(&self, reason: &str) {
        self.reject_pending(reason);
        if let Ok(mut child) = self.child.lock() {
            terminate_child(&mut child);
        }
    }
}

#[tauri::command]
fn app_server_connect(
    app: tauri::AppHandle,
    state: State<'_, AppState>,
) -> Result<Value, String> {
    state.manager.disconnect_current()?;

    let cli_path = resolve_cli_binary();
    let mut child = Command::new(&cli_path)
        .arg("app-server")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| format!("failed to spawn {cli_path}: {error}"))?;

    let stdin = child
        .stdin
        .take()
        .ok_or_else(|| "failed to capture app-server stdin".to_string())?;
    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| "failed to capture app-server stdout".to_string())?;
    let stderr = child
        .stderr
        .take()
        .ok_or_else(|| "failed to capture app-server stderr".to_string())?;

    let session = Arc::new(Session {
        id: state.manager.next_session_id(),
        child: Mutex::new(child),
        stdin: Mutex::new(stdin),
        pending: Mutex::new(HashMap::new()),
        next_request_id: AtomicU64::new(0),
    });

    state.manager.set_current(session.clone())?;
    spawn_reader_thread(app.clone(), state.manager.clone(), session.clone(), stdout);
    spawn_stderr_thread(session.id, stderr);

    let initialize = session.request(
        "initialize",
        json!({
            "client_name": "muxagent-desktop-tauri",
            "client_version": env!("CARGO_PKG_VERSION"),
            "protocol_version": PROTOCOL_VERSION,
        }),
    );

    if initialize.is_err() {
        let _ = state.manager.clear_if_current(session.id);
        session.shutdown("initialize failed");
    }

    initialize
}

#[tauri::command]
fn app_server_disconnect(state: State<'_, AppState>) -> Result<(), String> {
    state.manager.disconnect_current()
}

#[tauri::command]
fn app_server_request(
    state: State<'_, AppState>,
    method: String,
    params: Option<Value>,
) -> Result<Value, String> {
    let session = state.manager.current()?;
    session.request(&method, params.unwrap_or(Value::Object(Default::default())))
}

#[tauri::command]
fn read_text_file(state: State<'_, AppState>, path: String) -> Result<String, String> {
    let _session = state.manager.current()?;
    let requested = resolve_absolute_path(&path)?;
    fs::read_to_string(&requested).map_err(|error| format!("read file: {error}"))
}

#[tauri::command]
fn open_path(state: State<'_, AppState>, path: String) -> Result<(), String> {
    let _session = state.manager.current()?;
    let requested = resolve_absolute_path(&path)?;
    open_path_on_host(&requested)
}

fn resolve_cli_binary() -> String {
    std::env::var("MUXAGENT_CLI_PATH")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "muxagent".to_string())
}

fn spawn_stderr_thread(session_id: u64, stderr: impl Read + Send + 'static) {
    thread::spawn(move || {
        let mut reader = BufReader::new(stderr);
        let mut line = String::new();
        loop {
            line.clear();
            match reader.read_line(&mut line) {
                Ok(0) => break,
                Ok(_) => eprint!("[muxagent app-server:{session_id}] {line}"),
                Err(error) => {
                    eprintln!("[muxagent app-server:{session_id}] stderr read failed: {error}");
                    break;
                }
            }
        }
    });
}

fn spawn_reader_thread(
    app: tauri::AppHandle,
    manager: Arc<SessionManager>,
    session: Arc<Session>,
    stdout: ChildStdout,
) {
    thread::spawn(move || {
        let mut reader = BufReader::new(stdout);
        let reason = loop {
            match read_frame(&mut reader) {
                Ok(Some(frame)) => match handle_frame(&app, &session, &frame) {
                    Ok(()) => continue,
                    Err(error) => break error,
                },
                Ok(None) => break "app-server stdout closed".to_string(),
                Err(error) => break error,
            }
        };

        session.reject_pending(&reason);
        if manager.clear_if_current(session.id).unwrap_or(false) {
            let _ = app.emit(DISCONNECTED_EVENT, json!({ "message": reason }));
        }
        if let Ok(mut child) = session.child.lock() {
            terminate_child(&mut child);
        }
    });
}

fn resolve_absolute_path(path: &str) -> Result<PathBuf, String> {
    let requested = PathBuf::from(path);
    if !requested.is_absolute() {
        return Err("path must be absolute".to_string());
    }
    fs::canonicalize(requested).map_err(|error| format!("resolve path: {error}"))
}

fn handle_frame(app: &tauri::AppHandle, session: &Session, frame: &[u8]) -> Result<(), String> {
    let message: Value = serde_json::from_slice(frame)
        .map_err(|error| format!("decode app-server frame: {error}"))?;

    if let Some(method) = message
        .get("method")
        .and_then(Value::as_str)
        .map(str::to_owned)
    {
        if message.get("id").is_none() {
            app.emit(NOTIFICATION_EVENT, message)
                .map_err(|error| format!("emit notification {method}: {error}"))?;
            return Ok(());
        }
    }

    if let Some(id) = message.get("id").and_then(Value::as_u64) {
        let sender = session
            .pending
            .lock()
            .map_err(|_| "failed to lock pending requests".to_string())?
            .remove(&id);
        if let Some(sender) = sender {
            if let Some(error) = message.get("error") {
                let error_message = error
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("app-server request failed")
                    .to_string();
                let _ = sender.send(Err(error_message));
            } else if let Some(result) = message.get("result") {
                let _ = sender.send(Ok(result.clone()));
            } else {
                let _ = sender.send(Err("RPC response missing result".to_string()));
            }
        }
    }

    Ok(())
}

fn read_frame(reader: &mut BufReader<ChildStdout>) -> Result<Option<Vec<u8>>, String> {
    let mut content_length: Option<usize> = None;

    loop {
        let mut line = String::new();
        let bytes = reader
            .read_line(&mut line)
            .map_err(|error| format!("read frame header: {error}"))?;
        if bytes == 0 {
            if content_length.is_none() {
                return Ok(None);
            }
            return Err("unexpected EOF while reading frame header".to_string());
        }

        if line == "\r\n" || line == "\n" {
            break;
        }

        let trimmed = line.trim_end_matches(['\r', '\n']);
        if trimmed.is_empty() {
            break;
        }

        let (name, value) = trimmed
            .split_once(':')
            .ok_or_else(|| format!("invalid frame header: {trimmed}"))?;
        if name.trim().eq_ignore_ascii_case("Content-Length") {
            content_length = Some(
                value
                    .trim()
                    .parse::<usize>()
                    .map_err(|error| format!("invalid Content-Length header: {error}"))?,
            );
        }
    }

    let length = content_length.ok_or_else(|| "missing Content-Length header".to_string())?;
    let mut payload = vec![0; length];
    reader
        .read_exact(&mut payload)
        .map_err(|error| format!("read frame payload: {error}"))?;
    Ok(Some(payload))
}

fn open_path_on_host(path: &Path) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        let status = Command::new("open")
            .arg(path)
            .status()
            .map_err(|error| format!("open path: {error}"))?;
        if status.success() {
            return Ok(());
        }
        return Err(format!("open path failed with status {status}"));
    }

    #[cfg(target_os = "windows")]
    {
        let status = Command::new("cmd")
            .args(["/C", "start", "", &path.display().to_string()])
            .status()
            .map_err(|error| format!("open path: {error}"))?;
        if status.success() {
            return Ok(());
        }
        return Err(format!("open path failed with status {status}"));
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        let status = Command::new("xdg-open")
            .arg(path)
            .status()
            .map_err(|error| format!("open path: {error}"))?;
        if status.success() {
            return Ok(());
        }
        return Err(format!("open path failed with status {status}"));
    }
}

fn terminate_child(child: &mut Child) {
    if let Ok(None) = child.try_wait() {
        let _ = child.kill();
    }
    let _ = child.wait();
}

fn main() {
    let app = tauri::Builder::default()
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            app_server_connect,
            app_server_disconnect,
            app_server_request,
            read_text_file,
            open_path
        ])
        .build(tauri::generate_context!())
        .expect("failed to build tauri application");

    let manager = app.state::<AppState>().manager.clone();
    app.run(move |_app_handle, event| {
        if matches!(event, tauri::RunEvent::ExitRequested { .. }) {
            let _ = manager.disconnect_current();
        }
    });
}
