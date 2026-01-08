FROM node:22.12-alpine

# 必要なパッケージ（curl含む）のインストール
RUN apk add --no-cache curl \
    && npm install -g @modelcontextprotocol/server-sequential-thinking supergateway

# ポート8000を開放
EXPOSE 8000

# supergatewayを経由して起動
CMD ["supergateway", "--port", "8000", "--stdio", "mcp-server-sequential-thinking"]
