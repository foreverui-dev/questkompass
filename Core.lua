-- Questkompass: Grundgerüst, Einstellungen, Fehlerprotokoll, Ereignisse und Befehle.
local ADDON, QK = ...
_G.Questkompass = QK
local L = QK.L

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
  -- 0.3
  akzent = "gold",          -- gold | klasse | eis | smaragd
  pfeilGross = true,        -- schwebender Fokuspfeil
  pfeilPos = nil,
  autoFokus = false,        -- nächstgelegene Quest automatisch als Fokus
  questItems = true,        -- Knopf für Questgegenstände
  gruppen = false,          -- Zonenüberschriften in der Liste
  mitspieler = true,        -- Gruppenmitglieder mit derselben Quest
  graueAusblenden = false,
  epVorschau = true,
  logWarnung = true,
  gruppenMeldungen = false,
  neuMarkierung = true,
  -- 0.4 Barrierefreiheit
  vorlesen = false,         -- Sprachausgabe des Spiels
  kontrast = false,
  farbenblind = false,
  allesGroesser = false,    -- Fenster, Pfeil und Meldungen um 25 % größer
  wenigerBewegung = false,
  -- 0.5
  mouseover = false,        -- Liste nur bei Maus oder Änderung sichtbar
  instanzModus = true,      -- in Dungeons nur passende Quests
  kampfNurFokus = false,    -- im Kampf nur die Fokus-Quest
  minimapPfeil = true,      -- Pfeil am Minikartenrand
  abgabeErinnerung = true,
  goldVorschau = true,
  belohnungsVergleich = true,
  taeglichZeile = true,
  gruppenAbgleich = true,
  notizenZeigen = true,
  zielStufe = nil,          -- Stufenplaner
  erfolgMeldungen = true,   -- Meldung bei neuem Meilenstein
  twinks = true,            -- Twink-Hilfe in Tooltip und Questbuch
  sprache = "auto",         -- auto | de | en
  -- 0.6
  fokusModus = false,       -- Liste zeigt nur die Fokus-Quest
  zielSymbole = true,       -- Symbol je Zielart
  fertigKompakt = false,    -- fertige Quests nur als Titel mit Haken
  prozent = false,          -- Fortschritt je Quest in Prozent
  erholung = true,          -- Erholungsbonus in der EP-Zeile
  tooltipZiele = true,      -- Questziele in Gegner- und Gegenstands-Tooltips
  tagesziel = 0,            -- Quests pro Tag (0 = aus)
  autoTeilen = false,       -- neue Quests in der Gruppe teilen
  questPlaketten = true,    -- Symbol an Quest-Gegnern (Namensplakette)
  questGegenstaende = true, -- am Gegenstand zeigen, für welche Quests er gebraucht wird
  zeitWarnung = true,       -- Warnung vor Ablauf von Zeitlimits
}

-- Seite, mit der das Einstellungsfenster öffnet (1 = Willkommen, 2 = Barrierefreiheit)
QK.SEITE_EINSTELLUNGEN = 3

QK.AKZENTE = {
  gold    = { L"Gold", 0.95, 0.77, 0.35 },
  klasse  = { L"Klassenfarbe" },
  eis     = { "Eis", 0.45, 0.78, 0.98 },
  smaragd = { L"Smaragd", 0.40, 0.85, 0.55 },
}

-- Ändert die Akzentfarbe an Ort und Stelle, damit alle Verweise auf QK.farben.gold mitziehen.
function QK:AkzentAnwenden()
  local a = self.AKZENTE[self.db and self.db.akzent or "gold"] or self.AKZENTE.gold
  local r, g, b = a[2], a[3], a[4]
  if not r then
    local _, klasse = UnitClass("player")
    local c = klasse and RAID_CLASS_COLORS and RAID_CLASS_COLORS[klasse]
    if c then r, g, b = c.r, c.g, c.b else r, g, b = 0.95, 0.77, 0.35 end
  end
  local f = self.farben.gold
  f[1], f[2], f[3] = r, g, b
  local bl = self.farben.balken
  bl[1], bl[2], bl[3] = r, g * 0.92, b * 0.75
  self.gold = ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
  self:BarrierefreiAnwenden()
end

---------------------------------------------------------------------------
-- Barrierefreiheit
---------------------------------------------------------------------------
local BASIS = {
  hell  = { 0.93, 0.91, 0.86 },
  grau  = { 0.55, 0.55, 0.55 },
  gruen = { 0.45, 0.85, 0.45 },
  rot   = { 0.90, 0.35, 0.30 },
}

local function setze(ziel, quelle) ziel[1], ziel[2], ziel[3] = quelle[1], quelle[2], quelle[3] end

function QK:BarrierefreiAnwenden()
  local db, f = self.db or {}, self.farben
  setze(f.hell, db.kontrast and { 1, 1, 1 } or BASIS.hell)
  setze(f.grau, db.kontrast and { 0.82, 0.82, 0.82 } or BASIS.grau)
  -- Farbenblind: Blau statt Grün, Orange statt Rot (für Rot-Grün-Schwäche unterscheidbar)
  setze(f.gruen, db.farbenblind and { 0.35, 0.65, 1 } or BASIS.gruen)
  setze(f.rot, db.farbenblind and { 1, 0.6, 0.1 } or BASIS.rot)
end

-- Faktor für Fenster, Pfeil und Meldungen
function QK:Groesse()
  return (self.db and self.db.allesGroesser) and 1.25 or 1
end

-- Hintergrund-Deckkraft: im Kontrastmodus fast undurchsichtig
function QK:Deckkraft(normal)
  return (self.db and self.db.kontrast) and math.max(normal, 0.92) or normal
end

-- Text für die Sprachausgabe säubern (Farbcodes, Symbole, Links)
local function sauber(text)
  text = tostring(text or "")
  text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("%[(.-)%]", "%1")
  return (text:gsub("%s+", " "):gsub("^%s+", ""))
end
QK.Sauber = sauber

local stimme
local function Stimme()
  if stimme ~= nil then return stimme end
  stimme = false
  if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum and Enum.TtsVoiceType then
    local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
    if ok and id then stimme = id end
  end
  if not stimme and C_VoiceChat and C_VoiceChat.GetTtsVoices then
    local ok, liste = pcall(C_VoiceChat.GetTtsVoices)
    if ok and liste and liste[1] then stimme = liste[1].voiceID end
  end
  return stimme
end

-- Liest einen Text mit der Sprachausgabe des Spiels vor. Gibt true zurück, wenn es geklappt hat.
function QK:Sprechen(text, immer)
  if not immer and not (self.db and self.db.vorlesen) then return false end
  text = sauber(text)
  if text == "" then return false end
  if TextToSpeech_Speak and TextToSpeech_GetSelectedVoice and Enum and Enum.TtsVoiceType then
    local ok = pcall(TextToSpeech_Speak, text, TextToSpeech_GetSelectedVoice(Enum.TtsVoiceType.Standard))
    if ok then return true end
  end
  if C_VoiceChat and C_VoiceChat.SpeakText then
    local id = Stimme()
    if id then
      local ziel = Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1
      if pcall(C_VoiceChat.SpeakText, id, text, ziel, 0, 100) then return true end
      if pcall(C_VoiceChat.SpeakText, id, text, 0, 100) then return true end
    end
  end
  return false
end

-- Liest die Fokus-Quest (oder die erste der Liste) mit ihren offenen Zielen vor.
function QK:FokusVorlesen()
  local id = self.Compat:Fokus()
  local quests = self.Compat:Questlog()
  local q
  for _, x in ipairs(quests) do if x.id == id then q = x end end
  q = q or quests[1]
  if not q then self:Sprechen(L"Keine Quests im Log.", true) return end
  local teile = { q.titel }
  if q.fertig then
    teile[#teile + 1] = L"Bereit zum Abgeben."
  else
    for _, z in ipairs(q.ziele) do
      if not z.fertig then
        teile[#teile + 1] = z.ist and z.soll and (L"%s: %d von %d."):format(z.text, z.ist, z.soll) or (z.text .. ".")
      end
    end
  end
  local d = self.Kompass and self.Kompass:Entfernung(q.id)
  if d then teile[#teile + 1] = L"Entfernung " .. self:EntfernungText(d):gsub(" m$", L" Meter"):gsub(" km$", L" Kilometer") .. "." end
  if not self:Sprechen(table.concat(teile, " "), true) then
    self:Meldung(L"die Sprachausgabe ist nicht verfügbar. In den Spieleinstellungen unter Barrierefreiheit › Text-zu-Sprache lässt sie sich einrichten.")
  end
end

QK.STILE = {
  ruhig     = { name = L"Ruhig",     hintergrund = 0.55, balken = true,  schrift = "normal", nurNaechstes = false, anzahl = 8 },
  klassisch = { name = L"Klassisch", hintergrund = 0,    balken = false, schrift = "gross",  nurNaechstes = false, anzahl = 10 },
  kompakt   = { name = L"Kompakt",   hintergrund = 0.35, balken = true,  schrift = "klein",  nurNaechstes = true,  anzahl = 12 },
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
  DEFAULT_CHAT_FRAME:AddMessage(QK.gold .. L"Questkompass:|r " .. (select("#", ...) > 0 and text:format(...) or text))
end

---------------------------------------------------------------------------
-- Fehlerprotokoll: Fehler im Addon sollen nie die Oberfläche lahmlegen.
---------------------------------------------------------------------------
local gemeldet = false
-- Geschützte Werte: Neuere Clients geben manche Zahlen (Tempo, Position, Blickrichtung) als
-- „geheime“ Werte zurück, mit denen Addons nicht rechnen oder vergleichen dürfen.
-- QK.Zahl liefert die Zahl, wenn sie benutzbar ist, sonst nil.
local function vergleichbar(v) return v < math.huge end
function QK.Zahl(v)
  if type(v) ~= "number" then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  if not pcall(vergleichbar, v) then return nil end
  return v
end

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
      QK:Meldung(L"|cffe05a4dEin Fehler ist aufgetreten (%s).|r /qk fehler zeigt Details.", name)
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

-- Haken: Module hängen sich an Stellen anderer Module, z. B. Zusatzzeilen in der Liste.
-- QK:Rufe(name, ...) ruft alle Funktionen auf und sammelt ihre Ergebnisse.
local haken = {}
function QK:Haken(name, fn)
  haken[name] = haken[name] or {}
  table.insert(haken[name], fn)
end
function QK:Rufe(name, ...)
  local ergebnisse = {}
  for _, fn in ipairs(haken[name] or {}) do
    local ok, a = pcall(fn, ...)
    if ok and a ~= nil then ergebnisse[#ergebnisse + 1] = a
    elseif not ok then QK:Sicher(name, error, a, 0) end
  end
  return ergebnisse
end

-- Alle Module neu zeichnen (nach Änderungen in Assistent oder Einstellungen).
function QK:Anwenden()
  self:AkzentAnwenden()
  for _, m in ipairs(self.module) do
    if m.Anwenden then QK:Sicher(m.name, m.Anwenden, m) end
  end
end

-- Profile: Einstellungen gelten für alle Charaktere („konto“) oder nur für diesen („eigen“).
-- Diagnose und Fehlerprotokoll bleiben immer kontoweit in QuestkompassDB.
function QK:ProfilLaden()
  local root, char = QuestkompassDB, QuestkompassCharDB
  root.konto = root.konto or {}
  if char.profil == "eigen" then
    char.einstellungen = char.einstellungen or kopie(root.konto)
    self.db = char.einstellungen
  else
    self.db = root.konto
  end
  self:Standardwerte(self.db)
  self:AkzentAnwenden()
end

function QK:ProfilWechseln(art)
  QuestkompassCharDB.profil = art
  if art == "eigen" and not QuestkompassCharDB.einstellungen then
    QuestkompassCharDB.einstellungen = kopie(self.db)
  end
  self:ProfilLaden()
  self:Anwenden()
end

QK:Ereignis("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  QuestkompassDB = QuestkompassDB or {}
  QuestkompassCharDB = QuestkompassCharDB or {}
  local root = QuestkompassDB
  -- Einstellungen aus 0.1/0.2 (flach in QuestkompassDB) ins Kontoprofil übernehmen
  if not root.konto then
    root.konto = {}
    for k in pairs(QK.STANDARD) do
      if root[k] ~= nil then root.konto[k] = root[k]; root[k] = nil end
    end
    if type(root.konto.pos) == "table" and #root.konto.pos == 5 then root.konto.pos = nil end
  end
  QuestkompassCharDB.ausgeblendet = QuestkompassCharDB.ausgeblendet or {}
  QuestkompassCharDB.zugeklappt = QuestkompassCharDB.zugeklappt or {}
  QuestkompassCharDB.tagebuch = QuestkompassCharDB.tagebuch or {}
  QuestkompassCharDB.notizen = QuestkompassCharDB.notizen or {}
  QuestkompassCharDB.angenommen = QuestkompassCharDB.angenommen or {}
  QuestkompassCharDB.erfolge = QuestkompassCharDB.erfolge or {}
  QuestkompassCharDB.angeheftet = QuestkompassCharDB.angeheftet or {}
  QuestkompassCharDB.merkliste = QuestkompassCharDB.merkliste or {}
  QuestkompassCharDB.geschaetzt = QuestkompassCharDB.geschaetzt or {}
  root.charaktere = root.charaktere or {}
  root.epTabelle = root.epTabelle or {}
  root.questGegenstaende = root.questGegenstaende or {}
  QK.root = root
  QK.char = QuestkompassCharDB
  QK:ProfilLaden()
  QK:SpracheAnwenden()
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

-- Sprache: „auto“ folgt dem Spiel, „de“ und „en“ erzwingen eine Sprache (ganz erst nach /reload).
function QK:SpracheAnwenden()
  local s = self.db and self.db.sprache
  if s == "de" then englisch = false elseif s == "en" then englisch = true else englisch = GetLocale() ~= "deDE" end
  self.englischUI = englisch
end

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

-- Geld in Kupfer als Text mit Münzsymbolen
function QK:GeldText(kupfer)
  kupfer = math.floor(kupfer or 0)
  local g, si, k = math.floor(kupfer / 10000), math.floor(kupfer / 100) % 100, kupfer % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t" end
  if si > 0 then t[#t + 1] = si .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t" end
  if k > 0 or #t == 0 then t[#t + 1] = k .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" end
  return table.concat(t, " ")
end

---------------------------------------------------------------------------
-- Befehle
---------------------------------------------------------------------------
local HILFE = {
  L"/qk – Zielliste ein- oder ausblenden",
  L"/qk einstellungen – alle Einstellungen",
  L"/qk einrichten – Einrichtungsassistent erneut starten",
  L"/qk gebiet [Name] – Gebietsfortschritt",
  L"/qk buch | welt | suche [Text] | tagebuch – Questbuch",
  L"/qk naechste – nächstgelegene Quest als Fokus",
  L"/qk vorlesen – Fokus-Quest vorlesen lassen",
  L"/qk fokus – Fokus-Quest aufheben",
  L"/qk einblenden – ausgeblendete Quests wieder zeigen",
  L"/qk zuruecksetzen – alles auf Anfang",
  L"/qk diagnose | fehler – technische Infos für Fehlerberichte",
}

-- Englische Befehle
local ALIAS = {
  settings = "einstellungen", options = "einstellungen", setup = "einrichten", book = "buch", world = "welt",
  journal = "tagebuch", search = "suche", nearest = "naechste", read = "vorlesen", focus = "fokus",
  show = "einblenden", errors = "fehler", waypoint = "weg", wp = "weg", planner = "planer",
  achievements = "erfolge", milestones = "erfolge", note = "notiz", alts = "twinks", cleanup = "aufraeumen",
  language = "sprache", whatnow = "wasjetzt", chain = "kette", focusmode = "fokusmodus",
  dailygoal = "tagesziel", stats = "statistik", questitems = "gegenstaende",
}

SLASH_QUESTKOMPASS1 = "/qk"
SLASH_QUESTKOMPASS2 = "/questkompass"
SlashCmdList.QUESTKOMPASS = function(eingabe)
  local befehl, rest = (eingabe or ""):match("^%s*(%S*)%s*(.-)%s*$")
  befehl = befehl:lower()
  befehl = ALIAS[befehl] or befehl
  local db = QK.db
  if befehl == "" then
    QK.Tracker:Umschalten()
  elseif befehl == "hilfe" or befehl == "help" or befehl == "?" then
    QK:Meldung(L"Version %s, Questdaten vom %s", QK.version, QK.datenStand or "?")
    for _, zeile in ipairs(HILFE) do DEFAULT_CHAT_FRAME:AddMessage("  " .. zeile) end
  elseif befehl == "einstellungen" or befehl == "optionen" or befehl == "config" then
    QK.Assistent:Oeffnen(QK.SEITE_EINSTELLUNGEN, true)
  elseif befehl == "einrichten" or befehl == "assistent" then
    QK.Assistent:Oeffnen(1)
  elseif befehl == "gebiet" or befehl == "zone" then
    QK.Gebiet:Zeigen(rest ~= "" and rest or nil)
  elseif befehl == "buch" then
    QK.Gebiet:Umschalten()
  elseif befehl == "welt" or befehl == "tagebuch" then
    QK.Gebiet:Reiter(befehl)
  elseif befehl == "suche" then
    QK.Gebiet:Reiter("suche", rest)
  elseif befehl == "vorlesen" then
    QK:FokusVorlesen()
  elseif befehl == "naechste" or befehl == "nächste" then
    QK.Tracker:FokusNaechste()
  elseif befehl == "fokus" then
    QK.Compat:FokusSetzen(nil)
    QK:Anwenden()
    QK:Meldung(L"Fokus aufgehoben.")
  elseif befehl == "einblenden" then
    wipe(QK.char.ausgeblendet)
    QK:Anwenden()
    QK:Meldung(L"alle Quests sind wieder sichtbar.")
  elseif befehl == "zuruecksetzen" or befehl == "reset" then
    wipe(db)
    QK:Standardwerte(db)
    db.eingerichtet = true
    QK:Anwenden()
    QK:Meldung(L"Einstellungen zurückgesetzt. /qk einrichten startet den Assistenten.")
  elseif befehl == "diagnose" then
    QK.Compat:Diagnose(true)
  elseif befehl == "fehler" then
    local liste = QK.root.fehler
    if not liste or #liste == 0 then
      QK:Meldung(L"keine Fehler aufgezeichnet.")
    else
      QK:Meldung(L"die letzten %d Fehler:", #liste)
      for _, f in ipairs(liste) do DEFAULT_CHAT_FRAME:AddMessage("  " .. f) end
    end
  elseif QK.befehle[befehl] then
    QK.befehle[befehl](rest)
  else
    QK:Meldung(L"unbekannter Befehl. /qk hilfe zeigt alle Befehle.")
  end
end

-- Weitere Befehle aus anderen Dateien: QK:Befehl({ "route" }, fn, "/qk route – …")
QK.befehle = {}
function QK:Befehl(namen, fn, hilfe)
  for _, n in ipairs(namen) do QK.befehle[n] = fn end
  if hilfe then table.insert(HILFE, #HILFE - 2, hilfe) end
end

---------------------------------------------------------------------------
-- Tastenkürzel (Bindings.xml)
---------------------------------------------------------------------------
BINDING_HEADER_QUESTKOMPASS = "Questkompass"
BINDING_NAME_QUESTKOMPASS_LISTE = L"Liste ein- oder ausblenden"
BINDING_NAME_QUESTKOMPASS_NAECHSTE = L"Nächstgelegene Quest als Fokus"
BINDING_NAME_QUESTKOMPASS_WEITER = L"Fokus auf die nächste Quest der Liste"
BINDING_NAME_QUESTKOMPASS_ZURUECK = L"Fokus auf die vorige Quest der Liste"
BINDING_NAME_QUESTKOMPASS_ROUTE = L"Route planen oder beenden"
BINDING_NAME_QUESTKOMPASS_WASJETZT = L"Was jetzt? (bestes nächstes Ziel)"
BINDING_NAME_QUESTKOMPASS_FOKUSMODUS = L"Fokusmodus ein oder aus"
BINDING_NAME_QUESTKOMPASS_BUCH = L"Questbuch öffnen"
BINDING_NAME_QUESTKOMPASS_PLANER = L"Planer öffnen"
BINDING_NAME_QUESTKOMPASS_EINSTELLUNGEN = L"Einstellungen öffnen"
BINDING_NAME_QUESTKOMPASS_VORLESEN = L"Fokus-Quest vorlesen"

function QK:Taste(was)
  QK:Sicher("Taste", function()
    if was == "liste" then QK.Tracker:Umschalten()
    elseif was == "naechste" then QK.Tracker:FokusNaechste(true)
    elseif was == "weiter" then QK.Tracker:FokusWeiter()
    elseif was == "buch" then QK.Gebiet:Umschalten()
    elseif was == "vorlesen" then QK:FokusVorlesen()
    elseif was == "einstellungen" then QK.Assistent:Oeffnen(QK.SEITE_EINSTELLUNGEN, true)
    elseif QK.tasten[was] then QK.tasten[was]() end
  end)
end
QK.tasten = {}

QK:Befehl({ "sprache", "language" }, function(rest)
  rest = (rest or ""):lower()
  if rest ~= "de" and rest ~= "en" and rest ~= "auto" then
    QK:Meldung(L"/qk sprache de | en | auto")
    return
  end
  QK.db.sprache = rest
  QK:SpracheAnwenden()
  QK:Meldung(L"Sprache geändert. Ganz wirkt sie nach /reload.")
end, L"/qk sprache de | en | auto – Sprache der Oberfläche")
