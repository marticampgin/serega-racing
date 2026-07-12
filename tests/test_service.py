from __future__ import annotations

import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient

from service import app as service


class ServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(service.app)

    def test_health(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_dry_run_never_records_or_calls_api(self) -> None:
        with patch.object(service, "_record_clip") as record, patch.object(
            service, "_analyze_video"
        ) as analyze:
            response = self.client.post("/analyze-drink?dry_run=true")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["selected_color"], "blue")
        record.assert_not_called()
        analyze.assert_not_called()

    def test_busy_request_is_rate_limited(self) -> None:
        self.assertTrue(service._analysis_guard.acquire(blocking=False))
        try:
            response = self.client.post("/analyze-drink?dry_run=true")
        finally:
            service._analysis_guard.release()
        self.assertEqual(response.status_code, 429)

    def test_capture_is_removed_after_analysis(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            capture_dir = Path(temp)

            def fake_record(path: Path, seconds: float, camera: int) -> None:
                path.write_bytes(b"video")

            with patch.object(service, "CAPTURE_DIR", capture_dir), patch.object(
                service, "_record_clip", side_effect=fake_record
            ), patch.object(service, "_analyze_video", return_value=service.MOCK_RESULT):
                response = self.client.post("/analyze-drink")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(list(capture_dir.iterdir()), [])

    def test_timeout_maps_to_gateway_timeout(self) -> None:
        with tempfile.TemporaryDirectory() as temp, patch.object(
            service, "CAPTURE_DIR", Path(temp)
        ), patch.object(service, "_record_clip"), patch.object(
            service, "_analyze_video", side_effect=TimeoutError("timed out")
        ):
            response = self.client.post("/analyze-drink")
        self.assertEqual(response.status_code, 504)

    def test_environment_number_validation(self) -> None:
        with patch.dict("os.environ", {"CAPTURE_SECONDS": "999"}):
            with self.assertRaises(RuntimeError):
                service._env_float("CAPTURE_SECONDS", 5, 1, 15)


if __name__ == "__main__":
    unittest.main()
