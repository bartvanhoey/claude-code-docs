#!/bin/bash
# Smoke test for uninstall.sh. Unlike install.sh/claude-docs-helper.sh.template,
# uninstall.sh has almost no functions to extract and source — it's top-level script
# code. So instead this runs the REAL script end-to-end against a fake $HOME sandbox
# (every path in the script resolves through $HOME/tilde-expansion, so overriding it
# is enough to make this fully safe — nothing under the real ~/.claude is touched).
#
# Fixtures mirror what a real install actually produces: docs-command.md.template is
# copied verbatim (so docs.md contains a literal, unexpanded "$HOME" string), while the
# hook command in settings.json IS resolved at install time (real absolute path). Both
# matter — a bug fixed in this same session meant find_all_installations() could never
# recognize either form, because real installs live at "$HOME/.claude-code-docs" (note
# the leading dot) and the old matching logic didn't account for it.
#
# Run: bash tests/smoke/uninstall.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILURES=0

check() {
    local desc="$1" condition="$2"
    if [[ "$condition" == "true" ]]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        FAILURES=$((FAILURES + 1))
    fi
}

setup_fake_home() {
    local home="$1" install_dir="$2"
    mkdir -p "$home/.claude/commands" "$install_dir"
    cat > "$home/.claude/commands/docs.md" <<'EOF'
Execute: $HOME/.claude-code-docs/claude-docs-helper.sh "$ARGUMENTS"
EOF
    cat > "$home/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {"type": "command", "command": "$install_dir/claude-docs-helper.sh hook-check"}
        ]
      }
    ]
  }
}
EOF
}

# --- Scenario 1: clean installation directory gets removed ---
FAKE_HOME1=$(mktemp -d)
INSTALL_DIR1="$FAKE_HOME1/.claude-code-docs"
setup_fake_home "$FAKE_HOME1" "$INSTALL_DIR1"
(cd "$INSTALL_DIR1" && git init --quiet && git config user.email t@t.com && git config user.name t \
    && echo "x" > f.txt && git add f.txt && git commit --quiet -m "init")

HOME="$FAKE_HOME1" bash "$REPO_ROOT/uninstall.sh" -y > /tmp/smoke_uninstall1.log 2>&1
[[ ! -d "$INSTALL_DIR1" ]] && u1=true || u1=false
[[ ! -f "$FAKE_HOME1/.claude/commands/docs.md" ]] && u2=true || u2=false
check "clean install: directory found and removed" "$u1"
check "clean install: /docs command file removed" "$u2"

# --- Scenario 2: dirty installation directory is preserved ---
FAKE_HOME2=$(mktemp -d)
INSTALL_DIR2="$FAKE_HOME2/.claude-code-docs"
setup_fake_home "$FAKE_HOME2" "$INSTALL_DIR2"
(cd "$INSTALL_DIR2" && git init --quiet && git config user.email t@t.com && git config user.name t \
    && echo "x" > f.txt && git add f.txt && git commit --quiet -m "init" && echo "dirty" >> f.txt)

HOME="$FAKE_HOME2" bash "$REPO_ROOT/uninstall.sh" -y > /tmp/smoke_uninstall2.log 2>&1
[[ -d "$INSTALL_DIR2" ]] && d1=true || d1=false
grep -q "Preserved.*uncommitted changes" /tmp/smoke_uninstall2.log && d2=true || d2=false
check "dirty install: directory is preserved, not deleted" "$d1"
check "dirty install: reports the reason (uncommitted changes)" "$d2"

# --- Scenario 3: settings.json hook is removed and a backup is created ---
FAKE_HOME3=$(mktemp -d)
INSTALL_DIR3="$FAKE_HOME3/.claude-code-docs"
setup_fake_home "$FAKE_HOME3" "$INSTALL_DIR3"
(cd "$INSTALL_DIR3" && git init --quiet && git config user.email t@t.com && git config user.name t \
    && echo "x" > f.txt && git add f.txt && git commit --quiet -m "init")

HOME="$FAKE_HOME3" bash "$REPO_ROOT/uninstall.sh" -y > /tmp/smoke_uninstall3.log 2>&1
[[ -f "$FAKE_HOME3/.claude/settings.json.backup" ]] && s1=true || s1=false
grep -q "claude-code-docs" "$FAKE_HOME3/.claude/settings.json" > /dev/null 2>&1 && s2=false || s2=true
check "hook removal: settings.json.backup created" "$s1"
check "hook removal: claude-code-docs hook no longer present" "$s2"

rm -f /tmp/smoke_uninstall1.log /tmp/smoke_uninstall2.log /tmp/smoke_uninstall3.log
rm -rf "$FAKE_HOME1" "$FAKE_HOME2" "$FAKE_HOME3"

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
    echo "uninstall.sh: all checks passed"
    exit 0
else
    echo "uninstall.sh: $FAILURES check(s) failed"
    exit 1
fi
