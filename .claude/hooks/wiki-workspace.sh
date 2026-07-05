#!/usr/bin/env bash
# llm-wiki web-session workspace bootstrap.
#
# Runs at SessionStart for Claude Code sessions on this repo. It configures the
# roam backend so "put this in the wiki" writes to the roam-archive graph via the
# connected Roam MCP connector — in raw-free capture mode.
#
# Content vs. code separation: this repo holds the SKILL/plugin code (git,
# reviewed via PRs). Wiki CONTENT is NOT committed here — it lives dynamically in
# Roam. So the hub points at an EPHEMERAL scratch dir (outside the repo); there is
# no durable `raw/` and nothing wiki-content-related ever lands in git.
#
# Scope: only sessions launched on this repo run this hook. It writes just the
# llm-wiki config. Delete this hook (and the .claude/settings.json SessionStart
# entry) to opt out.
set -euo pipefail

CFG_DIR="$HOME/.config/llm-wiki"
HUB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/llm-wiki/hub"   # ephemeral scratch, not the repo
mkdir -p "$CFG_DIR" "$HUB_DIR"

cat > "$CFG_DIR/config.json" <<EOF
{
  "hub_path": "$HUB_DIR",
  "wiki_backend": "roam",
  "roam_server": "roam-archive"
}
EOF

echo "llm-wiki: raw-free capture mode -> backend=roam, server=roam-archive (content in Roam, not git)"
