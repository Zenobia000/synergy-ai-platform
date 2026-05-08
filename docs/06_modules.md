# 模組規格與測試案例 — Synergy AI Closer's Copilot

> **版本:** v3.0 | **更新:** 2026-05-08 | **狀態:** 草稿
> **對應架構**：`docs/04_architecture.md` | **對應 BDD**：`docs/02_bdd.md` | **對應 API**：`docs/05_api.md` | **對應 Phase I MVP**：`docs/12_phase1_mvp.md`

---

## 版本更新說明（v2.0 → v3.0）

本版本依據 Phase I MVP 規格（2026-05-08）擴充：
- 新增 5 個 Service：**ComplianceService**、**HITLService**、**ConversationCoachService**、**ActivityTrackingService**、**LeaderSummaryService**、**OnboardingProgressService**、**GoogleCalendarAdapter**
- 更新 **ScoringEngine** 支援三階段問卷（Phase 1/2/3）與動態追問
- 擴充 **BriefingService** 生成雙版摘要（客戶版 + 教練版）
- 新增 **EventLog** 貫穿所有 AI 任務
- 完整 HITL 佇列管理

詳見 [12_phase1_mvp.md § 模組詳規](./12_phase1_mvp.md#模組詳規)。

---

## 模組索引

| # | 模組 | 所屬層級 | 核心 API | BDD Feature | 新增(v3.0) |
| :---: | :--- | :--- | :--- | :--- | :---: |
| 1 | QuestionnaireService | Application | `/questionnaires/*` | `questionnaire.feature` | ⬆️ 升級 Phase 1/2/3 |
| 2 | ScoringEngine | Domain | (內部) | 內嵌 `questionnaire.feature` | ⬆️ 支援三階段 |
| 3 | BriefingService | Application | `/leads/{id}/briefing/*` | `briefing.feature` | ⬆️ 生成雙版摘要 |
| 4 | LLMAdapter | Infrastructure | (內部) | — | — |
| 5 | LeadService (CRM) | Application | `/leads/*` | `crm.feature` | ⬆️ 支援 10 種狀態 |
| 6 | LeadStatusMachine | Domain | (內部) | 內嵌 `crm.feature` | ⬆️ 10 種狀態流轉 |
| 7 | ReminderService | Application | `/reminders/*` | `reminder.feature` | ⬆️ Google Calendar 整合 |
| 8 | ReminderScheduler | Infrastructure | `/internal/reminders/scan` | `reminder.feature` | — |
| 9 | NotificationChannel 實作群 | Infrastructure | (內部) | — | ⬆️ 支援 LINE + Email fallback |
| **10** | **ComplianceService** | Application | `/compliance/*` | `compliance.feature` | **✨ 新增** |
| **11** | **HITLService** | Application | `/compliance/queue/*` | `compliance.feature` | **✨ 新增** |
| **12** | **ConversationCoachService** | Application | `/leads/{id}/conversation/*` | `briefing.feature` | **✨ 新增** |
| **13** | **GoogleCalendarAdapter** | Infrastructure | (內部) | — | **✨ 新增** |
| **14** | **ActivityTrackingService** | Application | `/coaches/{id}/stats` | — | **✨ 新增** |
| **15** | **LeaderSummaryService** | Application | `/leader/summary` | `leader_summary.feature` | **✨ 新增** |
| **16** | **OnboardingProgressService** | Application | `/leader/coaches/{id}/onboarding` | `onboarding_progress.feature` | **✨ 新增** |
| **17** | **EventLog Service** | Infrastructure | `/internal/events` | — | **✨ 新增** |

---

## 既有模組更新（v2.0 → v3.0）

### 1. QuestionnaireService（升級）

**更新**：支援三階段問卷（Phase 1/2/3）與動態題目序列。

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 編排三階段問卷填答流程：Phase 1 快速分流 → Phase 2 六大核心 → Phase 3 動態追問；題目載入、中途儲存、送出、觸發計分與 Lead 建立 |
| **依賴** | `ScoringEngine`、`LeadService`、Supabase Client |
| **被依賴** | FastAPI Router (`/questionnaires/*`)、BriefingService |

**新增函式**：
- `async def load_phase_questions(phase: int, preceding_answers: dict) -> list[Question]` — Phase 3 動態題目選擇

---

### 2. ScoringEngine（升級）

**更新**：支援三個 Phase 計分與標籤聚合。

| 項目 | 內容 |
| :--- | :--- |
| **核心職責** | 依規則 YAML 計算三階段健康等級、健康標籤、前三大優先關注、紅旗警訊 |
| **新規則**：Phase 1（快速分類）、Phase 2（六大核心逐項評分）、Phase 3（動態細化） |
| **輸出**：`HealthScore = { level: 0-100, tags: [str], top_3: [str], red_flags: [str] }` |

---

### 3. BriefingService（升級）

**更新**：生成三個不同客群的摘要（客戶版、教練版、商談中話術）。

| 項目 | 內容 |
| :--- | :--- |
| **核心職責** | 生成雙版摘要（客戶版 + 教練版）、商談中/後話術；驗證合規；寫入 DB |
| **依賴** | `LLMAdapter`、`ComplianceService`、EventLog |
| **API 端點** | `GET /leads/{id}/briefing` (摘要)、`GET /leads/{id}/conversation/pre`、`GET /leads/{id}/conversation/in-session`、`GET /leads/{id}/conversation/post` |

**新函式**：
- `async def generate_customer_summary(...) -> str` — 客戶版摘要（無診斷語言）
- `async def generate_coach_summary(...) -> str` — 教練版摘要（含紅旗、推薦、切入點）
- `async def generate_conversation_tactics(phase: Literal['pre', 'in_session', 'post']) -> ConversationPlan`

---

### 4-9. 既有模組（核心邏輯不變）

LeadService / LeadStatusMachine / ReminderService / ReminderScheduler / LLMAdapter / NotificationChannel 核心邏輯保持不變。

**狀態機更新**：LeadStatusMachine 從 4 種狀態（new/talked/closed_won/closed_lost）擴為 10 種：
```
新名單 → 已填問卷 → 已預約 → 已商談 → 已推薦
       → 試用中 → 已成交 / 未成交 → 需回訪 → 沉默
```

---

## 新增模組（Phase I v3.0）

### 10. ComplianceService（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 所有對外訊息的合規檢查：規則庫初篩 → LLM 二次覆核 → 改寫 → HITL 觸發 |
| **依賴** | 規則庫 YAML、`LLMAdapter`、`HITLService`、EventLog |
| **被依賴** | BriefingService、LeadService（邀約文案）、ReminderService（提醒文案） |
| **API 端點** | `POST /compliance/check`、`POST /compliance/rewrite`、`GET /compliance/queue` |

### 關鍵函式

#### `async def check(text: str, context: str) -> ComplianceCheckResult`

- **前置**：text 非空、context 說明來源（如 "briefing" / "invitation" / "reminder"）
- **後置**：
  1. 規則庫初篩（黑名單詞彙匹配 C1/C2/C3/C4）
  2. 若初篩命中 → 呼叫 LLM 進行語意確認
  3. 回傳 `{ risk_level: low/medium/high, risk_type: C1|C2|C3|C4|None, rewritten_text: str, needs_hitl: bool }`
- **低風險 (low)**：自動加免責聲明
- **中風險 (medium)**：自動改寫，記錄原文
- **高風險 (high)**：改寫 + HITL 標記

#### `async def rewrite_unsafe(text: str, risk_type: str) -> str`

- 呼叫 LLM 產生合規改寫版本

### 資料表

- `compliance_logs`: original_text, risk_type, rewritten_text, risk_level, reviewed_at, reviewer_id
- `compliance_rules`: rule_id, pattern, risk_type, pattern_type (regex/keyword)

---

### 11. HITLService（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 管理高風險訊息審核佇列、人工覆核流程、批量操作 |
| **依賴** | Supabase、EventLog |
| **API 端點** | `GET /compliance/queue`、`PATCH /compliance/queue/:id`、`POST /compliance/queue/batch-review` |

### 關鍵函式

#### `async def enqueue(text: str, risk_level: str, context: str, coach_id: UUID) -> ComplianceQueueItem`

- 新增到人工審核佇列

#### `async def review(queue_item_id: UUID, reviewer_id: UUID, decision: Literal['approved', 'rejected', 'modified'], feedback: str) -> ComplianceQueueItem`

- 人工審核決策記錄
- 若 `decision='modified'`，取 rewritten_text；其他情況回傳原決策

### 資料表

- `compliance_queue`: id, text, risk_level, context, coach_id, status (pending/reviewing/resolved), created_at, reviewed_at, reviewer_id

---

### 12. ConversationCoachService（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 生成商談前/中/後話術與異議處理建議 |
| **依賴** | BriefingService（取摘要內容）、`LLMAdapter`、`ComplianceService`、EventLog |
| **API 端點** | `GET /leads/{id}/conversation/pre`、`GET /leads/{id}/conversation/in-session`、`GET /leads/{id}/conversation/post` |

### 關鍵函式

#### `async def generate_pre_talk_tactics(lead_id: UUID) -> PreTalkPlan`

- 商談前 5 分鐘摘要：核心痛點三句話、建議開場、暖場問題

#### `async def generate_in_session_tactics(lead_id: UUID, current_context: str) -> InSessionPlan`

- 商談中實時話術：產品銜接、可能異議與回覆、柔性成交邀約

#### `async def generate_post_talk_message(lead_id: UUID) -> PostTalkMessage`

- 商談後訊息範本：下一步建議、自動帶入跟進排程

---

### 13. GoogleCalendarAdapter（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Infrastructure |
| **核心職責** | 教練 Google Calendar 整合：建立/刪除日曆事件 |
| **依賴** | Google Calendar API (OAuth 2.0) |
| **被依賴** | ReminderService |

### 關鍵函式

#### `async def create_event(coach_id: UUID, reminder: Reminder) -> str`

- 建立日曆事件，回傳 event_id
- 事件時間 = `reminder.due_at`；時區 = coach 時區設定

#### `async def delete_event(coach_id: UUID, event_id: str) -> bool`

- 刪除已排程的日曆事件

---

### 14. ActivityTrackingService（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 聚合教練活動數據：問卷數、商談數、成交數、跟進執行率、AI 摘要使用率 |
| **依賴** | EventLog、LeadService、ReminderService |
| **API 端點** | `GET /coaches/{id}/stats`、`GET /coaches/{id}/stats/history` |

### 關鍵函式

#### `async def get_coach_stats(coach_id: UUID, period: Literal['today', 'week', 'month']) -> CoachStats`

- 回傳：問卷數、商談數、成交數、48h 跟進執行率、AI 摘要使用率

### 資料表

- `activity_metrics`: coach_id, metric_type (questionnaires_count, conversations_count, conversions_count, follow_up_rate, briefing_usage_count), value, date

---

### 15. LeaderSummaryService（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 生成 Leader 視角報表：下線教練本週漏斗、新手進度、高風險統計 |
| **依賴** | ActivityTrackingService、OnboardingProgressService、EventLog |
| **API 端點** | `GET /leader/summary`、`GET /leader/coaches/:id` |

### 關鍵函式

#### `async def get_leader_summary(leader_id: UUID, period: str = 'week') -> LeaderSummary`

- 本週下線教練漏斗（問卷數 → 商談數 → 成交數）
- 每位教練的轉換率排名
- 新手教練進度快照
- 高風險話術觸發統計（C1/C2/C3/C4 分類）

---

### 16. OnboardingProgressService（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 新手教練進度追蹤：task checklist、Leader 分派、自動標記 |
| **依賴** | ActivityTrackingService、EventLog |
| **API 端點** | `GET /leader/coaches/:id/onboarding`、`PATCH /onboarding/tasks/:id` |

### 關鍵函式

#### `async def get_onboarding_progress(coach_id: UUID) -> OnboardingProgress`

- 回傳 checklist 項目與完成度
- 項目例如：「使用 briefing 3 次」、「完成首個成交」、「5 天內邀約 10+ 客戶」

#### `async def mark_task_complete(task_id: UUID, coach_id: UUID) -> OnboardingTask`

- 手動勾選完成

#### `async def auto_mark_completion(task_id: UUID) -> OnboardingTask`

- EventLog 觸發自動標記（如完成首個成交時自動標記「完成首個成交」任務）

### 資料表

- `onboarding_tasks`: id, coach_id, task_id (string), completed_at, assigned_by (FK → User), priority

---

### 17. EventLog Service（新增）

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Infrastructure |
| **核心職責** | 記錄所有使用者行為 & AI 任務執行日誌 |
| **被依賴** | 所有 Service |

### 資料表

```
event_logs:
  - id (UUID)
  - user_id (FK)
  - action (string, 如 "generate-briefing", "submit-questionnaire")
  - resource (string, customer_id / lead_id / etc)
  - timestamp (timestamptz)
  - latency_ms (int, AI 任務耗時)
  - token_count (int, LLM token 計數)
  - model_version (string, 如 "gemini-2.5-flash")
  - risk_keywords (jsonb, array, 觸發的風險詞)
  - result (string, "success" / "partial_failure" / "error")
  - metadata (jsonb, 其他上下文)
```

---

## 狀態機更新（10 種客戶狀態）

```
新名單 ──→ 已填問卷 ──→ 已預約 ──→ 已商談 ──→ 已推薦
       ↘             ↙         ↙
            試用中
                    ↓
            已成交 / 未成交 ──→ 需回訪 ──→ 沉默
                                ↑
                           (重新聯繫)
```

### LeadStatusMachine 更新

```python
class LeadStatus(str, Enum):
    NEW = "新名單"
    RESPONDED = "已填問卷"
    SCHEDULED = "已預約"
    TALKED = "已商談"
    RECOMMENDED = "已推薦"
    TRIAL = "試用中"
    CLOSED_WON = "已成交"
    CLOSED_LOST = "未成交"
    FOLLOW_UP_NEEDED = "需回訪"
    SILENT = "沉默"
```

轉換矩陣見 [12_phase1_mvp.md § M4 資料表](./12_phase1_mvp.md#m4--基礎-crm--10-種狀態--提醒)。

---

## 測試補充（新模組）

### 新增 BDD Feature Files

- `compliance.feature` — ComplianceService + HITLService 場景
- `conversation_coach.feature` — ConversationCoachService 場景
- `leader_summary.feature` — LeaderSummaryService 場景
- `onboarding_progress.feature` — OnboardingProgressService 場景

### 新增單元測試範例

```python
# ComplianceService
async def test_compliance_check_detects_medical_claim():
    result = await compliance_service.check(
        "這個產品可以治療糖尿病",
        context="briefing"
    )
    assert result.risk_level == "high"
    assert result.risk_type == "C1"  # 醫療宣稱
    assert "治療" in result.rewritten_text is False

# ConversationCoachService
async def test_conversation_generates_tactics_with_compliance():
    tactics = await conversation_service.generate_pre_talk_tactics(lead_id="...")
    # 驗證話術已通過合規檢查
    for tactic in tactics.opening_suggestions:
        assert not any(word in tactic for word in FORBIDDEN_WORDS)
```

---

## 相關文件

- **Phase I MVP 完整規格**：[12_phase1_mvp.md](./12_phase1_mvp.md)
- **Updated PRD v3.0**：[01_prd.md](./01_prd.md)
- **前端 IA 更新**：[09_frontend_ia.md](./09_frontend_ia.md)（TODO：新增 Leader 頁面、HITL 頁面）
- **BDD 更新**：[02_bdd.md](./02_bdd.md)（TODO：新增 5 個 feature）
- **架構決策更新**：[03_adr.md](./03_adr.md)（TODO：新增 ADR-010/011）

---

## TODO（待後續補充）

- [ ] ComplianceService 規則庫詞表（C1/C2/C3/C4 完整列表）— 等待客戶提供
- [ ] Google Calendar OAuth 流程細節 & 時區配置 — 開發時實裝
- [ ] HITL 人工審核 SLA 與人員分配 — 待決策
- [ ] EventLog 索引與查詢效能優化 — Phase I.5 考慮
- [ ] OnboardingTask 預設項目與評分邏輯 — 等待產品定義

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v1.0 | 2026-04-24 | 9 個既有模組（問卷、計分、摘要、CRM、提醒、通知） |
| v2.0 | — | （未發布） |
| **v3.0** | **2026-05-08** | **+7 個新模組（合規、HITL、商談話術、Google Calendar、Activity、Leader Summary、Onboarding）+ 10 種狀態 + EventLog** |
