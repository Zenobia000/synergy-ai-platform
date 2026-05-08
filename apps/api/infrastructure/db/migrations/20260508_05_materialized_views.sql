-- Migration 20260508_05: 建立物化視圖（Activity Tracking）
-- 目的：M6 輕量版使用物化視圖聚合指標（ADR-012）
-- 依賴：leads, conversation_plans, follow_up_tasks, compliance_logs 表已存在
-- 建立者：kuanwei
-- 日期：2026-05-08

-- ROLLBACK:
-- DROP MATERIALIZED VIEW IF EXISTS mv_leader_summary CASCADE;
-- DROP MATERIALIZED VIEW IF EXISTS mv_coach_weekly_stats CASCADE;

BEGIN;

-- 教練週統計物化視圖
CREATE MATERIALIZED VIEW mv_coach_weekly_stats AS
SELECT
  l.coach_id,
  l.tenant_id,
  DATE_TRUNC('week', l.created_at)::date AS week_start,
  COUNT(DISTINCT l.id) AS questionnaire_count,
  COUNT(DISTINCT cp.id) AS briefing_count,
  COUNT(DISTINCT CASE WHEN l.status = 'completed' THEN l.id END) AS deal_count,
  COUNT(DISTINCT fup.id) AS followup_count,
  COUNT(DISTINCT CASE WHEN cl.risk_level = 'high' THEN cl.id END) AS high_risk_count,
  -- 計算 48h 跟進率 TODO: 補充邏輯
  ROUND(
    CASE
      WHEN COUNT(DISTINCT CASE WHEN fup.due_at IS NOT NULL THEN fup.id END) = 0 THEN 0
      ELSE COUNT(DISTINCT CASE WHEN fup.sent_at IS NOT NULL THEN fup.id END)::numeric
           / COUNT(DISTINCT CASE WHEN fup.due_at IS NOT NULL THEN fup.id END)
    END * 100, 2
  ) AS followup_completion_rate,
  NOW() AS view_refreshed_at
FROM
  leads l
  LEFT JOIN conversation_plans cp ON l.id = cp.lead_id
  LEFT JOIN follow_up_tasks fup ON l.id = fup.lead_id
  LEFT JOIN compliance_logs cl ON l.id = cl.created_by
WHERE
  DATE_TRUNC('week', l.created_at) >= DATE_TRUNC('week', NOW() - interval '8 weeks')
GROUP BY
  l.coach_id, l.tenant_id, DATE_TRUNC('week', l.created_at)
ORDER BY
  week_start DESC, l.coach_id;

CREATE INDEX idx_mv_coach_weekly_stats_coach ON mv_coach_weekly_stats(coach_id, week_start);

-- Leader 總結物化視圖（跨 Coach 彙總）
CREATE MATERIALIZED VIEW mv_leader_summary AS
SELECT
  l.tenant_id,
  DATE_TRUNC('week', l.created_at)::date AS week_start,
  COUNT(DISTINCT l.coach_id) AS coach_count,
  COUNT(DISTINCT l.id) AS total_questionnaires,
  COUNT(DISTINCT CASE WHEN l.status = 'completed' THEN l.id END) AS total_deals,
  -- 漏斗轉換率
  ROUND(
    CASE
      WHEN COUNT(DISTINCT l.id) = 0 THEN 0
      ELSE COUNT(DISTINCT CASE WHEN l.status = 'completed' THEN l.id END)::numeric / COUNT(DISTINCT l.id) * 100
    END, 2
  ) AS conversion_rate,
  COUNT(DISTINCT CASE WHEN cl.risk_level IN ('high', 'medium') THEN cl.id END) AS compliance_review_count,
  NOW() AS view_refreshed_at
FROM
  leads l
  LEFT JOIN compliance_logs cl ON l.id = cl.created_by
WHERE
  DATE_TRUNC('week', l.created_at) >= DATE_TRUNC('week', NOW() - interval '8 weeks')
GROUP BY
  l.tenant_id, DATE_TRUNC('week', l.created_at)
ORDER BY
  week_start DESC;

CREATE INDEX idx_mv_leader_summary_tenant ON mv_leader_summary(tenant_id, week_start);

COMMIT;
