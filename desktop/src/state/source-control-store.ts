import { create } from "zustand";
import type {
  GitCheckoutDetailDto,
  GitDiffDto,
  WorkspaceGitStatusResult,
} from "@/rpc/types";

type StatusEntry = {
  loading: boolean;
  data?: WorkspaceGitStatusResult;
  error?: string;
};

type CheckoutEntry = {
  loading: boolean;
  data?: GitCheckoutDetailDto;
  error?: string;
};

type DiffEntry = {
  loading: boolean;
  data?: GitDiffDto;
  error?: string;
};

interface SourceControlState {
  statusByWorkspace: Record<string, StatusEntry>;
  checkoutByKey: Record<string, CheckoutEntry>;
  fileDiffByKey: Record<string, DiffEntry>;
  commitDiffByKey: Record<string, DiffEntry>;
  setStatus: (workspaceId: string, entry: StatusEntry) => void;
  setCheckout: (key: string, entry: CheckoutEntry) => void;
  setFileDiff: (key: string, entry: DiffEntry) => void;
  setCommitDiff: (key: string, entry: DiffEntry) => void;
  reset: () => void;
}

export const useSourceControlStore = create<SourceControlState>((set) => ({
  statusByWorkspace: {},
  checkoutByKey: {},
  fileDiffByKey: {},
  commitDiffByKey: {},
  setStatus: (workspaceId, entry) =>
    set((state) => ({
      statusByWorkspace: {
        ...state.statusByWorkspace,
        [workspaceId]: entry,
      },
    })),
  setCheckout: (key, entry) =>
    set((state) => ({
      checkoutByKey: {
        ...state.checkoutByKey,
        [key]: entry,
      },
    })),
  setFileDiff: (key, entry) =>
    set((state) => ({
      fileDiffByKey: {
        ...state.fileDiffByKey,
        [key]: entry,
      },
    })),
  setCommitDiff: (key, entry) =>
    set((state) => ({
      commitDiffByKey: {
        ...state.commitDiffByKey,
        [key]: entry,
      },
    })),
  reset: () =>
    set({
      statusByWorkspace: {},
      checkoutByKey: {},
      fileDiffByKey: {},
      commitDiffByKey: {},
    }),
}));

export function checkoutCacheKey(
  workspaceId: string,
  checkoutPath: string,
): string {
  return `${workspaceId}::${checkoutPath}`;
}

export function fileDiffCacheKey(
  workspaceId: string,
  checkoutPath: string,
  fileId: string,
): string {
  return `${workspaceId}::${checkoutPath}::${fileId}`;
}

export function commitDiffCacheKey(
  workspaceId: string,
  checkoutPath: string,
  commitHash: string,
): string {
  return `${workspaceId}::${checkoutPath}::${commitHash}`;
}
