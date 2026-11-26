// Chart parts in plain HTML/SVG, following the dataviz rules: thin marks, 4px rounded data ends, 2px surface gaps,
// a legend for 2+ series, a hover/focus tooltip on every mark, and a table view on every figure.
import { useEffect, useRef, useState } from "react";
import { compact, full, pct } from "./format.js";

export function useWidth() {
  const ref = useRef(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const ro = new ResizeObserver(([e]) => setWidth(e.contentRect.width));
    ro.observe(ref.current);
    return () => ro.disconnect();
  }, []);
  return [ref, width];
}

export function niceTicks(max, n = 4) {
  const raw = max / n || 1;
  const p = 10 ** Math.floor(Math.log10(raw));
  const m = raw / p;
  const step = (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 ? 2.5 : m <= 5 ? 5 : 10) * p;
  return Array.from({ length: Math.ceil(max / step - 1e-9) + 1 }, (_, i) => +(i * step).toPrecision(12));
}

// one tooltip per chart, positioned inside the chart box; content is React text, never HTML strings
export function useTip() {
  const box = useRef(null);
  const [tip, setTip] = useState(null);
  function show(e, content) {
    if (!box.current) return;
    const b = box.current.getBoundingClientRect();
    const t = e.currentTarget.getBoundingClientRect();
    const pointer = e.type.startsWith("pointer");
    const x = (pointer ? e.clientX : t.left + t.width / 2) - b.left;
    setTip({ x: Math.min(Math.max(x, 110), b.width - 110), y: (pointer ? e.clientY : t.top) - b.top, content });
  }
  return { box, tip, show, hide: () => setTip(null) };
}

export const hover = (tip, content) => ({
  onPointerMove: (e) => tip.show(e, content), onPointerLeave: tip.hide, onFocus: (e) => tip.show(e, content), onBlur: tip.hide,
});

export function Tip({ tip }) {
  return tip ? <div className="tip" style={{ left: tip.x, top: tip.y }} aria-hidden="true">{tip.content}</div> : null;
}

export function TipRows({ title, rows }) {
  return (
    <>
      {title && <div className="tip-title">{title}</div>}
      {rows.map((r, i) => (
        <div className="tip-row" key={i}>
          {r.color && <span className="tip-key" style={{ background: r.color }} />}
          <strong>{r.value}</strong> {r.label && <span>{r.label}</span>}
        </div>
      ))}
    </>
  );
}

export function Figure({ title, note, table, children, className = "" }) {
  const [asTable, setAsTable] = useState(false);
  return (
    <figure className={`fig ${className}`}>
      <div className="fig-head">
        <figcaption>
          <span className="fig-title">{title}</span>
          {note && <span className="fig-note">{note}</span>}
        </figcaption>
        {table && (
          <button className="link-btn" onClick={() => setAsTable(!asTable)} aria-pressed={asTable}>
            {asTable ? "Show chart" : "Show table"}
          </button>
        )}
      </div>
      {asTable && table ? <DataTable {...table} /> : children}
    </figure>
  );
}

export function DataTable({ columns, rows, caption }) {
  return (
    <div className="table-wrap">
      <table>
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead><tr>{columns.map((c) => <th key={c.key} scope="col" className={c.num ? "num" : ""}>{c.label}</th>)}</tr></thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i}>{columns.map((c) => <td key={c.key} className={c.num ? "num" : ""}>{c.format ? c.format(r[c.key], r) : r[c.key]}</td>)}</tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function Chips({ options, value, onChange, label }) {
  return (
    <div className="chips" role="group" aria-label={label}>
      {options.map((o) => (
        <button key={o} className="chip" aria-pressed={value === o} onClick={() => onChange(o)}>{o}</button>
      ))}
    </div>
  );
}

// complaints left of centre, praise right, neutral split across the centre (a diverging stacked bar of shares, each row = 100%)
export function DivergingBars({ rows, selected, onSelect }) {
  const tip = useTip();
  const tk = [0, 0.5, 1];
  const w = (v) => v * 50;
  const axis = [-1, -0.5, 0, 0.5, 1];
  return (
    <div className="dv" ref={tip.box} style={{ "--gs": `${50 / (tk.length - 1)}%` }}>
      <div className="dv-legend" aria-hidden="true">
        <span className="dv-label" />
        <span className="dv-keys">
          <span><i className="sw hate" />Complaints</span>
          <span><i className="sw neu" />Neutral</span>
          <span><i className="sw love" />Praise</span>
        </span>
      </div>
      <ul className="dv-rows">
        {rows.map((r) => {
          const n = r.pos + r.neu + r.neg || 1;
          const s = { pos: r.pos / n, neu: r.neu / n, neg: r.neg / n };
          const content = <TipRows title={`${r.label}, ${full(n)} mentions`} rows={[
            { color: "var(--love)", value: pct(s.pos), label: `praise (${full(r.pos)})` },
            { color: "var(--neu)", value: pct(s.neu), label: `neutral (${full(r.neu)})` },
            { color: "var(--hate)", value: pct(s.neg), label: `complaints (${full(r.neg)})` }]} />;
          return (
            <li key={r.label}>
              <button className="dv-row" aria-pressed={selected === r.label} onClick={() => onSelect?.(r.label)}
                aria-label={`${r.label}: ${full(n)} mentions, ${pct(s.pos)} praise, ${pct(s.neg)} complaints`} {...hover(tip, content)}>
                <span className="dv-label">{r.label} <span className="dv-n">{compact(n)}</span></span>
                <span className="dv-track">
                  <span className="seg hate" style={{ right: `calc(${50 + w(s.neu / 2)}% + 1px)`, width: `${w(s.neg)}%` }} />
                  <span className="seg neu" style={{ left: `calc(${50 - w(s.neu / 2)}% + 1px)`, width: `max(0px, calc(${w(s.neu)}% - 2px))` }} />
                  <span className="seg love" style={{ left: `calc(${50 + w(s.neu / 2)}% + 1px)`, width: `${w(s.pos)}%` }} />
                </span>
              </button>
            </li>
          );
        })}
      </ul>
      <div className="dv-axis" aria-hidden="true">
        <span className="dv-label" />
        <span className="dv-ticks">{axis.map((t) => <span key={t} style={{ left: `${50 + w(t)}%` }}>{pct(Math.abs(t))}</span>)}</span>
      </div>
      <Tip tip={tip.tip} />
    </div>
  );
}

// ranked horizontal bars, one hue, value at the bar tip
export function HBars({ rows, color = "var(--mag)", fmt = full, tipFor, max }) {
  const tip = useTip();
  const m = max ?? Math.max(...rows.map((r) => r.value), 1e-9);
  return (
    <div className="hb" ref={tip.box}>
      <ul>
        {rows.map((r) => (
          <li key={r.label} className="hb-row" tabIndex={0} aria-label={`${r.label}: ${fmt(r.value)}`}
            {...hover(tip, tipFor ? tipFor(r) : <TipRows title={r.label} rows={[{ color, value: fmt(r.value) }]} />)}>
            <span className="hb-label">{r.label}</span>
            <span className="hb-track">
              <span className="hb-bar" style={{ width: `${(r.value / m) * 82}%`, background: color }} />
              <span className="hb-val">{fmt(r.value)}</span>
            </span>
          </li>
        ))}
      </ul>
      <Tip tip={tip.tip} />
    </div>
  );
}

// dot per row on a shared scale; with a baseline, a stem runs from it and the colour says which side
export function DotList({ rows, domain: [lo, hi], tickVals, fmt, baseline, tipFor }) {
  const tip = useTip();
  const x = (v) => ((v - lo) / (hi - lo)) * 100;
  const side = (v) => (baseline == null ? "mag" : v > baseline + 1 ? "love" : v < baseline - 1 ? "hate" : "neu");
  return (
    <div className="dl" ref={tip.box} style={{ "--gs": `${100 / (tickVals.length - 1)}%` }}>
      <ul>
        {rows.map((r) => (
          <li key={r.label} className="dl-row" tabIndex={0} aria-label={`${r.label}: ${fmt(r.value)}`}
            {...hover(tip, tipFor ? tipFor(r) : <TipRows title={r.label} rows={[{ value: fmt(r.value) }]} />)}>
            <span className="dl-label">{r.label}</span>
            <span className="dl-track">
              {baseline != null && <span className={`stem ${side(r.value)}`} style={{ left: `${Math.min(x(baseline), x(r.value))}%`, width: `${Math.abs(x(r.value) - x(baseline))}%` }} />}
              <span className={`dot ${side(r.value)}`} style={{ left: `${x(r.value)}%` }} />
            </span>
            <span className="dl-val">{fmt(r.value)}</span>
          </li>
        ))}
      </ul>
      <div className="dl-axis" aria-hidden="true">
        <span className="dl-label" />
        <span className="dl-ticks">{tickVals.map((t) => <span key={t} style={{ left: `${x(t)}%` }}>{fmt(t)}</span>)}</span>
        <span className="dl-val" />
      </div>
      <Tip tip={tip.tip} />
    </div>
  );
}

// vertical columns from one baseline; mini = small-multiple panel without value labels
export function Columns({ rows, color = "var(--mag)", fmt = full, height = 180, mini = false, tipFor, max }) {
  const tip = useTip();
  const m = max ?? Math.max(...rows.map((r) => r.value), 1);
  return (
    <div className={`cols${mini ? " mini" : ""}`} ref={tip.box}>
      <div className="cols-plot" style={{ height }}>
        {rows.map((r) => (
          <div key={r.label} className="col" tabIndex={mini ? -1 : 0} aria-label={`${r.label}: ${fmt(r.value)}`}
            {...hover(tip, tipFor ? tipFor(r) : <TipRows title={r.label} rows={[{ color, value: fmt(r.value) }]} />)}>
            {!mini && <span className="col-val">{fmt(r.value)}</span>}
            <span className="col-bar" style={{ height: `${(r.value / m) * (mini ? 100 : 84)}%`, background: color }} />
          </div>
        ))}
      </div>
      <div className="cols-x" aria-hidden="true">
        {rows.map((r, i) => <span key={r.label}>{!mini || i === 0 || i === rows.length - 1 ? r.label : ""}</span>)}
      </div>
      <Tip tip={tip.tip} />
    </div>
  );
}

// a floating bar from low to high estimate per row
export function RangeBars({ rows, fmt, tipFor }) {
  const tip = useTip();
  const top = niceTicks(Math.max(...rows.map((r) => r.high)), 4);
  const m = top[top.length - 1];
  return (
    <div className="hb rb" ref={tip.box} style={{ "--gs": `${100 / (top.length - 1)}%` }}>
      <ul>
        {rows.map((r) => (
          <li key={r.label} className="hb-row" tabIndex={0} aria-label={`${r.label}: ${fmt(r.low)} to ${fmt(r.high)}`} {...hover(tip, tipFor(r))}>
            <span className="hb-label">{r.label}</span>
            <span className="hb-track grid-track">
              <span className="rb-bar" style={{ left: `${(r.low / m) * 100}%`, width: `${((r.high - r.low) / m) * 100}%` }} />
            </span>
          </li>
        ))}
      </ul>
      <div className="dl-axis" aria-hidden="true">
        <span className="hb-label" />
        <span className="dl-ticks">{top.map((t) => <span key={t} style={{ left: `${(t / m) * 100}%` }}>{fmt(t)}</span>)}</span>
      </div>
      <Tip tip={tip.tip} />
    </div>
  );
}

// line + soft area; the crosshair snaps to the nearest point
export function LineChart({ points, yFmt, xFmt = String, height = 220, mini = false, color = "var(--mag)", label }) {
  const [ref, width] = useWidth();
  const [hi, setHi] = useState(null);
  const m = mini ? { t: 10, r: 10, b: 20, l: 10 } : { t: 16, r: 56, b: 28, l: 48 };
  const W = Math.max(width, 160);
  const xs = points.map((p) => p[0]);
  const x0 = Math.min(...xs), x1 = Math.max(...xs);
  const yMax = Math.max(...points.map((p) => p[1]), 1e-9);
  const yt = niceTicks(yMax, 4);
  const top = mini ? yMax : yt[yt.length - 1];
  const X = (v) => m.l + ((v - x0) / (x1 - x0 || 1)) * (W - m.l - m.r);
  const Y = (v) => m.t + (1 - v / top) * (height - m.t - m.b);
  const d = points.map((p, i) => `${i ? "L" : "M"}${X(p[0]).toFixed(1)},${Y(p[1]).toFixed(1)}`).join("");
  const area = `${d}L${X(x1)},${Y(0)}L${X(x0)},${Y(0)}Z`;
  const step = Math.ceil(points.length / Math.max(2, Math.floor((W - m.l - m.r) / 56)));
  const xt = mini ? [points[0], points[points.length - 1]] : points.filter((_, i) => i % step === 0 || i === points.length - 1);
  function move(e) {
    const px = e.clientX - e.currentTarget.getBoundingClientRect().left;
    let best = 0;
    points.forEach((p, i) => { if (Math.abs(X(p[0]) - px) < Math.abs(X(points[best][0]) - px)) best = i; });
    setHi(best);
  }
  const last = points[points.length - 1];
  const h = hi == null ? null : points[hi];
  return (
    <div className="lc" ref={ref}>
      {width > 0 && (
        <svg width={W} height={height} role="img" aria-label={label} onPointerMove={move} onPointerLeave={() => setHi(null)}>
          {!mini && yt.map((t) => (
            <g key={t}>
              <line x1={m.l} x2={W - m.r} y1={Y(t)} y2={Y(t)} className="grid" />
              <text x={m.l - 8} y={Y(t)} className="tick" textAnchor="end" dominantBaseline="middle">{yFmt(t)}</text>
            </g>
          ))}
          <line x1={m.l} x2={W - m.r} y1={Y(0)} y2={Y(0)} className="axis" />
          {xt.map((p) => <text key={p[0]} x={X(p[0])} y={height - 6} className="tick" textAnchor={mini ? (p === points[0] ? "start" : "end") : "middle"}>{xFmt(p[0])}</text>)}
          <path d={area} fill={color} opacity="0.1" />
          <path d={d} fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
          {!mini && <circle cx={X(last[0])} cy={Y(last[1])} r="4" fill={color} stroke="var(--surface)" strokeWidth="2" />}
          {!mini && <text x={X(last[0]) + 9} y={Y(last[1])} className="end-label" dominantBaseline="middle">{yFmt(last[1])}</text>}
          {h && (
            <g>
              <line x1={X(h[0])} x2={X(h[0])} y1={m.t} y2={Y(0)} className="cross" />
              <circle cx={X(h[0])} cy={Y(h[1])} r="4" fill={color} stroke="var(--surface)" strokeWidth="2" />
            </g>
          )}
        </svg>
      )}
      {h && (
        <div className="tip" style={{ left: Math.min(Math.max(X(h[0]), 70), W - 70), top: Y(h[1]) }} aria-hidden="true">
          <TipRows title={xFmt(h[0])} rows={[{ color, value: yFmt(h[1]) }]} />
        </div>
      )}
    </div>
  );
}

// one whole split into parts: thin, no text (the figures sit beside it)
export function SegBar({ parts }) {
  const total = parts.reduce((s, p) => s + p.value, 0) || 1;
  return (
    <div className="segbar" role="img" aria-label={parts.map((p) => `${p.label} ${Math.round((p.value / total) * 100)}%`).join(", ")}>
      {parts.filter((p) => p.value > 0).map((p) => <span key={p.label} className={p.cls} style={{ flexGrow: p.value }} />)}
    </div>
  );
}
