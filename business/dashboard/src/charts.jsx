// Interactive chart primitives in HTML/SVG. Thin marks, 4px rounded ends, 2px gaps.
// Shared hover layer: the hovered mark gets a ring and its siblings fade back (styles.css, via :has),
// bars/lines animate in on mount, line charts snap a crosshair + marker to the nearest point,
// every mark has a tooltip on hover and keyboard focus, and every chart keeps a table view.
import { useEffect, useId, useMemo, useRef, useState } from "react";
import { full, pct } from "./format.js";
import { IconSearch, IconSort } from "./components/Icons.jsx";

const reducedMotion = () => typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

export function useWidth() {
  const ref = useRef(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    if (!ref.current) return;
    const ro = new ResizeObserver(([e]) => setWidth(e.contentRect.width));
    ro.observe(ref.current);
    return () => ro.disconnect();
  }, []);
  return [ref, width];
}

// Eases a number from its last value to `target` (used by gauges so they sweep in).
function useTween(target, ms = 760) {
  const [v, setV] = useState(() => (reducedMotion() ? target : 0));
  const cur = useRef(v);
  useEffect(() => {
    if (reducedMotion()) { cur.current = target; setV(target); return; }
    const from = cur.current, t0 = performance.now();
    let raf;
    const step = (now) => {
      const k = Math.min(1, (now - t0) / ms);
      cur.current = from + (target - from) * (1 - (1 - k) ** 3);
      setV(cur.current);
      if (k < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [target, ms]);
  return v;
}

export function niceTicks(max, n = 4) {
  const raw = max / n || 1;
  const p = 10 ** Math.floor(Math.log10(raw));
  const m = raw / p;
  const step = (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 ? 2.5 : m <= 5 ? 5 : 10) * p;
  return Array.from({ length: Math.ceil(max / step - 1e-9) + 1 }, (_, i) => +(i * step).toPrecision(12));
}

export function useTip() {
  const box = useRef(null);
  const [tip, setTip] = useState(null);
  function show(e, content) {
    if (!box.current) return;
    const b = box.current.getBoundingClientRect();
    const t = e.currentTarget.getBoundingClientRect();
    const pointer = e.type.startsWith("pointer");
    const x = (pointer ? e.clientX : t.left + t.width / 2) - b.left;
    setTip({ x: Math.min(Math.max(x, 110), Math.max(120, b.width - 110)), y: (pointer ? e.clientY : t.top) - b.top, content });
  }
  return { box, tip, show, hide: () => setTip(null) };
}

// Tooltip handlers for a mark; `on` optionally tracks which mark is hovered (for guides/labels).
export const hover = (tip, content, on) => ({
  onPointerMove: (e) => { tip.show(e, content); on?.enter?.(); },
  onPointerLeave: () => { tip.hide(); on?.leave?.(); },
  onFocus: (e) => { tip.show(e, content); on?.enter?.(); },
  onBlur: () => { tip.hide(); on?.leave?.(); },
});

export function Tip({ tip }) {
  return tip ? <div className="tip" style={{ left: tip.x, top: tip.y }} aria-hidden="true">{tip.content}</div> : null;
}

export function TipRows({ title, rows }) {
  return (
    <>
      {title && <div className="tip-title">{title}</div>}
      {rows.map((r, i) => (
        <div className={`tip-row${r.dim ? " is-dim" : ""}`} key={i}>
          {r.color && <span className="tip-key" style={{ background: r.color }} />}
          <strong>{r.value}</strong> {r.label && <span>{r.label}</span>}
        </div>
      ))}
    </>
  );
}

const pressKeys = (fn) => (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); fn(); } };

export function Figure({ title, note, table, actions, children, className = "" }) {
  const [asTable, setAsTable] = useState(false);
  return (
    <figure className={`fig ${className}`}>
      <div className="fig-head">
        <figcaption>
          <span className="fig-title">{title}</span>
          {note && <span className="fig-note">{note}</span>}
        </figcaption>
        <div className="fig-actions">
          {actions}
          {table && (
            <div className="view-toggle" role="group" aria-label="Show as">
              <button aria-pressed={!asTable} onClick={() => setAsTable(false)}>Chart</button>
              <button aria-pressed={asTable} onClick={() => setAsTable(true)}>Table</button>
            </div>
          )}
        </div>
      </div>
      {asTable && table ? <DataTable {...table} sortable /> : children}
    </figure>
  );
}

export function DataTable({
  columns,
  rows,
  caption,
  sortable = true,
  searchable = false,
  searchPlaceholder = "Filter rows…",
  selectedKey,
  rowKey,
  onRowClick,
  toolbar,
}) {
  const [sortCol, setSortCol] = useState(null);
  const [sortDir, setSortDir] = useState("desc");
  const [query, setQuery] = useState("");

  const processed = useMemo(() => {
    let list = rows;
    if (searchable && query.trim()) {
      const q = query.trim().toLowerCase();
      list = list.filter((r) =>
        columns.some((c) => {
          const v = r[c.key];
          return v != null && String(v).toLowerCase().includes(q);
        })
      );
    }
    if (sortable && sortCol) {
      const col = columns.find((c) => c.key === sortCol);
      const getVal = col?.sortValue ?? ((r) => r[sortCol]);
      list = [...list].sort((a, b) => {
        const va = getVal(a);
        const vb = getVal(b);
        if (va == null && vb == null) return 0;
        if (va == null) return 1;
        if (vb == null) return -1;
        if (typeof va === "number" && typeof vb === "number") {
          return sortDir === "asc" ? va - vb : vb - va;
        }
        const cmp = String(va).localeCompare(String(vb));
        return sortDir === "asc" ? cmp : -cmp;
      });
    }
    return list;
  }, [rows, columns, searchable, query, sortable, sortCol, sortDir]);

  function toggleSort(key) {
    if (!sortable) return;
    if (sortCol === key) {
      setSortDir((d) => (d === "desc" ? "asc" : "desc"));
    } else {
      setSortCol(key);
      setSortDir("desc");
    }
  }

  return (
    <div className="table-block">
      {(searchable || toolbar) && (
        <div className="table-bar">
          {searchable && (
            <label className="search sm">
              <IconSearch size={14} />
              <input type="search" placeholder={searchPlaceholder} value={query} onChange={(e) => setQuery(e.target.value)} />
            </label>
          )}
          {toolbar}
        </div>
      )}
      <div className="table-wrap">
        <table>
          {caption && <caption className="sr-only">{caption}</caption>}
          <thead>
            <tr>
              {columns.map((c) => {
                const active = sortCol === c.key;
                return (
                  <th key={c.key} scope="col" className={c.num ? "num" : ""}>
                    {sortable && c.sortable !== false ? (
                      <button className={`th-btn${active ? " is-sorted" : ""}`} onClick={() => toggleSort(c.key)}>
                        <span>{c.label}</span>
                        <IconSort size={12} />
                        {active && <span className="sr-only"> ({sortDir})</span>}
                      </button>
                    ) : (
                      c.label
                    )}
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {processed.length === 0 ? (
              <tr><td colSpan={columns.length} className="muted">No matching rows.</td></tr>
            ) : (
              processed.map((r, i) => {
                const k = rowKey ? rowKey(r) : i;
                const isSel = selectedKey != null && k === selectedKey;
                return (
                  <tr
                    key={k}
                    className={`${onRowClick ? "is-clickable" : ""}${isSel ? " is-selected" : ""}`}
                    onClick={onRowClick ? () => onRowClick(r) : undefined}
                  >
                    {columns.map((c) => (
                      <td key={c.key} className={c.num ? "num" : ""}>
                        {c.format ? c.format(r[c.key], r) : r[c.key]}
                      </td>
                    ))}
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function Chips({ options, value, onChange, label, size = "md" }) {
  return (
    <div className="chips" role="group" aria-label={label}>
      {options.map((o) => (
        <button key={o} className={`chip${size === "sm" ? " sm" : ""}`} aria-pressed={value === o} onClick={() => onChange(o)}>
          {o}
        </button>
      ))}
    </div>
  );
}

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
        {rows.map((r, i) => {
          const n = r.pos + r.neu + r.neg || 1;
          const s = { pos: r.pos / n, neu: r.neu / n, neg: r.neg / n };
          const content = <TipRows title={`${r.label}, ${full(n)} mentions`} rows={[
            { color: "var(--love)", value: pct(s.pos), label: `praise (${full(r.pos)})` },
            { color: "var(--neu)", value: pct(s.neu), label: `neutral (${full(r.neu)})` },
            { color: "var(--hate)", value: pct(s.neg), label: `complaints (${full(r.neg)})` }]} />;
          return (
            <li key={r.label} style={{ "--i": i }}>
              <button className="dv-row" aria-pressed={selected === r.label} onClick={() => onSelect?.(r.label)}
                aria-label={`${r.label}: ${full(n)} mentions, ${pct(s.pos)} praise, ${pct(s.neg)} complaints`} {...hover(tip, content)}>
                <span className="dv-label">{r.label} <span className="dv-n">{full(n)}</span></span>
                <span className="dv-track">
                  <span className="dv-ring" style={{ left: `calc(${50 - w(s.neu / 2) - w(s.neg)}% - 3px)` }} />
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

export function HBars({ rows, color = "var(--mag)", fmt = full, tipFor, max, selected, onSelect }) {
  const tip = useTip();
  const m = max ?? Math.max(...rows.map((r) => r.value), 1e-9);
  return (
    <div className="hb" ref={tip.box}>
      <ul>
        {rows.map((r, i) => {
          const interactive = Boolean(onSelect);
          const active = selected != null && selected === r.label;
          return (
            <li key={r.label}
              className={`hb-row${interactive ? " is-interactive" : ""}${active ? " is-selected" : ""}`}
              style={{ "--i": i }}
              tabIndex={0}
              role={interactive ? "button" : undefined}
              aria-pressed={interactive ? active : undefined}
              aria-label={`${r.label}: ${fmt(r.value)}`}
              onClick={interactive ? () => onSelect(r.label, r) : undefined}
              onKeyDown={interactive ? pressKeys(() => onSelect(r.label, r)) : undefined}
              {...hover(tip, tipFor ? tipFor(r) : <TipRows title={r.label} rows={[{ color, value: fmt(r.value) }]} />)}>
              <span className="hb-label">{r.label}</span>
              <span className="hb-track">
                <span className="hb-bar" style={{ width: `${(r.value / m) * 82}%`, "--c": r.color ?? color }} />
                <span className="hb-val">{fmt(r.value)}</span>
              </span>
            </li>
          );
        })}
      </ul>
      <Tip tip={tip.tip} />
    </div>
  );
}

export function DotList({ rows, domain: [lo, hi], tickVals, fmt, baseline, tipFor, selected, onSelect }) {
  const tip = useTip();
  const [over, setOver] = useState(null);
  const x = (v) => ((v - lo) / (hi - lo)) * 100;
  const side = (v) => (baseline == null ? "mag" : v > baseline + 1 ? "love" : v < baseline - 1 ? "hate" : "neu");
  const overRow = over == null ? null : rows.find((r) => r.label === over);
  return (
    <div className="dl" ref={tip.box} style={{ "--gs": `${100 / (tickVals.length - 1)}%` }}>
      <ul>
        {rows.map((r, i) => {
          const interactive = Boolean(onSelect);
          const active = selected != null && selected === r.label;
          const below = baseline != null && r.value < baseline;
          return (
            <li key={r.label}
              className={`dl-row${interactive ? " is-interactive" : ""}${active ? " is-selected" : ""}`}
              style={{ "--i": i }}
              tabIndex={0}
              role={interactive ? "button" : undefined}
              aria-pressed={interactive ? active : undefined}
              aria-label={`${r.label}: ${fmt(r.value)}`}
              onClick={interactive ? () => onSelect(r.label, r) : undefined}
              onKeyDown={interactive ? pressKeys(() => onSelect(r.label, r)) : undefined}
              {...hover(tip, tipFor ? tipFor(r) : <TipRows title={r.label} rows={[{ value: fmt(r.value) }]} />, { enter: () => setOver(r.label), leave: () => setOver(null) })}>
              <span className="dl-label">{r.label}</span>
              <span className="dl-track">
                {baseline != null && <span className={`stem ${side(r.value)}${below ? " below" : ""}`} style={{ left: `${Math.min(x(baseline), x(r.value))}%`, width: `${Math.abs(x(r.value) - x(baseline))}%` }} />}
                <span className={`dot ${side(r.value)}`} style={{ left: `${x(r.value)}%` }} />
              </span>
              <span className="dl-val">{fmt(r.value)}</span>
            </li>
          );
        })}
      </ul>
      <div className="dl-axis" aria-hidden="true">
        <span className="dl-label" />
        <span className="dl-ticks">
          {tickVals.map((t) => <span key={t} style={{ left: `${x(t)}%` }}>{fmt(t)}</span>)}
          {overRow && <b className="axis-pill" style={{ left: `${x(overRow.value)}%` }}>{fmt(overRow.value)}</b>}
        </span>
        <span className="dl-val" />
      </div>
      <Tip tip={tip.tip} />
    </div>
  );
}

export function Columns({ rows, color = "var(--mag)", fmt = full, height = 180, mini = false, tipFor, max, selected, onSelect }) {
  const tip = useTip();
  const [over, setOver] = useState(null);
  const m = max ?? Math.max(...rows.map((r) => r.value), 1);
  const scale = mini ? 100 : 84;
  const hiRow = over == null ? null : rows[over];
  return (
    <div className={`cols${mini ? " mini" : ""}`} ref={tip.box} style={{ "--c": color }}>
      <div className="cols-plot" style={{ height }}>
        {hiRow && <span className="cols-guide" style={{ bottom: `${(hiRow.value / m) * scale}%` }} aria-hidden="true" />}
        {rows.map((r, i) => {
          const interactive = Boolean(onSelect);
          const active = selected != null && selected === r.label;
          return (
            <div key={r.label}
              className={`col${interactive ? " is-interactive" : ""}${active ? " is-selected" : ""}`}
              style={{ "--i": i }}
              tabIndex={mini ? -1 : 0}
              role={interactive ? "button" : undefined}
              aria-pressed={interactive ? active : undefined}
              aria-label={`${r.label}: ${fmt(r.value)}`}
              onClick={interactive ? () => onSelect(r.label, r) : undefined}
              onKeyDown={interactive ? pressKeys(() => onSelect(r.label, r)) : undefined}
              {...hover(tip, tipFor ? tipFor(r) : <TipRows title={r.label} rows={[{ color, value: fmt(r.value) }]} />, { enter: () => setOver(i), leave: () => setOver(null) })}>
              {!mini && <span className="col-val">{fmt(r.value)}</span>}
              <span className="col-bar" style={{ height: `${(r.value / m) * scale}%` }} />
            </div>
          );
        })}
      </div>
      <div className="cols-x" aria-hidden="true">
        {rows.map((r, i) => (
          <span key={r.label} className={over === i ? "is-hi" : undefined}>
            {over === i || !mini || i === 0 || i === rows.length - 1 ? r.label : ""}
          </span>
        ))}
      </div>
      <Tip tip={tip.tip} />
    </div>
  );
}

export function RangeBars({ rows, fmt, tipFor }) {
  const tip = useTip();
  const top = niceTicks(Math.max(...rows.map((r) => r.high)), 4);
  const m = top[top.length - 1];
  return (
    <div className="hb rb" ref={tip.box} style={{ "--gs": `${100 / (top.length - 1)}%` }}>
      <ul>
        {rows.map((r, i) => (
          <li key={r.label} className="hb-row" style={{ "--i": i }} tabIndex={0} aria-label={`${r.label}: ${fmt(r.low)} to ${fmt(r.high)}`} {...hover(tip, tipFor(r))}>
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

// Index of the x value closest to pixel px.
function nearestIndex(xs, X, px) {
  let best = 0;
  xs.forEach((x, i) => { if (Math.abs(X(x) - px) < Math.abs(X(xs[best]) - px)) best = i; });
  return best;
}

// Arrow keys walk the crosshair along the points when the chart has focus.
function stepKeys(count, setHi) {
  return (e) => {
    const k = e.key;
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(k)) return;
    e.preventDefault();
    setHi((h) => {
      const cur = h ?? count - 1;
      if (k === "Home") return 0;
      if (k === "End") return count - 1;
      return Math.max(0, Math.min(count - 1, cur + (k === "ArrowRight" ? 1 : -1)));
    });
  };
}

export function LineChart({ points, yFmt, xFmt = String, height = 220, mini = false, color = "var(--mag)", label }) {
  const [ref, width] = useWidth();
  const [hi, setHi] = useState(null);
  const gid = `lc${useId().replace(/[^a-zA-Z0-9]/g, "")}`;
  if (!points.length) return <div className="lc" ref={ref} />;
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
  const lastI = points.length - 1;
  // Every step-th tick plus the last one, dropping a tick that would crowd the last label.
  const xt = mini ? [points[0], points[lastI]] : points.filter((_, i) => i === lastI || (i % step === 0 && lastI - i >= Math.max(1, step * 0.6)));
  const move = (e) => setHi(nearestIndex(xs, X, e.clientX - e.currentTarget.getBoundingClientRect().left));
  const last = points[points.length - 1];
  const h = hi == null ? null : points[Math.min(hi, points.length - 1)];
  return (
    <div className={`lc${mini ? " mini" : ""}`} ref={ref} style={{ "--c": color }}>
      {width > 0 && (
        <svg width={W} height={height} role="img" aria-label={label} tabIndex={mini ? -1 : 0}
          onPointerMove={move} onPointerLeave={() => setHi(null)}
          onKeyDown={stepKeys(points.length, setHi)} onFocus={() => setHi(points.length - 1)} onBlur={() => setHi(null)}>
          <defs>
            <linearGradient id={gid} x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" style={{ stopColor: color, stopOpacity: mini ? 0.24 : 0.3 }} />
              <stop offset="100%" style={{ stopColor: color, stopOpacity: 0 }} />
            </linearGradient>
          </defs>
          {!mini && yt.map((t) => (
            <g key={t}>
              <line x1={m.l} x2={W - m.r} y1={Y(t)} y2={Y(t)} className="grid" />
              <text x={m.l - 8} y={Y(t)} className="tick" textAnchor="end" dominantBaseline="middle">{yFmt(t)}</text>
            </g>
          ))}
          <line x1={m.l} x2={W - m.r} y1={Y(0)} y2={Y(0)} className="axis" />
          {xt.map((p) => <text key={p[0]} x={X(p[0])} y={height - 6} className="tick" textAnchor={mini ? (p === points[0] ? "start" : "end") : "middle"}>{xFmt(p[0])}</text>)}
          <path d={area} fill={`url(#${gid})`} className="lc-area" />
          <path d={d} pathLength="1" className="lc-line" style={{ stroke: color }} />
          {!mini && <circle cx={X(last[0])} cy={Y(last[1])} r="4" className="lc-end" style={{ fill: color }} />}
          {!mini && <text x={X(last[0]) + 9} y={Y(last[1])} className="end-label" dominantBaseline="middle">{yFmt(last[1])}</text>}
          {h && (
            <g className="lc-hover">
              <line x1={X(h[0])} x2={X(h[0])} y1={m.t} y2={Y(0)} className="cross" />
              <circle cx={X(h[0])} cy={Y(h[1])} r={mini ? 8 : 11} className="halo" style={{ fill: color }} />
              <circle cx={X(h[0])} cy={Y(h[1])} r={mini ? 3.5 : 5} className="marker" style={{ stroke: color }} />
            </g>
          )}
        </svg>
      )}
      {h && !mini && <span className="axis-pill x" style={{ left: X(h[0]), top: height - 20 }} aria-hidden="true">{xFmt(h[0])}</span>}
      {h && (
        <div className="tip" style={{ left: Math.min(Math.max(X(h[0]), 70), W - 70), top: Y(h[1]) }} aria-hidden="true">
          <TipRows title={xFmt(h[0])} rows={[{ color, value: yFmt(h[1]) }]} />
        </div>
      )}
    </div>
  );
}

// Fixed series order, checked with the dataviz palette validator per theme (tokens in styles.css).
export const SERIES_COLORS = ["var(--s1)", "var(--s2)", "var(--s3)", "var(--s4)"];

// Spread end labels so they never overlap: sort by y, push down by `gap`, then pull back inside [lo, hi].
function spreadLabels(items, gap, lo, hi) {
  const s = [...items].sort((a, b) => a.y - b.y);
  for (let i = 1; i < s.length; i++) s[i].y = Math.max(s[i].y, s[i - 1].y + gap);
  const over = s.length ? s[s.length - 1].y - hi : 0;
  if (over > 0) s.forEach((it) => { it.y -= over; });
  for (let i = s.length - 2; i >= 0; i--) s[i].y = Math.min(s[i].y, s[i + 1].y - gap);
  s.forEach((it) => { it.y = Math.max(lo, it.y); });
  return s;
}

export function MultiLineChart({ series, yFmt = (v) => String(Math.round(v)), xFmt = String, height = 240, label }) {
  const [ref, width] = useWidth();
  const [hi, setHi] = useState(null);
  const [hidden, setHidden] = useState(() => new Set());
  const [focus, setFocus] = useState(null);
  if (!series.length) return <div className="lc" ref={ref} />;

  const all = series.map((s, i) => ({ ...s, color: s.color ?? SERIES_COLORS[i % SERIES_COLORS.length] }));
  const shown = all.filter((s) => !hidden.has(s.name));
  const vis = shown.length ? shown : all;
  const labels = width >= 560;
  const m = { t: 16, r: labels ? 118 : 24, b: 28, l: 48 };
  const W = Math.max(width, 200);
  const xs = [...new Set(vis.flatMap((s) => s.points.map((p) => p[0])))].sort((a, b) => a - b);
  const x0 = Math.min(...xs), x1 = Math.max(...xs);
  const yMax = Math.max(...vis.flatMap((s) => s.points.map((p) => p[1])), 1e-9);
  const yt = niceTicks(yMax, 4);
  const top = yt[yt.length - 1];
  const X = (v) => m.l + ((v - x0) / (x1 - x0 || 1)) * (W - m.l - m.r);
  const Y = (v) => m.t + (1 - v / top) * (height - m.t - m.b);
  const step = Math.ceil(xs.length / Math.max(2, Math.floor((W - m.l - m.r) / 56)));
  const xt = xs.filter((_, i) => i === xs.length - 1 || (i % step === 0 && xs.length - 1 - i >= Math.max(1, step * 0.6)));
  const at = (s, x) => s.points.find((p) => p[0] === x);

  function move(e) {
    const r = e.currentTarget.getBoundingClientRect();
    const i = nearestIndex(xs, X, e.clientX - r.left);
    setHi(i);
    // The line nearest the pointer (within 26px) becomes the focused series.
    const py = e.clientY - r.top;
    let best = null, dist = 26;
    vis.forEach((s) => { const p = at(s, xs[i]); if (p && Math.abs(Y(p[1]) - py) < dist) { dist = Math.abs(Y(p[1]) - py); best = s.name; } });
    setFocus(best);
  }
  function toggle(name) {
    setHidden((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else if (all.length - next.size > 1) next.add(name);
      return next;
    });
  }

  const hiX = hi == null ? null : xs[Math.min(hi, xs.length - 1)];
  const ends = labels
    ? spreadLabels(vis.map((s) => { const p = s.points[s.points.length - 1]; return { name: s.name, color: s.color, x: X(p[0]), y: Y(p[1]) }; }), 15, m.t, Y(0) - 4)
    : [];
  const dimmed = (name) => focus != null && focus !== name;

  return (
    <div className="lc mlc" ref={ref}>
      <div className="mlc-legend" role="group" aria-label="Show or hide series">
        {all.map((s) => {
          const on = !hidden.has(s.name);
          return (
            <button key={s.name} className={`mlc-item${dimmed(s.name) ? " is-dim" : ""}`} aria-pressed={on}
              onClick={() => toggle(s.name)} onPointerEnter={() => on && setFocus(s.name)} onPointerLeave={() => setFocus(null)}
              onFocus={() => on && setFocus(s.name)} onBlur={() => setFocus(null)}>
              <span className="mlc-key" style={on ? { background: s.color } : undefined} />
              <span>{s.name}</span>
            </button>
          );
        })}
      </div>
      <div className="mlc-plot">
      {width > 0 && (
        <svg width={W} height={height} role="img" aria-label={label} tabIndex={0}
          onPointerMove={move} onPointerLeave={() => { setHi(null); setFocus(null); }}
          onKeyDown={stepKeys(xs.length, setHi)} onFocus={() => setHi(xs.length - 1)} onBlur={() => setHi(null)}>
          {yt.map((t) => (
            <g key={t}>
              <line x1={m.l} x2={W - m.r} y1={Y(t)} y2={Y(t)} className="grid" />
              <text x={m.l - 8} y={Y(t)} className="tick" textAnchor="end" dominantBaseline="middle">{yFmt(t)}</text>
            </g>
          ))}
          <line x1={m.l} x2={W - m.r} y1={Y(0)} y2={Y(0)} className="axis" />
          {xt.map((x) => <text key={x} x={X(x)} y={height - 6} className="tick" textAnchor="middle">{xFmt(x)}</text>)}
          {vis.map((s) => {
            const d = s.points.map((p, i) => `${i ? "L" : "M"}${X(p[0]).toFixed(1)},${Y(p[1]).toFixed(1)}`).join("");
            return <path key={s.name} d={d} pathLength="1" className={`lc-line${dimmed(s.name) ? " is-dim" : ""}${focus === s.name ? " is-focus" : ""}`} style={{ stroke: s.color, "--c": s.color }} />;
          })}
          {ends.map((e) => (
            <g key={e.name} className={`mlc-end${dimmed(e.name) ? " is-dim" : ""}`}>
              <line x1={W - m.r + 8} x2={W - m.r + 18} y1={e.y} y2={e.y} style={{ stroke: e.color }} />
              <text x={W - m.r + 23} y={e.y} dominantBaseline="middle">{e.name.length > 14 ? `${e.name.slice(0, 13)}…` : e.name}</text>
            </g>
          ))}
          {hiX != null && (
            <g className="lc-hover">
              <line x1={X(hiX)} x2={X(hiX)} y1={m.t} y2={Y(0)} className="cross" />
              {vis.map((s) => {
                const pt = at(s, hiX);
                if (!pt) return null;
                return (
                  <g key={s.name} className={dimmed(s.name) ? "is-dim" : undefined}>
                    {focus === s.name && <circle cx={X(pt[0])} cy={Y(pt[1])} r="11" className="halo" style={{ fill: s.color }} />}
                    <circle cx={X(pt[0])} cy={Y(pt[1])} r="4.5" className="marker" style={{ stroke: s.color }} />
                  </g>
                );
              })}
            </g>
          )}
        </svg>
      )}
      {hiX != null && <span className="axis-pill x" style={{ left: X(hiX), top: height - 20 }} aria-hidden="true">{xFmt(hiX)}</span>}
      {hiX != null && (
        <div className={`tip beside${X(hiX) > (m.l + W - m.r) / 2 ? " flip" : ""}`} style={{ left: X(hiX), top: (m.t + Y(0)) / 2 }} aria-hidden="true">
          <TipRows
            title={xFmt(hiX)}
            rows={vis.map((s) => {
              const pt = at(s, hiX);
              return { color: s.color, value: pt ? yFmt(pt[1]) : "–", label: s.name, dim: dimmed(s.name) };
            })}
          />
        </div>
      )}
      </div>
    </div>
  );
}

export function RadialGauge({ value, max = 100, label, sublabel, color = "var(--love)", size = 104, formatValue }) {
  const clamped = Math.max(0, Math.min(max, value));
  const shown = useTween(clamped);
  const r = 38;
  const c = 2 * Math.PI * r;
  const arc = c * 0.75; // 270 degree arc
  const dash = arc * (shown / max);
  const display = formatValue ? formatValue(shown) : `${Math.round(shown)}`;
  return (
    <div className="gauge" style={{ width: size, "--c": color }}>
      <svg viewBox="0 0 100 100" className="gauge-svg" aria-hidden="true">
        <circle cx="50" cy="50" r={r} fill="none" stroke="var(--grid)" strokeWidth="8"
          strokeDasharray={`${arc} ${c}`} strokeLinecap="round" transform="rotate(135 50 50)" />
        <circle cx="50" cy="50" r={r} fill="none" className="gauge-arc" style={{ stroke: color }} strokeWidth="8"
          strokeDasharray={`${dash} ${c}`} strokeLinecap="round" transform="rotate(135 50 50)" />
        <text x="50" y="51" textAnchor="middle" dominantBaseline="middle" className="gauge-val">{display}</text>
      </svg>
      {label && <span className="gauge-lbl">{label}</span>}
      {sublabel && <span className="gauge-sub">{sublabel}</span>}
      <span className="sr-only">{`${label ?? ""} ${formatValue ? formatValue(clamped) : Math.round(clamped)}`}</span>
    </div>
  );
}

export function SegBar({ parts }) {
  const tip = useTip();
  const total = parts.reduce((s, p) => s + p.value, 0) || 1;
  const share = (p) => Math.round((p.value / total) * 100);
  return (
    <div className="segbar-box" ref={tip.box}>
      <div className="segbar" role="img" aria-label={parts.map((p) => `${p.label} ${share(p)}%`).join(", ")}>
        {parts.filter((p) => p.value > 0).map((p, i) => (
          <span key={p.label} className={p.cls} style={{ flexGrow: p.value, "--i": i }}
            {...hover(tip, <TipRows title={p.label} rows={[{ color: `var(--${p.cls})`, value: `${share(p)}%` }]} />)} />
        ))}
      </div>
      <Tip tip={tip.tip} />
    </div>
  );
}
