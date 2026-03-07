#!/usr/bin/env python3
"""Lightweight HTTP server that proxies requests to beet CLI commands."""

import json
import os
import subprocess
import sys
import threading
import queue
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs

BEET_CMD = os.environ.get("BEET_CMD", "/lsiopy/bin/beet")
BEET_CONFIG = os.environ.get("BEET_CONFIG", "/config/config.yaml")
PORT = int(os.environ.get("HTTPSHELL_PORT", "5555"))
BLOCKING_TIMEOUT = int(os.environ.get("HTTPSHELL_BLOCKING_TIMEOUT", "30"))
DEFAULT_MODE = "blocking"

job_queue = queue.Queue()
blocking_lock = threading.Lock()


def run_beet(command, args):
    """Execute a beet CLI command and return exit_code, stdout, stderr."""
    cmd = [BEET_CMD, "-c", BEET_CONFIG, command] + args
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=3600
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out after 3600 seconds"
    except FileNotFoundError:
        return -1, "", f"Command not found: {BEET_CMD}"


def queue_worker():
    """Background worker that processes queued jobs sequentially."""
    while True:
        command, args = job_queue.get()
        try:
            run_beet(command, args)
        except Exception as e:
            print(f"[httpshell] queued job failed: {command} {args}: {e}", file=sys.stderr)
        finally:
            job_queue.task_done()


class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path.rstrip("/") in ("", "/health"):
            self._send_json(200, {
                "status": "ok",
                "default_mode": DEFAULT_MODE,
                "queue_size": job_queue.qsize(),
            })
        else:
            self._send_json(405, {"error": "Use POST to execute commands"})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.strip("/")
        if not path:
            self._send_json(400, {"error": "No command specified. Use POST /<command>"})
            return

        # Parse mode from query parameter, default to blocking
        params = parse_qs(parsed.query)
        mode = params.get("mode", [DEFAULT_MODE])[0].lower()
        if mode not in ("async", "queued", "blocking"):
            self._send_json(400, {"error": f"Invalid mode '{mode}'. Use async, queued, or blocking"})
            return

        # First path segment is the beet subcommand
        parts = path.split("/")
        command = parts[0]

        # Parse JSON body for additional arguments
        args = []
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length > 0:
            body = self.rfile.read(content_length)
            try:
                parsed_body = json.loads(body)
                if isinstance(parsed_body, list):
                    args = [str(a) for a in parsed_body]
                else:
                    self._send_json(400, {"error": "Request body must be a JSON array of arguments"})
                    return
            except json.JSONDecodeError as e:
                self._send_json(400, {"error": f"Invalid JSON: {e}"})
                return

        # Add any extra path segments as arguments too
        if len(parts) > 1:
            args = list(parts[1:]) + args

        if mode == "queued":
            self._handle_queued(command, args)
        elif mode == "blocking":
            self._handle_blocking(command, args)
        else:
            self._handle_async(command, args)

    def _handle_async(self, command, args):
        """Run command immediately in the handler thread, return result."""
        exit_code, stdout, stderr = run_beet(command, args)
        self._send_json(200, {
            "command": command,
            "args": args,
            "exit_code": exit_code,
            "stdout": stdout,
            "stderr": stderr,
        })

    def _handle_queued(self, command, args):
        """Queue command and return 202 immediately."""
        job_queue.put((command, args))
        self._send_json(202, {
            "status": "queued",
            "command": command,
            "args": args,
            "queue_size": job_queue.qsize(),
        })

    def _handle_blocking(self, command, args):
        """Wait for lock; if acquired run command, otherwise queue it."""
        acquired = blocking_lock.acquire(timeout=BLOCKING_TIMEOUT)
        if acquired:
            try:
                exit_code, stdout, stderr = run_beet(command, args)
                self._send_json(200, {
                    "command": command,
                    "args": args,
                    "exit_code": exit_code,
                    "stdout": stdout,
                    "stderr": stderr,
                })
            finally:
                blocking_lock.release()
        else:
            job_queue.put((command, args))
            self._send_json(202, {
                "status": "queued",
                "message": f"Lock not acquired within {BLOCKING_TIMEOUT}s, job queued",
                "command": command,
                "args": args,
                "queue_size": job_queue.qsize(),
            })

    def _send_json(self, status_code, data):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[httpshell] {self.address_string()} - {fmt % args}", file=sys.stderr)


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main():
    # Always start queue worker (needed for queued and blocking-timeout fallback)
    worker = threading.Thread(target=queue_worker, daemon=True)
    worker.start()

    server = ThreadingHTTPServer(("0.0.0.0", PORT), RequestHandler)
    print(f"[httpshell] Starting server on port {PORT} (default mode: {DEFAULT_MODE})", file=sys.stderr)
    print(f"[httpshell] beet command: {BEET_CMD} -c {BEET_CONFIG}", file=sys.stderr)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        print("[httpshell] Server stopped", file=sys.stderr)


if __name__ == "__main__":
    main()
