# ppt-master-user

Working folder for [PPT Master](https://github.com/hugohe3/ppt-master) — an AI workflow that turns documents or topics into natively editable PowerPoint decks.

This repository holds no application code of its own. It vendors the official skill and the setup needed to run it.

## Layout

| Path | What it is |
| --- | --- |
| `.cursor/skills/ppt-master/` | The official PPT Master skill, copied unmodified from [hugohe3/ppt-master](https://github.com/hugohe3/ppt-master) at `skills/ppt-master/`. Cursor discovers it automatically. |
| `projects/` | Working folder. Each generation run gets `projects/<name>/` with its sources, authored SVG, and `exports/*.pptx`. |
| `scripts/install.sh` | Installs the skill's Python and system dependencies. Idempotent. |
| `.cursor/environment.json` | Cloud Agent environment; runs the install script after checkout. |

## Setup

```bash
./scripts/install.sh
```

This installs the dependencies listed in `.cursor/skills/ppt-master/requirements.txt` and verifies the skill's integrity gate.

## Usage

Ask the agent in chat, for example:

```
Please create a PPT from projects/q3-report/sources/report.pdf
```

The skill routes the request itself; see `.cursor/skills/ppt-master/SKILL.md`. Decks land in `projects/<name>/exports/<name>_<timestamp>.pptx`.

## Optional API keys

The core pipeline runs without any key — web image search falls back to Openverse and Wikimedia Commons, and narration uses `edge-tts`. To use AI image generation or higher-quality stock photography, copy the template and fill in what you need:

```bash
cp .cursor/skills/ppt-master/.env.example .env
```

`.env` is gitignored. The install script creates it for you if it is missing.

## Updating the skill

The skill is a vendored copy, not a submodule. To move to a newer upstream release, replace `.cursor/skills/ppt-master/` with the same directory from a fresh checkout of the official repository and rerun `./scripts/install.sh`. Do not edit files inside the skill: `SKILL.md` runs `scripts/attribution_guard.py` first, and local modifications make the skill refuse to run.

Vendored from upstream commit `c45b7427e707d8695f1bf7df4d20360d05f82e7c` (skill version 6.3.0).

## License

The vendored skill is MIT licensed, Copyright (c) 2025-2026 Hugo He. See `.cursor/skills/ppt-master/LICENSE`.
