--!nocheck
-- Studio'da (Edit) komut cubugunda ya da MCP execute_luau ile calisir; Lune'da degil. APPLY=false yalniz raporlar.

local APPLY = false
local WORLD = true
local CLEAR_OLD = true
local ONLY_GROUP = nil -- ör. "cizim": yalniz bu grubun isaretlerini rapor eder ve yazar

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Binding = require(Shared.Config.Binding)
local Marker = require(Shared.Binding.Marker)
local Binder = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Binder)

local function run(label, root, expected)
	if ONLY_GROUP then
		local kept = {}
		for _, entry in expected do
			if entry.group == ONLY_GROUP then
				table.insert(kept, entry)
			end
		end
		expected = kept
	end
	local plan = Marker.plan(root, expected, Binding.MarkerAttribute, Binding.SelectedMark, Binding.SelectedTick)
	if ONLY_GROUP then
		local own, kept = {}, {}
		for _, entry in expected do
			own[entry.mark] = true
		end
		for _, item in plan.clear do
			if own[item.old] then
				table.insert(kept, item)
			end
		end
		plan.clear = kept
	end
	local lines = { `[{label}]` }
	for _, line in Marker.report(plan, expected) do
		table.insert(lines, line)
	end
	if APPLY then
		for _, item in plan.assign do
			if item.inst:GetAttribute(Binding.MarkerAttribute) ~= item.mark then
				item.inst:SetAttribute(Binding.MarkerAttribute, item.mark)
			end
		end
		if CLEAR_OLD then
			for _, item in plan.clear do
				item.inst:SetAttribute(Binding.MarkerAttribute, nil)
			end
		end
	end
	return lines, plan
end

local out = { APPLY and "MOD: yaz" or "MOD: yalniz rapor (APPLY=false)" }
local missing = 0
local lines, plan = run("StarterGui", game:GetService("StarterGui"), Binder.expected())
for _, line in lines do
	table.insert(out, line)
end
missing += #plan.problems
if WORLD then
	lines, plan = run("Workspace", workspace, Binder.expectedWorld())
	for _, line in lines do
		table.insert(out, line)
	end
	missing += #plan.problems
end
table.insert(out, `sorun: {missing}`)

local text = table.concat(out, "\n")
print(text)
return text
