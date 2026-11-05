-- Questkompass: Meilensteine. Eigener Reiter im Questbuch und eine Meldung, wenn einer erreicht ist.
local _, QK = ...
local E = QK:Modul("Erfolge")
local L = QK.L

local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
local titel, unter, balken, balkenText
local stand                 -- zwischengespeicherte Zählungen

local function Zaehlen()
  local s = { erledigt = 0, dungeon = 0, elite = 0, gebiete = 0, heute = 0 }
  local ich = QK.Twinks and QK.Twinks:Ich()
  local menge = ich and ich.erledigt or QK.Compat:Erledigte()
  for id in pairs(menge) do
    s.erledigt = s.erledigt + 1
    local roh = QK.quests[id]
    if roh then
      if roh[4] == 81 then s.dungeon = s.dungeon + 1 elseif roh[4] == 1 then s.elite = s.elite + 1 end
    end
  end
  for _, w in ipairs(QK.Gebiet:Welt()) do
    if w.gesamt >= 5 and w.erledigt >= w.gesamt then s.gebiete = s.gebiete + 1 end
  end
  local heute = date("%Y-%m-%d")
  for _, e in ipairs(QK.char.tagebuch) do
    if date("%Y-%m-%d", e.zeit) == heute then s.heute = s.heute + 1 end
  end
  s.tagebuch = #QK.char.tagebuch
  local n = 0
  for _ in pairs(QK.root.charaktere or {}) do n = n + 1 end
  s.charaktere = n
  s.routen = QK.char.routenGeschafft or 0
  return s
end

local function Stufen(id, name, text, schluessel, werte)
  local liste = {}
  for _, w in ipairs(werte) do
    liste[#liste + 1] = { id = id .. w[1], name = w[2], text = text:format(w[1]), schluessel = schluessel, soll = w[1] }
  end
  return liste
end

local LISTE = {}
local function dazu(t) for _, e in ipairs(t) do LISTE[#LISTE + 1] = e end end
dazu(Stufen("quests", nil, L"%d Quests erledigt", "erledigt", {
  { 10, L"Erste Schritte" }, { 50, L"Abenteurer" }, { 100, L"Hundert Aufträge" },
  { 250, L"Viel unterwegs" }, { 500, L"Held der Gegend" }, { 1000, L"Legende" } }))
dazu(Stufen("gebiet", nil, L"%d Gebiete komplett", "gebiete", {
  { 1, L"Gebiet komplett" }, { 5, L"Gründlich" }, { 10, L"Kartograf" } }))
dazu(Stufen("dungeon", nil, L"%d Dungeon-Quests erledigt", "dungeon", {
  { 1, L"Erster Dungeon" }, { 10, L"Dungeonkenner" } }))
dazu(Stufen("elite", nil, L"%d Elitequests erledigt", "elite", {
  { 1, L"Elite!" }, { 25, L"Zäher Brocken" } }))
dazu(Stufen("tag", nil, L"%d Quests an einem Tag", "heute", { { 10, L"Fleißiger Tag" }, { 30, L"Questmarathon" } }))
dazu(Stufen("buch", nil, L"%d Quests im Tagebuch", "tagebuch", { { 100, L"Tagebuchschreiber" } }))
dazu(Stufen("route", nil, L"%d Routen geschafft", "routen", { { 1, L"Navigator" }, { 10, L"Routenprofi" } }))
dazu(Stufen("twink", nil, L"%d Charaktere mit Questkompass", "charaktere", { { 3, L"Twink-Familie" } }))
E.LISTE = LISTE

-- Prüft alle Meilensteine; neue werden gemeldet (außer beim allerersten Durchlauf).
function E:Pruefen(still)
  stand = Zaehlen()
  local erfolge = QK.char.erfolge
  local erster = not QK.char.erfolgeStart
  QK.char.erfolgeStart = QK.char.erfolgeStart or time()
  for _, m in ipairs(LISTE) do
    if not erfolge[m.id] and (stand[m.schluessel] or 0) >= m.soll then
      erfolge[m.id] = time()
      if not erster and not still and QK.db.erfolgMeldungen and QK.Meldungen then
        QK.Meldungen:Zeigen(L"MEILENSTEIN", m.name .. " · " .. m.text)
        if QK.db.klang then pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 31578) end
      end
    end
  end
  return stand
end

local function Kopf(k)
  titel = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  titel:SetPoint("TOPLEFT")
  titel:SetText(L"Meilensteine")
  unter = k:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  unter:SetPoint("TOPLEFT", titel, "BOTTOMLEFT", 0, -4)
  unter:SetText(L"Abzeichen für deine Questreise.")
  balken = CreateFrame("StatusBar", nil, k)
  balken:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  balken:SetPoint("TOPLEFT", 0, -46)
  balken:SetPoint("TOPRIGHT", 0, -46)
  balken:SetHeight(14)
  local hg = balken:CreateTexture(nil, "BACKGROUND")
  hg:SetAllPoints()
  hg:SetColorTexture(1, 1, 1, 0.08)
  balkenText = balken:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  balkenText:SetPoint("CENTER")
end

local function Aufbau()
  local s = E:Pruefen()
  local erfolge = QK.char.erfolge
  local eintraege, geschafft = {}, 0
  for _, m in ipairs(LISTE) do
    local wann = erfolge[m.id]
    local ist = math.min(s[m.schluessel] or 0, m.soll)
    if wann then geschafft = geschafft + 1 end
    eintraege[#eintraege + 1] = {
      symbol = wann and HAKEN or "",
      text = m.name .. " |cff8c8c8c· " .. m.text .. "|r",
      rechts = wann and date("%d.%m.%Y", wann) or ("%d/%d"):format(ist, m.soll),
      farbe = wann and QK.farben.gold or QK.farben.hell,
      anteil = not wann and ist / m.soll or nil,
      tipp = { m.name, m.text, wann and ((L"Erreicht am %s"):format(date("%d.%m.%Y", wann))) or ((L"Stand: %d von %d"):format(ist, m.soll)) },
    }
  end
  -- erreichte nach oben
  table.sort(eintraege, function(a, b)
    if (a.symbol ~= "") ~= (b.symbol ~= "") then return a.symbol ~= "" end
    return (a.anteil or 0) > (b.anteil or 0)
  end)
  balken:SetMinMaxValues(0, #LISTE)
  balken:SetValue(geschafft)
  balken:SetStatusBarColor(unpack(QK.farben.balken))
  balkenText:SetText((L"%d von %d erreicht"):format(geschafft, #LISTE))
  QK.Gebiet.Zeichnen(eintraege)
end

QK.Gebiet:ReiterHinzufuegen("erfolge", L"Erfolge", Aufbau, Kopf)

function E:Start()
  C_Timer.After(8, function() QK:Sicher("Meilensteine", E.Pruefen, E) end)
  QK:Ereignis("QUEST_TURNED_IN", function()
    C_Timer.After(1.5, function() QK:Sicher("Meilensteine", E.Pruefen, E) end)
  end)
end

QK:Befehl({ "erfolge", "meilensteine" }, function() QK.Gebiet:Reiter("erfolge") end, L"/qk erfolge – Meilensteine")
