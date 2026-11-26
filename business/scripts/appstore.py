"""Apple App Store: find ball games, get per-country rating counts, and recent reviews per country.

Outputs (data/raw/appstore/): apps.json, country_ratings.csv, reviews.csv
Uses Apple's public iTunes Search/Lookup API and customer-review RSS feed. Reviewer names are not stored.
"""
import csv, json, re, sys, time, urllib.parse, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data/raw/appstore"
QUERIES = ["bounce ball", "bounce classic", "bounce tales", "red ball", "red ball 4", "ball platformer", "rolling ball", "going balls",
           "rolling sky", "helix jump", "stack ball", "ballz", "brick breaker", "bricks breaker balls", "peggle", "zuma", "marble shooter",
           "marble maze", "super monkey ball", "sky ball", "ball run", "jump ball", "bouncing ball", "ball jump", "hamster ball",
           "geometry dash", "arkanoid", "breakout", "marble blast", "ball roll 3d", "tilt ball maze", "neverball", "rock of ages"]
COUNTRIES = ["us", "gb", "ca", "au", "in", "de", "fr", "it", "es", "br", "mx", "jp", "kr", "cn", "tw", "ru", "tr", "id", "ph", "th",
             "vn", "my", "sg", "sa", "ae", "nl", "se", "pl", "za", "ng"]
REVIEW_COUNTRIES = ["us", "gb", "ca", "au", "in", "de", "fr", "br", "jp", "ru"]
BALL = re.compile(r"ball|marble|bounce|bouncy|roll|helix|zuma|peggle|brick|breakout|arkanoid|geometry dash|sphere|orb", re.I)
NOT_BALL = re.compile(r"football|soccer|basketball|baseball|golf|tennis|cricket|volley|bowling|billiard|pool|snooker|dragon ball|sort|connect|word", re.I)


def get(url, tries=3):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "research-script"}), timeout=30) as r:
                return json.load(r)
        except Exception as e:
            print("retry", url[:90], e, file=sys.stderr, flush=True)
            time.sleep(20 * (i + 1))
    return None


apps = {}
for q in QUERIES:
    d = get("https://itunes.apple.com/search?" + urllib.parse.urlencode({"term": q, "entity": "software", "country": "us", "limit": 50}))
    for a in (d or {}).get("results", []):
        if BALL.search(a.get("trackName", "")) and not NOT_BALL.search(a.get("trackName", "")) and "Games" in a.get("genres", []):
            a["found_by_query"] = q
            apps.setdefault(a["trackId"], a)
    time.sleep(3)
json.dump(list(apps.values()), open(OUT / "apps.json", "w", encoding="utf-8"), ensure_ascii=False)
print(len(apps), "App Store apps", flush=True)

ids = list(apps)
with open(OUT / "country_ratings.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["store_id", "country", "rating_count", "avg_rating", "price"])
    for cc in COUNTRIES:
        for i in range(0, len(ids), 150):
            d = get(f"https://itunes.apple.com/lookup?id={','.join(map(str, ids[i:i + 150]))}&country={cc}")
            for a in (d or {}).get("results", []):
                w.writerow([a["trackId"], cc, a.get("userRatingCount", 0), a.get("averageUserRating"), a.get("price")])
            time.sleep(3)
        print("country", cc, "done", flush=True)

top = sorted(apps.values(), key=lambda a: -(a.get("userRatingCount") or 0))[:30]
with open(OUT / "reviews.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["store_id", "country", "review_id", "rating", "title", "content", "app_version", "updated", "vote_count"])
    for a in top:
        n = 0
        for cc in REVIEW_COUNTRIES:
            for page in range(1, 11):
                d = get(f"https://itunes.apple.com/{cc}/rss/customerreviews/page={page}/id={a['trackId']}/sortby=mostrecent/json", tries=2)
                entries = ((d or {}).get("feed") or {}).get("entry") or []
                entries = [e for e in (entries if isinstance(entries, list) else [entries]) if "im:rating" in e]
                for e in entries:
                    w.writerow([a["trackId"], cc, e["id"]["label"], e["im:rating"]["label"], e["title"]["label"], e["content"]["label"],
                                e.get("im:version", {}).get("label"), e.get("updated", {}).get("label"), e.get("im:voteCount", {}).get("label")])
                n += len(entries)
                time.sleep(0.6)
                if len(entries) < 50:
                    break
        print(f"reviews {a['trackName'][:40]:40} {n}", flush=True)
