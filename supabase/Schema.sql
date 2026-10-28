-- Wintertraining 26/27 – Datenbank für Supabase (Login mit Name + Team-Code)
-- Einmal komplett im Supabase "SQL Editor" ausführen.
-- Vorher UNTEN die beiden Codes anpassen!

-- Alte Tabellen aus der ersten Version (E-Mail-Login) entfernen – sie sind leer
drop table if exists public.entries, public.profiles, public.coaches cascade;
drop function if exists public.is_coach();

-- Codes (genau eine Zeile)
create table if not exists public.wt_settings (
  id         int primary key default 1 check (id = 1),
  team_code  text not null,
  coach_code text not null
);

-- Ruderinnen
create table if not exists public.wt_rowers (
  name       text primary key check (char_length(name) between 1 and 80),
  grp        smallint not null check (grp in (1, 2)),
  created_at timestamptz not null default now()
);

-- Eine Zeile pro bestätigter Einheit, z. B. entry_key = 'w3-ergo'
create table if not exists public.wt_entries (
  name       text not null references public.wt_rowers (name) on update cascade on delete cascade,
  entry_key  text not null check (entry_key ~ '^w([0-9]|1[0-3])-(kraft|ergo|aus)$'),
  data       jsonb not null default '{}'::jsonb check (pg_column_size(data) < 8000),
  done_at    timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (name, entry_key)
);

-- Kein direkter Zugriff von der Website – nur über die Funktionen unten
alter table public.wt_settings enable row level security;
alter table public.wt_rowers   enable row level security;
alter table public.wt_entries  enable row level security;
revoke all on public.wt_settings, public.wt_rowers, public.wt_entries from anon, authenticated;

-- Welche Rolle gehört zum Code? 'coach', 'team' oder null
create or replace function public.wt_role(p_code text)
returns text language plpgsql stable security definer set search_path = public as $$
declare s public.wt_settings;
begin
  select * into s from public.wt_settings where id = 1;
  if s is null or p_code is null then return null; end if;
  if lower(trim(p_code)) = lower(trim(s.coach_code)) then return 'coach'; end if;
  if lower(trim(p_code)) = lower(trim(s.team_code))  then return 'team';  end if;
  return null;
end $$;

create or replace function public.wt_require(p_code text, p_need text)
returns void language plpgsql security definer set search_path = public as $$
declare r text := public.wt_role(p_code);
begin
  if r is null or (p_need = 'coach' and r <> 'coach') then
    perform pg_sleep(1);                       -- bremst Raten
    raise exception 'wrong_code' using errcode = '28000';
  end if;
end $$;

-- Login prüfen: liefert 'team' oder 'coach'
create or replace function public.wt_check(p_code text)
returns text language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  return public.wt_role(p_code);
end $$;

-- Eigene Daten laden (null, wenn der Name noch nicht angelegt ist)
create or replace function public.wt_me(p_code text, p_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.wt_rowers;
begin
  perform public.wt_require(p_code, 'team');
  select * into r from public.wt_rowers where name = p_name;
  if r is null then return null; end if;
  return jsonb_build_object('name', r.name, 'grp', r.grp, 'entries',
    coalesce((select jsonb_agg(jsonb_build_object('entry_key', e.entry_key, 'data', e.data, 'done_at', e.done_at))
              from public.wt_entries e where e.name = r.name), '[]'::jsonb));
end $$;

-- Namen anlegen oder ändern (p_old = bisheriger Name oder null)
create or replace function public.wt_profile(p_code text, p_old text, p_name text, p_grp int)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  if p_old is null or p_old = p_name then
    insert into public.wt_rowers (name, grp) values (trim(p_name), p_grp)
      on conflict (name) do update set grp = excluded.grp;
  else
    update public.wt_rowers set name = trim(p_name), grp = p_grp where name = p_old;
    if not found then
      insert into public.wt_rowers (name, grp) values (trim(p_name), p_grp);
    end if;
  end if;
end $$;

-- Einheit speichern
create or replace function public.wt_save(p_code text, p_name text, p_key text, p_data jsonb, p_done_at timestamptz)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  insert into public.wt_entries (name, entry_key, data, done_at, updated_at)
    values (p_name, p_key, coalesce(p_data, '{}'::jsonb), coalesce(p_done_at, now()), now())
    on conflict (name, entry_key) do update set data = excluded.data, updated_at = now();
end $$;

-- Einheit zurücksetzen
create or replace function public.wt_delete(p_code text, p_name text, p_key text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  delete from public.wt_entries where name = p_name and entry_key = p_key;
end $$;

-- Übersicht für die Trainerin (nur mit Trainerinnen-Code)
create or replace function public.wt_overview(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'coach');
  return coalesce((select jsonb_agg(jsonb_build_object('name', r.name, 'grp', r.grp, 'entries',
      coalesce((select jsonb_agg(jsonb_build_object('entry_key', e.entry_key, 'data', e.data, 'done_at', e.done_at))
                from public.wt_entries e where e.name = r.name), '[]'::jsonb)))
    from public.wt_rowers r), '[]'::jsonb);
end $$;

revoke all on function public.wt_role(text), public.wt_require(text, text) from public, anon, authenticated;
grant execute on function public.wt_check(text), public.wt_me(text, text),
  public.wt_profile(text, text, text, int), public.wt_save(text, text, text, jsonb, timestamptz),
  public.wt_delete(text, text, text), public.wt_overview(text) to anon, authenticated;

-- >>> HIER DIE CODES ANPASSEN (Groß-/Kleinschreibung egal) <<<
insert into public.wt_settings (id, team_code, coach_code)
values (1, 'Ruder_Winter_26', 'Deine_Ladies_26')
on conflict (id) do update set team_code = excluded.team_code, coach_code = excluded.coach_code;
