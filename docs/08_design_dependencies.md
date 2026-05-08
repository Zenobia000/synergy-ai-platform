# 設計與依賴關係 — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08
> **對應架構：** `docs/04_architecture.md` | **對應結構：** `docs/07_structure.md` | **對應決策：** ADR-003、ADR-015、ADR-016、ADR-017、ADR-018

---

## 1. 分層與依賴方向

```mermaid
graph TD
    subgraph FE [apps/web - React 19 + Vite]
        UI[components/*]
        Routes[routes/*]
        Hooks[lib/hooks]
    end

    subgraph BE [apps/api - FastAPI]
        Router[infrastructure/web/routers]
        App[application/*]
        Domain[domain/*]
        Infra[infrastructure/*]
    end

    subgraph Pkg [packages]
        PkgDomain[packages/domain]
        PkgLLM[packages/llm]
        PkgUI[packages/ui]
    end

    UI --> Hooks
    Routes --> UI
    Hooks -->|HTTP| Router
    UI --> PkgUI
    Routes --> PkgDomain
    Hooks --> PkgDomain

    Router --> App
    App --> Domain
    App --> Infra
    Infra --> PkgLLM
    App --> PkgDomain
    Domain --> PkgDomain
```

**規則**：
- Domain 不依賴任何其他層（純粹業務）
- Application 只依賴 Domain 與抽象介面（不直接 import 具體 Infra）
- Infrastructure 實作 Application 定義的介面
- `packages/*` 是橫切，所有層可用

---

## 2. 核心類別圖（Domain）

```mermaid
classDiagram
    class Lead {
        +UUID id
        +UUID tenant_id
        +UUID coach_id
        +str name
        +LeadStatus status
        +HealthLevel health_level
        +list~str~ red_flags
        +datetime last_contact_at
        +update_status(new: LeadStatus) Lead
    }

    class LeadStatusMachine {
        <<static>>
        +can_transition(from, to) bool
        +valid_transitions() dict
    }

    class Questionnaire {
        +UUID id
        +UUID template_id
        +list~Answer~ answers
        +datetime submitted_at
        +mark_redacted(key: str)
        +is_complete() bool
    }

    class ScoringEngine {
        <<service>>
        +score(answers, rules) ScoringResult
    }

    class Briefing {
        +UUID id
        +UUID lead_id
        +BriefingContent content
        +str llm_model
        +int llm_tokens
        +datetime generated_at
    }

    class Reminder {
        +UUID id
        +UUID lead_id
        +ReminderKind kind
        +datetime due_at
        +datetime sent_at
        +ReminderStatus status
        +can_send() bool
        +mark_sent()
        +cancel()
    }

    Lead --> LeadStatusMachine : uses
    Lead "1" --> "1" Questionnaire : from
    Lead "1" --> "0..1" Briefing : has
    Lead "1" --> "*" Reminder : schedules
    Questionnaire --> ScoringEngine : scored by
```

---

## 3. 技術依賴清單

### 3.1 前端（`apps/web` — React 19 + Vite）

| 套件 | 版本 | 用途 | 理由 |
| :--- | :--- | :--- | :--- |
| react | ^19.0 | UI 框架 | 核心依賴 |
| typescript | ^5.5 | 型別 | — |
| vite | ^6.0 | 建置工具 | ADR-013：快速啟動、純靜態輸出 |
| @vitejs/plugin-react | ^4 | Vite React 支持 | — |
| react-router-dom | ^7.0 | 路由 | ADR-013：nested routes + data loaders |
| tailwindcss | ^4.0 | CSS | 既有 Apple tokens |
| @tanstack/react-query | ^5 | API 狀態管理 | 快取 + 重打 + optimistic update |
| ~~@supabase/supabase-js~~ | **❌ 移除** | ~~Auth + Realtime~~ | **ADR-015：改為帳密 + JWT** |
| **axios** | **^1.7** | **HTTP client** | **ADR-015：取代 Supabase client** |
| react-helmet-async | ^2 | 動態 SEO meta | ADR-013：取代 Next.js next/head |
| zod | ^3 | schema 驗證 | 與 Pydantic 概念一致 |
| @hookform/resolvers | ^3 | 表單 | 問卷複雜表單 |
| react-hook-form | ^7 | 表單狀態 | — |
| lucide-react | latest | Icon | 輕量 |
| date-fns | ^3 | 時間 | 比 moment 輕 |

**移除（v3.0）取代品**：
- `next` ← 改 Vite
- `next-auth` ← 改 bcrypt + JWT
- `@supabase/supabase-js` ← 改 axios + 自建認證

### 3.2 後端（`apps/api` — FastAPI + PostgreSQL）

| 套件 | 版本 | 用途 | 理由 |
| :--- | :--- | :--- | :--- |
| fastapi | ^0.115 | REST API | — |
| uvicorn | ^0.30 | ASGI server | — |
| pydantic | ^2.9 | 資料驗證 | Pydantic v2 更快 |
| pydantic-settings | ^2 | 配置 | 環境變數管理 |
| ~~supabase~~ | **❌ 移除** | ~~Database Client~~ | **ADR-003：改為 PostgreSQL + SQLAlchemy** |
| **asyncpg** | **^0.29** | **Async PostgreSQL driver** | **ADR-003：FastAPI async 相容** |
| **sqlalchemy[asyncio]** | **^2.0** | **ORM** | **ADR-003：取代 Supabase SDK** |
| **alembic** | **^1.13** | **Database migrations** | **ADR-003：版本管理** |
| **bcrypt** | **^4.0** | **密碼雜湊** | **ADR-015：PASSWORD hash（cost=12）** |
| ~~python-jose~~ | **改為** | **JWT library** | **ADR-015：改為 PyJWT + cryptography** |
| **PyJWT** | **^2.8** | **JWT 簽發驗證** | **ADR-015** |
| **cryptography** | **^42** | **加密** | ADR-015：PyJWT 依賴 |
| litellm | ^1.50 | LLM 抽象 | ADR-004 |
| line-bot-sdk | ^3 | LINE Messaging API（主）| ADR-016：主通道 |
| **heyoo** | **^0.0.7** | **WhatsApp Business API** | **ADR-016：簡化 WhatsApp 集成** |
| resend | ^2 | Email（備援）| ADR-016：最終備援 |
| apscheduler | ^3.10 | 排程 | 單機夠用 |
| google-auth-oauthlib | ^1.2 | Google Calendar OAuth | — |
| google-auth-httplib2 | ^0.2 | Google Calendar API | — |
| structlog | ^24 | 結構化日誌 | JSON 輸出 |
| httpx | ^0.27 | HTTP client | async |
| sentry-sdk | ^2 | 錯誤追蹤 | — |
| pyyaml | ^6 | 計分規則 YAML | 仍用於靜態規則 |
| **pgvector** | **^0.2** | **PostgreSQL vector type** | **ADR-017：embedding 儲存與查詢** |
| **google-cloud-secret-manager** | **^2** | **GCP Secret Manager** | **ADR-018：部署秘密管理** |
| **google-cloud-storage** | **^2** | **GCP Cloud Storage** | **ADR-018：檔案存儲** |
| **google-cloud-logging** | **^3** | **GCP Cloud Logging** | **ADR-018：日誌彙集** |

**移除**：
- `supabase` ← SQLAlchemy + asyncpg 取代
- `python-jose` ← PyJWT 取代

### 3.3 開發依賴

| 套件 | 用途 |
| :--- | :--- |
| pytest、pytest-asyncio、pytest-bdd、pytest-cov | 測試 |
| ruff | Lint + format |
| mypy | 型別檢查 |
| vcr.py | 錄製 HTTP 回應（LLM 測試） |
| playwright | E2E |
| eslint、prettier | TS lint |
| @testing-library/react | 元件測試 |
| @vitest/ui | Vite 測試 UI（可選） |
| msw | Mock Service Worker（API mock） |

### 3.4 LLM 供應商

| 供應商 | 模型 | 用途 | 成本估（Pilot） |
| :--- | :--- | :--- | :--- |
| Google | gemini-2.5-flash（預設） | 摘要 + 商談 + 合規 Layer 2 + embedding | 50-200 NTD |
| Anthropic | claude-haiku-4-5（備援） | 成本超標時降級；embedding 備援 | — |
| Anthropic | claude-opus-4-6（品質） | Pilot 若品質不足切換 | 500+ NTD |

---

## 4. SOLID 檢核

| 原則 | 檢核 | 實踐位置 |
| :--- | :--- | :--- |
| **S** 單一職責 | 每個 Service 一個 Bounded Context；SemanticMatcher 純函式 | `apps/api/src/application/*` 各一檔；`semantic_matcher.py` 無副作用 |
| **O** 開放封閉 | LLM / Channel / Compliance / Auth 抽象可擴充 | `LLMAdapter`、`NotificationChannel`、`ComplianceLayer`、`PasswordAuthService` Protocol |
| **L** 里氏替換 | LiteLLMAdapter、NotificationChannel、PasswordAuthService 可被測試替身取代 | 測試 fixture；VCR.py 錄製 |
| **I** 介面隔離 | Adapter 介面只暴露必要方法 | `LLMAdapter.complete()`、`ComplianceService.check()` 單一方法 |
| **D** 依賴反轉 | Application 依賴介面，不直接 import SDK；ComplianceService 依賴 SemanticMatcher interface | `ReminderService` 收 `NotificationChannel`；`ComplianceService` 收 `RuleEngine` + `SemanticMatcher` |

---

## 5. 設計模式清單

| 模式 | 使用處 | 目的 |
| :--- | :--- | :--- |
| **Repository** | `infrastructure/persistence/repositories/*` | 封裝 PostgreSQL 存取 |
| **Adapter** | `LLMAdapter`、`NotificationChannel` | 抽象外部服務 |
| **State Machine** | `LeadStatusMachine`、Reminder status flow | Lead/Reminder 狀態轉換規則 |
| **Strategy** | 計分規則 YAML + `ScoringEngine`；合規詞表 + RuleEngine | 規則可版本替換 |
| **Idempotency Key** | `POST /submit`、`regenerate` | 避免重複副作用 |
| **Background Task** | Briefing 生成、Reminder 發送、物化視圖更新 | 非阻塞主請求 |
| **Chain of Responsibility** | ComplianceService Layer 1 → 2 → 3 | ADR-010：多層檢查流程 |
| **Protected Routes** | React Router + ProtectedRoute HOC | ADR-013：auth guard（無 middleware） |
| **Context Provider** | React Context（AuthContext、ComplianceContext） | 跨頁面狀態共享 |
| **Custom Hooks** | `use-leads`、`use-compliance-queue` | 邏輯重用、測試友善 |

---

## 6. 前後端通信協議

### API Response Envelope（所有 endpoint）

```json
{
  "success": true,
  "data": { /* payload */ },
  "error": null,
  "timestamp": "2026-05-08T12:34:56Z"
}
```

### 成功案例（200 OK）

```json
{
  "success": true,
  "data": { "id": "lead-123", "status": "contacted" },
  "error": null
}
```

### 錯誤案例（4xx/5xx）

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "COMPLIANCE_HIGH_RISK",
    "message": "訊息包含醫療宣稱，需人工審核",
    "details": { "risk_level": "high", "flagged_text": "可治療..." }
  }
}
```

### 分頁中繼資料

```json
{
  "success": true,
  "data": [ /* items */ ],
  "pagination": {
    "total": 150,
    "page": 1,
    "limit": 20,
    "total_pages": 8
  }
}
```

---

## 7. Vite 與 API 通信（ADR-013）

### 環境變數（Vite）

```bash
# apps/web/.env.local（開發）
VITE_API_BASE_URL=http://localhost:8000
VITE_GEMINI_MODEL=gemini-2.5-flash
VITE_ENVIRONMENT=development

# Vite 自動 prefix 讀取 VITE_*
```

### API 客戶端封裝

```ts
// apps/web/src/lib/api-client.ts
import axios from 'axios'

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  withCredentials: true,  // 含 JWT cookie
})

client.interceptors.response.use(
  (res) => res.data,  // 解包 envelope
  (err) => Promise.reject(err.response?.data?.error || err)
)

export default client
```

---

## ✨ v3.1 補丁（2026-05-08）

### 認證與依賴變更（ADR-015）

**移除**：
- Supabase Client：`@supabase/supabase-js`
- Magic Link / OTP：不需 Resend（仍用於其他郵件）

**新增**：
- `bcrypt ^4`（密碼雜湊，cost=12）
- `PyJWT ^2.8`（JWT 簽發與驗證）
- `cryptography ^42`（加密基礎）
- FE：`axios ^1.7`（HTTP client 統一用 axios）

**後端新環境變數**：
- `BCRYPT_COST=12`
- `PASSWORD_MIN_LENGTH=10`
- `JWT_SECRET=<強密鑰>`
- `JWT_ALGORITHM=HS256`
- `JWT_ACCESS_EXPIRY=3600` (1h)
- `JWT_REFRESH_EXPIRY=604800` (7d)

### DB 與依賴變更（ADR-003）

**移除**：
- `supabase` — Supabase Python SDK

**新增**：
- `asyncpg ^0.29` — Async PostgreSQL driver
- `sqlalchemy[asyncio] ^2.0` — ORM
- `alembic ^1.13` — Migration 工具

**後端新環境變數**：
- `DATABASE_URL=postgresql+asyncpg://synergy:synergy@localhost:5432/synergy`
- `SQLALCHEMY_LOG_SQL=false`（開發時可 true）

### 通知通道擴充（ADR-016）

**新增**：
- `heyoo ^0.0.7` — WhatsApp Business API wrapper

**後端新環境變數**：
- `WHATSAPP_ACCESS_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_VERIFY_TOKEN`
- `WHATSAPP_BUSINESS_ACCOUNT_ID` (可選)

### 規則庫 DB 化（ADR-017）

**新增**：
- `pgvector ^0.2` — PostgreSQL vector 型別與操作

**後端新環境變數**：
- `EMBEDDING_MODEL=models/embedding-001` (Gemini)
- `EMBEDDING_DIMENSION=768`
- `SEMANTIC_SIMILARITY_THRESHOLD=0.85`

### GCP 部署（ADR-018）

**新增**：
- `google-cloud-secret-manager ^2`
- `google-cloud-storage ^2`
- `google-cloud-logging ^3`

**後端新環境變數**：
- `GCP_PROJECT_ID`
- `GCP_REGION=asia-east1`
- `SECRET_MANAGER_PREFIX=synergy-`
- `GOOGLE_APPLICATION_CREDENTIALS` (Cloud Run IAM 注入)

### 本地開發（Docker）

**docker-compose.yml**：
```yaml
version: "3.8"
services:
  postgres:
    image: pgvector/pgvector:pg17
    environment:
      POSTGRES_USER: synergy
      POSTGRES_PASSWORD: synergy
      POSTGRES_DB: synergy
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synergy"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

### 環境變數對照（本地 vs Cloud Run）

| 變數 | 本地開發 | Cloud Run |
| :--- | :--- | :--- |
| `DATABASE_URL` | `postgresql+asyncpg://...@localhost:5432/...` | Cloud SQL Auth Proxy 或 Managed Connection |
| `JWT_SECRET` | 本地測試金鑰 | Secret Manager `synergy-jwt-secret` |
| `BCRYPT_COST` | 12 | 同 |
| `WHATSAPP_*` | `.env` 本地 | Secret Manager `synergy-whatsapp-*` |
| `GCP_PROJECT_ID` | (skip 本地) | Cloud Run 自動注入 |
| `GOOGLE_APPLICATION_CREDENTIALS` | (skip 本地) | Cloud Run IAM 注入 |

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v3.0 | 2026-05-08 | 初版（Supabase + Next.js 依賴） |
| **v3.1** | **2026-05-08** | **⚠️ 新增 bcrypt + PyJWT + SQLAlchemy + asyncpg + pgvector + WhatsApp + GCP 服務；移除 Supabase；FE 改用 axios** |
