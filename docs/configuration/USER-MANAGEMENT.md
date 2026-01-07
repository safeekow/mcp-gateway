# ユーザー管理ガイド

MCP Context Forge Gateway におけるユーザーの作成、管理、権限設定の完全ガイド

---

## 目次

1. [概要](#概要)
2. [ユーザーの種類](#ユーザーの種類)
3. [初期管理者の作成](#初期管理者の作成)
4. [ユーザーの追加](#ユーザーの追加)
5. [権限管理](#権限管理)
6. [パスワード管理](#パスワード管理)
7. [トラブルシューティング](#トラブルシューティング)

---

## 概要

MCP Context Forge Gateway は、ユーザーベースの認証・認可システムを提供します。ユーザーは以下の情報で管理されます:

- **Email**: ログイン ID として使用（ユニーク）
- **Password**: bcrypt でハッシュ化して保存
- **Full Name**: 表示名
- **Active Status**: アカウントの有効/無効
- **Superuser Status**: 管理者権限の有無

---

## ユーザーの種類

### 管理者（Superuser）

**権限**:
- 全 MCP サーバーへのアクセス
- ユーザーの作成・編集・削除
- システム設定の変更
- 全チーム・組織の管理
- API キーの管理

**用途**:
- システム管理者
- DevOps エンジニア
- プラットフォーム管理

### 一般ユーザー（Regular User）

**権限**:
- 自分に割り当てられた MCP サーバーへのアクセス
- 自分のプロファイル編集
- 自分のパスワード変更
- 所属チームのリソースへのアクセス

**用途**:
- 開発者
- データサイエンティスト
- アプリケーションユーザー

---

## 初期管理者の作成

### 方法 1: 自動作成（推奨）

初回起動時に環境変数から自動的に管理者が作成されます。

#### 手順

**1. 環境変数ファイルの編集**

`.env` ファイルで以下を設定:

```bash
# プラットフォーム管理者設定
PLATFORM_ADMIN_EMAIL=admin@your-domain.com
PLATFORM_ADMIN_PASSWORD=<強力なパスワード>
PLATFORM_ADMIN_FULL_NAME=Platform Administrator
```

**強力なパスワードの生成**:

```bash
# 32文字のランダムパスワード生成
openssl rand -base64 32
```

**2. データベースの初期化**

初回起動の場合:

```bash
docker compose up -d
```

既存データベースをリセットする場合（注意: 全データ削除）:

```bash
# SQLite 版
docker compose down -v
docker compose up -d

# PostgreSQL 版
docker compose -f docker-compose.postgres.yml down -v
docker compose -f docker-compose.postgres.yml up -d
```

**3. 作成確認**

ログで確認:

```bash
docker compose logs | grep -i "admin\|platform\|user"
```

期待される出力:

```
INFO - Creating platform admin user: admin@your-domain.com
INFO - Platform admin user created successfully
```

ログインテスト:

```bash
curl -X POST http://localhost:4444/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@your-domain.com",
    "password": "YourPassword"
  }'
```

成功時のレスポンス:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

---

### 方法 2: データベース直接操作（SQLite のみ）

既存のデータベースに手動でユーザーを追加する場合。

#### 手順

**1. コンテナに入る**

```bash
docker exec -it mcp-gateway /bin/bash
```

**2. パスワードハッシュを生成**

別のターミナルで:

```bash
docker exec -it mcp-gateway python3 -c "
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
print(pwd_context.hash('YourSecurePassword'))
"
```

出力例:

```
$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ
```

このハッシュをコピーします。

**3. SQLite でユーザーを追加**

コンテナ内で:

```bash
sqlite3 /app/data/mcp.db
```

SQL を実行:

```sql
INSERT INTO users (
    email,
    hashed_password,
    full_name,
    is_active,
    is_superuser,
    created_at,
    updated_at
) VALUES (
    'admin@your-domain.com',
    '$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'Platform Administrator',
    1,
    1,
    datetime('now'),
    datetime('now')
);
```

**4. 確認**

```sql
SELECT id, email, full_name, is_active, is_superuser FROM users;
.quit
```

コンテナから退出:

```bash
exit
```

---

## ユーザーの追加

### 方法 1: 管理 UI から追加（推奨）

**1. 管理 UI にログイン**

```
http://localhost:4444
```

**2. ユーザー管理ページに移動**

左メニューの「Users」をクリック

**3. 新規ユーザー作成**

「Add User」ボタンをクリックして以下を入力:

- **Email**: ユーザーのメールアドレス
- **Full Name**: 表示名
- **Password**: 初期パスワード
- **Active**: チェックを入れる（有効化）
- **Superuser**: 管理者権限が必要な場合のみチェック

**4. 保存**

「Save」ボタンをクリック

---

### 方法 2: API から追加

既存の管理者として API 経由でユーザーを作成します。

**1. 管理者トークンを取得**

```bash
curl -X POST http://localhost:4444/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@your-domain.com",
    "password": "YourAdminPassword"
  }'
```

レスポンスから `access_token` をコピー。

**2. 環境変数にトークンを保存**

```bash
export TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**3. 新規ユーザーを作成**

**一般ユーザーの作成**:

```bash
curl -X POST http://localhost:4444/api/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@your-domain.com",
    "full_name": "Regular User",
    "password": "UserPassword123",
    "is_active": true,
    "is_superuser": false
  }'
```

**管理者の作成**:

```bash
curl -X POST http://localhost:4444/api/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin2@your-domain.com",
    "full_name": "Second Administrator",
    "password": "AdminPassword456",
    "is_active": true,
    "is_superuser": true
  }'
```

**4. 作成確認**

```bash
curl -X GET http://localhost:4444/api/users \
  -H "Authorization: Bearer $TOKEN"
```

---

## 権限管理

### ユーザーステータスの変更

**管理者権限の付与**:

```bash
curl -X PATCH http://localhost:4444/api/users/{user_id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "is_superuser": true
  }'
```

**ユーザーの無効化**:

```bash
curl -X PATCH http://localhost:4444/api/users/{user_id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "is_active": false
  }'
```

**ユーザーの有効化**:

```bash
curl -X PATCH http://localhost:4444/api/users/{user_id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "is_active": true
  }'
```

### ユーザー一覧の取得

```bash
# 全ユーザー
curl -X GET http://localhost:4444/api/users \
  -H "Authorization: Bearer $TOKEN"

# 特定ユーザーの詳細
curl -X GET http://localhost:4444/api/users/{user_id} \
  -H "Authorization: Bearer $TOKEN"
```

### ユーザーの削除

```bash
curl -X DELETE http://localhost:4444/api/users/{user_id} \
  -H "Authorization: Bearer $TOKEN"
```

注意: 削除は永続的です。無効化（`is_active: false`）の使用を推奨します。

---

## パスワード管理

### ユーザー自身によるパスワード変更

**1. ログインしてトークンを取得**

```bash
curl -X POST http://localhost:4444/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@your-domain.com",
    "password": "CurrentPassword"
  }'
```

**2. パスワードを変更**

```bash
export USER_TOKEN="<上記で取得したトークン>"

curl -X PUT http://localhost:4444/api/users/me/password \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "current_password": "CurrentPassword",
    "new_password": "NewSecurePassword123"
  }'
```

### 管理者によるパスワードリセット

管理者が他のユーザーのパスワードをリセットする場合:

```bash
curl -X PATCH http://localhost:4444/api/users/{user_id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "password": "NewPassword123"
  }'
```

注意: 現在のパスワードは不要ですが、管理者権限が必要です。

### 管理 UI からのパスワード変更

**1. 管理 UI にログイン**

```
http://localhost:4444
```

**2. プロファイル設定に移動**

右上のユーザーアイコン → 「Settings」または「Profile」

**3. パスワード変更**

「Change Password」セクションで:
- **Current Password**: 現在のパスワード
- **New Password**: 新しいパスワード
- **Confirm Password**: 新しいパスワード（確認）

**4. 保存**

「Update Password」ボタンをクリック

---

## パスワードポリシー

### 推奨要件

- **最小長**: 12 文字以上
- **複雑性**: 大文字・小文字・数字・記号を含む
- **辞書攻撃対策**: 辞書にない単語を使用
- **再利用禁止**: 過去のパスワードを再利用しない

### 強力なパスワードの生成

```bash
# ランダムパスワード生成（32文字）
openssl rand -base64 32

# 別の方法（pwgen 使用）
pwgen -s 32 1

# パスフレーズ形式
openssl rand -base64 16 | tr -d "=+/" | cut -c1-20
```

### セキュリティのベストプラクティス

1. **定期的な変更**: 90 日ごとにパスワードを変更
2. **パスワードマネージャーの使用**: 1Password, Bitwarden などを推奨
3. **多要素認証（MFA）**: 将来のバージョンで対応予定
4. **アクセスログの監視**: 不正ログイン試行の検知

---

## データベーススキーマ

### users テーブル

| カラム名 | 型 | 説明 | 制約 |
|----------|-----|------|------|
| id | INTEGER/SERIAL | プライマリーキー | PRIMARY KEY, AUTO INCREMENT |
| email | VARCHAR | メールアドレス | UNIQUE, NOT NULL |
| hashed_password | VARCHAR | bcrypt ハッシュ化パスワード | NOT NULL |
| full_name | VARCHAR | 表示名 | NOT NULL |
| is_active | BOOLEAN | アクティブフラグ | NOT NULL, DEFAULT true |
| is_superuser | BOOLEAN | 管理者フラグ | NOT NULL, DEFAULT false |
| created_at | DATETIME | 作成日時 | NOT NULL, DEFAULT now() |
| updated_at | DATETIME | 更新日時 | NOT NULL, DEFAULT now() |

### データベース操作

#### SQLite

```bash
# コンテナに入る
docker exec -it mcp-gateway sqlite3 /app/data/mcp.db

# テーブル一覧
.tables

# スキーマ確認
.schema users

# 全ユーザー表示
SELECT * FROM users;

# 管理者のみ表示
SELECT * FROM users WHERE is_superuser = 1;

# アクティブユーザーのみ
SELECT * FROM users WHERE is_active = 1;

# 終了
.quit
```

#### PostgreSQL

```bash
# コンテナに入る
docker compose exec postgres psql -U postgres -d mcp

# テーブル一覧
\dt

# スキーマ確認
\d users

# 全ユーザー表示
SELECT * FROM users;

# 管理者のみ表示
SELECT * FROM users WHERE is_superuser = true;

# アクティブユーザーのみ
SELECT * FROM users WHERE is_active = true;

# 終了
\q
```

---

## トラブルシューティング

### Q1. 管理者ユーザーが自動作成されない

**原因**: データベースに既にユーザーが存在する

**解決策**:

完全リセット（注意: 全データ削除）:

```bash
# SQLite 版
docker compose down -v
docker compose up -d

# PostgreSQL 版
docker compose -f docker-compose.postgres.yml down -v
docker compose -f docker-compose.postgres.yml up -d
```

または、手動で管理者を作成（上記「方法 2: データベース直接操作」を参照）。

---

### Q2. パスワードでログインできない

**確認事項**:

**1. パスワードが正しいか確認**

大文字・小文字を区別します。コピー＆ペーストの際に余分なスペースが入っていないか確認してください。

**2. 環境変数が正しく設定されているか確認**

```bash
grep "PLATFORM_ADMIN" .env
```

**3. ログにエラーがないか確認**

```bash
docker compose logs | grep -i "error\|failed\|authentication"
```

**4. ユーザーがアクティブか確認**

```bash
# SQLite
docker exec -it mcp-gateway sqlite3 /app/data/mcp.db \
  "SELECT email, is_active FROM users;"

# PostgreSQL
docker compose exec postgres psql -U postgres -d mcp \
  -c "SELECT email, is_active FROM users;"
```

**5. パスワードのリセット**

管理者が API 経由でリセット（上記「管理者によるパスワードリセット」を参照）。

---

### Q3. 環境変数を変更しても反映されない

**原因**: 既存ユーザーのパスワードは環境変数では変更されない

環境変数はデータベース初期化時のみ使用されます。既存ユーザーのパスワードを変更するには:

**方法 1: 管理 UI から変更**

管理画面 → Settings → Change Password

**方法 2: API 経由で変更**

```bash
curl -X PUT http://localhost:4444/api/users/me/password \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "current_password": "OldPassword",
    "new_password": "NewPassword123"
  }'
```

**方法 3: データベースをリセット**（全データ削除）

```bash
docker compose down -v
docker compose up -d
```

---

### Q4. ユーザーを削除できない

**確認事項**:

**1. 管理者権限があるか確認**

一般ユーザーは他のユーザーを削除できません。

**2. 自分自身を削除しようとしていないか確認**

現在ログイン中のユーザーは削除できません。別の管理者でログインしてください。

**3. 最後の管理者を削除しようとしていないか確認**

システムには少なくとも 1 人の管理者が必要です。

**解決策**:

削除の代わりに無効化を使用:

```bash
curl -X PATCH http://localhost:4444/api/users/{user_id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "is_active": false
  }'
```

---

### Q5. データベースが見つからない

**確認コマンド**:

```bash
# SQLite: コンテナ内のデータベース確認
docker exec -it mcp-gateway ls -la /app/data/

# ホスト側のボリューム確認
docker volume ls | grep mcp
docker volume inspect <volume_name>

# PostgreSQL: データベース接続確認
docker compose exec postgres pg_isready -U postgres
```

**解決策**:

ボリュームが正しくマウントされているか確認:

```bash
docker compose ps
docker compose logs mcp-gateway
```

---

## セキュリティのベストプラクティス

### 1. 強力なパスワードの使用

```bash
# 最低要件
- 長さ: 12 文字以上
- 大文字・小文字・数字・記号を含む
- 辞書にない単語

# 推奨: ランダム生成
openssl rand -base64 32
```

### 2. 本番環境の設定例

```bash
# .env（本番用）
PLATFORM_ADMIN_EMAIL=admin@your-domain.com
PLATFORM_ADMIN_PASSWORD=<openssl rand -base64 32 の出力>
PLATFORM_ADMIN_FULL_NAME=Platform Administrator

# JWT Secret も変更
JWT_SECRET_KEY=<openssl rand -base64 64 の出力>
```

### 3. 定期的なパスワード変更

- 90 日ごとにパスワード変更を推奨
- 管理 UI または API で変更可能
- パスワードマネージャーの使用を推奨

### 4. アクセスログの監視

```bash
# 不正ログイン試行の監視
docker compose logs | grep -i "login\|authentication\|unauthorized"

# 特定ユーザーのアクセスログ
docker compose logs | grep "user@your-domain.com"
```

### 5. 最小権限の原則

- 必要なユーザーにのみ管理者権限を付与
- 一般ユーザーには必要最小限の権限のみ
- 定期的な権限の見直し

---

## 関連ドキュメント

- [クイックスタート](../QUICKSTART.md) - 初回セットアップ
- [環境変数リファレンス](configuration/ENVIRONMENT-VARIABLES.md) - 環境変数の詳細
- [セキュリティガイド](../SECURITY-GUIDE.md) - セキュリティベストプラクティス
- [トラブルシューティング](operations/TROUBLESHOOTING.md) - 問題解決ガイド

---

## API リファレンス

### 認証

```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password"
}

# レスポンス
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### ユーザー操作

```bash
# ユーザー一覧
GET /api/users
Authorization: Bearer <token>

# ユーザー詳細
GET /api/users/{user_id}
Authorization: Bearer <token>

# ユーザー作成
POST /api/users
Authorization: Bearer <token>
Content-Type: application/json

{
  "email": "newuser@example.com",
  "full_name": "New User",
  "password": "password123",
  "is_active": true,
  "is_superuser": false
}

# ユーザー更新
PATCH /api/users/{user_id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "full_name": "Updated Name",
  "is_active": true
}

# パスワード変更
PUT /api/users/me/password
Authorization: Bearer <token>
Content-Type: application/json

{
  "current_password": "oldpassword",
  "new_password": "newpassword"
}

# ユーザー削除
DELETE /api/users/{user_id}
Authorization: Bearer <token>
```

---

**最終更新**: 2025-10-19
**対象バージョン**: IBM ContextForge MCP Gateway 0.8.0
