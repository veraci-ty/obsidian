--!strict

@native
local function map<T, U>(list: { T }, fn: (T, number) -> U): { U }
	local out = table.create(#list)
	for i, v in ipairs(list) do
		out[i] = fn(v, i)
	end
	return out
end

@native
local function compact<T>(list: { T? }): { T }
	local out = {}
	for _, v in ipairs(list) do
		if v ~= nil then
			table.insert(out, v :: T)
		end
	end
	return out
end

return {
	map = map,
	compact = compact,
}
