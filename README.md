# 🎙️ KI-Vokabeltrainer: Sprachinteraktion & Gamification

> **Intelligenter, sprachbasierter Vokabeltrainer mit lokaler KI-Pipeline (Whisper & Llama 3.2), reaktivem Gamification-System und Spaced Repetition – entwickelt mit Flutter & FastAPI.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Whisper](https://img.shields.io/badge/STT-faster--whisper-orange)](https://github.com/SYSTRAN/faster-whisper)
[![Ollama](https://img.shields.io/badge/LLM-Ollama%20%2F%20Llama%203.2-black)](https://ollama.ai/)
[![Firebase](https://img.shields.io/badge/Cloud-Firestore%20%26%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)

---

## 📌 Über das Projekt & Entstehungsgeschichte

Dieses Repository entstand im Rahmen meines Informatik-Studiums an der **Fachhochschule Südwestfalen** und gliedert sich in zwei Entwicklungsphasen:

1. **Phase 1 – Basis-App (Teamprojekt):**  
   Im Modul *Mobile Applikationen* wurde im **3er-Team** ein grundlegender Prototyp für einen Karteikarten-Vokabeltrainer mit Flutter und Google Firebase entwickelt.
2. **Phase 2 – KI-Transformation & Gamification (Bachelorarbeit von Carlo Iuliano):**  
   In meiner anschließenden Bachelorarbeit (*„KI-Vokabeltrainer mit Flutter: Integration von Spracherkennung und Gamification“*) habe ich die Anwendung eigenständig zu einer KI-gestützten Sprachlern-Plattform erweitert. Hierbei wurden die gesamte Speech-to-Text-Pipeline, die semantische Auswertung via lokalem LLM, das serverseitige FastAPI-Backend, das reaktive Gamification-Ökosystem und eine qualitative Usability-Studie ($N=6$) konzipiert und implementiert.

---

## ✨ Hauptfunktionen

### 🎙️ 1. KI-Sprachmodus (Active Speech Interaction)
* **Natürliche Aussprache üben:** Nutzer sprechen Vokabeln frei ein, anstatt nur passiv Karteikarten umzudrehen oder Wörter abzutippen.
* **faster-whisper STT:** Lokale Transkription mit automatischer oder gezielter Sprachmodellerkennung (ISO-639-1).
* **Semantische Bewertung (Ollama / Llama 3.2):** Kein starrer Buchstabenausgleich (String-Vergleich / Levenshtein), sondern echtes semantisches Verständnis – Synonyme (z. B. *„comenzar“* statt *„empezar“*) und andere Zeitformen werden intelligent erkannt und bewertet.
* **Fallback-Auswertung:** Hält sich das Modell nicht an das vorgegebene Antwortformat, wird die Antwort über eine einfache Schlagwortprüfung ausgewertet, statt einen Fehler an die App zurückzugeben.

### 🎮 2. Pädagogisches Gamification-System
* **Micro-Paced XP-Engine:** Transparente Punktevergabe mit Dämpfungsfunktion `(correctCount * 10).clamp(5, 500)` abgestimmt auf die Konfigurationsspanne der Lerneinheit (5–50 Wörter), um Binge-Learning zu verhindern.
* **5-Stufen Ligasystem (Single Source of Truth):** Ligen (Bronze, Silber, Gold, Platin, Diamant) werden deterministisch aus den Gesamt-XP berechnet – keine Dateninkonsistenzen bei Netzwerkabbrüchen.
* **Streaks & Badges:** Tägliche Lernserien und freischaltbare Meilensteine mit reaktiven UI-Benachrichtigungen.
* **Spaced Repetition (Leitner-Prinzip):** 3-Stufen-Wiederholungssystem (`training` $\rightarrow$ `review` $\rightarrow$ `mastered`) mit automatischer Rückstufung bei Fehlern in `TrainingService`.

### 🔒 3. Datenschutz & Datensparsamkeit (DSGVO)
* **Zero-Cloud-Audio:** Sprachaufnahmen werden als komprimiertes `.m4a` (AAC-LC) flüchtig im lokalen App-Cache gehalten und per HTTP-Multipart direkt an den lokalen Inferenz-Server gestreamt.
* **Keine Speicherung biometrischer Daten:** Audioaufnahmen werden nach der Transkription verworfen und niemals in Cloud-Speichern (wie Firebase Storage) persistent hinterlegt.

---

## 🏛️ Systemarchitektur

Die Anwendung folgt einer **3-Knoten-Architektur (Client – Server – Cloud)** und trennt UI, Business-Logik und Datenhaltung strikt nach dem **MVVM-Pattern (Model-View-ViewModel)**:

```text
┌─────────────────────────────────┐
│     Smartphone (Flutter UI)     │
│   MVVM • Provider • GoRouter    │
└───────┬─────────────────┬───────┘
        │                 │
  HTTP / REST        Firebase SDK
  (Multipart)             │
        ▼                 ▼
┌─────────────────┐ ┌───────────────────────────┐
│ Local KI-Server │ │       Google Cloud        │
│ Python/FastAPI  │ │  Cloud Firestore (NoSQL)  │
│  Whisper (STT)  │ │  Firebase Authentication  │
│  Ollama (LLM)   │ └───────────────────────────┘
└─────────────────┘
```

### Projektstruktur (`lib/`)

```text
lib/
├── config/       # Zentrale Konfiguration (AppConfig, Endpunkte, Timeouts)
├── models/       # Unveränderliche Datenmodelle (LeagueModel, BadgeModel, Vocabulary)
├── providers/    # State-Management & Business-Logik (GamificationProvider, SessionProvider)
├── services/     # Schnittstellen (BackendService, FirestoreService, TrainingService)
└── ui/           # Screens, Dialoge & Widgets (VoiceLearningScreen, DashboardScreen, MicButton)
```

---

## 🛠️ Tech Stack

| Bereich | Technologie | Verwendung / Zweck |
| :--- | :--- | :--- |
| **Frontend** | **Flutter 3.x / Dart 3.x** | Cross-Platform Client für Android & iOS |
| **State Management** | **Provider (MVVM)** | Reaktive State-Verteilung & lose Kopplung |
| **Backend-API** | **Python 3.10+ / FastAPI** | Asynchrone REST-Endpunkte für Audio- & KI-Inferenz |
| **Spracherkennung** | **faster-whisper (CTranslate2)** | CPU-optimierte STT mit `int8`-Quantisierung |
| **Sprachmodell** | **Ollama / Llama 3.2 (3B)** | Semantische Antwortbewertung & Konjugationen |
| **Persistenz & Auth** | **Google Cloud Firestore** | NoSQL-Dokumentendatenbank & Benutzerverwaltung |
| **Audio I/O** | **record & permission_handler** | AAC-LC / `.m4a` Aufnahme mit nativer Berechtigungsprüfung |

---

## 🧪 Qualitätssicherung & Tests

* **Unit-Tests (Dart Test):** Automatisierte Tests für Kern-Modelle und Grenzwerte (z. B. Randwertanalyse der Ligengrenzen bei exakt 1.000 XP in `test/league_model_test.dart`).
* **Pydantic API-Validierung:** Strikte Typen- und Schemavalidierung in FastAPI. Fehlerhafte Anfragen werden mit `HTTP 422 Unprocessable Entity` abgewiesen, bevor KI-Pipelines ausgeführt werden.
* **Fehlertoleranz & Timeouts:** Strikte Asynchronität (`async/await`) verhindert UI-Freezes. Timeouts (60s Whisper, 30s Chat) fangen Verbindungsabbrüche über getypte `BackendUnreachableException` sauber ab.

---

## 🚀 Installation & Lokales Setup

### 1. Voraussetzungen
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version $\ge$ 3.11.0)
* [Python](https://www.python.org/) (Version $\ge$ 3.10)
* [Ollama](https://ollama.ai/) mit installiertem Llama-3.2-Modell (`ollama pull llama3.2:3b`)
* Ein eingerichtetes [Firebase-Projekt](https://firebase.google.com/) (mit Firestore und Auth)

### 2. Backend starten
```bash
# 1. In das Backend-Verzeichnis wechseln
cd backend

# 2. Virtuelle Umgebung erstellen und aktivieren
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 3. Abhängigkeiten installieren
pip install -r requirements.txt

# 4. FastAPI-Server starten (lauscht auf Port 8000)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Flutter App konfigurieren & ausführen
1. In `lib/config/app_config.dart` die Backend-URL auf deine Rechner-IP anpassen:
   * **Physisches Smartphone:** `http://<DEINE-LOKALE-PC-IP>:8000`
   * **Android-Emulator:** `http://10.0.2.2:8000`
2. Abhängigkeiten laden und App starten:
```bash
flutter pub get
flutter run
```

---

## 👤 Autor

**Carlo Iuliano**  
*Bachelor of Science in Informatik*  
Fachhochschule Südwestfalen  
Projekt: Bachelorarbeit (2026)  
Referent: Prof. Dr. Doga Arinir | Korreferent: Prof. Dr. rer. nat. Uwe Klug
