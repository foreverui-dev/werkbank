-- Prüft die Logik der Werkbank außerhalb des Spiels mit einer einfachen Attrappe der Spiel-API.
-- Aufruf aus dem Repo-Ordner: lua5.1 tests/test.lua
local fehler = 0
local function check(bed, text)
  if bed then
    print("ok    " .. text)
  else
    print("FEHLER " .. text)
    fehler = fehler + 1
  end
end

-- ---------- Attrappe ----------
local chat = {}
local function Objekt(name)
  local o = { _name = name, _shown = true, _text = "", _scripts = {} }
  return setmetatable(o, {
    __index = function(t, k)
      if k == "TitleText" then return nil end
      if k == "IsShown" then return function(self) return self._shown end end
      if k == "Show" then return function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end end
      if k == "Hide" then return function(self) self._shown = false end end
      if k == "SetShown" then return function(self, v) if v then self:Show() else self:Hide() end end end
      if k == "SetText" then return function(self, v) self._text = v end end
      if k == "GetText" then return function(self) return self._text end end
      if k == "GetNumber" then return function() return 3 end end
      if k == "SetScript" then return function(self, s, fn) self._scripts[s] = fn end end
      if k == "HookScript" then return function(self, s, fn) self._scripts[s] = self._scripts[s] or fn end end
      if k == "GetScript" then return function(self, s) return self._scripts[s] end end
      if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
      if k == "GetFrameLevel" then return function() return 1 end end
      if k == "CreateTexture" or k == "CreateFontString" then return function() return Objekt() end end
      if k == "Click" then return function(self) if self._scripts.OnClick then self._scripts.OnClick(self, "LeftButton") end end end
      return function() end
    end,
  })
end

local events = {}
local eventFrame
function CreateFrame(typ, name, parent)
  local o = Objekt(name)
  o.RegisterEvent = function(self, ev) events[ev] = true end
  if name then _G[name] = o end
  if not eventFrame then eventFrame = o end
  return o
end
local function Feuer(ev, ...) eventFrame._scripts.OnEvent(eventFrame, ev, ...) end

UIParent = Objekt("UIParent")
UISpecialFrames = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
GameTooltip = Objekt("GameTooltip")
ItemRefTooltip = Objekt("ItemRefTooltip")
SlashCmdList = {}
UnitName = function() return "Baumkuschler" end
GetRealmName = function() return "Forever" end
UnitClass = function() return "Druide", "DRUID" end
IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end
FauxScrollFrame_Update = function() end
FauxScrollFrame_GetOffset = function() return 0 end
FauxScrollFrame_SetOffset = function() end
FauxScrollFrame_OnVerticalScroll = function() end
GetItemInfo = function() return nil end
local vorrat = {}
GetItemCount = function(id) return vorrat[id] or 0 end

-- Fertigkeiten: Schneiderei 120/150
local skills = { { "Berufe", true, true }, { "Schneiderei", false, false, 120, 0, 0, 150 }, { "Kochkunst", false, false, 40, 0, 0, 75 } }
GetNumSkillLines = function() return #skills end
GetSkillLineInfo = function(i) return unpack(skills[i]) end

-- ---------- Laden ----------
local ns = {}
local function lade(datei)
  local chunk = assert(loadfile(datei))
  chunk("Werkbank", ns)
end
for _, d in ipairs({ "Data.lua", "Core.lua", "Tooltip.lua", "UI.lua" }) do lade(d) end
check(ns.daten and #ns.daten.berufe > 5, "Daten geladen (" .. #ns.daten.berufe .. " Berufe)")

local anzahl = 0
for _ in pairs(ns.daten.rezepte) do anzahl = anzahl + 1 end
check(anzahl > 2000, "Rezepte: " .. anzahl)

-- Jede Zutat und jedes Ergebnis hat einen Gegenstand
local ohne = 0
for _, r in pairs(ns.daten.rezepte) do
  if r[2] and not ns.daten.items[r[2]] then ohne = ohne + 1 end
  for i = 1, #r[4], 2 do if not ns.daten.items[r[4][i]] then ohne = ohne + 1 end end
end
check(ohne == 0, "alle Gegenstände vorhanden")

Feuer("ADDON_LOADED", "Werkbank")
Feuer("PLAYER_LOGIN")
check(WerkbankDB.chars["Baumkuschler-Forever"] ~= nil, "Charakter angelegt")
check(ns.char.berufe[197] and ns.char.berufe[197].stufe == 120, "Schneiderei-Stufe erfasst")
check(ns.char.berufe[185] ~= nil, "Kochkunst erfasst")

-- ---------- Einkaufsliste ----------
-- 1353 Handgenähte Lederstiefel: 2× 2318 Leichtes Leder, 1× 2320 Grober Faden
ns.ListeAdd(1353, 3)
local bedarf = ns.Rechnen()
check(bedarf[2318] == 6 and bedarf[2320] == 3, "Materialien für 3× Lederstiefel")
ns.ListeAdd(1353, -1)
check(ns.char.liste[1353] == 2, "eins weniger")
ns.ListeAdd(1353, -5)
check(ns.char.liste[1353] == nil, "Eintrag entfernt bei 0")

-- Zwischenprodukt selbst herstellen: Rezept mit herstellbarer Zutat suchen
local rid, zutat
for id, r in pairs(ns.daten.rezepte) do
  for i = 1, #r[4], 2 do
    local z = r[4][i]
    if ns.madeBy[z] and type(ns.daten.rezepte[ns.madeBy[z][1]][3]) == "number" then rid, zutat = id, z break end
  end
  if rid then break end
end
ns.ListeSetzen(rid, 2)
local vorher = ns.Rechnen()[zutat]
ns.SelbstUmschalten(zutat)
local b2, schritte = ns.Rechnen()
check(vorher and b2[zutat] == nil and next(schritte) ~= nil, "Zwischenprodukt aufgelöst (" .. ns.RezeptName(rid) .. " -> " .. ns.ItemName(zutat) .. ")")
ns.ListeLeeren()
check(next(ns.char.liste) == nil and next(ns.char.selbst) == nil, "Liste geleert")

-- ---------- Import / Export ----------
local n = ns.Import("https://foreverui.de/berufe/lederverarbeitung/#r=1353.2,1355.1,999999.4&h=2320")
check(n == 2, "Import erkennt 2 gültige Rezepte")
check(ns.char.liste[1353] == 2 and ns.char.liste[1355] == 1, "Import-Anzahlen")
local links = ns.Export()
check(#links == 1 and links[1].url == "https://foreverui.de/berufe/lederverarbeitung/#r=1353.2,1355.1" .. (ns.char.selbst[2320] and "&h=2320" or ""), "Export-Link: " .. (links[1] and links[1].url or "-"))
ns.ListeLeeren()
ns.Import(links[1].url)
check(ns.char.liste[1353] == 2, "Rundreise Export -> Import")
check(ns.Import("Quatsch") == 0, "Unsinn wird ignoriert")

-- ---------- Berufsfenster erfassen ----------
local tsl = { { "Stoff", "header" }, { "Leinenstiefel", "easy", 2302 } }
-- echtes Schneiderei-Rezept nehmen
local schneid = ns.beruf[197].kat[1][2][1]
local sr = ns.daten.rezepte[schneid]
tsl[2] = { ns.RezeptName(schneid), "easy", sr[2] }
local enchant -- Verzauberung ohne Gegenstand für Namensabgleich
for _, k in ipairs(ns.beruf[333].kat) do
  for _, x in ipairs(k[2]) do if not ns.daten.rezepte[x][2] then enchant = x break end end
  if enchant then break end
end
GetTradeSkillLine = function() return "Schneiderei", 125, 150 end
GetNumTradeSkills = function() return #tsl end
GetTradeSkillInfo = function(i) return tsl[i][1], tsl[i][2] end
GetTradeSkillItemLink = function(i) return tsl[i][3] and ("|Hitem:" .. tsl[i][3] .. "::::|h[x]|h") end
Feuer("TRADE_SKILL_SHOW")
check(ns.char.bekannt[schneid], "Rezept aus Berufsfenster erfasst (" .. ns.RezeptName(schneid) .. ")")
check(ns.char.berufe[197].stufe == 125, "Stufe aus Berufsfenster")

GetCraftDisplaySkillLine = function() return "Verzauberkunst", 50, 75 end
GetNumCrafts = function() return 1 end
GetCraftInfo = function() return ns.daten.rezepte[enchant][1], nil, "optimal" end
Feuer("CRAFT_SHOW")
check(ns.char.bekannt[enchant], "Verzauberung per Name erfasst (" .. ns.daten.rezepte[enchant][1] .. ")")

-- Gewähltes Rezept im Berufsfenster
TradeSkillFrame = Objekt("TradeSkillFrame"); TradeSkillFrame._shown = true
GetTradeSkillSelectionIndex = function() return 2 end
ns.offenerBeruf = ns.beruf[197]
check(ns.GewaehltesRezept() == schneid, "gewähltes Rezept erkannt")
TradeSkillFrame._shown = false

-- Beruf verlernt: Kochkunst fehlt in der Liste
table.remove(skills, 3)
Feuer("SKILL_LINES_CHANGED")
check(ns.char.berufe[185] == nil, "verlernten Beruf entfernt")
-- zugeklappter Kopf: nichts löschen
skills[1][3] = false
skills[2] = nil
Feuer("SKILL_LINES_CHANGED")
check(ns.char.berufe[197] ~= nil, "bei zugeklappter Liste nichts gelöscht")

-- ---------- Tooltip ----------
local zeilen = {}
local tip = { AddLine = function(_, t) zeilen[#zeilen + 1] = t end, AddDoubleLine = function(_, a, b) zeilen[#zeilen + 1] = a .. " " .. b end, Show = function() end }
ns.ListeLeeren()
ns.ListeSetzen(1353, 1)
vorrat[2318] = 1
ns.TooltipZeilen(tip, 2318)
local alles = table.concat(zeilen, "\n")
check(alles:find("1 / 2", 1, true) ~= nil, "Tooltip zeigt Listenstand")
check(alles:find("Zutat für", 1, true) ~= nil, "Tooltip zeigt Verwendung")
zeilen = {}
ns.TooltipZeilen(tip, sr[2])
check(table.concat(zeilen, "\n"):find("Baumkuschler", 1, true) ~= nil, "Tooltip nennt Charakter, der es kann")

-- ---------- Fenster ----------
ns.Umschalten()
check(WerkbankFrame and WerkbankFrame:IsShown(), "Fenster öffnet")
check(#ns.ui.buch.eintraege > 0 and #ns.ui.liste.eintraege > 0, "Listen gefüllt")
WerkbankSuche:SetText("stiefel")
WerkbankSuche._scripts.OnTextChanged(WerkbankSuche)
local nur = true
for _, e in ipairs(ns.ui.buch.eintraege) do
  if e.rid and not ns.RezeptName(e.rid):lower():find("stiefel") then nur = false end
end
check(nur, "Suche filtert")
for _, b in ipairs(ns.daten.berufe) do
  ns.Oeffnen(b.id)
end
check(true, "alle Berufe anzeigbar")
ns.ListeLeeren()
WerkbankSuche:SetText("")
ns.Oeffnen(197)
local row = ns.ui.buch.rows[2]
local klickRid = row.eintrag.rid
row._scripts.OnClick(row, "LeftButton")
row._scripts.OnEnter(row)
check(ns.char.liste[klickRid] == 1, "Klick im Rezeptbuch setzt auf die Liste")
local lrow = ns.ui.liste.rows[2]
lrow._scripts.OnClick(lrow, "RightButton")
check(ns.char.liste[klickRid] == nil, "Rechtsklick in der Liste nimmt es wieder runter")
ns.Umschalten()
check(not WerkbankFrame:IsShown(), "Fenster schließt")
ns.ExportDialog()
ns.ImportDialog()
SlashCmdList.WERKBANK("import #r=1356.4")
check(ns.char.liste[1356] == 4, "Import per Befehl")
SlashCmdList.WERKBANK("hilfe")
SlashCmdList.WERKBANK("tooltip")
check(ns.db.optionen.tooltip == false, "Tooltip abschaltbar")

print(fehler == 0 and "\nAlles in Ordnung." or ("\n" .. fehler .. " Fehler."))
os.exit(fehler == 0 and 0 or 1)
