import assert from "node:assert/strict";
import test from "node:test";
import { handleExternalLinkClick } from "@/platform/external-link-clicks";
import { classifyExternalLinkHref } from "@/platform/external-links";

const appUrl = "http://localhost:4173/workspaces/workspace-1/tasks/task-1";

test("classifyExternalLinkHref opens hosted http and https URLs externally", () => {
  assert.deepEqual(classifyExternalLinkHref("https://example.com", appUrl), {
    kind: "external-web",
    url: "https://example.com/",
  });
  assert.deepEqual(
    classifyExternalLinkHref("http://localhost:3000/path?x=1&y=2", appUrl),
    {
      kind: "external-web",
      url: "http://localhost:3000/path?x=1&y=2",
    },
  );
});

test("classifyExternalLinkHref preserves internal app navigation", () => {
  for (const href of [
    "/workspaces/workspace-1/tasks",
    "settings/about",
    "#activity",
    "?newTask=1",
    "http://localhost:4173/settings/about",
  ]) {
    assert.deepEqual(classifyExternalLinkHref(href, appUrl), { kind: "internal" });
  }
});

test("classifyExternalLinkHref blocks unsupported and malformed hrefs", () => {
  for (const href of [
    "",
    "   ",
    "file:///tmp/report.md",
    "javascript:alert(1)",
    "mailto:test@example.com",
    "muxagent://task/1",
    "http://",
  ]) {
    assert.deepEqual(classifyExternalLinkHref(href, appUrl), { kind: "blocked" });
  }
});

test("handleExternalLinkClick opens one external URL and prevents default once", async () => {
  let preventDefaultCount = 0;
  const openedUrls: string[] = [];

  const result = await handleExternalLinkClick({
    baseUrl: appUrl,
    defaultPrevented: false,
    href: "https://example.com/docs",
    openExternalUrl: (url) => {
      openedUrls.push(url);
    },
    preventDefault: () => {
      preventDefaultCount += 1;
    },
  });

  assert.deepEqual(result, {
    action: "opened",
    url: "https://example.com/docs",
  });
  assert.equal(preventDefaultCount, 1);
  assert.deepEqual(openedUrls, ["https://example.com/docs"]);
});

test("handleExternalLinkClick blocks unsupported schemes without opening", async () => {
  let preventDefaultCount = 0;
  const openedUrls: string[] = [];

  const result = await handleExternalLinkClick({
    baseUrl: appUrl,
    defaultPrevented: false,
    href: "javascript:alert(1)",
    openExternalUrl: (url) => {
      openedUrls.push(url);
    },
    preventDefault: () => {
      preventDefaultCount += 1;
    },
  });

  assert.deepEqual(result, { action: "blocked" });
  assert.equal(preventDefaultCount, 1);
  assert.deepEqual(openedUrls, []);
});

test("handleExternalLinkClick leaves internal and already handled clicks alone", async () => {
  let preventDefaultCount = 0;
  const openedUrls: string[] = [];
  const openExternalUrl = (url: string) => {
    openedUrls.push(url);
  };
  const preventDefault = () => {
    preventDefaultCount += 1;
  };

  assert.deepEqual(
    await handleExternalLinkClick({
      baseUrl: appUrl,
      defaultPrevented: false,
      href: "/settings/about",
      openExternalUrl,
      preventDefault,
    }),
    { action: "ignored" },
  );
  assert.deepEqual(
    await handleExternalLinkClick({
      baseUrl: appUrl,
      defaultPrevented: true,
      href: "https://example.com",
      openExternalUrl,
      preventDefault,
    }),
    { action: "ignored" },
  );

  assert.equal(preventDefaultCount, 0);
  assert.deepEqual(openedUrls, []);
});
