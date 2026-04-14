import { useEffect, useState } from "react";
import { readArtifactPreview } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import type { ArtifactRefDto } from "@/rpc/types";

export function useTaskDetailArtifactPreview(
  selectedArtifact: ArtifactRefDto | undefined,
) {
  const [artifactContent, setArtifactContent] = useState<string | undefined>();
  const [artifactError, setArtifactError] = useState<string | undefined>();

  useEffect(() => {
    if (!selectedArtifact) {
      setArtifactContent(undefined);
      setArtifactError(undefined);
      return;
    }
    let cancelled = false;
    setArtifactContent(undefined);
    setArtifactError(undefined);
    void readArtifactPreview(getRuntime(), selectedArtifact)
      .then((content) => {
        if (!cancelled) {
          setArtifactContent(content);
        }
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
    };
  }, [selectedArtifact]);

  return {
    artifactContent,
    artifactError,
  };
}
