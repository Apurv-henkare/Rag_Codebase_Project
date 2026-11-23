"""Step 1.1: look at the data before chunking (reading only, changes nothing)."""

import pymupdf
from config import CODE_DIR, DOCS_DIR, SKIP_PDFS

# ---- Part 1: check each PDF ----
for pdf_path in sorted(DOCS_DIR.glob("*.pdf")):
    if pdf_path.name in SKIP_PDFS:
        continue

    doc = pymupdf.open(pdf_path)
    lengths = []
    long_pages = 0
    revision_pages = 0

    for page in doc:
        text = page.get_text()
        lengths.append(len(text))
        if len(text) > 1000:
            long_pages = long_pages + 1
        if "· revision" in text:
            revision_pages = revision_pages + 1

    lengths.sort()
    middle = lengths[len(lengths) // 2]
    print(pdf_path.name, "| pages:", len(lengths), "| shortest:", lengths[0],
          "| middle:", middle, "| longest:", lengths[-1],
          "| over 1000:", long_pages, "| revision lines:", revision_pages)

# ---- Part 2: show one sample page ----
doc = pymupdf.open(DOCS_DIR / "06-modules.pdf")
text = doc[9].get_text()          # page 10 in the PDF viewer (code counts from 0)
print("\n--- sample: 06-modules.pdf page 10 ---")
print(text[:500])

# ---- Part 3: count Lua files and lines ----
file_count = 0
line_count = 0
for lua_path in CODE_DIR.rglob("*.lua"):
    file_count = file_count + 1
    line_count = line_count + len(lua_path.read_text(encoding="utf-8").splitlines())
print("\nLua files:", file_count, "| lines:", line_count)
