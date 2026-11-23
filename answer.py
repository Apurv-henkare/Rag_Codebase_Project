"""Phase 4b: write the answer (AI call 2) from the numbered search results."""

from langchain_core.prompts import ChatPromptTemplate
from langchain_google_genai import ChatGoogleGenerativeAI
from config import GEMINI_API_KEY, GEMINI_MODEL, TEMPERATURE, NOT_FOUND, GEMINI_TIMEOUT, GEMINI_MAX_RETRIES
from cache import get_cached, save_cached

INSTRUCTIONS = {
    "explain": "Explain how it works, step by step, in a few short paragraphs.",
    "locate": "List where it is in the code: each place with a short note and its citation.",
    "show_code": "Say in 1-2 sentences what the code does. Do not copy the code: it is shown below your answer.",
    "write_code": "Write two sections. '## How it works now': explain the current code, with citations. "
                  "'## New code': one ```lua block with the WHOLE new or changed function(s), "
                  "in the same style as the sources. If the feature already exists or the request is vague, "
                  "say so and state your assumption.",
}

PROMPT = ChatPromptTemplate.from_messages([
    ("system",
     "You answer questions about Inflate, a 2D platformer game written in Lua with an in-house game engine.\n"
     "Rules:\n"
     "- Use ONLY the numbered sources. Do not use outside knowledge.\n"
     "- After every fact, cite its source like [1] or [2][3].\n"
     "- If the sources do not contain the answer, reply exactly: {not_found}\n"
     "- Names starting with 'love.' can be engine functions (engine documentation) or game functions "
     "(game code). Say which one, based on the sources.\n"
     "- Never invent function, constant or file names.\n"
     "Task: {instruction}"),
    ("human", "Sources:\n{sources}\n\nQuestion: {question}\n{feedback}"),
])


def source_label(metadata):
    """'src/Ball.lua:242-277' for code, '06-modules.pdf p.444' for docs."""
    if metadata["source"] == "code":
        return metadata["file"] + ":" + str(metadata["start_line"]) + "-" + str(metadata["end_line"])
    return metadata["pdf"] + " p." + str(metadata["page"])


def format_sources(chunks):
    """Number the chunks: '[1] label\\ntext', '[2] ...'."""
    parts = []
    for i in range(len(chunks)):
        label = source_label(chunks[i]["metadata"])
        parts.append("[" + str(i + 1) + "] " + label + "\n" + chunks[i]["text"])
    return "\n\n".join(parts)


def write_answer(question, answer_type, chunks, feedback=""):
    """AI call 2 (0 calls if cached): question + numbered chunks -> answer text with [n] citations."""
    values = {"not_found": NOT_FOUND, "instruction": INSTRUCTIONS[answer_type],
              "sources": format_sources(chunks), "question": question, "feedback": feedback}
    prompt_text = PROMPT.format(**values)

    saved = get_cached(GEMINI_MODEL, prompt_text)
    if saved is not None:
        return saved

    llm = ChatGoogleGenerativeAI(model=GEMINI_MODEL, temperature=TEMPERATURE,
                                 google_api_key=GEMINI_API_KEY,
                                 timeout=GEMINI_TIMEOUT, max_retries=GEMINI_MAX_RETRIES)
    answer = (PROMPT | llm).invoke(values).text

    save_cached(GEMINI_MODEL, prompt_text, answer)
    return answer


# ---- Self-check: "python answer.py" (1 API call for the answer; the plan is cached) ----
if __name__ == "__main__":
    from planner import make_plan
    from search import search

    question = "What happens when the ball hits a wall?"
    plan = make_plan(question)
    chunks = search(question, plan.search_in)
    print(write_answer(question, plan.answer_type, chunks))
