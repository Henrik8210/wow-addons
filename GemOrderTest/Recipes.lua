GemOrderTest = GemOrder or {}

local TRADE_SKILL_NAME = "Jewelcrafting"
local scanPending = false
local autoScanSilent = false
local autoScanClose = false
local scanRetryToken = 0
local eventScanQueued = false

local function EnsureDB()
    GemOrderTestDB = GemOrderTestDB or {}
    GemOrderTestDB.recipes = GemOrderTestDB.recipes or { jcReports = {} }
    GemOrderTestDB.recipes.jcReports = GemOrderTestDB.recipes.jcReports or {}
end

function GemOrderTest_ShouldShareRecipes()
    return GemOrderTest_ShouldShareStock()
end

function GemOrderTest_IsJewelcraftingOpen()
    if not GetNumTradeSkills then
        return false
    end
    local num = GetNumTradeSkills() or 0
    if num <= 0 then
        return false
    end
    if GetTradeSkillLine then
        local line = GetTradeSkillLine()
        if line and line ~= TRADE_SKILL_NAME and not line:find("Jewelcraft") then
            return false
        end
    end
    return true
end

local jcSpellRefCache = nil

local function GetJewelcraftingSpellRef()
    if jcSpellRefCache then
        return jcSpellRefCache
    end

    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            if offset and numSpells then
                for i = offset + 1, offset + numSpells do
                    local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                    if name and name:find("Jewelcraft") then
                        local spellId
                        if GetSpellBookItemInfo then
                            _, spellId = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
                        end
                        if spellId and GetSpellInfo then
                            local resolved = GetSpellInfo(spellId)
                            if resolved then
                                jcSpellRefCache = resolved
                                return jcSpellRefCache
                            end
                        end
                        jcSpellRefCache = name
                        return jcSpellRefCache
                    end
                end
            end
        end
    end

    jcSpellRefCache = TRADE_SKILL_NAME
    return jcSpellRefCache
end

function GemOrderTest_HandleRecipesRefreshClick()
    if GemOrderTest_IsJewelcraftingOpen() then
        GemOrderTest_RefreshRecipesFromMacro(false)
        return
    end

    local spellRef = GetJewelcraftingSpellRef()
    if CastSpellByName then
        CastSpellByName(spellRef)
    end
    GemOrderTest_RefreshRecipesFromMacro(true)
end

function GemOrderTest_InitRecipesRefreshButton(btn)
    if not btn or btn._gemOrderRefreshInit then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    btn._gemOrderRefreshInit = true
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/run GemOrderTest_HandleRecipesRefreshClick()")
end

function GemOrderTest_RefreshRecipesSyncOnly()
    if GemOrderTest.Sync then
        GemOrderTest.Sync:RequestSync()
    end
    if GemOrderTest.UI then
        GemOrderTest_RefreshUI()
    end
    print("|cff00ccffGemOrderTest|r Recipe list refreshed.")
end

local function MatchGemByName(name)
    if not name or name == "" then
        return nil
    end
    local gem = GemOrderTest_GemByName[name]
    if gem then
        return gem
    end
    if strlower then
        for gemName, entry in pairs(GemOrderTest_GemByName or {}) do
            if strlower(gemName) == strlower(name) then
                return entry
            end
        end
    end
    return nil
end

local function ItemIdFromLink(link)
    if not link then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

function GemOrderTest_ScanOpenTradeSkill()
    local known = {}
    if not GetNumTradeSkills or not GetTradeSkillInfo then
        return known, 0
    end

    local num = GetNumTradeSkills() or 0
    if num <= 0 then
        return known, 0
    end

    for i = 1, num do
        local name, skillType = GetTradeSkillInfo(i)
        if name and skillType ~= "header" then
            local itemId = ItemIdFromLink(GetTradeSkillItemLink and GetTradeSkillItemLink(i))
            if not itemId then
                local gem = MatchGemByName(name)
                itemId = gem and gem.itemId
            end
            if itemId and GemOrderTest_IsTrackedRecipeItemId(itemId) then
                known[itemId] = true
            end
        end
    end

    return known, num
end

local function StoreLocalRecipeReport(itemIds)
    EnsureDB()
    GemOrderTestDB.recipes.jcReports[UnitName("player")] = {
        itemIds = itemIds,
        updatedAt = time(),
    }
end

local function CountKnown(itemIds)
    local count = 0
    for _ in pairs(itemIds or {}) do
        count = count + 1
    end
    return count
end

local function FinishAutoScanClose()
    autoScanClose = false
    autoScanSilent = false
end

local function ApplyRecipeScanResult(known, numSkills, source)
    StoreLocalRecipeReport(known)
    GemOrderTest.Sync:BroadcastRecipes(known)
    if GemOrderTest.UI then
        GemOrderTest_RefreshUI()
    end

    local knownCount = CountKnown(known)
    if scanPending then
        if numSkills <= 0 then
            print("|cffff0000GemOrderTest|r Could not read recipes. Open your Jewelcrafting window and try again.")
        elseif knownCount == 0 then
            print("|cff00ccffGemOrderTest|r Scanned Jewelcrafting (" .. numSkills .. " entries). No tracked gem cuts found yet.")
        else
            print("|cff00ccffGemOrderTest|r Scanned and shared " .. knownCount .. " gem cut recipes with the workshop.")
        end
    elseif source == "login" and knownCount > 0 then
        print("|cff00ccffGemOrderTest|r Shared " .. knownCount .. " gem cut recipes with the workshop.")
    end

    scanPending = false
    FinishAutoScanClose()
end

local function RunRecipeScan(source)
    if not GemOrderTest_ShouldShareRecipes() then
        scanPending = false
        FinishAutoScanClose()
        return
    end

    local known, numSkills = GemOrderTest_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, source)
        return
    end

    if source == "retry" then
        return
    end
end

local function ScheduleRecipeScan(source, delay)
    scanRetryToken = scanRetryToken + 1
    local token = scanRetryToken
    local function attempt(retryDelay, retrySource)
        if token ~= scanRetryToken then
            return
        end
        if not GemOrderTest_ShouldShareRecipes() then
            scanPending = false
            FinishAutoScanClose()
            return
        end

        local known, numSkills = GemOrderTest_ScanOpenTradeSkill()
        if numSkills > 0 then
            ApplyRecipeScanResult(known, numSkills, source)
            return
        end

        if retrySource == "retry1" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, function()
                    attempt(0, "retry2")
                end)
            end
            return
        end

        if retrySource == "retry2" then
            if scanPending and not autoScanSilent then
                print("|cffff0000GemOrderTest|r Could not read recipes. Open your Jewelcrafting window and try again.")
            end
            scanPending = false
            FinishAutoScanClose()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.15, function()
            attempt(0, "retry1")
        end)
    else
        attempt(0, "retry1")
    end
end

function GemOrderTest_ScanAndShareRecipes()
    EnsureDB()
    if not GemOrderTest_ShouldShareRecipes() then
        return false, "Only promoted jewelcrafters can share recipes."
    end

    local known, numSkills = GemOrderTest_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, "manual")
        return true
    end

    print("|cff00ccffGemOrderTest|r Open Jewelcrafting, then click Refresh on the Recipes tab.")
    return false, "closed"
end

function GemOrderTest_ShareWorkshopRecipes()
    EnsureDB()
    if not GemOrderTest_ShouldShareRecipes() then
        return
    end
    local player = UnitName("player")
    local report = GemOrderTestDB.recipes.jcReports[player]
    if report and report.itemIds then
        GemOrderTest.Sync:BroadcastRecipes(report.itemIds)
    end
end

function GemOrderTest_AutoScanRecipes(silent)
    if not GemOrderTest_ShouldShareRecipes() then
        return
    end

    if not GemOrderTest_IsJewelcraftingOpen() then
        if not silent then
            print("|cff00ccffGemOrderTest|r Open Jewelcrafting, then click Refresh on the Recipes tab.")
        end
        return
    end

    autoScanSilent = silent and true or false
    autoScanClose = false
    if not silent then
        scanPending = true
    end
    ScheduleRecipeScan(silent and "login" or "manual", 0.1)
end

function GemOrderTest_RequestRecipeScan()
    return GemOrderTest_ScanAndShareRecipes()
end

function GemOrderTest_ApplyRecipeReport(player, itemIds)
    EnsureDB()
    GemOrderTestDB.recipes.jcReports[player] = {
        itemIds = itemIds,
        updatedAt = time(),
    }
    if GemOrderTest.UI then
        GemOrderTest_RefreshUI()
    end
end

function GemOrderTest_GetRecipeCoverage(room, tier)
    EnsureDB()
    local coverage = {}
    if not room then
        return coverage
    end

    for _, gem in ipairs(GemOrderTest_GetRecipeGems(tier or "epic")) do
        local jcs = {}
        for _, jcName in ipairs(GemOrderTest_GetWorkshopStockContributors(room)) do
            local report = GemOrderTestDB.recipes.jcReports[jcName]
            if report and report.itemIds and report.itemIds[gem.itemId] then
                table.insert(jcs, jcName)
            end
        end
        table.insert(coverage, {
            gem = gem,
            jcs = jcs,
        })
    end
    return coverage
end

function GemOrderTest_WorkshopHasRecipeForGem(gemName)
    if not gemName or gemName == "None" then
        return true
    end

    local gem = GemOrderTest_GemByName[gemName]
    if not gem or gem.raw or not gem.itemId then
        return true
    end

    local room = GemOrderTest_GetActiveRoom()
    if not room then
        return true
    end

    EnsureDB()
    local contributors = GemOrderTest_GetWorkshopStockContributors(room)
    if #contributors == 0 then
        return false
    end

    for _, jcName in ipairs(contributors) do
        local report = GemOrderTestDB.recipes.jcReports[jcName]
        if report and report.itemIds and report.itemIds[gem.itemId] then
            return true
        end
    end

    return false
end

local RECIPE_KNOWN_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
local RECIPE_MISSING_ICON = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t"

function GemOrderTest_GetRecipeIndicatorText(gemName)
    if not gemName or gemName == "None" then
        return ""
    end

    local gem = GemOrderTest_GemByName and GemOrderTest_GemByName[gemName]
    if not gem or gem.raw or not gem.itemId then
        return ""
    end

    if GemOrderTest_WorkshopHasRecipeForGem(gemName) then
        return RECIPE_KNOWN_ICON .. " "
    end

    return RECIPE_MISSING_ICON .. " "
end

function GemOrderTest_FormatGemDropdownLabel(gemName)
    if not gemName or gemName == "None" then
        return nil
    end

    local indicator = GemOrderTest_GetRecipeIndicatorText(gemName)
    if indicator == "" then
        return gemName
    end

    return indicator .. gemName
end

local function QueuePassiveRecipeScan()
    if not GemOrderTest_ShouldShareRecipes() or not GemOrderTest_HasJoinedWorkshop() then
        return
    end
    if scanPending or autoScanSilent or autoScanClose or eventScanQueued then
        return
    end
    eventScanQueued = true

    local function run()
        eventScanQueued = false
        if scanPending or autoScanSilent or autoScanClose then
            return
        end
        if not GemOrderTest_ShouldShareRecipes() or not GemOrderTest_IsJewelcraftingOpen() then
            return
        end
        local known, numSkills = GemOrderTest_ScanOpenTradeSkill()
        if numSkills <= 0 then
            return
        end
        StoreLocalRecipeReport(known)
        GemOrderTest.Sync:BroadcastRecipes(known)
        if GemOrderTest.UI then
            GemOrderTest_RefreshUI()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.75, run)
    else
        run()
    end
end

local function OnTradeSkillEvent()
    if scanPending or autoScanSilent or autoScanClose then
        ScheduleRecipeScan(autoScanSilent and "login" or "manual", 0.1)
        return
    end
    QueuePassiveRecipeScan()
end

function GemOrderTest_RefreshRecipesFromMacro(delayScan)
    if not GemOrderTest_ShouldShareRecipes() then
        GemOrderTest_RefreshRecipesSyncOnly()
        return
    end

    if delayScan then
        scanPending = true
        print("|cff00ccffGemOrderTest|r Opening Jewelcrafting…")
        ScheduleRecipeScan("manual", 0.75)
        return
    end

    local known, numSkills = GemOrderTest_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, "manual")
    else
        print("|cffff0000GemOrderTest|r Open your Jewelcrafting window, then click Refresh again.")
    end
end

local recipeWatcher

function GemOrderTest_InitRecipeEvents()
    if recipeWatcher then
        return
    end
    recipeWatcher = CreateFrame("Frame")
    recipeWatcher:RegisterEvent("TRADE_SKILL_SHOW")
    recipeWatcher:RegisterEvent("TRADE_SKILL_UPDATE")
    recipeWatcher:SetScript("OnEvent", OnTradeSkillEvent)
end
