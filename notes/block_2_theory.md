# Block 2: The cache (`cache.py`)

---

## 1. Why we need a cache

Every Gemini call costs **time** (about 1–5 s) and uses the **daily free limit**.
And the same things are asked again and again: `rag.py` re-run while building, `eval_answers.py` (15
questions) every test, a user asking the same question twice.

**A cache is a place where answers are saved so they can be reused instead of asking again.**
```
Before asking Gemini: "Have we asked this exact prompt before?"
   YES → take the saved answer     → 0 API calls, about 0.1 s
   NO  → ask Gemini, then SAVE it  → 1 API call
```
**Real proof:** "what does love.graphics.rectangle does?" → first time `API calls: 3 · 5.19 s`,
again `API calls: 0 · 0.09 s` (about 50× faster). Re-running the eval after the revert: 15 questions, 0 calls.

**Why it's safe:** temperature 0 means the same prompt always gives the same answer, so the saved answer is
exactly what Gemini would say again.

### What the planner is (asked during this block)
The **planner** is the first step for every question (Gemini call 1). Gemini fills a small form:

| Field | Question it answers | "Add a bounce sound when the ball hits a wall." |
|---|---|---|
| `answer_type` | what kind of answer? | `write_code` |
| `search_in` | code, docs or both? | `code` |
| `search_query` | short words to search with | `ball wall collision` |
| `out_of_scope_parts` | any part not about Inflate? | `[]` |

```
question → PLANNER (call 1) → search → answer (call 2) → Python checks → show
```
"Make me a Pong game." → `out_of_scope` → fixed reply, no search, no second call.
Details (Pydantic, LangChain) in Block 11.

---

## 2. Hashing: how we know it's "the exact same prompt"

Prompts are long (rules + 5 chunks + question, often thousands of characters). Using such huge text as
the "name" of a saved answer is clumsy.

A **hash function** turns any text into a **short fixed-length code**. We use **SHA-256**, which always gives
**64 characters** (a–f, 0–9). Think of it as a **fingerprint** of the text.

| Property | Why it matters |
|---|---|
| same text → always the same hash | the same prompt finds its saved answer |
| change 1 character → a completely different hash | a slightly different prompt never reuses a wrong answer |
| always 64 characters | a 5,000-character prompt becomes a short key |

Main part of `cache.py`:
```python
def make_key(model, prompt):
    text = model + "\n" + prompt
    return hashlib.sha256(text.encode("utf-8")).hexdigest()
```
- in: model name + full prompt
- `.encode("utf-8")`: text → bytes (hashing works on bytes)
- `hashlib.sha256(...)` (built into Python) computes the fingerprint
- `.hexdigest()`: gives it back as 64-character text

**Why the model name is in the key:** a different model can answer the same prompt differently, so a new
model never reuses the old model's answers.

**Real "1 character changes everything" example:** the rectangle question's first answer failed a check; the
retry sends the same prompt **plus a feedback line** → a different prompt → a different hash → no saved
answer → a new API call. That's why it was **3 calls**, not 2.

---

## 3. SQLite: where the answers are saved

**SQLite** is a small **database** (an organised way to store data and find it fast):
- just **one file**: `cache/llm_cache.db`
- built into Python: nothing to install, no server

Data sits in a **table** (rows and columns, like a spreadsheet). Our table `cache`:

| key (hash) | response (saved answer) |
|---|---|
| `9f2c…` (64 chars) | "If the ball is faster than `WALL_BOUNCE_MIN`, it bounces [1]…" |
| `a71e…` | `{"answer_type": "explain", "search_in": "docs", …}` (a saved plan) |

Look up (main part):
```python
row = conn.execute("SELECT response FROM cache WHERE key = ?",
                   (make_key(model, prompt),)).fetchone()
return row[0] if row else None
```
`SELECT ... WHERE key = ?` is SQL (the database language) for "give me the answer whose key matches".
Found → the saved answer. Not found → `None` ("never asked").

Save (main part):
```python
API_CALLS["count"] = API_CALLS["count"] + 1
conn.execute("INSERT OR REPLACE INTO cache (key, response) VALUES (?, ?)",
             (make_key(model, prompt), response))
conn.commit()
```
- `INSERT OR REPLACE` adds the row (or replaces one with the same key)
- `commit()` writes it to the file for good
- the first line **counts API calls**: we only save right after a real call, so every save = 1 call → the app's "API calls: 3"

How the planner and answer steps use it:
```python
saved = get_cached(GEMINI_MODEL, prompt_text)
if saved is not None:
    return saved                       # reuse: 0 API calls
answer = ...call Gemini...             # only if not saved
save_cached(GEMINI_MODEL, prompt_text, answer)
```

---

## 4. Why this design

| Option | Problem |
|---|---|
| Python dictionary (memory) | lost when the program stops |
| JSON file | whole file read and rewritten on every save, slow as it grows |
| Redis (cache server) | separate program to install and run, too heavy |
| **SQLite** ✅ | one file, built in, fast lookup, survives restarts |

**Why our own cache and not LangChain's built-in one:**
1. control over the key: the planner key also includes the form's layout (schema), so adding a field
   (like `search_query`) makes old plans stop matching (Block 11)
2. counting API calls for the app

**It never serves outdated answers:** the prompt contains the chunk text (the actual code). Edit
`Ball:moveX` and rebuild → the prompt changes → a new hash → a fresh Gemini call. No manual clearing needed.

**Limits:** the file only grows (nothing deleted); only *exactly* the same prompt matches
("...a wall?" and "...a wall" are different).

---

## 🎤 Interview corner

**30 seconds:**
> "Every Gemini call is cached in SQLite. The key is a SHA-256 hash of the model name plus the full prompt.
> With temperature 0 the same prompt always gives the same answer, so reuse is safe. A repeat question costs
> 0 API calls and about 0.1 s instead of about 5 s. The retrieved code is inside the prompt, so any code
> change produces a new key automatically, and the cache never serves stale answers."

**Q: Why hash the prompt instead of storing it as the key?**
Prompts are thousands of characters; a hash is a fixed 64-character key, and 1 changed character gives a different key.

**Q: Couldn't the cache return an outdated answer after the code changes?**
No: the retrieved code is inside the prompt, so changed code = a different prompt = a different key.

**Q: Why does temperature matter for caching?**
At temperature 0 the output is deterministic; at higher temperatures a cached answer wouldn't represent what the model would say.

---

## ✅ Check yourself
1. What is a cache, and what does it save us?
2. Why does changing one character in the prompt cause a new API call?
3. Why can the cache never give an answer based on old code?
