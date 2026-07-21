#!/usr/bin/env bash
# llm-wiki web-session workspace bootstrap.
#
# Runs at SessionStart for Claude Code sessions on this repo. It configures the
# roam backend SINGLE-GRAPH mode: one Roam graph (reached through one connected
# MCP connector) holds the whole pipeline. Raw sources are pages titled
# `RAW/<title>`; compiled articles are ordinary unprefixed pages. The flow is
#   DailyNote (URLs / docs / emails / text)  ->  RAW/*  ->  <Article Title>
# all inside the one `wiki-s` graph. Because raw and wiki share a graph, an
# article links its sources with real `[[RAW/...]]` page links and gets Roam
# backlinks for free. See references/roam-backend.md § Single-graph mode.
#
# Content vs. code separation: this repo holds the SKILL/plugin code (git,
# reviewed via PRs). Wiki CONTENT is NOT committed here — it lives dynamically in
# Roam. So the hub points at an EPHEMERAL scratch dir (outside the repo); there is
# no durable `raw/` and nothing wiki-content-related ever lands in git.
#
# The `wiki-s` MCP connector points at the hosted Roam MCP server for the wiki-s
# graph. It is registered below with STATIC API-KEY auth instead of OAuth: OAuth
# connector tokens expire on every container/session resume, whereas an API key
# supplied via an environment secret survives resumes. The key is read from the
# $ROAM_WIKI_S_TOKEN environment variable (set it as a secret in the web
# environment settings) and is NEVER written into this repo. If the alias or
# endpoint differ, change roam_server/raw_roam_server and ROAM_WIKI_S_URL below.
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
  "roam_server": "wiki-s",
  "raw_roam_server": "wiki-s",
  "raw_mode": "namespace",
  "raw_namespace": "RAW/",
  "meta_namespace": "META/",
  "content_language": "ko"
}
EOF

# --- Register the wiki-s Roam MCP connector with static API-key auth ---
# Re-runs every session (the container is ephemeral, so nothing persists between
# resumes except the env secret). The token is read from the environment and
# passed as a Bearer header; it is never stored in the repo or in config.json.
ROAM_WIKI_S_URL="https://rr0.fly.dev/mcp?graph=wiki-s"
if [ -n "${ROAM_WIKI_S_TOKEN:-}" ]; then
  # Idempotent: drop any stale/OAuth registration of the same alias, then re-add.
  claude mcp remove wiki-s -s local >/dev/null 2>&1 || true
  if claude mcp add --transport http -s local wiki-s "$ROAM_WIKI_S_URL" \
       --header "Authorization: Bearer ${ROAM_WIKI_S_TOKEN}" >/dev/null 2>&1; then
    echo "llm-wiki: registered wiki-s MCP (API-key auth) -> $ROAM_WIKI_S_URL"
  else
    echo "llm-wiki: WARNING could not register wiki-s MCP connector (check 'claude mcp add')"
  fi
else
  echo "llm-wiki: WARNING ROAM_WIKI_S_TOKEN not set -> wiki-s MCP not registered. Add it as an environment secret in the web environment settings."
fi

echo "llm-wiki: single-graph roam mode -> graph=wiki-s, raw=RAW/* pages, wiki=unprefixed pages, log/index/reports=META/* pages (DailyNote -> RAW/* -> article; everything in Roam, nothing on the ephemeral hub)"
