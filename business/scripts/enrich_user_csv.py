"""Link the 50-game research catalogue to the store listings in games.csv and add their numbers.

Keeps every original column unchanged; adds new columns. Output: data/processed/catalogue_50_enriched.csv
"""
import difflib, re
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
norm = lambda s: re.sub(r"[^a-z0-9]+", " ", str(s).lower().replace("'", "")).strip()

user = pd.read_csv(ROOT / "ball_game_intelligence_consolidated.csv", encoding="utf-8-sig")
games = pd.read_csv(ROOT / "data/processed/games.csv", dtype={"store_id": str})
games["key"] = games.title.map(norm)
# store titles that differ from the catalogue's title for the same game
ALIASES = {"Peggle": ["Peggle Deluxe"], "Switchball": ["Switchball HD"], "Amberial": ["Amberial Dreams"],
           "Rock of Ages 2: Bigger & Boulder": ["Rock of Ages 2: Bigger & Boulder™"], "Zuma Deluxe": ["Zuma Deluxe"]}


def best(title, platform):
    pool = games[games.platform == platform]
    keys = [norm(t) for t in str(title).split("/") + ALIASES.get(title, [])]
    hit = pool[pool.key.isin(keys)]
    exact = not hit.empty
    if not exact:
        digits = lambda s: re.findall(r"\d+", s)
        close = {m for k in keys for m in difflib.get_close_matches(k, pool.key.tolist(), n=3, cutoff=0.9) if digits(m) == digits(k)}
        hit = pool[pool.key.isin(close)]
    return hit.sort_values("rating_count", ascending=False).head(1), exact


def confidence(exact, listing_year, first_year):
    if not exact:
        return "fuzzy title match - verify"
    if pd.notna(listing_year) and pd.notna(first_year) and listing_year - first_year > 5:
        return "same title, released much later - verify it is the same game"
    return "exact title match"


cols = {"Steam (PC)": "steam", "Google Play (Android)": "play", "App Store (iOS)": "ios"}
for i, r in user.iterrows():
    for platform, p in cols.items():
        h, exact = best(r.game_title, platform)
        if h.empty:
            continue
        h = h.iloc[0]
        user.loc[i, f"{p}_match_confidence"] = confidence(exact, h.release_year, r.first_release_year)
        user.loc[i, f"{p}_store_id"] = h.store_id
        user.loc[i, f"{p}_matched_title"] = h.title
        user.loc[i, f"{p}_rating_count"] = h.rating_count
        user.loc[i, f"{p}_rating_score_100"] = h.rating_score_100
        user.loc[i, f"{p}_installs_low"] = h.installs_low
        user.loc[i, f"{p}_installs_high"] = h.installs_high
        user.loc[i, f"{p}_price_usd"] = h.price_usd
user.to_csv(ROOT / "data/processed/catalogue_50_enriched.csv", index=False)
linked = user.filter(like="_store_id").notna().any(axis=1)
print(f"{linked.sum()} of {len(user)} games linked to at least one store listing")
print(user.loc[linked, ["game_title"] + [c for c in user.columns if c.endswith(("_matched_title", "_match_confidence"))]].to_string(max_colwidth=30))
