import { classifyExternalLinkHref } from "@/platform/external-links";

export type ExternalLinkClickResult =
  | {
      action: "ignored";
    }
  | {
      action: "blocked";
    }
  | {
      action: "opened";
      url: string;
    };

type ExternalLinkClickInput = {
  baseUrl: string;
  defaultPrevented: boolean;
  href: string | null | undefined;
  openExternalUrl(url: string): Promise<void> | void;
  preventDefault(): void;
};

type ExternalLinkClickGuardOptions = {
  document?: Document;
  getBaseUrl?: () => string;
  onError?: (error: unknown) => void;
  openExternalUrl(url: string): Promise<void> | void;
};

export async function handleExternalLinkClick({
  baseUrl,
  defaultPrevented,
  href,
  openExternalUrl,
  preventDefault,
}: ExternalLinkClickInput): Promise<ExternalLinkClickResult> {
  if (defaultPrevented || href == null) {
    return { action: "ignored" };
  }

  const classification = classifyExternalLinkHref(href, baseUrl);
  if (classification.kind === "internal") {
    return { action: "ignored" };
  }

  preventDefault();

  if (classification.kind === "blocked") {
    return { action: "blocked" };
  }

  await openExternalUrl(classification.url);
  return {
    action: "opened",
    url: classification.url,
  };
}

function findAnchorHref(target: EventTarget | null): string | null {
  if (
    typeof Element === "undefined" ||
    typeof Node === "undefined" ||
    !(target instanceof Node)
  ) {
    return null;
  }

  const element = target instanceof Element ? target : target.parentElement;
  const anchor = element?.closest<HTMLAnchorElement>("a[href]");
  return anchor?.getAttribute("href") ?? null;
}

export function installExternalLinkClickGuard({
  document: targetDocument = document,
  getBaseUrl = () => window.location.href,
  onError = (error) => console.error("Failed to open external URL", error),
  openExternalUrl,
}: ExternalLinkClickGuardOptions): () => void {
  const listener = (event: MouseEvent) => {
    const href = findAnchorHref(event.target);
    if (href == null) {
      return;
    }

    void handleExternalLinkClick({
      baseUrl: getBaseUrl(),
      defaultPrevented: event.defaultPrevented,
      href,
      openExternalUrl,
      preventDefault: () => event.preventDefault(),
    }).catch(onError);
  };

  targetDocument.addEventListener("click", listener, true);
  return () => {
    targetDocument.removeEventListener("click", listener, true);
  };
}
