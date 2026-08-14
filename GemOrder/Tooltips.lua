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
    GameTooltip:Show()
end

function GemOrder_ShowLinkTooltip(owner, link, anchor)
    if not link or not owner then
        return
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
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
        local itemId = self.gemOrderItemId
        if type(itemId) == "number" and itemId > 0 then
            GemOrder_ShowItemTooltip(self, itemId, "ANCHOR_RIGHT")
        end
    end)

    hooksecurefunc("UIDropDownMenuButton_OnLeave", function(self)
        if not self or not IsGemOrderItemDropdown(UIDROPDOWNMENU_OPEN_MENU) then
            return
        end
        if self.gemOrderItemId then
            GemOrder_HideTooltip()
        end
    end)

    if UIDropDownMenu_CreateButtons then
        hooksecurefunc("UIDropDownMenu_CreateButtons", function(level)
            GemOrder_ApplyDropdownItemTooltips(level or UIDROPDOWNMENU_MENU_LEVEL or 1)
        end)
    end
end
