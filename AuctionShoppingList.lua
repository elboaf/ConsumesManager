---------------------------------------------------------------
-- AuctionShoppingList.lua
-- Panel below the AH (aux or vanilla) listing selected consumes.
-- Left-click a row to search AH. Right-click a consume to
-- expand/collapse its mats. [-]/[+] button in header to
-- collapse/expand the whole panel.
-- WoW 1.12 / Turtle WoW | Lua 5.0
---------------------------------------------------------------

local ROW_HEIGHT     = 18
local HEADER_HEIGHT  = 20
local PANEL_WIDTH    = 380
local ROWS_DISPLAYED = 10
local MAT_INDENT     = 14

-- ============================================================
-- STATE
-- ============================================================
local displayList    = {}
local consumeState   = {}   -- [item.id] = true/false (expanded)
local scrollPos      = 0
local contentVisible = true -- persists across open/close within session

local panel      = nil
local rowFrames  = {}

-- ============================================================
-- INVENTORY HELPER
-- ============================================================
local function GetConsumeCount(itemID)
    local realmName = GetRealmName()
    local total     = 0
    if not ConsumesManager_Data or not ConsumesManager_Data[realmName] then
        return 0
    end
    for character, charData in pairs(ConsumesManager_Data[realmName]) do
        if type(charData) == "table" and character ~= "faction"
        and ConsumesManager_Options
        and ConsumesManager_Options["Characters"]
        and ConsumesManager_Options["Characters"][character] == true then
            local inv  = charData["inventory"] and charData["inventory"][itemID] or 0
            local bank = charData["bank"]      and charData["bank"][itemID]      or 0
            local mail = charData["mail"]      and charData["mail"][itemID]      or 0
            total = total + inv + bank + mail
        end
    end
    return total
end

-- ============================================================
-- MAT HELPERS
-- ============================================================
local function IsAuctionableMat(s)
    if string.find(s, "^Quest:")       then return false end
    if string.find(s, "^Reagents:")    then return false end
    if string.find(s, "^Looted")       then return false end
    if string.find(s, "^Drops")        then return false end
    if string.find(s, "^Bought")       then return false end
    if string.find(s, "^Conjured")     then return false end
    if string.find(s, "^Diverse")      then return false end
    if string.find(s, "^Gardening:")   then return false end
    if string.find(s, "^Love")         then return false end
    if string.find(s, "^Argent")       then return false end
    if string.find(s, "^Red Power")    then return false end
    if string.find(s, "^Dream Dust %(") then return false end
    if string.find(s, "^Firebloom,")   then return false end
    return true
end

local function ParseMatString(s)
    local _, _, amount, name = string.find(s, "^(%d+)x?%s+(.+)$")
    if name then return name, tonumber(amount) end
    return s, 1
end

local function GetItemMats(item)
    local mats = {}
    if not item.mats then return mats end
    for _, matStr in ipairs(item.mats) do
        if IsAuctionableMat(matStr) then
            local name, amount = ParseMatString(matStr)
            table.insert(mats, { name = name, amount = amount })
        end
    end
    return mats
end

-- ============================================================
-- REBUILD DISPLAY LIST
-- ============================================================

-- Build a flat item lookup: itemID -> item, for fast access
local function BuildItemLookup()
    local lookup = {}
    if not consumablesCategories then return lookup end
    for _, items in pairs(consumablesCategories) do
        for _, item in ipairs(items) do
            lookup[item.id] = item
        end
    end
    return lookup
end

local function RebuildDisplayList()
    displayList = {}
    if not consumablesCategories then return end

    local isManager = ConsumesManager_CharOptions and ConsumesManager_CharOptions.isManager

    -- If manager but no data loaded yet, trigger a read now
    if isManager and CM_FileSync and (not CM_FileSync.charData or next(CM_FileSync.charData) == nil) then
        if CM_FileSync.ReadAll then CM_FileSync.ReadAll() end
    end

    local hasFileData = isManager
        and CM_FileSync
        and CM_FileSync.charData
        and next(CM_FileSync.charData) ~= nil

    if hasFileData then
        -- --------------------------------------------------------
        -- MANAGER MODE: flat list of all configured consumes across
        -- all characters. Count = total across all characters.
        -- Missing items (total=0) float to the top.
        -- --------------------------------------------------------
        local itemLookup = BuildItemLookup()
        local charNames  = CM_FileSync_GetCharNames and CM_FileSync_GetCharNames() or {}

        -- Collect union of all configured items with total counts
        local totals = {}  -- [itemID] = total count across all chars
        for _, charName in ipairs(charNames) do
            local charData = CM_FileSync.charData[charName]
            if charData then
                for itemID, entry in pairs(charData.items) do
                    if entry.configured then
                        totals[itemID] = (totals[itemID] or 0) + entry.count
                    end
                end
            end
        end

        -- Also include inventory from ALL characters (not just configured ones)
        -- so the total count reflects full stock even from non-configuring chars
        for _, charName in ipairs(charNames) do
            local charData = CM_FileSync.charData[charName]
            if charData then
                for itemID, entry in pairs(charData.items) do
                    if totals[itemID] ~= nil and not entry.configured then
                        -- This char has stock of something another char uses
                        totals[itemID] = totals[itemID] + entry.count
                    end
                end
            end
        end

        -- Build sorted list: by count asc, then non-bop before bop, then by name
        local rows = {}
        for itemID, total in pairs(totals) do
            local item = itemLookup[itemID]
            if item then
                table.insert(rows, { item = item, count = total, isBop = item.bop == true })
            end
        end
        table.sort(rows, function(a, b)
            -- BOP items always below non-BOP
            local aBop = a.isBop and 1 or 0
            local bBop = b.isBop and 1 or 0
            if aBop ~= bBop then return aBop < bBop end
            -- Within same group: count ascending
            if a.count ~= b.count then return a.count < b.count end
            return a.item.name < b.item.name
        end)

        for _, entry in ipairs(rows) do
            local item  = entry.item
            local mats  = GetItemMats(item)
            local isBop = item.bop == true

            if isBop then
                -- BOP items: per-character breakdown so we know
                -- how many reagents each toon needs individually
                for _, charName in ipairs(charNames) do
                    local charData = CM_FileSync.charData[charName]
                    if charData then
                        local charEntry = charData.items[item.id]
                        if charEntry and charEntry.configured then
                            local count   = charEntry.count
                            local autoExp = table.getn(mats) == 1
                            local key     = "mgr_bop_" .. charName .. item.id
                            table.insert(displayList, {
                                type      = "consume",
                                item      = item,
                                count     = count,
                                expanded  = consumeState[key] or autoExp,
                                bop       = true,
                                singleMat = table.getn(mats) == 1 and mats[1] or nil,
                                stateKey  = key,
                                charLabel = charName,
                            })
                            if consumeState[key] then
                                for _, mat in ipairs(mats) do
                                    table.insert(displayList, {
                                        type        = "mat",
                                        name        = mat.name,
                                        amount      = mat.amount,
                                        auctionable = mat.auctionable,
                                    })
                                end
                            end
                        end
                    end
                end
            else
                -- Normal item: show total count
                local count   = entry.count
                local autoExp = false
                local key     = "mgr" .. item.id
                table.insert(displayList, {
                    type      = "consume",
                    item      = item,
                    count     = count,
                    expanded  = consumeState[key] or autoExp,
                    bop       = false,
                    singleMat = nil,
                    stateKey  = key,
                })
                if consumeState[key] then
                    for _, mat in ipairs(mats) do
                        table.insert(displayList, {
                            type        = "mat",
                            name        = mat.name,
                            amount      = mat.amount,
                            auctionable = mat.auctionable,
                        })
                    end
                end
            end
        end

    else
        -- --------------------------------------------------------
        -- NORMAL MODE: show own selected consumes as before
        -- --------------------------------------------------------
        if not ConsumesManager_SelectedItems then return end

        -- Collect into rows first so we can sort
        local rows = {}
        for _, items in pairs(consumablesCategories) do
            for _, item in ipairs(items) do
                if ConsumesManager_SelectedItems[item.id] then
                    local count = GetConsumeCount(item.id)
                    table.insert(rows, { item = item, count = count })
                end
            end
        end

        -- Sort by count ascending, then by name
        table.sort(rows, function(a, b)
            if a.count ~= b.count then return a.count < b.count end
            return a.item.name < b.item.name
        end)

        for _, entry in ipairs(rows) do
            local item    = entry.item
            local count   = entry.count
            local mats    = GetItemMats(item)
            local isBop   = item.bop == true
            local autoExp = isBop and table.getn(mats) == 1
            table.insert(displayList, {
                type      = "consume",
                item      = item,
                count     = count,
                expanded  = consumeState[tostring(item.id)] or autoExp,
                bop       = isBop,
                singleMat = isBop and table.getn(mats) == 1 and mats[1] or nil,
                stateKey  = tostring(item.id),
            })
            if consumeState[tostring(item.id)] then
                for _, mat in ipairs(mats) do
                    table.insert(displayList, {
                        type        = "mat",
                        name        = mat.name,
                        amount      = mat.amount,
                        auctionable = mat.auctionable,
                    })
                end
            end
        end
    end
end

-- ============================================================
-- AH SEARCH
-- ============================================================

-- Look up an item ID from consumablesCategories by name.
-- Handles edge case 1: concoction reagents that are themselves
-- tracked consumes (e.g. "Winterfall Firewater", "Dreamtonic").
local function GetIDFromItemlist(name)
    if not consumablesCategories then return nil end
    for _, items in pairs(consumablesCategories) do
        for _, item in ipairs(items) do
            if item.name == name and item.id then
                return item.id
            end
        end
    end
    return nil
end

-- Returns the resolved item ID for a mat name, or nil if none known.
-- Returns the string "search" if MatIDs explicitly marks it as name-search only.
local function ResolveMatID(name)
    if CM_MatIDs and CM_MatIDs[name] ~= nil then
        return CM_MatIDs[name]  -- may be a number or the string "search"
    end
    return GetIDFromItemlist(name)  -- fallback: check consumables list
end

local function BuildItemLink(name, itemID)
    local id = itemID or ResolveMatID(name)
    if not id or id == "search" then return nil end
    local itemName, _, quality = GetItemInfo(id)
    if not itemName then
        return string.format("|cffffff00|Hitem:%d:0:0:0|h[%s]|h|r", id, name)
    end
    local r, g, b = GetItemQualityColor(quality or 1)
    local hex = string.format("%02x%02x%02x",
        math.floor((r or 1) * 255),
        math.floor((g or 1) * 255),
        math.floor((b or 1) * 255))
    return string.format("|cff%s|Hitem:%d:0:0:0|h[%s]|h|r", hex, id, itemName)
end

-- Returns the aux search editbox and search button by walking the known frame hierarchy
local function GetAuxSearchFrames()
    if not aux_frame then return nil, nil end
    local topChildren = {aux_frame:GetChildren()}
    if not topChildren[4] then return nil, nil end
    local tabChildren = {topChildren[4]:GetChildren()}
    return tabChildren[11], tabChildren[8]  -- EditBox=11, SearchButton=8
end

-- Performs a name-only AH search
local function SearchByName(name)
    if aux_frame and aux_frame:IsVisible() then
        local searchBox, searchBtn = GetAuxSearchFrames()
        if searchBox and searchBtn then
            searchBox:SetText(name)
            searchBtn:Click()
            return
        end
    end
    if CanSendAuctionQuery and CanSendAuctionQuery()
    and AuctionFrame and AuctionFrame:IsVisible() then
        BrowseName:SetText(name)
        AuctionFrameBrowse_Search()
        BrowseNoResultsText:SetText(BROWSE_NO_RESULTS)
    end
end

local function SearchAuction(name, itemID)
    -- "search" sentinel: always do a plain name search
    local resolvedID = itemID or ResolveMatID(name)
    if resolvedID == "search" then
        SearchByName(name)
        return
    end

    local link = BuildItemLink(name, itemID)

    if aux_frame and aux_frame:IsVisible() then
        local ok,  aux  = pcall(require, "aux")
        local ok2, info = pcall(require, "aux.util.info")
        if ok and ok2 then
            local tab = aux.get_tab and aux.get_tab()
            if link and tab and tab.CLICK_LINK then
                local _, _, _id = string.find(link, "item:(%d+)") local id = tonumber(_id)
                if id then
                    local item_info = info.item(id)
                    if item_info then
                        tab.CLICK_LINK(item_info)
                        return
                    end
                end
            end
            -- item_info not cached yet, fall back to name search within aux
            local searchBox, searchBtn = GetAuxSearchFrames()
            if searchBox and searchBtn then
                searchBox:SetText(name)
                searchBtn:Click()
                return
            end
        end
    end

    -- Vanilla AH fallback
    if CanSendAuctionQuery and CanSendAuctionQuery()
    and AuctionFrame and AuctionFrame:IsVisible() then
        BrowseName:SetText(name)
        AuctionFrameBrowse_Search()
        BrowseNoResultsText:SetText(BROWSE_NO_RESULTS)
    end
end



-- ============================================================
-- PANEL CONTENT SHOW/HIDE (collapses rows, resizes panel)
-- ============================================================
local function ApplyContentVisible()
    if not panel then return end

    for i = 1, ROWS_DISPLAYED do
        if rowFrames[i] then rowFrames[i]:Hide() end
    end

    if contentVisible then
        panel:SetHeight(ROWS_DISPLAYED * ROW_HEIGHT + HEADER_HEIGHT + 16)
        if panel.btnUp     then panel.btnUp:Show()     end
        if panel.btnDown   then panel.btnDown:Show()   end
        if panel.scrollBar then panel.scrollBar:Show() end
        if panel.toggleBtn then panel.toggleBtn:SetText("[-]") end
        CM_AuctionShoppingList_Update()
    else
        panel:SetHeight(HEADER_HEIGHT + 8)
        if panel.btnUp     then panel.btnUp:Hide()     end
        if panel.btnDown   then panel.btnDown:Hide()   end
        if panel.scrollBar then panel.scrollBar:Hide() end
        if panel.toggleBtn then panel.toggleBtn:SetText("[+]") end
    end
end

-- ============================================================
-- CREATE PANEL
-- ============================================================
local function CreatePanel()
    if panel then return end

    panel = CreateFrame("Frame", "CM_AuctionShoppingListPanel", UIParent)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetHeight(ROWS_DISPLAYED * ROW_HEIGHT + HEADER_HEIGHT + 16)
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:Hide()

    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    panel:SetBackdropColor(0, 0, 0, 1)
    panel:SetBackdropBorderColor(1, 1, 1, 1)

    -- Solid opaque background texture underneath everything
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(0, 0, 0, 1)
    bg:SetPoint("TOPLEFT",     panel, "TOPLEFT",     5,  -5)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5,   5)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)
    title:SetText("|cffffff00Consumes Shopping List|r")

    -- Toggle [-]/[+] button in the header, right side
    local toggleBtn = CreateFrame("Button", nil, panel)
    toggleBtn:SetWidth(22)
    toggleBtn:SetHeight(14)
    toggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -5)

    local toggleLabel = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toggleLabel:SetAllPoints(toggleBtn)
    toggleLabel:SetJustifyH("CENTER")
    toggleLabel:SetText("[-]")
    toggleBtn:SetScript("OnClick", function()
        contentVisible = not contentVisible
        ApplyContentVisible()
    end)

    local toggleHl = toggleBtn:CreateTexture(nil, "HIGHLIGHT")
    toggleHl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    toggleHl:SetBlendMode("ADD")
    toggleHl:SetAllPoints(toggleBtn)

    panel.toggleBtn = toggleBtn

    -- Scroll up
    local btnUp = CreateFrame("Button", nil, panel)
    btnUp:SetWidth(16)
    btnUp:SetHeight(16)
    btnUp:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -(HEADER_HEIGHT + 2))
    btnUp:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    btnUp:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
    btnUp:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
    btnUp:SetScript("OnClick", function()
        if scrollPos > 0 then
            scrollPos = scrollPos - 1
            CM_AuctionShoppingList_Update()
        end
    end)
    panel.btnUp = btnUp

    -- Scroll down
    local btnDown = CreateFrame("Button", nil, panel)
    btnDown:SetWidth(16)
    btnDown:SetHeight(16)
    btnDown:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 6)
    btnDown:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    btnDown:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    btnDown:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    btnDown:SetScript("OnClick", function()
        local maxScroll = math.max(0, table.getn(displayList) - ROWS_DISPLAYED)
        if scrollPos < maxScroll then
            scrollPos = scrollPos + 1
            CM_AuctionShoppingList_Update()
        end
    end)
    panel.btnDown = btnDown

    -- Scrollbar
    local scrollBar = CreateFrame("Slider", "CM_AHSLScrollBar", panel)
    scrollBar:SetWidth(16)
    scrollBar:SetPoint("TOPRIGHT",    panel, "TOPRIGHT", -4, -(HEADER_HEIGHT + 20))
    scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 28)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)

    scrollBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile     = true, tileSize = 8, edgeSize = 8,
        insets   = { left = 3, right = 3, top = 6, bottom = 6 }
    })

    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    thumb:SetWidth(16)
    thumb:SetHeight(32)
    scrollBar:SetThumbTexture(thumb)

    scrollBar:SetScript("OnValueChanged", function()
        local newPos = math.floor(arg1 + 0.5)
        if newPos ~= scrollPos then
            scrollPos = newPos
            CM_AuctionShoppingList_Update()
        end
    end)

    panel.scrollBar = scrollBar

    -- Mousewheel
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function()
        if not contentVisible then return end
        local maxScroll = math.max(0, table.getn(displayList) - ROWS_DISPLAYED)
        if arg1 > 0 then
            scrollPos = math.max(0, scrollPos - 1)
        else
            scrollPos = math.min(maxScroll, scrollPos + 1)
        end
        CM_AuctionShoppingList_Update()
    end)

    -- Row frames
    for i = 1, ROWS_DISPLAYED do
        local row = CreateFrame("Button", "CM_AHSLRow" .. i, panel)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT",  panel, "TOPLEFT",  7,  -(HEADER_HEIGHT + (i - 1) * ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -(HEADER_HEIGHT + (i - 1) * ROW_HEIGHT))

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(row)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(ROW_HEIGHT - 2)
        icon:SetHeight(ROW_HEIGHT - 2)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon = icon

        local arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        arrow:SetWidth(16)
        arrow:SetJustifyH("RIGHT")
        row.arrow = arrow

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", icon, "RIGHT", 3, 0)
        label:SetWidth(PANEL_WIDTH - 55)
        label:SetJustifyH("LEFT")
        row.label = label

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function()
            if not row.entry then return end
            if arg1 == "RightButton" and row.entry.type == "consume" then
                local key = row.entry.stateKey or tostring(row.entry.item.id)
                consumeState[key] = not consumeState[key]
                RebuildDisplayList()
                CM_AuctionShoppingList_Update()
            elseif arg1 == "LeftButton" then
                if row.entry.type == "consume" then
                    if row.entry.singleMat then
                        SearchAuction(row.entry.singleMat.name)
                    elseif row.entry.bop then
                        local key = row.entry.stateKey or tostring(row.entry.item.id)
                        consumeState[key] = not consumeState[key]
                        RebuildDisplayList()
                        CM_AuctionShoppingList_Update()
                    else
                        SearchAuction(row.entry.item.name, row.entry.item.id)
                    end
                elseif row.entry.type == "mat" then
                    SearchAuction(row.entry.name)
                end
            end
        end)

        row:SetScript("OnEnter", function()
            if not row.entry then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            if row.entry.type == "consume" then
                GameTooltip:SetHyperlink("item:" .. row.entry.item.id)
                GameTooltip:AddLine(" ")
                if row.entry.singleMat then
                    GameTooltip:AddLine("|cffaaaaaaLeft-click: search " .. row.entry.singleMat.name .. "|r")
                elseif row.entry.bop then
                    GameTooltip:AddLine("|cffff4444Not on AH|r")
                    GameTooltip:AddLine("|cffaaaaaaLeft-click: show mats|r")
                    GameTooltip:AddLine("|cffaaaaaaRight-click: show mats|r")
                else
                    GameTooltip:AddLine("|cffaaaaaaLeft-click: search AH|r")
                    GameTooltip:AddLine("|cffaaaaaaRight-click: show mats|r")
                end
            elseif row.entry.type == "mat" then
                local id = row.entry.auctionable ~= false and ResolveMatID(row.entry.name) or nil
                if id and id ~= "search" and type(id) == "number" then
                    GameTooltip:SetHyperlink("item:" .. id)
                else
                    GameTooltip:SetText(row.entry.name)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffaaaaaaLeft-click: search AH|r")
            end
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:Hide()
        rowFrames[i] = row
    end
end

-- ============================================================
-- UPDATE ROWS
-- ============================================================
function CM_AuctionShoppingList_Update()
    if not panel or not panel:IsShown() or not contentVisible then return end

    local total = table.getn(displayList)

    for i = 1, ROWS_DISPLAYED do
        local row   = rowFrames[i]
        local entry = displayList[scrollPos + i]

        if entry then
            row.entry = entry

            if entry.type == "section" then
                -- Character section header
                row.icon:Hide()
                row.arrow:SetText("")
                row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.label:SetText("|cffffff00" .. entry.charName .. "|r")
                row:Show()

            elseif entry.type == "consume" then
                local item    = entry.item
                local texture = ConsumesManagerBar_GetItemTexture(item.id)
                row.icon:SetTexture(texture)
                row.icon:Show()
                row.label:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)

                local mats = GetItemMats(item)
                if table.getn(mats) > 0 then
                    row.arrow:SetText(entry.expanded and "|cffaaaaaa[-]|r" or "|cffaaaaaa[+]|r")
                else
                    row.arrow:SetText("")
                end

                local nameColor = entry.count == 0 and "ff4444" or "ffffff"
                local countStr  = entry.count == 0
                    and "|cffff4444[0]|r"
                    or  "|cff44ff44[" .. entry.count .. "]|r"
                local charSuffix = entry.charLabel
                    and " |cff888888(" .. entry.charLabel .. ")|r"
                    or ""
                row.label:SetText("|cff" .. nameColor .. item.name .. "|r " .. countStr .. charSuffix)

            elseif entry.type == "mat" then
                row.icon:Hide()
                row.arrow:SetText("")
                row.label:SetPoint("LEFT", row, "LEFT", MAT_INDENT, 0)

                local id    = CM_MatIDs and CM_MatIDs[entry.name]
                local color = "aaaaaa"
                if id then
                    local _, _, quality = GetItemInfo(id)
                    if quality then
                        local r, g, b = GetItemQualityColor(quality)
                        color = string.format("%02x%02x%02x",
                            math.floor((r or 1) * 255),
                            math.floor((g or 1) * 255),
                            math.floor((b or 1) * 255))
                    end
                end
                row.label:SetText("|cff" .. color .. entry.name .. "|r |cff888888x" .. entry.amount .. "|r")
            end

            row:Show()
        else
            row.entry = nil
            row.icon:Hide()
            row.arrow:SetText("")
            row.label:SetText("")
            row:Hide()
        end
    end

    local maxScroll = math.max(0, total - ROWS_DISPLAYED)
    if panel.btnUp   then
        if scrollPos > 0          then panel.btnUp:Enable()   else panel.btnUp:Disable()   end
    end
    if panel.btnDown then
        if scrollPos < maxScroll  then panel.btnDown:Enable() else panel.btnDown:Disable() end
    end
    if panel.scrollBar then
        panel.scrollBar:SetMinMaxValues(0, maxScroll)
        panel.scrollBar:SetValue(scrollPos)
    end
end

-- ============================================================
-- SHOW / HIDE
-- ============================================================
local function GetAnchorFrame()
    if aux_frame and aux_frame:IsVisible() then return aux_frame, "aux" end
    if AuctionFrame and AuctionFrame:IsVisible() then return AuctionFrame, "vanilla" end
    return nil, nil
end

local function ShowPanel()
    if not consumablesCategories or not ConsumesManager_SelectedItems then return end

    RebuildDisplayList()

    local anchor, anchorType = GetAnchorFrame()
    if not anchor then return end

    CreatePanel()
    scrollPos = 0

    panel:ClearAllPoints()
    if anchorType == "aux" then
        panel:SetPoint("TOPRIGHT", aux_frame, "BOTTOMRIGHT", 0, -2)
    else
        panel:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", 2, 0)
    end

    panel:Show()
    ApplyContentVisible()
end

local function HidePanel()
    if panel then panel:Hide() end
end

-- ============================================================
-- EVENTS
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

eventFrame:SetScript("OnEvent", function()
    if event == "AUCTION_HOUSE_SHOW" then
        ShowPanel()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        HidePanel()
    end
end)

function CM_AuctionShoppingList_Refresh()
    RebuildDisplayList()
    if panel and panel:IsShown() then
        scrollPos = 0
        CM_AuctionShoppingList_Update()
    end
end