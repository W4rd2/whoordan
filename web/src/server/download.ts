import { readFileSync } from "node:fs";
import { join } from "node:path";
import { clearAttempts, canAttempt, recordFailedAttempt } from "./rateLimit";
import { downloadTokenTTLSeconds, createDownloadToken, verifyDownloadToken } from "./token";
import { releaseConfig } from "./env";
import { verifyPassword } from "./password";

type DownloadSessionInput = {
  password: string;
  ip: string;
  userAgent?: string;
};

type DownloadFailure = {
  ok: false;
  status: 401 | 429;
  error: "Unable to authorize download.";
};

type DownloadSuccess = {
  ok: true;
  status: 200;
  token: string;
  cookie: {
    name: string;
    value: string;
    httpOnly: true;
    secure: true;
    sameSite: "strict";
    path: string;
    maxAge: number;
  };
};

type ProtectedTextResponse = {
  status: number;
  contentType?: string;
  body?: string;
};

type ProtectedBinaryResponse = {
  status: number;
  contentType?: string;
  body?: Buffer;
};

export async function createDownloadSession(input: DownloadSessionInput): Promise<DownloadSuccess | DownloadFailure> {
  const key = `${input.ip}:${input.userAgent ?? "unknown"}`;
  if (!canAttempt(key)) {
    return unauthorized(429);
  }

  const config = releaseConfig();
  const isValid = await verifyPassword(input.password, config.passwordHash);
  if (!isValid) {
    recordFailedAttempt(key);
    return unauthorized(401);
  }

  clearAttempts(key);
  const token = createDownloadToken(config.tokenSecret);
  return {
    ok: true,
    status: 200,
    token,
    cookie: {
      name: "whoordan_download",
      value: token,
      httpOnly: true,
      secure: true,
      sameSite: "strict",
      path: "/",
      maxAge: downloadTokenTTLSeconds,
    },
  };
}

export async function getProtectedManifest(input: { token?: string }): Promise<ProtectedTextResponse> {
  const config = releaseConfig();
  if (!verifyDownloadToken(input.token, config.tokenSecret)) {
    return { status: 401 };
  }

  const ipaUrl = `${config.baseUrl}/protected/${encodeURIComponent(config.ipaFilename)}?token=${encodeURIComponent(input.token ?? "")}`;
  return {
    status: 200,
    contentType: "application/xml",
    body: buildOTAManifest({
      ipaUrl,
      bundleIdentifier: config.bundleIdentifier,
      bundleVersion: config.build,
      title: "Whoordan",
    }),
  };
}

export async function getProtectedIPA(input: { token?: string }): Promise<ProtectedBinaryResponse> {
  const config = releaseConfig();
  if (!verifyDownloadToken(input.token, config.tokenSecret)) {
    return { status: 401 };
  }

  return {
    status: 200,
    contentType: "application/octet-stream",
    body: readFileSync(join(config.releaseStorageDir, config.ipaFilename)),
  };
}

export async function createInstallLink(input: { token?: string }): Promise<{ status: number; installUrl: string }> {
  const config = releaseConfig();
  if (!verifyDownloadToken(input.token, config.tokenSecret)) {
    return { status: 401, installUrl: "" };
  }

  const manifestUrl = `${config.baseUrl}/protected/manifest.plist?token=${encodeURIComponent(input.token ?? "")}`;
  return {
    status: 200,
    installUrl: `itms-services://?action=download-manifest&url=${encodeURIComponent(manifestUrl)}`,
  };
}

function unauthorized(status: 401 | 429): DownloadFailure {
  return { ok: false, status, error: "Unable to authorize download." };
}

function buildOTAManifest(input: {
  ipaUrl: string;
  bundleIdentifier: string;
  bundleVersion: string;
  title: string;
}): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${escapeXML(input.ipaUrl)}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${escapeXML(input.bundleIdentifier)}</string>
        <key>bundle-version</key>
        <string>${escapeXML(input.bundleVersion)}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${escapeXML(input.title)}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>`;
}

function escapeXML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}
