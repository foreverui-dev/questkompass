-- Questkompass: Helfer für unterwegs (1.1).
-- Leichen-Pfeil, Position und Wegpunkt teilen, Quest-Gegner ansagen, Händler-, Bank-, Beute- und
-- Verkaufshinweise für Questgegenstände, Sitzungsbericht, Questdialog vorlesen und mehr.
local _, QK = ...
local U = QK:Modul("Unterwegs")
local L = QK.L

U.sitzungGeld = nil

local function Meldung(oben, text)
  if QK.Meldungen and QK.db.meldungen then QK.Meldungen:Zeigen(oben, text) else QK:Meldung("%s", text) end
end

---------------------------------------------------------------------------
-- Leichen-Pfeil: nach dem Freilassen führt der Fokuspfeil zum Leichnam
---------------------------------------------------------------------------
function U:LeicheSuchen()
  if not QK.db.leichenPfeil then return false end
  if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map and C_Map.GetBestMapForUnit) then return false end
  local karte = C_Map.GetBestMapForUnit("player")
  if not karte then return false end
  local ok, pos = pcall(C_DeathInfo.GetCorpseMapPosition, karte)
  if not ok then return false end
  local x, y = QK.XY(pos)
  if not x or (x == 0 and y == 0) then return false end
  local w = QK.char.wegpunkt
  if not (w and w.leiche) then
    QK.char.vorLeiche = { punkt = w, kette = QK.char.wegkette }
  end
  QK.char.wegkette = nil
  QK.char.wegpunkt = { karte = karte, x = x, y = y, name = L"Dein Leichnam", leiche = true }
  Meldung(L"LEICHEN-PFEIL", L"Der Fokuspfeil führt dich zu deinem Leichnam.")
  if QK.Pfeil then QK.Pfeil:Aktualisieren() end
  return true
end

function U:LeicheErreicht()
  local w = QK.char.wegpunkt
  local vor = QK.char.vorLeiche
  if w and w.leiche then
    QK.char.wegpunkt = vor and vor.punkt or nil
    QK.char.wegkette = vor and vor.kette or nil
    QK.char.zaehler.leiche = (QK.char.zaehler.leiche or 0) + 1
  end
  QK.char.vorLeiche = nil
  if QK.Pfeil then QK.Pfeil:Aktualisieren() end
end

---------------------------------------------------------------------------
-- Position und Wegpunkt teilen
---------------------------------------------------------------------------
function U:Position()
  QK.Kompass:Auffrischen()
  local karte = QK.Kompass:Karte()
  local x, y = QK.Kompass:Spieler()
  if not karte or not x then QK:Meldung(L"die aktuelle Position ist gerade nicht bekannt.") return nil end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(karte)
  local text = ("%s %.1f, %.1f"):format(info and info.name or "", x * 100, y * 100)
  return text, karte, x, y
end

function U:PositionTeilen()
  local text = U:Position()
  if not text then return end
  QK:Meldung(L"Du bist hier: %s", text)
  if ChatFrame_OpenChat then ChatFrame_OpenChat(text) end
end

function U:WegpunktTeilen()
  local w = QK.Navigation:Wegpunkt()
  if not w then QK:Meldung(L"Es gibt keinen Wegpunkt zum Teilen. Setze erst einen mit /qk weg.") return end
  if not (QK.Gruppe and QK.Gruppe.Senden and QK.Gruppe:InGruppe()) then
    QK:Meldung(L"Du bist in keiner Gruppe.") return
  end
  local name = (w.name or ""):gsub("[;|]", " ")
  QK.Gruppe.Senden(("W%d;%.4f;%.4f;%s"):format(w.karte, w.x, w.y, name))
  QK:Meldung(L"Wegpunkt %s an die Gruppe geschickt.", w.name or "")
end

function U:WegpunktEmpfangen(absender, text)
  local karte, x, y, name = text:match("^(%d+);([%d%.]+);([%d%.]+);(.*)$")
  karte, x, y = tonumber(karte), tonumber(x), tonumber(y)
  if not karte or not x or not y then return end
  U.angebot = { karte = karte, x = x, y = y, name = (name ~= "" and name or L"Wegpunkt"), von = absender }
  if StaticPopupDialogs and StaticPopup_Show then
    StaticPopupDialogs.QUESTKOMPASS_WEGPUNKT = StaticPopupDialogs.QUESTKOMPASS_WEGPUNKT or {
      text = "%s", button1 = L"Übernehmen", button2 = L"Nein danke",
      OnAccept = function() U:AngebotAnnehmen() end,
      timeout = 60, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("QUESTKOMPASS_WEGPUNKT", (L"%s teilt einen Wegpunkt: %s (%.1f, %.1f). Übernehmen?"):format(absender, U.angebot.name, x * 100, y * 100))
  else
    QK:Meldung(L"%s teilt einen Wegpunkt: %s. /qk weg übernehmen", absender, U.angebot.name)
  end
end

function U:AngebotAnnehmen()
  local a = U.angebot
  if not a then return end
  QK.Navigation:WegpunktSetzen(a.karte, a.x, a.y, a.name)
  U.angebot = nil
end

---------------------------------------------------------------------------
-- Quest-Gegner: Hinweis beim Auftauchen, Ansage, Hervorhebung beim Anvisieren
---------------------------------------------------------------------------
local zuletztGehoert = {}
function U:NeuerGegner(name, stand)
  if not QK.db.questGegnerTon or not name then return end
  local jetzt = GetTime()
  if zuletztGehoert[name] and jetzt - zuletztGehoert[name] < 30 then return end
  zuletztGehoert[name] = jetzt
  pcall(PlaySound, (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175)
  QK:Sprechen((L"Quest-Gegner in der Nähe: %s"):format(name) .. ((stand and stand ~= "") and (", " .. stand) or ""))
end

function U:GegnerAnsagen()
  local liste = QK.Plaketten and QK.Plaketten:Sichtbare() or {}
  if #liste == 0 then
    QK:Meldung(L"Gerade ist kein Quest-Gegner in der Nähe (Namensplaketten mit V einblenden).")
    QK:Sprechen(L"Kein Quest-Gegner in der Nähe.", true)
    return
  end
  local teile = {}
  for i, e in ipairs(liste) do
    if i > 5 then break end
    teile[#teile + 1] = e.name .. ((e.stand ~= "") and (" " .. e.stand) or "")
  end
  local text = (L"%d Quest-Gegner in der Nähe: %s"):format(#liste, table.concat(teile, ", "))
  QK:Meldung("%s", text)
  QK:Sprechen(text, true)
end

U.zielQuest = nil
local function ZielGeaendert()
  local alt = U.zielQuest
  U.zielQuest = nil
  if QK.db.zielHervorheben and UnitExists and UnitExists("target") and QK.Plaketten then
    local _, _, id = QK.Plaketten:Pruefen("target")
    U.zielQuest = id
  end
  if alt ~= U.zielQuest and QK.Tracker then QK.Tracker:Planen() end
end

---------------------------------------------------------------------------
-- Questgegenstände: Händler, Bank, Beute und Verkauf
---------------------------------------------------------------------------
local function Gebraucht(name)
  name = QK.Text(name)
  if not name or not QK.Gegenstaende then return nil end
  local z = QK.Gegenstaende:Zeilen(name)
  if #z == 0 then return nil end
  return (z[1][1]:gsub("|T.-|t%s*", ""))
end

local function HaendlerName(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
    if ok and type(info) == "table" then return info.name end
  end
  if GetMerchantItemInfo then return (GetMerchantItemInfo(i)) end
end

function U:Haendler()
  if not QK.db.haendlerHinweis then return end
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  local gefunden = 0
  for i = 1, n do
    local name = HaendlerName(i)
    local wofuer = Gebraucht(name)
    if wofuer then
      gefunden = gefunden + 1
      if gefunden <= 3 then QK:Meldung(L"Dieser Händler verkauft %s, gebraucht für: %s", name, wofuer) end
    end
  end
end

local letzterRueckkauf
local function Rueckkauf()
  local n = GetNumBuybackItems and GetNumBuybackItems() or 0
  if n == 0 then return nil end
  return (GetBuybackItemInfo(n))
end

function U:Verkauft()
  if not QK.db.verkaufsWarnung then return end
  local name = Rueckkauf()
  if not name or name == letzterRueckkauf then return end
  letzterRueckkauf = name
  local wofuer = Gebraucht(name)
  if wofuer then
    Meldung(L"ACHTUNG", (L"%s wird noch gebraucht"):format(name))
    QK:Meldung(L"%s wird noch gebraucht (%s). Du kannst es beim Händler unter „Rückkauf“ zurückholen.", name, wofuer)
  end
end

function U:Bank()
  if not QK.db.bankHinweis or not QK.db.twinks then return end
  local ich = QK.Twinks and QK.Twinks.Schluessel()
  local teile = {}
  for key, c in pairs(QK.root.charaktere or {}) do
    if key ~= ich and c.brauche then
      for k, liste in pairs(c.brauche) do
        for _, e in ipairs(liste) do
          if not e[5] then
            local eintrag = QK.root.questGegenstaende[k]
            teile[#teile + 1] = ("%s (%s%s)"):format(eintrag and eintrag.n or k, c.name or "?",
              (e[3] and e[4]) and (" " .. e[3] .. "/" .. e[4]) or "")
          end
        end
      end
    end
  end
  if #teile == 0 then return end
  table.sort(teile)
  QK:Meldung(L"Deine anderen Charaktere sammeln: %s", table.concat(teile, ", ", 1, math.min(#teile, 6)))
end

local beuteGemeldet = {}
function U:Beute(text)
  text = QK.Text(text)
  if not QK.db.questGegenstaende or not text then return end
  local muster = LOOT_ITEM_SELF and LOOT_ITEM_SELF:match("^(.-)%%s")
  if muster and muster ~= "" and not text:find(muster, 1, true) then
    local mehr = LOOT_ITEM_SELF_MULTIPLE and LOOT_ITEM_SELF_MULTIPLE:match("^(.-)%%s")
    if not (mehr and text:find(mehr, 1, true)) then return end
  end
  local name = text:match("|h%[(.-)%]|h")
  if not name or beuteGemeldet[name] then return end
  -- eigene offene Ziele meldet schon die Fortschrittsanzeige, hier geht es um Twinks und spätere Quests
  local brauche = QK.Gegenstaende.brauche or {}
  if brauche[name:lower()] then return end
  local wofuer = Gebraucht(name)
  if wofuer then
    beuteGemeldet[name] = true
    QK:Meldung(L"%s gut aufheben: %s", name, wofuer)
  end
end

---------------------------------------------------------------------------
-- Liste: Questtext und Schwierigkeit im Tooltip
---------------------------------------------------------------------------
local textCache = {}
function U:QuestText(q)
  if textCache[q.id] ~= nil then return textCache[q.id] or nil end
  local beschreibung, ziele
  if C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.GetSelectedQuest and GetQuestLogQuestText then
    local vorher = C_QuestLog.GetSelectedQuest()
    pcall(C_QuestLog.SetSelectedQuest, q.id)
    local ok, b, z = pcall(GetQuestLogQuestText)
    if ok then beschreibung, ziele = b, z end
    if vorher then pcall(C_QuestLog.SetSelectedQuest, vorher) end
  elseif SelectQuestLogEntry and GetQuestLogSelection and GetQuestLogQuestText and q.index then
    local vorher = GetQuestLogSelection()
    SelectQuestLogEntry(q.index)
    local ok, b, z = pcall(GetQuestLogQuestText)
    if ok then beschreibung, ziele = b, z end
    if vorher then SelectQuestLogEntry(vorher) end
  end
  local text = (type(ziele) == "string" and ziele ~= "") and ziele or beschreibung
  if type(text) ~= "string" or text == "" then textCache[q.id] = false return nil end
  if #text > 260 then text = text:sub(1, 257):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") .. "…" end
  textCache[q.id] = text
  return text
end

function U:Schwierigkeit(q)
  if q.grau then return L"leicht (kaum Erfahrung)" end
  local ich = UnitLevel("player") or 1
  if not q.stufe or q.stufe <= 0 then return nil end
  local d = q.stufe - ich
  if d >= 5 then return L"sehr schwer"
  elseif d >= 3 then return L"schwer"
  elseif d >= -2 then return L"passend"
  else return L"leicht" end
end

---------------------------------------------------------------------------
-- Sitzungsbericht und Prognose
---------------------------------------------------------------------------
function U:Prognose()
  local pl = QK.Planer
  local rate = pl and pl:ProStunde()
  if not rate or rate <= 0 then return nil end
  local stufe = UnitLevel("player") or 1
  if pl.MaxStufe and stufe >= pl:MaxStufe() then return nil end
  local rest = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
  if rest <= 0 then return nil end
  return stufe + 1, rest / rate * 3600
end

function U:SitzungZeilen()
  local s = QK.Gebiet and QK.Gebiet.sitzung or {}
  local zeilen = {}
  local dauer = s.start and (GetTime() - s.start) or 0
  zeilen[#zeilen + 1] = { L"Diese Sitzung", QK:DauerText(dauer) }
  zeilen[#zeilen + 1] = { L"Quests abgegeben", tostring(s.quests or 0) }
  if (s.ep or 0) > 0 then zeilen[#zeilen + 1] = { L"Erfahrung", QK:EPText(s.ep) or "" } end
  local rate = QK.Planer and QK.Planer:ProStunde()
  if rate then zeilen[#zeilen + 1] = { L"EP pro Stunde", BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(rate)) or tostring(math.floor(rate)) } end
  if U.sitzungGeld and GetMoney then
    local diff = GetMoney() - U.sitzungGeld
    if diff ~= 0 then zeilen[#zeilen + 1] = { L"Gold", (diff < 0 and "-" or "+") .. QK:GeldText(math.abs(diff)) } end
  end
  local stufe, sekunden = U:Prognose()
  if stufe then zeilen[#zeilen + 1] = { (L"Stufe %d in etwa"):format(stufe), QK:DauerText(sekunden) } end
  if QK.Extras then zeilen[#zeilen + 1] = { L"Heute abgegeben", tostring(QK.Extras:Heute()) } end
  return zeilen
end

function U:TooltipSitzung(tooltip)
  if not QK.db.prognose then return end
  tooltip:AddLine(" ")
  for _, z in ipairs(U:SitzungZeilen()) do tooltip:AddDoubleLine(z[1], z[2], 0.6, 0.6, 0.6, 0.85, 0.85, 0.85) end
end

function U:SitzungAusgeben()
  QK:Meldung(L"Sitzungsbericht:")
  local teile = {}
  for _, z in ipairs(U:SitzungZeilen()) do
    print("  " .. z[1] .. ": " .. z[2])
    teile[#teile + 1] = z[1] .. " " .. z[2]
  end
  QK:Sprechen(table.concat(teile, ". "))
end

function U:TagebuchText()
  local buch = QK.char.tagebuch
  local teile = {}
  for i = #buch, math.max(1, #buch - 49), -1 do
    local e = buch[i]
    teile[#teile + 1] = date("%d.%m. %H:%M", e.zeit) .. " " .. (e.name or ("Quest " .. e.id)) .. (e.ep and e.ep > 0 and (" (" .. e.ep .. " EP)") or "")
  end
  return table.concat(teile, " | ")
end

---------------------------------------------------------------------------
-- Questdialog: geteilte Quests, Gruppenwarnung, Vorlesen
---------------------------------------------------------------------------
local function Dialog()
  local db = QK.db
  local npc = UnitIsPlayer and UnitIsPlayer("npc")
  if db.geteiltAnnehmen and npc and not IsShiftKeyDown() and ((UnitInParty and UnitInParty("npc")) or (UnitInRaid and UnitInRaid("npc"))) then
    if AcceptQuest then AcceptQuest() end
    QK:Meldung(L"Geteilte Quest angenommen: %s", GetTitleText and GetTitleText() or "")
    return
  end
  local gruppe = GetSuggestedGroupNum and GetSuggestedGroupNum() or 0
  if db.gruppenWarnung and gruppe and gruppe > 1 then
    Meldung(L"GRUPPENQUEST", (L"empfohlen für %d Spieler"):format(gruppe))
  end
  if db.vorlesen and db.dialogVorlesen then
    local titel = GetTitleText and GetTitleText() or ""
    local ziel = GetObjectiveText and GetObjectiveText() or ""
    QK:Sprechen(titel .. ". " .. ziel .. (gruppe and gruppe > 1 and (". " .. (L"empfohlen für %d Spieler"):format(gruppe)) or ""))
  end
end

local function BelohnungVorlesen()
  if not (QK.db.vorlesen and QK.db.dialogVorlesen) then return end
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  if n < 2 then return end
  local teile = {}
  for i = 1, n do
    local name = GetQuestItemInfo and GetQuestItemInfo("choice", i)
    if name then teile[#teile + 1] = i .. ": " .. name end
  end
  QK:Sprechen((L"Wähle eine Belohnung. %s"):format(table.concat(teile, ", ")))
end

local function FokusPruefen()
  if not QK.db.fokusWeiter then return end
  local id = QK.Compat:Fokus()
  if not id then return end
  for _, q in ipairs(QK.Compat:Questlog()) do
    if q.id == id then
      if q.fertig and QK.Tracker then QK.Tracker:FokusNaechste(true) end
      return
    end
  end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
function U:Start()
  QK.char.zaehler = QK.char.zaehler or {}
  U.sitzungGeld = GetMoney and GetMoney() or nil
  QK:Ereignis("PLAYER_ALIVE", function() if UnitIsGhost and UnitIsGhost("player") then U:LeicheSuchen() end end)
  QK:Ereignis("PLAYER_ENTERING_WORLD", function()
    if UnitIsGhost and UnitIsGhost("player") then C_Timer.After(2, function() QK:Sicher("Leiche", U.LeicheSuchen, U) end) end
  end)
  QK:Ereignis("PLAYER_UNGHOST", function() U:LeicheErreicht() end)
  QK:Ereignis("PLAYER_TARGET_CHANGED", ZielGeaendert)
  QK:Ereignis("MERCHANT_SHOW", function()
    letzterRueckkauf = Rueckkauf()
    C_Timer.After(0.3, function() QK:Sicher("Händler", U.Haendler, U) end)
  end)
  QK:Ereignis("MERCHANT_UPDATE", function() U:Verkauft() end)
  QK:Ereignis("BANKFRAME_OPENED", function() U:Bank() end)
  QK:Ereignis("CHAT_MSG_LOOT", function(text) U:Beute(text) end)
  QK:Ereignis("QUEST_DETAIL", Dialog)
  QK:Ereignis("QUEST_ACCEPT_CONFIRM", function()
    if QK.db.geteiltAnnehmen and ConfirmAcceptQuest and not IsShiftKeyDown() then ConfirmAcceptQuest() end
  end)
  QK:Ereignis("QUEST_COMPLETE", BelohnungVorlesen)
  local geplant = false
  QK:Ereignis("QUEST_LOG_UPDATE", function()
    if geplant then return end
    geplant = true
    C_Timer.After(0.6, function() geplant = false; QK:Sicher("Fokus weiter", FokusPruefen) end)
  end)
  QK:Ereignis("QUEST_TURNED_IN", function() wipe(textCache) end)
  QK:Haken("marke", function(q)
    if U.zielQuest and q.id == U.zielQuest then
      return "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:12:12:0:0|t" .. QK.gold .. L"anvisiert" .. "|r"
    end
  end)
  QK:Haken("listentipp", function(tooltip, q)
    local s = U:Schwierigkeit(q)
    if s then tooltip:AddDoubleLine(L"Schwierigkeit", s, 0.6, 0.6, 0.6, 0.85, 0.85, 0.85) end
    if QK.db.questText then
      local t = U:QuestText(q)
      if t then tooltip:AddLine(" "); tooltip:AddLine(t, 0.8, 0.8, 0.8, true) end
    end
  end)
end

QK:Befehl({ "pos", "position" }, function() U:PositionTeilen() end, L"/qk pos – eigene Position anzeigen und in den Chat legen")
QK:Befehl({ "gegner", "enemies" }, function() U:GegnerAnsagen() end, L"/qk gegner – Quest-Gegner in der Nähe ansagen")
QK:Befehl({ "sitzung", "session" }, function() U:SitzungAusgeben() end, L"/qk sitzung – Sitzungsbericht mit EP pro Stunde und Prognose")
QK:Befehl({ "tagebuchtext", "journaltext" }, function()
  QK.Assistent:Teilen("tagebuch", nil, L"Tagebuch als Text")
end, L"/qk tagebuchtext – die letzten 50 Einträge zum Kopieren")
QK.tasten.gegner = function() U:GegnerAnsagen() end
QK.tasten.position = function() U:PositionTeilen() end
QK.tasten.sitzung = function() U:SitzungAusgeben() end
