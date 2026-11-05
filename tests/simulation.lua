-- Testlauf ohne Spiel: stellt die benötigten WoW-Funktionen nach, lädt das Addon
-- in TOC-Reihenfolge und prüft Zielliste, Gebietsfortschritt, Tooltips und Befehle.
-- Aufruf aus dem Addon-Ordner: lua5.1 tests/simulation.lua
local fehler = 0
local function pruefe(bed, text)
  if bed then print("  ok    " .. text) else print("  FEHLER " .. text); fehler = fehler + 1 end
end

-- bit-Bibliothek wie im Spiel
bit = {
  band = function(a, b)
    local r, m = 0, 1
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then r = r + m end
      a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
    end
    return r
  end,
  lshift = function(a, n) return a * 2 ^ n end,
}

-- Frames: jede unbekannte Methode ist ein No-op, Texte werden gemerkt.
local alleTexte = {}
local function NeuesObjekt(art)
  local o = { art = art, punkte = {}, gezeigt = true, skripte = {} }
  return setmetatable(o, { __index = function(t, k)
    local f = ({
      SetText = function(s, x) s.text = x; alleTexte[#alleTexte + 1] = x end,
      GetText = function(s) return s.text end,
      SetScript = function(s, n, fn) s.skripte[n] = fn end,
      GetScript = function(s, n) return s.skripte[n] end,
      Show = function(s) s.gezeigt = true; if s.skripte.OnShow then s.skripte.OnShow(s) end end,
      Hide = function(s) s.gezeigt = false end,
      IsShown = function(s) return s.gezeigt end,
      SetShown = function(s, v) if v then s:Show() else s:Hide() end end,
      CreateFontString = function() return NeuesObjekt("FontString") end,
      CreateTexture = function() return NeuesObjekt("Texture") end,
      RegisterEvent = function(s, e) s.ereignisse = s.ereignisse or {}; s.ereignisse[e] = true end,
      SetMovable = function(s, v) s.beweglich = v end,
      IsMovable = function(s) return s.beweglich end,
      SetAlpha = function(s, v) s.alpha = v end,
      SetHeight = function(s, v) s.hoehe = v end,
      SetValue = function(s, v) s.wert = v end,
      GetPoint = function() return "TOPRIGHT", nil, "TOPRIGHT", -10, -200 end,
    })[k]
    if f then return f end
    if k:match("^%u") then return function() end end
  end })
end
local frames = {}
function CreateFrame(art, name)
  local f = NeuesObjekt(art)
  frames[#frames + 1] = f
  if name then _G[name] = f end
  return f
end
UIParent = NeuesObjekt("Frame")
Minimap = NeuesObjekt("Frame")
QuestWatchFrame = NeuesObjekt("Frame")
QuestLogFrame = NeuesObjekt("Frame"); QuestLogFrame.gezeigt = false
GameTooltip = NeuesObjekt("GameTooltip")
ItemRefTooltip = NeuesObjekt("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) print("  [Chat] " .. t) end }
UISpecialFrames = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
SlashCmdList = {}
MAX_QUESTLOG_QUESTS = 20
BackdropTemplateMixin = {}
C_Timer = { After = function(_, fn) fn() end }
C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }
GameTooltip_Hide = function() end
BreakUpLargeNumbers = function(n) local s = tostring(n); return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")) end
GetQuestDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
InCombatLockdown = function() return false end
IsShiftKeyDown = function() return false end
local hooks = {}
hooksecurefunc = function(a, b, c)
  if type(a) == "string" then hooks[a] = b else hooks[b] = c end
end

-- Spielfigur und Questlog
local locale, fraktion, klasse, volk = "deDE", "Alliance", 1, 1
GetLocale = function() return locale end
UnitFactionGroup = function() return fraktion end
UnitClass = function() return "Krieger", "WARRIOR", klasse end
UnitRace = function() return "Mensch", "Human", volk end
local zone = "Wald von Elwynn"
GetRealZoneText = function() return zone end
GetZoneText = function() return zone end
local erledigt = { [16] = true }
local teilzone = ""
GetSubZoneText = function() return teilzone end
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return erledigt[id] == true end }
local log = {
  { "Wald von Elwynn", nil, nil, true },
  { "GESUCHT: \"Hogger\"", 11, 3, false, false, nil, 0, 176, ziele = { { "Hoggers Klaue: 0/1", "item", false } } },
  { "Kopfgeld auf die Flusspfotengnolle", 10, 0, false, false, nil, 0, 11, ziele = { { "Flusspfotenhalstuch: 4/8", "item", false } } },
  { "Westfall", nil, nil, true },
  { "Die Volkswehr", 14, 0, false, false, 1, 0, 12, ziele = { { "Defias-Halunke getötet: 15/15", "monster", true } } },
}
GetNumQuestLogEntries = function() return #log end
GetQuestLogTitle = function(i) local e = log[i]; return e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8] end
GetNumQuestLeaderBoards = function(i) return log[i].ziele and #log[i].ziele or 0 end
GetQuestLogLeaderBoard = function(j, i) local z = log[i].ziele[j]; return z[1], z[2], z[3] end
IsQuestWatched = function(i) return i == 2 end
GetQuestLink = function(i) return "|cffffff00|Hquest:" .. log[i][8] .. ":" .. log[i][2] .. "|h[" .. log[i][1] .. "]|h|r" end

-- Addon in TOC-Reihenfolge laden
local QK = {}
local toc = {}
for zeile in io.lines("Questkompass.toc") do
  if not zeile:match("^##") and zeile:match("%S") then toc[#toc + 1] = (zeile:gsub("\\", "/")) end
end
for _, datei in ipairs(toc) do
  local chunk = assert(loadfile(datei))
  chunk("Questkompass", QK)
end
print("Geladen: " .. table.concat(toc, ", "))

local function feuern(ereignis, ...)
  for _, f in ipairs(frames) do
    if f.ereignisse and f.ereignisse[ereignis] and f.skripte.OnEvent then f.skripte.OnEvent(f, ereignis, ...) end
  end
end
feuern("ADDON_LOADED", "Questkompass")
feuern("PLAYER_LOGIN")

print("Daten")
local anzahl = 0 for _ in pairs(QK.quests) do anzahl = anzahl + 1 end
pruefe(anzahl > 5000, ("Questdaten geladen (%d Quests)"):format(anzahl))
pruefe(QK:Quest(176).name == "GESUCHT: \"Hogger\"", "deutscher Questname")
pruefe(QK:GebietZuName("Elwynn Forest") == 12 and QK:GebietZuName("wald von elwynn") == 12, "Gebiet per Name (de/en)")
pruefe(QK.version == "dev", "Version ohne Packager = dev")

print("Charakterfilter")
pruefe(QK:PasstZumCharakter(QK:Quest(176)), "Allianzquest passt zu Allianz")
pruefe(not QK:PasstZumCharakter(QK:Quest(2)), "Hordequest passt nicht")
pruefe(QK:PasstZumCharakter(QK:Quest(1638)) == true, "Kriegerquest passt zu Krieger")
klasse = 8
pruefe(QK:PasstZumCharakter(QK:Quest(1638)) == false, "Kriegerquest passt nicht zu Magier")
klasse = 1

print("Zielliste")
alleTexte = {}
QK.Tracker:Aktualisieren()
local function enthaelt(muster)
  for _, t in ipairs(alleTexte) do if type(t) == "string" and t:find(muster, 1, true) then return true end end
  return false
end
pruefe(enthaelt("[11+] GESUCHT"), "Titel mit Stufe und Gruppenmarke")
pruefe(enthaelt("Flusspfotenhalstuch  |cffbfbfbf4/8|r"), "Ziel mit Fortschritt")
pruefe(enthaelt("Bereit zum Abgeben"), "fertige Quest erkannt")
pruefe(enthaelt("· Westfall"), "Quest aus anderer Zone mit Zonenname")
pruefe(enthaelt("3/20"), "Zähler im Kopf")
local reihenfolge = {}
for _, t in ipairs(alleTexte) do if type(t) == "string" and t:match("^%[%d") then reihenfolge[#reihenfolge + 1] = t end end
pruefe(reihenfolge[1]:find("GESUCHT") and reihenfolge[3]:find("Volkswehr"), "aktuelle Zone zuerst")

QK.db.modus = "verfolgt"
alleTexte = {}
QK.Tracker:Aktualisieren()
pruefe(enthaelt("GESUCHT") and not enthaelt("Flusspfoten"), "Modus „verfolgt“")
QK.db.modus = "alle"

QK.char.ausgeblendet[11] = true
alleTexte = {}
QK.Tracker:Aktualisieren()
pruefe(not enthaelt("Flusspfoten"), "ausgeblendete Quest fehlt")
wipe(QK.char.ausgeblendet)

QK.db.anzahl = 1
alleTexte = {}
QK.Tracker:Aktualisieren()
pruefe(enthaelt("+ 2 weitere"), "Begrenzung der Anzahl")
QK.db.anzahl = 8

feuern("PLAYER_REGEN_DISABLED")
pruefe(QuestkompassListe.alpha == 0.35, "Ruhemodus im Kampf")
feuern("PLAYER_REGEN_ENABLED")
pruefe(QuestkompassListe.alpha == 1, "nach dem Kampf wieder voll sichtbar")
pruefe(QuestWatchFrame.gezeigt == false, "Blizzard-Questverfolgung ausgeblendet")

print("Gebietsfortschritt")
local liste = QK.Gebiet:Liste(12)
local status = {}
for _, q in ipairs(liste) do status[q.id] = q.status end
pruefe(#liste > 20, ("Elwynn hat %d passende Quests"):format(#liste))
pruefe(status[176] == 1 and status[11] == 1, "Quests im Log erkannt")
pruefe(status[16] == 3, "erledigte Quest erkannt")
pruefe(liste[1].status == 1, "Quests im Log stehen oben")
alleTexte = {}
QK.Gebiet:Zeigen()
pruefe(enthaelt("von " .. #liste .. " erledigt"), "Fortschrittsbalken beschriftet")
pruefe(QuestkompassGebiet.gezeigt, "Fenster sichtbar")

teilzone = "Nordhaintal"
pruefe(QK:AktuellesGebiet() == 9 and QK:AktuelleGebiete()[12], "Teilgebiet Nordhaintal hat Vorrang, Elwynn zählt weiter")
alleTexte = {}
QK.Tracker:Aktualisieren()
pruefe(not enthaelt("· Wald von Elwynn"), "Elwynn-Quests gelten im Nordhaintal als hier")
teilzone = ""

print("Tooltip")
local zeilen = {}
local tt = { AddLine = function(_, t) zeilen[#zeilen + 1] = t end, AddDoubleLine = function(_, a, b) zeilen[#zeilen + 1] = a .. "=" .. b end, Show = function() end }
hooks.SetHyperlink(tt, "quest:176:11")
local alles = table.concat(zeilen, "|")
pruefe(alles:find("Gebiet=Wald von Elwynn", 1, true) and alles:find("Typ=Elite", 1, true), "Gebiet und Typ")
pruefe(alles:find("Erfahrung=875 EP", 1, true) and alles:find("+100 Stormwind", 1, true), "Erfahrung und Ruf")

print("Befehle")
for _, b in ipairs({ "", "", "hilfe", "verfolgt", "alle", "anzahl 5", "anzahl 99", "sperren", "entsperren",
    "ruhe", "ruhe", "blizzard", "blizzard", "breite 300", "groesse 120", "gebiet Westfall", "gebiet Atlantis",
    "einblenden", "zuruecksetzen", "quatsch" }) do
  local ok, err = pcall(SlashCmdList.QUESTKOMPASS, b)
  pruefe(ok, "/qk " .. b .. (ok and "" or (" → " .. tostring(err))))
end

print("Englischer Client")
locale = "enUS"
for _, datei in ipairs(toc) do assert(loadfile(datei))("Questkompass", QK) end
pruefe(QK:Quest(176).name == "WANTED: \"Hogger\"", "englischer Questname")

print(fehler == 0 and "Alles in Ordnung." or (fehler .. " Fehler."))
os.exit(fehler == 0 and 0 or 1)
