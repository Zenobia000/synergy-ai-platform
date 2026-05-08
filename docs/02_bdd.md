# BDD 行為驅動情境 — Synergy AI Closer's Copilot

> **版本:** v3.0 | **更新:** 2026-05-08 | **對應 PRD:** `docs/01_prd.md` | **對應 Phase I MVP:** `docs/12_phase1_mvp.md`

---

## 版本更新說明（v2.0 → v3.0）

本版本升級為 Phase I v3.0，詳細補充 5 個新增 feature 與既有 feature 的額外 scenario（Gherkin 標準語法）：

**新增 5 個 feature**（詳細編寫）：
- ✨ `compliance.feature` — ComplianceService 三層檢查 + HITL
- ✨ `conversation_coach.feature` — 商談前/中/後話術
- ✨ `leader_summary.feature` — Leader 漏斗與新手進度
- ✨ `onboarding_progress.feature` — 新手教練 checklist
- ✨ `hitl.feature` — HITL 人工審核隊列

**既有 4 個 feature**（補充新 scenario）：
- ⬆️ `questionnaire.feature` — 三階段 + 雙版摘要
- ⬆️ `briefing.feature` — 商談前/中/後 + 合規
- ⬆️ `crm.feature` — 10 種狀態 + Google Calendar
- ⬆️ `reminder.feature` — 提醒排程 + 通道 fallback

---

## Feature 檔案索引

| # | 檔案 | 對應 Epic | User Stories | Scenario 數 |
| :---: | :--- | :--- | :--- | :---: |
| 1 | `questionnaire.feature` | Epic A | US-A01-A05 | 4 + 3 新 = 7 |
| 2 | `briefing.feature` | Epic B + C | US-B01-B04 | 4 + 3 新 = 7 |
| 3 | `crm.feature` | Epic C + D | US-C01-C04 | 4 + 2 新 = 6 |
| 4 | `reminder.feature` | Epic D | US-D01-D03 | 3 + 2 新 = 5 |
| **5** | **`compliance.feature`** | **Epic E** | **US-E01-E03** | **4** |
| **6** | **`conversation_coach.feature`** | **Epic B** | **US-B02-B03** | **4** |
| **7** | **`leader_summary.feature`** | **Epic F** | **US-F01-F02** | **4** |
| **8** | **`onboarding_progress.feature`** | **Epic F** | **US-F03** | **3** |
| **9** | **`hitl.feature`** | **Epic E** | **US-E02** | **4** |

**合計**：約 44 個 Scenario

---

## 既有 Feature 的新增 Scenario

### 1. `questionnaire.feature`（v3.0 更新）

**既有 Scenario 基礎**：Phase 1 快速分流、Phase 2 六大核心、計分規則

**新增 3 個 Scenario**：

```gherkin
# Feature: 智能健康問卷（三階段）

Scenario: Phase 3 動態題目根據前面回答調整
  Given 客戶已完成 Phase 2（六大核心）並選中「睡眠差」
  When 進入 Phase 3（動態追問）
  Then 系統應該顯示「睡眠相關題目」（飲食、補充品、規律性）
  And 不顯示「非相關題目」（女性週期、體態等）
  And 總題數控制在 3-8 題

Scenario: 客戶版摘要禁用診斷用語
  Given 問卷答案觸發「睡眠品質 < 6 小時」風險
  When 系統生成客戶版摘要
  Then 摘要應使用「睡眠品質偏低」而非「失眠症」
  And 不出現「治療」「治癒」「預防 X 病」等醫療宣稱詞
  And 包含免責聲明「本資料僅供健康參考，非醫療診斷」

Scenario: 教練版摘要含紅旗與 SKU 推薦
  Given 問卷完成後 30 秒內
  When 系統生成教練版摘要
  Then 摘要應包含三部分：
    | 部分 | 內容 |
    | 痛點 | 客戶前三大健康關注 |
    | 紅旗 | 需特別注意的風險訊號 |
    | 推薦 | 2-3 個 SKU + 理由（引用問卷答案） |
  And 所有推薦 SKU 已通過合規檢查
```

---

### 2. `briefing.feature`（v3.0 更新）

**既有 Scenario 基礎**：商談前 5 分鐘摘要、單頁可讀

**新增 3 個 Scenario**：

```gherkin
# Feature: 商談副駕駛（前/中/後話術）

Scenario: 商談中實時查詢異議回覆
  Given 教練進入商談中話術頁面
  When 客戶提出「朋友吃了沒效」的異議
  Then 系統應快速顯示 2-3 個預期異議回覆建議
  And 包含「每個人體質不同」「建議試用 2 週」等親切話術
  And 每條話術均 < 100 字、易於即時使用
  And 回覆時間 ≤ 5 秒

Scenario: 商談後自動帶入 48h 提醒排程
  Given 教練商談後點「生成下一步訊息」
  When 系統產出商談後訊息草稿
  Then 訊息應包含：
    | 項目 | 內容 |
    | 客戶名字 | 「王小姐」 |
    | 上次痛點引用 | 「根據妳剛才說的睡眠問題…」 |
    | 建議下一步 | 「建議妳先試用，48 小時後我再跟進」 |
  And 自動預設 48h 後提醒時間
  And 教練一鍵確認後自動建立 Google Calendar 事件

Scenario: 所有話術已通過合規檢查
  Given 問卷送出，系統生成所有話術（前/中/後）
  When 話術內容進入 ComplianceService
  Then 所有話術應通過合規檢查（無 C1/C2/C3/C4 風險詞）
  And 高風險話術應被改寫或標記待人工審核 (HITL)
  And 低風險話術應自動加上免責聲明
  And 合規日誌記錄每條話術的檢查結果
```

---

### 3. `crm.feature`（v3.0 更新）

**既有 Scenario 基礎**：CRM 列表、狀態流轉、自動建檔

**新增 2 個 Scenario**：

```gherkin
# Feature: 客戶管理 & 10 種狀態機

Scenario: 客戶狀態從「已商談」轉為「已推薦」自動排程 48h 提醒
  Given 客戶王小姐的狀態為「已商談」
  When 教練更新狀態為「已推薦」
  Then 系統應自動建立三個提醒：
    | 提醒類型 | 觸發時間 | 提醒內容 |
    | 48h 提醒 | 48 小時後 | 「記得跟進王小姐」 |
    | 7d 提醒 | 7 天後 | 「王小姐試用進度如何？」 |
    | 30d 提醒 | 30 天後 | 「回訪王小姐，詢問是否繼續」 |
  And 提醒自動寫入 reminders 表
  And `last_contact_at` 自動更新為當前時間

Scenario: 教練標記成交後未發送的提醒自動取消
  Given 客戶王小姐有 3 個待送提醒（48h/7d/30d）
  When 教練標記狀態為「已成交」
  Then 系統應自動標記所有未發送提醒為 `status=cancelled`
  And 已發送的提醒保留用於審計
  And 若已建立 Google Calendar 事件，自動標記完成
```

---

### 4. `reminder.feature`（v3.0 更新）

**既有 Scenario 基礎**：提醒排程、多通道發送

**新增 2 個 Scenario**：

```gherkin
# Feature: 自動提醒 & Google Calendar 連動

Scenario: 提醒事件自動建立到教練 Google Calendar，時區正確
  Given 系統建立 48h 提醒（due_at = 2026-05-03T14:00:00Z）
  And 教練時區設定為「Asia/Taipei (UTC+8)」
  When APScheduler 掃描到期提醒
  Then Google Calendar 事件應以本地時間顯示：
    | 欄位 | 值 |
    | 標題 | 「跟進王小姐」 |
    | 時間 | 2026-05-03 22:00（台北時間） |
    | 敘述 | 「客戶：王小姐 / 健康等級：B / 上次痛點：睡眠差」 |
  And 事件自動加入教練日曆
  And 若時區修改，已建立事件時間應相應調整

Scenario: 成交後日曆事件自動標記完成
  Given 教練的 Google Calendar 有未來 3 個提醒事件
  When 教練標記客戶狀態為「已成交」
  Then 系統應自動：
    | 動作 | 詳情 |
    | 取消提醒 | reminders 表標記 `cancelled` |
    | 更新日曆 | Google Calendar 事件標記完成 / 描述加上「已成交」標籤 |
    | 稽核日誌 | 記錄取消理由與時間 |
  And Google Calendar 側邊欄應無「未完成」提醒
```

---

## 新增 Feature：詳細 Scenario

### 5. `compliance.feature`（新增）

```gherkin
# Feature: 合規檢查與風險防護

Background:
  Given ComplianceService 已初始化規則庫（含 C1/C2/C3/C4 詞表）
  And LLM 模型為「gemini-2.5-flash」

Scenario: 規則庫命中醫療宣稱關鍵詞自動標記風險
  Given 邀約文案內容為「本產品可以治療糖尿病」
  When 邀約文案通過 ComplianceService.check()
  Then 系統應：
    | 步驟 | 結果 |
    | Layer 1 檢查 | 詞表命中「治療」(C1) |
    | 風險等級 | 標記為 `medium` |
    | 規則紀錄 | 記錄命中規則 ID 與模式 |
  And 進入 Layer 2（LLM 二次覆核）

Scenario: LLM 進行語意確認，低風險自動通過
  Given 邀約文案為「幫助改善睡眠品質」
  When 通過 Layer 1（規則庫無命中）
  Then 系統應：
    | 層級 | 動作 |
    | Layer 1 | 未命中黑名單 → `risk_level=candidate` |
    | Layer 2 | LLM 語意檢查 → 無醫療宣稱 → `risk_level=low` |
    | 最終 | 自動通過，加上免責聲明 → 發送 |
  And 合規日誌記錄「自動通過」決策

Scenario: 高風險文字自動改寫並送 HITL
  Given 話術內容為「100% 有效、立即見效」（C3 誇大效果）
  When 通過 ComplianceService.check()
  Then 系統應：
    | 層級 | 動作 |
    | Layer 1 | 命中誇大詞表 |
    | Layer 2 | LLM 確認高風險 → `risk_level=high` |
    | 改寫 | 產出「許多使用者回饋有感」作為改寫版本 |
    | HITL | 進入合規隊列，等待人工審核 |
  And 合規官員需在 30 分鐘內審核決策
  And 審核結果（批准/拒絕/改寫）記入 compliance_logs

Scenario: 合規日誌記錄原文、改寫版本、審核狀態
  Given 任何觸發 ComplianceService 的訊息（問卷摘要、話術、邀約文案、提醒草稿）
  When 完成檢查流程（無論自動通過或人工審核）
  Then compliance_logs 表應記錄：
    | 欄位 | 內容 |
    | original_text | 原始文字（完整） |
    | risk_type | C1/C2/C3/C4/None |
    | risk_level | low / medium / high |
    | rewritten_text | LLM 改寫版本（若有） |
    | reviewed_by | 審核官員 ID（若經 HITL） |
    | reviewed_at | 審核時間戳 |
    | decision | approved / rejected / modified |
  And 稽核日誌可按日期、風險類型、教練 ID 查詢
  And 誤判 > 5% 時觸發告警
```

---

### 6. `conversation_coach.feature`（新增）

```gherkin
# Feature: 商談副駕駛話術生成（前/中/後）

Background:
  Given 客戶已完成問卷、教練版摘要已生成
  And ConversationCoachService 就緒

Scenario: 商談前 5 分鐘摘要含核心痛點三句話
  Given 教練在商談前 5 分鐘打開客戶摘要頁面
  When 進入 `/leads/:id/briefing` 頁面
  Then 摘要應包含「痛點摘要」區塊，含：
    | 要素 | 範例 |
    | 痛點句 1 | 「睡眠品質連續 6 週 < 6 小時」 |
    | 痛點句 2 | 「過去試過 2 次減重都未成功」 |
    | 痛點句 3 | 「家族有糖尿病史，擔心自己的代謝」 |
  And 每句話 < 20 字、易於記憶
  And 頁面應於 2 秒內載入（3G 網路）
  And 自動採用深色模式便於實際商談環境使用

Scenario: 商談中提示包含產品銜接、異議回覆、成交邀約
  Given 教練進入商談中話術頁面 (`/leads/:id/conversation/in-session`)
  When 系統產出商談中話術建議
  Then 應分為三大區塊：
    | 區塊 | 內容 | 數量 |
    | 產品銜接 | 「根據妳的睡眠問題，我推薦…」 | 2-3 條 |
    | 異議回覆 | 「若客戶說『朋友吃了沒效』，回覆…」 | 2-3 條 |
    | 成交邀約 | 「柔性邀約：『不如先試試？』」 | 2-3 條 |
  And 每條話術都 ≤ 100 字、可直接使用
  And 所有話術均已通過 ComplianceService 檢查
  And 教練可一鍵複製話術到剪貼簿

Scenario: 商談後訊息自動帶入跟進排程
  Given 商談結束，教練點「生成下一步訊息」
  When 系統產出商談後訊息草稿
  Then 訊息應包含：
    | 要素 | 實例 |
    | 開場 | 「王小姐，謝謝妳今天的時間！」 |
    | 回顧 | 「我們聊到妳的睡眠問題和減重目標」 |
    | 建議 | 「建議妳先試用 2 週，看看身體反應」 |
    | 跟進 | 「48 小時後我再跟妳確認」 |
  And 訊息應自動預設 48h 後提醒（可手動調整）
  And 一鍵發送至 LINE OA，記錄發送時間
  And 自動建立 Google Calendar 提醒事件
```

---

### 7. `leader_summary.feature`（新增）

```gherkin
# Feature: Leader 儀表板 — 下線教練本週漏斗

Background:
  Given Leader 帳號已授權、有 3-5 位下線教練
  And 數據已聚合至 `mv_leader_summary` 物化視圖

Scenario: Leader 進入 Summary 頁看到下線 3-5 位教練本週漏斗
  Given 今天是週一 10:00
  When Leader 進入 `/leader/summary` 頁面
  Then 應顯示本週（Monday-Sunday）漏斗：
    | 教練 | 問卷數 | 商談數 | 成交數 | 轉換率 |
    | 阿明 | 12 | 5 | 1 | 20% |
    | 阿傑 | 8 | 2 | 0 | 0% |
    | 小美 | 15 | 6 | 2 | 33% |
  And 可按教練名稱排序、按成交率排序
  And 點選教練名稱進入詳情頁 (`/leader/coaches/:id`)
  And 頁面應於 2 秒內載入

Scenario: 找出「卡在商談未成交」的教練
  Given 漏斗數據中阿傑「商談 2 / 成交 0」
  When Leader 掃一眼漏斗數據
  Then 系統應視覺上突出低成交率教練（如橘色警告）
  And Leader 應立刻識別「阿傑需要 1:1 coaching」
  And 可點選進入阿傑的詳情頁查看原因
  And 詳情頁應顯示：
    | 指標 | 值 |
    | 平均商談準備時間 | 25 分鐘（應 < 5 分鐘） |
    | 話術使用率 | 40%（應 ≥ 80%） |
    | 跟進執行率 | 60%（應 ≥ 80%） |
  And Leader 可計畫 1:1 coaching

Scenario: 查看新手教練 Onboarding 進度
  Given 小美是新手教練（< 30 天），有 onboarding checklist
  When Leader 進入 Summary 頁下段「新手教練進度」
  Then 應顯示每位新手的進度：
    | 新手教練 | 任務進度 | 完成度 |
    | 小美 | 「使用摘要 3 次」✓ 「完成首個成交」✗ 「邀約 20+ 客戶」✗ | 33% |
  And Leader 可點選「查看詳細」進入 onboarding 詳情頁
  And 詳情頁列出全部 checklist 與預期完成日期
```

---

### 8. `onboarding_progress.feature`（新增）

```gherkin
# Feature: 新手教練進度追蹤 & Leader 分派

Background:
  Given 新手教練小美加入系統（< 30 天）
  And onboarding_tasks 預設清單已初始化

Scenario: 新手教練完成「使用摘要 3 次」自動標記
  Given 小美的 onboarding task「使用摘要 3 次」狀態為 pending
  When 小美查看第 3 個客戶的商談摘要
  Then 系統應自動：
    | 動作 | 詳情 |
    | 計數 | event_logs 記錄「generate-briefing」事件 |
    | 檢查 | 確認該任務已達 3 次 |
    | 標記 | `onboarding_tasks.completed_at = now()` |
    | 通知 | 小美收到「恭喜完成任務」提醒 |
  And Leader 頁面即時顯示進度更新（30 分鐘內）

Scenario: Leader 可分派新任務給新手教練
  Given Leader 進入小美的 onboarding 詳情頁
  When Leader 點「分派新任務」按鈕
  Then 應出現任務選擇表：
    | 預設任務 | 描述 |
    | 「邀約 50+ 客戶」 | 累計邀約數達 50 |
    | 「完成 5 次商談」 | 完成 5 場客戶商談 |
    | 「達成首個季度目標」 | 月成交 ≥ 3 單 |
  And Leader 可選擇任務、設定完成期限（如 30 天）
  And 任務寫入 onboarding_tasks 表

Scenario: 進度百分比實時計算
  Given 小美有 10 個 onboarding 任務
  When 已完成 3 個任務
  Then onboarding 進度條應顯示 `30%`
  And 進度條隨每次任務完成實時更新
  And 達到 100% 時觸發「新手教練畢業」狀態轉換
  And 自動推送「恭喜畢業」通知至 Leader + 小美
```

---

### 9. `hitl.feature`（新增）

```gherkin
# Feature: 人工審核隊列（HITL）管理

Background:
  Given HITL 合規隊列已建立（compliance_queue 表）
  And 至少有 1 位授權審核員（Leader / Admin）

Scenario: 高風險話術進入 HITL 佇列
  Given ComplianceService Layer 2 判定話術為 `risk_level=high`
  When 話術無法自動改寫或需人工確認
  Then 系統應：
    | 動作 | 詳情 |
    | 入隊 | 寫入 compliance_queue（status=pending） |
    | 標記 | 教練頁面顯示「待審核」狀態 |
    | 通知 | 審核員收到「待審項目」提醒 |
  And 教練 UI 顯示「正在審核中…」，訊息暫不發送
  And SLA 時限 ≤ 30 分鐘

Scenario: 合規官員可批准/拒絕/修改
  Given HITL 隊列中有 1 筆高風險話術
  When 審核員進入 `/compliance/queue` 頁面
  Then 應列出待審項目：
    | 欄位 | 內容 |
    | 原文 | 「100% 有效」 |
    | 風險類型 | C3（誇大效果） |
    | LLM 改寫 | 「許多使用者回饋有感」 |
  And 審核員可選擇：
    | 決策 | 後果 |
    | Approve | 採用 LLM 改寫版本 → 發送 |
    | Reject | 拒絕、通知教練重新編寫 |
    | Modify | 編輯改寫版本 → 發送修改版 |
  And 每次決策記錄審核者 ID、時間、理由

Scenario: 批量審核支援
  Given HITL 隊列中有 10 筆待審項目
  When 審核員在表格中批量勾選 5 筆（風險類型相同）
  Then 應支援批量操作：
    | 操作 | 結果 |
    | 批量批准 | 5 筆同時標記 approved |
    | 批量拒絕 | 5 筆同時標記 rejected |
    | 批量匯出 | 導出 CSV 供外部簽核 |
  And 每筆操作仍記錄審核者、時間
  And 批量操作應於 1 秒內完成

Scenario: 審核歷史完整記錄
  Given 任何高風險話術經過 HITL 流程
  When 審核流程完成（批准/拒絕/修改）
  Then compliance_logs 應包含完整歷史：
    | 欄位 | 內容 |
    | entry_id | HITL 入隊 ID |
    | reviewed_by | 審核官員 ID |
    | reviewed_at | 審核時間戳 |
    | decision | approved / rejected / modified |
    | feedback | 審核官員備註 |
  And 可按日期、審核者、決策結果查詢
  And 經過 HITL 的所有話術不可刪除（完整稽核）
```

---

## 實裝注意事項

### 檔案組織

每個 feature 對應一個 `.feature` 檔案，位置：
```
apps/api/tests/features/
├── questionnaire.feature
├── briefing.feature
├── crm.feature
├── reminder.feature
├── compliance.feature
├── conversation_coach.feature
├── leader_summary.feature
├── onboarding_progress.feature
└── hitl.feature

apps/api/tests/step_definitions/
├── questionnaire_steps.py
├── briefing_steps.py
├── crm_steps.py
├── reminder_steps.py
├── compliance_steps.py
├── conversation_steps.py
├── leader_steps.py
├── onboarding_steps.py
└── hitl_steps.py
```

### 執行與 CI/CD

- **Framework**：`pytest-bdd` + `behave`（可選）
- **執行**：`pytest tests/features/ -v --tb=short`
- **CI/CD**：GitHub Actions，所有 feature 標 `@smoke-test` 在 PR 時強制通過
- **覆蓋率**：整合測試需達 ≥ 80%（含單元測試）

### 與單元測試的分工

- **BDD scenarios**：關鍵使用者旅程、端到端流程、業務規則驗證
- **Unit tests**：元件、邏輯、邊界條件、錯誤處理（pytest + unittest）
- **Integration tests**：資料庫操作、API 呼叫、外部服務（Gemini、LINE 用 mock）

---

**版本履歷**

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v1.0 | 2026-04-24 | 4 個 feature 骨架（無詳細 Gherkin） |
| v2.0 | — | （未發布） |
| **v3.0** | **2026-05-08** | **9 個 feature 完整 Gherkin：既有 4+5 新、共 ~44 scenario** |
