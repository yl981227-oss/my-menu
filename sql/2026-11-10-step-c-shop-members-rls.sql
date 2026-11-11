-- ============================================================
-- DragonOro 多租户改造 · 第 C 步：员工绑定 + RLS 收口
-- 日期：2026-11-10
-- 前置：第 A 步（2026-11-10-multi-tenant-shops.sql）已执行
-- 效果：
--   1. 新增 shop_members 表：员工账号 ↔ 店铺绑定
--   2. 现有所有员工账号自动归入 1 号店（China Ideal）
--   3. orders / dishes 开启 RLS：员工只能读写自己店的数据
--      （顾客端下单、查单不受影响：下单走 insert 策略，查单走 RPC）
-- ============================================================

-- 1. 店铺-员工绑定表 ------------------------------------------------
create table if not exists public.shop_members (
  shop_id     bigint not null references public.shops(id) on delete cascade,
  user_id     uuid   not null references auth.users(id)  on delete cascade,
  role        text   not null default 'owner',           -- owner / staff
  created_at  timestamptz not null default now(),
  primary key (shop_id, user_id)
);

alter table public.shop_members enable row level security;

-- 员工只能看到自己的绑定关系
drop policy if exists "members read own rows" on public.shop_members;
create policy "members read own rows"
  on public.shop_members for select
  using (user_id = auth.uid());

grant select on public.shop_members to authenticated;

-- 现有员工全部归入 1 号店（当前只有 China Ideal 的账号；
-- 以后每开一店，用同一句把新员工的 user_id 绑到对应 shop_id）
insert into public.shop_members (shop_id, user_id, role)
select 1, id, 'owner' from auth.users
on conflict do nothing;

-- 2. 店铺成员判断函数 -----------------------------------------------
create or replace function public.is_shop_member(p_shop_id bigint)
returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (
    select 1 from public.shop_members
    where shop_id = p_shop_id and user_id = auth.uid()
  );
$$;

-- 3. orders：员工只能读写自己店的订单 -------------------------------
alter table public.orders enable row level security;

drop policy if exists "staff reads own shop orders" on public.orders;
create policy "staff reads own shop orders"
  on public.orders for select
  using (public.is_shop_member(shop_id));

drop policy if exists "staff updates own shop orders" on public.orders;
create policy "staff updates own shop orders"
  on public.orders for update
  using (public.is_shop_member(shop_id))
  with check (public.is_shop_member(shop_id));

-- 说明：顾客端不受影响——
-- 下单：第 A 步的 "orders insertable for active shops" insert 策略放行
-- 查单：lookup_my_order RPC（security definer，不受 RLS 限制）

-- 4. dishes：员工只能写自己店的菜品 ---------------------------------
alter table public.dishes enable row level security;
-- （select 已由第 A 步 "dishes readable for active shops" 放行，顾客端不受影响）

drop policy if exists "staff inserts own shop dishes" on public.dishes;
create policy "staff inserts own shop dishes"
  on public.dishes for insert
  with check (public.is_shop_member(shop_id));

drop policy if exists "staff updates own shop dishes" on public.dishes;
create policy "staff updates own shop dishes"
  on public.dishes for update
  using (public.is_shop_member(shop_id))
  with check (public.is_shop_member(shop_id));

drop policy if exists "staff deletes own shop dishes" on public.dishes;
create policy "staff deletes own shop dishes"
  on public.dishes for delete
  using (public.is_shop_member(shop_id));

-- 5. 跑完验证 --------------------------------------------------------
-- select shop_id, user_id, role from public.shop_members;   -- 应看到 1 行，shop_id=1
-- select id, slug, name from public.shops;
