#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class KeepaliveObserver(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        return

    def do_GET(self):
        body = f"client_port={self.client_address[1]}\n".encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 9051), KeepaliveObserver)
    print("keepalive observer listening on 127.0.0.1:9051", flush=True)
    server.serve_forever()
