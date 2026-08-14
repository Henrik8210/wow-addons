GemOrder = GemOrder or {}

local function EnsureDB()
    GemOrderDB = GemOrderDB or {}
    GemOrderDB.stock = GemOrderDB.stock or {
        bags = {},
        bank = {},
        jcReports = {},
    }
end

local function EmptyCounts()
    local counts = {}
    for _, gem in ipairs(GemOrder_GetRawGems()) do
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

function GemOrder_ScanBagsForGems()
    local counts = EmptyCounts()
    ScanBagRange(0, 4, counts)

    EnsureDB()
    GemOrderDB.stock.bags = counts
    GemOrderDB.stock.bagsUpdated = time()
    return counts
end

local function IsBankAccessible()
    if BankFrame and BankFrame.IsShown and BankFrame:IsShown() then
        return true
    end
    return GetContainerSlots(5) > 0
end

function GemOrder_IsBankAccessible()
    return IsBankAccessible()
end

function GemOrder_GetBankStockNote()
    EnsureDB()
    if IsBankAccessible() then
        return nil
    end
    if GemOrderDB.stock.bankUpdated then
        return "bank included from last visit"
    end
    return "open your bank once to include bank gems"
end

function GemOrder_ScanPersonalBankForGems()
    EnsureDB()
    if not IsBankAccessible() then
        GemOrderDB.stock.bank = GemOrderDB.stock.bank or EmptyCounts()
        return GemOrderDB.stock.bank
    end

    local counts = EmptyCounts()
    ScanBagRange(5, 11, counts)

    GemOrderDB.stock.bank = counts
    GemOrderDB.stock.bankUpdated = time()
    return counts
end

function GemOrder_GetCombinedPersonalStock()
    EnsureDB()
    GemOrderDB.stock.bags = GemOrderDB.stock.bags or EmptyCounts()
    GemOrderDB.stock.bank = GemOrderDB.stock.bank or EmptyCounts()
    return MergeCounts(MergeCounts(EmptyCounts(), GemOrderDB.stock.bags), GemOrderDB.stock.bank)
end

function GemOrder_RefreshLocalStock()
    GemOrder_ScanBagsForGems()
    GemOrder_ScanPersonalBankForGems()
    if GemOrder_ShouldShareStock() then
        GemOrder_ShareWorkshopStock()
    end
    if GemOrder.UI and GemOrder.UI.frame then
        GemOrder.UI:Refresh()
    end
end

function GemOrder_ShareWorkshopStock()
    EnsureDB()
    if not IsInGuild() or not GemOrder_ShouldShareStock() then
        return
    end

    GemOrder.Sync:BroadcastStock(GemOrder_GetCombinedPersonalStock(), "jc")
end

function GemOrder_GetStockCounts(source)
    EnsureDB()
    if source == "bags" then
        return GemOrderDB.stock.bags or {}
    end
    if source == "bank" then
        return GemOrderDB.stock.bank or {}
    end
    if source == "personal" then
        return GemOrder_GetCombinedPersonalStock()
    end
    return {}
end

function GemOrder_GetWorkshopStockReports(room)
    EnsureDB()
    local reports = {}
    if not room then
        return reports
    end

    for _, name in ipairs(GemOrder_GetWorkshopStockContributors(room)) do
        local report = GemOrderDB.stock.jcReports[name]
        if report then
            reports[name] = report
        end
    end
    return reports
end

function GemOrder_GetAggregatedWorkshopStock(room)
    local totals = EmptyCounts()
    local player = UnitName("player")

    for _, jcName in ipairs(GemOrder_GetWorkshopStockContributors(room)) do
        if jcName == player then
            MergeCounts(totals, GemOrder_GetCombinedPersonalStock())
        else
            local report = GemOrderDB.stock.jcReports[jcName]
            if report then
                MergeCounts(totals, report.counts)
            end
        end
    end
    return totals
end

function GemOrder_ApplyStockReport(player, counts, source)
    EnsureDB()
    if source == "jc" or source == "bags" then
        GemOrderDB.stock.jcReports[player] = {
            counts = counts,
            updatedAt = time(),
        }
    end
    if GemOrder.UI and GemOrder.UI.frame then
        GemOrder.UI:Refresh()
    end
end

function GemOrder_GetStockListing(counts)
    local lines = {}
    for _, gem in ipairs(GemOrder_GetRawGems()) do
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
        GemOrder_ScanPersonalBankForGems()
        GemOrder_ScanBagsForGems()
        if GemOrder_ShouldShareStock() then
            GemOrder_ShareWorkshopStock()
        end
        if GemOrder.UI and GemOrder.UI.frame then
            GemOrder.UI:Refresh()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, run)
    else
        run()
    end
end

function GemOrder_InitStockEvents()
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
