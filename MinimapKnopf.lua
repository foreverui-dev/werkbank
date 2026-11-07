-- Knopf an der Minikarte: Links-Klick Fenster, Rechts-Klick Optionen, ziehen zum Verschieben
local _, ns = ...
local F = ns.F

local knopf

local function Setzen()
  local w = math.rad(ns.db.optionen.minimapWinkel or 200)
  local r = (Minimap:GetWidth() or 140) / 2 + 10
  knopf:ClearAllPoints()
  knopf:SetPoint("CENTER", Minimap, "CENTER", math.cos(w) * r, math.sin(w) * r)
end

local function Ziehen()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  local winkel = math.deg(math.atan2(cy / s - my, cx / s - mx)) % 360
  ns.db.optionen.minimapWinkel = math.floor(winkel + 0.5)
  Setzen()
end

local function Tooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("Werkbank", 1, 1, 1)
  local n = 0
  for _ in pairs(ns.L.liste) do n = n + 1 end
  local fehlt = 0
  for _ in pairs(ns.Fehlend and ns.Fehlend() or {}) do fehlt = fehlt + 1 end
  GameTooltip:AddLine("Liste: " .. (ns.L.name or "Standard"), 1, 0.82, 0)
  if n == 0 then
    GameTooltip:AddLine("leer", 0.7, 0.7, 0.7)
  elseif fehlt == 0 then
    GameTooltip:AddLine(F.gruen .. n .. " Rezepte, alle Materialien da|r")
  else
    GameTooltip:AddLine(F.rot .. n .. " Rezepte, " .. fehlt .. " Materialien fehlen|r")
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Klick: Fenster öffnen", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Rechtsklick: Optionen", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Umschalt-Klick: Liste vorlesen", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Ziehen: verschieben", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

local function Bauen()
  knopf = CreateFrame("Button", "WerkbankMinimapKnopf", Minimap)
  knopf:SetSize(31, 31)
  knopf:SetFrameStrata("MEDIUM")
  knopf:SetFrameLevel(8)
  knopf:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  knopf:RegisterForDrag("LeftButton")
  knopf:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local hg = knopf:CreateTexture(nil, "BACKGROUND")
  hg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  hg:SetSize(20, 20)
  hg:SetPoint("TOPLEFT", 7, -5)

  local icon = knopf:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local rand = knopf:CreateTexture(nil, "OVERLAY")
  rand:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  rand:SetSize(53, 53)
  rand:SetPoint("TOPLEFT")

  knopf:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
      ns.OptionenDialog()
    elseif IsShiftKeyDown() then
      ns.ListeVorlesen()
    else
      ns.Umschalten()
    end
  end)
  knopf:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", Ziehen) end)
  knopf:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  knopf:SetScript("OnEnter", Tooltip)
  knopf:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Setzen()
end

function ns.MinimapKnopfZeigen()
  if not Minimap then return end
  if ns.db.optionen.minimap then
    if not knopf then Bauen() end
    knopf:Show()
  elseif knopf then
    knopf:Hide()
  end
end

ns.AufEreignis("PLAYER_LOGIN", function() ns.MinimapKnopfZeigen() end)
