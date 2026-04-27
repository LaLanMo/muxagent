import {
  ChevronDown,
  Loader,
  Paperclip,
  SendHorizontal,
  Square,
} from "lucide-react";
import type { ReactNode } from "react";
import { Button } from "@/features/shared/ui/Button";

export type ChatComposerControls = {
  runtime?: ReactNode;
  model?: ReactNode;
  mode?: ReactNode;
  cwd?: ReactNode;
};

type ChatComposerProps = {
  canCancel?: boolean;
  canSubmit: boolean;
  canceling?: boolean;
  cancelLabel?: string;
  controls?: ChatComposerControls;
  disabled?: boolean;
  placeholder?: string;
  sending: boolean;
  sendingLabel?: string;
  submitLabel?: string;
  value: string;
  onChange: (value: string) => void;
  onCancel?: () => void;
  onSubmit: () => void;
};

export function ChatComposer({
  canCancel = false,
  canSubmit,
  canceling = false,
  cancelLabel = "Stop",
  controls,
  disabled = false,
  placeholder = "Message",
  sending,
  sendingLabel = "Sending",
  submitLabel = "Send",
  value,
  onChange,
  onCancel,
  onSubmit,
}: ChatComposerProps) {
  const showCancel = canCancel || canceling;
  return (
    <form
      className="chat-composer"
      onSubmit={(event) => {
        event.preventDefault();
        if (canSubmit) {
          onSubmit();
        }
      }}
    >
      <textarea
        aria-label="Message"
        className="chat-composer__input"
        disabled={disabled || sending}
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={(event) => {
          if (
            (event.metaKey || event.ctrlKey) &&
            event.key === "Enter" &&
            canSubmit
          ) {
            event.preventDefault();
            onSubmit();
          }
        }}
        placeholder={placeholder}
        rows={2}
        value={value}
      />
      <div className="chat-composer__footer">
        <div className="chat-composer__pills" aria-label="Chat settings">
          {controls ? (
            <>
              {controls.runtime}
              {controls.model}
              {controls.mode}
              {controls.cwd}
            </>
          ) : (
            <button
              className="chat-composer__pill"
              disabled={disabled || sending}
              type="button"
            >
              <span>plan</span>
              <ChevronDown size={12} strokeWidth={1.8} />
            </button>
          )}
        </div>
        <div className="chat-composer__actions">
          <button
            aria-label="Attach file"
            className="chat-composer__icon-button"
            disabled
            title="Attachments are not available yet"
            type="button"
          >
            <Paperclip size={13} strokeWidth={1.8} />
          </button>
          {showCancel ? (
            <Button
              disabled={canceling || !onCancel}
              leadingIcon={
                canceling ? (
                  <Loader className="chat-composer__spinner" strokeWidth={2.1} />
                ) : (
                  <Square strokeWidth={2.1} />
                )
              }
              onClick={onCancel}
              size="md"
              type="button"
              variant="danger"
            >
              {canceling ? "Stopping" : cancelLabel}
            </Button>
          ) : (
            <Button
              disabled={!canSubmit}
              leadingIcon={
                sending ? (
                  <Loader className="chat-composer__spinner" strokeWidth={2.1} />
                ) : (
                  <SendHorizontal strokeWidth={2.1} />
                )
              }
              size="md"
              type="submit"
              variant="primary"
            >
              {sending ? sendingLabel : submitLabel}
            </Button>
          )}
        </div>
      </div>
    </form>
  );
}
