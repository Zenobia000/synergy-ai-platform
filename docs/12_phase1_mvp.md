# Phase I MVP 規格 — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08 | **狀態:** 實作基準
> **修訂歷程**：v3.0 規格收斂 → v3.0.1 教練即審核者 → **v3.1 五大架構翻轉（DB/Auth/Channel/Rules/Deploy）**
> **來源**：客戶 Phase I MVP 規格書（2026-05-06）
> **開發週期**：4 週 | **上線目標**：2026-06-02（Pilot 3-5 位教練）

---

## ⚠️ v3.1 重大修訂摘要（2026-05-08）

| # | 變更 | 對應 ADR | 影響模組 |
| :---: | :--- | :--- | :--- |
| 1 | DB 從 Supabase Cloud → 本地 PostgreSQL 17 + pgvector（GCP Cloud SQL）| ADR-003 翻轉 | 全部 |
| 2 | Magic Link 認證 → admin 後台手動建用戶 + bcrypt 帳密 | ADR-014 廢棄、ADR-015 採用 | M0 |
| 3 | 通知通道新增 WhatsApp（LINE → WhatsApp → Email fallback）| ADR-016 | M4 |
| 4 | 規則庫 YAML → DB `compliance_rules` + 向量近似比對 | ADR-017 | 合規 AI |
| 5 | 部署 Cloudflare/Railway → GCP（Cloud Run + Cloud SQL + Cloud CDN）| ADR-013 修訂、ADR-018 | 部署 |

**M0 模組重寫**：原 AuthService（Magic Link）淘汰，改為 **UserManagementService + PasswordAuthService**。
**合規模組擴充**：ComplianceService Layer 1 升級為「字面命中 + 向量近似命中」雙階；新增 ComplianceRuleService（admin CRUD）+ SemanticMatcher。
**通知模組擴充**：NotificationChannel 新增 WhatsAppChannel。
**模組數**：18 → 21。

---

## 執行摘要

Phase I MVP 從既有 4 功能閉環（v2.0 PRD）**擴充為 7 大模組完整閉環**：
1. **M0** — 教練認證與授權（Magic Link + Session 管理）**✨ v3.0.1 新增**
2. **M1** — Lead 入口 + 基本合規初篩
3. **M2** — 三階段 AI 問卷（快速分流 → 核心問卷 → 動態追問）+ 雙版摘要
4. **M3** — 商談副駕駛（前/中/後話術）
5. **M4** — 基礎 CRM + 10 種狀態 + 48h/7d/30d 提醒
6. **合規 AI**（強制路徑）— 規則庫 + LLM 二次覆核 + **教練即審核者**（⚠️ v3.0.1 修訂）
7. **M6** — 輕量 Activity Tracking + Leader Summary + 新手教練進度

**核心改變**：
- v3.0.1：HITL 從「外部 Reviewer 角色 + 佇列管理」簡化為「教練本人在 UI 內看草稿、可編輯、按下才送」，定位為輔助導航員而非流程阻擋
- 新增認證層（M0）確保教練身份與隱私
- 合規 AI 強制路徑保留，流程改為「規則庫 → LLM 改寫 → 草稿存檔 → 教練決策」

---

## 模組詳規

### M0 — 帳號管理與認證 ⚠️ v3.1 重寫（取代原 Magic Link 設計）

| 項目 | 內容 |
| :--- | :--- |
| **職責** | Admin 後台手動建立教練 / Leader / 其他 admin 帳號；bcrypt 帳密登入；首次強制改密；JWT Session 管理；登出 |
| **核心使用者** | 系統管理員（admin 後台 CRUD）、教練 / Leader（登入使用） |
| **新模組分工** | `UserManagementService`（admin 後台 user CRUD）、`PasswordAuthService`（帳密驗證 + JWT） |
| **In-scope 子功能** |  |
| F0.1 | **Admin 建立用戶** — 在 `/admin/users` 後台新增使用者（指定 email + role + 初始密碼）|
| F0.2 | **帳密登入** — `POST /auth/login`（email + password），bcrypt 驗證，核發 JWT |
| F0.3 | **首次強制改密** — `must_change_password=true` 時，登入後跳 `/auth/change-password` |
| F0.4 | **改密** — 教練自助改密（需驗舊密碼）|
| F0.5 | **登出** — 清除 JWT cookie |
| F0.6 | **Admin 重設密碼** — admin 在 `/admin/users/:id/reset-password` 為教練重設並設 `must_change_password=true` |
| F0.7 | **Admin 解鎖帳號** — 連續 5 次失敗後 lock 15min；admin 可手動 unlock |
| F0.8 | **Role 驗證** — 4 種角色：admin / leader / coach；ProtectedRoute + RLS 雙層檢查 |
| **API 入口** | `POST /auth/login`、`POST /auth/change-password`、`POST /auth/logout`、`GET /auth/me`、`GET/POST /admin/users`、`PATCH /admin/users/:id`、`DELETE /admin/users/:id`、`POST /admin/users/:id/reset-password`、`POST /admin/users/:id/unlock` |
| **資料表** | `users`（password_hash、must_change_password、failed_login_count、locked_until、last_login_at、whatsapp_id）、`admin_audit_logs`（所有 admin 操作 append-only）|
| **相依** | bcrypt（cost=12）、PyJWT、SQLAlchemy；**移除** Supabase Auth 依賴 |
| **驗收標準** |  |
| AC0.1 | Admin 可在後台建立教練帳號，密碼以 bcrypt hash 儲存 |
| AC0.2 | 教練首次登入強制改密；密碼長度 ≥10 字元含數字 + 字母 |
| AC0.3 | JWT 1h access + 7d refresh；驗證速度 ≤ 50ms |
| AC0.4 | 連續 5 次失敗 → lock 15 min；超時自動解除或 admin 手動解 |
| AC0.5 | 所有 admin 操作（建/改/刪/重設密）寫入 `admin_audit_logs`，append-only 不可改 |
| AC0.6 | Coach 無法存取 `/admin/*`；Leader 無法存取下線教練的 `message_drafts` |

> **⚠️ v3.0.1 → v3.1 變更**：原 Magic Link 設計（OTP 15 min + 自助註冊）整套淘汰，改為 admin 集中管理使用者，原因：Pilot 期 3-5 位教練人數少，admin 直接建檔最簡單；無 Magic Link 寄信維運負擔；ADR-014 標廢棄、ADR-015 採用。

---

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
| **核心使用者** | 教練（商談前後查閱）；商談中話術亦走草稿流程（教練編輯後送出） |
| **In-scope 子功能** |  |
| F3.1 | 商談前 5 分鐘摘要 — 核心痛點三句話、建議開場、暖場問題；進教練端 UI 顯示草稿卡片 |
| F3.2 | 商談中話術 — 產品銜接話術、可能異議與建議回覆、柔性成交邀約；**進草稿流程**（教練確認後同步對客戶說） |
| F3.3 | 商談後跟進訊息 — 下一步行動建議、自動帶入跟進排程；進草稿供教練編輯 |
| **API 入口** | `GET /leads/:id/conversation/pre`、`GET /leads/:id/conversation/in-session`、`GET /leads/:id/conversation/post`、`PATCH /drafts/:id/send` |
| **資料表** | `conversation_plans` (lead_id, phase, content, created_at)、`conversation_history` (lead_id, message, sent_at)、`message_drafts` (draft_id, coach_id, original_text, rewritten_text, risk_score, quality_score, regenerate_count, status, decided_at, sent_at, coach_edits) |
| **相依** | QuestionnaireResponse、RecommendationEngine、ComplianceService（話術合規）、LLMAdapter（話術生成）、DraftReviewService |
| **驗收標準** |  |
| AC3.1 | 教練進入 Lead 詳情頁能看到商談前摘要（5 秒載入） |
| AC3.2 | 商談中提示實時產出（≤ 5 秒），以草稿卡片形式呈現 |
| AC3.3 | 教練點「發送」後話術才對外送出；「編輯」能改寫內容 |

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
| **資料表** | `customers` (coach_id, status, last_contact, notes)、`follow_up_tasks` (customer_id, due_date, status, channel)、`reminder_queue` (customer_id, trigger_at, type)、`message_drafts` (draft_id, original_text, rewritten_text, ...) |
| **相依** | LeadStatusMachine、ReminderService、GoogleCalendarAdapter、NotificationChannel、DraftReviewService |
| **驗收標準** |  |
| AC4.1 | 問卷完成自動建立 Customer（< 2 秒） |
| AC4.2 | 教練可手動修改客戶狀態、查看完整狀態歷史 |
| AC4.3 | 48h/7d/30d 提醒在指定時間觸發、並自動產出草稿 |
| AC4.4 | 提醒事件自動建立到教練 Google Calendar |

---

### 合規 AI（強制路徑）— ⚠️ v3.0.1 重大修訂：教練即審核者

| 項目 | 內容 |
| :--- | :--- |
| **職責** | 所有對外訊息（摘要、話術、邀約文案）的合規檢查、改寫、品質驗證、教練最終決策 |
| **核心使用者** | 系統（檢查 + LLM 改寫）、教練（UI 內看草稿、編輯、決定送出） |
| **新定位** | 系統為「輔助導航員」，所有對外文字都是**草稿**，教練看過、可編輯、按「送出」才真的發送。移除外部 Reviewer 角色與佇列管理。 |
| **In-scope 子功能** |  |
| F5.1a | **字面命中（Layer 1a）** — 從 `compliance_rules` 表查詢字面 / 子字串 match 黑名單詞彙（C1-C4）（<10ms，B-tree + trigram 索引） |
| F5.1b | ⚠️ **向量近似命中（Layer 1b，v3.1 新增）** — 用 pgvector cosine similarity 比對改寫變體；超過閾值（預設 0.85）視為命中（~50ms，HNSW 索引） |
| F5.1c | **規則庫管理（v3.1 新增）** — admin 在 `/admin/compliance-rules` 後台 CRUD；支援 CSV 批量匯入；新增/修改規則自動觸發 embedding 重算（`SemanticMatcher` 用 Gemini text-embedding-004，768 維）|
| F5.2 | LLM 二次覆核 — 對初篩標記的文字進行高階語意檢查，輸出 `risk_score (0.0-1.0)` 與改寫版本 |
| F5.3 | 品質閥值 + 自動重生成 — LLM 改寫後的 `quality_score` 若 `< 閥值（預設 0.7）` → 自動丟回 LLM 重新生成（最多 3 次）；3 次仍不過保留原文並標 `quality_failed` 供教練確認 |
| **F5.4** | **教練即審核者（新流程）** — 兩種情境：<br>**(a) 低/中風險**：ComplianceService 改寫後→寫入 `message_drafts` 表，狀態 `pending_coach_review`→教練 UI 看「AI 建議草稿」卡片（顯示原文、改寫版、風險標記、quality_score）→教練可接受/編輯/丟棄<br>**(b) 品質未通過 (quality_failed)**：同樣進草稿，教練看到警告「LLM 重生成 3 次仍未達品質，請人工確認」<br>**無外部審核人員**：教練決定何時送出，全程記錄於 `compliance_logs` 與 `message_drafts` |
| F5.5 | 合規日誌 — 記錄原文、規則命中、LLM 改寫、風險等級、品質分數、重生成次數、教練最終決策（接受/編輯/丟棄）、編輯內容 |
| F5.6 | 免責聲明加碼 — 教練決定送出時，依風險等級自動附上免責聲明再送出（低風險：輕量聲明；高風險：強制免責） |
| **API 入口** | `POST /compliance/check`、`POST /compliance/rewrite`、`GET /coaches/me/drafts?status=pending`、`PATCH /drafts/:id`（編輯）、`POST /drafts/:id/send`（送出）、`DELETE /drafts/:id`（丟棄） |
| **資料表** | `message_drafts` (draft_id, coach_id, original_text, rewritten_text, risk_score, quality_score, regenerate_count, status, created_at, decided_at, sent_at, coach_edits, edited_text)、`compliance_logs` (original_text, rule_hits, llm_risk_score, quality_score, rewritten_text, final_decision, coach_edit_applied, compliance_risk_level) |
| **相依** | 規則庫 YAML、LLMAdapter（二次覆核 + 重生成）、EventLog（追蹤檢查與重試）|
| **驗收標準** |  |
| AC5.1 | 所有對外訊息必過合規檢查；教練必須在 UI 看過並決策才能對外送出 |
| AC5.2 | 規則庫命中率 ≥ 90%（黑名單詞彙） |
| AC5.3 | LLM 重生成 ≤ 3 次內收斂 ≥ 95% 案例；未通過者標 `quality_failed` 呈現教練 UI |
| AC5.4 | 教練可在 `/coaches/me/drafts` 頁一目瞭然看所有待審草稿（計數徽章）；支援批量操作 |
| AC5.5 | `message_drafts` 與 `compliance_logs` 記錄完整軌跡（每次改寫、每次決策、教練編輯內容） |

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
| F6.6 | **新手教練進度（Onboarding Checklist v3.2 補完整清單）** — Leader 可分派 & 追蹤，教練可自主完成。Pilot 期初版 8 項任務（Q-002 客戶可調整）：<br>① 完成首次登入 + 改密碼<br>② 觀看 30 min 系統 onboarding 影片<br>③ 邀請 5 位客戶填問卷（驗證 M1 邀約流程）<br>④ 使用 1 次商談前摘要（驗證 M3 BriefingService）<br>⑤ 完成首次商談並更新 Lead 狀態（驗證 M4 LeadStatusMachine）<br>⑥ 在 48h 內回應系統提醒 1 次（驗證 M4 ReminderService）<br>⑦ 在草稿 UI 編輯/送出 1 則 AI 文案（驗證合規流程 + DraftReview）<br>⑧ 完成首次成交或 4 週內主動回報 |
| F6.7 | **「個人記憶」（規格 §7.1）— 個別教練操作軌跡聚合** — 定義：每位教練的操作歷史（看了哪些 brief、編輯了什麼草稿、跟進執行率、常用話術）聚合成輕量 profile，未來餵入 LLM prompt 個人化建議。Phase I 僅做**讀寫 EventLog + 基礎聚合視圖** `mv_coach_personal_memory`（教練 id, 最常推 SKU, 平均跟進延遲, 編輯草稿頻率, 紅旗忽略次數）；Phase II 升級為向量記憶 + LLM context 注入。 |
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

### 橫切能力：認證與授權

本 MVP 全流程依賴 M0 認證層（Magic Link + JWT）：

- **教練身份驗證**：Supabase Magic Link + JWT，無法被繞過
- **Role-based 存取**：`coach` / `leader` / `admin` 三層權限
- **資料隔離**：Supabase RLS 確保教練只看自己客戶；Leader 只看下線聚合（無 PII）
- **合規日誌稽核**：所有敏感操作記錄至 `compliance_logs`、`message_drafts` 與 `event_logs`，供事後審查

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

MessageDraft（⚠️ v3.0.1 新增，取代 hitl_items）
├── id (UUID)
├── coach_id (FK → User)
├── original_text
├── rewritten_text
├── risk_score (0.0-1.0, LLM 評分)
├── quality_score (0.0-1.0, 改寫品質)
├── regenerate_count (0-3)
├── status (pending_coach_review / sent / discarded)
├── created_at
├── decided_at
├── sent_at
├── coach_edits (JSON, 教練改動內容)
├── context (briefing / reminder / conversation / invitation)
└── compliance_risk_level (low / medium / high)

ComplianceLog
├── id (UUID)
├── original_text
├── risk_type (C1/C2/C3/C4)
├── rewritten_text
├── risk_level (low / medium / high)
├── quality_score (0.0-1.0)
├── final_decision (approved / edited / discarded)
├── coach_edit_applied (boolean)
├── sent_at (nullable)
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
                    ├──< ConversationPlan
                    │
                    ├──< MessageDraft（v3.0.1：教練草稿）
                    │
                    └──< OnboardingTask (coach 為被指派人)

ComplianceLog ──→ (所有改寫訊息軌跡，一比一記錄)
MessageDraft ──→ (教練待決策草稿)
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

### Week 1：骨架 & 基礎 + Auth

| 天 | 成果 |
| :--- | :--- |
| W1D1-D2 | M0 Auth（Magic Link + JWT）、QuestionnaireService（Phase 1 快速分流）、Customer schema、ScoringEngine 初版 |
| W1D3-D4 | Phase 2/3 題庫 & 計分規則、ComplianceService 規則庫 v1、產品知識庫 RAG 初版 |
| W1D5 | 前後端骨架整合測試 |

### Week 2：AI 核心 & 教練草稿

| 天 | 成果 |
| :--- | :--- |
| W2D1-D2 | M2 雙版摘要（客戶版 + 教練版） |
| W2D3-D4 | M3 商談前/中/後話術、SKU 初步推薦 + **教練即審核者流程**（草稿 UI） |
| W2D5 | ComplianceService（規則庫 → LLM 改寫 → 草稿）整合、EventLog 啟用 |

### Week 3：跟進 & 領導

| 天 | 成果 |
| :--- | :--- |
| W3D1-D2 | M4 CRM + 10 狀態、48h/7d/30d 提醒排程、Google Calendar 連動 |
| W3D3-D4 | M6 Activity Tracking、Leader Summary 頁、Onboarding Task 管理 |
| W3D5 | 內部集成測試、UI 流程驗證 |

### Week 4：Pilot & 迭代

| 天 | 成果 |
| :--- | :--- |
| W4D1-D2 | 3-5 位教練 Pilot 上線、每日數據檢查 |
| W4D3-D4 | 高風險話術修正、合規詞庫迭代、使用者 feedback 反應 |
| W4D5 | Phase II 決策評審、成果總結 |

---

## 風險管理

| # | 風險 | 影響 | 緩解策略 |
| :--- | :--- | :--- | :--- |
| R-01 | 合規踩線造成法律風險 | CRITICAL | 三道防線：規則庫(黑名單) + LLM 覆核 + 教練決策；每週合規官員檢查；`compliance_logs` 完整稽核軌跡 |
| R-02 | Pilot 教練不使用系統 | HIGH | 只做他們每天會用的成交閉環；W2 起 weekly 1:1 coaching |
| R-03 | 訓練資料不足無法評估 | HIGH | EventLog 從 D1 啟用，4 週累積基準線 |
| R-04 | 時間壓力品質下降 | MEDIUM | M5/完整 M6 砍掉，只做核心；教練草稿流程要簡但要存 |
| R-05 | AI 成本超預期 | MEDIUM | 摘要/分類用低成本模型；高階模型只用合規與商談 |
| R-06 | Brand 寫死無法跨品牌 | MEDIUM | 即便 Phase I，詞庫與話術都資料驅動，預留 tenant_id |
| R-08 | 合規誤判影響教練信心 | HIGH | 教練在 UI 驗收決策；誤判 > 5% 觸發話術庫迭代 |
| R-09 | 教練拖延批准影響成交時效 | MEDIUM | 提醒教練「待審草稿數」徽章；設定自動過期時限 + 提醒 |

---

## v2.0 → v3.0.1 差異對照

| 項目 | v2.0（既有） | Phase I v3.0 | Phase I v3.0.1（修訂） | 處置 |
| :--- | :--- | :--- | :--- | :--- |
| **認證層** | 未定 | Supabase Auth | Supabase Magic Link + JWT | ✨ **新增 M0** |
| **HITL 流程** | 未提 | 外部 Reviewer + 30min SLA 佇列 | **教練即審核者 + UI 草稿** | ⚠️ **v3.0.1 修訂** |
| **合規 AI** | Won't | 三層防線 + HITL | 三層防線 + 教練決策 | ✅ 簡化 |
| **問卷結構** | 單階段 + 計分 | 三階段（快速分流/六大核心/動態追問） | 同 v3.0 | ✅ 確認 |
| **摘要版本** | 單版（教練看） | 雙版（客戶版 + 教練版） | 同 v3.0 | ✅ 確認 |
| **商談副駕駛** | 只「商談前」摘要 | 前/中/後三段 | 前/中/後三段，全進草稿 | ✅ 確認 |
| **CRM 狀態** | 4 種 | 10 種完整流轉 | 同 v3.0 | ✅ 確認 |
| **跟進提醒** | 48h + 7d/30d 草稿 | 三節點完整實裝 | 同 v3.0，進草稿流程 | ✅ 確認 |
| **Leader Summary** | Won't | 輕量版（活動指標+新手進度） | 同 v3.0 | ✨ **新增** |
| **Google Calendar** | 未提 | 連動跟進提醒 | 同 v3.0 | ✨ **新增** |
| **M1 邀約合規檢查** | 未提 | 邀約文案送出前檢查 | 同 v3.0 | ✨ **新增** |
| **Onboarding Progress** | 未提 | 新手教練 checklist | 同 v3.0 | ✨ **新增** |
| **Reviewer 角色** | — | Must have | **⚠️ 已移除，保留為 Phase II 選項** | 🔄 **簡化** |
| **開發週數** | 8 週 | 4 週 | 4 週 | ⚡ **加速** |

---

## 遷移備註

### 既有 v2.0 成果可直接複用

- `docs/02_bdd.md` 之 questionnaire + crm + briefing scenarios（新增 5 個 feature for M3/M5/M6/Compliance/Onboarding）
- `docs/05_api.md` 之 REST 端點骨架（新增 M0/M3/Compliance/Leader 端點）
- module2-questionnaire 前後端骨架（Phase 1/2 已有，補 Phase 3 & 雙版摘要）

### 新增技術棧元件（v3.0.1）

- **M0 AuthService**：Supabase Auth SDK、Magic Link（Email OTP）、JWT 驗證、role 檢查
- **DraftReviewService**（⚠️ 重命名自 HITLService）：教練草稿 UI、編輯、決策記錄
- **ComplianceService**：規則庫（YAML）、LLM 二次覆核、品質驗證、自動重生成
- **GoogleCalendarAdapter**：OAuth 2.0 整合、事件自動建立
- **OnboardingService**：Task 管理、進度追蹤
- **LeaderSummaryService**：資料聚合、報表生成

### 時程調整

原 8 週加速為 4 週，主要靠：
1. **功能裁切**：M5（見證轉介）完全排除、M6 輕量版、HITL 簡化為教練自主決策
2. **並行開發**：W1-4 各功能模組平行推進，M0 Auth 作為 W1 基礎
3. **前端複用**：既有 module2 前端骨架加速；教練草稿 UI 相對簡單
4. **API-first**：後端先行測試，前端平行實裝；草稿流程減少 API 複雜度（無佇列管理）

---

## 相關文件

- **架構決策**：[03_adr.md](./03_adr.md)（ADR-010/011 標 ⚠️ v3.0.1 修訂）
- **模組詳規**：[06_modules.md](./06_modules.md)（新增 AuthService、DraftReviewService；移除 Reviewer）
- **API 規範**：[05_api.md](./05_api.md)（新增 Auth + Draft endpoints；移除 HITL 佇列）
- **前端 IA**：[09_frontend_ia.md](./09_frontend_ia.md)（新增 `/coaches/me/drafts`；移除 `/compliance/queue`）
- **BDD 情境**：[02_bdd.md](./02_bdd.md)（新增 auth.feature、draft_review.feature；合併 compliance.feature）
- **安全清單**：[10_security.md](./10_security.md)（新增 Auth JWT 威脅模型；Draft RLS；移除 Reviewer）
- **部署指南**：[11_deployment.md](./11_deployment.md)（移除 Reviewer 角色、佇列 worker；新增 Magic Link 郵件設定）
- **客戶交付**：[13_client_deliverables.md](./13_client_deliverables.md)（Q-006 HITL Reviewer 已關閉；新增 Email 網域驗證）
- **工作計畫**：[14_team_workplan.md](./14_team_workplan.md)（D2 新增 AuthService；估工略增）

---

**文件版本履歷**

| 版本 | 日期 | 說明 |
| :--- | :--- | :--- |
| v1.0（未發布） | — | — |
| v3.0 | 2026-05-06 | Phase I MVP 規格精煉版，6 大模組全貌，與 v2.0 併行發布 |
| **v3.0.1** | **2026-05-08** | **教練即審核者（移除 Reviewer 角色 + 佇列）+ 新增 M0 Auth 模組；模組數 18；合規流程簡化；草稿 pattern 統一** |
| **v3.1** | **2026-05-08** | **五大架構翻轉：DB 本地化、Magic Link → bcrypt admin、加 WhatsApp、規則庫 DB+pgvector、部署 GCP；模組數 21** |
| **v3.2** | **2026-05-08** | **補 docx 規格遺漏：F6.6 Onboarding 完整 8 項清單、F6.7 個人記憶定義、Pilot 出口決策矩陣（見下）** |

---

## ✨ Pilot 出口決策矩陣（v3.2 新增，對應 docx §11.1）

W4 D5 召開「Phase II Gate」評審，依以下決策矩陣判定後續走向：

### 評審輸入（W4 D4 前彙整）

| 數據 | 來源 | 負責人 |
| :--- | :--- | :--- |
| 5 個北極星 KPI 達標率 | 系統埋點 + Pilot 訪談 | PM |
| Pilot 教練續用意願（1-10）| W4 結束訪談 | PM |
| 教練 NPS（願推薦給同團隊另 1 位 0-10）| W4 結束訪談 | PM |
| 高風險話術觸發次數趨勢 | EventLog 統計 | Eng |
| 系統穩定性（uptime / 重大事件數）| Sentry + UptimeRobot | Eng |
| LLM 月成本實際 vs 預算 | GCP billing | Eng |

### 決策分支

| 條件 | 判定 | 後續行動 |
| :--- | :--- | :--- |
| **5 KR 全達標** + **≥ 3 教練願續用** + **≥ 1 教練願推薦團隊另 1 人**（NPS ≥ 8）| ✅ **進 Phase II** | 啟動 Phase II 規劃：跨品牌擴張、M5 見證 / 轉介、完整 M6 團隊管理 |
| **半數 KR 達標**（3/5 達標）OR 教練續用意願 6-7 分 | ⚠️ **局部修正後再評估** | 4 週修正期：聚焦未達標 KR；重做 W3-W4 數據；再評估一次 |
| **KR 未達標**（< 3/5）OR 教練流失（≥ 2 位拒絕續用）| ❌ **暫停並重新定位** | 召開根因會議：是產品 / 商業模式 / 工程品質？；3 個月內不重啟 |

### 評審 SOP

1. **參與**：客戶 PM + 客戶 CEO 代表 + 我方 PM + 我方 Tech Lead + 1 位 Pilot 教練代表
2. **議程**（90 min）：
   - KPI 數據簡報（20 min，Eng）
   - Pilot 教練回饋彙整（20 min，PM）
   - 決策分支判定（20 min，全員）
   - 後續行動規劃（30 min）
3. **產出**：`docs/decisions/2026-06-22-phase2-gate.md` — 含投票結果、保留問題、6 個月時程草案
4. **變更窗口**：評審結束 7 天內，客戶可書面提異議重審；超過視為決議生效

---

## ✨ 動態追問邏輯定義（v3.2 新增，對應 docx §5.2 / Q-005）

Phase 3「依回答顯示最相關追問」的判定方式，**Phase I 採純規則引擎**（非 LLM），原因：

- **可預測性高**：規則明確、可審計，避免 LLM 隨機性影響問卷流程
- **效能**：< 10ms vs LLM ~1s
- **成本**：零 token 消耗
- **可由客戶直接維護**：規則表寫在 `apps/api/rules/questionnaire-phase3-routing.yaml`

### 規則格式範例

```yaml
phase3_routing:
  - condition: "phase2.stress_score >= 6"
    questions: [stress-1, stress-2, stress-3]
  - condition: "phase2.sleep_score >= 6 AND phase2.fatigue_score >= 4"
    questions: [sleep-1, sleep-2, sleep-3, energy-1]
  - condition: "phase1.gender == 'female' AND phase1.age >= 35"
    questions: [women-cycle-1, women-cycle-2]
```

**Phase II 升級**：若需求複雜化（多重交互條件 > 20 條規則），考慮升級為 LLM-based 動態題庫生成。Phase I 規則引擎足夠 5-8 種主路徑。
