# 架構決策記錄 (ADR) — Synergy AI Closer's Copilot

> **版本:** v3.1 | **更新:** 2026-05-08 | **最後修訂**：五項重大架構調整（DB、認證、通知、規則庫、部署）

本文件彙整 MVP 階段所有重要架構決策。每條 ADR 獨立可讀，可於未來拆分為單獨檔案。

## v3.1 修訂說明（2026-05-08）

⚠️ **五項重大架構翻轉**（客戶決定）：

- **ADR-003 翻轉**：❌ Supabase Cloud → ✅ **本地 Container PostgreSQL 17 + pgvector；部署用 GCP Cloud SQL**
- **ADR-014 廢棄**：❌ Magic Link 認證移除 → ✅ **新增 ADR-015：系統管理員後台建用戶 + 帳密登入**
- **新增 ADR-016**：通知通道擴充至 **LINE + WhatsApp + Email** 三通道（Fallback 順序）
- **新增 ADR-017**：規則庫從 YAML 升級為 **資料庫 + pgvector 向量語意比對**
- **新增 ADR-018**：部署平台改為 **GCP（Cloud Run + Cloud SQL + Cloud Storage + Cloud CDN）**

**模組數**：18 → ~21；**ADR**：14 → 18；**API 端點**：~48 → ~60+

---

## ADR 索引

| # | 標題 | 狀態 | 日期 |
| :---: | :--- | :--- | :--- |
| 001 | 技術棧延用 module2（FastAPI + React 19 + Vite + Gemini/LiteLLM） | ⚠️ 部分推翻 | 2026-04-24 |
| 002 | 專案結構重構為 apps/ + packages/ 扁平 monorepo | 已接受 | 2026-04-24 |
| **003** | **❌ Supabase Cloud → ✅ 本地 PostgreSQL 17 + pgvector；GCP Cloud SQL 部署** | **⚠️ 翻轉（v3.1）** | **2026-05-08** |
| 004 | LLM 預設 Gemini-2.5-flash，LiteLLM 抽象可切換 | 已接受 | 2026-04-24 |
| 005 | Multi-tenant：預留 tenant_id，不實作完整隔離 | 已接受 | 2026-04-24 |
| 006 | M1 獲客模組拆層；MVP 不實作內容生成層 | 已接受 | 2026-04-24 |
| 007 | M5/M6 於 MVP 完全不做；原因與後果 | ⚠️ 部分推翻 | 2026-04-24 |
| 008 | 提醒通道：LINE Messaging API 優先，Email 為備援 | ⚠️ 升級（見 ADR-016） | 2026-04-24 |
| 009 | 商談摘要採「生成時寫入 DB + 快取不重算」策略 | 已接受 | 2026-04-24 |
| 010 | Compliance 三層防線（規則庫 + LLM 覆核 + 教練決策） | 已接受 | 2026-05-08 |
| 011 | ⚠️ 教練即審核者，無外部 Reviewer（v3.0.1 修訂） | ⚠️ 修訂 | 2026-05-08 |
| 012 | M6 輕量 Activity Tracking：共用 EventLog + 物化視圖 | 已接受 | 2026-05-08 |
| 013 | 前端框架改為 React 19 + Vite（推翻 ADR-001 前端部分） | 已接受 | 2026-05-08 |
| **014** | **❌ Magic Link 認證（已廢棄 v3.1）** | **⚠️ 廢棄** | **2026-05-08** |
| **015** | **✨ 系統管理員後台建用戶 + 帳密登入（取代 ADR-014）** | **新增** | **2026-05-08** |
| **016** | **✨ 通知通道擴充至 LINE/WhatsApp/Email（升級 ADR-008）** | **新增** | **2026-05-08** |
| **017** | **✨ 規則庫 DB 化 + pgvector 語意比對（升級 ADR-010）** | **新增** | **2026-05-08** |
| **018** | **✨ 部署平台 GCP Cloud Run + Cloud SQL（修訂 ADR-013）** | **新增** | **2026-05-08** |

---

## ADR-001 ~ ADR-013

（參見上版本文件，維持不變。只在 ADR-003、ADR-008、ADR-013 處加上 v3.1 修訂註記）

### ADR-003 補充 v3.1 修訂

> **原決策（v3.0）**：Supabase Cloud（PostgreSQL + pgvector + Auth + RLS）
> **⚠️ v3.1 翻轉**：本地 Container PostgreSQL 17 + pgvector；GCP Cloud SQL 生產部署

詳見 **ADR-018**。

### ADR-008 補充 v3.1 升級

> **原決策（v3.0）**：LINE 優先、Email 備援
> **✅ v3.1 升級**：LINE 優先、WhatsApp 次選、Email 備援（三通道 Fallback）

詳見 **ADR-016**。

### ADR-013 補充（無修訂）

前端技術棧（React 19 + Vite）維持不變。部署平台改為 GCP 見 **ADR-018**。

---

## ADR-014: ❌ Magic Link 認證（v3.1 廢棄）

> **原狀態:** 已接受（v3.0.1） | **廢棄狀態:** ⚠️ 已廢棄（v3.1，2026-05-08）| **推翻原因:** 客戶決定採簡單帳密登入 + 後台管理員建用戶

### 原決策概述

v3.0.1 採 Supabase Magic Link + JWT，教練無需記密碼，每次登入自動寄送 Magic Link。

### v3.1 廢棄原因

1. **簡化管理**：Magic Link 依賴 Resend Email 穩定性與額度，無法精準控制
2. **教練 UX 改善**：帳密登入（首次由 admin 初設）比每次郵件等待更快
3. **成本考量**：移除 Resend 依賴，減少第三方服務
4. **後續簡化**：帳密支援「密碼重置」與「首次強制改密碼」，更符合企業內部應用

### 替代方案

見 **ADR-015**（系統管理員後台建用戶 + 帳密登入）。

### 資料遷移

- 清除 `auth.users` 中既有的 Magic Link session
- 將 coach_id 與 email 從 Supabase Auth 移至 users 表中自建（加 password_hash、password_hasher）

---

## ADR-015: ✨ 系統管理員後台建用戶 + 帳密登入

> **狀態:** 新增 | **日期:** 2026-05-08 | **決策者:** kuanwei | **推翻:** ADR-014（Magic Link） | **對應規格**：[12_phase1_mvp.md § M0](./12_phase1_mvp.md)

### 1. 背景與問題

- **上下文**：客戶決定廢棄 Magic Link，採簡單帳密登入以簡化系統依賴與教練 UX。
- **問題**：帳密系統如何初始化、管理、與更新？
- **驅動因素**：
  - 企業內部應用（不是公開平台），無自助註冊需求
  - 簡化第三方 email 服務依賴
  - 教練體驗最優化（直接輸入帳密，無郵件等待）

### 2. 決策

**採用「系統管理員後台建用戶 + 帳密登入」**

1. **用戶建立流程**：
   - 系統管理員在 `/admin/users` 後台頁面新增教練帳號
   - 輸入：email + 初始密碼（由系統隨機生成或 admin 手動設）
   - 密碼存儲：bcrypt hash (cost=12) → `users.password_hash`
   - 初始化標記：`users.must_change_password = true`

2. **首次登入流程**：
   - 教練在 `/login` 輸入 email + 密碼
   - 系統驗證：檢查 email 存在 + password_hash 匹配
   - JWT 核發（access 1h + refresh 7d）
   - 強制跳轉 `/auth/change-password`（因 `must_change_password = true`）
   - 教練設定新密碼 → 更新 DB + 標記 `must_change_password = false`

3. **日常登入**：
   - 教練輸入 email + 密碼
   - 驗證成功 → JWT 核發 → 重導向 `/leads` 或 `/leader/summary`

4. **密碼政策**：
   - 最少 10 字元，含數字 + 字母（大小寫）
   - bcrypt cost = 12（~0.3s 驗證時間，安全與性能平衡）
   - 暴力破解防護：失敗 5 次 → 帳號鎖定 15 分鐘
   - 密碼重置：admin 可在 `/admin/users/:id/reset-password` 強制重設，教練須再次首次登入流程

5. **後台操作**（`/admin/users`）：
   - `GET /admin/users` — 列表
   - `POST /admin/users` — 建立（email + 初始密碼）
   - `PATCH /admin/users/:id` — 編輯（name、role、status）
   - `DELETE /admin/users/:id` — 刪除（邏輯刪除，保留稽核記錄）
   - `POST /admin/users/:id/reset-password` — 強制重設密碼

### 3. 實作細節

**模組**：
- `UserManagementService`（Application）：admin 操作 CRUD
- `PasswordAuthService`（Application）：login / change-password / logout
- `PasswordHasher`（Domain）：bcrypt 封裝

**資料表**：
```sql
-- users 表新增欄位
ALTER TABLE users ADD COLUMN password_hash TEXT;                    -- bcrypt hash
ALTER TABLE users ADD COLUMN must_change_password BOOLEAN DEFAULT true;  -- 首次強制改
ALTER TABLE users ADD COLUMN failed_login_count INT DEFAULT 0;      -- 暴力破解計數
ALTER TABLE users ADD COLUMN locked_until TIMESTAMPTZ;              -- 鎖定至時間
ALTER TABLE users ADD COLUMN whatsapp_id TEXT;                      -- WhatsApp 整合（新增）
```

### 4. 後果

- **正向**：
  - 消除 Resend 依賴 + Magic Link 複雜性
  - Admin 掌握完全控制（建立、重設、刪除）
  - 首次強制改密碼符合企業安全標準
  - 密碼重置無需 email，直接 admin 後台操作
- **負向**：
  - 教練需要記住密碼（緩解：密碼 manager 或 SSO Phase 2）
  - Admin 需要管理 password resets（工作量小）
- **追蹤**：failed login 計數、lock 解除次數、password reset 頻率

### 5. 影響

- 移除 Resend（Magic Link email）使用，但 Resend 仍用於 M4 Email 提醒通道
- 新增 `/admin/users` UI 頁面
- API 端點新增 12 個（見 [05_api.md § Admin Endpoints](./05_api.md)）

---

## ADR-016: ✨ 通知通道擴充至 LINE/WhatsApp/Email

> **狀態:** 新增 | **日期:** 2026-05-08 | **決策者:** kuanwei | **升級:** ADR-008 | **對應規格**：[12_phase1_mvp.md § M4](./12_phase1_mvp.md)

### 1. 背景與問題

- **上下文**：Pilot 覆蓋三個區域：台灣（LINE 優先）、東南亞（WhatsApp 普遍）、中國（Email 備援）
- **問題**：如何在統一架構下支援多通道，並合理 fallback？
- **驅動因素**：
  - 地區適配性（不同國家使用習慣）
  - 傳遞保障（某通道失敗自動降級）
  - 成本最優化（每個通道按用量計費）

### 2. 決策

**採用「三層 Fallback」**：**LINE（主） → WhatsApp（次） → Email（備援）**

1. **通道優先級與配置**：
   ```
   LINE Messaging API
   ├─ 優先級：第一選
   ├─ 目標用戶：台灣 coach（日活率最高）
   ├─ 月費：LINE Light Plan ~800 NTD（15k 訊息額度）
   ├─ 失敗觸發：網路超時、限流、無效 user_id
   
   WhatsApp Business Cloud API
   ├─ 優先級：第二選
   ├─ 目標用戶：東南亞 / 國際 coach（無 LINE 時用）
   ├─ 月費：按訊息量計費（~0.5 USD / 訊息，1000 訊息 ~500 NTD）
   ├─ 失敗觸發：LINE 已嘗試 3 次失敗 或 user 無 whatsapp_id
   
   Resend Email
   ├─ 優先級：備援
   ├─ 目標用戶：所有 coach（最後保險）
   ├─ 月費：< 3000 email/月 免費
   ├─ 失敗觸發：前兩通道全部失敗
   ```

2. **用戶配置**：
   - `users` 表新增三個欄位：`line_user_id`、`whatsapp_id`、`email`
   - `coach_preferences` 表（新）：記錄教練的通道偏好（可自訂順序）

3. **發送流程**（NotificationService）：
   ```python
   async def send_reminder(coach_id, message):
       # 1. 讀取 coach preferences 與聯絡資訊
       coach = await coach_repo.get(coach_id)
       prefs = coach.notification_preferences or DEFAULT_PREFS  # LINE > WhatsApp > Email
       
       # 2. 嘗試 LINE
       if coach.line_user_id and LineChannel in prefs:
           success = await line_channel.send(coach.line_user_id, message)
           if success:
               log_event('reminder_sent', channel='line')
               return
       
       # 3. 失敗 → WhatsApp
       if coach.whatsapp_id and WhatsAppChannel in prefs:
           success = await whatsapp_channel.send(coach.whatsapp_id, message)
           if success:
               log_event('reminder_sent', channel='whatsapp')
               return
       
       # 4. 再失敗 → Email
       success = await email_channel.send(coach.email, message)
       if success:
           log_event('reminder_sent', channel='email')
           return
       
       # 5. 全部失敗 → 標記未送 + 告警
       log_event('reminder_failed', all_channels_failed=True)
       alert_admin(f"Coach {coach_id} 通知失敗")
   ```

4. **WhatsApp 整合細節**：
   - API：Meta WhatsApp Business Cloud API（官方）
   - 認證：`WHATSAPP_ACCESS_TOKEN`（長期 token，via Meta Business Manager）
   - Webhook：`POST /webhooks/whatsapp` 接收訊息確認回呼
   - Phone Number ID：客戶需事先申請 WhatsApp Business 帳號 + 取得 Phone Number ID
   - 訊息樣板：需預先在 Meta dashboard 建立審核通過的樣板（合規檢查）
   - 計費：按發送訊息數計費（不按成功率）

### 3. 後果

- **正向**：
  - 全球覆蓋三個主要通訊平台
  - 自動 fallback 確保訊息送達率
  - 教練可自訂通道偏好
  - 成本可控（按通道選擇）
- **負向**：
  - WhatsApp 需客戶自行申請與配置（交付成本 +1 週）
  - 訊息樣板審核延遲（1-2 天）
  - 月費額外 ~500 NTD（WhatsApp）
- **追蹤**：每通道送達率、失敗率、平均 fallback 層數

### 4. 環境變數

```bash
# LINE（既有）
LINE_MESSAGING_API_KEY=...
LINE_MESSAGING_API_SECRET=...

# WhatsApp（新增）
WHATSAPP_ACCESS_TOKEN=...
WHATSAPP_PHONE_NUMBER_ID=...
WHATSAPP_VERIFY_TOKEN=...    # webhook 驗證

# Email（既有）
RESEND_API_KEY=...
```

### 5. 影響

- 新增 `WhatsAppChannel` 模組（Infrastructure）
- 新增 `POST /webhooks/whatsapp` endpoint（接收訊息回呼與送達確認）
- 新增 `coach_preferences` 表
- 修改 `NotificationService` 邏輯（三層 fallback）

---

## ADR-017: ✨ 規則庫 DB 化 + pgvector 語意比對

> **狀態:** 新增 | **日期:** 2026-05-08 | **決策者:** kuanwei | **升級:** ADR-010（Compliance 三層防線） | **對應規格**：[12_phase1_mvp.md § F5 合規 AI](./12_phase1_mvp.md)

### 1. 背景與問題

- **上下文**：Pilot 期客戶需要動態管理合規詞表（C1/C2/C3/C4），並支援自動改寫建議。YAML 固定配置無法滿足。
- **問題**：規則庫應如何儲存、更新、與應用？
- **驅動因素**：
  - 規則庫頻繁變更（客戶每週微調禁用詞）
  - 需要向量語意比對（「療效」與「治療」近似，應同時命中）
  - 需要自動改寫建議（違規文案自動建議修改方案）

### 2. 決策

**採用「資料庫 + pgvector 向量語意比對」**

1. **資料表設計**：
   ```sql
   CREATE TABLE compliance_rules (
       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
       tenant_id UUID NOT NULL FK -> tenants,
       category TEXT NOT NULL,  -- C1/C2/C3/C4
       phrase TEXT NOT NULL,    -- 黑名單詞或句（如 "療效" / "保證治療"）
       severity TEXT NOT NULL,  -- low/medium/high
       suggested_rewrite TEXT,  -- 自動改寫建議（如 "可提供幫助" 代替 "保證療效"）
       embedding VECTOR(1536),  -- pgvector 向量（OpenAI ada-002 或 Gemini embedding）
       enabled BOOLEAN DEFAULT true,
       created_by UUID NOT NULL FK -> users,
       updated_by UUID NOT NULL FK -> users,
       created_at TIMESTAMPTZ DEFAULT now(),
       updated_at TIMESTAMPTZ DEFAULT now(),
       
       -- Indexes
       CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id),
       INDEX idx_category_enabled ON (category, enabled),
       INDEX idx_embedding ON embedding USING ivfflat (vector_cosine_ops)  -- pgvector HNSW 或 IVFFlat
   );
   ```

2. **三層合規檢查新流程**：
   ```
   Layer 1 — 規則庫字面匹配（<10ms）
   ├─ 逐一檢查 compliance_rules，詞重合 → 標 candidate
   └─ 無命中 → 自動通過（標 auto_pass）
   
   Layer 2 — 向量語意比對 (pgvector，<50ms)
   ├─ 文本轉向量：`embedding = embed_text(原文)`
   ├─ cosine_similarity > THRESHOLD (0.85) → 匹配風險規則
   ├─ 收集所有匹配規則（可能多個）
   ├─ LLM 二次覆核：輸入原文 + 匹配規則 + 改寫建議 → 質量評分
   └─ quality_score ≥ 0.7 → 標 lm_approved；< 0.7 → 標 quality_failed
   
   Layer 3 — 教練決策（人工）
   ├─ 訊息 + 改寫版 + 風險標記進 message_drafts
   ├─ 教練 UI 展示原文、改寫版、命中規則、quality_score
   ├─ 教練決策：接受、編輯、或丟棄
   └─ 「發送」時才寫入 compliance_logs（可稽核）
   ```

3. **Embedding 模型選擇**：
   - **建議 1**：Gemini text-embedding（維度 768）或 OpenAI ada-002（維度 1536）
   - **建議 2**：本地 sentence-transformers（開源、無月費，但需自己部署）
   - **使用 API**：Gemini 月費 ~100-200 NTD（embedding 便宜）
   - **環境變數**：`EMBEDDING_MODEL=gemini` 或 `sentence-transformers`

4. **Admin 後台操作**（`/admin/compliance-rules`）：
   - `GET /admin/compliance-rules` — 列表（按 category 篩選）
   - `POST /admin/compliance-rules` — 新增規則
   - `PATCH /admin/compliance-rules/:id` — 編輯規則 + 重算 embedding
   - `DELETE /admin/compliance-rules/:id` — 刪除
   - `POST /admin/compliance-rules/import` — CSV 批量匯入（包含詞表、severity、改寫建議）
   - `POST /admin/compliance-rules/regenerate-embeddings` — 手動重算所有 embedding（月 1-2 次）

5. **相似度閾值與調整**：
   - 預設 `SEMANTIC_SIMILARITY_THRESHOLD = 0.85`（可配置）
   - Pilot 期按實際誤判率調整（目標 < 5%）
   - Admin 可在後台檢視「被拒絕但應通過」的案件 → 調整閾值

### 3. 實作模組

- **ComplianceRuleService**（Application）：CRUD + embedding 計算
- **SemanticMatcher**（Domain）：純函式 cosine_similarity 與規則比對邏輯
- **ComplianceService**（升級）：Layer 2 整合 SemanticMatcher + LLM 覆核

### 4. 後果

- **正向**：
  - 規則庫動態可更新（無需重啟）
  - 語意比對提高準確度（「療效」+ 「治療」+ 「見效」 一次命中）
  - 向量存儲支援未來機器學習（Phase 2 可訓練私有分類器）
  - CSV 批量匯入簡化客戶初始化
- **負向**：
  - pgvector extension 需額外配置（但 PostgreSQL 17+ 現成支援）
  - embedding 月費 ~100-200 NTD（若用 API）
  - 冷啟動時需預計算所有規則的 embedding（~10 秒）
- **追蹤**：規則庫命中率、語意匹配誤判率、embedding API 月費

### 5. 環境變數

```bash
SEMANTIC_SIMILARITY_THRESHOLD=0.85
EMBEDDING_MODEL=gemini  # 或 sentence-transformers
GEMINI_EMBEDDING_API_KEY=...  # 若選 Gemini
```

---

## ADR-018: ✨ 部署平台 GCP（Cloud Run + Cloud SQL + Cloud CDN）

> **狀態:** 新增 | **日期:** 2026-05-08 | **決策者:** kuanwei | **修訂:** ADR-013（前端部署）| **對應規格**：[11_deployment.md](./11_deployment.md)

### 1. 背景與問題

- **上下文**：v3.0 計畫用 Cloudflare Pages（前端）+ Railway（後端），但客戶決定統一 GCP（成本與管理集中化）。
- **問題**：如何在 GCP 上部署 FastAPI + React SPA + PostgreSQL？
- **驅動因素**：
  - 企業級基礎設施穩定性
  - 統一 Google Cloud 生態（文件一致、支持一致）
  - 成本可控（Cloud Run 按使用量計費、Cloud SQL free tier 足夠 Pilot）

### 2. 決策

**採用 GCP 原生服務全棧**

| 組件 | GCP 服務 | 規格 | 月費估 |
|---|---|---|---|
| **前端靜態** | Cloud Storage + Cloud CDN | 1 GB 存儲 + edge cache | 100-200 NTD |
| **後端 API** | Cloud Run | 2 vCPU / 4 GB RAM（自動擴展） | 200-500 NTD |
| **資料庫** | Cloud SQL for PostgreSQL 17 | db-f1-micro (0.6GB RAM) + pgvector | 250-350 NTD |
| **排程任務** | Cloud Scheduler + Cloud Run | 每小時掃提醒 + 30min 更新物化視圖 | 50 NTD |
| **容器 registry** | Artifact Registry | docker 鏡像儲存 | 50 NTD |
| **機密管理** | Secret Manager | API keys、DB 密碼 | 免費（6 版本上限） |
| **監控日誌** | Cloud Logging + Cloud Monitoring | 標準監控 | 50-100 NTD |
| **域名 + 負載均衡** | Cloud DNS + Cloud Load Balancer | 按查詢 + 按流量 | 100-200 NTD |
| **合計** | — | — | **~800-1,500 NTD/月** |

### 3. 架構拓撲

```
使用者（瀏覽器）
    ↓
Cloud CDN（邊界節點）
    ├─ 靜態資源（HTML/JS/CSS）→ Cloud Storage
    └─ API 請求 → Cloud Load Balancer
         ↓
    Cloud Run（FastAPI 容器）
         ├─ 自動擴展 0-10 instance
         ├─ 健康檢查 /health
         └─ JWT 驗證
         ↓
    Cloud SQL（PostgreSQL 17 + pgvector）
         ├─ Cloud SQL Auth Proxy（SSL only）
         ├─ 自動備份（日）
         └─ 讀副本（可選 Phase 2）
         
排程層（Cloud Scheduler）
    ├─ 每小時：掃待發提醒
    ├─ 每 30 min：更新物化視圖
    └─ 觸發 → Cloud Run Job Endpoint
```

### 4. 開發與部署流程

#### 本地開發（docker-compose）
```bash
# docker-compose.yml
services:
  postgres:
    image: postgres:17
    environment:
      POSTGRES_DB: synergy_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev_local
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    command: |
      postgres -c shared_preload_libraries=vector

  pgvector:
    image: pgvector/pgvector:pg17
    # 或在 postgres 容器中執行：CREATE EXTENSION vector;

volumes:
  postgres_data:
```

#### CI/CD（GitHub Actions）

```yaml
name: Deploy to GCP

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # 前端
      - name: Build Frontend
        run: |
          cd apps/web && npm install && npm run build
          
      - name: Deploy Frontend to Cloud Storage
        run: |
          gsutil -m rsync -r -d apps/web/dist gs://synergy-ai-web-bucket/
          
      - name: Invalidate CDN Cache
        run: |
          gcloud compute url-maps invalidate-cdn-cache web-load-balancer --path "/*"
      
      # 後端
      - name: Build Backend Docker Image
        run: |
          docker build -t gcr.io/${{ secrets.GCP_PROJECT_ID }}/synergy-api:${{ github.sha }} \
            -f apps/api/Dockerfile apps/api
          docker push gcr.io/${{ secrets.GCP_PROJECT_ID }}/synergy-api:${{ github.sha }}
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy synergy-api \
            --image gcr.io/${{ secrets.GCP_PROJECT_ID }}/synergy-api:${{ github.sha }} \
            --region asia-east1 \
            --memory 4Gi \
            --cpu 2 \
            --set-env-vars DATABASE_URL=cloudsql://... \
            --allow-unauthenticated
      
      # DB 遷移
      - name: Run Migrations
        run: |
          gcloud run jobs execute synergy-migrate \
            --region asia-east1 \
            --wait
```

#### Docker 鏡像（apps/api/Dockerfile）

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# 複製 uv lock
COPY uv.lock pyproject.toml ./

# 安裝依賴
RUN pip install --no-cache-dir uv
RUN uv sync --no-dev

# 複製應用
COPY apps/api ./

# 健康檢查
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

# 用 uv run 啟動
CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 5. 環境變數管理

#### 本地開發（.env.local）
```bash
DATABASE_URL=postgresql+asyncpg://dev:dev_local@localhost:5432/synergy_dev
API_URL=http://localhost:8000
VITE_API_BASE_URL=http://localhost:8000
VITE_SUPABASE_URL=http://localhost:54321  # 若用本地 Supabase 替代
...
```

#### Cloud Run（Secret Manager）
```bash
# 儲存 Secret
gcloud secrets create database-url --data-file=- <<< "postgresql+asyncpg://user:pass@cloud-sql-ip:5432/synergy"
gcloud secrets create gemini-api-key --data-file=- <<< "..."
...

# Cloud Run 掛載 Secret
gcloud run deploy synergy-api \
  --set-env-vars DATABASE_URL=projects/PROJECT_ID/secrets/database-url/versions/latest:ref \
  ...
```

### 6. PostgreSQL 安全配置

#### Cloud SQL（GCP 管控）
- SSL 強制（pg_hba.conf 自動設定）
- Cloud SQL Auth Proxy（應用側無需儲存密碼）
- 自動備份（日期保留 30 天）
- 自動更新（每季月次 patch）

#### 應用連線
```python
# Cloud SQL Auth Proxy 簡化連線
DATABASE_URL = "postgresql+asyncpg://user:pass@/synergy?host=/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME"

# 或顯式 Cloud SQL Proxy
import sqlalchemy.pool as pool
engine = create_engine(
    DATABASE_URL,
    poolclass=pool.NullPool,  # Cloud Run 無需連線池
    echo=False
)
```

### 7. 部署環境變數對照

| 變數 | 本地 | Cloud Run |
|---|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://dev:@localhost:5432/...` | Secret Manager（SSL） |
| `GEMINI_API_KEY` | `.env` | Secret Manager |
| `WHATSAPP_ACCESS_TOKEN` | `.env` | Secret Manager |
| `LINE_MESSAGING_API_KEY` | `.env` | Secret Manager |
| `VITE_API_BASE_URL` | `http://localhost:8000` | `https://api.synergy-ai.tw` |
| `LOG_LEVEL` | `DEBUG` | `INFO` |

### 8. 成本估算（月度，Pilot 階段）

| 項目 | 成本 | 備註 |
|---|---|---|
| Cloud Storage + CDN | 100-200 | 1 GB + 10 GB egress |
| Cloud Run | 200-500 | 平均 0.5 instance，3000h/月 |
| Cloud SQL | 250-350 | db-f1-micro，300 GB storage |
| Cloud Scheduler | 50 | 2 個 job |
| Cloud Logging | 50-100 | 100 GB logs/月 |
| Artifact Registry | 50 | 1 GB docker image |
| Cloud DNS | 20 | 4 zone + queries |
| Cloud Load Balancer | 100-150 | per rule + data |
| **合計** | **~820-1,370 NTD** | 比 Cloudflare+Railway ~500 NTD 高，但統一管理 |

### 9. 後果

- **正向**：
  - 企業級基礎設施（SLA 99.95%）
  - 自動擴展與負載均衡無需手工維運
  - Cloud SQL 自動備份 + SSL 強制
  - 監控與日誌一套（Cloud Logging）
  - Secret Manager 集中管理機密
- **負向**：
  - GCP 學習曲線（但文件充分）
  - 月費較 Railway + Cloudflare 高 ~500 NTD
  - 鎖定 GCP 生態（但中立、不像 Vercel / Render 有其他限制）
- **Phase 2 平滑升級**：
  - 若需要 Cloud SQL 讀副本（高可用），GCP 支援無縫加副本
  - 若需要 Firestore（NoSQL），GCP 內部集成最佳

### 10. 迴避策略

- **不用 App Engine**：Cloud Run 更彈性、cold start 快（3-5s vs 10-20s）
- **不用 GKE（Kubernetes）**：Pilot 量小，Cloud Run serverless 足夠；Phase 2 若量爆炸再評估
- **不用 Firebase Hosting**：Cloud Storage + CDN 更細粒度控制

---

## 附錄：決策相依圖（v3.1 更新）

```
ADR-001 (技術棧) ⚠️ 部分推翻
   ├─→ ADR-002 (結構)
   ├─→ ❌ ADR-003 (DB: Supabase Cloud) → ✅ 翻轉為 GCP Cloud SQL
   │      ├─→ ADR-005 (tenant_id 靠 PostgreSQL RLS)
   │      ├─→ ADR-012 (M6 物化視圖 on PostgreSQL)
   │      └─→ ❌ ADR-014 (Magic Link) → 新增 ✅ ADR-015 (帳密+後台建用戶)
   ├─→ ADR-004 (LLM: Gemini + LiteLLM)
   │      ├─→ ADR-009 (摘要快取策略)
   │      ├─→ ADR-010 (Compliance Layer 2 LLM 覆核)
   │      │   └─→ ⬆️ ADR-017 (規則庫 DB+pgvector 升級)
   │      └─→ ADR-011 (⚠️ v3.0.1 修訂：教練即審核者，無外部 Reviewer)
   └─→ ADR-013 (React+Vite 前端)
       └─→ ✨ ADR-018 (部署改 GCP，修訂 ADR-013）

ADR-006 (M1 延後)  ── 影響 PRD Epic 範圍
ADR-007 (M5/M6 延後) ── ⚠️ 部分推翻：ADR-012 將 M6 輕量版復活
⬆️ ADR-008 (LINE 提醒) ── 升級為 ADR-016 (LINE/WhatsApp/Email 三通道)
ADR-010 (Compliance) ── ⬆️ 升級為 ADR-017 (語意比對+pgvector)
ADR-011 (教練審核) ── 教練草稿流程，無外部審核
ADR-012 (M6 輕量) ── 影響 Epic F + 新增 Leader 視角頁面群
ADR-013 (React+Vite) ── ⬆️ 修訂為 ADR-018 (GCP 部署)
❌ ADR-014 (Magic Link) ── 廢棄，改用 ADR-015
✨ ADR-015 (帳密登入) ── 新增 M0 認證，所有端點基礎依賴
✨ ADR-016 (多通道) ── 新增 Notification 層級 fallback
✨ ADR-017 (語意規則庫) ── 升級 Compliance 準確度
✨ ADR-018 (GCP 部署) ── 統一雲端基礎設施
```

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v1.0 | 2026-04-24 | 初版（ADR-001～013） |
| v3.0.1 | 2026-05-08 | 新增 ADR-014 (Magic Link Auth)；修訂 ADR-011 (教練即審核者) |
| **v3.1** | **2026-05-08** | **5 項重大翻轉：DB 改 PostgreSQL/GCP、認證改帳密+後台建用戶、通知加 WhatsApp、規則庫 DB+pgvector、部署改 GCP（新增 ADR-015~018）** |
