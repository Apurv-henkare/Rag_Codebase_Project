"""All settings for the Inflate RAG project, in one place.

Other files import from here, e.g.:  from config import CODE_DIR, TOP_K
Run "python config.py" to check that folders and the API key are found.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# ---- Folders ----
PROJECT_DIR = Path(__file__).parent          # the folder this file is in
CODE_DIR    = PROJECT_DIR / "game_project"   # Inflate's Lua source code
DOCS_DIR    = PROJECT_DIR / "documents"      # the LÖVE (Love2D) wiki PDFs
DATA_DIR    = PROJECT_DIR / "data"
CHUNKS_DIR  = DATA_DIR / "chunks"            # chunks saved as JSON (Phase 1)
INDEX_DIR   = DATA_DIR / "index"             # FAISS + BM25 indexes (Phase 3)
EVAL_DIR    = PROJECT_DIR / "eval"           # test set + results (Phase 2, 6)
CACHE_DIR   = PROJECT_DIR / "cache"          # SQLite cache (step 0.5)

SKIP_PDFS = ["injection.pdf", "vv2.pdf"]     # PDFs in documents/ that are not Love2D docs
# ---- Secret key (read from .env, never written in code) ----
load_dotenv(PROJECT_DIR / ".env")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# ---- Models ----
GEMINI_MODEL    = "gemini-3.1-flash-lite"    # the LLM (checked in step 0.5)
GEMINI_TIMEOUT     = 60    # seconds before one Gemini request is given up
GEMINI_MAX_RETRIES = 2     # how many times a failed / timed-out request is tried again
TEMPERATURE     = 0                         # 0 = same question gives same answer (needed for caching + evals)
EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"   # local, free, 384 numbers per chunk

# ---- Chunking (Phase 1) ----
DOC_CHUNK_SIZE    = 1000   # max characters per doc chunk (embedding model reads ~256 tokens ≈ 1000 chars)
DOC_CHUNK_OVERLAP = 150    # characters repeated between neighbour chunks so a sentence isn't cut in half
CODE_CHUNK_MAX_LINES = 60  # longer functions / code blocks are cut into parts of at most 60 lines

# ---- Search (Phase 3) ----
TOP_K            = 5       # chunks sent to the LLM when searching one index
TOP_K_PER_SOURCE = 3       # chunks from EACH index when search_in = "both"
SEARCH_CANDIDATES = 20     # how many chunks FAISS and BM25 each return before the RRF merge
RRF_K            = 60      # RRF formula: score = 1 / (60 + rank)

# ---- Answer checks (Phase 4-5) ----
MAX_RETRIES        = 1     # if Python checks fail, ask the LLM once more, then give up
MAX_SNIPPETS_SHOWN = 5     # max code snippets shown under an answer

# ---- Fixed replies ----
NOT_FOUND    = "I couldn't find that."
NOT_RELIABLE = "I couldn't answer this reliably."
OUT_OF_SCOPE = "I only write code for the Inflate project."
HELP_TEXT    = "Ask me about the Inflate game code or the LÖVE docs."


# ---- Self-check: run "python config.py" ----
if __name__ == "__main__":
    for name, path in [("CODE_DIR", CODE_DIR), ("DOCS_DIR", DOCS_DIR)]:
        status = "exists" if path.exists() else "MISSING"
        print(f"{name}: {path}  [{status}]")

    if GEMINI_API_KEY:
        print(f"GEMINI_API_KEY: set ({len(GEMINI_API_KEY)} characters)")
    else:
        print("GEMINI_API_KEY: NOT SET - check your .env file")
