-- ============================================================
-- China Ideal · GOHAN & SUSHI BURGER 补录（2026-11-14）
-- 来源：店内菜单照片（红底 GOHAN / SUSHI BURGER 一页）
-- 用法：Supabase Dashboard → SQL Editor → 粘贴 → Run
--
-- 说明：
--   1) 顾客端 index.html 已内置这 8 道菜，不跑本 SQL 也能看到新栏目；
--      跑完之后，后台 admin.html 才能对它们改价 / 设售罄 / 隐藏。
--   2) 幂等：按 (shop_id=1, name) 去重，重复执行不会产生重复菜品。
--   3) 只影响 China Ideal（shop_id=1），不动 YA XING 的菜品与价格。
--   4) 显式生成 id（当前 dishes.id 未必是自增），不会与现有数据撞号。
-- ============================================================

insert into public.dishes
  (id, name, description, price, category, is_colacion, is_available, is_hidden, shop_id)
select b.maxid + row_number() over (order by v.orden),
       v.name, v.description, v.price,
       'cat-sushi-gohan-burger', false, true, false, 1
from (values
  -- GOHAN (con base de arroz o con base de lechuga si prefiere)
  (1, 'Gohan Pollo',
      'Base de arroz o lechuga si prefieres · Pollo, queso crema, sésamo, cebollín, palta', 7500),
  (2, 'Gohan Camarón & Salmón',
      'Base de arroz o lechuga si prefieres · Camarón, salmón, queso crema, palta', 8200),
  (3, 'Arma tu Gohan (4 ingredientes a elección)',
      'Base de arroz o lechuga si prefieres · Arma tu Gohan con 4 ingredientes a elección · Precio desde', 7800),
  -- SUSHI BURGER (hecha con arroz en forma de hamburguesa)
  (4, 'Sushi Burger Pollo',
      'Arroz en forma de hamburguesa · Pollo, palta, queso crema, cebollín', 7500),
  (5, 'Sushi Burger Carne',
      'Arroz en forma de hamburguesa · Carne, palta, queso crema, cebollín', 8200),
  (6, 'Sushi Burger Camarón',
      'Arroz en forma de hamburguesa · Camarón, palta, queso crema, cebollín', 8500),
  (7, 'Sushi Burger Salmón',
      'Arroz en forma de hamburguesa · Salmón, palta, queso crema, cebollín', 9200),
  (8, 'Sushi Burger Vegetariano',
      'Arroz en forma de hamburguesa · Champiñón, palta, queso crema, cebollín', 7500)
) as v(orden, name, description, price)
cross join (select coalesce(max(id), 0) as maxid from public.dishes) b
where not exists (
  select 1 from public.dishes d
  where d.shop_id = 1
    and lower(trim(d.name)) = lower(trim(v.name))
);

-- 验证：应返回 8 行
-- select name, price, category from public.dishes
--  where shop_id = 1 and category = 'cat-sushi-gohan-burger'
--  order by name;
