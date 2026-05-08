# API 設計規範 — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08 | **狀態:** 實作基準 | **對應架構:** `docs/04_architecture.md` | **對應 Phase I MVP:** `docs/12_phase1_mvp.md` | **⚠️ v3.1 重大修訂：Magic Link 廢棄 → 帳密登入；新增 Admin endpoints；新增 WhatsApp webhook；新增合規規則 CRUD**

---

## v3.1 重大修訂說明（2026-05-08）

⚠️ **五大改動**：

1. **認證改帳密**（❌ Magic Link → ✅ bcrypt 帳密 + JWT）：
   - 移除 `/auth/magic-link`、`/auth/callback`
   - 新增 `/auth/login`（email + password）、`/auth/change-password`、`/auth/logout`
   - JWT 構成同：access 1h + refresh 7d

2. **新增 Admin endpoints**（系統管理員後台）：
   - `/admin/users`（CRUD）、`/admin/users/:id/reset-password`
   - `/admin/compliance-rules`（CRUD）、`/admin/compliance-rules/import`（CSV 批量）、`/admin/compliance-rules/regenerate-embeddings`

3. **新增 WhatsApp webhook**：
   - `POST /webhooks/whatsapp`（Meta 回呼、訊息確認）

4. **規則庫端點升級**：
   - `/compliance/rules`（GET/POST/PATCH/DELETE）— 管理 compliance_rules 表

5. **消息草稿端點（已存在，見 Draft Review）**：
   - `/drafts`（GET/PATCH）— 教練查看與審核草稿

**端點變化**：~48（v3.0）→ ~65+（v3.1）（新增 17+ admin + rule + webhook）

---

## 1. 設計約定

| 項目 | 規範 |
| :--- | :--- |
| **風格** | RESTful + JSON |
| **Base URL** | Production: `https://api.synergy-ai.tw/v1` / Staging: `https://api-staging.synergy-ai.tw/v1` |
| **格式** | `application/json` (UTF-8) |
| **資源路徑** | 小寫、連字符、複數（e.g., `/leads`、`/compliance-rules`） |
| **欄位命名** | `snake_case` |
| **日期格式** | ISO 8601 UTC（e.g., `2026-05-01T14:00:00Z`） |
| **認證** | JWT in `Authorization: Bearer <jwt>`（httpOnly cookie 同時支援） |
| **版本控制** | URL 路徑 `/v1/...` |
| **Tenant** | 由 JWT 的 `tenant_id` claim 決定，不在 URL |

---

## 2. 通用行為

（維持既有 v1.0 規範：分頁、排序、過濾、冪等性）

---

## 3. 錯誤處理

| 錯誤碼 | HTTP | 描述 |
| :--- | :--- | :--- |
| `draft_pending_review` | 202 | 訊息已存入草稿待教練審核 |
| `invalid_credentials` | 401 | 帳密錯誤或未登入 |
| `account_locked` | 429 | 帳號因暴力破解被鎖定 |
| `permission_denied` | 403 | 缺乏 admin 權限 |

---

## 4. 安全性

（維持既有 v1.0 規範 + v3.1 新增）

### 認證層

- **帳密登入**：bcrypt hash (cost=12)，密碼 ≥10 字元（數字 + 字母）
- **JWT**：HS256 簽章，claim 包含 `user_id, role, tenant_id`
- **暴力破解防護**：失敗 5 次 → 15min 鎖定
- **首次登入**：強制改密碼（`must_change_password = true`）

### 授權層

- **Admin endpoints**：僅 role=admin 可存取 `/admin/*`
- **Draft privacy**：coach 只看自己草稿；leader 無草稿存取權（隱私）

---

## 5. API 端點清單

### ✨ 5.1 認證（Auth）— 公開 + 需登入（v3.1 改帳密）

#### `POST /v1/auth/login` — 帳密登入

- **授權**：無（公開）
- **請求體**：

```json
{
  "email": "coach@synergy-ai.tw",
  "password": "SecurePass123!"
}
```

- **回應**：`200 OK`

```json
{
  "user": {
    "id": "user_01HWX...",
    "email": "coach@synergy-ai.tw",
    "role": "coach",
    "name": "阿明",
    "tenant_id": "tenant_01HWX...",
    "must_change_password": false
  },
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 3600
}
```

- **說明**：
  - 驗證成功 → JWT 核發 + httpOnly cookie 設置
  - 若 `must_change_password = true` → 自動跳轉 `/auth/change-password`（強制改密）
  - 失敗 5 次 → 回應 429 account_locked（15min 解除）

#### `POST /v1/auth/change-password` — 改密碼

- **授權**：JWT（必須）
- **請求體**：

```json
{
  "old_password": "OldPass123!",
  "new_password": "NewPass456!",
  "confirm_password": "NewPass456!"
}
```

- **回應**：`200 OK` → `{ "message": "密碼已更新" }`
- **說明**：
  - 新密碼政策同上（≥10 字、數字 + 字母）
  - 若首次登入（`must_change_password = true`），改密後標記為 false
  - 舊密碼驗證失敗 → 401

#### `POST /v1/auth/refresh` — 刷新 Token

- **授權**：無（用 refresh token via cookie 或 request body）
- **請求體**（可選，若用 cookie 則不需）：

```json
{
  "refresh_token": "eyJ..."
}
```

- **回應**：`200 OK` → 新的 access_token

```json
{
  "access_token": "eyJ...",
  "expires_in": 3600
}
```

#### `GET /v1/auth/me` — 取得當前使用者

- **授權**：JWT（必須）
- **回應**：`200 OK`

```json
{
  "user": {
    "id": "user_01HWX...",
    "email": "coach@synergy-ai.tw",
    "role": "coach | leader | admin",
    "name": "阿明",
    "tenant_id": "tenant_01HWX...",
    "created_at": "2026-04-01T00:00:00Z"
  }
}
```

#### `POST /v1/auth/logout` — 登出

- **授權**：JWT（必須）
- **請求體**：

```json
{
  "all_devices": false
}
```

- **回應**：`200 OK` → `{ "message": "已登出" }`
- **說明**：清除 httpOnly cookie + 若 `all_devices: true` 則清除所有 refresh token

---

### ✨ 5.2 管理員後台（Admin）— 需 admin 權限（v3.1 新增）

#### `GET /v1/admin/users` — 列出所有教練

- **授權**：JWT（role=admin）
- **Query 參數**：`page=1&limit=20&role=coach&name=阿&status=active`
- **回應**：`200 OK`

```json
{
  "users": [
    {
      "id": "user_01HWX...",
      "email": "coach@synergy-ai.tw",
      "name": "阿明",
      "role": "coach",
      "status": "active | inactive | locked",
      "failed_login_count": 0,
      "locked_until": null,
      "created_at": "2026-04-01T00:00:00Z"
    }
  ],
  "pagination": {
    "total": 50,
    "page": 1,
    "limit": 20,
    "pages": 3
  }
}
```

#### `POST /v1/admin/users` — 建立新教練帳號

- **授權**：JWT（role=admin）
- **請求體**：

```json
{
  "email": "new_coach@synergy-ai.tw",
  "name": "新教練",
  "role": "coach | leader | admin",
  "password": "InitialPass123!"
}
```

- **回應**：`201 Created`

```json
{
  "user": {
    "id": "user_01HWX...",
    "email": "new_coach@synergy-ai.tw",
    "name": "新教練",
    "role": "coach",
    "must_change_password": true,
    "created_at": "2026-05-08T00:00:00Z"
  }
}
```

- **說明**：
  - 初始密碼由 admin 設定或系統隨機生成
  - 新用戶 `must_change_password = true`
  - 首次登入時強制改密碼

#### `PATCH /v1/admin/users/:id` — 編輯教練帳號

- **授權**：JWT（role=admin）
- **請求體**：

```json
{
  "name": "新名字",
  "role": "leader",
  "status": "active | inactive | locked"
}
```

- **回應**：`200 OK` → 更新後的 user 物件

#### `DELETE /v1/admin/users/:id` — 刪除教練帳號

- **授權**：JWT（role=admin）
- **說明**：邏輯刪除（狀態改 `deleted`），保留稽核記錄
- **回應**：`204 No Content`

#### `POST /v1/admin/users/:id/reset-password` — 強制重設密碼

- **授權**：JWT（role=admin）
- **請求體**：

```json
{
  "new_password": "ResetPass123!"
}
```

- **回應**：`200 OK` → `{ "message": "密碼已重設", "must_change_password": true }`
- **說明**：教練下次登入時需改此初始密碼

#### `GET /v1/admin/compliance-rules` — 列出合規規則

- **授權**：JWT（role=admin）
- **Query 參數**：`page=1&limit=50&category=C1&enabled=true`
- **回應**：`200 OK`

```json
{
  "rules": [
    {
      "id": "rule_01HWX...",
      "category": "C1",
      "phrase": "保證治療",
      "severity": "high",
      "suggested_rewrite": "可幫助關注",
      "embedding_model": "gemini",
      "enabled": true,
      "created_by": "admin_id",
      "created_at": "2026-04-01T00:00:00Z"
    }
  ],
  "pagination": { "total": 200, "page": 1, "limit": 50 }
}
```

#### `POST /v1/admin/compliance-rules` — 新增合規規則

- **授權**：JWT（role=admin）
- **請求體**：

```json
{
  "category": "C1",
  "phrase": "新禁用詞",
  "severity": "high",
  "suggested_rewrite": "建議改寫方案"
}
```

- **回應**：`201 Created` → 新規則（含自動產生的 embedding）

#### `PATCH /v1/admin/compliance-rules/:id` — 編輯規則

- **授權**：JWT（role=admin）
- **請求體**：（同新增，任何欄位都可改）
- **回應**：`200 OK` → 更新後的規則 + 重新產生 embedding

#### `DELETE /v1/admin/compliance-rules/:id` — 刪除規則

- **授權**：JWT（role=admin）
- **回應**：`204 No Content`

#### `POST /v1/admin/compliance-rules/import` — CSV 批量匯入規則

- **授權**：JWT（role=admin）
- **Content-Type**：`multipart/form-data`
- **Form 欄位**：
  - `file`: CSV 檔案（columns: category, phrase, severity, suggested_rewrite）

**CSV 格式**：
```
category,phrase,severity,suggested_rewrite
C1,保證治療,high,可幫助關注
C1,保證療效,high,可能有幫助
C2,月收百萬,high,月入十多萬
```

- **回應**：`200 OK`

```json
{
  "imported": 100,
  "updated": 10,
  "failed": 0,
  "errors": []
}
```

#### `POST /v1/admin/compliance-rules/regenerate-embeddings` — 重算所有 embedding

- **授權**：JWT（role=admin）
- **說明**：當更換 embedding 模型時，重新產生所有規則的向量
- **回應**：`200 OK` → `{ "regenerated": 200, "failed": 0 }`

---

### 5.3 既有端點（v1.0 ~ v3.0 維持）

5.3.1 問卷（Questionnaire） — 無需登入
5.3.2 商談摘要（Briefing）— 需教練登入
5.3.3 客戶管理（Leads / CRM）— 需教練登入
5.3.4 提醒（Reminders）— 內部 + 教練查詢
5.3.5 LINE 綁定 Webhook（Coach onboarding）
5.3.6 合規檢查（Compliance）— 內部 + 教練決策
5.3.7 消息草稿（Message Drafts）— 教練查看與編輯

（詳見 v3.0 文件或對應模組詳規 `docs/06_modules.md`）

---

### ✨ 5.4 Webhook — 外部服務回呼（v3.1 新增 WhatsApp）

#### `POST /webhooks/whatsapp` — WhatsApp 訊息回呼

- **授權**：無（Webhook 驗證 via HMAC-SHA256）
- **驗證**：
  - 請求頭 `X-Hub-Signature` 包含 HMAC-SHA256(body, WHATSAPP_VERIFY_TOKEN)
  - 需與 Meta Dashboard 設定的 verify token 匹配

**Meta 發送格式**（Webhook body）：

```json
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "...",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "1234567890",
              "phone_number_id": "..."
            },
            "statuses": [
              {
                "id": "wamid.xxx",
                "status": "delivered | read | failed | sent",
                "timestamp": 1234567890,
                "recipient_id": "..."
              }
            ]
          }
        }
      ]
    }
  ]
}
```

- **說明**：
  - `statuses` → 記錄訊息送達狀態
  - 若 status = "failed" → log event + trigger fallback channel（Email）
  - 無需回應 body，回 200 即可（Meta 預期快速回應 ≤ 3s）

#### `GET /webhooks/whatsapp` — Webhook 驗證（初始化時）

- **Query 參數**：`hub.mode=subscribe&hub.challenge=...&hub.verify_token=...`
- **回應**：若 token 正確 → `200 OK` 並回應 hub.challenge；否則 403

---

## 6. 權限矩陣（v3.1 更新）

| Endpoint | Public | Coach | Leader | Admin | 說明 |
|---|---|---|---|---|---|
| `/auth/login` | ✅ | — | — | — | 帳密登入 |
| `/auth/change-password` | — | ✅ | ✅ | ✅ | 改密碼 |
| `/auth/me` | — | ✅ | ✅ | ✅ | 查自己資料 |
| `/admin/users` | — | — | — | ✅ | Admin CRUD |
| `/admin/compliance-rules` | — | — | — | ✅ | 規則管理 |
| `/questionnaires/*` | ✅ | — | — | — | 公開填答 |
| `/leads` | — | ✅ | ✅ | — | Lead 列表（Coach 看自己；Leader 看下線） |
| `/leads/:id` | — | ✅ | ✅ | — | Lead 詳情 |
| `/leader/summary` | — | — | ✅ | — | Leader 看下線統計 |
| `/drafts` | — | ✅ | — | — | 教練看自己草稿 |
| `/webhooks/whatsapp` | ✅ | — | — | — | Meta 回呼（HMAC 驗證） |

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v3.0.1 | 2026-05-08 | 新增 Auth endpoints（Magic Link）；新增 Draft endpoints；移除 HITL queue endpoints |
| **v3.1** | **2026-05-08** | **改帳密登入（廢棄 Magic Link）；新增 Admin CRUD endpoints；新增 WhatsApp webhook；新增合規規則 CRUD；總端點 ~48 → ~65+** |
