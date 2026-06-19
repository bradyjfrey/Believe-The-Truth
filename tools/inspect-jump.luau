-- READ-ONLY. Changes nothing. Run in the Command Bar DURING a round. Compares what makes Momotaro
-- different from Girl A for jumping: total weight, current state, how many parts actually have mass,
-- and any physics movers/constraints that might be pinning him down. Copy the Output back to Brady.

local Players = game:GetService("Players")

local MOVER_CLASSES = {
	BodyPosition = true, BodyVelocity = true, BodyForce = true, BodyGyro = true,
	BodyThrust = true, BodyAngularVelocity = true, LinearVelocity = true,
	AlignPosition = true, AlignOrientation = true, VectorForce = true, Torque = true,
}

for _, p in ipairs(Players:GetPlayers()) do
	local char = p.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if h and root then
		print(("== %s  (%s) =="):format(p.Name, tostring(p:GetAttribute("Character"))))
		print(("   AssemblyMass=%.1f   Humanoid state=%s   PlatformStand=%s   Sit=%s")
			:format(root.AssemblyMass, tostring(h:GetState()), tostring(h.PlatformStand), tostring(h.Sit)))

		-- How many parts carry weight, and the heaviest few.
		local total, withMass, heavy = 0, 0, {}
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				total += 1
				if not d.Massless then
					withMass += 1
					table.insert(heavy, { name = d.Name, mass = d:GetMass() })
				end
			end
		end
		table.sort(heavy, function(a, b) return a.mass > b.mass end)
		local top = {}
		for i = 1, math.min(5, #heavy) do
			top[i] = ("%s=%.1f"):format(heavy[i].name, heavy[i].mass)
		end
		print(("   parts=%d   with mass (NOT massless)=%d   heaviest: [%s]")
			:format(total, withMass, table.concat(top, ", ")))

		-- Any physics movers/constraints anywhere in the character?
		local movers = {}
		for _, d in ipairs(char:GetDescendants()) do
			if MOVER_CLASSES[d.ClassName] then
				table.insert(movers, d.ClassName .. " in " .. (d.Parent and d.Parent.Name or "?"))
			end
		end
		print(("   movers/constraints: %s"):format(#movers > 0 and table.concat(movers, ", ") or "none"))
	end
end
