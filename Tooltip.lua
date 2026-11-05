-- Zusätzliche Zeilen in Gegenstands-Tooltips
local _, ns = ...

local GRAU, GRUEN, ROT, GOLD = "|cff9d9d9d", "|cff40c040", "|cffff5050", "|cffe0b45a"

local function BerufeListe(rids, max)
  local namen, gesehen = {}, {}
  for _, rid in ipairs(rids) do
    local b = ns.berufOf[rid]
    if b and not gesehen[b.id] then
      gesehen[b.id] = true
      namen[#namen + 1] = b.name
    end
  end
  table.sort(namen)
  if #namen > max then
    local rest = #namen - max
    for i = #namen, max + 1, -1 do namen[i] = nil end
    namen[#namen + 1] = "+" .. rest
  end
  return table.concat(namen, ", ")
end

function ns.TooltipZeilen(tip, id)
  if not ns.char or not ns.db.optionen.tooltip or not id then return end
  local zeilen = false

  -- Stand der Einkaufsliste
  local bedarf = ns.Rechnen()
  local soll = bedarf[id]
  if soll then
    local hat = ns.Vorrat(id)
    local farbe = hat >= soll and GRUEN or ROT
    tip:AddDoubleLine(GOLD .. "Werkbank-Liste|r", farbe .. math.min(hat, soll) .. " / " .. soll .. "|r")
    zeilen = true
  end

  -- Wofür wird das gebraucht?
  local used = ns.usedIn[id]
  if used then
    local n = #used
    tip:AddLine(GRAU .. "Zutat für " .. n .. (n == 1 and " Rezept" or " Rezepte") .. ": " .. BerufeListe(used, 3) .. "|r", 1, 1, 1, true)
    zeilen = true
  end

  -- Wer stellt das her?
  local made = ns.madeBy[id]
  if made then
    local text = GRAU .. "Herstellbar: " .. BerufeListe(made, 3)
    if ns.db.optionen.tooltipKenner then
      local kenner, gesehen = {}, {}
      for _, rid in ipairs(made) do
        for _, name in ipairs(ns.Kenner(rid)) do
          if not gesehen[name] then
            gesehen[name] = true
            kenner[#kenner + 1] = name
          end
        end
      end
      if #kenner > 0 then text = text .. "|r " .. GRUEN .. "(" .. table.concat(kenner, ", ") .. ")" end
    end
    tip:AddLine(text .. "|r", 1, 1, 1, true)
    zeilen = true
  end

  if zeilen then tip:Show() end
end

local function BeiItem(tip)
  if tip.werkbankFertig then return end
  local _, link = tip:GetItem()
  local id = ns.ItemIdAusLink(link)
  if id then
    tip.werkbankFertig = true
    ns.TooltipZeilen(tip, id)
  end
end

local function Leeren(tip) tip.werkbankFertig = nil end

local function Einhaken(tip)
  if not tip or tip.werkbankHook then return end
  tip.werkbankHook = true
  tip:HookScript("OnTooltipCleared", Leeren)
  if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
    tip:HookScript("OnTooltipSetItem", BeiItem)
  end
end

function ns.TooltipsEinrichten()
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
      if tip == GameTooltip or tip == ItemRefTooltip then BeiItem(tip) end
    end)
  end
  Einhaken(GameTooltip)
  Einhaken(ItemRefTooltip)
end
