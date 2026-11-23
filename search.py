"""Step 3: hybrid search = FAISS (meaning) + BM25 (exact words), merged with RRF."""

import re
import json
import faiss
import numpy as np
from rank_bm25 import BM25Okapi
from build_index import get_embedder, load_chunks
from config import CHUNKS_DIR, INDEX_DIR, TOP_K, TOP_K_PER_SOURCE, RRF_K, SEARCH_CANDIDATES


def simple_stem(word):
    """Tiny stemmer: 'spikes' -> 'spike', 'falls' -> 'fall' (leaves 'class', 'is' alone)."""
    if len(word) > 3 and word.endswith("s") and not word.endswith("ss"):
        return word[:-1]
    return word


def tokenize(text):
    """Code-aware words, e.g. 'love.graphics.newImage' ->
    ['love.graphics.newimage', 'love', 'graphics', 'newimage', 'new', 'image']."""
    tokens = []
    for name in re.findall(r"[A-Za-z0-9_.:]+", text):
        name = name.strip(".:")                       # drop a full stop at the end of a sentence
        if name == "":
            continue
        tokens.append(name.lower())                   # 1. the full name, kept whole

        for segment in re.split(r"[.:]", name):       # 2. each part between dots / colons
            if segment == "":
                continue
            if segment != name:
                tokens.append(segment.lower())
            for part in re.findall(r"[A-Z]?[a-z]+|[A-Z]+|[0-9]+", segment):
                tokens.append(simple_stem(part.lower()))   # 3. pieces split at _ and camelCase
    return tokens


def load_source(source):
    """Load one source ('code' or 'docs'): its chunks, FAISS index and BM25 index."""
    chunks = load_chunks(source)
    index = faiss.read_index(str(INDEX_DIR / (source + ".faiss")))

    tokenized = []
    for chunk in chunks:
        tokenized.append(tokenize(chunk["text"]))
    bm25 = BM25Okapi(tokenized)

    return {"chunks": chunks, "faiss": index, "bm25": bm25}


def dense_search(store, query_vector, k):
    """FAISS: positions of the k chunks closest in meaning, best first."""
    scores, ids = store["faiss"].search(np.array([query_vector], dtype="float32"), k)
    positions = []
    for i in ids[0]:
        positions.append(int(i))
    return positions


def bm25_search(store, query, k):
    """BM25: positions of the k chunks with the best word match, best first."""
    scores = store["bm25"].get_scores(tokenize(query))
    best = np.argsort(scores)[::-1][:k]
    positions = []
    for i in best:
        positions.append(int(i))
    return positions


def rrf(ranked_lists):
    """Merge ranked lists: each chunk gets 1 / (RRF_K + rank) from every list it is in."""
    scores = {}
    for ranked in ranked_lists:
        for rank in range(len(ranked)):
            position = ranked[rank]
            if position not in scores:
                scores[position] = 0
            scores[position] = scores[position] + 1 / (RRF_K + rank + 1)
    return sorted(scores, key=scores.get, reverse=True)


loaded = {}

def get_loaded(name):
    """Load the embedder, the Love2D name list or a source ('code' / 'docs') only once, then reuse it."""
    if name not in loaded:
        if name == "embedder":
            loaded[name] = get_embedder()
        elif name == "love_names":
            symbols = json.loads((CHUNKS_DIR / "symbols.json").read_text(encoding="utf-8"))
            loaded[name] = set(symbols["love"])
        else:
            loaded[name] = load_source(name)
    return loaded[name]


def find_love_names(question):
    """Real Love2D names written in the question, e.g. 'love.graphics.rectangle', 'Source:play'."""
    found = []
    for name in re.findall(r"[A-Za-z0-9_.:]+", question):
        name = name.strip(".:")
        if name in get_loaded("love_names") and name not in found:
            found.append(name)
    return found


def search(query, search_in="code", k=TOP_K, extra_query=""):
    """Hybrid search. Returns chunks (dicts with text + metadata), best first.
    extra_query = a second way to say the question (the planner's keywords): searched too, merged by RRF."""
    if search_in == "both":
        return (search(query, "code", TOP_K_PER_SOURCE, extra_query)
                + search(query, "docs", TOP_K_PER_SOURCE, extra_query))

    queries = [query]
    if extra_query != "" and extra_query != query:
        queries.append(extra_query)

    if search_in == "docs":
        names = find_love_names(query)
        if names:
            queries = [" ".join(names)]    # search the docs only for the Love2D names asked about

    store = get_loaded(search_in)
    lists = []
    for q in queries:
        query_vector = get_loaded("embedder").embed_query(q)
        lists.append(dense_search(store, query_vector, SEARCH_CANDIDATES))
        lists.append(bm25_search(store, q, SEARCH_CANDIDATES))
    merged = rrf(lists)

    results = []
    for position in merged[:k]:
        results.append(store["chunks"][position])
    return results


# ---- Self-check: "python search.py" ----
if __name__ == "__main__":
    for question, where in [("What happens when the ball hits a wall?", "code"),
                            ("Explain love.graphics.rectangle and show where the game uses it.", "both")]:
        print("\n" + question)
        for chunk in search(question, where):
            m = chunk["metadata"]
            if m["source"] == "code":
                print("   code:", m["file"], m["start_line"], m["symbol"])
            else:
                print("   docs:", m["pdf"], "p." + str(m["page"]), m["title"])
