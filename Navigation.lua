-- Questkompass: Navigation. Route durch alle Quests einer Karte, eigene Wegpunkte,
-- Pfeil am Rand der Minikarte und Erinnerung, wenn eine Abgabe in der Nähe ist.
local _, QK = ...
local N = QK:Modul("Navigation")
local L = QK.L

local PFEIL = "Interface\\Minimap\\MiniMap-QuestArrow"
-- Durchmesser der Minikarte in Yards je Zoomstufe (draußen, drinnen)
local DRAUSSEN = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 }
local DRINNEN = { [0] = 300, 240, 180, 120, 80, 50 }

---------------------------------------------------------------------------
-- Route: kürzeste Reihenfolge (nächster Nachbar, dann 2-opt)
---------------------------------------------------------------------------
local function Laenge(punkte, reihenfolge)
  local summe = 0
  for i = 2, #reihenfolge do
    local a, b = punkte[reihenfolge[i - 1]], punkte[reihenfolge[i]]
    summe = summe + QK.Kompass:Abstand(a.x, a.y, b.x, b.y)
  end
  return summe
end

-- punkte[1] ist der Startpunkt (Spieler) und bleibt vorn. Liefert die Reihenfolge der Indizes.
function N:Reihenfolge(punkte)
  local n = #punkte
  local weg, frei = { 1 }, {}
  for i = 2, n do frei[i] = true end
  local aktuell = 1
  for _ = 2, n do
    local bester, abstand
    for i in pairs(frei) do
      local d = QK.Kompass:Abstand(punkte[aktuell].x, punkte[aktuell].y, punkte[i].x, punkte[i].y)
      if not abstand or d < abstand or (d == abstand and i < bester) then bester, abstand = i, d end
    end
    weg[#weg + 1] = bester
    frei[bester] = nil
    aktuell = bester
  end
  -- 2-opt: Teilstücke umdrehen, solange der Weg kürzer wird
  local besser, runden = true, 0
  while besser and runden < 50 do
    besser, runden = false, runden + 1
    for i = 2, #weg - 1 do
      for k = i + 1, #weg do
        local neu = {}
        for j = 1, i - 1 do neu[#neu + 1] = weg[j] end
        for j = k, i, -1 do neu[#neu + 1] = weg[j] end
        for j = k + 1, #weg do neu[#neu + 1] = weg[j] end
        if Laenge(punkte, neu) + 0.01 < Laenge(punkte, weg) then weg, besser = neu, true end
      end
    end
  end
  return weg
end

function N:Route() return QK.char.route end

-- Platz einer Quest in der Route (1 = aktuelle Station), sonst nil
function N:Station(questID)
  local r = QK.char and QK.char.route
  if not r then return nil end
  local nr = 0
  for _, st in ipairs(r.stationen) do
    if not st.erledigt then
      nr = nr + 1
      if st.id == questID then return nr end
    end
  end
end

function N:RoutePlanen()
  QK.Kompass:Auffrischen()
  local px, py = QK.Kompass:Spieler()
  if not px then QK:Meldung(L"deine Position ist hier nicht bekannt, eine Route geht nur im Freien.") return end
  local punkte = { { x = px, y = py } }
  local ziele = QK.Kompass:Ziele()
  for _, q in ipairs(QK.Compat:Questlog()) do
    local z = ziele[q.id]
    if z and not QK.char.ausgeblendet[q.id] then
      punkte[#punkte + 1] = { x = z[1], y = z[2], id = q.id, fertig = q.fertig, titel = q.titel }
    end
  end
  if #punkte < 2 then QK:Meldung(L"keine Quest mit Ziel auf dieser Karte.") return end
  local weg = N:Reihenfolge(punkte)
  local stationen = {}
  for i = 2, #weg do
    local p = punkte[weg[i]]
    stationen[#stationen + 1] = { id = p.id, warFertig = p.fertig }
  end
  QK.char.route = { karte = QK.Kompass:Karte(), stationen = stationen, laenge = Laenge(punkte, weg) }
  QK.Compat:FokusSetzen(stationen[1].id)
  QK:Meldung(L"Route mit %d Stationen, etwa %s Weg. Der Fokuspfeil führt dich Station für Station.",
    #stationen, QK:EntfernungText(QK.char.route.laenge))
  QK:Sprechen((L"Route mit %d Stationen."):format(#stationen))
  QK:Anwenden()
end

function N:RouteBeenden(geschafft)
  if not QK.char.route then return end
  QK.char.route = nil
  if geschafft then QK.char.routenGeschafft = (QK.char.routenGeschafft or 0) + 1 end
  if geschafft and QK.Meldungen and QK.db.meldungen then
    QK.Meldungen:Zeigen(L"ROUTE GESCHAFFT", L"Alle Stationen erledigt")
  elseif not geschafft then
    QK:Meldung(L"Route beendet.")
  end
  QK:Anwenden()
end

function N:RoutePruefen()
  local r = QK.char.route
  if not r then return end
  local log = {}
  for _, q in ipairs(QK.Compat:Questlog()) do log[q.id] = q end
  local erste, nr, gesamt = nil, 0, #r.stationen
  for _, st in ipairs(r.stationen) do
    local q = log[st.id]
    if not st.erledigt and (not q or (q.fertig and not st.warFertig)) then st.erledigt = true end
    if not st.erledigt and not erste then erste = st end
    if st.erledigt then nr = nr + 1 end
  end
  if not erste then N:RouteBeenden(true) return end
  local fokus = QK.Compat:Fokus()
  local alterFokusFertig = false
  for _, st in ipairs(r.stationen) do if st.id == fokus and st.erledigt then alterFokusFertig = true end end
  if not fokus or alterFokusFertig then
    QK.Compat:FokusSetzen(erste.id)
    local q = log[erste.id]
    if QK.Meldungen and QK.db.meldungen and q then
      QK.Meldungen:Zeigen((L"STATION %d VON %d"):format(nr + 1, gesamt), q.titel)
    end
    if QK.Tracker then QK.Tracker:Planen() end
  end
end

---------------------------------------------------------------------------
-- Eigene Wegpunkte
---------------------------------------------------------------------------
function N:Wegpunkt() return QK.char and QK.char.wegpunkt end

function N:WegpunktSetzen(karte, x, y, name)
  if not karte or not x or not y then return end
  QK.char.wegpunkt = { karte = karte, x = x, y = y, name = name or L"Wegpunkt" }
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    N.eigenerPunkt = true
    pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(karte, x, y))
    N.eigenerPunkt = false
  end
  QK:Meldung(L"Wegpunkt %s bei %.1f, %.1f gesetzt. Der Fokuspfeil führt dich hin.", QK.char.wegpunkt.name, x * 100, y * 100)
  if not QK.db.pfeilGross then QK:Meldung(L"Tipp: Der große Fokuspfeil ist ausgeschaltet, /qk einstellungen schaltet ihn ein.") end
  if QK.Pfeil then QK.Pfeil:Aktualisieren() end
end

function N:WegpunktLoeschen(erreicht)
  if not QK.char.wegpunkt then return end
  local name = QK.char.wegpunkt.name
  QK.char.wegpunkt = nil
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  local kette = QK.char.wegkette
  if erreicht then
    local naechster = kette and table.remove(kette, 1)
    if naechster then
      if QK.Meldungen and QK.db.meldungen then
        QK.Meldungen:Zeigen(L"WEGPUNKT ERREICHT", (L"weiter zu %s (%d übrig)"):format(naechster.name, #kette))
      end
      QK.char.wegpunkt = naechster
      if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        N.eigenerPunkt = true
        pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(naechster.karte, naechster.x, naechster.y))
        N.eigenerPunkt = false
      end
    elseif QK.Meldungen and QK.db.meldungen then
      QK.Meldungen:Zeigen(L"WEGPUNKT ERREICHT", name)
    end
  else
    QK.char.wegkette = nil
    QK:Meldung(L"Wegpunkt gelöscht.")
  end
  if QK.Pfeil then QK.Pfeil:Aktualisieren() end
end

-- Wegpunkt-Kette: weitere Punkte, die nacheinander angesteuert werden
function N:KetteAnhaengen(karte, x, y, name)
  if not N:Wegpunkt() then N:WegpunktSetzen(karte, x, y, name) return end
  QK.char.wegkette = QK.char.wegkette or {}
  local kette = QK.char.wegkette
  kette[#kette + 1] = { karte = karte, x = x, y = y, name = name or (L"Wegpunkt %d"):format(#kette + 2) }
  QK:Meldung(L"Wegpunkt %s an die Kette gehängt (%d warten).", kette[#kette].name, #kette)
end

-- Wegpunkt auf der aktuellen Karte (umgerechnet), sonst nil
function N:WegpunktHier()
  local w = N:Wegpunkt()
  if not w then return nil end
  return QK.Kompass:Umrechnen(w.karte, w.x, w.y)
end

local function Zahl(t) return tonumber(((t or ""):gsub(",", "."))) end

local function WegBefehl(rest, anhaengen)
  if rest == "" or rest == "aus" or rest == "löschen" or rest == "loeschen" then
    if N:Wegpunkt() then N:WegpunktLoeschen() else QK:Meldung(L"Beispiel: /qk weg 45,2 60,8 Brunnen") end
    return
  end
  local a, b, name = rest:match("^([%d%.,]+)%s+([%d%.,]+)%s*(.-)$")
  local x, y = Zahl(a), Zahl(b)
  if not x or not y or x > 100 or y > 100 then QK:Meldung(L"Beispiel: /qk weg 45,2 60,8 Brunnen") return end
  QK.Kompass:Auffrischen()
  local karte = QK.Kompass:Karte()
  if not karte then QK:Meldung(L"die aktuelle Karte ist nicht bekannt.") return end
  if anhaengen then
    N:KetteAnhaengen(karte, x / 100, y / 100, name ~= "" and name or nil)
  else
    QK.char.wegkette = nil
    N:WegpunktSetzen(karte, x / 100, y / 100, name ~= "" and name or nil)
  end
end

-- Alt+Klick auf die Weltkarte setzt einen Wegpunkt
local function KarteVerbinden()
  local wm = WorldMapFrame
  local sc = wm and wm.ScrollContainer
  if N.karteVerbunden or not sc or not sc.GetNormalizedCursorPosition then return end
  N.karteVerbunden = true
  sc:HookScript("OnMouseUp", function(self, taste)
    if taste ~= "LeftButton" or not IsAltKeyDown() then return end
    QK:Sicher("Weltkarte", function()
      local x, y = self:GetNormalizedCursorPosition()
      local karte = wm.GetMapID and wm:GetMapID()
      if karte and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        if IsShiftKeyDown() then N:KetteAnhaengen(karte, x, y, nil)
        else QK.char.wegkette = nil; N:WegpunktSetzen(karte, x, y, L"Kartenpunkt") end
      end
    end)
  end)
end

-- Setzt der Spieler selbst einen Punkt im Spiel (Strg+Klick), übernehmen wir ihn.
local function SpielWegpunkt()
  if N.eigenerPunkt or not (C_Map and C_Map.GetUserWaypoint) then return end
  local ok, punkt = pcall(C_Map.GetUserWaypoint)
  if ok and punkt and punkt.uiMapID and punkt.position then
    local x, y = punkt.position:GetXY()
    local w = N:Wegpunkt()
    if not w or w.karte ~= punkt.uiMapID or math.abs(w.x - x) > 0.001 or math.abs(w.y - y) > 0.001 then
      QK.char.wegpunkt = { karte = punkt.uiMapID, x = x, y = y, name = L"Kartenpunkt" }
      if QK.Pfeil then QK.Pfeil:Aktualisieren() end
    end
  end
end

---------------------------------------------------------------------------
-- Pfeil am Rand der Minikarte
---------------------------------------------------------------------------
local randPfeil

local function ZielPunkt()
  local x, y = N:WegpunktHier()
  if x then return x, y end
  local fokus = QK.Compat:Fokus()
  if fokus then return QK.Kompass:Ziel(fokus) end
end

function N:Minikarte()
  if not randPfeil then return end
  if not QK.db.minimapPfeil or not Minimap:IsVisible() then randPfeil:Hide() return end
  local x, y = ZielPunkt()
  if not x then randPfeil:Hide() return end
  local winkel, entfernung, peilung = QK.Kompass:RichtungZuPunkt(x, y)
  if not entfernung or not peilung then randPfeil:Hide() return end
  local zoom = Minimap.GetZoom and Minimap:GetZoom() or 0
  local drinnen = IsIndoors and IsIndoors()
  local radius = ((drinnen and DRINNEN[zoom] or DRAUSSEN[zoom]) or 400) / 2
  if entfernung <= radius * 0.95 then randPfeil:Hide() return end
  local dreht = GetCVar and GetCVar("rotateMinimap") == "1"
  local a = dreht and winkel or peilung
  if not a then randPfeil:Hide() return end
  local r = (Minimap:GetWidth() or 140) / 2 + 4
  randPfeil:ClearAllPoints()
  randPfeil:SetPoint("CENTER", Minimap, "CENTER", math.sin(a) * r, math.cos(a) * r)
  randPfeil.t:SetRotation(-a)
  local f = QK.farben.gold
  randPfeil.t:SetVertexColor(f[1], f[2], f[3])
  randPfeil:Show()
end

---------------------------------------------------------------------------
-- Abgabe-Erinnerung
---------------------------------------------------------------------------
local erinnert = {}
function N:Abgabe()
  if not QK.db.abgabeErinnerung or InCombatLockdown() then return end
  for _, q in ipairs(QK.Compat:Questlog()) do
    if q.fertig then
      local d = QK.Kompass:Entfernung(q.id)
      if d and d < 60 and not erinnert[q.id] then
        erinnert[q.id] = true
        if QK.Meldungen then QK.Meldungen:Zeigen(L"ABGABE IN DER NÄHE", q.titel) end
      elseif d and d > 150 then
        erinnert[q.id] = nil
      end
    end
  end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
-- Restweg der Route ab der aktuellen Station (Luftlinie), Anzahl offener Stationen
function N:Restweg()
  local r = QK.char.route
  if not r then return nil end
  local px, py = QK.Kompass:Spieler()
  local summe, offen, lx, ly = 0, 0, px, py
  for _, st in ipairs(r.stationen) do
    if not st.erledigt then
      offen = offen + 1
      local x, y = QK.Kompass:Ziel(st.id)
      if x and lx then summe = summe + QK.Kompass:Abstand(lx, ly, x, y); lx, ly = x, y end
    end
  end
  return summe, offen, #r.stationen
end

---------------------------------------------------------------------------
-- „Was jetzt?“: wählt das sinnvollste nächste Ziel
---------------------------------------------------------------------------
function N:WasJetzt()
  local quests = QK.Compat:Questlog()
  local abgabe, abgabeD, naechste, naechsteD, fertigIrgendwo
  for _, q in ipairs(quests) do
    if not QK.char.ausgeblendet[q.id] and not q.gescheitert then
      local d = QK.Kompass:Entfernung(q.id)
      if q.fertig then
        fertigIrgendwo = fertigIrgendwo or q
        if d and (not abgabeD or d < abgabeD) then abgabe, abgabeD = q, d end
      elseif d and (not naechsteD or d < naechsteD) then
        naechste, naechsteD = q, d
      end
    end
  end
  local q, text
  if abgabe and (abgabeD < 300 or not naechste) then
    q, text = abgabe, (L"Abgeben: %s"):format(abgabe.titel)
  elseif naechste then
    q, text = naechste, (L"Weiter mit: %s"):format(naechste.titel)
  elseif fertigIrgendwo then
    q, text = fertigIrgendwo, (L"Abgeben: %s"):format(fertigIrgendwo.titel)
  end
  if q then
    QK.Compat:FokusSetzen(q.id)
    local d = QK.Kompass:Entfernung(q.id)
    if d then text = text .. " (" .. QK:EntfernungText(d) .. ")" end
    QK:Anwenden()
  else
    local v = QK.Planer and QK.Planer:Vorschlaege(1)[1]
    if v then
      text = (L"Neue Quest holen: %s in %s"):format(v.name or ("Quest " .. v.id), QK:GebietName(v.gebiet) or "?")
    else
      text = L"Keine Quest im Log. Schau im Questbuch nach neuen Aufgaben."
    end
  end
  if QK.Meldungen then QK.Meldungen:Zeigen(L"WAS JETZT?", text) end
  QK:Sprechen(text, true)
  return text
end

function N:Start()
  if Minimap then
    randPfeil = CreateFrame("Frame", "QuestkompassRandpfeil", Minimap)
    randPfeil:SetSize(22, 22)
    randPfeil:SetFrameStrata("MEDIUM")
    randPfeil:SetFrameLevel(9)
    randPfeil.t = randPfeil:CreateTexture(nil, "OVERLAY")
    randPfeil.t:SetAllPoints()
    randPfeil.t:SetTexture(PFEIL)
    randPfeil:Hide()
  end
  local takt, langsam = 0, 0
  local uhr = CreateFrame("Frame")
  uhr:SetScript("OnUpdate", function(_, el)
    takt, langsam = takt + el, langsam + el
    if takt >= 0.1 then
      takt = 0
      QK.Kompass:Auffrischen(GetTime())
      QK:Sicher("Minikartenpfeil", N.Minikarte, N)
    end
    if langsam >= 2 then
      langsam = 0
      QK:Sicher("Abgabe-Erinnerung", N.Abgabe, N)
    end
  end)
  local geplant = false
  QK:Ereignis("QUEST_LOG_UPDATE", function()
    if geplant or not QK.char.route then return end
    geplant = true
    C_Timer.After(0.4, function() geplant = false; QK:Sicher("Route", N.RoutePruefen, N) end)
  end)
  QK:Ereignis("USER_WAYPOINT_UPDATED", SpielWegpunkt)
  QK:Ereignis("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then KarteVerbinden() end end)
  KarteVerbinden()

  QK:Haken("menue", function(q)
    local e = {}
    if QK.char.route then
      e[#e + 1] = { L"Route beenden", function() N:RouteBeenden() end }
    else
      e[#e + 1] = { L"Route durch alle Quests planen", function() N:RoutePlanen() end }
    end
    if N:Wegpunkt() then e[#e + 1] = { L"Wegpunkt löschen", function() N:WegpunktLoeschen() end } end
    return e
  end)
end

QK:Befehl({ "route" }, function(rest)
  if rest == "aus" or (rest == "" and QK.char.route) then N:RouteBeenden() else N:RoutePlanen() end
end, L"/qk route – kürzeste Route durch alle Quests der Karte (nochmal: beenden)")
QK:Befehl({ "weg", "wegpunkt" }, WegBefehl, L"/qk weg X Y [Name] – eigener Wegpunkt, Alt+Klick auf die Weltkarte geht auch")
QK:Befehl({ "kette" }, function(rest) WegBefehl(rest, true) end, L"/qk kette X Y [Name] – Wegpunkt hinten anhängen (Umschalt+Alt+Klick auf die Karte)")
QK:Befehl({ "wasjetzt", "jetzt" }, function() N:WasJetzt() end, L"/qk wasjetzt – das sinnvollste nächste Ziel als Fokus")
QK.tasten.wasjetzt = function() N:WasJetzt() end
QK.tasten.route = function() if QK.char.route then N:RouteBeenden() else N:RoutePlanen() end end
