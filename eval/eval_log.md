# Eval log

Every eval run and every change made because of one, in order, with before → after numbers.
Worse results are logged too.

## Rules (to keep results honest)

1. Test questions (`split: "test"`) are never used while building. The test split runs **once**, at the end.
2. Before the test run, freeze everything: code, prompts, scorer, `test_set.json`. No changes after.
3. Never edit expected answers (`gold`, `must_mention`, `must_use`) after seeing outputs.
4. Report the strict score, plus a separate note for answers that were correct on manual review.
5. The baseline (plain Gemini) uses the same questions and the same scorer.
6. Limits: 15 dev + 8 test questions is small. The numbers are a rough signal, not proof.

---

## Search eval (`eval_search.py`, 13 dev questions with gold)

| # | Change | Hit@5 | MRR | Misses |
|---|---|---|---|---|
| 1 | Baseline: FAISS + BM25 + RRF, plain tokenizer | 9/13 | 0.60 | — |
| 2 | Code-aware tokenizer (dotted names, camelCase, `_`) | 8/13 | — | worse |
| 3 | Eval fix: docs gold matched on page **title**, not exact page; + focused docs query (search docs with only the Love2D names in the question) | 11/13 | 0.77 | c3, w2 |
| 4 | Search with the planner's `search_query` **only** | 9/13 | 0.55 | c3, c7, d5, w2 — **worse, reverted** |
| 5 | RAG-Fusion: question + planner `search_query`, 4 lists merged with RRF (**current**) | 11/13 | 0.67 | c3, w2 |

Note on #3: changing the docs match from exact page to title was a fix to the scorer (a wiki page
can span several PDF pages), made before the test split was ever run.

Note on #5: same hits as #3, lower MRR (correct chunk sometimes at rank 2–3 instead of 1).
Kept because all 5 chunks go to Gemini anyway, and it fixed write_code retrieval in `rag.py`
(w1 found `Ball:moveX` only with the planner phrase).

---

## Answer eval (`eval_answers.py`, 15 dev questions)

### Run 1 (2026-11-22): current pipeline

**Passed 8/15 | right type 13/15 | reliable 15/15**

| Id | Result | Why |
|---|---|---|
| c1, c7, d1, d3, w1, o1, o3, h1 | PASS | |
| c3 | FAIL 1/2 | search miss: `FALL_OUT_MARGIN` chunk not found |
| c4 | FAIL 2/3 | search miss: constants chunk (`GROW_COST = 10`) not in top 5, so no value |
| c5 | FAIL 1/2 | wording: answer says "game function", expected "game code". Correct on manual review |
| d5 | FAIL 0/2 | planner: "make and run a minimal LÖVE game" → `out_of_scope` (prompts hide the engine name) |
| b1 | FAIL 1/4 | planner: chose `show_code` instead of `explain`, so a 1–2 sentence answer |
| b3 | FAIL 2/3 | wording: "sets its pitch" instead of `setPitch`. Small, fair miss |
| w2 | FAIL 1/2 | search miss: spike check / `Ball:hurt` not found; Gemini invented `handleSpikeCollision(player)`, which the checks can't catch (new function, `player` is its own argument) |

Manual review: c5 correct in meaning (strict FAIL kept).

### Ideas from run 1

| Idea | For | Status |
|---|---|---|
| Python override: if the message names the engine (`löve`, `love2d`, `love.`) and the plan is `out_of_scope` → `explain` + `docs` (`rag.py`, `ENGINE_WORDS` in `config.py`) | d5 | applied, then **reverted** (see Revert below) |
| Planner rule: "explain" beats "show me" (`answer_type` description in `planner.py`) | b1 | applied, then **reverted** (see Revert below) |
| Fix D: also add chunks that define / use a found name (`GROW_COST`, `SPIKE_DAMAGE`) | c4, w2 | not applied |
| ~~Change c5 `must_mention` to "game function"~~ | c5 | **rejected**: editing the answer key after seeing the output |

### Run 2 (2026-11-22): after the d5 override + b1 planner rule

**Passed 10/15 | right type 15/15 | reliable 15/15** (run 1: 8/15, 13/15, 15/15)

| Id | Run 1 | Run 2 | Why |
|---|---|---|---|
| b1 | FAIL 1/4 | **PASS 4/4** | planner now picks explain |
| w2 | FAIL 1/2 | PASS 2/2 | **false pass** (manual review): "hurt" only matched "thorns hurt like spikes"; the new code is an invented `applyDamage(amount, hasShield)` that is not connected to the game |
| d5 | FAIL 0/2 | FAIL 0/2 | type now right, but **bug in the override**: `out_of_scope_parts` still held the whole question, so the answer was told to ignore it → "I couldn't find that." + "Skipped: …" |
| c5 | FAIL 1/2 | FAIL 0/2 | **worse**: now "I couldn't find that." Cause not known yet (the plan is not saved in results) |
| c3, c4, b3 | FAIL | FAIL | same as run 1 |

Strict 10/15. After manual review: 9/15 (w2 is not a real pass).

### Revert (2026-11-22)

Both run-2 changes reverted (user decision): the engine override in `rag.py` / `ENGINE_WORDS` in
`config.py`, and the "explain beats show me" rule in `planner.py`. Code is back to the run-1 state,
so run 1 (8/15) is the current answer-eval result again.

Re-run after the revert: **8/15 passed | 13/15 right type | 15/15 reliable**, identical to run 1 (all from cache).

---

## Baseline (plain Gemini, no search)

### Run 1 (2026-11-22): `baseline.py`, 13 dev questions with facts (o1, h1 skipped: fixed replies)

Same model, temperature and framing ("Inflate … in-house game engine"); same `count_found` scorer.
"Ours" = answer eval run 1.

| Id | Plain Gemini | Ours | Note |
|---|---|---|---|
| c1 | 0/2 | 2/2 | |
| c3 | 1/2 | 1/2 | |
| c4 | 0/3 | 2/3 | |
| c5 | 0/2 | 1/2 | |
| c7 | 1/2 | 2/2 | |
| d1 | 3/3 | 3/3 | |
| d3 | 3/3 | 3/3 | |
| d5 | 2/2 | 0/2 | ours: planner said out_of_scope |
| b1 | 4/4 | 1/4 | ours: planner chose show_code (short answer) |
| b3 | 2/3 | 2/3 | |
| w1 | 0/1 (1 code problem) | 1/1 | |
| w2 | 0/2 (5 code problems) | 1/2 | |
| o3 | 1/1 | 1/1 | |

**All facts found: plain 5/13 | ours 6/13**

By group (facts found):

| Group | Plain Gemini | Ours |
|---|---|---|
| Game code (c1, c3, c4, c5, c7) | 2/11 | **8/11** |
| Docs (d1, d3, d5) | **8/8** | 6/8 |
| Docs + code (b1, b3) | **6/7** | 3/7 |
| Write code (w1, w2) | 0/3, 6 code problems | **2/3**, 0 code problems shown (checks) |

Reading: RAG wins clearly where Gemini has never seen the data (the game code). Plain Gemini
wins on the engine docs because the engine is public and in its training data. Our two docs
losses (d5, b1) come from planner type mistakes, not from search.
Not measured by this scorer: plain Gemini gives no citations and its answers are not checked.

## Test split (run once, at the end)

**Frozen 2026-11-22** before the test run: code, prompts, scorer and `test_set.json` are as in
dev run 1 (after the revert). Only change: `SPLIT = "test"` in `eval_answers.py`
(`baseline.py` reads the same setting). No changes after this point.

### Final test run (2026-11-22), 8 questions, run once

**Passed 6/8 | right type 8/8 | reliable 7/8**

| Id | Result | Note |
|---|---|---|
| c2 | FAIL 0/3 | "I couldn't find that.": the spike damage code was not retrieved (same search weakness as dev w2) |
| c6 | PASS 2/2 | **weak pass** (manual review): explains the switch with `gStateMachine:change` from `PauseState`, and says the sources don't show the `StartState` menu code (the gold) |
| c8 | PASS | correctly "I couldn't find that." (there is no multiplayer lobby) |
| d2 | PASS 3/3 | |
| d4 | PASS 3/3 | |
| b2 | PASS 2/2 | found all 3 game files that create images + the docs page |
| w3 | FAIL 0/2 | "I couldn't answer this reliably.": the checks rejected both tries, so it refused instead of showing bad code |
| o2 | PASS | correctly out of scope |

Strict 6/8. Both failures are safe failures (a refusal, not a wrong answer).

### Final test baseline (2026-11-22), plain Gemini, 6 test questions with facts (c8, o2 skipped)

| Id | Plain Gemini | Ours |
|---|---|---|
| c2 | 0/3 | 0/3 |
| c6 | 1/2 | 2/2 |
| d2 | 2/3 | 3/3 |
| d4 | 3/3 | 3/3 |
| b2 | 1/2 | 2/2 |
| w3 | 1/2, **6 code problems** (invented names) | 0/2 (refused: "couldn't answer reliably") |

**All facts found: plain Gemini 1/6 | ours 4/6.** Facts found in total: plain 8/15, ours 10/15.
On w3 plain Gemini found more words but its code used 6 names that don't exist; ours refused.

---

## Final numbers (for the README)

| | Dev (15) | Test (8, run once) |
|---|---|---|
| Search Hit@5 / MRR | 11/13, 0.67 | not measured |
| Answers passed (strict) | 8/15 | **6/8** |
| Right answer type | 13/15 | **8/8** |
| Reliable (not refused) | 15/15 | 7/8 |
| All facts found, plain Gemini vs ours | 5/13 vs 6/13 | **1/6 vs 4/6** |

Main known weakness: search for code that is reached through a constant (spike damage: c2, w2).
Small question sets: treat these as a rough signal.
