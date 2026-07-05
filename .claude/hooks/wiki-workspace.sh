#!/usr/bin/env bash
# llm-wiki web-session workspace bootstrap.
#
# Runs at SessionStart for Claude Code sessions on this repo. It points the
# llm-wiki hub at an in-repo directory (so `raw/`, hub registry, and logs are
# durable — committable — instead of vanishing with the ephemeral cloud VM) and
# defaults the compiled `wiki/` layer to the roam backend on the `roam-archive`
# graph (reached via the already-connected Roam MCP connector).
#
# Scope: only sessions launched on this repo run this hook. It writes just the
# llm-wiki config; it touches nothing else. Delete this hook (and the
# .claude/settings.json SessionStart entry) to opt out.
#
# The compiled articles live in Roam (durable on fly.dev). The `raw/` evidence
# layer lives under wiki-hub/ in the repo — commit it to keep provenance.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
CFG_DIR="$HOME/.config/llm-wiki"
mkdir -p "$CFG_DIR"

cat > "$CFG_DIR/config.json" <<EOF
{
  "hub_path": "$ROOT/wiki-hub",
  "wiki_backend": "roam",
  "roam_server": "roam-archive"
}
EOF

echo "llm-wiki: hub -> $ROOT/wiki-hub, backend=roam, server=roam-archive"
