-- Wintertraining 26/27 – Datenbank für Supabase
-- Einmal komplett im Supabase "SQL Editor" ausführen.

-- Profil jeder Ruderin (Name + Gruppe), verknüpft mit ihrem Login
create table if not exists public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  name       text not null check (char_length(name) between 1 and 80),
  grp        smallint not null check (grp in (1, 2)),
  created_at timestamptz not null default now()
);

-- Eine Zeile pro bestätigter Einheit, z. B. entry_key = 'w3-ergo'
create table if not exists public.entries (
  user_id    uuid not null references auth.users on delete cascade,
  entry_key  text not null check (entry_key ~ '^w([0-9]|1[0-3])-(kraft|ergo|aus)$'),
  data       jsonb not null default '{}'::jsonb check (pg_column_size(data) < 8000),
  done_at    timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, entry_key)
);

-- E-Mail-Adressen, die die Trainerinnen-Übersicht sehen dürfen.
-- Nicht über die Website lesbar oder änderbar (RLS ohne Policies).
create table if not exists public.coaches (
  email text primary key
);

-- Website-Zugriff nur für angemeldete Personen (Zeilen-Regeln folgen unten)
revoke all on public.profiles, public.entries, public.coaches from anon;
grant select, insert, update, delete on public.profiles, public.entries to authenticated;
revoke all on public.coaches from authenticated;

alter table public.profiles enable row level security;
alter table public.entries  enable row level security;
alter table public.coaches  enable row level security;

-- Ist die angemeldete Person Trainerin?
create or replace function public.is_coach()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.coaches
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function public.is_coach() from public;
grant execute on function public.is_coach() to authenticated;

-- Profile: jede sieht/ändert nur ihr eigenes, Trainerinnen sehen alle
drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_insert" on public.profiles;
drop policy if exists "profiles_update" on public.profiles;
create policy "profiles_select" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_coach());
create policy "profiles_insert" on public.profiles for insert to authenticated
  with check (id = auth.uid());
create policy "profiles_update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Einträge: jede sieht/ändert nur ihre eigenen, Trainerinnen lesen alle
drop policy if exists "entries_select" on public.entries;
drop policy if exists "entries_insert" on public.entries;
drop policy if exists "entries_update" on public.entries;
drop policy if exists "entries_delete" on public.entries;
create policy "entries_select" on public.entries for select to authenticated
  using (user_id = auth.uid() or public.is_coach());
create policy "entries_insert" on public.entries for insert to authenticated
  with check (user_id = auth.uid());
create policy "entries_update" on public.entries for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "entries_delete" on public.entries for delete to authenticated
  using (user_id = auth.uid());

-- Trainerin freischalten (Adresse anpassen und ausführen):
-- insert into public.coaches (email) values ('trainerin@example.de');
