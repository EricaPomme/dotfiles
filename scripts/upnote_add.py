#!/usr/bin/env python3
import sys
import urllib.parse
import subprocess
import re
from datetime import datetime
from pathlib import Path

def sanitize_text(text):
    replacements = {
        '‘': "'", '’': "'", '“': '"', '”': '"',
        '–': '-', '—': '--', '…': '...',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    # Remove non-printables except tabs and newlines
    return re.sub(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\uFFFF]', '', text)

def markdown_lint(text):
    try:
        from tempfile import NamedTemporaryFile
        import shutil
        if not shutil.which('markdownlint'):
            return
        with NamedTemporaryFile("w+", suffix=".md", delete=False) as tmp:
            tmp.write(text)
            tmp.flush()
            tmp_name = tmp.name
        subprocess.run(["markdownlint", tmp_name])
    except Exception as e:
        print(f"⚠️  Linting skipped due to error: {e}", file=sys.stderr)

def clean_title(raw_title):
    # Strip leading markdown heading chars and trailing colons/dashes
    title = re.sub(r'^\s*#+\s*', '', raw_title)        # Remove leading #
    title = re.sub(r'[\s:–—\-]+$', '', title)           # Remove trailing punctuation
    return title.strip()

def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("notebook", help="Notebook name (required)")
    parser.add_argument("--no-lint", action="store_true", help="Skip markdown linting")
    args = parser.parse_args()

    # Read from stdin
    raw_input = sys.stdin.read()

    # Sanitize and normalize text
    clean_input = sanitize_text(raw_input)

    # Extract title and body
    lines = clean_input.strip().splitlines()
    title = clean_title(lines[0]) if lines else f"Note {datetime.now().isoformat()}"
    body = clean_input

    if not args.no_lint:
        markdown_lint(body)

    # URL encode
    title_enc = urllib.parse.quote(title)
    body_enc = urllib.parse.quote(body)
    notebook_enc = urllib.parse.quote(args.notebook)

    # Build URL
    url = (
        f"upnote://x-callback-url/note/new?"
        f"title={title_enc}&text={body_enc}&notebook={notebook_enc}"
        f"&new_window=false&markdown=true"
    )

    # Open via system default
    try:
        subprocess.run(["open", url], check=True)
    except FileNotFoundError:
        subprocess.run(["xdg-open", url], check=True)

if __name__ == "__main__":
    main()
