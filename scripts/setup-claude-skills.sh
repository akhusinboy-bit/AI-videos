#!/usr/bin/env bash
# Installs 5 Claude Code skills/plugins globally (user scope, ~/.claude).
# Safe to re-run: every step is idempotent.
#   - claude-mem      (thedotmack/claude-mem)          plugin, local provider
#   - superpowers     (obra/superpowers)               plugin
#   - impeccable      (pbakaus/impeccable)             plugin
#   - find-skills     (vercel-labs/skills)             skill
#   - task-observer   (rebelytics/one-skill-to-rule-them-all) skill + CLAUDE.md activation block
set -uo pipefail

export DISABLE_TELEMETRY=1
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PROJECTS_ROOT="${PROJECTS_ROOT:-/home/user}"
fail=0
step() { echo; echo "==> $*"; }
run() { "$@" || { echo "!! failed (exit $?): $*" >&2; fail=1; }; }

step "Plugin marketplaces"
claude plugin marketplace list 2>/dev/null | grep -q 'claude-plugins-official' \
  || run claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace list 2>/dev/null | grep -q '> impeccable' \
  || run claude plugin marketplace add pbakaus/impeccable

step "superpowers + impeccable"
run claude plugin install superpowers@claude-plugins-official
run claude plugin install impeccable@impeccable

step "claude-mem (local memory, no account / cloud sync)"
# Non-interactive run defaults to the user's own Anthropic plan; the
# SessionStart hook starts the worker in each session.
run npx -y claude-mem install </dev/null

step "find-skills + task-observer"
run npx -y skills add vercel-labs/skills --skill find-skills -g -a claude-code -y
run npx -y skills add rebelytics/one-skill-to-rule-them-all --skill task-observer -g -a claude-code -y

step "task-observer activation block in $CLAUDE_DIR/CLAUDE.md"
MARKER="# Task Observer activation (rebelytics/one-skill-to-rule-them-all)"
SKILL_DIR="$CLAUDE_DIR/skills/task-observer"
ENV_MD="$SKILL_DIR/references/environments.md"
if grep -qF "$MARKER" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
  echo "already present"
elif [ -f "$ENV_MD" ]; then
  {
    [ -s "$CLAUDE_DIR/CLAUDE.md" ] && echo
    printf '%s\n\n' "$MARKER"
    awk '/^### The activation block/{f=1;next} f&&/^```text/{p=1;next} p&&/^```/{exit} p' "$ENV_MD" \
      | sed -e "s#\[ABSOLUTE PATH\]#$CLAUDE_DIR#g" \
            -e "s#\[PROJECTS ROOT\]#$PROJECTS_ROOT#g" \
            -e "s#<skill directory>#$SKILL_DIR#g"
  } >> "$CLAUDE_DIR/CLAUDE.md"
  mkdir -p "$CLAUDE_DIR/skill-observations/observation-log"
  echo "added"
else
  echo "!! $ENV_MD not found, activation block not added" >&2; fail=1
fi

step "Result"
claude plugin list 2>/dev/null | grep -E '^\s+>|Status'
ls -d "$CLAUDE_DIR"/skills/find-skills "$CLAUDE_DIR"/skills/task-observer 2>/dev/null
exit "$fail"
