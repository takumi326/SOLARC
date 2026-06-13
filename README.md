# SOLARC
収支の予実をまとめるアプリ。

## Project Structure

- `ignore/`: planning/design source docs (not tracked in git)
- `docs/`: ローカル用メモ（git 管理外）
- リポジトリ直下: Rails アプリ（HTML UI）

## Current Status

- 本番 UI は Render 上の Rails HTML（`https://solarc.onrender.com`）
- 旧 React フロント（`web/`）と Vercel デプロイは廃止

### Vercel 連携の解除（PR マージ後に1回）

リポジトリ直下の `vercel.json` で Git 連携デプロイは無効化済み。PR に **Vercel** チェックが残る場合はダッシュボード側で外す:

1. [Vercel](https://vercel.com) → プロジェクト `solarc` → **Settings** → **Delete Project**（または Pause）
2. GitHub → リポジトリ **Settings** → **Integrations** → **Vercel** → **Configure** → このリポジトリの連携を解除
3. （任意）**Settings** → **Branches** → 必須チェックから **Vercel** を外し **CI** のみにする

## Docker Development

Start all services:

```bash
docker compose up --build
```

Endpoints:

- App: `http://localhost:3000`
- DB: `localhost:5432` (PostgreSQL 16)

DBeaver などでローカル DB を見るときは、デフォルトのデータベース名 **`solarc_development`**（ユーザー `postgres` / パスワード `postgres`）を開いてください。`postgres` という名前の管理用 DB だけを見ているとテーブルが空に見えます。

### 初回・DB 作り直し後（Docker）

次で development に migration を当て、`db:seed` まで実行します（`solarc_test` 用の prepare も続けて実行）。

```bash
chmod +x bin/docker-db-bootstrap   # 初回のみ
bin/docker-db-bootstrap
```

手動で行う場合は `docker compose run --rm app bash -lc "..."`（このファイルの「DB を作り直すとき」節）でも構いません。

`db:seed` は development では **当月分の実績デモ**（取引・月末残高）も入ります。ダッシュで「実」が出るか確認する用途です。テスト環境ではこのブロックは実行されません。

Stop:

```bash
docker compose down
```

DB を作り直すときは `docker compose down -v` でボリュームを削除してから `docker compose up --build` してください。初回はテスト用 DB を作成してから migrate と seed:

```bash
docker compose run --rm app bash -lc "RAILS_ENV=test bundle exec rails db:create"
docker compose run --rm app bash -lc "bundle exec rails db:migrate && bundle exec rails db:seed"
docker compose run --rm app bash -lc "bundle exec rails db:test:prepare"
```

`solarc_test` が無いエラーが出たら、上の `rails db:create` を実行するか、`docker compose down -v` でボリュームを消してから `up` し直してください（`docker/postgres-init` で `solarc_test` が作られます）。

## Login

- 本番: **Google OAuth**（OmniAuth）+ Rails セッション。`GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` が必要。
- ローカル development: 認証スキップ（そのまま画面利用可）。

Render 本番の主な環境変数:

```bash
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
ALLOWED_HOSTS=solarc.onrender.com
ALLOWED_EMAILS=foo@example.com
DATABASE_URL=postgresql://...@...pooler.supabase.com:5432/postgres?sslmode=require
SECRET_KEY_BASE=...
```

## Production / CD

- 想定構成: **App=Render**（Rails HTML） / **DB=Supabase PostgreSQL**
- 本番 URL 例: `https://solarc.onrender.com`
- `main` への push で `.github/workflows/cd.yml` が Docker イメージを GHCR に push します（`ghcr.io/<owner>/SOLARC/solarc:latest`）。
- Render 側は GitHub 連携または GHCR イメージでデプロイ。Pre-Deploy Command は `bash bin/render-release`。
- 本番では `ALLOWED_HOSTS` / `GOOGLE_CLIENT_*` / `ALLOWED_EMAILS` / `DATABASE_URL` / `SECRET_KEY_BASE` を設定してください。

#### Render ダッシュボード（PR #88 マージ後に必須）

`api/` を廃止したため、**Root Directory に `api` を入れたままだとデプロイが失敗**します（`Root directory "api" does not exist`）。

1. [Render](https://dashboard.render.com) → サービス `solarc` → **Settings**
2. **Root Directory** を **空** にする（`.` ではなく未入力）
3. **Dockerfile Path** を `Dockerfile`（リポジトリ直下）にする
4. **Pre-Deploy Command** を `bash bin/render-release` にする
5. GHCR イメージデプロイの場合: イメージを `ghcr.io/takumi326/SOLARC/solarc:latest` に更新（旧 `.../api:latest` は使わない）
6. **Manual Deploy** → Deploy latest commit

リポジトリ直下の `render.yaml` が Blueprint 用の正しいパス設定の参考です。

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

スキーマの正本は `db/migrate/` と `db/schema.rb`。

**本番（Render + Supabase pooler）ではデプロイ時に `rails db:migrate` が自動実行される**（Render **Pre-Deploy Command**: `bash bin/render-release`）。Session pooler 経由でも migration は introspection 不要のため Ridgepole より安定。

Render ダッシュボードで **Pre-Deploy Command** に `bash bin/render-release` が未設定だと、起動時 migration は走らない（`bin/docker-start` では migrate しない）。

#### Render 本番の主な環境変数

| 変数 | 用途 |
|---|---|
| `DATABASE_URL` | Supabase Session pooler |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Rails HTML の Google ログイン |
| `ALLOWED_HOSTS` | 例: `solarc.onrender.com` |
| `ALLOWED_EMAILS` | ログイン許可メール |
| `SECRET_KEY_BASE` | セッション署名 |

#### 既存 Supabase（Ridgepole 時代）への初回切り替え

テーブルは既にあるため、初回デプロイ前に Supabase **SQL Editor** で baseline を実行:

```sql
INSERT INTO schema_migrations (version)
VALUES ('20250613000000')
ON CONFLICT (version) DO NOTHING;
```

（`db/supabase/20250613000000_baseline_schema_migrations.sql` と同内容）

その後のデプロイでは未適用 migration のみ実行される（例: `add_watched_to_stocks`）。

#### スキーマを変える手順

1. `rails generate migration ...` で `db/migrate/` に追加して PR / マージ
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
