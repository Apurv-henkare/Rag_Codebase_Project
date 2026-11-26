"""Combine all review sources into one table, and tidy the country and trends tables.

Outputs (data/processed/): reviews.csv, country_ratings.csv, search_interest.csv
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW, PROC = ROOT / "data/raw", ROOT / "data/processed"
games = pd.read_csv(PROC / "games.csv", dtype={"store_id": str}, usecols=["platform", "store_id", "title", "ball_game_category"])


def play():
    parts = []
    for folder, label in [("reviews", "google_play_scraper (newest, lang=en)"), ("reviews_relevant", "google_play_scraper (most relevant, lang=en)")]:
        for f in (RAW / "play" / folder).glob("*.csv"):
            parts.append(pd.read_csv(f, dtype={"appId": str, "reviewCreatedVersion": str}).assign(source=label))
    r = pd.concat(parts, ignore_index=True)  # the two passes overlap; duplicates are dropped by review_id below
    return pd.DataFrame({"platform": "Google Play (Android)", "store_id": r.appId, "review_id": r.reviewId, "stars": r.score,
                         "recommended": pd.NA, "text": r.content, "date": pd.to_datetime(r["at"], errors="coerce"),
                         "helpful_votes": r.thumbsUpCount, "app_version": r.reviewCreatedVersion, "country": pd.NA,
                         "has_dev_reply": r.has_dev_reply, "source": r.source})


def appstore():
    f = RAW / "appstore/reviews.csv"
    if not f.exists():
        return pd.DataFrame()
    r = pd.read_csv(f, dtype={"store_id": str, "review_id": str, "app_version": str})
    text = (r.title.fillna("") + ". " + r.content.fillna("")).str.strip(". ")
    return pd.DataFrame({"platform": "App Store (iOS)", "store_id": r.store_id, "review_id": r.review_id, "stars": r.rating,
                         "recommended": pd.NA, "text": text, "date": pd.to_datetime(r.updated, errors="coerce", utc=True).dt.tz_localize(None),
                         "helpful_votes": r.vote_count, "app_version": r.app_version, "country": r.country,
                         "has_dev_reply": pd.NA, "source": "Apple customer-review RSS (500 most recent per country)"})


def steam():
    z = pd.read_csv(PROC / "steam_reviews.csv", dtype={"store_id": str})
    z = z.assign(date=pd.NaT, hours_played=pd.NA, source="Zenodo 1000885 (2017 English snapshot)")
    f = PROC / "steam_reviews_ucsd.csv"
    u = pd.read_csv(f, dtype={"store_id": str}) if f.exists() else pd.DataFrame(columns=z.columns)
    # v2 dates look like 2017-12-17; v1 like "Posted November 5, 2011."
    u["date"] = pd.to_datetime(u.date.astype(str).str.replace(r"^Posted |\.$", "", regex=True), errors="coerce", format="mixed")
    u["date"] = u.date.where(u.date.dt.year >= 2003)  # v1 omits the year for current-year posts, which parses as year 1
    r = pd.concat([z, u], ignore_index=True)
    r = r[~r.duplicated(["store_id", "review_text"])]
    rec = r.recommended.map({True: True, False: False, "True": True, "False": False})
    return pd.DataFrame({"platform": "Steam (PC)", "store_id": r.store_id, "review_id": pd.NA, "stars": pd.NA,
                         "recommended": rec, "text": r.review_text, "date": r.date, "helpful_votes": r.helpful_votes,
                         "hours_played": r.hours_played, "app_version": pd.NA, "country": pd.NA, "has_dev_reply": pd.NA,
                         "source": r.source})


rev = pd.concat([play(), appstore(), steam()], ignore_index=True)
rev["text"] = rev.text.astype(str).str.replace(r"\s+", " ", regex=True).str.strip()
rev = rev[rev.text.str.len() > 1]
rev = rev[rev.review_id.isna() | ~rev.duplicated(["platform", "review_id"])]
# one label across stores: 4-5 stars or recommended = positive, 1-2 stars or not recommended = negative, 3 stars = neutral
stars = pd.to_numeric(rev.stars, errors="coerce")
rev["sentiment"] = "unknown"
rev.loc[stars == 3, "sentiment"] = "neutral"
rev.loc[(stars >= 4) | (rev.recommended == True), "sentiment"] = "positive"
rev.loc[(stars <= 2) | (rev.recommended == False), "sentiment"] = "negative"
rev = rev.merge(games, on=["platform", "store_id"], how="inner")  # drops reviews of listings the catalogue excluded
assert rev.sentiment.isin(["positive", "negative", "neutral", "unknown"]).all()
rev.to_csv(PROC / "reviews.csv", index=False)
print(len(rev), "reviews"); print(rev.groupby(["platform", "sentiment"]).size().unstack().to_string())

f = RAW / "appstore/country_ratings.csv"
if f.exists():
    c = pd.read_csv(f, dtype={"store_id": str})
    c = c[c.rating_count > 0]
    c["share_of_game_ratings"] = (c.rating_count / c.groupby("store_id").rating_count.transform("sum")).round(4)
    c = c.merge(games[games.platform == "App Store (iOS)"].drop(columns="platform"), on="store_id", how="inner")
    c.to_csv(PROC / "country_ratings.csv", index=False)
    print(len(c), "game x country rows,", c.store_id.nunique(), "games")

t = pd.read_csv(RAW / "trends/interest_monthly.csv")
t.to_csv(PROC / "search_interest.csv", index=False)
print(len(t), "trend rows")
