"""Debug: where does the gold code chunk rank in FAISS, BM25 and RRF?
Run from the project folder:  python -m checks.debug_search"""

from search import get_loaded, dense_search, bm25_search, rrf
from config import SEARCH_CANDIDATES

# (question, gold file, gold start line, gold end line)
CASES = [
    ("Where does the ball pop when it falls out of the level?", "src/Ball.lua", 115, 119),
    ("How does spike damage work, and add a shield that halves it?", "src/GameLevel.lua", 359, 372),
    ("How does spike damage work, and add a shield that halves it?", "src/Ball.lua", 127, 149),
]


def is_gold(m, gold_file, start, end):
    return m["file"] == gold_file and m["start_line"] <= end and m["end_line"] >= start


def show(store, name, ranked, gold_file, start, end):
    top = []
    for i in ranked[:5]:
        m = store["chunks"][i]["metadata"]
        top.append(m["file"].split("/")[-1] + " " + (m["symbol"] or m["kind"]))
    gold_rank = "not found"
    for rank in range(len(ranked)):
        if is_gold(store["chunks"][ranked[rank]]["metadata"], gold_file, start, end):
            gold_rank = rank + 1
            break
    print("  ", name, "| gold rank:", gold_rank, "| top 5:", top)


store = get_loaded("code")
embedder = get_loaded("embedder")
for question, gold_file, start, end in CASES:
    print("\n" + question, "->", gold_file, start, "-", end)
    dense = dense_search(store, embedder.embed_query(question), 100)
    words = bm25_search(store, question, 100)
    merged = rrf([dense[:SEARCH_CANDIDATES], words[:SEARCH_CANDIDATES]])
    show(store, "FAISS", dense, gold_file, start, end)
    show(store, "BM25 ", words, gold_file, start, end)
    show(store, "RRF  ", merged, gold_file, start, end)
