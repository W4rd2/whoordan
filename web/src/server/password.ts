import { randomUUID, scryptSync, timingSafeEqual } from "node:crypto";

const keyLength = 32;

export async function createPasswordHash(password: string, salt = randomUUID()): Promise<string> {
  const key = scryptSync(password, salt, keyLength).toString("base64url");
  return `scrypt$${salt}$${key}`;
}

export async function verifyPassword(password: string, encodedHash: string): Promise<boolean> {
  const [scheme, salt, expected] = encodedHash.split("$");
  if (scheme !== "scrypt" || !salt || !expected) {
    return false;
  }

  const actual = scryptSync(password, salt, keyLength);
  const expectedBuffer = Buffer.from(expected, "base64url");
  if (actual.byteLength !== expectedBuffer.byteLength) {
    return false;
  }
  return timingSafeEqual(actual, expectedBuffer);
}
