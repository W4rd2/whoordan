import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const landingSource = () => readFileSync(join(process.cwd(), "app", "LandingExperience.tsx"), "utf8");

describe("GSAP landing page contract", () => {
  it("uses scoped GSAP React cleanup with ScrollTrigger and reduced motion", () => {
    const source = landingSource();

    expect(source).toContain("useGSAP");
    expect(source).toContain("ScrollTrigger");
    expect(source).toContain("prefers-reduced-motion");
    expect(source).toContain("scope:");
  });

  it("does not ship production ScrollTrigger markers", () => {
    expect(landingSource()).not.toMatch(/markers\\s*:\\s*true/);
  });

  it("keeps motion on transform and opacity instead of layout properties", () => {
    const source = landingSource();

    expect(source).not.toMatch(/\b(width|height|top|left|right|bottom|margin|padding)\s*:/);
    expect(source).toMatch(/\b(x|y|scale|rotation|autoAlpha|opacity)\s*:/);
  });
});
