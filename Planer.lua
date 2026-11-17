-- Planen: Rückgängig, Listen kopieren und zusammenführen, Sicherung, Text-Export,
-- Händlerpreise und Fundorte, Kosten, Chat-Links, „Wer kann's?“, „Wofür?“, Zufallsrezept
local _, ns = ...
local D = ns.daten
local F = ns.F

local function Kopie(t)
  local n = {}
  for k, v in pairs(t or {}) do n[k] = v end
  return n
end

-- ---------- Rückgängig ----------

local stapel = {}
local still = false

local function Schnappschuss()
  if still or not ns.L then return end
  stapel[#stapel + 1] = { L = ns.L, liste = Kopie(ns.L.liste), selbst = Kopie(ns.L.selbst), name = ns.L.name }
  if #stapel > 30 then table.remove(stapel, 1) end
end
ns.Schnappschuss = Schnappschuss

-- Alle Funktionen, die die Liste ändern, merken sich vorher den Stand
for _, name in ipairs({ "ListeSetzen", "ListeLeeren", "SelbstUmschalten", "Import", "ListeUmbenennen" }) do
  local alt = ns[name]
  ns[name] = function(...)
    Schnappschuss()
    still = true
    local ok, a, b = pcall(alt, ...)
    still = false
    if not ok then error(a, 0) end
    return a, b
  end
end

function ns.KannRueckgaengig() return #stapel > 0 end

function ns.Rueckgaengig()
  local s = table.remove(stapel)
  if not s then
    ns.Print("Es gibt nichts rückgängig zu machen.")
    return false
  end
  wipe(s.L.liste)
  wipe(s.L.selbst)
  for k, v in pairs(s.liste) do s.L.liste[k] = v end
  for k, v in pairs(s.selbst) do s.L.selbst[k] = v end
  s.L.name = s.name
  -- zur betroffenen Liste wechseln, falls sie noch existiert
  local ort = ns.ListenOrt()
  for i, l in ipairs(ort.listen) do
    if l == s.L then ort.aktiv = i end
  end
  ns.ListeWaehlen()
  ns.Print("Rückgängig gemacht.")
  ns.Sprechen("Rückgängig gemacht.")
  return true
end

-- ---------- Listen kopieren, zusammenführen, von Twinks übernehmen ----------

function ns.ListeKopieren()
  local ort = ns.ListenOrt()
  local quelle = ns.L
  ort.listen[#ort.listen + 1] = { name = (quelle.name or "Liste") .. " (Kopie)", liste = Kopie(quelle.liste), selbst = Kopie(quelle.selbst) }
  return ns.ListeWaehlen(#ort.listen)
end

local function Dazu(ziel, quelle)
  for rid, n in pairs(quelle.liste or {}) do ziel.liste[rid] = math.min((ziel.liste[rid] or 0) + n, 999) end
  for id, v in pairs(quelle.selbst or {}) do if ziel.selbst[id] == nil then ziel.selbst[id] = v end end
end

function ns.ListenZusammenfuehren()
  local ort = ns.ListenOrt()
  if #ort.listen < 2 then
    ns.Print("Es gibt nur eine Liste.")
    return 0
  end
  Schnappschuss()
  local ziel = ns.L
  local n = 0
  for i = #ort.listen, 1, -1 do
    local l = ort.listen[i]
    if l ~= ziel then
      Dazu(ziel, l)
      table.remove(ort.listen, i)
      n = n + 1
    end
  end
  ort.aktiv = 1
  ns.ListeWaehlen()
  ns.Print(n .. (n == 1 and " Liste" or " Listen") .. " in „" .. (ziel.name or "") .. "“ zusammengeführt.")
  return n
end

-- Aktive Liste eines anderen Charakters
function ns.TwinkListe(c)
  if not c or not c.listen then return nil end
  return c.listen[c.aktiv or 1]
end

function ns.TwinkListeUebernehmen(name)
  name = (name or ""):lower()
  for _, c in pairs(ns.db.chars) do
    if c ~= ns.char and (c.name or ""):lower() == name then
      local l = ns.TwinkListe(c)
      if not l or not next(l.liste) then
        ns.Print((c.name or "?") .. " hat keine Einträge auf der Liste.")
        return 0
      end
      Schnappschuss()
      Dazu(ns.L, l)
      ns.Aktualisieren()
      local n = 0
      for _ in pairs(l.liste) do n = n + 1 end
      ns.Print(n .. " Rezepte von " .. c.name .. " übernommen.")
      return n
    end
  end
  ns.Print("Diesen Charakter kenne ich nicht.")
  return 0
end

-- Andere Charaktere mit eigener, nicht leerer Liste
function ns.TwinksMitListe()
  local t = {}
  for _, c in ipairs(ns.Twinks()) do
    local l = ns.TwinkListe(c)
    if l and next(l.liste) then t[#t + 1] = c end
  end
  return t
end

-- ---------- Sicherung aller Listen ----------
-- Format: WB1|Name;r=REZEPT.ANZAHL,…&h=ID,…|Name;…

local function NameSicher(n) return ((n or "Liste"):gsub("[|;]", " ")) end

function ns.SicherungText()
  local teile = { "WB1" }
  for _, l in ipairs(ns.ListenOrt().listen) do
    local r, h = {}, {}
    for rid, n in pairs(l.liste) do r[#r + 1] = rid .. "." .. n end
    for id, v in pairs(l.selbst) do if v then h[#h + 1] = id end end
    table.sort(r)
    table.sort(h)
    teile[#teile + 1] = NameSicher(l.name) .. ";r=" .. table.concat(r, ",") .. (#h > 0 and ("&h=" .. table.concat(h, ",")) or "")
  end
  return table.concat(teile, "|")
end

function ns.SicherungLaden(text)
  text = tostring(text or "")
  if not text:match("^WB1|") then return 0 end
  local ort = ns.ListenOrt()
  local n = 0
  for teil in text:gmatch("|([^|]+)") do
    local name, daten = teil:match("^([^;]*);(.*)$")
    if name then
      local l = { name = name ~= "" and name or "Liste", liste = {}, selbst = {} }
      for rid, anz in (daten:match("r=([%d%.,]*)") or ""):gmatch("(%d+)%.(%d+)") do
        rid = tonumber(rid)
        if D.rezepte[rid] then l.liste[rid] = math.min(tonumber(anz), 999) end
      end
      for id in (daten:match("h=([%d,]*)") or ""):gmatch("%d+") do
        id = tonumber(id)
        if ns.madeBy[id] then l.selbst[id] = true end
      end
      ort.listen[#ort.listen + 1] = l
      n = n + 1
    end
  end
  if n > 0 then ns.ListeWaehlen(#ort.listen) end
  return n
end

-- ---------- Liste als Text (für Chat, Forum, Notizen) ----------

function ns.TextExport()
  local rids = {}
  for rid in pairs(ns.L.liste) do rids[#rids + 1] = rid end
  if #rids == 0 then return "Die Liste ist leer." end
  table.sort(rids, function(a, b) return ns.RezeptName(a) < ns.RezeptName(b) end)
  local her = {}
  for _, rid in ipairs(rids) do her[#her + 1] = ns.L.liste[rid] .. "× " .. ns.RezeptName(rid) end
  local bedarf = ns.Rechnen()
  local ids = {}
  for id in pairs(bedarf) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  local mat = {}
  for _, id in ipairs(ids) do
    local hat = ns.Vorrat(id)
    mat[#mat + 1] = bedarf[id] .. "× " .. ns.ItemName(id) .. (hat < bedarf[id] and (" (fehlt " .. (bedarf[id] - hat) .. ")") or " (da)")
  end
  return (ns.L.name or "Liste") .. ": " .. table.concat(her, ", ") .. " — Materialien: " .. table.concat(mat, ", ")
end

-- ---------- Händlerpreise und Fundorte ----------

-- Merkt sich beim Händler Preis pro Stück, Name und Ort aller Materialien aus Rezepten
function ns.HaendlerMerken()
  if not GetMerchantNumItems then return 0 end
  ns.db.haendler = ns.db.haendler or {}
  local haendler = UnitName and UnitName("npc") or nil
  local zone = GetZoneText and GetZoneText() or nil
  local n = 0
  for i = 1, ns.HaendlerAnzahl() do
    local id = ns.ItemIdAusLink(GetMerchantItemLink and GetMerchantItemLink(i))
    if id and ns.usedIn[id] then
      local _, preis, pro, verfuegbar = ns.HaendlerArtikel(i)
      if preis and preis > 0 and (verfuegbar or -1) < 0 then
        local stueck = preis / math.max(pro or 1, 1)
        local alt = ns.db.haendler[id]
        if not alt or stueck <= alt.preis or alt.wer == haendler then
          ns.db.haendler[id] = { preis = stueck, wer = haendler, zone = zone }
        end
        n = n + 1
      end
    end
  end
  return n
end
ns.AufEreignis("MERCHANT_SHOW", function() ns.HaendlerMerken() end)

function ns.HaendlerInfo(id)
  return ns.db.haendler and ns.db.haendler[id]
end

-- Was kosten die fehlenden Materialien, die ein Händler verkauft?
function ns.Kosten()
  local summe, bekannt, unbekannt = 0, 0, 0
  for id, n in pairs(ns.Fehlend()) do
    local h = ns.HaendlerInfo(id)
    if h then
      summe = summe + math.ceil(h.preis * n)
      bekannt = bekannt + 1
    else
      unbekannt = unbekannt + 1
    end
  end
  return summe, bekannt, unbekannt
end

-- ---------- Gegenstand anhand von Name oder Link finden ----------

function ns.GegenstandSuchen(text)
  text = tostring(text or "")
  local id = ns.ItemIdAusLink(text) or tonumber(text)
  if id then return id end
  text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%[", ""):gsub("%]", ""):lower()
  if text == "" then return nil end
  local teil
  for iid, it in pairs(D.items) do
    local name = it[1]:lower()
    if name == text then return iid end
    if not teil and name:find(text, 1, true) then teil = iid end
  end
  return teil
end

-- „Wer kann es herstellen, wer hat es?“
function ns.WerText(text)
  local id = ns.GegenstandSuchen(text)
  if not id then return "Diesen Gegenstand kenne ich nicht." end
  local teile = { ns.ItemName(id) .. ":" }
  if ns.madeBy[id] then
    local wer = ns.HerstellerVon(id)
    teile[#teile + 1] = #wer > 0 and ("herstellen kann es " .. table.concat(wer, ", ") .. ".") or "keiner deiner Charaktere kann es herstellen."
  else
    teile[#teile + 1] = "lässt sich nicht herstellen."
  end
  local hat = ns.Vorrat(id)
  local summe, wer = ns.TwinkVorrat(id)
  if hat + summe > 0 then
    local liste = {}
    if hat > 0 then liste[1] = (ns.char.name or "du") .. " " .. hat end
    for _, w in ipairs(wer) do liste[#liste + 1] = w end
    teile[#teile + 1] = "Vorrat: " .. table.concat(liste, ", ") .. "."
  end
  return table.concat(teile, " ")
end

-- „Wofür brauche ich das?“
function ns.WofuerText(text)
  local id = ns.GegenstandSuchen(text)
  if not id then return "Diesen Gegenstand kenne ich nicht." end
  local used = ns.usedIn[id]
  if not used then return ns.ItemName(id) .. " ist in keinem Rezept Zutat." end
  local namen = {}
  for i, rid in ipairs(used) do
    if i > 12 then
      namen[#namen + 1] = "und " .. (#used - 12) .. " weitere"
      break
    end
    namen[#namen + 1] = ns.RezeptName(rid) .. " (" .. (ns.berufOf[rid] and ns.berufOf[rid].name or "?") .. ")"
  end
  return ns.ItemName(id) .. " ist Zutat für " .. #used .. (#used == 1 and " Rezept: " or " Rezepte: ") .. table.concat(namen, ", ") .. "."
end

-- ---------- Alt-Klick auf einen Gegenstandslink im Chat ----------

function ns.ChatLinkKlick(link, text)
  if not (IsAltKeyDown and IsAltKeyDown()) or not link then return false end
  local id = tonumber(tostring(link):match("^item:(%d+)"))
  if not id then return false end
  local rid
  if ns.madeBy[id] then
    rid = ns.RezeptFuer(id)
  else
    local name = text and text:match("%[(.-)%]")
    rid = ns.RezeptAusGegenstand(name)
  end
  if not rid then return false end
  ns.ListeAdd(rid, 1)
  ns.Print("1× " .. ns.RezeptName(rid) .. " auf die Liste gesetzt.")
  return true
end

if hooksecurefunc then
  hooksecurefunc("SetItemRef", function(link, text) ns.ChatLinkKlick(link, text) end)
end

-- ---------- Überrasch mich ----------

function ns.Ueberrasch(berufId)
  local jetzt, gelernt, alle = {}, {}, {}
  for rid in pairs(D.rezepte) do
    if not berufId or (ns.berufOf[rid] and ns.berufOf[rid].id == berufId) then
      alle[#alle + 1] = rid
      if ns.char.bekannt[rid] then
        gelernt[#gelernt + 1] = rid
        if ns.Moeglich(rid) > 0 then jetzt[#jetzt + 1] = rid end
      end
    end
  end
  local topf = #jetzt > 0 and jetzt or (#gelernt > 0 and gelernt or alle)
  if #topf == 0 then return nil end
  table.sort(topf)
  return topf[math.random(#topf)], topf == jetzt
end
