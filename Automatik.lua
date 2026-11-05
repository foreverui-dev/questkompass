-- Questkompass: Quests automatisch annehmen und abgeben (Umschalt hält das an)
-- und bei der Belohnungswahl die wertvollste Belohnung markieren.
local _, QK = ...
local A = QK:Modul("Automatik")

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
    local p = select(11, GetItemInfo(link))
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
      GameTooltip:AddLine("Höchster Verkaufswert beim Händler", 1, 1, 1)
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

local function Belohnung()
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  if QK.db.autoAbgeben and not Aus() and n <= 1 then
    GetQuestReward(n == 1 and 1 or nil)
    return
  end
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
  QK:Ereignis("QUEST_DETAIL", Details)
  QK:Ereignis("QUEST_PROGRESS", Fortschritt)
  QK:Ereignis("QUEST_COMPLETE", Belohnung)
  QK:Ereignis("QUEST_FINISHED", function() if marke then marke:Hide() end end)
end
