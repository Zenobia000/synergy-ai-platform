# 架構與設計文件 — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08 | **狀態:** 實作基準 | **對應 Phase I MVP:** `docs/12_phase1_mvp.md` | **對應 ADR**：`docs/03_adr.md` v3.1（5 項重大調整）

---

## v3.1 重大修訂說明（2026-05-08）

⚠️ **五項架構翻轉**（客戶決定）：

1. **資料庫**：❌ Supabase Cloud → ✅ **本地 PostgreSQL 17 + pgvector；生產用 GCP Cloud SQL**（ADR-003 翻轉）
2. **認證系統**：❌ Magic Link → ✅ **系統管理員後台建用戶 + 帳密登入 bcrypt**（ADR-014 廢棄，新增 ADR-015）
3. **通知通道**：LINE 主 → **LINE/WhatsApp/Email 三通道 Fallback**（ADR-016 新增）
4. **規則庫**：YAML 固定 → **DB 儲存 + pgvector 語意向量比對**（ADR-017 新增）
5. **部署平台**：Cloudflare Pages + Railway → **GCP Cloud Run + Cloud SQL + Cloud CDN**（ADR-018 新增）

**影響**：
- 移除 Supabase Auth 與 Supabase Storage 依賴
- 認證模組改為 `UserManagementService`（admin 建用戶）+ `PasswordAuthService`（帳密登入）
- 新增模組：`ComplianceRuleService`、`SemanticMatcher`、`WhatsAppChannel`
- 資料層新增：`compliance_rules` 表 + pgvector extension
- 環境配置：本地用 docker-compose PostgreSQL；部署改 GCP

詳見 [03_adr.md § v3.1 修訂](./03_adr.md)。

---

## 第 1 部分：架構總覽

### 1.1 C4 模型（v3.1 更新）

#### L1 系統情境圖（更新：Supabase → Cloud SQL，Magic Link 移除，WhatsApp 新增）

```mermaid
graph TB
    Prospect[潛在客戶<br/>王小姐]
    Coach[教練<br/>阿明]
    Leader[Leader<br/>老陳]
    Admin[系統管理員<br/>後台建帳號]
    
    subgraph Synergy [Synergy AI Closer's Copilot]
        App[Web App + API]
    end

    Gemini[Gemini API<br/>LLM 服務]
    Line[LINE Messaging API<br/>主通道]
    WhatsApp[WhatsApp Business API<br/>次選通道]
    Email[Resend<br/>備援通道]
    CloudSQL[(Cloud SQL<br/>PostgreSQL 17 + pgvector)]
    GoogleCal[Google Calendar API<br/>時程同步]

    Prospect -->|填寫問卷| App
    Prospect -->|收到摘要| App
    Coach -->|帳密登入| App
    Coach -->|查看名單/摘要/話術| App
    Coach -->|收到跟進提醒| Line
    Coach -.->|跨區域用 WhatsApp| WhatsApp
    Coach -.->|Email 備援| Email
    Leader -->|進入 Leader Summary| App
    Admin -->|後台建教練帳號| App
    Admin -->|管理合規規則| App

    App -->|產生摘要、話術| Gemini
    App -->|推播提醒（主）| Line
    App -.->|降級到 WhatsApp| WhatsApp
    App -.->|最終備援 Email| Email
    App -->|持久化（含 vector）| CloudSQL
    App -->|建立日曆事件| GoogleCal
    
    style CloudSQL fill:#ffd700
    style WhatsApp fill:#25d366
```

#### L2 容器圖（更新：本地 postgres + 部署用 GCP）

```mermaid
graph TB
    subgraph "使用者裝置"
        Browser[瀏覽器<br/>手機優先]
    end

    subgraph "Synergy AI Platform (Cloud Run)"
        Web[apps/web<br/>React 19 + Vite<br/>問卷 + 教練後台 + Leader 後台 + Admin 後台]
        API[apps/api<br/>FastAPI + uv<br/>REST + 排程]
        Scheduler[排程器<br/>APScheduler<br/>提醒發送 + 物化視圖更新]
        LLMPkg[packages/llm<br/>LiteLLM 抽象]
    end

    subgraph "本地開發 (docker-compose)"
        LocalPG[(PostgreSQL 17<br/>+ pgvector<br/>localhost:5432)]
    end

    subgraph "GCP 生產環境"
        CloudRun[Cloud Run<br/>自動擴展]
        CloudSQL[(Cloud SQL<br/>PostgreSQL 17<br/>+ pgvector<br/>自動備份)]
        CloudStorage[Cloud Storage<br/>靜態檔案]
        CloudCDN[Cloud CDN<br/>邊界快取]
        CloudDNS[Cloud DNS<br/>api.synergy-ai.tw]
    end

    subgraph "外部服務"
        Gemini[Gemini API<br/>LLM]
        LineAPI[LINE Messaging API<br/>主通道]
        WhatsAppAPI[WhatsApp Business API<br/>次通道]
        ResendAPI[Resend API<br/>備援]
        GoogleCalAPI[Google Calendar API<br/>教練日程]
    end

    Browser -->|HTTPS| Web
    Web -->|REST /api/*| API
    API -->|本地：asyncpg<br/>部署：Cloud SQL Auth Proxy| LocalPG
    API -->|部署時| CloudSQL
    API -->|透過| LLMPkg
    LLMPkg -->|預設 Gemini| Gemini
    Scheduler -->|Cron 每小時| API
    API -->|推播| LineAPI
    API -.->|降級| WhatsAppAPI
    API -.->|降級| ResendAPI
    API -->|建立/更新事件| GoogleCalAPI
    
    CloudRun --> CloudStorage
    CloudCDN --> CloudStorage
    CloudDNS --> CloudCDN
    
    style LocalPG fill:#87ceeb
    style CloudSQL fill:#ffd700
    style CloudRun fill:#4285f4
    style CloudCDN fill:#34a853
```

#### L3 元件圖（apps/api 內部，v3.1 新增 Admin 模組與合規升級）

```mermaid
graph LR
    subgraph "apps/api"
        Router[FastAPI Router]
        
        subgraph "Domain"
            Q[Questionnaire<br/>問卷領域]
            B[Briefing<br/>商談領域]
            C[CRM<br/>客戶管理]
            R[Reminder<br/>提醒領域]
            Comp[Compliance<br/>合規領域]
            Coach[Coaching<br/>商談話術領域]
            CompRule[ComplianceRule<br/>規則庫領域]
            SM[SemanticMatcher<br/>向量比對]
        end
        
        subgraph "Application"
            Auth[AuthService]
            UM[UserManagementService]
            QS[QuestionnaireService]
            BS[BriefingService]
            CS[CrmService]
            RS[ReminderService]
            CompS[ComplianceService]
            CRMS[ComplianceRuleService]
            ConvS[ConversationCoachService]
            ATS[ActivityTrackingService]
            LSS[LeaderSummaryService]
            OPS[OnboardingProgressService]
        end
        
        subgraph "Infrastructure"
            DB[PostgreSQL Client<br/>asyncpg + SQLAlchemy]
            LLM[LLM Adapter]
            Mail[Email Adapter]
            Line[LINE Adapter]
            WhatsApp[WhatsApp Adapter]
            GoogleCal[Google Calendar Adapter]
            EventLog[EventLog Service]
        end
    end

    Router --> Auth
    Router --> UM
    Router --> QS
    Router --> BS
    Router --> CS
    Router --> RS
    Router --> CompS
    Router --> CRMS
    Router --> ConvS
    Router --> ATS
    Router --> LSS
    Router --> OPS
    
    Auth --> DB
    UM --> DB
    QS --> Q
    QS --> DB
    BS --> B
    BS --> LLM
    BS --> DB
    BS --> CompS
    CS --> C
    CS --> DB
    RS --> R
    RS --> DB
    RS --> Line
    RS --> WhatsApp
    RS --> Mail
    RS --> GoogleCal
    CompS --> Comp
    CompS --> SM
    CompS --> CRMS
    CompS --> LLM
    CompS --> DB
    CRMS --> CompRule
    CRMS --> DB
    ConvS --> Coach
    ConvS --> LLM
    ConvS --> CompS
    ATS --> DB
    ATS --> EventLog
    LSS --> DB
    OPS --> DB
    
    LLM --> EventLog
    CompS --> EventLog
    ConvS --> EventLog
    Line --> EventLog
    WhatsApp --> EventLog
    Mail --> EventLog
    
    style Auth fill:#ffcccb
    style UM fill:#ffcccb
    style CRMS fill:#fff9c4
    style SM fill:#fff9c4
    style WhatsApp fill:#25d366
```

---

### 1.2 DDD 戰略設計（v3.1 補充）

#### 通用語言（Ubiquitous Language）——v3.1 擴充

| 領域術語 | 定義 | 對應程式碼命名 |
| :--- | :--- | :--- |
| **問卷** | 一份填完的健康問卷實例 | `Questionnaire` entity |
| **商談摘要** | AI 生成給教練看的單頁摘要（客戶版 + 教練版） | `Briefing` aggregate |
| **名單** | 填完問卷後的客戶資料 | `Lead` entity |
| **客戶狀態** | 新名單/已填問卷/已預約/已商談/已推薦/試用中/已成交/未成交/需回訪/沉默（10 種） | `LeadStatus` enum |
| **提醒** | 排程給教練的跟進通知 | `Reminder` entity |
| **商談話術** | 前/中/後三段教練用話術 | `ConversationPlan` aggregate |
| **合規規則** | C1/C2/C3/C4 合規詞表，帶向量與改寫建議（新） | `ComplianceRule` entity |
| **合規檢查** | 文字通過規則庫、向量比對、LLM 的流程（新） | `ComplianceLog`、`ComplianceCheck` entity |
| **人工審核** | 教練看草稿、編輯、決策是否發送（改名） | `MessageDraft` entity |
| **活動指標** | 教練問卷數、商談數、成交數等聚合 | `ActivityMetrics` entity |
| **新手進度** | 新教練的 onboarding checklist | `OnboardingTask` entity |
| **教練帳號** | 系統使用者，由 admin 後台建立 | `Coach` entity = User（帳密驗證） |
| **Leader** | 管理者（資深經營者，監控下線） | `Leader` = Coach（角色：role='leader'） |
| **租戶** | 多品牌隔離單位 | `Tenant` entity，MVP 固定 'synergy' |

#### 限界上下文（Bounded Context）——v3.1 新增

```mermaid
graph LR
    Auth[Authentication Context<br/>帳密驗證 + JWT]
    Admin[Admin Management Context<br/>用戶建立、規則維護]
    Q[Questionnaire Context]
    L[Lead Management Context]
    B[Briefing Context]
    Conv[Coaching Context]
    Comp[Compliance Context]
    Notif[Notification Context]
    Activity[Activity Tracking Context]

    Auth -->|提供身份| L
    Auth -->|提供身份| Admin
    Admin -->|管理規則庫| Comp
    Admin -->|管理用戶| L
    Q -->|送出觸發| L
    L -->|新建 Lead 觸發| B
    L -->|狀態變更觸發| Notif
    B -->|話術需檢查| Comp
    B -->|產生對話計畫| Conv
    Conv -->|話術需檢查| Comp
    Comp -->|觸發改寫| B
    Notif -->|提醒內容檢查| Comp
    L -->|記錄行為| Activity
    B -->|記錄行為| Activity
    Notif -->|記錄行為| Activity
    
    style Auth fill:#ffcccb
    style Admin fill:#ffcccb
    style Comp fill:#fff9c4
```

**新增 Context 說明**：

| Context | 核心職責 | 對應模組 |
| :--- | :--- | :--- |
| **Authentication** | 帳密驗證、JWT 核發、Session 管理 | AuthService、PasswordHasher |
| **Admin Management** | 用戶 CRUD、規則庫管理、稽核日誌 | UserManagementService、ComplianceRuleService |
| **Compliance** | 文字風險檢查（規則庫 + 向量 + LLM）、教練決策 | ComplianceService、SemanticMatcher、ComplianceRuleService |
| **Notification** | 訊息路由（LINE/WhatsApp/Email）、Fallback、送達追蹤 | NotificationService + 三個 Channel 實作 |

---

### 1.3 分層架構（v3.1 更新）

MVP 採用 **Clean Architecture 精簡版**（3 層）：

| 層 | 內容 | 目錄 | v3.1 新增 |
| :--- | :--- | :--- | :--- |
| **Domain** | Entity、Value Object、業務規則 | `apps/api/src/domain/` | `ComplianceRule`、`SemanticMatcher` |
| **Application** | Use Case、Service、編排邏輯 | `apps/api/src/application/` | `UserManagementService`、`ComplianceRuleService`、`PasswordAuthService` |
| **Infrastructure** | DB、LLM、Email、HTTP Adapter | `apps/api/src/infrastructure/` | `PostgreSQL Async`、`WhatsAppChannel`、`ComplianceRuleRepository` |

**依賴方向**：Infrastructure → Application → Domain（向內依賴）。

**v3.1 新增**：
- Application 層新增 3 個 service（`UserManagementService`、`PasswordAuthService`、`ComplianceRuleService`）
- Domain 層新增 `SemanticMatcher` 純函式 + `ComplianceRule` aggregate
- Infrastructure 層遷離 Supabase，改用 SQLAlchemy 2.0 + asyncpg + pgvector

---

### 1.4 技術選型（v3.1 更新）

| 分類 | 選用技術 | 選擇理由 | 備選方案 | ADR |
| :--- | :--- | :--- | :--- | :--- |
| **後端框架** | FastAPI + Python 3.12 + uv | 延用 module2；async 原生、Pydantic 整合 | Django、Flask | ADR-001 |
| **前端框架** | React 19 + Vite | SPA 模式、快速啟動、靜態輸出 | Next.js、Remix | ADR-013 |
| **資料庫** | **PostgreSQL 17 + pgvector（本地 docker；GCP Cloud SQL 部署）** | ✅ **v3.1 翻轉**：向量支援、RLS、自管理、成本低 | Supabase（已廢棄）、PlanetScale | ADR-003 |
| **認證方案** | **bcrypt 帳密 + JWT（admin 後台建用戶）** | ✅ **v3.1 翻轉**：簡化、企業規範、無第三方依賴 | Supabase Auth / Magic Link（已廢棄）、Clerk | ADR-015 |
| **LLM** | Gemini-2.5-flash via LiteLLM | 成本最低、抽象層可切 | Claude Opus 4.6 | ADR-004 |
| **訊息通道（主）** | LINE Messaging API | 台灣教練日常慣用、開信率最高 | WhatsApp（非台灣） | ADR-008 |
| **訊息通道（次）** | **WhatsApp Business API（新）** | **v3.1 新增**：東南亞覆蓋、Fallback 選項 | — | ADR-016 |
| **訊息通道（備援）** | Resend（Email） | 無金錢成本、全球覆蓋 | SendGrid、SES | ADR-016 |
| **合規檢查** | **規則庫 DB + pgvector 語意比對 + LLM 二次覆核** | **v3.1 升級**：動態規則管理、語意準確、可稽核 | YAML YAML 固定（已廢棄）、純 LLM | ADR-017 |
| **人工決策** | 教練在 UI 看草稿、自主決策 | 簡化流程、符合「輔助」定位 | 外部審核員佇列（已廢棄） | ADR-011 |
| **排程** | APScheduler（Python in-process） + **Cloud Scheduler（部署）** | 單機夠用、Pilot 量小；部署改用 GCP | Celery、Temporal | — |
| **CI/CD** | GitHub Actions | 標準、與 GCP 整合 | GitLab CI | — |
| **部署** | **GCP（Cloud Run + Cloud SQL + Cloud CDN）** | **v3.1 翻轉**：企業級基礎設施、成本可控、自動擴展 | Railway（已廢棄）、Fly.io、Vercel | ADR-018 |
| **可觀測性** | Cloud Logging + Cloud Monitoring（部署）；本地 stderr | GCP 原生、無額外成本 | Sentry、Datadog | — |

---

## 第 2 部分：需求摘要（同 v3.0，無新增）

（維持既有，詳見上版本）

---

## 第 3 部分：系統設計

### 3.1 架構模式

- **模式**：模組化單體（Modular Monolith）+ 扁平 Monorepo
- **選擇理由**：MVP 量小，微服務過度工程；單體內按 Bounded Context 分模組，Phase 2 要拆時邊界清楚

### 3.2 元件職責——v3.1 補充

| 元件 | 核心職責 | 技術 | v3.1 變更 |
| :--- | :--- | :--- | :--- |
| `apps/web` | 問卷填答 UI + 教練後台 + Leader 後台 + **Admin 後台** | React 19 / Vite | ✨ Admin 頁面：`/admin/users`、`/admin/compliance-rules` |
| `apps/api` | REST API + 排程器 | **FastAPI + PostgreSQL asyncpg** | ❌ 移除 Supabase SDK；✨ 新增 SQLAlchemy 2.0 + alembic migration；✨ 新增 `docker-compose.yml` |
| `packages/domain` | 共用型別（TS + Pydantic dual） | TypeScript + Python | ✨ `ComplianceRule`、`User`（帳密驗證）、`SemanticMatcher` |
| `packages/llm` | LLM 抽象 + prompt 模板 + 合規改寫 | Python / LiteLLM | ✨ Embedding adapter（Gemini / sentence-transformers） |
| `packages/ui` | 共用 React 元件 | React + Tailwind | ✨ Admin UI 元件（user table、rule editor） |
| **PostgreSQL 17** | **資料庫 + 向量存儲** | **docker-compose（本地）/ GCP Cloud SQL（部署）** | **✨ 新增 pgvector extension、compliance_rules 表、users 密碼欄位** |
| APScheduler | 每小時掃提醒、30min 更新物化視圖 | Python in-process（本地）；**Cloud Scheduler（部署）** | ✨ 部署改用 GCP Cloud Scheduler |

---

## 第 4 部分：資料架構（v3.1 重大更新）

### 4.1 資料庫遷移（Supabase → PostgreSQL + pgvector）

#### 本地開發（docker-compose）

```yaml
# docker-compose.yml（新增）
version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:pg17
    environment:
      POSTGRES_DB: synergy_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev_local
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infrastructure/db/migrations/init.sql:/docker-entrypoint-initdb.d/init.sql

volumes:
  postgres_data:
```

#### 連線字串（v3.1 改動）

```bash
# v3.0（Supabase，已廢棄）
DATABASE_URL="postgresql://user:pass@db.xxx.supabase.co:5432/postgres"

# v3.1 本地
DATABASE_URL="postgresql+asyncpg://dev:dev_local@localhost:5432/synergy_dev"

# v3.1 GCP Cloud SQL（部署）
DATABASE_URL="postgresql+asyncpg://user:pass@/synergy?host=/cloudsql/PROJECT_ID:REGION:INSTANCE"
```

### 4.2 ER 模型（v3.1 新增表與欄位）

```mermaid
erDiagram
    TENANTS ||--o{ USERS : has
    TENANTS ||--o{ COACHES : has
    TENANTS ||--o{ LEADS : scopes
    TENANTS ||--o{ COMPLIANCE_RULES : scopes
    USERS ||--o{ COACHES : is
    COACHES ||--o{ LEADS : owns
    COACHES ||--o{ COMPLIANCE_RULES : manages
    COACHES ||--o{ ONBOARDING_TASKS : receives
    COACHES ||--o{ EVENT_LOGS : generates
    LEADS ||--|| QUESTIONNAIRES : from
    LEADS ||--o| BRIEFINGS : has
    LEADS ||--o| CONVERSATION_PLANS : has
    LEADS ||--o{ REMINDERS : schedules
    LEADS ||--o{ MESSAGE_DRAFTS : generates
    LEADS ||--o{ STATUS_CHANGES : tracks
    LEADS ||--o{ COMPLIANCE_LOGS : references
    QUESTIONNAIRES ||--o{ ANSWERS : contains
    QUESTIONNAIRE_TEMPLATES ||--o{ QUESTIONNAIRES : instantiates
    COMPLIANCE_RULES ||--o{ COMPLIANCE_LOGS : triggers
    COMPLIANCE_LOGS ||--o{ MESSAGE_DRAFTS : generates
    ACTIVITY_METRICS ||--o{ COACHES : aggregates

    TENANTS {
        uuid id PK
        string code
        string name
        jsonb config
        timestamptz created_at
    }
    
    USERS {
        uuid id PK
        uuid tenant_id FK
        string email UNIQUE
        string password_hash "bcrypt(cost=12)"
        boolean must_change_password "首次強制改"
        int failed_login_count "暴力破解計數"
        timestamptz locked_until "鎖定至時間"
        timestamptz created_at
        timestamptz updated_at
    }
    
    COACHES {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        string name
        string role "coach/leader/admin"
        string line_user_id "LINE OA 綁定"
        string whatsapp_id "WhatsApp 新增"
        string timezone
        uuid leader_id FK
        timestamptz created_at
    }
    
    COMPLIANCE_RULES {
        uuid id PK
        uuid tenant_id FK
        string category "C1/C2/C3/C4"
        string phrase "黑名單詞或句"
        string severity "low/medium/high"
        text suggested_rewrite "自動改寫建議"
        vector embedding "pgvector(1536)"
        boolean enabled
        uuid created_by FK
        uuid updated_by FK
        timestamptz created_at
        timestamptz updated_at
    }
    
    MESSAGE_DRAFTS {
        uuid id PK
        uuid lead_id FK
        uuid coach_id FK
        text original_text
        text rewritten_text
        string status "pending_coach_review/approved/rejected"
        float quality_score
        uuid array matched_rule_ids
        text coach_decision "接受/編輯/丟棄"
        text coach_edit_content "教練編輯的版本"
        timestamptz reviewed_at
        timestamptz created_at
    }
    
    COMPLIANCE_LOGS {
        uuid id PK
        uuid lead_id FK
        text original_text
        string risk_type "C1/C2/C3/C4"
        text rewritten_text
        float semantic_match_score
        uuid array matched_rule_ids
        string risk_level
        uuid reviewed_by FK
        string decision "approved/rejected"
        timestamptz reviewed_at
        timestamptz created_at
    }

    ONBOARDING_TASKS {
        uuid id PK
        uuid coach_id FK
        string task_key
        timestamptz completed_at
        uuid assigned_by FK
        int priority
        timestamptz created_at
    }
    
    EVENT_LOGS {
        uuid id PK
        uuid user_id FK
        string action
        string resource
        timestamptz timestamp
        int latency_ms
        int token_count
        string model_version
        jsonb risk_keywords
        string result
    }
    
    ACTIVITY_METRICS {
        uuid id PK
        uuid coach_id FK
        string metric_type
        int value
        date metric_date
        timestamptz updated_at
    }
```

### 4.3 新增表詳規

#### `users` 表（v3.1 新增）

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,  -- bcrypt(cost=12)
    must_change_password BOOLEAN DEFAULT true,  -- 首次強制改
    failed_login_count INT DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    INDEX idx_email (email),
    INDEX idx_tenant_id (tenant_id)
);
```

#### `compliance_rules` 表（v3.1 新增）

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE compliance_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('C1', 'C2', 'C3', 'C4')),
    phrase TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    suggested_rewrite TEXT,
    embedding vector(1536),  -- pgvector 向量
    enabled BOOLEAN DEFAULT true,
    created_by UUID NOT NULL REFERENCES users(id),
    updated_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    INDEX idx_category_enabled (category, enabled),
    INDEX idx_embedding ON embedding USING ivfflat (vector_cosine_ops)
);
```

#### `message_drafts` 表（v3.1 取代舊的 compliance_queue）

```sql
CREATE TABLE message_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    coach_id UUID NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
    original_text TEXT NOT NULL,
    rewritten_text TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending_coach_review', 'approved', 'rejected')) DEFAULT 'pending_coach_review',
    quality_score FLOAT,
    matched_rule_ids UUID[] DEFAULT '{}',  -- pgvector 相符規則 IDs
    coach_decision TEXT,
    coach_edit_content TEXT,  -- 教練編輯後的文本
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    INDEX idx_coach_id (coach_id),
    INDEX idx_status (status)
);
```

#### `coaches` 表補充欄位

```sql
ALTER TABLE coaches ADD COLUMN whatsapp_id TEXT;  -- WhatsApp ID（新增）
ALTER TABLE coaches ADD COLUMN password_hash TEXT;  -- 暫時（若從 users FK 改）
```

### 4.4 物化視圖（同 v3.0，無改動）

（保持既有）

---

## 第 5 部分：部署與基礎設施（v3.1 重大改動）

### 5.1 環境策略

| 環境 | DB | API URL | Web URL | 用途 | v3.1 變更 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **local** | docker-compose PostgreSQL | localhost:8000 | localhost:3000 | 開發 | ✅ 改為 PostgreSQL（vs Supabase） |
| **staging** | GCP Cloud SQL（dev 實例） | api-staging.synergy-ai.tw | staging.synergy-ai.tw | 內部驗證 | ✅ 改為 GCP |
| **production** | GCP Cloud SQL（prod 實例） | api.synergy-ai.tw | app.synergy-ai.tw | Pilot 使用 | ✅ 改為 GCP |

### 5.2 部署拓撲（GCP）

```
使用者
  ↓
Cloud DNS（api.synergy-ai.tw、app.synergy-ai.tw）
  ↓
Cloud Load Balancer
  ├─ api.* → Cloud Run（FastAPI）
  └─ app.* → Cloud CDN → Cloud Storage（React 靜態檔）
  ↓
Cloud Run
  ├─ 自動擴展（0-10 instance）
  ├─ 健康檢查：/health
  └─ 環境變數：Secret Manager
  ↓
Cloud SQL Auth Proxy
  ↓
Cloud SQL（PostgreSQL 17 + pgvector）
  ├─ 自動備份（每天）
  ├─ SSL 強制（pg_hba）
  └─ 讀副本（可選 Phase 2）

排程層
  ├─ Cloud Scheduler（每小時）
  └─ Cloud Run Job → Reminder scan
```

### 5.3 成本估算（月度，Pilot 階段，v3.1 更新）

| 項目 | 成本 (NTD) | 備註 |
| :--- | :--- | :--- |
| Cloud Storage + CDN | 100-200 | 1 GB + 10 GB egress |
| Cloud Run | 200-500 | 平均 0.5 instance，3000h/月 |
| Cloud SQL | 250-350 | db-f1-micro，300 GB storage，自動備份 |
| Cloud Scheduler | 50 | 2 個 job |
| Cloud Logging | 50-100 | 100 GB logs/月 |
| Artifact Registry | 50 | 1 GB docker image |
| Cloud DNS | 20 | 4 zone + queries |
| Cloud Load Balancer | 100-150 | per rule + data |
| Gemini Embedding API | 100-150 | 合規規則向量化 |
| LINE Messaging API | 800 | Light plan 15k 訊息 |
| WhatsApp Business API | 200-500 | 按訊息量計費 |
| Resend（Email 備援） | 0 | < 3,000 封/月 |
| **合計** | **~2,170-3,350 NTD** | 比 v3.0（Supabase+Railway）~1,110-2,660 高，但統一 GCP |

**註**：若客戶提供 GCP Project 與 billing，可直接掛客戶帳號，成本由客戶承擔。

---

## 第 6 部分：可觀測性與風險（v3.1 補充）

### 6.1 EventLog 設計（同 v3.0，新增欄位）

```python
# EventLog 新增欄位（v3.1）
event_logs.risk_keywords  # 觸發的合規詞
event_logs.matched_rule_ids  # 命中的規則 ID（pgvector）
event_logs.semantic_match_score  # 語意相似度分數
event_logs.embedding_model  # Embedding 模型版本（gemini / sentence-transformers）
```

### 6.2 安全性補充（v3.1）

#### 密碼政策
- 最少 10 字元，含數字 + 字母（大小寫）
- bcrypt cost = 12（驗證時間 ~0.3s，安全性最優）
- 暴力破解：失敗 5 次 → 15 分鐘鎖定

#### PostgreSQL 安全（本地 vs GCP）

**本地（docker-compose）**：
- 預設 trust authentication（開發用）
- 可在 `docker-compose.yml` 設置環境變數 `POSTGRES_PASSWORD`

**GCP Cloud SQL**：
- SSL 強制（Cloud SQL Proxy 自動配置）
- Cloud SQL Auth Proxy（應用端無需存密碼）
- 自動備份與 PITR（Point-in-Time Recovery）

#### WhatsApp 安全
- Webhook 驗證：X-Hub-Signature（HMAC-SHA256）
- Phone Number ID：需客戶申請 Meta Business Manager

---

## 第 7 部分：環境變數（v3.1 完整清單）

### 本地開發（.env.local）

```bash
# PostgreSQL
DATABASE_URL=postgresql+asyncpg://dev:dev_local@localhost:5432/synergy_dev

# API
API_PORT=8000
API_HOST=0.0.0.0
LOG_LEVEL=DEBUG

# Frontend
VITE_API_BASE_URL=http://localhost:8000

# LLM
GEMINI_API_KEY=...

# 認證
JWT_SECRET_KEY=...
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=7

# LINE
LINE_MESSAGING_API_KEY=...
LINE_MESSAGING_API_SECRET=...

# WhatsApp（若本地開發需測）
WHATSAPP_ACCESS_TOKEN=...
WHATSAPP_PHONE_NUMBER_ID=...
WHATSAPP_VERIFY_TOKEN=...

# Email
RESEND_API_KEY=...

# 合規
SEMANTIC_SIMILARITY_THRESHOLD=0.85
EMBEDDING_MODEL=sentence-transformers  # 本地用開源，免費

# Google Calendar
GOOGLE_CALENDAR_API_KEY=...
```

### GCP Cloud Run（Secret Manager）

```bash
gcloud secrets create database-url --data-file=- <<< "postgresql+asyncpg://user:pass@cloudsql/..."
gcloud secrets create jwt-secret-key --data-file=- <<< "..."
gcloud secrets create gemini-api-key --data-file=- <<< "..."
gcloud secrets create whatsapp-access-token --data-file=- <<< "..."
# ... 等等

# 部署時
gcloud run deploy synergy-api \
  --set-env-vars DATABASE_URL=projects/PROJECT_ID/secrets/database-url/versions/latest:ref \
  --set-env-vars JWT_SECRET_KEY=projects/PROJECT_ID/secrets/jwt-secret-key/versions/latest:ref \
  ...
```

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v1.0 | 2026-04-24 | 初版（C4、DDD、分層、Supabase） |
| v3.0 | 2026-05-08 | 新增 Compliance / HITL / Coaching / Activity 層 |
| **v3.1** | **2026-05-08** | **5 項翻轉：DB 改 PostgreSQL/GCP、認證改帳密+後台建用戶、通知加 WhatsApp、規則庫 DB+pgvector、部署改 GCP；新增 20+ 頁架構更新** |
