# 模組規格與測試案例 — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08 | **狀態:** 實作基準
> **⚠️ v3.1 重大修訂**：帳密登入（廢棄 Magic Link）+ 新增 UserManagementService / PasswordAuthService / ComplianceRuleService / SemanticMatcher / WhatsAppChannel（模組 21） | **對應架構**：`docs/04_architecture.md` | **對應 API**：`docs/05_api.md` | **對應 Phase I MVP**：`docs/12_phase1_mvp.md`

---

## v3.1 重大修訂說明（2026-05-08）

⚠️ **新增 5 個模組 + 改造認證層**：

- **❌ AuthService（Magic Link，v3.0.1 舊設計）→ ✅ PasswordAuthService（帳密） + UserManagementService（後台建用戶）**
  - 移除 Magic Link 相關函式
  - 新增 bcrypt password verification、首次強制改密碼流程
  - Admin 後台 CRUD 教練帳號

- **✨ 新增 ComplianceRuleService**（Application）：規則庫 CRUD + embedding 計算
  - 取代舊 YAML 固定規則設定
  - 支援 admin 後台 CSV 批量匯入
  - 自動產生 pgvector embedding

- **✨ 新增 SemanticMatcher**（Domain）：向量相似度純函式
  - 計算 cosine similarity > 0.85（可配）
  - 支援多規則併行匹配（可能一次命中多條規則）

- **✨ 新增 WhatsAppChannel**（Infrastructure）：WhatsApp Business API 推播
  - 通知 Fallback：LINE → WhatsApp → Email
  - Webhook 接收訊息確認 + 送達狀態

- **ComplianceService 升級**：Layer 2 整合 SemanticMatcher + pgvector 語意比對

**模組總數**：18（v3.0.1）→ **21**（v3.1）；**新增模組數**：5

---

## 版本更新說明（v3.0.1 → v3.1）

本版本依據五項重大架構翻轉同步所有模組：

1. **認證系統翻轉**：Magic Link → bcrypt 帳密 + admin 後台建用戶
2. **規則庫 DB 化**：YAML → PostgreSQL + pgvector 向量語意比對
3. **通知通道擴充**：LINE/Email → LINE/WhatsApp/Email 三通道
4. **資料庫遷移**：Supabase → PostgreSQL（本地/GCP）
5. **部署平台改 GCP**：Cloudflare+Railway → Cloud Run+Cloud SQL+Cloud CDN

---

## 模組索引（v3.1 更新）

| # | 模組 | 所屬層級 | 核心 API | 新增/修訂 |
| :---: | :--- | :--- | :--- | :---: |
| **0** | **⚠️ PasswordAuthService** | **Application** | **`POST /auth/login`, `POST /auth/change-password`** | **⚠️ v3.1 改名自 AuthService，廢棄 Magic Link** |
| **0.5** | **✨ UserManagementService** | **Application** | **`POST/PATCH/DELETE /admin/users`** | **✨ v3.1 新增** |
| 1 | QuestionnaireService | Application | `/questionnaires/*` | ⬆️ v3.0：Phase 1/2/3；⬆️ v3.2：Phase 3 規則引擎驅動 |
| 2 | ScoringEngine | Domain | (內部) | ⬆️ v3.0：三階段計分；⬆️ v3.2：含 Phase 3 動態追問規則引擎（純 YAML，非 LLM）|

> **v3.2 補充（對應 docx §5.2 / Q-005 動態追問邏輯）**：
> - **Phase 3 路由判定 = 純規則引擎**（不用 LLM）
> - 規則檔：`apps/api/rules/questionnaire-phase3-routing.yaml`
> - 格式：`{condition: "phase2.stress_score >= 6", questions: [stress-1, stress-2]}`
> - 選擇理由：可預測（避免 LLM 隨機影響流程）、效能 <10ms、零 token、客戶可自維護
> - Phase II 升級觸發：規則 > 20 條交互、需要更動態題庫時
> - 詳見 [12_phase1_mvp.md § 動態追問邏輯定義](./12_phase1_mvp.md)
| 3 | BriefingService | Application | `/leads/{id}/briefing/*` | ⬆️ v3.0：雙版摘要 |
| 4 | LLMAdapter | Infrastructure | (內部) | — |
| 5 | LeadService (CRM) | Application | `/leads/*` | ⬆️ v3.0：10 種狀態 |
| 6 | LeadStatusMachine | Domain | (內部) | ⬆️ v3.0：狀態機 |
| 7 | ReminderService | Application | `/reminders/*` | ⬆️ v3.0：Google Calendar |
| 8 | ReminderScheduler | Infrastructure | `/internal/reminders/scan` | — |
| 9 | NotificationChannel 實作群 | Infrastructure | (內部) | **⚠️ v3.1：LINE/WhatsApp/Email 三通道** |
| **9.5** | **✨ WhatsAppChannel** | **Infrastructure** | **`POST /webhooks/whatsapp`** | **✨ v3.1 新增** |
| 10 | ComplianceService | Application | `/compliance/check` | **⚠️ v3.1：Layer 2 加 SemanticMatcher** |
| **10.5** | **✨ ComplianceRuleService** | **Application** | **`GET/POST/PATCH/DELETE /admin/compliance-rules`** | **✨ v3.1 新增** |
| **10.7** | **✨ SemanticMatcher** | **Domain** | **(內部）** | **✨ v3.1 新增，pgvector 相似度純函式** |
| 11 | DraftReviewService | Application | `GET/PATCH /drafts/:id` | ⬆️ v3.0.1：教練自主決策 |
| 12 | ConversationCoachService | Application | `/leads/{id}/conversation/*` | ✨ v3.0 |
| 13 | GoogleCalendarAdapter | Infrastructure | (內部) | ✨ v3.0 |
| 14 | ActivityTrackingService | Application | `/coaches/{id}/stats` | ✨ v3.0 |
| 15 | LeaderSummaryService | Application | `/leader/summary` | ✨ v3.0 |
| 16 | OnboardingProgressService | Application | `/leader/coaches/{id}/onboarding` | ✨ v3.0 |
| 17 | EventLog Service | Infrastructure | `/internal/events` | ✨ v3.0 |

**總計**：21 個模組（v3.0.1 時 18 個）

---

## 新增模組（v3.1）

### 0. PasswordAuthService（改名自 AuthService，v3.1）— 帳密驗證與 Session

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | 帳密登入、密碼驗證、首次強制改密、登出；JWT 核發與驗證 |
| **依賴** | PostgreSQL（users 表）、bcrypt 雜湊、JWT 庫 |
| **被依賴** | FastAPI Router (`/auth/*`)、所有受保護 endpoint（via `Depends(get_current_coach)`) |
| **API 端點** | `POST /auth/login`、`POST /auth/change-password`、`POST /auth/refresh`、`GET /auth/me`、`POST /auth/logout` |

#### 關鍵函式

```python
async def login(email: str, password: str) -> LoginResponse:
    """
    1. 查 users 表找 email
    2. 用 bcrypt.verify(password, user.password_hash)
    3. 檢查 failed_login_count 與 locked_until
    4. 成功 → JWT 核發 + reset failed_count
    5. 失敗 → failed_count++ + 若 ≥5 則鎖定 15min
    """

async def change_password(user_id: UUID, old_password: str, new_password: str) -> bool:
    """
    1. 驗證 old_password
    2. 新密碼政策檢查（≥10 字、數字+字母）
    3. 更新 password_hash + 設 must_change_password=false
    """

def get_current_coach(token: str) -> Coach:
    """
    JWT 驗證 + 讀 DB 確認 role + 返回 Coach 物件
    """
```

#### 資料表

```sql
-- users 表（新增 v3.1）
password_hash: TEXT (bcrypt cost=12)
must_change_password: BOOLEAN DEFAULT true
failed_login_count: INT DEFAULT 0
locked_until: TIMESTAMPTZ (NULL = 未鎖)
```

#### 驗收標準

- AC0.1：教練帳密登入；初始密碼由 admin 設定或自動生成
- AC0.2：首次登入強制改密碼（`must_change_password=true`）
- AC0.3：密碼政策 ≥10 字、含數字+字母；bcrypt cost=12
- AC0.4：暴力破解防護：失敗 5 次鎖 15min
- AC0.5：JWT 驗證速度 ≤ 50ms；access 1h + refresh 7d

---

### 0.5. UserManagementService（新增，v3.1）— 系統管理員後台

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | Admin 後台 CRUD 教練帳號、強制重設密碼、稽核日誌 |
| **依賴** | PostgreSQL（users、coaches、audit_logs）、PasswordAuthService |
| **被依賴** | FastAPI Router (`/admin/users/*`)、AuthorizationMiddleware |
| **API 端點** | `GET /admin/users`、`POST /admin/users`、`PATCH /admin/users/:id`、`DELETE /admin/users/:id`、`POST /admin/users/:id/reset-password` |

#### 關鍵函式

```python
async def create_user(email: str, name: str, role: str, password: str) -> User:
    """
    1. 檢查 email 唯一性
    2. 密碼 bcrypt hash（若 admin 提供）或隨機生成
    3. 建 users + coaches 表記錄
    4. 標 must_change_password=true
    5. 記 audit_log
    """

async def reset_password(user_id: UUID, new_password: str) -> bool:
    """
    1. 生成新密碼 hash
    2. 更新 password_hash + 設 must_change_password=true
    3. 記 audit_log（who, when, action）
    """

async def delete_user(user_id: UUID) -> bool:
    """邏輯刪除，保留審計記錄"""
```

#### 驗收標準

- AC0.5.1：Admin 可在 `/admin/users` 列表/建立/編輯/刪除教練
- AC0.5.2：新建用戶自動 `must_change_password=true`
- AC0.5.3：密碼重設記錄進 audit_log
- AC0.5.4：刪除用戶為邏輯刪除（status='deleted'）

---

### 9.5. WhatsAppChannel（新增，v3.1）— WhatsApp 推播

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Infrastructure |
| **核心職責** | Meta WhatsApp Business Cloud API 推播；Webhook 接收訊息狀態 |
| **依賴** | WhatsApp Business API（Meta）、HTTP client |
| **被依賴** | NotificationService（Fallback 路由）、ReminderService |
| **API 端點** | `POST /webhooks/whatsapp`（接收回呼） |

#### 關鍵函式

```python
async def send(phone_number_id: str, recipient_phone: str, message_text: str) -> bool:
    """
    1. 組建 WhatsApp API 請求（text message 或 template）
    2. 呼叫 POST https://graph.instagram.com/v18.0/{PHONE_NUMBER_ID}/messages
    3. 驗證回應 status code
    4. 記 EventLog
    5. 返回成功/失敗
    """

async def handle_webhook(request_body: dict) -> None:
    """
    Meta 發送的 Webhook（訊息送達、讀取、失敗）
    1. 驗證 X-Hub-Signature（HMAC-SHA256）
    2. 解析 statuses array
    3. 若 status='failed' → 記 EventLog + 可觸發 Email fallback
    """
```

#### 環境變數（v3.1）

```bash
WHATSAPP_ACCESS_TOKEN=...
WHATSAPP_PHONE_NUMBER_ID=...
WHATSAPP_VERIFY_TOKEN=...  # webhook 驗證
```

#### 驗收標準

- AC9.5.1：可向有 whatsapp_id 的教練推播訊息
- AC9.5.2：Webhook 正確驗證 HMAC 簽章
- AC9.5.3：送達失敗記錄進 EventLog + 可降級至 Email

---

### 10.5. ComplianceRuleService（新增，v3.1）— 規則庫管理

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Application |
| **核心職責** | CRUD compliance_rules 表；自動產生 pgvector embedding；CSV 批量匯入 |
| **依賴** | PostgreSQL（compliance_rules）、Gemini Embedding API 或 sentence-transformers |
| **被依賴** | ComplianceService、Admin endpoints |
| **API 端點** | `GET /admin/compliance-rules`、`POST /admin/compliance-rules`、`PATCH /admin/compliance-rules/:id`、`DELETE /admin/compliance-rules/:id`、`POST /admin/compliance-rules/import`、`POST /admin/compliance-rules/regenerate-embeddings` |

#### 關鍵函式

```python
async def create_rule(category: str, phrase: str, severity: str, suggested_rewrite: str) -> ComplianceRule:
    """
    1. 驗證 category ∈ {C1, C2, C3, C4}，severity ∈ {low, medium, high}
    2. 呼叫 embedding API 生成向量
    3. 存入 compliance_rules 表
    4. 記 audit_log（created_by=當前 admin）
    """

async def import_csv(file_path: str) -> dict:
    """
    1. 讀 CSV（columns: category, phrase, severity, suggested_rewrite）
    2. 逐列驗證 + 生成 embedding
    3. 批量 insert（或 upsert if exists）
    4. 返回 {imported: int, updated: int, failed: int}
    """

async def regenerate_all_embeddings() -> dict:
    """
    1. 讀所有 enabled=true 的規則
    2. 逐項重新產生 embedding（耗時 ~1-5min）
    3. 返回 {regenerated: int, failed: int}
    """
```

#### 資料表

```sql
-- compliance_rules（v3.1 新增）
CREATE TABLE compliance_rules (
    id UUID PRIMARY KEY,
    tenant_id UUID FK,
    category TEXT CHECK (category IN ('C1','C2','C3','C4')),
    phrase TEXT NOT NULL,
    severity TEXT CHECK (severity IN ('low','medium','high')),
    suggested_rewrite TEXT,
    embedding VECTOR(1536),  -- pgvector
    enabled BOOLEAN DEFAULT true,
    created_by UUID FK users,
    updated_by UUID FK users,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    INDEX idx_category_enabled (category, enabled),
    INDEX idx_embedding ON embedding USING ivfflat
);
```

#### 驗收標準

- AC10.5.1：Admin 可在 `/admin/compliance-rules` CRUD 規則
- AC10.5.2：新規則自動產生 embedding
- AC10.5.3：CSV 批量匯入支援 100+ 行
- AC10.5.4：embedding regenerate 支援全量重算

---

### 10.7. SemanticMatcher（新增，v3.1）— 向量語意比對

| 項目 | 內容 |
| :--- | :--- |
| **所屬層級** | Domain（純函式） |
| **核心職責** | 計算文本向量與規則向量的 cosine similarity；判定相符度 |
| **依賴** | pgvector 驅動（PostgreSQL），embedding adapter（Gemini / sentence-transformers） |
| **被依賴** | ComplianceService（Layer 2） |

#### 關鍵函式

```python
def cosine_similarity(vec_a: List[float], vec_b: List[float]) -> float:
    """
    計算兩個 1536-dim 向量的餘弦相似度 (0.0 ~ 1.0)
    """

async def match_rules(text: str, rules: List[ComplianceRule], threshold: float = 0.85) -> List[ComplianceRule]:
    """
    1. 生成 text embedding
    2. 逐一與 rules 計算 cosine similarity
    3. 篩選 similarity ≥ threshold 的規則
    4. 返回 matched rules list
    """
```

#### 驗收標準

- AC10.7.1：cosine similarity 計算正確 (0.0-1.0)
- AC10.7.2：相似度閾值可配（預設 0.85）
- AC10.7.3：一次可匹配多條規則

---

## 既有模組升級（v3.1）

### 9. NotificationChannel（升級）— 通知通道

**v3.1 升級**：新增 WhatsApp Fallback

```
NotificationService.send_reminder()
  ├─ try: LineChannel.send(coach.line_user_id) → success?
  ├─ try: WhatsAppChannel.send(coach.whatsapp_id) → success?
  └─ try: EmailChannel.send(coach.email) → success?
```

### 10. ComplianceService（升級）— 合規檢查

**v3.1 升級**：Layer 2 整合 SemanticMatcher + pgvector

```
Layer 1: 規則庫字面初篩 (<10ms)
  ├─ 逐一檢查 compliance_rules（WHERE enabled=true）
  └─ 詞重合 → 標 candidate

Layer 2: 向量語意比對 (<50ms) — 新增 v3.1
  ├─ 文本轉向量 embedding = embed_text(原文)
  ├─ pgvector cosine_similarity 比對 compliance_rules
  ├─ similarity > 0.85 → 匹配
  ├─ 呼叫 LLM 二次覆核 + quality_score
  └─ quality_score ≥ 0.7 → LM approved；< 0.7 → quality_failed

Layer 3: 教練決策（人工）
  ├─ 訊息 + 改寫版 + 風險標記進 message_drafts
  └─ 教練決策：接受/編輯/丟棄
```

---

## 模組矩陣（v3.1）

| 模組 | 層級 | 測試覆蓋 | 依賴複雜度 | 風險等級 |
|---|---|---|---|---|
| PasswordAuthService | App | 高 | 中 | 高（安全）|
| UserManagementService | App | 高 | 低 | 中 |
| ComplianceRuleService | App | 中 | 中 | 低 |
| SemanticMatcher | Domain | 高 | 低 | 低 |
| WhatsAppChannel | Infra | 中 | 中 | 中 |

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v3.0.1 | 2026-05-08 | AuthService（Magic Link）+ DraftReviewService；18 模組 |
| **v3.1** | **2026-05-08** | **PasswordAuthService（帳密）+ UserManagementService + ComplianceRuleService + SemanticMatcher + WhatsAppChannel；21 模組** |
