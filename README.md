# 肉球日常（GitHub Pages ＋ Supabase 版）

寵物鮮食適配分析與線上商店。網頁放在 GitHub Pages，資料存在 Supabase（免費的 PostgreSQL 資料庫，附會員登入）。

## 檔案

| 檔案 | 用途 |
|---|---|
| `index.html` | 整個網站（單一檔案） |
| `config.js` | 填入 Supabase 網址與 anon key |
| `supabase/schema.sql` | 資料表、權限規則、每月試吃包上限檢查 |
| `supabase/seed.sql` | 全部 125 項商品資料 |
| `supabase/functions/ai-chat/index.ts` | AI 營養師的後端（Edge Function），要使用 AI 對話才需要部署 |
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

## 賣家後台：ABC 分析

賣家後台有「ABC 分析」區塊，依訂單資料把商品分成三級，訂單、狀態、價格或庫存一有變動就會即時重算：

- **A 類**：累計貢獻到前 80% 的主力商品；**B 類**：累計到 95%；**C 類**：其餘與沒有銷售的商品。兩個百分比可以自行調整。
- 可切換依「營收」或「銷量」分析，也可選擇是否包含待付款訂單。
- 內容有各級摘要、柏拉圖（前 12 名）、完整排名表，以及補貨與促銷建議；A 類商品庫存偏低時會特別提醒。

## 顧客端：AI 營養師

登入的會員可以在網頁右下角開啟「AI 營養師」，用對話描述毛孩的情況，AI 會依店裡現有商品、價格和庫存推薦，並附上可直接加入購物車的商品卡片。已儲存的毛孩資料、分析頁填寫的內容和購物車也會一併提供給 AI 參考。

網頁不能直接放 Anthropic API 金鑰，所以這個版本透過 Supabase Edge Function 呼叫 AI。沒有部署時，AI 按鈕不會出現，其他功能不受影響。

1. 到 [console.anthropic.com](https://console.anthropic.com) 建立 API 金鑰。
2. 安裝 Supabase CLI 並登入後，在專案資料夾執行：

   ```bash
   supabase link --project-ref 你的專案代號
   supabase secrets set ANTHROPIC_API_KEY=你的金鑰
   supabase functions deploy ai-chat
   ```

3. 可選設定：`supabase secrets set AI_MODEL=模型名稱`（預設 `claude-sonnet-5-5`）、`AI_DAILY_LIMIT=30`（每位會員每天可提問的次數）。

函式只接受已登入的會員，並限制每人每天的提問次數與每次的輸入長度，避免金鑰被濫用而產生意外費用。`schema.sql` 內的 `ai_usage` 資料表用來記錄次數，網頁本身讀不到。API 用量由你的 Anthropic 帳號計費，請在 Anthropic 後台設定用量上限。

## 注意事項

- **訂單金額由網頁送出。** 會員有技術的話，可以改動自己訂單裡的金額。正式營運建議改成由 Supabase Edge Function 計價與建立訂單；付款也要改接真正的金流（目前付款畫面只是示範）。
- **起始庫存是示範數字。** 商品的 `st0` 是我設定的假數字，請在賣家後台改成實際庫存。
- 網頁圖片以 JPEG 壓縮後存在資料庫，商品很多時請留意免費方案的 500 MB 容量。
- 免費方案的專案閒置一段時間會被暫停，需要在後台手動恢復。
