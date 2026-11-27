import { useEffect, useMemo, useRef, useState } from "react";
import { compact, pct } from "../format.js";
import { IconArrowRight, IconClose, IconSearch, IconSpark } from "./Icons.jsx";

const FILTERS = ["All", "Games", "Topics", "Countries", "Sections"];

export function SmartSearch({ open, onClose, data, sections, onPick }) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("All");
  const [cursor, setCursor] = useState(0);
  const inputRef = useRef(null);

  useEffect(() => {
    if (!open) return;
    setCursor(0);
    const id = requestAnimationFrame(() => inputRef.current?.focus());
    return () => cancelAnimationFrame(id);
  }, [open]);

  const index = useMemo(() => {
    const items = [];
    sections.forEach(([id, label], i) => {
      items.push({
        kind: "Sections",
        id: `sec:${id}`,
        title: label,
        subtitle: `Section ${String(i).padStart(2, "0")}`,
        badge: "View",
        action: { section: id },
      });
    });
    data.games.forEach((g) => {
      items.push({
        kind: "Games",
        id: `game:${g.id}`,
        title: g.title,
        subtitle: `${g.platform.replace(/ \(.*\)/, "")} · ${g.category}`,
        badge: `${pct(g.textPos)} positive`,
        action: { section: "games", gameId: g.id },
      });
    });
    data.themes
      .filter((t) => t.group !== "General reaction")
      .forEach((t) => {
        const share = t.pos / (t.pos + t.neg + t.neu || 1);
        items.push({
          kind: "Topics",
          id: `topic:${t.theme}`,
          title: t.theme,
          subtitle: `${t.group} · ${compact(t.mentions)} mentions`,
          badge: `${pct(share)} positive`,
          action: { section: "topics", topic: t.theme },
        });
      });
    data.countries.forEach((c) => {
      items.push({
        kind: "Countries",
        id: `country:${c.code}`,
        title: c.name,
        subtitle: `App Store · ${compact(c.ratings)} ratings`,
        badge: `${c.avg.toFixed(2)} ★`,
        action: { section: "players", country: c.name },
      });
    });
    return items;
  }, [data, sections]);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    const filtered = index.filter((item) => {
      if (filter !== "All" && item.kind !== filter) return false;
      if (!q) return true;
      return item.title.toLowerCase().includes(q) || item.subtitle.toLowerCase().includes(q);
    });
    if (!q) {
      // Curated defaults when opening empty search
      const featuredIds = [
        "game:ios:1036661603",
        "game:google:com.nokia.bounce",
        "topic:Too many ads",
        "topic:Fun to play",
        "country:Indonesia",
        "sec:design",
      ];
      const curated = filtered.filter((x) => featuredIds.some((f) => x.id.includes(f.split(":")[1])));
      return (curated.length ? curated : filtered).slice(0, 10);
    }
    const score = (title) => {
      const t = title.toLowerCase();
      if (t === q) return 0;
      if (t.startsWith(q)) return 1;
      if (t.includes(q)) return 2;
      return 3;
    };
    return filtered
      .sort((a, b) => score(a.title) - score(b.title) || a.title.length - b.title.length)
      .slice(0, 14);
  }, [index, query, filter]);

  useEffect(() => {
    setCursor(0);
  }, [query, filter]);

  if (!open) return null;

  function choose(item) {
    onPick(item.action);
    onClose();
    setQuery("");
  }

  function onKeyDown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      onClose();
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      setCursor((c) => (results.length ? (c + 1) % results.length : 0));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setCursor((c) => (results.length ? (c - 1 + results.length) % results.length : 0));
    } else if (e.key === "Enter" && results[cursor]) {
      e.preventDefault();
      choose(results[cursor]);
    }
  }

  return (
    <div className="ss-backdrop" role="presentation" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="ss-modal" role="dialog" aria-modal="true" aria-label="Smart search" onKeyDown={onKeyDown}>
        <div className="ss-head">
          <span className="ss-eyebrow"><IconSpark size={14} /> Smart Search</span>
          <button className="icon-btn" onClick={onClose} aria-label="Close search"><IconClose /></button>
        </div>
        <div className="ss-input-wrap">
          <IconSearch size={18} />
          <input
            ref={inputRef}
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Jump to any game, review topic, country, or section…"
            aria-label="Search games, topics, countries, or sections"
          />
          {query && <button className="ss-clear" onClick={() => setQuery("")}>Clear</button>}
        </div>
        <div className="ss-chips" role="group" aria-label="Filter search results">
          {FILTERS.map((f) => (
            <button key={f} className="chip sm" aria-pressed={filter === f} onClick={() => setFilter(f)}>{f}</button>
          ))}
        </div>
        <ul className="ss-list" role="listbox">
          {results.length === 0 ? (
            <li className="ss-empty">No matches for “{query}”. Try another game title, topic, or country.</li>
          ) : (
            results.map((item, idx) => (
              <li key={item.id}>
                <button
                  className={`ss-item${idx === cursor ? " is-active" : ""}`}
                  onMouseEnter={() => setCursor(idx)}
                  onClick={() => choose(item)}
                >
                  <span className="ss-kind">{item.kind.slice(0, -1) || item.kind}</span>
                  <span className="ss-main">
                    <strong>{item.title}</strong>
                    <span>{item.subtitle}</span>
                  </span>
                  <span className="ss-badge">{item.badge}</span>
                  <IconArrowRight size={14} />
                </button>
              </li>
            ))
          )}
        </ul>
        <div className="ss-foot">
          <span><kbd>↑</kbd> <kbd>↓</kbd> navigate</span>
          <span><kbd>Enter</kbd> jump</span>
          <span><kbd>Esc</kbd> close</span>
        </div>
      </div>
    </div>
  );
}
