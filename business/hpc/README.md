# Models (trained on the Plaksha HPC)

Three models, run as Slurm jobs on plaksha-hpc (working folder `~/ballgames/` there) on 2026-11-26.
Dashboard tables are in `../data/model_outputs/dashboard/`. The weights are in `../models/` (the sentiment weights are 1.1 GB and are not committed to git).

| Model | What it answers | How it was trained | How well it works |
|---|---|---|---|
| Review sentiment (`train_sentiment.py`) | Is a review, or one sentence of it, positive, neutral or negative? Works in other languages too | Fine-tuned `cardiffnlp/twitter-xlm-roberta-base-sentiment` on 400,000 distinct review texts, using store stars as labels. One pass, 9.5 min on a 48 GB slice of an RTX PRO 6000 | Tested on 66,444 reviews from 41 games it never saw. Accuracy went from 70% to 82% and macro F1 from 0.55 to 0.71 (F1 per class: negative 0.84, neutral 0.38, positive 0.90) |
| Review themes (`train_themes.py`) | What do players talk about, and is it praise or a complaint? | Split the 790,541 reviews into 1.38M clauses (939k distinct), embedded them with `paraphrase-multilingual-MiniLM-L12-v2` and grouped them into 80 clusters with k-means. The fine-tuned sentiment model then labels each clause. I named the clusters by hand and merged them into 44 themes (`theme_names.csv`) | Unsupervised, so there is no accuracy score. Named from each cluster's keywords and example sentences (`../data/model_outputs/clusters.csv`) |
| Game success (`train_success.py`) | Which choices on the store page go with better-rated or more popular games? | Gradient-boosted trees over price, ads, in-app purchases, control type, advertised level count, features, category, platform and release year. Both targets are ranked within each store. 5-fold cross-validation, grouped by game | **Weak.** Rating: R² 0.00, i.e. no signal (585 listings). Popularity: R² 0.10 (1,088 listings). Show the plain averages in `success_feature_levels.csv`, not predictions |

## Dashboard tables (`../data/model_outputs/dashboard/`)

A "mention" means one review talking about one theme.

| File | One row per | Shows |
|---|---|---|
| `themes.csv` | theme | Mentions, share positive and negative, example praise and complaint quotes |
| `theme_by_category.csv`, `theme_by_platform.csv`, `theme_by_year.csv` | group × theme | The same counts, split by ball-game category, store or year |
| `theme_by_country.csv` | country × theme | App Store reviews only (10 country stores) |
| `theme_by_game.csv` | game × theme | Games with 200 or more reviews. `lift_vs_category` above 1 means players talk about this theme more than they do for other games in the same category |
| `game_sentiment.csv` | game | Positive share from stars and from the text model, most praised and most criticised specific theme |
| `stars_vs_text.csv` | star label × text label | How often the stars and the text disagree |
| `success_importance.csv`, `success_feature_levels.csv` | feature (× level) | Output of the game-success model, plus plain averages per feature level |
| `../review_sentiment.csv.gz` | review (row order of `data/processed/reviews.csv`) | Model label and probabilities for every review (not in git) |

## Limits

- The labels are store stars, and stars are noisy. The model reads 12% of 1–2-star reviews as positive (`stars_vs_text.csv`). Neutral is weak (F1 0.38) because 3-star reviews are usually mixed.
- Themes split reviews into clauses at sentence ends and at "but", "however" and "although". K-means puts every clause into some cluster, so some clauses end up in the wrong theme. A quote must contain one of its theme's keywords, but a few odd quotes remain.
- Theme volumes follow the review sample. The newest 10,000 English Google Play reviews per game dominate, and mobile ad complaints are the biggest single topic.
- Theme counts by country come only from the App Store: 10 countries, the 500 newest reviews per country, for the 30 most-rated iOS games. Country *ratings* (`../data/processed/country_ratings.csv`) cover 30 countries and 521 games.
- The game-success model shows associations, not causes. Its design features are keywords read from store descriptions.

## Re-running

1. On the HPC: `module load python`, then `python3 -m venv --system-site-packages ~/envs/ballgames`, then
   `pip install transformers sentence-transformers scikit-learn pandas pyarrow accelerate sentencepiece protobuf` (PyTorch comes from the module).
2. Download the two Hugging Face models on the login node with `HF_HUB_DISABLE_XET=1`. Xet downloads fail on `/home` with "Bad address". Jobs run with `HF_HUB_OFFLINE=1`.
3. Copy `data/processed/reviews.csv` (gzipped) to `~/ballgames/data/reviews.csv.gz` and `games.csv` to `~/ballgames/data/games.csv`, along with the scripts in this folder.
4. GPU job: `python train_sentiment.py && python train_themes.py` (about 17 min on `--gres=gpu:2g.48gb:1`). `SMOKE=1` runs a tiny version first.
   CPU job: `python train_success.py`. There is no `cpu` partition, so submit to `rtx` without `--gres`.
5. **Cluster numbers change on every run**, so `theme_names.csv` has to be redone by reading the new `out/clusters.csv`.
6. `python aggregate.py` (CPU, about 1 min), then download `out/dashboard/`.
