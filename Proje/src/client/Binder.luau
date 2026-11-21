local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Binding = require(Shared.Config.Binding)
local Drawing = require(Shared.Config.Drawing)
local Round = require(Shared.Config.Round)

local Binder = {}

function Binder.expected()
	local list = {}
	for _, entry in Binding.Marks do
		table.insert(list, entry)
	end
	for _, color in Drawing.Colors do
		table.insert(list, { mark = color.mark, class = "GuiButton", selectable = true, tick = true, group = "cizim" })
	end
	for _, mark in Drawing.BrushMarks do
		table.insert(list, { mark = mark, class = "GuiButton", selectable = true, group = "cizim" })
	end
	for _, name in Round.Emojis do
		table.insert(list, { mark = "emoji_" .. name, class = "GuiButton", selectable = true, group = "emoji" })	end
	for slot = 1, Round.PodiumSize do
		table.insert(list, { mark = "podyum_yuva_" .. slot, class = "Frame", group = "podyum" })
		table.insert(list, { mark = "podyum_tuval_" .. slot, class = "ImageLabel", group = "podyum" })
		table.insert(list, { mark = "podyum_ad_" .. slot, class = "TextLabel", group = "podyum" })
		table.insert(list, { mark = "podyum_tepki_" .. slot, class = "TextLabel", group = "podyum" })
	end
	return list
end

function Binder.expectedWorld()
	return table.clone(Binding.WorldMarks)
end

function Binder.tryCollect(root, expected)
	local found = {}
	for _, inst in root:GetDescendants() do
		local mark = inst:GetAttribute(Binding.MarkerAttribute)
		if mark ~= nil then
			found[mark] = found[mark] or {}
			table.insert(found[mark], inst)
		end
	end

	local problems = {}
	local bound = {}
	local selected = {}
	local ticks = {}
	local function child(parent, className, mark)
		for _, inst in parent:GetChildren() do
			if inst:IsA(className) and inst:GetAttribute(Binding.MarkerAttribute) == mark then
				return inst
			end
		end
		return nil
	end
	for _, entry in expected do
		local list = found[entry.mark] or {}
		if #list == 0 then
			table.insert(problems, "eksik: " .. entry.mark)
		elseif #list > 1 then
			table.insert(problems, ("cift: %s (%d nesne)"):format(entry.mark, #list))
		elseif not list[1]:IsA(entry.class) then
			table.insert(problems, ("yanlis sinif: %s (%s bekleniyordu, %s)"):format(entry.mark, entry.class, list[1].ClassName))
		else
			bound[entry.mark] = list[1]
			if entry.selectable then
				local stroke = child(list[1], "UIStroke", Binding.SelectedMark)
				if stroke then
					selected[entry.mark] = stroke
				else
					table.insert(problems, ("eksik: %s altinda '%s' UIStroke"):format(entry.mark, Binding.SelectedMark))
				end
			end
			if entry.tick then
				local tick = child(list[1], "ImageLabel", Binding.SelectedTick)
				if tick then
					ticks[entry.mark] = tick
				else
					table.insert(problems, ("eksik: %s altinda '%s' ImageLabel"):format(entry.mark, Binding.SelectedTick))
				end
			end
		end
	end

	return bound, selected, problems, ticks
end

-- Kod eksik nesne yaratmaz; eksik, cift ya da yanlis sinif varsa hepsini listeler ve hata verir.
function Binder.collect(root, expected, report)
	report = report or warn
	local bound, selected, problems, ticks = Binder.tryCollect(root, expected)
	if #problems > 0 then
		for _, problem in problems do
			report("[Binder] " .. problem)
		end
		error(("Binder: %d baglama sorunu (ayrinti yukarida)"):format(#problems), 2)
	end
	return bound, selected, ticks
end

-- PlayerGui, StarterGui'den istemci script'i basladiktan sonra dolar: baglama tamamlanana ya da sure bitene kadar beklenir.
function Binder.bind(root, expected, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		local bound, selected, problems, ticks = Binder.tryCollect(root, expected)
		if #problems == 0 then
			return bound, selected, ticks
		end
		task.wait(0.1)
	end
	return Binder.collect(root, expected)
end

return Binder
