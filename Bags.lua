-- ============================================================================
-- ProfRoute — Bags.lua
-- Подсчёт реагентов в сумках, банке и сумке реагентов.
-- ============================================================================

local PR = ProfRoute

PR.Bags = {}
local B = PR.Bags

-- Сколько штук предмета есть у персонажа (сумки + банк, если включено в настройках)
function B.Count(itemID)
    if not (C_Item and C_Item.GetItemCount) then return 0 end
    local includeBank = PR.db.useBank ~= false
    local ok, n = pcall(C_Item.GetItemCount, itemID, includeBank, false, true)
    if ok and type(n) == "number" then return n end
    -- запасной вариант для старых сигнатур
    ok, n = pcall(C_Item.GetItemCount, itemID, includeBank)
    if ok and type(n) == "number" then return n end
    return 0
end

-- Разбивка по местам хранения (для подсказки в UI)
function B.CountDetailed(itemID)
    local bags, bank = 0, 0
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, itemID, false, false, true)
        if ok then bags = n or 0 end
        local ok2, nb = pcall(C_Item.GetItemCount, itemID, true, false, true)
        if ok2 then bank = math.max(0, (nb or 0) - bags) end
    end
    return bags, bank
end

-- Подписаться на обновление содержимого сумок (вызывает callback)
function B.Watch(callback)
    local f = CreateFrame("Frame")
    -- На Forever части классических/современных событий может не быть
    -- (нет реагентного банка и т.п.) — регистрируем безопасно, через pcall
    for _, event in ipairs({
        "BAG_UPDATE_DELAYED",
        "BANKFRAME_OPENED",
        "PLAYERBANKSLOTS_CHANGED",
    }) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", function()
        -- небольшая задержка, чтобы дать клиенту обновить кэши
        C_Timer.After(0.1, function()
            if ProfRoute.UI and ProfRoute.UI.IsShown and ProfRoute.UI.IsShown() then
                callback()
            end
        end)
    end)
end
