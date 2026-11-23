"""Phase 3 check: how often does search find the gold location? (dev questions only)"""

import json
from search import search
from planner import make_plan
from config import EVAL_DIR

USE_PLANNER = True    # True = search with the question AND the planner's search_query, False = question only


def is_match(metadata, gold):
    """True if a retrieved chunk is at the gold location."""
    if "pdf" in gold:
        return metadata.get("title") == gold["title"]       # any chunk of the right wiki page
    if metadata.get("file") != gold["file"]:
        return False
    if gold["lines"] is None:
        return True
    return metadata["start_line"] <= gold["lines"][1] and metadata["end_line"] >= gold["lines"][0]


questions = json.loads((EVAL_DIR / "test_set.json").read_text(encoding="utf-8"))
hits = 0
total = 0
reciprocal_sum = 0

for q in questions:
    if q["split"] != "dev" or len(q["gold"]) == 0:
        continue
    total = total + 1

    need_code = False
    need_docs = False
    for gold in q["gold"]:
        if "pdf" in gold:
            need_docs = True
        else:
            need_code = True

    query = ""
    if USE_PLANNER:
        query = make_plan(q["question"]).search_query
    results = search(q["question"], q["search_in"], extra_query=query)
    found_code = False
    found_docs = False
    first_rank = 0
    for rank in range(len(results)):
        for gold in q["gold"]:
            if is_match(results[rank]["metadata"], gold):
                if "pdf" in gold:
                    found_docs = True
                else:
                    found_code = True
                if first_rank == 0:
                    first_rank = rank + 1

    hit = (found_code or not need_code) and (found_docs or not need_docs)
    if hit:
        hits = hits + 1
        reciprocal_sum = reciprocal_sum + 1 / first_rank
        print("HIT ", q["id"], "first at rank", first_rank)
    else:
        print("MISS", q["id"], "| code found:", found_code, "| docs found:", found_docs, "| query:", query)

print("\nHit@k:", hits, "/", total, "| MRR:", round(reciprocal_sum / total, 2))
