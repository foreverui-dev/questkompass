-- Questkompass als Plugin in ForeverUI: die wichtigsten Einstellungen erscheinen im
-- ForeverUI-Fenster unter „Plugins“, und mit eingeschaltetem Interface übernimmt Questkompass
-- dessen Balkentextur und Akzentfarbe. Ohne ForeverUI passiert hier nichts.
local _, QK = ...
local L = QK.L

local function db() return QK.db end

local plugin = {
  id = "questkompass",
  titel = "Questkompass",
  einstellungen = {
    { id = "interfaceAussehen", art = "schalter", titel = L"Aussehen von ForeverUI übernehmen", standard = true,
      text = L"Balken und Akzentfarbe wie im ForeverUI-Interface, solange es eingeschaltet ist." },
    { id = "stil", art = "auswahl", titel = L"Wie soll die Liste aussehen?", standard = "ruhig",
      werte = { { "ruhig", L"Ruhig" }, { "klassisch", L"Klassisch" }, { "kompakt", L"Kompakt" } } },
    { id = "lage", art = "auswahl", titel = L"Wo soll die Liste stehen?", standard = "minimap",
      werte = { { "minimap", L"Unter der Minikarte" }, { "rechts", L"Rechts am Rand" }, { "links", L"Links am Rand" }, { "frei", L"Frei verschieben" } } },
    { id = "skalierung", art = "regler", titel = L"Größe", min = 0.6, max = 2, schritt = 0.1, standard = 1, prozent = true },
    { id = "breite", art = "regler", titel = L"Breite", min = 180, max = 400, schritt = 20, standard = 240 },
    { id = "sortierung", art = "auswahl", titel = L"Sortierung und Anzeige", standard = "entfernung",
      werte = { { "entfernung", L"Nächste zuerst" }, { "zone", L"Nach Zone" }, { "log", L"Wie im Questlog" } } },
    { id = "blizzardAusblenden", art = "schalter", titel = L"Questverfolgung ersetzen", text = L"Blendet die Liste des Spiels aus.", standard = true },
    { id = "ruhemodus", art = "schalter", titel = L"Ruhemodus im Kampf", text = L"Liste wird im Kampf durchsichtig.", standard = true },
    { id = "mouseover", art = "schalter", titel = L"Nur bei Mauskontakt", text = L"Liste erscheint bei Maus oder Änderung.", standard = false },
    { id = "pfeil", art = "schalter", titel = L"Kompasspfeile", text = L"Kleiner Pfeil an jeder Quest.", standard = true },
    { id = "pfeilGross", art = "schalter", titel = L"Großer Fokuspfeil", text = L"Schwebender Pfeil mit Entfernung und Ankunftszeit.", standard = true },
    { id = "prozent", art = "schalter", titel = L"Fortschritt in Prozent", text = L"Gesamtstand jeder Quest neben dem Titel.", standard = false },
    { id = "meldungen", art = "schalter", titel = L"Meldung bei Fortschritt", text = L"Kurzer Hinweis, wenn ein Ziel erfüllt ist.", standard = true },
    { id = "klang", art = "schalter", titel = L"Klang bei fertiger Quest", text = L"Damit du nichts verpasst.", standard = true },
    { id = "tooltipZiele", art = "schalter", titel = L"Ziele in Tooltips", text = L"Gegner und Gegenstände zeigen deine Questziele.", standard = true },
    { id = "questPlaketten", art = "schalter", titel = L"Symbol an Quest-Gegnern", text = L"Totenkopf oder Beutel an der Namensplakette.", standard = true },
    { id = "autoAnnehmen", art = "schalter", titel = L"Quests automatisch annehmen", text = L"Halte Umschalt gedrückt, um es auszusetzen.", standard = false, stufe = "profi" },
    { id = "autoAbgeben", art = "schalter", titel = L"Quests automatisch abgeben", text = L"Nur ohne Belohnungswahl. Umschalt hält an.", standard = false, stufe = "profi" },
  },
  lesen = function(id) local d = db(); return d and d[id] end,
  schreiben = function(id, wert)
    local d = db()
    if d then
      d[id] = wert
      -- Ein Stil bringt seine Anzahl an Quests mit, wie im Assistenten
      if id == "stil" and QK.STILE[wert] then d.anzahl = QK.STILE[wert].anzahl end
    end
    if id == "interfaceAussehen" then QK:InterfaceAussehen() end
  end,
  anwenden = function() QK:Anwenden() end,
}

-- Aussehen des Interface übernehmen (nur wenn ForeverUI das Interface an hat und der Spieler es will)
function QK:InterfaceAussehen(a)
  if a then self.fuiAussehen = a end
  a = self.fuiAussehen
  local an = a and a.an and (not self.db or self.db.interfaceAussehen ~= false)
  self.fuiTextur = an and a.textur or nil
  self.fuiAkzent = an and a.akzent or nil
  self:BalkenAnwenden()
  if self.db then self:Anwenden() end
end
plugin.aussehen = function(a) QK:InterfaceAussehen(a) end

QK.plugin = plugin
local fui = _G.ForeverUI
if type(fui) == "table" and fui.PluginAnmelden then
  fui:PluginAnmelden(plugin)
else
  _G.ForeverUIPlugins = _G.ForeverUIPlugins or {}
  table.insert(_G.ForeverUIPlugins, plugin)
end
