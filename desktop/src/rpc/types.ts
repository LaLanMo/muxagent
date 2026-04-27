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

export interface RuntimeStatusAutomaticDto {
  runtime_id: string;
  runtime_name: string;
  launcher?: string;
  available: boolean;
  detected: boolean;
}

export interface RuntimeStatusEntryDto {
  runtime_id: string;
  runtime_name: string;
  launcher?: string;
  available: boolean;
}

export interface RuntimeStatusResult {
  automatic: RuntimeStatusAutomaticDto;
  runtimes: RuntimeStatusEntryDto[];
}

export interface AgentChatSessionConfigValueDto {
  value: string;
  name: string;
  description?: string;
}

export interface AgentChatSessionConfigGroupDto {
  group: string;
  name: string;
  options: AgentChatSessionConfigValueDto[];
}

export type AgentChatSessionConfigOptionEntryDto =
  | AgentChatSessionConfigValueDto
  | AgentChatSessionConfigGroupDto;

export type AgentChatSessionConfigOptionsDto =
  | AgentChatSessionConfigValueDto[]
  | AgentChatSessionConfigGroupDto[];

export interface AgentChatSessionConfigOptionDto {
  id: string;
  name: string;
  description?: string;
  category?: string;
  type: "select" | string;
  currentValue: string;
  options: AgentChatSessionConfigOptionsDto;
}

export interface AgentChatRuntimeDto {
  id: string;
  label: string;
  ready: boolean;
  configOptions?: AgentChatSessionConfigOptionDto[];
}

export interface AgentChatRuntimeListResult {
  runtimes: AgentChatRuntimeDto[];
}

export type AgentChatSessionStatusDto =
  | "idle"
  | "running"
  | "waiting_approval"
  | "error"
  | "done";

export interface AgentChatSessionDto {
  sessionId: string;
  cwd: string;
  title: string;
  runtime?: string;
  updatedAt: string;
  status: AgentChatSessionStatusDto;
  configOptions?: AgentChatSessionConfigOptionDto[];
}

export interface AgentChatSessionListResult {
  sessions: AgentChatSessionDto[];
}

export interface AgentChatListSessionsParams {
  runtime?: string;
  limit?: number;
}

export interface AgentChatCreateSessionParams {
  cwd: string;
  runtime: string;
  permissionMode?: string;
  useWorktree?: boolean;
}

export interface AgentChatSessionCreateResult {
  app: {
    sessionId: string;
    runtime: string;
    cwd: string;
    title: string;
    status: AgentChatSessionStatusDto;
    updatedAt: string;
  };
  acp: {
    sessionId: string;
    models?: unknown;
    modes?: unknown;
    configOptions?: AgentChatSessionConfigOptionDto[];
  };
}

export interface AgentChatLoadSessionParams {
  sessionId: string;
  cwd: string;
  runtime: string;
  permissionMode?: string;
  model?: string;
}

export interface AgentChatSessionLoadReplayDto {
  events: AgentChatEventDto[];
  complete: boolean;
}

export interface AgentChatSessionLoadResult {
  app: {
    ok: boolean;
    sessionId: string;
    runtime: string;
    cwd: string;
    title?: string;
    status?: AgentChatSessionStatusDto;
    updatedAt?: string;
    replay: AgentChatSessionLoadReplayDto;
  };
  acp: {
    models?: unknown;
    modes?: unknown;
    configOptions?: AgentChatSessionConfigOptionDto[];
  };
}

export interface AgentChatPromptParams {
  sessionId: string;
  text?: string;
  content?: Array<{
    type: string;
    text?: string;
    mimeType?: string;
    data?: string;
    uri?: string;
  }>;
}

export interface AgentChatCancelParams {
  sessionId: string;
}

export interface AgentChatSetModeParams {
  sessionId: string;
  permissionMode: string;
}

export interface AgentChatSetConfigOptionParams {
  sessionId: string;
  configId: string;
  value: string;
}

export interface AgentChatAcceptedResult {
  accepted: boolean;
}

export interface AgentChatOkResult {
  ok: boolean;
}

export interface AgentChatReplayHeadResult {
  streamEpoch: number;
  replayedThroughSeq: number;
}

export interface AgentChatMessagePartEventDto {
  app: {
    partId: string;
    messageId: string;
    role?: "user" | "agent" | string;
    delta: string;
    partType: string;
    fullText: string;
  };
  acp?: unknown;
}

export interface AgentChatToolEventDto {
  app: {
    partId: string;
    messageId: string;
    callId: string;
    name: string;
    kind?: string;
    title?: string;
    status: string;
    input?: unknown;
    inputTruncated?: boolean;
    output?: string;
    outputTruncated?: boolean;
    error?: string;
    errorTruncated?: boolean;
    diffs?: Array<{
      path: string;
      oldText?: string | null;
      newText: string;
    }>;
    diffsTruncated?: boolean;
    claudeCode?: unknown;
    locations?: Array<{
      path: string;
      line?: number;
    }>;
  };
  acp?: unknown;
}

export interface AgentChatSessionStatusEventDto {
  app: {
    id: string;
    title?: string;
    status: AgentChatSessionStatusDto;
    model?: string;
    cost?: {
      costAmount?: number;
      costCurrency?: string;
      totalTokens?: number;
    };
    machineId?: string;
    runtime?: string;
    cwd?: string;
    mode?: string;
    createdAt?: string;
    updatedAt?: string;
  };
}

export interface AgentChatRunFailedEventDto {
  app: {
    error: {
      code?: string;
      message: string;
    };
  };
}

export interface AgentChatRunFinishedEventDto {
  app: {
    stopReason?: string;
    inputTokens?: number;
    outputTokens?: number;
    totalTokens?: number;
  };
}

export interface AgentChatModeChangedEventDto {
  app: {
    currentModeId: string;
  };
  acp?: unknown;
}

export interface AgentChatConfigChangedEventDto {
  app: {
    configId: string;
    currentValue: string;
    category?: string;
    values?: AgentChatSessionConfigValueDto[];
  };
  acp?: unknown;
}

export interface AgentChatEventDto {
  type: string;
  sessionId?: string;
  seq?: number;
  at?: string;
  messagePart?: AgentChatMessagePartEventDto;
  tool?: AgentChatToolEventDto;
  sessionStatus?: AgentChatSessionStatusEventDto;
  runFailed?: AgentChatRunFailedEventDto;
  runFinished?: AgentChatRunFinishedEventDto;
  approval?: unknown;
  plan?: unknown;
  usage?: unknown;
  modeChanged?: AgentChatModeChangedEventDto;
  configChanged?: AgentChatConfigChangedEventDto;
}

export type AgentChatStreamItemDto =
  | {
      kind: "event";
      streamEpoch: number;
      event: AgentChatEventDto;
    }
  | {
      kind: "replay";
      status: "ok" | "gap" | "reset";
      streamEpoch: number;
      replayedThroughSeq: number;
      events: AgentChatEventDto[];
    };

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

export type GitCheckoutRoleDto = "main" | "muxagent_managed" | "external";
export type GitFileBucketDto =
  | "staged"
  | "unstaged"
  | "untracked"
  | "conflicted";

export interface GitCommitDto {
  short_hash: string;
  subject: string;
  authored_at?: string;
}

export interface GitFileChangeDto {
  path: string;
  orig_path?: string;
  xy: string;
  bucket: GitFileBucketDto;
}

export interface GitCheckoutSummaryDto {
  role: GitCheckoutRoleDto;
  path: string;
  reachable: boolean;
  unreachable_reason?: string;
  locked?: boolean;
  prunable?: boolean;
  branch?: string;
  detached_head?: boolean;
  upstream?: string;
  ahead_count: number;
  behind_count: number;
  head_commit?: string;
  head_subject?: string;
  head_authored_at?: string;
  staged_count: number;
  unstaged_count: number;
  untracked_count: number;
  conflicted_count: number;
  total_change_count: number;
}

export interface GitCheckoutDetailDto extends GitCheckoutSummaryDto {
  files: GitFileChangeDto[];
  files_total: number;
  next_file_cursor?: string;
  commits?: GitCommitDto[];
}

export interface WorkspaceGitStatusResult {
  main: GitCheckoutSummaryDto;
  worktrees: GitCheckoutSummaryDto[];
  worktrees_truncated?: boolean;
  worktrees_total_count: number;
  collected_at: string;
}

export interface WorkspaceCheckoutStatusResult {
  checkout: GitCheckoutDetailDto;
  collected_at: string;
}

export interface GitDiffDto {
  reachable: boolean;
  unreachable_reason?: string;
  patch?: string;
  truncated?: boolean;
  binary?: boolean;
  file_count?: number;
  subject?: string;
  author?: string;
  author_mail?: string;
  authored_at?: string;
  hash?: string;
}

export interface WorkspaceFileDiffParams {
  workspace_id: string;
  checkout_path: string;
  file_path: string;
  bucket?: "staged" | "unstaged" | "untracked" | "conflicted";
}

export interface WorkspaceFileDiffResult {
  diff: GitDiffDto;
  collected_at: string;
}

export interface WorkspaceCommitDiffParams {
  workspace_id: string;
  checkout_path: string;
  commit_hash: string;
}

export interface WorkspaceCommitDiffResult {
  diff: GitDiffDto;
  collected_at: string;
}

export interface WorkspaceGitStatusParams {
  workspace_id: string;
}

export interface WorkspaceCheckoutStatusParams {
  workspace_id: string;
  checkout_path: string;
  file_cursor?: string;
  file_limit?: number;
}

export interface WorkspaceReconcileParams {
  workspace_id: string;
}

export type WorkspaceReconcileOutcome = "busy" | "noop" | "reconciled";

export interface WorkspaceReconcileResult {
  outcome: WorkspaceReconcileOutcome;
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

export interface ConfigDeleteParams {
  alias: string;
}

export interface ConfigDeleteResult {
  removed: boolean;
}

export interface ConfigSetBuiltinRuntimesParams {
  runtime_id: string;
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

export interface ClarificationAnswerDto {
  selected?: string | string[];
}

export interface ClarificationRequestDto {
  questions?: InputQuestionDto[];
}

export interface ClarificationResponseDto {
  answers?: ClarificationAnswerDto[];
}

export interface ClarificationExchangeDto {
  created_at?: string;
  responded_at?: string;
  request?: ClarificationRequestDto;
  response?: ClarificationResponseDto;
}

export interface NodeRunViewDto {
  id: string;
  task_id: string;
  node_name: string;
  status: string;
  session_id?: string;
  failure_reason?: string;
  result?: Record<string, unknown>;
  clarifications?: ClarificationExchangeDto[];
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
  follow_up?: TaskFollowUpDto;
  follow_up_state?: TaskFollowUpStateDto;
  live_events?: SessionHistoryEventDto[];
  live_output_run_id?: string;
}

export type FollowUpModeDto =
  | "continue_here"
  | "fork_head"
  | "fork_with_changes";

export interface TaskFollowUpDto {
  default_mode: FollowUpModeDto;
  available_modes: FollowUpModeDto[];
  uncommitted_change_count: number;
}

export type TaskFollowUpStateDto = "basic" | "refine" | "disabled";

export type WorktreeCleanupStateDto =
  | "available"
  | "blocked"
  | "missing"
  | "not_applicable";

export type WorktreeRemovalScopeDto =
  | "single_worktree"
  | "shared_worktree";

export type TaskCleanupWorktreeOutcomeDto =
  | "removed"
  | "blocked"
  | "missing"
  | "not_applicable"
  | "failed";

export interface WorktreeCleanupBlockerDto {
  task_id: string;
  description: string;
  status: string;
}

export interface WorktreeCleanupInfoDto {
  state: WorktreeCleanupStateDto;
  worktree_group_id?: string;
  worktree_root?: string;
  shared_task_count: number;
  dirty_count: number;
  blocked_by?: WorktreeCleanupBlockerDto[];
  removal_scope?: WorktreeRemovalScopeDto;
  can_remove: boolean;
  message?: string;
}

export interface TaskAncestryItemDto {
  task_id: string;
  description: string;
  status: string;
  updated_at: string;
  parent_task_id?: string;
}

export interface TaskGetAncestryResult {
  ancestors: TaskAncestryItemDto[];
}

export interface TaskGetWorktreeCleanupInfoResult {
  info: WorktreeCleanupInfoDto;
}

export interface TaskInputRequestResult {
  input_request?: InputRequestDto;
}

export interface TaskRunHistoryResult {
  task_id: string;
  node_run_id: string;
  session_id?: string;
  provenance: string;
  completeness: string;
  last_seq?: number;
  events?: SessionHistoryEventDto[];
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

export interface ImageAttachmentInputDto {
  name?: string;
  mime_type?: string;
  size_bytes?: number;
  data_base64?: string;
}

export interface TaskStartParams {
  workspace_id: string;
  client_command_id?: string;
  description: string;
  config_alias: string;
  config_path: string;
  use_worktree?: boolean;
  image_attachments?: ImageAttachmentInputDto[];
}

export interface TaskStartFollowUpParams {
  workspace_id: string;
  client_command_id?: string;
  parent_task_id: string;
  description: string;
  config_alias?: string;
  config_path?: string;
  follow_up_mode?: FollowUpModeDto;
  image_attachments?: ImageAttachmentInputDto[];
}

export interface TaskSubmitInputParams {
  workspace_id: string;
  client_command_id?: string;
  task_id: string;
  node_run_id: string;
  payload?: Record<string, unknown>;
  image_attachments?: ImageAttachmentInputDto[];
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

export interface TaskGetWorktreeCleanupInfoParams {
  workspace_id: string;
  task_id: string;
}

export interface TaskCleanupWorktreeParams {
  workspace_id: string;
  task_id: string;
}

export interface TaskCleanupWorktreeResult {
  outcome: TaskCleanupWorktreeOutcomeDto;
  info?: WorktreeCleanupInfoDto;
}

export interface TaskRecoverStaleParams {
  workspace_id: string;
  task_id: string;
  node_run_id: string;
}

export type TaskRecoverStaleOutcome =
  | "busy"
  | "already_terminal"
  | "recovered_done"
  | "recovered_failed"
  | "recovered_awaiting"
  | "still_open";

export interface TaskRecoverStaleResult {
  outcome: TaskRecoverStaleOutcome;
}

export interface SessionHistoryToolDiffDto {
  path?: string;
  old_text?: string;
  new_text?: string;
}

export interface SessionHistoryMcpOutputBlockDto {
  type: string;
  label?: string;
  text?: string;
  json?: string;
  data_url?: string;
  mime_type?: string;
}

export interface SessionHistoryMcpToolDto {
  server?: string;
  tool?: string;
  arguments_json?: string;
  structured_content_json?: string;
  output_blocks?: SessionHistoryMcpOutputBlockDto[];
  debug_json?: string;
}

export interface SessionHistoryPlanStepDto {
  text: string;
  status?: string;
}

interface SessionHistoryEventBaseDto {
  event_id?: string;
  seq?: number;
  emitted_at?: string;
  recorded_at?: string;
  session_id?: string;
  provider_record_id?: string;
  provider_subindex?: number;
  provenance?: string;
  kind: "message" | "tool" | "plan" | "usage" | "raw";
}

export interface SessionHistoryMessageEventDto extends SessionHistoryEventBaseDto {
  kind: "message";
  message_id?: string;
  part_id?: string;
  role?: string;
  part_type?: string;
  text?: string;
}

export interface SessionHistoryToolEventDto extends SessionHistoryEventBaseDto {
  kind: "tool";
  call_id?: string;
  parent_call_id?: string;
  name?: string;
  tool_kind?: string;
  title?: string;
  status?: string;
  duration_ms?: number;
  input_summary?: string;
  output_text?: string;
  error_text?: string;
  paths?: string[];
  diffs?: SessionHistoryToolDiffDto[];
  raw_input_json?: string;
  raw_output_json?: string;
  mcp?: SessionHistoryMcpToolDto;
}

export interface SessionHistoryPlanEventDto extends SessionHistoryEventBaseDto {
  kind: "plan";
  plan_id?: string;
  steps?: SessionHistoryPlanStepDto[];
}

export interface SessionHistoryUsageEventDto extends SessionHistoryEventBaseDto {
  kind: "usage";
  input_tokens?: number;
  cached_input_tokens?: number;
  output_tokens?: number;
  total_tokens?: number;
  duration_ms?: number;
}

export interface SessionHistoryRawEventDto extends SessionHistoryEventBaseDto {
  kind: "raw";
  raw?: string;
}

export type SessionHistoryEventDto =
  | SessionHistoryMessageEventDto
  | SessionHistoryToolEventDto
  | SessionHistoryPlanEventDto
  | SessionHistoryUsageEventDto
  | SessionHistoryRawEventDto;

export interface ProgressInfoDto {
  message?: string;
  session_id?: string;
  events?: SessionHistoryEventDto[];
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
