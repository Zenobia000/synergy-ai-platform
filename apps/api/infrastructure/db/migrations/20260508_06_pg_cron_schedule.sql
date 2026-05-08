-- Migration 20260508_06: 排程物化視圖自動刷新（pg_cron）
-- 目的：每 30 分鐘刷新 Activity Tracking 物化視圖
-- 依賴：20260508_05 (物化視圖) + pg_cron 擴展已安裝
-- 建立者：kuanwei
-- 日期：2026-05-08

-- ROLLBACK:
-- SELECT cron.unschedule('refresh_mv_coach_weekly_stats');
-- SELECT cron.unschedule('refresh_mv_leader_summary');

BEGIN;

-- TODO: pg_cron 擴展需在 Supabase 管理端啟用（如尚未啟用）
-- 聯繫 Supabase 支援申請啟用 pg_cron extension

-- 刷新教練週統計視圖（每 30 分鐘執行一次）
-- SELECT cron.schedule('refresh_mv_coach_weekly_stats', '*/30 * * * *',
--   'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_coach_weekly_stats'
-- );

-- 刷新 Leader Summary 視圖（每 30 分鐘執行一次）
-- SELECT cron.schedule('refresh_mv_leader_summary', '*/30 * * * *',
--   'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_leader_summary'
-- );

-- 註解：上述排程需在 Supabase 啟用 pg_cron 後取消註解執行

COMMIT;
