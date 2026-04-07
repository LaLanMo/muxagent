import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  createEditableDraft,
  deleteConfig,
  loadConfigDetail,
  loadConfigPrompt,
  loadRuntimeList,
  refreshConfigCatalog,
  renameConfig,
  resetConfig,
  saveConfigDraft,
  saveConfigPrompt,
  setDefaultConfig,
  validateConfigDraft,
} from "@/application/configs";
import { getRuntime } from "@/app/runtime";
import {
  addEdgeToDraft,
  addNodeToDraft,
  createEditableNodeName,
  removeEdgeFromDraft,
  removeNodeFromDraft,
  renameNodeInDraft,
  updateEdgeInDraft,
  updateNodeDefinition,
  updateNodeRef,
} from "@/domain/config-editor";
import {
  buildConfigGraphLayout,
  type ConfigGraphLayout,
} from "@/features/configs/model/config-graph";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { useWorkspaceStore } from "@/state/workspace-store";
import type {
  ConfigDetailDto,
  ConfigDraftDto,
  ConfigPromptDto,
  ConfigValidateResult,
  RuntimeEntryDto,
} from "@/rpc/types";

type PromptDraftState = {
  path: string;
  content: string;
  savedContent: string;
  revision: string;
  loading: boolean;
  saving: boolean;
  needsConfigSave: boolean;
  error?: string;
};

function parseLooseJson(value: string): unknown {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }
  if (trimmed === "true") {
    return true;
  }
  if (trimmed === "false") {
    return false;
  }
  if (trimmed === "null") {
    return null;
  }
  const numeric = Number(trimmed);
  if (!Number.isNaN(numeric) && trimmed === String(numeric)) {
    return numeric;
  }
  try {
    return JSON.parse(trimmed);
  } catch {
    return trimmed;
  }
}

export function useConfigEditorScreen() {
  const { alias = "" } = useParams();
  const navigate = useNavigate();
  const shell = useShellModel();
  const setCatalog = useWorkspaceStore((state) => state.setCatalog);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();
  const [detail, setDetail] = useState<ReturnType<typeof loadDetailState>>();
  const [draft, setDraft] = useState<ConfigDraftDto>();
  const [runtimes, setRuntimes] = useState<RuntimeEntryDto[]>([]);
  const [selectedNodeName, setSelectedNodeName] = useState<string>();
  const [renameDraft, setRenameDraft] = useState("");
  const [schemaText, setSchemaText] = useState("");
  const [schemaError, setSchemaError] = useState<string>();
  const [saving, setSaving] = useState(false);
  const [renaming, setRenaming] = useState(false);
  const [working, setWorking] = useState(false);
  const [pendingConfirmAction, setPendingConfirmAction] = useState<
    "delete" | "reset" | undefined
  >(undefined);
  const [validation, setValidation] = useState<ConfigValidateResult>();
  const [validating, setValidating] = useState(false);
  const [graph, setGraph] = useState<ConfigGraphLayout>({
    nodes: [],
    edges: [],
    width: 420,
    height: 260,
  });
  const [promptDraftsByNodeName, setPromptDraftsByNodeName] = useState<
    Record<string, PromptDraftState>
  >({});

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError(undefined);
      try {
        const [entry, runtimeEntries] = await Promise.all([
          loadConfigDetail(getRuntime(), alias),
          loadRuntimeList(getRuntime()),
        ]);
        if (cancelled) {
          return;
        }
        setDetail(loadDetailState(entry));
        setDraft(createEditableDraft(entry));
        setRenameDraft(entry.alias);
        setSelectedNodeName(
          entry.config?.topology.entry || entry.node_names?.[0] || undefined,
        );
        setRuntimes(runtimeEntries);
        setPromptDraftsByNodeName({});
      } catch (loadError) {
        if (cancelled) {
          return;
        }
        setError(
          loadError instanceof Error ? loadError.message : "Failed to load config",
        );
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [alias]);

  useEffect(() => {
    const selectedDefinition = draft?.node_definitions[selectedNodeName ?? ""];
    setSchemaText(
      selectedDefinition
        ? JSON.stringify(selectedDefinition.result_schema, null, 2)
        : "",
    );
    setSchemaError(undefined);
  }, [draft, selectedNodeName]);

  const baseDraft = useMemo(
    () => (detail ? createEditableDraft(detail) : undefined),
    [detail],
  );

  useEffect(() => {
    if (!draft) {
      return undefined;
    }
    let cancelled = false;
    setValidating(true);
    const timer = window.setTimeout(() => {
      void validateConfigDraft(getRuntime(), draft)
        .then((result) => {
          if (!cancelled) {
            setValidation(result);
          }
        })
        .catch((validationError) => {
          if (!cancelled) {
            setValidation({
              valid: false,
              runtime_configured: false,
              error:
                validationError instanceof Error
                  ? validationError.message
                  : "Validation failed",
            });
          }
        })
        .finally(() => {
          if (!cancelled) {
            setValidating(false);
          }
        });
    }, 250);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [draft]);

  const selectedNode = useMemo(
    () => draft?.topology.nodes.find((node) => node.name === selectedNodeName),
    [draft, selectedNodeName],
  );
  const selectedDefinition = useMemo(
    () => (selectedNodeName ? draft?.node_definitions[selectedNodeName] : undefined),
    [draft, selectedNodeName],
  );
  const persistedSelectedDefinition = useMemo(
    () =>
      selectedNodeName ? detail?.config?.node_definitions?.[selectedNodeName] : undefined,
    [detail, selectedNodeName],
  );
  const selectedPrompt = useMemo(
    () => (selectedNodeName ? promptDraftsByNodeName[selectedNodeName] : undefined),
    [promptDraftsByNodeName, selectedNodeName],
  );
  const outgoingEdges = useMemo(
    () =>
      draft?.topology.edges
        .map((edge, index) => ({ edge, index }))
        .filter(({ edge }) => edge.from === selectedNodeName) ?? [],
    [draft, selectedNodeName],
  );
  useEffect(() => {
    if (!draft) {
      setGraph({
        nodes: [],
        edges: [],
        width: 420,
        height: 260,
      });
      return undefined;
    }
    let cancelled = false;
    void buildConfigGraphLayout(draft).then((nextGraph) => {
      if (!cancelled) {
        setGraph(nextGraph);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [draft]);

  useEffect(() => {
    if (!selectedNodeName || !selectedDefinition || selectedDefinition.type !== "agent") {
      return;
    }
    const existing = promptDraftsByNodeName[selectedNodeName];
    if (existing) {
      const desiredPath =
        selectedDefinition.system_prompt?.trim() || suggestedPromptPath(selectedNodeName);
      if (existing.path !== desiredPath) {
        setPromptDraftsByNodeName((current) => {
          const prompt = current[selectedNodeName];
          if (!prompt || prompt.path === desiredPath) {
            return current;
          }
          return {
            ...current,
            [selectedNodeName]: {
              ...prompt,
              path: desiredPath,
              needsConfigSave: true,
            },
          };
        });
      }
      return;
    }

    const draftPromptPath =
      selectedDefinition.system_prompt?.trim() || suggestedPromptPath(selectedNodeName);
    const canLoadPersistedPrompt =
      Boolean(detail) &&
      persistedSelectedDefinition?.type === "agent" &&
      Boolean(persistedSelectedDefinition.system_prompt?.trim()) &&
      persistedSelectedDefinition.system_prompt === selectedDefinition.system_prompt;

    setPromptDraftsByNodeName((current) => ({
      ...current,
      [selectedNodeName]: {
        path: draftPromptPath,
        content: "",
        savedContent: "",
        revision: "",
        loading: canLoadPersistedPrompt,
        saving: false,
        needsConfigSave: !canLoadPersistedPrompt,
      },
    }));
  }, [
    detail,
    persistedSelectedDefinition,
    promptDraftsByNodeName,
    selectedDefinition,
    selectedNodeName,
  ]);

  useEffect(() => {
    if (!detail || !selectedNodeName) {
      return;
    }
    const prompt = promptDraftsByNodeName[selectedNodeName];
    if (!prompt?.loading) {
      return;
    }
    let cancelled = false;
    void loadConfigPrompt(getRuntime(), detail.alias, selectedNodeName)
      .then((loadedPrompt) => {
        if (cancelled) {
          return;
        }
        setPromptDraftsByNodeName((current) => ({
          ...current,
          [selectedNodeName]: promptStateFromDto(loadedPrompt),
        }));
      })
      .catch((promptError) => {
        if (cancelled) {
          return;
        }
        setPromptDraftsByNodeName((current) => ({
          ...current,
          [selectedNodeName]: {
            ...prompt,
            loading: false,
            needsConfigSave: true,
            error:
              promptError instanceof Error
                ? promptError.message
                : "Failed to load prompt",
          },
        }));
      });

    return () => {
      cancelled = true;
    };
  }, [detail, promptDraftsByNodeName, selectedNodeName]);

  const isDirty =
    Boolean(draft) &&
    Boolean(baseDraft) &&
    JSON.stringify(draft) !== JSON.stringify(baseDraft);

  async function refreshCatalog() {
    const nextCatalog = await refreshConfigCatalog(getRuntime());
    setCatalog(nextCatalog);
    return nextCatalog;
  }

  async function persistDirtyPrompts(
    savedDetail: ConfigDetailDto,
    promptStates: Record<string, PromptDraftState>,
  ) {
    let nextPromptStates = { ...promptStates };
    const entries = Object.entries(promptStates).filter(([, prompt]) => {
      return prompt.content !== prompt.savedContent;
    });
    for (const [nodeName, prompt] of entries) {
      const persistedDefinition = savedDetail.config?.node_definitions?.[nodeName];
      if (
        !persistedDefinition ||
        persistedDefinition.type !== "agent" ||
        !persistedDefinition.system_prompt?.trim()
      ) {
        continue;
      }
      const savedPrompt = await saveConfigPrompt(
        getRuntime(),
        savedDetail.alias,
        nodeName,
        prompt.revision,
        prompt.content,
      );
      nextPromptStates[nodeName] = promptStateFromDto(savedPrompt);
    }
    return nextPromptStates;
  }

  async function saveDraft() {
    if (!detail || !draft || !detail.revision || saving || validating) {
      return;
    }
    if (!validation?.valid) {
      return;
    }
    setSaving(true);
    setError(undefined);
    try {
      const saved = await saveConfigDraft(
        getRuntime(),
        detail.alias,
        detail.revision,
        draft,
      );
      setDetail(loadDetailState(saved));
      setDraft(createEditableDraft(saved));
      setRenameDraft(saved.alias);
      try {
        const nextPromptStates = await persistDirtyPrompts(
          saved,
          promptDraftsByNodeName,
        );
        setPromptDraftsByNodeName(nextPromptStates);
      } catch (promptError) {
        setError(
          promptError instanceof Error
            ? `Config saved, but prompt sync failed: ${promptError.message}`
            : "Config saved, but prompt sync failed",
        );
      }
      await refreshCatalog();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : "Failed to save config");
    } finally {
      setSaving(false);
    }
  }

  async function renameCurrentConfig() {
    if (!detail || renaming) {
      return;
    }
    const nextAlias = renameDraft.trim();
    if (!nextAlias || nextAlias === detail.alias) {
      return;
    }
    setRenaming(true);
    setError(undefined);
    try {
      const renamed = await renameConfig(getRuntime(), detail.alias, nextAlias);
      setDetail(loadDetailState(renamed));
      await refreshCatalog();
      navigate(`/configs/${encodeURIComponent(renamed.alias)}`, { replace: true });
    } catch (renameError) {
      setError(
        renameError instanceof Error ? renameError.message : "Failed to rename config",
      );
    } finally {
      setRenaming(false);
    }
  }

  async function makeDefault() {
    if (!detail || detail.is_default) {
      return;
    }
    setWorking(true);
    setError(undefined);
    try {
      const updated = await setDefaultConfig(getRuntime(), detail.alias);
      setDetail(loadDetailState(updated));
      await refreshCatalog();
    } catch (defaultError) {
      setError(
        defaultError instanceof Error
          ? defaultError.message
          : "Failed to set default config",
      );
    } finally {
      setWorking(false);
    }
  }

  function requestRemoveCurrentConfig() {
    if (!detail || detail.builtin) {
      return;
    }
    setPendingConfirmAction("delete");
  }

  function requestResetBuiltinConfig() {
    if (!detail || !detail.builtin) {
      return;
    }
    setPendingConfirmAction("reset");
  }

  function cancelPendingConfigAction() {
    setPendingConfirmAction(undefined);
  }

  async function confirmPendingConfigAction() {
    if (!detail || !pendingConfirmAction) {
      return;
    }
    const action = pendingConfirmAction;
    setPendingConfirmAction(undefined);
    setWorking(true);
    setError(undefined);
    try {
      if (action === "delete") {
        await deleteConfig(getRuntime(), detail.alias);
        await refreshCatalog();
        navigate("/configs");
        return;
      }
      const reset = await resetConfig(getRuntime(), detail.alias);
      setDetail(loadDetailState(reset));
      setDraft(createEditableDraft(reset));
      setRenameDraft(reset.alias);
      setPromptDraftsByNodeName({});
      setSelectedNodeName(
        reset.config?.topology.entry || reset.node_names?.[0] || undefined,
      );
      await refreshCatalog();
    } catch (actionError) {
      setError(
        actionError instanceof Error
          ? actionError.message
          : action === "delete"
            ? "Failed to delete config"
            : "Failed to reset config",
      );
    } finally {
      setWorking(false);
    }
  }

  function initializeSelectedPrompt() {
    if (!selectedNodeName || !selectedDefinition) {
      return;
    }
    const nextPath =
      selectedDefinition.system_prompt?.trim() || suggestedPromptPath(selectedNodeName);
    if (!selectedDefinition.system_prompt?.trim()) {
      updateSelectedDefinition("system_prompt", nextPath);
    }
    setPromptDraftsByNodeName((current) => ({
      ...current,
      [selectedNodeName]: {
        path: nextPath,
        content: current[selectedNodeName]?.content ?? "",
        savedContent: current[selectedNodeName]?.savedContent ?? "",
        revision: current[selectedNodeName]?.revision ?? "",
        loading: false,
        saving: false,
        needsConfigSave: true,
      },
    }));
  }

  function setSelectedPromptContent(content: string) {
    if (!selectedNodeName) {
      return;
    }
    setPromptDraftsByNodeName((current) => {
      const existing = current[selectedNodeName];
      if (!existing) {
        return current;
      }
      return {
        ...current,
        [selectedNodeName]: {
          ...existing,
          content,
          error: undefined,
        },
      };
    });
  }

  async function saveSelectedPrompt() {
    if (!detail || !selectedNodeName || !selectedPrompt) {
      return;
    }
    if (selectedPrompt.needsConfigSave) {
      setPromptDraftsByNodeName((current) => {
        const existing = current[selectedNodeName];
        if (!existing) {
          return current;
        }
        return {
          ...current,
          [selectedNodeName]: {
            ...existing,
            error: "Save config changes first to persist this prompt file.",
          },
        };
      });
      return;
    }
    setPromptDraftsByNodeName((current) => {
      const existing = current[selectedNodeName];
      if (!existing) {
        return current;
      }
      return {
        ...current,
        [selectedNodeName]: {
          ...existing,
          saving: true,
          error: undefined,
        },
      };
    });
    try {
      const savedPrompt = await saveConfigPrompt(
        getRuntime(),
        detail.alias,
        selectedNodeName,
        selectedPrompt.revision,
        selectedPrompt.content,
      );
      setPromptDraftsByNodeName((current) => ({
        ...current,
        [selectedNodeName]: promptStateFromDto(savedPrompt),
      }));
    } catch (promptError) {
      setPromptDraftsByNodeName((current) => {
        const existing = current[selectedNodeName];
        if (!existing) {
          return current;
        }
        return {
          ...current,
          [selectedNodeName]: {
            ...existing,
            saving: false,
            error:
              promptError instanceof Error
                ? promptError.message
                : "Failed to save prompt",
          },
        };
      });
    }
  }

  function updateDraft(updater: (current: ConfigDraftDto) => ConfigDraftDto) {
    setDraft((current) => (current ? updater(current) : current));
  }

  function setDescription(description: string) {
    updateDraft((current) => ({ ...current, description }));
  }

  function setRuntime(runtimeId: string) {
    updateDraft((current) => ({ ...current, runtime: runtimeId }));
  }

  function setEntryNode(entry: string) {
    updateDraft((current) => ({
      ...current,
      topology: {
        ...current.topology,
        entry,
      },
    }));
  }

  function setTopologyMaxIterations(rawValue: string) {
    const parsed = Number.parseInt(rawValue, 10);
    updateDraft((current) => ({
      ...current,
      topology: {
        ...current.topology,
        max_iterations: Number.isFinite(parsed) && parsed > 0 ? parsed : 1,
      },
    }));
  }

  function setClarificationField(
    key: keyof ConfigDraftDto["clarification"],
    rawValue: string,
  ) {
    const parsed = Number.parseInt(rawValue, 10);
    updateDraft((current) => ({
      ...current,
      clarification: {
        ...current.clarification,
        [key]: Number.isFinite(parsed) && parsed > 0 ? parsed : 1,
      },
    }));
  }

  function addNode() {
    updateDraft((current) => {
      const nodeName = createEditableNodeName(current);
      setSelectedNodeName(nodeName);
      return addNodeToDraft(current, nodeName);
    });
  }

  function removeSelectedNode() {
    if (!selectedNodeName) {
      return;
    }
    updateDraft((current) => {
      const nextDraft = removeNodeFromDraft(current, selectedNodeName);
      setSelectedNodeName(nextDraft.topology.nodes[0]?.name);
      return nextDraft;
    });
    setPromptDraftsByNodeName((current) => {
      const next = { ...current };
      delete next[selectedNodeName];
      return next;
    });
  }

  function renameSelectedNode(nextName: string) {
    if (!selectedNodeName) {
      return;
    }
    const trimmed = nextName.trim();
    if (!trimmed) {
      return;
    }
    if (draft?.topology.nodes.some((node) => node.name === trimmed)) {
      if (trimmed === selectedNodeName) {
        return;
      }
      return;
    }
    updateDraft((current) => renameNodeInDraft(current, selectedNodeName, trimmed));
    setPromptDraftsByNodeName((current) => {
      const prompt = current[selectedNodeName];
      if (!prompt) {
        return current;
      }
      const next = { ...current };
      delete next[selectedNodeName];
      next[trimmed] = prompt;
      return next;
    });
    setSelectedNodeName(trimmed);
  }

  function updateSelectedNodeRef<K extends keyof ConfigDraftDto["topology"]["nodes"][number]>(
    key: K,
    value: ConfigDraftDto["topology"]["nodes"][number][K],
  ) {
    if (!selectedNodeName) {
      return;
    }
    updateDraft((current) =>
      updateNodeRef(current, selectedNodeName, (node) => ({
        ...node,
        [key]: value,
      })),
    );
  }

  function updateSelectedDefinition<K extends keyof ConfigDraftDto["node_definitions"][string]>(
    key: K,
    value: ConfigDraftDto["node_definitions"][string][K],
  ) {
    if (!selectedNodeName) {
      return;
    }
    updateDraft((current) =>
      updateNodeDefinition(current, selectedNodeName, (definition) => ({
        ...definition,
        [key]: value,
      })),
    );
  }

  function applySchema() {
    if (!selectedNodeName) {
      return;
    }
    try {
      const parsed = JSON.parse(schemaText) as Record<string, unknown>;
      updateDraft((current) =>
        updateNodeDefinition(current, selectedNodeName, (definition) => ({
          ...definition,
          result_schema: parsed,
        })),
      );
      setSchemaError(undefined);
    } catch (parseError) {
      setSchemaError(
        parseError instanceof Error ? parseError.message : "Invalid JSON schema",
      );
    }
  }

  function addOutgoingEdge() {
    if (!selectedNodeName) {
      return;
    }
    updateDraft((current) => addEdgeToDraft(current, selectedNodeName));
  }

  function updateOutgoingEdge(
    edgeIndex: number,
    field: "to" | "kind" | "whenField" | "equals",
    value: string,
  ) {
    updateDraft((current) =>
      updateEdgeInDraft(current, edgeIndex, (edge) => {
        if (field === "to") {
          return { ...edge, to: value };
        }
        if (field === "kind") {
          const kind = value.trim();
          return {
            ...edge,
            when:
              kind === ""
                ? undefined
                : {
                    kind,
                    field: kind === "when" ? edge.when?.field ?? "" : undefined,
                    equals: kind === "when" ? edge.when?.equals ?? "" : undefined,
                  },
          };
        }
        if (field === "whenField") {
          return {
            ...edge,
            when: {
              kind: edge.when?.kind ?? "when",
              field: value,
              equals: edge.when?.equals,
            },
          };
        }
        return {
          ...edge,
          when: {
            kind: edge.when?.kind ?? "when",
            field: edge.when?.field,
            equals: parseLooseJson(value),
          },
        };
      }),
    );
  }

  function removeOutgoingEdge(edgeIndex: number) {
    updateDraft((current) => removeEdgeFromDraft(current, edgeIndex));
  }

  return {
    shell,
    loading,
    error,
    detail,
    draft,
    runtimes,
    selectedNodeName,
    selectedNode,
    selectedDefinition,
    selectedPrompt,
    outgoingEdges,
    graph,
    renameDraft,
    setRenameDraft,
    schemaText,
    setSchemaText,
    schemaError,
    validation,
    validating,
    pendingConfirmAction,
    saving,
    renaming,
    working,
    isDirty,
    selectNode: setSelectedNodeName,
    setDescription,
    setRuntime,
    setEntryNode,
    setTopologyMaxIterations,
    setClarificationField,
    addNode,
    removeSelectedNode,
    renameSelectedNode,
    updateSelectedNodeRef,
    updateSelectedDefinition,
    initializeSelectedPrompt,
    setSelectedPromptContent,
    saveSelectedPrompt,
    applySchema,
    addOutgoingEdge,
    updateOutgoingEdge,
    removeOutgoingEdge,
    saveDraft,
    renameCurrentConfig,
    makeDefault,
    requestRemoveCurrentConfig,
    requestResetBuiltinConfig,
    cancelPendingConfigAction,
    confirmPendingConfigAction,
  };
}

function loadDetailState(entry: ConfigDetailDto) {
  return {
    ...entry,
  };
}

function promptStateFromDto(prompt: ConfigPromptDto): PromptDraftState {
  return {
    path: displayPromptPath(prompt.path),
    content: prompt.content,
    savedContent: prompt.content,
    revision: prompt.revision ?? "",
    loading: false,
    saving: false,
    needsConfigSave: false,
  };
}

function suggestedPromptPath(nodeName: string) {
  return `./prompts/${nodeName}.md`;
}

function displayPromptPath(promptPath: string) {
  const trimmed = promptPath.trim();
  if (!trimmed || trimmed.startsWith("./") || trimmed.startsWith("../")) {
    return trimmed;
  }
  return `./${trimmed}`;
}
