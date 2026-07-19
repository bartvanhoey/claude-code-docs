#!/bin/bash
# Smoke test for install.sh's safe_git_update() and its helpers.
# Sets up real temp git repos and exercises the scenarios that previously exposed
# real bugs (see reports/archive/health-audit-2026-07-18.md, findings 5 and 6, and
# reports/health-audit-2026-07-19.md item 1). Not a unit test framework — just a
# runnable regression check for the highest-risk function in this repo.
#
# Run: bash tests/smoke/safe_git_update.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILURES=0

# Extract detect_local_changes(), confirm_discard_changes(), and safe_git_update()
# from install.sh. Marker-based (not line-number-based) so this stays correct as
# the file changes, as long as these two markers remain.
FUNCS_FILE=$(mktemp)
sed -n '/^detect_local_changes() {/,/^# Main installation logic/p' "$REPO_ROOT/install.sh" | sed '$d' > "$FUNCS_FILE"
bash -n "$FUNCS_FILE" || { echo "FAIL: extracted functions have a syntax error"; exit 1; }

setup_repo_pair() {
    local work="$1"
    git -c init.defaultBranch=main init --quiet --bare "$work/origin"
    git clone --quiet "$work/origin" "$work/seed"
    (cd "$work/seed" && git config user.email t@t.com && git config user.name t \
        && git checkout -b main --quiet && echo "v1" > f.md && git add f.md \
        && git commit --quiet -m "v1" && git push --quiet -u origin main)
}

push_new_commit() {
    local origin="$1" work="$2"
    rm -rf "$work/editor"
    git clone --quiet "$origin" "$work/editor"
    (cd "$work/editor" && git config user.email t@t.com && git config user.name t \
        && echo "v2" >> f.md && git add f.md && git commit --quiet -m "v2" && git push --quiet origin main)
}

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
setup_repo_pair "$WORK"
push_new_commit "$WORK/origin" "$WORK"

# --- Scenario 1: decline discard ---
rm -rf "$WORK/decline"
cp -r "$WORK/seed" "$WORK/decline"
(
    cd "$WORK/decline"
    echo "dirty" >> f.md
    source "$FUNCS_FILE"
    INSTALL_BRANCH="main"
    echo "n" | safe_git_update "$WORK/decline" >/tmp/smoke_decline.log 2>&1
    echo "$?" > /tmp/smoke_decline.exit
)
[[ "$(cat /tmp/smoke_decline.exit)" == "1" ]] && d1=true || d1=false
grep -q "dirty" "$WORK/decline/f.md" && d2=true || d2=false
check "decline: safe_git_update returns non-zero" "$d1"
check "decline: local change preserved" "$d2"

# --- Scenario 2: accept discard ---
rm -rf "$WORK/accept"
cp -r "$WORK/seed" "$WORK/accept"
(
    cd "$WORK/accept"
    echo "dirty" >> f.md
    source "$FUNCS_FILE"
    INSTALL_BRANCH="main"
    echo "y" | safe_git_update "$WORK/accept" >/tmp/smoke_accept.log 2>&1
    echo "$?" > /tmp/smoke_accept.exit
)
[[ "$(cat /tmp/smoke_accept.exit)" == "0" ]] && a1=true || a1=false
grep -q "dirty" "$WORK/accept/f.md" && a2=false || a2=true
check "accept: safe_git_update returns 0" "$a1"
check "accept: local change discarded" "$a2"

# --- Scenario 3: branch switch actually switches (regression test for the fast-path
# git pull bug fixed 2026-07-19 — it used to report success while staying on the
# wrong branch) ---
rm -rf "$WORK/switch"
cp -r "$WORK/seed" "$WORK/switch"
(
    cd "$WORK/switch"
    git checkout -b some-other-branch --quiet
    source "$FUNCS_FILE"
    INSTALL_BRANCH="main"
    safe_git_update "$WORK/switch" >/tmp/smoke_switch.log 2>&1
    echo "$?" > /tmp/smoke_switch.exit
    git rev-parse --abbrev-ref HEAD > /tmp/smoke_switch.branch
)
[[ "$(cat /tmp/smoke_switch.exit)" == "0" ]] && s1=true || s1=false
[[ "$(cat /tmp/smoke_switch.branch)" == "main" ]] && s2=true || s2=false
check "branch-switch: safe_git_update returns 0" "$s1"
check "branch-switch: actually lands on target branch" "$s2"

rm -f /tmp/smoke_*.log /tmp/smoke_*.exit /tmp/smoke_switch.branch
rm -f "$FUNCS_FILE"
rm -rf "$WORK"

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
    echo "safe_git_update.sh: all checks passed"
    exit 0
else
    echo "safe_git_update.sh: $FAILURES check(s) failed"
    exit 1
fi
