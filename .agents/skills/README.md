# `.agents/skills/` — open-standard skill location

These entries are **symlinks** to the canonical skill directories at the repo
root. `.agents/skills/<name>/SKILL.md` is the location read by agents that follow
the [Agent Skills](https://agentskills.io) open standard — opencode, Kilo Code,
and Codex — for both project (`./.agents/skills/`) and global (`~/.agents/skills/`)
scopes.

Claude Code reads `.claude/skills/` instead; see the repo `README.md` for how to
install there. Edit the skills at the repo root, not through these links.
