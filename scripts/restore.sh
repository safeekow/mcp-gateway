#!/bin/bash
#
# IBM ContextForge MCP Gateway - リストアスクリプト
#
# このスクリプトは、バックアップからデータをリストアします。
# 使用方法: ./scripts/restore.sh <backup_directory>
#

set -e

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

# 使用方法
usage() {
    cat << EOF
使用方法: $0 <backup_directory>

IBM ContextForge MCP Gateway のバックアップからデータをリストアします。

例:
    $0 ./backups/backup_20251018_120000

⚠️  警告: このスクリプトは既存のデータを上書きします。
         実行前に現在のデータをバックアップすることを推奨します。

EOF
    exit 1
}

# 引数チェック
if [ $# -ne 1 ]; then
    print_error "バックアップディレクトリを指定してください"
    usage
fi

BACKUP_PATH="$1"

# バックアップディレクトリ確認
if [ ! -d "$BACKUP_PATH" ]; then
    print_error "バックアップディレクトリが見つかりません: $BACKUP_PATH"
    exit 1
fi

print_info "=========================================="
print_info "IBM ContextForge MCP Gateway リストア"
print_info "=========================================="
print_info "バックアップ: ${BACKUP_PATH}"
echo

# バックアップ情報表示
if [ -f "${BACKUP_PATH}/backup_info.txt" ]; then
    cat "${BACKUP_PATH}/backup_info.txt"
    echo
fi

# 確認プロンプト
print_warning "⚠️  既存のデータが上書きされます。続行しますか？"
read -p "続行する場合は 'yes' と入力してください: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "リストアをキャンセルしました"
    exit 0
fi

echo

# Docker Compose 動作確認（PostgreSQLリストアに必要）
if ! docker-compose ps >/dev/null 2>&1; then
    print_error "Docker Compose サービスが起動していません"
    print_info "docker-compose up -d を実行してください"
    exit 1
fi

# 1. PostgreSQL リストア
if [ -f "${BACKUP_PATH}/postgres_mcp.sql" ]; then
    print_info "[1/2] PostgreSQL データベースをリストア中..."

    # データベースを一旦削除して再作成
    # 注意: これを行うにはpostgresコンテナが稼働している必要があります
    docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS mcp;" >/dev/null 2>&1
    docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE mcp;" >/dev/null 2>&1

    # バックアップからリストア
    cat "${BACKUP_PATH}/postgres_mcp.sql" | docker-compose exec -T postgres psql -U postgres -d mcp >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        print_success "PostgreSQL リストア完了"
    else
        print_error "PostgreSQL リストア失敗"
        exit 1
    fi
else
    print_warning "PostgreSQL バックアップファイルが見つかりません"
fi

# サービス停止（Redisリストアのため）
print_info "Redisリストアのためサービスを一時停止中..."
docker-compose stop

# 2. Redis リストア
if [ -f "${BACKUP_PATH}/redis_data.tar.gz" ]; then
    print_info "[2/2] Redis データをリストア中..."

    # Redisサービスのボリュームを使用
    docker-compose run --rm --entrypoint sh -v "${PWD}/${BACKUP_PATH}":/backup redis -c "rm -rf /data/* && tar xzf /backup/redis_data.tar.gz -C /data"

    if [ $? -eq 0 ]; then
        print_success "Redis リストア完了"
    else
        print_error "Redis リストア失敗"
        exit 1
    fi
else
    print_warning "Redis バックアップファイルが見つかりません"
fi

# サービス再起動
print_info "サービスを再起動中..."
docker-compose start

echo
print_success "=========================================="
print_success "リストア完了"
print_success "=========================================="
print_info "サービスが正常に起動するまでお待ちください"
echo
print_info "動作確認:"
echo "  docker-compose ps"
echo "  docker-compose logs -f mcp-gateway"
