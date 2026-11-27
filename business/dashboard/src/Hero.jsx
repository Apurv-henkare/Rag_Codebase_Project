// Interactive physics & Aurora hero stage: the red ball drops onto 3 finding markers on load,
// and users can click/drag anywhere on the stage to launch it with real gravity, bounce restitution, and trails.
import { useEffect, useRef, useState } from "react";
import { IconArrowRight, IconReset } from "./components/Icons.jsx";

const PRESETS = {
  earth: { label: "Standard", gravity: 1380, bounce: 0.72, air: 0.996 },
  moon: { label: "Low gravity", gravity: 520, bounce: 0.82, air: 0.998 },
  arcade: { label: "Super bounce", gravity: 1550, bounce: 0.9, air: 0.998 },
};

const LANDINGS = [0.21, 0.51, 0.76];

export function Hero({ findings, onSelectFinding, theme, children }) {
  const wrapRef = useRef(null);
  const canvasRef = useRef(null);
  const [preset, setPreset] = useState("earth");
  const [stats, setStats] = useState({ bounces: 0, speed: 0, activeFinding: 0 });
  const [dragging, setDragging] = useState(false);

  const still = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const simRef = useRef({
    x: 42,
    y: 26,
    vx: 195,
    vy: 0,
    r: 14,
    squash: 0,
    bounces: 0,
    trail: [],
    ripples: [],
    drag: false,
    dragStart: null,
    pointer: null,
    w: 960,
    h: 210,
    ground: 174,
  });

  function launchDrop(mode = preset) {
    const s = simRef.current;
    const w = s.w || 960;
    s.x = Math.max(36, w * 0.045);
    s.y = 26;
    s.vx = Math.min(260, Math.max(150, w * 0.24));
    s.vy = mode === "moon" ? -40 : 10;
    s.bounces = 0;
    s.squash = 0;
    s.trail = [];
    s.ripples = [];
    setStats({ bounces: 0, speed: Math.round(Math.hypot(s.vx, s.vy)), activeFinding: 0 });
  }

  useEffect(() => {
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    if (!canvas || !wrap) return;

    const resize = () => {
      const rect = wrap.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = Math.max(300, Math.round(rect.width));
      const h = w < 640 ? 170 : 210;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      canvas.style.width = `${w}px`;
      canvas.style.height = `${h}px`;
      simRef.current.w = w;
      simRef.current.h = h;
      simRef.current.ground = h - 32;
    };

    resize();
    launchDrop(preset);

    const ro = new ResizeObserver(resize);
    ro.observe(wrap);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    let raf;
    let last = performance.now();
    let statTick = 0;

    const readColors = () => {
      const cs = getComputedStyle(document.documentElement);
      return {
        ball: cs.getPropertyValue("--ball").trim() || "#e0302b",
        axis: cs.getPropertyValue("--axis").trim() || "#c3cad2",
        ink2: cs.getPropertyValue("--ink-2").trim() || "#566270",
        love: cs.getPropertyValue("--love").trim() || "#257de0",
        mag: cs.getPropertyValue("--mag").trim() || "#00b894",
        isHud: theme === "hud",
      };
    };

    let colors = readColors();
    const frame = (now) => {
      const dt = Math.min(0.032, (now - last) / 1000);
      last = now;
      if (statTick % 20 === 0) colors = readColors();

      const s = simRef.current;
      const cfg = PRESETS[preset];
      const dpr = canvas.width / (s.w || 1);

      if (!still && !s.drag) {
        s.vy += cfg.gravity * dt;
        s.vx *= cfg.air;
        s.x += s.vx * dt;
        s.y += s.vy * dt;

        // Ground collision
        if (s.y >= s.ground - s.r) {
          s.y = s.ground - s.r;
          if (Math.abs(s.vy) > 48) {
            s.vy = -s.vy * cfg.bounce;
            s.squash = Math.min(1, Math.abs(s.vy) / 520);
            s.bounces += 1;
            s.ripples.push({ x: s.x, y: s.ground, r: 4, alpha: 0.75 });
          } else {
            s.vy = 0;
            s.vx *= 0.96;
          }
        }
        // Ceiling & side walls
        if (s.y < s.r + 4) {
          s.y = s.r + 4;
          s.vy = Math.abs(s.vy) * 0.75;
        }
        if (s.x > s.w - s.r - 8) {
          s.x = s.w - s.r - 8;
          s.vx = -Math.abs(s.vx) * 0.85;
          s.ripples.push({ x: s.w - 8, y: s.y, r: 4, alpha: 0.5 });
        } else if (s.x < s.r + 8) {
          s.x = s.r + 8;
          s.vx = Math.abs(s.vx) * 0.85;
          s.ripples.push({ x: 8, y: s.y, r: 4, alpha: 0.5 });
        }

        s.squash = Math.max(0, s.squash - dt * 5.2);
        const speed = Math.hypot(s.vx, s.vy);
        if (speed > 20) {
          s.trail.push({ x: s.x, y: s.y, alpha: 0.6 });
          if (s.trail.length > 36) s.trail.shift();
        }
      }

      // Draw frame
      ctx.save();
      ctx.scale(dpr, dpr);
      ctx.clearRect(0, 0, s.w, s.h);

      // Subtle Aurora glow in HUD/Dark or faint ambient glow
      if (colors.isHud) {
        const g = ctx.createRadialGradient(s.x, s.y, 4, s.x, s.y, 140);
        g.addColorStop(0, "rgba(0, 184, 148, 0.16)");
        g.addColorStop(0.5, "rgba(37, 125, 224, 0.08)");
        g.addColorStop(1, "rgba(0, 0, 0, 0)");
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, s.w, s.h);
      }

      // Ground line + finding ticks
      ctx.strokeStyle = colors.axis;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, s.ground);
      ctx.lineTo(s.w, s.ground);
      ctx.stroke();

      LANDINGS.forEach((ratio, idx) => {
        const lx = s.w * ratio;
        const near = Math.abs(s.x - lx) < s.w * 0.09;
        ctx.strokeStyle = near ? colors.ball : colors.ink2;
        ctx.lineWidth = near ? 2 : 1.25;
        ctx.beginPath();
        ctx.moveTo(lx, s.ground);
        ctx.lineTo(lx, s.ground + 12);
        ctx.stroke();

        ctx.fillStyle = near ? colors.ball : colors.ink2;
        ctx.beginPath();
        ctx.arc(lx, s.ground, near ? 4.5 : 3, 0, Math.PI * 2);
        ctx.fill();
        if (near && statTick % 6 === 0) {
          setStats((prev) => (prev.activeFinding === idx ? prev : { ...prev, activeFinding: idx }));
        }
      });

      // Motion trail
      s.trail.forEach((pt, i) => {
        pt.alpha *= 0.94;
        const t = i / s.trail.length;
        ctx.fillStyle = colors.isHud ? `rgba(0, 212, 170, ${pt.alpha * 0.45})` : `rgba(224, 48, 43, ${pt.alpha * 0.28})`;
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, Math.max(1.5, s.r * 0.42 * t), 0, Math.PI * 2);
        ctx.fill();
      });
      s.trail = s.trail.filter((pt) => pt.alpha > 0.03);

      // Impact ripples
      s.ripples.forEach((rp) => {
        rp.r += 48 * dt;
        rp.alpha -= 1.4 * dt;
        ctx.strokeStyle = colors.isHud ? `rgba(0, 212, 170, ${Math.max(0, rp.alpha)})` : `rgba(224, 48, 43, ${Math.max(0, rp.alpha)})`;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.ellipse(rp.x, rp.y, rp.r, rp.r * 0.3, 0, 0, Math.PI * 2);
        ctx.stroke();
      });
      s.ripples = s.ripples.filter((rp) => rp.alpha > 0);

      // Slingshot guide line when dragging
      if (s.drag && s.pointer) {
        ctx.strokeStyle = colors.love;
        ctx.lineWidth = 2;
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.moveTo(s.x, s.y);
        ctx.lineTo(s.pointer.x, s.pointer.y);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // Shadow under ball
      const hRatio = Math.max(0, 1 - (s.ground - s.r - s.y) / s.ground);
      ctx.fillStyle = `rgba(0, 0, 0, ${0.18 * hRatio})`;
      ctx.beginPath();
      ctx.ellipse(s.x, s.ground + 2, s.r * (0.65 + 0.55 * hRatio), 3.2, 0, 0, Math.PI * 2);
      ctx.fill();

      // Ball with squash & stretch
      const sx = 1 + 0.28 * s.squash;
      const sy = 1 - 0.24 * s.squash;
      ctx.save();
      ctx.translate(s.x, s.y);
      ctx.scale(sx, sy);

      if (colors.isHud) {
        ctx.strokeStyle = "rgba(0, 212, 170, 0.55)";
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.arc(0, 0, s.r + 5, 0, Math.PI * 2);
        ctx.stroke();
      }

      const grad = ctx.createRadialGradient(-s.r * 0.35, -s.r * 0.38, 1, 0, 0, s.r);
      grad.addColorStop(0, "#ff8b85");
      grad.addColorStop(0.35, colors.ball);
      grad.addColorStop(1, "#9c1915");
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(0, 0, s.r, 0, Math.PI * 2);
      ctx.fill();

      // Specular shine
      ctx.fillStyle = "rgba(255,255,255,0.48)";
      ctx.beginPath();
      ctx.arc(-s.r * 0.36, -s.r * 0.36, s.r * 0.26, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();

      ctx.restore();

      statTick += 1;
      if (statTick % 8 === 0) {
        const spd = Math.round(Math.hypot(s.vx, s.vy));
        setStats((prev) =>
          prev.bounces === s.bounces && prev.speed === spd ? prev : { ...prev, bounces: s.bounces, speed: spd }
        );
      }
      raf = requestAnimationFrame(frame);
    };

    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [preset, still, theme]);

  function getPos(e) {
    const rect = canvasRef.current.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  }

  function onPointerDown(e) {
    if (still) return;
    const p = getPos(e);
    const s = simRef.current;
    e.currentTarget.setPointerCapture?.(e.pointerId);
    s.drag = true;
    s.x = p.x;
    s.y = Math.min(p.y, s.ground - s.r);
    s.vx = 0;
    s.vy = 0;
    s.pointer = p;
    setDragging(true);
  }

  function onPointerMove(e) {
    const s = simRef.current;
    if (!s.drag) return;
    s.pointer = getPos(e);
  }

  function onPointerUp(e) {
    const s = simRef.current;
    if (!s.drag) return;
    const p = getPos(e);
    s.drag = false;
    setDragging(false);
    // Fling opposite to drag vector (slingshot), or gentle toss if clicked without dragging
    const dx = s.x - p.x;
    const dy = s.y - p.y;
    if (Math.hypot(dx, dy) > 8) {
      s.vx = dx * 5.4;
      s.vy = dy * 5.4;
    } else {
      s.vx = (p.x < s.w / 2 ? 1 : -1) * (170 + Math.random() * 90);
      s.vy = -340;
    }
    s.pointer = null;
  }

  return (
    <section className="hero" id="top">
      <div className="wrap">
        {children}

        <div className="hero-stage-card">
          <div className="hero-stage-bar">
            <div className="stage-controls" role="group" aria-label="Ball physics presets">
              {Object.entries(PRESETS).map(([k, cfg]) => (
                <button
                  key={k}
                  className="chip sm"
                  aria-pressed={preset === k}
                  onClick={() => { setPreset(k); launchDrop(k); }}
                >
                  {cfg.label}
                </button>
              ))}
              <button className="chip sm" onClick={() => launchDrop(preset)} aria-label="Replay ball drop">
                <IconReset size={13} /> Replay
              </button>
            </div>
            <div className="stage-telemetry" aria-live="off">
              <span className="tele-hint">{still ? "Reduced motion active" : "Click or drag to fling the ball"}</span>
              <span className="tele-pill">Bounces <strong>{stats.bounces}</strong></span>
              <span className="tele-pill">Velocity <strong>{stats.speed}</strong> px/s</span>
            </div>
          </div>

          <div className={`bounce-wrap${dragging ? " is-dragging" : ""}`} ref={wrapRef}>
            <canvas
              ref={canvasRef}
              className="bounce-canvas"
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
              aria-label="Interactive bouncing ball physics playground"
            />
          </div>

          <ul className="findings-grid">
            {findings.map((f, i) => (
              <li key={f.title}>
                <button
                  className={`finding-card${stats.activeFinding === i ? " is-near" : ""}`}
                  onClick={() => onSelectFinding?.(f.topic)}
                >
                  <span className="finding-top">
                    <span className="finding-idx">0{i + 1}</span>
                    <IconArrowRight size={14} />
                  </span>
                  <strong>{f.title}</strong>
                  <span>{f.text}</span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
