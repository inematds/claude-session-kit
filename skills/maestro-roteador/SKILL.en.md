---
name: maestro-roteador
description: Use when dispatching work to subagents/workflows, when the user hands over a problem and asks which model or effort to use, or before choosing model/effort in any Agent/Workflow call. Triggers - "which model", "how much effort", "triage", "triage this", raw requests that need to be distributed.
---

> English version of [SKILL.md](SKILL.md). The Portuguese file is the operational skill; this translation is kept in sync for reference.

# Maestro Roteador — model and effort selection

## Core principle

Model and effort are **two independent axes that do not convert into each other**:

- **Model** answers: what level of repertoire/judgment does the **hardest step** of the task demand?
- **Effort** answers: how much **deliberation and verification** do the ambiguity and the cost of error pay for?

Effort buys deliberation, never repertoire. Model buys repertoire, never verification. Decide each axis with its own question — never pick a "balanced middle ground" to dodge both questions.

## Procedure (always in this order)

1. **Isolate the hardest step.** Of the whole task, which step demands the finest judgment (taste, subtlety, decisions with no answer key)?
2. **Model = the SMALLEST one that handles that hardest step well.**
   - Mechanical step with a clear answer key (rename, extract, format, pattern-match) → `haiku`
   - Standard implementation/transformation, verifiably right-or-wrong → `sonnet`
   - Requires judgment with no answer key: brand voice, architecture, diagnosis with no obvious cause, adversarial review → `opus` or `fable`
3. **Effort = ambiguity + cost of error.** Add up both signals:
   - Single obvious solution + cheap/reversible error → `low`
   - Some choice between paths OR an error that is annoying to fix → `medium`
   - Several plausible paths OR an expensive error (production, lost data, external publication) → `high`+
   - If you **named a production/loss risk in your justification, effort is at least `high`** — "medium but careful" does not exist.
   - **Evidence ladder (cheap errors only):** if the error is reversible and immediately verifiable (you can test/inspect/undo), start at the **lowest plausible effort** and only climb with **evidence** of an insufficient result — never "high just in case". The ladder NEVER applies to irreversible risk: there, the evidence of failure would be the damage itself, and the rule above applies.
4. **Volume:** N identical items → test 1 item on the smallest model; if it passes, the whole batch goes to it.

## Quick table

| Task | Model | Effort | Why |
|---|---|---|---|
| Batch rename/extract/format | haiku | low | Clear answer key, cheap error |
| Clear feature, localized refactor | sonnet | medium | Standard, verifiable |
| Data migration with production at risk | sonnet | high | Standard capability; the risk demands verification, not intelligence |
| Script/copy with brand voice | fable | low | Hardest step is taste (repertoire); the decision is straightforward |
| Mysterious bug, architecture decision | fable | high | Hard AND ambiguous |

## Traps (seen in real testing)

| Rationalization | Reality |
|---|---|
| "sonnet+medium balances cost and quality" | The middle ground is dodging both questions. Answer each axis; the result is almost never the center of the matrix. |
| "a short script doesn't need heavy reasoning" → downgrades the model | Axes confused. Not needing *deliberation* justifies low effort — it does not justify a smaller model when the hardest step is brand judgment. Fable+low. |
| "medium is enough if I'm careful" (with production at risk) | You named the risk yourself. Named risk = high. Care is exactly what effort buys. |
| "I'll take the bigger model just in case" | If the hardest step is within the smaller model's capability, the bigger one delivers the same while charging more. Insurance is bought with effort/verification. |
| "small model + max effort comes out cheap" | Worst combination: you pay for deliberation in someone who lacks the repertoire to use it, and reasoning tokens pile up. |
| "I'll raise effort so it comes out prettier/more polished" | Effort buys deliberation, not taste. Finish is a MODEL-axis matter (see taste tie). Measured in a real test: from high to max the difference was a favicon, at 2–5× the tokens. |
| "extra effort doesn't help, but it doesn't hurt either" | It hurts: overthinking is the EXCESS of the effort axis itself, not a model defect. On a simple task, leftover deliberation re-explores already-settled paths and over-engineers the solution — the result can come out WORSE, not just more expensive. The right effort is the SMALLEST that covers the risk; above that you're buying noise, not safety. |

## Anti-overhead: triage has a cost too

- **A task cheaper than the triage itself gets no triage** — it goes straight to the turn's default. "Fix this typo" doesn't deserve a dispatch YAML.
- **Triage runs inline in the main turn, never in a subagent** — dispatching an agent just to decide model/effort costs more than the decision is worth.
- **Fragmenting has a cost too:** only dispatch a part to a subagent if its work outweighs the spawn overhead; small mechanical parts run inline even when the matrix would say "haiku".

## Cache: the hidden cost of switching models

The prompt cache is **per model** and depends on the context prefix — switching the main conversation's model throws away the accumulated cache (rewriting costs ~12.5× a read on a large context). Three rules:

- **Switch the main turn's `/model` only at a work boundary** (end of phase, handoff) — never mid-block. On a large context, the switch can cost more than the smaller model saves.
- **Subagents do NOT pay this cost.** Each Agent/Workflow has its own context; routing a part to a smaller model via subagent doesn't touch the main cache. It's the preferred way to use the matrix with no switching cost.
- **Never send an artificial keepalive call** to "hold the cache" — Claude Code manages the cache on its own; the ping costs more than it saves.

## Taste tie → offer the choice (cost × quality)

**Correctness is non-negotiable; efficiency is.** When the model choice depends only on **finish** (copy quality, taste, visual polish) and not on correctness, the decision is a budget one — and the budget belongs to the user. In that case the triage does NOT decide alone: it presents the pair and lets the user choose:

```yaml
options:
  cost: sonnet+low         # correct structure, functional finish
  quality: fable+low       # same structure, superior copy/polish
decides: user
```

Signal of a taste tie: a detailed template/skill has already settled the structure (correctness is guaranteed by the answer key) and all that's left for the big model is voice/finish.

**Never offer the pair when the risk is correctness** — wrong content, lost data, broken production, a course with errors. There, there is no cheap option: the model/effort that guarantees correctness is the minimum, not a choice.

## Output format (dispatch plan)

```yaml
task: <summary>
parts:
  - what: <subtask>
    hardest_step: <which and why>
    model: haiku|sonnet|opus|fable
    effort: low|medium|high|xhigh|max
    risk: <cost of error in 1 line>
main_turn: <a /model recommendation if switching is worth it — the switch belongs to the user>
```

## Limit

For subagents and workflows the decision is automatic (`model`/`effort` parameters). For the main conversation's model the skill only **recommends** — the user switches with `/model`.
