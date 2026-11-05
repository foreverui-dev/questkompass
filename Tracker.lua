-- Questkompass: die Zielliste.
local _, QK = ...
local T = QK:Modul("Tracker")

local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t "
local PFEIL = "Interface\\Minimap\\MiniMap-QuestArrow"
local SCHRIFTEN = {
  klein  = { titel = "GameFontNormalSmall", ziel = "GameFontHighlightSmall", hT = 14, hZ = 12 },
  normal = { titel = "GameFontNormal",      ziel = "GameFontHighlightSmall", hT = 16, hZ = 14 },
  gross  = { titel = "GameFontNormal",      ziel = "GameFontHighlight",      hT = 17, hZ = 15 },
}

local rahmen, kopf, zaehler, hintergrund
local zeilen, benutzt = {}, 0
local eingeklappt = false
local aktuelleQuests = {}
local menue

---------------------------------------------------------------------------
-- Kontextmenü (eigenes, damit es in jedem Client gleich aussieht)
---------------------------------------------------------------------------
local function MenueErstellen()
  menue = CreateFrame("Frame", "QuestkompassMenue", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  menue:SetFrameStrata("DIALOG")
  menue:SetClampedToScreen(true)
  menue:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  menue:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
  menue:SetBackdropBorderColor(0.95, 0.77, 0.35, 0.4)
  menue.knoepfe = {}
  menue:Hide()
  tinsert(UISpecialFrames, "QuestkompassMenue")
  menue:SetScript("OnShow", function(self) self.zeit = 0 end)
  menue:SetScript("OnUpdate", function(self, el)
    self.zeit = self.zeit + el
    if self.zeit > 0.5 and not self:IsMouseOver() then
      self.weg = (self.weg or 0) + el
      if self.weg > 1.5 then self:Hide() end
    else
      self.weg = 0
    end
  end)
end

local function MenueZeigen(anker, eintraege)
  if not menue then MenueErstellen() end
  for _, k in ipairs(menue.knoepfe) do k:Hide() end
  local breite = 160
  for i, e in ipairs(eintraege) do
    local k = menue.knoepfe[i]
    if not k then
      k = CreateFrame("Button", nil, menue)
      k:SetHeight(18)
      k.text = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      k.text:SetPoint("LEFT", 10, 0)
      local hl = k:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(0.95, 0.77, 0.35, 0.15)
      menue.knoepfe[i] = k
    end
    k:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 18)
    k:SetPoint("RIGHT", menue, "RIGHT", -4, 0)
    k.text:SetText(e[1])
    k:SetScript("OnClick", function() menue:Hide(); QK:Sicher("Menü", e[2]) end)
    k:Show()
    breite = math.max(breite, k.text:GetStringWidth() + 28)
  end
  menue:SetSize(breite, #eintraege * 18 + 8)
  menue:ClearAllPoints()
  menue:SetPoint("TOPRIGHT", anker, "TOPLEFT", -4, 0)
  menue:Show()
end

---------------------------------------------------------------------------
-- Zeilen
---------------------------------------------------------------------------
local function QuestMenue(zeile, q)
  local fokus = QK.Compat:Fokus() == q.id
  local e = {
    { fokus and "Fokus aufheben" or "Als Fokus setzen (Navigationspfeil)", function()
      QK.Compat:FokusSetzen(not fokus and q.id or nil); T:Aktualisieren() end },
    { "Im Questlog öffnen", function() QK.Compat:QuestOeffnen(q) end },
    { "Link in den Chat", function()
      local link = QK.Compat:QuestLink(q)
      if link and ChatEdit_InsertLink then
        if not ChatEdit_InsertLink(link) and ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
      end
    end },
  }
  if (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) then
    e[#e + 1] = { "Mit der Gruppe teilen", function() QK.Compat:Teilen(q) end }
  end
  e[#e + 1] = { "Hier ausblenden", function()
    QK.char.ausgeblendet[q.id] = true
    QK:Meldung("„%s“ ausgeblendet. /qk einblenden holt sie zurück.", q.titel)
    T:Aktualisieren()
  end }
  MenueZeigen(zeile, e)
end

local function ZeileKlick(self, taste)
  local q = self.quest
  if not q then return end
  if taste == "RightButton" then
    QuestMenue(self, q)
  elseif IsShiftKeyDown() then
    local link = QK.Compat:QuestLink(q)
    if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
  elseif IsControlKeyDown() then
    QK.Compat:QuestOeffnen(q)
  else
    local fokus = QK.Compat:Fokus() == q.id
    QK.Compat:FokusSetzen(not fokus and q.id or nil)
    T:Aktualisieren()
  end
end

local function ZeileTooltip(self)
  local q = self.quest
  if not q then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(q.titel, unpack(QK.farben.gold))
  if q.zone then GameTooltip:AddLine(q.zone, 0.8, 0.8, 0.8) end
  local d = QK.Kompass:Entfernung(q.id)
  if d then GameTooltip:AddDoubleLine("Entfernung", QK:EntfernungText(d), 0.6, 0.6, 0.6, 0.85, 0.85, 0.85) end
  QK.Tooltip:Ergaenzen(GameTooltip, q.id, true)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Klick: Fokus mit Navigationspfeil", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Strg+Klick: im Questlog öffnen", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Umschalt+Klick: Link in den Chat", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Rechtsklick: weitere Möglichkeiten", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function NeueZeile()
  local z = CreateFrame("Button", nil, rahmen)
  z:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  z:SetScript("OnClick", ZeileKlick)
  z:SetScript("OnEnter", ZeileTooltip)
  z:SetScript("OnLeave", function() GameTooltip:Hide() end)
  z.fokus = z:CreateTexture(nil, "BACKGROUND")
  z.fokus:SetPoint("TOPLEFT", -6, 1)
  z.fokus:SetPoint("BOTTOMRIGHT", 4, -1)
  z.fokus:SetColorTexture(0.95, 0.77, 0.35, 0.12)
  z.pfeil = z:CreateTexture(nil, "ARTWORK")
  z.pfeil:SetTexture(PFEIL)
  z.pfeil:SetSize(14, 14)
  z.pfeil:SetPoint("TOPLEFT", 0, 0)
  z.rechts = z:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  z.rechts:SetPoint("TOPRIGHT", 0, -1)
  z.rechts:SetJustifyH("RIGHT")
  z.text = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  z.text:SetJustifyH("LEFT")
  z.text:SetWordWrap(false)
  z.balken = CreateFrame("StatusBar", nil, z)
  z.balken:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  z.balken:SetHeight(3)
  z.balken.hg = z.balken:CreateTexture(nil, "BACKGROUND")
  z.balken.hg:SetAllPoints()
  z.balken.hg:SetColorTexture(1, 1, 1, 0.08)
  return z
end

-- art: "titel" | "ziel" | "info"
local function Zeile(art, text, farbe, quest, y)
  benutzt = benutzt + 1
  local z = zeilen[benutzt]
  if not z then
    z = NeueZeile()
    zeilen[benutzt] = z
  end
  local s = SCHRIFTEN[QK:Stil().schrift] or SCHRIFTEN.normal
  local hoehe = art == "titel" and s.hT or s.hZ
  local einzug = art == "ziel" and 18 or (art == "titel" and QK.db.pfeil and 18 or 0)
  z.text:SetFontObject(art == "titel" and s.titel or s.ziel)
  z.text:ClearAllPoints()
  z.text:SetPoint("TOPLEFT", einzug, 0)
  z.text:SetPoint("TOPRIGHT", z.rechts, "TOPLEFT", -4, 0)
  z.text:SetText(text)
  z.text:SetTextColor(unpack(farbe))
  z.rechts:SetText("")
  z.pfeil:Hide()
  z.balken:Hide()
  z.fokus:Hide()
  z.art, z.quest = art, quest
  z:ClearAllPoints()
  z:SetPoint("TOPLEFT", rahmen, "TOPLEFT", 10, y)
  z:SetPoint("TOPRIGHT", rahmen, "TOPRIGHT", -10, y)
  z:SetHeight(hoehe)
  z:Show()
  return z, hoehe
end

---------------------------------------------------------------------------
-- Inhalt
---------------------------------------------------------------------------
local function Stufenfarbe(stufe)
  if GetQuestDifficultyColor and stufe and stufe > 0 then
    local c = GetQuestDifficultyColor(stufe)
    if c then return { c.r, c.g, c.b } end
  end
  return QK.farben.gold
end

local function Sortieren(quests, hier)
  local fokus = QK.Compat:Fokus()
  local art = QK.db.sortierung
  for i, q in ipairs(quests) do
    q.reihenfolge = i
    q.hier = QK:IstHier(q, hier)
    q.entfernung = (art == "entfernung") and QK.Kompass:Entfernung(q.id) or nil
  end
  table.sort(quests, function(a, b)
    if (a.id == fokus) ~= (b.id == fokus) then return a.id == fokus end
    if art ~= "log" then
      if art == "entfernung" and a.entfernung and b.entfernung then
        return a.entfernung < b.entfernung
      end
      if a.hier ~= b.hier then return a.hier end
      if (a.entfernung ~= nil) ~= (b.entfernung ~= nil) then return a.entfernung ~= nil end
      if a.fertig ~= b.fertig then return a.fertig end
    end
    return a.reihenfolge < b.reihenfolge
  end)
end

function T:Aktualisieren()
  if not rahmen then return end
  local db, stil = QK.db, QK:Stil()
  rahmen:SetWidth(db.breite)
  hintergrund:SetAlpha(stil.hintergrund)
  for i = 1, benutzt do zeilen[i]:Hide() end
  benutzt = 0

  local alle = QK.Compat:Questlog()
  local quests = {}
  for _, q in ipairs(alle) do
    if not (q.id and QK.char.ausgeblendet[q.id]) and (db.modus ~= "verfolgt" or q.verfolgt) then
      quests[#quests + 1] = q
    end
  end
  Sortieren(quests, (QK:AktuelleGebiete()))
  aktuelleQuests = quests
  zaehler:SetText(("%d/%d"):format(#alle, QK.Compat:MaxQuests()))

  local y = -24
  local fokus = QK.Compat:Fokus()
  if not eingeklappt then
    if #quests == 0 then
      local _, h = Zeile("info", #alle == 0 and "Keine Quests im Log. Zeit für ein Abenteuer!" or "Nichts zu zeigen.", QK.farben.grau, nil, y)
      y = y - h
    end
    for n = 1, math.min(#quests, db.anzahl) do
      local q = quests[n]
      local titel = q.titel
      if q.stufe and q.stufe > 0 then
        titel = ("[%d%s] %s"):format(q.stufe, (q.gruppe and q.gruppe > 0) and "+" or "", q.titel)
      end
      if not q.hier and q.zone then titel = titel .. " |cff8c8c8c· " .. q.zone .. "|r" end
      local z, h = Zeile("titel", titel, Stufenfarbe(q.stufe), q, y)
      z.pfeilAn = db.pfeil
      if q.id == fokus then z.fokus:Show() end
      y = y - h

      local ziele = q.ziele
      if q.gescheitert then
        local _, hz = Zeile("ziel", "Gescheitert", QK.farben.rot, q, y); y = y - hz
      elseif q.fertig then
        local _, hz = Zeile("ziel", HAKEN .. "Bereit zum Abgeben", QK.farben.gruen, q, y); y = y - hz
      else
        local gezeigt = 0
        for _, ziel in ipairs(ziele) do
          if not (stil.nurNaechstes and (ziel.fertig or gezeigt >= 1)) then
            local text, farbe = ziel.text, QK.farben.hell
            if ziel.fertig then
              text, farbe = HAKEN .. ziel.text, QK.farben.grau
            elseif ziel.ist and ziel.soll and ziel.soll > 0 then
              text = ("%s  |cffbfbfbf%d/%d|r"):format(ziel.text, ziel.ist, ziel.soll)
            end
            local zz, hz = Zeile("ziel", text, farbe, q, y)
            if stil.balken and not ziel.fertig and ziel.ist and ziel.soll and ziel.soll > 1 then
              zz.balken:ClearAllPoints()
              zz.balken:SetPoint("TOPLEFT", zz, "BOTTOMLEFT", 18, -1)
              zz.balken:SetPoint("TOPRIGHT", zz, "BOTTOMRIGHT", 0, -1)
              zz.balken:SetMinMaxValues(0, ziel.soll)
              zz.balken:SetValue(math.min(ziel.ist, ziel.soll))
              zz.balken:SetStatusBarColor(unpack(QK.farben.balken))
              zz.balken:Show()
              hz = hz + 5
            end
            if not ziel.fertig then gezeigt = gezeigt + 1 end
            y = y - hz
          end
        end
      end
      y = y - 5
    end
    if #quests > db.anzahl then
      local _, h = Zeile("info", ("+ %d weitere"):format(#quests - db.anzahl), QK.farben.grau, nil, y)
      y = y - h
    end
  end
  rahmen:SetHeight(-y + 6)
  T:Kompass(true)
end

-- Pfeile und Entfernungen auffrischen (läuft mehrmals pro Sekunde, daher schlank).
function T:Kompass(sofort)
  if not rahmen or not rahmen:IsShown() then return end
  QK.Kompass:Auffrischen(GetTime())
  for i = 1, benutzt do
    local z = zeilen[i]
    if z.art == "titel" and z.quest then
      local winkel, e = QK.Kompass:Richtung(z.quest.id)
      if z.pfeilAn then QK.Kompass:PfeilDrehen(z.pfeil, winkel) end
      local d = QK.Compat:Entfernung(z.quest.id) or e
      z.rechts:SetText(d and QK:EntfernungText(d) or "")
    end
  end
end

local geplant = false
function T:Planen()
  if geplant then return end
  geplant = true
  C_Timer.After(0.15, function()
    geplant = false
    QK:Sicher("Zielliste", T.Aktualisieren, T)
  end)
end

---------------------------------------------------------------------------
-- Rahmen, Lage, Blizzard-Tracker
---------------------------------------------------------------------------
local LAGEN = {
  minimap = { "TOPRIGHT", "TOPRIGHT", -16, -235 },
  rechts  = { "RIGHT", "RIGHT", -16, 40 },
  links   = { "LEFT", "LEFT", 16, 80 },
}

function T:Positionieren()
  local db = QK.db
  rahmen:ClearAllPoints()
  if db.lage == "frei" and db.pos then
    rahmen:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
  else
    local l = LAGEN[db.lage] or LAGEN.minimap
    rahmen:SetPoint(l[1], UIParent, l[2], l[3], l[4])
  end
end

local BLIZZARD = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }
local gehakt = {}
function T:BlizzardTracker()
  if InCombatLockdown() then return end
  for _, name in ipairs(BLIZZARD) do
    local f = _G[name]
    if f then
      if not gehakt[name] then
        gehakt[name] = true
        hooksecurefunc(f, "Show", function(self)
          if QK.db.blizzardAusblenden and not InCombatLockdown() then self:Hide() end
        end)
      end
      if QK.db.blizzardAusblenden then
        f:Hide()
      elseif not f:IsShown() then
        f:Show()
        if name == "QuestWatchFrame" and QuestWatch_Update then QuestWatch_Update() end
      end
    end
  end
end

function T:Ruhe(imKampf)
  rahmen:SetAlpha((imKampf and QK.db.ruhemodus) and QK.db.ruheAlpha or 1)
end

function T:Anwenden()
  if not rahmen then return end
  T:Positionieren()
  rahmen:SetMovable(true)
  rahmen:SetScale(QK.db.skalierung or 1)
  rahmen:SetShown(not QK.db.versteckt)
  T:BlizzardTracker()
  T:Aktualisieren()
end

local function KopfKnopf(icon, tipp, beiKlick)
  local b = CreateFrame("Button", nil, rahmen)
  b:SetSize(16, 16)
  b:SetNormalTexture(icon)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnClick", beiKlick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(tipp[1], unpack(QK.farben.gold))
    GameTooltip:AddLine(tipp[2], 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function T:Start()
  rahmen = CreateFrame("Frame", "QuestkompassListe", UIParent)
  rahmen:SetSize(QK.db.breite, 40)
  rahmen:SetFrameStrata("LOW")
  rahmen:SetClampedToScreen(true)
  hintergrund = rahmen:CreateTexture(nil, "BACKGROUND")
  hintergrund:SetAllPoints()
  hintergrund:SetColorTexture(0.05, 0.05, 0.07, 1)
  local linie = rahmen:CreateTexture(nil, "BORDER")
  linie:SetPoint("TOPLEFT", 8, -20)
  linie:SetPoint("TOPRIGHT", -8, -20)
  linie:SetHeight(1)
  linie:SetColorTexture(0.95, 0.77, 0.35, 0.35)

  kopf = CreateFrame("Button", nil, rahmen)
  kopf:SetPoint("TOPLEFT", 0, 0)
  kopf:SetPoint("TOPRIGHT", -44, 0)
  kopf:SetHeight(20)
  kopf:RegisterForDrag("LeftButton")
  kopf:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  kopf:SetScript("OnDragStart", function()
    if not QK.db.gesperrt then rahmen:StartMoving() end
  end)
  kopf:SetScript("OnDragStop", function()
    rahmen:StopMovingOrSizing()
    local p, _, rp, x, y = rahmen:GetPoint()
    QK.db.lage, QK.db.pos = "frei", { p, rp, x, y }
  end)
  kopf:SetScript("OnClick", function(_, taste)
    if taste == "RightButton" then
      QK.Assistent:Oeffnen(2, true)
    else
      eingeklappt = not eingeklappt
      T:Aktualisieren()
    end
  end)
  kopf:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Questkompass", unpack(QK.farben.gold))
    GameTooltip:AddLine("Klick: ein- oder ausklappen", 0.8, 0.8, 0.8)
    if not QK.db.gesperrt then GameTooltip:AddLine("Ziehen: verschieben", 0.8, 0.8, 0.8) end
    GameTooltip:AddLine("Rechtsklick: Einstellungen", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  kopf:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local titel = kopf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  titel:SetPoint("LEFT", 10, -1)
  titel:SetText("QUESTKOMPASS")
  titel:SetTextColor(unpack(QK.farben.gold))
  zaehler = kopf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zaehler:SetPoint("RIGHT", -4, -1)

  local zahnrad = KopfKnopf("Interface\\Icons\\Trade_Engineering", { "Einstellungen", "Stil, Lage und Extras ändern" },
    function() QK.Assistent:Oeffnen(2, true) end)
  zahnrad:SetPoint("TOPRIGHT", -6, -2)
  local karte = KopfKnopf("Interface\\Icons\\INV_Misc_Map_01", { "Gebietsfortschritt", "Welche Quests es in dieser Zone gibt" },
    function() QK.Gebiet:Umschalten() end)
  karte:SetPoint("RIGHT", zahnrad, "LEFT", -4, 0)

  local takt = 0
  local sortTakt = 0
  rahmen:SetScript("OnUpdate", function(_, el)
    takt, sortTakt = takt + el, sortTakt + el
    if takt > 0.1 then
      takt = 0
      QK:Sicher("Kompass", T.Kompass, T)
    end
    if sortTakt > 3 and QK.db.sortierung == "entfernung" then
      sortTakt = 0
      T:Planen()
    end
  end)

  for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED",
      "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_ENTERING_WORLD", "SUPER_TRACKING_CHANGED" }) do
    QK:Ereignis(e, function() T:Planen() end)
  end
  QK:Ereignis("PLAYER_REGEN_DISABLED", function() T:Ruhe(true) end)
  QK:Ereignis("PLAYER_REGEN_ENABLED", function() T:Ruhe(false); T:BlizzardTracker() end)
  QK:Ereignis("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function() T:BlizzardTracker() end) end)

  T:Anwenden()
end
