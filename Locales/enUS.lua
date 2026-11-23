-- ============================================================================
-- ProfRoute — Locales/enUS.lua
-- English localization (fallback for all non-Russian clients).
-- ============================================================================

local PR = ProfRoute

PR.Locales.enUS = {
    -- money
    MONEY_G = "g", MONEY_S = "s", MONEY_C = "c",
    MONEY_UNKNOWN = "|cff8c8c8cno data|r",

    -- Core
    MSG_LOADED = "loaded. Open window: |cffffffff/proute|r",
    MSG_API_WARNING = "|cffff8080warning:|r non-standard client API, check this build.",
    MSG_RESET_DONE = "price database cleared.",

    -- Scanner
    SCAN_NO_SUPPORT = "scanner is not supported by this client (no C_AuctionHouse).",
    SCAN_OPEN_AH = "open the auction house window and start the scan again.",
    SCAN_SELECT_PROF = "select a profession in the ProfRoute window first (/proute).",
    SCAN_START = "scanning: %d items. Do not close the auction house window.",
    SCAN_DONE = "scan finished: %d of %d items found on the auction house.",
    SCAN_ABORTED = "auction house window closed — scan stopped.",
    SCAN_QUERY_FAIL = "query #%d was not sent (%s).",
    SRC_SCANNER = "built-in scanner",

    -- Window
    UI_TITLE = "|cff4da3ffProfRoute|r  |cff8c96b0— profession leveling route|r",
    UI_PROFESSION = "Profession",
    UI_SELECT_PROF = "Select a profession",
    UI_CURRENT_SKILL = "Current skill",
    UI_TARGET = "Target",
    UI_BUILD = "Build plan",
    UI_SCAN = "Scan prices",
    UI_ROUTE = "ROUTE",
    UI_SHOPPING = "SHOPPING LIST",
    UI_PLAN_EMPTY = "Select a profession and press «Build plan».",
    UI_PLAN_IMPOSSIBLE = "Could not build a route:\nno recipes in the database for the selected skill range.",
    UI_SHOP_EMPTY = "The list will appear after the plan is built.",
    UI_TOTAL_COST = "Estimated cost: ",
    UI_TOTAL_BUY = "To buy: ",
    UI_UNKNOWN_NOTE = "   |cffff8040* some prices unknown — run a scan|r",
    UI_STEP_FMT = "skill %d → %d   ·   craft ×%d",
    UI_PER_ITEM = "each: %s",
    UI_NEED_FMT = "need %d · have %d",
    UI_BUY_FMT = "|cffff6a5fbuy ×%d|r",
    UI_HAVE_ENOUGH = "|cff59e673enough|r",
    UI_STALE = " |cffff8040(stale)|r",
    UI_STATUS_SOURCE = "Price source: |cffffffff%s|r",
    UI_STATUS_SCANNING = "|cffffd700Scanning auction house: %d/%d...|r",
    UI_HINT = "/proute — open · scanner works at the auction house",

    -- Recipe details / auction
    UI_REAGENTS = "Reagents",
    UI_DETAIL_EMPTY = "Click a recipe to see its reagents.",
    UI_CRAFTS_FMT = "craft ×%d",
    UI_SCAN_AH_BTN = "ProfRoute: scan",
    UI_SCAN_BTN_TT = "Scan route reagent prices\n(requires an open auction house)",
    UI_VENDOR_ITEM = "sold by vendors",

    -- Settings
    UI_SETTINGS = "Settings",
    UI_LANGUAGE = "Language",
    UI_LANG_AUTO = "Auto (client)",
    UI_USE_BANK = "Include bank when counting reagents",
    MSG_LOCALE_RELOAD = "language changed, reloading UI...",

    -- Minimap button
    MM_TITLE = "|cff4da3ffProfRoute|r",
    MM_L1 = "Left-click — open/close window",
    MM_L2 = "Drag with left button — move the button",
    MM_L3 = "/proute minimap — hide the button",
    MM_STATE_HIDDEN = "minimap button: hidden",
    MM_STATE_SHOWN = "minimap button: shown",
}
