texture = {}

local function _clamp( x, xmin, xmax )
	if x < xmin then
		return xmin
	elseif x > xmax then
		return xmax
	end

	return x
end

function smootherstep( x, xmin, xmax )
	local t =  _clamp((x - xmin)/(xmax - xmin), 0, 1);
   
    return t*t*t*(t*(t*6 - 15) + 10)
end

function texture.clut( bands, w, h )
	assert(bands[1] and bands[100])

	local result = love.image.newImageData(w, h)

	for y = 0, h-1 do
		local probe = 1 + y * (99 / (h - 1))

		local lowerpc = 0
		local upperpc = 100

		for percent, color in pairs(bands) do
			if percent <= probe and percent > lowerpc then
				lowerpc = percent
			end

			if percent >= probe and percent < upperpc then
				upperpc = percent
			end
		end

		local r, g, b, a

		if lowerpc == upperpc then
			local color = bands[lowerpc]	
			r, g, b, a = color[1], color[2], color[3], color[4]
		else
			local lower = bands[lowerpc]
			local upper = bands[upperpc]

			local bias = smootherstep(probe, lowerpc, upperpc)
			
			r = (1 - bias) * lower[1] + bias * upper[1]
			g = (1 - bias) * lower[2] + bias * upper[2]
			b = (1 - bias) * lower[3] + bias * upper[3]
			a = (1 - bias) * lower[4] + bias * upper[4]
		end

		for x = 0, w-1 do
			result:setPixel(x, y, r, g, b, a)
		end
	end

	return love.graphics.newImage(result)
end

