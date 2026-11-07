-- Fenster: Rezeptbuch links, Einkaufsliste rechts
local _, ns = ...
local D = ns.daten

local ROW_H = 20
local F = ns.F
local FILTER = { "Alle Rezepte", "Gelernt", "Noch nicht gelernt", "Von meinen Charakteren", "Jetzt herstellbar", "Favoriten" }
local STERN = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"

local ui = {}
ns.ui = ui
local EintragText -- weiter unten definiert

-- ---------- Bausteine ----------

local function Knopf(parent, text, w)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 90, 22)
  b:SetText(text)
  return b
end

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

-- Eine scrollbare Liste aus gleich hohen Zeilen. eintraege ist eine Liste von Tabellen,
-- zeichne(row, eintrag) füllt eine Zeile.
local listenZaehler = 0
local function Liste(parent, w, h, zeichne, klick, enter)
  listenZaehler = listenZaehler + 1
  local name = "WerkbankListe" .. listenZaehler
  local l = CreateFrame("Frame", nil, parent)
  l:SetSize(w, h)
  l.eintraege = {}
  l.rows = {}
  local anzahl = math.floor(h / ROW_H)

  local scroll = CreateFrame("ScrollFrame", name .. "Scroll", l, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  l.scroll = scroll

  function l:Neu()
    local e = self.eintraege
    FauxScrollFrame_Update(scroll, #e, anzahl, ROW_H)
    local off = FauxScrollFrame_GetOffset(scroll)
    for i = 1, anzahl do
      local row = self.rows[i]
      local eintrag = e[i + off]
      row.eintrag = eintrag
      row.index = i + off
      row.auswahl:SetShown(eintrag ~= nil and self.aktiv and self.cursor == i + off)
      if eintrag then
        zeichne(row, eintrag)
        row:Show()
      else
        row:Hide()
      end
    end
  end

  l.anzahl = anzahl
  l.cursor = 1
  l.klick = klick

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
    if ziel <= off then off = ziel - 1 elseif ziel > off + anzahl then off = ziel - anzahl end
    FauxScrollFrame_SetOffset(scroll, off)
    scroll:SetVerticalScroll(off * ROW_H)
    self:Neu()
    return e[ziel]
  end

  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() l:Neu() end)
  end)

  for i = 1, anzahl do
    local row = CreateFrame("Button", nil, l)
    row:SetSize(w - 26, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Markierung für die Tastatursteuerung
    row.auswahl = row:CreateTexture(nil, "BACKGROUND")
    row.auswahl:SetAllPoints()
    row.auswahl:SetColorTexture(1, 0.82, 0.3, 0.25)
    row.auswahl:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 4, ROW_H - 4)
    row.icon:SetPoint("LEFT", 2, 0)
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
    l.rows[i] = row
  end

  return l
end

-- Kopfzeilen in Listen
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

-- ---------- Import und Webseiten-Link ----------

local function Dialog()
  if ui.dialog then return ui.dialog end
  local d = CreateFrame("Frame", "WerkbankDialog", UIParent, "BasicFrameTemplateWithInset")
  d:Hide()
  d:SetSize(460, 210)
  d:SetPoint("CENTER", 0, 80)
  d:SetFrameStrata("DIALOG")
  d:EnableMouse(true)
  d:SetMovable(true)
  d:RegisterForDrag("LeftButton")
  d:SetScript("OnDragStart", d.StartMoving)
  d:SetScript("OnDragStop", d.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WerkbankDialog")
  d.titel = d.TitleText or d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if not d.TitleText then d.titel:SetPoint("TOP", 0, -5) end

  d.info = d:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  d.info:SetPoint("TOPLEFT", 16, -34)
  d.info:SetPoint("TOPRIGHT", -16, -34)
  d.info:SetJustifyH("LEFT")

  d.boxen = {}
  for i = 1, 4 do
    local box = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    box:SetSize(420, 20)
    box:SetPoint("TOPLEFT", 22, -60 - (i - 1) * 28)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() d:Hide() end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box.label = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    box.label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 1)
    d.boxen[i] = box
  end

  d.kontrastBg = d:CreateTexture(nil, "BACKGROUND", nil, 7)
  d.kontrastBg:SetPoint("TOPLEFT", 4, -24)
  d.kontrastBg:SetPoint("BOTTOMRIGHT", -4, 4)
  d.kontrastBg:SetColorTexture(0, 0, 0, 0.92)
  d:HookScript("OnShow", function(self)
    self:SetScale(ns.Groesse())
    self.kontrastBg:SetShown(ns.db.optionen.kontrast and true or false)
  end)

  d.ok = Knopf(d, "Importieren", 110)
  d.ok:SetPoint("BOTTOMRIGHT", -14, 12)
  return d
end

function ns.ImportDialog()
  local d = Dialog()
  d.titel:SetText("Werkbank: Liste importieren")
  d.info:SetText("Link aus dem Berufe-Rechner auf foreverui.de einfügen (Strg+V). Die Rezepte kommen zur Liste dazu.")
  for i, box in ipairs(d.boxen) do
    box:SetText("")
    box.label:SetText("")
    box:SetShown(i == 1)
    box.text = nil
    box:SetScript("OnTextChanged", nil)
    box:SetScript("OnEnterPressed", function() d.ok:Click() end)
  end
  d.ok:SetText("Importieren")
  d.ok:Show()
  d.ok:SetScript("OnClick", function()
    local n = ns.Import(d.boxen[1]:GetText())
    if n > 0 then
      ns.Print(n .. (n == 1 and " Rezept" or " Rezepte") .. " übernommen.")
      d:Hide()
    else
      ns.Print("In dem Text war kein Rezept zu finden.")
    end
  end)
  d:Show()
  d.boxen[1]:SetFocus()
end

function ns.ExportDialog()
  local links = ns.Export()
  if #links == 0 then
    ns.Print("Die Liste ist leer.")
    return
  end
  local d = Dialog()
  d.titel:SetText("Werkbank: Liste auf foreverui.de")
  d.info:SetText("Link markieren und mit Strg+C kopieren. Der Berufe-Rechner hat je Beruf eine eigene Seite.")
  d.ok:Hide()
  for i, box in ipairs(d.boxen) do
    local l = links[i]
    box:SetShown(l ~= nil)
    if l then
      box.text = l.url
      box.label:SetText(l.beruf.name)
      box:SetText(l.url)
      box:SetCursorPosition(0)
      -- Text soll sich nicht verändern lassen
      box:SetScript("OnTextChanged", function(self, user)
        if user then
          self:SetText(self.text)
          self:HighlightText()
        end
      end)
      box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    end
  end
  if #links > #d.boxen then ns.Print("Nur die ersten " .. #d.boxen .. " Berufe werden angezeigt.") end
  d:Show()
  d.boxen[1]:SetFocus()
end

function ns.UmbenennenDialog()
  local d = Dialog()
  d.titel:SetText("Werkbank: Liste umbenennen")
  d.info:SetText("Neuer Name für die Liste „" .. (ns.L.name or "") .. "“, z. B. „Schneiderei 150“ oder „Gildenbank“.")
  for i, box in ipairs(d.boxen) do
    box:SetText(i == 1 and (ns.L.name or "") or "")
    box.label:SetText("")
    box:SetShown(i == 1)
    box.text = nil
    box:SetScript("OnTextChanged", nil)
    box:SetScript("OnEnterPressed", function() d.ok:Click() end)
  end
  d.ok:SetText("Übernehmen")
  d.ok:Show()
  d.ok:SetScript("OnClick", function()
    local name = (d.boxen[1]:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name ~= "" then ns.ListeUmbenennen(name:sub(1, 40)) end
    d:Hide()
  end)
  d:Show()
  d.boxen[1]:SetFocus()
end

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

function ns.CharakterDialog()
  if ui.chars then
    ui.chars:SetShown(not ui.chars:IsShown())
    return
  end
  local d = CreateFrame("Frame", "WerkbankCharaktere", UIParent, "BasicFrameTemplateWithInset")
  ui.chars = d
  d:Hide()
  d:SetSize(460, 380)
  d:SetPoint("CENTER", 0, 40)
  d:SetFrameStrata("DIALOG")
  d:EnableMouse(true)
  d:SetMovable(true)
  d:RegisterForDrag("LeftButton")
  d:SetScript("OnDragStart", d.StartMoving)
  d:SetScript("OnDragStop", d.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WerkbankCharaktere")
  local titel = d.TitleText or d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if not d.TitleText then titel:SetPoint("TOP", 0, -5) end
  titel:SetText("Werkbank: Deine Charaktere")

  local bg = d:CreateTexture(nil, "BACKGROUND", nil, 7)
  bg:SetPoint("TOPLEFT", 4, -24)
  bg:SetPoint("BOTTOMRIGHT", -4, 4)
  bg:SetColorTexture(0, 0, 0, 0.92)

  local scroll = CreateFrame("ScrollFrame", "WerkbankCharaktereScroll", d, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -32)
  scroll:SetPoint("BOTTOMRIGHT", -32, 44)
  local inhalt = CreateFrame("Frame", nil, scroll)
  inhalt:SetSize(400, 10)
  scroll:SetScrollChild(inhalt)
  local text = inhalt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOPLEFT")
  text:SetWidth(400)
  text:SetJustifyH("LEFT")

  local hinweis = d:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hinweis:SetPoint("BOTTOMLEFT", 16, 16)
  hinweis:SetPoint("BOTTOMRIGHT", -16, 16)
  hinweis:SetJustifyH("LEFT")
  hinweis:SetText(F.grau .. "Jeder Charakter wird beim Einloggen erfasst. Entfernen: /wb vergessen Name|r")

  d:SetScript("OnShow", function(self)
    self:SetScale(ns.Groesse())
    bg:SetShown(ns.db.optionen.kontrast and true or false)
    local t = ns.CharakterText()
    text:SetText(t)
    inhalt:SetHeight((text.GetStringHeight and text:GetStringHeight() or 10) + 10)
    ns.Sprechen(t)
  end)
  d:Show()
end

-- ---------- Hauptfenster ----------

local function Neu()
  if not ui.frame or not ui.frame:IsShown() then return end
  local o = ns.db.optionen
  ui.frame:SetScale(ns.Groesse())
  ui.kontrastBg:SetShown(o.kontrast and true or false)
  if not InCombatLockdown() then ui.frame:EnableKeyboard(o.tastatur and true or false) end
  ui.buch.aktiv = o.tastatur and ui.aktiv ~= "liste"
  ui.liste.aktiv = o.tastatur and ui.aktiv == "liste"
  ui.buch.eintraege = RezeptbuchEintraege()
  ui.buch:Neu()
  ui.liste.eintraege = ListeEintraege()
  ui.liste:Neu()
  for _, b in ipairs(ui.berufKnoepfe) do
    b:SetChecked(b.id == ui.beruf)
    local c = ns.char.berufe[b.id]
    b.icon:SetDesaturated(not c)
  end
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
  local text = b and (F.gold .. b.name .. "|r") or ""
  if c then text = text .. "  " .. F.weiss .. (c.stufe or 0) .. "/" .. (c.max or 0) .. "|r" end
  if b then text = text .. "  " .. F.grau .. gelernt .. " von " .. b.anzahl .. " Rezepten gelernt|r" end
  ui.kopf:SetText(text)
  local ort = ns.ListenOrt()
  ui.listeTitel:SetText((ns.L.name or "Liste") .. (ns.db.optionen.gemeinsam and " (gemeinsam)" or "")
    .. (#ort.listen > 1 and (F.grau .. "  " .. ort.aktiv .. "/" .. #ort.listen .. "|r") or ""))
end
ns.BeiAenderung(Neu)

local function Bauen()
  local f = CreateFrame("Frame", "WerkbankFrame", UIParent, "BasicFrameTemplateWithInset")
  ui.frame = f
  f:Hide() -- neue Fenster sind sichtbar, Umschalten soll es erst öffnen
  f:SetSize(760, 520)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.optionen.pos = { p, rp, x, y }
  end)
  f:SetScript("OnShow", Neu)

  -- Hoher Kontrast: fast undurchsichtiger Hintergrund
  ui.kontrastBg = f:CreateTexture(nil, "BACKGROUND", nil, 7)
  ui.kontrastBg:SetPoint("TOPLEFT", 4, -24)
  ui.kontrastBg:SetPoint("BOTTOMRIGHT", -4, 4)
  ui.kontrastBg:SetColorTexture(0, 0, 0, 0.92)
  ui.kontrastBg:Hide()

  -- Tastatursteuerung (in den Optionen einschalten)
  pcall(f.SetPropagateKeyboardInput, f, true)
  f:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    local erledigt = ns.FensterTaste(key)
    self:SetPropagateKeyboardInput(not erledigt)
  end)
  tinsert(UISpecialFrames, "WerkbankFrame")
  local pos = ns.db.optionen.pos
  if pos then
    f:ClearAllPoints()
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end

  local titel = f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if not f.TitleText then titel:SetPoint("TOP", 0, -5) end
  titel:SetText("Werkbank")

  -- Berufe als Symbolknöpfe
  ui.berufKnoepfe = {}
  local x = 14
  for _, b in ipairs(D.berufe) do
    local k = CreateFrame("CheckButton", nil, f)
    k:SetSize(30, 30)
    k:SetPoint("TOPLEFT", x, -30)
    k.id = b.id
    k.icon = k:CreateTexture(nil, "ARTWORK")
    k.icon:SetAllPoints()
    k.icon:SetTexture(b.icon or 134400)
    -- Eigene Texturen mit ADD-Blending, sonst deckt die Markierung das Symbol zu
    local an = k:CreateTexture(nil, "OVERLAY")
    an:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    an:SetBlendMode("ADD")
    an:SetAllPoints()
    k:SetCheckedTexture(an)
    local hl = k:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    k:SetHighlightTexture(hl)
    k:SetScript("OnClick", function()
      ui.beruf = b.id
      FauxScrollFrame_SetOffset(ui.buch.scroll, 0)
      ui.buch.scroll:SetVerticalScroll(0)
      Neu()
    end)
    k:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(b.name, 1, 1, 1)
      GameTooltip:AddLine(b.anzahl .. " Rezepte", 0.7, 0.7, 0.7)
      local c = ns.char.berufe[b.id]
      if c then GameTooltip:AddLine("Deine Stufe: " .. (c.stufe or 0) .. "/" .. (c.max or 0), 0.25, 0.75, 0.25) end
      GameTooltip:Show()
    end)
    k:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.berufKnoepfe[#ui.berufKnoepfe + 1] = k
    x = x + 34
  end

  ui.kopf = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  ui.kopf:SetPoint("TOPLEFT", 16, -70)
  ui.kopf:SetJustifyH("LEFT")

  -- Suche und Filter
  local suche = CreateFrame("EditBox", "WerkbankSuche", f, "InputBoxTemplate")
  suche:SetSize(220, 20)
  suche:SetPoint("TOPLEFT", 22, -92)
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
  local filter = Knopf(f, FILTER[1], 150)
  filter:SetPoint("LEFT", suche, "RIGHT", 10, 0)
  filter:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  filter:SetScript("OnClick", function(self, btn)
    ui.filter = (ui.filter - 1 + (btn == "RightButton" and -1 or 1)) % #FILTER + 1
    self:SetText(FILTER[ui.filter])
    ns.Sprechen("Filter " .. FILTER[ui.filter])
    Neu()
  end)
  ui.filterKnopf = filter
  Tipp(filter, "Filter", "Klick: nächster Filter, Rechtsklick: voriger.", "Alle, Gelernt, Noch nicht gelernt, Von meinen Charakteren gelernt, Jetzt herstellbar, Favoriten.", "Gelernte Rezepte erfasst die Werkbank, sobald du das Berufsfenster öffnest.")

  -- Listen
  ui.buch = Liste(f, 420, 360, ZeichneRezept, KlickRezept, EnterRezept)
  ui.buch:SetPoint("TOPLEFT", 14, -120)

  local trenner = f:CreateTexture(nil, "ARTWORK")
  trenner:SetColorTexture(1, 1, 1, 0.08)
  trenner:SetSize(1, 400)
  trenner:SetPoint("TOPLEFT", 440, -96)

  local listeTitel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  listeTitel:SetPoint("TOPLEFT", 452, -95)
  listeTitel:SetPoint("RIGHT", f, "RIGHT", -140, 0)
  listeTitel:SetJustifyH("LEFT")
  listeTitel:SetWordWrap(false)
  ui.listeTitel = listeTitel

  -- Zwischen mehreren Listen wechseln
  local function Angesagt()
    ns.Sprechen("Liste " .. (ns.L.name or ""))
  end
  local naechste = Knopf(f, ">", 24)
  naechste:SetPoint("TOPRIGHT", -14, -91)
  naechste:SetScript("OnClick", function() ns.ListeBlaettern(1) Angesagt() end)
  Tipp(naechste, "Nächste Liste")
  local vorige = Knopf(f, "<", 24)
  vorige:SetPoint("RIGHT", naechste, "LEFT", -2, 0)
  vorige:SetScript("OnClick", function() ns.ListeBlaettern(-1) Angesagt() end)
  Tipp(vorige, "Vorige Liste")
  local neueListe = Knopf(f, "+", 24)
  neueListe:SetPoint("RIGHT", vorige, "LEFT", -2, 0)
  neueListe:SetScript("OnClick", function() ns.ListeNeu() Angesagt() end)
  Tipp(neueListe, "Neue Liste", "Legt eine weitere, leere Einkaufsliste an.")
  local umbenennen = Knopf(f, "Name", 44)
  umbenennen:SetPoint("RIGHT", neueListe, "LEFT", -2, 0)
  umbenennen:SetScript("OnClick", function() ns.UmbenennenDialog() end)
  Tipp(umbenennen, "Liste umbenennen")

  ui.liste = Liste(f, 300, 360, ZeichneListe, KlickListe, EnterListe)
  ui.liste:SetPoint("TOPLEFT", 450, -120)

  -- Knöpfe unten
  local leeren = Knopf(f, "Leeren", 80)
  leeren:SetPoint("BOTTOMRIGHT", -14, 12)
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

  local web = Knopf(f, "Webseite", 90)
  web:SetPoint("RIGHT", leeren, "LEFT", -4, 0)
  web:SetScript("OnClick", ns.ExportDialog)
  Tipp(web, "Zum Berufe-Rechner", "Erzeugt einen Link zu foreverui.de/berufe mit deiner Liste.")

  local imp = Knopf(f, "Import", 80)
  imp:SetPoint("RIGHT", web, "LEFT", -4, 0)
  imp:SetScript("OnClick", ns.ImportDialog)
  Tipp(imp, "Liste importieren", "Link aus dem Berufe-Rechner auf foreverui.de einfügen.")

  local opt = Knopf(f, "Optionen", 90)
  opt:SetPoint("RIGHT", imp, "LEFT", -4, 0)
  opt:SetScript("OnClick", function() ns.OptionenDialog() end)
  Tipp(opt, "Optionen", "Vorlesen, hoher Kontrast, Farbenblind-Modus, Größe und Tastatursteuerung.")

  local chars = Knopf(f, "Charaktere", 90)
  chars:SetPoint("RIGHT", opt, "LEFT", -4, 0)
  chars:SetScript("OnClick", function() ns.CharakterDialog() end)
  Tipp(chars, "Deine Charaktere", "Berufe und gelernte Rezepte aller Charaktere, die die Werkbank kennt.")

  local fuss = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  fuss:SetPoint("BOTTOMLEFT", 18, 18)
  fuss:SetPoint("RIGHT", chars, "LEFT", -8, 0)
  fuss:SetJustifyH("LEFT")
  fuss:SetText("Klick +1 · Strg +5 · Rechts −1 · Alt: Favorit")

  -- Startberuf: der erste, den der Charakter hat
  for _, b in ipairs(D.berufe) do
    if ns.char.berufe[b.id] then
      ui.beruf = b.id
      break
    end
  end
  ui.beruf = ui.beruf or D.berufe[1].id
end

function ns.Umschalten(berufId)
  if not ui.frame then Bauen() end
  if berufId then
    ui.beruf = berufId
    if ui.frame:IsShown() then Neu() else ui.frame:Show() end
    return
  end
  ui.frame:SetShown(not ui.frame:IsShown())
end

function ns.Oeffnen(berufId)
  if not ui.frame then Bauen() end
  if berufId then ui.beruf = berufId end
  ui.frame:Show()
  Neu()
end

-- ---------- Tastatursteuerung im Fenster ----------
-- Pfeile: bewegen · Links/Rechts: Rezeptbuch oder Liste · Eingabe: +1 · Rücktaste/Entf: −1
-- Tab: nächster Beruf · Leertaste: vorlesen · Strg+F: Suche · M: Favorit · Esc: schließen

local function Vorlesen(e, immer)
  local text = EintragText(e)
  if immer and not ns.Sprechen(text, true) then ns.Print(ns.Sauber(text)) end
  if not immer then ns.Sprechen(text) end
end

function ns.FensterTaste(key)
  if not ui.frame or not ns.db.optionen.tastatur then return false end
  local l = ui.aktiv == "liste" and ui.liste or ui.buch
  local e = l.eintraege[l.cursor]
  if key == "ESCAPE" then
    ui.frame:Hide()
  elseif key == "UP" or key == "DOWN" or key == "PAGEUP" or key == "PAGEDOWN" or key == "HOME" or key == "END" then
    local ziel = ({ UP = l.cursor - 1, DOWN = l.cursor + 1, PAGEUP = l.cursor - l.anzahl,
      PAGEDOWN = l.cursor + l.anzahl, HOME = 1, END = #l.eintraege })[key]
    Vorlesen(l:Gehe(ziel))
  elseif key == "LEFT" or key == "RIGHT" then
    ui.aktiv = key == "RIGHT" and "liste" or "buch"
    l = ui.aktiv == "liste" and ui.liste or ui.buch
    Neu()
    local neu = l:Gehe(l.cursor)
    ns.Sprechen((ui.aktiv == "liste" and "Einkaufsliste. " or "Rezeptbuch. ") .. EintragText(neu))
  elseif key == "TAB" then
    local idx = 1
    for i, b in ipairs(D.berufe) do if b.id == ui.beruf then idx = i end end
    idx = (idx - 1 + (IsShiftKeyDown() and -1 or 1)) % #D.berufe + 1
    ui.beruf = D.berufe[idx].id
    ui.aktiv = "buch"
    ui.buch.cursor = 1
    Neu()
    local erst = ui.buch:Gehe(1)
    ns.Sprechen(D.berufe[idx].name .. ". " .. EintragText(erst))
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

-- ---------- Optionen ----------

local OPTIONEN = {
  { "vorlesen", "Vorlesen", "Liest Rezepte und Listeneinträge beim Darüberfahren oder Auswählen mit der Sprachausgabe des Spiels vor." },
  { "kontrast", "Hoher Kontrast", "Fast undurchsichtiger Hintergrund und hellere Nebentexte." },
  { "farbenblind", "Farbenblind-Modus", "Blau statt Grün und Orange statt Rot. Fehlende Mengen stehen zusätzlich als Wort da." },
  { "tastatur", "Tastatursteuerung im Fenster", "Pfeiltasten bewegen, Links/Rechts wechselt zwischen Rezeptbuch und Liste, Eingabe +1, Rücktaste −1, Tab nächster Beruf, Leertaste vorlesen, Strg+F Suche, Esc schließt." },
  { "tooltip", "Zeilen in Gegenstands-Tooltips", "Zeigt an Materialien und hergestellten Gegenständen, wofür sie gebraucht werden, wer sie herstellen kann und wie viele deine anderen Charaktere haben." },
  { "gemeinsam", "Eine Einkaufsliste für alle Charaktere", "Alle Charaktere teilen sich dieselben Listen. Aus: jeder Charakter hat eigene Listen." },
  { "abhaken", "Nach dem Herstellen abhaken", "Stellst du etwas von der Liste her, wird es automatisch um eins verringert." },
  { "lootMeldung", "Fortschritt beim Sammeln melden", "Meldet im Chat, wenn ein Material von der Liste dazukommt, z. B. „Leinenstoff 7/10“." },
  { "fertigMeldung", "Melden, wenn alles da ist", "Meldung, Ton und Sprachausgabe, sobald alle Materialien der Liste beisammen sind." },
  { "minimap", "Knopf an der Minikarte", "Klick öffnet die Werkbank, Rechtsklick die Optionen. Zum Verschieben ziehen." },
}
local ABSTAND = 28

function ns.OptionenDialog()
  if ui.optionen then
    ui.optionen:SetShown(not ui.optionen:IsShown())
    return
  end
  local d = CreateFrame("Frame", "WerkbankOptionen", UIParent, "BasicFrameTemplateWithInset")
  ui.optionen = d
  d:Hide()
  d:SetSize(440, 34 + #OPTIONEN * ABSTAND + 100)
  d:SetPoint("CENTER", 0, 40)
  d:SetFrameStrata("DIALOG")
  d:EnableMouse(true)
  d:SetMovable(true)
  d:RegisterForDrag("LeftButton")
  d:SetScript("OnDragStart", d.StartMoving)
  d:SetScript("OnDragStop", d.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WerkbankOptionen")
  local titel = d.TitleText or d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if not d.TitleText then titel:SetPoint("TOP", 0, -5) end
  titel:SetText("Werkbank: Optionen")

  local bg = d:CreateTexture(nil, "BACKGROUND", nil, 7)
  bg:SetPoint("TOPLEFT", 4, -24)
  bg:SetPoint("BOTTOMRIGHT", -4, 4)
  bg:SetColorTexture(0, 0, 0, 0.92)

  local kaesten = {}
  for i, opt in ipairs(OPTIONEN) do
    local cb = CreateFrame("CheckButton", nil, d, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, -30 - (i - 1) * ABSTAND)
    cb.label = cb.Text or cb.text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    if not (cb.Text or cb.text) then cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0) end
    cb.label:SetText(opt[2])
    cb:SetScript("OnClick", function(self)
      ns.db.optionen[opt[1]] = self:GetChecked() and true or false
      ns.FarbenAnwenden()
      if opt[1] == "gemeinsam" then ns.ListeWaehlen() end
      if opt[1] == "minimap" and ns.MinimapKnopfZeigen then ns.MinimapKnopfZeigen() end
      ns.Aktualisieren()
      ns.Sprechen(opt[2] .. (self:GetChecked() and " an." or " aus."), true)
    end)
    Tipp(cb, opt[2], opt[3])
    kaesten[opt[1]] = cb
  end

  local groesse = Knopf(d, "Größe: 100 %", 160)
  groesse:SetPoint("TOPLEFT", 22, -30 - #OPTIONEN * ABSTAND - 6)
  local function GroesseText() groesse:SetText(("Größe: %d %%"):format(ns.Groesse() * 100 + 0.5)) end
  groesse:SetScript("OnClick", function()
    local jetzt, naechste = ns.Groesse(), ns.GROESSEN[1]
    for i, g in ipairs(ns.GROESSEN) do
      if math.abs(g - jetzt) < 0.01 then naechste = ns.GROESSEN[i % #ns.GROESSEN + 1] end
    end
    ns.db.optionen.groesse = naechste
    GroesseText()
    d:SetScale(naechste)
    ns.Aktualisieren()
    ns.Sprechen(("Größe %d Prozent"):format(naechste * 100 + 0.5), true)
  end)
  Tipp(groesse, "Größe", "Fenster und Dialoge in 100, 125, 150 oder 200 Prozent.")

  local hinweis = d:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hinweis:SetPoint("BOTTOMLEFT", 16, 14)
  hinweis:SetPoint("BOTTOMRIGHT", -16, 14)
  hinweis:SetJustifyH("LEFT")
  hinweis:SetText("Tastenkürzel ohne Fenster: Tastaturbelegung › AddOns › Werkbank.\nDaten: Blizzard Entertainment, Stand " .. D.stand)

  d:SetScript("OnShow", function(self)
    for key, cb in pairs(kaesten) do cb:SetChecked(ns.db.optionen[key] and true or false) end
    GroesseText()
    self:SetScale(ns.Groesse())
    bg:SetShown(ns.db.optionen.kontrast and true or false)
  end)
  ns.BeiAenderung(function()
    if d:IsShown() then bg:SetShown(ns.db.optionen.kontrast and true or false) end
  end)
  d:Show()
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
      if ui.optionen and ui.optionen:IsShown() then ui.optionen:SetScale(ns.Groesse()) end
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
