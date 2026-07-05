---
title: "New in Claude Managed Agents: dreaming, outcomes, and multiagent orchestration"
source: "https://claude.com/blog/new-in-claude-managed-agents"
type: articles
ingested: 2026-07-05
tags: [claude, managed-agents, multiagent-orchestration, agent-memory, evaluation]
summary: "Anthropic announces three updates to Claude Managed Agents: Dreaming (scheduled self-improvement over sessions/memory), Outcomes (rubric-graded output improvement), and Multiagent Orchestration (lead agent decomposing tasks into parallel subagents). Published May 19, 2026."
---

# New in Claude Managed Agents: dreaming, outcomes, and multiagent orchestration

**Source:** https://claude.com/blog/new-in-claude-managed-agents
**Published:** May 19, 2026

Anthropic announced three major updates to Claude Managed Agents.

## Dreaming (Research Preview)

A scheduled process that reviews agent sessions and memory stores to identify
patterns and enable self-improvement. The system can automatically update memory
or allow human review before changes take effect. It "surfaces patterns that a
single agent can't see on its own" — recurring mistakes and shared team
preferences — while restructuring memory to maintain signal quality over time.

## Outcomes (Public Beta)

Developers define success rubrics that agents work toward. A separate grader
evaluates outputs against these criteria using its own context window, preventing
influence from the agent's reasoning process. When outputs fall short, the grader
identifies needed improvements and agents take additional passes. Testing showed
up to 10-point task success improvements, with gains reaching +8.4% on docx file
generation and +10.1% on pptx files.

## Multiagent Orchestration (Public Beta)

Lead agents can decompose complex tasks into specialized subagents with distinct
models, prompts, and tools. Subagents work in parallel on shared filesystems
while contributing to collective context. The Claude Console provides full
visibility into task delegation and execution steps.

## Additional Features

- Webhook notifications when agents complete tasks
- Enhanced memory systems for long-running operations
- Persistent event logging across agent interactions

## Real-World Applications

Harvey, Netflix, Spiral, and Wisedocs have deployed these features for legal
document drafting, log analysis, parallel writing tasks, and quality assurance,
achieving significant efficiency gains.
