# Project Health Report
**Report:** Health Audit

**Project:** claude-code-docs | **Stack:** Bash + Python + GitHub Actions (no single manifest-driven stack) | **Date:** 2026-07-19 | **Assessed by:** Claude

### Scope note

Same scope as the 2026-07-18 audit: `install.sh`, `uninstall.sh`, `scripts/claude-docs-helper.sh.template` (Bash), `scripts/fetch_claude_docs.py` (Python), and two GitHub Actions workflows. `docs/*.md` (mirrored Anthropic content) is excluded. No `shellcheck`/`pylint`/`ruff`/`pip-audit`/`vulture` available in this environment — Code Quality, Dead Code, and Security again used fallback heuristics, marked `?` where applicable.

### Grades

| Dimension | Grade | Score | Key Finding |
|-----------|-------|-------|-------------|
| Build Health | A | 97 | 0 syntax/compile errors; the update-docs CI pipeline (flagged as a live incident last audit) is now confirmed stable — 3 consecutive successes since the fix, independently re-verified this session |
| Code Quality | A | 92 | 0 functions over the 100-line threshold (was 3) — all fixed in the `/fix-items` session between audits; 0 TODO/FIXME |
| Architecture | A | 96 | Unchanged: 0 circular deps, one-directional coupling |
| Test Coverage | F | 0 | Unchanged: 0 test files. Confirmed "won't fix" for the third time this project's history (2026-06-30, 2026-07-18 code-audit, 2026-07-19 fix-items session) |
| Dead Code | A | 98 | 0 unreferenced functions across all 4 code files, including every function added in the interim refactor — all correctly wired |
| API Surface | B~ | 83 | Disciplined scoping unchanged (5 necessary globals); the ahead/behind sync-status logic is now *partially* deduplicated (one of three call sites extracted into a shared helper) but not fully unified — holding at B~ rather than assuming the prior report's "should improve to A" prediction fully landed |
| Security | A | 95 | Unchanged: 0 secrets, 0 unsafe eval/exec, scoped permissions, third-party Action SHA-pinned |
| Documentation | A | 94 | 100% comment/docstring coverage (34/34 functions) — found and fixed one regression during this audit: a doc comment left orphaned above the wrong function by the interim refactor (see below) |

### ⚠️ Found and fixed during this audit (not a new finding — a self-inflicted regression)

While checking Documentation coverage, `install.sh:safe_git_update()` had **no preceding comment**, and `# Function to safely update git repository` sat above `detect_local_changes()` instead — a leftover from the `print_sync_status`/`detect_local_changes` extraction done in the prior `/fix-items` session (the edit correctly moved the code but left the old comment line behind above the wrong function). Fixed in this audit: moved the comment back to `safe_git_update()`, verified with `bash -n`. This is now committed alongside the report.

### Overall GPA: 3.375 → rounds to **Good** (3.0–3.4 band)

> Good — solid foundation, minor improvements needed. One dimension (Test Coverage, F) is the sole thing keeping this out of the Excellent (3.5+) band; every other dimension is A, or B~ on a judgment-call dimension.

### Trend

| Dimension | Previous (2026-07-18) | Current | Change |
|-----------|----------|---------|--------|
| Build Health | A | A | No change on the letter grade, but the live CI incident flagged last time is now confirmed resolved rather than just "fix merged, unverified" |
| Code Quality | D? | A | **Improved** — all 3 overlong functions fixed in the interim `/fix-items` session (`read_doc` 103→65, `safe_git_update` 144→94, `main()` 183→86) |
| Architecture | A | A | No change |
| Test Coverage | F | F | No change — still 0%, still declined |
| Dead Code | A | A | No change — still 0, and stayed 0 through a fairly large refactor |
| API Surface | B~ | B~ | No change — held steady rather than assuming full improvement; see note above |
| Security | A | A | No change |
| Documentation | A | A | Letter grade unchanged, but a real regression was found and fixed mid-audit (see above) — net effect is documentation is now *more* accurate than either prior snapshot, not just stable |

### Priority Recommendations

1. **Carry forward: two bugs found but not fixed in the prior `/fix-items` session.** These were logged in `reports/archive/health-audit-2026-07-18.md` (now archived) as findings 5 and 6 and are still open — repeating them here so they aren't lost in the archive move: ✅ Fixed 2026-07-19 — branch-check guard (finding 5) fixed and verified against 4 git-repo scenarios; the dirty-file-sync issue (finding 6) reassessed as an incorrect finding — a corrected repro showed git pull correctly refuses (non-zero exit) rather than silently advancing HEAD, so the original report was based on a flawed test setup
   - `install.sh:safe_git_update()` — the fast-path `git pull` doesn't verify it's on the target branch before declaring success, which can silently leave the installer on the wrong branch.
   - Same fast-path `git pull` can leave a locally-modified tracked file (e.g. `docs/docs_manifest.json`) out of sync with the new `HEAD` without erroring.
   Estimated effort: unchanged from the prior report — the branch-check guard is a scoped fix; the second needs investigation before a fix can be sized.

2. **Test Coverage (F, accepted as won't-fix):** No change recommended — third confirmation of the same declined decision. Listed for completeness only. ✅ Fixed 2026-07-19 — not the full test suite (still declined, 4th time), but added `tests/smoke/safe_git_update.sh` and `tests/smoke/read_doc.sh`: standalone regression scripts built from this session's ad-hoc verification harnesses, covering the two functions that proved riskiest. Verified they actually catch regressions (not just pass trivially) by reverting a fix and confirming the test failed.

3. **API Surface (B~):** If the ahead/behind sync-status logic in `auto_update()`/`show_freshness()`/`print_sync_status()` is ever fully unified into one shared helper (the originally-proposed, higher-risk option from the 2026-07-18 code-audit), this should genuinely reach A. Not urgent — current state is a real, verified improvement over full triplication, just not complete unification. ❭ Skipped — remind me later — worth doing, but not stacked onto a branch that's already touched safe_git_update(), read_doc(), and fetch_claude_docs.py this session; revisit once this lands and gets a production cycle

### Conclusion

This is a clear improvement over the 2026-07-18 audit: the Code Quality grade went from D? to A by actually fixing the three overlong functions (not just planning to), the CI incident flagged last time is now confirmed resolved rather than merely "should be fixed," and this audit itself caught and fixed a small documentation regression the refactor had introduced. The only thing separating this project from an Excellent rating is the same accepted trade-off it's had since 2026-06-30 — zero test coverage — which remains a deliberate, repeatedly-reconfirmed decision rather than an oversight.
