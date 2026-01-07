# Docker MCP Gateway Tips集

Docker MCP Gatewayを効率的に運用するための実用的なコツと解決策をまとめたガイドです。

## 目次
- [基本操作](#基本操作)
- [パフォーマンス最適化](#パフォーマンス最適化)
- [セキュリティ強化](#セキュリティ強化)
- [トラブルシューティング](#トラブルシューティング)
- [開発・デバッグ](#開発デバッグ)
- [監視・運用](#監視運用)
- [高可用性](#高可用性)

## 基本操作

### 🚀 クイック起動コマンド
```bash
# ワンライナーでの完全起動
docker-compose up -d && docker-compose logs -f mcp-gateway

# 起動状態の詳細確認
docker-compose ps && docker-compose logs --tail 10 mcp-gateway
```

### 📋 MCPサーバー管理
```bash
# 利用可能なMCPサーバー一覧
docker exec mcp-gateway docker mcp server list

# サーバーの状態確認
docker exec mcp-gateway docker mcp server status filesystem

# 複数サーバーの一括有効化
docker exec mcp-gateway docker mcp server enable filesystem memory duckduckgo

# サーバー設定の詳細表示
docker exec mcp-gateway docker mcp server describe filesystem
```

### 🔄 設定のリロード
```bash
# 設定変更後の即座反映
docker-compose restart mcp-gateway

# ゼロダウンタイムでの設定リロード（可能な場合）
docker exec mcp-gateway docker mcp gateway reload
```

## パフォーマンス最適化

### ⚡ コンテナリソース調整
```yaml
# docker-compose.yml での最適化例
services:
  mcp-gateway:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'
```

### 📊 メモリ使用量監視
```bash
# リアルタイムリソース監視
docker stats mcp-gateway --no-stream

# メモリ使用量の詳細分析
docker exec mcp-gateway cat /proc/meminfo | grep -E "(MemTotal|MemAvailable|MemFree)"
```

### 🎯 接続最適化
```bash
# コネクションプールの調整（.envファイル）
MCP_GATEWAY_MAX_CONCURRENT_REQUESTS=50
MCP_GATEWAY_REQUEST_TIMEOUT=15
MCP_GATEWAY_CONNECT_TIMEOUT=5
```

## セキュリティ強化

### 🔐 セキュリティ設定ベストプラクティス
```bash
# .envでの推奨セキュリティ設定
MCP_GATEWAY_VERIFY_SIGNATURES=true
MCP_GATEWAY_BLOCK_SECRETS=true
MCP_GATEWAY_LOG_CALLS=true

# より厳格な設定
MCP_GATEWAY_OAUTH_ENABLED=true
ALLOWED_NETWORKS=["10.0.0.0/8", "172.16.0.0/12"]
BLOCKED_PORTS=[22, 3389, 5432, 3306, 6379]
```

### 🛡️ ファイアウォール設定

#### 最小権限ファイアウォール設定
```bash
# UFWでの最小限設定（最小権限の原則）
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 管理者IPからのSSH限定（IP制限）
sudo ufw allow from YOUR_ADMIN_IP to any port 22 comment 'SSH Admin Only'

# HTTPS統一エントリーポイント
sudo ufw allow 443/tcp comment 'HTTPS only'

# 内部ネットワークからのMCP Gateway直接アクセス（必要に応じて）
sudo ufw allow from 172.16.0.0/12 to any port 8080 comment 'Internal MCP Access'

sudo ufw enable
```

#### 高度なセキュリティ設定
```bash
# Fail2Ban DDoS保護
sudo apt install fail2ban

# Rate Limiting（iptables）
sudo iptables -A INPUT -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

# IP許可リスト管理
sudo ufw allow from 203.0.113.0/24 to any port 443 comment 'Trusted Network'

# ポートスキャン検出
sudo ufw deny from any to any port 1:65535 comment 'Port Scan Detection'
```

### 🔍 セキュリティ監査
```bash
# セキュリティログの確認
docker-compose logs mcp-gateway | grep -i "security\|auth\|error"

# 不正アクセス試行の検出
sudo grep "Failed" /var/log/auth.log | tail -20

# ポートスキャン検出
sudo netstat -tlnp | grep -E ":(22|443|8080)"
```

## トラブルシューティング

### 🔧 よくある問題と解決法

#### 問題1: ヘルスチェック失敗
```bash
# 症状確認
curl -f http://localhost:8080/ || echo "Health check failed"

# 解決手順
docker-compose logs mcp-gateway | tail -20
docker exec mcp-gateway ps aux
docker-compose restart mcp-gateway
```

#### 問題2: MCPサーバー接続エラー
```bash
# デバッグモードでの起動
docker-compose down
docker-compose run --rm mcp-gateway --verbose --debug

# 設定ファイルの検証
docker exec mcp-gateway cat /root/.docker/mcp/config.yaml
```

#### 問題3: パフォーマンス低下
```bash
# リソース使用状況の確認
docker stats mcp-gateway
docker exec mcp-gateway top -bn1

# ログファイルサイズの確認
docker exec mcp-gateway du -sh /var/log/
```

### 🚨 緊急時対応
```bash
# 完全リセット（データ保持）
docker-compose down
docker-compose up -d --force-recreate

# バックアップからの復旧
docker run --rm -v mcp_config:/data -v $(pwd)/backup:/backup alpine \
  sh -c "cd /data && tar xzf /backup/mcp-config-YYYYMMDD.tar.gz"
```

## 開発・デバッグ

### 🐛 デバッグ用設定
```bash
# .env でのデバッグ設定
LOG_LEVEL=DEBUG
LOG_FORMAT=text
MCP_GATEWAY_LOG_CALLS=true

# 詳細ログ出力
docker-compose logs -f mcp-gateway | grep -E "(ERROR|WARN|DEBUG)"
```

### 📡 API動作確認
```bash
# MCP Gateway APIテスト
curl -H "Content-Type: application/json" \
     -X POST http://localhost:8080/mcp \
     -d '{"method":"tools/list","params":{}}'

# ヘルスチェックエンドポイント
curl -v http://localhost:8080/
```

### 🔍 設定デバッグ
```bash
# 設定ファイルの構文チェック
docker-compose config

# 環境変数の確認
docker exec mcp-gateway env | grep MCP

# Docker MCP CLI でのデバッグ
docker exec mcp-gateway docker mcp --help
```

## 監視・運用

### 📈 定期監視スクリプト
```bash
#!/bin/bash
# monitor-mcp.sh
echo "=== MCP Gateway Health Check ==="
curl -s http://localhost:8080/ && echo "✅ Gateway OK" || echo "❌ Gateway DOWN"

echo "=== Container Status ==="
docker-compose ps mcp-gateway

echo "=== Resource Usage ==="
docker stats mcp-gateway --no-stream

echo "=== Recent Errors ==="
docker-compose logs --since 1h mcp-gateway | grep -i error | tail -5
```

### 📊 メトリクス収集
```bash
# システムメトリクス
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
echo "Disk: $(df -h / | awk 'NR==2{print $5}')"

# Docker メトリクス
docker system df
docker volume ls | grep mcp
```

### 📋 自動バックアップ
```bash
#!/bin/bash
# backup-mcp.sh
BACKUP_DIR="/backup/mcp-gateway"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 設定ファイルのバックアップ
docker run --rm -v mcp_config:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/mcp-config-$DATE.tar.gz -C /data .

# ログの圧縮保存
docker-compose logs mcp-gateway > $BACKUP_DIR/logs-$DATE.log

# 古いバックアップの削除（30日以上）
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/mcp-config-$DATE.tar.gz"
```

## 高可用性

### 🔄 負荷分散設定
```yaml
# docker-compose.yml での複数インスタンス
services:
  mcp-gateway-1:
    # ... 基本設定 ...
    ports:
      - "127.0.0.1:8080:8080"

  mcp-gateway-2:
    # ... 基本設定 ...
    ports:
      - "127.0.0.1:8081:8080"
```

### 🏥 ヘルスチェック強化
```yaml
# 詳細なヘルスチェック設定
healthcheck:
  test: ["CMD", "sh", "-c", "curl -f http://localhost:8080/ && docker mcp server list"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### 🔧 自動復旧スクリプト
```bash
#!/bin/bash
# auto-recovery.sh
check_health() {
    curl -sf http://localhost:8080/ > /dev/null 2>&1
}

if ! check_health; then
    echo "$(date): Gateway unhealthy, attempting restart..."
    docker-compose restart mcp-gateway
    sleep 30

    if check_health; then
        echo "$(date): Recovery successful"
    else
        echo "$(date): Recovery failed, manual intervention required"
        # アラート送信などの処理
    fi
fi
```

## 追加 Tips

### 💡 パフォーマンス向上
- MCPサーバーは必要なもののみ有効化
- ログレベルを本番では INFO に設定
- 定期的な `docker system prune` でリソース開放

### 🔒 セキュリティ強化推奨事項
- **パスワード管理**: 90日ごとの強制更新・複雑性要件適用
- **アクセス制御**: IP許可リスト管理・セッションタイムアウト設定
- **ログ管理**: 改ざん防止・リアルタイム監視・適切なローテーション
- **更新管理**: セキュリティアップデートの緊急適用・脆弱性スキャン
- **証明書管理**: SSL証明書の自動更新・HSTS設定・強力な暗号化スイート
- **バックアップ**: 暗号化バックアップ・オフサイト保存・復旧テスト
- **監査**: アクセスログ分析・異常検知・コンプライアンス対応

### 🚀 運用効率化
- CI/CDパイプラインでの自動デプロイ
- 監視アラートの設定
- ドキュメントの定期更新

---

## 📚 関連ドキュメント

### 設定・運用ガイド
- [環境変数設定ガイド](ENV.md) - 環境変数の包括的設定
- [MCPサーバー設定ガイド](MCP-SERVER-SETUP.md) - MCPサーバーの設定・管理
- [Nginxプロキシ設定ガイド](NGINX-PROXY-SETUP.md) - Nginxプロキシの設定

### メインドキュメント
- [メインREADME](../README.md) - プロジェクト概要とクイックスタート

---

**💡 Pro Tip**: このTips集を定期的に参照し、新しい運用ノウハウを追加していくことで、より効率的なDocker MCP Gateway運用が実現できます。