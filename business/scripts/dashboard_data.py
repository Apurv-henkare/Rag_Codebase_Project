"""Pack the processed data and model outputs into one JSON file for the React dashboard.

In:  data/processed/*.csv, data/model_outputs/**
Out: dashboard/src/data.json
"""
import json, re
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
P, M = ROOT / "data/processed", ROOT / "data/model_outputs"
D = M / "dashboard"
CAT = {"A: Ball platformer": "Ball platformers", "B: Rolling ball": "Rolling ball", "C: Ball physics & bouncing": "Physics and bouncing",
       "D: Hybrid / rhythm & transform": "Rhythm and hybrid", "Adjacent: marble shooter": "Marble shooters",
       "Adjacent: boulder action": "Boulder action", "Unclassified": "Not classified"}
COUNTRY = {"us": "United States", "gb": "United Kingdom", "ca": "Canada", "au": "Australia", "de": "Germany", "fr": "France", "jp": "Japan",
           "br": "Brazil", "in": "India", "ru": "Russia", "mx": "Mexico", "id": "Indonesia", "th": "Thailand", "my": "Malaysia",
           "vn": "Vietnam", "sg": "Singapore", "ng": "Nigeria", "za": "South Africa", "ph": "Philippines", "tw": "Taiwan",
           "nl": "Netherlands", "es": "Spain", "ae": "United Arab Emirates", "cn": "China", "se": "Sweden", "pl": "Poland",
           "it": "Italy", "tr": "Turkey", "kr": "South Korea", "sa": "Saudi Arabia"}
LANG = {"en": "English", "es": "Spanish", "pt": "Portuguese", "hi": "Hindi", "id": "Indonesian", "ru": "Russian", "tr": "Turkish",
        "fr": "French", "de": "German", "ar": "Arabic", "vi": "Vietnamese", "ja": "Japanese", "ko": "Korean", "th": "Thai"}
SAFE = re.compile(r"@|https?:|www\.|\d{6,}|\+")  # quotes shown publicly: no emails, links, long numbers or "+pro -con" lists


def r(x, n=3):
    return None if pd.isna(x) else round(float(x), n)


def quotes(s):
    return [q for q in str(s).split(" | ") if q and q != "nan" and not SAFE.search(q)][:5]


games = pd.read_csv(P / "games.csv", dtype={"store_id": str})
reviews_n = len(pd.read_csv(M / "review_sentiment.csv.gz", usecols=["row"]))  # one row per review in reviews.csv
out = {}

# ---- themes ----
t = pd.read_csv(D / "themes.csv")
out["themes"] = [{"theme": x.theme, "group": x.theme_group, "mentions": int(x.mentions), "pos": int(x.positive), "neg": int(x.negative),
                  "neu": int(x.neutral), "praise": quotes(x.praise_quotes), "complaints": quotes(x.complaint_quotes)} for x in t.itertuples()]
tc = pd.read_csv(D / "theme_by_category.csv")
out["themeByCategory"] = {CAT[k]: [{"theme": x.theme, "mentions": int(x.mentions), "pos": int(x.positive), "neg": int(x.negative),
                                     "neu": int(x.neutral)} for x in d.itertuples()] for k, d in tc.groupby("ball_game_category")}
spec = t[t.theme_group != "General reaction"].set_index("theme").mentions
spec = spec / spec.sum()
cs = tc[tc.theme_group != "General reaction"].copy()
cs["share"] = cs.mentions / cs.groupby("ball_game_category").mentions.transform("sum")
cs["lift"] = cs.share / cs.theme.map(spec)
out["categoryLift"] = {CAT[k]: [{"theme": x.theme, "lift": r(x.lift, 1), "mentions": int(x.mentions)}
                                for x in d[d.mentions >= 200].nlargest(4, "lift").itertuples()] for k, d in cs.groupby("ball_game_category")}
out["categories"] = [{"label": CAT[k], "listings": int((games.ball_game_category == k).sum()),
                      "mentions": int(tc[tc.ball_game_category == k].mentions.sum())} for k in CAT]

# ---- games ----
gs = pd.read_csv(D / "game_sentiment.csv", dtype={"store_id": str})
gs = gs[gs.reviews >= 200].merge(games[["platform", "store_id", "developer", "release_year", "installs_low", "installs_high", "rating_count",
                                        "stars_5", "rating_score_100", "price_usd", "url"]], on=["platform", "store_id"], how="left")
gs["id"] = gs.platform.str.split(" ").str[0].str.lower().str.replace("app", "ios") + ":" + gs.store_id
out["games"] = [{"id": x.id, "platform": x.platform, "title": x.title, "category": CAT[x.ball_game_category], "reviews": int(x.reviews),
                 "starPos": r(x.star_positive_share), "textPos": r(x.model_positive_share), "textNeg": r(x.model_negative_share),
                 "praised": None if pd.isna(x.most_praised_theme) else x.most_praised_theme,
                 "criticised": None if pd.isna(x.most_criticised_theme) else x.most_criticised_theme,
                 "developer": None if pd.isna(x.developer) else x.developer, "year": None if pd.isna(x.release_year) else int(x.release_year),
                 "installs": None if pd.isna(x.installs_low) else int(x.installs_low), "ratingCount": None if pd.isna(x.rating_count) else int(x.rating_count),
                 "score": r(x.rating_score_100, 1), "price": r(x.price_usd, 2), "url": x.url} for x in gs.itertuples()]
tg = pd.read_csv(D / "theme_by_game.csv", dtype={"store_id": str})
tg = tg[(tg.theme_group != "General reaction") & (tg.mentions >= 20)]
tg["id"] = tg.platform.str.split(" ").str[0].str.lower().str.replace("app", "ios") + ":" + tg.store_id
out["gameThemes"] = {k: [{"theme": x.theme, "lift": r(x.lift_vs_category, 1), "mentions": int(x.mentions), "pos": r(x.share_positive),
                          "neg": r(x.share_negative)} for x in d[d.lift_vs_category >= 1.2].nlargest(5, "lift_vs_category").itertuples()]  # 1.2x or more = clearly above usual
                     for k, d in tg[tg.id.isin(gs.id)].groupby("id")}

# ---- where players are ----
cr = pd.read_csv(P / "country_ratings.csv")
w = cr.assign(wsum=cr.avg_rating * cr.rating_count).groupby("country")[["wsum", "rating_count"]].sum()
out["countries"] = sorted([{"code": c, "name": COUNTRY[c], "ratings": int(x.rating_count), "avg": r(x.wsum / x.rating_count, 2)}
                           for c, x in w.iterrows()], key=lambda d: -d["avg"])
tco = pd.read_csv(D / "theme_by_country.csv")
tco = tco[tco.theme_group != "General reaction"]
ct = []
for c, d in tco.groupby("country"):
    comp = d.assign(k=d.negative).nlargest(1, "k").iloc[0]
    love = d.assign(k=d.positive).nlargest(1, "k").iloc[0]
    ct.append({"code": c, "name": COUNTRY[c], "mentions": int(d.mentions.sum()), "topComplaint": comp.theme,
               "complaintShare": r(comp.negative / d.negative.sum()), "topPraise": love.theme, "praiseShare": r(love.positive / d.positive.sum())})
out["countryThemes"] = sorted(ct, key=lambda d: -d["mentions"])
la = pd.read_csv(P / "play_language_activity.csv").groupby("lang").reviews_per_day.sum()
out["languages"] = [{"code": k, "name": LANG[k], "perDay": r(v, 1)} for k, v in la.sort_values(ascending=False).items()]
out["languageGames"] = int(pd.read_csv(P / "play_language_activity.csv").store_id.nunique())

# ---- money ----
play = games[games.platform == "Google Play (Android)"].copy()
inst = play.installs_low.dropna()
edges = [0, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, np.inf]
labels = ["Under 1K", "1K–10K", "10K–100K", "100K–1M", "1M–10M", "10M–100M", "100M+"]
b = pd.cut(inst, edges, labels=labels, right=False)
out["installBuckets"] = [{"label": l, "games": int((b == l).sum()), "installShare": r(inst[b == l].sum() / inst.sum())} for l in labels]
top10 = play.nlargest(10, "installs_low")
out["installTop10"] = {"share": r(top10.installs_low.sum() / inst.sum()), "games": int(len(inst)), "total": int(inst.sum()),
                       "titles": top10.title.tolist()}
out["monetisation"] = {"games": int(len(play)), "ads": r(play.has_ads.mean()), "iap": r(play.has_iap.mean()), "paid": r((~play.is_free.astype(bool)).mean())}
st = games[(games.platform == "Steam (PC)") & games.est_revenue_high_usd.gt(0)].nlargest(10, "est_revenue_high_usd")
out["steamRevenue"] = [{"title": x.title, "low": int(x.est_revenue_low_usd), "high": int(x.est_revenue_high_usd), "price": r(x.price_usd, 2),
                        "ownersLow": int(x.installs_low), "ownersHigh": int(x.installs_high)} for x in st.itertuples()]
f = pd.read_csv(P / "published_figures.csv")
out["figures"] = [{k: (None if pd.isna(v) else v) for k, v in row.items()} for row in f.to_dict("records")]

# ---- over time ----
y = pd.read_csv(D / "theme_by_year.csv")
tot = y.groupby("year").mentions.sum()
ads = y[y.theme_group == "Ads and money"].groupby("year").mentions.sum().reindex(tot.index, fill_value=0)
out["adShareByYear"] = [{"year": int(k), "share": r(ads[k] / tot[k]), "mentions": int(tot[k])} for k in tot.index if tot[k] >= 1000]
s = pd.read_csv(P / "search_interest.csv", parse_dates=["month"])
s = s[s.month.dt.year >= 2004]
peaks = s[s.term != "Ballz"].groupby("term").interest_vs_peggle.max().sort_values(ascending=False)  # "ballz" is mostly slang searches
yr = s.assign(year=s.month.dt.year).groupby(["term", "year"]).interest_vs_peggle.mean().round(1)
out["trends"] = [{"term": k, "peak": r(peaks[k], 0), "peakYear": int(s[s.term == k].nlargest(1, "interest_vs_peggle").month.dt.year.iloc[0]),
                  "years": [[int(a), float(v)] for a, v in yr[k].items()]} for k in peaks.index[:12]]
rel = games[games.release_year.between(2008, 2026)].groupby(["ball_game_category", "release_year"]).size()
out["releases"] = {CAT[k]: [[int(a), int(v)] for a, v in d.droplevel(0).items()] for k, d in rel.groupby(level=0) if k in CAT}

# ---- design choices + model notes ----
lv = pd.read_csv(D / "success_feature_levels.csv")
out["design"] = lv[lv.feature != "platform"].to_dict("records")
out["models"] = {"sentiment": json.load(open(M / "sentiment_metrics.json")), "success": json.load(open(M / "success_metrics.json"))}
for k in ("before_fine_tuning", "after_fine_tuning"):
    out["models"]["sentiment"][k].pop("per_class", None)
sv = pd.read_csv(D / "stars_vs_text.csv", index_col=0)
out["starsVsText"] = {"lowStarsReadPositive": r(sv.loc["negative", "positive"] / sv.loc["negative"].sum())}
out["meta"] = {"reviews": reviews_n, "games": int(len(games)), "ratings": int(games.rating_count.sum()),
               "reviewedGames": int(pd.read_csv(D / "game_sentiment.csv").shape[0]), "themes": int((t.theme_group != "General reaction").sum()),
               "collected": "2026-11-26"}

assert len(out["themes"]) == 44 and len(out["countries"]) == 30 and abs(sum(b["installShare"] for b in out["installBuckets"]) - 1) < 0.01
dest = ROOT / "dashboard/src/data.json"
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(f"{dest.stat().st_size / 1024:.0f} KB,", len(out["games"]), "games,", len(out["gameThemes"]), "with theme detail")
