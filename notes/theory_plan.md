# Theory session plan: Inflate RAG, from zero

**When:** Monday 2026-11-23 (before the cleanup, README and git push).
**Assumes:** you know nothing yet.

**How we study:** we go through the project **in the same order we built it, block by block**.
Each block is one file (or a small group of files). For each block we learn the theory it needs,
at that moment. Each block only uses things from earlier blocks, so you never need an idea you
haven't learned yet. At the end, we run one question through all the blocks to see the full flow.

**Language: simple.** Short sentences, plain words. Every technical term is explained in simple
words the first time it appears.

**Goal: truly understand, and be interview-ready.** Every block is explained **in detail**, not as a
summary: the theory fully, how it connects to the block before and the block after, and why we chose
it over the alternatives. We don't move on until you can explain the block yourself.

**For every block:**
1. **Why we built it**: the problem at that point in the project
2. **The theory, in detail**: the idea fully explained in simple words, with how it works inside
3. **Our example**: real data from Inflate, followed step by step
4. **The code**: NOT the whole file, only the main part (the few key lines that do the work),
   explained: what goes in, what those lines do, what comes out
5. **What went wrong and how we fixed it**: the real problems we hit while building
6. **Why this and not something else**: the alternatives and the trade-off (e.g. why hybrid and not only FAISS,
   why chunk by function and not by fixed size)
7. **How it connects**: what it takes from the earlier blocks, and what it gives to the next ones
8. **Interview corner**: how to explain this block in 30 seconds, plus 2–3 questions an interviewer
   could ask about it, with answers
9. **Check yourself**: you explain the block back in your own words before we move on

**Examples come only from our project** (our code, our chunks, our questions, our numbers), not made-up
examples. One example per idea; if something isn't clear, you ask and we go deeper.

**Order inside every block: theory first, then the library, then our code.**
1. **Theory**: the idea itself, in simple words, with one worked example from our project
   (e.g. what an embedding is, how BM25 scores words, why RRF adds `1/(60+rank)`, what cosine similarity is,
   what Hit@k and MRR measure, why overlap in chunking, what hallucination is)
2. **Library**: the tool that does it for us
3. **Our code**: how we used it in Inflate, line by line

**Libraries from zero:** every library is taught from scratch the first time it shows up, starting
from the simplest place it's used in our own code:
LangChain, Pydantic, SQLite, luaparser, PyMuPDF, sentence-transformers, FAISS, numpy, rank_bm25, Streamlit.

**Code: main part only.** Never the entire file. For each block, show only the key lines that do the
main work, and explain what they do: what goes in, what happens, what comes out, with real values from Inflate.

---

## Block 0: The project and the basics (no code yet)

- **The project** (`project_description.md`): what Inflate is (15 levels, 74 Lua files, ~12,000 lines),
  the 2 sources (game code + engine docs), the 4 problems (spread-out code, huge separate docs,
  chatbots invent things, game code looks like engine code), what the assistant does, who uses it, limits
- **What an LLM is**: it predicts text from training data; it knows public LÖVE, not private Inflate
- **What a prompt is**: everything the LLM sees; what's not in it, it can't use
- **Hallucination**: confident made-up answers (plain Gemini: 6 fake names on w3)
- **What RAG is**: Retrieve pieces → put them in the prompt → Generate from them
- **The two phases** we will build: build phase (files → indexes) and question phase (question → answer)

**Check yourself:** explain the project in 3 sentences.

---

## Block 1: Setup (`config.py`, `.env`, `requirements.txt`, `checks/check_gemini.py`)

- **Why:** one place for settings; the API key kept secret; the first test that Gemini answers at all
- **Theory:** API key and why it lives in `.env` (never in code, never in git); model name; temperature 0
- **Code:** `config.py` settings, `load_dotenv`
- **Check yourself:** what happens if `.env` is pushed to GitHub?

## Block 2: The cache (`cache.py`)

- **Why:** API calls cost time and quota; the same question shouldn't call Gemini twice
- **Theory:** hashing (sha256 = a fingerprint of text), a key → value table in SQLite,
  why temperature 0 makes caching safe
- **Code:** `make_key`, `get_cached`, `save_cached`
- **Check yourself:** why does changing one character of the prompt cause a new API call?

## Block 3: Looking at the data first (`checks/inspect_data.py`, `checks/check_lua_parse.py`)

- **Why:** before cutting files into pieces, see what they look like
- **Theory:** what an **AST** is (code turned into a tree: function → body → statements), using luaparser
- **Our example:** every one of the 74 Lua files parses; the PDFs have a title line on each wiki page
- **Check yourself:** what does an AST give us that plain text doesn't?

## Block 4: Chunking the game code (`load_code.py`)

- **Why:** we can't send 12,000 lines to Gemini; we need the right small pieces
- **Theory:** chunking (too big = noise, too small = no context); cutting at function boundaries using the AST;
  metadata (file, start line, end line, symbol, kind)
- **Our example:** the `Ball:moveX` chunk, lines 242–277; 6 kinds of chunk → **727 chunks**
- **Went wrong → fixed:** comment-only banner chunks (skipped); a 1-line `end` tail part (merged if under 10 lines);
  comments above a function now kept with it
- **The parser logic in detail:** how the AST finds functions (top-level only); what becomes a chunk
  (function, method, file_header, constants_group, top_level, level_meta); what is **skipped** and why
  (comment-only groups, groups under 30 characters, level grid rows); how each metadata field is filled
  (`file`, `start_line`, `end_line`, `symbol`, `kind`) and where each one is used later
- **Check yourself:** why is metadata the reason citations can't be invented?

## Block 5: Chunking the docs (`load_docs.py`)

- **Why:** the engine docs are 9 PDFs and thousands of pages
- **Theory:** size-based splitting (1000 characters) with overlap (150); keeping the page title with each chunk
- **Our example:** "06-modules.pdf p.444 - love.graphics.rectangle" → **4,772 chunks**
- **The logic in detail:** which PDFs are skipped (`SKIP_PDFS`), pages under 30 characters skipped,
  how the page title is found (the " · revision " line) and carried over to continuation pages,
  and the metadata fields (`pdf`, `page`, `title`)
- **Check yourself:** why do code and docs use different chunking?

## Block 6: The symbol index (`build_symbols.py`)

- **Why:** to check later whether a name is real, we need a list of every real name
- **Theory:** a lookup table name → `file:line`; aliases (`local lg = love.graphics`)
- **Our example:** `Ball:hurt → src/Ball.lua:127`; 519 game names, 1,843 engine names
- **Went wrong → fixed:** aliases inside functions were missed; then call results were wrongly taken as aliases → only plain names count
- **Check yourself:** why do we need aliases to check `lg.rectangle(...)`?

## Block 7: The test set, written BEFORE search (`eval/test_set.json`)

- **Why:** to measure search honestly, the right answers must come from reading the real files, not from our own search
- **Theory:** gold locations, must-mention facts, the **dev/test split** (build with dev, test once at the end)
- **Our example:** c1 (wall bounce) with gold `src/Ball.lua:244-277`; 15 dev + 8 test questions
- **Check yourself:** why would testing on the questions we tuned on give a fake high score?

## Block 8: Embeddings and FAISS (`build_index.py`)

- **Why:** search by meaning, not just by matching words
- **Theory:** an embedding = text → 384 numbers, where similar meaning gives similar numbers;
  normalised vectors; cosine similarity; FAISS stores the vectors and finds the closest ones fast
- **Our example:** "ball hits wall" lands near the `Ball:moveX` chunk; 727 + 4,772 vectors
- **Check yourself:** why does "ball hits wall" find code that never contains the word "hits"?

## Block 9: Hybrid search (`search.py`) + measuring it (`eval_search.py`)

- **Why:** meaning alone misses exact names like `WALL_BOUNCE_MIN`; words alone miss meaning
- **Theory, in build order:**
  1. **BM25**: word search where rare words count more
  2. **Our tokenizer**: `love.graphics.newImage` → 6 tokens (full name, parts, camelCase pieces)
  3. **RRF**: merging ranked lists with `1/(60+rank)` (the A–E example)
  4. **Hit@k and MRR**: how we score search (worked example)
  5. **The focused docs query**: search the docs only for the real engine names in the question
- **Our numbers:** 9/13 → tokenizer 8/13 (worse!) → title matching + focused query **11/13, MRR 0.77**
- **Check yourself:** why can a "better" change make the score drop, and what do you do then?

## Block 10: Rebuild and the manifest (`rebuild.py`)

- **Why:** the game code and docs can change; the index must follow
- **Theory:** a manifest of file fingerprints (sha256); comparing old vs new to find changed files
- **Our example:** edit `Ball.lua` → the app shows "Index out of date"
- **Check yourself:** why hash the file instead of checking its date?

## Block 11: The planner (`planner.py`), the first Gemini call in the pipeline

- **Why:** each question needs a decision: what kind of answer, and where to search
- **Pydantic from zero:** what a class with typed fields is; `BaseModel`; `Literal` (only these values
  allowed); `Field(description=...)`; what happens when data doesn't fit (a validation error);
  `model_dump_json` / `model_validate_json`, all shown on our `QueryPlan`
- **LangChain from zero:** what it is (glue between prompts, models and data); `ChatPromptTemplate`
  (system + human messages with `{placeholders}`); `ChatGoogleGenerativeAI`; the `|` pipe (`PROMPT | llm`);
  `.invoke()`; `.with_structured_output(QueryPlan)`, starting from the simplest one, `checks/check_gemini.py`
- **Then our code:** `QueryPlan` field by field, and `make_plan` line by line (prompt → cache key → cache
  check → Gemini → plan object → save); why the schema is part of the cache key
- **Our example:** "Explain Ball:pop and make me a Pong game." → `explain | code | out_of_scope_parts: ["make me a Pong game"]`
- **Decision:** the prompts hide the engine's name, so Gemini relies on our docs (the d5 trade-off)
- **Check yourself:** what does Pydantic guarantee that plain text doesn't?

## Block 12: The answer (`answer.py`), the second Gemini call

- **Why:** turn the 5 found chunks into an answer that can be checked
- **Theory:** numbered sources and `[n]` citations; rules in the prompt; a different task per answer type;
  the fixed "I couldn't find that." reply
- **Our example:** the c1 answer, citing `[1]`
- **Check yourself:** why number the sources instead of just pasting them?

## Block 13: Checking answers (`verify.py`)

- **Why:** the prompt **asks** Gemini to follow the rules; Python **checks** that it did
- **Theory:** citation check (every `[n]` exists); name check (backtick names must be in the symbol index
  or the sources); sources built from metadata; snippets read from disk, with the stale guard
- **Our example:** the fake answer using `Ball:takeDamage` → caught
- **Check yourself:** why show code from disk instead of the code Gemini wrote?

## Block 14: The pipeline (`rag.py`)

- **Why:** connect blocks 11–13 into one function, `ask(question)`
- **Theory:** routing (help / out_of_scope), the **retry loop** (problems → feedback → 1 retry → "I couldn't answer this reliably."),
  timeouts and network retries
- **Went wrong → fixed:** code shown twice, a stray "not found" line, sources out of order;
  a hung request → added a 60 s timeout
- **Check yourself:** why is a refusal better than an unchecked answer?

## Block 15: Checking new code (`code_check.py`)

- **Why:** write_code answers can use functions that don't exist (`JUMP_FORCE`)
- **Theory:** reuse the AST from Block 3: syntax check; every called name must be real
  (game / engine / standard Lua, via the symbol index and aliases); the "Uses" list
- **Went wrong → fixed:** fragments slipped through → **Fix B** (must be a whole function);
  `player:takeSpikeDamage` slipped through → **Fix C** (the class must be real)
- **Check yourself:** which check catches `function player:takeSpikeDamage()`, and why didn't Fix B?

## Block 16: Better search for write_code: planner phrase → RAG-Fusion (`planner.py`, `search.py`)

- **Why:** "add a **shield** that **halves** it" describes new code, so search missed the existing code
- **Theory:** query rewriting (the planner's `search_query`), then **RAG-Fusion**: search with the
  question **and** the phrase, merge 4 lists with RRF (Block 9); when fusion is skipped (the focused docs query)
- **Our numbers:** phrase only 9/13 (worse, reverted) → fusion **11/13, MRR 0.67**; the wall question now finds `Ball:moveX`
- **Check yourself:** why is fusion safer than using only the phrase?

## Block 17: Evaluating answers (`eval_answers.py`, `baseline.py`, `eval/eval_log.md`)

- **Why:** search scores don't tell us whether the final **answers** are right
- **Theory:** scoring facts and refusals; a **baseline** (plain Gemini, no search); reporting **by group**;
  keeping it honest (false passes, reverts, no editing the answer key, the test split run once)
- **Our numbers:** dev 8/15; **test 6/8**; game code: plain 2/11 vs ours 8/11; w3: plain used 6 fake names, ours refused
- **Check yourself:** why is "6/13 vs 5/13 overall" misleading?

## Block 18: The app (`app.py`, `.streamlit/config.toml`)

- **Why:** a chat page anyone can use
- **Theory:** Streamlit re-runs the script on every click; `session_state` keeps the chat;
  counting API calls; latency, average and **p95** (worked example)
- **Check yourself:** why can p95 be very different from the average?

---

## Block 19: The full flow, all blocks together

One question from the chat box to the screen, naming the block at each step:
**"Add a bounce sound when the ball hits a wall."**
app (18) → cache (2) → planner (11) → fusion search (16, 9, 8) → answer (12) → checks (13, 15)
→ retry (14) → sources + snippets (13) → app shows API calls and p95 (18)

Then a quick replay with **"What is love.graphics.rectangle?"**: the focused query instead of fusion,
no code checks, 3 calls on the first ask, 0 calls on the second.

## Block 20: Interview prep

- 3 resume lines with our measured numbers
- 10 likely questions with short answers
- known limits, said honestly: spike-damage search (c2, w2), plain variables like `player` aren't checked, small test set

---

## After the session (same day)

1. Folder cleanup: main files in the root, the rest in folders
2. Re-run everything once after the move
3. README: what it does, how to run it, results, limits
4. Git push: check that `.env`, `cache/` and `AIP_rag_reference/` are not uploaded
