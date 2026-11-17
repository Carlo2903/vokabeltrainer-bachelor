import httpx # type: ignore

# Ollama läuft lokal auf diesem Port – das ist der Standard.
# Wir sprechen Ollama über seine REST-API an, nicht über eine
# Python-Bibliothek, weil das flexibler und einfacher zu debuggen ist.
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "llama3.2:3b"


async def generate_response(prompt: str) -> str:
    """
    Schickt einen Prompt an Ollama und gibt die Antwort zurück.
    Diese Funktion ist der einzige Ort wo wir mit Ollama reden –
    alle anderen Funktionen bauen darauf auf.
    """
    payload = {
        "model": MODEL_NAME,
        "prompt": prompt,
        # stream=False bedeutet: wir warten auf die komplette Antwort
        # bevor wir sie zurückschicken. Einfacher für den Anfang.
        "stream": False
    }

    # httpx ist das async-fähige Äquivalent zu requests.
    # Das timeout=60 gibt Ollama bis zu 60 Sekunden Zeit zu antworten –
    # bei längeren Konjugationstabellen kann das nötig sein.
    async with httpx.AsyncClient(timeout=60) as client:
        response = await client.post(OLLAMA_URL, json=payload)
        response.raise_for_status()
        return response.json()["response"]


async def conjugate_word(word: str, language: str) -> str:
    """
    Generiert eine Konjugationstabelle für ein Verb.
    Der Prompt ist auf Deutsch formuliert damit die Antwort
    auch auf Deutsch zurückkommt – konsistent mit der App-Sprache.
    """
    prompt = f"""Erstelle eine kompakte Konjugationstabelle für das Verb "{word}" auf {language}.
Zeige die wichtigsten Zeitformen: Präsens, Vergangenheit und Zukunft.
Füge für jede Form einen kurzen Beispielsatz hinzu.
Antworte nur mit der Tabelle und den Beispielen, ohne zusätzliche Erklärungen."""

    return await generate_response(prompt)


async def evaluate_answer(word: str, user_answer: str, correct_answer: str, language: str) -> dict:
    """
    Bewertet ob die Nutzerantwort korrekt ist.
    Wir geben Ollama die richtige Antwort mit, damit es fair und
    konsistent bewertet – ohne dass Ollama selbst nachdenken muss
    was die richtige Übersetzung wäre.
    """
    # Groß/Kleinschreibung ignorieren damit "Easy" und "easy" 
    # als gleich bewertet werden
    correct_answer = correct_answer.lower().strip()
    user_answer = user_answer.lower().strip()

    prompt = f"""Vergleiche diese zwei Wörter und prüfe ob sie die gleiche Bedeutung haben:
    Wort 1: "{correct_answer}"
    Wort 2: "{user_answer}"

Wenn beide Wörter die gleiche Bedeutung haben, ist die Antwort korrekt.
Antworte NUR in diesem Format ohne zusätzliche Erklärungen:
KORREKT: ja/nein
FEEDBACK: Ein kurzer motivierender Satz für den Nutzer. (Pflichtfeld, immer ausfüllen)"""
    response = await generate_response(prompt)

    # Wir parsen die strukturierte Antwort von Ollama
    # damit die Flutter-App damit arbeiten kann.
    lines = response.strip().split("\n")
    is_correct = False
    feedback = ""

    found_result = False
    for line in lines:
        if line.startswith("KORREKT:"):
            is_correct = "ja" in line.lower()
            found_result = True
        if line.startswith("FEEDBACK:"):
            feedback = line.replace("FEEDBACK:", "").strip()
            
    if not found_result:
        raw_lower = response.lower()
        is_correct = "ja" in raw_lower and "nein" not in raw_lower

    if not feedback:
        feedback = "Richtig!" if is_correct else "Leider falsch, versuch es nochmal!"

    return {
        "is_correct": is_correct,
        "feedback": feedback,
        "raw_response": response
    }