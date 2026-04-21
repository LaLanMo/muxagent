import assert from "node:assert/strict";
import test from "node:test";
import {
  IMAGE_ATTACHMENT_MAX_BYTES,
  attachmentOverflowCount,
  mapImageAttachmentsToDto,
  validateImageFile,
  type DraftImageAttachment,
} from "@/features/shared/model/image-attachments";

function makeAttachment(id: string): DraftImageAttachment {
  return {
    id,
    name: `${id}.png`,
    mimeType: "image/png",
    sizeBytes: 4,
    dataBase64: "AAAAAA==",
    objectUrl: `blob:${id}`,
  };
}

test("validateImageFile accepts supported images within the size limit", () => {
  assert.deepEqual(
    validateImageFile({
      name: "screen.png",
      size: 128,
      type: "image/png",
    } as File),
    { ok: true },
  );
});

test("validateImageFile rejects unsupported and oversized files", () => {
  assert.deepEqual(
    validateImageFile({
      name: "notes.txt",
      size: 128,
      type: "text/plain",
    } as File),
    { ok: false, message: "notes.txt is not a supported image" },
  );
  assert.deepEqual(
    validateImageFile({
      name: "huge.png",
      size: IMAGE_ATTACHMENT_MAX_BYTES + 1,
      type: "image/png",
    } as File),
    { ok: false, message: "huge.png is larger than 8 MB" },
  );
});

test("attachmentOverflowCount reports hidden thumbnail count", () => {
  const attachments = ["a", "b", "c", "d", "e", "f"].map(makeAttachment);

  assert.equal(attachmentOverflowCount(attachments, 4), 2);
  assert.equal(attachmentOverflowCount(attachments.slice(0, 2), 4), 0);
});

test("mapImageAttachmentsToDto strips preview-only fields", () => {
  assert.deepEqual(mapImageAttachmentsToDto([makeAttachment("screen")]), [
    {
      name: "screen.png",
      mime_type: "image/png",
      size_bytes: 4,
      data_base64: "AAAAAA==",
    },
  ]);
});
