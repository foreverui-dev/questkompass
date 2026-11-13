-- Erzeugt Aenderungen.lua aus CHANGELOG.md, damit das Addon die Änderungsliste im Spiel zeigen kann.
-- Aufruf aus dem Addon-Ordner: lua5.1 tools/aenderungen.lua > Aenderungen.lua
-- Aufbau der CHANGELOG.md: "## Version", Punkte ("- " oder "1. ") auf Deutsch, optional "**English**"
-- und Punkte auf Englisch. Gezeigt werden die neuesten fünf Versionen.
local versionen, aktuell, sprache = {}, nil, "de"
for zeile in io.lines("CHANGELOG.md") do
  local v = zeile:match("^## (%d+%.%d+%.%d+)")
  if v then
    aktuell = #versionen < 5 and { version = v, de = {}, en = {} } or nil
    if aktuell then versionen[#versionen + 1] = aktuell end
    sprache = "de"
  elseif aktuell and zeile:match("^%*%*English%*%*") then
    sprache = "en"
  elseif aktuell then
    local punkt = zeile:match("^%- (.+)") or zeile:match("^%d+%. (.+)")
    if punkt then
      punkt = punkt:gsub("`", ""):gsub("%*%*(.-)%*%*", "%1")
      table.insert(aktuell[sprache], punkt)
    end
  end
end

local function q(s) return (("%q"):format(s):gsub("\\\n", "\\n")) end
local aus = { "-- Questkompass: Änderungsliste für das Spiel. Automatisch erzeugt aus CHANGELOG.md",
  "-- (lua5.1 tools/aenderungen.lua > Aenderungen.lua), bitte nicht von Hand ändern.",
  "local _, QK = ...", "QK.AENDERUNGEN = {" }
for _, v in ipairs(versionen) do
  aus[#aus + 1] = ("  { version = %s,"):format(q(v.version))
  for _, sp in ipairs({ "de", "en" }) do
    if #v[sp] > 0 then
      aus[#aus + 1] = ("    %s = {"):format(sp)
      for _, p in ipairs(v[sp]) do aus[#aus + 1] = ("      %s,"):format(q(p)) end
      aus[#aus + 1] = "    },"
    end
  end
  aus[#aus + 1] = "  },"
end
aus[#aus + 1] = "}"
io.write(table.concat(aus, "\n"), "\n")
