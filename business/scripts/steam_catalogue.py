"""Pick ball games out of the 124k-game Steam catalogue (Hugging Face, FronkonGames).

Output: data/processed/steam_games.csv
"""
import re
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
# The file's header merges "Discount" and "DLC count" into one name, so every column after it is shifted.
COLS = ['AppID', 'Name', 'Release date', 'Estimated owners', 'Peak CCU', 'Required age', 'Price', 'Discount', 'DLC count',
        'About the game', 'Supported languages', 'Full audio languages', 'Reviews', 'Header image', 'Website', 'Support url',
        'Support email', 'Windows', 'Mac', 'Linux', 'Metacritic score', 'Metacritic url', 'User score', 'Positive', 'Negative',
        'Score rank', 'Achievements', 'Recommendations', 'Notes', 'Average playtime forever', 'Average playtime two weeks',
        'Median playtime forever', 'Median playtime two weeks', 'Developers', 'Publishers', 'Categories', 'Genres', 'Tags',
        'Screenshots', 'Movies']

NAME = r"\b(?:ball|balls|ballz|marble|marbles|rolling|roll|bounce|bouncy|bouncing|sphere|peggle|zuma|luxor|breakout|brick ?breaker|arkanoid|hamster ?ball|switchball|ballance|neverball|rock of ages|mercury (?:meltdown|hg)|kula world|amberial|marble madness)\b"
NOT_NAME = (r"dragon ball|soundtrack|\bost\b|demo|playtest|\bdlc\b|\bpack\b|football|basketball|baseball|soccer|golf|bowling|billiard|"
            r"\bpool\b|snooker|tennis|volley|dodgeball|paintball|rock ?'?n'? ?roll|roll ?call|roller ?coaster|bankroll|payroll|"
            r"barrel roll|dice|dyson sphere|sphere of influence|edna|rig ?n ?roll|heads will roll|rolling line|sausage roll|egg roll")
GAMEPLAY_TAGS = r"Physics|Platformer|Arcade|Puzzle|Casual|Pinball|Racing|Action"
NOT_TAGS = r"Sports|Sexual Content|Nudity|Hentai|Dating Sim|Visual Novel|Grand Strategy|Card Game"
# Description route: games that say the player controls a ball, whatever the title.
ABOUT = r"\b(?:control|guide|roll|steer|tilt|bounce|navigate)\w* (?:a|the|your) (?:\w+ )?(?:ball|marble|sphere)\b"


def load():
    return pd.read_csv(ROOT / "data/raw/hf/games.csv", skiprows=1, names=COLS, index_col=False, low_memory=False)


def select(df):
    name, tags, about = (df[c].fillna("") for c in ("Name", "Tags", "About the game"))
    by_name = name.str.contains(NAME, case=False, regex=True) & ~name.str.contains(NOT_NAME, case=False, regex=True)
    by_about = tags.str.contains(r"Physics|Platformer", regex=True) & about.str.contains(ABOUT, case=False, regex=True)
    ok = tags.str.contains(GAMEPLAY_TAGS, regex=True) & ~tags.str.contains(NOT_TAGS, regex=True)
    out = df[(by_name | by_about) & ok].copy()
    out["matched_by"] = ["name" if b else "description" for b in by_name[out.index]]
    return out


def features(s):
    owners = s["Estimated owners"].str.extract(r"(\d+)\s*-\s*(\d+)").astype(float)
    n = s["Positive"] + s["Negative"]
    langs = s["Supported languages"].fillna("").str.count("'") // 2
    return pd.DataFrame({
        "platform": "Steam (PC)",
        "store_id": s["AppID"].astype(str),
        "title": s["Name"],
        "release_date": pd.to_datetime(s["Release date"], errors="coerce").dt.date,
        "developer": s["Developers"],
        "publisher": s["Publishers"],
        "price_usd": s["Price"],
        "is_free": s["Price"].eq(0),
        "owners_low": owners[0],
        "owners_high": owners[1],
        "est_revenue_low_usd": (owners[0] * s["Price"]).round(),   # estimate: owners x current price, ignores discounts/refunds/store cut
        "est_revenue_high_usd": (owners[1] * s["Price"]).round(),
        "rating_count": n,
        "positive_pct": (100 * s["Positive"] / n.where(n > 0)).round(1),
        "metacritic_score": s["Metacritic score"].where(s["Metacritic score"] > 0),
        "median_playtime_min": s["Median playtime forever"],
        "avg_playtime_min": s["Average playtime forever"],
        "peak_ccu": s["Peak CCU"],
        "achievements": s["Achievements"],
        "dlc_count": s["DLC count"],
        "language_count": langs,
        "windows": s["Windows"], "mac": s["Mac"], "linux": s["Linux"],
        "genres": s["Genres"],
        "tags": s["Tags"],
        "categories": s["Categories"],
        "description": s["About the game"].fillna("").str.slice(0, 600),
        "matched_by": s["matched_by"],
    })


if __name__ == "__main__":
    games = features(select(load()))
    assert games["store_id"].is_unique
    assert (games["owners_low"] <= games["owners_high"]).all()
    games.sort_values("rating_count", ascending=False).to_csv(ROOT / "data/processed/steam_games.csv", index=False)
    print(len(games), "Steam ball games;", int((games.rating_count >= 10).sum()), "with 10+ reviews")
