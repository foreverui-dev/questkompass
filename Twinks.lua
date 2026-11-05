-- Questkompass: Twink-Hilfe. Merkt sich kontoweit, welche Quests jeder Charakter erledigt hat,
-- und zeigt das in Tooltips und im Questbuch.
local _, QK = ...
local TW = QK:Modul("Twinks")
local L = QK.L

local function Schluessel()
  local name = UnitName("player") or "?"
  local realm = (GetRealmName and GetRealmName()) or ""
  return name .. "-" .. realm, name
end
TW.Schluessel = Schluessel

function TW:Ich()
  local db = QK.root and QK.root.charaktere
  return db and db[(Schluessel())]
end

-- Liest alle erledigten Quests des aktuellen Charakters ein.
function TW:Einlesen()
  local key, name = Schluessel()
  local _, klasse = UnitClass("player")
  local alt = QK.root.charaktere[key]
  local c = {
    name = name, klasse = klasse, stufe = UnitLevel("player"),
    fraktion = UnitFactionGroup("player"), zeit = time(),
    erledigt = QK.Compat:Erledigte(),
  }
  -- Abgaben dieser Sitzung behalten, falls der Server sie noch nicht meldet
  if alt and alt.erledigt then
    for id in pairs(alt.erledigt) do if not c.erledigt[id] and QK.Compat:IstErledigt(id) then c.erledigt[id] = true end end
  end
  local n = 0
  for _ in pairs(c.erledigt) do n = n + 1 end
  c.anzahl = n
  QK.root.charaktere[key] = c
  return c
end

-- Namen anderer Charaktere (gleiche Fraktion zuerst), die eine Quest erledigt haben
function TW:Andere(questID)
  local namen = {}
  if not QK.db.twinks then return namen end
  local ich = Schluessel()
  for key, c in pairs(QK.root.charaktere or {}) do
    if key ~= ich and c.erledigt and c.erledigt[questID] then namen[#namen + 1] = c.name end
  end
  table.sort(namen)
  return namen
end

function TW:Liste()
  local liste = {}
  for key, c in pairs(QK.root.charaktere or {}) do liste[#liste + 1] = { key = key, c = c } end
  table.sort(liste, function(a, b) return (a.c.stufe or 0) > (b.c.stufe or 0) end)
  return liste
end

function TW:Start()
  C_Timer.After(5, function() QK:Sicher("Twinks", TW.Einlesen, TW) end)
  QK:Ereignis("QUEST_TURNED_IN", function(id)
    local c = TW:Ich()
    if c and id and not c.erledigt[id] then c.erledigt[id] = true; c.anzahl = (c.anzahl or 0) + 1 end
  end)
  QK:Ereignis("PLAYER_LEVEL_UP", function(stufe) local c = TW:Ich(); if c then c.stufe = stufe end end)
  QK:Haken("tooltip", function(tooltip, questID)
    local andere = TW:Andere(questID)
    if #andere > 0 then
      tooltip:AddDoubleLine(L"Erledigt von", table.concat(andere, ", "), 0.6, 0.6, 0.6, 0.5, 0.75, 1)
    end
  end)
end

QK:Befehl({ "twinks", "twink" }, function(rest)
  local was, name = rest:match("^(%S*)%s*(.-)$")
  if (was == "vergessen" or was == "forget") and name ~= "" then
    for key, c in pairs(QK.root.charaktere) do
      if c.name and c.name:lower() == name:lower() then
        QK.root.charaktere[key] = nil
        QK:Meldung(L"%s vergessen.", c.name)
        return
      end
    end
    QK:Meldung(L"keinen Charakter namens „%s“ gefunden.", name)
    return
  end
  QK:Meldung(L"Charaktere mit Questkompass:")
  for _, e in ipairs(TW:Liste()) do
    DEFAULT_CHAT_FRAME:AddMessage(("  %s (%s %d): %d %s"):format(e.c.name or e.key, L"Stufe", e.c.stufe or 0, e.c.anzahl or 0, L"Quests erledigt"))
  end
  DEFAULT_CHAT_FRAME:AddMessage("  " .. L"/qk twinks vergessen Name – Charakter aus der Liste nehmen")
end, L"/qk twinks – deine Charaktere und ihre erledigten Quests")
