"""Download Google Play review text for the ball games found by play_discover.py.

Usage: python play_reviews.py <per_app_cap> <stop_at HH:MM> [newest|relevant] [top_n_apps]
Writes one CSV per app to data/raw/play/reviews/ (newest) or reviews_relevant/ as it goes, so a stop keeps what was fetched.
Reviewer names and avatars are not stored.
"""
import csv, json, re, sys, time
from datetime import datetime
from pathlib import Path
from google_play_scraper import Sort, reviews

ROOT = Path(__file__).resolve().parents[1]
SORT = sys.argv[3] if len(sys.argv) > 3 else "newest"
TOP_N = int(sys.argv[4]) if len(sys.argv) > 4 else None
OUT = ROOT / ("data/raw/play/reviews" if SORT == "newest" else "data/raw/play/reviews_relevant")
OUT.mkdir(parents=True, exist_ok=True)
NOT_BALL = re.compile(r"FPS|shooter game|role playing|connect|sort|match puzzle|pop - match|word|solitaire|mahjong|bubble", re.I)
FIELDS = ["appId", "reviewId", "score", "content", "thumbsUpCount", "at", "reviewCreatedVersion", "has_dev_reply"]

cap, stop_h, stop_m = int(sys.argv[1]), *map(int, sys.argv[2].split(":"))
stop_at = datetime.now().replace(hour=stop_h, minute=stop_m, second=0)

apps = json.load(open(ROOT / "data/raw/play/apps.json", encoding="utf-8"))
apps = [a for a in apps if (a.get("ratings") or 0) >= 1000 and not NOT_BALL.search(a["title"]) and a.get("genre") not in ("Role Playing", "Word")]
catalogue = ROOT / "data/processed/games.csv"
if catalogue.exists():  # only listings the catalogue kept (its rules exclude pinball, sorting puzzles, etc.)
    import pandas as pd
    keep = set(pd.read_csv(catalogue, usecols=["store_id"], dtype=str).store_id)
    apps = [a for a in apps if a["appId"] in keep]
apps.sort(key=lambda a: -(a.get("ratings") or 0))
apps = apps[:TOP_N]
print(f"{len(apps)} apps queued, cap {cap} each, stop at {stop_at:%H:%M}", flush=True)

total = 0
for a in apps:
    path = OUT / f"{a['appId']}.csv"
    if path.exists():
        continue
    rows, token = [], None
    while len(rows) < cap and datetime.now() < stop_at:
        try:
            batch, token = reviews(a["appId"], lang="en", country="us", sort=Sort.NEWEST if SORT == "newest" else Sort.MOST_RELEVANT, count=200, continuation_token=token)
        except Exception as e:
            print("error", a["appId"], e, file=sys.stderr, flush=True)
            time.sleep(30)
            break
        rows += [{**{k: r.get(k) for k in FIELDS[1:7]}, "appId": a["appId"], "has_dev_reply": bool(r.get("replyContent"))} for r in batch]
        if not batch or token is None or getattr(token, "token", None) is None:
            break
        time.sleep(0.5)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, FIELDS)
        w.writeheader()
        w.writerows(rows[:cap])
    total += min(len(rows), cap)
    print(f"{datetime.now():%H:%M} {a['title'][:40]:40} {min(len(rows), cap):>6}  total {total}", flush=True)
    if datetime.now() >= stop_at:
        print("stop time reached", flush=True)
        break
