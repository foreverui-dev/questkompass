-- Questkompass: Symbol an Gegnern, die du für eine Quest brauchst.
-- Hängt ein kleines Symbol (Totenkopf zum Besiegen, Beutel wenn sie einen Questgegenstand fallen
-- lassen) mit dem Stand an die Namensplakette. Namensplaketten gibt es nur für Einheiten in der
-- Nähe, das Symbol erscheint also automatisch nur bei Gegnern in Reichweite.
local _, QK = ...
local P = QK:Modul("Plaketten")
local L = QK.L

local SYMBOL = {
  monster = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
  item = "Interface\\Icons\\INV_Misc_Bag_10",
  object = "Interface\\Icons\\INV_Misc_Gear_01",
}
local marken = {}     -- Namensplakette -> unser Rahmen
local einheiten = {}  -- unit -> true, solange die Plakette sichtbar ist

-- Text, den Addons benutzen dürfen (geschützte Werte überspringen)
local function Text(v)
  if type(v) ~= "string" then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- Ziellinien aus dem Einheiten-Tooltip (moderne Clients): { text } offener Ziele
local function TooltipZiele(unit)
  local ziele = {}
  if not (C_TooltipInfo and C_TooltipInfo.GetUnit and Enum and Enum.TooltipDataLineType) then return ziele end
  local typ = Enum.TooltipDataLineType.QuestObjective
  if not typ then return ziele end
  local ok, daten = pcall(C_TooltipInfo.GetUnit, unit)
  if not ok or type(daten) ~= "table" or type(daten.lines) ~= "table" then return ziele end
  for _, zeile in ipairs(daten.lines) do
    local t = Text(zeile.leftText)
    if zeile.type == typ and t and not zeile.completed then
      local ist, soll = t:match("(%d+)%s*/%s*(%d+)")
      if not (ist and soll and tonumber(ist) >= tonumber(soll)) then ziele[#ziele + 1] = t end
    end
  end
  return ziele
end

-- Was braucht eine Quest von dieser Einheit? Liefert art, stand (z. B. "3/10") oder nil.
function P:Pruefen(unit)
  if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
  if UnitIsDead and UnitIsDead(unit) then return nil end
  local name = Text(UnitName(unit))
  local function auswerten(treffer)
    local z = treffer[1] and treffer[1][2]
    if not z then return nil end
    local stand = (z.ist and z.soll) and ("%d/%d"):format(z.ist, z.soll) or ""
    return (SYMBOL[z.art] and z.art or "monster"), stand
  end
  -- 1. Name steht in einem offenen Ziel („Bergpuma getötet“, „Bergpumapelz“)
  if name and QK.Extras then
    local art, stand = auswerten(QK.Extras:ZieleFuer(name))
    if art then return art, stand end
  end
  -- 2. Das Spiel nennt im Tooltip ein offenes Ziel
  for _, t in ipairs(TooltipZiele(unit)) do
    local art, stand = auswerten(QK.Extras:ZieleFuer(QK.Compat.ZielName(t)))
    if art then return art, stand end
    local ist, soll = t:match("(%d+)%s*/%s*(%d+)")
    return "monster", ist and (ist .. "/" .. soll) or ""
  end
  -- 3. Nur die Auskunft „gehört zu einer Quest“
  if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
    local ok, ja = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
    if ok and ja == true then return "monster", "" end
  end
  return nil
end

local function Marke(plakette)
  local m = marken[plakette]
  if m then return m end
  m = CreateFrame("Frame", nil, plakette)
  m:SetSize(20, 20)
  m.bild = m:CreateTexture(nil, "OVERLAY")
  m.bild:SetAllPoints()
  m.stand = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  m.stand:SetPoint("TOP", m, "BOTTOM", 0, -1)
  marken[plakette] = m
  return m
end

function P:Zeigen(unit)
  local plakette = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
  if not plakette then return end
  local art, stand
  if QK.db.questPlaketten then art, stand = P:Pruefen(unit) end
  local m = marken[plakette]
  if not art then
    if m then m:Hide() end
    return
  end
  m = Marke(plakette)
  local groesse = 20 * QK:Groesse()
  m:SetSize(groesse, groesse)
  m:ClearAllPoints()
  local uf = plakette.UnitFrame
  local balken = type(uf) == "table" and (uf.healthBar or uf.HealthBarsContainer) or nil
  if type(balken) ~= "table" then balken = nil end
  if balken then m:SetPoint("RIGHT", balken, "LEFT", -4, 0) else m:SetPoint("BOTTOM", plakette, "TOP", 0, 2) end
  m.bild:SetTexture(SYMBOL[art])
  if art ~= "monster" then m.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92) else m.bild:SetTexCoord(0, 1, 0, 1) end
  m.stand:SetText(stand or "")
  m:Show()
end

function P:AlleAktualisieren()
  for unit in pairs(einheiten) do QK:Sicher("Plaketten", P.Zeigen, P, unit) end
end

function P:Anwenden() P:AlleAktualisieren() end

function P:Start()
  QK:Ereignis("NAME_PLATE_UNIT_ADDED", function(unit)
    einheiten[unit] = true
    QK:Sicher("Plaketten", P.Zeigen, P, unit)
  end)
  QK:Ereignis("NAME_PLATE_UNIT_REMOVED", function(unit)
    einheiten[unit] = nil
    local plakette = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if plakette and marken[plakette] then marken[plakette]:Hide() end
  end)
  local geplant = false
  local function spaeter()
    if geplant then return end
    geplant = true
    C_Timer.After(0.3, function() geplant = false; P:AlleAktualisieren() end)
  end
  QK:Ereignis("QUEST_LOG_UPDATE", spaeter)
end
