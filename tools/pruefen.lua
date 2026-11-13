-- Questkompass: Prüfstandard (wie beim Forever DPS Meter) vor jedem Push und jeder Veröffentlichung.
-- Aufruf im Hauptordner: lua5.1 tools/pruefen.lua
-- Prüft alles, was sich ohne Spiel prüfen lässt, und endet mit Fehlercode, wenn etwas nicht stimmt.

local fehler, warnungen = 0, 0
local function ok(text) print("  ok      " .. text) end
local function fehlt(text) fehler = fehler + 1; print("  FEHLER  " .. text) end
local function warnung(text) warnungen = warnungen + 1; print("  Hinweis " .. text) end
local function lesen(pfad)
  local f = io.open(pfad, "rb")
  if not f then return nil end
  local t = f:read("*a")
  f:close()
  return t
end
local function befehl(cmd)
  local p = io.popen(cmd .. " 2>&1")
  local t = p:read("*a")
  p:close()
  return t
end

-- Dateien laut TOC
local toc = lesen("Questkompass.toc") or ""
local dateien, imToc = {}, {}
for zeile in toc:gmatch("[^\r\n]+") do
  if not zeile:match("^#") and zeile:match("%S") then
    local d = zeile:gsub("\\", "/"):gsub("%s+$", "")
    dateien[#dateien + 1] = d
    imToc[d] = true
  end
end

---------------------------------------------------------------------------
print("\n== 1. Dateien und Syntax ==")
for _, d in ipairs(dateien) do
  if not lesen(d) then fehlt("in der TOC, aber nicht vorhanden: " .. d) end
end
local alleLua = {}
for d in befehl("ls *.lua"):gmatch("[^\n]+") do
  alleLua[#alleLua + 1] = d
  if not imToc[d] then fehlt("nicht in der TOC (wird im Spiel nicht geladen): " .. d) end
end
local syntaxOk = true
for _, d in ipairs(alleLua) do
  local fn, err = loadfile(d)
  if not fn then syntaxOk = false; fehlt("Syntax: " .. tostring(err)) end
end
for d in befehl("ls tests/*.lua tools/*.lua"):gmatch("[^\n]+") do
  local fn, err = loadfile(d)
  if not fn then syntaxOk = false; fehlt("Syntax: " .. tostring(err)) end
end
if syntaxOk then ok("Syntax aller Lua-Dateien, alle Dateien in der TOC (" .. #dateien .. ")") end

---------------------------------------------------------------------------
print("\n== 2. Globale Namen ==")
-- Bekannte globale Namen (Spiel und Lua). Neue Spielfunktionen hier eintragen, damit Tippfehler auffallen.
local ERLAUBT = {}
for n in (lesen("tools/globale.txt") or ""):gmatch("[%w_]+") do ERLAUBT[n] = true end
local SCHREIBEN = { QuestkompassDB = true, QuestkompassCharDB = true }
local luac = befehl("command -v luac5.1"):match("%S+")
if not luac then
  warnung("luac5.1 fehlt, globale Namen nicht geprüft")
else
  local unbekannt, geschrieben = {}, {}
  for _, d in ipairs(alleLua) do
    for zeile in befehl(luac .. " -l -p " .. d):gmatch("[^\n]+") do
      local art, name = zeile:match("([GS]ETGLOBAL).-;%s*([%w_]+)")
      if art == "SETGLOBAL" and not SCHREIBEN[name] and not name:match("^SLASH_") and not name:match("^BINDING_") then
        geschrieben[#geschrieben + 1] = d .. ": " .. name
      elseif art == "GETGLOBAL" and not ERLAUBT[name] and not SCHREIBEN[name] then
        unbekannt[name] = unbekannt[name] or d
      end
    end
  end
  for _, t in ipairs(geschrieben) do fehlt("versehentlich globale Variable (local vergessen?) " .. t) end
  for name, d in pairs(unbekannt) do fehlt("unbekannter globaler Name (Tippfehler? sonst in tools/globale.txt eintragen) " .. d .. ": " .. name) end
  if #geschrieben == 0 and not next(unbekannt) then ok("keine versehentlichen Globalen, keine unbekannten Namen") end
end

---------------------------------------------------------------------------
print("\n== 3. Übersetzungen ==")
local locale = lesen("Locale.lua") or ""
local englisch = {}
for k, v in locale:gmatch('E%["(.-)"%]%s*=%s*"(.-)"\n') do englisch[k] = v end
local function platzhalter(t)
  local p = {}
  for x in t:gsub("%%%%", ""):gmatch("%%[%d%.]*%a") do p[#p + 1] = x end
  return table.concat(p, " ")
end
local ohne, falsch = 0, 0
for _, d in ipairs(alleLua) do
  if d ~= "Locale.lua" then
    for k in (lesen(d) or ""):gmatch('%f[%w_]L"([^"\n]+)"') do
      local e = englisch[k]
      if not e then
        ohne = ohne + 1
        fehlt("ohne englischen Text " .. d .. ": " .. k)
      elseif platzhalter(e) ~= platzhalter(k) then
        falsch = falsch + 1
        fehlt("Platzhalter passen nicht (" .. platzhalter(k) .. " / " .. platzhalter(e) .. "): " .. k)
      end
    end
  end
end
local doppelt = {}
for k in locale:gmatch('\nE%["(.-)"%]%s*=') do
  if doppelt[k] then warnung("doppelt in Locale.lua: " .. k) end
  doppelt[k] = true
end
if ohne == 0 and falsch == 0 then ok("alle Texte übersetzt, Platzhalter stimmen") end

---------------------------------------------------------------------------
print("\n== 4. Version und Änderungsliste ==")
local version = toc:match("## Version: (%S+)")
local changelog = lesen("CHANGELOG.md") or ""
local neueste = changelog:match("## (%d+%.%d+%.%d+)")
if version and version == neueste then ok("Version " .. version .. " in TOC und CHANGELOG.md")
else fehlt("Version in der TOC (" .. tostring(version) .. ") passt nicht zur neuesten in CHANGELOG.md (" .. tostring(neueste) .. ")") end
local block = changelog:match("## " .. (neueste or "?"):gsub("%.", "%%.") .. "\n(.-)\n## ") or changelog
if not block:find("%*%*English%*%*") then fehlt("Eintrag " .. tostring(neueste) .. " ohne **English**-Teil") end
if befehl("lua5.1 tools/aenderungen.lua") == lesen("Aenderungen.lua") then ok("Aenderungen.lua passt zur CHANGELOG.md")
else fehlt("Aenderungen.lua veraltet: lua5.1 tools/aenderungen.lua > Aenderungen.lua") end

---------------------------------------------------------------------------
print("\n== 5. Verbotene Hinweise und Reste ==")
local VERBOTEN = { "cla" .. "ude", "anthro" .. "pic", "c2" .. "pa" }
local treffer = false
for d in befehl("git ls-files"):gmatch("[^\n]+") do
  local t = (lesen(d) or ""):lower()
  for _, w in ipairs(VERBOTEN) do
    if t:find(w, 1, true) then treffer = true; fehlt("verbotenes Wort „" .. w .. "“ in " .. d) end
  end
end
for _, w in ipairs({ VERBOTEN[1]:upper() .. ".md", "." .. VERBOTEN[1] }) do
  if befehl("git ls-files " .. w):match("%S") then treffer = true; fehlt(w .. " gehört nicht ins Repo") end
end
if not treffer then ok("keine Hinweise auf KI-Werkzeuge") end
local reste = false
for _, d in ipairs(alleLua) do
  local nr = 0
  for zeile in (lesen(d) or ""):gmatch("([^\n]*)\n?") do
    nr = nr + 1
    if zeile:match("^%s*print%(") then reste = true; warnung(d .. ":" .. nr .. " print() statt QK:Meldung") end
    if zeile:match("TODO") or zeile:match("FIXME") then reste = true; warnung(d .. ":" .. nr .. " offener Vermerk: " .. zeile:gsub("^%s+", "")) end
  end
end
if not reste then ok("keine print()-Reste oder offenen Vermerke") end
local autoren = befehl("git log -20 --format='%an <%ae>%n%b'")
if autoren:lower():find("co%-authored") then fehlt("Commit mit Co-Authored-By in den letzten 20 Commits") end
for a in autoren:gmatch("([^\n]+ <[^>]+>)") do
  if a ~= "Syntaxlab <git@syntaxlab.dev>" then fehlt("Commit nicht von Syntaxlab: " .. a); break end
end

---------------------------------------------------------------------------
print("\n== 6. Testlauf (moderne und klassische Quest-API) ==")
local test = befehl("lua5.1 tests/simulation.lua")
local summe = test:match("(%d+ Prüfungen, [^\n]+)")
if summe and summe:match("alles in Ordnung") then ok(summe)
else
  fehlt("Tests: " .. tostring(summe))
  for z in test:gmatch("[^\n]+") do if z:match("FEHLER") then print("          " .. z) end end
end

---------------------------------------------------------------------------
print(("\n== Ergebnis: %d Fehler, %d Hinweise =="):format(fehler, warnungen))
if fehler == 0 then print("Bereit für Push und Veröffentlichung (Durchsicht nach CHECKLISTE.md nicht vergessen).") end
os.exit(fehler == 0 and 0 or 1)
