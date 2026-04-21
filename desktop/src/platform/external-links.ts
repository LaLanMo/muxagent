export type ExternalLinkClassification =
  | {
      kind: "external-web";
      url: string;
    }
  | {
      kind: "internal";
    }
  | {
      kind: "blocked";
    };

const explicitSchemePattern = /^[a-zA-Z][a-zA-Z\d+.-]*:/;

function hasExplicitScheme(href: string): boolean {
  return explicitSchemePattern.test(href);
}

function isProtocolRelative(href: string): boolean {
  return href.startsWith("//");
}

function isRelativeHref(href: string): boolean {
  return !hasExplicitScheme(href) && !isProtocolRelative(href);
}

function hasSameOrigin(url: URL, baseUrl: string): boolean {
  try {
    return url.origin === new URL(baseUrl).origin;
  } catch {
    return false;
  }
}

export function classifyExternalLinkHref(
  href: string | null | undefined,
  baseUrl: string,
): ExternalLinkClassification {
  const value = href?.trim() ?? "";
  if (!value) {
    return { kind: "blocked" };
  }

  let url: URL;
  try {
    url = new URL(value, baseUrl);
  } catch {
    return { kind: "blocked" };
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    return isRelativeHref(value) ? { kind: "internal" } : { kind: "blocked" };
  }

  if (!url.host) {
    return { kind: "blocked" };
  }

  if (isRelativeHref(value) || hasSameOrigin(url, baseUrl)) {
    return { kind: "internal" };
  }

  return {
    kind: "external-web",
    url: url.href,
  };
}
