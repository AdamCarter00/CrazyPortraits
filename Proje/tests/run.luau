--!nocheck

local process = require("@lune/process")

local KosuBitti = require("./lib/KosuBitti")

local args = { "run", "tests/kosu.luau" }
for _, arg in process.args do
	table.insert(args, arg)
end

local result = process.exec("lune", args, { stdio = "inherit" })
if result.code == KosuBitti then
	process.exit(0)
end
if result.code == 0 then
	print("  [KOSU YARIM KALDI] ozet yazilmadan bitti; bir spec ana is parcaciginda yield etmis olabilir")
	process.exit(1)
end
process.exit(result.code)
