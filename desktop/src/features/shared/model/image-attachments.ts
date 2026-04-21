import type { ImageAttachmentInputDto } from "@/rpc/types";

export const IMAGE_ATTACHMENT_MAX_COUNT = 6;
export const IMAGE_ATTACHMENT_MAX_BYTES = 8 * 1024 * 1024;

export const IMAGE_ATTACHMENT_MIME_TYPES = new Set([
  "image/png",
  "image/jpeg",
  "image/gif",
  "image/webp",
]);

export type DraftImageAttachment = {
  id: string;
  name: string;
  mimeType: string;
  sizeBytes: number;
  dataBase64: string;
  objectUrl: string;
};

export type ImageAttachmentValidationResult =
  | { ok: true }
  | { ok: false; message: string };

export function validateImageFile(
  file: Pick<File, "name" | "size" | "type">,
): ImageAttachmentValidationResult {
  const mimeType = file.type.trim().toLowerCase();
  if (!IMAGE_ATTACHMENT_MIME_TYPES.has(mimeType)) {
    return { ok: false, message: `${file.name || "File"} is not a supported image` };
  }
  if (file.size <= 0) {
    return { ok: false, message: `${file.name || "Image"} is empty` };
  }
  if (file.size > IMAGE_ATTACHMENT_MAX_BYTES) {
    return {
      ok: false,
      message: `${file.name || "Image"} is larger than 8 MB`,
    };
  }
  return { ok: true };
}

export function attachmentOverflowCount(
  attachments: readonly DraftImageAttachment[],
  visibleCount: number,
): number {
  return Math.max(0, attachments.length - Math.max(0, visibleCount));
}

export function mapImageAttachmentsToDto(
  attachments: readonly DraftImageAttachment[],
): ImageAttachmentInputDto[] {
  return attachments.map((attachment) => ({
    name: attachment.name,
    mime_type: attachment.mimeType,
    size_bytes: attachment.sizeBytes,
    data_base64: attachment.dataBase64,
  }));
}

export function revokeImageAttachmentUrls(
  attachments: readonly DraftImageAttachment[],
): void {
  for (const attachment of attachments) {
    URL.revokeObjectURL(attachment.objectUrl);
  }
}

export async function imageFileToDraftAttachment(
  file: File,
): Promise<DraftImageAttachment> {
  const validation = validateImageFile(file);
  if (!validation.ok) {
    throw new Error(validation.message);
  }
  const bytes = new Uint8Array(await file.arrayBuffer());
  return {
    id: globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${file.name}`,
    name: file.name || "image",
    mimeType: file.type.trim().toLowerCase(),
    sizeBytes: file.size,
    dataBase64: bytesToBase64(bytes),
    objectUrl: URL.createObjectURL(file),
  };
}

export async function imageFilesToDraftAttachments(
  files: readonly File[],
  existingCount: number,
): Promise<{
  attachments: DraftImageAttachment[];
  error?: string;
}> {
  const remaining = Math.max(0, IMAGE_ATTACHMENT_MAX_COUNT - existingCount);
  if (remaining === 0) {
    return {
      attachments: [],
      error: `Attach up to ${IMAGE_ATTACHMENT_MAX_COUNT} images`,
    };
  }

  const acceptedFiles = files.slice(0, remaining);
  const skippedForLimit = files.length - acceptedFiles.length;
  const attachments: DraftImageAttachment[] = [];
  for (const file of acceptedFiles) {
    const validation = validateImageFile(file);
    if (!validation.ok) {
      return { attachments, error: validation.message };
    }
    attachments.push(await imageFileToDraftAttachment(file));
  }

  return {
    attachments,
    error:
      skippedForLimit > 0
        ? `Attached ${acceptedFiles.length}; ${skippedForLimit} skipped`
        : undefined,
  };
}

function bytesToBase64(bytes: Uint8Array): string {
  const bufferCtor = (
    globalThis as typeof globalThis & {
      Buffer?: { from(value: Uint8Array): { toString(encoding: "base64"): string } };
    }
  ).Buffer;
  if (bufferCtor) {
    return bufferCtor.from(bytes).toString("base64");
  }

  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}
