// 把下面兩個值換成你的 Supabase 專案資料（Project Settings → API）。
// anon public key 本來就設計成可公開，安全性由 schema.sql 的權限規則控制。
// 絕對不要把 service_role key 放在這裡。
window.MEOW_CONFIG = {
  supabaseUrl: "https://YOUR-PROJECT.supabase.co",
  supabaseKey: "YOUR-ANON-PUBLIC-KEY",
  // AI 顧問：部署 supabase/functions/ai-chat 之後，網址預設就是
  //   <supabaseUrl>/functions/v1/ai-chat ，不用填。沒部署時會自動改用內建的基本模式。
  // 要指定別的網址才填：
  aiUrl: ""
};
