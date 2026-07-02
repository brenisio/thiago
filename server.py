#!/usr/bin/env python3
"""Servidor local do Board Nulla (equivalente ao server.ps1, pra Mac/Linux e testes).
Serve o index.html e salva/le o estado em banco.json na mesma pasta.
Uso:  python3 server.py    ->    abre http://localhost:8791/index.html
"""
import http.server, socketserver, os, sys, webbrowser, threading

PORT = 8791
ROOT = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(ROOT, "banco.json")

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def log_message(self, *a):  # silencioso
        pass

    def do_GET(self):
        if self.path == "/api/state":
            data = b"{}"
            if os.path.exists(STATE):
                with open(STATE, "rb") as f:
                    data = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        return super().do_GET()

    def do_POST(self):
        if self.path == "/api/state":
            n = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(n)
            with open(STATE, "wb") as f:
                f.write(body)
            self.send_response(204)
            self.end_headers()
            return
        self.send_response(404)
        self.end_headers()

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    url = f"http://localhost:{PORT}/index.html"
    if "--no-browser" not in sys.argv:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    with Server(("127.0.0.1", PORT), Handler) as httpd:
        print(f"Board Nulla rodando em {url}  (Ctrl+C para encerrar)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
