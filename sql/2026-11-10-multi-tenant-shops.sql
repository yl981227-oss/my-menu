-- ============================================================
-- 多租户改造 · 第 A 步：数据底座
-- 日期：2026-11-10
-- 目的：让同一套系统服务多个商家（每家一店、一台打印机）。
-- 原则：所有新字段默认值 = 1（China Ideal），
--       跑完这个 SQL 后，现有页面 / App / 数据行为完全不变。
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴 → Run
-- ============================================================

-- 1. 商家（租户）表 ------------------------------------------------
create table if not exists public.shops (
  id            bigint generated always as identity primary key,
  slug          text not null unique,              -- 用于 ?shop=xxx 的短标识
  name          text not null,                     -- 店名（顾客端展示）
  tagline       text default '',                   -- 副标题，如 "Comida china · Sushi"
  logo_url      text default '',
  brand_color   text default '#E03131',            -- 主题色
  phone         text default '',
  address       text default '',
  printer_ip    text default '',                   -- 本店唯一打印机
  printer_port  int default 9100,
  is_active     boolean not null default true,     -- 停用后顾客端不可下单
  created_at    timestamptz not null default now()
);

-- China Ideal 固定为 1 号租户（显式指定 id，保证 default 1 指向它）
insert into public.shops (id, slug, name, tagline, phone, address, printer_ip)
values (1, 'china-ideal', 'China Ideal', 'Comida china · Sushi', '', '', '10.0.4.250')
on conflict (id) do nothing;

-- 2. 菜品 / 订单挂到门店 -------------------------------------------
alter table public.dishes add column if not exists shop_id bigint not null default 1;
alter table public.orders add column if not exists shop_id bigint not null default 1;

create index if not exists dishes_shop_idx on public.dishes (shop_id);
create index if not exists orders_shop_idx  on public.orders (shop_id, created_at desc);

-- 3. 行级安全（多客户后的隔离底线）---------------------------------
-- 注意：跑这段之前，请先在 Table Editor 里检查 dishes / orders 现有的
-- RLS 策略；下面只添加"按店隔离"的新策略，不删除旧策略。如果旧策略
-- 允许 anon 全表读写，需要在第 C 步时收紧——那是后续工作，这里先立柱子。

-- 顾客端：只能看到"营业中"店铺的菜品
drop policy if exists "dishes readable for active shops" on public.dishes;
create policy "dishes readable for active shops"
  on public.dishes for select
  using (shop_id in (select id from public.shops where is_active));

-- 顾客端：只能向"营业中"的店铺下单
drop policy if exists "orders insertable for active shops" on public.orders;
create policy "orders insertable for active shops"
  on public.orders for insert
  with check (shop_id in (select id from public.shops where is_active));

-- ⚠️ 遗留项（第 C 步处理）：
--  - orders 的 select / update 现有策略按 lookup_token 控制，需要确认是否
--    顺带限定了 shop_id，防止跨店读单。
--  - dishes 的 insert / update / delete 策略需要收紧为"商家本人"，目前若
--    anon 可写，等于任何客户能改别人的菜单——上收银台登录时一并处理。

-- 4. 完成后验证 ----------------------------------------------------
-- select id, slug, name from public.shops;
-- select shop_id, count(*) from public.dishes group by 1;
-- select shop_id, count(*) from public.orders group by 1;
