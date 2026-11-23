"""Phase 4d: the whole RAG pipeline in one function: ask(question)."""

import re
from planner import make_plan
from search import search
from answer import write_answer, source_label
from verify import check_answer, build_sources, cited_numbers, get_snippet
from code_check import check_code
from config import NOT_FOUND, NOT_RELIABLE, OUT_OF_SCOPE, HELP_TEXT, MAX_RETRIES, MAX_SNIPPETS_SHOWN


def get_snippets(answer, chunks):
    """What each cited source says, at most MAX_SNIPPETS_SHOWN: (label, text, language).
    Code: the exact lines from disk. Docs: the chunk text from the PDF."""
    snippets = []
    for n in sorted(cited_numbers(answer)):
        if n < 1 or n > len(chunks):
            continue
        m = chunks[n - 1]["metadata"]
        label = "[" + str(n) + "] " + source_label(m)
        if m["source"] == "docs":
            snippets.append((label, chunks[n - 1]["text"], "text"))
        elif m["kind"] == "level_meta":
            continue                                   # level grids get no snippet
        else:
            code = get_snippet(chunks[n - 1])
            if code is None:
                code = "(this file changed since indexing - run rebuild.py)"
            snippets.append((label, code, "lua"))
        if len(snippets) == MAX_SNIPPETS_SHOWN:
            break
    return snippets


def remove_code_blocks(answer):
    """Drop ```...``` blocks. Except for write_code, code is only shown from the file on disk."""
    return re.sub(r"```.*?```", "", answer, flags=re.DOTALL).strip()


def run_checks(answer, chunks, answer_type):
    """All Python checks for one answer. Returns (problems, uses)."""
    problems = check_answer(answer, chunks)
    uses = []
    if answer_type == "write_code" and answer.strip() != NOT_FOUND:
        code_problems, uses = check_code(answer)
        problems = problems + code_problems
    return problems, uses


def ask(question):
    """Answer one message. Returns a dict: plan, answer, sources, snippets, problems."""
    result = {"plan": make_plan(question), "answer": "", "sources": [], "snippets": [],
              "uses": [], "problems": []}
    plan = result["plan"]

    if plan.answer_type == "help":
        result["answer"] = HELP_TEXT
        return result
    if plan.answer_type == "out_of_scope":
        result["answer"] = OUT_OF_SCOPE
        return result

    answer_question = question
    if plan.out_of_scope_parts:
        answer_question = (question + "\n(Answer only the Inflate part. Ignore: "
                           + ", ".join(plan.out_of_scope_parts) + ")")

    chunks = search(question, plan.search_in, extra_query=plan.search_query)   # question + planner keywords
    answer = write_answer(answer_question, plan.answer_type, chunks)
    problems, uses = run_checks(answer, chunks, plan.answer_type)

    tries = 0
    while problems and tries < MAX_RETRIES:            # one retry, with the problems as feedback
        tries = tries + 1
        feedback = ("Your previous answer failed these checks. Write it again and fix them:\n- "
                    + "\n- ".join(problems))
        answer = write_answer(answer_question, plan.answer_type, chunks, feedback)
        problems, uses = run_checks(answer, chunks, plan.answer_type)

    if problems:
        result["answer"] = NOT_RELIABLE
        result["problems"] = problems
        return result

    if plan.answer_type != "write_code":
        answer = remove_code_blocks(answer)

    if plan.out_of_scope_parts:
        answer = answer + "\n\nSkipped: " + ", ".join(plan.out_of_scope_parts) + ". " + OUT_OF_SCOPE

    result["answer"] = answer
    result["sources"] = build_sources(answer, chunks)
    result["snippets"] = get_snippets(answer, chunks)
    result["uses"] = uses
    return result


def print_result(result):
    """Show a result in the terminal."""
    print(result["answer"])
    if result["sources"]:
        print("\nSources:")
        for line in result["sources"]:
            print("  " + line)
    if result["uses"]:
        print("\nUses:")
        for line in result["uses"]:
            print("  " + line)
    for label, code, language in result["snippets"]:
        print("\n--- " + label + " ---\n" + code)
    if result["problems"]:
        print("\n(failed checks: " + "; ".join(result["problems"]) + ")")


# ---- Try it: "python rag.py" (about 6 new API calls the first time) ----
if __name__ == "__main__":
    for question in ["Add a bounce sound when the ball hits a wall.",
                     "How does spike damage work, and add a shield that halves it?",
                     "Make the small ball jump a bit higher."]:
        print("\n" + "=" * 70 + "\n" + question + "\n" + "=" * 70)
        print_result(ask(question))
