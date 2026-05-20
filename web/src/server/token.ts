import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";

type DownloadTokenPayload = {
  exp: number;
  nonce: string;
  scope: "download";
};

const defaultTTLSeconds = 15 * 60;

function base64url(input: string | Buffer): string {
  return Buffer.from(input).toString("base64url");
}

function sign(payload: string, secret: string): string {
  return createHmac("sha256", secret).update(payload).digest("base64url");
}

export function createDownloadToken(secret: string, now = Date.now(), ttlSeconds = defaultTTLSeconds): string {
  const payload: DownloadTokenPayload = {
    exp: Math.floor(now / 1000) + ttlSeconds,
    nonce: randomUUID(),
    scope: "download",
  };
  const encodedPayload = base64url(JSON.stringify(payload));
  return `${encodedPayload}.${sign(encodedPayload, secret)}`;
}

export function verifyDownloadToken(token: string | undefined, secret: string, now = Date.now()): boolean {
  if (!token) {
    return false;
  }
  const [payloadPart, signaturePart] = token.split(".");
  if (!payloadPart || !signaturePart) {
    return false;
  }
  const expectedSignature = Buffer.from(sign(payloadPart, secret), "base64url");
  const actualSignature = Buffer.from(signaturePart, "base64url");
  if (expectedSignature.byteLength !== actualSignature.byteLength || !timingSafeEqual(expectedSignature, actualSignature)) {
    return false;
  }

  try {
    const payload = JSON.parse(Buffer.from(payloadPart, "base64url").toString("utf8")) as DownloadTokenPayload;
    return payload.scope === "download" && payload.exp > Math.floor(now / 1000);
  } catch {
    return false;
  }
}

export const downloadTokenTTLSeconds = defaultTTLSeconds;
