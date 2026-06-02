<!-- 版本 v0.3 | 日期 2026-06-02 | 狀態 draft | 對應 PRD v0.3 | 專案 synergy(repo 根) -->

# 00 Tech Spec 總覽 — Care Copilot

## 文件導覽

本文件集涵蓋 `synergy` 專案（repo 根 `d:/project/synergy/`）的完整技術規格，各文件職責如下：

| 文件                                                    | 一句話說明                                                                |
| :------------------------------------------------------ | :------------------------------------------------------------------------ |
| **00_tech-spec.md**（本文件）                     | 產品定位、範圍、技術選型、NFR、成功標準、待答問題的統一入口               |
| [01_architecture.md](./01_architecture.md)                 | 系統架構總圖、元件關係、資料流、AI 層整合介面、部署拓撲                   |
| [02_api.md](./02_api.md)                                   | 全部 REST 端點規格、請求/回應 schema、SSE 串流協定、錯誤碼                |
| [03_data-model.md](./03_data-model.md)                     | 資料表的完整 schema、ER 圖、索引策略、RLS policy 設計                     |
| [04_frontend.md](./04_frontend.md)                         | 頁面清單、元件樹、Apple 設計 tokens、PWA manifest、狀態管理               |
| [05_backend.md](./05_backend.md)                           | FastAPI 路由層、服務層、LangGraph agent 整合介面、APScheduler 排程        |
| [06_project-structure.md](./06_project-structure.md)       | 目錄結構、埠號規劃、命名規範、開發環境啟動指令                            |
| [07_team-division.md](./07_team-division.md)               | 團隊分工（50/30/20 垂直切片）、檔案所有權矩陣、低 merge 衝突協作策略      |
| [客戶需求清單_給客戶版.md](./客戶需求清單_給客戶版.md)     | 面向 Synergy 教練的功能確認清單（非技術語言），承接 P0 待答問題的外部對話 |
| [客戶需求清單_內部對照版.md](./客戶需求清單_內部對照版.md) | 客戶版需求對應的工程任務分解、P0 問題 Owner 與截止週次                    |
| PRD.md                                                  | 功能模組導向說明（另見 PRD.md）                                           |

---

## 1. 產品定位

### 1.1 一句話定位

**「直銷商的關懷 Copilot — 記得每位你關心的人、知道今天該聯絡誰、講話有溫度不像在推銷。」**

Phase I：4 週 Pilot，服務 **5 位 Synergy 教練 + 1 位 Leader + 5 位下線**；PMF 定義 = W4 結尾至少 4/5 教練自願付 USD 39/月。

北極星指標：**每週 Care Action 數**（關懷動作，非推銷行為）。

### 1.2 四個核心 Persona（一句話）

| Persona                                                  | 一句話                                                                                               |
| :------------------------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| **Amy**（主 Persona，Active 直銷商 Rank 2-3）      | 帶 20-100 位客戶的中段直銷商，需要記住每個人的情境、拿捏朋友 tone，並在對話現場接住異議。            |
| **Nina**（次 Persona，Newbie 直銷商 Rank 0-1）     | 剛入行 6 個月以內的新手，需要每日節奏引導、有模板可參考但不死板，以及合規防護。                      |
| **Linda**（次 Persona，Leader/Director Rank 5+）   | 帶 10-50 位下線的資深 Leader，需要個人客戶工具加上下線招募漏斗可視化，確保下線不踩線。               |
| **Tina**（GTM Persona，Top 100 Leader Influencer） | 業界 KOL，不是主要使用者，而是 GTM 病毒引擎：代言推薦帶動教練圈擴散，以 Founders Circle 換長期綁定。 |

### 1.3 PMF 與北極星指標定義

| 指標                 | 定義                                                                                                  | 量化門檻（Pilot） |
| :------------------- | :---------------------------------------------------------------------------------------------------- | :---------------- |
| **PMF**        | W4 結尾，5 位 Amy 教練裡至少 4 位主動表達「我願意付 $39/月」                                          | 4/5               |
| **北極星指標** | 每位活躍直銷商每週發起的 Care Action 數（關懷動作：生日祝賀、關心訊息、純關懷草稿採用；不含推銷訊息） | 看成長趨勢        |
| **次級指標**   | 草稿採用率、今日任務完成率、樣品跟進率、合規觸發後改寫率                                              | 觀察方向          |

---

## 2. 11 個工具清單 × 4 週 Roadmap

### 2.1 工具一句話說明

| #   | 工具名稱        | 一句話                                                                     | AI 引擎                                        |
| :-- | :-------------- | :------------------------------------------------------------------------- | :--------------------------------------------- |
| T01 | 關係記憶活檔案  | 給每位客戶建一份隨時可補充的活檔案：健康關注、家庭、興趣、互動脈絡。       | Sonnet 4.6（insight 生成）                     |
| T02 | 生活事件雷達    | 偵測生日、換工作、寶寶誕生等生活事件，推出非推銷的關懷提醒。               | Haiku 4.5（文字型事件抽取）                    |
| T03 | 語氣/情緒感測器 | 讀對方近期訊息判斷「壓力大/中性/開心」三檔，告知直銷商今天適不適合提產品。 | Haiku 4.5（三檔分類）                          |
| T04 | 太業務員警報    | 連 3 則推銷就觸發警告，預生純關懷草稿，保住對話溫度。                      | 純規則引擎（無 AI）                            |
| T05 | 今日 5 件事     | App 首頁每日 5 張優先任務卡，早上 10 秒知道今天該關心誰。                  | 規則排序（v1 無 AI）                           |
| T06 | 訊息草稿        | 依活檔案脈絡生 3 種語氣草稿（關懷/隨意/商業），AI 不自動發送。             | Haiku 4.5 首字 + Sonnet 4.6 全文 streaming     |
| T07 | 樣品追蹤        | 發出樣品後自動排 48h/72h/7d 三個跟進提醒並預生草稿。                       | Haiku 4.5（跟進草稿）                          |
| T08 | 語音草稿        | 文字草稿一鍵轉 TTS 語音（≤60 秒），直銷商下載後自行傳給客戶。             | OpenAI TTS 或 ElevenLabs（VoiceProvider 抽象） |
| T09 | 快速異議處理器  | 10 種常見異議一鍵獲得共情型/提問型/邀請型 3 種接話建議。                   | Haiku 4.5（速度優先）                          |
| T10 | 健康問卷        | 可選工具：對高意願客戶發 7 天有效一次性連結，填完後 AI 生摘要。            | Sonnet 4.6（問卷摘要）                         |
| T11 | 招募漏斗        | 追蹤暖名單→曝光→邀約→簽約四階段轉換率，招募話術走最嚴格合規。           | Sonnet 4.6                                     |
| SYS | 合規低語        | 所有外送草稿必過 regex sidecar（<50ms），綠/黃/紅三燈，紅燈強制阻擋。      | 純規則引擎（regex，無 AI）                     |
| PLT | 平台支撐        | 隱私同意、Freemium 配額、Care Streak、病毒擴散、學習紀錄；**LINE OA 收訊→新客戶 round-robin 輪派教練→輔助回覆草稿（過合規）→教練審核→發送**。 | 無 AI（純寫入）；輔助草稿走 Haiku 4.5          |

### 2.2 4 週 Roadmap

```
W1（骨架週）
  ├─ repo 根獨立專案骨架建立（backend :8002 / frontend :3002）
  ├─ PostgreSQL + pgvector container 連線 + RLS 基礎 policy（三 session 變數）
  ├─ JWT 認證（FastAPI 自建 JWT，角色 distributor / leader）
  ├─ 資料模型 Day 1 全建（全表 + pgvector，含 official_accounts / inbound_messages）
  ├─ T01 關係記憶活檔案（contacts CRUD + 4 種補資料入口）
  ├─ SYS 合規低語（50 詞庫 regex sidecar）
  ├─ PLT 學習紀錄寫入基礎架構
  └─ 觀測基礎（OTel + Langfuse + Sentry 串接）

W2（核心 AI 週）
  ├─ T02 生活事件雷達（規則 + Haiku 4.5 抽取）
  ├─ T05 今日 5 件事（規則排序，APScheduler 每日凌晨）
  ├─ T06 訊息草稿（3 語氣，SSE streaming，Haiku 首字 + Sonnet 全文）
  └─ T03 語氣/情緒感測器（Haiku 三檔分類）

W3（追蹤 + 警報 + LINE 整合週）
  ├─ T07 樣品追蹤（APScheduler 48h/72h/7d）
  ├─ T11 招募漏斗（四階段 + 嚴格合規）
  ├─ T04 太業務員警報（純規則引擎）
  ├─ T09 快速異議處理器（Haiku，10 種預設）
  ├─ PLT Freemium 配額熔斷
  └─ LINE OA 整合（webhook 收訊 + round-robin 輪派 + 輔助回覆草稿 + 教練審核發送）
       ├─ LINE Messaging API webhook endpoint（收訊 → 200 < 3s）
       ├─ 新客戶 round-robin 輪派下一位 active 教練；既有客戶 sticky；Leader 可改派
       ├─ 輔助回覆草稿生成（Haiku 4.5，過合規 sidecar）
       └─ 教練審核後手動按「發送」→ push（reply token ~1 分鐘失效故走 push）

W4（語音 + 問卷 + Pilot 週）
  ├─ T08 語音草稿（VoiceProvider 抽象，TTS 供應商 W4 前選型）
  ├─ T10 健康問卷（一次性連結，Sonnet 摘要）
  ├─ PLT 病毒擴散（Care Streak + 推薦獎勵）
  └─ Pilot 啟動（5 教練 + 1 Leader + 5 下線）
```

| 週次         | 交付工具                                                  | 備註                              |
| :----------- | :-------------------------------------------------------- | :-------------------------------- |
| **W1** | T01、SYS、PLT 基礎、認證、資料模型                        | 後端骨架，無 AI 草稿              |
| **W2** | T02、T05、T06、T03                                        | 核心 AI 功能，SSE 串流            |
| **W3** | T07、T11、T04、T09、Freemium 熔斷、LINE OA 整合           | 追蹤 + 警報 + 異議 + LINE 收發    |
| **W4** | T08、T10、病毒擴散、Pilot 啟動                            | 語音選型需 W4 前完成              |

---

## 3. 技術選型總表

> 直接採用跨文件共用契約 C 章，所有欄位為唯一真實來源。

| 分類                        | 選用技術                          | 版本/規格                                     | 選擇理由                                                                                                      | AI 層備註         |
| :-------------------------- | :-------------------------------- | :-------------------------------------------- | :------------------------------------------------------------------------------------------------------------ | :---------------- |
| **前端框架**          | React                             | 19.x                                          | Concurrent features、Server Components 就緒                                                                   | —                |
| **前端建置**          | Vite                              | 6.x                                           | 快速 HMR、PWA plugin 生態完整                                                                                 | —                |
| **前端樣式**          | Tailwind CSS                      | v4.x                                          | CSS-first 設計 token 管理                                                                                     | —                |
| **前端 PWA**          | vite-plugin-pwa                   | latest                                        | Service Worker + manifest 自動注入                                                                            | —                |
| **前端 UI token**     | Apple 設計系統                    | `.claude/ui/apple/DESIGN.md`                | 直銷商 80% 用 iPhone；Apple 風格熟悉感                                                                        | —                |
| **前端狀態管理**      | Zustand                           | 5.x                                           | 輕量、React 19 相容                                                                                           | —                |
| **前端 HTTP**         | TanStack Query                    | 5.x                                           | SSE 串流支援、快取與樂觀更新                                                                                  | —                |
| **後端框架**          | FastAPI                           | 0.115.x                                       | async、OpenAPI 自動產生、Python 3.12 最佳化                                                                   | —                |
| **後端套件管理**      | uv                                | latest                                        | 規則強制；快速 venv + lock 管理                                                                               | —                |
| **後端 Python**       | Python                            | 3.12                                          | match statement、typing 改進                                                                                  | —                |
| **資料庫**            | PostgreSQL                        | 16.x（自建 container；prod 待評估 Cloud SQL） | ACID、JSON 支援、pgvector；標準 Postgres dev↔prod 透明切換                                                   | —                |
| **DB 連線**           | asyncpg                           | latest                                        | 原生非同步 PostgreSQL driver；FastAPI 非同步生態最佳搭配                                                      | —                |
| **向量搜尋**          | pgvector                          | 0.7.x                                         | 活檔案語意搜尋、embedding 同庫儲存                                                                            | —                |
| **租戶隔離**          | Postgres 原生 RLS + 三 session 變數 | —                                            | Row Level Security（Postgres 原生）；每交易 SET LOCAL 三個變數：`app.current_tenant_id`、`app.current_distributor`、`app.current_role`；distributor 看自己、leader 看全租戶 | —                |
| **LINE 整合**         | line-bot-sdk（或 httpx 呼叫 Messaging API） | latest                              | 每租戶一個 LINE OA；webhook 收訊→輪派→草稿→教練審核→push 發送                                               | —                |
| **AI 編排**           | LangGraph                         | 0.2.x                                         | **沿用既有框架（PRD 第 5 章），本次不重新設計**                                                         | 沿用既有框架      |
| **AI 模型（速度型）** | Claude Haiku 4.5                  | claude-haiku-4-5                              | 低延遲；情緒感測、異議、草稿首字、樣品草稿、生活事件、LINE 輔助回覆                                           | 沿用既有框架      |
| **AI 模型（品質型）** | Claude Sonnet 4.6                 | claude-sonnet-4-6                             | 品質優先；活檔案 insight、訊息全文 streaming、問卷摘要、招募                                                  | 沿用既有框架      |
| **合規檢查**          | regex sidecar                     | 純 Python re                                  | < 50ms；50 詞庫；v1 純規則                                                                                    | 非 AI，純規則引擎 |
| **太業務員警報**      | 純規則引擎                        | 純 Python                                     | < 50ms；產品關鍵字 + URL pattern；無 AI                                                                       | 非 AI，純規則引擎 |
| **語音合成**          | OpenAI TTS 或 ElevenLabs          | 供應商未定                                    | 介面抽象化（`VoiceProvider`），W4 前選型                                                                    | 沿用既有框架      |
| **語音儲存**          | GCS（google-cloud-storage）       | latest                                        | 語音檔存 GCS；Object Lifecycle 設定 7 天 TTL 自動刪除                                                         | —                |
| **認證**              | FastAPI 自建 JWT                  | HS256 + python-jose + passlib[bcrypt]         | 登入 POST /api/v1/auth/login；密碼存 distributors.password_hash；JWT claims 扁平（角色 distributor / leader） | —                |
| **觀測—追蹤**        | OpenTelemetry                     | 1.x                                           | 標準 OTLP 協定；後端 instrumentation                                                                          | —                |
| **觀測—AI Trace**    | Langfuse                          | 3.x                                           | LLM span、成本計量、採用率追蹤                                                                                | AI trace 必用     |
| **觀測—錯誤**        | Sentry                            | Python SDK + JS SDK                           | 前後端錯誤聚合                                                                                                | —                |
| **排程**              | APScheduler（FastAPI 內）         | 3.x                                           | 樣品 48h/72h/7d 提醒；今日 5 件事每日產生                                                                     | —                |
| **資料庫遷移**        | Alembic                           | 1.x                                           | FastAPI + SQLAlchemy 生態標準                                                                                 | —                |

### 3.1 AI 層整合介面說明

> AI 編排層（LangGraph + Haiku 4.5 + Sonnet 4.6）沿用既有框架，本次不重新設計。

本文件集的職責是定義**其他層與 AI 層的整合介面**：

```
後端服務層（app/services/*.py）
  │
  ├─ 呼叫方式：await agent.run(input_schema)
  │            → LangGraph graph.ainvoke()
  │
  ├─ 輸入契約：每個工具 Service 定義 Pydantic 輸入 schema
  │            （contact_id、distributor_id、context 字串、tone enum）
  │
  ├─ 輸出契約：Service 回傳標準化 Pydantic 回應 schema
  │            （含 model_used、latency_ms、compliance_status）
  │
  ├─ SSE 串流掛載點：message_draft_service.py → POST /api/v1/message-drafts/stream
  │                  Haiku 4.5 first_token → Sonnet 4.6 streaming token
  │
  ├─ 合規掛載點：所有外送草稿 Service 在 return 前呼叫 compliance_sidecar.check()
  │             結果強制寫入 compliance_checks 表
  │
  ├─ 學習紀錄掛載點：所有 AI 操作完成後 fire-and-forget 寫 learning_logs
  │                  （失敗 Sentry 告警但不影響主流程）
  │
  └─ 成本計量點：每次 AI 呼叫完成後同步更新 usage_quotas.ai_cost_usd_today
               Langfuse 追蹤 LLM span cost
```

---

## 4. 範圍：做與不做

### 4.1 做（Phase I MVP）

- 11 個核心工具（T01~T11 + SYS + PLT）
- Mobile PWA（iOS Safari 優先，Android Chrome 次之）
- HTTPS REST API + SSE 串流
- PostgreSQL 16 + pgvector（dev 自建 container；prod 待評估 Cloud SQL）
- FastAPI 自建 JWT（JWT Bearer，distributor / leader 兩角色）
- 合規低語（50 詞 regex，< 50ms）
- 學習紀錄（100% 寫入，Phase II 訓練素材）
- 成本熔斷（每位活躍直銷商每日 ≤ USD 0.30）
- Freemium / Pro / Pro Plus 三種方案配額控管
- 觀測基礎設施（OTel + Langfuse + Sentry）
- 多品牌資料模型（Day 1 抽象，tenants + brands 表已建，無管理 UI）
- 客戶資料請求（export/delete，30/7 天內處理）
- 隱私同意記錄
- **LINE OA 收訊 + 輔助回覆（教練審核後手動發送） + 多教練 round-robin 輪派**
  - 每租戶一個 LINE OA；webhook 收客戶訊息
  - 新客戶輪派下一位 active 教練（round-robin）；既有客戶 sticky；Leader 可看全租戶並改派
  - 自動生輔助回覆草稿（Haiku 4.5，過合規 sidecar）
  - 教練審核通過後按「發送」→ LINE Messaging API push（reply token ~1 分鐘失效故走 push）
  - AI 不自動回；每則訊息發送前皆過合規
  - 非 OA 客戶（尚無 line_user_id）維持手動補資料 + 複製貼上到 LINE

### 4.2 不做（明確排除）

**功能排除：**

| 排除項目                                              | 理由                                                    |
| :---------------------------------------------------- | :------------------------------------------------------ |
| 佣金計算與組織樹管理                                  | Phase II/III                                            |
| 完整電商功能                                          | 超出 prosumer 工具範疇                                  |
| 自動發送訊息                                          | 草稿模式硬限制，AI 永不代送（G.1 不變量）               |
| 品牌後台管理 UI                                       | 多品牌模型 Day 1 已抽象，UI 排 Y4+                      |
| 多語系（繁中以外）                                    | v1 繁中為主，語音支援英語                               |
| LINE 自動回覆 / 主動群發                              | AI 不自動回（G.1）；群發非個人化關懷，排除              |
| WhatsApp / IG 官方 API 對接                           | v1 不在範疇；LINE OA 已納入                             |
| 直銷商自錄語音變體                                    | v1 TTS 單向，不做錄音變體                               |
| 健康問卷即時多版本 A/B 分析                           | Phase II                                                |
| 完整 Leader 下線管理儀表板                            | Phase II，v1 只有招募漏斗統計                           |

**Persona 排除：**

| 排除 Persona                         | 理由                                                           |
| :----------------------------------- | :------------------------------------------------------------- |
| Brand Admin / 品牌總部               | Y1–Y3 不在 scope；18 個月銷售週期；v1 做 prosumer 自費 $39    |
| End Customer（直銷商的客戶本人）     | 不做客戶端 App；健康問卷為唯一客戶接觸面（無需登入一次性連結） |
| 跨產業 SaaS 用戶（房仲、保險、美髮） | v1 鎖定健康類直銷；其他產業排 Phase III                        |

---

## 5. 非功能需求（NFR）

> 依據 PRD 第 6 章，Phase I Pilot 目標。

### 5.1 性能指標

| 類別                            | 指標                            | Phase I Pilot 目標   | 備註                           |
| :------------------------------ | :------------------------------ | :------------------- | :----------------------------- |
| **首頁載入**              | 今日 5 件事 Time-to-Interactive | < 3 秒（4G 網路）    | PWA Service Worker 快取        |
| **草稿生成（首字）**      | Haiku 4.5 first_token           | < 500ms              | SSE event: first_token         |
| **草稿生成（全文）**      | Sonnet 4.6 streaming 完成       | < 5 秒（150 字草稿） | SSE event: done                |
| **情緒感測**              | Haiku 4.5 情緒三檔              | < 2 秒               | 非串流，同步回應               |
| **異議處理**              | Haiku 4.5 三種回應              | < 3 秒               | 速度優先                       |
| **合規掃描**              | regex sidecar                   | < 50ms               | 純規則，不走 AI                |
| **語音生成**              | TTS 60 秒以內語音               | < 10 秒生好          | VoiceProvider 抽象             |
| **API P95**               | 一般 REST 端點                  | < 1 秒               | 不含 AI 端點                   |
| **LINE webhook 反應**     | 收到 webhook 回傳 HTTP 200      | < 3 秒               | LINE 平台要求；超時視為失敗    |
| **LINE push 發送**        | 教練按發送後 push 抵達          | < 5 秒               | 依 LINE Messaging API SLA      |

### 5.2 可用性與復原

| 類別                 | 指標                                                                      | Pilot 目標                                     |
| :------------------- | :------------------------------------------------------------------------ | :--------------------------------------------- |
| **系統可用性** | 核心 API 穩定度                                                           | Pilot 期內不掛掉（11 位使用者，低流量）        |
| **資料復原**   | RPO（資料復原點目標）                                                     | 最壞情況不超過 15 分鐘資料損失（GCP 部署目標） |
| **資料備份**   | dev：自管備份（pg_dump / WAL）；prod：待評估 Cloud SQL（自動備份 / PITR） | Pilot 期 dev 自建 container 需自行安排備份排程 |

### 5.3 安全性

| 類別               | 要求                                                                                                                                                                    |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **認證**     | FastAPI 自建 JWT（HS256）；token 到期後強制重新登入；密碼以 bcrypt 雜湊存 distributors.password_hash                                                                   |
| **租戶隔離** | 所有查詢必含 `tenant_id` 條件；Postgres 原生 RLS 強制執行（三 session 變數：`app.current_tenant_id`、`app.current_distributor`、`app.current_role`）；跨租戶存取回 404（不回 403，見 G.3） |
| **個資加密** | `raw_input`（貼上對話文字）欄位 at-rest 加密；語音 storage_url 存 GCS（at-rest 採 GCS / DB 預設加密）                                                                 |
| **HTTPS**    | 強制；開發環境除外                                                                                                                                                      |
| **合規紀錄** | 每次合規掃描 100% 寫入 `compliance_checks`；不得有漏記                                                                                                                |

### 5.4 成本控管

| 類別                    | 指標                                            | 機制                                                                |
| :---------------------- | :---------------------------------------------- | :------------------------------------------------------------------ |
| **AI 成本上限**   | 每位活躍直銷商每日 AI 成本（含語音）≤ USD 0.30 | `usage_quotas.ai_cost_usd_today` 熔斷；`429 COST_LIMIT_REACHED` |
| **Freemium 配額** | 聯絡人 30 / 草稿 5 篇/日 / 語音 3 段/日         | `usage_quotas` 表每日重置                                         |
| **Pro 配額**      | 聯絡人無限制 / 草稿無限制 / 語音 10 段/日       | `usage_quotas.drafts_limit = 9999`                                |
| **成本監控**      | Langfuse 每日成本 dashboard                     | 超限告警到 Slack                                                    |

### 5.5 可觀測性

| 工具                                | 用途                                                |
| :---------------------------------- | :-------------------------------------------------- |
| **OpenTelemetry 1.x**         | 後端 trace/span；API 延遲、錯誤率、服務依賴圖       |
| **Langfuse 3.x**              | AI LLM span；模型選用、token 計量、成本、採用率追蹤 |
| **Sentry（Python + JS SDK）** | 前後端錯誤聚合；learning_logs 寫入失敗告警          |

---

## 6. 成功標準與 Kill Criteria

> 依據 PRD 第 7 章重點摘要。Pilot 期門檻保留調整空間。

### 6.1 成功標準（依 Persona）

**Amy（主 Persona，5 位 Synergy 教練）**

| 驗證目標                                 | 主要工具                 | 方向                                            |
| :--------------------------------------- | :----------------------- | :---------------------------------------------- |
| 她願意掏 $39/月（PMF 真實證據）          | 整套體驗                 | **5 位裡至少 4 位在 W4 結尾主動說願意付** |
| 每週 Care Action 數 > 推銷數             | 活檔案 + T02 + T05 + T06 | 關懷類動作數明顯多過推銷類                      |
| AI 草稿真的像她會講的話                  | T06 + T03                | 草稿採用率有起色                                |
| 收到太業務員警示後真的會收手             | T04 + T06                | 警示後下一則是純關懷，而非繼續推銷              |
| 客戶丟異議她當下接得住                   | T09                      | 直銷商真的會點開並用其中一個選項                |
| 樣品 48 小時內記得跟進                   | T07 + T05                | 跟進比例顯著高於未使用工具前                    |
| **整段 Pilot 0 次踩 FTC/FDA 紅線** | SYS 合規低語             | **底線，1 次都不能踩**                    |

**Nina（新手直銷商，2-3 人）**

| 驗證目標                     | 方向                          |
| :--------------------------- | :---------------------------- |
| 養成每天打開 App 的習慣      | 7 天裡至少 5 天有打開         |
| 持續做 Care Action 不斷掉    | 每天做幾個 Care Action        |
| 草稿採用率（新手依賴感更強） | 採用率應比 Amy 高             |
| W4 有 15 位以上活檔案        | 從 < 5 位起步到 W4 結構化名單 |

**Linda（Leader，1 人）**

| 驗證目標                               | 方向                       |
| :------------------------------------- | :------------------------- |
| 個人視角她願意付 $39                   | 個人 prosumer 工具要先夠用 |
| 下線 5 人裡至少 3 人每週開 App ≥ 4 天 | 下線真的會用               |
| 每週至少看招募漏斗 2 次以上            | 漏斗數字有意義             |
| 下線整段 Pilot 0 次外送踩線            | 合規底線                   |

**Tina（GTM，Top 100 Influencer）**

| 驗證目標                                | 方向         |
| :-------------------------------------- | :----------- |
| 25 個邀請裡至少 10 個簽 Founders Circle | GTM 啟動     |
| Tina 下線進候補名單至少 50 人           | 病毒擴散起步 |

### 6.2 Kill Criteria（任一觸發即停 Pilot 重評）

| 視角            | Kill 條件                                           |
| :-------------- | :-------------------------------------------------- |
| **系統**  | 重大故障連續 > 24 小時                              |
| **Amy**   | AI 採用率 < 30%；教練流失 ≥ 2/5；自願付 < 3/5      |
| **Nina**  | 4 週後仍 < 1/3 維持每日節奏（新手 onboarding 失敗） |
| **Linda** | 下線 5 人中 < 2 人活躍（Leader 視角無說服力）       |
| **合規**  | 任何 Persona 外送踩線 ≥ 3 次                       |
| **成本**  | AI 成本超預算 50%（含語音超量）                     |

---

## 7. 待答問題（P0）

> 依據 PRD 第 9 章整理，並標注哪些由「客戶需求清單」承接。

| #     | 問題                                                         | Owner             | PRD 狀態              | 工程截止週次 | 客戶需求清單承接       |
| :---- | :----------------------------------------------------------- | :---------------- | :-------------------- | :----------- | :--------------------- |
| P0-01 | AI Employee JD（可做 11 件、不可做 5 件、護欄）              | Irene + Op        | 草擬完成（待 review） | W1           | 是（給客戶版第 1 節）  |
| P0-02 | 知識三分類（Static / Policy / Dynamic）資料模型              | AI Architect      | 待答               | W1           | 否（純工程內部）       |
| P0-03 | 活檔案 7 欄位資料模型設計                                    | AI Architect      | 待答               | W1           | 是（客戶確認欄位需求） |
| P0-04 | 情緒感測器三檔分類訓練/驗證集（人工標註 200 則）             | AI Architect      | W2 前要齊          | W2           | 否（工程 + AI）        |
| P0-05 | 太業務員警報「交易型訊息」判定規則（產品詞庫 + URL pattern） | Op + Synergy 教練 | W3 前要齊          | W3           | 是（客戶訪談收斂）     |
| P0-06 | 語音 TTS 供應商選型（OpenAI TTS vs ElevenLabs 成本＋音色）   | AI Architect      | W4 前要齊          | W4           | 否（工程決策）         |
| P0-07 | 10 種預設異議庫（與 Synergy 5 位教練訪談收斂）               | Op                | 訪談排程中            | W3           | 是（客戶版第 9 節）    |
| P0-08 | 健康問卷 12 題模板 + 法務 review                             | Op + 法務         | 待答               | W4           | 是（客戶確認題目）     |
| P0-09 | 合規低語 50 詞庫 Synergy 法務 review                         | 法務              | 待答               | W1           | 是（法務必過才上線）   |
| P0-10 | 今日 5 件事首頁 wireframe                                    | Op + 設計         | 草擬完成              | W1           | 是（客戶確認 UX）      |
| P0-11 | 資料模型品牌無關（brand-agnostic）抽象                       | AI Architect      | 待答               | W1           | 否（純工程內部）       |
| P0-12 | 定價驗證（$39 prosumer）                                     | GTM Lead          | 結構定（待驗證）      | W4 Pilot     | 是（客戶意願調查）     |

**關鍵卡點：**

1. **AI Architect 缺位** — P0-02、P0-03、P0-04、P0-06、P0-11 都卡這 → 本週鎖定
2. **法務顧問缺位** — P0-09（合規詞庫）、P0-08（問卷模板）、語音隱私都需要 → 本週簽 NDA

---

## 8. 工程預設與架構決策記錄

本文件集在撰寫過程中做出以下工程預設，無法從 PRD 推斷者標「假設：」。

### 8.1 模組落點決策

| 決策                    | 內容                                                                       | 理由                                                                                          |
| :---------------------- | :------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------- |
| **專案路徑**      | repo 根獨立專案；`backend/` 與 `frontend/` 直接放 repo 最上層             | 全新獨立專案，不掛 modules/ 子目錄；modules/ 視為 POC 忽略                                    |
| **後端埠號**      | 8002                                                                       | 與同 host 其他服務區隔（POC modules 如已啟動可自行調整 PORT 環境變數）                        |
| **前端埠號**      | 3002（dev）                                                                | 與同 host 其他服務區隔（可自行調整）                                                          |
| **模組命名前綴**  | `cc_`（care-copilot）                                                    | 識別碼區隔，防止資源命名衝突                                                                  |
| **資料庫 schema** | `care`                                                                   | PostgreSQL 多 schema 隔離                                                                     |
| **API base path** | `/api/v1`                                                                | 符合 REST 版本化慣例                                                                          |

### 8.2 技術選型決策

| 決策                              | 選擇                                                                              | 理由                                                                                               |
| :-------------------------------- | :-------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- |
| **資料庫**                  | 自建 Postgres container（dev）；prod 待評估 Cloud SQL（PostgreSQL 16 + pgvector） | 只用標準 Postgres，dev↔prod 透明切換；pgvector 活檔案語意搜尋同庫；Postgres 原生 RLS 強制租戶隔離 |
| **認證**                    | FastAPI 自建 JWT（HS256 + python-jose + passlib[bcrypt]）                         | 無第三方 Auth 依賴；JWT claims 扁平；可隨業務需求延伸                                              |
| **Package Manager（前端）** | 沿用 monorepo 設定（`.claude/taskmaster-data/package-manager.json`）            | 規則強制；不由 Claude 自選                                                                         |
| **AI 編排**                 | 沿用既有框架（PRD 第 5 章：LangGraph）                                            | 不重新設計；本次只定義整合介面                                                                     |
| **合規 v1**                 | 純 regex sidecar（< 50ms，無 AI）                                                 | 快速啟動；Pilot 後觀察誤判率，必要時升 LLM 二審                                                    |
| **語音供應商**              | VoiceProvider 抽象介面（W4 前選 OpenAI TTS 或 ElevenLabs）                        | 避免 vendor 鎖定；W4 前選型，`provider` 欄位記錄                                                 |
| **embedding**               | text-embedding-3-small（存 pgvector vector(1536)）                                | 活檔案語意搜尋；同庫儲存降低架構複雜度                                                             |

### 8.3 資料模型關鍵決策

| 決策                         | 內容                                                                                                                                                                                                        |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **租戶隔離策略**       | 每張表都有 `tenant_id` 欄位；Postgres 原生 RLS policy 強制；每交易 SET LOCAL 三個 session 變數：`app.current_tenant_id`（隔離邊界）、`app.current_distributor`（distributor 看自己）、`app.current_role`（leader 看全租戶）；跨租戶存取回 404 |
| **LINE 相關新表**      | 新增 `official_accounts`（每租戶 OA 設定）、`inbound_messages`（收到的客戶訊息）；`contacts` 增 `line_user_id`、`source`、`assigned_at`；`message_drafts` 增 `line_oa`、`sent_at`、`delivery_method` 等欄位；`today_tasks.source_type` 增 `inbound_reply` |
| **ID 格式**            | UUID4 帶前綴（如 `ctc_`, `dft_`, `usr_`）；便於除錯與日誌追蹤                                                                                                                                           |
| **時間欄位**           | 一律 `timestamptz`（UTC）；前端顯示轉換由客戶端負責                                                                                                                                                        |
| **多品牌抽象**         | tenants → brands → brand_products 三層；v1 無管理 UI，但資料模型 Day 1 就建完整                                                                                                                            |
| **活檔案 embedding**   | `contacts.contact_embedding vector(1536)`；截圖/語音補資料後重新計算                                                                                                                                       |
| **learning_logs 寫入** | fire-and-forget async；失敗 Sentry 告警但不影響主流程（G.4 不變量）                                                                                                                                         |

### 8.4 跨領域不變量（工程硬約束）

以下 6 條規則優先級最高，任何實作不得違反：

| 編號          | 不變量                 | 說明                                                                                                                                 |
| :------------ | :--------------------- | :----------------------------------------------------------------------------------------------------------------------------------- |
| **G.1** | 草稿模式硬限制         | AI 永不自動送出任何訊息；後端不得實作自動發送或 webhook 代送機制                                                                     |
| **G.2** | 合規 Gate 硬邊界       | 所有外送草稿類型在被採用前必須先通過 `compliance_sidecar`；紅燈強制阻擋；100% 寫入 `compliance_checks`                           |
| **G.3** | 租戶隔離硬邊界         | 所有查詢必含 `tenant_id`；跨租戶存取回 404（不回 403）；JWT `sub` 必須與路徑中 distributor_id 一致                               |
| **G.4** | 學習紀錄強制寫入       | 所有 AI 操作完成後同步（或 async < 1 秒）寫入 `learning_logs`；寫入失敗不影響主流程但需 Sentry 告警                                |
| **G.5** | 成本上限與熔斷         | 每位活躍直銷商每日 AI 成本 ≤ USD 0.30；達限回 `429 COST_LIMIT_REACHED`；每次 AI 呼叫後同步更新 `usage_quotas.ai_cost_usd_today` |
| **G.6** | LINE 發送人工審核硬限制 | LINE 訊息發送仍需教練按「發送」按鈕；AI 不自動回；每則訊息發送前過合規 sidecar；push 不繞過合規 Gate                                 |

### 8.5 未決假設（需後續確認）

| 假設                        | 描述                                                                                                       | 影響                                                                       |
| :-------------------------- | :--------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------- |
| 假設：dev DB 形態           | dev 使用自建 Postgres 16 + pgvector container；prod DB 形態（Cloud SQL vs 自管 container）待成本評估後決定 | 兩者均使用標準 Postgres，切換透明；prod 如選 Cloud SQL 可獲自動備份 / PITR |
| 假設：Langfuse 自架或 Cloud | 假設使用 Langfuse Cloud（省 infra 管理）                                                                   | 若自架，需額外 Docker Compose 設定                                         |
| 假設：語音 storage 上限     | 假設語音檔 7 天後由 GCS Object Lifecycle 自動刪除；APScheduler 清理 job 降為可選補充                       | 若 GCS 費用超預算，可縮短保留期或移除 Lifecycle rule                       |
| 假設：Alembic 遷移策略      | 假設使用 Alembic autogenerate，每次 schema 變更手動 review 遷移腳本                                        | 統一走 Alembic，不依賴任何 GUI 工具管理 schema                             |
| 假設：法務詞庫 50 詞        | 假設 W1 結束前法務提供完整 50 詞（P0-09）；否則 W1 先用 10 詞佔位                                          | 影響合規 Gate 精確度                                                       |
| 假設：LINE OA 免費額度      | 每租戶 LINE OA 免費 push 訊息額度有限（每月 200 則免費，超量計費）；Pilot 期 5 教練低流量預期不超標         | 若超量計費，需在成本控管加入 LINE push 費用計量                            |

---

## 附錄 A：文件版本與維護規範

| 欄位                  | 內容                                                           |
| :-------------------- | :------------------------------------------------------------- |
| **版本**        | v0.3                                                           |
| **日期**        | 2026-06-02                                                     |
| **狀態**        | draft                                                          |
| **對應 PRD**    | v0.3（2026-05-20）                                             |
| **專案**        | synergy（repo 根）                                             |
| **下次 review** | W1 結束前（合規詞庫、活檔案資料模型、AI Architect 缺位確認後） |

**修改規則：**

- 本文件（00_tech-spec.md）如修改任何欄位名、端點路徑、enum 值，必須同步更新跨文件共用契約（本文件 Section 3 參照）並通知所有下游文件擁有者。
- 00_tech-spec.md 是導覽文件；具體 schema/API 細節以各子文件（01~06）為唯一真實來源。
- 每次 PRD 版本升級後，「對應 PRD」欄位和「成功標準」章節須同步 review。
