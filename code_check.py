"""Phase 5: check new Lua code from write_code answers (no AI): syntax + real names + 'uses:' list."""

import json
import re
from luaparser import ast, astnodes
from config import CHUNKS_DIR


def get_lua_blocks(answer):
    """The code inside ```lua ... ``` blocks of the answer."""
    return re.findall(r"```lua\s*\n(.*?)```", answer, flags=re.DOTALL)


def dotted_name(node):
    """A Name or a.b.c chain -> 'a.b.c'. Anything else (a[i], f().x) -> ''."""
    if isinstance(node, astnodes.Name):
        return node.id
    if isinstance(node, astnodes.Index) and node.notation == astnodes.IndexNotation.DOT:
        left = dotted_name(node.value)
        if left != "" and isinstance(node.idx, astnodes.Name):
            return left + "." + node.idx.id
    return ""


def collect_names(tree):
    """Walk the new code and sort its names into 4 sets:
    defined   = names the new code creates (functions, locals, arguments, new globals)
    called    = plain or dotted calls: 'clamp', 'Palette.set', 'love.graphics.rectangle'
    methods   = names called with ':', e.g. 'playBounce' from self:playBounce(1)
    constants = UPPER_CASE names, e.g. 'WALL_BOUNCE_MIN'"""
    defined = set()
    called = set()
    methods = set()
    constants = set()

    for node in ast.walk(tree):
        if isinstance(node, (astnodes.Function, astnodes.LocalFunction, astnodes.Method,
                             astnodes.AnonymousFunction)):
            if isinstance(node, astnodes.Method):
                defined.add(node.name.id)                           # Ball:shield -> 'shield'
            elif not isinstance(node, astnodes.AnonymousFunction):
                defined.add(dotted_name(node.name))
            for arg in node.args:
                if isinstance(arg, astnodes.Name):
                    defined.add(arg.id)
        elif isinstance(node, astnodes.Assign):                    # also covers LocalAssign
            for target in node.targets:
                if isinstance(target, astnodes.Name):
                    defined.add(target.id)
        elif isinstance(node, astnodes.Call):
            name = dotted_name(node.func)
            if name != "":
                called.add(name)
        elif isinstance(node, astnodes.Invoke):
            methods.add(node.func.id)
        elif isinstance(node, astnodes.Name) and node.id.isupper():
            constants.add(node.id)

    return defined, called, methods, constants


# ---- Part B: check every name against the real ones ----

symbols = json.loads((CHUNKS_DIR / "symbols.json").read_text(encoding="utf-8"))
GAME = symbols["game"]                                  # name -> "file:line"
ENGINE = set(symbols["love"])
LOCALS = set()
for names in symbols["locals"].values():
    LOCALS.update(names)
ALIASES = {}
for aliases in symbols["aliases"].values():
    ALIASES.update(aliases)
LUA_STANDARD = {"print", "pairs", "ipairs", "type", "tostring", "tonumber", "assert", "error",
                "pcall", "select", "unpack", "setmetatable", "getmetatable", "next", "require",
                "rawget", "rawset"}
LUA_LIBRARIES = ("math.", "string.", "table.", "os.", "coroutine.")


def resolve_alias(name):
    """'lg.rectangle' -> 'love.graphics.rectangle' (aliases from symbols.json)."""
    first = name.split(".")[0]
    if first in ALIASES:
        return ALIASES[first] + name[len(first):]
    return name


def find_method(method):
    """'playBounce' -> 'Ball:playBounce' if the game defines it, else ''."""
    for name in GAME:
        if name.endswith(":" + method):
            return name
    return ""


def engine_has_method(method):
    """True if any engine type has this method, e.g. 'play' -> Source:play."""
    for name in ENGINE:
        if name.endswith(":" + method):
            return True
    return False


def is_game_class(owner):
    """True if the game has methods on this class, e.g. 'Ball' (Ball:hurt)."""
    for name in GAME:
        if name.startswith(owner + ":"):
            return True
    return False


def check_code(answer):
    """Check every ```lua block. Returns (problems, uses).
    uses = ['Ball:playBounce → src/Ball.lua:433', ...] for the real game names the code uses."""
    blocks = get_lua_blocks(answer)
    if len(blocks) == 0:
        return ["The answer has no ```lua code block."], []
    problems = []
    uses = []
    has_function = False

    for code in blocks:
        try:
            tree = ast.parse(code)
        except Exception as error:
            problems.append("Lua syntax error: " + str(error)[:200])
            has_function = True                          # syntax error already reported
            continue
        for node in ast.walk(tree):
            if isinstance(node, (astnodes.Function, astnodes.LocalFunction, astnodes.Method)):
                has_function = True
            if isinstance(node, astnodes.Method):
                owner = dotted_name(node.source)          # player:takeSpikeDamage -> 'player'
                if not is_game_class(owner):
                    problems.append("`" + owner + "` is not a class in the game. Add methods only to real classes.")
        defined, called, methods, constants = collect_names(tree)

        for name in sorted(called):
            real = resolve_alias(name)
            first = real.split(".")[0]
            if name in defined or first in defined:
                continue
            if "." in real and first[0].islower() and first not in ("love", "math", "string", "table", "os"):
                continue                                 # self.x(), obj.fn(): a field, can't be checked
            if real in GAME:
                uses.append(real + " → " + GAME[real])
            elif real in ENGINE or name in LOCALS or name in LUA_STANDARD or real.startswith(LUA_LIBRARIES):
                continue
            else:
                problems.append("`" + name + "` does not exist in the game, the engine or standard Lua.")

        for method in sorted(methods):
            if method in defined:
                continue
            where = find_method(method)
            if where != "":
                uses.append(where + " → " + GAME[where])
            elif not engine_has_method(method):
                problems.append("Method `:" + method + "` does not exist in the game or the engine.")

        for name in sorted(constants):
            if name in defined:
                continue
            if name in GAME:
                uses.append(name + " → " + GAME[name])
            else:
                problems.append("Constant `" + name + "` does not exist in the game.")

    if not has_function:
        problems.append("The new code is not a whole function. Write the WHOLE new or changed "
                        "function, from 'function' to 'end'.")

    unique_uses = []
    for line in uses:
        if line not in unique_uses:
            unique_uses.append(line)
    return problems, unique_uses


# ---- Self-check: "python code_check.py" (no API calls) ----
if __name__ == "__main__":
    good = """```lua
function Ball:moveX(dt)
    if mabs(self.dx) > WALL_BOUNCE_MIN then
        self.dx = -self.dx * WALL_RESTITUTION
        self:playBounce(0.5)
        lg.rectangle('fill', 0, 0, 1, 1)
    end
end
```"""
    invented = """```lua
function Ball:shield()
    self:takeDamage(SHIELD_POWER)
    love.graphics.drawShield(self.x, self.y)
end
```"""
    broken = """```lua
function Ball:moveX(dt)
    if self.dx > 0 then
end
```"""
    fragment = """```lua
if player.shield then
    damage = damage / 2
end
```"""
    fake_class = """```lua
function player:takeSpikeDamage()
    self.health = self.health - SPIKE_DAMAGE
end
```"""
    for title, answer in [("good", good), ("invented", invented), ("broken", broken),
                          ("fragment", fragment), ("fake_class", fake_class)]:
        problems, uses = check_code(answer)
        print("\n" + title)
        print("   problems:", problems)
        print("   uses:    ", uses)
