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
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  family_id uuid references public.families(id) on delete set null,
  role text not null check (role in ('parent', 'admin')),
  display_name text,
  created_at timestamptz not null default now()
);

-- Child accounts are auth.users too, but login uses phone+password mapped to pseudo-email.
create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  phone text not null unique,
  display_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

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

