from fastapi import FastAPI # type: ignore
from app.routes import transcribe, chat

app = FastAPI(
    title="KI-Vokabeltrainer Backend",
    description="Backend für Whisper-Spracherkennung und Ollama-Integration",
    version="1.0.0"
)

app.include_router(transcribe.router, prefix="/api")
app.include_router(chat.router, prefix="/api")

@app.get("/health")
def health_check():
    return {"status": "ok"}