-- RIG QUADRUPED DOGS
-- Select BOTH dog models in Studio, then copy this whole file into the Command Bar and Enter.
-- Adds a HumanoidRootPart + the dog joints. (Walking ANIMATION is a separate hand-made step.)

local Selection = game:GetService("Selection")

local LINKS = {
	{"UpperTorso", "HumanoidRootPart", "Root"},
	{"Neck", "UpperTorso", "NeckJoint"},
	{"Head", "Neck", "HeadJoint"},
	{"UpperJaw", "Head", "UpperJawJoint"},
	{"LowerJaw", "Head", "LowerJawJoint"},
	{"Nose", "Head", "NoseJoint"},
	{"LeftEar", "Head", "LeftEarJoint"},
	{"RightEar", "Head", "RightEarJoint"},
	{"LeftFrontLeg", "UpperTorso", "LeftFrontHip"},
	{"RightFrontLeg", "UpperTorso", "RightFrontHip"},
	{"LeftBackLeg", "UpperTorso", "LeftBackHip"},
	{"RightBackLeg", "UpperTorso", "RightBackHip"},
	{"Tail", "UpperTorso", "TailJoint"},
}

for _, model in ipairs(Selection:Get()) do
	if model:IsA("Model") then
		local function P(n)
			local d = model:FindFirstChild(n, true)
			if d and d:IsA("BasePart") then return d end
			return nil
		end
		local torso = P("UpperTorso")
		if not torso then
			warn(model.Name .. ": no 'UpperTorso' - skipped.")
		else
			local hum = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
			hum.Parent = model
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if not hrp then
				hrp = Instance.new("Part")
				hrp.Name = "HumanoidRootPart"
				hrp.Size = torso.Size
				hrp.Transparency = 1
				hrp.CanCollide = false
				hrp.CFrame = torso.CFrame
				hrp.Parent = model
			end
			local made = 0
			local skipped = {}
			for _, link in ipairs(LINKS) do
				local childName = link[1]
				local parentName = link[2]
				local jointName = link[3]
				local child = (childName == "HumanoidRootPart") and hrp or P(childName)
				local parent = (parentName == "HumanoidRootPart") and hrp or P(parentName)
				if child and parent then
					local m = Instance.new("Motor6D")
					m.Name = jointName
					m.Part0 = parent
					m.Part1 = child
					m.C0 = parent.CFrame:ToObjectSpace(child.CFrame)
					m.C1 = CFrame.new()
					m.Parent = parent
					made = made + 1
				else
					table.insert(skipped, childName)
				end
			end
			local known = {}
			known["UpperTorso"] = true
			known["HumanoidRootPart"] = true
			for _, l in ipairs(LINKS) do known[l[1]] = true end
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and not known[p.Name] then
					local w = Instance.new("WeldConstraint")
					w.Part0 = torso
					w.Part1 = p
					w.Parent = torso
				end
			end
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = false end
			end
			hrp.Anchored = true
			model.PrimaryPart = hrp
			local skipText = "none"
			if #skipped > 0 then skipText = table.concat(skipped, ", ") end
			print(model.Name .. ": rigged with " .. made .. " joints. Not found: " .. skipText)
		end
	end
end
