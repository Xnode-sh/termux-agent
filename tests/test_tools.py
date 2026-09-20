import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tools import dispatch, list_dir, read_file, run_shell, write_file


class ToolsTest(unittest.TestCase):
    def test_write_then_read_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "a" / "b.txt")
            result = write_file(path, "привет", auto_yes=True)
            self.assertTrue(result["ok"])
            read_result = read_file(path)
            self.assertTrue(read_result["ok"])
            self.assertEqual(read_result["content"], "привет")

    def test_write_file_refuses_overwrite_without_confirmation(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "b.txt")
            write_file(path, "one", auto_yes=True)
            result = write_file(path, "two", auto_yes=False)
            self.assertFalse(result["ok"])
            self.assertEqual(Path(path).read_text(), "one")

    def test_read_file_missing(self):
        result = read_file("/no/such/file/exists.txt")
        self.assertFalse(result["ok"])

    def test_list_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "x.txt").write_text("x")
            (Path(tmp) / "sub").mkdir()
            result = list_dir(tmp)
            self.assertTrue(result["ok"])
            self.assertIn("x.txt", result["entries"])
            self.assertIn("sub/", result["entries"])

    def test_run_shell_auto_yes(self):
        result = run_shell("echo hello", auto_yes=True)
        self.assertTrue(result["ok"])
        self.assertEqual(result["returncode"], 0)
        self.assertIn("hello", result["stdout"])

    def test_run_shell_without_confirmation_is_rejected(self):
        result = run_shell("echo should-not-run", auto_yes=False)
        self.assertFalse(result["ok"])

    def test_dispatch_unknown_tool(self):
        result = dispatch("nope", {}, auto_yes=True, xnode_path=None)
        self.assertFalse(result["ok"])

    def test_dispatch_injects_auto_yes(self):
        result = dispatch("run_shell", {"command": "echo hi"}, auto_yes=True, xnode_path=None)
        self.assertTrue(result["ok"])

    def test_osint_lookup_without_xnode_path(self):
        result = dispatch("osint_lookup", {"kind": "email", "target": "a@b.com"}, auto_yes=True, xnode_path=None)
        self.assertFalse(result["ok"])
        self.assertIn("xnode_path", result["error"])


if __name__ == "__main__":
    unittest.main()
