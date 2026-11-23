"""Step 1.5: symbol index - every real name in the game code and the Love2D docs."""

import json
from config import CODE_DIR, CHUNKS_DIR
from load_code import get_function_name


def is_name(text):
    """True for names like 'Ball', 'GRAVITY', 'Ball.update', 'Mesh:getVertexMap'."""
    return text != "" and text.replace(".", "_").replace(":", "_").isidentifier()


def scan_game_code():
    """Find global names, file-local names and love.* aliases in every Lua file."""
    game = {}
    locals_by_file = {}
    aliases_by_file = {}

    for lua_path in sorted(CODE_DIR.rglob("*.lua")):
        file_name = lua_path.relative_to(CODE_DIR).as_posix()
        lines = lua_path.read_text(encoding="utf-8").splitlines()
        file_locals = []
        file_aliases = {}

        for n in range(1, len(lines) + 1):
            line = lines[n - 1].split("--")[0].rstrip()      # drop comments at the end of the line
            stripped = line.strip()

            # aliases, anywhere in the file (also inside functions): "local lg = love.graphics"
            if stripped.startswith("local ") and "=" in stripped:
                left, right = stripped[len("local "):].split("=", 1)
                names = left.split(",")
                values = right.split(",")
                for i in range(len(names)):
                    if i < len(values) and values[i].strip().startswith("love.") and is_name(values[i].strip()):
                        file_aliases[names[i].strip()] = values[i].strip()

            if line == "" or line.startswith(" ") or line.startswith("\t"):
                continue                                     # the rules below: top-level lines only

            # 1. functions: "function Ball:moveX(dt)" / "local function clamp(v)"
            if line.startswith("function ") or line.startswith("local function "):
                name = get_function_name(line)
                if line.startswith("local "):
                    file_locals.append(name)
                elif name not in game:
                    game[name] = file_name + ":" + str(n)
                continue

            # 2. top-level locals: "local mabs, mmin = math.abs, math.min"
            if line.startswith("local ") and "=" in line:
                left = line[len("local "):].split("=")[0]
                for name in left.split(","):
                    file_locals.append(name.strip())
                continue

            # 3. globals: "GRAVITY = 500" / "Ball = Class{...}"
            if "=" in line:
                left = line.split("=")[0].strip()
                if is_name(left) and left not in game:
                    game[left] = file_name + ":" + str(n)

        if file_locals:
            locals_by_file[file_name] = file_locals
        if file_aliases:
            aliases_by_file[file_name] = file_aliases

    return game, locals_by_file, aliases_by_file


def get_love_names():
    """Every Love2D page title that is a name, e.g. 'love.graphics.rectangle', 'Mesh:getVertexMap'."""
    chunks = json.loads((CHUNKS_DIR / "docs_chunks.json").read_text(encoding="utf-8"))
    names = set()
    for chunk in chunks:
        title = chunk["metadata"]["title"]
        if is_name(title):
            names.add(title)
    return sorted(names)


# ---- Run: "python build_symbols.py" (needs docs_chunks.json from load_docs.py) ----
if __name__ == "__main__":
    game, locals_by_file, aliases_by_file = scan_game_code()
    love = get_love_names()

    symbols = {"game": game, "love": love, "locals": locals_by_file, "aliases": aliases_by_file}
    path = CHUNKS_DIR / "symbols.json"
    path.write_text(json.dumps(symbols, indent=2, ensure_ascii=False), encoding="utf-8")

    print("game names:", len(game), "| love names:", len(love),
          "| files with locals:", len(locals_by_file), "| files with aliases:", len(aliases_by_file))
    print("Ball:moveX ->", game.get("Ball:moveX"))
    print("love.keyboard.wasPressed ->", game.get("love.keyboard.wasPressed"))
    print("GameLevel.lua aliases ->", aliases_by_file.get("src/GameLevel.lua"))
    print("love.graphics.rectangle is a Love2D name:", "love.graphics.rectangle" in love)
