# 05 後端架構規範（FastAPI + uv）

版本 v0.3 | 日期 2026-06-07 | 狀態 draft | 對應 PRD v0.2（docs/PRD.md）/ 00_tech-spec v0.4 | 專案根 backend/

> v0.3 變更：新增 16.8 來訊自動分析服務（enrichment_service，單次 Haiku 三合一）、16.9 語音 OA 發送（voice_service.send）、16.10 太業務員發送前預警；message_drafts/voice_clips 發送後自動寫入互動時間軸。

---

## 目錄

1. [整體分層架構](#1-整體分層架構)
2. [目錄結構](#2-目錄結構)
3. [應用啟動與設定](#3-應用啟動與設定)
4. [依賴注入與請求生命週期](#4-依賴注入與請求生命週期)
5. [認證與授權](#5-認證與授權)
6. [Repository 模式與資料存取](#6-repository-模式與資料存取)
7. [AI 編排整合介面](#7-ai-編排整合介面)
8. [合規 Sidecar（regex < 50ms）](#8-合規-sidecarregex--50ms)
9. [學習紀錄掛載機制](#9-學習紀錄掛載機制)
10. [排程器](#10-排程器)
11. [問卷公開端點安全](#11-問卷公開端點安全)
12. [語音 TTS 抽象層](#12-語音-tts-抽象層)
13. [錯誤處理與輸入驗證](#13-錯誤處理與輸入驗證)
14. [可觀測性掛載點](#14-可觀測性掛載點)
15. [測試策略](#15-測試策略)
16. [LINE 整合](#16-line-整合)

---

## 1. 整體分層架構

### 1.1 四層架構總覽

Care Copilot 後端採用嚴格的四層架構，每層職責單一，依賴方向由上往下（上層依賴下層，嚴禁跨層反向呼叫）。

```
┌──────────────────────────────────────────────────────────────┐
│  API 層（app/api/）                                           │
│  FastAPI Router、請求/回應 schema 轉換、HTTP 語義             │
│  職責：路由分派、Depends 注入、請求驗證、回應序列化           │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│  Service 層（app/services/）                                  │
│  業務邏輯、AI 呼叫協調、合規 gate、學習紀錄寫入              │
│  職責：工具業務規則、跨 Repository 協調、AI 結果後處理        │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│  Repository 層（app/repositories/）                           │
│  資料存取抽象、RLS 租戶隔離、查詢封裝                         │
│  職責：CRUD、分頁查詢、pgvector 搜尋、SQLAlchemy async 封裝  │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│  Infrastructure 層（app/infra/）                              │
│  資料庫連線、外部 API client、快取、排程                      │
│  職責：asyncpg 連線池、Anthropic/OpenAI client、APScheduler  │
└──────────────────────────────────────────────────────────────┘

          ┌─────────────────────────────┐
          │  Sidecar / Agent 層          │
          │  app/sidecars/ + app/agents/ │
          │  compliance_sidecar（< 50ms）│
          │  LangGraph agents（沿用框架）│
          └─────────────────────────────┘
```

### 1.2 請求生命週期圖

以「T06 訊息草稿 SSE 串流」為例，展示請求從進入到回應的完整路徑：

```mermaid
sequenceDiagram
    participant C as 前端（PWA）
    participant MW as Middleware 層
    participant R as Router（api/）
    participant S as Service（services/）
    participant SC as ComplianceSidecar
    participant AG as LangGraph Agent
    participant DB as PostgreSQL
    participant LL as LearningLog（async）

    C->>MW: POST /api/v1/message-drafts/stream<br/>Bearer <jwt>
    MW->>MW: verify_jwt()<br/>注入 tenant_id + distributor_id
    MW->>R: 通過認證，路由分派
    R->>R: Pydantic 驗證請求 body
    R->>S: MessageDraftService.stream_draft(ctx, req)
    S->>DB: 查詢 contacts（tenant_id 隔離）
    S->>SC: compliance_check（前置掃描 context）
    SC-->>S: {status: green, latency_ms: 12}
    S->>AG: haiku_first_token(context)
    AG-->>C: SSE event: first_token
    S->>AG: sonnet_stream_full(context)
    loop streaming tokens
        AG-->>C: SSE event: token
    end
    S->>SC: compliance_check（草稿全文）
    SC-->>C: SSE event: compliance_result
    S->>DB: INSERT message_drafts
    S->>DB: INSERT compliance_checks（100% 寫入）
    S-->>C: SSE event: done {draft_id, latency_ms}
    S->>LL: async fire-and-forget: INSERT learning_logs
```

---

## 2. 目錄結構

```
backend/
├── app/
│   ├── main.py                        # FastAPI 應用入口，:8002
│   ├── api/                           # 路由層（依工具拆模組）
│   │   ├── __init__.py
│   │   ├── deps.py                    # 共用 Depends 函式
│   │   ├── auth.py                    # /auth/me、/auth/me/usage-quota
│   │   ├── contacts.py                # T01 路由
│   │   ├── life_events.py             # T02 路由
│   │   ├── emotion.py                 # T03 路由
│   │   ├── salesy_alerts.py           # T04 路由
│   │   ├── today_tasks.py             # T05 路由
│   │   ├── message_drafts.py          # T06 路由（含 SSE）
│   │   ├── samples.py                 # T07 路由
│   │   ├── voice_clips.py             # T08 路由
│   │   ├── objection_responses.py     # T09 路由
│   │   ├── questionnaire.py           # T10 路由（含公開端點）
│   │   ├── recruitment.py             # T11 路由
│   │   ├── compliance.py              # SYS 合規路由
│   │   ├── platform.py                # PLT 訂閱/用量/同意/資料請求
│   │   └── webhooks.py                # LINE webhook（公開，HMAC 驗簽）
│   ├── services/                      # 業務邏輯層
│   │   ├── contact_service.py         # T01
│   │   ├── life_event_service.py      # T02
│   │   ├── emotion_service.py         # T03
│   │   ├── salesy_alert_service.py    # T04
│   │   ├── today_task_service.py      # T05
│   │   ├── message_draft_service.py   # T06（含 send via LINE push）
│   │   ├── sample_service.py          # T07
│   │   ├── voice_service.py           # T08
│   │   ├── objection_service.py       # T09
│   │   ├── questionnaire_service.py   # T10
│   │   ├── recruitment_service.py     # T11
│   │   ├── compliance_service.py      # SYS 合規業務
│   │   ├── learning_log_service.py    # PLT 學習紀錄
│   │   ├── quota_service.py           # 配額/熔斷
│   │   ├── subscription_service.py    # 訂閱管理
│   │   ├── assignment_service.py      # 新客戶 round-robin 輪派
│   │   └── inbox_service.py           # inbound_messages 處理流程
│   ├── agents/                        # LangGraph agent（沿用既有框架）
│   │   ├── __init__.py
│   │   ├── base_agent.py              # 抽象 OrchestratorClient 介面
│   │   ├── emotion_agent.py           # Haiku 4.5 三檔情緒
│   │   ├── draft_agent.py             # Haiku 首字 + Sonnet 全文
│   │   ├── objection_agent.py         # Haiku 速度優先
│   │   ├── insight_agent.py           # Sonnet 活檔案 insight
│   │   ├── questionnaire_agent.py     # Sonnet 摘要
│   │   └── recruitment_agent.py       # Sonnet 招募
│   ├── sidecars/
│   │   └── compliance_sidecar.py      # regex sidecar < 50ms
│   ├── infra/
│   │   ├── scheduler.py               # APScheduler
│   │   ├── storage.py                 # GCS 語音儲存
│   │   ├── voice_provider.py          # TTS 抽象層（OpenAI / ElevenLabs）
│   │   └── line_client.py             # LINE Messaging API client（push_message / get_profile）
│   ├── repositories/                  # 資料存取層
│   │   ├── base_repository.py         # 帶 tenant_id 的通用 CRUD
│   │   ├── contact_repository.py
│   │   ├── life_event_repository.py
│   │   ├── emotion_repository.py
│   │   ├── salesy_alert_repository.py
│   │   ├── today_task_repository.py
│   │   ├── message_draft_repository.py
│   │   ├── sample_repository.py
│   │   ├── voice_clip_repository.py
│   │   ├── objection_repository.py
│   │   ├── questionnaire_repository.py
│   │   ├── recruitment_repository.py
│   │   ├── compliance_repository.py
│   │   ├── learning_log_repository.py
│   │   ├── quota_repository.py
│   │   ├── subscription_repository.py
│   │   ├── inbound_message_repository.py  # inbound_messages CRUD
│   │   └── official_account_repository.py # official_accounts CRUD
│   ├── models/                        # SQLAlchemy ORM 模型
│   │   ├── base.py
│   │   ├── tenant.py
│   │   ├── distributor.py
│   │   ├── contact.py
│   │   ├── interaction.py
│   │   ├── life_event.py
│   │   ├── sample.py
│   │   ├── message_draft.py
│   │   ├── voice_clip.py
│   │   ├── objection.py
│   │   ├── questionnaire.py
│   │   ├── recruitment.py
│   │   ├── compliance.py
│   │   ├── learning_log.py
│   │   ├── subscription.py
│   │   ├── official_account.py        # official_accounts 表（oa_ 前綴）
│   │   └── inbound_message.py         # inbound_messages 表（inb_ 前綴）
│   ├── schemas/                       # Pydantic 請求/回應 schema
│   │   ├── common.py                  # 分頁、錯誤信封、enum
│   │   ├── contact.py
│   │   ├── message_draft.py
│   │   ├── voice_clip.py
│   │   ├── questionnaire.py
│   │   └── ...（各模組對應）
│   ├── db/
│   │   ├── session.py                 # SQLAlchemy async engine
│   │   └── migrations/                # Alembic 遷移腳本
│   │       ├── env.py
│   │       └── versions/
│   └── core/
│       ├── config.py                  # pydantic-settings Settings
│       ├── auth.py                    # JWT 驗證、TenantContext
│       ├── errors.py                  # 全域例外與錯誤碼
│       └── observability.py           # OTel + Langfuse + Sentry 初始化
├── tests/
│   ├── unit/
│   ├── integration/
│   └── red_team/                      # 租戶隔離紅隊測試
├── pyproject.toml
├── uv.lock
└── requirements.txt                   # uv pip compile 產出
```

---

## 3. 應用啟動與設定

### 3.1 pydantic-settings 設定模型

```python
# app/core/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, field_validator
from typing import Literal


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── 應用 ──────────────────────────────────────────────
    app_env: Literal["development", "staging", "production"] = "development"
    app_port: int = 8002
    debug: bool = False
    log_level: str = "INFO"

    # ── 資料庫 ────────────────────────────────────────────
    database_url: str                       # postgresql+asyncpg://...
    database_pool_size: int = 10
    database_max_overflow: int = 20

    # ── 認證（自建 JWT）──────────────────────────────────
    jwt_secret: str                         # HS256 簽/驗用
    jwt_alg: str = "HS256"
    access_token_ttl_hours: int = 24

    # ── GCS 語音儲存 ──────────────────────────────────────
    gcs_bucket: str
    google_application_credentials: str = ""  # 本地開發用，Prod 用 Workload Identity

    # ── AI 供應商 ─────────────────────────────────────────
    anthropic_api_key: str
    openai_api_key: str = ""               # 語音 TTS（供應商未定）
    elevenlabs_api_key: str = ""           # 語音 TTS（供應商未定）
    voice_provider: Literal["openai", "elevenlabs"] = "openai"  # 假設：預設 OpenAI

    # ── AI 模型 ───────────────────────────────────────────
    haiku_model_id: str = "claude-haiku-4-5"
    sonnet_model_id: str = "claude-sonnet-4-6"

    # ── 成本護欄 ──────────────────────────────────────────
    ai_cost_daily_limit_usd: float = 0.30

    # ── 觀測 ──────────────────────────────────────────────
    langfuse_public_key: str = ""
    langfuse_secret_key: str = ""
    langfuse_host: str = "https://cloud.langfuse.com"
    sentry_dsn: str = ""
    otel_endpoint: str = ""                # OTLP gRPC endpoint

    # ── LINE Messaging API ────────────────────────────────
    line_channel_secret: str = ""        # HMAC-SHA256 webhook 驗簽用
    line_channel_access_token: str = ""  # push_message bearer token（prod 走 Secret Manager）

    # ── 語音 TTL（GCS Object Lifecycle 主控，此欄供 fallback 參考）─
    voice_clip_expiry_days: int = 7

    @field_validator("app_env")
    @classmethod
    def validate_env(cls, v: str) -> str:
        return v


def get_settings() -> Settings:
    return Settings()


# 單例：避免重複讀取 .env
settings = get_settings()
```

### 3.2 .env 範本（提交至 .gitignore，僅範本入版控）

```dotenv
# .env.example
APP_ENV=development
APP_PORT=8002
DEBUG=true
LOG_LEVEL=DEBUG

DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/carecopilot
DATABASE_POOL_SIZE=10
DATABASE_MAX_OVERFLOW=20

JWT_SECRET=change-me-in-production
JWT_ALG=HS256
ACCESS_TOKEN_TTL_HOURS=24

GCS_BUCKET=care-copilot-voice-dev
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
ELEVENLABS_API_KEY=...
VOICE_PROVIDER=openai

LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
SENTRY_DSN=https://...@sentry.io/...
OTEL_ENDPOINT=http://localhost:4317

# LINE Messaging API（每租戶一個 OA；prod 值由 GCP Secret Manager 注入）
LINE_CHANNEL_SECRET=your-channel-secret
LINE_CHANNEL_ACCESS_TOKEN=your-channel-access-token
```

### 3.3 main.py 應用入口

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.observability import init_observability
from app.core.errors import register_exception_handlers
from app.infra.scheduler import start_scheduler, shutdown_scheduler
from app.api import (
    auth, contacts, life_events, emotion, salesy_alerts,
    today_tasks, message_drafts,
    samples, voice_clips, objection_responses,
    questionnaire, recruitment, compliance, platform,
    webhooks,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """應用啟動與關閉生命週期管理"""
    # 啟動
    init_observability()
    await start_scheduler()
    yield
    # 關閉
    await shutdown_scheduler()


app = FastAPI(
    title="Care Copilot API",
    version="0.1.0",
    description="AI 直銷 Care Copilot — Phase I MVP",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3002"] if settings.debug else ["https://app.carecopilot.ai"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── 例外處理器 ────────────────────────────────────────────
register_exception_handlers(app)

# ── 路由掛載 ──────────────────────────────────────────────
PREFIX = "/api/v1"
app.include_router(auth.router,                prefix=PREFIX)
app.include_router(contacts.router,            prefix=PREFIX)
app.include_router(life_events.router,         prefix=PREFIX)
app.include_router(emotion.router,             prefix=PREFIX)
app.include_router(salesy_alerts.router,       prefix=PREFIX)
app.include_router(today_tasks.router,         prefix=PREFIX)
app.include_router(message_drafts.router,      prefix=PREFIX)
app.include_router(samples.router,             prefix=PREFIX)
app.include_router(voice_clips.router,         prefix=PREFIX)
app.include_router(objection_responses.router, prefix=PREFIX)
app.include_router(questionnaire.router,       prefix=PREFIX)
app.include_router(recruitment.router,         prefix=PREFIX)
app.include_router(compliance.router,          prefix=PREFIX)
app.include_router(platform.router,            prefix=PREFIX)
# LINE webhook（公開，不走 JWT；HMAC 驗簽在 handler 內完成）
app.include_router(webhooks.router,            prefix=PREFIX)


# ── 健康檢查 ──────────────────────────────────────────────
@app.get("/health", tags=["internal"])
async def health_check():
    return {"status": "ok", "env": settings.app_env, "version": "0.1.0"}


@app.get("/ready", tags=["internal"])
async def readiness_check():
    """Kubernetes readiness probe：確認資料庫與 AI 供應商可達"""
    # 假設：v1 簡化版，只確認 DB 連線
    from app.db.session import async_session_factory
    async with async_session_factory() as session:
        await session.execute("SELECT 1")
    return {"status": "ready"}
```

### 3.4 啟動指令（uv）

```bash
# 安裝依賴（從 repo 根的 backend/ 執行）
cd backend
uv sync

# 開發模式（支援熱重載）
uv run uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload

# 生產模式（多 worker）
uv run uvicorn app.main:app --host 0.0.0.0 --port 8002 --workers 4
```

---

## 4. 依賴注入與請求生命週期

### 4.1 共用 Depends 函式

```python
# app/api/deps.py
from typing import Annotated
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import verify_jwt, TenantContext
from app.db.session import get_db_session
from app.repositories.quota_repository import QuotaRepository

bearer_scheme = HTTPBearer()


async def get_current_context(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
) -> TenantContext:
    """
    驗證 JWT，解析 tenant_id、distributor_id、role。
    失敗一律回 401，不洩露細節。
    """
    return await verify_jwt(credentials.credentials)


async def get_db(
    ctx: Annotated[TenantContext, Depends(get_current_context)],
) -> AsyncSession:
    """
    取得資料庫 session，注入 TenantContext。
    每次交易開始時以 SET LOCAL 注入三個 session 變數：
      - app.current_tenant_id   → RLS policy 租戶隔離條件
      - app.current_distributor → distributor 層級 policy（只看自己）
      - app.current_role        → leader 看全租戶；distributor 看自己
    DB role 必須是非 BYPASSRLS 角色，確保 RLS 實際生效。
    policy 條件範例：
      current_setting('app.current_tenant_id', true)::uuid = tenant_id
      current_setting('app.current_role', true) = 'leader'
        OR current_setting('app.current_distributor', true) = distributor_id::text
    """
    async with get_db_session() as session:
        await session.execute(
            "SET LOCAL app.current_tenant_id = :tid; "
            "SET LOCAL app.current_distributor = :did; "
            "SET LOCAL app.current_role = :role",
            {
                "tid": str(ctx.tenant_id),
                "did": str(ctx.distributor_id),
                "role": ctx.role,
            },
        )
        yield session


# 組合注入型別（路由層直接使用）
CurrentContext = Annotated[TenantContext, Depends(get_current_context)]
DBSession = Annotated[AsyncSession, Depends(get_db)]
```

### 4.2 Service 層注入模式

Service 透過建構子注入 Repository，避免在函式參數中傳遞 session：

```python
# app/services/message_draft_service.py（節錄）
from app.repositories.message_draft_repository import MessageDraftRepository
from app.repositories.compliance_repository import ComplianceRepository
from app.sidecars.compliance_sidecar import ComplianceSidecar
from app.core.auth import TenantContext


class MessageDraftService:
    def __init__(
        self,
        draft_repo: MessageDraftRepository,
        compliance_repo: ComplianceRepository,
        sidecar: ComplianceSidecar,
    ):
        self._draft_repo = draft_repo
        self._compliance_repo = compliance_repo
        self._sidecar = sidecar

    async def stream_draft(self, ctx: TenantContext, req: DraftStreamRequest):
        # 1. 前置情緒、太業務員、合規三道檢查
        # 2. 呼叫 Agent（詳見第 7 章）
        # 3. 寫入 message_drafts
        # 4. 寫入 compliance_checks
        # 5. fire-and-forget 寫入 learning_logs
        ...
```

---

## 5. 認證與授權

### 5.1 自建 JWT 驗證與登入服務

```python
# app/core/auth.py
from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Literal

from fastapi import HTTPException, status
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


@dataclass(frozen=True)
class TenantContext:
    """每次請求攜帶的不可變租戶上下文"""
    tenant_id: str       # 對應 tenants.id（tnt_ 前綴）
    distributor_id: str  # 對應 distributors.id（usr_ 前綴）
    role: Literal["distributor", "leader"]
    email: str


async def verify_jwt(token: str) -> TenantContext:
    """
    驗證自建 JWT（HS256）：
    1. 以 JWT_SECRET 解析並驗簽
    2. 確認 exp 未過期
    3. 從扁平 claims 取出 sub（=distributor_id）、tenant_id、role、email
    失敗一律 401，不區分原因（防止攻擊者推測 token 狀態）
    """
    try:
        payload: dict = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_alg],
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="UNAUTHORIZED"
        )

    if payload.get("exp", 0) < int(time.time()):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="UNAUTHORIZED"
        )

    # 扁平 claims：{sub, tenant_id, role, email, iat, exp}
    return TenantContext(
        tenant_id=payload.get("tenant_id", ""),
        distributor_id=payload["sub"],
        role=payload.get("role", "distributor"),
        email=payload.get("email", ""),
    )


def create_access_token(
    distributor_id: str,
    tenant_id: str,
    role: str,
    email: str,
) -> str:
    """簽發自建 JWT，扁平 claims，TTL = ACCESS_TOKEN_TTL_HOURS。"""
    now = int(time.time())
    payload = {
        "sub": distributor_id,
        "tenant_id": tenant_id,
        "role": role,
        "email": email,
        "iat": now,
        "exp": now + settings.access_token_ttl_hours * 3600,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_alg)


# ── 登入服務（auth_service）──────────────────────────────────

class AuthService:
    """
    POST /api/v1/auth/login 業務邏輯：
    1. 以 email 查詢 distributors.password_hash
    2. passlib[bcrypt] 驗密碼
    3. 驗通後以 create_access_token() 簽發 JWT
    """

    def __init__(self, distributor_repo):
        self._repo = distributor_repo

    async def login(self, email: str, password: str) -> dict:
        distributor = await self._repo.get_by_email(email)
        if distributor is None or not pwd_context.verify(
            password, distributor.password_hash
        ):
            # 不區分「帳號不存在」與「密碼錯誤」，防止帳號枚舉
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="UNAUTHORIZED"
            )
        token = create_access_token(
            distributor_id=distributor.id,
            tenant_id=distributor.tenant_id,
            role=distributor.role,
            email=distributor.email,
        )
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": settings.access_token_ttl_hours * 3600,
        }
```

### 5.2 角色權限矩陣

| 端點 | distributor | leader | 說明 |
|---|---|---|---|
| `GET /api/v1/contacts` | 自己的 | 自己的 | 不得查他人 contact |
| `GET /api/v1/recruitment/funnel` | 個人漏斗 | 個人漏斗 | — |
| `GET /api/v1/recruitment/team-funnel` | 403 | 下線統計 | Leader 專屬 |
| `GET /api/v1/questionnaire-links/{token}` | 無需 JWT | 無需 JWT | 公開端點（見第 11 章）|
| `POST /api/v1/questionnaire-links/{token}/submit` | 無需 JWT | 無需 JWT | 公開端點 |

### 5.3 跨租戶存取防護

所有 Repository 基底類別強制帶 `tenant_id` 篩選。跨租戶存取時回傳 `404 NOT_FOUND`（不回 403，避免暴露資源存在性）：

```python
# app/repositories/base_repository.py（節錄）
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


class BaseRepository:
    def __init__(self, session: AsyncSession, tenant_id: str):
        self._session = session
        self._tenant_id = tenant_id

    async def get_or_404(self, model_cls, record_id: str):
        stmt = (
            select(model_cls)
            .where(model_cls.id == record_id)
            .where(model_cls.tenant_id == self._tenant_id)  # 租戶隔離強制加
        )
        result = await self._session.scalar(stmt)
        if result is None:
            from app.core.errors import NotFoundError
            raise NotFoundError(f"{model_cls.__name__} {record_id} not found")
        return result
```

---

## 6. Repository 模式與資料存取

### 6.1 PostgreSQL RLS 隔離策略

Phase I 採用雙層防護：

1. **PostgreSQL 原生 RLS policy（第二道防線）**：每張表啟用 RLS，每次交易由 `get_db()` Depends 注入三個 session 變數（見 §4.1）：
   - `app.current_tenant_id`：租戶隔離，policy 條件 `current_setting('app.current_tenant_id', true)::uuid = tenant_id`
   - `app.current_distributor`：distributor 自身隔離，`role = distributor` 時只能存取自己的列
   - `app.current_role`：`role = leader` 時可看同租戶全部資料
   後端以非 `BYPASSRLS` 的 DB role 連線，確保 RLS 實際套用。**舊單一變數 `app.current_tenant` 已廢除，全部改三變數。**
2. **Repository 層 `tenant_id` 強制篩選（第一道防線）**：即使測試環境或 Alembic 遷移以高權限 role 連線，Application 層也確保查詢帶 `WHERE tenant_id = :tid`，不洩漏跨租戶資料。

開發環境使用 `pgvector/pgvector:pg16` container（port 5432）；CI 環境 Alembic 遷移以高權限 role 執行，整合測試仍走一般 JWT 驗證路徑（低權限 role）。

### 6.2 pgvector 語意搜尋（T01 活檔案）

`contacts` 資料表的 `contact_embedding` 欄位（`vector(1536)`）供活檔案語意搜尋使用：

```python
# app/repositories/contact_repository.py（節錄）
from pgvector.sqlalchemy import Vector
from sqlalchemy import select, func

class ContactRepository(BaseRepository):
    async def semantic_search(
        self,
        query_embedding: list[float],
        limit: int = 10,
    ) -> list[Contact]:
        stmt = (
            select(Contact)
            .where(Contact.tenant_id == self._tenant_id)
            .where(Contact.is_archived == False)
            .order_by(
                Contact.contact_embedding.cosine_distance(query_embedding)
            )
            .limit(limit)
        )
        result = await self._session.scalars(stmt)
        return list(result)
```

### 6.3 游標分頁實作

所有列表端點使用游標分頁（`cursor` + `limit`），不使用 OFFSET（大資料量時效能差）：

```python
# app/repositories/contact_repository.py（節錄）
async def list_contacts(
    self,
    cursor: str | None = None,
    limit: int = 20,
    q: str | None = None,
) -> tuple[list[Contact], str | None]:
    stmt = (
        select(Contact)
        .where(Contact.tenant_id == self._tenant_id)
        .where(Contact.is_archived == False)
        .order_by(Contact.created_at.desc(), Contact.id)
        .limit(limit + 1)
    )
    if cursor:
        stmt = stmt.where(Contact.id < cursor)
    if q:
        stmt = stmt.where(Contact.display_name.ilike(f"%{q}%"))

    rows = list(await self._session.scalars(stmt))
    has_more = len(rows) > limit
    if has_more:
        rows = rows[:limit]
    next_cursor = rows[-1].id if has_more else None
    return rows, next_cursor
```

### 6.4 Alembic 遷移管理

```bash
# 建立新遷移（資料模型變更後執行）
uv run alembic revision --autogenerate -m "add_contact_embedding_column"

# 執行遷移
uv run alembic upgrade head

# 回滾一步
uv run alembic downgrade -1
```

---

## 7. AI 編排整合介面

> **重要：AI 編排層（LangGraph + 11 個 agent + 模型分配）沿用既有框架（PRD 第 5 章），本次不重新設計。**
> 本章定義後端 Service 層如何與 AI 層對接的整合介面，包含：呼叫方式、輸入輸出契約、SSE 串流、合規與學習紀錄掛載點、成本計量點。

### 7.1 OrchestratorClient 抽象介面

所有 AI 呼叫均透過此抽象介面，避免直接耦合 Anthropic SDK 或 LangGraph。日後切換供應商或升級框架只需替換實作：

```python
# app/agents/base_agent.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import AsyncGenerator


@dataclass(frozen=True)
class AgentInput:
    """AI agent 統一輸入"""
    tool_id: str                 # T01~T11、SYS
    model_hint: str              # "haiku" | "sonnet"（由 agent 決定最終路由）
    prompt_context: dict         # 結構化 context（活檔案摘要、近期互動等）
    tenant_id: str
    distributor_id: str
    trace_id: str                # Langfuse trace ID（由 service 層產生）


@dataclass
class AgentOutput:
    """AI agent 統一輸出"""
    content: str
    model_used: str              # 實際使用的模型 ID
    input_tokens: int
    output_tokens: int
    cost_usd: float              # 本次呼叫成本（USD）
    latency_ms: int


class OrchestratorClient(ABC):
    """
    AI 編排層抽象介面。
    實作類別：LangGraphOrchestratorClient（沿用既有框架，本次不重新設計）
    測試替換類別：MockOrchestratorClient
    """

    @abstractmethod
    async def invoke(self, agent_input: AgentInput) -> AgentOutput:
        """同步呼叫（等待完整輸出）"""
        ...

    @abstractmethod
    async def stream(
        self, agent_input: AgentInput
    ) -> AsyncGenerator[str, None]:
        """
        串流呼叫（token-by-token）。
        呼叫方負責在最後一個 token 後收集 final_output（透過 get_last_output()）。
        """
        ...

    @abstractmethod
    def get_last_output(self) -> AgentOutput:
        """stream() 完成後取得完整 metadata（token 數、成本、模型）"""
        ...
```

### 7.2 工具與模型路由對照

| 工具 | service 呼叫的 model_hint | 實際模型（框架決定） | 備註 |
|---|---|---|---|
| T01 insight 生成 | `sonnet` | claude-sonnet-4-6 | embedding 另用 text-embedding-3-small |
| T02 事件抽取（文字型） | `haiku` | claude-haiku-4-5 | 日期型純規則，不呼叫 AI |
| T03 情緒感測 | `haiku` | claude-haiku-4-5 | 三檔分類 |
| T04 太業務員警報 | 不呼叫 AI | 純規則引擎 | 產品關鍵字 + URL pattern |
| T05 今日 5 件事 | 不呼叫 AI | 純規則 | v1 無 AI 排序 |
| T06 首字 | `haiku` | claude-haiku-4-5 | SSE first_token |
| T06 全文 | `sonnet` | claude-sonnet-4-6 | SSE 全文 streaming |
| T07 跟進草稿 | `haiku` | claude-haiku-4-5 | 樣品跟進訊息 |
| T08 語音（TTS） | 不呼叫 AI | VoiceProvider（見第 12 章）| 非 Anthropic |
| T09 異議處理 | `haiku` | claude-haiku-4-5 | 速度優先 |
| T10 問卷摘要 | `sonnet` | claude-sonnet-4-6 | 過合規再給直銷商 |
| T11 招募話術 | `sonnet` | claude-sonnet-4-6 | 最嚴格合規（FTC） |

### 7.3 SSE 串流生成器（T06 訊息草稿）

```python
# app/api/message_drafts.py（SSE 端點）
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from app.api.deps import CurrentContext, DBSession
from app.services.message_draft_service import MessageDraftService
import json

router = APIRouter(tags=["T06 訊息草稿"])


@router.post("/message-drafts/stream")
async def stream_message_draft(
    req: DraftStreamRequest,
    ctx: CurrentContext,
    session: DBSession,
):
    service = MessageDraftService.from_session(session, ctx)

    async def event_generator():
        async for event_type, data in service.stream_draft(ctx, req):
            payload = json.dumps(data, ensure_ascii=False)
            yield f"event: {event_type}\ndata: {payload}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # Nginx 關閉緩衝
        },
    )
```

```python
# app/services/message_draft_service.py（stream_draft 核心邏輯）
from typing import AsyncGenerator
import time
import uuid

from app.agents.base_agent import OrchestratorClient, AgentInput
from app.sidecars.compliance_sidecar import ComplianceSidecar
from app.core.auth import TenantContext


class MessageDraftService:
    async def stream_draft(
        self,
        ctx: TenantContext,
        req: DraftStreamRequest,
    ) -> AsyncGenerator[tuple[str, dict], None]:
        """
        SSE 事件流程：
        first_token → token(×N) → compliance_result → done
        紅燈時：改為 compliance_blocked
        """
        trace_id = str(uuid.uuid4())
        t_start = time.monotonic()

        # ── 前置合規檢查（context 摘要）────────────────
        pre_check = await self._sidecar.check(req.context_summary)
        await self._compliance_repo.save(pre_check, ctx, source_type="message_draft")

        if pre_check.status == "red":
            yield "compliance_blocked", {
                "status": "red",
                "check_id": pre_check.id,
                "triggered_terms": pre_check.triggered_terms,
                "suggestion": pre_check.suggestion,
            }
            return

        # ── Haiku 首字（< 500ms 目標）──────────────────
        haiku_input = AgentInput(
            tool_id="T06",
            model_hint="haiku",
            prompt_context=req.dict(),
            tenant_id=ctx.tenant_id,
            distributor_id=ctx.distributor_id,
            trace_id=trace_id,
        )
        first_token = await self._orchestrator.get_first_token(haiku_input)
        yield "first_token", {"token": first_token}

        # ── Sonnet 全文串流 ─────────────────────────────
        full_content = ""
        sonnet_input = AgentInput(
            tool_id="T06",
            model_hint="sonnet",
            prompt_context={**req.dict(), "first_token": first_token},
            tenant_id=ctx.tenant_id,
            distributor_id=ctx.distributor_id,
            trace_id=trace_id,
        )
        async for token in self._orchestrator.stream(sonnet_input):
            full_content += token
            yield "token", {"token": token}

        final_output = self._orchestrator.get_last_output()

        # ── 草稿全文合規掃描 ────────────────────────────
        post_check = await self._sidecar.check(full_content)
        await self._compliance_repo.save(post_check, ctx, source_type="message_draft")

        # ── 成本計量：更新 usage_quotas ─────────────────
        await self._quota_service.add_cost(
            ctx, final_output.cost_usd, quota_type="draft"
        )

        # ── 持久化草稿 ──────────────────────────────────
        draft = await self._draft_repo.create({
            "contact_id": req.contact_id,
            "distributor_id": ctx.distributor_id,
            "tenant_id": ctx.tenant_id,
            "tone": req.tone,
            "channel": req.channel,
            "content": full_content,
            "prompt_context": req.context_summary,
            "compliance_status": post_check.status,
            "compliance_check_id": post_check.id,
            "model_used": final_output.model_used,
            "latency_ms": int((time.monotonic() - t_start) * 1000),
        })

        yield "compliance_result", {
            "status": post_check.status,
            "check_id": post_check.id,
            "triggered_terms": post_check.triggered_terms,
        }

        yield "done", {
            "draft_id": draft.id,
            "tone": req.tone,
            "model_used": final_output.model_used,
            "latency_ms": draft.latency_ms,
        }

        # ── fire-and-forget 學習紀錄 ────────────────────
        import asyncio
        asyncio.create_task(
            self._learning_log_service.record(
                ctx=ctx,
                event_type="draft_generated",
                source_type="message_draft",
                source_id=draft.id,
                metadata={
                    "model_used": final_output.model_used,
                    "latency_ms": draft.latency_ms,
                    "cost_usd": final_output.cost_usd,
                    "compliance_status": post_check.status,
                    "tone": req.tone,
                },
            )
        )
```

### 7.4 成本計量與每日 $0.30 熔斷

```python
# app/services/quota_service.py
from app.repositories.quota_repository import QuotaRepository
from app.core.config import settings
from app.core.errors import CostLimitReachedError


class QuotaService:
    def __init__(self, repo: QuotaRepository):
        self._repo = repo

    async def add_cost(
        self,
        ctx,
        cost_usd: float,
        quota_type: str,  # "draft" | "voice" | "emotion" | "objection" 等
    ) -> None:
        """
        每次 AI 呼叫完成後同步更新成本。
        超過 cost_limit_usd 時拋出 CostLimitReachedError（→ 429）。
        """
        quota = await self._repo.get_or_create_today(
            ctx.tenant_id, ctx.distributor_id
        )
        new_cost = float(quota.ai_cost_usd_today) + cost_usd
        if new_cost > float(quota.cost_limit_usd):
            raise CostLimitReachedError(
                distributor_id=ctx.distributor_id,
                used=new_cost,
                limit=float(quota.cost_limit_usd),
            )
        await self._repo.increment_cost(
            quota.id, cost_usd, quota_type
        )

    async def check_draft_quota(self, ctx) -> None:
        """草稿生成前呼叫：超出每日上限則 429"""
        quota = await self._repo.get_or_create_today(
            ctx.tenant_id, ctx.distributor_id
        )
        if quota.drafts_used_today >= quota.drafts_limit:
            from app.core.errors import QuotaExceededError
            raise QuotaExceededError(
                quota_type="drafts",
                limit=quota.drafts_limit,
                used=quota.drafts_used_today,
            )

    async def check_voice_quota(self, ctx) -> None:
        """語音生成前呼叫：超出每日上限則 429"""
        quota = await self._repo.get_or_create_today(
            ctx.tenant_id, ctx.distributor_id
        )
        if quota.voice_used_today >= quota.voice_limit:
            from app.core.errors import QuotaExceededError
            raise QuotaExceededError(
                quota_type="voice",
                limit=quota.voice_limit,
                used=quota.voice_used_today,
            )
```

---

## 8. 合規 Sidecar（regex < 50ms）

> SYS 合規低語：所有外送草稿類型必過的 gate。

### 8.1 合規 Gate 流程

```mermaid
graph TD
    A[草稿文字] --> B{ComplianceSidecar check}
    B --> |green| C[直接放行]
    B --> |yellow| D[顯示警告<br/>直銷商可繼續確認]
    B --> |red| E[阻擋<br/>送出按鈕 disabled]
    E --> F[直銷商改寫]
    F --> B
    C --> G[寫入 compliance_checks]
    D --> G
    G --> H[主流程繼續]
```

### 8.2 ComplianceSidecar 實作

```python
# app/sidecars/compliance_sidecar.py
import re
import time
from dataclasses import dataclass, field
from typing import Literal
import uuid

# 合規燈號型別
ComplianceStatus = Literal["green", "yellow", "red"]

# 高風險詞庫（v1 約 50 個，從 compliance_lexicon 表載入）
# 假設：啟動時從 DB 載入並快取，避免每次查表（快取 TTL = 5 分鐘）


@dataclass
class ComplianceCheckResult:
    id: str
    status: ComplianceStatus
    triggered_terms: list[str]
    suggestion: str
    latency_ms: int
    input_text: str


class ComplianceSidecar:
    """
    regex sidecar：純規則，無 AI，目標 < 50ms。
    所有外送草稿類型（message_draft / sample_followup / voice_clip /
    objection_response / questionnaire_summary / recruitment_draft）均須通過。
    """

    def __init__(self, lexicon: list[dict]):
        """
        lexicon: 從 compliance_lexicon 表載入的詞庫
        每項包含 {term, risk_level, suggestion}
        """
        self._red_patterns: list[tuple[re.Pattern, str]] = []
        self._yellow_patterns: list[tuple[re.Pattern, str]] = []
        self._suggestions: dict[str, str] = {}

        for item in lexicon:
            pattern = re.compile(item["term"], re.IGNORECASE | re.UNICODE)
            suggestion = item.get("suggestion", "請修改相關表達")
            if item["risk_level"] == "red":
                self._red_patterns.append((pattern, item["term"]))
            elif item["risk_level"] == "yellow":
                self._yellow_patterns.append((pattern, item["term"]))
            self._suggestions[item["term"]] = suggestion

    def check(self, text: str) -> ComplianceCheckResult:
        """
        同步執行（非 async）— 純 CPU 操作，< 50ms。
        由 service 層以 asyncio.to_thread() 包裝若需要非阻塞。
        """
        t_start = time.perf_counter()
        triggered_red: list[str] = []
        triggered_yellow: list[str] = []

        for pattern, term in self._red_patterns:
            if pattern.search(text):
                triggered_red.append(term)

        for pattern, term in self._yellow_patterns:
            if pattern.search(term):
                triggered_yellow.append(term)

        latency_ms = int((time.perf_counter() - t_start) * 1000)

        if triggered_red:
            status: ComplianceStatus = "red"
            triggered = triggered_red
        elif triggered_yellow:
            status = "yellow"
            triggered = triggered_yellow
        else:
            status = "green"
            triggered = []

        suggestion = ""
        if triggered:
            suggestion = self._suggestions.get(triggered[0], "請修改相關表達")

        return ComplianceCheckResult(
            id=f"cck_{uuid.uuid4().hex[:8]}",
            status=status,
            triggered_terms=triggered,
            suggestion=suggestion,
            latency_ms=latency_ms,
            input_text=text,
        )
```

### 8.3 合規 Gate 在 Service 層的掛載方式

所有外送草稿類型 service 均需於草稿生成後、資料持久化前呼叫 sidecar，並**無論燈號如何，100% 寫入 `compliance_checks`**：

```python
# 以 recruitment_service.py 為例（最嚴格合規：FTC 收入保證）
async def generate_recruitment_draft(self, ctx, req):
    # 1. 生成草稿（Sonnet 4.6）
    output = await self._orchestrator.invoke(agent_input)

    # 2. 合規掃描（必做，不可跳過）
    check_result = self._sidecar.check(output.content)

    # 3. 100% 寫入 compliance_checks
    await self._compliance_repo.save_check({
        "distributor_id": ctx.distributor_id,
        "tenant_id": ctx.tenant_id,
        "source_type": "recruitment_draft",
        "source_id": None,        # 尚未持久化，先存 null，持久化後更新
        "input_text": output.content,
        "result": check_result.status,
        "triggered_terms": check_result.triggered_terms,
        "suggestion": check_result.suggestion,
        "latency_ms": check_result.latency_ms,
    })

    # 4. 紅燈：直接回傳錯誤，不持久化草稿
    if check_result.status == "red":
        from app.core.errors import ComplianceRedBlockedError
        raise ComplianceRedBlockedError(
            triggered_terms=check_result.triggered_terms,
            suggestion=check_result.suggestion,
        )

    # 5. 持久化草稿（此時才有 draft_id）
    draft = await self._draft_repo.create({...})

    # 6. 更新 compliance_checks 的 source_id
    await self._compliance_repo.update_source_id(
        check_result.id, draft.id
    )
    return draft
```

### 8.4 合規詞庫熱更新

詞庫變更（法務 review 後）無需重啟服務：

```python
# app/sidecars/compliance_sidecar.py（補充）
import asyncio

async def reload_lexicon(self, new_lexicon: list[dict]) -> None:
    """
    熱更新詞庫（由管理端 API 觸發）。
    更新期間使用 asyncio.Lock 避免並發問題。
    """
    async with self._reload_lock:
        self.__init__(new_lexicon)
```

---

## 9. 學習紀錄掛載機制

> 所有 AI 操作完成後非同步寫入 `learning_logs`，不阻塞主流程。

### 9.1 設計原則

- **fire-and-forget**：使用 `asyncio.create_task()` 提交，主流程不等待
- **失敗不影響主流程**：`learning_log_service.record()` 內部 try/except 全捕捉，失敗時 Sentry 告警
- **覆蓋範圍**：依契約 G.4，涵蓋 10 種事件類型（`emotion_read` / `draft_generated` / `draft_adopted` / `draft_rejected` / `salesy_alert_dismissed` / `salesy_alert_acknowledged` / `objection_used` / `compliance_triggered` / `compliance_overridden` / `voice_downloaded`）

### 9.2 LearningLogService 實作

```python
# app/services/learning_log_service.py
import asyncio
import logging

from app.repositories.learning_log_repository import LearningLogRepository
from app.core.auth import TenantContext
from app.core.observability import sentry_capture

logger = logging.getLogger(__name__)

# 學習紀錄事件類型（對應契約 H.11）
LEARNING_EVENT_TYPES = {
    "emotion_read", "draft_generated", "draft_adopted", "draft_rejected",
    "salesy_alert_dismissed", "salesy_alert_acknowledged", "objection_used",
    "compliance_triggered", "compliance_overridden", "voice_downloaded",
}


class LearningLogService:
    def __init__(self, repo: LearningLogRepository):
        self._repo = repo

    async def record(
        self,
        ctx: TenantContext,
        event_type: str,
        source_type: str,
        source_id: str | None,
        metadata: dict,
    ) -> None:
        """
        非同步寫入學習紀錄。
        此方法應包在 asyncio.create_task() 中呼叫，確保 fire-and-forget。
        """
        if event_type not in LEARNING_EVENT_TYPES:
            logger.warning(f"未知學習紀錄事件類型: {event_type}")
            return

        try:
            await self._repo.create({
                "distributor_id": ctx.distributor_id,
                "tenant_id": ctx.tenant_id,
                "event_type": event_type,
                "source_type": source_type,
                "source_id": source_id,
                "metadata": metadata,
            })
        except Exception as e:
            # 學習紀錄失敗不能讓主流程掛掉，但要告警
            logger.error(f"學習紀錄寫入失敗: {e}", exc_info=True)
            sentry_capture(e, extra={"event_type": event_type, "ctx": ctx})


def fire_and_forget_log(
    service: LearningLogService,
    ctx: TenantContext,
    event_type: str,
    source_type: str,
    source_id: str | None,
    metadata: dict,
) -> asyncio.Task:
    """
    工具函式：在 Service 層任何需要的位置呼叫，一行完成 fire-and-forget。
    回傳 Task 供測試斷言使用（通常忽略）。
    """
    return asyncio.create_task(
        service.record(ctx, event_type, source_type, source_id, metadata)
    )
```

### 9.3 各工具掛載點清單

| 工具 | 觸發時機 | event_type |
|---|---|---|
| T03 情緒感測 | `emotion_service.detect()` 完成後 | `emotion_read` |
| T06 訊息草稿生成 | `message_draft_service.stream_draft()` 完成後 | `draft_generated` |
| T06 草稿採用 | `POST /message-drafts/{draft_id}/adopt` | `draft_adopted` |
| T06 草稿未採用 | 後台 job：距生成 30 分鐘未 adopt | `draft_rejected` |
| T04 警報關掉 | `POST /salesy-alerts/{id}/dismiss` | `salesy_alert_dismissed` |
| T04 警報確認 | `POST /salesy-alerts/{id}/acknowledge` | `salesy_alert_acknowledged` |
| T09 異議採用 | `POST /objection-responses/{id}/adopt` | `objection_used` |
| SYS 合規觸發 | sidecar 回傳 yellow/red 時 | `compliance_triggered` |
| SYS 合規覆蓋 | 直銷商強制覆蓋黃燈時 | `compliance_overridden` |
| T08 語音下載 | `POST /voice-clips/{id}/download` | `voice_downloaded` |

---

## 10. 排程器

### 10.1 APScheduler vs Cloud Scheduler 取捨

| 方案 | 優點 | 缺點 | 建議 |
|---|---|---|---|
| APScheduler（FastAPI 內） | 與應用同部署、可存取 Service 層邏輯、Python 生態整合好 | 多副本時需分散式鎖（同一任務跑多次）| **Phase I 採用**（單副本，簡單可控）|
| GCP Cloud Scheduler + Cloud Run Job | 無多副本問題、部署獨立、GCP 原生整合 | 複雜業務邏輯需額外 Cloud Run Job | Phase II 遷移候選（規模化後）|

Phase I 單副本 Cloud Run 部署，不需分散式鎖。若未來橫向擴展，需在 APScheduler 任務前加 Redis 分散式鎖或改用 Cloud Scheduler。

### 10.2 排程任務清單

```python
# app/infra/scheduler.py
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

scheduler = AsyncIOScheduler(timezone="Asia/Taipei")


async def start_scheduler():
    scheduler.add_job(
        job_generate_today_tasks,
        CronTrigger(hour=6, minute=0),     # 每日凌晨 06:00 台北時間
        id="generate_today_tasks",
        replace_existing=True,
    )
    scheduler.add_job(
        job_check_sample_followups,
        IntervalTrigger(minutes=30),       # 每 30 分鐘掃描一次待跟進樣品
        id="check_sample_followups",
        replace_existing=True,
    )
    scheduler.add_job(
        job_detect_dormant_contacts,
        CronTrigger(hour=7, minute=0),     # 每日凌晨 07:00 偵測 30 天沉睡
        id="detect_dormant_contacts",
        replace_existing=True,
    )
    scheduler.add_job(
        job_mark_draft_rejected,
        IntervalTrigger(minutes=60),       # 每小時：距生成 30 分鐘未 adopt 的草稿
        id="mark_draft_rejected",
        replace_existing=True,
    )
    # GCS Object Lifecycle 已設定 7 天 TTL 自動刪除語音物件，
    # 此 job 為可選 fallback（同步清理 DB voice_clips 過期記錄）。
    scheduler.add_job(
        job_expire_voice_clips,
        CronTrigger(hour=3, minute=0),     # 每日凌晨 03:00 清理 DB 過期記錄（GCS 物件由 Lifecycle 主控）
        id="expire_voice_clips",
        replace_existing=True,
    )
    scheduler.start()


async def shutdown_scheduler():
    scheduler.shutdown()
```

### 10.3 各任務說明

#### job_generate_today_tasks — 今日 5 件事生成

```python
async def job_generate_today_tasks():
    """
    每日 06:00 為每位活躍直銷商生成今日 5 件任務卡。
    優先序（依契約 H.10）：
    1. life_event（生活事件雷達，生日前 7 天等）
    2. sample_followup（樣品 48h / 72h / 7d 到期）
    3. dormant（30 天無互動）
    4. recruitment（招募階段推進機會）
    5. salesy_alert（太業務員警報補關懷）
    """
    async for distributor in active_distributor_iter():
        ctx = build_system_context(distributor)
        await today_task_service.generate_daily_tasks(ctx)
```

#### job_check_sample_followups — 樣品跟進提醒

```python
async def job_check_sample_followups():
    """
    每 30 分鐘掃描 sample_followups 表，
    找出 status='pending' 且 followup_at <= now() 的記錄，
    更新 today_tasks 並寫入 notified_at。
    跟進類型：h48（48 小時）/ h72（72 小時）/ d7（7 天）
    """
    due = await sample_followup_repo.get_due_followups()
    for followup in due:
        await today_task_service.add_followup_task(followup)
        await sample_followup_repo.mark_notified(followup.id)
```

#### job_detect_dormant_contacts — 沉睡偵測

```python
async def job_detect_dormant_contacts():
    """
    每日 07:00 偵測 last_interaction_at < now() - 30 days 的聯絡人，
    更新 contacts.dormant_since，並為對應直銷商加入今日任務卡。
    """
    threshold = datetime.utcnow() - timedelta(days=30)
    await contact_repo.update_dormant_contacts(threshold)
```

---

## 11. 問卷公開端點安全

> T10 健康問卷：客戶無需登入，使用一次性 token，7 天有效。

### 11.1 安全設計

```mermaid
sequenceDiagram
    participant D as 直銷商
    participant API as FastAPI
    participant DB as PostgreSQL
    participant C as 客戶

    D->>API: POST /contacts/{id}/questionnaire-links（JWT）
    API->>DB: 建立 questionnaire_links（token=uuid4, expires_at=now+7d）
    API-->>D: {link_url: "https://app.cc.ai/q/{token}"}

    C->>API: GET /questionnaire-links/{token}（無 JWT）
    API->>DB: 查詢 token，確認 is_active=true AND expires_at>now
    DB-->>API: questionnaire_templates（題目）
    API-->>C: 題目 JSON

    C->>API: POST /questionnaire-links/{token}/submit（無 JWT）
    API->>DB: 寫入 questionnaire_responses，標記 filled_at
    API->>DB: UPDATE questionnaire_links SET is_active=false（單次使用）
    API-->>C: {status: "submitted"}
```

### 11.2 Token 安全措施

| 威脅 | 防護機制 |
|---|---|
| Token 猜測（枚舉攻擊） | Token 使用 `secrets.token_urlsafe(32)`（256 bits），暴力猜測不可行 |
| 重複提交 | 提交後立即設 `is_active=false`，重複提交回 `410 QUESTIONNAIRE_LINK_USED` |
| 過期 token | `expires_at < now()` 回 `410 QUESTIONNAIRE_LINK_EXPIRED` |
| 速率限制（防爬） | 公開端點加 IP 速率限制：同 IP 每分鐘最多 10 次 GET、3 次 POST |
| 個資保護 | 公開端點回應不包含直銷商個資（僅題目 JSON）|

```python
# app/api/questionnaire.py（公開端點）
from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

router = APIRouter(tags=["T10 健康問卷"])
limiter = Limiter(key_func=get_remote_address)


@router.get("/questionnaire-links/{token}")
@limiter.limit("10/minute")
async def get_questionnaire(token: str, request: Request):
    """
    公開端點：無需 JWT。
    回傳問卷題目，不洩漏任何直銷商或客戶資訊。
    """
    link = await questionnaire_repo.get_link_by_token(token)
    if not link:
        raise HTTPException(status_code=410, detail="QUESTIONNAIRE_LINK_EXPIRED")
    if not link.is_active:
        raise HTTPException(status_code=410, detail="QUESTIONNAIRE_LINK_USED")
    template = await questionnaire_repo.get_template(link.template_id)
    return {"questions": template.questions}


@router.post("/questionnaire-links/{token}/submit")
@limiter.limit("3/minute")
async def submit_questionnaire(
    token: str,
    body: QuestionnaireSubmitRequest,
    request: Request,
):
    """
    公開端點：無需 JWT。
    提交後立即設 is_active=false，防止重複提交。
    觸發 Sonnet 4.6 摘要生成（後台任務，不阻塞回應）。
    """
    link = await questionnaire_repo.get_link_by_token(token)
    if not link:
        raise HTTPException(status_code=410, detail="QUESTIONNAIRE_LINK_EXPIRED")
    if not link.is_active:
        raise HTTPException(status_code=410, detail="QUESTIONNAIRE_LINK_USED")

    # 寫入回覆
    response = await questionnaire_repo.create_response(link, body.answers)
    # 標記單次使用
    await questionnaire_repo.deactivate_link(link.id)
    # 背景生成 AI 摘要（非同步，不阻塞客戶端）
    asyncio.create_task(
        questionnaire_service.generate_summary(response.id)
    )
    return {"status": "submitted", "response_id": response.id}
```

---

## 12. 語音 TTS 抽象層

> T08 語音草稿：供應商未定（OpenAI vs ElevenLabs），介面需抽象化。

### 12.1 VoiceProvider 抽象介面

```python
# app/infra/voice_provider.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Literal


VoiceStyle = Literal["warm_female", "neutral_male"]
VoiceLanguage = Literal["zh-TW", "en-US"]


@dataclass
class VoiceGenerationResult:
    audio_bytes: bytes
    duration_seconds: int
    cost_usd: float
    provider: str


class VoiceProvider(ABC):
    """
    TTS 供應商抽象介面。
    v1 預設 OpenAI，W4 前完成供應商選型後可無縫切換至 ElevenLabs。
    """

    @abstractmethod
    async def generate(
        self,
        text: str,
        voice_style: VoiceStyle,
        language: VoiceLanguage,
    ) -> VoiceGenerationResult:
        """
        生成語音。
        text 字數限制：由 service 層在呼叫前確認 ≤ 60 秒等效字數。
        假設：中文每秒約 4–5 字，60 秒約 240–300 字。
        """
        ...


class OpenAIVoiceProvider(VoiceProvider):
    """沿用既有框架，本次不重新設計實作細節。"""

    _VOICE_MAP = {
        ("warm_female", "zh-TW"): "nova",
        ("neutral_male", "zh-TW"): "echo",
        ("warm_female", "en-US"): "shimmer",
        ("neutral_male", "en-US"): "echo",
    }

    async def generate(self, text, voice_style, language) -> VoiceGenerationResult:
        # 呼叫 OpenAI TTS API（沿用既有框架）
        ...


class ElevenLabsVoiceProvider(VoiceProvider):
    """備用供應商，W4 選型後啟用。"""
    async def generate(self, text, voice_style, language) -> VoiceGenerationResult:
        # 呼叫 ElevenLabs API（沿用既有框架）
        ...


def get_voice_provider() -> VoiceProvider:
    """由設定決定供應商，DI 注入點。"""
    from app.core.config import settings
    if settings.voice_provider == "elevenlabs":
        return ElevenLabsVoiceProvider()
    return OpenAIVoiceProvider()
```

### 12.2 GCS 語音儲存（app/infra/storage.py）

```python
# app/infra/storage.py
from __future__ import annotations

import asyncio
import uuid
from datetime import timedelta

from google.cloud import storage as gcs

from app.core.config import settings


def _get_gcs_client() -> gcs.Client:
    """取得 GCS client；Prod 使用 Workload Identity，Dev 使用 GOOGLE_APPLICATION_CREDENTIALS。"""
    return gcs.Client()


async def upload_voice_clip(audio_bytes: bytes, tenant_id: str) -> str:
    """
    上傳語音 mp3 至 GCS，回傳物件路徑（gs://bucket/...）。
    實際 I/O 在 thread pool 執行，不阻塞 event loop。
    """
    object_name = f"voice/{tenant_id}/{uuid.uuid4().hex}.mp3"

    def _upload():
        client = _get_gcs_client()
        bucket = client.bucket(settings.gcs_bucket)
        blob = bucket.blob(object_name)
        blob.upload_from_string(audio_bytes, content_type="audio/mpeg")

    await asyncio.to_thread(_upload)
    return f"gs://{settings.gcs_bucket}/{object_name}"


async def generate_signed_url(object_path: str, expiry_minutes: int = 60) -> str:
    """
    產生 V4 Signed URL 供前端直接下載語音（TTL 預設 60 分鐘）。
    object_path 格式：gs://bucket/voice/tenant_id/xxx.mp3
    GCS Object Lifecycle 設定 7 天後自動刪除物件，DB 記錄由 job_expire_voice_clips 清理。
    """
    # 解析 gs:// URI
    without_prefix = object_path.removeprefix("gs://")
    bucket_name, _, blob_name = without_prefix.partition("/")

    def _sign():
        client = _get_gcs_client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        return blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=expiry_minutes),
            method="GET",
        )

    return await asyncio.to_thread(_sign)
```

### 12.3 VoiceService 配額檢查與儲存

```python
# app/services/voice_service.py（節錄）
class VoiceService:
    MAX_DURATION_SECONDS = 60
    # 假設：中文約 4.5 字/秒，英文約 2.5 字/秒（保守估計）
    MAX_CHARS_ZH = 270
    MAX_CHARS_EN = 150

    async def generate_clip(self, ctx, req: VoiceClipCreateRequest):
        # 1. 配額檢查
        await self._quota_service.check_voice_quota(ctx)

        # 2. 字數限制（防止超過 60 秒）
        max_chars = (
            self.MAX_CHARS_ZH if req.language == "zh-TW"
            else self.MAX_CHARS_EN
        )
        if len(req.text) > max_chars:
            from app.core.errors import VoiceDurationExceededError
            raise VoiceDurationExceededError(
                char_count=len(req.text), max_chars=max_chars
            )

        # 3. 合規掃描（語音腳本必過）
        check = self._sidecar.check(req.text)
        await self._compliance_repo.save_check({
            **check.__dict__,
            "source_type": "voice_clip",
            "distributor_id": ctx.distributor_id,
            "tenant_id": ctx.tenant_id,
        })
        if check.status == "red":
            from app.core.errors import ComplianceRedBlockedError
            raise ComplianceRedBlockedError(
                triggered_terms=check.triggered_terms,
                suggestion=check.suggestion,
            )

        # 4. 生成語音
        result = await self._voice_provider.generate(
            req.text, req.voice_style, req.language
        )

        # 5. 上傳至 GCS，回傳物件路徑（gs://bucket/path/to/file.mp3）
        storage_url = await self._upload_voice_clip(result.audio_bytes, ctx)

        # 6. 持久化記錄
        clip = await self._voice_repo.create({
            "draft_id": req.draft_id,
            "distributor_id": ctx.distributor_id,
            "tenant_id": ctx.tenant_id,
            "voice_style": req.voice_style,
            "language": req.language,
            "duration_seconds": result.duration_seconds,
            "storage_url": storage_url,
            "provider": result.provider,
            "cost_usd": result.cost_usd,
            "expires_at": datetime.utcnow() + timedelta(days=7),
        })

        # 7. 成本計量
        await self._quota_service.add_cost(ctx, result.cost_usd, "voice")

        return clip
```

---

## 13. 錯誤處理與輸入驗證

### 13.1 錯誤碼定義

```python
# app/core/errors.py
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse


class CareCopilotError(Exception):
    """應用層基底例外"""
    error_code: str = "INTERNAL_ERROR"
    http_status: int = 500


class UnauthorizedError(CareCopilotError):
    error_code = "UNAUTHORIZED"
    http_status = 401


class ForbiddenError(CareCopilotError):
    error_code = "FORBIDDEN"
    http_status = 403


class NotFoundError(CareCopilotError):
    error_code = "NOT_FOUND"
    http_status = 404


class QuotaExceededError(CareCopilotError):
    """草稿/語音/聯絡人配額超限"""
    error_code = "QUOTA_EXCEEDED"
    http_status = 429

    def __init__(self, quota_type: str, limit: int, used: int):
        self.quota_type = quota_type
        self.limit = limit
        self.used = used
        self.upgrade_url = "/subscription/upgrade"


class CostLimitReachedError(CareCopilotError):
    """AI 成本日上限熔斷"""
    error_code = "COST_LIMIT_REACHED"
    http_status = 429


class ComplianceRedBlockedError(CareCopilotError):
    """合規紅燈強制阻擋"""
    error_code = "COMPLIANCE_RED_BLOCKED"
    http_status = 422

    def __init__(self, triggered_terms: list[str], suggestion: str):
        self.triggered_terms = triggered_terms
        self.suggestion = suggestion


class QuestionnaireLinkExpiredError(CareCopilotError):
    error_code = "QUESTIONNAIRE_LINK_EXPIRED"
    http_status = 410


class QuestionnaireLinkUsedError(CareCopilotError):
    error_code = "QUESTIONNAIRE_LINK_USED"
    http_status = 410


class VoiceDurationExceededError(CareCopilotError):
    error_code = "VOICE_DURATION_EXCEEDED"
    http_status = 422


class LineSignatureInvalidError(CareCopilotError):
    """LINE webhook HMAC 驗簽失敗"""
    error_code = "LINE_SIGNATURE_INVALID"
    http_status = 401


class LinePushFailedError(CareCopilotError):
    """LINE push_message API 呼叫失敗"""
    error_code = "LINE_PUSH_FAILED"
    http_status = 502


def register_exception_handlers(app):
    @app.exception_handler(CareCopilotError)
    async def care_copilot_error_handler(
        request: Request, exc: CareCopilotError
    ) -> JSONResponse:
        details = {}
        if isinstance(exc, QuotaExceededError):
            details = {
                "quota_type": exc.quota_type,
                "limit": exc.limit,
                "used": exc.used,
                "upgrade_url": exc.upgrade_url,
            }
        elif isinstance(exc, ComplianceRedBlockedError):
            details = {
                "triggered_terms": exc.triggered_terms,
                "suggestion": exc.suggestion,
            }
        return JSONResponse(
            status_code=exc.http_status,
            content={
                "error": {
                    "code": exc.error_code,
                    "message": str(exc),
                    "details": details,
                }
            },
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        from app.core.observability import sentry_capture
        sentry_capture(exc)
        return JSONResponse(
            status_code=500,
            content={"error": {"code": "INTERNAL_ERROR", "message": "伺服器內部錯誤"}},
        )
```

### 13.2 Pydantic 請求驗證範例

```python
# app/schemas/message_draft.py
from pydantic import BaseModel, Field, field_validator
from typing import Literal
import uuid


class DraftStreamRequest(BaseModel):
    contact_id: str = Field(..., pattern=r"^ctc_[a-f0-9]+$")
    tone: Literal["care", "casual", "business"] = "care"
    channel: Literal["line", "whatsapp", "ig_dm", "email"] = "line"
    context_summary: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="直銷商提供的對話背景（不可空白）",
    )

    @field_validator("contact_id")
    @classmethod
    def validate_contact_id(cls, v: str) -> str:
        if not v.startswith("ctc_"):
            raise ValueError("contact_id 必須以 ctc_ 開頭")
        return v
```

---

## 14. 可觀測性掛載點

### 14.1 三層可觀測性架構

```
┌─────────────────────────────────────────────────────────────┐
│  OpenTelemetry（標準協定）                                    │
│  - 所有 API 請求：spans（request_id, tenant_id, latency）   │
│  - 資料庫查詢：SQLAlchemy instrumentation                    │
│  - 外部 API 呼叫：Anthropic / OpenAI / ElevenLabs            │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Langfuse（AI 專屬 trace）                                   │
│  - 所有 AI 呼叫：model、input_tokens、output_tokens、cost   │
│  - 每次呼叫關聯 trace_id（從 service 層傳入 AgentInput）     │
│  - 草稿採用率、情緒感測準確率追蹤                           │
│  - 每日成本 dashboard + 超限告警（Slack webhook）            │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Sentry（錯誤聚合）                                          │
│  - 後端非預期例外（500 系列）                                │
│  - 學習紀錄寫入失敗告警                                      │
│  - 合規掃描逾時告警（> 50ms）                                │
└─────────────────────────────────────────────────────────────┘
```

### 14.2 初始化

```python
# app/core/observability.py
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from langfuse import Langfuse

from app.core.config import settings

_langfuse: Langfuse | None = None


def init_observability():
    # ── Sentry ────────────────────────────────────────────
    if settings.sentry_dsn:
        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            integrations=[FastApiIntegration(), SqlalchemyIntegration()],
            environment=settings.app_env,
            traces_sample_rate=0.1,
        )

    # ── OpenTelemetry ─────────────────────────────────────
    if settings.otel_endpoint:
        provider = TracerProvider()
        exporter = OTLPSpanExporter(endpoint=settings.otel_endpoint)
        provider.add_span_processor(BatchSpanProcessor(exporter))
        trace.set_tracer_provider(provider)
        FastAPIInstrumentor.instrument()

    # ── Langfuse ──────────────────────────────────────────
    global _langfuse
    if settings.langfuse_public_key:
        _langfuse = Langfuse(
            public_key=settings.langfuse_public_key,
            secret_key=settings.langfuse_secret_key,
            host=settings.langfuse_host,
        )


def get_langfuse() -> Langfuse | None:
    return _langfuse


def sentry_capture(exc: Exception, extra: dict | None = None):
    with sentry_sdk.push_scope() as scope:
        if extra:
            for k, v in extra.items():
                scope.set_extra(k, v)
        sentry_sdk.capture_exception(exc)
```

### 14.3 關鍵監控指標

| 指標 | 工具 | 告警條件 |
|---|---|---|
| P95 草稿生成延遲 | OTel + Langfuse | > 5 秒告警 |
| P95 情緒感測延遲 | OTel | > 2 秒告警 |
| P99 合規掃描延遲 | OTel | > 50ms 告警（硬限制） |
| 每日 AI 成本（per distributor） | Langfuse | > $0.27 告警（$0.30 前預警） |
| 合規紅燈觸發率 | Langfuse | 單日 > 20% 告警 |
| 草稿採用率 | Langfuse | < 20% 告警（PMF 信號）|
| API 500 錯誤率 | Sentry | > 1% 告警 |
| 學習紀錄寫入失敗 | Sentry | 任一失敗即告警 |

---

## 15. 測試策略

### 15.1 測試分層

| 層級 | 工具 | 覆蓋目標 | 說明 |
|---|---|---|---|
| 單元測試 | pytest + pytest-asyncio | 80%+ | Service/Sidecar/Repository 邏輯 |
| 整合測試 | pytest + httpx（TestClient）+ pgvector/pgvector:pg16 container | 關鍵端點 100% | 含 RLS policy 驗證 |
| 紅隊測試 | pytest | 租戶隔離 3 項 | 契約 G.3 三條必過 |

### 15.2 測試目錄結構

```
tests/
├── conftest.py                        # 共用 fixtures（test DB、JWT mock）
├── unit/
│   ├── test_compliance_sidecar.py     # ComplianceSidecar 正常/邊界/紅燈
│   ├── test_quota_service.py          # 配額熔斷邏輯
│   ├── test_message_draft_service.py  # 草稿生成（mock orchestrator）
│   ├── test_today_task_service.py     # 優先序規則
│   ├── test_salesy_alert_service.py   # 純規則引擎
│   ├── test_learning_log_service.py   # fire-and-forget 確認
│   ├── test_webhook_signature.py      # LINE HMAC-SHA256 驗簽（正常/竄改/遺失 header）
│   ├── test_assignment_service.py     # round-robin 輪派（cursor 前進、sticky、無 active）
│   └── test_message_draft_send.py     # send → compliance → LINE push（mock line_client）
├── integration/
│   ├── test_api_contacts.py           # T01 CRUD + 分頁
│   ├── test_api_message_drafts.py     # T06 SSE + 合規 gate
│   ├── test_api_questionnaire.py      # T10 公開端點 + token 過期
│   ├── test_api_voice_clips.py        # T08 配額 + 字數限制
│   ├── test_api_webhooks.py           # LINE webhook 冪等 + 重複 line_message_id
│   └── test_rls_policy.py             # PostgreSQL RLS policy 整合
└── red_team/
    ├── test_tenant_isolation_r001.py   # R001 不得查到 R002 的 contact
    ├── test_jwt_sub_match.py           # JWT sub 與路徑 distributor_id 一致性
    └── test_rls_coverage.py            # RLS policy 覆蓋每張表
```

### 15.3 關鍵測試案例說明

#### 合規 Sidecar 單元測試

```python
# tests/unit/test_compliance_sidecar.py
import pytest
from app.sidecars.compliance_sidecar import ComplianceSidecar

MOCK_LEXICON = [
    {"term": "保證", "risk_level": "red", "suggestion": "改寫為『我自己用了感覺不錯』"},
    {"term": "治癒", "risk_level": "red", "suggestion": "改寫為『有幫助』"},
    {"term": "月入十萬", "risk_level": "red", "suggestion": "改寫為『有些夥伴做得不錯，每人成果不同』"},
    {"term": "幫助", "risk_level": "yellow", "suggestion": "確認上下文是否為療效宣稱"},
]


@pytest.fixture
def sidecar():
    return ComplianceSidecar(MOCK_LEXICON)


def test_green_text(sidecar):
    result = sidecar.check("最近睡得好一點了嗎？上次說睡眠不好，想關心一下。")
    assert result.status == "green"
    assert result.triggered_terms == []
    assert result.latency_ms < 50


def test_red_income_claim(sidecar):
    result = sidecar.check("加入我們，月入十萬不是夢！")
    assert result.status == "red"
    assert "月入十萬" in result.triggered_terms
    assert result.suggestion != ""


def test_yellow_borderline(sidecar):
    result = sidecar.check("這個產品對睡眠很有幫助喔。")
    assert result.status == "yellow"


def test_latency_under_50ms(sidecar):
    import time
    long_text = "這是一段很長的訊息。" * 100
    t = time.perf_counter()
    sidecar.check(long_text)
    assert (time.perf_counter() - t) * 1000 < 50
```

#### 租戶隔離紅隊測試

```python
# tests/red_team/test_tenant_isolation_r001.py
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_r001_cannot_read_r002_contact(
    client: AsyncClient,
    jwt_r001: str,
    contact_r002_id: str,
):
    """R001 用戶嘗試讀取 R002 的 contact，應回 404（不回 403）"""
    resp = await client.get(
        f"/api/v1/contacts/{contact_r002_id}",
        headers={"Authorization": f"Bearer {jwt_r001}"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "NOT_FOUND"


@pytest.mark.asyncio
async def test_jwt_sub_must_match_path(
    client: AsyncClient,
    jwt_r001: str,
    distributor_r002_id: str,
):
    """JWT sub 與路徑中的 distributor_id 不一致，應回 403"""
    resp = await client.get(
        f"/api/v1/contacts?distributor_id={distributor_r002_id}",
        headers={"Authorization": f"Bearer {jwt_r001}"},
    )
    assert resp.status_code in (403, 404)
```

### 15.4 測試執行指令

```bash
# 執行全部測試
uv run pytest tests/ -v --cov=app --cov-report=term-missing

# 只跑單元測試（快，不需 DB）
uv run pytest tests/unit/ -v

# 只跑紅隊測試（需本地 PostgreSQL container）
uv run pytest tests/red_team/ -v --tb=short

# 覆蓋率報告
uv run pytest --cov=app --cov-report=html --cov-fail-under=80
```

---

## 16. LINE 整合

> 每租戶一個 LINE Official Account（OA）。客戶傳訊 → webhook 收訊 → 輪派/查找教練 → 寫 inbound_messages → 自動生回覆草稿 → 教練審核 → 按發送 → LINE push 給客戶。**AI 不自動回**，所有外送均經合規 gate 並需教練確認。

### 16.1 LINE 收訊流程（sequenceDiagram）

```mermaid
sequenceDiagram
    participant LN as LINE Platform
    participant WH as webhooks.py
    participant IS as InboxService
    participant AS as AssignmentService
    participant DS as MessageDraftService
    participant DB as PostgreSQL
    participant LC as LineClient

    LN->>WH: POST /api/v1/webhooks/line
    WH->>WH: 驗 X-Line-Signature HMAC-SHA256
    WH-->>LN: HTTP 200 即時回應
    WH->>IS: handle_message_event(event) 非同步
    IS->>DB: 查 official_accounts by channel_id
    IS->>DB: 查 contacts by line_user_id
    IS->>AS: 新客戶? assign_next(tenant_id, oa_id)
    AS->>DB: 取 active distributors + assignment_cursor
    AS->>DB: UPDATE official_accounts.assignment_cursor
    AS->>DB: INSERT/UPDATE contacts.distributor_id assigned_at
    IS->>DB: INSERT inbound_messages(status=new)
    IS->>DB: INSERT today_tasks(source_type=inbound_reply)
    IS->>DS: generate_draft(inbound_id) 非同步
    DS->>DS: compliance_check 前置掃描
    DS->>DB: INSERT message_drafts(channel=line_oa)
    DS->>DB: UPDATE inbound_messages.status=drafted
```

### 16.2 Webhook Handler（app/api/webhooks.py）

```python
# app/api/webhooks.py
import hashlib
import hmac
import base64
import asyncio
import logging

from fastapi import APIRouter, Request, HTTPException, status

from app.core.config import settings
from app.core.errors import LineSignatureInvalidError
from app.services.inbox_service import InboxService

router = APIRouter(tags=["LINE Webhook"])
logger = logging.getLogger(__name__)


def _verify_line_signature(body: bytes, signature: str) -> bool:
    """
    HMAC-SHA256 驗簽。
    signature = base64( HMAC-SHA256( channel_secret, request_body ) )
    """
    digest = hmac.new(
        settings.line_channel_secret.encode("utf-8"),
        body,
        hashlib.sha256,
    ).digest()
    expected = base64.b64encode(digest).decode("utf-8")
    return hmac.compare_digest(expected, signature)


@router.post("/webhooks/line")
async def line_webhook(request: Request):
    """
    LINE Messaging API webhook。
    - 公開端點，不走 JWT。
    - 收到請求先回 200，再非同步處理（避免 LINE retry）。
    - 冪等：同一 line_message_id 重複投遞時靜默忽略（DB UNIQUE 約束保護）。
    """
    body = await request.body()
    signature = request.headers.get("X-Line-Signature", "")

    if not signature or not _verify_line_signature(body, signature):
        raise LineSignatureInvalidError()

    import json
    try:
        payload = json.loads(body)
    except Exception:
        # body 無法解析時也回 200，不讓 LINE 重試無效請求
        return {"status": "ok"}

    # 非同步處理，不阻塞回應
    for event in payload.get("events", []):
        if event.get("type") == "message":
            asyncio.create_task(_handle_message(event))

    return {"status": "ok"}


async def _handle_message(event: dict):
    """背景處理 message event，捕捉所有例外避免 task 靜默消失。"""
    try:
        service = InboxService.from_settings(settings)
        await service.handle_message_event(event)
    except Exception as exc:
        logger.error("LINE message handling failed: %s", exc, exc_info=True)
        from app.core.observability import sentry_capture
        sentry_capture(exc, extra={"line_event": event})
```

### 16.3 LINE Client（app/infra/line_client.py）

```python
# app/infra/line_client.py
import httpx
import logging
from dataclasses import dataclass

from app.core.config import settings

logger = logging.getLogger(__name__)

LINE_API_BASE = "https://api.line.me/v2/bot"


@dataclass
class LineProfile:
    user_id: str
    display_name: str
    picture_url: str | None


class LineClient:
    """
    LINE Messaging API thin client。
    使用 httpx.AsyncClient，不依賴 line-bot-sdk（可選，見附錄 B）。
    若使用 line-bot-sdk，可替換為 AsyncLineBotApi 實作。
    """

    def __init__(self, access_token: str | None = None):
        self._token = access_token or settings.line_channel_access_token

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
        }

    async def push_message(self, to: str, text: str) -> str:
        """
        推播文字訊息給指定 line_user_id。
        回傳 LINE 回應的 message id（供回填 message_drafts.line_message_id）。
        reply token 約 1 分鐘失效，故一律用 push（免費額度 + 超量計費）。
        客戶須已加 OA 好友；若未加好友 LINE 回 400，拋 LinePushFailedError。
        """
        from app.core.errors import LinePushFailedError
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                f"{LINE_API_BASE}/message/push",
                headers=self._headers(),
                json={
                    "to": to,
                    "messages": [{"type": "text", "text": text}],
                },
            )
        if resp.status_code != 200:
            logger.error(
                "LINE push failed: status=%s body=%s", resp.status_code, resp.text
            )
            raise LinePushFailedError()
        data = resp.json()
        # LINE push response 包含 sentMessages[0].id
        messages = data.get("sentMessages", [])
        return messages[0]["id"] if messages else ""

    async def get_profile(self, line_user_id: str) -> LineProfile:
        """取得 LINE 使用者基本資料（顯示名稱、頭像）。"""
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                f"{LINE_API_BASE}/profile/{line_user_id}",
                headers=self._headers(),
            )
        resp.raise_for_status()
        data = resp.json()
        return LineProfile(
            user_id=data["userId"],
            display_name=data.get("displayName", ""),
            picture_url=data.get("pictureUrl"),
        )
```

### 16.4 AssignmentService（app/services/assignment_service.py）

```python
# app/services/assignment_service.py
"""
新客戶 round-robin 輪派。
- 既有客戶（contacts.distributor_id 已設）sticky，不改派。
- 每個租戶的 official_accounts.assignment_cursor 記錄目前輪到第幾位。
- 僅對 is_active=true 的 distributor 輪派。
- Leader 可透過 PUT /api/v1/contacts/{id}/assignment 手動改派。
"""
import logging
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.official_account_repository import OfficialAccountRepository
from app.repositories.contact_repository import ContactRepository

logger = logging.getLogger(__name__)


class AssignmentService:
    def __init__(
        self,
        oa_repo: OfficialAccountRepository,
        contact_repo: ContactRepository,
    ):
        self._oa_repo = oa_repo
        self._contact_repo = contact_repo

    async def assign_next(
        self,
        tenant_id: str,
        official_account_id: str,
        contact_id: str,
    ) -> str:
        """
        輪派下一位 active distributor 給新客戶。
        1. 取租戶 active distributors 列表（依 id 排序，確保穩定序）
        2. 讀取 official_accounts.assignment_cursor（目前指向列表第幾位）
        3. next_idx = (cursor + 1) % len(active)
        4. UPDATE official_accounts.assignment_cursor = next_idx
        5. UPDATE contacts.distributor_id, assigned_at
        回傳被指派的 distributor_id。
        """
        active = await self._oa_repo.get_active_distributors(tenant_id)
        if not active:
            logger.warning(
                "tenant=%s 無 active distributor，無法輪派 contact=%s",
                tenant_id, contact_id,
            )
            raise ValueError("NO_ACTIVE_DISTRIBUTOR")

        cursor = await self._oa_repo.get_assignment_cursor(official_account_id)
        next_idx = (cursor + 1) % len(active)
        distributor_id = active[next_idx].id

        await self._oa_repo.advance_cursor(official_account_id, next_idx)
        await self._contact_repo.assign_distributor(
            contact_id=contact_id,
            distributor_id=distributor_id,
            tenant_id=tenant_id,
        )
        logger.info(
            "assigned contact=%s → distributor=%s (idx=%s)",
            contact_id, distributor_id, next_idx,
        )
        return distributor_id
```

### 16.5 InboxService（app/services/inbox_service.py）

```python
# app/services/inbox_service.py
"""
LINE inbound 完整處理流程：
收到 LINE message event → 查/建 contact → 輪派（新客戶）
→ 寫 inbound_messages → 插 today_tasks → 生回覆草稿（非同步）
"""
import asyncio
import logging
from datetime import datetime, timezone

from app.core.config import Settings
from app.repositories.official_account_repository import OfficialAccountRepository
from app.repositories.contact_repository import ContactRepository
from app.repositories.inbound_message_repository import InboundMessageRepository
from app.repositories.today_task_repository import TodayTaskRepository
from app.services.assignment_service import AssignmentService
from app.services.message_draft_service import MessageDraftService
from app.infra.line_client import LineClient

logger = logging.getLogger(__name__)


class InboxService:

    @classmethod
    def from_settings(cls, settings: Settings) -> "InboxService":
        """工廠方法：從 settings 建立完整依賴圖（適合 webhook 背景 task）。"""
        # 假設：實作時注入 session factory
        ...

    async def handle_message_event(self, event: dict) -> None:
        """
        處理一條 LINE message event。
        冪等保護：inbound_messages.line_message_id 有 UNIQUE 約束，
        重複投遞時 DB insert 會觸發 UniqueViolation，捕捉後靜默回傳。
        """
        source = event.get("source", {})
        line_user_id = source.get("userId", "")
        message = event.get("message", {})
        line_message_id = message.get("id", "")
        text = message.get("text", "")
        channel_id = source.get("roomId") or source.get("groupId") or "direct"

        if not line_user_id or not line_message_id:
            return

        # 1. 查 official_account（by LINE channel_id，tenant_id 從 OA 取得）
        oa = await self._oa_repo.get_by_channel_id(channel_id)
        if oa is None:
            logger.warning("未知 LINE channel_id=%s，丟棄訊息", channel_id)
            return
        tenant_id = oa.tenant_id

        # 2. 查或建 contact
        contact = await self._contact_repo.get_by_line_user_id(
            tenant_id=tenant_id, line_user_id=line_user_id
        )
        is_new = contact is None
        if is_new:
            profile = await self._line_client.get_profile(line_user_id)
            contact = await self._contact_repo.create({
                "tenant_id": tenant_id,
                "line_user_id": line_user_id,
                "display_name": profile.display_name,
                "source": "line_oa",
            })

        # 3. 新客戶輪派
        if is_new or contact.distributor_id is None:
            await self._assignment_service.assign_next(
                tenant_id=tenant_id,
                official_account_id=oa.id,
                contact_id=contact.id,
            )
            await self._contact_repo.refresh(contact)  # 重載 distributor_id

        # 4. 寫 inbound_messages（冪等：UNIQUE(line_message_id)）
        try:
            inbound = await self._inbound_repo.create({
                "tenant_id": tenant_id,
                "official_account_id": oa.id,
                "contact_id": contact.id,
                "distributor_id": contact.distributor_id,
                "line_message_id": line_message_id,
                "text": text,
                "received_at": datetime.now(timezone.utc),
                "status": "new",
            })
        except Exception as exc:
            if "unique" in str(exc).lower():
                logger.info("重複訊息 line_message_id=%s，已略過", line_message_id)
                return
            raise

        # 5. 插 today_tasks（待回覆卡，source_type=inbound_reply）
        await self._task_repo.upsert_inbound_task({
            "tenant_id": tenant_id,
            "distributor_id": contact.distributor_id,
            "contact_id": contact.id,
            "source_type": "inbound_reply",
            "source_id": inbound.id,
        })

        # 6. 非同步生回覆草稿（不阻塞）
        asyncio.create_task(
            self._draft_service.generate_inbound_draft(
                inbound_id=inbound.id,
                tenant_id=tenant_id,
                distributor_id=contact.distributor_id,
                contact_id=contact.id,
                text=text,
            )
        )
```

### 16.6 草稿發送（message_draft_service.send）

```python
# app/services/message_draft_service.py（send 方法節錄）
async def send(self, ctx, draft_id: str) -> None:
    """
    POST /api/v1/message-drafts/{draft_id}/send 業務邏輯：
    1. 取草稿（確認 distributor_id 一致、channel=line_oa）
    2. 合規 sidecar 最終掃描（紅燈回 422 COMPLIANCE_RED_BLOCKED）
    3. LINE push_message → 取回 line_message_id
    4. 回填 message_drafts：sent_at、line_message_id、delivery_method=line_push
    5. 更新 inbound_messages.status=replied（若有 in_reply_to_inbound_id）
    6. fire-and-forget learning_log: draft_adopted
    """
    draft = await self._draft_repo.get_or_404(draft_id, ctx.tenant_id)
    if draft.distributor_id != ctx.distributor_id:
        from app.core.errors import ForbiddenError
        raise ForbiddenError()

    # 合規最終檢查
    check = self._sidecar.check(draft.content)
    await self._compliance_repo.save_check({
        **check.__dict__,
        "source_type": "message_draft",
        "source_id": draft_id,
        "distributor_id": ctx.distributor_id,
        "tenant_id": ctx.tenant_id,
    })
    if check.status == "red":
        from app.core.errors import ComplianceRedBlockedError
        raise ComplianceRedBlockedError(
            triggered_terms=check.triggered_terms,
            suggestion=check.suggestion,
        )

    # LINE push
    contact = await self._contact_repo.get_or_404(draft.contact_id, ctx.tenant_id)
    line_msg_id = await self._line_client.push_message(
        to=contact.line_user_id,
        text=draft.content,
    )

    # 回填草稿
    from datetime import datetime, timezone
    await self._draft_repo.update(draft_id, {
        "sent_at": datetime.now(timezone.utc),
        "line_message_id": line_msg_id,
        "delivery_method": "line_push",
    })

    # 更新 inbound 狀態
    if draft.in_reply_to_inbound_id:
        await self._inbound_repo.update_status(
            draft.in_reply_to_inbound_id, "replied"
        )

    # fire-and-forget
    import asyncio
    asyncio.create_task(
        self._learning_log_service.record(
            ctx=ctx,
            event_type="draft_adopted",
            source_type="message_draft",
            source_id=draft_id,
            metadata={"channel": "line_oa", "line_message_id": line_msg_id},
        )
    )
```

### 16.7 非 OA 客戶（manual source）

非 LINE OA 客戶（source=manual）維持現有手動補資料流程：直銷商自行填入 contacts，複製草稿內容至 LINE App 傳送。`delivery_method=manual_copy`，不觸發 push_message。

### 16.8 來訊自動分析服務（enrichment_service）

每則 OA 來訊寫入後的非同步背景任務（不阻擋 webhook 200 回應）：

```python
# app/services/enrichment_service.py（介面節錄）
# 單次 Haiku 4.5 呼叫，一次輸出三件事（控制成本，G.5）

class EnrichmentResult(BaseModel):
    emotion: Literal["stressed", "neutral", "happy"]
    life_events: list[LifeEventExtract]          # T02：型別 + 摘要
    profile_suggestions: list[ProfileSuggestion]  # T01：field + value + evidence

async def enrich_inbound(inbound_id: str, tenant_ctx: TenantContext) -> None:
    # 1. 成本前置檢查：熔斷中 → enrichment_status='skipped'，return（不拋例外）
    # 2. 取最近 N 則 inbound_messages（同 contact）作為情緒判讀上下文
    # 3. 單次 Haiku 4.5 呼叫 → EnrichmentResult（Langfuse span 記錄）
    # 4. 分流寫入：
    #    - contacts.current_emotion ← emotion（T03）
    #    - life_events + today_tasks ← life_events（T02，去重：同 contact 同 event_type 24h 內不重複）
    #    - contact_suggestions（status='pending'）← profile_suggestions（T01，G.7：不直接寫 contacts）
    # 5. UPDATE inbound_messages SET enrichment_status='done', enriched_at, detected_emotion
    # 6. learning_logs：event_type='inbound_enriched'
    # 失敗：enrichment_status='failed'，Sentry 告警，不影響收訊主流程
```

掛載點：`webhooks.py` 處理完 `INSERT inbound_messages` 後以 `asyncio.create_task`（或 background task queue）觸發。

### 16.9 語音 OA 發送（voice_service.send）

```python
# app/services/voice_service.py（send 方法節錄）
async def send_voice(clip_id: str, tenant_ctx: TenantContext) -> VoiceSendResult:
    # 1. listened_at 為空 → raise VoiceNotListenedException（422 VOICE_NOT_LISTENED）
    # 2. 對應草稿 compliance_status == 'red' → raise ComplianceBlockedException（422）
    # 3. 草稿 content 在語音生成後被修改（updated_at > clip.created_at）
    #    → raise VoiceStaleException（409 VOICE_STALE，須重生語音重掃合規）
    # 4. contact.line_user_id 為空 → 422 VALIDATION_ERROR
    # 5. LINE push audio message（originalContentUrl=HTTPS 可達 URL, duration=ms）
    # 6. 成功：sent_at=now(), line_message_id, retention_until=sent_at+30d
    #    寫互動時間軸（source='line_oa', interaction_type='voice_sent'）
    #    learning_logs：event_type='voice_sent'
```

語音檔格式 m4a（AAC，LINE 要求）；TTS 供應商若無法直接輸出 AAC，於 `storage.py` 上傳前加 ffmpeg 轉檔。清理排程：未發送依 `expires_at`（7 天）、已發送依 `retention_until`（30 天），APScheduler job 每日執行。

### 16.10 太業務員發送前預警（pre-send gate）

`message_draft_service.send()` 在合規檢查之後、LINE push 之前插入：

```python
# 1. 本則是否推銷型（純規則：產品關鍵字 + URL pattern，無 AI）
# 2. 推銷型且 contact.salesy_streak_count >= 2 且 request.acknowledge_salesy != True
#    → 預生純關懷草稿（Haiku，過合規）
#    → raise SalesyWarningException（409 SALESY_WARNING，附 streak_count + care_draft_id）
# 3. 教練帶 acknowledge_salesy=true 重送 → 放行
#    → learning_logs：event_type='salesy_alert_acknowledged'
# 4. 發送成功後更新 salesy_streak_count（推銷型 +1；關懷型歸零）
```

OA 管道的 streak 計數完全自動（依發送紀錄），不依賴教練手動補登互動。

---

| 文件 | 路徑 |
|---|---|
| 系統架構 | [./01_architecture.md](./01_architecture.md) |
| API 契約 | [./02_api.md](./02_api.md) |
| 資料模型 | [./03_data-model.md](./03_data-model.md) |
| 前端架構規範 | [./04_frontend.md](./04_frontend.md) |
| 專案結構與基礎設施 | [./06_project-structure.md](./06_project-structure.md) |
| 測試策略（詳細） | 見本文件 §12 與 [./06_project-structure.md](./06_project-structure.md) |
| 跨文件共用契約 | 本文件頂部「共用契約」章節 |

---

## 附錄 B — pyproject.toml 核心依賴

```toml
[project]
name = "care-copilot-backend"
version = "0.1.0"
requires-python = ">=3.12"

dependencies = [
    # ── Web 框架 ──────────────────────────────────────────
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.30.0",
    "python-multipart>=0.0.9",      # 檔案上傳（截圖補資料）

    # ── 資料庫 ────────────────────────────────────────────
    "sqlalchemy[asyncio]>=2.0.0",
    "asyncpg>=0.30.0",              # PostgreSQL async driver
    "alembic>=1.14.0",
    "pgvector>=0.3.0",              # pgvector Python extension

    # ── 設定 ──────────────────────────────────────────────
    "pydantic-settings>=2.0.0",
    "pydantic>=2.0.0",

    # ── 認證 ──────────────────────────────────────────────
    "python-jose[cryptography]>=3.3.0",  # JWT 簽/驗（HS256）
    "passlib[bcrypt]>=1.7.4",            # 密碼雜湊（bcrypt）

    # ── GCS 語音儲存 ──────────────────────────────────────
    "google-cloud-storage>=2.16.0",

    # ── AI（沿用既有框架，不重新設計）────────────────────
    "anthropic>=0.34.0",
    "openai>=1.50.0",
    "langgraph>=0.2.0",

    # ── 觀測 ──────────────────────────────────────────────
    "sentry-sdk[fastapi]>=2.0.0",
    "opentelemetry-sdk>=1.25.0",
    "opentelemetry-exporter-otlp-proto-grpc>=1.25.0",
    "opentelemetry-instrumentation-fastapi>=0.46b0",
    "opentelemetry-instrumentation-sqlalchemy>=0.46b0",
    "langfuse>=3.0.0",

    # ── 排程 ──────────────────────────────────────────────
    "apscheduler>=3.10.0",

    # ── 速率限制 ──────────────────────────────────────────
    "slowapi>=0.1.9",

    # ── LINE Messaging API ────────────────────────────────
    # 選項 A（推薦）：官方 SDK，含 HMAC 驗簽輔助、push/reply/profile 封裝
    "line-bot-sdk>=3.11.0",
    # 選項 B（替代）：直接用 httpx 呼叫 LINE API，不依賴 SDK；
    # 若選 B 可移除上一行，line_client.py 改用 httpx.AsyncClient
]

[tool.uv]
dev-dependencies = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.24.0",
    "pytest-cov>=5.0.0",
    "httpx>=0.27.0",               # TestClient async support
    "pytest-mock>=3.14.0",
    "factory-boy>=3.3.0",          # test fixtures
]
```

---

*文件結尾。版本 v0.2 | 2026-06-02 | 對應 PRD v0.3 | 專案根 backend/*
