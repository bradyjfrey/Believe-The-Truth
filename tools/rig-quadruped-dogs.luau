local Selection = game:GetService("Selection")
local LINKS = { 
    {"UpperTorso","HumanoidRootPart","Root"}, {"Neck","UpperTorso","NeckJoint"},
    {"Head","Neck","HeadJoint"}, {"UpperJaw","Head","UpperJawJoint"},
    {"LowerJaw","Head","LowerJawJoint"}, {"Nose","Head","NoseJoint"},
    {"LeftEar","Head","LeftEarJoint"}, {"RightEar","Head","RightEarJoint"},
    {"LeftFrontLeg","UpperTorso","LeftFrontHip"}, {"RightFrontLeg","UpperTorso","RightFrontHip"},
    {"LeftBackLeg","UpperTorso","LeftBackHip"}, {"RightBackLeg","UpperTorso","RightBackHip"},
    {"Tail","UpperTorso","TailJoint"},
}     
for _, model in ipairs(Selection:Get()) do
    if model:IsA("Model") then
            local function P(n) local d = model:FindFirstChild(n, true); return (d and d:IsA("BasePart")) and d or
            local torso = P("UpperTorso") 
            if not torso then warn(model.Name .. ": no 'UpperTorso' - skipped."); continue end
            local hum = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid"); hum.Parent = model
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then
                    hrp = Instance.new("Part")
                    hrp.Name, hrp.Size, hrp.Transparency, hrp.CanCollide = "HumanoidRootPart", torso.Size, 1, false
                    hrp.CFrame, hrp.Parent = torso.CFrame, model
            end     
            local made, skipped = 0, {}
            for _, link in ipairs(LINKS) do
                    local child = (link[1]=="HumanoidRootPart") and hrp or P(link[1])
                    local parent = (link[2]=="HumanoidRootPart") and hrp or P(link[2])
                    if child and parent then
                            local m = Instance.new("Motor6D")
                            m.Name, m.Part0, m.Part1 = link[3], parent, child
                            m.C0, m.C1 = parent.CFrame:ToObjectSpace(child.CFrame), CFrame.new()
                            m.Parent = parent
                            made = made + 1
                    else table.insert(skipped, link[1]) end
            end     
            local known = {UpperTorso=true, HumanoidRootPart=true}
            for _, l in ipairs(LINKS) do known[l[1]] = true end
            for _, p in ipairs(model:GetDescendants()) do
                    if p:IsA("BasePart") and not known[p.Name] then
                            local w = Instance.new("WeldConstraint"); w.Part0, w.Part1, w.Parent = torso, p, torso
                    end     
            end     
            for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = false end end
            hrp.Anchored = true
            model.PrimaryPart = hrp
            print(("%s: rigged with %d joints. Not found: %s"):format(model.Name, made, #skipped>0 and table.concat
or "none"))   
    end
end  