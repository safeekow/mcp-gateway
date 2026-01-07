FROM node:22.12-alpine

# 必要なパッケージのインストール
RUN npm install -g @modelcontextprotocol/server-sequential-thinking supergateway

# ポート8000を開放
EXPOSE 8000

# supergatewayを経由して起動（これでHTTPアクセス可能になります）
# --stdio 引数に元の実行コマンドを指定します
CMD ["npx", "supergateway", "--port", "8000", "--stdio", "npx @modelcontextprotocol/server-sequential-thinking"]
