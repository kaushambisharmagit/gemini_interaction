import fastapi
import google.generativeai as genai
import pathlib
import mimetypes
import nest_asyncio
import uvicorn
import base64
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse

# Configure your Gemini API key
genai.configure(api_key="AIzaSyATPl3zRyQyTaFCqduqhfhoiJIcrg9jrtc")

# Load the Gemini multimodal model
model = genai.GenerativeModel("gemini-2.0-flash")

app = FastAPI()

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or specify your frontend domain for better security
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Supported MIME types for images and audio
SUPPORTED_IMAGE_MIME_TYPES = ["image/png", "image/jpeg", "image/webp", "image/heic", "image/heif"]
SUPPORTED_AUDIO_MIME_TYPES = ["audio/wav", "audio/x-wav", "audio/mpeg", "audio/mp4", "audio/ogg"]

@app.post("/text-image")
async def text_image(text: str = Form(...), image: UploadFile = File(...)):
    print("Received text:", text)
    print("Received image file:", image.filename)

    parts = [text]
    image_data = await image.read()
    print("Image data length:", len(image_data))

    mime_type, _ = mimetypes.guess_type(image.filename)
    if mime_type not in SUPPORTED_IMAGE_MIME_TYPES:
        return JSONResponse(content={"error": f"Unsupported image format: {mime_type}"}, status_code=400)

    encoded_image = base64.b64encode(image_data).decode("utf-8")
    parts.append({
        "mime_type": mime_type,
        "data": encoded_image
    })

    try:
        response = model.generate_content(parts)
        return JSONResponse(content={"response": response.text})
    except Exception as e:
        print("Error:", str(e))
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/text-audio")
async def text_audio(text: str = Form(...), audio: UploadFile = File(...)):
    print("Received text:", text)
    print("Received audio file:", audio.filename)

    parts = [text]
    audio_data = await audio.read()
    print("Audio data length:", len(audio_data))

    mime_type, _ = mimetypes.guess_type(audio.filename)
    if mime_type not in SUPPORTED_AUDIO_MIME_TYPES:
        return JSONResponse(content={"error": f"Unsupported audio format: {mime_type}"}, status_code=400)

    encoded_audio = base64.b64encode(audio_data).decode("utf-8")
    parts.append({
        "mime_type": mime_type,
        "data": encoded_audio
    })

    try:
        response = model.generate_content(parts)
        return JSONResponse(content={"response": response.text})
    except Exception as e:
        print("Error:", str(e))
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/audio-only")
async def audio_only(audio: UploadFile = File(...)):
    print("Received audio file:", audio.filename)

    parts = []
    audio_data = await audio.read()
    print("Audio data length:", len(audio_data))

    mime_type, _ = mimetypes.guess_type(audio.filename)
    if mime_type not in SUPPORTED_AUDIO_MIME_TYPES:
        return JSONResponse(content={"error": f"Unsupported audio format: {mime_type}"}, status_code=400)

    encoded_audio = base64.b64encode(audio_data).decode("utf-8")
    parts.append({
        "mime_type": mime_type,
        "data": encoded_audio
    })

    try:
        response = model.generate_content(parts)
        return JSONResponse(content={"response": response.text})
    except Exception as e:
        print("Error:", str(e))
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/")
def read_root():
    return {"message": "FastAPI server is running!"}

# Fix for running inside Jupyter or Colab
nest_asyncio.apply()

if __name__ == "__main__":
    import os
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
