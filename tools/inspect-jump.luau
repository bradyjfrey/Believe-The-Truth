-- READ-ONLY. Changes nothing. Run this in the Command Bar DURING a round (it reads the live
-- characters on the server) to see why jumping differs per character. Copy the Output back to Brady.
--
-- It prints, for every player: the jump settings actually on their Humanoid right now, whether the
-- Jumping state is enabled, whether they're standing on a floor, and any ANCHORED parts inside their
-- character (e.g. Momotaro's Hawk) -- an anchored part in the character model can block jumping.

local Players = game:GetService("Players")

for _, p in ipairs(Players:GetPlayers()) do
	local char = p.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	if h then
		print(("== %s  (Character attr: %s) =="):format(p.Name, tostring(p:GetAttribute("Character"))))
		print(("   JumpPower=%s  UseJumpPower=%s  JumpHeight=%s  HipHeight=%s")
			:format(tostring(h.JumpPower), tostring(h.UseJumpPower), tostring(h.JumpHeight), tostring(h.HipHeight)))
		print(("   Jumping state enabled=%s   WalkSpeed=%s   FloorMaterial=%s")
			:format(tostring(h:GetStateEnabled(Enum.HumanoidStateType.Jumping)),
				tostring(h.WalkSpeed), tostring(h.FloorMaterial)))

		local anchored, names = 0, {}
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") and d.Anchored then
				anchored += 1
				if #names < 10 then table.insert(names, d.Name) end
			end
		end
		print(("   ANCHORED parts inside character: %d   [%s]"):format(anchored, table.concat(names, ", ")))
	else
		print(("== %s == (no Humanoid yet)"):format(p.Name))
	end
end
