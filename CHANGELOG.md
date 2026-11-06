# Questkompass

## 1.1.0

- Questgegenstände: Im Tooltip eines Gegenstands steht, für welche Quests er noch gebraucht wird
  - eigene Quests im Log mit Stand, bei fertigem Ziel der Hinweis „bis zur Abgabe behalten“
  - Quests deiner anderen Charaktere (praktisch an der Bank)
  - Quests, die das Addon schon einmal mit diesem Gegenstand gesehen hat und die dieser Charakter noch machen kann
- Questkompass lernt diese Gegenstände kontoweit aus dem Questlog aller Charaktere und wird so mit der Zeit vollständiger
- `/qk gegenstaende` listet alles, was deine Quests gerade brauchen
- Auch in verlinkten Gegenständen im Chat; im Assistenten unter „Feinschliff“ abschaltbar
- Symbol an Quest-Gegnern: Gegner in der Nähe, die du für eine Quest besiegen musst, bekommen einen Totenkopf an der Namensplakette, bei Questgegenständen einen Beutel, dazu den Stand (z. B. 3/10). Braucht eingeblendete Namensplaketten (Taste V)

Behoben:

- Fehlermeldungen von Fokuspfeil und Zielliste („secret number value“): Laufgeschwindigkeit, Position und Blickrichtung, die das Spiel geschützt liefert, werden jetzt übersprungen statt verglichen
- Belohnungs-Markierung und Belohnungs-Vergleich liefen ins Leere, weil der Client GetItemInfo nur noch unter C_Item anbietet

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
