#!/bin/bash

# Hole den absoluten Pfad des Skript-Verzeichnisses
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Aktiviere die virtuelle Umgebung
source "$SCRIPT_DIR/venv/bin/activate"

# Setze den PYTHONPATH
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

# Führe das Python-Skript aus
python3 "$SCRIPT_DIR/src/llm4rpi.py"