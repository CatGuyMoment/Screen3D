--!strict
local RunService = game:GetService("RunService")

local Definitions = require(script.Parent.Definitions)

local componentGen : Definitions.componentGen = {} :: Definitions.componentGen
componentGen.__index = componentGen

local function pivot(original: CFrame, pivot: CFrame, angle: CFrame) 
	return original:Inverse() * pivot * angle * pivot:Inverse() * original
end

function componentGen.new(Component2D, Screen3D)
	local self = setmetatable(
		{
			enabled = false,
			_compatibility = false,
			
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

function componentGen:EnableCompatibility()
	self._compatibility = true
	
	local Container0 , Container1 = Instance.new('Frame'), Instance.new('Frame')
	
	Container0.Name = '3DCONTAINER'
	Container1.Name = '3DCONTAINER'
	
	Container0.Parent = self.parent2D or self.screen3D.rootGui
	Container1.Parent = Container0
	
	Container0.BackgroundTransparency = 1
	Container1.BackgroundTransparency = 1
	
	local Container3D_0, Container3D_1 = componentGen.new(Container0,self.screen3D), componentGen.new(Container1,self.screen3D)
	
	self.screen3D.partIndex[Container0], self.screen3D.partIndex[Container1] = Container3D_0, Container3D_1
	
	self.compatibilityParent3D = self.parent3D
	self.compatibilityParent2D = self.parent2D
	
	self.parent2D = Container1
	self.parent3D = Container3D_1
	
	return self:Enable()
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
	
	self.conn = game:GetService('HttpService'):GenerateGUID(false)
	RunService:BindToRenderStep(self.conn,Enum.RenderPriority.Last.Value + 1,function(deltaTime: number)
		
		if self.conn and not (self.surfaceGui and surfacePart) then
			RunService:UnbindFromRenderStep(self.conn)
			return
		end
		
		

		local viewportSize = self:GetViewportSize()
		
		if self._compatibility and self.parent2D and self.parent3D and self.parent3D.parent2D then
			local c_parent = self.compatibilityParent2D or self.screen3D 
			self.parent2D.Size = UDim2.fromOffset(c_parent.AbsoluteSize.X,c_parent.AbsoluteSize.Y)
			self.parent3D.parent2D.Size = UDim2.fromOffset(self.component2D.AbsoluteSize.X,self.component2D.AbsoluteSize.Y)
		end
		
		
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
		RunService:UnbindFromRenderStep(self.conn)
	end
	
	if self.component2D then
		
		if self._compatibility then
			
			self.component2D.Parent = self.compatibilityParent2D or self.screen3D.rootGui
			
		else
			
			self.component2D.Parent = self.parent2D or self.screen3D.rootGui
			
		end
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

function componentGen:GetCompatibilityPosition()
	if not self.enabled and self.component2D and self.parent3D and self.parent3D.component2D and not self.parent3D.enabled then-- everyone is say "hey yqat, add modifiers", well i made modifiers, here is my modifiers

		local offset = (self.component2D.AbsolutePosition - self.parent3D.component2D.AbsolutePosition) + (self.component2D.AnchorPoint * self.component2D.AbsoluteSize)
		return UDim2.fromOffset(offset.X, offset.Y)
	end
	return UDim2.new(0,0,0,0)
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
		
		if not self.parent3D.enabled and self.parent3D.parent3D and self.parent3D.parent3D.component2D and not self.parent3D.parent3D.enabled then 
 
			udimPos  = self.parent3D:GetCompatibilityPosition()
		end
		
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
	
	local componentPosition = self.component2D.Position
	
	
	if not self.enabled and self.parent3D and self.parent3D.component2D and not self.parent3D.enabled then --whoever thinks that hell should be empty has never seen THIS...
		
		componentPosition = self:GetCompatibilityPosition()
	end
	
	local finalPivot =  
		finalCFrame 
		* udimMax:Inverse() 
		* self:UDim2ToCFrame(componentPosition) 
		* udimMax



	return finalCFrame * pivot(finalCFrame,finalPivot,self.offset) 
end

return componentGen
