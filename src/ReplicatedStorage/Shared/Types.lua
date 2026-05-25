-- Types.lua
-- Just the names and labels we use in lots of places. Putting them in one
-- module means we don't have typos like "Warden" vs "warden" causing bugs.

local Types = {}

Types.Team = {
    Warden = "Warden",
    Yokai = "Yokai",
}

Types.Character = {
    Momotaro = "Momotaro",
    Rokurokubi = "Rokurokubi",
    GirlA = "GirlA",
}

-- Which team each character belongs to.
Types.CharacterTeam = {
    Momotaro = Types.Team.Warden,
    Rokurokubi = Types.Team.Yokai,
    GirlA = Types.Team.Yokai,
}

Types.RoundState = {
    Lobby = "Lobby",
    InRound = "InRound",
    Ending = "Ending",
}

return Types
