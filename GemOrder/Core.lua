local ADDON_NAME = ...

if not strtrim then
    function strtrim(s)
        return (s:gsub("^%s*(.-)%s*$", "%1"))
    end
end

GemOrder = GemOrder or {}
GemOrder.UI = GemOrder.UI or {}
GemOrderDB = GemOrderDB or {
    orders = {},
    rooms = {},
    stock = { bags = {}, bank = {}, jcReports = {} },
    recipes = { jcReports = {} },
    settings = { jcMode = false, activeRoomId = nil, dataVersion = 0 },
}

local DATA_VERSION = 6

local function MigrateSavedData()
    GemOrderDB.settings = GemOrderDB.settings or {}
    if (GemOrderDB.settings.dataVersion or 0) < DATA_VERSION then
        GemOrderDB.orders = {}
        GemOrderDB.rooms = {}
        GemOrderDB.stock = { bags = {}, bank = {}, jcReports = {} }
        GemOrderDB.recipes = { jcReports = {} }
        GemOrderDB.settings.activeRoomId = nil
        GemOrderDB.settings.dataVersion = DATA_VERSION
    end
end

local STATUS_LABELS = {
    pending = "|cffffcc00Pending|r",
    in_progress = "|cff66ccffIn Progress|r",
    completed = "|cff00ff00Completed|r",
    cancelled = "|cff888888Cancelled|r",
}

function GemOrder_GetStatusLabel(status)
    return STATUS_LABELS[status] or status
end

function GemOrder_GetOrderStatusLabel(order)
    if not order then
        return ""
    end
    if order.status == "in_progress" then
        local assignee = order.assignedTo or order.updatedBy
        if assignee then
            return string.format(
                "|cff66ccffIn progress - by %s|r",
                GemOrder_ColorizePlayer(assignee)
            )
        end
    end
    return GemOrder_GetStatusLabel(order.status)
end

GemOrder.VERSION = "0.7.78"

function GemOrder_GetVersion()
    return GemOrder.VERSION
end

function GemOrder_RefreshUI()
    if GemOrder.UI and GemOrder.UI.frame then
        GemOrder.UI:Refresh()
    end
end

function GemOrder_EnsureUI()
    if GemOrder.UI and GemOrder.UI.frame then
        return true
    end

    if not GemOrder.UI or not GemOrder.UI.Init then
        print("|cffff0000GemOrder|r UI failed to load.")
        return false
    end

    local ok, err = pcall(function()
        GemOrder_HookDropdownMenuTooltips()
        GemOrder.UI:Init()
    end)
    if not ok then
        print("|cffff0000GemOrder UI error:|r " .. tostring(err))
        return false
    end
    return GemOrder.UI and GemOrder.UI.frame ~= nil
end

GemOrder_ROLES = { "Tank", "Healer", "DPS" }

local ROLE_COLORS = {
    Tank = "0070dd",
    Healer = "1eff00",
    DPS = "ff2020",
}

local ROLE_DISPLAY_COLOR = "ffff00"

function GemOrder_GetRoleLabel(role)
    role = role or "DPS"
    return string.format("|cff%s%s|r", ROLE_DISPLAY_COLOR, role)
end

local function NormalizePlayerName(name)
    if Ambiguate then
        return Ambiguate(name, "none")
    end
    return name
end

local function LocalizedClassToToken(classDisplayName)
    if not classDisplayName or classDisplayName == "" then
        return nil
    end
    if RAID_CLASS_COLORS[classDisplayName] then
        return classDisplayName
    end
    if LOCALIZED_CLASS_NAMES_MALE then
        for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            if localized == classDisplayName then
                return token
            end
        end
    end
    if LOCALIZED_CLASS_NAMES_FEMALE then
        for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            if localized == classDisplayName then
                return token
            end
        end
    end
    return nil
end

local function ClassFromGuildRosterInfo(name, classDisplayName, classFileName)
    if classFileName and classFileName ~= "" then
        return classFileName
    end
    return LocalizedClassToToken(classDisplayName)
end

function GemOrder_GetPlayerClassToken(playerName)
    if not playerName then
        return nil
    end
    local normalized = NormalizePlayerName(playerName)
    GemOrderDB = GemOrderDB or {}
    GemOrderDB.playerClasses = GemOrderDB.playerClasses or {}
    if GemOrderDB.playerClasses[normalized] then
        return GemOrderDB.playerClasses[normalized]
    end

    if normalized == NormalizePlayerName(UnitName("player")) then
        local _, class = UnitClass("player")
        if class then
            GemOrderDB.playerClasses[normalized] = class
        end
        return class
    end

    local function classFromUnit(unit)
        if UnitExists(unit) and NormalizePlayerName(UnitName(unit)) == normalized then
            local _, class = UnitClass(unit)
            return class
        end
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local class = classFromUnit("raid" .. i)
            if class then
                GemOrderDB.playerClasses[normalized] = class
                return class
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local class = classFromUnit("party" .. i)
            if class then
                GemOrderDB.playerClasses[normalized] = class
                return class
            end
        end
    end

    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, classDisplayName, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if name and NormalizePlayerName(name) == normalized then
                local class = ClassFromGuildRosterInfo(name, classDisplayName, classFileName)
                if class then
                    GemOrderDB.playerClasses[normalized] = class
                end
                return class
            end
        end
    end

    return nil
end

function GemOrder_GetClassColor(classToken)
    if not classToken or not RAID_CLASS_COLORS or not RAID_CLASS_COLORS[classToken] then
        return "ffffff"
    end

    local classColor = RAID_CLASS_COLORS[classToken]
    local colorStr = classColor.colorStr
    if type(colorStr) == "string" then
        colorStr = colorStr:lower()
        if #colorStr == 8 then
            return colorStr:sub(3, 8)
        end
        if #colorStr == 6 then
            return colorStr
        end
    end

    if classColor.r and classColor.g and classColor.b then
        return string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
    end

    return "ffffff"
end

function GemOrder_ColorizePlayer(name, classToken)
    classToken = classToken or GemOrder_GetPlayerClassToken(name)
    local color = GemOrder_GetClassColor(classToken)
    return string.format("|cff%s%s|r", color, name or "")
end

function GemOrder_IsValidRole(role)
    for _, valid in ipairs(GemOrder_ROLES) do
        if valid == role then
            return true
        end
    end
    return false
end

function GemOrder_CreateOrder(gear, gems, notes, role)
    local player = UnitName("player")
    if not player then
        return nil, "Not logged in."
    end
    if not IsInGuild() then
        return nil, "You must be in a guild to place orders."
    end

    local roomId = GemOrder_GetActiveRoomId()
    local room = GemOrder_GetActiveRoom()
    if not roomId or not room then
        return nil, "Select a workshop before placing an order."
    end
    if not GemOrder_IsRoomMember(room, player) then
        return nil, "Select the active workshop before placing an order."
    end

    if not gear or type(gear) ~= "table" or not gear.name or not gear.itemId then
        return nil, "Select gear from the list."
    end
    if not GemOrder_GetGearByName(gear.name) then
        return nil, "Select a valid gear item."
    end

    local filteredGems = {}
    for _, gem in ipairs(gems or {}) do
        if gem and gem ~= "" and gem ~= "None" then
            table.insert(filteredGems, gem)
        end
    end
    if #filteredGems == 0 then
        return nil, "Select at least one gem."
    end

    role = role or ""
    if not GemOrder_IsValidRole(role) then
        return nil, "Select a role."
    end

    local _, classToken = UnitClass("player")
    local order = {
        id = GemOrder.Sync:GenerateOrderId(),
        player = player,
        class = classToken,
        item = gear.name,
        itemLink = "item:" .. gear.itemId,
        itemId = gear.itemId,
        gems = filteredGems,
        notes = notes,
        role = role,
        status = "pending",
        created = time(),
        roomId = roomId,
    }

    GemOrderDB.orders[order.id] = order
    GemOrder_AppendOrderToQueue(roomId, order.id)
    GemOrder.Sync:BroadcastOrder(order)
    return order
end

function GemOrder_UpdateStatus(orderId, status)
    local order = GemOrderDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    order.status = status
    order.updatedBy = UnitName("player")
    order.updatedAt = time()
    if status == "in_progress" then
        order.assignedTo = UnitName("player")
    end
    GemOrder.Sync:BroadcastStatus(orderId, status, order.updatedBy, order.assignedTo)
    return true
end

function GemOrder_CancelOrder(orderId)
    local order = GemOrderDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    local player = UnitName("player")
    if order.player ~= player and not GemOrder_CanManageOrder(order) then
        return false, "You can only cancel your own orders."
    end

    order.status = "cancelled"
    GemOrder_RemoveOrderFromQueue(order.roomId, orderId)
    GemOrder.Sync:BroadcastStatus(orderId, "cancelled", player)
    return true
end

function GemOrder_DeleteOrder(orderId)
    local order = GemOrderDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    local room = order.roomId and GemOrder_GetRoom(order.roomId)
    if not GemOrder_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can delete orders."
    end

    GemOrder_RemoveOrderFromQueue(order.roomId, orderId)
    GemOrderDB.orders[orderId] = nil
    GemOrder.Sync:BroadcastRemove(orderId)
    if order.roomId and room then
        GemOrder.Sync:BroadcastOrderQueue(order.roomId, GemOrder_GetRoomOrderQueue(room))
    end
    return true
end

function GemOrder_GetRoomOrderQueue(room)
    if not room then
        return {}
    end
    room.orderQueue = room.orderQueue or {}
    return room.orderQueue
end

function GemOrder_AppendOrderToQueue(roomId, orderId)
    local room = GemOrder_GetRoom(roomId)
    if not room or not orderId then
        return
    end
    local queue = GemOrder_GetRoomOrderQueue(room)
    for _, id in ipairs(queue) do
        if id == orderId then
            return
        end
    end
    table.insert(queue, orderId)
end

function GemOrder_RemoveOrderFromQueue(roomId, orderId)
    local room = GemOrder_GetRoom(roomId)
    if not room or not orderId then
        return
    end
    local queue = GemOrder_GetRoomOrderQueue(room)
    for i, id in ipairs(queue) do
        if id == orderId then
            table.remove(queue, i)
            break
        end
    end
end

function GemOrder_SyncQueueWithOrders(room)
    if not room then
        return
    end
    local queue = GemOrder_GetRoomOrderQueue(room)
    local known = {}
    for _, id in ipairs(queue) do
        known[id] = true
    end

    local toAdd = {}
    for _, order in pairs(GemOrderDB.orders or {}) do
        if order.roomId == room.id and order.status ~= "cancelled" and order.status ~= "completed" then
            if not known[order.id] then
                table.insert(toAdd, order.id)
            end
        end
    end
    table.sort(toAdd, function(a, b)
        return (GemOrderDB.orders[a].created or 0) < (GemOrderDB.orders[b].created or 0)
    end)
    for _, id in ipairs(toAdd) do
        table.insert(queue, id)
    end

    local cleaned = {}
    for _, id in ipairs(queue) do
        local order = GemOrderDB.orders[id]
        if order and order.roomId == room.id and order.status ~= "cancelled" then
            table.insert(cleaned, id)
        end
    end
    room.orderQueue = cleaned
end

local function GetQueueIndex(room, orderId)
    if not room or not room.orderQueue then
        return nil
    end
    for i, id in ipairs(room.orderQueue) do
        if id == orderId then
            return i
        end
    end
    return nil
end

function GemOrder_MoveOrder(orderId, direction)
    local room = GemOrder_GetActiveRoom()
    if not room then
        return false, "Select a workshop first."
    end
    if not GemOrder_IsWorkshopJC(room, UnitName("player")) then
        return false, "Only workshop JCs can reorder the queue."
    end

    GemOrder_SyncQueueWithOrders(room)
    local queue = room.orderQueue
    local index
    for i, id in ipairs(queue) do
        if id == orderId then
            index = i
            break
        end
    end
    if not index then
        return false, "Order not in queue."
    end

    local order = GemOrderDB.orders[orderId]
    if not order or order.status == "completed" or order.status == "cancelled" then
        return false, "Cannot reorder that order."
    end

    local newIndex = index + direction
    if newIndex < 1 or newIndex > #queue then
        return false, "Already at the edge of the queue."
    end

    local otherId = queue[newIndex]
    local otherOrder = GemOrderDB.orders[otherId]
    if not otherOrder or otherOrder.status == "completed" or otherOrder.status == "cancelled" then
        return false, "Cannot swap with that order."
    end

    queue[index], queue[newIndex] = queue[newIndex], queue[index]
    GemOrder.Sync:BroadcastOrderQueue(room.id, queue)
    return true
end

local function CollectSortedOrders(mode)
    if not GemOrder_HasJoinedWorkshop() then
        return {}
    end
    local room = GemOrder_GetActiveRoom()
    if room then
        GemOrder_SyncQueueWithOrders(room)
    end

    local list = {}
    local activeRoomId = GemOrder_GetActiveRoomId()
    for _, order in pairs(GemOrderDB.orders or {}) do
        if order.status ~= "cancelled" then
            if not activeRoomId or order.roomId == activeRoomId then
                if mode == "active" and order.status == "completed" then
                    -- skip
                elseif mode == "completed" and order.status ~= "completed" then
                    -- skip
                else
                    table.insert(list, order)
                end
            end
        end
    end

    if mode == "completed" then
        table.sort(list, function(a, b)
            return (a.created or 0) > (b.created or 0)
        end)
        return list
    end

    local rank = { pending = 1, in_progress = 2 }
    table.sort(list, function(a, b)
        local ra = rank[a.status] or 9
        local rb = rank[b.status] or 9
        if ra ~= rb then
            return ra < rb
        end
        if room then
            local ia = GetQueueIndex(room, a.id) or 9999
            local ib = GetQueueIndex(room, b.id) or 9999
            if ia ~= ib then
                return ia < ib
            end
        end
        return (a.created or 0) < (b.created or 0)
    end)
    return list
end

function GemOrder_GetSortedOrders()
    return CollectSortedOrders("active")
end

function GemOrder_GetActiveOrders()
    return CollectSortedOrders("active")
end

function GemOrder_GetCompletedOrders()
    return CollectSortedOrders("completed")
end

local function After(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
        return
    end
    local timer = CreateFrame("Frame")
    local elapsed = 0
    timer:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            fn()
        end
    end)
end

local function OnAddonLoaded(_, addon)
    if addon ~= ADDON_NAME then
        return
    end

    MigrateSavedData()

    local ok, err = pcall(function()
        GemOrder.Sync:Init()
        GemOrder_TooltipsInit()
        GemOrder.Minimap:Init()
    end)
    if not ok then
        print("|cffff0000GemOrder minimap/sync error:|r " .. tostring(err))
    end

    if GemOrder.Minimap.button then
        print("|cff00ccffGemOrder|r loaded. Click the gem icon on your minimap, or type |cff00ccff/gemorder|r.")
    else
        print("|cffff0000GemOrder failed to load.|r Check chat for errors.")
    end
end

local function TryGuildSync()
    if not IsInGuild() or not GemOrder_GetGuildName() then
        return false
    end

    if GuildRoster then
        GuildRoster()
    end

    GemOrder_PurgeNonGuildData()
    GemOrder.Sync:BroadcastAllRooms()
    GemOrder.Sync:RequestSync()

    if GemOrder_HasJoinedWorkshop() then
        GemOrder_ScanBagsForGems()
        GemOrder_ScanPersonalBankForGems()
        if GemOrder_ShouldShareStock() then
            GemOrder_ShareWorkshopStock()
        end
    end

    if GemOrder.UI and GemOrder.UI.frame then
        GemOrder.UI:Refresh()
    end

    return true
end

local function OnPlayerLogin()
    if not GemOrder.Minimap.button then
        pcall(function() GemOrder.Minimap:Init() end)
    end

    After(1, function()
        TryGuildSync()
    end)
    After(5, function()
        TryGuildSync()
    end)
end

local function OnGuildReady()
    TryGuildSync()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("GUILD_ROSTER_UPDATE")
boot:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(event, arg1)
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "GUILD_ROSTER_UPDATE" then
        OnGuildReady()
        if GemOrder.UI and GemOrder.UI.frame then
            GemOrder.UI:Refresh()
        end
    end
end)
