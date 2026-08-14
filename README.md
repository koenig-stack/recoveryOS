# Protokoll — Trainings-Erfassung

Single-File-Web-App zur Erfassung von Krafttrainingsdaten im Gym.
Ein Nutzer, ein Gerät (iPhone, Safari). Erfasst und zeigt Progress — **bewertet nicht**.
Freigabe-/Ermüdungslogik läuft getrennt im Chat, nicht in dieser App.

## Aufbau

```
public/index.html                 komplette App (Vanilla JS, kein Build-Step)
vercel.json                       { "outputDirectory": "public" }
supabase/migrations/0001_init.sql Schema + RLS + Auswertungs-View + Seed-Katalog
```

## Deployment (Vercel)

Repo mit Vercel koppeln. Durch `vercel.json` wird `public/` als Output-Verzeichnis
ausgeliefert, es ist kein Build nötig. Jeder Push auf den Branch löst ein Auto-Deploy aus.

## Restschritt: Supabase-Integration

Die App ist auf Vercel bereits lauffähig und zeigt bis zur Verbindung einen Hinweis-Screen.
Zum Scharfschalten:

1. **Supabase-Projekt anlegen** (eigenes Projekt, nicht ein bestehendes mitbenutzen).
2. **Migrationen einspielen:** im Supabase SQL-Editor nacheinander ausführen:
   - `supabase/migrations/0001_init.sql` — Tabellen, RLS-Policies, View `v_e1rm`, Übungskatalog.
   - `supabase/migrations/0002_custom_exercises_and_health.sql` — eigene Übungen
     (user_id + Policies) und Zepp-Gesundheitsdaten (`health_days`).
3. **Nutzer anlegen:** In der Supabase-Konsole unter *Authentication → Users*
   eine E-Mail + Passwort anlegen. Es gibt bewusst **kein** Sign-Up in der App.
4. **Zugangsdaten eintragen:** In `public/index.html` oben im `<script>`-Block

   ```js
   const SUPABASE_URL      = "https://DEIN-PROJEKT.supabase.co";
   const SUPABASE_ANON_KEY = "DEIN-ANON-KEY";
   ```

   durch die Werte aus *Project Settings → API* ersetzen. Der Anon-Key ist bei
   statischen Seiten öffentlich und unkritisch, **solange RLS aktiv ist** (ist es).

Danach committen → Vercel deployt automatisch → Login erscheint.

## Offline

Jeder Satz wird sofort in `localStorage` geschrieben und im Hintergrund nach
Supabase synchronisiert (Upsert per Client-UUID, keine Duplikate). Der Sync-Status
ist oben sichtbar. Kein Datenverlust bei App-Neustart mit offener Queue.

## Deployment-Regel (wichtig bei Änderungen am JS)

Alle Nicht-ASCII-Zeichen **innerhalb von `<script>`-Blöcken** müssen als `\uXXXX`
escaped sein (sonst CDN-Ablehnung). Prüfen:

```
grep -nP '[^\x00-\x7F]' public/index.html   # Treffer nur im HTML/CSS-Teil erlaubt, nicht im <script>
```

Deutsche Strings im JS also als `"Übung"`, im HTML-Teil als Entities (`&uuml;`).
