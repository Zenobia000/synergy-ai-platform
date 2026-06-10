# 02 API 設計規範 — Care Copilot

版本 v0.2 | 日期 2026-06-07 | 狀態 draft | 對應 PRD v0.2（docs/PRD.md）/ 00_tech-spec v0.4 | 專案 synergy（repo 根）

> v0.2 變更：新增 7.18 來訊自動分析與活檔案建議（contact-suggestions）；voice-clips 增 listen/send 端點（OA 語音 push）；message-drafts send 增太業務員發送前預警；webhook 處理增 enrichment 步驟。

> 本文件定義 Care Copilot Phase I MVP 的所有對外 REST API 規範，包含設計約定、通用行為、錯誤處理、認證授權、速率限制與 11 個工具的完整端點。
> 資料庫實體詳見 [./03_data-model.md](./03_data-model.md)；後端實作詳見 [./05_backend.md](./05_backend.md)；AI 編排層沿用既有框架，本次不重新設計。

---

## 目錄

1. [設計約定](#1-設計約定)
2. [通用行為](#2-通用行為)
3. [錯誤處理](#3-錯誤處理)
4. [認證與授權](#4-認證與授權)
5. [速率限制與 Freemium 配額](#5-速率限制與-freemium-配額)
6. [SSE 串流約定](#6-sse-串流約定)
7. [端點定義](#7-端點定義)
   - 7.1 [認證與個人資料 (auth/login, auth/me)](#71-認證與個人資料-authlogin-authme)
   - 7.2 [T01 關係記憶活檔案 (contacts)](#72-t01-關係記憶活檔案-contacts)
   - 7.3 [互動記錄 (interactions)](#73-互動記錄-interactions)
   - 7.4 [T02 生活事件雷達 (life-events)](#74-t02-生活事件雷達-life-events)
   - 7.5 [T03 語氣／情緒感測器 (emotion)](#75-t03-語氣情緒感測器-emotion)
   - 7.6 [T04 太業務員警報 (salesy-alerts)](#76-t04-太業務員警報-salesy-alerts)
   - 7.7 [T05 今日 5 件事 (today-tasks)](#77-t05-今日-5-件事-today-tasks)
   - 7.8 [T06 訊息草稿 (message-drafts)](#78-t06-訊息草稿-message-drafts)
   - 7.9 [T07 樣品追蹤 (samples)](#79-t07-樣品追蹤-samples)
   - 7.10 [T08 語音草稿 (voice-clips)](#710-t08-語音草稿-voice-clips)
   - 7.11 [T09 快速異議處理器 (objection-responses)](#711-t09-快速異議處理器-objection-responses)
   - 7.12 [T10 健康問卷 (questionnaire)](#712-t10-健康問卷-questionnaire)
   - 7.13 [T11 招募漏斗 (recruitment)](#713-t11-招募漏斗-recruitment)
   - 7.14 [合規低語 (compliance)](#714-合規低語-compliance)
   - 7.15 [平台支撐 (subscription / usage / consent / data-requests)](#715-平台支撐-subscription--usage--consent--data-requests)
   - 7.16 [學習紀錄 (learning-logs)](#716-學習紀錄-learning-logs-internal)
   - 7.17 [LINE 整合 (webhooks / inbox / message-drafts send / contacts assignment)](#717-line-整合-webhooks--inbox--message-drafts-send--contacts-assignment)
   - 7.18 [來訊自動分析與活檔案建議 (contact-suggestions)](#718-來訊自動分析與活檔案建議-contact-suggestions)
8. [資料模型 DTO Schemas](#8-資料模型-dto-schemas)
9. [排程與內部事件](#9-排程與內部事件)
10. [跨領域不變量](#10-跨領域不變量)

---

## 1. 設計約定

### 1.1 基礎規約

| 項目 | 規格 |
|---|---|
| Base Path | `/api/v1` |
| 認證方式 | `Authorization: Bearer <jwt>` |
| 欄位命名 | snake_case |
| 時間格式 | ISO 8601 UTC（`2026-06-02T10:30:00Z`） |
| 資源路徑 | 小寫複數連字號（`/message-drafts`、`/today-tasks`） |
| 版本策略 | 版本號放 URL path（`/api/v1/...`），不用 header |
| Content-Type | `application/json`（除 SSE 外） |
| SSE Content-Type | `text/event-stream` |
| 字元編碼 | UTF-8 |
| HTTPS | 生產環境強制；開發環境（localhost:8002）除外 |
| 分頁策略 | 游標分頁（`?cursor=<uuid>&limit=<int>`），不用 offset 分頁 |

### 1.2 資源路徑命名表

| 工具 | 資源路徑前綴 |
|---|---|
| 認證與個人資料 | `/api/v1/auth`（含 `/api/v1/auth/login` 公開端點） |
| T01 活檔案 | `/api/v1/contacts` |
| T02 生活事件 | `/api/v1/contacts/{contact_id}/life-events` |
| T03 情緒感測 | `/api/v1/contacts/{contact_id}/emotion` |
| T04 太業務員警報 | `/api/v1/salesy-alerts`、`/api/v1/contacts/{contact_id}/salesy-alerts` |
| T05 今日 5 件事 | `/api/v1/today-tasks` |
| T06 訊息草稿 | `/api/v1/message-drafts` |
| T07 樣品追蹤 | `/api/v1/contacts/{contact_id}/samples`、`/api/v1/samples` |
| T08 語音草稿 | `/api/v1/voice-clips` |
| T09 異議處理 | `/api/v1/objection-templates`、`/api/v1/objection-responses` |
| T10 健康問卷 | `/api/v1/questionnaire-templates`、`/api/v1/questionnaire-links` |
| T11 招募漏斗 | `/api/v1/contacts/{contact_id}/recruitment-stage`、`/api/v1/recruitment` |
| 合規低語 | `/api/v1/compliance` |
| LINE Webhook | `/api/v1/webhooks/line` |
| LINE 收件匣 | `/api/v1/inbox` |
| 訂閱 | `/api/v1/subscription` |
| 用量 | `/api/v1/usage` |
| 同意記錄 | `/api/v1/contacts/{contact_id}/consents` |
| 資料請求 | `/api/v1/data-requests` |
| 學習紀錄 | `/api/v1/learning-logs` |

### 1.3 ID 前綴規範

所有 ID 欄位帶前綴（人眼可識別，同時也是合法 UUID 衍生字串）：

| 實體 | 前綴 | 範例 |
|---|---|---|
| tenants | `tnt_` | tnt_abc123 |
| distributors | `usr_` | usr_abc123 |
| brands | `brd_` | brd_abc123 |
| brand_products | `prd_` | prd_abc123 |
| contacts | `ctc_` | ctc_abc123 |
| contact_interactions | `itr_` | itr_abc123 |
| life_events | `evt_` | evt_abc123 |
| samples | `smp_` | smp_abc123 |
| sample_followups | `sfu_` | sfu_abc123 |
| message_drafts | `dft_` | dft_abc123 |
| voice_clips | `voc_` | voc_abc123 |
| objection_templates | `obt_` | obt_abc123 |
| objection_responses | `obr_` | obr_abc123 |
| questionnaire_templates | `qtpl_` | qtpl_abc123 |
| questionnaire_links | `qlnk_` | qlnk_abc123 |
| questionnaire_responses | `qrsp_` | qrsp_abc123 |
| recruitment_stages | `rcs_` | rcs_abc123 |
| compliance_lexicon | `lex_` | lex_abc123 |
| compliance_checks | `cck_` | cck_abc123 |
| emotion_readings | `emo_` | emo_abc123 |
| salesy_alerts | `sal_` | sal_abc123 |
| today_tasks | `tsk_` | tsk_abc123 |
| learning_logs | `lgl_` | lgl_abc123 |
| consents | `cns_` | cns_abc123 |
| data_requests | `drq_` | drq_abc123 |
| official_accounts | `oa_` | oa_abc123 |
| inbound_messages | `inb_` | inb_abc123 |
| subscriptions | `sub_` | sub_abc123 |
| usage_quotas | `uqt_` | uqt_abc123 |

---

## 2. 通用行為

### 2.1 游標分頁

所有列表端點使用游標分頁，不使用 offset-based 分頁（避免大資料集下效能退化與資料跳頁問題）。

**請求參數：**

| 參數 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `cursor` | string | null | 上一頁最後一筆的 ID（帶前綴），首次請求省略 |
| `limit` | integer | 20 | 每頁筆數，最大 100 |

**標準回應信封：**

```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "ctc_xyz789",
    "has_more": true,
    "limit": 20
  }
}
```

`has_more` 為 `false` 時 `next_cursor` 為 `null`。

### 2.2 排序

列表端點預設按 `created_at DESC`。需要自訂排序時，透過 `sort` 和 `order` 參數：

```
GET /api/v1/contacts?sort=last_interaction_at&order=asc
```

支援的 `sort` 欄位因端點而異（詳見各端點定義）。

### 2.3 過濾

列表端點支援欄位過濾，以 query string 傳遞：

```
GET /api/v1/contacts?relationship_type=customer&q=Anna
```

`q` 為全文搜尋（對 `display_name`、`phone` 做 ilike 搜尋）。

### 2.4 冪等鍵

對有副作用的 POST 請求（草稿生成、語音生成），支援 `Idempotency-Key` header。相同 key 在 24 小時內重複請求，返回第一次的結果：

```
POST /api/v1/message-drafts
Idempotency-Key: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

後端在 PostgreSQL 的 `idempotency_keys` 表快取 key + 結果，TTL 24 小時。

假設：Redis 未在本 Phase I 技術棧中，改用 PostgreSQL 的 `idempotency_keys` 表實作，TTL 以 `expires_at` 欄位控制。

---

## 3. 錯誤處理

### 3.1 統一錯誤信封

所有錯誤回應使用統一信封格式：

```json
{
  "error": {
    "code": "COMPLIANCE_RED_BLOCKED",
    "message": "草稿含高風險詞，請依建議改寫後重試",
    "details": {
      "triggered_terms": ["保證", "治癒"],
      "suggestion": "改寫成「我自己用了感覺不錯，分享給你參考」"
    }
  }
}
```

- `code`：機器可讀的錯誤識別碼（大寫底線格式）
- `message`：直銷商可見的友善訊息（正體中文）
- `details`：可選；提供額外上下文（依錯誤類型而異）

### 3.2 錯誤碼表

| 錯誤碼 | HTTP 狀態碼 | 說明 | details 欄位 |
|---|---|---|---|
| `INVALID_CREDENTIALS` | 401 | 帳密錯誤（email 不存在或密碼不符） | null |
| `UNAUTHORIZED` | 401 | JWT 無效、過期或缺少 | `{"expired_at": "..."}` |
| `FORBIDDEN` | 403 | 角色權限不足（例如非 leader 呼叫 leader 專屬端點） | `{"required_role": "leader"}` |
| `NOT_FOUND` | 404 | 資源不存在，或跨租戶存取（統一回 404，避免洩漏資源存在性） | null |
| `VALIDATION_ERROR` | 422 | 請求欄位驗證失敗 | `{"fields": {"tone": "must be one of: care, casual, business"}}` |
| `QUOTA_EXCEEDED` | 429 | 配額已用盡（草稿、語音、聯絡人） | `{"quota_type": "drafts", "limit": 5, "used": 5, "upgrade_url": "/subscription/upgrade"}` |
| `COST_LIMIT_REACHED` | 429 | AI 成本日上限熔斷 | `{"cost_usd_today": 0.30, "limit_usd": 0.30, "reset_at": "2026-06-03T00:00:00Z"}` |
| `COMPLIANCE_RED_BLOCKED` | 422 | 合規紅燈強制阻擋 | `{"check_id": "cck_...", "triggered_terms": [...], "suggestion": "..."}` |
| `QUESTIONNAIRE_LINK_EXPIRED` | 410 | 問卷連結已過期 | `{"expired_at": "..."}` |
| `QUESTIONNAIRE_LINK_USED` | 410 | 問卷連結已填寫過 | `{"filled_at": "..."}` |
| `VOICE_DURATION_EXCEEDED` | 422 | 語音文字超過 60 秒長度限制 | `{"estimated_seconds": 75, "max_seconds": 60}` |
| `RATE_LIMITED` | 429 | API 呼叫頻率超限（per-minute 限制） | `{"retry_after_seconds": 30}` |
| `LINE_SIGNATURE_INVALID` | 401 | LINE webhook 簽章驗證失敗（X-Line-Signature HMAC-SHA256 不符） | null |
| `LINE_PUSH_FAILED` | 502 | LINE Messaging API push message 呼叫失敗（網路錯誤或 LINE 側錯誤） | `{"line_error_code": 400, "line_error_message": "..."}` |
| `INTERNAL_ERROR` | 500 | 伺服器內部錯誤（不洩漏 stack trace） | `{"trace_id": "otel_trace_id"}` |
| `AI_PROVIDER_ERROR` | 503 | AI 供應商（Anthropic / OpenAI / ElevenLabs）不可用 | `{"provider": "anthropic", "retry_after_seconds": 60}` |

### 3.3 跨租戶存取的特殊處理

跨租戶存取（R001 嘗試讀取 R002 的資源）**必須回 `404 NOT_FOUND`**，不得回 `403 FORBIDDEN`，避免洩漏資源存在性。

```mermaid
sequenceDiagram
    participant Client
    participant API
    participant RLS as Postgres RLS

    Client->>API: GET /api/v1/contacts/ctc_other_tenant
    API->>RLS: SELECT * FROM contacts WHERE id = ? AND tenant_id = ?
    RLS-->>API: 0 rows (RLS policy blocks)
    API-->>Client: 404 NOT_FOUND
    Note over API: 永遠不回 403，避免確認資源存在
```

---

## 4. 認證與授權

### 4.1 JWT Bearer 驗證

所有需要認證的端點使用後端自簽 JWT（HS256，以環境變數 `JWT_SECRET` 自驗，不依賴第三方認證服務）。

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

JWT Payload 關鍵欄位（扁平結構）：

```json
{
  "sub": "usr_abc123",
  "tenant_id": "tnt_abc123",
  "role": "distributor",
  "iat": 1748872800,
  "exp": 1748959200
}
```

後端每次請求以 `JWT_SECRET` 驗簽，再從 JWT 提取 `sub`（distributor_id）、`tenant_id` 與 `role`，注入至所有資料庫查詢的 WHERE 條件。Token 有效期為 24 小時。

### 4.1.1 登入端點

#### POST /api/v1/auth/login

取得 access token（**公開端點**，無需既有 token）。以 `distributors.password_hash` 透過 bcrypt（passlib）驗證密碼。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | public |

**Request：**

```json
{
  "email": "amy@example.com",
  "password": "plaintext_password"
}
```

**Response 200：**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400
}
```

`expires_in` 單位為秒（86400 = 24 小時）。

**Status Codes：** 200 OK / 401 INVALID_CREDENTIALS（帳密不符）/ 422 VALIDATION_ERROR（欄位格式錯誤）

### 4.2 角色定義

| 角色 | 說明 | 額外端點權限 |
|---|---|---|
| `distributor` | 一般直銷商（Amy、Nina） | 標準 11 工具端點 |
| `leader` | 團隊 Leader（Linda） | `/api/v1/recruitment/team-funnel`、未來 Phase II leader dashboard |

角色存在 `distributors.role` 欄位，後端根據 JWT 中的 `role` claim 進行端點授權，Postgres RLS policy 作為資料層第二道防線。

### 4.3 無需認證的端點（公開端點）

以下端點無需 JWT：

| 端點 | 說明 |
|---|---|
| `POST /api/v1/auth/login` | 直銷商登入，取得 access token |
| `GET /api/v1/questionnaire-links/{token}` | 客戶端取得問卷題目（以 token 驗證） |
| `POST /api/v1/questionnaire-links/{token}/submit` | 客戶端提交填答 |
| `POST /api/v1/webhooks/line` | LINE 平台事件 webhook（改用 `X-Line-Signature` HMAC-SHA256 驗證，非 JWT；由 LINE 伺服器主動呼叫） |

問卷兩端點以 `token`（隨機字串，查 `questionnaire_links.token`）作為存取憑證，不需要 JWT。LINE webhook 端點以 `X-Line-Signature` header 做 HMAC-SHA256 驗簽（金鑰為各租戶 OA 的 channel secret），後端驗簽失敗回 `401 LINE_SIGNATURE_INVALID`。

### 4.4 Scope 命名

假設：v1 不實作細粒度 OAuth scope，以角色（distributor/leader）作為唯一授權維度。端點說明中的 `auth scope` 欄位值為：
- `distributor`：需要任意已登入直銷商
- `leader`：需要 role=leader
- `public`：無需認證

### 4.5 租戶隔離流程

```mermaid
graph TD
    A[Request with JWT] --> B[Extract sub + tenant_id from JWT]
    B --> C{JWT valid?}
    C -->|No| D[401 UNAUTHORIZED]
    C -->|Yes| E[Attach tenant_id to DB session]
    E --> F[RLS policy enforces tenant_id filter]
    F --> G{Row found?}
    G -->|No| H[404 NOT_FOUND]
    G -->|Yes| I[Process request]
```

---

## 5. 速率限制與 Freemium 配額

### 5.1 API 呼叫頻率限制（per-minute）

| 角色 | 全局限制 | AI 端點限制 |
|---|---|---|
| Freemium | 60 req/min | 10 req/min |
| Pro | 120 req/min | 30 req/min |
| Pro Plus | 300 req/min | 60 req/min |

超過時回應 `429 RATE_LIMITED`，並附 `Retry-After` header。

### 5.2 Freemium 配額硬上限

| 資源 | Freemium | Pro ($39/月) | Pro Plus ($79/月) |
|---|---|---|---|
| contacts_total（跨日不重置） | 30 | 9999（無限制） | 9999 |
| drafts_used_today（每日重置） | 5 | 9999 | 9999 |
| voice_used_today（每日重置） | 3 | 10 | 9999 |
| ai_cost_usd_today（每日重置） | 0.30 | 0.30 | 0.30 |

配額存在 `usage_quotas` 表，每次 AI 呼叫後同步更新。超限時回應：

```json
HTTP 429 QUOTA_EXCEEDED
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "今日訊息草稿額度已用完（5/5），升級 Pro 即可無限生成",
    "details": {
      "quota_type": "drafts",
      "limit": 5,
      "used": 5,
      "reset_at": "2026-06-03T00:00:00Z",
      "upgrade_url": "/subscription/upgrade"
    }
  }
}
```

### 5.3 回應 Headers

所有需要配額的端點回應附帶以下 headers：

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1748872860
X-Quota-Drafts-Limit: 5
X-Quota-Drafts-Used: 2
X-Quota-Drafts-Reset: 2026-06-03T00:00:00Z
X-Quota-Voice-Limit: 3
X-Quota-Voice-Used: 1
```

### 5.4 成本熔斷機制

每位活躍直銷商每日 AI 成本（含語音 TTS）上限 USD 0.30：

1. 每次 AI 呼叫完成後**同步**更新 `usage_quotas.ai_cost_usd_today`
2. 達到 `cost_limit_usd` 時，後續 AI 請求回 `429 COST_LIMIT_REACHED`
3. 每日 00:00 UTC 重置（`APScheduler` 排程）
4. Langfuse 設定成本 dashboard，超限時告警至 Slack

---

## 6. SSE 串流約定

T06 訊息草稿生成使用 Server-Sent Events 串流，降低使用者感知延遲。

### 6.1 連線建立

```
POST /api/v1/message-drafts/stream
Content-Type: application/json
Authorization: Bearer <jwt>
Accept: text/event-stream

{
  "contact_id": "ctc_abc123",
  "tone": "care",
  "channel": "line"
}
```

回應 `Content-Type: text/event-stream`，保持長連線直到串流完成。

### 6.2 事件序列

```mermaid
sequenceDiagram
    participant Client
    participant API
    participant Haiku as Haiku 4.5（AI）
    participant Sonnet as Sonnet 4.6（AI）
    participant Compliance as compliance_sidecar

    Client->>API: POST /message-drafts/stream
    API->>API: 三道前置檢查（情緒/太業務員/配額）
    API-->>Client: event: meta
    API->>Haiku: 生成首字
    Haiku-->>API: 首字 token
    API-->>Client: event: first_token
    API->>Sonnet: 生成全文（streaming）
    loop 每個 token
        Sonnet-->>API: token
        API-->>Client: event: token
    end
    API->>Compliance: regex 掃描全文
    Compliance-->>API: 合規結果
    API-->>Client: event: compliance_result
    API->>API: 存入 message_drafts
    API-->>Client: event: done
    Note over API: 寫入 learning_logs（非同步，< 1 秒）
```

### 6.3 SSE 訊息格式定義

**event: meta**（連線建立後第一個事件，告知前端準備狀態）

```
event: meta
data: {"contact_id": "ctc_abc123", "tone": "care", "channel": "line", "started_at": "2026-06-02T10:30:00Z"}
```

**event: first_token**（Haiku 4.5 生成首字，< 500ms 目標）

```
event: first_token
data: {"token": "Anna，"}
```

**event: token**（Sonnet 4.6 接手，streaming 全文）

```
event: token
data: {"token": "最近睡得好一點了嗎？"}
```

**event: compliance_result**（合規掃描結果，在 done 前推送）

綠燈：
```
event: compliance_result
data: {"status": "green", "check_id": "cck_abc123", "triggered_terms": []}
```

黃燈：
```
event: compliance_result
data: {"status": "yellow", "check_id": "cck_xyz456", "triggered_terms": ["神奇"], "suggestion": "建議改成「我自己用了感覺不錯」"}
```

**event: done**（串流完成，包含最終 draft_id）

```
event: done
data: {"draft_id": "dft_abc123", "tone": "care", "channel": "line", "model_used": "sonnet-4-6", "latency_ms": 1240, "compliance_status": "green"}
```

**event: compliance_blocked**（紅燈，強制阻擋時不產生 done event）

```
event: compliance_blocked
data: {"status": "red", "check_id": "cck_xyz789", "triggered_terms": ["保證", "治癒"], "suggestion": "改寫成「我自己用了感覺不錯，分享給你參考」"}
```

**event: error**（串流過程中發生錯誤）

```
event: error
data: {"code": "AI_PROVIDER_ERROR", "message": "AI 服務暫時不可用，請稍後重試", "retry_after_seconds": 60}
```

### 6.4 前端處理原則

- 收到 `compliance_blocked` 時，前端停止渲染並顯示改寫提示，送出按鈕維持 disabled
- 收到 `compliance_result` 黃燈時，顯示提醒 banner，允許繼續
- 連線中斷時，前端可用 `draft_id`（若已在 meta 事件中回傳）查詢 `GET /api/v1/message-drafts/{draft_id}` 取得已完成的草稿
- SSE 連線 timeout 設定：最長 30 秒（含生成時間），超過後由前端顯示重試提示

---

## 7. 端點定義

> **說明**：每個端點列出 Method、Path、auth scope、Request Schema（簡明 JSON）、Response Schema（簡明 JSON）與 Status Codes。欄位名與型別對齊契約 E/F 章。

---

### 7.1 認證與個人資料 (auth/login, auth/me)

login 端點規格詳見 §4.1.1。

#### GET /api/v1/auth/me

取得當前登入直銷商資訊。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "id": "usr_abc123",
    "tenant_id": "tnt_abc123",
    "email": "amy@example.com",
    "display_name": "Amy Lin",
    "role": "distributor",
    "phone": "+886912345678",
    "plan": "pro",
    "plan_expires_at": "2026-07-02T00:00:00Z",
    "is_active": true,
    "locale": "zh-TW",
    "care_streak": 7,
    "created_at": "2026-05-01T00:00:00Z",
    "updated_at": "2026-06-02T10:00:00Z"
  }
}
```

---

#### PUT /api/v1/auth/me

更新個人資料。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | distributor |

**Request：**

```json
{
  "display_name": "Amy Lin",
  "phone": "+886912345678",
  "locale": "zh-TW"
}
```

所有欄位均為可選（partial update）。

**Response 200：** 回傳更新後的 distributor 物件（同 GET /auth/me 格式）。

**Status Codes：** 200 OK / 422 VALIDATION_ERROR

---

#### GET /api/v1/auth/me/usage-quota

取得今日配額使用狀況。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "id": "uqt_abc123",
    "quota_date": "2026-06-02",
    "contacts_total": 25,
    "drafts_used_today": 2,
    "voice_used_today": 1,
    "ai_cost_usd_today": 0.085,
    "drafts_limit": 5,
    "voice_limit": 3,
    "contacts_limit": 30,
    "cost_limit_usd": 0.30,
    "updated_at": "2026-06-02T10:30:00Z"
  }
}
```

---

### 7.2 T01 關係記憶活檔案 (contacts)

#### GET /api/v1/contacts

列出直銷商的所有聯絡人（游標分頁）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：**

| 參數 | 型別 | 說明 |
|---|---|---|
| `cursor` | string | 游標（上頁最後一筆 contact_id） |
| `limit` | integer | 每頁筆數，預設 20，最大 100 |
| `q` | string | 全文搜尋（display_name、phone） |
| `relationship_type` | string | 過濾關係類型 enum |
| `current_emotion` | string | 過濾情緒狀態 |
| `is_archived` | boolean | 是否包含已封存，預設 false |
| `sort` | string | 排序欄位：`last_interaction_at`（預設）、`created_at`、`display_name` |
| `order` | string | `asc` 或 `desc`，預設 `desc` |

**Response 200：**

```json
{
  "data": [
    {
      "id": "ctc_abc123",
      "distributor_id": "usr_abc123",
      "tenant_id": "tnt_abc123",
      "display_name": "Anna Chen",
      "phone": "+886922123456",
      "health_concerns": ["睡眠改善", "壓力舒緩"],
      "interests": ["瑜珈", "烘焙"],
      "communication_pref": "line",
      "relationship_type": "customer",
      "last_interaction_at": "2026-06-01T20:00:00Z",
      "dormant_since": null,
      "current_emotion": "neutral",
      "emotion_updated_at": "2026-06-01T19:30:00Z",
      "salesy_streak_count": 0,
      "is_archived": false,
      "created_at": "2026-05-10T00:00:00Z",
      "updated_at": "2026-06-01T20:00:00Z"
    }
  ],
  "pagination": {
    "next_cursor": "ctc_xyz789",
    "has_more": true,
    "limit": 20
  }
}
```

**Status Codes：** 200 OK / 401 UNAUTHORIZED

---

#### POST /api/v1/contacts

建立新聯絡人。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request（ContactCreate schema）：**

```json
{
  "display_name": "Bella Wang",
  "phone": "+886933456789",
  "health_concerns": ["體重管理"],
  "family_info": {"spouse": true, "children": 2},
  "job_info": {"title": "教師", "company": "國小"},
  "interests": ["閱讀"],
  "communication_pref": "line",
  "relationship_type": "friend"
}
```

`display_name` 為必填，其餘均可選。

**Response 201：** 回傳建立的 contact 物件。

**Status Codes：** 201 Created / 422 VALIDATION_ERROR / 429 QUOTA_EXCEEDED（contacts 上限）

---

#### GET /api/v1/contacts/{contact_id}

取得單一聯絡人詳情，含最近 5 次互動摘要。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "id": "ctc_abc123",
    "display_name": "Anna Chen",
    "phone": "+886922123456",
    "health_concerns": ["睡眠改善"],
    "family_info": {"spouse": true, "children": 1},
    "job_info": {"title": "上班族"},
    "interests": ["瑜珈"],
    "communication_pref": "line",
    "relationship_type": "customer",
    "last_interaction_at": "2026-06-01T20:00:00Z",
    "dormant_since": null,
    "recruitment_stage": null,
    "current_emotion": "neutral",
    "emotion_updated_at": "2026-06-01T19:30:00Z",
    "salesy_streak_count": 0,
    "is_archived": false,
    "created_at": "2026-05-10T00:00:00Z",
    "updated_at": "2026-06-01T20:00:00Z",
    "recent_interactions": [
      {
        "id": "itr_abc123",
        "interaction_type": "message_sent",
        "channel": "line",
        "summary": "關心睡眠狀況，Anna 說最近壓力大",
        "occurred_at": "2026-06-01T20:00:00Z"
      }
    ],
    "upcoming_life_events": [
      {
        "id": "evt_abc123",
        "event_type": "birthday",
        "event_date": "2026-06-09",
        "description": "Anna 生日"
      }
    ]
  }
}
```

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### PUT /api/v1/contacts/{contact_id}

更新聯絡人資料（partial update）。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | distributor |

**Request：** 同 ContactCreate，所有欄位均可選。

**Response 200：** 回傳更新後的 contact 物件。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### DELETE /api/v1/contacts/{contact_id}

封存聯絡人（軟刪除，設 `is_archived = true`）。

| 項目 | 值 |
|---|---|
| Method | DELETE |
| Auth Scope | distributor |

**Response 204：** No Content

**Status Codes：** 204 No Content / 404 NOT_FOUND

---

#### POST /api/v1/contacts/{contact_id}/parse-text

貼上對話文字補資料（AI 抽取，Sonnet 4.6，沿用既有框架）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "raw_text": "Anna 說她最近睡不好，老公剛換工作壓力大，兩個小孩都要顧"
}
```

**Response 200：**

```json
{
  "data": {
    "suggested_updates": {
      "health_concerns": ["睡眠改善"],
      "family_info": {"spouse": true, "children": 2},
      "interests": []
    },
    "extracted_life_events": [
      {
        "event_type": "job_change",
        "description": "老公換工作",
        "source": "ai_extracted"
      }
    ],
    "interaction_logged": {
      "id": "itr_xyz123",
      "interaction_type": "text_parsed",
      "summary": "Anna 提到睡眠問題與老公換工作"
    }
  }
}
```

前端應顯示 `suggested_updates` 讓直銷商確認後套用（不自動更新 contact）。

**Status Codes：** 200 OK / 404 NOT_FOUND / 429 COST_LIMIT_REACHED

---

#### POST /api/v1/contacts/{contact_id}/parse-image

上傳截圖補資料（OCR + AI 抽取，沿用既有框架）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |
| Content-Type | `multipart/form-data` |

**Request：**

```
image: <binary file> (JPEG/PNG, max 10MB)
```

**Response 200：** 同 parse-text 格式，`interaction_type` 為 `image_parsed`。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR（非圖片格式）/ 429 COST_LIMIT_REACHED

---

#### POST /api/v1/contacts/{contact_id}/parse-audio

語音備忘錄補資料（STT + AI 抽取，沿用既有框架）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |
| Content-Type | `multipart/form-data` |

**Request：**

```
audio: <binary file> (mp3/m4a/wav, max 5MB, ≤ 5 分鐘)
```

**Response 200：** 同 parse-text 格式，`interaction_type` 為 `audio_parsed`。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR / 429 COST_LIMIT_REACHED

---

### 7.3 互動記錄 (interactions)

> **自動互動紀錄（LINE OA）**：OA 管道的收訊（`inbound_messages`）與發送（`message_drafts.sent_at` / `voice_clips.sent_at`）由系統自動寫入互動時間軸（`source = 'line_oa'`），教練無需手動補登。自動紀錄**原文不可修改**（PUT 回 `422 IMMUTABLE_INTERACTION`），僅可透過 `note` 欄位加註；手動補登紀錄（`source = 'manual'`）可自由編輯。GET 列表回應每筆含 `source` 欄位供前端標示來源。

#### POST /api/v1/contacts/{contact_id}/interactions

新增互動記錄。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "interaction_type": "message_sent",
  "channel": "line",
  "summary": "關心 Anna 睡眠狀況，分享作息小技巧",
  "raw_input": "Anna，最近睡得好一點了嗎？",
  "is_salesy": false,
  "occurred_at": "2026-06-02T10:00:00Z"
}
```

`occurred_at` 可選，預設為請求時間。送出後後端非同步更新 `contacts.last_interaction_at` 與 `salesy_streak_count`。

**Response 201：** 回傳建立的 contact_interaction 物件。

**Status Codes：** 201 Created / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### GET /api/v1/contacts/{contact_id}/interactions

列出互動歷史（游標分頁）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`（預設 20）、`interaction_type`（過濾）

**Response 200：** 游標分頁標準格式，data 為 contact_interaction 陣列。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

### 7.4 T02 生活事件雷達 (life-events)

#### GET /api/v1/contacts/{contact_id}/life-events

列出單一聯絡人的生活事件。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`、`event_type`（過濾）

**Response 200：**

```json
{
  "data": [
    {
      "id": "evt_abc123",
      "contact_id": "ctc_abc123",
      "event_type": "birthday",
      "event_date": "2026-06-09",
      "description": "Anna 生日",
      "is_recurring": true,
      "source": "manual",
      "notified_at": null,
      "created_at": "2026-05-15T00:00:00Z"
    }
  ],
  "pagination": {...}
}
```

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/contacts/{contact_id}/life-events

手動新增生活事件。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "event_type": "birthday",
  "event_date": "2026-06-09",
  "description": "Anna 生日",
  "is_recurring": true
}
```

`event_type` enum: `birthday / anniversary / baby_birth / job_change / health_topic / custom`

**Response 201：** 回傳建立的 life_event 物件。

**Status Codes：** 201 Created / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### PUT /api/v1/contacts/{contact_id}/life-events/{event_id}

更新生活事件。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | distributor |

**Request：** 同 POST，所有欄位可選。

**Response 200：** 回傳更新後物件。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### DELETE /api/v1/contacts/{contact_id}/life-events/{event_id}

刪除生活事件（硬刪除）。

| 項目 | 值 |
|---|---|
| Method | DELETE |
| Auth Scope | distributor |

**Response 204：** No Content

**Status Codes：** 204 No Content / 404 NOT_FOUND

---

### 7.5 T03 語氣／情緒感測器 (emotion)

AI 層說明：情緒感測器使用 Haiku 4.5 三檔分類，沿用既有框架，本次不重新設計。

#### POST /api/v1/contacts/{contact_id}/emotion/detect

觸發情緒感測（送入近期訊息文字，回傳三檔結果）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "input_text": "Anna 說：最近工作好忙，覺得快爆炸了，壓力超大，晚上又睡不好"
}
```

**Response 200：**

```json
{
  "data": {
    "id": "emo_abc123",
    "contact_id": "ctc_abc123",
    "emotion": "stressed",
    "confidence": 0.92,
    "model_used": "haiku-4-5",
    "latency_ms": 380,
    "created_at": "2026-06-02T10:30:00Z"
  },
  "recommendation": "今天壓力大，先別提產品 — 純關懷就好"
}
```

`emotion` enum: `stressed / neutral / happy`

後端在返回前非同步更新 `contacts.current_emotion` 與 `contacts.emotion_updated_at`，並寫入 `learning_logs`。

**Status Codes：** 200 OK / 404 NOT_FOUND / 429 COST_LIMIT_REACHED

---

#### GET /api/v1/contacts/{contact_id}/emotion/latest

取得最新情緒感測結果。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：** 回傳最新一筆 emotion_reading 物件（無記錄時 `data: null`）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### PUT /api/v1/contacts/{contact_id}/emotion/override

直銷商手動覆蓋情緒值（AI 判斷不準確時）。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | distributor |

**Request：**

```json
{
  "emotion": "happy",
  "reading_id": "emo_abc123"
}
```

**Response 200：** 回傳更新後的 emotion_reading 物件（`overridden_by_user: true`）。

後端寫入 `learning_logs`（`event_type: emotion_read`，`metadata.overridden: true`）。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

### 7.6 T04 太業務員警報 (salesy-alerts)

AI 層說明：太業務員警報為純規則引擎（產品關鍵字 + URL pattern，連 3 則觸發），沿用既有框架，本次不重新設計。

#### GET /api/v1/contacts/{contact_id}/salesy-alerts

列出此聯絡人的太業務員警報記錄。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`

**Response 200：**

```json
{
  "data": [
    {
      "id": "sal_abc123",
      "contact_id": "ctc_abc123",
      "triggered_at": "2026-06-01T15:00:00Z",
      "salesy_count": 3,
      "acknowledged": false,
      "dismissed": false,
      "dismiss_reason": null,
      "care_draft_id": "dft_care_xyz",
      "created_at": "2026-06-01T15:00:00Z"
    }
  ],
  "pagination": {...}
}
```

---

#### GET /api/v1/salesy-alerts

列出當前直銷商所有未確認的太業務員警報（跨所有聯絡人）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`、`acknowledged`（boolean，預設 false 只看未確認）

**Response 200：** 標準游標分頁格式，data 為 salesy_alert 陣列。

---

#### POST /api/v1/salesy-alerts/{alert_id}/acknowledge

確認警報（標記已看，但不關掉）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**Response 200：**

```json
{
  "data": {
    "id": "sal_abc123",
    "acknowledged": true
  }
}
```

後端寫入 `learning_logs`（`event_type: salesy_alert_acknowledged`）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/salesy-alerts/{alert_id}/dismiss

關掉此次警示（需填原因，用於規則調整）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "dismiss_reason": "這位客戶自己問的，不是我主動推"
}
```

**Response 200：** 回傳更新後的 salesy_alert 物件（`dismissed: true`）。

後端寫入 `learning_logs`（`event_type: salesy_alert_dismissed`，`metadata.dismiss_reason: ...`）。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR（dismiss_reason 為必填）

---

### 7.7 T05 今日 5 件事 (today-tasks)

今日任務由 APScheduler 每日凌晨 06:00（台北時間，UTC+8 = 22:00 UTC）批次產生，直銷商開 App 時呼叫 GET 取得。

#### GET /api/v1/today-tasks

取得今日任務卡（最多 5 張，依優先序排列）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": [
    {
      "id": "tsk_abc123",
      "contact_id": "ctc_abc123",
      "contact_display_name": "Bella Wang",
      "task_date": "2026-06-02",
      "priority": 1,
      "source_type": "life_event",
      "source_id": "evt_abc123",
      "reason": "下週日（6/9）是 Bella 生日",
      "cta_label": "寫關懷訊息",
      "status": "pending",
      "completed_at": null,
      "created_at": "2026-06-02T22:00:00Z"
    },
    {
      "id": "tsk_def456",
      "contact_id": "ctc_def456",
      "contact_display_name": "Cathy Liu",
      "task_date": "2026-06-02",
      "priority": 2,
      "source_type": "sample_followup",
      "source_id": "sfu_def456",
      "reason": "Cathy 的樣品 48 小時跟進到了",
      "cta_label": "跟進樣品",
      "status": "pending",
      "completed_at": null,
      "created_at": "2026-06-02T22:00:00Z"
    }
  ],
  "meta": {
    "total_today": 5,
    "completed_today": 1,
    "care_streak": 7
  }
}
```

`source_type` enum: `life_event / sample_followup / dormant / recruitment / salesy_alert`

優先序邏輯（後端實作，非 API 參數）：`life_event > sample_followup > dormant > recruitment > salesy_alert`

**Status Codes：** 200 OK

---

#### POST /api/v1/today-tasks/{task_id}/complete

標記任務完成。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**Response 200：**

```json
{
  "data": {
    "id": "tsk_abc123",
    "status": "done",
    "completed_at": "2026-06-02T10:35:00Z"
  },
  "meta": {
    "care_streak": 8,
    "completed_today": 2
  }
}
```

後端更新 `distributors.care_streak`（連續天數）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/today-tasks/{task_id}/snooze

延後任務（明日再排）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**Response 200：**

```json
{"data": {"id": "tsk_abc123", "status": "snoozed"}}
```

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/today-tasks/{task_id}/dismiss

略過此次任務（不再排入明日）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**Response 200：**

```json
{"data": {"id": "tsk_abc123", "status": "dismissed"}}
```

**Status Codes：** 200 OK / 404 NOT_FOUND

---

### 7.8 T06 訊息草稿 (message-drafts)

AI 層說明：Haiku 4.5 生成首字（< 500ms）、Sonnet 4.6 接手全文 streaming，沿用既有框架，本次不重新設計。SSE 串流詳見第 6 章。

三道前置檢查（生成前執行）：
1. 情緒感測（讀取 `contacts.current_emotion`，若 `stressed` 強制 `tone=care`，收起 `business` tab）
2. 太業務員警報（讀取 `contacts.salesy_streak_count`，≥ 3 時顯示提醒）
3. 配額確認（讀取 `usage_quotas`）

#### POST /api/v1/message-drafts

生成草稿（非串流，適合配額不足時的 fallback 或後端批次）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request（MessageDraftRequest schema）：**

```json
{
  "contact_id": "ctc_abc123",
  "tone": "care",
  "channel": "line",
  "context_override": "今天想特別關心她最近的睡眠"
}
```

`context_override` 可選，提供額外生成上下文。

**Response 201：**

```json
{
  "data": {
    "id": "dft_abc123",
    "contact_id": "ctc_abc123",
    "tone": "care",
    "channel": "line",
    "content": "Anna，最近睡得好一點了嗎？我看到一個很好的睡眠方法，想分享給你...",
    "compliance_status": "green",
    "compliance_check_id": "cck_abc123",
    "adopted": false,
    "model_used": "sonnet-4-6",
    "latency_ms": 2100,
    "created_at": "2026-06-02T10:30:00Z"
  }
}
```

**Status Codes：** 201 Created / 404 NOT_FOUND / 422 COMPLIANCE_RED_BLOCKED / 429 QUOTA_EXCEEDED / 429 COST_LIMIT_REACHED

---

#### POST /api/v1/message-drafts/stream

生成草稿（SSE 串流版，推薦使用）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |
| Response Content-Type | `text/event-stream` |

**Request：** 同 POST /message-drafts（MessageDraftRequest schema）。

**Response：** SSE 事件流（詳見第 6 章）。

**Status Codes：** 200 OK（連線建立）/ 429 QUOTA_EXCEEDED（連線前配額確認失敗，以 JSON 回傳）

---

#### GET /api/v1/message-drafts/{draft_id}

取得單一草稿。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：** 回傳 message_draft 物件（同 POST response 格式）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/message-drafts/{draft_id}/adopt

直銷商複製/使用草稿前呼叫，記錄採用行為。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**Response 200：**

```json
{
  "data": {
    "id": "dft_abc123",
    "adopted": true,
    "adopted_at": "2026-06-02T10:35:00Z"
  }
}
```

後端非同步寫入 `learning_logs`（`event_type: draft_adopted`）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### GET /api/v1/contacts/{contact_id}/message-drafts

列出此聯絡人的草稿歷史。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`、`tone`（過濾）、`compliance_status`（過濾）

**Response 200：** 標準游標分頁格式。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

### 7.9 T07 樣品追蹤 (samples)

AI 層說明：樣品跟進草稿使用 Haiku 4.5，沿用既有框架，本次不重新設計。

新增樣品後，APScheduler 自動排定三個跟進提醒（48h / 72h / 7d），並在提醒時間到時觸發今日 5 件事任務卡產生。

#### GET /api/v1/contacts/{contact_id}/samples

列出此聯絡人的樣品記錄。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`、`status`（過濾）

**Response 200：**

```json
{
  "data": [
    {
      "id": "smp_abc123",
      "contact_id": "ctc_abc123",
      "product_name": "精油套組 A",
      "sent_at": "2026-06-01T10:00:00Z",
      "status": "sent",
      "converted": false,
      "notes": "Cathy 說想試試看精油",
      "created_at": "2026-06-01T10:00:00Z",
      "updated_at": "2026-06-01T10:00:00Z"
    }
  ],
  "pagination": {...}
}
```

`status` enum: `sent / followed_up_48h / followed_up_72h / followed_up_7d / converted / not_converted / cancelled`

---

#### POST /api/v1/contacts/{contact_id}/samples

新增樣品記錄（觸發自動排定跟進提醒）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request（SampleCreate schema）：**

```json
{
  "product_name": "精油套組 A",
  "product_id": "prd_abc123",
  "sent_at": "2026-06-01T10:00:00Z",
  "notes": "Cathy 說想試試看精油"
}
```

`product_id` 可選（有品牌產品庫時帶入），`sent_at` 預設為請求時間。

**Response 201：** 回傳 sample 物件 + 自動建立的 sample_followups 陣列。

```json
{
  "data": {
    "id": "smp_abc123",
    "status": "sent",
    "followups_scheduled": [
      {"id": "sfu_abc001", "followup_type": "h48", "followup_at": "2026-06-03T10:00:00Z", "status": "pending"},
      {"id": "sfu_abc002", "followup_type": "h72", "followup_at": "2026-06-04T10:00:00Z", "status": "pending"},
      {"id": "sfu_abc003", "followup_type": "d7", "followup_at": "2026-06-08T10:00:00Z", "status": "pending"}
    ]
  }
}
```

**Status Codes：** 201 Created / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### PUT /api/v1/contacts/{contact_id}/samples/{sample_id}

更新樣品狀態（含回填轉換結果）。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | distributor |

**Request：**

```json
{
  "status": "converted",
  "converted": true,
  "converted_at": "2026-06-05T14:00:00Z",
  "notes": "Cathy 訂了兩瓶"
}
```

**Response 200：** 回傳更新後的 sample 物件。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### GET /api/v1/samples

列出當前直銷商所有待跟進樣品（跨聯絡人）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`、`status`（預設排除 `converted` 和 `not_converted`）

**Response 200：** 標準游標分頁格式，data 陣列包含 sample + contact 基本資料。

---

#### GET /api/v1/samples/{sample_id}/followups

列出樣品跟進提醒。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": [
    {
      "id": "sfu_abc001",
      "sample_id": "smp_abc123",
      "followup_at": "2026-06-03T10:00:00Z",
      "followup_type": "h48",
      "status": "pending",
      "draft_id": null,
      "notified_at": null,
      "created_at": "2026-06-01T10:00:00Z"
    }
  ]
}
```

---

### 7.10 T08 語音草稿 (voice-clips)

AI 層說明：TTS 使用 `VoiceProvider` 抽象介面（OpenAI TTS 或 ElevenLabs，W4 前確認供應商），沿用既有框架，本次不重新設計。

#### POST /api/v1/voice-clips

從草稿生成語音（指定 draft_id、聲音風格、語言）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request（VoiceClipRequest schema）：**

```json
{
  "draft_id": "dft_abc123",
  "voice_style": "warm_female",
  "language": "zh-TW"
}
```

`voice_style` enum: `warm_female / neutral_male`
`language` enum: `zh-TW / en-US`

後端驗證草稿文字轉語音預估長度 ≤ 60 秒，超過則回 `422 VOICE_DURATION_EXCEEDED`。

**Response 201：**

```json
{
  "data": {
    "id": "voc_abc123",
    "draft_id": "dft_abc123",
    "voice_style": "warm_female",
    "language": "zh-TW",
    "duration_seconds": 25,
    "storage_url": "https://storage.carecopilot.ai/voice/voc_abc123.m4a",
    "provider": "openai",
    "cost_usd": 0.012,
    "expires_at": "2026-06-09T10:30:00Z",
    "created_at": "2026-06-02T10:30:00Z"
  }
}
```

語音檔格式為 m4a（AAC，LINE audio message 要求）。保存期雙軌：**未發送** 7 天後自動刪除；**已透過 OA 發送**（見 `/send`）保存至 `retention_until = sent_at + 30 天`（APScheduler 清理排程依 `retention_until` 刪除）。

**Status Codes：** 201 Created / 404 NOT_FOUND（draft_id 不存在）/ 422 VOICE_DURATION_EXCEEDED / 429 QUOTA_EXCEEDED / 429 COST_LIMIT_REACHED

---

#### GET /api/v1/voice-clips/{clip_id}

取得語音檔資訊（含 storage_url）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：** 回傳 voice_clip 物件（同 POST response 格式）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/voice-clips/{clip_id}/download

記錄下載事件（採用指標）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**Response 200：**

```json
{"data": {"id": "voc_abc123", "downloaded_at": "2026-06-02T10:35:00Z"}}
```

後端寫入 `learning_logs`（`event_type: voice_downloaded`）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/voice-clips/{clip_id}/listen

記錄教練試聽事件（發送前置條件）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**Response 200：**

```json
{"data": {"id": "voc_abc123", "listened_at": "2026-06-02T10:33:00Z"}}
```

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/voice-clips/{clip_id}/send

教練試聽後將語音以 LINE audio message push 發送給 OA 客戶（G.6：人工審核硬限制）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body。

**後端處理流程：**

1. 檢查 `listened_at` 已存在；否則回 `422 VOICE_NOT_LISTENED`（未試聽不可發）
2. 檢查對應草稿 `compliance_status != 'red'`；紅燈→回 `422 COMPLIANCE_RED_BLOCKED`
3. 檢查草稿文字自語音生成後未被修改；已修改→回 `409 VOICE_STALE`（須重新生成語音並重掃合規）
4. 取得 contact 的 `line_user_id`；若無（非 OA 客戶）→回 `422 VALIDATION_ERROR`
5. 呼叫 LINE Messaging API push audio message（`originalContentUrl` = HTTPS 可達 URL、`duration` 毫秒）；失敗→`502 LINE_PUSH_FAILED`
6. 成功→回填 `voice_clips.sent_at`、`voice_clips.line_message_id`、`retention_until = sent_at + 30d`；寫入 `learning_logs`（`event_type: voice_sent`）；自動寫入互動時間軸

**Response 200：**

```json
{
  "data": {
    "id": "voc_abc123",
    "sent_at": "2026-06-02T10:35:00Z",
    "line_message_id": "line_msg_xyz",
    "retention_until": "2026-07-02T10:35:00Z"
  }
}
```

**Status Codes：** 200 OK / 404 NOT_FOUND / 409 VOICE_STALE / 422 VOICE_NOT_LISTENED / 422 COMPLIANCE_RED_BLOCKED / 422 VALIDATION_ERROR（無 line_user_id）/ 502 LINE_PUSH_FAILED

---

#### DELETE /api/v1/voice-clips/{clip_id}

提前刪除語音檔（從物件儲存移除）。**已發送**（`sent_at` 非空）且仍在保存期內的語音不可刪除（客戶重播期），回 `409 VOICE_RETENTION_ACTIVE`。

| 項目 | 值 |
|---|---|
| Method | DELETE |
| Auth Scope | distributor |

**Response 204：** No Content

**Status Codes：** 204 No Content / 404 NOT_FOUND / 409 VOICE_RETENTION_ACTIVE

---

### 7.11 T09 快速異議處理器 (objection-responses)

AI 層說明：異議回應使用 Haiku 4.5 速度優先，沿用既有框架，本次不重新設計。

#### GET /api/v1/objection-templates

列出 10 種預設異議模板。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": [
    {
      "id": "obt_abc123",
      "key": "spouse_oppose",
      "label_zh": "先生／家人反對",
      "description": "另一半不支持加入或購買的情況",
      "is_active": true,
      "sort_order": 1
    },
    {
      "id": "obt_def456",
      "key": "too_expensive",
      "label_zh": "太貴了",
      "description": "客戶覺得產品或加入費用超出預算",
      "is_active": true,
      "sort_order": 2
    }
  ]
}
```

預設 10 種 key：`spouse_oppose / too_expensive / try_first / family_not_support / effectiveness_doubt / no_time / already_have_product / mlm_fear / income_doubt / need_think`

---

#### POST /api/v1/objection-responses

生成三種風格的異議回應。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "contact_id": "ctc_abc123",
  "objection_template_id": "obt_abc123",
  "objection_text": "我先生不太能接受 MLM"
}
```

`objection_template_id` 與 `objection_text` 至少填一個；兩者都填時以 `objection_text` 為準。

**Response 201：**

```json
{
  "data": {
    "id": "obr_abc123",
    "contact_id": "ctc_abc123",
    "objection_template_id": "obt_abc123",
    "objection_text": "我先生不太能接受 MLM",
    "response_empathy": "我懂這個感覺，我先生一開始也是這樣⋯⋯",
    "response_question": "請問他主要擔心的是時間還是金錢？",
    "response_invite": "要不要找一天我們三個一起喝杯咖啡，讓他直接問？",
    "adopted_style": null,
    "model_used": "haiku-4-5",
    "created_at": "2026-06-02T10:30:00Z"
  }
}
```

**Status Codes：** 201 Created / 404 NOT_FOUND / 429 COST_LIMIT_REACHED

---

#### POST /api/v1/objection-responses/{response_id}/adopt

標記採用的回應風格（直銷商選擇後呼叫）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{"adopted_style": "question"}
```

`adopted_style` enum: `empathy / question / invite / none`

**Response 200：** 回傳更新後的 objection_response 物件。

後端寫入 `learning_logs`（`event_type: objection_used`）。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

### 7.12 T10 健康問卷 (questionnaire)

問卷為可選工具（非主流程），不在首頁顯示，不主動跳提醒。
客戶填寫端點（`/{token}` 相關）為**公開端點**，無需 JWT。

AI 層說明：問卷摘要使用 Sonnet 4.6，沿用既有框架，本次不重新設計。

#### GET /api/v1/questionnaire-templates

列出可用問卷模板。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": [
    {
      "id": "qtpl_abc123",
      "name": "健康關注評估問卷 v1",
      "version": "1.0",
      "is_active": true,
      "question_count": 12,
      "created_at": "2026-05-01T00:00:00Z"
    }
  ]
}
```

---

#### POST /api/v1/contacts/{contact_id}/questionnaire-links

為聯絡人生成問卷連結（7 天有效，一次性）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{"template_id": "qtpl_abc123"}
```

**Response 201：**

```json
{
  "data": {
    "id": "qlnk_abc123",
    "token": "rnd_a1b2c3d4e5f6",
    "share_url": "https://app.carecopilot.ai/q/rnd_a1b2c3d4e5f6",
    "expires_at": "2026-06-09T10:30:00Z",
    "is_active": true,
    "created_at": "2026-06-02T10:30:00Z"
  }
}
```

**Status Codes：** 201 Created / 404 NOT_FOUND（contact 或 template 不存在）/ 422 VALIDATION_ERROR

---

#### GET /api/v1/questionnaire-links/{token}

客戶端取得問卷題目（**公開端點**，無需 JWT）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | public |

**Response 200：**

```json
{
  "data": {
    "template_name": "健康關注評估問卷 v1",
    "questions": [
      {
        "id": "q01",
        "order": 1,
        "type": "single_choice",
        "text": "你目前最主要的健康關注是？",
        "options": ["睡眠品質", "體重管理", "壓力舒緩", "消化健康", "精力提升"]
      },
      {
        "id": "q02",
        "order": 2,
        "type": "scale",
        "text": "你目前的睡眠品質如何？（1=非常差，5=非常好）",
        "min": 1,
        "max": 5
      }
    ],
    "expires_at": "2026-06-09T10:30:00Z"
  }
}
```

**Status Codes：** 200 OK / 410 QUESTIONNAIRE_LINK_EXPIRED / 410 QUESTIONNAIRE_LINK_USED

---

#### POST /api/v1/questionnaire-links/{token}/submit

客戶端提交填答（**公開端點**，無需 JWT，觸發 Sonnet 4.6 AI 摘要）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | public |

**Request（QuestionnaireSubmit schema）：**

```json
{
  "answers": {
    "q01": "睡眠品質",
    "q02": 2,
    "q03": "最近睡眠非常差，入睡困難"
  },
  "submitted_at": "2026-06-02T11:00:00Z"
}
```

後端接收後：
1. 儲存 `questionnaire_responses` 記錄
2. 非同步觸發 Sonnet 4.6 生成 `ai_summary` 與 `care_angle`
3. 摘要生成後過合規 Gate（compliance_sidecar）
4. 更新 `contacts` 相關欄位（health_concerns 等）
5. 通知直銷商（App push 或今日 5 件事新增卡片）

**Response 202：**（非同步處理，立即回應）

```json
{
  "data": {
    "message": "感謝您的填寫！您的結果正在處理中，直銷商將會收到通知。",
    "response_id": "qrsp_abc123"
  }
}
```

**Status Codes：** 202 Accepted / 410 QUESTIONNAIRE_LINK_EXPIRED / 410 QUESTIONNAIRE_LINK_USED / 422 VALIDATION_ERROR

---

#### GET /api/v1/contacts/{contact_id}/questionnaire-responses

取得此聯絡人的問卷回覆與摘要。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": [
    {
      "id": "qrsp_abc123",
      "link_id": "qlnk_abc123",
      "ai_summary": "Anna 主要關注睡眠品質改善，目前睡眠評分 2/5，入睡困難，有明顯壓力因素",
      "care_angle": "建議以睡眠與壓力管理為主要關懷切角，避免直接提及療效，以生活習慣分享為主",
      "compliance_status": "green",
      "submitted_at": "2026-06-02T11:00:00Z",
      "processed_at": "2026-06-02T11:02:30Z",
      "created_at": "2026-06-02T11:00:00Z"
    }
  ],
  "pagination": {...}
}
```

---

### 7.13 T11 招募漏斗 (recruitment)

AI 層說明：招募話術草稿使用 Sonnet 4.6，走最嚴格合規檢查（FTC 收入保證），沿用既有框架，本次不重新設計。

#### GET /api/v1/contacts/{contact_id}/recruitment-stage

取得聯絡人招募階段。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "id": "rcs_abc123",
    "contact_id": "ctc_abc123",
    "stage": "exposure",
    "stage_entered_at": "2026-05-20T00:00:00Z",
    "stage_history": [
      {"stage": "warm_list", "entered_at": "2026-05-10T00:00:00Z"},
      {"stage": "exposure", "entered_at": "2026-05-20T00:00:00Z"}
    ],
    "notes": "已試用樣品，正在考慮",
    "updated_at": "2026-05-20T00:00:00Z"
  }
}
```

`stage` enum: `warm_list / exposure / invitation / signed`

**Status Codes：** 200 OK / 404 NOT_FOUND（無招募記錄時回傳 `data: null`）

---

#### PUT /api/v1/contacts/{contact_id}/recruitment-stage

更新招募階段（觸發合規檢查；stage 前進時同步更新 stage_history）。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | distributor |

**Request：**

```json
{
  "stage": "invitation",
  "notes": "Cathy 對加入感興趣，安排下週見面"
}
```

**Response 200：** 回傳更新後的 recruitment_stage 物件。

**Status Codes：** 200 OK / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### GET /api/v1/recruitment/funnel

取得直銷商個人招募漏斗統計（四階段各自人數）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "warm_list": 12,
    "exposure": 5,
    "invitation": 2,
    "signed": 1,
    "total": 20,
    "conversion_rates": {
      "warm_list_to_exposure": 0.42,
      "exposure_to_invitation": 0.40,
      "invitation_to_signed": 0.50
    }
  }
}
```

---

#### GET /api/v1/recruitment/team-funnel

Leader 專屬：取得下線團隊漏斗統計。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | leader |

**Response 200：**

```json
{
  "data": {
    "team_total": 5,
    "team_funnel": {
      "warm_list": 45,
      "exposure": 18,
      "invitation": 7,
      "signed": 3
    },
    "per_member": [
      {
        "distributor_id": "usr_member1",
        "display_name": "Amy Lin",
        "warm_list": 12,
        "exposure": 5,
        "invitation": 2,
        "signed": 1
      }
    ]
  }
}
```

**Status Codes：** 200 OK / 403 FORBIDDEN（非 leader 角色）

---

### 7.14 合規低語 (compliance)

AI 層說明：合規低語為 regex sidecar（純 Python re，< 50ms），沿用既有框架，本次不重新設計。

#### POST /api/v1/compliance/check

主動送文字做合規掃描（回傳 ComplianceResult）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "text": "保證一週瘦 5 公斤，效果立即見效",
  "source_type": "message_draft",
  "source_id": "dft_abc123"
}
```

`source_type` enum: `message_draft / sample_followup / voice_clip / objection_response / questionnaire_summary / recruitment_draft`

**Response 200（ComplianceResult schema）：**

```json
{
  "data": {
    "id": "cck_abc123",
    "result": "red",
    "triggered_terms": ["保證", "立即見效"],
    "suggestion": "改寫成「我自己用了一陣子，感覺作息有些變化，分享給你參考」",
    "latency_ms": 18,
    "created_at": "2026-06-02T10:30:00Z"
  }
}
```

`result` enum: `green / yellow / red`

100% 寫入 `compliance_checks` 資料表（稽核依據）。

**Status Codes：** 200 OK / 422 VALIDATION_ERROR

---

#### GET /api/v1/compliance/checks/{check_id}

取得單一合規檢查記錄。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：** 回傳 compliance_check 物件。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### GET /api/v1/contacts/{contact_id}/compliance-checks

列出此聯絡人相關的合規檢查歷史。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`、`result`（過濾：green/yellow/red）

**Response 200：** 標準游標分頁格式。

---

### 7.15 平台支撐 (subscription / usage / consent / data-requests)

#### GET /api/v1/subscription

取得當前直銷商訂閱狀態。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "id": "sub_abc123",
    "plan": "pro",
    "status": "active",
    "current_period_start": "2026-06-01T00:00:00Z",
    "current_period_end": "2026-07-01T00:00:00Z",
    "amount_usd": 39.00,
    "payment_provider": "stripe",
    "created_at": "2026-06-01T00:00:00Z"
  }
}
```

`plan` enum: `freemium / pro / pro_plus / leader_team / top_leader / design_partner`

---

#### POST /api/v1/subscription/upgrade

升級訂閱方案（觸發 Stripe Checkout Session）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{"target_plan": "pro"}
```

**Response 200：**

```json
{
  "data": {
    "checkout_url": "https://checkout.stripe.com/pay/cs_test_...",
    "expires_at": "2026-06-02T11:30:00Z"
  }
}
```

**Status Codes：** 200 OK / 422 VALIDATION_ERROR（已在該方案或更高方案）

---

#### GET /api/v1/usage

取得用量統計（今日 + 本月）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "today": {
      "drafts_used": 2,
      "drafts_limit": 5,
      "voice_used": 1,
      "voice_limit": 3,
      "ai_cost_usd": 0.085,
      "cost_limit_usd": 0.30
    },
    "month": {
      "drafts_total": 45,
      "voice_total": 12,
      "ai_cost_usd_total": 1.82,
      "care_actions_total": 38
    }
  }
}
```

---

#### GET /api/v1/contacts/{contact_id}/consents

取得聯絡人同意記錄。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": [
    {
      "id": "cns_abc123",
      "consent_type": "data_storage",
      "granted": true,
      "source": "verbal",
      "granted_at": "2026-05-10T00:00:00Z",
      "revoked_at": null
    }
  ]
}
```

`consent_type` enum: `data_storage / marketing / questionnaire`

---

#### POST /api/v1/contacts/{contact_id}/consents

新增同意記錄。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{
  "consent_type": "data_storage",
  "granted": true,
  "source": "verbal",
  "granted_at": "2026-05-10T00:00:00Z"
}
```

**Response 201：** 回傳建立的 consent 物件。

**Status Codes：** 201 Created / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### PUT /api/v1/contacts/{contact_id}/consents/{consent_id}/revoke

撤回同意。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | distributor |

**Request：** 無 body（撤回時間由後端設為 now()）。

**Response 200：** 回傳更新後的 consent 物件（`revoked_at` 已設定）。

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/contacts/{contact_id}/data-requests

代理提交資料請求（代理客戶提交 export/delete）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：**

```json
{"request_type": "export"}
```

`request_type` enum: `export / delete`
- `export`：30 天內處理，完成後提供 export_url
- `delete`：7 天內處理

**Response 201：**

```json
{
  "data": {
    "id": "drq_abc123",
    "request_type": "export",
    "status": "pending",
    "due_at": "2026-07-02T10:30:00Z",
    "created_at": "2026-06-02T10:30:00Z"
  }
}
```

**Status Codes：** 201 Created / 404 NOT_FOUND / 422 VALIDATION_ERROR

---

#### GET /api/v1/data-requests/{request_id}

查詢資料請求進度。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Response 200：**

```json
{
  "data": {
    "id": "drq_abc123",
    "request_type": "export",
    "status": "completed",
    "due_at": "2026-07-02T10:30:00Z",
    "completed_at": "2026-06-05T14:00:00Z",
    "export_url": "https://storage.carecopilot.ai/exports/drq_abc123.zip"
  }
}
```

`status` enum: `pending / processing / completed / failed`

---

### 7.16 學習紀錄 (learning-logs) [Internal]

學習紀錄主要由後端非同步寫入（fire-and-forget），v1 提供一個直銷商查詢自身紀錄的端點，用於透明度展示（讓直銷商了解 AI 如何學習其偏好）。

#### GET /api/v1/learning-logs

取得直銷商自身的學習紀錄（AI 操作歷史）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `cursor`、`limit`（預設 50）、`event_type`（過濾）

**Response 200：**

```json
{
  "data": [
    {
      "id": "lgl_abc123",
      "event_type": "draft_adopted",
      "source_type": "message_drafts",
      "source_id": "dft_abc123",
      "metadata": {
        "tone": "care",
        "model": "sonnet-4-6",
        "latency_ms": 1240
      },
      "created_at": "2026-06-02T10:35:00Z"
    }
  ],
  "pagination": {...}
}
```

`event_type` enum:
`emotion_read / draft_generated / draft_adopted / draft_rejected / salesy_alert_dismissed / salesy_alert_acknowledged / objection_used / compliance_triggered / compliance_overridden / voice_downloaded`

**Status Codes：** 200 OK

---

### 7.17 LINE 整合 (webhooks / inbox / message-drafts send / contacts assignment)

LINE 整合流程說明：每個租戶擁有一個 LINE Official Account（OA）。客戶傳訊給 OA 後，LINE 平台以 POST webhook 通知後端；後端找到或建立對應 contact、執行輪派、寫入 inbound_messages、生成待回覆任務卡、自動預生草稿（沿用 T06 流程，過合規 gate）；教練審核草稿後呼叫 send 端點，後端以 LINE Messaging API push message 發送給客戶。AI 不自動回覆；紅燈強制阻擋。

---

#### POST /api/v1/webhooks/line

接收 LINE 平台事件（**公開端點**，改用 X-Line-Signature HMAC-SHA256 驗證，非 JWT）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | public（X-Line-Signature 驗簽） |

**驗證流程：**

1. 讀取請求 header `X-Line-Signature`
2. 以對應租戶 OA 的 `channel_secret` 計算 HMAC-SHA256（raw request body）
3. Base64 encode 後與 header 值比對；不符→回 `401 LINE_SIGNATURE_INVALID`
4. 符合→進入冪等處理（以 `events[*].message.id` 去重，24 小時內重複請求直接回 200）

**Request（LINE Events Payload 摘要）：**

```json
{
  "destination": "Uxxxxx",
  "events": [
    {
      "type": "message",
      "replyToken": "nHuyWiB7yP5Zw52FIkcQobQuGDXCTA",
      "source": {
        "type": "user",
        "userId": "U206d25c2ea..."
      },
      "timestamp": 1462629479859,
      "message": {
        "id": "325708",
        "type": "text",
        "text": "你好，我想了解產品"
      }
    }
  ]
}
```

後端只處理 `events[*].type = "message"` 且 `message.type = "text"` 的事件；其他類型事件靜默忽略並回 200。

**後端內部處理（成功驗簽後）：**

1. 以 `source.userId`（line_user_id）查找 contacts；找不到→建立新 contact（`source = 'line_oa'`）並輪派給下一位 active 教練（依 `official_accounts.assignment_cursor`）
2. 寫入 `inbound_messages`（`status = 'new'`）
3. 寫入 `today_tasks`（`source_type = 'inbound_reply'`，推入被指派教練的今日 5 件事待回覆卡）
4. 非同步觸發**來訊自動分析（enrichment，單次 Haiku 三合一）**：情緒判讀（更新 `contacts.current_emotion`）、生活事件抽取（產生 T02 任務卡）、活檔案重點建議（寫入 `contact_suggestions`，status=pending）；分析失敗不影響收訊主流程（Sentry 告警）；成本計入教練每日配額，熔斷時跳過分析
5. 非同步觸發 T06 草稿預生成（帶 `in_reply_to_inbound_id`）；合規過紅燈時草稿狀態標 `compliance_red`，不自動發送

**Response 200：**（LINE 平台要求 5 秒內回覆 200，否則視為失敗）

```
HTTP 200 OK
Content-Type: application/json
{}
```

**Status Codes：** 200 OK / 401 LINE_SIGNATURE_INVALID

---

#### POST /api/v1/message-drafts/{draft_id}/send

教練審核草稿後發送（先過合規 gate；以 LINE Messaging API push message 發送）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 無 body（draft 內容已在 message_drafts 表中；可選附 `edited_content` 供教練最後編輯）

```json
{
  "edited_content": "Anna，最近睡得好一點了嗎？",
  "acknowledge_salesy": false
}
```

`edited_content` 可選；若提供則以此為最終發送文字（同步更新 `message_drafts.content`）並重跑合規掃描；若未提供則直接以 `message_drafts.content` 發送。
`acknowledge_salesy` 可選（預設 false）；收到 `409 SALESY_WARNING` 後教練確認仍要發送時帶 true 重送。

**後端處理流程：**

1. 合規檢查（compliance_sidecar 掃描）；紅燈→回 `422 COMPLIANCE_RED_BLOCKED`，拒絕發送
2. **太業務員發送前預警（T04）**：以 OA 管道自動累計的 `salesy_streak_count` 判定，若本則為推銷型且將構成連續第 3 則，且 request 未帶 `acknowledge_salesy: true` →回 `409 SALESY_WARNING`（含 `{"streak_count": 2, "care_draft_id": "dft_care_xxx"}`，附預生純關懷草稿）；前端彈出預警 dialog，教練確認後帶 `acknowledge_salesy: true` 重送（寫入 `salesy_alert_acknowledged` 學習紀錄）
3. 取得 contact 的 `line_user_id`；若無（non-OA 客戶）→回 `422 VALIDATION_ERROR`（`{"message": "此聯絡人無 LINE User ID，無法 push 發送"}`）
4. 呼叫 LINE Messaging API push message；失敗→回 `502 LINE_PUSH_FAILED`
5. 成功→回填 `message_drafts.sent_at`、`message_drafts.line_message_id`、`message_drafts.delivery_method = 'line_push'`；同步更新 `inbound_messages.status = 'replied'`；自動寫入互動時間軸並更新 `salesy_streak_count`

**Response 200：**

```json
{
  "data": {
    "draft_id": "dft_abc123",
    "sent_at": "2026-06-02T10:35:00Z",
    "line_message_id": "line_msg_xyz",
    "delivery_method": "line_push",
    "compliance_status": "green"
  }
}
```

**Status Codes：** 200 OK / 404 NOT_FOUND / 409 SALESY_WARNING / 422 COMPLIANCE_RED_BLOCKED / 422 VALIDATION_ERROR（無 line_user_id）/ 502 LINE_PUSH_FAILED

---

#### GET /api/v1/inbox

取得當前教練的待回覆 LINE 訊息清單（游標分頁）。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：**

| 參數 | 型別 | 說明 |
|---|---|---|
| `cursor` | string | 游標（上頁最後一筆 inbound_message id） |
| `limit` | integer | 每頁筆數，預設 20，最大 100 |
| `status` | string | 過濾：`new`（未草稿）、`drafted`（已草稿）；不傳則回 new+drafted 兩種 |

**Response 200：**

```json
{
  "data": [
    {
      "id": "inb_abc123",
      "tenant_id": "tnt_abc123",
      "official_account_id": "oa_abc123",
      "contact_id": "ctc_abc123",
      "contact_display_name": "Anna Chen",
      "distributor_id": "usr_abc123",
      "line_message_id": "325708",
      "text": "你好，我想了解產品",
      "received_at": "2026-06-02T10:00:00Z",
      "status": "drafted",
      "reply_draft_id": "dft_abc123"
    }
  ],
  "pagination": {
    "next_cursor": "inb_xyz789",
    "has_more": false,
    "limit": 20
  }
}
```

`status` enum: `new`（收到訊息，尚未生成草稿）、`drafted`（已生成草稿，待教練審核發送）、`replied`（已發送回覆）

`reply_draft_id` 為 `null` 時表示草稿尚未產生（status = new）或正在生成中。

**Status Codes：** 200 OK / 401 UNAUTHORIZED

---

#### PUT /api/v1/contacts/{contact_id}/assignment

Leader 手動改派教練（覆蓋輪派結果）。

| 項目 | 值 |
|---|---|
| Method | PUT |
| Auth Scope | leader |

**Request（AssignmentUpdate schema）：**

```json
{
  "distributor_id": "usr_def456"
}
```

**後端處理：** 更新 `contacts.distributor_id` 與 `contacts.assigned_at`（= now()）。已存在且 status=new/drafted 的 inbound_messages 不自動重新指派（需 Leader 自行協調）。

**Response 200：**

```json
{
  "data": {
    "contact_id": "ctc_abc123",
    "distributor_id": "usr_def456",
    "assigned_at": "2026-06-02T11:00:00Z"
  }
}
```

**Status Codes：** 200 OK / 403 FORBIDDEN（非 leader 角色）/ 404 NOT_FOUND / 422 VALIDATION_ERROR

---

### 7.18 來訊自動分析與活檔案建議 (contact-suggestions)

每則 OA 來訊由 enrichment 管線（單次 Haiku 4.5 三合一呼叫）非同步分析，其中活檔案重點建議寫入 `contact_suggestions`（status=pending）。**G.7 唯讀硬限制**：建議須教練 confirm 才 patch 進 contacts，AI 永不直接寫活檔案。

#### GET /api/v1/contacts/{contact_id}/suggestions

列出該聯絡人的活檔案待確認建議。

| 項目 | 值 |
|---|---|
| Method | GET |
| Auth Scope | distributor |

**Query Parameters：** `status`（過濾：`pending` / `confirmed` / `dismissed`；預設 `pending`）

**Response 200：**

```json
{
  "data": [
    {
      "id": "sug_abc123",
      "contact_id": "ctc_abc123",
      "inbound_message_id": "inb_abc123",
      "field": "health_concerns",
      "suggested_value": "睡眠品質差",
      "evidence": "客戶 2026-06-07 來訊：「最近都睡不好」",
      "status": "pending",
      "created_at": "2026-06-07T10:00:00Z"
    }
  ]
}
```

`field` enum：對應活檔案可建議欄位（`health_concerns` / `family_context` / `interests` / `life_status`）

**Status Codes：** 200 OK / 404 NOT_FOUND

---

#### POST /api/v1/contact-suggestions/{suggestion_id}/confirm

教練確認建議，後端將 `suggested_value` patch 進對應 contacts 欄位，並重算 contact_embedding。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Request：** 可選 `{"edited_value": "..."}` — 教練可修改建議內容後再確認。

**Response 200：**

```json
{"data": {"id": "sug_abc123", "status": "confirmed", "confirmed_at": "2026-06-07T10:05:00Z"}}
```

寫入 `learning_logs`（`event_type: suggestion_confirmed`）。

**Status Codes：** 200 OK / 404 NOT_FOUND / 409 CONFLICT（已 confirmed/dismissed）

---

#### POST /api/v1/contact-suggestions/{suggestion_id}/dismiss

教練忽略建議（不入檔）。

| 項目 | 值 |
|---|---|
| Method | POST |
| Auth Scope | distributor |

**Response 200：**

```json
{"data": {"id": "sug_abc123", "status": "dismissed", "dismissed_at": "2026-06-07T10:05:00Z"}}
```

寫入 `learning_logs`（`event_type: suggestion_dismissed`，誤抽率觀察素材）。

**Status Codes：** 200 OK / 404 NOT_FOUND / 409 CONFLICT

---

## 8. 資料模型 DTO Schemas

以下為關鍵 Request / Response DTO 的完整 Schema 範例，對齊契約 E 章實體定義。

### 8.1 ContactCreate

```json
{
  "display_name": "Anna Chen",          // required, string
  "phone": "+886922123456",             // optional, string
  "health_concerns": ["睡眠改善"],      // optional, string[]
  "family_info": {                      // optional, object (自由結構)
    "spouse": true,
    "children": 1
  },
  "job_info": {                         // optional, object (自由結構)
    "title": "上班族",
    "company": "科技公司"
  },
  "interests": ["瑜珈"],               // optional, string[]
  "communication_pref": "line",         // optional, enum: line/whatsapp/ig_dm/email
  "relationship_type": "customer"       // optional, enum: friend/acquaintance/prospect/customer/recruit_prospect
}
```

### 8.2 MessageDraftRequest

```json
{
  "contact_id": "ctc_abc123",           // required, string (帶前綴)
  "tone": "care",                       // required, enum: care/casual/business
  "channel": "line",                    // required, enum: line/whatsapp/ig_dm/email
  "context_override": "今天想特別關心睡眠狀況" // optional, string
}
```

### 8.3 MessageDraftEvent（SSE event: done 的 data）

```json
{
  "draft_id": "dft_abc123",            // string
  "tone": "care",                      // enum: care/casual/business
  "channel": "line",                   // enum
  "model_used": "sonnet-4-6",          // string: haiku-4-5/sonnet-4-6
  "latency_ms": 1240,                  // integer
  "compliance_status": "green"         // enum: green/yellow/red
}
```

### 8.4 SampleCreate

```json
{
  "product_name": "精油套組 A",         // required, string
  "product_id": "prd_abc123",          // optional, string (帶前綴)
  "sent_at": "2026-06-01T10:00:00Z",   // optional, timestamptz (預設 now())
  "notes": "Cathy 想試試精油"           // optional, string
}
```

### 8.5 VoiceClipRequest

```json
{
  "draft_id": "dft_abc123",            // required, string (帶前綴)
  "voice_style": "warm_female",        // required, enum: warm_female/neutral_male
  "language": "zh-TW"                  // required, enum: zh-TW/en-US
}
```

### 8.6 ComplianceResult（POST /compliance/check 的 response data）

```json
{
  "id": "cck_abc123",                  // string
  "result": "red",                     // enum: green/yellow/red
  "triggered_terms": ["保證", "治癒"], // string[]
  "suggestion": "改寫成「我自己用了感覺不錯，分享給你參考」", // string (紅/黃燈時)
  "latency_ms": 18,                    // integer (< 50ms)
  "created_at": "2026-06-02T10:30:00Z" // timestamptz
}
```

### 8.7 QuestionnaireSubmit（POST /questionnaire-links/{token}/submit 的 request）

```json
{
  "answers": {                          // required, object: question_id -> answer
    "q01": "睡眠品質",
    "q02": 2,
    "q03": "最近入睡困難"
  },
  "submitted_at": "2026-06-02T11:00:00Z" // optional, timestamptz (預設 now())
}
```

### 8.8 TodayTask

```json
{
  "id": "tsk_abc123",                  // string
  "contact_id": "ctc_abc123",          // string
  "contact_display_name": "Bella Wang", // string (join 展平，方便前端直接顯示)
  "task_date": "2026-06-02",           // date
  "priority": 1,                       // integer (1 = 最高)
  "source_type": "life_event",         // enum: life_event/sample_followup/dormant/recruitment/salesy_alert/inbound_reply
  "source_id": "evt_abc123",           // string (inbound_reply 時為 inbound_message id)
  "reason": "下週日（6/9）是 Bella 生日", // string (一句話，直接顯示在卡片)
  "cta_label": "寫關懷訊息",           // string (inbound_reply 時為「回覆 LINE 訊息」)
  "status": "pending",                 // enum: pending/done/snoozed/dismissed
  "completed_at": null                 // timestamptz or null
}
```

### 8.9 LineWebhookEvent（POST /webhooks/line 摘要）

```json
{
  "destination": "Uxxxxx",             // string（LINE OA userId，用於識別租戶 OA）
  "events": [
    {
      "type": "message",               // string（只處理 "message"）
      "replyToken": "nHuyWiB7...",     // string（LINE reply token，~1 分鐘失效，不用於本系統）
      "source": {
        "type": "user",                // string
        "userId": "U206d25c2ea..."     // string（即 contacts.line_user_id）
      },
      "timestamp": 1462629479859,      // integer（Unix ms）
      "message": {
        "id": "325708",                // string（唯一 message id，用於冪等去重）
        "type": "text",                // string（只處理 "text"）
        "text": "你好，我想了解產品"   // string
      }
    }
  ]
}
```

後端不需要回傳此 schema；此為 LINE 平台傳入的 payload 格式摘要，僅作為驗簽對象與業務解析依據。

### 8.10 SendDraftResponse（POST /message-drafts/{id}/send 的 response data）

```json
{
  "draft_id": "dft_abc123",           // string
  "sent_at": "2026-06-02T10:35:00Z",  // timestamptz
  "line_message_id": "line_msg_xyz",  // string（LINE 平台回傳的 message id）
  "delivery_method": "line_push",     // enum: line_push/manual_copy
  "compliance_status": "green"        // enum: green/yellow（紅燈不可到此）
}
```

### 8.11 InboxItem（GET /inbox 的 data 陣列元素）

```json
{
  "id": "inb_abc123",                 // string (inb_ 前綴)
  "tenant_id": "tnt_abc123",          // string
  "official_account_id": "oa_abc123", // string (oa_ 前綴)
  "contact_id": "ctc_abc123",         // string
  "contact_display_name": "Anna Chen",// string (join 展平)
  "distributor_id": "usr_abc123",     // string (被指派的教練)
  "line_message_id": "325708",        // string (LINE 平台 message id，唯一)
  "text": "你好，我想了解產品",        // string
  "received_at": "2026-06-02T10:00:00Z", // timestamptz
  "status": "drafted",                // enum: new/drafted/replied
  "reply_draft_id": "dft_abc123"      // string or null
}
```

### 8.12 AssignmentUpdate（PUT /contacts/{id}/assignment 的 request）

```json
{
  "distributor_id": "usr_def456"      // required, string (帶前綴)
}
```

### 8.13 MessageDraft（補充 LINE 整合欄位）

`message_drafts` DTO 在原有欄位基礎上新增以下欄位（`channel = 'line_oa'` 時適用）：

```json
{
  "id": "dft_abc123",
  "contact_id": "ctc_abc123",
  "tone": "care",
  "channel": "line_oa",               // 新增 enum 值：line_oa（區別於一般 line 頻道）
  "content": "Anna，最近睡得好一點了嗎？",
  "compliance_status": "green",
  "compliance_check_id": "cck_abc123",
  "adopted": false,
  "model_used": "sonnet-4-6",
  "latency_ms": 2100,
  "in_reply_to_inbound_id": "inb_abc123", // 新增：關聯的 inbound_message id（LINE OA 回覆時設定）
  "sent_at": "2026-06-02T10:35:00Z",  // 新增：發送時間（未發送時為 null）
  "delivery_method": "line_push",     // 新增：enum: line_push/manual_copy（未發送時為 null）
  "line_message_id": "line_msg_xyz",  // 新增：LINE 平台回傳 message id（未發送時為 null）
  "created_at": "2026-06-02T10:30:00Z"
}
```

---

## 9. 排程與內部事件

今日 5 件事的任務卡並非由前端請求觸發，而是由後端 APScheduler 批次產生，再由前端 GET 取得。以下說明排程流程與內部事件觸發機制。

### 9.1 今日任務批次產生排程

```mermaid
graph TD
    A[APScheduler: 每日 22:00 UTC = 06:00 台北時間] --> B[遍歷所有 active distributors]
    B --> C{各直銷商產生任務邏輯}
    C --> D[查詢 7 天內到期 life_events]
    C --> E[查詢 status=pending 的 sample_followups]
    C --> F[查詢 dormant_since IS NOT NULL 的 contacts]
    C --> G[查詢 recruitment_stages 近期可推進]
    C --> H[查詢 unacknowledged salesy_alerts]
    D --> I["依優先序（高到低）：life_event、sample_followup、dormant、recruitment、salesy_alert"]
    E --> I
    F --> I
    G --> I
    H --> I
    I --> J["取前 5 筆，寫入 today_tasks 表"]
    J --> K[task_date = 明日日期]
```

### 9.2 樣品跟進提醒觸發流程

```mermaid
sequenceDiagram
    participant Dist as 直銷商
    participant API
    participant DB
    participant Sched as APScheduler

    Dist->>API: POST /contacts/{id}/samples（新增樣品）
    API->>DB: INSERT samples（status=sent）
    API->>DB: INSERT sample_followups（h48/h72/d7）
    Note over Sched: followup_at 到達時
    Sched->>DB: SELECT sample_followups WHERE followup_at <= now() AND status=pending
    Sched->>API: 觸發內部 generate_followup_draft
    API->>DB: INSERT message_drafts（Haiku 4.5 生成，AI 層沿用既有框架）
    API->>DB: UPDATE sample_followups SET draft_id = ..., status = notified
    API->>DB: INSERT today_tasks（source_type=sample_followup）
    Note over Dist: 明日早上開 App 時看到任務卡
```

### 9.3 排程任務清單

| 排程名稱 | 觸發時間 | 說明 |
|---|---|---|
| `generate_today_tasks` | 每日 22:00 UTC | 為所有活躍直銷商批次產生今日 5 件事 |
| `process_sample_followups` | 每小時整點 | 掃描到期的 sample_followups，預生草稿 + 通知 |
| `expire_questionnaire_links` | 每日 00:00 UTC | 標記過期問卷連結（is_active = false） |
| `expire_voice_clips` | 每日 01:00 UTC | 刪除 expires_at < now() 的語音檔 |
| `reset_daily_quotas` | 每日 00:00 UTC | 重置 usage_quotas 的每日計數欄位 |
| `expire_idempotency_keys` | 每日 03:00 UTC | 清理過期的冪等 key 記錄 |
| `process_data_requests` | 每小時 | 掃描 pending 的 data_requests，觸發 export/delete 作業 |

### 9.5 LINE Inbound 訊息處理流程

```mermaid
sequenceDiagram
    participant LINE as LINE Platform
    participant API as Backend API
    participant DB as PostgreSQL
    participant Sched as APScheduler
    participant Coach as 教練端（App）

    LINE->>API: POST /api/v1/webhooks/line
    Note over API: 驗簽 X-Line-Signature HMAC-SHA256
    API-->>LINE: 200 OK（5 秒內必須回應）
    API->>DB: 查找 contacts by line_user_id
    Note over DB: 找不到時建立新 contact，source=line_oa
    API->>DB: 輪派（官方帳號 assignment_cursor，找下一位 active 教練）
    API->>DB: INSERT inbound_messages（status=new）
    API->>DB: INSERT today_tasks（source_type=inbound_reply，推入被指派教練）
    API->>DB: 非同步觸發 T06 草稿預生成（in_reply_to_inbound_id）
    DB-->>API: 草稿生成完成
    API->>DB: UPDATE inbound_messages SET status=drafted, reply_draft_id=dft_abc123
    Note over Coach: 教練開 App 看到今日 5 件事待回覆卡
    Coach->>API: GET /api/v1/inbox（查看待回覆清單）
    API-->>Coach: InboxItem 清單（含 reply_draft_id）
    Coach->>API: POST /api/v1/message-drafts/dft_abc123/send（審核後發送）
    Note over API: 合規 gate 再掃一次（紅燈→422，拒絕）
    API->>LINE: LINE Messaging API push message
    LINE-->>API: 200 OK（含 line_message_id）
    API->>DB: UPDATE message_drafts SET sent_at, line_message_id, delivery_method=line_push
    API->>DB: UPDATE inbound_messages SET status=replied
    API-->>Coach: SendDraftResponse（sent_at, line_message_id）
```

### 9.4 學習紀錄寫入時機

所有 AI 操作完成後，後端非同步（< 1 秒）寫入 `learning_logs`。寫入失敗不影響主流程，但需觸發 Sentry 告警。

```mermaid
graph LR
    A[AI 操作完成] --> B[主流程回應前端]
    A --> C{非同步寫入 learning_logs}
    C -->|成功| D[記錄寫入]
    C -->|失敗| E[Sentry 告警]
    B --> F[前端收到回應]
```

---

## 10. 跨領域不變量

以下規則在 API 層面的具體體現，與契約 G 章完全對應。

### 10.1 草稿模式硬限制

API 層的發送端點僅限 LINE OA 整合場景，且**強制經過人工審核**：

- `POST /message-drafts/{draft_id}/send`：僅適用 `channel = 'line_oa'` 的草稿，教練主動按「發送」後呼叫，AI 不自動發送
- 非 LINE OA 場景（`channel = 'line' / 'whatsapp' / 'ig_dm' / 'email'`）的草稿，不提供 send 端點，只有 `/adopt`（複製使用）

以下端點在 v1 不存在：
- `POST /voice-clips/{id}/send`
- `POST /objection-responses/{id}/send`

所有非 LINE OA 草稿端點僅提供「採用」（`/adopt`、`/download`）動作，語義為直銷商確認複製使用，不代表平台代發。

### 10.2 合規 Gate 實施

所有涉及草稿生成的端點，後端必須在返回給前端前完成合規掃描：

| 觸發場景 | compliance_sidecar 掃描時機 |
|---|---|
| POST /message-drafts（非串流） | 生成完成後，返回前同步掃描 |
| POST /message-drafts/stream（串流） | 全文生成完成後，推送 compliance_result 事件 |
| POST /contacts/{id}/samples（樣品草稿） | 跟進草稿預生成後掃描 |
| POST /voice-clips（語音生成） | 以 draft.content 為輸入，生成前掃描 |
| POST /objection-responses | 三種回應全部生成後掃描 |
| POST /questionnaire-links/{token}/submit | AI 摘要生成後掃描 |
| PUT /contacts/{id}/recruitment-stage | 招募話術草稿生成後掃描（source_type=recruitment_draft）；注記 notes 掃描為補充行為，主要合規 gate 在 recruitment_service 產生話術草稿時觸發 |
| POST /message-drafts/{id}/send（LINE OA 發送前） | 教練按發送時再掃一次（不論草稿是否已過 green）；紅燈→`422 COMPLIANCE_RED_BLOCKED`，拒絕發出；黃燈→允許繼續 |

紅燈時：回傳 `422 COMPLIANCE_RED_BLOCKED`，`details` 含 `check_id`、`triggered_terms`、`suggestion`。

### 10.3 學習紀錄強制寫入

下列 API 呼叫必須在完成後 1 秒內寫入 `learning_logs`（非同步 fire-and-forget）：

| API 動作 | learning_log event_type |
|---|---|
| POST /contacts/{id}/emotion/detect | `emotion_read` |
| POST /message-drafts 或 /stream 完成 | `draft_generated` |
| POST /message-drafts/{id}/adopt | `draft_adopted` |
| 草稿生成 30 分鐘後未 adopt | `draft_rejected`（排程觸發） |
| POST /salesy-alerts/{id}/dismiss | `salesy_alert_dismissed` |
| POST /salesy-alerts/{id}/acknowledge | `salesy_alert_acknowledged` |
| POST /objection-responses/{id}/adopt | `objection_used` |
| compliance_sidecar 回傳 yellow/red | `compliance_triggered` |
| 直銷商覆蓋 yellow 燈（確認繼續） | `compliance_overridden` |
| POST /voice-clips/{id}/download | `voice_downloaded` |

### 10.4 租戶隔離測試要求（API 層）

以下三條跨租戶測試需在 API 整合測試中覆蓋：

1. R001（distributor A）呼叫 `GET /api/v1/contacts/ctc_of_R002` → 回 404（不得回 403）
2. R001 呼叫 `POST /api/v1/message-drafts`，body 中的 `contact_id` 屬於 R002 → 回 404
3. 有效的 JWT 但 JWT 的 `sub` 不符合 path 中預期的 distributor_id → 回 404

### 10.5 成本計量責任

每個涉及 AI 呼叫的端點，後端**必須**在 AI 呼叫返回後同步更新 `usage_quotas.ai_cost_usd_today`，再返回 API 回應。更新失敗（DB 錯誤）應回 `500 INTERNAL_ERROR` 而非靜默跳過。

---

*本文件由首席技術文件撰寫者於 2026-06-02 依據 PRD v0.3 及跨文件共用契約 v1.0 撰寫。欄位名稱、路徑、enum 值以契約 E/F/H 章為唯一真實來源。*
