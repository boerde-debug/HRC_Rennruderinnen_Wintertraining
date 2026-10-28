# Wintertraining 26/27 – HRC Rennruderinnen

Web-App zum Wintertrainingsplan (19.10.2026 – 22.02.2027).

- **Ruderinnen** melden sich per E-Mail-Link an (kein Passwort, kein Claude-Konto), wählen einmal ihren Namen und sehen ihren Plan der Wochen 0–13. Einheiten werden bestätigt, optional mit Zeit, Metern, Schlagzahl, Split, Anstrengung und Kommentar.
- **1.000-m-Tests** in Woche 0 (Start), Woche 7 (Zwischentest) und Woche 13 (Ende) werden mit Zeit, Schlagzahl, Split und Anstrengung erfasst.
- **Trainerinnen** sehen eine Übersicht aller Ruderinnen mit Fortschritt, 1.000-m-Zeiten und Differenz Start → Ende sowie alle Einträge und Kommentare.

Die Website liegt auf **GitHub Pages**, die Daten in **Supabase** (kostenloser Plan reicht).

## Dateien

| Datei | Inhalt |
|---|---|
| `index.html` | die komplette App (Plan, Login, Ruderinnen- und Trainerinnen-Ansicht) |
| `config.js` | Supabase-Adresse und öffentlicher Schlüssel – **hier eintragen** |
| `supabase/schema.sql` | Tabellen und Zugriffsregeln für Supabase |

Den Trainingsplan selbst (Einheiten, Splits, Namen) findest du oben im Skript von `index.html` unter `PLAN` und `ROSTER`.

## Einrichtung (einmalig, ca. 15 Minuten)

### 1. Supabase-Projekt anlegen
1. Auf <https://supabase.com> kostenlos registrieren und **New project** anlegen.
2. Region **Central EU (Frankfurt)** wählen, ein Datenbank-Passwort vergeben (wird für die App nicht gebraucht).

### 2. Datenbank einrichten
1. Im Projekt links **SQL Editor** öffnen.
2. Den kompletten Inhalt von `supabase/schema.sql` einfügen und **Run** klicken.
3. Trainerin(nen) freischalten – im SQL Editor ausführen (Adresse anpassen):
   ```sql
   insert into public.coaches (email) values ('trainerin@example.de');
   ```
   Mit dieser Adresse meldet sich die Trainerin dann auf der Website an.
   Entziehen: `delete from public.coaches where email = 'trainerin@example.de';`

### 3. Login per E-Mail konfigurieren
1. **Authentication → Sign In / Providers → Email**: muss aktiviert sein (Standard).
2. **Authentication → URL Configuration**:
   - *Site URL*: `https://boerde-debug.github.io/HRC_Rennruderinnen_Wintertraining/`
   - *Redirect URLs*: dieselbe Adresse hinzufügen.
3. **Authentication → Emails → Templates → Magic Link**: damit auch ein Code in der Mail steht (praktisch, wenn der Link am Handy im falschen Browser aufgeht), den Text z. B. so anpassen:
   ```html
   <h2>Anmeldung Wintertraining</h2>
   <p><a href="{{ .ConfirmationURL }}">Hier tippen zum Anmelden</a></p>
   <p>Oder diesen Code auf der Website eingeben: <strong>{{ .Token }}</strong></p>
   ```
   Gleiches für das Template **Confirm signup** (erste Anmeldung einer neuen Adresse).

> **Wichtig – E-Mail-Limit:** Der eingebaute Mailversand von Supabase schickt nur sehr wenige Mails pro Stunde. Für den Start mit ca. 30 Ruderinnen empfiehlt sich ein eigener SMTP-Dienst (z. B. Brevo, kostenlos bis 300 Mails/Tag): **Project Settings → Authentication → SMTP Settings**. Danach unter **Authentication → Rate Limits** das Mail-Limit erhöhen. Ohne eigenes SMTP klappt es auch, wenn sich die Ruderinnen verteilt über einige Stunden anmelden. Einmal angemeldet bleibt man auf dem Gerät eingeloggt.

### 4. Zugangsdaten eintragen
1. **Project Settings → API** (bzw. **Data API** und **API Keys**) öffnen.
2. *Project URL* und den **anon / publishable** Key in `config.js` eintragen:
   ```js
   window.WT_CONFIG = {
     url: "https://abcdefgh.supabase.co",
     anonKey: "eyJ..."
   };
   ```
   Dieser Schlüssel ist öffentlich und darf ins Repository. **Niemals** den `service_role`/`secret` Key eintragen.

### 5. GitHub Pages einschalten
Im Repository **Settings → Pages → Build and deployment**: *Source* „Deploy from a branch“, Branch `main`, Ordner `/ (root)` → **Save**.
Nach ca. einer Minute ist die App erreichbar unter
`https://boerde-debug.github.io/HRC_Rennruderinnen_Wintertraining/`

Diesen Link an die Mannschaft schicken – fertig.

## Datenschutz & Zugriff

- Jede Ruderin sieht und ändert **nur ihre eigenen** Einträge (in der Datenbank erzwungen, nicht nur in der App).
- Nur Adressen in der Tabelle `coaches` sehen alle Einträge – nur lesend.
- Gespeichert werden: E-Mail-Adresse (für den Login), gewählter Name, Gruppe und die Trainingseinträge.
- Eine Ruderin löschen: in Supabase **Authentication → Users** den Nutzer löschen; Profil und Einträge werden automatisch mitgelöscht.

## Gut zu wissen

- **Pausierung:** Kostenlose Supabase-Projekte werden nach etwa einer Woche ohne Nutzung pausiert (z. B. über Weihnachten). Dann im Supabase-Dashboard auf **Restore project** klicken; die Daten bleiben erhalten.
- **Plan ändern:** In `index.html` die Einträge in `PLAN` bearbeiten. Die Einträge der Ruderinnen hängen an Wochennummer + Einheit (`w3-ergo`), nicht am Text.
- **Namen ergänzen:** In `index.html` die Liste `ROSTER` erweitern. Ruderinnen, die nicht in der Liste stehen, können sich aber auch selbst mit Namen und Gruppe eintragen.
