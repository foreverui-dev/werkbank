-- Ziele: Berufsziele, Mindestbestände, Werkbank-Erfolge, Herstellungsverlauf und Ertrag,
-- Materialverbrauch, Statistik je Beruf, neue Rezepte seit dem Datenupdate, Vorlagen,
-- Prioritäten, Rezeptvergleich, Übersicht und Diagnose
local _, ns = ...
local D = ns.daten
local F = ns.F

local function Jetzt() return time and time() or 0 end
local STUFEN = { 75, 150, 225, 300 }

local function Melden(text, laut)
  ns.Print(text)
  if ns.db.optionen.zielMeldung ~= false then
    if ns.Bildschirm then ns.Bildschirm(text) end
    if laut then ns.Sprechen(text) end
  end
end

-- Nächste Stufe, ab der ein Lehrer weiterhilft
function ns.NaechsteStufe(stufe)
  for _, s in ipairs(STUFEN) do
    if (stufe or 0) < s then return s end
  end
end

function ns.GelerntZahl(beruf, c)
  c = c or ns.char
  local n = 0
  for rid in pairs(c.bekannt or {}) do
    local b = ns.berufOf[rid]
    if b and b.id == beruf then n = n + 1 end
  end
  return n
end

-- ---------- Berufsziele ----------

function ns.ZieleDB()
  ns.char.ziele = ns.char.ziele or {}
  return ns.char.ziele
end

-- „/wb ziel Schmiedekunst 225“ (Fertigkeit) oder „… 40 rezepte“ (Anzahl gelernter Rezepte)
function ns.ZielSetzen(text)
  text = tostring(text or "")
  local name, zahl, art = text:match("^(.-)%s+(%d+)%s*(%a*)$")
  local b = name and ns.berufName[name]
  if not b and name then
    for n, x in pairs(ns.berufName) do
      if n:lower():find(name:lower(), 1, true) then b = x break end
    end
  end
  if not b then
    ns.Print("So geht's: /wb ziel Schmiedekunst 225  oder  /wb ziel Alchimie 40 rezepte  (0 löscht das Ziel)")
    return nil
  end
  local z = ns.ZieleDB()
  z[b.id] = z[b.id] or {}
  local feld = (art and art:lower():find("^rezept")) and "rezepte" or "stufe"
  zahl = tonumber(zahl)
  z[b.id][feld] = zahl > 0 and zahl or nil
  z[b.id]["erreicht" .. feld] = nil
  if not next(z[b.id]) then z[b.id] = nil end
  ns.Print(zahl > 0 and ("Ziel für " .. b.name .. ": " .. zahl .. (feld == "rezepte" and " gelernte Rezepte." or " Fertigkeit.")) or ("Ziel für " .. b.name .. " gelöscht."))
  ns.ZielePruefen()
  ns.Aktualisieren()
  return b.id
end

function ns.ZielePruefen()
  for id, z in pairs(ns.ZieleDB()) do
    local b = ns.beruf[id]
    local s = ns.char.berufe[id]
    if b and z.stufe and s and (s.stufe or 0) >= z.stufe and not z.erreichtstufe then
      z.erreichtstufe = Jetzt()
      Melden(F.gruen .. "Ziel erreicht: " .. b.name .. " " .. z.stufe .. "!|r", true)
    end
    if b and z.rezepte and ns.GelerntZahl(id) >= z.rezepte and not z.erreichtrezepte then
      z.erreichtrezepte = Jetzt()
      Melden(F.gruen .. "Ziel erreicht: " .. z.rezepte .. " Rezepte in " .. b.name .. "!|r", true)
    end
  end
end

local function Balken(anteil)
  local voll = math.floor(math.max(0, math.min(1, anteil)) * 20 + 0.5)
  return "[" .. string.rep("|", voll) .. F.grau .. string.rep(".", 20 - voll) .. "|r]"
end

function ns.ZieleText()
  local z = {}
  for id, s in pairs(ns.char.berufe) do
    local b = ns.beruf[id]
    if b then
      local ziel = ns.ZieleDB()[id] or {}
      local gelernt = ns.GelerntZahl(id)
      local t = F.gold .. b.name .. "|r  " .. (s.stufe or 0) .. "/" .. (s.max or "?")
      local naechste = ns.NaechsteStufe(s.stufe)
      if naechste then t = t .. F.grau .. "  · noch " .. (naechste - (s.stufe or 0)) .. " bis " .. naechste .. "|r" end
      z[#z + 1] = t
      if ziel.stufe then
        z[#z + 1] = "    Ziel Fertigkeit " .. ziel.stufe .. " " .. Balken((s.stufe or 0) / ziel.stufe) .. ((s.stufe or 0) >= ziel.stufe and (F.gruen .. " erreicht|r") or "")
      end
      z[#z + 1] = "    Gelernt: " .. gelernt .. " von " .. b.anzahl .. " Rezepten" .. (ziel.rezepte and ("  · Ziel " .. ziel.rezepte .. " " .. Balken(gelernt / ziel.rezepte)) or "")
    end
  end
  if #z == 0 then z[1] = F.grau .. "Öffne ein Berufsfenster, dann stehen hier deine Berufe und Ziele.|r" end
  z[#z + 1] = ""
  z[#z + 1] = F.grau .. "Ziele setzen: /wb ziel Schmiedekunst 225  oder  /wb ziel Alchimie 40 rezepte|r"
  return table.concat(z, "\n")
end

-- ---------- Mindestbestände ----------

local gewarnt = {}

function ns.MindestSetzen(text)
  local name, zahl = tostring(text or ""):match("^(.-)%s+(%d+)$")
  local id = name and ns.GegenstandSuchen(name)
  if not id then
    ns.Print("So geht's: /wb mindest Leinenstoff 40  (0 löscht den Mindestbestand)")
    return nil
  end
  ns.db.mindest = ns.db.mindest or {}
  zahl = tonumber(zahl)
  ns.db.mindest[id] = zahl > 0 and zahl or nil
  gewarnt[id] = nil
  ns.Print(zahl > 0 and ("Mindestbestand " .. ns.ItemName(id) .. ": " .. zahl .. ".") or ("Mindestbestand für " .. ns.ItemName(id) .. " gelöscht."))
  ns.Aktualisieren()
  return id
end

function ns.MindestZuWenig()
  local t = {}
  for id, soll in pairs(ns.db.mindest or {}) do
    local hat = ns.Vorrat(id)
    if hat < soll then t[id] = soll - hat end
  end
  return t
end

function ns.MindestPruefen()
  if ns.db.optionen.mindestWarnung == false then return end
  for id, fehlt in pairs(ns.MindestZuWenig()) do
    if not gewarnt[id] then
      gewarnt[id] = true
      ns.Print(F.rot .. "Mindestbestand unterschritten:|r " .. ns.ItemName(id) .. " (es fehlen " .. fehlt .. ")")
    end
  end
  for id in pairs(gewarnt) do
    if not ns.MindestZuWenig()[id] then gewarnt[id] = nil end
  end
end

-- Herstellbare Gegenstände unter Mindestbestand auf die Liste
function ns.MindestAufListe()
  local n = 0
  if ns.Schnappschuss then ns.Schnappschuss() end
  for id, fehlt in pairs(ns.MindestZuWenig()) do
    local rid = ns.RezeptFuer(id)
    if rid then
      local mal = math.ceil(fehlt / ns.Menge(D.rezepte[rid]))
      ns.L.liste[rid] = math.max(ns.L.liste[rid] or 0, mal)
      n = n + 1
    end
  end
  ns.Aktualisieren()
  ns.Print(n == 0 and "Nichts Herstellbares unter dem Mindestbestand." or (n .. " Rezept" .. (n == 1 and "" or "e") .. " zum Auffüllen auf die Liste gesetzt."))
  return n
end

-- ---------- Herstellungsverlauf, Ertrag, Verbrauch ----------

function ns.HistorieDB()
  ns.db.historie = ns.db.historie or {}
  ns.db.ertrag = ns.db.ertrag or {}
  return ns.db.historie
end

function ns.HistorieMerken(id, n)
  if not id then return end
  local h = ns.HistorieDB()
  local rid = ns.RezeptFuer(id)
  local letzte = h[1]
  local jetzt = Jetzt()
  if letzte and letzte.id == id and letzte.wer == (ns.char.name or "?") and jetzt - letzte.zeit < 120 then
    letzte.n, letzte.mal, letzte.zeit = letzte.n + n, (letzte.mal or 1) + 1, jetzt
  else
    table.insert(h, 1, { id = id, n = n, mal = 1, zeit = jetzt, wer = ns.char.name or "?" })
    while #h > 200 do table.remove(h) end
  end
  if rid then
    local e = ns.db.ertrag[rid] or { mal = 0, stueck = 0 }
    e.mal, e.stueck = e.mal + 1, e.stueck + n
    ns.db.ertrag[rid] = e
  end
end

function ns.Ertrag(rid)
  local e = ns.db.ertrag and ns.db.ertrag[rid]
  if not e or e.mal == 0 then return nil end
  return e.stueck / e.mal, e.mal
end

ns.AufEreignis("CHAT_MSG_LOOT", function(msg)
  local id, n = ns.HerstellungAusChat(msg)
  if id then
    ns.HistorieMerken(id, n)
    ns.ErfolgePruefen()
  end
end)

function ns.HistorieText(max)
  local h = ns.HistorieDB()
  local z = {}
  for i = 1, math.min(#h, max or 40) do
    local e = h[i]
    z[#z + 1] = (date and date("%d.%m. %H:%M", e.zeit) or "") .. "  " .. e.n .. "× " .. ns.ItemName(e.id) .. F.grau .. " (" .. e.wer .. (e.mal > 1 and (", " .. e.mal .. "-mal") or "") .. ")|r"
  end
  if #z == 0 then z[1] = F.grau .. "Noch nichts hergestellt, seit es den Verlauf gibt.|r" end
  return table.concat(z, "\n")
end

-- Verbrauch in dieser Sitzung: Materialien, die aus den Taschen verschwunden sind
local verbrauch, vorher, bereit = {}, {}, false
local function Verbrauch()
  local neu = {}
  for id in pairs(ns.char.taschen or {}) do neu[id] = ns.Vorrat(id) end
  for id in pairs(vorher) do neu[id] = neu[id] or ns.Vorrat(id) end
  if bereit then
    for id, alt in pairs(vorher) do
      local jetzt = neu[id] or 0
      if jetzt < alt and ns.usedIn[id] then verbrauch[id] = (verbrauch[id] or 0) + alt - jetzt end
    end
  end
  vorher, bereit = neu, true
  ns.MindestPruefen()
end
ns.AufEreignis("PLAYER_LOGIN", Verbrauch)
ns.AufEreignis("BAG_UPDATE_DELAYED", Verbrauch)
function ns.Verbrauch() return verbrauch end

-- Hergestellt je Beruf (aus der Statistik)
function ns.BerufStatistik()
  local s = ns.StatistikDB()
  local t = {}
  for id, n in pairs(s.gesamt) do
    local rid = ns.RezeptFuer(id)
    local b = rid and ns.berufOf[rid]
    if b then t[b.name] = (t[b.name] or 0) + n end
  end
  return t
end

function ns.AuswertungText()
  local z = { F.gold .. "Hergestellt je Beruf|r" }
  local t = ns.BerufStatistik()
  local namen = {}
  for name in pairs(t) do namen[#namen + 1] = name end
  table.sort(namen, function(a, b) return t[a] > t[b] end)
  if #namen == 0 then z[#z + 1] = F.grau .. "  Noch nichts gezählt.|r" end
  for _, name in ipairs(namen) do z[#z + 1] = "  " .. name .. ": " .. ns.Zahl(t[name]) end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Verbrauch in dieser Sitzung|r"
  local ids = {}
  for id in pairs(verbrauch) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return verbrauch[a] > verbrauch[b] end)
  if #ids == 0 then z[#z + 1] = F.grau .. "  Noch nichts verbraucht.|r" end
  for i = 1, math.min(#ids, 12) do z[#z + 1] = "  " .. verbrauch[ids[i]] .. "× " .. ns.ItemName(ids[i]) end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Durchschnittlicher Ertrag|r"
  local er = {}
  for rid, e in pairs(ns.db.ertrag or {}) do
    local r = D.rezepte[rid]
    if r and type(r[3]) == "table" and e.mal > 0 then
      er[#er + 1] = "  " .. ns.RezeptName(rid) .. ": " .. string.format("%.1f", e.stueck / e.mal) .. " pro Herstellung (" .. e.mal .. "-mal, laut Rezept " .. r[3][1] .. "–" .. r[3][2] .. ")"
    end
  end
  table.sort(er)
  if #er == 0 then z[#z + 1] = F.grau .. "  Erscheint bei Rezepten mit schwankender Menge, sobald du sie herstellst.|r" end
  for _, e in ipairs(er) do z[#z + 1] = e end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Zuletzt hergestellt|r"
  z[#z + 1] = ns.HistorieText(15)
  return table.concat(z, "\n")
end

-- ---------- Werkbank-Erfolge ----------

local function Summe(t)
  local n = 0
  for _, x in pairs(t or {}) do n = n + x end
  return n
end

local function Anzahl(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function Erledigt()
  local n = 0
  for _, k in pairs(ns.db.kunden or {}) do n = n + (k.anzahl or 0) end
  return n
end

local function Hoechste()
  local m = 0
  for _, c in pairs(ns.db.chars) do
    for _, s in pairs(c.berufe or {}) do m = math.max(m, s.stufe or 0) end
  end
  return m
end

ns.ERFOLGE = {
  { "erste", "Erste Schritte", "Etwas hergestellt", function() return Summe(ns.StatistikDB().gesamt) >= 1 end },
  { "hundert", "Fleißige Hände", "100 Gegenstände hergestellt", function() return Summe(ns.StatistikDB().gesamt) >= 100 end },
  { "tausend", "Meisterwerkstatt", "1.000 Gegenstände hergestellt", function() return Summe(ns.StatistikDB().gesamt) >= 1000 end },
  { "vielfalt", "Vielseitig", "25 verschiedene Gegenstände hergestellt", function() return Anzahl(ns.StatistikDB().gesamt) >= 25 end },
  { "geselle", "Geselle", "Einen Beruf auf 150 gebracht", function() return Hoechste() >= 150 end },
  { "meister", "Meister", "Einen Beruf auf 300 gebracht", function() return Hoechste() >= 300 end },
  { "sammler", "Rezeptsammler", "100 Rezepte mit einem Charakter gelernt", function() return Anzahl(ns.char.bekannt) >= 100 end },
  { "kunde", "Zu Diensten", "Den ersten Auftrag abgeschlossen", function() return Erledigt() >= 1 end },
  { "kundschaft", "Stammkundschaft", "10 Aufträge abgeschlossen", function() return Erledigt() >= 10 end },
  { "haendler", "Preisbewusst", "50 Preise im Auktionshaus gemerkt", function() return Anzahl(ns.db.preise) >= 50 end },
  { "planer", "Planer", "Drei Einkaufslisten angelegt", function() return #ns.ListenOrt().listen >= 3 end },
  { "familie", "Familienbetrieb", "Drei Charaktere mit Berufen", function()
    local n = 0
    for _, c in pairs(ns.db.chars) do if next(c.berufe or {}) then n = n + 1 end end
    return n >= 3
  end },
  { "ziel", "Zielstrebig", "Ein selbst gesetztes Berufsziel erreicht", function()
    for _, c in pairs(ns.db.chars) do
      for _, z in pairs(c.ziele or {}) do if z.erreichtstufe or z.erreichtrezepte then return true end end
    end
  end },
  { "vorrat", "Gut gerüstet", "Fünf Mindestbestände eingerichtet", function() return Anzahl(ns.db.mindest) >= 5 end },
}

function ns.ErfolgePruefen(still)
  ns.db.erfolge = ns.db.erfolge or {}
  local neu = 0
  for _, e in ipairs(ns.ERFOLGE) do
    if not ns.db.erfolge[e[1]] then
      local ok, ja = pcall(e[4])
      if ok and ja then
        ns.db.erfolge[e[1]] = Jetzt()
        neu = neu + 1
        if not still then Melden(F.gold .. "Werkbank-Erfolg: " .. e[2] .. "|r – " .. e[3], true) end
      end
    end
  end
  return neu
end

function ns.ErfolgeText()
  ns.ErfolgePruefen(true)
  local z, n = {}, 0
  for _, e in ipairs(ns.ERFOLGE) do
    local wann = ns.db.erfolge[e[1]]
    if wann then
      n = n + 1
      z[#z + 1] = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. F.gold .. e[2] .. "|r – " .. e[3] .. F.grau .. (date and ("  (" .. date("%d.%m.%Y", wann) .. ")") or "") .. "|r"
    else
      z[#z + 1] = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:0|t " .. F.grau .. e[2] .. " – " .. e[3] .. "|r"
    end
  end
  table.insert(z, 1, n .. " von " .. #ns.ERFOLGE .. " Erfolgen" .. "\n")
  return table.concat(z, "\n"), n
end

-- ---------- Neu seit dem Datenupdate ----------

function ns.NeueRezepte()
  return ns.db.neueRezepte or {}
end

function ns.DatenstandPruefen()
  local alt = ns.db.rezeptStand
  if alt == D.stand then return end
  local bekannt = ns.db.rezeptIds
  local neu = {}
  local ids = {}
  for rid in pairs(D.rezepte) do
    ids[#ids + 1] = rid
    if bekannt and not bekannt[rid] then neu[rid] = true end
  end
  local set = {}
  for _, rid in ipairs(ids) do set[rid] = true end
  if bekannt then
    ns.db.neueRezepte = neu
    local n = Anzahl(neu)
    if n > 0 then ns.Print(n .. " neue Rezepte seit dem letzten Datenstand. Filter „Neu seit Datenupdate“ im Rezeptbuch.") end
  end
  ns.db.rezeptIds, ns.db.rezeptStand = set, D.stand
end

-- ---------- Vorlagen ----------

function ns.VorlageSpeichern(name)
  name = (name and name ~= "") and name or (ns.L.name or "Vorlage")
  ns.db.vorlagen = ns.db.vorlagen or {}
  local l, s = {}, {}
  for k, v in pairs(ns.L.liste) do l[k] = v end
  for k, v in pairs(ns.L.selbst) do s[k] = v end
  ns.db.vorlagen[name] = { liste = l, selbst = s }
  ns.Print("Vorlage „" .. name .. "“ gespeichert.")
  return name
end

function ns.VorlageLaden(name)
  local v = ns.db.vorlagen and ns.db.vorlagen[name]
  if not v then
    for n, x in pairs(ns.db.vorlagen or {}) do
      if n:lower() == tostring(name):lower() then v, name = x, n break end
    end
  end
  if not v then
    ns.Print("Diese Vorlage gibt es nicht. Vorhanden: " .. table.concat(ns.Vorlagen(), ", "))
    return nil
  end
  ns.ListeNeu(name)
  for k, x in pairs(v.liste) do ns.L.liste[k] = x end
  for k, x in pairs(v.selbst) do ns.L.selbst[k] = x end
  ns.Aktualisieren()
  ns.Print("Neue Liste aus der Vorlage „" .. name .. "“.")
  return ns.L
end

function ns.VorlageLoeschen(name)
  if ns.db.vorlagen and ns.db.vorlagen[name] then
    ns.db.vorlagen[name] = nil
    return true
  end
end

function ns.Vorlagen()
  local t = {}
  for n in pairs(ns.db.vorlagen or {}) do t[#t + 1] = n end
  table.sort(t)
  return t
end

-- ---------- Prioritäten auf der Liste ----------

ns.PRIO_NAME = { "niedrig", "normal", "dringend" }

function ns.Prio(rid)
  return (ns.L.prio and ns.L.prio[rid]) or 2
end

function ns.PrioUmschalten(rid, wert)
  ns.L.prio = ns.L.prio or {}
  local p = wert or (ns.Prio(rid) % 3 + 1)
  ns.L.prio[rid] = p ~= 2 and p or nil
  ns.Aktualisieren()
  return p
end

-- ---------- Detailangaben und Vergleich ----------

-- Zusatzzeilen für die Rezeptseite: Kosten, Gewinn, Warnung, Alternativen, Quellen, Werkzeuge, Ertrag
function ns.RezeptExtras(rid)
  local r = D.rezepte[rid]
  if not r then return {} end
  local z = {}
  local kosten, ohne = ns.RezeptKosten(rid)
  if kosten > 0 then
    z[#z + 1] = "Materialkosten: " .. ns.Geld(kosten) .. (ohne > 0 and (F.grau .. " (" .. ohne .. " ohne Preis)|r") or "")
  end
  local gewinn, erloes = ns.RezeptGewinn(rid)
  if gewinn then
    z[#z + 1] = "Verkauf im Auktionshaus: " .. ns.Geld(erloes) .. " nach Gebühr  ·  " .. (gewinn >= 0 and (F.gruen .. "Gewinn " .. ns.Geld(gewinn)) or (F.rot .. "Verlust " .. ns.Geld(-gewinn))) .. "|r"
    if gewinn < 0 and ohne == 0 then z[#z + 1] = F.rot .. "Unwirtschaftlich: Die Materialien bringen einzeln mehr ein.|r" end
  end
  if r[2] then
    local andere = {}
    for _, x in ipairs(ns.madeBy[r[2]] or {}) do
      if x ~= rid then andere[#andere + 1] = ns.RezeptName(x) .. " (" .. (ns.berufOf[x] and ns.berufOf[x].name or "?") .. ")" end
    end
    if #andere > 0 then z[#z + 1] = "Alternativen: " .. table.concat(andere, ", ") end
    local t = ns.SelbstOderKaufen(r[2])
    if t then z[#z + 1] = t end
  end
  local q = ns.Quellen(rid)
  if #q > 0 then z[#z + 1] = "Rezept gesehen: " .. table.concat(q, "; ") end
  local wz = ns.db.werkzeuge and ns.db.werkzeuge[rid]
  if type(wz) == "table" then wz = table.concat(wz, ", ") end
  if wz and wz ~= "" then z[#z + 1] = "Braucht: " .. wz end
  local er, mal = ns.Ertrag(rid)
  if er then z[#z + 1] = "Dein Ertrag: " .. string.format("%.1f", er) .. " pro Herstellung (" .. mal .. "-mal)" end
  return z
end

local function Spalte(rid)
  local r = D.rezepte[rid]
  local b = ns.berufOf[rid]
  local t = {
    F.gold .. ns.RezeptName(rid) .. "|r",
    (b and b.name or "?") .. " · " .. (ns.katOf[rid] or ""),
    "Ergibt: " .. (type(r[3]) == "table" and (r[3][1] .. "–" .. r[3][2]) or tostring(r[3])),
  }
  local z = r[4]
  for i = 1, #z, 2 do t[#t + 1] = "  " .. z[i + 1] .. "× " .. ns.ItemName(z[i]) end
  local k, ohne = ns.RezeptKosten(rid)
  t[#t + 1] = "Kosten: " .. (k > 0 and ns.Geld(k) or "?") .. (ohne > 0 and " (unvollständig)" or "")
  local g = ns.RezeptGewinn(rid)
  t[#t + 1] = "Gewinn: " .. (g and ns.Geld(math.abs(g)) .. (g < 0 and " Verlust" or "") or "?")
  t[#t + 1] = "Jetzt möglich: " .. ns.Moeglich(rid) .. "×"
  t[#t + 1] = "Gelernt: " .. (ns.char.bekannt[rid] and "ja" or "nein")
  return t
end

function ns.VergleichText(a, b)
  if not (a and D.rezepte[a] and b and D.rezepte[b]) then
    return F.grau .. "Zwei Rezepte wählen: auf der Rezeptseite „Vergleichen“ drücken oder /wb vergleich Rezept A; Rezept B|r"
  end
  local z = {}
  for _, rid in ipairs({ a, b }) do
    for _, zeile in ipairs(Spalte(rid)) do z[#z + 1] = zeile end
    z[#z + 1] = ""
  end
  local ka, kb = ns.RezeptKosten(a), ns.RezeptKosten(b)
  if ka > 0 and kb > 0 and ka ~= kb then
    z[#z + 1] = F.gold .. "Günstiger: " .. ns.RezeptName(ka < kb and a or b) .. " um " .. ns.Geld(math.abs(ka - kb)) .. "|r"
  end
  return table.concat(z, "\n")
end

-- ---------- Übersicht ----------

function ns.UebersichtText()
  local z = {}
  local anteil = ns.ListeFortschritt()
  z[#z + 1] = F.gold .. "Einkaufsliste „" .. (ns.L.name or "") .. "“|r  " .. (anteil and (math.floor(anteil * 100 + 0.5) .. " % beisammen") or F.grau .. "leer|r")
  local offen, ueber = 0, 0
  for _, a in ipairs(ns.AuftraegeSortiert("frist")) do
    offen = offen + 1
    if a.frist and a.frist < Jetzt() then ueber = ueber + 1 end
  end
  z[#z + 1] = F.gold .. "Aufträge|r  " .. offen .. " offen" .. (ueber > 0 and (F.rot .. ", " .. ueber .. " überfällig|r") or "")
  local auftraege = ns.AuftraegeSortiert("frist")
  for i = 1, math.min(3, #auftraege) do
    local a = auftraege[i]
    z[#z + 1] = "    " .. a.n .. "× " .. ns.RezeptName(a.rid) .. " – " .. a.kunde .. "  " .. ns.FristText(a.frist)
  end
  local bereit = {}
  for _, c in pairs(ns.db.chars) do
    for name, ende in pairs(c.abklingzeiten or {}) do
      if ende <= Jetzt() then bereit[#bereit + 1] = (c.name or "?") .. " (" .. name .. ")" end
    end
  end
  table.sort(bereit)
  if #bereit > 0 then z[#z + 1] = F.gold .. "Abklingzeiten bereit|r  " .. table.concat(bereit, ", ") end
  local wenig = {}
  for id, f in pairs(ns.MindestZuWenig()) do wenig[#wenig + 1] = ns.ItemName(id) .. " (-" .. f .. ")" end
  table.sort(wenig)
  if #wenig > 0 then z[#z + 1] = F.rot .. "Unter Mindestbestand|r  " .. table.concat(wenig, ", ") end
  local s = ns.StatistikDB()
  z[#z + 1] = F.gold .. "Heute hergestellt|r  " .. Summe(s.heute) .. "  · insgesamt " .. ns.Zahl(Summe(s.gesamt))
  z[#z + 1] = ""
  for id, st in pairs(ns.char.berufe) do
    local b = ns.beruf[id]
    if b then
      local naechste = ns.NaechsteStufe(st.stufe)
      local ziel = ns.ZieleDB()[id]
      z[#z + 1] = b.name .. " " .. (st.stufe or 0) .. "/" .. (st.max or "?") .. (naechste and (F.grau .. "  · noch " .. (naechste - (st.stufe or 0)) .. " bis " .. naechste .. "|r") or "") .. (ziel and ziel.stufe and ("  · Ziel " .. ziel.stufe) or "")
    end
  end
  local _, erfolge = ns.ErfolgeText()
  z[#z + 1] = ""
  z[#z + 1] = F.grau .. "Werkbank-Erfolge: " .. erfolge .. " von " .. #ns.ERFOLGE .. "  · Preise gemerkt: " .. Anzahl(ns.db.preise) .. "  · Charaktere: " .. Anzahl(ns.db.chars) .. "|r"
  local neu = Anzahl(ns.NeueRezepte())
  if neu > 0 then z[#z + 1] = F.gruen .. neu .. " neue Rezepte seit dem letzten Datenupdate.|r" end
  return table.concat(z, "\n")
end

-- ---------- Diagnose ----------

function ns.DiagnoseText()
  local z = {}
  local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  z[#z + 1] = F.gold .. "Werkbank|r " .. tostring(GetMeta and GetMeta("Werkbank", "Version") or "?") .. "  · Datenstand " .. D.stand .. "  · Speicherstand " .. tostring(ns.db.schema)
  if GetBuildInfo then
    local v, build, _, iface = GetBuildInfo()
    z[#z + 1] = "Spiel: " .. tostring(v) .. " (" .. tostring(build) .. "), Interface " .. tostring(iface)
  end
  if GetLocale then z[#z + 1] = "Sprache: " .. GetLocale() end
  local nr, ni = 0, 0
  for _ in pairs(D.rezepte) do nr = nr + 1 end
  for _ in pairs(D.items) do ni = ni + 1 end
  z[#z + 1] = "Daten: " .. ns.Zahl(nr) .. " Rezepte, " .. ns.Zahl(ni) .. " Gegenstände"
  z[#z + 1] = "Gespeichert: " .. Anzahl(ns.db.chars) .. " Charaktere, " .. #ns.ListenOrt().listen .. " Listen, " .. Anzahl(ns.db.preise) .. " Preise, " .. #(ns.db.auftraege and ns.db.auftraege.liste or {}) .. " Aufträge, " .. #(ns.db.historie or {}) .. " Verlaufseinträge, " .. #(ns.db.fehler or {}) .. " Fehler"
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    pcall(UpdateAddOnMemoryUsage)
    local ok, kb = pcall(GetAddOnMemoryUsage, "Werkbank")
    if ok and kb then z[#z + 1] = "Speicherverbrauch: " .. ns.Zahl(kb) .. " KB" end
  end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Schnittstellen des Spiels|r"
  local apis = {
    { "Berufsfenster", GetTradeSkillInfo }, { "Handwerksfenster", GetCraftInfo },
    { "Werkzeuge", GetTradeSkillTools }, { "Taschen (neu)", C_Container and C_Container.GetContainerItemInfo },
    { "Auktionshaus", GetAuctionItemInfo }, { "Händler", GetMerchantItemInfo },
    { "Post", SendMail }, { "Zeitgeber", C_Timer and C_Timer.After },
    { "Vorlesen", C_VoiceChat and C_VoiceChat.SpeakText }, { "Geschützte Werte", issecretvalue },
  }
  for _, a in ipairs(apis) do z[#z + 1] = "  " .. a[1] .. ": " .. (a[2] and (F.gruen .. "da|r") or (F.grau .. "nicht vorhanden|r")) end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Geänderte Einstellungen|r"
  local geaendert = {}
  for k, v in pairs(ns.db.optionen) do
    if ns.STANDARD[k] ~= nil and ns.STANDARD[k] ~= v and type(v) ~= "table" then geaendert[#geaendert + 1] = k .. " = " .. tostring(v) end
  end
  table.sort(geaendert)
  z[#z + 1] = #geaendert > 0 and ("  " .. table.concat(geaendert, ", ")) or (F.grau .. "  keine|r")
  return table.concat(z, "\n")
end

-- ---------- Start ----------

ns.AufEreignis("PLAYER_LOGIN", function()
  ns.DatenstandPruefen()
  ns.ErfolgePruefen(true)
  ns.ZielePruefen()
end)
ns.AufEreignis("TRADE_SKILL_UPDATE", function() ns.ZielePruefen() end)
ns.AufEreignis("SKILL_LINES_CHANGED", function() ns.ZielePruefen() ns.ErfolgePruefen() end)
