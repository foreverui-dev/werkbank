-- Bausteine für das einheitliche ForeverUI-Design (nachgebaut im eigenen Namensraum)
local _, ns = ...

local S = {}
ns.Stil = S

S.HG = { 0.06, 0.06, 0.08 }
S.TEXT = { 0.93, 0.91, 0.86 }
S.GRAU = { 0.55, 0.55, 0.55 }

-- Texturen in Akzentfarbe merken, damit ein Wechsel sofort wirkt
local akzentTexturen = {}
local akzentTexte = {}

function S.Flaeche(parent, r, g, b, a, ebene, unter)
  local t = parent:CreateTexture(nil, ebene or "BACKGROUND", nil, unter)
  t:SetAllPoints()
  t:SetColorTexture(r, g, b, a)
  return t
end

function S.AkzentFlaeche(tex, alpha)
  akzentTexturen[tex] = alpha or 1
  local A = ns.Akzent
  tex:SetColorTexture(A[1], A[2], A[3], alpha or 1)
  return tex
end

function S.AkzentText(fs)
  akzentTexte[fs] = true
  local A = ns.Akzent
  fs:SetTextColor(A[1], A[2], A[3])
  return fs
end

-- Vier 1-px-Kanten. akzent = Deckkraft in Akzentfarbe, sonst weiß mit Deckkraft a
function S.Rand(f, a, akzent)
  local kanten = {}
  local function Kante(p1, p2, w, h)
    local t = f:CreateTexture(nil, "BORDER")
    t:SetPoint(p1)
    t:SetPoint(p2)
    if w then t:SetWidth(w) end
    if h then t:SetHeight(h) end
    if akzent then S.AkzentFlaeche(t, akzent) else t:SetColorTexture(1, 1, 1, a) end
    kanten[#kanten + 1] = t
  end
  Kante("TOPLEFT", "TOPRIGHT", nil, 1)
  Kante("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  Kante("TOPLEFT", "BOTTOMLEFT", 1, nil)
  Kante("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
  return kanten
end

-- Innerer Kasten: Hintergrund 0.35 und weißer Rand 0.08
function S.Kasten(parent, deckkraft)
  local k = CreateFrame("Frame", nil, parent)
  k.hg = S.Flaeche(k, S.HG[1], S.HG[2], S.HG[3], deckkraft or 0.35)
  S.Rand(k, 0.08)
  return k
end

function S.Knopf(parent, text, w)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 90, 22)
  b:SetText(text)
  return b
end

-- Zeilen-Markierungen: Hover weiß 0.05, Auswahl Akzent 0.14 mit 2-px-Strich links
function S.Zeile(row)
  local hover = row:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.05)
  row.zebra = row:CreateTexture(nil, "BACKGROUND")
  row.zebra:SetAllPoints()
  row.zebra:SetColorTexture(1, 1, 1, 0.08)
  row.zebra:Hide()
  row.auswahl = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.auswahl:SetAllPoints()
  S.AkzentFlaeche(row.auswahl, 0.14)
  row.strich = row:CreateTexture(nil, "ARTWORK", nil, 1)
  row.strich:SetPoint("TOPLEFT")
  row.strich:SetPoint("BOTTOMLEFT")
  row.strich:SetWidth(2)
  S.AkzentFlaeche(row.strich, 1)
  function row:Gewaehlt(an)
    self.auswahl:SetShown(an and true or false)
    self.strich:SetShown(an and true or false)
  end
  row:Gewaehlt(false)
end

-- Hauptfenster: Fläche 0.99, Akzentrand 0.45, Kopfband 64 px, Name in Großbuchstaben, Seitentitel
function S.Fenster(name, w, h)
  local f = CreateFrame("Frame", name, UIParent)
  f:Hide()
  f:SetSize(w, h)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f.hg = S.Flaeche(f, S.HG[1], S.HG[2], S.HG[3], 0.99)
  S.Rand(f, nil, 0.45)
  local band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  band:SetPoint("TOPLEFT", 1, -1)
  band:SetPoint("TOPRIGHT", -1, -1)
  band:SetHeight(64)
  S.AkzentFlaeche(band, 0.08)

  f.addon = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.addon:SetPoint("TOPLEFT", 24, -16)
  f.addon:SetText("WERKBANK")
  S.AkzentText(f.addon)
  f.seitenTitel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.seitenTitel:SetPoint("TOPLEFT", 24, -34)

  local zu = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  zu:SetPoint("TOPRIGHT", 2, 2)
  f.zu = zu
  if name then tinsert(UISpecialFrames, name) end

  -- Griff zum Vergrößern
  f:SetResizable(true)
  local griff = CreateFrame("Button", nil, f)
  griff:SetSize(16, 16)
  griff:SetPoint("BOTTOMRIGHT", -2, 2)
  griff:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  griff:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  griff:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  griff:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  griff:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    if f.NachGroesse then f:NachGroesse() end
  end)
  f.griff = griff
  return f
end

function S.Mindestgroesse(f, w, h)
  if f.SetResizeBounds then f:SetResizeBounds(w, h, 1600, 1200)
  elseif f.SetMinResize then f:SetMinResize(w, h) end
end

-- Akzentfarbe neu auftragen (nach einem Wechsel, ohne /reload)
function ns.StilAnwenden()
  local A = ns.Akzent
  for tex, alpha in pairs(akzentTexturen) do tex:SetColorTexture(A[1], A[2], A[3], alpha) end
  for fs in pairs(akzentTexte) do fs:SetTextColor(A[1], A[2], A[3]) end
end
