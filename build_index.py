"""Step 3.1: embed all chunks and save one FAISS index per source (code, docs)."""

import json
import faiss
import numpy as np
from langchain_huggingface import HuggingFaceEmbeddings
from config import CHUNKS_DIR, INDEX_DIR, EMBEDDING_MODEL


def get_embedder():
    """The local embedding model (downloads ~90 MB the first time)."""
    return HuggingFaceEmbeddings(model_name=EMBEDDING_MODEL,
                                 encode_kwargs={"normalize_embeddings": True})


def load_chunks(source):
    """Read code_chunks.json or docs_chunks.json."""
    path = CHUNKS_DIR / (source + "_chunks.json")
    return json.loads(path.read_text(encoding="utf-8"))


def build_faiss(source, embedder):
    """Embed every chunk of one source and save the FAISS index. Vector i = chunk i."""
    chunks = load_chunks(source)
    texts = []
    for chunk in chunks:
        texts.append(chunk["text"])

    vectors = embedder.embed_documents(texts)             # list of 384-number lists
    vectors = np.array(vectors, dtype="float32")          # FAISS needs a float32 array

    index = faiss.IndexFlatIP(vectors.shape[1])           # 384 = vector size
    index.add(vectors)

    INDEX_DIR.mkdir(parents=True, exist_ok=True)
    faiss.write_index(index, str(INDEX_DIR / (source + ".faiss")))
    return index.ntotal


# ---- Run: "python build_index.py" (takes a few minutes for the docs) ----
if __name__ == "__main__":
    embedder = get_embedder()
    for source in ["code", "docs"]:
        count = build_faiss(source, embedder)
        print(source, "index:", count, "vectors")
