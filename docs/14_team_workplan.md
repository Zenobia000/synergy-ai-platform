# 三人團隊分工計畫 — Phase I MVP

> **版本:** v1.0 | **更新:** 2026-05-08
> **對應規格:** [12_phase1_mvp.md](./12_phase1_mvp.md) | [06_modules.md](./06_modules.md) | [03_adr.md](./03_adr.md)
> **目的：** 把 17 個模組依能力比重 50/30/20（或 60/30/10）分到三人，並透過明確的模組邊界讓三人能平行開發、降低相互阻塞。

---

## 0. 摘要

| 角色 | 比重 | 主負責模組 | 全週時數 |
| :--- | :---: | :--- | :---: |
| **D1 Lead Engineer** | 50-60% | M2 三階段問卷 + AI 摘要、M3 商談副駕駛、Compliance + HITL（含 LLM 抽象層）| 35-40 hr/週 |
| **D2 Mid Engineer** | 30% | M4 CRM + Reminder、Google Calendar、ScoringEngine、共用 Domain types | 20-25 hr/週 |
| **D3 Junior Engineer** | 10-20% | M1 Lead 入口、M6 Leader Summary + Onboarding、共用前端元件、UI 組裝 | 10-15 hr/週 |

**模組獨立原則**：每位開發者負責的模組之間，後端走 Application Service 介面（非 DB 直連）、前端走 React Router 巢狀路由 + 共用 hooks 包裝。

---

## 1. 分工原則（為何這樣切）

### 1.1 切分依據

| 維度 | D1 拿什麼 | D2 拿什麼 | D3 拿什麼 |
| :--- | :--- | :--- | :--- |
| **AI / LLM 含量** | 高（M2 摘要、M3 話術、Compliance 覆核） | 低（純資料邏輯） | 低（讀現成資料展示）|
| **業務複雜度** | 高（合規規則、HITL 流程）| 中（10 種狀態機、Calendar 整合）| 低（CRUD + UI 組裝）|
| **外部依賴** | LLM API、Compliance 詞庫 | LINE / Email / Google Calendar | 無（純內部）|
| **失敗風險** | 高（影響核心 KPI）| 中（影響跟進執行率）| 低（影響可觀測性）|

### 1.2 為什麼 D1 拿最多 AI 模組

- LLM 整合與 prompt engineering 是「秘密武器」，集中一人累積經驗值
- Compliance/HITL 是合規責任核心，集中一人決策減少風險
- M2 + M3 + Compliance 三模組共享同一套 LLMAdapter 與 prompt 管理，集中一人寫不重工

### 1.3 為什麼 D2 拿 M4 + Calendar

- M4 是「水管工程」（資料流轉 + 狀態機 + 多通道 fanout），需要工程能力但不需 AI
- Google Calendar OAuth 與 LINE Messaging 是純整合活，可讓 D2 鍛鍊外部 API 整合
- 與 D1 的 AI 模組透過 `LeadCreated` / `BriefingGenerated` 事件解耦

### 1.4 為什麼 D3 拿 M1 + M6

- M1（邀請文案、私訊草稿）是 LLM call + 簡單 UI，D3 可學 LLM 但難度低
- M6 Leader Summary 主要是讀物化視圖 + 圖表展示，純前端 + 簡單 API
- Onboarding 是 YAML 驅動的 checklist，邏輯極簡
- D3 順帶當「前端共用元件管家」（按鈕、表格、Modal），整合三人成果

---

## 2. 模組分配明細

### 2.1 D1 Lead（50-60%）— AI 與合規核心

| 模組 | 後端檔案 | 前端頁面 | 關鍵交付 |
| :--- | :--- | :--- | :--- |
| **M2 QuestionnaireService** | `application/questionnaire/`（含三階段路由）| `routes/public/questionnaire.tsx` | Phase 1/2/3 動態題目、計分整合 ScoringEngine（D2 給介面）|
| **M2 BriefingService（雙版摘要）** | `application/briefing/` | （資料來源）| 客戶版 + 教練版，30s 內輸出 |
| **M3 ConversationCoachService** | `application/conversation_coach/` | `routes/coach/conversation-{pre,in-session,post}.tsx` | 三段話術 prompt + 5s 內 |
| **ComplianceService（ADR-010）** | `application/compliance/` | （內部）| 三層防線、規則庫熱載、LLM 二次覆核 |
| **HITLService（ADR-011）** | `application/hitl/` | `routes/compliance/queue.tsx`（資料 API）| 佇列 + SLA worker + reviewer actions |
| **LLMAdapter / Prompt 管理** | `packages/llm/`、`apps/api/.../infrastructure/llm/` | — | LiteLLM 抽象、prompt 版控、token / latency 記錄 |
| **EventLog Service** | `application/event_log/` | — | 全模組共用，D1 提介面，D2/D3 直接呼叫 |

**D1 額外職責**：技術仲裁、code review、ADR 維護、與客戶法務 / Reviewer 對接（HITL 流程演練）。

---

### 2.2 D2 Mid（30%）— 資料與整合

| 模組 | 後端檔案 | 前端頁面 | 關鍵交付 |
| :--- | :--- | :--- | :--- |
| **M4 LeadService（CRM）** | `application/lead/` | `routes/coach/leads.tsx`、`lead-detail.tsx`（D3 收尾 UI）| CRUD + 10 種狀態機 |
| **M4 LeadStatusMachine** | `domain/lead/status_machine.py` | — | 10 種狀態的合法轉換規則 |
| **M4 ReminderService + Scheduler** | `application/reminder/`、`infrastructure/scheduler/` | `routes/coach/reminders.tsx`（D3 收尾 UI）| 48h/7d/30d 排程、APScheduler |
| **M4 NotificationChannel 群** | `infrastructure/notifications/`（line / email）| — | LINE 主 + Email 備援 + fallback 路由 |
| **GoogleCalendarAdapter（ADR-008/012）** | `infrastructure/google_calendar/` | OAuth 入口頁（簡單）| OAuth flow + 事件 CRUD |
| **ScoringEngine（Domain）** | `domain/scoring/` | — | 純函式、Phase 1/2/3 計分、紅旗判定（規則 YAML 驅動）|
| **DB Migrations（W1）** | `infrastructure/db/migrations/*.sql` | — | 8 個 migration（見 11_deployment §17）|
| **共用 Domain Types** | `packages/domain/`（Python + TS dual）| — | Customer/Lead/User/Status enum |

**D2 額外職責**：Supabase RLS policy 撰寫、物化視圖維運、整合測試骨架。

---

### 2.3 D3 Junior（10-20%）— Lead 入口與 Leader 視角 + 前端整合

| 模組 | 後端檔案 | 前端頁面 | 關鍵交付 |
| :--- | :--- | :--- | :--- |
| **M1 InviteLinkService** | `application/invite/` | `routes/coach/invite.tsx` | 教練識別碼帶入連結、來源欄位 |
| **M1 InviteCopyGenerator** | `application/invite/copy_generator.py`（呼叫 LLMAdapter）| 同上 | LLM 生邀請文案 + 私訊草稿（先過 ComplianceService）|
| **M6 ActivityTrackingService** | `application/activity_tracking/` | — | EventLog 聚合（讀物化視圖）|
| **M6 LeaderSummaryService** | `application/leader/` | `routes/leader/{summary,coach-detail}.tsx` | 讀 `mv_leader_summary` + 渲染圖表 |
| **M6 OnboardingProgressService** | `application/onboarding/` | `routes/leader/coach-onboarding.tsx`、教練自視角頁 | YAML checklist + 完成狀態 |
| **共用前端元件** | `apps/web/src/components/` | — | Button、Table、Modal、StatusBadge、Toast、Apple tokens 套用 |
| **前端 UI 整合收尾** | — | D2 開過頭的 leads.tsx、reminders.tsx 等 | 樣式對齊、互動細節、loading/error state |

**D3 額外職責**：Storybook（可選）、前端共用 hooks（useAuth、useToast、useApi）、文件截圖與使用手冊輔助。

---

## 3. 模組獨立性設計（降低耦合）

### 3.1 後端：Application Service 介面契約

**禁止**：跨模組直接讀寫對方的 DB 表。
**強制**：透過 Application Service 公開的 Python protocol / interface 互動。

```python
# packages/domain/src/contracts/lead.py — 三人共用契約
from typing import Protocol

class LeadServicePort(Protocol):
    async def create_from_questionnaire(
        self, questionnaire_id: UUID, scoring: ScoringResult
    ) -> Lead: ...

    async def update_status(self, lead_id: UUID, status: LeadStatus) -> Lead: ...

    async def get_for_briefing(self, lead_id: UUID) -> LeadDetail: ...
```

D1（QuestionnaireService）只依賴 `LeadServicePort`，D2 寫實作；單元測試各自用 mock。

### 3.2 模組間溝通：Event Bus（簡化版）

避免 N×N 直接呼叫，採事件廣播：

| 事件 | 發起者 | 訂閱者 |
| :--- | :--- | :--- |
| `QuestionnaireSubmitted` | D1 (QuestionnaireService) | D2 (LeadService) → 自動建檔 |
| `LeadCreated` | D2 (LeadService) | D1 (BriefingService) → 觸發摘要 |
| `BriefingGenerated` | D1 (BriefingService) | D2 (NotificationChannel) → 通知教練 |
| `ConversationLogged` | D1 (ConversationCoachService) | D2 (ReminderService) → 排 48h/7d/30d |
| `LeadStatusChanged` | D2 (LeadService) | D2 (ReminderService) → 取消未發送提醒 |
| `OutboundMessageRequested` | 任何模組 | D1 (ComplianceService) → 過濾 |
| `AnyAIAction` | 任何模組 | D3 (ActivityTrackingService) → 寫 EventLog |

實作：Pilot 期用 in-process pub/sub（`asyncio.Queue` 或簡易 dispatcher），Phase II 升級為 Postgres LISTEN/NOTIFY 或 Redis。

### 3.3 前端：路由分組 + 共用 hooks

```
src/routes/
├── public/    ← D1 主、D3 配
├── coach/     ← D2 主（資料邏輯）+ D3 配（UI 細節）
├── compliance/← D1 主
└── leader/    ← D3 主
```

共用 hooks（D3 維護）：
```typescript
// src/lib/hooks/useApi.ts
export function useApi<T>(endpoint: string) { /* TanStack Query 包裝 */ }

// src/lib/hooks/useAuth.ts
export function useAuth() { /* Supabase Auth + role */ }
```

任何人寫頁面只用這些 hooks，不直接 fetch、不直接讀 Supabase 客戶端。

### 3.4 共用資源（D2 與 D3 共同維護）

| 資源 | 主要維護者 | 變更流程 |
| :--- | :--- | :--- |
| `packages/domain/`（型別契約）| D2 | PR + D1 review |
| `apps/web/src/components/`（UI 元件）| D3 | PR + D2 review |
| `apps/api/.../rules/*.yaml`（規則檔）| D1 | PR + 客戶 sign-off（合規詞庫）|

---

## 4. 4 週時程下的任務 Gantt

```
       W1骨架      W2 AI核心    W3 跟進閉環    W4 Pilot
       ─────────  ─────────   ────────────  ──────────
D1     [LLMAdapter]  [M2雙版摘要]   [Compliance]      [HITL pilot]
        ScoringIF    [M3前段話術]   [HITL service]    [prompt 迭代]
                     [M3中後話術]   [規則庫整合]      [bug 修]

D2     [DB migrations][LeadService]  [Reminder排程]   [整合測試]
       [10 狀態機]   [Notif channel] [Calendar]       [監控告警]
       [ScoringEngine][M2-M4 串接]  [RLS policy]

D3     [前端骨架]   [M1 Invite]    [Leader Summary]  [前端 polish]
       [shared UI]  [共用元件]      [Onboarding]      [UAT 配合]
                                   [前端整合 D2 頁]
```

詳細週任務見 [11_deployment.md §17 Migration 順序](./11_deployment.md) 與 [12_phase1_mvp.md §開發里程碑](./12_phase1_mvp.md)。

---

## 5. 同步與溝通機制

### 5.1 例行會議

| 會議 | 頻率 | 出席 | 議題 |
| :--- | :--- | :--- | :--- |
| **Daily Standup** | 每日 09:30 | D1/D2/D3 | 15 min：昨日 / 今日 / blocker |
| **Weekly Demo** | 週五 16:00 | + PM | 30 min：本週可 demo 功能 |
| **介面契約變更會** | 每週一 11:00（必要時）| D1/D2 | 變更 `packages/domain/` 前討論 |
| **與客戶同步** | 週一 09:30 | PM + 客戶窗口 | 30 min：交付清單進度（[13_client_deliverables.md](./13_client_deliverables.md)）|

### 5.2 共用看板

- GitHub Projects 或 Linear（任一）
- 看板欄位：Backlog / In Progress / Review / Done
- 每張卡標 `D1` / `D2` / `D3` owner 標籤

### 5.3 PR 規則

| 規則 | 說明 |
| :--- | :--- |
| 跨模組改動 | 必須 D1 review |
| 改 `packages/domain/` 或 contracts | 必須 D1 + D2 雙 review |
| 前端共用元件改動 | 必須 D3 review |
| 純自己模組內改動 | 一人 review 即可（互相 review）|
| 上線前 | 全員至少 sanity check |

---

## 6. 風險與緩解

| 風險 | 影響 | 緩解 |
| :--- | :--- | :--- |
| D1 過載（拿太多模組）| 進度落後 | W1 結束評估，必要時把 HITL UI 推給 D3、Compliance YAML 載入給 D2 |
| D2 與 D1 介面不對齊 | 整合卡關 | 強制 W1 D3 前完成 `packages/domain/` 契約 freeze |
| D3 經驗不足卡前端 | UI 不一致 | 第一週由 D2 配對程式設計（pair programming）2 hr/天 |
| Compliance 詞庫客戶遲交 | M2/M3 上線阻塞 | D1 W1 用假詞庫先開發，W2 切換真詞庫 |
| Google Calendar OAuth 卡審核 | M4 提醒缺一通道 | D2 先做純 LINE/Email 提醒，Calendar 標 P1 可延 W4 上 |
| 三人都不熟 LLM prompt | 摘要品質差 | D1 W0 先做 1 天 prompt 實驗、產出 prompt 模板給其他人沿用 |

---

## 7. 能力培養路徑（讓比重逐漸均衡）

Phase I 結束後，期望比重從 50/30/20 趨向 40/35/25：

| 人 | Phase I 學到 | Phase II 可承擔 |
| :--- | :--- | :--- |
| D1 | 全棧整合經驗 | 轉技術 leader 但減少 hands-on 比例 |
| D2 | LLM 整合（pair programming D1） | 接手 ConversationCoach 之一段話術 |
| D3 | 前端架構 + 簡單 LLM call | 接手 M1 完整 + 配對 D2 一個資料模組 |

---

## 8. 工具與環境

| 用途 | 工具 |
| :--- | :--- |
| 程式版控 | GitHub（monorepo）|
| CI/CD | GitHub Actions |
| 任務管理 | GitHub Projects 或 Linear（擇一）|
| 即時溝通 | LINE 群（已有）+ Slack（可選）|
| 文件 | 本 docs/ 目錄（PR 同步）|
| 設計協作 | Pencil MCP（design/）+ Figma（如客戶用）|
| API 測試 | Bruno 或 Insomnia（共享 collection）|
| LLM 實驗 | Jupyter Notebook（D1 的 sandbox）|

---

## 附錄：模組與 owner 對照速查表

| 模組（[06_modules.md](./06_modules.md)）| Owner | 備援 |
| :--- | :---: | :---: |
| QuestionnaireService | D1 | D2 |
| ScoringEngine | D2 | D1 |
| BriefingService | D1 | — |
| ConversationCoachService | D1 | — |
| ComplianceService | D1 | — |
| HITLService | D1 | D3（UI）|
| LeadService | D2 | D3（UI）|
| LeadStatusMachine | D2 | — |
| ReminderService | D2 | — |
| ReminderScheduler | D2 | — |
| NotificationChannel | D2 | — |
| GoogleCalendarAdapter | D2 | — |
| LLMAdapter | D1 | — |
| ActivityTrackingService | D3 | D2 |
| LeaderSummaryService | D3 | — |
| OnboardingProgressService | D3 | — |
| InviteLinkService / CopyGenerator (M1) | D3 | D1 |
