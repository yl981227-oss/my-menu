-- ============================================================
-- YA XING · GOHAN & SUSHI BURGER 归位到共用栏目（2026-11-14）
-- 背景：分类全店共用（cat-sushi-gohan-burger），价格与菜品内容仍各店独立。
-- 作用：把 YA XING 已有的 6 道同类菜从 Promos / Nuevos 挪进新栏目。
-- 边界：不改任何菜名、描述、价格；Combo 1 (Gohan + Bebida) 是套餐，保留在 Promos。
-- 幂等：重复执行结果一致，不会产生重复数据。
-- 用法：Supabase Dashboard → SQL Editor → 粘贴 → Run
-- ============================================================

update public.dishes
   set category = 'cat-sushi-gohan-burger'
 where shop_id = (select id from public.shops where slug = 'ya-xing')
   and (
     lower(trim(name)) = 'gohan'
     or name ilike 'Sushi Burger %'
   )
   and category is distinct from 'cat-sushi-gohan-burger';

-- 验证：应返回 6 行，价格仍为 7900 / 7300 / 7900 / 8300 / 8800 / 7300
-- select name, price, category from public.dishes
--  where shop_id = (select id from public.shops where slug = 'ya-xing')
--    and category = 'cat-sushi-gohan-burger'
--  order by name;
