"""Step 1.3: turn the Lua game code into chunks (LangChain Documents)."""

import json
from luaparser import ast, astnodes
from langchain_core.documents import Document
from config import CODE_DIR, CHUNKS_DIR, CODE_CHUNK_MAX_LINES


def split_range(start, end):
    """Cut a line range into parts of at most CODE_CHUNK_MAX_LINES lines.
    Example with 60: (1, 150) -> [(1, 60), (61, 120), (121, 150)]"""
    parts = []
    part_start = start
    while part_start <= end:
        part_end = part_start + CODE_CHUNK_MAX_LINES - 1
        if part_end > end:
            part_end = end
        parts.append((part_start, part_end))
        part_start = part_end + 1

    # a very small last part (e.g. only "end") is joined to the part before it
    if len(parts) > 1:
        last_start, last_end = parts.pop()
        if last_end - last_start + 1 < 10:
            prev_start, prev_end = parts.pop()
            parts.append((prev_start, last_end))
        else:
            parts.append((last_start, last_end))
    return parts


def make_chunk(file_name, lines, start, end, symbol, kind):
    """Build one Document from lines start..end of a file."""
    code = "\n".join(lines[start - 1:end])
    if symbol:
        title = symbol
    else:
        title = kind
    text = file_name + " - " + title + "\n" + code
    metadata = {"source": "code", "file": file_name, "start_line": start,
                "end_line": end, "symbol": symbol, "kind": kind}
    return Document(page_content=text, metadata=metadata)


# ---- Part 1: function chunks ----

def find_functions(source):
    """Return (start_line, end_line) for each top-level function in the file."""
    tree = ast.parse(source)
    found = []
    for node in tree.body.body:
        if isinstance(node, (astnodes.Function, astnodes.LocalFunction, astnodes.Method)):
            found.append((node.first_token.line, node.last_token.line))
    return found


def get_function_name(line):
    """'function Ball:moveX(dt)' -> 'Ball:moveX'"""
    text = line.strip()
    if text.startswith("local "):
        text = text[len("local "):]
    text = text[len("function "):]
    return text.split("(")[0].strip()


def make_function_chunks(lua_path):
    """One Document per top-level function, with the comment lines just above it."""
    file_name = lua_path.relative_to(CODE_DIR).as_posix()     # e.g. "src/Ball.lua"
    source = lua_path.read_text(encoding="utf-8")
    lines = source.splitlines()                               # lines[0] is line 1
    chunks = []

    for start, end in find_functions(source):
        name = get_function_name(lines[start - 1])

        # move start up over comment lines directly above the function
        while start > 1 and lines[start - 2].strip().startswith("--"):
            start = start - 1

        if ":" in name:
            kind = "method"
        else:
            kind = "function"

        for part_start, part_end in split_range(start, end):
            chunks.append(make_chunk(file_name, lines, part_start, part_end, name, kind))

    return chunks


# ---- Part 2: chunks for code between functions ----

def find_header_end(lines):
    """If the file starts with a --[[ ]] comment, return its last line number, else 0."""
    if len(lines) == 0 or not lines[0].strip().startswith("--[["):
        return 0
    for n in range(1, len(lines) + 1):
        if "]]" in lines[n - 1]:
            return n
    return 0


def make_other_chunks(lua_path, used_lines):
    """Chunks for code outside functions: file header, constants groups, top-level code."""
    file_name = lua_path.relative_to(CODE_DIR).as_posix()
    lines = lua_path.read_text(encoding="utf-8").splitlines()
    chunks = []

    # 1. file header
    header_end = find_header_end(lines)
    if header_end > 0:
        chunks.append(make_chunk(file_name, lines, 1, header_end, "", "file_header"))
        for n in range(1, header_end + 1):
            used_lines.add(n)

    # 2. group the remaining lines; a blank line + comment line starts a new group
    groups = []
    current = []
    for n in range(1, len(lines) + 1):
        line = lines[n - 1].strip()

        if n in used_lines:                  # a function chunk: close the open group
            if current:
                groups.append(current)
                current = []
            continue

        new_section = line.startswith("--") and n > 1 and lines[n - 2].strip() == ""
        if new_section and current:
            groups.append(current)
            current = []

        if line != "":                       # keep only non-blank line numbers
            current.append(n)

    if current:
        groups.append(current)

    # 3. one chunk per group (skip tiny ones like "return Ball")
    if file_name == "src/constants.lua":
        kind = "constants_group"
    else:
        kind = "top_level"

    for group in groups:
        start = group[0]
        end = group[-1]
        code = "\n".join(lines[start - 1:end])
        if len(code) < 30:
            continue

        # skip groups that are only comments (section banners, no code)
        has_code = False
        for n in group:
            if not lines[n - 1].strip().startswith("--"):
                has_code = True
        if not has_code:
            continue

        for part_start, part_end in split_range(start, end):
            chunks.append(make_chunk(file_name, lines, part_start, part_end, "", kind))

    return chunks


# ---- Part 3: level files ----

def make_level_chunk(lua_path):
    """One chunk per level file: everything except the grid rows (lines starting with a quote)."""
    file_name = lua_path.relative_to(CODE_DIR).as_posix()
    lines = lua_path.read_text(encoding="utf-8").splitlines()

    kept = []
    for line in lines:
        if not line.strip().startswith('"'):
            kept.append(line)

    text = file_name + " - level_meta\n" + "\n".join(kept)
    metadata = {"source": "code", "file": file_name, "start_line": 1,
                "end_line": len(lines), "symbol": "", "kind": "level_meta"}
    return Document(page_content=text, metadata=metadata)


def make_file_chunks(lua_path):
    """All chunks for one Lua file: other chunks first, then function chunks."""
    if lua_path.parent.name == "levels":
        return [make_level_chunk(lua_path)]

    function_chunks = make_function_chunks(lua_path)

    used_lines = set()
    for chunk in function_chunks:
        for n in range(chunk.metadata["start_line"], chunk.metadata["end_line"] + 1):
            used_lines.add(n)

    other_chunks = make_other_chunks(lua_path, used_lines)
    return other_chunks + function_chunks


# ---- Part 4: all files + save ----

def load_all_code():
    """Chunks for every .lua file in the game."""
    all_chunks = []
    for lua_path in sorted(CODE_DIR.rglob("*.lua")):
        all_chunks.extend(make_file_chunks(lua_path))
    return all_chunks


def save_chunks(chunks, path):
    """Save Documents to a JSON file as a list of {text, metadata}."""
    data = []
    for chunk in chunks:
        data.append({"text": chunk.page_content, "metadata": chunk.metadata})
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


# ---- Run: "python load_code.py" builds and saves all code chunks ----
if __name__ == "__main__":
    chunks = load_all_code()
    save_chunks(chunks, CHUNKS_DIR / "code_chunks.json")

    counts = {}
    for chunk in chunks:
        kind = chunk.metadata["kind"]
        if kind not in counts:
            counts[kind] = 0
        counts[kind] = counts[kind] + 1

    print("total chunks:", len(chunks))
    print("by kind:", counts)
    print("saved to:", CHUNKS_DIR / "code_chunks.json")
