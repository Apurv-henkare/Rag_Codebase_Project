# Block 4: Chunking the game code (`load_code.py`)

---

## 1. The overall plan

**Goal:** cut the 74 Lua files into chunks, each one meaningful piece of code, so search can find exactly the right piece.
**Rule:** every useful line of code must end up in some chunk (a line in no chunk can never be found or shown to Gemini).

A Lua file has: a header comment (`--[[ ... ]]`), code outside functions, and functions (most of the code).
Level files (`src/levels/`) are a special case: mostly a map drawn with letters.

### The 6 kinds of chunk (727 in total)

| Kind | Count | What it holds | Real example |
|---|---|---|---|
| `method` | 238 | a function belonging to a class (has `:`) | `Ball:jump`, `src/Ball.lua` 344–353 |
| `function` | 213 | a plain function | `love.keyboard.wasPressed`, `main.lua` 49–51 |
| `top_level` | 187 | code outside functions | `INPUT_KEYS = {...}`, `main.lua` 53–60 |
| `file_header` | 57 | the `--[[ ]]` description at the top of a file | `main.lua` 1–7 ("INFLATE. A bouncing-ball platformer where air is your life…") |
| `constants_group` | 17 | a group of numbers in `constants.lua` | `AIR_MAX = 100`, `SPIKE_DAMAGE = 25`, `GROW_COST = 10`… (63–80) |
| `level_meta` | 15 | a level file without its map rows | `level1.lua`: "Level 1 - First bounce", the legend (`J spring`, `K key`…), `name = 'FIRST BOUNCE'` |

### Order, per file
```
1. level file?        → level_meta (done)                  [Step 8]
2. find the functions → method / function                  [Steps 2–5]
3. mark those lines as used
4. leftover lines     → file_header, top_level / constants_group   [Steps 6–7]
```
Functions first, leftovers second → every line lands in exactly one chunk.

---

## 2. Finding the functions (top-level only)

```python
def find_functions(source):
    tree = ast.parse(source)
    found = []
    for node in tree.body.body:               # ONLY things written directly in the file
        if isinstance(node, (astnodes.Function, astnodes.LocalFunction, astnodes.Method)):
            found.append((node.first_token.line, node.last_token.line))
    return found
```
In: one file's text. Out: (start, end) per function, e.g. `(244, 277)` for `Ball:moveX`.

`tree` = the file → `.body` = its block → `.body` = the **list of things written directly in the file**.
It does not look inside functions (unlike `ast.walk` in Block 3, which counted all **452** functions).

**Why only outer functions:** a function can sit inside another, like a box inside a box (`src/LevelMaker.lua`):
```lua
function LevelMaker.build(...)          ← line 196: outer
    local function charAt(col, row)     ← line 205: inner
        ...
    end                                 ← line 209
end
```
`charAt` is already inside the `LevelMaker.build` chunk. A separate chunk would save lines 205–209 **twice**
(search could return both, wasting 1 of 5 places), and `charAt` alone lacks context (`rows` comes from the outer function).

---

## 3. Name, kind, and the comments above (244 → 242)

**Name** (from the first line):
```python
text = line.strip()                        # "function Ball:moveX(dt)"
if text.startswith("local "): text = text[len("local "):]
text = text[len("function "):]             # "Ball:moveX(dt)"
return text.split("(")[0].strip()          # "Ball:moveX"
```
Saved as the chunk's `symbol`.

**Kind:** `":" in name` → `method` (belongs to a class), else `function`.

**Comments above:** move the start up while the line above is a comment (`--`):
```python
while start > 1 and lines[start - 2].strip().startswith("--"):
    start = start - 1
```
```
244 → line 243 "-- Side wind ..." comment?          yes → 243
243 → line 242 "-- horizontal move ..." comment?    yes → 242
242 → line 241 blank?                                stop
```
→ chunk **242–277** (`📄 src/Ball.lua:242-277` in the app). `lines[start - 2]` because Python lists count from 0.
Why: the comment says "wall collision" in plain English, so "what happens when the ball hits a **wall**?" matches.

- Works for **any number** of comment lines (it keeps going until a non-comment line).
- Stops at a **blank line** or code; `start > 1` stops at the top of the file.
- Comments **inside** a function are always included (they are within its start–end lines).
- A comment above with a blank line between → not in this chunk (goes to a `top_level` group, or skipped if only a banner).

---

## 4. Long functions: 60-line parts, and the tiny `end` fix

Long chunks are bad: the embedding model reads only about the first 1,000 characters (~25–40 lines of code),
and a huge chunk fills the prompt. So parts of at most **60 lines** (`CODE_CHUNK_MAX_LINES = 60`).

```python
part_start = start
while part_start <= end:
    part_end = part_start + CODE_CHUNK_MAX_LINES - 1
    if part_end > end:
        part_end = end
    parts.append((part_start, part_end))
    part_start = part_end + 1
```
Real example `GameLevel:checkBall`, lines 253–373 (121 lines):
```
part 1: 253–312 (60)   part 2: 313–372 (60)   part 3: 373–373 (1 line)
```
**The issue:** part 3 is only `end`: meaningless, takes a slot in the index, could waste 1 of 5 places;
part 2 also loses its own closing line.
Part 2 ends with the spike check (`ball:hurt(SPIKE_DAMAGE, ball:centerX())`, line 368) and `end` at 372.

**The fix:** a last part under 10 lines is merged into the previous part:
```python
if len(parts) > 1:
    last_start, last_end = parts.pop()
    if last_end - last_start + 1 < 10:
        prev_start, prev_end = parts.pop()
        parts.append((prev_start, last_end))
    else:
        parts.append((last_start, last_end))
```
→ final **253–312** and **313–373** (exactly what's saved). Both keep `symbol: GameLevel:checkBall`.
Why 10: leftovers are often several closing lines (`end`, `end`, `return result`, `end`), still meaningless alone.
Why 60: most functions are never cut, and a part stays one readable idea.

---

## 5. `make_chunk` and the code metadata

```python
code = "\n".join(lines[start - 1:end])
title = symbol if symbol else kind
text = file_name + " - " + title + "\n" + code
metadata = {"source": "code", "file": file_name, "start_line": start,
            "end_line": end, "symbol": symbol, "kind": kind}
return Document(page_content=text, metadata=metadata)
```
- **Text** (searched + shown to Gemini) starts with `src/Ball.lua - Ball:moveX`, which makes the file and function names searchable words.
- **Metadata** (kept separately): `source`, `file`, `start_line`, `end_line`, `symbol`, `kind`.
- `Document` (LangChain) = a container with `page_content` + `metadata`. All saved in `data/chunks/code_chunks.json`.

| Field | Used later for |
|---|---|
| `source` | 📄 vs 📘; code gets a snippet from disk, docs get the PDF text |
| `file` | the citation `src/Ball.lua:242-277`; opening the real file |
| `start_line`, `end_line` | the citation numbers; copying exactly those lines from disk; measuring search |
| `symbol` | the searchable first line; knowing which function a split part belongs to |
| `kind` | special rules, e.g. `level_meta` gets no snippet |

Metadata is **not** used to **find** chunks (search uses the text); it is used **after** search, to show and prove the source.

### How metadata travels (query → embedding → citation)
**Only the text is embedded; metadata is linked by position.**

Build:
```
chunk list (code_chunks.json): position 512 → text + metadata (Ball:moveX, src/Ball.lua 242–277)   [512 = example]
embedding: text of 512 → 384 numbers (metadata NOT embedded)
FAISS: vector 512 ↔ chunk 512   (same order: the position is the link)
```
Question:
```
"What happens when the ball hits a wall?" → 384 numbers
FAISS → positions [512, 488, 130, ...]; BM25 → positions; RRF → top 5 positions
chunks[512] → text + metadata back together
prompt: [1] src/Ball.lua:242-277 + text           (label from metadata)
Gemini: "... it bounces back [1]"                  (writes only the number)
[1] → chunks[512].metadata → 📄 src/Ball.lua:242-277 + real lines 242–277 copied from disk
```
If the file changed since indexing, the copied lines don't match the saved text → "this file changed since indexing - run rebuild.py".

**Without metadata:** Gemini would have to name the file (and could invent `src/Player.lua:10-40`), no real code
under the answer, no code/docs distinction, the useless level map would be shown.

---

## 6. Code outside functions: header and groups

1. **Mark used lines**: every line inside a function chunk goes into `used_lines` and is skipped from now on.
2. **File header**: if line 1 starts with `--[[`, lines up to the first `]]` → `file_header` (e.g. `main.lua` 1–7).
3. **Group the leftover lines.** A new group starts when:
   - a function chunk appears (code before and after a function is about different things)
   - a blank line is followed by a comment (a new topic):
     ```python
     new_section = line.startswith("--") and n > 1 and lines[n - 2].strip() == ""
     ```
   Blank lines are separators, not kept in groups.

`main.lua` → groups **9–12** (`setDefaultFilter`, `require`, `local mmin`) and **53–60**
(`-- game actions -> keys …` + `INPUT_KEYS`). The comment stays with its code, so "keys" helps search.

---

## 7. What is skipped; constants_group vs top_level

**Skip 1: comment-only groups (banners).** Real example, `src/Ball.lua` 441–443:
```lua
---------------------------------------------------------------------------
-- SIZE CHANGE
---------------------------------------------------------------------------
```
```python
has_code = False
for n in group:
    if not lines[n - 1].strip().startswith("--"):
        has_code = True
if not has_code:
    continue
```
A banner directly above code (e.g. `-- AIR (health) AND INTERACTIONS` above `SPIKE_DAMAGE = 25`) is in the same group → kept, and helps search.

**Skip 2: tiny groups** (`len(code) < 30`), e.g. a lone `Ball = Class{}` (14 characters).

**Kind:** groups in `src/constants.lua` → `constants_group` (17); all other files → `top_level` (187).
Same grouping code; only the label differs (constants.lua holds every tuning number).
Long groups are split into 60-line parts with the same `split_range`.

---

## 8. Level files (`level_meta`)

A level file = description + legend (useful) + a map of letter rows (noise, and long):
```lua
"............................................................",
```
Every map row starts with `"`, so keep everything else:
```python
for line in lines:
    if not line.strip().startswith('"'):
        kept.append(line)
```
Answers: "What does Level 1 teach?", "Which letter places a spring?" (`J spring`). The `-- 10 20 30` column ruler stays (a harmless comment).
Detected by `lua_path.parent.name == "levels"` → one chunk, no other steps.
Metadata lines cover the whole file (1–30, map included), so `level_meta` gets **no snippet** (it would print the map).

---

## 9. Result, design, limits

**Result:** `python load_code.py` → **727 chunks** → `data/chunks/code_chunks.json`.

**Went wrong → fixed:** banner-only chunks (skip no-code groups); a 1-line `end` chunk (merge parts under
10 lines); explanation comments left out (move the start up over comments).

**Why this design:**
| Option | Problem |
|---|---|
| whole file = one chunk | the embedding model reads ~1,000 characters; one file fills the prompt |
| every N lines | cuts through functions |
| every 1,000 characters | the same; breaks an `if` in half |
| **one chunk per function (AST)** ✅ | one complete, named idea per chunk; exact citations |

Docs are prose (cut by size, Block 5); code has structure (cut at functions).

**Limits:** split parts lose shared context; the grouping rules match Inflate's style and may not fit another
codebase; inner functions are found only through their parent.

**Connects:** takes the AST (Block 3) and `CODE_CHUNK_MAX_LINES` (Block 1); gives 727 chunks to embedding
(Block 8) and search (Block 9); the metadata powers citations, snippets, the "file changed" warning and measuring search.

---

## 🎤 Interview corner

**30 seconds:**
> "For the game code I used AST-based chunking with luaparser: one chunk per top-level function, so every chunk is
> a complete, named unit like `Ball:moveX`. I include the comment lines just above each function, because they
> describe it in plain English, which helps retrieval. Functions over 60 lines are split, with tiny leftover parts
> merged back. Code outside functions becomes header, constants and top-level chunks, and level files keep only
> their description without the tile map. 727 chunks, each with file, line range, symbol and kind as metadata,
> which powers exact citations."

**Q: Why not a normal text splitter on code?** It cuts through functions; the AST gives exact boundaries, so a citation points to a whole function.

**Q: Very long functions?** 60-line parts with the same symbol; a last part under 10 lines (usually `end`) is merged back.

**Q: What's the metadata for?** Only the text is embedded; metadata stays linked by position. After search it gives
the exact citation, lets me copy the real lines from disk, and detects files changed since indexing.

---

## ✅ Check yourself
1. Why are only top-level functions made into chunks?
2. How does `Ball:moveX` (244–277) become the chunk 242–277?
3. What problem did the "merge parts under 10 lines" rule fix? Use `GameLevel:checkBall`.
4. How does a citation `[1]` become `src/Ball.lua:242-277`, if metadata is never embedded?
5. What is skipped, and why?
