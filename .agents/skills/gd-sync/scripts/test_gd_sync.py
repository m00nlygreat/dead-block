from __future__ import annotations

from contextlib import redirect_stdout
from datetime import datetime
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest


SCRIPT_PATH = Path(__file__).with_name("gd_sync.py")
SPEC = importlib.util.spec_from_file_location("gd_sync", SCRIPT_PATH)
assert SPEC and SPEC.loader
gd_sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gd_sync)


class GdSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.original_list_drive_folder = gd_sync.list_drive_folder
        self.original_subprocess_run = gd_sync.subprocess.run

    def tearDown(self) -> None:
        gd_sync.list_drive_folder = self.original_list_drive_folder
        gd_sync.subprocess.run = self.original_subprocess_run

    def test_sync_runs_pull_then_push_without_intermediate_last_sync_update(self) -> None:
        calls = []
        original_run_pull = gd_sync.run_pull
        original_run_push = gd_sync.run_push
        try:
            gd_sync.run_pull = lambda *args, **kwargs: calls.append(("pull", kwargs)) or 0
            gd_sync.run_push = lambda *args, **kwargs: calls.append(("push", kwargs)) or 0
            with tempfile.TemporaryDirectory() as temp_name:
                config = {"google_native": "html", "last_sync_at": "old"}
                result = gd_sync.run_sync(
                    "fake-gog",
                    "folder",
                    Path(temp_name),
                    [],
                    config,
                    Path(temp_name) / "gd-sync.yml",
                    True,
                )
            self.assertEqual(result, 0)
            self.assertEqual([name for name, _kwargs in calls], ["pull", "push"])
            self.assertTrue(all(kwargs["update_last_sync"] is False for _name, kwargs in calls))
            self.assertEqual(config["last_sync_at"], "old")
        finally:
            gd_sync.run_pull = original_run_pull
            gd_sync.run_push = original_run_push

    def test_config_defaults_to_html_and_accepts_modes_and_inline_comment(self) -> None:
        with tempfile.TemporaryDirectory() as temp_name:
            path = Path(temp_name) / "gd-sync.yml"
            path.write_text(
                'drive_folder_id: "folder"\n'
                'google_native: "pointer"  # html | pointer | export\n'
                "last_sync_at: null\n"
                "ignore: []\n",
                encoding="utf-8",
            )
            self.assertEqual(gd_sync.load_config(path)["google_native"], "pointer")
            path.write_text('drive_folder_id: "folder"\nignore: []\n', encoding="utf-8")
            self.assertEqual(gd_sync.load_config(path)["google_native"], "html")
            path.write_text(
                'drive_folder_id: "folder"\ngoogle_native: "link"\nignore: []\n',
                encoding="utf-8",
            )
            self.assertEqual(gd_sync.load_config(path)["google_native"], "html")

    def test_link_html_is_escaped_script_free_and_keeps_doc_id(self) -> None:
        content = gd_sync.google_link_html(
            '<매출 & "보고서">',
            'https://docs.google.com/spreadsheets/d/example?x=1&next="yes"',
            "1-VEv0yz1A1LdpEJKf8BxPTQaKEPkCVBjKTtFywVX0Y4",
        ).decode("utf-8")
        self.assertIn('<meta charset="utf-8">', content)
        self.assertIn('http-equiv="refresh"', content)
        self.assertIn("&lt;매출 &amp; &quot;보고서&quot;&gt;", content)
        self.assertIn("x=1&amp;next=&quot;yes&quot;", content)
        self.assertIn("1-VEv0yz1A1LdpEJKf8BxPTQaKEPkCVBjKTtFywVX0Y4", content)
        self.assertIn("<a href=", content)
        self.assertNotIn("<script", content.lower())

    def test_push_excludes_only_generated_link_html(self) -> None:
        with tempfile.TemporaryDirectory() as root_name, tempfile.TemporaryDirectory() as stage_name:
            root = Path(root_name)
            generated = root / "generated.gdrive.html"
            generated.write_bytes(gd_sync.google_link_html("Remote", "https://example.test/doc", "doc-id"))
            (root / "generated.gsheet").write_bytes(
                gd_sync.google_pointer("sheet-id", "", "person@example.test")
            )
            (root / "handmade.gdrive.html").write_text("<html>handmade</html>", encoding="utf-8")
            (root / "handmade.gsheet").write_text('{"doc_id":"handmade"}', encoding="utf-8")
            (root / "ordinary.html").write_text("<html>ordinary</html>", encoding="utf-8")

            copied, ignored = gd_sync.stage_tree(root, Path(stage_name), [])

            self.assertEqual((copied, ignored), (3, 2))
            self.assertFalse((Path(stage_name) / generated.name).exists())
            self.assertFalse((Path(stage_name) / "generated.gsheet").exists())
            self.assertTrue((Path(stage_name) / "handmade.gdrive.html").exists())
            self.assertTrue((Path(stage_name) / "handmade.gsheet").exists())
            self.assertTrue((Path(stage_name) / "ordinary.html").exists())

    def test_link_pull_handles_sheet_and_form_then_skips_identical_content(self) -> None:
        items = [
            {
                "id": "sheet-id",
                "name": "재고표",
                "mimeType": "application/vnd.google-apps.spreadsheet",
                "webViewLink": "https://docs.google.com/spreadsheets/d/sheet-id/edit",
            },
            {
                "id": "form-id",
                "name": "만족도 조사",
                "mimeType": "application/vnd.google-apps.form",
                "webViewLink": "https://docs.google.com/forms/d/form-id/edit",
            },
        ]
        gd_sync.list_drive_folder = lambda _gog, _folder_id: items
        with tempfile.TemporaryDirectory() as temp_name:
            root = Path(temp_name)
            output = io.StringIO()
            with redirect_stdout(output):
                result = gd_sync.pull_tree("fake-gog", "root", root, [], True, "html")
            self.assertEqual(result, (2, 0, 0, 0))
            self.assertIn("create_link\t재고표.gdrive.html", output.getvalue())
            self.assertIn("create_link\t만족도 조사.gdrive.html", output.getvalue())
            self.assertEqual(list(root.iterdir()), [])

            with redirect_stdout(io.StringIO()):
                gd_sync.pull_tree("fake-gog", "root", root, [], False, "html")
            output = io.StringIO()
            with redirect_stdout(output):
                result = gd_sync.pull_tree("fake-gog", "root", root, [], True, "html")
            self.assertEqual(result, (0, 0, 2, 0))
            self.assertIn("skip_link\t재고표.gdrive.html", output.getvalue())
            self.assertIn("skip_link\t만족도 조사.gdrive.html", output.getvalue())

    def test_export_mode_exports_supported_and_links_unsupported_native(self) -> None:
        gd_sync.list_drive_folder = lambda _gog, _folder_id: [
            {
                "id": "sheet-id",
                "name": "재고표",
                "mimeType": "application/vnd.google-apps.spreadsheet",
                "webViewLink": "https://docs.google.com/spreadsheets/d/sheet-id/edit",
            },
            {
                "id": "form-id",
                "name": "설문",
                "mimeType": "application/vnd.google-apps.form",
                "webViewLink": "https://docs.google.com/forms/d/form-id/edit",
            },
        ]
        with tempfile.TemporaryDirectory() as temp_name:
            output = io.StringIO()
            with redirect_stdout(output):
                result = gd_sync.pull_tree("fake-gog", "root", Path(temp_name), [], True, "export")
            self.assertEqual(result, (2, 0, 0, 0))
            self.assertIn("create_file\t재고표.xlsx", output.getvalue())
            self.assertIn("create_link\t설문.gdrive.html", output.getvalue())
            self.assertEqual(list(Path(temp_name).iterdir()), [])

    def test_export_mode_passes_expected_formats_to_fake_gog(self) -> None:
        mime_and_format = [
            ("application/vnd.google-apps.document", "docx"),
            ("application/vnd.google-apps.spreadsheet", "xlsx"),
            ("application/vnd.google-apps.presentation", "pptx"),
            ("application/vnd.google-apps.drawing", "png"),
        ]
        gd_sync.list_drive_folder = lambda _gog, _folder_id: [
            {
                "id": expected_format,
                "name": expected_format,
                "mimeType": mime,
                "webViewLink": f"https://docs.google.com/{expected_format}",
            }
            for mime, expected_format in mime_and_format
        ]
        commands = []

        class Completed:
            returncode = 0

        def fake_run(command, **_kwargs):
            commands.append(command)
            target = Path(command[command.index("--out") + 1])
            target.write_bytes(b"fake export")
            return Completed()

        gd_sync.subprocess.run = fake_run
        with tempfile.TemporaryDirectory() as temp_name, redirect_stdout(io.StringIO()):
            result = gd_sync.pull_tree("fake-gog", "root", Path(temp_name), [], False, "export")
            self.assertEqual(result, (4, 0, 0, 0))
            self.assertEqual(
                [command[command.index("--format") + 1] for command in commands],
                ["docx", "xlsx", "pptx", "png"],
            )

    def test_pointer_mode_matches_drive_desktop_doc_id_shape(self) -> None:
        gd_sync.list_drive_folder = lambda _gog, _folder_id: [
            {
                "id": "1-VEv0yz1A1LdpEJKf8BxPTQaKEPkCVBjKTtFywVX0Y4",
                "name": "입출고내역_전처리_실습_",
                "mimeType": "application/vnd.google-apps.spreadsheet",
                "resourceKey": "",
                "webViewLink": "https://docs.google.com/spreadsheets/d/example/edit",
            },
            {
                "id": "form-id",
                "name": "설문",
                "mimeType": "application/vnd.google-apps.form",
                "resourceKey": "form-key",
                "webViewLink": "https://docs.google.com/forms/d/form-id/edit",
            },
        ]
        with tempfile.TemporaryDirectory() as temp_name:
            root = Path(temp_name)
            output = io.StringIO()
            with redirect_stdout(output):
                result = gd_sync.pull_tree(
                    "fake-gog", "root", root, [], False, "pointer", "moonlygreat@gmail.com"
                )
            self.assertEqual(result, (2, 0, 0, 0))
            self.assertIn("create_pointer\t입출고내역_전처리_실습_.gsheet", output.getvalue())
            self.assertIn("create_pointer\t설문.gform", output.getvalue())
            sheet = (root / "입출고내역_전처리_실습_.gsheet").read_text(encoding="utf-8")
            self.assertIn('"doc_id":"1-VEv0yz1A1LdpEJKf8BxPTQaKEPkCVBjKTtFywVX0Y4"', sheet)
            self.assertIn('"email":"moonlygreat@gmail.com"', sheet)

    def test_pull_skips_when_local_file_is_newer(self) -> None:
        remote_time = "2026-08-05T10:00:00Z"
        gd_sync.list_drive_folder = lambda _gog, _folder_id: [
            {
                "id": "file-id",
                "name": "보고서.txt",
                "mimeType": "text/plain",
                "md5Checksum": "different-md5",
                "modifiedTime": remote_time,
            }
        ]
        with tempfile.TemporaryDirectory() as temp_name:
            root = Path(temp_name)
            target = root / "보고서.txt"
            target.write_text("local newer", encoding="utf-8")
            local_time = datetime.fromisoformat("2026-08-05T11:00:00+00:00").timestamp()
            os.utime(target, (local_time, local_time))
            output = io.StringIO()
            with redirect_stdout(output):
                result = gd_sync.pull_tree("fake-gog", "root", root, [], True, "html")
            self.assertEqual(result, (0, 0, 1, 0))
            self.assertIn("skip_file\t보고서.txt\tlocal is newer or same age", output.getvalue())

    def test_pull_updates_when_remote_file_is_newer(self) -> None:
        remote_time = "2026-08-05T11:00:00Z"
        gd_sync.list_drive_folder = lambda _gog, _folder_id: [
            {
                "id": "file-id",
                "name": "보고서.txt",
                "mimeType": "text/plain",
                "md5Checksum": "different-md5",
                "modifiedTime": remote_time,
            }
        ]

        class Completed:
            returncode = 0

        def fake_run(command, **_kwargs):
            target = Path(command[command.index("--out") + 1])
            target.write_text("remote newer", encoding="utf-8")
            return Completed()

        gd_sync.subprocess.run = fake_run
        with tempfile.TemporaryDirectory() as temp_name:
            root = Path(temp_name)
            target = root / "보고서.txt"
            target.write_text("local older", encoding="utf-8")
            local_time = datetime.fromisoformat("2026-08-05T10:00:00+00:00").timestamp()
            os.utime(target, (local_time, local_time))
            with redirect_stdout(io.StringIO()):
                result = gd_sync.pull_tree("fake-gog", "root", root, [], False, "html")
            self.assertEqual(result, (0, 1, 0, 0))
            self.assertEqual(target.read_text(encoding="utf-8"), "remote newer")

    def test_push_filter_skips_remote_file_that_is_newer(self) -> None:
        with tempfile.TemporaryDirectory() as root_name, tempfile.TemporaryDirectory() as staging_name:
            root = Path(root_name)
            staging = Path(staging_name)
            source = root / "보고서.txt"
            source.write_text("local older", encoding="utf-8")
            local_time = datetime.fromisoformat("2026-08-05T10:00:00+00:00").timestamp()
            os.utime(source, (local_time, local_time))
            staged = staging / source.name
            staged.parent.mkdir(parents=True, exist_ok=True)
            staged.write_bytes(source.read_bytes())
            remote_files = {
                "보고서.txt": {
                    "md5Checksum": "different-md5",
                    "modifiedTime": "2026-08-05T11:00:00Z",
                }
            }
            output = io.StringIO()
            with redirect_stdout(output):
                skipped = gd_sync.filter_staging_for_remote_newer(staging, root, remote_files)
            self.assertEqual(skipped, 1)
            self.assertFalse(staged.exists())
            self.assertIn("skip_file\t보고서.txt\tremote is newer or same age", output.getvalue())

    def test_transformed_path_collision_is_an_error(self) -> None:
        gd_sync.list_drive_folder = lambda _gog, _folder_id: [
            {
                "id": "native-id",
                "name": "같은이름",
                "mimeType": "application/vnd.google-apps.document",
                "webViewLink": "https://docs.google.com/document/d/native-id/edit",
            },
            {
                "id": "html-id",
                "name": "같은이름.gdrive.html",
                "mimeType": "text/html",
                "md5Checksum": "",
            },
        ]
        with tempfile.TemporaryDirectory() as temp_name:
            with redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError, "duplicate Drive path after transform"):
                    gd_sync.pull_tree("fake-gog", "root", Path(temp_name), [], True, "html")


if __name__ == "__main__":
    unittest.main()
