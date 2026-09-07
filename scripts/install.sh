#!/usr/bin/env bash
# Install the PPT Master skill's dependencies. Idempotent and non-interactive.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$REPO_ROOT/.cursor/skills/ppt-master"
REQUIREMENTS="$SKILL_DIR/requirements.txt"

log() { printf '\n==> %s\n' "$*"; }

if [ ! -f "$REQUIREMENTS" ]; then
  echo "error: skill not found at $SKILL_DIR" >&2
  echo "The vendored skill must be present before installing its dependencies." >&2
  exit 1
fi

log "Checking Python"
PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "error: $PYTHON not found. PPT Master needs Python 3.10 or newer." >&2
  exit 1
fi
"$PYTHON" - <<'PY'
import sys
if sys.version_info < (3, 10):
    sys.exit(f"error: Python 3.10+ required, found {sys.version.split()[0]}")
print(f"Python {sys.version.split()[0]} at {sys.executable}")
PY

# System packages: build toolchain for source builds of skia-pathops / uharfbuzz,
# fonts for glyph outlines, and pandoc for the legacy .doc/.odt/.rtf source formats.
log "Checking system packages"
SYSTEM_PACKAGES=(python3-dev build-essential fonts-liberation pandoc)
if ! "$PYTHON" -m pip --version >/dev/null 2>&1; then
  SYSTEM_PACKAGES+=(python3-pip)
fi
if command -v dpkg-query >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  missing=()
  for package in "${SYSTEM_PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$'; then
      missing+=("$package")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    echo "All present: ${SYSTEM_PACKAGES[*]}"
  else
    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
      if sudo -n true 2>/dev/null; then
        SUDO="sudo"
      else
        echo "warning: cannot install ${missing[*]} without passwordless sudo; continuing" >&2
      fi
    fi
    if [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ]; then
      echo "Installing: ${missing[*]}"
      export DEBIAN_FRONTEND=noninteractive
      $SUDO apt-get update -qq
      $SUDO apt-get install -y --no-install-recommends "${missing[@]}"
    fi
  fi
else
  echo "warning: apt-get unavailable; install ${SYSTEM_PACKAGES[*]} equivalents manually if pip needs them" >&2
fi

log "Installing Python dependencies from $REQUIREMENTS"
PIP_FLAGS=()
if "$PYTHON" - <<'PY'
import os, sys, sysconfig
in_venv = sys.prefix != sys.base_prefix
writable = os.access(sysconfig.get_path("purelib"), os.W_OK)
sys.exit(0 if not in_venv and not writable else 1)
PY
then
  # No virtualenv and no write access to system site-packages: install into the user site.
  PIP_FLAGS+=(--user)
  echo "Target: user site-packages"
  # A PEP 668 marker would reject even a user-site install. The skill's documented
  # commands all invoke a bare `python3`, so keep the deps on that interpreter
  # rather than hiding them in a virtualenv the agent's shells would not activate.
  if [ -f "$("$PYTHON" -c 'import sysconfig; print(sysconfig.get_path("stdlib"))')/EXTERNALLY-MANAGED" ]; then
    PIP_FLAGS+=(--break-system-packages)
    echo "Interpreter is externally managed (PEP 668); installing to the user site anyway."
  fi
else
  echo "Target: $("$PYTHON" -c 'import sysconfig; print(sysconfig.get_path("purelib"))')"
fi
"$PYTHON" -m pip install --disable-pip-version-check "${PIP_FLAGS[@]+"${PIP_FLAGS[@]}"}" -r "$REQUIREMENTS"

log "Preparing the working folder"
mkdir -p "$REPO_ROOT/projects"
# The skill derives its projects root as <skill dir>/../../projects, which points
# inside .cursor/ from this vendored location. Link it to the repo-root working
# folder so decks land there instead, without editing the skill.
DERIVED_PROJECTS="$SKILL_DIR/../../projects"
if [ -L "$DERIVED_PROJECTS" ]; then
  echo "Working-folder link already in place."
elif [ -d "$DERIVED_PROJECTS" ]; then
  echo "warning: $DERIVED_PROJECTS is a real directory; leaving it alone." >&2
  echo "         Move its contents into $REPO_ROOT/projects and delete it to use the repo-root working folder." >&2
else
  ln -s ../projects "$DERIVED_PROJECTS"
  echo "Linked $DERIVED_PROJECTS -> $REPO_ROOT/projects"
fi
if [ ! -f "$REPO_ROOT/.env" ] && [ -f "$SKILL_DIR/.env.example" ]; then
  cp "$SKILL_DIR/.env.example" "$REPO_ROOT/.env"
  echo "Created .env from the skill's template. All keys are optional and commented out."
else
  echo ".env already present or no template to copy; leaving it untouched."
fi

log "Verifying the installed dependencies"
"$PYTHON" - <<'PY'
import importlib, sys

# requirement name -> imported module
modules = {
    "PyYAML": "yaml",
    "python-pptx": "pptx",
    "XlsxWriter": "xlsxwriter",
    "skia-pathops": "pathops",
    "uharfbuzz": "uharfbuzz",
    "edge-tts": "edge_tts",
    "PyMuPDF": "fitz",
    "mammoth": "mammoth",
    "markdownify": "markdownify",
    "ebooklib": "ebooklib",
    "nbconvert": "nbconvert",
    "openpyxl": "openpyxl",
    "Pillow": "PIL",
    "numpy": "numpy",
    "requests": "requests",
    "beautifulsoup4": "bs4",
    "curl_cffi": "curl_cffi",
    "google-genai": "google.genai",
    "flask": "flask",
}

failed = []
for requirement, module in modules.items():
    try:
        importlib.import_module(module)
    except Exception as error:
        failed.append(f"  {requirement} (import {module}): {error}")

if failed:
    print(f"error: {len(failed)} of {len(modules)} dependencies failed to import:", file=sys.stderr)
    print("\n".join(failed), file=sys.stderr)
    sys.exit(1)
print(f"All {len(modules)} dependencies import cleanly.")
PY

log "Running the skill's integrity gate"
"$PYTHON" "$SKILL_DIR/scripts/attribution_guard.py"
echo "Integrity gate passed."

log "PPT Master is ready"
echo "Skill:          $SKILL_DIR"
echo "Working folder: $REPO_ROOT/projects"
