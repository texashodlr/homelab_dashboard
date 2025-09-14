from http.server import SimpleHTTPRequestHandler, HTTPServer

PORT=8000

handler = SimpleHTTPRequestHandler
with HTTPServer(('192.168.1.210', PORT), handler) as httpd:
    print(f"Serving on port {PORT}")
    httpd.serve_forever()
