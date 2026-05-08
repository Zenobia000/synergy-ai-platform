# Synergy AI 文件索引

> **產品：** Synergy AI — Closer's Copilot（教練成交副駕駛）
> **版本：** Phase I MVP **v3.1** | **更新：** 2026-05-08 | **⚠️ v3.1 五項重大翻轉**（DB、認證、通知、規則庫、部署） | **模式：** VibeCoding full + 客戶 Phase I 規格

---

## 文件清單（v3.1 完整）

| # | 檔案 | 用途 | 對應 VibeCoding | 版本 | 狀態 |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 01 | [01_prd.md](./01_prd.md) | 產品需求文件（Personas、OKRs、6 Epic、風險） | 02 | v3.0 | ✅ 維持 |
| 02 | [02_bdd.md](./02_bdd.md) | BDD 情境（9 個 feature + 44 scenario） | 03 | v3.0 | ✅ 維持 |
| 03 | [03_adr.md](./03_adr.md) | 架構決策記錄（18 條 ADR，新增 ADR-015~018） | 04 | **⚠️ v3.1** | ✅ 完成 |
| 04 | [04_architecture.md](./04_architecture.md) | 系統架構（C4 更新、DB 改 PostgreSQL、新增 Admin 模組、pgvector）| 05 | **⚠️ v3.1** | ✅ 完成 |
| 05 | [05_api.md](./05_api.md) | API 規範（~65 端點，帳密登入、Admin CRUD、WhatsApp webhook） | 06 | **⚠️ v3.1** | ✅ 完成 |
| 06 | [06_modules.md](./06_modules.md) | 模組規格（21 個模組，新增 UserMgmt/PassAuth/ComplianceRule，改名 DraftReview） | 07 | **⚠️ v3.1** | ⏳ 待完成 |
| 07 | [07_structure.md](./07_structure.md) | 專案結構（apps/ + packages/ + 新增 docker-compose） | 08 | **⚠️ v3.1** | ⏳ 待完成 |
| 08 | [08_design_dependencies.md](./08_design_dependencies.md) | 設計與依賴（改 PostgreSQL/asyncpg，移除 Supabase，新增 pgvector） | 09 | **⚠️ v3.1** | ⏳ 待完成 |
| 09 | [09_frontend_ia.md](./09_frontend_ia.md) | 前端資訊架構（25+ 頁，新增 /admin/*、改 /login 帳密） | 17 | **⚠️ v3.1** | ⏳ 待完成 |
| 10 | [10_security.md](./10_security.md) | 安全與合規（新增帳密政策、bcrypt、PostgreSQL 安全、WhatsApp 驗證） | 13 | **⚠️ v3.1** | ⏳ 待完成 |
| 11 | [11_deployment.md](./11_deployment.md) | 部署維運（GCP Cloud Run + Cloud SQL，CI/CD 改 gcloud deploy） | 14 | **⚠️ v3.1** | ⏳ 待完成 |
| **12** | **[12_phase1_mvp.md](./12_phase1_mvp.md)** | **Phase I MVP 規格精煉版（7 大模組含 M0 Auth、完整驗收、里程碑）** | — | **⚠️ v3.1** | ⏳ 待完成 |
| **13** | **[13_client_deliverables.md](./13_client_deliverables.md)** | **客戶交付清單（新增 WhatsApp/GCP/帳密培訓、移除 Magic Link）** | — | **⚠️ v3.1** | ⏳ 待完成 |
| **14** | **[14_team_workplan.md](./14_team_workplan.md)** | **三人團隊分工計畫（D2 新增帳密認證、ComplianceRule；D3 新增 Admin UI）** | — | **⚠️ v3.1** | ⏳ 待完成 |

---

## v3.1 重大修訂摘要（2026-05-08）

### 五項架構翻轉（客戶決定）

| # | 改動 | 舊方案 | 新方案 | 文件影響 | 新增 ADR |
|---|---|---|---|---|---|
| **1** | **資料庫** | ❌ Supabase Cloud | ✅ PostgreSQL 17 + pgvector（本地 docker；部署 GCP Cloud SQL） | 04, 07, 08, 10, 11 | ADR-003 翻轉 |
| **2** | **認證** | ❌ Magic Link (Supabase Auth) | ✅ bcrypt 帳密 + JWT（admin 後台建用戶） | 05, 06, 09, 10, 12, 13, 14 | ❌ ADR-014 廢棄；✨ ADR-015 新增 |
| **3** | **通知** | LINE 優先 + Email 備援 | ✅ LINE/WhatsApp/Email 三層 Fallback | 04, 05, 06, 12, 13 | ✨ ADR-016 新增 |
| **4** | **規則庫** | YAML 固定 | ✅ 資料庫儲存 + pgvector 語意向量比對 | 04, 05, 06, 07, 08, 10, 12 | ✨ ADR-017 新增 |
| **5** | **部署** | Cloudflare Pages + Railway | ✅ GCP（Cloud Run + Cloud SQL + Cloud CDN） | 07, 08, 10, 11 | ✨ ADR-018 新增 |

### 模組數增加（18 → 21）

**新增模組**：
- `UserManagementService`（admin 建用戶、CRUD）
- `PasswordAuthService`（帳密驗證、改密碼）
- `ComplianceRuleService`（規則庫 CRUD + embedding）
- `SemanticMatcher`（Domain 純函式，pgvector 相似度）
- `WhatsAppChannel`（WhatsApp 推播）

**改名模組**：
- `HITLService` → `DraftReviewService`（教練自主決策，無外部審核）

### API 端點增加（48 → 65+）

**新增 17+ 端點**：
- Auth 4 個（login、change-password、refresh、logout）—— **廢棄 magic-link、callback（2 個）**
- Admin users CRUD 5 個（list、create、update、delete、reset-password）
- Admin rules CRUD 5 個（list、create、update、delete、import、regenerate-embeddings）
- WhatsApp webhook 1 個
- Draft endpoints 2 個（list、update）

**淨增**：17 - 2（廢棄） = **~15 新端點**

### 成本變化

| 項目 | v3.0 | v3.1 | 差異 |
|---|---|---|---|
| Supabase | 1,000 | 0 | ❌ 移除 |
| PostgreSQL/GCP | 0 | 250-350 | ✨ 新增 |
| Railway API | 150-500 | 0 | ❌ 改 Cloud Run |
| Cloud Run | 0 | 200-500 | ✨ 新增 |
| Cloudflare Pages | 0 | 0 | （改 Cloud CDN） |
| Cloud CDN + Storage | 0 | 100-200 | ✨ 新增 |
| WhatsApp API | 0 | 200-500 | ✨ 新增 |
| Gemini Embedding | 0 | 100-150 | ✨ 新增 |
| **月費合計** | **~1,110-2,660** | **~2,170-3,350** | **+1,000~1,500** |

> **註**：若客戶自行承擔 GCP 費用，我方可零成本交付（僅需 Gemini API ~100-150/月）。

---

## 快速導覽（v3.1 焦點）

### 🚀 工程師快速上手

**必讀順序**：
1. **[03_adr.md](./03_adr.md)** — ADR-015/016/017/018 了解五項翻轉的架構決策
2. **[04_architecture.md](./04_architecture.md)** — L2 容器圖了解 PostgreSQL + GCP 拓撲
3. **[05_api.md](./05_api.md)** § 5.1~5.2 — 帳密登入 + Admin endpoints
4. **[06_modules.md](./06_modules.md)** — UserManagementService、PasswordAuthService、ComplianceRuleService 詳規
5. **[07_structure.md](./07_structure.md)** — `docker-compose.yml` + PostgreSQL schema
6. **[10_security.md](./10_security.md)** — 帳密政策、bcrypt、PostgreSQL 安全設置

### 🎨 PM / 設計師焦點

**必讀順序**：
1. **[03_adr.md](./03_adr.md)** § ADR-015 — admin 後台建用戶流程
2. **[09_frontend_ia.md](./09_frontend_ia.md)** — 新增 `/admin/users`、`/admin/compliance-rules` 頁面
3. **[12_phase1_mvp.md](./12_phase1_mvp.md)** — Admin UI 規格

### 👔 Tech Lead / 決策者

**必讀順序**：
1. **[03_adr.md](./03_adr.md)** — 所有 ADR，重點 ADR-003/015/016/017/018
2. **[04_architecture.md](./04_architecture.md)** — 整體架構改動
3. **[10_security.md](./10_security.md)** — 安全評估（帳密政策、PostgreSQL、WhatsApp）
4. **[11_deployment.md](./11_deployment.md)** — GCP 部署流程與成本

### 🛡️ 客戶交付視角

**必讀順序**：
1. **[12_phase1_mvp.md](./12_phase1_mvp.md)** — Phase I 功能與驗收
2. **[13_client_deliverables.md](./13_client_deliverables.md)** — 交付物清單（WhatsApp 申請、GCP 設置、帳密培訓）
3. **[14_team_workplan.md](./14_team_workplan.md)** — 工作分解與時程

---

## 統計數字（v3.1）

| 分類 | 數字 | 備註 |
|---|---|---|
| **ADR** | 18 | 新增 4 條（015/016/017/018） |
| **模組** | 21 | 新增 5 個（UserMgmt/PassAuth/ComplianceRule/SemanticMatcher/WhatsAppChannel） |
| **API 端點** | ~65+ | 新增 17+，移除 2（Magic Link） |
| **資料表** | 13+ | 新增 users、compliance_rules、message_drafts（改名自 compliance_queue） |
| **頁面** | 25+ | 新增 /admin/users、/admin/compliance-rules、改 /login（帳密） |
| **環境變數** | 25+ | 新增 WhatsApp、Embedding、PostgreSQL、GCP Secret Manager 相關 |
| **Docker 檔案** | 1 | 新增 docker-compose.yml（本地開發） |

---

## 鑰匙術語（v3.1 擴充）

| 術語 | 定義 | 文件位置 |
|---|---|---|
| **PostgreSQL 17** | 關聯式資料庫（含 pgvector 向量存儲擴展） | [04_architecture.md § 4.1](./04_architecture.md#41-資料庫遷移supabase--postgresql--pgvector) |
| **pgvector** | PostgreSQL 向量相似度擴展（cosine distance） | [03_adr.md § ADR-017](./03_adr.md#adr-017--規則庫-db-化--pgvector-語意比對) |
| **Cloud SQL** | GCP 託管 PostgreSQL（自動備份、SSL、自動擴展） | [03_adr.md § ADR-018](./03_adr.md#adr-018--部署平台-gcpcloud-run--cloud-sql--cloud-cdn) |
| **Cloud Run** | GCP 無伺服器容器（自動擴展、按執行計費） | [04_architecture.md § 5.2](./04_architecture.md#52-部署拓撲gcp) |
| **bcrypt** | 密碼雜湊演算法（cost=12，驗證 ~0.3s） | [03_adr.md § ADR-015](./03_adr.md#adr-015--系統管理員後台建用戶--帳密登入) |
| **UserManagementService** | 新增應用層服務，admin 後台 CRUD 教練帳號 | [06_modules.md](./06_modules.md)（待完成） |
| **ComplianceRuleService** | 新增應用層服務，管理 compliance_rules 表 + embedding | [03_adr.md § ADR-017](./03_adr.md#adr-017--規則庫-db-化--pgvector-語意比對) |
| **SemanticMatcher** | 新增 Domain 純函式，計算 cosine similarity + 規則比對 | [03_adr.md § ADR-017](./03_adr.md#adr-017--規則庫-db-化--pgvector-語意比對) |
| **WhatsAppChannel** | 新增 Infrastructure，WhatsApp Business Cloud API 推播 | [03_adr.md § ADR-016](./03_adr.md#adr-016--通知通道擴充至-linewhatsappemail) |
| **Cloud Scheduler** | GCP 排程服務（取代 APScheduler） | [03_adr.md § ADR-018](./03_adr.md#adr-018--部署平台-gcpcloud-run--cloud-sql--cloud-cdn) |
| **Message Drafts** | 新增表，取代舊 compliance_queue，教練審核訊息 | [04_architecture.md § 4.3](./04_architecture.md#43-新增表詳規) |

---

## 檔案更新時間表（v3.1 排程）

| 文件 | 預計完成 | 狀態 | 負責人 |
|---|---|---|---|
| 03_adr.md | 2026-05-08 | ✅ 完成 | Claude |
| 04_architecture.md | 2026-05-08 | ✅ 完成 | Claude |
| 05_api.md | 2026-05-08 | ✅ 完成 | Claude |
| 06_modules.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 07_structure.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 08_design_dependencies.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 09_frontend_ia.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 10_security.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 11_deployment.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 12_phase1_mvp.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 13_client_deliverables.md | 2026-05-08 | ⏳ 進行中 | Claude |
| 14_team_workplan.md | 2026-05-08 | ⏳ 進行中 | Claude |

---

## 版本履歷

| 版本 | 日期 | 變更重點 | 文件數 |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-04-24 | 初版（14 份文件，PRD + BDD + ADR 01-13 + 架構） | 14 |
| v3.0 | 2026-05-08 | Phase I MVP 擴充（新增 Compliance/HITL/Coaching/Activity 層，ADR 14 → 14） | 14 |
| v3.0.1 | 2026-05-08 | Auth 新增 + HITL 簡化（教練即審核者，ADR 14 → 14） | 14 |
| **v3.1** | **2026-05-08** | **五項重大翻轉：DB/認證/通知/規則庫/部署（ADR 14 → 18，新增 4 ADR，模組 18 → 21，端點 48 → 65+）** | **14** |

---

## 參考與原始文件

| 檔案 | 性質 | 版本 |
| :--- | :--- | :--- |
| `docs/_phase1_spec_extract.md` | 客戶 Phase I MVP 規格書（2026-05-06）純文本摘錄 | v3.0.1 基準 |
| `docs/02_AI直銷Agent_PhaseI_單一MVP規格書_v2.docx` | 客戶原始 docx 規格（v3.1 更新基準） | v3.1 |
| `system_design_docs/01_synergy_ai_prd.md` | 原 PRD v1.0（已被 01_prd.md v3.0 超越） | v1.0 |

---

## 貢獻指南

本索引由 VibeCoding 與客戶 Phase I 規格協同更新。文件版本遵循 **語意版本**：

- **v3.x**：Phase I MVP 周期（2026-04-24 ~ 2026-07-31）
- **v4.x**（計畫）：Phase II 擴張（2026-08-01 後）

任何文件更新，請同步更新本索引的版本欄與 v3.1 統計。
