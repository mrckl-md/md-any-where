#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/md-any-where-agent-transport.XXXXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

xcrun swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$temporary_dir/module-cache" \
  "$project_dir/Sources/MDAnyWhereLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/MDAnyWhereLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/MDAnyWhere/AgentService.swift" \
  "$project_dir/scripts/test-agent-transport.swift" \
  -o "$temporary_dir/agent-transport-tests"

# Only the loopback server below is contacted. No profiles, Keychain items,
# real API keys, user documents, or provider APIs are accessed.
python3 - "$temporary_dir/agent-transport-tests" <<'PY'
import http.server
import subprocess
import sys
import threading

destinations = []
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass

    def do_GET(self): self.respond()
    def do_POST(self): self.respond()

    def respond(self):
        body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        if self.path.startswith('/redirect/'):
            _, _, target, code = self.path.split('/')
            host = '127.0.0.1' if target == 'same-host' else 'localhost'
            self.send_response(int(code))
            self.send_header('Location', f'http://{host}:{self.server.server_port}/destination')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        if self.path == '/destination': destinations.append(self.path)
        status = 401 if self.path == '/error' else 200
        payload = (b'{"error":{"message":"test failure"}}' if self.path == '/error' else
                   b'A' * (4 * 1024 * 1024) if self.path == '/limit' else
                   b'A' * (4 * 1024 * 1024 + 1) if self.path == '/oversize' else body)
        self.send_response(status)
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        try: self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError): pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    result = subprocess.run([sys.argv[1], f'http://127.0.0.1:{server.server_port}'])
finally:
    server.shutdown()
    server.server_close()
if destinations:
    raise SystemExit(f'FAIL: {len(destinations)} requests reached a redirect destination')
if result.returncode:
    raise SystemExit(result.returncode)
print('PASS: destination server received zero requests (no body or authentication headers forwarded)')
PY
