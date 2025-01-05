#!/bin/bash

# Farben für die Ausgabe
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[+] $1${NC}"
}

error() {
    echo -e "${RED}[!] $1${NC}"
}

# Setze Projektpfad
PROJECT_DIR=$(pwd)

# Installiere benötigte Build-Tools
log "Installiere Build-Tools..."
sudo apt-get update
sudo apt-get install -y build-essential cmake git python3-pip python3-dev python3-venv wget aria2

# Aktiviere venv
source ./venv/bin/activate

# Installiere Python-Abhängigkeiten
log "Installiere Python-Abhängigkeiten..."
pip install --upgrade pip
pip install llama-cpp-python
pip install numpy

# Erstelle Models-Verzeichnis
log "Erstelle Models-Verzeichnis..."
mkdir -p models
cd models

# Lade das vorkonvertierte Modell herunter
log "Lade vorkonvertiertes Modell herunter..."
MODEL_URL="https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf"

if [ -f "phi-2-q4_k_m.gguf" ]; then
    log "Modell existiert bereits."
else
    log "Lade Modell herunter..."
    aria2c -x 4 -s 4 --summary-interval=10 ${MODEL_URL} -o phi-2-q4_k_m.gguf
fi

cd "$PROJECT_DIR"

# Überprüfe die Installation
if [ -f "models/phi-2-q4_k_m.gguf" ]; then
    log "Modell wurde erfolgreich heruntergeladen!"
    
    # Setze Berechtigungen
    chmod 644 models/phi-2-q4_k_m.gguf
    
    # Erstelle Modell-Konfig
    log "Erstelle Modell-Konfiguration..."
    cat > config.json << EOL
{
    "model_path": "$PROJECT_DIR/models/phi-2-q4_k_m.gguf",
    "n_ctx": 2048,
    "n_threads": 4,
    "n_gpu_layers": 0
}
EOL
    
    log "Setup abgeschlossen!"
    log "Du kannst den Assistenten nun mit ./start_llm4rpi.sh starten"
else
    error "Fehler beim Download des Modells!"
    exit 1
fi

# Installiere weitere benötigte Pakete
log "Installiere zusätzliche Pakete..."
sudo apt-get install -y espeak python3-espeak

# Teste die Installation
log "Teste die Installation..."
python3 - << EOL
from llama_cpp import Llama
import json

with open('config.json', 'r') as f:
    config = json.load(f)

try:
    llm = Llama(
        model_path=config['model_path'],
        n_ctx=config['n_ctx'],
        n_threads=config['n_threads'],
        n_gpu_layers=config['n_gpu_layers']
    )
    print("LLM wurde erfolgreich geladen!")
except Exception as e:
    print(f"Fehler beim Laden des LLM: {e}")
EOL