# FALHAS — claude-session-kit

| data | o que quebrou | menor correção | prompt \| infra |
|---|---|---|---|
| 2026-11-20 | barra mostrava `M:null%!` quando a API não mandava `weekly_scoped` | `first(.limits[]? \| select(...))` em vez de `[...] \| first` (lista vazia vira nada, não null) | prompt |
