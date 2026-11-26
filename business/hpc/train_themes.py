"""Find what players talk about in ball-game reviews, and whether each point is praise or a complaint.

Each review is split into clauses (sentence breaks and words like "but" separate praise from complaints). Every distinct clause is
embedded with a multilingual sentence model and k-means groups the clauses into K themes. The fine-tuned sentiment model
(train_sentiment.py) then scores each clause, so one review can praise the levels and complain about the ads.
Runs on the HPC (Slurm GPU job). SMOKE=1 runs a tiny version for checking the code.

In:  data/reviews.csv.gz, models/sentiment/
Out: out/clusters.csv (keywords + example clauses, for naming the themes by hand), out/clauses.csv.gz (review row -> clause),
     out/clause_texts.csv.gz (clause -> theme, sentiment), models/themes/ (centroids + settings)
"""
import json, os
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from scipy import sparse
from sentence_transformers import SentenceTransformer
from sklearn.cluster import MiniBatchKMeans
from sklearn.feature_extraction.text import CountVectorizer
from transformers import AutoModelForSequenceClassification, AutoTokenizer

EMB = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
SPLIT = r"(?<=[.!?])\s+|\s+(?:but|however|although|though|except)\s+"
LABELS = ["negative", "neutral", "positive"]
ROOT = Path(__file__).resolve().parent
SMOKE = os.environ.get("SMOKE") == "1"
K = 8 if SMOKE else 80
OUT = ROOT / ("out_smoke" if SMOKE else "out")
SENT = ROOT / ("models/sentiment_smoke" if SMOKE else "models/sentiment")
THEMES = ROOT / ("models/themes_smoke" if SMOKE else "models/themes")
OUT.mkdir(exist_ok=True); THEMES.mkdir(parents=True, exist_ok=True)

r = pd.read_csv(ROOT / "data/reviews.csv.gz", usecols=["text"], dtype=str, nrows=5_000 if SMOKE else None)
cl = r.text.str.split(SPLIT, regex=True).explode().str.strip(" .,!?-")  # index stays the review's row number
cl = cl[cl.str.len() >= 3]
clauses = pd.DataFrame({"row": cl.index, "key": cl.str.lower().to_numpy()})
uniq = clauses.key.value_counts()  # distinct clause -> how often it occurs
keys = uniq.index.to_numpy()
clauses["clause_id"] = pd.Index(keys).get_indexer(clauses.key)
assert (clauses.clause_id >= 0).all()
print(f"{len(r):,} reviews -> {len(clauses):,} clauses, {len(keys):,} distinct", flush=True)

emb = SentenceTransformer(EMB, device="cuda").half()
E = emb.encode(list(keys), batch_size=1024, normalize_embeddings=True, convert_to_numpy=True).astype(np.float32)
km = MiniBatchKMeans(n_clusters=K, batch_size=16384, n_init=3, max_iter=200, random_state=0).fit(E)
cluster = km.labels_
print("clustered", flush=True)

# keywords per theme: class-based TF-IDF (words common in this theme and rare in the others), counted by occurrences
cv = CountVectorizer(stop_words="english", ngram_range=(1, 2), min_df=2 if SMOKE else 20, token_pattern=r"(?u)\b[^\W\d_]{2,}\b")
X = cv.fit_transform(keys)
W = sparse.csr_matrix((uniq.to_numpy().astype(float), (cluster, np.arange(len(keys)))), shape=(K, len(keys)))
T = (W @ X).toarray()
ctfidf = (T / np.maximum(T.sum(1, keepdims=True), 1)) * np.log(1 + T.sum(1).mean() / np.maximum(T.sum(0), 1))
vocab = cv.get_feature_names_out()

# clause sentiment with the fine-tuned model
tok = AutoTokenizer.from_pretrained(SENT)
sm = AutoModelForSequenceClassification.from_pretrained(SENT).to("cuda").eval()
order = np.argsort([len(k) for k in keys])
parts = []
with torch.no_grad():
    for i in range(0, len(keys), 1024):
        enc = tok([keys[j] for j in order[i:i + 1024]], truncation=True, max_length=64, padding=True, return_tensors="pt").to("cuda")
        with torch.autocast("cuda", dtype=torch.bfloat16):
            parts.append(torch.softmax(sm(**enc).logits.float(), -1).cpu().numpy())
P = np.empty((len(keys), 3), dtype=np.float32)
P[order] = np.concatenate(parts)
print("clauses scored", flush=True)

texts = pd.DataFrame({"clause_id": np.arange(len(keys)), "text": keys, "occurrences": uniq.to_numpy(), "cluster": cluster,
                      "model_sentiment": np.array(LABELS)[P.argmax(1)], **{f"p_{l}": P[:, i].round(3) for i, l in enumerate(LABELS)}})
texts.to_csv(OUT / "clause_texts.csv.gz", index=False)
clauses[["row", "clause_id"]].to_csv(OUT / "clauses.csv.gz", index=False)

rows, words = [], np.array([len(k.split()) for k in keys])
cent = km.cluster_centers_ / np.linalg.norm(km.cluster_centers_, axis=1, keepdims=True)
review_count = clauses.assign(cluster=cluster[clauses.clause_id]).groupby("cluster").row.nunique()
for c in range(K):
    m = np.where(cluster == c)[0]
    occ = uniq.to_numpy()[m]
    share = pd.Series(occ, index=texts.model_sentiment.to_numpy()[m]).groupby(level=0).sum() / occ.sum()
    long_ = m[words[m] >= 4]
    central = long_[np.argsort(-(E[long_] @ cent[c]))[:8]]
    rows.append({"cluster": c, "clause_occurrences": int(occ.sum()), "distinct_clauses": len(m), "reviews": int(review_count.get(c, 0)),
                 **{f"share_{l}": round(float(share.get(l, 0)), 3) for l in LABELS},
                 "keywords": ", ".join(vocab[np.argsort(-ctfidf[c])[:15]]),
                 "examples_central": " | ".join(keys[central]), "examples_frequent": " | ".join(keys[m[np.argsort(-occ)[:10]]])})
pd.DataFrame(rows).sort_values("clause_occurrences", ascending=False).to_csv(OUT / "clusters.csv", index=False)
np.save(THEMES / "centroids.npy", km.cluster_centers_)
json.dump({"embedding_model": EMB, "k": K, "clause_split_regex": SPLIT, "min_clause_chars": 3}, open(THEMES / "config.json", "w"), indent=1)
print("done", K, "themes", flush=True)
