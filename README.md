# Questkompass

Ruhige Questziel-Liste, Gebietsfortschritt und Quest-Tooltips für WoW Forever. Teil der ForeverUI-Reihe, mehr auf [foreverui.de](https://foreverui.de/addons/questkompass/).

## Was es kann

- **Zielliste** neben der Minikarte. Quests der aktuellen Zone stehen oben, Ziele mit Zähler bekommen einen schmalen Fortschrittsbalken, fertige Quests zeigen „Bereit zum Abgeben“.
  Linksklick öffnet die Quest im Questlog, Umschalt+Klick setzt den Link in den Chat, Rechtsklick blendet sie aus.
- **Ruhemodus:** im Kampf wird die Liste halb durchsichtig.
- **Gebietsfortschritt** (Kartensymbol oben rechts oder `/qk gebiet`): alle Quests einer Zone, die zu Fraktion, Klasse und Volk deines Charakters passen, mit Status erledigt, im Log oder offen und der Erfahrung, die noch drin ist.
- **Quest-Tooltips:** Quest-Links im Chat zeigen Gebiet, Typ (Elite, Dungeon, Schlachtzug), Erfahrung und Ruf.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/qk` | Zielliste ein- oder ausblenden |
| `/qk gebiet [Name]` | Gebietsfortschritt der aktuellen oder einer genannten Zone |
| `/qk alle` · `/qk verfolgt` | alle Quests im Log oder nur verfolgte zeigen |
| `/qk anzahl 1-25` | wie viele Quests die Liste zeigt |
| `/qk sperren` · `/qk entsperren` | Liste fixieren oder verschiebbar machen |
| `/qk ruhe` | Ruhemodus im Kampf an/aus |
| `/qk blizzard` | Blizzard-Questverfolgung zeigen oder ausblenden |
| `/qk breite 160-400` · `/qk groesse 50-200` | Breite in Pixeln, Größe in Prozent |
| `/qk einblenden` | ausgeblendete Quests wieder zeigen |
| `/qk zuruecksetzen` | Position und Einstellungen zurücksetzen |

## Entwicklung

- Questdaten neu erzeugen (mindestens alle 30 Tage):
  `BLIZZARD_CLIENT_ID=… BLIZZARD_CLIENT_SECRET=… node scripts/questdaten.mjs` schreibt `Daten/Quests.lua`.
- Testlauf ohne Spiel: `lua5.1 tests/simulation.lua`
- Release: Tag `vX.Y.Z` pushen, der Workflow baut das Paket und lädt es zu CurseForge und Wago hoch.

Questdaten: Blizzard Entertainment, Battle.net Game Data API.
