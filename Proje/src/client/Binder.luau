local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Binding = require(Shared.Config.Binding)
local Drawing = require(Shared.Config.Drawing)

local Binder = {}

function Binder.expected()
	local list = {}
	for _, entry in Binding.Marks do
		table.insert(list, entry)
	end
	for _, color in Drawing.Colors do
		table.insert(list, { mark = color.mark, class = "GuiButton", selectable = true })
	end
	for _, mark in Drawing.BrushMarks do
		table.insert(list, { mark = mark, class = "GuiButton", selectable = true })
	end
	return list
end

-- Kod eksik nesne yaratmaz: eksik, cift ya da yanlis sinif varsa bepsini Output'a listeler ve hata verir.
function Binder.collect(root, expected, report)
	report = report or warn
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
				local stroke = nil
				for _, child in list[1]:GetChildren() do
					if child:IsA("UIStroke") and child:GetAttribute(Binding.MarkerAttribute) == Binding.SelectedMark then
						stroke = child
					end
				end
				if stroke then
					selected[entry.mark] = stroke
				else
					table.insert(problems, ("eksik: %s altinda '%s' UIStroke"):format(entry.mark, Binding.SelectedMark))
				end
			end
		end
	end

	if #problems > 0 then
		for _, problem in problems do
			report("[Binder] " .. problem)
		end
		error(("Binder: %d baglama sorunu (ayrinti yukarida)"):format(#problems), 2)
	end
	return bound, selected
end

return Binder
