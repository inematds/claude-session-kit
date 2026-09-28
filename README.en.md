# claude-session-kit

**🇧🇷 [Português](README.md) · 🇺🇸 [English](README.en.md) · 🇪🇸 [Español](README.es.md)**

[![Claude Session Kit](guia/assets/banner.jpg)](https://inematds.github.io/claude-session-kit/guia/en/)

## 📖 User Guide

Complete guide (landing page + step-by-step instructions): **https://inematds.github.io/claude-session-kit/guia/en/**

A kit for keeping Claude Code sessions lean: **statusline with actual usage quotas**
(5-hour, overall weekly, and weekly per model) + **three session skills** + **an optimization
plan** that ties them together.

```
statusline/
  PROMPT.md               prompt to install/configure the statusline
  statusline-command.sh   the script (bash + jq + curl)
  settings-snippet.json   snippet for ~/.claude/settings.json
skills/
  PROMPT-instalar.md      prompt to install the skills
  session-statusline/     quick checkpoint in the middle of work
  memory-audit/           memory and CLAUDE.md audit
  session-handoff/        structured summary before /clear
  maestro-roteador/       chooses model and effort before dispatching (when the quota gets tight)
  fable-mindset/          mines session JSONL files and generates a playbook for each model
PLANO-OTIMIZACAO.md       the checkpoint → audit → handoff cycle and its triggers
```

## Statusline

```
nmaldaner@host:~/proj  Fable 5.1/medium  ctx 41%  5h:2%→19:10  w:69% F:80%!→14/09 21:00  d:40.9M
```

`w:` is the weekly quota for all models; `F:` is the weekly quota **for the model
in use** (the API returns `weekly_scoped`), with `!` when it is in alert status. `F:`
is the one that gets blocked first—the old script only showed `w:`, which made it seem like it
“wasn’t updating.”

Installation: paste `statusline/PROMPT.md` into a Claude Code session, or do it
manually: copy the script to `~/.claude/statusline-command.sh` and add the block from
`settings-snippet.json` to `~/.claude/settings.json`.

## Skills

Paste `skills/PROMPT-instalar.md` into a session, or copy the folders to
`~/.claude/skills/`. Work breakdown and triggers are in `PLANO-OTIMIZACAO.md`.

The first three make up the cycle (checkpoint → audit → handoff). The other two
are supporting tools: `maestro-roteador` chooses the model/effort when the bar shows `F:` in
alert status, and `fable-mindset` measures how each model works using the same JSONL files
that feed the bar’s `d:`.

## Theory behind it

The **Mastering Context and Tokens** course (https://inematds.github.io/cctop/) is the
foundation for this kit: context rereading, prompt caching, a `/clear` and `/compact`
routine, structured handoff, and subagents. The kit is the course’s tool-based version.

Third-party plugins compatible with the cycle (not included): `context-mode`,
`claude-mem`, `claudex`.

## Requirements

Claude Code with OAuth login (claude.ai), `jq`, `curl`. The script reads the token from
`~/.claude/.credentials.json` locally; nothing leaves the machine except the call
to the official usage endpoint.

Research/education project — INEMA.
