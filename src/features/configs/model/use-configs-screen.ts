import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  cloneConfig,
  deleteConfig,
  refreshConfigCatalog,
  setDefaultConfig,
  suggestConfigAlias,
} from "@/application/configs";
import { getRuntime } from "@/app/runtime";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useConfigsScreen() {
  const navigate = useNavigate();
  const shell = useShellModel();
  const catalog = useWorkspaceStore((state) => state.catalog);
  const setCatalog = useWorkspaceStore((state) => state.setCatalog);
  const [busyAlias, setBusyAlias] = useState<string>();
  const [actionError, setActionError] = useState<string>();
  const [pendingRemoveAlias, setPendingRemoveAlias] = useState<string>();

  const entries = catalog?.entries ?? [];

  const cards = useMemo(
    () =>
      entries.map((entry) => ({
        ...entry,
        editLabel: "Edit",
        open: () => {
          navigate(`/configs/${encodeURIComponent(entry.alias)}`);
        },
        edit: async () => {
          navigate(`/configs/${encodeURIComponent(entry.alias)}`);
        },
        setDefault: async () => {
          setBusyAlias(entry.alias);
          setActionError(undefined);
          try {
            await setDefaultConfig(getRuntime(), entry.alias);
            const nextCatalog = await refreshConfigCatalog(getRuntime());
            setCatalog(nextCatalog);
          } catch (error) {
            setActionError(error instanceof Error ? error.message : "Failed to set default config");
          } finally {
            setBusyAlias(undefined);
          }
        },
        remove: async () => {
          setPendingRemoveAlias(entry.alias);
        },
      })),
    [entries, navigate, setCatalog],
  );

  const pendingRemoveEntry =
    pendingRemoveAlias == null
      ? undefined
      : entries.find((entry) => entry.alias === pendingRemoveAlias);

  async function confirmRemove() {
    if (!pendingRemoveEntry) {
      return;
    }
    const entry = pendingRemoveEntry;
    setPendingRemoveAlias(undefined);
    setBusyAlias(entry.alias);
    setActionError(undefined);
    try {
      await deleteConfig(getRuntime(), entry.alias);
      const nextCatalog = await refreshConfigCatalog(getRuntime());
      setCatalog(nextCatalog);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to delete config");
    } finally {
      setBusyAlias(undefined);
    }
  }

  function cancelRemove() {
    setPendingRemoveAlias(undefined);
  }

  async function createConfig() {
    const sourceAlias = catalog?.default_alias ?? entries[0]?.alias;
    if (!sourceAlias) {
      setActionError("No source config is available to customize");
      return;
    }
    const nextAlias = suggestConfigAlias(
      sourceAlias,
      entries.map((entry) => entry.alias),
    );
    setBusyAlias(sourceAlias);
    setActionError(undefined);
    try {
      const cloned = await cloneConfig(getRuntime(), sourceAlias, nextAlias);
      const nextCatalog = await refreshConfigCatalog(getRuntime());
      setCatalog(nextCatalog);
      navigate(`/configs/${encodeURIComponent(cloned.alias)}`);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to create config");
    } finally {
      setBusyAlias(undefined);
    }
  }

  return {
    shell,
    entries: cards,
    count: entries.length,
    actionError,
    busyAlias,
    pendingRemoveEntry,
    confirmRemove,
    cancelRemove,
    createConfig,
  };
}
