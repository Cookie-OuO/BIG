// 把下面兩個值換成你的 Supabase 專案資料（Project Settings → API）。
// anon public key 本來就設計成可公開，安全性由 schema.sql 的權限規則控制。
// 絕對不要把 service_role key 放在這裡。
window.MEOW_CONFIG = {
  supabaseUrl: "https://fibkffmatrmdmnmxycvc.supabase.co",
  supabaseKey: "sb_publishable_ekIht0eiFXqRCzu6Mydcxw_Lk8umQY4"
};
```[cite: 2]

> ⚠️ **安全提醒：** 由於你的 Secret Key (`sb_secret_...`) 已經寫入代碼並出現在截圖中[cite: 2]，請務必回到 Supabase 後台的 **Secret keys** 區塊將該金鑰 **刪除（Delete/Revoke）**，以免資料庫面臨外洩與破壞風險。
