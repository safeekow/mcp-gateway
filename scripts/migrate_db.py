import sys
import os
import sqlite3
import logging
from datetime import datetime
from urllib.parse import urlparse

# ロギング設定
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def install_dependencies():
    """必要なパッケージがない場合にインストールを試みる"""
    try:
        import psycopg2
    except ImportError:
        logger.info("psycopg2 not found. Installing...")
        import subprocess
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary"])
            logger.info("psycopg2 installed successfully.")
        except Exception as e:
            logger.error(f"Failed to install psycopg2: {e}")
            sys.exit(1)

def migrate():
    # 依存関係チェック
    install_dependencies()
    import psycopg2
    from psycopg2.extras import execute_values

    sqlite_path = '/app/data/mcp.db'
    pg_url = os.environ.get('DATABASE_URL')

    # 環境変数のサニタイズ（サーバー環境等で末尾にゴミが付く場合への対策）
    if pg_url:
        pg_url = pg_url.strip().rstrip('}').strip('"').strip("'")
        
        # デバッグログ: URLの先頭を確認（パスワード漏洩防止のため一部のみ）
        logger.info(f"DEBUG: DATABASE_URL starts with: {pg_url[:20]}...")

        # スキーム補完: postgresql:// がない場合は付与
        if not pg_url.startswith('postgresql://') and not pg_url.startswith('postgres://'):
            logger.warning("DATABASE_URL missing scheme. Appending 'postgresql://'")
            pg_url = 'postgresql://' + pg_url

    if not os.path.exists(sqlite_path):
        logger.warning(f"SQLite database not found at {sqlite_path}. Skipping migration.")
        return

    if not pg_url or 'sqlite' in pg_url:
        logger.error("DATABASE_URL is not set to PostgreSQL. Check your environment variables.")
        return

    logger.info("Starting migration from SQLite to PostgreSQL...")
    logger.info(f"Source: {sqlite_path}")
    
    # パスワードなどをマスクして表示
    safe_pg_url = pg_url.split('@')[-1] if '@' in pg_url else '***'
    logger.info(f"Target: PostgreSQL ({safe_pg_url})")

    # PostgreSQL接続
    try:
        # URLをパースしてキーワード引数として渡す（psycopg2のURIパース問題を回避）
        parsed_url = urlparse(pg_url)
        username = parsed_url.username
        password = parsed_url.password
        # pathの先頭の / を除去
        database = parsed_url.path[1:] if parsed_url.path.startswith('/') else parsed_url.path
        hostname = parsed_url.hostname
        port = parsed_url.port

        # DB名のサニタイズ（環境変数が二重になっている場合等の対策）
        if database and ('@' in database or '/' in database):
            logger.warning(f"DEBUG: database name '{database}' looks suspicious. Resetting to 'mcp'.")
            database = 'mcp'

        logger.info(f"DEBUG: Parsed connection info - Host: {hostname}, Port: {port}, DB: {database}, User: {username}")

        pg_conn = psycopg2.connect(
            database=database,
            user=username,
            password=password,
            host=hostname,
            port=port
        )
        pg_cursor = pg_conn.cursor()
    except Exception as e:
        logger.error(f"Failed to connect to PostgreSQL: {e}")
        sys.exit(1)

    # SQLite接続
    try:
        sqlite_conn = sqlite3.connect(sqlite_path)
        sqlite_conn.row_factory = sqlite3.Row
        sqlite_cursor = sqlite_conn.cursor()
    except Exception as e:
        logger.error(f"Failed to connect to SQLite: {e}")
        sys.exit(1)

    # テーブル一覧取得
    sqlite_cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = [row['name'] for row in sqlite_cursor.fetchall()]

    # 外部キー制約を一時無効化（PostgreSQL）
    try:
        pg_cursor.execute("SET session_replication_role = 'replica';")
        # 設定が効いているか確認
        pg_cursor.execute("SHOW session_replication_role;")
        role = pg_cursor.fetchone()[0]
        logger.info(f"session_replication_role set to: {role}")
    except Exception as e:
        logger.warning(f"Failed to set session_replication_role: {e}")

    try:
        # 既存データの消去 (TRUNCATE)
        # 初期データとの衝突を避けるため、移行対象のテーブルを空にする
        logger.info("Clearing existing data in PostgreSQL...")
        for table in tables:
            # PostgreSQLにテーブルが存在するか確認
            pg_cursor.execute(
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = %s)",
                (table,)
            )
            if pg_cursor.fetchone()[0]:
                logger.info(f"  Truncating {table}...")
                # CASCADEを付けて依存関係ごと消去
                pg_cursor.execute(f"TRUNCATE TABLE {table} CASCADE")

        # データ移行
        for table in tables:
            logger.info(f"Processing table: {table}")
            
            # SQLiteからデータ取得
            sqlite_cursor.execute(f"SELECT * FROM {table}")
            rows = sqlite_cursor.fetchall()
            
            if not rows:
                logger.info(f"  No data in {table}. Skipping.")
                continue

            # PostgreSQLの型情報を取得
            pg_cursor.execute(
                "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = %s",
                (table,)
            )
            pg_col_types = {row[0]: row[1] for row in pg_cursor.fetchall()}
            
            if not pg_col_types:
                logger.warning(f"  Table {table} not found in PostgreSQL. Skipping.")
                continue

            # カラム名取得
            columns = rows[0].keys()
            
            # PostgreSQLに存在するカラムのみを対象にする
            valid_columns = [c for c in columns if c in pg_col_types]
            if len(valid_columns) != len(columns):
                logger.warning(f"  Column mismatch in {table}. Using common columns: {valid_columns}")
            
            col_str = ', '.join([f'"{c}"' for c in valid_columns])
            
            # データ変換
            data = []
            for row in rows:
                row_data = []
                for col_name in valid_columns:
                    val = row[col_name]
                    target_type = pg_col_types.get(col_name)

                    # Boolean型への変換 (SQLiteの0/1 -> Python True/False)
                    if target_type == 'boolean' and val in (0, 1):
                        row_data.append(bool(val))
                    else:
                        row_data.append(val)
                data.append(tuple(row_data))

            query = f"INSERT INTO {table} ({col_str}) VALUES %s"
            
            try:
                execute_values(pg_cursor, query, data)
                logger.info(f"  Migrated {len(data)} rows.")
            except psycopg2.errors.UniqueViolation:
                # TRUNCATEしているので通常は発生しないはずだが、念のため
                pg_conn.rollback()
                logger.warning(f"  Unique constraint violation in {table}. Skipping batch.")
                continue
            except Exception as e:
                logger.error(f"  Error inserting into {table}: {e}")
                raise e

        pg_conn.commit()
        logger.info("Migration completed successfully.")

    except Exception as e:
        pg_conn.rollback()
        logger.error(f"Migration failed: {e}")
        sys.exit(1)
    finally:
        # 制約を戻す
        pg_cursor.execute("SET session_replication_role = 'origin';")
        pg_conn.close()
        sqlite_conn.close()

if __name__ == "__main__":
    migrate()