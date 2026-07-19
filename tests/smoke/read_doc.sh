#!/bin/bash
# Smoke test for scripts/claude-docs-helper.sh.template's read_doc() / print_sync_status().
# Verifies the fetch-count behavior fixed 2026-07-19 (the -t <topic> combined path used
# to fetch twice) and the total-fetch-failure fallback (which prints its own content and
# must return without the caller double-printing). See reports/archive/code-audit-2026-07-18.md
# item 4 and reports/health-audit-2026-07-18.md item 2 for the history.
#
# Run: bash tests/smoke/read_doc.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILURES=0
TEMPLATE="$REPO_ROOT/scripts/claude-docs-helper.sh.template"

# Extract every function definition (everything before the argument-dispatch section).
FUNCS_FILE=$(mktemp)
sed -n '1,/^# Store original arguments for flag checking/p' "$TEMPLATE" | sed '$d' > "$FUNCS_FILE"
bash -n "$FUNCS_FILE" || { echo "FAIL: extracted functions have a syntax error"; exit 1; }

check() {
    local desc="$1" condition="$2"
    if [[ "$condition" == "true" ]]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        FAILURES=$((FAILURES + 1))
    fi
}

WORK=$(mktemp -d)
git -c init.defaultBranch=main init --quiet --bare "$WORK/origin"
git clone --quiet "$WORK/origin" "$WORK/local"
(cd "$WORK/local" && git config user.email t@t.com && git config user.name t \
    && git checkout -b main --quiet && echo "v1" > f.md && git add f.md \
    && git commit --quiet -m "v1" && git push --quiet -u origin main)
mkdir -p "$WORK/local/docs"
echo "# Hello" > "$WORK/local/docs/hello.md"

git clone --quiet "$WORK/origin" "$WORK/editor"
(cd "$WORK/editor" && git config user.email t@t.com && git config user.name t \
    && echo "v2" >> f.md && git add f.md && git commit --quiet -m "v2" && git push --quiet origin main)

# Fetch-call tracer
SHIM=$(mktemp -d)
REALGIT=$(command -v git)
cat > "$SHIM/git" <<EOF
#!/bin/bash
if [[ "\$1" == "fetch" ]]; then
  echo "FETCH_CALLED" >> "$WORK/fetch.log"
fi
exec "$REALGIT" "\$@"
EOF
chmod +x "$SHIM/git"

# --- Scenario 1: combined auto_update -> read_doc path should fetch exactly once ---
rm -f "$WORK/fetch.log"
(
    PATH="$SHIM:$PATH"
    cd "$WORK/local"
    source "$FUNCS_FILE"
    DOCS_PATH="$WORK/local"
    MANIFEST="$DOCS_PATH/docs/docs_manifest.json"
    auto_update >/dev/null 2>&1
    read_doc "hello" >/tmp/smoke_readdoc1.log 2>&1
)
fetch_count=$(wc -l < "$WORK/fetch.log" 2>/dev/null || echo 0)
[[ "$fetch_count" -eq 1 ]] && c1=true || c1=false
grep -q "# Hello" /tmp/smoke_readdoc1.log && c2=true || c2=false
check "combined path: exactly 1 git fetch (was 2 before the 2026-07-19 fix)" "$c1"
check "combined path: doc content printed correctly" "$c2"

# --- Scenario 2: total fetch failure fallback prints once and returns cleanly ---
rm -rf "$WORK/broken"
cp -r "$WORK/local" "$WORK/broken"
(cd "$WORK/broken" && git remote set-url origin /nonexistent/path)
(
    cd "$WORK/broken"
    source "$FUNCS_FILE"
    DOCS_PATH="$WORK/broken"
    MANIFEST="$DOCS_PATH/docs/docs_manifest.json"
    read_doc "hello" > /tmp/smoke_readdoc2.log 2>&1
    echo "AFTER_RETURN_MARKER" >> /tmp/smoke_readdoc2.log
)
content_count=$(grep -c "# Hello" /tmp/smoke_readdoc2.log)
[[ "$content_count" -eq 1 ]] && f1=true || f1=false
grep -q "AFTER_RETURN_MARKER" /tmp/smoke_readdoc2.log && f2=true || f2=false
check "fetch-failure fallback: doc content printed exactly once (not duplicated)" "$f1"
check "fetch-failure fallback: read_doc returns cleanly (caller continues)" "$f2"

rm -f /tmp/smoke_readdoc1.log /tmp/smoke_readdoc2.log
rm -f "$FUNCS_FILE"
rm -rf "$SHIM" "$WORK"

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
    echo "read_doc.sh: all checks passed"
    exit 0
else
    echo "read_doc.sh: $FAILURES check(s) failed"
    exit 1
fi
