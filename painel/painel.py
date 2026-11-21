#!/usr/bin/env python3
"""Painel das sessões do Claude Code no visual Jarvis.

Lê os retratos que a statusline grava (STATUSLINE_RETRATO=1) e serve uma página
só no 127.0.0.1. Só lê: nada é executado e nenhum token passa por aqui.

    python3 painel/painel.py                 # http://127.0.0.1:8781
    python3 painel/painel.py --porta 9000
    python3 painel/painel.py --exportar sessoes.json   # grava o JSON e sai

Sem dependências além do Python 3.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

AQUI = Path(__file__).resolve().parent
PADRAO_DIR = Path.home() / ".local/share/claude-session-kit/sessoes"
ATIVA_S = 180          # retrato atualizado há menos de 3 min = sessão ativa
PARADA_S = 2 * 3600    # até 2 h = parada; mais velho que isso some da tela
LIMITE_ARQUIVO = 64 * 1024


def ler_retratos(pasta: Path, agora: float | None = None, max_idade: int = PARADA_S) -> list[dict]:
    """Lê os <session_id>.json da pasta, descarta lixo e o que é velho demais."""
    agora = time.time() if agora is None else agora
    saida = []
    if not pasta.is_dir():
        return saida
    for arq in pasta.glob("*.json"):
        try:
            if arq.stat().st_size > LIMITE_ARQUIVO:
                continue
            d = json.loads(arq.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if not isinstance(d, dict) or not isinstance(d.get("em"), (int, float)):
            continue
        idade = agora - d["em"]
        if idade > max_idade:
            continue
        d["idade_s"] = max(0, int(idade))
        d["estado"] = "ativa" if idade <= ATIVA_S else "parada"
        saida.append(d)
    saida.sort(key=lambda d: d["em"], reverse=True)
    return saida


def _num(v):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def montar(sessoes: list[dict]) -> dict:
    """Resumo da tela: cotas vêm do retrato mais recente (são da conta, não da sessão)."""
    recente = sessoes[0] if sessoes else {}
    custo = sum(_num(s.get("custo_usd")) or 0 for s in sessoes)
    ctx_alto = [s for s in sessoes if (_num(s.get("ctx_pct")) or 0) >= 60]
    alertas = []
    for s in ctx_alto:
        nome = s.get("nome") or projeto(s)
        alertas.append({"tipo": "ctx", "texto": f"{nome}: contexto em {s['ctx_pct']}% — hora de /compact ou handoff"})
    if (_num(recente.get("cota_5h")) or 0) >= 80:
        alertas.append({"tipo": "cota", "texto": f"Cota de 5 h em {recente['cota_5h']}% (reset {recente.get('cota_5h_reset') or '?'})"})
    if (_num(recente.get("cota_semana")) or 0) >= 80:
        alertas.append({"tipo": "cota", "texto": f"Cota semanal em {recente['cota_semana']}%"})
    if isinstance(recente.get("cota_modelo"), str) and recente["cota_modelo"].endswith("!"):
        alertas.append({"tipo": "cota", "texto": f"Cota do modelo em alerta: {recente['cota_modelo']}"})
    return {
        "gerado_em": int(time.time()),
        "resumo": {
            "ativas": sum(1 for s in sessoes if s["estado"] == "ativa"),
            "paradas": sum(1 for s in sessoes if s["estado"] == "parada"),
            "custo_usd": round(custo, 2),
            "tokens_dia": _num(recente.get("tokens_dia")),
            "cota_5h": _num(recente.get("cota_5h")),
            "cota_5h_reset": recente.get("cota_5h_reset"),
            "cota_semana": _num(recente.get("cota_semana")),
            "cota_semana_reset": recente.get("cota_semana_reset"),
            "cota_modelo": recente.get("cota_modelo"),
        },
        "alertas": alertas,
        "sessoes": [publico(s) for s in sessoes],
    }


def projeto(s: dict) -> str:
    cwd = s.get("cwd") or ""
    return os.path.basename(cwd.rstrip("/")) or cwd or "?"


CAMPOS = ("session_id", "nome", "cwd", "ativo", "contas", "modelo", "esforco", "ctx_pct", "custo_usd",
          "dur_ms", "linhas_mais", "linhas_menos", "estado", "idade_s")


def publico(s: dict) -> dict:
    d = {k: s.get(k) for k in CAMPOS}
    d["session_id"] = (d["session_id"] or "")[:8]
    d["projeto"] = projeto(s)
    return d


class Tratador(BaseHTTPRequestHandler):
    pasta: Path = PADRAO_DIR

    def _enviar(self, corpo: bytes, tipo: str, codigo: int = 200):
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):  # noqa: N802
        rota = self.path.split("?", 1)[0]
        if rota in ("/", "/index.html"):
            self._enviar((AQUI / "index.html").read_bytes(), "text/html; charset=utf-8")
        elif rota == "/sessoes.json":
            corpo = json.dumps(montar(ler_retratos(self.pasta)), ensure_ascii=False).encode()
            self._enviar(corpo, "application/json; charset=utf-8")
        else:
            self._enviar(b"nao encontrado", "text/plain; charset=utf-8", 404)

    def log_message(self, *_):
        pass


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Painel Jarvis das sessões do Claude Code (só lê).")
    ap.add_argument("--porta", type=int, default=int(os.environ.get("PAINEL_PORTA", 8781)))
    ap.add_argument("--pasta", type=Path,
                    default=Path(os.environ.get("STATUSLINE_RETRATO_DIR", PADRAO_DIR)).expanduser())
    ap.add_argument("--exportar", type=Path, help="grava o JSON da tela neste arquivo e sai")
    a = ap.parse_args(argv)
    if a.exportar:
        a.exportar.write_text(json.dumps(montar(ler_retratos(a.pasta)), ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"gravado: {a.exportar}")
        return 0
    if not a.pasta.is_dir():
        print(f"aviso: {a.pasta} ainda não existe — ligue STATUSLINE_RETRATO=1 na statusline", file=sys.stderr)
    Tratador.pasta = a.pasta
    srv = ThreadingHTTPServer(("127.0.0.1", a.porta), Tratador)
    print(f"painel: http://127.0.0.1:{a.porta}  (lendo {a.pasta}; Ctrl+C para sair)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
