import type { DesktopRuntime, RuntimeNotification } from "@/platform/contract";
import type {
  AgentChatAcceptedResult,
  AgentChatCreateSessionParams,
  AgentChatEventDto,
  AgentChatListSessionsParams,
  AgentChatLoadSessionParams,
  AgentChatPromptParams,
  AgentChatRuntimeListResult,
  AgentChatSessionCreateResult,
  AgentChatSessionListResult,
  AgentChatSessionLoadResult,
} from "@/rpc/types";

const agentChatEventMethod = "agentchat.event";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function isAgentChatEventNotification(
  notification: RuntimeNotification,
): notification is RuntimeNotification & AgentChatEventDto {
  return (
    notification.method === agentChatEventMethod &&
    typeof notification.type === "string"
  );
}

export function agentChatEventFromNotification(
  notification: RuntimeNotification,
): AgentChatEventDto | null {
  if (!isAgentChatEventNotification(notification)) {
    return null;
  }
  const { method: _method, ...event } = notification;
  return event as AgentChatEventDto;
}

export function eventSessionId(event: AgentChatEventDto): string | undefined {
  const sessionStatusId = isRecord(event.sessionStatus?.app)
    ? event.sessionStatus.app.id
    : undefined;
  return event.sessionId || sessionStatusId;
}

export function loadAgentChatRuntimes(
  runtime: DesktopRuntime,
): Promise<AgentChatRuntimeListResult> {
  return runtime.backend.agentChatRPC<AgentChatRuntimeListResult>("runtime.list");
}

export function listAgentChatSessions(
  runtime: DesktopRuntime,
  params: AgentChatListSessionsParams = { limit: 50 },
): Promise<AgentChatSessionListResult> {
  return runtime.backend.agentChatRPC<
    AgentChatSessionListResult,
    AgentChatListSessionsParams
  >("session.list", params);
}

export function createAgentChatSession(
  runtime: DesktopRuntime,
  params: AgentChatCreateSessionParams,
): Promise<AgentChatSessionCreateResult> {
  return runtime.backend.agentChatRPC<
    AgentChatSessionCreateResult,
    AgentChatCreateSessionParams
  >("session.create", params);
}

export function loadAgentChatSession(
  runtime: DesktopRuntime,
  params: AgentChatLoadSessionParams,
): Promise<AgentChatSessionLoadResult> {
  return runtime.backend.agentChatRPC<
    AgentChatSessionLoadResult,
    AgentChatLoadSessionParams
  >("session.load", params);
}

export function promptAgentChatSession(
  runtime: DesktopRuntime,
  params: AgentChatPromptParams,
): Promise<AgentChatAcceptedResult> {
  return runtime.backend.agentChatRPC<
    AgentChatAcceptedResult,
    AgentChatPromptParams
  >("session.prompt", params);
}
