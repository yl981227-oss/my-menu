-- 2026-11-01  订单"已出票"事实字段
-- 目的：让"小票是否已经发出"成为数据库里的事实，而不是靠状态推断。
-- 兼容性：旧版 APK 无感——它用 select=* 拉订单，只读取自己认识的字段，多一个字段不影响。
-- 当前只由 admin.html 在"补打"时写入；下一版 APK 会把它作为原生轮询的取单条件。

alter table public.orders
  add column if not exists printed_at timestamptz,
  add column if not exists printed_by text;

-- 未出票订单的查询路径（future APK 轮询用）
create index if not exists orders_unprinted_idx
  on public.orders (id)
  where printed_at is null;

-- 回滚（如需要）：
-- drop index if exists public.orders_unprinted_idx;
-- alter table public.orders drop column if exists printed_by;
-- alter table public.orders drop column if exists printed_at;
