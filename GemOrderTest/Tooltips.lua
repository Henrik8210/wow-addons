GemOrderTest = GemOrder or {}
GemOrderTest._loggingOut = false

function GemOrderTest_IsLoggingOut()
    return GemOrderTest._loggingOut == true
end

function GemOrderTest_PrepareForLogout()
    GemOrderTest._loggingOut = true

    if UISpecialFrames then
        for i = #UISpecialFrames, 1, -1 do
            local entry = UISpecialFrames[i]
            if entry == "GemOrderTestFrame" or entry == "GemOrderTestOrderDialog" then
                tremove(UISpecialFrames, i)
            end
        end
    end

    local ui = GemOrderTest.UI
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

function GemOrderTest_ShowItemTooltip(owner, itemId, anchor)
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

function GemOrderTest_ShowLinkTooltip(owner, link, anchor)
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

function GemOrderTest_HideTooltip()
    GameTooltip:Hide()
end

local function ResolveItemLink(itemIdOrLink)
    if not itemIdOrLink then
        return nil
    end

    if type(itemIdOrLink) == "string" then
        if itemIdOrLink:find("|Hitem:") then
            return itemIdOrLink
        end
        local itemId = tonumber(itemIdOrLink:match("item:(%d+)"))
        if itemId then
            itemIdOrLink = itemId
        else
            return nil
        end
    end

    if type(itemIdOrLink) ~= "number" or itemIdOrLink <= 0 then
        return nil
    end

    local _, link = GetItemInfo(itemIdOrLink)
    if link then
        return link
    end

    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetHyperlink("item:" .. itemIdOrLink)
    GameTooltip:Hide()
    _, link = GetItemInfo(itemIdOrLink)
    return link
end

function GemOrderTest_InsertChatItemLink(itemIdOrLink)
    local link = ResolveItemLink(itemIdOrLink)
    if not link then
        return false
    end

    if HandleModifiedItemClick and HandleModifiedItemClick(link) then
        return true
    end

    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then
        return true
    end

    local editBox = ChatFrame1EditBox
    if editBox and editBox:IsShown() then
        editBox:Insert(link)
        editBox:SetFocus()
        return true
    end

    if ChatFrame_OpenChat then
        ChatFrame_OpenChat("")
        editBox = ChatFrame1EditBox
        if editBox then
            editBox:Insert(link)
            editBox:SetFocus()
            return true
        end
    end

    return false
end

local function IsShiftChatLinkClick(button)
    if button ~= "LeftButton" and button ~= "LeftButtonUp" then
        return false
    end
    if IsModifiedClick and IsModifiedClick("CHATLINK") then
        return true
    end
    return IsShiftKeyDown()
end

local function AttachShiftClickLink(frame, getLinkFn)
    frame:SetScript("OnMouseUp", function(self, button)
        if not IsShiftChatLinkClick(button) then
            return
        end
        GemOrderTest_InsertChatItemLink(getLinkFn(self))
    end)
end

function GemOrderTest_RegisterEscapeFrame(frame)
    if not frame or not UISpecialFrames then
        return
    end
    if GemOrderTest.Debug and GemOrderTest.Debug.ShouldSkipUISpecialFrames
        and GemOrderTest.Debug:ShouldSkipUISpecialFrames() then
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

function GemOrderTest_GetGemItemId(gemName)
    if not gemName or gemName == "None" then
        return nil
    end
    local gem = GemOrderTest_GemByName and GemOrderTest_GemByName[gemName]
    return gem and gem.itemId
end

function GemOrderTest_ExtractItemLink(text)
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

function GemOrderTest_ExtractItemId(text)
    local link = GemOrderTest_ExtractItemLink(text)
    if not link then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

function GemOrderTest_GetItemDisplayText(text)
    local link = GemOrderTest_ExtractItemLink(text)
    if link then
        local name = GetItemInfo(link)
        if name then
            return name
        end
    end
    return text
end

function GemOrderTest_TooltipsInit()
    GemOrderTest.itemLinkTarget = nil
end

function GemOrderTest_AttachItemTooltip(frame, getLinkFn)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local link = getLinkFn(self)
        if link then
            if type(link) == "number" then
                GemOrderTest_ShowItemTooltip(self, link)
            else
                GemOrderTest_ShowLinkTooltip(self, link)
            end
        end
    end)
    frame:SetScript("OnLeave", GemOrderTest_HideTooltip)
    AttachShiftClickLink(frame, getLinkFn)
end

function GemOrderTest_ClearDropdownItemTooltips(level)
    level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
    local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
    if UIDropDownMenu_GetNumberOfButtons then
        maxButtons = UIDropDownMenu_GetNumberOfButtons(level) or maxButtons
    end

    for i = 1, maxButtons do
        local button = _G["DropDownList" .. level .. "Button" .. i]
        if button then
            button.gemOrderItemId = nil
        end
    end
end

function GemOrderTest_AttachDropdownItemButton(itemId, buttonIndex)
    if not itemId or itemId <= 0 or not buttonIndex then
        return
    end

    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local button = _G["DropDownList" .. level .. "Button" .. buttonIndex]
    if not button then
        return
    end

    button.gemOrderItemId = itemId
    button:SetScript("OnEnter", function(self)
        if UIDropDownMenuButton_OnEnter then
            UIDropDownMenuButton_OnEnter(self)
        end
        local linkedItemId = self.gemOrderItemId
        if linkedItemId
            and type(self.value) == "number"
            and self.value > 0
            and self.value == linkedItemId then
            GemOrderTest_ShowItemTooltip(self, linkedItemId, "ANCHOR_RIGHT")
        end
    end)
    button:SetScript("OnLeave", function(self)
        GemOrderTest_HideTooltip()
        if UIDropDownMenuButton_OnLeave then
            UIDropDownMenuButton_OnLeave(self)
        end
    end)
    button:SetScript("OnMouseUp", function(self, mouseButton)
        if not IsShiftChatLinkClick(mouseButton) then
            return
        end
        local linkedItemId = self.gemOrderItemId
        if linkedItemId
            and type(self.value) == "number"
            and self.value > 0
            and self.value == linkedItemId then
            GemOrderTest_InsertChatItemLink(linkedItemId)
        end
    end)
end

function GemOrderTest_ApplyDropdownItemTooltips(indexToItemId)
    if not indexToItemId then
        return
    end

    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local function apply()
        GemOrderTest_ClearDropdownItemTooltips(level)
        for index, itemId in pairs(indexToItemId) do
            GemOrderTest_AttachDropdownItemButton(itemId, index)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, apply)
    else
        apply()
    end
end

function GemOrderTest_AttachDropdownTooltips(dropdown, getItemIdFn)
    local button = _G[dropdown:GetName() .. "Button"]
    if button then
        GemOrderTest_AttachItemTooltip(button, function()
            return getItemIdFn()
        end)
    end
end

function GemOrderTest_HookDropdownMenuTooltips()
    -- Per-item tooltips are attached when each gear/gem dropdown opens.
end
