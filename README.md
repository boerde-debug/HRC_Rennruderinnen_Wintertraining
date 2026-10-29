# HRC Rennruderinnen – Mannschafts-App

Web-App der Mannschaft mit Startseite und zwei Bereichen:

1. **Wintertraining 26/27** – Trainingsplan (19.10.2026 – 22.02.2027) zum Abhaken
2. **Wer macht was?** – Aufgaben verteilen und Ämter vergeben

Eine dritte Kachel auf der Startseite ist als Platzhalter für die nächste Funktion reserviert.

### Wer macht was?
- **Aufgaben** (kurzfristig, z. B. Regattabericht, Verladen, After Row – oder mittelfristig, z. B. Trainingslager, Wanderfahrt): Titel, optionales Fälligkeitsdatum, eine oder mehrere Personen, Notiz. Jede kann sich mit „Ich mache mit“ eintragen oder austragen, Aufgaben abhaken, bearbeiten und löschen.
- **Ämter** (z. B. Bootsbauerin, Zeugwartin, Kassenwartin – weitere in der App anlegen): übernehmen, mit optionaler Amtszeit, wieder abgeben oder direkt an eine andere übergeben. Abgelaufene Amtszeiten werden markiert, der Verlauf zeigt frühere Inhaberinnen.

### Wintertraining

- **Ruderinnen** geben einmal den **Team-Code** ein, tippen auf ihren Namen und sehen ihren Plan der Wochen 0–13. Einheiten werden bestätigt, optional mit Zeit, Metern, Schlagzahl, Split, Anstrengung und Kommentar. Kein Konto, keine E-Mail.
- **1.000-m-Tests** in Woche 0 (Start), Woche 7 (Zwischentest) und Woche 13 (Ende) werden mit Zeit, Schlagzahl, Split und Anstrengung erfasst.
- **Trainerinnen** melden sich mit dem **Trainerinnen-Code** an und sehen alle Ruderinnen mit Fortschritt, 1.000-m-Zeiten, Differenz Start → Ende sowie alle Einträge und Kommentare.

Die Website liegt auf **GitHub Pages**, die Daten in **Supabase** (kostenloser Plan reicht).

## Dateien

| Datei | Inhalt |
|---|---|
| `index.html` | die komplette App (Plan, Anmeldung, Ruderinnen- und Trainerinnen-Ansicht) |
| `config.js` | Supabase-Adresse und öffentlicher Schlüssel |
| `supabase/schema.sql` | Grundgerüst: Codes, Ruderinnen, Trainingseinträge |
| `supabase/02_wer_macht_was.sql` | Erweiterung: Aufgaben und Ämter |
| `apple-touch-icon.png`, `favicon-32.png` | App-Icon |

Den Trainingsplan selbst (Einheiten, Splits, Namen) findest du oben im Skript von `index.html` unter `PLAN` und `ROSTER`.

## Einrichtung

### 1. Datenbank in Supabase
1. In `supabase/schema.sql` ganz unten die beiden Codes ersetzen:
   ```sql
   values (1, 'Team-Code-hier-eintragen', 'Trainerinnen-Code-hier-eintragen')
   ```
   Tipp: keine zu kurzen Codes, z. B. `Skull-Winter-26` und einen ganz anderen für die Trainerin. Groß-/Kleinschreibung ist egal.
2. In Supabase links **SQL Editor** → **New query**, den kompletten Inhalt einfügen und **Run** klicken.
   Die Warnung „destructive operations“ bestätigen – das Skript räumt nur die leeren Tabellen der ersten Version weg.

**Codes später ändern:** im SQL Editor
```sql
update public.wt_settings set team_code = 'Neuer-Team-Code', coach_code = 'Neuer-Trainerinnen-Code';
```
Wer mit dem alten Code angemeldet war, muss den neuen eingeben. Die Einträge bleiben erhalten.

> Achtung: Wird `schema.sql` später noch einmal komplett ausgeführt, werden die Codes auf die Werte im Skript zurückgesetzt. Die Einträge bleiben erhalten.

### 1b. Erweiterung „Wer macht was?“
Im SQL Editor eine **New query** öffnen, den Inhalt von `supabase/02_wer_macht_was.sql` einfügen und **Run** klicken. Die Codes und Trainingseinträge bleiben unverändert; die Ämter Bootsbauerin, Zeugwartin und Kassenwartin werden angelegt. Die Datei kann gefahrlos erneut ausgeführt werden.

> Wird `schema.sql` irgendwann erneut ausgeführt, danach auch `02_wer_macht_was.sql` noch einmal ausführen.

### 2. Zugangsdaten
In `config.js` stehen Project URL und der **publishable / anon** Key (Project Settings → API). Dieser Schlüssel ist öffentlich. **Niemals** den `secret`/`service_role` Key eintragen.

### 3. GitHub Pages einschalten
Im Repository **Settings → Pages → Build and deployment**: *Source* „Deploy from a branch“, Branch `main`, Ordner `/ (root)` → **Save**.
Nach ca. einer Minute ist die App erreichbar unter
`https://boerde-debug.github.io/HRC_Rennruderinnen_Wintertraining/`

Den Link und den Team-Code an die Mannschaft schicken – fertig.

## Zugriff & Datenschutz

- Ohne gültigen Code kommt niemand an Daten – die Tabellen sind nur über Funktionen erreichbar, die den Code prüfen.
- Mit dem **Team-Code** kann man Einträge unter jedem Namen lesen und schreiben sowie alle Aufgaben und Ämter bearbeiten (Vertrauensmodell innerhalb der Mannschaft). Die Übersicht aller Ruderinnen gibt es nur mit dem **Trainerinnen-Code**.
- Gespeichert werden nur der gewählte Name, die Gruppe und die Trainingseinträge – keine E-Mail-Adressen.
- Eine Ruderin löschen (mit allen Einträgen), im SQL Editor: `delete from public.wt_rowers where name = 'Name';`

## Gut zu wissen

- **Angemeldet bleiben:** Code und Name werden im Browser gespeichert. Auf einem neuen Gerät einfach Code eingeben und denselben Namen antippen – die bisherigen Einträge erscheinen wieder. Safari kann gespeicherte Daten nach ca. einer Woche ohne Besuch löschen; dann den Code erneut eingeben.
- **Pausierung:** Kostenlose Supabase-Projekte werden nach etwa einer Woche ohne Nutzung pausiert (z. B. über Weihnachten). Dann im Supabase-Dashboard **Restore project** klicken; die Daten bleiben erhalten.
- **Plan ändern:** In `index.html` die Einträge in `PLAN` bearbeiten. Die Einträge der Ruderinnen hängen an Wochennummer + Einheit (`w3-ergo`), nicht am Text.
- **Namen ergänzen:** In `index.html` die Liste `ROSTER` erweitern. Ruderinnen, die nicht in der Liste stehen, können sich auch selbst mit Namen und Gruppe eintragen.
