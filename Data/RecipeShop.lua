-- ============================================================================
-- ProfRoute — Data/RecipeShop.lua
-- Кандидаты для сканера выгодных рецептов.
--
-- Идея: некоторые рецепты покупаются у торговца (или на аукционе) и открывают
-- крафт, который прокачивает профессию дешевле текущего маршрута. Планировщик
-- временно добавляет такого кандидата в базу, пересчитывает маршрут и, если
-- экономия больше цены самого рецепта, предлагает его к покупке.
--
-- Формат кандидата:
--   item     — itemID самого рецепта (свитка) — для тултипа и поиска на АХ
--   name     — локализованные названия {ru=..., en=...}
--   made     — itemID создаваемого предмета
--   min/yel/grn/gry — пороги сложности (см. ниже про verified)
--   reagents — { {itemID, количество}, ... }
--   vendor   — цена у торговца в меди (nil — значит только аукцион)
--   limited  — true, если у торговца ограниченный запас (не всегда есть в продаже)
--   verified — данные подтверждены в игре на Forever. Пока false — пороги
--              сложности оценочные (+20/+30/+40 к требованию навыка) и строка
--              в интерфейсе помечается как требующая проверки.
--
-- Источники: classicdb.ch (комплекты реагентов с количествами, требования
-- навыка, цены и наличие у торговцев). Пороги сложности на сайте не публикуются
-- — они проверяются в игре по тултипу рецепта.
-- ============================================================================

local PR = ProfRoute

PR.RecipeShop = {

    -- ------------------------------------------------------------------
    -- АЛХИМИЯ
    -- ------------------------------------------------------------------
    ALCHEMY = {
        { item = 4597, name = { ru = "Рецепт: бесцветное лечебное зелье",
                                en = "Recipe: Discolored Healing Potion" },
          made = 4596, min = 50,  yel = 70,  grn = 80,  gry = 90,
          reagents = { { 3164, 1 }, { 2447, 1 }, { 3371, 1 } },
          vendor = nil, limited = false, verified = false },

        { item = 5640, name = { ru = "Рецепт: зелье ярости",
                                en = "Recipe: Rage Potion" },
          made = 5631, min = 60,  yel = 80,  grn = 90,  gry = 100,
          reagents = { { 5635, 1 }, { 2450, 1 }, { 3371, 1 } },
          vendor = 100, limited = false, verified = false },

        { item = 3393, name = { ru = "Рецепт: простое зелье защиты от магии",
                                en = "Recipe: Minor Magic Resistance Potion" },
          made = 3384, min = 110, yel = 130, grn = 140, gry = 150,
          reagents = { { 785, 3 }, { 3355, 1 }, { 3371, 1 } },
          vendor = nil, limited = false, verified = false },

        { item = 5642, name = { ru = "Рецепт: зелье свободы",
                                en = "Recipe: Free Action Potion" },
          made = 5634, min = 150, yel = 170, grn = 180, gry = 190,
          reagents = { { 6370, 2 }, { 3820, 1 }, { 3372, 1 } },
          vendor = 1800, limited = false, verified = false },

        { item = 5643, name = { ru = "Рецепт: сильное зелье ярости",
                                en = "Recipe: Great Rage Potion" },
          made = 5633, min = 175, yel = 195, grn = 205, gry = 215,
          reagents = { { 5637, 1 }, { 3356, 1 }, { 3372, 1 } },
          vendor = 2000, limited = false, verified = false },
    },

    -- ------------------------------------------------------------------
    -- КУЗНЕЧНОЕ ДЕЛО
    -- ------------------------------------------------------------------
    BLACKSMITHING = {
        { item = 6044, name = { ru = "Чертеж: железный шип для щита",
                                en = "Plans: Iron Shield Spike" },
          made = 6042, min = 150, yel = 170, grn = 180, gry = 190,
          reagents = { { 3575, 6 }, { 3478, 4 }, { 5956, 1 } },
          vendor = nil, limited = false, verified = false },

        { item = 12162, name = { ru = "Чертеж: закаленный железный короткий меч",
                                 en = "Plans: Hardened Iron Shortsword" },
          made = 3849, min = 160, yel = 180, grn = 190, gry = 200,
          reagents = { { 3575, 6 }, { 3466, 2 }, { 3486, 1 }, { 1705, 2 },
                       { 4234, 3 }, { 5956, 1 } },
          vendor = 3000, limited = true, verified = false },

        { item = 3871, name = { ru = "Чертеж: наплечники из золотой чешуи",
                                en = "Plans: Golden Scale Shoulders" },
          made = 3841, min = 175, yel = 195, grn = 205, gry = 215,
          reagents = { { 3859, 6 }, { 3577, 2 }, { 3486, 1 }, { 5956, 1 } },
          vendor = nil, limited = false, verified = false },

        { item = 12163, name = { ru = "Чертеж: лунностальной палаш",
                                 en = "Plans: Moonsteel Broadsword" },
          made = 3853, min = 180, yel = 200, grn = 210, gry = 220,
          reagents = { { 3859, 8 }, { 3466, 2 }, { 3486, 2 }, { 1705, 3 },
                       { 4234, 3 }, { 5956, 1 } },
          vendor = 4400, limited = true, verified = false },
    },

    -- ------------------------------------------------------------------
    -- КОЖЕВНИЧЕСТВО
    -- ------------------------------------------------------------------
    LEATHERWORKING = {
        { item = 5786, name = { ru = "Выкройка: пояс из чешуи мурлока",
                                en = "Pattern: Murloc Scale Belt" },
          made = 5780, min = 90,  yel = 110, grn = 120, gry = 130,
          reagents = { { 5784, 8 }, { 2318, 6 }, { 2321, 1 } },
          vendor = 550, limited = false, verified = false },

        { item = 5787, name = { ru = "Выкройка: кираса из чешуи мурлока",
                                en = "Pattern: Murloc Scale Breastplate" },
          made = 5781, min = 95,  yel = 115, grn = 125, gry = 135,
          reagents = { { 5784, 12 }, { 4231, 1 }, { 2318, 8 }, { 2321, 1 } },
          vendor = 600, limited = false, verified = false },

        { item = 13287, name = { ru = "Выкройка: портупея из шкуры ящера",
                                 en = "Pattern: Raptor Hide Harness" },
          made = 4455, min = 165, yel = 185, grn = 195, gry = 205,
          reagents = { { 4461, 6 }, { 4234, 4 }, { 2321, 2 } },
          vendor = 2500, limited = true, verified = false },

        { item = 13288, name = { ru = "Выкройка: пояс из шкуры ящера",
                                 en = "Pattern: Raptor Hide Belt" },
          made = 4456, min = 165, yel = 185, grn = 195, gry = 205,
          reagents = { { 4461, 4 }, { 4234, 4 }, { 2321, 2 } },
          vendor = 2500, limited = false, verified = false },

        { item = 5788, name = { ru = "Выкройка: прочный доспех из чешуи мурлока",
                                en = "Pattern: Thick Murloc Armor" },
          made = 5782, min = 170, yel = 190, grn = 200, gry = 210,
          reagents = { { 5785, 12 }, { 4236, 1 }, { 4234, 10 }, { 2321, 3 } },
          vendor = 650, limited = true, verified = false },

        { item = 5789, name = { ru = "Выкройка: наручи из чешуи мурлока",
                                en = "Pattern: Murloc Scale Bracers" },
          made = 5783, min = 190, yel = 210, grn = 220, gry = 230,
          reagents = { { 5785, 16 }, { 4236, 1 }, { 4234, 14 }, { 4291, 1 } },
          vendor = 2800, limited = true, verified = false },
    },

    -- ------------------------------------------------------------------
    -- ПОРТНЯЖНОЕ ДЕЛО
    -- ------------------------------------------------------------------
    TAILORING = {
        { item = 6272, name = { ru = "Выкройка: синее льняное одеяние",
                                en = "Pattern: Blue Linen Robe" },
          made = 6242, min = 70,  yel = 90,  grn = 100, gry = 110,
          reagents = { { 2996, 4 }, { 2320, 2 }, { 6260, 2 } },
          vendor = 300, limited = true, verified = false },

        { item = 2601, name = { ru = "Выкройка: серая шерстяная роба",
                                en = "Pattern: Gray Woolen Robe" },
          made = 2585, min = 105, yel = 125, grn = 135, gry = 145,
          reagents = { { 2997, 4 }, { 2321, 3 }, { 4340, 1 } },
          vendor = nil, limited = false, verified = false },

        { item = 4347, name = { ru = "Выкройка: усиленные шерстяные наплечники",
                                en = "Pattern: Reinforced Woolen Shoulders" },
          made = 4315, min = 120, yel = 140, grn = 150, gry = 160,
          reagents = { { 2997, 6 }, { 2319, 2 }, { 2321, 2 } },
          vendor = nil, limited = false, verified = false },

        { item = 6390, name = { ru = "Выкройка: элегантная синяя рубашка",
                                en = "Pattern: Stylish Blue Shirt" },
          made = 6384, min = 120, yel = 140, grn = 150, gry = 160,
          reagents = { { 2997, 4 }, { 6260, 2 }, { 4340, 1 }, { 2321, 1 } },
          vendor = nil, limited = false, verified = false },
    },
}
