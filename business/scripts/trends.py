"""Google Trends worldwide search interest, monthly since 2004, for the best-known ball games.

Every request carries the anchor term "Peggle" so values from different requests can be rescaled to one scale.
Output: data/raw/trends/interest_monthly.csv (columns: month, term, interest, interest_vs_peggle)
"""
import sys, time
from pathlib import Path
import pandas as pd
from pytrends.request import TrendReq

ROOT = Path(__file__).resolve().parents[1]
ANCHOR = "Peggle"
TERMS = ["Bounce Tales", "Nokia Bounce", "Red Ball 4", "Helix Jump", "Stack Ball", "Going Balls", "Rolling Sky", "Ballz",
         "Geometry Dash", "Zuma Deluxe", "Super Monkey Ball", "Marble Madness", "Marble Blast", "Ballance", "Neverball",
         "Switchball", "Rock of Ages game", "Marble It Up", "Hamsterball", "Kula World", "Mercury Meltdown", "Arkanoid",
         "Brick Breaker", "Luxor game", "Tiles Hop", "Sand Balls", "Bounce Classic", "Kirby Tilt n Tumble", "Bounce Back Nokia",
         "Peggle Blast", "Bricks Breaker Quest", "Geometry Dash Lite"]

py = TrendReq(hl="en-US", tz=0)  # no built-in retries: pytrends' Retry args break on urllib3 2.x; the loop below retries
frames = []
for i in range(0, len(TERMS), 4):
    batch = TERMS[i:i + 4] + [ANCHOR]
    for attempt in range(3):
        try:
            py.build_payload(batch, timeframe="all")
            df = py.interest_over_time()
            break
        except Exception as e:
            print("blocked/retry", batch, e, file=sys.stderr, flush=True)
            time.sleep(60 * (attempt + 1))
    else:
        continue
    if df.empty:
        continue
    df = df.drop(columns="isPartial", errors="ignore")
    anchor_peak = df[ANCHOR].max() or 1
    long = df.reset_index().melt(id_vars="date", var_name="term", value_name="interest")
    long["interest_vs_peggle"] = (100 * long["interest"] / anchor_peak).round(2)  # 100 = Peggle's all-time peak
    frames.append(long[long.term != ANCHOR] if i else long)
    print("ok", batch, flush=True)
    time.sleep(15)

out = pd.concat(frames).rename(columns={"date": "month"})
out.to_csv(ROOT / "data/raw/trends/interest_monthly.csv", index=False)
print(out.term.nunique(), "terms saved")
