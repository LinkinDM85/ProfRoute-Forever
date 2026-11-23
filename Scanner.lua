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
    if plan and plan.suggestions then
        -- свитки выгодных рецептов, которые покупаются на аукционе
        for _, sg in ipairs(plan.suggestions) do
            if not sg.cand.vendor then
                table.insert(ids, sg.cand.item)
            end
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
-- обработчик событий назначен ниже, в разделе кнопки на окне аукциона
-- (один OnEvent на все события сканера)

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

-- ---------------------------------------------------------------------------
-- Кнопка сканирования на окне аукциона
-- ---------------------------------------------------------------------------
-- Кнопка привязывается к фрейму аукциона, поэтому показывается и прячется
-- вместе с ним. Создаём лениво: фрейм аукциона может ещё не существовать
-- на момент загрузки аддона.

local ahButton

local function EnsureAHButton()
    if ahButton then return true end
    local ah = _G.AuctionHouseFrame or _G.AuctionFrame
    if not ah then return false end

    local b = CreateFrame("Button", "ProfRouteAHScanButton", ah)
    b:SetSize(128, 24)
    -- в правом верхнем углу, слева от кнопки закрытия — там всегда свободно;
    -- строка поиска товаров находится ниже и кнопку больше не перекрывает
    local ok
    local closeBtn = ah.GetName and ah:GetName() and _G[ah:GetName() .. "CloseButton"]
    if closeBtn then
        ok = pcall(b.SetPoint, b, "RIGHT", closeBtn, "LEFT", -6, 0)
    end
    if not ok then
        ok = pcall(b.SetPoint, b, "TOPRIGHT", ah, "TOPRIGHT", -40, -8)
    end
    if not ok then
        pcall(b.SetPoint, b, "TOP", ah, "TOP", 0, -34)
    end

    if not b.SetBackdrop and Mixin and BackdropTemplateMixin then
        Mixin(b, BackdropTemplateMixin)
    end
    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    b:SetBackdropColor(0.09, 0.12, 0.19, 0.95)
    b:SetBackdropBorderColor(unpack(PR.COLORS.accent))

    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(PR.L("UI_SCAN_AH_BTN"))

    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.84, 0.1)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(PR.L("UI_SCAN_BTN_TT"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(PR.COLORS.accent))
        if GameTooltip then GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function()
        PR.Scanner.StartForPlan()
        -- если план ещё не построен — открываем окно, чтобы было что сканировать
        if not (PR.state and PR.state.profession)
            and PR.UI and PR.UI.Toggle then
            PR.UI.Toggle()
        end
    end)

    ahButton = b
    return true
end

-- пробуем создать кнопку при логине и при каждом событии аукциона —
-- одно из событий в конкретном билде Forever наверняка наступит
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "AUCTION_HOUSE_SHOW" then
        EnsureAHButton()
    end
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
        if S.searchActive then
            S.searchActive = false
            S.searchQueue = nil
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Поиск покупок на аукционе
-- ---------------------------------------------------------------------------
-- Одна кнопка в окне аддона -> аддон по очереди подставляет в строку поиска
-- аукциона каждый предмет из списка покупок. Покупать всё равно приходится
-- вручную (автоматизация запрещена правилами Blizzard), но листинги нужных
-- товаров разворачиваются сами.

S.searchActive = false
S.searchQueue = nil -- { {itemID, name, count}, ... }
S.searchIdx = 0

local SEARCH_STEP_DELAY = 2.0 -- пауза между подстановками, сек.

-- Подставить текст в строку поиска открытого окна аукциона и запустить поиск.
-- Поддерживает классический (AuctionFrame) и современный (AuctionHouseFrame)
-- интерфейсы. Возвращает true, если поиск удалось запустить.
local function SetAHSearch(text)
    if not text or text == "" then return false end

    -- классический интерфейс ( Forever / classic )
    local af = _G.AuctionFrame
    if af and af:IsShown() and _G.BrowseName then
        _G.BrowseName:SetText(text)
        if _G.AuctionFrameBrowse_Search then
            pcall(_G.AuctionFrameBrowse_Search)
        end
        return true
    end

    -- современный интерфейс
    local ah = _G.AuctionHouseFrame
    if ah and ah:IsShown() and ah.SearchBar and ah.SearchBar.SearchBox then
        ah.SearchBar.SearchBox:SetText(text)
        if ah.SearchBar.StartSearch then
            pcall(function() ah.SearchBar:StartSearch() end)
        end
        return true
    end

    return false
end

local function NextSearchStep()
    if not S.searchActive then return end
    if not AtAuctionHouse() then
        S.searchActive = false
        S.searchQueue = nil
        if PR.UI and PR.UI.RefreshScanStatus then PR.UI.RefreshScanStatus() end
        return
    end

    S.searchIdx = S.searchIdx + 1
    local entry = S.searchQueue[S.searchIdx]
    if not entry then
        S.searchActive = false
        S.searchQueue = nil
        PR.Print(PR.L("UI_SEARCH_DONE"), S.searchIdx - 1)
        if PR.UI and PR.UI.RefreshScanStatus then PR.UI.RefreshScanStatus() end
        return
    end

    SetAHSearch(entry.name)
    if PR.UI and PR.UI.RefreshScanStatus then PR.UI.RefreshScanStatus() end
    C_Timer.After(SEARCH_STEP_DELAY, NextSearchStep)
end

-- Запустить обход списка покупок: каждая позиция с buy > 0 будет
-- последовательно искаться на аукционе.
function S.SearchShoppingOnAH()
    if not S.IsSupported() then
        PR.Print(PR.L("SCAN_NO_SUPPORT"))
        return
    end
    if not AtAuctionHouse() then
        PR.Print(PR.L("SCAN_OPEN_AH"))
        return
    end

    local plan = PR.state.plan
    if not (plan and plan.shopping and #plan.shopping > 0) then
        PR.Print(PR.L("UI_NOTHING_TO_BUY"))
        return
    end

    local q = {}
    for _, it in ipairs(plan.shopping) do
        if it.buy > 0 then
            local nm = (C_Item and C_Item.GetItemNameByID)
                and C_Item.GetItemNameByID(it.itemID)
            if nm and nm ~= "" then
                table.insert(q, { itemID = it.itemID, name = nm, count = it.buy })
            end
        end
    end

    if #q == 0 then
        PR.Print(PR.L("UI_NOTHING_TO_BUY"))
        return
    end

    S.searchQueue = q
    S.searchIdx = 0
    S.searchActive = true
    NextSearchStep()
end

-- Поиск одного предмета (Shift+клик по строке в окне аддона).
-- Возвращает true, если поиск был запущен.
function S.SearchItemOnAH(itemID)
    if not itemID or not AtAuctionHouse() then return false end
    local nm = (C_Item and C_Item.GetItemNameByID)
        and C_Item.GetItemNameByID(itemID)
    if not nm or nm == "" then return false end
    return SetAHSearch(nm)
end
