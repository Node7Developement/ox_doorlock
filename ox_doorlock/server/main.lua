if not LoadResourceFile(cache.resource, 'web/build/index.html') then
	error(
		'Unable to load UI. Build ox_doorlock or download the latest release.\n	^3https://github.com/overextended/ox_doorlock/releases/latest/download/ox_doorlock.zip^0')
end

if not lib.checkDependency('oxmysql', '2.4.0') then return end
if not lib.checkDependency('ox_lib', '3.14.0') then return end

require 'server.convert'

local utils = require 'server.utils'
local doors = {}


local function getLoadedPlayer(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 then return end
    return GetPlayer(playerId)
end

local function playerIsLoaded(playerId)
    return Config.RequirePlayerLoaded == false or getLoadedPlayer(playerId) ~= nil
end

local function encodeData(door)
	local double = door.doors

	return json.encode({
		auto = door.auto,
		autolock = door.autolock,
		coords = door.coords,
		doors = double and {
			{
				coords = double[1].coords,
				heading = double[1].heading,
				model = double[1].model,
				hash = double[1].hash,
			},
			{
				coords = double[2].coords,
				heading = double[2].heading,
				model = double[2].model,
				hash = double[2].hash,
			},
		},
		characters = door.characters,
		groups = door.groups,
		heading = door.heading,
		items = door.items,
		lockpick = door.lockpick,
		hideUi = door.hideUi,
		holdOpen = door.holdOpen,
		lockSound = door.lockSound,
		maxDistance = door.maxDistance,
		doorRate = door.doorRate,
		model = door.model,
		hash = door.hash,
		state = door.state,
		unlockSound = door.unlockSound,
		passcode = door.passcode,
		lockpickDifficulty = door.lockpickDifficulty
	})
end

local function getDoor(door)
	door = type(door) == 'table' and door or doors[door]
	if not door then return false end
	return {
		id = door.id,
		name = door.name,
		state = door.state,
		coords = door.coords,
		characters = door.characters,
		groups = door.groups,
		items = door.items,
		maxDistance = door.maxDistance,
	}
end

exports('getDoor', getDoor)

exports('getAllDoors', function()
	local allDoors = {}

	for _, door in pairs(doors) do
		allDoors[#allDoors+1] = getDoor(door)
	end

	return allDoors
end)

exports('getDoorFromName', function(name)
	for _, door in pairs(doors) do
		if door.name == name then
			return getDoor(door)
		end
	end
end)

exports('editDoor', function(id, data)
	local door = doors[id]

	if door then
		for k, v in pairs(data) do
			if k ~= 'id' then
				local current = door[k]
				local t1 = type(current)
				local t2 = type(v)

				if t1 ~= 'nil' and v ~= '' and t1 ~= t2 then
					error(("Expected '%s' for door.%s, received %s (%s)"):format(t1, k, t2, v))
				end

				door[k] = v ~= '' and v or nil
			end
		end

		MySQL.update('UPDATE ox_doorlock SET name = ?, data = ? WHERE id = ?', { door.name, encodeData(door), id })
		TriggerClientEvent('ox_doorlock:editDoorlock', -1, id, door)
	end
end)

local soundDirectory = Config.NativeAudio and 'audio/dlc_oxdoorlock/oxdoorlock' or 'web/build/sounds'
local fileFormat = Config.NativeAudio and '%.wav' or '%.ogg'
local sounds = utils.getFilesInDirectory(soundDirectory, fileFormat)

lib.callback.register('ox_doorlock:getSounds', function()
	return sounds
end)

local function createDoor(id, door, name)
	local double = door.doors
	door.id = id
	door.name = name

	if double then
		for i = 1, 2 do
			-- double[i].hash = joaat(('ox_door_%s_%s'):format(id, i))

			local coords = double[i].coords
			double[i].coords = vector3(coords.x, coords.y, coords.z)
		end

		if not door.coords then
			door.coords = double[1].coords - ((double[1].coords - double[2].coords) / 2)
		end
	else
		-- door.hash = joaat(('ox_door_%s'):format(id))
	end

	door.coords = vector3(door.coords.x, door.coords.y, door.coords.z)

	if not door.state then
		door.state = 1
	end

	if type(door.items?[1]) == 'string' then
		local items = {}

		for i = 1, #door.items do
			items[i] = {
				name = door.items[i],
				remove = false,
			}
		end

		door.items = items
		MySQL.update('UPDATE ox_doorlock SET data = ? WHERE id = ?', { encodeData(door), id })
	end

	doors[id] = door
	return door
end

local isLoaded = false

local lockpickSessions = {}
local lockpickCooldowns = {}
local approvedLockpicks = {}

local function isDoorPickable(door)
    return door and (Config.Node7Lockpick.AllowAllLockedDoors == true or door.lockpick == true)
end

local function playerNearDoor(playerId, door, padding)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local allowedDistance = math.max(tonumber(door.maxDistance) or 2.0, 2.0) + (padding or 1.5)
    return #(coords - door.coords) <= allowedDistance
end

local difficultyRank = {
    easy = 1,
    medium = 2,
    normal = 2,
    hard = 3,
    expert = 4,
    custom = 3,
}

local function resolveLockpickDifficulty(value)
    local selected = Config.Node7Lockpick.DefaultDifficulty or 'normal'
    local selectedRank = difficultyRank[selected] or 2

    local function consider(entry)
        local name

        if type(entry) == 'string' then
            name = entry:lower()
        elseif type(entry) == 'table' then
            name = 'custom'
        end

        local rank = name and difficultyRank[name]
        if rank and rank > selectedRank then
            selected = name
            selectedRank = rank
        end
    end

    if type(value) == 'table' then
        for i = 1, #value do consider(value[i]) end
    else
        consider(value)
    end

    return Config.Node7Lockpick.DifficultyMap[selected]
        or Config.Node7Lockpick.DefaultDifficulty
        or 'normal'
end

local function getLockpickItem(player)
    return player and DoesPlayerHaveItem(player, Config.LockpickItems)
end

local function removeLockpick(playerId, reason)
    local player = GetPlayer(playerId)
    if not player then return false end

    local removedItem = DoesPlayerHaveItem(player, Config.LockpickItems, true)
    if removedItem then
        exports['node7-core']:Notify(playerId, {
            title = 'DOOR LOCK',
            type = 'error',
            description = reason or locale('lockpick_broke'),
            duration = 5000,
        })
        return true
    end

    return false
end

local function rollBreakChance(playerId, chance, reason)
    chance = math.max(0, math.min(100, tonumber(chance) or 0))
    if chance > 0 and math.random(1, 100) <= chance then
        removeLockpick(playerId, reason)
    end
end

local function isAuthorised(playerId, door, lockpick)
	if Config.PlayerAceAuthorised and IsPlayerAceAllowed(playerId, 'command.doorlock') then
		return true
	end

	-- e.g. add_ace group.police "doorlock.mrpd locker rooms" allow
	-- add_principal fivem:123456 group.police
	-- or add_ace identifier.fivem:123456 "doorlock.mrpd locker rooms" allow
	if IsPlayerAceAllowed(playerId, ('doorlock.%s'):format(door.name)) then
		return true
	end

	local player = GetPlayer(playerId)
	local authorised = door.passcode or false --[[@as boolean | string | nil]]

	if player then
		if lockpick then
			return DoesPlayerHaveItem(player, Config.LockpickItems)
		end

		if door.characters and table.contains(door.characters, GetCharacterId(player)) then
			return true
		end

		if door.groups then
			authorised = IsPlayerInGroup(player, door.groups) and true or nil
		end

		if not authorised and door.items then
			authorised = DoesPlayerHaveItem(player, door.items) or nil
		end

		if authorised ~= nil and door.passcode then
			authorised = door.passcode == lib.callback.await('ox_doorlock:inputPassCode', playerId)
		end
	end

	return authorised
end


lib.callback.register('ox_doorlock:beginLockpick', function(playerId, doorId)
    playerId = tonumber(playerId)
    doorId = tonumber(doorId)

    local door = doorId and doors[doorId]
    local player = playerId and GetPlayer(playerId)
    local now = GetGameTimer()

    if not door or not player or not isDoorPickable(door) then return { reason = 'unavailable' } end
    if not Config.CanPickUnlockedDoors and door.state == 0 then return { reason = 'unavailable' } end
    if not playerNearDoor(playerId, door) then return { reason = 'too_far' } end
    if not getLockpickItem(player) then return { reason = 'missing_item' } end
    if now < (lockpickCooldowns[playerId] or 0) then return { reason = 'cooldown' } end

    lockpickCooldowns[playerId] = now + (Config.Node7Lockpick.CooldownMilliseconds or 1500)

    local token = ('%s:%s:%s:%s'):format(
        playerId,
        doorId,
        os.time(),
        math.random(100000, 999999)
    )

    lockpickSessions[playerId] = {
        doorId = doorId,
        token = token,
        expires = os.time() + (Config.Node7Lockpick.SessionSeconds or 60),
    }

    return {
        token = token,
        difficulty = resolveLockpickDifficulty(door.lockpickDifficulty or Config.LockDifficulty),
    }
end)

local function validateLockpickSession(playerId, doorId, token)
    local session = lockpickSessions[playerId]
    if not session then return false end

    lockpickSessions[playerId] = nil

    if session.doorId ~= tonumber(doorId) or session.token ~= token or session.expires < os.time() then
        return false
    end

    local door = doors[session.doorId]
    local player = GetPlayer(playerId)

    if not door or not player or not isDoorPickable(door) then return false end
    if not Config.CanPickUnlockedDoors and door.state == 0 then return false end
    if not playerNearDoor(playerId, door) then return false end
    if not getLockpickItem(player) then return false end

    return door
end

AddEventHandler('playerDropped', function()
    lockpickSessions[source] = nil
    lockpickCooldowns[source] = nil
    approvedLockpicks[source] = nil
end)

local sql = LoadResourceFile(cache.resource, 'sql/ox_doorlock.sql')

if sql then MySQL.query(sql) end

MySQL.ready(function()
    while Config.DoorList do Wait(100) end

    local response = MySQL.query.await('SELECT `id`, `name`, `data` FROM `ox_doorlock`')
    local relockQueries = {}
    local relocked = 0

    for i = 1, #response do
        local row = response[i]
        local data = json.decode(row.data)

        if type(data) == 'table' then
            if Config.RelockOnRestart and data.state ~= 1 then
                data.state = 1
                relocked = relocked + 1
                relockQueries[#relockQueries + 1] = {
                    query = 'UPDATE `ox_doorlock` SET `data` = ? WHERE `id` = ?',
                    values = { encodeData(data), row.id },
                }
            end

            createDoor(row.id, data, row.name)
        else
            print(('[ox_doorlock] Ignored invalid door data for id %s.'):format(row.id))
        end
    end

    if #relockQueries > 0 then
        local success = MySQL.transaction.await(relockQueries)
        if not success then
            print('[ox_doorlock] Failed to persist restart relock states; live doors are still locked for this session.')
        end
    end

    isLoaded = true
    print(('[ox_doorlock] Loaded %s door(s); %s door(s) reset to locked.'):format(#response, relocked))
    TriggerEvent('ox_doorlock:loaded')
end)

---@param id number
---@param state 0 | 1 | boolean
---@param lockpick? boolean
---@return boolean
local function setDoorState(id, state, lockpick)
    local playerId = tonumber(source)
    if playerId and playerId > 0 and not playerIsLoaded(playerId) then return false end

	local door = doors[id]

	state = (state == 1 or state == 0) and state or (state and 1 or 0)

	if door then
		if lockpick and source and source ~= '' and approvedLockpicks[source] ~= id then
			return false
		end

		local authorised = not source or source == '' or isAuthorised(source, door, lockpick)

		if authorised then
			door.state = state
			TriggerClientEvent('ox_doorlock:setState', -1, id, state, source)

			if door.autolock and state == 0 then
				SetTimeout(door.autolock * 1000, function()
					if door.state ~= 1 then
						door.state = 1

						TriggerClientEvent('ox_doorlock:setState', -1, id, door.state)
						TriggerEvent('ox_doorlock:stateChanged', nil, door.id, door.state == 1)
					end
				end)
			end

			TriggerEvent('ox_doorlock:stateChanged', source, door.id, state == 1, type(authorised) == 'string' and authorised)

			return true
		end

		if source then
			exports['node7-core']:Notify(source, { title = 'DOOR LOCK', type = 'error', description = locale(state == 0 and 'cannot_unlock' or 'cannot_lock'), duration = 5000 })
		end
	end

	return false
end

RegisterNetEvent('ox_doorlock:setState', setDoorState)
exports('setDoorState', setDoorState)

RegisterNetEvent('ox_doorlock:completeLockpick', function(doorId, token)
    local playerId = source
    local door = validateLockpickSession(playerId, doorId, token)
    if not door then return end

    approvedLockpicks[playerId] = door.id
    local success = setDoorState(door.id, 0, true)
    approvedLockpicks[playerId] = nil

    if success then
        rollBreakChance(
            playerId,
            Config.Node7Lockpick.BreakChanceOnSuccess,
            locale('lockpick_broke')
        )
    end
end)

RegisterNetEvent('ox_doorlock:failedLockpick', function(doorId, token)
    local playerId = source
    local door = validateLockpickSession(playerId, doorId, token)
    if not door then return end

    exports['node7-core']:Notify(playerId, {
        title = 'DOOR LOCK',
        type = 'error',
        description = 'The lockpick attempt failed.',
        duration = 4000,
    })

    rollBreakChance(
        playerId,
        Config.Node7Lockpick.BreakChanceOnFailure,
        locale('lockpick_broke')
    )
end)

RegisterNetEvent('ox_doorlock:cancelLockpick', function(doorId, token)
    local session = lockpickSessions[source]
    if session and session.doorId == tonumber(doorId) and session.token == token then
        lockpickSessions[source] = nil
    end
end)


lib.callback.register('ox_doorlock:getDoors', function(playerId)
    if not playerIsLoaded(playerId) then return false end
    while not isLoaded do Wait(100) end
    if not playerIsLoaded(playerId) then return false end

    return doors, sounds
end)

RegisterNetEvent('ox_doorlock:editDoorlock', function(id, data)
    if not playerIsLoaded(source) then return end
	if IsPlayerAceAllowed(source, 'command.doorlock') then
		if data then
			if not data.coords then
				local double = data.doors
				data.coords = double[1].coords - ((double[1].coords - double[2].coords) / 2)
			end

			if not data.name then
				data.name = tostring(data.coords)
			end
		end

		if id then
			if data then
				MySQL.update('UPDATE ox_doorlock SET name = ?, data = ? WHERE id = ?',
					{ data.name, encodeData(data), id })
			else
				MySQL.update('DELETE FROM ox_doorlock WHERE id = ?', { id })
			end

			doors[id] = data
			TriggerClientEvent('ox_doorlock:editDoorlock', -1, id, data)
		else
			local insertId = MySQL.insert.await('INSERT INTO ox_doorlock (name, data) VALUES (?, ?)', { data.name, encodeData(data) })
			local door = createDoor(insertId, data, data.name)

			TriggerClientEvent('ox_doorlock:setState', -1, door.id, door.state, false, door)
		end
	end
end)

lib.addCommand('doorlock', {
	help = locale('create_modify_lock'),
	params = {
		{
			name = 'closest',
			help = locale('command_closest'),
			optional = true,
		},
	},
	restricted = Config.CommandPrincipal
}, function(source, args)
    if not playerIsLoaded(source) then return end
	TriggerClientEvent('ox_doorlock:triggeredCommand', source, args.closest)
end)

local registeredUsableLockpicks = false

local function registerUsableLockpicks()
    if registeredUsableLockpicks then return true end
    if GetResourceState('node7-core') ~= 'started' or GetResourceState('node7-inventory') ~= 'started' then return false end

    local Node7Core = exports['node7-core']:GetCoreObject()
    if not Node7Core or not Node7Core.Functions or not Node7Core.Functions.CreateUseableItem then
        print('[ox_doorlock] NODE7 CreateUseableItem is unavailable.')
        return false
    end

    for i = 1, #Config.LockpickItems do
        local itemName = Config.LockpickItems[i]

        Node7Core.Functions.CreateUseableItem(itemName, function(playerId, itemData)
            playerId = tonumber(playerId)
            if not playerId or not playerIsLoaded(playerId) then return end

            if not exports['node7-inventory']:HasItem(playerId, itemName, 1) then
                return Node7Core.Functions.Notify(playerId, {
                    title = 'DOOR LOCK',
                    description = 'You need a lockpick.',
                    type = 'error',
                    duration = 4000,
                })
            end

            TriggerClientEvent('ox_doorlock:useLockpickItem', playerId, itemData and itemData.slot)
        end)
    end

    registeredUsableLockpicks = true
    print(('[ox_doorlock] Registered %s NODE7 usable lockpick item(s).'):format(#Config.LockpickItems))
    return true
end

CreateThread(function()
    while not registerUsableLockpicks() do Wait(500) end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'node7-core' or resourceName == 'node7-inventory' then
        registeredUsableLockpicks = false
        SetTimeout(500, registerUsableLockpicks)
    end
end)

RegisterCommand('doorpicktest', function(playerId)
    if playerId == 0 then
        return print('[ox_doorlock] /doorpicktest must be used in game.')
    end

    if not IsPlayerAceAllowed(playerId, 'ox_doorlock.test') or not playerIsLoaded(playerId) then return end
    TriggerClientEvent('ox_doorlock:useLockpickItem', playerId)
end, false)
