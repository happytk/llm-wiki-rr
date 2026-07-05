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
# The `wiki-s` MCP connector is provided by the user (register a Roam MCP server
# whose ROAM_GRAPH is the test graph, with ROAM_MUTATE=1 for writes). If the alias
# differs, change roam_server/raw_roam_server below to match.
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

echo "llm-wiki: single-graph roam mode -> graph=wiki-s, raw=RAW/* pages, wiki=unprefixed pages, log/index/reports=META/* pages (DailyNote -> RAW/* -> article; everything in Roam, nothing on the ephemeral hub)"
