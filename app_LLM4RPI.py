import torch
import torchaudio
from faster_whisper import WhisperModel
import numpy as np
import sounddevice as sd
import pygame
from espeak import espeak
import pvporcupine
import struct
import pyaudio
import os
from llama_cpp import Llama
import random

class LocalLLMAssistant:
    def __init__(self):
        # Initialisiere Whisper für Spracherkennung
        self.whisper = WhisperModel("tiny", device="cpu", compute_type="int8")
        
        # Initialisiere das lokale LLM (Phi-2)
        self.llm = Llama(
            model_path="models/phi-2.gguf",  # Pfad zur quantisierten Modell-Datei
            n_ctx=2048,                      # Kontextfenster
            n_threads=4,                     # Anzahl der Threads (an Pi anpassen)
            n_gpu_layers=0                   # Keine GPU-Beschleunigung auf dem Pi
        )
        
        # Sarkastische Prompts für verschiedene Situationen
        self.prompt_templates = {
            'default': """Du bist ein sarkastischer Assistent. 
                         Beantworte die folgende Frage mit Humor und Sarkasmus, 
                         aber bleibe dabei informativ. 
                         Halte die Antwort kurz (max. 2 Sätze).
                         Frage: {input}
                         Sarkastische Antwort:""",
            
            'nicht_verstanden': """Du bist ein sarkastischer Assistent.
                                  Die Spracheingabe war nicht verständlich.
                                  Generiere eine kurze, sarkastische Bemerkung darüber.
                                  Sarkastische Antwort:"""
        }
        
        # Initialisiere Wake Word Detection
        self.porcupine = pvporcupine.create(
            access_key='DEIN_PORCUPINE_ACCESS_KEY',
            keywords=['computer'],
            model_path='path/to/offline/porcupine_model'
        )
        
        # Audio Stream Setup
        self.audio = pyaudio.PyAudio()
        self.audio_stream = self.audio.open(
            rate=self.porcupine.sample_rate,
            channels=1,
            format=pyaudio.paInt16,
            input=True,
            frames_per_buffer=self.porcupine.frame_length
        )
        
        # Initialisiere Audio
        pygame.mixer.init()
        
        # Konfiguriere eSpeak
        espeak.set_voice("de")
        espeak.set_parameter(espeak.Parameter.Rate, 150)
        espeak.set_parameter(espeak.Parameter.Pitch, 50)
        
    def record_audio(self, duration=5, sample_rate=16000):
        """Nimmt Audio für eine bestimmte Dauer auf"""
        print("Aufnahme läuft...")
        recording = sd.rec(
            int(duration * sample_rate),
            samplerate=sample_rate,
            channels=1,
            dtype='float32'
        )
        sd.wait()
        return recording
    
    def transcribe_audio(self, audio_array):
        """Konvertiert Audio zu Text mit Whisper"""
        audio_array = audio_array.flatten()
        audio_array = audio_array / np.max(np.abs(audio_array))
        
        segments, _ = self.whisper.transcribe(audio_array, language="de")
        return " ".join([segment.text for segment in segments])
    
    def generate_response(self, input_text):
        """Generiert eine sarkastische Antwort mit dem lokalen LLM"""
        # Wähle Prompt-Template
        if not input_text.strip():
            prompt = self.prompt_templates['nicht_verstanden']
        else:
            prompt = self.prompt_templates['default'].format(input=input_text)
        
        # Generiere Antwort mit dem LLM
        response = self.llm(
            prompt,
            max_tokens=100,
            temperature=0.7,
            top_p=0.9,
            stop=["Frage:", "\n"],
            echo=False
        )
        
        # Extrahiere die generierte Antwort
        generated_text = response['choices'][0]['text'].strip()
        
        # Füge zufälligen sarkastischen Präfix hinzu
        prefixes = [
            "Oh, wie überaus brillant von dir zu fragen: ",
            "Nach intensiver Berechnung von ganzen 0.1 Sekunden: ",
            "Wahnsinnig kreative Frage! Hier kommt die offensichtliche Antwort: "
        ]
        return random.choice(prefixes) + generated_text
    
    def speak_response(self, text):
        """Spricht den Text mit eSpeak"""
        espeak.synth(text)
        
    def listen_for_wake_word(self):
        """Horcht auf das Wake Word"""
        pcm = self.audio_stream.read(self.porcupine.frame_length)
        pcm = struct.unpack_from("h" * self.porcupine.frame_length, pcm)
        
        keyword_index = self.porcupine.process(pcm)
        return keyword_index >= 0
    
    def run(self):
        """Hauptschleife des Assistenten"""
        print("Assistent gestartet. Warte auf Wake Word...")
        
        try:
            while True:
                if self.listen_for_wake_word():
                    print("Wake Word erkannt! Höre zu...")
                    
                    # Aufnahme und Transkription
                    audio = self.record_audio()
                    text = self.transcribe_audio(audio)
                    print(f"Erkannter Text: {text}")
                    
                    # Generiere und spreche Antwort
                    response = self.generate_response(text)
                    print(f"Antwort: {response}")
                    self.speak_response(response)
                        
        except KeyboardInterrupt:
            print("Beende Programm...")
        finally:
            self.audio_stream.close()
            self.audio.terminate()
            self.porcupine.delete()

if __name__ == "__main__":
    assistant = LocalLLMAssistant()
    assistant.run()
