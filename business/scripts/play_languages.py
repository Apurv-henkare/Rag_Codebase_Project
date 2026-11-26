"""Reviews per day by language for the top Google Play ball games: a stand-in for where each game is played.

For each game and language, read newest reviews (max 1000) back to 30 days ago, then rate = reviews / days covered.
Output: data/processed/play_language_activity.csv
"""
import json, sys, time
from datetime import datetime, timedelta
from pathlib import Path
import pandas as pd
from google_play_scraper import Sort, reviews

ROOT = Path(__file__).resolve().parents[1]
LANGS = ["en", "es", "pt", "hi", "id", "ru", "tr", "fr", "de", "ar", "vi", "ja", "ko", "th"]
WINDOW = timedelta(days=30)
games = pd.read_csv(ROOT / "data/processed/games.csv", dtype={"store_id": str})
top = games[(games.platform == "Google Play (Android)") & ~games.ball_game_category.isin(["Unclassified"])].nlargest(40, "rating_count")

out_file = ROOT / "data/processed/play_language_activity.csv"
rows = pd.read_csv(out_file).to_dict("records") if out_file.exists() else []
done = {r["store_id"] for r in rows}  # re-runs only measure games not measured yet
now = datetime.now()
for _, g in top[~top.store_id.isin(done)].iterrows():
    for lang in LANGS:
        got, token, oldest = [], None, now
        try:
            while len(got) < 1000 and oldest > now - WINDOW:
                batch, token = reviews(g.store_id, lang=lang, country="us", sort=Sort.NEWEST, count=200, continuation_token=token)
                if not batch:
                    break
                got += batch
                oldest = min(r["at"] for r in batch)
                if getattr(token, "token", None) is None:
                    break
                time.sleep(1)
        except Exception as e:
            print("error", g.store_id, lang, e, file=sys.stderr, flush=True)
            time.sleep(30)
        recent = [r for r in got if r["at"] >= now - WINDOW]
        span = (now - min((r["at"] for r in recent), default=now)).total_seconds() / 86400
        days = round(max(span, 1 / 24), 3) if len(recent) >= 1000 else WINDOW.days  # hit the cap: rate over the time it covered
        rows.append({"store_id": g.store_id, "title": g.title, "lang": lang, "reviews_counted": len(recent), "days_covered": days,
                     "reviews_per_day": round(len(recent) / days, 2), "avg_stars": round(sum(r["score"] for r in recent) / len(recent), 2) if recent else None})
    print(f"{datetime.now():%H:%M} {g.title[:40]}", flush=True)
    pd.DataFrame(rows).to_csv(out_file, index=False)  # save after each game
