-- Preise: Auktionshaus-Preise beobachten, Kosten und Gewinn je Rezept, Preisverlauf,
-- Preisalarme, Rezeptquellen und „Liste im Auktionshaus abfragen“
local _, ns = ...
local D = ns.daten
local F = ns.F

local GEBUEHR = 0.05 -- Auktionshausgebühr auf den Verkaufspreis

local function Jetzt() return time and time() or 0 end
local function Tag() return date and date("%Y-%m-%d") or "heute" end

function ns.PreiseDB()
  ns.db.preise = ns.db.preise or {}
  ns.db.alarme = ns.db.alarme or {}
  return ns.db.preise
end

-- ---------- Preise merken ----------

-- Günstigster Sofortkaufpreis pro Stück, je Tag; Verlauf über 30 Tage
function ns.PreisMerken(id, stueck)
  if not id or not stueck or stueck <= 0 then return end
  local p = ns.PreiseDB()
  local e = p[id] or { verlauf = {} }
  p[id] = e
  local tag = Tag()
  stueck = math.floor(stueck + 0.5)
  if e.tag == tag and e.ah then e.ah = math.min(e.ah, stueck) else e.ah = stueck end
  e.tag, e.zeit = tag, Jetzt()
  local v = e.verlauf
  if v[#v] and v[#v][1] == tag then v[#v][2] = e.ah else v[#v + 1] = { tag, e.ah } end
  while #v > 30 do table.remove(v, 1) end
  -- Preisalarm
  local grenze = ns.db.alarme[id]
  if grenze and e.ah <= grenze and e.alarmTag ~= tag then
    e.alarmTag = tag
    local text = "Preisalarm: " .. ns.ItemName(id) .. " für " .. ns.Geld(e.ah) .. " im Auktionshaus (Grenze " .. ns.Geld(grenze) .. ")"
    ns.Print(F.gruen .. text .. "|r")
    if ns.Bildschirm then ns.Bildschirm(text) end
    ns.Sprechen("Preisalarm: " .. ns.ItemName(id))
    if PlaySound and ns.db.optionen.alarmTon ~= false then pcall(PlaySound, SOUNDKIT and SOUNDKIT.AUCTION_WINDOW_OPEN or 5274) end
  end
  return e.ah
end

-- Liest die angezeigten Auktionen (jede Suche, jede Seite)
function ns.AuktionenLesen()
  if not GetNumAuctionItems then return 0 end
  local n = ns.Frei(GetNumAuctionItems("list")) or 0
  local min = {}
  for i = 1, n do
    local name, _, anzahl, _, _, _, _, _, _, sofort = GetAuctionItemInfo("list", i)
    name, anzahl, sofort = ns.Frei(name), ns.Frei(anzahl), ns.Frei(sofort)
    local id = ns.ItemIdAusLink(GetAuctionItemLink and GetAuctionItemLink("list", i))
    if id and sofort and sofort > 0 and anzahl and anzahl > 0 then
      if ns.usedIn[id] or ns.madeBy[id] then
        local st = sofort / anzahl
        if not min[id] or st < min[id] then min[id] = st end
      end
      local rid = name and ns.RezeptAusGegenstand(name)
      if rid then ns.QuelleMerken(rid, "ah", { preis = sofort }) end
    end
  end
  local k = 0
  for id, st in pairs(min) do
    ns.PreisMerken(id, st)
    k = k + 1
  end
  if k > 0 then ns.Aktualisieren() end
  return k
end
ns.AufEreignis("AUCTION_ITEM_LIST_UPDATE", function() ns.AuktionenLesen() end)

-- Preis pro Stück: Händler, wenn günstiger, sonst Auktionshaus
function ns.Preis(id)
  local h = ns.HaendlerInfo and ns.HaendlerInfo(id)
  local a = ns.PreiseDB()[id]
  local hp, ap = h and h.preis, a and a.ah
  if hp and (not ap or hp <= ap) then return hp, "Händler" end
  if ap then return ap, "Auktionshaus", a.zeit end
  return nil
end

-- Auktionshauspreis des Ergebnisses (für den Verkauf)
function ns.VerkaufsPreis(id)
  local a = ns.PreiseDB()[id]
  return a and a.ah
end

-- ---------- Kosten und Gewinn ----------

-- Materialkosten einer Herstellung. Fehlt ein Preis, wird ein herstellbares Material
-- über sein eigenes Rezept gerechnet. Liefert kosten, Anzahl Zutaten ohne Preis.
function ns.RezeptKosten(rid, tiefe)
  local r = D.rezepte[rid]
  if not r then return 0, 0 end
  tiefe = tiefe or 0
  local kosten, ohne = 0, 0
  local z = r[4]
  for i = 1, #z, 2 do
    local id, n = z[i], z[i + 1]
    local preis = ns.Preis(id)
    if not preis and ns.madeBy[id] and tiefe < 3 then
      local sub = ns.RezeptFuer(id)
      local k, o = ns.RezeptKosten(sub, tiefe + 1)
      if o == 0 then preis = k / ns.Menge(D.rezepte[sub]) end
    end
    if preis then kosten = kosten + preis * n else ohne = ohne + 1 end
  end
  return math.floor(kosten + 0.5), ohne
end

-- Gewinn nach Auktionshausgebühr: gewinn, erlös, kosten, Zutaten ohne Preis
function ns.RezeptGewinn(rid)
  local r = D.rezepte[rid]
  if not r or not r[2] then return nil end
  local vp = ns.VerkaufsPreis(r[2])
  if not vp then return nil end
  local erloes = math.floor(vp * ns.Menge(r) * (1 - GEBUEHR) + 0.5)
  local kosten, ohne = ns.RezeptKosten(rid)
  return erloes - kosten, erloes, kosten, ohne
end

-- Selbst herstellen oder kaufen? Liefert Text oder nil
function ns.SelbstOderKaufen(id)
  local rid = ns.madeBy[id] and ns.RezeptFuer(id)
  local kauf = ns.Preis(id)
  if not rid or not kauf then return nil end
  local k, ohne = ns.RezeptKosten(rid)
  if ohne > 0 then return nil end
  local selbst = k / ns.Menge(D.rezepte[rid])
  if selbst < kauf then
    return "Selbst herstellen spart " .. ns.Geld(math.floor(kauf - selbst + 0.5)) .. " pro Stück", true
  end
  return "Kaufen ist " .. ns.Geld(math.floor(selbst - kauf + 0.5)) .. " pro Stück günstiger", false
end

-- Preistrend gegenüber dem ältesten Wert der letzten 7 Tage (in Prozent)
function ns.Trend(id)
  local e = ns.PreiseDB()[id]
  local v = e and e.verlauf
  if not v or #v < 2 then return nil end
  local alt = v[math.max(1, #v - 7)][2]
  if not alt or alt == 0 then return nil end
  return math.floor((v[#v][2] - alt) / alt * 100 + 0.5)
end

function ns.Durchschnitt(id)
  local e = ns.PreiseDB()[id]
  local v = e and e.verlauf
  if not v or #v == 0 then return nil end
  local s = 0
  for _, x in ipairs(v) do s = s + x[2] end
  return math.floor(s / #v + 0.5)
end

function ns.TrendText(id)
  local t = ns.Trend(id)
  if not t then return "" end
  if t > 0 then return F.rot .. "+" .. t .. " %|r" end
  if t < 0 then return F.gruen .. t .. " %|r" end
  return F.grau .. "±0 %|r"
end

-- ---------- Preisalarme ----------

-- „1g 20s 5k“ → Kupfer
function ns.GeldLesen(text)
  text = tostring(text or ""):lower()
  local summe, gefunden = 0, false
  for zahl, einheit in text:gmatch("(%d+)%s*([gskc])") do
    zahl = tonumber(zahl)
    summe = summe + (einheit == "g" and zahl * 10000 or einheit == "s" and zahl * 100 or zahl)
    gefunden = true
  end
  return gefunden and summe or nil
end

function ns.AlarmSetzen(text)
  local name, geld = tostring(text or ""):match("^(.-)%s+([%d%sgskcGSKC]+)$")
  local id = name and ns.GegenstandSuchen(name)
  local kupfer = ns.GeldLesen(geld)
  if not id then
    local einzeln = ns.GegenstandSuchen(text)
    if einzeln and ns.PreiseDB() and ns.db.alarme[einzeln] then
      ns.db.alarme[einzeln] = nil
      ns.Print("Preisalarm für " .. ns.ItemName(einzeln) .. " entfernt.")
      return true
    end
    ns.Print("So geht's: /wb alarm Leinenstoff 20s  (ohne Preis: Alarm entfernen)")
    return false
  end
  if not kupfer then
    ns.Print("Preis bitte mit Einheit angeben, z. B. 1g 20s oder 50s.")
    return false
  end
  ns.PreiseDB()
  ns.db.alarme[id] = kupfer
  ns.Print("Preisalarm: " .. ns.ItemName(id) .. " ab " .. ns.Geld(kupfer) .. " oder günstiger.")
  return true
end

-- ---------- Rezeptquellen (beobachtet) ----------

function ns.QuelleMerken(rid, art, info)
  if not rid then return end
  ns.db.quellen = ns.db.quellen or {}
  local q = ns.db.quellen[rid] or {}
  ns.db.quellen[rid] = q
  info = info or {}
  info.zone = info.zone or (GetZoneText and ns.Frei(GetZoneText())) or nil
  info.zeit = Jetzt()
  q[art] = info
end

function ns.Quellen(rid)
  local q = ns.db.quellen and ns.db.quellen[rid]
  if not q then return {} end
  local t = {}
  if q.haendler then t[#t + 1] = "Händler " .. (q.haendler.wer or "?") .. (q.haendler.zone and (", " .. q.haendler.zone) or "") .. (q.haendler.preis and (" – " .. ns.Geld(q.haendler.preis)) or "") end
  if q.beute then t[#t + 1] = "Beute" .. (q.beute.zone and (" in " .. q.beute.zone) or "") end
  if q.ah then t[#t + 1] = "Auktionshaus" .. (q.ah.preis and (" ab " .. ns.Geld(q.ah.preis)) or "") end
  return t
end

ns.AufEreignis("MERCHANT_SHOW", function()
  local wer = UnitName and ns.Frei(UnitName("npc"))
  for i = 1, ns.HaendlerAnzahl() do
    local name, preis = ns.HaendlerArtikel(i)
    local rid = ns.RezeptAusGegenstand(name)
    if rid then ns.QuelleMerken(rid, "haendler", { wer = wer, preis = preis }) end
  end
end)

-- ---------- Auktionshaus: Liste der Reihe nach abfragen ----------

local abfrage = 0
function ns.ListeAbfragen()
  local fehlt = ns.Fehlend()
  local ids = {}
  for id in pairs(fehlt) do ids[#ids + 1] = id end
  if #ids == 0 then
    ns.Print("Auf deiner Liste fehlt nichts.")
    return nil
  end
  table.sort(ids, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  abfrage = abfrage % #ids + 1
  local id = ids[abfrage]
  if ns.AHSuchen(id) then
    ns.Print("(" .. abfrage .. " von " .. #ids .. ") Nächster Klick sucht das nächste Material.")
  end
  return id
end

ns.AufEreignis("AUCTION_HOUSE_SHOW", function()
  abfrage = 0
  local frame = AuctionFrame
  if not frame or frame.werkbankKnopf then return end
  local b = ns.Stil.Knopf(frame, "Liste abfragen", 110)
  b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -60, -14)
  b:SetFrameLevel(frame:GetFrameLevel() + 5)
  b:SetScript("OnClick", ns.ListeAbfragen)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Werkbank", 1, 1, 1)
    GameTooltip:AddLine("Jeder Klick sucht das nächste fehlende Material deiner Liste. Die Preise merkt sich die Werkbank für Kosten, Gewinn und Preisalarme.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.werkbankKnopf = b
end)

-- ---------- Text für die Seite „Preise und Vorrat“ ----------

function ns.PreiseText()
  local z = {}
  local p = ns.PreiseDB()
  local bedarf = ns.Rechnen()
  local ids = {}
  for id in pairs(bedarf) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  z[#z + 1] = F.gold .. "Materialien deiner Liste|r"
  if #ids == 0 then z[#z + 1] = F.grau .. "  Die Liste ist leer.|r" end
  local summe = 0
  for _, id in ipairs(ids) do
    local preis, quelle = ns.Preis(id)
    local fehlt = math.max(0, bedarf[id] - ns.Vorrat(id))
    local t = "  " .. ns.ItemName(id) .. ": "
    if preis then
      t = t .. ns.Geld(math.floor(preis + 0.5)) .. " (" .. quelle .. ") " .. ns.TrendText(id)
      summe = summe + preis * fehlt
    else
      t = t .. F.grau .. "noch kein Preis|r"
    end
    if fehlt > 0 then t = t .. F.grau .. "  · fehlt " .. fehlt .. "|r" end
    z[#z + 1] = t
  end
  if summe > 0 then z[#z + 1] = "  " .. F.gold .. "Einkauf für das Fehlende: ca. |r" .. ns.Geld(math.floor(summe + 0.5)) end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Preisalarme|r"
  local alarme = {}
  for id, g in pairs(ns.db.alarme) do
    local e = p[id]
    alarme[#alarme + 1] = "  " .. ns.ItemName(id) .. " ab " .. ns.Geld(g) .. (e and e.ah and (", zuletzt " .. ns.Geld(e.ah)) or "")
  end
  table.sort(alarme)
  if #alarme == 0 then z[#z + 1] = F.grau .. "  Keine. Unten eintragen oder /wb alarm Leinenstoff 20s|r" end
  for _, a in ipairs(alarme) do z[#z + 1] = a end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Mindestbestände|r"
  local mind = {}
  for id, n in pairs(ns.db.mindest or {}) do
    local hat = ns.Vorrat(id)
    mind[#mind + 1] = "  " .. ns.ItemName(id) .. ": " .. (hat < n and F.rot or F.gruen) .. hat .. " von " .. n .. "|r" .. (hat < n and " – zu wenig" or "")
  end
  table.sort(mind)
  if #mind == 0 then z[#z + 1] = F.grau .. "  Keine. Unten eintragen oder /wb mindest Leinenstoff 40|r" end
  for _, m in ipairs(mind) do z[#z + 1] = m end
  local n = 0
  for _ in pairs(p) do n = n + 1 end
  z[#z + 1] = ""
  z[#z + 1] = F.grau .. n .. " Preise gemerkt. Preise kommen aus dem Auktionshaus (jede Suche, auch „Liste abfragen“) und vom Händler.|r"
  return table.concat(z, "\n")
end
