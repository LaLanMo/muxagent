import assert from "node:assert/strict";
import test from "node:test";
import { renderToStaticMarkup } from "react-dom/server";
import type { TranscriptSnapshot } from "@/domain/session-history";
import type { NodeRunViewDto } from "@/rpc/types";
import { TaskTranscriptModal } from "@/features/task-detail/ui/TaskDetailPanels";

function makeRun(): NodeRunViewDto {
  return {
    id: "run-1",
    task_id: "task-1",
    node_name: "handle_request",
    status: "done",
    session_id: "session-1234567890",
    started_at: "2026-04-18T08:00:00.000Z",
    completed_at: "2026-04-18T08:00:12.000Z",
    artifact_paths: [],
  };
}

function makeTranscript(): TranscriptSnapshot {
  return {
    nodeRunId: "run-1",
    sessionId: "session-1234567890",
    provenance: "replay",
    events: [],
    messages: {},
    messageOrder: [],
    tools: {},
    toolOrder: [],
    completeness: "complete",
    replayEventCount: 0,
    liveEventCount: 0,
    hasStructuredEvents: false,
  };
}

test("transcript modal meta row renders the resolved runtime name", () => {
  const markup = renderToStaticMarkup(
    <TaskTranscriptModal
      clarificationItems={[]}
      displayTranscriptItems={[]}
      isCurrentRun={false}
      rawTranscriptItems={[]}
      run={makeRun()}
      runtimeName="Codex"
      showEmptyOutput
      streamLines={[]}
      streamSource="replay"
      transcript={makeTranscript()}
    />,
  );

  assert.match(markup, />Runtime</);
  assert.match(markup, />Codex</);
  assert.match(markup, />Session</);
});
