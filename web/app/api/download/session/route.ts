import { NextRequest, NextResponse } from "next/server";
import { createDownloadSession } from "../../../../src/server/download";
import { securityHeaders } from "../../../../src/server/env";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const body = (await request.json().catch(() => ({}))) as { password?: string };
  const result = await createDownloadSession({
    password: body.password ?? "",
    ip: request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown",
    userAgent: request.headers.get("user-agent") ?? undefined,
  });

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status, headers: securityHeaders() });
  }

  const response = NextResponse.json({ ok: true, token: result.token }, { headers: securityHeaders() });
  response.cookies.set(result.cookie.name, result.cookie.value, {
    httpOnly: result.cookie.httpOnly,
    secure: result.cookie.secure,
    sameSite: result.cookie.sameSite,
    path: result.cookie.path,
    maxAge: result.cookie.maxAge,
  });
  return response;
}
