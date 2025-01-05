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
- Start: `sudo systemctl start llm4rpi`
- Stop: `sudo systemctl stop llm4rpi`
- Neustart: `sudo systemctl restart llm4rpi`
- Status: `sudo systemctl status llm4rpi`

## Logs
Logs können mit folgendem Befehl eingesehen werden:
`sudo journalctl -u llm4rpi`
