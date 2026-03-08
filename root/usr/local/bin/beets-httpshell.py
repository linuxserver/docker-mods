#!/usr/bin/env python3
"""Lightweight HTTP server that proxies requests to beet CLI commands."""

import json
import logging
import os
import shlex
import subprocess
import sys
import threading
import queue
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from typing import NamedTuple
from urllib.parse import urlparse, parse_qs

logger = logging.getLogger("httpshell")

BEET_CMD = os.environ.get("BEET_CMD", "/lsiopy/bin/beet")
BEET_CONFIG = os.environ.get("BEET_CONFIG", "/config/config.yaml")
PORT = int(os.environ.get("HTTPSHELL_PORT", "5555"))
BLOCKING_TIMEOUT = int(os.environ.get("HTTPSHELL_BLOCKING_TIMEOUT", "30"))
DEFAULT_MODE = "parallel"
VALID_MODES = {"parallel", "queue", "block"}

job_queue: queue.Queue[tuple[str, list[str]]] = queue.Queue()
blocking_lock = threading.Lock()


class CommandResult(NamedTuple):
    exit_code: int
    stdout: str
    stderr: str


def _read_stream(stream, lines: list[str], label: str) -> None:
    for line in stream:
        lines.append(line)
        logger.info("[%s] %s", label, line.rstrip())


def run_beet(command: str, args: list[str]) -> CommandResult:
    """Execute a beet CLI command, stream output, and return the result."""
    cmd = [BEET_CMD, "-c", BEET_CONFIG, command]
    cmd.extend(args)

    logger.info("> %s", shlex.join(cmd))

    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
    except FileNotFoundError:
        return CommandResult(-1, "", f"Command not found: {BEET_CMD}")

    stdout_lines: list[str] = []
    stderr_lines: list[str] = []

    stderr_thread = threading.Thread(
        target=_read_stream, args=(proc.stderr, stderr_lines, command), daemon=True
    )
    stderr_thread.start()
    _read_stream(proc.stdout, stdout_lines, command)
    stderr_thread.join(timeout=5)

    try:
        proc.wait(timeout=3600)
    except subprocess.TimeoutExpired:
        proc.kill()
        return CommandResult(-1, "", "Command timed out after 3600 seconds")

    logger.info("[%s] exited with code %d", command, proc.returncode)
    return CommandResult(proc.returncode, "".join(stdout_lines), "".join(stderr_lines))


def queue_worker() -> None:
    """Background worker that processes queued jobs sequentially."""
    while True:
        command, args = job_queue.get()
        try:
            run_beet(command, args)
        except Exception:
            logger.exception("queued job failed: %s %s", command, args)
        finally:
            job_queue.task_done()


class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path.rstrip("/") in ("", "/health"):
            self._send_json(200, {
                "status": "ok",
                "default_mode": DEFAULT_MODE,
                "queue_size": job_queue.qsize(),
            })
        else:
            self._send_json(405, {"error": "Use POST to execute commands"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.strip("/")
        if not path:
            self._send_json(400, {"error": "No command specified. Use POST /<command>"})
            return

        params = parse_qs(parsed.query)
        mode = params.get("mode", [DEFAULT_MODE])[0].lower()
        if mode not in VALID_MODES:
            self._send_json(400, {"error": f"Invalid mode '{mode}'. Use parallel, queue, or block"})
            return

        parts = path.split("/")
        command = parts[0]
        args = list(parts[1:])

        body_args = self._parse_body_args()
        if body_args is None:
            return
        args.extend(body_args)

        {"parallel": self._handle_parallel, "queue": self._handle_queued,
         "block": self._handle_blocking}[mode](command, args)

    def _parse_body_args(self) -> list[str] | None:
        """Parse JSON body for arguments. Returns None on invalid input (error already sent)."""
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            return []

        body = self.rfile.read(content_length)
        try:
            parsed_body = json.loads(body)
        except json.JSONDecodeError as e:
            self._send_json(400, {"error": f"Invalid JSON: {e}"})
            return None

        if not isinstance(parsed_body, list):
            self._send_json(400, {"error": "Request body must be a JSON array of arguments"})
            return None

        return [str(a) for a in parsed_body]

    def _handle_parallel(self, command: str, args: list[str]) -> None:
        result = run_beet(command, args)
        self._send_result(command, args, result)

    def _handle_queued(self, command: str, args: list[str]) -> None:
        job_queue.put((command, args))
        self._send_json(202, {
            "status": "queued",
            "command": command,
            "args": args,
            "queue_size": job_queue.qsize(),
        })

    def _handle_blocking(self, command: str, args: list[str]) -> None:
        if blocking_lock.acquire(timeout=BLOCKING_TIMEOUT):
            try:
                result = run_beet(command, args)
                self._send_result(command, args, result)
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

    def _send_result(self, command: str, args: list[str], result: CommandResult) -> None:
        self._send_json(200, {
            "command": command,
            "args": args,
            "exit_code": result.exit_code,
            "stdout": result.stdout,
            "stderr": result.stderr,
        })

    def _send_json(self, status_code: int, data: dict) -> None:
        body = json.dumps(data).encode()
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:
        logger.info("%s - %s", self.address_string(), fmt % args)


def main() -> None:
    logging.basicConfig(
        format="[httpshell] %(message)s",
        level=logging.INFO,
        stream=sys.stderr,
    )

    threading.Thread(target=queue_worker, daemon=True).start()

    server = ThreadingHTTPServer(("0.0.0.0", PORT), RequestHandler)
    logger.info("Starting server on port %d (default mode: %s)", PORT, DEFAULT_MODE)
    logger.info("beet command: %s -c %s", BEET_CMD, BEET_CONFIG)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        logger.info("Server stopped")


if __name__ == "__main__":
    main()
