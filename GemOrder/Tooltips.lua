GemOrder = GemOrder or {}
GemOrder._loggingOut = false

function GemOrder_IsLoggingOut()
    return GemOrder._loggingOut == true
end

function GemOrder_PrepareForLogout()
    GemOrder._loggingOut = true

    if UISpecialFrames then
        for i = #UISpecialFrames, 1, -1 do
            local entry = UISpecialFrames[i]
            if entry == "GemOrderFrame" or entry == "GemOrderOrderDialog" then
                tremove(UISpecialFrames, i)
            end
        end
    end

    local ui = GemOrder.UI
    if not ui or not ui.frame then
        return
    end

    local f = ui.frame
    f:SetScript("OnHide", nil)
    f:SetScript("OnMouseDown", nil)

    if f.queueInset then
        f.queueInset:SetScript("OnMouseDown", nil)
    end
    if f.workshopPanel then
        f.workshopPanel:SetScript("OnMouseDown", nil)
    end
    if f.stockPanel then
        f.stockPanel:SetScript("OnMouseDown", nil)
    end
    if f.recipesPanel then
        f.recipesPanel:SetScript("OnMouseDown", nil)
    end

    if f.orderDialog then
        f.orderDialog:SetScript("OnHide", nil)
        if f.orderDialog.panel then
            f.orderDialog.panel:SetScript("OnMouseDown", nil)
        end
        if f.orderDialog.inset then
            f.orderDialog.inset:SetScript("OnMouseDown", nil)
        end
        if f.orderDialogOverlay then
            f.orderDialogOverlay:SetScript("OnMouseDown", nil)
            f.orderDialogOverlay:Hide()
        end
        f.orderDialog:Hide()
    end

    f:Hide()
end

function GemOrder_ShowItemTooltip(owner, itemId, anchor)
    if not itemId or not owner then
        return
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. itemId)
    if GameTooltip.SetClampedToScreen then
        GameTooltip:SetClampedToScreen(true)
    end
    GameTooltip:Show()
end

function GemOrder_ShowDropdownItemTooltip(itemId)
    if not itemId then
        return
    end
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 16, y / scale)
    GameTooltip:SetHyperlink("item:" .. itemId)
    if GameTooltip.SetClampedToScreen then
        GameTooltip:SetClampedToScreen(true)
    end
    GameTooltip:Show()
end

function GemOrder_ShowLinkTooltip(owner, link, anchor)
    if not link or not owner then
        return
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    if GameTooltip.SetClampedToScreen then
        GameTooltip:SetClampedToScreen(true)
    end
    GameTooltip:Show()
end

function GemOrder_HideTooltip()
    GameTooltip:Hide()
end

function GemOrder_RegisterEscapeFrame(frame)
    if not frame or not UISpecialFrames then
        return
    end
    if GemOrder.Debug and GemOrder.Debug.ShouldSkipUISpecialFrames
        and GemOrder.Debug:ShouldSkipUISpecialFrames() then
        return
    end

    local name = frame.GetName and frame:GetName()
    if not name or name == "" then
        return
    end

    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == name then
            return
        end
    end

    tinsert(UISpecialFrames, name)
end

function GemOrder_GetGemItemId(gemName)
    if not gemName or gemName == "None" then
        return nil
    end
    local gem = GemOrder_GemByName and GemOrder_GemByName[gemName]
    return gem and gem.itemId
end

function GemOrder_ExtractItemLink(text)
    if not text or text == "" then
        return nil
    end
    local link = text:match("(|c.-|Hitem:[%-%d:]+|h%[.-]|h|r)")
    if link then
        return link
    end
    link = text:match("(|Hitem:[%-%d:]+|h%[.-]|h)")
    if link then
        return link
    end
    local itemId = text:match("^item:(%d+)")
    if itemId then
        return "item:" .. itemId
    end
    return nil
end

function GemOrder_ExtractItemId(text)
    local link = GemOrder_ExtractItemLink(text)
    if not link then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

function GemOrder_GetItemDisplayText(text)
    local link = GemOrder_ExtractItemLink(text)
    if link then
        local name = GetItemInfo(link)
        if name then
            return name
        end
    end
    return text
end

function GemOrder_TooltipsInit()
    GemOrder.itemLinkTarget = nil
end

function GemOrder_AttachItemTooltip(frame, getLinkFn)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local link = getLinkFn(self)
        if link then
            if type(link) == "number" then
                GemOrder_ShowItemTooltip(self, link)
            else
                GemOrder_ShowLinkTooltip(self, link)
            end
        end
    end)
    frame:SetScript("OnLeave", GemOrder_HideTooltip)
end

local function StripColorCodes(text)
    if not text then
        return nil
    end
    return text:gsub("|c%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function GetDropdownButtonText(button)
    if not button or not button.GetName then
        return nil
    end
    local textFrame = _G[button:GetName() .. "NormalText"]
    if textFrame and textFrame.GetText then
        return StripColorCodes(textFrame:GetText())
    end
    if button.GetText then
        return StripColorCodes(button:GetText())
    end
    return nil
end

local function LookupItemIdByDisplayText(text)
    if not text or text == "" then
        return nil
    end
    if GemOrder_GemByName and GemOrder_GemByName[text] then
        return GemOrder_GemByName[text].itemId
    end
    if GemOrder_Gear then
        for _, gear in ipairs(GemOrder_Gear) do
            if gear.label == text or gear.name == text then
                return gear.itemId
            end
        end
    end
    return nil
end

local function GetDropdownButtonItemId(button)
    if not button then
        return nil
    end

    local itemId = button.gemOrderItemId
    local index = button.GetID and button:GetID()
    if (not itemId or itemId <= 0) and index and GemOrder._dropdownItemTooltips then
        itemId = GemOrder._dropdownItemTooltips[index]
    end
    if type(itemId) == "number" and itemId > 0 then
        return itemId
    end

    if type(button.value) == "number" and button.value > 0 then
        return button.value
    end

    return LookupItemIdByDisplayText(GetDropdownButtonText(button))
end

local function IsGemOrderItemDropdown(dropdown)
    if not dropdown or not dropdown.GetName then
        return false
    end
    local name = dropdown:GetName() or ""
    return name:match("^GemOrderGearDropdown") ~= nil
        or name:match("^GemOrderGemDropdown") ~= nil
end

local function ClearDropdownListItemIds(level)
    level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
    local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
    for i = 1, maxButtons do
        local button = _G["DropDownList" .. level .. "Button" .. i]
        if button then
            button.gemOrderItemId = nil
        end
    end
end

function GemOrder_BeginDropdownItemTooltips()
    GemOrder._dropdownItemTooltips = {}
    ClearDropdownListItemIds(UIDROPDOWNMENU_MENU_LEVEL or 1)
end

function GemOrder_QueueDropdownItemTooltip(buttonIndex, itemId)
    if not itemId or itemId <= 0 or not buttonIndex then
        return
    end
    GemOrder._dropdownItemTooltips = GemOrder._dropdownItemTooltips or {}
    GemOrder._dropdownItemTooltips[buttonIndex] = itemId
end

function GemOrder_ApplyDropdownItemTooltips(level)
    level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
    local map = GemOrder._dropdownItemTooltips
    if not map or not IsGemOrderItemDropdown(UIDROPDOWNMENU_OPEN_MENU) then
        return
    end

    local function apply()
        if not IsGemOrderItemDropdown(UIDROPDOWNMENU_OPEN_MENU) then
            return
        end
        GemOrder_ElevateDropdownList(level)
        for index, itemId in pairs(map) do
            local button = _G["DropDownList" .. level .. "Button" .. index]
            if button then
                button.gemOrderItemId = itemId
            end
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, apply)
    else
        apply()
    end
end

local function SaveMouseEnabled(frame, storage, key)
    if frame and frame.IsMouseEnabled and frame:IsMouseEnabled() then
        storage[key] = true
        frame:EnableMouse(false)
    end
end

local function RestoreMouseEnabled(frame, storage, key)
    if frame and storage[key] then
        frame:EnableMouse(true)
        storage[key] = nil
    end
end

function GemOrder_ElevateDropdownList(level)
    if not IsGemOrderItemDropdown(UIDROPDOWNMENU_OPEN_MENU) then
        return
    end

    level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
    local list = _G["DropDownList" .. level]
    if not list then
        return
    end

    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(1000)

    if list.gemOrderMouseSaved then
        return
    end

    local saved = {}
    list.gemOrderMouseSaved = saved

    local ui = GemOrder.UI and GemOrder.UI.frame
    if not ui then
        return
    end

    if ui.orderDialogOverlay then
        SaveMouseEnabled(ui.orderDialogOverlay, saved, "overlay")
    end
    if ui.orderDialog and ui.orderDialog.titleBar then
        SaveMouseEnabled(ui.orderDialog.titleBar, saved, "titleBar")
    end
    SaveMouseEnabled(ui, saved, "mainFrame")
end

function GemOrder_RestoreDropdownListMouseBlockers(level)
    level = level or 1
    local list = _G["DropDownList" .. level]
    if not list or not list.gemOrderMouseSaved then
        return
    end

    local saved = list.gemOrderMouseSaved
    local ui = GemOrder.UI and GemOrder.UI.frame
    if ui then
        RestoreMouseEnabled(ui, saved, "mainFrame")
        RestoreMouseEnabled(ui.orderDialogOverlay, saved, "overlay")
        if ui.orderDialog then
            RestoreMouseEnabled(ui.orderDialog.titleBar, saved, "titleBar")
        end
    end
    list.gemOrderMouseSaved = nil
end

function GemOrder_AttachDropdownTooltips(dropdown, getItemIdFn)
    local button = _G[dropdown:GetName() .. "Button"]
    if button then
        GemOrder_AttachItemTooltip(button, function()
            return getItemIdFn()
        end)
    end
end

function GemOrder_HookDropdownMenuTooltips()
    if GemOrder.dropdownTooltipHooked or not hooksecurefunc then
        return
    end
    GemOrder.dropdownTooltipHooked = true

    hooksecurefunc("UIDropDownMenuButton_OnEnter", function(self)
        if not self or not self:IsShown() then
            return
        end
        if not IsGemOrderItemDropdown(UIDROPDOWNMENU_OPEN_MENU) then
            return
        end
        local itemId = GetDropdownButtonItemId(self)
        if itemId then
            GemOrder_ShowDropdownItemTooltip(itemId)
        end
    end)

    hooksecurefunc("UIDropDownMenuButton_OnLeave", function(self)
        if not self or not IsGemOrderItemDropdown(UIDROPDOWNMENU_OPEN_MENU) then
            return
        end
        GemOrder_HideTooltip()
    end)

    if UIDropDownMenu_CreateButtons then
        hooksecurefunc("UIDropDownMenu_CreateButtons", function(level)
            GemOrder_ApplyDropdownItemTooltips(level or UIDROPDOWNMENU_MENU_LEVEL or 1)
        end)
    end

    if ToggleDropDownMenu then
        hooksecurefunc("ToggleDropDownMenu", function(level, _, dropDownFrame)
            if not IsGemOrderItemDropdown(dropDownFrame) then
                return
            end
            local menuLevel = level or 1
            local function elevate()
                GemOrder_ElevateDropdownList(menuLevel)
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, elevate)
            else
                elevate()
            end
        end)
    end

    for i = 1, (UIDROPDOWNMENU_MAXLEVELS or 2) do
        local list = _G["DropDownList" .. i]
        if list then
            if list.HookScript then
                list:HookScript("OnHide", function()
                    GemOrder_RestoreDropdownListMouseBlockers(i)
                end)
            else
                local prior = list:GetScript("OnHide")
                list:SetScript("OnHide", function(...)
                    GemOrder_RestoreDropdownListMouseBlockers(i)
                    if prior then
                        prior(...)
                    end
                end)
            end
        end
    end
end
