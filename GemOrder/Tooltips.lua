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
        local itemId = self.value
        if type(itemId) == "number" and itemId > 0 then
            GemOrder_ShowItemTooltip(self, itemId, "ANCHOR_RIGHT")
        end
    end)

    hooksecurefunc("UIDropDownMenuButton_OnLeave", function()
        if not IsGemOrderItemDropdown(UIDROPDOWNMENU_OPEN_MENU) then
            return
        end
        GemOrder_HideTooltip()
    end)
end
