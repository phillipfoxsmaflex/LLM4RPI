#!/bin/bash

# Installationsskript für den Sarkastischen Sprachassistenten
# Führe dieses Skript als root aus: sudo bash install.sh

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "${GREEN}[+] $1${NC}"
}

error() {
    echo -e "${RED}[!] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[*] $1${NC}"
}

# Prüfe Root-Rechte
if [ "$EUID" -ne 0 ]; then
    error "Dieses Skript muss als root ausgeführt werden!"
    exit 1
fi

# Erstelle Verzeichnisstruktur
log "Erstelle Verzeichnisse..."
PROJECT_DIR="/opt/sarcastic-assistant"
mkdir -p $PROJECT_DIR
mkdir -p $PROJECT_DIR/models
mkdir -p $PROJECT_DIR/src

# System-Pakete aktualisieren und installieren
log "Aktualisiere System-Pakete..."
apt-get update
apt-get upgrade -y

log "Installiere benötigte System-Pakete..."
apt-get install -y \
    python3-pip \
    python3-venv \
    espeak \
    portaudio19-dev \
    git \
    cmake \
    build-essential \
    gcc \
    g++ \
    python3-dev \
    libopenblas-dev \
    libjpeg-dev \
    zlib1g-dev

# Python virtual environment erstellen
log "Erstelle Python virtual environment..."
python3 -m venv $PROJECT_DIR/venv
source $PROJECT_DIR/venv/bin/activate

# Python-Pakete installieren
log "Installiere Python-Pakete..."
pip install --upgrade pip
pip install wheel
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cp39
pip install faster-whisper
pip install sounddevice
pip install pygame
pip install pyaudio
pip install numpy
pip install llama-cpp-python
pip install pvporcupine

# llama.cpp kompilieren
log "Kompiliere llama.cpp..."
cd $PROJECT_DIR
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j4
cp main $PROJECT_DIR/bin/
cd ..

# Lade Modelle herunter
log "Lade Modelle herunter..."

# Phi-2 Modell
log "Lade Phi-2 Modell..."
cd $PROJECT_DIR/models
git clone https://huggingface.co/microsoft/phi-2
cd phi-2

# Konvertiere zu GGUF
log "Konvertiere Phi-2 zu GGUF Format..."
python3 $PROJECT_DIR/llama.cpp/convert.py .
$PROJECT_DIR/llama.cpp/quantize phi-2.gguf phi-2-q4_k_m.gguf q4_k_m

# Whisper Modell (wird automatisch beim ersten Start heruntergeladen)
warning "Das Whisper Modell wird beim ersten Start heruntergeladen."

# Kopiere den Assistenten-Code
log "Kopiere Assistenten-Code..."
cat > $PROJECT_DIR/src/assistant.py << 'EOL'
# Hier kommt der Code aus dem vorherigen Artifact
EOL

# Erstelle Startup-Script
log "Erstelle Startup-Script..."
cat > $PROJECT_DIR/start_assistant.sh << 'EOL'
#!/bin/bash
source /opt/sarcastic-assistant/venv/bin/activate
python3 /opt/sarcastic-assistant/src/assistant.py
EOL

chmod +x $PROJECT_DIR/start_assistant.sh

# Erstelle Systemd Service
log "Erstelle Systemd Service..."
cat > /etc/systemd/system/sarcastic-assistant.service << EOL
[Unit]
Description=Sarcastic Voice Assistant
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/sarcastic-assistant
ExecStart=/opt/sarcastic-assistant/start_assistant.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# Setze Berechtigungen
log "Setze Berechtigungen..."
chown -R pi:pi $PROJECT_DIR
chmod -R 755 $PROJECT_DIR

# Aktiviere und starte den Service
log "Aktiviere Systemd Service..."
systemctl daemon-reload
systemctl enable sarcastic-assistant
systemctl start sarcastic-assistant

# Cleanup
log "Räume auf..."
apt-get autoremove -y
apt-get clean

log "Installation abgeschlossen!"
log "Der Assistent wurde als Systemd-Service eingerichtet und startet automatisch beim Booten."
log "Befehle zur Steuerung des Assistenten:"
echo "  systemctl start sarcastic-assistant   # Starten"
echo "  systemctl stop sarcastic-assistant    # Stoppen"
echo "  systemctl restart sarcastic-assistant # Neustarten"
echo "  systemctl status sarcastic-assistant  # Status anzeigen"
echo ""
warning "Bitte den Raspberry Pi nun neustarten mit: sudo reboot"
