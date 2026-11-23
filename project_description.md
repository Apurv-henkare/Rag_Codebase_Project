# Project Description: Inflate RAG Assistant

A retrieval-augmented generation (RAG) assistant for one real, live game: **Inflate**, a
15-level platformer I built and shipped with the **Love2D game engine** (official name **LÖVE**)
in the Lua language.

The assistant answers questions using **two sources**:

| Source | Folder | What it is | Size |
|---|---|---|---|
| 💻 **Game code** | `game_project/` | Inflate's Lua source code | 74 `.lua` files, ~12,000 lines |
| 📘 **Love2D documentation** | `documents/` | the official Love2D (LÖVE) wiki, exported to PDF: guides, modules, types, tutorials | 9 PDFs, thousands of pages |

> **Love2D = LÖVE.** "LÖVE" is the engine's official name; "Love2D" is the common name
> (from its website love2d.org). Both mean the same engine and the same documentation.

It can **explain** code and engine functions, **locate** where something is implemented,
**show** the exact code, and **write new code** for Inflate. Every answer cites its source,
and Python checks the answer before it is shown.

---

## 1. The problem in a game studio

### 1.1 The game's knowledge is spread across many files
One gameplay feature in Inflate touches many files:

| Feature | Files involved |
|---|---|
| The player ball | `src/Ball.lua`, `src/states/entity/ball/BallGroundState.lua`, `BallAirState.lua`, `BallPopState.lua`, `src/constants.lua` (`BALL_SIZES`, `GRAVITY`, `COYOTE_TIME`...) |
| One enemy type | `src/Enemy.lua`, one or more files in `src/states/entity/enemy/`, `src/constants.lua`, `src/LevelMaker.lua` (which grid character spawns it), `src/Dependencies.lua` (the `require` line) |
| A level | `src/levels/levelN.lua` (text grid), `src/LevelMaker.lua` (legend: what each character means), `src/GameLevel.lua` (what happens on touch) |

A new programmer, designer or tester has to read many files to answer a simple question,
or ask a senior developer, which costs that person's time.

### 1.2 The Love2D documentation is big and separate from the code
The Love2D docs are thousands of PDF pages. Inflate's code calls Love2D functions
(`love.graphics.rectangle`, `love.graphics.newQuad`, `love.audio.newSource`, `quad:getViewport()`)
but never explains them. To understand one line of game code, a developer often has to search
the **game code** and the **Love2D docs** separately.

### 1.3 General AI chatbots don't know the project
A general LLM (ChatGPT, plain Gemini) has never seen Inflate. Asked about it, it:
- **invents files and functions** that don't exist (e.g. a `Player.lua` or `Ball:takeDamage()`),
- **mixes up Love2D versions**: Inflate targets Love2D **11.3** (`conf.lua`), where colours are
  `0–1`; older versions used `0–255`. A general model can mix the two,
- **ignores the project's conventions**: new states must be added to `src/Dependencies.lua`,
  new enemies need a grid character in `LevelMaker.lua`, tuning values belong in `constants.lua`,
- **gives no source**, so the answer can't be checked quickly.

### 1.4 Game code and Love2D code look the same
Inflate adds its own functions into Love2D's `love` table. Example: `love.keyboard.wasPressed`
is defined **by the game** in `main.lua` line 49. It is **not** a Love2D function. Anyone (or any AI)
that assumes every `love.*` name comes from Love2D will look in the wrong place.

---

## 2. What the project solves

| Problem | How the assistant handles it |
|---|---|
| Knowledge spread across many files | **Hybrid search** (meaning + exact words) over game-code chunks (one per function) **and** Love2D-doc chunks |
| Answers that can't be checked | Every claim cites a source: 📄 `src/Ball.lua:244-277` or 📘 `06-modules.pdf p.444` |
| Invented functions and files | Python checks every name against a **symbol index** built from the real game code and the Love2D docs |
| Code shown in answers could be wrong | Code snippets are **copied from the files by Python**, never typed by the AI |
| "Where is X used?" needs a complete list | Python builds the full "used in" list from the symbol index (including aliases like `lg = love.graphics`) |
| New code that doesn't fit the project | Code generation first retrieves a **similar existing example** from Inflate; the output is then checked for valid Lua syntax and real names |
| Off-topic requests | Questions not about Inflate or Love2D are refused |

---

## 3. Examples

### Example 1: Explain (game code)
**Question:** "What happens when the ball hits a wall?"

**What happens:** search looks in the **game code** and finds `Ball:moveX` (`src/Ball.lua:244-277`)
and `WALL_RESTITUTION` / `WALL_BOUNCE_MIN` (`src/constants.lua:41-42`). The LLM explains using only
those chunks; Python checks the citations and names and copies the real code under the answer.

**Answer (shape):**
> If the ball runs into a solid tile or the level edge, it counts as hitting a wall [1]. Faster than
> `WALL_BOUNCE_MIN` (60 px/s) it bounces back with 30% of its speed (`WALL_RESTITUTION = 0.3`);
> slower, it stops [1][2].
> 📄 [1] `src/Ball.lua:244-277` 📄 [2] `src/constants.lua:41-42` + the code, copied from the file

### Example 2: Locate
**Question:** "Where does the ball take damage from spikes?"

**Answer (shape):** a list of locations: the function in `src/GameLevel.lua` that handles the touch,
plus `SPIKE_DAMAGE = 25` in `src/constants.lua`, each with file and line numbers.

### Example 3: Explain (game code + Love2D docs together)
**Question:** "Explain `love.graphics.rectangle` and show me where the game uses it."

**What happens:** search looks in **both** sources (3 chunks each):
- 📘 **Love2D docs** → the `love.graphics.rectangle` page: what it does, its arguments (`mode`, `x`, `y`, `width`, `height`)
- 📄 **game code** → functions in `src/art/Background.lua`, `src/GameLevel.lua`, `src/HUD.lua`

The answer explains the function from the docs, then how Inflate uses it (only `'fill'`, mostly to
draw single pixels for its generated art). Python adds the complete "used in" list, including calls
written as `lg.rectangle(...)` through the alias `local lg = love.graphics`.

### Example 4: Show code
**Question:** "Show me `love.keyboard.wasPressed`."

**Answer:** the exact function from `main.lua` (line 49), copied from disk, with a note that this is
**game code**, not a Love2D function.

### Example 5: Write code (for Inflate)
**Question:** "Add a bounce sound when the ball hits a wall."

**What happens:**
1. The planner labels it `write_code`.
2. Search retrieves the existing code: `Ball:moveX` (wall handling) and `Ball:playBounce` (an existing sound helper).
3. The LLM writes the **whole changed function** in the same style, and says that wall bouncing already
   exists, so it adds only the sound.
4. Python checks: the Lua parses, and every name used exists (game code, Love2D functions and methods,
   standard Lua) or is defined in the new code.
5. The answer shows "How it works now", the "New code", and a **"uses:"** list, e.g.
   `playBounce → src/Ball.lua:433`, `WALL_BOUNCE_MIN → src/constants.lua:42`.

### Example 6: Love2D docs only
**Question:** "What is the difference between `static` and `stream` sources in `love.audio.newSource`?"

**Answer:** from the **Love2D docs only**, with 📘 PDF + page citations.

### Example 7: Explain + write in one message
**Question:** "How does spike damage work, and add a shield that halves it?"

**Answer:** one answer with two sections: **"How it works now"** (with citations) and **"New code"**
(checked for syntax and real names). Still 2 AI calls.

### Example 8: Out of scope
**Question:** "Make me a Pong game." / "How do I do this in Unity?"

**Answer:** "I only write code for the Inflate project." No code is generated.
If only part of a message is off-topic ("Explain `Ball:pop` and make me Pong"), the Inflate part is
answered and the rest is skipped with a note.

### Example 9: Not found
**Question:** "How does the multiplayer lobby work?" (Inflate has no multiplayer.)

**Answer:** "I couldn't find that." The assistant does not invent an answer.

---

## 4. Who would use it in a studio

| Role | Typical question |
|---|---|
| New programmer (onboarding) | "How does the state machine switch from the title screen to gameplay?" |
| Gameplay programmer | "Add a new enemy state that works like the patrol state but faster." |
| Game designer | "Which constants control how high the ball jumps?" |
| Level designer | "Which grid character places a spring, and what does `W` do?" |
| QA / tester | "What happens when the ball falls out of the level?" |
| Anyone learning Love2D | "What does `love.graphics.newQuad` do, and how does Inflate use it?" |

---

## 5. How it works (short)

```text
question
  → ① Query plan (AI call 1, Pydantic form):
       answer_type = explain / locate / show_code / write_code / out_of_scope
       search_in   = code / docs / both
  → ② Hybrid search (local, free): FAISS (meaning) + BM25 (exact words), merged with RRF,
       over the game-code index and/or the Love2D-docs index
  → ③ Answer or code (AI call 2): uses only the retrieved chunks, cites [1], [2]...
  → ④ Python checks (no AI): citations real, names real, Lua syntax valid;
       one retry, else "I couldn't answer this reliably."
  → ⑤ Output: answer + source list (file:line / PDF page) + exact code snippets + "uses:" list
```
Usually **2 AI calls** per question (1 for off-topic); a repeated question costs 0 (SQLite cache).

**How the two sources are chunked:**
| | Game code (`.lua`) | Love2D docs (PDF) |
|---|---|---|
| Strategy | AST-based (luaparser): one chunk per function, plus file headers, constant groups, top-level code | recursive character splitting (~1000 chars, 150 overlap) |
| Citation | 📄 `src/Ball.lua:244-277` | 📘 `02-types-1of2.pdf p.412` |

**Main tech:** Python, LangChain, Pydantic, Gemini, HuggingFace embeddings (all-MiniLM-L6-v2), FAISS,
BM25, luaparser, PyMuPDF, SQLite (cache), Streamlit.

---

## 6. How we prove it works
- A test set of ~20 questions (game code, Love2D docs, both, write-code, out-of-scope), with correct
  answers taken **by reading the source** (game files, Love2D PDF pages), written **before** the
  search was built — never taken from our own chunks.
- Split into dev (used while building) and test (used once at the end).
- Measured: search quality (Hit@k, MRR), answer correctness, correct refusals, valid-syntax % and
  real-names-only % for generated code.
- **Baseline:** the same questions asked to plain Gemini without retrieval, to show what RAG adds.
- Real numbers reported, including failures (as counts, e.g. "6/7").

---

## 7. Limits (stated honestly)
- Generated code is checked for **syntax and real names**, not for game-logic bugs. It is not run in
  the game automatically.
- Works for **this one game** and the Love2D docs; it is not a general coding assistant.
- Answers depend on search quality; if the right chunk isn't found, the assistant should say
  "I couldn't find that" rather than guess.
- Each message stands alone (no follow-up chat memory in this version).
