-- Questkompass: eigene kurze Notiz je Quest, sichtbar in der Liste und im Tooltip.
local _, QK = ...
local NO = QK:Modul("Notizen")
local L = QK.L

local SYMBOL = "|TInterface\\Buttons\\UI-GuildButton-PublicNote-Up:12:12:0:0|t "

function NO:Text(questID) return QK.char and QK.char.notizen[questID] end

function NO:Setzen(questID, text)
  text = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
  if text == "" then text = nil end
  if text and #text > 120 then text = text:sub(1, 120) end
  QK.char.notizen[questID] = text
  if QK.Tracker then QK.Tracker:Planen() end
end

local function EditBox(dialog) return dialog.editBox or dialog.EditBox end

function NO:Bearbeiten(questID, titel)
  if not StaticPopupDialogs then return end
  StaticPopupDialogs.QUESTKOMPASS_NOTIZ = StaticPopupDialogs.QUESTKOMPASS_NOTIZ or {
    text = L"Notiz zu „%s“",
    button1 = L"Speichern",
    button2 = L"Abbrechen",
    button3 = L"Löschen",
    hasEditBox = 1,
    maxLetters = 120,
    editBoxWidth = 260,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    OnShow = function(self, daten)
      local e = EditBox(self)
      if e then e:SetText(NO:Text(daten) or ""); e:HighlightText(); e:SetFocus() end
    end,
    OnAccept = function(self, daten) local e = EditBox(self); NO:Setzen(daten, e and e:GetText()) end,
    OnAlt = function(_, daten) NO:Setzen(daten, nil) end,
    EditBoxOnEnterPressed = function(self)
      local dialog = self:GetParent()
      NO:Setzen(dialog.data, self:GetText())
      dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  }
  StaticPopup_Show("QUESTKOMPASS_NOTIZ", titel, nil, questID)
end

function NO:Start()
  QK:Haken("zeilen", function(q)
    local t = QK.db.notizenZeigen and NO:Text(q.id)
    if t then return { SYMBOL .. "|cffd9c9a3" .. t .. "|r", QK.farben.hell, L"Deine Notiz" } end
  end)
  QK:Haken("menue", function(q)
    return { { NO:Text(q.id) and L"Notiz bearbeiten" or L"Notiz schreiben", function() NO:Bearbeiten(q.id, q.titel) end } }
  end)
  QK:Haken("tooltip", function(tooltip, questID)
    local t = NO:Text(questID)
    if t then tooltip:AddLine(SYMBOL .. t, 0.85, 0.79, 0.64, true) end
  end)
end

QK:Befehl({ "notiz" }, function(rest)
  local id = QK.Compat:Fokus()
  if not id then QK:Meldung(L"setz zuerst eine Quest als Fokus.") return end
  if rest == "" then
    local titel = QK.Compat.titel and QK.Compat.titel[id] or (L"Quest " .. id)
    NO:Bearbeiten(id, titel)
  else
    NO:Setzen(id, rest ~= "-" and rest or nil)
    QK:Meldung(rest ~= "-" and L"Notiz gespeichert." or L"Notiz gelöscht.")
  end
end, L"/qk notiz [Text] – Notiz zur Fokus-Quest (- löscht sie)")
