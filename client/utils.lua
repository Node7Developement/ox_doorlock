-- Entity state does not work reliably for RedM doors, so ox_doorlock keeps its own map.

local function getDoorHashFromEntity(entity)
    local activeDoors = DoorSystemGetActive()

    for _, value in ipairs(activeDoors) do
        local doorHash = value[1]
        local doorHandle = value[2]

        if doorHandle == entity then
            return doorHash
        end
    end
end

local function getDoorFromEntity(data)
    local entity = type(data) == 'table' and data.entity or data
    if not entity then return end

    local state = DoorEntity[entity]
    local doorId = state?.doorId
    if not doorId then return end

    local door = doors[doorId]
    if not door then state.doorId = nil end

    return door
end

exports('getClosestDoorId', function() return ClosestDoor?.id end)
exports('getDoorIdFromEntity', function(entityId) return getDoorFromEntity(entityId)?.id end)

local function entityIsNotDoor(data)
    local entity = type(data) == 'number' and data or data.entity
    return not getDoorFromEntity(entity)
end

PickingLock = false

local registeredTargetEntities = {}

local function isDoorPickable(door)
    if not door or door.state ~= 1 then return false end
    return Config.Node7Lockpick.AllowAllLockedDoors == true or door.lockpick == true
end

local function getDoorFromTarget(data)
    if type(data) == 'table' then
        if data.doorId and doors then
            return doors[tonumber(data.doorId)]
        end

        if data.entity then
            return getDoorFromEntity(data.entity)
        end
    elseif type(data) == 'number' then
        local mapped = getDoorFromEntity(data)
        if mapped then return mapped end

        if doors then
            return doors[data]
        end
    end
end

local function canPickLock(data)
    if PickingLock then return false end
    return isDoorPickable(getDoorFromTarget(data))
end

local function canUnlockDoor(data)
    if PickingLock then return false end
    local door = getDoorFromTarget(data)
    return door and door.state == 1
end

local function canLockDoor(data)
    if PickingLock then return false end
    local door = getDoorFromTarget(data)
    return door and door.state == 0
end

local function stopLockpickAnimation(animDict)
    if animDict then
        StopEntityAnim(cache.ped, 'pick_door', animDict, 0)
        RemoveAnimDict(animDict)
    end
end

local function setDoorFromTarget(data, state)
    local door = getDoorFromTarget(data)
    if not door then
        return Node7DoorNotify('This door is not registered.', 'error')
    end

    TriggerServerEvent('ox_doorlock:setState', door.id, state)
end

local function startDoorLockpick(door)
    if not door or PickingLock then return end

    if not isDoorPickable(door) then
        return Node7DoorNotify('This door cannot be lockpicked.', 'error')
    end

    if GetResourceState('node7-lockpick-minigame') ~= 'started' then
        return Node7DoorNotify('The NODE7 lockpick minigame is not started.', 'error')
    end

    local session = lib.callback.await('ox_doorlock:beginLockpick', false, door.id)
    if not session or not session.token then
        local reason = session and session.reason
        if reason == 'missing_item' then
            return Node7DoorNotify('You need a lockpick.', 'error')
        elseif reason == 'too_far' then
            return Node7DoorNotify('Move closer to the door.', 'error')
        elseif reason == 'cooldown' then
            return Node7DoorNotify('Wait before trying the lock again.', 'error')
        elseif reason == 'unavailable' then
            return Node7DoorNotify('This door cannot be lockpicked.', 'error')
        end

        return Node7DoorNotify('The lock cannot be worked right now.', 'error')
    end

    PickingLock = true

    TaskTurnPedToFaceCoord(cache.ped, door.coords.x, door.coords.y, door.coords.z, 4000)
    Wait(500)

    local animDict
    local ok, requested = pcall(lib.requestAnimDict, 'mp_common_heist')
    if ok then
        animDict = requested
        TaskPlayAnim(cache.ped, animDict, 'pick_door', 3.0, 1.0, -1, 49, 0, true, true, true)
    end

    local exportOk, started, reason = pcall(function()
        return exports['node7-lockpick-minigame']:Start({
            difficulty = session.difficulty,
        }, function(success)
            stopLockpickAnimation(animDict)

            if success then
                TriggerServerEvent('ox_doorlock:completeLockpick', door.id, session.token)
            else
                TriggerServerEvent('ox_doorlock:failedLockpick', door.id, session.token)
            end

            PickingLock = false
        end)
    end)

    if not exportOk or not started then
        stopLockpickAnimation(animDict)
        TriggerServerEvent('ox_doorlock:cancelLockpick', door.id, session.token)
        PickingLock = false

        if not exportOk then
            print(('[ox_doorlock] node7-lockpick-minigame export error: %s'):format(tostring(started)))
        end

        Node7DoorNotify(reason == 'already_active' and 'A minigame is already active.' or 'Unable to start the NODE7 lockpick minigame.', 'error')
    end
end

local function pickLock(data)
    local door = getDoorFromTarget(data)
    if not door then
        return Node7DoorNotify('This door is not registered.', 'error')
    end

    startDoorLockpick(door)
end

local function findClosestPickableDoor(maxDistance)
    if ClosestDoor and ClosestDoor.distance and ClosestDoor.distance <= maxDistance and isDoorPickable(ClosestDoor) then
        return ClosestDoor
    end

    if not doors then return end

    local playerCoords = GetEntityCoords(cache.ped)
    local closest
    local closestDistance = maxDistance

    for _, door in pairs(doors) do
        if isDoorPickable(door) and door.coords then
            local distance = #(playerCoords - door.coords)
            if distance <= closestDistance then
                closest = door
                closestDistance = distance
            end
        end
    end

    return closest
end

local function pickClosestDoor()
    local maxDistance = math.max(tonumber(Config.TargetDistance) or 2.5, 3.0)
    local door = findClosestPickableDoor(maxDistance)

    if not door then
        return Node7DoorNotify('Stand closer to a locked registered door.', 'error')
    end

    startDoorLockpick(door)
end

exports('pickClosestDoor', pickClosestDoor)
RegisterNetEvent('ox_doorlock:useLockpickItem', pickClosestDoor)

local targetOptions = {
    {
        name = 'node7_unlockDoorlock',
        label = 'Unlock Door',
        icon = 'fa-solid fa-lock',
        iconColor = '#df3737',
        onSelect = function(data) setDoorFromTarget(data, 0) end,
        canInteract = canUnlockDoor,
        distance = tonumber(Config.TargetDistance) or 2.5,
    },
    {
        name = 'node7_lockDoorlock',
        label = 'Lock Door',
        icon = 'fa-solid fa-lock-open',
        iconColor = '#34d670',
        onSelect = function(data) setDoorFromTarget(data, 1) end,
        canInteract = canLockDoor,
        distance = tonumber(Config.TargetDistance) or 2.5,
    },
    {
        name = 'node7_pickDoorlock',
        label = 'Pick Lock [Lockpick]',
        icon = 'fa-solid fa-key',
        iconColor = '#d8b24f',
        onSelect = pickLock,
        canInteract = canPickLock,
        distance = tonumber(Config.TargetDistance) or 2.5,
    },
}

function RegisterDoorTargetEntity(entity)
    entity = tonumber(entity)
    if not entity or entity == 0 or registeredTargetEntities[entity] then return end
    if GetResourceState('ox_target') ~= 'started' then return end

    local ok, err = pcall(function()
        exports.ox_target:addLocalEntity(entity, targetOptions)
    end)

    if ok then
        registeredTargetEntities[entity] = true
    else
        print(('[ox_doorlock] Failed to register ox_target door entity %s: %s'):format(entity, tostring(err)))
    end
end

function UnregisterDoorTargetEntity(entity)
    entity = tonumber(entity)
    if not entity or not registeredTargetEntities[entity] then return end

    if GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:removeLocalEntity(entity, {
                'node7_unlockDoorlock',
                'node7_lockDoorlock',
                'node7_pickDoorlock',
            })
        end)
    end

    registeredTargetEntities[entity] = nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for entity in pairs(registeredTargetEntities) do
        UnregisterDoorTargetEntity(entity)
    end
end)

local tempData = {}

local function addDoorlock(data)
	local entity = type(data) == 'number' and data or data.entity
	local model = GetEntityModel(entity)
	local coords = GetEntityCoords(entity)
	local doorHash = getDoorHashFromEntity(entity)

	AddDoorToSystemNew(doorHash, true, true, false, 0, 0, false)
	DoorSystemSetDoorState(doorHash, 4, false, false)

	coords = GetEntityCoords(entity)
	tempData[#tempData + 1] = {
		entity = entity,
		model = model,
		coords = coords,
		heading = math.floor(GetEntityHeading(entity) + 0.5),
		hash = doorHash
	}

	RemoveDoorFromSystem(doorHash)
end

local isAddingDoorlock = false

RegisterNUICallback('notify', function(data, cb)
	cb(1)
	Node7DoorNotify(data, 'info')
end)

RegisterNUICallback('createDoor', function(data, cb)
	cb(1)
	SetNuiFocus(false, false)

	data.state = data.state and 1 or 0

	if data.items and not next(data.items) then
		data.items = nil
	end

	if data.characters and not next(data.characters) then
		data.characters = nil
	end

	if data.lockpickDifficulty and not next(data.lockpickDifficulty) then
		data.lockpickDifficulty = nil
	end

	if data.groups and not next(data.groups) then
		data.groups = nil
	end

	if not data.id then
		isAddingDoorlock = true
		local doorCount = data.doors and 2 or 1
		local lastEntity = 0

		lib.showTextUI(locale('add_door_textui'))

		repeat
			DisablePlayerFiring(cache.playerId, true)
			DisableControlAction(0, 25, true)

			local hit, entity, coords = lib.raycast.cam(1|16)
			local changedEntity = lastEntity ~= entity
			local doorA = tempData[1]?.entity
			if changedEntity and lastEntity ~= doorA then
				-- SetEntityDrawOutline(lastEntity, false)
			end
			if doorA then
				local mypos = GetEntityCoords(doorA)
				Citizen.InvokeNative(0x2A32FAA57B937173, 0x6EB7D3BB, mypos.x, mypos.y, mypos.z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 255, 42, 24, 100, false, false, 0, false)
			end

			lastEntity = entity
			if hit then
				---@diagnostic disable-next-line: param-type-mismatch
				Citizen.InvokeNative(0x2A32FAA57B937173, 0x50638AB9, coords.x, coords.y, coords.z, 0, 0, 0, 0, 0, 0, 0.2, 0.2, 0.2, 255, 42, 24, 100, false, false, 0, false, false)
			end

			if hit and entity > 0 and GetEntityType(entity) == 3 and (doorCount == 1 or doorA ~= entity) and entityIsNotDoor(entity) then
				local mypos = GetEntityCoords(entity)
				Citizen.InvokeNative(0x2A32FAA57B937173, 0x6EB7D3BB, mypos.x, mypos.y, mypos.z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 255, 42, 24, 100, false, false, 0, false)
				if changedEntity then
					-- SetEntityDrawOutline(entity, true)
				end

				if IsDisabledControlJustPressed(0, `INPUT_ATTACK`) then
					addDoorlock(entity)
				end
			end

			if IsDisabledControlJustPressed(0, `INPUT_AIM`) then
				-- SetEntityDrawOutline(entity, false)

				if not doorA then
					isAddingDoorlock = false
					return lib.hideTextUI()
				end

				-- SetEntityDrawOutline(doorA, false)
				table.wipe(tempData)
			end
		until tempData[doorCount]

		lib.hideTextUI()
		-- SetEntityDrawOutline(tempData[1].entity, false)

		if data.doors then
			-- SetEntityDrawOutline(tempData[2].entity, false)
			tempData[1].entity = nil
			tempData[2].entity = nil
			data.doors = tempData
		else
			data.model = tempData[1].model
			data.coords = tempData[1].coords
			data.heading = tempData[1].heading
			data.hash = tempData[1].hash
		end
	else
		if data.doors then
			for i = 1, 2 do
				local coords = data.doors[i].coords
				data.doors[i].coords = vector3(coords.x, coords.y, coords.z)
				data.doors[i].entity = nil
			end
		else
			data.entity = nil
		end

		data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
		data.distance = nil
		data.zone = nil
	end

	isAddingDoorlock = false

	TriggerServerEvent('ox_doorlock:editDoorlock', data.id or false, data)
	table.wipe(tempData)
end)

RegisterNUICallback('deleteDoor', function(id, cb)
	cb(1)
	TriggerServerEvent('ox_doorlock:editDoorlock', id)
end)

RegisterNUICallback('teleportToDoor', function(id, cb)
	cb(1)
	SetNuiFocus(false, false)
	local doorCoords = doors[id].coords
	if not doorCoords then return end
	SetEntityCoords(cache.ped, doorCoords.x, doorCoords.y, doorCoords.z, false, false, false, false)
end)

RegisterNUICallback('exit', function(_, cb)
	cb(1)
	SetNuiFocus(false, false)
end)

local nuiDataSent = false
local pendingUiOpen = false
local pendingUiId

local function sendInitialUiData()
    if nuiDataSent then return end

    SendNuiMessage(json.encode({
        action = 'updateDoorData',
        data = doors
    }, { with_hole = false }))

    SendNUIMessage({
        action = 'setSoundFiles',
        data = lib.callback.await('ox_doorlock:getSounds', false)
    })

    nuiDataSent = true
end

local function showUi(id)
    sendInitialUiData()
    SetNuiFocus(true, true)
    SendNuiMessage(json.encode({
        action = 'setVisible',
        data = id
    }))
end

RegisterNUICallback('ready', function(_, cb)
    NuiHasLoaded = true
    cb(1)

    if pendingUiOpen then
        local id = pendingUiId
        pendingUiOpen = false
        pendingUiId = nil
        showUi(id)
    end
end)

local function openUi(id)
    if source == '' or isAddingDoorlock then return end

    if not NuiHasLoaded then
        pendingUiOpen = true
        pendingUiId = id
        SetNuiFocus(true, true)
        return
    end

    showUi(id)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= cache.resource then return end
    SetNuiFocus(false, false)
end)

RegisterNetEvent('ox_doorlock:triggeredCommand', function(closest)
	openUi(closest and ClosestDoor?.id or nil)
end)
