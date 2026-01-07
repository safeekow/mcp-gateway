# IBM ContextForge MCP Gateway 環境変数リファレンス

IBM ContextForge MCP Gateway は、`.env` ファイルまたはシステム環境変数を通じて柔軟に設定できます。本ドキュメントは、公式ドキュメント（[IBM ContextForge Docs](https://ibm.github.io/mcp-context-forge/#configuration-env-or-env-vars)）に基づいた完全なリファレンスです。

---

## 📋 基本設定 (Core Configuration)

アプリケーションの基本動作とネットワーク接続に関する設定です。

| 変数名 | デフォルト値 | 説明 |
|:---|:---|:---|
| `APP_NAME` | `MCP Gateway` | ゲートウェイおよび OpenAPI ドキュメントのタイトル。 |
| `HOST` | `127.0.0.1` | サーバーがバインドするホストアドレス。Docker 環境では `0.0.0.0` を推奨。 |
| `PORT` | `4444` | サーバーがリスニングするポート番号。 |
| `DATABASE_URL` | `sqlite:///./mcp.db` | SQLAlchemy 接続 URL。SQLite, PostgreSQL などの接続文字列を指定。 |
| `APP_ROOT_PATH` | (空) | リバースプロキシ配下で動作させる場合のサブパスプレフィックス（例: `/gateway`）。 |
| `PROTOCOL_VERSION` | `2025-03-26` | サポートされる MCP プロトコルのバージョン。 |
| `ENVIRONMENT` | `development` | デプロイ環境。`development` または `production`。 |

---

## 🔐 認証とユーザー管理 (Authentication & User Management)

セキュリティ、JWT、およびユーザーアカウントに関する設定です。

### 認証の基本
| 変数名 | デフォルト値 | 説明 |
|:---|:---|:---|
| `AUTH_REQUIRED` | `true` | すべての API ルートで認証を要求するかどうか。 |
| `BASIC_AUTH_USER` | `admin` | HTTP Basic 認証に使用するユーザー名。 |
| `BASIC_AUTH_PASSWORD` | `changeme` | HTTP Basic 認証に使用するパスワード。**必ず変更してください。** |
| `JWT_SECRET_KEY` | `my-test-key` | JWT トークンの署名に使用する秘密鍵。**本番環境では強力なランダム文字列に変更必須。** |
| `JWT_ALGORITHM` | `HS256` | JWT の署名アルゴリズム。 |
| `TOKEN_EXPIRY` | `10080` | 生成された JWT の有効期限（分）。 |

### 初期管理者（ブートストラップ）設定
初回起動時に自動作成される管理者アカウントの情報です。

| 変数名 | デフォルト値 | 説明 |
|:---|:---|:---|
| `PLATFORM_ADMIN_EMAIL` | `admin@example.com` | プラットフォーム管理者のメールアドレス。 |
| `PLATFORM_ADMIN_PASSWORD` | `changeme` | プラットフォーム管理者の初期パスワード。 |
| `PLATFORM_ADMIN_FULL_NAME` | `Platform Administrator` | 管理者の表示名。 |

---

## 🖥️ UI と機能管理 (UI & Feature Management)

管理ダッシュボードと API 機能の有効化設定です。

| 変数名 | デフォルト値 | 説明 |
|:---|:---|:---|
| `MCPGATEWAY_UI_ENABLED` | `false` | ブラウザベースの管理ダッシュボードを有効にするか。 |
| `MCPGATEWAY_ADMIN_API_ENABLED` | `false` | 管理操作用の API エンドポイントを有効にするか。 |
| `MCPGATEWAY_BULK_IMPORT_ENABLED` | `true` | ツールのバルクインポートエンドポイントを有効にするか。 |

---

## 🌐 SSO (Single Sign-On) 設定

GitHub, Google, OIDC プロバイダーを使用した外部認証の設定です。

| 変数名 | デフォルト値 | 説明 |
|:---|:---|:---|
| `SSO_ENABLED` | `false` | SSO 認証全体のマスター切り替え。 |
| `SSO_AUTO_CREATE_USERS` | `true` | SSO 成功時に自動的にローカルユーザーを作成するか。 |
| `SSO_TRUSTED_DOMAINS` | `[]` | 信頼できるメールアドレスドメインのリスト（JSON配列）。 |

### GitHub OAuth
- `SSO_GITHUB_ENABLED`: `false`
- `SSO_GITHUB_CLIENT_ID`: (必須)
- `SSO_GITHUB_CLIENT_SECRET`: (必須)

### Google OAuth
- `SSO_GOOGLE_ENABLED`: `false`
- `SSO_GOOGLE_CLIENT_ID`: (必須)
- `SSO_GOOGLE_CLIENT_SECRET`: (必須)

---

## 🛡️ セキュリティと CORS (Security & CORS)

本番環境での安全な運用のための詳細設定です。

| 変数名 | デフォルト値 | 説明 |
|:---|:---|:---|
| `CORS_ENABLED` | `true` | CORS (Cross-Origin Resource Sharing) を有効にするか。 |
| `APP_DOMAIN` | `localhost` | 本番環境のメインドメイン。 |
| `SECURE_COOKIES` | `true` | `Secure` クッキーフラグを強制するか。 |
| `HSTS_ENABLED` | `true` | HSTS (HTTP Strict Transport Security) ヘッダーを有効にするか。 |
| `SKIP_SSL_VERIFY` | `false` | アップストリームへの TLS 検証をスキップするか（開発用）。 |

---

## 📊 ロギング (Logging)

| 変数名 | デフォルト値 | 説明 |
|:---|:---|:---|
| `LOG_LEVEL` | `INFO` | ログ出力の閾値 (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`)。 |
| `LOG_FORMAT` | `json` | ログの形式 (`json` または `text`)。 |
| `LOG_TO_FILE` | `false` | ファイルへのログ出力を有効にするか。 |

---

## 💡 設定の優先順位

1.  **システム環境変数**: 最優先。
2.  **`.env` ファイル**: プロジェクトルートに配置されたファイルから読み込まれます。
3.  **デフォルト値**: 上記が設定されていない場合に適用されます。

---

**⚠️ 注意事項**: 本番環境では `ENVIRONMENT=production` に設定し、`JWT_SECRET_KEY` や各種パスワードをデフォルト値から必ず変更してください。
