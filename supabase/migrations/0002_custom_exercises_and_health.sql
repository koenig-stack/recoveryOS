-- Protokoll -- Migration 0002
-- (1) Eigene Uebungen dauerhaft im Katalog  (2) Zepp-Gesundheitsdaten
-- Im Supabase SQL-Editor ausfuehren. Idempotent.

-- ============================================================
-- 1. Eigene Uebungen: user_id + Policies
--    Globale Katalog-Zeilen haben user_id = NULL (fuer alle lesbar).
--    Eigene Uebungen tragen die user_id des Erstellers.
-- ============================================================

alter table exercises add column if not exists user_id uuid references auth.users(id) on delete cascade;

drop policy if exists "exercises lesbar" on exercises;
create policy "exercises lesbar" on exercises
  for select to authenticated using (user_id is null or user_id = auth.uid());

drop policy if exists "exercises eigene insert" on exercises;
create policy "exercises eigene insert" on exercises
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "exercises eigene update" on exercises;
create policy "exercises eigene update" on exercises
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "exercises eigene delete" on exercises;
create policy "exercises eigene delete" on exercises
  for delete to authenticated using (user_id = auth.uid());

-- Namens-Eindeutigkeit: global eindeutig, und je Nutzer eindeutig
alter table exercises drop constraint if exists exercises_name_key;
create unique index if not exists exercises_global_name on exercises(name) where user_id is null;
create unique index if not exists exercises_user_name   on exercises(user_id, name) where user_id is not null;

-- ============================================================
-- 2. Zepp-Gesundheitsdaten: ein Datensatz pro Tag
-- ============================================================

create table if not exists health_days (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day          date not null,
  sleep_min    int,
  sleep_score  int,
  resting_hr   int,
  hrv_ms       int,
  steps        int,
  stress       int,
  weight_kg    numeric(5,2),
  calories     int,
  notes        text,
  source       text default 'zepp',
  created_at   timestamptz not null default now(),
  unique (user_id, day)
);

create index if not exists idx_health_user_day on health_days (user_id, day desc);

alter table health_days enable row level security;

drop policy if exists "eigene health" on health_days;
create policy "eigene health" on health_days
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
