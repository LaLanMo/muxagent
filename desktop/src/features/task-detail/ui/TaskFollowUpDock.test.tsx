import assert from "node:assert/strict";
import test from "node:test";
import { renderToStaticMarkup } from "react-dom/server";
import type {
  ConfigCatalogEntryDto,
  FollowUpModeDto,
  TaskFollowUpDto,
} from "@/rpc/types";
import { TaskFollowUpDock } from "@/features/task-detail/ui/TaskDetailPanels";

function makeConfigEntries(): ConfigCatalogEntryDto[] {
  return [
    {
      alias: "default",
      config_path: "/tmp/workspace/.muxagent/configs/default.yaml",
      is_default: true,
      runtime_explicit: false,
      runtime_configured: true,
      builtin: false,
      launchable: true,
    },
    {
      alias: "review",
      config_path: "/tmp/workspace/.muxagent/configs/review.yaml",
      is_default: false,
      runtime_explicit: true,
      runtime_configured: true,
      builtin: false,
      launchable: true,
      node_names: ["plan", "review"],
    },
  ];
}

function makeFollowUp(defaultMode: FollowUpModeDto = "continue_here"): TaskFollowUpDto {
  return {
    default_mode: defaultMode,
    available_modes: ["continue_here", "fork_head", "fork_with_changes"],
    uncommitted_change_count: 3,
  };
}

function renderDock(props: {
  followUp?: TaskFollowUpDto;
  followUpState?: "basic" | "pending" | "refine";
  followUpMode?: FollowUpModeDto;
}) {
  return renderToStaticMarkup(
    <TaskFollowUpDock
      configEntries={makeConfigEntries()}
      defaultConfigAlias="default"
      followUp={props.followUp}
      followUpConfigAlias={undefined}
      followUpDescription=""
      followUpMode={props.followUpMode}
      followUpState={props.followUpState}
      onConfigChange={() => {}}
      onModeChange={() => {}}
      onStartFollowUp={async () => {}}
      setFollowUpDescription={() => {}}
      submittingFollowUp={false}
    />,
  );
}

test("basic dock hides the fixed continue-here control for non-repo tasks", () => {
  const markup = renderDock({ followUpState: "basic" });

  assert.doesNotMatch(markup, /follow-up-mode-fixed/);
  assert.doesNotMatch(markup, /follow-up-mode-trigger/);
  assert.doesNotMatch(markup, /Continue here/);
});

test("refine dock renders the repo-backed mode trigger and dirty hint", () => {
  const markup = renderDock({
    followUp: makeFollowUp(),
    followUpMode: "fork_head",
    followUpState: "refine",
  });

  assert.match(markup, /follow-up-mode-trigger/);
  assert.match(markup, /Fork from HEAD/);
  assert.match(markup, /3 uncommitted/);
});

test("refine dock renders continue-here without an uncommitted hint", () => {
  const markup = renderDock({
    followUp: makeFollowUp(),
    followUpMode: "continue_here",
    followUpState: "refine",
  });

  assert.match(markup, /follow-up-mode-trigger/);
  assert.match(markup, /Continue here/);
  assert.doesNotMatch(markup, /follow-up-dirty-hint/);
  assert.doesNotMatch(markup, /3 uncommitted/);
});

test("refine dock renders fork-with-changes with the dirty hint", () => {
  const markup = renderDock({
    followUp: makeFollowUp(),
    followUpMode: "fork_with_changes",
    followUpState: "refine",
  });

  assert.match(markup, /follow-up-mode-trigger/);
  assert.match(markup, /Fork with changes/);
  assert.match(markup, /3 uncommitted/);
});

test("pending dock shows a resolving pill while follow-up detail loads", () => {
  const markup = renderDock({
    followUpState: "pending",
  });

  assert.match(markup, /follow-up-mode-pending/);
  assert.match(markup, /Resolving follow-up modes…/);
});
