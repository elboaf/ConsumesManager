-- ConsumesManagerBar - Companion addon for ConsumesManager
-- Unlimited named floating bars. Right-click icons in edit mode to assign to a bar.
-- Left/right arrows reorder within a bar.

ConsumesManagerBar = {}

-- Base dimensions (scaled at runtime)
local BAR_HEIGHT    = 40
local ICON_SIZE     = 32
local ICON_SPACING  = 5

-- Runtime state
local editMode      = false
local mouseoverMode = false
local mouseoverVisible = false

-- barFrames[barID] = WoW Frame object
local barFrames = {}

-- Saved variables (loaded from disk by WoW)
ConsumesManagerBar_Settings2 = {}

-- Buff tracking
local buffedItems = {}
local buffTimes   = {}

-- Texture cache
local itemTextureCache = {}

-- Pulse animation
local pulsingTimers   = {}
local lastPulseUpdate = 0

-- Per-item ordering override (itemID -> numeric priority)
local customPriorities = {}

-- Glow
local glowingIcons  = {}
local glowReminders = {}

-- Shared context-menu frame (created once, reused)
local contextMenuFrame = nil

-- ============================================================
-- BAR DATA ACCESSORS  (all bar metadata lives in Settings2)
-- ============================================================

local function GetBars()
    -- Ensure at least one bar always exists
    if not ConsumesManagerBar_Settings2.bars or
       table.getn(ConsumesManagerBar_Settings2.bars) == 0 then
        ConsumesManagerBar_Settings2.bars = {
            { id = "bar1", name = "Bar 1" }
        }
    end
    return ConsumesManagerBar_Settings2.bars
end

-- Returns the barID an item belongs to, defaulting to the first bar
local function GetItemBarID(itemID)
    local assigned = ConsumesManagerBar_Settings2.itemBar and
                     ConsumesManagerBar_Settings2.itemBar[itemID]
    if assigned then
        -- Validate the bar still exists
        for _, bar in ipairs(GetBars()) do
            if bar.id == assigned then return assigned end
        end
    end
    return GetBars()[1].id
end

-- Assigns an item to a bar (nil-stores when it's the default bar to save space)
local function SetItemBarID(itemID, barID)
    if not ConsumesManagerBar_Settings2.itemBar then
        ConsumesManagerBar_Settings2.itemBar = {}
    end
    if barID == GetBars()[1].id then
        ConsumesManagerBar_Settings2.itemBar[itemID] = nil
    else
        ConsumesManagerBar_Settings2.itemBar[itemID] = barID
    end
end

-- ============================================================
-- GLOW EFFECTS
-- ============================================================

function ConsumesManagerBar_IsGlowAvailable()
    return DoiteGlow ~= nil
end

function ConsumesManagerBar_LoadGlowSettings()
    glowReminders = ConsumesManagerBar_Settings2.glowReminders or {}
    ConsumesManagerBar_Settings2.glowReminders = glowReminders
end

function ConsumesManagerBar_SaveGlowSettings()
    ConsumesManagerBar_Settings2.glowReminders = glowReminders
end

function ConsumesManagerBar_ToggleGlowReminder(itemID)
    local itemName = consumablesList[itemID] or ("Item " .. itemID)
    if glowReminders[itemID] == false then
        glowReminders[itemID] = nil
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Glow ENABLED for " .. itemName)
    else
        glowReminders[itemID] = false
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Glow DISABLED for " .. itemName)
    end
    ConsumesManagerBar_SaveGlowSettings()
    ConsumesManagerBar_UpdateBars()
end

function ConsumesManagerBar_ShouldGlow(item)
    if not item then return false end
    if glowReminders[item.id] == false then return false end
    return (item.count > 0) and (not item.buffed)
end

function ConsumesManagerBar_StartGlow(iconFrame)
    if not iconFrame or not iconFrame:IsShown() then return end
    ConsumesManagerBar_StopGlowByItemID(iconFrame.itemID)
    if ConsumesManagerBar_IsGlowAvailable() then
        DoiteGlow.Start(iconFrame)
        glowingIcons[iconFrame.itemID] = { frame = iconFrame, usingDoiteGlow = true }
    else
        if not iconFrame.missingBuffGlow then
            local glow = iconFrame:CreateTexture(nil, "OVERLAY")
            glow:SetWidth(ICON_SIZE + 8)
            glow:SetHeight(ICON_SIZE + 8)
            glow:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
            glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            glow:SetBlendMode("ADD")
            glow:SetVertexColor(1, 0.2, 0.2, 0.8)
            glow:SetDrawLayer("OVERLAY", 6)
            iconFrame.missingBuffGlow = glow
        end
        iconFrame.missingBuffGlow:Show()
        glowingIcons[iconFrame.itemID] = { frame = iconFrame, usingDoiteGlow = false }
    end
end

function ConsumesManagerBar_StopGlowByItemID(itemID)
    local d = glowingIcons[itemID]
    if d then
        if d.usingDoiteGlow and ConsumesManagerBar_IsGlowAvailable() then
            DoiteGlow.Stop(d.frame)
        elseif d.frame.missingBuffGlow then
            d.frame.missingBuffGlow:Hide()
        end
        glowingIcons[itemID] = nil
    end
end

function ConsumesManagerBar_StopGlow(iconFrame)
    if not iconFrame or not iconFrame.itemID then return end
    local d = glowingIcons[iconFrame.itemID]
    if d and d.frame == iconFrame then
        if d.usingDoiteGlow and ConsumesManagerBar_IsGlowAvailable() then
            DoiteGlow.Stop(iconFrame)
        elseif iconFrame.missingBuffGlow then
            iconFrame.missingBuffGlow:Hide()
        end
        glowingIcons[iconFrame.itemID] = nil
    end
end

function ConsumesManagerBar_UpdateGlowForIcon(iconFrame, item)
    if not iconFrame or not item then return end
    local shouldGlow = ConsumesManagerBar_ShouldGlow(item)
    local current    = glowingIcons[item.id]
    local isGlowing  = current and current.frame == iconFrame
    if shouldGlow and not isGlowing then
        ConsumesManagerBar_StartGlow(iconFrame)
    elseif not shouldGlow and isGlowing then
        ConsumesManagerBar_StopGlow(iconFrame)
    end
end

function ConsumesManagerBar_CleanupGlowEffects()
    local living = {}
    for _, frame in pairs(barFrames) do
        if frame.icons then
            for _, iconFrame in ipairs(frame.icons) do
                if iconFrame and iconFrame.itemID then
                    living[iconFrame.itemID] = true
                end
            end
        end
    end
    for itemID in pairs(glowingIcons) do
        if not living[itemID] then
            ConsumesManagerBar_StopGlowByItemID(itemID)
        end
    end
end

function ConsumesManagerBar_ResetAllGlowSettings()
    glowReminders = {}
    ConsumesManagerBar_SaveGlowSettings()
    ConsumesManagerBar_UpdateBars()
    DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: All glow settings reset.")
end

-- ============================================================
-- TEXTURE CACHE
-- ============================================================

function ConsumesManagerBar_GetItemTexture(itemID)
    if itemTextureCache[itemID] then return itemTextureCache[itemID] end
    local _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
    if texture then
        itemTextureCache[itemID] = texture
        return texture
    end
    if consumablesCategories then
        for _, consumables in pairs(consumablesCategories) do
            if consumables then
                for _, c in ipairs(consumables) do
                    if c.id == itemID and c.texture then return c.texture end
                end
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ConsumesManagerBar_RefreshItemTextures()
    if not ConsumesManager_SelectedItems then return end
    local updated = 0
    for itemID, isTracked in ConsumesManager_SelectedItems do
        if isTracked then
            local _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
            if texture then
                local cur = itemTextureCache[itemID]
                if not cur or cur == "Interface\\Icons\\INV_Misc_QuestionMark" then
                    itemTextureCache[itemID] = texture
                    updated = updated + 1
                end
            end
        end
    end
    if updated > 0 then
        ConsumesManagerBar_SaveTextureCache()
        ConsumesManagerBar_UpdateBars()
    end
end

function ConsumesManagerBar_SaveTextureCache()
    ConsumesManagerBar_Settings2.itemTextureCache = itemTextureCache
end

function ConsumesManagerBar_LoadTextureCache()
    itemTextureCache = ConsumesManagerBar_Settings2.itemTextureCache or {}
    ConsumesManagerBar_Settings2.itemTextureCache = itemTextureCache
end

-- ============================================================
-- BUFF DATA
-- ============================================================

function ConsumesManagerBar_GetItemBuffData(itemID)
    if consumablesCategories then
        for _, consumables in pairs(consumablesCategories) do
            if consumables then
                for _, c in ipairs(consumables) do
                    if c.id == itemID then
                        return {
                            priority          = c.priority or 99,
                            spellId           = c.spellId,
                            weaponEnchantName = c.weaponEnchantName
                        }
                    end
                end
            end
        end
    end
    return { priority = 99, spellId = nil, weaponEnchantName = nil }
end

function ConsumesManagerBar_GetEffectivePriority(itemID)
    if customPriorities[itemID] then return customPriorities[itemID] end
    return ConsumesManagerBar_GetItemBuffData(itemID).priority or 99
end

function ConsumesManagerBar_SaveCustomPriorities()
    ConsumesManagerBar_Settings2.customPriorities = customPriorities
end

function ConsumesManagerBar_LoadCustomPriorities()
    customPriorities = ConsumesManagerBar_Settings2.customPriorities or {}
end

function ConsumesManagerBar_SetCustomPriority(itemID, priority)
    customPriorities[itemID] = priority
    ConsumesManagerBar_SaveCustomPriorities()
    ConsumesManagerBar_UpdateBars()
end

function ConsumesManagerBar_ResetAllCustomPriorities()
    customPriorities = {}
    ConsumesManagerBar_SaveCustomPriorities()
    ConsumesManagerBar_UpdateBars()
    DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: All custom priorities reset.")
end

function ConsumesManagerBar_HasBuff(itemID)
    local d = ConsumesManagerBar_GetItemBuffData(itemID)
    if not d or not d.spellId or d.spellId == 0 then return false end
    for i = 1, 32 do
        local texture, index, spellId = UnitBuff("player", i)
        if not texture then break end
        if spellId and spellId == d.spellId then return true end
    end
    return false
end

function ConsumesManagerBar_HasWeaponEnchant(itemID)
    local d = ConsumesManagerBar_GetItemBuffData(itemID)
    if not d or not d.weaponEnchantName then return false, 0, nil end
    local mhName, ohName = GetWeaponEnchantInfo("player")
    local _, mhExp, _, _, ohExp = GetWeaponEnchantInfo()
    local count = 0
    local timeLeft = nil
    if mhName and mhName == d.weaponEnchantName then
        count = count + 1
        local t = (mhExp and mhExp > 0) and (mhExp / 1000) or -1
        timeLeft = (not timeLeft or (t > 0 and t < timeLeft)) and t or timeLeft
    end
    if ohName and ohName == d.weaponEnchantName then
        count = count + 1
        local t = (ohExp and ohExp > 0) and (ohExp / 1000) or -1
        timeLeft = (not timeLeft or (t > 0 and t < timeLeft)) and t or timeLeft
    end
    return count > 0, count, timeLeft
end

function ConsumesManagerBar_GetBuffDuration(itemID)
    local d = ConsumesManagerBar_GetItemBuffData(itemID)
    if not d or not d.spellId or d.spellId == 0 then return nil end
    local targetTexture = nil
    for i = 1, 32 do
        local texture, index, spellId = UnitBuff("player", i)
        if not texture then break end
        if spellId and spellId == d.spellId then targetTexture = texture; break end
    end
    if not targetTexture then return nil end
    for i = 0, 31 do
        local buffId = GetPlayerBuff(i, "HELPFUL|HARMFUL|PASSIVE")
        if buffId >= 0 then
            local bt = GetPlayerBuffTexture(buffId)
            if bt and bt == targetTexture then
                local tl = GetPlayerBuffTimeLeft(buffId)
                return (tl and tl > 0) and tl or -1
            end
        end
    end
    return nil
end

function ConsumesManagerBar_UpdateBuffedItems()
    buffedItems = {}
    buffTimes   = {}
    if not ConsumesManager_SelectedItems then return end
    for itemID, isTracked in ConsumesManager_SelectedItems do
        if isTracked then
            local buffCount = 0
            local hasBuff   = false
            local timeLeft  = nil
            if ConsumesManagerBar_HasBuff(itemID) then
                buffCount = 1; hasBuff = true
                timeLeft = ConsumesManagerBar_GetBuffDuration(itemID)
            end
            local hasEnchant, enchantCount, enchantTime = ConsumesManagerBar_HasWeaponEnchant(itemID)
            if hasEnchant then
                buffCount = enchantCount; hasBuff = true
                timeLeft = enchantTime or -1
            end
            if hasBuff then
                buffedItems[itemID] = buffCount
                buffTimes[itemID]   = timeLeft
            end
        end
    end
end

-- ============================================================
-- PULSE ANIMATION
-- ============================================================

function ConsumesManagerBar_UpdatePulseAnimation()
    local now     = GetTime()
    local elapsed = now - lastPulseUpdate
    lastPulseUpdate = now
    if elapsed > 0.2 then elapsed = 0.05 end

    for itemID, p in pairs(pulsingTimers) do
        if p.frame and p.frame:IsShown() then
            p.lastUpdate = (p.lastUpdate or 0) + elapsed
            if p.lastUpdate >= 0.1 then
                local alpha = p.frame.timeText:GetAlpha()
                if p.direction == 1 then
                    alpha = math.min(alpha + 0.15, 1.0)
                    if alpha >= 1.0 then p.direction = -1 end
                else
                    alpha = math.max(alpha - 0.15, 0.3)
                    if alpha <= 0.3 then p.direction = 1 end
                end
                p.frame.timeText:SetAlpha(alpha)
                if p.frame.count and p.frame.count:GetText() ~= "" then
                    p.frame.count:SetAlpha(alpha)
                end
                if p.frame.buffHighlight and p.frame.buffHighlight:IsShown() then
                    local ga = (p.timeLeft and p.timeLeft < 30)
                               and (0.4 + alpha * 0.6)
                               or  (0.6 + alpha * 0.4)
                    p.frame.buffHighlight:SetAlpha(ga)
                end
                p.lastUpdate = 0
            end
        else
            pulsingTimers[itemID] = nil
        end
    end
end

-- ============================================================
-- FORMAT TIME
-- ============================================================

function ConsumesManagerBar_FormatTime(seconds)
    if not seconds or seconds < 0 then return "" end
    if seconds > 3600 then
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds - h * 3600) / 60)
        return h .. "h " .. m .. "m"
    elseif seconds > 60 then
        return math.floor(seconds / 60) .. "m"
    else
        return "<1m"
    end
end

-- ============================================================
-- SCALING
-- ============================================================

function ConsumesManagerBar_SetScale(newScale)
    newScale = tonumber(newScale)
    if not newScale then return end
    newScale = math.max(0.5, math.min(2.0, newScale))
    newScale = math.floor(newScale * 100 + 0.5) / 100  -- round to 2dp
    ConsumesManagerBar_Settings2.scale = newScale
    ConsumesManagerBar_ApplyScaling()
    DEFAULT_CHAT_FRAME:AddMessage(
        "ConsumesManagerBar: Scale set to " .. string.format("%.2f", newScale))
end

function ConsumesManagerBar_ApplyScaling()
    local scale  = ConsumesManagerBar_Settings2.scale or 1.0
    local barH   = BAR_HEIGHT   * scale
    local icoS   = ICON_SIZE    * scale
    local icoSp  = ICON_SPACING * scale

    for _, frame in pairs(barFrames) do
        frame:SetHeight(barH)
        for i, iconFrame in ipairs(frame.icons) do
            if iconFrame then
                iconFrame:SetWidth(icoS)
                iconFrame:SetHeight(icoS)
                iconFrame:ClearAllPoints()
                iconFrame:SetPoint("LEFT", frame, "LEFT",
                    (i - 1) * (icoS + icoSp) + icoSp, 0)
                if iconFrame.buffHighlight then
                    iconFrame.buffHighlight:SetWidth(icoS + 17 * scale)
                    iconFrame.buffHighlight:SetHeight(icoS + 17 * scale)
                end
                if iconFrame.count then
                    local fs = math.max(8, math.min(20, math.floor(12 * scale)))
                    iconFrame.count:SetFont("Fonts\\FRIZQT__.TTF", fs, "THICKOUTLINE")
                end
                if iconFrame.timeText then
                    local fs = math.max(8, math.min(18, math.floor(10 * scale)))
                    iconFrame.timeText:SetFont("Fonts\\FRIZQT__.TTF", fs, "THICKOUTLINE")
                end
                if iconFrame.missingBuffGlow then
                    iconFrame.missingBuffGlow:SetWidth(icoS + 8 * scale)
                    iconFrame.missingBuffGlow:SetHeight(icoS + 8 * scale)
                end
            end
        end
        if table.getn(frame.icons) > 0 then
            local n = table.getn(frame.icons)
            frame:SetWidth(n * (icoS + icoSp) + icoSp)
        end
    end
end

-- ============================================================
-- POSITION SAVE
-- ============================================================

function ConsumesManagerBar_SaveAllPositions()
    for _, bar in ipairs(GetBars()) do
        local f = barFrames[bar.id]
        if f then
            local x, y = f:GetLeft(), f:GetTop()
            if x and y then bar.position = { x = x, y = y } end
        end
    end
    ConsumesManagerBar_SaveTextureCache()
end

-- ============================================================
-- MOUSEOVER MODE
-- ============================================================

function ConsumesManagerBar_SetAllBarsAlpha(alpha)
    -- Edit mode always keeps bars visible regardless of mouseover state
    if editMode then alpha = 1 end
    for _, f in pairs(barFrames) do f:SetAlpha(alpha) end
end

local function IsMouseOver(frame)
    if not frame or not frame:IsShown() then return false end
    local mx, my = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    mx, my = mx / s, my / s
    local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    return l and mx >= l and mx <= r and my >= b and my <= t
end

-- Per-bar invisible hit frames for mouseover detection.
-- Each bar gets its own hit frame sized to match that bar exactly.
-- Hovering any hit frame shows ALL bars; leaving all of them hides them.
local mouseoverHitFrames = {}

function ConsumesManagerBar_CheckMouseoverHide()
    -- Still over any real bar frame?
    for _, f in pairs(barFrames) do
        if f:IsShown() and IsMouseOver(f) then return end
    end
    -- Still over any per-bar hit frame?
    for _, hf in pairs(mouseoverHitFrames) do
        if hf:IsShown() and IsMouseOver(hf) then return end
    end
    mouseoverVisible = false
    ConsumesManagerBar_SetAllBarsAlpha(0)
end

function ConsumesManagerBar_ApplyMouseoverMode()
    mouseoverMode = ConsumesManagerBar_Settings2.mouseoverMode or false
    if mouseoverMode then
        if not mouseoverVisible then ConsumesManagerBar_SetAllBarsAlpha(0) end
        ConsumesManagerBar_UpdateMouseoverHitFrame()
    else
        ConsumesManagerBar_SetAllBarsAlpha(1)
        mouseoverVisible = false
        -- Hide all per-bar hit frames
        for _, hf in pairs(mouseoverHitFrames) do hf:Hide() end
    end
end

-- No-op kept for call-sites that reference the old single-frame version
function ConsumesManagerBar_CreateMouseoverHitFrame() end

function ConsumesManagerBar_UpdateMouseoverHitFrame()
    if not mouseoverMode then
        for _, hf in pairs(mouseoverHitFrames) do hf:Hide() end
        return
    end
    local pad = 6

    -- Create/update one hit frame per bar, sized to that bar exactly
    for barID, barFrame in pairs(barFrames) do
        if not mouseoverHitFrames[barID] then
            local hf = CreateFrame("Frame",
                "ConsumesManagerBarHitFrame_" .. barID, UIParent)
            hf:SetFrameStrata("LOW")
            hf:SetAlpha(0)
            hf:EnableMouse(true)
            hf:SetScript("OnEnter", function()
                if mouseoverMode then
                    mouseoverVisible = true
                    ConsumesManagerBar_SetAllBarsAlpha(1)
                end
            end)
            hf:SetScript("OnLeave", function()
                if mouseoverMode then ConsumesManagerBar_CheckMouseoverHide() end
            end)
            mouseoverHitFrames[barID] = hf
        end

        local hf = mouseoverHitFrames[barID]
        local l = barFrame:GetLeft()
        if l and barFrame:IsShown() then
            local r = barFrame:GetRight()
            local b = barFrame:GetBottom()
            local t = barFrame:GetTop()
            hf:ClearAllPoints()
            hf:SetPoint("TOPLEFT",     UIParent, "BOTTOMLEFT", l - pad, t + pad)
            hf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r + pad, b - pad)
            hf:Show()
        else
            hf:Hide()
        end
    end

    -- Hide hit frames for bars that no longer exist
    for barID, hf in pairs(mouseoverHitFrames) do
        if not barFrames[barID] then hf:Hide() end
    end
end

function ConsumesManagerBar_ToggleMouseoverMode()
    ConsumesManagerBar_Settings2.mouseoverMode =
        not (ConsumesManagerBar_Settings2.mouseoverMode or false)
    ConsumesManagerBar_ApplyMouseoverMode()
    if ConsumesManagerBar_Settings2.mouseoverMode then
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Mouseover mode ON.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Mouseover mode OFF.")
    end
end

-- ============================================================
-- BAR FRAME CREATION
-- ============================================================

local function CreateBarFrameForBar(bar)
    local scale  = ConsumesManagerBar_Settings2.scale or 1.0
    local name   = "ConsumesManagerBarFrame_" .. bar.id

    -- Reuse existing WoW frame if it already exists (e.g. on reload)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetHeight(BAR_HEIGHT * scale)
    f:SetWidth(40)
    f.barID = bar.id
    f.icons = {}

    if bar.position then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            bar.position.x, bar.position.y)
    else
        -- Default: stack bars in the center of screen, spaced vertically
        local idx = 0
        for i, b in ipairs(GetBars()) do
            if b.id == bar.id then idx = i - 1; break end
        end
        f:SetPoint("CENTER", UIParent, "CENTER", 0, idx * -55)
    end

    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        ConsumesManagerBar_SaveAllPositions()
        ConsumesManagerBar_UpdateMouseoverHitFrame()
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)

    -- Mouseover passthrough
    f:SetScript("OnEnter", function()
        if mouseoverMode then
            mouseoverVisible = true
            ConsumesManagerBar_SetAllBarsAlpha(1)
        end
    end)
    f:SetScript("OnLeave", function()
        if mouseoverMode then ConsumesManagerBar_CheckMouseoverHide() end
    end)

    return f
end

-- ============================================================
-- PUBLIC ACCESSORS
-- ============================================================

-- Expose bar data and frames for the Settings UI
function ConsumesManagerBar_GetBars()
    return GetBars()
end

function ConsumesManagerBar_GetBarFrames()
    return barFrames
end

-- ============================================================
-- PUBLIC BAR MANAGEMENT
-- ============================================================

function ConsumesManagerBar_AddBar(name)
    local bars = GetBars()
    -- Generate a unique ID
    local suffix = table.getn(bars) + 1
    local newID
    repeat
        newID = "bar" .. suffix
        local collision = false
        for _, b in ipairs(bars) do
            if b.id == newID then collision = true; break end
        end
        if collision then suffix = suffix + 1 else break end
    until false

    local newBar = { id = newID, name = name or ("Bar " .. suffix) }
    table.insert(bars, newBar)

    local f = CreateBarFrameForBar(newBar)
    barFrames[newID] = f

    ConsumesManagerBar_UpdateBars()
    DEFAULT_CHAT_FRAME:AddMessage(
        "ConsumesManagerBar: Added bar \"" .. newBar.name .. "\".")
    return newID
end

function ConsumesManagerBar_DeleteBar(barID)
    local bars = GetBars()
    if table.getn(bars) <= 1 then
        DEFAULT_CHAT_FRAME:AddMessage(
            "ConsumesManagerBar: Cannot delete the only bar.")
        return
    end
    if barID == bars[1].id then
        DEFAULT_CHAT_FRAME:AddMessage(
            "ConsumesManagerBar: Cannot delete the first bar. Rename it if needed.")
        return
    end
    -- Move all items on this bar back to bar 1
    if ConsumesManagerBar_Settings2.itemBar then
        for itemID, assignedID in pairs(ConsumesManagerBar_Settings2.itemBar) do
            if assignedID == barID then
                ConsumesManagerBar_Settings2.itemBar[itemID] = nil
            end
        end
    end
    -- Remove from list
    for i, b in ipairs(bars) do
        if b.id == barID then table.remove(bars, i); break end
    end
    -- Hide and discard frame and its orphaned swap buttons
    if barFrames[barID] then
        local bf = barFrames[barID]
        if bf.swapBtns then
            for _, sb in pairs(bf.swapBtns) do
                if sb then sb:Hide() end
            end
        end
        bf:Hide()
        barFrames[barID] = nil
    end
    ConsumesManagerBar_UpdateBars()
end

function ConsumesManagerBar_RenameBar(barID, newName)
    newName = newName or ""
    if newName == "" then return end
    for _, bar in ipairs(GetBars()) do
        if bar.id == barID then
            bar.name = newName
            break
        end
    end
end

function ConsumesManagerBar_SetBarHidden(barID, hidden)
    for _, bar in ipairs(GetBars()) do
        if bar.id == barID then
            bar.hidden = hidden or nil  -- nil to keep saved vars clean
            break
        end
    end
    ConsumesManagerBar_UpdateBars()
end

function ConsumesManagerBar_IsBarHidden(barID)
    for _, bar in ipairs(GetBars()) do
        if bar.id == barID then
            return bar.hidden == true
        end
    end
    return false
end

function ConsumesManagerBar_MoveItemToBar(itemID, targetBarID)
    SetItemBarID(itemID, targetBarID)
    ConsumesManagerBar_UpdateBars()
end

-- ============================================================
-- CONTEXT MENU
-- ============================================================

local function HideContextMenu()
    if contextMenuFrame then contextMenuFrame:Hide() end
end

local function ShowBarContextMenu(iconFrame, itemID)
    HideContextMenu()

    if not contextMenuFrame then
        contextMenuFrame = CreateFrame(
            "Frame", "ConsumesManagerBarContextMenu", UIParent)
        contextMenuFrame:SetFrameStrata("TOOLTIP")
        contextMenuFrame:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        contextMenuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        contextMenuFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        contextMenuFrame:EnableMouse(true)
    end

    -- Clear old buttons by hiding them
    if contextMenuFrame.buttons then
        for _, btn in ipairs(contextMenuFrame.buttons) do btn:Hide() end
    end
    if contextMenuFrame.labels then
        for _, lbl in ipairs(contextMenuFrame.labels) do lbl:Hide() end
    end
    if contextMenuFrame.dividers then
        for _, div in ipairs(contextMenuFrame.dividers) do div:Hide() end
    end
    contextMenuFrame.buttons  = {}
    contextMenuFrame.labels   = {}
    contextMenuFrame.dividers = {}

    local bars        = GetBars()
    local currentBarID = GetItemBarID(itemID)
    local menuW       = 170
    local btnH        = 20
    local yOff        = -8

    -- Header
    local header = contextMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", contextMenuFrame, "TOPLEFT", 10, yOff)
    header:SetTextColor(1, 0.82, 0)
    header:SetText("Move to bar:")
    table.insert(contextMenuFrame.labels, header)
    yOff = yOff - btnH

    -- One button per bar
    for idx, bar in ipairs(bars) do
        local captureBar = bar   -- proper closure
        local btn = CreateFrame("Button", nil, contextMenuFrame)
        btn:SetWidth(menuW - 16)
        btn:SetHeight(btnH)
        btn:SetPoint("TOPLEFT", contextMenuFrame, "TOPLEFT", 8, yOff)
        btn:EnableMouse(true)

        local hl = btn:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints(btn)
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", btn, "LEFT", 4, 0)
        lbl:SetJustifyH("LEFT")
        if captureBar.id == currentBarID then
            lbl:SetText("|cff44ff44" .. captureBar.name .. " \226\156\147|r")
        else
            lbl:SetText(captureBar.name)
        end

        btn:SetScript("OnEnter", function() hl:SetAlpha(0.3) end)
        btn:SetScript("OnLeave", function() hl:SetAlpha(0)   end)
        btn:SetScript("OnClick", function()
            ConsumesManagerBar_MoveItemToBar(itemID, captureBar.id)
            HideContextMenu()
        end)

        table.insert(contextMenuFrame.buttons, btn)
        yOff = yOff - btnH
    end

    -- Divider
    yOff = yOff - 4
    local div = contextMenuFrame:CreateTexture(nil, "OVERLAY")
    div:SetHeight(1)
    div:SetWidth(menuW - 16)
    div:SetPoint("TOPLEFT", contextMenuFrame, "TOPLEFT", 8, yOff)
    div:SetTexture(0.5, 0.5, 0.5, 0.5)
    table.insert(contextMenuFrame.dividers, div)
    yOff = yOff - 6

    -- Glow toggle
    local glowBtn = CreateFrame("Button", nil, contextMenuFrame)
    glowBtn:SetWidth(menuW - 16)
    glowBtn:SetHeight(btnH)
    glowBtn:SetPoint("TOPLEFT", contextMenuFrame, "TOPLEFT", 8, yOff)
    glowBtn:EnableMouse(true)

    local glowHl = glowBtn:CreateTexture(nil, "BACKGROUND")
    glowHl:SetAllPoints(glowBtn)
    glowHl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    glowHl:SetBlendMode("ADD")
    glowHl:SetAlpha(0)

    local glowLbl = glowBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    glowLbl:SetPoint("LEFT", glowBtn, "LEFT", 4, 0)
    glowLbl:SetJustifyH("LEFT")
    if glowReminders[itemID] == false then
        glowLbl:SetText("|cffff6666Glow: OFF|r \226\128\148 click to enable")
    else
        glowLbl:SetText("|cff66ff66Glow: ON|r \226\128\148 click to disable")
    end

    glowBtn:SetScript("OnEnter", function() glowHl:SetAlpha(0.3) end)
    glowBtn:SetScript("OnLeave", function() glowHl:SetAlpha(0)   end)
    glowBtn:SetScript("OnClick", function()
        ConsumesManagerBar_ToggleGlowReminder(itemID)
        HideContextMenu()
    end)
    table.insert(contextMenuFrame.buttons, glowBtn)
    yOff = yOff - btnH - 8

    contextMenuFrame:SetWidth(menuW)
    contextMenuFrame:SetHeight(math.abs(yOff) + 4)

    -- Position: prefer above the icon, flip if it would go off-screen
    local iconTop  = iconFrame:GetTop()  or 0
    local menuH    = math.abs(yOff) + 4
    if iconTop - menuH < 0 then
        contextMenuFrame:SetPoint("BOTTOMLEFT", iconFrame, "TOPRIGHT", 0, 0)
    else
        contextMenuFrame:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 0, 0)
    end
    contextMenuFrame:Show()

    -- Register so ESC closes it
    tinsert(UISpecialFrames, "ConsumesManagerBarContextMenu")

    -- Only close once the cursor has entered the menu at least once.
    -- This prevents instant-close when the menu opens under/beside the cursor.
    local hasEntered = false
    local closePad = 8
    contextMenuFrame:SetScript("OnLeave", nil)
    contextMenuFrame:SetScript("OnUpdate", function()
        if not this:IsShown() then return end
        local mx, my = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        mx, my = mx / s, my / s
        local l = this:GetLeft()
        if not l then return end
        local r = this:GetRight()
        local b = this:GetBottom()
        local t = this:GetTop()
        local inside = mx >= l - closePad and mx <= r + closePad and
                       my >= b - closePad and my <= t + closePad
        if inside then
            hasEntered = true
        elseif hasEntered then
            this:Hide()
        end
    end)
end

-- ============================================================
-- REORDERING WITHIN A BAR
-- ============================================================

local function GetBarItemsSorted(barID)
    local result = {}
    if ConsumesManager_SelectedItems then
        for id, isTracked in ConsumesManager_SelectedItems do
            if isTracked and GetItemBarID(id) == barID then
                table.insert(result, {
                    id = id,
                    effectivePriority = ConsumesManagerBar_GetEffectivePriority(id)
                })
            end
        end
    end
    table.sort(result, function(a, b)
        return a.effectivePriority < b.effectivePriority
    end)
    return result
end

function ConsumesManagerBar_MoveItemLeft(itemID, barID)
    local items = GetBarItemsSorted(barID)
    for i, entry in ipairs(items) do
        if entry.id == itemID and i > 1 then
            local swapID = items[i - 1].id
            local pA = ConsumesManagerBar_GetEffectivePriority(itemID)
            local pB = ConsumesManagerBar_GetEffectivePriority(swapID)
            customPriorities[itemID] = pB
            customPriorities[swapID] = pA
            ConsumesManagerBar_SaveCustomPriorities()
            ConsumesManagerBar_UpdateBars()
            return
        end
    end
end

function ConsumesManagerBar_MoveItemRight(itemID, barID)
    local items = GetBarItemsSorted(barID)
    local n = table.getn(items)
    for i, entry in ipairs(items) do
        if entry.id == itemID and i < n then
            local swapID = items[i + 1].id
            local pA = ConsumesManagerBar_GetEffectivePriority(itemID)
            local pB = ConsumesManagerBar_GetEffectivePriority(swapID)
            customPriorities[itemID] = pB
            customPriorities[swapID] = pA
            ConsumesManagerBar_SaveCustomPriorities()
            ConsumesManagerBar_UpdateBars()
            return
        end
    end
end

-- ============================================================
-- USE ITEM
-- ============================================================

function ConsumesManagerBar_UseItem(itemID)
    local hadTarget          = UnitExists("target")
    local wasTargetingPlayer = UnitIsUnit("player", "target")
    TargetUnit("player")
    local bag, slot = ConsumesManager_FindItemInBags(itemID)
    if bag and slot then
        UseContainerItem(bag, slot)
    else
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Item not found in bags.")
    end
    if hadTarget and not wasTargetingPlayer then
        TargetLastTarget()
    elseif not hadTarget then
        ClearTarget()
    end
end

-- ============================================================
-- TOOLTIP
-- ============================================================

function ConsumesManagerBar_ShowTooltip(iconFrame, barID)
    GameTooltip:SetOwner(iconFrame, "ANCHOR_RIGHT")
    local itemName = consumablesList[iconFrame.itemID]
    if not itemName then
        GameTooltip:SetText("Unknown Item (ID: " .. tostring(iconFrame.itemID) .. ")")
        GameTooltip:Show()
        return
    end

    GameTooltip:SetText(itemName)

    -- Count
    local realmName  = GetRealmName()
    local playerName = UnitName("player")
    local count = 0
    if ConsumesManager_Data and ConsumesManager_Data[realmName] and
       ConsumesManager_Data[realmName][playerName] then
        local inv = ConsumesManager_Data[realmName][playerName]["inventory"] or {}
        count = inv[iconFrame.itemID] or 0
    end
    if count > 0 then
        GameTooltip:AddLine("Count: " .. count, 1, 1, 1)
    else
        GameTooltip:AddLine("Count: 0 (Not in bags)", 1, 0.5, 0.5)
    end

    -- Which bar
    local currentBarID = GetItemBarID(iconFrame.itemID)
    local barName = "Unknown"
    for _, bar in ipairs(GetBars()) do
        if bar.id == currentBarID then barName = bar.name; break end
    end
    GameTooltip:AddLine("Bar: " .. barName, 0.7, 0.7, 0.7)

    -- Glow
    if glowReminders[iconFrame.itemID] == false then
        GameTooltip:AddLine("Glow Reminder: DISABLED", 1, 0.3, 0.3)
    else
        GameTooltip:AddLine("Glow Reminder: ENABLED", 0.3, 1, 0.3)
    end

    -- Buff
    if buffedItems[iconFrame.itemID] then
        local buffCount = buffedItems[iconFrame.itemID]
        local timeLeft  = buffTimes[iconFrame.itemID]
        if buffCount == 2 then
            GameTooltip:AddLine("Currently Active (Both Weapons)", 0, 1, 0)
        else
            GameTooltip:AddLine("Currently Active", 0, 1, 0)
        end
        if timeLeft and timeLeft > 0 then
            local ts = ConsumesManagerBar_FormatTime(timeLeft)
            if ts ~= "" then
                GameTooltip:AddLine("Time Left: " .. ts, 1, 1, 0.5)
            end
        elseif timeLeft == -1 then
            GameTooltip:AddLine("Duration: Weapon Enchant", 0.8, 0.8, 0.8)
        end
    else
        if count > 0 then
            if glowReminders[iconFrame.itemID] == false then
                GameTooltip:AddLine("NOT BUFFED (Glow disabled)", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine("NOT BUFFED - Click to use", 1, 0.3, 0.3)
            end
        else
            GameTooltip:AddLine("Not available in bags", 0.7, 0.7, 0.7)
        end
    end

    if editMode then
        GameTooltip:AddLine("Right-click to move to a different bar", 0.8, 0.8, 1)
        GameTooltip:AddLine("Use arrows to reorder within this bar", 0.8, 0.8, 0.8)
    else
        if count > 0 then
            if buffedItems[iconFrame.itemID] then
                GameTooltip:AddLine("Click to refresh buff", 0.5, 1, 0.5)
            else
                GameTooltip:AddLine("Click to apply buff", 0.5, 1, 0.5)
            end
        else
            GameTooltip:AddLine("Item not available", 1, 0.5, 0.5)
        end
    end

    GameTooltip:Show()
end

-- ============================================================
-- EDIT MODE
-- ============================================================

function ConsumesManagerBar_ToggleEditMode()
    editMode = not editMode
    HideContextMenu()
    if editMode then
        -- Force all bars visible; mouseover mode is suspended during editing
        for _, f in pairs(barFrames) do f:SetAlpha(1) end
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Edit mode ON")
    else
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: Edit mode OFF")
        -- Re-apply mouseover state now that edit mode is off
        if mouseoverMode and not mouseoverVisible then
            ConsumesManagerBar_SetAllBarsAlpha(0)
        end
    end
    ConsumesManagerBar_UpdateBars()
end

function ConsumesManagerBar_IsEditMode()
    return editMode
end

-- ============================================================
-- MAIN UPDATE LOOP
-- ============================================================

function ConsumesManagerBar_UpdateBars()
    if not next(barFrames) then return end

    ConsumesManagerBar_UpdateBuffedItems()

    local realmName  = GetRealmName()
    local playerName = UnitName("player")

    if not ConsumesManager_Data or
       not ConsumesManager_Data[realmName] or
       not ConsumesManager_Data[realmName][playerName] then
        for _, f in pairs(barFrames) do f:Hide() end
        return
    end

    local inventory = ConsumesManager_Data[realmName][playerName]["inventory"] or {}

    -- Bucket items by bar
    local buckets = {}
    for _, bar in ipairs(GetBars()) do buckets[bar.id] = {} end

    if ConsumesManager_SelectedItems then
        for itemID, isTracked in ConsumesManager_SelectedItems do
            if isTracked then
                local barID = GetItemBarID(itemID)
                if not buckets[barID] then buckets[barID] = {} end
                table.insert(buckets[barID], {
                    id                = itemID,
                    count             = inventory[itemID] or 0,
                    name              = consumablesList[itemID] or "Unknown",
                    texture           = ConsumesManagerBar_GetItemTexture(itemID),
                    buffed            = buffedItems[itemID],
                    timeLeft          = buffTimes[itemID],
                    effectivePriority = ConsumesManagerBar_GetEffectivePriority(itemID)
                })
            end
        end
    end

    for barID, items in pairs(buckets) do
        table.sort(items, function(a, b)
            if a.effectivePriority ~= b.effectivePriority then
                return a.effectivePriority < b.effectivePriority
            end
            return (a.name or "") < (b.name or "")
        end)
        local f = barFrames[barID]
        if f then
            -- Respect hidden flag (skip normal show logic if hidden and not editing)
            local bar = nil
            for _, b in ipairs(GetBars()) do
                if b.id == barID then bar = b; break end
            end
            local isHidden = bar and bar.hidden == true

            if isHidden and not editMode then
                f:Hide()
                if f.nameLabel then f.nameLabel:Hide() end
            else
                ConsumesManagerBar_UpdateSingleBar(f, items, barID)
                if editMode then
                    f:SetBackdropBorderColor(1, 0.5, 0.5, 0.8)
                else
                    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
                end

                -- Edit mode: show bar name label above the bar
                if editMode then
                    if not f.nameLabel then
                        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        lbl:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 4, 2)
                        lbl:SetTextColor(1, 0.82, 0)
                        f.nameLabel = lbl
                    end
                    local displayName = (bar and bar.name or barID)
                    if isHidden then displayName = displayName .. " [hidden]" end
                    f.nameLabel:SetText(displayName)
                    f.nameLabel:Show()
                else
                    if f.nameLabel then f.nameLabel:Hide() end
                end
            end
        end
    end

    ConsumesManagerBar_ApplyScaling()
    ConsumesManagerBar_CleanupGlowEffects()
end

-- ============================================================
-- UPDATE A SINGLE BAR'S ICONS
-- ============================================================

function ConsumesManagerBar_UpdateSingleBar(frame, items, barID)
    local itemCount = table.getn(items)
    local scale     = ConsumesManagerBar_Settings2.scale or 1.0
    local icoS      = ICON_SIZE    * scale
    local icoSp     = ICON_SPACING * scale

    -- Ensure swap button table exists on this frame
    if not frame.swapBtns then frame.swapBtns = {} end

    -- Hide excess icons
    for i = itemCount + 1, table.getn(frame.icons) do
        if frame.icons[i] then
            frame.icons[i]:Hide()
            frame.icons[i] = nil
        end
    end

    -- Hide excess swap buttons (need at most itemCount-1)
    for i = math.max(1, itemCount), table.getn(frame.swapBtns) do
        if frame.swapBtns[i] then frame.swapBtns[i]:Hide() end
    end

    for i = 1, itemCount do
        local item      = items[i]
        local iconFrame = frame.icons[i]

        -- CREATE icon frame if needed
        if not iconFrame then
            iconFrame = CreateFrame("Button",
                frame:GetName() .. "Icon" .. i, frame)
            iconFrame:SetWidth(icoS)
            iconFrame:SetHeight(icoS)
            iconFrame:SetFrameLevel(frame:GetFrameLevel() + 2)

            local tex = iconFrame:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints(iconFrame)
            iconFrame.icon = tex

            local cnt = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            cnt:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2 * scale, 2 * scale)
            cnt:SetJustifyH("RIGHT")
            cnt:SetAlpha(1.0)
            iconFrame.count = cnt

            local tmr = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            tmr:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 2 * scale, -2 * scale)
            tmr:SetJustifyH("LEFT")
            tmr:SetTextColor(0, 1, 0)
            tmr:SetAlpha(1.0)
            iconFrame.timeText = tmr

            local bh = iconFrame:CreateTexture(nil, "OVERLAY")
            bh:SetWidth(icoS + 17 * scale)
            bh:SetHeight(icoS + 17 * scale)
            bh:SetPoint("CENTER", iconFrame, "CENTER", 0.5, 1)
            bh:SetTexture("Interface\Buttons\UI-ActionButton-Border")
            bh:SetBlendMode("ADD")
            bh:SetAlpha(1.0)
            bh:SetVertexColor(1, 0.82, 0, 1)
            bh:SetDrawLayer("OVERLAY", 7)
            bh:Hide()
            iconFrame.buffHighlight = bh

            iconFrame:SetScript("OnEnter", function()
                if this.itemID then
                    ConsumesManagerBar_ShowTooltip(this, frame.barID)
                end
            end)
            iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

            iconFrame:EnableMouse(true)
            iconFrame:SetScript("OnMouseDown", function()
                if not this.itemID then return end
                if arg1 == "RightButton" and editMode then
                    ShowBarContextMenu(this, this.itemID)
                end
            end)
            iconFrame:SetScript("OnMouseUp", function()
                if not this.itemID then return end
                if arg1 == "LeftButton" and not editMode then
                    ConsumesManagerBar_UseItem(this.itemID)
                end
            end)

            frame.icons[i] = iconFrame
        end

        -- Disable mouse on any legacy child arrow frames from old code
        iconFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
        if iconFrame.leftArrow then
            iconFrame.leftArrow:EnableMouse(false)
            iconFrame.leftArrow:Hide()
        end
        if iconFrame.rightArrow then
            iconFrame.rightArrow:EnableMouse(false)
            iconFrame.rightArrow:Hide()
        end

        -- Position icon (clear first to prevent anchor accumulation across updates)
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("LEFT", frame, "LEFT",
            (i - 1) * (icoS + icoSp) + icoSp, 0)

        iconFrame.itemID = item.id
        iconFrame.icon:SetTexture(item.texture)

        if item.count > 1 then
            iconFrame.count:SetText(item.count)
        else
            iconFrame.count:SetText("")
        end

        ConsumesManagerBar_UpdateIconTimerDisplay(iconFrame, item)

        if item.buffed then
            iconFrame.icon:SetDesaturated(false)
            local bd = ConsumesManagerBar_GetItemBuffData(item.id)
            if bd and bd.weaponEnchantName then
                local _, ec = ConsumesManagerBar_HasWeaponEnchant(item.id)
                iconFrame.buffHighlight:SetVertexColor(
                    ec == 2 and 0 or 1,
                    ec == 2 and 1 or 0.82,
                    0, 1)
            else
                iconFrame.buffHighlight:SetVertexColor(1, 0.82, 0, 1)
            end
            iconFrame.buffHighlight:Show()
        elseif item.count > 0 then
            iconFrame.icon:SetDesaturated(false)
            iconFrame.buffHighlight:Hide()
        else
            iconFrame.icon:SetDesaturated(true)
            if iconFrame.count:GetText() ~= "" then
                iconFrame.count:SetTextColor(0.5, 0.5, 0.5)
            end
            iconFrame.buffHighlight:Hide()
        end

        ConsumesManagerBar_UpdateGlowForIcon(iconFrame, item)
        iconFrame:Show()
    end

    -- SWAP BUTTONS: parented to UIParent (not bar frame) so they aren't
    -- clipped by the bar frame's bounding box. One button per adjacent pair,
    -- positioned just above the gap between icon i and icon i+1.
    local swapSize = math.max(12, math.floor(16 * scale))
    for i = 1, itemCount - 1 do
        local sb = frame.swapBtns[i]
        if not sb then
            sb = CreateFrame("Button", frame:GetName() .. "Swap" .. i, UIParent)
            sb:SetFrameStrata("HIGH")
            sb:SetNormalTexture("Interface\Buttons\UI-MicroButton-MainMenu-Up")
            sb:SetHighlightTexture("Interface\Buttons\UI-MicroButton-MainMenu-Up")
            sb:SetPushedTexture("Interface\Buttons\UI-MicroButton-MainMenu-Down")
            -- Draw a simple swap icon: two small triangles using FontString
            local lbl = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetAllPoints(sb)
            lbl:SetText("<>")
            lbl:SetTextColor(1, 1, 0)
            sb.lbl = lbl
            sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            frame.swapBtns[i] = sb
        end

        sb:SetWidth(swapSize)
        sb:SetHeight(swapSize)
        if sb.lbl then
            sb.lbl:SetFont("Fonts\FRIZQT__.TTF", math.max(8, math.floor(10 * scale)), "OUTLINE")
        end
        sb:ClearAllPoints()

        -- Center of gap between icon i right edge and icon i+1 left edge
        local gapCenterX = (i - 1) * (icoS + icoSp) + icoSp + icoS + icoSp * 0.5
        sb:SetPoint("BOTTOM", frame, "TOPLEFT", gapCenterX, 3)

        -- Capture current item IDs for this gap
        local idL = items[i].id
        local idR = items[i + 1].id

        sb:SetScript("OnClick", function()
            ConsumesManagerBar_MoveItemRight(idL, barID)
        end)

        sb:SetScript("OnEnter", function()
            local nL = consumablesList[idL] or tostring(idL)
            local nR = consumablesList[idR] or tostring(idR)
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Swap order")
            GameTooltip:AddLine(nL .. " <-> " .. nR, 1, 1, 1)
            GameTooltip:Show()
        end)

        if editMode then sb:Show() else sb:Hide() end
    end

    -- Resize / show-hide bar
    if itemCount > 0 then
        frame:SetWidth(itemCount * (icoS + icoSp) + icoSp)
        frame:Show()
    else
        frame:Hide()
    end
end
-- ============================================================
-- ICON TIMER DISPLAY
-- ============================================================

function ConsumesManagerBar_UpdateIconTimerDisplay(iconFrame, item)
    if not (item.buffed and item.timeLeft) then
        iconFrame.timeText:SetText("")
        iconFrame.timeText:SetAlpha(1.0)
        if iconFrame.count:GetText() ~= "" then
            iconFrame.count:SetTextColor(1, 1, 1)
            iconFrame.count:SetAlpha(1.0)
        end
        pulsingTimers[item.id] = nil
        return
    end

    local tl = item.timeLeft

    if tl == -1 then
        -- Weapon enchant / permanent
        iconFrame.timeText:SetText("Active")
        iconFrame.timeText:SetTextColor(0, 1, 0)
        iconFrame.timeText:SetAlpha(1.0)
        if iconFrame.count:GetText() ~= "" then
            iconFrame.count:SetTextColor(0, 1, 0)
            iconFrame.count:SetAlpha(1.0)
        end
        pulsingTimers[item.id] = nil
        if iconFrame.buffHighlight then
            iconFrame.buffHighlight:SetVertexColor(1, 0.82, 0, 1)
            iconFrame.buffHighlight:SetAlpha(1.0)
        end
    elseif tl > 0 then
        iconFrame.timeText:SetText(ConsumesManagerBar_FormatTime(tl))
        local function setPulse()
            if not pulsingTimers[item.id] then
                pulsingTimers[item.id] = {
                    frame = iconFrame, lastUpdate = 0,
                    direction = 1, timeLeft = tl
                }
            else
                pulsingTimers[item.id].frame   = iconFrame
                pulsingTimers[item.id].timeLeft = tl
            end
        end
        if tl < 30 then
            iconFrame.timeText:SetTextColor(1, 0, 0)
            if iconFrame.count:GetText() ~= "" then
                iconFrame.count:SetTextColor(1, 0, 0)
            end
            setPulse()
            if iconFrame.buffHighlight then
                iconFrame.buffHighlight:SetVertexColor(1, 0.3, 0.3, 1)
            end
        elseif tl < 120 then
            iconFrame.timeText:SetTextColor(1, 1, 0)
            if iconFrame.count:GetText() ~= "" then
                iconFrame.count:SetTextColor(1, 1, 0)
            end
            setPulse()
            if iconFrame.buffHighlight then
                iconFrame.buffHighlight:SetVertexColor(1, 0.82, 0, 1)
            end
        else
            iconFrame.timeText:SetTextColor(1, 1, 0)
            iconFrame.timeText:SetAlpha(1.0)
            if iconFrame.count:GetText() ~= "" then
                iconFrame.count:SetTextColor(0, 1, 0)
                iconFrame.count:SetAlpha(1.0)
            end
            pulsingTimers[item.id] = nil
            if iconFrame.buffHighlight then
                iconFrame.buffHighlight:SetVertexColor(1, 1, 1, 1)
                iconFrame.buffHighlight:SetAlpha(1.0)
            end
        end
    else
        -- tl == 0
        iconFrame.timeText:SetText("")
        iconFrame.timeText:SetAlpha(1.0)
        if iconFrame.count:GetText() ~= "" then
            iconFrame.count:SetTextColor(1, 1, 1)
            iconFrame.count:SetAlpha(1.0)
        end
        pulsingTimers[item.id] = nil
    end
end

-- ============================================================
-- MIGRATION (old 2-bar iconVisibility -> new itemBar system)
-- ============================================================

local function MigrateLegacyData()
    if ConsumesManagerBar_Settings2._migrated then return end
    if not ConsumesManagerBar_Settings2.iconVisibility then
        ConsumesManagerBar_Settings2._migrated = true
        return
    end

    -- Ensure we have at least 2 bars
    local bars = GetBars()
    if table.getn(bars) < 2 then
        table.insert(bars, { id = "bar2", name = "Bar 2" })
    end

    -- Migrate old positions
    if ConsumesManagerBar_Settings2.barPosition then
        bars[1].position = ConsumesManagerBar_Settings2.barPosition
    end
    if ConsumesManagerBar_Settings2.disabledBarPosition and bars[2] then
        bars[2].position = ConsumesManagerBar_Settings2.disabledBarPosition
    end

    -- Migrate item assignments
    if not ConsumesManagerBar_Settings2.itemBar then
        ConsumesManagerBar_Settings2.itemBar = {}
    end
    for itemID, isHidden in pairs(ConsumesManagerBar_Settings2.iconVisibility) do
        if isHidden then
            ConsumesManagerBar_Settings2.itemBar[itemID] = "bar2"
        end
    end

    ConsumesManagerBar_Settings2.iconVisibility        = nil
    ConsumesManagerBar_Settings2.barPosition           = nil
    ConsumesManagerBar_Settings2.disabledBarPosition   = nil
    ConsumesManagerBar_Settings2._migrated             = true
end

-- ============================================================
-- INITIALIZE
-- ============================================================

function ConsumesManagerBar_Initialize()
    if ConsumesManagerBar_Settings2.scale == nil then
        ConsumesManagerBar_Settings2.scale = 1.0
    end

    MigrateLegacyData()

    -- Build WoW frames for all saved bars
    for _, bar in ipairs(GetBars()) do
        if not barFrames[bar.id] then
            barFrames[bar.id] = CreateBarFrameForBar(bar)
        end
    end

    ConsumesManagerBar_LoadCustomPriorities()
    ConsumesManagerBar_LoadGlowSettings()
    ConsumesManagerBar_LoadTextureCache()

    -- Apply mouseover mode startup state
    mouseoverMode = ConsumesManagerBar_Settings2.mouseoverMode or false
    if mouseoverMode then
        ConsumesManagerBar_SetAllBarsAlpha(0)
        ConsumesManagerBar_CreateMouseoverHitFrame()
    end

    -- Attach OnUpdate to the primary bar's frame
    local primaryFrame = barFrames[GetBars()[1].id]
    if primaryFrame then
        primaryFrame:SetScript("OnUpdate", function()
            if not this.lastBarUpdate then this.lastBarUpdate = GetTime() end
            if GetTime() - this.lastBarUpdate > 0.5 then
                ConsumesManagerBar_UpdateBars()
                if mouseoverMode then
                    ConsumesManagerBar_UpdateMouseoverHitFrame()
                end
                this.lastBarUpdate = GetTime()
            end

            if not this.lastTexRefresh then this.lastTexRefresh = GetTime() end
            if GetTime() - this.lastTexRefresh > 10 then
                ConsumesManagerBar_RefreshItemTextures()
                this.lastTexRefresh = GetTime()
            end

            ConsumesManagerBar_UpdatePulseAnimation()
        end)
    end

    if ConsumesManagerBar_IsGlowAvailable() then
        DEFAULT_CHAT_FRAME:AddMessage(
            "ConsumesManagerBar loaded! DoiteGlow detected.")
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "ConsumesManagerBar loaded! (fallback glow mode)")
    end
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

SLASH_CONSUMESBAR1 = "/cmbar"
SLASH_CONSUMESBAR2 = "/consumesbar"
SlashCmdList["CONSUMESBAR"] = function(msg)
    if not next(barFrames) then ConsumesManagerBar_Initialize(); return end
    local anyShown = false
    for _, f in pairs(barFrames) do
        if f:IsShown() then anyShown = true; break end
    end
    if anyShown then
        for _, f in pairs(barFrames) do f:Hide() end
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: hidden. /cmbar to show.")
    else
        ConsumesManagerBar_UpdateBars()
        DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: shown.")
    end
end

SLASH_CONSUMESBAREDIT1 = "/cmbaredit"
SLASH_CONSUMESBAREDIT2 = "/consumesbaredit"
SlashCmdList["CONSUMESBAREDIT"] = function(msg)
    if not next(barFrames) then ConsumesManagerBar_Initialize() end
    ConsumesManagerBar_ToggleEditMode()
end

SLASH_CONSUMESBARRESET1 = "/cmbarreset"
SLASH_CONSUMESBARRESET2 = "/consumesbarreset"
SlashCmdList["CONSUMESBARRESET"] = function(msg)
    for i, bar in ipairs(GetBars()) do
        bar.position = nil
        local f = barFrames[bar.id]
        if f then
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER", 0, (i - 1) * -55)
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("ConsumesManagerBar: All positions reset.")
end

SLASH_CONSUMESBARSCALE1 = "/cmbarscale"
SLASH_CONSUMESBARSCALE2 = "/consumesbarscale"
SlashCmdList["CONSUMESBARSCALE"] = function(msg)
    if not next(barFrames) then ConsumesManagerBar_Initialize() end
    local v = tonumber(msg)
    if v then
        ConsumesManagerBar_SetScale(v)
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "Scale: " .. string.format("%.1f",
            ConsumesManagerBar_Settings2.scale or 1.0))
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /cmbarscale 0.5-2.0")
    end
end

SLASH_CONSUMESBARRESETORDER1 = "/cmbarresetorder"
SlashCmdList["CONSUMESBARRESETORDER"] = function()
    ConsumesManagerBar_ResetAllCustomPriorities()
end

SLASH_CONSUMESBARRESETGLOW1 = "/cmbarresetglow"
SlashCmdList["CONSUMESBARRESETGLOW"] = function()
    ConsumesManagerBar_ResetAllGlowSettings()
end

SLASH_CMBARMOUSEOVER1 = "/cmbarmouseover"
SLASH_CMBARMOUSEOVER2 = "/consumesbarmouseover"
SlashCmdList["CMBARMOUSEOVER"] = function()
    if not next(barFrames) then ConsumesManagerBar_Initialize() end
    ConsumesManagerBar_ToggleMouseoverMode()
end

-- ============================================================
-- BOOT
-- ============================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if not ConsumesManagerBar_Settings2 then
            ConsumesManagerBar_Settings2 = {}
        end
        ConsumesManagerBar_Initialize()
    end
end)