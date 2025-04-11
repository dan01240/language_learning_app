FROM python:3.9-slim

WORKDIR /app

# システム依存ライブラリのインストール（ffmpegなど）
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
  && rm -rf /var/lib/apt/lists/*

# 依存関係のみを先にコピーしてキャッシュを活用
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Python依存パッケージのインストール
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー（初回用、ホスト側のボリュームマウントで上書きされます）
COPY . .

# ポート公開
EXPOSE 8000

# Uvicornをホットリロードオプション付きで起動
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
