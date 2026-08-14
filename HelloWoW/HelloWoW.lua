local ADDON_NAME, HelloWoW = ...

HelloWoWDB = HelloWoWDB or {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        HelloWoWDB.loginCount = (HelloWoWDB.loginCount or 0) + 1
        print(string.format(
            "|cff00ff00HelloWoW|r loaded! Login #%d. Type |cff00ff00/hellowow|r for info.",
            HelloWoWDB.loginCount
        ))
    end
end)

SLASH_HELLOWOW1 = "/hellowow"
SlashCmdList["HELLOWOW"] = function()
    print(string.format(
        "|cff00ff00HelloWoW|r v1.0.0 — you've logged in %d time(s) with this addon.",
        HelloWoWDB.loginCount or 0
    ))
end
