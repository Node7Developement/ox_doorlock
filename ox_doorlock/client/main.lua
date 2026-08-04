local function Node7DoorNotify(description, notifyType, title, duration)
    if not DoorlockPlayerLoaded then return false end

    return exports['node7-core']:Notify({
        title = title or 'DOOR LOCK',
        description = description or '',
        type = notifyType or 'info',
        duration = duration or 5000,
    })
end

_G.Node7DoorNotify = Node7DoorNotify

if not LoadResourceFile(cache.resource, 'web/build/index.html') then
    error('Unable to load ox_doorlock UI. Install the complete resource build.')
end

if not lib.checkDependency('ox_lib', '3.14.0', true) then return end

local ZoneList = {
    [2025841068] = 'Bayou Nwa',
    [822658194] = 'Big Valley',
    [1308232528] = 'Bluewater Marsh',
    [-108848014] = 'Cholla Springs',
    [1835499550] = 'Cumberland',
    [426773653] = 'DiezCoronas',
    [-2066240242] = 'Gaptooth Ridge',
    [476637847] = 'Great Plains',
    [-120156735] = 'Grizzlies East',
    [1645618177] = 'Grizzlies West',
    [-512529193] = 'Guarma',
    [131399519] = 'Heartlands',
    [892930832] = 'Hennigans Stead',
    [-1319956120] = 'Perdido',
    [1453836102] = 'Punta Orgullo',
    [-2145992129] = 'Rio Bravo',
    [178647645] = 'Roanoke',
    [-864275692] = 'Scarlett Meadows',
    [1684533001] = 'Tall Trees',
}

local function getEntityCenterCoords(entity)
    local min, max = GetModelDimensions(GetEntityModel(entity))
    local pad = 0.001
    local box = {
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, min.y - pad, min.z - pad),
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, min.y - pad, min.z - pad),
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, max.y + pad, min.z - pad),
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, max.y + pad, min.z - pad),
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, min.y - pad, max.z + pad),
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, min.y - pad, max.z + pad),
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, max.y + pad, max.z + pad),
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, max.y + pad, max.z + pad),
    }

    local sum = vec3(0, 0, 0)
    for i = 1, 8 do sum = sum + box[i] end
    return sum / 8
end

local function getDoorHandPoint(entity)
    local boneIndex = GetEntityBoneIndexByName(entity, 'door_hand_point')
    if boneIndex == -1 then boneIndex = GetEntityBoneIndexByName(entity, 'doorknob_bone') end
    boneIndex = boneIndex == -1 and 1 or boneIndex
    return GetWorldPositionOfEntityBone(entity, boneIndex)
end

local nearbyDoors = {}
local lifecycleToken = 0
local activationPending = false
local doorPromptGroup
local doorPrompt
local promptState
local promptGroupLabel

DoorlockPlayerLoaded = false
doors = nil
DoorEntity = {}
ClosestDoor = nil
PickingLock = false

local function eachDoorHash(door, callback)
    if door.doors then
        for i = 1, 2 do
            local entry = door.doors[i]
            if entry and entry.hash then callback(entry.hash) end
        end
    elseif door.hash then
        callback(door.hash)
    end
end

local function createDoor(door)
    if not DoorlockPlayerLoaded or not door or not door.coords then return end

    door.zone = ZoneList[GetMapZoneAtCoords(door.coords.x, door.coords.y, door.coords.z, 10)]

    eachDoorHash(door, function(hash)
        AddDoorToSystemNew(hash, true, true, false, 0, 0, false)
        DoorSystemSetDoorState(hash, 4, false, false)
        DoorSystemSetDoorState(hash, door.state, false, false)

        if door.doorRate or not door.auto then
            DoorSystemSetAutomaticRate(hash, door.doorRate or 10.0, false, false)
        end
    end)
end

local function destroyPrompt()
    if doorPrompt then UiPromptDelete(doorPrompt) end
    doorPrompt = nil
    doorPromptGroup = nil
    promptState = nil
    promptGroupLabel = nil
end

local function createPrompt()
    if doorPrompt or not DoorlockPlayerLoaded or not Config.DoorPrompt or not Config.DoorPrompt.Enabled then return end

    doorPromptGroup = GetRandomIntInRange(0, 0xffffff)
    promptGroupLabel = CreateVarString(10, 'LITERAL_STRING', Config.DoorPrompt.GroupLabel or 'DOOR')
    doorPrompt = UiPromptRegisterBegin()
    PromptSetControlAction(doorPrompt, Config.DoorPrompt.Control or 0xCEFD9220)
    PromptSetText(doorPrompt, CreateVarString(10, 'LITERAL_STRING', Config.DoorPrompt.LockedLabel or 'Unlock Door'))
    PromptSetEnabled(doorPrompt, true)
    PromptSetVisible(doorPrompt, true)
    PromptSetStandardMode(doorPrompt, true)
    PromptSetGroup(doorPrompt, doorPromptGroup)
    PromptRegisterEnd(doorPrompt)
end

local function updateDoorPrompt(state)
    if not doorPrompt or promptState == state then return end
    promptState = state

    local label = state == 1
        and (Config.DoorPrompt.LockedLabel or 'Unlock Door')
        or (Config.DoorPrompt.UnlockedLabel or 'Lock Door')

    PromptSetText(doorPrompt, CreateVarString(10, 'LITERAL_STRING', label))
end

local function unregisterDoorRuntime(door)
    if not door then return end

    if door.doors then
        for i = 1, 2 do
            local entry = door.doors[i]
            if entry then
                if entry.entity then
                    if UnregisterDoorTargetEntity then UnregisterDoorTargetEntity(entry.entity) end
                    DoorEntity[entry.entity] = nil
                    entry.entity = nil
                end
            end
        end
    elseif door.entity then
        if UnregisterDoorTargetEntity then UnregisterDoorTargetEntity(door.entity) end
        DoorEntity[door.entity] = nil
        door.entity = nil
    end

    eachDoorHash(door, function(hash)
        DoorSystemSetHoldOpen(hash, false)
        RemoveDoorFromSystem(hash)
    end)
end

local function deactivateDoorlock()
    lifecycleToken = lifecycleToken + 1
    activationPending = false
    DoorlockPlayerLoaded = false
    ClosestDoor = nil
    PickingLock = false

    if lib.isTextUIOpen and lib.isTextUIOpen() then lib.hideTextUI() end
    SetNuiFocus(false, false)

    if ResetDoorlockUi then ResetDoorlockUi() end
    if CleanupDoorTargetEntities then CleanupDoorTargetEntities() end

    if doors then
        for _, door in pairs(doors) do unregisterDoorRuntime(door) end
    end

    table.wipe(nearbyDoors)
    table.wipe(DoorEntity)
    doors = nil
    destroyPrompt()
end

local function startDoorScan(token)
    CreateThread(function()
        while DoorlockPlayerLoaded and lifecycleToken == token and doors do
            table.wipe(nearbyDoors)
            local ped = cache.ped
            local coords = ped and ped ~= 0 and GetEntityCoords(ped)

            if coords then
                for _, door in pairs(doors) do
                    local double = door.doors
                    door.distance = #(coords - door.coords)

                    if double then
                        if door.distance < 80.0 then
                            for i = 1, 2 do
                                local entry = double[i]
                                if not entry.entity and IsModelValid(entry.model) then
                                    local entity = GetEntityByDoorhash(entry.hash)
                                    if entity ~= 0 then
                                        entry.entity = entity
                                        DoorEntity[entity] = DoorEntity[entity] or {}
                                        DoorEntity[entity].doorId = door.id
                                        if RegisterDoorTargetEntity then RegisterDoorTargetEntity(entity) end
                                    end
                                end
                            end

                            if door.distance < 20.0 then nearbyDoors[#nearbyDoors + 1] = door end
                        else
                            for i = 1, 2 do
                                local entry = double[i]
                                if entry.entity then
                                    if UnregisterDoorTargetEntity then UnregisterDoorTargetEntity(entry.entity) end
                                    DoorEntity[entry.entity] = nil
                                    entry.entity = nil
                                end
                            end
                        end
                    elseif door.distance < 80.0 then
                        if not door.entity and IsModelValid(door.model) then
                            local entity = GetEntityByDoorhash(door.hash)
                            if entity ~= 0 then
                                door.coords = getEntityCenterCoords(entity)
                                door.entity = entity
                                DoorEntity[entity] = DoorEntity[entity] or {}
                                DoorEntity[entity].doorId = door.id
                                if RegisterDoorTargetEntity then RegisterDoorTargetEntity(entity) end
                            end
                        end

                        if door.distance < 20.0 then nearbyDoors[#nearbyDoors + 1] = door end
                    elseif door.entity then
                        if UnregisterDoorTargetEntity then UnregisterDoorTargetEntity(door.entity) end
                        DoorEntity[door.entity] = nil
                        door.entity = nil
                    end
                end
            end

            Wait(500)
        end
    end)
end

local lastTriggered = 0

local function useClosestDoor()
    if not DoorlockPlayerLoaded or not ClosestDoor then return false end

    local gameTimer = GetGameTimer()
    if gameTimer - lastTriggered <= 500 then return false end

    lastTriggered = gameTimer
    TriggerServerEvent('ox_doorlock:setState', ClosestDoor.id, ClosestDoor.state == 1 and 0 or 1)
    return true
end

local function startInteractionLoop(token)
    CreateThread(function()
        local lockDoor = locale('lock_door')
        local unlockDoor = locale('unlock_door')
        local showUI
        local drawSprite = Config.DrawSprite

        if drawSprite then
            local loaded = {}
            for state = 0, 1 do
                local texture = drawSprite[state] and drawSprite[state][1]
                if texture and not loaded[texture] then
                    RequestStreamedTextureDict(texture, true)
                    local timeout = GetGameTimer() + 5000
                    while DoorlockPlayerLoaded and lifecycleToken == token and not HasStreamedTextureDictLoaded(texture) and GetGameTimer() < timeout do
                        Wait(0)
                    end
                    loaded[texture] = true
                end
            end
        end

        local SetDrawOrigin = SetDrawOrigin
        local ClearDrawOrigin = ClearDrawOrigin
        local DrawDoorSprite = drawSprite and DrawSprite

        while DoorlockPlayerLoaded and lifecycleToken == token do
            local num = #nearbyDoors
            ClosestDoor = nil

            if num > 0 then
                local ratio = drawSprite and 1.7
                for i = 1, num do
                    local door = nearbyDoors[i]
                    if door.distance < door.maxDistance then
                        if not ClosestDoor or door.distance < ClosestDoor.distance then ClosestDoor = door end

                        if drawSprite and not door.hideUi then
                            local sprite = drawSprite[door.state]
                            local entity = door.doors and door.doors[1].entity or door.entity
                            if sprite and entity and entity ~= 0 then
                                local point = getDoorHandPoint(entity)
                                if point.x == 0 and point.y == 0 and point.z == 0 then point = getEntityCenterCoords(entity) end

                                SetDrawOrigin(point.x, point.y, point.z + 0.04)
                                if door.distance < (door.maxDistance / 2) then
                                    DrawDoorSprite(sprite[1], sprite[2], sprite[3], sprite[4], sprite[5], sprite[6] * ratio, sprite[7], sprite[8], sprite[9], sprite[10], sprite[11])
                                else
                                    DrawDoorSprite(sprite[1], 'point', sprite[3], sprite[4], 0.017, 0.034, sprite[7], sprite[8], sprite[9], sprite[10], sprite[11])
                                end
                                ClearDrawOrigin()
                            end
                        end
                    end
                end
            end

            local canUseClosest = ClosestDoor and ClosestDoor.distance < ClosestDoor.maxDistance and not PickingLock
            if canUseClosest then
                if Config.DrawTextUI and not ClosestDoor.hideUi and ClosestDoor.state ~= showUI then
                    lib.showTextUI(ClosestDoor.state == 0 and lockDoor or unlockDoor)
                    showUI = ClosestDoor.state
                end

                local promptCompleted = false
                if doorPrompt and not ClosestDoor.hideUi then
                    updateDoorPrompt(ClosestDoor.state)
                    PromptSetActiveGroupThisFrame(doorPromptGroup, promptGroupLabel)
                    promptCompleted = PromptHasStandardModeCompleted(doorPrompt)
                end

                local control = Config.DoorPrompt and Config.DoorPrompt.Control or 0xCEFD9220
                if promptCompleted or IsControlJustReleased(0, control) then useClosestDoor() end
            elseif showUI then
                lib.hideTextUI()
                showUI = nil
            end

            Wait(num > 0 and 0 or 500)
        end

        ClosestDoor = nil
        if showUI then lib.hideTextUI() end
    end)
end

local function activateDoorlock()
    if DoorlockPlayerLoaded or activationPending then return end
    activationPending = true
    local requestToken = lifecycleToken

    CreateThread(function()
        local data

        for _ = 1, 40 do
            if lifecycleToken ~= requestToken or DoorlockPlayerLoaded then
                activationPending = false
                return
            end

            data = lib.callback.await('ox_doorlock:getDoors', false)
            if data then break end
            Wait(250)
        end

        activationPending = false
        if lifecycleToken ~= requestToken or DoorlockPlayerLoaded or not data then return end

        DoorlockPlayerLoaded = true
        lifecycleToken = lifecycleToken + 1
        local token = lifecycleToken
        doors = data
        table.wipe(nearbyDoors)
        table.wipe(DoorEntity)

        for _, door in pairs(doors) do createDoor(door) end

        createPrompt()
        startDoorScan(token)
        startInteractionLoop(token)
    end)
end

RegisterNetEvent('Node7Core:Client:OnPlayerLoaded', activateDoorlock)
RegisterNetEvent('Node7Core:Client:OnPlayerUnload', deactivateDoorlock)
RegisterNetEvent('node7-charselect:client:chooseChar', deactivateDoorlock)

RegisterNetEvent('ox_doorlock:setState', function(id, state, source, data)
    if not DoorlockPlayerLoaded or not doors then return end

    if data then
        doors[id] = data
        createDoor(data)

        if NuiHasLoaded then
            SendNuiMessage(json.encode({ action = 'updateDoorData', data = data }))
        end
    end

    local door = data or doors[id]
    if not door then return end

    if Config.Notify and source == cache.serverId then
        Node7DoorNotify(locale(state == 0 and 'unlocked_door' or 'locked_door'), 'success')
    end

    door.state = state
    eachDoorHash(door, function(hash)
        DoorSystemSetDoorState(hash, state, false, false)
        if door.holdOpen then DoorSystemSetHoldOpen(hash, state == 0) end
    end)

    if state == 1 then
        local timeout = GetGameTimer() + 2500
        while DoorlockPlayerLoaded and GetGameTimer() < timeout do
            local closed = true
            eachDoorHash(door, function(hash)
                if not IsDoorClosed(hash) then closed = false end
            end)
            if closed then break end
            Wait(0)
        end
    end

    if door.distance and door.distance < 20.0 then
        if Config.NativeAudio then
            RequestScriptAudioBank('dlc_oxdoorlock/oxdoorlock', false)
            local sound = state == 0 and door.unlockSound or door.lockSound or 'door_bolt'
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, sound, door.coords.x, door.coords.y, door.coords.z, 'DLC_OXDOORLOCK_SET', false, 0, false)
            ReleaseSoundId(soundId)
            ReleaseNamedScriptAudioBank('dlc_oxdoorlock/oxdoorlock')
        else
            local volume = math.min(1.0, 0.3 / math.max(door.distance / 2, 0.1))
            SendNUIMessage({
                action = 'playSound',
                data = { sound = state == 0 and door.unlockSound or door.lockSound or 'door-bolt-4', volume = volume }
            })
        end
    end
end)

RegisterNetEvent('ox_doorlock:editDoorlock', function(id, data)
    if source == '' or not DoorlockPlayerLoaded or not doors then return end

    local door = doors[id]
    if not door then
        if data then
            doors[id] = data
            createDoor(data)
        end
        return
    end

    local doorState = data and data.state or 0
    if data then
        data.zone = door.zone or ZoneList[GetMapZoneAtCoords(door.coords.x, door.coords.y, door.coords.z, 10)]
        if door.distance and door.distance < 20 then door.distance = 80 end
    elseif ClosestDoor and ClosestDoor.id == id then
        ClosestDoor = nil
    end

    unregisterDoorRuntime(door)
    if data then
        doors[id] = data
        createDoor(data)
        data.state = doorState
    else
        doors[id] = nil
    end

    if NuiHasLoaded then
        SendNuiMessage(json.encode({ action = 'updateDoorData', data = data or id }))
    end
end)

lib.callback.register('ox_doorlock:inputPassCode', function()
    if not DoorlockPlayerLoaded then return end
    return ClosestDoor and ClosestDoor.passcode and lib.inputDialog(locale('door_lock'), {
        { type = 'input', label = locale('passcode'), password = true, icon = 'lock' },
    })?[1]
end)

exports('useClosestDoor', useClosestDoor)
exports('getClosestDoor', function()
    return DoorlockPlayerLoaded and ClosestDoor or nil
end)

local function currentNode7PlayerLoaded()
    local ok, core = pcall(function() return exports['node7-core']:GetCoreObject() end)
    if not ok or not core or not core.Functions or not core.Functions.GetPlayerData then return false end

    local success, playerData = pcall(function() return core.Functions.GetPlayerData() end)
    if not success or type(playerData) ~= 'table' then return false end

    if playerData.loggedIn == false or playerData.isLoggedIn == false then return false end

    return playerData.citizenid ~= nil
        or playerData.charid ~= nil
        or playerData.characterId ~= nil
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= cache.resource then return end

    CreateThread(function()
        Wait(500)
        if currentNode7PlayerLoaded() then activateDoorlock() end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= cache.resource then return end
    deactivateDoorlock()
end)
