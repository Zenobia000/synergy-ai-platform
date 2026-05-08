# 部署與維運指南 — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08 | **對應架構：** `docs/04_architecture.md §5` | **對應決策：** ADR-013/015/016/017/018
> **⚠️ 修訂歷程**：v3.0 Cloudflare/Railway/Supabase → v3.0.1 教練即審核者（無 reviewer 工時）→ **v3.1 翻轉至 GCP + 本地 PostgreSQL + bcrypt 帳密 + WhatsApp + pgvector**（見文末 v3.0.1 與 v3.1 補丁段）

---

## 1. 部署拓撲

```mermaid
graph TB
    Users[使用者]
    CF[Cloudflare CDN/Pages]
    Railway[Railway<br/>apps/api<br/>FastAPI + APScheduler]
    Supabase[(Supabase Cloud<br/>PostgreSQL + Auth)]
    Gemini[Gemini API]
    Resend[Resend API]
    LineAPI[LINE Messaging API]
    GoogleCal[Google Calendar API]

    Users -->|HTTPS| CF
    CF -->|靜態 HTML/JS/CSS<br/>+ API 轉發| Railway
    Railway -->|Postgres protocol| Supabase
    Railway -->|HTTPS| Gemini
    Railway -->|HTTPS| Resend
    Railway -->|HTTPS| LineAPI
    Railway -->|HTTPS| GoogleCal
    Sentry[Sentry] -.監控.-> Railway

    classDef frontend fill:#e1f5ff
    classDef backend fill:#f3e5f5
    classDef data fill:#e8f5e9
    classDef external fill:#fff3e0

    class CF frontend
    class Railway backend
    class Supabase data
    class Gemini,Resend,LineAPI,GoogleCal external
```

**v3.0 變更（ADR-013）**：
- Vercel（Next.js 專優化） → **Cloudflare Pages**（Vite 純靜態）
- 原因：無 SSR 需求、Vite 產出 static 最佳化、Cloudflare Pages 成本低且 CDN 最快

---

## 2. 環境矩陣

| 環境 | 用途 | Frontend URL | Backend URL | 資料 | 部署觸發 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **local** | 開發 | localhost:5173（Vite） | localhost:8000 | Supabase local 或 staging | `pnpm dev` + `uv run uvicorn` |
| **staging** | 內部驗證 | staging.synergy-ai.tw | api-staging.synergy-ai.tw | Supabase staging project | push to `main` |
| **production** | Pilot 教練 | app.synergy-ai.tw | api.synergy-ai.tw | Supabase Pro | Git tag `v*.*.*` |

---

## 3. CI/CD Pipeline

### 3.1 Local 開發（Vite）

**啟動前端開發伺服器**：
```bash
cd apps/web
pnpm install  # 或 npm install / bun install，依 .claude/taskmaster-data/package-manager.json
pnpm dev      # Vite dev server 監聽 localhost:5173
```

**啟動後端開發伺服器**：
```bash
cd apps/api
uv sync       # 初次或更新依賴
uv run uvicorn src.main:app --reload --port 8000
```

**環境檔**（`.env.local`）：
```bash
# apps/web/.env.local
VITE_API_BASE_URL=http://localhost:8000
VITE_SUPABASE_URL=https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJxx...

# apps/api/.env
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_KEY=eyJxx...（service role）
LLM_API_KEY=sk-xxxx（Gemini）
LINE_CHANNEL_ACCESS_TOKEN=xxxx
RESEND_API_KEY=xxxx
GOOGLE_CALENDAR_CLIENT_ID=xxxx
SENTRY_DSN=xxxx（可選）
```

### 3.2 PR 檢查流程（`.github/workflows/pr.yml`）

```yaml
name: PR Checks
on: pull_request

jobs:
  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v1  # 或 pnpm/action-setup，依 PM 設定
      - run: bun install --frozen-lockfile  # 對應 PM
      - run: bun run --cwd apps/web lint
      - run: bun run --cwd apps/web typecheck
      - run: bun run --cwd apps/web test
      - run: bun run --cwd apps/web build

  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
      - run: uv sync --directory apps/api
      - run: uv run --directory apps/api ruff check
      - run: uv run --directory apps/api mypy src
      - run: uv run --directory apps/api pytest --cov --cov-fail-under=80

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: gitleaks/gitleaks-action@v2
      - run: bun audit  # 對應 PM
      - run: uv run --directory apps/api pip-audit
```

### 3.3 Merge to main（Staging 部署）

**Staging 環境自動部署到** `staging.synergy-ai.tw`：

1. **前端（Cloudflare Pages for Staging）**：
   - 設定 Cloudflare Pages project 監聽 `main` branch
   - Build 指令：`cd apps/web && pnpm build`（對應 PM）
   - Output directory：`apps/web/dist`
   - 環境變數：
     ```
     VITE_API_BASE_URL=https://api-staging.synergy-ai.tw
     VITE_SUPABASE_URL=https://xxxx.supabase.co
     VITE_SUPABASE_ANON_KEY=<Secret>
     ```

2. **後端（Railway Staging）**：
   - Railway project 監聽 `apps/api` 路徑變更
   - 自動部署到 staging service
   - 環境變數在 Railway dashboard 設定（所有 `SUPABASE_*`、`LLM_API_KEY` 等）

3. **資料庫遷移（手動）**：
   ```bash
   ./scripts/migrate.sh staging
   # 或手動在 Supabase dashboard 執行 SQL
   ```

### 3.4 Tag v* → Production（`.github/workflows/deploy-prod.yml`）

```yaml
name: Production Deploy
on:
  push:
    tags: ['v*.*.*']

jobs:
  deploy-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Cloudflare Pages
        run: |
          cd apps/web
          bun install --frozen-lockfile
          bun run build
          # 使用 wrangler CLI 部署到 Cloudflare Pages（需 API token）
          npx wrangler pages deploy dist \
            --project-name=synergy-web \
            --branch=main

  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Railway Production
        run: |
          # Railway CLI 部署
          railway up \
            --service apps/api \
            --environment production

  migrate-db:
    needs: deploy-backend
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run migrations
        run: ./scripts/migrate.sh production
        env:
          SUPABASE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
```

---

## 4. 部署平台詳述

### 4.1 Cloudflare Pages（前端 — v3.0 新增）

**為什麼選 Cloudflare Pages（ADR-013）**：
- Vite 產出純靜態檔案 → Pages 秒級部署
- CDN 全球加速，延遲最低
- Pricing：月費 0 NTD（無商用限制）
- API 轉發至後端（ `/api/*` proxy 到 Railway）

**設定步驟**：
1. 連結 GitHub repo（Cloudflare → Pages → Connect Git）
2. 選擇 `main` branch
3. Build 設定：
   - Framework：自訂
   - Build command：`cd apps/web && bun run build`
   - Build output directory：`apps/web/dist`
   - Root directory：`/`（不用改）
4. 環境變數設定在 Pages 設定面板
5. 自訂域名指向 Cloudflare Pages（DNS）

**自訂域名（DNS）**：
```
app.synergy-ai.tw  CNAME → synergy-web.pages.dev
```

**API 轉發設定**（`wrangler.toml` 在 Cloudflare Pages 側）：
```toml
# 內部設定，或使用 Cloudflare Workers 作 proxy
routes = [
  { pattern = "app.synergy-ai.tw/api/*", zone_name = "synergy-ai.tw" }
]
```

或用 Cloudflare Workers 轉發（更簡單）：
```javascript
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) {
      url.hostname = 'api.synergy-ai.tw';  // 後端 Railway
      return fetch(new Request(url, request));
    }
    // 其他請求走 Pages
    return fetch(request);
  }
};
```

### 4.2 Railway（後端）

**FastAPI + APScheduler 部署**：

1. 連結 GitHub repo（Railway dashboard）
2. 選擇 `apps/api` 目錄作為 root
3. Railway 自動偵測 `pyproject.toml`，設定為 Python project
4. 啟動指令：`uvicorn src.main:app --host 0.0.0.0 --port $PORT`
   - Railway 提供 `$PORT` 環境變數
5. 環境變數：設定所有 `SUPABASE_*`、`LLM_API_KEY` 等
6. PostgreSQL 可選（用 Supabase，不需要 Railway DB）

**域名**：
```
api.synergy-ai.tw  CNAME → xxx.railway.app
```

或用 Railway 內置域名：`api-prod.up.railway.app`

### 4.3 Supabase（資料庫 + Auth）

**現有設定保持不變**（ADR-003）：
- Free tier 或 Pro tier
- PostgreSQL + pgvector + Auth
- RLS policy（已寫好，MVP 不啟用）

**環境變數（後端）**：
```bash
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_KEY=eyJ... (service role key)
```

**環境變數（前端）**：
```bash
VITE_SUPABASE_URL=https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ... (anon key)
```

---

## 5. 環境變數清單（v3.0 Vite 更新）

### 前端（`apps/web`）

| 變數名 | 值範例 | 用途 | 環境 |
| :--- | :--- | :--- | :--- |
| `VITE_API_BASE_URL` | http://localhost:8000 | 後端 API 位置 | all |
| `VITE_SUPABASE_URL` | https://xxxx.supabase.co | Supabase 專案 URL | all |
| `VITE_SUPABASE_ANON_KEY` | eyJ... | Supabase anon key（Secret） | all |
| `VITE_COMPLIANCE_MAX_RETRIES` | 3 | 合規檢查重試次數 | all |

### 後端（`apps/api`）

| 變數名 | 值範例 | 用途 | 環境 |
| :--- | :--- | :--- | :--- |
| `SUPABASE_URL` | https://xxxx.supabase.co | Supabase 專案 URL | all |
| `SUPABASE_KEY` | eyJ... | Supabase service role key（Secret） | all |
| `LLM_API_KEY` | sk-... | Gemini API key（Secret） | all |
| `LINE_CHANNEL_ACCESS_TOKEN` | U+xxxx | LINE OA token（Secret） | all |
| `RESEND_API_KEY` | re_xxxx | Resend API key（Secret） | all |
| `GOOGLE_CALENDAR_CLIENT_ID` | xxxx.apps.googleusercontent.com | OAuth client ID | all |
| `GOOGLE_CALENDAR_CLIENT_SECRET` | xxxx | OAuth secret（Secret） | all |
| `SENTRY_DSN` | https://xxxx@xxxx.ingest.sentry.io/yyyy | 錯誤追蹤（可選） | staging / prod |
| `ENVIRONMENT` | development / staging / production | 執行環境標識 | all |
| `LOG_LEVEL` | DEBUG / INFO / WARNING | 日誌等級 | all |

---

## 6. 監控與告警

### 6.1 Sentry（錯誤追蹤）

**後端集成**：
```python
import sentry_sdk
sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    environment=os.getenv("ENVIRONMENT"),
    traces_sample_rate=0.1
)
```

**前端集成**（react-sentry）：
```tsx
import * as Sentry from "@sentry/react";
Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  tracesSampleRate: 0.1
});
```

### 6.2 重要指標監控

| 指標 | 目標 | 監控位置 |
| :--- | :--- | :--- |
| `compliance_check_p95_latency` | ≤ 5s | APScheduler / Sentry |
| `hitl_queue_depth` | ≤ 10 items | API endpoint + dashboard |
| `auto_pass_rate` | > 80% | ComplianceLog 統計 |
| `api_error_rate` | < 1% | Sentry / Railway metrics |
| `db_connection_pool` | ≥ 5 available | Supabase monitoring |

### 6.3 告警規則

- API error rate > 5% → 30 min 內告警
- Compliance latency p95 > 5s → 1 hour 內改善
- Database storage > 80% quota → 立即告警

---

## 7. 回滾策略

### 前端回滾（Cloudflare Pages）

1. 在 Cloudflare Pages 設定面板選擇「Deployments」
2. 選擇之前的正常版本，點「Rollback」
3. 自動 rollback 至該 commit

### 後端回滾（Railway）

1. 在 Railway dashboard 點「Deployments」
2. 選擇之前的正常版本，點「Redeploy」

### 資料庫回滾（Supabase）

1. 檢查 migration 歷史（`src/infrastructure/db/migrations/`）
2. 確認回滾 SQL（已附加 `-- ROLLBACK:` 註解）
3. 在 Supabase SQL editor 手動執行或用 CLI：
   ```bash
   supabase migration down
   ```

---

## 8. 維運檢查清單

### 部署前（Release 前）

- [ ] Staging 環境完全測試通過
- [ ] 所有 migration 檔已編寫並在 staging 測試
- [ ] 環境變數已在 prod 設定（不含默認值）
- [ ] Sentry project 已建立
- [ ] LINE OA 帳號已審核通過（若需要）
- [ ] Google Calendar OAuth 已授權
- [ ] 資料庫備份已排程（Supabase 自動，檢查確認）

### 部署後（Release 後）

- [ ] 前端 static files 已在 CDN 快取（Cloudflare）
- [ ] 後端服務正常啟動（Railway）
- [ ] Database migrations 已執行
- [ ] SEO meta tags 可正確渲染（react-helmet）
- [ ] LINE 提醒、Email、Google Calendar 整合可用
- [ ] 完整端到端流程（問卷 → 摘要 → 提醒 → HITL 審核）

### 每週維運檢查

- [ ] 監控儀表板無告警
- [ ] Sentry 錯誤率 < 1%
- [ ] 合規檢查 latency p95 < 5s
- [ ] HITL 隊列深度 < 10
- [ ] 資料庫存儲 < 80% quota
- [ ] 教練反饋無重大 BUG 回報

---

## 9. Scaling 規劃（Phase 2）

### 前端 Scaling

- Vite 產出靜態檔案 → 無狀態，Cloudflare CDN 原生支援
- 預期支援 10,000+ 併發用戶無問題

### 後端 Scaling

1. **單機 APScheduler → Celery（Redis）**（若 reminder 量 > 1,000/hr）
2. **FastAPI 單機 → Railway auto-scaling**（可配置 max instances）
3. **資料庫 → Supabase Pro tier + read replicas**（若 QPS > 100）

### 部署調整

- 前端：無變（Cloudflare CDN 自動）
- 後端：Railway 設定 auto-scaling rules
- DB：Supabase 升級 tier（成本線性）

---

## 10. 安全設定（Deployment 層）

- [ ] HTTPS everywhere（Cloudflare / Railway 原生）
- [ ] 環境變數絕不簽入 git（`.env` 在 `.gitignore`）
- [ ] Supabase RLS policy 預留但未啟用（Phase 2）
- [ ] API rate limiting 已設（每 IP 100 req/min）
- [ ] CORS 已限制（只允許 `https://app.synergy-ai.tw`）
- [ ] Database backup 每日自動（Supabase 內置）

---

## v3.0 部署變更總結（ADR-013）

| 項目 | v2.0（Next.js） | v3.0（React+Vite） |
| :--- | :--- | :--- |
| **部署平台** | Vercel | Cloudflare Pages |
| **Build 指令** | `next build` | `vite build` |
| **輸出格式** | SSR 伺服器 | 純靜態 HTML/JS/CSS |
| **Node.js 需求** | 運行時必需 | 建置時只需 |
| **啟動時間** | ~3-5s | <1s（無 build） |
| **環境變數** | `NEXT_PUBLIC_*` | `VITE_*` |
| **SEO 處理** | next/head | react-helmet-async |
| **Auth Middleware** | middleware.ts | ProtectedRoute HOC |
| **成本** | $15-25/月（Vercel） | $0/月 + Railway $5/月 |

---

## v3.0.1 補丁（2026-05-08，教練即審核者）

對應 [03_adr.md ADR-011 v3.0.1 修訂](./03_adr.md)、[12_phase1_mvp.md F5.4](./12_phase1_mvp.md)。

### v3.0.1 變更摘要

- HITL 從「外部 Reviewer + 30 min SLA + 佇列」**簡化**為「教練本人 UI 內審核」
- 移除：reviewer DB role、hitl_items 表、queue worker、escalation email、`/compliance/queue` 獨立頁
- 新增：`message_drafts` 表（draft pattern）、品質閥值重生成（最多 3 次）
- 月成本下降約 50%（無 Reviewer 人力）

### v3.0.1 Migration（已建檔）

| Step | 檔案 | 用途 |
| :--- | :--- | :--- |
| 09 | `20260508_09_message_drafts.sql` | 草稿表 + RLS（coach 只看自己） |

### v3.0.1 Cron Jobs / Worker 變更

| 任務 | v3.0 | v3.0.1 |
| :--- | :--- | :--- |
| HITL SLA 檢查 worker | 每 1 min | ❌ 移除 |
| HITL 超時 escalation email | 每 5 min | ❌ 移除 |
| 物化視圖 refresh | 每 30 min | ✅ 保留 |

> **註**：v3.0.1 Magic Link 與 Resend Email DNS 設定相關內容已被 v3.1 翻轉，請以下方 v3.1 補丁段為準。

---

## ✨ v3.1 補丁（2026-05-08，五大架構翻轉）

對應 [03_adr.md ADR-015/016/017/018](./03_adr.md)、[12_phase1_mvp.md](./12_phase1_mvp.md)、所有 v3.1 修訂的 docs 文件。

### A. 五大變更總覽

| # | 變更 | 對應 ADR |
| :---: | :--- | :--- |
| 1 | DB：Supabase Cloud → 本地 docker-compose PostgreSQL 17 + pgvector | ADR-003 翻轉 |
| 2 | 認證：Magic Link → admin 後台手動建用戶 + bcrypt 帳密登入 | ADR-014 廢棄、ADR-015 採用 |
| 3 | 通道：新增 WhatsApp（LINE → WhatsApp → Email fallback）| ADR-016 |
| 4 | 規則庫：YAML → DB `compliance_rules` + pgvector 向量近似 | ADR-017 |
| 5 | 部署：Cloudflare/Railway → **GCP**（Cloud Run + Cloud SQL + Cloud CDN）| ADR-013 修訂、ADR-018 |

### B. v3.1 部署拓撲（GCP）

```mermaid
graph TB
    Users[使用者]
    DNS[Cloud DNS]
    LB[Cloud Load Balancer<br/>+ Cloud CDN]
    Static[Cloud Storage<br/>前端靜態檔]
    CloudRun[Cloud Run<br/>FastAPI + APScheduler]
    SQL[(Cloud SQL<br/>PostgreSQL 17 + pgvector)]
    SecretMgr[Secret Manager]
    AR[Artifact Registry<br/>Docker images]
    Scheduler[Cloud Scheduler]
    Logging[Cloud Logging<br/>+ Monitoring]

    Gemini[Gemini API]
    LineAPI[LINE Messaging API]
    WhatsAppAPI[WhatsApp Business API]
    Resend[Resend API]
    GoogleCal[Google Calendar API]

    Users -->|HTTPS| DNS --> LB
    LB -->|靜態| Static
    LB -->|/api/*| CloudRun
    CloudRun -->|SSL/Cloud SQL Auth Proxy| SQL
    CloudRun --> SecretMgr
    CloudRun -.image.- AR
    Scheduler -->|trigger| CloudRun
    CloudRun --> Gemini
    CloudRun --> LineAPI
    CloudRun --> WhatsAppAPI
    CloudRun --> Resend
    CloudRun --> GoogleCal
    Logging -.收集.-> CloudRun
```

### C. GCP 資源清單

| 資源 | 規格 | 估月費（NTD）|
| :--- | :--- | ---: |
| Cloud Run（API service） | 1 vCPU / 512MB / min-instances=0 / max=2 | 500 |
| Cloud SQL for PostgreSQL | db-f1-micro / 10GB SSD / asia-east1 | 250 |
| Cloud Storage（前端 bucket）| Standard / 1GB | 5 |
| Cloud CDN | 1 LB + 10GB egress | 200 |
| Artifact Registry | Docker repo / 5GB | 50 |
| Secret Manager | < 50 secrets | 10 |
| Cloud Scheduler | 5 jobs | 0（免費 tier）|
| Cloud Logging / Monitoring | 5GB log/月 | 0（免費 tier）|
| Cloud DNS | 1 zone | 50 |
| **GCP 小計** | | **~1,065** |
| 外部：Gemini Flash + Pro | | 650 |
| 外部：LINE / WhatsApp / Resend | | 1,200 |
| **總計（v3.1）** | | **~2,915** |

vs v3.0.1 ~4,150 NTD/月 → **v3.1 -30%**

### D. 本地開發環境（docker-compose）

根目錄新增 `docker-compose.yml`：

```yaml
version: "3.9"

services:
  postgres:
    image: pgvector/pgvector:pg17
    environment:
      POSTGRES_USER: synergy
      POSTGRES_PASSWORD: synergy_dev
      POSTGRES_DB: synergy
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./apps/api/infrastructure/db/migrations:/migrations:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synergy -d synergy"]
      interval: 5s
      timeout: 3s
      retries: 10

  api:
    build:
      context: ./apps/api
      dockerfile: Dockerfile.dev
    environment:
      DATABASE_URL: postgresql+asyncpg://synergy:synergy_dev@postgres:5432/synergy
      JWT_SECRET: dev-secret-do-not-use-in-prod
      BCRYPT_COST: "10"           # dev 用低 cost 加速
      LLM_API_KEY: ${LLM_API_KEY}
      EMBEDDING_MODEL: models/embedding-001
      SEMANTIC_SIMILARITY_THRESHOLD: "0.85"
      WHATSAPP_ACCESS_TOKEN: ${WHATSAPP_ACCESS_TOKEN:-}
      WHATSAPP_PHONE_NUMBER_ID: ${WHATSAPP_PHONE_NUMBER_ID:-}
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./apps/api:/app

volumes:
  pgdata:
```

啟動：
```bash
docker-compose up -d postgres
docker-compose exec postgres psql -U synergy -d synergy -f /migrations/20260508_10_pgvector_extension.sql
# 或：alembic upgrade head（推薦）
docker-compose up api
# 終端 2：cd apps/web && pnpm dev
```

### E. 新增環境變數（v3.1）

```bash
# 資料庫（取代 SUPABASE_*）
DATABASE_URL=postgresql+asyncpg://synergy:<pass>@<host>:5432/synergy
DATABASE_POOL_SIZE=10

# 認證（ADR-015，取代 Magic Link）
JWT_SECRET=                          # 至少 32 字元，從 Secret Manager 注入
JWT_ACCESS_TOKEN_TTL_HOURS=1
JWT_REFRESH_TOKEN_TTL_DAYS=7
BCRYPT_COST=12
PASSWORD_MIN_LENGTH=10
AUTH_FAILED_ATTEMPTS_LOCK_THRESHOLD=5
AUTH_LOCK_DURATION_MINUTES=15

# WhatsApp（ADR-016）
WHATSAPP_ACCESS_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_BUSINESS_ACCOUNT_ID=
WHATSAPP_VERIFY_TOKEN=               # webhook 驗證用，自訂任意字串
WHATSAPP_APP_SECRET=                 # 用於 X-Hub-Signature-256 HMAC 驗證

# 規則庫向量（ADR-017）
EMBEDDING_MODEL=models/embedding-001
SEMANTIC_SIMILARITY_THRESHOLD=0.85
COMPLIANCE_QUALITY_THRESHOLD=0.7
COMPLIANCE_MAX_REGENERATE=3

# GCP（ADR-018）
GCP_PROJECT_ID=
GCP_REGION=asia-east1
SECRET_MANAGER_PREFIX=synergy-
ARTIFACT_REGISTRY_REPO=asia-east1-docker.pkg.dev/<project>/synergy
```

**已淘汰**（v3.0.1 → v3.1 移除）：
- ~~`SUPABASE_URL` / `SUPABASE_KEY` / `VITE_SUPABASE_*`~~
- ~~`MAGIC_LINK_TTL_MINUTES`~~

### F. CI/CD：GitHub Actions + gcloud

`.github/workflows/deploy-gcp.yml`：

```yaml
name: Deploy to GCP

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  GCP_REGION: asia-east1

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4

      # GCP 認證（用 Workload Identity Federation，不要 service account key）
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@v2

      # === 後端 ===
      - name: Build & push Docker image
        run: |
          gcloud auth configure-docker $GCP_REGION-docker.pkg.dev
          docker build -t $GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/synergy/api:${{ github.sha }} apps/api
          docker push $GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/synergy/api:${{ github.sha }}

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy synergy-api \
            --image $GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/synergy/api:${{ github.sha }} \
            --region $GCP_REGION \
            --platform managed \
            --add-cloudsql-instances $GCP_PROJECT_ID:$GCP_REGION:synergy-db \
            --set-secrets=JWT_SECRET=jwt-secret:latest,DATABASE_URL=db-url:latest \
            --max-instances 2 \
            --min-instances 0

      # === 前端 ===
      - uses: oven-sh/setup-bun@v1
      - name: Build frontend
        run: |
          cd apps/web && bun install --frozen-lockfile && bun run build
        env:
          VITE_API_BASE_URL: https://api.synergy-ai.tw

      - name: Deploy frontend to Cloud Storage
        run: |
          gsutil -m rsync -d -r apps/web/dist gs://synergy-web-$GCP_PROJECT_ID

      # === Migration ===
      - name: Run alembic migration
        run: |
          gcloud sql connect synergy-db --user=synergy --quiet < /dev/null
          # 或透過 Cloud Run Job 跑 alembic upgrade head
```

### G. 上線 Checklist 補充（v3.1）

**移除**（已過時）：
- ~~Cloudflare Pages 設定~~
- ~~Railway 部署~~
- ~~Supabase Cloud 專案~~
- ~~Magic Link 寄送驗證~~

**新增**：
- [ ] GCP project + billing 設定（Q-013 客戶交付）
- [ ] Cloud SQL instance（asia-east1, db-f1-micro, pgvector enabled）
- [ ] Cloud SQL Auth Proxy 連線測試
- [ ] Secret Manager 寫入：JWT_SECRET、DATABASE_URL、LLM_API_KEY、WHATSAPP_*
- [ ] Workload Identity Federation 設定（GitHub Actions OIDC）
- [ ] Artifact Registry repo 建立
- [ ] alembic 全 13 個 migration 跑過 staging 驗證
- [ ] pgvector extension 在 Cloud SQL 啟用驗證
- [ ] 1-2 個 admin 帳號 seed（密碼用安全管道交付）
- [ ] WhatsApp Business 帳號審核通過 + Phone Number ID 取得
- [ ] WhatsApp webhook URL 設定（HTTPS）+ verify_token + HMAC 驗證
- [ ] LINE OA 審核通過（v3.0 既有）
- [ ] Resend Email 寄件網域 SPF/DKIM/DMARC 通過（用於 M4 提醒）
- [ ] 教練 onboarding：admin 建帳號 → 教練收 email 含初始密碼 → 首次登入強制改密
- [ ] 規則庫 C1-C4 CSV 匯入 + embedding 計算
- [ ] 三通道 fallback 端到端測試（LINE 失敗 → WhatsApp → Email）

### H. Runbook 新增（v3.1）

| 情境 | 處理 |
| :--- | :--- |
| Cloud SQL 連線失敗 | 檢查 Cloud SQL Auth Proxy、IAM 權限、實例狀態；fallback 切 read-replica |
| pgvector 索引退化（query 變慢）| `REINDEX INDEX idx_compliance_rules_embedding;` 或 VACUUM ANALYZE |
| Embedding 計算超量 | 暫停自動重算，分批處理；檢查 Gemini API quota |
| Admin 帳號被鎖（5 次失敗） | 另一個 admin 在 `/admin/users/:id/unlock` 解鎖；無 admin 時用 SQL 直接更新 `locked_until=NULL` |
| WhatsApp webhook 不通 | 檢查 Meta Business 設定、verify_token、HTTPS 憑證；fallback 走 Email |
| GCP billing 超預算 | 檢查 Cloud Run min-instances（應為 0）、Cloud SQL tier、Cloud CDN egress；設定 budget alert |

