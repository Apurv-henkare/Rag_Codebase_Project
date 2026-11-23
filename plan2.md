# Project Plan v2: Chat with the Inflate Code + Love2D Docs

> Based on `plan.md` (the main plan). Same goal, phases and rules.
> v2 adds small, cheap fixes and the design decisions we agreed on (marked **[v2]**),
> and keeps the bigger ideas in "Parked".

## Goal
A chatbot for the **Inflate** game (Love2D / Lua) that:
1. **Answers questions** about the game's code and the Love2D engine docs, with sources
2. **Shows the real code**, copied exactly from the files by Python
3. **Writes new code** that fits the game, using only real functions, checked by Python

Two sources:
- 💻 **Code:** `game_project/` (74 `.lua` files, about 12,000 lines)
- 📘 **Docs:** `documents/` (Love2D wiki PDFs: guides, types, modules, tutorials...)

Every answer cites its source (`src/Ball.lua`, lines 127–149, or a PDF page).
If the answer isn't in the sources, it says "I couldn't find that."

**Deadline: submit Monday (2026-11-23).** This plan is the MVP (the smallest version that fully works).

---

## Working Rules
- **For every file, three steps:**
  1. **Explain** in simple words what the file will do and why.
  2. **Show** the code in chat. You read it and ask questions.
  3. **Write** it to the file only after you say okay.
- **Big files are done in parts:** say up front that the file is big, explain and show part 1,
  then part 2, ... and write the full file only after every part is understood.
- **You run every command and every file.** Claude never runs the code; you paste the
  output and Claude explains what it means.
- **Simple code:** plain functions, clear names, comments that explain *why*, no clever tricks.
- **Explanations are basic but technical:** real terms, inputs/outputs, small examples from this
  project (no everyday analogies). LangChain, Pydantic, metadata, embeddings, FAISS, BM25, RRF
  are explained the first time they appear.
- **Resume-ready:** you should be able to explain every part of this project in an interview.
- After each phase: a short `phases/phaseN.md` in simple language.
- Never commit `.env` or `AIP_rag_reference/`. Never index `.env`.

---

## Architecture
```text
User question
   │
① QUERY PLAN (AI call 1) → Pydantic QueryPlan
     answer_type: explain / locate / show_code / write_code / out_of_scope
     symbols_mentioned: names like "Ball:pop"
     search_in: code / docs / both
     out_of_scope_parts: off-topic parts of the message (usually empty)
   │
② RETRIEVAL (local, free)
     exact symbol lookup + hybrid search (FAISS + BM25 → our own RRF)
     over code chunks (one per function) and docs chunks (recursive, ~1000 chars)
     + Python "used in" lists from the symbol index
   │
③ ANSWER or CODE (AI call 2) → uses ONLY the retrieved chunks, cites [1], [2]...
   │
④ PYTHON CHECKS (no AI)
     answers: every [n] is real, every name mentioned exists
     new code: valid Lua (luaparser) + every function/constant exists
     → fails: retry once → still fails: "I couldn't answer this reliably"
   │
⑤ FINISH (Python) → source list (file:line / PDF page), exact code snippets, "uses:" list
```
Normally 2 AI calls per question (3 with a retry, 1 for out of scope).
**[v2]** Every AI call goes through a small SQLite cache (Phase 0.5): a repeated prompt costs 0 calls.

**[v2] Where LangChain is used / where our own code is used**
| LangChain | Our own code |
|---|---|
| `ChatGoogleGenerativeAI` (Gemini), `ChatPromptTemplate`, `with_structured_output(QueryPlan)`, `Document`, `HuggingFaceEmbeddings`, `FAISS`, `BM25Retriever` (with our tokenizer), `RecursiveCharacterTextSplitter` | Lua AST chunking (luaparser), symbol index + "used in" lists, RRF merge, Python checks, cache |

---

## [v2] Answer types

| `answer_type` | User wants | Example | Main output |
|---|---|---|---|
| **explain** | understand how something works | "How does coyote time work?" | explanation + `[n]` citations |
| **locate** | where something is | "Where are gems collected?" | list of `file:line` locations |
| **show_code** | see existing code / usages | "Show me `Ball:moveX`", "Show where `love.graphics.rectangle` is used" | exact code copied by Python + short explanation |
| **write_code** | new or changed code for Inflate | "Add a bounce sound on wall hits" | "How it works now" + "New code" + **uses:** list |
| **out_of_scope** | not about Inflate / LÖVE | "Make Pong", "Unity help" | fixed refusal (1 API call) |

**Scenario decisions**
| Scenario | Handled as |
|---|---|
| Code + docs in one question | `explain` / `show_code` with `search_in = "both"` |
| Explain + write code in one message | `write_code` with two sections (Phase 5.7) |
| Partly off-topic message | answer the Inflate part, skip the rest (Phase 5.8) |
| Feature not in the game ("multiplayer lobby") | "I couldn't find that." |
| Vague request / feature already exists | say so, state the assumption, then answer |
| Error / debugging ("attempt to index nil in GameLevel.lua line 600") | `explain`, search using the file/line in the error |
| General LÖVE question ("how do I draw a circle in LÖVE?") | allowed: `explain` from docs |
| Generic standalone program ("write a platformer") | `out_of_scope` |
| Small talk / "what can you do?" | fixed help line, no search |
| Follow-up questions | not in MVP: each message stands alone (Parked) |

---

## Phases (MVP)

**Phase 0: Setup**
- 0.1 Project folder + venv ✅ (per `plan.md`)
  **[v2]** Check: there is no venv inside `D:\Plaksha_Rag_Understand_2` and the system Python
  has no `dotenv` / `fitz` / `luaparser`. Confirm where the venv lives (`python -c "import sys; print(sys.prefix)"`).
- 0.2 Install packages ✅ → add `luaparser` (keep `pymupdf` for the PDFs)
  **[v2]** Freeze the exact versions into `requirements.txt` (`pip freeze`), so it installs anywhere.
- 0.3 `.gitignore` + `.env.example` (you create `.env` with your key yourself)
- 0.4 `config.py`: all settings in one place
  **[v2]** includes `DOC_CHUNK_SIZE = 1000`, `DOC_CHUNK_OVERLAP = 150`, `TOP_K_PER_SOURCE = 3`,
  `SKIP_PDFS`, `MAX_SNIPPETS_SHOWN`, the refusal / help sentences.
- 0.5 **[v2] Tiny SQLite cache** (`cache.py`, ~40 lines): key = hash(model + full prompt), value = answer.
  Why: we run the evals (and the plain-Gemini baseline) several times. Without a cache every
  run costs API calls, can hit Gemini rate limits, and gives slightly different numbers each time.
  Because the key hashes the full prompt, editing a prompt automatically skips old answers.

**Phase 1: Load + chunk**
- 1.1 Read the PDFs and the game code to see their structure (reading only)
  **[v2]** Your script prints, for the PDFs:
  - text length per page (min / median / max) → confirms `DOC_CHUNK_SIZE`
  - how many pages contain a revision line (`<name> · revision <n> · last edited`)
  - 3–5 sample pages as extracted text
- 1.2 Check `injection.pdf` and `vv2.pdf`: kept OUT of the main index until we know what they are
  (from the old project: `injection.pdf` is a poisoned test doc with a fake `drawCyberPortal` API,
  `vv2.pdf` is a fake API-key leak test)
- 1.3 **Code loader: AST-based chunking** with luaparser
  - **[v2] Do this first, it is the biggest risk.** Check that luaparser parses all 74 files
    (print any that fail) and gives a start **and** end line for every function.
    If a file fails: simple fallback that cuts from `function ...` to its matching `end`.
  - Metadata per chunk: `source`, `file`, `start_line`, `end_line`, `symbol`, `kind`
  - **[v2] Chunk kinds:**
    | kind | unit | example |
    |---|---|---|
    | `function` / `method` | one whole function | `Ball:moveX` → `src/Ball.lua:244-277` |
    | `file_header` | the `--[[ ]]` comment at the top of a file | `src/Ball.lua` header |
    | `constants_group` | one commented group in `constants.lua` | the `BALL PHYSICS` block |
    | `top_level` | code outside any function | `OBJECT_DEFS` in `LevelMaker.lua`, `require` list in `Dependencies.lua` |
    | `level_meta` | level file header + name + theme (grids skipped) | `level15.lua`: Wild Falls, jungle |
  - **[v2]** The chunk text starts with the file path + signature (e.g. `src/Ball.lua — Ball:moveX(dt)`),
    so the part the embedding model reads first is the most informative.
  - **[v2]** Very long functions (some in `GameLevel.lua`) are split into parts; each part keeps
    the same `symbol`, its own line range, and repeats the `function ...(...)` signature line.
    No character overlap for code.
- 1.4 **[v2] Docs loader: recursive character splitting only**
  - PyMuPDF reads each PDF page → `Document(page_content=text, metadata={pdf, page})`
  - `RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=150)`
    (tries `\n\n` → `\n` → ` ` → characters). 1000 chars fits the ~256-token input limit of
    `all-MiniLM-L6-v2`; final value confirmed in 1.1 / 3.1.
  - **No junk removal**: the "On this page" box, "Other Languages" list etc. stay in the text.
    Reason: rules built from a few sample pages could break on thousands of others or delete real content.
  - **Read-only tagging:** a regex finds LÖVE names in each chunk (`love.x.y`, `Type:method`) and
    stores them as metadata `apis: [...]`. Nothing is removed from the text.
  - Metadata per chunk: `source`, `pdf`, `page`, `apis`
- 1.5 Symbol index: every game function/constant + every Love2D API name → location
  - **[v2] LÖVE API list** (for the code checks): read every revision line with a regex
    (`^(\S+) · revision`) to collect real names, including **type methods** like `Mesh:getVertexMap`,
    `Source:play`. Fallback if that line doesn't extract cleanly: the `apis` tags from 1.4.
  - **[v2] File-local names** (e.g. `local mabs = math.abs` in `Ball.lua`), so correct code using them passes.
  - **[v2] Alias resolution:** `local lg = love.graphics` (12 files) and `local lg_draw = love.graphics.draw`
    (`Background.lua:904`), so `lg.rectangle(...)` is recorded as a use of `love.graphics.rectangle`.
  - **[v2] "Used in" lists:** for every symbol, every file + line where it is used.
  - Watch out: game functions inside the `love` table (`love.keyboard.wasPressed`, `main.lua:49`) are
    **game symbols**, not LÖVE APIs.
- 1.6 Save the chunks and the symbol index to disk

**Phase 2: Test set (written BEFORE the search exists)**
- ~20 questions: ~7 code, ~5 docs, ~3 both, ~3 code generation, ~2 out of scope
  (one out-of-scope case is "make a Pong game": it must refuse, not write code)
- Gold answer = **a location in the source** (file + lines, or PDF + page), taken from reading it
- You spot-check them; split into dev (~2/3) and test (~1/3)
- **[v2]** The test split is only ~7 questions, so report counts ("6/7"), not just percentages.
  If there is time, grow to ~30 questions.
- **[v2]** Include: 2 combined questions (explain + code; in-scope + out-of-scope),
  1 small-talk/help message, 1 general LÖVE question.

**Phase 3: Search**
- 3.1 Embeddings (HuggingFace) + FAISS: search by meaning
- 3.2 BM25 with a code-aware tokenizer (splits `Ball:hurt`, `SPIKE_DAMAGE`): search by exact words
- 3.3 Our own RRF: `score = 1 / (60 + rank)` to merge both lists
- 3.4 ~~Exact symbol lookup~~ **[v2] Dropped: hybrid search only (FAISS + BM25 + RRF).** The symbol
  index is still built (1.5) but used only for the Python name checks and "used in" lists.
- 3.5 **[v2] Two indexes, code and docs.** `search_in` picks which one(s).
  With `"both"`, take a fixed number from each (e.g. 3 docs + 3 code), so one source can't
  push the other out of the results.
- 3.6 **[v2] Source files can change (game code and Love2D docs get updated).**
  - One rebuild script: code chunks → doc chunks → indexes. Always a full rebuild (code: seconds,
    docs: a few minutes), never partial updates, so no stale pieces are left behind.
  - At build time save a manifest `{file: sha256 hash}`. At app start Python re-hashes the files;
    if any changed, show "Index is out of date (<file> changed). Run the rebuild." (0 API calls)
  - Before showing a code snippet, compare the lines on disk with the chunk's saved text; if they
    differ, say "file changed since indexing" instead of showing wrong lines.

**Phase 4: Grounded answers**
- 4.1 LangChain prompt + Gemini: answer only from the numbered chunks
- 4.2 Citations: 📄 file:line for code, 📘 PDF + page for docs
  **[v2]** Two levels: inline `[n]` written by the LLM, and a **source list under the answer
  built by Python from chunk metadata** (so file paths, lines and pages are never typed by the AI).
- 4.3 Python checks + one retry + safe refusal
- 4.4 Exact code snippets copied from the files by Python
- 4.5 **[v2] "Used in" answers** (e.g. "where is `love.graphics.rectangle` used?"): the complete list
  comes from the symbol index (Python), not from the LLM. Show the count + the first
  `MAX_SNIPPETS_SHOWN` (3–5) snippets; the rest go behind "show all". Only a few examples go to the LLM.

**Phase 5: Query plan + code generation**
- 5.1 Pydantic `QueryPlan` + `with_structured_output`
- 5.2 Route by `answer_type`
- 5.3 `write_code`: retrieve a similar existing example + the needed functions + docs → AI writes code
  **[v2]** The AI returns the **whole changed function** (`function Ball:moveX(dt) ... end`), not a
  fragment, so luaparser can always check it.
  **[v2]** If the request is vague or the feature already exists (e.g. wall bounce already exists in
  `Ball:moveX`), the answer says so and states its assumption.
- 5.4 Python checks: valid Lua syntax, every function and constant exists
  (allowed = game symbols + file-local names + Love2D API + Love2D type methods + standard Lua
  + names the new code defines)
- 5.5 Show the code + a "uses:" list with sources
- 5.6 Only code **for Inflate**. Requests for a new game or a standalone program (e.g. "make a Pong game")
  → `out_of_scope` → "I only write code for the Inflate project."
- 5.7 **[v2] Explain + code in one message** (e.g. "How does spike damage work, and add a shield
  that halves it?"): if any part asks for code, `answer_type = write_code`, and the write_code
  answer always has two sections: **"How it works now"** (with `[n]` citations → citation check)
  and **"New code"** (→ Lua syntax + real-names check). Still 2 API calls.
- 5.8 **[v2] Partly out-of-scope messages** (e.g. "Explain `Ball:pop` and make me a Pong game"):
  `QueryPlan.out_of_scope_parts: list[str]`. Answer the Inflate part normally, then add
  "Skipped: make me a Pong game. I only write code for the Inflate project." Still 2 API calls.

**Phase 6: Evaluate**
- 6.1 Retrieval: Hit@k and MRR per group (code / docs / both)
- 6.2 Answers: does it mention the must-mention facts? Did it refuse out-of-scope questions?
- 6.3 Code generation: valid syntax %, real-names-only %
- 6.4 **Baseline: plain Gemini (no retrieval) vs ours**, on the same questions
- 6.5 Final numbers on the test split

**Phase 7: App + wrap-up**
- 7.1 Streamlit chat page
- 7.2 README: what it does, how to run it, results, limits
- 7.3 `phases/*.md` summaries

---

## [v2] Chunking summary

| | Code (`.lua`) | Docs (PDF) |
|---|---|---|
| Strategy | AST-based (luaparser) | recursive character splitting |
| One chunk = | one function (+ headers, constant groups, top-level code, level meta) | up to ~1000 chars |
| Overlap | none (long functions repeat the signature line instead) | ~150 chars |
| Junk removal | — | none (text kept as extracted) |
| Metadata | `file`, `start_line`, `end_line`, `symbol`, `kind` | `pdf`, `page`, `apis` |
| Citation | 📄 `src/Ball.lua:244-277` | 📘 `02-types-1of2.pdf p.412` |

## [v2] API calls per message

| Message | Calls (normal) | With retry |
|---|---|---|
| explain / locate / show_code / write_code | 2 | 3 |
| out_of_scope | 1 | 1 |
| explain + code (5.7) or partly off-topic (5.8) | 2 | 3 |
| same prompt again | 0 (cache) | 0 |

Python checks, search and embeddings cost **0** API calls (all local).
First full eval (~22 questions + baseline) ≈ 70 calls; re-runs ≈ 0 (cache).

---

## Honesty Rules
- Gold answers come from reading the source, never from our own search.
- Code snippets are copied, never written by the AI.
- Generated code is checked for syntax and real names, **not** guaranteed bug-free.
- Report real numbers, including failures. No hard-coded or fake metrics.
- Watch out: the game defines some functions inside the `love` table itself
  (for example `love.keyboard.wasPressed` in `main.lua`, line 49 — verified). These are game code,
  not Love2D docs. Same for the callbacks it defines: `love.load`, `love.update`, `love.draw`,
  `love.resize`, `love.focus`, `love.keypressed`.

---

## [v2] Lessons from `AIP_rag_reference` (what NOT to repeat)
- The gate read old JSON reports instead of re-running checks → our numbers are always re-computed.
- Gold answers were picked by scanning our own index (circular) → ours come from reading the source.
- Regex guards matched only the exact test attacks → we don't claim security we don't test.
- `requirements.txt` was missing packages → we freeze it from the real venv.
- Cache key didn't change when the prompt changed → our key hashes the full prompt.

---

## Parked (future work)
From `plan.md`:
Reranker · call-graph "who calls" and flow tracing · query decomposition · follow-up chat ·
"did you mean" · cost tracking · tracing · safety guards (injection test with `injection.pdf`) ·
embedding model comparison (MiniLM vs EmbeddingGemma) · agent mode · other languages (tree-sitter) ·
Docker / CI / MCP

Added in v2:
- Docs: split by wiki page (revision line) and by subheadings; junk removal ("On this page",
  "Other Languages") — only if Phase 3 search results show the noise hurts
- A separate `debug` answer type for error messages
- Write generated code into `game_project/` after showing a diff and getting approval (with backup)
- Smoke test: launch `love game_project` for a few seconds to catch runtime errors
- Re-index only changed files (file hashes)
- Separate held-out attack set with reworded attacks; output filter that doesn't damage Lua code
- LLM-as-judge on a sample, checked against hand labels
- Regression gate that re-runs checks and exits 0 / 1
- Streamlit sidebar with live calls, cache hits, latency and spend
