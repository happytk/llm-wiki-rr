# Roam Backend

The wiki has two storage backends for the **compiled `wiki/` layer**:

- **`files`** (default) — compiled articles are markdown files under `wiki/concepts|topics|references|theses/`, with derived `_index.md` caches. This is the original behavior; everything else in these references assumes it unless this file says otherwise.
- **`roam`** — compiled articles live as **pages in a self-hosted Roam graph**, written and read through a Roam MCP server (the roamresearch-local `roam-direct` bridge, or the hosted `roam-mcp` server). The `raw/` evidence layer, `inventory/`, `datasets/`, `output/`, `log.md`, and `config.md` stay on disk exactly as before.

The graph can be local (`ROAM_BACKEND=127.0.0.1:9000`) or **hosted** (`ROAM_BACKEND=https://<app>.fly.dev`) — the backend location does not matter to the wiki; only the connected MCP server alias does. A common topology is: Claude Code + `raw/` files on your local machine, the Roam graph on fly.dev, reached through an already-connected MCP server. No local backend process is required in that case.

> **Only the `wiki/` layer moves to Roam.** Ingest, raw sources, inventory, datasets, outputs, sessions, and logs are unchanged. Roam is the *compiled-knowledge engine*, not a replacement for the evidence or operational layers.

This split is deliberate: `raw/` is immutable provenance that belongs in git and on disk; `wiki/` is living, heavily cross-linked synthesis that Roam's outliner + backlinks + Datalog model better than flat markdown.

The roam backend has **four topologies**, selected by config (see Backend Resolution):

| Topology | raw layer | wiki layer | Provenance link | When |
|---|---|---|---|---|
| **roam (single-layer)** | disk `raw/*.md` | Roam graph | text `raw-source::` path | keep git-tracked raw, move only synthesis to Roam |
| **Two-graph** | `raw_roam_server` graph | `roam_server` graph | text `source-title::`/`source-url::` (links can't cross graphs) | durable dated source archive, fully in Roam, kept separate from the wiki |
| **Single-graph raw** | `RAW/…` pages in the *same* graph | unprefixed pages in that graph | **real `[[RAW/…]]` page link + automatic backlinks** | one graph, one connector; `DailyNote → RAW/* → article` all in place |
| **Capture (raw-free)** | none (ephemeral) | Roam graph | `source-url::` / `compiled-from:: conversation` | phone-first / "just put this in my wiki", no durable raw |

Single-graph raw mode is the newest and the simplest to operate: **DailyNote → `RAW/<title>` pages → unprefixed article pages**, everything in one graph reached through one MCP connector. Because raw and wiki share a graph, an article links its sources with ordinary `[[RAW/<title>]]` page links and gets Roam backlinks for free — the cross-graph provenance compromise of two-graph mode disappears. See § Single-graph mode.

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
   If `backend: "roam"` is present → **roam backend**. Read `roam_graph` (the Roam graph name, for reference/logging), `roam_server` (**the connected MCP alias for the compiled wiki graph** — e.g. `wiki`, `roam-wiki`, `roam-archive`, `wiki-s`; whatever the user registered), the optional `raw_roam_server` (the alias for the raw/source graph), the optional `raw_namespace` (the title prefix for raw pages in single-graph mode; default `RAW/`), and the optional `meta_namespace` (the title prefix for operational pages — log, index, reports — in single-graph mode; default `META/`). If `raw_roam_server` is absent, raw is on disk or raw-free.
2. **Global default.** Else if `~/.config/llm-wiki/config.json` has `"wiki_backend": "roam"` → roam backend. Use `roam_server` = config `roam_server` (and `raw_roam_server`/`raw_namespace`/`meta_namespace` if present). Do not assume a specific alias.
3. **Otherwise → `files` backend** (default). Proceed exactly as the file-based references describe.

**Which roam topology?** Once the roam backend is resolved, pick the raw-layer topology:

- `raw_roam_server` set **and different** from `roam_server` → **Two-graph mode** (separate raw + wiki graphs).
- `raw_roam_server` **equals** `roam_server` (same alias/graph), **or** `raw_mode: "namespace"` is set → **Single-graph mode**: raw and wiki share one graph, and raw pages are distinguished by the `raw_namespace` title prefix (default `RAW/`). This is the mode to use when you only have one connector/graph.
- `raw_roam_server` absent, raw is on disk → **single-layer roam** (raw stays in `raw/*.md`; only the wiki layer is in Roam).
- No durable raw at all → **Capture mode** (raw-free).

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

## Single-graph mode (raw + wiki in one graph, `RAW/` namespace)

**One graph, one connector.** Raw sources and compiled articles live in the **same** Roam graph, told apart by a **title namespace**: every raw page is titled `RAW/<source title>` (prefix from `raw_namespace`, default `RAW/`); every article is an ordinary unprefixed page. The pipeline is:

```
DailyNote (URLs / docs / emails / pasted text)
   → RAW/<source title>   (durable, immutable source pages)
      → <Article Title>    (compiled, unprefixed wiki pages)
```

Active when `raw_roam_server == roam_server` (or `raw_mode: "namespace"`). This is the mode for "I have one graph and one MCP connector and I want the whole source→raw→wiki pipeline inside it."

**Why a namespace, not just any prefix-free page.** Do **not** treat "any page without the `RAW/` prefix" as an article — daily notes (dated pages), `#tag` pages, and attribute pages are all unprefixed too. Articles are identified **positively** by their attributes (`category::`, and the `updated::`/`verified::` stamps compile writes), exactly as everywhere else. The `RAW/` prefix marks the *raw* layer; it is not a definition of "article." Every query below filters on `RAW/` (in or out) explicitly, never on "no prefix."

### What counts as a source (daily-note inputs)

The **daily note is the inbox.** The user drops sources into today's (or any day's) daily note — or an external agent/this repo attaches them there — and each becomes one `RAW/…` page. A "source block" is any of:

| In the daily note | Becomes `RAW/<title>` with |
|---|---|
| A bare URL / link block | fetched + extracted content as child blocks, `source-url:: <url>` |
| An `.pdf`/file upload or attachment | `roam_upload_file` the original, `file:: <url>`, extracted text as blocks |
| An email (pasted headers + body) | `source:: email`, `from::`/`date::` when present, body as blocks |
| A pasted-text / freeform block | the text as blocks, `source:: note` |
| A block that already `[[links]]` a page | treat that page as the source (no new RAW page unless the user wants a copy) |

The user may also point at a specific block or page directly ("ingest this") — honor that regardless of where it sits.

### Ingest: DailyNote → `RAW/<title>` page

Triggered explicitly (`/wiki:ingest`, "put today's sources into raw", "이거 RAW로 넣어줘"). For each source block:

1. **Resolve title & content.** Fetch the URL / read the attachment / take the pasted text; derive a human title. Title the page `RAW/<Source Title>`. On collision with an existing `RAW/<Source Title>`, append ` (<ordinal date>)` or a `-2` counter — never overwrite an existing raw page (raw is immutable).
2. **Write one page** with `roam_replace_page({ title: "RAW/<Source Title>", children:[…] })` in a single transaction:
   - attributes: `type:: source`, `source-url:: <url>` **or** `source:: <where it came from>`, `ingested:: [[<today ordinal>]]`, `summary::`, `tags::`, and optional `topic::`.
   - the extracted content as an outliner subtree (one idea per block), so the page is self-contained. For binaries/PDFs, `roam_upload_file` the original and add `file:: <url>`.
3. **Link it back to the daily note (non-destructive).** Add a child link under the originating daily-note block — or a fresh block on today's daily note — `Source: [[RAW/<Source Title>]] [[META/Log]] — <one-line>`. Leave the user's original block intact; the daily note becomes the dated index/log, and the RAW page's backlinks show that day. No separate `captured::` stamp is needed in this mode — the RAW page already carries `ingested:: [[today]]` (step 2) and the daily-note link provides the date backlink; `captured::` is only for capture mode, where there is no `ingested::` (see Roam-native capture mode). Do not delete what the user wrote.

Because it is one graph, the daily note ↔ RAW ↔ article links are all **real** `[[links]]` with automatic backlinks — no text-only provenance anywhere in this mode.

### Compile: `RAW/<title>` → `<Article Title>`

Reads uncompiled `RAW/…` pages, synthesizes article pages (unprefixed), and stamps provenance — all in the same graph:

1. **Find uncompiled raw pages** — `roam_datomic_query`: pages whose title starts with the namespace and that lack a `compiled::` value:
   ```
   [:find (pull ?p [:node/title]) :where
     [?p :node/title ?t] [(clojure.string/starts-with? ?t "RAW/")]
     (not [?b :block/page ?p] [?b :block/string ?s]
          [(clojure.string/starts-with? ?s "compiled::")])]
   ```
   (Filter by `ingested:: [[date]]` range, or read a specific day's daily note, for "compile what I added this week/today.")
2. **Synthesize** one or more article pages from the raw content. Write each as one nested `children` tree via `roam_replace_page({ title:"<Article Title>", … })` — one transaction per article. The article title is unprefixed and **must never** start with `RAW/` or collide with an ordinal date (daily-note collision).
3. **Provenance is a real link, not text.** Under a `Sources` parent block, list each source as `[[RAW/<Source Title>]]`, and add a `source:: [[RAW/<Source Title>]]` attribute (one value per source, Datalog-queryable). The RAW page's linked-references now show every article built from it — this is the coverage index. (`raw-source::` disk paths and cross-graph `source-title::` text are **not** used in this mode.)
4. **Stamp the raw page** (not the article) so it is not recompiled: `roam_apply_page_ops` to add `compiled:: [[<today ordinal>]]` and `compiled-into:: [[<Article Title>]]` to the `RAW/…` page. Never rewrite the raw page's content — raw is immutable; only append these two provenance attributes.
5. **Capture log** — add `Wiki: [[<Article Title>]] — <one-line summary>` to today's daily note (`roam_add_to_daily_note`, omit the date). Set `compiled-from:: sources`, plus `created::`/`updated::`/`verified:: [[<today>]]` on the article as usual.

### Reading / query (single-graph mode)

Search and tag tools now return **both** raw and article pages from the one graph, so filter by layer:

- **Answering wiki questions** → exclude `RAW/…` source pages, `META/…`/`Output/…` operational pages (`(not (clojure.string/starts-with? ?t "RAW/"))` etc.), daily notes, and tag pages; answer from articles (positively: pages with a `category::`), cite by page title.
- **Provenance / "where did this come from"** → follow the article's `source:: [[RAW/…]]` links (or a raw page's backlinks) — no disk hop.
- **Full-text into raw** → `roam_search_by_text` and keep only `RAW/…` hits when you specifically want source evidence.

### Lint / coverage (single-graph mode)

All in-graph, no disk crossing:

- **Coverage (C6):** every `RAW/…` page should have ≥1 backlink from an article (or a `compiled::` stamp). Query raw pages with no incoming `source::` link → uncompiled/orphan sources.
- **Provenance (C4b/C18):** every article must carry a non-empty `source:: [[RAW/…]]` (or `compiled-from:: conversation`). No path-resolution against disk.
- **Link integrity (C4):** `[[RAW/…]]` targets that don't exist as pages → broken source links.
- C2/C11/C14/C15 and `--fix` behave exactly as the roam backend section below (`roam_apply_page_ops` for one-field fixes). C1/C3 remain N/A.

### Operational state (log, index, reports) → daily note + `META/`, never disk

**Single-graph mode writes nothing durable to disk.** The hub is treated as ephemeral (in the web/container setup it is a scratch dir that disappears between sessions). Every operational artifact that other backends keep on disk lives in Roam instead.

**The daily note *is* the activity log; `[[META/Log]]` aggregates it via backlinks.** Roam's daily note is already a date-organized log — the native replacement for `log.md`. Do **not** accumulate a second copy of the content on a `META/Log` page. Instead, each mutating operation appends one block to **today's daily note** (`roam_add_to_daily_note`, omit the date) and tags that block with a **`[[META/Log]]` page link**. The block's content lives once, on the daily note; `[[META/Log]]` stays an (otherwise empty) hub page whose **linked references collect every log block across all dates** — so "show me the whole log" is just that page's backlinks.

- ingest → `Source: [[RAW/<Title>]] [[META/Log]] — <one-line>`
- compile → `Wiki: [[<Article>]] [[META/Log]] — <one-line>`
- lint --fix / librarian fix / output → `<operation> [[META/Log]] — <what changed>`

That single block is the human-facing index entry **and** the log record, and `[[META/Log]]` is the collect-all view — one write, no duplicated content.

**Finding the log** (for a "show/collect the wiki log" request): read `[[META/Log]]`'s backlinks — `roam_fetch_page_by_title "META/Log"` returns its linked references, or Datalog for blocks referencing the `META/Log` page, ordered by their daily-note date. Never scan for a content-bearing log page; there isn't one.

**`META/` holds only what a date log cannot: single-value state and reports** (prefix from `meta_namespace`, default `META/`). Like `RAW/…`, `META/…` pages are **not** articles (no `category::`) and are excluded from query answers.

| State that needs one durable home | Page | How |
|---|---|---|
| current stats + last-run stamps | **`[[META/Index]]`** | attributes updated in place via `roam_apply_page_ops`: `last-compiled:: [[date]]`, `last-lint:: [[date]]`, and optional `sources:: N` / `articles:: N` **stamps**. Counts are **authoritative from Datalog** (`RAW/…` page count, article `category::` count); `META/Index` is a convenience cache, so a stale count is a refresh, never a lint failure. No "Recent Changes" list here — that is the daily note's job. |
| librarian / audit reports | **`[[META/Librarian <ordinal>]]`**, **`[[META/Audit <ordinal>]]`** | write the report as a block tree; log it with a daily-note `[[META/Log]]` block. |
| generated outputs | **`[[Output/<name>]]`** (or deliver to the user directly) | `output` synthesizes into an `Output/…` page; cite Roam articles by `[[title]]`. Do not depend on the ephemeral hub for the deliverable. |

Rules:

- **Never create the hub files** (`log.md`, `_index.md`, `wikis.json`, `raw/`, `.librarian/`, `.audit/`, `output/`) in single-graph mode. If the hub scratch dir has none, that is expected — the graph is the durable store. The Structural Guardian's disk checks (hub integrity, index freshness, orphan detection) are **N/A**; run their Roam equivalents (does `META/Index` exist, do its counts match Datalog) or skip with an info line. Do not "repair" by writing files to the ephemeral hub.
- **The log step for every mutating command is a daily-note block tagged `[[META/Log]]`** (ingest, compile, lint --fix, librarian fix, output) — never a content-bearing log page. Collect the log from `[[META/Log]]`'s backlinks.
- **Sessions/feedback** (`HUB/.sessions/…`) are a separate harness-hook subsystem that also lives on the ephemeral hub; in single-graph mode treat them as best-effort/ephemeral. Promoting a session or feedback note into the wiki writes a `RAW/…` page (then compile), not a disk file.

Everything else (attribute mapping, batch writes, `roam_apply_page_ops` rewrite rules, no `((uid))` cross-refs, daily-note-collision rule) is identical to the rest of this file.

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
| `sources` | one block per source under a `Sources` parent **and** a `raw-source::` attribute list | files/single-layer/two-graph; see source tracking below |
| `sources` *(single-graph)* | `source:: [[RAW/<title>]]` attribute + `[[RAW/<title>]]` blocks under `Sources` | single-graph mode — real in-graph link, not a path; backlinks give coverage |
| *(no durable raw)* | `source-url:: <url>` | capture mode — provenance when there is no raw file (see Roam-native capture mode) |
| *(optional grouping)* | `topic:: <name>` | optional; groups pages within a single graph (see capture mode) |
| *(capture stamp)* | `captured:: [[<ordinal date>]]` | **capture mode only** — the daily note a raw-free page was captured on. In single-graph mode use `ingested::` on the RAW page instead (no `captured::`). |

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
4. Update the on-disk master `_index.md` **stats** (source/article counts) by deriving article counts from a Datalog count; there is no `wiki/_index.md` to rebuild. **(Single-graph mode: update `[[META/Index]]` in Roam instead — the hub is ephemeral, nothing is written to disk. See § Single-graph mode → Operational state.)**
5. Log to `log.md` on disk as usual. **(Single-graph mode: append one daily-note block tagged `[[META/Log]]` instead — the daily note is the log; collect it via `[[META/Log]]` backlinks. No disk, no content-log page.)**

---

## Other commands

These follow the same backend-resolution step; only their `wiki/`-layer touchpoints change.

- **librarian** — the article-quality scan (staleness, low confidence, weak connections) runs against the graph: `roam_datomic_query`/`roam_fetch_page_by_title` to read articles, `verified::`/`updated::`/`volatility::` attributes for freshness, `[[link]]`/backlink density for connectedness. `fix` edits via `roam_apply_page_ops`. Reports still write to `.librarian/` on disk. **(Single-graph mode: write the report to `[[META/Librarian <ordinal>]]` in Roam — no disk.)**
- **audit** — hybrid, like lint: the wiki-content pass reads articles from the graph (reuse librarian's roam-aware scan); the output-drift pass and session-provenance pass stay on disk; source-chain resolution crosses the boundary by resolving each artifact's `sources:`/`raw-source::` entries against `raw/` and against Roam page titles. Reports still write to `.audit/` on disk. **(Single-graph mode: everything is in the graph — resolve `source:: [[RAW/…]]` links, write the report to `[[META/Audit <ordinal>]]`, no disk pass.)**
- **output** — gather the article content the artifact synthesizes from the graph (`roam_fetch_page_by_title`/`roam_search_by_text`); the artifact is still written to `output/` on disk. Cite Roam articles by page title in the artifact's `sources:` frontmatter (plus disk `raw/` paths as usual). **(Single-graph mode: synthesize into an `[[Output/<name>]]` page in the graph, or deliver directly to the user — do not rely on the ephemeral hub.)**
- **archive** — the Roam graph is **not** moved or deleted; archiving moves only the on-disk topic directory and flips `wikis.json` `status: "archived"`, which excludes the graph from default workflows. Preserve `backend`/`roam_graph` through archive/restore. `peek` reads `raw/_index.md` on disk plus, if cheap, a titles-only `roam_datomic_query`.
- **research** — its pipeline is search → ingest → compile. Ingest writes `raw/` on disk (unchanged); the compile step is roam-aware per the section above. No research-specific Roam logic beyond that.
- **refresh / ll / inventory / dataset / session / feedback / retract** — disk-only or operate on `raw/`; unaffected by the backend.

## Concerns / boundaries to respect

- **Availability:** roam-backend `compile`/`lint --fix` require the MCP server up with `ROAM_MUTATE=1`. If the backend is unreachable, stop — never split a wiki across files+roam.
- **Git history:** compiled articles are no longer in git. raw/ provenance still is; Roam keeps its own `/log` history. Audit replayability is preserved through `raw-source::` + the disk `raw/` layer.
- **Testing:** structural tests for the roam backend should use `ROAM_DRY_RUN=1` or a disposable test graph; the on-disk golden-wiki fixtures only validate the `files` backend.
- **No `((uid))` cross-article refs** — they break `roam_replace_page`. Use `[[title]]`.
- **Daily-note collision** — never title an article like an ordinal date.
