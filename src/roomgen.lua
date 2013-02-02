--
-- roomgen/lua
--
-- The roomgen table contained function with the following signature:
--
--   roomgen.<func>( aabb, margin )
--
-- An array of points is the result.
--

roomgen = {
	grid = nil,
}

-- TDOD: not as efficient as an array of arrays.
local function _mask( width, height, default )
	local data = {}

	for i = 1, width * height do
		data[i] = default and true or false
	end

	return {
		width = width,
		height = height,
		set = 
			function ( x, y, value )
				data[((y-1) * width) + x] = value
			end,
		get =
			function ( x, y )
				return data[((y-1) * width) + x]
			end,
		count =
			function ()
				local result = 0

				for i = 1, width * height do
					result = result + (data[i] and 1 or 0)
				end

				return result
			end,
		print =
			function ()
				for x = 1, width do
					local line = {}
					for y = 1, height do
						line[y] = data[((y-1) * width) + x] and 'x' or '.'
					end
					print(table.concat(line))
				end
			end,
	}
end

function roomgen.grid( bbox, margin )
	local points = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * margin)

			points[#points+1] = Vector.new { x, y }
		end
	end

	return points
end

function roomgen.browniangrid( bbox, margin )
	local points = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin


	local mask = _mask(numx, numy, false)

	local centrex, centrey = math.floor(0.5 + (numx * 0.5)), math.floor(0.5 + (numy * 0.5))
	local x, y = centrex, centrey
	local walked = 0
	local maxattempts = 2 * numx * numy

	local dirs = {
		{  0, -1 },
		{  0,  1 },
		{ -1,  0 },
		{  1,  0 },
	}

	local xmin, xmax = numx, 1
	local ymin, ymax = numy, 1

	repeat
		mask.set(x, y, true)
		local dir = dirs[math.random(1, #dirs)]
		x = x + dir[1]
		y = y + dir[2]
		if (x < 1 or numx < x) or (y < 1 or numy < y) then
			if walked > maxattempts * 0.25 and math.random(1, 3) == 1 then
				break
			else
				-- break
				x = centrex
				y = centrey
			end
		end
		xmin = math.min(xmin, x)
		xmax = math.max(xmax, x)
		ymin = math.min(ymin, y)
		ymax = math.max(ymax, y)
		walked = walked + 1
	until walked > maxattempts 

	mask.print()
	print(x, y, numx, numy)


	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			if mask.get(x+1, y+1) then
				local x = xoffset + (x * margin)
				local y = yoffset + (y * margin)

				points[#points+1] = Vector.new { x, y }
			end
		end
	end

	return points
end

function roomgen.cellulargrid( bbox, margin )

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local old, new = _mask(numx, numy, false), _mask(numx, numy, false)

	local centrex, centrey = math.floor(0.5 + (numx * 0.5)), math.floor(0.5 + (numy * 0.5))

	local dirs = {
		{  0, -1 },
		{  0,  1 },
		{ -1,  0 },
		{  1,  0 },
		{  -1, -1 },
		{  -1,  1 },
		{  1,  -1 },
		{  1,  1 },
	}
	
	local area = numx * numy
	local leastAlive = math.round(area * 0.4)
	local mostAlive = math.round(area * 0.6)
	local numAlive = math.random(leastAlive, mostAlive)

	local alive = {}

	for i = 1, area do
		alive[i] = i <= numAlive
	end

	table.shuffle(alive)

	for y = 1, numx do
		for x = 1, numy do
			old.set(x, y, alive[(y-1) * numx + x])
		end
	end

	print('init')
	old.print()

	local passes = 4
	local birth = 3
	local survive = 2
	-- This controls whether cells outside the grid are counted as alive.
	local offMaskIsAlive = false

	for i = 1, passes do
		for y = 1, numx do
			for x = 1, numy do
				local count = 0

				for _, dir in ipairs(dirs) do
					local nx, ny = x + dir[1], y + dir[2]

					if 1 <= nx and nx <= numx and 1 <= ny and ny <= numy then
						count = count + (old.get(nx, ny) and 1 or 0)
					elseif offMaskIsAlive then
						-- The edges of the mask count as alive.
						count = count + 1
					end
				end

				local cell = old.get(x, y)

				if cell then
					new.set(x, y, count > survive)
				else
					new.set(x, y, count >= birth)
				end
			end
		end

		new.print()
		print()

		new, old = old, new
	end

	local mask = old

	new.print()
	print()
	
	local result = {}

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			if mask.get(x+1, y+1) then
				local x = xoffset + (x * margin)
				local y = yoffset + (y * margin)

				result[#result+1] = Vector.new { x, y }
			end
		end
	end

	print('#points', #result)

	return result
end

function roomgen.randgrid( bbox, margin )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / margin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	print(w, margin, numx, gapx)

	local xoffset = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for x = 0, numx-1 do
		for y = 0, numy-1 do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * margin)

			if math.random() > 0.33 then
				result[#result+1] = Vector.new { x, y }
			end
		end
	end

	return result
end

function roomgen.hexgrid( bbox, margin )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	local ymargin = math.sqrt(0.75) * margin

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / ymargin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xmin = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for y = 0, numy-1 do
		local even = (y % 2) == 0
		local xoffset = xmin + (even and 0.5 or 0) * margin

		for x = 0, numx-(even and 2 or 1) do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * ymargin)

			result[#result+1] = { x, y }
		end
	end

	return result
end

function roomgen.randhexgrid( bbox, margin )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	local ymargin = math.sqrt(0.75) * margin

	local numx, gapx = math.modf(w / margin)
	local numy, gapy = math.modf(h / ymargin)
	numx, numy = numx + 1, numy + 1
	gapx, gapy = gapx * margin, gapy * margin

	local xmin = bbox.xmin + (gapx * 0.5)
	local yoffset = bbox.ymin + (gapy * 0.5)

	for y = 0, numy-1 do
		local even = (y % 2) == 0
		local xoffset = xmin + (even and 0.5 or 0) * margin

		for x = 0, numx-(even and 2 or 1) do
			local x = xoffset + (x * margin)
			local y = yoffset + (y * ymargin)

			if math.random() > 0.33 then
				result[#result+1] = Vector.new { x, y }
			end
		end
	end

	return result
end

-- ensure all points are at least margin apart.
-- TODO: make this less terribly inefficient and stupid
local function _sanitise( bbox, margin, points )
	local result = {}

	for i, v in ipairs(points) do
		result[i] = Vector.new(v)
	end

	local count = 0
	local starti, startj = 1, 2

	repeat
		local modified = false

		for i = 1, #result do
			for j = i+1, #result do
				count = count + 1

				local point1 = result[i]
				local point2 = result[j]

				if point1:toLength(point2) < margin then
					-- local killindex = (math.random() >=  0.5) and i or j
					local killindex = math.min(i, j)

					-- print('kill', killindex)

					result[killindex] = result[#result]
					result[#result] = nil

					modified = true
					break
				end
			end

			if modified then
				break
			end
		end
	until not modified

	print('count', count, count / #result)

	return result
end

function roomgen.random( bbox, margin )
	local result = {}

	local w = bbox:width()
	local h = bbox:height()

	-- TODO: Don't always try and fill the area.
	local numpoints = 1.5 * ((w * h) / (margin * margin))

	for i = 1, numpoints do
		result[#result+1] = Vector.new {
			math.random(bbox.xmin, bbox.xmax),
			math.random(bbox.ymin, bbox.ymax),
		}
	end

	result = _sanitise(bbox, margin, result)

	return result
end


