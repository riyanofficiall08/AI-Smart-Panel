-- =====================================================================
-- AI SMART PANEL - skema database + Row Level Security
-- Jalankan lewat `supabase db push` atau tempel di SQL Editor.
-- =====================================================================

-- ---------- tabel ----------
create table if not exists public.profiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  username             text not null unique check (username ~ '^[a-z0-9_.]{3,32}$'),
  display_name         text,
  role                 text not null default 'user' check (role in ('admin','user')),
  is_active            boolean not null default true,
  expires_at           timestamptz,                       -- masa aktif akun (null = belum punya lisensi)
  daily_limit          integer check (daily_limit is null or daily_limit >= 0), -- null = ikut default global
  must_change_password boolean not null default false,
  created_by           uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table if not exists public.licenses (
  id            uuid primary key default gen_random_uuid(),
  token_hash    text not null unique,                      -- SHA-256, token asli TIDAK disimpan
  token_hint    text not null,                             -- 4 karakter terakhir, hanya untuk tampilan
  duration_days integer not null check (duration_days in (1,7,30,90,365)),
  status        text not null default 'unused' check (status in ('unused','redeemed','revoked')),
  user_id       uuid references public.profiles(id) on delete set null,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  redeemed_at   timestamptz,
  expires_at    timestamptz                                -- batas akhir akses yang diberikan token ini
);
create index if not exists licenses_user_idx on public.licenses(user_id);

create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

-- Rahasia server (OpenAI key terenkripsi AES-GCM). Tanpa policy = tidak bisa diakses klien sama sekali.
create table if not exists public.app_secrets (
  name       text primary key,
  ciphertext text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.usage_logs (
  id                bigint generated always as identity primary key,
  user_id           uuid references public.profiles(id) on delete set null,
  username          text,
  action            text not null,      -- analyze | redeem | admin_*
  status            text not null,      -- ok | error | denied | quota | rate_limited
  mode              text,
  model             text,
  latency_ms        integer,
  prompt_tokens     integer,
  completion_tokens integer,
  detail            text,
  created_at        timestamptz not null default now()
);
create index if not exists usage_user_idx   on public.usage_logs(user_id, created_at desc);
create index if not exists usage_action_idx on public.usage_logs(action, status, created_at desc);

create table if not exists public.history (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  mode            text not null,
  confidence_pref integer not null,
  question_text   text not null default '',
  question_type   text not null default 'lainnya',
  answer          text not null default '',
  explanation     text not null default '',
  caveats         text not null default '',
  ai_confidence   integer,
  model           text,
  created_at      timestamptz not null default now()
);
create index if not exists history_user_idx on public.history(user_id, created_at desc);

-- ---------- trigger updated_at ----------
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

drop trigger if exists profiles_updated on public.profiles;
create trigger profiles_updated before update on public.profiles
for each row execute function public.set_updated_at();

-- ---------- helper role ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and p.is_active
  );
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ---------- hardening grant ----------
revoke all on all tables in schema public from anon;
revoke all on public.app_secrets from authenticated;
-- Penulisan oleh admin utamanya lewat Edge Function (service role); policy admin = cadangan. User biasa tidak punya policy tulis.
grant insert, update, delete on public.profiles, public.licenses, public.app_settings, public.usage_logs to authenticated;

-- ---------- RLS ----------
alter table public.profiles    enable row level security;
alter table public.licenses    enable row level security;
alter table public.app_settings enable row level security;
alter table public.app_secrets enable row level security;
alter table public.usage_logs  enable row level security;
alter table public.history     enable row level security;

-- profiles
drop policy if exists profiles_select_own   on public.profiles;
drop policy if exists profiles_admin_all    on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_admin_all  on public.profiles for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- licenses
drop policy if exists licenses_select_own on public.licenses;
drop policy if exists licenses_admin_all  on public.licenses;
create policy licenses_select_own on public.licenses for select to authenticated using (user_id = auth.uid());
create policy licenses_admin_all  on public.licenses for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- app_settings (hanya admin)
drop policy if exists settings_admin_all on public.app_settings;
create policy settings_admin_all on public.app_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- usage_logs: user melihat miliknya, admin melihat semua; insert hanya service role
drop policy if exists usage_select_own   on public.usage_logs;
drop policy if exists usage_admin_all    on public.usage_logs;
create policy usage_select_own on public.usage_logs for select to authenticated using (user_id = auth.uid());
create policy usage_admin_all  on public.usage_logs for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- history: milik sendiri saja (admin SENGAJA tidak bisa membaca isi riwayat user = privasi)
drop policy if exists history_select_own on public.history;
drop policy if exists history_delete_own on public.history;
create policy history_select_own on public.history for select to authenticated using (user_id = auth.uid());
create policy history_delete_own on public.history for delete to authenticated using (user_id = auth.uid());

-- app_secrets: tidak ada policy sama sekali (hanya service role yang bisa akses)

-- ---------- seed pengaturan global ----------
insert into public.app_settings(key, value) values
  ('models',                '{"fast":"gpt-4o-mini","accurate":"gpt-4o","study":"gpt-4o"}'::jsonb),
  ('daily_limit',           '100'::jsonb),
  ('rate_limit_per_minute', '6'::jsonb),
  ('openai_key_hint',       'null'::jsonb)
on conflict (key) do nothing;
