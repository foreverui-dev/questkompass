-- Questkompass: Grundgerüst, Einstellungen, Questdaten-Helfer und Befehle.
local ADDON, QK = ...
_G.Questkompass = QK

QK.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "dev"
if QK.version:find("@") then QK.version = "dev" end

QK.farben = {
  gold   = { 0.95, 0.77, 0.35 },
  hell   = { 0.93, 0.91, 0.86 },
  grau   = { 0.55, 0.55, 0.55 },
  gruen  = { 0.45, 0.85, 0.45 },
  balken = { 0.95, 0.70, 0.25 },
}
QK.gold = "|cfff2c45a"

local STANDARD = {
  pos = { "TOPRIGHT", "Minimap", "BOTTOMRIGHT", 0, -28 },
  gesperrt = false,
  modus = "alle",          -- "alle" oder "verfolgt"
  anzahl = 8,
  ruhemodus = true,
  ruheAlpha = 0.35,
  blizzardAusblenden = true,
  breite = 230,
  skalierung = 1,
  gebietPos = nil,
}

local function fuelle(ziel, vorlage)
  for k, v in pairs(vorlage) do
    if ziel[k] == nil then
      ziel[k] = type(v) == "table" and CopyTable(v) or v
    end
  end
end

function QK:Meldung(text, ...)
  DEFAULT_CHAT_FRAME:AddMessage(QK.gold .. "Questkompass:|r " .. text:format(...))
end

---------------------------------------------------------------------------
-- Questdaten
---------------------------------------------------------------------------
local englisch = GetLocale() ~= "deDE"

local function lokal(paar)
  if not paar then return nil end
  local s = englisch and paar[2] or paar[1]
  if s == "" then s = paar[1] ~= "" and paar[1] or paar[2] end
  return s
end
QK.Lokal = lokal

-- Liefert eine aufbereitete Tabelle zu einer Quest-ID oder nil.
function QK:Quest(id)
  local q = id and self.quests and self.quests[id]
  if not q then return nil end
  return {
    id = id,
    gebiet = q[1] ~= 0 and q[1] or nil,
    kategorie = q[2] ~= 0 and q[2] or nil,
    fraktion = q[3] ~= "" and q[3] or nil,
    typ = q[4] ~= 0 and q[4] or nil,
    ep = q[5],
    name = lokal(q[6]),
    klassen = q[7],
    voelker = q[8],
    ruf = q[9],
  }
end

-- Quest-IDs je Gebiet, einmalig aufgebaut.
function QK:QuestsImGebiet(id)
  if not self.gebietQuests then
    self.gebietQuests = {}
    for qid, q in pairs(self.quests) do
      local g = q[1]
      if g ~= 0 then
        local l = self.gebietQuests[g]
        if not l then l = {}; self.gebietQuests[g] = l end
        l[#l + 1] = qid
      end
    end
  end
  return self.gebietQuests[id] or {}
end

function QK:GebietName(id) return lokal(self.gebiete[id]) end
function QK:TypName(id) return id and lokal(self.typen[id]) end
function QK:FraktionName(id) return lokal(self.fraktionen[id]) or ("#" .. id) end

-- Gebiets-ID zu einem Zonennamen (deutsch oder englisch).
function QK:GebietZuName(name)
  if not name or name == "" then return nil end
  if not self.gebietIndex then
    self.gebietIndex = {}
    for id, paar in pairs(self.gebiete) do
      for _, n in ipairs(paar) do
        if n ~= "" then self.gebietIndex[n:lower()] = id end
      end
    end
  end
  return self.gebietIndex[name:lower()]
end

-- Teilgebiete mit eigenen Quests (z. B. Nordhaintal in Elwynn) haben Vorrang.
function QK:AktuellesGebiet()
  local _, teil, zone = self:AktuelleGebiete()
  return teil or zone
end

-- Liefert eine Menge der Gebiets-IDs, in denen der Charakter gerade steht.
function QK:AktuelleGebiete()
  local zone = self:GebietZuName(GetRealZoneText()) or self:GebietZuName(GetZoneText())
  local teil = GetSubZoneText and self:GebietZuName(GetSubZoneText()) or nil
  local menge = {}
  if zone then menge[zone] = true end
  if teil then menge[teil] = true end
  return menge, teil, zone
end

-- Passt eine Quest zu Fraktion, Klasse und Volk des Charakters?
function QK:PasstZumCharakter(q)
  if q.fraktion then
    local f = UnitFactionGroup("player")
    if (q.fraktion == "A" and f ~= "Alliance") or (q.fraktion == "H" and f ~= "Horde") then
      return false
    end
  end
  if q.klassen and q.klassen > 0 then
    local _, _, klasse = UnitClass("player")
    if klasse and bit.band(q.klassen, bit.lshift(1, klasse - 1)) == 0 then return false end
  end
  if q.voelker and q.voelker > 0 then
    local _, _, volk = UnitRace("player")
    if volk and bit.band(q.voelker, bit.lshift(1, volk - 1)) == 0 then return false end
  end
  return true
end

function QK:IstErledigt(id)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    return C_QuestLog.IsQuestFlaggedCompleted(id)
  elseif IsQuestFlaggedCompleted then
    return IsQuestFlaggedCompleted(id)
  end
  return false
end

function QK:EPText(ep)
  if not ep or ep <= 0 then return nil end
  return (BreakUpLargeNumbers and BreakUpLargeNumbers(ep) or tostring(ep)) .. " EP"
end

---------------------------------------------------------------------------
-- Questlog lesen (Classic-Questlog-API)
---------------------------------------------------------------------------
local function ziele(index, questID)
  local liste = {}
  local anzahl = GetNumQuestLeaderBoards(index) or 0
  for j = 1, anzahl do
    local text, art, fertig = GetQuestLogLeaderBoard(j, index)
    if text then
      local name, ist, soll = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
      liste[#liste + 1] = {
        text = name or text,
        ist = tonumber(ist),
        soll = tonumber(soll),
        fertig = fertig and true or false,
        art = art,
      }
    end
  end
  return liste
end

-- Gibt alle Quests im Questlog zurück, jeweils mit Zone (Überschrift) und Zielen.
function QK:Questlog()
  local quests = {}
  local zone
  local n = GetNumQuestLogEntries() or 0
  for i = 1, n do
    local titel, stufe, gruppe, istUeberschrift, _, fertig, _, questID = GetQuestLogTitle(i)
    if istUeberschrift then
      zone = titel
    elseif titel then
      local daten = self:Quest(questID)
      quests[#quests + 1] = {
        index = i,
        id = questID,
        titel = titel,
        stufe = stufe,
        gruppe = gruppe,
        zone = zone,
        gebiet = (daten and daten.gebiet) or self:GebietZuName(zone),
        fertig = fertig == 1 or fertig == true,
        gescheitert = fertig == -1,
        verfolgt = IsQuestWatched and IsQuestWatched(i) or false,
        ziele = ziele(i, questID),
        daten = daten,
      }
    end
  end
  return quests
end

---------------------------------------------------------------------------
-- Start und Befehle
---------------------------------------------------------------------------
local ereignisse = CreateFrame("Frame")
ereignisse:RegisterEvent("ADDON_LOADED")
ereignisse:RegisterEvent("PLAYER_LOGIN")
ereignisse:SetScript("OnEvent", function(_, ereignis, name)
  if ereignis == "ADDON_LOADED" and name == ADDON then
    QuestkompassDB = QuestkompassDB or {}
    QuestkompassCharDB = QuestkompassCharDB or {}
    fuelle(QuestkompassDB, STANDARD)
    QuestkompassCharDB.ausgeblendet = QuestkompassCharDB.ausgeblendet or {}
    QK.db = QuestkompassDB
    QK.char = QuestkompassCharDB
  elseif ereignis == "PLAYER_LOGIN" then
    if QK.Tracker then QK.Tracker:Start() end
    if QK.Gebiet then QK.Gebiet:Start() end
    if QK.Tooltip then QK.Tooltip:Start() end
  end
end)

local HILFE = {
  "/qk – Zielliste ein- oder ausblenden",
  "/qk gebiet [Name] – Gebietsfortschritt (aktuelle Zone oder Name)",
  "/qk alle | verfolgt – alle Quests oder nur verfolgte zeigen",
  "/qk anzahl <1-25> – wie viele Quests die Liste zeigt",
  "/qk sperren | entsperren – Liste fixieren oder verschiebbar machen",
  "/qk ruhe – Ruhemodus im Kampf an/aus",
  "/qk blizzard – Blizzard-Questverfolgung zeigen/ausblenden",
  "/qk breite <160-400> | groesse <50-200> – Breite in Pixeln, Größe in Prozent",
  "/qk einblenden – ausgeblendete Quests wieder zeigen",
  "/qk zuruecksetzen – Position und Einstellungen zurücksetzen",
}

SLASH_QUESTKOMPASS1 = "/qk"
SLASH_QUESTKOMPASS2 = "/questkompass"
SlashCmdList.QUESTKOMPASS = function(eingabe)
  local befehl, rest = (eingabe or ""):match("^%s*(%S*)%s*(.-)%s*$")
  befehl = befehl:lower()
  local db, T = QK.db, QK.Tracker
  if befehl == "" then
    T:Umschalten()
  elseif befehl == "hilfe" or befehl == "help" or befehl == "?" then
    QK:Meldung("Version %s, Daten vom %s", QK.version, QK.datenStand or "?")
    for _, zeile in ipairs(HILFE) do DEFAULT_CHAT_FRAME:AddMessage("  " .. zeile) end
  elseif befehl == "gebiet" or befehl == "zone" then
    QK.Gebiet:Zeigen(rest ~= "" and rest or nil)
  elseif befehl == "alle" or befehl == "verfolgt" then
    db.modus = befehl
    QK:Meldung(befehl == "alle" and "zeige alle Quests im Log." or "zeige nur verfolgte Quests.")
    T:Aktualisieren()
  elseif befehl == "anzahl" then
    local n = tonumber(rest)
    if n and n >= 1 and n <= 25 then
      db.anzahl = math.floor(n)
      T:Aktualisieren()
      QK:Meldung("zeige bis zu %d Quests.", db.anzahl)
    else
      QK:Meldung("bitte eine Zahl von 1 bis 25 angeben.")
    end
  elseif befehl == "sperren" or befehl == "entsperren" then
    db.gesperrt = befehl == "sperren"
    T:Sperre()
    QK:Meldung(db.gesperrt and "Liste ist fixiert." or "Liste lässt sich mit der Maus verschieben.")
  elseif befehl == "ruhe" then
    db.ruhemodus = not db.ruhemodus
    T:Ruhe(InCombatLockdown())
    QK:Meldung("Ruhemodus im Kampf ist %s.", db.ruhemodus and "an" or "aus")
  elseif befehl == "blizzard" then
    db.blizzardAusblenden = not db.blizzardAusblenden
    T:BlizzardTracker()
    QK:Meldung("Blizzard-Questverfolgung ist %s.", db.blizzardAusblenden and "ausgeblendet" or "sichtbar")
  elseif befehl == "breite" then
    local n = tonumber(rest)
    if n and n >= 160 and n <= 400 then db.breite = math.floor(n); T:Aktualisieren()
    else QK:Meldung("bitte eine Breite von 160 bis 400 angeben.") end
  elseif befehl == "groesse" or befehl == "größe" then
    local n = tonumber(rest)
    if n and n >= 50 and n <= 200 then db.skalierung = n / 100; T:Skalieren()
    else QK:Meldung("bitte eine Größe von 50 bis 200 (Prozent) angeben.") end
  elseif befehl == "einblenden" then
    wipe(QK.char.ausgeblendet)
    T:Aktualisieren()
    QK:Meldung("alle Quests sind wieder sichtbar.")
  elseif befehl == "zuruecksetzen" or befehl == "reset" then
    wipe(QuestkompassDB)
    fuelle(QuestkompassDB, STANDARD)
    T:Positionieren()
    T:Sperre()
    T:Skalieren()
    T:BlizzardTracker()
    T:Aktualisieren()
    QK:Meldung("Einstellungen zurückgesetzt.")
  else
    QK:Meldung("unbekannter Befehl. /qk hilfe zeigt alle Befehle.")
  end
end
