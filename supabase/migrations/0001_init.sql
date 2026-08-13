-- Trainings-Erfassung "Protokoll" -- Initiale Migration
-- Schema, RLS, Auswertungs-View und Seed-Daten Uebungskatalog.
-- In der Supabase-Konsole unter Database -> Migrations (oder SQL Editor) einspielen.

-- ============================================================
-- 1. Tabellen
-- ============================================================

-- Uebungskatalog (gemeinsam, lesend fuer alle authentifizierten Nutzer)
create table if not exists exercises (
  id            uuid primary key default gen_random_uuid(),
  name          text not null unique,
  day_tag       text not null check (day_tag in ('A','B','C','X')),
  unit_type     text not null default 'weight_reps'
                check (unit_type in ('weight_reps','reps','distance','time')),
  target_sets   int,
  target_reps_low  int,
  target_reps_high int,
  target_rpe    text,
  unilateral    boolean not null default false,
  sort_order    int not null default 0,
  active        boolean not null default true
);

-- Trainingseinheit
create table if not exists sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_date date not null,
  day_tag      text not null check (day_tag in ('A','B','C','X')),
  cycle_week   int check (cycle_week between 1 and 5),
  session_rpe  int check (session_rpe between 1 and 10),
  notes        text,
  started_at   timestamptz,
  ended_at     timestamptz,
  created_at   timestamptz not null default now()
);

-- Einzelsatz
create table if not exists sets (
  id          uuid primary key,           -- vom Client vergeben (Offline-Queue)
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_id  uuid not null references sessions(id) on delete cascade,
  exercise_id uuid not null references exercises(id),
  set_no      int  not null,
  weight_kg   numeric(6,2),
  reps        int,
  rpe         numeric(3,1) check (rpe between 1 and 10),
  distance_m  numeric(6,1),
  duration_s  int,
  side        text check (side in ('L','R')),   -- nur bei unilateralen Uebungen
  created_at  timestamptz not null default now()
);

create index if not exists idx_sessions_user_date on sessions (user_id, session_date desc);
create index if not exists idx_sets_user_ex        on sets (user_id, exercise_id, created_at desc);
create index if not exists idx_sets_session         on sets (session_id);

-- ============================================================
-- 2. Row Level Security
-- ============================================================

alter table exercises enable row level security;
alter table sessions  enable row level security;
alter table sets      enable row level security;

drop policy if exists "exercises lesbar" on exercises;
create policy "exercises lesbar" on exercises
  for select to authenticated using (true);

drop policy if exists "eigene sessions" on sessions;
create policy "eigene sessions" on sessions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "eigene sets" on sets;
create policy "eigene sets" on sets
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================
-- 3. Auswertungs-View (geschaetztes 1RM nach Epley)
--    security_invoker=on -> RLS der Basistabellen greift auch ueber die View.
-- ============================================================

drop view if exists v_e1rm;
create view v_e1rm with (security_invoker = on) as
select
  s.user_id,
  se.session_date,
  e.name as exercise,
  max(s.weight_kg * (1 + s.reps::numeric / 30)) as e1rm,
  max(s.weight_kg) as top_weight,
  sum(s.weight_kg * s.reps) as tonnage
from sets s
join sessions se on se.id = s.session_id
join exercises e on e.id = s.exercise_id
where s.weight_kg is not null and s.reps is not null and s.reps <= 12
group by s.user_id, se.session_date, e.name;

-- ============================================================
-- 4. Seed-Daten Uebungskatalog
--    reps-Bereiche als low/high, RPE als Text, "-" -> NULL.
-- ============================================================

insert into exercises
  (name, day_tag, unit_type, target_sets, target_reps_low, target_reps_high, target_rpe, unilateral, sort_order)
values
  -- Tag A
  ('Kniebeuge',                       'A', 'weight_reps', 4, 4,  6,  '8-9', false, 1),
  ('Rumaenisches Kreuzheben',         'A', 'weight_reps', 3, 6,  8,  '8',   false, 2),
  ('Bulgarian Split Squat',           'A', 'weight_reps', 3, 8,  8,  '8',   true,  3),
  ('Wadenheben stehend',              'A', 'weight_reps', 3, 10, 12, '8',   false, 4),
  ('Pallof Press',                    'A', 'time',        3, null, null, '7', true, 5),
  -- Tag B
  ('Kurzhantel-Bankdruecken',         'B', 'weight_reps', 4, 6,  8,  '7',   false, 1),
  ('Klimmzug / Latzug',               'B', 'weight_reps', 4, 6,  8,  '7',   false, 2),
  ('Schraegbank-Kurzhanteldruecken',  'B', 'weight_reps', 3, 8,  10, '7',   false, 3),
  ('Einarmiges Kabelrudern',          'B', 'weight_reps', 3, 10, 10, '7',   true,  4),
  ('Face Pull',                       'B', 'weight_reps', 3, 15, 15, '6-7', false, 5),
  ('Handgelenk-Curls',                'B', 'weight_reps', 2, 12, 15, '6',   false, 6),
  ('Reverse Curls',                   'B', 'weight_reps', 2, 12, 15, '6',   false, 7),
  -- Tag C
  ('Goblet Squat',                    'C', 'weight_reps', 3, 8,  10, '6-7', false, 1),
  ('Hip Thrust',                      'C', 'weight_reps', 3, 10, 12, '7',   false, 2),
  ('Kurzhantel-Schulterdruecken',     'C', 'weight_reps', 3, 10, 12, '6-7', false, 3),
  ('Kabelrudern breit',               'C', 'weight_reps', 3, 12, 12, '6-7', false, 4),
  ('Kabel-Holzhacke',                 'C', 'weight_reps', 3, 10, 10, '6',   true,  5),
  ('Farmer''s Walk',                  'C', 'distance',    3, null, null, '7', false, 6),
  -- Tag X (Auffangeintrag)
  ('Sonstige',                        'X', 'weight_reps', null, null, null, null, false, 1)
on conflict (name) do nothing;
