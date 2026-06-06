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

次で development に Ridgepole を当て、`db:seed` まで実行します（`api_test` 用の Ridgepole も続けて実行）。

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

DB を作り直すときは `docker compose down -v` でボリュームを削除してから `docker compose up --build` してください。初回はテスト用 DB を作成してから ridgepole と seed:

```bash
docker compose run --rm api bash -lc "cd /app/api && RAILS_ENV=test bundle exec rails db:create"
docker compose run --rm api bash -lc "cd /app/api && bundle exec ridgepole -c config/database.yml -E development --apply -f db/Schemafile && bundle exec rails db:seed"
docker compose run --rm api bash -lc "cd /app/api && bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile"
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
<<<<<<< Updated upstream
- 取込プロンプトの保存先 API は **`GET` / `PATCH /api/preferences/import_prompt`**（フロント既定）。`/api/user_preferences` も同じ処理の別ルートとして残しています。リバースプロキシでパスを個別に許可している場合はどちらか（または `/api/` 一括）を API に流してください。
- Render Postgres の `DATABASE_URL` は `postgresql://...` 形式をそのまま使えます（Rails の `pg` アダプタ）。
=======
>>>>>>> Stashed changes

### 本番 DB（Supabase PostgreSQL）

- **DB は Supabase PostgreSQL**（認証も同じ Supabase プロジェクト）。Render Postgres は使わない。
- Render API の `DATABASE_URL` は **Session pooler**（IPv4）を使う。末尾に `?sslmode=require` を付ける。

```
postgresql://postgres.<project-ref>:<password>@aws-<n>-<region>.pooler.supabase.com:5432/postgres?sslmode=require
```

- **Direct connection**（`db.<project-ref>.supabase.co`、IPv6）は Render や Docker から届かないことが多い。**本番の `DATABASE_URL` に使わない。**
- 接続文字列は Supabase ダッシュボード上部の **Connect** → **Session pooler** からコピーする（Project Settings 内の「Connection string」欄は UI 変更で無い場合がある）。
- DB パスワードは **Database → Configuration** でリセットできる（既存パスワードは表示されない）。

### 本番スキーマ管理（Ridgepole + Supabase）

スキーマの正本は `api/db/Schemafile`。ローカル development では Ridgepole がそのまま使える。

**本番（Render + Supabase pooler）では起動時 Ridgepole を使わない。** 次を必ず守る。

| 項目 | 設定 |
|---|---|
| Render 環境変数 | `SKIP_RIDGEPOLE_ON_BOOT=1` |
| スキーマ変更の適用先 | Supabase **SQL Editor**（左サイドバー）で手動実行 |
| Render Shell | 無料プランでは使えない前提 |

#### なぜ `SKIP_RIDGEPOLE_ON_BOOT=1` か

- `api/bin/docker-start` はデフォルトで起動時に `ridgepole --apply` を走らせる。
- Supabase **Session pooler 経由**だと Ridgepole が既存テーブルを正しく読めず、dry-run で全テーブル `create_table` と出る（DB が空だと誤認）。
- そのまま `--apply` すると `DuplicateTable` 等でデプロイが落ちる。
- データ参照（Rails / psql）は pooler で問題ない。**スキーマ introspection だけ Ridgepole と相性が悪い。**

#### スキーマを変える手順（本番）

1. `api/db/Schemafile` を編集して PR / マージ
2. Schemafile の差分に対応する SQL を書き、Supabase **SQL Editor** で実行
3. `SKIP_RIDGEPOLE_ON_BOOT=1` のまま Render にデプロイ（コード変更のみ）

ローカルで差分を眺めるとき（**本番に `--apply` しない**）:

```bash
docker compose run --rm \
  -e RAILS_ENV=production \
  -e DATABASE_URL="postgresql://postgres.<ref>:<pass>@aws-<n>-<region>.pooler.supabase.com:5432/postgres?sslmode=require" \
  api bash -lc "bundle install && bundle exec ridgepole -c config/database.yml -E production --apply -f db/Schemafile --dry-run"
```

dry-run で `create_table` が大量に出ても、pooler の誤認の可能性が高い。**SQL Editor で手動適用したうえで無視してよい。**

#### データ移行（Render Postgres → Supabase）のメモ

初回移行時のみ。通常運用では不要。

1. Render Postgres から `pg_dump`（外部 URL、`sslmode=require`）
2. Supabase に Ridgepole または SQL でスキーマ作成
3. `pg_restore --data-only` は FK 順のため失敗しやすい。次のどちらか:
   - `pg_restore` 前に SQL を `restore_data.sql` に落とし、psql で `SET session_replication_role = replica;` してから `\i`
   - 親テーブルから順に `pg_restore -t <table>`

`pg_restore --disable-triggers` は Supabase では権限エラーになる。

### Supabase で SQL を実行する

- **SQL Editor**: 左サイドバー → `SQL Editor` → `New query` → 貼り付け → `Run`
- 直接 URL: `https://supabase.com/dashboard/project/<project-ref>/sql/new`
- テーブル確認: **Table Editor** または `SELECT COUNT(*) FROM ...`
