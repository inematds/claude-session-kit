# claude-session-kit

[![Claude Session Kit](guia/assets/banner.jpg)](https://inematds.github.io/claude-session-kit/guia/)

## 📖 Guia de uso

Guia completo (landing + passo a passo): **https://inematds.github.io/claude-session-kit/guia/**

Kit pra manter sessões do Claude Code enxutas: **statusline com cota real**
(5 h, semanal geral e semanal por modelo) + **três skills de sessão** + **plano
de otimização** que liga as duas coisas.

```
statusline/
  PROMPT.md               prompt pra instalar/configurar a statusline
  statusline-command.sh   o script (bash + jq + curl)
  settings-snippet.json   trecho do ~/.claude/settings.json
skills/
  PROMPT-instalar.md      prompt pra instalar as skills
  session-statusline/     checkpoint rápido no meio do trabalho
  memory-audit/           auditoria de memória e CLAUDE.md
  session-handoff/        resumo estruturado antes do /clear
  maestro-roteador/       escolhe modelo e esforço antes de despachar (quando a cota aperta)
  fable-mindset/          minera os JSONL das sessões e gera playbook por modelo
PLANO-OTIMIZACAO.md       o ciclo checkpoint → audit → handoff e os gatilhos
```

## Statusline

```
nmaldaner@host:~/proj  Fable 5.1/medium  ctx 41%  5h:2%→19:10  w:69% F:80%!→14/09 21:00  d:40.9M
```

`w:` é a cota semanal de todos os modelos; `F:` é a cota semanal **do modelo
em uso** (a API manda `weekly_scoped`), com `!` quando está em alerta. É a `F:`
que bloqueia primeiro — o script antigo só mostrava a `w:` e por isso parecia
"não atualizar".

Instalação: cole `statusline/PROMPT.md` numa sessão do Claude Code, ou faça na
mão: copie o script pra `~/.claude/statusline-command.sh` e adicione o bloco de
`settings-snippet.json` ao `~/.claude/settings.json`.

## Skills

Cole `skills/PROMPT-instalar.md` numa sessão, ou copie as pastas pra
`~/.claude/skills/`. Divisão de trabalho e gatilhos em `PLANO-OTIMIZACAO.md`.

As três primeiras formam o ciclo (checkpoint → audit → handoff). As outras duas
são apoio: `maestro-roteador` decide modelo/esforço quando a barra mostra `F:` em
alerta, e `fable-mindset` mede como cada modelo trabalha a partir dos mesmos JSONL
que alimentam o `d:` da barra.

## Teoria por trás

O curso **Mestre em Contexto e Tokens** (https://inematds.github.io/cctop/) é a
base deste kit: releitura de contexto, prompt caching, rotina de `/clear` e
`/compact`, handoff estruturado e subagentes. O kit é a versão ferramenta do curso.

Plugins de terceiros compatíveis com o ciclo (não incluídos): `context-mode`,
`claude-mem`, `claudex`.

## Requisitos

Claude Code com login OAuth (claude.ai), `jq`, `curl`. O script lê o token de
`~/.claude/.credentials.json` localmente; nada sai da máquina além da chamada
ao endpoint oficial de uso.

Projeto de pesquisa/educação — INEMA.
