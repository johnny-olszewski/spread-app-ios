# Specification (v1.0) — Redirect

> **This file has been superseded.** The specification has been split into per-feature files for AI context efficiency.
>
> **Start here**: [`Documentation/Specs/_index.md`](Specs/_index.md)

The index lists every feature file with a description and key SPRD task references. Load only the file(s) relevant to the active task.

---

## Active Session Branches

| Branch | Description |
|--------|-------------|
| `feature/SESH-20` (formerly `WKFLW-20`) | UI polish and design system foundation for TestFlight |

---

## Why This Changed

`spec.md` grew to ~44k tokens — too large for an AI session to hold in full context. The per-feature split lets Claude load exactly the spec context needed for each task (~50–250 lines per file) instead of the full monolith.

The original content is fully preserved in `Documentation/Specs/`. Nothing was deleted.
