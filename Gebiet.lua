-- Questkompass: Gebietsfortschritt. Zeigt, welche Quests es in einer Zone gibt,
-- welche erledigt sind, welche im Log stehen und welche noch offen sind.
local _, QK = ...
local G = QK:Modul("Gebiet")

local ZEILE = 16
local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
local fenster, titel, unterzeile, balken, balkenText, scroll, inhalt, fuss
local zeilen = {}
local gebietID, folgen = nil, true
local gebietListe

-- Gebiete mit mindestens einer Quest für diesen Charakter, alphabetisch.
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

-- Quests eines Gebiets mit Status: 1 = im Log, 2 = offen, 3 = erledigt
function G:Liste(id)
  local imLog = {}
  for _, q in ipairs(QK.Compat:Questlog()) do
    if q.id then imLog[q.id] = true end
  end
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

local function NeueZeile()
  local z = CreateFrame("Button", nil, inhalt)
  z:SetHeight(ZEILE)
  z.symbol = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  z.symbol:SetPoint("LEFT", 2, 0)
  z.symbol:SetWidth(16)
  z.ep = z:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  z.ep:SetPoint("RIGHT", -4, 0)
  z.ep:SetJustifyH("RIGHT")
  z.text = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  z.text:SetPoint("LEFT", 20, 0)
  z.text:SetPoint("RIGHT", z.ep, "LEFT", -6, 0)
  z.text:SetJustifyH("LEFT")
  z.text:SetWordWrap(false)
  z.hl = z:CreateTexture(nil, "HIGHLIGHT")
  z.hl:SetAllPoints()
  z.hl:SetColorTexture(1, 1, 1, 0.06)
  z:SetScript("OnEnter", function(self)
    local q = self.quest
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(q.name or ("Quest " .. q.id), unpack(QK.farben.gold))
    GameTooltip:AddLine(({ "Steht in deinem Questlog", "Noch nicht gemacht", "Erledigt" })[q.status], 0.8, 0.8, 0.8)
    QK.Tooltip:Ergaenzen(GameTooltip, q.id, true)
    GameTooltip:Show()
  end)
  z:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return z
end

function G:Aktualisieren()
  if not fenster or not fenster:IsShown() then return end
  if folgen or not gebietID then
    gebietID = QK:AktuellesGebiet() or gebietID
  end
  for _, z in ipairs(zeilen) do z:Hide() end
  if not gebietID then
    titel:SetText("Unbekanntes Gebiet")
    unterzeile:SetText("Für diese Zone gibt es keine Questdaten. Mit den Pfeilen kannst du ein Gebiet wählen.")
    balken:SetValue(0)
    balkenText:SetText("")
    inhalt:SetHeight(1)
    return
  end
  local liste = self:Liste(gebietID)
  local anzahl = { 0, 0, 0 }
  local epOffen = 0
  for i, q in ipairs(liste) do
    anzahl[q.status] = anzahl[q.status] + 1
    if q.status ~= 3 then epOffen = epOffen + (q.ep or 0) end
    local z = zeilen[i] or NeueZeile()
    zeilen[i] = z
    z.quest = q
    z:SetPoint("TOPLEFT", 0, -(i - 1) * ZEILE)
    z:SetPoint("RIGHT", inhalt, "RIGHT")
    local typ = QK:TypName(q.typ)
    z.text:SetText((q.name or ("Quest " .. q.id)) .. (typ and (" |cffd98c40(" .. typ .. ")|r") or ""))
    z.ep:SetText(QK:EPText(q.ep) or "")
    if q.status == 1 then
      z.symbol:SetText("|TInterface\\GossipFrame\\ActiveQuestIcon:12:12:0:0|t")
      z.text:SetTextColor(unpack(QK.farben.gold))
    elseif q.status == 2 then
      z.symbol:SetText("|TInterface\\GossipFrame\\AvailableQuestIcon:12:12:0:0|t")
      z.text:SetTextColor(unpack(QK.farben.hell))
    else
      z.symbol:SetText(HAKEN)
      z.text:SetTextColor(unpack(QK.farben.grau))
    end
    z:Show()
  end
  inhalt:SetHeight(math.max(1, #liste * ZEILE))
  titel:SetText(QK:GebietName(gebietID))
  local gesamt = #liste
  unterzeile:SetText(("%d im Log · %d offen%s"):format(anzahl[1], anzahl[2],
    epOffen > 0 and (" · noch " .. QK:EPText(epOffen)) or ""))
  balken:SetMinMaxValues(0, math.max(1, gesamt))
  balken:SetValue(anzahl[3])
  balkenText:SetText(("%d von %d erledigt"):format(anzahl[3], gesamt))
end

local function Blaettern(richtung)
  local liste = Gebiete()
  if #liste == 0 then return end
  local pos = 0
  for i, id in ipairs(liste) do if id == gebietID then pos = i break end end
  pos = ((pos - 1 + richtung) % #liste) + 1
  gebietID = liste[pos]
  folgen = gebietID == QK:AktuellesGebiet()
  G:Aktualisieren()
end

local function Knopf(text, breite, beiKlick)
  local b = CreateFrame("Button", nil, fenster, "UIPanelButtonTemplate")
  b:SetSize(breite, 20)
  b:SetText(text)
  b:SetScript("OnClick", beiKlick)
  return b
end

local function Erstellen()
  fenster = CreateFrame("Frame", "QuestkompassGebiet", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  fenster:SetSize(340, 440)
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
  fenster:SetBackdropColor(0.06, 0.06, 0.08, 0.94)
  fenster:SetBackdropBorderColor(0.95, 0.77, 0.35, 0.35)
  local p = QK.db.gebietPos
  if p then fenster:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else fenster:SetPoint("CENTER") end
  tinsert(UISpecialFrames, "QuestkompassGebiet")

  local schliessen = CreateFrame("Button", nil, fenster, "UIPanelCloseButton")
  schliessen:SetPoint("TOPRIGHT", 2, 2)

  local kopf = fenster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  kopf:SetPoint("TOPLEFT", 14, -12)
  kopf:SetText("GEBIETSFORTSCHRITT")
  kopf:SetTextColor(unpack(QK.farben.gold))

  titel = fenster:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  titel:SetPoint("TOPLEFT", 14, -30)
  titel:SetPoint("RIGHT", -90, 0)
  titel:SetJustifyH("LEFT")

  local zurueck = Knopf("<", 24, function() Blaettern(-1) end)
  zurueck:SetPoint("TOPRIGHT", -62, -30)
  local hier = Knopf("Hier", 34, function()
    -- Mehrfach klicken wechselt zwischen den Gebieten rund um den Charakter.
    local liste = QK:GebieteHier()
    local pos = 0
    for i, id in ipairs(liste) do if id == gebietID then pos = i end end
    gebietID = liste[(pos % math.max(1, #liste)) + 1]
    folgen = false
    G:Aktualisieren()
  end)
  hier:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Gebiete hier", unpack(QK.farben.gold))
    GameTooltip:AddLine("Mehrfach klicken wechselt zwischen Zone, Teilgebiet und den Gebieten deiner Quests.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  hier:SetScript("OnLeave", function() GameTooltip:Hide() end)
  hier:SetPoint("LEFT", zurueck, "RIGHT", 2, 0)
  local weiter = Knopf(">", 24, function() Blaettern(1) end)
  weiter:SetPoint("LEFT", hier, "RIGHT", 2, 0)

  unterzeile = fenster:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  unterzeile:SetPoint("TOPLEFT", titel, "BOTTOMLEFT", 0, -4)
  unterzeile:SetPoint("RIGHT", -14, 0)
  unterzeile:SetJustifyH("LEFT")

  balken = CreateFrame("StatusBar", nil, fenster)
  balken:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  balken:SetStatusBarColor(unpack(QK.farben.balken))
  balken:SetPoint("TOPLEFT", 14, -78)
  balken:SetPoint("TOPRIGHT", -14, -78)
  balken:SetHeight(14)
  balken:SetMinMaxValues(0, 1)
  balken:SetValue(0)
  local hg = balken:CreateTexture(nil, "BACKGROUND")
  hg:SetAllPoints()
  hg:SetColorTexture(1, 1, 1, 0.08)
  balkenText = balken:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  balkenText:SetPoint("CENTER", 0, 0)

  scroll = CreateFrame("ScrollFrame", "QuestkompassGebietScroll", fenster, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -100)
  scroll:SetPoint("BOTTOMRIGHT", -30, 30)
  inhalt = CreateFrame("Frame", nil, scroll)
  inhalt:SetSize(300, 1)
  scroll:SetScrollChild(inhalt)
  scroll:SetScript("OnSizeChanged", function(self, w) inhalt:SetWidth(w) end)

  fuss = fenster:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  fuss:SetPoint("BOTTOMLEFT", 14, 10)
  fuss:SetPoint("BOTTOMRIGHT", -14, 10)
  fuss:SetJustifyH("LEFT")
  fuss:SetText(("Daten: Blizzard Entertainment, Stand %s · foreverui.de"):format(QK.datenStand or "?"))

  fenster:SetScript("OnShow", function() QK:Sicher("Gebiet", G.Aktualisieren, G) end)
  fenster:Hide()
end

function G:Zeigen(name)
  if not fenster then Erstellen() end
  if name then
    local id = QK:GebietZuName(name)
    if not id then
      QK:Meldung("kein Gebiet namens „%s“ gefunden.", name)
      return
    end
    gebietID, folgen = id, id == QK:AktuellesGebiet()
  else
    gebietID, folgen = nil, true
  end
  fenster:Show()
  QK:Sicher("Gebiet", G.Aktualisieren, G)
end

function G:Umschalten()
  if fenster and fenster:IsShown() then fenster:Hide() else G:Zeigen() end
end

function G:Start()
  local geplant = false
  local function planen()
    if geplant or not fenster or not fenster:IsShown() then return end
    geplant = true
    C_Timer.After(0.5, function() geplant = false; QK:Sicher("Gebiet", G.Aktualisieren, G) end)
  end
  QK:Ereignis("ZONE_CHANGED_NEW_AREA", planen)
  QK:Ereignis("QUEST_LOG_UPDATE", planen)
  QK:Ereignis("QUEST_TURNED_IN", planen)
end

function G:Anwenden()
  if fenster and fenster:IsShown() then G:Aktualisieren() end
end
