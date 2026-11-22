-- ============================================================================
-- ProfRoute — Scanner.lua
-- Собственный лёгкий сканер аукциона.
--
-- В отличие от полных сканов Auctionator, сканируем только те предметы,
-- которые реально нужны для маршрута (обычно 10-40 позиций) — это занимает
-- секунды вместо минут. Используется современный API C_AuctionHouse,
-- доступный в клиенте Forever.
--
-- Сканер работает только при открытом окне аукциона.
-- ============================================================================

local PR = ProfRoute

PR.Scanner = {
    queue = {},        -- очередь itemID
    active = false,    -- идёт ли сканирование
    waiting = false,   -- ждём ответ на текущий запрос
    current = nil,     -- текущий itemID
    total = 0,
    done = 0,
    found = 0,
}
local S = PR.Scanner

local INTERVAL = 0.5 -- пауза между запросами, сек.

-- ---------------------------------------------------------------------------
-- Поддержка API
-- ---------------------------------------------------------------------------
function S.IsSupported()
    return C_AuctionHouse ~= nil
        and C_AuctionHouse.SendSearchQuery ~= nil
        and C_AuctionHouse.MakeItemKey ~= nil
        and C_AuctionHouse.GetBrowseResults ~= nil
end

local function AtAuctionHouse()
    return C_AuctionHouse.IsAuctionHouseOpen and C_AuctionHouse.IsAuctionHouseOpen()
        or (AuctionHouseFrame and AuctionHouseFrame:IsShown())
end

-- ---------------------------------------------------------------------------
-- Управление очередью
-- ---------------------------------------------------------------------------
function S.Enqueue(itemIDs)
    local inQueue = {}
    for _, id in ipairs(S.queue) do inQueue[id] = true end
    for _, id in ipairs(itemIDs) do
        if not inQueue[id] then
            table.insert(S.queue, id)
            inQueue[id] = true
        end
    end
    S.total = #S.queue
end

-- Собрать все реагенты выбранной профессии и начать сканирование
function S.StartForPlan()
    if not S.IsSupported() then
        PR.Print(PR.L("SCAN_NO_SUPPORT"))
        return
    end
    if not AtAuctionHouse() then
        PR.Print(PR.L("SCAN_OPEN_AH"))
        return
    end

    local key = PR.state.profession
    if not key then
        PR.Print(PR.L("SCAN_SELECT_PROF"))
        return
    end

    local ids = {}
    local plan = PR.state.plan
    if plan and plan.shopping then
        -- приоритет: то, что реально нужно докупить
        for _, row in ipairs(plan.shopping) do
            table.insert(ids, row.itemID)
        end
    end
    for _, r in ipairs(PR.Professions[key].recipes) do
        for _, rg in ipairs(r.reagents) do
            table.insert(ids, rg[1])
        end
    end

    S.queue = {}
    S.done, S.found = 0, 0
    S.Enqueue(ids)
    S.active = true
    S.waiting = false
    PR.Print(PR.L("SCAN_START"), #S.queue)
    if PR.UI and PR.UI.RefreshScanStatus then PR.UI.RefreshScanStatus() end
end

-- ---------------------------------------------------------------------------
-- Отправка одного запроса
-- ---------------------------------------------------------------------------
local function SendNext()
    local itemID = table.remove(S.queue, 1)
    if not itemID then
        S.active = false
        PR.Print(PR.L("SCAN_DONE"), S.found, S.done)
        if PR.UI then
            if PR.UI.RefreshScanStatus then PR.UI.RefreshScanStatus() end
            if PR.UI.RefreshAll then PR.UI.RefreshAll() end
        end
        return
    end

    S.current = itemID
    S.waiting = true

    local sorts = {}
    if Enum and Enum.AuctionHouseSortOrder then
        table.insert(sorts, { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false })
    end

    local ok, err = pcall(C_AuctionHouse.SendSearchQuery,
        C_AuctionHouse.MakeItemKey(itemID), sorts, false)
    if not ok then
        -- защита от изменений сигнатуры API: пробуем без сортировки
        ok, err = pcall(C_AuctionHouse.SendSearchQuery,
            C_AuctionHouse.MakeItemKey(itemID), {}, false)
    end
    if not ok then
        S.waiting = false
        S.done = S.done + 1
        PR.Print(PR.L("SCAN_QUERY_FAIL"), S.done, tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Обработка ответа аукциона
-- ---------------------------------------------------------------------------
local function OnBrowseResults()
    if not S.waiting or not S.current then return end
    S.waiting = false
    S.done = S.done + 1

    local itemID = S.current
    local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
    local best

    if ok and type(results) == "table" then
        for _, row in ipairs(results) do
            local match = false
            if row.itemKey and row.itemKey.itemID == itemID then
                match = true
            elseif row.itemID == itemID then
                match = true
            end
            if match then
                -- цена за единицу: в разных билдах поле называется по-разному
                local unit
                if row.minPrice and row.minPrice > 0 then
                    unit = row.minPrice
                elseif row.buyoutAmount and row.buyoutAmount > 0 then
                    unit = row.buyoutAmount
                elseif row.totalPrice and row.quantity and row.quantity > 0 then
                    unit = math.floor(row.totalPrice / row.quantity)
                end
                if unit and unit > 0 and (not best or unit < best) then
                    best = unit
                end
            end
        end
    end

    if best then
        PR.SaveScannedPrice(itemID, best)
        S.found = S.found + 1
    end

    if PR.UI and PR.UI.RefreshScanStatus then PR.UI.RefreshScanStatus() end
end

-- ---------------------------------------------------------------------------
-- События и тикер
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
-- регистрируем безопасно: если события нет в конкретном билде Forever,
-- pcall проглотит ошибку, а остальные события продолжат работать
for _, event in ipairs({
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "AUCTION_HOUSE_BROWSE_FAILURE",
    "AUCTION_HOUSE_CLOSED",
}) do
    pcall(ev.RegisterEvent, ev, event)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"
        or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        OnBrowseResults()
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        S.waiting = false
        S.done = S.done + 1
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if S.active then
            S.active = false
            S.queue = {}
            PR.Print(PR.L("SCAN_ABORTED"))
        end
    end
end)

-- тикер очереди: учитываем серверное ограничение частоты запросов
C_Timer.NewTicker(INTERVAL, function()
    if not S.active or S.waiting then return end
    if not AtAuctionHouse() then return end
    if C_AuctionHouse.IsThrottledMessageSystemReady
        and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        return
    end
    SendNext()
end)
