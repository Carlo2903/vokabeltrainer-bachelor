import re

from faster_whisper import WhisperModel # type: ignore

# Das Modell wird einmal beim Import geladen und bleibt im Speicher.
# "small" ist ein guter Kompromiss: schnell genug für Echtzeit, 
_model = WhisperModel("small", device="cpu", compute_type="int8")


def transcribe_audio(audio_path: str, language: str = None) -> dict:
    """
    Transkribiert eine Audiodatei und gibt den erkannten Text
    sowie die erkannte Sprache zurück.
    """
    segments, info = _model.transcribe(
        audio_path,
        beam_size=5,
        # Sprache explizit angeben verhindert falsche Spracherkennung
        # bei einzelnen Wörtern ohne Kontext
        language=language,
        initial_prompt="Einzelnes Vokabel:"
    )

    # Die Segmente sind ein Generator – wir sammeln den Text
    # aller Segmente und fügen sie zusammen.
    full_text = " ".join([segment.text for segment in segments])

    # Satzzeichen am Ende entfernen die Whisper automatisch hinzufügt
    # z.B. "Abfall!" → "Abfall", "sprechen." → "sprechen"
    cleaned_text = re.sub(r'[^\w\s]$', '', full_text.strip()).strip()

    return {
        "text": cleaned_text        ,
        "language": info.language,
        "language_probability": round(info.language_probability, 2)
    }