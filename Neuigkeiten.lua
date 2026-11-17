-- Questkompass: Neuigkeiten im Hauptfenster (aus Aenderungen.lua), Hinweis nach einem Update und
-- Hinweis auf neuere Versionen (wie beim Forever DPS Meter). Addons kommen im Spiel nicht ins Internet,
-- darum tauschen Nutzer ihre Version unsichtbar über den Addon-Kanal in Gruppe und Gilde aus.
local _, QK = ...
local N = QK:Modul("Neuigkeiten")
local UI = QK.UI
local L = QK.L

QK.STANDARD.updateHinweis = false   -- Hinweis, wenn jemand in Gruppe oder Gilde eine neuere Version hat

local PRAEFIX = "Questkompass"     -- derselbe Kanal wie der Gruppen-Abgleich, Nachrichten beginnen mit „V:“

---------------------------------------------------------------------------
-- Versionen vergleichen: "1.1.0" < "1.10.0"; "dev" oder Unbekanntes zählt nicht
---------------------------------------------------------------------------
local function teile(v)
  if type(v) ~= "string" then return nil end
  local a, b, c = v:match("^v?(%d+)%.(%d+)%.?(%d*)")
  if not a then return nil end
  return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end

function N.Neuer(a, b)   -- ist a neuer als b?
  local x, y = teile(a), teile(b)
  if not x or not y then return false end
  for i = 1, 3 do
    if x[i] ~= y[i] then return x[i] > y[i] end
  end
  return false
end

---------------------------------------------------------------------------
-- Text der Neuigkeiten
---------------------------------------------------------------------------
function N:Text(anzahl)
  local t = {}
  for i, v in ipairs(QK.AENDERUNGEN or {}) do
    if anzahl and i > anzahl then break end
    local punkte = (QK.englischUI and v.en) or v.de or v.en or {}
    local kopf = (L"Version %s"):format(v.version)
    if v.version == QK.version then kopf = kopf .. " " .. L"(installiert)" end
    t[#t + 1] = QK.gold .. kopf .. "|r"
    for _, p in ipairs(punkte) do t[#t + 1] = "• " .. p end
    t[#t + 1] = " "
  end
  if #t == 0 then t[1] = L"Keine Neuigkeiten gefunden." end
  return table.concat(t, "\n")
end

---------------------------------------------------------------------------
-- Bereich im Hauptfenster
---------------------------------------------------------------------------
local rahmen
local function Bauen()
  rahmen = CreateFrame("Frame", "QuestkompassNeuigkeiten", UIParent)
  rahmen:SetSize(560, 440)
  rahmen:Hide()
  local hinweis = UI.Text(rahmen, "GameFontDisableSmall", "", 380)
  hinweis:SetPoint("BOTTOMLEFT", 14, 10)
  rahmen.hinweis = hinweis
  local feedback = UI.Knopf(rahmen, L"Feedback und Ideen", 140, function() QK.Hilfe:Feedback() end)
  feedback:SetPoint("BOTTOMRIGHT", -14, 6)
  local rolle = CreateFrame("ScrollFrame", "QuestkompassNeuigkeitenRolle", rahmen, "UIPanelScrollFrameTemplate")
  UI.Bildlauf(rolle)
  rolle:SetPoint("TOPLEFT", 14, -14)
  rolle:SetPoint("BOTTOMRIGHT", -30, 44)
  local inhalt = CreateFrame("Frame", nil, rolle)
  inhalt:SetSize(560, 1200)
  rolle:SetScrollChild(inhalt)
  rahmen.text = UI.Text(inhalt, "GameFontHighlight", "", 580)
  rahmen.text:SetPoint("TOPLEFT", 0, 0)
  rahmen.text:SetJustifyV("TOP")
  rahmen.text:SetSpacing(3)
  rahmen.inhalt = inhalt
  -- Text an die Breite des Hauptfensters anpassen, damit rechts nichts abgeschnitten wird
  rahmen:SetScript("OnSizeChanged", function(self, w)
    if type(w) == "number" and w > 200 then
      inhalt:SetWidth(w - 50); self.text:SetWidth(w - 50); hinweis:SetWidth(w - 190)
      N:Zeichnen()
    end
  end)
end

function N:Zeichnen()
  if not rahmen then return end
  rahmen.text:SetText(self:Text())
  local h = rahmen.text.GetStringHeight and rahmen.text:GetStringHeight()
  if type(h) == "number" and h > 0 then rahmen.inhalt:SetHeight(h + 20) end
  local neu = QK.root and QK.root.neuesteVersion
  if neu and N.Neuer(neu, QK.version) then
    rahmen.hinweis:SetText((L"Version %s ist verfügbar, du hast %s. Aktualisieren über die CurseForge-App oder curseforge.com."):format(neu, QK.version))
  else
    rahmen.hinweis:SetText((L"Installiert: Version %s"):format(QK.version))
  end
end

function N:Zeigen() QK.Assistent:Bereich("neuigkeiten") end

function N:Anmelden()
  QK.Assistent:BereichAnmelden("neuigkeiten", L"Neuigkeiten", function()
    if not rahmen then Bauen() end
    return rahmen
  end, function() N:Zeichnen() end)
end

function N:Neubauen() rahmen = nil end

QK:Befehl({ "neu", "news", "neuigkeiten", "changelog" }, function() N:Zeigen() end, L"/qk neu – Neuigkeiten und Änderungen")

---------------------------------------------------------------------------
-- Nach einem Update: einmal kurz im Chat Bescheid geben
---------------------------------------------------------------------------
function N:UpdatePruefen()
  local root = QK.root
  if not root or not teile(QK.version) then return end
  local alt = root.gesehenVersion
  root.gesehenVersion = QK.version
  if alt and N.Neuer(QK.version, alt) and QK.db.eingerichtet and QK.db.updateHinweis then
    QK:Meldung(L"auf Version %s aktualisiert. Was neu ist: %s/qk neu|r", QK.version, QK.gold)
  end
  if root.neuesteVersion and not N.Neuer(root.neuesteVersion, QK.version) then root.neuesteVersion = nil end
end

---------------------------------------------------------------------------
-- Versionen austauschen (Gruppe, Schlachtzug, Gilde)
---------------------------------------------------------------------------
local gesendet, gemeldet = {}, false

local function imKampf()
  return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function senden(kanal)
  if not teile(QK.version) or imKampf() then return end
  local jetzt = GetTime()
  if gesendet[kanal] and jetzt - gesendet[kanal] < 60 then return end
  gesendet[kanal] = jetzt
  local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
  if fn then pcall(fn, PRAEFIX, "V:" .. QK.version, kanal) end
end

function N:Senden()
  if IsInGuild and IsInGuild() then senden("GUILD") end
  if IsInRaid and IsInRaid() then
    senden((IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID")
  elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) then
    senden((LE_PARTY_CATEGORY_INSTANCE and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY")
  end
end

function N:Empfangen(praefix, text, kanal)
  praefix, text = QK.Text(praefix), QK.Text(text)
  if praefix ~= PRAEFIX or not text then return end
  local v = text:match("^V:(%S+)$")
  if not v or not teile(v) then return end
  if N.Neuer(v, QK.version) then
    if not QK.root.neuesteVersion or N.Neuer(v, QK.root.neuesteVersion) then QK.root.neuesteVersion = v end
    if QK.db.updateHinweis and not gemeldet then
      gemeldet = true
      QK:Meldung(L"Version %s ist verfügbar (du hast %s). Aktualisieren über die CurseForge-App oder curseforge.com.", v, QK.version)
    end
  elseif N.Neuer(QK.version, v) and kanal then
    -- der andere hat eine ältere Version: unsere einmal zurückschicken, damit er Bescheid bekommt
    senden(kanal)
  end
end

function N:Start()
  N:Anmelden()
  self:UpdatePruefen()
  C_Timer.After(15, function() QK:Sicher("Version senden", N.Senden, N) end)
  QK:Ereignis("CHAT_MSG_ADDON", function(praefix, text, kanal)
    QK:Sicher("Version empfangen", N.Empfangen, N, praefix, text, kanal)
  end)
  QK:Ereignis("GROUP_ROSTER_UPDATE", function() QK:Sicher("Version senden", N.Senden, N) end)
  QK:Ereignis("PLAYER_REGEN_ENABLED", function() C_Timer.After(5, function() QK:Sicher("Version senden", N.Senden, N) end) end)
end
