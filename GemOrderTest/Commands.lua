SLASH_GEMORDERTEST1 = "/gotest"
SLASH_GEMORDERTEST2 = "/got"
SLASH_GEMORDERTEST3 = "/gott"

SlashCmdList["GEMORDERTEST"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "stock" then
        GemOrderTest_RefreshLocalStock()
        print("|cff00ccffGemOrderTest|r Gem stock refreshed for " .. UnitName("player") .. ".")
        return
    end

    if msg == "sync" then
        if IsInGuild() then
            GemOrderTest.Sync:RequestSync()
            print("|cff00ccffGemOrderTest|r Requested sync from guild.")
        else
            print("|cff00ccffGemOrderTest|r You are not in a guild.")
        end
        return
    end

    if msg:match("^debug") then
        if GemOrderTest.Debug then
            GemOrderTest.Debug:HandleCommand(strtrim(msg:sub(7)))
        else
            print("|cffff0000GemOrderTest|r Debug module not loaded.")
        end
        return
    end

    if msg:match("^join ") then
        local roomId = strtrim(msg:sub(6))
        local _, err = GemOrderTest_JoinWorkshop(roomId)
        if err then
            print("|cff00ccffGemOrderTest|r " .. err)
        else
            print("|cff00ccffGemOrderTest|r Selected workshop.")
            if GemOrderTest.UI and GemOrderTest.UI.frame then
                GemOrderTest.UI:Refresh()
            end
        end
        return
    end

    GemOrderTest_EnsureUI()
    GemOrderTest.UI:Toggle()
end

