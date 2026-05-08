-- Migration 20260508_04: compliance_logs 表設定為 Append-Only（審計）
-- 目的：防止歷史審核記錄被修改，保留完整稽核軌跡
-- 依賴：20260508_02 (合規表)
-- 建立者：kuanwei
-- 日期：2026-05-08

-- ROLLBACK:
-- DROP TRIGGER IF EXISTS compliance_logs_prevent_update_delete ON compliance_logs;
-- DROP FUNCTION IF EXISTS fn_compliance_logs_prevent_update_delete();

BEGIN;

-- 建立防止 UPDATE/DELETE 的函式
CREATE OR REPLACE FUNCTION fn_compliance_logs_prevent_update_delete()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    RAISE EXCEPTION 'compliance_logs 是 Append-Only 表，不允許修改。如需改寫，請重新建立新紀錄。';
  ELSIF (TG_OP = 'DELETE') THEN
    RAISE EXCEPTION 'compliance_logs 不允許刪除，以保留完整稽核記錄。';
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 綁定 trigger
CREATE TRIGGER compliance_logs_prevent_update_delete
AFTER UPDATE OR DELETE ON compliance_logs
FOR EACH ROW
EXECUTE FUNCTION fn_compliance_logs_prevent_update_delete();

COMMIT;
