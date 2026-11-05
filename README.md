# Questkompass

Ruhige Questziel-Liste, Gebietsfortschritt und Quest-Tooltips für WoW Forever. Teil der ForeverUI-Reihe, mehr auf [foreverui.de](https://foreverui.de/addons/questkompass/).

## Was es kann

- **Einrichtungsassistent** beim ersten Start: Stil, Lage, Verhalten und Helfer in vier Schritten, jede Wahl sofort sichtbar. Später derselbe Dialog als Einstellungsfenster.
- **Zielliste** mit drei Stilen (Ruhig, Klassisch, Kompakt). Sortiert nach Entfernung, Zone oder Questlog, mit Fortschrittsbalken und „Bereit zum Abgeben“.
- **Kompass:** Pfeil und Entfernung zu jedem Questziel auf der aktuellen Karte. Klick setzt die Quest als Fokus, das Spiel zeigt dann den Weg.
- **Rechtsklick-Menü:** Fokus, im Questlog öffnen, Link, mit der Gruppe teilen, ausblenden.
- **Ruhemodus:** im Kampf wird die Liste durchsichtig.
- **Gebietsfortschritt** (Kartensymbol, Minikarten-Knopf mit Umschalt oder `/qk gebiet`): alle Quests einer Zone für deinen Charakter, erledigt, im Log oder offen.
- **Kleine Helfer:** Meldung und Klang bei erfüllten Zielen, auf Wunsch automatisch annehmen und abgeben (Umschalt hält an), Belohnungstipp mit höchstem Händlerwert.
- **Quest-Tooltips:** Quest-Links im Chat zeigen Gebiet, Typ, Erfahrung und Ruf.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/qk` | Zielliste ein- oder ausblenden |
| `/qk einstellungen` | Einstellungsfenster |
| `/qk einrichten` | Einrichtungsassistent erneut starten |
| `/qk gebiet [Name]` | Gebietsfortschritt |
| `/qk fokus` | Fokus aufheben |
| `/qk einblenden` | ausgeblendete Quests wieder zeigen |
| `/qk zuruecksetzen` | alle Einstellungen zurücksetzen |
| `/qk diagnose` · `/qk fehler` | technische Infos für Fehlerberichte |

## Entwicklung

- Questdaten neu erzeugen (mindestens alle 30 Tage):
  `BLIZZARD_CLIENT_ID=… BLIZZARD_CLIENT_SECRET=… node scripts/questdaten.mjs` schreibt `Daten/Quests.lua`.
- Testlauf ohne Spiel: `lua5.1 tests/simulation.lua`

Questdaten: Blizzard Entertainment, Battle.net Game Data API.
