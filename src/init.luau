--!strict
-- Services
-- Packages

-- Modules
local GridUtil = require(script:WaitForChild("GridUtil")) -- I'll probably make this a package eventually, it just needs refinement and unit testing
local JPEG = require(script:WaitForChild("JPEG"))
local PNG = require(script:WaitForChild("PNG"))
local BMP = require(script:WaitForChild("BMP"))

-- Types
export type Grid2D<V> = GridUtil.Grid<V>
-- Constants
-- Variables
-- References
-- Private Functions

-- Class
local Util = {}

function Util.fromPGM(content: string, lineLength: number?): Grid2D<number>
	return GridUtil.fromPGM(content, lineLength)
end

function Util.fromPNG(content: string): Grid2D<Color3>
	local PNGImage = PNG.new(content)
	local width = PNGImage.Width
	local height = PNGImage.Height
	local imageData: Grid2D<Color3> = {}
	for x = 1, width do
		for y = 1, height do
			local color = PNGImage:GetPixel(x, y)
			if not imageData[x] then
				imageData[x] = {}
			end
			imageData[x][y] = color
		end
	end
	return imageData
end

function Util.fromJPEG(content: string): Grid2D<Color3>
	local JPEGImage = JPEG.CreateJPEGfromString(content)
	local width = JPEGImage.ImageWidth
	local height = JPEGImage.ImageHeight
	local imageData: Grid2D<Color3> = {}
	for x = 1, width do
		for y = 1, height do
			local color = JPEGImage.GetPixel(x, y)
			if not imageData[x] then
				imageData[x] = {}
			end
			imageData[x][y] = color
		end
	end
	return imageData
end

function Util.fromBMP(content: string): Grid2D<Color3>
	local BMPImage = BMP.Parse(content)
	local width = BMPImage.width
	local height = BMPImage.height
	local imageData = {}
	for x = 1, width do
		for y = 1, height do
			local color = BMPImage.Pixel(x, y)
			if not imageData[x] then
				imageData[x] = {}
			end
			imageData[x][y] = color
		end
	end
	return imageData
end

return Util
