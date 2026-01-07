#!/bin/bash
#
# IBM ContextForge MCP Gateway - SQLite to PostgreSQL 移行スクリプト
#
# このスクリプトは、環境を再起動し、SQLiteデータをPostgreSQLに移行します。
#

set -e

# 環境変数の強制上書き (ユーザー環境のDATABASE_URLによる意図しないSQLite接続を防止)
export DATABASE_URL="postgresql://postgres:postgres@postgres:5432/mcp"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️ ${NC}$1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

echo
print_info "================================================"
print_info "SQLite から PostgreSQL へのデータ移行を開始します"
print_info "================================================"
echo

# 確認
print_warning "⚠️  Dockerサービスが再起動されます。"
print_warning "⚠️  既存のSQLiteデータ(/app/data/mcp.db)が読み込まれます。"
print_warning "⚠️  移行前に ./scripts/backup.sh を実行することを強く推奨します。"
echo
read -p "続行しますか？ (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    print_info "キャンセルしました。"
    exit 0
fi

# 1. サービス再起動
print_info "サービスを再起動してPostgreSQL環境を準備中..."
docker-compose down
docker-compose up -d

# 2. ヘルスチェック待機
print_info "サービスの起動を待機中 (30秒)..."
# プログレスバー風の待機
for i in {1..30}; do
    printf "."
    sleep 1
done
echo

# 3. 移行スクリプトの配置と実行
print_info "データ移行スクリプトを実行中..."

CONTAINER_ID=$(docker-compose ps -q mcp-gateway)
if [ -z "$CONTAINER_ID" ]; then
    print_error "mcp-gateway コンテナが見つかりません。"
    exit 1
fi

# Pythonスクリプトをコンテナにコピー
docker cp scripts/migrate_db.py "$CONTAINER_ID":/tmp/migrate_db.py

# 実行
if docker-compose exec -T mcp-gateway python3 /tmp/migrate_db.py; then
    print_success "データ移行が完了しました！"
else
    print_error "データ移行に失敗しました。ログを確認してください。"
    # 失敗してもコンテナは起動したままにする（調査のため）
    exit 1
fi

# 後始末
docker-compose exec -T mcp-gateway rm /tmp/migrate_db.py

echo
print_info "================================================"
print_info "移行作業完了"
print_info "================================================"
print_info "動作確認:"
print_info "  docker-compose logs -f mcp-gateway"
