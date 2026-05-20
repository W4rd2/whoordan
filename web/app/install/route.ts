import { NextRequest, NextResponse } from "next/server";
import { createInstallLink } from "../../src/server/download";
import { securityHeaders } from "../../src/server/env";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get("token") ?? request.cookies.get("whoordan_download")?.value;
  const result = await createInstallLink({ token });
  if (result.status !== 200) {
    return NextResponse.json({ error: "Unable to authorize download." }, { status: 401, headers: securityHeaders() });
  }
  return NextResponse.json({ installUrl: result.installUrl }, { headers: securityHeaders() });
}
