-- ============================================================================
-- ProfRoute — UI.lua
-- Главное окно: выбор профессии, маршрут прокачки, список покупок,
-- детали рецепта по клику.
-- Открытие: /proute
-- ============================================================================

local PR = ProfRoute

PR.UI = {}
local UI = PR.UI

local C = PR.COLORS

-- Локализация: функция-обёртка, чтобы смена языка подхватывалась в рантайме
local function L(key) return PR.L[key] end

local FRAME_W, FRAME_H = 860, 660
local ROW_H = 36
local HEADER_H = 38
local CTRL_H = 58
local SECT_H = 20
local DETAIL_H = 150
local TOTALS_H = 32

-- ---------------------------------------------------------------------------
-- Базовые хелперы отрисовки
-- ---------------------------------------------------------------------------

-- обычные Frame в современном клиенте не имеют SetBackdrop — подмешиваем
local function EnsureBackdrop(fr)
    if not fr.SetBackdrop and Mixin and BackdropTemplateMixin then
        Mixin(fr, BackdropTemplateMixin)
    end
end

-- Плоский бэкдроп для мелких виджетов (кнопки, поля, рамки иконок)
local function SetFlatBackdrop(fr, bg, border)
    EnsureBackdrop(fr)
    fr:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    fr:SetBackdropColor(unpack(bg))
    fr:SetBackdropBorderColor(unpack(border))
end

-- Вертикальный градиент поверх существующего фрейма (светлее сверху)
local function AddGradient(fr, topColor, bottomColor)
    local g = fr:CreateTexture(nil, "BACKGROUND")
    g:SetPoint("TOPLEFT", 1, -1)
    g:SetPoint("BOTTOMRIGHT", -1, 1)
    local ok = false
    if CreateColor then
        ok = pcall(g.SetGradient, g, "VERTICAL",
            CreateColor(bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4]),
            CreateColor(topColor[1], topColor[2], topColor[3], topColor[4]))
    end
    if not ok then
        ok = pcall(function()
            g:SetGradient("VERTICAL",
                bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4],
                topColor[1], topColor[2], topColor[3], topColor[4])
        end)
    end
    if not ok then
        g:SetColorTexture(
            (topColor[1] + bottomColor[1]) / 2,
            (topColor[2] + bottomColor[2]) / 2,
            (topColor[3] + bottomColor[3]) / 2,
            (topColor[4] + bottomColor[4]) / 2)
    end
    return g
end

-- Панель: рамка + тёмный фон + мягкий вертикальный градиент
local function MakePanel(parent, borderColor)
    local fr = CreateFrame("Frame", nil, parent)
    EnsureBackdrop(fr)
    fr:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    fr:SetBackdropColor(0.015, 0.025, 0.045, 0.92)
    fr:SetBackdropBorderColor(unpack(borderColor or C.borderDim))
    AddGradient(fr, { 0.095, 0.125, 0.20, 0.75 }, { 0.045, 0.06, 0.10, 0.85 })
    return fr
end

-- Шапка секции («МАРШРУТ», «ЧТО ДОКУПИТЬ»): полоса с акцентной чертой слева
local function MakeSectionHeader(parent, text)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(SECT_H)
    EnsureBackdrop(h)
    h:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    h:SetBackdropBorderColor(unpack(C.borderDim))
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.11, 0.145, 0.225, 0.55)

    local bar = h:CreateTexture(nil, "OVERLAY")
    bar:SetPoint("TOPLEFT", 1, -4)
    bar:SetPoint("BOTTOMLEFT", 1, 4)
    bar:SetWidth(3)
    bar:SetColorTexture(unpack(C.accent))

    local fs = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 10, 0)
    fs:SetText(text)
    fs:SetTextColor(0.75, 0.85, 1.0)
    h.text = fs
    return h
end

local function MakeText(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(template or GameFontHighlight)
    fs:SetTextColor(unpack(C.text))
    return fs
end

local function MakeButton(parent, w, h, label, accent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local bgColor = accent and { 0.14, 0.30, 0.60, 1 } or C.bgLight
    local brColor = accent and C.accent or C.borderDim
    SetFlatBackdrop(b, bgColor, brColor)
    b.bgColor, b.brColor = bgColor, brColor
    b.text = MakeText(b)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    if accent then b.text:SetTextColor(1, 1, 1) end
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.84, 0.1)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(self.brColor))
    end)
    return b
end

local function MakeEditBox(parent, w, label)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(w, 24)
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
        wrap.label:SetPoint("BOTTOMLEFT", wrap, "TOPLEFT", 0, 3)
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
    local holder = MakePanel(parent, C.borderDim)

    local scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", -14, 2)

    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)

    -- полоса прокрутки
    local bar = CreateFrame("Slider", nil, holder)
    bar:SetWidth(10)
    bar:SetPoint("TOPRIGHT", -2, -14)
    bar:SetPoint("BOTTOMRIGHT", -2, 14)
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

local function AcquireRow(list, i)
    local row = list.rows[i]
    if not row then
        row = CreateFrame("Button", nil, list.content)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)

        -- зебра
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(unpack(i % 2 == 0 and C.bgRowAlt or C.bgRow))

        -- подсветка выбранного шага
        row.sel = row:CreateTexture(nil, "BORDER")
        row.sel:SetAllPoints()
        row.sel:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.16)
        row.sel:Hide()

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(26, 26)
        row.icon:SetPoint("LEFT", 8, 0)

        row.iconBorder = CreateFrame("Frame", nil, row)
        row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
        row.iconBorder:SetSize(28, 28)
        SetFlatBackdrop(row.iconBorder, { 0, 0, 0, 0 }, C.borderDim)
        row.iconBorder:SetFrameLevel(row:GetFrameLevel() + 1)

        row.name = MakeText(row, GameFontHighlight)
        row.name:SetPoint("TOPLEFT", 46, -5)
        row.name:SetPoint("RIGHT", -90, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.sub = MakeText(row, GameFontDisableSmall)
        row.sub:SetPoint("BOTTOMLEFT", 46, 5)
        row.sub:SetPoint("RIGHT", -90, 0)
        row.sub:SetJustifyH("LEFT")
        row.sub:SetWordWrap(false)
        row.sub:SetTextColor(unpack(C.textDim))

        row.right = MakeText(row, GameFontHighlight)
        row.right:SetPoint("RIGHT", -10, 6)
        row.right:SetJustifyH("RIGHT")

        row.right2 = MakeText(row, GameFontDisableSmall)
        row.right2:SetPoint("RIGHT", -10, -9)
        row.right2:SetJustifyH("RIGHT")
        row.right2:SetTextColor(unpack(C.textDim))

        row.hl = row:CreateTexture(nil, "HIGHLIGHT")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.07)

        -- клик: выбор шага / Shift+клик: поиск предмета на аукционе
        row:SetScript("OnClick", function(self)
            if IsShiftKeyDown() and self.itemID
                and PR.Scanner and PR.Scanner.SearchItemOnAH
                and PR.Scanner.SearchItemOnAH(self.itemID) then
                return
            end
            if self.step and UI.SelectStep then UI.SelectStep(self.step) end
        end)

        list.rows[i] = row
    end
    return row
end

-- тултип предмета при наведении на строку/иконку
local function HookItemTooltip(fr, itemID)
    fr:SetScript("OnEnter", function(self)
        if itemID and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(itemID)
            GameTooltip:Show()
        end
    end)
    fr:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

-- ---------------------------------------------------------------------------
-- Главное окно
-- ---------------------------------------------------------------------------
local f -- главный фрейм

UI.selectedStep = nil -- шаг маршрута, выбранный кликом

function UI.IsShown()
    return f and f:IsShown()
end

local function ProfDisplayName(key)
    local p = PR.Professions[key]
    if PR.CurrentLocale() == "ruRU" then return p.names.ru end
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

    -- выбранный шаг мог исчезнуть из нового плана
    if UI.selectedStep then
        local still = false
        for _, s in ipairs(plan.steps) do
            if s == UI.selectedStep then still = true break end
        end
        if not still then UI.SelectStep(plan.steps[1]) end
    elseif plan.possible and plan.steps[1] then
        UI.SelectStep(plan.steps[1])
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
            f.planEmpty:SetText(L("UI_PLAN_IMPOSSIBLE"))
        else
            f.planEmpty:SetText(L("UI_PLAN_EMPTY"))
        end
        f.totalsCost:SetText("")
        return
    end
    f.planEmpty:Hide()

    for i, step in ipairs(steps) do
        local r = step.recipe
        local row = AcquireRow(list, i)
        row:Show()
        row.step = step
        row.itemID = r.item -- Shift+клик: искать результат рецепта на аукционе
        row.icon:SetTexture(PR.RecipeIcon(r))
        row.name:SetText(PR.RecipeName(r))

        local col = PR.Planner.DifficultyColor(r, step.from)
        row.sub:SetText(string.format(L("UI_STEP_FMT"), step.from, step.to, step.crafts))
        row.sub:SetTextColor(unpack(col))

        local costText = PR.FormatMoney(step.cost)
        if step.unknown then costText = costText .. " |cffff8040*|r" end
        row.right:SetText(costText)
        row.right2:SetText(string.format(L("UI_PER_ITEM"), PR.FormatMoneyShort(
            PR.Planner.CraftCost(r))))

        row.sel:SetShown(UI.selectedStep == step)
        if r.item then HookItemTooltip(row, r.item) end
    end
    list.content:SetHeight(#steps * ROW_H)
    list.UpdateScrollRange()

    -- итоговая стоимость маршрута
    local total = PR.FormatMoney(plan.totalCost)
    local note = plan.hasUnknown and L("UI_UNKNOWN_NOTE") or ""
    f.totalsCost:SetText(L("UI_TOTAL_COST") .. total .. note)
end

-- ---------------------------------------------------------------------------
-- Детали рецепта (нижняя панель под маршрутом)
-- ---------------------------------------------------------------------------

function UI.SelectStep(step)
    UI.selectedStep = step
    if not f then return end
    for _, row in ipairs(f.planList.rows) do
        row.sel:SetShown(step ~= nil and row.step == step)
    end
    UI.RefreshDetail()
end

function UI.RefreshDetail()
    if not f then return end
    local p = f.detail
    local step = UI.selectedStep

    if not step then
        p.empty:Show()
        p.head:Hide()
        p.info:Hide()
        p.reagLabel:Hide()
        for _, chip in ipairs(p.chips) do chip:Hide() end
        return
    end

    local r = step.recipe
    p.empty:Hide()
    p.head:Show()
    p.info:Show()

    p.icon:SetTexture(PR.RecipeIcon(r))
    p.head:SetText(PR.RecipeName(r))

    local col = PR.Planner.DifficultyColor(r, step.from)
    local costText = PR.FormatMoney(step.cost)
    if step.unknown then costText = costText .. " |cffff8040*|r" end
    p.info:SetText(string.format(
        "|cff%s%d → %d|r  ·  %s  ·  %s",
        string.format("%02x%02x%02x", col[1] * 255, col[2] * 255, col[3] * 255),
        step.from, step.to,
        string.format(L("UI_CRAFTS_FMT"), step.crafts),
        costText))
    p.info:SetTextColor(unpack(C.text))

    -- реагенты
    local reagents = r.reagents or {}
    p.reagLabel:SetShown(#reagents > 0)
    for i, chip in ipairs(p.chips) do
        local rg = reagents[i]
        if rg then
            local id, perCraft = rg[1], rg[2]
            local need = perCraft * step.crafts
            local have = PR.Bags.Count(id)
            chip:Show()
            chip.icon:SetTexture(PR.ItemIcon(id) or 134400)
            local nm = (C_Item and C_Item.GetItemNameByID)
                and C_Item.GetItemNameByID(id)
                or ("#" .. id)
            chip.name:SetText(nm)

            local unit, src = PR.GetPrice(id)
            local unitText
            if src == "vendor" then
                unitText = "|cff8c96b0" .. L("UI_VENDOR_ITEM") .. "|r"
            else
                unitText = PR.FormatMoneyShort(unit)
            end

            local haveCol = have >= need and "|cff59e673" or "|cffff6a5f"
            chip.counts:SetText(string.format("×%d  %s%d/%d|r",
                need, haveCol, have, need) .. "  " .. unitText)

            if chip.itemID ~= id then
                chip.itemID = id
                HookItemTooltip(chip, id)
            end
        else
            chip:Hide()
        end
    end
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
        f.totalsBuy:SetText("")
        return
    end
    f.shopEmpty:Hide()

    for i, it in ipairs(shopping) do
        local row = AcquireRow(list, i)
        row:Show()
        row.step = nil
        row.itemID = it.itemID -- Shift+клик: искать на аукционе
        row.sel:Hide()

        row.icon:SetTexture(PR.ItemIcon(it.itemID) or 134400)

        local name = C_Item and C_Item.GetItemNameByID
            and C_Item.GetItemNameByID(it.itemID)
            or ("Item #" .. it.itemID)
        row.name:SetText(name)

        row.sub:SetText(string.format(L("UI_NEED_FMT"), it.need, it.have))
        if it.have >= it.need then
            row.sub:SetTextColor(unpack(C.green))
        else
            row.sub:SetTextColor(unpack(C.textDim))
        end

        if it.buy > 0 then
            row.right:SetText(string.format(L("UI_BUY_FMT"), it.buy))
            local sub = PR.FormatMoney(it.subtotal)
            if it.stale then sub = sub .. L("UI_STALE") end
            row.right2:SetText(sub)
        else
            row.right:SetText(L("UI_HAVE_ENOUGH"))
            row.right2:SetText("")
        end

        HookItemTooltip(row, it.itemID)
    end
    list.content:SetHeight(#shopping * ROW_H)
    list.UpdateScrollRange()

    f.totalsBuy:SetText(L("UI_TOTAL_BUY") .. PR.FormatMoney(plan.shoppingTotal))
end

-- ---------------------------------------------------------------------------
-- Статусная строка (источник цен / прогресс сканирования)
-- ---------------------------------------------------------------------------

function UI.RefreshScanStatus()
    if not f or not f:IsShown() then return end
    local S = PR.Scanner
    if S.searchActive and S.searchQueue then
        local cur = S.searchQueue[S.searchIdx]
        if cur then
            f.status:SetText(string.format(L("UI_SEARCHING_FMT"),
                cur.name, S.searchIdx, #S.searchQueue))
        else
            f.status:SetText("")
        end
    elseif S.active then
        f.status:SetText(string.format(L("UI_STATUS_SCANNING"), S.done, S.total))
    else
        f.status:SetText(string.format(L("UI_STATUS_SOURCE"), PR.PriceSourceLabel()))
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
    dropdown:SetSize(230, 26)
    SetFlatBackdrop(dropdown, C.bgLight, C.borderDim)
    dropdown.text = MakeText(dropdown)
    dropdown.text:SetPoint("LEFT", 10, 0)
    dropdown.text:SetPoint("RIGHT", -24, 0)
    dropdown.text:SetJustifyH("LEFT")
    dropdown.text:SetText(L("UI_SELECT_PROF"))
    dropdown.arrow = MakeText(dropdown, GameFontDisableSmall)
    dropdown.arrow:SetPoint("RIGHT", -8, 0)
    dropdown.arrow:SetText("▼")
    dropdown.arrow:SetTextColor(unpack(C.textDim))

    dropdown:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    dropdown:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.borderDim)) end)

    dropdownPopup = CreateFrame("Frame", nil, dropdown)
    dropdownPopup:SetFrameStrata("TOOLTIP")
    dropdownPopup:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    dropdownPopup:SetWidth(230)
    SetFlatBackdrop(dropdownPopup, { 0.03, 0.045, 0.08, 0.97 }, C.border)
    dropdownPopup:Hide()

    local learned = PR.GetPlayerProfessions()
    local y = -4
    for _, key in ipairs(PR.ProfessionOrder) do
        local btn = CreateFrame("Button", nil, dropdownPopup)
        btn:SetHeight(26)
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
        hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.15)
        btn:SetScript("OnClick", function() SelectProfession(key) end)
        y = y - 26
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

local LEFT_X = 12
local COL_W = FRAME_W / 2 - 26   -- ширина одной колонки
local RIGHT_X = FRAME_W / 2 + 6

local function BuildDetailPanel(parent)
    local p = MakePanel(parent, C.borderDim)

    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetSize(40, 40)
    p.icon:SetPoint("TOPLEFT", 12, -14)

    p.iconBorder = CreateFrame("Frame", nil, p)
    p.iconBorder:SetPoint("CENTER", p.icon, "CENTER")
    p.iconBorder:SetSize(42, 42)
    SetFlatBackdrop(p.iconBorder, { 0, 0, 0, 0 }, C.borderDim)

    p.head = MakeText(p, GameFontHighlight)
    p.head:SetPoint("TOPLEFT", 64, -12)
    p.head:SetPoint("RIGHT", -12, 0)
    p.head:SetJustifyH("LEFT")
    p.head:SetWordWrap(false)

    p.info = MakeText(p, GameFontDisableSmall)
    p.info:SetPoint("TOPLEFT", 64, -32)
    p.info:SetPoint("RIGHT", -12, 0)
    p.info:SetJustifyH("LEFT")
    p.info:SetWordWrap(false)
    p.info:SetTextColor(unpack(C.textDim))

    p.empty = MakeText(p, GameFontDisableSmall)
    p.empty:SetPoint("CENTER")
    p.empty:SetWidth(COL_W - 40)
    p.empty:SetText(L("UI_DETAIL_EMPTY"))
    p.empty:SetTextColor(unpack(C.textDim))

    p.reagLabel = MakeText(p, GameFontDisableSmall)
    p.reagLabel:SetPoint("BOTTOMLEFT", 12, 8)
    p.reagLabel:SetText(L("UI_REAGENTS"))
    p.reagLabel:SetTextColor(0.75, 0.85, 1.0)

    -- до 4 реагентов: сетка 2×2 (в базе максимум 3 на рецепт)
    p.chips = {}
    for i = 1, 4 do
        local chip = CreateFrame("Button", nil, p)
        chip:SetSize(152, 24)
        local col = (i - 1) % 2
        local rowN = math.floor((i - 1) / 2)
        chip:SetPoint("BOTTOMLEFT", 84 + col * 156, 40 - rowN * 24)
        chip.itemID = nil

        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetSize(18, 18)
        chip.icon:SetPoint("LEFT", 0, 0)

        chip.name = MakeText(chip, GameFontDisableSmall)
        chip.name:SetPoint("TOPLEFT", 24, 0)
        chip.name:SetPoint("RIGHT", 0, 0)
        chip.name:SetJustifyH("LEFT")
        chip.name:SetWordWrap(false)
        chip.name:SetTextColor(unpack(C.text))

        chip.counts = MakeText(chip, GameFontDisableSmall)
        chip.counts:SetPoint("TOPLEFT", 24, -11)
        chip.counts:SetPoint("RIGHT", 0, -11)
        chip.counts:SetJustifyH("LEFT")
        chip.counts:SetWordWrap(false)
        chip.counts:SetTextColor(unpack(C.textDim))

        table.insert(p.chips, chip)
    end

    return p
end

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

    -- фон: стандартная «каменная» текстура Blizzard (как у окон игры).
    -- Под ней — тёмная заливка: если текстуры нет в клиенте, фон всё равно
    -- останется спокойным и тёмным.
    local solidBg = f:CreateTexture(nil, "BACKGROUND")
    solidBg:SetAllPoints()
    solidBg:SetColorTexture(0.05, 0.055, 0.07, 0.95)
    EnsureBackdrop(f)
    f:SetBackdrop({
        bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        tile = true,
        tileSize = 256,
    })
    f:SetBackdropColor(0.62, 0.65, 0.75, 0.92) -- холодная тонировка, без «грязи»
    f:SetBackdropBorderColor(0.28, 0.30, 0.38, 1)
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
    titleBar:SetHeight(HEADER_H)
    EnsureBackdrop(titleBar)
    titleBar:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    titleBar:SetBackdropBorderColor(unpack(C.borderDim))
    AddGradient(titleBar, { 0.10, 0.115, 0.15, 0.85 }, { 0.05, 0.06, 0.085, 0.9 })

    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(22, 22)
    titleIcon:SetPoint("LEFT", 12, 0)
    titleIcon:SetTexture(136241) -- Trade_BlackSmithing (наковальня)

    local title = MakeText(titleBar, GameFontHighlightLarge)
    title:SetPoint("CENTER", 0, 0)
    title:SetText(L("UI_TITLE"))

    local version = MakeText(titleBar, GameFontDisableSmall)
    version:SetPoint("RIGHT", -72, 0)
    version:SetText("|cff8c96b0v" .. PR.VERSION .. "|r")

    -- закрытие: стандартная кнопка X из FrameXML Blizzard
    local close = CreateFrame("Button", nil, titleBar)
    close:SetSize(26, 26)
    close:SetPoint("RIGHT", -4, 0)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    close:SetDisabledTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
    close:SetScript("OnClick", function() f:Hide() end)

    -- настройки: стандартная иконка-гаечный ключ (Trade_Engineering)
    local gear = CreateFrame("Button", nil, titleBar)
    gear:SetSize(22, 22)
    gear:SetPoint("RIGHT", close, "LEFT", -6, 0)
    local gearIcon = gear:CreateTexture(nil, "ARTWORK")
    gearIcon:SetAllPoints()
    gearIcon:SetTexture(136243)
    gear:SetHighlightTexture("Interface\\Icons\\Trade_Engineering", "ADD")
    gear:SetScript("OnClick", function(self) UI.ToggleSettings(self) end)

    -- панель управления
    local ctrl = CreateFrame("Frame", nil, f)
    ctrl:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -6)
    ctrl:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -6)
    ctrl:SetHeight(CTRL_H)

    local ddLabel = MakeText(ctrl, GameFontDisableSmall)
    ddLabel:SetPoint("TOPLEFT", LEFT_X, -2)
    ddLabel:SetText(L("UI_PROFESSION"))
    ddLabel:SetTextColor(unpack(C.textDim))

    local dd = BuildDropdown(ctrl)
    dd:SetPoint("TOPLEFT", LEFT_X, -18)

    local skillWrap, skillBox = MakeEditBox(ctrl, 64, L("UI_CURRENT_SKILL"))
    skillWrap:SetPoint("LEFT", dd, "RIGHT", 20, 0)
    f.skillBox = skillBox

    local tgtWrap, tgtBox = MakeEditBox(ctrl, 64, L("UI_TARGET"))
    tgtWrap:SetPoint("LEFT", skillWrap, "RIGHT", 20, 0)
    f.targetBox = tgtBox
    tgtBox:SetText(tostring(PR.db.targetSkill or 300))

    local build = MakeButton(ctrl, 140, 26, L("UI_BUILD"), true)
    build:SetPoint("LEFT", tgtWrap, "RIGHT", 20, 0)
    build:SetScript("OnClick", RebuildPlan)

    local scan = MakeButton(ctrl, 160, 26, L("UI_SCAN"))
    scan:SetPoint("LEFT", build, "RIGHT", 12, 0)
    scan:SetScript("OnClick", function() PR.Scanner.StartForPlan() end)
    f.scanButton = scan

    -- левая колонка: маршрут
    local leftHeader = MakeSectionHeader(f, L("UI_ROUTE"))
    leftHeader:SetPoint("TOPLEFT", LEFT_X, -(HEADER_H + 6 + CTRL_H + 8))
    leftHeader:SetWidth(COL_W)

    f.detail = BuildDetailPanel(f)
    f.detail:SetPoint("BOTTOMLEFT", LEFT_X, TOTALS_H + 30)
    f.detail:SetSize(COL_W, DETAIL_H)

    f.planList = MakeScrollList(f)
    f.planList.holder:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -4)
    f.planList.holder:SetPoint("BOTTOMRIGHT", f.detail, "TOPRIGHT", 0, -6)

    f.planEmpty = MakeText(f.planList.holder)
    f.planEmpty:SetPoint("CENTER")
    f.planEmpty:SetWidth(COL_W - 60)
    f.planEmpty:SetTextColor(unpack(C.textDim))

    -- правая колонка: список покупок
    local rightHeader = MakeSectionHeader(f, L("UI_SHOPPING"))
    rightHeader:SetPoint("TOPLEFT", RIGHT_X, -(HEADER_H + 6 + CTRL_H + 8))
    rightHeader:SetWidth(COL_W)

    -- кнопка «Найти на аукционе»: по очереди ищет все позиции списка покупок
    local findBtn = MakeButton(rightHeader, 158, SECT_H + 2, L("UI_FIND_BUYS"))
    findBtn:SetPoint("RIGHT", rightHeader, "RIGHT", -4, 0)
    findBtn:SetScript("OnClick", function() PR.Scanner.SearchShoppingOnAH() end)

    f.shopList = MakeScrollList(f)
    f.shopList.holder:SetPoint("TOPLEFT", rightHeader, "BOTTOMLEFT", 0, -4)
    f.shopList.holder:SetPoint("TOPRIGHT", rightHeader, "BOTTOMRIGHT", 0, -4)
    f.shopList.holder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -LEFT_X, TOTALS_H + 30)

    f.shopEmpty = MakeText(f.shopList.holder)
    f.shopEmpty:SetPoint("CENTER")
    f.shopEmpty:SetWidth(COL_W - 60)
    f.shopEmpty:SetText(L("UI_SHOP_EMPTY"))
    f.shopEmpty:SetTextColor(unpack(C.textDim))

    -- панель итогов над статусной строкой
    local totalsBar = MakePanel(f, C.borderDim)
    totalsBar:SetPoint("BOTTOMLEFT", 10, 26)
    totalsBar:SetPoint("BOTTOMRIGHT", -10, 26)
    totalsBar:SetHeight(TOTALS_H)

    local totalsIcon = totalsBar:CreateTexture(nil, "ARTWORK")
    totalsIcon:SetSize(16, 16)
    totalsIcon:SetPoint("LEFT", 10, 0)
    totalsIcon:SetTexture(133784) -- inv_misc_coin_01

    f.totalsCost = MakeText(totalsBar, GameFontHighlight)
    f.totalsCost:SetPoint("LEFT", 32, 0)
    f.totalsCost:SetPoint("RIGHT", totalsBar, "CENTER", -10, 0)
    f.totalsCost:SetJustifyH("LEFT")

    f.totalsBuy = MakeText(totalsBar, GameFontHighlightLarge)
    f.totalsBuy:SetPoint("RIGHT", -12, 0)
    f.totalsBuy:SetJustifyH("RIGHT")
    f.totalsBuy:SetTextColor(unpack(C.gold))

    -- статусная строка
    local statusBar = CreateFrame("Frame", nil, f)
    statusBar:SetPoint("BOTTOMLEFT", 1, 1)
    statusBar:SetPoint("BOTTOMRIGHT", -1, 1)
    statusBar:SetHeight(22)
    EnsureBackdrop(statusBar)
    statusBar:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    statusBar:SetBackdropBorderColor(unpack(C.borderDim))
    local statusBg = statusBar:CreateTexture(nil, "BACKGROUND")
    statusBg:SetPoint("TOPLEFT", 1, -1)
    statusBg:SetPoint("BOTTOMRIGHT", -1, 1)
    statusBg:SetColorTexture(0.05, 0.07, 0.11, 0.9)

    f.status = MakeText(statusBar, GameFontDisableSmall)
    f.status:SetPoint("LEFT", 10, 0)

    local hint = MakeText(statusBar, GameFontDisableSmall)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetText(L("UI_HINT"))
    hint:SetTextColor(unpack(C.textDim))

    -- отслеживаем изменения в сумках: обновляем «есть/купить» и детали
    PR.Bags.Watch(function()
        if PR.state.plan and PR.state.plan.possible then
            PR.state.plan.shopping, PR.state.plan.shoppingTotal =
                PR.Planner.BuildShoppingList(PR.state.plan)
            UI.RefreshShopping()
            UI.RefreshDetail()
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
-- Окно настроек (шестерёнка в заголовке)
-- ---------------------------------------------------------------------------

local settingsPopup

local function ApplyLocale(value)
    if PR.db.locale == value then return end
    PR.db.locale = value
    PR.Print(PR.L("MSG_LOCALE_RELOAD"))
    -- статичные надписи создаются при построении окна — проще перезагрузить UI
    C_Timer.After(0.5, function()
        if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
    end)
end

local function BuildSettingsPopup()
    local p = CreateFrame("Frame", nil, f)
    p:SetSize(290, 175)
    p:SetFrameStrata("TOOLTIP")
    SetFlatBackdrop(p, { 0.03, 0.045, 0.08, 0.97 }, C.border)

    local title = MakeText(p, GameFontHighlight)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(L("UI_SETTINGS"))
    title:SetTextColor(0.75, 0.85, 1.0)

    local langLabel = MakeText(p, GameFontDisableSmall)
    langLabel:SetPoint("TOPLEFT", 12, -34)
    langLabel:SetText(L("UI_LANGUAGE"))
    langLabel:SetTextColor(unpack(C.textDim))

    -- кнопки выбора языка
    p.langButtons = {}
    local langs = {
        { value = "auto", label = L("UI_LANG_AUTO") },
        { value = "ruRU", label = "Русский" },
        { value = "enUS", label = "English" },
    }
    local x = 12
    for _, entry in ipairs(langs) do
        local b = MakeButton(p, 86, 22, entry.label)
        b:SetPoint("TOPLEFT", x, -52)
        b:SetScript("OnClick", function() ApplyLocale(entry.value) end)
        b.langValue = entry.value
        b.langLabel = entry.label
        table.insert(p.langButtons, b)
        x = x + 90
    end

    -- чекбокс «учитывать банк»
    local cb = CreateFrame("Button", nil, p)
    cb:SetSize(18, 18)
    cb:SetPoint("TOPLEFT", 12, -94)
    SetFlatBackdrop(cb, C.bgLight, C.borderDim)
    cb.mark = MakeText(cb)
    cb.mark:SetPoint("CENTER")
    cb.mark:SetText("✓")
    cb.mark:SetTextColor(unpack(C.green))
    cb:SetScript("OnClick", function()
        PR.db.useBank = not PR.db.useBank
        UI.RefreshSettings()
        if PR.state.plan then RebuildPlan() end
    end)
    p.bankCheckbox = cb

    local cbLabel = MakeText(p, GameFontHighlightSmall)
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    cbLabel:SetText(L("UI_USE_BANK"))
    p.bankLabel = cbLabel

    return p
end

function UI.RefreshSettings()
    if not settingsPopup then return end
    for _, b in ipairs(settingsPopup.langButtons) do
        local active = (PR.db.locale or "auto") == b.langValue
        b.text:SetText((active and "|cff59e673" or "|cffffffff") .. b.langLabel .. "|r")
    end
    settingsPopup.bankCheckbox.mark:SetShown(PR.db.useBank ~= false)
end

function UI.ToggleSettings(anchor)
    if settingsPopup and settingsPopup:IsShown() then
        settingsPopup:Hide()
        return
    end
    if not settingsPopup then
        settingsPopup = BuildSettingsPopup()
        settingsPopup:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    end
    UI.RefreshSettings()
    settingsPopup:Show()
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
