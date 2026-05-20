export type ReleaseConfig = {
  baseUrl: string;
  bundleIdentifier: string;
  version: string;
  build: string;
  minimumOS: string;
  releaseNotes: string;
  ipaFilename: string;
  releaseStorageDir: string;
  tokenSecret: string;
  passwordHash: string;
  githubUrl?: string;
};

export function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable ${name}`);
  }
  return value;
}

export function releaseConfig(): ReleaseConfig {
  const baseUrl = (process.env.WHOORDAN_PUBLIC_BASE_URL ?? "https://whoordan.w4rd2.tech").trim().replace(/\/+$/, "");
  if (!baseUrl.startsWith("https://")) {
    throw new Error("WHOORDAN_PUBLIC_BASE_URL must use HTTPS.");
  }

  return {
    baseUrl,
    bundleIdentifier: process.env.WHOORDAN_BUNDLE_IDENTIFIER ?? "com.w4rd2.whoordan",
    version: process.env.WHOORDAN_RELEASE_VERSION ?? "1.0.0",
    build: process.env.WHOORDAN_RELEASE_BUILD ?? "1",
    minimumOS: process.env.WHOORDAN_MINIMUM_OS ?? "17.0",
    releaseNotes: process.env.WHOORDAN_RELEASE_NOTES ?? "Private Whoordan build.",
    ipaFilename: process.env.WHOORDAN_IPA_FILENAME ?? "Whoordan.ipa",
    releaseStorageDir: requiredEnv("WHOORDAN_RELEASE_STORAGE_DIR"),
    tokenSecret: requiredEnv("WHOORDAN_DOWNLOAD_TOKEN_SECRET"),
    passwordHash: requiredEnv("WHOORDAN_DOWNLOAD_PASSWORD_HASH"),
    githubUrl: process.env.WHOORDAN_GITHUB_URL?.trim() || undefined,
  };
}

export function securityHeaders(): Record<string, string> {
  return {
    "Cache-Control": "no-store, private",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
  };
}
