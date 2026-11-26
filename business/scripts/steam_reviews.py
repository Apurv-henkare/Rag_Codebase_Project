"""Keep the Zenodo 2017 Steam reviews (6.4M, English) that belong to our Steam ball games.

Input columns (no header): app_id, review_text, review_score (1 recommended / -1 not), review_votes (helpful).
Output: data/processed/steam_reviews.csv
"""
import bz2, csv, sys
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
csv.field_size_limit(10**8)
ids = set(pd.read_csv(ROOT / "data/processed/steam_games.csv", usecols=["store_id"], dtype=str)["store_id"])

kept = seen = 0
with bz2.open(ROOT / "data/raw/zenodo/steam.csv.bz2", "rt", encoding="utf-8", errors="replace", newline="") as src, \
        open(ROOT / "data/processed/steam_reviews.csv", "w", newline="", encoding="utf-8") as dst:
    w = csv.writer(dst)
    w.writerow(["store_id", "review_text", "recommended", "helpful_votes", "source"])
    for row in csv.reader(src):
        seen += 1
        if len(row) == 4 and row[0] in ids:
            w.writerow([row[0], row[1].strip(), row[2] == "1", row[3], "zenodo_2017"])
            kept += 1
        if seen % 1_000_000 == 0:
            print(f"{seen:,} read, {kept:,} kept", flush=True)
print(f"done: {seen:,} read, {kept:,} kept", file=sys.stderr)
