# Ball game data

Data on ball-control games (Nokia Bounce and similar games) collected on 2026-11-26 from public sources.
Scripts in `../scripts/` rebuild everything. `raw/` holds the downloads and is not committed to git (too large).
The original 50-game catalogue, `../ball_game_intelligence_consolidated.csv`, is never modified.

**Missing values are blank, never zero.** Blank means "not published", not "none".

## What's here (2026-11-26)

| | Count |
|---|---|
| Store listings (`games.csv`) | 1,702: 754 Google Play, 561 App Store, 387 Steam; 50 columns each; 48.1M ratings between them |
| Reviews (`reviews.csv`) | 790,541: 717,550 Google Play, 67,914 App Store, 5,077 Steam; 555k positive, 179k negative, 56k neutral |
| iOS game × country rating rows | 8,768 (521 games, 30 countries) |
| Google Play game × language activity rows | 714 (51 games, 14 languages) |
| Monthly search-interest rows | 9,075 (33 search terms, 2004–2026) |
| Published sales/revenue figures | 18, each with a source and confidence level |
| Other ball games (no store data) | 1,674: 12 J2ME/Nokia-era, 35 historical rolling-ball games, 1,627 itch.io indie games |
| Original catalogue linked to stores | 24 of 50 games (the rest are Nokia/arcade/console titles not sold in these stores) |

## Files in `processed/`

| File | One row per | What it is for |
|---|---|---|
| `games.csv` | store listing (Steam, Google Play or App Store) | The main table: money, players, ratings and design features for every ball game found |
| `reviews.csv` | review | Review text with a positive/negative/neutral label, for training a model |
| `catalogue_50_enriched.csv` | game in the original 50-game catalogue | Your catalogue, plus links to its store listings and their numbers |
| `country_ratings.csv` | App Store game × country | Where each iOS game's ratings come from (stand-in for player region) |
| `play_language_activity.csv` | Google Play game × language | Reviews per day in each language over the last 30 days (stand-in for player region on Android) |
| `search_interest.csv` | search term × month, 2004–2026 | Google Trends interest, all terms on one scale |
| `published_figures.csv` | published number | Sales, downloads and revenue figures from the press, publishers and trackers, each with its source |
| `other_titles.csv` | game | Ball games outside the three stores: Nokia-era J2ME games, historical rolling-ball games, itch.io indie games (titles, years, prices only) |
| `steam_games.csv`, `steam_reviews.csv`, `steam_reviews_ucsd.csv` | — | Intermediate Steam files used to build the tables above |

## `games.csv` columns

| Column | Meaning | Source / caveat |
|---|---|---|
| `platform` | Steam (PC), Google Play (Android) or App Store (iOS) | |
| `store_id` | Steam app id, Play package name or Apple track id | |
| `title`, `developer`, `url` | | store page |
| `release_date`, `release_year`, `years_on_market` | | store page |
| `price_usd`, `is_free` | price on the collection day | Steam prices may include a sale discount on that day |
| `has_iap`, `has_ads`, `iap_price_range` | in-app purchases, ads, IAP price range | Google Play only |
| `installs_low`, `installs_high`, `installs_kind` | how many people have the game | Play: Google's install count. Steam: owner range estimated by SteamSpy-style modelling. Apple publishes none |
| `rating_count` | number of ratings | Play hides it for small apps |
| `rating_score_100` | rating on a 0–100 scale | Play/iOS: stars × 20. Steam: % of reviews that recommend |
| `stars_5` | average stars | Play / iOS |
| `share_1star` … `share_5star` | share of ratings at each star level | Play only |
| `text_review_count` | written reviews (not just star ratings) | Play only |
| `est_revenue_low_usd`, `est_revenue_high_usd` | owners × price on collection day | **Rough estimate**: ignores discounts, refunds, regional prices, the store's cut and in-game purchases |
| `median_playtime_min` | median minutes played per owner | Steam |
| `metacritic_score`, `language_count`, `content_rating` | | store page |
| `genres`, `tags`, `description` (first 600 characters) | | store page |
| `ratings_per_year` | rating_count ÷ years on market | measure of sustained popularity |
| `ball_game_category` | A: Ball platformer · B: Rolling ball · C: Ball physics & bouncing · D: Hybrid / rhythm & transform · Adjacent: marble shooter · Adjacent: boulder action · Unclassified | **Keyword rules** over title, tags and description (see `build_catalogue.py`) plus hand labels for the most-rated listings. Checked by hand: about 2 in 3 correct on a random sample (mostly tiny apps); the 60 most-rated listings (92% of all ratings) are hand-checked. Treat small games' labels as approximate |
| `control_type` | tilt, swipe/drag, tap, direct (keys/controller), unspecified | keywords in the store description |
| `mentions_physics`, `mentions_bounce`, `mentions_roll` | description mentions physics, bouncing/jumping, rolling | keywords in the store description |
| `levels_advertised` | number of levels the description claims | only when the description states it |
| `has_level_editor`, `has_leaderboards`, `has_multiplayer`, `has_checkpoints`, `has_skins`, `has_boss_fights`, `works_offline` | design features | keywords in the store description; `False` can mean "not mentioned" |

## `reviews.csv` columns

`platform`, `store_id`, `title`, `ball_game_category`, `review_id`, `stars` (1–5, Play/iOS), `recommended` (Steam),
`sentiment` (positive = 4–5 stars or recommended; negative = 1–2 stars or not recommended; neutral = 3 stars; unknown = no label),
`text`, `date`, `helpful_votes`, `hours_played` (Steam, UCSD), `app_version`, `country` (iOS), `has_dev_reply` (Play), `source`.
Reviewer names and ids were never stored.

**How the reviews were sampled (affects any model):**
- Google Play: the newest 10,000 English reviews per game (fewer if the game has fewer), so popular games are capped and recent reviews dominate.
- App Store: Apple's feed returns at most the 500 most recent reviews per country; 10 countries for the 30 most-rated iOS games.
- Steam: only from two public research snapshots (Zenodo 2017, UCSD 2010–2018). Steam's live review endpoint redirected every
  request during collection, so newer Steam reviews are missing.
- Google Play top 30 games also have up to 10,000 "most relevant" reviews, which reach further back in time than the newest ones.
- Store reviews come from people who chose to write one. They lean towards strong opinions and are not a representative survey.
- Mobile reviews are short (median 33 characters). About 137k reviews repeat another review's exact text for the same game
  ("Good", "Nice game"): different people, same words. Drop them if a model should not see repeats.
- Stars are noisy as labels: some people write "nice" and give 1 star.
- App Store reviews come from 10 country stores, so some are not in English.
- `reviews.csv` is 235 MB and is excluded from git; run `scripts/finalize.py` to rebuild it.

## Player demographics

No public source gives age or gender for individual games. Two stand-ins for **where** people play:
- `country_ratings.csv`: each iOS game's rating count in 30 country stores.
- `play_language_activity.csv`: reviews per day in 14 languages on Google Play. Language is not country; Indian players, for example,
  mostly review in English, so Hindi undercounts India.

## Rebuilding

From `business/`, with `.venv` active (`pip install google-play-scraper pandas pytrends`):

1. Downloads into `data/raw/`: Zenodo `https://zenodo.org/records/1000885/files/steam.csv.bz2` → `raw/zenodo/`;
   Hugging Face `FronkonGames/steam-games-dataset` `games.csv` → `raw/hf/`;
   UCSD `steam_reviews.json.gz` and `australian_user_reviews.json.gz` from `mcauleylab.ucsd.edu/public_datasets/data/steam/` → `raw/ucsd/`;
   `https://wakkatobakka.github.io/j2me-archive/data/catalog.csv` → `raw/history/j2me_catalog.csv`;
   `https://rollingballs.neocities.org/list` → `raw/history/rollingballs_list.html` (`history.py` fetches itch.io itself).
2. `steam_catalogue.py`, `play_discover.py`, `appstore.py`, `trends.py`
3. `build_catalogue.py` (needed by the next step)
4. `play_reviews.py 10000 <stop HH:MM>` and `play_reviews.py 10000 <stop HH:MM> relevant 30`, `play_languages.py`,
   `steam_reviews.py`, `steam_reviews_ucsd.py`, `history.py`
5. `build_catalogue.py`, `enrich_user_csv.py`, `finalize.py`

`published_figures.csv` was compiled by hand from web sources; every row carries its URL.
Store data changes daily, so a rebuild will not match these numbers exactly.

## Model outputs

`model_outputs/` holds what the HPC models produced from these files: review sentiment, review themes (what players praise and
complain about) and a game-success model. See `../hpc/README.md`.

## Money

- Real development budgets: not published for any game in this set (Marble Madness's 10-month development time is the closest).
- Real revenue and sales: only the handful in `published_figures.csv`, each marked with its source and a confidence level.
- Everything else is an estimate: Steam `est_revenue_*`, Steam owner ranges and Google Play installs (installs are not sales; most mobile games are free).
