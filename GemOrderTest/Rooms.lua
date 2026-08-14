GemOrderTest = GemOrderTest or {}

local function EnsureDB()
    GemOrderTestDB = GemOrderTestDB or {}
    GemOrderTestDB.rooms = GemOrderTestDB.rooms or {}
    GemOrderTestDB.settings = GemOrderTestDB.settings or { jcMode = false }
end

function GemOrderTest_GetGuildName()
    if not IsInGuild() then
        return nil
    end
    return GetGuildInfo("player")
end

function GemOrderTest_IsSameGuild(room)
    if not room then
        return false
    end
    local guild = GemOrderTest_GetGuildName()
    if not guild then
        return false
    end
    if not room.guild then
        return true
    end
    return room.guild == guild
end

function GemOrderTest_HasJoinedWorkshop()
    if not IsInGuild() then
        return false
    end
    local room = GemOrderTest_GetActiveRoom()
    if not room or not room.open then
        return false
    end
    if not GemOrderTest_IsSameGuild(room) then
        return false
    end
    return GemOrderTest_IsRoomMember(room, UnitName("player"))
end

function GemOrderTest_ValidateActiveRoom()
    EnsureDB()
    if not GemOrderTest_HasJoinedWorkshop() then
        GemOrderTestDB.settings.activeRoomId = nil
    end
end

function GemOrderTest_PurgeNonGuildData()
    EnsureDB()
    local guild = GemOrderTest_GetGuildName()
    if not guild then
        return
    end

    for id, room in pairs(GemOrderTestDB.rooms) do
        if room.guild and room.guild ~= guild then
            GemOrderTestDB.rooms[id] = nil
        end
    end

    for id, order in pairs(GemOrderTestDB.orders) do
        local room = order.roomId and GemOrderTestDB.rooms[order.roomId]
        if not room or not GemOrderTest_IsSameGuild(room) then
            GemOrderTestDB.orders[id] = nil
        end
    end

    GemOrderTest_ValidateActiveRoom()
end

function GemOrderTest_GetActiveRoomId()
    EnsureDB()
    return GemOrderTestDB.settings.activeRoomId
end

function GemOrderTest_GetActiveRoom()
    local roomId = GemOrderTest_GetActiveRoomId()
    if not roomId then
        return nil
    end
    return GemOrderTestDB.rooms[roomId]
end

function GemOrderTest_GetRoom(roomId)
    EnsureDB()
    return roomId and GemOrderTestDB.rooms[roomId]
end

function GemOrderTest_GetOpenRooms()
    EnsureDB()
    if not IsInGuild() then
        return {}
    end
    local list = {}
    for _, room in pairs(GemOrderTestDB.rooms) do
        if room.open and GemOrderTest_IsSameGuild(room) then
            table.insert(list, room)
        end
    end
    table.sort(list, function(a, b)
        return (a.created or 0) > (b.created or 0)
    end)
    return list
end

function GemOrderTest_IsRoomMember(room, player)
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

function GemOrderTest_IsRoomCollaborator(room, player)
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

function GemOrderTest_IsRoomLeader(room, player)
    return room and player and room.leader == player
end

function GemOrderTest_IsRoomCoLeader(room, player)
    return room and player and room.coLeaders and room.coLeaders[player] == true
end

function GemOrderTest_IsWorkshopOwner(room, player)
    return GemOrderTest_IsRoomLeader(room, player)
end

function GemOrderTest_CanManageWorkshop(room, player)
    if not room or not player then
        return false
    end
    return room.leader == player or GemOrderTest_IsRoomCoLeader(room, player)
end

function GemOrderTest_CanManageOrder(order)
    if not order then
        return false
    end
    local player = UnitName("player")
    if order.roomId then
        local room = GemOrderTest_GetRoom(order.roomId)
        return GemOrderTest_IsRoomCollaborator(room, player)
    end
    return false
end

function GemOrderTest_CreateWorkshop(name)
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
        guild = GemOrderTest_GetGuildName(),
        collaborators = {},
        coLeaders = {},
        members = { [player] = true },
        orderQueue = {},
        created = time(),
        open = true,
    }

    GemOrderTestDB.rooms[room.id] = room
    GemOrderTestDB.settings.activeRoomId = room.id
    GemOrderTest.Sync:BroadcastRoom(room)
    GemOrderTest.Sync:BroadcastJoin(room.id, player)
    if GemOrderTest_ShouldShareStock() then
        GemOrderTest_RefreshLocalStock()
    end
    return room
end

function GemOrderTest_JoinWorkshop(roomId)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local room = GemOrderTestDB.rooms[roomId]
    if not room or not room.open then
        return nil, "Workshop not found or closed."
    end
    if not GemOrderTest_IsSameGuild(room) then
        return nil, "That workshop belongs to another guild."
    end

    local player = UnitName("player")
    room.members[player] = true
    GemOrderTestDB.settings.activeRoomId = room.id
    GemOrderTest.Sync:BroadcastJoin(room.id, player)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            GemOrderTest.Sync:RequestSync()
        end)
    else
        GemOrderTest.Sync:RequestSync()
    end
    return room
end

function GemOrderTest_DeselectWorkshop()
    EnsureDB()
    if not GemOrderTestDB.settings.activeRoomId then
        return nil, "No workshop selected."
    end

    GemOrderTestDB.settings.activeRoomId = nil
    return true
end

function GemOrderTest_LeaveWorkshop()
    EnsureDB()
    local roomId = GemOrderTestDB.settings.activeRoomId
    if not roomId then
        return nil, "No workshop selected."
    end

    local room = GemOrderTestDB.rooms[roomId]
    local player = UnitName("player")
    if room and room.members then
        room.members[player] = nil
    end
    GemOrderTestDB.settings.activeRoomId = nil
    GemOrderTest.Sync:BroadcastLeave(roomId, player)
    return true
end

function GemOrderTest_CloseWorkshop(roomId)
    EnsureDB()
    local room = GemOrderTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrderTest_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can close it."
    end

    room.open = false
    if GemOrderTestDB.settings.activeRoomId == roomId then
        GemOrderTestDB.settings.activeRoomId = nil
    end
    GemOrderTest.Sync:BroadcastRoom(room)
    return true
end

function GemOrderTest_AddCollaborator(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GemOrderTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrderTest_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can promote jewelcrafters."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.collaborators = room.collaborators or {}
    room.collaborators[playerName] = true
    GemOrderTest.Sync:BroadcastCollaborator(roomId, "add", playerName)
    return true
end

function GemOrderTest_PromoteMember(roomId, playerName)
    return GemOrderTest_AddCollaborator(roomId, playerName)
end

function GemOrderTest_AddCoLeader(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GemOrderTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrderTest_IsWorkshopOwner(room, UnitName("player")) then
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
    GemOrderTest.Sync:BroadcastCoLeader(roomId, "add", playerName)
    return true
end

function GemOrderTest_RemoveCoLeader(roomId, playerName)
    EnsureDB()
    local room = GemOrderTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrderTest_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can demote co-leaders."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = nil
    GemOrderTest.Sync:BroadcastCoLeader(roomId, "remove", playerName)
    return true
end

function GemOrderTest_DemoteCollaborator(roomId, playerName)
    return GemOrderTest_RemoveCollaborator(roomId, playerName)
end

function GemOrderTest_GetRoomMembers(room)
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

function GemOrderTest_GetSortedRoomMembers(room)
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

function GemOrderTest_IsPromotedJewelcrafter(room, player)
    if not room or not player then
        return false
    end
    return room.collaborators and room.collaborators[player] == true
end

function GemOrderTest_GetWorkshopStockContributors(room)
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

function GemOrderTest_GetWorkshopJCNames(room)
    return GemOrderTest_GetWorkshopStockContributors(room)
end

function GemOrderTest_IsWorkshopJC(room, player)
    return GemOrderTest_IsRoomCollaborator(room, player)
end

function GemOrderTest_ShouldShareStock()
    local room = GemOrderTest_GetActiveRoom()
    if not room then
        return false
    end
    return GemOrderTest_IsPromotedJewelcrafter(room, UnitName("player"))
end

function GemOrderTest_AcceptsWorkshopStockReport(room, player)
    return GemOrderTest_IsPromotedJewelcrafter(room, player)
end

function GemOrderTest_RemoveCollaborator(roomId, playerName)
    EnsureDB()
    local room = GemOrderTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GemOrderTest_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can remove jewelcrafters."
    end

    room.collaborators[playerName] = nil
    GemOrderTest.Sync:BroadcastCollaborator(roomId, "remove", playerName)
    return true
end

function GemOrderTest_ApplyRoom(room)
    EnsureDB()
    if not room or not room.id then
        return
    end
    GemOrderTestDB.rooms[room.id] = room
    if GemOrderTest.UI then
        GemOrderTest.UI:Refresh()
    end
end

