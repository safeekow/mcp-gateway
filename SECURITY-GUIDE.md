# IBM ContextForge MCP Gateway - セキュリティガイド

本番環境でのセキュリティベストプラクティスと推奨設定。

## 📋 目次

1. [セキュリティ原則](#セキュリティ原則)
2. [認証・認可](#認証認可)
3. [ネットワークセキュリティ](#ネットワークセキュリティ)
4. [データ保護](#データ保護)
5. [監査・ログ](#監査ログ)
6. [脆弱性管理](#脆弱性管理)
7. [インシデント対応](#インシデント対応)

---

## セキュリティ原則

### 基本方針

1. **最小権限の原則**: 必要最小限のアクセス権限のみ付与
2. **多層防御**: 複数のセキュリティレイヤーで保護
3. **ゼロトラスト**: 内部・外部問わず全て検証
4. **継続的監視**: リアルタイムでの異常検知
5. **定期的レビュー**: セキュリティ設定の定期見直し

### セキュリティレベル定義

| レベル | 用途 | 要件 |
|--------|------|------|
| **開発** | ローカル開発 | 基本的なセキュリティ |
| **ステージング** | テスト環境 | 本番環境に準じる |
| **本番** | 本番環境 | 最高レベルのセキュリティ |

---

## 認証・認可

### 1. JWT認証設定

#### シークレットキー生成

```bash
# 強力なJWTシークレットキー生成（64バイト推奨）
openssl rand -base64 64

# または
head -c 64 /dev/urandom | base64
```

**要件**:
- 最低32文字以上
- ランダムな文字列
- 定期的なローテーション（推奨: 90日毎）

#### トークン有効期限設定

環境変数で設定:
```bash
# トークン有効期限（秒）
JWT_ACCESS_TOKEN_EXPIRE=3600  # 1時間
JWT_REFRESH_TOKEN_EXPIRE=604800  # 7日
```

### 2. パスワードポリシー

#### 管理者パスワード要件

- **最低長**: 12文字以上（推奨: 16文字以上）
- **複雑性**: 以下を含む
  - 大文字 (A-Z)
  - 小文字 (a-z)
  - 数字 (0-9)
  - 特殊文字 (!@#$%^&*)
- **有効期限**: 90日（推奨）
- **履歴**: 過去5つのパスワードは再利用不可

#### パスワード生成例

```bash
# 強力なランダムパスワード生成
openssl rand -base64 32 | tr -d "=+/" | cut -c1-20

# パスフレーズ方式（覚えやすい）
# 例: Correct-Horse-Battery-Staple-42!
```

### 3. アクセス制御（RBAC）

#### ロール定義

```sql
-- プラットフォーム管理者
INSERT INTO roles (name, description, permissions)
VALUES ('platform_admin', 'Platform Administrator',
        '{"manage_users": true, "manage_servers": true, "manage_teams": true}');

-- チーム管理者
INSERT INTO roles (name, description, permissions)
VALUES ('team_admin', 'Team Administrator',
        '{"manage_team": true, "manage_servers": false, "manage_users": false}');

-- 一般ユーザー
INSERT INTO roles (name, description, permissions)
VALUES ('user', 'Regular User',
        '{"use_servers": true, "manage_servers": false, "manage_users": false}');
```

#### IP制限設定

Nginx設定で特定IPのみ許可:

```nginx
# 管理UIへのアクセスを特定IPのみ許可
location /admin {
    allow 203.0.113.0/24;  # 管理者ネットワーク
    allow 198.51.100.5;     # 管理者IP
    deny all;

    proxy_pass http://localhost:4444/admin;
}
```

### 4. マルチファクタ認証（MFA）

**推奨設定**:
- プラットフォーム管理者: MFA必須
- チーム管理者: MFA推奨
- 一般ユーザー: 任意

実装オプション:
- TOTP (Google Authenticator、Authy等)
- SMS認証
- ハードウェアトークン (YubiKey等)

---

## ネットワークセキュリティ

### 1. ファイアウォール設定

#### UFW（Ubuntu）

```bash
# 基本設定
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH（管理者IPのみ）
sudo ufw allow from 203.0.113.0/24 to any port 22 proto tcp

# HTTPS（全世界）
sudo ufw allow 443/tcp

# 内部通信のみ許可（PostgreSQL、Redis）
sudo ufw deny 5432/tcp
sudo ufw deny 6379/tcp

sudo ufw enable
```

#### iptables（詳細制御）

```bash
# 新規接続のレート制限
sudo iptables -A INPUT -p tcp --dport 443 -m state --state NEW -m recent --set
sudo iptables -A INPUT -p tcp --dport 443 -m state --state NEW -m recent --update --seconds 60 --hitcount 20 -j DROP

# SYN Flood 攻撃対策
sudo iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
sudo iptables -A INPUT -p tcp --syn -j DROP
```

### 2. SSL/TLS設定

#### 推奨設定（Nginx）

```nginx
# TLSバージョン
ssl_protocols TLSv1.2 TLSv1.3;

# 暗号スイート（Mozilla Intermediate）
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;

# HSTS（Strict Transport Security）
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/your-domain.com/chain.pem;

# DH Parameters
ssl_dhparam /etc/nginx/dhparam.pem;
```

#### DH Parametersパラメータ生成

```bash
sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096
```

### 3. Rate Limiting

#### アプリケーションレベル

環境変数設定:
```bash
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_PER_HOUR=1000
```

#### Nginxレベル

```nginx
# リクエスト制限ゾーン定義
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;

# 適用
location /api/ {
    limit_req zone=api_limit burst=20 nodelay;
    proxy_pass http://localhost:4444;
}

location /admin/login {
    limit_req zone=login_limit burst=5 nodelay;
    proxy_pass http://localhost:4444;
}
```

### 4. DDoS対策

```bash
# Fail2ban設定
sudo nano /etc/fail2ban/jail.local
```

```ini
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/*error.log
findtime = 600
bantime = 7200
maxretry = 10
```

---

## データ保護

### 1. 暗号化

#### 通信の暗号化

- **外部通信**: TLS 1.3（最低 TLS 1.2）
- **内部通信**: Docker内部ネットワーク

#### 保存データの暗号化

```bash
# PostgreSQL データ暗号化
# docker-compose.yml に追加
services:
  postgres:
    environment:
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data

# ボリューム暗号化（ホストレベル）
# LUKS等を使用したディスク暗号化
```

### 2. シークレット管理

#### 推奨ツール

1. **Docker Secrets**（Swarm mode）
2. **HashiCorp Vault**
3. **AWS Secrets Manager**
4. **Azure Key Vault**

#### 環境変数の保護

```bash
# .env ファイルのパーミッション
chmod 600 .env
chown root:root .env

# Gitignore設定
echo ".env" >> .gitignore
echo ".env.production" >> .gitignore
echo "*.pem" >> .gitignore
echo "*.key" >> .gitignore
```

### 3. バックアップ暗号化

```bash
# バックアップ暗号化スクリプト
cat > /opt/mcp-gateway/scripts/encrypted-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/mcp-gateway"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}"

# バックアップ実行
/opt/mcp-gateway/scripts/backup.sh "${BACKUP_DIR}"

# 暗号化（GPG）
tar czf - "${BACKUP_DIR}/${BACKUP_NAME}" | \
  gpg --symmetric --cipher-algo AES256 --output "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg"

# 元のバックアップ削除
rm -rf "${BACKUP_DIR}/${BACKUP_NAME}"

echo "Encrypted backup: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg"
EOF

chmod +x /opt/mcp-gateway/scripts/encrypted-backup.sh
```

---

## 監査・ログ

### 1. ログ設定

#### アプリケーションログ

環境変数:
```bash
# 本番環境
LOG_LEVEL=INFO
LOG_FORMAT=json

# セキュリティイベントログ
SECURITY_LOG_ENABLED=true
AUDIT_LOG_ENABLED=true
```

#### 収集すべきログ

1. **認証ログ**: ログイン成功/失敗
2. **認可ログ**: アクセス許可/拒否
3. **APIログ**: 全APIリクエスト
4. **変更ログ**: 設定変更、ユーザー管理
5. **エラーログ**: アプリケーションエラー
6. **システムログ**: Docker、OS レベル

### 2. ログ保持期間

| ログタイプ | 保持期間 | 理由 |
|-----------|----------|------|
| 認証ログ | 90日 | コンプライアンス |
| 監査ログ | 1年 | 法的要件 |
| APIログ | 30日 | トラブルシューティング |
| エラーログ | 60日 | 問題分析 |
| システムログ | 30日 | 運用監視 |

### 3. ログ分析・監視

#### Elastic Stack設定例

```yaml
# docker-compose.yml に追加
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
```

---

## 脆弱性管理

### 1. 定期的なスキャン

#### Docker イメージスキャン

```bash
# Trivy インストール
wget https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.tar.gz
tar zxvf trivy_0.48.0_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/

# スキャン実行
trivy image ghcr.io/ibm/mcp-context-forge:0.8.0
```

#### 依存関係スキャン

```bash
# Docker Compose 設定スキャン
trivy config docker-compose.yml

# 脆弱性レポート生成
trivy image --format json --output report.json ghcr.io/ibm/mcp-context-forge:0.8.0
```

### 2. 更新管理

#### システムアップデート（自動化）

```bash
# Unattended Upgrades インストール
sudo apt install unattended-upgrades

# 設定
sudo dpkg-reconfigure -plow unattended-upgrades
```

#### コンテナイメージ更新

```bash
# 定期的なイメージ更新スクリプト
cat > /usr/local/bin/update-mcp-gateway.sh << 'EOF'
#!/bin/bash
cd /opt/mcp-gateway

# バックアップ
./scripts/backup.sh /opt/backups/pre-update

# イメージ更新
docker compose pull

# サービス再起動
docker compose up -d

# ヘルスチェック
sleep 30
curl -f http://localhost:4444/health || {
    echo "Health check failed! Rolling back..."
    ./scripts/restore.sh /opt/backups/pre-update/backup_*
    exit 1
}

echo "Update completed successfully"
EOF

chmod +x /usr/local/bin/update-mcp-gateway.sh
```

---

## インシデント対応

### 1. インシデント対応手順

#### フェーズ1: 検知

- 異常なログパターン
- ヘルスチェック失敗
- パフォーマンス低下
- セキュリティアラート

#### フェーズ2: 封じ込め

```bash
# 緊急停止
docker compose stop mcp-gateway

# ネットワーク隔離
sudo ufw deny 443/tcp

# アクセスログ保存
sudo cp /var/log/nginx/mcp-gateway-access.log /tmp/incident-$(date +%Y%m%d_%H%M%S).log
```

#### フェーズ3: 調査

```bash
# ログ分析
docker compose logs --since 1h mcp-gateway > incident-gateway.log

# データベース監査
docker compose exec postgres psql -U postgres -d mcp -c "
SELECT * FROM email_auth_events
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;"

# ネットワーク接続確認
sudo netstat -tunap | grep ESTABLISHED
```

#### フェーズ4: 復旧

```bash
# クリーンな状態からリストア
./scripts/restore.sh /opt/backups/known-good-backup

# サービス再起動
docker compose up -d

# 検証
./scripts/health-check.sh
```

### 2. 緊急連絡先

```yaml
# incident-contacts.yml
platform_admin:
  email: admin@your-domain.com
  phone: +81-90-XXXX-XXXX

security_team:
  email: security@your-domain.com
  slack: "#security-alerts"

on_call:
  email: oncall@your-domain.com
  pagerduty: "https://your-org.pagerduty.com"
```

---

## セキュリティチェックリスト

### 導入前チェック

- [ ] 全てのデフォルトパスワードを変更
- [ ] JWT_SECRET_KEY を強力な値に設定
- [ ] SSL証明書を取得・設定
- [ ] ファイアウォールルールを設定
- [ ] SSH公開鍵認証を設定
- [ ] 管理者IPアドレス制限を設定
- [ ] Rate Limiting を有効化
- [ ] ログ収集・監視を設定
- [ ] バックアップ自動化を設定
- [ ] インシデント対応手順を準備

### 定期チェック（月次）

- [ ] セキュリティアップデート適用
- [ ] ログレビュー
- [ ] バックアップ検証
- [ ] アクセス権限レビュー
- [ ] 脆弱性スキャン実施
- [ ] SSL証明書有効期限確認

### 定期チェック（四半期）

- [ ] パスワードローテーション
- [ ] JWT_SECRET_KEY ローテーション
- [ ] セキュリティ設定レビュー
- [ ] インシデント対応訓練
- [ ] 災害復旧テスト

---

## 参考資料

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [PCI DSS](https://www.pcisecuritystandards.org/)
- [ISO 27001](https://www.iso.org/isoiec-27001-information-security.html)

---

**免責事項**: このガイドは一般的なセキュリティベストプラクティスを提供しますが、組織固有の要件や規制に従って適切にカスタマイズしてください。
