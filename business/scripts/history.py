"""Ball games outside the three stores: J2ME (Nokia-era) archive, the rolling-ball list, and itch.io indie games.

These sources give titles, years, prices and platforms but no sales or ratings.
Output: data/processed/other_titles.csv
"""
import re, time, urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/history"
BALL = r"\b(?:ball|balls|ballz|bounce|bouncy|bouncing|marble|marbles|roll|rolling|zuma|breakout|brick|arkanoid|helix|sphere|orb)"
NOT_BALL = r"football|soccer|basketball|baseball|golf|tennis|bowling|\bpool\b|billiard|snooker|volley|cricket|dragon ball|paintball|skee|sports"

j = pd.read_csv(RAW / "j2me_catalog.csv", encoding="utf-8-sig")
j = j[j.title.str.contains(BALL, case=False, regex=True) & ~j.title.str.contains(NOT_BALL, case=False, regex=True)]
j2me = pd.DataFrame({"source": "J2ME archive (wakkatobakka)", "title": j.title, "year": j.listed_year, "platform": "J2ME / Nokia-era mobile",
                     "price_usd": pd.NA, "genre_tags": j.genres_as_listed, "url": j.page})

html = (RAW / "rollingballs_list.html").read_text(encoding="utf-8", errors="replace")
names = [n.strip() for n in re.findall(r"<li[^>]*>(.*?)</li>", html, re.S)]
names = [re.sub(r"<[^>]+>", "", n).strip().split("\n")[-1].strip() for n in names if n]  # first <li> also holds the page intro
rb = pd.DataFrame({"source": "List of Rolling Ball Games (rollingballs.neocities.org)", "title": names, "year": pd.NA,
                   "platform": pd.NA, "price_usd": pd.NA, "genre_tags": "rolling ball", "url": "https://rollingballs.neocities.org/list"})

rows = []
for tag in ["tag-ball", "tag-marble", "tag-rolling", "genre-platformer/tag-ball"]:
    for page in range(1, 41):
        url = f"https://itch.io/games/{tag}.xml?page={page}"
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "research-script"}), timeout=30) as r:
                items = ET.fromstring(r.read()).findall(".//item")
        except Exception as e:
            print("stop", url, e); break
        if not items:
            break
        for it in items:
            g = lambda k: (it.findtext(k) or "").strip()
            tags = re.findall(r"\[([^\]]+)\]", g("title"))
            rows.append({"source": f"itch.io ({tag})", "title": g("plainTitle"), "year": pd.to_datetime(g("createDate"), errors="coerce").year,
                         "platform": ", ".join(t for t in tags if t in ("Windows", "macOS", "Linux", "Android", "HTML5", "iOS")) or "itch.io",
                         "price_usd": pd.to_numeric(g("price").replace("$", ""), errors="coerce"),
                         "genre_tags": ", ".join(t for t in tags if t not in ("Free", "Windows", "macOS", "Linux", "Android", "HTML5", "iOS")),
                         "url": g("link")})
        time.sleep(2)
    print(tag, len(rows), "rows so far", flush=True)
itch = pd.DataFrame(rows).drop_duplicates("url")
itch = itch[~itch.genre_tags.str.contains("Sports", na=False) & ~itch.title.str.contains(NOT_BALL, case=False, regex=True)]

out = pd.concat([j2me, rb, itch], ignore_index=True)
out.to_csv(ROOT / "data/processed/other_titles.csv", index=False)
print(out.groupby("source").size().to_string())
