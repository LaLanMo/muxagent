import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import {
  createEditableDraft,
  loadConfigDetail,
  validateConfigDraft,
} from "@/application/configs";
import { getRuntime } from "@/app/runtime";
import {
  buildConfigGraphLayout,
  type ConfigGraphLayout,
} from "@/features/configs/model/config-graph";
import { useShellModel } from "@/features/app/model/use-shell-model";
import type {
  ConfigDetailDto,
  ConfigDraftDto,
  ConfigValidateResult,
} from "@/rpc/types";

const EMPTY_GRAPH: ConfigGraphLayout = {
  nodes: [],
  edges: [],
  width: 420,
  height: 260,
};

export function useConfigEditorScreen() {
  const { alias = "" } = useParams();
  const shell = useShellModel();

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();
  const [detail, setDetail] = useState<ConfigDetailDto>();
  const [draft, setDraft] = useState<ConfigDraftDto>();
  const [selectedNodeName, setSelectedNodeName] = useState<string>();
  const [validation, setValidation] = useState<ConfigValidateResult>();
  const [validating, setValidating] = useState(false);
  const [graph, setGraph] = useState<ConfigGraphLayout>(EMPTY_GRAPH);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      setError(undefined);
      try {
        const entry = await loadConfigDetail(getRuntime(), alias);
        if (cancelled) {
          return;
        }
        setDetail(entry);
        setDraft(createEditableDraft(entry));
        setSelectedNodeName(
          entry.config?.topology.entry || entry.node_names?.[0] || undefined,
        );
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
    if (!draft) {
      setValidation(undefined);
      setValidating(false);
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

  useEffect(() => {
    if (!draft) {
      setGraph(EMPTY_GRAPH);
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

  return {
    shell,
    loading,
    error,
    detail,
    draft,
    selectedNodeName,
    graph,
    validation,
    validating,
    selectNode: setSelectedNodeName,
  };
}
