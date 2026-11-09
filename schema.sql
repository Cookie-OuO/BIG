-- 肉球日常 資料庫結構（Supabase / PostgreSQL）
-- 在 Supabase 後台「SQL Editor」貼上整份並執行一次即可，可重複執行。

-- ========== 資料表 ==========
-- docs：訂單、會員資料、評論、庫存銷量、商品設定與圖片（每筆是一份 JSON 文件）
create table if not exists public.docs (
  path       text primary key,
  coll       text not null,
  id         text not null,
  data       jsonb not null default '{}'::jsonb,
  uid        uuid,
  updated_at timestamptz not null default now(),
  constraint docs_path_chk check (path = coll || '/' || id)
);
create index if not exists docs_coll_idx on public.docs (coll);

-- products：全部商品資料（由 seed.sql 匯入）
create table if not exists public.products (
  id   int primary key,
  data jsonb not null
);

-- admins：賣家（可看全部訂單、改商品與庫存）。用 SQL 手動加入，見 README。
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

-- ai_usage：AI 營養師每人每日提問次數（只有 Edge Function 用 service role 讀寫，網頁無法存取）
create table if not exists public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day     date not null,
  n       int  not null default 0,
  primary key (user_id, day)
);
alter table public.ai_usage enable row level security;

-- ========== 權限判斷 ==========
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;

-- ========== 寫入檢查 ==========
-- 1. 每位會員每個月（台北時間）試吃包最多 2 份，資料庫端也會擋。
-- 2. 銷量資料只接受 0 以上的數字，避免有人用負數灌高庫存。
create or replace function public.guard_docs() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if tg_op = 'INSERT' then new.uid := auth.uid(); end if;
  new.updated_at := now();
  if public.is_admin() then return new; end if;

  if new.coll = 'orders' then
    select coalesce(sum((i->>'q')::int), 0) into n
    from jsonb_array_elements(coalesce(new.data->'list', '[]'::jsonb)) o,
         jsonb_array_elements(coalesce(o->'items', '[]'::jsonb)) i
    where (i->>'id')::int in (
            select p.id from public.products p where (p.data->>'trial')::int = 1)
      and date_trunc('month', to_timestamp(((o->>'ts')::bigint) / 1000.0) at time zone 'Asia/Taipei')
        = date_trunc('month', now() at time zone 'Asia/Taipei');
    if n > 2 then
      raise exception '每月試吃包最多 2 份' using errcode = 'P0001';
    end if;
  end if;

  if new.coll = 'sales' and exists (
       select 1 from jsonb_each(coalesce(new.data->'q', '{}'::jsonb)) e
       where jsonb_typeof(e.value) <> 'number' or (e.value::text)::numeric < 0) then
    raise exception '銷量必須是 0 以上的數字' using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists docs_guard on public.docs;
create trigger docs_guard before insert or update on public.docs
  for each row execute function public.guard_docs();

-- ========== 列級安全（RLS）==========
alter table public.docs     enable row level security;
alter table public.products enable row level security;
alter table public.admins   enable row level security;

-- docs 讀取：賣家看全部；評論、銷量、商品設定、商品圖片公開；其餘只能讀自己的
drop policy if exists docs_select on public.docs;
create policy docs_select on public.docs for select to anon, authenticated
  using (public.is_admin()
         or coll in ('reviews', 'sales', 'catalog', 'productimgs')
         or id = auth.uid()::text);

-- docs 寫入：賣家全部可寫；會員只能寫「以自己 id 為名」的訂單、會員資料、評論、銷量
drop policy if exists docs_insert on public.docs;
create policy docs_insert on public.docs for insert to authenticated
  with check (public.is_admin()
              or (coll in ('orders', 'members', 'reviews', 'sales') and id = auth.uid()::text));

drop policy if exists docs_update on public.docs;
create policy docs_update on public.docs for update to authenticated
  using (public.is_admin()
         or (coll in ('orders', 'members', 'reviews', 'sales') and id = auth.uid()::text))
  with check (public.is_admin()
              or (coll in ('orders', 'members', 'reviews', 'sales') and id = auth.uid()::text));

drop policy if exists docs_delete on public.docs;
create policy docs_delete on public.docs for delete to authenticated
  using (public.is_admin());

-- products：所有人可讀，只有賣家可改
drop policy if exists products_select on public.products;
create policy products_select on public.products for select to anon, authenticated using (true);
drop policy if exists products_write on public.products;
create policy products_write on public.products for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- admins：登入者只能看到自己是不是賣家；不開放從網頁寫入
drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select to authenticated using (user_id = auth.uid());

-- ========== 資料表權限 ==========
grant select on public.docs, public.products to anon, authenticated;
grant insert, update, delete on public.docs, public.products to authenticated;
grant select on public.admins to authenticated;
