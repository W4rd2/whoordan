import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  createDownloadSession,
  createInstallLink,
  getProtectedIPA,
  getProtectedManifest,
} from "../src/server/download";
import { createPasswordHash } from "../src/server/password";

const originalEnv = { ...process.env };

describe("private distribution routes", () => {
  let releaseDir: string;

  beforeEach(async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-05-20T10:00:00Z"));
    releaseDir = join(tmpdir(), `whoordan-release-${crypto.randomUUID()}`);
    mkdirSync(releaseDir, { recursive: true });
    writeFileSync(join(releaseDir, "Whoordan.ipa"), "signed ipa bytes");

    process.env = {
      ...originalEnv,
      WHOORDAN_DOWNLOAD_PASSWORD_HASH: await createPasswordHash("correct horse battery staple", "test-salt"),
      WHOORDAN_DOWNLOAD_TOKEN_SECRET: "test-token-secret-with-at-least-32-bytes",
      WHOORDAN_RELEASE_STORAGE_DIR: releaseDir,
      WHOORDAN_PUBLIC_BASE_URL: "https://whoordan.w4rd2.tech",
      WHOORDAN_BUNDLE_IDENTIFIER: "com.w4rd2.whoordan",
      WHOORDAN_RELEASE_VERSION: "1.2.3",
      WHOORDAN_RELEASE_BUILD: "123",
      WHOORDAN_IPA_FILENAME: "Whoordan.ipa",
    };
  });

  afterEach(() => {
    vi.useRealTimers();
    process.env = { ...originalEnv };
    rmSync(releaseDir, { recursive: true, force: true });
  });

  it("rejects bad passwords with a generic error", async () => {
    const result = await createDownloadSession({
      password: "wrong",
      ip: "198.51.100.10",
      userAgent: "vitest",
    });

    expect(result.ok).toBe(false);
    expect(result.status).toBe(401);
    expect(result.error).toBe("Unable to authorize download.");
  });

  it("rate limits repeated failed password attempts", async () => {
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await createDownloadSession({ password: "wrong", ip: "198.51.100.11" });
    }

    const limited = await createDownloadSession({ password: "wrong", ip: "198.51.100.11" });

    expect(limited.ok).toBe(false);
    expect(limited.status).toBe(429);
    expect(limited.error).toBe("Unable to authorize download.");
  });

  it("issues a short-lived token after a valid password", async () => {
    const result = await createDownloadSession({
      password: "correct horse battery staple",
      ip: "198.51.100.12",
    });

    expect(result.ok).toBe(true);
    expect(result.cookie?.httpOnly).toBe(true);
    expect(result.cookie?.secure).toBe(true);
    expect(result.cookie?.maxAge).toBeLessThanOrEqual(900);
    expect(result.token).toMatch(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  });

  it("protects the manifest and emits an HTTPS OTA plist for signed builds", async () => {
    const session = await createDownloadSession({
      password: "correct horse battery staple",
      ip: "198.51.100.13",
    });
    if (!session.ok) throw new Error("expected session");

    const manifest = await getProtectedManifest({ token: session.token });

    expect(manifest.status).toBe(200);
    expect(manifest.contentType).toBe("application/xml");
    expect(manifest.body).toContain("<key>bundle-identifier</key>");
    expect(manifest.body).toContain("com.w4rd2.whoordan");
    expect(manifest.body).toContain("<key>bundle-version</key>");
    expect(manifest.body).toContain("<string>123</string>");
    expect(manifest.body).toContain("https://whoordan.w4rd2.tech/protected/Whoordan.ipa?token=");
  });

  it("uses the configured IPA filename in the protected manifest", async () => {
    process.env.WHOORDAN_IPA_FILENAME = "Whoordan-adhoc.ipa";
    writeFileSync(join(releaseDir, "Whoordan-adhoc.ipa"), "custom signed ipa bytes");
    const session = await createDownloadSession({
      password: "correct horse battery staple",
      ip: "198.51.100.17",
    });
    if (!session.ok) throw new Error("expected session");

    const manifest = await getProtectedManifest({ token: session.token });
    const ipa = await getProtectedIPA({ token: session.token });

    expect(manifest.body).toContain("https://whoordan.w4rd2.tech/protected/Whoordan-adhoc.ipa?token=");
    expect(ipa.body?.toString("utf8")).toBe("custom signed ipa bytes");
  });

  it("denies expired tokens for manifest and IPA access", async () => {
    const session = await createDownloadSession({
      password: "correct horse battery staple",
      ip: "198.51.100.14",
    });
    if (!session.ok) throw new Error("expected session");

    vi.setSystemTime(new Date("2026-05-20T10:16:00Z"));

    await expect(getProtectedManifest({ token: session.token })).resolves.toMatchObject({ status: 401 });
    await expect(getProtectedIPA({ token: session.token })).resolves.toMatchObject({ status: 401 });
  });

  it("protects IPA bytes behind the token", async () => {
    const session = await createDownloadSession({
      password: "correct horse battery staple",
      ip: "198.51.100.15",
    });
    if (!session.ok) throw new Error("expected session");

    const denied = await getProtectedIPA({});
    const allowed = await getProtectedIPA({ token: session.token });

    expect(denied.status).toBe(401);
    expect(allowed.status).toBe(200);
    expect(allowed.contentType).toBe("application/octet-stream");
    expect(allowed.body?.toString("utf8")).toBe("signed ipa bytes");
  });

  it("creates an itms-services install URL with a protected manifest URL", async () => {
    const session = await createDownloadSession({
      password: "correct horse battery staple",
      ip: "198.51.100.16",
    });
    if (!session.ok) throw new Error("expected session");

    const link = await createInstallLink({ token: session.token });

    expect(link.status).toBe(200);
    expect(link.installUrl.startsWith("itms-services://?action=download-manifest&url=")).toBe(true);
    expect(decodeURIComponent(link.installUrl)).toContain("https://whoordan.w4rd2.tech/protected/manifest.plist?token=");
  });
});
