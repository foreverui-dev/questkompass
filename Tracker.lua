-- Questkompass: die Zielliste neben der Minikarte.
local _, QK = ...
local T = {}
QK.Tracker = T

local ZEILE_TITEL, ZEILE_ZIEL, BALKEN_HOEHE = 16, 14, 3
local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t "
local versteck = CreateFrame("Frame")
versteck:Hide()

local rahmen, kopf, kopfText, zaehler, gebietKnopf
local zeilen, benutzt = {}, 0
local eingeklappt = false

---------------------------------------------------------------------------
-- Zeilen
---------------------------------------------------------------------------
local function ZeileKlick(self, taste)
  local q = self.quest
  if not q then return end
  if taste == "RightButton" then
    if q.id then
      QK.char.ausgeblendet[q.id] = true
      QK:Meldung("„%s“ ausgeblendet. /qk einblenden holt sie zurück.", q.titel)
      T:Aktualisieren()
    end
  elseif IsShiftKeyDown() and GetQuestLink then
    local link = GetQuestLink(q.index)
    if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
  else
    if QuestLogFrame and not QuestLogFrame:IsShown() then ShowUIPanel(QuestLogFrame) end
    if QuestLog_SetSelection then
      QuestLog_SetSelection(q.index)
    else
      SelectQuestLogEntry(q.index)
    end
    if QuestLog_Update then QuestLog_Update() end
  end
end

local function ZeileTooltip(self)
  local q = self.quest
  if not q then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(q.titel, unpack(QK.farben.gold))
  if q.zone then GameTooltip:AddLine(q.zone, 0.8, 0.8, 0.8) end
  QK.Tooltip:Ergaenzen(GameTooltip, q.id, true)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Linksklick: im Questlog öffnen", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Umschalt+Klick: Link in den Chat", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Rechtsklick: hier ausblenden", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function NeueZeile()
  local z = CreateFrame("Button", nil, rahmen)
  z:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  z:SetScript("OnClick", ZeileKlick)
  z:SetScript("OnEnter", ZeileTooltip)
  z:SetScript("OnLeave", GameTooltip_Hide)
  z.text = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  z.text:SetPoint("TOPLEFT")
  z.text:SetPoint("TOPRIGHT")
  z.text:SetJustifyH("LEFT")
  z.text:SetWordWrap(false)
  z.balken = CreateFrame("StatusBar", nil, z)
  z.balken:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  z.balken:SetHeight(BALKEN_HOEHE)
  z.balken:SetPoint("BOTTOMLEFT", 0, 1)
  z.balken:SetPoint("BOTTOMRIGHT", 0, 1)
  z.balken.hg = z.balken:CreateTexture(nil, "BACKGROUND")
  z.balken.hg:SetAllPoints()
  z.balken.hg:SetColorTexture(1, 1, 1, 0.08)
  return z
end

local function Zeile(text, hoehe, einzug, schrift, farbe, quest)
  benutzt = benutzt + 1
  local z = zeilen[benutzt]
  if not z then
    z = NeueZeile()
    zeilen[benutzt] = z
  end
  z.text:SetFontObject(schrift)
  z.text:SetText(text)
  z.text:SetTextColor(unpack(farbe))
  z.text:SetPoint("TOPLEFT", einzug, 0)
  z:SetHeight(hoehe)
  z.balken:Hide()
  z.quest = quest
  z:Show()
  return z
end

---------------------------------------------------------------------------
-- Inhalt
---------------------------------------------------------------------------
local function Sortieren(quests, hier)
  for i, q in ipairs(quests) do q.reihenfolge = i end
  table.sort(quests, function(a, b)
    local ah, bh = a.gebiet ~= nil and hier[a.gebiet] == true, b.gebiet ~= nil and hier[b.gebiet] == true
    if ah ~= bh then return ah end
    if a.fertig ~= b.fertig then return a.fertig end
    return a.reihenfolge < b.reihenfolge
  end)
end

local function AlleZieleFertig(q)
  if #q.ziele == 0 then return false end
  for _, ziel in ipairs(q.ziele) do
    if not ziel.fertig then return false end
  end
  return true
end

local function Stufenfarbe(stufe)
  if GetQuestDifficultyColor and stufe then
    local c = GetQuestDifficultyColor(stufe)
    return { c.r, c.g, c.b }
  end
  return QK.farben.gold
end

function T:Aktualisieren()
  if not rahmen then return end
  local db = QK.db
  rahmen:SetWidth(db.breite)
  for i = 1, benutzt do zeilen[i]:Hide() end
  benutzt = 0

  local alle = QK:Questlog()
  local quests = {}
  for _, q in ipairs(alle) do
    if not (q.id and QK.char.ausgeblendet[q.id]) and (db.modus ~= "verfolgt" or q.verfolgt) then
      quests[#quests + 1] = q
    end
  end
  local hier = QK:AktuelleGebiete()
  Sortieren(quests, hier)

  zaehler:SetText(("%d/%d"):format(#alle, MAX_QUESTLOG_QUESTS or 20))
  local y = -24
  if not eingeklappt then
    if #quests == 0 then
      local z = Zeile(#alle == 0 and "Keine Quests im Log." or "Nichts zu zeigen (/qk alle).",
        ZEILE_ZIEL, 0, "GameFontDisableSmall", QK.farben.grau)
      z:SetPoint("TOPLEFT", rahmen, "TOPLEFT", 10, y)
      z:SetPoint("TOPRIGHT", rahmen, "TOPRIGHT", -10, y)
      y = y - ZEILE_ZIEL
    end
    for n = 1, math.min(#quests, db.anzahl) do
      local q = quests[n]
      local titel = q.stufe and ("[%d%s] %s"):format(q.stufe, (q.gruppe and q.gruppe > 0) and "+" or "", q.titel) or q.titel
      local z = Zeile(titel, ZEILE_TITEL, 0, "GameFontNormal", Stufenfarbe(q.stufe), q)
      if not (q.gebiet and hier[q.gebiet]) and q.zone then
        z.text:SetText(titel .. " |cff8c8c8c· " .. q.zone .. "|r")
      end
      z:SetPoint("TOPLEFT", rahmen, "TOPLEFT", 10, y)
      z:SetPoint("TOPRIGHT", rahmen, "TOPRIGHT", -10, y)
      y = y - ZEILE_TITEL

      local function Ziel(text, farbe, ist, soll)
        local hoehe = ZEILE_ZIEL + ((ist and soll and soll > 1) and BALKEN_HOEHE + 2 or 0)
        local zz = Zeile(text, hoehe, 10, "GameFontHighlightSmall", farbe, q)
        zz:SetPoint("TOPLEFT", rahmen, "TOPLEFT", 10, y)
        zz:SetPoint("TOPRIGHT", rahmen, "TOPRIGHT", -10, y)
        if ist and soll and soll > 1 then
          zz.balken:ClearAllPoints()
          zz.balken:SetPoint("BOTTOMLEFT", 10, 1)
          zz.balken:SetPoint("BOTTOMRIGHT", 0, 1)
          zz.balken:SetMinMaxValues(0, soll)
          zz.balken:SetValue(math.min(ist, soll))
          zz.balken:SetStatusBarColor(unpack(QK.farben.balken))
          zz.balken:Show()
        end
        y = y - hoehe
      end

      if q.gescheitert then
        Ziel("Gescheitert", { 0.9, 0.3, 0.3 })
      elseif q.fertig or AlleZieleFertig(q) then
        Ziel(HAKEN .. "Bereit zum Abgeben", QK.farben.gruen)
      else
        for _, ziel in ipairs(q.ziele) do
          if ziel.fertig then
            Ziel(HAKEN .. ziel.text, QK.farben.grau)
          elseif ziel.ist and ziel.soll then
            Ziel(("%s  |cffbfbfbf%d/%d|r"):format(ziel.text, ziel.ist, ziel.soll), QK.farben.hell, ziel.ist, ziel.soll)
          else
            Ziel(ziel.text, QK.farben.hell)
          end
        end
      end
      y = y - 4
    end
    if #quests > db.anzahl then
      local z = Zeile(("+ %d weitere"):format(#quests - db.anzahl), ZEILE_ZIEL, 0, "GameFontDisableSmall", QK.farben.grau)
      z:SetPoint("TOPLEFT", rahmen, "TOPLEFT", 10, y)
      z:SetPoint("TOPRIGHT", rahmen, "TOPRIGHT", -10, y)
      y = y - ZEILE_ZIEL
    end
  end
  rahmen:SetHeight(-y + 6)
end

-- Mehrere Ereignisse kurz hintereinander lösen nur eine Aktualisierung aus.
local geplant = false
function T:Planen()
  if geplant then return end
  geplant = true
  C_Timer.After(0.1, function()
    geplant = false
    T:Aktualisieren()
  end)
end

---------------------------------------------------------------------------
-- Rahmen, Position, Optionen
---------------------------------------------------------------------------
function T:Positionieren()
  local p = QK.db.pos
  rahmen:ClearAllPoints()
  local anker = _G[p[2]] or UIParent
  rahmen:SetPoint(p[1], anker, p[3], p[4], p[5])
end

function T:Sperre()
  rahmen:SetMovable(not QK.db.gesperrt)
end

function T:Skalieren()
  rahmen:SetScale(QK.db.skalierung or 1)
end

function T:Ruhe(imKampf)
  rahmen:SetAlpha((imKampf and QK.db.ruhemodus) and QK.db.ruheAlpha or 1)
end

function T:BlizzardTracker()
  local f = QuestWatchFrame
  if not f then return end
  if QK.db.blizzardAusblenden then
    f:Hide()
  elseif QuestWatch_Update then
    f:Show()
    QuestWatch_Update()
  end
end

function T:Umschalten()
  QK.db.versteckt = not QK.db.versteckt
  rahmen:SetShown(not QK.db.versteckt)
  if not QK.db.versteckt then T:Aktualisieren() end
end

function T:Start()
  rahmen = CreateFrame("Frame", "QuestkompassListe", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  rahmen:SetSize(QK.db.breite, 40)
  rahmen:SetFrameStrata("LOW")
  rahmen:SetClampedToScreen(true)
  rahmen:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  rahmen:SetBackdropColor(0.05, 0.05, 0.07, 0.55)
  rahmen:SetBackdropBorderColor(1, 1, 1, 0.08)

  kopf = CreateFrame("Button", nil, rahmen)
  kopf:SetPoint("TOPLEFT", 0, 0)
  kopf:SetPoint("TOPRIGHT", -22, 0)
  kopf:SetHeight(20)
  kopf:RegisterForDrag("LeftButton")
  kopf:RegisterForClicks("LeftButtonUp")
  kopf:SetScript("OnDragStart", function() if rahmen:IsMovable() then rahmen:StartMoving() end end)
  kopf:SetScript("OnDragStop", function()
    rahmen:StopMovingOrSizing()
    local p, _, rp, x, y = rahmen:GetPoint()
    QK.db.pos = { p, "UIParent", rp, x, y }
  end)
  kopf:SetScript("OnClick", function()
    eingeklappt = not eingeklappt
    T:Aktualisieren()
  end)
  kopf:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Questkompass", unpack(QK.farben.gold))
    GameTooltip:AddLine("Klick: ein- oder ausklappen", 0.8, 0.8, 0.8)
    if not QK.db.gesperrt then GameTooltip:AddLine("Ziehen: verschieben", 0.8, 0.8, 0.8) end
    GameTooltip:AddLine("/qk hilfe: alle Befehle", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  kopf:SetScript("OnLeave", GameTooltip_Hide)

  kopfText = kopf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  kopfText:SetPoint("LEFT", 10, -1)
  kopfText:SetText("QUESTKOMPASS")
  kopfText:SetTextColor(unpack(QK.farben.gold))
  zaehler = kopf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zaehler:SetPoint("RIGHT", 0, -1)

  gebietKnopf = CreateFrame("Button", nil, rahmen)
  gebietKnopf:SetSize(16, 16)
  gebietKnopf:SetPoint("TOPRIGHT", -5, -2)
  gebietKnopf:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
  gebietKnopf:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  gebietKnopf:SetScript("OnClick", function() QK.Gebiet:Umschalten() end)
  gebietKnopf:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Gebietsfortschritt", unpack(QK.farben.gold))
    GameTooltip:AddLine("Welche Quests es in dieser Zone gibt", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  gebietKnopf:SetScript("OnLeave", GameTooltip_Hide)

  T:Positionieren()
  T:Sperre()
  T:Skalieren()
  rahmen:SetShown(not QK.db.versteckt)

  if QuestWatchFrame then
    hooksecurefunc(QuestWatchFrame, "Show", function(f)
      if QK.db.blizzardAusblenden then f:Hide() end
    end)
  end
  T:BlizzardTracker()

  rahmen:RegisterEvent("QUEST_LOG_UPDATE")
  rahmen:RegisterEvent("QUEST_WATCH_UPDATE")
  rahmen:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
  rahmen:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  rahmen:RegisterEvent("ZONE_CHANGED")
  rahmen:RegisterEvent("PLAYER_ENTERING_WORLD")
  rahmen:RegisterEvent("PLAYER_REGEN_DISABLED")
  rahmen:RegisterEvent("PLAYER_REGEN_ENABLED")
  rahmen:SetScript("OnEvent", function(_, ereignis)
    if ereignis == "PLAYER_REGEN_DISABLED" then
      T:Ruhe(true)
    elseif ereignis == "PLAYER_REGEN_ENABLED" then
      T:Ruhe(false)
    else
      T:Planen()
    end
  end)
  -- Ein/Aus der Questverfolgung im Questlog
  if AddQuestWatch then hooksecurefunc("AddQuestWatch", function() T:Planen() end) end
  if RemoveQuestWatch then hooksecurefunc("RemoveQuestWatch", function() T:Planen() end) end

  T:Aktualisieren()
end
