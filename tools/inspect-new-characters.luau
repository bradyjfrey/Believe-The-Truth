-- READ-ONLY health check for the kids' NEW character models. Changes nothing.
-- Sweeps Workspace for: Kasa Obake, Okiku, Tomino, Bobzilla, Two Time Prime, Verity.
-- Paste the whole thing into the Roblox Studio Command Bar and press Enter.
--
-- For each model found it prints one report card:
--   * part/joint counts and any parts NOT welded to the rest (they'd fall off or get
--     left behind the moment the model moves or spawns unanchored)
--   * whether it has a Humanoid + HumanoidRootPart (a "rig") — playable characters
--     need one; a decoration NPC like Kasa Obake doesn't
--   * its size next to our finished characters, so scale problems jump out
--   * any scripts hiding inside (we always delete those)
--
-- Anchored parts count as "holding together" while a model is ON DISPLAY in Workspace.
-- The report says how many parts are anchored — that's fine for now, but a PLAYABLE
-- character must end up fully unanchored with everything welded to its root before it
-- can spawn and walk. We handle that in each character's dressing pass later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Who we're looking for: label + lowercase name fragments that count as a match.
local WANTED = {
	{ label = "Kasa Obake",     keys = { "kasa", "obake" } },
	{ label = "Okiku the Doll", keys = { "okiku" } },
	{ label = "Tomino",         keys = { "tomino" } },
	{ label = "Bobzilla",       keys = { "bobzilla" } },
	{ label = "Two Time Prime", keys = { "two time", "twotime", "prime" } },
	{ label = "Verity",         keys = { "verity" } },
}

-- Print our finished characters' heights once, as the measuring stick.
print("==================================================")
print("SIZE REFERENCE — finished characters:")
local characterModels = ReplicatedStorage:FindFirstChild("CharacterModels")
if characterModels then
	for _, m in ipairs(characterModels:GetChildren()) do
		if m:IsA("Model") then
			local size = m:GetExtentsSize()
			print(("   %-12s %4.1f studs tall  (%.1f x %.1f footprint)")
				:format(m.Name, size.Y, size.X, size.Z))
		end
	end
else
	print("   (ReplicatedStorage.CharacterModels not found — skipping reference)")
end

-- Find candidates in Workspace by name fragment (kids name things their own way).
-- Matches Models AND Folders (the kids often use a Folder as the top container) and
-- even a bare BasePart (Verity is a single MeshPart). Skips things nested inside an
-- already-matched container so one character doesn't print twice.
local function findMatches(keys)
	local found = {}
	local function nameMatches(inst)
		local name = inst.Name:lower()
		for _, key in ipairs(keys) do
			if name:find(key, 1, true) then return true end
		end
		return false
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart")) and nameMatches(d) then
			local insideExisting = false
			for _, already in ipairs(found) do
				if d:IsDescendantOf(already) then insideExisting = true break end
			end
			if not insideExisting then table.insert(found, d) end
		end
	end
	return found
end

-- Bounding box that works for ANY container (Folder has no GetExtentsSize). Axis-aligned
-- approximation from every part's position + size — close enough for a scale eyeball.
local function extentsOf(container)
	if container:IsA("Model") then return container:GetExtentsSize() end
	local minV, maxV = nil, nil
	local list = container:GetDescendants()
	if container:IsA("BasePart") then table.insert(list, container) end
	for _, d in ipairs(list) do
		if d:IsA("BasePart") then
			local lo = d.Position - d.Size / 2
			local hi = d.Position + d.Size / 2
			minV = minV and Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) or lo
			maxV = maxV and Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) or hi
		end
	end
	if not minV then return Vector3.zero end
	return maxV - minV
end

-- One report card per model.
local function inspect(label, model)
	print("==================================================")
	print(("%s  ->  %s"):format(label, model:GetFullName()))

	-- Gather parts and every kind of joint the kids might have used.
	local parts, jointCount, anchoredCount = {}, 0, 0
	local connectedTo = {}
	local function link(a, b)
		if not (a and b) then return end
		connectedTo[a] = connectedTo[a] or {}
		connectedTo[b] = connectedTo[b] or {}
		table.insert(connectedTo[a], b)
		table.insert(connectedTo[b], a)
	end
	local humanoid = nil
	local scanList = model:GetDescendants()
	if model:IsA("BasePart") then table.insert(scanList, model) end
	for _, d in ipairs(scanList) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d.Anchored then anchoredCount += 1 end
		elseif d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			-- JointInstance covers Weld, Motor6D, Snap, ManualWeld
			link(d.Part0, d.Part1)
			jointCount += 1
		elseif d:IsA("Humanoid") then
			humanoid = d   -- may be nested inside a sub-model when the container is a Folder
		end
	end
	if #parts == 0 then
		warn("   ⚠️ no parts at all inside this model?")
		return
	end

	-- Rig check: does it have the pieces a playable character needs?
	local rootPart = model:IsA("BasePart") and nil or model:FindFirstChild("HumanoidRootPart", true)
	local primaryName = (model:IsA("Model") and model.PrimaryPart) and model.PrimaryPart.Name
		or "<none>"
	print(("   Parts: %d   Joints/Welds: %d   Anchored: %d of %d")
		:format(#parts, jointCount, anchoredCount, #parts))
	print(("   Humanoid: %s   HumanoidRootPart: %s   PrimaryPart: %s")
		:format(humanoid and "yes" or "NO", rootPart and "yes" or "NO", primaryName))

	-- Size vs the reference list above.
	local size = extentsOf(model)
	print(("   Size: %.1f studs tall  (%.1f x %.1f footprint)"):format(size.Y, size.X, size.Z))

	-- Scripts hiding inside (free-asset / copy-paste risk — we write our own behavior).
	local scriptCount = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			scriptCount += 1
			warn("   ⚠️ script inside: " .. d:GetFullName() .. "  — delete unless we put it there")
		end
	end
	if scriptCount == 0 then print("   Scripts inside: none ✅") end

	-- Hold-together check: flood-fill through the joints starting from the best "core"
	-- part (root if it has one). Anything the flood can't reach is a loose part.
	local core = rootPart or (model:IsA("Model") and model.PrimaryPart)
	if not core then
		-- No obvious core: use the biggest part as the body.
		local biggest, biggestVolume = nil, 0
		for _, p in ipairs(parts) do
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > biggestVolume then biggest, biggestVolume = p, v end
		end
		core = biggest
	end
	local reached = { [core] = true }
	local queue = { core }
	while #queue > 0 do
		local p = table.remove(queue)
		for _, other in ipairs(connectedTo[p] or {}) do
			if not reached[other] then
				reached[other] = true
				table.insert(queue, other)
			end
		end
	end
	local loose = {}
	for _, p in ipairs(parts) do
		if not reached[p] then table.insert(loose, p) end
	end

	if #loose == 0 then
		print(("   Welds: ✅ every part is connected to '%s'"):format(core.Name))
	else
		warn(("   Welds: ⚠️ %d part(s) NOT connected to '%s' — they'll fall off / get left behind:")
			:format(#loose, core.Name))
		-- Show up to 15 so a fully-unwelded model doesn't flood the Output.
		for i, p in ipairs(loose) do
			if i > 15 then
				warn(("      ...and %d more"):format(#loose - 15))
				break
			end
			warn(("      - '%s'  (in '%s')  Anchored=%s")
				:format(p.Name, p.Parent and p.Parent.Name or "?", tostring(p.Anchored)))
		end
		print("   Fix: select a loose part + the body part it should stick to, then Model tab > Weld.")
	end
end

-- Run the sweep.
for _, want in ipairs(WANTED) do
	local matches = findMatches(want.keys)
	if #matches == 0 then
		print("==================================================")
		warn(("%s: not found in Workspace (name doesn't contain %s?)")
			:format(want.label, table.concat(want.keys, " / ")))
	else
		for _, model in ipairs(matches) do
			inspect(want.label, model)
		end
	end
end
print("==================================================")
print("Sweep done.")
