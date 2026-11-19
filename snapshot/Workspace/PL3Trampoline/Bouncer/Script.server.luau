-- @CloneTrooper1019, 2017

local Debris = game:GetService("Debris")

local function onTouched(hit)
	local char = hit.Parent
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			local rootPart = humanoid.RootPart
			if rootPart and rootPart.Velocity.Y < 200 then
				local bv = Instance.new("BodyVelocity")
				bv.MaxForce = Vector3.new(0,10e4,0)
				bv.Velocity = Vector3.new(0,200,0)
				bv.Parent = rootPart
				Debris:AddItem(bv,.25)
			end
		end
	end
end

for _,v in pairs(script.Parent:GetChildren()) do
	if v:IsA("BasePart") then
		v.Touched:Connect(onTouched)
	end
end