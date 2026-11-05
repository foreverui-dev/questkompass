-- Questkompass: kurze Meldungen, wenn ein Ziel oder eine ganze Quest fertig wird.
local _, QK = ...
local M = QK:Modul("Meldungen")

local stand = nil          -- questID -> { fertig, ziele = { [i] = fertig } }
local anzeige
local HAKEN = "|TInterface\\RaidFrame\\ReadyCheck-Ready:16:16:0:0|t "

local function Erstellen()
  anzeige = CreateFrame("Frame", "QuestkompassMeldung", UIParent)
  anzeige:SetSize(400, 50)
  anzeige:SetPoint("TOP", UIParent, "TOP", 0, -150)
  anzeige:SetFrameStrata("HIGH")
  anzeige.oben = anzeige:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  anzeige.oben:SetPoint("TOP")
  anzeige.oben:SetTextColor(unpack(QK.farben.gold))
  anzeige.text = anzeige:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  anzeige.text:SetPoint("TOP", anzeige.oben, "BOTTOM", 0, -4)
  anzeige:Hide()
  anzeige:SetScript("OnUpdate", function(self, el)
    self.zeit = self.zeit + el
    if self.zeit < 0.25 then self:SetAlpha(self.zeit / 0.25)
    elseif self.zeit < 3 then self:SetAlpha(1)
    elseif self.zeit < 4 then self:SetAlpha(4 - self.zeit)
    else self:Hide() end
  end)
end

function M:Zeigen(oben, text)
  if not anzeige then Erstellen() end
  anzeige.oben:SetText(oben)
  anzeige.text:SetText(text)
  anzeige.zeit = 0
  anzeige:SetAlpha(0)
  anzeige:Show()
end

local function Klang()
  if not QK.db.klang then return end
  local id = SOUNDKIT and (SOUNDKIT.IG_QUEST_LIST_COMPLETE or SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01)
  pcall(PlaySound, id or 878)
end

-- Fortschritt in den Gruppenchat (nur in kleinen Gruppen, nie im Schlachtzug).
local letzteGruppenMeldung = 0
local function Gruppe(text)
  if not QK.db.gruppenMeldungen then return end
  local inGruppe = (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0)
  if not inGruppe or (IsInRaid and IsInRaid()) then return end
  local jetzt = GetTime()
  if jetzt - letzteGruppenMeldung < 1 then return end
  letzteGruppenMeldung = jetzt
  SendChatMessage("[Questkompass] " .. text, "PARTY")
end

local function Pruefen()
  local neu = {}
  for _, q in ipairs(QK.Compat:Questlog()) do
    local s = { fertig = q.fertig, ziele = {}, ist = {} }
    for i, z in ipairs(q.ziele) do s.ziele[i] = z.fertig; s.ist[i] = z.ist end
    neu[q.id] = s
    local alt = stand and stand[q.id]
    if alt then
      if q.fertig and not alt.fertig then
        if QK.db.meldungen then M:Zeigen("BEREIT ZUM ABGEBEN", HAKEN .. q.titel); Klang() end
        Gruppe(q.titel .. " ist fertig.")
      elseif not q.fertig then
        for i, z in ipairs(q.ziele) do
          if z.fertig and alt.ziele[i] == false then
            if QK.db.meldungen then
              M:Zeigen(q.titel, HAKEN .. z.text .. ((z.soll and z.soll > 1) and (" " .. z.soll .. "/" .. z.soll) or ""))
            end
            Gruppe(("%s: %s erledigt"):format(q.titel, z.text))
          elseif z.ist and alt.ist[i] and z.ist > alt.ist[i] and z.soll then
            Gruppe(("%s: %s %d/%d"):format(q.titel, z.text, z.ist, z.soll))
          end
        end
      end
    end
  end
  stand = neu
end

function M:Start()
  QK:Ereignis("QUEST_LOG_UPDATE", function()
    C_Timer.After(0.2, function() QK:Sicher("Meldungen", Pruefen) end)
  end)
end
