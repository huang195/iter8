#!/usr/bin/env python3

import http.server
import socketserver
from http import HTTPStatus

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(HTTPStatus.OK)
        self.end_headers()
        self.wfile.write(b'Hello world v1\n')

httpd = socketserver.TCPServer(('0.0.0.0', 8000), Handler)
httpd.serve_forever()
