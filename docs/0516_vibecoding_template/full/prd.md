# 專案簡報與產品需求文件 (PRD) — AI 直銷 Care Copilot

> **版本:** v1.0（基於客戶 0516 更新版整理） | **更新:** 2026-05-17 | **狀態:** 草稿（pending 6 題 P0 補答）

> **本 PRD 範圍**：Phase I (4 週 Pilot) + Phase I+ (Y1 H1) 主軸，並含 Phase II/III 願景章節。
> **依據文件鏈**：
> - ① `AI直銷CareCopilot_①完整專案Pre-PRD_FINAL_2026-05-16.xlsx`（決策來源）
> - ② `AI直銷CareCopilot_②MVP規格書_V7_FINAL_2026-05-16.xlsx`（工程級規格）
> - ③ `工程深度藍圖_PhaseII-III_2026-05-16.docx`（Phase II/III 參考）
> - ④ `比較圖表_舊04v6PRD_vs_新v7MVP_2026-05-16.docx`（pivot 對齊）

> **重大策略 pivot 聲明**：本 PRD 以 v7 (2026-05-16) Mailchimp Playbook 為準。**舊 04 v6 PRD（品牌總部買單、健康問卷主流程、Brand Governance Console、Agent OS）已廢棄**；舊版 §19-30 工程深度章節抽出獨立保存（DR-30）。**買方從「品牌總部」→「個別直銷商」**；**模式從「enterprise Agent OS」→「prosumer Mailchimp Playbook」**。

---

## 📖 代號與行話速查（先看這裡，再讀全文）

> 本 PRD 沿用客戶交付資料的編號系統。為避免一直跳來跳去，這份速查表把全文用到的代號、縮寫、行話一次解釋完。

### A. 七個工具的代號（Phase I 範圍）

| 代號 | 中文名 | 一句話功能 |
| :--- | :--- | :--- |
| **C1** | 關係記憶活檔案 | 每位客戶 7 欄位（基本／健康／家庭／工作／興趣／溝通偏好／最近互動），rep 漸進累積 |
| **C2** | 生活事件雷達 | 偵測生日、紀念日、寶寶、工作變動、健康話題 → 觸發**非銷售**關懷提醒 |
| **O1** | 今日 5 件事（App 首頁） | 開 App 第一眼，5 張卡告訴你今天該聯絡誰、為什麼 |
| **O2** | 訊息草稿引擎 | 為單一客戶生成 3 語氣（關懷／隨意／商業）訊息草稿，rep 手動送 |
| **O3** | 樣品追蹤 | 發樣品後 48h / 72h / 7d 自動排跟進草稿 + 轉換結果回填 |
| **G1** | 招募漏斗 lite | 暖名單 → 曝光 → 邀約 → 簽約，4 階段轉換率 + 合規招募話術 |
| **G8** | 合規低語 lite | 訊息送出前自動掃 50 個高風險詞（健康宣稱、收入保證），擋紅線 |

> 字母分類：**C** = Care 關懷層、**O** = Operational 執行層、**G** = Growth 管理層。Phase I 只做這 7 個；完整 21+ 工具願景見附錄 E。

### B. 引用前綴

| 前綴 | 意思 | 範例 |
| :--- | :--- | :--- |
| **FR-XXX** | Functional Requirement，v7 功能需求編號 | FR-001 = C1 那條功能需求 |
| **EP-XXX** | API Endpoint，後端端點編號 | EP-101 = `POST /api/contacts` |
| **AC-XXX-X** | Acceptance Criteria，驗收標準 | AC-001-1 = C1 的第 1 條驗收 |
| **DR-XX** | Design Rationale，設計決策記錄 | DR-21 = 「不抓 LINE 對話歷史」這個決策 |
| **Q0XX** | 待辦問題（PRD 完稿前要答） | Q016 = C1 七欄位 schema 還沒定 |
| **R-XX** | Risk，風險登記項 | R-09 = 50 詞庫太薄的風險 |
| **SR-XX** | Strategic Risk，戰略風險 | SR-06 = 買方碎片化卡 $5-10M ARR 天花板 |
| **SC-工具-XX** | Scenario，BDD 使用情境 | SC-O2-01 = O2 的第 1 個情境 |
| **US-XX** | User Story | US-04 = O2 對應的使用者故事 |
| **TR0~TR11** | Stage-gate 階段門（① Sheet 05） | TR6 = Spec 階段（PRD + AC + TEST Matrix） |
| **ENG-XX** | 工程深度（Phase II/III 用，舊 v6 重命名避撞號） | ENG-11 = 舊 v6 Agent Runtime Harness |

### C. 行話翻譯

| 詞 | 白話 |
| :--- | :--- |
| **sidecar**（嵌入式 / 非獨立 gate） | 「貼在流程旁邊跑的小檢查器」。不是獨立關卡頁面，而是 O2 / O3 / G1 在生草稿時自動順手跑一遍。對比 gate 是「擋在路中央必過的關卡」。本 PRD 兩者並用：G8 平時是 sidecar（背景檢查），對高風險訊息會升級成 gate（硬擋下） |
| **gate**（關卡 / 閘門） | 必過檢查點，沒通過就不能繼續。例：高風險訊息 → G8 硬阻擋 |
| **JTBD**（Jobs To Be Done） | 使用者「要被完成的事」。比痛點更具體、更行動導向 |
| **RLS**（Row Level Security） | Supabase 資料庫的列級權限。限制 rep 只能看自己 tenant + rep_id 的客戶資料 |
| **tenant**（租戶） | 多租戶架構下的一個獨立資料隔離單位。本案是 `brand_id` + `rep_id` 雙層 |
| **SAR**（Subject Access Request） | 客戶要求「給我我的資料」或「刪掉我的資料」的合規請求，GDPR/PIPL 要求必須回應 |
| **PIPL** | 中國個資法（Personal Information Protection Law） |
| **GDPR** | 歐盟個資法 |
| **FTC / FDA** | 美國聯邦貿易委員會 / 食品藥物管理局，管不實宣稱（收入保證、療效誇大）的紅線單位 |
| **PMF**（Product-Market Fit） | 產品／市場契合度。本案以「≥ 4/5 教練自願付 $39」作為 PMF 證據 |
| **k-factor** | 病毒係數，每位用戶平均能帶來幾個新用戶 |
| **P95** | 95 分位延遲，95% 請求在這個時間內完成（比平均更嚴格的延遲指標） |
| **nudge** | 提醒／推一把，本 PRD 指 App 主動跳出的關懷提醒卡 |
| **prosumer** | professional + consumer，個人專業使用者（非企業客戶） |
| **fail-closed** | 出錯時預設「擋下」，安全優先（對比 fail-open = 出錯放行） |
| **rep** | Representative，直銷商／教練 |
| **北極星指標** | 整個產品最核心的單一指標。本案 = 每 rep 每週 ≥ 10 Care Actions |
| **PR-3 護欄** | Product Rule 第 3 條：訊息一律 rep 手動送、絕不自動發 |
| **streaming**（SSE） | 草稿逐字回傳，rep 不用乾等全文生成完 |
| **Pilot / GA** | Pilot = 設計夥伴小規模試跑；GA = General Availability，正式上線 |
| **lite** | 簡化版（對比 full 完整版）。例：G1 lite = Phase I 只做漏斗統計，不做完整招募管理 |
| **草稿區** | Contact 詳情頁底部 O2 生成草稿、顯示合規檢查結果的區塊 |
| **Mailchimp Playbook** | 對標 Mailchimp 2008-2014 紀律：Y1-3 純 prosumer 拒絕 enterprise 合約 → Y5+ 才從強勢方賣 → $12B exit |
| **Refusal Protocol**（DR-25） | Y1-3 收到品牌方買單請求一律 polite refuse + 公開 broadcast 紀律，降低 founder 動搖風險 |
| **AEOS** | AI Employee Operating System，本案的母平台願景；MLM Copilot 是其「relationship sales」驗證垂直 |
| **MoSCoW** | 優先級分類：Must（必做）／ Should（重要可延後）／ Could（錦上添花）／ Won't（明確不做） |

---

## 1. 專案總覽

| 項目 | 內容 |
| :--- | :--- |
| **專案名稱** | AI 直銷 Care Copilot |
| **產品定位** | 直銷商的「關懷 Copilot」— 記得每位你關心的人、知道今天該聯絡誰、不再像在推銷 |
| **狀態** | 規劃中（Phase I MVP / 4 週 Pilot） |
| **目標發布日期** | Pilot 上線 = 2026-W4（基準週 = W1 起算）；Series A 阻擋 = M12 |
| **核心團隊** | CEO / 產品 (Irene Op Lead) / AI Architect (待補, P0 卡點) / FTC 律師 (待補, P0 卡點) / Engineer (待補) / Synergy 教練 ×1 (Domain Expert) |
| **利益相關者** | 創辦人、Synergy 設計夥伴（6 教練 + 5 下線）、Top 100 Leader Influencer（GTM 引擎）、未來 PLG-friendly Series A 投資人（a16z / Benchmark / Index / Lightspeed / Sequoia consumer arm） |
| **策略基準** | Mailchimp Playbook（純 rep prosumer，Y1-3 拒絕 brand 合約；Y5+ optional enterprise） |
| **退場願景** | $1.5–8B exit（Mailchimp trajectory）；Bear case $30-80M acqui-hire |

---

## 2. 商業目標與 OKRs

### 背景與痛點

**目標市場規模**：Relationship-driven independents $16.5B TAM（不需品牌通路）。

**直銷商當前痛點（量化）**：
1. **80% 直銷商月收 < $300**（DSN 數據）
2. **首購 90 天流失率 > 40%**
3. **Penny AI 滲透率 < 10%**（市場未飽和但既有方案不足）
4. **FB / TikTok MLM Script GPT $27–97 充斥但無合規層**（structural gap）
5. **rep 記不住 100+ 客戶的 context**、上次聊什麼忘了、錯過跟進黃金 48h
6. **訊息冷僵硬像業務員**（icky factor）
7. **沒有 mobile-first × FTC 合規 × MLM-native 的整合產品**

**競爭白空間**（① Sheet 10 結論）：沒有任何競品同時做到：
1. Rep-side mobile UX
2. FTC 嵌入式合規
3. MLM-native（招募 / Sample / Funnel）
4. Asia LINE/WA-first
5. 關懷層差異化（C1 Memory / C2 Life-event Radar）

### 策略契合度

| 維度 | 對齊內容 |
| :--- | :--- |
| **公司核心** | AEOS（AI Employee Operating System）的「relationship sales」垂直驗證 — 純 rep mode 是「solo professional AI OS」最乾淨平台論調 |
| **Series A 軌道** | Mailchimp Playbook 對 PLG-friendly fund 極具吸引力；目標 Pre-A $1-2M → Series A $8-12M @ $50-70M（M12 ≥ 80 Top Leader 為阻擋條件） |
| **跨垂直延伸** | C1/O1/O2/G8 工具邏輯 100% 可重用至 Amway / Herbalife（H-08 待驗證）；Phase II 延伸至 real estate / insurance |
| **合規順風** | FTC + Rytr 案 + EU AI Act 持續對「無合規 AI 寫手」收緊 → 我們的合規層 = 結構性差異 |
| **Asia 市場** | LINE / WA 主導通路，無強競品；亞洲健康直銷 vertical exclusivity（Synergy partnership）|

### OKRs

#### Phase I (4 週 Pilot) OKRs

| Objective | Key Result | 衡量方式 | 目標值 |
| :--- | :--- | :--- | :--- |
| **O1: 證明 PMF（自願付費）** | KR1: 教練自願付 $39 / 月 | W4 Pilot 訪談 + payment intent | **≥ 4 / 5 教練** |
| | KR2: 每 rep 每週 Care Actions | EventLog 計數 | **≥ 10 / 週** |
| | KR3: AI 採用率（草稿被採用比例） | Langfuse + EventLog | **≥ 60%** |
| **O2: 0 合規踩線** | KR1: FTC red line 觸發次數 | ComplianceLog + leader 抽查 | **= 0** |
| | KR2: 50 phrase 召回率 | 紅隊測試 | **≥ 95%** |
| **O3: GTM 引擎啟動** | KR1: Top Leader 簽約 | BD pipeline | **≥ 10 by M3** |
| | KR2: Top 100 Leader 總簽 | 累計 | **≥ 80 by M12（Series A 阻擋）** |
| | KR3: k-factor (viral) | Referral tracking | **≥ 0.2 by M6** |

#### Phase II+ (Y1-Y3) OKRs

| Objective | Key Result | 目標值 |
| :--- | :--- | :--- |
| **O4: ARR 規模化** | Y1 Core ARR | $0.3M |
| | Y2 Core ARR | $3M |
| | Y3 Core ARR | $10M |
| **O5: 跨垂直驗證** | 跨垂直 design partner | Y3 末 ≥ 1 個 |
| | Skill reuse 比例 | > 70% |
| **O6: Series A 達陣** | 估值 | $50-70M @ Series A |

---

## 3. 目標用戶 (Personas)

### Persona 1: 中段 Active Rep — **Maggie**（v1 主 persona，唯一）

| 項目 | 描述 |
| :--- | :--- |
| **角色** | Synergy（或其他 generic MLM）直銷商，Rank 2–3，30-45 歲女性，居住台北 / 高雄 / 新加坡 / 馬來西亞華語區 |
| **規模** | 已有 20–100 個客戶 / 暖名單；月 GMV $500-2,000；月收入 $100-500（typical） |
| **痛點** | 1. 100+ 客戶 context 記不住，上次聊什麼忘了 2. 錯過跟進黃金 48h（樣品 / 邀約） 3. 訊息冷僵硬像業務員（icky factor） 4. Penny AI 只能套範本，不懂她客戶 5. FB GPT bot 無合規、無持久記憶 6. 每月已花 $50-80（LINE Premium $3-7 + Canva $13 + 修圖影音 $10-30 + FB GPT bot $10-15） |
| **目標 (JTBD)** | 「**幫我像個有溫度的朋友，而不是業務員**」「給我一個友善的每日 5 件事，讓我能持續做下去」 |
| **行為** | 每日開 App 1-3 次；高頻：每日訊息草稿 5-20×、Today's 5 開啟 1×、樣品跟進提醒 3-10×、生活事件 nudge 2-5×；技術程度：手機熟、PC 弱；偏好 LINE / WA / IG DM > Email |
| **v1 對應工具** | C1 Memory + C2 Radar + O1 Today's 5 + O2 Draft + O3 Sample（+ G1 / G8 為輔） |
| **付費門檻** | Pro $39 / 月（取代現有 $50-80 工具棧的 60%） |

### Persona 2: Newbie Rep — **Lily**

| 項目 | 描述 |
| :--- | :--- |
| **角色** | 加入 < 90 天的新人 rep，Rank 0–1 |
| **痛點** | 1. 不知道每天該做什麼 2. 怕推銷被朋友 block 3. 話術冷僵硬，不敢開口 |
| **目標** | 「給我一個友善的每日 5 件事，讓我能持續做下去」 |
| **v1 對應** | O1 Today's 5 + C1 Memory + O2 Draft；Freemium 30 contacts 入門 |
| **付費門檻** | Freemium $0 → 14d upsell to Pro |

### Persona 3: Top 100 Leader Influencer — **Sandy**（GTM 引擎對象）

| 項目 | 描述 |
| :--- | :--- |
| **角色** | Rank 5+（Iconic / Power / Rising），個人 reputation 是事業；下線 100-500+；社群 10K-50K+ |
| **痛點** | 想被當 industry thought leader；想賺被動收入；想成為下個世代直銷意見領袖 |
| **目標** | 「幫我成為下個世代直銷 thought leader + 賺被動收入」 |
| **v1 對應** | Founders Circle + 個人 referral landing page + commission dashboard（FR-014） |
| **付費門檻** | **免費 + 30-40% commission + equity 0.02-0.5%** |

### Persona 4: Leader / Director（**Phase II 才主打**）

| 項目 | 描述 |
| :--- | :--- |
| **角色** | Rank 5+；5-50 位下線 |
| **痛點** | 每天 coaching 私訊轟炸；不知道誰需要救；複製困難 |
| **目標** | 「給我規模化的關懷工具，不要讓我每天 8 小時打字」 |
| **v1 對應** | v1 不主打（hook 已埋於 G1 lite）；**Phase II 主打 G4 Downline Coach / G5 Recognition / G6 Rank Tracker** |
| **付費門檻** | Leader Team $129 / 月（含 10 下線 seat） |

### Won't / 不做 Persona（Mailchimp 紀律）

| Persona | 為何 v1 不做 |
| :--- | :--- |
| **Brand Admin / 品牌總部** | Y1-3 完全不在 scope（DR-25 Refusal Protocol；DR-27 創辦人公開承諾「2 年不做 enterprise」）；Y5+ 才 optional reverse partnership |
| **Brand Marketing 團隊** | 同上 |
| **Compliance Officer（品牌端）** | 同上；v1 合規只給 rep 看 |

---

## 4. 競爭分析

> 詳見 ① Sheet 10。三軸：**Rep-side mobile UX × FTC/FDA 合規 × MLM-native**。

| 維度 | Penny AI | Rallyware | FB/TikTok MLM Script GPT | HubSpot Breeze | 通用 LLM (ChatGPT/Claude) | **Care Copilot（我們）** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **核心功能** | Rep CRM + 跟進範本 | 品牌端 Performance Enablement | $27 prompt wrapper | 通用 CRM + AI agents | Free-form chat | **C1 Memory + 7 工具 + Compliance + Asia LINE-first** |
| **定價** | $6.99-8.99 / 月 | $5-15 / 月（**品牌付**） | $27-97 一次性 | $20-150 + Hub $450-800 | $20-30 / 月 | **Pro $39 / 月（prosumer）** |
| **AI 能力** | 範本 + 提醒；薄 | Intelligent Field Orchestration (2025) | 無持久記憶、無合規 | Breeze AI agents (2025) | 無 context、無合規 | Sonnet 4.6 抽取 + Haiku 草稿 + L1 regex 合規 |
| **優勢** | 便宜 | 企業關係 | 病毒擴散 | 大廠生態 | 通用強大 | **MLM-native + Asia-first + 合規** |
| **劣勢** | 無合規 / 無 RAG / 無關懷層 | 只賣品牌方；rep 接觸不到 | 無產品、無持續迭代 | B2B 重；不懂 MLM | 無 channel、無合規 | 新創、無品牌 |
| **威脅等級** | 中 | 低（不同買方） | **高**（rep 真實在用） | 中 | 中 | — |
| **我們對應差異** | C1 + C2 是 Penny 沒有的 | 直賣 rep；繞過企業銷售 | C1 Memory + Compliance + 持續產品 = 結構性差距 | MLM-native + Asia-first（LINE-first） | Context-aware + 合規 + 通路嵌入 | — |

**戰略威脅**（① Sheet 17 Risk Register）：
- **SR-01（🔴 高）**：Anthropic 自己推 personal AI memory（18-24m）— 緩解：垂直深度 + 品牌合作 + 速度 + build-on-top
- **SR-06（🔴 高）**：買方碎片化卡 $5-10M ARR 天花板 — 緩解：3 軌並進（Top Leader Influencer + Viral + Content）

**白空間結論**：**沒有任何競品同時做到 5 維度** → 1-2 年窗口開放、無強對手、合規順風、Asia 市場未開發。

---

## 5. 使用者故事與允收標準

> US 對應 ② V7 Sheet 03（INVEST 標準）；AC 詳見 ② V7 Sheet 02；BDD 場景詳見 § 5.X。

### Epic A：關懷層（Care）— v1 差異化護城河

| ID | 描述 (As / I want / So that) | 優先級 | 允收標準（AC） | BDD 連結 |
| :--- | :--- | :--- | :--- | :--- |
| **US-01** | As a **Rep**, I want **每位客戶有活檔案，自動記住細節**, so that **我不再把客戶當陌生人**。 | **Must** | AC-001-1 Memory ≥3 欄位 ≥ 80%（待 Q016）；AC-001-2 手填單欄位 ≤ 10s；AC-001-3 輔助捕捉 4 法（貼上/OCR/語音/Share/手填）；AC-001-4 跨 contact 0 資料洩漏 | `bdd/c1_memory.feature` SC-C1-01..05 |
| **US-02** | As a **Rep**, I want **被提醒客戶生活事件做關懷**, so that **我能在對的時機自然連結**。 | **Must** | AC-002-1 生日 / 紀念日 100% 準時（前 7 天 + 當天）；AC-002-2 對話抽取 precision ≥ 80%；AC-002-3 100% 含 trigger_reason；AC-002-4 nudge 採納率 ≥ 40%（北極星子指標） | `bdd/c2_radar.feature` SC-C2-01..03 |

### Epic B：執行層（Operational）— 黏著度引擎

| ID | 描述 | 優先級 | 允收標準 | BDD 連結 |
| :--- | :--- | :--- | :--- | :--- |
| **US-03** | As a **Rep**, I want **打開 App 就知道今天該做什麼**, so that **我不浪費時間想要做什麼**。 | **Must** | AC-003-1 首頁元件規格定稿（Q035 草擬完）；AC-003-2 首頁載入 P95 ≤ 2s；AC-003-3 5 卡每張一鍵進對應 action；AC-003-4 開 App → 知道今天做什麼 ≤ 10s | `bdd/o1_today.feature` SC-O1-01..03 |
| **US-04** | As a **Rep**, I want **一鍵生成 3 語氣訊息草稿**, so that **我不再從空白卡關**。 | **Must** | AC-004-1 首字 ≤ 3s、全文 ≤ 8s（streaming）；AC-004-2 三語氣（關懷 / 隨意 / 商業）皆生成；AC-004-3 100% 經 Compliance；AC-004-4 context 命中率 ≥ 90%；AC-004-5 採用率 ≥ 60% | `bdd/o2_draft.feature` SC-O2-01..04 |
| **US-05** | As a **Rep**, I want **樣品發出後自動提醒跟進**, so that **不再漏接成交機會**。 | **Must** | AC-005-1 log ≤ 15s（手機）；AC-005-2 48h/72h/7d 準時 ≥ 99%；AC-005-3 每階段草稿必過 Compliance；AC-005-4 sample → sale 轉換率可追蹤 | `bdd/o3_sample.feature` SC-O3-01..03 |

### Epic C：管理層（Growth）— Phase II 升級錨點（v1 lite）

| ID | 描述 | 優先級 | 允收標準 | BDD 連結 |
| :--- | :--- | :--- | :--- | :--- |
| **US-06** | As a **Rep**, I want **追蹤招募漏斗 4 階段**, so that **我能看到自己團隊有沒有成長**。 | **Must** | AC-006-1 4 階段轉換率正確計算；AC-006-2 招募話術 100% 過 Compliance；AC-006-3 暖名單 → 簽約整體轉換 ≥ 5% | `bdd/g1_funnel.feature` SC-G1-01..02 |
| **US-07** | As a **Rep**, I want **訊息先過合規檢查**, so that **不踩 FTC / FDA 線**。 | **Must** | AC-007-1 50 phrase 召回 ≥ 95%；AC-007-2 FPR < 10%（v1 寬鬆）；AC-007-3 100% 寫 ComplianceLog；AC-007-4 詞庫過 Synergy Legal review（待 Q018） | `bdd/g8_compliance.feature` SC-G8-01..04 |

### Epic D：平台 / GTM / 飛輪 — v1 商業閉環

| ID | 描述 | 優先級 | 允收標準 | BDD 連結 |
| :--- | :--- | :--- | :--- | :--- |
| **US-08** | As a **Top Leader**, I want **有個人 referral page + commission 看板**, so that **我能把 AI 工具當被動收入經營**。 | **Should** | referral track 100%；commission 計算正確 | `bdd/g_leader.feature` |
| **US-09** | As a **New Rep**, I want **免費試用先看價值**, so that **我能 risk-free 決定要不要付費**。 | **Must** | Freemium 30 contacts；O2 限 5 draft / 日；14d upsell flow | `bdd/freemium.feature` |
| **US-10** | As a **Rep**, I want **分享成就拉朋友**, so that **k-factor 提升**。 | **Should** | k-factor ≥ 0.2 by M6；Care Streaks / Refer-a-friend mechanic | `bdd/viral.feature` |

### 優先級定義 (MoSCoW)

| 等級 | 定義 | 此版本 User Stories |
| :--- | :--- | :--- |
| **Must** | 沒有就不能發布（Pilot 必過） | US-01, US-02, US-03, US-04, US-05, US-06, US-07, US-09 |
| **Should** | 重要但可延後（Pilot 內若時間足則加） | US-08, US-10 |
| **Could** | 錦上添花（Phase I+ 4-8 週） | O5 Voice Note Draft、O6 Quick Objection、C3 Tone Sensor、C4 Too-Salesy Warning |
| **Won't（v1）** | 本版本明確不做 | 6 子卡 Conversation Copilot（取代為 O2）、AI 見證生成（Rytr 風險，DR-05）、Brand Knowledge Console（Y5+）、Agent API（Y5+）、6 層 Memory（Phase II/III）、Skill Registry（Phase II）、MCP Gateway（Phase II）、Eval Dashboard（Phase II）、佣金計算、完整電商、組織樹管理、自動發訊息（PR-3）、多語系（v1 繁中） |

### 5.X 關鍵 BDD 場景（Given / When / Then 含實際資料）

> 場景命名：`SC-<工具>-<序號>`。完整 50 題 test set 見 Q041（Pilot 前 W3 完成）。以下列出 12 個關鍵場景。

#### SC-C1-01 — rep 用截圖 OCR 把 LINE 對話塞進關懷檔案
- **Given** rep `R001` 已登入，contact `Anna (CT-3071)` 已建檔但 `health_focus = NULL`
- **And** rep 從 LINE 截圖一張對話（Anna 提到「最近睡不好，想找助眠的東西」），圖檔 1.2MB
- **When** rep 在 Anna 詳情頁點「+ 從截圖補資料」→ 選擇截圖 → 等待 OCR
- **Then** 系統 ≤ 4 秒回傳 OCR + Sonnet 4.6 抽取建議：
  ```json
  { "health_focus": "睡眠改善",
    "last_interaction_summary": "提到最近睡不好",
    "suggested_tags": ["睡眠困擾"],
    "capture_method": "screenshot_ocr",
    "ts": "2026-05-17T10:32:15+08:00",
    "confidence": 0.87 }
  ```
- **And** rep 點「確認套用」→ `CT-3071` 寫入欄位，EventLog 新增 `memory_update`
- **And** 同時觸發 C2 nudge：「下次提醒可關懷 Anna 睡眠主題」
- **And** AC-001-3（輔助捕捉）+ AC-001-2（手填 ≤ 10s）+ AC-001-4（無洩漏）皆計入通過

#### SC-C1-02 — rep 語音口述 5 秒補欄位
- **Given** rep `R001` 剛跟 Bella (CT-4102) 通話結束，得知 Bella 下週生日 5/24、近期關注睡眠
- **When** rep 點麥克風按鈕 → 口述「剛跟 Bella 聊完，下週日 5/24 生日，最近也在意睡眠」→ 點停止
- **Then** Speech-to-text ≤ 2s，Sonnet 4.6 抽取：
  ```json
  { "contact": "Bella", "birthday": "2026-05-24", "health_focus": "睡眠",
    "capture_method": "voice_memo", "confidence": 0.92 }
  ```
- **And** UI 預填 Bella 詳情頁的對應欄位（rep 一鍵確認）

#### SC-C2-01 — 生日前 7 天自動進 Today's 5
- **Given** `CT-4102 Bella` 的 `birthday = 2026-05-24`，今天 = `2026-05-17`
- **When** 每日 06:00 排程跑 Life-event Radar
- **Then** 生成 nudge：
  ```json
  { "contact_id": "CT-4102", "event_type": "birthday",
    "trigger_reason": "生日 7 天內（5/24）",
    "scheduled_at": "2026-05-17T06:00:00+08:00" }
  ```
- **And** rep 早上 07:30 開 App → O1 第 1 卡顯示「下週日（5/24）是 Bella 生日 — 寫關懷訊息」
- **And** rep 點開 → nudge 採納率分子 +1（NS 子指標）
- **And** AC-002-1（生日 100% 準時）+ AC-002-3（含 trigger_reason）皆通過

#### SC-O1-01 — rep 早晨開 App 在 10 秒內知道今天該做什麼
- **Given** rep `R001` 有 87 個客戶；今天有 2 個生日（C2）、3 個樣品 48h 到期（O3）、5 位 30 天無互動的沉睡客戶、1 個招募邀約待跟進
- **When** rep `06:45` 開 App → 進首頁
- **Then** P95 ≤ 2 秒內顯示 5 卡（排序如下）：
  1. **Bella 生日（5/24）** — 來源 C2
  2. **Cathy 樣品 48h 到期（SKU-NJ-001）** — 來源 O3
  3. **David 招募邀約 3 天未跟進** — 來源 G1
  4. **Eric 30 天沉睡** — 來源 FollowUp 規則
  5. **Fiona 生日 + 樣品同時到期** — 合併卡
- **And** 頂部「今日進度 0/5」+ Care Streak「12 天」
- **And** rep 點任一卡 → 同畫面開出 contact 詳情 + AI 預生成草稿（**無需第二次 LLM call**）
- **And** AC-003-2（P95 ≤ 2s）+ AC-003-4（≤ 10s 知道做什麼）皆通過

#### SC-O2-01 — 一鍵生成 3 語氣訊息草稿且全過 Compliance
- **Given** Contact `Anna (CT-3071)` Memory 含 `health_focus=睡眠改善`、`relation=老同學`
- **When** rep 在 Anna 詳情頁點「✨ 生成訊息草稿」→ 選 channel=LINE、intent=care
- **Then** 系統 ≤ 3s 回傳首字、≤ 8s 回傳完整 3 個草稿：
  ```json
  { "drafts": [
      { "tone": "care",
        "content": "Anna 最近還好嗎？上次聊到睡不好，這陣子有沒有好一點？我自己最近也在調作息，有空再分享。",
        "compliance_score": 0.02,
        "citations": ["Memory.health_focus", "Memory.relation"] },
      { "tone": "casual",
        "content": "嘿同學！好久不見啦～最近怎麼樣？",
        "compliance_score": 0.01 },
      { "tone": "business",
        "content": "Anna 上次聊到睡眠的問題，我這邊剛好有些朋友也在試一些方式，要不要找時間聊聊？",
        "compliance_score": 0.18 }
    ],
    "context_hit": ["health_focus", "relation"],
    "model_route": "haiku_first_token+sonnet_fulltext" }
  ```
- **And** 三個草稿皆 `compliance_score < 0.5` → 全部過、無紅框
- **And** rep 選 care 版 → 點「複製到 LINE」→ 系統開 LINE share sheet（**不自動發送，PR-3**）
- **And** AI 採用率分子 +1

#### SC-O2-02 — 草稿觸發合規詞被擋
- **Given** rep 想對 Anna 寫「保證一週瘦 5 公斤」訊息
- **When** rep 在草稿框輸入後點「過合規」（或 O2 自己生成出含此語）
- **Then** G8 在 < 50ms 回傳：
  ```json
  { "risk_score": 0.95, "action": "block",
    "matched_phrases": ["保證", "一週瘦"],
    "category": "health_unsupported_claim",
    "suggested_rewrite": "我自己用了一陣子，覺得作息和食慾有變化，分享給你參考",
    "log_id": "CL-20260517-000123" }
  ```
- **And** UI 顯示紅框 + 並排改寫建議 + 「採用建議」按鈕
- **And** **rep 強制送出按鈕不存在**（高風險硬阻擋）
- **And** ComplianceLog 寫入 1 筆事件（包含 rep_id / contact_id / risk_score / matched_phrases / final_action）

#### SC-O3-01 — 樣品發出後 48h 自動排提醒草稿
- **Given** rep `R001` 於 `2026-05-15 10:00 +0800` 發樣品 `SKU-NJ-001`（晚安睡眠茶）給 Cathy (CT-5009)
- **And** API call：`POST /api/samples { "contact_id": "CT-5009", "sample_sku": "SKU-NJ-001", "given_at": "2026-05-15T10:00:00+08:00", "channel": "in_person" }`
- **When** 系統於 `2026-05-17 10:00`（+48h）排程觸發
- **Then** O1 首頁第 N 卡顯示「**Cathy 樣品 2 天了，要不要關心一下？**」
- **And** 卡內預生成草稿（Haiku）：
  ```json
  { "draft": "Cathy 上次給你的睡眠茶喝了幾包？感覺如何？沒喝完也沒關係，順便聊聊近況～",
    "compliance_score": 0.05 }
  ```
- **And** 若 rep 7 天內無動作 → 樣品狀態自動標 `abandoned`，計入「sample → sale 轉換率」分母
- **And** AC-005-2（準時率 ≥ 99%）+ AC-005-3（必過 Compliance）皆計入

#### SC-G1-01 — 招募話術自動掃 FTC 收入宣稱
- **Given** rep 對 David (CT-6002) 寫邀約訊息「**加入我們團隊，月入 10 萬不是夢**」
- **When** 訊息經 O2 → G8 檢查
- **Then** G8 標記為高風險 `income_guarantee`：
  ```json
  { "risk_score": 0.92, "action": "block",
    "matched_phrases": ["月入", "10 萬"],
    "category": "income_guarantee",
    "suggested_rewrite": "我們團隊有些夥伴做得不錯，每個人成果不同，要不要先了解一下我們在做什麼？" }
  ```
- **And** 強制 rep 確認 → **不允許繞過送出**
- **And** funnel 階段不前進（仍卡在「邀約」階段）
- **And** AC-006-2（招募話術 100% 過 Compliance）通過

#### SC-G8-01 — 同義詞繞過（Pilot W4 紅隊觀察）
- **Given** rep 用同義詞繞過（「打包票」代「保證」）
- **When** O2 生成包含「打包票讓你瘦」的草稿
- **Then** G8 在 v1 50 phrase 詞庫**可能漏抓**（Pilot 期觀察 FPR）
- **And** ComplianceLog 仍寫入 raw 訊息供 leader 抽查
- **And** Pilot W4 若 leader 抽查發現漏攔 ≥ 3 次 → 緊急加詞庫到 200+（R-09 緩解）

#### SC-PII-01 — 客戶要求 SAR（資料存取請求）
- **Given** Contact `Eric (CT-7001)` 透過 rep 提出 SAR 請求
- **When** rep 在 Eric 詳情頁點「資料請求 → 匯出」→ `POST /api/privacy/sar { "contact_id": "CT-7001" }`
- **Then** 系統於 30 天內匯出該 contact 在系統內 100% 資料（JSON 檔，含 C1 Memory / EventLog / ComplianceLog 中所有相關 rows）
- **And** 若客戶提出刪除 → `DELETE /api/contacts/:id` → 7 天內物理刪除（含 EventLog 中相關 row 的 hash redaction）
- **And** AC-008-2 通過

#### SC-TENANT-01 — 跨 rep 資料隔離（紅隊測試）
- **Given** rep `R001`（Synergy）與 rep `R002`（Synergy）同 brand 但不同 tenant
- **When** rep `R002` 嘗試以 GET `/api/contacts/CT-3071`（屬 R001）
- **Then** Supabase RLS 強制 `rep_id` 過濾 → 回傳 `404 Not Found`（**非 403**，避免存在性洩漏）
- **And** 同樣的 vector retrieval（pgvector）跨 rep 拉資料 → 100% 被攔
- **And** 紅隊測試（Q044）跨 tenant 洩漏 case 100% 通過
- **And** AC-001-4 / NFR-Tenant 通過

#### SC-COST-01 — 每 rep AI 成本超 $0.30 / 日 自動降級
- **Given** rep `R001` 當日已用掉 $0.28，正生成第 N 個草稿
- **When** 預估該 call 會破 $0.30
- **Then** Model Router 自動降級：Sonnet → Haiku；rep 看到「⚠️ 今日 AI 額度即將用完，後續草稿改用快速版」提示
- **And** Token budget log 寫入 `{ rep_id, day, total_cost, downgrade_at }`
- **And** AC-Cost（≤ $0.30 / rep / day）持續滿足

---

## 6. 範圍與限制

### 6.1 功能範圍（v1 P0 — 必做）

**7 工具 + 5 平台 / 商業 FR**（共 13 個 FR-P0；2 個 P1；1 個 P2 stub）

#### 關懷層 C（v1 差異化）
- **C1 Relationship Memory**（FR-001 / EP-101, EP-102）
- **C2 Life-event Radar**（FR-002 / EP-103, EP-104）

#### 執行層 O（黏著度）
- **O1 Today's 5 Actions**（FR-003 / EP-105）
- **O2 Message Draft Engine**（FR-004 / EP-106）
- **O3 Sample-to-Sale Tracker**（FR-005 / EP-107, EP-108）

#### 管理層 G（lite，Phase II 加厚）
- **G1 Recruiting Funnel lite**（FR-006 / EP-109, EP-110）
- **G8 Compliance Whisper lite**（FR-007 / EP-111）

#### 跨模組支撐
- **FR-008** PII 同意 + SAR（EP-112, EP-113）
- **FR-009** AI Quick Actions Panel（全 App 共用）
- **FR-010** O8 健康問卷 stub（P2，只留入口；DR-13 從 P0 降級）
- **FR-011** Freemium tier（30 contacts，O2 限 5 draft/日）
- **FR-012** Viral / PLG mechanics（P1，Care Streaks / Refer-a-friend）
- **FR-013** Tier gating（Pro / ProPlus / Leader，DR-24）
- **FR-014** Top Leader Influencer 後台（P1，個人 referral page + commission 看板）
- **FR-015** EventLog 資料飛輪（待 Q014）

### 6.2 非功能需求（② V7 Sheet 04）

| 類別 | 指標 | Phase I 目標 | Status |
| :--- | :--- | :--- | :--- |
| 可用性 | Core API SLA | ≥ 99.0%（Pilot） | 🟢 已答 |
| 延遲 P95 | 首頁 / 草稿首字 / 草稿全文 | ≤ 2s / ≤ 3s / ≤ 8s | 🟢 已答 |
| 資料 | RPO / RTO | RPO ≤ 15 分 / RTO ≤ 4 小時 | 🟢 已答 |
| 安全 | Tenant Isolation / RBAC / PII 加密 | 全項 P0 | 🔴 待 Q027/Q028 |
| 合規 | risk_score + 觸發詞保存率 | 100% | 🟢 已答 |
| 品質 | Regression Eval Pass Rate | ≥ 70%（Pilot）/ ≥ 85%（GA） | 🔴 待 Q042 |
| 成本 | 每 active rep AI 成本 | ≤ USD 0.30 / 日 | 🟢 已答 |
| 多租戶 | brand_id schema Day 1 | 抽象保留，**不建 admin UI** | 🟢 已答（DR-26） |
| 可觀測性 | OTel / Langfuse / Sentry | 所有 AI 任務寫 EventLog | 🔴 待 Q039 |

### 6.3 明確不做（Non-goals）— Mailchimp 紀律

| 不做項 | 理由 / 出處 |
| :--- | :--- |
| 佣金計算 | 公司級後台領域；Exigo / DirectScale 已存在 |
| 完整電商 | 同上 |
| 組織樹管理 | 同上 |
| **自動發訊息** | PR-3 護欄；草稿模式 + rep 確認後送 |
| 品牌後台整合（Exigo / Synergy Hub） | Y1-3 不接觸品牌方 |
| **Brand Knowledge Console** | Y5+ optional only（DR-25） |
| **Agent API**（external） | Y5+ optional only |
| 多語系 | v1 繁中為主，簡中 / 英文 Phase II |
| **6 層 Memory Architecture** | Phase II/III（重型基建毀 lean MVP；DR-30） |
| **Skill Registry / MCP Gateway / Eval Dashboard** | Phase II（DR-30） |
| **Agent Runtime Harness** | Phase II（Pilot 5 教練不需 manifest 控制面） |
| **AI 假見證生成（M5）** | Rytr 2024 FTC 案；DR-05 v1 完全砍出 |
| **Voice clone（O5 高風險變形）** | 限 rep 本人 voice + 內容白名單 + Compliance Gate + audit |

### 6.4 假設

| ID | 假設 | 信心 | 驗證時點 |
| :--- | :--- | :--- | :--- |
| H-01 | 直銷商願意付 $30-50 / 月（非 Penny $7-10） | 中 | Pilot W4 |
| H-02 | C1 Relationship Memory 是「啊哈時刻」（顯著差異化） | 高 | Pilot W2-W3 |
| H-03 | 前 60 秒 = Today's 5 比「填問卷」更能讓 rep 留下來 | 高 | Pilot W4 D1/D7/D28 |
| H-04 | Compliance lite 已足夠 v1（不需 600 詞庫） | 中 | Pilot W4 leader 抽查 |
| H-05 | Sample-to-Sale Tracker 對所有 generic MLM 通用 | 中 | TR2 訪談 doTERRA/YL/Synergy |
| H-06 | LINE 語音訊息（O5）在亞洲 ROI > 文字 3× | 高 | Pilot W2-W3 A/B |
| H-08 | Generic MLM 跨品牌 schema 可重用 > 70% | 中 | Phase II 末 |
| H-10 | AI Employee 履歷 onboarding 60 秒讓 rep 信任 | 中 | Pilot W1 |

### 6.5 依賴

| 依賴 | 影響 | Owner | 狀態 |
| :--- | :--- | :--- | :--- |
| AI Architect 鎖定 | Q014 / Q016 / Q025 / Q027 / Q040 都卡這 | Irene | 🔴 P0 卡點，本季招到 |
| FTC-specialist 律師 | Q018 / Q023 / Q028 / Q034 / Q044 都需要 | Irene | 🔴 P0 卡點，本週簽 NDA |
| Synergy 設計夥伴 LOI | Pilot 對象 5 教練 + 1 Leader + 5 下線 | Irene | 🟡 對齊 Script 已草擬 |
| Synergy Legal review 50 phrase | G8 詞庫 v1 合規上線（AC-007-4） | Legal + Synergy | 🔴 待 Q018 |
| Anthropic API quota | Core LLM | AI Architect | 需確認 Pilot 期額度 |
| Supabase 部署 | PostgreSQL + pgvector + RLS | Engineer | 待 Engineer 就位 |
| LINE 不依賴官方 API | DR-21 設計消除：rep 輔助捕捉 → 無平台 ToS / PIPL / GDPR 風險 | Op | ✅ 已設計消除 |

### 6.6 風險（節錄；完整見 ① Sheet 11）

| RID | 風險 | 等級 | 緩解 | Owner |
| :--- | :--- | :--- | :--- | :--- |
| R-01 | AI 幻覺造成不實產品宣稱 | 高 | Approved claims only + citation + Compliance Gate + 人審 | AI + 法務 |
| R-02 | 醫療/收入宣稱踩 FTC/FDA 線 | 高 | 詞庫 + 風險分級 + 強制改寫 + 高風險阻擋 | 法務 |
| R-03 | AI 成本失控 | 中 | Model router + token budget + cache + batch | AI Architect |
| **R-04** | 品牌資料與 rep 私域衝突 | **低（設計消除）** | DR-21 rep 擁有資料 | AI Architect |
| **R-05** | LINE / WA / IG 平台限制自動化 | **低（設計消除）** | 不依賴平台 API；草稿 + 手動送 | AI Architect |
| R-06 | Pilot 教練不用 | 中 | Today's 5 + 關懷層；Weekly 1:1 | 產品 |
| R-07 | Anthropic API 中斷 | 中 | Multi-vendor router + rules fallback | AI Architect |
| R-08 | Rytr 案 → AI 假見證紅線 | 高 | M5 從 v1 砍出；用戶生成不過 AI | 法務 |
| R-09 | Compliance lite 太薄（50 phrase） | 中 | Pilot W4 觀察觸發率，必要時 W4 中緊急加詞庫 | 法務 + 產品 |
| **R-10** | Memory 抽取 LINE history 隱私同意鏈 | **低（設計消除）** | DR-21 不抽取，無同意鏈 | 法務 + AI Architect |
| R-11 | Voice clone 被濫用發假語音 | 中 | 限 rep 本人 voice + 白名單 + Compliance + audit | AI Architect |
| R-12 | v1 沒有 Leader downline，M1/M4 證據不足 | 中 | Pilot W3 招募 1+ Leader 帶 5 下線 | GTM |
| R-13 | Generic MLM 假設破裂 | 中 | H-08 驗證；BrandConfig 抽象維持 | AI Architect |

**戰略風險**（① Sheet 17）：
- SR-01 Anthropic 推 personal AI memory（🔴 高）
- SR-04 Voice clone 濫用品牌災難（🟠 中-高）
- SR-06 買方碎片化卡 $5-10M ARR 天花板（🔴 高）
- SR-07 PIPL / GDPR 對關係記憶資料執法（🟡 中）

---

## 7. 上市策略 (Go-to-Market)

### 7.1 Phase I (4 週 Pilot) Roadmap

| 階段 | 時間 | 目標 | 交付物 | 並行 GTM |
| :--- | :--- | :--- | :--- | :--- |
| **W1** | Day 1-7 | 骨架 + Compliance lite | 骨架 + C1 Memory schema + 50 phrase + EventLog | Synergy 設計夥伴啟動 |
| **W2** | Day 8-14 | AI 核心 | C1 + O1 Today's 5 + O2 Draft + AI Quick Actions | Top 10 Leader outreach |
| **W3** | Day 15-21 | 跟進閉環 | O3 Sample + G1 Funnel lite + Freemium + Viral mechanics MVP | Top Leader 持續招募 |
| **W4** | Day 22-28 | Pilot 上線 | 5 教練 + 1 Leader + 5 下線；自願付費評估 | Top Leader 25 簽 + 教練訪談 |

### 7.2 三階段 Roadmap（v1 → Phase III）

| Phase | 期程 | 核心命題 | 成功指標 | Kill Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **Phase I (Pilot)** | 4 週 | 關懷 Copilot 立得住 + Synergy 設計夥伴 | ≥ 4/5 教練自願付 $39 + 0 合規 + Top 10 Leader signed | ≤ 2/5 自願付 / Top Leader < 10 by M3 |
| **Phase I+ (Y1 H1)** | 6 月 | GTM 引擎啟動 | Top 50 Leader + 1,000+ paying + k-factor ≥ 0.2 | Top Leader < 30 by M6 / k-factor < 0.15 |
| **Phase II (Y1 H2 - Y3)** | 30 月 | 100 Top Leader + Federated Playbook + 跨垂直 #2 | 5K-15K paying + 1 跨垂直 + 100 Top Leader | ARR plateau < $5M Y3 / k-factor < 0.15 |
| **Phase III A (Y4)** | 12 月 | Reverse partnership 評估 + 跨垂直 #3 | 20K-30K paying + Brand reverse ≥ 5 + Industry Insights $500K ARR | Brand reverse < 3 / Y4 ARR < $15M |
| **Phase III B (Y5+, optional)** | 開放 | 若 leverage 翻轉 → Brand Enterprise tier from strength | $15-40M additional ent ARR by Y7 | Brand 接受 < 3 → 純 rep forever（仍 $50M+ core） |

### 7.3 GTM 引擎：Top 100 Leader Influencer Program

**Year 1 月度 KPI 追蹤**（Series A 阻擋條件 M12 ≥ 80）：

| 指標 | M1 | M3 | M6 | M9 | M12 | Series A 阻擋 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Tier 1 Iconic 簽約 | 0 | 2 | 5 | 8 | **10** | Yes |
| Tier 2 Power 簽約 | 0 | 5 | 15 | 30 | **40** | Yes |
| Tier 3 Rising 簽約 | 0 | 10 | 25 | 40 | **50** | No |
| **總 Leader 數** | 0 | 17 | 45 | 78 | **100** | **Yes（≥ 80）** |
| Leader 帶 paying | 0 | 50 | 500 | 1,500 | **3,500** | No |
| k-factor | — | — | 0.15 | 0.20 | **≥ 0.20** | No |

**Year 1 預算總額** $695K（約 7% Series A 募資額），含 signing $200K + commissions $80K + Head of Influencer $150K + 出差 / 大會 $50K + 內容 $80K + tools $15K + Founders Circle 晚宴 $40K + 公關 $30K + Reserve $50K。

### 7.4 定價

| Tier | 定價 | 包含 | 目標用戶 | Phase |
| :--- | :--- | :--- | :--- | :--- |
| **Freemium** | $0 永久 | 30 contacts + C1/C2/O1/O2 限 5 draft/日 | 新 rep 試用 | Phase I |
| **Pro**（主力） | **$39 / 月** | 全 7 工具 P0 無限制 | 中段 Active Rep | Phase I |
| **Pro Plus** | $79 / 月 | + Voice + AI Insights Pro + 跨品牌 | 進階 Rep / 高 ARPU | Phase I |
| **Leader Team** | $129 / 月（含 10 下線 seat） | + G4 Downline + G5 Recognition + G6 Rank | Director / Leader | Phase II |
| **Top Leader Influencer** | 免費 + 30-40% commission | + Founders Circle + equity 0.02-0.5% | Top 100 Leader 全球 | Phase I 持續 |
| **Industry Insights** | $5K-50K / 年 | aggregate trend reports（去識別） | MLM 顧問 / 研究 / 媒體 | Phase II |
| **Synergy Design Partner** | $0（換 12 月 exclusivity + Y4 first refusal） | Pro Plus 永久免費 | Synergy 6 教練 + 5 下線 | Phase I |
| ⚠️ **Y5+ optional Brand Enterprise** | $25-50 / seat / 月（reverse only） | + Brand Console + 600 詞庫 + Audit | MLM 品牌（reverse only） | Phase III B |

**定價邏輯**：
- Penny $6.99-8.99 = commoditized，**不對標**
- 對標 Mailchimp / Calendly / Notion **prosumer tier**
- rep 月已花 $50-80（LINE Premium + Canva + 修圖 + FB GPT bot）；我們 $39 取代 60%，比現狀便宜
- ChatGPT / Claude Plus $20 已建立「個人 AI $20-30 正常」心智

---

## 8. 成功指標與追蹤

### 8.1 北極星指標

| 層級 | 指標 | 基線 | 目標（Pilot W4） | 追蹤 | 負責人 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **北極星** | 每 rep 每週 **Care Actions** | — | ≥ 10 / 週 | EventLog + Langfuse | 產品 |
| 子指標 | C1 Memory ≥3 欄位 ≥ 80% | — | ≥ 80% | EventLog | 產品 |
| 子指標 | C2 nudge 採納率 | — | ≥ 40% | EventLog | 產品 |
| 子指標 | O2 草稿 AI 採用率 | — | ≥ 60% | EventLog | 產品 |
| 子指標 | sample → sale 轉換率 | — | 可追蹤即達標 | EventLog | 產品 |
| 子指標 | G1 funnel 整體（暖名單→簽約）轉換 | — | ≥ 5% | EventLog | 產品 |

### 8.2 商業指標

| 指標 | 基線 | 目標 | 追蹤 | 負責人 |
| :--- | :--- | :--- | :--- | :--- |
| Pilot W4 教練自願付 $39 | — | **≥ 4/5** | 訪談 + payment intent | GTM |
| Pilot W4 自願 NPS | — | ≥ 8 | 訪談問卷 | 產品 |
| Top 100 Leader 簽約 by M12 | 0 | **≥ 80**（Series A 阻擋） | BD pipeline | Head of Influencer |
| paying users by M12 | 0 | 800-1,500 | Stripe + DB | GTM |
| k-factor by M6 | — | ≥ 0.2 | Referral track | 產品 + GTM |
| Y1 Core ARR | 0 | $0.3M | Stripe | GTM |
| Y2 Core ARR | — | $3M | | |
| Y3 Core ARR | — | $10M | | |

### 8.3 護欄指標（不可低於）

| 指標 | 不可低於 / 高於 | 觸發行動 |
| :--- | :--- | :--- |
| Core API SLA | < 99.0% | P0 incident |
| 首頁 P95 | > 2s | 性能調優 sprint |
| AI 採用率 | < 30% | Kill criteria 觸發 |
| 合規踩線 | ≥ 3 次 / pilot | Kill criteria 觸發 + 緊急加詞庫 |
| 教練流失 | ≥ 2 / 5 | Kill criteria 觸發 |
| 成本超預算 | > 50% | Kill criteria 觸發 |
| 每 rep AI 成本 | > $0.30 / 日 | Model Router 自動降級 |
| Tenant 跨界 | > 0 次 | P0 安全 incident |
| Compliance 召回率 | < 95% | 詞庫加厚 |

### 8.4 追蹤工具

- **EventLog**（PostgreSQL）— 所有 AI 任務 / rep action 寫入
- **Langfuse** — LLM trace + prompt / cost / latency / quality
- **Sentry** — error tracking
- **OpenTelemetry** — distributed tracing
- **Stripe** — payment / subscription
- **Mixpanel / PostHog** — funnel / retention（pilot 後選一）

---

## 9. 待辦問題與決策

### 9.1 P0 待答（本週必答，阻擋 PRD 完稿 / build）

| QID | 問題 | Owner | 狀態 | 截止 |
| :--- | :--- | :--- | :--- | :--- |
| **Q002** | AI Employee JD（職位 / 可做 7 件 / 不可做 5 件 / KPI） | Irene + Op | 🟢 草擬完成（待 review） | 本週五 |
| **Q014** | 知識三分類 Schema（Static / Policy / Dynamic） | AI Architect（待補） | 🔴 待答 | 本週 |
| **Q016** | Relationship Memory 7 欄位 schema 設計 | AI Architect（待補） | 🔴 待答 | 本週 |
| **Q035** | 首頁 IA（Today's 5）元件規格 wireframe | Op + 設計 | 🟢 草擬完成（待設計出圖） | 本週 |
| **Q040** | 資料模型 brand-agnostic 設計（BrandConfig + Tenant 雙層） | AI Architect（待補） | 🔴 待答 | 本週 |
| **Q008** | 定價驗證（$39 prosumer）5 rep 訪談 + landing A/B | GTM Lead（Irene） | 🟢 結構定（待驗證） | 本週 |

### 9.2 P1 待答（兩週內，阻擋設計與工程預估）

Q009 已解 ✅（DR-21 通路決策）；剩餘 10 題：Q010 高頻動作 / Q012 Domain Expert 投入 / Q018 Compliance 詞庫 RACI / Q019 onboarding / Q023 不可做清單 / Q025 Tool Gateway / Q027 Tenant 隔離 / Q028 PII 遮罩 / Q036 RACI 完整名單。

### 9.3 已做決策（節錄；完整 30 條見 ① Sheet 13）

| DR ID | 決策 | 結論 | 日期 |
| :--- | :--- | :--- | :--- |
| **DR-11** | v1 買方 | **個別 rep + Leader**（v1）；品牌方 Phase III | 2026-05-15 |
| **DR-12** | 產品定位主軸 | **關懷 Copilot**（核心）+ 執行 + 管理（三層） | 2026-05-15 |
| **DR-13** | 健康問卷處理 | **P2 可選工具**；改為「關懷檔案」5-7 欄位 | 2026-05-15 |
| **DR-14** | 首頁 IA | **Today's 5**（含生活事件） | 2026-05-15 |
| **DR-15** | Generic MLM vs Synergy-only | **Generic MLM + Synergy Pilot** | 2026-05-15 |
| **DR-16** | v1 範圍 | **7 工具 bundle**（C1, C2, O1, O2, O3, G1, G8） | 2026-05-15 |
| **DR-17** | 定價 | **Pro $39 + ProPlus $79 + Leader $129** | 2026-05-15 |
| **DR-18** | Compliance 詞庫 | **v1 50 phrase + alert**；Phase II 600+ | 2026-05-15 |
| **DR-19** | Voice note (O5) | **v1 P1**（pilot 2 教練 A/B） | 2026-05-15 |
| **DR-20** | Leader downline pilot | **至少 1 Leader + 5 下線** | 2026-05-15 |
| **DR-21** | 通路資料策略 | **不讀 LINE，改 rep 輔助捕捉**（消除 Q009 + R-04/05/10） | 2026-05-16 |
| **DR-25** | Brand 接觸協議 | **Refusal Protocol**：Y1-3 polite refuse + 公開 broadcast 紀律 | 2026-05-15 |
| **DR-26** | 架構紀律 | 保留 brand_id schema 抽象（Y5+ optionality），**不建 brand admin UI** | 2026-05-15 |
| **DR-27** | 創辦人公開承諾 | Y1-3 拒絕 enterprise 公開承諾（blog / podcast），confirm no enterprise in 2 years | 2026-05-15 |
| **DR-28** | 投資人對齊 | Series A 僅 align PLG-friendly fund | 2026-05-15 |
| **DR-30** | 舊 v6 §19-30 工程深度處置 | **抽成獨立 Phase II/III 藍圖**，不入 Phase I V7 scope | 2026-05-16 |

### 9.4 ADR 連結

- ADR-001 PostgreSQL + pgvector（DR-02）
- ADR-002 LangGraph + 內部抽象 vs OpenAI Agents / Vertex ADK（DR-03）
- ADR-003 Claude Opus 4.7 主合規（Phase II；v1 純 regex）（DR-04）
- ADR-004 brand_id 抽象但不建 admin UI（DR-08 + DR-26）
- ADR-005 不依賴 LINE API（DR-21）
- ADR-006 重型工程章節抽出 Phase II/III 藍圖（DR-30）

> 後續用 `/docs-init --full` 之 ADR 子流程或 `04_architecture_decision_record_template.md` 範本逐份產出。

---

## 附錄 A：FR ↔ EP ↔ AC ↔ Sheet 對應快查

| FR | 工具 | EP | AC 數 | Sheet 來源 | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| FR-001 | C1 Memory | EP-101 / 102 | 4 | ② V7 S02 / ① S03 / Q016 | 🔴 待 Q016 |
| FR-002 | C2 Radar | EP-103 / 104 | 4 | ② V7 S02 | 🔴 待答 |
| FR-003 | O1 Today's 5 | EP-105 | 4 | ② V7 S02 / Q035 | 🔴 待 Q035 |
| FR-004 | O2 Draft | EP-106 | 5 | ② V7 S02 | 🟢 已答 |
| FR-005 | O3 Sample | EP-107 / 108 | 4 | ② V7 S02 | 🔴 待答 |
| FR-006 | G1 Funnel lite | EP-109 / 110 | 3 | ② V7 S02 | 🔴 待答 |
| FR-007 | G8 Compliance lite | EP-111 | 4 | ② V7 S02 / DR-07/18 | 🟢 已答（待 Q018 詞庫） |
| FR-008 | PII + SAR | EP-112 / 113 | 3 | ② V7 S02 / DR-21 | 🟢 已答 |
| FR-009 | AI Quick Actions Panel | — | — | DR-10 | 🟢 已答 |
| FR-010 | O8 健康問卷 stub | — | — | DR-13 | 🟢 已答（降為 P2） |
| FR-011 | Freemium tier | — | — | — | 🔴 待答 |
| FR-012 | Viral / PLG mechanics | — | — | — | 🔴 待答 |
| FR-013 | Tier gating | — | — | DR-24 | 🟢 已答 |
| FR-014 | Top Leader Influencer 後台 | — | — | Influencer 計畫 | 🔴 待答 |
| FR-015 | EventLog 飛輪 | — | — | Q014 | 🔴 待 Q014 |

---

## 附錄 B：推薦模型路由規則 v1（② V7 Sheet 06）

| 條件 | 路由 |
| :--- | :--- |
| 短訊息、低風險、無宣稱 | Haiku 4.5；只查 contact profile |
| 含產品 / 成分 / 健康感受 | Sonnet 4.6 + 必過 Compliance Whisper |
| 含疾病 / 治療 / 收入 / 保證 | 高風險：硬阻擋或並排改寫；強制 rep 確認 |
| Memory 抽取 | Sonnet 4.6（structured extraction） |
| Today's 5 排序 | 規則 v1（無 LLM） |
| Compliance lite 檢查 | 純 regex（v1 不走 LLM reviewer） |
| 招募話術（高 FTC 風險） | Sonnet 4.6 + 強制 G8 |

---

## 附錄 C：舊 v6 PRD → 新 v7 對照（節錄；完整見 ④ 比較圖表）

| # | 維度 | 舊 04 v6 | 新 v7（本 PRD） |
| :--- | :--- | :--- | :--- |
| 1 | 產品定位 | 直銷 + Leader + **品牌總部** 的 AI 商談 / 跟進 / 合規 / field orchestration **Agent OS** | **直銷商**的「**關懷 Copilot**」— 記憶 + 今日 5 + 一鍵草稿 |
| 2 | 買方 | rep + Leader + **品牌總部買單** | rep + Leader（Y1-3）；品牌方 Phase III optional |
| 3 | 產品形態 | Mobile PWA + AI Panel + **Brand Governance Console** + **Agent API** | Mobile PWA + Embedded AI Quick Actions（**無品牌後台**） |
| 4 | 北極星 | Compliant Conversation Action ≥ 10 / 週 | **Care Action ≥ 10 / 週**（多一項：寫入 Memory） |
| 5 | 核心範圍 | 問卷 → 摘要 → 商談腳本 → 合規 → 跟進 + Brand Console + Agent API | **7 工具**（C1/C2/O1/O2/O3/G1/G8 lite） |
| 6 | 架構 | M1-M7 模組 + **重型 Agent Runtime** / 6 層 MEM / Skills / MCP / Eval Gate | 3 層 C/O/G + 輕量 RAG L1/L3 + Compliance lite |
| 7 | 健康問卷 | **P0 主流程**（M2 Consultation Intake） | **P2 可選工具**（DR-13 降級） |
| 8 | 合規 | 詞庫 ≥ 600 + Rules + LLM Reviewer + 高風險阻擋 | **lite：50 phrase + alert 嵌入式** |
| 9 | 通路 / 資料 | **LINE OA + 問卷收集**；Phase II opt-in API | **DR-21：不依賴 LINE API，rep 輔助捕捉 4 法** |
| 10 | 定價 | Rep $29-49 / Leader $99-199 / Brand $3K-10K / Ent $8-18 seat | **Freemium $0 / Pro $39 / ProPlus $79 / Leader $129**（Y1-3 無品牌 tier） |
| 11 | GTM 引擎 | 品牌通路（Synergy → USANA → Herbalife → Amway） | **Top 100 Leader Influencer Program** |
| 12 | 策略 / 退場 | 未明定；品牌擴張 | **Mailchimp Playbook：純 rep Y1-3 → Y4 reverse → Y5+ optional ent；$1.5-8B exit** |

**本質結論**：兩者買方、入口、定價、GTM、工程量級**全不同 — 這是策略 pivot，不是版本升級**。現行以 v7 為準；v6 的工程章節保留為 Phase II/III 參考。

---

## 附錄 D：Phase II / III 工程深度藍圖摘要

> 完整內容見 `docs/0516更新版/工程深度藍圖_PhaseII-III_2026-05-16.docx`。**Phase II 啟動前必讀 Part 0 + Part 3**。

| 舊章 | 內容 | Phase | DR 衝擊 |
| :--- | :--- | :--- | :--- |
| §19 | Agent Runtime 最終架構 | Phase II | 無 |
| §20 | LLM / Agent 平台檢查 | 持續參考 | 需更新到當期模型 |
| §21 | Agent Runtime Harness (SR-201~207) | Phase II | Pilot 5 教練不需 manifest 控制面 |
| **§22** | **6 層 Memory Architecture** | Phase II/III | ⚠️ **需重設計**：原為 LINE 抽取 + 同意鏈，DR-21 已廢；scope/TTL/tenant 隔離原則仍有效 |
| §23 | Skills / Procedural Knowledge Layer | Phase II | 原則沿用 |
| §24 | MCP / A2A / Tool Interop | Phase II（MCP）/ III（A2A） | 原則沿用 |
| §25 | Flow / State Machine 事件合約 | Phase I 部分採（idempotency_key / event schema） | 完整狀態機 Phase II |
| **§26** | **Eval Harness / Model Upgrade Gate** | Phase II | ⚠️ **標準不同**：§26 是 600 詞庫級；v1 lite 是 50 phrase / FPR < 10% |
| §27 | Agent Security Threat Model | Phase I 輕量意識 / Phase II 完整 | 部分有效 |
| **§28** | **ENG-11~15 + NFR-011/012**（**撞號已重命名**） | Phase II | ⚠️ **FR-011~15 與 v7 撞號**；現行 build 一律以 v7 為準 |
| §29 | Roadmap 調整 | 參考 | Phase I 只取 minimal harness/trace/idempotency |

**Phase I 輕量可採（3 概念）**：
1. event `idempotency_key`（§25）— 防外部發送重複執行
2. trace 基本欄位（§21 SR-205 / §28 NFR-011 輕量版）— route / model / risk_score / user_action
3. fail-closed 合規（§21 SR-207）— Compliance 失敗預設阻擋

**Phase II 啟動「不可照抄」清單**：
- §22 Customer Memory — 改 rep 輔助捕捉來源；保留 scope/TTL/tenant 隔離
- §26 Compliance Golden Set 標準 — Phase II 加厚到 600 時才套此標準
- §28 FR-011~015 編號 — 一律用 ENG-11~15
- §30 DR-07~10 — 一律看 ① Sheet 13

---

## 附錄 E：產品願景圖（全 21+ 工具）

| Phase | 關懷層 C | 執行層 O | 管理層 G | 工具數 | 累計 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Phase I (v1 MVP, 4 週)** | C1, C2 | O1, O2, O3 | G1 (lite), G8 (lite) | 7 | 7 |
| Phase I+ (v1 加強, 4-8 週) | C3, C4 | O5, O6 | — | 4 | 11 |
| Phase II (4 個月) | C5 | O4, O7, O8 | G2, G3, G4, G5, G6 | 9 | 20 |
| Phase III (6-12 個月) | — | — | G7 + Brand Console | 2 | 22 |

**結論**：
1. 原 PRD M1-M7 在全產品中 100% 覆蓋 — M1/M4/M6/M7 直接保留並擴充；M2/M3/M5 重構或拆解但意圖保留
2. 新增 9 個 MLM-native 工具（C1/C2/O3/O4/O5/G1/G2/G3/G7）是把產品從「健康諮詢」改成「真實 MLM 平台」的關鍵
3. v1 MVP（7 工具）= 平台 wedge；全產品（21+ 工具）跨 3 階段、3 層
4. **不要把 v1 當「全部產品」推銷給 Synergy** — 他們是 Pilot brand，要看到完整 Phase I/II/III 願景

---

## 附錄 F：後續文件產出指引

依 VibeCoding Workflow Templates 順序，後續可逐份產出：

| 編號 | 文件 | 範本 | 本 PRD 對應章節 |
| :--- | :--- | :--- | :--- |
| 03 | BDD Guide | `03_behavior_driven_development_guide.md` | § 5 + § 5.X 12 個 SC 場景擴充至 50 個 |
| 04 | ADR ×6 | `04_architecture_decision_record_template.md` | § 9.4 已列 6 個 ADR |
| 05 | 架構與設計 | `05_architecture_and_design_document.md` | mvp/prd.md § 5 架構總覽擴充 |
| 06 | API 設計 | `06_api_design_specification.md` | 附錄 A 的 EP-101~113 擴充為完整 OpenAPI |
| 07 | 模組規格 + 測試 | `07_module_specification_and_tests.md` | § 6.1 13 個 FR 逐份展開 |
| 08 | 專案結構 | `08_project_structure_guide.md` | 依 monorepo 慣例（FastAPI + React 19）|
| 09 | 設計與依賴 | `09_design_and_dependencies.md` | § 6.5 依賴表展開 |
| 11 | 程式審查 | `11_code_review_and_refactoring_guide.md` | — |
| 12 | 前端架構 | `12_frontend_architecture_specification.md` | Mobile PWA / React 19 + Tailwind v4 |
| 13 | 安全與就緒 | `13_security_and_readiness_checklists.md` | § 6.5 R-01~13 + SR-01~07 |
| 14 | 部署與運維 | `14_deployment_and_operations_guide.md` | — |
| 15 | 文件與維護 | `15_documentation_and_maintenance_guide.md` | — |
| 16 | WBS 開發計畫 | `16_wbs_development_plan_template.md` | § 7.1 + § 7.2 |
| 17 | 前端資訊架構 | `17_frontend_information_architecture_template.md` | § 5 SC-O1-01 / Q035 IA |
