-- Questkompass: die Zielliste.
local _, QK = ...
local T = QK:Modul("Tracker")
local L = QK.L

local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t "
local PFEIL = "Interface\\Minimap\\MiniMap-QuestArrow"
local SCHRIFTEN = {
  klein  = { titel = "GameFontNormalSmall", ziel = "GameFontHighlightSmall", hT = 14, hZ = 12 },
  normal = { titel = "GameFontNormal",      ziel = "GameFontHighlightSmall", hT = 16, hZ = 14 },
  gross  = { titel = "GameFontNormal",      ziel = "GameFontHighlight",      hT = 17, hZ = 15 },
}
local TAEGLICH = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily) or LE_QUEST_FREQUENCY_DAILY
local WOECHENTLICH = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly) or LE_QUEST_FREQUENCY_WEEKLY
local NEU_DAUER = 120

local rahmen, kopf, kopfTitel, zaehler, hintergrund, linie
local zeilen, benutzt = {}, 0
local eingeklappt = false
local versatz = 0           -- Mausrad: so viele Einträge sind nach oben weggeblättert
local sichtbar = {}         -- angezeigte Quests in Reihenfolge (für Tastenkürzel)
local menue
local knoepfe = {}          -- Questgegenstände (sichere Knöpfe)
local neu = {}              -- questID -> Zeitpunkt der Annahme
local logVoll = false
local signatur, sichtbarBis = nil, 0   -- Mouseover-Modus: kurz zeigen, wenn sich etwas ändert
local imKampf = false
T.neu = neu

---------------------------------------------------------------------------
-- Kontextmenü
---------------------------------------------------------------------------
local function MenueErstellen()
  menue = CreateFrame("Frame", "QuestkompassMenue", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  menue:SetFrameStrata("DIALOG")
  menue:SetClampedToScreen(true)
  menue:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  menue:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
  menue:SetBackdropBorderColor(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.4)
  menue.knoepfe = {}
  menue:Hide()
  tinsert(UISpecialFrames, "QuestkompassMenue")
  menue:SetScript("OnShow", function(self) self.zeit, self.weg = 0, 0 end)
  menue:SetScript("OnUpdate", function(self, el)
    self.zeit = self.zeit + el
    if self.zeit > 0.5 and not self:IsMouseOver() then
      self.weg = self.weg + el
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
      hl:SetColorTexture(1, 1, 1, 0.08)
      menue.knoepfe[i] = k
    end
    k:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 18)
    k:SetPoint("RIGHT", menue, "RIGHT", -4, 0)
    k.text:SetText(e[1])
    k:SetScript("OnClick", function() menue:Hide(); QK:Sicher("Menü", e[2]) end)
    k:Show()
    breite = math.max(breite, (k.text:GetStringWidth() or 100) + 28)
  end
  menue:SetSize(breite, #eintraege * 18 + 8)
  menue:ClearAllPoints()
  if anker:GetLeft() and anker:GetLeft() < 220 then
    menue:SetPoint("TOPLEFT", anker, "TOPRIGHT", 4, 0)
  else
    menue:SetPoint("TOPRIGHT", anker, "TOPLEFT", -4, 0)
  end
  menue:SetScale(QK:Groesse())
  menue:Show()
end

---------------------------------------------------------------------------
-- Fokus
---------------------------------------------------------------------------
function T:FokusNaechste(still)
  local bester, abstand, ersatz
  for _, q in ipairs(QK.Compat:Questlog()) do
    if not QK.char.ausgeblendet[q.id] then
      local d = QK.Kompass:Entfernung(q.id)
      if d and not q.fertig and (not abstand or d < abstand) then bester, abstand = q, d end
      if d and not ersatz then ersatz = q end
    end
  end
  bester = bester or ersatz
  if bester then
    QK.Compat:FokusSetzen(bester.id)
    if not still then QK:Meldung(L"Fokus: %s", bester.titel) end
  elseif not still then
    QK:Meldung(L"keine Quest mit Ziel auf dieser Karte.")
  end
  T:Planen()
end

function T:FokusWeiter(richtung)
  if #sichtbar == 0 then return end
  local jetzt, pos = QK.Compat:Fokus(), 0
  for i, q in ipairs(sichtbar) do if q.id == jetzt then pos = i end end
  if pos == 0 and richtung == -1 then pos = 1 end
  local q = sichtbar[((pos - 1 + (richtung or 1)) % #sichtbar) + 1]
  QK.Compat:FokusSetzen(q.id)
  if QK.db.vorlesen then QK:Sprechen(q.titel) end
  T:Planen()
end

function T:Sichtbar() return sichtbar end

---------------------------------------------------------------------------
-- Zeilen
---------------------------------------------------------------------------
local function LinkInChat(q)
  local link = QK.Compat:QuestLink(q)
  if link and ChatEdit_InsertLink then
    if not ChatEdit_InsertLink(link) and ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
  end
end

local function QuestMenue(zeile, q)
  local fokus = QK.Compat:Fokus() == q.id
  local e = {
    { fokus and L"Fokus aufheben" or L"Als Fokus setzen (Navigationspfeil)", function()
      QK.Compat:FokusSetzen(not fokus and q.id or nil); T:Aktualisieren() end },
    { L"Im Questlog öffnen", function() QK.Compat:QuestOeffnen(q) end },
    { L"Link in den Chat", function() LinkInChat(q) end },
  }
  if (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) then
    e[#e + 1] = { L"Mit der Gruppe teilen", function() QK.Compat:Teilen(q) end }
  end
  if q.zone then
    e[#e + 1] = { L"Gebietsfortschritt: " .. q.zone, function() QK.Gebiet:Zeigen(q.zone) end }
  end
  for _, extra in ipairs(QK:Rufe("menue", q)) do
    for _, eintrag in ipairs(extra) do e[#e + 1] = eintrag end
  end
  e[#e + 1] = { L"Hier ausblenden", function()
    QK.char.ausgeblendet[q.id] = true
    QK:Meldung(L"„%s“ ausgeblendet. /qk einblenden holt sie zurück.", q.titel)
    T:Aktualisieren()
  end }
  MenueZeigen(zeile, e)
end

local function ZeileKlick(self, taste)
  if self.art == "gruppe" then
    QK.char.zugeklappt[self.gruppe] = not QK.char.zugeklappt[self.gruppe] or nil
    T:Aktualisieren()
    return
  elseif self.art == "mehr" then
    versatz = math.max(0, versatz + (self.richtung or 0) * QK.db.anzahl)
    T:Aktualisieren()
    return
  end
  local q = self.quest
  if not q then return end
  if taste == "RightButton" then
    QuestMenue(self, q)
  elseif IsShiftKeyDown() then
    LinkInChat(q)
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
  if self.art == "ep" then
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(self.titelTipp or L"Bereit zum Abgeben", unpack(QK.farben.gold))
    GameTooltip:AddLine(self.tipp or "", 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
    return
  end
  if not q then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(q.titel, unpack(QK.farben.gold))
  if q.zone then GameTooltip:AddLine(q.zone, 0.8, 0.8, 0.8) end
  local d = QK.Kompass:Entfernung(q.id)
  if d then
    GameTooltip:AddDoubleLine(L"Entfernung", QK:EntfernungText(d), 0.6, 0.6, 0.6, 0.85, 0.85, 0.85)
    local tempo = GetUnitSpeed and GetUnitSpeed("player")
    if tempo and tempo > 0 then
      GameTooltip:AddDoubleLine(L"Ankunft in etwa", QK:DauerText(d / tempo), 0.6, 0.6, 0.6, 0.85, 0.85, 0.85)
    end
  end
  if q.mitspieler and #q.mitspieler > 0 then
    GameTooltip:AddDoubleLine(L"Auch dabei", table.concat(q.mitspieler, ", "), 0.6, 0.6, 0.6, 0.5, 0.75, 1)
  end
  QK.Tooltip:Ergaenzen(GameTooltip, q.id, true)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L"Klick: Fokus mit Navigationspfeil", 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L"Strg+Klick: im Questlog öffnen", 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L"Umschalt+Klick: Link in den Chat", 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L"Rechtsklick: weitere Möglichkeiten", 0.6, 0.6, 0.6)
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

-- art: titel | ziel | info | gruppe | ep | mehr
local function Zeile(art, text, farbe, quest, y)
  benutzt = benutzt + 1
  local z = zeilen[benutzt]
  if not z then
    z = NeueZeile()
    zeilen[benutzt] = z
  end
  local s = SCHRIFTEN[QK:Stil().schrift] or SCHRIFTEN.normal
  local hoehe = art == "titel" and s.hT or s.hZ
  local einzug = 0
  if art == "ziel" then einzug = 18 elseif art == "titel" and QK.db.pfeil then einzug = 18 end
  local schrift = s.ziel
  if art == "titel" then schrift = s.titel elseif art == "gruppe" or art == "mehr" or art == "ep" then schrift = "GameFontDisableSmall" end
  z.text:SetFontObject(schrift)
  z.text:ClearAllPoints()
  z.text:SetPoint("TOPLEFT", einzug, 0)
  z.text:SetPoint("TOPRIGHT", z.rechts, "TOPLEFT", -4, 0)
  z.text:SetText(text)
  z.text:SetTextColor(unpack(farbe))
  z.rechts:SetText("")
  z.pfeil:Hide()
  z.balken:Hide()
  z.fokus:Hide()
  z.art, z.quest, z.zeitEnde, z.gruppe, z.tipp, z.richtung, z.pfeilAn, z.titelTipp = art, quest, nil, nil, nil, nil, nil, nil
  z:ClearAllPoints()
  z:SetPoint("TOPLEFT", rahmen, "TOPLEFT", 10, y)
  z:SetPoint("TOPRIGHT", rahmen, "TOPRIGHT", -10, y)
  z:SetHeight(hoehe)
  z:Show()
  return z, hoehe
end

local function Balken(z, wert, max, farbe)
  z.balken:ClearAllPoints()
  z.balken:SetPoint("TOPLEFT", z, "BOTTOMLEFT", z.art == "ziel" and 18 or 0, -1)
  z.balken:SetPoint("TOPRIGHT", z, "BOTTOMRIGHT", 0, -1)
  z.balken:SetMinMaxValues(0, max)
  z.balken:SetValue(math.min(wert, max))
  z.balken:SetStatusBarColor(unpack(farbe or QK.farben.balken))
  z.balken:Show()
  return 5
end

---------------------------------------------------------------------------
-- Aufbereiten und Sortieren
---------------------------------------------------------------------------
local function Stufenfarbe(q)
  if q.grau then return QK.farben.grau end
  if GetQuestDifficultyColor and q.stufe and q.stufe > 0 then
    local c = GetQuestDifficultyColor(q.stufe)
    if c then return { c.r, c.g, c.b } end
  end
  return QK.farben.gold
end

local function Marken(q)
  local m = {}
  local typ = q.daten and q.daten.typ
  if typ then m[#m + 1] = "|cffd98c40" .. (QK:TypName(typ) or "") .. "|r" end
  if TAEGLICH and q.haeufigkeit == TAEGLICH then m[#m + 1] = L"|cff6fb6ffTäglich|r"
  elseif WOECHENTLICH and q.haeufigkeit == WOECHENTLICH then m[#m + 1] = L"|cff6fb6ffWöchentlich|r" end
  if q.mitspieler and #q.mitspieler > 0 then m[#m + 1] = "|cff7fbfff[" .. #q.mitspieler .. "]|r" end
  if q.neu then m[#m + 1] = QK.gold .. "Neu|r" end
  if q.route then m[#m + 1] = QK.gold .. "#" .. q.route .. "|r" end
  for _, extra in ipairs(QK:Rufe("marke", q)) do m[#m + 1] = extra end
  return #m > 0 and (" " .. table.concat(m, " ")) or ""
end

local function Sortieren(quests, hier)
  local fokus = QK.Compat:Fokus()
  local art = QK.db.sortierung
  local jetzt = GetTime()
  for i, q in ipairs(quests) do
    q.reihenfolge = i
    q.hier = QK:IstHier(q, hier)
    q.entfernung = QK.Kompass:Entfernung(q.id)
    q.grau = QK.Compat:IstGrau(q)
    q.neu = QK.db.neuMarkierung and neu[q.id] and jetzt - neu[q.id] < NEU_DAUER or false
    q.mitspieler = QK.db.mitspieler and QK.Compat:Mitspieler(q) or nil
    q.route = QK.Navigation and QK.Navigation:Station(q.id) or nil
  end
  table.sort(quests, function(a, b)
    if (a.id == fokus) ~= (b.id == fokus) then return a.id == fokus end
    if (a.route ~= nil) ~= (b.route ~= nil) then return a.route ~= nil end
    if a.route and b.route then return a.route < b.route end
    if art ~= "log" then
      if a.grau ~= b.grau then return b.grau end
      if art == "entfernung" and a.entfernung and b.entfernung then return a.entfernung < b.entfernung end
      if a.hier ~= b.hier then return a.hier end
      if art == "entfernung" and (a.entfernung ~= nil) ~= (b.entfernung ~= nil) then return a.entfernung ~= nil end
      if a.fertig ~= b.fertig then return a.fertig end
    end
    return a.reihenfolge < b.reihenfolge
  end)
end

-- Bildet aus den sortierten Quests Einträge, wahlweise mit Zonenüberschriften.
local function Eintraege(quests)
  local liste = {}
  if not QK.db.gruppen then
    for _, q in ipairs(quests) do liste[#liste + 1] = { quest = q } end
    return liste
  end
  local gruppen, reihenfolge = {}, {}
  for _, q in ipairs(quests) do
    local g = q.zone or L"Sonstige"
    if not gruppen[g] then gruppen[g] = {}; reihenfolge[#reihenfolge + 1] = g end
    table.insert(gruppen[g], q)
  end
  for _, g in ipairs(reihenfolge) do
    liste[#liste + 1] = { gruppe = g, anzahl = #gruppen[g] }
    if not QK.char.zugeklappt[g] then
      for _, q in ipairs(gruppen[g]) do liste[#liste + 1] = { quest = q } end
    end
  end
  return liste
end

---------------------------------------------------------------------------
-- Zeichnen
---------------------------------------------------------------------------
-- Erfahrungs- und Goldvorschau: was die fertigen Quests zusammen bringen.
local function EPVorschau(quests, y)
  local db = QK.db
  if not db.epVorschau and not db.goldVorschau then return y end
  local maxStufe = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or MAX_PLAYER_LEVEL or 60
  local mitEP = db.epVorschau and (UnitLevel("player") or 1) < maxStufe
  local summe, anzahl, gold = 0, 0, 0
  for _, q in ipairs(quests) do
    if q.fertig then
      if q.daten and q.daten.ep then summe = summe + q.daten.ep end
      if db.goldVorschau then gold = gold + (QK.Compat:Gold(q) or 0) end
      anzahl = anzahl + 1
    end
  end
  if not mitEP then summe = 0 end
  if summe <= 0 and gold <= 0 then return y end
  local ist, max = UnitXP("player") or 0, UnitXPMax("player") or 1
  local teile = {}
  if summe > 0 then
    teile[#teile + 1] = (L"%s bereit · %d %% der Stufe"):format(QK:EPText(summe), math.floor(summe / max * 100 + 0.5))
    if ist + summe >= max then teile[#teile + 1] = QK.gold .. L"Stufenaufstieg!" .. "|r" end
  end
  if gold > 0 then teile[#teile + 1] = QK:GeldText(gold) end
  local z, h = Zeile("ep", table.concat(teile, " · "), QK.farben.hell, nil, y)
  local werte = {}
  if summe > 0 then werte[#werte + 1] = QK:EPText(summe) end
  if gold > 0 then werte[#werte + 1] = QK:GeldText(gold) end
  z.tipp = (L"%d fertige Quests bringen zusammen %s."):format(anzahl, table.concat(werte, L" und "))
  if summe > 0 then
    z.tipp = z.tipp .. "\n" .. (L"Aktuell: %s von %s EP."):format(BreakUpLargeNumbers and BreakUpLargeNumbers(ist) or ist, BreakUpLargeNumbers and BreakUpLargeNumbers(max) or max)
    h = h + Balken(z, ist + summe, max, { 0.55, 0.45, 0.9 })
  end
  return y - h - 4
end

-- Tägliche Quests: wie viele offen sind und wann der Tag zurückgesetzt wird.
function QK:BisZuruecksetzen()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    local ok, s = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
    if ok and s then return s end
  end
  if GetQuestResetTime then
    local ok, s = pcall(GetQuestResetTime)
    if ok and s and s > 0 then return s end
  end
end

local function Taeglich(quests, y)
  if not QK.db.taeglichZeile or not TAEGLICH then return y end
  local offen, fertig = 0, 0
  for _, q in ipairs(quests) do
    if q.haeufigkeit == TAEGLICH then
      if q.fertig then fertig = fertig + 1 else offen = offen + 1 end
    end
  end
  if offen + fertig == 0 then return y end
  local text = (L"Tägliche: %d offen, %d fertig"):format(offen, fertig)
  local rest = QK:BisZuruecksetzen()
  if rest then text = text .. " · " .. (L"neu in %s"):format(QK:DauerText(rest)) end
  local z, h = Zeile("ep", text, QK.farben.hell, nil, y)
  z.tipp = L"Tägliche Quests im Log. Nach dem Zurücksetzen lassen sie sich erneut annehmen."
  z.titelTipp = L"Tägliche Quests"
  return y - h - 4
end

function T:Aktualisieren()
  if not rahmen then return end
  local db, stil = QK.db, QK:Stil()
  rahmen:SetWidth(db.breite)
  hintergrund:SetAlpha(QK:Deckkraft(stil.hintergrund))
  linie:SetColorTexture(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.35)
  kopfTitel:SetTextColor(unpack(QK.farben.gold))
  for i = 1, benutzt do zeilen[i]:Hide() end
  benutzt = 0

  local alle = QK.Compat:Questlog()
  local quests = {}
  for _, q in ipairs(alle) do
    if not (q.id and QK.char.ausgeblendet[q.id]) and (db.modus ~= "verfolgt" or q.verfolgt)
      and not (db.graueAusblenden and QK.Compat:IstGrau(q)) then
      quests[#quests + 1] = q
    end
  end
  local hier = QK:AktuelleGebiete()
  -- Instanz-Modus: im Dungeon nur Quests dieses Dungeons (wenn es welche gibt)
  local modusText
  if db.instanzModus and IsInInstance then
    local drin, art = IsInInstance()
    if drin and (art == "party" or art == "raid") then
      local passend = {}
      for _, q in ipairs(quests) do if QK:IstHier(q, hier) then passend[#passend + 1] = q end end
      if #passend > 0 then quests = passend; modusText = L"Dungeon" end
    end
  end
  -- Im Kampf nur die Fokus-Quest
  local fokusJetzt = QK.Compat:Fokus()
  if db.kampfNurFokus and imKampf and fokusJetzt then
    for _, q in ipairs(quests) do
      if q.id == fokusJetzt then quests = { q }; modusText = L"Kampf" break end
    end
  end
  Sortieren(quests, hier)

  -- Auto-Fokus: ohne gültigen Fokus die nächstgelegene Quest nehmen.
  if db.autoFokus then
    local f, gueltig = QK.Compat:Fokus(), false
    for _, q in ipairs(alle) do if q.id == f then gueltig = true end end
    if not gueltig then
      for _, q in ipairs(quests) do
        if q.entfernung and not q.fertig then QK.Compat:FokusSetzen(q.id); Sortieren(quests, hier) break end
      end
    end
  end

  -- Zähler und Warnung bei vollem Questlog
  local max = QK.Compat:MaxQuests()
  zaehler:SetText((modusText and (modusText .. " · ") or "") .. ("%d/%d"):format(#alle, max))
  local knapp = #alle >= max - 2
  if #alle >= max then zaehler:SetTextColor(unpack(QK.farben.rot))
  elseif knapp then zaehler:SetTextColor(1, 0.6, 0.2)
  else zaehler:SetTextColor(0.5, 0.5, 0.5) end
  if db.logWarnung and knapp and not logVoll and QK.Meldungen then
    QK.Meldungen:Zeigen("QUESTLOG FAST VOLL", (L"%d von %d Plätzen belegt"):format(#alle, max))
  end
  logVoll = knapp

  local y = -24
  sichtbar = {}
  local fokus = QK.Compat:Fokus()
  if not eingeklappt then
    y = EPVorschau(alle, y)
    y = Taeglich(alle, y)
    if #quests == 0 then
      local _, h = Zeile("info", #alle == 0 and L"Keine Quests im Log. Zeit für ein Abenteuer!" or L"Nichts zu zeigen.", QK.farben.grau, nil, y)
      y = y - h
    end
    local eintraege = Eintraege(quests)
    local questsGesamt = 0
    for _, e in ipairs(eintraege) do if e.quest then questsGesamt = questsGesamt + 1 end end
    versatz = math.max(0, math.min(versatz, math.max(0, questsGesamt - db.anzahl)))
    rahmen:EnableMouseWheel(questsGesamt > db.anzahl)

    if versatz > 0 then
      local z, h = Zeile("mehr", ("|TInterface\\Buttons\\Arrow-Up-Up:12:12:0:-2|t %d weiter oben"):format(versatz), QK.farben.grau, nil, y)
      z.richtung = -1
      y = y - h
    end
    local questNr, gezeigt = 0, 0
    for _, e in ipairs(eintraege) do
      if e.gruppe then
        local zu = QK.char.zugeklappt[e.gruppe]
        local z, h = Zeile("gruppe", (zu and "+ " or "– ") .. e.gruppe:upper(), QK.farben.gold, nil, y)
        z.text:SetTextColor(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.8)
        z.rechts:SetText(e.anzahl)
        z.gruppe = e.gruppe
        y = y - h - 1
      else
        questNr = questNr + 1
        local q = e.quest
        if questNr > versatz and gezeigt < db.anzahl then
          gezeigt = gezeigt + 1
          sichtbar[#sichtbar + 1] = q
          local titel = q.titel
          if q.stufe and q.stufe > 0 then
            titel = ("[%d%s] %s"):format(q.stufe, (q.gruppe and q.gruppe > 0) and "+" or "", q.titel)
          end
          if not db.gruppen and not q.hier and q.zone and not q.entfernung then
            titel = titel .. " |cff8c8c8c· " .. q.zone .. "|r"
          end
          titel = titel .. Marken(q)
          local z, h = Zeile("titel", titel, Stufenfarbe(q), q, y)
          z.pfeilAn = db.pfeil
          if q.id == fokus then
            z.fokus:SetColorTexture(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.13)
            z.fokus:Show()
          end
          y = y - h

          local rest = QK.Compat:Restzeit(q)
          if rest and not q.fertig then
            local zz, hz = Zeile("ziel", "", QK.farben.rot, q, y)
            zz.zeitEnde = GetTime() + rest
            y = y - hz
          end
          if q.gescheitert then
            local _, hz = Zeile("ziel", L"Gescheitert", QK.farben.rot, q, y); y = y - hz
          elseif q.fertig then
            local _, hz = Zeile("ziel", HAKEN .. L"Bereit zum Abgeben", QK.farben.gruen, q, y); y = y - hz
          else
            local zahl = 0
            for _, ziel in ipairs(q.ziele) do
              if not (stil.nurNaechstes and (ziel.fertig or zahl >= 1)) then
                local text, farbe = ziel.text, QK.farben.hell
                if ziel.fertig then
                  text, farbe = HAKEN .. ziel.text, QK.farben.grau
                elseif ziel.ist and ziel.soll and ziel.soll > 0 then
                  text = ("%s  |cffbfbfbf%d/%d|r"):format(ziel.text, ziel.ist, ziel.soll)
                end
                local zz, hz = Zeile("ziel", text, farbe, q, y)
                if stil.balken and not ziel.fertig and ziel.ist and ziel.soll and ziel.soll > 1 then
                  hz = hz + Balken(zz, ziel.ist, ziel.soll)
                end
                if not ziel.fertig then zahl = zahl + 1 end
                y = y - hz
              end
            end
          end
          for _, extra in ipairs(QK:Rufe("zeilen", q)) do
            local zz, hz = Zeile("ziel", extra[1], extra[2] or QK.farben.grau, q, y)
            zz.tipp = extra[3]
            y = y - hz
          end
          y = y - 5
        end
      end
    end
    if questsGesamt > versatz + gezeigt then
      local z, h = Zeile("mehr", ("|TInterface\\Buttons\\Arrow-Down-Up:12:12:0:2|t %d weitere"):format(questsGesamt - versatz - gezeigt), QK.farben.grau, nil, y)
      z.richtung = 1
      y = y - h
    end
  end
  rahmen:SetHeight(-y + 6)
  -- Mouseover-Modus: bei Änderungen kurz einblenden
  local teile = {}
  for i = 1, benutzt do teile[i] = zeilen[i].text:GetText() or "" end
  local neueSignatur = table.concat(teile, "\1")
  if signatur and neueSignatur ~= signatur then sichtbarBis = GetTime() + (db.wenigerBewegung and 10 or 5) end
  signatur = neueSignatur
  T:Kompass()
  T:Gegenstaende()
  if QK.Pfeil then QK.Pfeil:Aktualisieren() end
end

---------------------------------------------------------------------------
-- Pfeile, Entfernungen, Zeitlimits (mehrmals pro Sekunde)
---------------------------------------------------------------------------
function QK:DauerText(sek)
  sek = math.max(0, math.floor(sek + 0.5))
  if sek >= 3600 then return ("%d:%02d Std."):format(math.floor(sek / 3600), math.floor((sek % 3600) / 60)) end
  return ("%d:%02d"):format(math.floor(sek / 60), sek % 60)
end

function T:Kompass()
  if not rahmen or not rahmen:IsShown() then return end
  QK.Kompass:Auffrischen(GetTime())
  local jetzt = GetTime()
  for i = 1, benutzt do
    local z = zeilen[i]
    if z.art == "titel" and z.quest then
      local winkel, e = QK.Kompass:Richtung(z.quest.id)
      if z.pfeilAn then QK.Kompass:PfeilDrehen(z.pfeil, winkel) end
      local d = QK.Compat:Entfernung(z.quest.id) or e
      z.rechts:SetText(d and QK:EntfernungText(d) or "")
    elseif z.zeitEnde then
      z.text:SetText(L"Zeit: " .. QK:DauerText(z.zeitEnde - jetzt))
    end
  end
end

---------------------------------------------------------------------------
-- Questgegenstände: sichere Knöpfe, nur außerhalb des Kampfes verändern
---------------------------------------------------------------------------
local function Knopf(i)
  local b = knoepfe[i]
  if b then return b end
  b = CreateFrame("Button", "QuestkompassGegenstand" .. i, UIParent, "SecureActionButtonTemplate")
  b:SetSize(24, 24)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetFrameStrata("MEDIUM")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints()
  b:SetScript("OnEnter", function(self)
    if self.link then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetHyperlink(self.link)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:Hide()
  knoepfe[i] = b
  return b
end

local gegenstaendeOffen = false
function T:Gegenstaende()
  if InCombatLockdown() then gegenstaendeOffen = true return end
  gegenstaendeOffen = false
  local n = 0
  if QK.db.questItems and rahmen:IsShown() and not eingeklappt then
    local skala = rahmen:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local links = (rahmen:GetLeft() or 0) * skala
    local rechtsSeite = links < 40
    for i = 1, benutzt do
      local z = zeilen[i]
      if z:IsShown() and z.art == "titel" and z.quest and n < 8 then
        local link, symbol, index = QK.Compat:Gegenstand(z.quest)
        local oben = z:GetTop()
        if link and oben then
          n = n + 1
          local b = Knopf(n)
          b.link, b.index = link, index
          b:SetAttribute("type", "item")
          b:SetAttribute("item", link:match("item:%d+") or link)
          b.icon:SetTexture(symbol)
          b:ClearAllPoints()
          if rechtsSeite then
            b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (rahmen:GetRight() or 0) * skala + 4, oben * skala + 2)
          else
            b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", links - 4, oben * skala + 2)
          end
          if GetQuestLogSpecialItemCooldown then
            local start, dauer, an = GetQuestLogSpecialItemCooldown(index)
            if start and dauer and dauer > 0 and an ~= 0 then b.cd:SetCooldown(start, dauer) else b.cd:Clear() end
          end
          b:Show()
        end
      end
    end
  end
  for i = n + 1, #knoepfe do knoepfe[i]:Hide() end
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

-- Deckkraft der Liste aus Ruhemodus (Kampf) und Mouseover-Modus
function T:Ruhe(kampf)
  if kampf ~= nil then imKampf = kampf end
  local alpha = (imKampf and QK.db.ruhemodus) and QK.db.ruheAlpha or 1
  if QK.db.mouseover and not rahmen:IsMouseOver() and GetTime() > sichtbarBis
    and not (menue and menue:IsShown()) then
    alpha = 0
  end
  if rahmen:GetAlpha() ~= alpha then rahmen:SetAlpha(alpha) end
end

function T:Anwenden()
  if not rahmen then return end
  T:Positionieren()
  rahmen:SetMovable(true)
  rahmen:SetScale(QK.db.skalierung or 1)
  if not InCombatLockdown() then rahmen:SetShown(not QK.db.versteckt) end
  T:BlizzardTracker()
  T:Aktualisieren()
end

function T:Umschalten()
  if InCombatLockdown() then return end
  QK.db.versteckt = not QK.db.versteckt
  QK:Anwenden()
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
  linie = rahmen:CreateTexture(nil, "BORDER")
  linie:SetPoint("TOPLEFT", 8, -20)
  linie:SetPoint("TOPRIGHT", -8, -20)
  linie:SetHeight(1)

  rahmen:SetScript("OnMouseWheel", function(_, delta)
    versatz = math.max(0, versatz - delta)
    T:Aktualisieren()
  end)

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
    T:Gegenstaende()
  end)
  kopf:SetScript("OnClick", function(_, taste)
    if taste == "RightButton" then
      QK.Assistent:Oeffnen(QK.SEITE_EINSTELLUNGEN, true)
    else
      eingeklappt = not eingeklappt
      T:Aktualisieren()
    end
  end)
  kopf:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Questkompass", unpack(QK.farben.gold))
    GameTooltip:AddLine(L"Klick: ein- oder ausklappen", 0.8, 0.8, 0.8)
    if not QK.db.gesperrt then GameTooltip:AddLine(L"Ziehen: verschieben", 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(L"Rechtsklick: Einstellungen", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Mausrad über der Liste: blättern", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  kopf:SetScript("OnLeave", function() GameTooltip:Hide() end)

  kopfTitel = kopf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  kopfTitel:SetPoint("LEFT", 10, -1)
  kopfTitel:SetText("QUESTKOMPASS")
  zaehler = kopf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zaehler:SetPoint("RIGHT", -4, -1)

  local zahnrad = KopfKnopf("Interface\\Icons\\Trade_Engineering", { L"Einstellungen", L"Stil, Lage und Extras ändern" },
    function() QK.Assistent:Oeffnen(QK.SEITE_EINSTELLUNGEN, true) end)
  zahnrad:SetPoint("TOPRIGHT", -6, -2)
  local karte = KopfKnopf("Interface\\Icons\\INV_Misc_Map_01", { L"Questbuch", L"Gebiet, Welt, Suche und Tagebuch" },
    function() QK.Gebiet:Umschalten() end)
  karte:SetPoint("RIGHT", zahnrad, "LEFT", -4, 0)

  local takt, sortTakt = 0, 0
  rahmen:SetScript("OnUpdate", function(_, el)
    takt, sortTakt = takt + el, sortTakt + el
    if takt > 0.1 then
      takt = 0
      QK:Sicher("Kompass", T.Kompass, T)
      T:Ruhe()
    end
    if sortTakt > 3 then
      sortTakt = 0
      if QK.db.sortierung == "entfernung" or QK.db.autoFokus or next(neu) then T:Planen() end
    end
  end)

  for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED",
      "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_ENTERING_WORLD", "SUPER_TRACKING_CHANGED",
      "GROUP_ROSTER_UPDATE", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "BAG_UPDATE_COOLDOWN" }) do
    QK:Ereignis(e, function() T:Planen() end)
  end
  QK:Ereignis("QUEST_ACCEPTED", function(a, b)
    local id = (b and b > 0 and b) or a
    if id then neu[id] = GetTime() end
    T:Planen()
  end)
  QK:Ereignis("PLAYER_REGEN_DISABLED", function() T:Ruhe(true); if QK.db.kampfNurFokus then T:Planen() end end)
  QK:Ereignis("PLAYER_REGEN_ENABLED", function()
    T:Ruhe(false)
    if QK.db.kampfNurFokus then T:Planen() end
    T:BlizzardTracker()
    if gegenstaendeOffen then T:Gegenstaende() end
  end)
  QK:Ereignis("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function() T:BlizzardTracker() end) end)

  T:Anwenden()
end
