-- ============================================================
-- 新店一键复制菜单模板（DragonOro · 2026-11-14）
-- 目的：分类共用 + 菜品内容共用为"模板"，价格每店独立。
-- 开一家新的中餐 + 寿司店时，不用再手写上百行 INSERT。
--
-- 用法：
--   1) 先在 shops 表建好新店记录
--   2) 把下面 'NUEVO_SLUG' 改成新店实际 slug
--   3) Supabase Dashboard → SQL Editor → Run
--   4) 让店主登录 admin.html 逐项核价 / 隐藏不卖的菜
--
-- 边界：
--   - 分类：直接沿用模板店的 category（前端分类本就是全店共用常量）
--   - 菜品内容：name + description 复制一份，之后各店各改各的，互不影响
--   - 价格：复制来的只是"起始默认值"，上线前必须逐项复核！
--   - 幂等：按 (shop_id, name) 去重，重复执行不会产生重复菜品
--   - slug 写错时查不到店，本脚本不插入任何数据（静默失败，安全）
-- ============================================================

insert into public.dishes
  (id, name, description, price, category, is_colacion, is_available, is_hidden, shop_id)
select b.maxid + row_number() over (order by d.id),
       d.name, d.description,
       d.price,                        -- 起始默认价；整体调价可改成 round(d.price * 1.10)
       d.category, d.is_colacion,
       true, false, s.id
from public.dishes d
cross join (select id from public.shops where slug = 'NUEVO_SLUG') s
cross join (select coalesce(max(id), 0) as maxid from public.dishes) b
where d.shop_id = 1                   -- 模板店：China Ideal（中餐 + 寿司）
  and d.is_hidden is distinct from true
  and not exists (
    select 1 from public.dishes x
    where x.shop_id = s.id
      and lower(trim(x.name)) = lower(trim(d.name))
  );

-- 若新店还卖奶茶，再跑一遍并把 where 改成：
--   where d.shop_id = 3
--     and d.category in ('cat-milk-tea', 'cat-fruit-tea', 'cat-mt-premium')
-- （YA XING 的奶茶分类在 shop_id=3）

-- 验证：
-- select category, count(*) from public.dishes
--  where shop_id = (select id from public.shops where slug = 'NUEVO_SLUG')
--  group by category order by category;
