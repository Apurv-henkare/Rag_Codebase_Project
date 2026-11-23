"""SQLite cache for LLM answers: same model + same prompt → saved answer, 0 API calls."""

import hashlib
import sqlite3
from config import CACHE_DIR

CACHE_FILE = CACHE_DIR / "llm_cache.db"
API_CALLS = {"count": 0}     # real Gemini calls since the program started (the app shows it)


def make_key(model, prompt):
    """Turn model name + full prompt into a fixed 64-character hash."""
    text = model + "\n" + prompt
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def open_db():
    """Open the database file (create folder + table the first time)."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(CACHE_FILE)
    conn.execute("CREATE TABLE IF NOT EXISTS cache (key TEXT PRIMARY KEY, response TEXT)")
    return conn


def get_cached(model, prompt):
    """Return the saved answer, or None if this prompt was never asked."""
    conn = open_db()
    row = conn.execute("SELECT response FROM cache WHERE key = ?",
                       (make_key(model, prompt),)).fetchone()
    conn.close()
    return row[0] if row else None


def save_cached(model, prompt, response):
    """Save an answer (replaces an old one with the same key).
    It runs right after every real Gemini call, so it also counts the API calls."""
    API_CALLS["count"] = API_CALLS["count"] + 1
    conn = open_db()
    conn.execute("INSERT OR REPLACE INTO cache (key, response) VALUES (?, ?)",
                 (make_key(model, prompt), response))
    conn.commit()
    conn.close()


# ---- Self-check: run "python cache.py" (no API call) ----
if __name__ == "__main__":
    save_cached("test-model", "test prompt", "test answer")
    print("same prompt     ->", get_cached("test-model", "test prompt"))
    print("changed prompt  ->", get_cached("test-model", "test prompt!"))
    print("other model     ->", get_cached("other-model", "test prompt"))
    print("cache file:", CACHE_FILE)
