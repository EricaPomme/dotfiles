#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import urllib.request
from typing import Any, Dict, List, Optional


JSON_SCHEMA: Dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "required": ["label", "tasks"],
    "properties": {
        "label": {"type": "string", "minLength": 1},
        "tasks": {
            "type": "array",
            "maxItems": 4,
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["task"],
                "properties": {
                    "task": {"type": "string", "minLength": 1},
                    "subtasks": {
                        "type": "array",
                        "maxItems": 6,
                        "items": {"type": "string", "minLength": 1},
                    },
                },
            },
        },
    },
}


def _read_input(args: list[str]) -> str:
    if args:
        return " ".join(args).strip()
    return sys.stdin.read().strip()


def _post_json(url: str, payload: Dict[str, Any], timeout: float = 120.0) -> Dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode("utf-8", errors="replace")
        #print(f"DEBUG: raw response body:\n{body}\n", file=sys.stderr)
    return json.loads(body)


def _extract_json_object(text: str) -> Optional[dict]:
    """
    Best-effort: if the model violates "JSON only", pull the first {...} block.
    """
    text = text.strip()
    if not text:
        return None

    # If it's already valid JSON, take it.
    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass

    # Try to locate a JSON object substring.
    m = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not m:
        return None
    try:
        obj = json.loads(m.group(0))
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def _normalize_label(label: str) -> str:
    """
    Enforce 3-5-ish words, but don't be destructive.
    """
    words = re.findall(r"\S+", label.strip())
    if len(words) < 3:
        # pad minimally without inventing meaning
        return " ".join((words + ["task"] * (3 - len(words))))[:80]
    if len(words) > 5:
        return " ".join(words[:5])
    return " ".join(words)


def _to_markdown(data: dict) -> str:
    label = _normalize_label(str(data.get("label", "")).strip() or "New tasks")
    lines: List[str] = [f"- [ ] {label}"]

    tasks = data.get("tasks", [])
    if not isinstance(tasks, list):
        tasks = []

    for t in tasks[:4]:
        if not isinstance(t, dict):
            continue
        task = str(t.get("task", "")).strip()
        if not task:
            continue
        lines.append(f"  - [ ] {task}")

        subtasks = t.get("subtasks", [])
        if isinstance(subtasks, list):
            for st in subtasks[:6]:
                st_s = str(st).strip()
                if st_s:
                    lines.append(f"    - [ ] {st_s}")

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert text -> Markdown checklist via Ollama structured outputs.")
    parser.add_argument("text", nargs="*", help="Input text (if omitted, read stdin).")
    parser.add_argument("-m", "--model", default=os.getenv("OLLAMA_MODEL", "qwen3.5:9b"))
    parser.add_argument(
        "-t",
        "--temperature",
        type=float,
        default=float(os.getenv("OLLAMA_TEMPERATURE", "0.2")),
        help="Lower is more deterministic; recommend ~0.1-0.3 for this tool.",
    )
    parser.add_argument(
        "--base-url",
        default=os.getenv("OLLAMA_BASE_URL", "http://localhost:11434/api"),
        help="Ollama API base URL (default: http://localhost:11434/api).",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=float(os.getenv("OLLAMA_TIMEOUT", "120")),
        help="HTTP timeout seconds.",
    )
    ns = parser.parse_args()

    raw_in = _read_input(ns.text)
    if not raw_in.strip():
        return 0

    prompt = """You are a tool that extracts a concise technical todo list from short input text.

Your response must match the provided JSON schema exactly.

CONTEXT
- The input often refers to technical, system administration, scripting, infrastructure, or software tasks.
- Another program will render your JSON into Markdown checkboxes.
- Be conservative, but useful.

GOAL
Convert the input into a small, practical checklist with:
- one short label
- a small number of tasks
- optional subtasks only when clearly helpful

OUTPUT REQUIREMENTS
- Return ONLY valid JSON matching the schema.
- Do not return Markdown.
- Do not return prose.
- Do not explain your reasoning.
- Do not include multiple interpretations.
- Do not include any keys not defined in the schema.

LABEL RULES
- "label" must be a brief summary of the overall task in 3 to 5 words.
- The label should be natural and human-readable.
- Do not repeat the input mechanically unless the input is already a good short label.

TASK RULES
- "tasks" should contain the main actionable steps.
- Use at most 4 tasks.
- Each task must be specific, concrete, and action-oriented.
- Prefer fewer tasks over more tasks.
- Do not repeat or paraphrase the same task.

SUBTASK RULES
- Add subtasks only if they are clearly implied or are the minimal generic steps normally required.
- Subtasks must stay generic and must not invent environment-specific details.
- Use at most 6 subtasks per task.

ALLOWED GENERIC EXPANSION
- For short technical phrases, you may expand into minimal generic operational steps.
- Good generic examples:
  - testing software -> run a sample command, verify expected output
  - deploying configuration -> apply configuration, reload service, verify status
  - verifying a system -> check status, run validation, confirm result
- Bad invented details:
  - package names not mentioned
  - service names not mentioned
  - file paths not mentioned
  - ports, endpoints, APIs, or models not mentioned
  - setup or installation steps unless setup or installation is implied

ANTI-HALLUCINATION RULES
- Only include tasks directly implied by the input.
- Do not invent unrelated workflows.
- Do not pad the output with extra tasks.
- Do not include setup or installation unless the input implies setup or installation.
- If the input is small or ambiguous, prefer one task.
- If the input is a short technical action, one task with 1 to 2 helpful generic subtasks is acceptable.

EXAMPLES

Input:
test ollama

Example JSON output:
{
  "label": "Test Ollama setup",
  "tasks": [
    {
      "task": "Run test inference",
      "subtasks": [
        "Execute a sample prompt",
        "Confirm response output"
      ]
    }
  ]
}

Input:
deploy nginx and verify TLS

Example JSON output:
{
  "label": "Deploy nginx changes",
  "tasks": [
    {
      "task": "Apply nginx configuration",
      "subtasks": [
        "Validate configuration syntax",
        "Reload nginx service"
      ]
    },
    {
      "task": "Verify TLS certificate renewal"
    }
  ]
}

Input:
clean up old backups

Example JSON output:
{
  "label": "Clean up backups",
  "tasks": [
    {
      "task": "Review old backup sets"
    },
    {
      "task": "Remove unneeded backups"
    }
  ]
}

END OF EXAMPLES

Extract tasks from the following input:"""

    final_prompt = f"{prompt}\n\n{raw_in}\n"

    payload = {
        "model": ns.model,
        "prompt": final_prompt,
        "stream": False,
        "think": False,
        "options": {"temperature": ns.temperature},
        "format": JSON_SCHEMA,
    }

    out = _post_json(f"{ns.base_url.rstrip('/')}/generate", payload, timeout=ns.timeout)
    resp_text = out.get("response", "")
    data = _extract_json_object(resp_text)
    if not data:
        # Fallback: minimal sane output (no hallucinated expansions).
        label = _normalize_label(raw_in.strip()[:60] or "New tasks")
        sys.stdout.write(f"- [ ] {label}\n")
        return 0

    sys.stdout.write(_to_markdown(data) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())