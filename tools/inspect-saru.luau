-- READ-ONLY Saru health check. Changes nothing.
-- The kids build in Workspace; models move to ReplicatedStorage.Companions only after
-- Brady signs off. So this looks for Saru in this order:
--   1. Whatever you have SELECTED in the Explorer (surest way — click the monkey first)
--   2. A model named "Saru" anywhere in Workspace
--   3. ReplicatedStorage > Companions > Saru (its final home, once moved)
-- Paste into the Roblox Studio Command Bar, press Enter.
--
-- Why this matters: Messy Eater spawns Saru WITHOUT anchoring him (he only stands
-- there for a few seconds, then poofs). So the model must hold itself together:
--   GOOD option A: every part Anchored = true
--   GOOD option B: one anchored "root" part, everything else welded to it (directly
--                  or through a chain of welds)
-- Any part that is unanchored AND not weld-connected to an anchored part will fall
-- through the floor / scatter the instant the ability runs. This script finds those.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local saru = Selection:Get()[1]
if not saru then
	saru = workspace:FindFirstChild("Saru", true)
end
if not saru then
	local folder = ReplicatedStorage:FindFirstChild("Companions")
	saru = folder and folder:FindFirstChild("Saru")
end
if not saru then
	warn("Couldn't find Saru. Select the monkey model in the Explorer and run this again.")
	return
end

print("==================================================")
print("SARU CHECK: " .. saru:GetFullName() .. "  (" .. saru.ClassName .. ")")
print("==================================================")

-- Gather every part, plus every joint (welds AND Motor6Ds both count as "connected").
local parts = {}
for _, d in ipairs(saru:GetDescendants()) do
	if d:IsA("BasePart") then table.insert(parts, d) end
end
if saru:IsA("BasePart") then table.insert(parts, saru) end
if #parts == 0 then warn("Saru has no parts at all?") return end

-- Build a "who is stuck to who" map from every joint type the kids might have used.
local connectedTo = {}   -- part -> list of parts it's joined to
local function link(a, b)
	if not (a and b) then return end
	connectedTo[a] = connectedTo[a] or {}
	connectedTo[b] = connectedTo[b] or {}
	table.insert(connectedTo[a], b)
	table.insert(connectedTo[b], a)
end
local jointCount = 0
for _, d in ipairs(saru:GetDescendants()) do
	if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
		-- JointInstance covers Weld, Motor6D, Snap, ManualWeld
		link(d.Part0, d.Part1)
		jointCount += 1
	end
end

-- Flood-fill outward from every ANCHORED part. Anything the flood reaches is safe.
local safe = {}
local queue = {}
for _, p in ipairs(parts) do
	if p.Anchored then
		safe[p] = true
		table.insert(queue, p)
	end
end
while #queue > 0 do
	local p = table.remove(queue)
	for _, other in ipairs(connectedTo[p] or {}) do
		if not safe[other] then
			safe[other] = true
			table.insert(queue, other)
		end
	end
end

-- Report card ---------------------------------------------------------------
local anchoredCount, fallers = 0, {}
for _, p in ipairs(parts) do
	if p.Anchored then anchoredCount += 1 end
	if not safe[p] then table.insert(fallers, p) end
end

local primary = saru:IsA("Model") and saru.PrimaryPart
print(("Parts: %d   Anchored: %d   Joints/Welds: %d   PrimaryPart: %s")
	:format(#parts, anchoredCount, jointCount, primary and primary.Name or "<none — code will pick one>"))

-- Any scripts hiding inside? (We always write our own behavior; a script inside
-- the model would run on spawn.)
for _, d in ipairs(saru:GetDescendants()) do
	if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
		warn("  Script found inside Saru: " .. d:GetFullName() .. "  — delete it unless we put it there.")
	end
end

if #fallers == 0 then
	print("RESULT: ✅ Saru holds together — every part is anchored or welded to an anchored part.")
else
	warn(("RESULT: ⚠️ %d part(s) will FALL when he spawns:"):format(#fallers))
	for _, p in ipairs(fallers) do
		-- Say where it lives so it's easy to find in the Explorer.
		warn(("   - '%s'  (in '%s')  Anchored=%s"):format(
			p.Name, p.Parent and p.Parent.Name or "?", tostring(p.Anchored)))
	end
	print("Fix: either tick Anchored on those parts, or add a WeldConstraint from each one")
	print("to a part that IS anchored (select both parts, then Model tab > Weld).")
end
print("==================================================")
