-- ============================================================================
-- ProfRoute — UI.lua
-- Главное окно: выбор профессии, маршрут прокачки, список покупок.
-- Открытие: /proute
-- ============================================================================

local PR = ProfRoute

PR.UI = {}
local UI = PR.UI

local C = PR.COLORS

local FRAME_W, FRAME_H = 820, 560
local ROW_H = 34

-- ---------------------------------------------------------------------------
-- Хелперы отрисовки
-- ---------------------------------------------------------------------------

local function SetFlatBackdrop(fr, bg, border)
    -- обычные Frame в современном клиенте не имеют SetBackdrop — подмешиваем
    if not fr.SetBackdrop and Mixin and BackdropTemplateMixin then
        Mixin(fr, BackdropTemplateMixin)
    end
    fr:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    fr:SetBackdropColor(unpack(bg))
    fr:SetBackdropBorderColor(unpack(border))
end

local function MakeText(parent, template, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(template or GameFontHighlight)
    fs:SetTextColor(unpack(C.text))
    return fs
end

local function MakeButton(parent, w, h, label, accent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    SetFlatBackdrop(b, accent and { 0.15, 0.32, 0.62, 1 } or C.bgLight,
        accent and C.accent or C.borderDim)
    b.text = MakeText(b)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    if accent then b.text:SetTextColor(1, 1, 1) end
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
    end)
    b:SetScript("OnLeave", function(self)
        SetFlatBackdrop(self, accent and { 0.15, 0.32, 0.62, 1 } or C.bgLight,
            accent and C.accent or C.borderDim)
    end)
    return b
end

local function MakeEditBox(parent, w, label)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(w, 22)
    SetFlatBackdrop(wrap, { 0.03, 0.04, 0.07, 1 }, C.borderDim)
    local eb = CreateFrame("EditBox", nil, wrap)
    eb:SetPoint("TOPLEFT", 6, -2)
    eb:SetPoint("BOTTOMRIGHT", -4, 2)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlight)
    eb:SetTextColor(unpack(C.text))
    eb:SetJustifyH("CENTER")
    eb:SetNumeric(true)
    eb:SetMaxLetters(3)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if label then
        wrap.label = MakeText(wrap, GameFontDisableSmall)
        wrap.label:SetPoint("BOTTOMLEFT", wrap, "TOPLEFT", 0, 2)
        wrap.label:SetText(label)
        wrap.label:SetTextColor(unpack(C.textDim))
    end
    return wrap, eb
end

-- ---------------------------------------------------------------------------
-- Простой список со скроллом (своя полоса прокрутки — без зависимостей
-- от шаблонов Blizzard, которые меняются между клиентами)
-- ---------------------------------------------------------------------------

local function MakeScrollList(parent)
    local holder = CreateFrame("Frame", nil, parent)
    SetFlatBackdrop(holder, { 0.03, 0.04, 0.07, 1 }, C.borderDim)

    local scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", -14, 2)

    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)

    -- полоса прокрутки
    local bar = CreateFrame("Slider", nil, holder)
    bar:SetWidth(10)
    bar:SetPoint("TOPRIGHT", -2, -16)
    bar:SetPoint("BOTTOMRIGHT", -2, 16)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    SetFlatBackdrop(bar, { 0.06, 0.08, 0.12, 1 }, C.borderDim)
    bar.thumb = bar:CreateTexture(nil, "OVERLAY")
    bar.thumb:SetColorTexture(unpack(C.accent))
    bar.thumb:SetSize(8, 40)
    bar:SetThumbTexture(bar.thumb)

    local function UpdateScrollRange()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        local viewH = scroll:GetHeight()
        local contentH = content:GetHeight()
        local range = math.max(0, contentH - viewH)
        bar:SetMinMaxValues(0, range)
        if range <= 0 then bar:Hide() else bar:Show() end
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), range))
    end

    bar:SetScript("OnValueChanged", function(_, v)
        scroll:SetVerticalScroll(v)
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(bar:GetValue() - delta * ROW_H * 2)
    end)
    holder:SetScript("OnSizeChanged", UpdateScrollRange)

    return {
        holder = holder,
        scroll = scroll,
        content = content,
        bar = bar,
        rows = {},
        UpdateScrollRange = UpdateScrollRange,
    }
end

-- ---------------------------------------------------------------------------
-- Строки списков
-- ---------------------------------------------------------------------------

local function AcquireRow(list, i, rightWidth)
    local row = list.rows[i]
    if not row then
        row = CreateFrame("Button", nil, list.content)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(unpack(i % 2 == 0 and C.bgRowAlt or C.bgRow))

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 6, 0)

        row.iconBorder = CreateFrame("Frame", nil, row)
        row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
        row.iconBorder:SetSize(26, 26)
        SetFlatBackdrop(row.iconBorder, { 0, 0, 0, 0 }, C.borderDim)
        row.iconBorder:SetFrameLevel(row:GetFrameLevel() + 1)

        row.name = MakeText(row, GameFontHighlight)
        row.name:SetPoint("TOPLEFT", 40, -4)
        row.name:SetJustifyH("LEFT")

        row.sub = MakeText(row, GameFontDisableSmall)
        row.sub:SetPoint("BOTTOMLEFT", 40, 4)
        row.sub:SetJustifyH("LEFT")
        row.sub:SetTextColor(unpack(C.textDim))

        row.right = MakeText(row, GameFontHighlight)
        row.right:SetPoint("RIGHT", -8, 6)
        row.right:SetJustifyH("RIGHT")

        row.right2 = MakeText(row, GameFontDisableSmall)
        row.right2:SetPoint("RIGHT", -8, -8)
        row.right2:SetJustifyH("RIGHT")

        row.hl = row:CreateTexture(nil, "HIGHLIGHT")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(0.3, 0.55, 0.95, 0.12)

        list.rows[i] = row
    end
    return row
end

-- тултип предмета при наведении на строку
local function HookRowTooltip(row, itemID)
    row:SetScript("OnEnter", function(self)
        if itemID and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(itemID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

-- ---------------------------------------------------------------------------
-- Главное окно
-- ---------------------------------------------------------------------------
local f -- главный фрейм

function UI.IsShown()
    return f and f:IsShown()
end

local function ProfDisplayName(key)
    local p = PR.Professions[key]
    local locale = GetLocale and GetLocale() or "ruRU"
    if locale == "ruRU" then return p.names.ru end
    return p.names.en
end

-- ---------------------------------------------------------------------------
-- Пересчёт плана и списка покупок
-- ---------------------------------------------------------------------------

local function RebuildPlan()
    local key = PR.state.profession
    if not key then return end

    local cur = tonumber(f.skillBox:GetText()) or PR.state.currentSkill or 1
    local tgt = tonumber(f.targetBox:GetText()) or PR.db.targetSkill or 300
    tgt = math.max(cur + 1, math.min(300, tgt))

    PR.state.currentSkill = cur
    PR.state.targetSkill = tgt
    PR.db.targetSkill = tgt
    PR.db.lastProfession = key

    local plan = PR.Planner.BuildPlan(key, cur, tgt)
    PR.state.plan = plan
    if plan and plan.possible then
        plan.shopping, plan.shoppingTotal = PR.Planner.BuildShoppingList(plan)
    else
        plan = plan or { steps = {} }
        plan.shopping = {}
    end

    UI.RefreshPlan()
    UI.RefreshShopping()
end

-- ---------------------------------------------------------------------------
-- Обновление левой панели: маршрут
-- ---------------------------------------------------------------------------

function UI.RefreshPlan()
    local list = f.planList
    local plan = PR.state.plan
    local steps = (plan and plan.steps) or {}

    for i, row in ipairs(list.rows) do row:Hide() end

    if not plan or not plan.possible or #steps == 0 then
        f.planEmpty:Show()
        if plan and not plan.possible then
            f.planEmpty:SetText("Не удалось построить маршрут:\nв базе нет рецептов для выбранного диапазона навыка.")
        else
            f.planEmpty:SetText("Выберите профессию и нажмите «Построить план».")
        end
        f.planTotal:SetText("")
        return
    end
    f.planEmpty:Hide()

    local W = list.holder:GetWidth() - 16
    for i, step in ipairs(steps) do
        local r = step.recipe
        local row = AcquireRow(list, i)
        row:Show()
        row.icon:SetTexture(PR.RecipeIcon(r))
        row.name:SetText(PR.RecipeName(r))

        local col = PR.Planner.DifficultyColor(r, step.from)
        row.sub:SetText(string.format("навык %d → %d   ·   создать ×%d",
            step.from, step.to, step.crafts))
        row.sub:SetTextColor(unpack(col))

        local costText = PR.FormatMoney(step.cost)
        if step.unknown then costText = costText .. " |cffff8040*|r" end
        row.right:SetText(costText)
        row.right2:SetText(string.format("за шт: %s", PR.FormatMoneyShort(
            PR.Planner.CraftCost(r))))

        if r.item then HookRowTooltip(row, r.item) end
    end
    list.content:SetHeight(#steps * ROW_H)
    list.UpdateScrollRange()

    -- итог
    local total = PR.FormatMoney(plan.totalCost)
    local note = plan.hasUnknown and
        "   |cffff8040* часть цен неизвестна — запустите сканирование|r" or ""
    f.planTotal:SetText("Ожидаемая стоимость: " .. total .. note)
end

-- ---------------------------------------------------------------------------
-- Обновление правой панели: список покупок
-- ---------------------------------------------------------------------------

function UI.RefreshShopping()
    local list = f.shopList
    local plan = PR.state.plan
    local shopping = (plan and plan.shopping) or {}

    for i, row in ipairs(list.rows) do row:Hide() end

    if #shopping == 0 then
        f.shopEmpty:Show()
        f.shopTotal:SetText("")
        return
    end
    f.shopEmpty:Hide()

    for i, it in ipairs(shopping) do
        local row = AcquireRow(list, i)
        row:Show()

        local _, _, _, _, icon = GetItemInfoInstant(it.itemID)
        row.icon:SetTexture(icon or 134400)

        local name = C_Item and C_Item.GetItemNameByID
            and C_Item.GetItemNameByID(it.itemID)
            or ("Предмет #" .. it.itemID)
        row.name:SetText(name)

        if it.buy > 0 then
            row.sub:SetText(string.format("нужно %d · есть %d", it.need, it.have))
            row.sub:SetTextColor(unpack(C.textDim))
            row.right:SetText(string.format("|cffff6a5fкупить ×%d|r", it.buy))
            local sub = PR.FormatMoney(it.subtotal)
            if it.stale then sub = sub .. " |cffff8040(устар.)|r" end
            row.right2:SetText(sub)
        else
            row.sub:SetText(string.format("нужно %d · есть %d", it.need, it.have))
            row.sub:SetTextColor(unpack(C.textDim))
            row.right:SetText("|cff59e673хватает|r")
            row.right2:SetText("")
        end

        HookRowTooltip(row, it.itemID)
    end
    list.content:SetHeight(#shopping * ROW_H)
    list.UpdateScrollRange()

    f.shopTotal:SetText("К закупке: " .. PR.FormatMoney(plan.shoppingTotal))
end

-- ---------------------------------------------------------------------------
-- Статусная строка (источник цен / прогресс сканирования)
-- ---------------------------------------------------------------------------

function UI.RefreshScanStatus()
    if not f or not f:IsShown() then return end
    local S = PR.Scanner
    if S.active then
        f.status:SetText(string.format(
            "|cffffd700Сканирование аукциона: %d/%d...|r", S.done, S.total))
    else
        f.status:SetText("Источник цен: |cffffffff" .. PR.PriceSourceLabel() .. "|r")
    end
end

function UI.RefreshAll()
    if UI.IsShown() then RebuildPlan() end
    UI.RefreshScanStatus()
end

-- ---------------------------------------------------------------------------
-- Выпадающий список профессий (самодельный, без шаблонов Blizzard)
-- ---------------------------------------------------------------------------

local dropdown, dropdownPopup

local function SelectProfession(key)
    PR.state.profession = key
    dropdown.text:SetText(ProfDisplayName(key))

    -- подставляем текущий навык персонажа, если профессия изучена
    local learned = PR.GetPlayerProfessions()
    local cur = 1
    if learned[key] then cur = math.max(1, learned[key].skill) end
    f.skillBox:SetText(tostring(cur))
    PR.state.currentSkill = cur

    if dropdownPopup then dropdownPopup:Hide() end
    RebuildPlan()
end

local function BuildDropdown(parent)
    dropdown = CreateFrame("Button", nil, parent)
    dropdown:SetSize(210, 24)
    SetFlatBackdrop(dropdown, C.bgLight, C.borderDim)
    dropdown.text = MakeText(dropdown)
    dropdown.text:SetPoint("LEFT", 8, 0)
    dropdown.text:SetPoint("RIGHT", -20, 0)
    dropdown.text:SetJustifyH("LEFT")
    dropdown.text:SetText("Выберите профессию")
    dropdown.arrow = MakeText(dropdown)
    dropdown.arrow:SetPoint("RIGHT", -6, 0)
    dropdown.arrow:SetText("▼")
    dropdown.arrow:SetTextColor(unpack(C.textDim))

    dropdownPopup = CreateFrame("Frame", nil, dropdown)
    dropdownPopup:SetFrameStrata("TOOLTIP")
    dropdownPopup:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    dropdownPopup:SetWidth(210)
    SetFlatBackdrop(dropdownPopup, C.bg, C.borderDim)
    dropdownPopup:Hide()

    local learned = PR.GetPlayerProfessions()
    local y = -4
    for _, key in ipairs(PR.ProfessionOrder) do
        local btn = CreateFrame("Button", nil, dropdownPopup)
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT", 4, y)
        btn:SetPoint("TOPRIGHT", -4, y)
        local label = MakeText(btn)
        label:SetPoint("LEFT", 8, 0)
        local name = ProfDisplayName(key)
        if learned[key] then
            label:SetText(string.format("%s  |cff8c96b0(%d/%d)|r",
                name, learned[key].skill, learned[key].maxSkill))
        else
            label:SetText(name)
            label:SetTextColor(unpack(C.textDim))
        end
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.3, 0.55, 0.95, 0.15)
        btn:SetScript("OnClick", function() SelectProfession(key) end)
        y = y - 24
    end
    dropdownPopup:SetHeight(-y + 8)

    dropdown:SetScript("OnClick", function()
        dropdownPopup:SetShown(not dropdownPopup:IsShown())
    end)
    return dropdown
end

-- ---------------------------------------------------------------------------
-- Построение главного окна
-- ---------------------------------------------------------------------------

local function CreateMainFrame()
    f = CreateFrame("Frame", "ProfRouteFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        PR.db.framePos = { point = point, x = x, y = y }
    end)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    SetFlatBackdrop(f, C.bg, C.border)
    f:Hide()
    table.insert(UISpecialFrames, "ProfRouteFrame") -- закрытие по Esc

    if PR.db.framePos then
        f:ClearAllPoints()
        f:SetPoint(PR.db.framePos.point, UIParent, PR.db.framePos.point,
            PR.db.framePos.x, PR.db.framePos.y)
    end

    -- заголовок
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(34)
    SetFlatBackdrop(titleBar, { 0.07, 0.10, 0.16, 1 }, C.borderDim)

    local title = MakeText(titleBar, GameFontHighlightLarge)
    title:SetPoint("LEFT", 12, 0)
    title:SetText("|cff4da3ffProfRoute|r  |cff8c96b0— маршрут прокачки профессий|r")

    local close = MakeButton(titleBar, 24, 20, "✕")
    close:SetPoint("RIGHT", -6, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- панель управления
    local ctrl = CreateFrame("Frame", nil, f)
    ctrl:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -6)
    ctrl:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -6)
    ctrl:SetHeight(52)

    local ddLabel = MakeText(ctrl, GameFontDisableSmall)
    ddLabel:SetPoint("TOPLEFT", 12, 0)
    ddLabel:SetText("Профессия")
    ddLabel:SetTextColor(unpack(C.textDim))

    local dd = BuildDropdown(ctrl)
    dd:SetPoint("TOPLEFT", 12, -14)

    local skillWrap, skillBox = MakeEditBox(ctrl, 60, "Текущий навык")
    skillWrap:SetPoint("LEFT", dd, "RIGHT", 18, 0)
    f.skillBox = skillBox

    local tgtWrap, tgtBox = MakeEditBox(ctrl, 60, "Цель")
    tgtWrap:SetPoint("LEFT", skillWrap, "RIGHT", 18, 0)
    f.targetBox = tgtBox
    tgtBox:SetText(tostring(PR.db.targetSkill or 300))

    local build = MakeButton(ctrl, 130, 24, "Построить план", true)
    build:SetPoint("LEFT", tgtWrap, "RIGHT", 18, 0)
    build:SetScript("OnClick", RebuildPlan)

    local scan = MakeButton(ctrl, 150, 24, "Сканировать цены")
    scan:SetPoint("LEFT", build, "RIGHT", 12, 0)
    scan:SetScript("OnClick", function() PR.Scanner.StartForPlan() end)
    f.scanButton = scan

    -- левая панель: маршрут
    local leftHeader = MakeText(f, GameFontHighlight)
    leftHeader:SetPoint("TOPLEFT", ctrl, "BOTTOMLEFT", 12, -10)
    leftHeader:SetText("МАРШРУТ")
    leftHeader:SetTextColor(unpack(C.accent))

    f.planList = MakeScrollList(f)
    f.planList.holder:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -4)
    f.planList.holder:SetSize(FRAME_W / 2 - 20, FRAME_H - 170)

    f.planEmpty = MakeText(f.planList.holder)
    f.planEmpty:SetPoint("CENTER")
    f.planEmpty:SetWidth(FRAME_W / 2 - 60)
    f.planEmpty:SetTextColor(unpack(C.textDim))

    f.planTotal = MakeText(f, GameFontHighlight)
    f.planTotal:SetPoint("TOPLEFT", f.planList.holder, "BOTTOMLEFT", 4, -6)

    -- правая панель: список покупок
    local rightHeader = MakeText(f, GameFontHighlight)
    rightHeader:SetPoint("TOPLEFT", f, "TOPLEFT", FRAME_W / 2 + 8, 0)
    rightHeader:SetPoint("TOP", leftHeader, "TOP", 0, 0)
    rightHeader:SetText("ЧТО ДОКУПИТЬ")
    rightHeader:SetTextColor(unpack(C.accent))

    f.shopList = MakeScrollList(f)
    f.shopList.holder:SetPoint("TOPLEFT", rightHeader, "BOTTOMLEFT", 0, -4)
    f.shopList.holder:SetSize(FRAME_W / 2 - 20, FRAME_H - 170)

    f.shopEmpty = MakeText(f.shopList.holder)
    f.shopEmpty:SetPoint("CENTER")
    f.shopEmpty:SetWidth(FRAME_W / 2 - 60)
    f.shopEmpty:SetText("Список появится после построения плана.")
    f.shopEmpty:SetTextColor(unpack(C.textDim))

    f.shopTotal = MakeText(f, GameFontHighlight)
    f.shopTotal:SetPoint("TOPLEFT", f.shopList.holder, "BOTTOMLEFT", 4, -6)
    f.shopTotal:SetTextColor(unpack(C.gold))

    -- статусная строка
    local statusBar = CreateFrame("Frame", nil, f)
    statusBar:SetPoint("BOTTOMLEFT", 1, 1)
    statusBar:SetPoint("BOTTOMRIGHT", -1, 1)
    statusBar:SetHeight(24)
    SetFlatBackdrop(statusBar, { 0.07, 0.10, 0.16, 1 }, C.borderDim)

    f.status = MakeText(statusBar, GameFontDisableSmall)
    f.status:SetPoint("LEFT", 10, 0)

    local hint = MakeText(statusBar, GameFontDisableSmall)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetText("/proute — открыть · сканер работает при открытом аукционе")
    hint:SetTextColor(unpack(C.textDim))

    -- отслеживаем изменения в сумках: обновляем "есть/купить"
    PR.Bags.Watch(function()
        if PR.state.plan and PR.state.plan.possible then
            PR.state.plan.shopping, PR.state.plan.shoppingTotal =
                PR.Planner.BuildShoppingList(PR.state.plan)
            UI.RefreshShopping()
        end
    end)

    f:SetScript("OnShow", function()
        UI.RefreshScanStatus()
        if PR.db.lastProfession and not PR.state.profession then
            SelectProfession(PR.db.lastProfession)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Открыть/закрыть
-- ---------------------------------------------------------------------------

function UI.Toggle()
    if not f then CreateMainFrame() end
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end
