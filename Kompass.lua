-- Questkompass: Richtung und Entfernung zu Questzielen auf der aktuellen Karte.
local _, QK = ...
local K = QK:Modul("Kompass")

local karte, kartenZeit = nil, 0
local ziele = {}           -- questID -> { x, y } auf der aktuellen Karte
local groessen = {}        -- mapID -> { breite, hoehe } in Yards
local atan2 = math.atan2 or atan2

local function Groesse(mapID)
  if groessen[mapID] ~= nil then return groessen[mapID] end
  local g = false
  if C_Map and C_Map.GetMapWorldSize then
    local ok, b, h = pcall(C_Map.GetMapWorldSize, mapID)
    if ok and b and h and b > 0 and h > 0 then g = { b, h } end
  end
  if not g and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local ok, _, p0 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local ok1, _, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 0))
    local ok2, _, p2 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 1))
    if ok and ok1 and ok2 and p0 and p1 and p2 then
      local function abstand(a, b)
        local ax, ay = a:GetXY()
        local bx, by = b:GetXY()
        return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
      end
      local b, h = abstand(p0, p1), abstand(p0, p2)
      if b > 0 and h > 0 then g = { b, h } end
    end
  end
  groessen[mapID] = g
  return g
end

-- Karte und Questpositionen höchstens einmal pro Sekunde neu lesen.
function K:Auffrischen(jetzt)
  if jetzt and kartenZeit and jetzt - kartenZeit < 1 then return end
  kartenZeit = jetzt or 0
  wipe(ziele)
  karte = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not karte or not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return end
  local ok, liste = pcall(C_QuestLog.GetQuestsOnMap, karte)
  if ok and liste then
    for _, e in ipairs(liste) do
      if e.questID and e.x and e.y then ziele[e.questID] = { e.x, e.y } end
    end
  end
end

-- Aktuelle Karte und Position des Charakters darauf.
function K:Karte() return karte end
function K:Ziel(questID) local z = ziele[questID]; if z then return z[1], z[2] end end
function K:Ziele() return ziele end

-- Richtung zu einem Punkt (x, y) auf der aktuellen Karte.
-- Liefert: Winkel relativ zur Blickrichtung (im Uhrzeigersinn), Entfernung in Yards, Peilung ab Norden.
function K:RichtungZuPunkt(x, y)
  if not karte or not x then return nil end
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(karte, "player")
  if not pos then return nil end
  local px, py = pos:GetXY()
  if not px or (px == 0 and py == 0) then return nil end
  local g = Groesse(karte)
  local b, h = g and g[1] or 1000, g and g[2] or 667
  local dx, dy = (x - px) * b, (y - py) * h
  local entfernung = g and math.sqrt(dx * dx + dy * dy) or nil
  local peilung = atan2(dx, -dy)               -- im Uhrzeigersinn ab Norden
  local blick = GetPlayerFacing and GetPlayerFacing()
  if not blick then return nil, entfernung, peilung end
  return peilung + blick, entfernung, peilung  -- GetPlayerFacing zählt gegen den Uhrzeigersinn
end

-- Liefert Winkel (Bogenmaß, im Uhrzeigersinn relativ zur Blickrichtung) und Entfernung in Yards.
function K:Richtung(questID)
  local z = ziele[questID]
  if not z then return nil end
  return self:RichtungZuPunkt(z[1], z[2])
end

-- Entfernung zwischen zwei Kartenpunkten in Yards (für die Routenplanung).
function K:Abstand(x1, y1, x2, y2)
  local g = karte and Groesse(karte)
  local b, h = g and g[1] or 1000, g and g[2] or 667
  return math.sqrt(((x2 - x1) * b) ^ 2 + ((y2 - y1) * h) ^ 2)
end

-- Rechnet einen Punkt einer anderen Karte auf die aktuelle Karte um (gleicher Kontinent).
function K:Umrechnen(vonKarte, x, y)
  if not karte or not vonKarte or not x then return nil end
  if vonKarte == karte then return x, y end
  if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  local ok, kontinent, welt = pcall(C_Map.GetWorldPosFromMapPos, vonKarte, CreateVector2D(x, y))
  if not ok or not kontinent or not welt then return nil end
  local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, kontinent, welt, karte)
  if not ok2 or not pos then return nil end
  local nx, ny = pos:GetXY()
  if nx and nx >= -1 and nx <= 2 and ny >= -1 and ny <= 2 then return nx, ny end
end

function K:Spieler()
  if not karte then return nil end
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(karte, "player")
  if pos then return pos:GetXY() end
end

function K:Entfernung(questID)
  local d = QK.Compat:Entfernung(questID)
  if d then return d end
  local _, e = self:Richtung(questID)
  return e
end

-- Dreht eine Pfeil-Textur (zeigt im Original nach oben).
function K:PfeilDrehen(textur, winkel)
  if winkel then
    textur:SetRotation(-winkel)
    textur:Show()
  else
    textur:Hide()
  end
end

function K:Start()
  QK:Ereignis("ZONE_CHANGED_NEW_AREA", function() kartenZeit = nil; K:Auffrischen() end)
  QK:Ereignis("QUEST_POI_UPDATE", function() kartenZeit = nil end)
  K:Auffrischen()
end
