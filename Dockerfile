# MCP Context Forge ARM64 Dockerfile
# PyPI版を使用してARM64ネイティブコンテナをビルド
ARG TARGETARCH

FROM python:3.11-slim-bookworm

# メタデータ
LABEL maintainer="MCP Gateway Team"
LABEL description="IBM MCP Context Forge Gateway"
LABEL version="0.9.0- $TARGETARCH"

RUN echo "$TARGETARCH"

# 環境変数
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore

# 作業ディレクトリ
WORKDIR /app

# システムパッケージのインストール
# sqlite3, libpq-dev (PostgreSQL), gcc (ビルド用) をインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    sqlite3 \
    libpq-dev \
    gcc \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# MCP Context Forge と依存パッケージのインストール
# PostgreSQLアダプタ(psycopg2-binary)を追加
RUN pip install --no-cache-dir \
    mcp-contextforge-gateway \
    redis \
    psycopg2-binary

# データディレクトリの作成
RUN mkdir -p /app/data && \
    chmod 755 /app/data

# 非rootユーザーの作成とsudo設定
RUN useradd -m -u 1000 -s /bin/bash mcpuser && \
    chown -R mcpuser:mcpuser /app && \
    echo "mcpuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/mcpuser && \
    chmod 0440 /etc/sudoers.d/mcpuser

# ユーザー切り替え
USER mcpuser

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
    CMD curl -f http://localhost:4444/health || exit 1

# ポート公開
EXPOSE 4444

COPY --chown=mcpuser:mcpuser mcp-catalog.yml /app/

# Gunicorn起動スクリプト
COPY --chown=mcpuser:mcpuser deployment/docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
