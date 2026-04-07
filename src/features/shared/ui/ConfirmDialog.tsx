type ConfirmDialogProps = {
  open: boolean;
  title: string;
  body: string;
  confirmLabel?: string;
  cancelLabel?: string;
  confirmDisabled?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
};

export function ConfirmDialog({
  open,
  title,
  body,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  confirmDisabled = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  if (!open) {
    return null;
  }

  return (
    <div className="modal-layer" data-testid="confirm-dialog">
      <div className="modal-scrim" onClick={onCancel} />
      <section className="confirm-modal">
        <header className="confirm-modal__header">
          <h2>{title}</h2>
        </header>

        <div className="confirm-modal__body">
          <p>{body}</p>
        </div>

        <footer className="confirm-modal__footer">
          <button className="secondary-action" onClick={onCancel} type="button">
            {cancelLabel}
          </button>
          <button
            className="secondary-action secondary-action--danger"
            data-testid="confirm-dialog-submit"
            disabled={confirmDisabled}
            onClick={onConfirm}
            type="button"
          >
            {confirmLabel}
          </button>
        </footer>
      </section>
    </div>
  );
}
