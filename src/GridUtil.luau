--!strict
--!native
-- Services
-- Packages
local TableUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("TableUtil"))
-- Modules
-- Types
export type Grid<V> = { [number]: { [number]: V } }
-- Constants
-- Variables
-- References
-- Private Functions

-- Class
local Util = {}

function Util.freeze<V>(grid: Grid<V>)
	for y = 1, #grid do
		table.freeze(grid[y])
	end
	table.freeze(grid)
end

function Util.resize<V>(grid: Grid<V>, size: Vector3, processor: (v: V, xAlpha: number, nextX: V?, yAlpha: number, nextY: V?) -> V): Grid<V>
	local out: Grid<V> = {}

	assert(size.X > 1 and size.Y > 1, `bad resize dimensions: {size}`)
	local iSize = Util.getSize(grid)
	assert(iSize.X > 1 and iSize.Y > 1, `bad dimensions: {iSize}`)

	for yO = 1, size.Y do
		local yA = (yO - 1) / (size.Y - 1)
		local yRaw = 1 + yA * (iSize.Y - 1)
		local yMin = math.floor(yRaw)
		local yMax = yMin + 1

		out[yO] = {}

		for xO = 1, size.X do
			local xA = (xO - 1) / (size.X - 1)
			local xRaw = 1 + xA * (iSize.X - 1)
			local xMin = math.floor(xRaw)
			local xMax = xMin + 1

			assert(grid[yMin] ~= nil, `bad yMin {yMin} for size {iSize}`)

			if yO == 1 and xO == 1 then
				out[yO][xO] = grid[yMin][xMin]
			else
				out[yO][xO] = processor(grid[yMin][xMin], xA, grid[yMin][xMax], yA, if grid[yMax] then grid[yMax][xMin] else nil)
			end
		end
	end

	local fSize = Util.getSize(out)

	assert(fSize.X == size.X and fSize.Y == size.Y, `resize failed: i[{size.X},{size.Y}] != o[{fSize.X},{size.Y}]`)

	return out
end

function Util.flatten<V>(grid: Grid<V>): { [number]: V }
	local size = Util.getSize(grid)
	local list: { [number]: V } = table.create(size.X * size.Y)
	for y = 1, size.Y do
		for x = 1, size.X do
			table.insert(list, grid[y][x])
		end
	end
	return list
end

function Util.fromPGM(content: string, lineLength: number?): Grid<number>
	local lines = content:split("\n")

	local fileType = lines[1]:match("P%d")
	assert(fileType, `bad file type: {lines[1]}`)

	local fileNumberString = fileType:match("%d")
	assert(fileNumberString, `bad file number: {fileType}, {lines[1]}`)

	local fileNumber = tonumber(fileNumberString)
	assert(fileNumber, `bad file number: {fileNumberString}`)

	local width = tonumber(lines[3]:split(" ")[1])
	assert(width, `bad width: {lines[3]}`)

	local height = tonumber(lines[3]:split(" ")[1])
	assert(height, `bad height: {lines[3]}`)

	local maxGrayValue = tonumber(lines[4])
	assert(maxGrayValue)

	local out: Grid<number> = table.create(0)

	lineLength = lineLength or 13
	assert(lineLength)

	if fileNumber == 2 then
		local pixelData = table.create(0)
		local count = 0
		for i = 5, #lines do
			local line = lines[i]:gsub("%s", ",")
			local vs = line:split(",")
			count += #vs
			for j = 1, lineLength do
				local v = vs[j]
				local val = if v and v:len() > 0 then tonumber(v) else 0
				assert(val ~= nil, `bad v "{v}" in line "{line}"`)
				table.insert(pixelData, val / maxGrayValue)
			end
			-- for j, v in ipairs(vs) do

			-- end
		end
		-- print(`len: {#pixelData}, {count}, {#lines}`)

		-- Convert to 2D array
		for y = 1, height do
			local row: { [number]: number } = table.create(0)
			for x = 1, width do
				local value = pixelData[(y - 1) * width + x]
				assert(value, `bad value at y={y}, x={x}`)
				table.insert(row, value)
			end
			table.insert(out, row)
		end

		-- print(Util.getSize(out), #out[#out])

		return out
	else
		error(`pgm type {fileType} not yet supported`)
	end
end

function Util.fromCSV(content: string, includesHeader: boolean): Grid<number>
	local out: Grid<number> = table.create(0)
	local lines = content:split("\n")
	for i = if includesHeader then 2 else 1, #lines do
		-- local y = if includesHeader then i-1 else i
		local line = lines[i]
		table.insert(out, {})

		for x, valueString in ipairs(line:split(",")) do
			if valueString:len() > 0 then
				local val: number? = tonumber(valueString)
				assert(val, `bad value (len={valueString:len()}): {valueString}`)

				table.insert(out[#out], val)
			end
		end

		if #out > 1 then
			assert(#lines[1] == #lines[#lines], `change in row length: {#lines[1]} != {#lines[#lines]}`)
		end
	end
	return out
end

function Util.fromImage(image: EditableImage, rect: Rect?): (Grid<Color3>, Grid<number>)
	local colors: Grid<Color3> = { {} }
	local alphas: Grid<number> = { {} }

	rect = rect or Rect.new(0, 0, image.Size.X, image.Size.Y)
	assert(rect)

	local start = rect.Min
	-- Vector3.new(
	-- 	math.clamp(rect.Min.X, 0, image.Size.X),
	-- 	math.clamp(rect.Min.Y, 0, image.Size.Y)
	-- )

	local finish = rect.Max
	--  Vector3.new(
	-- 	math.clamp(rect.Max.X+1, 0, image.Size.X),
	-- 	math.clamp(rect.Max.Y+1, 0, image.Size.Y)
	-- )

	local size = Vector3.new((finish.X - start.X), (finish.Y - start.Y))

	local pixels = image:ReadPixels(start, finish - start)

	do
		local x = 0
		local y = 1

		for i = 0, math.ceil(#pixels / 4) - 1 do
			if x >= size.X then
				table.insert(colors, {})
				table.insert(alphas, {})

				y += 1
				x = 0
			end
			x += 1

			table.insert(colors[#colors], Color3.new(pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3]))
			table.insert(alphas[#alphas], pixels[i * 4 + 4])
		end
	end

	if #colors[#colors] == 0 then
		table.remove(colors, #colors)
	end

	if #alphas[#alphas] == 0 then
		table.remove(alphas, #alphas)
	end

	do
		local cSize = Util.getSize(colors)
		local aSize = Util.getSize(alphas)
		-- local size = Vector3.new(rect.Width, rect.Height)
		assert(cSize.X == size.X and cSize.Y == size.Y, `color size mismatch: c={cSize}, i={size}`)
		assert(aSize.X == size.X and aSize.Y == size.Y, `alpha size mismatch: a={aSize}, i={size}`)
	end

	return colors, alphas
end

function Util.transpose<V>(grid: Grid<V>): Grid<V>
	local out = table.create(0)
	-- print(grid[1])
	for y, row in ipairs(grid) do
		for x, v in ipairs(row) do
			if y == 1 then
				out[x] = table.create(0)
			end
			out[x][y] = v
		end
	end
	-- assert(#out > 1)
	return out
end

function Util.clear(grid: Grid<unknown>)
	for y, row in ipairs(grid) do
		table.clear(row)
	end
	table.clear(grid)
end

function Util.flipHorizontal<V>(grid: Grid<V>): Grid<V>
	local out: Grid<V> = table.create(0)
	for y, row in ipairs(grid) do
		out[y] = table.clone(row)
		TableUtil.reverse(out[y])
	end
	return out
end

function Util.flipVertical<V>(grid: Grid<V>): Grid<V>
	local out: Grid<V> = table.create(0)
	for y, row in ipairs(grid) do
		out[y] = table.clone(row)
	end
	TableUtil.reverse(out)

	return out
end

function Util.map<I, O>(grid: Grid<I>, transform: (input: I) -> O): Grid<O>
	local out: Grid<O> = table.create(0)

	local size = Util.getSize(grid)
	for y = 1, size.Y do
		table.insert(out, {})
		for x = 1, size.X do
			table.insert(out[#out], transform(grid[y][x]))
		end
	end

	return out
end

function Util.getSize(grid: Grid<unknown>): Vector3
	assert(grid[1], `bad grid, x=0, y={#grid}`)
	return Vector3.new(#grid[1], #grid)
end

function Util.getArea(grid: Grid<unknown>): number
	local size = Util.getSize(grid)
	return size.X * size.Y
end

function Util.fit(grid: Grid<unknown>, area: Rect): Rect
	local size = Util.getSize(grid)

	return Rect.new(math.clamp(area.Min.X, 1, size.X), math.clamp(area.Min.Y, 1, size.Y), math.clamp(area.Max.X, 1, size.X), math.clamp(area.Max.Y, 1, size.Y))
end

function Util.crop<V>(grid: Grid<V>, area: Rect): Grid<V>
	local size = Util.getSize(grid)
	if size.Magnitude == 0 then
		error("empty coordinate array")
	end

	assert(area.Min.Y >= 1 and area.Max.Y <= size.Y, `y range of area goes outside of array: {area.Min.Y}, {area.Max.Y} vs {size.Y}`)
	assert(area.Min.X >= 1 and area.Max.X <= size.X, `x range of area goes outside of array: {area.Min.X}, {area.Max.X} vs {size.X}`)
	local out = table.create(area.Max.Y - area.Min.Y + 1)
	for y = area.Min.Y, area.Max.Y - 1 do
		local yIndex = y - area.Min.Y + 1
		out[yIndex] = table.create(area.Max.X - area.Min.X + 1)
		for x = area.Min.X, area.Max.X - 1 do
			out[yIndex][x - area.Min.X + 1] = grid[y][x]
		end
	end

	do
		local outSize = Util.getSize(out)
		local goalSize = Vector3.new(area.Width, area.Height)
		assert(outSize.X == goalSize.X and outSize.Y == goalSize.Y, `area mismatch: o={outSize}, a={goalSize}`)
	end

	return out
end

function Util.sample<V>(grid: Grid<V>, sampleRate: Vector3): Grid<V>
	local size = Util.getSize(grid)

	local sampleCount = Vector3.new(math.round(size.X / sampleRate.X), math.round(size.Y / sampleRate.Y))

	local out = table.create(sampleCount.Y)

	local yWidth = size.Y / sampleCount.Y
	local xWidth = size.X / sampleCount.X

	for y = 1, sampleCount.Y do
		out[y] = table.create(sampleCount.X)
		local yIndex: number
		if y == 1 then
			yIndex = 1
		elseif y == sampleCount.Y then
			yIndex = size.Y
		else
			yIndex = math.round((y - 1) * yWidth)
		end
		for x = 1, sampleCount.X do
			local xIndex: number
			if x == 1 then
				xIndex = 1
			elseif x == sampleCount.X then
				xIndex = size.X
			else
				xIndex = math.round((x - 1) * xWidth)
			end

			out[y][x] = grid[yIndex][xIndex]
		end
	end
	return out
end

return Util
