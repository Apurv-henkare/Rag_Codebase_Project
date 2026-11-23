"""Step 0.5 check: one real Gemini call through LangChain, plus the cache.
Run twice: 1st run calls Gemini, 2nd run is answered from the cache."""

from langchain_google_genai import ChatGoogleGenerativeAI
from config import GEMINI_API_KEY, GEMINI_MODEL, TEMPERATURE
from cache import get_cached, save_cached

PROMPT = "In one sentence: what is the C++"

saved = get_cached(GEMINI_MODEL, PROMPT)
if saved is not None:
    print("CACHE:", saved)
else:
    try:
        llm = ChatGoogleGenerativeAI(model=GEMINI_MODEL,
                                     temperature=TEMPERATURE,
                                     google_api_key=GEMINI_API_KEY)
        answer = llm.invoke(PROMPT).text
        save_cached(GEMINI_MODEL, PROMPT, answer)
        print("GEMINI:", answer)
    except Exception as error:
        print("FAILED:", error)
