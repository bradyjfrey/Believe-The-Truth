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
    Otohime = "Otohime",
    Rokurokubi = "Rokurokubi",
    GirlA = "GirlA",
    Okiku = "Okiku",
    Tomino = "Tomino",
    TwoTimePrime = "TwoTimePrime",
    Verity = "Verity",
    Bobzilla = "Bobzilla",
}

-- Which team each character belongs to.
Types.CharacterTeam = {
    Momotaro = Types.Team.Warden,
    Otohime = Types.Team.Warden,
    Rokurokubi = Types.Team.Yokai,
    GirlA = Types.Team.Yokai,
    Okiku = Types.Team.Yokai,
    Tomino = Types.Team.Yokai,
    TwoTimePrime = Types.Team.Warden,
    Verity = Types.Team.Yokai,
    Bobzilla = Types.Team.Yokai,
}

Types.RoundState = {
    Lobby = "Lobby",
    InRound = "InRound",
    Ending = "Ending",
}

return Types
