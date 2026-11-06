-- Questkompass: Reiter „Statistik“ im Questbuch. Quests pro Tag, Summen, Lieblingsgebiet und Rekorde
-- aus dem Questtagebuch dieses Charakters.
local _, QK = ...
local S = QK:Modul("Statistik")
local L = QK.L

local TAGE = 14
local titel, zeile1, zeile2

local function Zahl(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n + 0.5)) or tostring(math.floor(n + 0.5)) end

-- Wertet das Tagebuch aus
function S:Auswerten()
  local buch = QK.char.tagebuch
  local tage, gebiete = {}, {}
  local r = { quests = #buch, ep = 0, gold = 0, tage = tage }
  for _, e in ipairs(buch) do
    r.ep = r.ep + (e.ep or 0)
    r.gold = r.gold + (e.gold or 0)
    local tag = date("%Y-%m-%d", e.zeit)
    local t = tage[tag]
    if not t then t = { quests = 0, ep = 0 }; tage[tag] = t end
    t.quests, t.ep = t.quests + 1, t.ep + (e.ep or 0)
    local g = e.gebiet or (QK:Quest(e.id) or {}).gebiet
    if g then gebiete[g] = (gebiete[g] or 0) + 1 end
    if e.dauer and e.dauer > 0 then
      if not r.schnellste or e.dauer < r.schnellste.dauer then r.schnellste = e end
      if not r.laengste or e.dauer > r.laengste.dauer then r.laengste = e end
    end
    if not r.meisteEP or (e.ep or 0) > (r.meisteEP.ep or 0) then r.meisteEP = e end
  end
  for tag, t in pairs(tage) do
    if not r.besterTag or t.quests > r.besterTag.quests then r.besterTag = { tag = tag, quests = t.quests } end
  end
  for g, n in pairs(gebiete) do
    if not r.lieblingsgebiet or n > r.lieblingsgebiet.n then r.lieblingsgebiet = { id = g, n = n } end
  end
  local anzahlTage = 0
  for _ in pairs(tage) do anzahlTage = anzahlTage + 1 end
  r.schnitt = anzahlTage > 0 and r.quests / anzahlTage or 0
  return r
end

local function Kopf(k)
  titel = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  titel:SetPoint("TOPLEFT")
  titel:SetText(L"Statistik")
  zeile1 = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  zeile1:SetPoint("TOPLEFT", titel, "BOTTOMLEFT", 0, -6)
  zeile1:SetPoint("RIGHT", 0, 0)
  zeile1:SetJustifyH("LEFT")
  zeile2 = k:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zeile2:SetPoint("TOPLEFT", zeile1, "BOTTOMLEFT", 0, -4)
  zeile2:SetPoint("RIGHT", 0, 0)
  zeile2:SetJustifyH("LEFT")
end

local function Name(e) return e.name or ((QK:Quest(e.id) or {}).name) or ("Quest " .. e.id) end

local function Aufbau()
  local r = S:Auswerten()
  local teile = { (L"%d Quests"):format(r.quests), (L"%s EP"):format(Zahl(r.ep)) }
  if r.gold > 0 then teile[#teile + 1] = QK:GeldText(r.gold) end
  zeile1:SetText(table.concat(teile, " · "))
  local fav = r.lieblingsgebiet and QK:GebietName(r.lieblingsgebiet.id)
  local schnitt = (L"Im Schnitt %.1f Quests pro Spieltag"):format(r.schnitt)
  if not QK.englischUI then schnitt = schnitt:gsub("(%d)%.(%d)", "%1,%2") end
  zeile2:SetText(schnitt .. (fav and (" · " .. (L"Lieblingsgebiet: %s"):format(fav)) or ""))

  local eintraege = {}
  eintraege[#eintraege + 1] = { text = QK.gold .. L"Die letzten 14 Tage" .. "|r" }
  local max = 1
  local liste = {}
  for i = 0, TAGE - 1 do
    local zeit = time() - i * 86400
    local t = r.tage[date("%Y-%m-%d", zeit)] or { quests = 0, ep = 0 }
    liste[#liste + 1] = { zeit = zeit, t = t }
    if t.quests > max then max = t.quests end
  end
  for i, e in ipairs(liste) do
    eintraege[#eintraege + 1] = {
      text = (i == 1 and L"Heute" or (i == 2 and L"Gestern" or date("%d.%m.", e.zeit))),
      rechts = e.t.quests > 0 and ((L"%d Quests"):format(e.t.quests) .. " · " .. (L"%s EP"):format(Zahl(e.t.ep))) or "–",
      farbe = e.t.quests > 0 and QK.farben.hell or QK.farben.grau,
      anteil = e.t.quests / max,
    }
  end

  eintraege[#eintraege + 1] = { text = "" }
  eintraege[#eintraege + 1] = { text = QK.gold .. L"Rekorde" .. "|r" }
  local function rekord(text, rechts) eintraege[#eintraege + 1] = { text = text, rechts = rechts, farbe = QK.farben.hell } end
  if r.besterTag then
    local j, m, t = r.besterTag.tag:match("(%d+)-(%d+)-(%d+)")
    rekord(L"Bester Tag", ("%s.%s.%s · "):format(t, m, j) .. (L"%d Quests"):format(r.besterTag.quests))
  end
  if r.schnellste then rekord((L"Schnellste Quest: %s"):format(Name(r.schnellste)), QK:DauerText(r.schnellste.dauer)) end
  if r.laengste and r.laengste ~= r.schnellste then rekord((L"Längste Quest: %s"):format(Name(r.laengste)), QK:DauerText(r.laengste.dauer)) end
  if r.meisteEP and (r.meisteEP.ep or 0) > 0 then rekord((L"Meiste EP: %s"):format(Name(r.meisteEP)), QK:EPText(r.meisteEP.ep)) end
  if r.quests == 0 then eintraege[#eintraege + 1] = { text = L"Noch keine Quest abgegeben, seit Questkompass läuft.", farbe = QK.farben.grau } end
  QK.Gebiet.Zeichnen(eintraege)
end

QK.Gebiet:ReiterHinzufuegen("statistik", "Statistik", Aufbau, Kopf)

QK:Befehl({ "statistik", "stats" }, function() QK.Gebiet:Reiter("statistik") end, L"/qk statistik – Quests pro Tag und Rekorde")
