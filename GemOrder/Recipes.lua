GemOrder = GemOrder or {}

local TRADE_SKILL_NAME = "Jewelcrafting"
local scanPending = false
local autoScanSilent = false
local autoScanClose = false
local scanRetryToken = 0
local eventScanQueued = false

local function EnsureDB()
    GemOrderDB = GemOrderDB or {}
    GemOrderDB.recipes = GemOrderDB.recipes or { jcReports = {} }
    GemOrderDB.recipes.jcReports = GemOrderDB.recipes.jcReports or {}
end

function GemOrder_ShouldShareRecipes()
    return GemOrder_ShouldShareStock()
end

function GemOrder_IsJewelcraftingOpen()
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

function GemOrder_HandleRecipesRefreshClick()
    if GemOrder_IsJewelcraftingOpen() then
        GemOrder_RefreshRecipesFromMacro(false)
        return
    end

    local spellRef = GetJewelcraftingSpellRef()
    if CastSpellByName then
        CastSpellByName(spellRef)
    end
    GemOrder_RefreshRecipesFromMacro(true)
end

function GemOrder_InitRecipesRefreshButton(btn)
    if not btn or btn._gemOrderRefreshInit then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    btn._gemOrderRefreshInit = true
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/run GemOrder_HandleRecipesRefreshClick()")
end

function GemOrder_RefreshRecipesSyncOnly()
    if GemOrder.Sync then
        GemOrder.Sync:RequestSync()
    end
    if GemOrder.UI then
        GemOrder_RefreshUI()
    end
    print("|cff00ccffGemOrder|r Recipe list refreshed.")
end

local function MatchGemByName(name)
    if not name or name == "" then
        return nil
    end
    local gem = GemOrder_GemByName[name]
    if gem then
        return gem
    end
    if strlower then
        for gemName, entry in pairs(GemOrder_GemByName or {}) do
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

function GemOrder_ScanOpenTradeSkill()
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
            if itemId and GemOrder_IsTrackedRecipeItemId(itemId) then
                known[itemId] = true
            end
        end
    end

    return known, num
end

local function StoreLocalRecipeReport(itemIds)
    EnsureDB()
    GemOrderDB.recipes.jcReports[UnitName("player")] = {
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
    GemOrder.Sync:BroadcastRecipes(known)
    if GemOrder.UI then
        GemOrder_RefreshUI()
    end

    local knownCount = CountKnown(known)
    if scanPending then
        if numSkills <= 0 then
            print("|cffff0000GemOrder|r Could not read recipes. Open your Jewelcrafting window and try again.")
        elseif knownCount == 0 then
            print("|cff00ccffGemOrder|r Scanned Jewelcrafting (" .. numSkills .. " entries). No tracked gem cuts found yet.")
        else
            print("|cff00ccffGemOrder|r Scanned and shared " .. knownCount .. " gem cut recipes with the workshop.")
        end
    elseif source == "login" and knownCount > 0 then
        print("|cff00ccffGemOrder|r Shared " .. knownCount .. " gem cut recipes with the workshop.")
    end

    scanPending = false
    FinishAutoScanClose()
end

local function RunRecipeScan(source)
    if not GemOrder_ShouldShareRecipes() then
        scanPending = false
        FinishAutoScanClose()
        return
    end

    local known, numSkills = GemOrder_ScanOpenTradeSkill()
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
        if not GemOrder_ShouldShareRecipes() then
            scanPending = false
            FinishAutoScanClose()
            return
        end

        local known, numSkills = GemOrder_ScanOpenTradeSkill()
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
                print("|cffff0000GemOrder|r Could not read recipes. Open your Jewelcrafting window and try again.")
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

function GemOrder_ScanAndShareRecipes()
    EnsureDB()
    if not GemOrder_ShouldShareRecipes() then
        return false, "Only promoted jewelcrafters can share recipes."
    end

    local known, numSkills = GemOrder_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, "manual")
        return true
    end

    print("|cff00ccffGemOrder|r Open Jewelcrafting, then click Refresh on the Recipes tab.")
    return false, "closed"
end

function GemOrder_ShareWorkshopRecipes()
    EnsureDB()
    if not GemOrder_ShouldShareRecipes() then
        return
    end
    local player = UnitName("player")
    local report = GemOrderDB.recipes.jcReports[player]
    if report and report.itemIds then
        GemOrder.Sync:BroadcastRecipes(report.itemIds)
    end
end

function GemOrder_AutoScanRecipes(silent)
    if not GemOrder_ShouldShareRecipes() then
        return
    end

    if not GemOrder_IsJewelcraftingOpen() then
        if not silent then
            print("|cff00ccffGemOrder|r Open Jewelcrafting, then click Refresh on the Recipes tab.")
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

function GemOrder_RequestRecipeScan()
    return GemOrder_ScanAndShareRecipes()
end

function GemOrder_ApplyRecipeReport(player, itemIds)
    EnsureDB()
    GemOrderDB.recipes.jcReports[player] = {
        itemIds = itemIds,
        updatedAt = time(),
    }
    if GemOrder.UI then
        GemOrder_RefreshUI()
    end
end

function GemOrder_GetRecipeCoverage(room, tier)
    EnsureDB()
    local coverage = {}
    if not room then
        return coverage
    end

    for _, gem in ipairs(GemOrder_GetRecipeGems(tier or "epic")) do
        local jcs = {}
        for _, jcName in ipairs(GemOrder_GetWorkshopStockContributors(room)) do
            local report = GemOrderDB.recipes.jcReports[jcName]
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

function GemOrder_WorkshopHasRecipeForGem(gemName)
    if not gemName or gemName == "None" then
        return true
    end

    local gem = GemOrder_GemByName[gemName]
    if not gem or gem.raw or not gem.itemId then
        return true
    end

    local room = GemOrder_GetActiveRoom()
    if not room then
        return true
    end

    EnsureDB()
    local contributors = GemOrder_GetWorkshopStockContributors(room)
    if #contributors == 0 then
        return false
    end

    for _, jcName in ipairs(contributors) do
        local report = GemOrderDB.recipes.jcReports[jcName]
        if report and report.itemIds and report.itemIds[gem.itemId] then
            return true
        end
    end

    return false
end

local function QueuePassiveRecipeScan()
    if not GemOrder_ShouldShareRecipes() or not GemOrder_HasJoinedWorkshop() then
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
        if not GemOrder_ShouldShareRecipes() or not GemOrder_IsJewelcraftingOpen() then
            return
        end
        local known, numSkills = GemOrder_ScanOpenTradeSkill()
        if numSkills <= 0 then
            return
        end
        StoreLocalRecipeReport(known)
        GemOrder.Sync:BroadcastRecipes(known)
        if GemOrder.UI then
            GemOrder_RefreshUI()
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

function GemOrder_RefreshRecipesFromMacro(delayScan)
    if not GemOrder_ShouldShareRecipes() then
        GemOrder_RefreshRecipesSyncOnly()
        return
    end

    if delayScan then
        scanPending = true
        print("|cff00ccffGemOrder|r Opening Jewelcrafting…")
        ScheduleRecipeScan("manual", 0.75)
        return
    end

    local known, numSkills = GemOrder_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, "manual")
    else
        print("|cffff0000GemOrder|r Open your Jewelcrafting window, then click Refresh again.")
    end
end

local recipeWatcher

function GemOrder_InitRecipeEvents()
    if recipeWatcher then
        return
    end
    recipeWatcher = CreateFrame("Frame")
    recipeWatcher:RegisterEvent("TRADE_SKILL_SHOW")
    recipeWatcher:RegisterEvent("TRADE_SKILL_UPDATE")
    recipeWatcher:SetScript("OnEvent", OnTradeSkillEvent)
end
