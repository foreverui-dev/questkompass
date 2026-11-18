-- Questkompass: Hauptfenster im ForeverUI-Design. Beim ersten Start führt es als Assistent
-- Schritt für Schritt durch die Einstellungen; danach ist es das Einstellungsfenster mit
-- Seitenleiste, Suche und eingebetteten Bereichen (Questbuch aus Gebiet.lua, Hilfe aus Hilfe.lua, Neuigkeiten).
local ADDON, QK = ...
local A = QK:Modul("Assistent")
local L = QK.L
local UI = QK.UI

A.ASSISTENT_SEITEN = 12              -- Seiten des Einrichtungsassistenten, danach nur Einstellungen

local fenster, seitenTitel, punkte, zurueck, weiter, inhalt
local seiten, seite, alsEinstellungen = {}, 1, false
local auswahl, markierung = 0, nil   -- Gamepad/Tastatur
local navi = {}                      -- Knöpfe der Seitenleiste
local bereiche, bereich = {}, nil    -- eingebettete Bereiche und der offene
local GOLD = QK.farben.gold
A.bereiche = bereiche
local goldTexte = {}                 -- { fontstring, Text mit |cfff2c45a }
local Gold = UI.Gold

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------
local Rahmen = UI.Rahmen
A.RandFarbe = UI.RandFarbe

local bauSeite                       -- Seite, die gerade gebaut wird (für die Suche)
local function Text(eltern, schrift, text, breite)
  if bauSeite and type(text) == "string" and text ~= "" then bauSeite.such[#bauSeite.such + 1] = text end
  local t = eltern:CreateFontString(nil, "OVERLAY", schrift)
  t:SetJustifyH("LEFT")
  t:SetJustifyV("TOP")
  if breite then t:SetWidth(breite) end
  t:SetText(text)
  if type(text) == "string" and text:find("|cfff2c45a", 1, true) then goldTexte[#goldTexte + 1] = { t, text } end
  return t
end

function A:FarbeAuffrischen()
  for _, e in ipairs(goldTexte) do e[1]:SetText((e[2]:gsub("|cfff2c45a", QK.gold))) end
end

-- Auswahlkarte: Titel, Beschreibung, in Akzentfarbe umrandet, wenn gewählt.
local function Karte(eltern, titel, text, breite, hoehe, istGewaehlt, waehlen)
  local k = CreateFrame("Button", nil, eltern)
  k:SetSize(breite, hoehe)
  Rahmen(k, 0.6, { 1, 1, 1, 0.12 })
  k.titel = Text(k, "GameFontNormal", titel, breite - 20)
  k.titel:SetPoint("TOPLEFT", 10, -10)
  k.text = Text(k, "GameFontHighlightSmall", text, breite - 20)
  k.text:SetPoint("TOPLEFT", k.titel, "BOTTOMLEFT", 0, -4)
  k.text:SetTextColor(0.75, 0.75, 0.75)
  local hl = k:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  k.Auffrischen = function()
    local an = istGewaehlt()
    A.RandFarbe(k, an and { GOLD[1], GOLD[2], GOLD[3], 0.9 } or { 1, 1, 1, 0.12 })
    if an then k.hg:SetColorTexture(GOLD[1] * 0.17, GOLD[2] * 0.17, GOLD[3] * 0.17, 0.7)
    else k.hg:SetColorTexture(0.06, 0.06, 0.08, 0.7) end
  end
  k:SetScript("OnClick", function()
    waehlen()
    QK:Anwenden()
    A:Auffrischen()
  end)
  k.knopf = k
  k.vorlesen = titel .. ". " .. (text or "")
  return k
end

-- Schalter mit Beschriftung und Erklärung.
-- Schalter im ForeverUI-Stil „Klar“ (statt Häkchen): Spur in Akzentfarbe, wenn an, weißer Knopf wandert
-- nach rechts. Verhält sich wie ein CheckButton (SetChecked, GetChecked, OnClick schaltet vorher um).
local function Umschalter(eltern)
  local c = CreateFrame("Button", nil, eltern)
  c:SetSize(34, 18)
  local spur = c:CreateTexture(nil, "BACKGROUND")
  spur:SetAllPoints()
  local knopf = c:CreateTexture(nil, "ARTWORK")
  knopf:SetSize(14, 14)
  knopf:SetColorTexture(1, 1, 1, 1)
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  c.an = false
  c.SetChecked = function(self, an)
    self.an = an and true or false
    knopf:ClearAllPoints()
    if self.an then
      local a = QK.farben.gold
      spur:SetColorTexture(a[1], a[2], a[3], 1)
      knopf:SetPoint("RIGHT", -2, 0)
    else
      spur:SetColorTexture(1, 1, 1, 0.18)
      knopf:SetPoint("LEFT", 2, 0)
    end
  end
  c.GetChecked = function(self) return self.an end
  local setze = c.SetScript
  c.SetScript = function(self, name, fn)
    if name == "OnClick" and fn then
      return setze(self, name, function(s, ...) s:SetChecked(not s.an); return fn(s, ...) end)
    end
    return setze(self, name, fn)
  end
  c:SetChecked(false)
  return c
end

local function Schalter(eltern, titel, text, schluessel, nachher)
  local f = CreateFrame("Frame", nil, eltern)
  f:SetSize(240, 40)
  local c = Umschalter(f)
  c:SetPoint("TOPLEFT", 0, -2)
  local l = Text(f, "GameFontHighlight", titel, 192)
  l:SetPoint("TOPLEFT", 42, -3)
  local d = Text(f, "GameFontDisableSmall", text or "", 192)
  d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
  if bauSeite then bauSeite.schluessel[#bauSeite.schluessel + 1] = schluessel end
  c:SetScript("OnClick", function(self)
    QK.db[schluessel] = self:GetChecked() and true or false
    if nachher then nachher(QK.db[schluessel]) end
    QK:Anwenden()
  end)
  f.Auffrischen = function() c:SetChecked(QK.db[schluessel] and true or false) end
  f.knopf = c
  f.vorlesen = titel .. ". " .. (text or "")
  return f
end

local function Absatz(eltern, text, y)
  local t = Text(eltern, "GameFontHighlight", text, 500)
  t:SetPoint("TOPLEFT", 0, y or 0)
  t:SetSpacing(3)
  return t
end

---------------------------------------------------------------------------
-- Seiten
---------------------------------------------------------------------------
local function NeueSeite(titel, bauen)
  local s = CreateFrame("Frame", nil, inhalt)
  s:SetAllPoints()
  s.titel = titel
  s.elemente = {}
  s.such = { titel }
  s.schluessel = {}
  bauSeite = s
  bauen(s, function(e) s.elemente[#s.elemente + 1] = e; return e end)
  bauSeite = nil
  s:Hide()
  seiten[#seiten + 1] = s
end

local function Raster(s, merke, liste, y, zeilenHoehe)
  for i, e in ipairs(liste) do
    local f = merke(Schalter(s, e[1], e[2], e[3], e[4]))
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 255, y - math.floor((i - 1) / 2) * (zeilenHoehe or 48))
  end
end

local function SeitenBauen()
  NeueSeite(L"Willkommen", function(s)
    Absatz(s, L"Schön, dass du da bist!\n\nQuestkompass zeigt dir ruhig und übersichtlich, was als Nächstes zu tun ist: "
      .. L"welche Quest am nächsten liegt, in welche Richtung du laufen musst und wie weit du bist.\n\n"
      .. L"In ein paar kurzen Schritten stellst du alles nach deinem Geschmack ein. Jede Wahl siehst du sofort. "
      .. L"Später erreichst du diese Einstellungen per Rechtsklick auf die Liste, über das Zahnrad oder mit |cfff2c45a/qk einstellungen|r.")
    local tipp = Text(s, "GameFontDisableSmall", L"Keine Lust auf Einstellungen? Klick einfach auf „Fertig“, die Standardwerte passen für die meisten.", 500)
    tipp:SetPoint("BOTTOMLEFT", 0, 4)
  end)

  NeueSeite(L"Barrierefreiheit", function(s, merke)
    local t = Text(s, "GameFontHighlight", L"Questkompass soll für alle gut nutzbar sein. Stell hier ein, was dir hilft. "
      .. L"Alles lässt sich später unter |cfff2c45a/qk einstellungen|r ändern.", 500)
    t:SetPoint("TOPLEFT", 0, 0)
    Raster(s, merke, {
      { L"Vorlesen", L"Fortschritt und fertige Quests per Sprachausgabe.", "vorlesen" },
      { L"Hoher Kontrast", L"Dunklerer Hintergrund, hellere Schrift.", "kontrast" },
      { L"Farbenblind-Modus", L"Blau und Orange statt Grün und Rot, Status als Wort.", "farbenblind" },
      { L"Alles größer", L"Fenster, Pfeil und Meldungen um ein Viertel größer.", "allesGroesser" },
      { L"Weniger Bewegung", L"Keine Einblendungen, Meldungen bleiben länger.", "wenigerBewegung" },
    }, -44, 52)
    local test = QK.FlachKnopf(s)
    test:SetSize(150, 22)
    test:SetText(L"Vorlesen testen")
    test:SetPoint("TOPLEFT", 255, -158)
    test:SetScript("OnClick", function()
      if not QK:Sprechen(L"Hallo! So klingt Questkompass.", true) then
        QK:Meldung(L"die Sprachausgabe ist nicht verfügbar. In den Spieleinstellungen unter Barrierefreiheit › Text-zu-Sprache lässt sie sich einrichten.")
      end
    end)
    local tipp = Text(s, "GameFontDisableSmall", L"Tastenkürzel „Fokus-Quest vorlesen“ und |cfff2c45a/qk vorlesen|r lesen die aktuelle Quest jederzeit vor. "
      .. L"Die Liste selbst kannst du auf der nächsten Seite bis 200 % vergrößern.", 500)
    tipp:SetPoint("TOPLEFT", 0, -218)
  end)

  NeueSeite(L"Wie soll die Liste aussehen?", function(s, merke)
    local x = 0
    for _, id in ipairs({ "ruhig", "klassisch", "kompakt" }) do
      local beschreibung = ({
        ruhig = L"Dunkler, halb durchsichtiger Hintergrund, Fortschrittsbalken. Unsere Empfehlung.",
        klassisch = L"Ohne Hintergrund, größere Schrift, wie die Questverfolgung des Spiels.",
        kompakt = L"Kleine Schrift, nur das nächste Ziel je Quest. Viele Quests auf wenig Platz.",
      })[id]
      local k = merke(Karte(s, QK.STILE[id].name, beschreibung, 160, 92,
        function() return QK.db.stil == id end,
        function() QK.db.stil = id; QK.db.anzahl = QK.STILE[id].anzahl end))
      k:SetPoint("TOPLEFT", x, 0)
      x = x + 170
    end
    local a = Text(s, "GameFontNormal", L"Akzentfarbe", 200)
    a:SetPoint("TOPLEFT", 0, -106)
    for i, id in ipairs(QK.AKZENT_REIHE) do
      local k = merke(Karte(s, QK.AKZENTE[id][1], "", 80, 30,
        function() return QK.db.akzent == id end,
        function() QK.db.akzent = id; QK:AkzentAnwenden() end))
      k:SetPoint("TOPLEFT", (i - 1) * 85, -124)
      k.titel:ClearAllPoints()
      k.titel:SetPoint("LEFT", 8, 0)
      k.titel:SetWidth(52)
      local farbe = k:CreateTexture(nil, "ARTWORK")
      farbe:SetSize(10, 10)
      farbe:SetPoint("RIGHT", -8, 0)
      local alt = k.Auffrischen
      k.Auffrischen = function()
        local merk = QK.db.akzent
        QK.db.akzent = id; QK:AkzentAnwenden()
        farbe:SetColorTexture(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 1)
        QK.db.akzent = merk; QK:AkzentAnwenden()
        alt()
      end
    end
    local g = Text(s, "GameFontNormal", L"Größe", 200)
    g:SetPoint("TOPLEFT", 0, -180)
    local wert = Text(s, "GameFontHighlight", "", 60)
    wert:SetJustifyH("CENTER")
    wert:SetPoint("TOPLEFT", 110, -180)
    local function schritt(d)
      QK.db.skalierung = math.max(0.6, math.min(2.0, (QK.db.skalierung or 1) + d))
      QK:Anwenden(); A:Auffrischen()
    end
    local minus = QK.FlachKnopf(s)
    minus:SetSize(26, 20); minus:SetText("–"); minus:SetPoint("TOPLEFT", 80, -176)
    minus:SetScript("OnClick", function() schritt(-0.1) end)
    local plus = QK.FlachKnopf(s)
    plus:SetSize(26, 20); plus:SetText("+"); plus:SetPoint("TOPLEFT", 175, -176)
    plus:SetScript("OnClick", function() schritt(0.1) end)
    local b = Text(s, "GameFontNormal", L"Breite", 200)
    b:SetPoint("TOPLEFT", 260, -180)
    local bwert = Text(s, "GameFontHighlight", "", 60)
    bwert:SetJustifyH("CENTER")
    bwert:SetPoint("TOPLEFT", 370, -180)
    local function bschritt(d)
      QK.db.breite = math.max(180, math.min(400, (QK.db.breite or 240) + d))
      QK:Anwenden(); A:Auffrischen()
    end
    local bminus = QK.FlachKnopf(s)
    bminus:SetSize(26, 20); bminus:SetText("–"); bminus:SetPoint("TOPLEFT", 340, -176)
    bminus:SetScript("OnClick", function() bschritt(-20) end)
    local bplus = QK.FlachKnopf(s)
    bplus:SetSize(26, 20); bplus:SetText("+"); bplus:SetPoint("TOPLEFT", 435, -176)
    bplus:SetScript("OnClick", function() bschritt(20) end)
    merke({ Auffrischen = function()
      wert:SetText(("%d %%"):format(math.floor((QK.db.skalierung or 1) * 100 + 0.5)))
      bwert:SetText(("%d"):format(QK.db.breite or 240))
    end })
    local tipp = Text(s, "GameFontDisableSmall", L"Die Liste neben dem Fenster zeigt deine Wahl sofort.", 500)
    tipp:SetPoint("TOPLEFT", 0, -216)
  end)

  NeueSeite(L"Wo soll die Liste stehen?", function(s, merke)
    local lagen = {
      { "minimap", L"Unter der Minikarte", L"Dort, wo sonst die Questverfolgung steht." },
      { "rechts", L"Rechts am Rand", L"Mittig am rechten Bildschirmrand." },
      { "links", L"Links am Rand", L"Gut, wenn rechts schon Leisten sitzen." },
      { "frei", L"Frei verschieben", L"Zieh die Liste an ihrer Kopfzeile, wohin du willst." },
    }
    for i, l in ipairs(lagen) do
      local k = merke(Karte(s, l[2], l[3], 245, 62,
        function() return QK.db.lage == l[1] end,
        function()
          if l[1] == "frei" then
            QK.db.gesperrt = false
            local f = QuestkompassListe
            if f then
              local p, _, rp, x, y = f:GetPoint()
              QK.db.pos = { p, rp, x, y }
            end
          end
          QK.db.lage = l[1]
        end))
      k:SetPoint("TOPLEFT", ((i - 1) % 2) * 255, -math.floor((i - 1) / 2) * 72)
    end
    local f = merke(Schalter(s, L"Liste fixieren", L"Verhindert versehentliches Verschieben.", "gesperrt"))
    f:SetPoint("TOPLEFT", 0, -160)
  end)

  NeueSeite(L"Sortierung und Anzeige", function(s, merke)
    local sort = {
      { "entfernung", L"Nächste zuerst", L"Quests nach Entfernung sortiert." },
      { "zone", L"Nach Zone", L"Aktuelle Zone oben, fertige Quests zuerst." },
      { "log", L"Wie im Questlog", L"Gleiche Reihenfolge wie im Spiel." },
    }
    for i, e in ipairs(sort) do
      local k = merke(Karte(s, e[2], e[3], 160, 62,
        function() return QK.db.sortierung == e[1] end,
        function() QK.db.sortierung = e[1] end))
      k:SetPoint("TOPLEFT", (i - 1) * 170, 0)
    end
    merke({ Auffrischen = function() QK.db._nurVerfolgt = QK.db.modus == "verfolgt" end })
    Raster(s, merke, {
      { L"Questverfolgung ersetzen", L"Blendet die Liste des Spiels aus.", "blizzardAusblenden" },
      { L"Nach Zonen gruppieren", L"Überschriften, die sich einklappen lassen.", "gruppen" },
      { L"Ruhemodus im Kampf", L"Liste wird im Kampf durchsichtig.", "ruhemodus" },
      { L"Nur verfolgte Quests", L"Zeigt nur, was du verfolgst.", "_nurVerfolgt", function(an) QK.db.modus = an and "verfolgt" or "alle" end },
      { L"Graue Quests ausblenden", L"Quests, die kaum noch Erfahrung bringen.", "graueAusblenden" },
      { L"Neue Quests markieren", L"Zwei Minuten lang mit „Neu“.", "neuMarkierung" },
    }, -78)
  end)

  NeueSeite(L"Navigation", function(s, merke)
    local t = Text(s, "GameFontHighlight", L"Questkompass führt dich zum Ziel. Klick in der Liste auf eine Quest, um sie als Fokus zu setzen.", 500)
    t:SetPoint("TOPLEFT", 0, 0)
    Raster(s, merke, {
      { L"Kompasspfeile", L"Kleiner Pfeil an jeder Quest.", "pfeil" },
      { L"Großer Fokuspfeil", L"Schwebender Pfeil mit Entfernung und Ankunftszeit.", "pfeilGross" },
      { L"Automatischer Fokus", L"Ohne Fokus wird die nächste Quest gewählt.", "autoFokus" },
      { L"Questgegenstände", L"Knopf zum Benutzen direkt an der Quest.", "questItems" },
      { L"Gruppenmitglieder zeigen", L"Wer aus der Gruppe dieselbe Quest hat.", "mitspieler" },
      { L"Erfahrungsvorschau", L"Was deine fertigen Quests zusammen bringen.", "epVorschau" },
    }, -40)
  end)

  NeueSeite(L"Kleine Helfer", function(s, merke)
    Raster(s, merke, {
      { L"Meldung bei Fortschritt", L"Kurzer Hinweis, wenn ein Ziel erfüllt ist.", "meldungen" },
      { L"Klang bei fertiger Quest", L"Damit du nichts verpasst.", "klang" },
      { L"Fortschritt an die Gruppe", L"Schreibt Fortschritte in den Gruppenchat.", "gruppenMeldungen" },
      { L"Warnung bei vollem Questlog", L"Kurz bevor kein Platz mehr frei ist.", "logWarnung" },
      { L"Quests automatisch annehmen", L"Halte Umschalt gedrückt, um es auszusetzen.", "autoAnnehmen" },
      { L"Quests automatisch abgeben", L"Nur ohne Belohnungswahl. Umschalt hält an.", "autoAbgeben" },
      { L"Belohnungstipp", L"Markiert die Belohnung mit dem höchsten Wert.", "belohnungsTipp" },
      { L"Knopf an der Minikarte", L"Schneller Zugriff auf Liste und Questbuch.", "minimapKnopf" },
    }, 0, 52)
  end)

  NeueSeite(L"Noch mehr", function(s, merke)
    Raster(s, merke, {
      { L"Nur bei Mauskontakt", L"Liste erscheint bei Maus oder Änderung.", "mouseover" },
      { L"Instanz-Modus", L"Im Dungeon nur dessen Quests.", "instanzModus" },
      { L"Im Kampf nur Fokus", L"Zeigt im Kampf nur die Fokus-Quest.", "kampfNurFokus" },
      { L"Pfeil an der Minikarte", L"Zeigt zum Fokus, wenn er weiter weg ist.", "minimapPfeil" },
      { L"Abgabe-Erinnerung", L"Hinweis, wenn eine Abgabe in der Nähe ist.", "abgabeErinnerung" },
      { L"Goldvorschau", L"Gold der fertigen Quests neben den EP.", "goldVorschau" },
      { L"Belohnungs-Vergleich", L"Markiert bessere Ausrüstung bei der Wahl.", "belohnungsVergleich" },
      { L"Tägliche Quests", L"Zeile mit Countdown bis zum Zurücksetzen.", "taeglichZeile" },
      { L"Gruppen-Abgleich", L"Fortschritt der Gruppe (mit Questkompass).", "gruppenAbgleich" },
      { L"Notizen in der Liste", L"Eigene Notizen unter der Quest.", "notizenZeigen" },
      { L"Twink-Hilfe", L"Was deine anderen Charaktere schon erledigt haben.", "twinks" },
      { L"Meilensteine melden", L"Meldung bei einem neuen Abzeichen.", "erfolgMeldungen" },
    }, 0, 46)
  end)

  NeueSeite(L"Feinschliff", function(s, merke)
    Raster(s, merke, {
      { L"Symbole an Zielen", L"Totenkopf, Beutel und Zahnrad zeigen die Art.", "zielSymbole" },
      { L"Fertige Quests kompakt", L"Nur der Titel mit Haken.", "fertigKompakt" },
      { L"Fortschritt in Prozent", L"Gesamtstand jeder Quest neben dem Titel.", "prozent" },
      { L"Erholungsbonus zeigen", L"Erholte EP in der Erfahrungszeile.", "erholung" },
      { L"Ziele in Tooltips", L"Gegner und Gegenstände zeigen deine Questziele.", "tooltipZiele" },
      { L"Questgegenstände", L"Am Gegenstand: für welche Quests er noch gebraucht wird.", "questGegenstaende" },
      { L"Symbol an Quest-Gegnern", L"Totenkopf oder Beutel an der Namensplakette.", "questPlaketten" },
      { L"Automatisch teilen", L"Neue Quests in der Gruppe teilen.", "autoTeilen" },
      { L"Zeitlimit-Warnung", L"Hinweis 60 und 10 Sekunden vor Ablauf.", "zeitWarnung" },
      { L"Fokusmodus", L"Liste zeigt nur die Fokus-Quest.", "fokusModus" },
    }, 0, 42)
    local t = Text(s, "GameFontNormal", L"Tagesziel", 120)
    t:SetPoint("TOPLEFT", 0, -214)
    local wert = Text(s, "GameFontHighlight", "", 90)
    wert:SetJustifyH("CENTER")
    wert:SetPoint("TOPLEFT", 120, -214)
    local function schritt(d)
      QK.db.tagesziel = math.max(0, math.min(200, (QK.db.tagesziel or 0) + d))
      QK:Anwenden(); A:Auffrischen()
    end
    local minus = QK.FlachKnopf(s)
    minus:SetSize(26, 20); minus:SetText("–"); minus:SetPoint("TOPLEFT", 90, -210)
    minus:SetScript("OnClick", function() schritt(-5) end)
    local plus = QK.FlachKnopf(s)
    plus:SetSize(26, 20); plus:SetText("+"); plus:SetPoint("TOPLEFT", 215, -210)
    plus:SetScript("OnClick", function() schritt(5) end)
    merke({ Auffrischen = function()
      local n = QK.db.tagesziel or 0
      wert:SetText(n > 0 and (L"%d Quests"):format(n) or L"aus")
    end })
    local teilen = QK.FlachKnopf(s)
    teilen:SetSize(200, 22)
    teilen:SetText(L"Einstellungen teilen")
    teilen:SetPoint("TOPLEFT", 255, -210)
    teilen:SetScript("OnClick", function() A:Teilen("export") end)
    local tipp = Text(s, "GameFontDisableSmall", L"Mit „Einstellungen teilen“ gibst du deine Einstellungen als Text weiter, z. B. an Freunde oder deinen Twink.", 500)
    tipp:SetPoint("TOPLEFT", 0, -248)
  end)

  NeueSeite(L"Unterwegs", function(s, merke)
    Raster(s, merke, {
      { L"Leichen-Pfeil", L"Nach dem Tod führt der Pfeil zum Leichnam.", "leichenPfeil" },
      { L"Fokus springt weiter", L"Fertige Fokus-Quest: nächste rückt nach.", "fokusWeiter" },
      { L"Anvisierte Gegner", L"Ihre Quest wird in der Liste markiert.", "zielHervorheben" },
      { L"Ton bei Quest-Gegnern", L"Kurzer Hinweis, wenn einer auftaucht.", "questGegnerTon" },
      { L"Questtext im Tooltip", L"Auftrag und Schwierigkeit in der Liste.", "questText" },
      { L"Ton bei jedem Ziel", L"Nicht nur, wenn die Quest fertig ist.", "zielKlang" },
      { L"Verkaufswarnung", L"Questgegenstand verkauft? Hinweis mit Rückkauf.", "verkaufsWarnung" },
      { L"Händler-Hinweis", L"Im Chat: Händler verkauft etwas für deine Quests, Beute wird später noch gebraucht.", "haendlerHinweis" },
      { L"Bank-Hinweis", L"Was deine Twinks noch sammeln.", "bankHinweis" },
      { L"Sitzung und Prognose", L"EP pro Stunde und nächste Stufe im Tooltip.", "prognose" },
      { L"Geteilte Quests annehmen", L"Von Gruppenmitgliedern, Umschalt hält an.", "geteiltAnnehmen" },
      { L"Gruppenquest-Warnung", L"Hinweis beim Lesen einer Gruppenquest.", "gruppenWarnung" },
      { L"Dialoge vorlesen", L"Questtext und Belohnungen, wenn Vorlesen an ist.", "dialogVorlesen" },
    }, 0, 40)
  end)

  NeueSeite(L"Profil und Tasten", function(s, merke)
    local profile = {
      { "konto", L"Für alle Charaktere", L"Eine Einstellung für deinen ganzen Account." },
      { "eigen", L"Nur für diesen Charakter", L"Eigene Einstellungen, z. B. für einen Twink." },
    }
    for i, p in ipairs(profile) do
      local k = merke(Karte(s, p[2], p[3], 245, 62,
        function() return (QK.char.profil or "konto") == p[1] end,
        function() QK:ProfilWechseln(p[1]) end))
      k:SetPoint("TOPLEFT", (i - 1) * 255, 0)
    end
    local t = Text(s, "GameFontHighlightSmall", L"|cfff2c45aTastenkürzel|r findest du in den Tastenbelegungen des Spiels unter „AddOns“ › „Questkompass“, "
      .. L"mit Gamepad auch für Controllertasten.\n\n"
      .. L"|cfff2c45aGamepad und Pfeiltasten|r: In Questbuch und Assistent wählt das Steuerkreuz aus, A bestätigt, B schließt, "
      .. L"die Schultertasten wechseln Reiter und Seiten.\n\n"
      .. L"|cfff2c45a/qk hilfe|r zeigt alle Chatbefehle.", 500)
    t:SetPoint("TOPLEFT", 0, -78)
    t:SetSpacing(3)
    local sprache = Text(s, "GameFontNormal", L"Sprache", 120)
    sprache:SetPoint("TOPLEFT", 0, -238)
    for i, e in ipairs({ { "auto", L"Wie das Spiel" }, { "de", "Deutsch" }, { "en", "English" } }) do
      local k = merke(Karte(s, e[2], "", 120, 30,
        function() return (QK.db.sprache or "auto") == e[1] end,
        function()
          QK.db.sprache = e[1]
          QK:SpracheAnwenden()
          C_Timer.After(0, function() A:Neubauen() end)
        end))
      k:SetPoint("TOPLEFT", 90 + (i - 1) * 130, -230)
    end
  end)

  NeueSeite(L"Alles bereit!", function(s)
    Absatz(s, L"So bedienst du Questkompass:\n\n"
      .. L"|cfff2c45aKlick|r auf eine Quest setzt sie als Fokus, Pfeil und Navigation zeigen den Weg.\n"
      .. L"|cfff2c45aRechtsklick|r öffnet weitere Möglichkeiten wie Teilen oder Ausblenden.\n"
      .. L"|cfff2c45aMausrad|r über der Liste blättert, wenn es mehr Quests gibt.\n"
      .. L"|cfff2c45aKartensymbol|r öffnet das Questbuch: Gebiet, Welt, Suche, Tagebuch, Planer und Erfolge.\n"
      .. L"|cfff2c45a/qk route|r plant den kürzesten Weg, |cfff2c45a/qk weg 45 60|r setzt einen Wegpunkt.\n"
      .. L"|cfff2c45aZahnrad|r oder |cfff2c45a/qk einstellungen|r: hierher zurück.\n\n"
      .. L"Viel Spaß in Azeroth! Ideen und Wünsche gern über foreverui.de.")
  end)

end

local function SeitenErgaenzen()
  -- Werte, die nicht über Schalter laufen, für „Seite zurücksetzen“
  local extra = { [3] = { "stil", "anzahl", "akzent", "skalierung", "breite" }, [4] = { "lage", "pos" },
    [5] = { "sortierung", "modus" }, [9] = { "tagesziel" }, [11] = { "sprache" } }
  for nr, liste in pairs(extra) do
    if seiten[nr] then
      for _, k in ipairs(liste) do seiten[nr].schluessel[#seiten[nr].schluessel + 1] = k end
    end
  end
end

function A:LetzteSeite() return alsEinstellungen and #seiten or A.ASSISTENT_SEITEN end

local function standardKopie(v)
  if type(v) ~= "table" then return v end
  local n = {}
  for k, w in pairs(v) do n[k] = standardKopie(w) end
  return n
end

-- Einstellungen der offenen Seite auf den Standard
function A:SeiteZuruecksetzen(nr)
  local s = seiten[nr or seite]
  if not s or #s.schluessel == 0 then return 0 end
  for _, k in ipairs(s.schluessel) do
    if k:sub(1, 1) ~= "_" then QK.db[k] = standardKopie(QK.STANDARD[k]) end
  end
  QK:AkzentAnwenden()
  QK:SpracheAnwenden()
  QK:Anwenden()
  A:Auffrischen()
  QK:Meldung(L"Seite „%s“ auf Standard zurückgesetzt.", L(s.titel))
  return #s.schluessel
end
A.Seiten = seiten

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
-- Knöpfe mittig nebeneinander, Seitenpunkte mittig darunter.
function A:Anordnen()
  local sichtbar = {}
  for _, b in ipairs({ fenster.fertig, zurueck, weiter }) do
    if b:IsShown() then sichtbar[#sichtbar + 1] = b end
  end
  local breite = -8
  for _, b in ipairs(sichtbar) do breite = breite + b:GetWidth() + 8 end
  local x = -breite / 2
  for _, b in ipairs(sichtbar) do
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", fenster, "BOTTOM", x, 30)
    x = x + b:GetWidth() + 8
  end
  local abstand = 22
  local start = -((#punkte - 1) * abstand) / 2
  for i, p in ipairs(punkte) do
    p:ClearAllPoints()
    p:SetPoint("BOTTOM", fenster, "BOTTOM", start + (i - 1) * abstand, 14)
  end
end

-- Auswählbare Elemente der aktuellen Seite (Karten und Schalter)
local function Waehlbar()
  local liste = {}
  for _, e in ipairs(seiten[seite].elemente) do
    if e.knopf and e:IsShown() then liste[#liste + 1] = e end
  end
  return liste
end

local function Markieren()
  if not markierung then
    markierung = CreateFrame("Frame", nil, fenster)
    markierung.kanten = {}
    for i = 1, 4 do markierung.kanten[i] = markierung:CreateTexture(nil, "OVERLAY") end
    local k = markierung.kanten
    k[1]:SetPoint("TOPLEFT"); k[1]:SetPoint("TOPRIGHT"); k[1]:SetHeight(2)
    k[2]:SetPoint("BOTTOMLEFT"); k[2]:SetPoint("BOTTOMRIGHT"); k[2]:SetHeight(2)
    k[3]:SetPoint("TOPLEFT"); k[3]:SetPoint("BOTTOMLEFT"); k[3]:SetWidth(2)
    k[4]:SetPoint("TOPRIGHT"); k[4]:SetPoint("BOTTOMRIGHT"); k[4]:SetWidth(2)
  end
  local liste = Waehlbar()
  local e = liste[auswahl]
  if not e then markierung:Hide() return end
  for _, t in ipairs(markierung.kanten) do t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1) end
  markierung:ClearAllPoints()
  markierung:SetPoint("TOPLEFT", e, "TOPLEFT", -4, 4)
  markierung:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", 4, -4)
  markierung:SetFrameLevel((e:GetFrameLevel() or 1) + 5)
  markierung:Show()
end

-- Gamepad/Tastatur: hoch, runter, links, rechts, ok, zurueck, vorher, nachher (Schultertasten)
-- quelle: "pad" für das Gamepad, sonst Tastatur
function A:Steuern(aktion, quelle)
  if not fenster or not fenster:IsShown() then return false end
  if aktion == "vorher" or aktion == "nachher" then
    if alsEinstellungen then A:NaviBlaettern(aktion == "vorher" and -1 or 1); return true end
    aktion = aktion == "vorher" and "links" or "rechts"
  end
  -- Eingebetteter Bereich (Questbuch ...): er steuert selbst, Escape/B schließt
  if alsEinstellungen and bereich then
    if aktion == "zurueck" then A:Schliessen(); return true end
    local b = bereiche[bereich]
    if b and b.steuern then
      local ok, behandelt = pcall(b.steuern, aktion)
      return ok and behandelt and true or false
    end
    return false
  end
  -- In den Einstellungen wird über die Seitenleiste geblättert: links/rechts gehören dem Spiel
  if alsEinstellungen and (aktion == "links" or aktion == "rechts") then return false end
  local liste = Waehlbar()
  if aktion == "ok" and not liste[auswahl] and alsEinstellungen then return false end
  if aktion == "hoch" or aktion == "runter" then
    if #liste == 0 then return true end
    auswahl = auswahl + (aktion == "hoch" and -1 or 1)
    if auswahl < 1 then auswahl = #liste elseif auswahl > #liste then auswahl = 1 end
    Markieren()
    local e = liste[auswahl]
    local an = e.knopf.GetChecked and (e.knopf:GetChecked() and L"an" or L"aus") or nil
    QK:Sprechen(e.vorlesen .. (an and (" " .. an) or ""))
  elseif aktion == "links" then
    if seite > 1 then seite = seite - 1; A:Auffrischen() end
  elseif aktion == "rechts" then
    if seite < A:LetzteSeite() then seite = seite + 1; A:Auffrischen() end
  elseif aktion == "ok" then
    local e = liste[auswahl]
    if e then e.knopf:Click() else weiter:Click() end
    Markieren()
  elseif aktion == "zurueck" then
    A:Schliessen()
  else
    return false
  end
  return true
end

function A:Auffrischen()
  if not fenster then return end
  fenster:SetScale(QK:Groesse())
  fenster.hg:SetColorTexture(0.06, 0.06, 0.08, QK:Deckkraft(0.99))
  A:FarbeAuffrischen()
  local offen = alsEinstellungen and bereich and bereiche[bereich] or nil
  for key, b in pairs(bereiche) do
    if b.rahmen and b.rahmen ~= (offen and offen.rahmen) then b.rahmen:Hide() end
  end
  local markiert = offen and bereich or seite
  for _, k in ipairs(navi) do
    local an = k.nr == markiert
    k.hg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], an and 0.14 or 0)
    k.strich:SetShown(an)
    if an then k.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else k.text:SetTextColor(0.85, 0.85, 0.85) end
  end
  if fenster.zuruecksetzen then
    fenster.zuruecksetzen:SetShown(alsEinstellungen and not offen and seiten[seite] and #seiten[seite].schluessel > 0 or false)
  end
  if offen then
    for _, s in ipairs(seiten) do s:Hide() end
    if markierung then markierung:Hide() end
    if A.letzteSeite ~= bereich then A.letzteSeite = bereich; QK:Sprechen(offen.titel) end
    seitenTitel:SetText(offen.titel)
    local f = offen.holen()
    A:Einbetten(f)
    offen.rahmen = f
    f:Show()
    offen.zeichnen()
    zurueck:Hide(); weiter:Hide()
    fenster.fertig:Show()
    fenster.fertig:SetText(L"Schließen")
    fenster.fertig:ClearAllPoints()
    fenster.fertig:SetPoint("BOTTOMRIGHT", fenster, "BOTTOMRIGHT", -24, 12)
    return
  end
  for i, s in ipairs(seiten) do
    s:SetShown(i == seite)
    if i == seite then for _, e in ipairs(s.elemente) do if e.Auffrischen then e.Auffrischen() end end end
  end
  seitenTitel:SetText(L(seiten[seite].titel))
  if seite ~= A.letzteSeite then
    A.letzteSeite, auswahl = seite, 0
    QK:Sprechen(L(seiten[seite].titel))
  end
  Markieren()
  for i, p in ipairs(punkte) do
    p.t:SetColorTexture(i == seite and GOLD[1] or 0.4, i == seite and GOLD[2] or 0.4, i == seite and GOLD[3] or 0.4, 1)
    p:SetSize(i == seite and 18 or 8, 4)
  end
  if alsEinstellungen then
    zurueck:Hide(); weiter:Hide()
    fenster.fertig:Show()
    fenster.fertig:SetText(L"Schließen")
    fenster.fertig:ClearAllPoints()
    fenster.fertig:SetPoint("BOTTOMRIGHT", fenster, "BOTTOMRIGHT", -24, 12)
    return
  end
  weiter:Show()
  fenster.fertig:SetText(L"Fertig")
  zurueck:SetShown(seite > 1)
  fenster.fertig:SetShown(seite < A:LetzteSeite())
  A:Anordnen()
  if seite == A:LetzteSeite() then
    weiter:SetText(L"Fertig")
  elseif seite == 1 then
    weiter:SetText(L"Los geht’s")
  else
    weiter:SetText(L"Weiter")
  end
end

---------------------------------------------------------------------------
-- Seitenleiste mit Gruppen, Kasten für den Inhalt
---------------------------------------------------------------------------
-- { Gruppe, { Seitennummer oder Bereich, kurzer Name } ... }; die Gruppe „Questbuch“
-- kommt aus den Reitern des Questbuchs (Gebiet, Welt, Suche, Tagebuch, Planer ...).
local function Navi()
  local buch = { L"Questbuch" }
  for _, r in ipairs(QK.Gebiet.REITER) do buch[#buch + 1] = { "buch:" .. r[1], L(r[2]) } end
  return {
    buch,
    { L"Darstellung", { 3, L"Aussehen" }, { 4, L"Lage" }, { 5, L"Sortierung" }, { 9, L"Feinschliff" } },
    { L"Funktionen", { 6, L"Navigation" }, { 7, L"Kleine Helfer" }, { 8, L"Noch mehr" }, { 10, L"Unterwegs" }, { "teilen", L"Teilen und Übernehmen" } },
    { L"Zugang", { 2, L"Barrierefreiheit" }, { 11, L"Profil und Tasten" } },
    { L"Hilfe", { "neuigkeiten", L"Neuigkeiten" }, { "discord", L"Discord und Feedback" }, { 12, L"Bedienung" }, { "fehlerbericht", L"Fehler melden" }, { "assistent", L"Assistent starten" } },
  }
end

local function NaviBauen()
  local leiste = CreateFrame("Frame", nil, fenster)
  leiste:SetPoint("TOPLEFT", 12, -84)
  leiste:SetPoint("BOTTOMLEFT", 12, 44)
  leiste:SetWidth(168)
  Rahmen(leiste, 0.5, { 1, 1, 1, 0.08 })
  fenster.leiste = leiste
  local y = -10
  for _, gruppe in ipairs(Navi()) do
    local kopf = Text(leiste, "GameFontNormalSmall", gruppe[1], 150)
    kopf:SetPoint("TOPLEFT", 12, y)
    Gold(function() kopf:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
    y = y - 16
    for i = 2, #gruppe do
      local nr, name = gruppe[i][1], gruppe[i][2]
      local k = CreateFrame("Button", nil, leiste)
      k:SetSize(156, 16)
      k:SetPoint("TOPLEFT", 6, y)
      k.hg = k:CreateTexture(nil, "BACKGROUND")
      k.hg:SetAllPoints()
      k.strich = k:CreateTexture(nil, "ARTWORK")
      k.strich:SetPoint("TOPLEFT"); k.strich:SetPoint("BOTTOMLEFT"); k.strich:SetWidth(2)
      Gold(function() k.strich:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1) end)
      local hl = k:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.05)
      k.text = Text(k, "GameFontHighlightSmall", name, 140)
      k.text:SetPoint("LEFT", 12, 0)
      k.nr = nr
      k:SetScript("OnClick", function()
        if nr == "assistent" then A:Oeffnen(1, false); return end
        if type(nr) == "string" then bereich = nr else bereich, seite = nil, nr end
        A:Auffrischen()
      end)
      k:SetScript("OnEnter", function() QK:Sprechen(name) end)
      navi[#navi + 1] = k
      y = y - 16
    end
    y = y - 4
  end
  local version = Text(leiste, "GameFontDisableSmall", "Version " .. tostring(QK.version), 150)
  version:SetPoint("BOTTOMLEFT", 12, 10)

  local kasten = CreateFrame("Frame", nil, fenster)
  kasten:SetPoint("TOPLEFT", leiste, "TOPRIGHT", 10, 0)
  kasten:SetPoint("BOTTOMRIGHT", -12, 44)
  Rahmen(kasten, 0.35, { 1, 1, 1, 0.08 })
  kasten:SetFrameLevel(math.max((fenster:GetFrameLevel() or 1), 1))
  fenster.kasten = kasten
end

---------------------------------------------------------------------------
-- Eingebettete Bereiche
---------------------------------------------------------------------------
-- holen(): baut den Rahmen und gibt ihn zurück, zeichnen(): frischt ihn auf,
-- steuern(aktion): optional, Gamepad/Pfeiltasten im Bereich (true = behandelt)
function A:BereichAnmelden(key, titel, holen, zeichnen, steuern)
  bereiche[key] = { titel = titel, holen = holen, zeichnen = zeichnen, steuern = steuern }
end

function A:NaviBlaettern(schritt)
  local liste = {}
  for _, k in ipairs(navi) do if k.nr ~= "assistent" then liste[#liste + 1] = k end end
  local markiert = (alsEinstellungen and bereich) or seite
  local nr = 1
  for i, k in ipairs(liste) do if k.nr == markiert then nr = i end end
  local k = liste[((nr - 1 + schritt) % #liste) + 1]
  if not k then return end
  if type(k.nr) == "string" then bereich = k.nr else bereich, seite = nil, k.nr end
  A:Auffrischen()
end

function A:Bereich(key)
  if fenster and fenster:IsShown() and alsEinstellungen then
    bereich = key
    A:Auffrischen()
  else
    self:Oeffnen(QK.SEITE_EINSTELLUNGEN, true, key)
  end
end

function A:BereichOffen(muster)
  if not (fenster and fenster:IsShown() and alsEinstellungen and bereich) then return false end
  return bereich:find(muster, 1, true) == 1
end

function A:Einbetten(f)
  if f.eingebettet then return end
  f.eingebettet = true
  f:SetParent(fenster.kasten)
  f:ClearAllPoints()
  f:SetAllPoints(fenster.kasten)
  f:SetScale(1)
  f:SetFrameStrata(fenster:GetFrameStrata() or "DIALOG")
  f:SetFrameLevel((fenster.kasten:GetFrameLevel() or 1) + 2)
end

-- Größe und Anordnung je nach Ansicht (Assistent oder Einstellungen)
local function Ansicht()
  local e = alsEinstellungen
  local g = QK.db.hauptGroesse
  if e then fenster:SetSize(math.max(760, g and g[1] or 820), math.max(620, g and g[2] or 660)) else fenster:SetSize(560, 440) end
  if fenster.griff then fenster.griff:SetShown(e) end
  if fenster.suche then fenster.suche:SetShown(e); if not e then fenster.trefferListe:Hide() end end
  fenster.leiste:SetShown(e)
  fenster.kasten:SetShown(e)
  for _, p in ipairs(punkte) do p:SetShown(not e) end
  inhalt:ClearAllPoints()
  if e then
    inhalt:SetPoint("TOPLEFT", fenster.kasten, "TOPLEFT", 16, -14)
    inhalt:SetPoint("BOTTOMRIGHT", fenster.kasten, "BOTTOMRIGHT", -16, 10)
  else
    inhalt:SetPoint("TOPLEFT", 24, -84)
    inhalt:SetPoint("BOTTOMRIGHT", -24, 64)
  end
  fenster.kopf:SetText(e and L"QUESTKOMPASS" or L"QUESTKOMPASS · EINRICHTUNG")
end

---------------------------------------------------------------------------
-- Suche: findet Seiten und Bereiche nach Titel und Texten
---------------------------------------------------------------------------
local GROSS = { ["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü" }
local function klein(t)
  t = tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
  return (t:gsub("\195[\132\150\156]", GROSS))
end

function A:Suchen(begriff)
  begriff = klein(begriff):gsub("^%s+", ""):gsub("%s+$", "")
  local treffer = {}
  if #begriff < 2 then return treffer end
  for i, s in ipairs(seiten) do
    for _, t in ipairs(s.such or {}) do
      if klein(t):find(begriff, 1, true) then
        treffer[#treffer + 1] = { ziel = i, titel = L(s.titel), fund = t ~= s.titel and t or nil }
        break
      end
    end
  end
  local keys = {}
  for key in pairs(bereiche) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local b = bereiche[key]
    if klein(b.titel):find(begriff, 1, true) then treffer[#treffer + 1] = { ziel = key, titel = b.titel } end
  end
  return treffer
end

function A:Springen(ziel)
  if type(ziel) == "string" then bereich = ziel else bereich, seite = nil, ziel end
  if fenster and fenster.suche then fenster.suche:SetText(""); fenster.suche:ClearFocus() end
  A:Auffrischen()
end

local function SucheBauen()
  local box = CreateFrame("EditBox", "QuestkompassEinstellungSuche", fenster, "InputBoxTemplate")
  box:SetSize(180, 20)
  box:SetPoint("TOPRIGHT", -44, -20)
  box:SetAutoFocus(false)
  box:SetMaxLetters(40)
  fenster.suche = box
  local platz = Text(box, "GameFontDisableSmall", L"Einstellung suchen …", 170)
  platz:SetPoint("LEFT", 4, 0)
  local liste = CreateFrame("Frame", nil, fenster)
  liste:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
  liste:SetSize(260, 10)
  liste:SetFrameLevel((fenster:GetFrameLevel() or 1) + 30)
  Rahmen(liste, 0.98)
  UI.GoldRand(liste, 0.45)
  liste.knoepfe = {}
  liste:Hide()
  fenster.trefferListe = liste
  local function zeigen()
    local text = box:GetText() or ""
    platz:SetShown(text == "")
    local treffer = A:Suchen(text)
    liste.treffer = treffer
    for i = 1, math.max(#treffer, #liste.knoepfe) do
      local k = liste.knoepfe[i]
      if i <= 8 and treffer[i] and not k then
        k = CreateFrame("Button", nil, liste)
        k:SetSize(250, 20)
        k:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 21)
        local hl = k:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        k.text = Text(k, "GameFontHighlightSmall", "", 240)
        k.text:SetPoint("LEFT", 6, 0)
        k:SetScript("OnClick", function(self) A:Springen(self.ziel) end)
        liste.knoepfe[i] = k
      end
      if k then
        local t = i <= 8 and treffer[i]
        k:SetShown(t and true or false)
        if t then
          k.ziel = t.ziel
          k.text:SetText(t.fund and (t.titel .. " > " .. t.fund) or t.titel)
        end
      end
    end
    local n = math.min(#treffer, 8)
    liste:SetHeight(n * 21 + 10)
    liste:SetShown(n > 0 and alsEinstellungen)
    if #text >= 2 and #treffer == 0 then QK:Sprechen(L"Nichts gefunden") end
  end
  box:SetScript("OnTextChanged", zeigen)
  box:SetScript("OnEnterPressed", function(self)
    local t = liste.treffer and liste.treffer[1]
    if t then QK:Sprechen(t.titel); A:Springen(t.ziel) else self:ClearFocus() end
  end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  box:SetScript("OnEditFocusLost", function() C_Timer.After(0.2, function() if not box:HasFocus() then liste:Hide() end end) end)
end

-- Teilen, Fehlerbericht und Discord stehen in Hilfe.lua, die Neuigkeiten in Neuigkeiten.lua.
function A:Teilen(art, text, titel) QK.Hilfe:Teilen(art, text, titel) end
function A:FehlerText() return table.concat(QK.Hilfe:Fehlerbericht(), "\n") end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function Erstellen()
  fenster = CreateFrame("Frame", "QuestkompassAssistent", UIParent)
  fenster:SetSize(560, 440)
  fenster:SetResizable(true)
  if fenster.SetResizeBounds then fenster:SetResizeBounds(760, 620, 1600, 1200)
  elseif fenster.SetMinResize then fenster:SetMinResize(760, 620) end
  local griff = CreateFrame("Button", nil, fenster)
  griff:SetSize(16, 16)
  griff:SetPoint("BOTTOMRIGHT", -2, 2)
  griff:SetFrameLevel((fenster:GetFrameLevel() or 1) + 20)
  griff.t = griff:CreateTexture(nil, "OVERLAY")
  griff.t:SetAllPoints()
  griff.t:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  griff:SetScript("OnMouseDown", function() fenster:StartSizing("BOTTOMRIGHT") end)
  griff:SetScript("OnMouseUp", function()
    fenster:StopMovingOrSizing()
    if alsEinstellungen then
      local w, h = fenster:GetWidth(), fenster:GetHeight()
      if type(w) == "number" and type(h) == "number" then QK.db.hauptGroesse = { math.floor(w), math.floor(h) } end
    end
  end)
  fenster.griff = griff
  fenster:SetPoint("CENTER", -120, 40)
  fenster:SetFrameStrata("DIALOG")
  fenster:SetClampedToScreen(true)
  fenster:EnableMouse(true)
  fenster:SetMovable(true)
  fenster:RegisterForDrag("LeftButton")
  fenster:SetScript("OnDragStart", fenster.StartMoving)
  fenster:SetScript("OnDragStop", fenster.StopMovingOrSizing)
  Rahmen(fenster, 0.99)
  UI.GoldRand(fenster, 0.45)
  tinsert(UISpecialFrames, "QuestkompassAssistent")

  local band = fenster:CreateTexture(nil, "ARTWORK")
  band:SetPoint("TOPLEFT", 1, -1)
  band:SetPoint("TOPRIGHT", -1, -1)
  band:SetHeight(64)
  Gold(function() band:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08) end)

  local kopf = Text(fenster, "GameFontNormalSmall", "QUESTKOMPASS")
  fenster.kopf = kopf
  kopf:SetPoint("TOPLEFT", 24, -16)
  Gold(function() kopf:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
  seitenTitel = Text(fenster, "GameFontHighlightLarge", "", 400)
  seitenTitel:SetPoint("TOPLEFT", 24, -34)

  local schliessen = CreateFrame("Button", nil, fenster, "UIPanelCloseButton")
  schliessen:SetPoint("TOPRIGHT", 0, 0)
  schliessen:SetScript("OnClick", function() A:Schliessen() end)

  SucheBauen()

  inhalt = CreateFrame("Frame", nil, fenster)
  inhalt:SetPoint("TOPLEFT", 24, -84)
  inhalt:SetPoint("BOTTOMRIGHT", -24, 64)

  SeitenBauen()
  SeitenErgaenzen()
  NaviBauen()

  punkte = {}
  for i = 1, A.ASSISTENT_SEITEN do
    local p = CreateFrame("Button", nil, fenster)
    p:SetSize(8, 4)
    p.t = p:CreateTexture(nil, "ARTWORK")
    p.t:SetAllPoints()
    p:SetHitRectInsets(-4, -4, -8, -8)
    p:SetScript("OnClick", function() seite = i; A:Auffrischen() end)
    punkte[i] = p
  end

  weiter = QK.FlachKnopf(fenster)
  weiter:SetSize(110, 24)
  weiter:SetScript("OnClick", function()
    if seite < A:LetzteSeite() then seite = seite + 1; A:Auffrischen() else A:Schliessen() end
  end)
  zurueck = QK.FlachKnopf(fenster)
  zurueck:SetSize(90, 24)
  zurueck:SetText(L"Zurück")
  zurueck:SetScript("OnClick", function() if seite > 1 then seite = seite - 1; A:Auffrischen() end end)
  local fertig = QK.FlachKnopf(fenster)
  fertig:SetSize(90, 24)
  fertig:SetText(L"Fertig")
  fertig:SetScript("OnClick", function() A:Schliessen() end)
  fenster.fertig = fertig
  local zurueckSetzen = UI.Knopf(fenster, L"Seite zurücksetzen", 130, function() A:SeiteZuruecksetzen() end)
  zurueckSetzen:SetPoint("BOTTOMLEFT", fenster, "BOTTOMLEFT", 192, 15)
  UI.Tipp(zurueckSetzen, L"Seite zurücksetzen", L"Stellt nur die Einstellungen dieser Seite auf den Standard zurück.")
  fenster.zuruecksetzen = zurueckSetzen
  fenster:Hide()
end

function A:Oeffnen(start, einstellungen, bereichKey)
  if not fenster then Erstellen() end
  alsEinstellungen = einstellungen and true or false
  bereich = alsEinstellungen and bereichKey or nil
  seite = math.max(1, math.min(start or 1, #seiten))
  Ansicht()
  fenster:Show()
  if QK.db.versteckt then QK.db.versteckt = false; QK:Anwenden() end
  A:Auffrischen()
end

function A:Offen() return fenster and fenster:IsShown() and true or false end

function A:Schliessen()
  if not QK.db.eingerichtet then
    QK.db.eingerichtet = true
    QK:Meldung(L"eingerichtet. /qk einstellungen bringt dich jederzeit zurück.")
  end
  if fenster then fenster:Hide() end
  QK:Anwenden()
end

-- Nach einem Sprachwechsel das Fenster neu bauen, damit alle Seiten sofort in der neuen Sprache stehen.
-- Ein Fenster lässt sich im Spiel nicht löschen: das alte wird versteckt und bleibt ungenutzt liegen.
function A:Neubauen()
  if not fenster then return end
  local offen, alteSeite, alsE, alterBereich = fenster:IsShown(), seite, alsEinstellungen, bereich
  for _, b in pairs(bereiche) do
    local f = b.rahmen
    if f then
      f.eingebettet = nil
      f:Hide()
      f:SetParent(UIParent)
      b.rahmen = nil
    end
  end
  fenster:Hide()
  fenster:SetScript("OnKeyDown", nil)
  wipe(seiten); wipe(navi); wipe(goldTexte); UI.GoldVergessen()
  fenster, markierung, punkte, auswahl, A.letzteSeite = nil, nil, nil, 0, nil
  -- Bereiche der anderen Dateien neu anmelden, damit Titel und Texte in der neuen Sprache stehen
  for _, m in ipairs({ QK.Gebiet, QK.Hilfe, QK.Neuigkeiten }) do
    if m and m.Neubauen then m:Neubauen() end
    if m and m.Anmelden then m:Anmelden() end
  end
  if offen then self:Oeffnen(alteSeite, alsE, alterBereich) end
end

---------------------------------------------------------------------------
-- Eintrag in den Spieleinstellungen, Bereiche anmelden
---------------------------------------------------------------------------
function A:Start()
  local panel = CreateFrame("Frame")
  panel.name = "Questkompass"
  local t = Text(panel, "GameFontNormalLarge", "Questkompass")
  t:SetPoint("TOPLEFT", 16, -16)
  local d = Text(panel, "GameFontHighlight", L"Alle Einstellungen findest du im eigenen Fenster.", 500)
  d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
  local b = QK.FlachKnopf(panel)
  b:SetSize(200, 26)
  b:SetText(L"Einstellungen öffnen")
  b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  b:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
    A:Oeffnen(QK.SEITE_EINSTELLUNGEN, true)
  end)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local kategorie = Settings.RegisterCanvasLayoutCategory(panel, "Questkompass")
    Settings.RegisterAddOnCategory(kategorie)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end
