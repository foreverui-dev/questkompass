-- Questkompass: zusätzliche Zeilen in Quest-Tooltips (Chat-Links, Zielliste, Gebietsfenster).
local _, QK = ...
local TT = {}
QK.Tooltip = TT

-- Fügt Gebiet, Typ, Erfahrung und Ruf zu einem Tooltip hinzu.
-- ohneTitel: true, wenn der Aufrufer den Questnamen schon gesetzt hat.
function TT:Ergaenzen(tooltip, questID, ohneTitel)
  local q = QK:Quest(questID)
  if not q then return false end
  if not ohneTitel and q.name then tooltip:AddLine(q.name, unpack(QK.farben.gold)) end
  local r, g, b = 0.85, 0.85, 0.85
  if q.gebiet and QK:GebietName(q.gebiet) then
    tooltip:AddDoubleLine("Gebiet", QK:GebietName(q.gebiet), 0.6, 0.6, 0.6, r, g, b)
  elseif q.kategorie and QK.kategorien[q.kategorie] then
    tooltip:AddDoubleLine("Kategorie", QK.Lokal(QK.kategorien[q.kategorie]), 0.6, 0.6, 0.6, r, g, b)
  end
  if q.typ then
    tooltip:AddDoubleLine("Typ", QK:TypName(q.typ), 0.6, 0.6, 0.6, 0.85, 0.55, 0.25)
  end
  if q.fraktion then
    tooltip:AddDoubleLine("Fraktion", q.fraktion == "A" and "Allianz" or "Horde", 0.6, 0.6, 0.6, r, g, b)
  end
  local ep = QK:EPText(q.ep)
  if ep then tooltip:AddDoubleLine("Erfahrung", ep, 0.6, 0.6, 0.6, r, g, b) end
  if q.ruf then
    for i = 1, #q.ruf, 2 do
      tooltip:AddDoubleLine(i == 1 and "Ruf" or " ", ("+%d %s"):format(q.ruf[i + 1], QK:FraktionName(q.ruf[i])),
        0.6, 0.6, 0.6, 0.45, 0.85, 0.45)
    end
  end
  if QK:IstErledigt(questID) then
    tooltip:AddLine("Bereits erledigt", 0.45, 0.85, 0.45)
  end
  return true
end

local function BeiLink(tooltip, link)
  if type(link) ~= "string" then return end
  local id = tonumber(link:match("quest:(%d+)"))
  if id and TT:Ergaenzen(tooltip, id, true) then tooltip:Show() end
end

function TT:Start()
  if ItemRefTooltip then hooksecurefunc(ItemRefTooltip, "SetHyperlink", BeiLink) end
  if GameTooltip then hooksecurefunc(GameTooltip, "SetHyperlink", BeiLink) end
end
