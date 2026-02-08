#!/bin/bash

set -e

VENV_DIR="$PROJECT_DIR/venv"

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python3" -m pip install polib

# Mark script as having run (for Xcode dependency analysis)
touch "${DERIVED_FILE_DIR}/SetUpPython_done" 2>/dev/null || true
