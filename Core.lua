-- Werkbank: Rezeptbuch, Einkaufsliste und Berufs-Tooltips für WoW Forever
local ADDON, ns = ...
local D = ns.daten

ns.name = "Werkbank"
ns.web = "https://foreverui.de/berufe/"
ns.farbe = "|cffe0b45a"

-- ---------- Nachschlagetabellen ----------

ns.beruf = {}       -- Beruf-ID -> Beruf
ns.berufName = {}   -- deutscher Name -> Beruf
ns.berufOf = {}     -- Rezept-ID -> Beruf
ns.katOf = {}       -- Rezept-ID -> Kategoriename
ns.madeBy = {}      -- Gegenstand -> { Rezept-IDs, die ihn herstellen }
ns.usedIn = {}      -- Gegenstand -> { Rezept-IDs, in denen er Zutat ist }
ns.rezeptName = {}  -- Beruf-ID -> { Rezeptname -> Rezept-ID }

for _, b in ipairs(D.berufe) do
  ns.beruf[b.id] = b
  ns.berufName[b.name] = b
  ns.rezeptName[b.id] = {}
  local n = 0
  for _, k in ipairs(b.kat) do
    for _, rid in ipairs(k[2]) do
      ns.berufOf[rid] = b
      ns.katOf[rid] = k[1]
      n = n + 1
    end
  end
  b.anzahl = n
end

local function push(t, key, v)
  local list = t[key]
  if not list then
    list = {}
    t[key] = list
  end
  for i = 1, #list do
    if list[i] == v then return end
  end
  list[#list + 1] = v
end

for rid, r in pairs(D.rezepte) do
  if r[2] then push(ns.madeBy, r[2], rid) end
  local z = r[4]
  for i = 1, #z, 2 do push(ns.usedIn, z[i], rid) end
  ns.rezeptName[r[5]][r[1]] = rid
end
for _, list in pairs(ns.madeBy) do table.sort(list) end
for _, list in pairs(ns.usedIn) do table.sort(list) end

-- ---------- Hilfsfunktionen ----------

function ns.Rezept(rid) return D.rezepte[rid] end
function ns.Item(id) return D.items[id] end

-- Durchschnittliche Menge pro Herstellung (manche Rezepte ergeben 1–4 Stück)
function ns.Menge(r)
  local m = r[3]
  if type(m) == "table" then return (m[1] + m[2]) / 2 end
  return m
end

function ns.ItemName(id)
  local it = D.items[id]
  if it then return it[1] end
  return (GetItemInfo and GetItemInfo(id)) or ("Gegenstand " .. id)
end

function ns.ItemIcon(id)
  local it = D.items[id]
  if it and it[3] then return it[3] end
  return (GetItemIcon and GetItemIcon(id)) or 134400
end

function ns.RezeptName(rid)
  local r = D.rezepte[rid]
  if not r then return "?" end
  if r[2] then return ns.ItemName(r[2]) end
  return r[1]
end

function ns.RezeptIcon(rid)
  local r = D.rezepte[rid]
  if not r then return 134400 end
  if r[2] then return ns.ItemIcon(r[2]) end
  return r[6] or (ns.berufOf[rid] and ns.berufOf[rid].icon) or 134400
end

local QFARBE = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
function ns.QualitaetFarbe(id)
  local it = D.items[id]
  local q = it and it[2] or 1
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex then
    return ITEM_QUALITY_COLORS[q].hex
  end
  return "|c" .. (QFARBE[q] or QFARBE[1])
end

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(ns.farbe .. "Werkbank:|r " .. msg)
end

local function ItemIdAusLink(link)
  if not link then return nil end
  local id = link:match("item:(%d+)")
  return id and tonumber(id)
end
ns.ItemIdAusLink = ItemIdAusLink

-- ---------- Gespeicherte Daten ----------

local defaults = {
  tooltip = true, tooltipKenner = true,
  -- Barrierefreiheit
  vorlesen = false, kontrast = false, farbenblind = false, tastatur = false, groesse = 1,
  -- 1.2
  gemeinsam = false,        -- eine Einkaufsliste für alle Charaktere
  abhaken = true,           -- nach dem Herstellen automatisch abhaken
  lootMeldung = true,       -- Fortschritt beim Looten im Chat
  fertigMeldung = true,     -- Meldung und Ton, wenn alles da ist
  minimap = true,           -- Knopf an der Minikarte
  minimapWinkel = 200,
}

function ns.CharKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

function ns.InitDB()
  WerkbankDB = WerkbankDB or {}
  local db = WerkbankDB
  db.chars = db.chars or {}
  db.optionen = db.optionen or {}
  for k, v in pairs(defaults) do
    if db.optionen[k] == nil then db.optionen[k] = v end
  end
  local key = ns.CharKey()
  local c = db.chars[key] or {}
  db.chars[key] = c
  c.name = UnitName("player")
  c.realm = GetRealmName()
  c.klasse = select(2, UnitClass("player"))
  c.berufe = c.berufe or {}   -- Beruf-ID -> { stufe, max }
  c.bekannt = c.bekannt or {} -- Rezept-ID -> true
  c.fraktion = UnitFactionGroup and UnitFactionGroup("player") or c.fraktion
  c.schwierigkeit = c.schwierigkeit or {} -- Rezept-ID -> optimal/medium/easy/trivial
  c.taschen = c.taschen or {}             -- Gegenstand -> Anzahl in den Taschen (nur Berufsgegenstände)
  c.bank = c.bank or {}                   -- Gegenstand -> Anzahl in der Bank (Stand beim letzten Besuch)
  -- Einkaufslisten: mehrere benannte Listen, pro Charakter oder gemeinsam
  c.listen = c.listen or { { name = "Standard", liste = c.liste or {}, selbst = c.selbst or {} } }
  c.liste, c.selbst = nil, nil
  c.aktiv = c.aktiv or 1
  db.gemeinsam = db.gemeinsam or { listen = { { name = "Gemeinsam", liste = {}, selbst = {} } }, aktiv = 1 }
  db.favoriten = db.favoriten or {}       -- Rezept-ID -> true (für alle Charaktere)
  ns.db, ns.char = db, c
  ns.ListeWaehlen()
  if ns.FarbenAnwenden then ns.FarbenAnwenden() end
end

-- ---------- Mehrere Einkaufslisten ----------

-- Wo liegen die Listen gerade? Pro Charakter oder gemeinsam für alle
function ns.ListenOrt()
  if ns.db.optionen.gemeinsam then return ns.db.gemeinsam end
  return ns.char
end

-- Setzt ns.L auf die aktive Liste
function ns.ListeWaehlen(index)
  local ort = ns.ListenOrt()
  if index then ort.aktiv = index end
  if not ort.listen[ort.aktiv] then ort.aktiv = 1 end
  ns.L = ort.listen[ort.aktiv]
  if ns.Aktualisieren and ns.char then ns.Aktualisieren() end
  return ns.L
end

function ns.ListeNeu(name)
  local ort = ns.ListenOrt()
  name = (name and name ~= "") and name or ("Liste " .. (#ort.listen + 1))
  ort.listen[#ort.listen + 1] = { name = name, liste = {}, selbst = {} }
  return ns.ListeWaehlen(#ort.listen)
end

function ns.ListeLoeschen()
  local ort = ns.ListenOrt()
  if #ort.listen <= 1 then
    wipe(ns.L.liste)
    wipe(ns.L.selbst)
  else
    table.remove(ort.listen, ort.aktiv)
    ort.aktiv = math.max(1, ort.aktiv - 1)
  end
  return ns.ListeWaehlen()
end

function ns.ListeUmbenennen(name)
  if name and name ~= "" then ns.L.name = name end
  ns.Aktualisieren()
end

function ns.ListeBlaettern(schritt)
  local ort = ns.ListenOrt()
  local i = (ort.aktiv - 1 + (schritt or 1)) % #ort.listen + 1
  return ns.ListeWaehlen(i)
end

-- ---------- Favoriten ----------

function ns.FavoritUmschalten(rid)
  if not ns.Rezept(rid) then return end
  ns.db.favoriten[rid] = not ns.db.favoriten[rid] or nil
  ns.Aktualisieren()
  return ns.db.favoriten[rid]
end

-- ---------- Einkaufsliste ----------

local MAX_ANZAHL = 999

function ns.ListeSetzen(rid, n)
  if not D.rezepte[rid] then return end
  n = math.floor(tonumber(n) or 0)
  if n <= 0 then
    ns.L.liste[rid] = nil
  else
    ns.L.liste[rid] = math.min(n, MAX_ANZAHL)
  end
  ns.Aktualisieren()
end

function ns.ListeAdd(rid, n)
  ns.ListeSetzen(rid, (ns.L.liste[rid] or 0) + (n or 1))
end

function ns.ListeLeeren()
  wipe(ns.L.liste)
  wipe(ns.L.selbst)
  ns.Aktualisieren()
end

function ns.SelbstUmschalten(id)
  if not ns.madeBy[id] then return end
  ns.L.selbst[id] = not ns.L.selbst[id] or nil
  ns.Aktualisieren()
end

-- Welches Rezept stellt einen Gegenstand her? Bevorzugt eins, das der Charakter kennt.
function ns.RezeptFuer(id)
  local list = ns.madeBy[id]
  if not list then return nil end
  for _, rid in ipairs(list) do
    if ns.char and ns.char.bekannt[rid] then return rid end
  end
  return list[1]
end

-- Rechnet die Liste aus: Materialien (Gegenstand -> Anzahl) und Zwischenschritte (Rezept -> wie oft)
function ns.Rechnen(liste, selbst)
  liste = liste or ns.L.liste
  selbst = selbst or ns.L.selbst
  local bedarf, schritte = {}, {}
  local function add(id, n, tiefe)
    local rid = selbst[id] and ns.RezeptFuer(id)
    if rid and tiefe < 8 then
      local r = D.rezepte[rid]
      local mal = math.ceil(n / ns.Menge(r))
      schritte[rid] = (schritte[rid] or 0) + mal
      local z = r[4]
      for i = 1, #z, 2 do add(z[i], z[i + 1] * mal, tiefe + 1) end
    else
      bedarf[id] = (bedarf[id] or 0) + n
    end
  end
  for rid, n in pairs(liste) do
    local r = D.rezepte[rid]
    if r then
      local z = r[4]
      for i = 1, #z, 2 do add(z[i], z[i + 1] * n, 0) end
    end
  end
  return bedarf, schritte
end

-- Wie viele hat der Charakter (Taschen und Bank)?
function ns.Vorrat(id)
  if not GetItemCount then return 0 end
  return GetItemCount(id, true) or 0
end

-- Wie oft lässt sich ein Rezept mit dem eigenen Vorrat herstellen?
function ns.Moeglich(rid)
  local r = D.rezepte[rid]
  if not r or #r[4] == 0 then return 0 end
  local mal
  local z = r[4]
  for i = 1, #z, 2 do
    local m = math.floor(ns.Vorrat(z[i]) / z[i + 1])
    if not mal or m < mal then mal = m end
  end
  return mal or 0
end

-- Schwierigkeit als Wort und Farbe (wie im Berufsfenster: orange, gelb, grün, grau)
ns.SCHWIERIGKEIT = {
  optimal = { "orange", "|cffff8040" },
  medium = { "gelb", "|cffffff00" },
  easy = { "grün", "|cff40c040" },
  trivial = { "grau", "|cff808080" },
}

-- ---------- Austausch mit dem Berufe-Rechner auf foreverui.de ----------
-- Format der Webseite: #r=REZEPT.ANZAHL,REZEPT.ANZAHL&h=GEGENSTAND,GEGENSTAND

function ns.Import(text)
  text = tostring(text or "")
  local r = text:match("r=([%d%.,]+)")
  if not r then return 0 end
  local n = 0
  for rid, anz in r:gmatch("(%d+)%.?(%d*)") do
    rid = tonumber(rid)
    if D.rezepte[rid] then
      local a = tonumber(anz) or 1
      ns.L.liste[rid] = math.min((ns.L.liste[rid] or 0) + math.max(a, 1), MAX_ANZAHL)
      n = n + 1
    end
  end
  local h = text:match("h=([%d,]+)")
  if h then
    for id in h:gmatch("%d+") do
      id = tonumber(id)
      if ns.madeBy[id] then ns.L.selbst[id] = true end
    end
  end
  ns.Aktualisieren()
  return n
end

-- Ein Link pro Beruf, weil der Rechner auf der Webseite je Beruf eine Seite hat
function ns.Export()
  local proBeruf, reihenfolge = {}, {}
  local rids = {}
  for rid in pairs(ns.L.liste) do rids[#rids + 1] = rid end
  table.sort(rids)
  for _, rid in ipairs(rids) do
    local b = ns.berufOf[rid]
    if b then
      if not proBeruf[b.id] then
        proBeruf[b.id] = {}
        reihenfolge[#reihenfolge + 1] = b
      end
      local t = proBeruf[b.id]
      t[#t + 1] = rid .. "." .. ns.L.liste[rid]
    end
  end
  local h = {}
  for id in pairs(ns.L.selbst) do h[#h + 1] = id end
  table.sort(h)
  local links = {}
  for _, b in ipairs(reihenfolge) do
    local url = ns.web .. b.slug .. "/#r=" .. table.concat(proBeruf[b.id], ",")
    if #h > 0 then url = url .. "&h=" .. table.concat(h, ",") end
    links[#links + 1] = { beruf = b, url = url }
  end
  return links
end

-- ---------- Berufe und bekannte Rezepte erfassen ----------

-- Berufe aus dem Fertigkeitenfenster lesen; vergessene Berufe räumen wir auf
function ns.FertigkeitenLesen()
  if not GetNumSkillLines then return end
  local gefunden, zugeklappt = {}, false
  for i = 1, GetNumSkillLines() do
    local name, isHeader, isExpanded, rank, _, _, max = GetSkillLineInfo(i)
    if isHeader and not isExpanded then zugeklappt = true end
    local b = name and not isHeader and ns.berufName[name]
    if b then
      gefunden[b.id] = true
      ns.char.berufe[b.id] = { stufe = rank, max = max }
    end
  end
  -- Nur aufräumen, wenn alles aufgeklappt ist, sonst fehlen Berufe bloß in der Anzeige
  if GetNumSkillLines() > 0 and not zugeklappt then
    for id in pairs(ns.char.berufe) do
      if not gefunden[id] then
        ns.char.berufe[id] = nil
        for rid in pairs(ns.char.bekannt) do
          if ns.berufOf[rid] and ns.berufOf[rid].id == id then ns.char.bekannt[rid] = nil end
        end
      end
    end
  end
end

local function Merken(b, name, itemId, typ)
  local rid
  if itemId and ns.madeBy[itemId] then
    for _, x in ipairs(ns.madeBy[itemId]) do
      if ns.berufOf[x] == b then
        rid = x
        break
      end
    end
  end
  rid = rid or ns.rezeptName[b.id][name]
  if rid then
    ns.char.bekannt[rid] = true
    if typ and typ ~= "" and typ ~= "none" then ns.char.schwierigkeit[rid] = typ end
    return true
  end
  return false
end

-- Berufsfenster (alle Berufe außer Verzauberkunst in der klassischen Oberfläche)
function ns.BerufsfensterLesen()
  if not GetTradeSkillLine then return end
  local name, rank, max = GetTradeSkillLine()
  local b = name and ns.berufName[name]
  if not b then return end
  ns.char.berufe[b.id] = { stufe = rank, max = max }
  ns.offenerBeruf = b
  local n = 0
  for i = 1, GetNumTradeSkills() do
    local rname, typ = GetTradeSkillInfo(i)
    if rname and typ ~= "header" and typ ~= "subheader" then
      if Merken(b, rname, ItemIdAusLink(GetTradeSkillItemLink(i)), typ) then n = n + 1 end
    end
  end
  ns.Aktualisieren()
  return n
end

-- Handwerksfenster (Verzauberkunst in der klassischen Oberfläche)
function ns.HandwerksfensterLesen()
  if not GetCraftDisplaySkillLine then return end
  local name, rank, max = GetCraftDisplaySkillLine()
  local b = name and ns.berufName[name]
  if not b then return end
  ns.char.berufe[b.id] = { stufe = rank, max = max }
  ns.offenerBeruf = b
  for i = 1, GetNumCrafts() do
    local rname, _, typ = GetCraftInfo(i)
    if rname and typ ~= "header" then
      Merken(b, rname, GetCraftItemLink and ItemIdAusLink(GetCraftItemLink(i)), typ)
    end
  end
  ns.Aktualisieren()
end

-- Rezept-ID des im Berufsfenster gewählten Eintrags
function ns.GewaehltesRezept()
  local b = ns.offenerBeruf
  if not b then return nil end
  if TradeSkillFrame and TradeSkillFrame:IsShown() and GetTradeSkillSelectionIndex then
    local i = GetTradeSkillSelectionIndex()
    local rname, typ = GetTradeSkillInfo(i)
    if rname and typ ~= "header" and typ ~= "subheader" then
      local id = ItemIdAusLink(GetTradeSkillItemLink(i))
      if id and ns.madeBy[id] then
        for _, x in ipairs(ns.madeBy[id]) do
          if ns.berufOf[x] == b then return x end
        end
      end
      return ns.rezeptName[b.id][rname]
    end
  end
  if CraftFrame and CraftFrame:IsShown() and GetCraftSelectionIndex then
    local rname = GetCraftInfo(GetCraftSelectionIndex())
    return rname and ns.rezeptName[b.id][rname]
  end
end

-- Welche eigenen Charaktere kennen ein Rezept?
function ns.Kenner(rid)
  local t = {}
  for _, c in pairs(ns.db.chars) do
    if c.bekannt and c.bekannt[rid] then t[#t + 1] = c.name or "?" end
  end
  table.sort(t)
  return t
end

-- ---------- Ereignisse ----------

local listener = {}
function ns.BeiAenderung(fn) listener[#listener + 1] = fn end
function ns.Aktualisieren()
  for _, fn in ipairs(listener) do fn() end
end

local f = CreateFrame("Frame")
ns.eventFrame = f
-- pcall, weil nicht jede Spielversion jedes Ereignis kennt
for _, ev in ipairs({
  "ADDON_LOADED", "PLAYER_LOGIN", "SKILL_LINES_CHANGED",
  "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_CLOSE",
  "CRAFT_SHOW", "CRAFT_UPDATE", "CRAFT_CLOSE",
  "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED",
}) do
  pcall(f.RegisterEvent, f, ev)
end

-- Weitere Module hängen sich hier an Ereignisse
local handler = {}
function ns.AufEreignis(ev, fn)
  if not handler[ev] then
    handler[ev] = {}
    pcall(f.RegisterEvent, f, ev)
  end
  table.insert(handler[ev], fn)
end

f:SetScript("OnEvent", function(_, event, arg1, ...)
  if handler[event] and (ns.char or event == "ADDON_LOADED") then
    for _, fn in ipairs(handler[event]) do fn(arg1, ...) end
  end
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then ns.InitDB() end
    if ns.BlizzardFensterGeladen then ns.BlizzardFensterGeladen(arg1) end
  elseif event == "PLAYER_LOGIN" then
    ns.FertigkeitenLesen()
    if ns.Start then ns.Start() end
  elseif event == "SKILL_LINES_CHANGED" then
    if ns.char then ns.FertigkeitenLesen() end
  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
    ns.BerufsfensterLesen()
    if ns.BlizzardFensterGeladen then ns.BlizzardFensterGeladen("Blizzard_TradeSkillUI") end
  elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
    ns.HandwerksfensterLesen()
    if ns.BlizzardFensterGeladen then ns.BlizzardFensterGeladen("Blizzard_CraftUI") end
  elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
    ns.offenerBeruf = nil
  elseif ns.char and (event == "BAG_UPDATE_DELAYED" or event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED") then
    ns.Aktualisieren()
  end
end)
