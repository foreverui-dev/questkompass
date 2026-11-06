-- Questkompass: Questgegenstände. Zeigt am Gegenstand, für welche Quests er noch gebraucht wird:
-- eigene Quests im Log, Quests deiner anderen Charaktere und Quests, die das Addon schon einmal
-- mit diesem Gegenstand gesehen hat und die du noch nicht erledigt hast.
-- Die Blizzard-Questdaten enthalten keine benötigten Gegenstände, deshalb lernt das Addon sie
-- kontoweit aus dem Questlog aller Charaktere (QuestkompassDB.questGegenstaende).
local _, QK = ...
local GG = QK:Modul("Gegenstaende")
local L = QK.L

local SYMBOL = "|TInterface\\GossipFrame\\ActiveQuestIcon:0:0:0:0|t "
local MAX_SPAETER = 4

local function Schluessel(name) return name and name:lower():gsub("^%s+", ""):gsub("%s+$", "") end

local function IstGegenstand(z)
  return z.art == "item" and z.text and #z.text >= 3
end

-- Liest das Questlog: merkt sich gelernte Gegenstände und was dieser Charakter gerade braucht.
function GG:Einlesen()
  local gelernt = QK.root.questGegenstaende
  local brauche = {}
  for _, q in ipairs(QK.Compat:Questlog()) do
    for _, z in ipairs(q.ziele or {}) do
      if IstGegenstand(z) then
        local k = Schluessel(z.text)
        local e = gelernt[k]
        if not e then e = { n = z.text, q = {} }; gelernt[k] = e end
        e.q[q.id] = z.soll or e.q[q.id] or 1
        brauche[k] = brauche[k] or {}
        table.insert(brauche[k], { q.id, q.titel, z.ist, z.soll, (z.fertig or q.fertig) and true or false })
      end
    end
  end
  GG.brauche = brauche
  local ich = QK.Twinks and QK.Twinks:Ich()
  if ich then ich.brauche = brauche end
  return brauche
end

local function Titel(id, notfalls)
  local d = QK:Quest(id)
  return (d and d.name) or notfalls or (L"Quest " .. id)
end

local function Stand(ist, soll)
  return (ist and soll) and (" %d/%d"):format(ist, soll) or ""
end

-- Alle Zeilen für einen Gegenstand: { { text, r, g, b } }
function GG:Zeilen(name)
  local zeilen = {}
  local k = Schluessel(name)
  if not k or #k < 3 then return zeilen end
  local brauche = GG.brauche or GG:Einlesen()
  local imLog = {}
  -- 1. eigene Quests im Log
  for _, e in ipairs(brauche[k] or {}) do
    imLog[e[1]] = true
    if e[5] then
      zeilen[#zeilen + 1] = { SYMBOL .. Titel(e[1], e[2]) .. ": " .. L"fertig, bis zur Abgabe behalten", unpack(QK.farben.gruen) }
    else
      zeilen[#zeilen + 1] = { SYMBOL .. Titel(e[1], e[2]) .. Stand(e[3], e[4]), unpack(QK.farben.gold) }
    end
  end
  -- 2. andere Charaktere
  if QK.db.twinks then
    local ich = QK.Twinks and QK.Twinks.Schluessel()
    for key, c in pairs(QK.root.charaktere or {}) do
      if key ~= ich and c.brauche and c.brauche[k] then
        for _, e in ipairs(c.brauche[k]) do
          local zustand = e[5] and (" – " .. L"fertig") or Stand(e[3], e[4])
          zeilen[#zeilen + 1] = { (c.name or "?") .. ": " .. Titel(e[1], e[2]) .. zustand, 0.5, 0.75, 1 }
        end
      end
    end
  end
  -- 3. gelernte Quests, die dieser Charakter noch machen kann
  local e = QK.root.questGegenstaende[k]
  if e then
    local spaeter = {}
    for id, soll in pairs(e.q) do
      local d = QK:Quest(id)
      if not imLog[id] and not QK.Compat:IstErledigt(id) and (not d or QK:PasstZumCharakter(d)) then
        spaeter[#spaeter + 1] = { Titel(id), soll }
      end
    end
    table.sort(spaeter, function(a, b) return a[1] < b[1] end)
    for i, s in ipairs(spaeter) do
      if i > MAX_SPAETER then
        zeilen[#zeilen + 1] = { (L"und %d weitere Quests"):format(#spaeter - MAX_SPAETER), 0.7, 0.7, 0.7 }
        break
      end
      local menge = (s[2] and s[2] > 1) and (" (" .. s[2] .. ")") or ""
      zeilen[#zeilen + 1] = { L"Später für: " .. s[1] .. menge, 0.8, 0.8, 0.8 }
    end
  end
  return zeilen
end

function GG:Tooltip(tooltip, name)
  local zeilen = GG:Zeilen(name)
  if #zeilen == 0 then return end
  tooltip:AddLine(L"Für Quests gebraucht:", 0.6, 0.6, 0.6)
  for _, z in ipairs(zeilen) do tooltip:AddLine(z[1], z[2], z[3], z[4]) end
  tooltip:Show()
end

-- /qk gegenstaende: alles, was du und deine Charaktere für Quests sammeln
function GG:Ausgeben()
  local brauche = GG:Einlesen()
  local namen = {}
  for k in pairs(brauche) do namen[#namen + 1] = k end
  for key, c in pairs(QK.root.charaktere or {}) do
    if key ~= QK.Twinks.Schluessel() and c.brauche then
      for k in pairs(c.brauche) do if not brauche[k] then brauche[k] = false; namen[#namen + 1] = k end end
    end
  end
  table.sort(namen)
  if #namen == 0 then QK:Meldung(L"Gerade braucht keine Quest einen Gegenstand.") return end
  QK:Meldung(L"Questgegenstände (%d):", #namen)
  for _, k in ipairs(namen) do
    local e = QK.root.questGegenstaende[k]
    local teile = {}
    for _, z in ipairs(GG:Zeilen(k)) do teile[#teile + 1] = (z[1]:gsub("|T.-|t%s*", "")) end
    print("  " .. ((e and e.n) or k) .. ": " .. table.concat(teile, "; "))
  end
end

function GG:Start()
  QK.root.questGegenstaende = QK.root.questGegenstaende or {}
  local geplant = false
  QK:Ereignis("QUEST_LOG_UPDATE", function()
    if geplant then return end
    geplant = true
    C_Timer.After(0.5, function() geplant = false; QK:Sicher("Gegenstaende", GG.Einlesen, GG) end)
  end)
  C_Timer.After(6, function() QK:Sicher("Gegenstaende", GG.Einlesen, GG) end)
end

QK:Befehl({ "gegenstaende", "gegenstände", "items" }, function() GG:Ausgeben() end,
  L"/qk gegenstaende – welche Gegenstände deine Quests noch brauchen")
