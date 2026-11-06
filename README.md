# Questkompass

Ruhige Questziel-Liste, Gebietsfortschritt und Quest-Tooltips für WoW Forever. Teil der ForeverUI-Reihe, mehr auf [foreverui.de](https://foreverui.de/addons/questkompass/).

## Was es kann

- **Einrichtungsassistent** beim ersten Start, später derselbe Dialog als Einstellungsfenster: Stil, Akzentfarbe, Lage, Sortierung, Navigation, Helfer und Profil.
- **Zielliste** in drei Stilen, sortiert nach Entfernung, Zone oder Questlog. Auf Wunsch mit einklappbaren Zonenüberschriften, Mausrad zum Blättern, Marken für Elite, Dungeon, täglich, „Neu“ und Gruppenmitglieder auf derselben Quest.
- **Navigation:** kleiner Kompasspfeil an jeder Quest, großer schwebender Fokuspfeil mit Entfernung und Ankunftszeit, automatischer Fokus auf die nächste Quest.
- **Questgegenstände** lassen sich direkt an der Quest benutzen. Quests mit Zeitlimit zeigen einen Countdown.
- **Erfahrungsvorschau:** was die fertigen Quests zusammen bringen, und ob es für den Stufenaufstieg reicht.
- **Questbuch** mit sieben Reitern: Gebiet (alle Quests einer Zone mit Status), Welt (Fortschritt aller Zonen), Suche (alle Quests, deutsch und englisch), Tagebuch (abgegebene Quests, Sitzungsstatistik mit EP pro Stunde), Planer (Stufenplaner, Merkliste, Vorschläge, Ruf, tägliche Quests, Aufräumen), Erfolge (Meilensteine) und Statistik (Quests pro Tag, Rekorde). Das Gebiet lässt sich filtern.
- **„Was jetzt?“:** ein Knopf oder eine Taste wählt das sinnvollste nächste Ziel. Dazu Fokusmodus, angeheftete Quests, Symbole an den Zielen, Prozent je Quest und ein Tagesziel.
- **Questziele in Tooltips** von Gegnern und Gegenständen.
- **Route und Wegpunkte:** kürzeste Route durch alle Quests der Karte, eigene Wegpunkte und Wegpunkt-Ketten per Befehl oder Alt+Klick auf die Weltkarte, Pfeil am Minikartenrand, Abgabe-Erinnerung.
- **Gemeinschaft:** Twink-Hilfe (was andere Charaktere schon erledigt haben), Gruppen-Abgleich („Kumpel 3/8“), fertige Suchnachricht für Gruppenquests, Notizen je Quest.
- **Kleine Helfer:** Meldung und Klang bei Fortschritt, Fortschritt an die Gruppe, Warnung bei vollem Questlog, automatisch annehmen und abgeben (Umschalt hält an), Belohnungstipp, Knopf an der Minikarte.
- **Barrierefreiheit:** Vorlesen über die Sprachausgabe des Spiels, hoher Kontrast, Farbenblind-Modus (Blau/Orange, Status als Wort), alles größer (Liste bis 200 %), weniger Bewegung. Alles über Tastatur erreichbar, Questbuch und Assistent auch mit Gamepad und Pfeiltasten.
- **Sprachen:** Deutsch und Englisch, automatisch nach Spielsprache.
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
| `/qk route` | Route durch alle Quests der Karte planen oder beenden |
| `/qk weg X Y [Name]` | eigener Wegpunkt (`/qk weg` löscht ihn) |
| `/qk planer` · `/qk erfolge` | Planer und Meilensteine im Questbuch |
| `/qk notiz [Text]` | Notiz zur Fokus-Quest |
| `/qk twinks` | deine Charaktere und ihre erledigten Quests |
| `/qk wasjetzt` | das sinnvollste nächste Ziel als Fokus |
| `/qk kette X Y [Name]` | Wegpunkt hinten an die Kette hängen |
| `/qk fokusmodus` | Liste zeigt nur die Fokus-Quest |
| `/qk tagesziel N` | Tagesziel setzen (0 = aus) |
| `/qk statistik` | Quests pro Tag und Rekorde |
| `/qk export` · `/qk import` | Einstellungen als Text teilen |
| `/qk sprache de \| en \| auto` | Sprache der Oberfläche |
| `/qk fokus` | Fokus aufheben |
| `/qk einblenden` | ausgeblendete Quests wieder zeigen |
| `/qk zuruecksetzen` | alle Einstellungen zurücksetzen |
| `/qk diagnose` · `/qk fehler` | technische Infos für Fehlerberichte |

## Entwicklung

- Questdaten neu erzeugen (mindestens alle 30 Tage):
  `BLIZZARD_CLIENT_ID=… BLIZZARD_CLIENT_SECRET=… node scripts/questdaten.mjs` schreibt `Daten/Quests.lua`.
- Testlauf ohne Spiel: `lua5.1 tests/simulation.lua`

Questdaten: Blizzard Entertainment, Battle.net Game Data API.
