#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class KeepaliveHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        body = b"upstream keepalive response\n"
        self.send_response(200)
        self.send_header("X-Upstream-Client-Port", str(self.client_address[1]))
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


server = ThreadingHTTPServer(("0.0.0.0", 9021), KeepaliveHandler)
server.serve_forever()
