# Prompt — instalar as skills de sessão

Cole numa sessão do Claude Code:

```
Instala as três skills de sessão deste repo em ~/.claude/skills/:

  skills/session-statusline/SKILL.md  → ~/.claude/skills/session-statusline/SKILL.md
  skills/memory-audit/SKILL.md        → ~/.claude/skills/memory-audit/SKILL.md
  skills/session-handoff/SKILL.md     → ~/.claude/skills/session-handoff/SKILL.md

Só copia — não edita o conteúdo. Depois lista ~/.claude/skills/ pra confirmar
que as três apareceram. Elas passam a responder a "checkpoint / onde estamos",
"analise a memória" e "handoff / vou dar /clear", respectivamente.
```

## Como as três se dividem

| skill | quando | gatilho | saída |
|---|---|---|---|
| `session-statusline` | no meio do trabalho | "checkpoint", "onde estamos", "organiza a sessão" | foto rápida: foco, guardado × candidato, próximos passos, recomendação |
| `memory-audit` | contexto inchado | "analise a memória", "memória inchada", "o que remover" | inventário: manter / comprimir / mover / remover |
| `session-handoff` | antes do `/clear` | "handoff", "vou dar /clear", "encerrar sessão" | resumo estruturado pro próximo agente continuar |

Todas são **chat-only**: não escrevem arquivo nem memória sozinhas.
