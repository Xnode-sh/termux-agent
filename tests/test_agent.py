import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from agent import run_conversation


class FakeClient:
    """Имитирует OllamaClient: сперва просит вызвать run_shell, затем отвечает текстом."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = 0

    def chat(self, messages, tools=None):
        self.calls += 1
        return self.responses.pop(0)


class RunConversationTest(unittest.TestCase):
    def test_single_tool_call_then_final_answer(self):
        responses = [
            {
                "role": "assistant",
                "content": "",
                "tool_calls": [
                    {"function": {"name": "run_shell", "arguments": {"command": "echo hi"}}}
                ],
            },
            {"role": "assistant", "content": "готово, вывод: hi"},
        ]
        client = FakeClient(responses)
        cfg = SimpleNamespace(auto_yes=True, xnode_path=None, max_steps=8)
        messages = [{"role": "user", "content": "запусти echo hi"}]

        result = run_conversation(client, cfg, messages)

        self.assertEqual(result, "готово, вывод: hi")
        self.assertEqual(client.calls, 2)
        tool_messages = [m for m in messages if m.get("role") == "tool"]
        self.assertEqual(len(tool_messages), 1)
        self.assertIn("hi", tool_messages[0]["content"])

    def test_no_tool_call_returns_immediately(self):
        client = FakeClient([{"role": "assistant", "content": "просто ответ"}])
        cfg = SimpleNamespace(auto_yes=True, xnode_path=None, max_steps=8)
        messages = [{"role": "user", "content": "привет"}]

        result = run_conversation(client, cfg, messages)

        self.assertEqual(result, "просто ответ")
        self.assertEqual(client.calls, 1)

    def test_max_steps_is_enforced(self):
        looping_response = {
            "role": "assistant",
            "content": "",
            "tool_calls": [
                {"function": {"name": "list_dir", "arguments": {"path": "."}}}
            ],
        }
        client = FakeClient([looping_response] * 3)
        cfg = SimpleNamespace(auto_yes=True, xnode_path=None, max_steps=3)
        messages = [{"role": "user", "content": "зациклись"}]

        result = run_conversation(client, cfg, messages)

        self.assertIn("превышен лимит шагов", result)
        self.assertEqual(client.calls, 3)


if __name__ == "__main__":
    unittest.main()
