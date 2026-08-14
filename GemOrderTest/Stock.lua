GemOrderTest = GemOrder or {}

local function EnsureDB()
    GemOrderTestDB = GemOrderTestDB or {}
    GemOrderTestDB.stock = GemOrderTestDB.stock or {
        bags = {},
        bank = {},
        jcReports = {},
    }
end

local function EmptyCounts()
    local counts = {}
    for _, gem in ipairs(GemOrderTest_GetRawGems()) do
        counts[gem.itemId] = 0
    end
    return counts
end

local function ItemIdFromLink(link)
    if not link then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local function AddItemToCounts(itemId, stackCount, counts)
    if itemId and counts[itemId] ~= nil then
        counts[itemId] = counts[itemId] + (stackCount or 1)
    end
end

local function AddLinkToCounts(link, counts, stackCount)
    AddItemToCounts(ItemIdFromLink(link), stackCount, counts)
end

local function MergeCounts(into, from)
    for itemId, count in pairs(from or {}) do
        into[itemId] = (into[itemId] or 0) + count
    end
    return into
end

local function GetContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

local function ScanContainerSlot(bag, slot, counts)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            local link = info.hyperlink
            if not link and info.iconFileID and C_Container.GetContainerItemLink then
                link = C_Container.GetContainerItemLink(bag, slot)
            end
            AddLinkToCounts(link, counts, info.stackCount)
            return
        end
    end

    if GetContainerItemInfo then
        local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
        local _, stackCount = GetContainerItemInfo(bag, slot)
        AddLinkToCounts(link, counts, stackCount)
        return
    end

    if GetContainerItemLink then
        AddLinkToCounts(GetContainerItemLink(bag, slot), counts, 1)
    end
end

local function ScanBagRange(firstBag, lastBag, counts)
    for bag = firstBag, lastBag do
        local slots = GetContainerSlots(bag)
        for slot = 1, slots do
            ScanContainerSlot(bag, slot, counts)
        end
    end
end

function GemOrderTest_ScanBagsForGems()
    local counts = EmptyCounts()
    ScanBagRange(0, 4, counts)

    EnsureDB()
    GemOrderTestDB.stock.bags = counts
    GemOrderTestDB.stock.bagsUpdated = time()
    return counts
end

local function IsBankAccessible()
    if BankFrame and BankFrame.IsShown and BankFrame:IsShown() then
        return true
    end
    return GetContainerSlots(5) > 0
end

function GemOrderTest_IsBankAccessible()
    return IsBankAccessible()
end

function GemOrderTest_GetBankStockNote()
    EnsureDB()
    if IsBankAccessible() then
        return nil
    end
    if GemOrderTestDB.stock.bankUpdated then
        return "bank included from last visit"
    end
    return "open your bank once to include bank gems"
end

function GemOrderTest_ScanPersonalBankForGems()
    EnsureDB()
    if not IsBankAccessible() then
        GemOrderTestDB.stock.bank = GemOrderTestDB.stock.bank or EmptyCounts()
        return GemOrderTestDB.stock.bank
    end

    local counts = EmptyCounts()
    ScanBagRange(5, 11, counts)

    GemOrderTestDB.stock.bank = counts
    GemOrderTestDB.stock.bankUpdated = time()
    return counts
end

function GemOrderTest_GetCombinedPersonalStock()
    EnsureDB()
    GemOrderTestDB.stock.bags = GemOrderTestDB.stock.bags or EmptyCounts()
    GemOrderTestDB.stock.bank = GemOrderTestDB.stock.bank or EmptyCounts()
    return MergeCounts(MergeCounts(EmptyCounts(), GemOrderTestDB.stock.bags), GemOrderTestDB.stock.bank)
end

function GemOrderTest_RefreshLocalStock()
    GemOrderTest_ScanBagsForGems()
    GemOrderTest_ScanPersonalBankForGems()
    if GemOrderTest_ShouldShareStock() then
        GemOrderTest_ShareWorkshopStock()
    end
    if GemOrderTest.UI and GemOrderTest.UI.frame then
        GemOrderTest.UI:Refresh()
    end
end

function GemOrderTest_ShareWorkshopStock()
    EnsureDB()
    if not IsInGuild() or not GemOrderTest_ShouldShareStock() then
        return
    end

    GemOrderTest.Sync:BroadcastStock(GemOrderTest_GetCombinedPersonalStock(), "jc")
end

function GemOrderTest_GetStockCounts(source)
    EnsureDB()
    if source == "bags" then
        return GemOrderTestDB.stock.bags or {}
    end
    if source == "bank" then
        return GemOrderTestDB.stock.bank or {}
    end
    if source == "personal" then
        return GemOrderTest_GetCombinedPersonalStock()
    end
    return {}
end

function GemOrderTest_GetWorkshopStockReports(room)
    EnsureDB()
    local reports = {}
    if not room then
        return reports
    end

    for _, name in ipairs(GemOrderTest_GetWorkshopStockContributors(room)) do
        local report = GemOrderTestDB.stock.jcReports[name]
        if report then
            reports[name] = report
        end
    end
    return reports
end

function GemOrderTest_GetAggregatedWorkshopStock(room)
    local totals = EmptyCounts()
    local player = UnitName("player")

    for _, jcName in ipairs(GemOrderTest_GetWorkshopStockContributors(room)) do
        if jcName == player then
            MergeCounts(totals, GemOrderTest_GetCombinedPersonalStock())
        else
            local report = GemOrderTestDB.stock.jcReports[jcName]
            if report then
                MergeCounts(totals, report.counts)
            end
        end
    end
    return totals
end

function GemOrderTest_ApplyStockReport(player, counts, source)
    EnsureDB()
    if source == "jc" or source == "bags" then
        GemOrderTestDB.stock.jcReports[player] = {
            counts = counts,
            updatedAt = time(),
        }
    end
    if GemOrderTest.UI and GemOrderTest.UI.frame then
        GemOrderTest.UI:Refresh()
    end
end

function GemOrderTest_GetStockListing(counts)
    local lines = {}
    for _, gem in ipairs(GemOrderTest_GetRawGems()) do
        local count = counts[gem.itemId] or 0
        if count > 0 then
            table.insert(lines, {
                name = gem.name,
                count = count,
                itemId = gem.itemId,
                raw = true,
                rare = gem.rare,
            })
        end
    end
    table.sort(lines, function(a, b)
        if (a.rare or false) ~= (b.rare or false) then
            return not a.rare
        end
        return a.name < b.name
    end)
    return lines
end

local stockEventFrame
local bankScanQueued = false

local function QueueBankStockRefresh()
    if bankScanQueued then
        return
    end
    bankScanQueued = true

    local function run()
        bankScanQueued = false
        if not IsBankAccessible() then
            return
        end
        GemOrderTest_ScanPersonalBankForGems()
        GemOrderTest_ScanBagsForGems()
        if GemOrderTest_ShouldShareStock() then
            GemOrderTest_ShareWorkshopStock()
        end
        if GemOrderTest.UI and GemOrderTest.UI.frame then
            GemOrderTest.UI:Refresh()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, run)
    else
        run()
    end
end

function GemOrderTest_InitStockEvents()
    if stockEventFrame then
        return
    end

    stockEventFrame = CreateFrame("Frame")
    stockEventFrame:RegisterEvent("BANKFRAME_OPENED")
    stockEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    stockEventFrame:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then
            QueueBankStockRefresh()
        end
    end)
end
