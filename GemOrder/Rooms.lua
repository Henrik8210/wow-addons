GemOrder = GemOrder or {}

local function EnsureDB()
    GemOrderDB = GemOrderDB or {}
    GemOrderDB.rooms = GemOrderDB.rooms or {}
    GemOrderDB.settings = GemOrderDB.settings or { jcMode = false }
end

function GemOrder_GetGuildName()
    if not IsInGuild() then
        return nil
    end
    return GetGuildInfo("player")
end

function GemOrder_IsSameGuild(room)
    if not room then
        return false
    end
    local guild = GemOrder_GetGuildName()
    if not guild then
        return false
    end
    if not room.guild then
        return true
    end
    return room.guild == guild
end

function GemOrder_HasJoinedWorkshop()
    if not IsInGuild() then
        return false
    end
    local room = GemOrder_GetActiveRoom()
    if not room or not room.open then
        return false
    end
    if not GemOrder_IsSameGuild(room) then
        return false
    end
    return GemOrder_IsRoomMember(room, UnitName("player"))
end

function GemOrder_ValidateActiveRoom()
    EnsureDB()
    if not GemOrder_HasJoinedWorkshop() then
        GemOrderDB.settings.activeRoomId = nil
    end
end

function GemOrder_PurgeNonGuildData()
    EnsureDB()
    local guild = GemOrder_GetGuildName()
    if not guild then
        return
    end

    for id, room in pairs(GemOrderDB.rooms) do
        if room.guild and room.guild ~= guild then
            GemOrderDB.rooms[id] = nil
        end
    end

    for id, order in pairs(GemOrderDB.orders) do
        local room = order.roomId and GemOrderDB.rooms[order.roomId]
        if not room or not GemOrder_IsSameGuild(room) then
            GemOrderDB.orders[id] = nil
        end
    end

    GemOrder_ValidateActiveRoom()
end

function GemOrder_GetActiveRoomId()
    EnsureDB()
    return GemOrderDB.settings.activeRoomId
end

function GemOrder_GetActiveRoom()
    local roomId = GemOrder_GetActiveRoomId()
    if not roomId then
        return nil
    end
    return GemOrderDB.rooms[roomId]
end

function GemOrder_GetRoom(roomId)
    EnsureDB()
    return roomId and GemOrderDB.rooms[roomId]
end

function GemOrder_GetOpenRooms()
    EnsureDB()
    if not IsInGuild() then
        return {}
    end
    local list = {}
    for _, room in pairs(GemOrderDB.rooms) do
        if room.open and GemOrder_IsSameGuild(room) then
            table.insert(list, room)
        end
    end
    table.sort(list, function(a, b)
        return (a.created or 0) > (b.created or 0)
    end)
    return list
end

function GemOrder_IsRoomMember(room, player)
    if not room or not player then
        return false
    end
    if room.leader == player then
        return true
    end
    if room.coLeaders and room.coLeaders[player] then
        return true
    end
    return room.members and room.members[player] == true
end

function GemOrder_IsRoomCollaborator(room, player)
    if not room or not player then
        return false
    end
    if room.leader == player then
        return true
    end
    if room.coLeaders and room.coLeaders[player] then
        return true
    end
    return room.collaborators and room.collaborators[player] == true
end

function GemOrder_IsRoomLeader(room, player)
    return room and player and room.leader == player
end

function GemOrder_IsRoomCoLeader(room, player)
    return room and player and room.coLeaders and room.coLeaders[player] == true
end

function GemOrder_IsWorkshopOwner(room, player)
    return GemOrder_IsRoomLeader(room, player)
end

function GemOrder_CanManageWorkshop(room, player)
    if not room or not player then
        return false
    end
    return room.leader == player or GemOrder_IsRoomCoLeader(room, player)
end

function GemOrder_CanManageOrder(order)
    if not order then
        return false
    end
    local player = UnitName("player")
    if order.roomId then
        local room = GemOrder_GetRoom(order.roomId)
        return GemOrder_IsRoomCollaborator(room, player)
    end
    return false
end

function GemOrder_CreateWorkshop(name)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    name = strtrim(name or "")
    if name == "" then
        return nil, "Enter a workshop name."
    end

    local player = UnitName("player")
    local room = {
        id = string.format("%s-%d", player, time()),
        name = name,
        leader = player,
        guild = GemOrder_GetGuildName(),
        collaborators = {},
        coLeaders = {},
        members = { [player] = true },
        orderQueue = {},
        created = time(),
        open = true,
    }

    GemOrderDB.rooms[room.id] = room
    GemOrderDB.settings.activeRoomId = room.id
    GemOrder.Sync:BroadcastRoom(room)
    GemOrder.Sync:BroadcastJoin(room.id, player)
    if GemOrder_ShouldShareStock() then
        GemOrder_RefreshLocalStock()
    end
    return room
end

function GemOrder_JoinWorkshop(roomId)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local room = GemOrderDB.rooms[roomId]
    if not room or not room.open then
        return nil, "Workshop not found or closed."
    end
    if not GemOrder_IsSameGuild(room) then
        return nil, "That workshop belongs to another guild."
    end

    local player = UnitName("player")
    room.members[player] = true
    GemOrderDB.settings.activeRoomId = room.id
    GemOrder.Sync:BroadcastJoin(room.id, player)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            GemOrder.Sync:RequestSync()
        end)
    else
        GemOrder.Sync:RequestSync()
    end
    return room
end

function GemOrder_DeselectWorkshop()
    EnsureDB()
    if not GemOrderDB.settings.activeRoomId then
        return nil, "No workshop selected."
    end

    GemOrderDB.settings.activeRoomId = nil
    return true
end

function GemOrder_LeaveWorkshop()
    EnsureDB()
    local roomId = GemOrderDB.settings.activeRoomId
    if not roomId then
        return nil, "No workshop selected."
    end

    local room = GemOrderDB.rooms[roomId]
    local player = UnitName("player")
    if room and room.members then
        room.members[player] = nil
    end
    GemOrderDB.settings.activeRoomId = nil
    GemOrder.Sync:BroadcastLeave(roomId, player)
    return true
end

function GemOrder_CloseWorkshop(roomId)
    EnsureDB()
    local room = GemOrderDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrder_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can close it."
    end

    room.open = false
    if GemOrderDB.settings.activeRoomId == roomId then
        GemOrderDB.settings.activeRoomId = nil
    end
    GemOrder.Sync:BroadcastRoom(room)
    return true
end

function GemOrder_AddCollaborator(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GemOrderDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrder_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can promote jewelcrafters."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.collaborators = room.collaborators or {}
    room.collaborators[playerName] = true
    GemOrder.Sync:BroadcastCollaborator(roomId, "add", playerName)
    return true
end

function GemOrder_PromoteMember(roomId, playerName)
    return GemOrder_AddCollaborator(roomId, playerName)
end

function GemOrder_AddCoLeader(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GemOrderDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrder_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can promote co-leaders."
    end
    if playerName == room.leader then
        return false, "The workshop leader is already in charge."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = true
    room.members[playerName] = true
    GemOrder.Sync:BroadcastCoLeader(roomId, "add", playerName)
    return true
end

function GemOrder_RemoveCoLeader(roomId, playerName)
    EnsureDB()
    local room = GemOrderDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrder_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can demote co-leaders."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = nil
    GemOrder.Sync:BroadcastCoLeader(roomId, "remove", playerName)
    return true
end

function GemOrder_DemoteCollaborator(roomId, playerName)
    return GemOrder_RemoveCollaborator(roomId, playerName)
end

function GemOrder_GetRoomMembers(room)
    local members = {}
    if not room or not room.members then
        return members
    end
    for name in pairs(room.members) do
        table.insert(members, name)
    end
    table.sort(members)
    return members
end

function GemOrder_GetSortedRoomMembers(room)
    local coLeaders = {}
    local jewelcrafters = {}
    local members = {}
    if not room or not room.members then
        return {}
    end

    for name in pairs(room.members) do
        if name == room.leader then
            -- leader handled separately
        elseif room.coLeaders and room.coLeaders[name] then
            table.insert(coLeaders, name)
        elseif room.collaborators and room.collaborators[name] then
            table.insert(jewelcrafters, name)
        else
            table.insert(members, name)
        end
    end

    table.sort(coLeaders)
    table.sort(jewelcrafters)
    table.sort(members)

    local sorted = {}
    if room.leader then
        table.insert(sorted, room.leader)
    end
    for _, name in ipairs(coLeaders) do
        table.insert(sorted, name)
    end
    for _, name in ipairs(jewelcrafters) do
        table.insert(sorted, name)
    end
    for _, name in ipairs(members) do
        table.insert(sorted, name)
    end
    return sorted
end

function GemOrder_IsPromotedJewelcrafter(room, player)
    if not room or not player then
        return false
    end
    return room.collaborators and room.collaborators[player] == true
end

function GemOrder_GetWorkshopStockContributors(room)
    local names = {}
    if not room then
        return names
    end
    for name in pairs(room.collaborators or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function GemOrder_GetWorkshopJCNames(room)
    return GemOrder_GetWorkshopStockContributors(room)
end

function GemOrder_IsWorkshopJC(room, player)
    return GemOrder_IsRoomCollaborator(room, player)
end

function GemOrder_ShouldShareStock()
    local room = GemOrder_GetActiveRoom()
    if not room then
        return false
    end
    return GemOrder_IsPromotedJewelcrafter(room, UnitName("player"))
end

function GemOrder_AcceptsWorkshopStockReport(room, player)
    return GemOrder_IsPromotedJewelcrafter(room, player)
end

function GemOrder_RemoveCollaborator(roomId, playerName)
    EnsureDB()
    local room = GemOrderDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrder_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can remove jewelcrafters."
    end

    room.collaborators[playerName] = nil
    GemOrder.Sync:BroadcastCollaborator(roomId, "remove", playerName)
    return true
end

function GemOrder_ApplyRoom(room)
    EnsureDB()
    if not room or not room.id then
        return
    end
    GemOrderDB.rooms[room.id] = room
    if GemOrder.UI then
        GemOrder_RefreshUI()
    end
end
