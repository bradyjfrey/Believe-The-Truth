local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

local OVERRIDES = {}

local HEAD_HINTS = { "hair", "eye", "mask", "head" }
local TORSO_HINTS = { "shirt", "back", "pocket", "base" }

local R15_LIMBS = {
	"HumanoidRootPart", "UpperTorso", "LowerTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local source = Selection:Get()[1]
if not source then
	warn("Select Tomino in the Explorer first.")
	return
end

local clone = source:Clone()

local parts, humanoid = {}, nil
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	elseif d:IsA("Humanoid") then
		humanoid = d
	end
end

if not humanoid then
	warn("No Humanoid found — is this Tomino?")
	clone:Destroy()
	return
end

local limbs = {}
local missing = {}
for _, name in ipairs(R15_LIMBS) do
	local part = clone:FindFirstChild(name, true)
	if part and part:IsA("BasePart") then
		limbs[name] = part
	else
		table.insert(missing, name)
	end
end
if #missing > 0 then
	warn("NOT DRESSING. Tomino's R15 rig is missing: " .. table.concat(missing, ", "))
	clone:Destroy()
	return
end

local dressed = Instance.new("Model")
dressed.Name = "StarterCharacter"

humanoid.Parent = dressed
humanoid.AutomaticScalingEnabled = false
for _, part in pairs(limbs) do
	part.Parent = dressed
end
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("Motor6D") then
		d.Parent = limbs[d.Part0 and d.Part0.Name] or dressed
	end
end

local limbList = {}
for _, part in pairs(limbs) do
	if part.Name ~= "HumanoidRootPart" then table.insert(limbList, part) end
end

local function anyHint(name, hints)
	local lower = name:lower()
	for _, hint in ipairs(hints) do
		if lower:find(hint, 1, true) then return true end
	end
	return false
end

local function nearestLimb(p)
	local best, bestDist
	for _, limb in ipairs(limbList) do
		local d = (limb.Position - p.Position).Magnitude
		if not bestDist or d < bestDist then bestDist, best = d, limb end
	end
	return best
end

local function targetFor(p)
	local forced = OVERRIDES[p.Name]
	if forced then
		if limbs[forced] then return limbs[forced], true end
		warn(("OVERRIDES names '%s' for '%s', but there's no such limb."):format(forced, p.Name))
	end
	if anyHint(p.Name, HEAD_HINTS) then return limbs.Head, false end
	if anyHint(p.Name, TORSO_HINTS) then return limbs.UpperTorso, false end
	return nearestLimb(p), false
end

local report, overridden = {}, 0
for _, p in ipairs(parts) do
	if not limbs[p.Name] then
		local limb, wasForced = targetFor(p)
		if wasForced then overridden += 1 end
		p.Parent = dressed
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = p
		weld.Parent = p
		table.insert(report, ("   %-24s -> %-16s%s"):format(p.Name:sub(1, 24), limb.Name, wasForced and "  (forced)" or ""))
	end
end

for _, d in ipairs(dressed:GetDescendants()) do
	if (d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("WeldConstraint")) and (d.Part0 == nil or d.Part1 == nil) then
		d:Destroy()
	end
	if d:IsA("BasePart") then d.Anchored = false end
end

dressed.PrimaryPart = limbs.HumanoidRootPart
clone:Destroy()

local old = StarterPlayer:FindFirstChild("StarterCharacter")
if old then old:Destroy() end
dressed.Parent = StarterPlayer

print("==================================================")
print("TOMINO DRESSED  (R15 rig kept, costume welded onto it)")
print("==================================================")
print(("%d costume parts welded, %d of them forced by OVERRIDES."):format(#report, overridden))
print("")
for _, line in ipairs(report) do print(line) end
print("")
print("Wrong limb? Add it to OVERRIDES at the top and re-run — don't hand-fix with reweld.luau,")
print("or the fix is lost the next time this runs.")
