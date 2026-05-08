# 專案結構指南 — Synergy AI Closer's Copilot

> **版本:** v3.0 | **更新:** 2026-05-08
> **對應架構決策：** ADR-002（扁平 monorepo）、ADR-013（前端改 React + Vite）、ADR-010/011/012（Phase I 新模組）

---

## 設計原則

- **按功能組織**：相關功能放一起（非按類型分散）
- **明確職責**：每個目錄單一職責
- **一致命名**：目錄 `kebab-case`、Python `snake_case.py`、TS `kebab-case.ts`、測試 `test_*` 前綴
- **配置外部化**：env vars + `.env` 本機、部署平台管正式
- **根目錄簡潔**：原始碼放在 `apps/` 與 `packages/`，根層只放 workspace 設定

---

## 頂層結構

```
synergy/
├── .claude/                    # Claude Code 設定（現有）
├── .github/                    # CI/CD workflows
├── apps/                       # 應用程式（部署單元）
│   ├── web/                    # React 19 + Vite 前端（ADR-013）
│   └── api/                    # FastAPI 後端 + 排程器
├── packages/                   # 共用套件（workspace 內）
│   ├── domain/                 # 型別契約（TS + Python dual）
│   ├── llm/                    # LLM 抽象層 + prompts
│   └── ui/                     # React 元件 + Apple tokens
├── modules/                    # 舊 POC 參考（只讀，不進新開發）
│   ├── module1-distributor/    # 貼文自動化（Phase 2 再啟用）
│   └── module2-questionnaire/  # 問卷 POC（邏輯遷移至 apps/api）
├── docs/                       # 專案文檔（本資料夾）
│   ├── 01_prd.md
│   ├── 02_bdd.md
│   ├── ... (本系列)
│   └── adr/                    # 未來單獨 ADR 檔
├── system_design_docs/         # 原始策略文件（客戶提供）
├── VibeCoding_Workflow_Templates/  # 範本庫
├── scripts/                    # 開發/維運腳本
│   ├── seed-dev-data.py
│   └── migrate.sh
├── .env.example
├── .gitignore
├── .gitattributes
├── pnpm-workspace.yaml         # pnpm workspace
├── package.json                # 根層（scripts 統一入口）
├── uv.lock                     # Python workspace lock
├── CLAUDE.md                   # 根層指引
└── README.md
```

---

## `apps/web/` — React 19 + Vite 前端

```
apps/web/
├── index.html                  # HTML 進入點
├── vite.config.ts              # Vite 設定（React plugin）
├── tsconfig.json
├── package.json
├── src/
│   ├── main.tsx                # 應用根進入點
│   ├── App.tsx                 # Router 根元件
│   ├── routes/                 # react-router-dom v7 路由
│   │   ├── public/
│   │   │   ├── questionnaire-page.tsx    # GET /q/:token
│   │   │   └── questionnaire-complete.tsx # GET /q/:token/complete
│   │   ├── auth/
│   │   │   └── callback.tsx             # Supabase Magic Link 回調
│   │   ├── coach/              # Protected routes
│   │   │   ├── leads-page.tsx           # GET /leads
│   │   │   ├── lead-detail-page.tsx     # GET /leads/:id
│   │   │   ├── conversation/
│   │   │   │   ├── pre-briefing.tsx     # GET /leads/:id/conversation/pre
│   │   │   │   ├── in-session.tsx       # GET /leads/:id/conversation/in-session
│   │   │   │   └── post-followup.tsx    # GET /leads/:id/conversation/post
│   │   │   ├── customer-summary.tsx     # GET /leads/:id/summary/customer
│   │   │   └── reminders-page.tsx       # GET /reminders
│   │   ├── compliance/
│   │   │   └── queue-page.tsx           # GET /compliance/queue
│   │   └── leader/
│   │       ├── summary-page.tsx         # GET /leader/summary
│   │       ├── coach-detail-page.tsx    # GET /leader/coaches/:id
│   │       └── onboarding-page.tsx      # GET /leader/coaches/:id/onboarding
│   ├── components/             # 共用 React 元件
│   │   ├── questionnaire/
│   │   │   ├── QuestionCard.tsx
│   │   │   ├── ProgressBar.tsx
│   │   │   └── RedactToggle.tsx
│   │   ├── lead/
│   │   │   ├── LeadTable.tsx
│   │   │   ├── LeadStatusBadge.tsx
│   │   │   └── LeadFilterBar.tsx
│   │   ├── briefing/
│   │   │   ├── BriefingView.tsx
│   │   │   ├── PainPointList.tsx
│   │   │   └── ProductRecommendation.tsx
│   │   ├── compliance/
│   │   │   ├── ComplianceQueueItem.tsx
│   │   │   └── HighlightedText.tsx
│   │   └── common/
│   │       ├── EmptyState.tsx
│   │       ├── ErrorBoundary.tsx
│   │       └── ProtectedRoute.tsx
│   ├── lib/
│   │   ├── api-client.ts               # Fetch wrapper（呼叫 apps/api）
│   │   ├── supabase.ts                 # Supabase client + Auth helper
│   │   └── hooks/
│   │       ├── use-leads.ts            # React Query hooks
│   │       ├── use-briefing.ts
│   │       ├── use-compliance.ts
│   │       └── use-auth.ts
│   ├── styles/
│   │   ├── globals.css                 # Tailwind + Apple CSS 變數
│   │   └── tokens.css                  # 從 packages/ui 複製或 import
│   ├── public/
│   │   └── logo.svg
│   └── env.d.ts                # Vite 環境變數型別
├── tests/
│   ├── e2e/                    # Playwright
│   │   ├── questionnaire.spec.ts
│   │   ├── briefing.spec.ts
│   │   └── compliance.spec.ts
│   └── unit/
│       └── components/
├── tailwind.config.ts          # 繼承 packages/ui tokens
└── CLAUDE.md
```

**v3.0 與 ADR-013 差異**：
- 結構改 Vite + react-router v7（無 Next.js App Router）
- 路由由 `routes/` 資料夾組織而非 `app/` 目錄慣例
- 環境變數改用 `VITE_*` 前綴（而非 `NEXT_PUBLIC_*`）
- 無 middleware.ts（Auth 改用 react-router 的 ProtectedRoute HOC）
- React Query 用於 API 狀態管理（無 getServerSideProps）
- SEO 用 react-helmet-async（而非 next/head）

---

## `apps/api/` — FastAPI 後端 + 排程

```
apps/api/
├── src/
│   ├── main.py                     # FastAPI app + APScheduler 啟動
│   ├── core/
│   │   ├── config.py               # pydantic-settings
│   │   ├── auth.py                 # Supabase JWT 驗證
│   │   ├── rate_limit.py
│   │   ├── logging.py              # structlog 設定
│   │   └── errors.py               # 統一錯誤格式
│   ├── domain/                     # Domain Layer
│   │   ├── questionnaire/
│   │   │   ├── entities.py
│   │   │   ├── scoring_engine.py
│   │   │   └── exceptions.py
│   │   ├── lead/
│   │   │   ├── entities.py
│   │   │   ├── status_machine.py
│   │   │   └── exceptions.py
│   │   ├── briefing/
│   │   │   ├── entities.py
│   │   │   └── exceptions.py
│   │   ├── reminder/
│   │   │   ├── entities.py
│   │   │   └── exceptions.py
│   │   ├── compliance/
│   │   │   ├── compliance_log.py
│   │   │   ├── risk_level.py
│   │   │   └── check_category.py
│   │   ├── hitl/
│   │   │   └── hitl_item.py
│   │   └── onboarding/
│   │       └── onboarding_task.py
│   ├── application/                # Application Layer
│   │   ├── questionnaire_service.py
│   │   ├── briefing_service.py
│   │   ├── lead_service.py
│   │   ├── reminder_service.py
│   │   ├── compliance/
│   │   │   ├── compliance_service.py
│   │   │   ├── rule_engine.py
│   │   │   └── llm_reviewer.py
│   │   ├── hitl/
│   │   │   ├── hitl_service.py
│   │   │   └── queue_worker.py
│   │   ├── conversation_coach/
│   │   │   ├── pre_briefing.py
│   │   │   ├── in_session_advisor.py
│   │   │   └── post_followup.py
│   │   ├── activity_tracking/
│   │   │   ├── event_recorder.py
│   │   │   └── stats_aggregator.py
│   │   ├── leader/
│   │   │   ├── leader_summary.py
│   │   │   └── coach_detail.py
│   │   └── onboarding/
│   │       └── onboarding_service.py
│   ├── infrastructure/             # Infrastructure Layer
│   │   ├── web/
│   │   │   ├── routers/
│   │   │   │   ├── questionnaire.py     # /v1/questionnaires/*
│   │   │   │   ├── lead.py              # /v1/leads/*
│   │   │   │   ├── briefing.py          # /v1/leads/{id}/briefing
│   │   │   │   ├── reminder.py          # /v1/reminders/*
│   │   │   │   ├── compliance.py        # /v1/compliance/*
│   │   │   │   ├── leader.py            # /v1/leader/*
│   │   │   │   └── internal.py          # /v1/internal/*
│   │   │   └── middleware/
│   │   │       ├── auth_middleware.py
│   │   │       ├── rate_limit_middleware.py
│   │   │       └── logging_middleware.py
│   │   ├── persistence/
│   │   │   ├── supabase_client.py
│   │   │   ├── repositories/
│   │   │   │   ├── questionnaire_repo.py
│   │   │   │   ├── lead_repo.py
│   │   │   │   ├── briefing_repo.py
│   │   │   │   ├── reminder_repo.py
│   │   │   │   ├── compliance_repo.py
│   │   │   │   └── onboarding_repo.py
│   │   │   ├── migrations/              # SQL migrations
│   │   │   │   ├── 20260508_01_add_reviewer_role.sql
│   │   │   │   ├── 20260508_02_create_compliance_tables.sql
│   │   │   │   └── ... (8 份遷移檔)
│   │   │   └── materialized_views/     # ADR-012
│   │   │       ├── mv_coach_weekly_stats.sql
│   │   │       └── mv_leader_summary.sql
│   │   ├── llm/
│   │   │   └── adapter.py               # 繫結 packages/llm
│   │   ├── notifications/
│   │   │   ├── email_channel.py         # Resend
│   │   │   └── line_channel.py          # LINE Messaging API
│   │   ├── google_calendar/
│   │   │   ├── oauth_client.py
│   │   │   └── calendar_adapter.py
│   │   └── scheduler/
│   │       ├── reminder_scheduler.py    # APScheduler jobs
│   │       └── materialized_view_refresh.py
│   └── rules/                      # 業務規則 YAML
│       ├── questionnaire-v1.yaml
│       ├── compliance-keywords.yaml
│       └── onboarding-tasks.yaml
├── tests/
│   ├── conftest.py                 # 全域 fixtures
│   ├── unit/
│   │   ├── domain/
│   │   │   ├── test_scoring_engine.py
│   │   │   └── test_lead_status_machine.py
│   │   └── application/
│   │       ├── test_briefing_service.py
│   │       ├── test_reminder_service.py
│   │       ├── test_compliance_service.py
│   │       └── test_hitl_service.py
│   ├── integration/
│   │   ├── test_questionnaire_flow.py
│   │   ├── test_reminder_scheduler.py
│   │   └── test_compliance_flow.py
│   └── features/                   # pytest-bdd
│       ├── questionnaire.feature
│       ├── briefing.feature
│       ├── crm.feature
│       ├── reminder.feature
│       ├── compliance.feature
│       └── steps/
├── pyproject.toml                  # uv 管理
├── .python-version                 # 3.12
└── CLAUDE.md
```

---

## `packages/domain/` — 共用型別契約

```
packages/domain/
├── ts/                             # TypeScript 端
│   ├── src/
│   │   ├── lead.ts
│   │   ├── briefing.ts
│   │   ├── questionnaire.ts
│   │   ├── reminder.ts
│   │   ├── compliance.ts
│   │   ├── onboarding.ts
│   │   └── index.ts
│   ├── package.json                # name: @synergy/domain
│   └── tsconfig.json
├── python/                         # Python 端
│   ├── src/
│   │   └── synergy_domain/
│   │       ├── __init__.py
│   │       ├── lead.py             # Pydantic
│   │       ├── briefing.py
│   │       ├── questionnaire.py
│   │       ├── reminder.py
│   │       ├── compliance.py
│   │       └── onboarding.py
│   └── pyproject.toml              # name: synergy-domain
└── schemas/                        # JSON Schema 單一真相來源
    ├── lead.json
    ├── briefing.json
    ├── questionnaire.json
    └── compliance.json
```

**同步策略**：以 `schemas/*.json` 為唯一來源，用 `datamodel-code-generator`（Python）與 `json-schema-to-typescript`（TS）雙向生成。手動改生成檔 = 違規。

---

## `packages/llm/` — LLM 抽象層

```
packages/llm/
├── src/
│   └── synergy_llm/
│       ├── __init__.py
│       ├── adapter.py              # LLMAdapter 介面 + LiteLLMAdapter 實作
│       ├── config.py               # 模型預設、timeout、retry
│       ├── exceptions.py
│       └── prompts/
│           ├── briefing_v1.py
│           ├── public_summary_v1.py
│           ├── compliance/
│           │   ├── medical_claim.txt
│           │   ├── income_claim.txt
│           │   ├── exaggeration.txt
│           │   └── pyramid_risk.txt
│           ├── conversation_coach/
│           │   ├── pre_briefing.txt
│           │   ├── in_session.txt
│           │   └── post_followup.txt
│           └── _helpers.py
├── tests/
│   ├── test_adapter.py             # 用 VCR.py 錄製 API 回應
│   └── test_prompts.py             # Prompt 輸出格式測試
├── pyproject.toml
└── CLAUDE.md                       # 使用規範
```

---

## `packages/ui/` — 共用 React 元件

```
packages/ui/
├── src/
│   ├── components/
│   │   ├── Button.tsx
│   │   ├── Card.tsx
│   │   ├── Input.tsx
│   │   ├── Badge.tsx
│   │   ├── Table.tsx
│   │   └── index.ts
│   ├── tokens/
│   │   ├── apple.css               # Apple CSS 變數
│   │   └── tailwind.ts             # Tailwind preset
│   └── hooks/
│       └── use-toast.ts
├── package.json                    # name: @synergy/ui
├── tsconfig.json
└── tailwind.config.ts
```

---

## `modules/` — 舊 POC 參考

```
modules/
├── module1-distributor/            # n8n + FastAPI + Vite（暫停開發）
│   └── README.md                   # ★ 標註「已凍結，參考用」
└── module2-questionnaire/          # 問卷 POC（邏輯已遷移至 apps/api）
    └── README.md                   # ★ 標註「已遷移，參考用」
```

**規則**：
- `modules/` 目錄**只讀**，不進新 PR
- 要重用其邏輯，複製到 `apps/` 或 `packages/` 並符合新結構規範
- 未來 Phase 2 重啟 module1（M1 獲客）時再決定是否遷移

---

## `docs/` — 專案文檔

```
docs/
├── INDEX.md                        # 文檔索引
├── 01_prd.md
├── 02_bdd.md
├── 03_adr.md                       # 含 ADR-001 ~ ADR-013
├── 04_architecture.md
├── 05_api.md
├── 06_modules.md
├── 07_structure.md                 # 本檔
├── 08_design_dependencies.md
├── 09_frontend_ia.md
├── 10_security.md
├── 11_deployment.md
├── 12_phase1_mvp.md
├── adr/                            # 未來拆分後的獨立 ADR
│   └── README.md
└── diagrams/                       # Mermaid / PlantUML 原始檔
```

---

## `scripts/` — 開發/維運腳本

```
scripts/
├── seed-dev-data.py                # 建立測試資料
├── migrate.sh                      # Supabase migration 統一入口
├── generate-types.sh               # schemas/*.json → TS + Python
├── run-bdd.sh
└── check-env.sh
```

---

## Workspace 設定

### `pnpm-workspace.yaml`（根層）

```yaml
packages:
  - "apps/web"
  - "packages/ui"
  - "packages/domain/ts"
```

### `pyproject.toml`（根層 uv workspace）

```toml
[tool.uv.workspace]
members = ["apps/api", "packages/domain/python", "packages/llm"]

[tool.uv.sources]
synergy-domain = { workspace = true }
synergy-llm = { workspace = true }
```

### 根層 `package.json`

```json
{
  "name": "synergy",
  "private": true,
  "scripts": {
    "dev": "pnpm -F @synergy/web dev & uv run --directory apps/api uvicorn src.main:app --reload",
    "test": "pnpm -r test && uv run --directory apps/api pytest",
    "lint": "pnpm -r lint && uv run --directory apps/api ruff check",
    "typecheck": "pnpm -r typecheck && uv run --directory apps/api mypy src",
    "build": "pnpm -F @synergy/web build",
    "preview": "pnpm -F @synergy/web preview"
  }
}
```

---

## 命名規範速查

| 類型 | 規範 | 範例 |
| :--- | :--- | :--- |
| 目錄 | kebab-case | `lead-management/` |
| Python 檔案 | snake_case.py | `scoring_engine.py` |
| Python 類別 | PascalCase | `ScoringEngine` |
| Python 函式/變數 | snake_case | `generate_summary` |
| TS/TSX 檔案 | kebab-case.ts/tsx | `lead-table.tsx`、但 component 檔名可用 PascalCase `LeadTable.tsx` |
| TS 類別/元件 | PascalCase | `LeadTable` |
| TS 函式/變數 | camelCase | `generateSummary` |
| 常數 | UPPER_SNAKE_CASE | `MAX_QUESTIONNAIRE_TTL_DAYS` |
| 測試 | `test_*.py` / `*.spec.ts` | `test_scoring_engine.py` |
| Feature 檔 | `*.feature` | `questionnaire.feature` |
| ADR 檔 | `YYYYMMDD-kebab-title.md` | `20260424-flat-monorepo.md` |
| Vite 環境變數 | `VITE_*` | `VITE_API_BASE_URL` |
| Routes 檔 | `*-page.tsx` / `*-layout.tsx` | `questionnaire-page.tsx` |

---

## 演進原則

- 本結構是 MVP 起點，Phase 2 擴張時依 ADR 調整
- 頂層結構變更（新增 `apps/*` 或 `packages/*`）需 ADR 記錄
- 一致性 > 完美結構：新功能優先遵循既有慣例
- `modules/` 最終目標是清空（Phase 2 重啟時完全遷移或 archive）

---

## v3.0 主要變更（2026-05-08）

### ADR-013：前端框架改為 React 19 + Vite

- **結構**：`apps/web/src/routes/` 路由（非 `app/` 慣例）
- **路由庫**：react-router-dom v7（內置 nested routes、data loaders）
- **環境變數**：`VITE_*` 前綴（不是 `NEXT_PUBLIC_*`）
- **部署**：Cloudflare Pages 或 Netlify（純靜態輸出）
- **SEO/Meta**：react-helmet-async（不是 next/head）
- **Auth**：React Context + ProtectedRoute HOC（不是 middleware）

### ADR-010/011/012：新增模組

- `apps/api/application/compliance/` — 合規三層防線
- `apps/api/application/hitl/` — 人工審核佇列
- `apps/api/application/conversation_coach/` — 商談前/中/後
- `apps/api/application/activity_tracking/` — 事件聚合
- `apps/api/application/leader/` — Leader Summary
- `apps/api/application/onboarding/` — 新手進度
- `apps/web/src/routes/coach/conversation/` — 商談三階段 UI
- `apps/web/src/routes/compliance/` — HITL 佇列 UI
- `apps/web/src/routes/leader/` — Leader 後台 UI

### 環境變數範例（ADR-013）

```bash
# apps/web/.env.local
VITE_API_BASE_URL=http://localhost:8000
VITE_SUPABASE_URL=https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJxx...

# apps/api/.env
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_KEY=eyJxx...
LLM_API_KEY=sk-xxxx (Gemini)
LINE_CHANNEL_ACCESS_TOKEN=xxxx
RESEND_API_KEY=xxxx
GOOGLE_CALENDAR_CLIENT_ID=xxxx
```
