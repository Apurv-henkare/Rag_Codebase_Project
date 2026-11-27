"""Fine-tune a multilingual sentiment model on ball-game reviews, then score every review.

Labels come from the stores: 4-5 stars or "recommended" = positive, 3 = neutral, 1-2 or "not recommended" = negative.
The split is by game, so test scores are for games the model never saw during training.
Runs on the HPC (Slurm GPU job). SMOKE=1 runs a tiny version for checking the code.

In:  data/reviews.csv.gz
Out: models/sentiment/ (weights), out/sentiment_metrics.json, out/review_sentiment.csv.gz
"""
import json, os, time
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit
from transformers import AutoModelForSequenceClassification, AutoTokenizer

BASE = "cardiffnlp/twitter-xlm-roberta-base-sentiment"  # multilingual, already outputs negative/neutral/positive
LABELS = ["negative", "neutral", "positive"]
ROOT = Path(__file__).resolve().parent
SMOKE = os.environ.get("SMOKE") == "1"
MAX_TRAIN, BS, LR = (2_000, 32, 2e-5) if SMOKE else (400_000, 64, 2e-5)
OUT = ROOT / ("out_smoke" if SMOKE else "out")
OUT.mkdir(exist_ok=True)
torch.manual_seed(0)
dev = "cuda"

r = pd.read_csv(ROOT / "data/reviews.csv.gz", usecols=["platform", "title", "sentiment", "text"], dtype=str,
                nrows=60_000 if SMOKE else None)
r["key"] = r.text.str.lower().str.strip()
r["group"] = r.title.str.lower().str.replace(r"[^a-z0-9]+", " ", regex=True).str.strip()  # same game on iOS and Play = one group
lab = r[r.sentiment.isin(LABELS)].assign(y=lambda d: d.sentiment.map({l: i for i, l in enumerate(LABELS)}))

tr, te = next(GroupShuffleSplit(n_splits=1, test_size=0.15, random_state=0).split(lab, groups=lab.group))


def dedupe(df):  # one example per distinct text, majority label ("Good" x 14,000 becomes one example)
    best = df.groupby(["key", "y"]).size().reset_index(name="n").sort_values("n", ascending=False).drop_duplicates("key")
    return best.assign(text=best.key.map(df.drop_duplicates("key").set_index("key").text))[["key", "text", "y"]]


train = dedupe(lab.iloc[tr]).sample(frac=1, random_state=0).head(MAX_TRAIN)
test = dedupe(lab.iloc[te])
test = test[~test.key.isin(set(dedupe(lab.iloc[tr]).key))]  # texts also seen in training ("good") would flatter the score
assert len(set(lab.iloc[tr].group) & set(lab.iloc[te].group)) == 0
print(f"train {len(train):,} texts | test {len(test):,} texts from {lab.iloc[te].group.nunique()} unseen games", flush=True)

tok = AutoTokenizer.from_pretrained(BASE)
model = AutoModelForSequenceClassification.from_pretrained(BASE).to(dev)


def encode(texts):
    return tok(texts, truncation=True, max_length=128, padding=True, return_tensors="pt").to(dev)


@torch.no_grad()
def predict(texts, bs=512):
    model.eval()
    order = np.argsort([len(t) for t in texts])  # length-sorted batches waste less padding
    parts = []
    for i in range(0, len(texts), bs):
        with torch.autocast("cuda", dtype=torch.bfloat16):
            logits = model(**encode([texts[j] for j in order[i:i + bs]])).logits
        parts.append(torch.softmax(logits.float(), -1).cpu().numpy())
    p = np.empty((len(texts), 3), dtype=np.float32)
    p[order] = np.concatenate(parts)
    return p


def scores(p):
    y, yhat = test.y.to_numpy(), p.argmax(1)
    return {"macro_f1": round(f1_score(y, yhat, average="macro"), 4), "accuracy": round(float((y == yhat).mean()), 4),
            "per_class": classification_report(y, yhat, target_names=LABELS, output_dict=True, zero_division=0),
            "confusion_rows_true_cols_pred": confusion_matrix(y, yhat, labels=[0, 1, 2]).tolist()}


before = scores(predict(test.text.tolist()))
print("before fine-tuning:", before["macro_f1"], before["accuracy"], flush=True)

counts = np.bincount(train.y, minlength=3)
loss_fn = torch.nn.CrossEntropyLoss(weight=torch.tensor((counts.sum() / (3 * counts)) ** 0.5, dtype=torch.float, device=dev))
opt = torch.optim.AdamW(model.parameters(), lr=LR, weight_decay=0.01)
steps = len(train) // BS
sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=LR, total_steps=steps, pct_start=0.06, anneal_strategy="linear")
texts, ys = train.text.tolist(), torch.tensor(train.y.to_numpy(), device=dev)
model.train()
t0 = time.time()
for s in range(steps):  # one pass over the data
    b = slice(s * BS, (s + 1) * BS)
    with torch.autocast("cuda", dtype=torch.bfloat16):
        logits = model(**encode(texts[b])).logits
    loss = loss_fn(logits.float(), ys[b])
    loss.backward()
    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
    opt.step(); sched.step(); opt.zero_grad()
    if s % 500 == 0:
        print(f"step {s}/{steps} loss {loss.item():.3f} {time.time() - t0:.0f}s", flush=True)

after = scores(predict(test.text.tolist()))
print("after fine-tuning:", after["macro_f1"], after["accuracy"], flush=True)
model.save_pretrained(ROOT / ("models/sentiment_smoke" if SMOKE else "models/sentiment"))
tok.save_pretrained(ROOT / ("models/sentiment_smoke" if SMOKE else "models/sentiment"))
json.dump({"base_model": BASE, "train_texts": len(train), "test_texts": len(test),
           "test_games": int(lab.iloc[te].group.nunique()), "train_minutes": round((time.time() - t0) / 60, 1),
           "note": "test = games never seen in training; labels are store stars, which are themselves noisy",
           "before_fine_tuning": before, "after_fine_tuning": after}, open(OUT / "sentiment_metrics.json", "w"), indent=1)

# score every review once per distinct text
uniq = r.drop_duplicates("key")
p = pd.DataFrame(predict(uniq.text.tolist()), columns=[f"p_{l}" for l in LABELS], index=uniq.key).round(3)
res = r[["key"]].join(p, on="key").drop(columns="key")
res.insert(0, "model_sentiment", np.array(LABELS)[res.to_numpy().argmax(1)])
res.insert(0, "row", np.arange(len(r)))  # row number in reviews.csv
res.to_csv(OUT / "review_sentiment.csv.gz", index=False)
print("scored", len(res), "reviews", flush=True)
