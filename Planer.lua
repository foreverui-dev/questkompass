-- Questkompass: Reiter „Planer“ im Questbuch. Stufenplaner, Questvorschläge,
-- Ruf-Übersicht, tägliche Quests und Vorschläge zum Aufräumen des Questlogs.
local _, QK = ...
local PL = QK:Modul("Planer")
local L = QK.L

-- EP bis zur nächsten Stufe (Classic-Werte). Gemessene Werte aus dem Spiel haben Vorrang.
local KLASSIK = {
  400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
  8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200,
  25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
  50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700,
  95800, 101000, 106300, 111800, 117500, 123200, 129100, 135100, 141200, 147500,
  153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}
local ALTE_TAGE = 7
local TAEGLICH = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily) or LE_QUEST_FREQUENCY_DAILY
local titel, zeile1, zeile2

local function Zahl(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n + 0.5)) or tostring(math.floor(n + 0.5)) end

function PL:MaxStufe()
  return (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or MAX_PLAYER_LEVEL or 60
end

function PL:EPFuer(stufe)
  return (QK.root.epTabelle and QK.root.epTabelle[stufe]) or KLASSIK[stufe]
end

local function Messen()
  local stufe, max = UnitLevel("player"), UnitXPMax("player")
  if stufe and max and max > 0 then QK.root.epTabelle[stufe] = max end
end

-- EP bis zur Zielstufe
function PL:Bedarf(ziel)
  local stufe = UnitLevel("player") or 1
  if ziel <= stufe then return 0 end
  local summe = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
  for s = stufe + 1, ziel - 1 do
    local ep = PL:EPFuer(s)
    if not ep then return nil end
    summe = summe + ep
  end
  return summe
end

-- Durchschnittliche EP einer Quest: aus dem Tagebuch, sonst aus dem Questlog
function PL:Schnitt()
  local buch, summe, n = QK.char.tagebuch, 0, 0
  for i = #buch, math.max(1, #buch - 19), -1 do
    if buch[i].ep and buch[i].ep > 0 then summe, n = summe + buch[i].ep, n + 1 end
  end
  if n >= 3 then return summe / n end
  for _, q in ipairs(QK.Compat:Questlog()) do
    if q.daten and q.daten.ep and q.daten.ep > 0 then summe, n = summe + q.daten.ep, n + 1 end
  end
  if n > 0 then return summe / n end
end

function PL:ProStunde()
  local s = QK.Gebiet.sitzung
  if not s.start then return nil end
  local dauer = GetTime() - s.start
  if dauer < 300 or s.ep <= 0 then return nil end
  return s.ep / dauer * 3600
end

function PL:Ziel()
  local stufe, max = UnitLevel("player") or 1, PL:MaxStufe()
  local z = QK.db.zielStufe
  if not z or z <= stufe then z = math.min(max, stufe + 1) end
  return math.min(z, max)
end

---------------------------------------------------------------------------
-- Abschnitte
---------------------------------------------------------------------------
local function Ueberschrift(eintraege, text)
  if #eintraege > 0 then eintraege[#eintraege + 1] = { text = "" } end
  eintraege[#eintraege + 1] = { text = QK.gold .. text .. "|r" }
end

-- Offene Quests in Gebieten, in denen du gerade unterwegs bist
function PL:Vorschlaege(anzahl)
  local gebiete, gesehen = {}, {}
  local function dazu(id) if id and not gesehen[id] then gesehen[id] = true; gebiete[#gebiete + 1] = id end end
  for _, id in ipairs(QK:GebieteHier()) do dazu(id) end
  for _, q in ipairs(QK.Compat:Questlog()) do dazu(q.gebiet) end
  local buch = QK.char.tagebuch
  for i = #buch, math.max(1, #buch - 9), -1 do local d = QK:Quest(buch[i].id); dazu(d and d.gebiet) end
  local liste = {}
  for _, id in ipairs(gebiete) do
    for _, q in ipairs(QK.Gebiet:Liste(id)) do
      if q.status == 2 then liste[#liste + 1] = q end
    end
  end
  table.sort(liste, function(a, b)
    if (a.ep or 0) ~= (b.ep or 0) then return (a.ep or 0) > (b.ep or 0) end
    return a.id < b.id
  end)
  while #liste > (anzahl or 12) do table.remove(liste) end
  return liste
end

-- Ruf aus Quests im Log: { fraktion, bereit, offen }
function PL:Ruf()
  local summen = {}
  for _, q in ipairs(QK.Compat:Questlog()) do
    local ruf = q.daten and q.daten.ruf
    if ruf then
      for i = 1, #ruf, 2 do
        local f = ruf[i]
        summen[f] = summen[f] or { fraktion = f, bereit = 0, offen = 0 }
        if q.fertig then summen[f].bereit = summen[f].bereit + ruf[i + 1] else summen[f].offen = summen[f].offen + ruf[i + 1] end
      end
    end
  end
  local liste = {}
  for _, s in pairs(summen) do liste[#liste + 1] = s end
  table.sort(liste, function(a, b) return a.bereit + a.offen > b.bereit + b.offen end)
  return liste
end

local function Ansehen(fraktion)
  if not GetFactionInfoByID then return nil end
  local ok, _, _, stufe = pcall(GetFactionInfoByID, fraktion)
  if ok and stufe then return _G["FACTION_STANDING_LABEL" .. stufe] end
end

-- Kandidaten zum Aufräumen: { quest, grund }
function PL:Aufraeumen()
  local liste, jetzt = {}, time()
  for _, q in ipairs(QK.Compat:Questlog()) do
    local seit = QK.char.angenommen[q.id]
    local grund
    if q.gescheitert then grund = L"gescheitert"
    elseif QK.Compat:IstGrau(q) and not q.fertig then grund = L"grau, bringt kaum noch EP"
    elseif seit and not q.fertig and jetzt - seit > ALTE_TAGE * 86400 then
      grund = (L"seit %d Tagen im Log"):format(math.floor((jetzt - seit) / 86400))
    end
    if grund then liste[#liste + 1] = { quest = q, grund = grund } end
  end
  return liste
end

local function Abbrechen(q)
  if not StaticPopupDialogs then return end
  StaticPopupDialogs.QUESTKOMPASS_ABBRECHEN = StaticPopupDialogs.QUESTKOMPASS_ABBRECHEN or {
    text = L"„%s“ wirklich abbrechen? Der Fortschritt geht verloren.",
    button1 = L"Abbrechen",
    button2 = L"Behalten",
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1, preferredIndex = 3,
    OnAccept = function(_, daten)
      QK.Compat:Abbrechen(daten)
      QK:Meldung(L"„%s“ abgebrochen.", daten.titel)
    end,
  }
  StaticPopup_Show("QUESTKOMPASS_ABBRECHEN", q.titel, nil, q)
end

---------------------------------------------------------------------------
-- Reiter
---------------------------------------------------------------------------
local function Kopf(k)
  titel = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  titel:SetPoint("TOPLEFT", 0, 0)
  titel:SetPoint("RIGHT", -90, 0)
  titel:SetJustifyH("LEFT")
  local function knopf(text, d)
    local b = CreateFrame("Button", nil, k, "UIPanelButtonTemplate")
    b:SetSize(28, 20)
    b:SetText(text)
    b:SetScript("OnClick", function()
      local stufe = UnitLevel("player") or 1
      QK.db.zielStufe = math.max(stufe + 1, math.min(PL:MaxStufe(), PL:Ziel() + d))
      QK.Gebiet:Aktualisieren()
    end)
    return b
  end
  local plus = knopf("+", 1)
  plus:SetPoint("TOPRIGHT", 0, 2)
  local minus = knopf("–", -1)
  minus:SetPoint("RIGHT", plus, "LEFT", -2, 0)
  zeile1 = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  zeile1:SetPoint("TOPLEFT", titel, "BOTTOMLEFT", 0, -6)
  zeile1:SetPoint("RIGHT", 0, 0)
  zeile1:SetJustifyH("LEFT")
  zeile2 = k:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zeile2:SetPoint("TOPLEFT", zeile1, "BOTTOMLEFT", 0, -4)
  zeile2:SetPoint("RIGHT", 0, 0)
  zeile2:SetJustifyH("LEFT")
  zeile2:SetSpacing(2)
end

local function KopfFuellen()
  local stufe, max = UnitLevel("player") or 1, PL:MaxStufe()
  if stufe >= max then
    titel:SetText(L"Höchststufe erreicht")
    zeile1:SetText(L"Glückwunsch! Der Planer zeigt dir weiter Vorschläge, Ruf und Aufräumtipps.")
    zeile2:SetText("")
    return
  end
  local ziel = PL:Ziel()
  titel:SetText((L"Ziel: Stufe %d"):format(ziel))
  local bedarf = PL:Bedarf(ziel)
  if not bedarf then
    zeile1:SetText(L"Für diese Stufen fehlen noch Erfahrungswerte.")
    zeile2:SetText("")
    return
  end
  local teile = { (L"Noch %s EP"):format(Zahl(bedarf)) }
  local schnitt = PL:Schnitt()
  if schnitt and schnitt > 0 then teile[#teile + 1] = (L"etwa %d Quests"):format(math.ceil(bedarf / schnitt)) end
  local proStunde = PL:ProStunde()
  if proStunde and proStunde > 0 then teile[#teile + 1] = (L"etwa %s Spielzeit"):format(QK:DauerText(bedarf / proStunde * 3600)) end
  zeile1:SetText(table.concat(teile, " · "))
  local imLog, bereit = 0, 0
  for _, q in ipairs(QK.Compat:Questlog()) do
    local ep = q.daten and q.daten.ep or 0
    imLog = imLog + ep
    if q.fertig then bereit = bereit + ep end
  end
  local text = (L"Quests im Log bringen %s EP, davon %s bereit zum Abgeben."):format(Zahl(imLog), Zahl(bereit))
  if proStunde then
    text = text .. "\n" .. (L"Dein Tempo in dieser Sitzung: %s EP pro Stunde."):format(Zahl(proStunde))
  else
    text = text .. "\n" .. L"Nach ein paar Minuten Spielzeit rechnet der Planer auch die Zeit aus."
  end
  zeile2:SetText(text)
end

local function Aufbau()
  KopfFuellen()
  local eintraege = {}

  -- Merkliste aus dem Questbuch (Rechtsklick auf offene Quests)
  local gemerkt = {}
  for id in pairs(QK.char.merkliste) do
    local q = QK:Quest(id)
    if q and not QK.Compat:IstErledigt(id) then q.status = 2; gemerkt[#gemerkt + 1] = q
    elseif not q or QK.Compat:IstErledigt(id) then QK.char.merkliste[id] = nil end
  end
  if #gemerkt > 0 then
    table.sort(gemerkt, function(a, b) return (a.name or "") < (b.name or "") end)
    Ueberschrift(eintraege, L"Deine Merkliste")
    for _, q in ipairs(gemerkt) do eintraege[#eintraege + 1] = QK.Gebiet.QuestEintrag(q, true) end
  end

  Ueberschrift(eintraege, L"Vorschläge in deiner Gegend")
  local vorschlaege = PL:Vorschlaege(12)
  for _, q in ipairs(vorschlaege) do eintraege[#eintraege + 1] = QK.Gebiet.QuestEintrag(q, true) end
  if #vorschlaege == 0 then eintraege[#eintraege + 1] = { text = L"Keine offenen Quests in der Nähe bekannt.", farbe = QK.farben.grau } end

  local ruf = PL:Ruf()
  if #ruf > 0 then
    Ueberschrift(eintraege, L"Ruf aus deinen Quests")
    for _, r in ipairs(ruf) do
      local ansehen = Ansehen(r.fraktion)
      local rechts = {}
      if r.bereit > 0 then rechts[#rechts + 1] = (L"+%d bereit"):format(r.bereit) end
      if r.offen > 0 then rechts[#rechts + 1] = (L"+%d offen"):format(r.offen) end
      eintraege[#eintraege + 1] = {
        text = QK:FraktionName(r.fraktion) .. (ansehen and (" |cff8c8c8c(" .. ansehen .. ")|r") or ""),
        rechts = table.concat(rechts, " · "),
        farbe = QK.farben.hell,
      }
    end
  end

  local taeglich = {}
  for _, q in ipairs(QK.Compat:Questlog()) do
    if TAEGLICH and q.haeufigkeit == TAEGLICH then taeglich[#taeglich + 1] = q end
  end
  local rest = QK:BisZuruecksetzen()
  if #taeglich > 0 or rest then
    Ueberschrift(eintraege, L"Tägliche Quests")
    if rest then
      eintraege[#eintraege + 1] = { text = (L"Zurücksetzen in %s"):format(QK:DauerText(rest)), farbe = QK.farben.grau }
    end
    for _, q in ipairs(taeglich) do
      eintraege[#eintraege + 1] = {
        text = q.titel, rechts = q.fertig and L"fertig" or L"offen",
        farbe = q.fertig and QK.farben.gruen or QK.farben.hell,
        klick = function() QK.Compat:FokusSetzen(q.id); QK:Anwenden() end,
      }
    end
    if #taeglich == 0 then eintraege[#eintraege + 1] = { text = L"Keine täglichen Quests im Log.", farbe = QK.farben.grau } end
  end

  local alt = PL:Aufraeumen()
  Ueberschrift(eintraege, L"Questlog aufräumen")
  if #alt == 0 then
    eintraege[#eintraege + 1] = { text = L"Alles ordentlich, nichts zum Aufräumen.", farbe = QK.farben.grau }
  else
    for _, a in ipairs(alt) do
      eintraege[#eintraege + 1] = {
        text = a.quest.titel .. " |cff8c8c8c· " .. a.grund .. "|r",
        rechts = L"abbrechen…", farbe = QK.farben.hell,
        tipp = { a.quest.titel, a.grund, L"Klick: Quest abbrechen (mit Rückfrage)" },
        klick = function() Abbrechen(a.quest) end,
      }
    end
  end
  QK.Gebiet.Zeichnen(eintraege)
end

QK.Gebiet:ReiterHinzufuegen("planer", L"Planer", Aufbau, Kopf)

function PL:Start()
  Messen()
  QK:Ereignis("PLAYER_LEVEL_UP", function() C_Timer.After(1, Messen) end)
  QK:Ereignis("QUEST_ACCEPTED", function(a, b)
    local id = (b and b > 0 and b) or a
    if id then QK.char.angenommen[id] = time() end
  end)
  QK:Ereignis("QUEST_TURNED_IN", function(id) if id then QK.char.angenommen[id] = nil; QK.char.geschaetzt[id] = nil end end)
  -- Quests, die schon vor 0.5 im Log standen, zählen ab heute
  local jetzt = time()
  for _, q in ipairs(QK.Compat:Questlog()) do
    if not QK.char.angenommen[q.id] then QK.char.angenommen[q.id] = jetzt; QK.char.geschaetzt[q.id] = true end
  end
end

QK:Befehl({ "planer" }, function() QK.Gebiet:Reiter("planer") end, L"/qk planer – Stufenplaner, Vorschläge, Ruf und Aufräumen")
QK:Befehl({ "aufraeumen", "aufräumen" }, function() QK.Gebiet:Reiter("planer") end)
QK.tasten.planer = function() QK.Gebiet:Reiter("planer") end
