# Retrospective — Feature 1 (Blank-box walking skeleton)

**Date:** 2026-06-18
**Scope:** F1 end-to-end through the autonomous SDLC Factory orchestrator (doc stage + 10 implementation stories).
**Runtime:** The Python orchestrator drove every gate autonomously (running locally). This was **not** a human-conducted "dogfood" run — all gate verdicts, fix cycles, and `failed-needs-human` label flips were emitted programmatically. Where a human touched the run, it was to clear an escalation, not to conduct the pipeline.

> **Read this first — the headline finding:** *Every single Feature-1 user story escalated to `failed-needs-human` at least once* (most of them 2–4 times). An early draft of this analysis claimed "9 of 11 shipped clean" — that was wrong. It was read off the **PR review verdicts**, which only show the code-review gate. The authoritative record is the **issue label history**, where the orchestrator posts a `Gate: … — FAIL` comment every time it flips a story to `failed-needs-human`. Read against that record, the escalation rate was 100%.

---

## 1. What actually happened

### 1.1 Doc stage (before any code)

The Feature's Spec + Plan went through `feature-doc-gauntlet` **twice as a fail** before passing:

1. **Fail 1** — four `check-seam-cynicism` findings: coverage-gate fixtures captured from the wrong boundary (raw coverlet, not ReportGenerator's merged output); an *external* seam (the build toolchain) with no grounded authority; an overloaded Seam 3 hiding the Serilog on-disk write; a manual-only proof of an *automatable* write. Closed by `/fix-feature-docs`.
2. **Fail 2** — one `check-artefact-consistency` finding: `Roadmap.md` F1 said the coverage gate "passes vacuously" and the Feature "ships no testable production code", contradicting the Spec/Plan design that landed `LoggingSetup` as real gated code. Resolved by a **human decision** (amend the higher-authority Roadmap rather than revert the design — recorded as Spec §7 R3).
3. **Pass** — full fresh re-run, all three leaves green.

### 1.2 Implementation stage — per-story escalation census

Ten implementation stories (#22 excluded: manual launch verification, human-by-design). Every one passed through `failed-needs-human`:

| Story | Escalations | Reasons (in order) |
|---|---|---|
| #18 spine | 1 | readiness **misroute** (graded against Feature 2) → human "false-fail" clear |
| #19 gate + self-test | ≥2 | readiness misroute; **code-review-loop** (hit the round cap) |
| #20 MAUI head | 1 | readiness — blocked-by #18 while #18 was itself needs-human |
| #21 CI pipeline | 4+ | readiness misroute → blocked-by #19 → blocked-by #20; **push failure**; **code-review-loop** |
| #23 XXE harden | 2 | readiness misroute (Feature 3); blocked-by #19 + an uncovered AC |
| #24 fail-closed | 2 | readiness — blocked-by #19 (needs-human) ×2 |
| #25 least-priv token | 4 | readiness — no plan; blocked-by #21 ×; **ambiguous AC3 (allowlist)** |
| #26 SHA-pin | 4 | readiness misroute (F4); blocked-by #21 ×2; **"/tdd passed but no commits"** |
| #27 lockfiles | 2 | readiness misroute (F4); blocked-by #21 + unspecified proof mechanism |
| #28 secret-scan | 3 | readiness misroute (F4); blocked-by #21 ×2; tool + canary mechanism undefined |

Result: **10/10 stories escalated; ~27 distinct escalations across the feature.**

---

## 2. Why they escalated — root causes, ranked by blast radius

The dominant causes are **not** implementation quality. Ranked by how many escalations each produced:

### Cause A — By-id gate identity bug (the universal first-touch failure)

Every story's **first** readiness check resolved "Story #N" by matching N against **`PRD.md`'s internal user-story numbering**, not the GitHub issue number. So issue **#18** was graded against *PRD user-story 18* ("see the current Weather Condition as an icon and label") — a **Feature 2** item; #23 → Feature 3; #26/#27/#28 → Feature 4. Every finding ("no Feature 2 Plan", "gauntlet not run", "five §9 open questions deferred") was true *of the wrong feature*.

The #18 clear-back comment names the root cause exactly — *"a GitHub issue number (#18) and a PRD user-story number (18) are different namespaces"* — and points at the fix: **`kitcox-dev/enate-claude-skills#19`**, an identity guard for the three by-id gates (`check-implementation-readiness`, `enate-to-stories`, `check-security-design`).

**One skill defect bounced every story on first contact, each requiring a human to recognise the false-fail and re-clear.** This is the single biggest contributor and has nothing to do with the code, the Spec, or the orchestrator's logic.

### Cause B — Dependency-ordering cascade (amplifier)

F1 was decomposed into a serial blocked-by chain: #20←#18; #21←#19,#20; #23/#24←#19; #25/#26/#27/#28←#21. Once a foundation story sat in `failed-needs-human` (from Cause A, then Cause D), every dependent *correctly* failed readiness — *"blocker is needs-human; the file you must edit doesn't exist."* Because #19 and #21 bounced repeatedly, their dependents re-failed on every orchestrator sweep. **The gate behaved correctly; the decomposition shape amplified a few root failures into a dozen escalations.**

### Cause C — Generated hardening stories with non-AFK-implementable ACs

readiness correctly refused stories whose acceptance criteria couldn't be met without guessing:
- **#25** — AC3 "explicit allowlist": contents, location, and format all undefined.
- **#27** — AC3 "a proof": proof mechanism unspecified (failing CI run? dedicated step? pasted output?).
- **#28** — tool deferred ("gitleaks *or equivalent*"), canary verification mechanism undefined, "no implementation artefact telling the agent what to add where."
- **#23** — "bound input size so an oversized report can't OOM the runner" is in *What to build* but covered by no AC.

These are **story-quality defects from `enate-to-stories` / `check-security-design`**, not the Developer Agent. They also overlap with code-review findings — #23/#24's XXE + fail-closed work is exactly what the gauntlet independently raised as blockers on #19 (double-surfacing the same concern as both a downstream story *and* a review blocker).

### Cause D — Code-review loops to exhaustion (#19, #21) — the only "code quality" bucket

Both ran code-review rounds until they hit the loop cap → `failed-needs-human` (reason `code-review-loop`). Drivers:
- **A dev loop that couldn't run the real Windows CI:** #21 opened with a **red build** (NETSDK1112, missing `-r win-x64`) — the agent could not compile the MAUI head locally, so the defect surfaced at review instead of at TDD.
- **A spec-contract the TDD step under-tested:** #19 shipped `-lt` where Spec §5 Seam 1 says the gate passes *iff* `covered == valid`; the fixer had to *add* the `covered > valid` test case the original suite never wrote.
- **Reviewers pulling sibling-story scope:** robustness findings (malformed XML, null-attribute coercion, the exit-2 path) overlapping #23/#24.

### Cause E — Orchestrator / agent runtime faults (each burned an escalation)

- **#21** — `push_branch failed: git push failed: returncode=1` → orchestrator FAIL (reason `implementation`).
- **#26** — `"/tdd returned pass but no commits found on the story branch"` → FAIL: the agent reported success but produced nothing.
- **#19, #26** — malformed verdict comments (`Gate: <unknown> — FAIL — trailing json block is not valid JSON`): the orchestrator's own verdict serialization broke and registered as a fail/extra round.

These are plumbing defects — not artefact or code-quality problems — but each consumed a round.

---

## 3. The honest bottom line

Every story escalated, and the **largest cause was a gate-identity bug that had nothing to do with the code, the Spec, or the orchestrator's decision logic** — it mis-resolved which work item it was grading and failed all ten on a phantom. Strip that out and the next-biggest cause is the **serial dependency decomposition** that let each stuck foundation story knock down its whole subtree. Genuine code-quality loops (#19, #21) were real but third in line — and even those trace to a dev loop with no Windows build.

The factory's gates mostly did their job. They were fed a numbering bug, a brittle dependency chain, under-specified generated stories, and some flaky plumbing. The escalation rate is a story about **inputs and tooling**, not about the Developer Agent writing bad code.

F1 is also the worst feature to judge AFK throughput on: it bootstraps the gates themselves (no prior green baseline), its payloads are tiny (a PowerShell script, a `.csproj`), and one of its deliverables (#22 launch verification) is human-by-design. The throughput signal becomes meaningful from F2 onward (real domain logic, faked providers, fully automatable).

---

## 4. Improvement actions (priority order)

1. **Ship the by-id identity guard** (`kitcox-dev/enate-claude-skills#19`). Highest ROI — eliminates the universal first-touch failure across `check-implementation-readiness`, `enate-to-stories`, and `check-security-design`. Until deployed, expect every story to bounce once.
2. **Flatten the dependency chain.** Fold hardening/security into the foundation story as **acceptance criteria** rather than downstream `blocked-by` stories, so a single stall doesn't cascade across a subtree. (E.g. #21 should ship SHA-pinned + least-privilege + fail-closed the first time — removing #25/#26/#28 *and* the #21 security re-loop.)
3. **Hold generated stories to the readiness bar.** `check-security-design` / `enate-to-stories` must emit ACs that are implementable without invention: no undefined allowlists, deferred tool choices, or unspecified proof mechanisms. Give the generators the readiness gate's own definition of "AFK-ready".
4. **Give the Developer/TDD agent the real gate before PR.** At minimum a Windows build, plus a discipline of deriving one test per explicit Spec-contract clause (the `covered == valid` boundary). Moves the #19/#21 defect class from review-time to TDD-time.
5. **Harden orchestrator plumbing.** Push retries with backoff; a commit-presence check after `/tdd` returns pass; verdict-JSON validation so a serialization slip doesn't count as a gate fail.
6. **Move the doc-stage checks left.** Fold a seam-taxonomy checklist into `/brainstorming` + `/writing-plans`, and run `/check-artefact-consistency` *before* `feature-doc-gauntlet`, so the gauntlet confirms rather than discovers (both F1 doc-stage failures were catchable one stage earlier).
7. **Right-size the gauntlet to story risk.** Running four review leaves + ADR + security + finalization on a 3-line `.csproj` change is the per-story tax that made every trivial story a heavy loop. Consider triage that scales gate depth to the diff's risk surface.

---

## 5. Escalation taxonomy (for future retros)

When measuring AFK autonomy, classify each human touch — only the last bucket is a failure to engineer away:

- **Tooling defect** — gate misroute, malformed verdict, push failure (Causes A, E). *Drive to zero.*
- **Decomposition defect** — cascade from serial `blocked-by`, sibling-scope bleed (Causes B, C). *Drive to zero via slice design.*
- **Artefact/spec defect** — ambiguous ACs, stale upstream doc (Cause C, doc-stage Fail 2). *Drive to zero via left-shifted checks.*
- **Code-quality loop** — real defects caught at review (Cause D). *Reduce via a stronger dev loop.*
- **Designed HITL** — authority-order decisions, manual-verification stories (#22, Roadmap amendment). *Irreducible floor — do not penalise.*
