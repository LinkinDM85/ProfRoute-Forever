-- ============================================================================
-- ProfRoute — MinimapButton.lua
-- Кнопка у миникарты: открытие окна без слэш-команды.
-- Перетаскивается по окружности миникарты, позиция сохраняется.
-- ЛКМ — открыть/закрыть окно. /proute minimap — скрыть/показать кнопку.
-- ============================================================================

local PR = ProfRoute

local RADIUS_OFFSET = 12 -- на сколько пикселей кнопка выступает за край миникарты

local function UpdatePosition(btn)
    local angle = math.rad(PR.db.minimap.angle or 220)
    local r = (Minimap:GetWidth() / 2) + RADIUS_OFFSET
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * r, math.sin(angle) * r)
end

local function CreateButton()
    if not Minimap then return end
    if PR.MinimapButton then return end

    local b = CreateFrame("Button", "ProfRouteMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- стандартная круглая рамка кнопок миникарты
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Trade_Engineering")

    b:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" and PR.UI and PR.UI.Toggle then
            PR.UI.Toggle()
        end
    end)

    -- перетаскивание по окружности миникарты
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            PR.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff4da3ffProfRoute|r")
        GameTooltip:AddLine("ЛКМ — открыть/закрыть окно", 1, 1, 1)
        GameTooltip:AddLine("Перетаскивание ЛКМ — переместить кнопку", 0.62, 0.62, 0.72)
        GameTooltip:AddLine("/proute minimap — скрыть кнопку", 0.62, 0.62, 0.72)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    UpdatePosition(b)
    b:SetShown(not PR.db.minimap.hide)
    PR.MinimapButton = b
end

function PR.ToggleMinimapButton()
    PR.db.minimap.hide = not PR.db.minimap.hide
    if PR.MinimapButton then
        PR.MinimapButton:SetShown(not PR.db.minimap.hide)
    end
    PR.Print("кнопка у миникарты: " .. (PR.db.minimap.hide and "скрыта" or "показана"))
end

-- создаём после входа в мир (к этому моменту SavedVariables уже загружены)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    PR.db.minimap = PR.db.minimap or { hide = false, angle = 220 }
    CreateButton()
end)
