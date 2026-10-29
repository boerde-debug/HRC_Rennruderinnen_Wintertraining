-- "Wer macht was?" – Aufgaben und Ämter
-- Einmal komplett im Supabase "SQL Editor" ausführen (NACH schema.sql).
-- Ändert nichts an den Codes oder an den Trainingseinträgen.

-- Aufgaben
create table if not exists public.wt_tasks (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(title) between 1 and 120),
  kind       text not null default 'kurz' check (kind in ('kurz', 'mittel')),
  due        date,
  notes      text not null default '' check (char_length(notes) <= 2000),
  assignees  text[] not null default '{}',
  status     text not null default 'offen' check (status in ('offen', 'erledigt')),
  created_by text,
  created_at timestamptz not null default now(),
  done_at    timestamptz
);

-- Ämter
create table if not exists public.wt_roles (
  id          uuid primary key default gen_random_uuid(),
  title       text not null unique check (char_length(title) between 1 and 80),
  description text not null default '' check (char_length(description) <= 1000),
  holder      text,
  since       date,
  until       date,
  created_at  timestamptz not null default now()
);

-- Wer hatte welches Amt wann?
create table if not exists public.wt_role_history (
  id        uuid primary key default gen_random_uuid(),
  role_id   uuid not null references public.wt_roles (id) on delete cascade,
  holder    text not null,
  from_date date not null,
  to_date   date
);

alter table public.wt_tasks        enable row level security;
alter table public.wt_roles        enable row level security;
alter table public.wt_role_history enable row level security;
revoke all on public.wt_tasks, public.wt_roles, public.wt_role_history from anon, authenticated;

-- Alles auf einmal laden: Aufgaben, Ämter (mit Verlauf), angemeldete Namen
create or replace function public.wt_board(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  return jsonb_build_object(
    'tasks', coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at) from public.wt_tasks t), '[]'::jsonb),
    'roles', coalesce((select jsonb_agg(to_jsonb(r) || jsonb_build_object('history',
                coalesce((select jsonb_agg(to_jsonb(h) order by h.to_date desc nulls first, h.from_date desc) from public.wt_role_history h where h.role_id = r.id), '[]'::jsonb))
              order by r.title) from public.wt_roles r), '[]'::jsonb),
    'names', coalesce((select jsonb_agg(name order by name) from public.wt_rowers), '[]'::jsonb)
  );
end $$;

-- Aufgabe anlegen oder ändern (p_id = null legt neu an); liefert die id
create or replace function public.wt_task_save(p_code text, p_id uuid, p_title text, p_kind text, p_due date,
  p_notes text, p_assignees text[], p_status text, p_actor text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.wt_require(p_code, 'team');
  if p_id is null then
    insert into public.wt_tasks (title, kind, due, notes, assignees, status, created_by, done_at)
    values (trim(p_title), coalesce(p_kind, 'kurz'), p_due, coalesce(p_notes, ''), coalesce(p_assignees, '{}'),
            coalesce(p_status, 'offen'), p_actor, case when p_status = 'erledigt' then now() end)
    returning id into v_id;
  else
    update public.wt_tasks set title = trim(p_title), kind = coalesce(p_kind, kind), due = p_due,
      notes = coalesce(p_notes, ''), assignees = coalesce(p_assignees, '{}'), status = coalesce(p_status, status),
      done_at = case when p_status = 'erledigt' then coalesce(done_at, now()) else null end
    where id = p_id returning id into v_id;
  end if;
  return v_id;
end $$;

create or replace function public.wt_task_delete(p_code text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  delete from public.wt_tasks where id = p_id;
end $$;

-- Amt anlegen oder umbenennen/beschreiben
create or replace function public.wt_role_save(p_code text, p_id uuid, p_title text, p_description text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.wt_require(p_code, 'team');
  if p_id is null then
    insert into public.wt_roles (title, description) values (trim(p_title), coalesce(p_description, '')) returning id into v_id;
  else
    update public.wt_roles set title = trim(p_title), description = coalesce(p_description, '') where id = p_id returning id into v_id;
  end if;
  return v_id;
end $$;

create or replace function public.wt_role_delete(p_code text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  delete from public.wt_roles where id = p_id;
end $$;

-- Amt übernehmen (auch Übergabe von der bisherigen Inhaberin)
create or replace function public.wt_role_take(p_code text, p_id uuid, p_name text, p_until date)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  update public.wt_role_history set to_date = current_date where role_id = p_id and to_date is null;
  update public.wt_roles set holder = trim(p_name), since = current_date, until = p_until where id = p_id;
  insert into public.wt_role_history (role_id, holder, from_date) values (p_id, trim(p_name), current_date);
end $$;

-- Geplante Amtszeit ändern
create or replace function public.wt_role_until(p_code text, p_id uuid, p_until date)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  update public.wt_roles set until = p_until where id = p_id;
end $$;

-- Amt abgeben
create or replace function public.wt_role_release(p_code text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.wt_require(p_code, 'team');
  update public.wt_role_history set to_date = current_date where role_id = p_id and to_date is null;
  update public.wt_roles set holder = null, since = null, until = null where id = p_id;
end $$;

-- Namensänderung auch in Aufgaben und Ämtern übernehmen
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
    update public.wt_tasks set assignees = array_replace(assignees, p_old, trim(p_name)) where p_old = any(assignees);
    update public.wt_roles set holder = trim(p_name) where holder = p_old;
    update public.wt_role_history set holder = trim(p_name) where holder = p_old;
  end if;
end $$;

grant execute on function public.wt_board(text),
  public.wt_task_save(text, uuid, text, text, date, text, text[], text, text),
  public.wt_task_delete(text, uuid),
  public.wt_role_save(text, uuid, text, text), public.wt_role_delete(text, uuid),
  public.wt_role_take(text, uuid, text, date), public.wt_role_until(text, uuid, date),
  public.wt_role_release(text, uuid),
  public.wt_profile(text, text, text, int) to anon, authenticated;

-- Startämter (weitere lassen sich in der App anlegen)
insert into public.wt_roles (title, description) values
  ('Bootsbauerin', 'Kümmert sich um Pflege und kleine Reparaturen der Boote.'),
  ('Zeugwartin',   'Verwaltet Material, Skulls und Zubehör.'),
  ('Kassenwartin', 'Führt die Mannschaftskasse.')
on conflict (title) do nothing;
