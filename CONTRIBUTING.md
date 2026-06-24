# Contributing — branching & merge rules

WeatherPoC is built with the **Enate SDLC Factory**. Two branching rules apply, depending on who
is doing the work. Direct commits to `main` are blocked in both — `main` only ever moves through a
pull request that passes CI (and review, where required).

## 1. Human-in-the-loop (HITL) work

All human work — planning docs, fixes, skill changes, anything — happens on a **branch**, opened as
a **pull request** and merged into `main`. You cannot commit to `main` directly. Agent-assisted HITL
sessions work on a `claude/<slug>` branch and follow the same PR path.

## 2. AFK — the orchestrator delivering Stories (current rule)

When the orchestrator delivers work autonomously it uses **one `story/<issue#>-<slug>` branch per
Story**. The agent works only inside that branch; the orchestrator owns the branch lifecycle (the
agent performs no branch operations). On `Approved`, the Story branch is **squash-merged into
`main`**. A single Story is in flight at a time.

> When the orchestrator's feature-branch integration buffer ships (a `feature/<id>-<slug>` branch
> with Story branches cut from it), **this note and the branch-protection rules must be updated** to
> match. Until then, the two rules above are the whole story; do not pre-adopt the buffer model.

## CI gate

Every PR into `main` must pass the `CI` workflow (`.github/workflows/ci.yml`): build, the 100%
coverage gate and its scope assertion, secret scanning (gitleaks), SHA-pinned-actions verification,
and locked-mode dependency restore. CI also runs on pushes to `claude/**`, `feature/**`, and
`story/**` branches. See `Technical-Context.MD` for the engineering contract these checks enforce.
