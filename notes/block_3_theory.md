# Block 3: Looking at the data first (`checks/inspect_data.py`, `checks/check_lua_parse.py`)

---

## 1. Why look before building

The next job is cutting files into chunks, and **how** to cut depends on what the files look like:
how long a PDF page is, whether each docs page has a usable title, whether every Lua file can be read.
**Looking first is cheaper than fixing later.**

---

## 2. `checks/inspect_data.py` (reads only, changes nothing, 0 API calls)

Run: `python -m checks.inspect_data` (`-m checks.` lets it find `config.py` in the main folder).

Main part (measure every PDF page):
```python
for page in doc:
    text = page.get_text()             # one page's text (library: pymupdf reads text out of PDFs)
    lengths.append(len(text))          # length in characters
    if len(text) > 1000:
        long_pages = long_pages + 1
    if "· revision" in text:
        revision_pages = revision_pages + 1
```
It also prints one sample page and counts the Lua files: **74 files, 12,070 lines**.

### Real output
```
01-guides.pdf      | pages: 49  | shortest: 66 | middle: 1962 | longest: 4206 | over 1000: 43  | revision lines: 10
02-types-1of2.pdf  | pages: 761 | shortest: 10 | middle: 839  | longest: 4232 | over 1000: 254 | revision lines: 640
03-types-2of2.pdf  | pages: 797 | shortest: 10 | middle: 859  | longest: 5022 | over 1000: 298 | revision lines: 639
04-other-pages.pdf | pages: 341 | shortest: 0  | middle: 944  | longest: 6800 | over 1000: 164 | revision lines: 234
05-categories.pdf  | pages: 81  | shortest: 10 | middle: 1038 | longest: 2043 | over 1000: 41  | revision lines: 27
06-modules.pdf     | pages: 921 | shortest: 10 | middle: 915  | longest: 5066 | over 1000: 374 | revision lines: 506
07-tutorials.pdf   | pages: 99  | shortest: 62 | middle: 1833 | longest: 3089 | over 1000: 75  | revision lines: 30
```

### What each column means (06-modules.pdf)
Sizes are in **characters** of one page's text.

| Column | Value | Meaning |
|---|---|---|
| pages | 921 | pages in the PDF |
| shortest | 10 | the emptiest page (almost blank) |
| middle | 915 | the **median**: half the pages are shorter, half longer |
| longest | 5066 | the fullest page |
| over 1000 | 374 | pages longer than 1,000 characters |
| revision lines | 506 | pages containing `· revision` (= the start of an article) |

### Middle (median) vs average
```python
lengths.sort()                          # shortest → longest
middle = lengths[len(lengths) // 2]     # 921 // 2 = 460 → the 461st page: 460 before, 460 after
```
An **average** is pulled up by a few huge pages. Example: `800, 850, 900, 950, 5000` → average **1,700**,
but 4 of 5 pages are under 1,000. The **middle** is **900**: what a normal page really looks like.
Our PDFs have such giant pages (longest 5,066 vs middle 915), so the middle is the honest "typical page".

### Revision lines and titles
The LÖVE docs were a **wiki** (a website where each function has its own article; each edit saves a new
**revision**). In the PDF, the **first page of each article** has a line like:
```
love.audio.getDopplerScale · revision 14660 · last edited ...
```
So a revision line = **the start of a new article + its title**.
06-modules.pdf: 921 pages, 506 revision lines → 506 articles; the other 415 pages are **continuations**
(an article too long for one page goes on without a new title line).
Example: `love.graphics.rectangle` starts on **p.444** and continues on **p.445**, which is why both appeared as sources.

### What the numbers decided
| Seen | Decided |
|---|---|
| shortest 10 / 0 (near-empty pages) | skip pages under 30 characters (17 pages) → 3,049 pages become **3,032** |
| many pages over 1,000 | cut docs into pieces of about **1,000 characters** (Block 5) |
| revision lines < pages | **carry the title over** to continuation pages (Block 5) |
| 74 Lua files of code | code needs a different cut: by function, using an **AST** |

---

## 3. Docs chunk size: 1,000 characters, 150 overlap (decided here, built in Block 5)

**Why 1,000:**
1. The embedding model (all-MiniLM-L6-v2, Block 8) reads only about **256 tokens**. A **token** is a small
   piece of a word, about 4 characters in English → 256 × 4 ≈ **1,000 characters**. Longer text is cut off and ignored.
2. A typical page (middle) is 840–1,960 characters; 374 of 921 pages in 06-modules are over 1,000.
   Short pages stay whole; long pages are cut.

**Why 150 overlap:** a cut can land mid-sentence ("The mode argument can be" | "'fill' or 'line'").
The last 150 characters of a chunk are repeated at the start of the next, so a sentence at the border is whole in at least one chunk.

Result: **3,032 pages → 4,772 chunks**. In `config.py`:
```python
DOC_CHUNK_SIZE    = 1000
DOC_CHUNK_OVERLAP = 150
```

---

## 4. The title is stored and carried over (built in Block 5)

Main part of `load_docs.py`:
```python
title = ""                               # start of each PDF: no title yet
for page in pymupdf.open(pdf_path):
    text = page.get_text()
    new_title = get_title(text)          # text before " · revision " on this page, or ""
    if new_title:
        title = new_title                # a new article starts: remember its name
    metadata = {..., "page": page.number + 1, "title": title}   # every page gets the remembered title
```
| Page | Revision line? | Title stored |
|---|---|---|
| p.444 | yes, `love.graphics.rectangle · revision …` | `love.graphics.rectangle` |
| p.445 | no (continuation) | `love.graphics.rectangle` (kept) |
| next article | yes | the new name |

- Pages before the first article (cover, contents) → title stays `""`. Reset per PDF so titles never leak between PDFs.
- Honest limit: if an article's revision line were missing, its pages would keep the previous title (not seen in our data).

The title is stored **in the metadata** and **at the start of the chunk text** (`06-modules.pdf p.444 - love.graphics.rectangle`).
It is used for: **search** (continuation chunks still match the name), the **list of 1,843 engine names**
(Block 6), and **measuring search** (a docs hit = any chunk with the right title, Block 9).

---

## 5. What an AST is

**Problem:** one chunk should be one whole function (e.g. `Ball:moveX`, start to end). Searching the text for
`function` … `end` fails: in Lua, `end` closes `if`, `for`, `while` **and** `function`. `Ball:moveX` has
4 inner `end`s before its own one at line 277; stopping at the first `end` would cut the function in half.

**AST = Abstract Syntax Tree:** the code turned into a tree showing what is inside what, the way the computer
reads it. Library: **luaparser**.
```
File (Ball.lua)
 ├── Method: Ball:moveX        ← lines 244–277
 │    ├── LocalAssign: newX, tile = ...
 │    ├── If: tile and self:isBig() ...
 │    │    └── If: breakTilesInBox(...) > 0
 │    ├── If: hitWall
 │    │    └── If: mabs(self.dx) > WALL_BOUNCE_MIN
 ├── Method: Ball:jump         ← lines 344–353
```
Each box is a **node**. The parser matched every `end` to its own `if`/`function`, and each node knows its start and end line.

| Need | Plain text | AST |
|---|---|---|
| where a function starts and ends | confused by inner `end`s | exact (244–277) |
| its name | guess from the line | `Ball:moveX` |
| method or plain function | guess | the node type says |
| is the code valid? | can't tell | broken code fails to parse (reused in Block 15 to check new code) |

---

## 6. `checks/check_lua_parse.py`: testing the parser on all 74 files

Main part:
```python
tree = ast.parse(source)                         # one file → tree (error = file failed)
for node in ast.walk(tree):                      # visit every node
    if isinstance(node, (astnodes.Function, astnodes.LocalFunction, astnodes.Method)):
        function_count = function_count + 1
        if node.first_token is None or node.last_token is None:
            missing_lines = missing_lines + 1
```
3 kinds of function node:
- `Function`: `function clamp(...)`
- `LocalFunction`: `local function helper(...)` (visible only in its file)
- `Method`: `function Ball:moveX(...)` (belongs to a class)

`first_token` / `last_token` = the first and last piece of the function's text, each with its line number.
Proof check: we knew `Ball:moveX` is at 244–277 from reading the file; the parser agreed.

### Real output
```
Ball:moveX -> lines 244 to 277
parsed: 74 | failed: 0 | functions: 452 | missing lines: 0
```
→ safe to build code chunking on the AST.

**Why the app shows 242–277, not 244–277:** in Block 4 (`load_code.py`) the comment lines just above a
function (242–243: "horizontal move with wall collision, level edges and block breaking…") are added to
its chunk, so search matches questions like "what happens when the ball hits a wall?" better.

**Why 452 functions but fewer function chunks:** the 452 include small functions nested inside other
functions; chunks are made only for top-level functions (Block 4).

---

## ✅ Check yourself
1. Why did we look at the data before writing the chunking code?
2. What does a revision line tell us, and what happens on a continuation page?
3. Why can't we find a function's end by searching for the word `end`?
4. Why is the `Ball:moveX` chunk 242–277 when the function is 244–277?
