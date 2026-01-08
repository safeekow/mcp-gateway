FROM node:20-slim

# 必要なパッケージ
RUN apt-get update && apt-get install -y git netcat-openbsd \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# リポジトリをクローン
# src/memory ディレクトリで依存関係をインストールしてビルド
RUN git clone https://github.com/modelcontextprotocol/servers.git . \
    && cd src/memory \
    && npm install \
    && npm run build

EXPOSE 8000

# 実行コマンド
# ビルドされた dist/index.js を node で実行
CMD ["supergateway", "--port", "8000", "--stdio", "node /app/src/memory/dist/index.js"]

