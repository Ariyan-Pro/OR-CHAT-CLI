#!/usr/bin/env python3
"""
Mock OpenRouter API server for integration testing.
Simulates both streaming and non-streaming responses.
"""
import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

class MockHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Read request
        content_length = int(self.headers.get('Content-Length', 0))
        request_data = self.rfile.read(content_length).decode('utf-8')
        
        try:
            request_json = json.loads(request_data)
        except:
            request_json = {}
        
        # Check for streaming
        stream = request_json.get('stream', False)
        
        if stream:
            # Streaming response
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            
            # Simulate streaming chunks
            message = "This is a mock streaming response from the test server."
            words = message.split()
            
            for i, word in enumerate(words):
                chunk = {
                    "choices": [{
                        "delta": {"content": word + (" " if i < len(words)-1 else "")}
                    }]
                }
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
                self.wfile.flush()
                time.sleep(0.05)
            
            # End of stream
            self.wfile.write(b"data: [DONE]\n\n")
            
        else:
            # Non-streaming response
            response = {
                "id": "mock-123",
                "choices": [{
                    "message": {
                        "role": "assistant",
                        "content": "This is a mock non-streaming response."
                    }
                }]
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def run_mock_server(port=8888):
    server = HTTPServer(('localhost', port), MockHandler)
    print(f"Mock server running on port {port}")
    server.serve_forever()

if __name__ == '__main__':
    run_mock_server()
