"""Step 1.4: turn the Love2D documentation PDFs into chunks (LangChain Documents)."""

import pymupdf
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from config import DOCS_DIR, CHUNKS_DIR, SKIP_PDFS, DOC_CHUNK_SIZE, DOC_CHUNK_OVERLAP
from load_code import save_chunks


def get_title(text):
    """Return the page name from its revision line, or '' if the page has none.
    'love.audio.getDopplerScale · revision 14660 · last edited ...' -> 'love.audio.getDopplerScale'"""
    for line in text.splitlines():
        if " · revision " in line:
            return line.split(" · revision ")[0].strip()
    return ""


def load_pages():
    """One Document per PDF page (near-empty pages skipped)."""
    pages = []
    for pdf_path in sorted(DOCS_DIR.glob("*.pdf")):
        if pdf_path.name in SKIP_PDFS:
            continue

        title = ""
        for page in pymupdf.open(pdf_path):
            text = page.get_text()
            if len(text.strip()) < 30:
                continue

            new_title = get_title(text)
            if new_title:
                title = new_title          # a new wiki page starts here

            metadata = {"source": "docs", "pdf": pdf_path.name,
                        "page": page.number + 1, "title": title}
            pages.append(Document(page_content=text, metadata=metadata))
    return pages


def make_doc_chunks(pages):
    """Split pages into ~1000-character chunks and put the pdf, page and title at the start."""
    splitter = RecursiveCharacterTextSplitter(chunk_size=DOC_CHUNK_SIZE,
                                              chunk_overlap=DOC_CHUNK_OVERLAP)
    chunks = splitter.split_documents(pages)

    for chunk in chunks:
        m = chunk.metadata
        prefix = m["pdf"] + " p." + str(m["page"]) + " - " + m["title"]
        chunk.page_content = prefix + "\n" + chunk.page_content
    return chunks


# ---- Run: "python load_docs.py" builds and saves all doc chunks ----
if __name__ == "__main__":
    pages = load_pages()
    chunks = make_doc_chunks(pages)
    save_chunks(chunks, CHUNKS_DIR / "docs_chunks.json")

    print("pages:", len(pages), "| chunks:", len(chunks))
    for chunk in chunks:
        if chunk.metadata["title"] == "love.graphics.rectangle":
            print(chunk.page_content[:400])
            break
