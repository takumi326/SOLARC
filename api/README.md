# API

Rails API for SOLARC.

## Database (Ridgepole)

Schema is defined in `api/db/Schemafile`.

Apply schema:

```bash
bundle exec ridgepole -c config/database.yml -E development --apply -f db/Schemafile
```

Export current DB schema back to Schemafile:

```bash
bundle exec ridgepole -c config/database.yml -E development --export -f db/Schemafile
```

## Production (Render + Supabase)

本番 DB は **Supabase PostgreSQL**。Render API の `DATABASE_URL` は Session pooler を使う。

**本番では起動時 Ridgepole を無効化する**（`SKIP_RIDGEPOLE_ON_BOOT=1`）。Supabase pooler 経由では Ridgepole のスキーマ introspection が正しく動かず、デプロイが落ちるため。

スキーマ変更は `api/db/Schemafile` を編集したうえで、**Supabase SQL Editor** で手動適用する。詳細はリポジトリルートの `README.md`（「本番 DB」「本番スキーマ管理」）と `.cursor/rules/supabase-production-db.mdc` を参照。

`bin/docker-start` / `bin/render-release` の Ridgepole はローカル development や、pooler を使わない接続が確実な環境向け。
