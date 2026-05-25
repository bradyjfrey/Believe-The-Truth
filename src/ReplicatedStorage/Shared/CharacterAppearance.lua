-- CharacterAppearance.lua
-- Visual look per character. Bootstrap calls CharacterAppearance.apply when a
-- player spawns as that character, after their HP and walk speed are set.

local Players = game:GetService("Players")
--
-- For each character, the Data table lists:
--   Body         - colors for the standard HumanoidDescription slots
--   PartOverrides- per-part color tweaks applied AFTER the description (hands/feet)
--   Accessories  - extra Parts we weld on (sword, sash, satchel, etc.)
--   Catalog      - free Roblox catalog asset IDs (hair, face, shirt, pants)
--
-- To add a new character: add a new Data entry below.
-- To tweak an existing one: change the hex codes / accessory specs.
-- To upgrade to real art: fill in the Catalog asset IDs.

local CharacterAppearance = {}

------------------------------------------------------------------------------
-- Data per character
------------------------------------------------------------------------------

CharacterAppearance.Data = {
    Momotaro = {
        Body = {
            -- Skin tone: Pantone "Peach Fuzz" (13-1023 TCX)
            Head     = Color3.fromHex("f8b892"),
            LeftArm  = Color3.fromHex("f8b892"),
            RightArm = Color3.fromHex("f8b892"),
            -- Happi coat / hakama top: Pantone "Peach Pink" (16-1626 TPX)
            Torso    = Color3.fromHex("ef9080"),
            -- Hakama pants: blue
            LeftLeg  = Color3.fromHex("506ec0"),
            RightLeg = Color3.fromHex("506ec0"),
        },
        PartOverrides = {
            -- Fingerless gloves: dark purple
            LeftHand  = Color3.fromHex("330541"),
            RightHand = Color3.fromHex("330541"),
            -- Open-toed socks: same dark purple as gloves
            LeftFoot  = Color3.fromHex("330541"),
            RightFoot = Color3.fromHex("330541"),
        },
        Accessories = {
            -- Green obi sash around waist with a knot in front
            {Type = "Sash", Color = Color3.fromHex("3d6b3a")},
            -- Brown satchel — strap diagonally across chest, pouch on left hip
            {Type = "Satchel", Color = Color3.fromHex("8B6F47")},
            -- Katana held in right hand, blade pointing down at his side
            {
                Type = "SwordInHand",
                BladeColor = Color3.fromHex("c0c0c0"),
                HiltColor  = Color3.fromHex("2a1f15"),  -- dark wrap
                TsubaColor = Color3.fromHex("f8b892"),  -- peach (matches palette)
            },
        },
        Catalog = {
            Hair  = "12401269941",          -- Brady-picked: cropped shaggy hair from Creator Store
            -- TODO when art lands:
            -- Face  = "rbxassetid://...",  -- spec: green eyes #608666
            -- Shirt = "rbxassetid://...",  -- happi coat texture
            -- Pants = "rbxassetid://...",  -- hakama texture
        },
    },

    Rokurokubi = {
        Body = {
            -- Pale geisha-white skin
            Head     = Color3.fromHex("f5e3d4"),
            LeftArm  = Color3.fromHex("f5e3d4"),
            RightArm = Color3.fromHex("f5e3d4"),
            -- Red kimono top (solid color placeholder — real cherry-blossom
            -- pattern needs a shirt-template upload)
            Torso    = Color3.fromHex("b22222"),
            -- Kimono skirt: same red
            LeftLeg  = Color3.fromHex("b22222"),
            RightLeg = Color3.fromHex("b22222"),
        },
        PartOverrides = {
            -- Feet: traditional dark sandals
            LeftFoot  = Color3.fromHex("1a0a0a"),
            RightFoot = Color3.fromHex("1a0a0a"),
        },
        Accessories = {
            -- Iconic stretched neck — head floats high above the torso with
            -- a pale column connecting them. Per spec: neck must be LONGER
            -- than the rest of her body (~4 studs from torso to feet), so 6.
            -- Always visible in her base form; Disguise (when she copies a
            -- Warden) hides this. TODO: have DisguiseService un-stretch on
            -- apply / re-stretch on drop.
            {Type = "StretchedNeck", SegmentStuds = 6, SkinColor = Color3.fromHex("f5e3d4")},
            -- Obi sash (darker red) with a knot in front
            {Type = "Sash", Color = Color3.fromHex("4a0e0e")},
            -- Red folding fan held in her left hand
            {Type = "FanInHand", Color = Color3.fromHex("b22222"), HandleColor = Color3.fromHex("1a1a1a")},
        },
        Catalog = {
            -- Full avatar Bundle — the red kimono character from the Creator
            -- Store. Replaces body + clothing + accessories with the bundle's,
            -- which is exactly what we want for Rokurokubi's base look. Our
            -- own accessories (stretched neck, fan) still get welded on top.
            Bundle = 13358640198,
            -- TODO when art lands:
            -- Hair  = ...   -- (only needed if the bundle's hair doesn't match — spec: black with red beads)
            -- Face  = ...   -- (only needed if the bundle's face doesn't match — spec: red eyes, white paint)
        },
    },

    GirlA = {
        Body = {
            -- Deep red Neon-glowing "skin" (the binary code pattern needs a
            -- texture upload; for now the whole skin is a uniform glow).
            Head     = Color3.fromHex("c81818"),
            LeftArm  = Color3.fromHex("c81818"),
            RightArm = Color3.fromHex("c81818"),
            -- Sailor uniform top: white (TorsoColor sets both UpperTorso and
            -- LowerTorso; we then override LowerTorso below for the skirt)
            Torso    = Color3.fromHex("f5f5f5"),
            -- Legs: same red glowing skin as arms
            LeftLeg  = Color3.fromHex("c81818"),
            RightLeg = Color3.fromHex("c81818"),
        },
        PartOverrides = {
            -- Skirt area: dark teal-green
            LowerTorso = Color3.fromHex("1f4d3f"),
            -- Shoes: black mary-janes
            LeftFoot   = Color3.fromHex("1a1a1a"),
            RightFoot  = Color3.fromHex("1a1a1a"),
        },
        -- Neon material on the red-skin parts makes them glow.
        Materials = {
            Head      = Enum.Material.Neon,
            LeftArm   = Enum.Material.Neon,
            RightArm  = Enum.Material.Neon,
            LeftLeg   = Enum.Material.Neon,
            RightLeg  = Enum.Material.Neon,
        },
        -- Binary-code pattern tiled across her glowing skin parts. If this
        -- doesn't read well on Neon material (Neon can wash out overlays),
        -- swap the Materials above to SmoothPlastic.
        BodyTextures = {
            Head     = "rbxassetid://37444347",
            LeftArm  = "rbxassetid://37444347",
            RightArm = "rbxassetid://37444347",
            LeftLeg  = "rbxassetid://37444347",
            RightLeg = "rbxassetid://37444347",
        },
        Accessories = {
            -- Bloody cleaver held in her right hand
            {Type = "CleaverInHand", BladeColor = Color3.fromHex("c0c0c0"), HandleColor = Color3.fromHex("1a1a1a")},
            -- Pop-up particles around her (visual hook for the "Red Room Curse" theme)
            {Type = "GlitchPopupParticles"},
        },
        Catalog = {
            -- TODO when art lands:
            -- Hair  = "rbxassetid://...",  -- spec: dark brown, messy, medium length
            -- Face  = "rbxassetid://...",  -- spec: red glitchy face, no features visible
            -- Shirt = "rbxassetid://...",  -- spec: sailor uniform top with green collar, dirty
            -- Pants = "rbxassetid://...",  -- spec: dark teal skirt + white knee socks
        },
    },
}

------------------------------------------------------------------------------
-- Apply
------------------------------------------------------------------------------

function CharacterAppearance.apply(player, characterName)
    local data = CharacterAppearance.Data[characterName]
    if not data then return end

    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- 1. Body colors + clothing/accessory setup via HumanoidDescription.
    --
    -- Two paths depending on Catalog.Bundle:
    --   A. Catalog.Bundle is set -> fetch that bundle's full description and
    --      use it as the base. Body colors + clothing + accessories all come
    --      from the bundle. We can still override Hair/Face on top.
    --   B. No Bundle -> start from the player's current description, overwrite
    --      our body colors, wipe their personal clothing/accessories so their
    --      avatar doesn't cover our look, then add our chosen catalog items.
    if data.Body or data.Catalog then
        local desc
        local fromBundle = false

        if data.Catalog and data.Catalog.Bundle then
            local bundleId = tonumber(data.Catalog.Bundle)
            if bundleId then
                local ok, bundleDesc = pcall(function()
                    return Players:GetHumanoidDescriptionFromBundleId(bundleId)
                end)
                if ok and bundleDesc then
                    desc = bundleDesc
                    fromBundle = true
                end
            end
        end

        if not desc then
            desc = humanoid:GetAppliedDescription()
        end

        -- Body color overrides (apply on top of whatever the base set).
        if data.Body then
            if data.Body.Head     then desc.HeadColor     = data.Body.Head end
            if data.Body.LeftArm  then desc.LeftArmColor  = data.Body.LeftArm end
            if data.Body.RightArm then desc.RightArmColor = data.Body.RightArm end
            if data.Body.Torso    then desc.TorsoColor    = data.Body.Torso end
            if data.Body.LeftLeg  then desc.LeftLegColor  = data.Body.LeftLeg end
            if data.Body.RightLeg then desc.RightLegColor = data.Body.RightLeg end
        end

        -- Only wipe if we started from the player's avatar (not from a bundle).
        if not fromBundle then
            -- Wipe legacy clothing slots
            desc.Shirt          = 0
            desc.Pants          = 0
            desc.GraphicTShirt  = 0
            desc.HatAccessory   = ""
            desc.HairAccessory  = ""
            desc.FaceAccessory  = ""
            desc.NeckAccessory  = ""
            desc.ShouldersAccessory = ""
            desc.FrontAccessory = ""
            desc.BackAccessory  = ""
            desc.WaistAccessory = ""
            -- Wipe LAYERED CLOTHING accessories (the new system). Many modern
            -- avatars use this for shirts/jackets/pants and the legacy fields
            -- above don't touch them. SetAccessories({}, true) clears both
            -- layered and rigid accessories at once.
            pcall(function()
                desc:SetAccessories({}, true)
            end)
        end

        -- Catalog overrides (hair, face, shirt, pants). These run AFTER the
        -- bundle/wipe so they can override individual slots without losing
        -- the rest.
        if data.Catalog then
            if data.Catalog.Hair  then desc.HairAccessory = data.Catalog.Hair end
            if data.Catalog.Face  then desc.Face = tonumber(data.Catalog.Face) or 0 end
            if data.Catalog.Shirt then desc.Shirt = tonumber(data.Catalog.Shirt) or 0 end
            if data.Catalog.Pants then desc.Pants = tonumber(data.Catalog.Pants) or 0 end
        end

        humanoid:ApplyDescription(desc)

        -- Wait one frame so Roblox finishes its internal re-render. Without
        -- this, per-part Color/Material overrides below get clobbered by the
        -- description system finishing its work.
        task.wait()
    end

    -- 2. Per-part color overrides — applied AFTER the description so they
    --    don't get overwritten.
    if data.PartOverrides then
        for partName, color in pairs(data.PartOverrides) do
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.Color = color
            end
        end
    end

    -- 2b. Per-part material overrides (e.g. Neon for Girl A's glowing skin).
    if data.Materials then
        for partName, material in pairs(data.Materials) do
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.Material = material
            end
        end
    end

    -- 2c. Per-part texture overlays. We tile the texture across all 6 faces
    --     of the part so the pattern wraps around the body.
    if data.BodyTextures then
        local ALL_FACES = {
            Enum.NormalId.Front, Enum.NormalId.Back,
            Enum.NormalId.Left,  Enum.NormalId.Right,
            Enum.NormalId.Top,   Enum.NormalId.Bottom,
        }
        for partName, textureId in pairs(data.BodyTextures) do
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                for _, face in ipairs(ALL_FACES) do
                    local texture = Instance.new("Texture")
                    texture.Name = "BodyTexture_" .. face.Name
                    texture.Texture = textureId
                    texture.Face = face
                    texture.StudsPerTileU = 2
                    texture.StudsPerTileV = 2
                    texture.Parent = part
                end
            end
        end
    end

    -- 3. Accessories we build ourselves (sword, sash, satchel, etc.).
    if data.Accessories then
        -- Folder so we can find + remove all of them at once later (used by
        -- DisguiseService when she copies a Warden's look).
        local folder = character:FindFirstChild("AppearanceAccessories")
        if folder then folder:Destroy() end
        folder = Instance.new("Folder")
        folder.Name = "AppearanceAccessories"
        folder.Parent = character

        for _, accessory in ipairs(data.Accessories) do
            CharacterAppearance._buildAccessory(character, folder, accessory)
        end
    end
end

------------------------------------------------------------------------------
-- Builders
------------------------------------------------------------------------------

local function weldTo(part, attachTo, offsetCFrame)
    part.CFrame = attachTo.CFrame * offsetCFrame
    local w = Instance.new("WeldConstraint")
    w.Part0 = attachTo
    w.Part1 = part
    w.Parent = part
end

function CharacterAppearance._buildAccessory(character, parent, spec)
    if spec.Type == "Sash" then
        local lowerTorso = character:FindFirstChild("LowerTorso")
        if not lowerTorso then return end

        -- Ring around the waist
        local sash = Instance.new("Part")
        sash.Name = "Sash"
        sash.Size = Vector3.new(2.1, 0.4, 1.2)
        sash.Color = spec.Color
        sash.Material = Enum.Material.Fabric
        sash.CanCollide = false
        sash.Massless = true
        sash.Parent = parent
        weldTo(sash, lowerTorso, CFrame.new(0, 0.5, 0))

        -- Little knotted bow in front
        local knot = Instance.new("Part")
        knot.Name = "SashKnot"
        knot.Size = Vector3.new(0.7, 0.5, 0.35)
        knot.Color = spec.Color
        knot.Material = Enum.Material.Fabric
        knot.CanCollide = false
        knot.Massless = true
        knot.Parent = parent
        weldTo(knot, lowerTorso, CFrame.new(0, 0.5, -0.7))

    elseif spec.Type == "Satchel" then
        local upperTorso = character:FindFirstChild("UpperTorso")
        local lowerTorso = character:FindFirstChild("LowerTorso")
        if not upperTorso or not lowerTorso then return end

        -- Strap: thin diagonal Part across the chest (right shoulder → left hip)
        local strap = Instance.new("Part")
        strap.Name = "SatchelStrap"
        strap.Size = Vector3.new(0.18, 4, 0.18)
        strap.Color = spec.Color
        strap.Material = Enum.Material.Fabric
        strap.CanCollide = false
        strap.Massless = true
        strap.Parent = parent
        weldTo(strap, upperTorso, CFrame.new(0, 0, -0.55) * CFrame.Angles(0, 0, math.rad(30)))

        -- Pouch on the left hip
        local pouch = Instance.new("Part")
        pouch.Name = "SatchelPouch"
        pouch.Size = Vector3.new(1.2, 1, 0.55)
        pouch.Color = spec.Color
        pouch.Material = Enum.Material.Fabric
        pouch.CanCollide = false
        pouch.Massless = true
        pouch.Parent = parent
        weldTo(pouch, lowerTorso, CFrame.new(-0.7, 0.3, -0.55))

    elseif spec.Type == "StretchedNeck" then
        -- Rokurokubi's iconic feature. We offset the head Motor6D so the head
        -- floats SegmentStuds above its normal position, then add a pale
        -- column between the torso and the new head spot.
        local upperTorso = character:FindFirstChild("UpperTorso")
        local head = character:FindFirstChild("Head")
        if not upperTorso or not head then return end

        -- The Neck Motor6D in R15 lives inside the Head, not UpperTorso.
        -- Search the whole character to be safe across rig variations.
        local neck = nil
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("Motor6D") and descendant.Name == "Neck" then
                neck = descendant
                break
            end
        end
        if not neck then return end

        -- Offset the head joint upward
        neck.C0 = neck.C0 * CFrame.new(0, spec.SegmentStuds, 0)

        -- Pale cylinder filling the gap (cylinder's long axis is X, so we
        -- rotate 90 around Z to make it vertical)
        local neckColumn = Instance.new("Part")
        neckColumn.Name = "ElongatedNeck"
        neckColumn.Shape = Enum.PartType.Cylinder
        neckColumn.Size = Vector3.new(spec.SegmentStuds + 0.5, 0.7, 0.7)
        neckColumn.Color = spec.SkinColor
        neckColumn.Material = Enum.Material.SmoothPlastic
        neckColumn.CanCollide = false
        neckColumn.Massless = true
        neckColumn.Parent = parent
        -- Centered halfway up the new neck. UpperTorso's top is roughly y=+1
        -- in its own space; the head originally sits ~0.5 above that.
        weldTo(neckColumn, upperTorso, CFrame.new(0, 1 + spec.SegmentStuds / 2, 0) * CFrame.Angles(0, 0, math.rad(90)))

    elseif spec.Type == "FanInHand" then
        -- A folding fan held in the left hand. Rendered as a thin half-disc
        -- (we approximate with a flat block).
        local leftHand = character:FindFirstChild("LeftHand")
        if not leftHand then return end

        local fan = Instance.new("Part")
        fan.Name = "Fan"
        fan.Size = Vector3.new(2, 1.8, 0.1)
        fan.Color = spec.Color
        fan.Material = Enum.Material.Fabric
        fan.CanCollide = false
        fan.Massless = true
        fan.Parent = parent
        weldTo(fan, leftHand, CFrame.new(0, -1, 0))

        local handle = Instance.new("Part")
        handle.Name = "FanHandle"
        handle.Size = Vector3.new(0.15, 0.6, 0.15)
        handle.Color = spec.HandleColor
        handle.Material = Enum.Material.Wood
        handle.CanCollide = false
        handle.Massless = true
        handle.Parent = parent
        weldTo(handle, leftHand, CFrame.new(0, -0.2, 0))

    elseif spec.Type == "CleaverInHand" then
        -- Big rectangular blade with a black handle, held in the right hand.
        local rightHand = character:FindFirstChild("RightHand")
        if not rightHand then return end

        local blade = Instance.new("Part")
        blade.Name = "CleaverBlade"
        blade.Size = Vector3.new(1.4, 1.8, 0.1)
        blade.Color = spec.BladeColor
        blade.Material = Enum.Material.Metal
        blade.CanCollide = false
        blade.Massless = true
        blade.Parent = parent
        weldTo(blade, rightHand, CFrame.new(0.4, -1.3, 0))

        local handle = Instance.new("Part")
        handle.Name = "CleaverHandle"
        handle.Size = Vector3.new(0.2, 0.9, 0.2)
        handle.Color = spec.HandleColor
        handle.Material = Enum.Material.Wood
        handle.CanCollide = false
        handle.Massless = true
        handle.Parent = parent
        weldTo(handle, rightHand, CFrame.new(0, -0.3, 0))

    elseif spec.Type == "GlitchPopupParticles" then
        -- Tiny red popup-like particles drifting around her body, evoking the
        -- "Red Room Curse" pop-up theme. Placeholder texture (default
        -- ParticleEmitter image) until art uploads a real pop-up icon.
        local upperTorso = character:FindFirstChild("UpperTorso")
        if not upperTorso then return end

        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "PopupParticles"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromHex("c81818"))
        emitter.Size = NumberSequence.new(0.4)
        emitter.Lifetime = NumberRange.new(1.5, 2.5)
        emitter.Rate = 4
        emitter.Speed = NumberRange.new(1, 2)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.LightEmission = 0.5
        emitter.Parent = upperTorso

    elseif spec.Type == "SwordInHand" then
        -- Katana held in the right hand, blade pointing down. It'll swing
        -- naturally with the arm animation.
        local rightHand = character:FindFirstChild("RightHand")
        if not rightHand then return end

        local blade = Instance.new("Part")
        blade.Name = "KatanaBlade"
        blade.Size = Vector3.new(0.12, 4, 0.4)
        blade.Color = spec.BladeColor
        blade.Material = Enum.Material.Metal
        blade.CanCollide = false
        blade.Massless = true
        blade.Parent = parent
        weldTo(blade, rightHand, CFrame.new(0, -2.3, 0))

        local hilt = Instance.new("Part")
        hilt.Name = "KatanaHilt"
        hilt.Size = Vector3.new(0.2, 0.9, 0.4)
        hilt.Color = spec.HiltColor
        hilt.Material = Enum.Material.Fabric
        hilt.CanCollide = false
        hilt.Massless = true
        hilt.Parent = parent
        weldTo(hilt, rightHand, CFrame.new(0, -0.3, 0))

        -- Tsuba (circular guard at base of blade). Cylinder shape — its long
        -- axis is X, so we rotate it 90° around Z to make it a flat disc.
        local tsuba = Instance.new("Part")
        tsuba.Name = "KatanaTsuba"
        tsuba.Shape = Enum.PartType.Cylinder
        tsuba.Size = Vector3.new(0.1, 0.85, 0.85)
        tsuba.Color = spec.TsubaColor
        tsuba.Material = Enum.Material.Metal
        tsuba.CanCollide = false
        tsuba.Massless = true
        tsuba.Parent = parent
        weldTo(tsuba, rightHand, CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.rad(90)))
    end
end

return CharacterAppearance
