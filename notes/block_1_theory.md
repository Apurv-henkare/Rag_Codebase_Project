# Block 1: Setup (`config.py`, `.env`, `requirements.txt`, `checks/check_gemini.py`)

---

## 1. Why `config.py`

**Problem:** about 20 Python files need the **same settings** (where the code is, how many chunks, which model).
If each file wrote them itself, changing one setting means editing many files, and forgetting one causes bugs.

**Solution:** one settings file. Every other file **imports** from it ("take something from another file and use it here").

Main part of `config.py`:
```python
CODE_DIR = PROJECT_DIR / "game_project"    # where Inflate's Lua code is
DOCS_DIR = PROJECT_DIR / "documents"       # where the LÖVE PDFs are
GEMINI_MODEL = "gemini-3.1-flash-lite"     # which Gemini to use
TEMPERATURE  = 0
TOP_K   = 5      # how many chunks go into the prompt
RRF_K   = 60     # used when merging search results (Block 9)
NOT_FOUND = "I couldn't find that."        # fixed replies
```
Used like this (from `search.py`):
```python
from config import TOP_K, RRF_K
```
Change `TOP_K = 5` → `7` in one place, and every file uses 7.

### Temperature
Controls how "creative" Gemini is:
- **high** (e.g. 1): picks less likely words → different answers to the same question
- **0**: always the most likely word → **same question, same answer**

We use **0** because:
1. correct facts matter more than creativity
2. it makes **caching** possible (Block 2): the same prompt always gives the same answer, so a saved answer can be reused

---

## 2. API, API key and `.env`

- **API:** Gemini runs on Google's computers. An API is the agreed way for our program to send it requests over the internet.
  Each request = **1 API call** (what the app counts).
- **API key:** a long secret code proving "this request is from my account". Google uses it to apply my free
  limit and block strangers. It works like a **password**; anyone who has it can use my limit.

**The key is never written in the code.** It lives in `.env`:
```
GEMINI_API_KEY=...secret...
```
Main part of `config.py` that reads it:
```python
load_dotenv(PROJECT_DIR / ".env")              # read the .env file (library: python-dotenv)
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")   # take the key from it
```
Other files then do `from config import GEMINI_API_KEY`.

**Why not put the key in `config.py`?** `config.py` goes to GitHub, where anyone can read it.
`.env` stays on my PC because it is listed in **`.gitignore`** (the file that tells git "never upload these").
**`.env.example`** shows the format without a real key (`GEMINI_API_KEY=your-key-here`); someone who
downloads the project copies it to `.env` and adds their own key.

Safety detail: `python config.py` prints only the key's **length** (`GEMINI_API_KEY: set (N characters)`),
never the key itself.

---

## 3. `requirements.txt`

A **library** is code someone else wrote that we use. `requirements.txt` lists every library with its **exact version**:
```
langchain-google-genai==4.5.2      # talk to Gemini
faiss-cpu==1.16.0                  # search by meaning
rank-bm25==0.2.2                   # search by words
luaparser==4.2.0                   # read Lua code as a tree
streamlit==1.67.0                  # the chat page
```
**Why exact versions:** a newer version can work differently and break the code. Fixed versions = the same
behaviour on any PC. Install all with `pip install -r requirements.txt`.

---

## 4. The first Gemini test: `checks/check_gemini.py`

Before building anything: **can our code talk to Gemini at all?** (key, model name, internet)

Main part:
```python
llm = ChatGoogleGenerativeAI(model=GEMINI_MODEL,
                             temperature=TEMPERATURE,
                             google_api_key=GEMINI_API_KEY)
answer = llm.invoke(PROMPT).text
```
- `ChatGoogleGenerativeAI(...)` creates a connection object to Gemini, set up from `config.py`.
  It comes from **LangChain**, a library that makes talking to LLMs simple (details in Block 11).
- `llm.invoke(PROMPT)` sends the prompt and waits for the reply → **1 API call**
- `.text` takes just the answer text

In: `"In one sentence: what is the C++"` → Out: one sentence about C++ → the connection works.
It also saves the answer; a second run prints `CACHE:` instead of calling Gemini (Block 2).

**Why a test first:** a wrong key or model name is much easier to find in a 6-line test than deep inside the
full project. That's what the `checks/` folder is for: small one-time tests, each checking one thing.

---

## ✅ Check yourself
1. Why do all files import settings from `config.py` instead of writing their own?
2. Why is the API key in `.env` and not in `config.py`?
3. Why is temperature set to 0?
