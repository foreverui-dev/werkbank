-- Aufträge: Kundenaufträge von Hand verwalten (Kunde, Rezept, Anzahl, Lohn, Frist,
-- Notiz, Material vom Kunden, Aufwand, Priorität, Status), Kunden mit Verlauf
local _, ns = ...
local D = ns.daten
local F = ns.F

ns.AUFTRAG_STATUS = { "geplant", "in Arbeit", "fertig", "abgeschlossen" }
ns.STUFEN3 = { "niedrig", "mittel", "hoch" }

local function Jetzt() return time and time() or 0 end

function ns.AuftraegeDB()
  ns.db.auftraege = ns.db.auftraege or { liste = {}, naechste = 1 }
  ns.db.kunden = ns.db.kunden or {}
  return ns.db.auftraege
end

-- Rezept aus Name, Gegenstandsname, Link oder Nummer
function ns.RezeptSuchen(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  local nr = tonumber(text)
  if nr and D.rezepte[nr] then return nr end
  local such = text:gsub("%[", ""):gsub("%]", ""):lower()
  for rid, r in pairs(D.rezepte) do
    if r[1]:lower() == such then return rid end
  end
  local id = ns.GegenstandSuchen(text)
  local rid = id and ns.RezeptFuer(id)
  if rid then return rid end
  for rid, r in pairs(D.rezepte) do
    if r[1]:lower():find(such, 1, true) then return rid end
  end
  return nil
end

-- Frist lesen: „24.12.“, „24.12.2026“, „+3“ (Tage), „heute“, „morgen“ → Zeitpunkt (Tagesende)
function ns.FristLesen(text)
  text = tostring(text or ""):lower():gsub("%s", "")
  if text == "" or not time or not date then return nil end
  local heute = date("*t")
  local function Ende(j, m, t) return time({ year = j, month = m, day = t, hour = 23, min = 59, sec = 0 }) end
  if text == "heute" then return Ende(heute.year, heute.month, heute.day) end
  if text == "morgen" then return Ende(heute.year, heute.month, heute.day + 1) end
  local plus = text:match("^%+(%d+)$")
  if plus then return Ende(heute.year, heute.month, heute.day + tonumber(plus)) end
  local t, m, j = text:match("^(%d%d?)%.(%d%d?)%.?(%d*)$")
  if t then
    t, m = tonumber(t), tonumber(m)
    if m < 1 or m > 12 or t < 1 or t > 31 then return nil end
    j = tonumber(j)
    if j and j < 100 then j = 2000 + j end
    if not j then
      j = heute.year
      if Ende(j, m, t) < Ende(heute.year, heute.month, heute.day) then j = j + 1 end
    end
    return Ende(j, m, t)
  end
  return nil
end

function ns.FristText(zeit)
  if not zeit then return F.grau .. "ohne Frist|r" end
  local rest = zeit - Jetzt()
  local tage = math.floor(rest / 86400)
  local txt = date and date("%d.%m.", zeit) or "?"
  if rest < 0 then return F.rot .. txt .. " (überfällig)|r" end
  if tage == 0 then return F.gold .. txt .. " (heute)|r" end
  if tage == 1 then return F.gold .. txt .. " (morgen)|r" end
  return txt .. F.grau .. " (in " .. tage .. " Tagen)|r"
end

-- ---------- Aufträge ----------

function ns.AuftragNeu(d)
  local db = ns.AuftraegeDB()
  if not d or not d.rid or not D.rezepte[d.rid] then return nil end
  local a = {
    nr = db.naechste,
    kunde = (d.kunde and d.kunde ~= "") and d.kunde or "Unbekannt",
    rid = d.rid,
    n = math.max(1, math.floor(tonumber(d.n) or 1)),
    lohn = d.lohn,
    frist = d.frist,
    notiz = d.notiz,
    kundenMat = d.kundenMat and true or nil,
    aufwand = d.aufwand or 2,
    prio = d.prio or 2,
    status = 1,
    erstellt = Jetzt(),
    wer = ns.char and ns.char.name,
  }
  db.naechste = db.naechste + 1
  db.liste[#db.liste + 1] = a
  local k = ns.KundeHolen(a.kunde)
  k.offen = (k.offen or 0) + 1
  ns.Aktualisieren()
  return a
end

-- Kurzform: „Kunde; Rezept; Anzahl; Lohn; Frist; Notiz“
function ns.AuftragAusText(text)
  local teile = {}
  for t in (tostring(text or "") .. ";"):gmatch("(.-);") do teile[#teile + 1] = t:gsub("^%s+", ""):gsub("%s+$", "") end
  local rid = ns.RezeptSuchen(teile[2])
  if not rid then
    ns.Print("So geht's: /wb auftrag Kunde; Rezept; Anzahl; Lohn; Frist; Notiz  (z. B. Thrall; Schwere Rüstung; 5; 2g; 24.12.; bringt Leder mit)")
    return nil
  end
  local notiz = teile[6]
  local a = ns.AuftragNeu({
    kunde = teile[1], rid = rid, n = teile[3],
    lohn = ns.GeldLesen(teile[4]), frist = ns.FristLesen(teile[5]),
    notiz = (notiz and notiz ~= "") and notiz or nil,
    kundenMat = notiz and notiz:lower():find("bringt", 1, true) and true or nil,
  })
  if a then ns.Print("Auftrag #" .. a.nr .. ": " .. a.n .. "× " .. ns.RezeptName(rid) .. " für " .. a.kunde .. ".") end
  return a
end

function ns.AuftragHolen(nr)
  nr = tonumber(nr)
  for i, a in ipairs(ns.AuftraegeDB().liste) do
    if a.nr == nr then return a, i end
  end
end

function ns.AuftragStatus(nr, status)
  local a = ns.AuftragHolen(nr)
  if not a then return nil end
  local alt = a.status
  status = status or (a.status % #ns.AUFTRAG_STATUS + 1)
  a.status = status
  local k = ns.KundeHolen(a.kunde)
  if status == 4 and alt ~= 4 then
    a.erledigt = Jetzt()
    k.offen = math.max(0, (k.offen or 1) - 1)
    k.anzahl = (k.anzahl or 0) + 1
    k.summe = (k.summe or 0) + (a.lohn or 0)
    k.letzte = a.erledigt
    k.verlauf = k.verlauf or {}
    table.insert(k.verlauf, 1, { rid = a.rid, n = a.n, lohn = a.lohn, zeit = a.erledigt })
    while #k.verlauf > 20 do table.remove(k.verlauf) end
    ns.Sprechen("Auftrag für " .. a.kunde .. " abgeschlossen.")
  elseif alt == 4 and status ~= 4 then
    a.erledigt = nil
    k.offen = (k.offen or 0) + 1
  end
  ns.Aktualisieren()
  return a
end

function ns.AuftragLoeschen(nr)
  local a, i = ns.AuftragHolen(nr)
  if not a then return false end
  table.remove(ns.AuftraegeDB().liste, i)
  if a.status ~= 4 then
    local k = ns.KundeHolen(a.kunde)
    k.offen = math.max(0, (k.offen or 1) - 1)
  end
  ns.Aktualisieren()
  return true
end

function ns.AuftragDuplizieren(nr)
  local a = ns.AuftragHolen(nr)
  if not a then return nil end
  return ns.AuftragNeu({ kunde = a.kunde, rid = a.rid, n = a.n, lohn = a.lohn, notiz = a.notiz, kundenMat = a.kundenMat, aufwand = a.aufwand, prio = a.prio })
end

function ns.AuftragWert(nr, feld, wert)
  local a = ns.AuftragHolen(nr)
  if not a then return nil end
  if feld == "prio" or feld == "aufwand" then
    a[feld] = wert or ((a[feld] or 2) % 3 + 1)
  elseif feld == "kundenMat" then
    a.kundenMat = not a.kundenMat or nil
  else
    a[feld] = wert
  end
  ns.Aktualisieren()
  return a
end

-- Fehlende Materialien: { id = fehlt } (leer, wenn der Kunde das Material bringt)
function ns.AuftragFehlt(a)
  local fehlt = {}
  if a.kundenMat then return fehlt end
  local bedarf = ns.Rechnen({ [a.rid] = a.n }, {})
  for id, n in pairs(bedarf) do
    local f = n - ns.Vorrat(id)
    if f > 0 then fehlt[id] = f end
  end
  return fehlt
end

-- Gewinn: Lohn minus Materialkosten (wenn der Kunde Material bringt, nur der Lohn)
function ns.AuftragGewinn(a)
  local kosten, ohne = 0, 0
  if not a.kundenMat and ns.RezeptKosten then
    local k, o = ns.RezeptKosten(a.rid)
    local r = D.rezepte[a.rid]
    kosten, ohne = math.floor(k * math.ceil(a.n / ns.Menge(r)) + 0.5), o
  end
  if not a.lohn then return nil, kosten, ohne end
  return a.lohn - kosten, kosten, ohne
end

local function Offen(a) return a.status < 4 end

local function NachFrist(a, b)
  local x, y = a.frist or math.huge, b.frist or math.huge
  if x ~= y then return x < y end
  return a.nr < b.nr
end

local SORT = {
  frist = NachFrist,
  prio = function(a, b)
    if (a.prio or 2) ~= (b.prio or 2) then return (a.prio or 2) > (b.prio or 2) end
    return NachFrist(a, b)
  end,
  kunde = function(a, b)
    if a.kunde:lower() ~= b.kunde:lower() then return a.kunde:lower() < b.kunde:lower() end
    return a.nr < b.nr
  end,
  status = function(a, b)
    if a.status ~= b.status then return a.status < b.status end
    return a.nr < b.nr
  end,
  lohn = function(a, b)
    if (a.lohn or 0) ~= (b.lohn or 0) then return (a.lohn or 0) > (b.lohn or 0) end
    return a.nr < b.nr
  end,
  aufwand = function(a, b)
    if (a.aufwand or 2) ~= (b.aufwand or 2) then return (a.aufwand or 2) < (b.aufwand or 2) end
    return NachFrist(a, b)
  end,
  rezept = function(a, b)
    local ba, bb = ns.berufOf[a.rid], ns.berufOf[b.rid]
    local x, y = ba and ba.name or "", bb and bb.name or ""
    if x ~= y then return x < y end
    local ra, rb = ns.RezeptName(a.rid), ns.RezeptName(b.rid)
    if ra ~= rb then return ra < rb end
    return NachFrist(a, b)
  end,
}
ns.AUFTRAG_SORT = { "frist", "prio", "kunde", "status", "lohn", "aufwand", "rezept" }

function ns.AuftraegeSortiert(nach, alle)
  local t = {}
  for _, a in ipairs(ns.AuftraegeDB().liste) do
    if alle or Offen(a) then t[#t + 1] = a end
  end
  table.sort(t, SORT[nach or "frist"] or SORT.frist)
  return t
end

-- Alle offenen Aufträge (ohne Kundenmaterial) auf die aktive Einkaufsliste
function ns.AuftraegeAufListe()
  local n = 0
  if ns.Schnappschuss then ns.Schnappschuss() end
  for _, a in ipairs(ns.AuftraegeSortiert("frist")) do
    if a.status <= 2 and not a.kundenMat then
      ns.L.liste[a.rid] = (ns.L.liste[a.rid] or 0) + a.n
      n = n + 1
    end
  end
  ns.Aktualisieren()
  ns.Print(n == 0 and "Keine offenen Aufträge mit eigenem Material." or (n .. (n == 1 and " Auftrag" or " Aufträge") .. " auf die Liste „" .. (ns.L.name or "") .. "“ gesetzt."))
  return n
end

function ns.AuftragZeile(a)
  local fehlt = ns.AuftragFehlt(a)
  local nf = 0
  for _ in pairs(fehlt) do nf = nf + 1 end
  local status = ns.AUFTRAG_STATUS[a.status]
  local farbe = a.status == 4 and F.grau or a.status == 3 and F.gruen or ""
  local t = farbe .. "#" .. a.nr .. " " .. a.n .. "× " .. ns.RezeptName(a.rid) .. "|r – " .. a.kunde
  t = t .. "  " .. F.grau .. "[" .. status .. ", Prio " .. ns.STUFEN3[a.prio or 2] .. "]|r"
  if a.status < 4 then t = t .. "  " .. ns.FristText(a.frist) end
  local zeile2 = {}
  if a.kundenMat then zeile2[#zeile2 + 1] = "Kunde bringt Material"
  elseif nf == 0 then zeile2[#zeile2 + 1] = F.gruen .. "Material vollständig|r"
  else zeile2[#zeile2 + 1] = F.rot .. nf .. " Material" .. (nf == 1 and "" or "ien") .. " fehlen|r" end
  local g, k = ns.AuftragGewinn(a)
  if a.lohn then zeile2[#zeile2 + 1] = "Lohn " .. ns.Geld(a.lohn) end
  if k and k > 0 then zeile2[#zeile2 + 1] = "Kosten " .. ns.Geld(k) end
  if g then zeile2[#zeile2 + 1] = (g >= 0 and F.gruen .. "Gewinn " or F.rot .. "Verlust ") .. ns.Geld(math.abs(g)) .. "|r" end
  zeile2[#zeile2 + 1] = "Aufwand " .. ns.STUFEN3[a.aufwand or 2]
  if a.notiz then zeile2[#zeile2 + 1] = F.grau .. "„" .. a.notiz .. "“|r" end
  return t, "    " .. table.concat(zeile2, " · ")
end

function ns.AuftraegeText(nach, alle)
  local z = {}
  local liste = ns.AuftraegeSortiert(nach, alle)
  if #liste == 0 then
    z[1] = F.grau .. (alle and "Noch keine Aufträge." or "Keine offenen Aufträge.") .. "|r"
  end
  for _, a in ipairs(liste) do
    local a1, a2 = ns.AuftragZeile(a)
    z[#z + 1] = a1
    z[#z + 1] = a2
  end
  return table.concat(z, "\n")
end

-- ---------- Kunden ----------

function ns.KundeHolen(name)
  ns.AuftraegeDB()
  name = (name and name ~= "") and name or "Unbekannt"
  local k = ns.db.kunden[name]
  if not k then
    k = { anzahl = 0, summe = 0, offen = 0 }
    ns.db.kunden[name] = k
  end
  return k
end

function ns.KundeSetzen(text)
  local name, kontakt = tostring(text or ""):match("^(%S+)%s*(.-)$")
  if not name or name == "" then
    ns.Print("So geht's: /wb kunde Name Kontaktweg/Notiz  (z. B. /wb kunde Thrall flüstern abends, Gilde Horde)")
    return nil
  end
  local k = ns.KundeHolen(name)
  k.kontakt = kontakt ~= "" and kontakt or nil
  ns.Print("Kunde " .. name .. (k.kontakt and (": " .. k.kontakt) or " gespeichert."))
  ns.Aktualisieren()
  return k
end

function ns.KundenText()
  ns.AuftraegeDB()
  local namen = {}
  for name in pairs(ns.db.kunden) do namen[#namen + 1] = name end
  table.sort(namen, function(a, b) return a:lower() < b:lower() end)
  local z = {}
  if #namen == 0 then z[1] = F.grau .. "Noch keine Kunden. Sie entstehen mit dem ersten Auftrag.|r" end
  for _, name in ipairs(namen) do
    local k = ns.db.kunden[name]
    local t = F.gold .. name .. "|r  " .. (k.anzahl or 0) .. " erledigt"
    if (k.offen or 0) > 0 then t = t .. ", " .. k.offen .. " offen" end
    if (k.summe or 0) > 0 then t = t .. ", zusammen " .. ns.Geld(k.summe) end
    if k.letzte and date then t = t .. F.grau .. ", zuletzt " .. date("%d.%m.%Y", k.letzte) .. "|r" end
    z[#z + 1] = t
    if k.kontakt then z[#z + 1] = "    Kontakt: " .. k.kontakt end
    for i = 1, math.min(3, #(k.verlauf or {})) do
      local v = k.verlauf[i]
      z[#z + 1] = F.grau .. "    " .. (date and date("%d.%m.", v.zeit) or "") .. " " .. v.n .. "× " .. ns.RezeptName(v.rid) .. (v.lohn and (" für " .. ns.Geld(v.lohn)) or "") .. "|r"
    end
  end
  return table.concat(z, "\n")
end

-- Beim Einloggen an überfällige und heute fällige Aufträge erinnern
ns.AufEreignis("PLAYER_LOGIN", function()
  if ns.db.optionen.auftragHinweis == false then return end
  local ueber, heute = 0, 0
  local jetzt = Jetzt()
  for _, a in ipairs(ns.AuftraegeSortiert("frist")) do
    if a.frist then
      if a.frist < jetzt then ueber = ueber + 1
      elseif a.frist - jetzt < 86400 then heute = heute + 1 end
    end
  end
  if ueber + heute > 0 then
    local t = {}
    if ueber > 0 then t[#t + 1] = ueber .. " überfällig" end
    if heute > 0 then t[#t + 1] = heute .. " heute fällig" end
    ns.Print("Aufträge: " .. table.concat(t, ", ") .. ". /wb auftraege")
  end
end)
