-- Fortschritt und Hinweise: Tracker, Bildschirmmeldungen, Statistik, Stufenaufstieg,
-- Abklingzeiten, Gold, Post-Helfer, Hinweise bei Händler, Bank, Beute und Berufsfenster,
-- Flüsteranfragen, Fehlerprotokoll und Einrichtungsassistent
local _, ns = ...
local D = ns.daten
local F = ns.F
local S = ns.Stil

local function Jetzt() return time and time() or 0 end
local function Heute() return date and date("%Y-%m-%d") or "heute" end

-- ---------- Fehlerprotokoll ----------

local gemeldet = false
function ns.FehlerMerken(err, wo)
  if not ns.db then return end
  ns.db.fehler = ns.db.fehler or {}
  local f = ns.db.fehler
  f[#f + 1] = { zeit = date and date("%Y-%m-%d %H:%M") or "", wo = tostring(wo or ""), text = tostring(err or "?") }
  while #f > 30 do table.remove(f, 1) end
  if not gemeldet then
    gemeldet = true
    ns.Print(F.rot .. "Ein Fehler wurde protokolliert.|r Unter Hilfe › Fehler melden kannst du ihn kopieren (/wb fehler).")
  end
end

function ns.FehlerText()
  local f = ns.db.fehler or {}
  if #f == 0 then return "Keine Fehler protokolliert." end
  local zeilen = {}
  local v = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata or function() end)("Werkbank", "Version") or "?"
  zeilen[1] = "Werkbank " .. v .. ", Spiel " .. (GetBuildInfo and select(1, GetBuildInfo()) or "?")
  for i = #f, 1, -1 do zeilen[#zeilen + 1] = f[i].zeit .. " [" .. f[i].wo .. "] " .. f[i].text end
  return table.concat(zeilen, "\n")
end

-- ---------- Meldungen mitten auf dem Bildschirm ----------

function ns.Bildschirm(text)
  if not (ns.db and ns.db.optionen.bildschirm) or not UIErrorsFrame then return end
  local A = ns.Akzent
  local halten = ns.db.optionen.wenigerBewegung and 10 or 5
  pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, ns.Sauber(text), A[1], A[2], A[3], 1, halten)
end

-- ---------- Tracker: fehlende Materialien in einem kleinen Fenster ----------

local tracker
local MAX_ZEILEN = 12

local function TrackerBauen()
  local t = CreateFrame("Frame", "WerkbankTracker", UIParent)
  t:Hide()
  t:SetSize(240, 60)
  t:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
  t:SetFrameStrata("MEDIUM")
  t:SetClampedToScreen(true)
  t:EnableMouse(true)
  t:SetMovable(true)
  t:RegisterForDrag("LeftButton")
  t:SetScript("OnDragStart", t.StartMoving)
  t:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.optionen.trackerPos = { p, rp, x, y }
  end)
  t:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" then ns.TrackerUmschalten(false) else ns.Oeffnen() end
  end)
  t.hg = S.Flaeche(t, S.HG[1], S.HG[2], S.HG[3], 0.75)
  S.Rand(t, nil, 0.45)
  t.titel = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t.titel:SetPoint("TOPLEFT", 10, -8)
  t.titel:SetPoint("RIGHT", -10, 0)
  t.titel:SetJustifyH("LEFT")
  S.AkzentText(t.titel)
  t.balken = t:CreateTexture(nil, "ARTWORK")
  t.balken:SetPoint("TOPLEFT", 10, -24)
  t.balken:SetHeight(2)
  S.AkzentFlaeche(t.balken, 0.9)
  t.zeilen = {}
  for i = 1, MAX_ZEILEN + 1 do
    local z = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    z:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 14)
    z:SetPoint("RIGHT", -10, 0)
    z:SetJustifyH("LEFT")
    z:SetWordWrap(false)
    t.zeilen[i] = z
  end
  local pos = ns.db.optionen.trackerPos
  if pos then
    t:ClearAllPoints()
    t:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end
  return t
end

-- Anteil der Materialien, die schon da sind (0–1)
function ns.ListeFortschritt()
  local bedarf = ns.Rechnen()
  local soll, hat = 0, 0
  for id, n in pairs(bedarf) do
    soll = soll + n
    hat = hat + math.min(ns.Vorrat(id), n)
  end
  if soll == 0 then return nil end
  return hat / soll
end

function ns.TrackerZeilen()
  local bedarf = ns.Rechnen()
  local t = {}
  for id, n in pairs(bedarf) do
    local hat = ns.Vorrat(id)
    if hat < n then t[#t + 1] = { id = id, hat = hat, n = n } end
  end
  table.sort(t, function(a, b) return ns.ItemName(a.id) < ns.ItemName(b.id) end)
  return t
end

function ns.TrackerNeu()
  if not (ns.db and ns.db.optionen.tracker) then
    if tracker then tracker:Hide() end
    return
  end
  tracker = tracker or TrackerBauen()
  local anteil = ns.ListeFortschritt()
  if not anteil then
    tracker:Hide()
    return
  end
  local zeilen = ns.TrackerZeilen()
  tracker.titel:SetText("WERKBANK · " .. (ns.L.name or "Liste"):upper() .. "  " .. math.floor(anteil * 100 + 0.5) .. " %")
  tracker.balken:SetWidth(math.max(1, 220 * anteil))
  for i, z in ipairs(tracker.zeilen) do
    local e = zeilen[i]
    if i > MAX_ZEILEN and e then
      z:SetText(F.grau .. "und " .. (#zeilen - MAX_ZEILEN) .. " weitere …|r")
      z:Show()
    elseif e and i <= MAX_ZEILEN then
      z:SetText(F.rot .. e.hat .. "/" .. e.n .. "|r " .. F.weiss .. ns.ItemName(e.id) .. "|r")
      z:Show()
    else
      z:Hide()
    end
  end
  local n = math.min(#zeilen, MAX_ZEILEN + 1)
  if n == 0 then
    tracker.zeilen[1]:SetText(F.gruen .. "Alles da. Ab an die Werkbank!|r")
    tracker.zeilen[1]:Show()
    n = 1
  end
  tracker:SetHeight(36 + n * 14)
  tracker:SetScale(ns.Groesse())
  tracker.hg:SetColorTexture(S.HG[1], S.HG[2], S.HG[3], ns.Deckkraft(0.75))
  tracker:Show()
end
ns.BeiAenderung(function() ns.TrackerNeu() end)

function ns.TrackerUmschalten(an)
  if an == nil then an = not ns.db.optionen.tracker end
  ns.db.optionen.tracker = an and true or false
  ns.TrackerNeu()
  ns.Aktualisieren()
  return ns.db.optionen.tracker
end

-- ---------- Statistik: hergestellte Gegenstände und gesammelte Materialien ----------

local sitzung = {}     -- Gegenstand -> in dieser Sitzung dazugekommen
local vorher = {}      -- Gegenstand -> Anzahl beim letzten Taschen-Update

function ns.StatistikDB()
  local s = ns.db.statistik or { gesamt = {}, heute = {}, tag = Heute() }
  ns.db.statistik = s
  if s.tag ~= Heute() then
    s.tag = Heute()
    s.heute = {}
  end
  ns.char.hergestellt = ns.char.hergestellt or {}
  return s
end

function ns.HergestelltZaehlen(id, n)
  if not id then return end
  n = n or 1
  local s = ns.StatistikDB()
  s.gesamt[id] = (s.gesamt[id] or 0) + n
  s.heute[id] = (s.heute[id] or 0) + n
  ns.char.hergestellt[id] = (ns.char.hergestellt[id] or 0) + n
end

ns.AufEreignis("CHAT_MSG_LOOT", function(msg)
  local id, n = ns.HerstellungAusChat(msg)
  if id then ns.HergestelltZaehlen(id, n) end
end)

local bereit = false
local function Sammeln()
  local neu = {}
  for id in pairs(ns.char.taschen or {}) do neu[id] = ns.Vorrat(id) end
  for id in pairs(ns.char.bank or {}) do neu[id] = ns.Vorrat(id) end
  if bereit then
    for id, n in pairs(neu) do
      local alt = vorher[id] or 0
      if n > alt then sitzung[id] = (sitzung[id] or 0) + n - alt end
    end
  end
  vorher, bereit = neu, true
end
ns.AufEreignis("PLAYER_LOGIN", Sammeln)
ns.AufEreignis("BAG_UPDATE_DELAYED", Sammeln)

local function TopText(t, max)
  local ids = {}
  for id in pairs(t) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return t[a] > t[b] or (t[a] == t[b] and ns.ItemName(a) < ns.ItemName(b)) end)
  local z = {}
  for i = 1, math.min(#ids, max) do z[#z + 1] = "  " .. t[ids[i]] .. "× " .. ns.ItemName(ids[i]) end
  return z, #ids
end

function ns.StatistikText()
  local s = ns.StatistikDB()
  local summe, heute = 0, 0
  for _, n in pairs(s.gesamt) do summe = summe + n end
  for _, n in pairs(s.heute) do heute = heute + n end
  local zeilen = { F.gold .. "Hergestellt|r", "  Insgesamt: " .. summe .. ", heute: " .. heute }
  local top = TopText(s.gesamt, 10)
  if #top > 0 then
    zeilen[#zeilen + 1] = ""
    zeilen[#zeilen + 1] = F.gold .. "Am häufigsten hergestellt|r"
    for _, z in ipairs(top) do zeilen[#zeilen + 1] = z end
  end
  local proChar = {}
  for _, c in pairs(ns.db.chars) do
    local n = 0
    for _, x in pairs(c.hergestellt or {}) do n = n + x end
    if n > 0 then proChar[#proChar + 1] = (c.name or "?") .. " " .. n end
  end
  table.sort(proChar)
  if #proChar > 0 then
    zeilen[#zeilen + 1] = ""
    zeilen[#zeilen + 1] = F.gold .. "Je Charakter|r"
    zeilen[#zeilen + 1] = "  " .. table.concat(proChar, ", ")
  end
  local ges, anzahl = TopText(sitzung, 15)
  zeilen[#zeilen + 1] = ""
  zeilen[#zeilen + 1] = F.gold .. "In dieser Sitzung gesammelt|r"
  if anzahl == 0 then
    zeilen[#zeilen + 1] = F.grau .. "  Noch nichts. Materialien aus Rezepten werden hier gezählt, sobald sie in den Taschen landen.|r"
  else
    for _, z in ipairs(ges) do zeilen[#zeilen + 1] = z end
  end
  return table.concat(zeilen, "\n")
end

-- ---------- Sammlung: gelernte Rezepte je Beruf und Charakter ----------

function ns.SammlungText()
  local zeilen = {}
  for _, b in ipairs(D.berufe) do
    local teile = {}
    for _, c in pairs(ns.db.chars) do
      if c.berufe and c.berufe[b.id] then
        local n = 0
        for _, k in ipairs(b.kat) do
          for _, rid in ipairs(k[2]) do if c.bekannt and c.bekannt[rid] then n = n + 1 end end
        end
        teile[#teile + 1] = { c.name or "?", n }
      end
    end
    if #teile > 0 then
      table.sort(teile, function(x, y) return x[2] > y[2] end)
      zeilen[#zeilen + 1] = F.gold .. b.name .. "|r " .. F.grau .. "(" .. b.anzahl .. " Rezepte)|r"
      for _, t in ipairs(teile) do
        local p = math.floor(t[2] / math.max(b.anzahl, 1) * 100 + 0.5)
        local balken = ("|"):rep(math.floor(p / 5))
        zeilen[#zeilen + 1] = "  " .. t[1] .. ": " .. t[2] .. " von " .. b.anzahl .. " (" .. p .. " %)  " .. F.gold .. balken .. "|r"
      end
      zeilen[#zeilen + 1] = ""
    end
  end
  if #zeilen == 0 then return "Noch keine Berufe erfasst. Öffne einmal das Berufsfenster." end
  return table.concat(zeilen, "\n")
end

-- ---------- Gold, zuletzt gesehen ----------

local function GoldMerken() if GetMoney then ns.char.gold = GetMoney() end end
ns.AufEreignis("PLAYER_LOGIN", function()
  GoldMerken()
  ns.char.zuletzt = Jetzt()
end)
ns.AufEreignis("PLAYER_MONEY", GoldMerken)
ns.AufEreignis("PLAYER_LOGOUT", function() ns.char.zuletzt = Jetzt() GoldMerken() end)

function ns.Alter(zeit)
  if not zeit or zeit == 0 then return "unbekannt" end
  local s = Jetzt() - zeit
  if s < 3600 then return "gerade eben" end
  if s < 86400 then return "vor " .. math.floor(s / 3600) .. " Std." end
  local t = math.floor(s / 86400)
  return t == 1 and "vor 1 Tag" or ("vor " .. t .. " Tagen")
end

function ns.GoldSumme()
  local summe = 0
  for _, c in pairs(ns.db.chars) do
    if c.realm == ns.char.realm then summe = summe + (c.gold or 0) end
  end
  return summe
end

-- Tabelle Beruf × Charakter als Text
function ns.BerufeTabelle()
  local zeilen = {}
  for _, b in ipairs(D.berufe) do
    local wer = {}
    for _, c in pairs(ns.db.chars) do
      local s = c.berufe and c.berufe[b.id]
      if s then wer[#wer + 1] = (c.name or "?") .. " " .. (s.stufe or 0) end
    end
    table.sort(wer)
    if #wer > 0 then zeilen[#zeilen + 1] = F.gold .. b.name .. ":|r " .. table.concat(wer, ", ") end
  end
  return table.concat(zeilen, "\n")
end

-- ---------- Abklingzeiten (Transmutation, Mondstoff …) ----------

ns.ABKLINGEN = {
  { "Transmutation", { 11479, 11480, 17187, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566, 25146 } },
  { "Mondstoff", { 18560 } },
}

local function Bekannt(id)
  if IsPlayerSpell then return IsPlayerSpell(id) end
  if IsSpellKnown then return IsSpellKnown(id) end
  return false
end

function ns.AbklingzeitenLesen()
  if not GetSpellCooldown then return end
  ns.char.abklingzeiten = ns.char.abklingzeiten or {}
  for _, g in ipairs(ns.ABKLINGEN) do
    for _, id in ipairs(g[2]) do
      if Bekannt(id) then
        local start, dauer = GetSpellCooldown(id)
        local ende = 0
        if start and dauer and dauer > 1.5 and GetTime then ende = Jetzt() + math.floor(start + dauer - GetTime()) end
        ns.char.abklingzeiten[g[1]] = ende
        break
      end
    end
  end
end

local function Dauer(s)
  if s <= 0 then return F.gruen .. "bereit|r" end
  local h, m = math.floor(s / 3600), math.floor(s / 60) % 60
  if h >= 24 then return "noch " .. math.floor(h / 24) .. " T " .. (h % 24) .. " Std." end
  return "noch " .. h .. " Std. " .. m .. " Min."
end

function ns.AbklingText()
  local zeilen = {}
  local keys = {}
  for key in pairs(ns.db.chars) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local c = ns.db.chars[key]
    for name, ende in pairs(c.abklingzeiten or {}) do
      zeilen[#zeilen + 1] = (c.name or "?") .. " · " .. name .. ": " .. Dauer(ende - Jetzt())
    end
  end
  table.sort(zeilen)
  if #zeilen == 0 then
    return "Keiner deiner Charaktere hat eine Abklingzeit für Transmutationen oder Mondstoff. Sobald ein Charakter so ein Rezept kennt, steht es hier."
  end
  return table.concat(zeilen, "\n")
end

-- Fertige Abklingzeiten einmal melden
function ns.AbklingPruefen()
  if not (ns.db and ns.db.optionen.abklingMeldung) then return {} end
  local fertig = {}
  for _, c in pairs(ns.db.chars) do
    c.abklingGemeldet = c.abklingGemeldet or {}
    for name, ende in pairs(c.abklingzeiten or {}) do
      if ende <= Jetzt() and c.abklingGemeldet[name] ~= ende then
        c.abklingGemeldet[name] = ende
        fertig[#fertig + 1] = name .. " (" .. (c.name or "?") .. ")"
      end
    end
  end
  table.sort(fertig)
  if #fertig > 0 then
    ns.Print("Wieder bereit: " .. table.concat(fertig, ", "))
    ns.Bildschirm("Wieder bereit: " .. table.concat(fertig, ", "))
  end
  return fertig
end

ns.AufEreignis("PLAYER_LOGIN", function()
  ns.AbklingzeitenLesen()
  ns.AbklingPruefen()
  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(60, function() ns.AbklingPruefen() end) end
end)
ns.AufEreignis("TRADE_SKILL_UPDATE", function() ns.AbklingzeitenLesen() end)
ns.AufEreignis("SPELL_UPDATE_COOLDOWN", function()
  local t = GetTime and GetTime() or 0
  if ns.abklingZuletzt and t - ns.abklingZuletzt < 5 then return end
  ns.abklingZuletzt = t
  ns.AbklingzeitenLesen()
end)

-- ---------- Stufenaufstieg, Lehrer, Meilensteine ----------

local MEILENSTEINE = { [75] = "Geselle", [150] = "Experte", [225] = "Fachmann", [300] = "Meister" }

function ns.StufenVergleichen(alt)
  if not ns.db.optionen.berufHinweise then return end
  ns.char.lehrerHinweis = ns.char.lehrerHinweis or {}
  for id, s in pairs(ns.char.berufe) do
    local b = ns.beruf[id]
    local vorher = alt[id]
    if b and vorher and s.stufe and vorher < s.stufe then
      ns.Print(b.name .. ": " .. vorher .. " → " .. F.gruen .. s.stufe .. "|r von " .. (s.max or "?"))
      for stufe, titel in pairs(MEILENSTEINE) do
        if vorher < stufe and s.stufe >= stufe then
          ns.Print(F.gold .. "Glückwunsch! " .. b.name .. " " .. stufe .. " – " .. titel .. "-Niveau erreicht.|r")
          ns.Bildschirm("Glückwunsch! " .. b.name .. " " .. stufe)
          ns.Sprechen("Glückwunsch! " .. b.name .. " " .. stufe)
          if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.LEVEL_UP or 888) end
        end
      end
    end
    if b and s.stufe and s.max and s.max < 300 and s.stufe >= s.max and ns.char.lehrerHinweis[id] ~= s.max then
      ns.char.lehrerHinweis[id] = s.max
      ns.Print(b.name .. " steht bei " .. s.stufe .. "/" .. s.max .. ". Zeit für den Lehrer, um weiterzulernen.")
    end
  end
end

ns.AufEreignis("SKILL_LINES_CHANGED", function()
  local alt = {}
  for id, s in pairs(ns.char.berufe) do alt[id] = s.stufe end
  ns.FertigkeitenLesen()
  ns.StufenVergleichen(alt)
end)

-- ---------- Hinweise beim Einloggen: was andere Charaktere brauchen ----------

function ns.PostHinweise()
  if not ns.db.optionen.postHinweis or ns.db.optionen.gemeinsam then return {} end
  local hinweise = {}
  for _, c in ipairs(ns.TwinksMitListe()) do
    local l = ns.TwinkListe(c)
    local bedarf = ns.Rechnen(l.liste, l.selbst)
    local teile = {}
    for id, n in pairs(bedarf) do
      local fehlt = n - ((c.taschen or {})[id] or 0) - ((c.bank or {})[id] or 0)
      local hab = ns.Vorrat(id)
      if fehlt > 0 and hab > 0 then teile[#teile + 1] = math.min(fehlt, hab) .. "× " .. ns.ItemName(id) end
    end
    if #teile > 0 then
      table.sort(teile)
      hinweise[#hinweise + 1] = c.name .. " braucht, was du hast: " .. table.concat(teile, ", ")
    end
  end
  for _, h in ipairs(hinweise) do ns.Print(h) end
  return hinweise
end
ns.AufEreignis("PLAYER_LOGIN", function() ns.PostHinweise() end)

-- ---------- Post-Helfer: Materialien für einen Twink anhängen ----------

local function Benutzen(bag, slot)
  if C_Container and C_Container.UseContainerItem then return C_Container.UseContainerItem(bag, slot) end
  if UseContainerItem then return UseContainerItem(bag, slot) end
end

function ns.PostAnhaengen()
  local box = SendMailNameEditBox
  local name = box and box:GetText() or ""
  local ziel
  for _, c in ipairs(ns.TwinksMitListe()) do
    if name == "" or (c.name or ""):lower() == name:lower() then
      ziel = c
      break
    end
  end
  if not ziel then
    ns.Print(name == "" and "Keiner deiner Charaktere braucht gerade etwas." or (name .. " ist kein eigener Charakter mit Einkaufsliste."))
    return 0
  end
  if box and name == "" then box:SetText(ziel.name) end
  local l = ns.TwinkListe(ziel)
  local bedarf = ns.Rechnen(l.liste, l.selbst)
  local fehlt = {}
  for id, n in pairs(bedarf) do
    local f = n - ((ziel.taschen or {})[id] or 0) - ((ziel.bank or {})[id] or 0)
    if f > 0 then fehlt[id] = f end
  end
  local max, n = ATTACHMENTS_MAX_SEND or 12, 0
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, ns.SlotAnzahl(bag) do
      local id, anz = ns.SlotInhalt(bag, slot)
      if id and fehlt[id] and fehlt[id] > 0 and n < max then
        Benutzen(bag, slot)
        fehlt[id] = fehlt[id] - (anz or 1)
        n = n + 1
      end
    end
  end
  ns.Print(n > 0 and (n .. " Stapel für " .. ziel.name .. " angehängt.") or ("Du hast nichts, was " .. ziel.name .. " noch braucht."))
  return n
end

ns.AufEreignis("MAIL_SHOW", function()
  if not SendMailFrame or SendMailFrame.werkbankKnopf then return end
  local b = S.Knopf(SendMailFrame, "Für Twink", 90)
  b:SetPoint("TOPRIGHT", SendMailFrame, "TOPRIGHT", -40, -30)
  b:SetFrameLevel(SendMailFrame:GetFrameLevel() + 5)
  b:SetScript("OnClick", ns.PostAnhaengen)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Werkbank", 1, 1, 1)
    GameTooltip:AddLine("Hängt an, was der Empfänger für seine Einkaufsliste noch braucht. Ohne Empfänger wird der erste Charakter mit Bedarf eingetragen.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  SendMailFrame.werkbankKnopf = b
end)

-- ---------- Hinweise bei Bank, Händler, Beute und Berufsfenster ----------

function ns.BankHinweis()
  local bedarf = ns.Rechnen()
  local n = 0
  for id, soll in pairs(bedarf) do
    local taschen = GetItemCount and GetItemCount(id) or 0
    if taschen < soll and ((ns.char.bank or {})[id] or 0) > 0 then n = n + 1 end
  end
  if n > 0 then ns.Print("In der Bank liegen " .. n .. (n == 1 and " Material" or " Materialien") .. " für deine Liste. Knopf „Material holen“ legt sie in die Taschen.") end
  return n
end
ns.AufEreignis("BANKFRAME_OPENED", function() ns.BankHinweis() end)

function ns.HaendlerRezepte()
  if not GetMerchantNumItems then return {} end
  local neu = {}
  for i = 1, GetMerchantNumItems() do
    local name = GetMerchantItemInfo(i)
    local rid = ns.RezeptAusGegenstand(name)
    if rid and not ns.IrgendwerKennt(rid) then neu[#neu + 1] = ns.RezeptName(rid) end
  end
  if #neu > 0 then ns.Print("Dieser Händler hat " .. #neu .. (#neu == 1 and " Rezept" or " Rezepte") .. ", das noch keiner deiner Charaktere kennt: " .. table.concat(neu, ", ")) end
  return neu
end
ns.AufEreignis("MERCHANT_SHOW", function() if ns.db.optionen.berufHinweise then ns.HaendlerRezepte() end end)

local function Muster(fmt)
  if not fmt then return nil end
  fmt = fmt:gsub("%%%d%$", "%%"):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  return "^" .. fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
end
local BEUTE = Muster(LOOT_ITEM_SELF)
local BEUTE_MEHR = Muster(LOOT_ITEM_SELF_MULTIPLE)

function ns.BeuteRezept(msg)
  if not msg then return nil end
  local link = (BEUTE_MEHR and msg:match(BEUTE_MEHR)) or (BEUTE and msg:match(BEUTE))
  local name = link and link:match("%[(.-)%]")
  local rid = ns.RezeptAusGegenstand(name)
  if not rid then return nil end
  local kenner = ns.Kenner(rid)
  if #kenner > 0 then
    ns.Print(name .. ": kennt schon " .. table.concat(kenner, ", ") .. ".")
  else
    local b = ns.berufOf[rid]
    local koennten = {}
    for _, c in pairs(ns.db.chars) do
      if b and c.berufe and c.berufe[b.id] then koennten[#koennten + 1] = c.name or "?" end
    end
    table.sort(koennten)
    ns.Print(F.gruen .. "Neues Rezept: " .. name .. "|r" .. (#koennten > 0 and (" – lernen kann es " .. table.concat(koennten, ", ")) or " – keiner deiner Charaktere hat " .. (b and b.name or "den Beruf")) .. ".")
    ns.Sprechen("Neues Rezept: " .. name)
  end
  return rid
end
ns.AufEreignis("CHAT_MSG_LOOT", function(msg) if ns.db.optionen.berufHinweise then ns.BeuteRezept(msg) end end)

-- Beim Öffnen des Berufsfensters: was von der Liste geht jetzt?
local berufsfensterGemeldet
function ns.BerufsfensterHinweis()
  local b = ns.offenerBeruf
  if not b or berufsfensterGemeldet == b.id then return {} end
  berufsfensterGemeldet = b.id
  local t = {}
  for rid, n in pairs(ns.L.liste) do
    if ns.berufOf[rid] == b and ns.char.bekannt[rid] then
      local m = ns.Moeglich(rid)
      if m > 0 then t[#t + 1] = math.min(m, n) .. "× " .. ns.RezeptName(rid) end
    end
  end
  table.sort(t)
  if #t > 0 then ns.Print("Von deiner Liste kannst du jetzt herstellen: " .. table.concat(t, ", ")) end
  return t
end
ns.AufEreignis("TRADE_SKILL_SHOW", function() ns.BerufsfensterHinweis() end)
ns.AufEreignis("CRAFT_SHOW", function() ns.BerufsfensterHinweis() end)
ns.AufEreignis("TRADE_SKILL_CLOSE", function() berufsfensterGemeldet = nil end)
ns.AufEreignis("CRAFT_CLOSE", function() berufsfensterGemeldet = nil end)

-- Knopf „Liste herstellen“ im Berufsfenster: stellt das gewählte Rezept so oft her, wie es auf der Liste steht
function ns.ListeHerstellen()
  if not (TradeSkillFrame and TradeSkillFrame:IsShown() and GetTradeSkillSelectionIndex and DoTradeSkill) then return 0 end
  local rid = ns.GewaehltesRezept()
  local i = GetTradeSkillSelectionIndex()
  local n = rid and ns.L.liste[rid]
  if not n then
    ns.Print("Das gewählte Rezept steht nicht auf deiner Liste.")
    return 0
  end
  local _, _, moeglich = GetTradeSkillInfo(i)
  n = math.min(n, moeglich or n)
  if n <= 0 then
    ns.Print("Dafür fehlen noch Materialien.")
    return 0
  end
  DoTradeSkill(i, n)
  ns.Print(n .. "× " .. ns.RezeptName(rid) .. " wird hergestellt.")
  return n
end

local alt = ns.BlizzardFensterGeladen
function ns.BlizzardFensterGeladen(name)
  if alt then alt(name) end
  if name == "Blizzard_TradeSkillUI" and TradeSkillFrame and TradeSkillFrame.werkbankKnopf and not TradeSkillFrame.werkbankHerstellen then
    local b = S.Knopf(TradeSkillFrame, "Liste herstellen", 110)
    b:SetFrameLevel(TradeSkillFrame:GetFrameLevel() + 5)
    b:SetPoint("RIGHT", TradeSkillFrame.werkbankKnopf, "LEFT", -2, 0)
    b:SetScript("OnClick", ns.ListeHerstellen)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Liste herstellen", 1, 1, 1)
      GameTooltip:AddLine("Stellt das gewählte Rezept so oft her, wie es auf deiner Einkaufsliste steht (soweit die Materialien reichen).", nil, nil, nil, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    TradeSkillFrame.werkbankHerstellen = b
  end
end

-- ---------- Flüsteranfragen „!werkbank Rezept“ ----------

local zuletzt = {}
function ns.Fluesteranfrage(msg, wer)
  if not (ns.db.optionen.fluestern and msg and wer) then return nil end
  local frage = msg:match("^%s*![Ww][Ee][Rr][Kk][Bb][Aa][Nn][Kk]%s+(.+)$")
  if not frage then return nil end
  local t = GetTime and GetTime() or 0
  if zuletzt[wer] and t - zuletzt[wer] < 10 then return nil end
  zuletzt[wer] = t
  local id = ns.GegenstandSuchen(frage)
  local antwort
  local rid
  if id and ns.madeBy[id] then
    for _, x in ipairs(ns.madeBy[id]) do if ns.char.bekannt[x] then rid = x end end
  end
  if rid then
    local z, r = {}, D.rezepte[rid][4]
    for i = 1, #r, 2 do z[#z + 1] = r[i + 1] .. "× " .. ns.ItemName(r[i]) end
    antwort = "[Werkbank] Ja, ich kann " .. ns.RezeptName(rid) .. " herstellen. Zutaten: " .. table.concat(z, ", ")
  elseif id then
    antwort = "[Werkbank] " .. ns.ItemName(id) .. " kann ich leider nicht herstellen."
  else
    antwort = "[Werkbank] Diesen Gegenstand kenne ich nicht."
  end
  if SendChatMessage then SendChatMessage(antwort:sub(1, 255), "WHISPER", nil, wer) end
  return antwort
end
ns.AufEreignis("CHAT_MSG_WHISPER", function(msg, wer) ns.Fluesteranfrage(msg, wer) end)

-- ---------- Start ----------

ns.AufEreignis("PLAYER_LOGIN", function()
  ns.TrackerNeu()
  if not ns.db.assistentFertig and ns.AssistentStarten and C_Timer and C_Timer.After then
    C_Timer.After(3, function() if not ns.db.assistentFertig then ns.AssistentStarten() end end)
  end
end)
