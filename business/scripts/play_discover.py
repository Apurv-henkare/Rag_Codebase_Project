"""Find ball games on Google Play and save each app's store details.

Output: data/raw/play/apps.json (all details), data/raw/play/search_hits.csv (which query found what).
"""
import json, re, sys, time
from pathlib import Path
import pandas as pd
from google_play_scraper import app, search

OUT = Path(__file__).resolve().parents[1] / "data" / "raw" / "play"
QUERIES = [
    "bounce ball", "bounce classic", "bounce tales", "nokia bounce", "red ball", "red ball 4", "ball platformer",
    "rolling ball", "ball roll 3d", "going balls", "rolling sky", "helix jump", "stack ball", "ballz",
    "brick breaker ball", "bricks breaker", "peggle", "zuma", "marble shooter", "marble run", "marble maze",
    "ball maze tilt", "super monkey ball", "sky ball", "color bump", "ball run", "jump ball", "bouncing ball",
    "balance ball 3d", "ball jump", "hamster ball", "ball adventure", "geometry dash", "ball blast",
    "arkanoid", "breakout game", "switchball", "neverball", "rock of ages", "mercury meltdown",
    # second round: broader ball-control phrasing
    "ball game", "ball games offline", "ball escape", "ball maze", "ball balance", "ball fall", "drop ball", "ball bounce 3d",
    "red bounce ball", "bounce ball adventure", "ball physics", "ball roller", "rolling ball 3d", "ball race",
    "ball jump 3d", "tilt maze", "marble game", "marble roll", "ball hop", "helix ball", "fire balls 3d", "ball blast cannon",
    "bricks balls", "brick breaker offline", "pinball physics ball", "pachinko", "plinko ball", "bouncy ball game",
    "ball tower", "ball dash", "sky roller", "ball action", "ball climb", "ball paint", "balls rotate", "ball run 2048",
    "smash ball", "crash ball", "ball shooter physics", "rolling ball adventure",
]
# shortcut: keyword gate on title/summary only; a manual category pass happens in build_catalogue.py
BALL = re.compile(r"ball|marble|bounce|bouncy|roll|helix|zuma|peggle|brick|breakout|arkanoid|geometry dash|sphere|orb", re.I)
SPORTS = re.compile(r"football|soccer|basketball|baseball|golf|tennis|cricket|volleyball|bowling|billiard|pool|snooker|dragon ball|ball sort|sort puzzle", re.I)

hits, ids = [], {}
for q in QUERIES:
    try:
        res = search(q, lang="en", country="us", n_hits=30)
    except Exception as e:
        print("search failed:", q, e, file=sys.stderr); continue
    for r in res:
        if not r.get("appId"):
            continue
        text = f"{r.get('title','')} {r.get('summary','')}"
        keep = bool(BALL.search(text)) and not SPORTS.search(r.get("title", "")) and r.get("genre") != "Sports"
        hits.append({"query": q, "appId": r["appId"], "title": r.get("title"), "genre": r.get("genre"), "kept": keep})
        if keep:
            ids.setdefault(r["appId"], q)
    time.sleep(1)
print(f"{len(hits)} search hits, {len(ids)} kept apps", flush=True)
pd.DataFrame(hits).to_csv(OUT / "search_hits.csv", index=False)

prev = OUT / "apps.json"
details = json.load(open(prev, encoding="utf-8")) if prev.exists() else []
have = {d["appId"] for d in details}  # re-runs only fetch apps not already saved
ids = {k: v for k, v in ids.items() if k not in have}
for i, (aid, q) in enumerate(ids.items(), 1):
    try:
        d = app(aid, lang="en", country="us")
    except Exception as e:
        print("details failed:", aid, e, file=sys.stderr); continue
    d.pop("comments", None)
    d["found_by_query"] = q
    details.append(d)
    if i % 25 == 0:
        print(f"details {i}/{len(ids)}", flush=True)
    time.sleep(0.7)
json.dump(details, open(OUT / "apps.json", "w", encoding="utf-8"), ensure_ascii=False, default=str)
print(f"saved {len(details)} apps")
