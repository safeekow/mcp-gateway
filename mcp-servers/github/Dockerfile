FROM node:20-slim

RUN apt-get update && apt-get install -y netcat-openbsd \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 8000

# GITHUB_PERSONAL_ACCESS_TOKEN 環境変数は実行時に注入されることを想定
CMD ["sh", "-c", "supergateway --port 8000 --stdio 'npx -y @modelcontextprotocol/server-github'"]
