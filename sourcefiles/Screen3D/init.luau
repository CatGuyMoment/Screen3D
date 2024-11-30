--!strict
local GuiService = game:GetService("GuiService")

local Component3D = require(script.Component3D)
local Definitions = require(script.Definitions)

local screenGen : Definitions.screenGen = {} :: Definitions.screenGen
screenGen.__index = screenGen

function screenGen.new(screenGui: ScreenGui, displayDistance: number)
	local partIndex : {[GuiObject] : Definitions.component3D} = {}

	local self = setmetatable(
		{
			partIndex = partIndex,
			rootGui = screenGui,
			displayDistance = displayDistance,
			rootOffset = CFrame.new()
		},
		
		screenGen
	)

	for _,Component2D in screenGui:GetDescendants() do
		if Component2D:IsA("GuiObject") then
			partIndex[Component2D] = Component3D.new(Component2D,self)
		end
	end

	screenGui.DescendantAdded:Connect(function(AddedComponent: Instance)
		if AddedComponent:IsA("GuiObject") then
			partIndex[AddedComponent] = Component3D.new(AddedComponent,self)
		end

		for _,Component2D in AddedComponent:GetDescendants() do
			if Component2D:IsA("GuiObject") and not partIndex[Component2D] then
				partIndex[Component2D] = Component3D.new(Component2D,self)
			end
		end
	end)

	return self 
end

function screenGen:GetRealCanvasSize(): Vector2
	return workspace.CurrentCamera.ViewportSize
end

function screenGen:GetInset(): Vector2
	local inset = GuiService:GetGuiInset()
	return inset
end

function screenGen:GetInsetCanvasSize(): Vector2
	return self:GetRealCanvasSize() - self:GetInset()
end

function screenGen:GetIntendedCanvasSize(): Vector2
	if self.rootGui.IgnoreGuiInset then
		return self:GetRealCanvasSize()
	end
	
	return self:GetInsetCanvasSize()
end

function screenGen:GetComponent3D(Component2D)
	return self.partIndex[Component2D]
end

return screenGen
