--!strict
local process = require("@lune/process")

type Spec = { { name: string, run: () -> () } }

local specs: { [string]: Spec } = {
	Config = require("./Config.spec"),
	Formulas = require("./Formulas.spec"),
	Distribution = require("./Distribution.spec"),
	PlayerData = require("./PlayerData.spec"),
}
local order = { "Config", "Formulas", "Distribution", "PlayerData" }

local passed, failed = 0, 0
for _, specName in order do
	for _, case in specs[specName] do
		-- pcall here is the test harness catching assertion failures, not hiding errors.
		local ok, err = pcall(case.run)
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL {specName} > {case.name}\n  {err}`)
		end
	end
end

print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
