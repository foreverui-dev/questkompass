-- Questkompass: Quests automatisch annehmen und abgeben (Umschalt hält das an)
-- und bei der Belohnungswahl die wertvollste Belohnung markieren.
local _, QK = ...
local A = QK:Modul("Automatik")
local L = QK.L

local function Aus() return IsShiftKeyDown() end

---------------------------------------------------------------------------
-- Annehmen und Abgeben
---------------------------------------------------------------------------
local function Gossip()
  local db = QK.db
  if Aus() or not (db.autoAnnehmen or db.autoAbgeben) then return end
  local G = C_GossipInfo
  if G and G.GetActiveQuests then
    if db.autoAbgeben then
      for _, q in ipairs(G.GetActiveQuests() or {}) do
        if q.isComplete and q.questID then G.SelectActiveQuest(q.questID) return end
      end
    end
    if db.autoAnnehmen then
      for _, q in ipairs(G.GetAvailableQuests() or {}) do
        if q.questID and not q.isTrivial then G.SelectAvailableQuest(q.questID) return end
      end
    end
  end
end

local function Begruessung()
  local db = QK.db
  if Aus() then return end
  if db.autoAbgeben and GetNumActiveQuests and GetActiveQuestID and C_QuestLog and C_QuestLog.IsComplete then
    for i = 1, GetNumActiveQuests() do
      local id = GetActiveQuestID(i)
      if id and C_QuestLog.IsComplete(id) then SelectActiveQuest(i) return end
    end
  end
  if db.autoAnnehmen and GetNumAvailableQuests then
    for i = 1, GetNumAvailableQuests() do
      local trivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
      if not trivial then SelectAvailableQuest(i) return end
    end
  end
end

local function Details()
  if not QK.db.autoAnnehmen or Aus() then return end
  if QuestGetAutoAccept and QuestGetAutoAccept() then
    if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
  else
    AcceptQuest()
  end
end

local function Fortschritt()
  if QK.db.autoAbgeben and not Aus() and IsQuestCompletable and IsQuestCompletable() then
    CompleteQuest()
  end
end

---------------------------------------------------------------------------
-- Belohnung
---------------------------------------------------------------------------
local marke

local function Knopf(i)
  return _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
end

local function Markieren(versuch)
  if marke then marke:Hide() end
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  if n < 2 then return true end
  local bester, preis = nil, -1
  for i = 1, n do
    local link = GetQuestItemLink("choice", i)
    if not link then return false end
    local p = select(11, QK.Compat.ItemInfo(link))
    if p == nil then return false end
    local _, _, _, anzahl = GetQuestItemInfo("choice", i)
    p = p * (anzahl or 1)
    if p > preis then bester, preis = i, p end
  end
  local k = bester and preis > 0 and Knopf(bester)
  if not k then return true end
  if not marke then
    marke = CreateFrame("Frame", nil, UIParent)
    marke:SetSize(20, 20)
    marke:SetFrameStrata("DIALOG")
    local t = marke:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    marke:EnableMouse(true)
    marke:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Questkompass", unpack(QK.farben.gold))
      GameTooltip:AddLine(L"Höchster Verkaufswert beim Händler", 1, 1, 1)
      GameTooltip:Show()
    end)
    marke:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  marke:SetParent(k)
  marke:ClearAllPoints()
  marke:SetPoint("TOPLEFT", k, "TOPLEFT", -4, 4)
  marke:Show()
  return true
end

---------------------------------------------------------------------------
-- Belohnungs-Vergleich: Gegenstandsstufe gegen die angelegte Ausrüstung
---------------------------------------------------------------------------
local PLAETZE = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
  INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_WAND = { 18 },
}
local vergleichsMarken = {}

local function Stufe(link)
  if not link then return nil end
  if QK.Compat.ItemStufe then
    local ok, s = pcall(QK.Compat.ItemStufe, link)
    if ok and s then return s end
  end
  local _, _, _, s = QK.Compat.ItemInfo(link)
  return s
end

-- Unterschied zur schwächsten passenden angelegten Ausrüstung, nil wenn nicht vergleichbar
function A:Vergleich(link)
  local _, _, _, stufe, _, _, _, _, platz = QK.Compat.ItemInfo(link)
  stufe = Stufe(link) or stufe
  local plaetze = platz and PLAETZE[platz]
  if not stufe or not plaetze then return nil end
  local schwaechste
  for _, p in ipairs(plaetze) do
    local angelegt = GetInventoryItemLink and GetInventoryItemLink("player", p)
    local s = angelegt and Stufe(angelegt) or 0
    if not schwaechste or s < schwaechste then schwaechste = s end
  end
  return stufe - (schwaechste or 0)
end

local function Vergleichen()
  for _, m in ipairs(vergleichsMarken) do m:Hide() end
  if not QK.db.belohnungsVergleich then return true end
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  local fertig = true
  for i = 1, n do
    local link = GetQuestItemLink("choice", i)
    local k = Knopf(i)
    if not link then fertig = false
    elseif k then
      local d = A:Vergleich(link)
      if d and d > 0 then
        local m = vergleichsMarken[i]
        if not m then
          m = CreateFrame("Frame", nil, UIParent)
          m:SetSize(60, 14)
          m:SetFrameStrata("DIALOG")
          m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          m.text:SetPoint("RIGHT")
          vergleichsMarken[i] = m
        end
        m:SetParent(k)
        m:ClearAllPoints()
        m:SetPoint("BOTTOMRIGHT", k, "BOTTOMRIGHT", -4, 4)
        m.text:SetText((L"besser +%d"):format(d))
        m.text:SetTextColor(unpack(QK.farben.gruen))
        m:Show()
      end
    end
  end
  return fertig
end

local function VergleichPlanen()
  local versuch = 0
  local function los()
    versuch = versuch + 1
    QK:Sicher("Belohnungs-Vergleich", function()
      if not Vergleichen() and versuch < 6 then C_Timer.After(0.3, los) end
    end)
  end
  los()
end

local function Belohnung()
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  if QK.db.autoAbgeben and not Aus() and n <= 1 then
    GetQuestReward(n == 1 and 1 or nil)
    return
  end
  VergleichPlanen()
  if QK.db.belohnungsTipp then
    local versuch = 0
    local function los()
      versuch = versuch + 1
      if not QK:Sicher("Belohnung", function()
        if not Markieren() and versuch < 6 then C_Timer.After(0.3, los) end
      end) then return end
    end
    los()
  end
end

function A:Start()
  QK:Ereignis("GOSSIP_SHOW", Gossip)
  QK:Ereignis("QUEST_GREETING", Begruessung)
  QK:Ereignis("QUEST_DETAIL", function() Details(); VergleichPlanen() end)
  QK:Ereignis("QUEST_PROGRESS", Fortschritt)
  QK:Ereignis("QUEST_COMPLETE", Belohnung)
  QK:Ereignis("QUEST_FINISHED", function()
    if marke then marke:Hide() end
    for _, m in ipairs(vergleichsMarken) do m:Hide() end
  end)
end
