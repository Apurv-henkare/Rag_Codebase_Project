import { useEffect, useRef, useState } from "react";
import data from "./data.json";
import { Hero } from "./Hero.jsx";
import { Bouncer } from "./Bouncer.jsx";
import { Chips, Columns, DataTable, DivergingBars, DotList, Figure, HBars, LineChart, RangeBars, SegBar, TipRows } from "./charts.jsx";
import { compact, full, pct, usd } from "./format.js";

const SECTIONS = [["top", "Overview"], ["topics", "Loved and hated"], ["games", "Games"], ["players", "Where players are"], ["money", "Money"],
  ["time", "Over time"], ["design", "Design choices"], ["method", "How this was made"]];
const ALL = "All ball games";
const CATS = ["Ball platformers", "Rolling ball", "Physics and bouncing", "Rhythm and hybrid", "Marble shooters", "Boulder action", "Not classified"];
const RAW_CAT = { "A: Ball platformer": "Ball platformers", "B: Rolling ball": "Rolling ball", "C: Ball physics & bouncing": "Physics and bouncing",
  "D: Hybrid / rhythm & transform": "Rhythm and hybrid", "Adjacent: marble shooter": "Marble shooters", "Adjacent: boulder action": "Boulder action" };
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
const sharePos = (r) => r.pos / (r.pos + r.neg + r.neu);

const IDS = SECTIONS.map(([id]) => id);
const fromHash = () => (IDS.includes(location.hash.slice(1)) ? location.hash.slice(1) : "top");

// One section is on screen at a time. The address bar keeps the section (#games), so the back button and shared links work.
export default function App() {
  const [active, setActive] = useState(fromHash);
  const [visited, setVisited] = useState(() => new Set([fromHash()]));
  const main = useRef(null);
  const shown = useRef(active);
  useEffect(() => {
    const on = () => setActive(fromHash());
    window.addEventListener("hashchange", on);
    return () => window.removeEventListener("hashchange", on);
  }, []);
  useEffect(() => {
    setVisited((v) => (v.has(active) ? v : new Set(v).add(active)));
    if (shown.current === active) return;
    shown.current = active;
    window.scrollTo(0, 0);
    main.current?.querySelector("h1, h2")?.focus({ preventScroll: true });
  }, [active]);
  const View = VIEWS[active];
  return (
    <div className="app">
      <a className="skip" href="#main" onClick={(e) => { e.preventDefault(); main.current?.querySelector("h1, h2")?.focus(); }}>Skip to the section</a>
      <Nav active={active} visited={visited} />
      <main ref={main} id="main">
        <View />
        <footer className="foot">
          Built from public store listings and reviews collected on 26 November 2026. Review quotes are short phrases from public reviews, shown in lower case
          and filtered for profanity and personal details.
        </footer>
      </main>
    </div>
  );
}

function Overview() {
  const top = (name) => data.themes.find((t) => t.theme === name);
  const fun = top("Fun to play"), ads = top("Too many ads"), levels = top("Wants more levels");
  return (
    <>
        <Hero findings={[
          { title: "Fun is the top praise", text: `${compact(fun.mentions)} reviews call the game fun; ${pct(sharePos(fun))} of those mentions are positive.` },
          { title: "Ads are the top complaint", text: `${compact(ads.mentions)} reviews say there are too many ads; ${pct(ads.neg / ads.mentions)} of those mentions are negative.` },
          { title: "Players want more levels", text: `${compact(levels.mentions)} reviews ask for more levels, and ${pct(sharePos(levels))} of them still like the game.` },
        ]}>
          <h1 tabIndex={-1}>What players love and hate about ball games</h1>
          <p className="lead">
            Nokia's <em>Bounce</em> put a red rubber ball on millions of phones in 2001. Thousands of ball games have followed: platformers,
            rolling-ball races, brick breakers and rhythm hops. This dashboard reads {full(data.meta.reviews)} store reviews of{" "}
            {full(data.meta.games)} of them to show what keeps people playing, what drives them away, and where they play.
          </p>
        </Hero>
        <div className="wrap"><Pager id="top" /></div>
    </>
  );
}

// Sidebar: the red ball drops onto the section on screen; sections already opened keep a ring.
function Nav({ active, visited }) {
  const seen = IDS.filter((id) => visited.has(id)).length;
  // on phones the menu is a sideways strip: keep the open section in view
  useEffect(() => { document.querySelector(".side [aria-current]")?.scrollIntoView({ block: "nearest", inline: "nearest" }); }, [active]);
  return (
    <aside className="side">
      <a className="brand" href="#top"><span className="brand-ball" aria-hidden="true" />Ball game reviews</a>
      <nav aria-label="Sections">
        <ol>
          {SECTIONS.map(([id, label], i) => {
            const here = active === id, been = visited.has(id);
            return (
              <li key={id}>
                <a href={`#${id}`} aria-current={here ? "page" : undefined} className={been ? "been" : undefined}>
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

// Back and next links at the foot of each section
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

function Topics() {
  const [cat, setCat] = useState(ALL);
  const [sel, setSel] = useState("Too many ads");
  const base = cat === ALL ? data.themes : data.themeByCategory[cat];
  const rows = base.filter((t) => isSpecific(t.theme))
    .map((t) => ({ label: t.theme, pos: t.pos, neg: t.neg, neu: t.neu, mentions: t.mentions }))
    .sort((a, b) => (b.pos - b.neg) / b.mentions - (a.pos - a.neg) / a.mentions);
  const s = rows.find((r) => r.label === sel) ?? rows[0];
  const info = themeInfo[s.label];
  const general = base.filter((t) => !isSpecific(t.theme)).reduce((n, t) => n + t.mentions, 0);
  return (
    <Section id="topics" title="Fun keeps people playing. Ads make them quit."
      lead={`A model read every review and sorted what people wrote into ${data.meta.themes} topics. Praise gathers around fun, calm and clever design; complaints gather around ads, crashes and difficulty. Pick a topic to read what players actually said.`}>
      <Chips label="Kind of ball game" options={[ALL, ...CATS]} value={cat} onChange={setCat} />
      <div className="split">
        <Figure title={`What reviews praise and complain about${cat === ALL ? "" : `: ${cat.toLowerCase()}`}`}
          note={`Each bar splits one topic's mentions into praise, neutral and complaints; the number beside the topic is how many reviews mention it. ${full(general)} plain “good game” or “bad game” comments are left out.`}
          table={{ caption: "Topic mentions", rows, columns: [
            { key: "label", label: "Topic" }, { key: "pos", label: "Praise", num: true, format: full },
            { key: "neu", label: "Neutral", num: true, format: full }, { key: "neg", label: "Complaints", num: true, format: full },
            { key: "share", label: "Positive", num: true, format: (_, r) => pct(sharePos(r)) }] }}>
          <DivergingBars rows={rows} selected={s.label} onSelect={setSel} />
        </Figure>
        <aside className="panel sticky" aria-live="polite">
          <h3>{s.label}</h3>
          <p className="muted">{info.group}. {full(s.mentions)} mentions{cat === ALL ? "" : ` in ${cat.toLowerCase()}`}: {pct(sharePos(s))} positive, {pct(s.neg / s.mentions)} negative.</p>
          <SegBar parts={[{ label: "Praise", value: s.pos, cls: "love" }, { label: "Neutral", value: s.neu, cls: "neu" }, { label: "Complaints", value: s.neg, cls: "hate" }]} />
          <h4><i className="key love" />What players praise</h4>
          <Quotes items={info.praise} tone="love" />
          <h4><i className="key hate" />What players complain about</h4>
          <Quotes items={info.complaints} tone="hate" />
          <p className="fine">Quotes are drawn from all ball games.</p>
        </aside>
      </div>
      <h3 className="sub">What each kind of ball game is known for</h3>
      <p className="sub-lead">Topics that come up far more often for one kind of game than for ball games overall.</p>
      <div className="kinds">
        {CATS.filter((c) => CAT_ABOUT[c]).map((c) => {
          const meta = data.categories.find((x) => x.label === c);
          return (
            <div className="kind" key={c}>
              <h4>{c}</h4>
              <p className="muted">{CAT_ABOUT[c]}. {full(meta.listings)} store listings, {compact(meta.mentions)} topic mentions.</p>
              <ul>
                {data.categoryLift[c].map((l) => (
                  <li key={l.theme}><span>{l.theme}</span><span className="fig-num">{l.lift.toFixed(1)}× as often</span></li>
                ))}
              </ul>
            </div>
          );
        })}
      </div>
    </Section>
  );
}

function Games() {
  const [cat, setCat] = useState(ALL);
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState("Most reviewed");
  const [showAll, setShowAll] = useState(false);
  const [sel, setSel] = useState(() => (data.games.find((g) => g.title === "Bounce Classic") ?? data.games[0]).id);
  const list = data.games
    .filter((g) => (cat === ALL || g.category === cat) && g.title.toLowerCase().includes(query.trim().toLowerCase()))
    .sort((a, b) => (sort === "Most positive" ? b.textPos - a.textPos : b.reviews - a.reviews));
  const shown = showAll ? list : list.slice(0, 15);
  const g = data.games.find((x) => x.id === sel);
  const themes = data.gameThemes[g.id] ?? [];
  const steam = g.platform.startsWith("Steam");
  return (
    <Section id="games" title="The Nokia classic still wins players over. Some of the biggest hits split them."
      lead={`How positive each game's reviews read, for the ${data.games.length} games with at least 200 reviews. Pick a game to see what its players single out.`}>
      <div className="filters">
        <Chips label="Kind of ball game" options={[ALL, ...CATS]} value={cat} onChange={setCat} />
        <div className="filter-line">
          <label className="search"><span className="sr-only">Find a game</span>
            <input type="search" placeholder="Find a game" value={query} onChange={(e) => setQuery(e.target.value)} />
          </label>
          <Chips label="Sort games" options={["Most reviewed", "Most positive"]} value={sort} onChange={setSort} />
        </div>
      </div>
      <div className="split">
        <Figure title="Share of reviews that read positive" note="Read from the review text by the sentiment model, not from the stars."
          table={{ caption: "Games", rows: list, columns: [
            { key: "title", label: "Game" }, { key: "platform", label: "Store", format: (v) => SHORT_STORE[v] },
            { key: "category", label: "Kind" }, { key: "reviews", label: "Reviews", num: true, format: full },
            { key: "textPos", label: "Positive (text)", num: true, format: (v) => pct(v) }, { key: "starPos", label: "Positive (stars)", num: true, format: (v) => pct(v) }] }}>
          {list.length === 0 ? <p className="muted">No game matches “{query}”. Clear the search or pick another kind of game.</p> : (
            <>
              <ul className="meter-list">
                {shown.map((x) => (
                  <li key={x.id}>
                    <button aria-pressed={x.id === sel} onClick={() => setSel(x.id)} aria-label={`${x.title}, ${SHORT_STORE[x.platform]}: ${pct(x.textPos)} positive`}>
                      <span className="ml-name">{x.title}<span className="ml-store">{SHORT_STORE[x.platform]}</span></span>
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
          <h3>{g.title}</h3>
          <dl className="facts">
            <div><dt>Store</dt><dd>{SHORT_STORE[g.platform]}</dd></div>
            <div><dt>Kind</dt><dd>{g.category}</dd></div>
            {g.developer && <div><dt>Developer</dt><dd>{g.developer}</dd></div>}
            {g.year && <div><dt>Released</dt><dd>{g.year}</dd></div>}
            {g.installs != null && <div><dt>{steam ? "Owners (estimate)" : "Installs"}</dt><dd>{compact(g.installs)}+</dd></div>}
            {g.score != null && <div><dt>Store rating</dt><dd>{steam ? `${g.score}% recommend` : `${(g.score / 20).toFixed(1)} of 5 stars`}</dd></div>}
            <div><dt>Reviews read</dt><dd>{full(g.reviews)}</dd></div>
          </dl>
          <SegBar parts={[{ label: "Positive", value: g.textPos, cls: "love" }, { label: "Neutral", value: Math.max(0, 1 - g.textPos - g.textNeg), cls: "neu" },
            { label: "Negative", value: g.textNeg, cls: "hate" }]} />
          <p className="muted">
            The text reads {pct(g.textPos)} positive and {pct(g.textNeg)} negative. The stars say {pct(g.starPos)} positive.
            {g.praised && <> Praised most for <strong>{g.praised.toLowerCase()}</strong>.</>}
            {g.criticised && <> Criticised most for <strong>{g.criticised.toLowerCase()}</strong>.</>}
          </p>
          <h4>Talked about more than in other {g.category.toLowerCase()} games</h4>
          {themes.length ? (
            <HBars rows={themes.map((t) => ({ label: t.theme, value: t.lift, ...t }))} fmt={(v) => `${v.toFixed(1)}×`}
              tipFor={(r) => <TipRows title={r.label} rows={[{ value: `${r.lift.toFixed(1)}×`, label: "as often as usual" },
                { value: full(r.mentions), label: "mentions" }, { color: "var(--love)", value: pct(r.pos), label: "positive" }]} />} />
          ) : <p className="muted">Too few reviews to compare topics for this game.</p>}
          {g.url && <p><a href={g.url} target="_blank" rel="noreferrer">Open the store page</a></p>}
        </aside>
      </div>
    </Section>
  );
}

function Players() {
  const c = data.countries;
  const hiC = c.slice(0, 3).map((x) => x.name), loC = c.slice(-2).map((x) => x.name);
  const lang = data.languages;
  return (
    <Section id="players" title={`${hiC[0]}, ${hiC[1]} and ${hiC[2]} rate ball games highest.`}
      lead={`No store publishes the age or gender of a game's players, so country and language are the closest public signals. ${loC[0]} and ${loC[1]} give the lowest ratings.`}>
      <div className="grid2">
        <Figure title="Average App Store rating, by country" note="Across 521 iOS ball games, weighted by how many ratings each game has. 5 is the best score."
          table={{ caption: "Country ratings", rows: c, columns: [{ key: "name", label: "Country" },
            { key: "avg", label: "Average rating", num: true, format: (v) => v.toFixed(2) }, { key: "ratings", label: "Ratings", num: true, format: full }] }}>
          <DotList rows={c.map((x) => ({ label: x.name, value: x.avg, ratings: x.ratings }))} domain={[4.2, 4.7]} tickVals={[4.2, 4.3, 4.4, 4.5, 4.6, 4.7]}
            fmt={(v) => v.toFixed(2)} tipFor={(r) => <TipRows title={r.label} rows={[{ value: r.value.toFixed(2), label: "average stars" }, { value: compact(r.ratings), label: "ratings" }]} />} />
        </Figure>
        <div className="stack">
          <Figure title="New Google Play reviews per day, by language" note={`Last 30 days, ${data.languageGames} most-rated Google Play ball games. Hindi looks small because most Indian players review in English.`}
            table={{ caption: "Reviews per day by language", rows: lang, columns: [{ key: "name", label: "Language" }, { key: "perDay", label: "Reviews per day", num: true, format: full }] }}>
            <HBars rows={lang.map((l) => ({ label: l.name, value: l.perDay }))} fmt={(v) => full(v)}
              tipFor={(r) => <TipRows title={r.label} rows={[{ color: "var(--mag)", value: full(r.value), label: "reviews a day" }]} />} />
          </Figure>
          <Figure title="What each country's players complain about and praise" note="App Store reviews from 10 country stores, read in their own language. Share means the share of that country's complaints or praise.">
            <DataTable caption="Top topics by country" rows={data.countryThemes} columns={[
              { key: "name", label: "Country" },
              { key: "topComplaint", label: "Top complaint", format: (v, r) => <>{v} <span className="muted">{pct(r.complaintShare)}</span></> },
              { key: "topPraise", label: "Top praise", format: (v, r) => <>{v} <span className="muted">{pct(r.praiseShare)}</span></> }]} />
          </Figure>
        </div>
      </div>
    </Section>
  );
}

const METRIC = {
  units_sold: "Copies sold", downloads: "Downloads", units_sold_steam: "Copies sold on Steam", gross_revenue_steam: "Steam revenue before the store's cut",
  gross_revenue_mobile: "Mobile in-app revenue", arcade_units_sold: "Arcade cabinets sold", arcade_units_produced: "Arcade cabinets built",
  development_time: "Time to make", installs_android: "Android installs", monthly_revenue_android: "Android revenue a month", distribution: "How it reached players",
};

function amount(f) {
  if (f.value_low == null) return f.note;
  const v = (n) => (f.unit?.startsWith("USD") ? usd(n) : f.unit === "months" ? `${n} months` : compact(n));
  return f.value_high && f.value_high !== f.value_low ? `${v(f.value_low)} to ${v(f.value_high)}` : v(f.value_low);
}

function Money() {
  const b = data.installBuckets;
  const big = b[b.length - 1];
  const m = data.monetisation;
  return (
    <Section id="money" title={`Ten games take ${pct(data.installTop10.share)} of all installs.`}
      lead="Most ball games are free and earn from ads. No studio publishes what a ball game cost to make, so this section shows what is known: install counts, revenue estimates and the few sales figures that have been published.">
      <div className="kpis">
        <div className="kpi"><span className="kpi-label">Google Play ball games that show ads</span><span className="kpi-value">{pct(m.ads)}</span></div>
        <div className="kpi"><span className="kpi-label">Sell items inside the game</span><span className="kpi-value">{pct(m.iap)}</span></div>
        <div className="kpi"><span className="kpi-label">Cost money to download</span><span className="kpi-value">{pct(m.paid, 1)}</span></div>
        <div className="kpi"><span className="kpi-label">Installs of these games, in total</span><span className="kpi-value">{compact(data.installTop10.total)}</span></div>
      </div>
      <div className="grid2">
        <Figure title="Google Play ball games, by number of installs"
          note={`${full(data.installTop10.games)} games, ${compact(data.installTop10.total)} installs in total. The ${big.games} games past 100 million installs hold ${pct(big.installShare)} of them.`}
          table={{ caption: "Install buckets", rows: b, columns: [{ key: "label", label: "Installs" }, { key: "games", label: "Games", num: true, format: full },
            { key: "installShare", label: "Share of all installs", num: true, format: (v) => pct(v, 1) }] }}>
          <Columns rows={b.map((x) => ({ label: x.label, value: x.games, share: x.installShare }))} height={200}
            tipFor={(r) => <TipRows title={`${r.label} installs`} rows={[{ color: "var(--mag)", value: full(r.value), label: "games" }, { value: pct(r.share, 1), label: "of all installs" }]} />} />
        </Figure>
        <Figure title="Highest estimated Steam revenue" note="Estimated owners × price on the collection day. Rough: ignores discounts, refunds, regional prices and Steam's cut."
          table={{ caption: "Steam revenue estimates", rows: data.steamRevenue, columns: [{ key: "title", label: "Game" },
            { key: "low", label: "Low", num: true, format: usd }, { key: "high", label: "High", num: true, format: usd }, { key: "price", label: "Price", num: true, format: (v) => `$${v}` }] }}>
          <RangeBars rows={data.steamRevenue.map((x) => ({ label: x.title, ...x }))} fmt={usd}
            tipFor={(r) => <TipRows title={r.label} rows={[{ value: `${usd(r.low)} to ${usd(r.high)}`, label: "revenue" }, { value: `${compact(r.ownersLow)} to ${compact(r.ownersHigh)}`, label: "owners" }, { value: `$${r.price}`, label: "price" }]} />} />
        </Figure>
      </div>
      <Figure title="Published sales and revenue figures" note="Every figure found in press reports, publisher statements and trackers. Estimates are marked low confidence.">
        <DataTable caption="Published figures" rows={data.figures} columns={[
          { key: "game", label: "Game" }, { key: "metric", label: "Figure", format: (v) => METRIC[v] ?? v },
          { key: "value_low", label: "Amount", format: (_, r) => amount(r) }, { key: "as_of", label: "As of", format: (v) => <span className="nowrap">{v}</span> },
          { key: "source_kind", label: "Source", format: (v, r) => <a href={r.source_url} target="_blank" rel="noreferrer">{v}</a> },
          { key: "confidence", label: "Confidence" }]} />
      </Figure>
    </Section>
  );
}

function OverTime() {
  const a = data.adShareByYear;
  const first = a.slice(0, 3), last = a[a.length - 1];
  const kinds = ["Ball platformers", "Rolling ball", "Physics and bouncing", "Rhythm and hybrid", "Marble shooters"];
  const years = Array.from({ length: 19 }, (_, i) => 2008 + i);
  const releases = Object.fromEntries(kinds.map((k) => [k, Object.fromEntries(data.releases[k] ?? [])]));
  const relMax = Math.max(...kinds.flatMap((k) => years.map((y) => releases[k][y] ?? 0)));
  return (
    <Section id="time" title="Talk about ads and money went from 3% of review topics to about 15%."
      lead="Mobile ball games moved to free downloads paid for by ads around 2016, and reviews followed. Search interest shows which games people went looking for.">
      <Figure title="Share of review topics about ads or money, by year"
        note={`Of every topic mention in a year's reviews. Years before 2016 have few reviews in this data (${full(first.reduce((s, x) => s + x.mentions, 0))} mentions in ${first[0].year} to ${first[2].year}).`}
        table={{ caption: "Ad and money share by year", rows: a, columns: [{ key: "year", label: "Year" }, { key: "share", label: "Share", num: true, format: (v) => pct(v, 1) },
          { key: "mentions", label: "All mentions", num: true, format: full }] }}>
        <LineChart points={a.map((x) => [x.year, x.share])} yFmt={(v) => pct(v)} label={`Ad and money share of review topics rose to ${pct(last.share)} in ${last.year}`} />
      </Figure>
      <div className="grid2">
        <Figure title="Google searches, 2004–2026" note="Yearly average of Google Trends interest. Each panel has its own scale; the figure is the peak month compared with Peggle's peak month."
          table={{ caption: "Search interest peaks", rows: data.trends, columns: [{ key: "term", label: "Search term" },
            { key: "peak", label: "Peak vs Peggle", num: true, format: (v) => `${(v / 100).toFixed(1)}×` }, { key: "peakYear", label: "Peak year", num: true }] }}>
          <div className="multiples">
            {data.trends.map((tr) => (
              <div className="multiple" key={tr.term}>
                <div className="mult-head"><span>{tr.term}</span><span className="muted">{(tr.peak / 100).toFixed(1)}× in {tr.peakYear}</span></div>
                <LineChart mini height={72} points={tr.years} yFmt={(v) => `${Math.round(v)}`} label={`${tr.term} searches by year`} />
              </div>
            ))}
          </div>
        </Figure>
        <Figure title="New ball games each year, by kind" note="Listings still in the stores today, by release year. Games that were removed are missing, so older years are undercounted."
          table={{ caption: "Releases by year", rows: years.map((y) => ({ year: y, ...Object.fromEntries(kinds.map((k) => [k, releases[k][y] ?? 0])) })),
            columns: [{ key: "year", label: "Year" }, ...kinds.map((k) => ({ key: k, label: k, num: true }))] }}>
          <div className="multiples">
            {kinds.map((k) => (
              <div className="multiple" key={k}>
                <div className="mult-head"><span>{k}</span><span className="muted">{full(years.reduce((s, y) => s + (releases[k][y] ?? 0), 0))} games</span></div>
                <Columns mini height={64} max={relMax} rows={years.map((y) => ({ label: String(y), value: releases[k][y] ?? 0 }))}
                  tipFor={(r) => <TipRows title={`${k}, ${r.label}`} rows={[{ color: "var(--mag)", value: full(r.value), label: "new games" }]} />} />
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
  is_free: (l) => (l === "yes" ? "Free to download" : "Paid up front"), has_ads: (l) => (l === "yes" ? "Shows ads" : "No ads"),
  has_iap: (l) => (l === "yes" ? "Sells in-game items" : "Sells nothing in-game"),
  ball_game_category: (l) => RAW_CAT[l] ?? null,
};
const FLAG = { mentions_physics: "Mentions physics", mentions_bounce: "Mentions bouncing or jumping", mentions_roll: "Mentions rolling",
  has_level_editor: "Has a level editor", has_leaderboards: "Has leaderboards", has_multiplayer: "Has multiplayer", has_checkpoints: "Has checkpoints",
  has_skins: "Has ball skins", has_boss_fights: "Has boss fights", works_offline: "Works offline" };

function Design() {
  const rows = data.design.map((d) => ({ ...d, label: FEATURE[d.feature] ? FEATURE[d.feature](d.level) : d.level === "yes" ? FLAG[d.feature] : null }))
    .filter((d) => d.label);
  const s = data.models.success;
  const chart = (key) => rows.map((r) => ({ label: r.label, value: r[key], listings: r.listings })).sort((a, b) => b.value - a.value);
  const tipFor = (r) => <TipRows title={r.label} rows={[{ value: Math.round(r.value), label: "average rank (50 is typical)" }, { value: full(r.listings), label: "listings" }]} />;
  const table = (key) => ({ caption: "Design choices", rows: chart(key), columns: [{ key: "label", label: "Feature" }, { key: "value", label: "Average rank", num: true, format: (v) => v.toFixed(0) }, { key: "listings", label: "Listings", num: true, format: full }] });
  return (
    <Section id="design" title="What's on the store page barely predicts how well a game rates."
      lead={`A model given price, ads, controls, level count and listed features explained ${pct(Math.max(0, s.rating_percentile_in_store.r2))} of the differences in rating and ${pct(s.popularity_percentile_in_store.r2)} of the differences in popularity. The averages below show which way each feature leans, not what causes success.`}>
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

function Method() {
  const s = data.models.sentiment;
  return (
    <Section id="method" title="How this was made">
      <div className="method">
        <div>
          <h3>Data</h3>
          <p>Store listings from Google Play, the App Store and Steam; {full(data.meta.reviews)} reviews (newest English Google Play reviews, the App Store's
            latest reviews in 10 countries, and Steam reviews from 2010–2018 research datasets); App Store ratings in 30 countries; Google Trends; and
            the published sales figures above. Collected on 26 November 2026.</p>
        </div>
        <div>
          <h3>Models</h3>
          <p>A multilingual sentiment model (XLM-RoBERTa) was fine-tuned on {compact(s.train_texts)} reviews on the Plaksha HPC cluster. On {s.test_games} games it
            never saw in training, it agrees with the stars {pct(s.after_fine_tuning.accuracy)} of the time ({pct(s.before_fine_tuning.accuracy)} before training).
            Reviews were split into 1.38 million short phrases, grouped by meaning into 80 clusters, and named by hand as {data.meta.themes} topics plus 5 kinds of plain reaction.</p>
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
    </Section>
  );
}

const VIEWS = { top: Overview, topics: Topics, games: Games, players: Players, money: Money, time: OverTime, design: Design, method: Method };
