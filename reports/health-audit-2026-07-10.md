## Project Health Report

**Project:** claude-code-docs | **Stack:** Bash (installer/uninstaller/helper) + Python 3 (doc fetcher) + GitHub Actions | **Date:** 2026-07-10 | **Assessed by:** Claude

### Grades

| Dimension | Grade | Score | Key Finding |
|-----------|-------|-------|-------------|
| Build Health | A | 95 | 0 syntax errors across 3 bash scripts, Python compiles clean, both YAML workflows valid |
| Code Quality | C? | 68 | 4 long functions (60–144 lines) in ~1.8K lines (~2.2/1K); no linter configured, grep fallback used |
| Architecture | A | 92 | No cross-script coupling, no circular deps possible; prior self-invocation bug confirmed fixed |
| Test Coverage | F | 0 | 0% — no test files of any kind exist (bash or Python) |
| Dead Code | A | 96 | 0 unused functions detected in any script; both templates actively referenced |
| API Surface | B~ | 82 | Minimal, consistent `/docs` command surface; stale docs.anthropic.com links in output (judgment call) |
| Security | A | 96 | 0 vulnerable deps (pip-audit), no secrets/eval, jq download SHA256-verified, scoped CI permissions |
| Documentation | A | 92 | 100% function-level doc coverage (13/13 Python docstrings, 15/15 bash); README comprehensive |

### Overall GPA: 3.12 — Good

> Good — solid foundation, minor improvements needed

### Priority Recommendations

1. **Test Coverage (F → C):** Add tests for the pure, network-free functions in `scripts/fetch_claude_docs.py`:
   - `url_to_safe_filename`, `validate_markdown_content`, `content_has_changed`, `parse_sitemap_xml` — all deterministic, no I/O
   - Consider `bats-core` smoke tests for `install.sh`/`uninstall.sh` critical paths (OS detection, jq checksum verification)
   Estimated effort: 1–2 days for the Python unit tests alone; this was already flagged in the prior code-audit (2026-06-30) as a "Won't fix" — worth revisiting given the fetch script broke silently in production between audits.

2. **Code Quality (C → B):** Extract logic out of the largest functions:
   - `install.sh` — `safe_git_update()` (144 lines) mixes branch-switch detection, conflict handling, and user confirmation; split into smaller named steps
   - `install.sh` — `find_existing_installations()` (77 lines) and `ensure_jq_windows()` (65 lines) are borderline; lower priority
   - `scripts/claude-docs-helper.sh.template` — `read_doc()` (97 lines) combines freshness check, fetch, and formatting
   Estimated effort: 3–4 hours

3. **API Surface / Documentation (cleanup):** Replace stale `docs.anthropic.com` references with `code.claude.com` in user-facing output:
   - `scripts/claude-docs-helper.sh.template:33,155,184,270` — "Official page" links
   - `README.md:8`, `CLAUDE.md:3` — descriptive text
   These still 301-redirect correctly, so nothing is broken today, but they add an unnecessary hop and drift from the canonical host now used by the fetcher itself.
   Estimated effort: 15 minutes

### Conclusion

The project is in good shape overall (GPA 3.12), with a clean build, strong security posture (verified downloads, no secrets, no known vulnerable dependencies), zero dead code, and excellent documentation coverage at the function level. The two clear weak points are the complete absence of automated tests — which is exactly how the recent `docs.anthropic.com` → `code.claude.com` migration silently broke the doc-fetch pipeline for every scheduled run until this session's manual investigation caught it — and a handful of long, multi-responsibility bash functions that would benefit from being split up. Adding a small pytest suite for the fetcher's pure functions would have caught the sitemap/fallback-URL bug automatically and is the single highest-leverage next step.
