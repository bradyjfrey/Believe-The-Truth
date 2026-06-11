# Plan: Lobby hangout + spawn into Map 1

Status: proposed (2026-06-10). Waiting on Brady's decisions (see "Decisions for Brady").

## The problem, in one line
Players never get sent to the play map — the whole round happens in the lobby — and a
player who joins while waiting has **no body** (the "sky view"), because nothing spawns
them until a round-state transition fires.

## How the system actually works today
`RoundService` is a 3-state machine (`Lobby` → `InRound` → `Ending` → back to `Lobby`),
ticked once per second by `Bootstrap`.

- `Bootstrap.server.lua:17` sets `Players.CharacterAutoLoads = false` — Roblox never
  auto-spawns anyone. RoundService is supposed to do all spawning.
- `Bootstrap` `PlayerAdded` → `watchPlayer` only **wires up** a `CharacterAdded` handler
  (to set HP/speed). It does **NOT** call `LoadCharacter()`. So a fresh joiner has no body.
- `RoundService:_enterLobby()` (line 98) clears each player's role attributes, then loops
  `player:LoadCharacter()` — **with no spawn position**.
- `RoundService:_enterRound()` (line 139) assigns Team + Character, then loops
  `player:LoadCharacter()` — again **with no spawn position**.
- **There is no teleport / SpawnLocation logic anywhere in code.** Where a body appears is
  left entirely to Roblox's default SpawnLocation behavior — which is why everyone lands in
  the lobby (that's where the SpawnLocation is) and the round plays out there.
- **There are no camera scripts.** The "sky view" is not a deliberate camera — it's just
  what you see when you have no character for the camera to follow.

### So the two bugs are:
1. **Join-while-waiting = sky view.** No `LoadCharacter` on join → bodiless → floating cam.
2. **Round runs in the lobby.** `_enterRound` never moves anyone to Map 1.

Both come from the **same gap**: spawning never specifies *where*.

## Target flow
| Moment | What should happen |
|---|---|
| Player joins during Lobby | Spawn a **plain** body in the **lobby**, free to walk around while "Waiting (X/Y)" ticks |
| Lobby countdown hits 0 (enough players) | Move everyone to **Map 1** with their role + (later) dressed character |
| Round ends | Return everyone to the **lobby** |
| Player joins **mid-round** | DECISION NEEDED — spectate, or wait in the lobby |

Good news: the **lobby body is already plain** — `_enterLobby` nils the `Character`
attribute, so `applyCharacterStats` returns early and you stay the default avatar. We only
need to control *where* people spawn.

## Design

### Spawn markers (live in Workspace, so not in git — code finds them by name)
Brady places one anchored, invisible marker Part in each place:
- `Workspace.Maps.Finished Lobby` → a Part named **`LobbySpawn`**
- `Workspace.Environment.Map 1` → a Part named **`MapSpawn`** (or `WardenSpawn` + `YokaiSpawn`
  if we want the Yokai to start away from the Wardens — see decisions)

The code reads `marker.CFrame`, and if a marker is missing it falls back to a safe default
coordinate (and `warn`s), so a missing marker never hard-crashes a round.

### One small helper (new), used everywhere we spawn
```lua
-- Spawn `player` and drop them at `cframe` (a bit above it so they don't clip the floor).
local function spawnPlayerAt(player, cframe)
    player:LoadCharacter()
    local char = player.Character or player.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart")
    char:PivotTo(cframe + Vector3.new(0, 3, 0))
end

-- Find a spawn CFrame by marker name under a Workspace path; fall back if missing.
local function spawnCFrame(folderPath, markerName, fallback)
    local node = workspace
    for _, name in ipairs(folderPath) do
        node = node and node:FindFirstChild(name)
    end
    local marker = node and node:FindFirstChild(markerName, true)
    if marker and marker:IsA("BasePart") then return marker.CFrame end
    warn("[Spawn] missing marker " .. markerName .. " — using fallback")
    return fallback
end

local LOBBY_SPAWN = function() return spawnCFrame({"Maps","Finished Lobby"}, "LobbySpawn", CFrame.new(0, 10, 0)) end
local MAP_SPAWN   = function() return spawnCFrame({"Environment","Map 1"}, "MapSpawn", CFrame.new(0, 50, 0)) end
```

### Server changes
1. **`_enterLobby`** — replace the bare `LoadCharacter` loop with:
   ```lua
   local lobbyAt = LOBBY_SPAWN()
   for _, player in ipairs(Players:GetPlayers()) do
       spawnPlayerAt(player, lobbyAt)
   end
   ```
2. **`_enterRound`** — after assigning Team/Character, spawn at the map instead of bare LoadCharacter:
   ```lua
   local mapAt = MAP_SPAWN()
   for _, player in ipairs(players) do
       ...assign team/character/abilities...
       spawnPlayerAt(player, mapAt)   -- (or a per-team marker)
   end
   ```
3. **Join handling** — add `RoundService:OnPlayerJoined(player)` and call it from
   `Bootstrap`'s `PlayerAdded`:
   ```lua
   function RoundService:OnPlayerJoined(player)
       if state == Types.RoundState.Lobby then
           spawnPlayerAt(player, LOBBY_SPAWN())     -- walk around the lobby while waiting
       else
           -- mid-round joiner: DECISION — spectate, or hold in the lobby. See below.
           spawnPlayerAt(player, LOBBY_SPAWN())     -- (placeholder: park them in the lobby)
       end
   end
   ```
   No camera code needed — the default camera follows the new character automatically.

### What this does NOT change (on purpose)
- **Appearance is still the old placeholder.** During a round, `applyCharacterStats` →
  `CharacterAppearance.apply` still recolors a default avatar (red Yokai / tan Warden). This
  plan fixes *where* people are, not *what they look like*.
- Swapping the round spawn to clone the **dressed models** (GirlA etc.) is the *next* piece —
  see the seam below. Keeping them separate means we debug "flow" and "appearance" one at a time.

### The seam to the dressed-character work
`_enterRound` is exactly where the dressed-model spawn will eventually plug in. Today it's
`LoadCharacter()` + `ApplyDescription`. Later it becomes: clone
`ReplicatedStorage.CharacterModels[characterName]`, set it as `player.Character`, position at
the map spawn, and skip `ApplyDescription`. So the `spawnPlayerAt` helper grows a variant like
`spawnPlayerAsModel(player, model, cframe)`. We can land the flow fix now and graft the dressed
models on top once Momotaro & Rokurokubi are dressed too.

## Decisions for Brady
1. **Mid-round joiner** — when someone joins while a round is already running, should they
   (a) sit in the lobby with a body until the next round *(my recommendation — no sky cam,
   they can walk around)*, or (b) spectate the live round with a free camera?
2. **Map 1 spawn points** — one shared `MapSpawn`, or separate **`WardenSpawn`** and
   **`YokaiSpawn`** so the killer starts away from the survivors? *(Recommend separate
   eventually; fine to start with one shared and split later.)*
3. **Who places the markers** — you drop a `LobbySpawn` Part in the lobby and a `MapSpawn`
   Part in Map 1 (you know the good spots), and I wire the code to them? Or want me to have the
   code auto-create defaults at fixed coordinates (like the placeholder Hotspots already do)?
4. **Existing SpawnLocation** — is there currently a `SpawnLocation` in the lobby? If so we
   keep it (harmless) or remove it; the explicit teleport overrides it either way.

## Suggested build order (small, testable steps)
1. **Lobby-on-join** (`OnPlayerJoined` + `LobbySpawn` marker) → fixes the sky-view-while-waiting.
2. **Round → Map 1** (`_enterRound` teleport + `MapSpawn` marker) → the round finally happens
   on the play map.
3. **Round-end → lobby** is automatic once #1's `_enterLobby` teleport is in.
4. *(Later)* dressed-model role spawn grafts onto `_enterRound`.

Steps 1–3 are one small, shared change (the helper + three call sites + two markers). Low risk,
each independently testable with the 2-client Test we've been using.
