# LLM4RPI - Lokaler Sprachassistent für Raspberry Pi

Ein sarkastischer Sprachassistent, der komplett lokal auf dem Raspberry Pi läuft und einen KY-038 Soundsensor für die Spracherkennung verwendet.

## Inhaltsverzeichnis
1. [Funktionen](#funktionen)
2. [Hardware-Anforderungen](#hardware-anforderungen)
3. [Projektstruktur](#projektstruktur)
4. [Installation](#installation)
5. [Konfiguration](#konfiguration)
6. [Nutzung](#nutzung)
7. [Fehlerbehebung](#fehlerbehebung)
8. [Entwicklung und Anpassung](#entwicklung-und-anpassung)

## Funktionen
- Vollständig lokale Sprachverarbeitung ohne Internetverbindung
- Sarkastische Antworterzeugung mittels lokalem LLM (Phi-2)
- Spracherkennung über KY-038 Soundsensor
- Automatischer Start beim Systemboot
- Einfache Konfiguration und Anpassung

## Hardware-Anforderungen
- Raspberry Pi 4 (mindestens 4GB RAM empfohlen)
- KY-038 Soundsensor
- Lautsprecher (3.5mm oder USB)
- SD-Karte (mindestens 32GB empfohlen)
- Optional: Gehäuse für Raspberry Pi

### Verkabelung KY-038
```
KY-038 Pin | Raspberry Pi Pin
-----------|----------------
VCC        | 3.3V (Pin 1)
GND        | Ground (Pin 6)
DO         | GPIO17 (Pin 11)
AO         | GPIO27 (Pin 13)
```

## Projektstruktur
```
LLM4RPI/
├── install.sh              # Hauptinstallationsskript
├── setup_llama.sh         # Skript für LLM-Setup
├── start_llm4rpi.sh       # Startskript
├── README.md              # Diese Datei
├── config.json            # LLM-Konfiguration
├── models/
│   └── phi-2-q4_k_m.gguf  # Quantisiertes LLM-Modell
├── src/
│   └── llm4rpi.py        # Hauptprogramm
├── bin/
│   └── ...               # Kompilierte Binaries
├── llama.cpp/            # LLM Backend
└── venv/                 # Python virtuelle Umgebung
```

## Installation

### Voraussetzungen
1. Frische Installation von Raspberry Pi OS (64-bit)
2. Internetverbindung für die Installation
3. Mindestens 10GB freier Speicherplatz

### Installationsschritte
1. Repository klonen:
```bash
git clone https://github.com/yourusername/LLM4RPI.git
cd LLM4RPI
```

2. Installationsskript ausführbar machen und ausführen:
```bash
chmod +x install.sh
sudo ./install.sh
```

3. System neustarten:
```bash
sudo reboot
```

## Konfiguration

### LLM-Konfiguration (config.json)
```json
{
    "model_path": "/path/to/models/phi-2-q4_k_m.gguf",
    "n_ctx": 2048,
    "n_threads": 4,
    "n_gpu_layers": 0
}
```

### Systemd Service
Der Service wird automatisch eingerichtet und startet beim Systemboot. Manuelle Steuerung:
```bash
sudo systemctl start llm4rpi    # Starten
sudo systemctl stop llm4rpi     # Stoppen
sudo systemctl restart llm4rpi  # Neustarten
sudo systemctl status llm4rpi   # Status anzeigen
```

## Nutzung

1. **Hardware anschließen**
   - KY-038 Sensor gemäß Verkabelungsplan anschließen
   - Lautsprecher anschließen
   - Raspberry Pi starten

2. **Spracherkennung**
   - Der Sensor erkennt automatisch, wenn gesprochen wird
   - Eine kurze Aufnahme wird gemacht
   - Die Antwort wird über die Lautsprecher ausgegeben

3. **Log-Dateien einsehen**
```bash
sudo journalctl -u llm4rpi -f
```

## Fehlerbehebung

### Häufige Probleme

1. **GPIO-Fehler**
```bash
# GPIO-Berechtigungen überprüfen
ls -l /dev/gpiomem
# Benutzer zur gpio Gruppe hinzufügen
sudo usermod -a -G gpio $USER
```

2. **Audio-Probleme**
```bash
# Audio-Ausgabegerät testen
speaker-test -t wav
# Standard-Ausgabegerät setzen
raspi-config
```

3. **LLM-Fehler**
```bash
# Modell neu konvertieren
./setup_llama.sh
```

## Entwicklung und Anpassung

### Prompts anpassen
Die Prompts für die Antworterzeugung können in `src/llm4rpi.py` angepasst werden:
```python
prompts = {
    'leise': """Du bist ein sarkastischer Assistent...""",
    'laut': """Du bist ein sarkastischer Assistent...""",
    'normal': """Du bist ein sarkastischer Assistent..."""
}
```

### LLM-Parameter optimieren
In config.json können verschiedene Parameter angepasst werden:
- `n_ctx`: Kontextgröße
- `n_threads`: CPU-Threads
- `temperature`: Kreativität der Antworten

### Hardware-Anpassungen
- GPIO-Pins können in `src/llm4rpi.py` angepasst werden
- Verschiedene Audio-Aufnahmeparameter können justiert werden
