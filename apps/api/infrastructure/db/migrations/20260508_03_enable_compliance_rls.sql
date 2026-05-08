-- Migration 20260508_03: 啟用合規表的 RLS（預留，MVP 不啟用）
-- 目的：設定 Row-Level Security policy（Phase 2 啟用）
-- 依賴：20260508_02 (合規表)
-- 建立者：kuanwei
-- 日期：2026-05-08

-- ROLLBACK:
-- ALTER TABLE compliance_logs DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE hitl_items DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE onboarding_tasks DISABLE ROW LEVEL SECURITY;
-- DROP POLICY IF EXISTS compliance_logs_select_policy ON compliance_logs;
-- DROP POLICY IF EXISTS hitl_items_select_policy ON hitl_items;
-- DROP POLICY IF EXISTS onboarding_tasks_select_policy ON onboarding_tasks;

BEGIN;

-- MVP 不啟用 RLS，但預留 policy 定義供 Phase 2 使用

-- 合規日誌 Policy（按 tenant_id 隔離）
-- TODO: Phase 2 啟用時執行
-- ALTER TABLE compliance_logs ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY compliance_logs_select_policy ON compliance_logs
--   FOR SELECT USING (tenant_id = current_setting('app.tenant_id'));
-- CREATE POLICY compliance_logs_insert_policy ON compliance_logs
--   FOR INSERT WITH CHECK (tenant_id = current_setting('app.tenant_id'));

-- HITL 項目 Policy
-- TODO: Phase 2 啟用時執行
-- ALTER TABLE hitl_items ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY hitl_items_select_policy ON hitl_items
--   FOR SELECT USING (tenant_id = current_setting('app.tenant_id'));

-- Onboarding 進度 Policy
-- TODO: Phase 2 啟用時執行
-- ALTER TABLE onboarding_tasks ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY onboarding_tasks_select_policy ON onboarding_tasks
--   FOR SELECT USING (tenant_id = current_setting('app.tenant_id'));

-- 註解：MVP tenant_id 固定為 'synergy'，不使用 current_setting

COMMIT;
