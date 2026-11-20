--!strict

-- Nesne adi = isaret. Yalniz plan uretir; attribute yazmak tools/isaretle.luau'nun isi.
local Marker = {}

export type Entry = { mark: string, class: string, selectable: boolean?, group: string? }

local function pathOf(inst: any): string
	return inst:GetFullName()
end

function Marker.plan(root: any, expected: { Entry }, attribute: string, selectedMark: string)
	local byName: { [string]: { any } } = {}
	local expectedSet: { [string]: boolean } = { [selectedMark] = true }
	for _, entry in expected do
		expectedSet[entry.mark] = true
	end
	local carriers = {}
	for _, inst in root:GetDescendants() do
		local list = byName[inst.Name]
		if list == nil then
			list = {}
			byName[inst.Name] = list
		end
		table.insert(list, inst)
		if inst:GetAttribute(attribute) ~= nil then
			table.insert(carriers, inst)
		end
	end

	local assign = {}
	local problems = {}
	local okMarks = {}
	local wanted: { [any]: string } = {}

	local function claim(inst: any, mark: string)
		wanted[inst] = mark
		table.insert(assign, { inst = inst, mark = mark })
	end

	for _, entry in expected do
		local list = byName[entry.mark] or {}
		local before = #problems
		if #list == 0 then
			table.insert(problems, { kind = "eksik", mark = entry.mark, group = entry.group })
		elseif #list > 1 then
			local paths = {}
			for _, inst in list do
				table.insert(paths, pathOf(inst))
			end
			table.insert(problems, { kind = "cift", mark = entry.mark, group = entry.group, detail = table.concat(paths, " | ") })
		elseif not list[1]:IsA(entry.class) then
			table.insert(problems, {
				kind = "sinif",
				mark = entry.mark,
				group = entry.group,
				detail = `{entry.class} bekleniyordu, {list[1].ClassName}`,
			})
		else
			claim(list[1], entry.mark)
			if entry.selectable then
				local strokes = {}
				for _, child in list[1]:GetChildren() do
					if child.Name == selectedMark then
						table.insert(strokes, child)
					end
				end
				if #strokes == 0 then
					table.insert(problems, { kind = "secili_eksik", mark = entry.mark, group = entry.group })
				elseif #strokes > 1 or not strokes[1]:IsA("UIStroke") then
					table.insert(problems, {
						kind = "secili_hatali",
						mark = entry.mark,
						group = entry.group,
						detail = `{#strokes} nesne, ilki {strokes[1].ClassName}`,
					})
				else
					claim(strokes[1], selectedMark)
					if strokes[1].Enabled then
						table.insert(problems, { kind = "secili_acik", mark = entry.mark, group = entry.group, warning = true })
					end
				end
			end
		end
		if #problems == before then
			okMarks[entry.mark] = true
		end
	end

	local clear = {}
	for _, inst in carriers do
		if wanted[inst] == nil then
			local old = inst:GetAttribute(attribute)
			table.insert(clear, {
				inst = inst,
				old = old,
				reason = if expectedSet[old] then "adi isaretle uyusmuyor" else "taninmayan isaret",
			})
		end
	end

	return { assign = assign, problems = problems, clear = clear, okMarks = okMarks }
end

function Marker.report(plan: any, expected: { Entry }): { string }
	local totals: { [string]: number } = {}
	local done: { [string]: number } = {}
	local groups: { string } = {}
	for _, entry in expected do
		local group = entry.group or "diger"
		if totals[group] == nil then
			totals[group] = 0
			done[group] = 0
			table.insert(groups, group)
		end
		totals[group] += 1
		if plan.okMarks[entry.mark] then
			done[group] += 1
		end
	end
	local lines = {}
	for _, group in groups do
		table.insert(lines, `{group}: {done[group]}/{totals[group]}`)
	end
	for _, problem in plan.problems do
		local label = if problem.warning then "uyari" else problem.kind
		local detail = if problem.detail then ` ({problem.detail})` else ""
		table.insert(lines, `  {label}: {problem.mark}{detail}`)
	end
	for _, item in plan.clear do
		table.insert(lines, `  eski isaret: {pathOf(item.inst)} Isaret={item.old} ({item.reason})`)
	end
	return lines
end

return Marker
