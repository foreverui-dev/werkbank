-- Werkbank als Plugin in ForeverUI: die wichtigsten Optionen erscheinen im ForeverUI-Fenster
-- unter „Plugins“, und mit eingeschaltetem Interface übernimmt die Werkbank dessen Akzentfarbe.
-- Ohne ForeverUI passiert hier nichts.
local _, ns = ...

local function opt() return ns.db and ns.db.optionen end

-- Nach einer Änderung: was die Optionsseite der Werkbank sonst auch tut
local DANACH = {
  minimap = function() if ns.MinimapKnopfZeigen then ns.MinimapKnopfZeigen() end end,
  tracker = function() if ns.TrackerNeu then ns.TrackerNeu() end end,
}

local plugin = {
  id = "werkbank",
  titel = "Werkbank",
  einstellungen = {
    { id = "interfaceAussehen", art = "schalter", titel = "Aussehen von ForeverUI übernehmen", standard = true,
      text = "Akzentfarbe wie im ForeverUI-Interface, solange es eingeschaltet ist." },
    { id = "groesse", art = "regler", titel = "Größe", min = 1, max = 2, schritt = 0.25, standard = 1, prozent = true },
    { id = "kompakt", art = "schalter", titel = "Kompaktes Fenster", text = "Ohne Seitenleiste.", standard = false },
    { id = "tooltip", art = "schalter", titel = "Zeilen in Gegenstands-Tooltips", text = "Wofür ein Material gebraucht wird, wer es herstellen kann und wie viele deine anderen Charaktere haben.", standard = true },
    { id = "tooltipKenner", art = "schalter", titel = "Hersteller im Tooltip", text = "Nennt im Tooltip deine Charaktere, die einen Gegenstand herstellen können.", standard = true },
    { id = "abhaken", art = "schalter", titel = "Nach dem Herstellen abhaken", text = "Stellst du etwas von der Liste her, wird es automatisch um eins verringert.", standard = true },
    { id = "lootMeldung", art = "schalter", titel = "Fortschritt beim Sammeln", text = "Meldet im Chat, wenn ein Material von der Liste dazukommt.", standard = true },
    { id = "fertigMeldung", art = "schalter", titel = "Melden, wenn alles da ist", text = "Meldung, Ton und Sprachausgabe, sobald alle Materialien beisammen sind.", standard = true },
    { id = "tracker", art = "schalter", titel = "Tracker", text = "Kleines Fenster am Bildschirmrand mit den fehlenden Materialien.", standard = false },
    { id = "bildschirm", art = "schalter", titel = "Meldungen auf dem Bildschirm", text = "Fortschritt beim Sammeln und fertige Listen zusätzlich mitten auf dem Bildschirm.", standard = false },
    { id = "autoSelbst", art = "schalter", titel = "Selbst herstellen, wenn ich's kann", text = "Zwischenprodukte, die einer deiner Charaktere herstellen kann, werden in ihre Zutaten aufgelöst.", standard = false },
    { id = "berufHinweise", art = "schalter", titel = "Berufs-Hinweise", text = "Stufenaufstieg, Meilensteine, Lehrer, neue Muster und unbekannte Rezepte beim Händler.", standard = true },
    { id = "abklingMeldung", art = "schalter", titel = "Abklingzeiten melden", text = "Wenn Transmutation oder Mondstoff wieder bereit ist.", standard = true },
    { id = "postHinweis", art = "schalter", titel = "Hinweise für andere Charaktere", text = "Beim Einloggen melden, wenn ein anderer Charakter etwas braucht, das du hast.", standard = true, stufe = "profi" },
    { id = "zielMeldung", art = "schalter", titel = "Ziele und Erfolge melden", standard = true, stufe = "profi" },
    { id = "mindestWarnung", art = "schalter", titel = "Mindestbestand überwachen", standard = true, stufe = "profi" },
    { id = "auftragHinweis", art = "schalter", titel = "An Aufträge erinnern", standard = true, stufe = "profi" },
    { id = "alarmTon", art = "schalter", titel = "Preisalarm mit Ton", standard = true, stufe = "profi" },
    { id = "fluestern", art = "schalter", titel = "Flüsteranfragen beantworten", text = "Auf „!werkbank Name“ antworten, ob du das herstellen kannst.", standard = false, stufe = "profi" },
  },
  lesen = function(id) local o = opt(); return o and o[id] end,
  schreiben = function(id, wert)
    local o = opt()
    if o then o[id] = wert end
    if id == "interfaceAussehen" then ns.InterfaceAussehen() end
    if DANACH[id] then pcall(DANACH[id]) end
  end,
  anwenden = function()
    if ns.FarbenAnwenden then ns.FarbenAnwenden() end
    if ns.Aktualisieren then pcall(ns.Aktualisieren) end
  end,
}

-- Aussehen des Interface übernehmen (nur wenn ForeverUI das Interface an hat und der Spieler es will)
function ns.InterfaceAussehen(a)
  if a then ns.fuiAussehen = a end
  a = ns.fuiAussehen
  local o = opt()
  local an = a and a.an and (not o or o.interfaceAussehen ~= false)
  ns.fuiAkzent = an and a.akzent or nil
  if ns.FarbenAnwenden then ns.FarbenAnwenden() end
end
plugin.aussehen = function(a) ns.InterfaceAussehen(a) end

ns.plugin = plugin
local fui = _G.ForeverUI
if type(fui) == "table" and fui.PluginAnmelden then
  fui:PluginAnmelden(plugin)
else
  _G.ForeverUIPlugins = _G.ForeverUIPlugins or {}
  table.insert(_G.ForeverUIPlugins, plugin)
end
