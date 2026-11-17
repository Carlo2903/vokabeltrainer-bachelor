import os
import tempfile
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from typing import Annotated, Optional

from app.services.whisper_service import transcribe_audio

router = APIRouter()


@router.post("/transcribe")
async def transcribe_endpoint(
    audio: UploadFile = File(...),
    language: Annotated[Optional[str], Form()] = None
):
    """
    Nimmt eine Audiodatei entgegen, transkribiert sie mit Whisper
    und gibt den erkannten Text zurück.
    """

    # Wir prüfen ob wirklich eine Audiodatei geschickt wurde.
    # Die Flutter-App schickt normalerweise audio/wav oder audio/m4a.
    if not audio.content_type.startswith("audio/"):
        raise HTTPException(
            status_code=400,
            detail="Nur Audiodateien sind erlaubt."
        )

    # Whisper braucht eine echte Datei auf der Festplatte, keine
    # Bytes im Speicher. Deshalb speichern wir die Datei kurz
    # als temporäre Datei – sie wird danach automatisch gelöscht.
    suffix = os.path.splitext(audio.filename)[1] or ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await audio.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        result = transcribe_audio(tmp_path, language=language)
    finally:
        # Die temporäre Datei wird in jedem Fall gelöscht –
        # auch wenn Whisper einen Fehler wirft.
        os.remove(tmp_path)

    return result