#!/usr/bin/env python3

import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class StreamingHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")

        if self.path == "/stream-no-buffer":
            self.send_header("X-Accel-Buffering", "no")

        self.end_headers()

        for number in range(1, 5):
            self.wfile.write(f"data: event-{number}\n\n".encode())
            self.wfile.flush()
            time.sleep(0.5)

        self.close_connection = True

    def log_message(self, format, *args):
        return


server = ThreadingHTTPServer(("0.0.0.0", 9003), StreamingHandler)
server.serve_forever()
