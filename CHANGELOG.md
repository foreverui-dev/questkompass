# Questkompass

## 1.2.0

- Neu: Plugin für ForeverUI. Ist ForeverUI installiert, erscheinen die wichtigsten Einstellungen dort unter „Plugins“ (Stil, Lage, Größe, Breite, Sortierung, Pfeile, Meldungen, Tooltips, Automatik). Questkompass läuft weiter genauso auch ohne ForeverUI.
- Mit eingeschaltetem ForeverUI-Interface übernimmt Questkompass dessen Balkentextur und Akzentfarbe. Abschaltbar mit „Aussehen von ForeverUI übernehmen“.

**English**

- New: plugin for ForeverUI. With ForeverUI installed, the main settings appear there under “Plugins” (style, position, size, width, sorting, arrows, messages, tooltips, automation). Questkompass keeps working exactly the same without ForeverUI.
- With the ForeverUI interface turned on, Questkompass takes on its bar texture and accent colour. Can be turned off with “Use ForeverUI's look”.

## 1.1.0

- Neues Aussehen wie bei allen ForeverUI-Addons: Einstellungen und Questbuch in einem Fenster mit Seitenleiste (Questbuch, Darstellung, Funktionen, Zugang, Hilfe), Suche über alle Einstellungen und veränderbarer Größe, die gemerkt wird.
- Das Questbuch steht in der Seitenleiste, `/qk buch` öffnet und schließt es wie bisher.
- Sechs Akzentfarben (Gold, Klassenfarbe, Eis, Glut, Wald, Silber), ein Wechsel wirkt sofort. Smaragd wird zu Wald.
- Jede Einstellungsseite hat einen Knopf „Seite zurücksetzen“. Sprachwechsel ohne /reload, auch mit `/qk sprache`.
- Hilfe im Hauptfenster: Neuigkeiten (`/qk neu`), Discord und Feedback (`/qk feedback`), Fehler melden (`/qk fehlerbericht`).
- Teilen und Übernehmen (Einstellungen, fremder Text, Tagebuch als Text) im Hauptfenster statt eigenem Fenster.
- Hinweis nach einem Update und wenn jemand in Gruppe oder Gilde eine neuere Version hat.
- Gamepad: die Schultertasten blättern durch die Seitenleiste.
- Questgegenstände im Tooltip: für welche Quests ein Gegenstand gebraucht wird, auch bei deinen Twinks, mit Anzahl im Besitz und auf der Bank (`/qk gegenstaende`).
- Symbol an Quest-Gegnern an der Namensplakette mit Stand, in drei Größen (`/qk plaketten`), bei hohem Kontrast mit dunklem Hintergrund.
- Anvisierte Quest-Gegner markieren ihre Quest in der Liste, auf Wunsch mit Hinweiston.
- `/qk gegner` und Tastenkürzel: sagt alle Quest-Gegner in der Nähe mit Stand an.
- Händler-, Verkaufs-, Bank- und Beute-Hinweise für Questgegenstände.
- Questtext und Schwierigkeit als Wort im Tooltip der Liste, Ton bei jedem fertigen Ziel (optional).
- Stufenprognose im Tooltip der Erfahrungszeile, wöchentliche Quests mit Countdown.
- Leichen-Pfeil: nach dem Freilassen führt der Fokuspfeil zum Leichnam.
- `/qk pos` zeigt die eigene Position, `/qk weg teilen` schickt den Wegpunkt an die Gruppe.
- Geschätzte Restzeit der Route unter dem Fokuspfeil, Fokus springt nach einer fertigen Quest weiter (optional).
- `/qk sitzung`: Sitzungsbericht mit Dauer, Quests, EP pro Stunde, Gold und Prognose. `/qk tagebuchtext`: Tagebuch zum Kopieren.
- Die Suche findet Quests im Log auch über ihre Ziele und deine Notizen. Fünf neue Meilensteine.
- Geteilte Quests automatisch annehmen (optional), Gruppenquest-Warnung, Questdialog und Belohnungswahl vorlesen.
- Behoben: Fehlermeldungen durch geschützte Werte des Spiels („secret value“) in Fokuspfeil, Liste und Tooltips.
- Behoben: Belohnungs-Vergleich und Kartenpunkte auf WoW Forever, Fehler bei der Stufenprognose.
- Behoben: Das Fehlerprotokoll leert sich nach einem Update, `/qk fehler leeren` leert es von Hand.

**English**

- New look shared by all ForeverUI addons: settings and quest book in one window with a sidebar (Quest book, Display, Features, Access, Help), a search across all settings and an adjustable size that is remembered.
- The quest book lives in the sidebar, `/qk buch` opens and closes it as before.
- Six accent colors (Gold, class color, Ice, Ember, Forest, Silver), changes apply instantly. Emerald becomes Forest.
- Every settings page has a "Reset page" button. Switching language without /reload, also with `/qk sprache`.
- Help in the main window: What's new (`/qk news`), Discord and feedback (`/qk feedback`), Report a bug (`/qk bugreport`).
- Share and import (settings, someone else's text, journal as text) in the main window instead of a separate window.
- Notice after an update and when someone in your group or guild has a newer version.
- Gamepad: the shoulder buttons step through the sidebar.
- Quest items in the tooltip: which quests still need an item, for your alts too, with the amount in your bags and bank (`/qk gegenstaende`).
- Icon on quest enemies at the nameplate with progress, in three sizes (`/qk plaketten`), with a dark background in high contrast.
- Targeted quest enemies mark their quest in the list, with an optional sound.
- `/qk gegner` and a key binding announce all quest enemies nearby with progress.
- Vendor, selling, bank and loot hints for quest items.
- Quest text and difficulty as a word in the list tooltip, a sound for each finished objective (optional).
- Level forecast in the experience row tooltip, weekly quests with a countdown.
- Corpse arrow: after releasing, the focus arrow leads you to your corpse.
- `/qk pos` shows your position, `/qk weg teilen` sends your waypoint to the group.
- Estimated remaining route time below the focus arrow, focus moves on after a finished quest (optional).
- `/qk sitzung`: session report with duration, quests, XP per hour, gold and forecast. `/qk tagebuchtext`: journal as text.
- Search also finds quests in your log by their objectives and your notes. Five new milestones.
- Auto-accept shared quests (optional), group quest warning, quest dialogs and reward choice read aloud.
- Fixed: errors caused by protected game values ("secret value") in the focus arrow, list and tooltips.
- Fixed: reward comparison and map pins on WoW Forever, an error in the level forecast.
- Fixed: the error log clears itself after an update, `/qk fehler leeren` clears it by hand.

## 1.0.0 – erste öffentliche Version

20 neue Funktionen:

1. Quests oben anheften (Rechtsklick), angeheftete Quests stehen gleich nach dem Fokus
2. Fokusmodus: die Liste zeigt nur die Fokus-Quest (`/qk fokusmodus`, Tastenkürzel)
3. Symbole an den Zielen: Totenkopf für Gegner, Beutel für Gegenstände, Zahnrad für Objekte
4. Fertige Quests kompakt: nur der Titel mit Haken
5. Fortschritt je Quest in Prozent
6. Erholungsbonus in der Erfahrungszeile
7. Wegpunkt-Kette: mehrere Wegpunkte nacheinander (`/qk kette X Y`, Umschalt+Alt+Klick auf die Weltkarte)
8. Route mit Station und Restweg unter dem Fokuspfeil
9. Liegt das Ziel auf einer anderen Karte, nennt der Pfeil die Zone
10. „Was jetzt?“: Knopf in der Kopfzeile, Tastenkürzel und `/qk wasjetzt` wählen das sinnvollste nächste Ziel und lesen es vor
11. Questziele im Tooltip von Gegnern, z. B. „Die Jagd geht weiter: Bergpumapelz 3/10“
12. Questziele im Tooltip von Gegenständen
13. Neuer Reiter „Statistik“: Quests pro Tag der letzten 14 Tage, Summen und Lieblingsgebiet
14. Rekorde: bester Tag, schnellste und längste Quest, meiste EP
15. Dauer und Gold je Quest im Tagebuch
16. Filter im Gebiet-Reiter: alle, offen, im Log, erledigt
17. Merkliste: offene Quests im Questbuch per Rechtsklick merken, sie erscheinen im Planer
18. Tagesziel mit Anzeige in der Kopfzeile und Meldung beim Erreichen (`/qk tagesziel 10`)
19. Neue Quests in der Gruppe automatisch teilen; Warnung 60 und 10 Sekunden vor Ablauf eines Zeitlimits
20. Einstellungen teilen: als Text kopieren und bei Freunden oder Twinks einfügen (`/qk export`, `/qk import`)

Außerdem: neue Assistent-Seite „Feinschliff“ für alle neuen Schalter, alle neuen Texte auch auf Englisch.

## 0.5.0

20 neue Funktionen:

1. Gamepad und Pfeiltasten: Questbuch und Assistent lassen sich komplett mit Steuerkreuz, A, B und Schultertasten bedienen; neues Tastenkürzel „Fokus auf die vorige Quest“
2. Englische Oberfläche, automatisch nach Spielsprache oder fest per `/qk sprache de | en | auto`; englische Befehle wie `/qk settings` oder `/qk wp`
3. Mouseover-Modus: die Liste erscheint nur bei Maus oder wenn sich etwas ändert
4. Instanz-Modus und „im Kampf nur Fokus“
5. Route planen: kürzeste Reihenfolge durch alle Quests der Karte, der Fokuspfeil führt Station für Station (`/qk route`, Tastenkürzel, Rechtsklickmenü)
6. Eigene Wegpunkte mit `/qk weg 45 60 Name` oder Alt+Klick auf die Weltkarte; auch Wegpunkte des Spiels werden übernommen
7. Pfeil am Rand der Minikarte, wenn der Fokus außerhalb liegt
8. Abgabe-Erinnerung, wenn eine fertige Quest in der Nähe abgegeben werden kann
9. Stufenplaner im neuen Reiter „Planer“: EP, Quests und Spielzeit bis zur Wunschstufe
10. Questvorschläge: offene Quests in deiner Gegend
11. Ruf-Übersicht: was deine Quests je Fraktion bringen
12. Goldvorschau neben der Erfahrungsvorschau
13. Belohnungs-Vergleich: „besser +5“ an Belohnungen mit höherer Gegenstandsstufe als deine Ausrüstung
14. Tägliche Quests mit Countdown bis zum Zurücksetzen, in der Liste und im Planer
15. Twink-Hilfe: kontoweit sehen, welche Quests deine anderen Charaktere erledigt haben (`/qk twinks`)
16. Gruppen-Abgleich: Fortschritt der Mitspieler direkt unter der Quest, z. B. „Kumpel 3/8“
17. Gruppensuche: fertige Suchnachricht für Elite- und Gruppenquests
18. Meilensteine im neuen Reiter „Erfolge“ mit Meldung bei neuen Abzeichen
19. Notizen je Quest in Liste und Tooltip (`/qk notiz`)
20. Questlog aufräumen: graue, gescheiterte und lange liegende Quests, Abbrechen nur mit Rückfrage

Außerdem: neue Assistent-Seite „Noch mehr“ für alle neuen Schalter, Sprachwahl auf der Seite „Profil und Tasten“, breiteres Questbuch mit sechs Reitern.

## 0.4.0 – Barrierefreiheit

- Neue Seite „Barrierefreiheit“ gleich zu Beginn des Einrichtungsassistenten
- Vorlesen: Fortschritt, fertige Quests und „Am Ziel“ über die Sprachausgabe des Spiels; Tastenkürzel und /qk vorlesen lesen die Fokus-Quest mit offenen Zielen und Entfernung vor
- Hoher Kontrast: fast undurchsichtige Hintergründe, weiße Schrift, hellere Nebentexte
- Farbenblind-Modus: Blau und Orange statt Grün und Rot, Fokuspfeil mit Richtung in Worten, Status im Questbuch zusätzlich als Wort
- Alles größer: Questbuch, Assistent, Fokuspfeil, Menü und Meldungen um ein Viertel größer; die Liste lässt sich bis 200 % vergrößern
- Weniger Bewegung: Meldungen ohne Ein- und Ausblenden und doppelt so lange sichtbar

## 0.3.0

20 neue Funktionen:

1. Großer Fokuspfeil, frei schwebend, mit Entfernung und Ankunftszeit
2. Automatischer Fokus auf die nächstgelegene Quest
3. Knopf für Questgegenstände direkt an der Quest
4. Zonenüberschriften in der Liste, einklappbar
5. Gruppenmitglieder mit derselben Quest
6. Countdown für Quests mit Zeitlimit
7. Marken für Elite, Dungeon, Schlachtzug, täglich und wöchentlich
8. Graue Quests werden markiert und auf Wunsch ausgeblendet
9. Erfahrungsvorschau: was deine fertigen Quests zusammen bringen
10. Warnung, wenn das Questlog fast voll ist
11. Questtagebuch mit allen abgegebenen Quests
12. Sitzungsstatistik mit Quests und EP pro Stunde
13. Weltübersicht: Fortschritt aller Zonen
14. Suche über alle Quests, deutsch und englisch
15. Tastenkürzel (Liste, nächste Quest, Fokus weiter, Questbuch, Einstellungen)
16. Mausrad blättert durch lange Listen
17. Akzentfarben: Gold, Klassenfarbe, Eis, Smaragd
18. Fortschritt auf Wunsch in den Gruppenchat
19. Profile: Einstellungen für alle Charaktere oder nur für einen
20. Neue Quests sind zwei Minuten lang als „Neu“ markiert

Der Einrichtungsassistent hat dafür drei neue Seiten bekommen.

## 0.2.0

- Läuft jetzt mit der modernen Quest-API von WoW Forever (und weiter mit der klassischen)
- Einrichtungsassistent beim ersten Start, danach als Einstellungsfenster (Zahnrad, Rechtsklick auf die Liste, /qk einstellungen oder Spieleinstellungen)
- Drei Stile: Ruhig, Klassisch, Kompakt; Größe, Breite und vier Lagen wählbar
- Sortierung nach Entfernung, Zone oder Questlog; Entfernung in Metern
- Kompasspfeil an jeder Quest, Klick setzt den Fokus samt Navigationspfeil des Spiels
- Rechtsklick-Menü: Fokus, Questlog, Link, Teilen, Ausblenden
- Meldung und Klang, wenn ein Ziel oder eine Quest fertig ist
- Auf Wunsch Quests automatisch annehmen und abgeben (Umschalt hält an)
- Belohnungstipp: markiert die Belohnung mit dem höchsten Händlerwert
- Knopf an der Minikarte
- Gebietsfortschritt: „Hier“ wechselt zwischen Zone, Teilgebiet und Gebieten deiner Quests
- Fehler legen die Oberfläche nicht mehr lahm; /qk fehler und /qk diagnose helfen bei Berichten

## 0.1.0

- Zielliste neben der Minikarte: Quests der aktuellen Zone zuerst, Fortschritt als schmaler Balken, fertige Quests mit „Bereit zum Abgeben“
- Ruhemodus: im Kampf blendet sich die Liste halb aus
- Gebietsfortschritt: alle Quests einer Zone für deinen Charakter, erledigt, im Log oder offen, mit Erfahrung
- Quest-Links im Chat zeigen Gebiet, Typ, Erfahrung und Ruf
- Questdaten für WoW Forever (7.050 Quests in 139 Gebieten)
