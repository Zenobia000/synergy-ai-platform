-- Migration 20260508_07: 擴充 Lead Status 從 4 種升至 10 種（新客戶狀態機）
-- 目的：支援完整的客戶生命週期流程
-- 依賴：leads 表已存在，原有 status enum
-- 建立者：kuanwei
-- 日期：2026-05-08

-- 舊狀態（v2.0）：new_lead, contacted, deal_completed, lost
-- 新狀態（v3.0）：new_lead, questionnaire_completed, appointment_scheduled, meeting_held,
--               recommendation_made, trial_started, deal_won, deal_lost, followup_required, silent

-- ROLLBACK:
-- TODO: PostgreSQL enum 無法直接刪除，需要重建
-- 1. 建立新 enum 類型
-- 2. 改變 leads.status column 類型
-- 3. 刪除舊 enum

BEGIN;

-- 新增新狀態至既有 enum（如 v2.0 enum 仍被使用）
-- TODO: 若原有 enum 名為 lead_status，需先確認其內容
-- 若原有狀態為 status text，需改為 enum

-- 假設：原有 leads.status 是 text 型別，直接新增 enum 並轉換
-- 如果已是 enum，需要重建

-- 方案：建立新的 enum 並遷移資料
CREATE TYPE lead_status_new AS ENUM (
  'new_lead',
  'questionnaire_completed',
  'appointment_scheduled',
  'meeting_held',
  'recommendation_made',
  'trial_started',
  'deal_won',
  'deal_lost',
  'followup_required',
  'silent'
);

-- 轉換 leads.status column
ALTER TABLE leads
ALTER COLUMN status TYPE lead_status_new
USING CASE
  WHEN status = 'new_lead' THEN 'new_lead'::lead_status_new
  WHEN status = 'contacted' THEN 'appointment_scheduled'::lead_status_new
  WHEN status = 'deal_completed' THEN 'deal_won'::lead_status_new
  WHEN status = 'lost' THEN 'deal_lost'::lead_status_new
  ELSE 'new_lead'::lead_status_new -- 預設回新名單
END;

-- 移除舊 enum（如有）
-- DROP TYPE IF EXISTS lead_status;

-- 重新命名新 enum
ALTER TYPE lead_status_new RENAME TO lead_status;

-- 新增狀態流轉記錄表（稽審軌跡）
CREATE TABLE IF NOT EXISTS lead_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id text NOT NULL DEFAULT 'synergy',
  lead_id uuid NOT NULL,
  old_status lead_status,
  new_status lead_status NOT NULL,
  changed_by uuid NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now(),
  reason text,

  CONSTRAINT fk_lead FOREIGN KEY (lead_id) REFERENCES leads(id),
  CONSTRAINT fk_changed_by FOREIGN KEY (changed_by) REFERENCES auth.users(id)
);

CREATE INDEX idx_lead_status_history_lead ON lead_status_history(lead_id);
CREATE INDEX idx_lead_status_history_changed_at ON lead_status_history(changed_at);

-- 新增觸發器自動記錄狀態變化
CREATE OR REPLACE FUNCTION fn_log_lead_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO lead_status_history (lead_id, tenant_id, old_status, new_status, changed_by, changed_at)
    VALUES (NEW.id, NEW.tenant_id, OLD.status, NEW.status, NEW.updated_by, NOW());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lead_status_change_trigger
AFTER UPDATE ON leads
FOR EACH ROW
EXECUTE FUNCTION fn_log_lead_status_change();

-- TODO: 資料遷移：4 → 10 狀態對應由 PM 確認
-- 建議對應：
-- - new_lead → new_lead
-- - contacted → appointment_scheduled（需驗證是否已聯繫）
-- - deal_completed → deal_won
-- - lost → deal_lost

COMMIT;
