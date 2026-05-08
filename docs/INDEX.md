# Synergy AI 文件索引

> **產品：** Synergy AI — Closer's Copilot（教練成交副駕駛）
> **版本：** Phase I MVP v3.0 | **更新：** 2026-05-08 | **模式：** VibeCoding full + 客戶 Phase I 規格

---

## 文件清單

| # | 檔案 | 用途 | 對應 VibeCoding 範本 | 版本 |
| :---: | :--- | :--- | :--- | :--- |
| 01 | [01_prd.md](./01_prd.md) | 產品需求文件（Personas、OKRs、6 Epic、風險） | 02 | **v3.0** ✅ |
| 02 | [02_bdd.md](./02_bdd.md) | BDD 情境（9 個 feature + 44 scenario） | 03 | **v3.0** ✅ |
| 03 | [03_adr.md](./03_adr.md) | 架構決策記錄（12 條 ADR） | 04 | **v3.0** ✅ |
| 04 | [04_architecture.md](./04_architecture.md) | 系統架構（C4、DDD、4 個新 Context、物化視圖） | 05 | **v3.0** ✅ |
| 05 | [05_api.md](./05_api.md) | API 規範（~45 端點 + 新增 Compliance/Leader/Conversation） | 06 | **v3.0** ✅ |
| 06 | [06_modules.md](./06_modules.md) | 模組規格與測試（17 個模組 + 7 新） | 07 | **v3.0** ✅ |
| 07 | [07_structure.md](./07_structure.md) | 專案結構（含 v3.0 補丁：compliance/hitl/conversation_coach/leader/onboarding 子套件）| 08 | **v3.0** ✅ |
| 08 | [08_design_dependencies.md](./08_design_dependencies.md) | 設計與依賴（含 v3.0 補丁：Google Calendar、reviewer 角色、Compliance flag）| 09 | **v3.0** ✅ |
| 09 | [09_frontend_ia.md](./09_frontend_ia.md) | 前端資訊架構（22 頁 + 3 旅程 + 權限矩陣） | 17 | **v3.0** ✅ |
| 10 | [10_security.md](./10_security.md) | 安全與合規（含 v3.0 補丁：內容合規 C1-C4、HITL 稽核、Compliance RLS、Prompt injection 防禦）| 13 | **v3.0** ✅ |
| 11 | [11_deployment.md](./11_deployment.md) | 部署維運（含 v3.0 補丁：HITL worker、物化視圖 cron、成本 +33%、Migration 8 步）| 14 | **v3.0** ✅ |
| **12** | **[12_phase1_mvp.md](./12_phase1_mvp.md)** | **Phase I MVP 規格精煉版（6 大模組、完整驗收、里程碑）** | — | **✨ v3.0 新增** ✅ |
| **13** | **[13_client_deliverables.md](./13_client_deliverables.md)** | **客戶交付清單（產品庫、話術庫、合規詞庫、人員、法務、里程碑簽核）** | — | **✨ v3.0 新增** ✅ |
| **14** | **[14_team_workplan.md](./14_team_workplan.md)** | **三人團隊分工計畫（50/30/20 比重、模組獨立性、事件 Bus、時程 Gantt）** | — | **✨ v3.0 新增** ✅ |

---

## v3.0 升級狀態

### ✅ 已完全升級到 v3.0 的文件

| # | 檔案 | 更新內容 |
| :---: | :--- | :--- |
| 01 | `01_prd.md` | 6 個 Epic（新增 Epic E: Compliance、Epic F: Leader Summary）、28 個 User Story、6 個新 ADR 連結 |
| 02 | `02_bdd.md` | 9 個 feature（既有 4 + 新增 5）、**44 個 scenario**（完整 Gherkin 語法） |
| 03 | `03_adr.md` | 12 條 ADR（既有 9 + 新增 ADR-010/011/012 for Compliance/HITL/M6） |
| 04 | `04_architecture.md` | C4 模型含新容器、4 個新 DDD Context、新增 6 個 Application Service、**2 個物化視圖**、新增表欄位補丁 |
| 05 | `05_api.md` | ~45 個 endpoint（既有 ~25 + 新增 ~20）：ComplianceService、HITLService、ConversationCoachService、LeaderSummaryService、ActivityTrackingService、GoogleCalendarAdapter |
| 06 | `06_modules.md` | 17 個模組（既有 10 + 新增 7）：ComplianceService、HITLService、ConversationCoachService、ActivityTrackingService、LeaderSummaryService、OnboardingProgressService、EventLog Service |
| 09 | `09_frontend_ia.md` | 22 頁（既有 12 + 新增 5 教練頁面 + 新增 4 Leader 頁面 + 1 HITL 隊列頁）、3 使用者旅程、權限矩陣擴充 |
| 12 | `12_phase1_mvp.md` | ✨ **新檔案**：Phase I MVP 核心規格、6 大模組、里程碑、開發策略、驗收標準、風險管理 |

### 🔄 維持既有版本的文件

| # | 檔案 | 原因 |
| :---: | :--- | :--- |
| 07 | `07_structure.md` | 專案結構不變（apps/ + packages/ 已在 ADR-002 決定） |
| 08 | `08_design_dependencies.md` | SOLID 與設計模式仍適用，無新增模組衝突 |
| 10 | `10_security.md` | 新增 ComplianceLog 稽核（待下一版補充） |
| 11 | `11_deployment.md` | 部署策略、CI/CD 流程無重大變動 |

---

## 閱讀順序建議（v3.0）

### 🚀 新加入的工程師（Phase I MVP 快速上手）

1. `01_prd.md` — 為什麼做（Phase I 範圍擴充至 6 大模組）
2. `12_phase1_mvp.md` — **Phase I 執行摘要**（強烈推薦先讀）
3. `04_architecture.md` — 整體系統設計 + 新增 Context
4. `06_modules.md` — 詳細模組規格（自己領域聚焦）
5. `05_api.md` — REST 端點規範

### 🎨 新加入的 PM / 設計師

1. `01_prd.md` — 產品定位 & 6 個 Epic 與故事
2. `12_phase1_mvp.md` — Phase I 核心功能
3. `09_frontend_ia.md` — 前端頁面（22 頁） + 3 使用者旅程
4. `02_bdd.md` — 行為定義（44 個 scenario）

### 👔 Tech Lead 決策與安全

1. `01_prd.md` — 商業目標 & 9 個風險
2. `12_phase1_mvp.md` — 技術棧 & 相依
3. `03_adr.md` — 架構決策（重點：ADR-010/011/012 for Compliance）
4. `04_architecture.md` — 系統架構 & 資料層
5. `10_security.md` — 安全與合規（新增 ComplianceLog 稽核）
6. `11_deployment.md` — 部署與 CI/CD

### 🛡️ Compliance / 法務

1. `12_phase1_mvp.md` § 合規 AI 模組（直接快速入門）
2. `06_modules.md` § **ComplianceService & HITLService**（模組詳規）
3. `03_adr.md` § **ADR-010 & ADR-011**（架構決策）
4. `05_api.md` § **5.7-5.8**（Compliance 與 HITL 端點）
5. `01_prd.md` § 風險登記（R-08, R-09）

---

## 參考原始文件

| 檔案 | 性質 |
| :--- | :--- |
| `docs/_phase1_spec_extract.md` | 客戶 Phase I MVP 規格書（2026-05-06）純文本摘錄 |
| `docs/02_AI直銷Agent_PhaseI_單一MVP規格書_v2.docx` | 客戶原始 docx 規格 |
| `system_design_docs/01_synergy_ai_prd.md` | 原 PRD v1.0（已被 01_prd.md v3.0 取代） |
| `system_design_docs/健康直銷AI系統_模組分層與MVP規劃.docx` | 客戶策略文件 A |
| `system_design_docs/健康直銷AI平台_跨品牌擴張策略評估.docx` | 客戶策略文件 B |

---

## 下一步（Immediate Action Items）

### Week 0 (2026-05-08 ~ 2026-05-14)

1. ✅ **文件升級到 v3.0**（02/03/04/05 done，本清單更新）
2. **確認 Pilot 教練 3-5 位**（kuanwei action）
3. **Day 1 提出 LINE OA 申請**（kuanwei action，見 ADR-008）
4. `/pm-choose` — 確認前端 package manager（bun 或 pnpm）

### Week 1 (2026-05-15 ~ 2026-05-21) — 骨架

5. **問卷骨架**（Phase 1/2/3）+ 計分規則 + Customer schema
6. **ComplianceService 規則庫 v1**（C1/C2/C3/C4 詞表）
7. **產品知識庫 RAG 初版**
8. `/plan` — Week 1 實作計畫（QuestionnaireService + ScoringEngine）

### Week 2 (2026-05-22 ~ 2026-05-28) — AI 核心

9. **M2 雙版摘要**（客戶版 + 教練版）
10. **M3 商談話術**（前/中/後三段）
11. **ComplianceService 完整實裝**（三層檢查）
12. **HITL 佇列管理**

### Week 3 (2026-05-29 ~ 2026-06-04) — 跟進 & Leader

13. **M4 CRM + 10 種狀態**
14. **48h/7d/30d 提醒排程**
15. **Google Calendar 連動**
16. **M6 Activity Tracking + Leader Summary + Onboarding**

### Week 4 (2026-06-05 ~ 2026-06-11) — Pilot

17. **3-5 位教練 Pilot 上線**
18. **每日數據檢查與快速迭代**
19. **高風險話術修正**
20. **Phase II 決策評審**（2026-06-12）

---

## 文件統計（v3.0）

| 項目 | v2.0 | v3.0 | Δ |
| :---: | ---: | ---: | ---: |
| 核心文件 | 11 | 12 | +1 |
| Epic 與 User Story | 22 (4 Epic) | 28 (6 Epic) | +6 US |
| 模組 | 10 | 17 | +7 |
| 前端頁面 | ~12 | 22 | +10 |
| 使用者旅程 | 2 | 3 | +1 |
| 架構決策 (ADR) | 9 | 12 | +3 |
| BDD Feature | 4 | 9 | +5 |
| BDD Scenario | ~24 | ~44 | +20 |
| API 端點 | ~25 | ~45 | +20 |
| 風險項 | 6 | 9 | +3 (R-08/R-09 新) |
| 北極星指標 | 5 | 7 | +2 |
| 驗收標準 | ~24 | ~39+ | +15 |

---

## 鑰匙術語（v3.0 新增）

- **ComplianceService** — 合規檢查（規則庫 + LLM 二次覆核 + HITL）
- **HITL** — Human-In-The-Loop，人工審核環節（30min SLA）
- **ConversationCoachService** — 商談話術生成（前/中/後三段）
- **LeaderSummaryService** — Leader 視角漏斗與新手進度
- **OnboardingProgressService** — 新手教練進度 checklist
- **ActivityTrackingService** — 教練活動聚合、KPI 統計
- **EventLog** — 全系統埋點（AI 任務、風險詞、延遲追蹤）
- **雙版摘要** — 客戶版（友善）+ 教練版（含推薦/紅旗）
- **10 種狀態** — 新名單 → 已填問卷 → 已預約 → 已商談 → 已推薦 → 試用中 → 已成交/未成交 → 需回訪 → 沉默
- **物化視圖** — `mv_coach_weekly_stats`、`mv_leader_summary`（30min refresh）
- **合規檢查三層防線** — Layer 1 規則庫初篩 → Layer 2 LLM 二次覆核 → Layer 3 HITL 人工確認

---

## 相關資源

- **VibeCoding 模板**：見 `VibeCoding_Workflow_Templates/` 目錄
  - `01_workflow_manual.md` — 整體開發流程
  - `03_behavior_driven_development_guide.md` — BDD 指南
  - `04_architecture_decision_record_template.md` — ADR 模板
- **UI 設計系統**：見 `.claude/ui/` 目錄（Apple tokens）
- **編碼規則**：見 `.claude/rules/` 目錄（coding-style、development-workflow、security 等）
- **Monorepo 結構**：見根層 `CLAUDE.md`

---

## 版本記錄

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v1.0 | 2026-04-24 | 初版產出（11 份文件 + 4 功能閉環） |
| v2.0 | 2026-04-24 | 從原 PRD 收斂為 4 功能 MVP（問卷/摘要/CRM/提醒） |
| v2.0.1 | 2026-04-24 | ADR-008：提醒通道改 LINE 優先 + Email 備援 |
| **v3.0** | **2026-05-08** | **Phase I MVP 擴充：6 大模組（新增 M1/合規/HITL/M6）、4 週時程、12 個 ADR、9 個 feature (44 scenario)、~45 個 API endpoint、22 個前端頁面、3 個新 DDD Context、2 個物化視圖** ✨ |

---

## 責任人 & 檢視排程

| 角色 | 責任 | 下次檢視 |
| :--- | :--- | :--- |
| **PM (kuanwei)** | PRD、Phase I 規格、決策記錄 | Pilot 完成（2026-06-15） |
| **Tech Lead** | 架構、ADR、API、安全 | Week 2 (2026-05-22) |
| **Compliance Officer** | ComplianceService、HITL SLA、稽核日誌 | 每日（Pilot 期） |
| **工程師** | 模組規格、BDD、測試覆蓋率 | Sprint 結束（每週） |

---

**最後更新**：2026-05-08 | **下次審查**：Pilot 完成後（約 2026-06-15） | **負責人**：kuanwei
