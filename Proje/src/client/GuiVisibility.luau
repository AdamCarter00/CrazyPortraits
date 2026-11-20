--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Binding = require(ReplicatedStorage:WaitForChild("Shared").Config.Binding)

local GuiVisibility = {}
GuiVisibility.__index = GuiVisibility

-- Yalniz isaret attribute'u olan ScreenGui'lere dokunur: Roblox'un TouchGui'si ve ayni PlayerGui'deki
-- baska her sey oldugu gibi kalir (mobil joystick buna bagli).
function GuiVisibility.new(playerGui: any)
	return setmetatable({ playerGui = playerGui, hidden = {} }, GuiVisibility)
end

function GuiVisibility:HideExcept(keep: { any })
	self:Restore()
	for _, gui in self.playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui:GetAttribute(Binding.MarkerAttribute) ~= nil and table.find(keep, gui) == nil then
			if gui.Enabled then
				table.insert(self.hidden, gui)
				gui.Enabled = false
			end
		end
	end
end

function GuiVisibility:Restore()
	for _, gui in self.hidden do
		gui.Enabled = true
	end
	table.clear(self.hidden)
end

return GuiVisibility
