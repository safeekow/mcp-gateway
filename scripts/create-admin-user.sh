#!/bin/bash
#
# IBM ContextForge MCP Gateway - 初期管理者ユーザー作成スクリプト
#
# このスクリプトは、データベース(PostgreSQL)に初期管理者ユーザーを作成します。
# 使用方法: ./scripts/create-admin-user.sh [email] [password] [full_name]
#

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルパー関数
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️ ${NC}$1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# 使用方法を表示
usage() {
    cat << EOF
使用方法: $0 [OPTIONS]

IBM ContextForge MCP Gateway の初期管理者ユーザーを作成します。

オプション:
    -e, --email EMAIL           管理者のメールアドレス（必須）
    -p, --password PASSWORD     管理者のパスワード（必須）
    -n, --name NAME            管理者の氏名（デフォルト: Platform Administrator）
    -h, --help                 このヘルプメッセージを表示

例:
    # 対話的にユーザー作成
    $0

    # コマンドライン引数で指定
    $0 -e admin@example.com -p SecureP@ssw0rd -n "Admin User"

    # 環境変数から読み込み
    ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=SecureP@ssw0rd $0

EOF
    exit 0
}

# 引数解析
EMAIL=""
PASSWORD=""
FULL_NAME="Platform Administrator"

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -n|--name)
            FULL_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "不明なオプション: $1"
            usage
            ;;
    esac
done

# 環境変数からの読み込み
EMAIL=${EMAIL:-${ADMIN_EMAIL:-}}
PASSWORD=${PASSWORD:-${ADMIN_PASSWORD:-}}

# 対話的入力
if [ -z "$EMAIL" ]; then
    read -p "管理者のメールアドレス: " EMAIL
fi

if [ -z "$PASSWORD" ]; then
    read -sp "管理者のパスワード: " PASSWORD
    echo
fi

if [ -z "$FULL_NAME" ]; then
    read -p "管理者の氏名 [Platform Administrator]: " FULL_NAME
    FULL_NAME=${FULL_NAME:-"Platform Administrator"}
fi

# バリデーション
if [ -z "$EMAIL" ]; then
    print_error "メールアドレスが指定されていません"
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    print_error "パスワードが指定されていません"
    exit 1
fi

# メールアドレス形式チェック
if ! echo "$EMAIL" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
    print_error "無効なメールアドレス形式です: $EMAIL"
    exit 1
fi

# パスワード強度チェック（本番環境向け）
if [ ${#PASSWORD} -lt 8 ]; then
    print_warning "パスワードは8文字以上を推奨します"
fi

print_info "管理者ユーザーを作成します..."
print_info "メールアドレス: $EMAIL"
print_info "氏名: $FULL_NAME"
echo

# Docker Compose が動作しているか確認
if ! docker-compose ps mcp-gateway >/dev/null 2>&1; then
    print_error "Docker Compose サービスが起動していません"
    print_info "docker-compose up -d を実行してください"
    exit 1
fi

# パスワードハッシュを生成
print_info "パスワードハッシュを生成中..."
PASSWORD_HASH=$(docker-compose exec -T mcp-gateway python3 << PYEOF
try:
    from argon2 import PasswordHasher
    ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=1)
    print(ph.hash("$PASSWORD"))
except ImportError:
    print("ERROR: argon2 module not found")
except Exception as e:
    print(f"ERROR: {e}")
PYEOF
)

if [[ "$PASSWORD_HASH" == "ERROR"* ]] || [ -z "$PASSWORD_HASH" ]; then
    print_error "パスワードハッシュの生成に失敗しました: $PASSWORD_HASH"
    exit 1
fi

PASSWORD_HASH=$(echo "$PASSWORD_HASH" | tr -d '\r\n')
print_success "パスワードハッシュを生成しました"

# データベースにユーザーを挿入
print_info "データベース(PostgreSQL)にユーザーを作成中..."

SQL_QUERY="
INSERT INTO email_users
(email, password_hash, full_name, is_admin, is_active, email_verified_at, auth_provider, password_hash_type, failed_login_attempts, password_change_required, created_at, updated_at)
VALUES
('${EMAIL}', '${PASSWORD_HASH}', '${FULL_NAME}', true, true, NOW(), 'email', 'argon2', 0, false, NOW(), NOW())
ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    full_name = EXCLUDED.full_name,
    is_admin = EXCLUDED.is_admin,
    is_active = EXCLUDED.is_active,
    password_change_required = EXCLUDED.password_change_required,
    updated_at = NOW();

SELECT email, full_name, is_admin, is_active, password_change_required, created_at
FROM email_users
WHERE email = '${EMAIL}';
"

RESULT=$(docker-compose exec -T postgres psql -U postgres -d mcp -c "$SQL_QUERY" 2>&1)

if [ $? -eq 0 ]; then
    print_success "管理者ユーザーを作成しました"
    echo
    echo "$RESULT"
    echo
    print_info "=========================================="
    print_info "ログイン情報"
    print_info "=========================================="
    echo "Email: $EMAIL"
    echo "パスワード: [設定したパスワード]"
    echo
    print_info "ブラウザで http://localhost:4444 にアクセスしてログインしてください"
else
    print_error "ユーザーの作成に失敗しました"
    echo "$RESULT"
    exit 1
fi
