-- 既存 Supabase（Ridgepole 時代に作ったテーブルあり）向けの一回限りの baseline。
-- 初回 migration デプロイ前に SQL Editor で実行する。
--
-- 実行後、Render デプロイ時の `rails db:migrate` は
-- 20250613000001_add_watched_to_stocks のみ適用される（watched 列が未追加の場合）。

INSERT INTO schema_migrations (version)
VALUES ('20250613000000')
ON CONFLICT (version) DO NOTHING;
