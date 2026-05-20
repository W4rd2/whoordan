import { NextRequest, NextResponse } from "next/server";
import { getProtectedIPA } from "../../../src/server/download";
import { releaseConfig, securityHeaders } from "../../../src/server/env";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest, context: { params: Promise<{ file: string }> }) {
  const { file } = await context.params;
  const config = releaseConfig();
  if (file !== config.ipaFilename) {
    return new NextResponse("Not found", { status: 404, headers: securityHeaders() });
  }

  const token = request.nextUrl.searchParams.get("token") ?? request.cookies.get("whoordan_download")?.value;
  const result = await getProtectedIPA({ token });
  if (result.status !== 200 || !result.body) {
    return new NextResponse("Unauthorized", { status: 401, headers: securityHeaders() });
  }

  return new NextResponse(new Uint8Array(result.body), {
    status: 200,
    headers: {
      ...securityHeaders(),
      "Content-Type": result.contentType ?? "application/octet-stream",
      "Content-Disposition": `attachment; filename="${safeDownloadFilename(config.ipaFilename)}"`,
    },
  });
}

function safeDownloadFilename(filename: string): string {
  return filename.replace(/["\r\n\\]/g, "_");
}
