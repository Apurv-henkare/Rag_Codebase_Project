"""Keep the UCSD Steam reviews (McAuley lab, 2010-2018) that belong to our Steam ball games.

Files are one Python-dict literal per line, not JSON. Usernames and user ids are dropped.
Output: data/processed/steam_reviews_ucsd.csv
"""
import ast, csv, gzip, re
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/ucsd"
ids = set(pd.read_csv(ROOT / "data/processed/steam_games.csv", usecols=["store_id"], dtype=str)["store_id"])
FIELDS = ["store_id", "review_text", "recommended", "helpful_votes", "hours_played", "date", "source"]

with open(ROOT / "data/processed/steam_reviews_ucsd.csv", "w", newline="", encoding="utf-8") as out:
    w = csv.DictWriter(out, FIELDS)
    w.writeheader()
    kept = 0
    pid = re.compile(r"'product_id': u?'(\d+)'")  # file is Python 2 repr: u'...' strings
    with gzip.open(RAW / "steam_reviews.json.gz", "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = pid.search(line)
            if not m or m.group(1) not in ids:
                continue
            r = ast.literal_eval(line)
            w.writerow({"store_id": r["product_id"], "review_text": r.get("text", ""), "recommended": r.get("recommended"),
                        "helpful_votes": r.get("found_funny"), "hours_played": r.get("hours"), "date": r.get("date"),
                        "source": "UCSD Steam reviews v2"})
            kept += 1
    print("v2 kept", kept, flush=True)
    item = re.compile(r"'item_id': u?'(\d+)'")
    with gzip.open(RAW / "australian_user_reviews.json.gz", "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            if not any(i in ids for i in item.findall(line)):
                continue
            for r in ast.literal_eval(line)["reviews"]:
                if r["item_id"] in ids:
                    w.writerow({"store_id": r["item_id"], "review_text": r.get("review", ""), "recommended": r.get("recommend"),
                                "helpful_votes": r.get("helpful"), "hours_played": None, "date": r.get("posted"),
                                "source": "UCSD Australian user reviews v1"})
                    kept += 1
    print("total kept", kept)
