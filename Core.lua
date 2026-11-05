-- Questkompass: Grundgerüst, Einstellungen, Fehlerprotokoll, Ereignisse und Befehle.
local ADDON, QK = ...
_G.Questkompass = QK

local metadaten = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
QK.version = (metadaten and metadaten(ADDON, "Version")) or "dev"
if QK.version:find("@") then QK.version = "dev" end

QK.farben = {
  gold   = { 0.95, 0.77, 0.35 },
  hell   = { 0.93, 0.91, 0.86 },
  grau   = { 0.55, 0.55, 0.55 },
  gruen  = { 0.45, 0.85, 0.45 },
  rot    = { 0.90, 0.35, 0.30 },
  balken = { 0.95, 0.70, 0.25 },
}
QK.gold = "|cfff2c45a"

QK.STANDARD = {
  eingerichtet = false,     -- Assistent schon durchlaufen?
  stil = "ruhig",           -- ruhig | klassisch | kompakt
  lage = "minimap",         -- minimap | rechts | links | frei
  pos = nil,                -- bei lage = frei: { punkt, relPunkt, x, y }
  gesperrt = false,
  modus = "alle",           -- alle | verfolgt
  sortierung = "entfernung",-- entfernung | zone | log
  anzahl = 8,
  breite = 240,
  skalierung = 1,
  ruhemodus = true,
  ruheAlpha = 0.35,
  blizzardAusblenden = true,
  pfeil = true,             -- Kompasspfeil an jeder Quest
  meldungen = true,         -- Fortschritt in der Bildschirmmitte
  klang = true,             -- Klang bei fertiger Quest
  autoAnnehmen = false,
  autoAbgeben = false,
  belohnungsTipp = true,
  minimapKnopf = true,
  minimapWinkel = 200,
  gebietPos = nil,
  versteckt = false,
}

QK.STILE = {
  ruhig     = { name = "Ruhig",     hintergrund = 0.55, balken = true,  schrift = "normal", nurNaechstes = false, anzahl = 8 },
  klassisch = { name = "Klassisch", hintergrund = 0,    balken = false, schrift = "gross",  nurNaechstes = false, anzahl = 10 },
  kompakt   = { name = "Kompakt",   hintergrund = 0.35, balken = true,  schrift = "klein",  nurNaechstes = true,  anzahl = 12 },
}

local function kopie(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, w in pairs(v) do t[k] = kopie(w) end
  return t
end
QK.Kopie = kopie

function QK:Standardwerte(ziel)
  for k, v in pairs(self.STANDARD) do
    if ziel[k] == nil then ziel[k] = kopie(v) end
  end
end

function QK:Stil()
  return self.STILE[self.db.stil] or self.STILE.ruhig
end

function QK:Meldung(text, ...)
  DEFAULT_CHAT_FRAME:AddMessage(QK.gold .. "Questkompass:|r " .. (select("#", ...) > 0 and text:format(...) or text))
end

---------------------------------------------------------------------------
-- Fehlerprotokoll: Fehler im Addon sollen nie die Oberfläche lahmlegen.
---------------------------------------------------------------------------
local gemeldet = false
function QK:Sicher(name, fn, ...)
  local ok, fehler = pcall(fn, ...)
  if not ok then
    local db = QuestkompassDB
    if db then
      db.fehler = db.fehler or {}
      local eintrag = ("%s: %s"):format(name, tostring(fehler))
      if db.fehler[#db.fehler] ~= eintrag then
        table.insert(db.fehler, eintrag)
        while #db.fehler > 20 do table.remove(db.fehler, 1) end
      end
    end
    if not gemeldet then
      gemeldet = true
      QK:Meldung("|cffe05a4dEin Fehler ist aufgetreten (%s).|r /qk fehler zeigt Details.", name)
    end
  end
  return ok
end

---------------------------------------------------------------------------
-- Ereignisse: Module melden sich mit QK:Ereignis(name, funktion) an.
---------------------------------------------------------------------------
local verteiler = CreateFrame("Frame")
local empfaenger = {}
function QK:Ereignis(ereignis, fn)
  if not empfaenger[ereignis] then
    empfaenger[ereignis] = {}
    pcall(verteiler.RegisterEvent, verteiler, ereignis)
  end
  table.insert(empfaenger[ereignis], fn)
end
verteiler:SetScript("OnEvent", function(_, ereignis, ...)
  for _, fn in ipairs(empfaenger[ereignis] or {}) do
    QK:Sicher(ereignis, fn, ...)
  end
end)

QK.module = {}
function QK:Modul(name)
  local m = { name = name }
  self.module[#self.module + 1] = m
  QK[name] = m
  return m
end

-- Alle Module neu zeichnen (nach Änderungen in Assistent oder Einstellungen).
function QK:Anwenden()
  for _, m in ipairs(self.module) do
    if m.Anwenden then QK:Sicher(m.name, m.Anwenden, m) end
  end
end

QK:Ereignis("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  QuestkompassDB = QuestkompassDB or {}
  QuestkompassCharDB = QuestkompassCharDB or {}
  QK:Standardwerte(QuestkompassDB)
  QuestkompassCharDB.ausgeblendet = QuestkompassCharDB.ausgeblendet or {}
  QK.db = QuestkompassDB
  QK.char = QuestkompassCharDB
end)

QK:Ereignis("PLAYER_LOGIN", function()
  if QK.Compat then QK:Sicher("Diagnose", QK.Compat.Diagnose, QK.Compat) end
  for _, m in ipairs(QK.module) do
    if m.Start then QK:Sicher(m.name, m.Start, m) end
  end
  if not QK.db.eingerichtet and QK.Assistent then
    C_Timer.After(2, function() QK:Sicher("Assistent", QK.Assistent.Oeffnen, QK.Assistent, 1) end)
  end
end)

---------------------------------------------------------------------------
-- Questdaten aus der Blizzard-API (Daten/Quests.lua)
---------------------------------------------------------------------------
local englisch = GetLocale() ~= "deDE"

local function lokal(paar)
  if not paar then return nil end
  local s = englisch and paar[2] or paar[1]
  if s == "" then s = paar[1] ~= "" and paar[1] or paar[2] end
  return s
end
QK.Lokal = lokal

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

function QK:GebietName(id) return id and lokal(self.gebiete[id]) end
function QK:TypName(id) return id and lokal(self.typen[id]) end
function QK:FraktionName(id) return lokal(self.fraktionen[id]) or ("#" .. id) end

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

-- Liefert die Menge der Gebiets-IDs, in denen der Charakter steht, plus Teil- und Hauptgebiet.
function QK:AktuelleGebiete()
  local zone = self:GebietZuName(GetRealZoneText and GetRealZoneText()) or self:GebietZuName(GetZoneText and GetZoneText())
  local teil = GetSubZoneText and self:GebietZuName(GetSubZoneText()) or nil
  local menge = {}
  if zone then menge[zone] = true end
  if teil then menge[teil] = true end
  return menge, teil, zone
end

-- Gehört eine Quest aus dem Log zur Gegend, in der der Charakter steht?
-- Zählt das Questgebiet aus den Daten oder die Überschrift im Questlog.
function QK:IstHier(q, hier)
  if q.gebiet and hier[q.gebiet] then return true end
  local zone = GetRealZoneText and GetRealZoneText()
  return q.zone ~= nil and (q.zone == zone or q.zone == (GetSubZoneText and GetSubZoneText()))
end

-- Gebiete, die gerade in Frage kommen: Zone, Teilzone und Gebiete der Quests unter der Zonenüberschrift.
function QK:GebieteHier()
  local menge, teil, zone = self:AktuelleGebiete()
  local liste, gesehen = {}, {}
  local function dazu(id) if id and not gesehen[id] then gesehen[id] = true; liste[#liste + 1] = id end end
  dazu(teil); dazu(zone)
  for _, q in ipairs(self.Compat:Questlog()) do
    if self:IstHier(q, menge) then dazu(q.gebiet) end
  end
  return liste
end

-- Teilgebiete mit eigenen Quests (z. B. Nordhaintal in Elwynn) haben Vorrang.
function QK:AktuellesGebiet()
  local _, teil, zone = self:AktuelleGebiete()
  return teil or zone
end

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

function QK:EPText(ep)
  if not ep or ep <= 0 then return nil end
  return (BreakUpLargeNumbers and BreakUpLargeNumbers(ep) or tostring(ep)) .. " EP"
end

-- Entfernung in Yards als lesbarer Text in Metern.
function QK:EntfernungText(yards)
  if not yards then return nil end
  local m = yards * 0.9144
  if m >= 1000 then return (("%.1f km"):format(m / 1000):gsub("%.", ",")) end
  if m >= 100 then return ("%d m"):format(math.floor(m / 10 + 0.5) * 10) end
  return ("%d m"):format(math.floor(m + 0.5))
end

---------------------------------------------------------------------------
-- Befehle
---------------------------------------------------------------------------
local HILFE = {
  "/qk – Zielliste ein- oder ausblenden",
  "/qk einstellungen – alle Einstellungen",
  "/qk einrichten – Einrichtungsassistent erneut starten",
  "/qk gebiet [Name] – Gebietsfortschritt",
  "/qk fokus – Fokus-Quest aufheben",
  "/qk einblenden – ausgeblendete Quests wieder zeigen",
  "/qk zuruecksetzen – alles auf Anfang",
  "/qk diagnose | fehler – technische Infos für Fehlerberichte",
}

SLASH_QUESTKOMPASS1 = "/qk"
SLASH_QUESTKOMPASS2 = "/questkompass"
SlashCmdList.QUESTKOMPASS = function(eingabe)
  local befehl, rest = (eingabe or ""):match("^%s*(%S*)%s*(.-)%s*$")
  befehl = befehl:lower()
  local db = QK.db
  if befehl == "" then
    db.versteckt = not db.versteckt
    QK:Anwenden()
  elseif befehl == "hilfe" or befehl == "help" or befehl == "?" then
    QK:Meldung("Version %s, Questdaten vom %s", QK.version, QK.datenStand or "?")
    for _, zeile in ipairs(HILFE) do DEFAULT_CHAT_FRAME:AddMessage("  " .. zeile) end
  elseif befehl == "einstellungen" or befehl == "optionen" or befehl == "config" then
    QK.Assistent:Oeffnen(2, true)
  elseif befehl == "einrichten" or befehl == "assistent" then
    QK.Assistent:Oeffnen(1)
  elseif befehl == "gebiet" or befehl == "zone" then
    QK.Gebiet:Zeigen(rest ~= "" and rest or nil)
  elseif befehl == "fokus" then
    QK.Compat:FokusSetzen(nil)
    QK:Anwenden()
    QK:Meldung("Fokus aufgehoben.")
  elseif befehl == "einblenden" then
    wipe(QK.char.ausgeblendet)
    QK:Anwenden()
    QK:Meldung("alle Quests sind wieder sichtbar.")
  elseif befehl == "zuruecksetzen" or befehl == "reset" then
    local diag, fehler = db.diagnose, db.fehler
    wipe(db)
    QK:Standardwerte(db)
    db.diagnose, db.fehler, db.eingerichtet = diag, fehler, true
    QK:Anwenden()
    QK:Meldung("Einstellungen zurückgesetzt. /qk einrichten startet den Assistenten.")
  elseif befehl == "diagnose" then
    QK.Compat:Diagnose(true)
  elseif befehl == "fehler" then
    if not db.fehler or #db.fehler == 0 then
      QK:Meldung("keine Fehler aufgezeichnet.")
    else
      QK:Meldung("die letzten %d Fehler:", #db.fehler)
      for _, f in ipairs(db.fehler) do DEFAULT_CHAT_FRAME:AddMessage("  " .. f) end
    end
  else
    QK:Meldung("unbekannter Befehl. /qk hilfe zeigt alle Befehle.")
  end
end
