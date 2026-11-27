// A looping bouncing ball for each section's banner. It is hands-off: every time a section is opened
// from the sidebar (even the one already open) the ball drops in from above, settles, then loops on its own.
import { createContext, useContext, useEffect, useRef } from "react";

const W = 1000, H = 110, BASE = 96, R = 11;
const HOP_S = 0.52, SQUASH_S = 0.07;
const DROP_S = 0.9, DROP_FROM = -46;
const RIPPLE_S = 0.42;

// App bumps this number on every sidebar click, which replays the drop-in.
export const BouncePlay = createContext(0);

const SCENES = {
  topics: { pts: [[60, BASE], [230, BASE], [340, BASE], [520, BASE], [620, BASE], [800, BASE], [940, BASE]], lifts: [70, 26, 70, 26, 70, 26], ground: "flat" },
  games: { pts: [[60, BASE], [210, 78], [360, 60], [510, 72], [660, 46], [810, 30], [940, 30]], ground: "ledges" },
  players: { pts: [[70, 82], [230, 64], [380, 88], [540, 58], [700, 80], [860, 62]], ground: "pins" },
  money: { pts: [[80, 88], [220, 80], [360, 70], [500, 60], [640, 46], [780, 28], [920, 12]], ground: "columns" },
  time: { pts: [[50, 90], [200, 86], [350, 80], [500, 70], [650, 54], [800, 40], [950, 34]], ground: "line" },
  design: { pts: [[120, BASE - 14], [420, BASE], [620, BASE], [760, BASE], [860, BASE]], lifts: [92, 58, 34, 18], ground: "spring" },
  method: { pts: [[300, BASE], [440, BASE], [580, BASE], [720, BASE]], lifts: [60, 60, 60], ground: "box" },
};

function Ground({ kind, pts }) {
  if (kind === "flat") return <line className="bn-ground" x1="0" x2={W} y1={BASE} y2={BASE} />;
  if (kind === "line") return <polyline className="bn-ground" points={pts.map(([x, y]) => `${x},${y}`).join(" ")} />;
  if (kind === "ledges") return pts.map(([x, y], i) => <line key={i} className="bn-ledge" x1={x - 34} x2={x + 34} y1={y} y2={y} />);
  if (kind === "pins") return (
    <>
      <polyline className="bn-route" points={pts.map(([x, y]) => `${x},${y}`).join(" ")} />
      {pts.map(([x, y], i) => <circle key={i} className="bn-pin" cx={x} cy={y + 4} r="4" />)}
    </>
  );
  if (kind === "columns") return (
    <>
      <line className="bn-ground" x1="0" x2={W} y1={BASE + 8} y2={BASE + 8} />
      {pts.map(([x, y], i) => <rect key={i} className="bn-col" x={x - 22} y={y} width="44" height={BASE + 8 - y} rx="3" />)}
    </>
  );
  if (kind === "spring") return (
    <>
      <line className="bn-ground" x1="0" x2={W} y1={BASE} y2={BASE} />
      <path className="bn-spring" d={`M${pts[0][0] - 34},${BASE - 14} h68 M${pts[0][0] - 28},${BASE} l7,-14 l7,14 l7,-14 l7,14 l7,-14 l7,14 l7,-14 l7,14`} />
    </>
  );
  if (kind === "box") {
    const l = pts[0][0] - 40, r = pts[pts.length - 1][0] + 40;
    return <path className="bn-ground" d={`M${l},${BASE - 84} V${BASE} H${r} V${BASE - 84}`} />;
  }
  return null;
}

// Height above the landing spot during the drop-in: a fall, then two shrinking settle hops.
// Returns [offset, squash 0..1].
function dropOffset(t) {
  const fall = 0.42, hop1 = 0.24, hop2 = 0.14;
  if (t < fall) { const u = t / fall; return [(1 - u * u) * (0 - DROP_FROM), 0]; }
  let s = t - fall;
  const hop = (len, h) => { const u = s / len; return 4 * h * u * (1 - u); };
  if (s < hop1) return [hop(hop1, 18), s < SQUASH_S ? 1 - s / SQUASH_S : 0];
  s -= hop1;
  if (s < hop2) return [hop(hop2, 6), s < SQUASH_S * 0.7 ? 0.6 * (1 - s / (SQUASH_S * 0.7)) : 0];
  return [0, 0];
}

export function Bouncer({ scene }) {
  const s = SCENES[scene];
  const play = useContext(BouncePlay);
  const ball = useRef(null);
  const ripple = useRef(null);
  const pts = s.pts;
  const path = [...pts, ...pts.slice(1, -1).reverse()];
  const lifts = s.lifts ? [...s.lifts, ...s.lifts.slice(0, pts.length - 2).reverse()] : null;

  useEffect(() => {
    const el = ball.current, rp = ripple.current;
    if (!el) return;
    const place = (x, y, sq) => el.setAttribute("transform", `translate(${x.toFixed(1)} ${y.toFixed(1)}) scale(${1 + 0.22 * sq} ${1 - 0.22 * sq})`);
    const [sx, sy] = pts[0];
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) { place(sx, sy, 0); return; }

    let raf, start = null, lastHop = 0, rippleAt = null, rippleX = 0, rippleY = 0;
    const land = (now, x, y) => { rippleAt = now; rippleX = x; rippleY = y; };
    const n = path.length;

    const frame = (now) => {
      start ??= now;
      const t = (now - start) / 1000;
      if (t < DROP_S) {
        const [off, sq] = dropOffset(t);
        if (sq > 0.95 && (rippleAt == null || now - rippleAt > 150)) land(now, sx, sy);
        place(sx, sy - off, sq);
      } else {
        const lt = (t - DROP_S) % (n * HOP_S);
        const i = Math.floor(lt / HOP_S), u = (lt - i * HOP_S) / HOP_S;
        if (i !== lastHop) { lastHop = i; land(now, path[i][0], path[i][1]); }
        const [x0, y0] = path[i], [x1, y1] = path[(i + 1) % n];
        const lift = lifts ? lifts[i % lifts.length] : 24 + Math.abs(y1 - y0) * 0.5;
        const cx = (x0 + x1) / 2, cy = Math.min(y0, y1) - 2 * lift;
        const a = (1 - u) * (1 - u), b = 2 * (1 - u) * u, c = u * u;
        const x = a * x0 + b * cx + c * x1, y = a * y0 + b * cy + c * y1;
        const toLand = Math.min(u, 1 - u) * HOP_S;
        place(x, y, toLand < SQUASH_S ? 1 - toLand / SQUASH_S : 0);
      }
      if (rp) {
        const k = rippleAt == null ? 1 : (now - rippleAt) / 1000 / RIPPLE_S;
        if (k < 1) {
          rp.setAttribute("cx", rippleX.toFixed(1));
          rp.setAttribute("cy", rippleY.toFixed(1));
          rp.setAttribute("rx", (6 + 22 * k).toFixed(1));
          rp.setAttribute("ry", (2 + 5 * k).toFixed(1));
          rp.style.opacity = String(0.55 * (1 - k));
        } else rp.style.opacity = "0";
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [scene, play]);

  return (
    <div className="bouncer-wrap">
      <svg className="bouncer" viewBox={`0 -40 ${W} ${H + 48}`} aria-hidden="true" preserveAspectRatio="xMinYMax meet">
        <Ground kind={s.ground} pts={pts} />
        <ellipse ref={ripple} className="bn-ripple" cx={pts[0][0]} cy={pts[0][1]} rx="6" ry="2" style={{ opacity: 0 }} />
        <g ref={ball} transform={`translate(${pts[0][0]} ${pts[0][1] + DROP_FROM})`}>
          <circle r={R} cy={-R} className="ball" />
          <circle r={R * 0.3} cx={-R * 0.38} cy={-R * 1.38} className="ball-shine" />
        </g>
      </svg>
    </div>
  );
}
