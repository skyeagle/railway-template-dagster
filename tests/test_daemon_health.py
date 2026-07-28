import time
import unittest
from unittest.mock import patch

from dagster._daemon.types import DaemonHeartbeat

from scripts.daemon_health import daemon_status


class FakeInstance:
    def __init__(self, heartbeats: dict[str, DaemonHeartbeat]) -> None:
        self.heartbeats = heartbeats

    def __enter__(self) -> "FakeInstance":
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def get_required_daemon_types(self) -> list[str]:
        return ["QUEUED_RUN_COORDINATOR", "SCHEDULER"]

    def get_daemon_heartbeats(self) -> dict[str, DaemonHeartbeat]:
        return self.heartbeats


class DaemonHealthTest(unittest.TestCase):
    def heartbeat(self, daemon_type: str, age: int = 0) -> DaemonHeartbeat:
        return DaemonHeartbeat(
            timestamp=time.time() - age,
            daemon_type=daemon_type,
            daemon_id="test",
        )

    def test_all_required_fresh_heartbeats_are_healthy(self) -> None:
        instance = FakeInstance(
            {
                "QUEUED_RUN_COORDINATOR": self.heartbeat("QUEUED_RUN_COORDINATOR"),
                "SCHEDULER": self.heartbeat("SCHEDULER"),
            }
        )

        with patch("scripts.daemon_health.DagsterInstance.get", return_value=instance):
            healthy, body = daemon_status()

        self.assertTrue(healthy)
        self.assertEqual(body["status"], "ok")

    def test_missing_or_stale_heartbeats_are_unavailable(self) -> None:
        instance = FakeInstance(
            {
                "QUEUED_RUN_COORDINATOR": self.heartbeat(
                    "QUEUED_RUN_COORDINATOR", age=121
                )
            }
        )

        with patch("scripts.daemon_health.DagsterInstance.get", return_value=instance):
            healthy, body = daemon_status()

        self.assertFalse(healthy)
        self.assertEqual(body["missingDaemons"], ["SCHEDULER"])
        self.assertEqual(body["staleDaemons"], ["QUEUED_RUN_COORDINATOR"])


if __name__ == "__main__":
    unittest.main()
