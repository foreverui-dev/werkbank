-- Fenster: Rezeptbuch links, Einkaufsliste rechts
local _, ns = ...
local D = ns.daten

local ROW_H = 20
local GRAU, GRUEN, ROT, GOLD, WEISS = "|cff9d9d9d", "|cff40c040", "|cffff5050", "|cffe0b45a", "|cffffffff"
local FILTER = { "Alle Rezepte", "Gelernt", "Noch nicht gelernt" }

local ui = {}
ns.ui = ui

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
      if eintrag then
        zeichne(row, eintrag)
        row:Show()
      else
        row:Hide()
      end
    end
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
  row.text:SetText(GOLD .. e.kopf .. "|r")
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
  GameTooltip:AddLine(GOLD .. (b and b.name or "") .. "|r " .. GRAU .. (ns.katOf[rid] or "") .. "|r")
  local z = r[4]
  for i = 1, #z, 2 do
    local id, n = z[i], z[i + 1]
    local hat = ns.Vorrat(id)
    GameTooltip:AddDoubleLine(ns.QualitaetFarbe(id) .. ns.ItemName(id) .. "|r", (hat >= n and GRUEN or ROT) .. hat .. " / " .. n .. "|r")
  end
  local m = r[3]
  if type(m) == "table" then
    GameTooltip:AddLine(GRAU .. "Ergibt " .. m[1] .. " bis " .. m[2] .. " Stück|r")
  elseif m > 1 then
    GameTooltip:AddLine(GRAU .. "Ergibt " .. m .. " Stück|r")
  end
  local kenner = ns.Kenner(rid)
  if #kenner > 0 then GameTooltip:AddLine(GRUEN .. "Gelernt: " .. table.concat(kenner, ", ") .. "|r", nil, nil, nil, true) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(GRAU .. "Klick: auf die Liste  ·  Umschalt-Klick: in den Chat|r")
  GameTooltip:Show()
end

local function ItemTooltip(owner, id, zusatz)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then GameTooltip:SetItemByID(id) else GameTooltip:SetHyperlink("item:" .. id) end
  if zusatz then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(GRAU .. zusatz .. "|r", nil, nil, nil, true)
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
      if ok and such ~= "" then
        ok = ns.RezeptName(rid):lower():find(such, 1, true) ~= nil
      end
      if ok then e[#e + 1] = { rid = rid } end
    end
    if #e == n0 + 1 then
      e[#e] = nil
    else
      kopf.rechts = GRAU .. (#e - n0 - 1) .. "|r"
    end
  end
  return e
end

local function ZeichneRezept(row, e)
  if e.kopf then return ZeichneKopf(row, e) end
  local rid = e.rid
  local r = D.rezepte[rid]
  local name = ns.RezeptName(rid)
  local farbe = r[2] and ns.QualitaetFarbe(r[2]) or WEISS
  local rechts = ""
  local anz = ns.char.liste[rid]
  if anz then rechts = GOLD .. anz .. "×|r " end
  if ns.char.bekannt[rid] then rechts = rechts .. GRUEN .. "gelernt|r" end
  ZeichneZeile(row, ns.RezeptIcon(rid), farbe .. name .. "|r", rechts)
end

local function KlickRezept(e, btn)
  if not e.rid then return end
  if IsShiftKeyDown() then return ChatLink(e.rid) end
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
  for rid in pairs(ns.char.liste) do rids[#rids + 1] = rid end
  table.sort(rids, function(a, b) return ns.RezeptName(a) < ns.RezeptName(b) end)
  if #rids == 0 then
    e[1] = { kopf = "Die Liste ist leer" }
    e[2] = { info = "Links ein Rezept anklicken oder im" }
    e[3] = { info = "Berufsfenster auf „Werkbank“ drücken." }
    return e
  end
  e[#e + 1] = { kopf = "Herstellen", rechts = GRAU .. #rids .. "|r" }
  for _, rid in ipairs(rids) do e[#e + 1] = { liste = rid } end

  local bedarf, schritte = ns.Rechnen()
  local ids, fehlt = {}, 0
  for id, n in pairs(bedarf) do
    ids[#ids + 1] = id
    if ns.Vorrat(id) < n then fehlt = fehlt + 1 end
  end
  table.sort(ids, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  e[#e + 1] = { kopf = "Materialien", rechts = fehlt > 0 and (ROT .. fehlt .. " fehlen|r") or (GRUEN .. "alles da|r") }
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
    row.text:SetText(GRAU .. e.info .. "|r")
    row.rechts:SetText("")
    return
  end
  if e.liste then
    local rid = e.liste
    local r = D.rezepte[rid]
    local farbe = r[2] and ns.QualitaetFarbe(r[2]) or WEISS
    ZeichneZeile(row, ns.RezeptIcon(rid), GOLD .. ns.char.liste[rid] .. "×|r " .. farbe .. ns.RezeptName(rid) .. "|r")
  elseif e.mat then
    local hat = ns.Vorrat(e.mat)
    local selbst = ns.madeBy[e.mat] and (GRAU .. "  herstellbar|r") or ""
    ZeichneZeile(row, ns.ItemIcon(e.mat), ns.QualitaetFarbe(e.mat) .. ns.ItemName(e.mat) .. "|r" .. selbst,
      (hat >= e.n and GRUEN or ROT) .. math.min(hat, e.n) .. " / " .. e.n .. "|r")
  elseif e.schritt then
    local r = D.rezepte[e.schritt]
    ZeichneZeile(row, ns.RezeptIcon(e.schritt), GOLD .. e.n .. "×|r " .. ns.QualitaetFarbe(r[2]) .. ns.RezeptName(e.schritt) .. "|r",
      GRAU .. (ns.berufOf[e.schritt] and ns.berufOf[e.schritt].name or "") .. "|r")
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
    GameTooltip:AddLine(GRAU .. "Rechtsklick: eins weniger  ·  Strg-Rechtsklick: entfernen|r")
    GameTooltip:Show()
  elseif e.mat then
    ItemTooltip(row, e.mat, ns.madeBy[e.mat] and "Klick: selbst herstellen statt kaufen" or nil)
  elseif e.schritt then
    ItemTooltip(row, D.rezepte[e.schritt][2], "Klick: doch lieber kaufen")
  end
end

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

-- ---------- Hauptfenster ----------

local function Neu()
  if not ui.frame or not ui.frame:IsShown() then return end
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
  local text = b and (GOLD .. b.name .. "|r") or ""
  if c then text = text .. "  " .. WEISS .. (c.stufe or 0) .. "/" .. (c.max or 0) .. "|r" end
  if b then text = text .. "  " .. GRAU .. gelernt .. " von " .. b.anzahl .. " Rezepten gelernt|r" end
  ui.kopf:SetText(text)
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
  suche:SetSize(200, 20)
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
  platzhalter:SetText("Suchen …")
  suche:HookScript("OnTextChanged", function(self) platzhalter:SetShown(self:GetText() == "") end)
  ui.suche = suche

  ui.filter = 1
  local filter = Knopf(f, FILTER[1], 150)
  filter:SetPoint("LEFT", suche, "RIGHT", 10, 0)
  filter:SetScript("OnClick", function(self)
    ui.filter = ui.filter % #FILTER + 1
    self:SetText(FILTER[ui.filter])
    Neu()
  end)
  Tipp(filter, "Filter", "Gelernte Rezepte erfasst die Werkbank, sobald du das Berufsfenster öffnest.")

  -- Listen
  ui.buch = Liste(f, 420, 360, ZeichneRezept, KlickRezept, EnterRezept)
  ui.buch:SetPoint("TOPLEFT", 14, -120)

  local trenner = f:CreateTexture(nil, "ARTWORK")
  trenner:SetColorTexture(1, 1, 1, 0.08)
  trenner:SetSize(1, 400)
  trenner:SetPoint("TOPLEFT", 440, -96)

  local listeTitel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  listeTitel:SetPoint("TOPLEFT", 452, -95)
  listeTitel:SetText("Einkaufsliste")

  ui.liste = Liste(f, 300, 360, ZeichneListe, KlickListe, EnterListe)
  ui.liste:SetPoint("TOPLEFT", 450, -120)

  -- Knöpfe unten
  local leeren = Knopf(f, "Leeren", 80)
  leeren:SetPoint("BOTTOMRIGHT", -14, 12)
  leeren:SetScript("OnClick", function()
    if IsShiftKeyDown() then
      ns.ListeLeeren()
    else
      ns.Print("Zum Leeren Umschalt gedrückt halten und klicken.")
    end
  end)
  Tipp(leeren, "Liste leeren", "Umschalt-Klick leert die ganze Einkaufsliste.")

  local web = Knopf(f, "Webseite", 90)
  web:SetPoint("RIGHT", leeren, "LEFT", -4, 0)
  web:SetScript("OnClick", ns.ExportDialog)
  Tipp(web, "Zum Berufe-Rechner", "Erzeugt einen Link zu foreverui.de/berufe mit deiner Liste.")

  local imp = Knopf(f, "Import", 80)
  imp:SetPoint("RIGHT", web, "LEFT", -4, 0)
  imp:SetScript("OnClick", ns.ImportDialog)
  Tipp(imp, "Liste importieren", "Link aus dem Berufe-Rechner auf foreverui.de einfügen.")

  local fuss = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  fuss:SetPoint("BOTTOMLEFT", 18, 18)
  fuss:SetText("Klick +1  ·  Strg-Klick +5  ·  Rechtsklick −1  ·  Daten: Blizzard Entertainment, Stand " .. D.stand)

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
  else
    ns.Print("Befehle:")
    for _, z in ipairs(HILFE) do DEFAULT_CHAT_FRAME:AddMessage("  " .. z) end
  end
end
