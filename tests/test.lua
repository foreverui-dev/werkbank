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
      if k == "TitleText" or k == "Text" or k == "text" then return nil end
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
InCombatLockdown = function() return false end
local gesprochen = {}
Enum = { TtsVoiceType = { Standard = 0 } }
TextToSpeech_GetSelectedVoice = function() return 1 end
TextToSpeech_Speak = function(text) gesprochen[#gesprochen + 1] = text end
local vorrat = {}
GetItemCount = function(id) return vorrat[id] or 0 end
IsAltKeyDown = function() return false end
time = os.time
date = os.date
LOOT_ITEM_CREATED_SELF = "Ihr stellt her: %s."
LOOT_ITEM_CREATED_SELF_MULTIPLE = "Ihr stellt her: %sx%d."
local gesendet = {}
SendChatMessage = function(text, kanal) gesendet[#gesendet + 1] = { text, kanal } end
IsInGroup = function() return true end
IsInRaid = function() return false end
Minimap = Objekt("Minimap")

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
-- Reihenfolge wie in der TOC-Datei
local toc = {}
for zeile in io.lines("Werkbank.toc") do
  if zeile:match("%.lua$") then toc[#toc + 1] = zeile end
end
for _, d in ipairs(toc) do lade(d) end
check(#toc >= 8, "alle Dateien aus der TOC geladen (" .. #toc .. ")")
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
check(ns.L.liste[1353] == 2, "eins weniger")
ns.ListeAdd(1353, -5)
check(ns.L.liste[1353] == nil, "Eintrag entfernt bei 0")

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
check(next(ns.L.liste) == nil and next(ns.L.selbst) == nil, "Liste geleert")

-- ---------- Import / Export ----------
local n = ns.Import("https://foreverui.de/berufe/lederverarbeitung/#r=1353.2,1355.1,999999.4&h=2320")
check(n == 2, "Import erkennt 2 gültige Rezepte")
check(ns.L.liste[1353] == 2 and ns.L.liste[1355] == 1, "Import-Anzahlen")
local links = ns.Export()
check(#links == 1 and links[1].url == "https://foreverui.de/berufe/lederverarbeitung/#r=1353.2,1355.1" .. (ns.L.selbst[2320] and "&h=2320" or ""), "Export-Link: " .. (links[1] and links[1].url or "-"))
ns.ListeLeeren()
ns.Import(links[1].url)
check(ns.L.liste[1353] == 2, "Rundreise Export -> Import")
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
check(ns.L.liste[klickRid] == 1, "Klick im Rezeptbuch setzt auf die Liste")
local lrow = ns.ui.liste.rows[2]
lrow._scripts.OnClick(lrow, "RightButton")
check(ns.L.liste[klickRid] == nil, "Rechtsklick in der Liste nimmt es wieder runter")
ns.Umschalten()
check(not WerkbankFrame:IsShown(), "Fenster schließt")
ns.ExportDialog()
ns.ImportDialog()
SlashCmdList.WERKBANK("import #r=1356.4")
check(ns.L.liste[1356] == 4, "Import per Befehl")
SlashCmdList.WERKBANK("hilfe")
SlashCmdList.WERKBANK("tooltip")
check(ns.db.optionen.tooltip == false, "Tooltip abschaltbar")

-- ---------- Barrierefreiheit ----------
ns.db.optionen.tooltip = true
check(ns.F.gruen == "|cff73d973" and ns.F.gold == ns.Hex(0.95, 0.77, 0.35), "normale Farben (ForeverUI-Palette)")
SlashCmdList.WERKBANK("farbenblind")
check(ns.F.gruen == "|cff59a6ff" and ns.F.rot == "|cffff9919", "Farbenblind-Modus: Blau und Orange")
SlashCmdList.WERKBANK("kontrast")
check(ns.F.grau == "|cffd1d1d1" and ns.Deckkraft(0.5) == 0.92, "Hoher Kontrast")
SlashCmdList.WERKBANK("groesse 150")
check(ns.Groesse() == 1.5, "Größe 150 %")
SlashCmdList.WERKBANK("groesse 900")
check(ns.Groesse() == 2, "Größe auf 200 % begrenzt")

ns.ListeLeeren()
check(ns.ListeText() == "Die Einkaufsliste ist leer.", "leere Liste als Text")
ns.ListeSetzen(1353, 1)
vorrat[2318] = 1
vorrat[2320] = 5
local t = ns.ListeText()
check(t:find("1 mal", 1, true) and t:find("Es fehlen: 1 ", 1, true), "Liste als Text: " .. t)

gesprochen = {}
ns.Sprechen("leise")
check(#gesprochen == 0, "ohne Vorlesen wird nichts gesprochen")
SlashCmdList.WERKBANK("sprache")
gesprochen = {}
ns.Sprechen("|cffff0000Leichtes Leder|r 1 / 2")
check(gesprochen[#gesprochen] == "Leichtes Leder 1 von 2", "Vorlesen säubert Farbcodes: " .. tostring(gesprochen[#gesprochen]))
SlashCmdList.WERKBANK("vorlesen")
check(gesprochen[#gesprochen]:find("Es fehlen", 1, true) ~= nil, "Einkaufsliste vorlesen")

-- Tooltip nennt fehlende Menge als Wort
zeilen = {}
ns.TooltipZeilen(tip, 2318)
check(table.concat(zeilen, "\n"):find("fehlt 1", 1, true) ~= nil, "Tooltip: fehlende Menge als Wort")

-- Tastatursteuerung
SlashCmdList.WERKBANK("tastatur")
ns.Oeffnen(197)
check(ns.FensterTaste("DOWN") == true, "Pfeiltaste wird verarbeitet")
local cur = ns.ui.buch.cursor
check(ns.ui.buch.eintraege[cur] and ns.ui.buch.eintraege[cur].rid ~= nil, "Cursor springt über Kopfzeilen")
local vorherAnz = ns.L.liste[ns.ui.buch.eintraege[cur].rid] or 0
ns.FensterTaste("ENTER")
check((ns.L.liste[ns.ui.buch.eintraege[cur].rid] or 0) == vorherAnz + 1, "Eingabe setzt auf die Liste")
ns.FensterTaste("RIGHT")
check(ns.ui.aktiv == "liste", "Rechts wechselt zur Liste")
ns.FensterTaste("TAB")
check(ns.ui.beruf ~= 197 or ns.ui.seite ~= "rezepte", "Tab wechselt den Eintrag")
check(ns.FensterTaste("W") == false, "andere Tasten gehen ans Spiel")
WerkbankFrame:Show()
ns.FensterTaste("ESCAPE")
check(not WerkbankFrame:IsShown(), "Esc schließt")
Werkbank:Taste("fenster")
check(WerkbankFrame:IsShown(), "Tastenkürzel öffnet das Fenster")
ns.OptionenDialog()
check(WerkbankFrame:IsShown() and ns.ui.seite == "barrierefreiheit", "Optionen öffnen als Seite im Hauptfenster")

-- ---------- 1.2: mehrere Listen ----------
SlashCmdList.WERKBANK("sprache") -- Vorlesen wieder aus
ns.ListeLeeren()
ns.ListeSetzen(1353, 2)
local erste = ns.L
ns.ListeNeu("Zweite")
check(ns.L ~= erste and ns.L.name == "Zweite" and next(ns.L.liste) == nil, "neue Liste ist leer")
ns.ListeSetzen(1355, 1)
ns.ListeBlaettern(1)
check(ns.L == erste and ns.L.liste[1353] == 2 and ns.L.liste[1355] == nil, "Listen getrennt, Blättern geht reihum")
SlashCmdList.WERKBANK("liste weiter")
check(ns.L.name == "Zweite", "/wb liste weiter")
SlashCmdList.WERKBANK("liste name Gildenbank")
check(ns.L.name == "Gildenbank", "/wb liste name")
SlashCmdList.WERKBANK("liste loeschen")
check(#ns.char.listen == 1 and ns.L == erste, "Liste gelöscht")
ns.ListeLoeschen()
check(#ns.char.listen == 1 and next(ns.L.liste) == nil, "letzte Liste wird nur geleert")

-- gemeinsame Liste
ns.ListeSetzen(1353, 1)
SlashCmdList.WERKBANK("gemeinsam")
check(ns.L == ns.db.gemeinsam.listen[1] and ns.L.liste[1353] == nil, "gemeinsame Liste aktiv")
ns.ListeSetzen(1356, 2)
SlashCmdList.WERKBANK("gemeinsam")
check(ns.L.liste[1353] == 1 and ns.L.liste[1356] == nil, "zurück zur eigenen Liste")

-- alte gespeicherte Daten (1.1) werden übernommen
local altDB = WerkbankDB
WerkbankDB = { chars = { ["Baumkuschler-Forever"] = { liste = { [1353] = 4 }, selbst = {} } }, optionen = {} }
ns.InitDB()
check(ns.L.liste[1353] == 4 and ns.char.liste == nil, "Liste aus Version 1.1 übernommen")
WerkbankDB = altDB
ns.InitDB()

-- ---------- Favoriten, Filter, Suche ----------
ns.ListeLeeren()
check(ns.FavoritUmschalten(1353) == true and ns.db.favoriten[1353], "Favorit gesetzt")
ns.Oeffnen(165) -- Lederverarbeitung
ns.ui.filter = 6
ns.Aktualisieren()
local nurFav = #ns.ui.buch.eintraege > 0
for _, e in ipairs(ns.ui.buch.eintraege) do if e.rid and not ns.db.favoriten[e.rid] then nurFav = false end end
check(nurFav, "Filter Favoriten")
ns.FavoritUmschalten(1353)
check(not ns.db.favoriten[1353], "Favorit entfernt")

vorrat = { [2318] = 6, [2320] = 2 }
check(ns.Moeglich(1353) == 2, "2× möglich mit 6 Leder und 2 Faden")
ns.ui.filter = 5
ns.Aktualisieren()
local hatStiefel = false
for _, e in ipairs(ns.ui.buch.eintraege) do if e.rid == 1353 then hatStiefel = true end end
check(hatStiefel, "Filter „Jetzt herstellbar“")
ns.ui.filter = 1
WerkbankSuche:SetText(ns.ItemName(2318):lower())
ns.Aktualisieren()
check(#ns.ui.buch.eintraege > 2, "Suche findet Rezepte über die Zutat " .. ns.ItemName(2318))
WerkbankSuche:SetText("")

-- ---------- Andere Charaktere ----------
WerkbankDB.chars["Zweitie-Forever"] = { name = "Zweitie", realm = "Forever", taschen = { [2318] = 5 }, bank = { [2318] = 2 },
  bekannt = { [schneid] = true }, berufe = { [197] = { stufe = 50, max = 75 } } }
WerkbankDB.chars["Fremd-Anderswo"] = { name = "Fremd", realm = "Anderswo", taschen = { [2318] = 9 }, bekannt = {}, berufe = {} }
local summe, wer = ns.TwinkVorrat(2318)
check(summe == 7 and wer[1] == "Zweitie 7", "Vorrat anderer Charaktere auf dem Realm: " .. table.concat(wer, ", "))
check(ns.IrgendwerKennt(schneid), "Rezept von irgendeinem Charakter gelernt")
local herst = ns.HerstellerVon(sr[2])
check(#herst == 2, "Hersteller: " .. table.concat(herst, ", "))
ns.ListeSetzen(1353, 5)
zeilen = {}
ns.TooltipZeilen(tip, 2318)
check(table.concat(zeilen, "\n"):find("Zweitie 7", 1, true) ~= nil, "Tooltip zeigt Vorrat der anderen Charaktere")
local cz = ns.CharakterZeilen()
check(#cz == 3, "Charakterübersicht mit 3 Charakteren")
SlashCmdList.WERKBANK("charaktere")
check(ns.ui.seite == "charaktere" and ns.ui.seiten.charaktere.text:GetText():find("Zweitie", 1, true), "Charakterseite zeigt alle Charaktere")
SlashCmdList.WERKBANK("vergessen fremd")
check(WerkbankDB.chars["Fremd-Anderswo"] == nil, "Charakter vergessen")
SlashCmdList.WERKBANK("vergessen baumkuschler")
check(WerkbankDB.chars["Baumkuschler-Forever"] ~= nil, "aktueller Charakter bleibt")

-- Muster/Pläne-Tooltip
local muster = "Muster: " .. ns.daten.rezepte[schneid][1]
check(ns.RezeptAusGegenstand(muster) == schneid, "Rezept aus „" .. muster .. "“ erkannt")
check(ns.RezeptAusGegenstand("Leinenstoff") == nil, "normaler Gegenstand ist kein Rezept")
zeilen = {}
ns.RezeptGegenstandZeilen(tip, muster)
check(table.concat(zeilen, "\n"):find("gelernt von Baumkuschler, Zweitie", 1, true) ~= nil, "Muster-Tooltip nennt, wer es gelernt hat")

-- Listenzeile nennt Twinks
ns.Oeffnen(165)
local twinkZeile = false
for _, r in ipairs(ns.ui.liste.rows) do
  local e = rawget(r, "eintrag")
  if type(e) == "table" and e.mat == 2318 then twinkZeile = true end
end
check(twinkZeile, "Material steht in der Liste")
check(ns.EintragText({ mat = 2318, n = 10 }):find("Zweitie 7", 1, true) ~= nil, "Vorlesetext nennt andere Charaktere")

-- ---------- Loot-Fortschritt, Fertig-Meldung, Abhaken ----------
ns.ListeLeeren()
ns.ListeSetzen(1353, 1) -- 2 Leder, 1 Faden
vorrat = { [2318] = 0, [2320] = 1 }
Feuer("BAG_UPDATE_DELAYED")
chat = {}
vorrat[2318] = 1
Feuer("BAG_UPDATE_DELAYED")
check(chat[#chat] and chat[#chat]:find(ns.ItemName(2318) .. " 1/2", 1, true), "Loot-Fortschritt: " .. tostring(chat[#chat]))
vorrat[2318] = 2
Feuer("BAG_UPDATE_DELAYED")
check(chat[#chat] and chat[#chat]:find("sind da", 1, true), "Fertig-Meldung, wenn alles da ist")
chat = {}
Feuer("BAG_UPDATE_DELAYED")
check(#chat == 0, "keine doppelte Meldung")

local stiefel = ns.daten.rezepte[1353][2]
check(ns.HerstellungAusChat("Ihr stellt her: |cffffffff|Hitem:" .. stiefel .. "::::|h[Stiefel]|h|r.") == stiefel, "Herstellung im Chat erkannt")
check(ns.HerstellungAusChat("Ihr stellt her: |Hitem:2840::|h[Kupferstange]|hx3.") == 2840, "mehrfache Herstellung erkannt")
check(ns.HerstellungAusChat("Ihr erhaltet Beute: |Hitem:2840::|h[x]|h.") == nil, "Beute ist keine Herstellung")
ns.ListeSetzen(1353, 2)
Feuer("CHAT_MSG_LOOT", "Ihr stellt her: |Hitem:" .. stiefel .. "::::|h[Stiefel]|h.")
check(ns.L.liste[1353] == 1, "nach dem Herstellen abgehakt")
Feuer("CHAT_MSG_LOOT", "Ihr stellt her: |Hitem:" .. stiefel .. "::::|h[Stiefel]|h.")
check(ns.L.liste[1353] == nil, "zuletzt ganz von der Liste")

-- ---------- Händler ----------
ns.ListeSetzen(1353, 3) -- 6 Leder, 3 Faden
vorrat = { [2318] = 6, [2320] = 0 }
local gekauft = {}
GetMerchantNumItems = function() return 2 end
GetMerchantItemLink = function(i) return i == 1 and "|Hitem:2320::|h[Faden]|h" or "|Hitem:159::|h[Wasser]|h" end
GetMerchantItemInfo = function(i) return "x", 1, 10, 1, -1 end
GetMerchantItemMaxStack = function() return 20 end
BuyMerchantItem = function(i, n) gekauft[#gekauft + 1] = { i, n } end
GetMoney = function() return 100000 end
local angebot, kosten = ns.HaendlerAngebot()
check(#angebot == 1 and angebot[1].kaeufe == 3 and kosten == 30, "Händler: 3 Faden für 30 Kupfer")
ns.FehlendesKaufen()
check(#gekauft == 1 and gekauft[1][1] == 1 and gekauft[1][2] == 3, "fehlender Faden gekauft")
GetMoney = function() return 5 end
gekauft = {}
ns.FehlendesKaufen()
check(#gekauft == 0, "ohne genug Geld wird nichts gekauft")

-- ---------- Chat ----------
gesendet = {}
SlashCmdList.WERKBANK("chat")
check(#gesendet == 1 and gesendet[1][2] == "PARTY" and gesendet[1][1]:find("3× " .. ns.ItemName(2320), 1, true), "fehlende Materialien in den Gruppenchat")
ns.ListeLeeren()
for rid in pairs(ns.daten.rezepte) do
  ns.L.liste[rid] = 1
  local n = 0
  for _ in pairs(ns.L.liste) do n = n + 1 end
  if n >= 40 then break end
end
vorrat = {}
local cz2 = ns.ChatZeilen()
local zulang = false
for _, z in ipairs(cz2) do if #z > 255 then zulang = true end end
check(#cz2 > 1 and not zulang, "lange Chat-Nachricht in " .. #cz2 .. " Teile zerlegt")

-- ---------- Design: Seiten, Akzentfarbe, Größe ----------
for _, seite in ipairs({ "austausch", "funktionen", "darstellung", "neuigkeiten", "bedienung", "discord", "rezepte" }) do
  ns.SeiteZeigen(seite)
  check(ns.ui.seite == seite and ns.ui.seiten[seite]:IsShown(), "Seite " .. seite)
end
ns.db.optionen.akzent = "eis"
ns.FarbenAnwenden()
check(ns.Akzent[1] == 0.45 and ns.F.gold == ns.Hex(0.45, 0.78, 0.98), "Akzentfarbe wechselt ohne Neuladen")
ns.db.optionen.akzent = "gold"
ns.FarbenAnwenden()
ns.ListeSetzen(1353, 1)
ns.ExportDialog()
check(ns.ui.seiten.austausch.boxen[1].fest:find("#r=1353.1", 1, true), "Link steht schreibgeschützt auf der Austausch-Seite")
ns.UmbenennenDialog()
ns.ui.nameBox:SetText("Neuer Name")
ns.ui.nameBox._scripts.OnEnterPressed(ns.ui.nameBox)
check(ns.L.name == "Neuer Name", "Liste im Fenster umbenannt")
ns.ui.frame:SetSize(1200, 800)
ns.ui.frame:NachGroesse()
check(true, "Fenstergröße änderbar")
ns.db.optionen.tastatur = true
ns.SeiteZeigen("rezepte", 197)
ns.FensterTaste("TAB")
check(ns.ui.beruf ~= 197 or ns.ui.seite ~= "rezepte", "Tab geht zum nächsten Eintrag der Seitenleiste")
ns.db.optionen.tastatur = false

-- ---------- Minimap und Optionen ----------
SlashCmdList.WERKBANK("minimap")
check(ns.db.optionen.minimap == false and not WerkbankMinimapKnopf:IsShown(), "Minimap-Knopf ausblendbar")
SlashCmdList.WERKBANK("minimap")
check(WerkbankMinimapKnopf:IsShown(), "Minimap-Knopf wieder da")
ns.ListeLeeren()

-- ---------- 1.4: Rezeptbuch ----------
ns.ListeLeeren()
ns.SeiteZeigen("rezepte", 197)
ns.ui.filter = 1
ns.ui.sortierung = 2
ns.Aktualisieren()
local namen = {}
for _, e in ipairs(ns.ui.buch.eintraege) do if e.rid then namen[#namen + 1] = ns.RezeptName(e.rid) end end
local sortiert = #namen > 5
for i = 2, #namen do if namen[i - 1] > namen[i] then sortiert = false end end
check(sortiert and ns.ui.buch.eintraege[1].kopf:find("Name", 1, true), "Sortierung nach Name")
ns.ui.sortierung = 1
ns.Aktualisieren()
local kopf = ns.ui.buch.eintraege[1]
local vorZu = #ns.ui.buch.eintraege
ns.ui.buch.rows[1]._scripts.OnClick(ns.ui.buch.rows[1], "LeftButton")
check(#ns.ui.buch.eintraege < vorZu and ns.ui.zu[kopf.key], "Kategorie zugeklappt")
ns.ui.buch.rows[1]._scripts.OnClick(ns.ui.buch.rows[1], "LeftButton")
check(#ns.ui.buch.eintraege == vorZu, "Kategorie wieder aufgeklappt")
check(kopf.rechts:find("gelernt", 1, true), "Kopfzeile zählt gelernte Rezepte")
ns.char.schwierigkeit[schneid] = "optimal"
ns.ui.filter = 7
ns.Aktualisieren()
local punkte = false
for _, e in ipairs(ns.ui.buch.eintraege) do if e.rid == schneid then punkte = true end end
check(punkte, "Filter „Bringt noch Punkte“")
ns.ui.filter = 1
WerkbankSuche:SetText("leder stiefel")
ns.ui.ueberall = true
ns.Aktualisieren()
local berufeGefunden, allePassen = {}, true
for _, e in ipairs(ns.ui.buch.eintraege) do
  if e.rid then
    berufeGefunden[ns.berufOf[e.rid].id] = true
  end
end
check(next(berufeGefunden) ~= nil and ns.ui.seiten.rezepte.titel == "Suche in allen Berufen", "Mehrwort-Suche in allen Berufen")
ns.ui.ueberall = false
WerkbankSuche:SetText("")

-- Detailseite, Notiz, Anzahl
ns.RezeptZeigen(1353)
check(ns.ui.seite == "rezept" and ns.ui.seiten.rezept.text:GetText():find("Zutaten", 1, true), "Detailseite zeigt Zutaten")
WerkbankNotiz:SetText("für Gilde")
WerkbankNotiz._scripts.OnEnterPressed(WerkbankNotiz)
check(ns.db.notizen[1353] == "für Gilde", "Notiz gespeichert")
WerkbankAnzahl:SetText("7")
WerkbankAnzahl._scripts.OnEnterPressed(WerkbankAnzahl)
check(ns.L.liste[1353] == 7, "Anzahl direkt gesetzt")
local tz = {}
local ttip = { AddLine = function(_, t) tz[#tz + 1] = t end, AddDoubleLine = function(_, a, b) tz[#tz + 1] = a .. b end, Show = function() end }
ns.TooltipZeilen(ttip, ns.daten.rezepte[1353][2])
check(table.concat(tz, "\n"):find("für Gilde", 1, true), "Notiz im Tooltip")
check(ns.Ueberrasch(197) ~= nil, "Überrasch mich schlägt ein Rezept vor")

-- ---------- 1.4: Einkaufsliste ----------
ns.ListeLeeren()
ns.ListeSetzen(1353, 2)
ns.ListeSetzen(1353, 5)
ns.Rueckgaengig()
check(ns.L.liste[1353] == 2, "Rückgängig")
ns.Rueckgaengig()
check(ns.L.liste[1353] == nil, "zweimal Rückgängig")
ns.ListeSetzen(1353, 1)
ns.ListeKopieren()
check(ns.L.name:find("Kopie", 1, true) and ns.L.liste[1353] == 1, "Liste kopiert")
ns.ListeSetzen(1355, 2)
ns.ListenZusammenfuehren()
check(#ns.ListenOrt().listen == 1 and ns.L.liste[1353] == 2 and ns.L.liste[1355] == 2, "Listen zusammengeführt")
local sicher = ns.SicherungText()
ns.ListeLeeren()
check(ns.SicherungLaden(sicher) == 1 and ns.L.liste[1355] == 2, "Sicherung geladen: " .. sicher)
check(ns.SicherungLaden("Quatsch") == 0, "kaputte Sicherung wird ignoriert")
check(ns.TextExport():find("Handgenähte Lederstiefel", 1, true), "Text-Export")
ns.ListeLoeschen()

-- Twink-Liste übernehmen, Hinweis beim Einloggen
WerkbankDB.chars["Zweitie-Forever"].listen = { { name = "Zweit", liste = { [1356] = 10 }, selbst = {} } }
WerkbankDB.chars["Zweitie-Forever"].aktiv = 1
ns.ListeLeeren()
check(ns.TwinkListeUebernehmen("zweitie") == 1 and ns.L.liste[1356] == 10, "Liste von Zweitie übernommen")
ns.ListeLeeren()
local z1356 = ns.daten.rezepte[1356][4][1]
vorrat = { [z1356] = 50 }
local hinweise = ns.PostHinweise()
check(#hinweise == 1 and hinweise[1]:find("Zweitie", 1, true), "Hinweis: Zweitie braucht, was du hast")

-- Händlerpreise, Fundorte, Kosten, Gruppen
ns.ListeSetzen(1353, 3)
vorrat = { [2318] = 6 }
GetMerchantNumItems = function() return 1 end
GetMerchantItemLink = function() return "|Hitem:2320::|h[Faden]|h" end
GetMerchantItemInfo = function() return "Grober Faden", 1, 10, 1, -1 end
UnitName = function(u) return u == "npc" and "Händlerin Hilde" or "Baumkuschler" end
GetZoneText = function() return "Sturmwind" end
ns.HaendlerMerken()
UnitName = function() return "Baumkuschler" end
check(ns.HaendlerInfo(2320).preis == 10 and ns.HaendlerInfo(2320).wer == "Händlerin Hilde", "Händlerpreis gemerkt")
local summe = ns.Kosten()
check(summe == 30, "Kosten der fehlenden Händlerware: 30")
ns.SeiteZeigen("rezepte")
local gruppe = false
for _, e in ipairs(ns.ui.liste.eintraege) do if e.kopf and e.kopf:find("Beim Händler", 1, true) then gruppe = true end end
check(gruppe, "Materialien nach Quelle gruppiert")
local bereitZeile = ns.ListeFortschritt()
check(bereitZeile and bereitZeile > 0 and bereitZeile < 1, "Fortschritt der Liste: " .. math.floor(bereitZeile * 100) .. " %")

-- automatisch selbst herstellen
ns.ListeLeeren()
ns.ListeSetzen(rid, 1)
ns.db.optionen.autoSelbst = false
check(ns.Rechnen()[zutat] ~= nil, "ohne Option wird das Zwischenprodukt gekauft")
local zr = ns.RezeptFuer(zutat)
ns.char.bekannt[zr] = true
ns.db.optionen.autoSelbst = true
check(ns.Rechnen()[zutat] == nil, "mit Option wird es selbst hergestellt")
ns.SelbstUmschalten(zutat)
check(ns.Rechnen()[zutat] ~= nil and ns.L.selbst[zutat] == false, "ausdrücklich kaufen geht trotzdem")
ns.db.optionen.autoSelbst = false
ns.ListeLeeren()

-- wer, wofür, Chat-Link
check(ns.WerText("Grober Faden"):find("Grober Faden", 1, true), "/wb wer: " .. ns.WerText("Grober Faden"))
check(ns.WofuerText("2318"):find("Zutat für", 1, true), "/wb wofür")
IsAltKeyDown = function() return true end
check(ns.ChatLinkKlick("item:" .. ns.daten.rezepte[1353][2], "[Stiefel]") and ns.L.liste[1353] == 1, "Alt-Klick auf Chat-Link")
IsAltKeyDown = function() return false end
ns.ListeLeeren()

-- ---------- 1.4: Unterwegs und Fortschritt ----------
ns.ListeSetzen(1353, 1)
vorrat = {}
ns.TrackerUmschalten(true)
check(WerkbankTracker and WerkbankTracker:IsShown() and #ns.TrackerZeilen() == 2, "Tracker zeigt fehlende Materialien")
ns.TrackerUmschalten(false)
check(not WerkbankTracker:IsShown(), "Tracker aus")

ns.HergestelltZaehlen(2840, 3)
Feuer("CHAT_MSG_LOOT", "Ihr stellt her: |Hitem:2840::|h[Kupferstange]|hx2.")
check(ns.db.statistik.gesamt[2840] == 5 and ns.char.hergestellt[2840] == 5, "Statistik zählt Hergestelltes")
check(ns.StatistikText():find("5× " .. ns.ItemName(2840), 1, true), "Statistik-Text")
check(ns.SammlungText():find("Schneiderei", 1, true), "Sammlung")

LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s."
check(ns.BeuteRezept ~= nil, "Beute-Hinweis vorhanden")

ns.char.berufe[197] = { stufe = 149, max = 150 }
chat = {}
ns.StufenVergleichen({ [197] = 148 })
ns.char.berufe[197] = { stufe = 150, max = 150 }
ns.StufenVergleichen({ [197] = 149 })
local alleChat = table.concat(chat, "\n")
check(alleChat:find("Glückwunsch", 1, true) and alleChat:find("Lehrer", 1, true), "Meilenstein und Lehrer-Hinweis")

ns.char.abklingzeiten = { Mondstoff = 1 }
local fertig = ns.AbklingPruefen()
check(#fertig == 1 and fertig[1]:find("Mondstoff", 1, true), "Abklingzeit fertig gemeldet")
check(#ns.AbklingPruefen() == 0, "nur einmal gemeldet")
check(ns.AbklingText():find("Mondstoff", 1, true), "Abklingzeiten-Seite")

ns.char.gold = 12345
check(ns.GoldSumme() >= 12345, "Gold aller Charaktere")
check(ns.BerufeTabelle():find("Zweitie", 1, true), "Berufe-Tabelle")

ns.db.optionen.fluestern = true
gesendet = {}
local antwort = ns.Fluesteranfrage("!werkbank " .. ns.ItemName(sr[2]), "Fremder")
check(antwort and antwort:find("Ja, ich kann", 1, true) and #gesendet == 1, "Flüsteranfrage beantwortet")
check(ns.Fluesteranfrage("!werkbank " .. ns.ItemName(sr[2]), "Fremder") == nil, "keine Doppelantwort binnen 10 Sekunden")
ns.db.optionen.fluestern = false

-- Fehlerprotokoll
ns.AufEreignis("WERKBANK_TEST", function() error("absichtlich") end)
local vorFehler = #(ns.db.fehler or {})
Feuer("WERKBANK_TEST")
check(#ns.db.fehler == vorFehler + 1 and ns.FehlerText():find("absichtlich", 1, true), "Fehler protokolliert")
ns.SeiteZeigen("fehler")
check(WerkbankFehlerText:GetText():find("absichtlich", 1, true), "Fehler-Seite zum Kopieren")
check(type(ns.db.fehler[#ns.db.fehler]) == "string", "Fehler als Textzeile (für die ForeverUI-Übersicht)")
table.remove(ns.db.fehler)
ns.db.fehler[1] = { zeit = "2026-11-17 14:08", wo = "BAG_UPDATE_DELAYED", text = "alt" }
ns.db.codestand = nil
ns.FehlerVorbereiten()
check(ns.db.fehler[1] == "2026-11-17 14:08 [BAG_UPDATE_DELAYED] alt", "alte Tabellen-Einträge werden zu Text")
ns.db.codestand = 1
ns.FehlerVorbereiten()
check(#ns.db.fehler == 0 and ns.db.codestand == ns.CODESTAND, "neuer Codestand leert das Protokoll")
issecretvalue = function(v) return v == "GEHEIM" end
check(ns.HerstellungAusChat("GEHEIM") == nil and ns.BeuteRezept("GEHEIM") == nil, "geschützte Chatzeilen werden übersprungen")
issecretvalue = nil

-- Assistent und neue Seiten
ns.AssistentStarten()
check(ns.ui.seite == "willkommen" and ns.ui.assistent == 1, "Assistent startet")
ns.AssistentSchritt(1)
check(ns.ui.seite == "barrierefreiheit" and ns.ui.assistent == 2, "Assistent: Schritt 2")
ns.AssistentSchritt(1) ns.AssistentSchritt(1) ns.AssistentSchritt(1)
check(ns.db.assistentFertig and ns.ui.seite == "rezepte" and ns.ui.assistent == nil, "Assistent fertig")
for _, seite in ipairs({ "abklingzeiten", "statistik", "sammlung", "charaktere" }) do
  ns.SeiteZeigen(seite)
  check(ns.ui.seiten[seite]:IsShown(), "Seite " .. seite)
end
ns.ListenMenue()
check(WerkbankMenue and WerkbankMenue:IsShown(), "Listenmenü öffnet")
ns.ListeLeeren()

-- ---------- Version 1.5 ----------
local function ImChat(text)
  for i = #chat, math.max(1, #chat - 15), -1 do
    if chat[i]:find(text, 1, true) then return true end
  end
  return false
end
local stange = ns.RezeptFuer(2840)
check(stange ~= nil, "Rezept Kupferstange gefunden")
check(ns.RezeptSuchen(ns.ItemName(2840)) == stange and ns.RezeptSuchen(tostring(stange)) == stange, "Rezept nach Name und Nummer suchen")
check(ns.GeldLesen("1g 20s 5k") == 12005 and ns.GeldLesen("50s") == 5000 and ns.GeldLesen("viel") == nil, "Geldbeträge lesen")
check(ns.Zahl(1234567) == "1.234.567" and ns.Zahl(-1500) == "-1.500", "Zahlen mit Tausenderpunkt")
local f3 = ns.FristLesen("+3")
check(f3 and f3 > os.time() + 2 * 86400 and f3 < os.time() + 4 * 86400, "Frist +3 Tage")
check(ns.FristLesen("24.12.") ~= nil and ns.FristLesen("31.13.") == nil and ns.FristLesen("bald") == nil, "Frist als Datum, Unsinn wird abgelehnt")
check(ns.FristText(os.time() - 100):find("überfällig", 1, true), "überfällige Frist erkannt")

-- Preise
local sz = ns.daten.rezepte[stange][4]
for i = 1, #sz, 2 do ns.PreisMerken(sz[i], 50) end
ns.PreisMerken(sz[1], 80)
check(ns.Preis(sz[1]) == 50, "niedrigster Tagespreis bleibt")
local kosten, ohne = ns.RezeptKosten(stange)
check(kosten > 0 and ohne == 0, "Materialkosten berechnet (" .. kosten .. ")")
ns.PreisMerken(2840, 400)
local gewinn, erloes = ns.RezeptGewinn(stange)
check(gewinn and erloes == math.floor(400 * ns.Menge(ns.daten.rezepte[stange]) * 0.95 + 0.5) and gewinn == erloes - kosten, "Gewinn nach Gebühr")
check(ns.SelbstOderKaufen(2840):find("Selbst herstellen", 1, true), "selbst herstellen lohnt sich")
check(ns.AlarmSetzen(ns.ItemName(sz[1]) .. " 40k") and ns.db.alarme[sz[1]] == 40, "Preisalarm gesetzt")
ns.PreisMerken(sz[1], 30)
check(ImChat("Preisalarm"), "Preisalarm meldet sich")
SlashCmdList.WERKBANK("alarm " .. ns.ItemName(sz[1]))
check(ns.db.alarme[sz[1]] == nil, "Preisalarm per Befehl entfernt")
-- Auktionshaus lesen
GetNumAuctionItems = function() return 2 end
GetAuctionItemInfo = function(_, i) return "x", nil, 5, nil, nil, nil, nil, nil, nil, i == 1 and 1000 or 600 end
GetAuctionItemLink = function() return "|Hitem:2840::|h[Kupferstange]|h" end
Feuer("AUCTION_ITEM_LIST_UPDATE")
check(ns.VerkaufsPreis(2840) == 120, "Auktionen gelesen, günstigstes Stück gemerkt")
check(ns.PreiseText():find("Materialien deiner Liste", 1, true), "Preisseite")
check(ns.TrendText(2840) ~= nil and ns.Durchschnitt(2840) ~= nil, "Trend und Durchschnitt")

-- Aufträge
local a = ns.AuftragAusText("Thrall; " .. ns.ItemName(2840) .. "; 5; 2g; +2; eilig")
check(a and a.kunde == "Thrall" and a.rid == stange and a.n == 5 and a.lohn == 20000 and a.frist and not a.kundenMat, "Auftrag aus Text")
check(next(ns.AuftragFehlt(a)) ~= nil, "fehlendes Material des Auftrags")
local ag = ns.AuftragGewinn(a)
check(type(ag) == "number", "Gewinn des Auftrags")
local b2 = ns.AuftragNeu({ kunde = "Jaina", rid = stange, n = 2, kundenMat = true, frist = os.time() - 10 })
check(b2 and next(ns.AuftragFehlt(b2)) == nil, "Kunde bringt Material: nichts fehlt")
check(ns.AuftraegeSortiert("frist")[1] == b2, "überfälliger Auftrag zuerst")
ns.AuftragWert(a.nr, "prio", 3)
check(ns.AuftraegeSortiert("prio")[1] == a, "Sortierung nach Priorität")
check(ns.AuftraegeSortiert("lohn")[1] == a and #ns.AuftraegeSortiert("rezept") == 2 and #ns.AuftraegeSortiert("aufwand") == 2, "Sortierung nach Lohn, Aufwand, Beruf")
local vorListe = ns.L.liste[stange] or 0
ns.AuftraegeAufListe()
check(ns.L.liste[stange] == vorListe + 5, "offene Aufträge auf die Liste (ohne Kundenmaterial)")
ns.Rueckgaengig()
check((ns.L.liste[stange] or 0) == vorListe, "Aufträge auf Liste rückgängig")
for _ = 1, 3 do ns.AuftragStatus(a.nr) end
check(a.status == 4 and ns.db.kunden.Thrall.anzahl == 1 and ns.db.kunden.Thrall.summe == 20000, "Auftrag abgeschlossen, Kundenverlauf")
local kopie = ns.AuftragDuplizieren(a.nr)
check(kopie and kopie.nr ~= a.nr and kopie.status == 1 and kopie.kunde == "Thrall", "Auftrag kopiert")
check(ns.AuftragLoeschen(kopie.nr) and not ns.AuftragHolen(kopie.nr), "Auftrag gelöscht")
ns.KundeSetzen("Thrall flüstern abends")
check(ns.db.kunden.Thrall.kontakt == "flüstern abends" and ns.KundenText():find("flüstern abends", 1, true), "Kunde mit Kontaktweg")
check(ns.AuftraegeText("frist", true):find("Thrall", 1, true), "Auftragsliste als Text")

-- Ziele, Mindestbestand, Erfolge
local stufe = ns.char.berufe[197].stufe
ns.ZielSetzen("Schneiderei " .. (stufe + 25))
check(ns.char.ziele[197] and ns.char.ziele[197].stufe == stufe + 25 and not ns.char.ziele[197].erreichtstufe, "Berufsziel gesetzt")
ns.ZielSetzen("Schneid " .. stufe)
check(ns.char.ziele[197].erreichtstufe and ImChat("Ziel erreicht"), "Ziel erreicht gemeldet")
local naechste = ns.NaechsteStufe(stufe)
check(ns.ZieleText():find("noch " .. (naechste - stufe) .. " bis " .. naechste, 1, true), "nächster Meilenstein")
ns.ZielSetzen("Schneiderei 0")
check(ns.char.ziele[197] == nil, "Ziel gelöscht")
vorrat[2840] = 3
ns.MindestSetzen(ns.ItemName(2840) .. " 10")
check(ns.MindestZuWenig()[2840] == 7, "Mindestbestand unterschritten")
ns.L.liste[stange] = nil
ns.MindestAufListe()
check(ns.L.liste[stange] == math.ceil(7 / ns.Menge(ns.daten.rezepte[stange])), "Mindestbestand auffüllen")
ns.MindestSetzen(ns.ItemName(2840) .. " 0")
vorrat[2840] = nil
ns.L.liste[stange] = nil
check(#ns.db.historie > 0 and ns.db.historie[1].id == 2840, "Herstellungsverlauf")
check(ns.Ertrag(stange) ~= nil, "Ertrag je Herstellung")
check(ns.AuswertungText():find("Hergestellt je Beruf", 1, true), "Auswertung")
ns.ErfolgePruefen()
check(ns.db.erfolge.erste and ns.db.erfolge.kunde, "Werkbank-Erfolge")
check(ns.ErfolgeText():find("Erste Schritte", 1, true), "Erfolge als Text")

-- Neu seit Datenupdate
ns.db.rezeptIds[stange] = nil
ns.db.rezeptStand = "alt"
ns.DatenstandPruefen()
check(ns.NeueRezepte()[stange] and ns.db.rezeptStand == ns.daten.stand, "neue Rezepte seit Datenupdate")

-- Vorlagen und Prioritäten
ns.ListeSetzen(stange, 4)
ns.VorlageSpeichern("Wochenbedarf")
ns.ListeLeeren()
ns.VorlageLaden("wochenbedarf")
check(ns.L.name == "Wochenbedarf" and ns.L.liste[stange] == 4, "Vorlage gespeichert und geladen")
check(ns.PrioUmschalten(stange) == 3 and ns.Prio(stange) == 3, "Priorität dringend")
check(ns.PrioUmschalten(stange) == 1 and ns.PrioUmschalten(stange) == 2 and ns.L.prio[stange] == nil, "Priorität reihum")
ns.ListeLoeschen()

-- Detail, Vergleich, Übersicht, Diagnose
local extras = table.concat(ns.RezeptExtras(stange), "\n")
check(extras:find("Materialkosten", 1, true) and extras:find("Gewinn", 1, true), "Rezeptseite: Kosten und Gewinn")
ns.db.werkzeuge = ns.db.werkzeuge or {}
ns.db.werkzeuge[stange] = "Schmelzofen"
check(table.concat(ns.RezeptExtras(stange), "\n"):find("Braucht: Schmelzofen", 1, true), "Rezeptseite: Werkzeuge und Orte")
check(ns.VergleichText(stange, schneid):find(ns.RezeptName(schneid), 1, true), "Rezepte vergleichen")
check(ns.UebersichtText():find("Aufträge", 1, true), "Übersicht")
check(ns.DiagnoseText():find("Schnittstellen", 1, true), "Diagnose")

-- Fenster: neue Seiten, Seitenleiste, kompakt
for _, seite in ipairs({ "uebersicht", "auftraege", "preise", "ziele", "diagnose", "meldungen" }) do
  ns.SeiteZeigen(seite)
  check(ns.ui.seiten[seite]:IsShown(), "Seite " .. seite)
end
WerkbankAuftragKunde:SetText("Anduin")
WerkbankAuftragRezept:SetText(ns.ItemName(2840))
WerkbankAuftragAnzahl:SetText("3")
WerkbankAuftragFrist:SetText("morgen")
WerkbankAuftragKunde._scripts.OnEnterPressed(WerkbankAuftragKunde)
local neuster = ns.db.auftraege.liste[#ns.db.auftraege.liste]
check(neuster.kunde == "Anduin" and neuster.n == 3 and neuster.frist, "Auftrag im Fenster angelegt")
check(#ns.ui.auftragListe.eintraege >= 2, "Auftragsliste im Fenster")
ns.RezeptZeigen(stange)
ns.VergleichMerken(stange)
ns.VergleichMerken(schneid)
check(ns.ui.seite == "vergleich" and ns.ui.seiten.vergleich:IsShown(), "Vergleichsseite")
local fremd
for _, bf in ipairs(ns.daten.berufe) do if not ns.char.berufe[bf.id] and bf.id ~= ns.ui.beruf then fremd = bf.id break end end
check(fremd and not ns.LeisteSichtbar({ seite = "rezepte", beruf = fremd }), "fremde Berufe nicht in der Seitenleiste")
ns.db.optionen.kompakt = true
ns.Aktualisieren()
check(not ns.ui.leiste:IsShown() and ns.ui.seitenKnopf:IsShown(), "kompaktes Fenster")
ns.SeitenMenue(ns.ui.seitenKnopf)
check(WerkbankMenue:IsShown(), "Seitenmenü")
WerkbankMenue:Hide()
ns.db.optionen.kompakt = false
ns.Aktualisieren()
check(ns.ui.leiste:IsShown(), "Seitenleiste wieder da")
SlashCmdList.WERKBANK("auftraege")
check(ns.ui.seite == "auftraege", "/wb auftraege")
SlashCmdList.WERKBANK("vergleich " .. ns.ItemName(2840) .. "; " .. ns.RezeptName(schneid))
check(ns.ui.seite == "vergleich", "/wb vergleich")
ns.SeiteZeigen("fehler")
check(WerkbankFehlerText:GetText():find("Schnittstellen", 1, true), "Diagnose auf der Fehlerseite")
ns.SeiteZeigen("rezepte")

-- Neue Schnittstellen von WoW Forever (ohne die klassischen Funktionen)
local altInfo, altTS = GetMerchantItemInfo, GetTradeSkillLine
GetMerchantItemInfo = nil
C_MerchantFrame = { GetItemInfo = function(i) return { name = "Grober Faden", price = 10, stackCount = 1, numAvailable = -1 } end }
GetMerchantNumItems = function() return 1 end
local vorF = #ns.db.fehler
Feuer("MERCHANT_SHOW")
check(#ns.db.fehler == vorF, "Händler mit neuer Schnittstelle ohne Fehler")
local n1, p1, s1, v1 = ns.HaendlerArtikel(1)
check(n1 == "Grober Faden" and p1 == 10 and s1 == 1 and v1 == -1, "Händlerware über C_MerchantFrame")
GetMerchantItemInfo = altInfo
GetTradeSkillLine = nil
local ar = ns.beruf[171].kat[1][2][1]
C_TradeSkillUI = {
  GetBaseProfessionInfo = function() return { professionName = "Alchimie", skillLevel = 55, maxSkillLevel = 75 } end,
  GetAllRecipeIDs = function() return { 9001 } end,
  GetRecipeInfo = function() return { name = ns.daten.rezepte[ar][1], learned = true, type = "recipe", relativeDifficulty = 0 } end,
}
ns.char.bekannt[ar] = nil
Feuer("TRADE_SKILL_LIST_UPDATE")
check(ns.char.bekannt[ar] and ns.char.berufe[171].stufe == 55 and ns.char.schwierigkeit[ar] == "optimal", "Berufsfenster über C_TradeSkillUI gelesen")
check(#ns.db.fehler == vorF, "neue Berufsschnittstelle ohne Fehler")
GetTradeSkillLine, C_TradeSkillUI, C_MerchantFrame = altTS, nil, nil
C_AuctionHouse = {
  GetBrowseResults = function() return { { itemKey = { itemID = 2840 }, minPrice = 77 } } end,
  GetCommoditySearchResultInfo = function() return { unitPrice = 66 } end,
}
ns.db.preise[2840] = nil
Feuer("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check(ns.VerkaufsPreis(2840) == 77, "neues Auktionshaus: Suchergebnisse gelesen")
Feuer("COMMODITY_SEARCH_RESULTS_UPDATED", 2840)
check(ns.VerkaufsPreis(2840) == 66 and #ns.db.fehler == vorF, "neues Auktionshaus: Massenware gelesen")
C_AuctionHouse = nil

-- Plugin für ForeverUI
local wbPlugin
for _, p in ipairs(ForeverUIPlugins or {}) do if p.id == "werkbank" then wbPlugin = p end end
check(wbPlugin ~= nil, "Plugin: für ForeverUI angemeldet")
local stdOk = true
for _, o in ipairs(wbPlugin.einstellungen) do
  if o.id and ns.STANDARD[o.id] ~= o.standard then stdOk = false; print("  Standard weicht ab: " .. o.id) end
end
check(stdOk, "Plugin: Standards wie in der Werkbank")
wbPlugin.schreiben("lootMeldung", false)
check(ns.db.optionen.lootMeldung == false and wbPlugin.lesen("lootMeldung") == false, "Plugin: schreibt in die Werkbank-Optionen")
wbPlugin.schreiben("lootMeldung", true)
wbPlugin.aussehen({ an = true, akzent = { 0.1, 0.2, 0.3 } })
check(math.abs(ns.Akzent[1] - 0.1) < 0.001 and math.abs(ns.Akzent[3] - 0.3) < 0.001, "Plugin: übernimmt Akzentfarbe des Interface")
wbPlugin.schreiben("interfaceAussehen", false)
check(math.abs(ns.Akzent[1] - 0.1) > 0.01, "Plugin: eigene Akzentfarbe, wenn abgeschaltet")
wbPlugin.schreiben("interfaceAussehen", true)
wbPlugin.aussehen({ an = false, akzent = { 0.1, 0.2, 0.3 } })
check(math.abs(ns.Akzent[1] - 0.1) > 0.01, "Plugin: eigene Akzentfarbe ohne ForeverUI-Interface")
wbPlugin.anwenden()

local protokoll = ns.db.fehler or {}
for _, f in ipairs(protokoll) do print("PROTOKOLL " .. tostring(f)) end
check(#protokoll == 0, "keine Fehler im Protokoll")

print(fehler == 0 and "\nAlles in Ordnung." or ("\n" .. fehler .. " Fehler."))
os.exit(fehler == 0 and 0 or 1)
