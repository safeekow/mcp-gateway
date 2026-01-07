#!/usr/bin/env bash
set -e

# MCP Context Forge Docker Entrypoint

echo "🚀 Starting MCP Context Forge Gateway..."

# 環境変数のデフォルト値設定
: "${HOST:=0.0.0.0}"
: "${PORT:=4444}"
: "${LOG_LEVEL:=info}"

# データベースディレクトリの確認
if [[ "$DATABASE_URL" == sqlite* ]]; then
    DB_PATH=$(echo "$DATABASE_URL" | sed 's|sqlite:///||')
    DB_DIR=$(dirname "$DB_PATH")
    if [ ! -d "$DB_DIR" ]; then
        echo "📁 Creating database directory: $DB_DIR"
        mkdir -p "$DB_DIR"
    fi
fi

# 設定の表示
echo "📋 Configuration:"
echo "   Host: $HOST"
echo "   Port: $PORT"
echo "   Log Level: $LOG_LEVEL"
echo "   Database: ${DATABASE_URL:-Not set}"
echo "   Redis: ${REDIS_URL:-Not set}"
echo "   UI Enabled: ${MCPGATEWAY_UI_ENABLED:-false}"
echo "   Admin API: ${MCPGATEWAY_ADMIN_API_ENABLED:-false}"

# mcpgateway CLIでアプリケーション起動
exec mcpgateway \
    --host "${HOST}" \
    --port "${PORT}" \
    --log-level "${LOG_LEVEL}"
