# from https://stackoverflow.com/questions/42341039/remove-cache-in-a-python-http-server

import http.server

PORT = 8085

class NoCacheHTTPRequestHandler(
    http.server.SimpleHTTPRequestHandler
):
    def send_response_only(self, code, message=None):
        super().send_response_only(code, message)
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Expires', '0')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')

if __name__ == '__main__':
    http.server.test(
        HandlerClass=NoCacheHTTPRequestHandler,
        port=PORT
    )