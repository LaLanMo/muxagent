import assert from "node:assert/strict";
import test from "node:test";
import { renderToStaticMarkup } from "react-dom/server";
import type { DraftImageAttachment } from "@/features/shared/model/image-attachments";
import { ImageInputComposer } from "@/features/shared/ui/ImageInputComposer";

function makeAttachment(index: number): DraftImageAttachment {
  return {
    id: `image-${index}`,
    name: `image-${index}.png`,
    mimeType: "image/png",
    sizeBytes: 4,
    dataBase64: "AAAAAA==",
    objectUrl: `blob:image-${index}`,
  };
}

test("ImageInputComposer renders thumbnails, overflow, remove controls, and textarea", () => {
  const markup = renderToStaticMarkup(
    <ImageInputComposer
      ariaLabel="Task description"
      attachments={[1, 2, 3, 4, 5, 6].map(makeAttachment)}
      maxVisibleAttachments={4}
      onAttachmentsChange={() => undefined}
      onValueChange={() => undefined}
      rows={3}
      testId="composer"
      textareaTestId="composer-text"
      value="Describe this"
    />,
  );

  assert.match(markup, /data-testid="composer-attachments"/);
  assert.equal((markup.match(/data-testid="composer-attachment"/g) ?? []).length, 4);
  assert.match(markup, /data-testid="composer-overflow"/);
  assert.match(markup, />\+2</);
  assert.match(markup, /aria-label="Remove image-1\.png"/);
  assert.match(markup, /data-testid="composer-text"/);
  assert.doesNotMatch(markup, /data-testid="composer-file-input"/);
  assert.doesNotMatch(markup, /aria-label="Attach image"/);
  assert.match(markup, /rows="3"/);
  assert.match(markup, /Describe this/);
});

test("ImageInputComposer renders disabled state on controls", () => {
  const markup = renderToStaticMarkup(
    <ImageInputComposer
      attachments={[makeAttachment(1)]}
      disabled
      onAttachmentsChange={() => undefined}
      onValueChange={() => undefined}
      testId="composer"
      value=""
    />,
  );

  assert.match(markup, /image-composer--disabled/);
  assert.match(markup, /disabled=""/);
});
