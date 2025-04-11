import os
import tempfile
import subprocess
import shutil
import uuid
import logging
import re
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException, BackgroundTasks, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import openai
from openai import audio  # 新しい API インターフェース

# .env から環境変数の読み込み
load_dotenv()

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

openai.api_key = ""

app = FastAPI(
    title="Transcription API",
    description="API for transcribing long YouTube videos using OpenAI's Whisper API",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development; in production, specify your app domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],  # For file downloads if needed
)


# レスポンスモデル
class SubtitleEntry(BaseModel):
    start: float
    end: float
    text: str


class TranscribeResponse(BaseModel):
    subtitles: List[SubtitleEntry]
    video_id: str
    status: str
    message: str


# ユーティリティ：YouTube動画IDの抽出
def extract_video_id(url: str) -> str:
    if re.match(r"^[a-zA-Z0-9_-]{11}$", url):
        return url
    youtube_regex = r'(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be/)([^"&?/\s]{11})'
    match = re.search(youtube_regex, url)
    if match:
        return match.group(1)
    raise ValueError(f"Invalid YouTube URL or video ID: {url}")


# ユーティリティ：yt-dlp による音声ダウンロード（WAV 出力）
def download_audio(video_id: str, output_dir: str) -> str:
    unique_id = uuid.uuid4().hex
    output_path = os.path.join(output_dir, f"{unique_id}.wav")
    cmd = [
        "yt-dlp",
        "--force-ipv4",
        "--user-agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/XX.0.0.0 Safari/537.36",
        "--add-header",
        "referer: https://www.youtube.com/",
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
    try:
        result = subprocess.run(
            cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        logger.info(f"yt-dlp stdout: {result.stdout}")
        logger.info(f"yt-dlp stderr: {result.stderr}")
    except subprocess.CalledProcessError as e:
        logger.error(f"yt-dlp error: {e.stderr}")
        raise HTTPException(
            status_code=500, detail=f"Failed to download audio: {str(e)}"
        )
    if os.path.exists(output_path):
        return output_path
    raise FileNotFoundError(f"Downloaded audio file not found in {output_dir}")


# ユーティリティ：ffmpeg による音声ファイルの圧縮変換（16kHz, モノラル, MP3）
def convert_audio_to_16khz_compressed(input_file: str, output_dir: str) -> str:
    """
    入力の WAV ファイルを 16kHz、モノラル、例えば 96kbps の MP3 に変換します。
    MP3 の方がファイルサイズが小さくなり、長時間の動画にも対応しやすくなります。
    """
    filename = os.path.basename(input_file)
    output_file = os.path.join(
        output_dir, f"converted_{os.path.splitext(filename)[0]}.mp3"
    )
    cmd = [
        "ffmpeg",
        "-i",
        input_file,
        "-ar",
        "16000",  # 16kHz に変換
        "-ac",
        "1",  # モノラル
        "-b:a",
        "96k",  # ビットレート 96kbps（必要に応じて調整）
        "-c:a",
        "libmp3lame",
        output_file,
        "-y",  # 上書き
        "-loglevel",
        "error",
    ]
    logger.info(f"Executing command: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)
    return output_file


# ユーティリティ：ffmpeg による音声ファイルの分割（秒単位のチャンクに分割）
def split_audio_file(
    input_file: str, segment_duration: int, output_dir: str
) -> List[str]:
    """
    入力ファイルを segment_duration（秒）ごとに分割し、複数のファイルとして output_dir に出力します。
    MP3 ファイルの場合、-c copy で分割可能ですが、正確な開始タイムスタンプを得るために re-encoding する場合もあります。
    """
    import shlex

    output_pattern = os.path.join(output_dir, "chunk_%03d.mp3")
    cmd = f"ffmpeg -i {shlex.quote(input_file)} -f segment -segment_time {segment_duration} -c copy {shlex.quote(output_pattern)}"
    logger.info(f"Splitting audio file with command: {cmd}")
    subprocess.run(cmd, shell=True, check=True)
    chunks = sorted(
        [
            os.path.join(output_dir, f)
            for f in os.listdir(output_dir)
            if f.startswith("chunk_") and f.endswith(".mp3")
        ]
    )
    return chunks


# ユーティリティ：新しい OpenAI API インターフェースで文字起こし
def transcribe_with_whisper(audio_file: str) -> List[Dict[str, Any]]:
    if not os.path.exists(audio_file) or os.path.getsize(audio_file) == 0:
        raise ValueError(f"Audio file doesn't exist or is empty: {audio_file}")
    logger.info(f"Transcribing audio file: {audio_file}")
    with open(audio_file, "rb") as audio_file_obj:
        response = audio.transcriptions.create(
            model="whisper-1", file=audio_file_obj, response_format="verbose_json"
        )
    # 新API仕様では、response.segments としてチャンクのリストが返ると仮定
    segments = response.segments
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


# 各チャンクに対して文字起こしを呼び出し、オフセットを付与して結果を統合
def transcribe_audio_chunks(
    chunks: List[str], segment_duration: int
) -> List[Dict[str, Any]]:
    all_subtitles = []
    for i, chunk in enumerate(chunks):
        offset = i * segment_duration
        subtitles = transcribe_with_whisper(chunk)
        # オフセットを各チャンクの字幕に加算
        for seg in subtitles:
            seg["start"] += offset
            seg["end"] += offset
        all_subtitles.extend(subtitles)
    return all_subtitles


# 一時ファイルのクリーンアップを行う関数
def cleanup_files(temp_dir: str, audio_file: str = None):
    """一時ファイルとディレクトリを削除する"""
    try:
        logger.info(f"Cleaning up temporary files in {temp_dir}")
        if audio_file and os.path.exists(audio_file):
            os.remove(audio_file)
            logger.info(f"Removed audio file: {audio_file}")
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)
            logger.info(f"Removed temporary directory: {temp_dir}")
    except Exception as e:
        logger.error(f"Error during cleanup: {str(e)}")


# /transcribe エンドポイント
@app.get("/transcribe", response_model=TranscribeResponse)
async def transcribe_youtube_video(
    background_tasks: BackgroundTasks,
    video_url: str = Query(..., description="YouTube URL or video ID"),
):
    try:
        temp_dir = tempfile.mkdtemp()
        video_id = extract_video_id(video_url)
        logger.info(f"Extracted video ID: {video_id}")

        # 音声をダウンロード（WAV形式）
        wav_audio_file = download_audio(video_id, temp_dir)
        logger.info(f"Downloaded WAV audio file: {wav_audio_file}")

        # WAV を圧縮して MP3 に変換（16kHz, モノラル）
        compressed_audio_file = convert_audio_to_16khz_compressed(
            wav_audio_file, temp_dir
        )
        logger.info(f"Converted compressed audio file: {compressed_audio_file}")

        # MP3 ファイルのサイズを確認
        file_size = os.path.getsize(compressed_audio_file)
        logger.info(f"Compressed audio file size: {file_size} bytes")

        # Whisper API の上限は 26MB (26214400 bytes)
        threshold = 26214400
        if file_size > threshold:
            # 長時間・大容量の場合は分割して処理
            # ここでは例として 180 秒ごとに分割（必要に応じて調整）
            segment_duration = 180
            logger.info("Audio file exceeds threshold; splitting into chunks...")
            chunks = split_audio_file(compressed_audio_file, segment_duration, temp_dir)
            logger.info(f"Split into {len(chunks)} chunks.")
            all_subtitles = transcribe_audio_chunks(chunks, segment_duration)
        else:
            # そのままで文字起こし
            all_subtitles = transcribe_with_whisper(compressed_audio_file)

        logger.info(f"Transcription complete: {len(all_subtitles)} segments generated.")
        background_tasks.add_task(lambda: cleanup_files(temp_dir))

        return TranscribeResponse(
            subtitles=all_subtitles,
            video_id=video_id,
            status="success",
            message=f"Transcription complete. {len(all_subtitles)} segments generated.",
        )
    except Exception as e:
        logger.error(f"Error during transcription: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


# 部分的なオーディオダウンロード用の関数
def download_audio_segment(
    video_id: str, output_dir: str, start_seconds: float, duration_seconds: float
) -> str:
    """指定された部分のオーディオだけをダウンロード（より堅牢なバージョン）"""
    unique_id = uuid.uuid4().hex
    output_path = os.path.join(output_dir, f"{unique_id}.wav")
    end_seconds = start_seconds + duration_seconds

    try:
        # 方法1: yt-dlpとffmpegを組み合わせた方法
        try:
            # まずストリームURLを取得
            get_url_cmd = [
                "yt-dlp",
                "-f",
                "bestaudio",
                "-g",
                f"https://www.youtube.com/watch?v={video_id}",
                "--quiet",
            ]

            logger.info(f"Getting stream URL with command: {' '.join(get_url_cmd)}")
            result = subprocess.run(
                get_url_cmd, check=True, stdout=subprocess.PIPE, text=True
            )
            stream_url = result.stdout.strip()

            if not stream_url:
                raise ValueError("Failed to get stream URL")

            # FFmpegで指定された部分だけをダウンロード・変換
            ffmpeg_cmd = [
                "ffmpeg",
                "-ss",
                str(start_seconds),
                "-t",
                str(duration_seconds),
                "-i",
                stream_url,
                "-vn",  # ビデオ無効
                "-acodec",
                "pcm_s16le",  # WAV向けコーデック
                "-ar",
                "16000",  # すでに16kHzに変換
                "-ac",
                "1",  # モノラル
                output_path,
                "-y",  # 上書き
                "-loglevel",
                "warning",  # より詳細なログ
            ]

            logger.info(f"Downloading segment with ffmpeg: {' '.join(ffmpeg_cmd)}")
            subprocess.run(ffmpeg_cmd, check=True)

            if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
                logger.info(
                    f"Successfully downloaded audio segment using ffmpeg: {output_path}"
                )
                return output_path

        except Exception as e:
            logger.warning(f"Method 1 failed, trying backup method: {str(e)}")
            # 失敗した場合は次の方法を試す
            pass

        # 方法2: yt-dlpの --download-sections オプションを使用
        yt_cmd = [
            "yt-dlp",
            f"https://www.youtube.com/watch?v={video_id}",
            "--force-ipv4",
            "--user-agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/XX.0.0.0 Safari/537.36",
            "--add-header",
            "referer: https://www.youtube.com/",
            "--no-playlist",
            "--extract-audio",
            "--audio-format",
            "wav",
            "--audio-quality",
            "0",
            "--output",
            output_path,
            "--quiet",
            "--download-sections",
            f"*{start_seconds:.1f}-{end_seconds:.1f}",
        ]

        logger.info(f"Backup method - executing command: {' '.join(yt_cmd)}")
        subprocess.run(yt_cmd, check=True)

        if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
            logger.info(
                f"Successfully downloaded audio segment using yt-dlp: {output_path}"
            )
            return output_path

        raise FileNotFoundError(
            f"Downloaded audio file not found or empty: {output_path}"
        )

    except subprocess.CalledProcessError as e:
        logger.error(f"Error downloading audio segment: {str(e)}")

        # 最終手段: 全体をダウンロードして切り取る
        try:
            logger.info(
                "Trying final fallback method: download entire audio and cut segment"
            )
            full_audio_path = os.path.join(output_dir, f"full_{unique_id}.wav")

            # 全体をダウンロード
            full_cmd = [
                "yt-dlp",
                f"https://www.youtube.com/watch?v={video_id}",
                "--force-ipv4",
                "--no-playlist",
                "--extract-audio",
                "--audio-format",
                "wav",
                "--audio-quality",
                "0",
                "--output",
                full_audio_path,
                "--quiet",
            ]

            logger.info(f"Downloading full audio: {' '.join(full_cmd)}")
            subprocess.run(full_cmd, check=True)

            if not os.path.exists(full_audio_path):
                raise FileNotFoundError(f"Full audio download failed")

            # 指定部分を切り出し
            cut_cmd = [
                "ffmpeg",
                "-i",
                full_audio_path,
                "-ss",
                str(start_seconds),
                "-t",
                str(duration_seconds),
                "-acodec",
                "pcm_s16le",
                "-ar",
                "16000",
                "-ac",
                "1",
                output_path,
                "-y",
                "-loglevel",
                "warning",
            ]

            logger.info(f"Cutting segment: {' '.join(cut_cmd)}")
            subprocess.run(cut_cmd, check=True)

            # 元ファイルを削除
            os.remove(full_audio_path)

            if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
                logger.info(
                    f"Successfully cut audio segment from full download: {output_path}"
                )
                return output_path

            raise FileNotFoundError("Failed to generate segment from full audio")

        except Exception as fallback_error:
            logger.error(f"All download methods failed: {str(fallback_error)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to download audio segment after multiple attempts: {str(e)}, fallback error: {str(fallback_error)}",
            )


# /transcribe-segment エンドポイント
@app.get("/transcribe-segment")
async def transcribe_video_segment(
    background_tasks: BackgroundTasks,
    video_url: str = Query(..., description="YouTube URL or video ID"),
    start_seconds: float = Query(0, description="開始時間（秒）"),
    duration_seconds: float = Query(30, description="処理する動画の長さ（秒）"),
    translate: bool = Query(False, description="翻訳するかどうか"),
):
    """
    YouTube動画の特定の部分だけを文字起こし
    """
    try:
        # ビデオIDを抽出
        try:
            video_id = extract_video_id(video_url)
            logger.info(f"Extracted video ID: {video_id}")
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

        # 一時ディレクトリを作成
        temp_dir = tempfile.mkdtemp()
        logger.info(f"Created temporary directory: {temp_dir}")

        # 部分的なダウンロードを行う
        audio_file = download_audio_segment(
            video_id, temp_dir, start_seconds, duration_seconds
        )
        logger.info(f"Downloaded audio segment: {audio_file}")

        # オーディオ変換用の関数を直接定義
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

        # オーディオをWhisper用に変換
        converted_audio = convert_audio_to_16khz(audio_file, temp_dir)
        logger.info(f"Converted audio file: {converted_audio}")

        # 文字起こし実行
        subtitles = transcribe_with_whisper(converted_audio)
        logger.info(f"Transcription complete: {len(subtitles)} segments")

        # 開始時間を調整
        for subtitle in subtitles:
            subtitle["start"] += start_seconds
            subtitle["end"] += start_seconds

        # 非同期クリーンアップ
        background_tasks.add_task(cleanup_files, temp_dir, audio_file)

        return {
            "subtitles": subtitles,
            "video_id": video_id,
            "segment_start": start_seconds,
            "segment_duration": duration_seconds,
            "language": "en",
            "status": "success",
            "message": f"部分的な文字起こし完了。{len(subtitles)}個のセグメントを生成。",
        }

    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
