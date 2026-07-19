#!/usr/bin/env python3
"""
Smoke test for scripts/fetch_claude_docs.py's fetch_all_pages(),
fetch_and_record_changelog(), and finalize_run() — the three functions extracted
from main() during the 2026-07-19 health-audit fix-items session. Mock-based: no
real network calls, no repo files touched. Not a full test framework — a runnable
regression check for the extraction, same pattern as tests/smoke/*.sh.

Run: python tests/smoke/fetch_claude_docs.py
"""
import sys
import os
from unittest.mock import patch

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(REPO_ROOT, "scripts"))
import fetch_claude_docs as m  # noqa: E402

failures = 0


def check(desc, condition):
    global failures
    if condition:
        print(f"PASS: {desc}")
    else:
        print(f"FAIL: {desc}")
        failures += 1


# --- Scenario 1: fetch_all_pages, mixed success/failure ---
def fake_fetch_markdown_content(page_path, session, base_url):
    if page_path == "/docs/en/bad":
        raise Exception("simulated fetch failure")
    return page_path.replace("/", "_") + ".md", f"content for {page_path}"


with patch.object(m, "fetch_markdown_content", side_effect=fake_fetch_markdown_content), \
     patch.object(m, "content_has_changed", return_value=True), \
     patch.object(m, "save_markdown_file", return_value="fakehash123"), \
     patch.object(m, "time"):
    pages = ["/docs/en/good1", "/docs/en/bad", "/docs/en/good2"]
    files, fetched, successful, failed, failed_pages = m.fetch_all_pages(
        pages, session=None, base_url="https://example.com", manifest={"files": {}}, docs_dir="/tmp"
    )
    check("fetch_all_pages: 2 successful out of 3 pages", successful == 2)
    check("fetch_all_pages: 1 failed", failed == 1)
    check("fetch_all_pages: failed_pages lists the bad page", failed_pages == ["/docs/en/bad"])
    check("fetch_all_pages: 2 files fetched", len(fetched) == 2)
    check("fetch_all_pages: 2 manifest entries built", len(files) == 2)

# --- Scenario 2: fetch_and_record_changelog, success case ---
with patch.object(m, "fetch_changelog", return_value=("changelog.md", "changelog content")), \
     patch.object(m, "content_has_changed", return_value=True), \
     patch.object(m, "save_markdown_file", return_value="hash456"):
    entry, filename, ok = m.fetch_and_record_changelog(session=None, manifest={"files": {}}, docs_dir="/tmp")
    check("fetch_and_record_changelog: success returns ok=True", ok is True)
    check("fetch_and_record_changelog: correct filename", filename == "changelog.md")
    check("fetch_and_record_changelog: correct hash in entry", entry is not None and entry["hash"] == "hash456")
    check("fetch_and_record_changelog: correct source tag", entry is not None and entry["source"] == "claude-code-repository")

# --- Scenario 3: fetch_and_record_changelog, failure case ---
with patch.object(m, "fetch_changelog", side_effect=Exception("network down")):
    entry, filename, ok = m.fetch_and_record_changelog(session=None, manifest={"files": {}}, docs_dir="/tmp")
    check("fetch_and_record_changelog: failure returns ok=False", ok is False)
    check("fetch_and_record_changelog: failure returns entry=None", entry is None)
    check("fetch_and_record_changelog: failure returns filename=None", filename is None)

# --- Scenario 4: finalize_run exits 1 when failed > 0 ---
with patch.object(m, "cleanup_old_files"), patch.object(m, "save_manifest"):
    exited_correctly = False
    try:
        m.finalize_run(
            docs_dir="/tmp", new_manifest={"files": {}}, fetched_files={"a.md"},
            documentation_pages=["/a", "/b"], successful=1, failed=1,
            failed_pages=["/b"], sitemap_url="http://x", base_url="http://x",
            start_time=m.datetime.now(), manifest={"files": {}}
        )
    except SystemExit as e:
        exited_correctly = (e.code == 1)
    check("finalize_run: exits with code 1 when failed > 0", exited_correctly)

# --- Scenario 5: finalize_run does NOT exit when failed == 0 ---
with patch.object(m, "cleanup_old_files"), patch.object(m, "save_manifest"):
    did_not_exit = True
    try:
        m.finalize_run(
            docs_dir="/tmp", new_manifest={"files": {}}, fetched_files={"a.md", "b.md"},
            documentation_pages=["/a", "/b"], successful=2, failed=0,
            failed_pages=[], sitemap_url="http://x", base_url="http://x",
            start_time=m.datetime.now(), manifest={"files": {}}
        )
    except SystemExit:
        did_not_exit = False
    check("finalize_run: does not exit when failed == 0", did_not_exit)

print()
if failures == 0:
    print("fetch_claude_docs.py smoke test: all checks passed")
    sys.exit(0)
else:
    print(f"fetch_claude_docs.py smoke test: {failures} check(s) failed")
    sys.exit(1)
