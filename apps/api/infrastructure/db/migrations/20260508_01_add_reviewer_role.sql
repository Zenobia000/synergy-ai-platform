-- Migration 20260508_01: 新增 reviewer 角色
-- 目的：為合規審核系統新增管理者角色
-- 依賴：(無)
-- 建立者：kuanwei
-- 日期：2026-05-08

-- ROLLBACK:
-- ALTER TYPE user_role DROP VALUE 'reviewer';

BEGIN;

-- 新增 reviewer 角色至 user_role enum
ALTER TYPE user_role ADD VALUE 'reviewer' AFTER 'admin';

-- 新增 reviewers 表（若尚未存在）
-- TODO: 補充 reviewer 帳號與權限設定

COMMIT;
