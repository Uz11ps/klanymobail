-- Klany: базовая схема (MVP) под ТЗ.
-- Применять в Supabase SQL Editor. Далее можно разбить на миграции.

create extension if not exists "pgcrypto";

-- ===== Helpers =====
create or replace function public.current_uid()
returns uuid
language sql
stable
as $$
  select auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  )
$$;

-- ===== Core entities =====
create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  family_code text not null unique,
  clan_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  family_id uuid references public.families(id) on delete set null,
  role text not null check (role in ('parent', 'admin')),
  display_name text,
  created_at timestamptz not null default now()
);

-- Child accounts are passwordless in MVP: access is granted by parent approval + device binding.
create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  family_id uuid not null references public.families(id) on delete cascade,
  phone text unique,
  first_name text,
  last_name text,
  display_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Passwordless child access requests (child device asks, parent approves/rejects).
create table if not exists public.child_access_requests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_first_name text not null,
  child_last_name text not null,
  device_id text not null,
  device_key text not null,
  status text not null check (status in ('pending', 'approved', 'rejected')) default 'pending',
  approved_child_id uuid references public.children(id) on delete set null,
  rejection_reason text,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null
);

create index if not exists idx_child_access_requests_family_status
  on public.child_access_requests(family_id, status, created_at desc);

create index if not exists idx_child_access_requests_device
  on public.child_access_requests(device_id, created_at desc);

-- Active child session is bound to the approved device.
create table if not exists public.child_device_bindings (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  device_id text not null,
  device_key text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null
);

create unique index if not exists ux_child_device_bindings_device_active
  on public.child_device_bindings(device_id, device_key)
  where is_active = true;

create table if not exists public.quests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  assigned_child_id uuid references public.children(id) on delete set null,
  title text not null,
  description text,
  tags text[] not null default '{}',
  reward_amount int not null default 0,
  status text not null check (status in ('draft', 'active', 'done', 'rejected')) default 'draft',
  evidence_required boolean not null default false,
  due_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.quest_evidence (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  storage_path text not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

-- ===== Wallet / currency =====
create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null unique references public.children(id) on delete cascade,
  balance int not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  amount int not null,
  tx_type text not null check (tx_type in ('earn', 'spend', 'adjust')),
  quest_id uuid references public.quests(id) on delete set null,
  note text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

-- ===== Shop =====
create table if not exists public.shop_products (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  description text,
  price int not null default 0,
  image_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.shop_purchases (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.shop_products(id) on delete restrict,
  child_id uuid not null references public.children(id) on delete restrict,
  quantity int not null default 1,
  total_price int not null default 0,
  status text not null check (status in ('requested', 'approved', 'rejected', 'delivered')) default 'requested',
  created_at timestamptz not null default now(),
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz
);

-- ===== Notifications (in-app log) =====
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  to_user_id uuid references auth.users(id) on delete set null,
  to_child_id uuid references public.children(id) on delete set null,
  n_type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'new',
  created_at timestamptz not null default now()
);

-- ===== RLS =====
alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.children enable row level security;
alter table public.quests enable row level security;
alter table public.quest_evidence enable row level security;
alter table public.wallets enable row level security;
alter table public.transactions enable row level security;
alter table public.shop_products enable row level security;
alter table public.shop_purchases enable row level security;
alter table public.notifications enable row level security;
alter table public.child_access_requests enable row level security;
alter table public.child_device_bindings enable row level security;

-- Families: owner or admin.
drop policy if exists "families_select" on public.families;
create policy "families_select"
on public.families for select
using (public.is_admin() or owner_user_id = auth.uid());

drop policy if exists "families_insert" on public.families;
create policy "families_insert"
on public.families for insert
with check (auth.uid() = owner_user_id);

drop policy if exists "families_update" on public.families;
create policy "families_update"
on public.families for update
using (public.is_admin() or owner_user_id = auth.uid())
with check (public.is_admin() or owner_user_id = auth.uid());

-- Profiles: self or admin. Parents can read profiles in their family for UI.
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select"
on public.profiles for select
using (
  public.is_admin()
  or user_id = auth.uid()
  or (
    exists (
      select 1
      from public.profiles me
      where me.user_id = auth.uid()
        and me.role = 'parent'
        and me.family_id is not null
        and me.family_id = profiles.family_id
    )
  )
);

drop policy if exists "profiles_upsert_self" on public.profiles;
create policy "profiles_upsert_self"
on public.profiles for insert
with check (user_id = auth.uid());

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
on public.profiles for update
using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());

-- Children: parents in same family can manage; child can read self.
drop policy if exists "children_select" on public.children;
create policy "children_select"
on public.children for select
using (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = children.family_id
  )
);

drop policy if exists "children_insert_parent" on public.children;
create policy "children_insert_parent"
on public.children for insert
with check (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = children.family_id
  )
);

drop policy if exists "children_update_parent" on public.children;
create policy "children_update_parent"
on public.children for update
using (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = children.family_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = children.family_id
  )
);

-- Quests: parents manage within family; child reads own assigned; child can mark done.
drop policy if exists "quests_select" on public.quests;
create policy "quests_select"
on public.quests for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = quests.family_id
  )
  or exists (
    select 1
    from public.children c
    where c.user_id = auth.uid()
      and c.id = quests.assigned_child_id
  )
);

drop policy if exists "quests_insert_parent" on public.quests;
create policy "quests_insert_parent"
on public.quests for insert
with check (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = quests.family_id
  )
);

drop policy if exists "quests_update_parent_or_child_done" on public.quests;
create policy "quests_update_parent_or_child_done"
on public.quests for update
using (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = quests.family_id
  )
  or exists (
    select 1
    from public.children c
    where c.user_id = auth.uid()
      and c.id = quests.assigned_child_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = quests.family_id
  )
  or (
    exists (
      select 1
      from public.children c
      where c.user_id = auth.uid()
        and c.id = quests.assigned_child_id
    )
    and quests.status in ('done')
  )
);

-- Evidence: parent can read via quest; child adds evidence for own quest.
drop policy if exists "quest_evidence_select" on public.quest_evidence;
create policy "quest_evidence_select"
on public.quest_evidence for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.quests q
    where q.id = quest_evidence.quest_id
      and (
        exists (
          select 1 from public.profiles p
          where p.user_id = auth.uid()
            and p.role = 'parent'
            and p.family_id = q.family_id
        )
        or exists (
          select 1 from public.children c
          where c.user_id = auth.uid()
            and c.id = q.assigned_child_id
        )
      )
  )
);

drop policy if exists "quest_evidence_insert_child" on public.quest_evidence;
create policy "quest_evidence_insert_child"
on public.quest_evidence for insert
with check (
  public.is_admin()
  or exists (
    select 1
    from public.quests q
    join public.children c on c.id = q.assigned_child_id
    where q.id = quest_evidence.quest_id
      and c.user_id = auth.uid()
  )
);

-- Wallets + transactions: readable by parent in family or child owner; writes by parent/admin.
drop policy if exists "wallets_select" on public.wallets;
create policy "wallets_select"
on public.wallets for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    where c.user_id = auth.uid()
      and c.id = wallets.child_id
  )
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and c.id = wallets.child_id
  )
);

drop policy if exists "wallets_insert_parent" on public.wallets;
create policy "wallets_insert_parent"
on public.wallets for insert
with check (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and c.id = wallets.child_id
  )
);

drop policy if exists "wallets_update_parent" on public.wallets;
create policy "wallets_update_parent"
on public.wallets for update
using (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and c.id = wallets.child_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and c.id = wallets.child_id
  )
);

drop policy if exists "transactions_select" on public.transactions;
create policy "transactions_select"
on public.transactions for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.wallets w
    join public.children c on c.id = w.child_id
    where w.id = transactions.wallet_id
      and (
        c.user_id = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.role = 'parent'
            and p.family_id = c.family_id
        )
      )
  )
);

drop policy if exists "transactions_insert_parent" on public.transactions;
create policy "transactions_insert_parent"
on public.transactions for insert
with check (
  public.is_admin()
  or exists (
    select 1
    from public.wallets w
    join public.children c on c.id = w.child_id
    join public.profiles p on p.family_id = c.family_id
    where w.id = transactions.wallet_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
);

-- Shop: readable by family members; writes by parent/admin.
drop policy if exists "shop_products_select" on public.shop_products;
create policy "shop_products_select"
on public.shop_products for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.family_id = shop_products.family_id
  )
  or exists (
    select 1
    from public.children c
    where c.user_id = auth.uid()
      and c.family_id = shop_products.family_id
  )
);

drop policy if exists "shop_products_write_parent" on public.shop_products;
create policy "shop_products_write_parent"
on public.shop_products for all
using (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = shop_products.family_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = shop_products.family_id
  )
);

drop policy if exists "shop_purchases_select" on public.shop_purchases;
create policy "shop_purchases_select"
on public.shop_purchases for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    where c.id = shop_purchases.child_id
      and c.user_id = auth.uid()
  )
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = shop_purchases.child_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
);

drop policy if exists "shop_purchases_insert_child" on public.shop_purchases;
create policy "shop_purchases_insert_child"
on public.shop_purchases for insert
with check (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    where c.id = shop_purchases.child_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "shop_purchases_update_parent" on public.shop_purchases;
create policy "shop_purchases_update_parent"
on public.shop_purchases for update
using (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = shop_purchases.child_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = shop_purchases.child_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
);

-- Notifications: readable by target or parent in family; insert by parent/admin.
drop policy if exists "notifications_select" on public.notifications;
create policy "notifications_select"
on public.notifications for select
using (
  public.is_admin()
  or to_user_id = auth.uid()
  or exists (
    select 1
    from public.children c
    where c.user_id = auth.uid()
      and c.id = notifications.to_child_id
  )
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = notifications.family_id
  )
);

drop policy if exists "notifications_insert_parent" on public.notifications;
create policy "notifications_insert_parent"
on public.notifications for insert
with check (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = notifications.family_id
  )
);

-- ===== Passwordless child access: RLS =====
drop policy if exists "child_access_requests_parent_select" on public.child_access_requests;
create policy "child_access_requests_parent_select"
on public.child_access_requests for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = child_access_requests.family_id
  )
);

drop policy if exists "child_access_requests_parent_update" on public.child_access_requests;
create policy "child_access_requests_parent_update"
on public.child_access_requests for update
using (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = child_access_requests.family_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = child_access_requests.family_id
  )
);

drop policy if exists "child_device_bindings_parent_select" on public.child_device_bindings;
create policy "child_device_bindings_parent_select"
on public.child_device_bindings for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = child_device_bindings.child_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
);

drop policy if exists "child_device_bindings_parent_write" on public.child_device_bindings;
create policy "child_device_bindings_parent_write"
on public.child_device_bindings for all
using (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = child_device_bindings.child_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = child_device_bindings.child_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
);

-- ===== Passwordless child access: RPC =====
create or replace function public.generate_family_code()
returns text
language plpgsql
as $$
declare
  result text;
begin
  result := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4))
    || '-' ||
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4));
  return result;
end;
$$;

create or replace function public.child_submit_access_request(
  p_family_code text,
  p_child_first_name text,
  p_child_last_name text,
  p_device_id text,
  p_device_key text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_family_id uuid;
  v_request_id uuid;
begin
  select f.id into v_family_id
  from public.families f
  where upper(f.family_code) = upper(trim(p_family_code))
  limit 1;

  if v_family_id is null then
    raise exception 'Family ID not found';
  end if;

  insert into public.child_access_requests(
    family_id,
    child_first_name,
    child_last_name,
    device_id,
    device_key,
    status
  ) values (
    v_family_id,
    trim(p_child_first_name),
    trim(p_child_last_name),
    trim(p_device_id),
    trim(p_device_key),
    'pending'
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;

create or replace function public.child_poll_access_request(
  p_request_id uuid,
  p_device_id text,
  p_device_key text
)
returns table(
  request_id uuid,
  status text,
  family_id uuid,
  approved_child_id uuid,
  child_display_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    r.id as request_id,
    r.status,
    r.family_id,
    r.approved_child_id,
    c.display_name as child_display_name
  from public.child_access_requests r
  left join public.children c on c.id = r.approved_child_id
  where r.id = p_request_id
    and r.device_id = trim(p_device_id)
    and r.device_key = trim(p_device_key)
  limit 1;
end;
$$;

create or replace function public.child_restore_session(
  p_device_id text,
  p_device_key text
)
returns table(
  child_id uuid,
  family_id uuid,
  child_display_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    c.id as child_id,
    c.family_id,
    c.display_name as child_display_name
  from public.child_device_bindings b
  join public.children c on c.id = b.child_id
  where b.device_id = trim(p_device_id)
    and b.device_key = trim(p_device_key)
    and b.is_active = true
    and c.is_active = true
  limit 1;
end;
$$;

create or replace function public.parent_get_family_context()
returns table(
  family_id uuid,
  family_code text,
  clan_name text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_family_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  select p.family_id into v_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_family_id is null then
    insert into public.families(owner_user_id, family_code)
    values (v_user_id, public.generate_family_code())
    returning id into v_family_id;

    insert into public.profiles(user_id, family_id, role)
    values (v_user_id, v_family_id, 'parent')
    on conflict (user_id) do update
      set family_id = excluded.family_id,
          role = excluded.role;
  end if;

  return query
  select f.id, f.family_code, f.clan_name
  from public.families f
  where f.id = v_family_id
  limit 1;
end;
$$;

create or replace function public.parent_approve_child_request(
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_parent_family_id uuid;
  v_request record;
  v_child_id uuid;
  v_display_name text;
  v_plan_code text;
  v_max_children int;
  v_children_count int;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_parent_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_parent_family_id is null then
    raise exception 'Parent family not found';
  end if;

  select * into v_request
  from public.child_access_requests r
  where r.id = p_request_id
    and r.status = 'pending'
  limit 1;

  if v_request.id is null then
    raise exception 'Request not found';
  end if;

  if v_request.family_id <> v_parent_family_id then
    raise exception 'Access denied';
  end if;

  v_plan_code := public.family_active_plan_code(v_parent_family_id);
  select sp.max_children into v_max_children
  from public.subscription_plans sp
  where sp.code = v_plan_code;

  select count(*) into v_children_count
  from public.children c
  where c.family_id = v_parent_family_id
    and c.is_active = true;

  if v_children_count >= coalesce(v_max_children, 2) then
    raise exception 'Children limit reached for current plan';
  end if;

  v_display_name := trim(v_request.child_first_name) || ' ' || trim(v_request.child_last_name);

  insert into public.children(
    family_id,
    first_name,
    last_name,
    display_name,
    is_active
  ) values (
    v_parent_family_id,
    trim(v_request.child_first_name),
    trim(v_request.child_last_name),
    trim(v_display_name),
    true
  )
  returning id into v_child_id;

  insert into public.wallets(child_id, balance)
  values (v_child_id, 0)
  on conflict (child_id) do nothing;

  update public.child_device_bindings
  set is_active = false,
      revoked_at = now(),
      revoked_by = v_user_id
  where device_id = v_request.device_id
    and device_key = v_request.device_key
    and is_active = true;

  insert into public.child_device_bindings(
    child_id, device_id, device_key, is_active
  ) values (
    v_child_id, v_request.device_id, v_request.device_key, true
  );

  update public.child_access_requests
  set status = 'approved',
      approved_child_id = v_child_id,
      decided_at = now(),
      decided_by = v_user_id
  where id = p_request_id;

  return v_child_id;
end;
$$;

create or replace function public.parent_create_shop_product(
  p_title text,
  p_description text,
  p_price int,
  p_image_path text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_family_id uuid;
  v_plan_code text;
  v_max_products int;
  v_active_products int;
  v_product_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_family_id is null then
    raise exception 'Family not found';
  end if;

  v_plan_code := public.family_active_plan_code(v_family_id);
  select sp.max_active_products into v_max_products
  from public.subscription_plans sp
  where sp.code = v_plan_code;

  select count(*) into v_active_products
  from public.shop_products sp
  where sp.family_id = v_family_id
    and sp.is_active = true;

  if v_active_products >= coalesce(v_max_products, 1) then
    raise exception 'Active product limit reached for current plan';
  end if;

  insert into public.shop_products(family_id, title, description, price, image_path, is_active)
  values (v_family_id, trim(p_title), p_description, greatest(p_price, 0), p_image_path, true)
  returning id into v_product_id;

  return v_product_id;
end;
$$;

create or replace function public.parent_reject_child_request(
  p_request_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_parent_family_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_parent_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_parent_family_id is null then
    raise exception 'Parent family not found';
  end if;

  update public.child_access_requests r
  set status = 'rejected',
      rejection_reason = p_reason,
      decided_at = now(),
      decided_by = v_user_id
  where r.id = p_request_id
    and r.family_id = v_parent_family_id
    and r.status = 'pending';
end;
$$;

create or replace function public.parent_revoke_child_devices(
  p_child_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  if not exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = p_child_id
      and p.user_id = v_user_id
      and p.role in ('parent', 'admin')
  ) then
    raise exception 'Access denied';
  end if;

  update public.child_device_bindings
  set is_active = false,
      revoked_at = now(),
      revoked_by = v_user_id
  where child_id = p_child_id
    and is_active = true;
end;
$$;

-- ===== Extended domain for full TZ =====
create table if not exists public.subscription_plans (
  code text primary key,
  title text not null,
  max_children int not null,
  max_active_quests int not null,
  max_active_products int not null,
  created_at timestamptz not null default now()
);

insert into public.subscription_plans(code, title, max_children, max_active_quests, max_active_products)
values
  ('basic', 'Базовый', 2, 10, 1),
  ('premium', 'Премиум', 10, 200, 10)
on conflict (code) do nothing;

create table if not exists public.family_subscriptions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  plan_code text not null references public.subscription_plans(code),
  status text not null check (status in ('active', 'expired', 'cancelled')) default 'active',
  started_at timestamptz not null default now(),
  expires_at timestamptz,
  auto_renew boolean not null default false,
  source text not null default 'manual',
  created_at timestamptz not null default now()
);

create index if not exists idx_family_subscriptions_family_created
  on public.family_subscriptions(family_id, created_at desc);

create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  plan_code text not null references public.subscription_plans(code),
  duration_days int not null default 30,
  max_uses int not null default 1,
  used_count int not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.promo_redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_id uuid not null references public.promo_codes(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  redeemed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.payment_orders (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  provider text not null default 'yookassa',
  amount_rub numeric(12,2) not null,
  status text not null check (status in ('pending', 'paid', 'failed', 'cancelled')) default 'pending',
  plan_code text references public.subscription_plans(code),
  provider_payment_id text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create table if not exists public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_type text not null,
  event_id text,
  payload jsonb not null default '{}'::jsonb,
  processed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  child_id uuid references public.children(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  push_token text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notification_devices_user
  on public.notification_devices(user_id, is_active);

create index if not exists idx_notification_devices_child
  on public.notification_devices(child_id, is_active);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_child_id uuid references public.children(id) on delete set null,
  action text not null,
  target_type text,
  target_id text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.telegram_links (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  telegram_chat_id text not null unique,
  telegram_username text,
  created_at timestamptz not null default now()
);

create table if not exists public.quest_assignees (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  status text not null check (status in ('assigned', 'in_progress', 'submitted', 'approved', 'rejected', 'expired')) default 'assigned',
  submitted_at timestamptz,
  approved_at timestamptz,
  reviewer_user_id uuid references auth.users(id) on delete set null,
  comment text,
  reward_amount int not null default 0,
  created_at timestamptz not null default now(),
  unique (quest_id, child_id)
);

create table if not exists public.quest_comments (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  child_id uuid references public.children(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.family_parent_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  email text not null,
  token text not null unique,
  status text not null check (status in ('pending', 'accepted', 'expired', 'cancelled')) default 'pending',
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz
);

alter table public.quests
  add column if not exists quest_type text not null default 'one_time',
  add column if not exists recurring_rule text,
  add column if not exists started_at timestamptz,
  add column if not exists closed_at timestamptz;

alter table public.shop_purchases
  add column if not exists frozen_amount int not null default 0;

alter table public.subscription_plans enable row level security;
alter table public.family_subscriptions enable row level security;
alter table public.promo_codes enable row level security;
alter table public.promo_redemptions enable row level security;
alter table public.payment_orders enable row level security;
alter table public.payment_webhook_events enable row level security;
alter table public.notification_devices enable row level security;
alter table public.audit_logs enable row level security;
alter table public.quest_assignees enable row level security;
alter table public.quest_comments enable row level security;
alter table public.family_parent_invites enable row level security;
alter table public.telegram_links enable row level security;

drop policy if exists "subscription_plans_read_all" on public.subscription_plans;
create policy "subscription_plans_read_all"
on public.subscription_plans for select
using (true);

drop policy if exists "family_subscriptions_select" on public.family_subscriptions;
create policy "family_subscriptions_select"
on public.family_subscriptions for select
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.family_id = family_subscriptions.family_id
  )
  or exists (
    select 1 from public.children c
    where c.user_id = auth.uid()
      and c.family_id = family_subscriptions.family_id
  )
);

drop policy if exists "family_subscriptions_write_parent" on public.family_subscriptions;
create policy "family_subscriptions_write_parent"
on public.family_subscriptions for all
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = family_subscriptions.family_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = family_subscriptions.family_id
  )
);

drop policy if exists "promo_codes_admin_rw" on public.promo_codes;
create policy "promo_codes_admin_rw"
on public.promo_codes for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "promo_redemptions_select" on public.promo_redemptions;
create policy "promo_redemptions_select"
on public.promo_redemptions for select
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.family_id = promo_redemptions.family_id
  )
);

drop policy if exists "promo_redemptions_insert_parent" on public.promo_redemptions;
create policy "promo_redemptions_insert_parent"
on public.promo_redemptions for insert
with check (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = promo_redemptions.family_id
  )
);

drop policy if exists "payment_orders_select" on public.payment_orders;
create policy "payment_orders_select"
on public.payment_orders for select
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.family_id = payment_orders.family_id
  )
);

drop policy if exists "payment_orders_write_parent" on public.payment_orders;
create policy "payment_orders_write_parent"
on public.payment_orders for all
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = payment_orders.family_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = payment_orders.family_id
  )
);

drop policy if exists "webhook_events_admin_only" on public.payment_webhook_events;
create policy "webhook_events_admin_only"
on public.payment_webhook_events for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_devices_rw" on public.notification_devices;
create policy "notification_devices_rw"
on public.notification_devices for all
using (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1 from public.children c
    where c.id = notification_devices.child_id
      and c.user_id = auth.uid()
  )
)
with check (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1 from public.children c
    where c.id = notification_devices.child_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "audit_logs_select" on public.audit_logs;
create policy "audit_logs_select"
on public.audit_logs for select
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.family_id = audit_logs.family_id
  )
);

drop policy if exists "audit_logs_insert_parent" on public.audit_logs;
create policy "audit_logs_insert_parent"
on public.audit_logs for insert
with check (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.family_id = audit_logs.family_id
  )
);

drop policy if exists "telegram_links_parent_rw" on public.telegram_links;
create policy "telegram_links_parent_rw"
on public.telegram_links for all
using (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = telegram_links.family_id
  )
)
with check (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = telegram_links.family_id
  )
);

drop policy if exists "quest_assignees_select" on public.quest_assignees;
create policy "quest_assignees_select"
on public.quest_assignees for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.quests q
    join public.profiles p on p.family_id = q.family_id
    where q.id = quest_assignees.quest_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
  or exists (
    select 1
    from public.children c
    where c.id = quest_assignees.child_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "quest_assignees_write_parent_or_child" on public.quest_assignees;
create policy "quest_assignees_write_parent_or_child"
on public.quest_assignees for all
using (
  public.is_admin()
  or exists (
    select 1
    from public.quests q
    join public.profiles p on p.family_id = q.family_id
    where q.id = quest_assignees.quest_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
  or exists (
    select 1
    from public.children c
    where c.id = quest_assignees.child_id
      and c.user_id = auth.uid()
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.quests q
    join public.profiles p on p.family_id = q.family_id
    where q.id = quest_assignees.quest_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
  or exists (
    select 1
    from public.children c
    where c.id = quest_assignees.child_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "quest_comments_select" on public.quest_comments;
create policy "quest_comments_select"
on public.quest_comments for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.quests q
    join public.profiles p on p.family_id = q.family_id
    where q.id = quest_comments.quest_id
      and p.user_id = auth.uid()
      and p.role = 'parent'
  )
  or exists (
    select 1
    from public.quest_assignees a
    join public.children c on c.id = a.child_id
    where a.quest_id = quest_comments.quest_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "quest_comments_insert" on public.quest_comments;
create policy "quest_comments_insert"
on public.quest_comments for insert
with check (
  public.is_admin()
  or created_by = auth.uid()
);

drop policy if exists "family_parent_invites_parent_rw" on public.family_parent_invites;
create policy "family_parent_invites_parent_rw"
on public.family_parent_invites for all
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = family_parent_invites.family_id
  )
)
with check (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'parent'
      and p.family_id = family_parent_invites.family_id
  )
);

-- ===== RPC for quests/wallet/shop/subscription =====
create or replace function public.family_active_plan_code(p_family_id uuid)
returns text
language sql
stable
as $$
  select coalesce(
    (
      select fs.plan_code
      from public.family_subscriptions fs
      where fs.family_id = p_family_id
        and fs.status = 'active'
        and (fs.expires_at is null or fs.expires_at > now())
      order by fs.created_at desc
      limit 1
    ),
    'basic'
  )
$$;

create or replace function public.parent_create_quest(
  p_title text,
  p_description text,
  p_reward_amount int,
  p_quest_type text,
  p_due_at timestamptz,
  p_child_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_family_id uuid;
  v_plan_code text;
  v_max_active int;
  v_active_count int;
  v_quest_id uuid;
  v_child uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_family_id is null then
    raise exception 'Family not found';
  end if;

  v_plan_code := public.family_active_plan_code(v_family_id);
  select sp.max_active_quests into v_max_active
  from public.subscription_plans sp
  where sp.code = v_plan_code;

  select count(*) into v_active_count
  from public.quests q
  where q.family_id = v_family_id
    and q.status in ('draft', 'active');

  if v_active_count >= coalesce(v_max_active, 10) then
    raise exception 'Quest limit reached for current plan';
  end if;

  insert into public.quests(
    family_id, title, description, reward_amount, quest_type, due_at, status, created_by
  )
  values (
    v_family_id, trim(p_title), p_description, greatest(p_reward_amount, 0), coalesce(p_quest_type, 'one_time'),
    p_due_at, 'active', v_user_id
  )
  returning id into v_quest_id;

  foreach v_child in array p_child_ids loop
    insert into public.quest_assignees(quest_id, child_id, reward_amount)
    values (v_quest_id, v_child, greatest(p_reward_amount, 0))
    on conflict (quest_id, child_id) do nothing;
  end loop;

  insert into public.audit_logs(family_id, actor_user_id, action, target_type, target_id, payload)
  values (v_family_id, v_user_id, 'quest_created', 'quest', v_quest_id::text, jsonb_build_object('title', p_title));

  return v_quest_id;
end;
$$;

create or replace function public.child_submit_quest(
  p_quest_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_child_id uuid;
begin
  select c.id into v_child_id
  from public.children c
  where c.user_id = auth.uid()
  limit 1;

  if v_child_id is null then
    raise exception 'Child session not found';
  end if;

  update public.quest_assignees
  set status = 'submitted',
      submitted_at = now()
  where quest_id = p_quest_id
    and child_id = v_child_id;
end;
$$;

create or replace function public.parent_review_quest_submission(
  p_quest_id uuid,
  p_child_id uuid,
  p_approve boolean,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_wallet_id uuid;
  v_reward int;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  if p_approve then
    update public.quest_assignees
    set status = 'approved',
        approved_at = now(),
        reviewer_user_id = v_user_id,
        comment = p_comment
    where quest_id = p_quest_id
      and child_id = p_child_id;

    select reward_amount into v_reward
    from public.quest_assignees
    where quest_id = p_quest_id
      and child_id = p_child_id;

    select w.id into v_wallet_id
    from public.wallets w
    where w.child_id = p_child_id
    limit 1;

    if v_wallet_id is null then
      insert into public.wallets(child_id, balance)
      values (p_child_id, 0)
      returning id into v_wallet_id;
    end if;

    insert into public.transactions(wallet_id, amount, tx_type, quest_id, note, created_by)
    values (v_wallet_id, greatest(coalesce(v_reward, 0), 0), 'earn', p_quest_id, 'Автоначисление за подтвержденный квест', v_user_id);

    update public.wallets
    set balance = balance + greatest(coalesce(v_reward, 0), 0),
        updated_at = now()
    where id = v_wallet_id;
  else
    update public.quest_assignees
    set status = 'rejected',
        reviewer_user_id = v_user_id,
        comment = p_comment
    where quest_id = p_quest_id
      and child_id = p_child_id;
  end if;
end;
$$;

create or replace function public.parent_adjust_wallet(
  p_child_id uuid,
  p_amount int,
  p_note text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_wallet_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select w.id into v_wallet_id
  from public.wallets w
  where w.child_id = p_child_id
  limit 1;

  if v_wallet_id is null then
    insert into public.wallets(child_id, balance)
    values (p_child_id, 0)
    returning id into v_wallet_id;
  end if;

  insert into public.transactions(wallet_id, amount, tx_type, note, created_by)
  values (v_wallet_id, p_amount, 'adjust', p_note, v_user_id);

  update public.wallets
  set balance = balance + p_amount,
      updated_at = now()
  where id = v_wallet_id;
end;
$$;

create or replace function public.child_request_purchase(
  p_product_id uuid,
  p_quantity int default 1
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_child_id uuid;
  v_wallet_id uuid;
  v_price int;
  v_total int;
  v_purchase_id uuid;
begin
  select c.id into v_child_id
  from public.children c
  where c.user_id = auth.uid()
  limit 1;

  if v_child_id is null then
    raise exception 'Child session not found';
  end if;

  select sp.price into v_price
  from public.shop_products sp
  where sp.id = p_product_id
    and sp.is_active = true
  limit 1;

  if v_price is null then
    raise exception 'Product not available';
  end if;

  v_total := greatest(v_price * greatest(p_quantity, 1), 0);

  select w.id into v_wallet_id
  from public.wallets w
  where w.child_id = v_child_id
  limit 1;

  if v_wallet_id is null then
    raise exception 'Wallet not found';
  end if;

  if (select balance from public.wallets where id = v_wallet_id) < v_total then
    raise exception 'Insufficient funds';
  end if;

  update public.wallets
  set balance = balance - v_total,
      updated_at = now()
  where id = v_wallet_id;

  insert into public.transactions(wallet_id, amount, tx_type, note, created_by)
  values (v_wallet_id, -v_total, 'spend', 'Заморозка средств под покупку', auth.uid());

  insert into public.shop_purchases(product_id, child_id, quantity, total_price, frozen_amount, status)
  values (p_product_id, v_child_id, greatest(p_quantity, 1), v_total, v_total, 'requested')
  returning id into v_purchase_id;

  return v_purchase_id;
end;
$$;

create or replace function public.parent_decide_purchase(
  p_purchase_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_row record;
  v_wallet_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select spu.*, c.family_id
    into v_row
  from public.shop_purchases spu
  join public.children c on c.id = spu.child_id
  where spu.id = p_purchase_id
  limit 1;

  if v_row.id is null then
    raise exception 'Purchase not found';
  end if;

  if p_approve then
    update public.shop_purchases
    set status = 'approved',
        decided_by = v_user_id,
        decided_at = now()
    where id = p_purchase_id;
  else
    select w.id into v_wallet_id
    from public.wallets w
    where w.child_id = v_row.child_id
    limit 1;

    if v_wallet_id is not null then
      update public.wallets
      set balance = balance + coalesce(v_row.frozen_amount, 0),
          updated_at = now()
      where id = v_wallet_id;

      insert into public.transactions(wallet_id, amount, tx_type, note, created_by)
      values (v_wallet_id, coalesce(v_row.frozen_amount, 0), 'adjust', 'Возврат замороженных средств по отклоненной покупке', v_user_id);
    end if;

    update public.shop_purchases
    set status = 'rejected',
        decided_by = v_user_id,
        decided_at = now()
    where id = p_purchase_id;
  end if;
end;
$$;

create or replace function public.parent_activate_promo(
  p_code text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_family_id uuid;
  v_promo record;
  v_exp timestamptz;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_family_id is null then
    raise exception 'Family not found';
  end if;

  select * into v_promo
  from public.promo_codes pc
  where upper(pc.code) = upper(trim(p_code))
    and pc.is_active = true
    and (pc.starts_at is null or pc.starts_at <= now())
    and (pc.ends_at is null or pc.ends_at >= now())
  limit 1;

  if v_promo.id is null then
    raise exception 'Promo not found or inactive';
  end if;

  if v_promo.used_count >= v_promo.max_uses then
    raise exception 'Promo usage limit reached';
  end if;

  v_exp := now() + make_interval(days => greatest(v_promo.duration_days, 1));

  insert into public.family_subscriptions(family_id, plan_code, status, started_at, expires_at, source)
  values (v_family_id, v_promo.plan_code, 'active', now(), v_exp, 'promocode');

  update public.promo_codes
  set used_count = used_count + 1
  where id = v_promo.id;

  insert into public.promo_redemptions(promo_id, family_id, redeemed_by)
  values (v_promo.id, v_family_id, v_user_id);

  return v_promo.plan_code;
end;
$$;

create or replace function public.parent_create_payment_order(
  p_plan_code text,
  p_amount_rub numeric
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_family_id uuid;
  v_order_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_family_id is null then
    raise exception 'Family not found';
  end if;

  insert into public.payment_orders(family_id, amount_rub, status, plan_code)
  values (v_family_id, p_amount_rub, 'pending', p_plan_code)
  returning id into v_order_id;

  return v_order_id;
end;
$$;

create or replace function public.parent_create_invite(
  p_email text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_family_id uuid;
  v_token text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_family_id is null then
    raise exception 'Family not found';
  end if;

  v_token := encode(gen_random_bytes(12), 'hex');
  insert into public.family_parent_invites(family_id, email, token, created_by)
  values (v_family_id, lower(trim(p_email)), v_token, v_user_id);

  return v_token;
end;
$$;

create or replace function public.accept_parent_invite(
  p_token text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_invite record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select * into v_invite
  from public.family_parent_invites fpi
  where fpi.token = trim(p_token)
    and fpi.status = 'pending'
    and fpi.expires_at > now()
  limit 1;

  if v_invite.id is null then
    raise exception 'Invite invalid';
  end if;

  insert into public.profiles(user_id, family_id, role)
  values (v_user_id, v_invite.family_id, 'parent')
  on conflict (user_id) do update
    set family_id = excluded.family_id,
        role = excluded.role;

  update public.family_parent_invites
  set status = 'accepted',
      accepted_by = v_user_id,
      accepted_at = now()
  where id = v_invite.id;

  return v_invite.family_id;
end;
$$;

create or replace function public.parent_grant_admin(
  p_target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_family_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select p.family_id into v_family_id
  from public.profiles p
  where p.user_id = v_user_id
    and p.role in ('parent', 'admin')
  limit 1;

  if v_family_id is null then
    raise exception 'Family not found';
  end if;

  if not exists (
    select 1 from public.profiles tp
    where tp.user_id = p_target_user_id
      and tp.family_id = v_family_id
      and tp.role = 'parent'
  ) then
    raise exception 'Target parent not found in family';
  end if;

  update public.profiles
  set role = 'parent'
  where family_id = v_family_id
    and role = 'admin';

  update public.profiles
  set role = 'admin'
  where user_id = p_target_user_id;
end;
$$;

create or replace function public.parent_deactivate_child(
  p_child_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  if not exists (
    select 1
    from public.children c
    join public.profiles p on p.family_id = c.family_id
    where c.id = p_child_id
      and p.user_id = v_user_id
      and p.role in ('parent', 'admin')
  ) then
    raise exception 'Access denied';
  end if;

  update public.children
  set is_active = false
  where id = p_child_id;

  perform public.parent_revoke_child_devices(p_child_id);
end;
$$;


