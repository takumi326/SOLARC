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
- 取込プロンプトの保存先 API は **`GET` / `PATCH /api/preferences/import_prompt`**（フロント既定）。`/api/user_preferences` も同じ処理の別ルートとして残しています。リバースプロキシでパスを個別に許可している場合はどちらか（または `/api/` 一括）を API に流してください。
- Render Postgres の `DATABASE_URL` は `postgresql://...` 形式をそのまま使えます（Rails の `pg` アダプタ）。

### Render: DB スキーマ（Ridgepole）

スキーマは **`rails db:migrate` ではなく** `api/db/Schemafile` を **Ridgepole** で当てます。本番 Docker イメージは **コンテナ起動時**（`api/bin/docker-start`）に一度 Ridgepole を実行してから Puma を起動するため、**Pre-Deploy（有料プラン向け）は必須ではありません**。無効化したい場合だけ API の環境変数に `SKIP_RIDGEPOLE_ON_BOOT=1` を設定してください。

手動で当て直すときは **API サービス → Shell** で:

```bash
bundle exec ridgepole -c config/database.yml -E production --apply -f db/Schemafile
```

（有料プランで Pre-Deploy を使う場合は `bash bin/render-release` を **Settings → Deploy** に設定してもよいです。起動時と二重になるので、どちらか一方にするとよいです。）

### Render 本番 Postgres に外部から接続して SQL を実行する

GUI（DBeaver / TablePlus / Beekeeper Studio など）でも **ターミナルの psql** でも同じです。

1. Render ダッシュボードで **PostgreSQL** のインスタンス（Web サービスではない）を開く。
2. 画面上部付近の **Connect**（または **Info** / **Connections**）から **External Database URL** をコピーする。中にホスト・ポート・ユーザー・DB 名・パスワードが含まれる。
3. **Inbound IP 許可**（IP Allow List）を Postgres 側で設定する。自宅のグローバル IP を追加するか、検証中のみ `0.0.0.0/0`（全世界）にするかはポリシー次第。**本番は可能なら自宅／固定 IP のみ**に絞る。
4. クライアント側で **SSL を必須**にする（接続文字列に `sslmode=require` が付いていない場合は DBeaver のドライバプロパティや「SSL」タブで有効化）。

**psql の例**（URL はダッシュボードの値に置き換え）:

```bash
psql "postgresql://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require"
```

接続できたら、通常の PostgreSQL と同様に `SELECT`、`CREATE TABLE` などを実行できます。スキーマの正本はリポジトリの `api/db/Schemafile` なので、**テーブル定義を変えたい場合はコード側を直してデプロイ**し、手元 SQL はデータ修正・調査用に使うと安全です。
