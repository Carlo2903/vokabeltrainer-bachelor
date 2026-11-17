from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.ollama_service import conjugate_word, evaluate_answer

router = APIRouter()


# Pydantic-Modell definiert wie der Request-Body aussehen muss.
# FastAPI prüft das automatisch – schickt die App ein falsches Format,
# bekommt sie sofort eine verständliche Fehlermeldung zurück.
class ChatRequest(BaseModel):
    mode: str          # "conjugation" oder "evaluation"
    word: str          # das Vokabel z.B. "hablar"
    language: str      # z.B. "Spanisch" oder "Deutsch"
    user_answer: str = ""      # nur bei mode="evaluation" nötig
    correct_answer: str = ""   # nur bei mode="evaluation" nötig


@router.post("/chat")
async def chat_endpoint(request: ChatRequest):
    """
    Hauptendpunkt für alle Ollama-Anfragen.
    Der mode-Parameter entscheidet welche Funktion aufgerufen wird.
    """

    if request.mode == "conjugation":
        result = await conjugate_word(request.word, request.language)
        return {"result": result}

    elif request.mode == "evaluation":
        # Bei Bewertung prüfen wir ob alle nötigen Felder vorhanden sind
        if not request.user_answer or not request.correct_answer:
            raise HTTPException(
                status_code=400,
                detail="Für mode='evaluation' werden user_answer und correct_answer benötigt."
            )
        result = await evaluate_answer(
            request.word,
            request.user_answer,
            request.correct_answer,
            request.language
        )
        return result

    else:
        raise HTTPException(
            status_code=400,
            detail=f"Unbekannter mode: '{request.mode}'. Erlaubt sind: 'conjugation', 'evaluation'."
        )