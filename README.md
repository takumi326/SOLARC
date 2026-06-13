# SOLARC
収支の予実をまとめるアプリ。

## Project Structure

- `ignore/`: planning/design source docs (not tracked in git)
- `docs/`: consolidated decisions for implementation
- `api/`: Rails API (to be implemented)
- `web/`: React + TypeScript frontend (to be implemented)

## Current Status

- Design docs were prepared first.
- Initial implementation decisions and task breakdown are documented in `docs/`.

## Docker Development

Start all services:

```bash
docker compose up --build
```

Endpoints:

- Web: `http://localhost:5173`
- API: `http://localhost:3000`
- DB: `localhost:5432` (PostgreSQL 16)

DBeaver などでローカル DB を見るときは、デフォルトのデータベース名 **`iae_management_development`**（ユーザー `postgres` / パスワード `postgres`）を開いてください。`postgres` という名前の管理用 DB だけを見ているとテーブルが空に見えます。

### 初回・DB 作り直し後（Docker）

次で development に migration を当て、`db:seed` まで実行します（`api_test` 用の prepare も続けて実行）。

```bash
chmod +x scripts/docker-db-bootstrap.sh   # 初回のみ
./scripts/docker-db-bootstrap.sh
```

手動で行う場合は従来どおり `docker compose run --rm api bash -lc "cd /app/api && ..."`（このファイルの「DB を作り直すとき」節）でも構いません。

`db:seed` は development では **当月分の実績デモ**（取引・月末残高）も入ります。ダッシュで「実」が出るか確認する用途です。テスト環境ではこのブロックは実行されません。

Stop:

```bash
docker compose down
```

### Web: `node_modules` / Vite の import 解決

Web は `./web/node_modules` を bind マウント上に置き、起動時に `npm ci` で `package-lock.json` と揃えます。依存を変えたら **Web コンテナを再起動**（または `down` → `up`）すれば反映されます。

`Failed to resolve import "@supabase/supabase-js"` が **変わらない**ときは、まず **リポジトリを最新にしてから** 次を順に試してください。

```bash
git pull origin main
docker compose down
docker volume ls | grep web_node_modules   # 残っていれば削除（例: iae-management_web_node_modules）
docker volume rm <上で見つかった名前>
docker compose up --build -d
```

古い compose で名前付きボリューム `web_node_modules` を使っていた環境では、そのボリュームだけが残っているとコンテナ内とホストの `node_modules` がずれることがあります。`docker volume rm` で捨ててから `up` してください。

DB を作り直すときは `docker compose down -v` でボリュームを削除してから `docker compose up --build` してください。初回はテスト用 DB を作成してから migrate と seed:

```bash
docker compose run --rm api bash -lc "cd /app/api && RAILS_ENV=test bundle exec rails db:create"
docker compose run --rm api bash -lc "cd /app/api && bundle exec rails db:migrate && bundle exec rails db:seed"
docker compose run --rm api bash -lc "cd /app/api && bundle exec rails db:test:prepare"
```

`api_test` が無いエラーが出たら、上の `rails db:create` を実行するか、`docker compose down -v` でボリュームを消してから `up` し直してください（`docker/postgres-init` で `api_test` が作られます）。

## Login (Supabase Auth)

- 認証は Supabase Auth (Google provider) を利用します。
- Web は Supabase で取得した access token を `Authorization: Bearer ...` として API に送信します。
- API は Supabase の JWKS（公開鍵）で JWT を検証し、`ALLOWED_EMAILS` が設定されている場合は allowlist チェックを行います。
- ローカル開発では `development` 環境のため API 側認証をスキップします（開発速度優先）。

必要な環境変数:

```bash
# Web
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_ANON_KEY=<supabase-anon-key>
# Web と API が別オリジンのとき必須（Vite のビルド時に埋め込まれる）。未設定だと /api/* が静的ホストに飛び 404 になる。
VITE_API_BASE_URL=https://<your-api-host>

# API
SUPABASE_URL=https://<project-ref>.supabase.co
ALLOWED_EMAILS=foo@example.com,bar@example.com
```

## Production / CD

- 想定構成: Web=Vercel / API=Render / Auth=Supabase
- **Web を API と別ドメインで配信する場合**、`docker compose` のローカル用 `VITE_API_BASE_URL` と同様に、本番のフロントビルド（Vercel の Environment Variables など）に **`VITE_API_BASE_URL`** を必ず入れてください（API のオリジンのみ、パスなし・末尾 `/` なし）。これが無いとブラウザは `https://<web>/api/...` にリクエストし、静的ホスト側が **404** を返します。同一ドメインでリバースプロキシが `/api` を API に流す構成なら空のままでよいです。
- `main` への push で `.github/workflows/cd.yml` が実行され、API/Web の Docker イメージを GHCR (`ghcr.io/<owner>/<repo>`) に push します。
- デプロイを自動化する場合は、次の GitHub Secrets を設定してください。
  - `DEPLOY_HOST`
  - `DEPLOY_USER`
  - `DEPLOY_SSH_KEY`
  - `DEPLOY_PORT` (任意)
  - `DEPLOY_APP_DIR` (サーバー上で `docker compose` を実行するディレクトリ)
- API 本番では `ALLOWED_HOSTS` / `CORS_ORIGINS`（カンマ区切り）と `SUPABASE_URL` / `ALLOWED_EMAILS` を設定してください。
- 取込プロンプトの保存先 API は **`GET` / `PATCH /api/preferences/import_prompt`**（フロント既定）。`/api/user_preferences` も同じ処理の別ルートとして残しています。リバースプロキシでパスを個別に許可している場合はどちらか（または `/api/` 一括）を API に流してください。

### 本番 DB（Supabase PostgreSQL）

- **DB は Supabase PostgreSQL**（認証も同じ Supabase プロジェクト）。Render Postgres は使わない。
- Render API の `DATABASE_URL` は **Session pooler**（IPv4）を使う。末尾に `?sslmode=require` を付ける。

```
postgresql://postgres.<project-ref>:<password>@aws-<n>-<region>.pooler.supabase.com:5432/postgres?sslmode=require
```

- **Direct connection**（`db.<project-ref>.supabase.co`、IPv6）は Render や Docker から届かないことが多い。**本番の `DATABASE_URL` に使わない。**
- 接続文字列は Supabase ダッシュボード上部の **Connect** → **Session pooler** からコピーする（Project Settings 内の「Connection string」欄は UI 変更で無い場合がある）。
- DB パスワードは **Database → Configuration** でリセットできる（既存パスワードは表示されない）。

### 本番スキーマ管理（Rails migration + Supabase）

スキーマの正本は `api/db/migrate/` と `api/db/schema.rb`。

**本番（Render + Supabase pooler）ではデプロイ時に `rails db:migrate` が自動実行される**（`bin/docker-start` / `bin/render-release`）。Session pooler 経由でも migration は introspection 不要のため Ridgepole より安定。

#### 既存 Supabase（Ridgepole 時代）への初回切り替え

テーブルは既にあるため、初回デプロイ前に Supabase **SQL Editor** で baseline を実行:

```sql
INSERT INTO schema_migrations (version)
VALUES ('20250613000000')
ON CONFLICT (version) DO NOTHING;
```

（`api/db/supabase/20250613000000_baseline_schema_migrations.sql` と同内容）

その後のデプロイでは未適用 migration のみ実行される（例: `add_watched_to_stocks`）。

#### スキーマを変える手順

1. `rails generate migration ...` で `api/db/migrate/` に追加して PR / マージ
2. ローカルで `rails db:migrate` → `schema.rb` 更新をコミット
3. Render にデプロイ（`db:migrate` 自動実行）

#### データ移行（Render Postgres → Supabase）のメモ

初回移行時のみ。通常運用では不要。

1. Render Postgres から `pg_dump`（外部 URL、`sslmode=require`）
2. Supabase に migration または SQL でスキーマ作成
3. `pg_restore --data-only` は FK 順のため失敗しやすい。次のどちらか:
   - `pg_restore` 前に SQL を `restore_data.sql` に落とし、psql で `SET session_replication_role = replica;` してから `\i`
   - 親テーブルから順に `pg_restore -t <table>`

`pg_restore --disable-triggers` は Supabase では権限エラーになる。

### Supabase で SQL を実行する

- **SQL Editor**: 左サイドバー → `SQL Editor` → `New query` → 貼り付け → `Run`
- 直接 URL: `https://supabase.com/dashboard/project/<project-ref>/sql/new`
- テーブル確認: **Table Editor** または `SELECT COUNT(*) FROM ...`
