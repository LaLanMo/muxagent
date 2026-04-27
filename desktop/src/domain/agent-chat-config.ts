import type {
  AgentChatSessionConfigOptionDto,
  AgentChatSessionConfigOptionEntryDto,
  AgentChatSessionConfigValueDto,
} from "@/rpc/types";

function isConfigValue(
  entry: AgentChatSessionConfigOptionEntryDto,
): entry is AgentChatSessionConfigValueDto {
  return "value" in entry;
}

export function flattenConfigOptionValues(
  option: AgentChatSessionConfigOptionDto | undefined,
): AgentChatSessionConfigValueDto[] {
  return (option?.options ?? []).flatMap((entry) =>
    isConfigValue(entry) ? [entry] : entry.options,
  );
}

export function configOptionByCategory(
  options: AgentChatSessionConfigOptionDto[] | undefined,
  category: string,
): AgentChatSessionConfigOptionDto | undefined {
  return options?.find((option) => option.category === category);
}

export function configValueByCategory(
  options: AgentChatSessionConfigOptionDto[] | undefined,
  category: string,
): string {
  return configOptionByCategory(options, category)?.currentValue?.trim() ?? "";
}
