SLASH_GEMORDER1 = "/gemorder"
SLASH_GEMORDER2 = "/gorder"
SLASH_GEMORDER3 = "/gor"

SlashCmdList["GEMORDER"] = function(msg)
    if not GemOrder or not GemOrder.UI then
        print("|cffff0000GemOrder|r is not loaded yet.")
        return
    end

    msg = string.lower(strtrim(msg or ""))

    if msg == "stock" then
        GemOrder_RefreshLocalStock()
        print("|cff00ccffGemOrder|r Gem stock refreshed for " .. UnitName("player") .. ".")
        return
    end

    if msg == "sync" then
        if IsInGuild() then
            GemOrder.Sync:RequestSync()
            print("|cff00ccffGemOrder|r Requested sync from guild.")
        else
            print("|cff00ccffGemOrder|r You are not in a guild.")
        end
        return
    end

    if msg:match("^debug") then
        if GemOrder.Debug then
            GemOrder.Debug:HandleCommand(strtrim(msg:sub(7)))
        else
            print("|cffff0000GemOrder|r Debug module not loaded.")
        end
        return
    end

    if msg:match("^join ") then
        local roomId = strtrim(msg:sub(6))
        local _, err = GemOrder_JoinWorkshop(roomId)
        if err then
            print("|cff00ccffGemOrder|r " .. err)
        else
            print("|cff00ccffGemOrder|r Selected workshop.")
            GemOrder.UI:Refresh()
        end
        return
    end

    GemOrder.UI:Toggle()
end
