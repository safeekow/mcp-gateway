# 1. Dart 公式イメージをベースに使用
FROM dart:stable

# 2. Node.js と supergateway のインストール
#    supergateway は stdio 通信を HTTP に変換するために必要です
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    netcat-openbsd \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY wrapper.js .

# 3. ポート開放
EXPOSE 8000

# 4. 実行コマンド
#    supergateway を経由して dart mcp-server を実行します
CMD ["sh", "-c", "echo 'Starting Dart server...' && supergateway --port 8000 --stdio 'node wrapper.js dart mcp-server --force-roots-fallback'"]
