-- Questkompass: kleinere Helfer ab 0.6. Anheften, Fokusmodus, Questziele in Tooltips,
-- Tagesziel, Merkliste, automatisch teilen, Zeitlimit-Warnung und Einstellungen teilen.
local _, QK = ...
local X = QK:Modul("Extras")
local L = QK.L

local SYMBOL = "|TInterface\\GossipFrame\\ActiveQuestIcon:0:0:0:0|t "

---------------------------------------------------------------------------
-- Anheften, Fokusmodus, Merkliste, Tagesziel
---------------------------------------------------------------------------
function X:Anheften(questID)
  local a = QK.char.angeheftet
  a[questID] = not a[questID] or nil
  if QK.Tracker then QK.Tracker:Planen() end
  return a[questID] and true or false
end

function X:Fokusmodus()
  QK.db.fokusModus = not QK.db.fokusModus
  if QK.db.fokusModus and not QK.Compat:Fokus() and QK.Navigation then QK.Navigation:WasJetzt() end
  QK:Meldung(QK.db.fokusModus and L"Fokusmodus an: die Liste zeigt nur noch die Fokus-Quest." or L"Fokusmodus aus.")
  QK:Anwenden()
end

function X:Merken(questID)
  local m = QK.char.merkliste
  m[questID] = not m[questID] and time() or nil
  return m[questID] ~= nil
end
function X:Gemerkt(questID) return QK.char and QK.char.merkliste[questID] ~= nil end

function X:Heute()
  local heute, n = date("%Y-%m-%d"), 0
  for i = #QK.char.tagebuch, 1, -1 do
    local e = QK.char.tagebuch[i]
    if date("%Y-%m-%d", e.zeit) ~= heute then break end
    n = n + 1
  end
  return n
end

---------------------------------------------------------------------------
-- Questziele in Tooltips von Gegnern und Gegenständen
---------------------------------------------------------------------------
local cache, cacheZeit = nil, 0
local function Questlog()
  local jetzt = GetTime()
  if not cache or jetzt - cacheZeit > 1 then cache, cacheZeit = QK.Compat:Questlog(), jetzt end
  return cache
end

-- Offene Ziele, deren Text den Namen enthält: { { quest, ziel } }
function X:ZieleFuer(name)
  local treffer = {}
  if not name or #name < 3 then return treffer end
  local n = name:lower()
  for _, q in ipairs(Questlog()) do
    if not q.fertig then
      for _, z in ipairs(q.ziele) do
        local t = (z.text or ""):lower()
        if not z.fertig and t ~= "" and (t:find(n, 1, true) or (#t >= 4 and n:find(t, 1, true))) then
          treffer[#treffer + 1] = { q, z }
        end
      end
    end
  end
  return treffer
end

local function SchonDrin(tooltip, text)
  local name = tooltip.GetName and tooltip:GetName()
  if not name then return false end
  for i = 2, (tooltip.NumLines and tooltip:NumLines() or 0) do
    local zeile = _G[name .. "TextLeft" .. i]
    local t = zeile and zeile.GetText and zeile:GetText()
    if t and t:find(text, 1, true) then return true end
  end
  return false
end

function X:TooltipErgaenzen(tooltip, name)
  if not QK.db.tooltipZiele then return end
  local dazu = false
  for _, t in ipairs(X:ZieleFuer(name)) do
    local q, z = t[1], t[2]
    if not SchonDrin(tooltip, z.text) then
      local stand = (z.ist and z.soll) and ("  %d/%d"):format(z.ist, z.soll) or ""
      tooltip:AddLine(SYMBOL .. q.titel .. ": " .. z.text .. stand, QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3])
      dazu = true
    end
  end
  if dazu then tooltip:Show() end
end

local function TooltipsVerbinden()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
      if tooltip ~= GameTooltip then return end
      local name = tooltip.GetUnit and tooltip:GetUnit()
      QK:Sicher("Tooltip", X.TooltipErgaenzen, X, tooltip, name)
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
      if tooltip ~= GameTooltip then return end
      local name = tooltip.GetItem and tooltip:GetItem()
      QK:Sicher("Tooltip", X.TooltipErgaenzen, X, tooltip, name)
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
      QK:Sicher("Tooltip", X.TooltipErgaenzen, X, tooltip, (tooltip:GetUnit()))
    end)
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
      QK:Sicher("Tooltip", X.TooltipErgaenzen, X, tooltip, (tooltip:GetItem()))
    end)
  end
end

---------------------------------------------------------------------------
-- Automatisch teilen und Zeitlimit-Warnung
---------------------------------------------------------------------------
local function Teilen(id)
  if not QK.db.autoTeilen or not id then return end
  local inGruppe = (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0)
  if not inGruppe then return end
  if C_QuestLog and C_QuestLog.IsPushableQuest and not C_QuestLog.IsPushableQuest(id) then return end
  for _, q in ipairs(QK.Compat:Questlog()) do
    if q.id == id then
      QK.Compat:Teilen(q)
      QK:Meldung(L"„%s“ mit der Gruppe geteilt.", q.titel)
      return
    end
  end
end

local gewarnt = {}
function X:Zeitlimits()
  if not QK.db.zeitWarnung then return end
  for _, q in ipairs(QK.Compat:Questlog()) do
    local rest = not q.fertig and QK.Compat:Restzeit(q)
    if rest then
      for _, grenze in ipairs({ 60, 10 }) do
        local schluessel = q.id .. ":" .. grenze
        if rest <= grenze and rest > 0 and not gewarnt[schluessel] then
          gewarnt[schluessel] = true
          if QK.Meldungen then QK.Meldungen:Zeigen((L"NOCH %d SEKUNDEN"):format(grenze), q.titel) end
          if QK.db.klang then pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Einstellungen teilen: als Text kopieren und bei anderen einfügen
---------------------------------------------------------------------------
local function Kodieren(t) return (tostring(t):gsub("[%%;=]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function Dekodieren(t) return (t:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

function X:Export()
  local teile, schluessel = { "QK1" }, {}
  for k in pairs(QK.STANDARD) do schluessel[#schluessel + 1] = k end
  table.sort(schluessel)
  for _, k in ipairs(schluessel) do
    local v = QK.db[k]
    if k ~= "eingerichtet" and k ~= "versteckt" then
      if type(v) == "boolean" then teile[#teile + 1] = k .. "=" .. (v and "t" or "f")
      elseif type(v) == "number" then teile[#teile + 1] = k .. "=#" .. v
      elseif type(v) == "string" then teile[#teile + 1] = k .. "=$" .. Kodieren(v) end
    end
  end
  return table.concat(teile, ";")
end

function X:Import(text)
  text = (text or ""):gsub("%s", "")
  if text:sub(1, 4) ~= "QK1;" then return false, 0 end
  local n = 0
  for k, v in text:sub(5):gmatch("([%w_]+)=([^;]*)") do
    local standard = QK.STANDARD[k]
    local wert
    if v == "t" or v == "f" then wert = v == "t"
    elseif v:sub(1, 1) == "#" then wert = tonumber(v:sub(2))
    elseif v:sub(1, 1) == "$" then wert = Dekodieren(v:sub(2)) end
    if wert ~= nil and (standard == nil and k == "zielStufe" or type(standard) == type(wert)) then
      QK.db[k] = wert
      n = n + 1
    end
  end
  QK:SpracheAnwenden()
  QK:Anwenden()
  return n > 0, n
end

local teilenFenster
function X:TeilenZeigen(mitText)
  if not teilenFenster then
    local f = CreateFrame("Frame", "QuestkompassTeilen", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(480, 130)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
    f:SetBackdropBorderColor(QK.farben.gold[1], QK.farben.gold[2], QK.farben.gold[3], 0.45)
    tinsert(UISpecialFrames, "QuestkompassTeilen")
    f.titel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.titel:SetPoint("TOPLEFT", 14, -12)
    f.titel:SetText(L"Einstellungen teilen")
    f.hinweis = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hinweis:SetPoint("TOPLEFT", f.titel, "BOTTOMLEFT", 0, -4)
    f.hinweis:SetPoint("RIGHT", -14, 0)
    f.hinweis:SetJustifyH("LEFT")
    f.hinweis:SetText(L"Text mit Strg+C kopieren und weitergeben, oder fremden Text einfügen und übernehmen.")
    local e = CreateFrame("EditBox", "QuestkompassTeilenText", f, "InputBoxTemplate")
    e:SetAutoFocus(false)
    e:SetHeight(22)
    e:SetPoint("TOPLEFT", 20, -54)
    e:SetPoint("TOPRIGHT", -14, -54)
    if e.SetMaxLetters then e:SetMaxLetters(0) end
    e:SetScript("OnEscapePressed", function() f:Hide() end)
    f.text = e
    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(120, 22)
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 12)
    ok:SetText(L"Übernehmen")
    ok:SetScript("OnClick", function()
      local geklappt, n = X:Import(e:GetText())
      if geklappt then QK:Meldung(L"%d Einstellungen übernommen.", n); f:Hide()
      else QK:Meldung(L"Dieser Text enthält keine Questkompass-Einstellungen.") end
    end)
    local zu = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    zu:SetSize(120, 22)
    zu:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 12)
    zu:SetText(L"Schließen")
    zu:SetScript("OnClick", function() f:Hide() end)
    teilenFenster = f
  end
  teilenFenster:SetScale(QK:Groesse())
  teilenFenster.text:SetText(mitText and X:Export() or "")
  teilenFenster:Show()
  teilenFenster.text:SetFocus()
  if mitText and teilenFenster.text.HighlightText then teilenFenster.text:HighlightText() end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
function X:Start()
  TooltipsVerbinden()
  QK:Haken("menue", function(q)
    return { { QK.char.angeheftet[q.id] and L"Nicht mehr anheften" or L"Oben anheften", function() X:Anheften(q.id) end } }
  end)
  QK:Ereignis("QUEST_ACCEPTED", function(a, b)
    local id = (b and b > 0 and b) or a
    C_Timer.After(0.5, function() QK:Sicher("Teilen", Teilen, id) end)
  end)
  QK:Ereignis("QUEST_TURNED_IN", function(id)
    if id then QK.char.angeheftet[id] = nil; QK.char.merkliste[id] = nil end
    local ziel = QK.db.tagesziel or 0
    if ziel > 0 and X:Heute() == ziel and QK.Meldungen then
      QK.Meldungen:Zeigen(L"TAGESZIEL ERREICHT", (L"%d Quests heute"):format(ziel))
      if QK.db.klang then pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 31578) end
    end
  end)
  local uhr, takt = CreateFrame("Frame"), 0
  uhr:SetScript("OnUpdate", function(_, el)
    takt = takt + el
    if takt < 1 then return end
    takt = 0
    QK:Sicher("Zeitlimit", X.Zeitlimits, X)
  end)
end

QK:Befehl({ "fokusmodus" }, function() X:Fokusmodus() end, L"/qk fokusmodus – Liste zeigt nur die Fokus-Quest (nochmal: aus)")
QK:Befehl({ "tagesziel" }, function(rest)
  local n = tonumber(rest)
  if not n then QK:Meldung(L"Beispiel: /qk tagesziel 10 (0 schaltet es aus)") return end
  QK.db.tagesziel = math.max(0, math.min(200, math.floor(n)))
  QK:Meldung(QK.db.tagesziel > 0 and (L"Tagesziel: %d Quests."):format(QK.db.tagesziel) or L"Tagesziel aus.")
  QK:Anwenden()
end, L"/qk tagesziel N – so viele Quests willst du heute schaffen")
QK:Befehl({ "export" }, function() X:TeilenZeigen(true) end, L"/qk export | import – Einstellungen als Text teilen")
QK:Befehl({ "import" }, function(rest)
  if rest ~= "" then
    local ok, n = X:Import(rest)
    QK:Meldung(ok and (L"%d Einstellungen übernommen."):format(n) or L"Dieser Text enthält keine Questkompass-Einstellungen.")
  else
    X:TeilenZeigen(false)
  end
end)
QK.tasten.fokusmodus = function() X:Fokusmodus() end
