import { useEffect, useMemo, useRef, useState } from "react";
import data from "./data.json";
import { Hero } from "./Hero.jsx";
import { Bouncer, BouncePlay } from "./Bouncer.jsx";
import {
  Chips,
  Columns,
  DataTable,
  DivergingBars,
  DotList,
  Figure,
  HBars,
  LineChart,
  MultiLineChart,
  RadialGauge,
  RangeBars,
  SegBar,
  SERIES_COLORS,
  TipRows,
} from "./charts.jsx";
import { compact, full, pct, usd } from "./format.js";
import {
  IconArrowRight,
  IconCompare,
  IconMoon,
  IconOrbital,
  IconReset,
  IconSearch,
  IconSliders,
  IconSun,
} from "./components/Icons.jsx";
import { SmartSearch } from "./components/SmartSearch.jsx";

const SECTIONS = [
  ["top", "Overview"],
  ["topics", "Loved and hated"],
  ["games", "Games"],
  ["players", "Where players are"],
  ["money", "Money"],
  ["time", "Over time"],
  ["design", "Design choices"],
  ["method", "How this was made"],
];
const ALL = "All ball games";
const CATS = ["Ball platformers", "Rolling ball", "Physics and bouncing", "Rhythm and hybrid", "Marble shooters", "Boulder action", "Not classified"];
const RAW_CAT = {
  "A: Ball platformer": "Ball platformers",
  "B: Rolling ball": "Rolling ball",
  "C: Ball physics & bouncing": "Physics and bouncing",
  "D: Hybrid / rhythm & transform": "Rhythm and hybrid",
  "Adjacent: marble shooter": "Marble shooters",
  "Adjacent: boulder action": "Boulder action",
};
const CAT_ABOUT = {
  "Ball platformers": "Bounce, Red Ball and other games where the ball is the hero who jumps through levels",
  "Rolling ball": "Super Monkey Ball, Going Balls and other games about steering a rolling ball",
  "Physics and bouncing": "Brick breakers, Peggle, Helix Jump: aiming and bouncing balls",
  "Rhythm and hybrid": "Geometry Dash, Tiles Hop and other music-timed or shape-changing games",
  "Marble shooters": "Zuma and Luxor: shoot marbles to match colours",
  "Boulder action": "Rock of Ages: roll a giant boulder at your enemies",
};
const SHORT_STORE = { "Google Play (Android)": "Google Play", "App Store (iOS)": "App Store", "Steam (PC)": "Steam" };
const themeInfo = Object.fromEntries(data.themes.map((t) => [t.theme, t]));
const isSpecific = (theme) => themeInfo[theme]?.group !== "General reaction";
const sharePos = (r) => r.pos / (r.pos + r.neg + r.neu || 1);

const IDS = SECTIONS.map(([id]) => id);
const fromHash = () => (IDS.includes(location.hash.slice(1)) ? location.hash.slice(1) : "top");

const THEMES = [
  { id: "light", label: "Light", Icon: IconSun },
  { id: "dark", label: "Dark", Icon: IconMoon },
  { id: "hud", label: "JARVIS HUD", Icon: IconOrbital },
];

function getInitialTheme() {
  try {
    const saved = localStorage.getItem("ball-dash-theme");
    if (saved === "light" || saved === "dark" || saved === "hud") return saved;
  } catch { /* ignore */ }
  if (typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: dark)").matches) return "dark";
  return "light";
}

export default function App() {
  const [active, setActive] = useState(fromHash);
  const [visited, setVisited] = useState(() => new Set([fromHash()]));
  const [theme, setTheme] = useState(getInitialTheme);
  const [searchOpen, setSearchOpen] = useState(false);
  const [play, setPlay] = useState(0);

  // Cross-section deep-link state so Smart Search & chart clicks jump cleanly into context
  const [selectedTopic, setSelectedTopic] = useState("Too many ads");
  const [topicCategory, setTopicCategory] = useState(ALL);
  const [selectedGameId, setSelectedGameId] = useState(() => (data.games.find((g) => g.title === "Bounce Classic") ?? data.games[0]).id);
  const [compareGameId, setCompareGameId] = useState(null);
  const [selectedCountry, setSelectedCountry] = useState("United States");

  const main = useRef(null);
  const shown = useRef(active);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    try { localStorage.setItem("ball-dash-theme", theme); } catch { /* ignore */ }
  }, [theme]);

  useEffect(() => {
    const onHash = () => setActive(fromHash());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  useEffect(() => {
    const onKey = (e) => {
      const key = e.key?.toLowerCase();
      if ((e.metaKey || e.ctrlKey) && key === "k") {
        e.preventDefault();
        setSearchOpen((v) => !v);
      } else if (e.key === "/" && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName)) {
        e.preventDefault();
        setSearchOpen(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    setVisited((v) => (v.has(active) ? v : new Set(v).add(active)));
    if (shown.current === active) return;
    shown.current = active;
    window.scrollTo(0, 0);
    main.current?.querySelector("h1, h2")?.focus({ preventScroll: true });
  }, [active]);

  function navigate({ section, topic, category, gameId, country }) {
    if (topic) setSelectedTopic(topic);
    if (category) setTopicCategory(category);
    if (gameId) setSelectedGameId(gameId);
    if (country) setSelectedCountry(country);
    if (section) {
      if (location.hash.slice(1) !== section) location.hash = `#${section}`;
      setActive(section);
    }
  }

  const activeTitle = SECTIONS.find(([id]) => id === active)?.[1] ?? "Overview";

  return (
    <div className="app">
      <a className="skip" href="#main" onClick={(e) => { e.preventDefault(); main.current?.querySelector("h1, h2")?.focus(); }}>
        Skip to the section
      </a>
      <Nav active={active} visited={visited} onPick={() => setPlay((n) => n + 1)} />
      <div className="shell">
        <header className="topbar">
          <div className="topbar-left">
            <span className="crumb">Ball Game Intelligence</span>
            <span className="crumb-sep" aria-hidden="true">/</span>
            <span className="crumb-cur">{activeTitle}</span>
            <span className="live-pill">{full(data.meta.games)} games · {compact(data.meta.reviews)} reviews</span>
          </div>
          <div className="topbar-right">
            <button className="search-trigger" onClick={() => setSearchOpen(true)} aria-label="Open smart search">
              <IconSearch size={15} />
              <span>Smart search…</span>
              <kbd>Ctrl K</kbd>
            </button>
            <div className="theme-switch" role="group" aria-label="Appearance mode">
              {THEMES.map(({ id, label, Icon }) => (
                <button
                  key={id}
                  className="theme-btn"
                  aria-pressed={theme === id}
                  onClick={() => setTheme(id)}
                  title={`Switch to ${label} mode`}
                >
                  <Icon size={14} />
                  <span>{label}</span>
                </button>
              ))}
            </div>
          </div>
        </header>

        <BouncePlay.Provider value={play}>
        <main ref={main} id="main">
          {active === "top" && <Overview theme={theme} onNavigate={navigate} />}
          {active === "topics" && (
            <Topics
              cat={topicCategory}
              setCat={setTopicCategory}
              sel={selectedTopic}
              setSel={setSelectedTopic}
            />
          )}
          {active === "games" && (
            <Games
              sel={selectedGameId}
              setSel={setSelectedGameId}
              compareId={compareGameId}
              setCompareId={setCompareGameId}
              onJumpTopic={(topic) => navigate({ section: "topics", topic })}
            />
          )}
          {active === "players" && <Players selCountry={selectedCountry} setSelCountry={setSelectedCountry} />}
          {active === "money" && <Money onOpenGame={(gameId) => navigate({ section: "games", gameId })} />}
          {active === "time" && <OverTime />}
          {active === "design" && <Design />}
          {active === "method" && <Method />}
          <footer className="foot">
            Built from public store listings and reviews collected on 26 November 2026. Review quotes are short phrases from public reviews, shown in lower case
            and filtered for profanity and personal details.
          </footer>
        </main>
        </BouncePlay.Provider>
      </div>

      <SmartSearch
        open={searchOpen}
        onClose={() => setSearchOpen(false)}
        data={data}
        sections={SECTIONS}
        onPick={navigate}
      />
    </div>
  );
}

function Overview({ theme, onNavigate }) {
  const top = (name) => data.themes.find((t) => t.theme === name);
  const fun = top("Fun to play"), ads = top("Too many ads"), levels = top("Wants more levels");
  const spotlightGames = ["Bounce Classic", "Geometry Dash", "Going Balls"]
    .map((t) => data.games.find((g) => g.title === t))
    .filter(Boolean);

  return (
    <>
      <Hero
        theme={theme}
        onSelectFinding={(topic) => onNavigate({ section: "topics", topic })}
        findings={[
          { topic: "Fun to play", title: "Fun is the top praise", text: `${compact(fun.mentions)} reviews call the game fun; ${pct(sharePos(fun))} positive.` },
          { topic: "Too many ads", title: "Ads are the top complaint", text: `${compact(ads.mentions)} reviews mention too many ads; ${pct(ads.neg / ads.mentions)} negative.` },
          { topic: "Wants more levels", title: "Players want more levels", text: `${compact(levels.mentions)} reviews ask for more levels; ${pct(sharePos(levels))} still like it.` },
        ]}
      >
        <div className="hero-eyebrow-row">
          <span className="pill-tag">Interactive Research Studio</span>
          <span className="pill-tag subtle">{full(data.meta.themes)} review topics · 30 countries</span>
        </div>
        <h1 tabIndex={-1}>What players love and hate about ball games</h1>
        <p className="lead">
          Nokia&apos;s <em>Bounce</em> put a red rubber ball on millions of phones in 2001. Thousands of ball games have followed: platformers,
          rolling-ball races, brick breakers and rhythm hops. Explore {full(data.meta.reviews)} store reviews across {full(data.meta.games)} games—drag the
          ball below, search any title, or jump into a section.
        </p>
      </Hero>

      <div className="wrap">
        <div className="bento-kpis">
          <button className="bento-kpi" onClick={() => onNavigate({ section: "topics" })}>
            <span className="bk-label">Reviews analyzed</span>
            <strong className="bk-val">{full(data.meta.reviews)}</strong>
            <span className="bk-sub">Sorted into {data.meta.themes} topics <IconArrowRight size={13} /></span>
          </button>
          <button className="bento-kpi" onClick={() => onNavigate({ section: "games" })}>
            <span className="bk-label">Store listings</span>
            <strong className="bk-val">{full(data.meta.games)}</strong>
            <span className="bk-sub">{data.games.length} deep-dive games (200+ reviews) <IconArrowRight size={13} /></span>
          </button>
          <button className="bento-kpi" onClick={() => onNavigate({ section: "players" })}>
            <span className="bk-label">Store ratings</span>
            <strong className="bk-val">{compact(data.meta.ratings)}</strong>
            <span className="bk-sub">Across 30 country App Stores <IconArrowRight size={13} /></span>
          </button>
          <button className="bento-kpi" onClick={() => onNavigate({ section: "method" })}>
            <span className="bk-label">Model accuracy</span>
            <strong className="bk-val">{pct(data.models.sentiment.after_fine_tuning.accuracy, 1)}</strong>
            <span className="bk-sub">Fine-tuned XLM-RoBERTa sentiment <IconArrowRight size={13} /></span>
          </button>
        </div>

        <div className="overview-grid">
          <div className="panel">
            <div className="panel-head-inline">
              <div>
                <h3>Spotlight games</h3>
                <p className="muted">Click any title to inspect its sentiment gauge and topic lifts.</p>
              </div>
              <button className="link-btn" onClick={() => onNavigate({ section: "games" })}>Browse all {data.games.length}</button>
            </div>
            <div className="spotlight-list">
              {spotlightGames.map((g) => (
                <button key={g.id} className="spot-card" onClick={() => onNavigate({ section: "games", gameId: g.id })}>
                  <div className="spot-top">
                    <strong>{g.title}</strong>
                    <span className="spot-score">{pct(g.textPos)} positive</span>
                  </div>
                  <div className="spot-meta">{SHORT_STORE[g.platform]} · {g.category} · {full(g.reviews)} reviews</div>
                  <SegBar parts={[{ label: "Positive", value: g.textPos, cls: "love" }, { label: "Neutral", value: Math.max(0, 1 - g.textPos - g.textNeg), cls: "neu" }, { label: "Negative", value: g.textNeg, cls: "hate" }]} />
                </button>
              ))}
            </div>
          </div>

          <div className="panel">
            <div className="panel-head-inline">
              <div>
                <h3>Jump by ball game genre</h3>
                <p className="muted">Filter review topics directly by how the game plays.</p>
              </div>
              <button className="link-btn" onClick={() => onNavigate({ section: "design" })}>Open Design Simulator</button>
            </div>
            <div className="genre-pills">
              {data.categories.filter((c) => CAT_ABOUT[c.label]).map((c) => (
                <button
                  key={c.label}
                  className="genre-tile"
                  onClick={() => onNavigate({ section: "topics", category: c.label })}
                >
                  <strong>{c.label}</strong>
                  <span>{full(c.listings)} listings · {compact(c.mentions)} mentions</span>
                </button>
              ))}
            </div>
          </div>
        </div>

        <Pager id="top" />
      </div>
    </>
  );
}

function Nav({ active, visited, onPick }) {
  const seen = IDS.filter((id) => visited.has(id)).length;
  useEffect(() => {
    document.querySelector(".side [aria-current]")?.scrollIntoView({ block: "nearest", inline: "nearest" });
  }, [active]);
  return (
    <aside className="side">
      <a className="brand" href="#top"><span className="brand-ball" aria-hidden="true" />Ball game reviews</a>
      <nav aria-label="Sections">
        <ol>
          {SECTIONS.map(([id, label], i) => {
            const here = active === id, been = visited.has(id);
            return (
              <li key={id}>
                <a href={`#${id}`} aria-current={here ? "page" : undefined} className={been ? "been" : undefined} onClick={onPick}>
                  <span className="mark" aria-hidden="true">{here && <span key={id} className="mark-ball" />}</span>
                  <span className="nav-n" aria-hidden="true">{String(i).padStart(2, "0")}</span>
                  <span className="nav-label">{label}</span>
                  {been && !here && <span className="sr-only">, opened</span>}
                </a>
              </li>
            );
          })}
        </ol>
      </nav>
      <p className="side-note">{seen} of {IDS.length} sections opened</p>
    </aside>
  );
}

function Pager({ id }) {
  const i = IDS.indexOf(id);
  const prev = SECTIONS[i - 1], next = SECTIONS[i + 1];
  return (
    <nav className="pager" aria-label="Section steps">
      {prev ? <a className="pg prev" href={`#${prev[0]}`}><span className="pg-k">Back</span>{prev[1]}</a> : <span />}
      {next && <a className="pg next" href={`#${next[0]}`}><span className="pg-k">Next</span>{next[1]}</a>}
    </nav>
  );
}

function Section({ id, title, lead, children }) {
  return (
    <section id={id} className="sec" aria-labelledby={`${id}-h`}>
      <div className="wrap">
        <div className="sec-head">
          <p className="eyebrow">{String(IDS.indexOf(id)).padStart(2, "0")} · {SECTIONS[IDS.indexOf(id)][1]}</p>
          <Bouncer scene={id} />
        </div>
        <h2 id={`${id}-h`} tabIndex={-1}>{title}</h2>
        {lead && <p className="sec-lead">{lead}</p>}
        {children}
        <Pager id={id} />
      </div>
    </section>
  );
}

function Quotes({ items, tone }) {
  if (!items?.length) return <p className="muted">No clear examples in this topic.</p>;
  return <ul className={`quotes ${tone}`}>{items.map((q) => <li key={q}>{q}</li>)}</ul>;
}

function Topics({ cat, setCat, sel, setSel }) {
  const [sortBy, setSortBy] = useState("Net positive");
  const [query, setQuery] = useState("");
  const base = cat === ALL ? data.themes : data.themeByCategory[cat];
  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    const list = base
      .filter((t) => isSpecific(t.theme) && (!q || t.theme.toLowerCase().includes(q)))
      .map((t) => ({ label: t.theme, pos: t.pos, neg: t.neg, neu: t.neu, mentions: t.mentions }));
    if (sortBy === "Most mentioned") return list.sort((a, b) => b.mentions - a.mentions);
    if (sortBy === "Most negative") return list.sort((a, b) => b.neg / b.mentions - a.neg / a.mentions);
    return list.sort((a, b) => (b.pos - b.neg) / b.mentions - (a.pos - a.neg) / a.mentions);
  }, [base, query, sortBy]);

  const s = rows.find((r) => r.label === sel) ?? rows[0];
  const info = s ? themeInfo[s.label] : null;
  const general = base.filter((t) => !isSpecific(t.theme)).reduce((n, t) => n + t.mentions, 0);

  // Cross-genre breakdown for the selected topic
  const acrossGenres = useMemo(() => {
    if (!s) return [];
    return CATS.filter((c) => CAT_ABOUT[c]).map((c) => {
      const found = (data.themeByCategory[c] ?? []).find((t) => t.theme === s.label);
      const posRate = found && found.mentions ? found.pos / found.mentions : 0;
      return { label: c, value: posRate, mentions: found?.mentions ?? 0 };
    });
  }, [s]);

  return (
    <Section
      id="topics"
      title="Fun keeps people playing. Ads make them quit."
      lead={`A model read every review and sorted what people wrote into ${data.meta.themes} topics. Praise gathers around fun, calm and clever design; complaints gather around ads, crashes and difficulty. Pick any topic or genre to inspect player quotes and cross-genre patterns.`}
    >
      <div className="filters">
        <Chips label="Kind of ball game" options={[ALL, ...CATS]} value={cat} onChange={setCat} />
        <div className="filter-line">
          <label className="search">
            <IconSearch size={14} />
            <input type="search" placeholder="Filter topics…" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Filter topics" />
          </label>
          <Chips label="Sort topics" options={["Net positive", "Most mentioned", "Most negative"]} value={sortBy} onChange={setSortBy} size="sm" />
        </div>
      </div>

      <div className="split">
        <Figure
          title={`What reviews praise and complain about${cat === ALL ? "" : `: ${cat.toLowerCase()}`}`}
          note={`Each bar splits one topic's mentions into praise, neutral and complaints. ${full(general)} plain “good game” or “bad game” comments are left out.`}
          table={{
            caption: "Topic mentions",
            rows,
            columns: [
              { key: "label", label: "Topic" },
              { key: "pos", label: "Praise", num: true, format: full },
              { key: "neu", label: "Neutral", num: true, format: full },
              { key: "neg", label: "Complaints", num: true, format: full },
              { key: "share", label: "Positive", num: true, sortValue: (r) => sharePos(r), format: (_, r) => pct(sharePos(r)) },
            ],
          }}
        >
          {rows.length === 0 ? (
            <p className="muted">No topics match “{query}”.</p>
          ) : (
            <DivergingBars rows={rows} selected={s.label} onSelect={setSel} />
          )}
        </Figure>

        {s && info && (
          <aside className="panel sticky" aria-live="polite">
            <div className="panel-top-row">
              <div>
                <span className="panel-tag">{info.group}</span>
                <h3>{s.label}</h3>
              </div>
              <RadialGauge
                value={sharePos(s) * 100}
                size={84}
                color={sharePos(s) >= 0.5 ? "var(--love)" : "var(--hate)"}
                formatValue={(v) => `${Math.round(v)}%`}
              />
            </div>
            <p className="muted">
              {full(s.mentions)} mentions{cat === ALL ? "" : ` in ${cat.toLowerCase()}`}: {pct(sharePos(s))} positive, {pct(s.neg / s.mentions)} negative.
            </p>
            <SegBar parts={[{ label: "Praise", value: s.pos, cls: "love" }, { label: "Neutral", value: s.neu, cls: "neu" }, { label: "Complaints", value: s.neg, cls: "hate" }]} />
            <h4><i className="key love" />What players praise</h4>
            <Quotes items={info.praise} tone="love" />
            <h4><i className="key hate" />What players complain about</h4>
            <Quotes items={info.complaints} tone="hate" />

            <h4>Positive share across genres</h4>
            <HBars
              rows={acrossGenres}
              color="var(--love)"
              max={1}
              fmt={(v) => pct(v)}
              selected={cat}
              onSelect={(label) => setCat(label === cat ? ALL : label)}
              tipFor={(r) => <TipRows title={r.label} rows={[{ color: "var(--love)", value: pct(r.value), label: "positive" }, { value: full(r.mentions), label: "mentions" }]} />}
            />
          </aside>
        )}
      </div>

      <h3 className="sub">What each kind of ball game is known for</h3>
      <p className="sub-lead">Click any genre card to filter the topic chart above.</p>
      <div className="kinds">
        {CATS.filter((c) => CAT_ABOUT[c]).map((c) => {
          const meta = data.categories.find((x) => x.label === c);
          const isCat = cat === c;
          return (
            <button className={`kind kind-btn${isCat ? " is-active" : ""}`} key={c} onClick={() => { setCat(isCat ? ALL : c); window.scrollTo({ top: 180, behavior: "smooth" }); }}>
              <h4>{c}</h4>
              <p className="muted">{CAT_ABOUT[c]}. {full(meta.listings)} store listings, {compact(meta.mentions)} topic mentions.</p>
              <ul>
                {data.categoryLift[c].map((l) => (
                  <li key={l.theme}><span>{l.theme}</span><span className="fig-num">{l.lift.toFixed(1)}× as often</span></li>
                ))}
              </ul>
            </button>
          );
        })}
      </div>
    </Section>
  );
}

function Games({ sel, setSel, compareId, setCompareId, onJumpTopic }) {
  const [cat, setCat] = useState(ALL);
  const [store, setStore] = useState("All stores");
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState("Most reviewed");
  const [showAll, setShowAll] = useState(false);

  const list = useMemo(() => {
    const q = query.trim().toLowerCase();
    return data.games
      .filter((g) => {
        if (cat !== ALL && g.category !== cat) return false;
        if (store !== "All stores" && SHORT_STORE[g.platform] !== store) return false;
        if (q && !g.title.toLowerCase().includes(q) && !(g.developer ?? "").toLowerCase().includes(q)) return false;
        return true;
      })
      .sort((a, b) => {
        if (sort === "Most positive") return b.textPos - a.textPos;
        if (sort === "Most negative") return b.textNeg - a.textNeg;
        if (sort === "Biggest star gap") return Math.abs(b.starPos - b.textPos) - Math.abs(a.starPos - a.textPos);
        if (sort === "Most installs") return (b.installs ?? -1) - (a.installs ?? -1);
        return b.reviews - a.reviews;
      });
  }, [cat, store, query, sort]);

  const shown = showAll ? list : list.slice(0, 15);
  const g = data.games.find((x) => x.id === sel) ?? list[0] ?? data.games[0];
  const cmp = compareId ? data.games.find((x) => x.id === compareId) : null;
  const themes = data.gameThemes[g.id] ?? [];
  const steam = g.platform.startsWith("Steam");
  const gap = g.starPos - g.textPos;

  return (
    <Section
      id="games"
      title="The Nokia classic still wins players over. Some of the biggest hits split them."
      lead={`How positive each game's reviews read, for the ${data.games.length} games with at least 200 reviews. Filter by store or genre, click any game to inspect its sentiment telemetry, or pin two titles side-by-side to compare.`}
    >
      <div className="filters">
        <Chips label="Kind of ball game" options={[ALL, ...CATS]} value={cat} onChange={setCat} />
        <div className="filter-line">
          <Chips label="Store" options={["All stores", "Google Play", "App Store", "Steam"]} value={store} onChange={setStore} size="sm" />
          <label className="search">
            <IconSearch size={14} />
            <input type="search" placeholder="Find a game or studio…" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Find a game or studio" />
          </label>
          <Chips label="Sort games" options={["Most reviewed", "Most positive", "Most negative", "Biggest star gap", "Most installs"]} value={sort} onChange={setSort} size="sm" />
        </div>
      </div>

      {cmp && (
        <div className="compare-drawer">
          <div className="compare-head">
            <h3><IconCompare size={16} /> Side-by-side comparison</h3>
            <button className="link-btn" onClick={() => setCompareId(null)}>Exit compare</button>
          </div>
          <div className="compare-cols">
            {[g, cmp].map((item, idx) => (
              <div key={idx === 0 ? "slot-a" : "slot-b"} className="compare-card">
                <div className="compare-card-top">
                  <div>
                    <span className="panel-tag">
                      {idx === 0 ? "Selected (A)" : g.id === cmp.id ? "Pinned (B) · pick another game below" : "Pinned (B)"} · {SHORT_STORE[item.platform]}
                    </span>
                    <h4>{item.title}</h4>
                  </div>
                  <RadialGauge value={item.textPos * 100} size={76} color="var(--love)" formatValue={(v) => `${Math.round(v)}%`} />
                </div>
                <SegBar parts={[{ label: "Positive", value: item.textPos, cls: "love" }, { label: "Neutral", value: Math.max(0, 1 - item.textPos - item.textNeg), cls: "neu" }, { label: "Negative", value: item.textNeg, cls: "hate" }]} />
                <dl className="facts compact">
                  <div><dt>Reviews</dt><dd>{full(item.reviews)}</dd></div>
                  <div><dt>Text positive</dt><dd>{pct(item.textPos)}</dd></div>
                  <div><dt>Stars positive</dt><dd>{pct(item.starPos)}</dd></div>
                  <div><dt>Top praise</dt><dd>{item.praised ?? "–"}</dd></div>
                  <div><dt>Top complaint</dt><dd>{item.criticised ?? "–"}</dd></div>
                </dl>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="split">
        <Figure
          title={`Share of reviews that read positive (${list.length} matching)`}
          note="Read from the review text by the sentiment model, not from the stars."
          table={{
            caption: "Games",
            rows: list,
            rowKey: (r) => r.id,
            selectedKey: g.id,
            onRowClick: (r) => setSel(r.id),
            columns: [
              { key: "title", label: "Game" },
              { key: "platform", label: "Store", format: (v) => SHORT_STORE[v] },
              { key: "category", label: "Kind" },
              { key: "reviews", label: "Reviews", num: true, format: full },
              { key: "textPos", label: "Positive (text)", num: true, format: (v) => pct(v) },
              { key: "starPos", label: "Positive (stars)", num: true, format: (v) => pct(v) },
            ],
          }}
        >
          {list.length === 0 ? (
            <p className="muted">No game matches those filters. Clear the search or pick another store/genre.</p>
          ) : (
            <>
              <ul className="meter-list">
                {shown.map((x) => (
                  <li key={x.id}>
                    <button aria-pressed={x.id === g.id} onClick={() => setSel(x.id)} aria-label={`${x.title}, ${SHORT_STORE[x.platform]}: ${pct(x.textPos)} positive`}>
                      <span className="ml-name">
                        {x.title}
                        <span className="ml-store">{SHORT_STORE[x.platform]} · {full(x.reviews)} reviews</span>
                      </span>
                      <span className="ml-track"><span className="ml-bar" style={{ width: `${x.textPos * 100}%` }} /></span>
                      <span className="ml-val">{pct(x.textPos)}</span>
                    </button>
                  </li>
                ))}
              </ul>
              {list.length > 15 && (
                <button className="link-btn more" onClick={() => setShowAll(!showAll)}>
                  {showAll ? "Show the first 15" : `Show all ${list.length} games`}
                </button>
              )}
            </>
          )}
        </Figure>

        <aside className="panel sticky" aria-live="polite">
          <div className="panel-top-row">
            <div>
              <span className="panel-tag">{SHORT_STORE[g.platform]} · {g.category}</span>
              <h3>{g.title}</h3>
            </div>
            <button
              className="chip sm"
              aria-pressed={compareId === g.id}
              onClick={() => setCompareId(compareId === g.id ? null : g.id)}
              title="Pin this game to compare side-by-side with another game"
            >
              <IconCompare size={13} /> {compareId === g.id ? "Pinned" : "Compare"}
            </button>
          </div>

          <div className="gauge-row">
            <RadialGauge value={g.textPos * 100} label="Text positive" sublabel="NLP model" color="var(--love)" size={94} formatValue={(v) => `${Math.round(v)}%`} />
            <RadialGauge value={g.starPos * 100} label="Stars positive" sublabel="Store stars" color="var(--mag)" size={94} formatValue={(v) => `${Math.round(v)}%`} />
          </div>

          <dl className="facts">
            {g.developer && <div><dt>Developer</dt><dd>{g.developer}</dd></div>}
            {g.year && <div><dt>Released</dt><dd>{g.year}</dd></div>}
            {g.installs != null && <div><dt>{steam ? "Owners (est.)" : "Installs"}</dt><dd>{compact(g.installs)}+</dd></div>}
            {g.score != null && <div><dt>Store rating</dt><dd>{steam ? `${g.score}% recommend` : `${(g.score / 20).toFixed(1)} of 5 ★`}</dd></div>}
            <div><dt>Reviews read</dt><dd>{full(g.reviews)}</dd></div>
            <div><dt>Star vs text gap</dt><dd>{gap >= 0 ? `+${pct(gap)}` : pct(gap)}</dd></div>
          </dl>

          <SegBar parts={[{ label: "Positive", value: g.textPos, cls: "love" }, { label: "Neutral", value: Math.max(0, 1 - g.textPos - g.textNeg), cls: "neu" }, { label: "Negative", value: g.textNeg, cls: "hate" }]} />
          <p className="muted">
            The text reads {pct(g.textPos)} positive and {pct(g.textNeg)} negative.
            {g.praised && <> Praised most for <button className="inline-link" onClick={() => onJumpTopic(g.praised)}>{g.praised.toLowerCase()}</button>.</>}
            {g.criticised && <> Criticised most for <button className="inline-link" onClick={() => onJumpTopic(g.criticised)}>{g.criticised.toLowerCase()}</button>.</>}
          </p>

          <h4>Talked about more than in other {g.category.toLowerCase()} games</h4>
          {themes.length ? (
            <HBars
              rows={themes.map((t) => ({ label: t.theme, value: t.lift, ...t }))}
              fmt={(v) => `${v.toFixed(1)}×`}
              onSelect={(topic) => onJumpTopic(topic)}
              tipFor={(r) => (
                <TipRows
                  title={r.label}
                  rows={[
                    { value: `${r.lift.toFixed(1)}×`, label: "as often as usual (click to open)" },
                    { value: full(r.mentions), label: "mentions" },
                    { color: "var(--love)", value: pct(r.pos), label: "positive" },
                  ]}
                />
              )}
            />
          ) : (
            <p className="muted">Too few reviews to compare topics for this game.</p>
          )}
          {g.url && <p className="ext-link"><a href={g.url} target="_blank" rel="noreferrer">Open the store page <IconArrowRight size={13} /></a></p>}
        </aside>
      </div>
    </Section>
  );
}

function Players({ selCountry, setSelCountry }) {
  const c = data.countries;
  const hiC = c.slice(0, 3).map((x) => x.name), loC = c.slice(-2).map((x) => x.name);
  const lang = data.languages;
  const [cQuery, setCQuery] = useState("");

  const filteredCountries = useMemo(() => {
    const q = cQuery.trim().toLowerCase();
    return q ? c.filter((x) => x.name.toLowerCase().includes(q)) : c;
  }, [c, cQuery]);

  const spot = c.find((x) => x.name === selCountry) ?? c[0];
  const spotRank = c.findIndex((x) => x.name === spot.name) + 1;
  const spotThemes = data.countryThemes.find((x) => x.name === spot.name);

  return (
    <Section
      id="players"
      title={`${hiC[0]}, ${hiC[1]} and ${hiC[2]} rate ball games highest.`}
      lead={`No store publishes the age or gender of a game's players, so country and language are the closest public signals. Click any country below to inspect its regional rating profile and review themes.`}
    >
      <div className="panel spotlight-banner">
        <div className="spot-banner-main">
          <div>
            <span className="panel-tag">Regional spotlight · Rank #{spotRank} of {c.length}</span>
            <h3>{spot.name}</h3>
            <p className="muted">
              {compact(spot.ratings)} App Store ratings across 521 iOS ball games · average {spot.avg.toFixed(2)} of 5 stars.
            </p>
          </div>
          <div className="spot-banner-gauges">
            <RadialGauge value={(spot.avg / 5) * 100} label="Avg rating" sublabel={`${spot.avg.toFixed(2)} / 5`} color="var(--mag)" size={90} formatValue={() => spot.avg.toFixed(2)} />
            {spotThemes && (
              <div className="spot-country-themes">
                <div><span className="key hate" /> Top complaint: <strong>{spotThemes.topComplaint}</strong> ({pct(spotThemes.complaintShare)})</div>
                <div><span className="key love" /> Top praise: <strong>{spotThemes.topPraise}</strong> ({pct(spotThemes.praiseShare)})</div>
                <div className="muted">{full(spotThemes.mentions)} App Store topic mentions analysed</div>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="grid2">
        <Figure
          title="Average App Store rating, by country"
          note="Across 521 iOS ball games, weighted by how many ratings each game has. Click a country to highlight."
          actions={
            <label className="search sm">
              <IconSearch size={13} />
              <input type="search" placeholder="Filter countries…" value={cQuery} onChange={(e) => setCQuery(e.target.value)} aria-label="Filter countries" />
            </label>
          }
          table={{
            caption: "Country ratings",
            rows: filteredCountries,
            rowKey: (r) => r.name,
            selectedKey: spot.name,
            onRowClick: (r) => setSelCountry(r.name),
            columns: [
              { key: "name", label: "Country" },
              { key: "avg", label: "Average rating", num: true, format: (v) => v.toFixed(2) },
              { key: "ratings", label: "Ratings", num: true, format: full },
            ],
          }}
        >
          <DotList
            rows={filteredCountries.map((x) => ({ label: x.name, value: x.avg, ratings: x.ratings }))}
            domain={[4.2, 4.7]}
            tickVals={[4.2, 4.3, 4.4, 4.5, 4.6, 4.7]}
            fmt={(v) => v.toFixed(2)}
            selected={spot.name}
            onSelect={(name) => setSelCountry(name)}
            tipFor={(r) => <TipRows title={r.label} rows={[{ value: r.value.toFixed(2), label: "average stars" }, { value: compact(r.ratings), label: "ratings" }]} />}
          />
        </Figure>

        <div className="stack">
          <Figure
            title="New Google Play reviews per day, by language"
            note={`Last 30 days, ${data.languageGames} most-rated Google Play ball games. Hindi looks small because most Indian players review in English.`}
            table={{
              caption: "Reviews per day by language",
              rows: lang,
              columns: [{ key: "name", label: "Language" }, { key: "perDay", label: "Reviews per day", num: true, format: full }],
            }}
          >
            <HBars
              rows={lang.map((l) => ({ label: l.name, value: l.perDay }))}
              fmt={(v) => full(v)}
              tipFor={(r) => <TipRows title={r.label} rows={[{ color: "var(--mag)", value: full(r.value), label: "reviews a day" }]} />}
            />
          </Figure>

          <Figure
            title="What each country's players complain about and praise"
            note="App Store reviews from 10 country stores, read in their own language. Click a row to spotlight."
          >
            <DataTable
              caption="Top topics by country"
              rows={data.countryThemes}
              rowKey={(r) => r.name}
              selectedKey={spot.name}
              onRowClick={(r) => setSelCountry(r.name)}
              columns={[
                { key: "name", label: "Country" },
                { key: "topComplaint", label: "Top complaint", format: (v, r) => <>{v} <span className="muted">{pct(r.complaintShare)}</span></> },
                { key: "topPraise", label: "Top praise", format: (v, r) => <>{v} <span className="muted">{pct(r.praiseShare)}</span></> },
              ]}
            />
          </Figure>
        </div>
      </div>
      <p className="fine">Lowest average App Store ratings in this sample: {loC[0]} and {loC[1]}.</p>
    </Section>
  );
}

const METRIC = {
  units_sold: "Copies sold",
  downloads: "Downloads",
  units_sold_steam: "Copies sold on Steam",
  gross_revenue_steam: "Steam revenue before the store's cut",
  gross_revenue_mobile: "Mobile in-app revenue",
  arcade_units_sold: "Arcade cabinets sold",
  arcade_units_produced: "Arcade cabinets built",
  development_time: "Time to make",
  installs_android: "Android installs",
  monthly_revenue_android: "Android revenue a month",
  distribution: "How it reached players",
};

function amount(f) {
  if (f.value_low == null) return f.note;
  const v = (n) => (f.unit?.startsWith("USD") ? usd(n) : f.unit === "months" ? `${n} months` : compact(n));
  return f.value_high && f.value_high !== f.value_low ? `${v(f.value_low)} to ${v(f.value_high)}` : v(f.value_low);
}

const BUCKET_BOUNDS = {
  "Under 1K": [0, 1000],
  "1K–10K": [1000, 10000],
  "10K–100K": [10000, 100000],
  "100K–1M": [100000, 1000000],
  "1M–10M": [1000000, 10000000],
  "10M–100M": [10000000, 100000000],
  "100M+": [100000000, Infinity],
};

function Money({ onOpenGame }) {
  const b = data.installBuckets;
  const big = b[b.length - 1];
  const m = data.monetisation;
  const [bucket, setBucket] = useState("100M+");
  const [confidence, setConfidence] = useState("All");

  const bucketObj = b.find((x) => x.label === bucket) ?? big;
  const [lo, hi] = BUCKET_BOUNDS[bucket] ?? [0, Infinity];
  const bucketGames = useMemo(
    () =>
      data.games
        .filter((g) => g.platform.startsWith("Google") && g.installs != null && g.installs >= lo && g.installs < hi)
        .sort((a, b) => b.installs - a.installs)
        .slice(0, 6),
    [lo, hi]
  );

  const filteredFigures = useMemo(
    () => (confidence === "All" ? data.figures : data.figures.filter((f) => f.confidence === confidence)),
    [confidence]
  );

  return (
    <Section
      id="money"
      title={`Ten games take ${pct(data.installTop10.share)} of all installs.`}
      lead="Most ball games are free and earn from ads. Click any install bucket column to see the biggest Google Play games in that tier, or filter and sort published revenue figures."
    >
      <div className="kpis">
        <div className="kpi"><span className="kpi-label">Google Play ball games that show ads</span><span className="kpi-value">{pct(m.ads)}</span></div>
        <div className="kpi"><span className="kpi-label">Sell items inside the game</span><span className="kpi-value">{pct(m.iap)}</span></div>
        <div className="kpi"><span className="kpi-label">Cost money to download</span><span className="kpi-value">{pct(m.paid, 1)}</span></div>
        <div className="kpi"><span className="kpi-label">Installs of these games, in total</span><span className="kpi-value">{compact(data.installTop10.total)}</span></div>
      </div>

      <div className="grid2">
        <Figure
          title="Google Play ball games, by number of installs"
          note={`${full(data.installTop10.games)} games, ${compact(data.installTop10.total)} installs in total. Click a column to inspect games in that tier.`}
          table={{
            caption: "Install buckets",
            rows: b,
            columns: [
              { key: "label", label: "Installs" },
              { key: "games", label: "Games", num: true, format: full },
              { key: "installShare", label: "Share of all installs", num: true, format: (v) => pct(v, 1) },
            ],
          }}
        >
          <Columns
            rows={b.map((x) => ({ label: x.label, value: x.games, share: x.installShare }))}
            height={200}
            selected={bucket}
            onSelect={setBucket}
            tipFor={(r) => <TipRows title={`${r.label} installs`} rows={[{ color: "var(--mag)", value: full(r.value), label: "games" }, { value: pct(r.share, 1), label: "of all installs" }]} />}
          />
          <div className="tier-inspector">
            <div className="tier-head">
              <strong>Tier: {bucketObj.label}</strong>
              <span className="muted">{full(bucketObj.games)} games · {pct(bucketObj.installShare, 1)} of all installs</span>
            </div>
            {bucketGames.length ? (
              <div className="tier-chips">
                {bucketGames.map((g) => (
                  <button key={g.id} className="tier-game" onClick={() => onOpenGame(g.id)}>
                    <span>{g.title}</span>
                    <span className="muted">{compact(g.installs)}+</span>
                  </button>
                ))}
              </div>
            ) : (
              <p className="muted">No games with 200+ read reviews fall into this smaller install tier.</p>
            )}
          </div>
        </Figure>

        <Figure
          title="Highest estimated Steam revenue"
          note="Estimated owners × price on the collection day. Rough: ignores discounts, refunds, regional prices and Steam's cut."
          table={{
            caption: "Steam revenue estimates",
            rows: data.steamRevenue,
            columns: [
              { key: "title", label: "Game" },
              { key: "low", label: "Low", num: true, format: usd },
              { key: "high", label: "High", num: true, format: usd },
              { key: "price", label: "Price", num: true, format: (v) => `$${v}` },
            ],
          }}
        >
          <RangeBars
            rows={data.steamRevenue.map((x) => ({ label: x.title, ...x }))}
            fmt={usd}
            tipFor={(r) => (
              <TipRows
                title={r.label}
                rows={[
                  { value: `${usd(r.low)} to ${usd(r.high)}`, label: "revenue" },
                  { value: `${compact(r.ownersLow)} to ${compact(r.ownersHigh)}`, label: "owners" },
                  { value: `$${r.price}`, label: "price" },
                ]}
              />
            )}
          />
        </Figure>
      </div>

      <Figure title="Published sales and revenue figures" note="Every figure found in press reports, publisher statements and trackers. Search or filter by confidence.">
        <DataTable
          caption="Published figures"
          rows={filteredFigures}
          searchable
          searchPlaceholder="Search game or source…"
          toolbar={<Chips label="Filter confidence" options={["All", "high", "medium", "low"]} value={confidence} onChange={setConfidence} size="sm" />}
          columns={[
            { key: "game", label: "Game" },
            { key: "metric", label: "Figure", format: (v) => METRIC[v] ?? v },
            { key: "value_low", label: "Amount", sortValue: (r) => r.value_low ?? -1, format: (_, r) => amount(r) },
            { key: "as_of", label: "As of", format: (v) => <span className="nowrap">{v}</span> },
            { key: "source_kind", label: "Source", format: (v, r) => <a href={r.source_url} target="_blank" rel="noreferrer">{v}</a> },
            { key: "confidence", label: "Confidence" },
          ]}
        />
      </Figure>
    </Section>
  );
}

function OverTime() {
  const [startYear, setStartYear] = useState(2008);
  // Four colour slots: a term keeps its slot (and colour) while pinned, so toggling others never repaints it.
  const [pins, setPins] = useState({ slots: ["Geometry Dash", "Helix Jump", "Red Ball 4", "Peggle"], order: ["Geometry Dash", "Helix Jump", "Red Ball 4", "Peggle"] });
  const pinnedTerms = pins.order;

  const a = data.adShareByYear.filter((x) => x.year >= Math.max(2013, startYear));
  const first = data.adShareByYear.slice(0, 3), last = a[a.length - 1] ?? data.adShareByYear[data.adShareByYear.length - 1];
  const kinds = ["Ball platformers", "Rolling ball", "Physics and bouncing", "Rhythm and hybrid", "Marble shooters"];
  const years = Array.from({ length: 2026 - startYear + 1 }, (_, i) => startYear + i);
  const releases = Object.fromEntries(kinds.map((k) => [k, Object.fromEntries(data.releases[k] ?? [])]));
  const relMax = Math.max(...kinds.flatMap((k) => years.map((y) => releases[k][y] ?? 0)), 1);

  const selectedTrends = useMemo(
    () =>
      pins.slots
        .map((term, slot) => {
          const tr = term && data.trends.find((t) => t.term === term);
          return tr ? { name: tr.term, color: SERIES_COLORS[slot], points: tr.years.filter(([y]) => y >= startYear) } : null;
        })
        .filter(Boolean),
    [pins, startYear]
  );

  function toggleTerm(term) {
    setPins(({ slots, order }) => {
      const at = slots.indexOf(term);
      if (at >= 0) {
        if (order.length <= 1) return { slots, order };
        return { slots: slots.map((t, k) => (k === at ? null : t)), order: order.filter((t) => t !== term) };
      }
      const free = slots.indexOf(null);
      const slot = free >= 0 ? free : slots.indexOf(order[0]);
      const kept = free >= 0 ? order : order.slice(1);
      return { slots: slots.map((t, k) => (k === slot ? term : t)), order: [...kept, term] };
    });
  }


  return (
    <Section
      id="time"
      title="Talk about ads and money went from 3% of review topics to about 15%."
      lead="Mobile ball games moved to free downloads paid for by ads around 2016, and reviews followed. Scrub the start year or click search terms below to compare up to 4 titles on one timeline."
    >
      <div className="timeline-bar">
        <label className="range-control">
          <span>Timeline starts: <strong>{startYear}</strong></span>
          <input type="range" min="2004" max="2020" step="1" value={startYear} onChange={(e) => setStartYear(Number(e.target.value))} />
        </label>
        <div className="chips">
          {[2004, 2008, 2013, 2016].map((yr) => (
            <button key={yr} className="chip sm" aria-pressed={startYear === yr} onClick={() => setStartYear(yr)}>{yr}–2026</button>
          ))}
        </div>
      </div>

      <div className="grid2">
        <Figure
          title="Share of review topics about ads or money, by year"
          note={`Of every topic mention in a year's reviews. Years before 2016 have few reviews (${full(first.reduce((s, x) => s + x.mentions, 0))} mentions in ${first[0].year}–${first[2].year}).`}
          table={{
            caption: "Ad and money share by year",
            rows: a,
            columns: [
              { key: "year", label: "Year" },
              { key: "share", label: "Share", num: true, format: (v) => pct(v, 1) },
              { key: "mentions", label: "All mentions", num: true, format: full },
            ],
          }}
        >
          <LineChart points={a.map((x) => [x.year, x.share])} yFmt={(v) => pct(v)} label={`Ad and money share of review topics rose to ${pct(last.share)} in ${last.year}`} />
        </Figure>

        <Figure
          title="Compare Google searches side-by-side"
          note="Yearly average Google Trends index (relative to Peggle's peak = 100). Select up to 4 titles below to compare."
        >
          <MultiLineChart series={selectedTrends} label="Comparison of Google Trends search interest across selected ball games" />
        </Figure>
      </div>

      <div className="grid2">
        <Figure
          title="Google searches, 2004–2026 (click any card to toggle above)"
          note="Each panel has its own scale; the figure is the peak month compared with Peggle's peak month."
          table={{
            caption: "Search interest peaks",
            rows: data.trends,
            columns: [
              { key: "term", label: "Search term" },
              { key: "peak", label: "Peak vs Peggle", num: true, format: (v) => `${(v / 100).toFixed(1)}×` },
              { key: "peakYear", label: "Peak year", num: true },
            ],
          }}
        >
          <div className="multiples">
            {data.trends.map((tr) => {
              const active = pinnedTerms.includes(tr.term);
              return (
                <button className={`multiple mult-btn${active ? " is-active" : ""}`} key={tr.term} onClick={() => toggleTerm(tr.term)} aria-pressed={active}
                  style={active ? { "--c": SERIES_COLORS[pins.slots.indexOf(tr.term)] } : undefined}>
                  <div className="mult-head">
                    <span>{tr.term}</span>
                    <span className="muted">{(tr.peak / 100).toFixed(1)}× in {tr.peakYear}</span>
                  </div>
                  <LineChart mini height={68} color={active ? SERIES_COLORS[pins.slots.indexOf(tr.term)] : "var(--ink-2)"} points={tr.years.filter(([y]) => y >= startYear)} yFmt={(v) => `${Math.round(v)}`} label={`${tr.term} searches by year`} />
                </button>
              );
            })}
          </div>
        </Figure>

        <Figure
          title="New ball games each year, by kind"
          note="Listings still in the stores today, by release year. Games that were removed are missing, so older years are undercounted."
          table={{
            caption: "Releases by year",
            rows: years.map((y) => ({ year: y, ...Object.fromEntries(kinds.map((k) => [k, releases[k][y] ?? 0])) })),
            columns: [{ key: "year", label: "Year" }, ...kinds.map((k) => ({ key: k, label: k, num: true }))],
          }}
        >
          <div className="multiples">
            {kinds.map((k) => (
              <div className="multiple" key={k}>
                <div className="mult-head"><span>{k}</span><span className="muted">{full(years.reduce((s, y) => s + (releases[k][y] ?? 0), 0))} games</span></div>
                <Columns
                  mini
                  height={64}
                  max={relMax}
                  rows={years.map((y) => ({ label: String(y), value: releases[k][y] ?? 0 }))}
                  tipFor={(r) => <TipRows title={`${k}, ${r.label}`} rows={[{ color: "var(--mag)", value: full(r.value), label: "new games" }]} />}
                />
              </div>
            ))}
          </div>
        </Figure>
      </div>
    </Section>
  );
}

const FEATURE = {
  control_type: (l) => (l === "unspecified" ? null : `Controls: ${l.replace("direct (keys/controller)", "keys or controller")}`),
  is_free: (l) => (l === "yes" ? "Free to download" : "Paid up front"),
  has_ads: (l) => (l === "yes" ? "Shows ads" : "No ads"),
  has_iap: (l) => (l === "yes" ? "Sells in-game items" : "Sells nothing in-game"),
  ball_game_category: (l) => RAW_CAT[l] ?? null,
};
const FLAG = {
  mentions_physics: "Mentions physics",
  mentions_bounce: "Mentions bouncing or jumping",
  mentions_roll: "Mentions rolling",
  has_level_editor: "Has a level editor",
  has_leaderboards: "Has leaderboards",
  has_multiplayer: "Has multiplayer",
  has_checkpoints: "Has checkpoints",
  has_skins: "Has ball skins",
  has_boss_fights: "Has boss fights",
  works_offline: "Works offline",
};

function Design() {
  const rows = data.design
    .map((d) => ({ ...d, label: FEATURE[d.feature] ? FEATURE[d.feature](d.level) : d.level === "yes" ? FLAG[d.feature] : null }))
    .filter((d) => d.label);
  const s = data.models.success;

  // Interactive Design Profile Explorer state
  const [genre, setGenre] = useState("A: Ball platformer");
  const [free, setFree] = useState("yes");
  const [ads, setAds] = useState("no");
  const [iap, setIap] = useState("no");
  const [flags, setFlags] = useState(["has_level_editor", "works_offline"]);

  const toggleFlag = (f) => setFlags((prev) => (prev.includes(f) ? prev.filter((x) => x !== f) : [...prev, f]));

  // Empirical weighted estimate across selected store traits from data.design
  const profileScore = useMemo(() => {
    const picks = [
      data.design.find((d) => d.feature === "ball_game_category" && d.level === genre),
      data.design.find((d) => d.feature === "is_free" && d.level === free),
      data.design.find((d) => d.feature === "has_ads" && d.level === ads),
      data.design.find((d) => d.feature === "has_iap" && d.level === iap),
      ...flags.map((f) => data.design.find((d) => d.feature === f && d.level === "yes")),
    ].filter(Boolean);
    if (!picks.length) return { rating: 50, pop: 50, picks };
    const rating = picks.reduce((sum, d) => sum + d.avg_rating_percentile, 0) / picks.length;
    const pop = picks.reduce((sum, d) => sum + d.avg_popularity_percentile, 0) / picks.length;
    return { rating, pop, picks };
  }, [genre, free, ads, iap, flags]);

  const chart = (key) => rows.map((r) => ({ label: r.label, value: r[key], listings: r.listings })).sort((a, b) => b.value - a.value);
  const tipFor = (r) => <TipRows title={r.label} rows={[{ value: Math.round(r.value), label: "average rank (50 is typical)" }, { value: full(r.listings), label: "listings" }]} />;
  const table = (key) => ({
    caption: "Design choices",
    rows: chart(key),
    columns: [
      { key: "label", label: "Feature" },
      { key: "value", label: "Average rank", num: true, format: (v) => v.toFixed(0) },
      { key: "listings", label: "Listings", num: true, format: full },
    ],
  });

  return (
    <Section
      id="design"
      title="What's on the store page barely predicts how well a game rates."
      lead={`A model given price, ads, controls, level count and listed features explained ${pct(Math.max(0, s.rating_percentile_in_store.r2))} of the differences in rating and ${pct(s.popularity_percentile_in_store.r2)} of the differences in popularity. Try combining traits in the simulator below to see how store features lean.`}
    >
      <div className="panel sim-card">
        <div className="sim-head">
          <div>
            <span className="panel-tag"><IconSliders size={13} /> Interactive Design Explorer</span>
            <h3>Mix store traits &amp; features</h3>
            <p className="muted">Blends the empirical store averages below across your selected traits (associations, not causal predictions).</p>
          </div>
          <div className="sim-gauges">
            <RadialGauge value={profileScore.rating} label="Rating rank" sublabel="50 = typical" color="var(--love)" size={102} />
            <RadialGauge value={profileScore.pop} label="Popularity rank" sublabel="50 = typical" color="var(--mag)" size={102} />
          </div>
        </div>

        <div className="sim-controls">
          <div className="sim-group">
            <span className="sim-lbl">Genre</span>
            <div className="chips">
              {Object.entries(RAW_CAT).map(([raw, label]) => (
                <button key={raw} className="chip sm" aria-pressed={genre === raw} onClick={() => setGenre(raw)}>{label}</button>
              ))}
            </div>
          </div>
          <div className="sim-group">
            <span className="sim-lbl">Business model</span>
            <div className="chips">
              <button className="chip sm" aria-pressed={free === "yes"} onClick={() => setFree("yes")}>Free</button>
              <button className="chip sm" aria-pressed={free === "no"} onClick={() => setFree("no")}>Paid</button>
              <button className="chip sm" aria-pressed={ads === "yes"} onClick={() => setAds(ads === "yes" ? "no" : "yes")}>Ads: {ads === "yes" ? "On" : "Off"}</button>
              <button className="chip sm" aria-pressed={iap === "yes"} onClick={() => setIap(iap === "yes" ? "no" : "yes")}>In-app items: {iap === "yes" ? "On" : "Off"}</button>
            </div>
          </div>
          <div className="sim-group">
            <span className="sim-lbl">Store page features</span>
            <div className="chips">
              {Object.entries(FLAG).map(([key, label]) => (
                <button key={key} className="chip sm" aria-pressed={flags.includes(key)} onClick={() => toggleFlag(key)}>{label}</button>
              ))}
              <button className="link-btn" onClick={() => setFlags([])}><IconReset size={12} /> Clear</button>
            </div>
          </div>
        </div>
      </div>

      <div className="grid2">
        <Figure title="Rating rank within its store" note="0 = lowest-rated listing in its store, 100 = highest, 50 = typical. Listings with at least 30 ratings." table={table("avg_rating_percentile")}>
          <DotList rows={chart("avg_rating_percentile")} domain={[0, 100]} tickVals={[0, 25, 50, 75, 100]} baseline={50} fmt={(v) => v.toFixed(0)} tipFor={tipFor} />
        </Figure>
        <Figure title="Popularity rank within its store" note="By ratings per year since release. Popular games show ads more often, which is why ads lean towards popularity." table={table("avg_popularity_percentile")}>
          <DotList rows={chart("avg_popularity_percentile")} domain={[0, 100]} tickVals={[0, 25, 50, 75, 100]} baseline={50} fmt={(v) => v.toFixed(0)} tipFor={tipFor} />
        </Figure>
      </div>
    </Section>
  );
}

const SENTIMENT_LABELS = ["Negative", "Neutral", "Positive"];

function Method() {
  const s = data.models.sentiment;
  const [stage, setStage] = useState("after");
  const snap = stage === "before" ? s.before_fine_tuning : s.after_fine_tuning;
  const matrix = snap.confusion_rows_true_cols_pred;

  return (
    <Section id="method" title="How this was made">
      <div className="method">
        <div>
          <h3>Data</h3>
          <p>
            Store listings from Google Play, the App Store and Steam; {full(data.meta.reviews)} reviews (newest English Google Play reviews, the App Store&apos;s
            latest reviews in 10 countries, and Steam reviews from 2010–2018 research datasets); App Store ratings in 30 countries; Google Trends; and
            the published sales figures above. Collected on 26 November 2026.
          </p>
        </div>
        <div>
          <h3>Models</h3>
          <p>
            A multilingual sentiment model (XLM-RoBERTa) was fine-tuned on {compact(s.train_texts)} reviews on the Plaksha HPC cluster. On {s.test_games} games it
            never saw in training, it agrees with the stars {pct(s.after_fine_tuning.accuracy)} of the time ({pct(s.before_fine_tuning.accuracy)} before training).
            Reviews were split into 1.38 million short phrases, grouped by meaning into 80 clusters, and named by hand as {data.meta.themes} topics plus 5 kinds of plain reaction.
          </p>
        </div>
        <div>
          <h3>Limits</h3>
          <ul>
            <li>Stars are noisy: {pct(data.starsVsText.lowStarsReadPositive)} of 1–2 star reviews read as positive.</li>
            <li>Most reviews are recent Google Play reviews, so mobile games and ad complaints weigh heavily.</li>
            <li>The topic grouping puts every phrase somewhere, so a few phrases land in the wrong topic.</li>
            <li>Revenue figures are estimates. Real budgets are not public.</li>
            <li>Countries and languages stand in for player demographics; no store publishes age or gender.</li>
          </ul>
        </div>
      </div>

      <div className="panel calibration-card">
        <div className="panel-head-inline">
          <div>
            <span className="panel-tag">Interactive Model Telemetry · {full(s.test_texts)} held-out reviews</span>
            <h3>Sentiment calibration: before vs after fine-tuning</h3>
            <p className="muted">Toggle between the base model and the fine-tuned model across {s.test_games} unseen games.</p>
          </div>
          <Chips label="Model stage" options={["Before fine-tuning", "After fine-tuning"]} value={stage === "before" ? "Before fine-tuning" : "After fine-tuning"} onChange={(v) => setStage(v.startsWith("Before") ? "before" : "after")} size="sm" />
        </div>

        <div className="cal-grid">
          <div className="cal-gauges">
            <RadialGauge value={snap.accuracy * 100} label="Accuracy" sublabel="vs store stars" color="var(--love)" size={108} formatValue={(v) => `${v.toFixed(1)}%`} />
            <RadialGauge value={snap.macro_f1 * 100} label="Macro F1" sublabel="class balance" color="var(--mag)" size={108} formatValue={(v) => (v / 100).toFixed(2)} />
          </div>
          <div className="cm-wrap">
            <table className="cm-table">
              <caption className="sr-only">Confusion matrix: rows are true star buckets, columns are model predictions</caption>
              <thead>
                <tr>
                  <th>True \ Pred</th>
                  {SENTIMENT_LABELS.map((l) => <th key={l} className="num">{l}</th>)}
                </tr>
              </thead>
              <tbody>
                {matrix.map((row, rIdx) => {
                  const rowSum = row.reduce((a, b) => a + b, 0) || 1;
                  return (
                    <tr key={SENTIMENT_LABELS[rIdx]}>
                      <th>{SENTIMENT_LABELS[rIdx]}</th>
                      {row.map((val, cIdx) => {
                        const share = val / rowSum;
                        const diag = rIdx === cIdx;
                        return (
                          <td key={cIdx} className={`num cm-cell${diag ? " is-diag" : ""}`} style={{ "--alpha": (0.08 + share * 0.42).toFixed(2) }}>
                            <strong>{full(val)}</strong>
                            <span className="cm-pct">{pct(share)}</span>
                          </td>
                        );
                      })}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Section>
  );
}
