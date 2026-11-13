-- Questkompass: Bausteine für alle Fenster im einheitlichen ForeverUI-Design (wie FM.Bausteine im DPS-Meter)
-- (einfarbige Flächen, 1-px-Ränder, Akzentfarbe, die sich ohne /reload ändern lässt).
local _, QK = ...
local UI = {}
QK.UI = UI

-- Alles, was die Akzentfarbe trägt, meldet sich hier an und wird bei einem Wechsel neu gefärbt.
local goldTeile = {}
function UI.Gold(fn) goldTeile[#goldTeile + 1] = fn; fn() end
function UI.FarbeAuffrischen() for _, fn in ipairs(goldTeile) do pcall(fn) end end
function UI.GoldVergessen() wipe(goldTeile) end

function UI.Rahmen(f, alpha, rand)
  f.hg = f.hg or f:CreateTexture(nil, "BACKGROUND")
  f.hg:SetAllPoints()
  f.hg:SetColorTexture(0.06, 0.06, 0.08, alpha or 0.6)
  f.rand = f.rand or {}
  local function kante(i, p1, p2, w, h)
    local t = f.rand[i] or f:CreateTexture(nil, "BORDER")
    t:ClearAllPoints()
    t:SetPoint(p1); t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
    f.rand[i] = t
  end
  kante(1, "TOPLEFT", "TOPRIGHT", nil, 1)
  kante(2, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  kante(3, "TOPLEFT", "BOTTOMLEFT", 1)
  kante(4, "TOPRIGHT", "BOTTOMRIGHT", 1)
  UI.RandFarbe(f, rand or { 1, 1, 1, 0.12 })
end

function UI.RandFarbe(f, c)
  for _, t in ipairs(f.rand or {}) do t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

-- Rand in Akzentfarbe, der einem Wechsel der Akzentfarbe folgt
function UI.GoldRand(f, alpha)
  UI.Gold(function() local g = QK.farben.gold; UI.RandFarbe(f, { g[1], g[2], g[3], alpha or 0.45 }) end)
end

function UI.Text(eltern, schrift, text, breite)
  local t = eltern:CreateFontString(nil, "OVERLAY", schrift or "GameFontHighlightSmall")
  t:SetJustifyH("LEFT")
  if breite then t:SetWidth(breite) end
  if text then t:SetText(text) end
  return t
end

function UI.Knopf(eltern, text, breite, fn)
  local k = CreateFrame("Button", nil, eltern)
  k:SetSize(breite or 18, 18)
  UI.Rahmen(k, 0.5)
  k.text = UI.Text(k, "GameFontHighlightSmall", text)
  k.text:SetPoint("CENTER")
  local hl = k:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  k:SetScript("OnClick", fn)
  k.SetText = function(self, t) self.text:SetText(t) end
  return k
end

function UI.Tipp(f, titel, ...)
  local zeilen = { ... }
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(titel, unpack(QK.farben.gold))
    for _, z in ipairs(zeilen) do GameTooltip:AddLine(z, 0.85, 0.85, 0.85, true) end
    GameTooltip:Show()
    QK:Sprechen(titel)
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Textfeld nur zum Lesen und Kopieren: Eingaben werden zurückgesetzt, ein Klick markiert den Text
-- (feld.markieren: nur so viele Zeichen, z. B. nur einen Link in der ersten Zeile).
local function markieren(self)
  if self.markieren then self:HighlightText(0, self.markieren) else self:HighlightText() end
end

function UI.Schreibschutz(feld)
  feld:SetScript("OnTextChanged", function(self, vomSpieler)
    if self.nurLesen and vomSpieler and self.inhalt and self:GetText() ~= self.inhalt then
      self:SetText(self.inhalt)
      markieren(self)
    end
  end)
  feld:SetScript("OnEditFocusGained", function(self) if self.nurLesen then markieren(self) end end)
end

function UI.Lesetext(feld, text, zeichen)
  feld.inhalt, feld.nurLesen, feld.markieren = text, true, zeichen
  feld:SetText(text)
end

-- Bildlaufleiste nur zeigen, wenn es etwas zu blättern gibt (sonst stehen leere Pfeile da)
local function leisteVon(rolle)
  local leiste = rolle.ScrollBar
  if type(leiste) ~= "table" then
    local name = rolle.GetName and rolle:GetName()
    leiste = type(name) == "string" and _G[name .. "ScrollBar"] or nil
  end
  if type(leiste) == "table" and leiste.SetShown then return leiste end
end
function UI.Bildlauf(rolle)
  local function pruefen(self, _, y)
    local leiste = leisteVon(self)
    if not leiste then return end
    if type(y) ~= "number" then y = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0 end
    local noetig = type(y) == "number" and y > 0.5
    leiste:SetShown(noetig)
    if not noetig and self.SetVerticalScroll then self:SetVerticalScroll(0) end
  end
  rolle:HookScript("OnScrollRangeChanged", pruefen)
  rolle:HookScript("OnShow", function(self) pruefen(self) end)
  pruefen(rolle)
  return rolle
end

---------------------------------------------------------------------------
-- Auswahlmenü: QK.UI:Menue(anker, { { text, fn, an = bool, titel = bool }, ... }, seitlich)
-- seitlich: neben dem Anker statt darunter (für die Questliste am Bildschirmrand)
---------------------------------------------------------------------------
local menue, knoepfe = nil, {}
function UI:Menue(anker, eintraege, seitlich)
  if not menue then
    menue = CreateFrame("Frame", "QuestkompassMenue", UIParent)
    menue:SetFrameStrata("FULLSCREEN_DIALOG")
    menue:SetClampedToScreen(true)
    menue:EnableMouse(true)
    menue:Hide()
    tinsert(UISpecialFrames, "QuestkompassMenue")
    -- schließt sich, wenn die Maus eine Weile draußen ist
    menue:SetScript("OnShow", function(self) self.zeit, self.weg = 0, 0 end)
    menue:SetScript("OnUpdate", function(self, el)
      self.zeit = (self.zeit or 0) + el
      if self.zeit > 0.5 and not self:IsMouseOver() then
        self.weg = (self.weg or 0) + el
        if self.weg > 1.5 then self:Hide() end
      else
        self.weg = 0
      end
    end)
  end
  if menue:IsShown() and menue.anker == anker then menue:Hide(); return end
  menue.anker = anker
  menue:SetScale(QK:Groesse())
  local g = QK.farben.gold
  UI.Rahmen(menue, 0.95, { g[1], g[2], g[3], 0.5 })
  local breite = 150
  for i, e in ipairs(eintraege) do
    local k = knoepfe[i]
    if not k then
      k = CreateFrame("Button", nil, menue)
      k:SetHeight(18)
      k.text = UI.Text(k, "GameFontHighlightSmall")
      k.text:SetPoint("LEFT", 8, 0)
      local hl = k:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.08)
      knoepfe[i] = k
    end
    k:ClearAllPoints()
    k:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 18)
    k:SetPoint("RIGHT", -4, 0)
    k.text:SetText(e.titel and ("|cfff2c45a" .. e[1] .. "|r") or ((e.an and "› " or "   ") .. e[1]))
    if e.an then k.text:SetTextColor(unpack(g)) else k.text:SetTextColor(unpack(QK.farben.hell)) end
    breite = math.max(breite, (k.text:GetStringWidth() or 100) + 24)
    k:SetScript("OnClick", function()
      menue:Hide()
      if e[2] then QK:Sicher("Menü", e[2]) end
    end)
    k:SetScript("OnEnter", function() QK:Sprechen(e[1]) end)
    k:EnableMouse(not e.titel)
    k:Show()
  end
  for i = #eintraege + 1, #knoepfe do knoepfe[i]:Hide() end
  menue:SetSize(breite, #eintraege * 18 + 8)
  menue:ClearAllPoints()
  if not seitlich then
    menue:SetPoint("TOPLEFT", anker, "BOTTOMLEFT", 0, -2)
  elseif anker.GetLeft and anker:GetLeft() and anker:GetLeft() < 220 then
    menue:SetPoint("TOPLEFT", anker, "TOPRIGHT", 4, 0)
  else
    menue:SetPoint("TOPRIGHT", anker, "TOPLEFT", -4, 0)
  end
  menue:Show()
  return menue
end

function UI:MenueZu() if menue then menue:Hide() end end
function UI:MenueOffen() return menue and menue:IsShown() and true or false end
