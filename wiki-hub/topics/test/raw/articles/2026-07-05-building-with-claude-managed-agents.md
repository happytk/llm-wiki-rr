---
title: "The evolution of agentic surfaces: building with Claude Managed Agents"
source: "https://claude.com/blog/building-with-claude-managed-agents"
type: articles
ingested: 2026-07-05
tags: [claude, managed-agents, agent-sdk, agent-infrastructure, sandboxing, observability, mcp]
summary: "Anthropic's guide to moving agents from prototype to production with Claude Managed Agents. Decouples the reasoning 'brain' from the sandboxed 'hands' via three resources (Agents, Environments, Sessions), with Vault-based credentials, ~60% median latency gains, durable/resumable sessions, and automatic harness evolution. Published June 10, 2026."
---

# The evolution of agentic surfaces: building with Claude Managed Agents

**Source:** https://claude.com/blog/building-with-claude-managed-agents
**Published:** June 10, 2026

## Overview

How Claude Managed Agents takes teams from prototype agents to production
deployments at scale. Traces the evolution from the 2023 token-in/token-out
Claude API → Claude Code (2025, its own agent harness) → the Claude Agent SDK →
the managed service.

## Core architecture

Decouples the reasoning engine ("the brain") from the execution environment
("the hands"). The harness runs independently from sandboxed code execution;
sessions are append-only event logs connecting both.

### Three resources

- **Agents** — configurations combining model, prompt, tools, and guardrails.
- **Environments** — execution contexts: sandbox containers and networking rules.
- **Sessions** — individual runs pairing an agent with an environment, keeping a
  persistent history.

## Key benefits

- **Security & credentials** — MCP/CLI/repo tokens live outside sandboxes in
  Vaults, using envelope encryption + signed request verification, so
  prompt-injection can't exfiltrate secrets.
- **Performance** — decoupling lets Claude reason while the environment spins up
  in parallel; ~60% median latency improvement, >90% at p95.
- **Durability & observability** — sessions persist full event histories outside
  process execution: real-time event streaming, resumable/checkpointed sessions,
  debugging timelines, and automatic memory refinement ("Dreaming").
- **Deployment flexibility** — Anthropic-managed cloud containers or self-hosted
  sandboxes in a VPC; MCP tunnels reach private network resources within
  boundary controls.

## Production challenges addressed

Hosting/autoscaling, session persistence/state, filesystem workspace
provisioning, code-execution isolation, credential access without exposure, and
comprehensive observability/auditability.

## Harness evolution

Harnesses need continuous refinement. On Claude Sonnet 4.5 agents showed
"context anxiety," rushing near context limits; the team added context resets as
a workaround. That behavior vanished on Claude Opus 4.5, making the resets
needless overhead. Managed Agents absorbs such changes automatically — model
updates become config changes, not re-architecture.

## Customer applications

- **Notion** — Custom Agents for task assignment with document/meeting data.
- **Rakuten** — multi-department specialist agents shipped ~1 week each.
- **Sentry** — debugging agent paired with patch-writing.
- **Asana & Atlassian** — task management and Jira workflow integration.

## Getting started

Claude Developer Console at platform.claude.com — template-based or
natural-language agent creation. Claude Code ships the `/claude-api` skill
(reference material) and `/claude-api managed-agents-onboard` for guided setup.

## Strategic value

Managing infrastructure and harness evolution frees teams to invest in
differentiation: context management and domain expertise.
