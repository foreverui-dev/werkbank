-- Unterwegs: Händler, Bank, Auktionshaus, Chat, Loot-Fortschritt und automatisches Abhaken
local _, ns = ...
local F = ns.F

-- Was fehlt noch? Gegenstand -> Anzahl (nur Materialien, die nicht reichen)
function ns.Fehlend()
  local bedarf = ns.Rechnen()
  local t = {}
  for id, n in pairs(bedarf) do
    local rest = n - ns.Vorrat(id)
    if rest > 0 then t[id] = rest end
  end
  return t
end

local function Sortiert(t)
  local ids = {}
  for id in pairs(t) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return ns.ItemName(a) < ns.ItemName(b) end)
  return ids
end

local function Geld(kupfer)
  if GetCoinTextureString then return GetCoinTextureString(kupfer) end
  local g, s, k = math.floor(kupfer / 10000), math.floor(kupfer / 100) % 100, kupfer % 100
  return (g > 0 and (g .. "g ") or "") .. (s > 0 and (s .. "s ") or "") .. k .. "k"
end

local function Knopf(parent, text, w)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 120, 22)
  b:SetText(text)
  return b
end

-- ---------- Loot-Fortschritt und Fertig-Meldung ----------

local stand = {} -- Gegenstand -> Anzahl beim letzten Taschen-Update

function ns.VorratGeaendert()
  local bedarf = ns.Rechnen()
  local fehlteVorher, fehltJetzt = 0, 0
  local neu = {}
  for id, soll in pairs(bedarf) do
    local jetzt = ns.Vorrat(id)
    local vorher = stand[id] or jetzt
    neu[id] = jetzt
    if vorher < soll then fehlteVorher = fehlteVorher + 1 end
    if jetzt < soll then fehltJetzt = fehltJetzt + 1 end
    if ns.db.optionen.lootMeldung and jetzt > vorher and vorher < soll then
      local text = ns.ItemName(id) .. " " .. math.min(jetzt, soll) .. "/" .. soll
      if jetzt >= soll then text = text .. " " .. F.gruen .. "(fertig)|r" end
      ns.Print(text)
    end
  end
  stand = neu
  if ns.db.optionen.fertigMeldung and fehlteVorher > 0 and fehltJetzt == 0 then
    ns.Print(F.gruen .. "Alle Materialien für „" .. (ns.L.name or "Liste") .. "“ sind da!|r")
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.READY_CHECK or 8960) end
    ns.Sprechen("Alle Materialien sind da.")
  end
  return fehltJetzt
end

ns.AufEreignis("PLAYER_LOGIN", function() stand = {} ns.VorratGeaendert() end)
ns.AufEreignis("BAG_UPDATE_DELAYED", function() ns.VorratGeaendert() end)

-- ---------- Nach dem Herstellen automatisch abhaken ----------

-- Macht aus einem Spieltext wie "Ihr stellt her: %sx%d." ein Suchmuster
local function Muster(fmt)
  if not fmt then return nil end
  fmt = fmt:gsub("%%%d%$", "%%")
  fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  fmt = fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  return "^" .. fmt .. "$"
end

local MEHRERE = Muster(LOOT_ITEM_CREATED_SELF_MULTIPLE)
local EINER = Muster(LOOT_ITEM_CREATED_SELF)

-- Liefert Gegenstand-ID, wenn die Chatzeile eine eigene Herstellung meldet
function ns.HerstellungAusChat(msg)
  if not msg then return nil end
  local link = MEHRERE and msg:match(MEHRERE)
  link = link or (EINER and msg:match(EINER))
  return ns.ItemIdAusLink(link)
end

function ns.Abhaken(id)
  if not id then return end
  for _, rid in ipairs(ns.madeBy[id] or {}) do
    local n = ns.L.liste[rid]
    if n then
      ns.ListeSetzen(rid, n - 1)
      local rest = ns.L.liste[rid]
      if rest then
        ns.Print(ns.RezeptName(rid) .. " abgehakt, noch " .. rest .. ".")
      else
        ns.Print(F.gruen .. ns.RezeptName(rid) .. " erledigt.|r")
        ns.Sprechen(ns.RezeptName(rid) .. " erledigt.")
      end
      return rid
    end
  end
end

ns.AufEreignis("CHAT_MSG_LOOT", function(msg)
  if not ns.db.optionen.abhaken then return end
  ns.Abhaken(ns.HerstellungAusChat(msg))
end)

-- ---------- Händler: fehlende Materialien kaufen ----------

-- Was kann dieser Händler von der Liste liefern? { {index, id, kaeufe, pro, preis} }
function ns.HaendlerAngebot()
  local fehlt = ns.Fehlend()
  local t, summe = {}, 0
  if not GetMerchantNumItems then return t, 0 end
  for i = 1, GetMerchantNumItems() do
    local id = ns.ItemIdAusLink(GetMerchantItemLink(i))
    if id and fehlt[id] then
      local _, _, preis, pro, verfuegbar = GetMerchantItemInfo(i)
      pro = math.max(pro or 1, 1)
      local kaeufe = math.ceil(fehlt[id] / pro)
      if verfuegbar and verfuegbar >= 0 then kaeufe = math.min(kaeufe, verfuegbar) end
      if kaeufe > 0 and preis then
        t[#t + 1] = { index = i, id = id, kaeufe = kaeufe, pro = pro, preis = preis * kaeufe }
        summe = summe + preis * kaeufe
      end
    end
  end
  return t, summe
end

local function Kaufen(angebot)
  for _, a in ipairs(angebot) do
    if a.pro > 1 then
      for _ = 1, a.kaeufe do BuyMerchantItem(a.index, 1) end
    else
      local stapel = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(a.index)) or 20
      local rest = a.kaeufe
      while rest > 0 do
        local n = math.min(rest, math.max(stapel, 1))
        BuyMerchantItem(a.index, n)
        rest = rest - n
      end
    end
    ns.Print("Gekauft: " .. (a.kaeufe * a.pro) .. "× " .. ns.ItemName(a.id))
  end
end

function ns.FehlendesKaufen()
  local angebot, summe = ns.HaendlerAngebot()
  if #angebot == 0 then
    ns.Print("Dieser Händler hat nichts, was auf deiner Liste fehlt.")
    ns.Sprechen("Dieser Händler hat nichts, was auf deiner Liste fehlt.")
    return
  end
  if GetMoney and GetMoney() < summe then
    ns.Print(F.rot .. "Nicht genug Geld: " .. Geld(summe) .. " nötig.|r")
    return
  end
  local namen = {}
  for _, a in ipairs(angebot) do namen[#namen + 1] = (a.kaeufe * a.pro) .. "× " .. ns.ItemName(a.id) end
  local text = table.concat(namen, ", ")
  if StaticPopupDialogs and StaticPopup_Show then
    StaticPopupDialogs.WERKBANK_KAUFEN = {
      text = "Werkbank: %s kaufen für %s?",
      button1 = YES or "Ja", button2 = NO or "Nein",
      OnAccept = function() Kaufen(ns.HaendlerAngebot()) end,
      timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("WERKBANK_KAUFEN", text, Geld(summe))
    ns.Sprechen(text .. " kaufen für " .. math.floor(summe / 10000) .. " Gold " .. (math.floor(summe / 100) % 100) .. " Silber " .. (summe % 100) .. " Kupfer?")
  else
    Kaufen(angebot)
  end
end

ns.AufEreignis("MERCHANT_SHOW", function()
  if not MerchantFrame or MerchantFrame.werkbankKnopf then return end
  local b = Knopf(MerchantFrame, "Fehlendes kaufen", 130)
  b:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -44, -44)
  b:SetFrameLevel(MerchantFrame:GetFrameLevel() + 5)
  b:SetScript("OnClick", ns.FehlendesKaufen)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Werkbank", 1, 1, 1)
    local angebot, summe = ns.HaendlerAngebot()
    if #angebot == 0 then
      GameTooltip:AddLine("Hier gibt es nichts von deiner Liste.", 0.7, 0.7, 0.7)
    else
      for _, a in ipairs(angebot) do GameTooltip:AddDoubleLine((a.kaeufe * a.pro) .. "× " .. ns.ItemName(a.id), Geld(a.preis), 1, 1, 1, 1, 1, 1) end
      GameTooltip:AddDoubleLine("Zusammen", Geld(summe), 1, 0.82, 0, 1, 0.82, 0)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  MerchantFrame.werkbankKnopf = b
end)

-- ---------- Bank: Materialien in die Taschen holen ----------

local function Benutzen(bag, slot)
  if C_Container and C_Container.UseContainerItem then return C_Container.UseContainerItem(bag, slot) end
  if UseContainerItem then return UseContainerItem(bag, slot) end
end

function ns.MaterialHolen()
  if not ns.bankOffen then
    ns.Print("Dazu muss die Bank geöffnet sein.")
    return 0
  end
  local bedarf = ns.Rechnen()
  local inTaschen = {}
  for id in pairs(bedarf) do inTaschen[id] = GetItemCount and GetItemCount(id) or 0 end
  local stapel = 0
  for _, bag in ipairs(ns.BankBags()) do
    for slot = 1, ns.SlotAnzahl(bag) do
      local id, n = ns.SlotInhalt(bag, slot)
      if id and bedarf[id] and inTaschen[id] < bedarf[id] then
        Benutzen(bag, slot)
        inTaschen[id] = inTaschen[id] + (n or 1)
        stapel = stapel + 1
      end
    end
  end
  if stapel == 0 then
    ns.Print("In der Bank liegt nichts, was du für die Liste noch in den Taschen brauchst.")
  else
    ns.Print(stapel .. (stapel == 1 and " Stapel" or " Stapel") .. " aus der Bank geholt.")
  end
  ns.Sprechen(stapel .. " Stapel aus der Bank geholt.")
  return stapel
end

ns.AufEreignis("BANKFRAME_OPENED", function()
  if not BankFrame or BankFrame.werkbankKnopf then return end
  local b = Knopf(BankFrame, "Material holen", 120)
  b:SetPoint("TOPRIGHT", BankFrame, "TOPRIGHT", -50, -40)
  b:SetFrameLevel(BankFrame:GetFrameLevel() + 5)
  b:SetScript("OnClick", ns.MaterialHolen)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Werkbank", 1, 1, 1)
    GameTooltip:AddLine("Holt alles aus der Bank in die Taschen, was du für die Einkaufsliste brauchst.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  BankFrame.werkbankKnopf = b
end)

-- ---------- Auktionshaus: Material suchen ----------

function ns.AHSuchen(id)
  local name = ns.ItemName(id)
  if AuctionFrame and AuctionFrame:IsShown() and BrowseName then
    if AuctionFrameTab1 and AuctionFrameTab_OnClick then pcall(AuctionFrameTab_OnClick, AuctionFrameTab1) end
    BrowseName:SetText(name)
    if AuctionFrameBrowse_Search then pcall(AuctionFrameBrowse_Search) end
    ns.Print("Suche im Auktionshaus: " .. name)
    return true
  end
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame.SearchBar then
    local bar = AuctionHouseFrame.SearchBar
    if bar.SearchBox then bar.SearchBox:SetText(name) end
    if bar.StartSearch then pcall(bar.StartSearch, bar) end
    ns.Print("Suche im Auktionshaus: " .. name)
    return true
  end
  return false
end

-- ---------- Fehlende Materialien im Chat teilen ----------

local KANAELE = { gruppe = true, gilde = "GUILD", sagen = "SAY", schlachtzug = "RAID" }

function ns.ChatZeilen()
  local fehlt = ns.Fehlend()
  local teile = {}
  for _, id in ipairs(Sortiert(fehlt)) do teile[#teile + 1] = fehlt[id] .. "× " .. ns.ItemName(id) end
  if #teile == 0 then return { "[Werkbank] Mir fehlt nichts mehr für meine Liste." } end
  local zeilen, z = {}, "[Werkbank] Mir fehlt: "
  for i, t in ipairs(teile) do
    local stueck = t .. (i < #teile and ", " or "")
    if #z + #stueck > 250 then
      zeilen[#zeilen + 1] = z
      z = ""
    end
    z = z .. stueck
  end
  zeilen[#zeilen + 1] = z
  return zeilen
end

function ns.ChatTeilen(kanal)
  kanal = (kanal or "gruppe"):lower()
  if not KANAELE[kanal] then kanal = "gruppe" end
  local ziel = KANAELE[kanal]
  if ziel == true then
    if IsInRaid and IsInRaid() then ziel = "RAID"
    elseif IsInGroup and IsInGroup() then ziel = "PARTY"
    else ziel = nil end
  end
  if ziel == "GUILD" and IsInGuild and not IsInGuild() then ziel = nil end
  local zeilen = ns.ChatZeilen()
  if not ziel or not SendChatMessage then
    ns.Print("Du bist in keiner Gruppe oder Gilde. So sähe die Nachricht aus:")
    for _, z in ipairs(zeilen) do DEFAULT_CHAT_FRAME:AddMessage("  " .. z) end
    return zeilen
  end
  for _, z in ipairs(zeilen) do SendChatMessage(z, ziel) end
  return zeilen
end
