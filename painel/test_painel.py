"""Testes do painel: python3 -m unittest painel/test_painel.py"""
import json
import sys
import tempfile
import threading
import time
import unittest
import urllib.request
from pathlib import Path

import importlib.util

_spec = importlib.util.spec_from_file_location("painel_kit", Path(__file__).resolve().parent / "painel.py")
painel = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(painel)


def retrato(pasta: Path, sid: str, idade: int, **extra):
    d = {"em": int(time.time()) - idade, "session_id": sid, "cwd": "/home/x/projetos/" + sid, "modelo": "Opus 5.5"}
    d.update(extra)
    (pasta / f"{sid}.json").write_text(json.dumps(d))


class TestPainel(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.p = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_estado_por_idade_e_ordem(self):
        retrato(self.p, "aaaaaaaa1", 10, ctx_pct=20)
        retrato(self.p, "bbbbbbbb2", 600)
        retrato(self.p, "cccccccc3", 3 * 3600)  # velho demais: some
        s = painel.ler_retratos(self.p)
        self.assertEqual([x["session_id"] for x in s], ["aaaaaaaa1", "bbbbbbbb2"])
        self.assertEqual([x["estado"] for x in s], ["ativa", "parada"])

    def test_lixo_nao_derruba(self):
        (self.p / "ruim.json").write_text("{nao é json")
        (self.p / "lista.json").write_text("[1,2]")
        (self.p / "grande.json").write_text("x" * (painel.LIMITE_ARQUIVO + 1))
        retrato(self.p, "aaaaaaaa1", 5)
        self.assertEqual(len(painel.ler_retratos(self.p)), 1)

    def test_pasta_inexistente(self):
        self.assertEqual(painel.ler_retratos(self.p / "nao-existe"), [])
        self.assertEqual(painel.montar([])["resumo"]["ativas"], 0)

    def test_alertas_ctx_e_cota(self):
        retrato(self.p, "aaaaaaaa1", 5, ctx_pct=72, nome="site", cota_5h=85, cota_semana=40, cota_modelo="F:81%!", custo_usd=1.25)
        retrato(self.p, "bbbbbbbb2", 50, ctx_pct=10, custo_usd=0.75)
        m = painel.montar(painel.ler_retratos(self.p))
        textos = " | ".join(a["texto"] for a in m["alertas"])
        self.assertIn("site: contexto em 72%", textos)
        self.assertIn("5 h em 85%", textos)
        self.assertIn("F:81%!", textos)
        self.assertNotIn("Cota semanal", textos)
        self.assertEqual(m["resumo"]["custo_usd"], 2.0)
        self.assertEqual(m["resumo"]["cota_5h"], 85)

    def test_publico_corta_id_e_nao_vaza_campos(self):
        retrato(self.p, "aaaaaaaa-1111-2222", 5, segredo="nao-deveria-sair")
        m = painel.montar(painel.ler_retratos(self.p))
        s = m["sessoes"][0]
        self.assertEqual(s["session_id"], "aaaaaaaa")
        self.assertNotIn("segredo", s)
        self.assertEqual(s["projeto"], "aaaaaaaa-1111-2222")

    def test_servidor_so_loopback_e_rotas(self):
        retrato(self.p, "aaaaaaaa1", 5)
        painel.Tratador.pasta = self.p
        srv = painel.ThreadingHTTPServer(("127.0.0.1", 0), painel.Tratador)
        porta = srv.server_address[1]
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        try:
            base = f"http://127.0.0.1:{porta}"
            html = urllib.request.urlopen(base + "/").read().decode()
            self.assertIn("JARVIS", html)
            j = json.loads(urllib.request.urlopen(base + "/sessoes.json").read())
            self.assertEqual(j["resumo"]["ativas"], 1)
            with self.assertRaises(urllib.error.HTTPError):
                urllib.request.urlopen(base + "/../painel.py")
        finally:
            srv.shutdown()
            srv.server_close()


if __name__ == "__main__":
    unittest.main()
