import { Loader, SendHorizontal } from "lucide-react";
import { Button } from "@/features/shared/ui/Button";

type ChatComposerProps = {
  canSubmit: boolean;
  disabled?: boolean;
  placeholder?: string;
  sending: boolean;
  sendingLabel?: string;
  submitLabel?: string;
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
};

export function ChatComposer({
  canSubmit,
  disabled = false,
  placeholder = "Message",
  sending,
  sendingLabel = "Sending",
  submitLabel = "Send",
  value,
  onChange,
  onSubmit,
}: ChatComposerProps) {
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
        className="chat-composer__input"
        disabled={disabled || sending}
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={(event) => {
          if ((event.metaKey || event.ctrlKey) && event.key === "Enter" && canSubmit) {
            event.preventDefault();
            onSubmit();
          }
        }}
        placeholder={placeholder}
        rows={4}
        value={value}
      />
      <div className="chat-composer__footer">
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
      </div>
    </form>
  );
}
