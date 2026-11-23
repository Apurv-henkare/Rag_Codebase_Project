"""Step 3.6: rebuild everything from the source files, and check if the index is out of date."""

import hashlib
import json
import subprocess
import sys
from config import PROJECT_DIR, CODE_DIR, DOCS_DIR, SKIP_PDFS, INDEX_DIR

MANIFEST = INDEX_DIR / "manifest.json"
STEPS = ["load_code.py", "load_docs.py", "build_symbols.py", "build_index.py"]


def source_files():
    """Every file the index is built from: the Lua files and the Love2D PDFs."""
    files = []
    for path in sorted(CODE_DIR.rglob("*.lua")):
        files.append(path)
    for path in sorted(DOCS_DIR.glob("*.pdf")):
        if path.name not in SKIP_PDFS:
            files.append(path)
    return files


def make_manifest():
    """{ 'game_project/src/Ball.lua': 'sha256 hash', ... } for every source file."""
    manifest = {}
    for path in source_files():
        name = path.relative_to(PROJECT_DIR).as_posix()
        manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return manifest


def changed_files():
    """Files edited, added or removed since the last rebuild. [] means the index is up to date."""
    if not MANIFEST.exists():
        return ["(no index built yet)"]
    old = json.loads(MANIFEST.read_text(encoding="utf-8"))
    new = make_manifest()
    changed = []
    for name in new:
        if old.get(name) != new[name]:
            changed.append(name)
    for name in old:
        if name not in new:
            changed.append(name)
    return changed


def rebuild():
    """Run every build step in order, then save the manifest."""
    for script in STEPS:
        print("running", script, "...")
        subprocess.run([sys.executable, str(PROJECT_DIR / script)], check=True)
    MANIFEST.write_text(json.dumps(make_manifest(), indent=2), encoding="utf-8")


# ---- Run: "python rebuild.py" (takes a few minutes) ----
if __name__ == "__main__":
    rebuild()
    print("index up to date:", changed_files() == [])
