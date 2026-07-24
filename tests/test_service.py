from __future__ import annotations

import os
import json
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx
from fastapi.testclient import TestClient

from service import app as service


class ServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.environment = patch.dict(os.environ, {"DRY_RUN": ""})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.client = TestClient(service.app)

    def test_health(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")
        self.assertEqual(response.json()["pollinations_model"], "gemini-3-flash")

    def test_control_panel_is_self_contained_and_exposes_both_modes(self) -> None:
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("text/html", response.headers["content-type"])
        self.assertIn("Fuel Recognition Lab", response.text)
        self.assertIn("Run safe dry test", response.text)
        self.assertIn("Record &amp; analyze 5s", response.text)
        self.assertIn("/analyze-drink", response.text)
        self.assertIn("?dry_run=true", response.text)
        self.assertNotIn("<script src=", response.text)
        self.assertNotIn("<link rel=", response.text)
        self.assertIn("POLL_API_KEY", response.text)

    def test_pollinations_uploads_video_and_requests_structured_gemini_analysis(self) -> None:
        requests: list[httpx.Request] = []

        def handler(request: httpx.Request) -> httpx.Response:
            requests.append(request)
            self.assertEqual(request.headers["authorization"], "Bearer poll-test-key")
            if str(request.url) == service.POLL_UPLOAD_URL:
                self.assertIn("multipart/form-data", request.headers["content-type"])
                return httpx.Response(
                    200,
                    json={"url": "https://media.pollinations.ai/fuel-test.mp4"},
                )
            self.assertEqual(str(request.url), service.POLL_CHAT_URL)
            payload = json.loads(request.content)
            self.assertEqual(payload["model"], "gemini-3-flash")
            self.assertEqual(payload["messages"][0]["content"][1]["type"], "video_url")
            return httpx.Response(
                200,
                json={
                    "choices": [{
                        "message": {
                            "content": service.MOCK_RESULT.model_dump_json()
                        }
                    }]
                },
            )

        with tempfile.TemporaryDirectory() as temp:
            clip = Path(temp) / "drink.mp4"
            clip.write_bytes(b"video")
            client = httpx.Client(
                transport=httpx.MockTransport(handler),
                headers={"Authorization": "Bearer poll-test-key"},
            )
            with patch.dict(
                os.environ,
                {"POLL_API_KEY": "poll-test-key", "POLL_MODEL": "gemini-3-flash"},
            ), patch.object(service, "_pollinations_client", return_value=client):
                result = service._analyze_video(clip)
        self.assertTrue(result.drinking_detected)
        self.assertEqual(len(requests), 2)

    def test_dry_run_never_records_or_calls_api(self) -> None:
        with patch.object(service, "_record_clip") as record, patch.object(
            service, "_analyze_video"
        ) as analyze:
            response = self.client.post("/analyze-drink?dry_run=true")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["drinking_detected"])
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

    def test_live_failure_reports_exact_stage_type_and_message(self) -> None:
        with tempfile.TemporaryDirectory() as temp, patch.object(
            service, "CAPTURE_DIR", Path(temp)
        ), patch.object(
            service, "_record_clip", side_effect=RuntimeError("camera exploded")
        ), self.assertLogs("uvicorn.error", level="ERROR") as logs:
            response = self.client.post("/analyze-drink")
        self.assertEqual(response.status_code, 500)
        self.assertEqual(
            response.json()["detail"],
            "camera recording: RuntimeError: camera exploded",
        )
        self.assertIn("Fueling failed during camera recording", "\n".join(logs.output))

    def test_environment_number_validation(self) -> None:
        with patch.dict("os.environ", {"CAPTURE_SECONDS": "999"}):
            with self.assertRaises(RuntimeError):
                service._env_float("CAPTURE_SECONDS", 5, 1, 15)


if __name__ == "__main__":
    unittest.main()
