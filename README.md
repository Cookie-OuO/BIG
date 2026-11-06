# 肉球日常（GitHub Pages ＋ Supabase 版）

寵物鮮食適配分析與線上商店。網頁放在 GitHub Pages，資料存在 Supabase（免費的 PostgreSQL 資料庫，附會員登入）。

## 檔案

| 檔案 | 用途 |
|---|---|
| `index.html` | 整個網站（單一檔案） |
| `config.js` | 填入 Supabase 網址與 anon key |
| `supabase/schema.sql` | 資料表、權限規則、每月試吃包上限檢查 |
| `supabase/seed.sql` | 全部 125 項商品資料 |
| `supabase/functions/ai-chat/` | AI 顧問的後端（Edge Function，選用） |
| `.nojekyll` | 讓 GitHub Pages 原樣提供檔案 |

## 部署步驟

1. **建立資料庫**：到 supabase.com 新增專案（免費方案即可）。
2. **建立資料表**：Supabase 後台 → SQL Editor，依序貼上並執行 `supabase/schema.sql`、`supabase/seed.sql`。兩份都可以重複執行。
3. **設定登入**：Authentication → Sign In / Providers → Email 保持開啟。測試時可先關閉「Confirm email」，註冊後立刻登入；正式營運建議開啟。Authentication → URL Configuration 的 Site URL 填你的 GitHub Pages 網址。
4. **填入連線資料**：Project Settings → API，把 Project URL 和 `anon public` key 貼進 `config.js`。**不要使用 `service_role` key。**
5. **上傳到 GitHub**：新增 repository，把 `index.html`、`config.js`、`.nojekyll`、`supabase/` 上傳。Settings → Pages → Deploy from a branch → `main` / `/ (root)`，幾分鐘後網站上線。
6. **設定賣家**：先在網站上用你的 Email 註冊並登入一次，再到 SQL Editor 執行（換成你的 Email）：

   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'you@example.com';
   ```

   重新登入後就會看到賣家後台：全部訂單、改訂單狀態、改價格與庫存、上傳商品圖、新增商品。

`config.js` 沒填或還是範例值時，網站會退回「只存在這個瀏覽器」的示範模式。

## 賣家後台：ABC 商品分析

後台「ABC 商品分析」區塊會依訂單資料自動分級，**不用手動更新**：

- 後台約每 8 秒同步一次訂單；有新訂單、改庫存、改商品狀態或調整條件時，A／B／C 與柏拉圖會立刻重算（右上角顯示最後更新時間）。
- 分級方式：商品依營收（或銷量）由高到低排列，累計占比**未達 80% 前**的是 **A（主力）**，到 95% 為 **B**，其餘為 **C**。兩個門檻可以在畫面上改。
- 可切換「依營收／依銷量」、期間（全部／近 30 天／近 7 天），也能選擇是否排除「待付款」訂單（預設排除）。
- 每項商品附庫存與建議，例如 A 類庫存偏低會提示優先補貨；另可匯出 CSV。
- 沒有銷售的上架商品不列入分級，只顯示件數。

## AI 顧問（顧客端）

網頁右下角的「🐾 AI 顧問」讓顧客用聊天的方式描述毛孩情況，顧問會追問、推薦商品（附「加入」「詳情」按鈕）。顧客也能按「帶入分析區資料」，把「毛孩適配分析」表單目前的選項一起帶進對話。

有兩種模式，網頁會自動選擇：

| 模式 | 條件 | 說明 |
|---|---|---|
| **AI 模式（Claude）** | 已部署 `ai-chat` 函式 | 真正的 AI 對話，能理解自然語言、追問細節。 |
| **基本模式** | 沒部署、或 AI 連不上 | 網頁內建的規則對話：從句子抓出寵物種類、年齡、體重、困擾、過敏肉種、預算，再配對商品。不用任何額外設定。 |

### 啟用 AI 模式

API key 不能放在網頁裡（任何人都看得到），所以要放在 Supabase 的 Secrets，由 Edge Function 代為呼叫：

1. 到 console.anthropic.com 建立 API key。
2. 安裝 [Supabase CLI](https://supabase.com/docs/guides/cli) 並登入、連結專案：`supabase login`、`supabase link --project-ref 你的專案代號`。
3. 設定 Secrets（`ALLOWED_ORIGIN` 填你的 GitHub Pages 網址，只允許自己的網站呼叫）：

   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxxx ALLOWED_ORIGIN=https://你的帳號.github.io
   ```

4. 部署函式：

   ```bash
   supabase functions deploy ai-chat --no-verify-jwt
   ```

5. 不用改 `config.js`：網址預設是 `<supabaseUrl>/functions/v1/ai-chat`。重新整理網站，聊天視窗標題下會顯示「AI 模式（Claude）」。

說明：

- 函式會即時讀取商品目錄（含你在後台調整的價格、下架、庫存），所以不會推薦已下架或缺貨的商品。
- 預設模型是 `claude-haiku-5-5`（便宜、快）；想換模型，設定 `ANTHROPIC_MODEL` 這個 secret。
- 每次呼叫都會花 API 費用。函式已限制：每個 IP 每分鐘 15 次、只帶最近 12 則訊息、回覆上限 700 tokens。這是基本防護；若網站流量變大，建議到 Anthropic 後台設定每月用量上限。
- AI 的回覆只是選購建議，不是醫療意見；對話中出現就醫警訊時，顧問會先請顧客找獸醫師。

## 資料存放

| 資料 | 位置 | 誰能看 |
|---|---|---|
| 商品 | `products` | 所有人可讀，賣家可改 |
| 商品價格／下架／庫存調整、商品圖片 | `docs`（catalog、productimgs） | 所有人可讀，賣家可寫 |
| 訂單 | `docs`（orders） | 會員只看得到自己的，賣家看全部 |
| 會員資料（暱稱、點數、毛孩資料） | `docs`（members） | 只有本人與賣家 |
| 評論、銷量 | `docs`（reviews、sales） | 所有人可讀，會員只能寫自己的 |
| 帳號與密碼 | Supabase Auth | 由 Supabase 加密保管，網站與資料表都碰不到密碼 |

## 會員每月試吃包

- 只有登入的會員能領，每月最多 2 份（貓、狗試吃包合計，以台北時間的日曆月計算）。
- 點選「領取試吃包」後，會直接開啟結帳視窗填寫運送資料，會自動帶入上次填的姓名、電話、地址。
- 額度在三個地方檢查：點選時、結帳送出時、資料庫寫入時（`guard_docs` 觸發器）。就算有人改網頁程式，資料庫也會擋下第 3 份。
- 試吃包單價沿用商品資料裡的價格（貓 $99、狗 $129），運費照一般規則計算。

## 注意事項

- **訂單金額由網頁送出。** 會員有技術的話，可以改動自己訂單裡的金額。正式營運建議改成由 Supabase Edge Function 計價與建立訂單；付款也要改接真正的金流（目前付款畫面只是示範）。
- **起始庫存是示範數字。** 商品的 `st0` 是我設定的假數字，請在賣家後台改成實際庫存。
- 網頁圖片以 JPEG 壓縮後存在資料庫，商品很多時請留意免費方案的 500 MB 容量。
- 免費方案的專案閒置一段時間會被暫停，需要在後台手動恢復。
