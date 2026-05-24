#!/usr/bin/env bash
# Install (symlink) the hetzner-proxmox-deploy skill into Claude Code, Codex,
# and other agent skill directories. Optionally registers a daily fast-forward
# git pull so the skill stays current with origin/main automatically.
#
# Idempotent — safe to re-run after pulling repo updates.
#
# Usage:
#   bash install.sh                        # symlink only
#   bash install.sh --auto-update          # symlink + register auto-update job
#   bash install.sh --auto-update --hour=3 # auto-update at 03:00 instead of 06:00
#   bash install.sh --uninstall            # remove symlinks (and auto-update job)
#   bash install.sh --update-now           # one-shot: pull origin/main now
#
# Auto-update mechanics:
#   macOS  → ~/Library/LaunchAgents/com.gprecious.hetzner-skill-update.plist (launchd)
#   Linux  → user crontab line (annotated with "hetzner-skill-update" tag)
#   other  → prints manual cron suggestion, no registration
#
# Auto-update is conservative: `git fetch && git merge --ff-only origin/main`.
# If you have local commits or a dirty working tree, the merge fails harmlessly
# and the next run tries again. Logs land in ~/Library/Logs (mac) or
# ~/.local/share (linux).

set -euo pipefail

SKILL_NAME="hetzner-proxmox-deploy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR"

CLAUDE_DIR="${HOME}/.claude/skills"
CODEX_DIR="${HOME}/.codex/skills"
AGENTS_DIR="${HOME}/.agents/skills"

LAUNCHD_LABEL="com.gprecious.hetzner-skill-update"
LAUNCHD_PLIST="${HOME}/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
CRON_TAG="hetzner-skill-update"

ACTION=install
AUTO_UPDATE=0
HOUR=6
MINUTE=0

print_help() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --auto-update)   AUTO_UPDATE=1 ;;
    --hour=*)        HOUR="${arg#*=}" ;;
    --minute=*)      MINUTE="${arg#*=}" ;;
    --update-now)    ACTION=update_now ;;
    --uninstall|uninstall) ACTION=uninstall ;;
    install)         ACTION=install ;;
    --help|-h|help)  print_help; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; print_help; exit 1 ;;
  esac
done

link_into() {
  local target_dir="$1"
  if [ ! -d "$target_dir" ]; then
    echo "skip: $target_dir does not exist (agent not installed?)"
    return
  fi
  local link="$target_dir/$SKILL_NAME"
  if [ -L "$link" ] || [ -e "$link" ]; then
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$SOURCE" ]; then
      echo "ok:  $link already points to $SOURCE"
      return
    fi
    echo "warn: $link exists and is not the expected symlink — backing up to $link.bak"
    mv "$link" "$link.bak"
  fi
  ln -s "$SOURCE" "$link"
  echo "ok:  linked $link → $SOURCE"
}

unlink_from() {
  local target_dir="$1"
  local link="$target_dir/$SKILL_NAME"
  if [ -L "$link" ]; then
    rm "$link"
    echo "ok:  removed $link"
  else
    echo "skip: $link not a symlink, leaving alone"
  fi
}

repo_root() {
  git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null
}

do_pull() {
  local root="$1"
  cd "$root"
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "warn: working tree dirty in $root — skipping pull"
    return 1
  fi
  git fetch -q origin main || { echo "fetch failed"; return 1; }
  git merge --ff-only -q origin/main || { echo "merge --ff-only failed (local commits ahead?)"; return 1; }
  echo "ok:  pulled origin/main in $root"
}

register_launchd() {
  local root="$1"
  mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/Library/Logs"
  local log="${HOME}/Library/Logs/hetzner-skill-update.log"
  cat > "$LAUNCHD_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LAUNCHD_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>cd "${root}" &amp;&amp; /usr/bin/git fetch -q origin main &amp;&amp; /usr/bin/git merge --ff-only -q origin/main</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>${HOUR}</integer>
    <key>Minute</key><integer>${MINUTE}</integer>
  </dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>${log}</string>
  <key>StandardErrorPath</key><string>${log}</string>
</dict>
</plist>
PLIST

  launchctl bootout "gui/$(id -u)/${LAUNCHD_LABEL}" 2>/dev/null || true
  if launchctl bootstrap "gui/$(id -u)" "$LAUNCHD_PLIST" 2>/dev/null; then
    echo "ok:  registered launchd job ${LAUNCHD_LABEL} (daily ${HOUR}:${MINUTE})"
  else
    launchctl load -w "$LAUNCHD_PLIST" 2>/dev/null \
      && echo "ok:  loaded launchd job (legacy syntax) ${LAUNCHD_LABEL}" \
      || echo "warn: could not load launchd job — try: launchctl bootstrap gui/$(id -u) $LAUNCHD_PLIST"
  fi
  echo "     log: $log"
}

unregister_launchd() {
  if [ -f "$LAUNCHD_PLIST" ]; then
    launchctl bootout "gui/$(id -u)/${LAUNCHD_LABEL}" 2>/dev/null || \
      launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    rm -f "$LAUNCHD_PLIST"
    echo "ok:  removed launchd job ${LAUNCHD_LABEL}"
  fi
}

register_cron() {
  local root="$1"
  local logdir="${HOME}/.local/share"
  mkdir -p "$logdir"
  local log="${logdir}/hetzner-skill-update.log"
  local line="${MINUTE} ${HOUR} * * * cd ${root} && git fetch -q origin main && git merge --ff-only -q origin/main >> ${log} 2>&1  # ${CRON_TAG}"
  local current; current="$(crontab -l 2>/dev/null || true)"
  local cleaned; cleaned="$(printf '%s\n' "$current" | grep -v "${CRON_TAG}" || true)"
  printf '%s\n%s\n' "$cleaned" "$line" | sed '/^$/d' | crontab -
  echo "ok:  registered cron job (daily ${HOUR}:${MINUTE})"
  echo "     log: $log"
}

unregister_cron() {
  local current; current="$(crontab -l 2>/dev/null || true)"
  if printf '%s\n' "$current" | grep -q "${CRON_TAG}"; then
    printf '%s\n' "$current" | grep -v "${CRON_TAG}" | crontab -
    echo "ok:  removed cron job"
  fi
}

register_auto_update() {
  local root; root="$(repo_root)" || true
  if [ -z "$root" ]; then
    echo "skip: $SCRIPT_DIR is not in a git repo, can't auto-update"
    return
  fi
  case "$(uname)" in
    Darwin) register_launchd "$root" ;;
    Linux)  register_cron    "$root" ;;
    *)
      echo "info: auto-update on $(uname) not handled — add this to your scheduler:"
      echo "  ${MINUTE} ${HOUR} * * * cd ${root} && git fetch -q origin main && git merge --ff-only -q origin/main"
      ;;
  esac
}

unregister_auto_update() {
  case "$(uname)" in
    Darwin) unregister_launchd ;;
    Linux)  unregister_cron ;;
  esac
}

case "$ACTION" in
  install)
    echo "Installing $SKILL_NAME from $SOURCE"
    link_into "$CLAUDE_DIR"
    link_into "$CODEX_DIR"
    link_into "$AGENTS_DIR"
    if [ "$AUTO_UPDATE" = "1" ]; then
      echo ""
      echo "Registering auto-update…"
      register_auto_update
    fi
    echo ""
    echo "Done. The skill is invocable in Claude Code as:  /$SKILL_NAME"
    echo "Or via the Skill tool:                          Skill(\"$SKILL_NAME\")"
    if [ "$AUTO_UPDATE" = "1" ]; then
      echo ""
      echo "Auto-update is on. To force a pull right now:"
      echo "  bash $0 --update-now"
      echo "To disable auto-update later:"
      echo "  bash $0 --uninstall"
    else
      echo ""
      echo "Tip: pass --auto-update to keep the skill in sync with origin/main automatically."
    fi
    ;;
  uninstall)
    echo "Uninstalling $SKILL_NAME symlinks"
    unlink_from "$CLAUDE_DIR"
    unlink_from "$CODEX_DIR"
    unlink_from "$AGENTS_DIR"
    unregister_auto_update
    ;;
  update_now)
    root="$(repo_root)" || { echo "not in a git repo"; exit 1; }
    do_pull "$root"
    ;;
esac
