# Nginx プロキシ設定ガイド

Docker MCP Gatewayの前段にNginxをリバースプロキシとして設置する場合の設定方法を説明します。

## 概要

Nginxをリバースプロキシとして使用することで以下の利点があります：

- **SSL終端**: HTTPS通信の処理をNginxで行い、バックエンドは平文通信
- **ロードバランシング**: 複数のDocker MCP Gatewayインスタンスへの負荷分散
- **セキュリティ**: IP制限、Rate Limiting、DDoS対策
- **キャッシュ**: 静的ファイルのキャッシュによる性能向上
- **圧縮**: gzip圧縮による転送量削減

## アーキテクチャ

```
Internet → Nginx (Port 443/80) → Docker MCP Gateway (Port 8080) → Docker Container
```

## 前提条件

- Ubuntu 22.04 LTS またはCentOS 8+
- Docker & Docker Compose インストール済み
- ドメイン名とDNS設定済み
- sudo権限

## インストール手順

### 1. Nginxインストール

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y nginx
```

#### CentOS/RHEL
```bash
sudo dnf install -y nginx
```

### 2. SSL証明書取得

#### Let's Encryptを使用（推奨）
```bash
# Certbotインストール
sudo apt install -y certbot python3-certbot-nginx

# SSL証明書取得
sudo certbot --nginx -d your-domain.com
```

#### 自己署名証明書（開発環境用）
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/mcp-gateway.key \
  -out /etc/ssl/certs/mcp-gateway.crt \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Organization/CN=your-domain.com"
```

### 3. Nginx設定ファイル作成

`/etc/nginx/sites-available/mcp-gateway` を作成：

```nginx
# MCP Gateway Nginx設定
upstream mcp_backend {
    # ヘルスチェック付きバックエンド
    server 127.0.0.1:8080 max_fails=3 fail_timeout=30s;
    # 複数インスタンスの場合
    # server 127.0.0.1:4445 max_fails=3 fail_timeout=30s;

    # セッション維持（必要に応じて）
    ip_hash;
}

# Rate Limiting設定
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# HTTPからHTTPSへのリダイレクト
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS設定
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL設定
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL強化設定
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS設定
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # ログ設定
    access_log /var/log/nginx/mcp-gateway.access.log;
    error_log /var/log/nginx/mcp-gateway.error.log;

    # 基本設定
    client_max_body_size 100M;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # gzip圧縮
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml;

    # WebUIへのプロキシ（Rate Limiting適用）
    location / {
        limit_req zone=api burst=20 nodelay;

        proxy_pass http://mcp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # WebSocket支援
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # API エンドポイント（厳格なRate Limiting）
    location /api/ {
        limit_req zone=api burst=10 nodelay;

        proxy_pass http://mcp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 認証エンドポイント（最も厳格なRate Limiting）
    location /auth/ {
        limit_req zone=login burst=3 nodelay;

        proxy_pass http://mcp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # ヘルスチェックエンドポイント
    location /health {
        proxy_pass http://mcp_backend/health;
        access_log off;
    }

    # 静的ファイル（必要に応じて）
    location /static/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # IP制限例（管理者のみアクセス）
    location /admin/ {
        allow 192.168.1.0/24;  # 内部ネットワーク
        allow 203.0.113.0/24;  # 管理者IP範囲
        deny all;

        proxy_pass http://mcp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 4. 設定の有効化

```bash
# 設定ファイルのシンタックスチェック
sudo nginx -t

# サイトを有効化
sudo ln -s /etc/nginx/sites-available/mcp-gateway /etc/nginx/sites-enabled/

# デフォルトサイトを無効化（必要に応じて）
sudo rm /etc/nginx/sites-enabled/default

# Nginxを再起動
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 5. Docker Compose設定の調整

`docker-compose.yml`を以下のように修正：

```yaml
services:
  mcp-gateway:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: mcp-gateway
    ports:
      # 外部には公開せず、localhostのみ
      - "127.0.0.1:8080:8080"
    env_file:
      - .env
    environment:
      HOST: 0.0.0.0
      PORT: 8080
      # プロキシ経由であることを明示
      PROXY_MODE: true
      MCPGATEWAY_UI_ENABLED: ${MCPGATEWAY_UI_ENABLED}
      MCPGATEWAY_ADMIN_API_ENABLED: ${MCPGATEWAY_ADMIN_API_ENABLED}
      DATABASE_URL: ${DATABASE_URL}
    volumes:
      - mcp_data:/app/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  mcp_data:
    driver: local
```

## セキュリティ設定

### 1. ファイアウォール設定

```bash
# UFW設定
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable

# iptables設定（上級者向け）
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -s 127.0.0.1 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
```

### 2. Fail2Ban設定

```bash
# Fail2Banインストール
sudo apt install -y fail2ban

# 設定ファイル作成
sudo tee /etc/fail2ban/jail.d/nginx-mcp.conf <<EOF
[nginx-mcp-auth]
enabled = true
port = http,https
filter = nginx-mcp-auth
logpath = /var/log/nginx/mcp-gateway.access.log
maxretry = 5
bantime = 3600
findtime = 600

[nginx-mcp-dos]
enabled = true
port = http,https
filter = nginx-mcp-dos
logpath = /var/log/nginx/mcp-gateway.access.log
maxretry = 100
bantime = 600
findtime = 60
EOF

# フィルター作成
sudo tee /etc/fail2ban/filter.d/nginx-mcp-auth.conf <<EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*(admin|auth|login).*" (401|403|404) .*$
ignoreregex =
EOF

sudo tee /etc/fail2ban/filter.d/nginx-mcp-dos.conf <<EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*" (2\d\d|3\d\d) .*$
ignoreregex =
EOF

# Fail2Ban再起動
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
```

## 監視・運用

### 1. ログ監視

```bash
# Nginxアクセスログ
sudo tail -f /var/log/nginx/mcp-gateway.access.log

# Nginxエラーログ
sudo tail -f /var/log/nginx/mcp-gateway.error.log

# Rate Limiting状況確認
sudo grep "limiting requests" /var/log/nginx/mcp-gateway.error.log
```

### 2. ヘルスチェック

```bash
# 外部からのヘルスチェック
curl -f https://your-domain.com/health

# 内部バックエンドの直接チェック
curl -f http://127.0.0.1:8080/health
```

### 3. SSL証明書の自動更新

```bash
# Crontab設定
sudo crontab -e

# 以下を追加（毎日2時に証明書更新チェック）
0 2 * * * /usr/bin/certbot renew --quiet && /usr/bin/systemctl reload nginx
```

## パフォーマンス最適化

### 1. キャッシュ設定

```nginx
# Nginx設定に追加
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=mcp_cache:10m
                 max_size=1g inactive=60m use_temp_path=off;

server {
    # 静的コンテンツのキャッシュ
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_cache mcp_cache;
        proxy_cache_valid 200 1h;
        proxy_cache_use_stale error timeout invalid_header updating;
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://mcp_backend;
    }
}
```

### 2. Worker設定

```nginx
# /etc/nginx/nginx.conf の worker_processes設定
worker_processes auto;
worker_connections 1024;

# keepalive設定
upstream mcp_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}
```

## トラブルシューティング

### よくある問題と解決方法

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| 502 Bad Gateway | バックエンドが停止 | `docker-compose ps`でコンテナ状態確認 |
| SSL証明書エラー | 証明書期限切れ | `sudo certbot renew`実行 |
| 429 Too Many Requests | Rate Limitに達した | `/var/log/nginx/error.log`でRate Limit状況確認 |
| 接続タイムアウト | ファイアウォール設定 | UFW設定とiptables確認 |

### デバッグコマンド

```bash
# Nginx設定テスト
sudo nginx -t

# Nginx設定リロード
sudo systemctl reload nginx

# プロセス状況確認
sudo netstat -tlnp | grep :443
sudo ss -tlnp | grep :8080

# Nginxステータス確認
sudo systemctl status nginx

# プロキシテスト
curl -H "Host: your-domain.com" http://127.0.0.1:8080/health
```

## 高可用性構成

### 1. 複数インスタンス構成

```yaml
# docker-compose.yml
services:
  mcp-gateway-1:
    # ... 設定 ...
    ports:
      - "127.0.0.1:8080:8080"

  mcp-gateway-2:
    # ... 設定 ...
    ports:
      - "127.0.0.1:4445:8080"
```

```nginx
# Nginx upstream設定
upstream mcp_backend {
    server 127.0.0.1:8080 weight=1 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:4445 weight=1 max_fails=3 fail_timeout=30s;

    # ヘルスチェック（nginx-plusの場合）
    # health_check interval=10s fails=3 passes=2;
}
```

### 2. データベース共有設定

```bash
# 共有データベースを使用
DATABASE_URL=postgresql://user:pass@db-server:5432/mcp_gateway
```

## まとめ

この設定により、Docker MCP Gatewayの前段にNginxを配置し、SSL終端、Rate Limiting、セキュリティ強化を実現できます。本番環境では組織のセキュリティポリシーに従って適切に調整してください。

---

## 📚 関連ドキュメント

### 設定・運用ガイド
- [環境変数設定ガイド](ENV.md) - 環境変数の包括的設定
- [MCPサーバー設定ガイド](MCP-SERVER-SETUP.md) - MCPサーバーの設定・管理

### 運用・保守
- [Tips集](TIPS.md) - 実用的な運用のコツと解決策

### メインドキュメント
- [メインREADME](../README.md) - プロジェクト概要とクイックスタート

---

**⚠️ 重要**: 本番環境では組織のセキュリティポリシーに従って適切に設定を調整してください。