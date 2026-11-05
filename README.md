# Questkompass

Ruhige Questziel-Liste, Gebietsfortschritt und Quest-Tooltips für WoW Forever. Teil der ForeverUI-Reihe, mehr auf [foreverui.de](https://foreverui.de/addons/questkompass/).

## Was es kann

- **Einrichtungsassistent** beim ersten Start, später derselbe Dialog als Einstellungsfenster: Stil, Akzentfarbe, Lage, Sortierung, Navigation, Helfer und Profil.
- **Zielliste** in drei Stilen, sortiert nach Entfernung, Zone oder Questlog. Auf Wunsch mit einklappbaren Zonenüberschriften, Mausrad zum Blättern, Marken für Elite, Dungeon, täglich, „Neu“ und Gruppenmitglieder auf derselben Quest.
- **Navigation:** kleiner Kompasspfeil an jeder Quest, großer schwebender Fokuspfeil mit Entfernung und Ankunftszeit, automatischer Fokus auf die nächste Quest.
- **Questgegenstände** lassen sich direkt an der Quest benutzen. Quests mit Zeitlimit zeigen einen Countdown.
- **Erfahrungsvorschau:** was die fertigen Quests zusammen bringen, und ob es für den Stufenaufstieg reicht.
- **Questbuch** mit vier Reitern: Gebiet (alle Quests einer Zone mit Status), Welt (Fortschritt aller Zonen), Suche (alle Quests, deutsch und englisch) und Tagebuch (abgegebene Quests, Sitzungsstatistik mit EP pro Stunde).
- **Kleine Helfer:** Meldung und Klang bei Fortschritt, Fortschritt an die Gruppe, Warnung bei vollem Questlog, automatisch annehmen und abgeben (Umschalt hält an), Belohnungstipp, Knopf an der Minikarte.
- **Barrierefreiheit:** Vorlesen über die Sprachausgabe des Spiels, hoher Kontrast, Farbenblind-Modus (Blau/Orange, Status als Wort), alles größer (Liste bis 200 %), weniger Bewegung. Alles über Tastatur erreichbar.
- **Profile** für alle Charaktere oder einzeln, **Tastenkürzel** unter „AddOns“ in den Tastenbelegungen.
- **Quest-Tooltips:** Quest-Links im Chat zeigen Gebiet, Typ, Erfahrung und Ruf.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/qk` | Zielliste ein- oder ausblenden |
| `/qk einstellungen` | Einstellungsfenster |
| `/qk einrichten` | Einrichtungsassistent erneut starten |
| `/qk gebiet [Name]` | Gebietsfortschritt |
| `/qk buch` · `/qk welt` · `/qk tagebuch` | Questbuch |
| `/qk suche Text` | Quest suchen |
| `/qk naechste` | nächstgelegene Quest als Fokus |
| `/qk vorlesen` | Fokus-Quest vorlesen lassen |
| `/qk fokus` | Fokus aufheben |
| `/qk einblenden` | ausgeblendete Quests wieder zeigen |
| `/qk zuruecksetzen` | alle Einstellungen zurücksetzen |
| `/qk diagnose` · `/qk fehler` | technische Infos für Fehlerberichte |

## Entwicklung

- Questdaten neu erzeugen (mindestens alle 30 Tage):
  `BLIZZARD_CLIENT_ID=… BLIZZARD_CLIENT_SECRET=… node scripts/questdaten.mjs` schreibt `Daten/Quests.lua`.
- Testlauf ohne Spiel: `lua5.1 tests/simulation.lua`

Questdaten: Blizzard Entertainment, Battle.net Game Data API.
