--!strict
local Assert = {}

function Assert.equal(actual: any, expected: any, label: string)
	if actual ~= expected then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

function Assert.near(actual: number, expected: number, tolerance: number, label: string)
	if math.abs(actual - expected) > tolerance then
		error(`{label}: expected {expected} +/- {tolerance}, got {actual}`, 2)
	end
end

function Assert.isTrue(condition: boolean, label: string)
	if not condition then
		error(`{label}: expected true`, 2)
	end
end

function Assert.throws(fn: () -> (), label: string)
	if pcall(fn) then
		error(`{label}: expected an error`, 2)
	end
end

return Assert
