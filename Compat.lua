-- Questkompass: eine Schicht über den beiden Quest-APIs.
-- WoW Forever nutzt die moderne API (C_QuestLog.GetInfo usw.), ältere Classic-Clients die alte
-- (GetQuestLogTitle usw.). Alles im Addon fragt nur hier nach.
local _, QK = ...
local C = QK:Modul("Compat")
local L = QK.L

local CQ = C_QuestLog or {}
C.modern = CQ.GetInfo ~= nil and CQ.GetNumQuestLogEntries ~= nil

local function zahl(v) return tonumber(v) end

-- Zieltext ohne Zähler: "Bergpumapelz: 1/10" oder "1/10 Bergpumapelz" -> "Bergpumapelz"
local function zielName(text)
  if not text then return "" end
  local n = text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text:match("^%d+%s*/%s*%d+%s+(.+)$")
  return n or text
end
C.ZielName = zielName

local function zieleModern(questID)
  local liste = {}
  local roh = CQ.GetQuestObjectives and CQ.GetQuestObjectives(questID) or {}
  for _, z in ipairs(roh) do
    local ist, soll = zahl(z.numFulfilled), zahl(z.numRequired)
    if not ist or not soll then
      local a, b = (z.text or ""):match("(%d+)%s*/%s*(%d+)")
      ist, soll = zahl(a), zahl(b)
    end
    liste[#liste + 1] = {
      text = zielName(z.text),
      ist = ist, soll = soll,
      fertig = z.finished and true or false,
      art = z.type,
    }
  end
  return liste
end

local function zieleKlassisch(index)
  local liste = {}
  for j = 1, (GetNumQuestLeaderBoards(index) or 0) do
    local text, art, fertig = GetQuestLogLeaderBoard(j, index)
    if text then
      local a, b = text:match("(%d+)%s*/%s*(%d+)")
      liste[#liste + 1] = {
        text = zielName(text), ist = zahl(a), soll = zahl(b),
        fertig = fertig and true or false, art = art,
      }
    end
  end
  return liste
end

-- Alle Quests im Log: { index, id, titel, stufe, gruppe, zone, gebiet, fertig, gescheitert, verfolgt, ziele, daten }
function C:Questlog()
  local quests, zone = {}, nil
  if C.modern then
    local n = CQ.GetNumQuestLogEntries() or 0
    for i = 1, n do
      local info = CQ.GetInfo(i)
      if info then
        if info.isHeader then
          zone = info.title
        elseif not info.isHidden and info.questID and info.questID > 0 then
          local id = info.questID
          local daten = QK:Quest(id)
          local verfolgt = true
          if CQ.GetQuestWatchType then verfolgt = CQ.GetQuestWatchType(id) ~= nil
          elseif CQ.IsQuestWatched then verfolgt = CQ.IsQuestWatched(id) end
          local ziele = zieleModern(id)
          local fertig = CQ.IsComplete and CQ.IsComplete(id) or false
          quests[#quests + 1] = {
            index = i, id = id, titel = info.title or (L"Quest " .. id),
            stufe = info.level, gruppe = info.suggestedGroup,
            haeufigkeit = info.frequency,
            zone = zone,
            gebiet = (daten and daten.gebiet) or QK:GebietZuName(zone),
            fertig = fertig and true or false,
            gescheitert = CQ.IsFailed and CQ.IsFailed(id) or false,
            verfolgt = verfolgt,
            ziele = ziele,
            daten = daten,
          }
        end
      end
    end
  else
    for i = 1, (GetNumQuestLogEntries() or 0) do
      local titel, stufe, gruppe, istUeberschrift, _, fertig, _, questID = GetQuestLogTitle(i)
      if istUeberschrift then
        zone = titel
      elseif titel then
        local daten = QK:Quest(questID)
        quests[#quests + 1] = {
          index = i, id = questID, titel = titel, stufe = stufe,
          haeufigkeit = select(7, GetQuestLogTitle(i)),
          gruppe = tonumber(gruppe), zone = zone,
          gebiet = (daten and daten.gebiet) or QK:GebietZuName(zone),
          fertig = fertig == 1 or fertig == true,
          gescheitert = fertig == -1,
          verfolgt = IsQuestWatched and IsQuestWatched(i) or false,
          ziele = zieleKlassisch(i),
          daten = daten,
        }
      end
    end
  end
  C.titel = C.titel or {}
  for _, q in ipairs(quests) do
    C.titel[q.id] = q.titel
    if not q.fertig and #q.ziele > 0 then
      local alle = true
      for _, z in ipairs(q.ziele) do if not z.fertig then alle = false break end end
      q.fertig = alle
    end
  end
  return quests
end

-- Restzeit in Sekunden für Quests mit Zeitlimit, sonst nil.
function C:Restzeit(q)
  if CQ.GetTimeAllowed then
    local ok, gesamt, vergangen = pcall(CQ.GetTimeAllowed, q.id)
    if ok and gesamt and gesamt > 0 and vergangen then return math.max(0, gesamt - vergangen) end
  end
  return nil
end

-- Questgegenstand: Link, Symbol, Abklingzeit-Funktion
function C:Gegenstand(q)
  if not GetQuestLogSpecialItemInfo then return nil end
  local index = q.index
  if C.modern and CQ.GetLogIndexForQuestID then index = CQ.GetLogIndexForQuestID(q.id) or index end
  local link, symbol, _, beiFertig = GetQuestLogSpecialItemInfo(index)
  if not link or (q.fertig and not beiFertig) then return nil end
  return link, symbol, index
end

-- Namen der Gruppenmitglieder, die dieselbe Quest haben.
function C:Mitspieler(q)
  local namen = {}
  local n = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or (GetNumPartyMembers and GetNumPartyMembers()) or 0
  for i = 1, math.min(n, 4) do
    local einheit = "party" .. i
    local hat
    if CQ.IsUnitOnQuest then hat = CQ.IsUnitOnQuest(einheit, q.id)
    elseif IsUnitOnQuest then hat = IsUnitOnQuest(q.index, einheit) end
    if hat == true or hat == 1 then namen[#namen + 1] = UnitName(einheit) end
  end
  return namen
end

-- Ist die Quest für den Charakter grau (bringt kaum noch Erfahrung)?
function C:IstGrau(q)
  if not q.stufe or q.stufe <= 0 then return false end
  local spanne = (UnitQuestTrivialLevelRange and UnitQuestTrivialLevelRange("player")) or (GetQuestGreenRange and GetQuestGreenRange()) or 5
  return (UnitLevel("player") or 1) - q.stufe > spanne
end

function C:MaxQuests()
  if CQ.GetMaxNumQuestsCanAccept then return CQ.GetMaxNumQuestsCanAccept() end
  return MAX_QUESTLOG_QUESTS or 20
end

function C:IstErledigt(id)
  if CQ.IsQuestFlaggedCompleted then return CQ.IsQuestFlaggedCompleted(id) end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) end
  return false
end

function C:QuestOeffnen(q)
  if C.modern then
    if QuestMapFrame_OpenToQuestDetails then
      QuestMapFrame_OpenToQuestDetails(q.id)
    else
      if CQ.SetSelectedQuest then CQ.SetSelectedQuest(q.id) end
      if ToggleQuestLog then ToggleQuestLog() end
    end
  else
    if QuestLogFrame and not QuestLogFrame:IsShown() then ShowUIPanel(QuestLogFrame) end
    if QuestLog_SetSelection then QuestLog_SetSelection(q.index) elseif SelectQuestLogEntry then SelectQuestLogEntry(q.index) end
    if QuestLog_Update then QuestLog_Update() end
  end
end

function C:QuestLink(q)
  if not GetQuestLink then return nil end
  return GetQuestLink(C.modern and q.id or q.index)
end

-- Goldbelohnung in Kupfer (ohne die Auswahl im Questlog dauerhaft zu ändern)
function C:Gold(q)
  if not GetQuestLogRewardMoney then return nil end
  if C.modern then
    local ok, geld = pcall(GetQuestLogRewardMoney, q.id)
    return ok and geld or nil
  end
  if not SelectQuestLogEntry then return nil end
  local vorher = GetQuestLogSelection and GetQuestLogSelection()
  SelectQuestLogEntry(q.index)
  local ok, geld = pcall(GetQuestLogRewardMoney)
  if vorher and vorher > 0 then SelectQuestLogEntry(vorher) end
  return ok and geld or nil
end

-- Quest abbrechen (nur nach Bestätigung durch den Spieler aufrufen)
function C:Abbrechen(q)
  if C.modern and CQ.SetAbandonQuest then
    if CQ.SetSelectedQuest then CQ.SetSelectedQuest(q.id) end
    CQ.SetAbandonQuest()
    CQ.AbandonQuest()
  elseif SetAbandonQuest then
    local index = q.index
    for _, x in ipairs(C:Questlog()) do if x.id == q.id then index = x.index end end
    SelectQuestLogEntry(index)
    SetAbandonQuest()
    AbandonQuest()
  end
end

-- Alle erledigten Quest-IDs als Menge { [id] = true }
function C:Erledigte()
  local menge = {}
  if CQ.GetAllCompletedQuestIDs then
    local ok, liste = pcall(CQ.GetAllCompletedQuestIDs)
    if ok and type(liste) == "table" and #liste > 0 then
      for _, id in ipairs(liste) do menge[id] = true end
      return menge
    end
  end
  if GetQuestsCompleted then
    local ok, t = pcall(GetQuestsCompleted)
    if ok and type(t) == "table" and next(t) then
      for id, an in pairs(t) do if an then menge[id] = true end end
      return menge
    end
  end
  for id in pairs(QK.quests or {}) do
    if C:IstErledigt(id) then menge[id] = true end
  end
  return menge
end

function C:Teilen(q)
  if CQ.SetSelectedQuest then CQ.SetSelectedQuest(q.id) elseif SelectQuestLogEntry then SelectQuestLogEntry(q.index) end
  if QuestLogPushQuest then QuestLogPushQuest() end
end

---------------------------------------------------------------------------
-- Fokus (Navigationspfeil des Spiels) und Entfernung
---------------------------------------------------------------------------
function C:FokusSetzen(questID)
  QK.char.fokus = questID
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
    pcall(C_SuperTrack.SetSuperTrackedQuestID, questID or 0)
  end
end

-- Der Fokus folgt auch dem, was der Spieler auf der Weltkarte auswählt.
function C:Fokus()
  if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
    local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    if ok and id and id > 0 then return id end
    if ok then return nil end
  end
  return QK.char and QK.char.fokus
end

-- Entfernung in Yards oder nil
function C:Entfernung(questID)
  if CQ.GetDistanceSqToQuest then
    local ok, d2, gleicherKontinent = pcall(CQ.GetDistanceSqToQuest, questID)
    if ok and d2 and d2 > 0 and gleicherKontinent ~= false then return math.sqrt(d2) end
  end
  return nil
end

---------------------------------------------------------------------------
-- Diagnose: hält fest, welche Funktionen der Client hat.
---------------------------------------------------------------------------
local PRUEFEN = {
  "C_QuestLog.GetInfo", "C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetQuestObjectives",
  "C_QuestLog.IsComplete", "C_QuestLog.GetQuestWatchType", "C_QuestLog.GetDistanceSqToQuest",
  "C_QuestLog.GetQuestsOnMap", "C_QuestLog.IsQuestFlaggedCompleted", "C_SuperTrack.SetSuperTrackedQuestID",
  "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetWorldPosFromMapPos",
  "C_Map.GetMapWorldSize", "C_GossipInfo.GetAvailableQuests", "C_GossipInfo.GetActiveQuests",
  "GetQuestLogTitle", "GetNumQuestLogEntries", "QuestMapFrame_OpenToQuestDetails", "GetPlayerFacing",
  "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame", "Settings.RegisterCanvasLayoutCategory",
  "InterfaceOptions_AddCategory", "MenuUtil.CreateContextMenu",
}

local function vorhanden(pfad)
  local t = _G
  for teil in pfad:gmatch("[^%.]+") do
    if type(t) ~= "table" then return false end
    t = t[teil]
  end
  return t ~= nil
end

function C:Diagnose(ausgeben)
  local version, build, datum, interface = GetBuildInfo()
  local d = {
    version = version, build = build, datum = datum, interface = interface,
    addon = QK.version, modern = C.modern, sprache = GetLocale(), zeit = date and date("%Y-%m-%d %H:%M") or nil,
    api = {},
  }
  for _, pfad in ipairs(PRUEFEN) do d.api[pfad] = vorhanden(pfad) end
  QK.root.diagnose = d
  if ausgeben then
    QK:Meldung(L"Client %s (%s), Interface %s, %s Quest-API, Addon %s",
      tostring(version), tostring(build), tostring(interface), C.modern and "moderne" or "klassische", QK.version)
    local fehlt = {}
    for _, pfad in ipairs(PRUEFEN) do if not d.api[pfad] then fehlt[#fehlt + 1] = pfad end end
    DEFAULT_CHAT_FRAME:AddMessage(L"  Fehlt: " .. (#fehlt > 0 and table.concat(fehlt, ", ") or "nichts"))
  end
end
