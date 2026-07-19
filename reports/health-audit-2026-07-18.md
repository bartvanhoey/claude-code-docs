# Project Health Report
**Report:** Health Audit

**Project:** claude-code-docs | **Stack:** Bash + Python + GitHub Actions (no single manifest-driven stack) | **Date:** 2026-07-18 | **Assessed by:** Claude

### Scope note

No `package.json`/`.csproj`/`go.mod`/etc. exists — this repo's code surface is `install.sh`, `uninstall.sh`, `scripts/claude-docs-helper.sh.template` (Bash), `scripts/fetch_claude_docs.py` (Python), and two GitHub Actions workflows. `docs/*.md` (171 of 186 tracked files) is mirrored Anthropic content, not authored code, and is excluded from all 8 dimensions below. No stack-specific linters were available in this environment (no `shellcheck`, `pylint`/`ruff`, `pip-audit`, or `vulture` installed) — Code Quality, Dead Code, and Security used the Fallback heuristics from the skill's tooling reference, marked `?` for lower confidence where applicable.

### ⚠️ Live incident found during this audit (not a grade — read first)

While gathering Build Health data, `gh run list` showed the **"Update Claude Code Documentation"** workflow had failed **7 times in a row**, every 3-hour run from **2026-07-18 01:54 UTC through 18:54 UTC (~17 hours)**. Root cause: the exact "PR title exceeds GitHub's 256-character limit" bug that PR #73 fixed — but that fix only merged at **19:20:31 UTC**, *after* the last observed failure, so every failing run through 18:54 executed against the pre-fix commit (`b124bab`). No scheduled run has executed since the fix merged (next is 21:00 UTC) — **the fix is unverified by a live run as of this report.** Recommend checking the 21:00 UTC run before considering this closed.

### Grades

| Dimension | Grade | Score | Key Finding |
|-----------|-------|-------|-------------|
| Build Health | A | 95 | 0 syntax errors/warnings (`bash -n` × 3 scripts, `py_compile` × 1) — but see live incident above; not reflected in this grade since it's a logic bug, not a syntax/compile failure |
| Code Quality | D? | 58 | 3 functions exceed the 100-line anti-pattern threshold (`read_doc` 103, `safe_git_update` 144, `main()` 183) in 1,782 bash+python LOC = 1.68/1K — fallback heuristic only, no linter available |
| Architecture | A | 96 | 0 circular deps, one-directional coupling verified by cross-reference grep (install.sh → template copy; workflows → scripts, never reversed) |
| Test Coverage | F | 0 | 0 test files anywhere in the repo (structural coverage 0/6 code files) — pre-existing, user-confirmed "won't fix" as of 2026-06-30 |
| Dead Code | A | 98 | 0 unreferenced functions across all 4 code files (systematic reference-count check); the one dead branch found this session was already fixed |
| API Surface | B~ | 82 | Disciplined scoping (65 `local` declarations vs. 5 necessary globals); CLI dispatch is clean but the underlying ahead/behind sync logic is still implemented independently in 3 places |
| Security | A | 94 | 0 hardcoded secrets, 0 unsafe `eval`/`exec`/`pickle`, scoped Actions permissions, third-party Action SHA-pinned; no automated CVE scanner available to verify dependency vulnerabilities |
| Documentation | A | 96 | 15/15 bash functions commented, 13/13 Python functions have docstrings, README has 8 well-organized sections incl. security notes and uninstall |

### Overall GPA: 3.0 — Good

> Good — solid foundation, minor improvements needed

### Trend

| Dimension | Previous (2026-07-10) | Current | Change |
|-----------|----------|---------|--------|
| Build Health | A | A | No change |
| Code Quality | C? | D? | Down — this audit specifically counted 3 functions >100 lines (incl. `fetch_claude_docs.py:main()` at 183 lines) using a stricter fallback threshold; still no real linter available in either audit, so treat both as low-confidence |
| Architecture | A | A | No change |
| Test Coverage | F | F | No change — still 0%, still an accepted "won't fix" per 2026-06-30 decision |
| Dead Code | A | A | No change — 1 dead branch was found and fixed earlier in this session, so the codebase is at its cleanest point yet |
| API Surface | B~ | B~ | No change |
| Security | A | A | No change — third-party GitHub Action is now SHA-pinned (fixed this session), closing the one gap noted previously |
| Documentation | A | A | No change |

### Priority Recommendations

1. **Verify the update-docs fix (unassigned dimension, most urgent):** Check that the 21:00 UTC scheduled run of "Update Claude Code Documentation" succeeds. If it fails again, the PR-title truncation logic in `.github/workflows/update-docs.yml` needs a second look — 17 hours of consecutive failures on the project's core automated deliverable is the most operationally significant finding in this audit, even though it doesn't map cleanly onto a letter grade. ❭ Won't fix — verified via `gh run list`: runs at 2026-07-18 21:43 UTC and 2026-07-19 02:06 UTC both succeeded
   Estimated effort: 5 minutes to check `gh run list --workflow=update-docs.yml --limit 1`, more only if it's still failing.

2. **Code Quality (D? → B): split the 3 overlong functions:**
   - `scripts/fetch_claude_docs.py:main()` (183 lines) — extract page-fetch-loop and changelog-fetch-loop into separate functions; both are already self-contained blocks
   - `install.sh:safe_git_update()` (144 lines) — extract the "detect what kind of local changes exist" block (the `has_conflicts`/`has_local_changes`/`has_untracked` section) into its own function
   - `scripts/claude-docs-helper.sh.template:read_doc()` (103 lines) — extract the "fetch/compare/pull and print sync status" block into a helper (this is also the block flagged for triplication in the prior code-audit's item 4, so fixing both at once is efficient)
   Estimated effort: 2-3 hours total

3. **Test Coverage (F, accepted as won't-fix):** No change recommended — this was explicitly declined by the user on 2026-06-30 and reconfirmed during the 2026-07-18 code-audit session. Listed here only for completeness, not as an action item.

4. **API Surface (B~ → A):** Once the Code Quality refactor above extracts a shared sync-status helper, the API Surface grade should improve alongside it — no separate action needed.

### Conclusion

The codebase is small, clean, and well-documented — zero dead code, zero hardcoded secrets, disciplined variable scoping, and comprehensive comments/docstrings/README coverage. The one real quality gap (three overlong functions) is narrow and cheap to fix. The single most important thing to act on right now isn't a grade at all: confirm the 21:00 UTC scheduled run succeeds, since the project's actual purpose — keeping the docs mirror in sync — was silently broken for 17 hours today and the fix hasn't been observed working yet.
