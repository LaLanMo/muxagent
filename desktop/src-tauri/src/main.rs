#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use rfd::FileDialog;
use serde::Deserialize;
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    fs,
    io::{BufRead, BufReader, Read, Write},
    net::{Shutdown, TcpStream},
    path::{Path, PathBuf},
    process::Command,
    sync::{
        atomic::{AtomicU64, Ordering},
        mpsc, Arc, Mutex,
    },
    thread,
    time::Duration,
};
use tauri::{
    menu::{IsMenuItem, MenuItem, Submenu},
    Emitter, Manager, State,
};

const JSON_RPC_VERSION: &str = "2.0";
const PROTOCOL_VERSION: u64 = 1;
const NOTIFICATION_EVENT: &str = "app-server-notification";
const DISCONNECTED_EVENT: &str = "app-server-disconnected";
const NATIVE_CONTEXT_MENU_ACTION_EVENT: &str = "native-context-menu-action";
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

#[derive(Default)]
struct AppState {
    manager: Arc<SessionManager>,
    pending_context_menus: Mutex<Vec<PendingContextMenu>>,
}

struct PendingContextMenu {
    window_label: String,
    item_ids: Vec<String>,
    _submenu: Submenu<tauri::Wry>,
    _items: Vec<MenuItem<tauri::Wry>>,
}

#[derive(Default)]
struct SessionManager {
    current: Mutex<Option<Arc<Session>>>,
    next_session_id: AtomicU64,
}

#[derive(Debug, Deserialize)]
struct AppServerEnsureResult {
    address: String,
    token: String,
    instance_id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ContextMenuItemPayload {
    id: String,
    label: String,
}

struct Session {
    id: u64,
    stream: Mutex<TcpStream>,
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
        let mut stream = self
            .stream
            .lock()
            .map_err(|_| "failed to lock app-server stream".to_string())?;
        stream
            .write_all(format!("Content-Length: {}\r\n\r\n", payload.len()).as_bytes())
            .map_err(|error| format!("write frame header: {error}"))?;
        stream
            .write_all(payload)
            .map_err(|error| format!("write frame payload: {error}"))?;
        stream
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
        if let Ok(stream) = self.stream.lock() {
            let _ = stream.shutdown(Shutdown::Both);
        }
    }
}

#[tauri::command]
fn app_server_connect(app: tauri::AppHandle, state: State<'_, AppState>) -> Result<Value, String> {
    state.manager.disconnect_current()?;

    let cli_path = resolve_cli_binary();
    let ensured = ensure_app_server_daemon(&cli_path)?;

    let stream = TcpStream::connect(&ensured.address)
        .map_err(|error| format!("connect app-server daemon {}: {error}", ensured.address))?;
    stream
        .set_nodelay(true)
        .map_err(|error| format!("configure app-server daemon stream: {error}"))?;
    let reader_stream = stream
        .try_clone()
        .map_err(|error| format!("clone app-server daemon stream: {error}"))?;

    let session = Arc::new(Session {
        id: state.manager.next_session_id(),
        stream: Mutex::new(stream),
        pending: Mutex::new(HashMap::new()),
        next_request_id: AtomicU64::new(0),
    });

    state.manager.set_current(session.clone())?;
    spawn_reader_thread(
        app.clone(),
        state.manager.clone(),
        session.clone(),
        reader_stream,
    );

    let initialize = session.request(
        "initialize",
        json!({
            "client_name": "muxagent-desktop-tauri",
            "client_version": env!("CARGO_PKG_VERSION"),
            "protocol_version": PROTOCOL_VERSION,
            "auth_token": ensured.token,
        }),
    );

    let initialize = match initialize {
        Ok(result) => {
            verify_instance_id(&result, &ensured.instance_id)?;
            Ok(result)
        }
        Err(error) => {
            eprintln!("app_server_connect initialize failed: {error}");
            Err(error)
        }
    };

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
    match session.request(&method, params.unwrap_or(Value::Object(Default::default()))) {
        Ok(result) => Ok(result),
        Err(error) => {
            eprintln!("app_server_request {method} failed: {error}");
            Err(error)
        }
    }
}

#[tauri::command]
fn read_text_file(state: State<'_, AppState>, path: String) -> Result<String, String> {
    let _session = state.manager.current()?;
    let requested = resolve_absolute_path(&path)?;
    fs::read_to_string(&requested).map_err(|error| format!("read file: {error}"))
}

fn describe_inline_preview_limit(max_bytes: u64) -> String {
    let megabytes = max_bytes as f64 / (1024.0 * 1024.0);
    if (megabytes - megabytes.round()).abs() < f64::EPSILON {
        return format!("{} MB", megabytes.round() as u64);
    }
    format!("{megabytes:.1} MB")
}

#[tauri::command]
fn read_binary_file(
    state: State<'_, AppState>,
    path: String,
    max_bytes: u64,
) -> Result<Vec<u8>, String> {
    if max_bytes == 0 {
        return Err("maxBytes must be a positive integer".to_string());
    }
    let _session = state.manager.current()?;
    let requested = resolve_absolute_path(&path)?;
    let metadata = fs::metadata(&requested).map_err(|error| format!("read file metadata: {error}"))?;
    if metadata.len() > max_bytes {
        return Err(format!(
            "Artifact preview exceeds the {} inline limit. Open externally to inspect the full file.",
            describe_inline_preview_limit(max_bytes)
        ));
    }
    fs::read(&requested).map_err(|error| format!("read file: {error}"))
}

#[tauri::command]
fn open_path(state: State<'_, AppState>, path: String) -> Result<(), String> {
    let _session = state.manager.current()?;
    let requested = resolve_absolute_path(&path)?;
    open_path_on_host(&requested)
}

#[tauri::command]
fn pick_directory() -> Result<Option<String>, String> {
    Ok(FileDialog::new()
        .pick_folder()
        .map(|path| path.to_string_lossy().to_string()))
}

#[tauri::command]
fn show_context_menu(
    window: tauri::WebviewWindow,
    state: State<'_, AppState>,
    x: f64,
    y: f64,
    items: Vec<ContextMenuItemPayload>,
) -> Result<(), String> {
    if items.is_empty() {
        return Ok(());
    }

    let built_items = items
        .iter()
        .map(|item| {
            MenuItem::with_id(&window, item.id.clone(), item.label.clone(), true, None::<&str>)
                .map_err(|error| format!("create context menu item: {error}"))
        })
        .collect::<Result<Vec<_>, _>>()?;

    let item_refs = built_items
        .iter()
        .map(|item| item as &dyn IsMenuItem<tauri::Wry>)
        .collect::<Vec<_>>();

    let submenu = Submenu::with_id_and_items(
        &window,
        format!("context-menu-{}", items[0].id),
        "Context",
        true,
        &item_refs,
    )
    .map_err(|error| format!("create context submenu: {error}"))?;

    {
        let mut pending = state
            .pending_context_menus
            .lock()
            .map_err(|_| "failed to lock context menu state".to_string())?;
        pending.retain(|entry| entry.window_label != window.label());
        pending.push(PendingContextMenu {
            window_label: window.label().to_string(),
            item_ids: items.iter().map(|item| item.id.clone()).collect(),
            _submenu: submenu.clone(),
            _items: built_items.clone(),
        });
    }

    window
        .popup_menu_at(&submenu, tauri::LogicalPosition::new(x, y))
        .map_err(|error| format!("popup native context menu: {error}"))
}

fn resolve_cli_binary() -> String {
    std::env::var("MUXAGENT_CLI_PATH")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "muxagent".to_string())
}

fn resolve_app_server_state_dir() -> Option<String> {
    std::env::var("MUXAGENT_APP_SERVER_STATE_DIR")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn ensure_app_server_daemon(cli_path: &str) -> Result<AppServerEnsureResult, String> {
    let mut command = Command::new(cli_path);
    command.arg("app-server").arg("ensure");
    if let Some(state_dir) = resolve_app_server_state_dir() {
        command.arg("--state-dir").arg(state_dir);
    }

    let output = command
        .output()
        .map_err(|error| format!("run `{cli_path} app-server ensure`: {error}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let detail = if !stderr.is_empty() {
            stderr
        } else if !stdout.is_empty() {
            stdout
        } else {
            format!("exit status {}", output.status)
        };
        return Err(format!("app-server ensure failed: {detail}"));
    }

    serde_json::from_slice::<AppServerEnsureResult>(&output.stdout)
        .map_err(|error| format!("decode app-server ensure output: {error}"))
}

fn verify_instance_id(initialize_result: &Value, expected_instance_id: &str) -> Result<(), String> {
    let actual = initialize_result
        .get("instance_id")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if actual == expected_instance_id {
        return Ok(());
    }
    Err(format!(
        "app-server instance mismatch: expected {}, got {}",
        expected_instance_id, actual
    ))
}

fn spawn_reader_thread(
    app: tauri::AppHandle,
    manager: Arc<SessionManager>,
    session: Arc<Session>,
    stream: TcpStream,
) {
    thread::spawn(move || {
        let mut reader = BufReader::new(stream);
        let reason = loop {
            match read_frame(&mut reader) {
                Ok(Some(frame)) => match handle_frame(&app, &session, &frame) {
                    Ok(()) => continue,
                    Err(error) => break error,
                },
                Ok(None) => break "app-server connection closed".to_string(),
                Err(error) => break error,
            }
        };

        session.reject_pending(&reason);
        eprintln!("app-server reader thread disconnected: {reason}");
        if manager.clear_if_current(session.id).unwrap_or(false) {
            let _ = app.emit(DISCONNECTED_EVENT, json!({ "message": reason }));
        }
        session.shutdown(&reason);
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

fn read_frame<R: Read>(reader: &mut BufReader<R>) -> Result<Option<Vec<u8>>, String> {
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

fn main() {
    let app = tauri::Builder::default()
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            app_server_connect,
            app_server_disconnect,
            app_server_request,
            pick_directory,
            read_text_file,
            read_binary_file,
            open_path,
            show_context_menu
        ])
        .build(tauri::generate_context!())
        .expect("failed to build tauri application");

    let manager = app.state::<AppState>().manager.clone();
    app.run(move |app_handle, event| {
        match event {
            tauri::RunEvent::ExitRequested { .. } => {
                let _ = manager.disconnect_current();
            }
            tauri::RunEvent::MenuEvent(menu_event) => {
                let menu_id = menu_event.id().0.clone();
                if let Ok(mut pending) = app_handle
                    .state::<AppState>()
                    .pending_context_menus
                    .lock()
                {
                    if let Some(index) = pending
                        .iter()
                        .position(|entry| entry.item_ids.iter().any(|item_id| item_id == &menu_id))
                    {
                        let entry = pending.remove(index);
                        if let Some(window) = app_handle.get_webview_window(&entry.window_label) {
                            let _ = window.emit(
                                NATIVE_CONTEXT_MENU_ACTION_EVENT,
                                json!({ "itemId": menu_id }),
                            );
                        }
                    }
                }
            }
            _ => {}
        }
    });
}
