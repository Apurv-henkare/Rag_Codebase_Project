"""Phase 4a: the query planner (AI call 1). Turns a user message into a QueryPlan."""

from typing import Literal
from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate
from langchain_google_genai import ChatGoogleGenerativeAI
from config import GEMINI_API_KEY, GEMINI_MODEL, TEMPERATURE, GEMINI_TIMEOUT, GEMINI_MAX_RETRIES
from cache import get_cached, save_cached


class QueryPlan(BaseModel):
    """How to answer one user message."""
    answer_type: Literal["explain", "locate", "show_code", "write_code", "out_of_scope", "help"] = Field(
        description="explain = how something works; locate = where something is in the code; "
                    "show_code = show existing code; write_code = write new or changed code for Inflate "
                    "(use this if ANY part of the message asks for code); "                    "out_of_scope = nothing about Inflate or its engine; help = greetings or 'what can you do'")
    search_in: Literal["code", "docs", "both"] = Field(
        description="code = the Inflate game code; docs = the engine documentation; "
                    "both = the message needs the game code and the engine documentation")
    search_query: str = Field(default="",
        description="A few keywords to find the EXISTING code or documentation the answer needs. "
                    "Keep any code names written in the message. Leave out words about new features "
                    "that do not exist yet, e.g. 'add a pause menu that dims the screen' -> 'pause draw screen'")
    symbols_mentioned: list[str] = Field(default=[],
        description="Code names written in the message, e.g. 'Ball:pop', 'love.graphics.rectangle', 'SPIKE_DAMAGE'")
    out_of_scope_parts: list[str] = Field(default=[],
        description="Parts of the message that are not about Inflate or its engine, e.g. 'make me a Pong game'")


PROMPT = ChatPromptTemplate.from_messages([
    ("system",
     "You plan how to answer messages about Inflate, a 2D platformer game written in Lua "
     "with an in-house game engine. The assistant can search the Inflate game code and the engine documentation. "
     "It only writes code for Inflate: a request for a new game, or for another engine "
     "(e.g. 'make me a Pong game', 'how do I do this in Unity'), is out_of_scope. "
     "Fill in the plan for the user's message."),
    ("human", "{question}"),
])


def make_plan(question):
    """AI call 1 (0 calls if cached): user message -> QueryPlan."""
    prompt_text = PROMPT.format(question=question)
    cache_key = prompt_text + str(QueryPlan.model_json_schema())     # schema change = new key

    saved = get_cached(GEMINI_MODEL, cache_key)
    if saved is not None:
        return QueryPlan.model_validate_json(saved)

    llm = ChatGoogleGenerativeAI(model=GEMINI_MODEL, temperature=TEMPERATURE,
                                 google_api_key=GEMINI_API_KEY,
                                 timeout=GEMINI_TIMEOUT, max_retries=GEMINI_MAX_RETRIES)
    planner = PROMPT | llm.with_structured_output(QueryPlan)
    plan = planner.invoke({"question": question})

    save_cached(GEMINI_MODEL, cache_key, plan.model_dump_json())
    return plan


# ---- Self-check: "python planner.py" (6 API calls the first time, 0 after) ----
if __name__ == "__main__":
    for question in ["What happens when the ball hits a wall?",
                     "Explain love.graphics.rectangle and show me where the game uses it.",
                     "How does spike damage work, and add a shield that halves it?",
                     "Explain Ball:pop and make me a Pong game.",
                     "Make me a Pong game.",
                     "hi, what can you do?"]:
        plan = make_plan(question)
        print("\n" + question)
        print("  ", plan.answer_type, "|", plan.search_in, "|", plan.search_query, "|", plan.out_of_scope_parts)
