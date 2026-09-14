# Prompt — instalar as skills

Cole numa sessão do Claude Code:

```
Instala as skills deste repo em ~/.claude/skills/:

  skills/session-statusline/SKILL.md  → ~/.claude/skills/session-statusline/SKILL.md
  skills/memory-audit/SKILL.md        → ~/.claude/skills/memory-audit/SKILL.md
  skills/session-handoff/SKILL.md     → ~/.claude/skills/session-handoff/SKILL.md
  skills/maestro-roteador/            → ~/.claude/skills/maestro-roteador/   (pasta inteira)
  skills/fable-mindset/               → ~/.claude/skills/fable-mindset/      (pasta inteira, com scripts/)

Só copia — não edita o conteúdo. Depois lista ~/.claude/skills/ pra confirmar
que as cinco apareceram. As três de sessão respondem a "checkpoint / onde estamos",
"analise a memória" e "handoff / vou dar /clear". maestro-roteador responde a "qual
modelo / quanto esforço"; fable-mindset a "analisar minhas sessões / playbook do modelo".
```

## Como as três se dividem

| skill | quando | gatilho | saída |
|---|---|---|---|
| `session-statusline` | no meio do trabalho | "checkpoint", "onde estamos", "organiza a sessão" | foto rápida: foco, guardado × candidato, próximos passos, recomendação |
| `memory-audit` | contexto inchado | "analise a memória", "memória inchada", "o que remover" | inventário: manter / comprimir / mover / remover |
| `session-handoff` | antes do `/clear` | "handoff", "vou dar /clear", "encerrar sessão" | resumo estruturado pro próximo agente continuar |

Todas são **chat-only**: não escrevem arquivo nem memória sozinhas.

## Skills de apoio

| skill | quando | gatilho | saída |
|---|---|---|---|
| `maestro-roteador` | a barra mostra `F:` com `!` ou vai despachar subagentes | "qual modelo", "quanto esforço", "triagem" | modelo + esforço por tarefa |
| `fable-mindset` | quer saber como cada modelo trabalha de verdade | "analisar minhas sessões", "playbook do modelo", "debloat jsonl" | playbook a partir dos JSONL de `~/.claude/projects` |
