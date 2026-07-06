#!/usr/bin/env python3

import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class ControlledHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/read-timeout":
            time.sleep(2)

        body = b"healthy upstream response\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


def run_http_server():
    server = ThreadingHTTPServer(("0.0.0.0", 9001), ControlledHandler)
    server.serve_forever()


def hold_without_reading(connection):
    try:
        time.sleep(10)
    finally:
        connection.close()


def run_no_read_server():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("0.0.0.0", 9002))
        server.listen(16)

        while True:
            connection, _ = server.accept()
            thread = threading.Thread(
                target=hold_without_reading,
                args=(connection,),
                daemon=True,
            )
            thread.start()


threading.Thread(target=run_http_server, daemon=True).start()
run_no_read_server()
