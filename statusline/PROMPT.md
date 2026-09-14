# Prompt — configurar a statusline do Claude Code

Cole o texto abaixo numa sessão do Claude Code (qualquer projeto). Ele instala o
script `statusline-command.sh` deste repo e aponta o `settings.json` pra ele.

---

```
Configura a statusline do Claude Code pra mim, do jeito abaixo. Não invente
outro formato — use exatamente o script que eu vou indicar.

1. Copia o arquivo `statusline/statusline-command.sh` deste repo pra
   `~/.claude/statusline-command.sh` e dá `chmod +x`.

2. Em `~/.claude/settings.json`, garante que existe:
     "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
   (mescla com o que já existe; não apaga outras chaves).

3. Confirma que `jq` e `curl` estão instalados (o script depende dos dois).

4. Testa rodando o script com o payload de exemplo:
     echo '{"cwd":"'$PWD'","model":{"display_name":"Fable 5.1"}}' | bash ~/.claude/statusline-command.sh
   e me mostra a linha renderizada (sem os códigos ANSI).

O que a linha mostra, nesta ordem:
  user@host:cwd  Modelo/esforço  ctx N%  5h:X%→HH:MM  w:Y% F:Z%!→dd/mm HH:MM  d:TOK

  - ctx N%   = % da janela de contexto usada (lê a última "usage" do transcript JSONL).
  - 5h:X%    = cota de 5 horas, com hora local do reset.
  - w:Y%     = cota semanal geral (weekly_all).
  - F:Z%     = cota semanal POR MODELO (weekly_scoped, ex.: Fable). Ganha "!" quando
               a API marca severity != normal. É esse que trava de verdade.
  - d:TOK    = tokens do dia, contados localmente nos JSONL.

De onde vem a cota: GET https://api.anthropic.com/api/oauth/usage com o
accessToken de ~/.claude/.credentials.json e header `anthropic-beta: oauth-2025-04-20`.
Cache de 300 s em /tmp/cc_limits_<uid>.json (não martelar a API a cada tecla —
com 4 sessões abertas e TTL de 60 s deu 429). O refetch roda em background pra
não travar o render.

Não mexa no formato, não adicione emoji, não troque cores. Se a API retornar
campos novos, me avisa em vez de adivinhar.
```

---

## Notas

- O bloco `limits[]` da API (visto em 2026-09-14) traz `weekly_all` e
  `weekly_scoped`; `.seven_day.utilization` reflete só o `weekly_all`. Por isso o
  script lê os dois. Detalhe em `statusline-command.sh`, seção "Limite semanal
  POR MODELO".
- Payload cru que o Claude Code manda pra statusline fica em
  `/tmp/cc_statusline_input_<uid>.json` — útil pra descobrir campos novos
  (modelo, esforço).
- Pra ver a linha se atualizar não precisa reiniciar: ela re-renderiza a cada
  mensagem.
