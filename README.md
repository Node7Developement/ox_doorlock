# ox_doorlock — NODE7 RedM

A RedM-only ox_doorlock build integrated with `node7-core`, `node7-inventory`, `node7-lockpick-minigame`, `ox_target`, `ox_lib`, and `oxmysql`.

## Required start order

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_target
ensure node7-core
ensure node7-inventory
ensure node7-lockpick-minigame
ensure ox_doorlock
```

## Runtime behavior

Door data and normal door interactions initialize with the resource. The administrator interface remains hidden and opens only when an authorised player explicitly uses `/doorlock`.

## Restart relocking

`Config.RelockOnRestart = true` resets every stored door to state `1` (locked) before the server exposes the door list. The locked baseline is also written back to the database.

## Usage

Use `/doorlock` to create or edit doors. Use the configured RedM interaction prompt or `ox_target` actions to lock, unlock, or pick registered doors.

## API

```lua
exports.ox_doorlock:useClosestDoor()
exports.ox_doorlock:pickClosestDoor()
local door = exports.ox_doorlock:getDoor(1)
exports.ox_doorlock:setDoorState(1, 1)
```

## NODE7 integration

- NODE7 core notifications and character/job/gang authorization
- NODE7 inventory item checks and lockpick removal
- NODE7 lockpick minigame sessions with server validation
- RedM prompts and door natives
- Restart relocking and command-only administrator UI

## Door Settings

### General

- Door name
  - Used to easily identify the door.
- Passcode
  - Door can be unlocked by anybody by using the code or phrase.
- Autolock interval
  - Door will be locked after x seconds.
- Interact distance
  - Door can only be used when within x metres.
- Door rate
  - Door movement speed for sliding/garage/automatic doors, or swinging doors when locked.
- Locked
  - Sets the door as locked by default.
- Double
  - Door is a set of two doors, controlled together.
- Automatic
  - Sliding/garage/automatic door.
- Lockpick
  - Door can be lockpicked when interacting with a targeting resource.
- Hide UI
  - No indicators (i.e. icon, text) will display on the door.

### Characters

- Character Id
  - Character identifier used by a framework (i.e. player.charid, xPlayer.identifier, Player.CitizenId).

### Groups

- Group
  - Framework dependent, referring to jobs, gangs, etc.
- Grade
  - The minimum grade to allow access for the group (0 to allow all).

### Items

- Item
  - Name of the item.
- Metadata type
  - Requires metadata support (i.e. ox_inventory) to check slot.metadata.type

### Lockpick

- Difficulty
  - Sets the skillcheck difficulty (see [docs](https://overextended.github.io/docs/ox_lib/Interface/Client/skillcheck)).
- Area size
  - Custom difficulty area size.
- Speed multiplier
  - Custom difficulty idicator speed.

## NODE7 RedM integration

This build preserves the ox_doorlock door/database logic while adding:

- NODE7 core notifications (enabled by default with `Config.Notify = true`)
- NODE7 inventory lockpick item support
- `node7-lockpick-minigame` integration
- `ox_target` lockpick interactions
- RedM manifest support and the required prerelease acknowledgement
- Black-and-gold 700×500 administrator interface
- Visible action buttons and option cards instead of dropdown/context menus

The NUI page remains transparent outside the doorlock window.

> RedM note: GTA's `DoorSystemSetHoldOpen` native is not used. Door locking and unlocking are handled with RedM-supported door-state natives.


## NODE7 command-only editor fix

The management NUI is closed on startup and opens only from the authorised `/doorlock` command. Explicit open and close NUI messages prevent a false hide payload from being interpreted as an open request.
