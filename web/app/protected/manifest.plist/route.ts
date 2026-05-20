import { NextRequest, NextResponse } from "next/server";
import { getProtectedManifest } from "../../../src/server/download";
import { securityHeaders } from "../../../src/server/env";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get("token") ?? request.cookies.get("whoordan_download")?.value;
  const result = await getProtectedManifest({ token });
  if (result.status !== 200) {
    return new NextResponse("Unauthorized", { status: 401, headers: securityHeaders() });
  }
  return new NextResponse(result.body, {
    status: 200,
    headers: {
      ...securityHeaders(),
      "Content-Type": result.contentType ?? "application/xml",
    },
  });
}
