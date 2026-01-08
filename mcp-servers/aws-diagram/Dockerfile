FROM python:3.12-slim-bookworm

# 1. uv のインストール
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

# 2. Node.js と supergateway
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    netcat-openbsd \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. パッケージのインストール (システム環境へ)
RUN uv pip install --system awslabs.aws-diagram-mcp-server

# 4. ポート開放
EXPOSE 8000

# 5. 実行コマンド
#    supergateway を経由して awslabs.aws-diagram-mcp-server を実行
CMD ["supergateway", "--port", "8000", "--stdio", "awslabs.aws-diagram-mcp-server"]

