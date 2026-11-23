"""Phase 6.4: baseline = plain Gemini, no search. Same dev questions, same fact check as eval_answers.py."""

import json
from langchain_core.prompts import ChatPromptTemplate
from langchain_google_genai import ChatGoogleGenerativeAI
from config import EVAL_DIR, GEMINI_API_KEY, GEMINI_MODEL, TEMPERATURE, GEMINI_TIMEOUT, GEMINI_MAX_RETRIES
from cache import get_cached, save_cached
from eval_answers import count_found, SPLIT
from code_check import check_code

PROMPT = ChatPromptTemplate.from_messages([
    ("system", "You answer questions about Inflate, a 2D platformer game written in Lua "
               "with an in-house game engine."),
    ("human", "{question}"),
])


def plain_answer(question):
    """One Gemini call with only the question: no sources (0 calls if cached)."""
    prompt_text = PROMPT.format(question=question)
    saved = get_cached(GEMINI_MODEL, prompt_text)
    if saved is not None:
        return saved
    llm = ChatGoogleGenerativeAI(model=GEMINI_MODEL, temperature=TEMPERATURE,
                                 google_api_key=GEMINI_API_KEY,
                                 timeout=GEMINI_TIMEOUT, max_retries=GEMINI_MAX_RETRIES)
    answer = (PROMPT | llm).invoke({"question": question}).text
    save_cached(GEMINI_MODEL, prompt_text, answer)
    return answer


ours = {}
for s in json.loads((EVAL_DIR / ("results_" + SPLIT + ".json")).read_text(encoding="utf-8")):
    ours[s["id"]] = s

questions = json.loads((EVAL_DIR / "test_set.json").read_text(encoding="utf-8"))
plain_passed = 0
ours_passed = 0
total = 0
for q in questions:
    words = q.get("must_mention", []) + q.get("must_use", [])
    if q["split"] != SPLIT or len(words) == 0:
        continue                                    # o1, h1: fixed replies, not comparable
    total = total + 1
    answer = plain_answer(q["question"])
    found = count_found(words, answer)
    if found == len(words):
        plain_passed = plain_passed + 1
    if ours[q["id"]]["passed"]:
        ours_passed = ours_passed + 1
    line = q["id"] + " | plain: " + str(found) + "/" + str(len(words)) + " | ours: " + str(ours[q["id"]]["facts"]) + "/" + str(len(words))
    if q["expected_type"] == "write_code":
        problems, uses = check_code(answer)
        line = line + " | plain code problems: " + str(len(problems))
    print(line)

print("\nAll facts found: plain Gemini", plain_passed, "/", total, "| ours", ours_passed, "/", total)
