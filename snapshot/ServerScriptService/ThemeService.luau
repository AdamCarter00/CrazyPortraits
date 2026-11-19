local ThemeService = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local rng = Random.new()

ThemeService.themes = {
	-- Physical / Deformation
	"Potato Person",
	"Baby",
	"One Eye",
	"One Leg",
	"Two Heads",
	"Upside Down",
	"Broken Teeth",
	"TV Head",
	"Banana Body",
	"Donut Body",
	"Big Mouth",
	"Tiny Head",

	-- Character / Hybrid
	"Cow Person",
	"Chicken",
	"Fish",
	"Cat",
	"Bird",

	-- Outfit / Cosmetic
	"Colorful Dress",
}

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function ThemeService:PickThemes(count, bannedPerSlot)
	local pool     = { table.unpack(self.themes) }
	local selected = {}

	for i = 1, count do
		if #pool == 0 then
			pool = { table.unpack(self.themes) }
		end

		local banned    = bannedPerSlot and bannedPerSlot[i] or nil
		local candidates = {}

		for _, theme in ipairs(pool) do
			if not (banned and banned[theme]) then
				table.insert(candidates, theme)
			end
		end

		if #candidates == 0 then
			candidates = pool
		end

		local pick = candidates[rng:NextInteger(1, #candidates)]
		table.insert(selected, pick)

		for j = #pool, 1, -1 do
			if pool[j] == pick then
				table.remove(pool, j)
				break
			end
		end
	end

	return selected
end

--------------------------------------------------------------------------------

return ThemeService
