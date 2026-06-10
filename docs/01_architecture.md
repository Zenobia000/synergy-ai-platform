# Care Copilot — 架構與設計文件

版本 v0.3 | 日期 2026-06-07 | 狀態 draft | 對應 PRD v0.2（docs/PRD.md）/ 00_tech-spec v0.4 | 專案 synergy（repo 根，獨立專案）

> v0.3 變更：新增 LINE OA 來訊自動分析管線（inbound enrichment，單次 Haiku 三合一）、語音經 OA push 發送（audio message）、已發送語音 30 天保存策略。

---

## 文件索引

本文件為專案 synergy（repo 根，獨立專案，`backend/` + `frontend/`）架構設計的第一份輸出，與同目錄下其他文件協同閱讀：

- [./02_api.md](./02_api.md) — REST + SSE 端點規格
- [./03_data-model.md](./03_data-model.md) — 完整資料庫 Schema
- [./04_frontend.md](./04_frontend.md) — 前端元件設計
- [./05_backend.md](./05_backend.md) — 後端服務與 AI 整合
- [./06_project-structure.md](./06_project-structure.md) — 專案結構、環境變數、CI/CD、測試佈局

---

## 目錄

1. [架構總覽](#1-架構總覽)
2. [前後端分離與通訊](#2-前後端分離與通訊)
3. [AI 層整合（沿用既有框架）](#3-ai-層整合沿用既有框架)
4. [關鍵資料流](#4-關鍵資料流)
5. [多租戶隔離架構](#5-多租戶隔離架構)
6. [部署視圖（概念）](#6-部署視圖概念)
7. [NFR 實現策略](#7-nfr-實現策略)
8. [跨領域關注點](#8-跨領域關注點)
9. [風險與演進路線](#9-風險與演進路線)

---

## 1. 架構總覽

### 1.1 C4 L1 — 系統情境圖

外部角色與系統邊界說明：

- **直銷商（Distributor）**：主要用戶，透過 Mobile PWA 使用全部 11 個工具。
- **客戶（Contact）**：直銷商的客戶，唯一接觸面為健康問卷一次性連結（無需登入）。
- **Synergy 法務（Compliance Reviewer）**：定期 review 合規詞庫，不直接操作系統。
- **Anthropic API**：提供 Claude Haiku 4.5（速度型）與 Claude Sonnet 4.6（品質型）推論服務。
- **TTS 供應商**（OpenAI TTS 或 ElevenLabs，介面抽象化，W4 前完成選型）：語音合成服務。
- **PostgreSQL 16 + pgvector**：自建 container（dev/pilot）；提供 PostgreSQL 16（含 pgvector 0.7）、Row Level Security 租戶隔離（Postgres 原生）。
- **GCS（語音檔）**：Google Cloud Storage，語音檔暫存（7 天 TTL，Object Lifecycle 自動刪除）。

```mermaid
graph TB
    Distributor["直銷商 (Distributor)<br/>[主 Persona - 直銷商 App 用戶]"]
    Contact["客戶 (Contact)<br/>[唯一接觸面：健康問卷連結]"]
    ComplianceReviewer["Synergy 法務<br/>[合規詞庫 review，無直接系統操作]"]

    ContactLINE["客戶 LINE<br/>[透過 LINE 傳訊給 OA]"]

    subgraph CareCopioltSystem["Care Copilot System<br/>[repo 根，backend/ + frontend/]"]
        PWA["Mobile PWA<br/>[React 19 + Vite + Tailwind v4]"]
        Backend["FastAPI 後端<br/>[Python 3.12, :8002]"]
    end

    subgraph ExternalAI["外部 AI 服務"]
        AnthropicAPI["Anthropic API<br/>[Claude Haiku 4.5 / Sonnet 4.6]"]
        TTSProvider["TTS 供應商<br/>[OpenAI TTS 或 ElevenLabs<br/>介面抽象化]"]
    end

    subgraph ExternalData["外部資料服務"]
        PGContainer["PostgreSQL 16 + pgvector<br/>[自建 container；prod 待評估 Cloud SQL]"]
        GCSStorage["GCS（語音檔）<br/>[Google Cloud Storage<br/>7 天 TTL Object Lifecycle]"]
    end

    LINEPlatform["LINE Platform<br/>[Messaging API<br/>Webhook 入 / Push 出]"]

    Distributor -->|"HTTPS / PWA"| PWA
    Contact -->|"無需登入，7 天有效連結"| PWA
    ContactLINE -->|"傳訊 LINE OA"| LINEPlatform
    ComplianceReviewer -.->|"詞庫 review（線下流程）"| Backend

    LINEPlatform -->|"POST webhook /api/v1/webhooks/line"| Backend
    Backend -->|"LINE Messaging API push message"| LINEPlatform
    LINEPlatform -->|"推播給客戶"| ContactLINE

    PWA -->|"HTTPS REST + SSE"| Backend
    Backend -->|"LangGraph 編排（沿用既有框架）"| AnthropicAPI
    Backend -->|"VoiceProvider 抽象介面"| TTSProvider
    Backend -->|"SQLAlchemy asyncpg"| PGContainer
    Backend -->|"google-cloud-storage SDK"| GCSStorage
```

### 1.2 C4 L2 — 容器圖

```mermaid
graph TB
    subgraph Client["用戶端"]
        PWA["Mobile PWA<br/>[React 19 + Vite 6 + Tailwind v4]<br/>[:3002 dev / CDN prod]<br/>PWA Manifest + Service Worker<br/>Apple 設計 tokens"]
    end

    subgraph Backend["FastAPI 後端 [:8002]"]
        APIRouter["API Router 層<br/>app/api/ — 依工具分模組<br/>/api/v1 base path"]
        WebhookHandler["Webhook Handler<br/>app/api/webhooks/line.py<br/>POST /api/v1/webhooks/line<br/>驗簽 X-Line-Signature"]
        LINEClient["LINE Client<br/>app/clients/line_client.py<br/>line-bot-sdk / httpx<br/>push message 發送"]
        AssignmentService["輪派服務<br/>app/services/assignment_service.py<br/>新客戶輪派下一位 active 教練<br/>official_accounts.assignment_cursor"]
        ServiceLayer["Service 層<br/>app/services/ — 業務邏輯<br/>11 個工具各自 service 模組"]
        AgentLayer["LangGraph 編排層（沿用既有框架）<br/>app/agents/ — Agent 定義<br/>Haiku 4.5 速度型 / Sonnet 4.6 品質型"]
        ComplianceSidecar["合規規則庫（Sidecar）<br/>app/sidecars/compliance_sidecar.py<br/>regex 小於 50ms，純規則，無 AI"]
        Scheduler["排程器<br/>APScheduler（FastAPI 內）<br/>樣品 48h/72h/7d + 今日 5 件事"]
        ObsLayer["觀測層<br/>OpenTelemetry + Langfuse + Sentry<br/>app/core/observability.py"]
        AuthMiddleware["認證中介層<br/>app/core/auth.py<br/>FastAPI 自建 JWT Bearer + tenant context"]

        WebhookHandler --> AssignmentService
        WebhookHandler --> ServiceLayer
        APIRouter --> ServiceLayer
        ServiceLayer --> AgentLayer
        ServiceLayer --> ComplianceSidecar
        ServiceLayer --> Scheduler
        ServiceLayer --> LINEClient
        APIRouter --> AuthMiddleware
        AgentLayer --> ObsLayer
        ServiceLayer --> ObsLayer
    end

    subgraph DataLayer["資料層（GCP-native）"]
        PG["PostgreSQL 16 + pgvector 0.7<br/>schema: care<br/>Alembic 遷移<br/>RLS 租戶隔離（Postgres 原生）<br/>自建 container；prod 待評估 Cloud SQL"]
        GCS["GCS（語音檔）<br/>Google Cloud Storage<br/>語音檔暫存（7 天 TTL）<br/>V4 Signed URL 下載"]
    end

    subgraph AIProviders["AI 服務供應商"]
        Anthropic["Anthropic API<br/>Haiku 4.5 / Sonnet 4.6"]
        TTS["TTS 供應商<br/>VoiceProvider 介面<br/>OpenAI TTS 或 ElevenLabs"]
    end

    subgraph Observability["觀測後端"]
        Langfuse["Langfuse 3.x<br/>AI trace + 成本計量<br/>採用率追蹤"]
        Sentry["Sentry<br/>前後端錯誤聚合"]
        OTelCollector["OTel Collector<br/>span + metrics"]
    end

    LINEPlatformL2["LINE Platform<br/>[Messaging API]"]

    PWA -->|"HTTPS REST + SSE<br/>Authorization: Bearer JWT"| APIRouter
    AuthMiddleware -->|"HS256 自驗 JWT"| APIRouter
    LINEPlatformL2 -->|"POST /api/v1/webhooks/line<br/>X-Line-Signature 驗簽"| WebhookHandler
    LINEClient -->|"push message"| LINEPlatformL2
    ServiceLayer -->|"SQLAlchemy ORM + RLS"| PG
    ServiceLayer -->|"GCS V4 Signed URL"| GCS
    AgentLayer -->|"LangGraph → Claude API"| Anthropic
    ServiceLayer -->|"VoiceProvider.synthesize()"| TTS
    ObsLayer -->|"OTLP"| OTelCollector
    ObsLayer -->|"LLM spans"| Langfuse
    PWA -->|"JS SDK"| Sentry
    ServiceLayer -->|"Python SDK"| Sentry
```

### 1.3 技術選型表

依契約 C 章逐字對齊：

| 分類 | 選用技術 | 版本 / 規格 | 選擇理由 |
| :--- | :--- | :--- | :--- |
| 前端框架 | React | 19.x | Concurrent features、Server Components 就緒 |
| 前端建置 | Vite | 6.x | 快速 HMR、PWA plugin 生態完整 |
| 前端樣式 | Tailwind CSS | v4.x | CSS-first 設計 token 管理 |
| 前端 PWA | vite-plugin-pwa | latest | Service Worker + manifest 自動注入 |
| 前端 UI token | Apple 設計系統 | `.claude/ui/apple/DESIGN.md` | 直銷商 80% 用 iPhone；Apple 風格熟悉感 |
| 前端狀態管理 | Zustand | 5.x | 輕量、React 19 相容 |
| 前端 HTTP | TanStack Query | 5.x | SSE 串流支援、快取與樂觀更新 |
| 後端框架 | FastAPI | 0.115.x | async、OpenAPI 自動產生、Python 3.12 最佳化 |
| 後端套件管理 | uv | latest | 規則強制；快速 venv + lock 管理 |
| 後端 Python | Python | 3.12 | match statement、typing 改進 |
| 資料庫 | PostgreSQL 16 + pgvector（自建 container；prod 待評估 Cloud SQL） | 16.x + pgvector 0.7.x | ACID、JSON 支援、pgvector；標準 Postgres，dev↔prod 透明切換 |
| 向量搜尋 | pgvector | 0.7.x | 活檔案語意搜尋、embedding 同庫儲存 |
| 租戶隔離 | RLS（Postgres 原生）+ TenantContext Middleware | — | Row Level Security；後端每交易注入三個 session 變數（app.current_tenant_id / app.current_distributor / app.current_role） |
| AI 編排 | LangGraph | 0.2.x | **沿用既有框架（PRD 第 5 章），本次不重新設計** |
| AI 模型（速度型） | Anthropic Claude Haiku 4.5 | claude-haiku-4-5 | 低延遲；情緒感測、異議、草稿首字、樣品草稿、生活事件 |
| AI 模型（品質型） | Anthropic Claude Sonnet 4.6 | claude-sonnet-4-6 | 品質優先；活檔案 insight、訊息全文 streaming、問卷摘要、招募 |
| 合規檢查 | regex sidecar | 純 Python re | < 50ms；50 詞庫；無 AI；v1 純規則 |
| 太業務員警報 | 純規則引擎 | 純 Python | < 50ms；產品關鍵字 + URL pattern；無 AI |
| 語音合成 | OpenAI TTS 或 ElevenLabs | 供應商未定，W4 前選型 | 介面抽象化（VoiceProvider 介面） |
| 語音儲存 | Google Cloud Storage（GCS） | — | V4 Signed URL 下載；7 天 TTL Object Lifecycle 自動刪除 |
| 認證 | FastAPI 自建 JWT | HS256 + python-jose + passlib[bcrypt] | 扁平 JWT claims；無第三方 Auth 依賴；bcrypt 密碼驗證 |
| DB 連線 | asyncpg | DATABASE_URL=postgresql+asyncpg://... | 非同步連線；標準 Postgres 協定 |
| 觀測—追蹤 | OpenTelemetry | 1.x | 標準 OTLP 協定；後端 instrumentation |
| 觀測—AI Trace | Langfuse | 3.x | LLM span、成本計量、採用率追蹤 |
| 觀測—錯誤 | Sentry | Python SDK + JS SDK | 前後端錯誤聚合 |
| 排程 | APScheduler（FastAPI 內） | 3.x | 樣品 48h/72h/7d 提醒；今日 5 件事每日產生 |
| 資料庫遷移 | Alembic | 1.x | FastAPI + SQLAlchemy 生態標準 |
| LINE 整合 | line-bot-sdk（或 httpx 呼叫 Messaging API） | 3.x | 每租戶一個 LINE OA；webhook 驗簽；push message 發送；reply token 失效後改用 push |

### 1.4 DDD-lite 分層架構

本模組採用 DDD 輕量分層，每層職責明確，禁止跨層直接依賴（infrastructure 不得被 domain 引用）：

```
┌──────────────────────────────────────────────────────────────────┐
│  Interface Layer（介面層）                                        │
│  app/api/         — FastAPI Router，HTTP 請求解碼、回應序列化     │
│  app/schemas/     — Pydantic 請求/回應 Schema                    │
├──────────────────────────────────────────────────────────────────┤
│  Application Layer（應用層）                                      │
│  app/services/    — 業務用例協調（11 個工具各自 service 模組）    │
│  app/agents/      — LangGraph Agent 定義（沿用既有框架）          │
│  app/sidecars/    — compliance_sidecar.py（< 50ms 規則引擎）      │
├──────────────────────────────────────────────────────────────────┤
│  Domain Layer（領域層）                                           │
│  app/models/      — SQLAlchemy ORM 模型（care schema 實體）       │
│  純領域邏輯（值物件、業務規則、Enum 定義）                         │
├──────────────────────────────────────────────────────────────────┤
│  Infrastructure Layer（基礎設施層）                               │
│  app/db/          — PostgreSQL 連線（asyncpg）、Session、Alembic  │
│  app/core/        — 設定（Settings）、auth、observability         │
│  外部 client：Anthropic SDK、TTS client、Langfuse client          │
│                   google-cloud-storage client（GCS 語音檔）       │
└──────────────────────────────────────────────────────────────────┘
```

### 1.5 通用語言詞彙表（Ubiquitous Language）

| 詞彙 | 定義 | 對應實體/Enum |
| :--- | :--- | :--- |
| 活檔案 | 直銷商對每位客戶建立的即時累積記錄，欄位可漸進填寫 | contacts |
| Care Action | 關懷動作（非推銷），北極星指標計量單元 | learning_logs.event_type |
| 今日 5 件事 | App 首頁每日生成的最高優先級任務卡，最多 5 張 | today_tasks |
| 草稿模式 | AI 生成草稿後靜待直銷商手動複製送出，AI 永不自動發送 | message_drafts.adopted |
| 合規低語 | regex sidecar，所有外送草稿的強制 gate | compliance_checks |
| 合規燈號 | 合規掃描結果：green / yellow / red | compliance_status enum |
| 太業務員警報 | 連 3 則推銷型訊息觸發的純規則警報 | salesy_alerts |
| 語氣三檔 | 情緒感測器輸出：stressed / neutral / happy | emotion enum |
| 暖名單 / 曝光 / 邀約 / 簽約 | 招募漏斗四階段 | recruitment_stage enum |
| 租戶（Tenant） | 品牌隔離頂層實體，Day 1 抽象，v1 無管理 UI | tenants |
| 配額熔斷 | ai_cost_usd_today 達 cost_limit_usd 時阻擋後續 AI 請求 | usage_quotas |
| 學習紀錄 | 所有 AI 操作的背景寫入，Phase II 訓練素材 | learning_logs |
| VoiceProvider | TTS 供應商抽象介面，隔離 OpenAI TTS 與 ElevenLabs 差異 | voice_clips.provider |

---

## 2. 前後端分離與通訊

### 2.1 邊界定義

| 邊界面 | 前端職責 | 後端職責 |
| :--- | :--- | :--- |
| 渲染 | React 19 CSR + PWA Service Worker 快取靜態資源 | 不做 SSR（v1，假設：前端靜態 CDN 部署） |
| 業務邏輯 | UI 狀態管理（Zustand）、樂觀更新、SSE 串流接收 | 業務規則、AI 編排、合規掃描、排程 |
| 資料驗證 | 前端表單驗證（即時 UX） | Pydantic schema 驗證（強制，信任邊界） |
| 認證 | 持有 JWT（FastAPI 自建發行），每請求帶 Bearer token | JWT 驗證（HS256 自驗）、tenant_id 注入、RLS 依據 |

### 2.2 通訊協定

**標準 REST 請求（多數 API）**

```
POST /api/v1/contacts
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "display_name": "Anna Chen",
  "communication_pref": "line",
  "relationship_type": "customer"
}
```

回應信封（成功）：
```json
{
  "data": {
    "id": "ctc_abc123",
    "display_name": "Anna Chen",
    "tenant_id": "tnt_xyz789",
    ...
  }
}
```

回應信封（錯誤）：
```json
{
  "error": {
    "code": "COMPLIANCE_RED_BLOCKED",
    "message": "草稿含高風險詞，請依建議改寫後重試",
    "details": {
      "triggered_terms": ["保證", "治癒"],
      "suggestion": "改寫成『我自己用了感覺不錯，分享給你參考』"
    }
  }
}
```

**SSE 串流（T06 訊息草稿）**

```
POST /api/v1/message-drafts/stream
Content-Type: application/json → 回應 text/event-stream
```

前端使用 TanStack Query + EventSource / fetch stream：

```typescript
// 假設：使用 fetch + ReadableStream 處理 SSE，不用原生 EventSource
// 因需帶 Authorization header（EventSource 不支援自訂 header）
const response = await fetch('/api/v1/message-drafts/stream', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${jwt}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ contact_id, tone, channel }),
});
```

SSE 事件序列：

```
event: first_token
data: {"token": "Anna，"}

event: token
data: {"token": "最近睡得好一點了嗎？"}

event: compliance_result
data: {"status": "green", "check_id": "cck_abc123", "triggered_terms": []}

event: done
data: {"draft_id": "dft_abc123", "tone": "care", "model_used": "sonnet-4-6", "latency_ms": 1240}
```

合規紅燈時：

```
event: compliance_blocked
data: {"status": "red", "check_id": "cck_xyz", "triggered_terms": ["保證"], "suggestion": "..."}
```

### 2.3 認證流程（FastAPI 自建 JWT）

```mermaid
sequenceDiagram
    participant D as 直銷商 (PWA)
    participant API as FastAPI Backend
    participant DB as PostgreSQL (RLS)

    D->>API: POST /api/v1/auth/login<br/>{email, password}
    API->>DB: SELECT password_hash FROM care.distributors<br/>WHERE email = $1
    DB->>API: password_hash
    API->>API: bcrypt.verify(password, password_hash)
    API->>API: 簽發 JWT HS256<br/>{sub, tenant_id, role, iat, exp}
    API-->>D: {access_token, token_type:"bearer", expires_in}

    D->>API: POST /api/v1/contacts<br/>Authorization: Bearer JWT
    API->>API: decode_jwt(token)<br/>sub, role, tenant_id
    API->>API: inject TenantContext<br/>(tenant_id, distributor_id, role 注入)
    API->>DB: SET LOCAL app.current_tenant_id  = tenant_id
    API->>DB: SET LOCAL app.current_distributor = distributor_id
    API->>DB: SET LOCAL app.current_role        = role
    API->>DB: SELECT ... WHERE tenant_id = $1<br/>(RLS policy 額外強制執行)
    DB->>API: 隔離後的查詢結果
    API-->>D: 200 OK {"data": {...}}

    Note over API,DB: 若 tenant_id 不符：RLS 篩空<br/>後端邏輯回傳 404 NOT_FOUND
```

**JWT Payload 關鍵欄位**：

```json
{
  "sub": "usr_abc123",
  "tenant_id": "tnt_xyz789",
  "role": "distributor",
  "iat": 1748793600,
  "exp": 1748880000
}
```

後端 `TenantContext` Middleware 從 JWT 抽取 `tenant_id`、`sub`（distributor_id）與 `role`，每交易注入三個 session 變數（`app.current_tenant_id`、`app.current_distributor`、`app.current_role`），禁止 Service 層自行從請求取 tenant_id。

### 2.4 埠號規劃

| 服務 | Port | 備註 |
| :--- | :--- | :--- |
| synergy backend（本專案） | 8002 | repo 根 backend/，獨立專案 |
| synergy frontend dev（本專案） | 3002 | repo 根 frontend/，Vite dev server |
| PostgreSQL container（本地）| 5432 | docker-compose pgvector/pgvector:pg16 |

### 2.5 API 路徑規範

- Base Path：`/api/v1`
- 資源路徑：小寫複數連字號（`/message-drafts`、`/today-tasks`、`/life-events`）
- 欄位命名：snake_case
- 時間格式：ISO 8601 UTC（`2026-06-02T10:30:00Z`）
- 分頁：游標分頁 `?cursor=<uuid>&limit=<int>`，回應含 `pagination.next_cursor`、`pagination.has_more`

---

## 3. AI 層整合（沿用既有框架）

> **重要聲明**：AI 編排層（LangGraph 0.2.x + 11 個 agent + 模型分配策略）沿用既有框架（PRD 第 5 章），本次不重新設計。本章僅定義後端 Service 層與 AI 層的整合介面、輸入輸出契約、串流掛載點、合規與學習紀錄掛載點，以及成本計量點。

### 3.1 11 工具 → 服務模組 → AI 模型對照

| 工具 | 服務模組（app/services/） | AI 模型 / 引擎 | 延遲目標 |
| :--- | :--- | :--- | :--- |
| T01 關係記憶活檔案 | `contact_service.py` | Sonnet 4.6（insight 生成）；text-embedding-3-small（pgvector） | insight < 3s |
| T02 生活事件雷達 | `life_event_service.py` | Haiku 4.5（文字型事件抽取）；日期型純規則 | < 1s |
| T03 語氣／情緒感測器 | `emotion_service.py` | Haiku 4.5（三檔分類） | < 1s |
| T04 太業務員警報 | `salesy_alert_service.py` | 純規則引擎（無 AI） | < 50ms |
| T05 今日 5 件事 | `today_task_service.py` | 規則優先（v1 無 AI 排序） | < 200ms |
| T06 訊息草稿 | `message_draft_service.py` | Haiku 4.5 首字 + Sonnet 4.6 全文 streaming | 首字 < 500ms；全文 < 3s |
| T07 樣品追蹤 | `sample_service.py` | Haiku 4.5（跟進草稿） | < 1s |
| T08 語音草稿 | `voice_service.py` | VoiceProvider 抽象（OpenAI TTS 或 ElevenLabs） | < 10s（60 秒語音） |
| T09 快速異議處理器 | `objection_service.py` | Haiku 4.5 速度優先 | < 2s |
| T10 健康問卷 | `questionnaire_service.py` | Sonnet 4.6（摘要） | < 5s |
| T11 招募漏斗 | `recruitment_service.py` | Sonnet 4.6（最嚴格合規） | < 3s |
| SYS 合規低語 | `compliance_sidecar.py` | regex sidecar（純規則） | < 50ms |
| PLT 學習紀錄 | `learning_log_service.py` | 無 AI（純寫入） | < 100ms async |

### 3.2 後端 Service → LangGraph → Haiku/Sonnet 整合序列圖

```mermaid
sequenceDiagram
    participant API as API Router<br/>(/api/v1/...)
    participant SVC as Service Layer<br/>(app/services/)
    participant LG as LangGraph 編排器<br/>(app/agents/)<br/>[沿用既有框架]
    participant Haiku as Claude Haiku 4.5<br/>[速度型]
    participant Sonnet as Claude Sonnet 4.6<br/>[品質型]
    participant LF as Langfuse<br/>[AI Trace]
    participant LL as learning_log_service<br/>[學習紀錄]

    API->>SVC: generate_draft(contact_id, tone, tenant_ctx)
    SVC->>SVC: 前置三道檢查<br/>1. emotion_service.get_latest()<br/>2. salesy_alert_service.check_streak()<br/>3. compliance_sidecar.pre_check()
    SVC->>LG: invoke_draft_agent(context)

    Note over LG: LangGraph 狀態機<br/>沿用既有框架

    LG->>Haiku: 生成首字（小於 500ms）
    Haiku-->>LG: first_token
    LG-->>SVC: stream event: first_token

    LG->>Sonnet: 全文 streaming
    Sonnet-->>LG: token stream
    LG-->>SVC: stream events: token[]

    LG->>LF: record_llm_span(<br/>  model, prompt_tokens,<br/>  completion_tokens, cost_usd<br/>)

    SVC->>SVC: compliance_sidecar.check(full_text)
    SVC-->>API: stream event: compliance_result

    SVC->>SVC: 更新 usage_quotas.ai_cost_usd_today
    SVC->>LL: async write_log(<br/>  event_type="draft_generated",<br/>  source_id=draft_id<br/>)

    SVC-->>API: stream event: done {draft_id, latency_ms}
```

### 3.3 合規 Sidecar 掛載點

合規 sidecar（`app/sidecars/compliance_sidecar.py`）必須在以下六種「外送草稿類型」被直銷商取得或採用前執行：

| source_type | 觸發時機 | 阻擋機制 |
| :--- | :--- | :--- |
| `message_draft` | 草稿全文生成後，stream 結束前 | red → SSE `compliance_blocked` 事件；前端禁用複製按鈕 |
| `sample_followup` | 預生跟進草稿完成時 | red → today_task 卡顯示警告，不允許採用 |
| `voice_clip` | 語音合成前，文字腳本階段；經 OA 發送前再次確認 | red → 阻擋 TTS 呼叫，回傳 422；發送階段 red → 拒絕 push。腳本修改後必須重新生成語音並重掃，不得舊語音配新腳本 |
| `objection_response` | 三種回應全部生成後 | red → 前端隱藏紅燈回應，只顯示 green/yellow |
| `questionnaire_summary` | Sonnet 摘要生成後 | red → 不回傳摘要，觸發改寫 |
| `recruitment_draft` | 招募話術草稿完成後 | red → 強制阻擋，最嚴格（FTC 收入保證） |

每次掃描結果 100% 寫入 `compliance_checks`（含 latency_ms）。

### 3.4 學習紀錄掛載點

所有下列 AI 操作完成後，`learning_log_service.py` 非同步（< 1 秒）寫入 `learning_logs`：

| event_type | 觸發條件 | 備註 |
| :--- | :--- | :--- |
| `emotion_read` | Haiku 情緒感測完成 | 含 confidence, latency_ms |
| `draft_generated` | 草稿生成完成（含 SSE 完成） | 含 model_used, latency_ms |
| `draft_adopted` | 直銷商呼叫 `/adopt` | 採用率計算基準 |
| `draft_rejected` | 草稿生成後 30 分鐘無 adopt | 背景 APScheduler 任務標記 |
| `salesy_alert_dismissed` | 直銷商呼叫 dismiss | 含 dismiss_reason |
| `salesy_alert_acknowledged` | 直銷商呼叫 acknowledge | — |
| `objection_used` | 直銷商呼叫 `/adopt` | 含 adopted_style |
| `compliance_triggered` | 合規黃 / 紅燈觸發 | 含 triggered_terms |
| `compliance_overridden` | 黃燈被直銷商覆蓋 | 含 override_reason |
| `voice_downloaded` | 直銷商呼叫 `/download` | 採用指標 |
| `voice_sent` | 教練按發送、語音經 OA push 成功 | 採用指標；含 line_message_id |
| `inbound_enriched` | OA 來訊三合一分析完成 | 含 emotion、life_events 數、suggestions 數、latency_ms |
| `suggestion_confirmed` | 教練確認活檔案待確認建議 | 抽取準確率計算基準 |
| `suggestion_dismissed` | 教練忽略活檔案待確認建議 | 誤抽率觀察 |

**重要**：learning_logs 寫入失敗不得導致主流程失敗（async fire-and-forget），但失敗需 Sentry 告警。

### 3.5 成本計量點

每次 AI 呼叫完成後，Service 層同步更新 `usage_quotas.ai_cost_usd_today`：

```python
# 假設：成本計算依 Anthropic 官方 token 定價
# Haiku 4.5: $0.25/1M input + $1.25/1M output
# Sonnet 4.6: $3.00/1M input + $15.00/1M output
# TTS: 依供應商定價（W4 選型後更新）
async def update_cost(distributor_id: str, tenant_id: str, cost_usd: float):
    async with db.transaction():
        quota = await get_or_create_today_quota(distributor_id, tenant_id)
        new_cost = quota.ai_cost_usd_today + cost_usd
        if new_cost >= quota.cost_limit_usd:
            raise CostLimitReachedException(used=new_cost, limit=quota.cost_limit_usd)
        await update_quota_cost(distributor_id, tenant_id, new_cost)
```

熔斷後回傳 `429 COST_LIMIT_REACHED`，含 `{"used": 0.31, "limit": 0.30, "reset_at": "2026-06-03T00:00:00Z"}`。

Langfuse 成本 dashboard 每日超限 → Slack 告警（環境變數與設定見 [./06_project-structure.md](./06_project-structure.md)）。

### 3.6 VoiceProvider 抽象介面

語音檔合成完成後，後端將音訊上傳至 GCS，並以 V4 Signed URL 提供直銷商下載（TTL 配合 7 天 Object Lifecycle）。

```python
# app/services/voice_service.py — VoiceProvider 抽象
from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class VoiceSynthesisResult:
    audio_bytes: bytes
    duration_seconds: int
    provider: str  # "openai" | "elevenlabs"
    cost_usd: float

class VoiceProvider(ABC):
    @abstractmethod
    async def synthesize(
        self,
        text: str,
        voice_style: str,  # "warm_female" | "neutral_male"
        language: str,     # "zh-TW" | "en-US"
    ) -> VoiceSynthesisResult:
        ...

# 具體實作（W4 前選型後啟用）
class OpenAITTSProvider(VoiceProvider): ...
class ElevenLabsProvider(VoiceProvider): ...
```

語音檔上傳至 GCS 後，`voice_clips.storage_url` 儲存 GCS 物件路徑（例：`gs://care-copilot-voice/tnt_xyz/clip_abc.m4a`）；下載端點呼叫 `google-cloud-storage` SDK 產生 V4 Signed URL 回傳前端。

**LINE 語音發送（audio message push）**：

- 檔案格式採 **m4a（AAC）**——LINE audio message 的硬性要求；TTS 供應商若不支援直接輸出 AAC，後端加轉檔步驟（影響 P0-06 選型）
- 發送流程：教練試聽（前端強制，未播放過不可發）→ POST `/voice-clips/{id}/send` → 後端確認 compliance_status 非 red → LINE push audio message（`originalContentUrl` = 對 LINE 伺服器可達的 HTTPS URL，`duration` 毫秒）→ 寫入 `voice_clips.sent_at`、`line_message_id`
- **保存策略雙軌**：未發送語音維持 7 天 TTL；已發送語音 `retention_until = sent_at + 30 天`（客戶可重播期），由 APScheduler 清理 job 依 `retention_until` 刪除（取代單一 Lifecycle rule）
- 語音 push 與文字 push 同計 LINE OA 每月免費額度
- 學習紀錄：發送成功寫入 `voice_sent` 事件

---

## 4. 關鍵資料流

### 4.1 生訊息草稿 — 三道檢查 → SSE 串流 → 學習紀錄

本流程涵蓋 T03 情緒感測、T04 太業務員警報、SYS 合規低語、T06 訊息草稿四個工具的協作。

```mermaid
sequenceDiagram
    participant D as 直銷商 PWA
    participant API as POST /api/v1/message-drafts/stream
    participant EmSvc as emotion_service
    participant SalSvc as salesy_alert_service
    participant DraftSvc as message_draft_service
    participant Comp as compliance_sidecar
    participant LG as LangGraph 編排器<br/>[沿用既有框架]
    participant Haiku as Haiku 4.5
    participant Sonnet as Sonnet 4.6
    participant DB as PostgreSQL
    participant LLog as learning_log_service

    D->>API: POST {contact_id, tone, channel}<br/>Authorization: Bearer JWT

    API->>EmSvc: get_latest_emotion(contact_id)
    EmSvc-->>API: {emotion: "stressed", confidence: 0.87}
    Note over API: 情緒 stressed → 強制 tone="care"<br/>收起 business tab（前端由 compliance_result 決定）

    API->>SalSvc: check_streak(contact_id, distributor_id)
    SalSvc-->>API: {salesy_streak_count: 2}
    Note over API: streak 小於 3 → 繼續（不觸發警報）

    API->>Comp: pre_check(context_summary)
    Comp-->>API: {result: "green", latency_ms: 12}
    Note over Comp: 前置輕量掃描（context），小於 50ms

    API->>DraftSvc: stream_draft(contact_id, tone="care", channel)
    DraftSvc->>LG: invoke_draft_agent(contact_context)

    LG->>Haiku: generate_first_token(prompt)
    Haiku-->>LG: "Anna，"
    LG-->>D: event: first_token<br/>data: {"token": "Anna，"}

    LG->>Sonnet: stream_full_draft(prompt)
    loop token stream
        Sonnet-->>LG: token
        LG-->>D: event: token<br/>data: {"token": "..."}
    end

    DraftSvc->>Comp: check(full_draft_text)
    Comp->>DB: INSERT compliance_checks<br/>{source_type="message_draft", result, latency_ms}
    Comp-->>DraftSvc: {result: "green", check_id: "cck_abc123"}

    DraftSvc->>DB: INSERT message_drafts<br/>{tone, channel, content, compliance_status="green",<br/> compliance_check_id, model_used="sonnet-4-6", latency_ms}

    DraftSvc-->>D: event: compliance_result<br/>data: {"status": "green", "check_id": "cck_abc123"}
    DraftSvc-->>D: event: done<br/>data: {"draft_id": "dft_abc123", "latency_ms": 1240}

    DraftSvc->>DB: UPDATE usage_quotas SET ai_cost_usd_today += cost
    DraftSvc->>LLog: async write_log(event_type="draft_generated", source_id="dft_abc123")

    Note over D: 直銷商看到草稿，點「複製到 LINE」
    D->>API: POST /api/v1/message-drafts/dft_abc123/adopt
    API->>DB: UPDATE message_drafts SET adopted=true, adopted_at=now()
    API->>LLog: async write_log(event_type="draft_adopted", source_id="dft_abc123")
```

**合規紅燈流程（異常路徑）**：

若 `compliance_sidecar.check()` 回傳 `red`，DraftSvc 推送 `event: compliance_blocked`，不寫入 `message_drafts`，前端複製按鈕 disabled，直銷商必須修改文字後重新呼叫 stream 端點。

### 4.2 發樣品 → 排程 48/72/7 天 → 今日 5 件事跳卡

```mermaid
sequenceDiagram
    participant D as 直銷商 PWA
    participant API as POST /api/v1/contacts/{id}/samples
    participant SmpSvc as sample_service
    participant Sched as APScheduler
    participant TodaySvc as today_task_service
    participant DraftSvc as message_draft_service
    participant Haiku as Haiku 4.5
    participant DB as PostgreSQL

    D->>API: POST {product_name: "Omega+",<br/>product_id: "prd_xyz", notes: "..."}
    API->>SmpSvc: create_sample(contact_id, distributor_id, tenant_id, ...)

    SmpSvc->>DB: INSERT samples<br/>{status="sent", sent_at=now()}

    SmpSvc->>DB: INSERT sample_followups x 3<br/>[{followup_type="h48", followup_at=sent+48h},<br/> {followup_type="h72", followup_at=sent+72h},<br/> {followup_type="d7",  followup_at=sent+7d}]

    SmpSvc->>Sched: schedule_jobs(<br/>  [h48_job, h72_job, d7_job]<br/>)
    Sched-->>SmpSvc: jobs registered
    SmpSvc-->>D: 201 Created {sample_id: "smp_abc123"}

    Note over Sched: --- 48 小時後 ---

    Sched->>TodaySvc: trigger_followup_task(sample_followup_id)
    TodaySvc->>DB: UPDATE sample_followups<br/> SET status="notified", notified_at=now()<br/>WHERE followup_type="h48"

    TodaySvc->>DraftSvc: pre_generate_followup_draft(<br/>  contact_id, tone="care",<br/>  context="樣品 48h 跟進"<br/>)
    DraftSvc->>Haiku: generate_followup_draft(contact_context)
    Haiku-->>DraftSvc: "Cathy 妳好，上次給妳的 Omega+ 用得怎樣？"
    DraftSvc->>DB: INSERT message_drafts {tone="care", ...}

    TodaySvc->>DB: INSERT today_tasks<br/>{source_type="sample_followup",<br/> source_id="sfu_abc123",<br/> reason="Cathy 樣品 2 天了，要不要關心一下？",<br/> cta_label="查看草稿",<br/> draft_id="dft_xxx"}

    Note over D: --- 直銷商早晨開 App ---

    D->>API: GET /api/v1/today-tasks
    API->>TodaySvc: get_today_tasks(distributor_id, task_date=today)
    TodaySvc-->>D: 5 張任務卡（依優先序排列）

    D->>API: POST /api/v1/today-tasks/{task_id}/complete
    API->>DB: UPDATE today_tasks SET status="done", completed_at=now()
    API->>DB: UPDATE sample_followups SET status="done"
```

### 4.3 發問卷一次性連結 → 客戶無登入填寫 → 回填活檔案

```mermaid
sequenceDiagram
    participant D as 直銷商 PWA
    participant API as FastAPI Backend
    participant QSvc as questionnaire_service
    participant ContactSvc as contact_service
    participant Sonnet as Sonnet 4.6
    participant Comp as compliance_sidecar
    participant DB as PostgreSQL
    participant Client as 客戶（無需登入）

    D->>API: POST /api/v1/contacts/ctc_abc/questionnaire-links
    API->>QSvc: create_questionnaire_link(<br/>  contact_id, distributor_id, tenant_id,<br/>  template_id<br/>)
    QSvc->>DB: INSERT questionnaire_links<br/>{token="qlnk_rand_token",<br/> expires_at=now()+7d,<br/> is_active=true}
    QSvc-->>D: {link_url: "https://app/q/qlnk_rand_token",<br/> expires_at: "2026-06-09T..."}

    D->>Client: 透過 LINE / WhatsApp 分享連結

    Note over Client: 客戶點開連結（無需登入）

    Client->>API: GET /api/v1/questionnaire-links/qlnk_rand_token
    API->>QSvc: get_template_by_token(token)
    QSvc->>DB: SELECT questionnaire_links + questionnaire_templates<br/>WHERE token="qlnk_rand_token"<br/>  AND expires_at 大於 now()<br/>  AND filled_at IS NULL
    DB-->>QSvc: 12 題模板
    QSvc-->>Client: {questions: [...12 題...]}

    Client->>API: POST /api/v1/questionnaire-links/qlnk_rand_token/submit<br/>{answers: {q1: "...", q2: "...", ...}}
    API->>QSvc: submit_questionnaire(token, answers)

    QSvc->>DB: UPDATE questionnaire_links<br/> SET filled_at=now(), is_active=false

    QSvc->>Sonnet: generate_summary(answers, contact_context)
    Sonnet-->>QSvc: ai_summary + care_angle

    QSvc->>Comp: check(ai_summary + care_angle)
    Comp->>DB: INSERT compliance_checks<br/>{source_type="questionnaire_summary", ...}
    Comp-->>QSvc: {result: "green"}

    QSvc->>DB: INSERT questionnaire_responses<br/>{answers, ai_summary, care_angle,<br/> compliance_status="green",<br/> submitted_at, processed_at=now()}

    QSvc->>ContactSvc: patch_contact_from_questionnaire(<br/>  contact_id,<br/>  health_concerns=[...抽取結果...]<br/>)
    ContactSvc->>DB: UPDATE contacts<br/> SET health_concerns=ARRAY[...],<br/>     updated_at=now()

    QSvc->>DB: INSERT today_tasks<br/>{source_type="life_event",<br/> reason="Anna 剛填完問卷，睡眠與壓力是主要關注",<br/> cta_label="查看問卷摘要"}

    API-->>Client: 200 OK {message: "感謝填寫！"}

    Note over D: 直銷商收到 App 通知<br/>點開看問卷摘要與後續建議切角
```

### 4.4 LINE OA 收訊 → 輪派 → 草稿審核 → 教練發送

本流程涵蓋 LINE 訊息進入、驗簽、聯絡人建立/比對、新客戶輪派、inbound_messages 寫入、今日 5 件事「待回覆」卡產生、自動草稿生成（含三道檢查）、教練審核後手動發送。

非 OA 客戶（尚未加入 LINE OA 好友）維持原有流程：直銷商手動補資料並複製草稿到 LINE 外部傳送。

```mermaid
sequenceDiagram
    participant CL as 客戶 LINE
    participant LP as LINE Platform
    participant WH as WebhookHandler
    participant AS as AssignmentService
    participant SVC as ServiceLayer
    participant Comp as compliance_sidecar
    participant LG as LangGraph
    participant Haiku as Haiku 4.5
    participant Sonnet as Sonnet 4.6
    participant DB as PostgreSQL
    participant PWA as 教練 PWA

    CL->>LP: 傳訊給 LINE OA
    LP->>WH: POST /api/v1/webhooks/line<br/>X-Line-Signature
    WH->>WH: 驗簽 HMAC-SHA256<br/>channel_secret
    Note over WH: 驗簽失敗 → 400 Bad Request

    WH->>DB: SELECT contacts WHERE line_user_id=$1<br/>AND tenant_id=$2
    DB-->>WH: 找到 / 未找到

    Note over WH: 新客戶（未找到）→ 輪派流程
    WH->>AS: assign_new_contact(oa_id, line_user_id)
    AS->>DB: SELECT official_accounts<br/>WHERE id=$1 FOR UPDATE
    AS->>DB: 取下一位 active 教練<br/>assignment_cursor 遞增
    AS->>DB: INSERT contacts<br/>line_user_id, source="line_oa"<br/>distributor_id, assigned_at
    AS-->>WH: contact_id, coach_id

    WH->>DB: INSERT inbound_messages<br/>contact_id, line_user_id<br/>raw_text, received_at

    WH->>DB: INSERT today_tasks<br/>source_type="inbound_reply"<br/>coach_id, reason="待回覆"<br/>cta_label="查看並回覆"

    Note over WH: 既有客戶（sticky）→ 跳過輪派<br/>直接用 contacts.distributor_id

    WH->>SVC: generate_reply_draft(contact_id, inbound_id)
    SVC->>SVC: 三道前置檢查<br/>1. emotion_service<br/>2. salesy_alert_service<br/>3. compliance_sidecar pre_check
    SVC->>LG: invoke_draft_agent(context)
    LG->>Haiku: generate_first_token
    Haiku-->>LG: first_token
    LG->>Sonnet: stream_full_draft
    Sonnet-->>LG: token stream
    SVC->>Comp: check(full_draft_text)
    Note over Comp: 紅燈 → 草稿標記 blocked<br/>教練看到警示，不可發送
    Comp-->>SVC: compliance_result
    SVC->>DB: INSERT message_drafts<br/>channel="line_oa"<br/>in_reply_to_inbound_id<br/>delivery_method="line_push"<br/>compliance_status

    SVC-->>PWA: 推播通知教練<br/>今日 5 件事「待回覆」卡更新

    Note over PWA: 教練在 App 審核草稿
    PWA->>SVC: POST /api/v1/message-drafts/dft_xxx/send
    Note over SVC: 合規燈號紅燈 → 403 拒絕發送
    SVC->>Comp: 再次合規確認
    Comp-->>SVC: green / yellow
    SVC->>DB: UPDATE message_drafts<br/>sent_at=now(), line_message_id
    SVC->>LP: LINE Messaging API push message<br/>to line_user_id
    LP->>CL: 訊息送達（以 OA 名義）
    SVC-->>PWA: 200 OK sent_at
```

**說明：**

- reply token 有效期約 1 分鐘，逾期改用 push message（免費額度內免費，超量依 LINE 計費）
- 客戶須先加 LINE OA 好友，才能收到 push message
- AI 不自動發送；紅燈合規阻擋發送按鈕
- 非 OA 客戶（`source != "line_oa"`）不走本流程，教練手動複製草稿至 LINE 外部傳送
- 教練亦可將回覆轉為語音草稿，試聽後按發送 → LINE audio message push（見 3.6 VoiceProvider）

### 4.5 來訊自動分析管線（inbound enrichment，單次 Haiku 三合一）

每則 OA 來訊寫入 `inbound_messages` 後，觸發**非同步** enrichment 任務（不阻擋 webhook 3 秒回應；待回覆卡先產生，分析結果完成後補上）：

```
inbound_messages 寫入（webhook 已回 200）
  │
  ▼
enrichment_service.enrich(inbound_id)   ← 非同步背景任務
  │
  ├─ 單次 Haiku 4.5 呼叫，一次輸出三件事（控制成本，G.5）：
  │   {
  │     "emotion": "stressed" | "neutral" | "happy",        → T03：更新 contacts.current_emotion
  │     "life_events": [{type, summary}],                   → T02：產生關懷提醒 today_task
  │     "profile_suggestions": [{field, value, evidence}]   → T01：寫入 contact_suggestions（status=pending）
  │   }
  │
  ├─ G.7 唯讀硬限制：只產生建議，不自動回覆、不直接寫 contacts
  │   （contact_suggestions 須教練 confirm 才 patch 進活檔案）
  │
  ├─ 成本：計入該教練 usage_quotas.ai_cost_usd_today（熔斷時跳過分析、僅記 log，不影響收訊）
  │
  ├─ 失敗處理：分析失敗不影響收訊與待回覆卡（Sentry 告警，學習紀錄標記）
  │
  └─ 學習紀錄：寫入 inbound_enriched 事件
```

**T04 自動計數**：OA 管道由 `message_drafts.sent_at` 自動累計推銷型訊息 streak（純規則判定，無 AI）；教練按「發送」第 3 則推銷型訊息前，後端回傳 `salesy_warning`，前端彈出預警 dialog，教練可選擇仍要發送（記錄 `salesy_alert_acknowledged` / `dismissed`）。

**隱私**：`inbound_messages.raw_text` 比照 `contacts.raw_input` at-rest 加密；OA 歡迎訊息告知客戶「訊息會由 AI 協助整理，供您的服務教練參考；不會由 AI 自動回覆」（告知文字經法務確認）。

---

## 5. 多租戶隔離架構

### 5.1 隔離機制

Care Copilot 的多租戶隔離以 RLS（Postgres 原生 Row Level Security）為主力，後端 `TenantContext Middleware` 為第一道防線：

```
請求進入
  │
  ▼
AuthMiddleware（app/core/auth.py）
  ├── 驗證 FastAPI 自建 JWT（exp, sig HS256）
  ├── 抽取 sub → distributor_id
  ├── 抽取 tenant_id（JWT claims 扁平欄位）
  ├── 抽取 role（distributor / leader）
  └── 注入 TenantContext(distributor_id, tenant_id, role)
  │
  ▼
Service 層（所有 DB 查詢強制帶 tenant_id）
  ├── contact_service.get_contact(contact_id, tenant_ctx)
  │   ├── distributor role → WHERE tenant_id=$1 AND distributor_id=$2（只看自己）
  │   └── leader role     → WHERE tenant_id=$1（看全租戶）
  └── ... （所有 service 方法簽名含 tenant_ctx）
  │
  ▼
RLS Policy（資料庫層最後防線，Postgres 原生）
  ├── 三個 session 變數（每交易注入）：
  │   ├── app.current_tenant_id   ← tenant_id
  │   ├── app.current_distributor ← distributor_id
  │   └── app.current_role        ← "distributor" | "leader"
  ├── distributor policy：tenant_id = current_tenant_id
  │   AND (distributor_id = current_distributor OR current_role='leader')
  └── ... （所有 care schema 資料表均有同款 policy）
```

**輪派與 sticky 隔離**：`official_accounts.assignment_cursor` 為租戶層級，多個教練共享同一輪派游標；已指派的 `contacts.distributor_id` 確保 sticky（同一客戶下次來訊仍指向同一教練）。Leader 可在 App 手動改派，更新 `contacts.distributor_id`，同步更新 `today_tasks` 指派對象。

### 5.2 RLS Policy 範例（Postgres 原生）

```sql
-- 以 contacts 資料表為例，所有 care schema 資料表套用相同模式
ALTER TABLE care.contacts ENABLE ROW LEVEL SECURITY;

-- distributor：只看自己負責的 contacts
-- leader：看全租戶所有 contacts
CREATE POLICY "tenant_distributor_isolation"
ON care.contacts
FOR ALL
USING (
    tenant_id = current_setting('app.current_tenant_id', true)::uuid
    AND (
        current_setting('app.current_role', true) = 'leader'
        OR distributor_id = current_setting('app.current_distributor', true)::uuid
    )
);

-- 後端連線時必須在每個交易注入三個 session 變數
-- app/db/session.py
-- await conn.execute("""
--     SET LOCAL app.current_tenant_id  = $1;
--     SET LOCAL app.current_distributor = $2;
--     SET LOCAL app.current_role        = $3
-- """, [str(tenant_id), str(distributor_id), role])
-- 應用程式以非 BYPASSRLS 的 DB role 連線
```

### 5.3 跨租戶 404 機制

跨租戶存取時，RLS 會讓查詢回傳空結果，後端邏輯統一以 `404 NOT_FOUND` 回應（不使用 `403 FORBIDDEN`，避免洩漏資源存在性）：

```python
# app/services/contact_service.py
async def get_contact(contact_id: str, tenant_ctx: TenantContext) -> Contact:
    result = await db.execute(
        "SELECT * FROM care.contacts WHERE id = $1",  # RLS 自動附加 tenant_id 條件
        [contact_id]
    )
    if not result:
        raise NotFoundException(f"Contact {contact_id} not found")
        # → HTTP 404 NOT_FOUND（不論是真不存在還是跨租戶）
```

### 5.4 紅隊測試要求

以下三項測試在 CI pipeline 中強制執行（所有場景必須通過後才能 merge）：

| 測試 ID | 描述 | 預期結果 |
| :--- | :--- | :--- |
| R001 | 直銷商 A（tnt_001）嘗試 GET `/api/v1/contacts/ctc_b001`（屬於 tnt_002） | 404 NOT_FOUND |
| R002 | 直銷商 A 嘗試 GET `/api/v1/message-drafts/dft_b001`（屬於 tnt_002） | 404 NOT_FOUND |
| R003 | JWT sub（usr_a001）與路徑中 distributor_id（usr_b002）不符時 | 403 FORBIDDEN（此案例可 403，因路徑明顯偽造）|
| R004 | 刪除 JWT 中的 tenant_id，發送請求 | 401 UNAUTHORIZED（Middleware 拒絕） |
| R005 | 直銷商 B 嘗試列出直銷商 A 的 today-tasks | 回傳空列表（RLS 過濾，非 404） |

**整合測試覆蓋要求**：RLS policy 必須有 integration test（不可只做 unit test mock），使用兩個不同 tenant 的測試帳號交叉驗證。

---

## 6. 部署視圖（概念）

環境策略與部署指令見 [./06_project-structure.md](./06_project-structure.md)，本章提供概念視圖。

### 6.1 環境定義

| 環境 | 用途 | 基礎設施 |
| :--- | :--- | :--- |
| Dev（本機） | 工程師開發與測試 | Docker Compose（pgvector container + FastAPI uvicorn + Vite dev） |
| Staging | Pilot 前驗收測試 | 假設：雲端單機或同 Prod 區隔 namespace（詳見 06_infra） |
| Prod | 4 週 Pilot 正式運行 | GCP Cloud Run（後端）+ Cloud Storage + Cloud CDN（前端 PWA）+ PostgreSQL 16 自建 container 或待評估 Cloud SQL for PostgreSQL + GCS（語音）+ GCP Secret Manager（機密） |

假設：v1 Pilot 規模小（11 人），Cloud Run 單服務即可，不需 Kubernetes。

### 6.2 本機開發啟動

```bash
# 後端（repo 根 backend/）
cd D:/project/synergy/backend
uv sync
uv run uvicorn app.main:app --reload --port 8002

# 前端（repo 根 frontend/）
cd D:/project/synergy/frontend
npm install
npm run dev   # :3002

# 資料庫（pgvector container）
# docker-compose.yml 位於 repo 根 D:/project/synergy/
docker compose up -d postgres   # 啟動 pgvector/pgvector:pg16 container，port 5432
# 連線：DATABASE_URL=postgresql+asyncpg://care:care@localhost:5432/care_db
# 首次 migration：uv run alembic upgrade head
```

### 6.3 CI/CD 概念流程

```
git push → GitHub Actions
  │
  ├── Lint（ruff, mypy, eslint）
  ├── Unit Tests（pytest 後端 + vitest 前端）
  ├── Integration Tests（含紅隊測試 R001–R005）
  ├── Build Docker image（後端）+ Vite build（前端）
  │
  ├── [Staging] Deploy → Run smoke tests
  │
  └── [Prod] 手動 approve → Deploy → 健康檢查
```

---

## 7. NFR 實現策略

對應 PRD 第 6 章非功能需求：

### 7.1 反應速度（直銷商不耐煩之前出來）

| 操作 | 目標 | 實現策略 |
| :--- | :--- | :--- |
| App 首頁載入（today-tasks） | < 2s | PWA Service Worker 快取靜態資源；今日任務 APScheduler 預先算好，查詢走索引 |
| 情緒感測 | < 1s | Haiku 4.5 低延遲；結果快取至 contacts.current_emotion，30 分鐘有效 |
| 草稿首字出現 | < 500ms | Haiku 4.5 生首字，SSE 即時推送 |
| 草稿全文完成 | < 3s | Sonnet 4.6 streaming；前端顯示 token 逐字動畫 |
| 異議處理三種回應 | < 2s | Haiku 4.5；無前置合規（生成後才掃） |
| 今日 5 件事 API | < 200ms | 規則排序（v1），結果預算；無 AI 呼叫 |

### 7.2 語音生成（10 秒左右生好）

- 單段語音上限 60 秒，目標生成時間 < 10s
- 若輸入文字預估 > 60 秒，後端在 TTS 呼叫前回傳 `422 VOICE_DURATION_EXCEEDED`（預估算法：中文約 4 字/秒，英文約 2.5 字/秒，假設值，需供應商選型後校正）
- 語音檔上傳至 GCS：未發送的 7 天後自動刪除；**已透過 OA 發送的保存 30 天**（`voice_clips.retention_until`，APScheduler 清理 job 執行刪除），確保客戶在保存期內可重播

### 7.3 資料復原（RPO 15 分鐘）

- PostgreSQL WAL archiving 啟用（自建 container dev 可配置；prod Cloud SQL 支援自動備份與 PITR）
- 本機開發：docker volume + 定期備份腳本（假設：每 15 分鐘一次）
- 目標 RPO ≤ 15 分鐘

### 7.4 成本 $0.30/日 熔斷

實現三層防護：

1. **Freemium 配額硬上限**（`usage_quotas` 表）：草稿 5/日、語音 3/日、聯絡人 30 個
2. **成本熔斷**（`usage_quotas.ai_cost_usd_today`）：達 `cost_limit_usd`（預設 0.30）即阻擋所有後續 AI 請求，回傳 `429 COST_LIMIT_REACHED`
3. **Langfuse 每日告警**：ai_cost_usd_today > 0.25 → 預警；> 0.30 → Slack 告警

Freemium 配額上限表：

| 資源 | Freemium | Pro ($39) | Pro Plus ($79) |
| :--- | :--- | :--- | :--- |
| contacts_total | 30 | 9999 | 9999 |
| drafts_used_today | 5 | 9999 | 9999 |
| voice_used_today | 3 | 10 | 9999 |
| ai_cost_usd_today 上限 | 0.30 | 0.30 | 0.30 |

### 7.5 合規 100% 紀錄

所有 `compliance_sidecar.check()` 呼叫結果強制寫入 `compliance_checks`，包含：
- `input_text`（被掃描文字）
- `result`（green/yellow/red）
- `triggered_terms`（觸發詞陣列）
- `latency_ms`（必須 < 50ms，超過即 Sentry 告警）

若寫入失敗，`compliance_sidecar` 拋出例外，主流程也應失敗（與學習紀錄不同，合規紀錄寫入失敗須阻斷）。

### 7.6 系統可用性（Pilot 期不掛掉）

- 核心 API 目標：99%+ uptime（Pilot 11 人規模）
- 健康檢查端點：`GET /api/v1/health`（DB 連線、Anthropic API 可達性、配額服務）
- AI 供應商不可用時：降級回傳 `503 AI_PROVIDER_ERROR`，不靜默失敗

---

## 8. 跨領域關注點

### 8.1 可觀測性

三個工具各司其職，互補不重疊：

| 工具 | 角色 | 關鍵指標 |
| :--- | :--- | :--- |
| OpenTelemetry (OTel) 1.x | 分散式追蹤（trace）與指標（metrics）基礎設施；後端所有 service 方法自動 instrument | Span 延遲、API 請求量、錯誤率 |
| Langfuse 3.x | 專用 AI trace；LLM span（含 prompt/completion token 數）、每次呼叫成本計量、草稿採用率 | prompt_tokens, completion_tokens, cost_usd, draft_adoption_rate |
| Sentry | 前後端例外聚合；前端 JS SDK + 後端 Python SDK | Error rate, 堆疊追蹤, 影響用戶數 |

OTel Collector 接收後端 OTLP spans，可匯出至 Jaeger（本機）或 GCP Cloud Trace（Prod）。

**關鍵 Alert 定義**：

| 告警 | 條件 | 通知目標 |
| :--- | :--- | :--- |
| AI 成本預警 | ai_cost_usd_today > 0.25 任一直銷商 | Slack #ops-alerts |
| AI 成本熔斷 | ai_cost_usd_today > 0.30 | Slack #ops-alerts + PagerDuty |
| 合規掃描超時 | latency_ms > 50ms | Sentry 告警 |
| API 錯誤率 | 5xx > 1% / 5 分鐘 | Sentry + Slack |
| AI 供應商不可用 | AI_PROVIDER_ERROR 連續 3 次 | Sentry + Slack |

### 8.2 安全

**威脅模型（簡版）**：

| 威脅 | 防護措施 |
| :--- | :--- |
| 跨租戶資料洩露 | RLS（Postgres 原生）+ TenantContext Middleware；404 不透露資源存在性 |
| JWT 偽造 / 重放 | HS256 自驗簽名；exp 強制；Phase II 加 Refresh token rotation |
| 個資未授權存取（客戶） | contacts.raw_input 加密存（application-layer AES-256，假設）；contacts 需 distributor_id 匹配 |
| XSS（前端） | React 預設 escape；CSP header；Sentry 監控 |
| SQL Injection | SQLAlchemy ORM 參數化；asyncpg 參數化 |
| TTS 語音隱私 | 使用無個人特徵的合成音色；不送入訓練；GCS V4 Signed URL 7 天 TTL |
| AI 幻覺造成不實宣稱 | 合規 sidecar 100% 掃描；可宣稱清單（brand_products.allowed_claims）參考 |

**機密管理**：

- 所有 API Key（Anthropic、TTS 供應商、JWT_SECRET）存入環境變數，不硬編碼
- 本機開發使用 `.env`（已在 `.gitignore`）
- Staging/Prod 使用 GCP Secret Manager
- 機密輪換：任何可能已暴露的 key 立即輪換，見 security.md 規範

### 8.3 成本控管機制（彙整）

```
每次 AI 呼叫
  │
  ▼
1. Langfuse span 記錄 token + cost
  │
  ▼
2. usage_quotas.ai_cost_usd_today += cost（同步更新）
  │
  ├─ cost >= cost_limit_usd → 429 COST_LIMIT_REACHED（熔斷）
  │
  ▼
3. Langfuse daily dashboard → 超 0.25 → Slack 預警
                             → 超 0.30 → Slack + PagerDuty
```

Freemium 配額：

```
每次 draft/voice 生成
  │
  ▼
usage_quotas 取今日配額
  │
  ├─ drafts_used_today >= drafts_limit → 429 QUOTA_EXCEEDED
  │   {"quota_type": "drafts", "limit": 5, "used": 5,
  │    "upgrade_url": "/subscription/upgrade"}
  │
  └─ 通過 → 生成後 drafts_used_today += 1
```

---

## 9. 風險與演進路線

### 9.1 Phase I 高風險項目（節錄自 PRD 第 10 章）

| 風險 | 等級 | 緩解策略 |
| :--- | :--- | :--- |
| AI 幻覺造成不實產品宣稱 | 高 | 合規 sidecar 100% 掃描；allowed_claims 正面清單；法務 review 詞庫 |
| FTC/FDA 收入保證 / 療效宣稱踩線 | 高 | 招募話術走最嚴格合規；健康問卷摘要過合規 gate；詞庫版本控管 |
| 合規低語精簡版太薄（50 詞） | 中 | W4 觀察觸發率；觸發率 < 5% 代表詞庫太寬鬆；> 30% 代表誤判率過高 |
| 情緒感測器誤判 | 中 | UI 一鍵覆蓋；learning_logs 收集修正案例；W4 後調模型 |
| 太業務員警報誤觸頻繁 | 中 | 規則寬鬆起；dismiss_rate > 30% 即調寬規則 |
| 語音 TTS 供應商選型延遲（W4 前） | 中 | VoiceProvider 介面已抽象化；可快速切換；W4 前必須選型 |
| 語音成本爆量 | 中 | Freemium 3/日、Pro 10/日限額；ai_cost_usd_today 熔斷 |
| 健康問卷涉醫療診斷越界 | 高 | 摘要過合規 gate；法務 review 問卷模板（P0 待辦，見 PRD 第 9 章） |
| AI Architect / 法務顧問缺位（PRD P0） | 高 | 本 Pilot 開始前必須鎖定（見 PRD 9 章 Kill Criteria） |

### 9.2 Phase I → Phase II → Phase III 演進路線

```
Phase I（4 週 Pilot，本文件範圍）
│  規模：11 人（5 教練 + 1 Leader + 5 下線）
│  精簡版工具：情緒三檔 / 太業務員純規則 / 合規 50 詞 / TTS 文字轉語音 / 問卷單模板
│  AI：LangGraph 既有框架 / Haiku + Sonnet
│  租戶：多品牌資料模型 Day 1 抽象，無管理 UI
│  LINE 整合：LINE OA 收訊 + 輔助回覆（教練審核後手動發送）
│     ├─ 每租戶一個 LINE OA，客戶加好友後傳訊
│     ├─ webhook 收訊 → 新客戶輪派 → 今日5件事「待回覆」卡
│     ├─ 來訊自動分析（單次 Haiku 三合一：情緒/事件/活檔案建議）
│     ├─ 自動生草稿（過三道合規 gate）→ 教練審核 → 手動按發送
│     ├─ 語音草稿可試聽後經 OA push 發送（audio message）
│     └─ AI 不自動發送；紅燈阻擋發送
│
▼
Phase II（PMF 後擴展，假設 W4+ 通過 PMF Gate）
│  升級路徑：
│  ├─ 情緒感測器：三檔 → 細情緒光譜 + 歷史趨勢圖
│  ├─ 太業務員警報：純規則 → LLM 細判語氣轉折（Haiku 4.5）
│  ├─ 合規低語：50 詞 → 600 詞 + LLM 二審
│  ├─ 語音草稿：TTS → 自錄變體 + 多音色
│  ├─ 健康問卷：單模板 → 多版本 A/B + 即時分析
│  ├─ Leader Dashboard：下線活躍度 + 下線訊息合規監控
│  ├─ LINE 進階：主動群發 / Flex Message 排版（需 LINE 額度評估）
│  ├─ 定價：Leader Team $129（含 10 下線 seat）上線
│  └─ 規模：Top 10 Leader × 下線，數百用戶
│
▼
Phase III（跨產業 / 品牌後台，18 個月後）
   ├─ 跨產業擴展：房仲、保險、美髮（獨立合規詞庫）
   ├─ 品牌後台 UI：Brand Admin 管理合規詞庫、產品可宣稱清單
   ├─ LINE 自動回覆 / 多平台擴展：WhatsApp、Instagram DM（若法規允許）
   └─ 多語系支援（英文、泰文等東南亞市場）
```

### 9.3 架構演進原則

Phase I 設計決策中，以下已為未來演進預留空間：

| 決策 | Phase I 狀態 | 演進方向 |
| :--- | :--- | :--- |
| tenants 多租戶抽象 | 資料模型 Day 1 就緒，無管理 UI | Phase III 開放品牌後台 |
| VoiceProvider 介面 | 抽象化，W4 前選型 | 供應商可隨時切換，不需改業務邏輯 |
| LangGraph 編排 | 沿用既有框架 | Phase II 加厚 Agent 定義，框架不換 |
| learning_logs | Day 1 全量寫入 | Phase II 作為模型微調素材 |
| brand_products.allowed_claims | 正面清單欄位就緒 | Phase II/III 品牌後台填充 |
| compliance_lexicon 版本控管 | version 欄位就緒 | Phase II 升至 600 詞；Phase III 多品牌詞庫 |

---

*文件結尾*

*本文件由 Claude Code (claude-sonnet-4-6) 依據 PRD v0.3 與共用契約 v1.0 自動生成，版本 v0.1，2026-06-02。如需修改欄位名稱、路徑或 enum 值，請先更新 `docs/0516_vibecoding_template/mvp/contract.md` 並通知所有下游技術文件擁有者同步。*
