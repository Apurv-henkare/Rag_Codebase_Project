"""Turn the model outputs into small tables for the dashboard.

Needs theme_names.csv (cluster -> theme name and group, written by hand after reading out/clusters.csv).
A "mention" is one review talking about one theme; its sentiment is the model's average over that review's clauses in the theme.

In:  data/reviews.csv.gz, out/review_sentiment.csv.gz, out/clauses.csv.gz, out/clause_texts.csv.gz, theme_names.csv
Out: out/dashboard/*.csv
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out/dashboard"
OUT.mkdir(parents=True, exist_ok=True)
LABELS = ["negative", "neutral", "positive"]
# quotes shown to the public: skip profanity and slurs (shortcut: small word list, extend if the dashboard shows a bad quote)
RUDE = r"\b(?:fuck|shit|bitch|cunt|dick|pussy|nigg|fag|retard|whore|slut|bastard|asshole|porn|sex)"

rev = pd.read_csv(ROOT / "data/reviews.csv.gz", dtype=str,
                  usecols=["platform", "store_id", "title", "ball_game_category", "stars", "sentiment", "date", "country"])
rev["row"] = np.arange(len(rev))
rev["year"] = pd.to_datetime(rev.date, errors="coerce").dt.year
rs = pd.read_csv(ROOT / "out/review_sentiment.csv.gz")
assert len(rs) == len(rev) and (rs.row.to_numpy() == rev.row.to_numpy()).all()
rev = rev.join(rs.drop(columns="row"))

names = pd.read_csv(ROOT / "theme_names.csv")  # cluster, theme, theme_group
texts = pd.read_csv(ROOT / "out/clause_texts.csv.gz").merge(names, on="cluster", how="left", validate="many_to_one")
assert texts.theme.notna().all(), "every cluster needs a name in theme_names.csv"
cl = pd.read_csv(ROOT / "out/clauses.csv.gz").merge(texts[["clause_id", "theme", "theme_group", "p_negative", "p_neutral", "p_positive"]], on="clause_id")

m = cl.groupby(["row", "theme", "theme_group"], as_index=False)[["p_negative", "p_neutral", "p_positive"]].mean()
m["mention_sentiment"] = np.array(LABELS)[m[["p_negative", "p_neutral", "p_positive"]].to_numpy().argmax(1)]
m = m.merge(rev[["row", "platform", "store_id", "title", "ball_game_category", "country", "year"]], on="row")


def summarise(g):
    s = g.mention_sentiment.value_counts()
    return pd.Series({"mentions": len(g), "positive": int(s.get("positive", 0)), "negative": int(s.get("negative", 0)),
                      "neutral": int(s.get("neutral", 0)), "share_positive": round(s.get("positive", 0) / len(g), 3),
                      "share_negative": round(s.get("negative", 0) / len(g), 3)})


def table(keys, min_mentions=0):
    t = m.groupby(keys + ["theme", "theme_group"]).apply(summarise, include_groups=False).reset_index()
    t["share_of_mentions"] = (t.mentions / t.groupby(keys).mentions.transform("sum")).round(4) if keys else (t.mentions / t.mentions.sum()).round(4)
    return t[t.mentions >= min_mentions]


# a quote must use one of its theme's keywords, so frequent off-topic sentences are not shown as examples
kw = pd.read_csv(ROOT / "out/clusters.csv", usecols=["cluster", "keywords"]).merge(names, on="cluster")
KEYWORDS = kw.groupby("theme").keywords.apply(lambda k: r"\b(?:" + "|".join(sorted({w for s in k for w in s.split(", ")}, key=len, reverse=True)) + r")\b")


def quotes(theme, label, n=6):
    q = texts[(texts.theme == theme) & (texts.model_sentiment == label) & (texts[f"p_{label}"] >= 0.8)]
    q = q[q.text.str.split().str.len().between(5, 25) & ~q.text.str.contains(RUDE, regex=True) & q.text.str.contains(KEYWORDS[theme], regex=True)]
    return " | ".join(q.sort_values(["occurrences", f"p_{label}"], ascending=False).text.head(n).str.capitalize())


themes = table([])
themes["reviews_mentioning"] = themes.mentions
themes["praise_quotes"] = themes.theme.map(lambda t: quotes(t, "positive"))
themes["complaint_quotes"] = themes.theme.map(lambda t: quotes(t, "negative"))
themes.sort_values("mentions", ascending=False).to_csv(OUT / "themes.csv", index=False)

table(["ball_game_category"]).to_csv(OUT / "theme_by_category.csv", index=False)
table(["platform"]).to_csv(OUT / "theme_by_platform.csv", index=False)
table(["year"], min_mentions=20).to_csv(OUT / "theme_by_year.csv", index=False)
m[m.country.notna()].pipe(lambda d: d.groupby(["country", "theme", "theme_group"]).apply(summarise, include_groups=False)) \
    .reset_index().to_csv(OUT / "theme_by_country.csv", index=False)  # App Store reviews only (10 country stores)

# per game: which themes stand out compared with other games in the same category ("lift" > 1 = talked about more than usual)
g = table(["platform", "store_id", "title", "ball_game_category"], min_mentions=1)
cat = table(["ball_game_category"])[["ball_game_category", "theme", "share_of_mentions"]].rename(columns={"share_of_mentions": "category_share"})
g = g.merge(cat, on=["ball_game_category", "theme"])
g["lift_vs_category"] = (g.share_of_mentions / g.category_share).round(2)
reviewed = rev.groupby(["platform", "store_id"]).size().rename("reviews").reset_index()
g = g.merge(reviewed, on=["platform", "store_id"])
g[g.reviews >= 200].to_csv(OUT / "theme_by_game.csv", index=False)

# per game sentiment: store stars vs model reading of the text
gs = rev.groupby(["platform", "store_id", "title", "ball_game_category"]).agg(
    reviews=("row", "size"), star_positive_share=("sentiment", lambda s: round((s == "positive").sum() / max(s.isin(LABELS).sum(), 1), 3)),
    model_positive_share=("model_sentiment", lambda s: round((s == "positive").mean(), 3)),
    model_negative_share=("model_sentiment", lambda s: round((s == "negative").mean(), 3))).reset_index()
specific = g[g.theme_group != "General reaction"]
for col, label in [("most_praised_theme", "positive"), ("most_criticised_theme", "negative")]:
    top = specific[specific.mentions >= 20].assign(k=lambda d: d[label]).sort_values("k", ascending=False).drop_duplicates(["platform", "store_id"])
    gs = gs.merge(top[["platform", "store_id", "theme"]].rename(columns={"theme": col}), on=["platform", "store_id"], how="left")
gs.to_csv(OUT / "game_sentiment.csv", index=False)

# reviews whose stars and text disagree, e.g. 1 star "great game" (how noisy store stars are)
agree = rev[rev.sentiment.isin(LABELS)]
pd.crosstab(agree.sentiment, agree.model_sentiment).to_csv(OUT / "stars_vs_text.csv")
print({f.name: len(pd.read_csv(f)) for f in sorted(OUT.glob("*.csv"))})
