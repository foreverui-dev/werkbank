-- Fenster im einheitlichen ForeverUI-Design: ein Hauptfenster, links die Seitenleiste,
-- rechts der Inhaltskasten mit Rezeptbuch und Einkaufsliste, Charakteren, Austausch, Optionen und Hilfe
local _, ns = ...
local D = ns.daten
local S = ns.Stil

local ROW_H = 20
local F = ns.F
local FILTER = { "Alle Rezepte", "Gelernt", "Noch nicht gelernt", "Von meinen Charakteren", "Jetzt herstellbar", "Favoriten" }
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
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(F.grau .. "Klick: auf die Liste  ·  Umschalt-Klick: in den Chat|r")
  GameTooltip:AddLine(F.grau .. "Alt-Klick: Favorit an oder aus|r")
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

local function RezeptbuchEintraege()
  local b = ns.beruf[ui.beruf]
  local such = (ui.suche:GetText() or ""):lower()
  local filter = ui.filter
  local e = {}
  if not b then return e end
  for _, k in ipairs(b.kat) do
    local kopf = { kopf = k[1] }
    local n0 = #e
    e[#e + 1] = kopf
    for _, rid in ipairs(k[2]) do
      local bekannt = ns.char.bekannt[rid]
      local ok = filter == 1 or (filter == 2 and bekannt) or (filter == 3 and not bekannt)
        or (filter == 4 and ns.IrgendwerKennt(rid))
        or (filter == 5 and ns.Moeglich(rid) > 0)
        or (filter == 6 and ns.db.favoriten[rid])
      if ok and such ~= "" then
        ok = ns.RezeptName(rid):lower():find(such, 1, true) ~= nil
        -- auch nach Zutaten suchen
        if not ok then
          local z = D.rezepte[rid][4]
          for i = 1, #z, 2 do
            if ns.ItemName(z[i]):lower():find(such, 1, true) then
              ok = true
              break
            end
          end
        end
      end
      if ok then e[#e + 1] = { rid = rid } end
    end
    if #e == n0 + 1 then
      e[#e] = nil
    else
      kopf.rechts = F.grau .. (#e - n0 - 1) .. "|r"
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
  if not e.rid then return end
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
  table.sort(rids, function(a, b) return ns.RezeptName(a) < ns.RezeptName(b) end)
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
  for _, id in ipairs(ids) do e[#e + 1] = { mat = id, n = bedarf[id] } end

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
    local r = D.rezepte[rid]
    local farbe = r[2] and ns.QualitaetFarbe(r[2]) or F.weiss
    ZeichneZeile(row, ns.RezeptIcon(rid), F.gold .. ns.L.liste[rid] .. "×|r " .. farbe .. ns.RezeptName(rid) .. "|r")
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
    GameTooltip:Show()
  elseif e.mat then
    local zusatz = {}
    local _, wer = ns.TwinkVorrat(e.mat)
    if #wer > 0 then zusatz[#zusatz + 1] = "Bei deinen anderen Charakteren: " .. table.concat(wer, ", ") end
    local hersteller = ns.madeBy[e.mat] and ns.HerstellerVon(e.mat) or {}
    if #hersteller > 0 then zusatz[#zusatz + 1] = "Herstellen kann es: " .. table.concat(hersteller, ", ") end
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
  if e.liste then return ns.L.liste[e.liste] .. " mal " .. ns.RezeptName(e.liste) .. " herstellen." end
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

local function LeisteEintraege()
  local gruppen = {}
  local berufe = { kopf = "Berufe" }
  for _, b in ipairs(D.berufe) do berufe[#berufe + 1] = { seite = "rezepte", beruf = b.id, text = b.name } end
  gruppen[1] = berufe
  gruppen[2] = { kopf = "Planen",
    { seite = "charaktere", text = "Charaktere" },
    { seite = "austausch", text = "Austausch mit foreverui.de" } }
  gruppen[3] = { kopf = "Zugang",
    { seite = "barrierefreiheit", text = "Barrierefreiheit" },
    { seite = "funktionen", text = "Funktionen" },
    { seite = "darstellung", text = "Darstellung" } }
  gruppen[4] = { kopf = "Hilfe",
    { seite = "neuigkeiten", text = "Neuigkeiten" },
    { seite = "bedienung", text = "Bedienung" },
    { seite = "discord", text = "Discord und Feedback" } }
  return gruppen
end

local function EintragAktiv(e)
  return e.seite == ui.seite and (not e.beruf or e.beruf == ui.beruf)
end

-- Nächster oder voriger Eintrag der Seitenleiste (Tab, Pfeile)
function ns.LeisteSchritt(schritt)
  local alle = ui.leisteEintraege
  local idx = 1
  for i, e in ipairs(alle) do if EintragAktiv(e) then idx = i end end
  idx = (idx - 1 + schritt) % #alle + 1
  ns.SeiteZeigen(alle[idx].seite, alle[idx].beruf)
  return alle[idx]
end

local function BaueLeiste(f)
  local leiste = CreateFrame("Frame", nil, f)
  ui.leiste = leiste
  leiste:SetPoint("TOPLEFT", 12, -72)
  leiste:SetPoint("BOTTOMLEFT", 12, 44)
  leiste:SetWidth(LEISTE_B)
  leiste.hg = S.Flaeche(leiste, S.HG[1], S.HG[2], S.HG[3], 0.5)
  ui.leisteEintraege, ui.leisteKnoepfe = {}, {}
  local y = -8
  for _, g in ipairs(LeisteEintraege()) do
    local kopf = leiste:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    kopf:SetPoint("TOPLEFT", 10, y)
    kopf:SetText(g.kopf:upper())
    S.AkzentText(kopf)
    y = y - 18
    for _, e in ipairs(g) do
      local k = CreateFrame("Button", nil, leiste)
      k:SetHeight(16)
      k:SetPoint("TOPLEFT", 4, y)
      k:SetPoint("RIGHT", leiste, "RIGHT", -4, 0)
      S.Zeile(k)
      k.text = k:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      k.text:SetPoint("LEFT", 10, 0)
      k.text:SetJustifyH("LEFT")
      k.rechts = k:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      k.rechts:SetPoint("RIGHT", -4, 0)
      k.eintrag = e
      k:SetScript("OnClick", function()
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
          if c then GameTooltip:AddLine("Deine Stufe: " .. (c.stufe or 0) .. "/" .. (c.max or 0), 0.45, 0.85, 0.45) end
          local wer = {}
          for _, x in pairs(ns.db.chars) do
            if x ~= ns.char and x.berufe and x.berufe[b.id] then wer[#wer + 1] = (x.name or "?") .. " " .. (x.berufe[b.id].stufe or 0) end
          end
          table.sort(wer)
          if #wer > 0 then GameTooltip:AddLine("Andere Charaktere: " .. table.concat(wer, ", "), 0.55, 0.55, 0.55, true) end
          GameTooltip:Show()
        end)
        k:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
      ui.leisteEintraege[#ui.leisteEintraege + 1] = e
      ui.leisteKnoepfe[#ui.leisteKnoepfe + 1] = k
      y = y - 16
    end
    y = y - 8
  end

  local version = leiste:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", 10, 8)
  local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local v = GetMeta and GetMeta("Werkbank", "Version")
  if not v or v:find("@", 1, true) then v = "Entwicklung" end
  version:SetText("Version " .. v)
end

local function LeisteNeu()
  for _, k in ipairs(ui.leisteKnoepfe) do
    local e = k.eintrag
    k:Gewaehlt(EintragAktiv(e))
    if e.beruf then
      local c = ns.char.berufe[e.beruf]
      k.text:SetText((c and F.weiss or F.grau) .. e.text .. "|r")
      k.rechts:SetText(c and tostring(c.stufe or 0) or "")
    else
      k.text:SetText(F.weiss .. e.text .. "|r")
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
    local cb = CreateFrame("CheckButton", nil, feld, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", -4, 2)
    local t = feld:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 28, -4)
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
  titelKnopf:SetScript("OnClick", function() ns.UmbenennenDialog() end)
  Tipp(titelKnopf, "Einkaufsliste", "Klick: Liste umbenennen.")

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

  local leeren = Knopf(p, "Leeren", 80)
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
  local vorlesen = Knopf(p, "Vorlesen", 80)
  vorlesen:SetPoint("RIGHT", leeren, "LEFT", -4, 0)
  vorlesen:SetScript("OnClick", ns.ListeVorlesen)
  Tipp(vorlesen, "Einkaufsliste vorlesen", "Liest vor, was hergestellt wird und was noch fehlt.")
  local teilen = Knopf(p, "In den Chat", 96)
  teilen:SetPoint("RIGHT", vorlesen, "LEFT", -4, 0)
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
    if b then text = text .. F.grau .. gelernt .. " von " .. b.anzahl .. " Rezepten gelernt|r" end
    ui.kopf:SetText(text)
    local ort = ns.ListenOrt()
    ui.listeTitel:SetText((ns.L.name or "Liste") .. (o.gemeinsam and " (gemeinsam)" or "")
      .. (#ort.listen > 1 and (F.grau .. "  " .. ort.aktiv .. "/" .. #ort.listen .. "|r") or ""))
    p.titel = b and b.name or "Rezeptbuch"
  end
end

-- ---------- Seite: Charaktere ----------

local function BaueCharakterSeite()
  local p = TextSeite("charaktere", "Deine Charaktere", function()
    return ns.CharakterText() .. "\n\n" .. F.grau .. "Jeder Charakter wird beim Einloggen erfasst, Taschen sofort, die Bank beim nächsten Besuch. Entfernen: /wb vergessen Name|r"
  end)
  return p
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
    local n = ns.Import(box:GetText())
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
    k:SetPoint("TOPLEFT", 6, -160 - (i - 1) * 40)
    k:SetPoint("RIGHT", p, "RIGHT", -6, 0)
    p.boxen[i] = k
  end
  p.leer = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  p.leer:SetPoint("TOPLEFT", 6, -150)
  p.leer:SetText("Die aktive Liste ist leer.")
  p.Neu = function()
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
    { "minimap", "Knopf an der Minikarte", "Klick öffnet die Werkbank, Rechtsklick die Optionen. Zum Verschieben ziehen.",
      danach = function() if ns.MinimapKnopfZeigen then ns.MinimapKnopfZeigen() end end },
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
  local zurueck = Knopf(p, "Seite zurücksetzen", 150)
  zurueck:SetPoint("BOTTOMRIGHT", 0, 0)
  zurueck:SetScript("OnClick", function()
    ns.db.optionen.akzent = ns.STANDARD.akzent
    ns.db.optionen.groesse = ns.STANDARD.groesse
    ns.FarbenAnwenden()
    ns.Aktualisieren()
    ns.Sprechen("Seite zurückgesetzt.", true)
  end)
  p.Neu = function()
    ka.Anordnen()
    kg.Anordnen()
  end
end

-- ---------- Seiten: Hilfe ----------

local NEUIGKEITEN = {
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
  "Befehle: /wb hilfe",
}

local function BaueHilfeSeiten()
  TextSeite("neuigkeiten", "Neuigkeiten", function() return table.concat(NEUIGKEITEN, "\n") end)
  TextSeite("bedienung", "Bedienung", function() return table.concat(BEDIENUNG, "\n") end)
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
    d:Fest("https://discord.gg/KFPPhER4Y2")
    w:Fest("https://foreverui.de/addons/werkbank/")
  end
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

local function Bauen()
  local o = ns.db.optionen
  local f = S.Fenster("WerkbankFrame", 980, 620)
  ui.frame = f
  S.Mindestgroesse(f, 900, 580)
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
  Tipp(filter, "Filter", "Klick: nächster Filter, Rechtsklick: voriger.", "Alle, Gelernt, Noch nicht gelernt, Von meinen Charakteren gelernt, Jetzt herstellbar, Favoriten.", "Gelernte Rezepte erfasst die Werkbank, sobald du das Berufsfenster öffnest.")

  BaueLeiste(f)
  ui.inhalt = S.Kasten(f)
  ui.inhalt:SetPoint("TOPLEFT", ui.leiste, "TOPRIGHT", 12, 0)
  ui.inhalt:SetPoint("BOTTOMRIGHT", -12, 44)

  BaueRezeptSeite()
  BaueCharakterSeite()
  BaueAustauschSeite()
  BaueOptionsSeiten()
  BaueHilfeSeiten()

  -- Unten: Hinweis links, Schließen rechts
  local schliessen = Knopf(f, "Schließen", 100)
  schliessen:SetPoint("BOTTOMRIGHT", -24, 12)
  schliessen:SetScript("OnClick", function() f:Hide() end)
  local fuss = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  fuss:SetPoint("BOTTOMLEFT", 22, 18)
  fuss:SetPoint("RIGHT", schliessen, "LEFT", -8, 0)
  fuss:SetJustifyH("LEFT")
  fuss:SetText("Klick +1 · Strg +5 · Rechtsklick −1 · Alt: Favorit · Umschalt: in den Chat")

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
  elseif cmd == "minimap" then
    ns.db.optionen.minimap = not ns.db.optionen.minimap
    ns.MinimapKnopfZeigen()
    ns.Print("Minimap-Knopf " .. (ns.db.optionen.minimap and "an." or "aus."))
  else
    ns.Print("Befehle:")
    for _, z in ipairs(HILFE) do DEFAULT_CHAT_FRAME:AddMessage("  " .. z) end
  end
end
