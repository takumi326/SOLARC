# SOLARC

収支の予実をまとめる Web アプリ（Rails + PostgreSQL）。

- 家計の予算・実績・Forecast
- 株式のタイムライン・取引メモ

ローカル development では認証なしで利用できます。

## ローカルで動かす

Docker Compose を使います。

```bash
docker compose up --build
```

- アプリ: http://localhost:3000
- DB: `localhost:5432`（PostgreSQL 16 / ユーザー `postgres` / パスワード `postgres`）

### 初回・DB 作り直し後

```bash
chmod +x bin/docker-db-bootstrap   # 初回のみ
bin/docker-db-bootstrap
```

migration・seed・テスト DB の prepare まで一括で実行します。

### 停止

```bash
docker compose down
```

DB ごと作り直す場合:

```bash
docker compose down -v
docker compose up --build
bin/docker-db-bootstrap
```

## 本番構成

| 項目 | 内容 |
|---|---|
| URL | https://solarc.onrender.com |
| アプリ | Render（Docker / Rails HTML） |
| DB | Supabase PostgreSQL（Session pooler） |
| 認証 | Google OAuth + Rails セッション |

`main` への push / merge で **Render Auto-Deploy** が Docker イメージをビルドしてデプロイします（GitHub Actions の CD は使いません。CI は PR / `main` の lint・test のみ）。

起動時は `bin/docker-start` が `db:migrate` → Puma 起動の順で実行します（Render Free は Pre-Deploy 不可）。

### Auto-Deploy の確認（Render）

1. [Render Dashboard](https://dashboard.render.com/) → サービス `solarc` を開く
2. **Settings** → **Build & Deploy**
3. **Branch** が `main` であること
4. **Auto-Deploy** が `Yes`（または On）であること
5. **Repository** が `takumi326/SOLARC` に繋がっていること

手動デプロイしていた場合は Auto-Deploy を On にすれば、以降は `main` 更新だけで反映されます。

### 環境変数（Render）

| 変数 | 用途 |
|---|---|
| `RAILS_ENV` | `production` |
| `DATABASE_URL` | Supabase Session pooler（`?sslmode=require`） |
| `SECRET_KEY_BASE` | セッション署名 |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google ログイン |
| `ALLOWED_HOSTS` | `solarc.onrender.com` |
| `ALLOWED_EMAILS` | ログイン許可メール（カンマ区切り） |
| `WEB_CONCURRENCY` | `0`（Free プラン推奨） |

`DATABASE_URL` は Supabase の **Session pooler**（`pooler.supabase.com:5432`）を使ってください。Direct connection（`db.*.supabase.co`）は Render から届かないことがあります。

スキーマの正本は `db/migrate/` と `db/schema.rb` です。
