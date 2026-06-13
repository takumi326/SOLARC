-- PR #86 の migration が Render Pre-Deploy で未適用のとき用（Supabase SQL Editor で実行）。
-- 通常は Render デプロイ時の `rails db:migrate` に任せてください。

ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS import_claude_prompt_template text;

CREATE TABLE IF NOT EXISTS finance_import_drafts (
  id bigserial PRIMARY KEY,
  owner_key character varying NOT NULL,
  raw_json text,
  pending_rows jsonb NOT NULL DEFAULT '[]'::jsonb,
  selected_lines jsonb NOT NULL DEFAULT '[]'::jsonb,
  compare_month character varying,
  phase character varying NOT NULL DEFAULT 'edit',
  created_at timestamp(6) NOT NULL DEFAULT now(),
  updated_at timestamp(6) NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS index_finance_import_drafts_on_owner_key
  ON finance_import_drafts (owner_key);

INSERT INTO schema_migrations (version)
VALUES
  ('20260613110039'),
  ('20260613110304')
ON CONFLICT (version) DO NOTHING;
