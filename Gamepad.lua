-- Questkompass: Steuerung des Hauptfensters (Einstellungen, Questbuch, Assistent) mit Gamepad oder Pfeiltasten.
-- Steuerkreuz/Pfeile wählen aus, A/Eingabe bestätigt, B/Escape schließt,
-- die Schultertasten blättern durch die Seitenleiste (im Assistenten: Seiten).
local _, QK = ...
local GP = QK:Modul("Gamepad")

local PAD = {
  PADDUP = "hoch", PADDDOWN = "runter", PADDLEFT = "links", PADDRIGHT = "rechts",
  PAD1 = "ok", PAD2 = "zurueck", PADLSHOULDER = "vorher", PADRSHOULDER = "nachher",
}
local TASTATUR = { UP = "hoch", DOWN = "runter", LEFT = "links", RIGHT = "rechts", ENTER = "ok" }

local function Weitergeben(frame, an, funktion)
  if frame[funktion] and not InCombatLockdown() then pcall(frame[funktion], frame, an) end
end

-- Verbindet ein Fenster mit einer Funktion handler(aktion, quelle) -> true, wenn behandelt
function GP:Anmelden(frame, handler)
  if not frame or frame.questkompassGamepad then return end
  frame.questkompassGamepad = true
  local function an(self)
    if self.EnableGamePadButton then pcall(self.EnableGamePadButton, self, true) end
    if self.EnableKeyboard and not InCombatLockdown() then pcall(self.EnableKeyboard, self, true) end
    Weitergeben(self, true, "SetPropagateKeyboardInput")
    Weitergeben(self, true, "SetPropagateGamePadInput")
  end
  frame:HookScript("OnShow", an)
  -- ältere Clients kennen kein Gamepad-Skript, daher geschützt
  pcall(frame.SetScript, frame, "OnGamePadButtonDown", function(self, taste)
    local aktion = PAD[taste]
    local ok, behandelt = false, false
    if aktion then ok, behandelt = pcall(handler, aktion, "pad") end
    Weitergeben(self, not (ok and behandelt), "SetPropagateGamePadInput")
  end)
  frame:SetScript("OnKeyDown", function(self, taste)
    local aktion = TASTATUR[taste]
    local ok, behandelt = false, false
    if aktion then ok, behandelt = pcall(handler, aktion) end
    Weitergeben(self, not (ok and behandelt), "SetPropagateKeyboardInput")
    if ok and behandelt then
      C_Timer.After(0, function() Weitergeben(self, true, "SetPropagateKeyboardInput") end)
    end
  end)
  if frame:IsShown() then an(frame) end
end

local function Assistent(aktion, quelle) return QK.Assistent:Steuern(aktion, quelle) end

function GP:Start()
  -- Das Hauptfenster entsteht erst beim ersten Öffnen; dann verbinden. Das Questbuch steckt darin.
  hooksecurefunc(QK.Assistent, "Oeffnen", function() GP:Anmelden(QuestkompassAssistent, Assistent) end)
  if QuestkompassAssistent then GP:Anmelden(QuestkompassAssistent, Assistent) end
end

-- Tastenkürzel „Fokus zurück“ (z. B. auf eine Gamepad-Taste legen)
QK.tasten.zurueck = function() QK.Tracker:FokusWeiter(-1) end
