import { useEffect, useEffectEvent } from "react";
import { getCommitDiff, getFileDiff } from "@/application/source-control";
import { getRuntime } from "@/app/runtime";
import type { GitFileBucketDto } from "@/rpc/types";
import {
  commitDiffCacheKey,
  fileDiffCacheKey,
  useSourceControlStore,
} from "@/state/source-control-store";

function parseFileId(fileId: string): {
  bucket: GitFileBucketDto;
  filePath: string;
} {
  const idx = fileId.indexOf(":");
  if (idx < 0) {
    return { bucket: "unstaged", filePath: fileId };
  }
  const rawBucket = fileId.slice(0, idx);
  const filePath = fileId.slice(idx + 1);
  const bucket: GitFileBucketDto =
    rawBucket === "staged" ||
    rawBucket === "unstaged" ||
    rawBucket === "untracked" ||
    rawBucket === "conflicted"
      ? rawBucket
      : "unstaged";
  return { bucket, filePath };
}

export function useFileDiff(
  workspaceId: string | undefined,
  checkoutPath: string | undefined,
  fileId: string | undefined,
) {
  const key =
    workspaceId && checkoutPath && fileId
      ? fileDiffCacheKey(workspaceId, checkoutPath, fileId)
      : undefined;
  const entry = useSourceControlStore((state) =>
    key ? state.fileDiffByKey[key] : undefined,
  );
  const setFileDiff = useSourceControlStore((state) => state.setFileDiff);

  const load = useEffectEvent(
    async (wid: string, path: string, id: string) => {
      const cacheKey = fileDiffCacheKey(wid, path, id);
      setFileDiff(cacheKey, { loading: true, data: entry?.data });
      try {
        const { bucket, filePath } = parseFileId(id);
        const result = await getFileDiff({
          runtime: getRuntime(),
          workspaceId: wid,
          checkoutPath: path,
          filePath,
          bucket,
        });
        setFileDiff(cacheKey, { loading: false, data: result.diff });
      } catch (error) {
        setFileDiff(cacheKey, {
          loading: false,
          error:
            error instanceof Error ? error.message : "Failed to load file diff",
        });
      }
    },
  );

  useEffect(() => {
    if (!workspaceId || !checkoutPath || !fileId) return;
    if (entry?.loading || entry?.data) return;
    void load(workspaceId, checkoutPath, fileId);
  }, [
    checkoutPath,
    entry?.data,
    entry?.loading,
    fileId,
    load,
    workspaceId,
  ]);

  return {
    loading: entry?.loading ?? false,
    data: entry?.data,
    error: entry?.error,
  };
}

export function useCommitDiff(
  workspaceId: string | undefined,
  checkoutPath: string | undefined,
  commitHash: string | undefined,
) {
  const key =
    workspaceId && checkoutPath && commitHash
      ? commitDiffCacheKey(workspaceId, checkoutPath, commitHash)
      : undefined;
  const entry = useSourceControlStore((state) =>
    key ? state.commitDiffByKey[key] : undefined,
  );
  const setCommitDiff = useSourceControlStore((state) => state.setCommitDiff);

  const load = useEffectEvent(
    async (wid: string, path: string, hash: string) => {
      const cacheKey = commitDiffCacheKey(wid, path, hash);
      setCommitDiff(cacheKey, { loading: true, data: entry?.data });
      try {
        const result = await getCommitDiff({
          runtime: getRuntime(),
          workspaceId: wid,
          checkoutPath: path,
          commitHash: hash,
        });
        setCommitDiff(cacheKey, { loading: false, data: result.diff });
      } catch (error) {
        setCommitDiff(cacheKey, {
          loading: false,
          error:
            error instanceof Error
              ? error.message
              : "Failed to load commit diff",
        });
      }
    },
  );

  useEffect(() => {
    if (!workspaceId || !checkoutPath || !commitHash) return;
    if (entry?.loading || entry?.data) return;
    void load(workspaceId, checkoutPath, commitHash);
  }, [
    checkoutPath,
    commitHash,
    entry?.data,
    entry?.loading,
    load,
    workspaceId,
  ]);

  return {
    loading: entry?.loading ?? false,
    data: entry?.data,
    error: entry?.error,
  };
}
