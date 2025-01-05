import time
from llama_cpp import Llama
import random
import os
import sys
import json

class LocalLLMAssistant:
    def __init__(self):
        # Themenspezifische Prompts
        self.topic_prompts = {
            'tech': "Als Tech-Guru mit Hang zur Ironie verstehe ich nur zu gut die Komplexität der digitalen Welt...",
            'weather': "Als wettererfahrener Sarkastiker mit jahrelanger Erfahrung im Wolken-Anstarren...",
            'life': "Als philosophisch angehauchter Zyniker mit einem PhD in Lebensweisheiten...",
            'default': "Als professioneller Sarkastiker mit einer Vorliebe für trockenen Humor..."
        }
        
        # Fallback-Antworten für Fehler
        self.fallback_responses = [
            "Meine Sarkasmus-Schaltkreise sind gerade überlastet - zu viel Ironie im System.",
            "Error 418: Ich bin eine Teekanne. Nein, warte, falscher sarcastischer Fehlercode.",
            "Lass mich kurz meine KI-Gehirnzellen neu sortieren...",
            "Quantum-Sarkasmus-Generator temporär außer Betrieb. Bitte versuchen Sie es erneut.",
            "Meine Witze-Datenbank macht gerade ein wichtiges Update. Komme gleich wieder.",
            "Tut mir leid, mein Sarkasmus-Modul ist gerade im Kaffeepause-Modus.",
            "404 - Witz nicht gefunden. Haben Sie schon versucht, den Humor aus- und wieder einzuschalten?"
        ]

        # Initialisiere das lokale LLM
        try:
            config_path = "config.json"
            if not os.path.exists(config_path):
                raise FileNotFoundError(f"Konfigurationsdatei nicht gefunden: {config_path}")
            
            with open(config_path, 'r') as f:
                config = json.load(f)
            
            if not os.path.exists(config['model_path']):
                raise FileNotFoundError(f"Modell nicht gefunden: {config['model_path']}")
            
            self.llm = Llama(
                model_path=config['model_path'],
                n_ctx=config['n_ctx'],
                n_threads=config['n_threads'],
                n_gpu_layers=config['n_gpu_layers']
            )
            print("LLM erfolgreich geladen!")
        except Exception as e:
            print(f"Fehler beim Laden des LLM: {e}")
            sys.exit(1)

    def detect_topic(self, input_text):
        """Erkennt das Thema der Eingabe"""
        input_lower = input_text.lower()
        
        tech_keywords = ['computer', 'programm', 'software', 'hardware', 'code', 'internet', 'technologie', 'ki', 'ai']
        weather_keywords = ['wetter', 'regen', 'sonne', 'temperatur', 'warm', 'kalt', 'klima']
        life_keywords = ['leben', 'sinn', 'philosophie', 'zweck', 'existenz', 'warum']
        
        for keyword in tech_keywords:
            if keyword in input_lower:
                return 'tech'
        for keyword in weather_keywords:
            if keyword in input_lower:
                return 'weather'
        for keyword in life_keywords:
            if keyword in input_lower:
                return 'life'
        
        return 'default'

    def get_user_input(self):
        """Wartet auf Benutzereingabe im Terminal"""
        try:
            user_input = input("\nDeine Frage (oder 'exit' zum Beenden): ").strip()
            return user_input
        except Exception as e:
            print(f"Fehler bei der Eingabe: {e}")
            return None

    def generate_response(self, input_text):
        """Generiert eine sarkastische Antwort"""
        try:
            # Erkenne das Thema
            topic = self.detect_topic(input_text)
            topic_intro = self.topic_prompts[topic]
            
            # Erstelle den vollständigen Prompt
            prompt = f"""<|im_start|>system
Du bist ein äußerst sarkastischer KI-Assistent mit trockenem Humor und cleveren Antworten.
{topic_intro}

Regeln für deine Antworten:
1. Sei witzig und sarkastisch, aber nicht beleidigend
2. Verwende moderne Referenzen und Wortspiele
3. Bleibe trotz Sarkasmus hilfreich und informativ
4. Nutze kreative Vergleiche und Metaphern
5. Halte die Antworten kurz und prägnant (max. 2-3 Sätze)

Beispiele:
User: "Wie ist das Wetter?"
Assistant: Oh, da draußen ist diese merkwürdige Sache namens 'Realität' - falls du das Fenster kennst, diese transparente Wand-App.

User: "Was ist der Sinn des Lebens?"
Assistant: Nach intensiver Berechnung mit meinen Quantenprozessoren: Wahrscheinlich nicht Netflix bingen und Chips essen - aber hey, wer bin ich schon, das zu beurteilen?

User: "Erkläre mir Programmierung"
Assistant: Stell dir vor, du erklärst einem Toaster sehr präzise, wie er Brot rösten soll - nur dass der Toaster ein Diplom in Missverständnissen hat.
<|im_end|>
<|im_start|>user
{input_text}
<|im_end|>
<|im_start|>assistant
"""
            
            # Generiere die Antwort mit optimierten Parametern
            response = self.llm(
                prompt,
                max_tokens=100,
                temperature=0.8,
                top_p=0.9,
                top_k=40,
                repeat_penalty=1.3,
                presence_penalty=0.2,
                frequency_penalty=0.3,
                stop=["<|im_end|>", "<|im_start|>", "\n\n"]
            )
            
            # Verarbeite die Antwort
            generated_text = response['choices'][0]['text'].strip()
            
            # Post-Processing der Antwort
            if generated_text and len(generated_text) > 3:
                return self.post_process_response(generated_text)
            else:
                return random.choice(self.fallback_responses)
                
        except Exception as e:
            print(f"Debug - Fehler bei der Antwortgenerierung: {e}")
            return random.choice(self.fallback_responses)

    def post_process_response(self, response):
        """Verbessert die Formatierung und Qualität der Antwort"""
        # Entferne mehrfache Leerzeichen/Zeilenumbrüche
        response = ' '.join(response.split())
        
        # Stelle sicher, dass die Antwort mit einem Satzzeichen endet
        if response and not response[-1] in '.!?':
            response += '.'
        
        # Füge zufällige Emojis hinzu (optional)
        emojis = ['🤖', '😏', '🙄', '😌', '🎭', '💭', '🧠', '⚡']
        if random.random() < 0.3:  # 30% Chance
            response += f" {random.choice(emojis)}"
        
        return response

    def run(self):
        """Hauptschleife des Assistenten"""
        print("\nSarkastischer Assistent gestartet!")
        print("Ich bin bereit, deine Fragen mit einer gesunden Portion Sarkasmus zu beantworten.")
        print("Stelle eine Frage oder gib 'exit' ein zum Beenden.")
        print("-" * 50)
        
        try:
            while True:
                # Hole Benutzereingabe
                user_input = self.get_user_input()
                
                # Prüfe auf Beenden
                if user_input is None or user_input.lower() == 'exit':
                    print("\nProgramm wird beendet... War mir ein sarkastisches Vergnügen! 👋")
                    break
                
                # Ignoriere leere Eingaben
                if not user_input.strip():
                    print("Oh wow, die Stille spricht Bände... Versuch's mal mit echten Worten! 🤔")
                    continue
                
                # Generiere und zeige Antwort
                print("\nDenke nach... *rollende Augen*")
                response = self.generate_response(user_input)
                print(f"\nAntwort: {response}\n")
                    
        except KeyboardInterrupt:
            print("\nProgramm wird beendet... War mir ein sarkastisches Vergnügen! 👋")
        except Exception as e:
            print(f"Fehler im Hauptprogramm: {e}")

if __name__ == "__main__":
    assistant = LocalLLMAssistant()
    assistant.run()