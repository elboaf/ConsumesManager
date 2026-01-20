-- ConsumesManagerBar - Companion addon for ConsumesManager
-- Provides a floating horizontal bar with clickable consumable icons

ConsumesManagerBar = {}

-- Configuration with scaling support
local BAR_HEIGHT = 40
local ICON_SIZE = 32
local ICON_SPACING = 5
-- Removed MAX_ICONS limit - bar will expand to fit all tracked items

-- Edit mode state
local editMode = false
local iconVisibility = {} -- Stores which icons should be HIDDEN (true = hidden)

-- Main frames
local barFrame
local disabledBarFrame

-- Saved variables (UPDATED VARIABLE NAME)
ConsumesManagerBar_Settings2 = {}

-- Buff tracking
local buffedItems = {} -- Track which items are currently buffed (now stores count: 1 for regular buffs, 1-2 for weapon enchants)
local buffTimes = {} -- Track remaining time for buffs in seconds

-- Texture cache for dynamic texture loading
local itemTextureCache = {}

-- REMOVED: buffNameMap - now using Itemlist.lua directly

function ConsumesManagerBar_GetItemTexture(itemID)
    -- If texture is actually the 9th return (equipLoc position)
    local _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
    return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ConsumesManagerBar_GetItemBuffData(itemID)
    -- Search through consumablesCategories to find item data
    if consumablesCategories then
        for categoryName, consumables in pairs(consumablesCategories) do
            if consumables then
                for _, consumable in ipairs(consumables) do
                    if consumable.id == itemID then
                        return {
                            priority = consumable.priority or 99,
                            spellId = consumable.spellId,
                            weaponEnchantName = consumable.weaponEnchantName
                        }
                    end
                end
            end
        end
    end
    return { priority = 99, spellId = nil, weaponEnchantName = nil }
end

function ConsumesManagerBar_GetBuffDuration(itemID)
    local buffData = ConsumesManagerBar_GetItemBuffData(itemID)
    if not buffData or not buffData.spellId or buffData.spellId == 0 then
        return nil, nil
    end
    
    -- Loop through player buffs
    for i = 1, 32 do
        local texture, index, spellId = UnitBuff("player", i)
        if not texture then break end
        
        -- Match by spell ID (3rd parameter from superwow.dll)
        if spellId and spellId == buffData.spellId then
            -- Try to get the remaining time using GetPlayerBuff
            local buffIndex = GetPlayerBuff(i - 1, "HELPFUL")
            if buffIndex >= 0 then
                local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
                return timeLeft, buffIndex
            end
        end
    end
    
    return nil, nil
end

function ConsumesManagerBar_HasBuff(itemID)
    local buffData = ConsumesManagerBar_GetItemBuffData(itemID)
    if not buffData or not buffData.spellId or buffData.spellId == 0 then
        return false
    end
    
    -- superwow.dll's UnitBuff returns: texture, index, spellId
    for i = 1, 32 do
        local texture, index, spellId = UnitBuff("player", i)
        if not texture then break end
        
        -- Match by spell ID (3rd parameter from superwow.dll)
        if spellId and spellId == buffData.spellId then
            return true
        end
    end
    
    return false
end

function ConsumesManagerBar_HasWeaponEnchant(itemID)
    local buffData = ConsumesManagerBar_GetItemBuffData(itemID)
    if not buffData or not buffData.weaponEnchantName then
        return false, 0, nil
    end
    
    -- Get weapon enchant names
    local mhName, ohName = GetWeaponEnchantInfo("player")
    local count = 0
    local timeLeft = nil
    
    -- Get expiration times
    local hasMHEnchant, mhExpiration, mhCharges, hasOHEnchant, ohExpiration, ohCharges = GetWeaponEnchantInfo()
    
    -- Check main hand
    if mhName and mhName == buffData.weaponEnchantName then
        count = count + 1
        if mhExpiration and mhExpiration > 0 then
            local mhTimeLeftSec = mhExpiration / 1000  -- Convert ms to seconds
            if not timeLeft or mhTimeLeftSec < timeLeft then
                timeLeft = mhTimeLeftSec
            end
        else
            -- No expiration time (infinite duration like some poisons)
            timeLeft = -1
        end
    end
    
    -- Check off hand
    if ohName and ohName == buffData.weaponEnchantName then
        count = count + 1
        if ohExpiration and ohExpiration > 0 then
            local ohTimeLeftSec = ohExpiration / 1000  -- Convert ms to seconds
            if not timeLeft or ohTimeLeftSec < timeLeft then
                timeLeft = ohTimeLeftSec
            end
        else
            -- No expiration time (infinite duration like some poisons)
            timeLeft = -1
        end
    end
    
    return count > 0, count, timeLeft
end

function ConsumesManagerBar_UpdateBuffedItems()
    -- Clear previous buff tracking
    buffedItems = {}
    buffTimes = {}
    
    -- Check each tracked item to see if it's currently buffed
    if ConsumesManager_SelectedItems then
        for itemID, isTracked in ConsumesManager_SelectedItems do
            if isTracked then
                local buffCount = 0
                local hasBuff = false
                local timeLeft = nil
                
                -- Check for regular buffs
                if ConsumesManagerBar_HasBuff(itemID) then
                    buffCount = 1  -- Regular buffs count as 1
                    hasBuff = true
                    timeLeft = ConsumesManagerBar_GetBuffDuration(itemID)
                end
                
                -- Check for weapon enchants (could be 1 or 2)
                local hasEnchant, enchantCount, enchantTimeLeft = ConsumesManagerBar_HasWeaponEnchant(itemID)
                if hasEnchant then
                    buffCount = enchantCount  -- 1 or 2 for weapon enchants
                    hasBuff = true
                    timeLeft = enchantTimeLeft or -1
                end
                
                if hasBuff then
                    buffedItems[itemID] = buffCount
                    buffTimes[itemID] = timeLeft
                end
            end
        end
    end
end

function ConsumesManagerBar_ApplyScaling()
    -- Calculate scaled dimensions based on user settings
    local scale = ConsumesManagerBar_Settings2.scale or 1.0
    local scaledBarHeight = BAR_HEIGHT * scale
    local scaledIconSize = ICON_SIZE * scale
    local scaledIconSpacing = ICON_SPACING * scale
    
    -- Apply scaling to main bar
    if barFrame then
        barFrame:SetHeight(scaledBarHeight)
        
        -- Update icon positions and sizes
        for i, iconFrame in ipairs(barFrame.icons) do
            if iconFrame then
                iconFrame:SetWidth(scaledIconSize)
                iconFrame:SetHeight(scaledIconSize)
                
                -- Update icon position
                iconFrame:SetPoint("LEFT", barFrame, "LEFT", (i-1) * (scaledIconSize + scaledIconSpacing) + scaledIconSpacing, 0)
                
                -- Update buff highlight size
                if iconFrame.buffHighlight then
                    iconFrame.buffHighlight:SetWidth(scaledIconSize + 17 * scale)
                    iconFrame.buffHighlight:SetHeight(scaledIconSize + 17 * scale)
                end
                
                -- Update move indicator size
                if iconFrame.moveIndicator then
                    iconFrame.moveIndicator:SetWidth(12 * scale)
                    iconFrame.moveIndicator:SetHeight(12 * scale)
                end
                
                -- Update font sizes
                if iconFrame.count then
                    local fontSize = 12 * scale
                    if fontSize < 8 then fontSize = 8 end
                    if fontSize > 20 then fontSize = 20 end
                    iconFrame.count:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
                end
                
                if iconFrame.timeText then
                    local fontSize = 10 * scale
                    if fontSize < 8 then fontSize = 8 end
                    if fontSize > 18 then fontSize = 18 end
                    iconFrame.timeText:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
                end
            end
        end
        
        -- Update bar width
        if barFrame.icons and table.getn(barFrame.icons) > 0 then
            local iconCount = table.getn(barFrame.icons)
            local newWidth = (iconCount * (scaledIconSize + scaledIconSpacing)) + scaledIconSpacing
            barFrame:SetWidth(newWidth)
        end
    end
    
    -- Apply scaling to secondary bar
    if disabledBarFrame then
        disabledBarFrame:SetHeight(scaledBarHeight)
        
        -- Update icon positions and sizes
        for i, iconFrame in ipairs(disabledBarFrame.icons) do
            if iconFrame then
                iconFrame:SetWidth(scaledIconSize)
                iconFrame:SetHeight(scaledIconSize)
                
                -- Update icon position
                iconFrame:SetPoint("LEFT", disabledBarFrame, "LEFT", (i-1) * (scaledIconSize + scaledIconSpacing) + scaledIconSpacing, 0)
                
                -- Update buff highlight size
                if iconFrame.buffHighlight then
                    iconFrame.buffHighlight:SetWidth(scaledIconSize + 17 * scale)
                    iconFrame.buffHighlight:SetHeight(scaledIconSize + 17 * scale)
                end
                
                -- Update move indicator size
                if iconFrame.moveIndicator then
                    iconFrame.moveIndicator:SetWidth(12 * scale)
                    iconFrame.moveIndicator:SetHeight(12 * scale)
                end
                
                -- Update font sizes
                if iconFrame.count then
                    local fontSize = 12 * scale
                    if fontSize < 8 then fontSize = 8 end
                    if fontSize > 20 then fontSize = 20 end
                    iconFrame.count:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
                end
                
                if iconFrame.timeText then
                    local fontSize = 10 * scale
                    if fontSize < 8 then fontSize = 8 end
                    if fontSize > 18 then fontSize = 18 end
                    iconFrame.timeText:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
                end
            end
        end
        
        -- Update bar width
        if disabledBarFrame.icons and table.getn(disabledBarFrame.icons) > 0 then
            local iconCount = table.getn(disabledBarFrame.icons)
            local newWidth = (iconCount * (scaledIconSize + scaledIconSpacing)) + scaledIconSpacing
            disabledBarFrame:SetWidth(newWidth)
        end
    end
    
    -- Update title font sizes
    if barFrame and barFrame.title then
        local fontSize = 12 * scale
        if fontSize < 10 then fontSize = 10 end
        if fontSize > 16 then fontSize = 16 end
        barFrame.title:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
    end
    
    if barFrame and barFrame.editText then
        local fontSize = 10 * scale
        if fontSize < 8 then fontSize = 8 end
        if fontSize > 14 then fontSize = 14 end
        barFrame.editText:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
    end
    
    if disabledBarFrame and disabledBarFrame.title then
        local fontSize = 12 * scale
        if fontSize < 10 then fontSize = 10 end
        if fontSize > 16 then fontSize = 16 end
        disabledBarFrame.title:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
    end
end

function ConsumesManagerBar_Initialize()
    -- Create the main bar frame (for enabled items)
    barFrame = CreateFrame("Frame", "ConsumesManagerBarFrame", UIParent)
    barFrame:SetHeight(BAR_HEIGHT)
    
    -- Load saved scale or use default
    if ConsumesManagerBar_Settings2.scale == nil then
        ConsumesManagerBar_Settings2.scale = 1.0
    end
    
    -- Load saved position or use default (UPDATED VARIABLE NAME)
    if ConsumesManagerBar_Settings2.barPosition then
        barFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 
                         ConsumesManagerBar_Settings2.barPosition.x, 
                         ConsumesManagerBar_Settings2.barPosition.y)
    else
        barFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    end
    
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetMovable(true)
    barFrame:EnableMouse(true)
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function() 
        this:StartMoving() 
    end)
    barFrame:SetScript("OnDragStop", function() 
        this:StopMovingOrSizing() 
        -- Save position
        ConsumesManagerBar_SavePosition()
    end)
    
    -- Background
    local bg = barFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(barFrame)
    bg:SetTexture(0, 0, 0, 0)
    barFrame.background = bg
    
    -- Border
    barFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, 
        tileSize = 16, 
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    barFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    barFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    -- Title (only visible when dragging)
    local title = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", barFrame, "TOP", 0, -5)
    title:SetText("Consumes Bar - Drag to move")
    title:SetTextColor(1, 1, 1, 0.5)
    barFrame.title = title
    
    -- Edit mode indicator
    local editText = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editText:SetPoint("BOTTOM", barFrame, "BOTTOM", 0, 5)
    editText:SetText("EDIT MODE - Click icons to move between bars")
    editText:SetTextColor(1, 0.5, 0.5)
    editText:Hide()
    barFrame.editText = editText
    
    -- We'll create icons dynamically in UpdateBar instead of pre-creating them
    barFrame.icons = {}
    
    -- Create the disabled bar frame (for hidden items)
    disabledBarFrame = CreateFrame("Frame", "ConsumesManagerDisabledBarFrame", UIParent)
    disabledBarFrame:SetHeight(BAR_HEIGHT)
    
    -- Load saved position or position relative to main bar (UPDATED VARIABLE NAME)
    if ConsumesManagerBar_Settings2.disabledBarPosition then
        disabledBarFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 
                                ConsumesManagerBar_Settings2.disabledBarPosition.x, 
                                ConsumesManagerBar_Settings2.disabledBarPosition.y)
    else
        disabledBarFrame:SetPoint("TOP", barFrame, "BOTTOM", 0, -10)
    end
    
    disabledBarFrame:SetFrameStrata("MEDIUM")
    disabledBarFrame:SetMovable(true)
    disabledBarFrame:EnableMouse(true)
    disabledBarFrame:RegisterForDrag("LeftButton")
    disabledBarFrame:SetScript("OnDragStart", function() 
        this:StartMoving() 
    end)
    disabledBarFrame:SetScript("OnDragStop", function() 
        this:StopMovingOrSizing() 
        -- Save position
        ConsumesManagerBar_SavePosition()
    end)
    
    -- Background for disabled bar
    local disabledBg = disabledBarFrame:CreateTexture(nil, "BACKGROUND")
    disabledBg:SetAllPoints(disabledBarFrame)
    disabledBg:SetTexture(0, 0, 0, 0)
    disabledBarFrame.background = disabledBg
    
    -- Border for disabled bar
    disabledBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, 
        tileSize = 16, 
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    disabledBarFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    disabledBarFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    -- Title for disabled bar
    local disabledTitle = disabledBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    disabledTitle:SetPoint("TOP", disabledBarFrame, "TOP", 0, -5)
    disabledTitle:SetText("Secondary Bar - Drag to move")
    disabledTitle:SetTextColor(1, 1, 1, 0.5)
    disabledBarFrame.title = disabledTitle
    
    disabledBarFrame.icons = {}
    
    -- ===== ADD VISIBILITY LOADING HERE =====
    -- Load visibility state
    if ConsumesManagerBar_Settings2.barVisible == nil then
        -- Default to shown if not saved
        ConsumesManagerBar_Settings2.barVisible = true
    end
    
    if ConsumesManagerBar_Settings2.disabledBarVisible == nil then
        -- Default to shown if not saved
        ConsumesManagerBar_Settings2.disabledBarVisible = true
    end
    
    -- Apply visibility
    if ConsumesManagerBar_Settings2.barVisible then
        barFrame:Show()
    else
        barFrame:Hide()
    end
    
    if ConsumesManagerBar_Settings2.disabledBarVisible then
        disabledBarFrame:Show()
    else
        disabledBarFrame:Hide()
    end
    -- ===== END VISIBILITY LOADING =====
    
    -- Hide titles after a few seconds
    barFrame:SetScript("OnShow", function()
        this.title:Show()
        if disabledBarFrame then
            disabledBarFrame.title:Show()
        end
    end)
    
    -- Hide titles after 3 seconds
    barFrame:SetScript("OnUpdate", function(arg1)
        -- Hide main bar title
        if this.title and this.title:IsVisible() then
            if not this.hideTime then
                this.hideTime = GetTime() + 3
            elseif GetTime() > this.hideTime then
                this.title:Hide()
                this.hideTime = nil
            end
        end
        
        -- Hide disabled bar title
        if disabledBarFrame and disabledBarFrame.title and disabledBarFrame.title:IsVisible() then
            if not disabledBarFrame.hideTime then
                disabledBarFrame.hideTime = GetTime() + 3
            elseif GetTime() > disabledBarFrame.hideTime then
                disabledBarFrame.title:Hide()
                disabledBarFrame.hideTime = nil
            end
        end
        
        -- Update bars every 0.5 seconds
        if not this.lastBarUpdate then
            this.lastBarUpdate = GetTime()
        end
        
        if GetTime() - this.lastBarUpdate > 0.5 then
            ConsumesManagerBar_UpdateBars()
            this.lastBarUpdate = GetTime()
        end
    end)
    
    -- Load saved visibility settings (UPDATED VARIABLE NAME)
    if ConsumesManagerBar_Settings2.iconVisibility then
        iconVisibility = ConsumesManagerBar_Settings2.iconVisibility
    else
        ConsumesManagerBar_Settings2.iconVisibility = {}
        iconVisibility = ConsumesManagerBar_Settings2.iconVisibility
    end
    
    -- Apply scaling
    ConsumesManagerBar_ApplyScaling()
    
    DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar loaded! Two bars created - both fully functional.")
end

function ConsumesManagerBar_SavePosition()
    -- UPDATED VARIABLE NAME
    if not ConsumesManagerBar_Settings2 then
        ConsumesManagerBar_Settings2 = {}
    end
    
    -- Save main bar position
    local barX = barFrame:GetLeft()
    local barY = barFrame:GetTop()
    
    if barX and barY then
        if not ConsumesManagerBar_Settings2.barPosition then
            ConsumesManagerBar_Settings2.barPosition = {}
        end
        ConsumesManagerBar_Settings2.barPosition.x = barX
        ConsumesManagerBar_Settings2.barPosition.y = barY
    end
    
    -- Save disabled bar position
    local disabledBarX = disabledBarFrame:GetLeft()
    local disabledBarY = disabledBarFrame:GetTop()
    
    if disabledBarX and disabledBarY then
        if not ConsumesManagerBar_Settings2.disabledBarPosition then
            ConsumesManagerBar_Settings2.disabledBarPosition = {}
        end
        ConsumesManagerBar_Settings2.disabledBarPosition.x = disabledBarX
        ConsumesManagerBar_Settings2.disabledBarPosition.y = disabledBarY
    end
end

function ConsumesManagerBar_UpdateBars()
    if not barFrame or not disabledBarFrame then return end
    
    -- Update buff tracking first
    ConsumesManagerBar_UpdateBuffedItems()
    
    -- Get current player data
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    
    if not ConsumesManager_Data or not ConsumesManager_Data[realmName] or not ConsumesManager_Data[realmName][playerName] then
        barFrame:Hide()
        disabledBarFrame:Hide()
        return
    end
    
    local playerData = ConsumesManager_Data[realmName][playerName]
    local inventory = playerData["inventory"] or {}
    
    -- Collect all tracked items
    local allItems = {}
    local itemCount = 0
    
    if ConsumesManager_SelectedItems then
        for itemID, isTracked in ConsumesManager_SelectedItems do
            if isTracked then
                local count = inventory[itemID] or 0
                itemCount = itemCount + 1
                allItems[itemCount] = {
                    id = itemID,
                    count = count,
                    name = consumablesList[itemID] or "Unknown Item",
                    texture = ConsumesManagerBar_GetItemTexture(itemID), -- DYNAMIC TEXTURE LOADING
                    hidden = iconVisibility[itemID], -- true if hidden from main bar
                    buffed = buffedItems[itemID], -- now stores count (1 for regular buffs, 1-2 for weapon enchants)
                    timeLeft = buffTimes[itemID] -- remaining time in seconds or nil
                }
            end
        end
    end
    
    -- Sort by priority then by name using table.sort for predictable ordering
    table.sort(allItems, function(a, b)
        local buffDataA = ConsumesManagerBar_GetItemBuffData(a.id)
        local buffDataB = ConsumesManagerBar_GetItemBuffData(b.id)
        
        -- Default priority to 99 if not found
        local priorityA = buffDataA and buffDataA.priority or 99
        local priorityB = buffDataB and buffDataB.priority or 99
        
        -- First sort by priority (ascending - lower numbers first)
        if priorityA ~= priorityB then
            return priorityA < priorityB
        end
        
        -- If priorities are equal, sort by name (ascending)
        local nameA = a.name or ""
        local nameB = b.name or ""
        return nameA < nameB
    end)
    
    -- Separate items into enabled and disabled
    local enabledItems = {}
    local disabledItems = {}
    local enabledCount = 0
    local disabledCount = 0
    
    for i = 1, itemCount do
        local item = allItems[i]
        if item.hidden then
            disabledCount = disabledCount + 1
            disabledItems[disabledCount] = item
        else
            enabledCount = enabledCount + 1
            enabledItems[enabledCount] = item
        end
    end
    
    -- Update main bar (enabled items)
    ConsumesManagerBar_UpdateBar(barFrame, enabledItems, enabledCount, false)
    
    -- Update secondary bar
    ConsumesManagerBar_UpdateBar(disabledBarFrame, disabledItems, disabledCount, true)
    
    -- Update edit mode UI
    if editMode then
        barFrame.editText:Show()
        barFrame:SetBackdropBorderColor(1, 0.5, 0.5, 0.8) -- Red border in edit mode
        disabledBarFrame:SetBackdropBorderColor(1, 0.5, 0.5, 0.8) -- Red border in edit mode
    else
        barFrame.editText:Hide()
        barFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8) -- Normal border
        disabledBarFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8) -- Normal border for secondary bar
    end
    
    -- Apply scaling after updating bars
    ConsumesManagerBar_ApplyScaling()
end

function ConsumesManagerBar_FormatTime(seconds)
    if not seconds or seconds < 0 then
        return ""
    end
    
    if seconds > 3600 then
        -- More than 1 hour: show as Xh Ym
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds - (hours * 3600)) / 60)
        return hours .. "h " .. minutes .. "m"
    elseif seconds > 60 then
        -- More than 1 minute: show as Xm (no seconds)
        local minutes = math.floor(seconds / 60)
        return minutes .. "m"
    else
        -- Less than 1 minute: show as "<1m" instead of seconds
        return "<1m"
    end
end

function ConsumesManagerBar_GetBuffDuration(itemID)
    local buffData = ConsumesManagerBar_GetItemBuffData(itemID)
    if not buffData or not buffData.spellId or buffData.spellId == 0 then
        return nil
    end
    
    -- Step 1: Find the buff texture using UnitBuff (we have spellId)
    local targetTexture = nil
    for i = 1, 32 do
        local texture, index, spellId = UnitBuff("player", i)
        if not texture then break end
        if spellId and spellId == buffData.spellId then
            targetTexture = texture
            break
        end
    end
    
    if not targetTexture then
        return nil -- Buff not found via UnitBuff
    end
    
    -- Step 2: Find which GetPlayerBuff slot has this texture
    for i = 0, 31 do
        local buffId, cancel = GetPlayerBuff(i, "HELPFUL|HARMFUL|PASSIVE")
        if buffId >= 0 then
            local buffTexture = GetPlayerBuffTexture(buffId)
            if buffTexture and buffTexture == targetTexture then
                -- Found it! Get the time left
                local timeLeft = GetPlayerBuffTimeLeft(buffId)
                if timeLeft and timeLeft > 0 then
                    return timeLeft
                end
                return -1 -- Buff active but no time (weapon enchants)
            end
        end
    end
    
    return nil
end

function ConsumesManagerBar_UpdateBar(frame, items, itemCount, isSecondaryBar)
    -- Clean up old icons if we have more than needed
    for i = itemCount + 1, table.getn(frame.icons) do
        if frame.icons[i] then
            frame.icons[i]:Hide()
            frame.icons[i] = nil
        end
    end
    
    -- Get current scale
    local scale = ConsumesManagerBar_Settings2.scale or 1.0
    local scaledIconSize = ICON_SIZE * scale
    local scaledIconSpacing = ICON_SPACING * scale
    
    -- Update or create icons
    for i = 1, itemCount do
        local iconFrame = frame.icons[i]
        local item = items[i]
        
        -- Create icon frame if it doesn't exist
        if not iconFrame then
            iconFrame = CreateFrame("Button", frame:GetName().."Icon"..i, frame)
            iconFrame:SetWidth(scaledIconSize)
            iconFrame:SetHeight(scaledIconSize)
            
            -- Icon texture
            local icon = iconFrame:CreateTexture(nil, "BACKGROUND")
            icon:SetAllPoints(iconFrame)
            iconFrame.icon = icon
            
            -- Count text
            local count = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            count:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2 * scale, 2 * scale)
            count:SetJustifyH("RIGHT")
            iconFrame.count = count
            
            -- Time text (top left - NEW POSITION)
            local timeText = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            timeText:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 2 * scale, -2 * scale)
            timeText:SetJustifyH("LEFT")
            timeText:SetTextColor(1, 1, 1) -- White color (CHANGED FROM YELLOW)
            iconFrame.timeText = timeText
            
            -- Move indicator (arrows for edit mode)
            local moveIndicator = iconFrame:CreateTexture(nil, "OVERLAY")
            moveIndicator:SetWidth(12 * scale)
            moveIndicator:SetHeight(12 * scale)
            moveIndicator:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -3 * scale, 3 * scale)
            moveIndicator:SetTexture("Interface\\Buttons\\UI-RadioButton")
            moveIndicator:Hide()
            iconFrame.moveIndicator = moveIndicator

            -- Buff highlight - gold border
            local buffHighlight = iconFrame:CreateTexture(nil, "OVERLAY")
            buffHighlight:SetWidth(scaledIconSize + 17 * scale)
            buffHighlight:SetHeight(scaledIconSize + 17 * scale)
            buffHighlight:SetPoint("CENTER", iconFrame, "CENTER", 0.5, 1)
            buffHighlight:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            buffHighlight:SetBlendMode("ADD")
            buffHighlight:SetAlpha(1.0)
            buffHighlight:SetVertexColor(1, 0.82, 0, 1) -- Gold color
            buffHighlight:SetDrawLayer("OVERLAY", 7)
            buffHighlight:Hide()
            iconFrame.buffHighlight = buffHighlight
            
            -- Cooldown
            local cooldown = CreateFrame("Frame", frame:GetName().."Cooldown"..i, iconFrame)
            cooldown:SetAllPoints(iconFrame)
            cooldown:SetFrameLevel(iconFrame:GetFrameLevel() + 1)
            iconFrame.cooldown = cooldown
            
            -- Tooltip
            iconFrame:SetScript("OnEnter", function()
                if this.itemID then
                    ConsumesManagerBar_ShowTooltip(this, isSecondaryBar)
                end
            end)
            iconFrame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            
            -- Click handler
            iconFrame:SetScript("OnClick", function()
                if this.itemID then
                    if editMode then
                        -- Toggle visibility in edit mode (move between bars)
                        ConsumesManagerBar_ToggleVisibility(this.itemID)
                    else
                        -- Use item in normal mode (works on both bars!)
                        ConsumesManagerBar_UseItem(this.itemID)
                    end
                end
            end)
            
            frame.icons[i] = iconFrame
        else
            -- Update existing icon size
            iconFrame:SetWidth(scaledIconSize)
            iconFrame:SetHeight(scaledIconSize)
        end
        
        -- Position the icon
        iconFrame:SetPoint("LEFT", frame, "LEFT", (i-1) * (scaledIconSize + scaledIconSpacing) + scaledIconSpacing, 0)
        
        -- Update icon content
        iconFrame.itemID = item.id
        iconFrame.icon:SetTexture(item.texture)
        
        -- Update count display - show empty for 0 count
        if item.count > 0 then
            if item.count > 1 then
                iconFrame.count:SetText(item.count)
            else
                iconFrame.count:SetText("")
            end
        else
            iconFrame.count:SetText("") -- No count text for 0 items
        end
        
        -- Update time display for buffed items
        if item.buffed and item.timeLeft then
            if item.timeLeft == -1 then
                -- Weapon enchant or unknown duration
                iconFrame.timeText:SetText("Active")
                iconFrame.timeText:SetTextColor(0, 1, 0) -- Green for active
            elseif item.timeLeft > 0 then
                -- Regular buff with time remaining
                local timeStr = ConsumesManagerBar_FormatTime(item.timeLeft)
                iconFrame.timeText:SetText(timeStr)
                
                -- Color code based on remaining time
                if item.timeLeft < 30 then
                    -- Less than 30 seconds: Red
                    iconFrame.timeText:SetTextColor(1, 0, 0)
                elseif item.timeLeft < 60 then
                    -- Less than 1 minute: Yellow
                    iconFrame.timeText:SetTextColor(1, 1, 0)
                else
                    -- More than 1 minute: white color
                    iconFrame.timeText:SetTextColor(1, 1, 1)
                end
            else
                -- Buff expired or no time data
                iconFrame.timeText:SetText("")
            end
        else
            -- Not buffed
            iconFrame.timeText:SetText("")
        end
        
        -- Update appearance based on whether item is available and buffed
        if item.buffed then
            -- Item is currently buffed - highlight with glowing border
            iconFrame.icon:SetDesaturated(false)
            iconFrame.count:SetTextColor(0, 1, 0) -- Green count for buffed items
            
            -- Check if it's a weapon enchant with both weapons
            local buffData = ConsumesManagerBar_GetItemBuffData(item.id)
            if buffData and buffData.weaponEnchantName then
                -- It's a weapon enchant item
                local _, enchantCount = ConsumesManagerBar_HasWeaponEnchant(item.id)
                if enchantCount == 2 then
                    -- Both weapons enchanted - BRIGHT GREEN
                    if iconFrame.buffHighlight then
                        iconFrame.buffHighlight:SetVertexColor(0, 1, 0, 1) -- Bright green
                        iconFrame.buffHighlight:Show()
                    end
                else
                    -- One weapon enchanted or regular buff - YELLOW/GOLD
                    if iconFrame.buffHighlight then
                        iconFrame.buffHighlight:SetVertexColor(1, 0.82, 0, 1) -- Gold
                        iconFrame.buffHighlight:Show()
                    end
                end
            else
                -- Regular buff - YELLOW/GOLD
                if iconFrame.buffHighlight then
                    iconFrame.buffHighlight:SetVertexColor(1, 0.82, 0, 1) -- Gold
                    iconFrame.buffHighlight:Show()
                end
            end
        elseif item.count > 0 then
            -- Item is available but not buffed - normal appearance
            iconFrame.icon:SetDesaturated(false)
            iconFrame.count:SetTextColor(1, 1, 1)
            if iconFrame.buffHighlight then
                iconFrame.buffHighlight:Hide()
            end
        else
            -- Item is not available - greyed out
            iconFrame.icon:SetDesaturated(true)
            iconFrame.count:SetTextColor(0.5, 0.5, 0.5)
            if iconFrame.buffHighlight then
                iconFrame.buffHighlight:Hide()
            end
        end
        
        -- Show move indicator in edit mode (regardless of availability)
        if editMode then
            if iconFrame.moveIndicator then
                iconFrame.moveIndicator:Show()
            end
        else
            if iconFrame.moveIndicator then
                iconFrame.moveIndicator:Hide()
            end
        end
        
        -- Simple cooldown handling
        local start, duration = GetContainerItemCooldown(0, 1)
        
        iconFrame:Show()
    end
    
    -- Adjust bar width based on number of items
    if itemCount > 0 then
        local newWidth = (itemCount * (scaledIconSize + scaledIconSpacing)) + scaledIconSpacing
        frame:SetWidth(newWidth)
        frame:Show()
    else
        frame:Hide()
    end
end

function ConsumesManagerBar_ToggleVisibility(itemID)
    -- Toggle HIDDEN state for this item (true = hidden from main bar, false/nil = visible on main bar)
    if iconVisibility[itemID] then
        iconVisibility[itemID] = nil
    else
        iconVisibility[itemID] = true
    end
    
    -- Save visibility settings (UPDATED VARIABLE NAME)
    ConsumesManagerBar_Settings2.iconVisibility = iconVisibility
    
    -- Update the bars to reflect changes
    ConsumesManagerBar_UpdateBars()
end

function ConsumesManagerBar_UseItem(itemID)
    -- Store target state before using item
    local hadTarget = UnitExists("target")
    local wasTargetingPlayer = UnitIsUnit("player", "target")
    TargetUnit("player")
    local bag, slot = ConsumesManager_FindItemInBags(itemID)
    if bag and slot then
        UseContainerItem(bag, slot)
    else
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Item not found in bags.")
    end
    
    -- Restore previous target if needed
    if hadTarget and not wasTargetingPlayer then
        -- Restore the original target
        TargetLastTarget()
    elseif not hadTarget then
        -- Clear target if we had none originally
        ClearTarget()
    end
end

function ConsumesManagerBar_ShowTooltip(iconFrame, isSecondaryBar)
    GameTooltip:SetOwner(iconFrame, "ANCHOR_RIGHT")
    
    -- Use item ID to show tooltip
    local itemName = consumablesList[iconFrame.itemID]
    if itemName then
        GameTooltip:SetText(itemName)
        
        -- Get the actual count from inventory data
        local realmName = GetRealmName()
        local playerName = UnitName("player")
        local count = 0
        
        if ConsumesManager_Data and ConsumesManager_Data[realmName] and ConsumesManager_Data[realmName][playerName] then
            local inventory = ConsumesManager_Data[realmName][playerName]["inventory"] or {}
            count = inventory[iconFrame.itemID] or 0
        end
        
        if count > 0 then
            GameTooltip:AddLine("Count: " .. count, 1, 1, 1)
        else
            GameTooltip:AddLine("Count: 0 (Not in bags)", 1, 0.5, 0.5)
        end
        
        -- Show buff status with time info
        if buffedItems[iconFrame.itemID] then
            local buffCount = buffedItems[iconFrame.itemID]
            local timeLeft = buffTimes[iconFrame.itemID]
            
            if buffCount == 2 then
                GameTooltip:AddLine("Currently Active (Both Weapons)", 0, 1, 0) -- Bright green
            else
                GameTooltip:AddLine("Currently Active", 0, 1, 0) -- Green
            end
            
            -- Add time information if available
            if timeLeft and timeLeft > 0 then
                local timeStr = ConsumesManagerBar_FormatTime(timeLeft)
                if timeStr ~= "" then
                    GameTooltip:AddLine("Time Left: " .. timeStr, 1, 1, 0.5) -- Yellow
                end
            elseif timeLeft == -1 then
                GameTooltip:AddLine("Duration: Weapon Enchant", 0.8, 0.8, 0.8) -- Gray
            end
        end
        
        if editMode then
            if isSecondaryBar then
                GameTooltip:AddLine("Click to move to main bar", 0.5, 1, 0.5)
            else
                GameTooltip:AddLine("Click to move to secondary bar", 0.5, 1, 0.5)
            end
        else
            if count > 0 then
                GameTooltip:AddLine("Click to use", 0.5, 1, 0.5)
            else
                GameTooltip:AddLine("Item not available", 1, 0.5, 0.5)
            end
            if isSecondaryBar then
                GameTooltip:AddLine("(Secondary Bar)", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine("(Main Bar)", 0.7, 0.7, 0.7)
            end
        end
        
        GameTooltip:Show()
    else
        GameTooltip:SetText("Unknown Item (ID: " .. tostring(iconFrame.itemID) .. ")")
        GameTooltip:AddLine("Item data not found", 1, 0.5, 0.5)
        GameTooltip:Show()
    end
end

function ConsumesManagerBar_ToggleEditMode()
    editMode = not editMode
    if editMode then
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Edit mode ON - Click icons to move between bars")
    else
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Edit mode OFF")
    end
    ConsumesManagerBar_UpdateBars()
end

function ConsumesManagerBar_SetScale(newScale)
    -- Clamp scale between 0.5 and 2.0
    newScale = tonumber(newScale)
    if not newScale or newScale < 0.5 then
        newScale = 0.5
    elseif newScale > 2.0 then
        newScale = 2.0
    end
    
    -- Save scale setting
    ConsumesManagerBar_Settings2.scale = newScale
    
    -- Apply scaling
    ConsumesManagerBar_ApplyScaling()
    
    DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Scale set to " .. string.format("%.1f", newScale))
end

-- Slash command for showing/hiding the bars
SLASH_CONSUMESBAR1 = "/cmbar"
SLASH_CONSUMESBAR2 = "/consumesbar"
SlashCmdList["CONSUMESBAR"] = function(msg)
    if not barFrame then
        ConsumesManagerBar_Initialize()
    else
        if barFrame:IsShown() then
            barFrame:Hide()
            if disabledBarFrame then
                disabledBarFrame:Hide()
            end
            DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar hidden. Use /cmbar to show again.")
            -- SAVE VISIBILITY STATE
            ConsumesManagerBar_Settings2.barVisible = false
            ConsumesManagerBar_Settings2.disabledBarVisible = false
        else
            barFrame:Show()
            if disabledBarFrame then
                disabledBarFrame:Show()
            end
            DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar shown.")
            -- SAVE VISIBILITY STATE
            ConsumesManagerBar_Settings2.barVisible = true
            ConsumesManagerBar_Settings2.disabledBarVisible = true
        end
    end
end

-- Slash command for edit mode
SLASH_CONSUMESBAREDIT1 = "/cmbaredit"
SLASH_CONSUMESBAREDIT2 = "/consumesbaredit"
SlashCmdList["CONSUMESBAREDIT"] = function(msg)
    if not barFrame then
        ConsumesManagerBar_Initialize()
    end
    ConsumesManagerBar_ToggleEditMode()
end

-- Slash command to reset positions
SLASH_CONSUMESBARRESET1 = "/cmbarreset"
SLASH_CONSUMESBARRESET2 = "/consumesbarreset"
SlashCmdList["CONSUMESBARRESET"] = function(msg)
    -- Reset saved positions (UPDATED VARIABLE NAME)
    ConsumesManagerBar_Settings2.barPosition = nil
    ConsumesManagerBar_Settings2.disabledBarPosition = nil
    
    -- Reset to default positions
    barFrame:ClearAllPoints()
    barFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    
    disabledBarFrame:ClearAllPoints()
    disabledBarFrame:SetPoint("TOP", barFrame, "BOTTOM", 0, -10)
    
    DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Bar positions reset to default.")
end

-- Slash command for scaling
SLASH_CONSUMESBARSCALE1 = "/cmbarscale"
SLASH_CONSUMESBARSCALE2 = "/consumesbarscale"
SlashCmdList["CONSUMESBARSCALE"] = function(msg)
    if not barFrame then
        ConsumesManagerBar_Initialize()
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar initialized. Use /cmbarscale 0.5-2.0 to adjust size.")
        return
    end
    
    if msg and msg ~= "" then
        -- Parse scale value from command
        local newScale = tonumber(msg)
        if newScale then
            ConsumesManagerBar_SetScale(newScale)
        else
            DEFAULT_CHAT_FRAME:AddMessage("Usage: /cmbarscale <value>")
            DEFAULT_CHAT_FRAME:AddMessage("Current scale: " .. string.format("%.1f", ConsumesManagerBar_Settings2.scale or 1.0))
            DEFAULT_CHAT_FRAME:AddMessage("Valid range: 0.5 - 2.0 (0.5 = 50%, 1.0 = 100%, 2.0 = 200%)")
        end
    else
        -- Show current scale if no value provided
        DEFAULT_CHAT_FRAME:AddMessage("Current scale: " .. string.format("%.1f", ConsumesManagerBar_Settings2.scale or 1.0))
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /cmbarscale <value>")
        DEFAULT_CHAT_FRAME:AddMessage("Valid range: 0.5 - 2.0 (0.5 = 50%, 1.0 = 100%, 2.0 = 200%)")
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        -- Initialize saved variables if they don't exist (UPDATED VARIABLE NAME)
        if not ConsumesManagerBar_Settings2 then
            ConsumesManagerBar_Settings2 = {}
        end
        
        -- Initialize immediately
        ConsumesManagerBar_Initialize()
    end
end)