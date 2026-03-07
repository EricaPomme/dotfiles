#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.request
from typing import Any, Dict


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
    return json.loads(body)


def main() -> int:
    parser = argparse.ArgumentParser(description="Quick CLI ask() using Ollama /api/generate.")
    parser.add_argument("text", nargs="*", help="Prompt text (if omitted, read stdin).")
    parser.add_argument("-m", "--model", default=os.getenv("OLLAMA_MODEL", "qwen3.5:9b"))
    parser.add_argument(
        "-t",
        "--temperature",
        type=float,
        default=float(os.getenv("OLLAMA_TEMPERATURE", "0.7")),
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
    parser.add_argument(
        "--system",
        default=os.getenv("OLLAMA_SYSTEM", ""),
        help="Optional system prompt.",
    )
    ns = parser.parse_args()

    prompt_in = _read_input(ns.text)
    if not prompt_in.strip():
        return 0

    # Concise + accurate, tuned for terminal use
    prompt = (
        "Answer the following question concisely and accurately.\n"
        "If you make assumptions, label them as assumptions.\n\n"
        f"{prompt_in}\n"
    )

    payload: Dict[str, Any] = {
        "model": ns.model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": ns.temperature},
    }
    if ns.system.strip():
        payload["system"] = ns.system

    out = _post_json(f"{ns.base_url.rstrip('/')}/generate", payload, timeout=ns.timeout)
    sys.stdout.write(out.get("response", "") + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())