-- Questkompass: Steuerung von Questbuch und Assistent mit Gamepad oder Pfeiltasten.
-- Steuerkreuz/Pfeile wählen aus, A/Eingabe bestätigt, B/Escape schließt,
-- Schultertasten oder links/rechts wechseln Reiter bzw. Seiten.
local _, QK = ...
local GP = QK:Modul("Gamepad")

local PAD = {
  PADDUP = "hoch", PADDDOWN = "runter", PADDLEFT = "links", PADDRIGHT = "rechts",
  PAD1 = "ok", PAD2 = "zurueck", PADLSHOULDER = "links", PADRSHOULDER = "rechts",
}
local TASTATUR = { UP = "hoch", DOWN = "runter", LEFT = "links", RIGHT = "rechts", ENTER = "ok" }

local function Weitergeben(frame, an, funktion)
  if frame[funktion] and not InCombatLockdown() then pcall(frame[funktion], frame, an) end
end

-- Verbindet ein Fenster mit einer Funktion handler(aktion) -> true, wenn behandelt
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
    if aktion then ok, behandelt = pcall(handler, aktion) end
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

local function Questbuch(aktion)
  local G = QK.Gebiet
  if aktion == "hoch" then G:Bewegen(-1)
  elseif aktion == "runter" then G:Bewegen(1)
  elseif aktion == "links" then G:ReiterWechseln(-1)
  elseif aktion == "rechts" then G:ReiterWechseln(1)
  elseif aktion == "ok" then G:Ausloesen()
  elseif aktion == "zurueck" then G:Fenster():Hide()
  else return false end
  return true
end

local function Assistent(aktion) return QK.Assistent:Steuern(aktion) end

function GP:Start()
  -- Fenster entstehen erst beim ersten Öffnen; dann verbinden.
  hooksecurefunc(QK.Gebiet, "Reiter", function() GP:Anmelden(QK.Gebiet:Fenster(), Questbuch) end)
  hooksecurefunc(QK.Gebiet, "Zeigen", function() GP:Anmelden(QK.Gebiet:Fenster(), Questbuch) end)
  hooksecurefunc(QK.Assistent, "Oeffnen", function() GP:Anmelden(QuestkompassAssistent, Assistent) end)
  if QuestkompassAssistent then GP:Anmelden(QuestkompassAssistent, Assistent) end
end

-- Tastenkürzel „Fokus zurück“ (z. B. auf eine Gamepad-Taste legen)
QK.tasten.zurueck = function() QK.Tracker:FokusWeiter(-1) end
