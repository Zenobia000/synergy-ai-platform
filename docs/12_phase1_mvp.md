# Phase I MVP 規格 — Synergy AI Closer's Copilot

> **版本:** v3.0 | **更新:** 2026-05-08 | **狀態:** 實作基準
> **來源**：客戶 Phase I MVP 規格書（2026-05-06）+ 既有 v2.0 文件收斂
> **開發週期**：4 週 | **上線目標**：2026-06-02（Pilot 3-5 位教練）

---

## 執行摘要

Phase I MVP 從既有 4 功能閉環（v2.0 PRD）**擴充為 6 大模組完整閉環**：
1. **M1** — Lead 入口 + 基本合規初篩
2. **M2** — 三階段 AI 問卷（快速分流 → 核心問卷 → 動態追問）+ 雙版摘要
3. **M3** — 商談副駕駛（前/中/後話術）
4. **M4** — 基礎 CRM + 10 種狀態 + 48h/7d/30d 提醒
5. **合規 AI**（強制路徑）— 規則庫 + LLM 二次覆核 + HITL
6. **M6** — 輕量 Activity Tracking + Leader Summary + 新手教練進度

**核心改變**：合規 AI 與 HITL 從 Won't 晉升為 **Must**；Leader 視角從無晉升為輕量資料板；整合 Google Calendar 連動提醒。

---

## 模組詳規

### M1 — Lead 入口與合規初篩

| 項目 | 內容 |
| :--- | :--- |
| **職責** | 生成邀請連結、邀約文案、私訊開場、來源追蹤、送出前合規檢查 |
| **核心使用者** | 教練（邀請客戶填問卷） |
| **In-scope 子功能** |  |
| F1.1 | 產生問卷連結 — 教練一鍵產生帶自己識別碼的鏈接 |
| F1.2 | 邀約文案自動產生 — AI 依客戶來源/tag 產生邀約文案 |
| F1.3 | 私訊開場草稿 — LINE / WhatsApp 開場白範本 |
| F1.4 | 客戶來源分類 — LINE、社群、朋友介紹、活動、其他 |
| F1.5 | 邀約文案合規檢查 — 送出前自動檢查是否踩線（C1-C4） |
| **API 入口** | `POST /leads/generate-link`、`POST /leads/generate-invitation`、`POST /leads/validate-message` |
| **資料表** | `leads` (含 coach_id, source, status, created_at)、`questionnaire_tokens` (含 coach_id, token, expires_at) |
| **相依** | ComplianceService、LLMAdapter（邀約文案生成） |
| **驗收標準** |  |
| AC1.1 | 教練可產生唯一問卷連結、連結 30 天有效 |
| AC1.2 | AI 邀約文案 3 秒內產出 |
| AC1.3 | 邀約文案送出前通過合規檢查或標記為高風險改寫 |

---

### M2 — 三階段 AI 問卷 + 雙版摘要

| 項目 | 內容 |
| :--- | :--- |
| **職責** | 編排三階段問卷流程、自動計分、產生客戶版與教練版兩份摘要、30 秒內完成 |
| **核心使用者** | 潛在客戶（填答者）、教練（商談前讀摘要） |
| **In-scope 子功能** |  |
| F2.1 | Phase 1 快速分流 — 年齡、生活型態、主要健康關注（5 題） |
| F2.2 | Phase 2 六大核心 — 壓力、睡眠、消化、手腳冰冷、水腫、排便（12 題，分值 0-3） |
| F2.3 | Phase 3 動態追問 — 依回答顯示最相關追問：飲食、水分、活動、體態、女性週期、補充品/藥物（3-8 題） |
| F2.4 | 自動計分與標籤 — 健康關注標籤、分值、前三大優先關注、紅旗提醒 |
| F2.5 | 客戶版摘要 — 健康關注與生活習慣方向，**禁用診斷語言**、友善可分享 |
| F2.6 | 教練版摘要 — 商談切入點、紅旗提醒、產品/SKU 初步建議（為 M3 做準備） |
| F2.7 | 雙版摘要 30 秒產出 — 完成提交後自動生成並通知 |
| **API 入口** | `POST /questionnaires/start`、`POST /questionnaires/save-answers`、`POST /questionnaires/submit` |
| **資料表** | `questionnaires` (phase, status, submitted_at)、`questionnaire_responses` (answers JSON, score, tags)、`health_scores` (coach_id, customer_id, health_level, red_flags) |
| **相依** | ScoringEngine（Phase 1-3 計分）、ComplianceService（摘要合規檢查）、LLMAdapter（摘要生成）、LeadService（建檔） |
| **驗收標準** |  |
| AC2.1 | 客戶可無登入完成問卷、期間可中途暫存 |
| AC2.2 | 提交後 30 秒內產出兩版摘要 |
| AC2.3 | 客戶版可直接分享（email）、無診斷用詞 |
| AC2.4 | 教練版含紅旗與 SKU 初步建議 |
| AC2.5 | 所有摘要文字通過合規檢查 |

---

### M3 — 商談副駕駛（前/中/後話術）

| 項目 | 內容 |
| :--- | :--- |
| **職責** | 依問卷結果與客戶狀態產生商談前/中/後話術與異議處理建議 |
| **核心使用者** | 教練（商談前後查閱） |
| **In-scope 子功能** |  |
| F3.1 | 商談前 5 分鐘摘要 — 核心痛點三句話、建議開場、暖場問題 |
| F3.2 | 商談中話術 — 產品銜接話術、可能異議與建議回覆、柔性成交邀約 |
| F3.3 | 商談後跟進訊息 — 下一步行動建議、自動帶入跟進排程 |
| **API 入口** | `GET /leads/:id/conversation/pre`、`GET /leads/:id/conversation/in-session`、`GET /leads/:id/conversation/post` |
| **資料表** | `conversation_plans` (lead_id, phase, content, created_at)、`conversation_history` (lead_id, message, sent_at) |
| **相依** | QuestionnaireResponse、RecommendationEngine、ComplianceService（話術合規）、LLMAdapter（話術生成） |
| **驗收標準** |  |
| AC3.1 | 教練進入 Lead 詳情頁能看到商談前摘要（5 秒載入） |
| AC3.2 | 商談中提示實時產出（≤ 5 秒） |
| AC3.3 | 所有話術通過合規檢查 |

---

### M4 — 基礎 CRM + 10 種狀態 + 提醒

| 項目 | 內容 |
| :--- | :--- |
| **職責** | 自動建檔、狀態管理、提醒排程、多通道草稿生成 |
| **核心使用者** | 教練（CRM 操作）、系統（自動提醒） |
| **In-scope 子功能** |  |
| F4.1 | 問卷完成自動建檔 — 系統自動建立 Customer 記錄 |
| F4.2 | 10 種狀態流轉 — 新名單 → 已填問卷 → 已預約 → 已商談 → 已推薦 → 試用中 → 已成交/未成交 → 需回訪 → 沉默 |
| F4.3 | 狀態管理 — 手動修改 + 自動觸發（如：48h 未跟進自動轉 `需回訪`） |
| F4.4 | 最後聯繫時間 & 備註 — 每個 Customer 必填欄位 |
| F4.5 | 48h 提醒 — 商談/推薦後未成交，產出 LINE/WhatsApp/Email 跟進草稿 |
| F4.6 | 7d 提醒 — 試用中或冷淡，產出試用回饋詢問草稿 |
| F4.7 | 30d 提醒 — 沉默/未回購，產出喚醒草稿 |
| F4.8 | Google Calendar 連動 — 提醒自動建立日曆事件 |
| **API 入口** | `GET /leads`、`GET /leads/:id`、`PATCH /leads/:id`、`POST /leads/:id/reminders`、`GET /reminders` |
| **資料表** | `customers` (coach_id, status, last_contact, notes)、`follow_up_tasks` (customer_id, due_date, status, channel)、`reminder_queue` (customer_id, trigger_at, type) |
| **相依** | LeadStatusMachine、ReminderService、GoogleCalendarAdapter、NotificationChannel |
| **驗收標準** |  |
| AC4.1 | 問卷完成自動建立 Customer（< 2 秒） |
| AC4.2 | 教練可手動修改客戶狀態、查看完整狀態歷史 |
| AC4.3 | 48h/7d/30d 提醒在指定時間觸發、並自動產出草稿 |
| AC4.4 | 提醒事件自動建立到教練 Google Calendar |

---

### 合規 AI（強制路徑）

| 項目 | 內容 |
| :--- | :--- |
| **職責** | 所有對外訊息（摘要、話術、邀約文案）的合規檢查、改寫、HITL 觸發 |
| **核心使用者** | 系統（內部路徑）、合規官員（HITL 審核） |
| **In-scope 子功能** |  |
| F5.1 | 規則庫初篩 — 檢查四類風險：醫療宣稱(C1)、收入宣稱(C2)、誇大效果(C3)、金字塔語句(C4) |
| F5.2 | LLM 二次覆核 — 對初篩標記的文字進行高階語意檢查 |
| F5.3 | 安全改寫 — 高風險文字自動改寫為合規版本 |
| F5.4 | HITL 觸發 — 高風險或改寫不確定案例送入人工審核佇列 |
| F5.5 | 合規日誌 — 記錄原文、風險等級、改寫版本、審核狀態 |
| F5.6 | 免責聲明加碼 — 低風險自動加上免責聲明 |
| **API 入口** | `POST /compliance/check`、`POST /compliance/rewrite`、`GET /compliance/queue`（HITL）、`PATCH /compliance/queue/:id`（人工審核） |
| **資料表** | `compliance_logs` (original_text, risk_type, rewritten_text, risk_level, reviewed_at, reviewer_id)、`compliance_queue` (text, risk_level, status) |
| **相依** | 規則庫 YAML、LLMAdapter（高階覆核）、EventLog（追蹤檢查） |
| **驗收標準** |  |
| AC5.1 | 所有對外訊息必過合規檢查 |
| AC5.2 | 規則庫命中率 ≥ 90%（黑名單詞彙） |
| AC5.3 | 高風險文字自動改寫或送 HITL，≤ 30 秒決策 |
| AC5.4 | HITL 審核隊列可視化、支援批量審核 |

---

### M6 — 輕量 Activity Tracking + Leader Summary + 新手進度

| 項目 | 內容 |
| :--- | :--- |
| **職責** | 聚合教練活動數據、Leader 報表、新手進度追蹤 |
| **核心使用者** | 教練（自己的數據）、Leader（下線匯總 + 新手進度） |
| **In-scope 子功能** |  |
| F6.1 | 每位教練問卷數/商談數/成交數 — 教練自己 + Leader 可見 |
| F6.2 | 跟進執行率 — 48h 應跟進中實際跟進的百分比 |
| F6.3 | AI 摘要使用次數 — Leader 視角看教練是否用摘要 |
| F6.4 | 高風險話術觸發次數 — Leader 視角合規監控 |
| F6.5 | Leader Summary 頁 — 本週問卷→商談→成交漏斗、下線教練排名、新手進度快照 |
| F6.6 | 新手教練進度（Onboarding Checklist） — Leader 可分派 & 追蹤，教練可自主完成 |
| F6.7 | 個人儀表板摘要 — 教練登入首頁看自己本週數據 |
| **API 入口** | `GET /coaches/:id/stats`、`GET /leader/summary`、`GET /leader/coaches/:id`、`GET /leader/coaches/:id/onboarding` |
| **資料表** | `activity_metrics` (coach_id, metric_type, value, date)、`onboarding_tasks` (coach_id, task_id, completed_at)、`event_logs` (user_id, action, resource, timestamp, latency_ms, token_count) |
| **相依** | EventLog、LeadService、CustomerService |
| **驗收標準** |  |
| AC6.1 | 教練登入後可看到自己本週 KPI（問卷數、商談數、成交數）|
| AC6.2 | Leader 進入 Summary 頁看到下線 3-5 人的漏斗 & 新手進度 |
| AC6.3 | 所有指標實時計算、不超過 2 小時延遲 |
| AC6.4 | Onboarding 任務支援手動勾選 & Leader 分派 |

---

## 資料模型（Phase I 核心 Entity）

```
User
├── id (UUID)
├── email
├── name
├── role (coach / leader / admin)
├── brand
├── language
├── leader_id (FK → User)
└── onboarded_at

Customer
├── id (UUID)
├── coach_id (FK → User)
├── name / nickname
├── contact_method (LINE / WhatsApp / Email)
├── source (LINE / 社群 / 朋友介紹 / 活動 / 其他)
├── status (10 種)
├── last_contact_at
├── notes
└── consent_records (JSON, 同意追蹤記錄)

QuestionnaireResponse
├── id (UUID)
├── customer_id (FK)
├── answers (JSON)
├── health_level (0-100)
├── health_tags (array)
├── top_3_priorities (array)
├── red_flags (array)
├── submitted_at
└── completion_time_sec

Recommendation
├── id (UUID)
├── questionnaire_response_id (FK)
├── sku
├── rationale
├── precaution
├── manual_override_reason
└── created_at

ConversationPlan
├── id (UUID)
├── customer_id (FK)
├── phase (pre / in-session / post)
├── content (JSON, 話術清單)
├── created_at
└── ttl_expires_at

FollowUpTask
├── id (UUID)
├── customer_id (FK)
├── due_at
├── channel (LINE / WhatsApp / Email)
├── draft_content
├── status (pending / completed / skipped)
├── completed_at
└── google_calendar_event_id

ComplianceLog
├── id (UUID)
├── original_text
├── risk_type (C1/C2/C3/C4)
├── rewritten_text
├── risk_level (low / medium / high)
├── reviewed_by (FK → User, HITL 審核者)
├── reviewed_at
└── decision (approved / rejected / modified)

ComplianceQueue
├── id (UUID)
├── text
├── risk_level
├── context (source module)
├── status (pending / reviewing / resolved)
└── created_at

OnboardingTask
├── id (UUID)
├── coach_id (FK → User)
├── task_id (string, 如 "use-briefing-3-times")
├── completed_at
├── assigned_by (FK → User, 通常 Leader)
└── priority

EventLog
├── id (UUID)
├── user_id (FK)
├── action (generate-briefing / submit-questionnaire / etc)
├── resource (customer_id / lead_id / etc)
├── timestamp
├── latency_ms
├── token_count
├── model_version
├── risk_keywords (array, 觸發的風險詞)
└── result (success / partial_failure / error)

ActivityMetrics
├── id (UUID)
├── coach_id (FK)
├── metric_type (questionnaires_count / conversations_count / conversions_count / etc)
├── value
├── date
└── updated_at
```

**關聯圖**：
```
User (coach) ──< Customer ──< QuestionnaireResponse
                    │              │
                    │              ├──> Recommendation
                    │              └──> FollowUpTask
                    │
                    └──< ConversationPlan
                    
                    └──< OnboardingTask (coach 為被指派人)

ComplianceLog ──→ (任何對外訊息原文，一比一記錄)
ComplianceQueue ──→ (待審訊息)
EventLog ──→ (所有使用者行為)
ActivityMetrics ──→ (聚合 coach 數據)
```

---

## 非功能需求

| 類別 | 需求 | 測量 |
| :--- | :--- | :--- |
| **效能** | 問卷摘要 ≤ 30s、商談前摘要 ≤ 5s、跟進草稿 ≤ 3s | APM 監控 |
| **可用性** | Pilot 期 ≥ 99.0% uptime | 監控儀表板 |
| **可觀測性** | 所有 AI 任務寫 EventLog（latency、token、模型、風險詞） | 日誌查詢 |
| **多語系** | Phase I 繁中（介面與輸出皆繁中） | 介面檢查 |
| **權限** | Coach 只看自己客戶；Leader 只看下線聚合（無 PII）；Admin 全權 | 權限測試 |
| **資料保護** | Customer PII 加密儲存；同意紀錄必填；GDPR 刪除支援 | 審計日誌 |

---

## 北極星指標 & 驗收

### KPIs（Pilot 8 週內驗證）

| 指標 | 基線 | 目標 |
| :--- | :--- | :--- |
| 問卷完成率 | 未知 | ≥ 50% |
| 問卷 → 預約商談轉換率 | — | ≥ 30% |
| 商談 → 成交率 | 15% | ≥ 20% |
| 教練商談準備時間 | 30+ 分鐘 | ≤ 5 分鐘 |
| 48h 未成交跟進執行率 | < 40% | ≥ 80% |
| AI 摘要使用率（Pilot 教練） | — | ≥ 80% |
| 合規檢查誤判率 | — | < 5% |

### 驗收標準（AC 清單已上列各模組）

---

## 開發里程碑

### Week 1：骨架 & 基礎

| 天 | 成果 |
| :--- | :--- |
| W1D1-2 | QuestionnaireService （Phase 1 快速分流）、Customer schema、ScoringEngine 初版 |
| W1D3-4 | Phase 2/3 題庫 & 計分規則、ComplianceService 規則庫 v1、產品知識庫 RAG 初版 |
| W1D5 | 前後端骨架整合測試 |

### Week 2：AI 核心

| 天 | 成果 |
| :--- | :--- |
| W2D1-2 | M2 雙版摘要（客戶版 + 教練版） |
| W2D3-4 | M3 商談前/中/後話術、SKU 初步推薦 + HITL 流程 |
| W2D5 | ComplianceService（強制路徑）整合、EventLog 啟用 |

### Week 3：跟進 & 領導

| 天 | 成果 |
| :--- | :--- |
| W3D1-2 | M4 CRM + 10 狀態、48h/7d/30d 提醒排程、Google Calendar 連動 |
| W3D3-4 | M6 Activity Tracking、Leader Summary 頁、Onboarding Task 管理 |
| W3D5 | 內部集成測試、UI 流程驗證 |

### Week 4：Pilot & 迭代

| 天 | 成果 |
| :--- | :--- |
| W4D1-2 | 3-5 位教練 Pilot 上線、每日數據檢查 |
| W4D3-4 | 高風險話術修正、合規詞庫迭代、使用者 feedback 反應 |
| W4D5 | Phase II 決策評審、成果總結 |

---

## 風險管理

| # | 風險 | 影響 | 緩解策略 |
| :--- | :--- | :--- | :--- |
| R-01 | 合規踩線造成法律風險 | CRITICAL | 三道防線：規則庫(黑名單) + LLM 覆核 + HITL 人工確認；每週合規官員檢查 |
| R-02 | Pilot 教練不使用系統 | HIGH | 只做他們每天會用的成交閉環；W2 起 weekly 1:1 coaching |
| R-03 | 訓練資料不足無法評估 | HIGH | EventLog 從 D1 啟用，4 週累積基準線 |
| R-04 | 時間壓力品質下降 | MEDIUM | M5/完整 M6 砍掉，只做核心；HITL 流程要簡但要存 |
| R-05 | AI 成本超預期 | MEDIUM | 摘要/分類用低成本模型；高階模型只用合規與商談 |
| R-06 | Brand 寫死無法跨品牌 | MEDIUM | 即便 Phase I，詞庫與話術都資料驅動，預留 tenant_id |
| R-08 | 合規誤判影響教練信心 | HIGH | HITL 處理 & Feedback loop；誤判 > 5% 触發話術庫迭代 |
| R-09 | HITL 人工審核拖累時程 | HIGH | 自動化低風險、高風險限時審核（< 30 min）；無共識回絕並記錄 |

---

## v2.0 → v3.0 差異對照

| 項目 | v2.0（既有） | Phase I（v3.0） | 處置 |
| :--- | :--- | :--- | :--- |
| **問卷結構** | 單階段 + 計分 | 三階段（快速分流/六大核心/動態追問） | ✅ 擴充 |
| **摘要版本** | 單版（教練看） | 雙版（客戶版 + 教練版） | ✅ 擴充 |
| **商談副駕駛** | 只「商談前」摘要 | 前/中/後三段 | ✅ 擴充 |
| **CRM 狀態** | 4 種 | 10 種完整流轉 | ✅ 擴充 |
| **跟進提醒** | 48h + 7d/30d 草稿 | 三節點完整實裝 | ✅ 確認 |
| **合規 AI** | Won't（明確不做） | **Must**（強制路徑） | ✨ **新增** |
| **HITL** | 未提 | SKU/見證/健康建議必過 | ✨ **新增** |
| **Leader Summary** | Won't（明確不做） | 輕量版（活動指標+新手進度） | ✨ **新增** |
| **Google Calendar** | 未提 | 連動跟進提醒 | ✨ **新增** |
| **M1 邀約合規檢查** | 未提 | 邀約文案送出前檢查 | ✨ **新增** |
| **Onboarding Progress** | 未提 | 新手教練 checklist | ✨ **新增** |
| **開發週數** | 8 週 | 4 週 | ⚡ **加速** |

---

## 遷移備註

### 既有 v2.0 成果可直接複用

- `docs/02_bdd.md` 之 questionnaire + crm + briefing scenarios（新增 5 個 feature for M3/M5/M6/Compliance/Onboarding）
- `docs/05_api.md` 之 REST 端點骨架（新增 M3/Compliance/Leader 端點）
- module2-questionnaire 前後端骨架（Phase 1/2 已有，補 Phase 3 & 雙版摘要）

### 新增技術棧元件

- **Compliance Service**：規則庫（YAML）、LLM 二次覆核、HITL 隊列管理
- **GoogleCalendarAdapter**：OAuth 2.0 整合、事件自動建立
- **OnboardingService**：Task 管理、進度追蹤
- **LeaderSummaryService**：資料聚合、報表生成

### 時程調整

原 8 週加速為 4 週，主要靠：
1. **功能裁切**：M5（見證轉介）完全排除、M6 輕量版
2. **並行開發**：W1-4 各功能模組平行推進
3. **前端複用**：既有 module2 前端骨架加速
4. **API-first**：後端先行測試，前端平行實裝

---

## 相關文件

- 原始 PRD：[01_prd.md](./01_prd.md)（v3.0 更新中）
- 模組詳規：[06_modules.md](./06_modules.md)（v3.0 新增 ComplianceService 等）
- API 規範：[05_api.md](./05_api.md)（補充 M3/Compliance/Leader 端點）
- 前端 IA：[09_frontend_ia.md](./09_frontend_ia.md)（新增 Leader/Compliance 頁面）
- BDD 情境：[02_bdd.md](./02_bdd.md)（新增 5 個 feature）
- 架構決策：[03_adr.md](./03_adr.md)（新增 ADR-010/011 for Compliance & HITL）

---

**文件版本履歷**

| 版本 | 日期 | 說明 |
| :--- | :--- | :--- |
| v1.0（未發布） | — | — |
| v3.0 | 2026-05-08 | Phase I MVP 規格精煉版，6 大模組全貌，與 v2.0 併行發布 |
