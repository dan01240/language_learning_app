# main.py
import os
import tempfile
import subprocess
import shutil
from typing import Optional, Dict, Any, List
import uuid
import logging
from fastapi import FastAPI, HTTPException, BackgroundTasks, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl
import openai
import re
import json
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize the FastAPI app
app = FastAPI(
    title="Language Learning API",
    description="API for transcribing and translating YouTube videos",
    version="1.0.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load API keys
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    logger.warning("OPENAI_API_KEY is not set. Whisper API will not work.")

# Configure OpenAI client
openai
api_key = OPENAI_API_KEY


# Response models
class SubtitleEntry(BaseModel):
    start: float
    end: float
    text: str
    translation: Optional[str] = None


class TranscribeResponse(BaseModel):
    subtitles: List[SubtitleEntry]
    video_id: str
    language: str
    status: str
    message: Optional[str] = None


# Utility functions
def extract_video_id(url: str) -> str:
    """Extract YouTube video ID from URL or return the ID if already an ID."""
    # Check if it's already a video ID (11 characters)
    if re.match(r"^[a-zA-Z0-9_-]{11}$", url):
        return url

    # Extract from YouTube URL
    youtube_regex = r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})'
    match = re.search(youtube_regex, url)

    if match:
        return match.group(1)

    raise ValueError(f"Invalid YouTube URL or video ID: {url}")


def cleanup_files(temp_dir: str, audio_file: str):
    """Clean up temporary files and directories."""
    logger.info(f"Cleaning up temporary files in {temp_dir}")
    try:
        if os.path.exists(audio_file):
            os.remove(audio_file)
            logger.info(f"Removed temporary audio file: {audio_file}")

        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
            logger.info(f"Removed temporary directory: {temp_dir}")
    except Exception as e:
        logger.error(f"Error during cleanup: {str(e)}")


def download_audio(video_id: str, output_dir: str) -> str:
    """Download audio from YouTube video using yt-dlp."""
    unique_id = uuid.uuid4().hex
    output_path = os.path.join(output_dir, f"{unique_id}.%(ext)s")

    try:
        # Download audio only using yt-dlp
        cmd = [
            "yt-dlp",
            f"https://www.youtube.com/watch?v={video_id}",
            "--no-playlist",
            "--extract-audio",
            "--audio-format",
            "wav",
            "--audio-quality",
            "0",
            "--output",
            output_path,
            "--quiet",
        ]

        logger.info(f"Executing command: {' '.join(cmd)}")
        subprocess.run(cmd, check=True)

        # Find the downloaded file
        for file in os.listdir(output_dir):
            if file.startswith(unique_id) and file.endswith(".wav"):
                return os.path.join(output_dir, file)

        raise FileNotFoundError(f"Downloaded audio file not found in {output_dir}")

    except subprocess.CalledProcessError as e:
        logger.error(f"Error downloading audio: {str(e)}")
        raise HTTPException(
            status_code=500, detail=f"Failed to download audio: {str(e)}"
        )


def convert_audio_to_16khz(input_file: str, output_dir: str) -> str:
    """Convert audio to 16kHz mono WAV format for Whisper API."""
    filename = os.path.basename(input_file)
    output_file = os.path.join(output_dir, f"converted_{filename}")

    try:
        # Convert to 16kHz mono WAV using ffmpeg
        cmd = [
            "ffmpeg",
            "-i",
            input_file,
            "-ar",
            "16000",
            "-ac",
            "1",
            "-c:a",
            "pcm_s16le",
            output_file,
            "-y",  # Overwrite if exists
            "-loglevel",
            "error",
        ]

        logger.info(f"Executing command: {' '.join(cmd)}")
        subprocess.run(cmd, check=True)

        return output_file

    except subprocess.CalledProcessError as e:
        logger.error(f"Error converting audio: {str(e)}")
        raise HTTPException(
            status_code=500, detail=f"Failed to convert audio: {str(e)}"
        )


def transcribe_with_whisper(audio_file: str) -> List[Dict[str, Any]]:
    """Transcribe audio using OpenAI's Whisper API."""
    try:
        # Check if file exists and is not empty
        if not os.path.exists(audio_file) or os.path.getsize(audio_file) == 0:
            raise ValueError(f"Audio file doesn't exist or is empty: {audio_file}")

        logger.info(f"Transcribing audio file: {audio_file}")

        with open(audio_file, "rb") as audio:
            response = openai.Audio.transcribe(
                model="whisper-1", file=audio, response_format="verbose_json"
            )

        # Extract segments with timestamps
        segments = response.get("segments", [])

        # Format the segments as subtitle entries
        subtitles = []
        for segment in segments:
            subtitles.append(
                {
                    "start": segment["start"],
                    "end": segment["end"],
                    "text": segment["text"].strip(),
                }
            )

        return subtitles

    except Exception as e:
        logger.error(f"Error in Whisper transcription: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


# API Endpoint to transcribe YouTube video
@app.get("/transcribe", response_model=TranscribeResponse)
async def transcribe_youtube_video(
    background_tasks: BackgroundTasks,
    video_url: str = Query(..., description="YouTube URL or video ID"),
    translate: bool = Query(
        False, description="Whether to translate subtitles to Japanese"
    ),
):
    """
    Transcribe a YouTube video using Whisper API.

    - Downloads the audio from YouTube using yt-dlp
    - Converts the audio to 16kHz mono WAV using ffmpeg
    - Transcribes the audio using OpenAI's Whisper API
    - Optionally translates the subtitles to Japanese
    - Returns timestamped subtitles
    """
    try:
        # Create a temporary directory
        temp_dir = tempfile.mkdtemp()
        logger.info(f"Created temporary directory: {temp_dir}")

        # Extract video ID
        try:
            video_id = extract_video_id(video_url)
            logger.info(f"Extracted video ID: {video_id}")
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

        # Download audio
        audio_file = download_audio(video_id, temp_dir)
        logger.info(f"Downloaded audio file: {audio_file}")

        # Convert audio to 16kHz mono WAV
        converted_audio = convert_audio_to_16khz(audio_file, temp_dir)
        logger.info(f"Converted audio file: {converted_audio}")

        # Transcribe audio
        subtitles = transcribe_with_whisper(converted_audio)
        logger.info(f"Transcription complete: {len(subtitles)} segments")

        # Schedule cleanup (async)
        background_tasks.add_task(cleanup_files, temp_dir, audio_file)

        # Return response
        return TranscribeResponse(
            subtitles=subtitles,
            video_id=video_id,
            language="en",  # Assuming English for now
            status="success",
            message=f"Transcription complete. {len(subtitles)} subtitle segments generated.",
        )

    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "message": "API is running"}


# Run the server (for development)
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
