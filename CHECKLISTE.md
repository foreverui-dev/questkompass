# Prüfstandard vor jeder Veröffentlichung

Gilt für jede neue Version, wie bei allen ForeverUI-Addons. Teil 1 läuft automatisch, Teil 2 ist die Durchsicht von Hand.
Eine Version wird erst getaggt, wenn Teil 1 grün ist, Teil 2 abgehakt ist und Michel Ja sagt.

## Teil 1: automatisch

```
lua5.1 tools/pruefen.lua
```

Läuft auch bei jedem Push in GitHub (Workflow „Prüfen“). Geprüft wird:

1. **Dateien und Syntax:** Jede Datei aus der .toc existiert, jede Lua-Datei steht in der .toc, alle Dateien lassen sich laden.
2. **Globale Namen:** keine versehentlich globalen Variablen (vergessenes `local`), keine unbekannten Namen (Tippfehler). Neue Spielfunktionen in `tools/globale.txt` eintragen.
3. **Übersetzungen:** Jeder Text hat einen englischen Text mit denselben Platzhaltern (`%d`, `%s` ...). Ein falscher Platzhalter bringt die Meldung im Spiel zum Absturz.
4. **Version:** Version in der .toc = neuester Eintrag in CHANGELOG.md, mit **English**-Teil, `Aenderungen.lua` neu erzeugt.
5. **Hinweise und Reste:** keine verbotenen Hinweise, keine `print()`-Reste oder TODO, alle Commits von Syntaxlab.
6. **Testlauf:** `tests/simulation.lua` mit moderner und klassischer Quest-API.

## Teil 2: Durchsicht von Hand

Was kein Test sieht. Jeder Fund wird notiert als: Datei, Zeile, Problem, Vorschlag.

- [ ] **Geschützte Werte:** Wird mit Zahlen oder Texten gerechnet, verglichen oder indexiert, die das Spiel sperrt (Position, Laufgeschwindigkeit, Namen)? Immer `QK.Zahl` / `QK.Text` / `QK.XY` verwenden.
- [ ] **Tasten:** Fängt ein Fenster Enter, Pfeiltasten oder Gamepad ab, obwohl es nichts damit macht? Chat und Bewegung müssen frei bleiben.
- [ ] **Quests:** Stimmen Ziele, Entfernungen, Fokus und Route mit moderner und klassischer Quest-API?
- [ ] **Fremde Daten:** Wird alles gefiltert, was von anderen Spielern kommt (Gruppen-Abgleich, Wegpunkte, Versionen, eingefügte Einstellungen)? Keine Farb- oder Linkcodes übernehmen.
- [ ] **Ereignisse:** Wird nichts doppelt angemeldet, wird nichts gezeichnet, was nicht sichtbar ist?
- [ ] **Oberfläche:** Passt alles bei kleinster Fenstergröße (760 × 620) und mit „Alles größer“? Überlappt nichts? Stimmt alles auch auf Englisch? Design nach DESIGN.md des Forever DPS Meters.
- [ ] **Versprechen:** Kann das Addon im Spiel wirklich, was README, CurseForge-Text, .toc und Änderungsliste versprechen?
- [ ] **Speicher:** Wachsen die gespeicherten Daten nicht unbegrenzt? Jede Liste hat eine Obergrenze (Tagebuch 500, Fehler 20).
- [ ] **Neue Funktionen:** Gibt es für jede neue Funktion einen Test?
- [ ] **Fehlerprotokoll:** `QK.codeStand` in Core.lua hochgezählt, damit alte Fehler nach dem Update verschwinden.

## Teil 3: im Spiel (vor dem Tag)

- [ ] Spiel neu starten (neue Dateien) bzw. `/reload` ohne Fehlermeldung, `/qk fehler` leer
- [ ] Quest annehmen, Ziel erfüllen, abgeben: Liste, Fokuspfeil, Meldungen plausibel
- [ ] Hauptfenster öffnen, durch alle Seiten der Seitenleiste klicken, auch das Questbuch
- [ ] mit offenem Hauptfenster per Enter chatten
- [ ] mit ForeverUI: unter /fui > Plugins > Questkompass Einstellungen ändern, wirkt sofort; Interface an: Balken und Akzent wie ForeverUI

## Veröffentlichung

1. Version in `Questkompass.toc` erhöhen, CHANGELOG.md (Deutsch und **English**), `lua5.1 tools/aenderungen.lua > Aenderungen.lua`.
2. `lua5.1 tools/pruefen.lua` grün, Teil 2 und 3 abgehakt.
3. Push auf main, Michels Ja, dann Tag `vX.Y.Z` vom Mac pushen. Der Workflow lädt zu CurseForge.
4. Release-Lauf prüfen: Upload ok, im Paket steht die richtige Version.
