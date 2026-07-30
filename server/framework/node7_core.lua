local Node7Core = exports['node7-core']:GetCoreObject()

function GetPlayer(playerId)
    return Node7Core.Functions.GetPlayer(tonumber(playerId))
end

function GetCharacterId(player)
    return player and player.PlayerData and player.PlayerData.citizenid
end

local function getGrade(data)
    if not data then return 0 end
    if type(data.grade) == 'table' then
        return tonumber(data.grade.level or data.grade.grade or data.grade.value) or 0
    end
    return tonumber(data.grade) or tonumber(data.gradelevel) or 0
end

local function matchesGroup(data, filter)
    if not data or not data.name then return end

    local grade = getGrade(data)
    local filterType = type(filter)

    if filterType == 'string' then
        if data.name == filter then return data.name, grade end
        return
    end

    if filterType ~= 'table' then return end

    local tableType = table.type(filter)
    if tableType == 'hash' then
        local minimum = filter[data.name]
        if minimum ~= nil and grade >= (tonumber(minimum) or 0) then
            return data.name, grade
        end
    elseif tableType == 'array' then
        for i = 1, #filter do
            if data.name == filter[i] then return data.name, grade end
        end
    end
end

function IsPlayerInGroup(player, filter)
    if not player or not player.PlayerData then return end

    local name, grade = matchesGroup(player.PlayerData.job, filter)
    if name then return name, grade end

    return matchesGroup(player.PlayerData.gang, filter)
end

local function getItemMetadata(item)
    return item and (item.info or item.metadata) or {}
end

---@param player table
---@param items string[] | { name: string, remove?: boolean, metadata?: string }[]
---@param removeItem? boolean
---@return string?
function DoesPlayerHaveItem(player, items, removeItem)
    if not player or not player.PlayerData then return end

    local playerId = tonumber(player.PlayerData.source or player.source)
    if not playerId or type(items) ~= 'table' then return end

    for i = 1, #items do
        local item = items[i]
        local itemName = type(item) == 'table' and item.name or item

        if itemName then
            local foundItems = exports['node7-inventory']:GetItemsByName(playerId, itemName) or {}

            for j = 1, #foundItems do
                local found = foundItems[j]
                local metadataMatches = true

                if type(item) == 'table' and item.metadata then
                    local metadata = getItemMetadata(found)
                    metadataMatches = metadata.type == item.metadata
                        or metadata.metadata == item.metadata
                        or metadata.name == item.metadata
                end

                if metadataMatches and (tonumber(found.amount) or 0) > 0 then
                    if removeItem or (type(item) == 'table' and item.remove) then
                        local removed = exports['node7-inventory']:RemoveItem(
                            playerId,
                            itemName,
                            1,
                            found.slot,
                            'ox_doorlock item use'
                        )

                        if not removed then return end
                    end

                    return itemName
                end
            end
        end
    end
end

function RemoveItem(playerId, item, slot)
    return exports['node7-inventory']:RemoveItem(
        tonumber(playerId),
        item,
        1,
        slot,
        'ox_doorlock lockpick broke'
    )
end
