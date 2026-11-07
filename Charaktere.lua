-- Charakterübergreifend: Vorrat aller Charaktere, wer was herstellen kann, Rezept-Tooltips
local _, ns = ...

-- Nur Gegenstände merken, die in Rezepten vorkommen, damit die gespeicherten Daten klein bleiben
local function relevant(id)
  return ns.usedIn[id] ~= nil or ns.madeBy[id] ~= nil
end

-- ---------- Taschen und Bank lesen ----------

local function SlotAnzahl(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function SlotInhalt(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount end
    return nil
  end
  if GetContainerItemInfo then
    local _, anzahl, _, _, _, _, link = GetContainerItemInfo(bag, slot)
    return ns.ItemIdAusLink(link), anzahl
  end
end
ns.SlotInhalt = SlotInhalt
ns.SlotAnzahl = SlotAnzahl

local function Lesen(bags)
  local t = {}
  for _, bag in ipairs(bags) do
    for slot = 1, SlotAnzahl(bag) do
      local id, n = SlotInhalt(bag, slot)
      if id and relevant(id) then t[id] = (t[id] or 0) + (n or 1) end
    end
  end
  return t
end

local function TaschenBags()
  local t = {}
  for b = 0, (NUM_BAG_SLOTS or 4) do t[#t + 1] = b end
  return t
end

function ns.BankBags()
  local t = { BANK_CONTAINER or -1 }
  local erste = (NUM_BAG_SLOTS or 4) + 1
  for b = erste, erste + (NUM_BANKBAGSLOTS or 6) - 1 do t[#t + 1] = b end
  return t
end

function ns.TaschenLesen()
  ns.char.taschen = Lesen(TaschenBags())
end

function ns.BankLesen()
  ns.char.bank = Lesen(ns.BankBags())
end

ns.AufEreignis("PLAYER_LOGIN", function() ns.TaschenLesen() end)
ns.AufEreignis("BAG_UPDATE_DELAYED", function() ns.TaschenLesen() end)
ns.AufEreignis("BANKFRAME_OPENED", function() ns.bankOffen = true ns.BankLesen() end)
ns.AufEreignis("PLAYERBANKSLOTS_CHANGED", function() if ns.bankOffen then ns.BankLesen() end end)
ns.AufEreignis("BANKFRAME_CLOSED", function()
  if ns.bankOffen then ns.BankLesen() end
  ns.bankOffen = false
end)

-- ---------- Andere Charaktere ----------

-- Charaktere auf demselben Realm und derselben Fraktion (nur die können sich etwas schicken)
function ns.Twinks()
  local t = {}
  for key, c in pairs(ns.db.chars) do
    if c ~= ns.char and c.realm == ns.char.realm and (not c.fraktion or not ns.char.fraktion or c.fraktion == ns.char.fraktion) then
      t[#t + 1] = c
    end
  end
  table.sort(t, function(a, b) return (a.name or "") < (b.name or "") end)
  return t
end

-- Vorrat eines Gegenstands bei den anderen Charakteren: Summe und Liste "Name 5"
function ns.TwinkVorrat(id)
  local summe, wer = 0, {}
  for _, c in ipairs(ns.Twinks()) do
    local n = ((c.taschen or {})[id] or 0) + ((c.bank or {})[id] or 0)
    if n > 0 then
      summe = summe + n
      wer[#wer + 1] = (c.name or "?") .. " " .. n
    end
  end
  return summe, wer
end

-- Welche Charaktere (auch der aktuelle) können einen Gegenstand herstellen?
function ns.HerstellerVon(id)
  local namen, gesehen = {}, {}
  for _, rid in ipairs(ns.madeBy[id] or {}) do
    for _, name in ipairs(ns.Kenner(rid)) do
      if not gesehen[name] then
        gesehen[name] = true
        namen[#namen + 1] = name
      end
    end
  end
  table.sort(namen)
  return namen
end

-- Hat irgendein eigener Charakter das Rezept gelernt?
function ns.IrgendwerKennt(rid)
  for _, c in pairs(ns.db.chars) do
    if c.bekannt and c.bekannt[rid] then return true end
  end
  return false
end

-- ---------- Charakterübersicht ----------

function ns.CharakterZeilen()
  local zeilen = {}
  local keys = {}
  for key in pairs(ns.db.chars) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local c = ns.db.chars[key]
    local berufe = {}
    for id, s in pairs(c.berufe or {}) do
      local b = ns.beruf[id]
      if b then berufe[#berufe + 1] = b.name .. " " .. (s.stufe or 0) .. "/" .. (s.max or 0) end
    end
    table.sort(berufe)
    local n = 0
    for _ in pairs(c.bekannt or {}) do n = n + 1 end
    zeilen[#zeilen + 1] = {
      key = key,
      name = (c.name or "?") .. " (" .. (c.realm or "?") .. ")",
      berufe = #berufe > 0 and table.concat(berufe, ", ") or "keine Berufe erfasst",
      rezepte = n,
      klasse = c.klasse,
    }
  end
  return zeilen
end

function ns.CharakterVergessen(name)
  name = (name or ""):lower()
  for key, c in pairs(ns.db.chars) do
    if c ~= ns.char and (key:lower() == name or (c.name or ""):lower() == name) then
      ns.db.chars[key] = nil
      return key
    end
  end
end

-- ---------- Tooltip an Rezept-Gegenständen (Muster, Pläne, Formeln …) ----------

local PRAEFIXE = { "Muster", "Rezept", "Pläne", "Formel", "Bauplan", "Schema", "Handbuch", "Anleitung", "Buch" }

-- Findet zum Namen eines Rezept-Gegenstands das Rezept
function ns.RezeptAusGegenstand(name)
  if not name then return nil end
  local rest
  for _, p in ipairs(PRAEFIXE) do
    rest = name:match("^" .. p .. ": (.+)$")
    if rest then break end
  end
  if not rest then return nil end
  for _, b in ipairs(ns.daten.berufe) do
    local rid = ns.rezeptName[b.id][rest]
    if rid then return rid end
  end
  -- Verzauberungen heißen im Rezept oft "Armschiene - …", auf der Formel "Armschiene – …"
  rest = rest:gsub("–", "-")
  for _, b in ipairs(ns.daten.berufe) do
    local rid = ns.rezeptName[b.id][rest]
    if rid then return rid end
  end
end

function ns.RezeptGegenstandZeilen(tip, name)
  local rid = ns.RezeptAusGegenstand(name)
  if not rid then return false end
  local F = ns.F
  local kenner = ns.Kenner(rid)
  if #kenner > 0 then
    tip:AddLine(F.gruen .. "Werkbank: gelernt von " .. table.concat(kenner, ", ") .. "|r", 1, 1, 1, true)
  else
    tip:AddLine(F.rot .. "Werkbank: noch von keinem deiner Charaktere gelernt|r", 1, 1, 1, true)
  end
  -- Wer hat den Beruf, aber das Rezept noch nicht?
  local b = ns.berufOf[rid]
  if b then
    local koennten = {}
    for _, c in pairs(ns.db.chars) do
      if c.berufe and c.berufe[b.id] and not (c.bekannt and c.bekannt[rid]) then
        koennten[#koennten + 1] = (c.name or "?") .. " (" .. (c.berufe[b.id].stufe or 0) .. ")"
      end
    end
    table.sort(koennten)
    if #koennten > 0 then
      tip:AddLine(F.grau .. "Könnte lernen: " .. table.concat(koennten, ", ") .. "|r", 1, 1, 1, true)
    end
  end
  return true
end
