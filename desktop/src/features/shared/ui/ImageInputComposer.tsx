import {
  useEffect,
  useRef,
  useState,
  type ClipboardEvent,
  type DragEvent,
  type FormEvent as ReactFormEvent,
  type KeyboardEvent as ReactKeyboardEvent,
  type Ref,
} from "react";
import { ImagePlus, X } from "lucide-react";
import {
  attachmentOverflowCount,
  imageFilesToDraftAttachments,
  type DraftImageAttachment,
} from "@/features/shared/model/image-attachments";

type ImageInputComposerProps = {
  value: string;
  onValueChange: (value: string) => void;
  attachments: DraftImageAttachment[];
  onAttachmentsChange: (attachments: DraftImageAttachment[]) => void;
  className?: string;
  textareaClassName?: string;
  label?: string;
  ariaLabel?: string;
  placeholder?: string;
  rows?: number;
  disabled?: boolean;
  textareaTestId?: string;
  testId?: string;
  maxVisibleAttachments?: number;
  dropLabel?: string;
  textareaRef?: Ref<HTMLTextAreaElement>;
  onTextareaInput?: (event: ReactFormEvent<HTMLTextAreaElement>) => void;
  onTextareaKeyDown?: (event: ReactKeyboardEvent<HTMLTextAreaElement>) => void;
};

function joinClassNames(...parts: Array<string | false | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function fileListToImages(files: FileList | File[]): File[] {
  return Array.from(files).filter((file) => file.type.startsWith("image/"));
}

function assignRef<T>(ref: Ref<T> | undefined, value: T | null) {
  if (!ref) {
    return;
  }
  if (typeof ref === "function") {
    ref(value);
    return;
  }
  (ref as { current: T | null }).current = value;
}

export function ImageInputComposer({
  value,
  onValueChange,
  attachments,
  onAttachmentsChange,
  className,
  textareaClassName,
  label,
  ariaLabel,
  placeholder,
  rows = 3,
  disabled = false,
  textareaTestId,
  testId = "image-input-composer",
  maxVisibleAttachments = 4,
  dropLabel = "Drop image to attach",
  textareaRef,
  onTextareaInput,
  onTextareaKeyDown,
}: ImageInputComposerProps) {
  const [dragDepth, setDragDepth] = useState(0);
  const [error, setError] = useState<string | undefined>();
  const knownUrlsRef = useRef<Set<string>>(new Set());
  const isDragging = dragDepth > 0;

  useEffect(() => {
    const nextUrls = new Set(attachments.map((attachment) => attachment.objectUrl));
    for (const objectUrl of knownUrlsRef.current) {
      if (!nextUrls.has(objectUrl)) {
        URL.revokeObjectURL(objectUrl);
      }
    }
    knownUrlsRef.current = nextUrls;
  }, [attachments]);

  useEffect(() => {
    return () => {
      for (const objectUrl of knownUrlsRef.current) {
        URL.revokeObjectURL(objectUrl);
      }
      knownUrlsRef.current = new Set();
    };
  }, []);

  async function addFiles(files: File[]) {
    if (disabled || files.length === 0) {
      return;
    }
    const result = await imageFilesToDraftAttachments(files, attachments.length);
    if (result.attachments.length > 0) {
      onAttachmentsChange([...attachments, ...result.attachments]);
    }
    setError(result.error);
  }

  function handleDragEnter(event: DragEvent<HTMLDivElement>) {
    if (disabled) {
      return;
    }
    event.preventDefault();
    setDragDepth((current) => current + 1);
  }

  function handleDragOver(event: DragEvent<HTMLDivElement>) {
    if (disabled) {
      return;
    }
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
  }

  function handleDragLeave(event: DragEvent<HTMLDivElement>) {
    if (disabled) {
      return;
    }
    event.preventDefault();
    setDragDepth((current) => Math.max(0, current - 1));
  }

  function handleDrop(event: DragEvent<HTMLDivElement>) {
    if (disabled) {
      return;
    }
    event.preventDefault();
    setDragDepth(0);
    void addFiles(fileListToImages(event.dataTransfer.files));
  }

  function handlePaste(event: ClipboardEvent<HTMLTextAreaElement>) {
    if (disabled) {
      return;
    }
    const files = fileListToImages(event.clipboardData.files);
    if (files.length === 0) {
      return;
    }
    event.preventDefault();
    void addFiles(files);
  }

  function removeAttachment(id: string) {
    const removed = attachments.find((attachment) => attachment.id === id);
    if (removed) {
      URL.revokeObjectURL(removed.objectUrl);
    }
    onAttachmentsChange(attachments.filter((attachment) => attachment.id !== id));
  }

  const visibleAttachments = attachments.slice(0, maxVisibleAttachments);
  const overflowCount = attachmentOverflowCount(attachments, maxVisibleAttachments);

  return (
    <div
      className={joinClassNames(
        "image-composer",
        isDragging && "image-composer--dragging",
        disabled && "image-composer--disabled",
        className,
      )}
      data-dragging={isDragging ? "true" : "false"}
      data-testid={testId}
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
    >
      {label ? <span className="image-composer__label">{label}</span> : null}
      <div className="image-composer__surface">
        {attachments.length > 0 ? (
          <div
            aria-label="Attached images"
            className="image-composer__attachments"
            data-testid={`${testId}-attachments`}
          >
            {visibleAttachments.map((attachment) => (
              <div
                className="image-composer__thumb"
                data-testid={`${testId}-attachment`}
                key={attachment.id}
              >
                <img alt="" draggable={false} src={attachment.objectUrl} />
                <span className="image-composer__thumb-name">{attachment.name}</span>
                <button
                  aria-label={`Remove ${attachment.name}`}
                  className="image-composer__remove"
                  data-testid={`${testId}-remove-${attachment.id}`}
                  disabled={disabled}
                  onClick={() => removeAttachment(attachment.id)}
                  type="button"
                >
                  <X aria-hidden="true" size={12} strokeWidth={2.2} />
                </button>
              </div>
            ))}
            {overflowCount > 0 ? (
              <span className="image-composer__overflow" data-testid={`${testId}-overflow`}>
                +{overflowCount}
              </span>
            ) : null}
          </div>
        ) : null}
        <textarea
          aria-label={ariaLabel}
          className={joinClassNames("image-composer__textarea", textareaClassName)}
          data-testid={textareaTestId}
          disabled={disabled}
          onChange={(event) => onValueChange(event.target.value)}
          onInput={onTextareaInput}
          onKeyDown={onTextareaKeyDown}
          onPaste={handlePaste}
          placeholder={placeholder}
          ref={(node) => assignRef(textareaRef, node)}
          rows={rows}
          value={value}
        />
        {isDragging ? (
          <div className="image-composer__drop-state" data-testid={`${testId}-drop-state`}>
            <ImagePlus aria-hidden="true" size={18} strokeWidth={1.9} />
            <span>{dropLabel}</span>
          </div>
        ) : null}
      </div>
      {error ? (
        <span className="image-composer__error" data-testid={`${testId}-error`}>
          {error}
        </span>
      ) : null}
    </div>
  );
}
