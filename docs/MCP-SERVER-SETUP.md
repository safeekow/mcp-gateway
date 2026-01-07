# MCP サーバー設定ガイド

IBM ContextForge MCP Gateway への MCP サーバー登録・管理手順。

---

## 概要

MCP サーバーの登録には、以下の2つの方法があります。

1.  **管理 UI (Admin UI)**: ブラウザから直感的に操作（推奨）
2.  **Admin API**: スクリプトや自動化ツールから操作

## 1. 管理 UI での登録

最も簡単で確実な方法です。

1.  **ログイン**: `http://localhost:4444` にアクセスし、管理者アカウントでログインします。
2.  **Servers メニュー**: 左サイドバーから「Servers」を選択します。
3.  **Add Server**: 右上の「Add Server」ボタンをクリックします。
4.  **フォーム入力**:
    *   **Name**: サーバーの識別名（例: `filesystem-server`）
    *   **Description**: 説明（任意）
    *   **Associated Tools/Resources**: 既存のツールやリソースをこのサーバーに紐付けます。
5.  **Save**: 保存します。

---

## 2. API での登録

自動化のために API を使用する場合の手順です。

### 前提: 認証トークンの取得

まず、管理者アカウントでログインして JWT トークンを取得します。

```bash
# トークンを取得して環境変数にセット
export JWT_TOKEN=$(curl -s -X POST http://localhost:4444/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "admin123"}' | sed -E 's/.*"access_token":"([^"]+)".*/\1/')

# 確認
echo $JWT_TOKEN
```

### サーバーの登録

`/admin/servers` エンドポイントに対し、**Form Data (application/x-www-form-urlencoded)** 形式でデータを送信します。

```bash
curl -X POST http://localhost:4444/admin/servers \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "name=my-api-server" \
  -d "description=Created via API"
```

**成功時のレスポンス**:
```json
{"message":"Server created successfully!","success":true}
```

### Gateway (接続先) の登録

外部の MCP サーバー (SSE など) を登録する場合、`Gateway` として登録します。

```bash
curl -X POST http://localhost:4444/admin/gateways \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "name=remote-server" \
  -d "url=http://remote-host:8000/sse" \
  -d "transport=SSE"
```

---

## 注意事項

### stdio (コマンド実行型) サーバーについて

現在のバージョンでは、API 経由で直接 `command` や `args` を指定して `stdio` タイプのサーバーを一撃で登録する機能は制限されています。

`stdio` サーバーを使用したい場合は、以下のいずれかの方法を検討してください：

1.  **mcp-catalog.yml**: 設定ファイルに記述して起動時に読み込ませる（高度な設定）。
2.  **SSE ラッパー**: ローカルの stdio サーバーを SSE サーバーとして公開するラッパーを使用し、それを Gateway として登録する。
3.  **UI**: 管理 UI の将来のアップデートでサポートされる可能性があります。

---

## トラブルシューティング

### 401 Unauthorized
トークンの有効期限が切れているか、間違っています。再度ログインしてトークンを取得してください。

### 422 Unprocessable Entity
送信したデータ形式が間違っています。API は JSON ではなく **Form Data** を期待していることに注意してください。また、必須フィールド (`name` など) が不足していないか確認してください。

```