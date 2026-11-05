-- Questkompass: großer, frei schwebender Pfeil zur Fokus-Quest, wie ein Navi.
local _, QK = ...
local P = QK:Modul("Pfeil")
local L = QK.L
local rahmen, pfeil, titel, info

local function Farbe(winkel)
  local a = math.abs(((winkel + math.pi) % (2 * math.pi)) - math.pi) / math.pi
  if QK.db.farbenblind then
    -- blau geradeaus, weiß seitlich, orange hinter dir
    if a < 0.5 then return 0.35 + a * 1.3, 0.65 + a * 0.7, 1 end
    return 1, 1 - (a - 0.5) * 0.8, 1 - (a - 0.5) * 1.8
  end
  -- grün geradeaus, gelb seitlich, rot hinter dir
  if a < 0.5 then return 0.3 + a * 1.4, 0.9, 0.3 end
  return 1, 0.9 - (a - 0.5) * 1.4, 0.25
end

-- Richtung in Worten, z. B. für Farbenblind- und Kontrastmodus
local function Richtungswort(winkel)
  local grad = math.deg(((winkel + math.pi) % (2 * math.pi)) - math.pi)
  if math.abs(grad) < 25 then return L"geradeaus" end
  if math.abs(grad) > 150 then return L"hinter dir" end
  if grad > 0 then return grad < 80 and L"halb rechts" or L"rechts" end
  return grad > -80 and L"halb links" or L"links"
end

local function Erstellen()
  rahmen = CreateFrame("Button", "QuestkompassPfeil", UIParent)
  rahmen:SetSize(160, 96)
  rahmen:SetFrameStrata("MEDIUM")
  rahmen:SetClampedToScreen(true)
  rahmen:SetMovable(true)
  rahmen:RegisterForDrag("LeftButton")
  rahmen:RegisterForClicks("RightButtonUp")
  rahmen:SetScript("OnDragStart", rahmen.StartMoving)
  rahmen:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    QK.db.pfeilPos = { p, rp, x, y }
  end)
  rahmen:SetScript("OnClick", function()
    if rahmen.wegpunkt then QK.Navigation:WegpunktLoeschen() return end
    QK.Compat:FokusSetzen(nil)
    QK:Anwenden()
  end)
  rahmen:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L"Fokuspfeil", unpack(QK.farben.gold))
    GameTooltip:AddLine(L"Ziehen: verschieben", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(rahmen.wegpunkt and L"Rechtsklick: Wegpunkt löschen" or L"Rechtsklick: Fokus aufheben", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  rahmen:SetScript("OnLeave", function() GameTooltip:Hide() end)

  pfeil = rahmen:CreateTexture(nil, "ARTWORK")
  pfeil:SetTexture("Interface\\Minimap\\MiniMap-QuestArrow")
  pfeil:SetSize(48, 48)
  pfeil:SetPoint("TOP", 0, 0)
  titel = rahmen:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titel:SetPoint("TOP", pfeil, "BOTTOM", 0, -2)
  titel:SetWidth(220)
  titel:SetWordWrap(false)
  info = rahmen:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info:SetPoint("TOP", titel, "BOTTOM", 0, -2)

  local takt = 0
  rahmen:SetScript("OnUpdate", function(_, el)
    takt = takt + el
    if takt < 0.05 then return end
    takt = 0
    QK:Sicher("Fokuspfeil", P.Drehen, P)
  end)
  rahmen:Hide()
end

function P:Drehen()
  local id, wp = rahmen.questID, rahmen.wegpunkt
  if not id and not wp then return end
  QK.Kompass:Auffrischen(GetTime())
  local winkel, d
  if wp then
    local x, y = QK.Navigation:WegpunktHier()
    if x then winkel, d = QK.Kompass:RichtungZuPunkt(x, y) end
    if d and d < 8 then QK.Navigation:WegpunktLoeschen(true) return end
  else
    local e
    winkel, e = QK.Kompass:Richtung(id)
    d = QK.Compat:Entfernung(id) or e
  end
  if winkel then
    pfeil:SetRotation(-winkel)
    pfeil:SetVertexColor(Farbe(winkel))
    pfeil:Show()
  else
    pfeil:Hide()
  end
  if d and d < 8 then
    info:SetText(QK.gold .. L"Am Ziel|r")
    if not rahmen.angekommen then rahmen.angekommen = true; QK:Sprechen(L"Am Ziel.") end
  elseif d then
    if d > 20 then rahmen.angekommen = false end
    local tempo = GetUnitSpeed and GetUnitSpeed("player") or 0
    local text = QK:EntfernungText(d)
    if tempo > 0 then text = text .. "  ·  " .. QK:DauerText(d / tempo) end
    if winkel and (QK.db.farbenblind or QK.db.kontrast) then text = text .. "  ·  " .. Richtungswort(winkel) end
    info:SetText(text)
  else
    info:SetText(L"|cff8c8c8cZiel nicht auf dieser Karte|r")
  end
end

function P:Aktualisieren()
  if not rahmen then return end
  local wp = QK.db.pfeilGross and QK.Navigation and QK.Navigation:Wegpunkt()
  rahmen.wegpunkt = wp or nil
  if wp then
    rahmen.questID = nil
    titel:SetText(wp.name or L"Wegpunkt")
    titel:SetTextColor(unpack(QK.farben.gold))
    rahmen:Show()
    P:Drehen()
    return
  end
  local id = QK.db.pfeilGross and QK.Compat:Fokus()
  local q
  if id then
    for _, x in ipairs(QK.Compat:Questlog()) do if x.id == id then q = x end end
  end
  if not q then rahmen.questID = nil; rahmen:Hide() return end
  rahmen.questID = id
  titel:SetText(q.titel)
  titel:SetTextColor(unpack(QK.farben.gold))
  rahmen:Show()
  P:Drehen()
end

function P:Anwenden()
  if not rahmen then return end
  rahmen:SetScale(QK:Groesse())
  rahmen:ClearAllPoints()
  local p = QK.db.pfeilPos
  if p then rahmen:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else rahmen:SetPoint("TOP", UIParent, "TOP", 0, -110) end
  P:Aktualisieren()
end

function P:Start()
  Erstellen()
  QK:Ereignis("SUPER_TRACKING_CHANGED", function() P:Aktualisieren() end)
  P:Anwenden()
end
