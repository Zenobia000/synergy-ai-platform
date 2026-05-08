# 架構決策記錄 (ADR) — Synergy AI Closer's Copilot

> **版本:** v3.0 | **更新:** 2026-05-08

本文件彙整 MVP 階段所有重要架構決策。每條 ADR 獨立可讀，可於未來拆分為單獨檔案。

## v3.0 修訂說明

依據客戶 Phase I MVP 規格書（2026-05-06），合規 AI 與 HITL 從 Won't 晉升為 Must，Leader Summary 與新手教練進度納入輕量範圍。本版新增：

- **ADR-010**：Compliance 三層防線（規則庫 → LLM 二次覆核 → HITL）
- **ADR-011**：HITL 人工審核佇列流程與 SLA
- **ADR-012**：M6 輕量 Activity Tracking 採共用 EventLog + 物化視圖
- **ADR-013**：前端棧由 Next.js 改為 React 19 + Vite（簡化無 SSR 需求的 SPA）

ADR-007（M5/M6 完全不做）標註為 **部分推翻**：M6 以「輕量版」復活；M5 仍延後。

## ADR 索引

| # | 標題 | 狀態 | 日期 |
| :---: | :--- | :--- | :--- |
| 001 | 技術棧延用 module2（FastAPI + Next.js + Gemini/LiteLLM） | ⚠️ 部分推翻（前端部分） | 2026-04-24 |
| 002 | 專案結構重構為 apps/ + packages/ 扁平 monorepo | 已接受 | 2026-04-24 |
| 003 | 資料庫選用 Supabase Cloud（PostgreSQL + pgvector） | 已接受 | 2026-04-24 |
| 004 | LLM 預設 Gemini-2.5-flash，LiteLLM 抽象可切換 | 已接受 | 2026-04-24 |
| 005 | Multi-tenant：預留 tenant_id，不實作完整隔離 | 已接受 | 2026-04-24 |
| 006 | M1 獲客模組拆層；MVP 不實作內容生成層 | 已接受 | 2026-04-24 |
| 007 | M5/M6 於 MVP 完全不做；原因與後果 | ⚠️ 部分推翻（見 ADR-012） | 2026-04-24 |
| 008 | 提醒通道：LINE Messaging API 優先，Email 為備援 | 已接受（2026-04-24 修訂） | 2026-04-24 |
| 009 | 商談摘要採「生成時寫入 DB + 快取不重算」策略 | 已接受 | 2026-04-24 |
| **010** | **Compliance 三層防線（規則庫 + LLM 覆核 + HITL）** | **已接受** | **2026-05-08** |
| **011** | **HITL 人工審核佇列：同步阻塞 + 30 min SLA** | **已接受** | **2026-05-08** |
| **012** | **M6 輕量 Activity Tracking：共用 EventLog + 物化視圖** | **已接受** | **2026-05-08** |
| **013** | **前端框架改為 React 19 + Vite（推翻 ADR-001 前端部分）** | **已接受** | **2026-05-08** |

---

## ADR-001: 技術棧延用 module2（FastAPI + Next.js + Gemini/LiteLLM）

> **狀態:** ⚠️ 部分推翻 (前端) | **日期:** 2026-04-24 | **決策者:** kuanwei
> **推翻記錄：** ADR-013（2026-05-08）將前端改為 React 19 + Vite；後端仍為 FastAPI

### 1. 背景與問題

- **上下文**：repo 已有 `modules/module2-questionnaire`（FastAPI + React 19 + Tailwind v4 + Apple tokens）作為問卷 POC，`modules/module1-distributor`（n8n + FastAPI + Vite）作為貼文自動化 POC。
- **問題**：MVP 要在 6-8 週交付 4 功能閉環，要選一個技術基礎。
- **驅動因素/約束**：
  - 時程緊（8 週含 Pilot）
  - 單人開發或最多 2 人，不能有重學習成本
  - 需要 LLM 整合能力與可切換彈性
  - Python 生態內有 `python-docx`、問卷計分邏輯等既有累積

### 2. 考量的選項

#### 選項一：延用 module2 技術棧
- **描述**：FastAPI (uv) + Next.js 15/React + Gemini via LiteLLM + PostgreSQL
- **優點**：
  - 起步最快、PoC 已驗證可跑
  - 既有 Apple 風格 UI 可直接延伸
  - Python + FastAPI 生態健全
- **缺點**：Next.js 不是 SSR-first，但 MVP 簡單夠用
- **成本/複雜度**：低

#### 選項二：麥肯錫推薦 Next.js 15 + Supabase + Claude Opus 4.6
- **描述**：整包重做 SaaS 平台技術棧
- **優點**：一步到位支援多租戶
- **缺點**：多 2-3 週開發成本、Claude 月費高
- **成本/複雜度**：中-高

#### 選項三：Airtable + Tally + Make + Claude（極速版）
- **描述**：低程式碼
- **優點**：3 週跑完、月費 < 5,000 NTD
- **缺點**：未來遷移成本極高、與現有 repo 脫鉤、資料所有權弱
- **成本/複雜度**：短期最低、長期最高

### 3. 決策

**選擇：選項一（延用 module2 技術棧）** — *後端部分保留；前端於 ADR-013 修正*

**理由**：
- 時程壓力下選擇風險最低的路徑
- LiteLLM 抽象層讓 LLM 供應商可未來切換，不鎖死
- 既有 UI 元件與 Python 問卷邏輯可直接複用
- 擴張到 multi-tenant 時不需改語言與框架，只需加抽象層

### 4. 後果

- **正面**：
  - Week 1 即可開始實作 Epic A（問卷）而非基礎建設
  - 與現有 Apple UI tokens 無縫銜接
- **負面**：
  - Next.js 不是當前最熱門選擇，招募新成員時需說明理由
  - Python 後端在 serverless 部署（如 Vercel）較受限，需要自架或 Railway/Fly.io
- **影響範圍**：所有後續 ADR（結構、DB、LLM）都以此為前提
- **重新評估觸發**：
  - ✅ 2026-05-08：Next.js 前端部分改為 React 19 + Vite（見 ADR-013）
  - 若 Pilot 後決定多租戶要實作，需重評資料層（ADR-005）
  - 若擴張到第 2 家客戶且需多語系，需重評前端 SSR 需求

---

## ADR-002: 專案結構重構為 apps/ + packages/ 扁平 monorepo

> **狀態:** 已接受 | **日期:** 2026-04-24 | **決策者:** kuanwei

### 1. 背景與問題

- **上下文**：現有 `modules/module1-distributor/` 與 `modules/module2-questionnaire/` 各自獨立，有自己的 frontend/backend/docs，無共用層。
- **問題**：MVP 要把問卷+商談摘要+CRM+提醒整合成「單一教練版成交副駕駛」。若繼續 `modules/` 切分，共用 TypeScript 型別、Pydantic schema、LLM prompt 會困難。
- **驅動因素/約束**：
  - 使用者允許重構結構
  - module1 與 module2 當參考，不強制延用
  - 未來要加 module3/module4（合規、多語系）需明確擴展路徑

### 2. 考量的選項

#### 選項一：扁平化 apps/ + packages/
```
synergy/
├── apps/
│   ├── web/          # React 19 + Vite 前端（問卷 + 教練後台 + CRM）
│   └── api/          # FastAPI 後端（所有 REST API）
├── packages/
│   ├── domain/       # 共用型別（Pydantic + TS）
│   ├── llm/          # LiteLLM 抽象 + prompt 模板
│   └── ui/           # 共用 React 元件（Apple tokens）
├── modules/          # 舊參考（只讀、不進新開發）
│   ├── module1-distributor/
│   └── module2-questionnaire/
└── docs/
```

- **優點**：單一產品觀點清楚、共用層明確、符合 Turborepo/Nx 慣例
- **缺點**：要搬資料庫 migration 與 env 設定
- **成本/複雜度**：中（遷移 1-2 天）

#### 選項二：繼續 modules/ 結構擴張
- **描述**：新建 `modules/module3-closer-copilot/`
- **優點**：結構不變
- **缺點**：跨模組共用邏輯要不重複寫要不寫成 subtree，很痛
- **成本/複雜度**：短期低、長期高

#### 選項三：整併 module1 + module2 + 新功能進 apps/
- **描述**：把 module1 功能也搬進 apps/api
- **優點**：最乾淨
- **缺點**：module1 是 n8n+FastAPI 混合，搬遷成本過高且 MVP 不需要
- **成本/複雜度**：高

### 3. 決策

**選擇：選項一（扁平 monorepo）**

**理由**：
- MVP 的 4 個功能本質上是**一個產品**，不該切成獨立模組
- `packages/domain`、`packages/llm` 是 multi-tenant 擴張時最先用到的共用層
- 舊 `modules/` 保留為參考，降低決策成本
- 遷移成本僅 1-2 天，遠低於長期開發拖累

### 4. 後果

- **正面**：
  - 共用型別 & prompt 可被前後端 import
  - 未來加 `apps/admin`、`apps/mobile` 有明確位置
  - 符合大部分 monorepo 工具（Turborepo、Nx、pnpm workspaces）慣例
- **負面**：
  - Python 與 TypeScript 混合 monorepo 需處理工具鏈（uv + pnpm）
  - 舊 `modules/` 目錄保留造成 repo 大小增加，但短期接受
- **影響範圍**：
  - `CLAUDE.md`（根層）需更新結構描述
  - 根層新增 `pnpm-workspace.yaml` 與 `uv.lock`（workspace 模式）
- **重新評估觸發**：若 Phase 2 決定把 module1 重啟，重評是否併入 apps/

### 5. 執行計畫

1. 在根層建立 `apps/web`、`apps/api`、`packages/domain`、`packages/llm`、`packages/ui`
2. 複製 `modules/module2-questionnaire/backend` 內容到 `apps/api`（選擇性）或參考實作
3. 把 Apple UI tokens 抽到 `packages/ui`
4. 更新根層 `CLAUDE.md` 並新增各 `apps/*` 與 `packages/*` 的 CLAUDE.md
5. `modules/` 增加 README 註明「舊 POC 參考，請參考 apps/ 新版」

---

## ADR-003: 資料庫選用 Supabase Cloud（PostgreSQL + pgvector）

> **狀態:** 已接受 | **日期:** 2026-04-24 | **決策者:** kuanwei

### 1. 背景與問題

- **上下文**：需要儲存問卷答案、客戶資料、商談摘要、提醒排程等結構化資料，Pilot 期量 < 100 份問卷/月。
- **問題**：選 Supabase Cloud、自架 PostgreSQL、還是 SQLite 快速版？
- **驅動因素/約束**：
  - Pilot 階段量小，但需要穩定
  - 希望未來能加向量搜尋（RAG 異議處理）
  - 要有備份與認證能力
  - 單人維運，不想自己管 DB

### 2. 考量的選項

#### 選項一：Supabase Cloud
- **描述**：託管 PostgreSQL + Auth + Storage + pgvector + Realtime
- **優點**：
  - 免費方案足以 Pilot 用（500MB DB + 1GB storage）
  - Row-Level Security (RLS) 天然支援 multi-tenant
  - pgvector 內建
  - Realtime 可做提醒推播
- **缺點**：
  - 資料主權在第三方
  - 未來大量時成本線性上升
- **成本/複雜度**：低（月費 0-25 USD）

#### 選項二：自架 PostgreSQL（Railway/Fly.io）
- **描述**：自建 Postgres 容器
- **優點**：完全掌控、便宜
- **缺點**：要自己做 migration、備份、監控
- **成本/複雜度**：中

#### 選項三：SQLite + Litestream（單機）
- **描述**：極簡方案
- **優點**：成本最低、單檔案好備份
- **缺點**：未來多租戶、向量搜尋、並發寫入都不適合
- **成本/複雜度**：短期最低

### 3. 決策

**選擇：選項一（Supabase Cloud）**

**理由**：
- RLS 是未來 multi-tenant 的重要基礎，不想後期補
- 免費方案撐得過 Pilot 期
- pgvector 讓未來商談異議 RAG 有擴展空間
- 單人維運省心

### 4. 後果

- **正面**：
  - Auth 可直接用 Supabase 提供（不用自建登入）
  - Storage 可存問卷上傳檔（若未來要）
  - Migration 工具（`supabase db push`）簡單
- **負面**：
  - 鎖定 Supabase 生態，搬到純 Postgres 需要改 Auth 與 Storage 層
  - 免費方案有限制（7 天不活動會 pause），Pilot 前要設定自動 ping
- **影響範圍**：
  - Schema 設計需遵循 RLS 慣例（每表加 `tenant_id` + policy）
  - 後端要用 Supabase Python SDK 或直連 PostgreSQL
- **重新評估觸發**：月用量 > Supabase Pro 方案（25 USD）上限時

---

## ADR-004: LLM 預設 Gemini-2.5-flash，LiteLLM 抽象可切換

> **狀態:** 已接受 | **日期:** 2026-04-24 | **決策者:** kuanwei

### 1. 背景與問題

- **上下文**：MVP 有兩個 LLM 呼叫點：(1) 問卷送出後產生健康摘要（短文本）、(2) 商談前摘要（長文本 + 結構化輸出）。
- **問題**：用 Gemini（便宜）還是 Claude（品質高）？
- **驅動因素/約束**：
  - Pilot 量 < 100 次/月，月成本預算 < 300 NTD
  - 現有 `project.json` 記錄選 Gemini
  - 麥肯錫文件推薦 Claude Opus 4.6

### 2. 考量的選項

#### 選項一：Gemini-2.5-flash 單一模型 + LiteLLM 抽象
- **描述**：預設 Gemini，用 LiteLLM 讓未來可切 Claude/GPT
- **優點**：
  - 月成本 < 200 NTD
  - LiteLLM 是成熟抽象
- **缺點**：結構化輸出穩定度比 Claude 差

#### 選項二：Claude Opus 4.6 全用
- **描述**：直接上最強模型
- **優點**：品質最高
- **缺點**：Pilot 期月成本可能 > 1,000 NTD

#### 選項三：混用（問卷計分 Gemini / 商談摘要 Claude）
- **描述**：LiteLLM 路由
- **優點**：兼顧成本與品質
- **缺點**：兩種 API 風險、提示工程要做兩套

### 3. 決策

**選擇：選項一（Gemini + LiteLLM）**

**理由**：
- 成本考量優先
- LiteLLM 讓未來切換成本接近零（改 config）
- Pilot 第 2 週可評估品質，若不足再切換

### 4. 後果

- **正面**：月成本可控、未來彈性高
- **負面**：
  - 需要在 prompt 層處理 Gemini 結構化輸出穩定性（用 JSON mode + schema 驗證）
  - LiteLLM 多一層抽象，debug 時要多讀一層 log
- **影響範圍**：`packages/llm` 專責封裝
- **重新評估觸發**：
  - Pilot W2 評估：若商談摘要主觀品質 < 7/10（5 位教練評），切到 Claude Haiku 4.5
  - 月成本超過 500 NTD 時評估降級

---

## ADR-005: Multi-tenant：預留 tenant_id，不實作完整隔離

> **狀態:** 已接受 | **日期:** 2026-04-24 | **決策者:** kuanwei

### 1. 背景與問題

- **上下文**：麥肯錫文件建議跨品牌擴張為 Phase 2。MVP 只服務 Synergy 3 位 Pilot 教練。
- **問題**：要不要在 MVP 實作完整 multi-tenant（RLS、tenant 切換、品牌 UI）？
- **驅動因素/約束**：
  - 時程緊（8 週）
  - Phase 2 目標是 6-12 個月後接 USANA
  - 重構成本遠大於一開始多寫 10%

### 2. 考量的選項

#### 選項一：預留不實作
- **描述**：
  - 核心表加 `tenant_id` 欄位（MVP 固定為 'synergy'）
  - RLS policy 寫好但不啟用
  - 前端無品牌切換 UI
- **優點**：Phase 2 啟用時改動最小
- **缺點**：MVP 開發時要記得加欄位

#### 選項二：完全不做
- **描述**：MVP 當單租戶寫
- **優點**：最快
- **缺點**：Phase 2 要改所有表與查詢

#### 選項三：完整實作
- **描述**：MVP 就做好 tenant 切換
- **優點**：Phase 2 即插即用
- **缺點**：MVP 時程拉長 50%+

### 3. 決策

**選擇：選項一（預留不實作）**

**理由**：
- 加 tenant_id 欄位與 RLS policy 是 10 分鐘的事，不做是惰性不是理性
- 完整實作 UI 是 2-3 週的事，Pilot 期不值得
- 折衷方案

### 4. 後果

- **正面**：
  - Phase 2 啟用 multi-tenant 只需「啟用 RLS + 加前端切換器」
  - 資料從一開始就乾淨
- **負面**：
  - MVP 每個表多一個欄位，查詢多 `where tenant_id = ?` 但效能可忽略
  - Pilot 測試時要確保 tenant_id 正確填入
- **影響範圍**：
  - 所有 schema、API、seed data 都要考慮
  - `packages/domain` 的 type 必須包含 tenant_id
- **重新評估觸發**：
  - 簽約第 2 家客戶前 1 個月啟動完整 multi-tenant 實作

---

## ADR-006: M1 獲客模組拆層；MVP 不實作內容生成層

> **狀態:** 已接受 | **日期:** 2026-04-24 | **決策者:** kuanwei

### 1. 背景與問題

- **上下文**：原 PRD 把 M1（獲客行銷）當整塊 P0。客戶模組分層文件指出這是**最大架構錯誤**——M1 應拆兩層：
  - 基礎層：Lead 蒐集、私訊入口整合（全員可用）
  - 進階層：AI 貼文生成、SEO、故事包裝（只有 MEGA 會持續產出）
- **問題**：MVP 要不要做任何 M1 功能？

### 2. 考量的選項

#### 選項一：M1 全延後
- 基礎層也不做，問卷連結由教練手動分享

#### 選項二：只做 M1 基礎層
- Lead 蒐集頁、連結追蹤

#### 選項三：全做（原 PRD 方向）

### 3. 決策

**選擇：選項一（M1 全延後）**

**理由**：
- MVP 問卷連結由教練手動在 LINE/FB 分享即可
- Lead 蒐集頁可 Phase 2 再加，不影響核心漏斗
- 內容生成層（貼文/SEO/故事）需要產出節奏與品牌語料，Pilot 期沒意義

### 4. 後果

- **正面**：MVP 專注力更集中，省 1-2 週開發
- **負面**：
  - 問卷觸及靠教練手動，擴散速度慢
  - Phase 2 補 M1 基礎層時需要設計 Lead attribution
- **重新評估觸發**：Pilot 期教練反映「問卷連結不好分享」時

---

## ADR-007: M5/M6 於 MVP 完全不做

> **狀態:** ⚠️ 部分推翻 | **日期:** 2026-04-24 | **決策者:** kuanwei
> **推翻記錄：** ADR-012（2026-05-08）將 M6 輕量版復活（Leader Summary + Onboarding Tracking）；M5 仍延後

### 1. 背景與問題

- **上下文**：原 PRD 有 M5（成果轉介）與 M6（團隊管理）為 P0/P1。客戶兩份新文件都明確指出 MVP 不做。
- **問題**：完全不做會不會影響 Phase 2？

### 2. 考量的選項

#### 選項一：完全不做
- 資料 schema 不預留

#### 選項二：預留 schema，不做 UI
- DB 層加 `outcomes`、`team_members` 表但不使用

#### 選項三：做最簡陋版本

### 3. 決策

**選擇：選項二（預留 schema，不做 UI/API）** — *後修正：M6 輕量版執行（見 ADR-012）*

**理由**：
- M5/M6 所需資料（成果追蹤、團隊關係）需要 M4 完整執行追蹤先跑半年
- 但預留 schema 讓 Phase 2 啟動時不用改既有表
- UI 與 API 完全延後，因為沒資料先做等於空殼

### 4. 後果

- **正面**：Phase 2 啟動時可立即接資料管線；2026-05-08 更新：M6 輕量版已執行
- **負面**：Schema 設計要多花 30 分鐘想清楚未來欄位；2026-05-08：M6 輕量版包含物化視圖與新手進度表
- **重新評估觸發**：Phase 2 Gate（Pilot 驗收達標後）；M6 輕量版已於 ADR-012 重新評估並執行

---

## ADR-008: 提醒通道 LINE Messaging API 優先，Email 為備援

> **狀態:** 已接受（2026-04-24 修訂，原 Email 優先決策已翻轉）| **日期:** 2026-04-24 | **決策者:** kuanwei

### 1. 背景與問題

- **上下文**：台灣教練日常溝通 95% 使用 LINE，Email 開信率低（< 30%）。LINE Notify 已於 2025-03 停用，只能走 LINE Messaging API（付費）。Pilot 量 < 100 通知/月。
- **問題**：第一期提醒用哪個通道？
- **驅動因素**：
  - KR3「48h 跟進執行率 ≥ 80%」要達標，**通道必須命中教練日常視線**
  - Pilot 只有 3 位教練，通道失效會直接拉爛 KPI
  - 成本不是瓶頸（< 1,000 NTD/月 可接受）

### 2. 考量的選項

#### 選項一：Email（Resend）優先
- **優點**：免費 3,000 封/月、設定簡單、跨平台
- **缺點**：台灣教練開信率低，直接影響 KR3；需要教練主動檢查 inbox
- **成本/複雜度**：低

#### 選項二：LINE Messaging API 優先
- **優點**：
  - 符合教練既有溝通習慣，開信率接近 100%
  - 推播即時、可帶連結回到 Lead 詳情頁
  - KR3 達成機率最大化
- **缺點**：
  - 需申請 LINE Official Account（1-2 週審核）
  - 月費 ~800 NTD（Light plan 15k messages）
  - 需設計 webhook 處理用戶綁定
- **成本/複雜度**：中

#### 選項三：雙通道並行（LINE + Email）
- **優點**：任一通道失效有備援
- **缺點**：兩套通道 = 雙倍開發與測試成本
- **成本/複雜度**：高

### 3. 決策

**選擇：選項二（LINE Messaging API 優先），Email 為備援通道（降級用）**

**理由**：
- **KR3 是 MVP 5 個 KR 中最難達成的**，通道選擇直接決定成敗
- 教練在 LINE 看到提醒 → 點連結回到系統 → 完成跟進，整段摩擦最小
- LINE OA 審核時程必須納入專案關鍵路徑，Week 0 啟動申請
- Email 不砍掉：作為 LINE 失敗時的 fallback 通道（教練未綁定、LINE API 中斷、用量超標）

### 4. 後果

- **正面**：
  - KR3 達成機率顯著提升
  - Pilot 教練採用度更高（他們本來就活在 LINE 上）
  - 直接驗證未來 Phase 2 跨品牌的主力通道
- **負面**：
  - LINE OA 申請排入**專案關鍵路徑**（Week 0 必須送出）
  - 月費 +800 NTD（預算仍控制在 < 2,500 NTD）
  - 需要教練一次性 LINE 綁定流程（可能造成輕微 onboarding 摩擦）
  - 審核未過的風險需有 contingency plan
- **影響範圍**：
  - PRD US-D03 從 Should 升為 Must
  - `apps/api/notifications` 需同時實作 LINE + Email 兩個 adapter
  - 通道抽象層必須從一開始設計好（`NotificationChannel` Protocol）
  - `leads` 或 `coaches` 資料表新增 `line_user_id` 欄位
  - 部署 checklist 加入「LINE OA 審核通過」
- **重新評估觸發**：
  - LINE OA 審核超過 3 週未過 → 降級為 Email 優先 + LINE 作為 Phase 1.5 補齊
  - Pilot W2 若教練 LINE 綁定率 < 100% → 加強 onboarding 引導

### 5. 執行計畫

1. **Week 0 Day 1**：送出 LINE Official Account 申請（Messaging API Channel）
2. **Week 0**：同步申請 Resend API Key（作為 fallback）
3. **Week 2**：實作 `NotificationChannel` Protocol 抽象層
4. **Week 3**：`LineMessagingChannel` 實作 + webhook 綁定流程
5. **Week 4**：`ResendEmailChannel` 實作（fallback）+ 雙通道路由策略
6. **Week 5**：端到端測試：教練綁定 LINE → 觸發提醒 → 驗證 delivery
7. **Week 5（contingency）**：若 LINE 未過審核，Email 改為主通道，LINE 補在 Phase 1.5

---

## ADR-009: 商談摘要採「生成時寫入 DB + 快取不重算」策略

> **狀態:** 已接受 | **日期:** 2026-04-24 | **決策者:** kuanwei

### 1. 背景與問題

- **上下文**：商談摘要由 LLM 生成，成本與延遲較高。教練可能多次查看同一份摘要。
- **問題**：每次查看都重新生成？還是一次生成快取永久？

### 2. 考量的選項

#### 選項一：Lazy 生成（每次打開才呼叫 LLM）
- **缺點**：成本高、延遲明顯、結果不穩定（每次不同）

#### 選項二：問卷送出即生成並寫入 DB，後續查看直接讀
- **優點**：成本可控、延遲低、結果穩定
- **缺點**：問卷答案後續更新時要 invalidate

#### 選項三：Lazy + 7 天 TTL 快取

### 3. 決策

**選擇：選項二（生成時寫入 DB，不重算）**

**理由**：
- LLM 成本與結果穩定性壓倒一切
- 問卷答案 MVP 階段不可改（客戶填完即鎖定）
- 教練若對摘要有疑慮，提供「重新生成」按鈕（用量受限）

### 4. 後果

- **正面**：
  - p95 延遲 < 200ms（純 DB 讀）
  - 月 LLM 成本可預測（= 問卷量 × 2 次）
- **負面**：
  - 若 prompt 升級，需要 batch 重跑舊資料
  - 重新生成按鈕需防濫用（rate limit）
- **影響範圍**：
  - DB 增加 `summaries` 表（1:1 對應問卷）
  - `packages/llm` 需有 `generate_summary(questionnaire_id)` 冪等接口
- **重新評估觸發**：若問卷可編輯功能加入，需重評 invalidation 策略

---

## ADR-010: Compliance 三層防線（規則庫 + LLM 二次覆核 + HITL）

> **狀態:** 已接受 | **日期:** 2026-05-08 | **決策者:** kuanwei | **對應規格**：[12_phase1_mvp.md §合規 AI](./12_phase1_mvp.md)

### 1. 背景與問題

- **上下文**：客戶 Phase I 規格把「合規 AI」從 v2.0 的 Won't 拉回 **Must**。所有 AI 對外訊息（邀約文案、客戶版摘要、跟進草稿、商談話術）必須先通過合規檢查，避免醫療宣稱（C1）、收入宣稱（C2）、誇大效果（C3）、金字塔風險語句（C4）等四大類風險。
- **問題**：合規檢查要兼顧「速度」（不能拖慢 ≤3s 的跟進草稿）、「準確度」（誤判率 < 5%）、「可稽核」（ComplianceLog 一比一保留）。單靠規則或單靠 LLM 都不夠。
- **驅動因素**：
  - 法務風險（誤過會傷品牌）
  - 工程效能（每則訊息都要過，總呼叫量大）
  - 可解釋性（被檢舉時要拿得出理由）

### 2. 考量的選項

#### 選項一：純規則庫（黑名單關鍵詞）
- **優點**：快、便宜、可解釋
- **缺點**：誤判率高（「治療師」也會被擋）、無法處理改寫變體
- **成本**：低

#### 選項二：純 LLM 判斷
- **優點**：理解上下文、可同時改寫
- **缺點**：每則 latency +2~5s、月成本估 1500+ NTD、不可解釋
- **成本**：高

#### 選項三：三層防線（採用）
- **流程**：規則庫初篩 → LLM 二次覆核（僅可疑案件） → 高風險走 HITL
- **優點**：成本可控、稽核可追溯、誤判率可降至 <5%
- **缺點**：實作複雜度高，要維護規則庫詞表
- **成本**：中

### 3. 決策

**採用選項三**。實作要點：

1. **Layer 1 — 規則庫初篩**（純 Python，<10ms）
   - 詞表分四類（C1/C2/C3/C4），每類至少 50 條（首版由客戶提供）
   - 命中 → 標記 `risk_level = candidate` 進入 Layer 2
   - 未命中 → 自動加上免責聲明後通過
2. **Layer 2 — LLM 二次覆核**（高階模型，~2s）
   - 僅 candidate 案件呼叫
   - Prompt 要求輸出 `{risk_level: low/medium/high, rewritten_text, reason}`
   - low → 自動採用 rewritten_text；medium → 採用且記錄；high → 進 Layer 3
3. **Layer 3 — HITL**（見 ADR-011）

**所有經過任一層的訊息**：寫入 `compliance_logs`（原文 / 改寫後 / 風險等級 / 是否人工覆核 / 規則命中 / LLM 模型版本）。

### 4. 後果

- **正向**：合規風險顯著降低；資料累積後可訓練私有分類器（Phase II）
- **負向**：跟進草稿 latency 預算需擴至 5s（規格 ≤3s 仍要努力達成，靠規則庫快路徑）
- **追蹤**：`compliance_check_p95_latency`、`hitl_queue_depth`、`auto_pass_rate`

### 5. 影響

- 影響 [05_api.md](./05_api.md)：所有產生對外文字的 endpoint 需串接 Compliance Service
- 影響 [06_modules.md §ComplianceService](./06_modules.md)：新增模組
- 影響 [10_security.md](./10_security.md)：ComplianceLog 列為稽核必保留資料

---

## ADR-011: HITL 人工審核佇列 — 同步阻塞 + 30 min SLA

> **狀態:** 已接受 | **日期:** 2026-05-08 | **決策者:** kuanwei | **對應規格**：[12_phase1_mvp.md §HITL](./12_phase1_mvp.md)

### 1. 背景與問題

- **上下文**：ADR-010 的 Layer 3（high risk）與 SKU 推薦、健康建議都需人工審核（HITL）。
- **問題**：HITL 是「同步阻塞」（教練要等審核才能發送）還是「非同步通過 + 事後追溯」？前者體驗差但合規嚴；後者體驗好但風險已外洩。
- **驅動因素**：
  - 教練黃金跟進時間（48h）不能等太久
  - Pilot 期審核員可能只有 1-2 人
  - 規格未明指 SLA，需自定

### 2. 考量的選項

| 選項 | 描述 | 優 | 缺 |
| :--- | :--- | :--- | :--- |
| A | 同步阻塞 + 30min SLA | 風險完全攔截 | 體驗差、需審核員待命 |
| B | 非同步預設通過 + 事後審核 | 體驗好 | 高風險可能已送達客戶 |
| C | **同步阻塞但設快速通道** | 取折衷 | 規則最複雜 |

### 3. 決策

**採用選項 C**：

1. **預設同步阻塞**：高風險訊息進佇列，教練 UI 顯示「審核中」狀態
2. **30 min 內 SLA**：審核員需在 30 分鐘內處理（Pilot 期目標）
3. **快速通道**：「商談中即時話術」例外採非同步（先送出 + 標記待覆核），因即時對話不能等
4. **HITL 介面**：`/compliance/queue` 頁，列出待審項，提供 Approve / Reject + Rewrite / Escalate
5. **超時處理**：> 30 min 未審 → 系統發信給審核員主管 + 教練可選擇「降級為純文字 + 免責聲明」
6. **記錄**：每次 HITL 動作寫入 `compliance_logs.reviewed_by`、`reviewed_at`、`hitl_decision`

### 4. 後果

- **正向**：合規責任明確、審核行為可追蹤
- **負向**：需 Pilot 期確認審核員人力（Q-006 待決）；UX 增加「審核中」狀態
- **風險**：若審核員人力不足，48h 跟進可能超時（緩解：規則庫詞表越完整 → Layer 3 比例越低）

### 5. 待決問題（Block W1 啟動）

- Q-006：HITL 審核員是「客戶內部合規人員」還是「我方代審」？
- Q-007：規則庫詞表初版（C1-C4 共 200 條）由誰提供？最遲 W1 D1

---

## ADR-012: M6 輕量 Activity Tracking — 共用 EventLog + 物化視圖

> **狀態:** 已接受 | **日期:** 2026-05-08 | **決策者:** kuanwei | **推翻**：ADR-007（M6 完全不做）

### 1. 背景與問題

- **上下文**：客戶 Phase I 把「Leader Summary + 新手教練進度」納入 Must。但完整 M6（團隊管理、組織樹、業績串接）仍延後。
- **問題**：要為 M6 輕量版獨立建表（teams, kpi_snapshots, onboarding_tasks…）還是複用既有 EventLog？
- **驅動因素**：
  - 4 週時程，不能花太多時間做複雜資料表
  - F6.1~F6.4 指標（問卷數、商談數、成交數、跟進執行率、AI 摘要使用、高風險觸發）都已有來源（leads, conversation_plans, follow_up_tasks, event_logs, compliance_logs）
  - 新手進度（F6.6）是少量靜態 checklist，不需複雜表

### 2. 決策

**採用「共用 + 物化視圖」**：

1. **F6.1~F6.5（聚合指標）**：不建新表，採 PostgreSQL 物化視圖
   - `mv_coach_weekly_stats`（每位教練週統計）
   - `mv_leader_summary`（Leader 視角彙總）
   - 每 30 min 用 `pg_cron` refresh（Pilot 期足夠即時）
2. **F6.6 新手教練進度**：建一張小表 `onboarding_tasks`
   - 欄位：`coach_id, task_key, completed_at, evidence_url`
   - Task 清單寫死於 YAML（Pilot 期 ~10 項，例：「綁定 LINE OA」「第一次成交」「完成 5 次商談」）
3. **不做**：teams 組織樹、業績串接、獎金計算（仍 Won't）

### 3. 後果

- **正向**：4 週可達；Phase II 升級為完整 M6 時，資料已累積
- **負向**：物化視圖 30min 延遲（Leader 看不到實時資料 — 可接受）
- **追蹤**：物化視圖 refresh 失敗監控；onboarding 完成率

### 4. 影響

- 影響 [04_architecture.md](./04_architecture.md)：資料層新增物化視圖
- 影響 [06_modules.md §ActivityTrackingService, LeaderSummaryService, OnboardingProgressService](./06_modules.md)：新增三個 Application 模組
- 影響 [09_frontend_ia.md](./09_frontend_ia.md)：新增 `/leader/*` 頁面群

---

## ADR-013: 前端框架改為 React 19 + Vite（推翻 ADR-001 前端部分）

> **狀態:** 已接受 | **日期:** 2026-05-08 | **決策者:** kuanwei | **推翻**：ADR-001 前端決策

### 1. 背景與問題

- **上下文**：ADR-001 原定前端用 Next.js 15，主因是 module2 既有 React 19 + Tailwind v4 + Apple tokens 可複用。但實務評估發現：
  - MVP 前端純 SPA（無 SSR 需求）：問卷是公開頁但無 SEO；教練後台是受認證頁；Leader Summary 同樣無 SEO 需求
  - Next.js 15 AppRouter 在 SPA 模式下添加複雜性（middleware、dynamic import、metadata） — 反而拖累啟動速度與維運
  - Vite 啟動快（< 1s dev）、依賴少、無 Node.js runtime 綁定 — 適合 Pilot 期快速迭代
  - Module1 已驗證 Vite + React + Tailwind 可行，可借鏡
- **問題**：改用 React + Vite 會不會拖延進度、或造成與後端集成困難？

### 2. 考量的選項

#### 選項一：保留 Next.js 15（ADR-001 決策）
- **優點**：已有 module2 經驗、集成 API BFF 簡單、內置 Auth middleware
- **缺點**：無 SSR 需求反而造成過度工程、dev 啟動較慢、不適合 SPA、部署平台受限（Vercel 優先，但本案用 Cloudflare Pages 時有限制）
- **成本**：無新學習、但 SPA 架構需 workaround

#### 選項二：React 19 + Vite（採用）
- **優點**：
  - 純 SPA，架構簡單清爽
  - Vite 啟動快、dev 體驗好、build 產出 static HTML — 對 Cloudflare Pages 最友好
  - 依賴少，適合 Pilot 期輕量維運
  - 與 module1-distributor 既有經驗一致（降低新成員上手成本）
  - 可沿用 module2 既有元件與 Apple tokens
- **缺點**：路由自己實作（建議用 react-router-dom v7 或 TanStack Router）、no built-in SSR（但 MVP 不需要）、SEO meta 要手寫（react-helmet-async）
- **成本**：低（routing + helmet 各 < 2h 集成）

#### 選項三：Remix（全棧框架）
- **優點**：兼具 SPA 靈活與後端友好
- **缺點**：學習曲線陡、Pilot 期不必要
- **成本**：高

### 3. 決策

**選擇：選項二（React 19 + Vite）**

**理由**：
- **MVP 本質是 SPA**（無 SSR、無 ISR、無 middleware 複雜邏輯），Next.js AppRouter 過度設計
- **Vite 啟動速度**對日常 Pilot 開發體驗影響大（dev < 1s vs Next.js ~3-5s），每天減少 30+ 分鐘累積時間
- **部署平台最優化**：Vite 產出純靜態文件 → Cloudflare Pages 秒級部署、edge cache 最高效、成本最低
- **既有驗證**：module1 已用 Vite，團隊零陌生感；module2 React 元件與 tokens 照用無改動
- **Phase 2 平滑過渡**：若未來需 SSR（跨品牌版），改用 Remix 或 Next.js 時，React 元件無損搬遷（僅路由 refactor）

### 4. 後果

- **正面**：
  - 開發迴圈快（Vite dev mode < 1s）
  - build 產出極小（tree-shake + minify 效率高）
  - 部署簡單（pure static → Cloudflare Pages 無 build step）
  - 與 module1 技術一致，未來整合無縫
  - 維運成本低（無 Node.js 後端依賴）
- **負面**：
  - 路由自己實作（工作量 ~2-3h 用 react-router-dom v7）
  - 無內置 Auth middleware，需在 React 層實作 protected routes
  - SEO meta 要用 react-helmet-async（~30 min 集成）
  - 若 Pilot 期突然要 SSR（極罕見），需 refactor — 但風險低（元件無損）
  - 環境變數命名變更：Next.js 的 `NEXT_PUBLIC_*` → Vite 的 `VITE_*`
- **影響範圍**：
  - 影響 [07_structure.md](./07_structure.md)：`apps/web` 結構改為 Vite；`src/routes/` 替代 `app/`
  - 影響 [08_design_dependencies.md](./08_design_dependencies.md)：移除 `next`、`next-auth`；新增 `vite`、`react-router-dom`、`react-helmet-async`
  - 影響 [11_deployment.md](./11_deployment.md)：部署改 Cloudflare Pages（或 Netlify）；不用 Vercel
  - 影響 [04_architecture.md](./04_architecture.md)：L2 Container 圖改 Vite；技術選型表改 React + Vite
  - 前端套件管理器與 build 指令變更（PM 由用戶決定 — npm/pnpm/bun）
- **重新評估觸發**：
  - Pilot W2 若教練需要 PWA offline 支持 → 加 workbox plugin
  - Phase 2 若需 multi-brand SSR → 評估遷移到 Remix（成本估 3-5 day）

### 5. 執行計畫

1. **W0 D1**：建立 `apps/web` 基礎結構（Vite + React 19 + Tailwind v4 + Apple tokens）
2. **W0 D2-D3**：集成 react-router-dom v7（路由、nested routes、protected routes）
3. **W0 D4**：集成 react-helmet-async（head meta 管理）
4. **W0 D5**：集成 @supabase/supabase-js + Auth flow（Magic Link）
5. **W1 D1-D2**：複製 module2 既有元件、業務邏輯到 `apps/web/components`
6. **W1 D3-W2**：實作問卷頁、Lead 列表、Briefing 詳情、Reminder 列表（5 個頁面）
7. **W2 D4-W3**：合規審核隊列頁 + Leader Summary 新增（2 個新頁面）

---

## 附錄：決策相依圖

```
ADR-001 (技術棧) ⚠️ 部分推翻
   ├─→ ADR-002 (結構)
   ├─→ ADR-003 (DB: Supabase)
   │      ├─→ ADR-005 (tenant_id 靠 Supabase RLS)
   │      └─→ ADR-012 (M6 物化視圖)
   ├─→ ADR-004 (LLM: Gemini + LiteLLM)
   │      ├─→ ADR-009 (摘要快取策略)
   │      └─→ ADR-010 (Compliance Layer 2 LLM 覆核)
   │             └─→ ADR-011 (HITL 流程)
   └─→ ADR-013 (🆕 前端改 React + Vite，推翻 ADR-001 前端決策)

ADR-006 (M1 延後)  ── 影響 PRD Epic 範圍
ADR-007 (M5/M6 延後) ── ⚠️ 部分推翻：ADR-012 將 M6 輕量版復活
ADR-008 (LINE 提醒) ── 影響 Epic D US-D03
ADR-010 (Compliance) ── 影響所有產生對外文字的 endpoint
ADR-011 (HITL) ── 影響 Epic E + UX 增加「審核中」狀態
ADR-012 (M6 輕量) ── 影響 Epic F + 新增 Leader 視角頁面群
ADR-013 (React+Vite) ── 影響部署平台、環境變數、dev 工作流
```
