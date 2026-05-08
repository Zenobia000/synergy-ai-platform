# 專案結構指南 — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08
> **對應架構決策：** ADR-002（扁平 monorepo）、ADR-013（前端改 React + Vite）、ADR-015/016/017/018（v3.1 新增認證、WhatsApp、規則 DB、GCP）

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
├── docker-compose.yml          # ✨ v3.1 新增：本地 PostgreSQL 17 + pgvector
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
│   │   │   ├── login-page.tsx            # ✨ v3.1 帳密登入頁
│   │   │   └── change-password.tsx       # ✨ v3.1 首次強制改密
│   │   ├── admin/              # ✨ v3.1 新增：系統管理員後台
│   │   │   ├── users-page.tsx
│   │   │   ├── users-create.tsx
│   │   │   ├── users-edit.tsx
│   │   │   ├── compliance-rules-page.tsx
│   │   │   └── compliance-rules-import.tsx
│   │   ├── coach/              # Protected routes
│   │   │   ├── leads-page.tsx           # GET /leads
│   │   │   ├── lead-detail-page.tsx     # GET /leads/:id
│   │   │   ├── conversation/
│   │   │   │   ├── pre-briefing.tsx     # GET /leads/:id/conversation/pre
│   │   │   │   ├── in-session.tsx       # GET /leads/:id/conversation/in-session
│   │   │   │   └── post-followup.tsx    # GET /leads/:id/conversation/post
│   │   │   ├── customer-summary.tsx     # GET /leads/:id/summary/customer
│   │   │   └── reminders-page.tsx       # GET /reminders
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
│   │   ├── admin/              # ✨ v3.1 新增
│   │   │   ├── UserManagementTable.tsx
│   │   │   ├── UserForm.tsx
│   │   │   ├── ComplianceRuleForm.tsx
│   │   │   └── ComplianceRuleImportCSV.tsx
│   │   └── common/
│   │       ├── EmptyState.tsx
│   │       ├── ErrorBoundary.tsx
│   │       └── ProtectedRoute.tsx
│   ├── lib/
│   │   ├── api-client.ts               # Fetch wrapper（呼叫 apps/api）
│   │   ├── auth.ts                     # ✨ v3.1 改為帳密驗證（無 Supabase）
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

---

## `apps/api/` — FastAPI 後端 + 排程

```
apps/api/
├── src/
│   ├── main.py                     # FastAPI app + APScheduler 啟動
│   ├── core/
│   │   ├── config.py               # pydantic-settings
│   │   ├── auth.py                 # ✨ v3.1 改為 bcrypt + JWT 驗證（無 Supabase Auth）
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
│   │   │   ├── check_category.py
│   │   │   └── semantic_matcher.py  # ✨ v3.1 新增：pgvector 向量比對
│   │   └── onboarding/
│   │       └── onboarding_task.py
│   ├── application/                # Application Layer
│   │   ├── auth/                   # ✨ v3.1 新增：帳密登入 + 密碼管理
│   │   │   ├── password_auth_service.py
│   │   │   ├── password_hasher.py
│   │   │   └── jwt_manager.py
│   │   ├── admin/                  # ✨ v3.1 新增：系統管理員後台
│   │   │   ├── user_management_service.py
│   │   │   └── compliance_rule_management_service.py
│   │   ├── questionnaire_service.py
│   │   ├── briefing_service.py
│   │   ├── lead_service.py
│   │   ├── reminder_service.py
│   │   ├── compliance/
│   │   │   ├── compliance_service.py
│   │   │   ├── rule_engine.py
│   │   │   └── llm_reviewer.py
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
│   │   │   │   ├── auth.py                # ✨ v3.1 新增：帳密登入端點
│   │   │   │   ├── admin.py               # ✨ v3.1 新增：後台 CRUD 端點
│   │   │   │   ├── questionnaire.py       # /v1/questionnaires/*
│   │   │   │   ├── lead.py                # /v1/leads/*
│   │   │   │   ├── briefing.py            # /v1/leads/{id}/briefing
│   │   │   │   ├── reminder.py            # /v1/reminders/*
│   │   │   │   ├── compliance.py          # /v1/compliance/*
│   │   │   │   ├── leader.py              # /v1/leader/*
│   │   │   │   ├── webhooks.py            # ✨ v3.1 新增：WhatsApp webhook
│   │   │   │   └── internal.py            # /v1/internal/*
│   │   │   └── middleware/
│   │   │       ├── auth_middleware.py     # ✨ v3.1 改為 JWT（無 Supabase）
│   │   │       ├── rate_limit_middleware.py
│   │   │       └── logging_middleware.py
│   │   ├── db/                     # ✨ v3.1 改為本地 PostgreSQL + alembic
│   │   │   ├── sqlalchemy/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── session.py         # SQLAlchemy AsyncSession
│   │   │   │   └── models/
│   │   │   │       ├── user.py        # Users table（新）
│   │   │   │       ├── lead.py
│   │   │   │       ├── questionnaire.py
│   │   │   │       ├── compliance_rule.py  # ✨ v3.1 新增（取代 YAML）
│   │   │   │       └── audit_log.py   # ✨ v3.1 新增
│   │   │   └── migrations/
│   │   │       └── alembic/            # ✨ v3.1 新增：SQLAlchemy migration tool
│   │   │           ├── env.py
│   │   │           ├── alembic.ini
│   │   │           └── versions/
│   │   │               ├── 20260508_10_pgvector_extension.sql
│   │   │               ├── 20260508_11_compliance_rules.sql
│   │   │               ├── 20260508_12_users_password_auth.sql
│   │   │               └── 20260508_13_admin_audit_log.sql
│   │   ├── llm/
│   │   │   └── adapter.py               # 繫結 packages/llm
│   │   ├── notifications/
│   │   │   ├── channel.py               # 基類（改為多通道支援）
│   │   │   ├── line_channel.py          # LINE Messaging API（主）
│   │   │   ├── whatsapp_channel.py      # ✨ v3.1 新增：WhatsApp Business API
│   │   │   └── email_channel.py         # Resend（備援）
│   │   ├── google_calendar/
│   │   │   ├── oauth_client.py
│   │   │   └── calendar_adapter.py
│   │   └── scheduler/
│   │       ├── reminder_scheduler.py    # APScheduler jobs
│   │       └── materialized_view_refresh.py
│   └── rules/                      # ⚠️ v3.1 迴圈：YAML 已廢棄，改用 DB compliance_rules
│       ├── questionnaire-v1.yaml
│       └── onboarding-tasks.yaml
├── tests/
│   ├── conftest.py                 # 全域 fixtures
│   ├── unit/
│   │   ├── domain/
│   │   │   ├── test_scoring_engine.py
│   │   │   ├── test_lead_status_machine.py
│   │   │   └── test_semantic_matcher.py  # ✨ v3.1 新增
│   │   └── application/
│   │       ├── test_briefing_service.py
│   │       ├── test_reminder_service.py
│   │       ├── test_compliance_service.py
│   │       ├── test_password_auth_service.py  # ✨ v3.1 新增
│   │       └── test_user_management_service.py  # ✨ v3.1 新增
│   ├── integration/
│   │   ├── test_questionnaire_flow.py
│   │   ├── test_reminder_scheduler.py
│   │   ├── test_compliance_flow.py
│   │   ├── test_auth_flow.py  # ✨ v3.1 新增
│   │   └── test_whatsapp_webhook.py  # ✨ v3.1 新增
│   └── features/                   # pytest-bdd
│       ├── questionnaire.feature
│       ├── briefing.feature
│       ├── crm.feature
│       ├── reminder.feature
│       ├── compliance.feature
│       ├── auth.feature  # ✨ v3.1 新增
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
│   │   ├── auth.ts  # ✨ v3.1 新增
│   │   ├── user.ts  # ✨ v3.1 新增
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
│   │       ├── onboarding.py
│   │       ├── auth.py  # ✨ v3.1 新增
│   │       ├── user.py  # ✨ v3.1 新增
│   │       └── schemas.py  # ✨ v3.1 新增：SemanticMatcher 輸入輸出
│   └── pyproject.toml              # name: synergy-domain
└── schemas/                        # JSON Schema 單一真相來源
    ├── lead.json
    ├── briefing.json
    ├── questionnaire.json
    ├── compliance.json
    ├── auth.json  # ✨ v3.1 新增
    └── user.json  # ✨ v3.1 新增
```

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

---

## `docs/` — 專案文檔

```
docs/
├── INDEX.md                        # 文檔索引
├── 01_prd.md
├── 02_bdd.md
├── 03_adr.md                       # 含 ADR-001 ~ ADR-018（v3.1 新增）
├── 04_architecture.md
├── 05_api.md
├── 06_modules.md
├── 07_structure.md                 # 本檔
├── 08_design_dependencies.md
├── 09_frontend_ia.md
├── 10_security.md
├── 11_deployment.md
├── 12_phase1_mvp.md
├── 13_client_deliverables.md
├── 14_team_workplan.md
├── adr/                            # 未來拆分後的獨立 ADR
│   └── README.md
└── diagrams/                       # Mermaid / PlantUML 原始檔
```

---

## `scripts/` — 開發/維運腳本

```
scripts/
├── seed-dev-data.py                # 建立測試資料
├── migrate.sh                      # ✨ v3.1 改為 alembic migration 統一入口
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

---

## ✨ v3.1 補丁（2026-05-08）

### ADR-003/015/016/017/018：架構翻轉

**五大變更**：

#### 1. DB：Supabase → 本地 PostgreSQL + GCP Cloud SQL（ADR-003 翻轉）

- **本地開發**：`docker-compose.yml` 啟動 `postgres:17` + `pgvector` image
  - 預設 `postgresql://synergy:synergy@localhost:5432/synergy`
  - 包含 pgvector extension 與 Healthcheck
- **GCP 部署**：Cloud SQL（PostgreSQL 17 + pgvector 支援）
- **Migration**：`alembic` 取代 Supabase migration
  - 版本檔：`apps/api/src/infrastructure/db/migrations/alembic/versions/`
  - 執行：`alembic upgrade head`

#### 2. 認證：Magic Link → 帳密 + Admin 後台建用戶（ADR-015 新增）

- **PasswordAuthService**（新）：`apps/api/src/application/auth/`
  - `login(email, password)` → JWT核發
  - `change_password(user_id, old, new)` → 密碼策略檢查（≥10字、數字+字母）
  - `get_current_coach()` → JWT驗證（Depends）
  - 暴力破解防護：失敗5次鎖15min
  - 首次登入強制改密：`must_change_password = true`
  
- **UserManagementService**（新）：`apps/api/src/application/admin/`
  - Admin CRUD教練帳號、重設密碼
  - 所有操作寫`admin_audit_logs`表
  
- **前端**：
  - `/login` — 帳密表單（email + password，無 Supabase Magic Link）
  - `/auth/change-password` — 首次強制改密
  - `/admin/users`、`/admin/users/new`、`/admin/users/:id/edit` — Admin UI

#### 3. 通道：LINE → LINE/WhatsApp/Email 三層 Fallback（ADR-016 新增）

- **WhatsAppChannel**（新）：`apps/api/src/infrastructure/notifications/whatsapp_channel.py`
  - Webhook：`POST /webhooks/whatsapp` 接收 Meta 回呼
  - 環境變數：
    - `WHATSAPP_ACCESS_TOKEN`
    - `WHATSAPP_PHONE_NUMBER_ID`
    - `WHATSAPP_VERIFY_TOKEN`
    - `WHATSAPP_BUSINESS_ACCOUNT_ID`（可選）
  - Fallback 順序：LINE → WhatsApp → Email
  
- **Frontend**：
  - F1.3 私訊開場草稿改支援 WhatsApp 格式

#### 4. 規則庫：YAML → DB + pgvector 向量語意比對（ADR-017 新增）

- **ComplianceRuleService**（新）：`apps/api/src/application/admin/`
  - CRUD：`GET/POST/PATCH/DELETE /admin/compliance-rules`
  - CSV 批量匯入：`POST /admin/compliance-rules/import`
  - 重算 embedding：`POST /admin/compliance-rules/regenerate-embeddings`
  
- **SemanticMatcher**（新 Domain）：`apps/api/src/domain/compliance/semantic_matcher.py`
  - 純函式：計算 cosine similarity > 閾值（預設 0.85）
  - 支援多規則併行匹配
  
- **DB**：`compliance_rules` 表（新）
  - 欄位：id, tenant_id, category, phrase, severity, suggested_rewrite, embedding(vector 768), enabled, created_by, updated_by, created_at, updated_at
  - IVFFlat/HNSW 索引
  
- **Frontend**：
  - `/admin/compliance-rules` — 規則列表 CRUD
  - `/admin/compliance-rules/import` — CSV 匯入 UI

#### 5. 部署：Cloudflare/Railway → GCP（ADR-018 新增）

- **拓撲**：Cloud DNS → Cloud CDN → (Cloud Storage FE + Cloud Run BE) → Cloud SQL
- **環境變數**：
  - `GCP_PROJECT_ID`
  - `GCP_REGION`（預設 `asia-east1`）
  - `SECRET_MANAGER_PREFIX`（如 `synergy-`）
- **檔案**：
  - `Dockerfile`（apps/api 與 apps/web multi-stage）
  - `cloudbuild.yaml` — CI/CD 定義
  - `docker-compose.yml`（本地 dev）

### DB 表結構補充（v3.1）

**新欄位（users 表）**：
- `password_hash: TEXT`（bcrypt cost=12）
- `must_change_password: BOOLEAN DEFAULT true`
- `failed_login_count: INT DEFAULT 0`
- `locked_until: TIMESTAMPTZ NULL`

**新表**：
- `compliance_rules` — 規則庫
- `admin_audit_logs` — Admin 操作稽核

### 環境變數補充（v3.1）

```bash
# apps/api/.env（本地開發）
DATABASE_URL=postgresql+asyncpg://synergy:synergy@localhost:5432/synergy
WHATSAPP_ACCESS_TOKEN=xxx
WHATSAPP_PHONE_NUMBER_ID=xxx
WHATSAPP_VERIFY_TOKEN=xxx
EMBEDDING_MODEL=models/embedding-001
SEMANTIC_SIMILARITY_THRESHOLD=0.85
BCRYPT_COST=12
PASSWORD_MIN_LENGTH=10
GCP_PROJECT_ID=synergy-dev
SECRET_MANAGER_PREFIX=synergy-

# 部署環境（GCP Cloud Run Secret Manager）
# 同上，由 Cloud Run 注入
```

### 檔案新增清單

- `docker-compose.yml` — 本地 PostgreSQL 17
- `apps/api/src/core/auth.py` — 重寫為 bcrypt + JWT（非 Supabase）
- `apps/api/src/application/auth/` — PasswordAuthService + 相關模組
- `apps/api/src/application/admin/` — UserManagementService + ComplianceRuleService
- `apps/api/src/infrastructure/db/sqlalchemy/` — SQLAlchemy 配置
- `apps/api/src/infrastructure/db/migrations/alembic/` — 遷移管理
- `apps/api/src/infrastructure/notifications/whatsapp_channel.py` — WhatsApp 整合
- `apps/api/src/domain/compliance/semantic_matcher.py` — 向量語意比對
- `apps/web/src/routes/auth/login-page.tsx` 與 `change-password.tsx`
- `apps/web/src/routes/admin/users*.tsx` 與 `compliance-rules*.tsx`
- `Dockerfile`（後端與前端）
- `cloudbuild.yaml` — GCP 部署

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v3.0 | 2026-05-08 | 初版，React 19 + Vite + FastAPI |
| **v3.1** | **2026-05-08** | **⚠️ 五項架構翻轉：DB（Supabase → PostgreSQL + GCP）、認證（Magic Link → bcrypt + Admin 後台）、通知（+ WhatsApp）、規則庫（YAML → DB + pgvector）、部署（GCP）；新增 PasswordAuthService、UserManagementService、WhatsAppChannel、SemanticMatcher** |
