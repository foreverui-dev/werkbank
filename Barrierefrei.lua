-- Barrierefreiheit: Vorlesen, hoher Kontrast, Farbenblind-Modus, Größe, Tastenkürzel
local _, ns = ...

-- Farben als Farbcodes. Werden an Ort und Stelle geändert, damit alle Verweise mitziehen.
local F = { gold = "|cffe0b45a", weiss = "|cffffffff" }
ns.F = F

local BASIS = { grau = "|cff9d9d9d", gruen = "|cff40c040", rot = "|cffff5050" }

function ns.FarbenAnwenden()
  local o = ns.db and ns.db.optionen or {}
  F.grau = o.kontrast and "|cffd1d1d1" or BASIS.grau
  -- Für Rot-Grün-Schwäche: Blau statt Grün, Orange statt Rot
  F.gruen = o.farbenblind and "|cff59a6ff" or BASIS.gruen
  F.rot = o.farbenblind and "|cffff9919" or BASIS.rot
end
ns.FarbenAnwenden()

ns.GROESSEN = { 1, 1.25, 1.5, 2 }

function ns.Groesse()
  local g = ns.db and tonumber(ns.db.optionen.groesse) or 1
  return math.max(1, math.min(2, g))
end

-- Hintergrund-Deckkraft im Kontrastmodus
function ns.Deckkraft(normal)
  return (ns.db and ns.db.optionen.kontrast) and math.max(normal, 0.92) or normal
end

-- ---------- Sprachausgabe ----------

local function sauber(text)
  text = tostring(text or "")
  text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("%[(.-)%]", "%1")
  text = text:gsub("(%d+) / (%d+)", "%1 von %2"):gsub("×", " mal")
  return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
ns.Sauber = sauber

local stimme
local function Stimme()
  if stimme ~= nil then return stimme end
  stimme = false
  if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum and Enum.TtsVoiceType then
    local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
    if ok and id then stimme = id end
  end
  if not stimme and C_VoiceChat and C_VoiceChat.GetTtsVoices then
    local ok, liste = pcall(C_VoiceChat.GetTtsVoices)
    if ok and liste and liste[1] then stimme = liste[1].voiceID end
  end
  return stimme
end

-- Liest Text mit der Sprachausgabe des Spiels vor. immer = auch wenn Vorlesen aus ist.
function ns.Sprechen(text, immer)
  if not immer and not (ns.db and ns.db.optionen.vorlesen) then return false end
  text = sauber(text)
  if text == "" then return false end
  if C_VoiceChat and C_VoiceChat.StopSpeakingText then pcall(C_VoiceChat.StopSpeakingText) end
  if TextToSpeech_Speak and TextToSpeech_GetSelectedVoice and Enum and Enum.TtsVoiceType then
    local ok = pcall(TextToSpeech_Speak, text, TextToSpeech_GetSelectedVoice(Enum.TtsVoiceType.Standard))
    if ok then return true end
  end
  if C_VoiceChat and C_VoiceChat.SpeakText then
    local id = Stimme()
    if id then
      local ziel = Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1
      if pcall(C_VoiceChat.SpeakText, id, text, ziel, 0, 100) then return true end
      if pcall(C_VoiceChat.SpeakText, id, text, 0, 100) then return true end
    end
  end
  return false
end

local function NichtVerfuegbar()
  ns.Print("Die Sprachausgabe ist nicht verfügbar. In den Spieleinstellungen unter Barrierefreiheit › Text-zu-Sprache lässt sie sich einrichten.")
end

-- Fasst die Einkaufsliste in Sätzen zusammen
function ns.ListeText()
  local rids = {}
  for rid in pairs(ns.char.liste) do rids[#rids + 1] = rid end
  if #rids == 0 then return "Die Einkaufsliste ist leer." end
  table.sort(rids, function(a, b) return ns.RezeptName(a) < ns.RezeptName(b) end)
  local teile = {}
  local herstellen = {}
  for _, rid in ipairs(rids) do herstellen[#herstellen + 1] = ns.char.liste[rid] .. " mal " .. ns.RezeptName(rid) end
  teile[1] = "Herstellen: " .. table.concat(herstellen, ", ") .. "."
  local bedarf = ns.Rechnen()
  local fehlt = {}
  local ids = {}
  for id in pairs(bedarf) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  for _, id in ipairs(ids) do
    local rest = bedarf[id] - ns.Vorrat(id)
    if rest > 0 then fehlt[#fehlt + 1] = rest .. " " .. ns.ItemName(id) end
  end
  if #fehlt == 0 then
    teile[2] = "Alle Materialien sind da."
  else
    teile[2] = "Es fehlen: " .. table.concat(fehlt, ", ") .. "."
  end
  return table.concat(teile, " ")
end

function ns.ListeVorlesen()
  if not ns.Sprechen(ns.ListeText(), true) then NichtVerfuegbar() end
end

-- Zusammenfassung eines Rezepts: Name, Zutaten mit Vorrat, wer es kann
function ns.RezeptText(rid)
  local r = ns.Rezept(rid)
  if not r then return "" end
  local teile = { ns.RezeptName(rid) .. "." }
  local b = ns.berufOf[rid]
  if b then teile[#teile + 1] = b.name .. ", " .. (ns.katOf[rid] or "") .. "." end
  local z = r[4]
  local zutaten = {}
  for i = 1, #z, 2 do
    local hat = ns.Vorrat(z[i])
    zutaten[#zutaten + 1] = z[i + 1] .. " " .. ns.ItemName(z[i]) .. (hat >= z[i + 1] and ", vorhanden" or (", du hast " .. hat))
  end
  if #zutaten > 0 then teile[#teile + 1] = "Zutaten: " .. table.concat(zutaten, "; ") .. "." end
  if ns.char.bekannt[rid] then teile[#teile + 1] = "Gelernt." end
  local anz = ns.char.liste[rid]
  if anz then teile[#teile + 1] = anz .. " mal auf der Liste." end
  return table.concat(teile, " ")
end

-- ---------- Tastenkürzel (Bindings.xml) ----------

BINDING_HEADER_WERKBANK = "Werkbank"
BINDING_NAME_WERKBANK_FENSTER = "Fenster öffnen oder schließen"
BINDING_NAME_WERKBANK_REZEPT = "Gewähltes Rezept auf die Liste"
BINDING_NAME_WERKBANK_VORLESEN = "Einkaufsliste vorlesen"

function ns.Taste(was)
  if not ns.char then return end
  if was == "fenster" then
    ns.Umschalten()
  elseif was == "rezept" then
    local rid = ns.GewaehltesRezept()
    if rid then
      ns.ListeAdd(rid, 1)
      ns.Print("1× " .. ns.RezeptName(rid) .. " auf die Liste gesetzt.")
      ns.Sprechen(ns.RezeptName(rid) .. " auf die Liste gesetzt.")
    else
      ns.Print("Im Berufsfenster ist kein bekanntes Rezept gewählt.")
    end
  elseif was == "vorlesen" then
    ns.ListeVorlesen()
  end
end

-- Global, damit Bindings.xml es aufrufen kann
Werkbank = Werkbank or {}
Werkbank.Taste = function(_, was) ns.Taste(was) end
