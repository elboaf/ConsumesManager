---------------------------------------------------------------
-- CM_ManagerView.lua
-- Floating manager stock overview window.
--
-- Tab strip: "Overview" + one tab per loaded character.
--
-- Overview tab:
--   Flat list of all items configured by at least one character.
--   Columns: item name, one column per character, total.
--   Sorted ascending by total count (needs-attention first).
--   No categories, no expand/collapse.
--
-- Character tabs:
--   Flat list of items that character has configured.
--   Columns: item name, count.
--   Sorted ascending by count.
--
-- WoW 1.12 / Turtle WoW | Lua 5.0
---------------------------------------------------------------

CM_ManagerView = {}

-- ============================================================
-- LAYOUT CONSTANTS
-- ============================================================
local ROW_HEIGHT    = 18
local HEADER_HEIGHT = 44   -- title bar + tab strip
local COL_H_HEIGHT  = 18   -- column header row
local ROWS_VISIBLE  = 18
local LABEL_WIDTH   = 220
local COL_WIDTH     = 70
local MIN_WIDTH     = 420

-- ============================================================
-- STATE
-- ============================================================
local frame       = nil
local rowFrames   = {}
local scrollPos   = 0
local activeTab   = "overview"   -- "overview" or charName
local displayList = {}           -- flat list of { item, count, charCounts }
local charNames   = {}           -- sorted list of loaded char names

-- ============================================================
-- COLOR HELPER
-- ============================================================
local function CountColor(count)
    if count == nil  then return "444444" end
    if count == 0    then return "ff4444" end
    if count < 5     then return "ff9944" end
    if count < 20    then return "ffff44" end
    return "44ff44"
end

-- ============================================================
-- BUILD DISPLAY LIST
-- ============================================================
local function BuildDisplayList()
    displayList = {}
    charNames   = CM_FileSync_GetCharNames and CM_FileSync_GetCharNames() or {}

    if not consumablesCategories then return end

    -- Build itemID -> item lookup
    local lookup = {}
    for _, items in pairs(consumablesCategories) do
        for _, item in ipairs(items) do
            lookup[item.id] = item
        end
    end

    if activeTab == "overview" then
        -- Collect all items configured by at least one character
        local seen     = {}
        local rows     = {}

        for _, charName in ipairs(charNames) do
            local data = CM_FileSync.charData[charName]
            if data then
                for itemID, entry in pairs(data.items) do
                    -- Only add row if at least one character has this configured
                    local anyConfigured = false
                    for _, cn in ipairs(charNames) do
                        local d = CM_FileSync.charData[cn]
                        if d and d.items[itemID] and d.items[itemID].configured then
                            anyConfigured = true
                            break
                        end
                    end

                    if anyConfigured and not seen[itemID] then
                        seen[itemID] = true
                        local item = lookup[itemID]
                        if item then
                            -- Build per-char counts (nil = no data, number = count)
                            local charCounts = {}
                            local total = 0
                            for _, cn in ipairs(charNames) do
                                local d = CM_FileSync.charData[cn]
                                local e = d and d.items[itemID]
                                -- Show count if character has the item in inventory,
                                -- even if not configured. nil = no file data at all.
                                charCounts[cn] = e and e.count or (d and 0 or nil)
                                if e then total = total + e.count end
                            end
                            table.insert(rows, {
                                item       = item,
                                charCounts = charCounts,
                                total      = total,
                            })
                        end
                    end
                end
            end
        end

        -- Sort: non-BOP before BOP, within each group by total ascending, then name
        table.sort(rows, function(a, b)
            local aBop = (a.item.bop == true) and 1 or 0
            local bBop = (b.item.bop == true) and 1 or 0
            if aBop ~= bBop then return aBop < bBop end
            if a.total ~= b.total then return a.total < b.total end
            return a.item.name < b.item.name
        end)

        displayList = rows

    else
        -- Character tab: items this character has configured
        local data = CM_FileSync.charData[activeTab]
        if not data then return end

        local rows = {}
        for itemID, entry in pairs(data.items) do
            local item = lookup[itemID]
            if item then
                table.insert(rows, { item = item, count = entry.count, configured = entry.configured })
            end
        end

        -- Sort: non-BOP before BOP, within each group by count ascending, then name
        table.sort(rows, function(a, b)
            local aBop = (a.item.bop == true) and 1 or 0
            local bBop = (b.item.bop == true) and 1 or 0
            if aBop ~= bBop then return aBop < bBop end
            if a.count ~= b.count then return a.count < b.count end
            return a.item.name < b.item.name
        end)

        displayList = rows
    end
end

-- ============================================================
-- UPDATE ROWS
-- ============================================================
function CM_ManagerView_UpdateRows()
    if not frame or not frame:IsShown() then return end

    local total    = table.getn(displayList)
    local colCount = table.getn(charNames)

    for i = 1, ROWS_VISIBLE do
        local row   = rowFrames[i]
        local entry = displayList[scrollPos + i]

        -- Hide all cells
        for _, cell in ipairs(row.cells or {}) do cell:Hide() end

        if entry then
            -- Icon
            local tex = ConsumesManagerBar_GetItemTexture
                and ConsumesManagerBar_GetItemTexture(entry.item.id)
                or entry.item.texture
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            row.icon:SetTexture(tex)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon:Show()
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)

            if activeTab == "overview" then
                -- Name
                row.label:SetText("|cffdddddd" .. entry.item.name .. "|r")

                -- Per-char cells
                row.cells = row.cells or {}
                for j, cn in ipairs(charNames) do
                    local count = entry.charCounts[cn]
                    local cell  = row.cells[j]
                    if not cell then
                        cell = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        cell:SetWidth(COL_WIDTH)
                        cell:SetJustifyH("CENTER")
                        row.cells[j] = cell
                    end
                    cell:ClearAllPoints()
                    cell:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH + (j - 1) * COL_WIDTH, 0)
                    if count == nil then
                        cell:SetText("|cff444444-|r")
                    else
                        cell:SetText("|cff" .. CountColor(count) .. count .. "|r")
                    end
                    cell:Show()
                end

                -- Total cell
                local totCell = row.cells[colCount + 1]
                if not totCell then
                    totCell = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    totCell:SetWidth(COL_WIDTH)
                    totCell:SetJustifyH("CENTER")
                    row.cells[colCount + 1] = totCell
                end
                totCell:ClearAllPoints()
                totCell:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH + colCount * COL_WIDTH, 0)
                totCell:SetText("|cff" .. CountColor(entry.total) .. entry.total .. "|r")
                totCell:Show()

            else
                -- Character tab: just name + count
                local color = CountColor(entry.count)
                row.label:SetText("|cffdddddd" .. entry.item.name .. "|r")

                local cell = row.cells[1]
                if not cell then
                    cell = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    cell:SetWidth(COL_WIDTH)
                    cell:SetJustifyH("CENTER")
                    row.cells[1] = cell
                end
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
                cell:SetText("|cff" .. color .. entry.count .. "|r")
                cell:Show()
            end

            -- Tooltip
            row:SetScript("OnEnter", function()
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. entry.item.id)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:Show()
        else
            row.icon:Hide()
            row.label:SetText("")
            row:Hide()
        end
    end

    -- Scroll controls
    local maxScroll = math.max(0, total - ROWS_VISIBLE)
    if frame.btnUp   then
        if scrollPos > 0         then frame.btnUp:Enable()   else frame.btnUp:Disable()   end
    end
    if frame.btnDown then
        if scrollPos < maxScroll then frame.btnDown:Enable() else frame.btnDown:Disable() end
    end
    if frame.scrollBar then
        frame.scrollBar:SetMinMaxValues(0, maxScroll)
        frame.scrollBar:SetValue(scrollPos)
    end
end

-- ============================================================
-- TAB STRIP
-- ============================================================
function RebuildTabs()
    if not frame then return end

    -- Clear old tabs
    if frame.tabs then
        for _, t in ipairs(frame.tabs) do t:Hide() end
    end
    frame.tabs = {}

    local tabNames = { "Overview" }
    local tabKeys  = { "overview" }
    for _, cn in ipairs(charNames) do
        table.insert(tabNames, cn)
        table.insert(tabKeys, cn)
    end

    local tabX = 8
    for i, label in ipairs(tabNames) do
        local key = tabKeys[i]
        local btn = CreateFrame("Button", nil, frame)
        btn:SetHeight(18)
        btn:SetWidth(string.len(label) * 7 + 16)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", tabX, -22)

        local isActive = (activeTab == key)

        btn:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if isActive then
            btn:SetBackdropColor(0.2, 0.2, 0.4, 1)
        else
            btn:SetBackdropColor(0, 0, 0, 0.8)
        end

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetAllPoints(btn)
        lbl:SetJustifyH("CENTER")
        lbl:SetText(isActive and ("|cffffff00" .. label .. "|r") or ("|cffaaaaaa" .. label .. "|r"))

        local captureKey = key
        btn:SetScript("OnClick", function()
            activeTab = captureKey
            scrollPos = 0
            BuildDisplayList()
            RebuildTabs()
            RebuildColumnHeaders()
            CM_ManagerView_UpdateRows()
        end)

        tabX = tabX + btn:GetWidth() + 3
        table.insert(frame.tabs, btn)
    end
end

-- ============================================================
-- COLUMN HEADERS
-- ============================================================
function RebuildColumnHeaders()
    if not frame then return end

    if frame.colHeaders then
        for _, h in ipairs(frame.colHeaders) do h:Hide() end
    end
    frame.colHeaders = {}

    local colCount = table.getn(charNames)

    if activeTab == "overview" then
        -- Per-character column headers
        for j, cn in ipairs(charNames) do
            local h = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            h:SetWidth(COL_WIDTH)
            h:SetJustifyH("CENTER")
            h:SetPoint("TOPLEFT", frame, "TOPLEFT",
                LABEL_WIDTH + 8 + (j - 1) * COL_WIDTH, -(HEADER_HEIGHT))
            -- Managers in gold, non-managers in grey
            local data = CM_FileSync and CM_FileSync.charData and CM_FileSync.charData[cn]
            local color = (data and data.isManager) and "ffffff00" or "ffaaaaaa"
            h:SetText("|c" .. color .. cn .. "|r")
            table.insert(frame.colHeaders, h)
        end
        -- Total header
        local tot = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tot:SetWidth(COL_WIDTH)
        tot:SetJustifyH("CENTER")
        tot:SetPoint("TOPLEFT", frame, "TOPLEFT",
            LABEL_WIDTH + 8 + colCount * COL_WIDTH, -(HEADER_HEIGHT))
        tot:SetText("|cffaaaaaaTotal|r")
        table.insert(frame.colHeaders, tot)
    else
        -- Single count column header
        local h = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetWidth(COL_WIDTH)
        h:SetJustifyH("CENTER")
        h:SetPoint("TOPLEFT", frame, "TOPLEFT",
            LABEL_WIDTH + 8, -(HEADER_HEIGHT))
        h:SetText("|cffaaaaaaCount|r")
        table.insert(frame.colHeaders, h)
    end
end

-- ============================================================
-- CREATE FRAME
-- ============================================================
local function CreateManagerFrame()
    if frame then return end

    local colCount = math.max(1, table.getn(charNames))
    local winWidth = math.max(MIN_WIDTH,
        LABEL_WIDTH + (colCount + 1) * COL_WIDTH + 40)
    local winHeight = HEADER_HEIGHT + COL_H_HEIGHT + ROWS_VISIBLE * ROW_HEIGHT + 30

    frame = CreateFrame("Frame", "CM_ManagerViewFrame", UIParent)
    frame:SetWidth(winWidth)
    frame:SetHeight(winHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    frame:Hide()

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(0, 0, 0, 1)
    bg:SetPoint("TOPLEFT",     frame, "TOPLEFT",      5, -5)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5,  5)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    title:SetText("|cffffff00Consumes Manager - Stock Overview|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetWidth(70)
    refreshBtn:SetHeight(18)
    refreshBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        CM_FileSync.ReadAll()
        CM_ManagerView_Refresh()
    end)

    -- Separator under tab strip
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  frame, "TOPLEFT",   8, -(HEADER_HEIGHT - 2))
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -(HEADER_HEIGHT - 2))
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetVertexColor(0.4, 0.4, 0.4, 1)

    -- Separator under column headers
    local sep2 = frame:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT",  frame, "TOPLEFT",   8, -(HEADER_HEIGHT + COL_H_HEIGHT))
    sep2:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -(HEADER_HEIGHT + COL_H_HEIGHT))
    sep2:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep2:SetVertexColor(0.3, 0.3, 0.3, 1)

    -- Scroll up button
    local btnUp = CreateFrame("Button", nil, frame)
    btnUp:SetWidth(16); btnUp:SetHeight(16)
    btnUp:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -(HEADER_HEIGHT + COL_H_HEIGHT + 2))
    btnUp:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    btnUp:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
    btnUp:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
    btnUp:SetScript("OnClick", function()
        if scrollPos > 0 then
            scrollPos = scrollPos - 1
            CM_ManagerView_UpdateRows()
        end
    end)
    frame.btnUp = btnUp

    -- Scroll down button
    local btnDown = CreateFrame("Button", nil, frame)
    btnDown:SetWidth(16); btnDown:SetHeight(16)
    btnDown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 6)
    btnDown:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    btnDown:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    btnDown:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    btnDown:SetScript("OnClick", function()
        local maxScroll = math.max(0, table.getn(displayList) - ROWS_VISIBLE)
        if scrollPos < maxScroll then
            scrollPos = scrollPos + 1
            CM_ManagerView_UpdateRows()
        end
    end)
    frame.btnDown = btnDown

    -- Scrollbar
    local scrollBar = CreateFrame("Slider", "CM_ManagerViewScrollBar", frame)
    scrollBar:SetWidth(16)
    scrollBar:SetPoint("TOPRIGHT",    frame, "TOPRIGHT", -4,
        -(HEADER_HEIGHT + COL_H_HEIGHT + 20))
    scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 28)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    scrollBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })
    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    thumb:SetWidth(16); thumb:SetHeight(32)
    scrollBar:SetThumbTexture(thumb)
    scrollBar:SetScript("OnValueChanged", function()
        local newPos = math.floor(arg1 + 0.5)
        if newPos ~= scrollPos then
            scrollPos = newPos
            CM_ManagerView_UpdateRows()
        end
    end)
    frame.scrollBar = scrollBar

    -- Mousewheel
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function()
        local maxScroll = math.max(0, table.getn(displayList) - ROWS_VISIBLE)
        if arg1 > 0 then
            scrollPos = math.max(0, scrollPos - 1)
        else
            scrollPos = math.min(maxScroll, scrollPos + 1)
        end
        CM_ManagerView_UpdateRows()
    end)

    -- Row frames
    rowFrames = {}
    local rowTop = HEADER_HEIGHT + COL_H_HEIGHT + 2
    for i = 1, ROWS_VISIBLE do
        local row = CreateFrame("Frame", "CM_MVRow" .. i, frame)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8,  -(rowTop + (i - 1) * ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -(rowTop + (i - 1) * ROW_HEIGHT))

        -- Zebra stripe background
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints(row)
        if math.mod(i, 2) == 0 then
            stripe:SetTexture(0.12, 0.12, 0.18, 0.6)  -- slightly blue-tinted dark
        else
            stripe:SetTexture(0.06, 0.06, 0.06, 0.6)  -- near-black
        end

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

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetWidth(LABEL_WIDTH - 20)
        label:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
        label:SetJustifyH("LEFT")
        row.label = label

        row.cells = {}
        row:Hide()
        rowFrames[i] = row
    end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function CM_ManagerView_Open()
    if not ConsumesManager_CharOptions or not ConsumesManager_CharOptions.isManager then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[CM]|r Manager mode is not enabled.")
        return
    end

    activeTab = "overview"
    scrollPos = 0
    BuildDisplayList()
    CreateManagerFrame()

    -- Resize for current character count
    local colCount = table.getn(charNames)
    local newWidth = math.max(MIN_WIDTH,
        LABEL_WIDTH + (colCount + 1) * COL_WIDTH + 40)
    frame:SetWidth(newWidth)

    RebuildTabs()
    RebuildColumnHeaders()
    frame:Show()
    CM_ManagerView_UpdateRows()
end

function CM_ManagerView_Refresh()
    if not frame then return end
    charNames = CM_FileSync_GetCharNames and CM_FileSync_GetCharNames() or {}
    scrollPos = 0
    BuildDisplayList()

    -- Resize if character count changed
    local colCount = table.getn(charNames)
    local newWidth = math.max(MIN_WIDTH,
        LABEL_WIDTH + (colCount + 1) * COL_WIDTH + 40)
    frame:SetWidth(newWidth)

    RebuildTabs()
    RebuildColumnHeaders()
    if frame:IsShown() then
        CM_ManagerView_UpdateRows()
    end
end

function CM_ManagerView_Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        CM_ManagerView_Open()
    end
end