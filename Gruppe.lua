-- Questkompass: Gruppen-Abgleich und Gruppensuche.
-- Mitspieler mit Questkompass tauschen ihren Questfortschritt über unsichtbare Addon-Nachrichten aus,
-- die Liste zeigt dann z. B. „Kumpel 3/8“. Für Gruppenquests gibt es eine fertige Suchnachricht.
local _, QK = ...
local GR = QK:Modul("Gruppe")
local L = QK.L

local PRAEFIX = "Questkompass"
local fortschritt = {}      -- Name -> { [questID] = "F" | "3/8" }
local letzteNachricht, zuletzt = nil, 0
GR.fortschritt = fortschritt

local function InGruppe()
  return ((IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0)) and not (IsInRaid and IsInRaid())
end

local function Senden(text)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    pcall(C_ChatInfo.SendAddonMessage, PRAEFIX, text, "PARTY")
  elseif SendAddonMessage then
    pcall(SendAddonMessage, PRAEFIX, text, "PARTY")
  end
end

-- Eigener Stand, kompakt: "id=F" für fertig, sonst "id=3/8" (erstes offenes Ziel)
function GR:Stand()
  local teile = {}
  for _, q in ipairs(QK.Compat:Questlog()) do
    if q.fertig then
      teile[#teile + 1] = q.id .. "=F"
    else
      for _, z in ipairs(q.ziele) do
        if not z.fertig and z.ist and z.soll then teile[#teile + 1] = ("%d=%d/%d"):format(q.id, z.ist, z.soll) break end
      end
    end
  end
  return teile
end

function GR:Verschicken(immer)
  if not QK.db.gruppenAbgleich or not InGruppe() then return end
  local teile = GR:Stand()
  local ganz = table.concat(teile, ";")
  if not immer and ganz == letzteNachricht then return end
  letzteNachricht = ganz
  -- in Stücken unter 250 Zeichen; "S" beginnt einen neuen Stand, "+" ergänzt ihn
  local stueck, art = {}, "S"
  local laenge = 0
  for _, t in ipairs(teile) do
    if laenge + #t > 240 then
      Senden(art .. table.concat(stueck, ";"))
      stueck, laenge, art = {}, 0, "+"
    end
    stueck[#stueck + 1] = t
    laenge = laenge + #t + 1
  end
  Senden(art .. table.concat(stueck, ";"))
end

local function Empfangen(praefix, text, kanal, absender)
  if praefix ~= PRAEFIX or not text or not absender then return end
  local name = Ambiguate and Ambiguate(absender, "short") or absender:match("^[^-]+")
  if name == UnitName("player") then return end
  local art = text:sub(1, 1)
  if art == "?" then GR:Verschicken(true) return end
  if art == "S" then fortschritt[name] = {} end
  local t = fortschritt[name] or {}
  fortschritt[name] = t
  for id, wert in text:sub(2):gmatch("(%d+)=([^;]+)") do t[tonumber(id)] = wert end
  if QK.Tracker then QK.Tracker:Planen() end
end

-- Zeile unter der Quest: "Kumpel 3/8 · Freund fertig"
function GR:Zeile(q)
  if not QK.db.gruppenAbgleich or not InGruppe() then return nil end
  local teile = {}
  for name, t in pairs(fortschritt) do
    local w = t[q.id]
    if w then teile[#teile + 1] = name .. " " .. (w == "F" and L"fertig" or w) end
  end
  if #teile == 0 then return nil end
  table.sort(teile)
  return { "|cff7fbfff" .. table.concat(teile, " · ") .. "|r", QK.farben.hell, L"Fortschritt deiner Gruppe (mit Questkompass)" }
end

---------------------------------------------------------------------------
-- Gruppensuche
---------------------------------------------------------------------------
local function IstGruppenquest(q)
  if q.gruppe and q.gruppe > 0 then return true end
  local typ = q.daten and q.daten.typ
  return typ == 1 or typ == 62 or typ == 81
end

function GR:SuchText(q)
  local link = QK.Compat:QuestLink(q) or ("[" .. q.titel .. "]")
  local offen = 0
  for _, z in ipairs(q.ziele) do if not z.fertig then offen = offen + 1 end end
  local typ = q.daten and q.daten.typ and QK:TypName(q.daten.typ)
  local extra = {}
  if typ then extra[#extra + 1] = typ end
  if q.gruppe and q.gruppe > 0 then extra[#extra + 1] = (L"für %d Spieler"):format(q.gruppe) end
  local text = (L"Suche Gruppe für %s"):format(link)
  if #extra > 0 then text = text .. " (" .. table.concat(extra, ", ") .. ")" end
  if offen > 0 and #q.ziele > 1 then text = text .. (L", noch %d von %d Zielen offen"):format(offen, #q.ziele) end
  return text .. L" – bitte anschreiben!"
end

function GR:Suchen(q)
  local kanal = 0
  if GetChannelName then
    for _, n in ipairs({ "LookingForGroup", "SucheNachGruppe", "World", "Welt" }) do
      local id = GetChannelName(n)
      if id and id > 0 then kanal = id break end
    end
  end
  local text = (kanal > 0 and ("/" .. kanal .. " ") or "/1 ") .. GR:SuchText(q)
  if ChatFrame_OpenChat then ChatFrame_OpenChat(text) end
end

function GR:Start()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PRAEFIX)
  elseif RegisterAddonMessagePrefix then
    pcall(RegisterAddonMessagePrefix, PRAEFIX)
  end
  QK:Ereignis("CHAT_MSG_ADDON", Empfangen)
  QK:Ereignis("GROUP_ROSTER_UPDATE", function()
    if not InGruppe() then wipe(fortschritt); letzteNachricht = nil return end
    for name in pairs(fortschritt) do
      if not (UnitInParty and UnitInParty(name)) then fortschritt[name] = nil end
    end
    if QK.db.gruppenAbgleich then Senden("?") end
    GR:Verschicken(true)
  end)
  local geplant = false
  QK:Ereignis("QUEST_LOG_UPDATE", function()
    if geplant or not InGruppe() then return end
    geplant = true
    local warte = math.max(0.5, 2 - (GetTime() - zuletzt))
    C_Timer.After(warte, function()
      geplant, zuletzt = false, GetTime()
      QK:Sicher("Gruppen-Abgleich", GR.Verschicken, GR)
    end)
  end)
  QK:Haken("zeilen", function(q) return GR:Zeile(q) end)
  QK:Haken("menue", function(q)
    if IstGruppenquest(q) and not q.fertig then
      return { { L"Gruppe suchen (Nachricht vorbereiten)", function() GR:Suchen(q) end } }
    end
  end)
end
