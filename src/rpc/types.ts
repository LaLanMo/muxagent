export const JSON_RPC_VERSION = "2.0";
export const PROTOCOL_VERSION = 1;

export type JsonRpcId = number;

export interface JsonRpcRequest<TParams = unknown> {
  jsonrpc: typeof JSON_RPC_VERSION;
  id: JsonRpcId;
  method: string;
  params?: TParams;
}

export interface JsonRpcSuccess<TResult = unknown> {
  jsonrpc: typeof JSON_RPC_VERSION;
  id: JsonRpcId;
  result: TResult;
}

export interface JsonRpcFailure {
  jsonrpc: typeof JSON_RPC_VERSION;
  id: JsonRpcId | null;
  error: {
    code: number;
    message: string;
  };
}

export interface JsonRpcNotification<TParams = unknown> {
  jsonrpc: typeof JSON_RPC_VERSION;
  method: string;
  params?: TParams;
}

export type JsonRpcMessage =
  | JsonRpcSuccess
  | JsonRpcFailure
  | JsonRpcNotification;

export interface ServerCapabilitiesDto {
  methods: string[];
  notifications: string[];
}

export interface InitializeResult {
  protocol_version: number;
  server_name: string;
  server_version: string;
  capabilities: ServerCapabilitiesDto;
}

export interface ServiceStatusResult {
  state_dir: string;
  server_version: string;
  protocol_version: number;
  workspace_count: number;
  runtime_count: number;
  connected_clients: number;
}

export interface TaskCountsDto {
  running: number;
  awaiting: number;
  done: number;
  failed: number;
}

export interface WorkspaceActorDto {
  state: string;
  last_error?: string;
}

export interface WorkspaceSummaryDto {
  workspace_id: string;
  path: string;
  display_name: string;
  source: string;
  reachable: boolean;
  worktree_available: boolean;
  added_at: string;
  last_opened_at?: string;
  task_counts: TaskCountsDto;
  actor: WorkspaceActorDto;
}

export interface WorkspaceListResult {
  workspaces: WorkspaceSummaryDto[];
}

export interface WorkspaceGetResult {
  workspace: WorkspaceSummaryDto;
}

export interface WorkspaceAddParams {
  path: string;
  display_name?: string;
}

export interface WorkspaceAddResult {
  workspace: WorkspaceSummaryDto;
}

export interface WorkspaceUpdateParams {
  workspace_id: string;
  display_name?: string;
}

export interface WorkspaceUpdateResult {
  workspace: WorkspaceSummaryDto;
}

export interface WorkspaceRemoveParams {
  workspace_id: string;
}

export interface WorkspaceRemoveResult {
  removed: boolean;
}

export interface ConfigCatalogEntryDto {
  alias: string;
  bundle_path?: string;
  config_path: string;
  is_default: boolean;
  runtime_id?: string;
  runtime_name?: string;
  runtime_explicit: boolean;
  runtime_configured: boolean;
  node_names?: string[];
  load_error?: string;
  builtin_id?: string;
  builtin: boolean;
  description?: string;
  launchable: boolean;
}

export interface ConfigCatalogResult {
  default_alias: string;
  default_use_worktree: boolean;
  entries: ConfigCatalogEntryDto[];
}

export interface ConfigDraftDto {
  version: number;
  description?: string;
  runtime?: string;
  clarification: {
    max_questions: number;
    max_options_per_question: number;
    min_options_per_question: number;
  };
  topology: {
    max_iterations: number;
    entry: string;
    nodes: Array<{
      name: string;
      max_iterations?: number;
      join?: string;
    }>;
    edges: Array<{
      from: string;
      to: string;
      when?: {
        kind?: string;
        field?: string;
        equals?: unknown;
      };
    }>;
  };
  node_definitions: Record<
    string,
    {
      type?: string;
      system_prompt?: string;
      max_clarification_rounds?: number;
      result_schema: Record<string, unknown>;
    }
  >;
}

export interface ConfigDetailDto {
  alias: string;
  bundle_path?: string;
  config_path: string;
  is_default: boolean;
  builtin_id?: string;
  builtin: boolean;
  revision?: string;
  runtime_id?: string;
  runtime_name?: string;
  runtime_explicit: boolean;
  runtime_configured: boolean;
  description?: string;
  node_names?: string[];
  load_error?: string;
  launchable: boolean;
  config?: ConfigDraftDto;
}

export interface ConfigGetParams {
  alias: string;
}

export interface ConfigGetResult {
  entry: ConfigDetailDto;
}

export interface ConfigCloneParams {
  source_alias: string;
  new_alias: string;
}

export interface ConfigCloneResult {
  entry: ConfigDetailDto;
}

export interface ConfigRenameParams {
  alias: string;
  new_alias: string;
}

export interface ConfigRenameResult {
  entry: ConfigDetailDto;
}

export interface ConfigDeleteParams {
  alias: string;
}

export interface ConfigDeleteResult {
  removed: boolean;
}

export interface ConfigResetParams {
  alias: string;
}

export interface ConfigResetResult {
  entry: ConfigDetailDto;
}

export interface ConfigSetDefaultParams {
  alias: string;
}

export interface ConfigSetDefaultResult {
  entry: ConfigDetailDto;
}

export interface ConfigValidateParams {
  config: ConfigDraftDto;
}

export interface ConfigValidateResult {
  valid: boolean;
  config?: ConfigDraftDto;
  runtime_id?: string;
  runtime_name?: string;
  runtime_configured: boolean;
  error?: string;
}

export interface ConfigSaveParams {
  alias: string;
  expected_revision: string;
  config: ConfigDraftDto;
}

export interface ConfigSaveResult {
  entry: ConfigDetailDto;
}

export interface ConfigPromptDto {
  alias: string;
  node_name: string;
  node_type: string;
  path: string;
  resolved_path: string;
  content: string;
  revision?: string;
  readonly: boolean;
  builtin: boolean;
}

export interface ConfigPromptGetParams {
  alias: string;
  node_name: string;
}

export interface ConfigPromptGetResult {
  prompt: ConfigPromptDto;
}

export interface ConfigPromptSaveParams {
  alias: string;
  node_name: string;
  expected_revision?: string;
  content: string;
}

export interface ConfigPromptSaveResult {
  prompt: ConfigPromptDto;
}

export interface RuntimeEntryDto {
  runtime_id: string;
  runtime_name: string;
  command?: string;
  args?: string[];
  cwd?: string;
  env_keys?: string[];
}

export interface RuntimeListResult {
  runtimes: RuntimeEntryDto[];
}

export interface TaskDto {
  id: string;
  description: string;
  config_alias: string;
  config_path: string;
  work_dir: string;
  execution_dir: string;
  created_at: string;
  updated_at: string;
  parent_task_id?: string;
  parent_task_description?: string;
}

export interface TriggeredByDto {
  node_run_id: string;
  reason: string;
}

export interface TaskIssueDto {
  kind: string;
  node_name: string;
  iteration: number;
  reason: string;
  occurred_at: string;
}

export interface NodeRunViewDto {
  id: string;
  task_id: string;
  node_name: string;
  status: string;
  session_id?: string;
  failure_reason?: string;
  result?: Record<string, unknown>;
  clarifications?: Array<Record<string, unknown>>;
  triggered_by?: TriggeredByDto;
  started_at: string;
  completed_at?: string;
  artifact_paths?: string[];
}

export interface BlockedStepDto {
  node_name: string;
  iteration: number;
  reason: string;
  triggered_by?: TriggeredByDto;
  created_at: string;
}

export interface TaskViewDto {
  task: TaskDto;
  status: string;
  current_node_name: string;
  current_node_type: string;
  current_issue?: TaskIssueDto;
  artifact_paths?: string[];
  node_runs?: NodeRunViewDto[];
  blocked_steps?: BlockedStepDto[];
}

export interface InputQuestionOptionDto {
  label: string;
  description?: string;
}

export interface InputQuestionDto {
  question: string;
  why_it_matters?: string;
  options?: InputQuestionOptionDto[];
  multi_select?: boolean;
}

export interface InputRequestDto {
  kind: string;
  task_id: string;
  node_run_id: string;
  node_name: string;
  schema?: Record<string, unknown>;
  artifact_paths?: string[];
  questions?: InputQuestionDto[];
}

export interface ConfigViewDto {
  path: string;
  config?: Record<string, unknown>;
}

export interface TaskListResult {
  tasks: TaskViewDto[];
}

export interface TaskGetResult {
  task: TaskViewDto;
  config?: ConfigViewDto;
  input_request?: InputRequestDto;
  live_output?: string[];
  live_output_run_id?: string;
}

export interface TaskInputRequestResult {
  input_request?: InputRequestDto;
}

export interface RunHistoryChunkDto {
  recorded_at: string;
  progress: ProgressInfoDto;
}

export interface TaskRunHistoryResult {
  task_id: string;
  node_run_id: string;
  session_id?: string;
  source: string;
  complete: boolean;
  history?: RunHistoryChunkDto[];
}

export interface ArtifactRefDto {
  task_id: string;
  node_run_id?: string;
  node_name?: string;
  source_label?: string;
  raw_path: string;
  resolved_path: string;
  display_path: string;
  preview_name: string;
  preview_title: string;
  markdown: boolean;
}

export interface ArtifactListResult {
  artifacts: ArtifactRefDto[];
}

export interface CommandAcceptedResult {
  accepted: boolean;
  client_command_id?: string;
}

export interface TaskStartParams {
  workspace_id: string;
  client_command_id?: string;
  description: string;
  config_alias: string;
  config_path: string;
  use_worktree?: boolean;
}

export interface TaskStartFollowUpParams {
  workspace_id: string;
  client_command_id?: string;
  parent_task_id: string;
  description: string;
  config_alias?: string;
  config_path?: string;
}

export interface TaskSubmitInputParams {
  workspace_id: string;
  client_command_id?: string;
  task_id: string;
  node_run_id: string;
  payload?: Record<string, unknown>;
}

export interface TaskRetryNodeParams {
  workspace_id: string;
  client_command_id?: string;
  task_id: string;
  node_run_id: string;
  force?: boolean;
}

export interface TaskContinueBlockedParams {
  workspace_id: string;
  client_command_id?: string;
  task_id: string;
}

export interface StreamEventDto {
  kind: string;
  session_id?: string;
  raw?: string;
  message?: Record<string, unknown>;
  tool?: Record<string, unknown>;
  plan?: Record<string, unknown>;
  usage?: Record<string, unknown>;
}

export interface ProgressInfoDto {
  message?: string;
  session_id?: string;
  events?: StreamEventDto[];
}

export interface RunEventDto {
  type: string;
  task_id?: string;
  node_run_id?: string;
  node_name?: string;
  task_view?: TaskViewDto;
  config?: Record<string, unknown>;
  progress?: ProgressInfoDto;
  input_request?: InputRequestDto;
  error?: {
    message: string;
  };
}

export interface TaskNotificationPayload {
  client_command_id?: string;
  event: RunEventDto;
}

export interface WorkspaceNotificationPayload {
  workspace: WorkspaceSummaryDto;
}

export interface WorkspaceRemovedPayload {
  removed: boolean;
}

export interface NotificationEnvelopeParams {
  event_id: string;
  at: string;
  kind: string;
  workspace_id?: string;
  payload?: unknown;
}
