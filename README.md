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
