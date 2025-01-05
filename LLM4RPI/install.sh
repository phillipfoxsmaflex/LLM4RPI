#!/bin/bash

# Installationsskript für LLM4RPI mit KY-038
# Führe dieses Skript als root aus: sudo bash install.sh

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Setze Projektpfad auf aktuelles Verzeichnis
PROJECT_DIR=$(pwd)
log "Projektpfad: $PROJECT_DIR"

# Erstelle Verzeichnisstruktur
log "Erstelle Verzeichnisse..."
mkdir -p $PROJECT_DIR/models
mkdir -p $PROJECT_DIR/src
mkdir -p $PROJECT_DIR/bin

# System-Pakete aktualisieren und installieren
log "Aktualisiere System-Pakete..."
apt-get update
apt-get upgrade -y

log "Installiere benötigte System-Pakete..."
apt-get install -y \
    python3-pip \
    python3-venv \
    espeak \
    git \
    cmake \
    build-essential \
    gcc \
    g++ \
    python3-dev \
    libopenblas-dev \
    python3-rpi.gpio \
    libasound2-dev

# Python virtual environment erstellen
log "Erstelle Python virtual environment..."
python3 -m venv $PROJECT_DIR/venv --system-site-packages
source $PROJECT_DIR/venv/bin/activate

# Python-Pakete installieren
log "Installiere Python-Pakete..."
pip install --upgrade pip
pip install wheel
pip install RPi.GPIO
pip install pygame
pip install numpy
pip install llama-cpp-python

# llama.cpp kompilieren
log "Kompiliere llama.cpp..."
cd $PROJECT_DIR
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j4
cp main $PROJECT_DIR/bin/
cd $PROJECT_DIR

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
cd $PROJECT_DIR

# GPIO-Konfiguration
log "Konfiguriere GPIO..."
# Aktiviere SPI und I2C wenn nötig
raspi-config nonint do_spi 0
raspi-config nonint do_i2c 0

# Erstelle GPIO-Udev-Regel für Nicht-Root-Zugriff
cat > /etc/udev/rules.d/20-gpiomem.rules << EOL
SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
EOL

# Füge Benutzer zur GPIO-Gruppe hinzu
usermod -a -G gpio pi

# Kopiere den Assistenten-Code
log "Kopiere Assistenten-Code..."
cat > $PROJECT_DIR/src/llm4rpi.py << 'EOL'
# Hier kommt der Code aus dem vorherigen Artifact
EOL

# Erstelle Startup-Script
log "Erstelle Startup-Script..."
cat > $PROJECT_DIR/start_llm4rpi.sh << EOL
#!/bin/bash
source $PROJECT_DIR/venv/bin/activate
python3 $PROJECT_DIR/src/llm4rpi.py
EOL

chmod +x $PROJECT_DIR/start_llm4rpi.sh

# Erstelle Systemd Service
log "Erstelle Systemd Service..."
cat > /etc/systemd/system/llm4rpi.service << EOL
[Unit]
Description=LLM4RPI Voice Assistant
After=network.target

[Service]
Type=simple
User=pi
Group=gpio
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/start_llm4rpi.sh
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
systemctl enable llm4rpi
systemctl start llm4rpi

# Erstelle README.md
cat > $PROJECT_DIR/README.md << EOL
# LLM4RPI

Ein lokaler Sprachassistent für den Raspberry Pi mit KY-038 Soundsensor.

## Installation
Die Installation wurde bereits durch das Installationsskript durchgeführt.

## Hardware-Setup
KY-038 Verkabelung:
1. VCC   → 3.3V (Pin 1)
2. GND   → Ground (Pin 6)
3. DO    → GPIO17 (Pin 11)
4. AO    → GPIO27 (Pin 13)

## Steuerung
Folgende Befehle stehen zur Verfügung:
- Start: \`sudo systemctl start llm4rpi\`
- Stop: \`sudo systemctl stop llm4rpi\`
- Neustart: \`sudo systemctl restart llm4rpi\`
- Status: \`sudo systemctl status llm4rpi\`

## Logs
Logs können mit folgendem Befehl eingesehen werden:
\`sudo journalctl -u llm4rpi\`
EOL

# Cleanup
log "Räume auf..."
apt-get autoremove -y
apt-get clean

# Ausgabe der Verkabelungsanleitung
log "Installation von LLM4RPI abgeschlossen!"
echo ""
warning "KY-038 Verkabelung:"
echo "1. VCC   → 3.3V (Pin 1)"
echo "2. GND   → Ground (Pin 6)"
echo "3. DO    → GPIO17 (Pin 11)"
echo "4. AO    → GPIO27 (Pin 13)"
echo ""
warning "Bitte stelle sicher, dass das KY-038 Modul korrekt angeschlossen ist!"
echo ""
log "Befehle zur Steuerung von LLM4RPI:"
echo "  systemctl start llm4rpi   # Starten"
echo "  systemctl stop llm4rpi    # Stoppen"
echo "  systemctl restart llm4rpi # Neustarten"
echo "  systemctl status llm4rpi  # Status anzeigen"
echo ""
log "Eine README.md wurde im Projektverzeichnis erstellt."
warning "Bitte den Raspberry Pi nun neustarten mit: sudo reboot"