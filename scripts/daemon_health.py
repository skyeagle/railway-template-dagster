#!/usr/bin/env python3
import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from dagster import DagsterInstance

MAX_HEARTBEAT_AGE_SECONDS = 120


def daemon_status() -> tuple[bool, dict[str, object]]:
    with DagsterInstance.get() as instance:
        required = set(instance.get_required_daemon_types())
        heartbeats = instance.get_daemon_heartbeats()

    now = time.time()
    missing = sorted(required - heartbeats.keys())
    stale = sorted(
        daemon_type
        for daemon_type in required & heartbeats.keys()
        if now - heartbeats[daemon_type].timestamp > MAX_HEARTBEAT_AGE_SECONDS
    )
    errored = sorted(
        daemon_type
        for daemon_type in required & heartbeats.keys()
        if heartbeats[daemon_type].errors
    )
    healthy = not missing and not stale and not errored

    return healthy, {
        "status": "ok" if healthy else "unavailable",
        "requiredDaemons": sorted(required),
        "missingDaemons": missing,
        "staleDaemons": stale,
        "erroredDaemons": errored,
    }


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path != "/health":
            self.send_error(404)
            return

        try:
            healthy, body = daemon_status()
        except Exception as error:
            healthy = False
            body = {"status": "unavailable", "error": type(error).__name__}

        payload = json.dumps(body, separators=(",", ":")).encode()
        self.send_response(200 if healthy else 503)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args: object) -> None:
        return


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "3001"))
    ThreadingHTTPServer(("0.0.0.0", port), HealthHandler).serve_forever()
