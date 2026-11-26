"""Which design choices go with higher-rated and more popular ball games?

Gradient-boosted trees predict a listing's rating and its popularity (ratings per year), each ranked within its own store from things a developer
decides: price, ads, in-app purchases, controls, level count, features, category, platform, release year.
Scored with 5-fold cross-validation grouped by game title, against a "predict the average" baseline. Feature importance is
permutation importance on the held-out folds. These are associations in store data, not proof that a feature causes success.

In:  data/games.csv     Out: out/success_metrics.json, out/dashboard/success_importance.csv, out/dashboard/success_feature_levels.csv
"""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.inspection import permutation_importance
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import GroupKFold

ROOT = Path(__file__).resolve().parent
(ROOT / "out/dashboard").mkdir(parents=True, exist_ok=True)
CAT = ["platform", "ball_game_category", "control_type"]
BOOL = ["is_free", "has_ads", "has_iap", "mentions_physics", "mentions_bounce", "mentions_roll", "has_level_editor",
        "has_leaderboards", "has_multiplayer", "has_checkpoints", "has_skins", "has_boss_fights", "works_offline"]
NUM = ["price_usd", "levels_advertised", "release_year", "language_count"]

g = pd.read_csv(ROOT / "data/games.csv", dtype={"store_id": str})
g = g[g.ball_game_category != "Unclassified"]
X = g[CAT + BOOL + NUM].copy()
for c in CAT:
    X[c] = X[c].astype("category")
for c in BOOL:
    X[c] = X[c].map({True: 1.0, False: 0.0, "True": 1.0, "False": 0.0})  # blank (not published) stays missing
# both targets are ranks within the listing's own store (0-100, 50 = typical): Play counts are ~100x Steam's and Steam's score
# is "% recommend", not stars, so raw values would mostly measure the platform
rating = g.rating_score_100.where(g.rating_count >= 30)  # tiny rating counts are mostly noise
targets = {"rating_percentile_in_store": (rating.groupby(g.platform).rank(pct=True) * 100).round(1),
           "popularity_percentile_in_store": (g.ratings_per_year.groupby(g.platform).rank(pct=True) * 100).round(1)}

metrics, imp_rows = {}, []
for name, y in targets.items():
    ok = y.notna().to_numpy()
    Xi, yi, groups = X[ok], y[ok].to_numpy(), g.title_key[ok].to_numpy()
    pred, base, imps = np.empty(len(yi)), np.empty(len(yi)), []
    for tr, te in GroupKFold(n_splits=5).split(Xi, yi, groups):
        model = HistGradientBoostingRegressor(categorical_features="from_dtype", max_iter=300, learning_rate=0.05,
                                              max_leaf_nodes=15, min_samples_leaf=20, l2_regularization=1.0, random_state=0)
        model.fit(Xi.iloc[tr], yi[tr])
        pred[te], base[te] = model.predict(Xi.iloc[te]), yi[tr].mean()
        imps.append(permutation_importance(model, Xi.iloc[te], yi[te], n_repeats=5, random_state=0, scoring="r2").importances_mean)
    metrics[name] = {"listings": int(ok.sum()), "r2": round(r2_score(yi, pred), 3), "mae": round(mean_absolute_error(yi, pred), 3),
                     "baseline_mae_predict_average": round(mean_absolute_error(yi, base), 3)}
    for f, v in zip(Xi.columns, np.mean(imps, axis=0)):
        imp_rows.append({"target": name, "feature": f, "importance_r2_drop": round(float(v), 4)})
    print(name, metrics[name], flush=True)

pd.DataFrame(imp_rows).sort_values(["target", "importance_r2_drop"], ascending=[True, False]).to_csv(
    ROOT / "out/dashboard/success_importance.csv", index=False)

# plain averages per feature level, to show the direction next to the importance (raw data, no model)
lv = []
t = pd.DataFrame(targets)
for f in CAT + BOOL:
    level_of = g[f].astype(str) if f in CAT else X[f].map({1.0: "yes", 0.0: "no"})
    for level, d in t.groupby(level_of):
        if len(d) >= 10:
            lv.append({"feature": f, "level": level, "listings": len(d),
                       "avg_rating_percentile": round(d.rating_percentile_in_store.mean(), 1),
                       "avg_popularity_percentile": round(d.popularity_percentile_in_store.mean(), 1)})
pd.DataFrame(lv).to_csv(ROOT / "out/dashboard/success_feature_levels.csv", index=False)
json.dump({**metrics, "note": "5-fold CV grouped by title; associations in store data, not causes"},
          open(ROOT / "out/success_metrics.json", "w"), indent=1)
