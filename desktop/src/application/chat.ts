import type { DesktopRuntime, RuntimeNotification } from "@/platform/contract";
import type {
  AgentChatAcceptedResult,
  AgentChatCancelParams,
  AgentChatCreateSessionParams,
  AgentChatListSessionsParams,
  AgentChatLoadSessionParams,
  AgentChatOkResult,
  AgentChatPromptParams,
  AgentChatRuntimeListResult,
  AgentChatSetConfigOptionParams,
  AgentChatSetModeParams,
  AgentChatSessionCreateResult,
  AgentChatSessionListResult,
  AgentChatSessionLoadResult,
  AgentChatStreamItemDto,
} from "@/rpc/types";

const agentChatStreamItemMethod = "agentchat.streamItem";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function isAgentChatStreamItemNotification(
  notification: RuntimeNotification,
): notification is RuntimeNotification & AgentChatStreamItemDto {
  if (notification.method !== agentChatStreamItemMethod) {
    return false;
  }
  if (notification.kind === "event") {
    return isRecord(notification.event);
  }
  return (
    notification.kind === "replay" &&
    Array.isArray(notification.events) &&
    typeof notification.status === "string"
  );
}

export function agentChatStreamItemFromNotification(
  notification: RuntimeNotification,
): AgentChatStreamItemDto | null {
  if (!isAgentChatStreamItemNotification(notification)) {
    return null;
  }
  const { method: _method, ...streamItem } = notification;
  return streamItem as AgentChatStreamItemDto;
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

export function cancelAgentChatSession(
  runtime: DesktopRuntime,
  params: AgentChatCancelParams,
): Promise<AgentChatOkResult> {
  return runtime.backend.agentChatRPC<AgentChatOkResult, AgentChatCancelParams>(
    "session.cancel",
    params,
  );
}

export function setAgentChatSessionMode(
  runtime: DesktopRuntime,
  params: AgentChatSetModeParams,
): Promise<AgentChatOkResult> {
  return runtime.backend.agentChatRPC<AgentChatOkResult, AgentChatSetModeParams>(
    "session.setMode",
    params,
  );
}

export function setAgentChatSessionConfigOption(
  runtime: DesktopRuntime,
  params: AgentChatSetConfigOptionParams,
): Promise<AgentChatOkResult> {
  return runtime.backend.agentChatRPC<
    AgentChatOkResult,
    AgentChatSetConfigOptionParams
  >("session.setConfigOption", params);
}
