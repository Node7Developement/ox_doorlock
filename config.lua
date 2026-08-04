---@type DoorlockConfig
---@diagnostic disable-next-line: missing-fields
Config = {}

---Trigger a notification on the client when the door state is successfully updated.
Config.Notify = true

---Reset every configured door to the locked state whenever ox_doorlock starts.
---This prevents unlocked runtime states from surviving a server or resource restart.
Config.RelockOnRestart = true

---Reject door data and interaction requests until NODE7 has a loaded character for the player.
Config.RequirePlayerLoaded = true

---Create a persistent notification while in-range of a door, prompting to lock/unlock.
Config.DrawTextUI = false

---Set the properties used by DrawSprite.
Config.DrawSprite = {
    -- Unlocked
    [0] = { 'mas_sprite', 'key', 0, 0, 0.024, 0.024, 0, 52, 214, 112, 245 },

    -- Locked
    [1] = { 'mas_sprite', 'key_lock', 0, 0, 0.024, 0.024, 0, 224, 55, 55, 245 },
}



---Clear RedM interaction prompt and state indicator settings.
Config.DoorPrompt = {
    Enabled = true,
    Control = 0xCEFD9220, -- INPUT_CONTEXT / E
    GroupLabel = 'DOOR',
    LockedLabel = 'Unlock Door',
    UnlockedLabel = 'Lock Door',
}

---ox_target interaction distance for lock, unlock, and lockpick options.
Config.TargetDistance = 2.5

---Allow the specified ace principal to use /doorlock.
Config.CommandPrincipal = 'group.admin'

---Allow players with command.doorlock to use any door.
Config.PlayerAceAuthorised = true

---Original ox_doorlock difficulty data remains configurable in the door editor.
Config.LockDifficulty = { 'easy', 'easy', 'medium' }

---Allow lockpicks to lock an already unlocked door.
Config.CanPickUnlockedDoors = false

---Items that function as lockpicks.
Config.LockpickItems = {
    'lockpick'
}

---Play sounds using game audio instead of NUI audio.
Config.NativeAudio = false

---NODE7 lockpick integration. These values do not alter the ox_doorlock UI.
Config.Node7Lockpick = {
    -- When true, every registered locked door can be worked with a lockpick.
    -- Set false to require the per-door lockpick option from the door editor.
    AllowAllLockedDoors = true,

    DefaultDifficulty = 'normal',
    SessionSeconds = 60,
    CooldownMilliseconds = 1500,

    -- Matches the original ox_doorlock probabilities: 1% on success, 20% on failure.
    BreakChanceOnSuccess = 1,
    BreakChanceOnFailure = 20,

    DifficultyMap = {
        easy = 'easy',
        medium = 'normal',
        normal = 'normal',
        hard = 'hard',
        expert = 'expert',
        custom = 'hard',
    }
}
