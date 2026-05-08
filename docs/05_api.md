# API 設計規範 — Synergy AI Closer's Copilot

> **版本:** v3.0 | **更新:** 2026-05-08 | **狀態:** 實作基準 | **對應架構:** `docs/04_architecture.md` | **對應 Phase I MVP:** `docs/12_phase1_mvp.md`

---

## v3.0 修訂說明

本版本升級為 Phase I v3.0，新增約 20 個 endpoint：
- **ComplianceService** — 4 個（檢查、改寫、隊列、HITL 決策）
- **ConversationCoachService** — 3 個（商談前/中/後）
- **LeaderSummaryService** — 3 個（Summary、Coach 詳情、Onboarding）
- **OnboardingProgressService** — 1 個（任務完成）
- **GoogleCalendarAdapter** — 1 個（同步日曆）
- **ActivityTrackingService** — 1 個（教練統計）

**總端點數**：約 25 → 45 個

---

## 1. 設計約定

| 項目 | 規範 |
| :--- | :--- |
| **風格** | RESTful + JSON |
| **Base URL** | Production: `https://api.synergy-ai.tw/v1` / Staging: `https://api-staging.synergy-ai.tw/v1` |
| **格式** | `application/json` (UTF-8) |
| **資源路徑** | 小寫、連字符、複數（e.g., `/leads`、`/questionnaire-templates`） |
| **欄位命名** | `snake_case` |
| **日期格式** | ISO 8601 UTC（e.g., `2026-05-01T14:00:00Z`） |
| **認證** | Supabase JWT in `Authorization: Bearer <jwt>` |
| **版本控制** | URL 路徑 `/v1/...` |
| **Tenant** | 由 JWT 的 `tenant_id` claim 決定，不在 URL |

---

## 2. 通用行為

### 分頁 / 排序 / 過濾 / 冪等性

（維持既有，見原 v1.0 文件）

---

## 3. 錯誤處理

（維持既有，新增 `compliance_review_required` 錯誤碼）

| 錯誤碼 | HTTP | 描述 |
| :--- | :--- | :--- |
| `compliance_review_required` | 202 | 訊息已存入 HITL，等待審核（人工複核中） |

---

## 4. 安全性

（維持既有）

---

## 5. API 端點清單

### 既有端點（v1.0 維持不變）

5.1 問卷（Questionnaire） — 無需登入
5.2 商談摘要（Briefing）— 需教練登入
5.3 客戶管理（Leads / CRM）— 需教練登入
5.4 提醒（Reminders）— 內部 + 教練查詢
5.5 LINE 綁定 Webhook（Coach onboarding）
5.6 認證（Auth）— Supabase 直接提供

（詳見原 v1.0 文件 § 5.1-5.6）

---

### 5.7 新增：合規檢查（Compliance）— 內部 + 審核員

#### `POST /v1/compliance/check` — 同步檢查文字

- **授權**：內部調用（from BriefingService、ReminderService 等）或 JWT（Admin/Leader）
- **請求體**：
  
```json
{
  "text": "本產品可以治療糖尿病",
  "context": "briefing | invitation | reminder | conversation"
}
```

- **回應**：`200 OK` → `ComplianceCheckResult`

```json
{
  "risk_level": "high",
  "risk_type": "C1",
  "rewritten_text": "本產品可幫助關注血糖健康",
  "needs_hitl": true,
  "confidence": 0.95,
  "rules_matched": ["C1_medical_claim_cure"]
}
```

**說明**：
- `risk_level: low/medium/high`
- `risk_type: C1/C2/C3/C4/None`
- `needs_hitl: true` → 進入 HITL 佇列
- `confidence` 是 LLM 判定的信心度

#### `POST /v1/compliance/rewrite` — 改寫不安全文字

- **授權**：內部調用或 JWT（Admin）
- **請求體**：
  
```json
{
  "original_text": "100% 有效，立即見效",
  "risk_type": "C3"
}
```

- **回應**：`200 OK` → `{ "rewritten_text": "許多使用者回饋有感" }`

#### `GET /v1/compliance/logs` — 查詢合規日誌（Leader / Admin 權限）

- **授權**：JWT（Leader/Admin）
- **查詢參數**：
  - `coach_id`：教練篩選
  - `risk_level`：low/medium/high
  - `risk_type`：C1/C2/C3/C4
  - `from`、`to`：日期範圍
  - `page`、`page_size`
- **回應**：`200 OK` → 分頁列表

```json
{
  "data": [
    {
      "id": "clog_01HWX...",
      "original_text": "治療糖尿病",
      "risk_type": "C1",
      "risk_level": "high",
      "rewritten_text": "幫助關注血糖健康",
      "reviewed_by": "reviewer_01HWX...",
      "reviewed_at": "2026-05-01T14:00:00Z",
      "decision": "approved",
      "created_at": "2026-05-01T13:30:00Z"
    }
  ],
  "pagination": { "page": 1, "page_size": 25, "total": 127 }
}
```

#### `GET /v1/compliance/logs/:id` — 單筆詳情

- **授權**：JWT（Leader/Admin）
- **回應**：`200 OK` → 單筆合規日誌（詳細欄位同上）

---

### 5.8 新增：HITL 待審隊列（Compliance Queue）— Leader / Admin 權限

#### `GET /v1/compliance/queue` — 待審佇列

- **授權**：JWT（Leader/Admin）
- **查詢參數**：
  - `status`：pending / reviewing / resolved
  - `risk_level`：low/medium/high
  - `page`、`page_size`
- **回應**：`200 OK` → 分頁列表

```json
{
  "data": [
    {
      "id": "cq_01HWX...",
      "original_text": "月入 20 萬保證",
      "risk_level": "high",
      "risk_type": "C2",
      "context": "invitation",
      "coach_id": "coach_01HWX...",
      "coach_name": "阿明",
      "rewritten_suggestion": "月收入潛力佳",
      "status": "pending",
      "created_at": "2026-05-01T13:00:00Z",
      "expires_at": "2026-05-01T13:30:00Z"
    }
  ],
  "pagination": { "page": 1, "page_size": 25, "total": 8 }
}
```

**說明**：`expires_at` 是 30min SLA，超時應觸發告警給主管。

#### `POST /v1/compliance/queue/:id/approve` — 批准改寫版本

- **授權**：JWT（Leader/Admin）
- **請求體**：
  
```json
{
  "feedback": "改寫版本合理"
}
```

- **回應**：`200 OK` → `{ "status": "approved", "message": "已通過，訊息可發送" }`
- **副作用**：更新 `compliance_logs.decision = approved`、`compliance_queue.status = resolved`

#### `POST /v1/compliance/queue/:id/reject` — 拒絕改寫

- **授權**：JWT（Leader/Admin）
- **請求體**：
  
```json
{
  "feedback": "內容有風險，建議教練重新撰寫"
}
```

- **回應**：`200 OK` → `{ "status": "rejected", "message": "已拒絕，教練需重新編寫" }`
- **副作用**：教練端顯示「遭拒，理由：…」+ 重新編寫按鈕

#### `POST /v1/compliance/queue/:id/rewrite` — 由審核員改寫

- **授權**：JWT（Leader/Admin）
- **請求體**：
  
```json
{
  "rewritten_text": "使用本產品有機會改善健康狀況",
  "feedback": "改為更中立表述"
}
```

- **回應**：`200 OK` → `{ "status": "modified", "rewritten_text": "..." }`

#### `POST /v1/compliance/queue/batch-review` — 批量審核

- **授權**：JWT（Leader/Admin）
- **請求體**：
  
```json
{
  "queue_ids": ["cq_01HWX...", "cq_02HWX..."],
  "action": "approve",
  "feedback": "批量確認通過"
}
```

- **回應**：`200 OK` → `{ "processed": 2, "succeeded": 2, "failed": 0 }`

---

### 5.9 新增：商談副駕駛（Conversation Coach）— 教練權限

#### `GET /v1/leads/:id/conversation/pre` — 商談前摘要

- **授權**：JWT（該 lead 所屬 coach）
- **回應**：`200 OK` → `ConversationPlan (pre)`

```json
{
  "id": "conv_01HWX...",
  "lead_id": "lead_01HWX...",
  "phase": "pre",
  "content": {
    "pain_points": [
      "連續 6 週睡眠 < 6 小時",
      "過去試過 2 次減重都失敗",
      "家族糖尿病史"
    ],
    "opening_suggestion": "王小姐妳好，謝謝妳填寫問卷。我看到妳的睡眠狀況有點挑戰…",
    "warm_up_questions": [
      "這段時間睡眠狀況怎麼樣？",
      "妳之前試過什麼改善方法嗎？"
    ]
  },
  "generated_at": "2026-05-01T10:00:00Z"
}
```

#### `GET /v1/leads/:id/conversation/in-session` — 商談中話術

- **授權**：JWT（該 lead 所屬 coach）
- **回應**：`200 OK` → `ConversationPlan (in_session)`

```json
{
  "id": "conv_01HWX...",
  "lead_id": "lead_01HWX...",
  "phase": "in_session",
  "content": {
    "product_connection": [
      "根據妳的睡眠問題，我推薦產品 A（含褪黑激素），許多朋友用了都有回饋…",
      "我們也有配套方案，結合營養與運動…"
    ],
    "objection_responses": [
      {
        "objection": "朋友吃了沒效",
        "response": "每個人體質不同，建議先試用 2 週，看身體反應。如果沒有感受，我們可以調整…"
      },
      {
        "objection": "價格有點貴",
        "response": "我理解預算考量。其實我們有分期方案，算起來月費只要…"
      }
    ],
    "closing_invitation": [
      "不如妳先試試，我相信會有幫助",
      "要不要我先給妳預留一份？"
    ]
  },
  "generated_at": "2026-05-01T10:00:00Z"
}
```

#### `GET /v1/leads/:id/conversation/post` — 商談後訊息

- **授權**：JWT（該 lead 所屬 coach）
- **回應**：`200 OK` → `ConversationPlan (post)`

```json
{
  "id": "conv_01HWX...",
  "lead_id": "lead_01HWX...",
  "phase": "post",
  "content": {
    "follow_up_message": "王小姐，謝謝妳今天的時間！我們聊到妳的睡眠問題和減重目標。我相信我們的產品組合能幫妳。建議妳先試用 2 週，到時我再跟妳確認反應如何。48 小時後我再跟妳聯絡，ok？",
    "next_action": "提醒客戶試用 2 週",
    "suggested_reminder": {
      "kind": "48h",
      "due_at": "2026-05-03T14:00:00Z"
    }
  },
  "generated_at": "2026-05-01T14:00:00Z"
}
```

---

### 5.10 新增：Leader Summary & Coach 詳情 — Leader 權限

#### `GET /v1/leader/summary` — Leader Summary 頁

- **授權**：JWT（Leader）
- **查詢參數**：
  - `period`：week（預設）/ month / custom
  - `from`、`to`（custom 時）
- **回應**：`200 OK`

```json
{
  "period": "week",
  "week_start": "2026-04-28T00:00:00Z",
  "funnel": {
    "coaches": [
      {
        "coach_id": "coach_01HWX...",
        "coach_name": "阿明",
        "questionnaires_count": 12,
        "conversations_count": 5,
        "conversions_count": 1,
        "conversion_rate": 0.20
      },
      {
        "coach_id": "coach_02HWX...",
        "coach_name": "阿傑",
        "questionnaires_count": 8,
        "conversations_count": 2,
        "conversions_count": 0,
        "conversion_rate": 0.0
      }
    ]
  },
  "onboarding_snapshot": [
    {
      "coach_id": "coach_03HWX...",
      "coach_name": "小美",
      "days_since_onboarded": 5,
      "completion_percentage": 30,
      "completed_tasks": ["使用摘要 3 次"],
      "pending_tasks": ["完成首個成交", "邀約 20+ 客戶"]
    }
  ],
  "high_risk_statistics": {
    "c1_triggers": 2,
    "c2_triggers": 1,
    "c3_triggers": 4,
    "c4_triggers": 0,
    "total_triggers": 7
  }
}
```

#### `GET /v1/leader/coaches/:id` — 單一教練詳情

- **授權**：JWT（該教練的 Leader）
- **回應**：`200 OK`

```json
{
  "coach_id": "coach_01HWX...",
  "coach_name": "阿明",
  "role": "中階教練",
  "stats": {
    "week": {
      "questionnaires": 12,
      "conversations": 5,
      "conversions": 1,
      "conversion_rate": 0.20,
      "follow_up_rate": 0.85
    },
    "month": {
      "questionnaires": 40,
      "conversations": 15,
      "conversions": 3,
      "conversion_rate": 0.20,
      "follow_up_rate": 0.82
    }
  },
  "trend_7d": [
    { "date": "2026-05-01", "conversions": 0 },
    { "date": "2026-05-02", "conversions": 1 },
    { "date": "2026-05-03", "conversions": 0 },
    { "date": "2026-05-04", "conversions": 0 },
    { "date": "2026-05-05", "conversions": 0 }
  ],
  "briefing_usage_count": 12,
  "high_risk_triggers": {
    "c1": 1,
    "c2": 0,
    "c3": 2,
    "c4": 0
  }
}
```

#### `GET /v1/leader/coaches/:id/onboarding` — 新手教練進度

- **授權**：JWT（該教練的 Leader）
- **回應**：`200 OK`

```json
{
  "coach_id": "coach_03HWX...",
  "coach_name": "小美",
  "onboarded_at": "2026-04-28T00:00:00Z",
  "days_in_program": 10,
  "completion_percentage": 30,
  "tasks": [
    {
      "task_id": "briefing_3_times",
      "name": "使用摘要 3 次",
      "target": 3,
      "current": 3,
      "completed_at": "2026-05-02T14:00:00Z",
      "status": "completed"
    },
    {
      "task_id": "first_conversion",
      "name": "完成首個成交",
      "target": 1,
      "current": 0,
      "completed_at": null,
      "expected_by": "2026-05-28T00:00:00Z",
      "status": "pending"
    },
    {
      "task_id": "invite_20_customers",
      "name": "邀約 20+ 客戶",
      "target": 20,
      "current": 12,
      "completed_at": null,
      "expected_by": "2026-05-28T00:00:00Z",
      "status": "pending"
    }
  ],
  "can_assign_tasks": true
}
```

#### `POST /v1/onboarding/tasks/:id/complete` — 標記任務完成（Leader 分派用）

- **授權**：JWT（Leader）
- **請求體**：
  
```json
{
  "evidence": "客戶已簽約"
}
```

- **回應**：`200 OK` → 更新 `onboarding_tasks.completed_at`、推送通知給教練

---

### 5.11 新增：教練統計（Activity Tracking）— 教練 + Leader

#### `GET /v1/coaches/:id/stats` — 教練個人 KPI

- **授權**：JWT（本人或其 Leader）
- **查詢參數**：
  - `period`：today / week（預設）/ month
- **回應**：`200 OK`

```json
{
  "coach_id": "coach_01HWX...",
  "period": "week",
  "stats": {
    "questionnaires_count": 12,
    "conversations_count": 5,
    "conversions_count": 1,
    "conversion_rate": 0.20,
    "follow_up_rate": 0.85,
    "briefing_usage_count": 12,
    "briefing_usage_rate": 1.0
  }
}
```

---

### 5.12 新增：Google Calendar 同步（提醒）— 內部呼叫

#### `POST /v1/reminders/:id/sync-calendar` — 推同步事件

- **授權**：內部調用（from ReminderService）
- **請求體**：無（用 reminder_id）
- **回應**：`200 OK` → `{ "calendar_event_id": "event_01HWX...", "synced": true }`
- **副作用**：建立 Google Calendar 事件，記錄 event_id 到 `reminders.google_calendar_event_id`

#### `POST /v1/integrations/google/oauth/callback` — Google OAuth 回呼

- **授權**：無（OAuth 回呼）
- **查詢參數**：`code` (Google auth code)、`state` (CSRF token)
- **回應**：`302 Redirect` → `/settings?calendar=authorized`
- **副作用**：儲存 refresh token 到 Supabase，準備未來同步

---

## 6. 資料模型（v3.0 補充）

### 新增：`ComplianceLog`

```json
{
  "id": "clog_01HWX...",
  "object": "compliance_log",
  "original_text": "本產品可治療糖尿病",
  "risk_type": "C1 | C2 | C3 | C4 | None",
  "risk_level": "low | medium | high",
  "rewritten_text": "本產品可幫助關注血糖健康",
  "context": "briefing | invitation | reminder | conversation",
  "coach_id": "coach_01HWX...",
  "reviewed_by": "reviewer_01HWX...",
  "reviewed_at": "2026-05-01T14:00:00Z",
  "decision": "approved | rejected | modified",
  "created_at": "2026-05-01T13:30:00Z"
}
```

### 新增：`ComplianceQueueItem`

```json
{
  "id": "cq_01HWX...",
  "object": "compliance_queue",
  "text": "月入 20 萬保證",
  "risk_level": "high",
  "risk_type": "C2",
  "context": "invitation",
  "coach_id": "coach_01HWX...",
  "status": "pending | reviewing | resolved",
  "created_at": "2026-05-01T13:00:00Z",
  "expires_at": "2026-05-01T13:30:00Z"
}
```

### 新增：`ConversationPlan`

```json
{
  "id": "conv_01HWX...",
  "object": "conversation_plan",
  "lead_id": "lead_01HWX...",
  "phase": "pre | in_session | post",
  "content": {
    "pain_points": ["..."],
    "opening_suggestion": "...",
    "product_connection": ["..."],
    "objection_responses": [{ "objection": "...", "response": "..." }],
    "follow_up_message": "..."
  },
  "generated_at": "2026-05-01T10:00:00Z"
}
```

### 新增：`OnboardingTask`

```json
{
  "id": "ot_01HWX...",
  "object": "onboarding_task",
  "coach_id": "coach_01HWX...",
  "task_id": "briefing_3_times | first_conversion | invite_20_customers",
  "completed_at": "2026-05-02T14:00:00Z",
  "assigned_by": "leader_01HWX...",
  "priority": 1,
  "expected_by": "2026-05-28T00:00:00Z"
}
```

---

## 7. 權限矩陣（v3.0 擴充）

| 端點 | Coach | Leader（下線） | Admin | 合規官員 |
| :--- | :--- | :--- | :--- | :--- |
| `/compliance/check` | ✅（內部） | ✅（內部） | ✅ | — |
| `/compliance/logs` | ❌ | ✅ | ✅ | ✅ |
| `/compliance/queue` | ❌ | ✅ | ✅ | ✅ |
| `/compliance/queue/:id/*` | ❌ | ✅ | ✅ | ✅ |
| `/conversation/pre` | ✅（自己的 lead） | ❌ | ✅ | — |
| `/conversation/in-session` | ✅（自己的 lead） | ❌ | ✅ | — |
| `/conversation/post` | ✅（自己的 lead） | ❌ | ✅ | — |
| `/leader/summary` | ❌ | ✅ | ✅ | — |
| `/leader/coaches/:id` | ❌ | ✅（下線） | ✅ | — |
| `/leader/coaches/:id/onboarding` | ❌ | ✅（下線） | ✅ | — |
| `/coaches/:id/stats` | ✅（自己） | ✅（下線） | ✅ | — |
| `/onboarding/tasks/:id/complete` | ✅ | ✅（授權者） | ✅ | — |
| `/reminders/:id/sync-calendar` | — | — | ✅（內部） | — |

---

## 8. 狀態碼與錯誤

**新增 HTTP 202 Accepted**：

```json
{
  "status": 202,
  "error": {
    "type": "compliance_review_required",
    "message": "訊息已進入人工審核，待審核員確認。SLA 30 分鐘內。"
  }
}
```

---

## 9. 版本演進政策

（維持既有）

---

**文件統計**

| 項目 | 數量 |
| :--- | ---: |
| 既有端點（v1.0） | ~25 |
| 新增端點（v3.0） | ~20 |
| **總計** | **~45** |
| 資料模型 | 新增 4 個 |
| 權限矩陣 | 擴充至 8 角色 × 12 端點 |

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v1.0 | 2026-04-24 | 基礎 API（問卷/摘要/CRM/提醒/認證）~25 端點 |
| v2.0 | — | （未發布） |
| **v3.0** | **2026-05-08** | **新增 Compliance、HITL、Conversation、Leader、Activity、Google Calendar 端點 ~20 個，合計 ~45** |
