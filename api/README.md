# API

Rails API for SOLARC.

## Database (Active Record migrations)

Schema is defined in `api/db/migrate/` and dumped to `api/db/schema.rb`.

Apply pending migrations:

```bash
bundle exec rails db:migrate
```

Prepare test database:

```bash
bundle exec rails db:test:prepare
```

## Production (Render + Supabase)

本番 DB は **Supabase PostgreSQL**。Render API の `DATABASE_URL` は Session pooler を使う。

デプロイ時に **`rails db:migrate`** が自動実行される（`bin/docker-start` / `bin/render-release`）。

既存 Supabase（Ridgepole 時代）への初回切り替え時は `api/db/supabase/20250613000000_baseline_schema_migrations.sql` を SQL Editor で実行してからデプロイする。詳細はリポジトリルートの `README.md` と `.cursor/rules/supabase-production-db.mdc` を参照。
