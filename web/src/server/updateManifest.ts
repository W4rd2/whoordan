export type WhoordanUpdateManifest = {
  bundleIdentifier: string;
  version: string;
  build: string;
  minimumOS: string;
  releaseNotes: string;
  installUrl: string;
};

export function buildUpdateManifest(): WhoordanUpdateManifest {
  const baseUrl = (process.env.WHOORDAN_PUBLIC_BASE_URL ?? "https://whoordan.w4rd2.tech").trim().replace(/\/+$/, "");
  if (!baseUrl.startsWith("https://")) {
    throw new Error("WHOORDAN_PUBLIC_BASE_URL must use HTTPS.");
  }

  return {
    bundleIdentifier: process.env.WHOORDAN_BUNDLE_IDENTIFIER ?? "com.w4rd2.whoordan",
    version: process.env.WHOORDAN_RELEASE_VERSION ?? "1.0.0",
    build: process.env.WHOORDAN_RELEASE_BUILD ?? "1",
    minimumOS: process.env.WHOORDAN_MINIMUM_OS ?? "17.0",
    releaseNotes: process.env.WHOORDAN_RELEASE_NOTES ?? "Private Whoordan build.",
    installUrl: `${baseUrl}/update`,
  };
}
