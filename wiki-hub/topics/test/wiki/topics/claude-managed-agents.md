---
title: "Claude Managed Agents"
category: topic
sources: [raw/articles/2026-07-05-claude-managed-agents.md]
created: 2026-07-05
updated: 2026-07-05
tags: [claude, managed-agents, multiagent-orchestration, agent-memory, evaluation]
aliases: [Managed Agents, Claude Agents Platform]
confidence: medium
volatility: hot
verified: 2026-07-05
compiled-from: sources
summary: "Anthropic's Claude Managed Agents platform gained three capabilities in May 2026: Dreaming (scheduled memory self-improvement), Outcomes (rubric-graded output refinement), and Multiagent Orchestration (lead-agent task decomposition into parallel subagents)."
---

# Claude Managed Agents

> Claude Managed Agents is Anthropic's hosted platform for building and running
> agents. A May 2026 update added three capabilities aimed at making agents
> self-improving, goal-directed, and able to coordinate as teams: **Dreaming**,
> **Outcomes**, and **Multiagent Orchestration**.

## Dreaming

Dreaming (research preview) is a scheduled offline process that reviews an
agent's past sessions and memory stores to find patterns a single in-the-moment
agent can't see — recurring mistakes and shared team preferences. It restructures
memory to preserve signal quality over time and can either update memory
automatically or route proposed changes through human review first. Conceptually
it treats memory as something curated between runs rather than only appended
during them.

## Outcomes

Outcomes (public beta) lets developers define success rubrics that agents work
toward. A **separate grader** evaluates each output against the rubric in its own
context window, so the grading is not contaminated by the agent's own reasoning.
When an output falls short, the grader names the gap and the agent takes another
pass. Reported gains were up to ~10 points of task success, including **+8.4% on
docx generation** and **+10.1% on pptx generation**. This is essentially an
LLM-as-judge refinement loop wired into the platform.

## Multiagent Orchestration

Multiagent Orchestration (public beta) lets a **lead agent** decompose a complex
task into specialized **subagents**, each with its own model, prompt, and tools.
Subagents run in parallel over a shared filesystem and feed back into a shared
collective context. The Claude Console exposes full visibility into how the lead
agent delegated work and each execution step.

## Supporting Features

- **Webhook notifications** when agents finish tasks
- **Enhanced memory** for long-running operations
- **Persistent event logging** across agent interactions

## Adoption

Harvey, Netflix, Spiral, and Wisedocs were cited as early deployments — legal
document drafting, log analysis, parallel writing, and QA respectively.

## See Also

- _No sibling articles yet — this is the first article in the `test` topic._

## Sources

- [New in Claude Managed Agents](../../raw/articles/2026-07-05-claude-managed-agents.md) — the announcement blog post (all three features, benchmarks, and adopters)
