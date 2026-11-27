"""Merge Steam, Google Play and App Store listings into one games table with shared features.

Output: data/processed/games.csv (one row per store listing; title_key groups the same game across stores)
"""
import json, re
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW, PROC = ROOT / "data/raw", ROOT / "data/processed"

# ---- category rules (brief: A platformer, B rolling, C physics/bouncing, D hybrid; marble shooters kept as adjacent) ----
# shortcut: keyword rules over title + tags/genre + description, not hand labels; spot-check before using as ground truth.
RULES = [
    ("Adjacent: boulder action", r"\brock of ages"),  # before Exclude: its Steam tags include Tower Defense
    ("Exclude", r"\b(fps|shooter game|battle royale|rpg|role playing|visual novel|mahjong|solitaire|sudoku|word|dice|deckbuild|"
                r"connect|sort|match 3 puzzle|pinball|flipper|bubble shooter|prison|tower defense|strategy game|city builder|"
                r"interactive fiction|fmv|god game|survival|sausage|cooking|tycoon|laser|slide puzzle|sliding|unblock|rolling in holes)\b"),
    ("Adjacent: marble shooter", r"\b(zuma|luxor|marble (shoot|blast|legend|puzzle|match|crush|woka|master|pop|duel|mania)|marble shooter|jungle marble|ball shoot\b)"),
    ("D: Hybrid / rhythm & transform", r"\b(geometry dash|tiles hop|hop ball|music|piano hop|dancing (road|ball)|beat|rhythm|rolling sky|rolling twins|roadball)"),
    ("C: Ball physics & bouncing", r"\b(brick|bricks|breakout|arkanoid|dx-ball|ballz|peggle|pachinko|plinko|pegs?\b|helix|stack ball|bounce merge|"
                                   r"punball|balls bounce|bounce and collect|smashball|angry birds bounce)"),
    ("A: Ball platformer", r"\b(red ball|bounce (classic|tales|back|ball|quest|touch|boing)|bouncy?|roller ball|ball hero|ball v\b|jump ball|"
                           r"ball adventure|2d platformer|precision platformer|bounce)\b"),
    ("B: Rolling ball", r"\b(roll|rolling|marble|monkey ball|ballance|switchball|neverball|going balls|sky ball|balance|hamster ?ball|ball run|"
                        r"ball game 3d|sphere|3d platformer|ball race|maze)"),
]
# description-only fallback when title/tags match nothing; stricter phrases than the title rules
DESC_RULES = [
    ("C: Ball physics & bouncing", r"plinko|pachinko|\bpegs?\b|break (all )?the bricks|brick breaker|helix"),
    ("Adjacent: marble shooter", r"match (colou?red )?marbles|three of the same colou?r|zuma"),
    ("D: Hybrid / rhythm & transform", r"rhythm|to the beat|music ball"),
    ("A: Ball platformer", r"platformer|bouncing ball|bounce the ball"),
    ("B: Rolling ball", r"\broll (the|your) ball|tilt|ball maze|rolling ball"),
]
EXCLUDE_IDS = {"2095300", "397040", "346810", "383740", "1585910", "758730", "1235100", "3384190", "696560", "1014370",
               "1627310", "546660", "325260", "com.proximabeta.mf.uamo", "com.yamystudio.prisonbreakout",
               "1308410", "680620", "1117330", "com.spyke.skyroll"}  # hand-checked false hits
A, B, C = "A: Ball platformer", "B: Rolling ball", "C: Ball physics & bouncing"
# hand labels for popular listings and spot-check misses (the top 60 listings hold 92% of all ratings)
OVERRIDES = {"1435951901": A, "com.custom.goescape": A, "1480638758": A, "1571520699": A, "1340929016": C, "com.water.balls": C,
             "com.game.rope.and.balls": C, "1597618935": C, "2587960": C, "508760": C, "1807920": C, "1435120620": B,
             "com.ivanvyd.hamsterbounce": B, "1674960": B, "com.Two747Game.SkyBall": B, "2819630": B,
             "com.colorup.game": B, "com.supertapx.lovedots": C, "com.playgendary.sportmasters": C, "games.joker.drop.poly": C,
             "com.dropping.ball.jungle.android": C, "1297180034": C, "game.color.ballz.block.brick.puzzle.free.physics.balls": C,
             "com.bigdog.games.gravityloopballs": C}


def category(row):
    if str(row.store_id) in EXCLUDE_IDS:
        return "Exclude"
    if str(row.store_id) in OVERRIDES:
        return OVERRIDES[str(row.store_id)]
    text = f"{row.title} | {row.genres} | {row.tags}".lower()
    for name, pat in RULES:
        if re.search(pat, text):
            return name
    desc = str(row.description).lower()
    for name, pat in DESC_RULES:
        if re.search(pat, desc):
            return name
    return "Unclassified"


def mechanics(desc):
    d = desc.fillna("").str.lower()
    levels = d.str.extract(r"(\d[\d,]*)\+?\s*(?:challenging |unique |amazing |exciting |fun |hand-crafted |handcrafted )?levels")[0]
    control = np.select(
        [d.str.contains(r"tilt|gyro|accelerometer|motion control"), d.str.contains(r"swipe|drag|slide your finger"),
         d.str.contains(r"one[- ]tap|one[- ]touch|tap to|just tap|simply tap"), d.str.contains(r"keyboard|controller|gamepad|arrow keys|joystick|wasd")],
        ["tilt", "swipe/drag", "tap", "direct (keys/controller)"], "unspecified")
    return pd.DataFrame({
        "control_type": control,
        "mentions_physics": d.str.contains(r"physics"),
        "mentions_bounce": d.str.contains(r"bounc|jump"),
        "mentions_roll": d.str.contains(r"\broll"),
        "levels_advertised": pd.to_numeric(levels.str.replace(",", ""), errors="coerce").where(lambda x: x < 100000),
        "has_level_editor": d.str.contains(r"level editor|create your own level|build your own level|level creator"),
        "has_leaderboards": d.str.contains(r"leaderboard|high score|global rank"),
        "has_multiplayer": d.str.contains(r"multiplayer|pvp|online battle|co-op|versus"),
        "has_checkpoints": d.str.contains(r"checkpoint"),
        "has_skins": d.str.contains(r"\bskins?\b|customi[sz]e your ball|unlock (?:new )?balls"),
        "has_boss_fights": d.str.contains(r"\bboss"),
        "works_offline": d.str.contains(r"offline|no wifi|no internet|without internet"),
    }, index=desc.index)


def steam():
    s = pd.read_csv(PROC / "steam_games.csv", dtype={"store_id": str})
    return pd.DataFrame({
        "platform": "Steam (PC)", "store_id": s.store_id, "title": s.title, "developer": s.developer,
        "release_date": pd.to_datetime(s.release_date, errors="coerce"), "price_usd": s.price_usd, "is_free": s.is_free,
        "has_iap": np.nan, "has_ads": np.nan, "installs_low": s.owners_low, "installs_high": s.owners_high,
        "installs_kind": "estimated owners (SteamSpy-style range)", "rating_count": s.rating_count,
        "rating_score_100": s.positive_pct, "stars_5": np.nan, "text_review_count": np.nan,
        "est_revenue_low_usd": s.est_revenue_low_usd, "est_revenue_high_usd": s.est_revenue_high_usd,
        "median_playtime_min": s.median_playtime_min, "metacritic_score": s.metacritic_score, "language_count": s.language_count,
        "content_rating": np.nan, "genres": s.genres, "tags": s.tags, "description": s.description,
        "last_updated": pd.NaT, "url": "https://store.steampowered.com/app/" + s.store_id,
    })


def play():
    p = pd.DataFrame(json.load(open(RAW / "play/apps.json", encoding="utf-8")))
    hist = pd.DataFrame(p["histogram"].apply(lambda h: h if isinstance(h, list) and len(h) == 5 else [np.nan] * 5).tolist(),
                        columns=[f"share_{i}star" for i in range(1, 6)])
    hist = hist.div(hist.sum(axis=1).replace(0, np.nan), axis=0).round(4)
    out = pd.DataFrame({
        "platform": "Google Play (Android)", "store_id": p.appId, "title": p.title, "developer": p.developer,
        "release_date": pd.to_datetime(p.released, errors="coerce"), "price_usd": p.price, "is_free": p["free"],
        "has_iap": p.offersIAP, "has_ads": p.containsAds, "installs_low": p.realInstalls, "installs_high": p.realInstalls,
        "installs_kind": "installs (Google Play count)", "rating_count": p.ratings, "rating_score_100": (p.score * 20).round(1),
        "stars_5": p.score.round(2), "text_review_count": p.reviews, "est_revenue_low_usd": np.nan, "est_revenue_high_usd": np.nan,
        "median_playtime_min": np.nan, "metacritic_score": np.nan, "language_count": np.nan, "content_rating": p.contentRating,
        "genres": p.genre, "tags": "", "description": p.description.fillna("").str.slice(0, 600),
        "last_updated": pd.to_datetime(p.updated, unit="s", errors="coerce"), "url": p.url,
        "iap_price_range": p.inAppProductPrice,
    })
    return pd.concat([out, hist], axis=1)


def appstore():
    f = RAW / "appstore/apps.json"
    if not f.exists():
        return pd.DataFrame()
    a = pd.DataFrame(json.load(open(f, encoding="utf-8")))
    return pd.DataFrame({
        "platform": "App Store (iOS)", "store_id": a.trackId.astype(str), "title": a.trackName, "developer": a.sellerName,
        "release_date": pd.to_datetime(a.releaseDate, errors="coerce").dt.tz_localize(None), "price_usd": a.price,
        "is_free": a.price.eq(0), "has_iap": np.nan, "has_ads": np.nan, "installs_low": np.nan, "installs_high": np.nan,
        "installs_kind": "not published by Apple", "rating_count": a.userRatingCount, "rating_score_100": (a.averageUserRating * 20).round(1),
        "stars_5": a.averageUserRating.round(2), "text_review_count": np.nan, "est_revenue_low_usd": np.nan, "est_revenue_high_usd": np.nan,
        "median_playtime_min": np.nan, "metacritic_score": np.nan, "language_count": a.languageCodesISO2A.str.len(),
        "content_rating": a.contentAdvisoryRating, "genres": a.genres.str.join(","), "tags": "",
        "description": a.description.fillna("").str.slice(0, 600),
        "last_updated": pd.to_datetime(a.currentVersionReleaseDate, errors="coerce").dt.tz_localize(None), "url": a.trackViewUrl,
    })


if __name__ == "__main__":
    g = pd.concat([steam(), play(), appstore()], ignore_index=True)
    g = g.drop_duplicates(["platform", "store_id"])
    g["ball_game_category"] = g.apply(category, axis=1)
    g = g[g.ball_game_category != "Exclude"].copy()
    g["release_year"] = g.release_date.dt.year
    g["years_on_market"] = ((pd.Timestamp("2026-11-26") - g.release_date).dt.days / 365.25).round(1)
    g["ratings_per_year"] = (g.rating_count / g.years_on_market.clip(lower=0.25)).round(0)
    g["title_key"] = g.title.map(lambda t: re.sub(r"[^a-z0-9]+", " ", str(t).lower()).strip())
    g = pd.concat([g, mechanics(g.description)], axis=1)
    assert g[["platform", "store_id"]].drop_duplicates().shape[0] == len(g)
    assert g.rating_score_100.dropna().between(0, 100).all()
    g.sort_values(["platform", "rating_count"], ascending=[True, False]).to_csv(PROC / "games.csv", index=False)
    print(len(g), "listings"); print(g.groupby(["ball_game_category", "platform"]).size().unstack().fillna(0).astype(int).to_string())
