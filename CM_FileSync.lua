---------------------------------------------------------------
-- CM_FileSync.lua
-- Handles per-character inventory snapshot files.
-- Non-managers: write on BAG_UPDATE (debounced) and on demand.
-- Managers: write own file, then read all CM_*.txt files.
--
-- File format (single line):
--   CharName|timestamp|itemID:count,itemID:count,...
--
-- Items exported = full ConsumesManager_SelectedItems list
-- with current counts (bags + cached bank), including zeros.
--
-- WoW 1.12 / Turtle WoW / SuperWoW | Lua 5.0
---------------------------------------------------------------

CM_FileSync = {}

local FILE_PREFIX = "CM_"
local DEBOUNCE    = 2.0   -- seconds to wait after last BAG_UPDATE before writing

-- Parsed data from other characters' files.
-- CM_FileSync.charData[charName] = {
--     timestamp = number,
--     items     = { [itemID] = count, ... }
-- }
CM_FileSync.charData = {}

-- ============================================================
-- SERIALISE / DESERIALISE
-- ============================================================

-- Returns { [itemID] = { count=N, configured=bool } } for all
-- consumables found in bags+bank. configured=true if the character
-- has this item selected in ConsumesManager_SelectedItems.
local function GetCurrentCounts()
    local realmName  = GetRealmName()
    local playerName = UnitName("player")
    local result     = {}

    local charData = ConsumesManager_Data
        and ConsumesManager_Data[realmName]
        and ConsumesManager_Data[realmName][playerName]

    if not charData then return result end

    -- Scan all items found in inventory and bank
    local function addItems(source)
        if not source then return end
        for itemID, count in pairs(source) do
            if consumablesList and consumablesList[itemID] then
                if not result[itemID] then
                    result[itemID] = { count = 0, configured = false }
                end
                result[itemID].count = result[itemID].count + count
            end
        end
    end

    addItems(charData["inventory"])
    addItems(charData["bank"])

    -- Also include configured items even if count is zero
    if ConsumesManager_SelectedItems then
        for itemID, selected in pairs(ConsumesManager_SelectedItems) do
            if selected then
                if not result[itemID] then
                    result[itemID] = { count = 0, configured = false }
                end
                result[itemID].configured = true
            end
        end
    end

    return result
end

-- File format: CharName|timestamp|excluded|isManager|itemID:count:configured,...
-- excluded:   1 = skip in manager overview, 0 = include
-- isManager:  1 = this character is a manager, 0 = not
-- configured: 1 = selected by this char, 0 = in inventory but not selected
local function Serialise()
    local playerName = UnitName("player")
    local timestamp  = math.floor(GetTime())
    local excluded   = (ConsumesManager_CharOptions and ConsumesManager_CharOptions.excludeFromManager) and "1" or "0"
    local isManager  = (ConsumesManager_CharOptions and ConsumesManager_CharOptions.isManager) and "1" or "0"
    local data       = GetCurrentCounts()

    local parts = {}
    for itemID, entry in pairs(data) do
        table.insert(parts, itemID .. ":" .. entry.count .. ":" .. (entry.configured and "1" or "0"))
    end

    return playerName .. "|" .. timestamp .. "|" .. excluded .. "|" .. isManager .. "|" .. table.concat(parts, ",")
end

local function Deserialise(line, fileName)
    if not line or line == "" then return nil end

    -- Try new format: CharName|timestamp|excluded|isManager|items
    local _, _, charName, tsStr, excludedStr, isManagerStr, itemsStr = string.find(line, "^([^|]+)|(%d+)|(%d+)|(%d+)|(.*)$")
    if not charName then
        -- Try old format: CharName|timestamp|excluded|items
        _, _, charName, tsStr, excludedStr, itemsStr = string.find(line, "^([^|]+)|(%d+)|(%d+)|(.*)$")
        isManagerStr = "0"
    end
    if not charName then
        -- Oldest format: CharName|timestamp|items
        _, _, charName, tsStr, itemsStr = string.find(line, "^([^|]+)|(%d+)|(.*)$")
        excludedStr  = "0"
        isManagerStr = "0"
    end
    if not charName then return nil end

    local result = {
        timestamp = tonumber(tsStr) or 0,
        excluded  = excludedStr == "1",
        isManager = isManagerStr == "1",
        items     = {},
    }

    if itemsStr and itemsStr ~= "" then
        for pair in string.gfind(itemsStr, "[^,]+") do
            -- Try new format first: id:count:configured
            local _, _, idStr, countStr, configStr = string.find(pair, "^(%d+):(%d+):(%d+)$")
            if not idStr then
                -- Fall back to old format: id:count
                _, _, idStr, countStr = string.find(pair, "^(%d+):(%d+)$")
                configStr = "0"
            end
            if idStr then
                result.items[tonumber(idStr)] = {
                    count      = tonumber(countStr),
                    configured = configStr == "1",
                }
            end
        end
    end

    return charName, result
end

-- ============================================================
-- MANIFEST
-- ============================================================

local MANIFEST_FILE = "CM_manifest"

local function ReadManifest()
    local names = {}
    local content = ImportFile(MANIFEST_FILE)
    if content and content ~= "" then
        for name in string.gfind(content, "[^,]+") do
            local _, _, trimmed = string.find(name, "^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                names[trimmed] = true
            end
        end
    end
    return names
end

local function UpdateManifest(playerName)
    local names = ReadManifest()
    if names[playerName] then return end
    names[playerName] = true
    local parts = {}
    for name, _ in pairs(names) do
        table.insert(parts, name)
    end
    table.sort(parts)
    ExportFile(MANIFEST_FILE, table.concat(parts, ","))
end

-- ============================================================
-- WRITE
-- ============================================================

function CM_FileSync.Write()
    if not ImportFile then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[CM FileSync]|r SuperWoW not detected - file sync unavailable.")
        return false
    end

    local playerName = UnitName("player")
    local fileName   = FILE_PREFIX .. playerName
    local data       = Serialise()

    ExportFile(fileName, data)
    UpdateManifest(playerName)
    return true
end

function CM_FileSync.ReadAll()
    if not ImportFile then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[CM FileSync]|r SuperWoW not detected - file sync unavailable.")
        return
    end

    CM_FileSync.charData = {}

    -- Build candidate list from manifest + fallbacks
    local candidates = ReadManifest()

    -- Also add same-account toons from ConsumesManager_Data as fallback
    local realmName = GetRealmName()
    if ConsumesManager_Data and ConsumesManager_Data[realmName] then
        for charName, _ in pairs(ConsumesManager_Data[realmName]) do
            if type(charName) == "string" then
                candidates[charName] = true
            end
        end
    end

    -- Always include current player
    candidates[UnitName("player")] = true

    local loaded = 0
    for charName, _ in pairs(candidates) do
        local fileName = FILE_PREFIX .. charName
        local raw      = ImportFile(fileName)
        if raw and raw ~= "" then
            local name, data = Deserialise(raw, fileName)
            if name and data then
                CM_FileSync.charData[name] = data
                loaded = loaded + 1
            end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CM FileSync]|r Loaded data for " .. loaded .. " character(s).")
end



-- ============================================================
-- SYNC BUTTON HANDLER
-- Called by the Sync button in the settings tab.
-- Non-managers: write own file.
-- Managers: write own file, then read all.
-- ============================================================

function CM_FileSync_Sync()
    local isManager = ConsumesManager_CharOptions and ConsumesManager_CharOptions.isManager

    local ok = CM_FileSync.Write()
    if not ok then return end

    if isManager then
        CM_FileSync.ReadAll()
        -- Refresh manager view if it's open
        if CM_ManagerView_Refresh then
            CM_ManagerView_Refresh()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CM FileSync]|r Sync complete (manager).")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CM FileSync]|r Inventory exported.")
    end
end

-- ============================================================
-- BAG_UPDATE DEBOUNCE
-- ============================================================

local debounceFrame   = CreateFrame("Frame")
local debounceElapsed = 0
local debouncing      = false

debounceFrame:Hide()
debounceFrame:SetScript("OnUpdate", function()
    debounceElapsed = debounceElapsed + arg1
    if debounceElapsed >= DEBOUNCE then
        debounceFrame:Hide()
        debouncing      = false
        debounceElapsed = 0
        CM_FileSync.Write()
    end
end)

local bagUpdateFrame = CreateFrame("Frame")
bagUpdateFrame:RegisterEvent("BAG_UPDATE")
bagUpdateFrame:RegisterEvent("PLAYER_LOGIN")
bagUpdateFrame:RegisterEvent("BANKFRAME_CLOSED")

bagUpdateFrame:SetScript("OnEvent", function()
    if not ImportFile then return end

    if event == "PLAYER_LOGIN" then
        -- On login, managers auto-read all files
        if ConsumesManager_CharOptions and ConsumesManager_CharOptions.isManager then
            -- Delay slightly to let saved variables finish loading
            local loginFrame   = CreateFrame("Frame")
            local loginElapsed = 0
            loginFrame:SetScript("OnUpdate", function()
                loginElapsed = loginElapsed + arg1
                if loginElapsed >= 2.0 then
                    loginFrame:SetScript("OnUpdate", nil)
                    CM_FileSync.ReadAll()
                    if CM_ManagerView_Open then CM_ManagerView_Open() end
                end
            end)
        end

    elseif event == "BAG_UPDATE" then
        -- Debounce: reset timer on every BAG_UPDATE
        debounceElapsed = 0
        if not debouncing then
            debouncing = true
            debounceFrame:Show()
        end

    elseif event == "BANKFRAME_CLOSED" then
        -- Bank just closed - write immediately to capture bank data
        CM_FileSync.Write()
    end
end)

-- ============================================================
-- UTILITY: get merged count for an item across all loaded chars
-- ============================================================

function CM_FileSync_GetTotalCount(itemID)
    local total = 0
    for _, data in pairs(CM_FileSync.charData) do
        local entry = data.items[itemID]
        if entry then total = total + entry.count end
    end
    return total
end

-- Returns sorted list of character names from loaded data,
-- excluding any characters that have opted out of the overview.
function CM_FileSync_GetCharNames()
    local excluded = ConsumesManager_Options
        and ConsumesManager_Options.excludedChars
        or {}

    local managers    = {}
    local nonManagers = {}

    for name, data in pairs(CM_FileSync.charData) do
        if not excluded[name] then
            if data.isManager then
                table.insert(managers, name)
            else
                table.insert(nonManagers, name)
            end
        end
    end

    table.sort(managers)
    table.sort(nonManagers)

    -- Managers first, then non-managers
    local names = {}
    for _, n in ipairs(managers)    do table.insert(names, n) end
    for _, n in ipairs(nonManagers) do table.insert(names, n) end
    return names
end