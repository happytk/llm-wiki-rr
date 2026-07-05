---
description: "Compile raw sources into wiki articles. Synthesizes, cross-references, and organizes active knowledge."
argument-hint: "[--full] [--source <path>] [--topic <name>] [--include-archived] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mv:*), Bash(mkdir:*), mcp__roam-direct, mcp__roam, mcp__roam-wiki, mcp__roam-archive, mcp__wiki, mcp__wiki-raw
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`) and prefer that path; use `resolved_path` only as a fallback cache when the expanded `hub_path` is unavailable and `resolved_path` is initialized. If config has only `resolved_path`, use it. If the configured path can be statted but reading `wikis.json` or listing `topics/` fails with `Operation not permitted`, stop and ask the user to grant Full Disk Access/iCloud Drive access to the launcher; do not fall back to `~/wiki` or `resolved_path`. Do not write machine-specific `resolved_path` into shared configs.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup with portable path resolution (`<HUB>`, `~`, absolute, or HUB-relative); if the registry path is stale, fall back to `HUB/topics/<name>`; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing → stop with "No wiki found. Run `/wiki init` first."
5. **Resolve the backend.** Check the resolved wiki's `wikis.json` entry for `backend: "roam"` (else the global `wiki_backend` in `config.json`, else `files`). If **roam**, read `skills/wiki-manager/references/roam-backend.md` and write the `wiki/` layer to the Roam graph via its MCP batch tools instead of to files; `raw/` and all other layers stay on disk. The default **files** backend behaves exactly as below.

Read the compilation protocol at `skills/wiki-manager/references/compilation.md` and the indexing protocol at `skills/wiki-manager/references/indexing.md`. Then compile raw sources into wiki articles.

Inventory awareness: compile consumes `raw/` and writes `wiki/`; it does not
compile inventory records into articles. Read `inventory/_index.md` only to
notice active candidates, blocked source queues, or next actions that explain
why sources were ingested. If compilation completes work represented by an
inventory record, report the recommended record update instead of silently
changing operational state.

Archive awareness: compile targets active topic wikis only by default. If the
resolved `--wiki <name>` path is archived (`wikis.json` status `archived` or
path under `topics/.archive/`), stop and ask the user to restore the topic or
rerun with `--include-archived`. When `--include-archived` is present, compile
only inside that archived topic path and keep it archived; do not use archived
raw sources to update active articles.

### Parse $ARGUMENTS

- **--full**: Recompile everything from scratch
- **--source <path>**: Compile only this specific source file
- **--topic <name>**: Create or update a specific topic article
- **--include-archived**: Explicitly compile an archived target wiki. Never
  makes the wiki active.

### Compilation Process

> **Roam backend:** follow `references/roam-backend.md` for steps 4–8. In short: determine already-compiled sources with a `roam_datomic_query` over `raw-source::` (not a `wiki/_index.md` read); skip the placement pre-check (step 0) and bidirectional-link step (step 6 — Roam backlinks are automatic); write each article as one nested `children` tree via `roam_replace_page` (one transaction per article, never block-by-block); cross-link with `[[Title]]` page links, never `((uid))`; and in step 7 update only the on-disk master `_index.md` stats (there is no `wiki/_index.md`). Everything else (survey of `raw/`, reading sources, logging) is unchanged.
>
> **Two-graph mode (raw graph → wiki graph):** when `raw_roam_server` is set (see `references/roam-backend.md` § Two-graph mode), determine uncompiled sources by querying the **raw graph** (`mcp__<raw_roam_server>__roam_datomic_query` for `type:: source` pages lacking a `compiled::` value, or filtered by `ingested:: [[date]]` range / a day's daily note) instead of surveying disk `raw/`. Read those source pages, synthesize, and write articles to the **wiki graph** (`mcp__<roam_server>__*`). After each source is compiled, stamp it in the raw graph with `compiled:: [[today]]` and `compiled-into:: <Article Title>`. Provenance on the article is text (`source-title::`/`source-url::`), not a cross-graph `[[link]]`. Also honor "compile the source I just added to <raw graph>" — read the page the user names.
>
> **Roam-native capture mode (raw-free):** when the wiki has no durable `raw/` layer (see `references/roam-backend.md` § Roam-native capture mode), compile directly from the explicitly-provided input — conversation (`compiled-from:: conversation`) or a fetched URL (`source-url::`, raw not kept) — with no raw survey. Topic is optional (`topic::` only when the user names one). On each capture, also add a `Wiki: [[Title]]` block to today's daily note (`roam_add_to_daily_note`, omit the date) and stamp `captured:: [[<today ordinal>]]`. Only ever capture when the user explicitly asks.

0. **Placement pre-check** (C13 + C11 from `references/linting.md`): Before surveying, walk `raw/` and for each `.md` file read its frontmatter. Rewrite any legacy keys/values using the C13 alias table. Then compare the file's `type` field to its actual directory — if it's misplaced (e.g., `type: papers` but sitting in `raw/notes/`, or loose at the wiki root), `mv` it to the canonical path, creating the destination directory if needed. This is the same rule lint uses, run inline because you're already reading every frontmatter. It heals both user miscategorization and stale layouts from older wiki versions — there is no separate migration pass. On slug collisions at the destination, skip and warn. Do this before step 1 so the survey sees canonical state. Does not touch `output/projects/` — that's compile step 7's territory.

1. **Survey**: Read `raw/_index.md` to see all sources. Read `wiki/_index.md` to see existing articles. For incremental mode, identify sources ingested after the "Last compiled" date in master `_index.md`.

2. If no uncompiled sources found (incremental mode), report: "All sources are already compiled. Use `--full` to recompile everything."

3. **Read sources**: Read each uncompiled source in full. Extract key concepts, facts, relationships.

4. **Plan**: For each concept found:
   - Check existing wiki articles (via `wiki/_index.md` summaries and tags)
   - Decide: create new article, update existing, or mention within another article
   - Classify new articles as concept, topic, or reference

5. **Write/Update articles**: Follow the protocol in `references/compilation.md` and core principle #9 (chunked writes):
   - New articles: Write frontmatter + abstract first, then Edit to append body, See Also, Sources
   - Updated articles: use Edit to integrate new information, update frontmatter dates
   - Every article must link to at least one other via See Also

5.5. **Self-validation pass**: For every article touched in step 5 (new or updated), re-read the frontmatter and verify:
   - `sources:` is a non-empty list resolving to existing raw files, OR `compiled-from: conversation` is set
   - `volatility:` is set to `hot`, `warm`, or `cold`
   - `verified:` is set to today's date
   - `confidence:` is set to `high`, `medium`, or `low`

   If any check fails, halt with: `Article <path>: missing required frontmatter (<field>). See references/compilation.md § Step 5 (write protocol) and references/wiki-structure.md § Volatility Classification.` This catches silent agent skips before lint has to catch them later. Do not "fix and continue" — stop, surface the failure, let the user re-run with awareness.

6. **Bidirectional links**: For every See Also link A→B, ensure B→A exists

7. **Update indexes (best-effort)**: Update `wiki/concepts/_index.md`, `wiki/topics/_index.md`, `wiki/references/_index.md`, `wiki/_index.md`, and master `_index.md` (article count, "Last compiled" date, Recent Changes). If `output/projects/` exists, rebuild `output/_index.md` as a projects-aware listing: scan each `output/projects/*/WHY.md` for its first `#` heading (title) and first non-heading paragraph (goal), list them as a table, then list any remaining loose outputs in `output/` below. If any index update is skipped or interrupted, no data is lost — the next read operation will detect the stale index and rebuild it from file frontmatter. See `references/indexing.md` Derived Index Protocol and `references/compilation.md` Step 7.

8. **Log**: Append to `log.md`: `## [YYYY-MM-DD] compile | N sources → X new articles, Y updated (list slugs)`

9. **Report**:
   - Sources processed: N
   - New articles created: list with paths
   - Existing articles updated: list with paths
   - New cross-references added: count
   - Volatility set: count of `hot`, `warm`, `cold` articles touched. If any are `hot`, append a one-line note pointing at `references/wiki-structure.md § Volatility Classification` so the author can confirm the rubric matched their intent.
   - Suggest: `/wiki:lint` to verify consistency
