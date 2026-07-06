#!/usr/bin/env python3

import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def handler_for(backend_name):
    class BackendHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.endswith("/slow"):
                time.sleep(2)

            body = f"backend {backend_name}\n".encode()
            self.send_response(200)
            self.send_header("X-Backend", backend_name)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            return

    return BackendHandler


def serve(port, backend_name):
    server = ThreadingHTTPServer(("0.0.0.0", port), handler_for(backend_name))
    server.serve_forever()


threading.Thread(target=serve, args=(9011, "A"), daemon=True).start()
serve(9012, "B")
