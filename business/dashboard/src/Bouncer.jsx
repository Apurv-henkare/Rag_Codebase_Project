// A looping bouncing ball for each section's banner. The ball hops from one landing spot to the next along a parabola
// (a quadratic curve whose control point sits at the middle of the hop, so x moves at a steady speed and y follows gravity),
// squashes when it lands, then hops back the other way. Each section gets its own terrain.
import { useEffect, useRef } from "react";

const W = 1000, H = 110, BASE = 96, R = 11;
const HOP_S = 0.52, SQUASH_S = 0.07;

// landing spots (x, y) and how each section draws the ground under them
const SCENES = {
  // praise and complaints: tall hops and short hops on flat ground
  topics: { pts: [[60, BASE], [230, BASE], [340, BASE], [520, BASE], [620, BASE], [800, BASE], [940, BASE]], lifts: [70, 26, 70, 26, 70, 26], ground: "flat" },
  // platform game: the ball climbs floating ledges
  games: { pts: [[60, BASE], [210, 78], [360, 60], [510, 72], [660, 46], [810, 30], [940, 30]], ground: "ledges" },
  // where players are: hops from pin to pin, like a route across a map
  players: { pts: [[70, 82], [230, 64], [380, 88], [540, 58], [700, 80], [860, 62]], ground: "pins" },
  // money: lands on top of columns that grow, the way installs pile up in a few games
  money: { pts: [[80, 88], [220, 80], [360, 70], [500, 60], [640, 46], [780, 28], [920, 12]], ground: "columns" },
  // over time: hops up a rising line
  time: { pts: [[50, 90], [200, 86], [350, 80], [500, 70], [650, 54], [800, 40], [950, 34]], ground: "line" },
  // design choices: a springboard sends the ball high, then it settles
  design: { pts: [[120, BASE - 14], [420, BASE], [620, BASE], [760, BASE], [860, BASE]], lifts: [92, 58, 34, 18], ground: "spring" },
  // how it was made: a ball in a test box, bouncing wall to wall
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

export function Bouncer({ scene }) {
  const s = SCENES[scene];
  const ball = useRef(null);
  const pts = s.pts;
  // forward then back, so the loop never jumps
  const path = [...pts, ...pts.slice(1, -1).reverse()];
  const lifts = s.lifts ? [...s.lifts, ...s.lifts.slice(0, pts.length - 2).reverse()] : null;
  useEffect(() => {
    const el = ball.current;
    if (!el) return;
    const place = (x, y, sq) => el.setAttribute("transform", `translate(${x.toFixed(1)} ${y.toFixed(1)}) scale(${1 + 0.22 * sq} ${1 - 0.22 * sq})`);
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) { place(pts[0][0], pts[0][1], 0); return; }
    let raf, t0;
    const n = path.length;
    const frame = (now) => {
      t0 ??= now;
      const t = ((now - t0) / 1000) % (n * HOP_S);
      const i = Math.floor(t / HOP_S), u = (t - i * HOP_S) / HOP_S;
      const [x0, y0] = path[i], [x1, y1] = path[(i + 1) % n];
      const lift = lifts ? lifts[i % lifts.length] : 24 + Math.abs(y1 - y0) * 0.5;
      const cx = (x0 + x1) / 2, cy = Math.min(y0, y1) - 2 * lift;
      const a = (1 - u) * (1 - u), b = 2 * (1 - u) * u, c = u * u;
      const x = a * x0 + b * cx + c * x1, y = a * y0 + b * cy + c * y1;
      const toLand = Math.min(u, 1 - u) * HOP_S;
      place(x, y, toLand < SQUASH_S ? 1 - toLand / SQUASH_S : 0);
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [scene]);
  return (
    <svg className="bouncer" viewBox={`0 -40 ${W} ${H + 48}`} aria-hidden="true" preserveAspectRatio="xMinYMax meet">
      <Ground kind={s.ground} pts={pts} />
      <g ref={ball} transform={`translate(${pts[0][0]} ${pts[0][1]})`}>
        <circle r={R} cy={-R} className="ball" />
        <circle r={R * 0.3} cx={-R * 0.38} cy={-R * 1.38} className="ball-shine" />
      </g>
    </svg>
  );
}
