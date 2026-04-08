import type { ReactNode } from "react";
import ReactMarkdown, { type Components } from "react-markdown";
import remarkGfm from "remark-gfm";

export type DocumentContentFormat = "markdown" | "text";
export type DocumentContentVariant = "detail" | "compact";

type DocumentContentProps = {
  content?: string | null;
  format?: DocumentContentFormat;
  variant?: DocumentContentVariant;
  className?: string;
  emptyFallback?: ReactNode;
};

const markdownComponents: Components = {
  table({ children }) {
    return (
      <div className="markdown-document__table-scroll">
        <table>{children}</table>
      </div>
    );
  },
};

function joinClassNames(...parts: Array<string | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export function DocumentContent({
  content,
  format = "text",
  variant = "detail",
  className,
  emptyFallback = null,
}: DocumentContentProps) {
  if (!content) {
    return <>{emptyFallback}</>;
  }

  if (format === "markdown") {
    return (
      <article
        className={joinClassNames(
          "markdown-document",
          `markdown-document--${variant}`,
          className,
        )}
      >
        <ReactMarkdown components={markdownComponents} remarkPlugins={[remarkGfm]}>
          {content}
        </ReactMarkdown>
      </article>
    );
  }

  return (
    <pre
      className={joinClassNames(
        "document-content",
        `document-content--${variant}`,
        className,
      )}
    >
      {content}
    </pre>
  );
}
