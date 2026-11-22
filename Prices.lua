-- ============================================================================
-- ProfRoute — Prices.lua
-- Единая точка получения цены предмета.
-- Приоритет источников:
--   1. Auctionator (если установлен) — свежие цены из его базы
--   2. TradeSkillMaster (если установлен) — DBMinBuyout
--   3. Собственный сканер ProfRoute (результаты сохраняются в SavedVariables)
--   4. Цена торговца (для реагентов, которые продаются у NPC)
-- Цены в меди. Цена торговца также служит потолком: если на аукционе дороже
-- торговца, выгоднее купить у торговца.
-- ============================================================================

local PR = ProfRoute

local function RealmDB()
    local realm = GetRealmName and GetRealmName() or "?"
    PR.db.prices[realm] = PR.db.prices[realm] or {}
    return PR.db.prices[realm]
end

-- Сохранить цену, полученную собственным сканером
function PR.SaveScannedPrice(itemID, price)
    if not itemID or not price or price <= 0 then return end
    RealmDB()[itemID] = { price = price, time = time() }
end

-- Цена из Auctionator (официальный API аддона)
local function AuctionatorPrice(itemID)
    if not (Auctionator and Auctionator.API and Auctionator.API.v1
        and Auctionator.API.v1.GetAuctionPriceByItemID) then
        return nil
    end
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "ProfRoute", itemID)
    if ok and type(price) == "number" and price > 0 then return price end
    return nil
end

-- Цена из TradeSkillMaster
local function TSMPrice(itemID)
    if not (TSM_API and TSM_API.GetCustomPriceValue) then return nil end
    local ok, price = pcall(TSM_API.GetCustomPriceValue, "DBMinBuyout", "i:" .. itemID)
    if ok and type(price) == "number" and price > 0 then return price end
    return nil
end

-- Цена из собственной базы сканов (nil, если устарела)
function PR.GetScannedPrice(itemID)
    local rec = RealmDB()[itemID]
    if not rec then return nil, nil end
    local age = time() - (rec.time or 0)
    local stale = age > (PR.db.scanTimeoutMin or 120) * 60
    return rec.price, rec.time, stale
end

-- Главная функция: цена за 1 шт. предмета.
-- Возвращает price, source ("auctionator"|"tsm"|"scan"|"vendor"), stale
function PR.GetPrice(itemID)
    local p = AuctionatorPrice(itemID)
    if p then return p, "auctionator", false end

    p = TSMPrice(itemID)
    if p then return p, "tsm", false end

    local sp, _, stale = PR.GetScannedPrice(itemID)
    local vendor = PR.VendorPrice[itemID]

    -- если есть и аукцион, и торговец — берём дешевле
    if sp and vendor then
        if vendor <= sp then return vendor, "vendor", false end
        return sp, "scan", stale
    end
    if sp then return sp, "scan", stale end
    if vendor then return vendor, "vendor", false end
    return nil, nil, false
end

-- Есть ли вообще хоть какой-то источник цен для предмета
function PR.HasAnyPrice(itemID)
    local p = PR.GetPrice(itemID)
    return p ~= nil
end

-- Какой источник цен сейчас основной (для строки состояния в UI)
function PR.PriceSourceLabel()
    if Auctionator and Auctionator.API then
        return "Auctionator"
    elseif TSM_API then
        return "TSM"
    end
    return PR.L("SRC_SCANNER")
end
