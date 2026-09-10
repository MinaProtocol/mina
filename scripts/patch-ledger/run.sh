#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

VENV_DIR="$SCRIPT_DIR/.venv"
if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt"
fi

exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/__main__.py" "$@"
