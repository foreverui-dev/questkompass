-- Questkompass: das Questbuch mit vier Reitern.
-- Gebiet: alle Quests einer Zone mit Status. Welt: Fortschritt aller Zonen.
-- Suche: alle Quests nach Namen. Tagebuch: abgegebene Quests und Sitzungsstatistik.
local _, QK = ...
local G = QK:Modul("Gebiet")
local L = QK.L

local ZEILE = 16
local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
local IM_LOG = "|TInterface\\GossipFrame\\ActiveQuestIcon:12:12:0:0|t"
local OFFEN = "|TInterface\\GossipFrame\\AvailableQuestIcon:12:12:0:0|t"

local fenster, scroll, inhalt, fuss
local reiterKnoepfe, koepfe = {}, {}
local zeilen = {}
local reiter = "gebiet"
local gebietID, folgen = nil, true
local gebietListe, weltCache
local suchFeld, suchText = nil, ""
local gebietTitel, gebietUnter, gebietBalken, gebietBalkenText
local weltTitel, weltBalken, weltBalkenText
local buchStatistik
local auswahl = 0           -- Gamepad/Tastatur: markierte Zeile
local filter = 1            -- Gebiet: 1 alle, 2 offen, 3 im Log, 4 erledigt
local FILTER = { "Alle", "Offen", "Im Log", "Erledigt" }
local filterKnopf
local MERK = "|TInterface\\COMMON\\ReputationStar:12:12:0:0:32:32:0:16:0:16|t"

-- Reiter; weitere Dateien hängen mit G:ReiterHinzufuegen eigene an (Planer, Erfolge).
local REITER = { { "gebiet", L"Gebiet" }, { "welt", L"Welt" }, { "suche", L"Suche" }, { "tagebuch", L"Tagebuch" } }
local AUFBAU, KOPFBAU = {}, {}
function G:ReiterHinzufuegen(id, titel, aufbau, kopfBauen)
  REITER[#REITER + 1] = { id, titel }
  AUFBAU[id], KOPFBAU[id] = aufbau, kopfBauen
end

-- Sitzung
local sitzung = { start = nil, quests = 0, ep = 0 }
G.sitzung = sitzung
local letzteXP, letzteMax

---------------------------------------------------------------------------
-- Daten
---------------------------------------------------------------------------
local function Gebiete()
  if gebietListe then return gebietListe end
  local zaehlung = {}
  for id in pairs(QK.quests) do
    local q = QK:Quest(id)
    if q.gebiet and QK:PasstZumCharakter(q) then
      zaehlung[q.gebiet] = (zaehlung[q.gebiet] or 0) + 1
    end
  end
  gebietListe = {}
  for id in pairs(zaehlung) do
    if QK:GebietName(id) then gebietListe[#gebietListe + 1] = id end
  end
  table.sort(gebietListe, function(a, b) return QK:GebietName(a) < QK:GebietName(b) end)
  return gebietListe
end

local function ImLog()
  local imLog = {}
  for _, q in ipairs(QK.Compat:Questlog()) do if q.id then imLog[q.id] = true end end
  return imLog
end

-- Quests eines Gebiets mit Status: 1 = im Log, 2 = offen, 3 = erledigt
function G:Liste(id, imLog)
  imLog = imLog or ImLog()
  local liste = {}
  for _, qid in ipairs(QK:QuestsImGebiet(id)) do
    local q = QK:Quest(qid)
    if QK:PasstZumCharakter(q) then
      q.status = imLog[qid] and 1 or (QK.Compat:IstErledigt(qid) and 3 or 2)
      liste[#liste + 1] = q
    end
  end
  table.sort(liste, function(a, b)
    if a.status ~= b.status then return a.status < b.status end
    if a.name ~= b.name then return (a.name or "") < (b.name or "") end
    return a.id < b.id
  end)
  return liste
end

-- Fortschritt aller Gebiete: { id, erledigt, gesamt }
function G:Welt()
  local imLog = ImLog()
  local liste = {}
  for _, id in ipairs(Gebiete()) do
    local erledigt, gesamt = 0, 0
    for _, q in ipairs(self:Liste(id, imLog)) do
      gesamt = gesamt + 1
      if q.status == 3 then erledigt = erledigt + 1 end
    end
    liste[#liste + 1] = { id = id, erledigt = erledigt, gesamt = gesamt }
  end
  return liste
end

function G:Suchen(text)
  text = (text or ""):lower()
  local treffer = {}
  if #text < 3 then return treffer end
  local imLog = ImLog()
  for id, roh in pairs(QK.quests) do
    local de, en = roh[6][1]:lower(), roh[6][2]:lower()
    if de:find(text, 1, true) or en:find(text, 1, true) then
      local q = QK:Quest(id)
      if QK:PasstZumCharakter(q) then
        q.status = imLog[id] and 1 or (QK.Compat:IstErledigt(id) and 3 or 2)
        treffer[#treffer + 1] = q
      end
    end
  end
  table.sort(treffer, function(a, b) return (a.name or "") < (b.name or "") end)
  while #treffer > 150 do table.remove(treffer) end
  return treffer
end

---------------------------------------------------------------------------
-- Liste
---------------------------------------------------------------------------
local function NeueZeile()
  local z = CreateFrame("Button", nil, inhalt)
  z:SetHeight(ZEILE)
  z.symbol = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  z.symbol:SetPoint("LEFT", 2, 0)
  z.symbol:SetWidth(16)
  z.rechts = z:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  z.rechts:SetPoint("RIGHT", -4, 0)
  z.rechts:SetJustifyH("RIGHT")
  z.text = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  z.text:SetPoint("LEFT", 20, 0)
  z.text:SetPoint("RIGHT", z.rechts, "LEFT", -6, 0)
  z.text:SetJustifyH("LEFT")
  z.text:SetWordWrap(false)
  z.balken = z:CreateTexture(nil, "BACKGROUND")
  z.balken:SetPoint("TOPLEFT", 0, 0)
  z.balken:SetPoint("BOTTOMLEFT", 0, 0)
  z.hl = z:CreateTexture(nil, "HIGHLIGHT")
  z.hl:SetAllPoints()
  z.hl:SetColorTexture(1, 1, 1, 0.06)
  z.wahl = z:CreateTexture(nil, "BORDER")
  z.wahl:SetAllPoints()
  z.wahl:Hide()
  z:SetScript("OnEnter", function(self)
    local q = self.quest
    if not q and self.tipp then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.tipp[1], unpack(QK.farben.gold))
      for i = 2, #self.tipp do GameTooltip:AddLine(self.tipp[i], 0.85, 0.85, 0.85, true) end
      GameTooltip:Show()
      return
    end
    if not q then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(q.name or (L"Quest " .. q.id), unpack(QK.farben.gold))
    GameTooltip:AddLine(({ L"Steht in deinem Questlog", L"Noch nicht gemacht", L"Erledigt" })[q.status] or "", 0.8, 0.8, 0.8)
    QK.Tooltip:Ergaenzen(GameTooltip, q.id, true)
    if q.status == 2 and QK.Extras then
      GameTooltip:AddLine(QK.Extras:Gemerkt(q.id) and L"Rechtsklick: von der Merkliste nehmen" or L"Rechtsklick: auf die Merkliste", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
  end)
  z:SetScript("OnLeave", function() GameTooltip:Hide() end)
  z:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  z:SetScript("OnClick", function(self, taste)
    if taste == "RightButton" and self.quest and self.quest.status == 2 and QK.Extras then
      local an = QK.Extras:Merken(self.quest.id)
      QK:Meldung(an and L"„%s“ steht auf deiner Merkliste (Planer)." or L"„%s“ von der Merkliste genommen.", self.quest.name or self.quest.id)
      G:Aktualisieren()
    elseif self.klick then
      self.klick()
    end
  end)
  return z
end

local function Zeichnen(eintraege)
  for _, z in ipairs(zeilen) do z:Hide() end
  for i, e in ipairs(eintraege) do
    local z = zeilen[i] or NeueZeile()
    zeilen[i] = z
    z:ClearAllPoints()
    z:SetPoint("TOPLEFT", 0, -(i - 1) * ZEILE)
    z:SetPoint("RIGHT", inhalt, "RIGHT")
    z.symbol:SetText(e.symbol or "")
    z.text:SetText(e.text or "")
    z.text:SetTextColor(unpack(e.farbe or QK.farben.hell))
    z.rechts:SetText(e.rechts or "")
    z.quest, z.klick, z.tipp = e.quest, e.klick, e.tipp
    if e.anteil and e.anteil > 0 then
      z.balken:SetWidth(math.max(1, (inhalt:GetWidth() or 300) * e.anteil))
      z.balken:SetColorTexture(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.12)
      z.balken:Show()
    else
      z.balken:Hide()
    end
    z:Show()
  end
  inhalt:SetHeight(math.max(1, #eintraege * ZEILE))
  if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
  G.anzahl = #eintraege
  if auswahl > #eintraege then auswahl = 0 end
  G:AuswahlZeigen()
end
G.Zeichnen = Zeichnen

-- Gamepad und Tastatur: Zeile markieren, auslösen, Reiter wechseln
function G:AuswahlZeigen(sprechen)
  for i, z in ipairs(zeilen) do
    local an = i == auswahl and z:IsShown()
    z.wahl:SetShown(an)
    if an then
      z.wahl:SetColorTexture(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.22)
      local oben = (i - 1) * ZEILE
      local sicht = scroll:GetHeight() or 300
      local jetzt = scroll.GetVerticalScroll and scroll:GetVerticalScroll() or 0
      if oben < jetzt then scroll:SetVerticalScroll(oben)
      elseif oben + ZEILE > jetzt + sicht then scroll:SetVerticalScroll(oben + ZEILE - sicht) end
      local q = z.quest
      if sprechen then QK:Sprechen(z.text:GetText() .. ((q and q.status) and (". " .. ({ L"im Log", L"offen", L"erledigt" })[q.status]) or "")) end
    end
  end
end

function G:Bewegen(schritt)
  if not G.anzahl or G.anzahl == 0 then return end
  auswahl = auswahl + schritt
  if auswahl < 1 then auswahl = G.anzahl elseif auswahl > G.anzahl then auswahl = 1 end
  G:AuswahlZeigen(true)
end

function G:Ausloesen()
  local z = zeilen[auswahl]
  if z and z:IsShown() and z.klick then z.klick() end
end

function G:ReiterWechseln(schritt)
  local pos = 1
  for i, r in ipairs(REITER) do if r[1] == reiter then pos = i end end
  pos = ((pos - 1 + schritt) % #REITER) + 1
  G:Reiter(REITER[pos][1])
end

function G:Fenster() return fenster end

function G:Filter(n) filter = n; auswahl = 0; G:Aktualisieren() end

local function QuestEintrag(q, mitGebiet)
  local typ = QK:TypName(q.typ)
  local text = (q.name or (L"Quest " .. q.id)) .. (typ and (" |cffd98c40(" .. typ .. ")|r") or "")
  if mitGebiet and q.gebiet then text = text .. " |cff8c8c8c· " .. (QK:GebietName(q.gebiet) or "") .. "|r" end
  local e = { text = text, rechts = QK:EPText(q.ep) or "", quest = q }
  if q.status == 1 then e.symbol, e.farbe = IM_LOG, QK.farben.gold
  elseif q.status == 2 then e.symbol, e.farbe = OFFEN, QK.farben.hell
  else e.symbol, e.farbe = HAKEN, QK.farben.grau end
  -- Status zusätzlich als Wort, damit er nicht nur an Farbe und Symbol hängt
  if QK.db.farbenblind or QK.db.kontrast then
    e.text = e.text .. "  |cffbfbfbf(" .. ({ L"im Log", L"offen", L"erledigt" })[q.status] .. ")|r"
  end
  if q.status == 2 and QK.Extras and QK.Extras:Gemerkt(q.id) then e.text = MERK .. " " .. e.text end
  if q.status == 2 and QK.Twinks then
    local andere = QK.Twinks:Andere(q.id)
    if #andere > 0 then e.text = e.text .. " |cff7fbfff(" .. L"Twink" .. ")|r" end
  end
  if mitGebiet and q.gebiet then e.klick = function() G:GebietWaehlen(q.gebiet) end end
  return e
end
G.QuestEintrag = QuestEintrag

---------------------------------------------------------------------------
-- Reiter
---------------------------------------------------------------------------
function AUFBAU.gebiet()
  if folgen or not gebietID then gebietID = QK:AktuellesGebiet() or gebietID end
  if not gebietID then
    gebietTitel:SetText(L"Unbekanntes Gebiet")
    gebietUnter:SetText(L"Keine Questdaten für diese Zone. Mit den Pfeilen wählst du ein Gebiet.")
    gebietBalken:SetMinMaxValues(0, 1); gebietBalken:SetValue(0)
    gebietBalkenText:SetText("")
    Zeichnen({})
    return
  end
  local liste = G:Liste(gebietID)
  local anzahl, epOffen, eintraege = { 0, 0, 0 }, 0, {}
  local passend = { nil, 2, 1, 3 }
  for _, q in ipairs(liste) do
    anzahl[q.status] = anzahl[q.status] + 1
    if q.status ~= 3 then epOffen = epOffen + (q.ep or 0) end
    if filter == 1 or q.status == passend[filter] then eintraege[#eintraege + 1] = QuestEintrag(q) end
  end
  if #eintraege == 0 and #liste > 0 then eintraege[1] = { text = L"Nichts in diesem Filter.", farbe = QK.farben.grau } end
  filterKnopf:SetText(L(FILTER[filter]))
  Zeichnen(eintraege)
  gebietTitel:SetText(QK:GebietName(gebietID))
  gebietUnter:SetText((L"%d im Log · %d offen%s"):format(anzahl[1], anzahl[2],
    epOffen > 0 and (L" · noch " .. QK:EPText(epOffen)) or ""))
  gebietBalken:SetMinMaxValues(0, math.max(1, #liste))
  gebietBalken:SetValue(anzahl[3])
  gebietBalken:SetStatusBarColor(unpack(QK.farben.balken))
  gebietBalkenText:SetText((L"%d von %d erledigt"):format(anzahl[3], #liste))
end

function AUFBAU.welt()
  weltCache = weltCache or G:Welt()
  local erledigt, gesamt, eintraege = 0, 0, {}
  for _, w in ipairs(weltCache) do
    erledigt, gesamt = erledigt + w.erledigt, gesamt + w.gesamt
    local anteil = w.gesamt > 0 and w.erledigt / w.gesamt or 0
    eintraege[#eintraege + 1] = {
      text = QK:GebietName(w.id),
      rechts = ("%d/%d · %d %%"):format(w.erledigt, w.gesamt, math.floor(anteil * 100 + 0.5)),
      farbe = anteil >= 1 and QK.farben.gruen or QK.farben.hell,
      symbol = anteil >= 1 and HAKEN or "",
      anteil = anteil,
      klick = function() G:GebietWaehlen(w.id) end,
    }
  end
  Zeichnen(eintraege)
  weltBalken:SetMinMaxValues(0, math.max(1, gesamt))
  weltBalken:SetValue(erledigt)
  weltBalken:SetStatusBarColor(unpack(QK.farben.balken))
  weltBalkenText:SetText((L"%d von %d Quests in %d Gebieten"):format(erledigt, gesamt, #weltCache))
end

function AUFBAU.suche()
  local eintraege = {}
  if #suchText >= 3 then
    for _, q in ipairs(G:Suchen(suchText)) do eintraege[#eintraege + 1] = QuestEintrag(q, true) end
    if #eintraege == 0 then eintraege[1] = { text = L"Nichts gefunden.", farbe = QK.farben.grau } end
  else
    eintraege[1] = { text = L"Mindestens drei Buchstaben eingeben, deutsch oder englisch.", farbe = QK.farben.grau }
  end
  Zeichnen(eintraege)
end

function AUFBAU.tagebuch()
  local buch = QK.char.tagebuch
  local eintraege = {}
  local heute = date("%d.%m.")
  for i = #buch, 1, -1 do
    local e = buch[i]
    local tag = date("%d.%m.", e.zeit)
    local rechts = QK:EPText(e.ep) or ""
    if e.dauer then rechts = rechts .. (rechts ~= "" and " · " or "") .. QK:DauerText(e.dauer) end
    eintraege[#eintraege + 1] = {
      symbol = HAKEN,
      text = (tag == heute and date("%H:%M", e.zeit) or tag) .. "  " .. (e.name or (L"Quest " .. e.id)),
      rechts = rechts,
      quest = QK:Quest(e.id) and (function() local q = QK:Quest(e.id); q.status = 3; return q end)() or nil,
    }
  end
  if #eintraege == 0 then eintraege[1] = { text = L"Noch keine Quest abgegeben, seit Questkompass läuft.", farbe = QK.farben.grau } end
  Zeichnen(eintraege)
  local dauer = sitzung.start and (GetTime() - sitzung.start) or 0
  local proStunde = dauer > 120 and math.floor(sitzung.ep / dauer * 3600) or nil
  buchStatistik:SetText((L"Diese Sitzung: %d Quests · %s%s\nInsgesamt im Tagebuch: %d Quests"):format(
    sitzung.quests, QK:EPText(sitzung.ep) or "0 EP",
    proStunde and (" · " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(proStunde) or proStunde) .. L" EP pro Stunde") or "",
    #buch))
end

function G:Aktualisieren()
  if not fenster or not fenster:IsShown() then return end
  fenster:SetScale(QK:Groesse())
  fenster:SetBackdropColor(0.06, 0.06, 0.08, QK:Deckkraft(0.95))
  for name, k in pairs(koepfe) do k:SetShown(name == reiter) end
  for name, b in pairs(reiterKnoepfe) do
    b.text:SetTextColor(unpack(name == reiter and QK.farben.gold or QK.farben.grau))
    b.strich:SetShown(name == reiter)
    b.strich:SetColorTexture(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 1)
  end
  if not AUFBAU[reiter] then reiter = "gebiet" end
  AUFBAU[reiter]()
end

function G:GebietWaehlen(id)
  gebietID, folgen = id, id == QK:AktuellesGebiet()
  reiter = "gebiet"
  G:Aktualisieren()
end

local function Blaettern(richtung)
  local liste = Gebiete()
  if #liste == 0 then return end
  local pos = 0
  for i, id in ipairs(liste) do if id == gebietID then pos = i break end end
  pos = ((pos - 1 + richtung) % #liste) + 1
  G:GebietWaehlen(liste[pos])
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local function Knopf(eltern, text, breite, beiKlick)
  local b = CreateFrame("Button", nil, eltern, "UIPanelButtonTemplate")
  b:SetSize(breite, 20)
  b:SetText(text)
  b:SetScript("OnClick", beiKlick)
  return b
end

local function Balken(eltern, y)
  local b = CreateFrame("StatusBar", nil, eltern)
  b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  b:SetPoint("TOPLEFT", 0, y)
  b:SetPoint("TOPRIGHT", 0, y)
  b:SetHeight(14)
  b:SetMinMaxValues(0, 1)
  b:SetValue(0)
  local hg = b:CreateTexture(nil, "BACKGROUND")
  hg:SetAllPoints()
  hg:SetColorTexture(1, 1, 1, 0.08)
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("CENTER")
  return b, t
end

function G.KopfBereich(name)
  local k = CreateFrame("Frame", nil, fenster)
  k:SetPoint("TOPLEFT", 14, -62)
  k:SetPoint("TOPRIGHT", -14, -62)
  k:SetHeight(64)
  k:Hide()
  koepfe[name] = k
  return k
end

local function Erstellen()
  fenster = CreateFrame("Frame", "QuestkompassGebiet", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  fenster:SetSize(490, 520)
  fenster:SetFrameStrata("DIALOG")
  fenster:SetClampedToScreen(true)
  fenster:SetMovable(true)
  fenster:EnableMouse(true)
  fenster:RegisterForDrag("LeftButton")
  fenster:SetScript("OnDragStart", fenster.StartMoving)
  fenster:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    QK.db.gebietPos = { p, rp, x, y }
  end)
  fenster:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  fenster:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
  fenster:SetBackdropBorderColor(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.35)
  local p = QK.db.gebietPos
  if p then fenster:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else fenster:SetPoint("CENTER") end
  tinsert(UISpecialFrames, "QuestkompassGebiet")

  local schliessen = CreateFrame("Button", nil, fenster, "UIPanelCloseButton")
  schliessen:SetPoint("TOPRIGHT", 2, 2)
  local kopf = fenster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  kopf:SetPoint("TOPLEFT", 14, -12)
  kopf:SetText("QUESTBUCH")
  kopf:SetTextColor(unpack(QK.farben.gold))

  -- Reiter
  local x = 14
  for _, r in ipairs(REITER) do
    local b = CreateFrame("Button", nil, fenster)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT")
    b.text:SetText(L(r[2]))
    b:SetSize((b.text:GetStringWidth() or 50) + 4, 22)
    b:SetPoint("TOPLEFT", x, -30)
    b.strich = b:CreateTexture(nil, "ARTWORK")
    b.strich:SetPoint("BOTTOMLEFT", 0, 0)
    b.strich:SetPoint("BOTTOMRIGHT", -4, 0)
    b.strich:SetHeight(2)
    b:SetScript("OnClick", function()
      reiter = r[1]
      auswahl = 0
      if r[1] == "welt" then weltCache = nil end
      G:Aktualisieren()
      if r[1] == "suche" and suchFeld then suchFeld:SetFocus() end
    end)
    reiterKnoepfe[r[1]] = b
    x = x + (b.text:GetStringWidth() or 50) + 14
  end
  for _, r in ipairs(REITER) do
    if KOPFBAU[r[1]] then KOPFBAU[r[1]](G.KopfBereich(r[1])) end
  end

  -- Kopf: Gebiet
  local kg = G.KopfBereich("gebiet")
  gebietTitel = kg:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  gebietTitel:SetPoint("TOPLEFT", 0, 0)
  gebietTitel:SetPoint("RIGHT", -90, 0)
  gebietTitel:SetJustifyH("LEFT")
  gebietTitel:SetWordWrap(false)
  local zurueck = Knopf(kg, "<", 24, function() Blaettern(-1) end)
  zurueck:SetPoint("TOPRIGHT", -62, 2)
  local hier = Knopf(kg, L"Hier", 34, function()
    local liste = QK:GebieteHier()
    local pos = 0
    for i, id in ipairs(liste) do if id == gebietID then pos = i end end
    gebietID = liste[(pos % math.max(1, #liste)) + 1]
    folgen = false
    G:Aktualisieren()
  end)
  hier:SetPoint("LEFT", zurueck, "RIGHT", 2, 0)
  hier:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L"Gebiete hier", unpack(QK.farben.gold))
    GameTooltip:AddLine(L"Mehrfach klicken wechselt zwischen Zone, Teilgebiet und den Gebieten deiner Quests.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  hier:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local weiter = Knopf(kg, ">", 24, function() Blaettern(1) end)
  weiter:SetPoint("LEFT", hier, "RIGHT", 2, 0)
  gebietUnter = kg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  gebietUnter:SetPoint("TOPLEFT", gebietTitel, "BOTTOMLEFT", 0, -4)
  gebietUnter:SetPoint("RIGHT", -84, 0)
  filterKnopf = Knopf(kg, L"Alle", 80, function()
    filter = (filter % #FILTER) + 1
    auswahl = 0
    G:Aktualisieren()
  end)
  filterKnopf:SetPoint("TOPRIGHT", 0, -22)
  filterKnopf:SetHeight(18)
  gebietUnter:SetJustifyH("LEFT")
  gebietBalken, gebietBalkenText = Balken(kg, -46)

  -- Kopf: Welt
  local kw = G.KopfBereich("welt")
  weltTitel = kw:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  weltTitel:SetPoint("TOPLEFT")
  weltTitel:SetText(L"Weltfortschritt")
  local wu = kw:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  wu:SetPoint("TOPLEFT", weltTitel, "BOTTOMLEFT", 0, -4)
  wu:SetText(L"Klick auf ein Gebiet öffnet seine Quests.")
  weltBalken, weltBalkenText = Balken(kw, -46)

  -- Kopf: Suche
  local ks = G.KopfBereich("suche")
  local st = ks:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  st:SetPoint("TOPLEFT")
  st:SetText(L"Quest suchen")
  suchFeld = CreateFrame("EditBox", "QuestkompassSuche", ks, "InputBoxTemplate")
  suchFeld:SetAutoFocus(false)
  suchFeld:SetHeight(22)
  suchFeld:SetPoint("TOPLEFT", 6, -26)
  suchFeld:SetPoint("TOPRIGHT", 0, -26)
  suchFeld:SetScript("OnTextChanged", function(self)
    suchText = self:GetText() or ""
    if reiter == "suche" then QK:Sicher("Suche", AUFBAU.suche) end
  end)
  suchFeld:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  suchFeld:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  -- Kopf: Tagebuch
  local kt = G.KopfBereich("tagebuch")
  local tt = kt:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  tt:SetPoint("TOPLEFT")
  tt:SetText(L"Questtagebuch")
  buchStatistik = kt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  buchStatistik:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 0, -6)
  buchStatistik:SetPoint("RIGHT", 0, 0)
  buchStatistik:SetJustifyH("LEFT")
  buchStatistik:SetSpacing(3)

  scroll = CreateFrame("ScrollFrame", "QuestkompassGebietScroll", fenster, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -132)
  scroll:SetPoint("BOTTOMRIGHT", -30, 30)
  inhalt = CreateFrame("Frame", nil, scroll)
  inhalt:SetSize(440, 1)
  scroll:SetScrollChild(inhalt)
  scroll:SetScript("OnSizeChanged", function(_, w) inhalt:SetWidth(w) end)

  fuss = fenster:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  fuss:SetPoint("BOTTOMLEFT", 14, 10)
  fuss:SetPoint("BOTTOMRIGHT", -14, 10)
  fuss:SetJustifyH("LEFT")
  fuss:SetText((L"Daten: Blizzard Entertainment, Stand %s · foreverui.de"):format(QK.datenStand or "?"))

  fenster:SetScript("OnShow", function() QK:Sicher("Questbuch", G.Aktualisieren, G) end)
  fenster:Hide()
end

function G:Zeigen(name)
  if not fenster then Erstellen() end
  if name then
    local id = QK:GebietZuName(name)
    if not id then
      QK:Meldung(L"kein Gebiet namens „%s“ gefunden.", name)
      return
    end
    gebietID, folgen = id, id == QK:AktuellesGebiet()
  else
    gebietID, folgen = nil, true
  end
  reiter = "gebiet"
  fenster:Show()
  QK:Sicher("Questbuch", G.Aktualisieren, G)
end

function G:Reiter(name, text)
  if not fenster then Erstellen() end
  if reiter ~= name then auswahl = 0 end
  reiter = name
  if name == "welt" then weltCache = nil end
  if name == "suche" and text and text ~= "" then suchFeld:SetText(text); suchText = text end
  fenster:Show()
  QK:Sicher("Questbuch", G.Aktualisieren, G)
end

function G:Umschalten()
  if fenster and fenster:IsShown() then fenster:Hide() else G:Zeigen() end
end

---------------------------------------------------------------------------
-- Tagebuch und Sitzung
---------------------------------------------------------------------------
local function EPMessen()
  local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
  if letzteXP then
    if xp >= letzteXP then sitzung.ep = sitzung.ep + (xp - letzteXP)
    else sitzung.ep = sitzung.ep + (letzteMax - letzteXP) + xp end
  end
  letzteXP, letzteMax = xp, max
end

function G:Start()
  sitzung.start = GetTime()
  EPMessen()
  local geplant = false
  local function planen()
    if geplant or not fenster or not fenster:IsShown() then return end
    geplant = true
    C_Timer.After(0.5, function() geplant = false; QK:Sicher("Questbuch", G.Aktualisieren, G) end)
  end
  QK:Ereignis("ZONE_CHANGED_NEW_AREA", planen)
  QK:Ereignis("QUEST_LOG_UPDATE", planen)
  QK:Ereignis("PLAYER_XP_UPDATE", EPMessen)
  QK:Ereignis("QUEST_TURNED_IN", function(questID, ep, geld)
    if not questID then return end
    sitzung.quests = sitzung.quests + 1
    local daten = QK:Quest(questID)
    local buch = QK.char.tagebuch
    local seit = QK.char.angenommen and QK.char.angenommen[questID]
    local jetzt = time()
    buch[#buch + 1] = {
      id = questID,
      name = (QK.Compat.titel and QK.Compat.titel[questID]) or (daten and daten.name),
      zeit = jetzt,
      ep = (ep and ep > 0) and ep or (daten and daten.ep) or 0,
      gold = (geld and geld > 0) and geld or nil,
      gebiet = daten and daten.gebiet or nil,
      dauer = (seit and not QK.char.geschaetzt[questID] and jetzt - seit > 0) and (jetzt - seit) or nil,
    }
    while #buch > 500 do table.remove(buch, 1) end
    weltCache = nil
    planen()
  end)
end

function G:Anwenden()
  if fenster and fenster:IsShown() then G:Aktualisieren() end
end
