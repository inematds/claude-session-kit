#!/bin/bash
# Statusline: user@host:cwd → projeto · ctx N% · 5h:X% · w:Y% F:Z% · d:TOK · cc:conta cx:conta
#
# 5h% e w% vêm do endpoint oficial do Claude Code:
#   GET https://api.anthropic.com/api/oauth/usage
#   header: Authorization: Bearer <accessToken de ~/.claude/.credentials.json>
#   header: anthropic-beta: oauth-2025-04-20
# Resposta:
#   { "five_hour":{"utilization":20.0,"resets_at":"..."},
#     "seven_day":{"utilization":83.0,"resets_at":"..."}, ... }
# Cache 300s em /tmp/cc_limits_<uid>.json pra não martelar a API a cada tecla
# (TTL elevado de 60s → 300s em 2026-05-13 após 429 rate_limit_error com 4
# sessões Claude simultâneas batendo na API a cada minuto).
#
# d:TOK continua sendo a contagem local (JSONL) — útil pra ver volume absoluto
# do dia; a API não retorna bucket "hoje".

set -u
input=$(cat)
# Dump do payload cru pra inspecionar campos novos (modelo/effort). Barato: 1 arquivo.
printf '%s' "$input" > "/tmp/cc_statusline_input_${UID}.json" 2>/dev/null
cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null)
transcript=$(echo "$input" | jq -r '.transcript_path // ""' 2>/dev/null)

# ── Context % (última usage do transcript / context window do modelo ativo) ─
# Opus 4.x → 1M. Sonnet/Haiku → 200k (1M se beta ativo). Detecta o modelo via
# .model.id no input do Claude Code; fallback olha a última message no transcript.
# Heurística do beta 1M: se tok já passou 200k num Sonnet/Haiku, só é possível
# se a sessão estiver com context-1m-2025-08-07, então assume 1M.
ctx=""
model_id=$(echo "$input" | jq -r '.model.id // .model.display_name // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
if [[ -n "$transcript" && -f "$transcript" ]]; then
  tok=$(tac "$transcript" 2>/dev/null | grep -m1 '"usage"' | \
        jq -r 'try ((.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)) catch 0' 2>/dev/null)
  # fallback do modelo: última message do transcript
  if [[ -z "$model_id" ]]; then
    model_id=$(tac "$transcript" 2>/dev/null | grep -m1 '"model"' | \
               jq -r 'try .message.model catch empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
  fi
  if [[ -n "$tok" && "$tok" != "0" && "$tok" != "null" ]]; then
    if [[ "$model_id" == *opus* ]]; then
      ctx_window=1000000
    elif (( tok > 200000 )); then
      ctx_window=1000000   # heurística: passou 200k → beta 1M ativo
    else
      ctx_window=200000
    fi
    pct=$(( tok * 100 / ctx_window ))
    ctx=" ctx ${pct}%"
  fi
fi

# ── 5h% + w% via API (cache 300s) ────────────────────────────────────────
# Cada pasta de login (CLAUDE_CONFIG_DIR) tem seu próprio token e seu próprio cache:
# quem alterna duas contas vê a cota da conta certa.
CC_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ "$CC_DIR" == "$HOME/.claude" ]]; then LIMITS_CACHE="/tmp/cc_limits_${UID}.json"
else LIMITS_CACHE="/tmp/cc_limits_${UID}_$(basename "$CC_DIR").json"; fi
refresh_api=1
if [[ -f "$LIMITS_CACHE" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$LIMITS_CACHE" 2>/dev/null || echo 0) ))
  [[ $age -lt 300 ]] && refresh_api=0
fi

if [[ $refresh_api -eq 1 ]]; then
  # Refetch em background pra não bloquear render
  (
    TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CC_DIR/.credentials.json" 2>/dev/null)
    if [[ -n "$TOKEN" ]]; then
      tmp=$(mktemp)
      code=$(curl -s --max-time 4 \
        -H "Authorization: Bearer $TOKEN" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -w "%{http_code}" -o "$tmp" \
        https://api.anthropic.com/api/oauth/usage 2>/dev/null)
      if [[ "$code" == "200" ]] && [[ -s "$tmp" ]]; then
        mv "$tmp" "$LIMITS_CACHE"
      else
        rm -f "$tmp"
      fi
    fi
  ) &
  disown
fi

h5_pct=""; h5_reset=""; w_pct=""; w_reset=""
if [[ -f "$LIMITS_CACHE" ]]; then
  h5_pct=$(jq -r 'try (.five_hour.utilization | round | tostring) catch empty' "$LIMITS_CACHE" 2>/dev/null)
  w_pct=$(jq -r  'try (.seven_day.utilization | round | tostring) catch empty' "$LIMITS_CACHE" 2>/dev/null)
  h5_iso=$(jq -r 'try .five_hour.resets_at catch empty' "$LIMITS_CACHE" 2>/dev/null)
  w_iso=$(jq -r  'try .seven_day.resets_at catch empty' "$LIMITS_CACHE" 2>/dev/null)
  # 5h reset: só hora local (HH:MM) — reset dentro de ≤5h
  [[ -n "$h5_iso" ]] && h5_reset=$(date -d "$h5_iso" +%H:%M 2>/dev/null)
  # weekly reset: dia/mês hora local (dd/mm HH:MM)
  [[ -n "$w_iso"  ]] && w_reset=$(date -d "$w_iso"  +"%d/%m %H:%M" 2>/dev/null)
  # Limite semanal POR MODELO (2026-09-14): a API passou a mandar .limits[] com
  # kind=weekly_scoped (ex.: Fable) além do weekly_all. O scoped é o que trava
  # de verdade quando is_active=true, e .seven_day só reflete o weekly_all.
  # Mostra como "<Inicial>:<pct>%" e acrescenta "!" se severity != normal.
  ws=$(jq -r 'try (first(.limits[]? | select(.kind=="weekly_scoped"))
       | "\(.scope.model.display_name // "M" | .[0:1]):\(.percent | tostring)%\(if .severity != "normal" then "!" else "" end)")
       catch empty' "$LIMITS_CACHE" 2>/dev/null)
fi

# ── Daily tokens (JSONL local, cache 60s) ────────────────────────────────
CACHE="/tmp/cc_usage_${UID}.txt"
refresh=1
if [[ -f "$CACHE" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
  [[ $age -lt 300 ]] && refresh=0
fi
# 20/10/2026: antes relia 8 GB de JSONL a cada 60 s com jq -s (tudo na RAM) e sem trava;
# as sessões empilharam cópias até ~74 GB e travaram a máquina. Agora: trava única,
# só arquivos de hoje, soma em streaming (sem -s), teto de tempo/memória e prioridade baixa.
if [[ $refresh -eq 1 ]]; then
  T=$(date +%Y-%m-%d)
  (
    exec 9>"/tmp/cc_usage_${UID}.lock"
    flock -n 9 || exit 0
    touch "$CACHE" 2>/dev/null
    ulimit -v 2000000
    tmp=$(mktemp)
    find "$HOME/.claude/projects" -name "*.jsonl" -newermt "$T 00:00" -print0 2>/dev/null | \
      timeout 120 nice -n 19 ionice -c3 xargs -0 cat 2>/dev/null | \
      timeout 120 nice -n 19 jq -nR --arg t "$T" -r '
        reduce (inputs | fromjson? | select(.timestamp? and (.timestamp[0:10] == $t)) | (.message.usage // {})) as $u
          (0; . + ($u.input_tokens // 0) + ($u.output_tokens // 0) + ($u.cache_creation_input_tokens // 0))
      ' > "$tmp" 2>/dev/null
    [[ -s "$tmp" ]] && mv "$tmp" "$CACHE" || rm -f "$tmp"
  ) &
  disown
fi
d=0
[[ -f "$CACHE" ]] && read -r d < "$CACHE"

fmt() {
  local n=${1:-0}
  if (( n >= 1000000 )); then awk -v x="$n" 'BEGIN{printf "%.1fM", x/1000000}'
  elif (( n >= 1000 )); then awk -v x="$n" 'BEGIN{printf "%.0fk", x/1000}'
  else echo "$n"
  fi
}

# ── Modelo + esforço ──────────────────────────────────────────────────────
# Preferência: payload da statusline (reflete o /model da sessão). Fallback:
# settings.json (model + effortLevel), que é o default quando a sessão não
# sobrescreveu nada.
model_name=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)
effort=$(echo "$input" | jq -r '
  [.effort.level?, .model.effort?, .model.effortLevel?, .effortLevel?, .reasoning_effort?]
  | map(select(. != null and . != "")) | first // empty' 2>/dev/null)
if [[ -z "$model_name" || -z "$effort" ]]; then
  s="$HOME/.claude/settings.json"
  [[ -z "$model_name" ]] && model_name=$(jq -r '.model // empty' "$s" 2>/dev/null)
  [[ -z "$effort"     ]] && effort=$(jq -r '.effortLevel // empty' "$s" 2>/dev/null)
fi
me=""
[[ -n "$model_name" ]] && me=" ${model_name}"
[[ -n "$effort"     ]] && me+="/${effort}"

# Monta trinca de limits. Se API ainda não populou cache, omite graciosamente.
limits=""
if [[ -n "$h5_pct" ]]; then
  limits+=" 5h:${h5_pct}%"
  [[ -n "$h5_reset" ]] && limits+="→${h5_reset}"
fi
if [[ -n "$w_pct" ]]; then
  limits+=" w:${w_pct}%"
  [[ -n "${ws:-}" ]] && limits+=" ${ws}"
  [[ -n "$w_reset" ]] && limits+="→${w_reset}"
fi
limits+=" d:$(fmt "$d")"

# ── Projeto ativo: "→ X" em amarelo ──────────────────────────────────────
# A sessão fica presa na pasta onde abriu; quando o trabalho vai para outro
# projeto dentro de $STATUSLINE_PROJETOS (padrão ~/projetos), mostra "→ X".
# Fonte: últimos 50 tool_use do transcript; vale o mais recente que é pasta
# e não é o projeto da própria sessão.
PROJ_ROOT="${STATUSLINE_PROJETOS:-$HOME/projetos}"; PROJ_ROOT=${PROJ_ROOT%/}
proj_base=$(basename "$PROJ_ROOT")
sessao=""
[[ "$cwd" == "$PROJ_ROOT/"* ]] && { sessao=${cwd#"$PROJ_ROOT/"}; sessao=${sessao%%/*}; }
ativo=""
if [[ -n "$transcript" && -f "$transcript" && -d "$PROJ_ROOT" ]]; then
  while read -r p; do
    p=${p#*"$proj_base"/}
    [[ -n "$p" && "$p" != "$sessao" && -d "$PROJ_ROOT/$p" ]] && { ativo=$p; break; }
  done < <(tac "$transcript" 2>/dev/null | grep -m50 '"tool_use"' | \
           grep -oE "(${PROJ_ROOT}|~${PROJ_ROOT#"$HOME"})/[A-Za-z0-9._-]+")
fi
proj=""
[[ -n "$ativo" ]] && proj=" → ${ativo}"

# ── Contas em uso: cc = Claude desta sessão, cx = Codex (se instalado) ───
# Mostra só o começo do e-mail. Cache 300 s; nenhum token sai daqui.
# STATUSLINE_CONTAS=0 desliga.
contas=""
if [[ "${STATUSLINE_CONTAS:-1}" != "0" ]]; then
  CX_DIR="${CODEX_HOME:-$HOME/.codex}"
  CONTAS_CACHE="/tmp/cc_contas_${UID}_$(basename "$CC_DIR")_$(basename "$CX_DIR").txt"
  if [[ ! -f "$CONTAS_CACHE" || $(( $(date +%s) - $(stat -c %Y "$CONTAS_CACHE" 2>/dev/null || echo 0) )) -ge 300 ]]; then
    if [[ "$CC_DIR" == "$HOME/.claude" ]]; then cj="$HOME/.claude.json"; else cj="$CC_DIR/.claude.json"; fi
    cc_mail=$(jq -r '.oauthAccount.emailAddress // empty' "$cj" 2>/dev/null)
    cx_mail=""
    if [[ -f "$CX_DIR/auth.json" ]] && command -v python3 >/dev/null; then
      cx_mail=$(python3 -I -c 'import json,base64,sys
try:
  p=json.load(open(sys.argv[1]))["tokens"]["id_token"].split(".")[1]; p+="="*(-len(p)%4)
  print(json.loads(base64.urlsafe_b64decode(p)).get("email",""))
except Exception: pass' "$CX_DIR/auth.json" 2>/dev/null)
    fi
    out=""
    [[ -n "$cc_mail" ]] && out+=" cc:${cc_mail%%@*}"
    [[ -n "$cx_mail" ]] && out+=" cx:${cx_mail%%@*}"
    printf '%s' "$out" > "$CONTAS_CACHE" 2>/dev/null
  fi
  contas=$(cat "$CONTAS_CACHE" 2>/dev/null)
fi

# ── Retrato da sessão para o painel (opcional) ───────────────────────────
# STATUSLINE_RETRATO=1 grava um JSON pequeno por sessão em
# ${STATUSLINE_RETRATO_DIR:-~/.local/share/claude-session-kit/sessoes}/<session_id>.json,
# que o painel/ do kit lê. Desligado por padrão. Nenhum token vai para o arquivo.
if [[ "${STATUSLINE_RETRATO:-0}" == "1" ]]; then
  sid=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
  if [[ "$sid" =~ ^[A-Za-z0-9-]{8,64}$ ]]; then
    rdir="${STATUSLINE_RETRATO_DIR:-$HOME/.local/share/claude-session-kit/sessoes}"
    mkdir -p "$rdir" 2>/dev/null
    echo "$input" | jq -c --arg em "$(date +%s)" --arg ativo "$ativo" --arg contas "${contas# }" \
      --arg h5 "${h5_pct:-}" --arg h5r "${h5_reset:-}" --arg w "${w_pct:-}" --arg wr "${w_reset:-}" --arg ws "${ws:-}" --arg d "${d:-0}" \
      '{em:($em|tonumber), session_id, nome:(.session_name // null), cwd,
        ativo:(if $ativo=="" then null else $ativo end), contas:(if $contas=="" then null else $contas end),
        modelo:.model.display_name, modelo_id:.model.id, esforco:(.effort.level // null),
        ctx_pct:(.context_window.used_percentage // null), custo_usd:(.cost.total_cost_usd // null),
        dur_ms:(.cost.total_duration_ms // null), linhas_mais:(.cost.total_lines_added // null), linhas_menos:(.cost.total_lines_removed // null),
        cota_5h:(if $h5=="" then null else ($h5|tonumber? // null) end), cota_5h_reset:(if $h5r=="" then null else $h5r end),
        cota_semana:(if $w=="" then null else ($w|tonumber? // null) end), cota_semana_reset:(if $wr=="" then null else $wr end),
        cota_modelo:(if $ws=="" then null else $ws end), tokens_dia:($d|tonumber? // 0), versao:(.version // null)}' \
      > "$rdir/.$sid.tmp" 2>/dev/null && mv -f "$rdir/.$sid.tmp" "$rdir/$sid.json" 2>/dev/null
  fi
fi

printf "\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m\033[01;33m%s\033[00m\033[38;5;180m%s\033[00m%s\033[38;5;244m%s\033[00m\033[38;5;117m%s\033[00m" \
  "$(whoami)" "$(hostname -s)" "$cwd" "$proj" "$me" "$ctx" "$limits" "$contas"
