# Project Health Report
**Report:** Health Audit

**Project:** claude-code-docs | **Stack:** Bash + Python + GitHub Actions (no single manifest-driven stack) | **Date:** 2026-07-19 | **Assessed by:** Claude

### Scope note

Same scope as the two prior audits, now also including `tests/smoke/*.sh` (added since the last report). `docs/*.md` (mirrored Anthropic content) remains excluded. Same fallback-heuristic caveat as before — no `shellcheck`/`pylint`/`pip-audit`/`vulture` available in this environment.

### Grades

| Dimension | Grade | Score | Key Finding |
|-----------|-------|-------|-------------|
| Build Health | A | 97 | 0 syntax/compile errors across all files including the new smoke tests; both smoke tests pass (10/10 checks); CI pipeline remains stable |
| Code Quality | A | 93 | Still 0 functions over the 100-line threshold (`safe_git_update()` grew slightly to 97 lines from the branch-check fix, still under); 0 TODO/FIXME |
| Architecture | A | 96 | Unchanged: 0 circular deps, one-directional coupling |
| Test Coverage | C | 65 | **Structural coverage 50% (2 of 4 core script files now have a smoke test)** — was F (0%) at the last audit. `install.sh` and `scripts/claude-docs-helper.sh.template` are covered; `uninstall.sh` and `scripts/fetch_claude_docs.py` are not. Within covered files, coverage is partial at the function level (e.g. `ensure_jq_windows`, `find_existing_installations`, `migrate_installation` in `install.sh` are untested directly) |
| Dead Code | A | 98 | 0 unreferenced functions across all files, including the two new test scripts |
| API Surface | B~ | 83 | Unchanged — the ahead/behind sync-status unification (item 3 from the last report) was deliberately deferred, not lost |
| Security | A | 95 | Unchanged: 0 secrets, 0 unsafe eval/exec, scoped permissions, SHA-pinned third-party Action |
| Documentation | A | 94 | Still 100% function/docstring coverage (34/34). One new minor gap: `README.md` doesn't mention `tests/smoke/` exists — a reader browsing the repo wouldn't discover it. Not a coverage failure (README still exists and covers basics), just a discoverability nit — noted below rather than dropping the grade |

### Overall GPA: 3.625 → **Excellent** (3.5–4.0 band)

> Excellent — production-ready, well-maintained. This is the first time this project has crossed into the Excellent band across three audits (2026-07-18: 3.0, earlier 2026-07-19: 3.375, now: 3.625) — driven this time by Test Coverage actually gaining ground instead of staying at F.

### Trend

| Dimension | Previous (2026-07-19, earlier today) | Current | Change |
|-----------|----------|---------|--------|
| Build Health | A | A | No change |
| Code Quality | A | A | No change (safe_git_update grew 94→97 lines from the branch-check fix, still comfortably under 100) |
| Architecture | A | A | No change |
| Test Coverage | F | C | **Improved** — 0% → 50% structural coverage. This is the real story of this audit: the "smoke tests instead of the full suite" compromise from the last `/fix-items` session moved the needle by 2.5 letter grades |
| Dead Code | A | A | No change — held at 0 through another round of changes |
| API Surface | B~ | B~ | No change — deferred, as planned |
| Security | A | A | No change |
| Documentation | A | A | Letter grade unchanged; one new minor gap identified (README doesn't reference the new tests) |

### Priority Recommendations

1. **Test Coverage (C → B): extend smoke coverage to the two untested files.** `uninstall.sh` and `scripts/fetch_claude_docs.py` have no corresponding smoke test. `fetch_claude_docs.py` is actually the easier of the two — its three extracted functions (`fetch_all_pages`, `fetch_and_record_changelog`, `finalize_run`) already have ad-hoc mock-based verification from the earlier refactor session that could be checked in the same way `tests/smoke/safe_git_update.sh` was. `uninstall.sh` would need a fresh scenario (e.g., verify it correctly identifies and offers to remove a clean vs. dirty installation directory). ✅ Fixed 2026-07-19 — both added (`tests/smoke/fetch_claude_docs.py`, 14 checks; `tests/smoke/uninstall.sh`, 6 checks). Building the uninstall.sh test uncovered a real, previously-undiscovered bug: `find_all_installations()` could never locate a real install because real installs live at `$HOME/.claude-code-docs` (leading dot) and the matching logic assumed no dot — meaning uninstall.sh silently never removed the installation directory on a real machine. Fixed both parsing branches, verified against realistic fixtures, then verified the new test catches the regression by reverting and re-testing.
   Estimated effort: ~1 hour for `fetch_claude_docs.py` (tests mostly already written as scratch code in the prior session); ~1-2 hours for `uninstall.sh` (needs new scenarios).

2. **Documentation: add a one-line pointer to `tests/smoke/` in `README.md`.** Cheap, and closes the only new gap found this audit.
   Estimated effort: 5 minutes.

3. **API Surface (B~ → A):** Unchanged from the last report — full unification of the ahead/behind sync-status logic across `auto_update()`/`show_freshness()`/`print_sync_status()` remains a legitimate future improvement, still correctly deferred rather than rushed.

### Conclusion

This is the best-scoring audit yet for this project, and the reason is specific and real: the smoke tests added last session weren't just a box-checking exercise — they're built from git-repo simulations that already caught three production bugs, and this audit's own structural-coverage metric confirms they measurably moved Test Coverage from F to C. The project is now genuinely in "Excellent" territory. The most impactful next step is extending that same pattern to the two remaining untested files, since the approach has already proven itself here.
