FROM node:20-slim

# 必要なパッケージのインストール (netcatはヘルスチェック用)
RUN apt-get update && apt-get install -y netcat-openbsd \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ポート開放
EXPOSE 8000

COPY wrapper.js /app/wrapper.js

# 実行コマンド
# supergateway経由でnpxを使って@growi/mcp-serverを起動
CMD ["sh", "-c", "supergateway --port 8000 --stdio 'node /app/wrapper.js npx -y @modelcontextprotocol/server-gitlab'"]
