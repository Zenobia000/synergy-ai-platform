# 三人團隊分工計畫 — Phase I MVP

> **版本:** v3.1 | **更新:** 2026-05-08 | **對應規格:** [12_phase1_mvp.md](./12_phase1_mvp.md) | [06_modules.md](./06_modules.md) | [03_adr.md](./03_adr.md)
> **⚠️ v3.1 修訂**：D2 取代 Magic Link AuthService → PasswordAuthService + UserManagementService + ComplianceRuleService + WhatsAppChannel + alembic；D3 新增 admin UI 兩頁；D1 新增 SemanticMatcher
> **目的：** 把 21 個模組依能力比重分到三人，並透過明確的模組邊界讓三人能平行開發、降低相互阻塞。

---

## 0. 摘要（v3.0.1 更新）

| 角色 | 比重 | 主負責模組 | 全週時數 | 變化 |
| :--- | :---: | :--- | :--- | :--- |
| **D1 Lead Engineer** | 50-60% | M2 三階段問卷 + AI 摘要、M3 商談副駕駛、Compliance（簡化無佇列） | 35-40 hr/週 | ⬇️ 移除 HITL |
| **D2 Mid Engineer** | 30% | **M0 AuthService（新）** + M4 CRM + Reminder、Google Calendar、ScoringEngine、共用 Domain types | 20-25 hr/週 | ⬆️ **新增 Auth** |
| **D3 Junior Engineer** | 10-20% | M1 Lead 入口、M6 Leader Summary + Onboarding + **DraftReviewService UI**、共用前端元件 | 10-15 hr/週 | ⬆️ **草稿決策 UI** |

**模組獨立原則**：每位開發者負責的模組之間，後端走 Application Service 介面（非 DB 直連）、前端走 React Router 巢狀路由 + 共用 hooks 包裝。

---

## 1. 分工原則（為何這樣切）

### 1.1 切分依據

| 維度 | D1 拿什麼 | D2 拿什麼 | D3 拿什麼 |
| :--- | :--- | :--- | :--- |
| **AI / LLM 含量** | 高（M2 摘要、M3 話術、Compliance 覆核） | **中（M0 Auth 含 Magic Link 不涉 LLM，純認證邏輯）** | 低（讀現成資料展示）|
| **業務複雜度** | 高（合規規則、三層檢查） | 中（10 種狀態機、OAuth、Auth flow）| 低（Draft UI + CRUD）|
| **外部依賴** | LLM API、合規詞庫 | **Supabase Auth + Google Calendar + LINE** | 無（純內部 UI）|
| **失敗風險** | 高（影響核心 KPI）| 中（影響登入與跟進執行率）| 低（影響 UX 流暢度）|

### 1.2 為何 D2 拿 M0 AuthService（v3.0.1 新）

- **Magic Link + JWT** 是純認證邏輯，無 LLM 但牽涉密碼學與 OAuth flow
- D2 已掌握 Google Calendar OAuth，Auth flow 學習曲線相近
- M0 是「基礎」，D1 的後續模組都依賴 JWT 驗證，集中 D2 確保一致性
- 估工：3-4 天內完成（含 Resend 信寄、Magic Link 驗證、JWT 管理、refresh token 邏輯）

### 1.3 為何 D1 簡化 Compliance（無 HITL 佇列）

- v3.0.1 移除「外部 Reviewer 審核佇列」邏輯
- ComplianceService 只保留：規則庫初篩 → LLM 改寫 → quality 驗證 → 寫草稿
- 不再需要「SLA 計時、佇列管理、escalation email」，減少 D1 負擔 ~20%

### 1.4 為何 D3 新增 DraftReviewService UI

- **教練決策草稿頁** （`/coaches/me/drafts`）是 v3.0.1 核心新增
- D3 負責前端 UI：草稿卡片清單、編輯抽屜、送出/丟棄按鈕、計數徽章
- 後端由 D2 提供 Draft API，D3 純前端消費
- 估工：2-3 天（相對簡單，主要是 React 狀態管理）

---

## 2. 模組分配明細（v3.0.1）

### 2.1 D1 Lead（50-60%）— AI 與合規核心

| 模組 | 後端檔案 | 前端頁面 | 關鍵交付 |
| :--- | :--- | :--- | :--- |
| **M2 QuestionnaireService** | `application/questionnaire/`（含三階段路由）| `routes/public/questionnaire.tsx` | Phase 1/2/3 動態題目、計分整合 ScoringEngine（D2 給介面）|
| **M2 BriefingService（雙版摘要）** | `application/briefing/` | （資料來源）| 客戶版 + 教練版，30s 內輸出 |
| **M3 ConversationCoachService** | `application/conversation_coach/` | `routes/coach/conversation-{pre,in-session,post}.tsx` | 三段話術 prompt + 5s 內；話術進草稿 |
| **ComplianceService（ADR-010）** | `application/compliance/` | （內部）| 三層防線、規則庫熱載、LLM 改寫、品質驗證；改寫版進 Draft（無佇列） |
| ~~HITLService~~ | ~~（已淘汰）~~ | — | ~~佇列 + SLA + Reviewer 審核~~ **改為 DraftReviewService 後端（見下）** |
| **LLMAdapter / Prompt 管理** | `packages/llm/`、`apps/api/.../infrastructure/llm/` | — | LiteLLM 抽象、prompt 版控、token / latency 記錄 |
| **EventLog Service** | `application/event_log/` | — | 全模組共用，D1 提介面，D2/D3 直接呼叫 |

**D1 額外職責**：技術仲裁、code review、ADR 維護、與客戶合規 / 教練對接（Draft 流程演練）。

---

### **✨ 2.2 D2 Mid（30%）— 認證、資料與整合（v3.0.1 新增 Auth）**

| 模組 | 後端檔案 | 前端頁面 | 關鍵交付 |
| :--- | :--- | :--- | :--- |
| **✨ M0 AuthService（新）** | **`application/auth/`** | **`routes/auth/{login,callback}.tsx`** | **Magic Link 登入、JWT 管理、role 驗證、登出；Resend Email** |
| **M4 LeadService（CRM）** | `application/lead/` | `routes/coach/leads.tsx`、`lead-detail.tsx` | CRUD + 10 種狀態機 |
| **M4 LeadStatusMachine** | `domain/lead/status_machine.py` | — | 10 種狀態的合法轉換規則 |
| **M4 ReminderService + Scheduler** | `application/reminder/`、`infrastructure/scheduler/` | `routes/coach/reminders.tsx` | 48h/7d/30d 排程、APScheduler |
| **M4 NotificationChannel 群** | `infrastructure/notifications/`（line / email）| — | LINE 主 + Email 備援 + fallback 路由 |
| **GoogleCalendarAdapter** | `infrastructure/google_calendar/` | OAuth 入口頁（簡單）| OAuth flow + 事件 CRUD |
| **ScoringEngine（Domain）** | `domain/scoring/` | — | 純函式、Phase 1/2/3 計分、紅旗判定 |
| **✨ DraftReviewService（後端）** | **`application/draft/`** | **（見 D3）** | **Draft CRUD、狀態管理、決策記錄** |
| **DB Migrations** | `infrastructure/db/migrations/*.sql` | — | 9 個 migration（含 message_drafts） |
| **共用 Domain Types** | `packages/domain/`（Python + TS dual）| — | Customer/Lead/User/Status enum |

**D2 額外職責**：Supabase RLS policy 撰寫、物化視圖維運、Auth 安全稽核、Draft API 設計。

---

### **2.3 D3 Junior（10-20%）— Lead 入口、Leader 視角、Draft UI**

| 模組 | 後端檔案 | 前端頁面 | 關鍵交付 |
| :--- | :--- | :--- | :--- |
| **M1 InviteLinkService** | `application/invite/` | `routes/coach/invite.tsx` | 教練識別碼帶入連結、來源欄位 |
| **M1 InviteCopyGenerator** | `application/invite/copy_generator.py` | 同上 | LLM 生邀請文案 + 私訊草稿 |
| **M6 ActivityTrackingService** | `application/activity_tracking/` | — | EventLog 聚合（讀物化視圖）|
| **M6 LeaderSummaryService** | `application/leader/` | `routes/leader/{summary,coach-detail}.tsx` | 讀物化視圖 + 渲染圖表 |
| **M6 OnboardingProgressService** | `application/onboarding/` | `routes/leader/coach-onboarding.tsx`、教練自視角 | YAML checklist + 完成狀態 |
| **✨ DraftReviewService UI（前端）** | **（見 D2）** | **`routes/coach/drafts.tsx` + Lead 詳情內 AI 建議卡片** | **待審草稿清單 UI、編輯抽屜、決策按鈕、計數徽章** |
| **共用前端元件** | `apps/web/src/components/` | — | Button、Table、Modal、StatusBadge、Toast、Apple tokens |
| **前端 UI 整合收尾** | — | 各頁面樣式 + 互動細節 | 樣式對齊、loading/error state |

**D3 額外職責**：Storybook（可選）、前端共用 hooks（useAuth、useToast、useApi）、使用手冊圖截。

---

## 3. 模組獨立性設計（降低耦合）

### 3.1 後端：Application Service 介面契約

（保持 v3.0 不變）

**禁止**：跨模組直接讀寫對方的 DB 表。
**強制**：透過 Application Service 公開的 Python protocol / interface 互動。

### 3.2 模組間溝通：Event Bus（簡化版）

| 事件 | 發起者 | 訂閱者 |
| :--- | :--- | :--- |
| **✨ `UserLoggedIn`** | **D2 (AuthService)** | **D3 (ActivityTracking) → 寫 EventLog；所有模組 → 初始化 RLS context** |
| `QuestionnaireSubmitted` | D1 (QuestionnaireService) | D2 (LeadService) → 自動建檔 |
| `LeadCreated` | D2 (LeadService) | D1 (BriefingService) → 觸發摘要 |
| `BriefingGenerated` | D1 (BriefingService) | D2 (NotificationChannel) → 通知教練 |
| `ConversationLogged` | D1 (ConversationCoachService) | **D2 (DraftReviewService) → 寫草稿；D2 (ReminderService) → 排提醒** |
| `LeadStatusChanged` | D2 (LeadService) | D2 (ReminderService) → 取消未發送提醒 |
| `OutboundMessageRequested` | 任何模組 | D1 (ComplianceService) → 過濾 |
| **`DraftSent` / `DraftDiscarded`** | **D2 (DraftReviewService)** | **D1 (ComplianceLog) → 記錄決策；D2 (NotificationChannel) → 真正送出；D3 (ActivityTracking) → 寫 EventLog** |
| `AnyAIAction` | 任何模組 | D3 (ActivityTrackingService) → 寫 EventLog |

實作：Pilot 期用 in-process pub/sub（`asyncio.Queue` 或簡易 dispatcher），Phase II 升級為 Postgres LISTEN/NOTIFY 或 Redis。

---

### 3.3 前端：路由分組 + 共用 hooks

```
src/routes/
├── public/           ← D1 主（問卷）、D3 配
├── auth/             ← D2 主（login / callback）
├── coach/            ← D2 主（CRM/Reminders）、D1 主（Briefing/Conversation）、D3 主（Drafts 頁）
└── leader/           ← D3 主

src/hooks/
├── useAuth.ts        ← D2 提供（Magic Link context）
├── useToast.ts       ← D3 提供
└── useApi.ts         ← D2 提供（JWT 自動附加）
```

---

## 4. 時程與里程碑

### **Week 1：Auth + 問卷骨架**

| 天 | 工作項 | Owner | 預估 | 產出 |
| :--- | :--- | :---: | :---: | :--- |
| **D1** | M0 AuthService（Magic Link + JWT） | **D2** | **3-4h** | 登入 endpoint + session 管理 |
| D1 | M2 Phase 1/2/3 問卷骨架 + ScoringEngine 初版 | D1 | 4h | 三階段路由 + 計分規則 |
| D2 | M4 LeadStatusMachine + Customer schema | D2 | 3h | 10 種狀態機 |
| D3 | ComplianceService 規則庫 YAML v1（客戶交付） | D1 | 2h | C1/C2/C3/C4 詞表 |
| **D5** | **Magic Link + 問卷完整流程集成測試** | **D1+D2** | — | 教練能登入 → 填問卷 |

### Week 2：AI 核心 + 草稿流程

| 天 | 工作項 | Owner | 預估 | 產出 |
| :--- | :--- | :---: | :---: | :--- |
| D1-D2 | M2 雙版摘要 + M3 商談話術完整 | D1 | 6h | 摘要 & 話術進草稿 |
| **D2-D3** | **DraftReviewService（後端 + 前端 UI）** | **D2 + D3** | **4h** | **待審草稿清單頁 + 編輯決策** |
| D2 | M4 CRM + 10 狀態 + CRUD | D2 | 4h | LeadService 完整 |
| D1 | ComplianceService Layer 1-3 完整（LLM 改寫 + 品質驗證） | D1 | 5h | 自動重生成邏輯 + 草稿寫入 |
| **D5** | **Draft 流程端到端測試**：話術 → 進草稿 → 教練決策 → 送出 | **D1+D2+D3** | — | Demo 完成 |

### Week 3：跟進 + Leader + 整合

| 天 | 工作項 | Owner | 預估 | 產出 |
| :--- | :--- | :---: | :---: | :--- |
| D1-D2 | M4 48h/7d/30d 提醒 + Google Calendar | D2 | 4h | 排程 + 日曆同步 |
| D3 | M6 Leader Summary + Onboarding + Activity | D3 | 4h | 漏斗 + 新手進度 |
| **D1+D2+D3** | **全系統集成測試 + 教練培訓準備** | — | 4h | Pilot 準備就緒 |
| D1 | EventLog 埋點完整 + Sentry 接入 | D1 | 2h | 可觀測 |
| **D5** | **Pilot 3-5 教練上線、首日監控** | **All** | — | 實時反饋 |

---

## 5. 風險與緩解

| 風險 | 影響 | 緣故 | 緩解 |
| :--- | :--- | :--- | :--- |
| **R-07** | 魔術連結寄送失敗 | **Resend Email 服務不穩定** | 本地測試 + Resend 雙通道（SMTP fallback） + 告警 |
| **R-08** | Draft 決策流程混亂 | 教練對「何時送出」理解不清 | UI 提示明確（徽章 + 提醒）+ W2 培訓演練 + 文件 |
| R-09 | ComplianceService 重生成無窮迴圈 | LLM 品質驗證卡住 | 設定最多 3 次 retry，超過標 `quality_failed` 交教練決策 |
| R-10 | D2 Auth 與 D1 Compliance JWT 簽章不一致 | 獨立實作導致 key 差異 | D2 Auth 用 Supabase 內建簽章，所有模組讀同一 JWT |

---

## 6. 溝通計畫

### 每日站會（9:30 AM，15 min）

- 昨日完成、今日計畫、卡點
- 若卡點涉多人，快速 breakout

### 每週同步（Friday 4 PM，1h）

- 週回顧（進度、品質、學習）
- 下週規劃 + 風險更新

### 與客戶（weekly）

- PM + Tech Lead 與客戶對齊：題庫、詞庫、人員確認
- Pilot 教練培訓（W2 D4）

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v1.0 | 2026-05-08 | 初版三人分工（D1 50% / D2 30% / D3 20%） |
| **v3.0.1** | **2026-05-08** | **⚠️ D2 新增 AuthService（M0，3-4 天）；D1 簡化 Compliance（無 HITL）；D3 新增 DraftReviewService UI；新增 UserLoggedIn 事件；時程調整；新增 Email 寄送風險 R-07** |
| **v3.1** | **2026-05-08** | **⚠️ 五大架構翻轉同步（見下方 v3.1 補丁段）：D2 重構 Auth 為 PasswordAuthService + 加 UserManagementService / ComplianceRuleService / WhatsAppChannel / alembic；D3 加 admin UI；D1 加 SemanticMatcher；模組數 18→21**|

---

## ⚠️ v3.1 補丁（2026-05-08）— 模組重新分配

### v3.1 模組差異表

| 模組 | v3.0.1 owner | v3.1 owner | 變更 |
| :--- | :---: | :---: | :--- |
| ~~AuthService（Magic Link）~~ | D2 | — | ❌ 廢棄（ADR-014）|
| **PasswordAuthService** | — | **D2** | ✨ 新增（取代上者）|
| **UserManagementService** | — | **D2** | ✨ 新增（admin user CRUD）|
| **ComplianceRuleService** | — | **D2** | ✨ 新增（規則庫 CRUD + embedding 計算）|
| **SemanticMatcher** | — | **D1** | ✨ 新增（向量相似度純函式）|
| **WhatsAppChannel** | — | **D2** | ✨ 新增（Meta Business API + webhook）|
| ~~Supabase Auth client~~ | D2 | — | ❌ 移除（換 SQLAlchemy + asyncpg）|
| **DB 維運（docker-compose + Cloud SQL + alembic）**| D2（Supabase 部分）| **D2（升級全自管）**| ⚠️ 工作量增 |
| **Admin UI（/admin/users + /admin/compliance-rules）**| — | **D3** | ✨ 新增 |

### v3.1 D2 工作量重估

D2 在 v3.0.1 比重 30%，v3.1 增加：
- PasswordAuthService（取代 Magic Link，估 2 天 — 比 Magic Link 簡單）
- UserManagementService + admin_audit_logs（估 2 天）
- ComplianceRuleService + embedding 計算（估 3 天）
- WhatsAppChannel + webhook + HMAC 驗證（估 2 天）
- alembic 遷移工具 + Cloud SQL Auth Proxy（估 1 天）

合計 **+10 天工作量**，4 週時程下平均每週 +2.5 天。建議 D2 比重從 30% 拉到 35%，或把以下任務分給 D1/D3：
- WhatsAppChannel 可分給 D1（與 ComplianceService 整合熟悉度高）
- UserManagementService 後端 + admin UI 前端可由 D2/D3 結對

### v3.1 D3 工作量增量

新增 admin UI 兩頁：
- `/admin/users`：CRUD 列表（簡單 CRUD UI，估 2 天）
- `/admin/compliance-rules`：含 CSV 批量匯入 dropzone（估 3 天，較複雜）

D3 比重從 10-20% → 維持 20%，但 onboarding 進度頁可後挪到 W3。

### v3.1 D1 工作量增量

新增 SemanticMatcher（純函式 + Gemini embedding 整合，估 2 天）+ ComplianceService Layer 1 升級為「字面 + 向量近似」雙階（估 1 天）。

D1 仍 50-60%，無顯著增量（Compliance 已熟）。

### v3.1 事件 Bus 補充

| 新增事件 | 發起者 | 訂閱者 |
| :--- | :--- | :--- |
| `AdminAction` | D2 (UserManagement, ComplianceRuleService) | D2 (admin_audit_logs persistence) |
| `ComplianceRuleChanged` | D2 (ComplianceRuleService) | D2 (re-compute embedding async)、D1 (ComplianceService cache invalidation) |
| `WhatsAppMessageReceived` | D2 (webhook handler) | D2 (NotificationChannel 對應 lead) |

### v3.1 共用資源更新

| 資源 | 主維護者 | 變更 |
| :--- | :---: | :--- |
| `apps/api/.../infrastructure/db/sqlalchemy/`（取代 supabase client）| D2 | ✨ 新增 |
| `apps/api/.../infrastructure/db/migrations/alembic/`（取代 Supabase migration）| D2 | ✨ 新增 |
| `packages/llm/embeddings/`（Gemini text-embedding 整合）| D1 | ✨ 新增 |
| `apps/web/src/lib/auth/`（替換 Supabase Auth 為自寫 token 管理）| D2 | ⚠️ 重寫 |
| ~~Supabase RLS policy 撰寫~~ | D2 | 維持（但目標 DB 改 Cloud SQL）|

### v3.1 風險表新增

| ID | 風險 | 影響 | 緩解 |
| :--- | :--- | :--- | :--- |
| R-08 | GCP 帳號 / billing 設定延誤（Q-013）| HIGH | 我方代開可在 1 天內完成；客戶開放至少需 W0 D5 |
| R-09 | WhatsApp Business 審核 > 7 天 | MED | 並行 LINE + Email 上線；WhatsApp 補在 W4 |
| R-10 | pgvector 在 Cloud SQL 啟用問題 | LOW | Cloud SQL for PostgreSQL 14+ 預設支援；先在 staging 驗證 |
| R-11 | 規則庫 embedding 重算量大拖累 API | MED | 改 async 後台任務（Cloud Tasks）；分批每 100 條一次 |
| R-12 | D2 工作量超載（v3.1 +10 天）| HIGH | WhatsAppChannel 改派 D1；admin UI 提早給 D3 開工 |
