import { useEffect, useState } from "react";
import {
  readArtifactPreview,
  type ArtifactPreview,
} from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import type { ArtifactRefDto } from "@/rpc/types";

type ArtifactTextPreview = Extract<ArtifactPreview, { kind: "markdown" | "text" }>;

export type TaskDetailArtifactPreview = ArtifactTextPreview | {
  kind: "image";
  url: string;
  mimeType: string;
  byteLength: number;
};

export function useTaskDetailArtifactPreview(
  selectedArtifact: ArtifactRefDto | undefined,
) {
  const [artifactPreview, setArtifactPreview] = useState<
    TaskDetailArtifactPreview | undefined
  >();
  const [artifactError, setArtifactError] = useState<string | undefined>();

  useEffect(() => {
    if (!selectedArtifact) {
      setArtifactPreview(undefined);
      setArtifactError(undefined);
      return;
    }
    let cancelled = false;
    let objectUrl: string | undefined;
    setArtifactPreview(undefined);
    setArtifactError(undefined);
    void readArtifactPreview(getRuntime(), selectedArtifact)
      .then((preview) => {
        if (cancelled) {
          return;
        }
        if (preview.kind === "image") {
          const imageBytes = new Uint8Array(preview.byteLength);
          imageBytes.set(preview.bytes);
          objectUrl = URL.createObjectURL(
            new Blob([imageBytes.buffer], { type: preview.mimeType }),
          );
          setArtifactPreview({
            kind: "image",
            url: objectUrl,
            mimeType: preview.mimeType,
            byteLength: preview.byteLength,
          });
          return;
        }
        setArtifactPreview(preview);
      })
      .catch((error) => {
        if (!cancelled) {
          setArtifactError(
            error instanceof Error ? error.message : "Failed to read artifact",
          );
        }
      });
    return () => {
      cancelled = true;
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [selectedArtifact]);

  return {
    artifactPreview,
    artifactError,
  };
}
