import { afterEach, describe, expect, it } from "vitest";
import { buildUpdateManifest } from "../src/server/updateManifest";

const originalEnv = { ...process.env };

describe("update manifest generation", () => {
  afterEach(() => {
    process.env = { ...originalEnv };
  });

  it("generates the minimal public update manifest without user or health fields", () => {
    process.env = {
      ...originalEnv,
      WHOORDAN_BUNDLE_IDENTIFIER: "com.w4rd2.whoordan",
      WHOORDAN_RELEASE_VERSION: "1.2.3",
      WHOORDAN_RELEASE_BUILD: "123",
      WHOORDAN_MINIMUM_OS: "17.0",
      WHOORDAN_RELEASE_NOTES: "Refined recovery trends and private install flow.",
      WHOORDAN_PUBLIC_BASE_URL: "https://whoordan.w4rd2.tech",
    };

    const manifest = buildUpdateManifest();

    expect(manifest).toEqual({
      bundleIdentifier: "com.w4rd2.whoordan",
      version: "1.2.3",
      build: "123",
      minimumOS: "17.0",
      releaseNotes: "Refined recovery trends and private install flow.",
      installUrl: "https://whoordan.w4rd2.tech/update",
    });
    expect(JSON.stringify(manifest)).not.toMatch(/user|health|analytics|device|email/i);
  });
});
