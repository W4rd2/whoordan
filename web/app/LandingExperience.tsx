"use client";

import { useRef, useState } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";

gsap.registerPlugin(ScrollTrigger, useGSAP);

type LandingExperienceProps = {
  githubUrl?: string;
};

export default function LandingExperience({ githubUrl }: LandingExperienceProps) {
  const root = useRef<HTMLElement>(null);
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [isSubmitting, setSubmitting] = useState(false);

  useGSAP(
    () => {
      const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
      if (reduceMotion.matches) {
        gsap.set(".reveal", { autoAlpha: 1, y: 0 });
        return;
      }

      gsap.set(".reveal", { autoAlpha: 0, y: 28 });
      gsap.to(".hero-device", {
        y: -24,
        rotation: -2,
        scale: 1.02,
        ease: "power3.out",
        scrollTrigger: {
          trigger: ".hero",
          start: "top top",
          end: "bottom top",
          scrub: 1,
        },
      });
      gsap.to(".reveal", {
        autoAlpha: 1,
        y: 0,
        duration: 0.8,
        stagger: 0.08,
        ease: "power4.out",
        scrollTrigger: {
          trigger: ".signal-grid",
          start: "top 72%",
          toggleActions: "play none none reverse",
        },
      });
      gsap.to(".pinned-device", {
        x: 18,
        y: -18,
        scale: 1.04,
        ease: "none",
        scrollTrigger: {
          trigger: ".product-moment",
          start: "top top",
          end: "+=120%",
          scrub: 1,
          pin: true,
        },
      });
    },
    { scope: root },
  );

  async function submitPassword(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setMessage("");
    try {
      const response = await fetch("/api/download/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });
      if (!response.ok) {
        setMessage("Unable to authorize download.");
        return;
      }
      const payload = (await response.json()) as { token: string };
      const install = await fetch(`/install?token=${encodeURIComponent(payload.token)}`, { cache: "no-store" });
      const installPayload = (await install.json()) as { installUrl?: string };
      if (installPayload.installUrl) {
        window.location.href = installPayload.installUrl;
        return;
      }
      setMessage("Unable to authorize download.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main ref={root} className="site-shell">
      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">Private recovery intelligence</p>
          <h1>Whoordan</h1>
          <p className="lede">
            A native iPhone companion for sleep, strain, recovery, movement, haptics, and Apple Health signals,
            built around local-first wellness data.
          </p>
          <div className="hero-actions">
            <a href="#download" className="button primary">Private install</a>
            {githubUrl ? <a href={githubUrl} className="button secondary">GitHub</a> : null}
          </div>
        </div>
        <div className="phone-frame hero-device" aria-hidden="true">
          <div className="phone-screen">
            <span className="score">92</span>
            <span className="score-label">Recovered</span>
            <div className="ring one" />
            <div className="ring two" />
            <div className="metric-row"><span>Sleep</span><strong>8h 04m</strong></div>
            <div className="metric-row"><span>Strain</span><strong>11.8</strong></div>
            <div className="metric-row"><span>HRV</span><strong>64 ms</strong></div>
          </div>
        </div>
      </section>

      <section className="signal-grid" aria-label="Whoordan focus areas">
        <article className="reveal">
          <span>01</span>
          <h2>Recovery without cloud pressure</h2>
          <p>Approved users can keep health records local, with cloud health sync staying separate and consent-gated.</p>
        </article>
        <article className="reveal">
          <span>02</span>
          <h2>Health signals in context</h2>
          <p>Sleep, movement, heart rate, HRV, haptics, and wearable checkpoints resolve into one native view.</p>
        </article>
        <article className="reveal">
          <span>03</span>
          <h2>Private build channel</h2>
          <p>Signed iOS builds are distributed only through Apple-valid private installation paths.</p>
        </article>
      </section>

      <section className="product-moment">
        <div className="moment-copy">
          <p className="eyebrow">Native iOS, deliberate motion</p>
          <h2>Daily readiness, not medical claims.</h2>
          <p>
            Whoordan stays in the wellness and fitness domain: no diagnosis, no treatment promises, no silent updates,
            and no hidden health-data upload.
          </p>
        </div>
        <div className="phone-frame pinned-device" aria-hidden="true">
          <div className="phone-screen alt">
            <div className="timeline-line" />
            <div className="timeline-card">Resting heart rate steady</div>
            <div className="timeline-card">Deep sleep trending up</div>
            <div className="timeline-card">Update available: 1.2.3 (123)</div>
          </div>
        </div>
      </section>

      <section id="download" className="download-panel">
        <div>
          <p className="eyebrow">Protected private install</p>
          <h2>Enter Ward’s download password.</h2>
          <p>
            The install route requires a short-lived token and a signed Apple-valid IPA. If signing prerequisites are
            missing, this page will be ready while the Apple step remains blocked.
          </p>
        </div>
        <form onSubmit={submitPassword} className="download-form">
          <label htmlFor="download-password">Password</label>
          <input
            id="download-password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="current-password"
            required
          />
          <button type="submit" disabled={isSubmitting}>
            {isSubmitting ? "Checking..." : "Unlock install"}
          </button>
          {message ? <p role="status" className="form-message">{message}</p> : null}
        </form>
      </section>
    </main>
  );
}
