import torch
import numpy as np
import pygame
from espeak import espeak
import RPi.GPIO as GPIO
import time
from llama_cpp import Llama
import random
import audioop
import wave
import struct

class LocalLLMAssistant:
    def __init__(self):
        # GPIO Setup für KY-038
        self.SOUND_PIN_DIGITAL = 17  # GPIO Pin für digitales Signal
        self.SOUND_PIN_ANALOG = 27   # GPIO Pin für analoges Signal
        self.setup_gpio()
        
        # Audio Aufnahme Konfiguration
        self.CHUNK = 1024
        self.FORMAT = 8  # 8-bit aufnahme
        self.CHANNELS = 1
        self.RATE = 44100
        self.THRESHOLD = 100  # Schwellenwert für Geräuscherkennung
        
        # Initialisiere das lokale LLM (Phi-2)
        self.llm = Llama(
            model_path="models/phi-2.gguf",
            n_ctx=2048,
            n_threads=4,
            n_gpu_layers=0
        )
        
        # Konfiguriere eSpeak
        espeak.set_voice("de")
        espeak.set_parameter(espeak.Parameter.Rate, 150)
        espeak.set_parameter(espeak.Parameter.Pitch, 50)
        
        # Initialisiere Audio Output
        pygame.mixer.init()
        
    def setup_gpio(self):
        """Initialisiert die GPIO Pins"""
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.SOUND_PIN_DIGITAL, GPIO.IN)
        GPIO.setup(self.SOUND_PIN_ANALOG, GPIO.IN)
        
    def record_audio(self, duration=5):
        """Nimmt Audio vom KY-038 Modul auf"""
        print("Aufnahme läuft...")
        frames = []
        start_time = time.time()
        
        # Erstelle Wellenform-Array für die Aufnahme
        while time.time() - start_time < duration:
            # Lese analoges Signal
            analog_value = GPIO.input(self.SOUND_PIN_ANALOG)
            
            # Konvertiere zu 8-bit Audio Sample
            sample = struct.pack('B', min(255, max(0, int(analog_value * 255))))
            frames.append(sample)
            
            time.sleep(1.0 / self.RATE)  # Timing für Sample Rate
        
        # Speichere Audio in WAV-Datei
        with wave.open('temp_recording.wav', 'wb') as wf:
            wf.setnchannels(self.CHANNELS)
            wf.setsampwidth(1)  # 8-bit
            wf.setframerate(self.RATE)
            wf.writeframes(b''.join(frames))
        
        return frames
    
    def detect_speech(self):
        """Erkennt, ob gesprochen wird"""
        # Lese digitales Signal vom Sensor
        return GPIO.input(self.SOUND_PIN_DIGITAL) == GPIO.HIGH
    
    def wait_for_speech(self, timeout=10):
        """Wartet auf Spracheingabe"""
        print("Warte auf Sprache...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if self.detect_speech():
                return True
            time.sleep(0.1)
        
        return False
    
    def analyze_audio(self, frames):
        """Analysiert die Audioaufnahme nach Schlüsselwörtern"""
        # Vereinfachte Analyse basierend auf Audiointensität
        rms = audioop.rms(b''.join(frames), 1)  # 1 für 8-bit Audio
        
        # Basierend auf der AudioIntensität verschiedene Antworten generieren
        if rms < 50:
            return "leise_aufnahme"
        elif rms > 200:
            return "laute_aufnahme"
        else:
            return "normale_aufnahme"
    
    def generate_response(self, input_type):
        """Generiert eine sarkastische Antwort basierend auf der Audioanalyse"""
        prompts = {
            'leise_aufnahme': """Du bist ein sarkastischer Assistent. 
                                Die Aufnahme war sehr leise. 
                                Generiere eine kurze, sarkastische Bemerkung darüber.""",
            
            'laute_aufnahme': """Du bist ein sarkastischer Assistent.
                                Die Aufnahme war sehr laut.
                                Generiere eine kurze, sarkastische Bemerkung darüber.""",
            
            'normale_aufnahme': """Du bist ein sarkastischer Assistent.
                                  Generiere eine kurze, sarkastische Bemerkung über
                                  eine durchschnittliche Aufnahme."""
        }
        
        # Generiere Antwort mit dem LLM
        response = self.llm(
            prompts[input_type],
            max_tokens=100,
            temperature=0.7,
            top_p=0.9,
            stop=["\n"],
            echo=False
        )
        
        # Extrahiere die generierte Antwort
        generated_text = response['choices'][0]['text'].strip()
        
        # Füge sarkastischen Präfix hinzu
        prefixes = [
            "Oh, wie wundervoll: ",
            "Nach tiefgründiger Analyse: ",
            "Lass mich dir sagen: "
        ]
        return random.choice(prefixes) + generated_text
    
    def speak_response(self, text):
        """Spricht den Text mit eSpeak"""
        espeak.synth(text)
        while espeak.is_playing():
            time.sleep(0.1)
    
    def run(self):
        """Hauptschleife des Assistenten"""
        print("Assistent gestartet. Warte auf Spracheingabe...")
        
        try:
            while True:
                if self.wait_for_speech():
                    print("Sprache erkannt! Nehme auf...")
                    
                    # Aufnahme und Analyse
                    audio_frames = self.record_audio()
                    input_type = self.analyze_audio(audio_frames)
                    
                    # Generiere und spreche Antwort
                    response = self.generate_response(input_type)
                    print(f"Antwort: {response}")
                    self.speak_response(response)
                    
                    # Kurze Pause vor der nächsten Aufnahme
                    time.sleep(1)
                    
        except KeyboardInterrupt:
            print("Beende Programm...")
        finally:
            GPIO.cleanup()

if __name__ == "__main__":
    assistant = LocalLLMAssistant()
    assistant.run()
