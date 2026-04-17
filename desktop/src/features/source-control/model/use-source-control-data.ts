import { useEffect, useEffectEvent } from "react";
import {
  getWorkspaceCheckoutStatus,
  getWorkspaceGitStatus,
} from "@/application/source-control";
import { getRuntime } from "@/app/runtime";
import {
  checkoutCacheKey,
  useSourceControlStore,
} from "@/state/source-control-store";

export function useWorkspaceStatus(workspaceId: string | undefined) {
  const entry = useSourceControlStore((state) =>
    workspaceId ? state.statusByWorkspace[workspaceId] : undefined,
  );
  const setStatus = useSourceControlStore((state) => state.setStatus);

  const load = useEffectEvent(async (id: string) => {
    setStatus(id, { loading: true, data: entry?.data });
    try {
      const data = await getWorkspaceGitStatus(getRuntime(), id);
      setStatus(id, { loading: false, data });
    } catch (error) {
      setStatus(id, {
        loading: false,
        error:
          error instanceof Error
            ? error.message
            : "Failed to load source control",
      });
    }
  });

  useEffect(() => {
    if (!workspaceId) return;
    if (entry?.loading || entry?.data) return;
    void load(workspaceId);
  }, [entry?.data, entry?.loading, load, workspaceId]);

  return {
    loading: entry?.loading ?? false,
    data: entry?.data,
    error: entry?.error,
    reload: () => {
      if (workspaceId) void load(workspaceId);
    },
  };
}

export function useCheckoutDetail(
  workspaceId: string | undefined,
  checkoutPath: string | undefined,
) {
  const key =
    workspaceId && checkoutPath
      ? checkoutCacheKey(workspaceId, checkoutPath)
      : undefined;
  const entry = useSourceControlStore((state) =>
    key ? state.checkoutByKey[key] : undefined,
  );
  const setCheckout = useSourceControlStore((state) => state.setCheckout);

  const load = useEffectEvent(async (wid: string, path: string) => {
    const cacheKey = checkoutCacheKey(wid, path);
    setCheckout(cacheKey, {
      loading: true,
      data: entry?.data,
    });
    try {
      const result = await getWorkspaceCheckoutStatus({
        runtime: getRuntime(),
        workspaceId: wid,
        checkoutPath: path,
        fileLimit: 200,
      });
      setCheckout(cacheKey, { loading: false, data: result.checkout });
    } catch (error) {
      setCheckout(cacheKey, {
        loading: false,
        error:
          error instanceof Error
            ? error.message
            : "Failed to load checkout details",
      });
    }
  });

  useEffect(() => {
    if (!workspaceId || !checkoutPath) return;
    if (entry?.loading || entry?.data) return;
    void load(workspaceId, checkoutPath);
  }, [checkoutPath, entry?.data, entry?.loading, load, workspaceId]);

  return {
    loading: entry?.loading ?? false,
    data: entry?.data,
    error: entry?.error,
  };
}
