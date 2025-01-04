#!/bin/bash

# Installationsskript für LLM4RPI mit KY-038
# Führe dieses Skript als root aus: sudo bash install.sh

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging-Funktionen
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
mkdir -p $PROJECT_DIR/{models,src,bin}

# System-Pakete aktualisieren und installieren
log "Aktualisiere System-Pakete..."
apt-get update
apt-get upgrade -y

log "Installiere benötigte System-Pakete..."
apt-get install -y \
    python3-pip \
    python3-venv \
    python3-dev \
    espeak \
    espeak-data \
    python3-espeak \
    portaudio19-dev \
    git \
    cmake \
    build-essential \
    gcc \
    g++ \
    libopenblas-dev \
    libasound2-dev \
    python3-rpi.gpio \
    pigpio \
    python3-pigpio

# GPIO-Konfiguration
log "Konfiguriere GPIO..."
# Aktiviere Device Tree in config.txt falls nicht vorhanden
if ! grep -q "^device_tree=1" /boot/config.txt; then
    echo "device_tree=1" >> /boot/config.txt
fi

# Setze GPIO Einstellungen
if ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt; then
    echo "dtparam=i2c_arm=on" >> /boot/config.txt
fi
if ! grep -q "^dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" >> /boot/config.txt
fi
if ! grep -q "^dtparam=gpio=on" /boot/config.txt; then
    echo "dtparam=gpio=on" >> /boot/config.txt
fi

# Erstelle udev-Regeln
log "Erstelle udev-Regeln..."
cat > /etc/udev/rules.d/99-gpio.rules << EOL
SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
SUBSYSTEM=="gpio*", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"
EOL

# Python virtual environment erstellen
log "Erstelle Python virtual environment..."
python3 -m venv $PROJECT_DIR/venv --system-site-packages 
source $PROJECT_DIR/venv/bin/activate

# Python-Pakete installieren
log "Installiere Python-Pakete..."
pip install --upgrade pip
pip install wheel

# Installiere PyTorch
log "Installiere PyTorch..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Installiere weitere Python-Pakete
pip install gpiozero
pip install RPi.GPIO
pip install pigpio
pip install pygame
pip install numpy
pip install llama-cpp-python
pip install py-espeak-ng
pip install sentencepiece

# Aktiviere pigpiod Service
log "Aktiviere pigpiod Service..."
systemctl enable pigpiod
systemctl start pigpiod

# Klon und Build llama.cpp mit CMake
log "Klone llama.cpp..."
cd $PROJECT_DIR
if [ -d "llama.cpp" ]; then
    rm -rf llama.cpp
fi

git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Füge das Repository zur safe.directory hinzu
git config --global --add safe.directory "$PROJECT_DIR/llama.cpp"

log "Erstelle Build-Verzeichnis..."
mkdir -p build
cd build

log "Konfiguriere CMake..."
cmake ..

log "Kompiliere llama.cpp..."
cmake --build . --config Release

cd $PROJECT_DIR

# Kopiere den LLM4RPI Python-Code
log "Erstelle Python-Code..."
cat > $PROJECT_DIR/src/llm4rpi.py << 'EOL'
# Hier kommt der komplette Python-Code
# Den Code separat bereitstellen oder aus einer Datei kopieren
EOL

# Erstelle Startup-Script
log "Erstelle Startup-Script..."
cat > $PROJECT_DIR/start_llm4rpi.sh << EOL
#!/bin/bash
# Hole den absoluten Pfad des Skript-Verzeichnisses
SCRIPT_DIR="$PROJECT_DIR"

# Aktiviere die virtuelle Umgebung
source "\$SCRIPT_DIR/venv/bin/activate"

# Setze den PYTHONPATH
export PYTHONPATH="\$SCRIPT_DIR:\$PYTHONPATH"

# Führe das Python-Skript aus
python3 "\$SCRIPT_DIR/src/llm4rpi.py"
EOL

chmod +x $PROJECT_DIR/start_llm4rpi.sh

# Erstelle Systemd Service
log "Erstelle Systemd Service..."
cat > /etc/systemd/system/llm4rpi.service << EOL
[Unit]
Description=LLM4RPI Voice Assistant
After=network.target pigpiod.service

[Service]
Type=simple
User=pi
Group=gpio
WorkingDirectory=$PROJECT_DIR
Environment=PYTHONPATH=$PROJECT_DIR
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

# Erstelle README
log "Erstelle README..."
cat > $PROJECT_DIR/README.md << EOL
# LLM4RPI

Ein lokaler Sprachassistent für den Raspberry Pi mit KY-038 Soundsensor.

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

# Aktiviere und starte den Service
log "Aktiviere Systemd Service..."
systemctl daemon-reload
systemctl enable llm4rpi

# Cleanup
log "Räume auf..."
apt-get autoremove -y
apt-get clean

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
