// The page opens with a red ball dropping in and bouncing to rest; each landing spot carries one finding.
// The bounce loops: the ball rests, fades out and drops in again.
// Horizontal speed is constant and each hop lasts in proportion to the square root of its height, as with real gravity.
import { useEffect, useRef } from "react";

const GROUND = 168, R = 13, X0 = 34, DROP = 150, HOPS = [104, 60, 28], SPEED = 14.5, SECONDS = 2.8, HOLD = 1.6;

const t = [Math.sqrt(DROP), ...HOPS.map((h) => 2 * Math.sqrt(h))];
const lands = [];
t.reduce((x, d) => { lands.push(x + SPEED * d); return x + SPEED * d; }, X0);
const END = lands[lands.length - 1] + 54;
const ROLL = 9;
const T = t.reduce((a, b) => a + b, 0) + ROLL;
const DUR = SECONDS + HOLD, K = SECONDS / DUR; // the motion takes the first K of each loop, the rest is the rest
const at = (v) => ((v / T) * K).toFixed(4);

const trail = [`M${X0},${GROUND - DROP} Q${(X0 + lands[0]) / 2},${GROUND - DROP} ${lands[0]},${GROUND}`,
  ...HOPS.map((h, i) => `Q${(lands[i] + lands[i + 1]) / 2},${GROUND - 2 * h} ${lands[i + 1]},${GROUND}`), `L${END},${GROUND}`].join(" ");

// x: steady across each hop, then the ball rolls to a stop
const cum = t.reduce((acc, d) => [...acc, acc[acc.length - 1] + d], [0]);
const xTimes = [...[...cum, T].map(at), "1"].join(";");
const xValues = [X0, ...lands, END, END].map((v) => `${v.toFixed(1)} 0`).join(";");
const xSplines = [...t.map(() => "0 0 1 1"), "0 0 0.58 1", "0 0 1 1"].join(";");
// y: speeds up on the way down, slows on the way up
const EASE_IN = "0.11 0 0.5 0", EASE_OUT = "0.5 1 0.89 1";
const yTimes = [...[0, cum[1], ...HOPS.flatMap((_, i) => [cum[i + 1] + t[i + 1] / 2, cum[i + 2]]), T].map(at), "1"].join(";");
const yValues = [GROUND - DROP, GROUND, ...HOPS.flatMap((h) => [GROUND - h, GROUND]), GROUND, GROUND].map((v) => `0 ${v}`).join(";");
const ySplines = [EASE_IN, ...HOPS.flatMap(() => [EASE_OUT, EASE_IN]), "0 0 1 1", "0 0 1 1"].join(";");
// fade in as it drops, fade out at the end of the rest
const fadeTimes = `0;${(0.2 / DUR).toFixed(4)};${((DUR - 0.4) / DUR).toFixed(4)};1`;

export function Hero({ findings, children }) {
  const ax = useRef(null), ay = useRef(null), af = useRef(null);
  const still = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  useEffect(() => {
    if (still) return;
    const id = setTimeout(() => { ax.current?.beginElement(); ay.current?.beginElement(); af.current?.beginElement(); }, 300);
    return () => clearTimeout(id);
  }, [still]);
  return (
    <section className="hero" id="top">
      <div className="wrap">
        {children}
        <div className="bounce-wrap">
          <svg className="bounce" viewBox="0 0 1000 190" aria-hidden="true">
            <line x1="0" x2="1000" y1={GROUND} y2={GROUND} className="ground" />
            <path d={trail} className="trail" />
            {lands.slice(0, findings.length).map((x) => <line key={x} x1={x} x2={x} y1={GROUND} y2={GROUND + 12} className="land" />)}
            <g transform={`translate(${still ? END : X0} 0)`} opacity={still ? 1 : 0}>
              {!still && <animate ref={af} attributeName="opacity" begin="indefinite" dur={`${DUR}s`} repeatCount="indefinite"
                keyTimes={fadeTimes} values="0;1;1;0" />}
              {!still && <animateTransform ref={ax} attributeName="transform" type="translate" begin="indefinite" dur={`${DUR}s`}
                repeatCount="indefinite" calcMode="spline" keyTimes={xTimes} values={xValues} keySplines={xSplines} />}
              <g transform={`translate(0 ${still ? GROUND : GROUND - DROP})`}>
                {!still && <animateTransform ref={ay} attributeName="transform" type="translate" begin="indefinite" dur={`${DUR}s`}
                  repeatCount="indefinite" calcMode="spline" keyTimes={yTimes} values={yValues} keySplines={ySplines} />}
                <circle r={R} cy={-R} className="ball" />
                <circle r={R * 0.3} cx={-R * 0.38} cy={-R * 1.38} className="ball-shine" />
              </g>
            </g>
          </svg>
          <ul className="findings">
            {findings.map((f, i) => (
              <li key={f.title} style={{ "--at": `${lands[i] / 10}%` }}>
                <strong>{f.title}</strong>
                <span>{f.text}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
