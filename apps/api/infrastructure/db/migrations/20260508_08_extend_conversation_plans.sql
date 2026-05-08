-- Migration 20260508_08: 擴充 conversation_plans 表（商談前/中/後）
-- 目的：支援 Epic B 商談副駕駛的前/中/後三個階段提示
-- 依賴：conversation_plans 表已存在
-- 建立者：kuanwei
-- 日期：2026-05-08

-- ROLLBACK:
-- ALTER TABLE conversation_plans
-- DROP COLUMN IF EXISTS in_session_advisor_text,
-- DROP COLUMN IF EXISTS post_followup_draft,
-- DROP COLUMN IF EXISTS in_session_generated_at,
-- DROP COLUMN IF EXISTS post_followup_generated_at;

BEGIN;

-- 擴充 conversation_plans 表，新增商談中與商談後欄位
ALTER TABLE conversation_plans
ADD COLUMN IF NOT EXISTS in_session_advisor_text text, -- 商談中臨場話術
ADD COLUMN IF NOT EXISTS in_session_generated_at timestamptz,
ADD COLUMN IF NOT EXISTS post_followup_draft text, -- 商談後跟進草稿
ADD COLUMN IF NOT EXISTS post_followup_generated_at timestamptz,
ADD COLUMN IF NOT EXISTS llm_model text, -- 記錄產生此摘要的 LLM 模型版本
ADD COLUMN IF NOT EXISTS llm_tokens_used int; -- 消耗的 token 數

-- 新增索引以加速查詢
CREATE INDEX IF NOT EXISTS idx_conversation_plans_generated ON conversation_plans(
  CASE WHEN in_session_advisor_text IS NOT NULL THEN generated_at END
);
CREATE INDEX IF NOT EXISTS idx_conversation_plans_post_followup ON conversation_plans(
  CASE WHEN post_followup_draft IS NOT NULL THEN post_followup_generated_at END
);

-- 新增建立商談前後觸發器，自動設定 generated_at
CREATE OR REPLACE FUNCTION fn_update_conversation_generation_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF NEW.briefing_summary IS NOT NULL AND NEW.generated_at IS NULL THEN
      NEW.generated_at := NOW();
    END IF;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.in_session_advisor_text IS DISTINCT FROM NEW.in_session_advisor_text
       AND NEW.in_session_advisor_text IS NOT NULL
       AND NEW.in_session_generated_at IS NULL THEN
      NEW.in_session_generated_at := NOW();
    END IF;

    IF OLD.post_followup_draft IS DISTINCT FROM NEW.post_followup_draft
       AND NEW.post_followup_draft IS NOT NULL
       AND NEW.post_followup_generated_at IS NULL THEN
      NEW.post_followup_generated_at := NOW();
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS conversation_plans_generation_timestamps ON conversation_plans;

CREATE TRIGGER conversation_plans_generation_timestamps
BEFORE INSERT OR UPDATE ON conversation_plans
FOR EACH ROW
EXECUTE FUNCTION fn_update_conversation_generation_timestamps();

-- 新增註解指南
-- 欄位使用說明：
-- - briefing_summary：商談前 5 分鐘摘要（既有）
-- - in_session_advisor_text：商談中即時話術提示（新增）
--   包含：產品銜接話術、可能異議與建議回覆、柔性成交邀約
-- - post_followup_draft：商談後跟進訊息草稿（新增）
--   自動帶入 48h/7d/30d 排程建議

COMMIT;
