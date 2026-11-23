"""Step 1.3 check: can luaparser read all 74 Lua files and give line numbers for every function?"""

from luaparser import ast, astnodes
from config import CODE_DIR

parsed_files = 0
failed_files = 0
function_count = 0
missing_lines = 0

for lua_path in sorted(CODE_DIR.rglob("*.lua")):
    source = lua_path.read_text(encoding="utf-8")

    try:
        tree = ast.parse(source)
    except Exception as error:
        failed_files = failed_files + 1
        print("FAILED:", lua_path.name, "-", error)
        continue

    parsed_files = parsed_files + 1

    for node in ast.walk(tree):
        if isinstance(node, (astnodes.Function, astnodes.LocalFunction, astnodes.Method)):
            function_count = function_count + 1

            if node.first_token is None or node.last_token is None:
                missing_lines = missing_lines + 1

            # proof: we know Ball:moveX is at lines 244-277
            if lua_path.name == "Ball.lua" and isinstance(node, astnodes.Method) and node.name.id == "moveX":
                print("Ball:moveX -> lines", node.first_token.line, "to", node.last_token.line)

print("parsed:", parsed_files, "| failed:", failed_files,
      "| functions:", function_count, "| missing lines:", missing_lines)
