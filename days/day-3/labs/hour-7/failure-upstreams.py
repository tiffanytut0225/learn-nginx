#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading
import time

payments = {"A": 0, "B": 0}


class FailureHandler(BaseHTTPRequestHandler):
    backend_name = "?"

    def log_message(self, format, *args):
        return

    def _send_text(self, status, body, headers=None):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("X-Backend", self.backend_name)
        if headers:
            for key, value in headers.items():
                self.send_header(key, value)
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        if self.path.startswith("/ok"):
            self._send_text(200, f"ok from {self.backend_name}\n")
            return

        if self.path.startswith("/error"):
            self._send_text(500, f"error from {self.backend_name}\n")
            return

        if self.path.startswith("/slow"):
            time.sleep(2)
            self._send_text(200, f"slow response from {self.backend_name}\n")
            return

        if self.path.startswith("/stats"):
            self._send_text(200, f"backend={self.backend_name} payments={payments[self.backend_name]}\n")
            return

        self._send_text(404, "not found\n")

    def do_POST(self):
        if self.path.startswith("/payments"):
            payments[self.backend_name] += 1
            if self.backend_name == "A":
                time.sleep(2)
            self._send_text(200, f"payment accepted by {self.backend_name}\n")
            return

        self._send_text(404, "not found\n")


def make_handler(name):
    return type(f"Backend{name}Handler", (FailureHandler,), {"backend_name": name})


def serve(port, name):
    server = ThreadingHTTPServer(("127.0.0.1", port), make_handler(name))
    print(f"backend {name} listening on 127.0.0.1:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    threads = [
        threading.Thread(target=serve, args=(9031, "A"), daemon=True),
        threading.Thread(target=serve, args=(9032, "B"), daemon=True),
    ]

    for thread in threads:
        thread.start()

    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        print("stopping failure upstreams", flush=True)
