require 'misc'
require 'Vector'
require 'AABB'
require 'graphgen'
require 'layoutgen'
require 'roomgen'
require 'Level'
require 'Actor'
require 'Scheduler'
require 'behaviour'
require 'action'
require 'metalines'
require 'texture'
require 'Voronoi'

local w, h = love.graphics.getWidth(), love.graphics.getHeight()
local track = false
local actions = {}
local playerAction = nil
local diagram = nil

local function _gen()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()

	local rgen =
		function ( ... )
			local r = math.random()
			if r < 0.33 then
				return roomgen.browniangrid(...)
				-- return roomgen.cellulargrid(...)
			elseif r < 0.66 then
				-- return roomgen.random(...)
				return roomgen.enclose(...)
			else
				return roomgen.hexgrid(...)
			end
		end

	-- TODO: need proper config data for the extents and level generation
	--       values.
	-- TODO: room connection should be a parameter.

	local level = Level.new {
		aabb = AABB.new {
			xmin = 0,
			ymin = 0,
			xmax = 3 * w,
			ymax = 3 * h,
		},
		-- margin = 100,
		margin = 50,
		-- margin = 75,
		-- margin = 100,
		layout = layoutgen.splat,
		roomgen = rgen,
	}
	
	return level
end

local level
local time = 0

voronoimode = {}

function voronoimode.update()
	local dt = love.timer.getDelta()
	time = time + dt

	if not level then
		level = _gen()
	end
end

local drawPoints = true
local drawRoomAABBs = false
local drawQuadtree = false
local drawWalls = true
local drawVoronoi = true
local drawHulls = false
local drawEdges = false

function shadowf( x, y, ... )
	love.graphics.setColor(0, 0, 0, 255)

	local text = string.format(...)

	love.graphics.print(text, x-1, y-1)
	love.graphics.print(text, x-1, y+1)
	love.graphics.print(text, x+1, y-1)
	love.graphics.print(text, x+1, y+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, x, y)
end

-- TODO: make an object of this with methods like:
--       - screenToWorld( point )
--       - worldToScreen( point )
--       - centreOnScreenSpace( point )
--       - centreOnWorldSpace( point )
--       - zoomTo( scale )              -- smoothly interpolate.
local xform = {
	scale = 1/3,
	origin = { 0, 0 },
}

function voronoimode.draw()
	love.graphics.push()	
	
	love.graphics.translate(-xform.origin[1], -xform.origin[2])
	love.graphics.scale(xform.scale, xform.scale)

	love.graphics.setLineStyle('rough')

	if drawVoronoi then
		local linewidth = 2
		love.graphics.setLine(linewidth * 1/xform.scale, 'rough')

		local colours = {
			-- { 0, 0, 0, 255 },
			{ 255, 0, 0, 255 },
			{ 0, 255, 0, 255 },
			{ 0, 0, 255, 255 },
			{ 255, 255, 0, 255 },
			{ 255, 0, 255, 255 },
			{ 0, 255, 255, 255 },
			{ 255, 255, 255, 255 },
		}

		for id, cell in ipairs(level.diagram.cells) do
			local vertices = {}

			for _, halfedge in ipairs(cell.halfedges) do
				local startpoint = halfedge:getStartpoint()

				vertices[#vertices+1] = startpoint.x
				vertices[#vertices+1] = startpoint.y
			end

			if #vertices < 3*2 then
				printf('cell id:%d has only %d verts', id, #vertices/2)
			else
				local colour = { 64, 64, 64, 255 }

				if not cell.site.wall then
					-- colour = colours[1 + (id % #colours)]
					colour = { 0, 255, 255, 255 }
				end

				love.graphics.setColor(unpack(colour))
				love.graphics.polygon('fill', vertices)
				if not cell.site.wall then
					love.graphics.setColor(0, 0, 0, 255)
					love.graphics.polygon('line', vertices)
				end
			end
		end
	end

	if drawQuadtree then
		local branch = { 0, 255, 255, 64 }
		local leaf = { 255, 0, 255, 64 }

		local function aux( node )
			local style = 'line'
			if node.leaf then
				love.graphics.setColor(unpack(leaf))
				
				if not node.point then
					style = 'fill'
				end
			else
				love.graphics.setColor(unpack(branch))
			end

			local aabb = node.aabb
			love.graphics.rectangle(style, aabb.xmin, aabb.ymin, aabb:width(), aabb:height())

			if not node.leaf then
				for i = 1, 4 do
					local child = node[i]
					aux(child)
				end
			end
		end

		local root = level.quadtree.root
		if root then
			aux(root)
		end
	end

	if drawRoomAABBs then
		love.graphics.setLineWidth(3)
		love.graphics.setColor(0, 255, 0, 255)

		for index, room in ipairs(level.rooms) do
			local aabb = room.aabb
			love.graphics.rectangle('line', aabb.xmin, aabb.ymin, aabb:width(), aabb:height())
		end
	end

	if drawHulls then
		love.graphics.setColor(255, 255, 0, 255)
		
		for _, room in ipairs(level.rooms) do
			local vertices = {}

			for _, point in ipairs(room.hull) do
				vertices[#vertices+1] = point[1]
				vertices[#vertices+1] = point[2]
			end

			love.graphics.polygon('line', vertices)
		end
	end

	if drawEdges then
		love.graphics.setColor(0, 255, 0, 255)
		
		for edge, endverts in pairs(level.graph.edges) do
			if not endverts[1].wall and not endverts[2].wall then
				love.graphics.line(endverts[1][1], endverts[1][2], endverts[2][1], endverts[2][2])
			end
		end
	end

	if drawPoints then
		love.graphics.setColor(255, 0 , 255, 255)

		for index, room in ipairs(level.rooms) do
			for _, point in ipairs(room.points) do
				local radius = 2
				love.graphics.circle('fill', point[1], point[2], radius)	
			end
		end

		love.graphics.setColor(255, 255 , 255, 255)

		for index, point in ipairs(level.corridors) do
			local radius = 3
			love.graphics.circle('fill', point[1], point[2], radius)
		end

		if drawWalls then
			love.graphics.setColor(128, 128 , 128, 255)

			for index, point in ipairs(level.walls) do
				local radius = 3
				love.graphics.circle('fill', point[1], point[2], radius)
			end
		end
	end

	love.graphics.setColor(0, 0, 255, 128)
	love.graphics.setLineWidth(1)
	for _, core in ipairs(level.cores) do
		love.graphics.polygon('fill', core)
	end

	for vertex, peers in pairs(level.graph.vertices) do
		if table.count(peers) > 8 then
			love.graphics.setColor(0, 0, 0, 128)
			local radius = 10
			love.graphics.circle('fill', vertex[1], vertex[2], radius)
		end
	end

	love.graphics.pop()

	local numPoints = 0

	for index, room in ipairs(level.rooms) do
		numPoints = numPoints + #room.points
	end

	shadowf(10, 10, 'fps:%.2f #p:%d',
		love.timer.getFPS(),
		numPoints)
end

function voronoimode.mousepressed( x, y, button )
	if button == 'wu' then
		xform.scale = math.min(3, xform.scale * 1.05)
		printf('scale:%.2f', xform.scale)
	elseif button == 'wd' then
		xform.scale = math.max(1/3, xform.scale * 0.95)
		printf('scale:%.2f', xform.scale)
	-- elseif button == 'l' then
	-- 	-- Set the centre of the screen to where you clicked.
	-- 	local w, h = love.graphics.getWidth(), love.graphics.getHeight()

	-- 	local wx = xform.origin[1] + (x / xform.scale)
	-- 	local wy = xform.origin[2] + (y / xform.scale)

	-- 	local ox = wx - (w * 0.5)
	-- 	local oy = wy - (h * 0.5)

	-- 	printf('[%d, %d] -> [%.2f, %.2f] -> [%.2f, %.2f]', x, y, wx, wy, ox, oy)

	-- 	xform.origin[1] = ox
	-- 	xform.origin[2] = oy
	end
end

function voronoimode.mousereleased( x, y, button )
end

-- TODO: need a proper declarative interface for setting up controls.
function voronoimode.keypressed( key )
	if key == 'z' then
		if scale ~= 1/3 then
			scale = 1/3
		else
			scale = 1
		end
	elseif key == 'a' then
		drawRoomAABBs = not drawRoomAABBs
	elseif key == 'q' then
		drawQuadtree = not drawQuadtree
	elseif key == 'w' then
		drawWalls = not drawWalls
	elseif key == 'v' then
		drawVoronoi = not drawVoronoi
	elseif key == 'h' then
		drawHulls = not drawHulls
	elseif key == 'e' then
		drawEdges = not drawEdges
	elseif key == 'r' then
		xform.origin = { 0, 0 }
		xform.scale = 1/3
	elseif key == ' ' then
		level = _gen()
	elseif key == 'right' then
		xform.origin[1] = xform.origin[1] + (100 * xform.scale)
	elseif key == 'left' then
		xform.origin[1] = xform.origin[1] - (100 * xform.scale)
	elseif key == 'up' then
		xform.origin[2] = xform.origin[2] - (100 * xform.scale)
	elseif key == 'down' then
		xform.origin[2] = xform.origin[2] + (100 * xform.scale)
	end
end

function voronoimode.keyreleased( key )
end
