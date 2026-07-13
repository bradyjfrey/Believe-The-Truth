-- AbilityBindings.lua
-- ONE shared list of who-gets-which-keys. Two scripts read it:
--   * AbilityInput.client.lua binds the keys to ability requests
--   * HUD.client.lua draws the ability icons + cooldown shading from the same rows
-- Add a row here and both pick it up. Keep each row's Ability name EXACTLY matching
-- the name the character module passes to startCooldown (and its Constants table key).
--
-- Fields per row:
--   Ability - the ability's code name (matches Constants + the server module)
--   Key     - KeyCode or UserInputType to bind
--   Label   - friendly name shown on the HUD icon and the mobile touch button
--   Hold    - true for press-and-hold abilities (fires Begin/End phases)
--   HudOnly - true = show on the HUD but DON'T bind the key here, because another
--             script owns that key (e.g. DisguisePickerUI owns Rokurokubi's R)

local AbilityBindings = {
	Momotaro = {
		{Ability = "Katana",     Key = Enum.KeyCode.Q, Label = "Katana"},
		{Ability = "GuardDog",   Key = Enum.KeyCode.E, Label = "Inuta"},
		{Ability = "MessyEater", Key = Enum.KeyCode.R, Label = "Banana"},
		{Ability = "KibiDango",  Key = Enum.KeyCode.F, Label = "Dango"},
	},
	Rokurokubi = {
		{Ability = "Bite",     Key = Enum.UserInputType.MouseButton1, Label = "Bite"},
		{Ability = "NeckWrap", Key = Enum.KeyCode.Q,                  Label = "Wrap"},
		{Ability = "Disguise", Key = Enum.KeyCode.R,                  Label = "Disguise", HudOnly = true},
	},
	GirlA = {
		{Ability = "Slash",           Key = Enum.UserInputType.MouseButton1, Label = "Slash"},
		{Ability = "BreachOfPrivacy", Key = Enum.KeyCode.Q,                  Label = "Breach"},
		{Ability = "StrayBlade",      Key = Enum.KeyCode.E,                  Label = "Blade", Hold = true},
		{Ability = "IncognitoMode",   Key = Enum.KeyCode.R,                  Label = "Hide"},
	},
	Otohime = {
		{Ability = "DarkMoon",     Key = Enum.KeyCode.Q, Label = "Dark Moon"},
		{Ability = "HealingPulse", Key = Enum.KeyCode.E, Label = "Heal"},
	},
}

return AbilityBindings
