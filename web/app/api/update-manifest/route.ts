import { NextResponse } from "next/server";
import { securityHeaders } from "../../../src/server/env";
import { buildUpdateManifest } from "../../../src/server/updateManifest";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json(buildUpdateManifest(), {
    headers: securityHeaders(),
  });
}
