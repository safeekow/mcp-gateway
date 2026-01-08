# クライアント接続設定ガイド

本ガイドでは、IBM ContextForge MCP Gateway を利用するクライアントアプリケーション（AIエージェント、IDEなど）の設定方法について説明します。

---

## JetBrains AI Assistant (推奨方法)

JetBrains IDE (IntelliJ IDEA, PyCharm, WebStorm, GoLand など) の AI Assistant 機能（バージョン 2024.3 以降）から、公式の接続ラッパーを使用して MCP Gateway に接続する手順です。

### 1. 前提条件

1.  **Python 3 のインストール**: ローカルマシンに Python 3.10 以上がインストールされている必要があります。
2.  **ラッパーのインストール**:
    ターミナルで以下のコマンドを実行し、接続に必要な公式パッケージをインストールしてください。
    ```bash
    pip install mcp-contextforge-gateway
    ```
3.  **サーバー ID (UUID) の取得**:
    *   Gateway 管理画面（`https://{MCP GatewayのURL}`）にログインします。
    *   **Servers** メニューを開き、利用したいサーバーの **ID (UUID)** をコピーします（例: `550e8400-e29b-41d4-a716-446655440000`）。
4.  **API トークンの取得**:
    *   管理者から提供された、または管理画面で発行した API トークン（JWT）を準備します。

### 2. 設定手順

JetBrains AI Assistant の「Executable」設定を使用して、公式の `mcpgateway.wrapper` を起動します。

1.  **設定画面を開く**:
    *   IDE のメニューから **Settings** (macOS は **Settings** または **Preferences**) を開きます。
    *   **Tools** > **AI Assistant** > **Model Context Protocol (MCP)** に移動します。

2.  **サーバーを追加**:
    *   **+ (Add)** ボタンをクリックし、以下の内容を入力します。

    | 項目 | 設定値 |
    | :--- | :--- |
    | **Name** | `MCP Gateway (Server Name)` |
    | **Type** | `Executable` |
    | **Command** | `python3` (または `python`) |
    | **Arguments** | `-m mcpgateway.wrapper` |

3.  **環境変数の設定**:
    *   設定画面の **Environment Variables** (または `...` ボタン) をクリックし、以下の変数を追加します。

    | キー | 値 |
    | :--- | :--- |
    | **`MCP_SERVER_URL`** | `https://{MCP GatewayのURL}/servers/{取得したUUID}/mcp` |
    | **`MCP_AUTH`** | `Bearer <YOUR_ACCESS_TOKEN>` |
    | **`MCP_TOOL_CALL_TIMEOUT`** | `120` (推奨) |

4.  **保存と確認**:
    *   **OK** または **Apply** をクリックして設定を保存します。
    *   接続に成功すると、AI Assistant でそのサーバーが提供するツールが利用可能になります。

---

## Claude Code CLI

Claude Code CLI から MCP Gateway を利用する場合も、同様に `mcpgateway.wrapper` を経由させる方法が最も安定しています。

### 設定例 (`config.json`)

```json
{
  "mcpServers": {
    "ibm-gateway": {
      "command": "python3",
      "args": ["-m", "mcpgateway.wrapper"],
      "env": {
        "MCP_SERVER_URL": "https://{MCP GatewayのURL}/servers/{UUID}/mcp",
        "MCP_AUTH": "Bearer <YOUR_ACCESS_TOKEN>",
        "MCP_TOOL_CALL_TIMEOUT": "120"
      }
    }
  }
}
```

---

## その他の接続方法 (直接 SSE)

ブリッジツール（`npx @mcpwizard/sse-bridge` など）を使用する場合は、以下のエンドポイントを試してください。

*   **URL**: `https://{MCP GatewayのURL}/sse` (Gateway全体のエンドポイント)
    ※ ただし、この方法はサーバー側の構成によって `404 Not Found` になる場合があります。その際は上記の **推奨方法（UUID指定 + mcpgateway.wrapper）** を利用してください。

---

## トラブルシューティング

### 403 Forbidden エラー (権限エラー)
*   サーバーのアクセス設定が **Private** または **Team** になっている場合、適切な権限がないとアクセスできません。
*   **Team** 設定の場合は、トークンを発行したユーザーがそのチームのメンバーであることを確認してください。
*   **Private** 設定の場合は、自分自身のサーバー以外にはアクセスできません。
*   一時的に **Public** に変更して疎通確認を行うのも一つの手段です。

### 404 Not Found エラー
*   URL の UUID が正しいか確認してください。
*   `/mcp` の前に `/servers/` が含まれているか確認してください。
*   `/sse` でエラーが出る場合は、必ず `/servers/{UUID}/mcp` の形式を使用してください。

### Authentication failed
*   `MCP_AUTH` の値が `Bearer ` (半角スペースあり) で始まっているか確認してください。
*   トークンの有効期限が切れていないか、管理画面で再確認してください。

### コマンドが見つからない
*   ターミナルで `python3 --version` を実行し、Python が利用可能であることを確認してください。
*   `pip install mcp-contextforge-gateway` が正常に完了しているか確認してください。

---

## CLIでの接続テスト（デバッグ）

設定がうまくいかない場合や、最小構成で疎通確認を行いたい場合は、ターミナルから直接ラッパーを起動して動作を確認できます。

### 1. 接続情報のセット
ターミナルで一時的に環境変数を設定します。

```bash
export MCP_SERVER_URL="https://{MCP GatewayのURL}/servers/{UUID}/mcp"
export MCP_AUTH="Bearer <YOUR_ACCESS_TOKEN>"
```

### 2. ラッパーの起動
接続用ラッパーを直接起動します。

```bash
python3 -m mcpgateway.wrapper
```
起動すると入力待ち状態（何も表示されない状態）になります。

### 3. 初期化リクエストの送信
以下の JSON をコピーし、ターミナルに貼り付けて Enter を押します。

```json
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}}
```

### 4. 結果の確認
成功すると、以下のような JSON レスポンスが返ってきます。

```json
{"jsonrpc": "2.0", "id": 1, "result": {"protocolVersion": "2024-11-05", "capabilities": {...}, "serverInfo": {...}}}
```
これらが返ってくれば、ネットワークと認証は正常です。`Ctrl + C` で終了します。

### 重要: ラッパーとサーバー本体の違い（DBエラーが出る場合）
`mcp-contextforge-gateway` パッケージには、サーバー本体と接続用ラッパーの両方が含まれています。起動コマンドの引数に注意してください。

*   **正 (クライアント用):** `python3 -m mcpgateway.wrapper`
    *   軽量なプロキシとして動作し、リモートの Gateway へ接続します。DB設定は不要です。
*   **誤 (サーバー用):** `python3 -m mcpgateway`
    *   Gateway 本体として起動しようとします。ローカルに DB 設定がない場合、**接続エラー**が発生します。