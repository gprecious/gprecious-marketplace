# Installing the skill on another machine (or another project)

This is the recipe for using `hetzner-proxmox-deploy` from a machine that does
**not** have the full `hetzner-master` monorepo. The skill stays in sync with
`origin/main` automatically — every agent invocation reads the latest content.

The skill ships as part of the private repo `gprecious/hetzner-master` on
GitHub. You authenticate once, sparse-clone the `skills/` subtree, and let
`install.sh --auto-update` register a daily fast-forward pull job.

---

## One-time setup (per machine)

```bash
# 0. Make sure you can authenticate to gprecious's GitHub.
#    Pick whichever you already use:
gh auth login --hostname github.com --git-protocol ssh   # or HTTPS+PAT
# Or, if you use an SSH alias for the gprecious account, ensure ~/.ssh/config has it.

# 1. Sparse-clone the skill (only the skills/ subtree, ~30KB, no terraform/ansible noise)
SKILL_HOME="${HOME}/.local/share/hetzner-master-skill"
mkdir -p "$SKILL_HOME"
git clone \
  --depth=1 --filter=blob:none --sparse \
  git@github.com-gprecious:gprecious/hetzner-master.git \
  "$SKILL_HOME"
git -C "$SKILL_HOME" sparse-checkout set skills/hetzner-proxmox-deploy

# 2. Symlink into your agent skill dirs + register daily auto-update
bash "$SKILL_HOME/skills/hetzner-proxmox-deploy/install.sh" --auto-update

# 3. Verify the agent can see it
ls -l ~/.claude/skills/hetzner-proxmox-deploy
```

If you don't have an SSH alias for `gprecious`, replace the URL with
`https://github.com/gprecious/hetzner-master.git` (you'll be prompted for a
PAT) or set up the alias once:

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com-gprecious
  HostName github.com
  User git
  IdentityFile ~/.ssh/gprecious_ed25519
EOF
```

---

## What auto-update does

`install.sh --auto-update` registers a per-user job that runs daily at 06:00:

| Platform | Mechanism | File |
|----------|-----------|------|
| macOS | launchd LaunchAgent | `~/Library/LaunchAgents/com.gprecious.hetzner-skill-update.plist` |
| Linux | user crontab line | `crontab -l` (tagged `# hetzner-skill-update`) |
| other | nothing — install.sh prints a manual cron suggestion | — |

The job runs:

```bash
cd <repo-root> && git fetch -q origin main && git merge --ff-only -q origin/main
```

Conservative on purpose:
- `--ff-only` means it never rewrites local commits or creates merge commits.
- A dirty working tree or local commits ahead of `origin/main` cause the merge
  to fail harmlessly. The next day's run tries again.
- Logs land at `~/Library/Logs/hetzner-skill-update.log` (mac) or
  `~/.local/share/hetzner-skill-update.log` (linux).

The agent symlinks (`~/.claude/skills/hetzner-proxmox-deploy` → sparse-clone
dir) keep working even while the underlying files refresh, so no re-install is
needed after a pull.

### Override the schedule

```bash
bash install.sh --auto-update --hour=3 --minute=30   # 03:30 daily
```

### Force a pull right now

```bash
bash ~/.local/share/hetzner-master-skill/skills/hetzner-proxmox-deploy/install.sh --update-now
```

### Disable auto-update (or fully uninstall)

```bash
bash install.sh --uninstall
# → removes symlinks AND the launchd/cron job
```

---

## Updating to a different branch or pinning to a tag

Auto-update tracks `origin/main` by default. If you want a different ref:

```bash
cd ~/.local/share/hetzner-master-skill
git fetch --tags --depth=1 origin
git checkout v1.0.0           # or any tag/branch
# After this, install.sh's auto-update will fail merge --ff-only
# (you're not on main). That's fine — it just becomes a no-op until you
# `git checkout main` again. Disable auto-update if you want it really off:
bash skills/hetzner-proxmox-deploy/install.sh --uninstall   # removes job too
bash skills/hetzner-proxmox-deploy/install.sh               # symlink only
```

---

## Per-project (other repos) advertising the skill

In any project that deploys onto this Proxmox lab, drop a one-liner in its
own `AGENTS.md` / `CLAUDE.md` so the AI agent landing there knows about the
skill:

```markdown
## Deploying to the Hetzner Proxmox lab

This project deploys workloads onto `gprecious/hetzner-master`. The deploy
runbook is in the skill `hetzner-proxmox-deploy`. If it isn't installed:

    bash ~/.local/share/hetzner-master-skill/skills/hetzner-proxmox-deploy/install.sh --auto-update

Then invoke `Skill("hetzner-proxmox-deploy")` and follow `references/02-deploy-workload.md`.
```

The skill itself is intentionally project-agnostic: it tells the agent how to
add an LXC container to the lab, not what to run inside it. Each project keeps
its own deployment specifics in its own repo.

---

## Troubleshooting

**"merge --ff-only failed"** in the log → you have local commits in the sparse
clone, or the remote has been rebased. Fix: `cd <repo-root> && git status`,
resolve, then `git pull --ff-only` manually.

**launchd job not firing** → check `launchctl print gui/$(id -u)/com.gprecious.hetzner-skill-update`.
If it shows `state = not running` and `next fire` is in the past, run
`launchctl kickstart gui/$(id -u)/com.gprecious.hetzner-skill-update` to
trigger immediately.

**SSH auth fails inside the launchd/cron context** → keychains and
`SSH_AUTH_SOCK` differ from your interactive shell. Easiest fix: switch the
sparse clone to HTTPS + a PAT stored in macOS Keychain via
`git config credential.helper osxkeychain`. Or use `gh auth setup-git` once
to wire git into the gh credential store.

**Symlink missing after Claude Code update** → re-run `install.sh` (it's
idempotent). The auto-update job only refreshes the skill content, not the
symlinks. Symlinks survive Claude Code upgrades unless `~/.claude/skills/` is
nuked.
