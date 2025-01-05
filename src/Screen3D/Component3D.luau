--!strict
local RunService = game:GetService("RunService")

local Definitions = require(script.Parent.Definitions)

local componentGen : Definitions.componentGen = {} :: Definitions.componentGen
componentGen.__index = componentGen

local function pivot(original: CFrame, pivot: CFrame, angle: CFrame) 
	return original:Inverse() * pivot * angle * pivot:Inverse() * original
end


local function scaleOffFOV(original: CFrame)
	local rx,ry,rz = original:ToOrientation() --fuck gimbal lock

	local function crashout(fov: number)
		return 90 - fov/2
	end
	
	ry = ry *  crashout(workspace.CurrentCamera.FieldOfView) / crashout(70)
	rx = rx *  crashout(workspace.CurrentCamera.FieldOfView) / crashout(70)
	--rz = rz *  crashout(workspace.CurrentCamera.FieldOfView) / crashout(70)
	return CFrame.new(original.Position) * CFrame.Angles(rx,ry,rz)
end

function componentGen.new(Component2D, Screen3D)
	local self = setmetatable(
		{
			enabled = false,
			fovIndependant = false,
			
			component2D = Component2D,
			surfaceGui = nil,

			parent3D = nil,
			screen3D = Screen3D,

			offset = CFrame.new(),
			viewportSize = Screen3D:GetIntendedCanvasSize(),

			conn = nil
		},

		componentGen
	)

	self.viewportSize = self:GetViewportSize()

	if Component2D.Parent and Component2D.Parent:IsA("GuiObject") then
		self.parent2D = Component2D.Parent
	end

	return self
end

function componentGen:Enable()
	if self.enabled or not self.component2D then
		return self
	end	

	self.enabled = true

	local surfaceGui = Instance.new('SurfaceGui')
	local surfacePart = Instance.new('Part')

	surfacePart.CanCollide = false
	surfacePart.Anchored = true
	surfacePart.Parent = surfaceGui

	surfaceGui.Parent = self.parent2D or self.screen3D.rootGui
	surfaceGui.Face =  Enum.NormalId.Back
	surfaceGui.Adornee = surfacePart
	surfaceGui.AlwaysOnTop = true

	self.surfaceGui = surfaceGui

	self.component2D.Parent = self.surfaceGui

	--self:RecomputeParent()

	self.conn = RunService.RenderStepped:Connect(function(deltaTime: number)
		if self.conn and not (self.surfaceGui and surfacePart) then
			self.conn:Disconnect()
			return
		end

		local viewportSize = self:GetViewportSize()

		self.viewportSize = viewportSize

		surfaceGui.CanvasSize = viewportSize
		surfacePart.Size = self:GetStudsScreenSize(viewportSize)
		surfacePart.CFrame = self:ReadWorldCFrame()

	end)

	return self
end

function componentGen:Disable()
	if not self.enabled then
		return self
	end

	self.enabled = false

	if self.conn then
		self.conn:Disconnect()
	end

	if self.component2D then
		self.component2D.Parent = self.parent2D or self.screen3D.rootGui
	end

	if self.surfaceGui then
		self.surfaceGui:Destroy()
	end

	return self
end

function componentGen:GetViewportSize(): Vector2
	if self.parent3D and self.parent3D.component2D then
		return self.parent3D.component2D.AbsoluteSize
	end

	return self.screen3D:GetIntendedCanvasSize()
end

function componentGen:UDim2ToCFrame(position2D: UDim2): CFrame
	if not self.component2D then
		return CFrame.new()
	end

	local scaleX, scaleY = position2D.X.Scale, position2D.Y.Scale
	local offsetX, offsetY = position2D.X.Offset, position2D.Y.Offset

	local viewSize = self:GetViewportSize()

	local partSize = self:GetStudsScreenSize(viewSize)
	local trueScaleX, trueScaleY = scaleX +  offsetX/ viewSize.X , scaleY + offsetY / viewSize.Y



	local partSize = self:GetStudsScreenSize(viewSize)

	return CFrame.new(
		(partSize.X) * (trueScaleX - 0.5),
		-(partSize.Y) * (trueScaleY -0.5 ),
		0		
	)	
end

function componentGen:GetStudsScreenSize(viewportSize: Vector2): Vector3
	local trueSize =  self.screen3D:GetRealCanvasSize()

	local currentCamera = workspace.CurrentCamera
	local FOV = currentCamera.FieldOfView

	return Vector3.new(
		(trueSize.X / trueSize.Y) * math.tan(math.rad(FOV)/2) * (viewportSize.X / trueSize.X) ,
		math.tan(math.rad(FOV)/2)  * (viewportSize.Y / trueSize.Y),
		0	
	) * self.screen3D.displayDistance

end

function componentGen:RecomputeParent()
	if self.parent2D and self.parent2D:IsA("GuiObject") then
		self.parent3D = self.screen3D:GetComponent3D(self.parent2D)
	end

	if self.surfaceGui then
		local parent = self.parent3D
		local zIndex = 0

		while parent do
			zIndex += 1
			parent = parent.parent3D
		end

		self.surfaceGui.ZOffset = zIndex
	end

	return self
end

function componentGen:ReadWorldCFrame(): CFrame
	if not self.component2D then
		return CFrame.new()
	end

	self:RecomputeParent()

	local originalCFrame, udimPos, addedPosition

	local udimMax = self:UDim2ToCFrame(UDim2.fromScale(1,1))

	if self.parent3D then


		if not self.parent3D.component2D or not self.parent2D then
			return CFrame.new()
		end



		local anchorPoint = self.parent3D.component2D.AnchorPoint

		originalCFrame = self.parent3D:ReadWorldCFrame()
		udimPos = self.parent3D.component2D.Position 
		addedPosition = 
			self.parent3D:UDim2ToCFrame(udimPos) 
			* udimMax  
			* self:UDim2ToCFrame(UDim2.fromScale(-anchorPoint.X+0.5,-anchorPoint.Y+0.5))
			* CFrame.Angles(0,0, -math.rad(self.parent2D.Rotation) ) 
	else
		local viewportDiff = self.screen3D:GetRealCanvasSize() - self.screen3D:GetIntendedCanvasSize()

		originalCFrame = workspace.CurrentCamera.CFrame * CFrame.new(0,0,-(self.screen3D.displayDistance)/2 ) * self.screen3D.rootOffset

		udimPos = UDim2.new(0,viewportDiff.X/2,0,viewportDiff.Y/2)

		addedPosition = self:UDim2ToCFrame(udimPos) * self:UDim2ToCFrame(UDim2.fromScale(1,1)) 

	end


	local finalCFrame = originalCFrame  * addedPosition

	local finalPivot =  
		finalCFrame 
		* udimMax:Inverse() 
		* self:UDim2ToCFrame(self.component2D.Position) 
		* udimMax
	
	
	local offset = self.offset
	
	if self.fovIndependant then
		offset = scaleOffFOV(offset)
	end

	return finalCFrame * pivot(finalCFrame,finalPivot, offset )
end

return componentGen
