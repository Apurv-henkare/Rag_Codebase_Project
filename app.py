"""Phase 7: the chat page. Run: streamlit run app.py"""

import math
import time
import streamlit as st
import cache
from rag import ask
from rebuild import changed_files

LATENCY_PERCENTILE = 95      # p95 = 95% of answers took this long or less

EXAMPLES = ["What happens when the ball hits a wall?",
            "Add a bounce sound when the ball hits a wall.",
            "What arguments does love.keypressed receive?"]

st.set_page_config(page_title="Inflate Code Assistant", page_icon="🎈", layout="wide")

# bigger, easier-to-read text (on top of baseFontSize in .streamlit/config.toml)
st.markdown("""
<style>
.block-container { max-width: 1150px; padding-top: 2rem; }
[data-testid="stMarkdownContainer"] p, [data-testid="stMarkdownContainer"] li { font-size: 1.15rem; line-height: 1.7; }
[data-testid="stChatInput"] textarea { font-size: 1.15rem; }
[data-testid="stMetricValue"] { font-size: 2.2rem; }
[data-testid="stMetricLabel"] p { font-size: 1.05rem; }
[data-testid="stCaptionContainer"] { font-size: 1rem; }
code { font-size: 1rem; }
.stButton button { font-size: 1.05rem; padding: 0.6rem 1rem; width: 100%; }
</style>
""", unsafe_allow_html=True)


@st.cache_data(ttl=60)
def index_status():
    """Files changed since the last rebuild (checked at most once a minute)."""
    return changed_files()


def percentile(values, p):
    """The value that p% of the values are at or below, e.g. p95 of the answer times."""
    ordered = sorted(values)
    index = math.ceil(p / 100 * len(ordered)) - 1
    return ordered[index]


def show_details(message):
    """Sources, real names used, exact code from disk, and the numbers for one answer."""
    if message["sources"]:
        st.markdown("**Sources**")
        for line in message["sources"]:
            st.markdown("- " + line)
    if message["uses"]:
        st.markdown("**Uses** (real game names in the new code)")
        for line in message["uses"]:
            st.markdown("- " + line)
    if message["snippets"]:
        st.markdown("**What the sources say** (click to open)")
    for label, text, language in message["snippets"]:
        if language == "lua":
            icon = "📄 "
        else:
            icon = "📘 "
        with st.expander(icon + label):
            st.code(text, language=language, wrap_lines=True)
    st.caption(message["type"] + " · searched: " + message["search_in"]
               + " · API calls: " + str(message["calls"])
               + " · " + str(round(message["seconds"], 2)) + " s")


if "messages" not in st.session_state:
    st.session_state.messages = []
    st.session_state.latencies = []
    st.session_state.api_calls = 0

st.title("🎈 Inflate Code Assistant")
st.markdown("Ask about the **Inflate game code** or the **engine docs**. "
            "Every answer cites its sources, and Python checks it before you see it.")

clicked = ""
if not st.session_state.messages:
    st.markdown("**Try one of these:**")
    columns = st.columns(len(EXAMPLES))
    for i in range(len(EXAMPLES)):
        if columns[i].button(EXAMPLES[i]):
            clicked = EXAMPLES[i]

# ---- old messages ----
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        if message["role"] == "assistant":
            show_details(message)

# ---- new message ----
question = st.chat_input("Ask about the game code or the engine docs")
if not question:
    question = clicked                 # an example button was clicked
if question:
    st.session_state.messages.append({"role": "user", "content": question})
    with st.chat_message("user"):
        st.markdown(question)

    with st.chat_message("assistant"):
        with st.spinner("Searching and checking..."):
            calls_before = cache.API_CALLS["count"]
            start = time.time()
            error_text = ""
            try:
                result = ask(question)
            except Exception as error:
                result = None
                error_text = str(error)
            seconds = time.time() - start
            calls = cache.API_CALLS["count"] - calls_before

        if result is None:
            st.error("Something went wrong: " + error_text[:300])
        else:
            message = {"role": "assistant", "content": result["answer"],
                       "sources": result["sources"], "uses": result["uses"],
                       "snippets": result["snippets"],
                       "type": result["plan"].answer_type, "search_in": result["plan"].search_in,
                       "calls": calls, "seconds": seconds}
            st.markdown(message["content"])
            show_details(message)
            st.session_state.messages.append(message)
            st.session_state.latencies.append(seconds)
        st.session_state.api_calls = st.session_state.api_calls + calls

# ---- sidebar (drawn last, so the numbers include the newest answer) ----
with st.sidebar:
    st.header("Inflate Code Assistant")
    st.write("Ask how the Inflate game works, where something is, to see code, "
             "or to write new code. Answers cite their sources and are checked by Python.")

    changed = index_status()
    if changed:
        st.warning("Index out of date: " + str(len(changed)) + " file(s) changed. "
                   "Run `python rebuild.py`.")
        with st.expander("Changed files"):
            for name in changed:
                st.write(name)
    else:
        st.success("Index up to date")

    st.subheader("This session")
    latencies = st.session_state.latencies
    st.metric("Answers", len(latencies))
    st.metric("Gemini API calls", st.session_state.api_calls)
    if latencies:
        p = percentile(latencies, LATENCY_PERCENTILE)
        total = 0
        for value in latencies:
            total = total + value
        st.metric("p" + str(LATENCY_PERCENTILE) + " latency", str(round(p, 2)) + " s")
        st.metric("Average latency", str(round(total / len(latencies), 2)) + " s")
    st.caption("API calls: 0 means the answer came from the cache.")

    if st.button("🗑️ Clear chat"):
        st.session_state.messages = []
        st.rerun()
