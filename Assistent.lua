-- Questkompass: Einrichtungsassistent. Derselbe Dialog dient später als Einstellungsfenster.
local ADDON, QK = ...
local A = QK:Modul("Assistent")

local fenster, seitenTitel, punkte, zurueck, weiter, inhalt
local seiten, seite, alsEinstellungen = {}, 1, false
local GOLD = QK.farben.gold

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------
local function Rahmen(f, alpha, rand)
  f.hg = f.hg or f:CreateTexture(nil, "BACKGROUND")
  f.hg:SetAllPoints()
  f.hg:SetColorTexture(0.06, 0.06, 0.08, alpha)
  f.rand = f.rand or {}
  local function kante(i, p1, p2, w, h)
    local t = f.rand[i] or f:CreateTexture(nil, "BORDER")
    t:ClearAllPoints()
    t:SetPoint(p1); t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
    f.rand[i] = t
  end
  kante(1, "TOPLEFT", "TOPRIGHT", nil, 1)
  kante(2, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  kante(3, "TOPLEFT", "BOTTOMLEFT", 1)
  kante(4, "TOPRIGHT", "BOTTOMRIGHT", 1)
  A.RandFarbe(f, rand)
end
function A.RandFarbe(f, c)
  for _, t in ipairs(f.rand) do t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

local function Text(eltern, schrift, text, breite)
  local t = eltern:CreateFontString(nil, "OVERLAY", schrift)
  t:SetJustifyH("LEFT")
  t:SetJustifyV("TOP")
  if breite then t:SetWidth(breite) end
  t:SetText(text)
  return t
end

-- Auswahlkarte: Titel, Beschreibung, gold umrandet, wenn gewählt.
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
  hl:SetColorTexture(1, 1, 1, 0.04)
  k.Auffrischen = function()
    local an = istGewaehlt()
    A.RandFarbe(k, an and { GOLD[1], GOLD[2], GOLD[3], 0.9 } or { 1, 1, 1, 0.12 })
    k.hg:SetColorTexture(an and 0.16 or 0.06, an and 0.13 or 0.06, an and 0.07 or 0.08, 0.7)
  end
  k:SetScript("OnClick", function()
    waehlen()
    A:Auffrischen()
    QK:Anwenden()
  end)
  return k
end

-- Schalter mit Beschriftung und Erklärung.
local function Schalter(eltern, titel, text, schluessel, nachher)
  local f = CreateFrame("Frame", nil, eltern)
  f:SetSize(240, 40)
  local c = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c:SetPoint("TOPLEFT", 0, 2)
  local l = Text(f, "GameFontHighlight", titel, 205)
  l:SetPoint("TOPLEFT", 28, -3)
  local d = Text(f, "GameFontDisableSmall", text or "", 205)
  d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
  c:SetScript("OnClick", function(self)
    QK.db[schluessel] = self:GetChecked() and true or false
    if nachher then nachher(QK.db[schluessel]) end
    QK:Anwenden()
  end)
  f.Auffrischen = function() c:SetChecked(QK.db[schluessel] and true or false) end
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
  bauen(s, function(e) s.elemente[#s.elemente + 1] = e; return e end)
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
  NeueSeite("Willkommen", function(s)
    Absatz(s, "Schön, dass du da bist!\n\nQuestkompass zeigt dir ruhig und übersichtlich, was als Nächstes zu tun ist: "
      .. "welche Quest am nächsten liegt, in welche Richtung du laufen musst und wie weit du bist.\n\n"
      .. "In ein paar kurzen Schritten stellst du alles nach deinem Geschmack ein. Jede Wahl siehst du sofort. "
      .. "Später erreichst du diese Einstellungen per Rechtsklick auf die Liste, über das Zahnrad oder mit |cfff2c45a/qk einstellungen|r.")
    local tipp = Text(s, "GameFontDisableSmall", "Keine Lust auf Einstellungen? Klick einfach auf „Fertig“, die Standardwerte passen für die meisten.", 500)
    tipp:SetPoint("BOTTOMLEFT", 0, 4)
  end)

  NeueSeite("Barrierefreiheit", function(s, merke)
    local t = Text(s, "GameFontHighlight", "Questkompass soll für alle gut nutzbar sein. Stell hier ein, was dir hilft. "
      .. "Alles lässt sich später unter |cfff2c45a/qk einstellungen|r ändern.", 500)
    t:SetPoint("TOPLEFT", 0, 0)
    Raster(s, merke, {
      { "Vorlesen", "Fortschritt und fertige Quests per Sprachausgabe.", "vorlesen" },
      { "Hoher Kontrast", "Dunklerer Hintergrund, hellere Schrift.", "kontrast" },
      { "Farbenblind-Modus", "Blau und Orange statt Grün und Rot, Status als Wort.", "farbenblind" },
      { "Alles größer", "Fenster, Pfeil und Meldungen um ein Viertel größer.", "allesGroesser" },
      { "Weniger Bewegung", "Keine Einblendungen, Meldungen bleiben länger.", "wenigerBewegung" },
    }, -44, 52)
    local test = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    test:SetSize(150, 22)
    test:SetText("Vorlesen testen")
    test:SetPoint("TOPLEFT", 255, -158)
    test:SetScript("OnClick", function()
      if not QK:Sprechen("Hallo! So klingt Questkompass.", true) then
        QK:Meldung("die Sprachausgabe ist nicht verfügbar. In den Spieleinstellungen unter Barrierefreiheit › Text-zu-Sprache lässt sie sich einrichten.")
      end
    end)
    local tipp = Text(s, "GameFontDisableSmall", "Tastenkürzel „Fokus-Quest vorlesen“ und |cfff2c45a/qk vorlesen|r lesen die aktuelle Quest jederzeit vor. "
      .. "Die Liste selbst kannst du auf der nächsten Seite bis 200 % vergrößern.", 500)
    tipp:SetPoint("TOPLEFT", 0, -218)
  end)

  NeueSeite("Wie soll die Liste aussehen?", function(s, merke)
    local x = 0
    for _, id in ipairs({ "ruhig", "klassisch", "kompakt" }) do
      local beschreibung = ({
        ruhig = "Dunkler, halb durchsichtiger Hintergrund, Fortschrittsbalken. Unsere Empfehlung.",
        klassisch = "Ohne Hintergrund, größere Schrift, wie die Questverfolgung des Spiels.",
        kompakt = "Kleine Schrift, nur das nächste Ziel je Quest. Viele Quests auf wenig Platz.",
      })[id]
      local k = merke(Karte(s, QK.STILE[id].name, beschreibung, 160, 92,
        function() return QK.db.stil == id end,
        function() QK.db.stil = id; QK.db.anzahl = QK.STILE[id].anzahl end))
      k:SetPoint("TOPLEFT", x, 0)
      x = x + 170
    end
    local a = Text(s, "GameFontNormal", "Akzentfarbe", 200)
    a:SetPoint("TOPLEFT", 0, -106)
    for i, id in ipairs({ "gold", "klasse", "eis", "smaragd" }) do
      local k = merke(Karte(s, QK.AKZENTE[id][1], "", 120, 34,
        function() return QK.db.akzent == id end,
        function() QK.db.akzent = id end))
      k:SetPoint("TOPLEFT", (i - 1) * 127, -124)
      local farbe = k:CreateTexture(nil, "ARTWORK")
      farbe:SetSize(10, 10)
      farbe:SetPoint("RIGHT", -10, 0)
      local alt = k.Auffrischen
      k.Auffrischen = function()
        local merk = QK.db.akzent
        QK.db.akzent = id; QK:AkzentAnwenden()
        farbe:SetColorTexture(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 1)
        QK.db.akzent = merk; QK:AkzentAnwenden()
        alt()
      end
    end
    local g = Text(s, "GameFontNormal", "Größe", 200)
    g:SetPoint("TOPLEFT", 0, -180)
    local wert = Text(s, "GameFontHighlight", "", 60)
    wert:SetJustifyH("CENTER")
    wert:SetPoint("TOPLEFT", 110, -180)
    local function schritt(d)
      QK.db.skalierung = math.max(0.6, math.min(2.0, (QK.db.skalierung or 1) + d))
      QK:Anwenden(); A:Auffrischen()
    end
    local minus = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    minus:SetSize(26, 20); minus:SetText("–"); minus:SetPoint("TOPLEFT", 80, -176)
    minus:SetScript("OnClick", function() schritt(-0.1) end)
    local plus = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    plus:SetSize(26, 20); plus:SetText("+"); plus:SetPoint("TOPLEFT", 175, -176)
    plus:SetScript("OnClick", function() schritt(0.1) end)
    local b = Text(s, "GameFontNormal", "Breite", 200)
    b:SetPoint("TOPLEFT", 260, -180)
    local bwert = Text(s, "GameFontHighlight", "", 60)
    bwert:SetJustifyH("CENTER")
    bwert:SetPoint("TOPLEFT", 370, -180)
    local function bschritt(d)
      QK.db.breite = math.max(180, math.min(400, (QK.db.breite or 240) + d))
      QK:Anwenden(); A:Auffrischen()
    end
    local bminus = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    bminus:SetSize(26, 20); bminus:SetText("–"); bminus:SetPoint("TOPLEFT", 340, -176)
    bminus:SetScript("OnClick", function() bschritt(-20) end)
    local bplus = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    bplus:SetSize(26, 20); bplus:SetText("+"); bplus:SetPoint("TOPLEFT", 435, -176)
    bplus:SetScript("OnClick", function() bschritt(20) end)
    merke({ Auffrischen = function()
      wert:SetText(("%d %%"):format(math.floor((QK.db.skalierung or 1) * 100 + 0.5)))
      bwert:SetText(("%d"):format(QK.db.breite or 240))
    end })
    local tipp = Text(s, "GameFontDisableSmall", "Die Liste neben dem Fenster zeigt deine Wahl sofort.", 500)
    tipp:SetPoint("TOPLEFT", 0, -216)
  end)

  NeueSeite("Wo soll die Liste stehen?", function(s, merke)
    local lagen = {
      { "minimap", "Unter der Minikarte", "Dort, wo sonst die Questverfolgung steht." },
      { "rechts", "Rechts am Rand", "Mittig am rechten Bildschirmrand." },
      { "links", "Links am Rand", "Gut, wenn rechts schon Leisten sitzen." },
      { "frei", "Frei verschieben", "Zieh die Liste an ihrer Kopfzeile, wohin du willst." },
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
    local f = merke(Schalter(s, "Liste fixieren", "Verhindert versehentliches Verschieben.", "gesperrt"))
    f:SetPoint("TOPLEFT", 0, -160)
  end)

  NeueSeite("Sortierung und Anzeige", function(s, merke)
    local sort = {
      { "entfernung", "Nächste zuerst", "Quests nach Entfernung sortiert." },
      { "zone", "Nach Zone", "Aktuelle Zone oben, fertige Quests zuerst." },
      { "log", "Wie im Questlog", "Gleiche Reihenfolge wie im Spiel." },
    }
    for i, e in ipairs(sort) do
      local k = merke(Karte(s, e[2], e[3], 160, 62,
        function() return QK.db.sortierung == e[1] end,
        function() QK.db.sortierung = e[1] end))
      k:SetPoint("TOPLEFT", (i - 1) * 170, 0)
    end
    merke({ Auffrischen = function() QK.db._nurVerfolgt = QK.db.modus == "verfolgt" end })
    Raster(s, merke, {
      { "Questverfolgung ersetzen", "Blendet die Liste des Spiels aus.", "blizzardAusblenden" },
      { "Nach Zonen gruppieren", "Überschriften, die sich einklappen lassen.", "gruppen" },
      { "Ruhemodus im Kampf", "Liste wird im Kampf durchsichtig.", "ruhemodus" },
      { "Nur verfolgte Quests", "Zeigt nur, was du verfolgst.", "_nurVerfolgt", function(an) QK.db.modus = an and "verfolgt" or "alle" end },
      { "Graue Quests ausblenden", "Quests, die kaum noch Erfahrung bringen.", "graueAusblenden" },
      { "Neue Quests markieren", "Zwei Minuten lang mit „Neu“.", "neuMarkierung" },
    }, -78)
  end)

  NeueSeite("Navigation", function(s, merke)
    local t = Text(s, "GameFontHighlight", "Questkompass führt dich zum Ziel. Klick in der Liste auf eine Quest, um sie als Fokus zu setzen.", 500)
    t:SetPoint("TOPLEFT", 0, 0)
    Raster(s, merke, {
      { "Kompasspfeile", "Kleiner Pfeil an jeder Quest.", "pfeil" },
      { "Großer Fokuspfeil", "Schwebender Pfeil mit Entfernung und Ankunftszeit.", "pfeilGross" },
      { "Automatischer Fokus", "Ohne Fokus wird die nächste Quest gewählt.", "autoFokus" },
      { "Questgegenstände", "Knopf zum Benutzen direkt an der Quest.", "questItems" },
      { "Gruppenmitglieder zeigen", "Wer aus der Gruppe dieselbe Quest hat.", "mitspieler" },
      { "Erfahrungsvorschau", "Was deine fertigen Quests zusammen bringen.", "epVorschau" },
    }, -40)
  end)

  NeueSeite("Kleine Helfer", function(s, merke)
    Raster(s, merke, {
      { "Meldung bei Fortschritt", "Kurzer Hinweis, wenn ein Ziel erfüllt ist.", "meldungen" },
      { "Klang bei fertiger Quest", "Damit du nichts verpasst.", "klang" },
      { "Fortschritt an die Gruppe", "Schreibt Fortschritte in den Gruppenchat.", "gruppenMeldungen" },
      { "Warnung bei vollem Questlog", "Kurz bevor kein Platz mehr frei ist.", "logWarnung" },
      { "Quests automatisch annehmen", "Halte Umschalt gedrückt, um es auszusetzen.", "autoAnnehmen" },
      { "Quests automatisch abgeben", "Nur ohne Belohnungswahl. Umschalt hält an.", "autoAbgeben" },
      { "Belohnungstipp", "Markiert die Belohnung mit dem höchsten Wert.", "belohnungsTipp" },
      { "Knopf an der Minikarte", "Schneller Zugriff auf Liste und Questbuch.", "minimapKnopf" },
    }, 0, 52)
  end)

  NeueSeite("Profil und Tasten", function(s, merke)
    local profile = {
      { "konto", "Für alle Charaktere", "Eine Einstellung für deinen ganzen Account." },
      { "eigen", "Nur für diesen Charakter", "Eigene Einstellungen, z. B. für einen Twink." },
    }
    for i, p in ipairs(profile) do
      local k = merke(Karte(s, p[2], p[3], 245, 62,
        function() return (QK.char.profil or "konto") == p[1] end,
        function() QK:ProfilWechseln(p[1]) end))
      k:SetPoint("TOPLEFT", (i - 1) * 255, 0)
    end
    Absatz(s, "|cfff2c45aTastenkürzel|r findest du in den Tastenbelegungen des Spiels unter „AddOns“ › „Questkompass“: "
      .. "Liste umschalten, nächstgelegene Quest als Fokus, Fokus weiterschalten, Questbuch und Einstellungen.\n\n"
      .. "|cfff2c45a/qk hilfe|r zeigt alle Chatbefehle.", -80)
  end)

  NeueSeite("Alles bereit!", function(s)
    Absatz(s, "So bedienst du Questkompass:\n\n"
      .. "|cfff2c45aKlick|r auf eine Quest setzt sie als Fokus, Pfeil und Navigation zeigen den Weg.\n"
      .. "|cfff2c45aRechtsklick|r öffnet weitere Möglichkeiten wie Teilen oder Ausblenden.\n"
      .. "|cfff2c45aMausrad|r über der Liste blättert, wenn es mehr Quests gibt.\n"
      .. "|cfff2c45aKartensymbol|r öffnet das Questbuch: Gebiet, Welt, Suche und Tagebuch.\n"
      .. "|cfff2c45aZahnrad|r oder |cfff2c45a/qk einstellungen|r: hierher zurück.\n\n"
      .. "Viel Spaß in Azeroth! Ideen und Wünsche gern über foreverui.de.")
  end)
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
function A:Auffrischen()
  if not fenster then return end
  fenster:SetScale(QK:Groesse())
  fenster.hg:SetColorTexture(0.06, 0.06, 0.08, QK:Deckkraft(0.96))
  for i, s in ipairs(seiten) do
    s:SetShown(i == seite)
    if i == seite then for _, e in ipairs(s.elemente) do if e.Auffrischen then e.Auffrischen() end end end
  end
  seitenTitel:SetText(seiten[seite].titel)
  for i, p in ipairs(punkte) do
    p.t:SetColorTexture(i == seite and GOLD[1] or 0.4, i == seite and GOLD[2] or 0.4, i == seite and GOLD[3] or 0.4, 1)
    p:SetSize(i == seite and 18 or 8, 4)
  end
  zurueck:SetShown(seite > 1)
  fenster.fertig:SetShown(seite < #seiten)
  if seite == #seiten then
    weiter:SetText("Fertig")
  elseif seite == 1 and not alsEinstellungen then
    weiter:SetText("Los geht’s")
  else
    weiter:SetText("Weiter")
  end
end

local function Erstellen()
  fenster = CreateFrame("Frame", "QuestkompassAssistent", UIParent)
  fenster:SetSize(560, 440)
  fenster:SetPoint("CENTER", -120, 40)
  fenster:SetFrameStrata("DIALOG")
  fenster:SetClampedToScreen(true)
  fenster:EnableMouse(true)
  fenster:SetMovable(true)
  fenster:RegisterForDrag("LeftButton")
  fenster:SetScript("OnDragStart", fenster.StartMoving)
  fenster:SetScript("OnDragStop", fenster.StopMovingOrSizing)
  Rahmen(fenster, 0.96, { GOLD[1], GOLD[2], GOLD[3], 0.45 })
  tinsert(UISpecialFrames, "QuestkompassAssistent")

  local band = fenster:CreateTexture(nil, "ARTWORK")
  band:SetPoint("TOPLEFT", 1, -1)
  band:SetPoint("TOPRIGHT", -1, -1)
  band:SetHeight(64)
  band:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)

  local kopf = Text(fenster, "GameFontNormalSmall", "QUESTKOMPASS")
  kopf:SetPoint("TOPLEFT", 24, -16)
  kopf:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  seitenTitel = Text(fenster, "GameFontHighlightLarge", "", 400)
  seitenTitel:SetPoint("TOPLEFT", 24, -34)

  local schliessen = CreateFrame("Button", nil, fenster, "UIPanelCloseButton")
  schliessen:SetPoint("TOPRIGHT", 0, 0)
  schliessen:SetScript("OnClick", function() A:Schliessen() end)

  inhalt = CreateFrame("Frame", nil, fenster)
  inhalt:SetPoint("TOPLEFT", 24, -84)
  inhalt:SetPoint("BOTTOMRIGHT", -24, 56)

  SeitenBauen()

  punkte = {}
  for i = 1, #seiten do
    local p = CreateFrame("Button", nil, fenster)
    p:SetSize(8, 4)
    p.t = p:CreateTexture(nil, "ARTWORK")
    p.t:SetAllPoints()
    p:SetPoint("BOTTOMLEFT", 24 + (i - 1) * 26, 28)
    p:SetHitRectInsets(-4, -4, -8, -8)
    p:SetScript("OnClick", function() seite = i; A:Auffrischen() end)
    punkte[i] = p
  end

  weiter = CreateFrame("Button", nil, fenster, "UIPanelButtonTemplate")
  weiter:SetSize(110, 24)
  weiter:SetPoint("BOTTOMRIGHT", -20, 16)
  weiter:SetScript("OnClick", function()
    if seite < #seiten then seite = seite + 1; A:Auffrischen() else A:Schliessen() end
  end)
  zurueck = CreateFrame("Button", nil, fenster, "UIPanelButtonTemplate")
  zurueck:SetSize(90, 24)
  zurueck:SetPoint("RIGHT", weiter, "LEFT", -8, 0)
  zurueck:SetText("Zurück")
  zurueck:SetScript("OnClick", function() if seite > 1 then seite = seite - 1; A:Auffrischen() end end)
  local fertig = CreateFrame("Button", nil, fenster, "UIPanelButtonTemplate")
  fertig:SetSize(90, 24)
  fertig:SetPoint("RIGHT", zurueck, "LEFT", -8, 0)
  fertig:SetText("Fertig")
  fertig:SetScript("OnClick", function() A:Schliessen() end)
  fenster.fertig = fertig
  fenster:Hide()
end

function A:Oeffnen(start, einstellungen)
  if not fenster then Erstellen() end
  alsEinstellungen = einstellungen and true or false
  seite = math.max(1, math.min(start or 1, #seiten))
  fenster:Show()
  if QK.db.versteckt then QK.db.versteckt = false; QK:Anwenden() end
  A:Auffrischen()
end

function A:Schliessen()
  if not QK.db.eingerichtet then
    QK.db.eingerichtet = true
    QK:Meldung("eingerichtet. /qk einstellungen bringt dich jederzeit zurück.")
  end
  if fenster then fenster:Hide() end
  QK:Anwenden()
end

---------------------------------------------------------------------------
-- Eintrag in den Spieleinstellungen
---------------------------------------------------------------------------
function A:Start()
  local panel = CreateFrame("Frame")
  panel.name = "Questkompass"
  local t = Text(panel, "GameFontNormalLarge", "Questkompass")
  t:SetPoint("TOPLEFT", 16, -16)
  local d = Text(panel, "GameFontHighlight", "Alle Einstellungen findest du im eigenen Fenster.", 500)
  d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(200, 26)
  b:SetText("Einstellungen öffnen")
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
