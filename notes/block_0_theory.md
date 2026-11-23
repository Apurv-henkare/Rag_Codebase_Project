# Block 0: The project and the basics

No code in this block. It is the foundation for everything else.

---

## 1. What Inflate is

- Inflate is a real game I made and released: a **15-level platformer**.
- The player is a **ball that can grow and shrink** (a big ball smashes blocks, a small ball jumps differently).
- Written in **Lua**: **74 code files, about 12,000 lines**.
  - `src/Ball.lua`: the ball (move, jump, bounce, get hurt, pop)
  - `src/GameLevel.lua`: a level
  - `src/constants.lua`: the game's numbers (gravity, jump speed, damage)
- Built on a **game engine** called **LÖVE** (also called **Love2D**).
  A game engine is a ready-made toolkit of functions, so you don't write the basics yourself:
  - `love.graphics.rectangle(...)` draws a rectangle → **engine**
  - `love.audio.newSource(...)` loads a sound → **engine**
  - `Ball:moveX(...)` moves the ball → **my game code**

**Inflate = my code (74 files) + the LÖVE engine (the toolkit my code uses).**

---

## 2. The assistant, and its 2 sources

**The assistant** is the program built in this project (title in the app: **"Inflate Code Assistant"**).
You type a question about Inflate in a chat page and get an answer. It has 3 parts:

| Part | What it is | Its job |
|---|---|---|
| Our Python code | `search.py`, `rag.py`, `verify.py`, ... | finds the right pieces of code/docs, checks the answer |
| Gemini | Google's LLM, reached over the internet | reads the pieces we give it, writes the answer |
| The chat page | `app.py` (Streamlit), in the browser | where you ask and see the answer |

Gemini alone is **not** the assistant: it has never seen my code.
**Assistant = Gemini + our code that feeds it the right pieces and checks its answer.**

It answers only from **2 sources**:

| Source | Folder | What it is |
|---|---|---|
| 💻 Game code | `game_project/` | Inflate's 74 Lua files |
| 📘 Engine docs | `documents/` | the official LÖVE documentation as PDFs, **3,032 pages** (2 PDFs in the folder are not LÖVE docs and are skipped: `SKIP_PDFS` in `config.py`) |

**Why both:** my code **uses** engine functions but never **explains** them.
In `love.graphics.rectangle('fill', x, y, 1, 1)`:
- which file uses it and why → only the **game code** can tell
- what `'fill'` and the 4 numbers mean → only the **engine docs** can tell

| Question | Source needed |
|---|---|
| "What happens when the ball hits a wall?" | code |
| "What arguments does `love.keypressed` receive?" | docs |
| "Explain `love.graphics.rectangle` and show where the game uses it." | both |

What it can do: **explain**, **locate**, **show code**, **write code**, **refuse** off-topic requests
("Make me a Pong game."), and **say "I couldn't find that."** (e.g. "multiplayer lobby": Inflate has none).
Every answer cites its source (📄 `src/Ball.lua:242-277`, 📘 `06-modules.pdf p.444`), and Python checks it.

---

## 3. Why the project is needed: 4 problems

- A **function** is a named block of code that does one job (`Ball:jump()` makes the ball jump).
- A **constant** is a fixed number with a name (`SPIKE_DAMAGE = 25`).
- A **feature** is one thing the game does (the ball, spikes, jumping).

**Problem 1: one feature is spread across many files.**
The ball needs `Ball.lua`, `BallGroundState.lua`, `BallAirState.lua`, `BallPopState.lua` and `constants.lua`.
"Jump just after rolling off an edge" = `COYOTE_TIME = 0.08` in `constants.lua` + the timer in `BallGroundState.lua`.
→ The assistant searches all 74 files at once.

**Problem 2: the engine docs are huge and separate.**
Understanding one engine call means searching 3,032 pages separately from the code.
→ The assistant searches code and docs together.

**Problem 3: a general chatbot (ChatGPT, Gemini) has never seen Inflate.**
It learned from public internet text (its **training data**). Inflate's code is **private** (only on my PC),
so it **guesses**. Measured in this project:

| Test | Plain Gemini | Our assistant |
|---|---|---|
| Game-code facts (11) | 2 found | 8 found |
| Writing code (test w3) | used 6 names that don't exist | refused: "I couldn't answer this reliably." |
| Shows where facts came from | no | yes, file + line |

**Problem 4: game code and engine code look the same.**
`love` is a container (a Lua **table**) holding the engine's functions, and game code can add its own into it.
`love.keyboard.wasPressed` looks like the engine, but it is **game code** (`main.lua` line 49).
→ The assistant says which is which ("game function" / "engine function").

---

## 4. What an LLM is, and what a prompt is

**LLM** (Large Language Model), e.g. Gemini: a program that read a huge amount of internet text and learned
to **predict what text comes next**. It answers by writing the most likely reply, word by word.
It only knows what it read before:
- LÖVE docs: public → it knows them (plain Gemini found 8/8 docs facts)
- Inflate code: private → it doesn't (plain Gemini found 2/11 game-code facts)

**Prompt:** all the text we send to the LLM in one request.
**Gemini can only use (1) what it learned before and (2) what is inside the prompt.** It cannot open my files.

A real prompt (shortened) has 3 parts:
```
Rules: Use ONLY the numbered sources. Cite [n] after every fact. Never invent function names.
Sources:
[1] src/Ball.lua:242-277
function Ball:moveX(dt) ... if mabs(self.dx) > WALL_BOUNCE_MIN then self.dx = -self.dx * WALL_RESTITUTION ...
Question: What happens when the ball hits a wall?
```
**The whole project comes down to: put the right pieces of the code into the prompt.**

---

## 5. Hallucination and RAG

**Hallucination:** the LLM gives an answer that sounds confident and correct but is **made up**.
It always writes the most likely-looking reply, even when it doesn't know.

Real example: for "add a shield that halves spike damage", search missed the spike code, and Gemini wrote
`function player:takeSpikeDamage()`. There is **no `player`** in Inflate (the real code is `Ball` / `Ball:hurt`).
It would crash. (Our Python check caught it.)

**RAG = Retrieval-Augmented Generation**, the method this project uses:

| Step | Meaning | For "What happens when the ball hits a wall?" |
|---|---|---|
| Retrieval | find the right pieces | search finds `Ball:moveX` in `src/Ball.lua:242-277` |
| Augmented | add them to the prompt | `Sources: [1] src/Ball.lua:242-277 + code` |
| Generation | the LLM writes from them | "If faster than `WALL_BOUNCE_MIN`, it bounces back [1]" |

Gemini doesn't need to **know** Inflate: each time, we **show it** the right code.
**Rule: the answer can only be as good as the pieces we find.** That's why many blocks are about search.

---

## 6. The 2 phases

**Phase 1: build phase**: once, and again only when code or docs change (`python rebuild.py`).
```
74 Lua files + PDFs → cut into chunks (727 code, 4,772 docs) → made searchable (an index) → saved in data/
```
An **index** works like the index at the back of a book: a prepared list to jump to the right place fast.
Done in advance because it takes minutes; then each search takes under a second.

**Phase 2: question phase**: every message.
```
1. Plan   → Gemini decides the kind of answer and where to search
2. Search → find the best 5 chunks           (R)
3. Answer → put them in the prompt, Gemini writes   (A + G)
4. Check  → Python checks the answer
5. Show   → answer + sources + real code
```
Phase 1 makes the index; Phase 2 uses it. If a file changes and you don't rebuild, Phase 2 searches old
chunks, so the app warns **"Index out of date"**.
Blocks 1–10 build Phase 1 (plus measuring search); Blocks 11–18 build Phase 2 and the chat page.

---

## 7. Why RAG and not other options

| | Paste everything into the prompt | Fine-tuning | **RAG** ✅ |
|---|---|---|---|
| Fits / fast | ❌ too much text (beyond the **context window**, the max an LLM reads at once) | ✅ | ✅ only 5 pieces |
| Shows the source | ❌ | ❌ | ✅ file + line |
| When the code changes | ✅ | ❌ retrain | ✅ rebuild in minutes |
| Cost | high every question | high to train | low |

**Fine-tuning** = training the model further on my own data. Costly, must be redone on every code change,
can't cite sources, and can still hallucinate.

---

## 🎤 Interview corner

**30 seconds:**
> "I built a RAG assistant for my own released game, Inflate. It answers questions about the game's Lua code
> and the LÖVE engine documentation. A general LLM has never seen private code, so it hallucinates: in my
> baseline, plain Gemini recalled 2 of 11 game-code facts and used 6 non-existent functions when writing
> code. My system finds the right code and doc pieces, makes Gemini answer only from them with citations,
> and Python checks every citation and name before the answer is shown."

**Q: Why not just use ChatGPT?**
It has never seen my private code, so it guesses. Measured: 2/11 facts without retrieval, 8/11 with it.

**Q: Why RAG instead of fine-tuning?**
The code changes often; fine-tuning needs retraining and can't cite sources. RAG: rebuild in minutes, every answer points to a file and line.

**Q: What is hallucination, and how does your project handle it?**
Confidently made-up output (e.g. `player:takeSpikeDamage`). RAG gives the model the real code; Python checks
catch the rest: if a name isn't real, retry once, then refuse instead of showing a wrong answer.

---

## ✅ Check yourself
1. What is the project, and what are its 2 sources?
2. Why can't plain Gemini answer questions about Inflate well?
3. What does each letter of RAG do, using the wall-bounce question?
