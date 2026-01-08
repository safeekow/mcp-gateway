# MCP サーバー・ホスティング

このディレクトリでは、Docker コンテナとして実行される各 MCP サーバーの設定を管理しています。
IBM ContextForge MCP Gateway は HTTP/SSE 通信を前提としているため、標準入出力 (stdio) のみをサポートする MCP サーバーは `supergateway` を介して HTTP 化して実行されます。

## 🚀 クイックスタート

すべてのサーバーを起動する：
```bash
docker compose up -d
```

ステータスを確認する：
```bash
docker compose ps
```

## 🛠 ホストされている MCP サーバー一覧

| サービス名 | ポート | 接続タイプ | 言語/ベース | 概要 |
| :--- | :---: | :--- | :--- | :--- |
| `mcp-mermaid` | 3033 | SSE (Direct) | Node.js | Mermaid図生成・変換 |
| `mcp-sequentialthinking` | 8000 | SSE (Bridge) | Node.js | 逐次思考プロセス支援 |
| `mcp-aws-diagram` | 8000 | SSE (Bridge) | Python (uv) | AWS構成図生成 |
| `mcp-aws-documentation` | 8000 | SSE (Bridge) | Python (uv) | AWSドキュメント検索 |
| `mcp-dart` | 8000 | SSE (Bridge) | Dart | Dart言語サポート |
| `mcp-magic` | 8000 | SSE (Bridge) | Node.js | UIコンポーネント生成 |
| `mcp-morphllm` | 8000 | SSE (Bridge) | Node.js | コード変更・適用支援 |
| `mcp-growi` | 8000 | SSE (Bridge) | Node.js | GROWI Wiki連携 |
| `mcp-memory` | 8000 | SSE (Bridge) | Node.js | 知識グラフ/メモリ |
| `mcp-gitlab` | 8000 | SSE (Bridge) | Node.js | GitLab連携 |

> **注**: `SSE (Bridge)` は `supergateway` を使用して stdio を HTTP/SSE に変換しています。

---

## 📖 各サーバーの詳細

### 1. mcp-mermaid
テキストベースのMermaid記法からダイアグラム画像を生成します。
*   **主な機能**: フローチャート、シーケンス図、ガントチャート、ER図などの生成とPNG/SVG変換。
*   **用途**: ドキュメント作成時の図版生成、アーキテクチャの可視化。

### 2. mcp-sequentialthinking
AIモデルが複雑な問題を解決するための「思考の連鎖 (Chain of Thought)」を構造化して提供します。
*   **主な機能**: `sequentialthinking` ツールを通じた段階的な推論、仮説検証、結論の導出。
*   **用途**: 難解なロジックの解析、デバッグ、計画策定。

### 3. mcp-aws-diagram
Pythonの `diagrams` パッケージを使用して、AWSのインフラ構成図をコードベースで生成します。
*   **主な機能**: AWSリソース（EC2, RDS, S3など）のアイコンを用いた構成図の作成。
*   **用途**: インフラ設計図の自動生成、構成の可視化。

### 4. mcp-aws-documentation
AWSの公式ドキュメントを検索し、関連する情報を抽出します。
*   **主な機能**: AWSサービス、APIリファレンス、ユーザーガイドの検索。
*   **用途**: クラウド構築時の仕様確認、トラブルシューティング時の情報収集。

### 5. mcp-dart
Dart 言語および Flutter プロジェクトの開発支援機能を提供します。
*   **主な機能**: コード解析、定義へのジャンプ、リファクタリング支援。
*   **用途**: Dart/Flutter アプリケーションの開発効率化。

### 6. mcp-magic
自然言語の指示から、即座に利用可能な UI コンポーネントやコードスニペットを生成します。
*   **主な機能**: React/Vue などのコンポーネント生成、スタイリング適用。
*   **用途**: プロトタイピング、UI実装の高速化。

### 7. mcp-morphllm
ソースコードに対する変更を高速かつ正確に適用するための支援ツールです。
*   **主な機能**: コードベースの文脈理解、Diffの生成と適用、リファクタリング。
*   **用途**: 大規模なコード修正、自動リファクタリングタスク。

### 8. mcp-growi
Wikiツール「GROWI」と連携し、ナレッジの検索や操作を行います。
*   **主な機能**: ページの検索、閲覧、作成、更新。
*   **用途**: 社内Wikiからの情報取得、ドキュメントの自動更新。

### 9. mcp-memory
AIとの対話履歴や重要な事実を「知識グラフ」として永続化します。
*   **主な機能**: エンティティ（人、物、概念）とリレーションの保存、検索。
*   **用途**: 長期記憶の保持、コンテキストをまたいだ情報共有、ユーザーの好みの学習。

### 10. mcp-gitlab
GitLab リポジトリに対する様々な操作を提供します。
*   **主な機能**: プロジェクト検索、Issue/MRの読み書き、ファイル操作、CI/CDパイプラインの確認。
*   **用途**: 開発ワークフローの自動化、リポジトリ管理。

---

## ➕ 新しい MCP サーバーの追加方法

1.  **ディレクトリ作成**: `mcp-servers/<server-name>` を作成します。
2.  **Dockerfile 作成**: 
    *   ベースイメージを選択（Node.js, Python, etc.）。
    *   `netcat-openbsd` (ヘルスチェック用) と `supergateway` をインストール。
    *   `EXPOSE 8000` を指定。
    *   `CMD` で `supergateway` を介して実行。
3.  **docker-compose.yml への登録**: サービス定義を追加し、ネットワーク `mcp-servers` に接続します。

## 🔗 Gateway への登録方法

Gateway 管理画面から新しいサーバーを登録する際、URL には **Docker サービス名** を使用します。

*   **URL 例**: `http://mcp-growi:8000/sse`
*   **Type**: `SSE` (Bridge サーバーの場合)

## 🔍 トラブルシューティング

### コンテナが Unhealthy になる
*   コンテナ内に `nc` (netcat) がインストールされているか確認してください。
*   `docker compose logs <service-name>` で `supergateway` の起動ログを確認してください。
*   stdio で実行されるコマンドが正しくインストールされているか確認してください。

### ログの確認
```bash
docker compose logs -f <service-name>
```