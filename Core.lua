-- ============================================================================
-- ProfRoute — Core.lua
-- Инициализация аддона, хранилище настроек, события, слэш-команды.
-- Клиент: WoW: Forever (1.60.1, Interface 16001, современное API Mainline).
-- ============================================================================

local ADDON_NAME = ...

ProfRoute = {}
local PR = ProfRoute

PR.VERSION = "1.0.4"

-- Цвета оформления (единая палитра, используется в UI)
PR.COLORS = {
    bg        = { 0.055, 0.075, 0.115, 0.96 },
    bgLight   = { 0.09, 0.12, 0.18, 1.0 },
    bgRow     = { 0.08, 0.105, 0.16, 1.0 },
    bgRowAlt  = { 0.065, 0.088, 0.135, 1.0 },
    border    = { 0.30, 0.55, 0.95, 1.0 },
    borderDim = { 0.18, 0.24, 0.34, 1.0 },
    text      = { 0.92, 0.93, 0.97, 1.0 },
    textDim   = { 0.55, 0.60, 0.70, 1.0 },
    accent    = { 0.30, 0.62, 1.00, 1.0 },
    gold      = { 1.00, 0.84, 0.10, 1.0 },
    green     = { 0.35, 0.85, 0.45, 1.0 },
    red       = { 0.95, 0.35, 0.35, 1.0 },
    -- цвета сложности рецептов (как в игре)
    orange    = { 1.00, 0.50, 0.00, 1.0 },
    yellow    = { 1.00, 1.00, 0.00, 1.0 },
    greenDiff = { 0.10, 0.75, 0.10, 1.0 },
    grayDiff  = { 0.60, 0.60, 0.60, 1.0 },
}

-- ---------------------------------------------------------------------------
-- Настройки по умолчанию
-- ---------------------------------------------------------------------------
local DEFAULTS = {
    prices = {},          -- [realm] = { [itemID] = { price=..., time=... } }
    targetSkill = 300,
    useBank = true,       -- учитывать банк при подсчёте "уже есть"
    scanTimeoutMin = 120, -- через сколько минут цены считаются устаревшими
    lastProfession = nil,
    framePos = nil,       -- { point, x, y }
}

-- ---------------------------------------------------------------------------
-- Служебные функции
-- ---------------------------------------------------------------------------

-- Форматирование денег: 123456 -> "12г 34с 56м"
function PR.FormatMoney(copper)
    if not copper then return "|cff8c8c8cнет данных|r" end
    copper = math.floor(copper + 0.5)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return string.format("|cffffd700%d|r|cffffffffг|r |cffc7c7cf%d|r|cffffffffс|r", g, s)
    elseif s > 0 then
        return string.format("|cffc7c7cf%d|r|cffffffffс|r |cffeda55f%d|r|cffffffffм|r", s, c)
    end
    return string.format("|cffeda55f%d|r|cffffffffм|r", c)
end

function PR.FormatMoneyShort(copper)
    if not copper then return "--" end
    copper = math.floor(copper + 0.5)
    local g = math.floor(copper / 10000)
    if g > 0 then
        return string.format("%.1fг", copper / 10000)
    end
    return string.format("%dс", math.floor((copper % 10000) / 100))
end

-- Сообщение в чат
function PR.Print(msg, ...)
    if ... then msg = string.format(msg, ...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff4da3ff[ProfRoute]|r " .. msg)
end

-- Текущий маршрут/результат расчёта (пересчитывается планировщиком)
PR.state = {
    profession = nil,   -- ключ профессии, напр. "ALCHEMY"
    currentSkill = 0,
    targetSkill = 300,
    plan = nil,         -- результат Planner.BuildPlan
    shopping = nil,     -- результат Planner.BuildShoppingList
}

-- ---------------------------------------------------------------------------
-- Определение профессий персонажа
-- ---------------------------------------------------------------------------

-- Возвращает таблицу { [PROF_KEY] = { skill=, maxSkill= } } для изученных профессий
function PR.GetPlayerProfessions()
    local found = {}
    if not GetProfessions then return found end
    -- GetProfessions возвращает несколько значений, среди них могут быть nil
    -- (пустые слоты) — обходим через select, а не ipairs по таблице
    for i = 1, 6 do
        local idx = select(i, GetProfessions())
        if idx then
            local name, _, skill, maxSkill = GetProfessionInfo(idx)
            if name then
                local key = PR.RecipesByName and PR.RecipesByName[name]
                if key then
                    found[key] = { skill = skill or 0, maxSkill = maxSkill or 300 }
                end
            end
        end
    end
    return found
end

-- ---------------------------------------------------------------------------
-- События
-- ---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
PR.frame = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ProfRouteDB = ProfRouteDB or {}
        for k, v in pairs(DEFAULTS) do
            if ProfRouteDB[k] == nil then ProfRouteDB[k] = v end
        end
        PR.db = ProfRouteDB

        -- подгружаем данные о предметах, которые встречаются в рецептах,
        -- чтобы имена/иконки были доступны без задержек
        if PR.PrecacheItems then PR.PrecacheItems() end

    elseif event == "PLAYER_LOGIN" then
        PR.Print("загружен. Открыть окно: |cffffffff/proute|r")
        if C_Item and C_Item.GetItemCount == nil then
            PR.Print("|cffff8080внимание:|r нестандартное API клиента, проверьте работу на текущем билде.")
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Слэш-команды
-- ---------------------------------------------------------------------------
SLASH_PROFROUTE1 = "/proute"
SLASH_PROFROUTE2 = "/прокачка"

SlashCmdList.PROFROUTE = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "scan" then
        if PR.Scanner and PR.Scanner.StartForPlan then
            PR.Scanner.StartForPlan()
        else
            PR.Print("сканер недоступен.")
        end
    elseif msg == "minimap" then
        if PR.ToggleMinimapButton then
            PR.ToggleMinimapButton()
        end
    elseif msg == "reset" then
        ProfRouteDB.prices = {}
        PR.Print("база цен очищена.")
    else
        if PR.UI and PR.UI.Toggle then PR.UI.Toggle() end
    end
end
