-- ============================================================================
-- ProfRoute — Planner.lua
-- Динамическое построение самого дешёвого маршрута прокачки.
--
-- Алгоритм: динамическое программирование от целевого навыка к текущему.
-- Для каждого уровня навыка s выбирается рецепт, минимизирующий
-- ожидаемую стоимость одного повышения навыка:
--     cost(s) = min_рецепт [ цена_крафта / шанс_скиллапа(s) + cost(s+1) ]
--
-- Модель шанса повышения (классическая):
--   до жёлтого порога        — 100%
--   от жёлтого до серого     — линейно убывает: (gray - s) / (gray - yellow)
--   серый                    — 0 (рецепт не используется)
--
-- После расчёта соседние уровни с одинаковым рецептом объединяются в шаги.
-- ============================================================================

local PR = ProfRoute

PR.Planner = {}
local P = PR.Planner

-- Шанс повышения навыка при создании рецепта r на уровне навыка s
local function SkillUpChance(r, s)
    if s < r.min or s >= r.gry then return 0 end
    if s < r.yel then return 1 end
    local span = r.gry - r.yel
    if span <= 0 then return 0 end
    return math.max(0, math.min(1, (r.gry - s) / span))
end

-- Цвет сложности рецепта на уровне s (для подсветки в UI)
function P.DifficultyColor(r, s)
    if s >= r.gry then return PR.COLORS.grayDiff
    elseif s >= r.grn then return PR.COLORS.greenDiff
    elseif s >= r.yel then return PR.COLORS.yellow
    end
    return PR.COLORS.orange
end

-- Стоимость одного крафта. Возвращает cost, hasUnknownPrices
local function CraftCost(r)
    local total, unknown = 0, false
    for _, rg in ipairs(r.reagents) do
        local price = PR.GetPrice(rg[1])
        if price then
            total = total + price * rg[2]
        else
            unknown = true
        end
    end
    return total, unknown
end
P.CraftCost = CraftCost

-- ---------------------------------------------------------------------------
-- Построение маршрута
-- Возвращает plan = {
--   steps = { {recipe, from, to, crafts, cost, unknown}, ... },
--   totalCost, hasUnknown, possible (bool), gapFrom, gapTo
-- }
-- ---------------------------------------------------------------------------
function P.BuildPlan(profKey, fromSkill, toSkill)
    local prof = PR.Professions[profKey]
    if not prof then return nil end

    fromSkill = math.max(1, math.floor(fromSkill or 1))
    toSkill = math.min(300, math.floor(toSkill or 300))

    local plan = { steps = {}, totalCost = 0, hasUnknown = false, possible = true }
    if fromSkill >= toSkill then
        plan.possible = false
        return plan
    end

    -- DP: cost[s] — минимальная ожидаемая стоимость пути s -> toSkill
    local INF = math.huge
    local cost, choice, unknownAt = {}, {}, {}
    cost[toSkill] = 0

    for s = toSkill - 1, fromSkill, -1 do
        local best, bestR, bestUnk = INF, nil, false
        for _, r in ipairs(prof.recipes) do
            local ch = SkillUpChance(r, s)
            if ch > 0 then
                local cc, unk = CraftCost(r)
                local c = cc / ch + (cost[s + 1] or INF)
                -- при равной цене предпочитаем полностью оценённый рецепт
                local better = (c < best) or (c == best and bestUnk and not unk)
                if better then
                    best, bestR, bestUnk = c, r, unk
                end
            end
        end
        cost[s], choice[s], unknownAt[s] = best, bestR, bestUnk
    end

    if not choice[fromSkill] or cost[fromSkill] == INF then
        plan.possible = false
        return plan
    end

    -- Сшиваем уровни в шаги
    local s = fromSkill
    while s < toSkill do
        local r = choice[s]
        local e = s
        while e + 1 < toSkill and choice[e + 1] == r do e = e + 1 end

        -- ожидаемое число крафтов на этом участке
        local expectedCrafts, stepCost, stepUnknown = 0, 0, false
        for lvl = s, e do
            local ch = SkillUpChance(r, lvl)
            local cc, unk = CraftCost(r)
            if unk then stepUnknown = true end
            local perLevel = 1 / ch
            expectedCrafts = expectedCrafts + perLevel
            stepCost = stepCost + cc * perLevel
        end

        table.insert(plan.steps, {
            recipe = r,
            from = s,
            to = e + 1,          -- навык, до которого крафтим (не включая)
            crafts = math.ceil(expectedCrafts),
            expectedCrafts = expectedCrafts,
            cost = stepCost,
            unknown = stepUnknown,
        })
        if stepUnknown then plan.hasUnknown = true end
        plan.totalCost = plan.totalCost + stepCost
        s = e + 1
    end

    -- Учитываем реагенты, которые уже лежат в сумках/банке:
    -- имеющееся покрывает потребности шагов по порядку, цена покрытой
    -- части считается нулевой. Число крафтов не меняется (оно определяется
    -- математикой скиллапа) — меняется только ожидаемая стоимость.
    local owned = {} -- itemID -> остаток имеющегося, ещё не израсходованный
    plan.totalCost = 0
    plan.hasUnknown = false
    for _, step in ipairs(plan.steps) do
        local r = step.recipe
        local paidCost, stepUnknown = 0, false
        for _, rg in ipairs(r.reagents) do
            local id, perCraft = rg[1], rg[2]
            local needF = perCraft * step.expectedCrafts
            local have = owned[id]
            if have == nil then
                have = PR.Bags.Count(id)
                owned[id] = have
            end
            local paid = needF
            if have >= needF then
                paid = 0
                owned[id] = have - needF
            elseif have > 0 then
                paid = needF - have
                owned[id] = 0
            end
            local price = PR.GetPrice(id)
            if price then
                paidCost = paidCost + price * paid
            elseif paid > 0 then
                stepUnknown = true
            end
        end
        step.cost = paidCost
        step.unknown = stepUnknown
        if stepUnknown then plan.hasUnknown = true end
        plan.totalCost = plan.totalCost + paidCost
    end

    return plan
end

-- ---------------------------------------------------------------------------
-- Сканер выгодных рецептов.
-- Для каждого кандидата (Data/RecipeShop.lua) временно добавляем его рецепт
-- в базу профессии, пересчитываем маршрут и сравниваем итоговую стоимость с
-- базовой. Если экономия больше цены самого рецепта — кандидат предлагается
-- к покупке. Кандидаты, чей создаваемый предмет уже есть в базе, пропускаются.
-- Возвращает { {cand, savings, price, source, newTotal}, ... } по убыванию выгоды.
-- ---------------------------------------------------------------------------
function P.SuggestRecipes(profKey, fromSkill, toSkill, basePlan)
    local shop = PR.RecipeShop and PR.RecipeShop[profKey]
    if not shop then return {} end
    local prof = PR.Professions[profKey]
    if not prof then return {} end
    local base = (basePlan and basePlan.totalCost) or 0

    local out = {}
    for _, cand in ipairs(shop) do
        -- рецепт должен быть полезен на участке маршрута
        if cand.gry > fromSkill and cand.min < toSkill then
            local known = false
            for _, r in ipairs(prof.recipes) do
                if r.item == cand.made then known = true break end
            end
            if not known then
                -- цена самого свитка рецепта
                local price, source
                if cand.vendor then
                    price, source = cand.vendor, "vendor"
                else
                    price, source = PR.GetPrice(cand.item)
                    source = "ah"
                end

                if price then
                    local tmp = { item = cand.made, min = cand.min, yel = cand.yel,
                                  grn = cand.grn, gry = cand.gry,
                                  reagents = cand.reagents }
                    table.insert(prof.recipes, tmp)
                    local newPlan = P.BuildPlan(profKey, fromSkill, toSkill)
                    table.remove(prof.recipes)

                    if newPlan and newPlan.possible then
                        local savings = base - newPlan.totalCost
                        if savings > price then
                            table.insert(out, {
                                cand = cand, savings = savings, price = price,
                                source = source, newTotal = newPlan.totalCost,
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(out, function(a, b) return a.savings > b.savings end)
    return out
end

-- ---------------------------------------------------------------------------
-- Список покупок: агрегируем реагенты по всему маршруту,
-- вычитаем то, что уже есть в сумках/банке.
-- Возвращает shopping = { {itemID, need, have, buy, price, subtotal, stale}, ... },
-- и итоговую стоимость закупки.
-- ---------------------------------------------------------------------------
function P.BuildShoppingList(plan)
    local agg = {} -- itemID -> need
    for _, step in ipairs(plan.steps) do
        local r = step.recipe
        -- сколько крафтов по этому шагу ещё актуально (учитываем частичный прогресс)
        for _, rg in ipairs(r.reagents) do
            agg[rg[1]] = (agg[rg[1]] or 0) + rg[2] * step.crafts
        end
    end

    local shopping, total = {}, 0
    for itemID, need in pairs(agg) do
        need = math.ceil(need)
        local have = PR.Bags.Count(itemID)
        local buy = math.max(0, need - have)
        local price, source, stale = PR.GetPrice(itemID)
        local subtotal = price and price * buy or nil
        if subtotal then total = total + subtotal end
        table.insert(shopping, {
            itemID = itemID,
            need = need,
            have = have,
            buy = buy,
            price = price,
            source = source,
            stale = stale,
            subtotal = subtotal,
        })
    end

    -- сортировка: сначала то, что нужно купить (дорогие сверху), потом остальное
    table.sort(shopping, function(a, b)
        if (a.buy > 0) ~= (b.buy > 0) then return a.buy > 0 end
        if a.buy > 0 and b.buy > 0 then
            return (a.subtotal or 0) > (b.subtotal or 0)
        end
        return (a.need or 0) > (b.need or 0)
    end)

    return shopping, total
end
