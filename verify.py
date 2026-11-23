"""Phase 4c: Python checks (no AI) + the source list and exact code snippets."""

import json
import re
from config import CHUNKS_DIR, CODE_DIR, NOT_FOUND
from answer import source_label
from build_symbols import is_name
from code_check import get_lua_blocks

symbols = json.loads((CHUNKS_DIR / "symbols.json").read_text(encoding="utf-8"))
KNOWN_NAMES = set(symbols["game"])
KNOWN_NAMES.update(symbols["love"])


def cited_numbers(answer):
    """[1], [2][3] in the answer -> [1, 2, 3] (each number once, in order)."""
    numbers = []
    for n in re.findall(r"\[(\d+)\]", answer):
        if int(n) not in numbers:
            numbers.append(int(n))
    return numbers


def check_answer(answer, chunks):
    """Return a list of problems. [] means the answer passed."""
    if answer.strip() == NOT_FOUND:
        return []
    problems = []

    # 1. citations
    numbers = cited_numbers(answer)
    if len(numbers) == 0:
        problems.append("The answer has no [n] citations.")
    for n in numbers:
        if n < 1 or n > len(chunks):
            problems.append("Citation [" + str(n) + "] does not exist: there are only "
                            + str(len(chunks)) + " sources.")

    # 2. names in `backticks` must be real
    sources_text = ""
    for chunk in chunks:
        sources_text = sources_text + chunk["text"] + "\n"
    for block in get_lua_blocks(answer):
        sources_text = sources_text + block + "\n"     # new names from the new code: checked by code_check.py
    for name in re.findall(r"`([^`\n]+)`", answer):
        name = name.split("(")[0].strip()            # `Ball:moveX(dt)` -> Ball:moveX
        if not is_name(name):
            continue                                 # not a single name, e.g. `x > 0`
        if name not in KNOWN_NAMES and name not in sources_text:
            problems.append("`" + name + "` is not in the sources or the code.")
    return problems


def build_sources(answer, chunks):
    """Source list for the cited chunks, from metadata: ['[1] 📄 src/Ball.lua:242-277', ...]."""
    lines = []
    for n in sorted(cited_numbers(answer)):
        if 1 <= n <= len(chunks):
            m = chunks[n - 1]["metadata"]
            if m["source"] == "code":
                icon = "📄"
            else:
                icon = "📘"
            lines.append("[" + str(n) + "] " + icon + " " + source_label(m))
    return lines


def get_snippet(chunk):
    """The exact lines from the file on disk. None if the file changed since indexing."""
    m = chunk["metadata"]
    path = CODE_DIR / m["file"]
    if not path.exists():
        return None
    lines = path.read_text(encoding="utf-8").splitlines()
    code = "\n".join(lines[m["start_line"] - 1:m["end_line"]])
    if not chunk["text"].endswith(code):             # chunk text = title line + these exact lines
        return None
    return code


# ---- Self-check: "python verify.py" (0 API calls: everything is cached) ----
if __name__ == "__main__":
    from planner import make_plan
    from search import search
    from answer import write_answer

    question = "What happens when the ball hits a wall?"
    plan = make_plan(question)
    chunks = search(question, plan.search_in)
    answer = write_answer(question, plan.answer_type, chunks)

    print("problems:", check_answer(answer, chunks))
    print("sources:", build_sources(answer, chunks))
    print("snippet [1]:\n" + str(get_snippet(chunks[0]))[:200])

    fake = "The ball calls `Ball:takeDamage` when it hits a wall [7]."
    print("\nfake answer problems:", check_answer(fake, chunks))
