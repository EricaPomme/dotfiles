---
applyTo: "**"
---

# Global Copilot Instructions

## Table of Contents

- [Maintaining these instructions](#maintaining-these-instructions)
- [ASCII-only source files](#ascii-only-source-files)
- [Markdown table of contents](#markdown-table-of-contents)
- [Stylistic preferences](#stylistic-preferences)
- [Keep documentation up to date](#keep-documentation-up-to-date)
- [Backup files outside version control](#backup-files-outside-version-control)
- [Unix shell config with dotfiles and zsh](#unix-shell-config-with-dotfiles-and-zsh)
- [Versioning](#versioning)
- [Lint before committing](#lint-before-committing)

## Maintaining these instructions

These files are global defaults that apply across all projects. Help keep them
current and useful:

- **New global rule:** If the user specifies a rule or preference that is not
  project-specific, ask whether it should be added to both global instruction
  files in dotfiles:
  - `~/dotfiles/copilot-instructions/copilot-instructions.md` (Copilot CLI)
  - `~/dotfiles/copilot-instructions/global.instructions.md` (VS Code)

- **Emerging pattern:** If you notice a pattern the user applies consistently
  across multiple projects -- a style choice, a structural convention, a tool
  preference -- mention it and ask whether it should be promoted to a global
  rule.

When updating these files, always update both and commit the change.

---

## ASCII-only source files

All source files **must use only plain ASCII characters (code points 0-127)**
unless explicitly instructed otherwise. This is a hard default -- no Unicode,
no emoji, no smart/curly quotes, no decorative symbols.

Rationale: non-ASCII characters in source files cause silent encoding bugs
(e.g. Windows PowerShell 5.1 misreads UTF-8 without BOM as ANSI, turning
em dashes and ellipses into parse errors), reduce portability, and make
diffs harder to read.

Use these ASCII substitutions:

| Instead of                  | Use                      |
| --------------------------- | ------------------------ |
| em dash (U+2014)            | `-` (hyphen with spaces) |
| ellipsis (U+2026)           | `...`                    |
| bullet (U+2022)             | `*`                      |
| box-drawing chars (U+2500+) | `-`                      |
| Curly/smart quotes          | Straight `"` and `'`     |
| Any other non-ASCII char    | Plain ASCII equivalent   |

The only exceptions are:

- User-visible string content (UI labels, output messages) where a specific
  character is explicitly requested
- Data files where the format requires Unicode (e.g. JSON with non-ASCII values)
- Files where you are explicitly told Unicode is acceptable

---

## Markdown table of contents

When editing a Markdown file (e.g. README.md, CHANGELOG.md, any `.md` file),
include a table of contents unless specifically asked not to. Place it after
the first H1 (`#`) heading and before the next section. Use a plain Markdown
linked list reflecting all H2 (`##`) headings, and H3 (`###`) headings if the
document is long enough to warrant them.

Example structure:

```markdown
# Project Title

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic usage](#basic-usage)
  - [Advanced options](#advanced-options)
- [Contributing](#contributing)

## Overview

...
```

Keep the TOC in sync whenever headings are added, removed, or renamed.

---

## Stylistic preferences

Unless a project-level instruction overrides it, these preferences apply.
**Project-level instructions take precedence over these global defaults.**

### General principles

- Prefer simple, clean, and easy-to-maintain code over clever or terse code.
- Portability and maintainability matter more than performance unless a
  specific performance requirement exists.
- Do not reach for a library or framework to solve a problem that can be
  solved simply with the language's standard features. Avoid adding
  dependencies unless the alternative would be unreasonably complex or
  error-prone.
- Where a dependency is already present in the project, prefer using it
  consistently over introducing a second one for the same purpose.

---

## Keep documentation up to date

Documentation that disagrees with the code is worse than no documentation.
Treat doc updates as part of the same change, not a follow-up task.

### Docstrings and inline comments

- When a function, method, or command's signature changes (parameters added,
  removed, renamed, or retyped), update its docstring immediately.
- When behaviour changes in a meaningful way -- return values, side effects,
  error conditions, accepted input -- update the docstring to match.
- Remove or correct inline comments that no longer reflect what the code does.
  A stale comment that contradicts the code is actively harmful.
- Do not add comments that merely restate what the code obviously does.
  Comments should explain _why_, not _what_.

### README and other Markdown docs

- If a change affects something documented in README.md (usage examples,
  configuration, CLI flags, function signatures, prerequisites), update that
  section in the same pass.
- If a feature is removed, remove or clearly mark its documentation.
- Keep code examples in docs runnable. If you change the code, verify the
  example still works and update it if not.

### Scope

Apply this rule proportionally. A small internal refactor with no external
behaviour change does not require a README update. A changed public interface,
a new required parameter, or a removed feature does.

---

## Backup files outside version control

When modifying a file that is **not** in a git repository, create a timestamped
backup copy before performing the edit. This provides a safety net for
untracked files.

**Rule**: Before editing a non-versioned file, copy it to:
`[original-filename].[YYYYMMDD_HHMMSS].backup`

Example: editing `config.ini` creates `config.ini.20260402_143022.backup`

**Recovery**: If something goes wrong, use the most recent backup to undo.
Older backups remain available if needed.

**Scope**: This applies only to files outside git repositories. Files tracked
by version control already have history and do not need manual backups.

---

## Unix shell config with dotfiles and zsh

When working on a Mac/Linux/BSD or other Unix system and a task involves editing
a user shell config file (e.g. `~/.bashrc`, `~/.bash_profile`, `~/.profile`):

1. Check whether `~/dotfiles` exists and whether `zsh` is installed.
2. If **both** are present, and the work is **not** being done inside the
   dotfiles repository itself, redirect the edit to the zsh equivalent with a
   `.local` suffix instead of editing the bash file directly.

   Examples:
   - `~/.bashrc` -> `~/.zshrc.local`
   - `~/.bash_profile` -> `~/.zprofile.local`
   - `~/.profile` -> `~/.zprofile.local`

   The dotfiles repository already sources these `.local` files automatically,
   so no additional wiring is needed.

3. If only one condition is met (dotfiles present but zsh absent, or vice
   versa), edit the file the user requested without redirecting.

---

## Versioning

Unless a project already uses a different, clearly established versioning scheme,
use **MAJOR.MINOR.REVISION** versioning (e.g. `1.2.3`).

### Version increment rules

- **REVISION**: Any bugfix or small, self-contained change. Increment automatically.
- **MINOR**: Substantial additions or improvements that do not break compatibility.
  Ask the user before incrementing.
- **MAJOR**: Breaking changes -- changes that would break compatibility with other
  components, consumers, or features. Ask the user before incrementing.

When a MAJOR or MINOR version is incremented, reset all lesser markers to zero:

- `1.1.2` + minor bump = `1.2.0` (not `1.2.2`)
- `1.1.2` + major bump = `2.0.0` (not `2.1.2`)

### CHANGELOG.md

When a project has a CHANGELOG.md:

- **During development**: Add every notable modification or bugfix to a
  **"Latest Changes"** section at the top of the file.
- **Before committing**: Promote the "Latest Changes" section to a dated,
  versioned section heading (e.g. `## [1.2.0] - 2026-04-02`). Leave the
  "Latest Changes" section empty (or remove it) for the next round of work.
  Do this in the same commit as the code changes.

---

## Lint before committing

Before committing changes to any file, check whether a linter is available on
the system for that file's language. If one is found, run it against the
modified file(s) and resolve any errors or warnings before proceeding with the
commit.

Common linters by language/file type:

| Language / File type | Linter               |
| -------------------- | -------------------- |
| Markdown (`.md`)     | `markdownlint`       |
| PowerShell (`.ps1`)  | `PSScriptAnalyzer`   |
| JavaScript / TS      | `eslint`             |
| Python               | `flake8` or `ruff`   |
| JSON                 | `jsonlint`           |
| YAML                 | `yamllint`           |
| CSS / SCSS           | `stylelint`          |

If a linter is not installed, do not install it automatically. Instead,
inform the user that a linter is available for that language and suggest
they install it. Only run linters that are already present on the system
or defined in the project's tooling.
