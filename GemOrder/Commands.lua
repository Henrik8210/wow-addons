SLASH_GEMORDER1 = "/gemorder"
SLASH_GEMORDER2 = "/gorder"
SLASH_GEMORDER3 = "/gor"

SlashCmdList["GEMORDER"] = function(msg)
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
            GemOrder_RefreshUI()
        end
        return
    end

    if GemOrder_EnsureUI() then
        GemOrder.UI:Toggle()
    end
end
