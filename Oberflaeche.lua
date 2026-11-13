-- Questkompass: Bausteine für alle Fenster im einheitlichen ForeverUI-Design
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

-- Textfeld nur zum Lesen und Kopieren: Eingaben werden zurückgesetzt, ein Klick markiert alles.
function UI.Schreibschutz(feld)
  feld:SetScript("OnTextChanged", function(self, vomSpieler)
    if self.nurLesen and vomSpieler and self.inhalt and self:GetText() ~= self.inhalt then
      self:SetText(self.inhalt)
      self:HighlightText()
    end
  end)
  feld:SetScript("OnEditFocusGained", function(self) if self.nurLesen then self:HighlightText() end end)
end

function UI.Lesetext(feld, text)
  feld.inhalt, feld.nurLesen = text, true
  feld:SetText(text)
end
