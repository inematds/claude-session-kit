# Plano de otimização de sessão (Claude Code)

Objetivo: gastar menos contexto e menos cota, e nunca perder o fio ao dar `/clear`.
As três skills deste repo formam um ciclo; a statusline é o sensor que diz
quando disparar cada uma.

## O ciclo

```
  trabalhar ──► ctx sobe ──► [checkpoint] ──► continuar
                                 │
                 ctx > 60% ou "ruidoso" ──► [memory-audit] ──► compactar / apagar
                                 │
                 vai dar /clear ─────────► [session-handoff] ──► /clear ──► colar handoff
```

## Gatilhos, lidos da statusline

| leitura na barra | ação |
|---|---|
| `ctx` até 40% | seguir; nada a fazer |
| `ctx` 40–60% | `checkpoint` (session-statusline) — decidir se compacta |
| `ctx` > 60% ou saída ficando repetitiva | `analise a memória` (memory-audit) → aplicar o "plano de enxugamento" → `/compact` |
| `ctx` > 80% | `handoff` (session-handoff) → `/clear` → colar o handoff na sessão nova |
| `5h:` > 80% | parar tarefas pesadas; usar `5h→HH:MM` pra planejar o retorno |
| `F:` (semanal por modelo) com `!` | `maestro-roteador` decide o que vai pra modelo mais barato (`/model` ou subagente); o resto espera o reset `→dd/mm HH:MM` |
| `w:` > 90% | só o essencial até o reset |

## Regras de higiene por sessão

1. **Uma sessão, um assunto.** Assunto novo → `handoff` + `/clear`. Misturar é o que incha o contexto.
2. **Checkpoint a cada bloco de trabalho** (uns 30–45 min ou ao fechar uma etapa). Custa pouco e evita a auditoria grande.
3. **Memória durável só do que muda comportamento futuro.** O memory-audit separa: durável / curta / handoff / ruído. Só o durável vai pra `~/.claude/projects/<proj>/memory/` ou pro `CLAUDE.md`.
4. **Handoff é chat-only e vai pro próximo agente, não pra você.** Caminhos absolutos, IDs de processos em background, comando de verificação. Sem retro.
5. **Subagentes pra leitura pesada.** Logs, diffs grandes, exploração ampla → Agent/Explore, e só a conclusão volta pro contexto principal.
6. **Não adivinhar cota dentro da conversa.** O modelo não vê cota; quem vê é a statusline (script deste repo). As skills têm regra explícita de não inventar esses números.

## O que medir pra saber se está funcionando

- Sessões que terminam com `/clear` **sem** handoff → meta: zero.
- `ctx` médio no momento do `/clear` → meta: abaixo de 80%.
- Quantas vezes por semana a `F:` ganha `!` → se for sempre, o problema é volume, não organização.

## Medir de verdade

`fable-mindset` lê os mesmos JSONL que a barra usa pro `d:` e mostra, por modelo, quantas
chamadas de ferramenta, quanto contexto por turno e onde o trabalho travou. Rodar uma vez
por semana responde "o problema é volume ou organização?" com número, não com impressão.

## Base teórica

Curso **Mestre em Contexto e Tokens**: https://inematds.github.io/cctop/ — trilhas T2 (rotina
de `/clear` e `/compact`), T3 (handoff) e T4 (subagentes) são o que este plano operacionaliza.

## Pendências / ideias

- Hook `PreCompact` que roda a session-statusline automaticamente antes do `/compact`.
- Statusline colorir `ctx` (verde/âmbar/vermelho) nos cortes 40/60/80.
- Skill única "session-audit" que encadeia checkpoint → memory-audit → handoff numa chamada só, pra quem não quer lembrar de três nomes.
