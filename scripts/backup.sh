#!/bin/bash
#
# IBM ContextForge MCP Gateway - バックアップスクリプト
#
# このスクリプトは、PostgreSQLデータベース、Redis、設定のバックアップを取得します。
# 使用方法: ./scripts/backup.sh [backup_directory]
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

# デフォルトのバックアップディレクトリ
BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/backup_${TIMESTAMP}"

# バックアップディレクトリ作成
mkdir -p "${BACKUP_PATH}"

print_info "=========================================="
print_info "IBM ContextForge MCP Gateway バックアップ"
print_info "=========================================="
print_info "バックアップ先: ${BACKUP_PATH}"
echo

# Docker Compose 動作確認
if ! docker-compose ps >/dev/null 2>&1; then
    print_error "Docker Compose サービスが起動していません"
    exit 1
fi

# 1. PostgreSQL バックアップ
print_info "[1/3] PostgreSQL データベースをバックアップ中..."
docker-compose exec -T postgres pg_dump -U postgres mcp > "${BACKUP_PATH}/postgres_mcp.sql"
if [ $? -eq 0 ]; then
    SIZE=$(du -h "${BACKUP_PATH}/postgres_mcp.sql" | cut -f1)
    print_success "PostgreSQL バックアップ完了 (${SIZE})"
else
    print_error "PostgreSQL バックアップ失敗"
    exit 1
fi

# 2. Redis バックアップ
print_info "[2/3] Redis データをバックアップ中..."
docker-compose exec redis redis-cli SAVE >/dev/null 2>&1
docker run --rm -v mcp-gateway_redis_data:/data -v "${PWD}/${BACKUP_PATH}":/backup alpine tar czf /backup/redis_data.tar.gz -C /data .
if [ $? -eq 0 ]; then
    SIZE=$(du -h "${BACKUP_PATH}/redis_data.tar.gz" | cut -f1)
    print_success "Redis バックアップ完了 (${SIZE})"
else
    print_error "Redis バックアップ失敗"
    exit 1
fi

# 3. 環境変数バックアップ（機密情報を除く）
print_info "[3/3] 環境設定をバックアップ中..."
if [ -f .env ]; then
    cp .env "${BACKUP_PATH}/env.backup"
    # 機密情報をマスク
    sed -i.bak \
        -e 's/\(JWT_SECRET_KEY=\).*/\1[MASKED]/' \
        -e 's/\(PASSWORD=\).*/\1[MASKED]/' \
        -e 's/\(SECRET=\).*/\1[MASKED]/' \
        "${BACKUP_PATH}/env.backup"
    rm -f "${BACKUP_PATH}/env.backup.bak"
    print_success "環境設定バックアップ完了"
else
    print_warning ".env ファイルが見つかりません"
fi

# バックアップ情報ファイル作成
cat > "${BACKUP_PATH}/backup_info.txt" << EOF
IBM ContextForge MCP Gateway バックアップ情報
=============================================
作成日時: $(date '+%Y-%m-%d %H:%M:%S')
ホスト名: $(hostname)
Docker Compose Project: $(docker-compose ps --format json | jq -r '.[0].Project' 2>/dev/null || echo "N/A")

バックアップ内容:
- PostgreSQL データベース: postgres_mcp.sql
- Redis データ: redis_data.tar.gz
- 環境設定: env.backup (機密情報マスク済み)

リストア方法:
./scripts/restore.sh ${BACKUP_PATH}
EOF

# 総容量表示
TOTAL_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
echo
print_success "=========================================="
print_success "バックアップ完了"
print_success "=========================================="
print_info "保存先: ${BACKUP_PATH}"
print_info "総容量: ${TOTAL_SIZE}"
echo
print_info "リストア方法:"
echo "  ./scripts/restore.sh ${BACKUP_PATH}"
