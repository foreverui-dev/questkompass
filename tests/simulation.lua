-- Testlauf ohne Spiel: stellt die benötigten WoW-Funktionen nach, lädt das Addon in
-- TOC-Reihenfolge und prüft es zweimal: mit der modernen Quest-API (wie WoW Forever)
-- und mit der klassischen. Aufruf aus dem Addon-Ordner: lua5.1 tests/simulation.lua
local fehler, geprueft = 0, 0
local function pruefe(bed, text)
  geprueft = geprueft + 1
  if bed then print("  ok    " .. text) else print("  FEHLER " .. text); fehler = fehler + 1 end
end

local toc = {}
for zeile in io.lines("Questkompass.toc") do
  if not zeile:match("^##") and zeile:match("%S") then toc[#toc + 1] = (zeile:gsub("\\", "/")) end
end

local echteG = {}
for k, v in pairs(_G) do echteG[k] = v end

local function Durchlauf(modern)
  -- frische Umgebung
  for k in pairs(_G) do if echteG[k] == nil then _G[k] = nil end end
  print(modern and "\n== Moderne Quest-API (WoW Forever) ==" or "\n== Klassische Quest-API ==")

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

  local alleTexte = {}
  local frames = {}
  local function NeuesObjekt(art)
    local o = { art = art, gezeigt = true, skripte = {}, ereignisse = {} }
    return setmetatable(o, { __index = function(t, k)
      local f = ({
        SetText = function(s, x) s.text = x; alleTexte[#alleTexte + 1] = x end,
        GetText = function(s) return s.text end,
        SetScript = function(s, n, fn) s.skripte[n] = fn end,
        GetScript = function(s, n) return s.skripte[n] end,
        Show = function(s) local war = s.gezeigt; s.gezeigt = true; if s.skripte.OnShow and not war then s.skripte.OnShow(s) end end,
        Hide = function(s) s.gezeigt = false end,
        IsShown = function(s) return s.gezeigt end,
        SetShown = function(s, v) if v then s:Show() else s:Hide() end end,
        CreateFontString = function() return NeuesObjekt("FontString") end,
        CreateTexture = function() return NeuesObjekt("Texture") end,
        RegisterEvent = function(s, e) s.ereignisse[e] = true end,
        SetAlpha = function(s, v) s.alpha = v end,
        SetHeight = function(s, v) s.hoehe = v end,
        SetValue = function(s, v) s.wert = v end,
        SetRotation = function(s, v) s.drehung = v end,
        SetChecked = function(s, v) s.an = v end,
        GetChecked = function(s) return s.an end,
        GetStringWidth = function() return 80 end,
        GetWidth = function(s) return s.breite or 140 end,
        GetCenter = function() return 500, 500 end,
        GetEffectiveScale = function() return 1 end,
        IsMouseOver = function() return false end,
        GetPoint = function() return "TOPRIGHT", nil, "TOPRIGHT", -10, -200 end,
        GetLeft = function() return 900 end,
        GetRight = function() return 1140 end,
        GetTop = function() return 600 end,
        SetAttribute = function(s, k, v) s.attribute = s.attribute or {}; s.attribute[k] = v end,
        EnableMouseWheel = function(s, v) s.mausrad = v end,
        SetVertexColor = function() end,
      })[k]
      if f then return f end
      if type(k) == "string" and k:match("^%u") then return function() end end
    end })
  end
  CreateFrame = function(art, name)
    local f = NeuesObjekt(art)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
  end
  UIParent, Minimap = NeuesObjekt("Frame"), NeuesObjekt("Frame")
  GameTooltip, ItemRefTooltip = NeuesObjekt("GameTooltip"), NeuesObjekt("GameTooltip")
  if modern then ObjectiveTrackerFrame = NeuesObjekt("Frame") else QuestWatchFrame = NeuesObjekt("Frame") end
  DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) end }
  UISpecialFrames, SlashCmdList = {}, {}
  tinsert = table.insert
  wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  MAX_QUESTLOG_QUESTS = 20
  BackdropTemplateMixin = {}
  local timer = {}
  C_Timer = { After = function(_, fn) timer[#timer + 1] = fn end }
  local function Timer() while #timer > 0 do table.remove(timer, 1)() end end
  C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }
  BreakUpLargeNumbers = function(n) local s = tostring(n); return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")) end
  GetQuestDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
  local imKampf = false
  InCombatLockdown = function() return imKampf end
  IsShiftKeyDown = function() return false end
  IsControlKeyDown = function() return false end
  GetTime = function() return os.clock() * 100 end
  GetBuildInfo = function() return "1.60.1", "70399", "Nov 1 2026", modern and 16001 or 11507 end
  date = os.date
  local hooks = {}
  hooksecurefunc = function(a, b, c) if type(a) == "string" then hooks[a] = b else hooks[b] = c end end
  PlaySound = function() end
  UnitLevel = function() return 5 end
  UnitXP = function() return 1000 end
  UnitXPMax = function() return 1500 end
  GetUnitSpeed = function() return 7 end
  UnitName = function(e) return e == "party1" and "Kumpel" or "Baumkuschler" end
  local gruppe = 0
  GetNumSubgroupMembers = function() return gruppe end
  IsInGroup = function() return gruppe > 0 end
  IsInRaid = function() return false end
  local chat = {}
  SendChatMessage = function(t, kanal) chat[#chat + 1] = kanal .. ":" .. t end
  RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
  time = os.time
  SOUNDKIT = { IG_QUEST_LIST_COMPLETE = 1 }

  local fraktion, klasse, volk = modern and "Horde" or "Alliance", 1, modern and 6 or 1
  GetLocale = function() return "deDE" end
  UnitFactionGroup = function() return fraktion end
  UnitClass = function() return "Krieger", "WARRIOR", klasse end
  UnitRace = function() return "x", "x", volk end
  local zone = modern and "Mulgore" or "Wald von Elwynn"
  local teilzone = ""
  GetRealZoneText = function() return zone end
  GetZoneText = function() return zone end
  GetSubZoneText = function() return teilzone end

  -- Questlog: { Titel, Stufe, Gruppe, Überschrift, ID, Ziele = { text, art, fertig, ist, soll } }
  local log = modern and {
    { "Mulgore", h = true },
    { "Riten der Erdenmutter", 3, 0, id = 776, ziele = { { "Begebt Euch zu Seher Graytongue", "event", false } } },
    { "Die Jagd geht weiter", 3, 0, id = 750, ziele = { { "Bergpumapelz: 1/10", "item", false, 1, 10 } } },
    { "Durotar", h = true },
    { "Tafel der Ahnen", 5, 2, id = 790, ziele = { { "Tafel: 1/1", "item", true, 1, 1 } } },
  } or {
    { "Wald von Elwynn", h = true },
    { "GESUCHT: \"Hogger\"", 11, 3, id = 176, ziele = { { "Hoggers Klaue: 0/1", "item", false, 0, 1 } } },
    { "Kopfgeld auf die Flusspfotengnolle", 10, 0, id = 11, ziele = { { "Flusspfotenhalstuch: 4/8", "item", false, 4, 8 } } },
    { "Westfall", h = true },
    { "Die Volkswehr", 14, 0, id = 12, ziele = { { "Defias-Halunke getötet: 15/15", "monster", true, 15, 15 } } },
  }
  local erledigt = { [16] = true, [743] = true }
  local fokus = 0
  local positionen = { [750] = { 0.6, 0.4 }, [776] = { 0.5, 0.7 } }
  C_QuestLog = { IsQuestFlaggedCompleted = function(id) return erledigt[id] == true end }
  if modern then
    local CQ = C_QuestLog
    CQ.GetNumQuestLogEntries = function() return #log, 3 end
    CQ.GetInfo = function(i)
      local e = log[i]
      if not e then return nil end
      return { title = e[1], level = e[2], suggestedGroup = e[3], isHeader = e.h or false, questID = e.id }
    end
    CQ.GetQuestObjectives = function(id)
      for _, e in ipairs(log) do
        if e.id == id then
          local r = {}
          for _, z in ipairs(e.ziele) do r[#r + 1] = { text = z[1], type = z[2], finished = z[3], numFulfilled = z[4], numRequired = z[5] } end
          return r
        end
      end
      return {}
    end
    CQ.IsComplete = function(id) return id == 790 end
    CQ.IsFailed = function() return false end
    CQ.GetQuestWatchType = function(id) if id == 750 then return 0 end return nil end
    CQ.GetDistanceSqToQuest = function(id)
      if id == 750 then return 120 * 120, true elseif id == 776 then return 400 * 400, true end
      return nil
    end
    CQ.GetQuestsOnMap = function()
      local r = {}
      for id, p in pairs(positionen) do r[#r + 1] = { questID = id, x = p[1], y = p[2] } end
      return r
    end
    C_SuperTrack = {
      SetSuperTrackedQuestID = function(id) fokus = id end,
      GetSuperTrackedQuestID = function() return fokus end,
    }
    C_Map = {
      GetBestMapForUnit = function() return 7 end,
      GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
      GetMapWorldSize = function() return 3000, 2000 end,
    }
    GetPlayerFacing = function() return 0 end
    GetQuestLink = function(id) return "|Hquest:" .. id .. ":3|h[x]|h" end
  else
    GetNumQuestLogEntries = function() return #log end
    GetQuestLogTitle = function(i)
      local e = log[i]
      if e.h then return e[1], nil, nil, true end
      return e[1], e[2], e[3], false, false, nil, 0, e.id
    end
    GetNumQuestLeaderBoards = function(i) return log[i].ziele and #log[i].ziele or 0 end
    GetQuestLogLeaderBoard = function(j, i) local z = log[i].ziele[j]; return z[1], z[2], z[3] end
    IsQuestWatched = function(i) return i == 2 end
    GetQuestLink = function(i) return "|Hquest:" .. log[i].id .. ":1|h[x]|h" end
  end

  -- laden
  local QK = {}
  for _, datei in ipairs(toc) do assert(loadfile(datei))("Questkompass", QK) end
  local function feuern(ereignis, ...)
    for _, f in ipairs(frames) do
      if f.ereignisse[ereignis] and f.skripte.OnEvent then f.skripte.OnEvent(f, ereignis, ...) end
    end
    Timer()
  end
  feuern("ADDON_LOADED", "Questkompass")
  feuern("PLAYER_LOGIN")
  local function enthaelt(muster)
    for _, t in ipairs(alleTexte) do if type(t) == "string" and t:find(muster, 1, true) then return true end end
    return false
  end

  pruefe(QK.Compat.modern == modern, "richtige Quest-API erkannt")
  pruefe(QuestkompassAssistent and QuestkompassAssistent.gezeigt, "Assistent öffnet beim ersten Start")
  pruefe(enthaelt("Willkommen") and enthaelt("Los geht’s"), "Willkommensseite")
  for i = 1, 9 do
    alleTexte = {}
    QK.Assistent:Oeffnen(i)
  end
  pruefe(enthaelt("Alles bereit!") and enthaelt("Fertig"), "alle Seiten des Assistenten lassen sich zeigen")
  QK.Assistent:Schliessen()
  pruefe(QK.db.eingerichtet and not QuestkompassAssistent.gezeigt, "Assistent schließt und merkt sich das")

  alleTexte = {}
  QK.Tracker:Aktualisieren()
  if modern then
    pruefe(enthaelt("[3] Die Jagd geht weiter") and enthaelt("Riten der Erdenmutter"), "Quests aus moderner API in der Liste")
    pruefe(enthaelt("Bergpumapelz  |cffbfbfbf1/10|r"), "Ziel mit Zähler")
    pruefe(enthaelt("Bereit zum Abgeben"), "fertige Quest erkannt")
    pruefe(enthaelt("110 m") and enthaelt("370 m"), "Entfernungen in Metern")
    local reihen = {}
    for _, t in ipairs(alleTexte) do if type(t) == "string" and t:match("^%[%d") then reihen[#reihen + 1] = t end end
    pruefe(reihen[1]:find("Jagd") and reihen[2]:find("Riten"), "nächste Quest zuerst")
    QK.Compat:FokusSetzen(776)
    alleTexte = {}
    QK.Tracker:Aktualisieren()
    reihen = {}
    for _, t in ipairs(alleTexte) do if type(t) == "string" and t:match("^%[%d") then reihen[#reihen + 1] = t end end
    pruefe(reihen[1]:find("Riten") and fokus == 776, "Fokus-Quest steht oben und setzt den Navigationspfeil")
    local w = QK.Kompass:Richtung(750)
    pruefe(w and math.abs(w - math.atan2(300, 200)) < 0.01, "Kompasswinkel stimmt")
    pruefe(ObjectiveTrackerFrame.gezeigt == false, "Questverfolgung des Spiels ausgeblendet")
  else
    pruefe(enthaelt("[11+] GESUCHT"), "Titel mit Stufe und Gruppenmarke")
    pruefe(enthaelt("Flusspfotenhalstuch  |cffbfbfbf4/8|r"), "Ziel mit Zähler")
    pruefe(enthaelt("Bereit zum Abgeben"), "fertige Quest erkannt")
    pruefe(enthaelt("· Westfall"), "Quest aus anderer Zone mit Zonenname")
    pruefe(QuestWatchFrame.gezeigt == false, "Questverfolgung des Spiels ausgeblendet")
  end

  QK.Compat:FokusSetzen(nil)
  QK.db.modus = "verfolgt"
  alleTexte = {}
  QK.Tracker:Aktualisieren()
  pruefe(modern and (enthaelt("Jagd") and not enthaelt("Riten")) or (not modern and enthaelt("GESUCHT") and not enthaelt("Flusspfoten")), "Modus „nur verfolgte“")
  QK.db.modus = "alle"

  QK.db.stil = "kompakt"
  alleTexte = {}
  QK:Anwenden()
  pruefe(#alleTexte > 0, "Stil „Kompakt“ zeichnet")
  QK.db.stil = "klassisch"
  QK:Anwenden()
  QK.db.stil = "ruhig"

  imKampf = true
  feuern("PLAYER_REGEN_DISABLED")
  pruefe(QuestkompassListe.alpha == 0.35, "Ruhemodus im Kampf")
  imKampf = false
  feuern("PLAYER_REGEN_ENABLED")
  pruefe(QuestkompassListe.alpha == 1, "nach dem Kampf wieder sichtbar")

  -- Fortschrittsmeldung
  feuern("QUEST_LOG_UPDATE")
  local jagd = modern and log[3] or log[3]
  jagd.ziele[1][3] = true
  if modern then CQ_alt = C_QuestLog.IsComplete; C_QuestLog.IsComplete = function(id) return id == 790 or id == 750 end end
  alleTexte = {}
  feuern("QUEST_LOG_UPDATE")
  pruefe(enthaelt("BEREIT ZUM ABGEBEN"), "Meldung, wenn eine Quest fertig wird")

  -- Gebiet
  local gebiet = QK:AktuellesGebiet()
  local liste = QK.Gebiet:Liste(gebiet)
  pruefe(gebiet and #liste > 10, ("Gebietsfortschritt %s: %d passende Quests"):format(tostring(QK:GebietName(gebiet)), #liste))
  local status = {}
  for _, q in ipairs(liste) do status[q.id] = q.status end
  if modern then
    pruefe(status[776] == 1 and status[743] == 3, "Status im Log und erledigt")
    local hierListe = QK:GebieteHier()
    pruefe(#hierListe == 2 and hierListe[1] == 215 and hierListe[2] == 220, "Gebiete hier: Mulgore und Gebiet der Jagd-Quest")
  else
    pruefe(status[176] == 1 and status[16] == 3, "Status im Log und erledigt")
  end
  alleTexte = {}
  QK.Gebiet:Zeigen()
  pruefe(enthaelt("von " .. #liste .. " erledigt"), "Gebietsfenster beschriftet")

  -- Automatik
  local angenommen, abgegeben = false, nil
  AcceptQuest = function() angenommen = true end
  GetNumQuestChoices = function() return 0 end
  GetQuestReward = function(i) abgegeben = i or 0 end
  QK.db.autoAnnehmen, QK.db.autoAbgeben = true, true
  feuern("QUEST_DETAIL")
  feuern("QUEST_COMPLETE")
  pruefe(angenommen and abgegeben == 0, "automatisch annehmen und abgeben")
  IsShiftKeyDown = function() return true end
  angenommen = false
  feuern("QUEST_DETAIL")
  pruefe(not angenommen, "Umschalt hält die Automatik an")
  IsShiftKeyDown = function() return false end
  GetNumQuestChoices = function() return 2 end
  GetQuestItemLink = function(_, i) return "item:" .. i end
  GetItemInfo = function(link) local i = tonumber(link:match("%d+")); return "x", nil, nil, nil, nil, nil, nil, nil, nil, nil, i == 2 and 500 or 100 end
  GetQuestItemInfo = function() return "x", nil, 1, 1 end
  QuestInfoRewardsFrameQuestInfoItem2 = NeuesObjekt("Button")
  abgegeben = nil
  feuern("QUEST_COMPLETE")
  pruefe(abgegeben == nil, "bei Belohnungswahl wird nicht automatisch gewählt")

  -- Tooltip
  local zeilen = {}
  local tt = { AddLine = function(_, t) zeilen[#zeilen + 1] = t end, AddDoubleLine = function(_, a, b) zeilen[#zeilen + 1] = a .. "=" .. b end, Show = function() end }
  hooks.SetHyperlink(tt, "quest:176:11")
  local alles = table.concat(zeilen, "|")
  pruefe(alles:find("Gebiet=Wald von Elwynn", 1, true) and alles:find("Erfahrung=875 EP", 1, true), "Quest-Tooltip")

  -- 0.3: Profile, Akzent, Gruppen, Mausrad, EP-Vorschau, Tagebuch, Welt, Suche
  QK.db.akzent = "klasse"
  QK:Anwenden()
  pruefe(math.abs(QK.farben.gold[1] - 0.78) < 0.01, "Akzentfarbe Klassenfarbe")
  QK.db.akzent = "gold"
  QK:Anwenden()
  QK.db.breite = 300
  QK:ProfilWechseln("eigen")
  QK.db.breite = 222
  QK:ProfilWechseln("konto")
  pruefe(QK.db.breite == 300 and QuestkompassCharDB.einstellungen.breite == 222, "Profile getrennt")
  QK.db.gruppen = true
  alleTexte = {}
  QK.Tracker:Aktualisieren()
  pruefe(enthaelt(modern and "– MULGORE" or "– WALD VON ELWYNN"), "Zonenüberschriften")
  QK.char.zugeklappt[modern and "Mulgore" or "Wald von Elwynn"] = true
  alleTexte = {}
  QK.Tracker:Aktualisieren()
  pruefe(enthaelt(modern and "+ MULGORE" or "+ WALD VON ELWYNN") and not enthaelt(modern and "Riten" or "GESUCHT"), "Gruppe zuklappen")
  QK.char.zugeklappt = {}
  QK.db.gruppen = false
  QK.db.anzahl = 1
  alleTexte = {}
  QK.Tracker:Aktualisieren()
  pruefe(QuestkompassListe.mausrad == true and enthaelt("2 weitere"), "Mausrad bei langen Listen")
  QuestkompassListe.skripte.OnMouseWheel(QuestkompassListe, -1)
  pruefe(enthaelt("1 weiter oben"), "Mausrad blättert")
  QK.db.anzahl = 8
  QK.Tracker:Aktualisieren()
  alleTexte = {}
  QK.Tracker:Aktualisieren()
  pruefe(enthaelt("EP bereit"), "Erfahrungsvorschau")
  gruppe = 1
  if modern then C_QuestLog.IsUnitOnQuest = function(_, id) return id == 776 end
  else IsUnitOnQuest = function(i) return i == 2 end end
  alleTexte = {}
  QK.Tracker:Aktualisieren()
  pruefe(enthaelt("[1]"), "Gruppenmitglied mit derselben Quest")
  QK.db.gruppenMeldungen = true
  if modern then log[3].ziele[1][3] = false; log[3].ziele[1][4] = 2; C_QuestLog.IsComplete = function(id) return id == 790 end
  else log[3].ziele[1][1] = "Flusspfotenhalstuch: 4/8"; log[3].ziele[1][3] = false end
  feuern("QUEST_LOG_UPDATE")
  if modern then log[3].ziele[1][4] = 3 else log[3].ziele[1][1] = "Flusspfotenhalstuch: 5/8" end
  feuern("QUEST_LOG_UPDATE")
  pruefe(#chat > 0 and chat[#chat]:find("PARTY", 1, true), "Fortschritt an die Gruppe: " .. tostring(chat[#chat]))
  gruppe = 0
  if modern then
    C_QuestLog.GetTimeAllowed = function(id) if id == 776 then return 600, 100 end end
    alleTexte = {}
    QK.Tracker:Aktualisieren()
    pruefe(enthaelt("Zeit: 8:20"), "Countdown bei Zeitlimit")
    GetQuestLogSpecialItemInfo = function(i) if i == 2 then return "|Hitem:5099|h[Horn]|h", 134400, 1, false end end
    QK.Tracker:Aktualisieren()
    pruefe(QuestkompassGegenstand1 and QuestkompassGegenstand1.gezeigt and QuestkompassGegenstand1.attribute.item == "item:5099", "Knopf für Questgegenstand")
    QK.Compat:FokusSetzen(750)
    QK.Tracker:Aktualisieren()
    pruefe(QuestkompassPfeil.gezeigt and enthaelt("Die Jagd geht weiter"), "großer Fokuspfeil")
  end
  feuern("QUEST_TURNED_IN", modern and 776 or 176, 1250, 0)
  pruefe(#QK.char.tagebuch == 1 and QK.char.tagebuch[1].ep == 1250, "Tagebuch-Eintrag")
  alleTexte = {}
  QK.Gebiet:Reiter("tagebuch")
  pruefe(enthaelt("Diese Sitzung: 1 Quests"), "Sitzungsstatistik")
  alleTexte = {}
  QK.Gebiet:Reiter("welt")
  pruefe(enthaelt("Gebieten"), "Weltübersicht")
  alleTexte = {}
  QK.Gebiet:Reiter("suche", "hogger")
  pruefe(modern and enthaelt("Nichts gefunden") or (not modern and enthaelt("GESUCHT")), "Suche (Hogger nur für Allianz)")
  QK.Gebiet:Reiter("suche", "jagd")
  for _, t in ipairs({ "liste", "liste", "naechste", "weiter", "buch", "einstellungen" }) do Questkompass:Taste(t) end
  Timer()
  pruefe(BINDING_NAME_QUESTKOMPASS_NAECHSTE ~= nil, "Tastenkürzel")

  -- 0.4: Barrierefreiheit
  local gesprochen = {}
  TextToSpeech_Speak = function(t) gesprochen[#gesprochen + 1] = t end
  TextToSpeech_GetSelectedVoice = function() return 1 end
  Enum = Enum or {}
  Enum.TtsVoiceType = { Standard = 0 }
  QK.db.vorlesen, QK.db.farbenblind, QK.db.kontrast, QK.db.allesGroesser, QK.db.wenigerBewegung = true, true, true, true, true
  QK:Anwenden()
  pruefe(QK.farben.gruen[3] == 1 and QK.farben.hell[1] == 1, "Farbenblind- und Kontrastfarben")
  QK.Meldungen:Zeigen("BEREIT ZUM ABGEBEN", "|TInterface\\x:16|t |cff00ff00Test|r")
  pruefe(gesprochen[#gesprochen] == "BEREIT ZUM ABGEBEN. Test", "Meldung wird vorgelesen: " .. tostring(gesprochen[#gesprochen]))
  QK:FokusVorlesen()
  pruefe(#gesprochen >= 2 and #gesprochen[#gesprochen] > 5, "Fokus-Quest vorlesen: " .. tostring(gesprochen[#gesprochen]))
  alleTexte = {}
  QK.Gebiet:Zeigen()
  pruefe(enthaelt("(erledigt)") or enthaelt("(offen)"), "Status als Wort im Questbuch")
  pruefe(QuestkompassAssistent and true, "Assistent mit Barrierefreiheit-Seite")
  QK.db.vorlesen, QK.db.farbenblind, QK.db.kontrast, QK.db.allesGroesser, QK.db.wenigerBewegung = false, false, false, false, false
  QK:Anwenden()
  pruefe(QK.farben.gruen[3] < 0.5, "Farben zurück auf normal")

  -- Befehle
  for _, b in ipairs({ "", "", "hilfe", "einstellungen", "einrichten", "gebiet", "gebiet Westfall", "gebiet Atlantis",
      "fokus", "vorlesen", "einblenden", "diagnose", "fehler", "zuruecksetzen", "quatsch" }) do
    local ok, err = pcall(SlashCmdList.QUESTKOMPASS, b)
    Timer()
    pruefe(ok, "/qk " .. b .. (ok and "" or (" → " .. tostring(err))))
  end
  pruefe(QK.root.diagnose and QK.root.diagnose.interface == (modern and 16001 or 11507), "Diagnose gespeichert")
  pruefe(not QK.root.fehler or #QK.root.fehler == 0, "keine Fehler im Protokoll" .. ((QK.root.fehler and QK.root.fehler[1]) and (": " .. QK.root.fehler[1]) or ""))
end

Durchlauf(true)
Durchlauf(false)
print(("\n%d Prüfungen, %s"):format(geprueft, fehler == 0 and "alles in Ordnung." or (fehler .. " Fehler.")))
os.exit(fehler == 0 and 0 or 1)
