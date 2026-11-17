-- Fenster im einheitlichen ForeverUI-Design: ein Hauptfenster, links die Seitenleiste,
-- rechts der Inhaltskasten mit Rezeptbuch und Einkaufsliste, Charakteren, Austausch, Optionen und Hilfe
local _, ns = ...
local D = ns.daten
local S = ns.Stil
local SCHRITTE = { "willkommen", "barrierefreiheit", "funktionen", "darstellung" }

local ROW_H = 20
local F = ns.F
local FILTER = { "Alle Rezepte", "Gelernt", "Noch nicht gelernt", "Von meinen Charakteren", "Jetzt herstellbar", "Favoriten", "Bringt noch Punkte", "Beim Händler gesehen", "Neu seit Datenupdate", "Mit Gewinn" }
local SORTIERUNG = { "Kategorie", "Name", "Schwierigkeit", "Möglich" }
local SW_RANG = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
local STERN = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"
local LEISTE_B = 168

local ui = {}
ns.ui = ui
local EintragText -- weiter unten definiert
local Neu         -- Hauptfenster neu zeichnen

-- ---------- Bausteine ----------

local Knopf = S.Knopf

local function Tipp(frame, titel, ...)
  local zeilen = { ... }
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(titel, 1, 1, 1)
    for _, z in ipairs(zeilen) do GameTooltip:AddLine(z, nil, nil, nil, true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Eine scrollbare Liste aus gleich hohen Zeilen, die mit dem Fenster mitwächst.
-- zeichne(row, eintrag) füllt eine Zeile.
local listenZaehler = 0
local function Liste(parent, zeichne, klick, enter)
  listenZaehler = listenZaehler + 1
  local l = CreateFrame("Frame", nil, parent)
  l.eintraege, l.rows, l.anzahl, l.cursor, l.klick = {}, {}, 0, 1, klick
  l.hoehe = 360 -- bis das Fenster seine echte Größe kennt

  local scroll = CreateFrame("ScrollFrame", "WerkbankListe" .. listenZaehler .. "Scroll", l, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  l.scroll = scroll

  local function NeueZeile(i)
    local row = CreateFrame("Button", nil, l)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", l, "RIGHT", -26, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    S.Zeile(row)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 4, ROW_H - 4)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.rechts = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.rechts:SetPoint("RIGHT", -4, 0)
    row.rechts:SetJustifyH("RIGHT")

    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.rechts, "LEFT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnClick", function(self, btn)
      if self.eintrag and klick then klick(self.eintrag, btn) end
    end)
    row:SetScript("OnEnter", function(self)
      if self.eintrag and enter then enter(self, self.eintrag) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
  end

  function l:Neu()
    local e = self.eintraege
    FauxScrollFrame_Update(scroll, #e, self.anzahl, ROW_H)
    local off = FauxScrollFrame_GetOffset(scroll)
    for i = 1, self.anzahl do
      local row = self.rows[i]
      local eintrag = e[i + off]
      row.eintrag = eintrag
      row.index = i + off
      row:Gewaehlt(eintrag ~= nil and self.aktiv and self.cursor == i + off)
      row.zebra:SetShown(eintrag ~= nil and not eintrag.kopf and (i + off) % 2 == 0)
      if eintrag then
        zeichne(row, eintrag)
        row:Show()
      else
        row:Hide()
      end
    end
  end

  -- Zeilen an die Höhe anpassen
  function l:Groesse()
    local h = self:GetHeight()
    if not h or h < ROW_H then h = self.hoehe end
    local n = math.max(1, math.floor(h / ROW_H))
    for i = #self.rows + 1, n do self.rows[i] = NeueZeile(i) end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    self.anzahl = n
    self:Neu()
  end
  l:SetScript("OnSizeChanged", function(self) self:Groesse() end)

  -- Cursor bewegen und sichtbar halten
  function l:Gehe(n)
    local e = self.eintraege
    if #e == 0 then return end
    local ziel = math.max(1, math.min(#e, n))
    -- Kopfzeilen überspringen
    local schritt = ziel >= self.cursor and 1 or -1
    while e[ziel] and (e[ziel].kopf or e[ziel].info) do ziel = ziel + schritt end
    if not e[ziel] then
      ziel = math.max(1, math.min(#e, n))
      while e[ziel] and (e[ziel].kopf or e[ziel].info) do ziel = ziel - schritt end
    end
    if not e[ziel] then return end
    self.cursor = ziel
    local off = FauxScrollFrame_GetOffset(scroll)
    if ziel <= off then off = ziel - 1 elseif ziel > off + self.anzahl then off = ziel - self.anzahl end
    FauxScrollFrame_SetOffset(scroll, off)
    scroll:SetVerticalScroll(off * ROW_H)
    self:Neu()
    return e[ziel]
  end

  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() l:Neu() end)
  end)

  l:Groesse()
  return l
end

-- Schreibgeschütztes Textfeld zum Kopieren
local function KopierFeld(parent, w)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(w or 400, 20)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  box:SetScript("OnTextChanged", function(self, user)
    if user and self.fest then
      self:SetText(self.fest)
      self:HighlightText()
    end
  end)
  function box:Fest(text)
    self.fest = text
    self:SetText(text)
    self:SetCursorPosition(0)
  end
  box.label = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  box.label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 2)
  return box
end

local function ZeichneKopf(row, e)
  row.icon:Hide()
  row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
  row.text:SetText(F.gold .. e.kopf .. "|r")
  row.rechts:SetText(e.rechts or "")
end

local function ZeichneZeile(row, icon, text, rechts)
  row.icon:Show()
  row.icon:SetTexture(icon)
  row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.text:SetText(text)
  row.rechts:SetText(rechts or "")
end

-- Tooltip für ein Rezept: Ergebnis und Zutaten mit Vorrat
local function RezeptTooltip(owner, rid)
  local r = D.rezepte[rid]
  if not r then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if r[2] then
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(r[2]) else GameTooltip:SetHyperlink("item:" .. r[2]) end
  else
    GameTooltip:SetText(r[1], 1, 1, 1)
  end
  GameTooltip:AddLine(" ")
  local b = ns.berufOf[rid]
  GameTooltip:AddLine(F.gold .. (b and b.name or "") .. "|r " .. F.grau .. (ns.katOf[rid] or "") .. "|r")
  local z = r[4]
  for i = 1, #z, 2 do
    local id, n = z[i], z[i + 1]
    local hat = ns.Vorrat(id)
    GameTooltip:AddDoubleLine(ns.QualitaetFarbe(id) .. ns.ItemName(id) .. "|r", (hat >= n and F.gruen or F.rot) .. hat .. " / " .. n .. (hat >= n and "" or (" (fehlt " .. (n - hat) .. ")")) .. "|r")
  end
  local m = r[3]
  if type(m) == "table" then
    GameTooltip:AddLine(F.grau .. "Ergibt " .. m[1] .. " bis " .. m[2] .. " Stück|r")
  elseif m > 1 then
    GameTooltip:AddLine(F.grau .. "Ergibt " .. m .. " Stück|r")
  end
  local kenner = ns.Kenner(rid)
  if #kenner > 0 then GameTooltip:AddLine(F.gruen .. "Gelernt: " .. table.concat(kenner, ", ") .. "|r", nil, nil, nil, true) end
  local sw = ns.char.bekannt[rid] and ns.SCHWIERIGKEIT[ns.char.schwierigkeit[rid] or ""]
  if sw then GameTooltip:AddLine("Schwierigkeit: " .. sw[2] .. sw[1] .. "|r") end
  local moeglich = ns.Moeglich(rid)
  if moeglich > 0 then GameTooltip:AddLine(F.weiss .. "Mit deinem Vorrat " .. moeglich .. "× möglich|r") end
  if ns.db.favoriten[rid] then GameTooltip:AddLine(STERN .. " Favorit") end
  local notiz = ns.db.notizen and ns.db.notizen[rid]
  if notiz then GameTooltip:AddLine(F.gold .. "Notiz:|r " .. notiz, 1, 1, 1, true) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(F.grau .. "Klick: auf die Liste  ·  Umschalt-Klick: in den Chat|r")
  GameTooltip:AddLine(F.grau .. "Alt-Klick: Favorit  ·  Mittel- oder Strg-Rechtsklick: Details|r")
  GameTooltip:Show()
  ns.Sprechen(ns.RezeptText(rid))
end

local function ItemTooltip(owner, id, zusatz)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then GameTooltip:SetItemByID(id) else GameTooltip:SetHyperlink("item:" .. id) end
  if zusatz then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(F.grau .. zusatz .. "|r", nil, nil, nil, true)
  end
  GameTooltip:Show()
end

local function ChatLink(rid)
  local r = D.rezepte[rid]
  if not r then return end
  if r[2] then
    local _, link = GetItemInfo(r[2])
    if link and ChatEdit_InsertLink then
      ChatEdit_InsertLink(link)
      return
    end
  end
  if ChatEdit_InsertLink then ChatEdit_InsertLink(ns.RezeptName(rid)) end
end

-- ---------- Rezeptbuch ----------

ui.zu = {}         -- zugeklappte Kategorien
ui.sortierung = 1

-- Passt ein Rezept zu Filter und Suchwörtern? Alle Wörter müssen im Namen oder in einer Zutat vorkommen.
local function Passt(rid, filter, woerter)
  local bekannt = ns.char.bekannt[rid]
  local sw = ns.char.schwierigkeit[rid]
  local ok = filter == 1 or (filter == 2 and bekannt) or (filter == 3 and not bekannt)
    or (filter == 4 and ns.IrgendwerKennt(rid))
    or (filter == 5 and ns.Moeglich(rid) > 0)
    or (filter == 6 and ns.db.favoriten[rid])
    or (filter == 7 and bekannt and (sw == "optimal" or sw == "medium" or sw == "easy"))
    or (filter == 8 and ns.db.quellen and ns.db.quellen[rid] and ns.db.quellen[rid].haendler)
    or (filter == 9 and ns.NeueRezepte and ns.NeueRezepte()[rid])
    or (filter == 10 and ns.RezeptGewinn and (ns.RezeptGewinn(rid) or 0) > 0)
  if not ok then return false end
  if #woerter == 0 then return true end
  local name = ns.RezeptName(rid):lower()
  local z = D.rezepte[rid][4]
  for _, w in ipairs(woerter) do
    local treffer = name:find(w, 1, true) ~= nil
    if not treffer then
      for i = 1, #z, 2 do
        if ns.ItemName(z[i]):lower():find(w, 1, true) then
          treffer = true
          break
        end
      end
    end
    if not treffer then return false end
  end
  return true
end

local function Sortieren(rids)
  local art = ui.sortierung
  if art == 1 then return end
  local name, wert = {}, {}
  for _, rid in ipairs(rids) do
    name[rid] = ns.RezeptName(rid)
    if art == 3 then wert[rid] = ns.char.bekannt[rid] and (SW_RANG[ns.char.schwierigkeit[rid] or ""] or 5) or 6
    elseif art == 4 then wert[rid] = -ns.Moeglich(rid)
    else wert[rid] = 0 end
  end
  table.sort(rids, function(a, b)
    if wert[a] ~= wert[b] then return wert[a] < wert[b] end
    return name[a] < name[b]
  end)
end

local function RezeptbuchEintraege()
  local such = (ui.suche:GetText() or ""):lower()
  local woerter = {}
  for w in such:gmatch("%S+") do woerter[#woerter + 1] = w end
  local gruppen = {}
  if ui.ueberall and #woerter > 0 then
    -- Suche in allen Berufen: eine Gruppe je Beruf
    for _, b in ipairs(D.berufe) do
      local rids = {}
      for _, k in ipairs(b.kat) do for _, rid in ipairs(k[2]) do rids[#rids + 1] = rid end end
      gruppen[#gruppen + 1] = { b.name, "b" .. b.id, rids }
    end
  else
    local b = ns.beruf[ui.beruf]
    if not b then return {} end
    if ui.sortierung == 1 then
      for _, k in ipairs(b.kat) do gruppen[#gruppen + 1] = { k[1], b.id .. ":" .. k[1], k[2] } end
    else
      local rids = {}
      for _, k in ipairs(b.kat) do for _, rid in ipairs(k[2]) do rids[#rids + 1] = rid end end
      gruppen[1] = { "Alle Rezepte, nach " .. SORTIERUNG[ui.sortierung], b.id .. ":alle", rids }
    end
  end
  local e = {}
  for _, g in ipairs(gruppen) do
    local treffer, gelernt = {}, 0
    for _, rid in ipairs(g[3]) do
      if ns.char.bekannt[rid] then gelernt = gelernt + 1 end
      if Passt(rid, ui.filter, woerter) then treffer[#treffer + 1] = rid end
    end
    if #treffer > 0 then
      Sortieren(treffer)
      local zu = ui.zu[g[2]]
      e[#e + 1] = { kopf = (zu and "+ " or "– ") .. g[1], key = g[2],
        rechts = F.grau .. #treffer .. "  ·  " .. gelernt .. "/" .. #g[3] .. " gelernt|r" }
      if not zu then
        for _, rid in ipairs(treffer) do e[#e + 1] = { rid = rid } end
      end
    end
  end
  return e
end

local function ZeichneRezept(row, e)
  if e.kopf then return ZeichneKopf(row, e) end
  local rid = e.rid
  local r = D.rezepte[rid]
  local name = ns.RezeptName(rid)
  local farbe = r[2] and ns.QualitaetFarbe(r[2]) or F.weiss
  local rechts = ""
  local anz = ns.L.liste[rid]
  if anz then rechts = F.gold .. anz .. "×|r " end
  local moeglich = ns.Moeglich(rid)
  if moeglich > 0 then rechts = rechts .. F.weiss .. moeglich .. "× möglich|r " end
  if ns.char.bekannt[rid] then
    local sw = ns.SCHWIERIGKEIT[ns.char.schwierigkeit[rid] or ""]
    rechts = rechts .. (sw and (sw[2] .. sw[1] .. "|r") or (F.gruen .. "gelernt|r"))
  elseif ns.IrgendwerKennt(rid) then
    rechts = rechts .. F.grau .. table.concat(ns.Kenner(rid), ", ") .. "|r"
  end
  local stern = ns.db.favoriten[rid] and (STERN .. " ") or ""
  ZeichneZeile(row, ns.RezeptIcon(rid), stern .. farbe .. name .. "|r", rechts)
end

local function KlickRezept(e, btn)
  if e.key then
    ui.zu[e.key] = not ui.zu[e.key] or nil
    ns.Sprechen(e.kopf:sub(4) .. (ui.zu[e.key] and " zugeklappt." or " aufgeklappt."))
    return Neu()
  end
  if not e.rid then return end
  if btn == "MiddleButton" or (btn == "RightButton" and IsControlKeyDown()) then return ns.RezeptZeigen(e.rid) end
  if IsShiftKeyDown() then return ChatLink(e.rid) end
  if IsAltKeyDown and IsAltKeyDown() then
    local an = ns.FavoritUmschalten(e.rid)
    ns.Sprechen(ns.RezeptName(e.rid) .. (an and " ist jetzt Favorit." or " ist kein Favorit mehr."))
    return
  end
  if btn == "RightButton" then
    ns.ListeAdd(e.rid, -1)
  else
    ns.ListeAdd(e.rid, IsControlKeyDown() and 5 or 1)
  end
end

local function EnterRezept(row, e)
  if e.rid then RezeptTooltip(row, e.rid) end
end

-- ---------- Einkaufsliste ----------

local function ListeEintraege()
  local e = {}
  local rids = {}
  for rid in pairs(ns.L.liste) do rids[#rids + 1] = rid end
  table.sort(rids, function(a, b)
    local pa, pb = ns.Prio(a), ns.Prio(b)
    if pa ~= pb then return pa > pb end
    return ns.RezeptName(a) < ns.RezeptName(b)
  end)
  if #rids == 0 then
    e[1] = { kopf = "Die Liste ist leer" }
    e[2] = { info = "Links ein Rezept anklicken oder im" }
    e[3] = { info = "Berufsfenster auf „Werkbank“ drücken." }
    return e
  end
  e[#e + 1] = { kopf = "Herstellen", rechts = F.grau .. #rids .. "|r" }
  for _, rid in ipairs(rids) do e[#e + 1] = { liste = rid } end

  local bedarf, schritte = ns.Rechnen()
  local ids, fehlt = {}, 0
  for id, n in pairs(bedarf) do
    ids[#ids + 1] = id
    if ns.Vorrat(id) < n then fehlt = fehlt + 1 end
  end
  table.sort(ids, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  e[#e + 1] = { kopf = "Materialien", rechts = fehlt > 0 and (F.rot .. fehlt .. " fehlen|r") or (F.gruen .. "alles da|r") }
  if ns.db.optionen.gruppierung == "typ" then
    local typen, namen = {}, {}
    for _, id in ipairs(ids) do
      local typ = GetItemInfo and ns.Frei(select(6, GetItemInfo(id))) or nil
      typ = typ or "Sonstiges"
      if not typen[typ] then typen[typ] = {} namen[#namen + 1] = typ end
      table.insert(typen[typ], { mat = id, n = bedarf[id] })
    end
    table.sort(namen)
    for _, typ in ipairs(namen) do
      e[#e + 1] = { kopf = "  " .. typ, rechts = F.grau .. #typen[typ] .. "|r" }
      for _, x in ipairs(typen[typ]) do e[#e + 1] = x end
    end
    ids = {}
  end
  -- nach Quelle gruppieren: wo bekomme ich, was fehlt?
  local gruppen = { {}, {}, {}, {}, {} }
  local kosten = 0
  for _, id in ipairs(ids) do
    local n, hat = bedarf[id], ns.Vorrat(id)
    local g
    if hat >= n then g = 5
    elseif ns.HaendlerInfo(id) then
      g = 1
      kosten = kosten + math.ceil(ns.HaendlerInfo(id).preis * (n - hat))
    elseif ns.madeBy[id] and #ns.HerstellerVon(id) > 0 then g = 2
    elseif hat + ns.TwinkVorrat(id) >= n then g = 3
    else g = 4 end
    table.insert(gruppen[g], { mat = id, n = n })
  end
  local titel = { "Beim Händler", "Selbst herstellbar", "Bei deinen Charakteren", "Sammeln oder Auktionshaus", "Schon da" }
  for g, liste in ipairs(gruppen) do
    if #liste > 0 then
      local rechts = F.grau .. #liste .. "|r"
      if g == 1 and kosten > 0 then rechts = F.grau .. "ca. |r" .. ns.Geld(kosten) end
      e[#e + 1] = { kopf = "  " .. titel[g], rechts = rechts }
      for _, x in ipairs(liste) do e[#e + 1] = x end
    end
  end

  local st = {}
  for rid, mal in pairs(schritte) do st[#st + 1] = { schritt = rid, n = mal } end
  if #st > 0 then
    table.sort(st, function(a, b) return ns.RezeptName(a.schritt) < ns.RezeptName(b.schritt) end)
    e[#e + 1] = { kopf = "Zwischenprodukte" }
    for _, s in ipairs(st) do e[#e + 1] = s end
  end
  return e
end

local function ZeichneListe(row, e)
  if e.kopf then return ZeichneKopf(row, e) end
  if e.info then
    row.icon:Hide()
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetText(F.grau .. e.info .. "|r")
    row.rechts:SetText("")
    return
  end
  if e.liste then
    local rid = e.liste
    if not ns.L.liste[rid] then return ZeichneZeile(row, ns.RezeptIcon(rid), F.grau .. ns.RezeptName(rid) .. "|r", "") end
    local r = D.rezepte[rid]
    local farbe = r[2] and ns.QualitaetFarbe(r[2]) or F.weiss
    local rechts = ""
    if ns.char.bekannt[rid] then
      local m = ns.Moeglich(rid)
      if m >= ns.L.liste[rid] then rechts = F.gruen .. "bereit|r"
      elseif m > 0 then rechts = F.gruen .. m .. "× bereit|r" end
    else
      local kenner = ns.Kenner(rid)
      rechts = F.grau .. (#kenner > 0 and ("kann: " .. table.concat(kenner, ", ")) or "nicht gelernt") .. "|r"
    end
    local prio = ns.Prio(rid)
    local vorn = prio == 3 and (F.rot .. "! |r") or prio == 1 and (F.grau .. "· |r") or ""
    ZeichneZeile(row, ns.RezeptIcon(rid), vorn .. F.gold .. ns.L.liste[rid] .. "×|r " .. farbe .. ns.RezeptName(rid) .. "|r", rechts)
  elseif e.mat then
    local hat = ns.Vorrat(e.mat)
    local selbst = ""
    if ns.madeBy[e.mat] then
      local wer = ns.HerstellerVon(e.mat)
      selbst = F.grau .. "  herstellbar" .. (#wer > 0 and (": " .. table.concat(wer, ", ")) or "") .. "|r"
    end
    local twinks = hat < e.n and ns.TwinkVorrat(e.mat) or 0
    if twinks > 0 then selbst = selbst .. F.gold .. "  Twinks " .. twinks .. "|r" end
    ZeichneZeile(row, ns.ItemIcon(e.mat), ns.QualitaetFarbe(e.mat) .. ns.ItemName(e.mat) .. "|r" .. selbst,
      (hat >= e.n and F.gruen or F.rot) .. math.min(hat, e.n) .. " / " .. e.n .. (hat >= e.n and "" or ("  fehlt " .. (e.n - hat))) .. "|r")
  elseif e.schritt then
    local r = D.rezepte[e.schritt]
    ZeichneZeile(row, ns.RezeptIcon(e.schritt), F.gold .. e.n .. "×|r " .. ns.QualitaetFarbe(r[2]) .. ns.RezeptName(e.schritt) .. "|r",
      F.grau .. (ns.berufOf[e.schritt] and ns.berufOf[e.schritt].name or "") .. "|r")
  end
end

local function KlickListe(e, btn)
  if e.liste then
    if IsShiftKeyDown() then return ChatLink(e.liste) end
    if btn == "MiddleButton" then return ns.RezeptZeigen(e.liste) end
    if IsAltKeyDown and IsAltKeyDown() then
      local p = ns.PrioUmschalten(e.liste)
      ns.Sprechen(ns.RezeptName(e.liste) .. ": " .. ns.PRIO_NAME[p])
      return
    end
    if btn == "RightButton" then
      ns.ListeAdd(e.liste, IsControlKeyDown() and -999 or -1)
    else
      ns.ListeAdd(e.liste, IsControlKeyDown() and 5 or 1)
    end
  elseif e.mat then
    if IsShiftKeyDown() then
      local _, link = GetItemInfo(e.mat)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    elseif IsAltKeyDown and IsAltKeyDown() then
      if not ns.AHSuchen(e.mat) then ns.Print("Dazu muss das Auktionshaus geöffnet sein.") end
    elseif not ns.madeBy[e.mat] and ns.AHSuchen(e.mat) then
      return
    elseif ns.madeBy[e.mat] then
      ns.SelbstUmschalten(e.mat)
    end
  elseif e.schritt then
    local item = D.rezepte[e.schritt][2]
    if item then ns.SelbstUmschalten(item) end
  end
end

local function EnterListe(row, e)
  if e.liste then
    RezeptTooltip(row, e.liste)
    GameTooltip:AddLine(F.grau .. "Rechtsklick: eins weniger  ·  Strg-Rechtsklick: entfernen|r")
    GameTooltip:AddLine(F.grau .. "Alt-Klick: Priorität (jetzt " .. ns.PRIO_NAME[ns.Prio(e.liste)] .. ")|r")
    GameTooltip:Show()
  elseif e.mat then
    local zusatz = {}
    local _, wer = ns.TwinkVorrat(e.mat)
    if #wer > 0 then zusatz[#zusatz + 1] = "Bei deinen anderen Charakteren: " .. table.concat(wer, ", ") end
    local hersteller = ns.madeBy[e.mat] and ns.HerstellerVon(e.mat) or {}
    if #hersteller > 0 then zusatz[#zusatz + 1] = "Herstellen kann es: " .. table.concat(hersteller, ", ") end
    local h = ns.HaendlerInfo(e.mat)
    if h then zusatz[#zusatz + 1] = "Händler: " .. (h.wer or "?") .. (h.zone and (", " .. h.zone) or "") .. " – " .. ns.Geld(math.ceil(h.preis)) .. " pro Stück" end
    local preis, quelle = ns.Preis(e.mat)
    if preis then zusatz[#zusatz + 1] = "Preis: " .. ns.Geld(math.floor(preis + 0.5)) .. " (" .. quelle .. ") " .. ns.TrendText(e.mat) end
    local rat = ns.SelbstOderKaufen(e.mat)
    if rat then zusatz[#zusatz + 1] = rat end
    local mind = ns.db.mindest and ns.db.mindest[e.mat]
    if mind then zusatz[#zusatz + 1] = "Mindestbestand: " .. mind end
    local taschen, bank = ns.char.taschen and ns.char.taschen[e.mat], ns.char.bank and ns.char.bank[e.mat]
    if taschen or bank then zusatz[#zusatz + 1] = "Bei dir: " .. (taschen or 0) .. " in den Taschen, " .. (bank or 0) .. " auf der Bank" end
    if ns.madeBy[e.mat] then zusatz[#zusatz + 1] = "Klick: selbst herstellen statt kaufen" end
    zusatz[#zusatz + 1] = "Alt-Klick: im Auktionshaus suchen"
    ItemTooltip(row, e.mat, table.concat(zusatz, "\n"))
    ns.Sprechen(EintragText(e))
  elseif e.schritt then
    ItemTooltip(row, D.rezepte[e.schritt][2], "Klick: doch lieber kaufen")
    ns.Sprechen(EintragText(e))
  end
end

-- Text eines Listeneintrags für die Sprachausgabe
function EintragText(e)
  if not e then return "" end
  if e.kopf then return e.kopf .. ". " .. (e.rechts or "") end
  if e.info then return e.info end
  if e.rid then return ns.RezeptText(e.rid) end
  if e.liste then
    local t = ns.L.liste[e.liste] .. " mal " .. ns.RezeptName(e.liste) .. " herstellen."
    if ns.char.bekannt[e.liste] and ns.Moeglich(e.liste) > 0 then t = t .. " Bereit." end
    return t
  end
  if e.mat then
    local hat = ns.Vorrat(e.mat)
    local t = ns.ItemName(e.mat) .. ": " .. math.min(hat, e.n) .. " von " .. e.n .. "."
    if hat < e.n then t = t .. " Es fehlen " .. (e.n - hat) .. "." end
    if ns.madeBy[e.mat] then
      local wer = ns.HerstellerVon(e.mat)
      t = t .. " Herstellbar" .. (#wer > 0 and (" von " .. table.concat(wer, ", ")) or "") .. "."
    end
    local summe, wer = ns.TwinkVorrat(e.mat)
    if summe > 0 then t = t .. " Bei deinen anderen Charakteren: " .. table.concat(wer, ", ") .. "." end
    return t
  end
  if e.schritt then return e.n .. " mal " .. ns.RezeptName(e.schritt) .. " selbst herstellen." end
  return ""
end
ns.EintragText = EintragText

-- ---------- Charakterübersicht ----------

function ns.CharakterText()
  local zeilen = {}
  for _, z in ipairs(ns.CharakterZeilen()) do
    local farbe = (RAID_CLASS_COLORS and z.klasse and RAID_CLASS_COLORS[z.klasse] and RAID_CLASS_COLORS[z.klasse].colorStr)
    local name = farbe and ("|c" .. farbe .. z.name .. "|r") or (F.gold .. z.name .. "|r")
    zeilen[#zeilen + 1] = name .. "\n  " .. z.berufe .. F.grau .. "  ·  " .. z.rezepte .. " Rezepte gelernt|r"
  end
  return table.concat(zeilen, "\n\n")
end

-- ---------- Seitenleiste ----------

local function BerufeMenue(anker)
  local e = {}
  for _, b in ipairs(D.berufe) do
    local c = ns.char.berufe[b.id]
    e[#e + 1] = { b.name .. (c and ("  " .. F.grau .. (c.stufe or 0) .. "|r") or ""), function() ns.SeiteZeigen("rezepte", b.id) end }
  end
  return S.Menue(anker, e)
end

local function LeisteEintraege()
  local gruppen = {}
  gruppen[1] = { kopf = "Werkstatt",
    { seite = "uebersicht", text = "Übersicht" },
    { seite = "auftraege", text = "Aufträge" },
    { seite = "preise", text = "Preise und Vorrat" },
    { seite = "ziele", text = "Ziele und Erfolge" } }
  local berufe = { kopf = "Berufe" }
  for _, b in ipairs(D.berufe) do berufe[#berufe + 1] = { seite = "rezepte", beruf = b.id, text = b.name } end
  berufe[#berufe + 1] = { text = "Alle Berufe …", aktion = function(k) BerufeMenue(k) end, alle = true }
  gruppen[2] = berufe
  gruppen[3] = { kopf = "Planen",
    { seite = "charaktere", text = "Charaktere" },
    { seite = "abklingzeiten", text = "Abklingzeiten" },
    { seite = "statistik", text = "Statistik" },
    { seite = "sammlung", text = "Sammlung" },
    { seite = "austausch", text = "Austausch mit foreverui.de" } }
  gruppen[4] = { kopf = "Zugang",
    { seite = "barrierefreiheit", text = "Barrierefreiheit" },
    { seite = "funktionen", text = "Funktionen" },
    { seite = "darstellung", text = "Darstellung" },
    { seite = "meldungen", text = "Meldungen" } }
  gruppen[5] = { kopf = "Hilfe",
    { seite = "neuigkeiten", text = "Neuigkeiten" },
    { seite = "bedienung", text = "Bedienung" },
    { seite = "discord", text = "Discord und Feedback" },
    { seite = "fehler", text = "Fehler und Diagnose" },
    { text = "Assistent starten", aktion = function() ns.AssistentStarten() end } }
  return gruppen
end

local function EintragAktiv(e)
  return e.seite ~= nil and e.seite == ui.seite and (not e.beruf or e.beruf == ui.beruf)
end

-- In der Seitenleiste stehen nur die eigenen Berufe und der gerade gewählte,
-- alle anderen erreicht man über „Alle Berufe …“. So passt alles ins Fenster.
local function Sichtbar(e)
  if not e.beruf then return true end
  return ns.char.berufe[e.beruf] ~= nil or e.beruf == ui.beruf
end
ns.LeisteSichtbar = Sichtbar

-- Nächster oder voriger Eintrag der Seitenleiste (Tab, Pfeile)
function ns.LeisteSchritt(schritt)
  local alle = ui.leisteEintraege
  local idx = 1
  for i, e in ipairs(alle) do if EintragAktiv(e) then idx = i end end
  repeat idx = (idx - 1 + schritt) % #alle + 1 until alle[idx].seite and Sichtbar(alle[idx])
  ns.SeiteZeigen(alle[idx].seite, alle[idx].beruf)
  return alle[idx]
end

-- Alle Seiten als Menü (im kompakten Modus statt der Seitenleiste)
function ns.SeitenMenue(anker)
  local e = {}
  for _, x in ipairs(ui.leisteEintraege) do
    if Sichtbar(x) then
      e[#e + 1] = { x.text, function()
        if x.aktion then return x.aktion(anker) end
        ns.SeiteZeigen(x.seite, x.beruf)
      end }
    end
  end
  return S.Menue(anker, e)
end

local function LeisteAnordnen()
  local y = -8
  for _, g in ipairs(ui.leisteGruppen) do
    g.kopfText:ClearAllPoints()
    g.kopfText:SetPoint("TOPLEFT", ui.leiste, "TOPLEFT", 10, y)
    y = y - 18
    for _, k in ipairs(g.knoepfe) do
      if Sichtbar(k.eintrag) then
        k:ClearAllPoints()
        k:SetPoint("TOPLEFT", ui.leiste, "TOPLEFT", 4, y)
        k:SetPoint("RIGHT", ui.leiste, "RIGHT", -4, 0)
        k:Show()
        y = y - 16
      else
        k:Hide()
      end
    end
    y = y - 8
  end
end

local function BaueLeiste(f)
  local leiste = CreateFrame("Frame", nil, f)
  ui.leiste = leiste
  leiste:SetPoint("TOPLEFT", 12, -72)
  leiste:SetPoint("BOTTOMLEFT", 12, 44)
  leiste:SetWidth(LEISTE_B)
  leiste.hg = S.Flaeche(leiste, S.HG[1], S.HG[2], S.HG[3], 0.5)
  ui.leisteEintraege, ui.leisteKnoepfe, ui.leisteGruppen = {}, {}, {}
  for _, g in ipairs(LeisteEintraege()) do
    local kopf = leiste:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    kopf:SetText(g.kopf:upper())
    S.AkzentText(kopf)
    local gruppe = { kopfText = kopf, knoepfe = {} }
    ui.leisteGruppen[#ui.leisteGruppen + 1] = gruppe
    for _, e in ipairs(g) do
      local k = CreateFrame("Button", nil, leiste)
      k:SetHeight(16)
      S.Zeile(k)
      k.text = k:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      k.text:SetPoint("LEFT", 10, 0)
      k.text:SetJustifyH("LEFT")
      k.rechts = k:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      k.rechts:SetPoint("RIGHT", -4, 0)
      k.eintrag = e
      k:SetScript("OnClick", function(self)
        if e.aktion then return e.aktion(self) end
        ui.assistent = nil
        ns.SeiteZeigen(e.seite, e.beruf)
        ns.Sprechen(e.text)
      end)
      if e.beruf then
        k:SetScript("OnEnter", function(self)
          local b = ns.beruf[e.beruf]
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText(b.name, 1, 1, 1)
          GameTooltip:AddLine(b.anzahl .. " Rezepte", 0.55, 0.55, 0.55)
          local c = ns.char.berufe[b.id]
          if c then
            GameTooltip:AddLine("Deine Stufe: " .. (c.stufe or 0) .. "/" .. (c.max or 0), 0.45, 0.85, 0.45)
            local naechste = ns.NaechsteStufe and ns.NaechsteStufe(c.stufe)
            if naechste then GameTooltip:AddLine("Noch " .. (naechste - (c.stufe or 0)) .. " bis " .. naechste, 0.55, 0.55, 0.55) end
          end
          local wer = {}
          for _, x in pairs(ns.db.chars) do
            if x ~= ns.char and x.berufe and x.berufe[b.id] then wer[#wer + 1] = (x.name or "?") .. " " .. (x.berufe[b.id].stufe or 0) end
          end
          table.sort(wer)
          if #wer > 0 then GameTooltip:AddLine("Andere Charaktere: " .. table.concat(wer, ", "), 0.55, 0.55, 0.55, true) end
          GameTooltip:Show()
        end)
        k:SetScript("OnLeave", function() GameTooltip:Hide() end)
      elseif e.alle then
        Tipp(k, "Alle Berufe", "Hier stehen nur die Berufe deines Charakters. Alle zwölf Berufe erreichst du über dieses Menü.")
      end
      ui.leisteEintraege[#ui.leisteEintraege + 1] = e
      ui.leisteKnoepfe[#ui.leisteKnoepfe + 1] = k
      gruppe.knoepfe[#gruppe.knoepfe + 1] = k
    end
  end

  local version = leiste:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", 10, 8)
  local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local v = GetMeta and GetMeta("Werkbank", "Version")
  if not v or v:find("@", 1, true) then v = "Entwicklung" end
  version:SetText("Version " .. v)
end

local function LeisteNeu()
  LeisteAnordnen()
  for _, k in ipairs(ui.leisteKnoepfe) do
    local e = k.eintrag
    k:Gewaehlt(EintragAktiv(e))
    if e.beruf then
      local c = ns.char.berufe[e.beruf]
      k.text:SetText((c and F.weiss or F.grau) .. e.text .. "|r")
      k.rechts:SetText(c and tostring(c.stufe or 0) or "")
    elseif e.seite == "auftraege" then
      k.text:SetText(F.weiss .. e.text .. "|r")
      local n = ns.AuftraegeSortiert and #ns.AuftraegeSortiert("frist") or 0
      k.rechts:SetText(n > 0 and tostring(n) or "")
    else
      k.text:SetText((e.alle and F.grau or F.weiss) .. e.text .. "|r")
    end
  end
end

-- ---------- Seiten im Inhaltskasten ----------

ui.seiten = {}

local function Seite(name, titel, neu)
  local p = CreateFrame("Frame", nil, ui.inhalt)
  p:SetPoint("TOPLEFT", 12, -12)
  p:SetPoint("BOTTOMRIGHT", -12, 12)
  p:Hide()
  p.titel = titel
  p.Neu = neu
  ui.seiten[name] = p
  return p
end

-- Überschrift und graue Erklärung oben auf einer Seite
local function Ueberschrift(p, text, erklaerung, y)
  local h = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h:SetPoint("TOPLEFT", 0, y or 0)
  h:SetText(text)
  if erklaerung then
    local e = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    e:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)
    e:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    e:SetJustifyH("LEFT")
    e:SetText(erklaerung)
    return h, e
  end
  return h
end

-- Langer Text mit Bildlauf
local function TextSeite(name, titel, textFn)
  local p = Seite(name, titel)
  local scroll = CreateFrame("ScrollFrame", "WerkbankSeite_" .. name, p, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  local inhalt = CreateFrame("Frame", nil, scroll)
  inhalt:SetSize(500, 10)
  scroll:SetScrollChild(inhalt)
  local text = inhalt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOPLEFT")
  text:SetJustifyH("LEFT")
  text:SetSpacing(2)
  p.text = text
  p.scroll = scroll
  p.Neu = function()
    local w = scroll:GetWidth()
    if w and w > 50 then
      inhalt:SetWidth(w)
      text:SetWidth(w - 4)
    else
      text:SetWidth(500)
    end
    text:SetText(textFn())
    inhalt:SetHeight((text.GetStringHeight and text:GetStringHeight() or 10) + 10)
  end
  p.Vorlesen = textFn
  return p
end

-- Schalter im ForeverUI-Stil „Klar“ (statt Häkchen): Spur in Akzentfarbe, wenn an, weißer Knopf wandert
-- nach rechts. Verhält sich wie ein CheckButton (SetChecked, GetChecked, OnClick schaltet vorher um).
local function Umschalter(eltern)
  local c = CreateFrame("Button", nil, eltern)
  c:SetSize(34, 18)
  local spur = c:CreateTexture(nil, "BACKGROUND")
  spur:SetAllPoints()
  local knopf = c:CreateTexture(nil, "ARTWORK")
  knopf:SetSize(14, 14)
  knopf:SetColorTexture(1, 1, 1, 1)
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  c.an = false
  c.SetChecked = function(self, an)
    self.an = an and true or false
    knopf:ClearAllPoints()
    if self.an then
      local a = ns.Akzent
      spur:SetColorTexture(a[1], a[2], a[3], 1)
      knopf:SetPoint("RIGHT", -2, 0)
    else
      spur:SetColorTexture(1, 1, 1, 0.18)
      knopf:SetPoint("LEFT", 2, 0)
    end
  end
  c.GetChecked = function(self) return self.an end
  local setze = c.SetScript
  c.SetScript = function(self, name, fn)
    if name == "OnClick" and fn then
      return setze(self, name, function(s, ...) s:SetChecked(not s.an); return fn(s, ...) end)
    end
    return setze(self, name, fn)
  end
  c:SetChecked(false)
  return c
end

-- Schalter mit Titel und Erklärung in zwei Spalten, dazu „Seite zurücksetzen“
local function SchalterSeite(name, titel, schalter)
  local p = Seite(name, titel)
  p.kaesten = {}
  for i, opt in ipairs(schalter) do
    local spalte, zeile = (i - 1) % 2, math.floor((i - 1) / 2)
    local feld = CreateFrame("Frame", nil, p)
    feld:SetHeight(56)
    feld:SetPoint("TOPLEFT", p, spalte == 0 and "TOPLEFT" or "TOP", spalte == 0 and 0 or 6, -zeile * 62)
    feld:SetPoint("RIGHT", p, spalte == 0 and "CENTER" or "RIGHT", spalte == 0 and -6 or 0, 0)
    local cb = Umschalter(feld)
    cb:SetPoint("TOPLEFT", 0, -2)
    local t = feld:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 42, -4)
    t:SetPoint("RIGHT", feld, "RIGHT", 0, 0)
    t:SetJustifyH("LEFT")
    t:SetText(opt[2])
    local e = feld:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    e:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -3)
    e:SetPoint("RIGHT", feld, "RIGHT", 0, 0)
    e:SetJustifyH("LEFT")
    e:SetText(opt[3])
    cb:SetScript("OnClick", function(self)
      local an = self:GetChecked() and true or false
      if opt.setzen then opt.setzen(an) else ns.db.optionen[opt[1]] = an end
      if opt.danach then opt.danach(an) end
      ns.FarbenAnwenden()
      ns.Aktualisieren()
      ns.Sprechen(opt[2] .. (an and " an." or " aus."), true)
    end)
    Tipp(cb, opt[2], opt[3])
    cb.opt = opt
    p.kaesten[#p.kaesten + 1] = cb
  end
  p.Neu = function()
    for _, cb in ipairs(p.kaesten) do
      local o = cb.opt
      cb:SetChecked((o.lesen and o.lesen() or ns.db.optionen[o[1]]) and true or false)
    end
  end
  local zurueck = Knopf(p, "Seite zurücksetzen", 150)
  zurueck:SetPoint("BOTTOMRIGHT", 0, 0)
  zurueck:SetScript("OnClick", function()
    for _, o in ipairs(schalter) do
      local std = ns.STANDARD[o[1]]
      if o.setzen then o.setzen(o.standard or false) else ns.db.optionen[o[1]] = std end
      if o.danach then o.danach(ns.db.optionen[o[1]]) end
    end
    ns.FarbenAnwenden()
    ns.Aktualisieren()
    ns.Print("Seite „" .. titel .. "“ zurückgesetzt.")
    ns.Sprechen("Seite zurückgesetzt.", true)
  end)
  Tipp(zurueck, "Seite zurücksetzen", "Stellt alle Schalter dieser Seite auf die Grundeinstellung.")
  return p
end

-- Auswahl als Karten mit Titel und grauer Beschreibung
local function Karten(p, y, spalten, eintraege, gewaehlt, waehlen)
  local karten = {}
  for i, k in ipairs(eintraege) do
    local sp, z = (i - 1) % spalten, math.floor((i - 1) / spalten)
    local c = CreateFrame("Button", nil, p)
    c:SetHeight(52)
    c.hg = S.Flaeche(c, S.HG[1], S.HG[2], S.HG[3], 0.35)
    S.Rand(c, 0.08)
    S.Zeile(c)
    c.zebra:Hide()
    c.titel = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    c.titel:SetPoint("TOPLEFT", 12, -10)
    c.titel:SetText(k.titel)
    c.text = c:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    c.text:SetPoint("TOPLEFT", c.titel, "BOTTOMLEFT", 0, -4)
    c.text:SetPoint("RIGHT", c, "RIGHT", -8, 0)
    c.text:SetJustifyH("LEFT")
    c.text:SetText(k.text)
    if k.farbe then
      local muster = c:CreateTexture(nil, "ARTWORK")
      muster:SetSize(12, 12)
      muster:SetPoint("TOPRIGHT", -10, -10)
      muster:SetColorTexture(k.farbe[1], k.farbe[2], k.farbe[3], 1)
    end
    c:SetScript("OnClick", function()
      waehlen(k)
      ns.Sprechen(k.titel .. " gewählt.", true)
    end)
    c.wert = k
    karten[i] = c
  end
  function karten.Anordnen()
    local w = p:GetWidth()
    if not w or w < 100 then w = 560 end
    local kw = (w - (spalten - 1) * 8) / spalten
    for i, c in ipairs(karten) do
      local sp, z = (i - 1) % spalten, math.floor((i - 1) / spalten)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", sp * (kw + 8), y - z * 60)
      c:SetWidth(kw)
      c:Gewaehlt(gewaehlt(c.wert))
    end
  end
  return karten
end

-- ---------- Seite: Rezeptbuch und Einkaufsliste ----------

local function BaueRezeptSeite()
  local p = Seite("rezepte")
  ui.kopf = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  ui.kopf:SetPoint("TOPLEFT", 4, -2)
  ui.kopf:SetJustifyH("LEFT")

  ui.buch = Liste(p, ZeichneRezept, KlickRezept, EnterRezept)
  ui.buch:SetPoint("TOPLEFT", 0, -26)
  ui.buch:SetPoint("BOTTOMLEFT", 0, 0)
  ui.buch:SetWidth(420)

  local trenner = p:CreateTexture(nil, "ARTWORK")
  trenner:SetColorTexture(1, 1, 1, 0.08)
  trenner:SetWidth(1)
  trenner:SetPoint("TOPLEFT", ui.buch, "TOPRIGHT", 6, 26)
  trenner:SetPoint("BOTTOMLEFT", ui.buch, "BOTTOMRIGHT", 6, 0)

  -- Kopf der Einkaufsliste: Name (Klick zum Umbenennen) und Knöpfe für mehrere Listen
  local naechste = Knopf(p, ">", 24)
  naechste:SetPoint("TOPRIGHT", 0, 2)
  naechste:SetScript("OnClick", function() ns.ListeBlaettern(1) ns.Sprechen("Liste " .. (ns.L.name or "")) end)
  Tipp(naechste, "Nächste Liste")
  local vorige = Knopf(p, "<", 24)
  vorige:SetPoint("RIGHT", naechste, "LEFT", -2, 0)
  vorige:SetScript("OnClick", function() ns.ListeBlaettern(-1) ns.Sprechen("Liste " .. (ns.L.name or "")) end)
  Tipp(vorige, "Vorige Liste")
  local neueListe = Knopf(p, "+", 24)
  neueListe:SetPoint("RIGHT", vorige, "LEFT", -2, 0)
  neueListe:SetScript("OnClick", function() ns.ListeNeu() ns.Sprechen("Neue Liste " .. (ns.L.name or "")) end)
  Tipp(neueListe, "Neue Liste", "Legt eine weitere, leere Einkaufsliste an.")

  local titelKnopf = CreateFrame("Button", nil, p)
  titelKnopf:SetHeight(20)
  titelKnopf:SetPoint("TOPLEFT", ui.buch, "TOPRIGHT", 16, 24)
  titelKnopf:SetPoint("RIGHT", neueListe, "LEFT", -6, 0)
  ui.listeTitel = titelKnopf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ui.listeTitel:SetPoint("LEFT", 0, 0)
  ui.listeTitel:SetPoint("RIGHT", 0, 0)
  ui.listeTitel:SetJustifyH("LEFT")
  ui.listeTitel:SetWordWrap(false)
  S.AkzentText(ui.listeTitel)
  titelKnopf:SetScript("OnClick", function(self) ns.ListenMenue(self) end)
  Tipp(titelKnopf, "Einkaufsliste", "Klick: Menü mit Umbenennen, Kopieren, Zusammenführen, von anderen Charakteren übernehmen und Löschen.")
  ui.titelKnopf = titelKnopf

  local sortieren = Knopf(p, "Nach: " .. SORTIERUNG[1], 134)
  sortieren:SetPoint("BOTTOMRIGHT", ui.buch, "TOPRIGHT", -24, 4)
  sortieren:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  sortieren:SetScript("OnClick", function(self, btn)
    ui.sortierung = (ui.sortierung - 1 + (btn == "RightButton" and -1 or 1)) % #SORTIERUNG + 1
    self:SetText("Nach: " .. SORTIERUNG[ui.sortierung])
    ns.Sprechen("Sortierung " .. SORTIERUNG[ui.sortierung])
    Neu()
  end)
  Tipp(sortieren, "Sortierung", "Nach Kategorie, Name, Schwierigkeit (orange zuerst) oder danach, wie oft du es mit deinem Vorrat herstellen kannst.")
  ui.sortKnopf = sortieren
  local zufall = Knopf(p, "Zufall", 64)
  zufall:SetPoint("RIGHT", sortieren, "LEFT", -4, 0)
  zufall:SetScript("OnClick", function()
    local rid, jetzt = ns.Ueberrasch(ui.beruf)
    if rid then
      ns.Print((jetzt and "Wie wär's mit " or "Vielleicht ") .. ns.RezeptName(rid) .. (jetzt and "? Die Materialien hast du." or "?"))
      ns.RezeptZeigen(rid)
    end
  end)
  Tipp(zufall, "Überrasch mich", "Schlägt ein zufälliges Rezept vor, am liebsten eins, das du mit deinem Vorrat gleich herstellen kannst.")

  local nameBox = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
  nameBox:SetAllPoints(titelKnopf)
  nameBox:SetAutoFocus(false)
  nameBox:Hide()
  nameBox:SetScript("OnEnterPressed", function(self)
    local name = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name ~= "" then ns.ListeUmbenennen(name:sub(1, 40)) end
    self:Hide()
  end)
  nameBox:SetScript("OnEscapePressed", function(self) self:Hide() end)
  nameBox:SetScript("OnEditFocusLost", function(self) self:Hide() end)
  ui.nameBox = nameBox

  ui.liste = Liste(p, ZeichneListe, KlickListe, EnterListe)
  ui.liste:SetPoint("TOPLEFT", ui.buch, "TOPRIGHT", 14, 0)
  ui.liste:SetPoint("BOTTOMRIGHT", 0, 30)

  -- Fortschrittsbalken: wie viel der Materialien schon da ist
  local spur = p:CreateTexture(nil, "ARTWORK")
  spur:SetPoint("BOTTOMLEFT", ui.liste, "TOPLEFT", 0, 2)
  spur:SetPoint("BOTTOMRIGHT", ui.liste, "TOPRIGHT", -26, 2)
  spur:SetHeight(2)
  spur:SetColorTexture(1, 1, 1, 0.08)
  ui.balken = p:CreateTexture(nil, "OVERLAY")
  ui.balken:SetPoint("BOTTOMLEFT", ui.liste, "TOPLEFT", 0, 2)
  ui.balken:SetHeight(2)
  S.AkzentFlaeche(ui.balken, 1)

  local leeren = Knopf(p, "Leeren", 66)
  leeren:SetPoint("BOTTOMRIGHT", 0, 0)
  leeren:SetScript("OnClick", function()
    if IsShiftKeyDown() and IsControlKeyDown() then
      local alt = ns.L.name
      ns.ListeLoeschen()
      ns.Print("Liste „" .. (alt or "") .. "“ gelöscht.")
    elseif IsShiftKeyDown() then
      ns.ListeLeeren()
    else
      ns.Print("Zum Leeren Umschalt gedrückt halten und klicken, zum Löschen der ganzen Liste Strg und Umschalt.")
    end
  end)
  Tipp(leeren, "Liste leeren", "Umschalt-Klick leert die Einkaufsliste.", "Strg-Umschalt-Klick löscht die ganze Liste (die letzte wird nur geleert).")
  local vorlesen = Knopf(p, "Vorlesen", 76)
  vorlesen:SetPoint("RIGHT", leeren, "LEFT", -4, 0)
  vorlesen:SetScript("OnClick", ns.ListeVorlesen)
  Tipp(vorlesen, "Einkaufsliste vorlesen", "Liest vor, was hergestellt wird und was noch fehlt.")
  local teilen = Knopf(p, "Chat", 56)
  teilen:SetPoint("RIGHT", vorlesen, "LEFT", -4, 0)
  local zurueck = Knopf(p, "Rückgängig", 90)
  zurueck:SetPoint("RIGHT", teilen, "LEFT", -4, 0)
  zurueck:SetScript("OnClick", function() ns.Rueckgaengig() end)
  Tipp(zurueck, "Rückgängig", "Nimmt die letzte Änderung an der Einkaufsliste zurück (bis zu 30 Schritte). Auch mit Strg+Z.")
  teilen:SetScript("OnClick", function() ns.ChatTeilen() end)
  Tipp(teilen, "Fehlendes teilen", "Schreibt die fehlenden Materialien in den Gruppen- oder Schlachtzugschat.", "Gilde: /wb chat gilde")

  p.Neu = function()
    local o = ns.db.optionen
    ui.buch.aktiv = o.tastatur and ui.aktiv ~= "liste"
    ui.liste.aktiv = o.tastatur and ui.aktiv == "liste"
    ui.buch.eintraege = RezeptbuchEintraege()
    ui.buch:Neu()
    ui.liste.eintraege = ListeEintraege()
    ui.liste:Neu()
    local b = ns.beruf[ui.beruf]
    local c = b and ns.char.berufe[b.id]
    local gelernt = 0
    if b then
      for _, k in ipairs(b.kat) do
        for _, rid in ipairs(k[2]) do
          if ns.char.bekannt[rid] then gelernt = gelernt + 1 end
        end
      end
    end
    local text = c and (F.weiss .. "Stufe " .. (c.stufe or 0) .. "/" .. (c.max or 0) .. "|r  ") or (F.grau .. "nicht erlernt|r  ")
    if b then text = text .. F.grau .. gelernt .. "/" .. b.anzahl .. " gelernt|r" end
    local naechste = c and ns.NaechsteStufe and ns.NaechsteStufe(c.stufe)
    if naechste then text = text .. F.grau .. "  ·  noch " .. (naechste - (c.stufe or 0)) .. " bis " .. naechste .. "|r" end
    ui.kopf:SetText(text)
    local ort = ns.ListenOrt()
    ui.listeTitel:SetText((ns.L.name or "Liste") .. (o.gemeinsam and " (gemeinsam)" or "")
      .. (#ort.listen > 1 and (F.grau .. "  " .. ort.aktiv .. "/" .. #ort.listen .. "|r") or ""))
    p.titel = (ui.ueberall and (ui.suche:GetText() or "") ~= "") and "Suche in allen Berufen" or (b and b.name or "Rezeptbuch")
    local anteil = ns.ListeFortschritt()
    local w = ui.liste:GetWidth()
    if not w or w < 50 then w = 300 end
    ui.balken:SetShown(anteil ~= nil and anteil > 0)
    ui.balken:SetWidth(math.max(1, (w - 26) * (anteil or 0)))
    if anteil then
      ui.listeTitel:SetText(ui.listeTitel:GetText() .. "  " .. F.grau .. math.floor(anteil * 100 + 0.5) .. " %|r")
    end
  end
end

-- Menü am Listennamen
function ns.ListenMenue(anker)
  local e = {
    { "Umbenennen", function() ns.UmbenennenDialog() end },
    { "Neue Liste", function() ns.ListeNeu() end },
    { "Liste kopieren", function() ns.ListeKopieren() end },
    { "Alle Listen zusammenführen", function() ns.ListenZusammenfuehren() end, grau = #ns.ListenOrt().listen < 2 },
    { "Rückgängig", function() ns.Rueckgaengig() end, grau = not ns.KannRueckgaengig() },
  }
  for _, c in ipairs(ns.TwinksMitListe()) do
    e[#e + 1] = { "Liste von " .. c.name .. " übernehmen", function() ns.TwinkListeUebernehmen(c.name) end }
  end
  local typ = ns.db.optionen.gruppierung == "typ"
  e[#e + 1] = { typ and "Materialien nach Quelle ordnen" or "Materialien nach Art ordnen", function()
    ns.db.optionen.gruppierung = not typ and "typ" or nil
    ns.Aktualisieren()
  end }
  e[#e + 1] = { "Als Vorlage speichern", function() ns.VorlageSpeichern(ns.L.name) end }
  for _, name in ipairs(ns.Vorlagen()) do
    e[#e + 1] = { "Neue Liste aus Vorlage „" .. name .. "“", function() ns.VorlageLaden(name) end }
  end
  e[#e + 1] = { "Offene Aufträge hinzufügen", function() ns.AuftraegeAufListe() end }
  e[#e + 1] = { "Mindestbestände auffüllen", function() ns.MindestAufListe() end }
  e[#e + 1] = { "Liste löschen", function()
    local alt = ns.L.name
    ns.ListeLoeschen()
    ns.Print("Liste „" .. (alt or "") .. "“ gelöscht.")
  end }
  return S.Menue(anker or ui.titelKnopf, e)
end

-- ---------- Seite: Charaktere ----------

local function BaueCharakterSeite()
  local p = TextSeite("charaktere", "Deine Charaktere", function()
    return ns.CharakterText() .. "\n\n" .. F.gold .. "Gold auf diesem Realm:|r " .. ns.Geld(ns.GoldSumme())
      .. "\n\n" .. F.gold .. "Berufe im Vergleich|r\n" .. ns.BerufeTabelle()
      .. "\n\n" .. F.grau .. "Jeder Charakter wird beim Einloggen erfasst, Taschen sofort, die Bank beim nächsten Besuch. Entfernen: /wb vergessen Name|r"
  end)
  TextSeite("abklingzeiten", "Abklingzeiten", function()
    return ns.AbklingText() .. "\n\n" .. F.grau .. "Transmutationen und Mondstoff aller Charaktere. Ist eine Abklingzeit vorbei, meldet die Werkbank das im Chat (abschaltbar unter Funktionen).|r"
  end)
  TextSeite("statistik", "Statistik", function() return ns.StatistikText() .. "\n\n" .. ns.AuswertungText() end)
  TextSeite("sammlung", "Sammlung", function()
    return ns.SammlungText() .. "\n" .. F.grau .. "Wie viele Rezepte jeder deiner Charaktere schon gelernt hat.|r"
  end)
  return p
end

-- ---------- Seite: Rezept im Detail ----------

local function DetailText()
  local rid = ui.detail
  local r = rid and D.rezepte[rid]
  if not r then return "" end
  local z = {}
  local b = ns.berufOf[rid]
  z[#z + 1] = F.gold .. (b and b.name or "") .. "|r  ·  " .. (ns.katOf[rid] or "")
  local sw = ns.char.bekannt[rid] and ns.SCHWIERIGKEIT[ns.char.schwierigkeit[rid] or ""]
  if sw then z[#z + 1] = "Schwierigkeit: " .. sw[2] .. sw[1] .. "|r" end
  local m = r[3]
  if type(m) == "table" then z[#z + 1] = "Ergibt " .. m[1] .. " bis " .. m[2] .. " Stück"
  elseif m and m > 1 then z[#z + 1] = "Ergibt " .. m .. " Stück" end
  z[#z + 1] = ""
  z[#z + 1] = F.gold .. "Zutaten|r"
  local zu = r[4]
  for i = 1, #zu, 2 do
    local id, n = zu[i], zu[i + 1]
    local hat = ns.Vorrat(id)
    local t = "  " .. n .. "× " .. ns.QualitaetFarbe(id) .. ns.ItemName(id) .. "|r – du hast " .. hat
    if hat < n then t = t .. F.rot .. " (fehlt " .. (n - hat) .. ")|r" else t = t .. F.gruen .. " (da)|r" end
    local summe = ns.TwinkVorrat(id)
    if summe > 0 then t = t .. F.grau .. ", Twinks " .. summe .. "|r" end
    local h = ns.HaendlerInfo(id)
    if h then t = t .. F.grau .. ", Händler " .. ns.Geld(math.ceil(h.preis)) .. "|r" end
    z[#z + 1] = t
  end
  local moeglich = ns.Moeglich(rid)
  z[#z + 1] = "  " .. (moeglich > 0 and (F.gruen .. "Mit deinem Vorrat " .. moeglich .. "× möglich|r") or (F.grau .. "Mit deinem Vorrat noch nicht möglich|r"))
  local extras = ns.RezeptExtras and ns.RezeptExtras(rid) or {}
  if #extras > 0 then
    z[#z + 1] = ""
    z[#z + 1] = F.gold .. "Kosten, Quellen und mehr|r"
    for _, x in ipairs(extras) do z[#z + 1] = "  " .. x end
  end
  z[#z + 1] = ""
  local kenner = ns.Kenner(rid)
  z[#z + 1] = F.gold .. "Gelernt von|r " .. (#kenner > 0 and table.concat(kenner, ", ") or F.grau .. "keinem deiner Charaktere|r")
  if b then
    local koennten = {}
    for _, c in pairs(ns.db.chars) do
      if c.berufe and c.berufe[b.id] and not (c.bekannt and c.bekannt[rid]) then
        koennten[#koennten + 1] = (c.name or "?") .. " (" .. (c.berufe[b.id].stufe or 0) .. ")"
      end
    end
    table.sort(koennten)
    if #koennten > 0 then z[#z + 1] = F.gold .. "Könnte lernen|r " .. table.concat(koennten, ", ") end
  end
  local used = r[2] and ns.usedIn[r[2]]
  if used then
    local namen = {}
    for i, x in ipairs(used) do
      if i > 15 then
        namen[#namen + 1] = "und " .. (#used - 15) .. " weitere"
        break
      end
      namen[#namen + 1] = ns.RezeptName(x)
    end
    z[#z + 1] = ""
    z[#z + 1] = F.gold .. "Verwendet in|r " .. table.concat(namen, ", ")
  end
  local anz = ns.L.liste[rid]
  if anz then z[#z + 1] = "" z[#z + 1] = F.gold .. anz .. "×|r auf der Liste „" .. (ns.L.name or "") .. "“" end
  local hergestellt = ns.db.statistik and r[2] and ns.db.statistik.gesamt[r[2]]
  if hergestellt then z[#z + 1] = F.grau .. "Schon " .. hergestellt .. "× hergestellt|r" end
  return table.concat(z, "\n")
end

local function BaueDetailSeite()
  local p = TextSeite("rezept", "Rezept", DetailText)
  p.scroll:SetPoint("BOTTOMRIGHT", -26, 84)

  local notiz = CreateFrame("EditBox", "WerkbankNotiz", p, "InputBoxTemplate")
  notiz:SetHeight(20)
  notiz:SetPoint("BOTTOMLEFT", 6, 40)
  notiz:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  notiz:SetAutoFocus(false)
  notiz:SetMaxLetters(120)
  local label = notiz:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetPoint("BOTTOMLEFT", notiz, "TOPLEFT", -4, 2)
  label:SetText("Notiz (erscheint im Tooltip, z. B. „für Gildenkollegen“)")
  local function NotizSpeichern(self)
    local t = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ns.db.notizen = ns.db.notizen or {}
    ns.db.notizen[ui.detail] = t ~= "" and t or nil
    self:ClearFocus()
  end
  notiz:SetScript("OnEnterPressed", NotizSpeichern)
  notiz:SetScript("OnEditFocusLost", NotizSpeichern)
  notiz:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ui.notizBox = notiz

  local anzahl = CreateFrame("EditBox", "WerkbankAnzahl", p, "InputBoxTemplate")
  anzahl:SetSize(44, 20)
  anzahl:SetPoint("BOTTOMLEFT", 6, 1)
  anzahl:SetAutoFocus(false)
  anzahl:SetNumeric(true)
  anzahl:SetMaxLetters(3)
  local setzen = Knopf(p, "Auf die Liste", 110)
  setzen:SetPoint("LEFT", anzahl, "RIGHT", 6, 0)
  local function Setzen()
    local n = tonumber(anzahl:GetText()) or 0
    ns.ListeSetzen(ui.detail, n)
    ns.Print(n > 0 and (n .. "× " .. ns.RezeptName(ui.detail) .. " auf der Liste.") or (ns.RezeptName(ui.detail) .. " von der Liste genommen."))
    anzahl:ClearFocus()
  end
  setzen:SetScript("OnClick", Setzen)
  anzahl:SetScript("OnEnterPressed", Setzen)
  Tipp(setzen, "Anzahl setzen", "Setzt genau diese Anzahl auf die aktive Liste. 0 nimmt das Rezept herunter.")
  ui.anzahlBox = anzahl

  local fav = Knopf(p, "Favorit", 80)
  fav:SetPoint("LEFT", setzen, "RIGHT", 4, 0)
  fav:SetScript("OnClick", function() ns.FavoritUmschalten(ui.detail) end)
  local zeigen = Knopf(p, "Im Berufsfenster", 120)
  zeigen:SetPoint("LEFT", fav, "RIGHT", 4, 0)
  zeigen:SetScript("OnClick", function() ns.ImBerufsfensterZeigen(ui.detail) end)
  Tipp(zeigen, "Im Berufsfenster zeigen", "Wählt das Rezept im offenen Berufsfenster aus.")
  local auftrag = Knopf(p, "Auftrag", 80)
  auftrag:SetPoint("LEFT", zeigen, "RIGHT", 4, 0)
  auftrag:SetScript("OnClick", function() ns.AuftragVorbereiten(ui.detail, tonumber(anzahl:GetText()) or 1) end)
  Tipp(auftrag, "Kundenauftrag", "Legt für dieses Rezept einen Auftrag an. Nur noch den Kunden eintragen.")
  local vergleichen = Knopf(p, "Vergleichen", 100)
  vergleichen:SetPoint("LEFT", auftrag, "RIGHT", 4, 0)
  vergleichen:SetScript("OnClick", function() ns.VergleichMerken(ui.detail) end)
  Tipp(vergleichen, "Rezepte vergleichen", "Erst bei einem Rezept drücken, dann beim zweiten. Beide stehen danach nebeneinander mit Zutaten, Kosten und Gewinn.")
  local zurueck = Knopf(p, "Zurück", 80)
  zurueck:SetPoint("BOTTOMRIGHT", 0, 0)
  zurueck:SetScript("OnClick", function() ns.SeiteZeigen("rezepte") end)

  local alt = p.Neu
  p.Neu = function()
    alt()
    p.titel = ui.detail and ns.RezeptName(ui.detail) or "Rezept"
    if not notiz:HasFocus() then notiz:SetText(ns.db.notizen and ns.db.notizen[ui.detail] or "") end
    if not anzahl:HasFocus() then anzahl:SetText(tostring(ns.L.liste[ui.detail] or 1)) end
    fav:SetText(ns.db.favoriten[ui.detail] and "Kein Favorit" or "Favorit")
  end
end

function ns.RezeptZeigen(rid)
  if not D.rezepte[rid] then return end
  ui.detail = rid
  ns.SeiteZeigen("rezept")
end

-- Rezept im offenen Berufsfenster auswählen
function ns.ImBerufsfensterZeigen(rid)
  local name = ns.RezeptName(rid)
  if TradeSkillFrame and TradeSkillFrame:IsShown() and GetNumTradeSkills and GetTradeSkillInfo then
    for i = 1, GetNumTradeSkills() do
      if GetTradeSkillInfo(i) == name or GetTradeSkillInfo(i) == D.rezepte[rid][1] then
        if TradeSkillFrame_SetSelection then TradeSkillFrame_SetSelection(i) end
        if TradeSkillFrame_Update then TradeSkillFrame_Update() end
        return true
      end
    end
  end
  if CraftFrame and CraftFrame:IsShown() and GetNumCrafts and GetCraftInfo then
    for i = 1, GetNumCrafts() do
      if GetCraftInfo(i) == D.rezepte[rid][1] then
        if CraftFrame_SetSelection then CraftFrame_SetSelection(i) end
        if CraftFrame_Update then CraftFrame_Update() end
        return true
      end
    end
  end
  ns.Print("Öffne zuerst das Berufsfenster mit diesem Rezept.")
  return false
end

-- ---------- Seite: Austausch mit foreverui.de ----------

local function BaueAustauschSeite()
  local p = Seite("austausch", "Austausch mit foreverui.de")
  Ueberschrift(p, "Liste importieren", "Link aus dem Berufe-Rechner auf foreverui.de einfügen (Strg+V). Die Rezepte kommen zur aktiven Liste dazu.")
  local box = CreateFrame("EditBox", "WerkbankImport", p, "InputBoxTemplate")
  box:SetHeight(20)
  box:SetPoint("TOPLEFT", 6, -50)
  box:SetPoint("RIGHT", p, "RIGHT", -130, 0)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local ok = Knopf(p, "Importieren", 110)
  ok:SetPoint("LEFT", box, "RIGHT", 10, 0)
  local function Import()
    local text = box:GetText() or ""
    if text:match("^WB1|") then
      local n = ns.SicherungLaden(text)
      ns.Print(n .. (n == 1 and " Liste" or " Listen") .. " aus der Sicherung geladen.")
      box:SetText("")
      box:ClearFocus()
      return
    end
    local n = ns.Import(text)
    if n > 0 then
      ns.Print(n .. (n == 1 and " Rezept" or " Rezepte") .. " übernommen.")
      box:SetText("")
      box:ClearFocus()
    else
      ns.Print("In dem Text war kein Rezept zu finden.")
    end
  end
  ok:SetScript("OnClick", Import)
  box:SetScript("OnEnterPressed", Import)
  ui.importBox = box

  Ueberschrift(p, "Liste als Link", "Link markieren und mit Strg+C kopieren. Der Berufe-Rechner hat je Beruf eine eigene Seite.", -96)
  p.boxen = {}
  for i = 1, 4 do
    local k = KopierFeld(p)
    k:SetPoint("TOPLEFT", 6, -160 - (i - 1) * 36)
    k:SetPoint("RIGHT", p, "RIGHT", -6, 0)
    p.boxen[i] = k
  end
  p.text = KopierFeld(p)
  p.text:SetPoint("TOPLEFT", 6, -320)
  p.text:SetPoint("RIGHT", p, "RIGHT", -6, 0)
  p.text.label:SetText("Liste als Text (für Chat, Forum oder Notizen)")
  p.sicherung = KopierFeld(p)
  p.sicherung:SetPoint("TOPLEFT", 6, -366)
  p.sicherung:SetPoint("RIGHT", p, "RIGHT", -6, 0)
  p.sicherung.label:SetText("Sicherung aller Listen (oben bei „Liste importieren“ wieder einfügen)")
  p.leer = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  p.leer:SetPoint("TOPLEFT", 6, -150)
  p.leer:SetText("Die aktive Liste ist leer.")
  p.Neu = function()
    p.text:Fest(ns.TextExport())
    p.sicherung:Fest(ns.SicherungText())
    local links = ns.Export()
    p.leer:SetShown(#links == 0)
    for i, k in ipairs(p.boxen) do
      local l = links[i]
      k:SetShown(l ~= nil)
      if l then
        k.label:SetText(l.beruf.name)
        k:Fest(l.url)
      end
    end
  end
end

-- ---------- Seiten: Barrierefreiheit, Funktionen, Darstellung ----------

local function BaueOptionsSeiten()
  SchalterSeite("barrierefreiheit", "Barrierefreiheit", {
    { "vorlesen", "Vorlesen", "Liest Rezepte, Listeneinträge und Seiten mit der Sprachausgabe des Spiels vor." },
    { "kontrast", "Hoher Kontrast", "Fast undurchsichtige Flächen, weißer Text und hellere Nebentexte." },
    { "farbenblind", "Farbenblind-Modus", "Blau statt Grün und Orange statt Rot. Fehlende Mengen stehen zusätzlich als Wort da." },
    { "groesse", "Alles größer", "Vergrößert die Werkbank auf 125 %. Weitere Stufen unter Darstellung.",
      lesen = function() return ns.Groesse() > 1 end,
      setzen = function(an) ns.db.optionen.groesse = an and 1.25 or 1 end },
    { "wenigerBewegung", "Weniger Bewegung", "Meldungen mitten auf dem Bildschirm bleiben doppelt so lange stehen, nichts blinkt oder gleitet." },
    { "tastatur", "Tastatursteuerung im Fenster", "Pfeile bewegen, Links/Rechts wechselt Rezeptbuch und Liste, Eingabe +1, Rücktaste −1, Tab nächster Eintrag links, Leertaste vorlesen, M Favorit, Strg+F Suche, Esc schließt." },
  })
  SchalterSeite("funktionen", "Funktionen", {
    { "tooltip", "Zeilen in Gegenstands-Tooltips", "Wofür ein Material gebraucht wird, wer es herstellen kann und wie viele deine anderen Charaktere haben." },
    { "tooltipKenner", "Hersteller im Tooltip", "Nennt im Tooltip deine Charaktere, die einen Gegenstand herstellen können." },
    { "gemeinsam", "Eine Einkaufsliste für alle Charaktere", "Alle Charaktere teilen sich dieselben Listen. Aus: jeder Charakter hat eigene.",
      danach = function() ns.ListeWaehlen() end },
    { "abhaken", "Nach dem Herstellen abhaken", "Stellst du etwas von der Liste her, wird es automatisch um eins verringert." },
    { "lootMeldung", "Fortschritt beim Sammeln", "Meldet im Chat, wenn ein Material von der Liste dazukommt, z. B. „Leinenstoff 7/10“." },
    { "fertigMeldung", "Melden, wenn alles da ist", "Meldung, Ton und Sprachausgabe, sobald alle Materialien beisammen sind." },
    { "minimap", "Knopf an der Minikarte", "Klick öffnet die Werkbank, Rechtsklick die Optionen, Mittelklick den Tracker.",
      danach = function() if ns.MinimapKnopfZeigen then ns.MinimapKnopfZeigen() end end },
    { "tracker", "Tracker", "Kleines Fenster am Bildschirmrand mit den fehlenden Materialien und dem Fortschritt der Liste.",
      danach = function() ns.TrackerNeu() end },
    { "bildschirm", "Meldungen auf dem Bildschirm", "Fortschritt beim Sammeln und fertige Listen zusätzlich mitten auf dem Bildschirm." },
    { "autoSelbst", "Selbst herstellen, wenn ich's kann", "Zwischenprodukte, die einer deiner Charaktere herstellen kann, werden automatisch in ihre Zutaten aufgelöst." },
    { "postHinweis", "Hinweise für andere Charaktere", "Beim Einloggen melden, wenn ein anderer Charakter für seine Liste etwas braucht, das du hast." },
    { "berufHinweise", "Berufs-Hinweise", "Stufenaufstieg, Meilensteine, Lehrer, neue Muster in der Beute und unbekannte Rezepte beim Händler." },
    { "abklingMeldung", "Abklingzeiten melden", "Meldet, wenn Transmutation oder Mondstoff bei einem deiner Charaktere wieder bereit ist." },
    { "fluestern", "Flüsteranfragen beantworten", "Flüstert dir jemand „!werkbank Name“, antwortet die Werkbank, ob du das herstellen kannst und mit welchen Zutaten." },
  })
  SchalterSeite("meldungen", "Meldungen", {
    { "zielMeldung", "Ziele und Erfolge melden", "Meldung, Bildschirmtext und Sprachausgabe, wenn ein Berufsziel erreicht ist oder ein Werkbank-Erfolg dazukommt." },
    { "mindestWarnung", "Mindestbestand überwachen", "Meldet im Chat, wenn ein Gegenstand unter den eingestellten Mindestbestand fällt." },
    { "auftragHinweis", "An Aufträge erinnern", "Beim Einloggen melden, wenn Aufträge heute fällig oder schon überfällig sind." },
    { "alarmTon", "Preisalarm mit Ton", "Spielt einen Ton, wenn im Auktionshaus ein Preis unter deine Grenze fällt." },
  })

  local p = Seite("darstellung", "Darstellung")
  Ueberschrift(p, "Akzentfarbe", "Färbt Rahmen, Überschriften und Auswahl. Wirkt sofort.")
  local akzente = {}
  for _, a in ipairs(ns.AKZENTE) do
    local farbe = a[3] and { a[3], a[4], a[5] }
    if a[1] == "klasse" then
      local k = UnitClass and select(2, UnitClass("player"))
      local c = k and RAID_CLASS_COLORS and RAID_CLASS_COLORS[k]
      farbe = c and { c.r, c.g, c.b }
    end
    akzente[#akzente + 1] = { titel = a[2], text = a[6], wert = a[1], farbe = farbe }
  end
  local ka = Karten(p, -44, 3, akzente,
    function(k) return (ns.db.optionen.akzent or "gold") == k.wert end,
    function(k)
      ns.db.optionen.akzent = k.wert
      ns.FarbenAnwenden()
      ns.Aktualisieren()
    end)
  Ueberschrift(p, "Größe", "Fenster und Schrift der Werkbank, frei auch mit /wb groesse 100-200.", -176)
  local groessen = {}
  for _, g in ipairs(ns.GROESSEN) do
    groessen[#groessen + 1] = { titel = ("%d %%"):format(g * 100 + 0.5), text = g == 1 and "Grundeinstellung" or (g == 1.25 and "Alles größer" or "Noch größer"), wert = g }
  end
  local kg = Karten(p, -220, 4, groessen,
    function(k) return math.abs(ns.Groesse() - k.wert) < 0.01 end,
    function(k)
      ns.db.optionen.groesse = k.wert
      ns.Aktualisieren()
    end)
  local kompakt = CreateFrame("CheckButton", "WerkbankKompakt", p, "UICheckButtonTemplate")
  kompakt:SetPoint("BOTTOMLEFT", -4, -2)
  local kl = kompakt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  kl:SetPoint("LEFT", kompakt, "RIGHT", 2, 0)
  kl:SetText("Kompaktes Fenster: Seitenleiste ausblenden, Seiten über den Knopf „Seiten“")
  kompakt:SetScript("OnClick", function(self)
    ns.db.optionen.kompakt = self:GetChecked() and true or false
    ns.Aktualisieren()
    ns.Sprechen("Kompaktes Fenster " .. (ns.db.optionen.kompakt and "an." or "aus."), true)
  end)
  Tipp(kompakt, "Kompaktes Fenster", "Mehr Platz für Rezeptbuch und Liste, das Fenster lässt sich kleiner ziehen. Alle Seiten erreichst du dann über „Seiten“ unten links.")
  local zurueck = Knopf(p, "Seite zurücksetzen", 150)
  zurueck:SetPoint("BOTTOMRIGHT", 0, 0)
  zurueck:SetScript("OnClick", function()
    ns.db.optionen.akzent = ns.STANDARD.akzent
    ns.db.optionen.groesse = ns.STANDARD.groesse
    ns.db.optionen.kompakt = ns.STANDARD.kompakt
    ns.FarbenAnwenden()
    ns.Aktualisieren()
    ns.Sprechen("Seite zurückgesetzt.", true)
  end)
  p.Neu = function()
    ka.Anordnen()
    kg.Anordnen()
    kompakt:SetChecked(ns.db.optionen.kompakt and true or false)
  end
end

-- ---------- Seiten: Hilfe ----------

local NEUIGKEITEN = {
  "Version 1.5",
  "· Neue Seiten: Übersicht, Aufträge mit Kunden und Fristen, Preise und Vorrat, Ziele und Erfolge, Meldungen",
  "· Auktionshauspreise: Kosten und Gewinn je Rezept, Preisverlauf, Preisalarme, „Liste abfragen“",
  "· Mindestbestände, Berufsziele, Werkbank-Erfolge, Vorlagen, Prioritäten, Rezeptvergleich",
  "· Herstellungsverlauf, Ertrag, Verbrauch, Statistik je Beruf, Diagnose zum Kopieren",
  "· Seitenleiste zeigt deine Berufe (alle über „Alle Berufe …“), kompaktes Fenster, neue Filter",
  "",
  "Version 1.4",
  "· 50 neue Funktionen: Detailseite mit Notizen, Sortierung, Suche in allen Berufen, Rückgängig,",
  "  Tracker, Händlerpreise, Post-Helfer, Abklingzeiten, Statistik, Sammlung, Assistent und mehr",
  "",
  "Version 1.3",
  "· Neues Aussehen im einheitlichen ForeverUI-Design: ein Fenster mit Seitenleiste, Akzentfarbe nach Wahl, Größe veränderbar",
  "· Austausch, Charaktere, Optionen und Hilfe sind jetzt Seiten im Hauptfenster statt eigener Fenster",
  "",
  "Version 1.2",
  "· Vorrat aller Charaktere, gemeinsame und mehrere Einkaufslisten, Charakterübersicht",
  "· Tooltips an Mustern und Plänen: wer es gelernt hat, wer es lernen könnte",
  "· Händler „Fehlendes kaufen“, Bank „Material holen“, Alt-Klick sucht im Auktionshaus",
  "· Fortschritt beim Sammeln, Meldung wenn alles da ist, automatisches Abhaken",
  "· Favoriten, Zutatensuche, Schwierigkeit, „3× möglich“, Minimap-Knopf",
  "",
  "Version 1.1",
  "· Barrierefreiheit: Vorlesen, hoher Kontrast, Farbenblind-Modus, Größe, Tastatursteuerung",
}

local WILLKOMMEN = {
  "Schön, dass du die Werkbank nutzt!",
  "",
  "Links in der Seitenleiste findest du deine Berufe. Ein Klick zeigt das Rezeptbuch,",
  "rechts daneben deine Einkaufsliste: Rezepte anklicken, die Werkbank rechnet die",
  "Materialien zusammen und zieht ab, was du schon hast, auch bei deinen anderen Charakteren.",
  "",
  "Die nächsten drei Schritte stellen ein, was dir wichtig ist:",
  "· Barrierefreiheit: Vorlesen, hoher Kontrast, Farbenblind-Modus, alles größer",
  "· Funktionen: Tracker, Meldungen, Hinweise",
  "· Darstellung: Akzentfarbe und Größe",
  "",
  "Alles lässt sich später unter „Zugang“ ändern. Den Assistenten startest du jederzeit unter Hilfe.",
}

local BEDIENUNG = {
  "Rezeptbuch (links)",
  "· Klick +1 auf die Liste, Strg-Klick +5, Rechtsklick −1",
  "· Umschalt-Klick: Link in den Chat, Alt-Klick: Favorit",
  "· Suche oben rechts findet Rezepte und Zutaten, daneben der Filter",
  "",
  "Einkaufsliste (rechts)",
  "· Klick auf ein herstellbares Material: selbst herstellen statt kaufen",
  "· Alt-Klick auf ein Material: im Auktionshaus suchen",
  "· Klick auf den Listennamen: umbenennen, + < >: weitere Listen",
  "",
  "Unterwegs",
  "· Händler: „Fehlendes kaufen“, Bank: „Material holen“",
  "· Im Berufsfenster: Knopf „Werkbank“ setzt das gewählte Rezept auf die Liste",
  "",
  "· Alt-Klick auf ein Rezept der Liste: Priorität (dringend steht oben)",
  "· Klick auf den Listennamen: Vorlagen, Aufträge, Mindestbestände, Ordnen nach Art",
  "",
  "Aufträge",
  "· Klick: nächster Status, Rechtsklick: Priorität, Aufwand, Material, Kopieren, Löschen",
  "",
  "Mittel- oder Strg-Rechtsklick auf ein Rezept öffnet die Detailseite mit Notiz, Kosten, Gewinn und Vergleich.",
  "Strg+Z macht die letzte Änderung an der Liste rückgängig.",
  "Alt-Klick auf einen Gegenstand im Chat setzt sein Rezept auf die Liste.",
  "",
  "Befehle: /wb hilfe",
}

local function BaueHilfeSeiten()
  TextSeite("neuigkeiten", "Neuigkeiten", function() return table.concat(NEUIGKEITEN, "\n") end)
  TextSeite("bedienung", "Bedienung", function() return table.concat(BEDIENUNG, "\n") end)
  TextSeite("willkommen", "Willkommen", function() return table.concat(WILLKOMMEN, "\n") end)

  -- Fehler melden: Protokoll zum Kopieren
  local fp = Seite("fehler", "Fehler und Diagnose")
  Ueberschrift(fp, "Fehlerprotokoll und Diagnose", "Oben die Diagnose (Version, Spiel, Schnittstellen, Einstellungen), darunter die Fehler. Alles markieren (Strg+A), kopieren (Strg+C) und im Discord unter Feedback einfügen.")
  local scroll = CreateFrame("ScrollFrame", "WerkbankFehlerScroll", fp, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -46)
  scroll:SetPoint("BOTTOMRIGHT", -26, 34)
  local box = CreateFrame("EditBox", "WerkbankFehlerText", scroll)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject(ChatFontNormal or "GameFontHighlightSmall")
  box:SetWidth(500)
  box:SetHeight(200)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(fp.text) end end)
  scroll:SetScrollChild(box)
  local leeren = Knopf(fp, "Protokoll leeren", 140)
  leeren:SetPoint("BOTTOMRIGHT", 0, 0)
  leeren:SetScript("OnClick", function()
    ns.db.fehler = {}
    fp.Neu()
  end)
  fp.Neu = function()
    fp.text = (ns.DiagnoseText and (ns.DiagnoseText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "\n\n") or "") .. ns.FehlerText()
    local w = scroll:GetWidth()
    if w and w > 50 then box:SetWidth(w) end
    box:SetText(fp.text)
  end
  fp.Vorlesen = function() return ns.FehlerText() end
  local p = Seite("discord", "Discord und Feedback")
  Ueberschrift(p, "Fragen, Ideen und Fehler", "Komm auf unseren Discord-Server oder schau auf der Webseite vorbei. Bei Fehlern hilft eine kurze Beschreibung, was du gerade gemacht hast.")
  local d = KopierFeld(p)
  d:SetPoint("TOPLEFT", 6, -70)
  d:SetPoint("RIGHT", p, "RIGHT", -6, 0)
  d.label:SetText("Discord")
  local w = KopierFeld(p)
  w:SetPoint("TOPLEFT", 6, -114)
  w:SetPoint("RIGHT", p, "RIGHT", -6, 0)
  w.label:SetText("Webseite")
  p.Neu = function()
    d:Fest("https://discord.gg/Sh8zyYUKRX")
    w:Fest("https://foreverui.de/addons/werkbank/")
  end
end

-- ---------- Seiten der Werkstatt: Übersicht, Aufträge, Preise und Vorrat, Ziele, Vergleich, Diagnose ----------

local function Eingabe(parent, name, breite, label)
  local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  e:SetSize(breite, 20)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  if label then
    e.label = e:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    e.label:SetPoint("BOTTOMLEFT", e, "TOPLEFT", -4, 2)
    e.label:SetText(label)
  end
  return e
end

local function Text(box)
  return ((box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Textseite mit Platz für Eingaben unten
local function FormularSeite(name, titel, textFn, unten)
  local p = TextSeite(name, titel, textFn)
  p.scroll:SetPoint("BOTTOMRIGHT", -26, unten)
  return p
end

ui.vergleich = {}

local function AuftragMenue(a)
  local e = {}
  for i, st in ipairs(ns.AUFTRAG_STATUS) do
    e[#e + 1] = { (a.status == i and "> " or "") .. "Status: " .. st, function() ns.AuftragStatus(a.nr, i) end }
  end
  e[#e + 1] = { "Priorität: " .. ns.STUFEN3[a.prio or 2] .. " (ändern)", function() ns.AuftragWert(a.nr, "prio") end }
  e[#e + 1] = { "Aufwand: " .. ns.STUFEN3[a.aufwand or 2] .. " (ändern)", function() ns.AuftragWert(a.nr, "aufwand") end }
  e[#e + 1] = { a.kundenMat and "Material kommt doch von mir" or "Kunde bringt das Material", function() ns.AuftragWert(a.nr, "kundenMat") end }
  e[#e + 1] = { "Auf die Einkaufsliste", function() ns.ListeAdd(a.rid, a.n) end, grau = a.kundenMat }
  e[#e + 1] = { "Rezept zeigen", function() ns.RezeptZeigen(a.rid) end }
  e[#e + 1] = { "Kopieren (neuer Auftrag)", function() ns.AuftragDuplizieren(a.nr) end }
  e[#e + 1] = { "Löschen", function() ns.AuftragLoeschen(a.nr) end }
  return S.Menue(ui.auftragListe, e)
end

local function AuftragEintraege()
  local e = {}
  if ui.kundenAnsicht then return e end
  local liste = ns.AuftraegeSortiert(ns.AUFTRAG_SORT[ui.auftragSort or 1], ui.auftragAlle)
  if #liste == 0 then
    e[1] = { kopf = ui.auftragAlle and "Noch keine Aufträge" or "Keine offenen Aufträge" }
    e[2] = { info = "Oben Kunde, Rezept und Anzahl eintragen und „Anlegen“ drücken." }
    return e
  end
  for _, a in ipairs(liste) do
    e[#e + 1] = { auftrag = a }
    e[#e + 1] = { auftrag = a, zweite = true }
  end
  return e
end

local function ZeichneAuftrag(row, e)
  if e.kopf then return ZeichneKopf(row, e) end
  if e.info then
    row.icon:Hide()
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetText(F.grau .. e.info .. "|r")
    row.rechts:SetText("")
    return
  end
  local a = e.auftrag
  local z1, z2 = ns.AuftragZeile(a)
  if e.zweite then
    row.icon:Hide()
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetText(z2)
    row.rechts:SetText("")
  else
    ZeichneZeile(row, ns.RezeptIcon(a.rid), (z1:gsub("  |cff%x%x%x%x%x%x%[.-%]|r.*$", "")), (a.status < 4 and ns.FristText(a.frist) or "") .. "  " .. F.grau .. ns.AUFTRAG_STATUS[a.status] .. "|r")
  end
end

local function KlickAuftrag(e, btn)
  local a = e.auftrag
  if not a then return end
  if btn == "RightButton" then return AuftragMenue(a) end
  if btn == "MiddleButton" then return ns.RezeptZeigen(a.rid) end
  local neu = ns.AuftragStatus(a.nr)
  if neu then ns.Sprechen("Auftrag " .. a.nr .. ": " .. ns.AUFTRAG_STATUS[neu.status]) end
end

local function EnterAuftrag(row, e)
  local a = e.auftrag
  if not a then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText("Auftrag #" .. a.nr .. " für " .. a.kunde, 1, 1, 1)
  local z1, z2 = ns.AuftragZeile(a)
  GameTooltip:AddLine(z1, nil, nil, nil, true)
  GameTooltip:AddLine(z2, nil, nil, nil, true)
  local fehlt = ns.AuftragFehlt(a)
  for id, n in pairs(fehlt) do GameTooltip:AddLine(F.rot .. "fehlt " .. n .. "× " .. ns.ItemName(id) .. "|r") end
  local k = ns.db.kunden and ns.db.kunden[a.kunde]
  if k and k.kontakt then GameTooltip:AddLine("Kontakt: " .. k.kontakt, 0.55, 0.55, 0.55, true) end
  if a.erstellt and date then GameTooltip:AddLine("Angelegt am " .. date("%d.%m.%Y", a.erstellt) .. (a.wer and (" von " .. a.wer) or ""), 0.55, 0.55, 0.55) end
  GameTooltip:AddLine(F.grau .. "Klick: nächster Status · Rechtsklick: mehr · Mittelklick: Rezept|r")
  GameTooltip:Show()
  ns.Sprechen(ns.Sauber and ns.Sauber(z1 .. ". " .. z2) or z1)
end

function ns.AuftragVorbereiten(rid, n)
  ns.SeiteZeigen("auftraege")
  ui.auftragRezept:SetText(ns.RezeptName(rid))
  ui.auftragAnzahl:SetText(tostring(n or 1))
  ui.auftragKunde:SetFocus()
end

local function BaueAuftragSeite()
  local p = Seite("auftraege", "Aufträge")
  local kunde = Eingabe(p, "WerkbankAuftragKunde", 110, "Kunde")
  kunde:SetPoint("TOPLEFT", 6, -16)
  local rezept = Eingabe(p, "WerkbankAuftragRezept", 190, "Rezept oder Gegenstand")
  rezept:SetPoint("LEFT", kunde, "RIGHT", 12, 0)
  local anzahl = Eingabe(p, "WerkbankAuftragAnzahl", 40, "Anzahl")
  anzahl:SetPoint("LEFT", rezept, "RIGHT", 12, 0)
  anzahl:SetNumeric(true)
  anzahl:SetMaxLetters(3)
  local lohn = Eingabe(p, "WerkbankAuftragLohn", 80, "Lohn (1g 50s)")
  lohn:SetPoint("LEFT", anzahl, "RIGHT", 12, 0)
  local frist = Eingabe(p, "WerkbankAuftragFrist", 80, "Frist (24.12. / +3)")
  frist:SetPoint("LEFT", lohn, "RIGHT", 12, 0)
  local notiz = Eingabe(p, "WerkbankAuftragNotiz", 300, "Notiz")
  notiz:SetPoint("TOPLEFT", kunde, "BOTTOMLEFT", 0, -22)
  notiz:SetPoint("RIGHT", p, "RIGHT", -330, 0)
  local mat = CreateFrame("CheckButton", "WerkbankAuftragMaterial", p, "UICheckButtonTemplate")
  mat:SetSize(20, 20)
  mat:SetPoint("LEFT", notiz, "RIGHT", 8, 0)
  local ml = mat:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  ml:SetPoint("LEFT", mat, "RIGHT", 2, 0)
  ml:SetText("Kunde bringt Material")
  local anlegen = Knopf(p, "Anlegen", 90)
  anlegen:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -54)
  ui.auftragKunde, ui.auftragRezept, ui.auftragAnzahl = kunde, rezept, anzahl

  local function Anlegen()
    local rid = ns.RezeptSuchen(Text(rezept))
    if not rid then
      ns.Print("Dieses Rezept kenne ich nicht. Name des Rezepts oder des Gegenstands eintragen.")
      rezept:SetFocus()
      return
    end
    local fristText = Text(frist)
    local f = ns.FristLesen(fristText)
    if fristText ~= "" and not f then ns.Print("Die Frist verstehe ich nicht. Beispiele: 24.12., 24.12.2026, +3, morgen.") return end
    local lohnText = Text(lohn)
    local l = ns.GeldLesen(lohnText)
    if lohnText ~= "" and not l then ns.Print("Den Lohn bitte mit Einheit angeben, z. B. 1g 50s.") return end
    local a = ns.AuftragNeu({ kunde = Text(kunde), rid = rid, n = tonumber(Text(anzahl)) or 1, lohn = l, frist = f,
      notiz = Text(notiz) ~= "" and Text(notiz) or nil, kundenMat = mat:GetChecked() })
    if a then
      ns.Print("Auftrag #" .. a.nr .. " angelegt: " .. a.n .. "× " .. ns.RezeptName(rid) .. " für " .. a.kunde .. ".")
      ns.Sprechen("Auftrag angelegt.")
      for _, b in ipairs({ rezept, anzahl, lohn, frist, notiz }) do b:SetText("") b:ClearFocus() end
      mat:SetChecked(false)
    end
  end
  anlegen:SetScript("OnClick", Anlegen)
  for _, b in ipairs({ kunde, rezept, anzahl, lohn, frist, notiz }) do b:SetScript("OnEnterPressed", Anlegen) end
  Tipp(anlegen, "Auftrag anlegen", "Kunde, Rezept und Anzahl reichen. Lohn, Frist und Notiz sind freiwillig.", "Frist: 24.12. oder 24.12.2026, +3 für in drei Tagen, heute oder morgen.")

  -- Werkzeugleiste
  local sortKnopf = Knopf(p, "Nach: Frist", 120)
  sortKnopf:SetPoint("TOPLEFT", notiz, "BOTTOMLEFT", -6, -10)
  local SORTNAMEN = { "Frist", "Priorität", "Kunde", "Status", "Lohn", "Aufwand", "Beruf" }
  sortKnopf:SetScript("OnClick", function(self)
    ui.auftragSort = (ui.auftragSort or 1) % #SORTNAMEN + 1
    self:SetText("Nach: " .. SORTNAMEN[ui.auftragSort])
    Neu()
  end)
  local alle = Knopf(p, "Auch erledigte", 120)
  alle:SetPoint("LEFT", sortKnopf, "RIGHT", 6, 0)
  alle:SetScript("OnClick", function(self)
    ui.auftragAlle = not ui.auftragAlle
    self:SetText(ui.auftragAlle and "Nur offene" or "Auch erledigte")
    Neu()
  end)
  local aufListe = Knopf(p, "Offene auf die Liste", 150)
  aufListe:SetPoint("LEFT", alle, "RIGHT", 6, 0)
  aufListe:SetScript("OnClick", function() ns.AuftraegeAufListe() end)
  Tipp(aufListe, "Offene Aufträge auf die Liste", "Setzt alle geplanten und laufenden Aufträge, für die du das Material besorgst, auf die aktive Einkaufsliste.")
  local kundenKnopf = Knopf(p, "Kunden", 90)
  kundenKnopf:SetPoint("LEFT", aufListe, "RIGHT", 6, 0)
  kundenKnopf:SetScript("OnClick", function(self)
    ui.kundenAnsicht = not ui.kundenAnsicht
    self:SetText(ui.kundenAnsicht and "Aufträge" or "Kunden")
    Neu()
  end)

  local liste = Liste(p, ZeichneAuftrag, KlickAuftrag, EnterAuftrag)
  liste:SetPoint("TOPLEFT", sortKnopf, "BOTTOMLEFT", 0, -8)
  liste:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  ui.auftragListe = liste

  -- Kundenansicht: Text mit Verlauf und Kontaktweg
  local kt = CreateFrame("ScrollFrame", "WerkbankKundenScroll", p, "UIPanelScrollFrameTemplate")
  kt:SetPoint("TOPLEFT", liste, "TOPLEFT", 0, 0)
  kt:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -26, 0)
  local inhalt = CreateFrame("Frame", nil, kt)
  inhalt:SetSize(500, 10)
  kt:SetScrollChild(inhalt)
  local ktext = inhalt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  ktext:SetPoint("TOPLEFT")
  ktext:SetJustifyH("LEFT")
  ktext:SetSpacing(2)
  kt:Hide()

  p.Neu = function()
    liste:SetShown(not ui.kundenAnsicht)
    kt:SetShown(ui.kundenAnsicht and true or false)
    if ui.kundenAnsicht then
      local w = kt:GetWidth()
      if w and w > 50 then inhalt:SetWidth(w) ktext:SetWidth(w - 4) else ktext:SetWidth(500) end
      ktext:SetText(ns.KundenText() .. "\n\n" .. F.grau .. "Kontaktweg oder Notiz zu einem Kunden: /wb kunde Name Text|r")
      inhalt:SetHeight((ktext.GetStringHeight and ktext:GetStringHeight() or 10) + 10)
    else
      liste.eintraege = AuftragEintraege()
      liste:Groesse()
    end
  end
  p.Vorlesen = function() return ns.Sauber and ns.Sauber(ns.AuftraegeText("frist")) or "" end
end

local function BauePreisSeite()
  local p = FormularSeite("preise", "Preise und Vorrat", function() return ns.PreiseText() end, 64)
  local alarm = Eingabe(p, "WerkbankAlarm", 220, "Preisalarm (Gegenstand und Preis, z. B. Leinenstoff 20s)")
  alarm:SetPoint("BOTTOMLEFT", 6, 26)
  local aK = Knopf(p, "Setzen", 70)
  aK:SetPoint("LEFT", alarm, "RIGHT", 4, 0)
  local function Alarm() if ns.AlarmSetzen(Text(alarm)) then alarm:SetText("") alarm:ClearFocus() end Neu() end
  aK:SetScript("OnClick", Alarm)
  alarm:SetScript("OnEnterPressed", Alarm)
  local mind = Eingabe(p, "WerkbankMindest", 160, "Mindestbestand (z. B. Leinenstoff 40)")
  mind:SetPoint("LEFT", aK, "RIGHT", 24, 0)
  local mK = Knopf(p, "Setzen", 70)
  mK:SetPoint("LEFT", mind, "RIGHT", 4, 0)
  local function Mindest() if ns.MindestSetzen(Text(mind)) then mind:SetText("") mind:ClearFocus() end Neu() end
  mK:SetScript("OnClick", Mindest)
  mind:SetScript("OnEnterPressed", Mindest)
  local auf = Knopf(p, "Auffüllen", 90)
  auf:SetPoint("LEFT", mK, "RIGHT", 4, 0)
  auf:SetScript("OnClick", function() ns.MindestAufListe() end)
  Tipp(auf, "Mindestbestand auffüllen", "Setzt alles Herstellbare, das unter dem Mindestbestand liegt, auf die aktive Einkaufsliste.")
  local hinweis = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hinweis:SetPoint("BOTTOMLEFT", 2, 2)
  hinweis:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  hinweis:SetJustifyH("LEFT")
  hinweis:SetText("Im Auktionshaus fragt der Knopf „Liste abfragen“ jedes fehlende Material der Reihe nach ab. Ohne Preis: Alarm wird entfernt.")
end

local function BaueZielSeite()
  local p = FormularSeite("ziele", "Ziele und Erfolge", function()
    return F.gold .. "Berufsziele|r\n" .. ns.ZieleText() .. "\n\n" .. F.gold .. "Werkbank-Erfolge|r\n" .. ns.ErfolgeText()
  end, 64)
  local ziel = Eingabe(p, "WerkbankZiel", 200, "Ziel (z. B. Schmiedekunst 225 oder Alchimie 40 rezepte)")
  ziel:SetPoint("BOTTOMLEFT", 6, 26)
  local zK = Knopf(p, "Setzen", 70)
  zK:SetPoint("LEFT", ziel, "RIGHT", 4, 0)
  local function Ziel() if ns.ZielSetzen(Text(ziel)) then ziel:SetText("") ziel:ClearFocus() end Neu() end
  zK:SetScript("OnClick", Ziel)
  ziel:SetScript("OnEnterPressed", Ziel)
  local vorlage = Eingabe(p, "WerkbankVorlage", 150, "Vorlage aus der aktiven Liste")
  vorlage:SetPoint("LEFT", zK, "RIGHT", 24, 0)
  local vS = Knopf(p, "Speichern", 84)
  vS:SetPoint("LEFT", vorlage, "RIGHT", 4, 0)
  vS:SetScript("OnClick", function() ns.VorlageSpeichern(Text(vorlage)) vorlage:SetText("") vorlage:ClearFocus() end)
  local vL = Knopf(p, "Laden …", 84)
  vL:SetPoint("LEFT", vS, "RIGHT", 4, 0)
  vL:SetScript("OnClick", function(self)
    local e = {}
    for _, name in ipairs(ns.Vorlagen()) do e[#e + 1] = { name, function() ns.VorlageLaden(name) end } end
    for _, name in ipairs(ns.Vorlagen()) do e[#e + 1] = { "Löschen: " .. name, function() ns.VorlageLoeschen(name) Neu() end } end
    if #e == 0 then e[1] = { "Noch keine Vorlagen", nil, grau = true } end
    S.Menue(self, e)
  end)
  Tipp(vL, "Vorlage laden", "Legt eine neue Einkaufsliste aus einer gespeicherten Vorlage an, z. B. „Wochenbedarf Raid“.")
  local hinweis = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hinweis:SetPoint("BOTTOMLEFT", 2, 2)
  hinweis:SetText("0 als Zahl löscht ein Ziel. Ist ein Ziel erreicht, meldet die Werkbank das (abschaltbar unter Funktionen).")
end

local function BaueVergleichSeite()
  local p = FormularSeite("vergleich", "Rezepte vergleichen", function() return ns.VergleichText(ui.vergleich[1], ui.vergleich[2]) end, 30)
  local tauschen = Knopf(p, "Tauschen", 90)
  tauschen:SetPoint("BOTTOMLEFT", 0, 0)
  tauschen:SetScript("OnClick", function() ui.vergleich[1], ui.vergleich[2] = ui.vergleich[2], ui.vergleich[1] Neu() end)
  local leeren = Knopf(p, "Neu wählen", 100)
  leeren:SetPoint("LEFT", tauschen, "RIGHT", 4, 0)
  leeren:SetScript("OnClick", function() ui.vergleich = {} ns.SeiteZeigen("rezepte") end)
end

-- Rezept für den Vergleich merken; beim zweiten öffnet sich die Vergleichsseite
function ns.VergleichMerken(rid)
  local v = ui.vergleich
  if v[1] and not v[2] and v[1] ~= rid then
    v[2] = rid
    return ns.SeiteZeigen("vergleich")
  end
  ui.vergleich = { rid }
  ns.Print(ns.RezeptName(rid) .. " gemerkt. Jetzt beim zweiten Rezept auf „Vergleichen“ drücken.")
end

function ns.VergleichZeigen(a, b)
  ui.vergleich = { a, b }
  ns.SeiteZeigen("vergleich")
end

local function BaueWerkstattSeiten()
  local p = TextSeite("uebersicht", "Übersicht", function() return ns.UebersichtText() end)
  p.scroll:SetPoint("BOTTOMRIGHT", -26, 30)
  local knoepfe = { { "Aufträge", "auftraege" }, { "Preise und Vorrat", "preise" }, { "Ziele und Erfolge", "ziele" }, { "Statistik", "statistik" } }
  local vorher
  for _, k in ipairs(knoepfe) do
    local b = Knopf(p, k[1], 130)
    if vorher then b:SetPoint("LEFT", vorher, "RIGHT", 4, 0) else b:SetPoint("BOTTOMLEFT", 0, 0) end
    b:SetScript("OnClick", function() ns.SeiteZeigen(k[2]) end)
    vorher = b
  end
  BaueAuftragSeite()
  BauePreisSeite()
  BaueZielSeite()
  BaueVergleichSeite()
  TextSeite("diagnose", "Diagnose", function() return ns.DiagnoseText() end)
end

-- ---------- Hauptfenster ----------

function Neu()
  if not ui.frame or not ui.frame:IsShown() then return end
  local o = ns.db.optionen
  ui.frame:SetScale(ns.Groesse())
  ui.frame.hg:SetColorTexture(S.HG[1], S.HG[2], S.HG[3], ns.Deckkraft(0.99))
  ui.leiste.hg:SetColorTexture(S.HG[1], S.HG[2], S.HG[3], ns.Deckkraft(0.5))
  ui.inhalt.hg:SetColorTexture(S.HG[1], S.HG[2], S.HG[3], ns.Deckkraft(0.35))
  if not InCombatLockdown() then ui.frame:EnableKeyboard(o.tastatur and true or false) end
  local kompakt = o.kompakt and true or false
  if ui.kompaktStand ~= kompakt then
    ui.kompaktStand = kompakt
    ui.leiste:SetShown(not kompakt)
    ui.inhalt:ClearAllPoints()
    if kompakt then ui.inhalt:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 12, -72)
    else ui.inhalt:SetPoint("TOPLEFT", ui.leiste, "TOPRIGHT", 12, 0) end
    ui.inhalt:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -12, 44)
    S.Mindestgroesse(ui.frame, kompakt and 720 or 900, kompakt and 560 or 660)
    ui.seitenKnopf:SetShown(kompakt)
    ui.fuss:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", kompakt and 120 or 22, 18)
    if ui.Layout then ui.Layout() end
  end
  local rezepte = ui.seite == "rezepte"
  ui.suche:SetShown(rezepte)
  ui.filterKnopf:SetShown(rezepte)
  LeisteNeu()
  local p = ui.seiten[ui.seite]
  for name, s in pairs(ui.seiten) do
    if name ~= ui.seite and s:IsShown() then s:Hide() end
  end
  if not p:IsShown() then p:Show() end
  if p.Neu then p.Neu() end
  ui.frame.seitenTitel:SetText(p.titel or "")
  -- Einrichtungsassistent
  if ui.assistent and SCHRITTE[ui.assistent] ~= ui.seite then ui.assistent = nil end
  local a = ui.assistentLeiste
  a:SetShown(ui.assistent ~= nil)
  ui.fuss:SetShown(ui.assistent == nil)
  if ui.assistent then
    ui.frame.seitenTitel:SetText(p.titel .. "  " .. F.grau .. "Schritt " .. ui.assistent .. " von " .. #SCHRITTE .. "|r")
    a.zurueck:SetShown(ui.assistent > 1)
    a.weiter:SetText(ui.assistent == #SCHRITTE and "Fertig" or "Weiter")
    local A = ns.Akzent
    for i, pkt in ipairs(a.punkte) do
      if i == ui.assistent then pkt:SetColorTexture(A[1], A[2], A[3], 1) else pkt:SetColorTexture(1, 1, 1, 0.25) end
    end
  end
end

-- ---------- Einrichtungsassistent ----------

function ns.AssistentStarten()
  ns.SeiteZeigen(SCHRITTE[1])
  ui.assistent = 1
  Neu()
  ns.Sprechen("Willkommen bei der Werkbank. Schritt 1 von " .. #SCHRITTE .. ".")
end

function ns.AssistentSchritt(richtung)
  local i = (ui.assistent or 1) + richtung
  if i > #SCHRITTE then
    ui.assistent = nil
    ns.db.assistentFertig = true
    ns.SeiteZeigen("rezepte")
    ns.Print("Fertig eingerichtet. Viel Spaß an der Werkbank!")
    return
  end
  i = math.max(1, i)
  ui.seite = SCHRITTE[i]
  ui.assistent = i
  ns.SeiteZeigen(SCHRITTE[i])
  ui.assistent = i
  Neu()
end
ns.BeiAenderung(Neu)

-- Breite von Rezeptbuch und Liste an die Fenstergröße anpassen
local function Layout()
  if not ui.buch or not ui.liste then return end
  local w = ui.inhalt:GetWidth()
  if not w or w < 200 then w = 980 - LEISTE_B - 36 end
  ui.buch:SetWidth(math.floor((w - 24 - 14) * 0.56))
  ui.buch:Groesse()
  ui.liste:Groesse()
  if ui.seite and ui.seiten[ui.seite] and ui.seiten[ui.seite].Neu and ui.frame:IsShown() then ui.seiten[ui.seite].Neu() end
end

ui.Layout = Layout

local function Bauen()
  local o = ns.db.optionen
  local f = S.Fenster("WerkbankFrame", 980, 680)
  ui.frame = f
  S.Mindestgroesse(f, 900, 660)
  if type(o.fenster) == "table" then f:SetSize(o.fenster[1], o.fenster[2]) end
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    o.pos = { p, rp, x, y }
  end)
  function f:NachGroesse()
    local w, h = self:GetWidth(), self:GetHeight()
    if w and h then o.fenster = { math.floor(w + 0.5), math.floor(h + 0.5) } end
    Layout()
  end
  f:SetScript("OnSizeChanged", function() Layout() end)
  f:SetScript("OnShow", function() Neu() end)
  local pos = o.pos
  if pos then
    f:ClearAllPoints()
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end

  -- Tastatursteuerung (in den Optionen einschalten)
  pcall(f.SetPropagateKeyboardInput, f, true)
  f:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    local erledigt = ns.FensterTaste(key)
    self:SetPropagateKeyboardInput(not erledigt)
  end)

  -- Suche und Filter oben rechts im Kopfband
  local suche = CreateFrame("EditBox", "WerkbankSuche", f, "InputBoxTemplate")
  suche:SetSize(240, 20)
  suche:SetPoint("TOPRIGHT", -40, -22)
  suche:SetAutoFocus(false)
  suche:SetScript("OnTextChanged", function()
    FauxScrollFrame_SetOffset(ui.buch.scroll, 0)
    ui.buch.scroll:SetVerticalScroll(0)
    Neu()
  end)
  suche:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  suche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  local platzhalter = suche:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  platzhalter:SetPoint("LEFT", 2, 0)
  platzhalter:SetText("Rezept oder Zutat suchen …")
  suche:HookScript("OnTextChanged", function(self) platzhalter:SetShown(self:GetText() == "") end)
  ui.suche = suche

  ui.filter = 1
  local filter = Knopf(f, FILTER[1], 170)
  filter:SetPoint("RIGHT", suche, "LEFT", -12, 0)
  filter:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  filter:SetScript("OnClick", function(self, btn)
    ui.filter = (ui.filter - 1 + (btn == "RightButton" and -1 or 1)) % #FILTER + 1
    self:SetText(FILTER[ui.filter])
    ns.Sprechen("Filter " .. FILTER[ui.filter])
    Neu()
  end)
  ui.filterKnopf = filter

  -- Suche in allen Berufen
  local ueberall = CreateFrame("CheckButton", "WerkbankUeberall", f, "UICheckButtonTemplate")
  ueberall:SetSize(20, 20)
  ueberall:SetPoint("TOPLEFT", suche, "BOTTOMLEFT", -6, 0)
  local ul = ueberall:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  ul:SetPoint("LEFT", ueberall, "RIGHT", 2, 0)
  ul:SetText("In allen Berufen suchen")
  ueberall:SetScript("OnClick", function(self)
    ui.ueberall = self:GetChecked() and true or false
    ns.Sprechen("In allen Berufen suchen " .. (ui.ueberall and "an." or "aus."))
    Neu()
  end)
  ui.ueberallKnopf = ueberall
  Tipp(filter, "Filter", "Klick: nächster Filter, Rechtsklick: voriger.", "Alle, Gelernt, Noch nicht gelernt, Von meinen Charakteren gelernt, Jetzt herstellbar, Favoriten, Bringt noch Punkte, Beim Händler gesehen, Neu seit Datenupdate, Mit Gewinn (braucht Auktionshauspreise).", "Gelernte Rezepte erfasst die Werkbank, sobald du das Berufsfenster öffnest.")

  BaueLeiste(f)
  ui.inhalt = S.Kasten(f)
  ui.inhalt:SetPoint("TOPLEFT", ui.leiste, "TOPRIGHT", 12, 0)
  ui.inhalt:SetPoint("BOTTOMRIGHT", -12, 44)

  BaueRezeptSeite()
  BaueCharakterSeite()
  BaueDetailSeite()
  BaueAustauschSeite()
  BaueOptionsSeiten()
  BaueHilfeSeiten()
  BaueWerkstattSeiten()

  -- Unten: Hinweis links, Schließen rechts
  local schliessen = Knopf(f, "Schließen", 100)
  schliessen:SetPoint("BOTTOMRIGHT", -24, 12)
  schliessen:SetScript("OnClick", function() f:Hide() end)
  local fuss = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  fuss:SetPoint("BOTTOMLEFT", 22, 18)
  fuss:SetPoint("RIGHT", schliessen, "LEFT", -8, 0)
  fuss:SetJustifyH("LEFT")
  fuss:SetText("Klick +1 · Strg +5 · Rechtsklick −1 · Alt: Favorit · Mittelklick: Details")
  ui.fuss = fuss
  local seitenKnopf = Knopf(f, "Seiten …", 96)
  seitenKnopf:SetPoint("BOTTOMLEFT", 14, 12)
  seitenKnopf:SetScript("OnClick", function(self) ns.SeitenMenue(self) end)
  seitenKnopf:Hide()
  ui.seitenKnopf = seitenKnopf

  -- Leiste des Einrichtungsassistenten: Zurück, Punkte, Weiter
  local a = CreateFrame("Frame", nil, f)
  a:SetPoint("BOTTOMLEFT", 12, 8)
  a:SetPoint("BOTTOMRIGHT", schliessen, "BOTTOMLEFT", -12, 0)
  a:SetHeight(30)
  a:Hide()
  a.zurueck = Knopf(a, "Zurück", 90)
  a.zurueck:SetPoint("LEFT", 0, 0)
  a.zurueck:SetScript("OnClick", function() ns.AssistentSchritt(-1) end)
  a.weiter = Knopf(a, "Weiter", 90)
  a.weiter:SetPoint("RIGHT", 0, 0)
  a.weiter:SetScript("OnClick", function() ns.AssistentSchritt(1) end)
  a.punkte = {}
  for i = 1, #SCHRITTE do
    local pkt = a:CreateTexture(nil, "ARTWORK")
    pkt:SetSize(8, 8)
    pkt:SetPoint("CENTER", a, "CENTER", (i - (#SCHRITTE + 1) / 2) * 16, 0)
    a.punkte[i] = pkt
  end
  ui.assistentLeiste = a

  -- Startberuf: der erste, den der Charakter hat
  for _, b in ipairs(D.berufe) do
    if ns.char.berufe[b.id] then
      ui.beruf = b.id
      break
    end
  end
  ui.beruf = ui.beruf or D.berufe[1].id
  ui.seite = "rezepte"
  Layout()
end

-- Zeigt eine Seite im Hauptfenster (und öffnet es)
function ns.SeiteZeigen(seite, berufId)
  if not ui.frame then Bauen() end
  if seite and seite ~= ui.seite and ui.assistent and SCHRITTE[ui.assistent] ~= seite then ui.assistent = nil end
  if seite then ui.seite = seite end
  if berufId and berufId ~= ui.beruf then
    ui.beruf = berufId
    FauxScrollFrame_SetOffset(ui.buch.scroll, 0)
    ui.buch.scroll:SetVerticalScroll(0)
  end
  if ui.frame:IsShown() then Neu() else ui.frame:Show() end
  local p = ui.seiten[ui.seite]
  if p and p.Vorlesen then ns.Sprechen(p.Vorlesen()) end
end

function ns.Umschalten(berufId)
  if not ui.frame then Bauen() end
  if berufId then return ns.SeiteZeigen("rezepte", berufId) end
  ui.frame:SetShown(not ui.frame:IsShown())
end

function ns.Oeffnen(berufId)
  ns.SeiteZeigen("rezepte", berufId)
end

-- Frühere Einzelfenster sind jetzt Seiten im Hauptfenster
function ns.OptionenDialog() ns.SeiteZeigen("barrierefreiheit") end
function ns.CharakterDialog() ns.SeiteZeigen("charaktere") end
function ns.ExportDialog() ns.SeiteZeigen("austausch") end
function ns.ImportDialog()
  ns.SeiteZeigen("austausch")
  ui.importBox:SetFocus()
end
function ns.UmbenennenDialog()
  ns.SeiteZeigen("rezepte")
  ui.nameBox:SetText(ns.L.name or "")
  ui.nameBox:Show()
  ui.nameBox:SetFocus()
  ui.nameBox:HighlightText()
end

-- ---------- Tastatursteuerung im Fenster ----------
-- Pfeile: bewegen · Links/Rechts: Rezeptbuch oder Liste · Eingabe: +1 · Rücktaste/Entf: −1
-- Tab: nächster Eintrag der Seitenleiste · Leertaste: vorlesen · Strg+F: Suche · M: Favorit · Esc: schließen

local function Vorlesen(e, immer)
  local text = EintragText(e)
  if immer and not ns.Sprechen(text, true) then ns.Print(ns.Sauber(text)) end
  if not immer then ns.Sprechen(text) end
end

function ns.FensterTaste(key)
  if not ui.frame or not ns.db.optionen.tastatur then return false end
  if key == "ESCAPE" then
    ui.frame:Hide()
    return true
  end
  if key == "Z" and IsControlKeyDown() then
    ns.Rueckgaengig()
    return true
  end
  -- Tab wechselt den Eintrag der Seitenleiste, auf den anderen Seiten auch die Pfeile
  if key == "TAB" or (ui.seite ~= "rezepte" and (key == "UP" or key == "DOWN")) then
    local schritt = ((key == "TAB" and IsShiftKeyDown()) or key == "UP") and -1 or 1
    local eintrag = ns.LeisteSchritt(schritt)
    if ui.seite == "rezepte" then
      ui.aktiv = "buch"
      ui.buch.cursor = 1
      local erst = ui.buch:Gehe(1)
      ns.Sprechen(eintrag.text .. ". " .. EintragText(erst))
    else
      ns.Sprechen(eintrag.text)
    end
    return true
  end
  if ui.seite ~= "rezepte" then return false end
  local l = ui.aktiv == "liste" and ui.liste or ui.buch
  local e = l.eintraege[l.cursor]
  if key == "UP" or key == "DOWN" or key == "PAGEUP" or key == "PAGEDOWN" or key == "HOME" or key == "END" then
    local ziel = ({ UP = l.cursor - 1, DOWN = l.cursor + 1, PAGEUP = l.cursor - l.anzahl,
      PAGEDOWN = l.cursor + l.anzahl, HOME = 1, END = #l.eintraege })[key]
    Vorlesen(l:Gehe(ziel))
  elseif key == "LEFT" or key == "RIGHT" then
    ui.aktiv = key == "RIGHT" and "liste" or "buch"
    l = ui.aktiv == "liste" and ui.liste or ui.buch
    Neu()
    local neu = l:Gehe(l.cursor)
    ns.Sprechen((ui.aktiv == "liste" and "Einkaufsliste. " or "Rezeptbuch. ") .. EintragText(neu))
  elseif key == "ENTER" or key == "BACKSPACE" or key == "DELETE" then
    if e and l.klick then
      l.klick(e, key == "ENTER" and "LeftButton" or "RightButton")
      ns.Sprechen(EintragText(l.eintraege[l.cursor]))
    end
  elseif key == "SPACE" then
    Vorlesen(e, true)
  elseif key == "F" and IsControlKeyDown() then
    ui.suche:SetFocus()
  elseif key == "D" then
    local rid = e and (e.rid or e.liste)
    if rid then ns.RezeptZeigen(rid) end
  elseif key == "M" then
    local rid = e and (e.rid or e.liste)
    if rid then
      local an = ns.FavoritUmschalten(rid)
      ns.Sprechen(ns.RezeptName(rid) .. (an and " ist jetzt Favorit." or " ist kein Favorit mehr."), true)
    end
  else
    return false
  end
  return true
end


-- ---------- Knopf im Berufsfenster ----------

local function BerufsfensterKnopf(parent, close)
  if not parent or parent.werkbankKnopf then return end
  local b = Knopf(parent, "Werkbank", 80)
  b:SetFrameLevel(parent:GetFrameLevel() + 5)
  if close then
    b:SetPoint("RIGHT", close, "LEFT", -2, 0)
  else
    b:SetPoint("TOPRIGHT", -40, -14)
  end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
      ns.Oeffnen(ns.offenerBeruf and ns.offenerBeruf.id)
      return
    end
    local rid = ns.GewaehltesRezept()
    if not rid then
      ns.Print("Dieses Rezept kennt die Werkbank nicht.")
      return
    end
    local n = 1
    local box = (parent == TradeSkillFrame and TradeSkillInputBox) or (parent == CraftFrame and CraftInputBox)
    if box and box.GetNumber then n = math.max(box:GetNumber() or 1, 1) end
    ns.ListeAdd(rid, n)
    ns.Print(n .. "× " .. ns.RezeptName(rid) .. " auf die Liste gesetzt.")
    ns.Oeffnen(ns.berufOf[rid] and ns.berufOf[rid].id)
  end)
  Tipp(b, "Werkbank", "Klick: gewähltes Rezept auf die Einkaufsliste (Anzahl aus dem Feld unten).", "Rechtsklick: Werkbank öffnen.")
  parent.werkbankKnopf = b
end

function ns.BlizzardFensterGeladen(name)
  if name == "Blizzard_TradeSkillUI" and TradeSkillFrame then
    BerufsfensterKnopf(TradeSkillFrame, TradeSkillFrameCloseButton)
  elseif name == "Blizzard_CraftUI" and CraftFrame then
    BerufsfensterKnopf(CraftFrame, CraftFrameCloseButton)
  end
end

-- ---------- Start und Befehle ----------

function ns.Start()
  ns.TooltipsEinrichten()
  ns.BlizzardFensterGeladen("Blizzard_TradeSkillUI")
  ns.BlizzardFensterGeladen("Blizzard_CraftUI")
end

local HILFE = {
  "/wb – Fenster öffnen oder schließen",
  "/wb import – Liste vom Berufe-Rechner übernehmen",
  "/wb link – Liste als Link für foreverui.de",
  "/wb leeren – Einkaufsliste leeren",
  "/wb tooltip – Tooltip-Zeilen an oder aus",
  "/wb optionen – Barrierefreiheit und weitere Optionen",
  "/wb vorlesen – Einkaufsliste vorlesen",
  "/wb kontrast · farbenblind · tastatur · sprache – Option an oder aus",
  "/wb groesse 100-200 – Größe in Prozent",
  "/wb liste neu|weiter|zurueck|name Text|loeschen – mehrere Einkaufslisten",
  "/wb gemeinsam – eine Liste für alle Charaktere an oder aus",
  "/wb charaktere – Übersicht deiner Charaktere",
  "/wb vergessen Name – Charakter aus der Werkbank entfernen",
  "/wb chat [gruppe|gilde|sagen] – fehlende Materialien in den Chat",
  "/wb kaufen – beim Händler fehlende Materialien kaufen",
  "/wb bank – Materialien aus der Bank holen",
  "/wb minimap – Knopf an der Minikarte an oder aus",
  "/wb tracker – kleines Fenster mit den fehlenden Materialien",
  "/wb rueckgaengig – letzte Änderung an der Liste zurücknehmen",
  "/wb rezept Name – Detailseite eines Rezepts",
  "/wb wer Gegenstand – wer kann es herstellen, wer hat es",
  "/wb wofuer Gegenstand – in welchen Rezepten es Zutat ist",
  "/wb zufall – zufälliges Rezept vorschlagen",
  "/wb kopieren · zusammenfuehren · uebernehmen Name – Listen",
  "/wb sicherung – alle Listen als Text sichern",
  "/wb abklingzeiten · statistik · sammlung · fehler · assistent – Seiten öffnen",
  "/wb uebersicht · auftraege · preise · ziele · diagnose – Seiten öffnen",
  "/wb auftrag Kunde; Rezept; Anzahl; Lohn; Frist; Notiz – Kundenauftrag anlegen",
  "/wb kunde Name Kontaktweg – Kontakt oder Notiz zu einem Kunden",
  "/wb alarm Gegenstand Preis – Preisalarm (ohne Preis: entfernen)",
  "/wb mindest Gegenstand Anzahl – Mindestbestand (0: entfernen)",
  "/wb ziel Beruf Stufe | Beruf Anzahl rezepte – Berufsziel",
  "/wb vorlage speichern Name | laden Name – Listen-Vorlagen",
  "/wb vergleich Rezept A; Rezept B – zwei Rezepte vergleichen",
  "/wb kompakt – kompaktes Fenster an oder aus",
  "/wb abfragen – im Auktionshaus das nächste fehlende Material suchen",
}

SLASH_WERKBANK1 = "/werkbank"
SLASH_WERKBANK2 = "/wb"
SlashCmdList.WERKBANK = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    ns.Umschalten()
  elseif cmd == "import" then
    if rest ~= "" then
      local n = ns.Import(rest)
      ns.Print(n .. (n == 1 and " Rezept" or " Rezepte") .. " übernommen.")
    else
      ns.ImportDialog()
    end
  elseif cmd == "link" or cmd == "export" then
    ns.ExportDialog()
  elseif cmd == "leeren" then
    ns.ListeLeeren()
    ns.Print("Einkaufsliste geleert.")
  elseif cmd == "tooltip" then
    ns.db.optionen.tooltip = not ns.db.optionen.tooltip
    ns.Print("Tooltip-Zeilen " .. (ns.db.optionen.tooltip and "an." or "aus."))
  elseif cmd == "optionen" or cmd == "barrierefrei" then
    ns.OptionenDialog()
  elseif cmd == "vorlesen" then
    ns.ListeVorlesen()
  elseif cmd == "kontrast" or cmd == "farbenblind" or cmd == "tastatur" or cmd == "sprache" then
    local key = cmd == "sprache" and "vorlesen" or cmd
    ns.db.optionen[key] = not ns.db.optionen[key]
    ns.FarbenAnwenden()
    ns.Aktualisieren()
    local namen = { kontrast = "Hoher Kontrast", farbenblind = "Farbenblind-Modus", tastatur = "Tastatursteuerung", vorlesen = "Vorlesen" }
    ns.Print(namen[key] .. (ns.db.optionen[key] and " an." or " aus."))
    ns.Sprechen(namen[key] .. (ns.db.optionen[key] and " an." or " aus."), true)
  elseif cmd == "groesse" or cmd == "größe" then
    local p = tonumber((rest:gsub("%%", "")))
    if p then
      ns.db.optionen.groesse = math.max(100, math.min(200, p)) / 100
      ns.Aktualisieren()
      ns.Print(("Größe %d %%."):format(ns.Groesse() * 100 + 0.5))
    else
      ns.Print("Bitte eine Zahl zwischen 100 und 200 angeben, z. B. /wb groesse 150")
    end
  elseif cmd == "liste" then
    local was, wert = rest:match("^(%S*)%s*(.-)$")
    was = (was or ""):lower()
    if was == "neu" then
      ns.ListeNeu(wert)
    elseif was == "weiter" or was == "" then
      ns.ListeBlaettern(1)
    elseif was == "zurueck" or was == "zurück" then
      ns.ListeBlaettern(-1)
    elseif was == "name" then
      ns.ListeUmbenennen(wert:sub(1, 40))
    elseif was == "loeschen" or was == "löschen" then
      ns.ListeLoeschen()
    end
    local ort = ns.ListenOrt()
    ns.Print("Aktive Liste: " .. (ns.L.name or "") .. " (" .. ort.aktiv .. " von " .. #ort.listen .. ")")
  elseif cmd == "gemeinsam" then
    ns.db.optionen.gemeinsam = not ns.db.optionen.gemeinsam
    ns.ListeWaehlen()
    ns.Print(ns.db.optionen.gemeinsam and "Alle Charaktere teilen sich jetzt die Einkaufslisten." or "Jeder Charakter hat wieder eigene Einkaufslisten.")
  elseif cmd == "charaktere" or cmd == "chars" then
    ns.CharakterDialog()
  elseif cmd == "vergessen" then
    local key = ns.CharakterVergessen(rest)
    ns.Print(key and (key .. " vergessen.") or "Diesen Charakter kenne ich nicht (der aktuelle lässt sich nicht vergessen).")
  elseif cmd == "chat" then
    ns.ChatTeilen(rest ~= "" and rest or nil)
  elseif cmd == "kaufen" then
    if MerchantFrame and MerchantFrame:IsShown() then ns.FehlendesKaufen() else ns.Print("Dazu muss ein Händler geöffnet sein.") end
  elseif cmd == "bank" then
    ns.MaterialHolen()
  elseif cmd == "tracker" then
    ns.Print("Tracker " .. (ns.TrackerUmschalten() and "an." or "aus."))
  elseif cmd == "rueckgaengig" or cmd == "rückgängig" or cmd == "undo" then
    ns.Rueckgaengig()
  elseif cmd == "rezept" then
    local id = ns.GegenstandSuchen(rest)
    local rid = id and (ns.RezeptFuer(id) or ns.RezeptAusGegenstand(ns.ItemName(id)))
    if not rid then
      local such = rest:lower()
      for x, r in pairs(D.rezepte) do
        if r[1]:lower() == such then rid = x break end
      end
    end
    if rid then ns.RezeptZeigen(rid) else ns.Print("Dieses Rezept kenne ich nicht.") end
  elseif cmd == "wer" then
    ns.Print(ns.WerText(rest))
  elseif cmd == "wofuer" or cmd == "wofür" then
    ns.Print(ns.WofuerText(rest))
  elseif cmd == "zufall" then
    local rid = ns.Ueberrasch()
    if rid then ns.Print("Wie wär's mit " .. ns.RezeptName(rid) .. "?") ns.RezeptZeigen(rid) end
  elseif cmd == "kopieren" then
    ns.ListeKopieren()
    ns.Print("Liste kopiert: " .. (ns.L.name or ""))
  elseif cmd == "zusammenfuehren" or cmd == "zusammenführen" then
    ns.ListenZusammenfuehren()
  elseif cmd == "uebernehmen" or cmd == "übernehmen" then
    ns.TwinkListeUebernehmen(rest)
  elseif cmd == "sicherung" then
    ns.SeiteZeigen("austausch")
    ns.Print("Die Sicherung steht auf der Seite „Austausch“ ganz unten.")
  elseif cmd == "abklingzeiten" or cmd == "statistik" or cmd == "sammlung" or cmd == "fehler" then
    ns.SeiteZeigen(cmd)
  elseif cmd == "assistent" then
    ns.AssistentStarten()
  elseif cmd == "uebersicht" or cmd == "übersicht" or cmd == "preise" or cmd == "ziele" or cmd == "diagnose" or cmd == "erfolge" then
    ns.SeiteZeigen(cmd == "übersicht" and "uebersicht" or cmd == "erfolge" and "ziele" or cmd)
  elseif cmd == "auftraege" or cmd == "aufträge" or cmd == "kunden" then
    ns.SeiteZeigen("auftraege")
  elseif cmd == "auftrag" then
    if rest == "" then ns.SeiteZeigen("auftraege") else ns.AuftragAusText(rest) end
  elseif cmd == "kunde" then
    ns.KundeSetzen(rest)
  elseif cmd == "alarm" then
    ns.AlarmSetzen(rest)
  elseif cmd == "mindest" then
    ns.MindestSetzen(rest)
  elseif cmd == "ziel" then
    ns.ZielSetzen(rest)
  elseif cmd == "vorlage" then
    local was, name = rest:match("^(%S*)%s*(.-)$")
    was = (was or ""):lower()
    if was == "speichern" then ns.VorlageSpeichern(name)
    elseif was == "laden" then ns.VorlageLaden(name)
    elseif was == "loeschen" or was == "löschen" then ns.Print(ns.VorlageLoeschen(name) and "Vorlage gelöscht." or "Diese Vorlage gibt es nicht.")
    else ns.Print("Vorlagen: " .. (#ns.Vorlagen() > 0 and table.concat(ns.Vorlagen(), ", ") or "keine") .. ". /wb vorlage speichern Name · laden Name · loeschen Name") end
  elseif cmd == "vergleich" then
    local a, b = rest:match("^(.-);(.+)$")
    local ra, rb = ns.RezeptSuchen(a), ns.RezeptSuchen(b)
    if ra and rb then ns.VergleichZeigen(ra, rb) else ns.Print("So geht's: /wb vergleich Rezept A; Rezept B") end
  elseif cmd == "kompakt" then
    ns.db.optionen.kompakt = not ns.db.optionen.kompakt
    ns.Aktualisieren()
    ns.Print("Kompaktes Fenster " .. (ns.db.optionen.kompakt and "an." or "aus."))
  elseif cmd == "abfragen" then
    ns.ListeAbfragen()
  elseif cmd == "minimap" then
    ns.db.optionen.minimap = not ns.db.optionen.minimap
    ns.MinimapKnopfZeigen()
    ns.Print("Minimap-Knopf " .. (ns.db.optionen.minimap and "an." or "aus."))
  else
    ns.Print("Befehle:")
    for _, z in ipairs(HILFE) do DEFAULT_CHAT_FRAME:AddMessage("  " .. z) end
  end
end
