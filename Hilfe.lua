-- Questkompass: Textbereiche im Hauptfenster (wie beim Forever DPS Meter). Teilen und Übernehmen,
-- Fehlerbericht zum Kopieren und Discord-Link, damit sich dafür kein eigenes Fenster mehr öffnet.
local _, QK = ...
local H = QK:Modul("Hilfe")
local UI = QK.UI
local L = QK.L

-- Einladung in den Discord von ForeverUI (nur hier ändern)
H.DISCORD = "https://discord.gg/Sh8zyYUKRX"

-- Rahmen mit Überschrift und einem schreibgeschützten Textfeld (Klick markiert, Strg+C kopiert).
-- platzRechts: Breite, die rechts neben der Überschrift frei bleibt (für einen Knopf)
-- platzUnten: Höhe unten für Knöpfe
local function TextRahmen(name, platzRechts, platzUnten)
  local r = CreateFrame("Frame", name, UIParent)
  r:SetSize(600, 440)
  r:Hide()
  r.kopf = UI.Text(r, "GameFontHighlightSmall", "", 570 - (platzRechts or 0))
  r.kopf:SetPoint("TOPLEFT", 14, -12)
  r.kopf:SetJustifyV("TOP")
  local rolle = CreateFrame("ScrollFrame", name and (name .. "Rolle") or nil, r, "UIPanelScrollFrameTemplate")
  UI.Bildlauf(rolle)
  rolle:SetPoint("TOPLEFT", 14, -56)
  rolle:SetPoint("BOTTOMRIGHT", -30, platzUnten or 12)
  local feld = CreateFrame("EditBox", name and (name .. "Text") or nil, rolle)
  feld:SetMultiLine(true)
  feld:SetFontObject(ChatFontNormal or "GameFontHighlightSmall")
  feld:SetWidth(560)
  feld:SetAutoFocus(false)
  feld:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  UI.Schreibschutz(feld)
  rolle:SetScrollChild(feld)
  r:SetScript("OnSizeChanged", function(self, w)
    if type(w) == "number" and w > 200 then
      feld:SetWidth(w - 60)
      self.kopf:SetWidth(w - 30 - (platzRechts or 0))
    end
  end)
  r.feld = feld
  return r
end

-- nurErste: nur die erste Zeile markieren (z. B. einen Link)
local function zeigen(r, kopf, zeilen, nurErste)
  r.kopf:SetText(kopf or L"Text markiert: Strg+C kopiert ihn.")
  r.feld.nurLesen = true
  UI.Lesetext(r.feld, table.concat(zeilen, "\n"), nurErste and zeilen[1] and #zeilen[1] or nil)
  r.feld:SetFocus()
  if nurErste and zeilen[1] then r.feld:HighlightText(0, #zeilen[1]) else r.feld:HighlightText() end
end

local function zeilenVon(text)
  local t = {}
  for z in (text .. "\n"):gmatch("([^\n]*)\n") do t[#t + 1] = z end
  return t
end

---------------------------------------------------------------------------
-- Teilen und Übernehmen: eigene Einstellungen, fremder Text, Tagebuch als Text
---------------------------------------------------------------------------
H.art, H.text = "export", nil
local teilen
local function TeilenHolen()
  if teilen then return teilen end
  local f = TextRahmen("QuestkompassTeilen", nil, 44)
  local x = 14
  local function knopf(text, breite, fn)
    local k = QK.FlachKnopf(f)
    k:SetSize(breite, 22)
    k:SetText(text)
    k:SetPoint("BOTTOMLEFT", x, 12)
    k:SetScript("OnClick", fn)
    x = x + breite + 8
    return k
  end
  knopf(L"Meine Einstellungen", 150, function() H:Teilen("export") end)
  knopf(L"Fremden Text einfügen", 160, function() H:Teilen("import") end)
  knopf(L"Tagebuch als Text", 140, function() H:Teilen("tagebuch") end)
  f.ok = QK.FlachKnopf(f)
  f.ok:SetSize(110, 22)
  f.ok:SetText(L"Übernehmen")
  f.ok:SetPoint("BOTTOMRIGHT", -14, 12)
  f.ok:SetScript("OnClick", function()
    local geklappt, n = QK.Extras:Import(f.feld:GetText())
    if geklappt then QK:Meldung(L"%d Einstellungen übernommen.", n); QK.Assistent:Auffrischen()
    else QK:Meldung(L"Dieser Text enthält keine Questkompass-Einstellungen.") end
  end)
  f.text = f.feld
  teilen = f
  return f
end

local function TeilenZeichnen()
  local f = TeilenHolen()
  local art = H.art
  if art == "import" then
    f.kopf:SetText(L"Füge hier Einstellungen ein, die dir jemand geschickt hat (Strg+V), und klick auf „Übernehmen“.")
    f.feld.nurLesen = false
    f.feld.inhalt = nil
    if not f.importBereit then f.feld:SetText(""); f.importBereit = true end
    f.ok:Show()
    f.feld:SetFocus()
    return
  end
  f.importBereit = nil
  f.ok:Hide()
  local text = H.text or (art == "tagebuch" and QK.Unterwegs and QK.Unterwegs:TagebuchText()) or QK.Extras:Export()
  zeigen(f, art == "tagebuch" and L"Die letzten 50 Einträge deines Tagebuchs. Ein Klick markiert alles, Strg+C kopiert."
    or art == "text" and L"Ein Klick markiert alles, Strg+C kopiert."
    or L"Deine Einstellungen als Text. Ein Klick markiert alles, Strg+C kopiert. So gibst du sie an Freunde oder deinen Twink weiter.",
    zeilenVon(text))
end

-- art: "export" | "import" | "tagebuch" | "text"; text: eigener Text statt des üblichen
function H:Teilen(art, text, titel)
  H.art, H.text = art or "export", text
  local b = QK.Assistent.bereiche.teilen
  if b then b.titel = titel or L"Teilen und Übernehmen" end
  QK.Assistent:Bereich("teilen")
end

---------------------------------------------------------------------------
-- Fehlerbericht: alles, was beim Helfen nützt, in einem Text
---------------------------------------------------------------------------
function H:Fehlerbericht()
  local t = { ("Questkompass %s · Stand %s · Spiel %s · %s"):format(tostring(QK.version), QK.codeStand or "?",
    tostring(select(4, GetBuildInfo())), GetLocale and GetLocale() or "?") }
  t[#t + 1] = ("Questdaten %s, Quest-API %s"):format(QK.datenStand or "?", QK.Compat and QK.Compat.modern and "modern" or "klassisch")
  local liste = QK.root.fehler or {}
  t[#t + 1] = ""
  t[#t + 1] = (#liste == 0) and L"Keine Fehler aufgezeichnet." or ("Letzte Fehler (%d):"):format(#liste)
  for _, e in ipairs(liste) do t[#t + 1] = "  " .. e end
  return t
end

local bericht
local function BerichtZeichnen()
  zeigen(bericht, (L"Kopier diesen Text (Strg+C) und schick ihn uns im Discord von ForeverUI (%s). Er enthält keine persönlichen Daten außer Spielversion und Einstellungen."):format(H.DISCORD),
    H:Fehlerbericht())
end

---------------------------------------------------------------------------
-- Discord und Feedback: Link zum Kopieren (Addons kommen im Spiel nicht ins Internet)
---------------------------------------------------------------------------
function H:FeedbackZeilen()
  return {
    H.DISCORD,
    "",
    L"Im Discord von ForeverUI kannst du Fragen stellen, Ideen und Wünsche teilen und Fehler melden. Wir lesen alles und freuen uns über jede Rückmeldung.",
    L"Den Link oben kopierst du mit Strg+C und fügst ihn im Browser oder in Discord ein.",
    "",
    L"Oder als Kommentar auf der Seite von Questkompass bei CurseForge.",
    L"Bei Fehlern hilft der Text unter Hilfe > Fehler melden (/qk fehlerbericht).",
  }
end

local discord
function H:Feedback() QK.Assistent:Bereich("discord") end

---------------------------------------------------------------------------
-- Anmelden (bei jedem Sprachwechsel neu, damit die Titel stimmen)
---------------------------------------------------------------------------
function H:Anmelden()
  local A = QK.Assistent
  A:BereichAnmelden("teilen", L"Teilen und Übernehmen", TeilenHolen, TeilenZeichnen)
  A:BereichAnmelden("fehlerbericht", L"Fehler melden", function()
    if not bericht then
      bericht = TextRahmen("QuestkompassFehlerbericht", 140)
      local leeren = UI.Knopf(bericht, L"Fehlerliste leeren", 120, function()
        QK.root.fehler = {}
        BerichtZeichnen()
      end)
      leeren:SetPoint("TOPRIGHT", -14, -8)
    end
    return bericht
  end, BerichtZeichnen)
  A:BereichAnmelden("discord", L"Discord und Feedback", function()
    if not discord then discord = TextRahmen("QuestkompassDiscord") end
    return discord
  end, function()
    zeigen(discord, L"Feedback und Ideen: Link markiert, Strg+C kopiert ihn.", H:FeedbackZeilen(), true)
  end)
end

-- Nach einem Sprachwechsel entstehen die Rahmen neu
function H:Neubauen() teilen, bericht, discord = nil, nil, nil end

function H:Start() H:Anmelden() end

QK:Befehl({ "fehlerbericht", "bugreport" }, function() QK.Assistent:Bereich("fehlerbericht") end,
  L"/qk fehlerbericht – Text für einen Fehlerbericht")
QK:Befehl({ "feedback", "discord" }, function() H:Feedback() end, L"/qk feedback – Link zum Discord für Ideen und Fehler")
