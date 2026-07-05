# Roam Backend

The wiki has two storage backends for the **compiled `wiki/` layer**:

- **`files`** (default) — compiled articles are markdown files under `wiki/concepts|topics|references|theses/`, with derived `_index.md` caches. This is the original behavior; everything else in these references assumes it unless this file says otherwise.
- **`roam`** — compiled articles live as **pages in a self-hosted Roam graph**, written and read through a Roam MCP server (the roamresearch-local `roam-direct` bridge, or the hosted `roam-mcp` server). The `raw/` evidence layer, `inventory/`, `datasets/`, `output/`, `log.md`, and `config.md` stay on disk exactly as before.

The graph can be local (`ROAM_BACKEND=127.0.0.1:9000`) or **hosted** (`ROAM_BACKEND=https://<app>.fly.dev`) — the backend location does not matter to the wiki; only the connected MCP server alias does. A common topology is: Claude Code + `raw/` files on your local machine, the Roam graph on fly.dev, reached through an already-connected MCP server. No local backend process is required in that case.

> **Only the `wiki/` layer moves to Roam.** Ingest, raw sources, inventory, datasets, outputs, sessions, and logs are unchanged. Roam is the *compiled-knowledge engine*, not a replacement for the evidence or operational layers.

This split is deliberate: `raw/` is immutable provenance that belongs in git and on disk; `wiki/` is living, heavily cross-linked synthesis that Roam's outliner + backlinks + Datalog model better than flat markdown.

---

## When this file applies

Read this file **only when the resolved wiki uses the `roam` backend**. With the `files` backend, ignore it entirely and follow `compilation.md` / `indexing.md` / `linting.md` as written.

---

## Backend Resolution

Resolve the backend immediately after resolving the wiki (the HUB + wiki-location steps in each command), before touching the `wiki/` layer:

1. **Per-topic override (authoritative).** In `HUB/wikis.json`, the resolved wiki's entry may carry:
   ```json
   "bitcoin": {
     "path": "topics/bitcoin",
     "backend": "roam",
     "roam_graph": "bitcoin",
     "roam_server": "wiki",
     "raw_roam_server": "wiki-raw"
   }
   ```
   If `backend: "roam"` is present → **roam backend**. Read `roam_graph` (the Roam graph name, for reference/logging), `roam_server` (**the connected MCP alias for the compiled wiki graph** — e.g. `wiki`, `roam-wiki`, `roam-archive`; whatever the user registered), and the optional `raw_roam_server` (the alias for a **separate raw/source graph** — see Two-graph mode). If `raw_roam_server` is absent, raw is on disk or raw-free.
2. **Global default.** Else if `~/.config/llm-wiki/config.json` has `"wiki_backend": "roam"` → roam backend. Use `roam_server` = config `roam_server` (and `raw_roam_server` if present). Do not assume a specific alias.
3. **Otherwise → `files` backend** (default). Proceed exactly as the file-based references describe.

**`roam_server` selects the graph.** Each Roam MCP server points at exactly one graph (its `ROAM_GRAPH`), so the alias in `roam_server` *is* the graph selector. Set it per topic to route each topic wiki to whichever graph you want — a dedicated wiki graph, a per-topic graph, or (if you accept co-mingling) an existing graph. The agent calls tools as `mcp__<roam_server>__roam_*` (e.g. `mcp__roam-wiki__roam_replace_page`). Writes require that server to be registered with `ROAM_MUTATE=1`.

> **Prefer a dedicated wiki graph.** `compile` creates one page per article. Pointing `roam_server` at a large personal/daily-notes graph mixes wiki pages into it. Register a separate graph (or MCP alias) for the wiki layer unless you deliberately want them together.

**Preflight (roam backend only).** Before the first write, confirm the `roam_server` MCP tools (`mcp__<roam_server>__*`) are actually connected. If they are not, stop and tell the user: the topic is configured for the roam backend but its Roam MCP server (`<roam_server>`) is not connected. Do **not** silently fall back to writing files — that would split the wiki across two backends. (Note: `allowed-tools` on the commands lists several common aliases; if your alias differs, add `mcp__<your-alias>` there or approve the tool when prompted.)

---

## Two-graph mode (separate raw + wiki graphs)

When `raw_roam_server` is set, the **raw/source layer lives in its own Roam graph** and the compiled wiki lives in another — e.g. `raw_roam_server: "wiki-raw"` and `roam_server: "wiki"`. Nothing is on disk or in git. This is the durable, dated source archive that `compile` reads from.

Flow:
- **`ingest`** writes a **source page to the raw graph** (`mcp__<raw_roam_server>__*`). One page per source, titled by the source title, with attributes:
  - `type:: source`, `source-url:: <url>` (or `source:: <where it came from>`), `ingested:: [[<today ordinal>]]`, `summary::`, `tags::`
  - the extracted content as child blocks (outliner structure), so the source is self-contained; for a binary/PDF, `roam_upload_file` the original and add `file:: <url>`.
  - Also add a `Source: [[Title]]` link block to **that graph's** today daily note → the raw graph becomes a date-organized inbox.
- **`compile`** reads sources from the **raw graph**, synthesizes, and writes **article pages to the wiki graph** (`mcp__<roam_server>__*`). After compiling a source, stamp it **in the raw graph** with `compiled:: [[<today>]]` and `compiled-into:: <Article Title>` so it is not recompiled.
  - **Incremental / by date:** find uncompiled sources with `roam_datomic_query` on the raw graph — `type:: source` pages lacking a `compiled::` value, or filtered by an `ingested:: [[date]]` range (or by reading a specific day's daily note). This is how "compile the sources I added this week" works.
  - **Manual entries:** the user may add source pages/blocks to the raw graph directly (in the Roam app). Treat any page the user points at — or any `type:: source` page without `compiled::` — as ingestable, even if it lacks full metadata; infer title/summary from its content.

**Cross-graph provenance (important constraint).** `[[links]]` only resolve **within one graph**. An article in the `wiki` graph therefore cannot live-link `[[source]]` in the `wiki-raw` graph. Record provenance on the article as **text attributes**, not cross-graph links:
- `source-title:: <raw page title>` and `source-url:: <url>` (and optionally the raw page's deep-link URL). Within each graph, real `[[links]]` still work (article↔article in `wiki`; source↔source in `wiki-raw`). `raw-source::` (disk path) is not used in this mode.

Everything else about the wiki graph (attribute mapping, `[[title]]` article links, batch `roam_replace_page` writes, daily-note capture log, Datalog reads/lint) is exactly as in the single-graph roam backend — it just points at `roam_server` while ingest points at `raw_roam_server`.

---

## Article ↔ Page mapping

One compiled article = one Roam page. The page title is the article title (human-readable, not the slug). Frontmatter becomes Roam **attributes** (`name:: value`, first-class and Datalog-queryable); body, See Also, and Sources become a nested block tree.

```
Page: "Proof of Work"
├─ category:: concept
├─ confidence:: high
├─ volatility:: warm
├─ verified:: [[June 24th, 2026]]
├─ updated:: [[June 24th, 2026]]
├─ created:: [[June 20th, 2026]]
├─ tags:: #consensus #bitcoin
├─ compiled-from:: sources
├─ raw-source:: topics/bitcoin/raw/papers/2026-01-03-pow.md
├─ aliases:: PoW, hashcash
├─ (body: ## sections → blocks, prose → child blocks, one idea per block)
├─ See Also
│   ├─ [[Nakamoto Consensus]] — why PoW underpins it
│   └─ [[Difficulty Adjustment]]
└─ Sources
    ├─ topics/bitcoin/raw/papers/2026-01-03-pow.md
    └─ topics/bitcoin/raw/articles/2026-01-05-pow-explained.md
```

### Frontmatter → attribute conventions

| Article frontmatter | Roam attribute | Notes |
|---|---|---|
| `title` | page title | not an attribute |
| `category` | `category:: concept\|topic\|reference\|thesis` | drives "placement" (there are no directories in Roam) |
| `confidence` | `confidence:: high\|medium\|low` | |
| `volatility` | `volatility:: hot\|warm\|cold` | |
| `verified` | `verified:: [[<ordinal date>]]` | date page link, e.g. `[[June 24th, 2026]]` |
| `created` / `updated` | `created:: [[…]]` / `updated:: [[…]]` | ordinal date links |
| `tags` | `tags:: #tag1 #tag2` | hashtags so they show in Roam backlinks |
| `aliases` | `aliases:: a, b` | comma-separated |
| `compiled-from` | `compiled-from:: sources\|conversation\|mixed` | |
| `sources` | one block per source under a `Sources` parent **and** a `raw-source::` attribute list | see source tracking below |
| *(no durable raw)* | `source-url:: <url>` | capture mode — provenance when there is no raw file (see Roam-native capture mode) |
| *(optional grouping)* | `topic:: <name>` | optional; groups pages within a single graph (see capture mode) |
| *(capture stamp)* | `captured:: [[<ordinal date>]]` | the daily note the page was captured on |

**Dates use ordinal format** (`June 24th, 2026`, never `June 24, 2026`) — Roam treats the non-ordinal form as a different page. Never give an article a title that collides with a daily-note date.

### Links

- Article → article cross-references use **page links** `[[Other Article Title]]`, **not** block references `((uid))`. Page links survive a full-page rewrite; `((uid))` references would break it (see "Rewriting" below).
- **Backlinks are automatic.** Do not hand-maintain bidirectional "See Also" the way the files backend does — if A links to B, B's linked-references panel already shows A. Compile only needs to write the forward link.
- The "dual-link" convention (`[[slug|Name]] ([Name](path))`) from the files backend is **obsolete** here. Use plain `[[Title]]`.

### Source tracking (the raw↔wiki boundary)

`raw/` is on disk; the article is in Roam. To keep provenance traceable across the boundary, store each source as a **hub-relative path string** (e.g. `topics/bitcoin/raw/papers/2026-01-03-pow.md`):

- as child blocks under a `Sources` parent block (human-readable), and
- as a `raw-source::` attribute (one value per source, machine-queryable for incremental compile and lint coverage).

Never store raw content in Roam — only the path reference. Resolving these paths back to files uses the same Source Reference Resolution protocol as the files backend (`wiki-structure.md`), rooted at HUB.

---

## Roam-native capture mode (raw-free)

A lighter variant of the roam backend for **capture-first, no-durable-local** use — e.g. a phone-only or globally-installed skill where you "just put this into my wiki" and everything lives in one Roam graph. It is the roam backend with three relaxations. Use it when the wiki has **no durable `raw/` layer** (raw is ephemeral or absent).

**Trigger is always explicit.** Only capture when the user explicitly asks ("put this in the wiki", "이거 위키에 넣어줘", `/wiki:ingest`, `/wiki:compile`). Never auto-detect and never capture conversation content the user did not ask you to.

### 1. Raw-optional inputs

There is no durable `raw/` file to point at. Track provenance on the page instead:

| Input | How to compile | Provenance attribute |
|---|---|---|
| **Conversation / context** ("capture this discussion") | synthesize the article directly from the conversation → page | `compiled-from:: conversation` |
| **URL / attachment** (raw not kept) | fetch, extract, synthesize → page; discard the fetched source after | `compiled-from:: sources` + `source-url:: <url>` |

Skip `raw-source::` and the `Sources`-of-file-paths block when there is no raw file. `source-url::` (or `compiled-from:: conversation`) is the honest provenance. Lint's raw-coverage/provenance checks (C4b/C6) do not apply when there is no `raw/` layer — treat them as satisfied by `source-url::`/`compiled-from::`.

### 2. Topic-optional

Do **not** require a topic. A captured page is just a page in the graph. When the user wants grouping, add a `topic:: <name>` attribute (and optionally `#[[Topic/<name>]]`). Query filters by `topic::` only when the user asks for a topic; otherwise search the whole graph. Never invent a topic the user did not name.

### 3. Daily-note integration

On every capture, use the connected server's daily-note tools (`roam_add_to_daily_note`; omit the date so the server computes today's ordinal title):

- **(a) Capture log** — add one block to **today's daily note** linking the new page: `Wiki: [[Article Title]] — <one-line summary>`. This makes the daily note a chronological index and puts the day in the article's backlinks. It replaces the on-disk `log.md`.
- **(b) Daily-note inbox** *(explicit trigger — "compile today's/my recent daily notes into the wiki")* — read the daily note(s) with `roam_fetch_page_by_title` (ordinal title) or `roam_find_pages_modified_today`, synthesize the blocks the user jotted there into one or more articles, then link them back per (a). Do not consume arbitrary daily-note content unless asked.
- **(c) Context stamp** — add `captured:: [[<today ordinal>]]` to each new page.

### 4. Global install (closed-network / self-hosted Claude Code)

For "skill available everywhere, no repo, no local hub":

- Enable the plugin in **user settings** (`~/.claude/settings.json` `enabledPlugins`) so it activates in any directory/session (this is for a self-hosted CLI/desktop Claude Code; Claude Code on the web ignores user-scoped enablement and needs the repo's `.claude/settings.json` instead).
- Register the Roam MCP server globally (`claude mcp add`), pointing at the capture graph.
- Set a global default in `~/.config/llm-wiki/config.json`: `{ "wiki_backend": "roam", "roam_server": "<alias>" }`. No hub directory, no `raw/`, no topics required — conversation capture writes straight to the graph with `compiled-from:: conversation`.

---

## Writing: batch tools, one call per article

Use the roamresearch-local batch primitives so an entire article is **one transaction**, not one call per block:

| Tool | Cost | Use for |
|---|---|---|
| `roam_replace_page({ title, children })` | 1 read + 1 write | Create or fully recompile an article page |
| `roam_create_block({ content, children })` | 1 write | Append a self-contained subtree to a page |
| `roam_apply_page_ops({ ops:[…] })` | 1 tx | Incremental in-place edits that must preserve block uids / `((refs))` |
| `roam_create_table({ rows })` | 1 tx | Render a comparison/table block correctly (Roam tables are an outline, not markdown `\| a \| b \|`) |

**Build the whole article as a nested `children` tree and send it in a single `roam_replace_page` call.** Do not create the page and then append blocks one at a time — that is the per-block anti-pattern this backend exists to avoid.

### Rewriting an existing article

- Default to `roam_replace_page` (1 read + 1 write). Because cross-article links are `[[title]]` page links, a full rewrite is safe — page links are title-based and survive fresh block uids.
- `roam_replace_page` **refuses** if some other block references a block on this page via `((uid))` (returns `{ refused: true, referencing: [...] }`). Since this backend forbids `((uid))` cross-article references by convention, that should not happen. If it does, do **not** blindly `force:true` — fall back to `roam_apply_page_ops` to edit in place (it preserves uids and refs), or surface the conflict.
- Use `roam_apply_page_ops` when you only need to touch a few blocks (e.g. bump `verified::`, fix one paragraph) and want to avoid regenerating the page.

---

## Reading / Query (roam backend)

Replace index-hop file reads with graph queries. There is **no `wiki/_index.md`** in this backend — Datalog and backlinks are the index.

- **Title lookup:** `roam_fetch_page_by_title({ title })` → the page + full block tree.
- **Full-text:** `roam_search_by_text({ text })` → blocks with their page.
- **By tag:** `roam_search_for_tag({ tag })`.
- **Structured/aggregate (the index replacement):** `roam_datomic_query`. Examples:
  - All articles in a category:
    ```
    [:find (pull ?p [:node/title]) :where
      [?p :node/title] [?b :block/page ?p]
      [?b :block/string ?s] [(clojure.string/starts-with? ?s "category:: concept")]]
    ```
  - Article + verified date for freshness scans, coverage by `raw-source::`, etc.
- **Quick** depth ≈ search + attribute pull (no full page reads). **Standard** ≈ fetch the few matched pages. **Deep** ≈ fetch pages + follow `[[links]]` + read backlinks + grep `raw/` **on disk** for detail not yet compiled.
- Citations are page titles / `[[links]]`, not file paths. Raw citations remain disk paths.

---

## Lint / Audit (roam backend)

Structural checks shift from filesystem walks to graph queries; cross-boundary checks stay on disk.

- **C1/C3 (structure, index consistency):** N/A — there are no `wiki/` directories or `_index.md` to drift. Skip with an info line. (raw/, inventory/, datasets/ checks on disk are unchanged.)
- **C2 (frontmatter):** validate that each article page carries `category`, `confidence`, `volatility`, `verified` attributes with valid enum values — via Datalog over `:block/string` `name:: value` blocks.
- **C11 (placement):** there are no directories to move into; instead validate the `category::` attribute value. No `mv`.
- **C4 (link integrity):** find `[[links]]` whose target page does not exist (Datalog: refs to titles with no `:node/title`). Backlinks make bidirectional checks unnecessary.
- **C4b (source provenance) / C6 (coverage):** read each article's `raw-source::` / `sources` blocks, resolve the hub-relative paths against `raw/` **on disk**, and cross-check that every `raw/` source is referenced by ≥1 article (query the union of `raw-source::` values, diff against the disk listing). This is the main raw↔wiki boundary check.
- **C14/C15 (freshness, volatility):** compute from the `verified::`/`updated::`/`volatility::` attributes; `--fix` adds a default `volatility:: warm` via `roam_apply_page_ops`.
- **C18 (missing sources):** article must have a non-empty `raw-source::`/`Sources` or `compiled-from:: conversation`.
- **Auto-fix (`--fix`)** edits attributes/blocks via `roam_apply_page_ops` (preserves uids), never `roam_replace_page` for a one-field fix.

---

## Incremental compile (roam backend)

1. Determine already-compiled sources: `roam_datomic_query` for all `raw-source::` attribute values across the graph → the set of compiled raw paths.
2. List `raw/` on disk; the uncompiled set = disk sources − compiled set (also recompile when a source's `ingested:` is newer than the article's `updated::`).
3. Read uncompiled raw sources from disk, synthesize, write/rewrite article pages with `roam_replace_page`.
4. Update the on-disk master `_index.md` **stats** (source/article counts) by deriving article counts from a Datalog count; there is no `wiki/_index.md` to rebuild.
5. Log to `log.md` on disk as usual.

---

## Other commands

These follow the same backend-resolution step; only their `wiki/`-layer touchpoints change.

- **librarian** — the article-quality scan (staleness, low confidence, weak connections) runs against the graph: `roam_datomic_query`/`roam_fetch_page_by_title` to read articles, `verified::`/`updated::`/`volatility::` attributes for freshness, `[[link]]`/backlink density for connectedness. `fix` edits via `roam_apply_page_ops`. Reports still write to `.librarian/` on disk.
- **audit** — hybrid, like lint: the wiki-content pass reads articles from the graph (reuse librarian's roam-aware scan); the output-drift pass and session-provenance pass stay on disk; source-chain resolution crosses the boundary by resolving each artifact's `sources:`/`raw-source::` entries against `raw/` and against Roam page titles. Reports still write to `.audit/` on disk.
- **output** — gather the article content the artifact synthesizes from the graph (`roam_fetch_page_by_title`/`roam_search_by_text`); the artifact is still written to `output/` on disk. Cite Roam articles by page title in the artifact's `sources:` frontmatter (plus disk `raw/` paths as usual).
- **archive** — the Roam graph is **not** moved or deleted; archiving moves only the on-disk topic directory and flips `wikis.json` `status: "archived"`, which excludes the graph from default workflows. Preserve `backend`/`roam_graph` through archive/restore. `peek` reads `raw/_index.md` on disk plus, if cheap, a titles-only `roam_datomic_query`.
- **research** — its pipeline is search → ingest → compile. Ingest writes `raw/` on disk (unchanged); the compile step is roam-aware per the section above. No research-specific Roam logic beyond that.
- **refresh / ll / inventory / dataset / session / feedback / retract** — disk-only or operate on `raw/`; unaffected by the backend.

## Concerns / boundaries to respect

- **Availability:** roam-backend `compile`/`lint --fix` require the MCP server up with `ROAM_MUTATE=1`. If the backend is unreachable, stop — never split a wiki across files+roam.
- **Git history:** compiled articles are no longer in git. raw/ provenance still is; Roam keeps its own `/log` history. Audit replayability is preserved through `raw-source::` + the disk `raw/` layer.
- **Testing:** structural tests for the roam backend should use `ROAM_DRY_RUN=1` or a disposable test graph; the on-disk golden-wiki fixtures only validate the `files` backend.
- **No `((uid))` cross-article refs** — they break `roam_replace_page`. Use `[[title]]`.
- **Daily-note collision** — never title an article like an ordinal date.
