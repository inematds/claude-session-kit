# claude-session-kit

**🇧🇷 [Português](README.md) · 🇺🇸 [English](README.en.md) · 🇪🇸 [Español](README.es.md)**

[![Claude Session Kit](guia/assets/banner.jpg)](https://inematds.github.io/claude-session-kit/guia/es/)

## 📖 Guía de uso

Guía completa (landing + paso a paso): **https://inematds.github.io/claude-session-kit/guia/es/**

Kit para mantener las sesiones de Claude Code optimizadas: **statusline con cuota real**
(5 h, semanal general y semanal por modelo) + **tres skills de sesión** + **plan
de optimización** que conecta ambas cosas.

```
statusline/
  PROMPT.md               prompt para instalar/configurar la statusline
  statusline-command.sh   el script (bash + jq + curl)
  settings-snippet.json   fragmento de ~/.claude/settings.json
skills/
  PROMPT-instalar.md      prompt para instalar las skills
  session-statusline/     checkpoint rápido a mitad del trabajo
  memory-audit/           auditoría de memoria y CLAUDE.md
  session-handoff/        resumen estructurado antes de /clear
  maestro-roteador/       elige modelo y esfuerzo antes de despachar (cuando la cuota se reduce)
  fable-mindset/          procesa los JSONL de las sesiones y genera un playbook por modelo
PLANO-OTIMIZACAO.md       el ciclo checkpoint → audit → handoff y los disparadores
```

## Statusline

```
nmaldaner@host:~/proj  Fable 5.1/medium  ctx 41%  5h:2%→19:10  w:69% F:80%!→14/09 21:00  d:40.9M
```

`w:` es la cuota semanal de todos los modelos; `F:` es la cuota semanal **del modelo
en uso** (la API envía `weekly_scoped`), con `!` cuando está en alerta. Es la `F:`
la que bloquea primero; el script anterior solo mostraba la `w:` y por eso parecía
que "no se actualizaba".

Instalación: pega `statusline/PROMPT.md` en una sesión de Claude Code, o hazlo
manualmente: copia el script a `~/.claude/statusline-command.sh` y agrega el bloque de
`settings-snippet.json` a `~/.claude/settings.json`.

## Skills

Pega `skills/PROMPT-instalar.md` en una sesión, o copia las carpetas a
`~/.claude/skills/`. La división del trabajo y los disparadores están en `PLANO-OTIMIZACAO.md`.

Las tres primeras forman el ciclo (checkpoint → audit → handoff). Las otras dos
son complementarias: `maestro-roteador` decide el modelo/esfuerzo cuando la barra muestra `F:` en
alerta, y `fable-mindset` mide cómo trabaja cada modelo a partir de los mismos JSONL
que alimentan la `d:` de la barra.

## Teoría detrás

El curso **Mestre em Contexto e Tokens** (https://inematds.github.io/cctop/) es la
base de este kit: relectura del contexto, prompt caching, rutina de `/clear` y
`/compact`, handoff estructurado y subagentes. El kit es la versión en herramientas del curso.

Plugins de terceros compatibles con el ciclo (no incluidos): `context-mode`,
`claude-mem`, `claudex`.

## Requisitos

Claude Code con inicio de sesión OAuth (claude.ai), `jq`, `curl`. El script lee el token de
`~/.claude/.credentials.json` localmente; nada sale de la máquina aparte de la llamada
al endpoint oficial de uso.

Proyecto de investigación/educación — INEMA.
