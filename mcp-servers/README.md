# MCP サーバー管理設定一式

このフォルダは、各MCPサーバーをDockerコンテナにて起動する為の設定一駅を纏めています。

なお、MCPサーバがstdioのみサポートされている場合は、SSE通信に変換して利用する必要があります。(IBM ContextForge MCP Gatewayはstdioをサポートしていないため)

## フォルダ構成

```text
.
├── mcp-server1/
│   └── Dockerfile
├── mcp-server2/
│   └── Dockerfile
├── docker-compose.yml
└── Dockerfile.custum
```

Dockerfile.customファイルは、stdioでやりとりするMCPサーバの通信をSSEに変換するためのテンプレートをなります。

各MCPサーバのフォルダにコピーして、中身を修正して利用してください。
