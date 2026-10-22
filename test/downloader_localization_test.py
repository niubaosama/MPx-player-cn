import importlib.util
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import URLError


SOURCE = Path(__file__).resolve().parents[1] / "android/app/src/main/python/downloader_bridge.py"
SPEC = importlib.util.spec_from_file_location("downloader_bridge", SOURCE)
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class DownloaderLocalizationTest(unittest.TestCase):
    def test_known_errors_use_selected_language(self):
        error = URLError("offline")
        chinese = bridge._friendly_error_message("https://example.com", error, "zh")
        self.assertIn("网络错误", chinese)
        self.assertIn("Network error", bridge._friendly_error_message("https://example.com", error))
        self.assertIn(
            "Cookie",
            bridge._friendly_error_message("https://instagram.com/video", RuntimeError("login required"), "zh"),
        )
        self.assertIn(
            "暂不支持",
            bridge._friendly_error_message("https://example.com", RuntimeError("unsupported URL"), "zh"),
        )

    def test_unknown_diagnostic_is_preserved(self):
        detail = "ffmpeg: cannot open My Video.mp4"
        self.assertEqual(bridge._friendly_error_message("https://example.com", RuntimeError(detail), "zh"), detail)

    def test_remaining_time_in_both_languages(self):
        self.assertEqual(bridge._format_eta(65, "zh"), "1 分 5 秒")
        self.assertEqual(bridge._format_eta(65, "en"), "1m 5s")
        self.assertEqual(bridge._format_eta(3605, "zh"), "1 小时 0 分钟")
        self.assertIsNone(bridge._format_eta(None, "zh"))

    def test_fetch_error_keeps_original_cause(self):
        original = URLError("offline")
        downloader = MagicMock()
        downloader.return_value.__enter__.return_value.extract_info.side_effect = original
        with patch.object(bridge, "_ensure_yt_dlp_loaded"), patch.object(bridge, "YoutubeDL", downloader):
            with self.assertRaisesRegex(RuntimeError, "网络错误") as result:
                bridge.fetch_video_info("https://example.com", None, "zh")
        self.assertIs(result.exception.__cause__, original)

    def test_download_progress_receives_language_without_changing_path(self):
        emitter = MagicMock()
        token = MagicMock()
        token.isCancelled.return_value = False

        def create_downloader(options):
            instance = MagicMock()

            def extract_info(url, download):
                options["progress_hooks"][0]({
                    "status": "downloading", "downloaded_bytes": 50,
                    "total_bytes": 100, "eta": 65,
                })
                options["progress_hooks"][0]({"status": "finished", "filename": "/tmp/video.mp4"})
                return {"format": "mp4", "height": 720}

            instance.__enter__.return_value.extract_info.side_effect = extract_info
            return instance

        with patch.object(bridge, "_ensure_yt_dlp_loaded"), \
                patch.object(bridge, "YoutubeDL", side_effect=create_downloader), \
                patch.object(bridge, "_resolve_final_path", return_value="/tmp/video.mp4"), \
                self.assertLogs(level="WARNING"):
            result = bridge.download_video("task", "https://example.com", "/tmp/video.mp4", "best", None, emitter, token, "zh")
        self.assertEqual(result, "/tmp/video.mp4")
        self.assertEqual(emitter.emit.call_args_list[0].args[3], "1 分 5 秒")
        self.assertEqual(emitter.emit.call_args_list[-1].args[4], "下载完成")


if __name__ == "__main__":
    unittest.main()
