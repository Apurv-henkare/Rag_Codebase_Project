"""Phase 6: run every question through ask() and score the answers (dev split by default)."""

import json
from rag import ask
from config import EVAL_DIR, NOT_FOUND, NOT_RELIABLE, OUT_OF_SCOPE, HELP_TEXT

SPLIT = "test"         # "dev" while building; "test" only ONCE at the very end

FIXED = {"NOT_FOUND": NOT_FOUND, "OUT_OF_SCOPE": OUT_OF_SCOPE, "HELP_TEXT": HELP_TEXT}


def count_found(words, text):
    """How many of the words are in the text (not case-sensitive)."""
    found = 0
    for word in words:
        if word.lower() in text.lower():
            found = found + 1
    return found


def score_question(q, result):
    """Scores for one question: right type, reliable, facts found, passed."""
    answer = result["answer"]
    score = {"id": q["id"], "type_ok": result["plan"].answer_type == q["expected_type"],
             "reliable": answer != NOT_RELIABLE, "facts": 0, "facts_total": 0,
             "passed": False, "answer": answer}

    if "expected_answer" in q:                      # o1, h1, c8: must give the fixed reply
        score["passed"] = answer.strip() == FIXED[q["expected_answer"]]
        return score

    words = q.get("must_mention", []) + q.get("must_use", [])
    score["facts"] = count_found(words, answer)
    score["facts_total"] = len(words)
    score["passed"] = score["reliable"] and score["facts"] == score["facts_total"]
    if q.get("expect_out_of_scope_parts") and "Skipped:" not in answer:
        score["passed"] = False                     # o3: must say what it skipped
    return score


# ---- Run: "python eval_answers.py" ----
if __name__ == "__main__":
    questions = json.loads((EVAL_DIR / "test_set.json").read_text(encoding="utf-8"))
    scores = []
    for q in questions:
        if q["split"] != SPLIT:
            continue
        s = score_question(q, ask(q["question"]))
        scores.append(s)
        if s["passed"]:
            status = "PASS"
        else:
            status = "FAIL"
        print(status, q["id"], "| type ok:", s["type_ok"], "| facts:", s["facts"], "/", s["facts_total"])

    passed = 0
    type_ok = 0
    reliable = 0
    for s in scores:
        if s["passed"]:
            passed = passed + 1
        if s["type_ok"]:
            type_ok = type_ok + 1
        if s["reliable"]:
            reliable = reliable + 1

    total = len(scores)
    print("\nPassed:", passed, "/", total, "| right type:", type_ok, "/", total, "| reliable:", reliable, "/", total)

    out = EVAL_DIR / ("results_" + SPLIT + ".json")
    out.write_text(json.dumps(scores, indent=2, ensure_ascii=False), encoding="utf-8")
