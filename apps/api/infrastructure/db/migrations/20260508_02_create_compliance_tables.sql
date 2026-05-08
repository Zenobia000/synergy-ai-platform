-- Migration 20260508_02: 建立合規相關表（compliance_logs + hitl_items + onboarding_tasks）
-- 目的：儲存合規檢查日誌、HITL 審核項目、新手教練進度
-- 依賴：20260508_01 (reviewer 角色)
-- 建立者：kuanwei
-- 日期：2026-05-08

-- ROLLBACK:
-- DROP TABLE IF EXISTS onboarding_tasks CASCADE;
-- DROP TABLE IF EXISTS hitl_items CASCADE;
-- DROP TABLE IF EXISTS compliance_logs CASCADE;
-- DROP TYPE IF EXISTS risk_level CASCADE;
-- DROP TYPE IF EXISTS compliance_category CASCADE;
-- DROP TYPE IF EXISTS hitl_decision CASCADE;

BEGIN;

-- Compliance 相關 Enum
CREATE TYPE compliance_category AS ENUM ('C1', 'C2', 'C3', 'C4');
CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high');
CREATE TYPE hitl_decision AS ENUM ('approved', 'rejected', 'rewritten', 'escalated');

-- 合規日誌表
CREATE TABLE compliance_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id text NOT NULL DEFAULT 'synergy',
  content_type text NOT NULL, -- 'briefing_summary', 'coaching_script', 'follow_up_draft', 'invitation_text'
  original_text text NOT NULL,
  rewritten_text text,
  risk_level risk_level NOT NULL DEFAULT 'low',
  categories compliance_category[] DEFAULT ARRAY[]::compliance_category[],
  rule_keywords text[] DEFAULT ARRAY[]::text[], -- Layer 1 命中的關鍵詞
  llm_model text, -- Layer 2 使用的模型版本
  llm_tokens int,
  reviewed_by uuid, -- HITL 審核者 ID
  reviewed_at timestamptz,
  hitl_decision hitl_decision,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT fk_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES auth.users(id),
  CONSTRAINT fk_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id)
);

-- HITL 佇列項目表
CREATE TABLE hitl_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id text NOT NULL DEFAULT 'synergy',
  compliance_log_id uuid NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'reviewing', 'approved', 'rejected', 'overdue'
  assigned_to uuid, -- 審核員
  due_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT fk_compliance_log FOREIGN KEY (compliance_log_id) REFERENCES compliance_logs(id),
  CONSTRAINT fk_assigned_to FOREIGN KEY (assigned_to) REFERENCES auth.users(id)
);

-- 新手教練 Onboarding 進度表
CREATE TABLE onboarding_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id text NOT NULL DEFAULT 'synergy',
  coach_id uuid NOT NULL,
  task_key text NOT NULL, -- 'bind-line-oa', 'first-deal', 'briefing-3x', etc.
  completed_at timestamptz,
  evidence_url text, -- 可選證據連結
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT fk_coach FOREIGN KEY (coach_id) REFERENCES auth.users(id),
  UNIQUE(tenant_id, coach_id, task_key)
);

-- 索引
CREATE INDEX idx_compliance_logs_tenant_created ON compliance_logs(tenant_id, created_at);
CREATE INDEX idx_compliance_logs_risk_level ON compliance_logs(risk_level);
CREATE INDEX idx_hitl_items_status ON hitl_items(status);
CREATE INDEX idx_hitl_items_due_at ON hitl_items(due_at);
CREATE INDEX idx_onboarding_tasks_coach ON onboarding_tasks(coach_id);

COMMIT;
