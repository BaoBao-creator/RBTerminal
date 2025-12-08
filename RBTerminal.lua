local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local TerminalSystem = {}
local Lines = {}
local WaitingForInput = false
local InputSignal = Instance.new("BindableEvent")

local Screen = Instance.new("ScreenGui")
Screen.Name = "TerminalOverlay"
Screen.ResetOnSpawn = false
Screen.IgnoreGuiInset = true

pcall(function()
	Screen.Parent = CoreGui
end)
if not Screen.Parent then
	Screen.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "TerminalWindow"
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.new(1, 1, 1)
MainFrame.ClipsDescendants = true
MainFrame.Parent = Screen

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.new(0, 0, 0)
TopBar.BorderSizePixel = 0
TopBar.BorderColor3 = Color3.new(1, 1, 1)
TopBar.Parent = MainFrame

local BottomBorder = Instance.new("Frame")
BottomBorder.Size = UDim2.new(1, 0, 0, 1)
BottomBorder.Position = UDim2.new(0, 0, 1, 0)
BottomBorder.BackgroundColor3 = Color3.new(1, 1, 1)
BottomBorder.BorderSizePixel = 0
BottomBorder.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Text = " TERMINAL"
Title.Size = UDim2.new(0.5, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 14
Title.Font = Enum.Font.Code
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local ButtonContainer = Instance.new("Frame")
ButtonContainer.Size = UDim2.new(0, 100, 1, 0)
ButtonContainer.Position = UDim2.new(1, -100, 0, 0)
ButtonContainer.BackgroundTransparency = 1
ButtonContainer.Parent = TopBar

local function CreateButton(text, order)
	local Btn = Instance.new("TextButton")
	Btn.Text = text
	Btn.Size = UDim2.new(0, 30, 1, 0)
	Btn.Position = UDim2.new(1, -30 * order, 0, 0)
	Btn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	Btn.BackgroundTransparency = 1
	Btn.TextColor3 = Color3.new(1, 1, 1)
	Btn.TextSize = 14
	Btn.Font = Enum.Font.Code
	Btn.BorderSizePixel = 0
	Btn.Parent = ButtonContainer
	
	Btn.MouseEnter:Connect(function()
		TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
	end)
	Btn.MouseLeave:Connect(function()
		TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
	end)
	return Btn
end

local CloseBtn = CreateButton("X", 1) 
local MaximizeBtn = CreateButton("[]", 2)
local SettingsBtn = CreateButton("...", 3)
local MinimizeBtn = CreateButton("_", 4)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -10, 1, -65) 
ScrollFrame.Position = UDim2.new(0, 5, 0, 35)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.new(1, 1, 1)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.Parent = MainFrame

local InputBox = Instance.new("TextBox")
InputBox.Size = UDim2.new(1, -10, 0, 25)
InputBox.Position = UDim2.new(0, 5, 1, -30)
InputBox.BackgroundColor3 = Color3.new(0, 0, 0)
InputBox.TextColor3 = Color3.new(1, 1, 1)
InputBox.PlaceholderColor3 = Color3.new(0.5, 0.5, 0.5)
InputBox.PlaceholderText = "> Input command..."
InputBox.Text = ""
InputBox.Font = Enum.Font.Code
InputBox.TextSize = 14
InputBox.TextXAlignment = Enum.TextXAlignment.Left
InputBox.BorderSizePixel = 1
InputBox.BorderColor3 = Color3.new(0.3, 0.3, 0.3)
InputBox.Parent = MainFrame

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Size = UDim2.new(0, 15, 0, 15)
ResizeHandle.Position = UDim2.new(1, -15, 1, -15)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = "◢"
ResizeHandle.TextColor3 = Color3.new(1, 1, 1)
ResizeHandle.Parent = MainFrame

local IconFrame = Instance.new("TextButton")
IconFrame.Name = "TerminalIcon"
IconFrame.Size = UDim2.new(0, 50, 0, 50)
IconFrame.Position = UDim2.new(0, 50, 0.8, 0)
IconFrame.BackgroundColor3 = Color3.new(0, 0, 0)
IconFrame.TextColor3 = Color3.new(1, 1, 1)
IconFrame.Text = "#"
IconFrame.TextSize = 24
IconFrame.Font = Enum.Font.Code
IconFrame.BorderSizePixel = 1
IconFrame.BorderColor3 = Color3.new(1, 1, 1)
IconFrame.Visible = false
IconFrame.Parent = Screen

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = IconFrame

local Dragging, DragInput, DragStart, StartPos
local function UpdateDrag(input)
	local delta = input.Position - DragStart
	MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
end

TopBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		Dragging = true
		DragStart = input.Position
		StartPos = MainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				Dragging = false
			end
		end)
	end
end)

TopBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		DragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == DragInput and Dragging then
		UpdateDrag(input)
	end
end)

local IconDrag, IconStart, IconStartPos
IconFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		IconDrag = true
		IconStart = input.Position
		IconStartPos = IconFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				IconDrag = false
				
				local originalSize = MainFrame.Size
				local originalPos = MainFrame.Position
				
				MainFrame.Size = UDim2.new(0, 0, 0, 0)
				MainFrame.Position = UDim2.new(0, IconFrame.AbsolutePosition.X + 25, 0, IconFrame.AbsolutePosition.Y + 25)
				MainFrame.Visible = true
				
				local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				local openTween = TweenService:Create(MainFrame, tweenInfo, {
					Size = SavedSize or UDim2.new(0, 600, 0, 400),
					Position = SavedPos or UDim2.new(0.5, -300, 0.5, -200)
				})
				
				IconFrame.Visible = false
				openTween:Play()
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if IconDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - IconStart
		IconFrame.Position = UDim2.new(IconStartPos.X.Scale, IconStartPos.X.Offset + delta.X, IconStartPos.Y.Scale, IconStartPos.Y.Offset + delta.Y)
	end
end)

local Resizing, ResizeStart, StartSize
ResizeHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Resizing = true
		ResizeStart = input.Position
		StartSize = MainFrame.Size
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if Resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - ResizeStart
		MainFrame.Size = UDim2.new(StartSize.X.Scale, StartSize.X.Offset + delta.X, StartSize.Y.Scale, StartSize.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Resizing = false
	end
end)

local SavedSize, SavedPos
local IsMaximized = false

MaximizeBtn.MouseButton1Click:Connect(function()
	if IsMaximized then
		TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Size = SavedSize, Position = SavedPos}):Play()
		IsMaximized = false
		ResizeHandle.Visible = true
	else
		SavedSize = MainFrame.Size
		SavedPos = MainFrame.Position
		TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0)}):Play()
		IsMaximized = true
		ResizeHandle.Visible = false
	end
end)

MinimizeBtn.MouseButton1Click:Connect(function()
	SavedSize = MainFrame.Size
	SavedPos = MainFrame.Position
	
	local targetPos = UDim2.new(0, IconFrame.AbsolutePosition.X + 25, 0, IconFrame.AbsolutePosition.Y + 25)
	local tween = TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		Position = targetPos
	})
	tween:Play()
	tween.Completed:Wait()
	MainFrame.Visible = false
	IconFrame.Visible = true
end)

local SettingDrag, LastMouseX
SettingsBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		SettingDrag = true
		LastMouseX = input.Position.X
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if SettingDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position.X - LastMouseX
		LastMouseX = input.Position.X
		
		for _, line in pairs(Lines) do
			local newSize = math.clamp(line.TextSize + (delta * 0.1), 8, 30)
			line.TextSize = newSize
		end
		InputBox.TextSize = math.clamp(InputBox.TextSize + (delta * 0.1), 8, 30)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		SettingDrag = false
	end
end)

CloseBtn.MouseButton1Click:Connect(function()
	Screen:Destroy()
end)

function TerminalSystem.Print(text)
	text = tostring(text)
	for chunk in string.gmatch(text, "[^\n]+") do
		local label = Instance.new("TextLabel")
		label.Text = chunk
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.Code
		label.TextSize = InputBox.TextSize
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.Parent = ScrollFrame
		table.insert(Lines, label)
	end
	ScrollFrame.CanvasPosition = Vector2.new(0, ScrollFrame.AbsoluteCanvasSize.Y)
end

function TerminalSystem.Clear()
	for _, child in pairs(ScrollFrame:GetChildren()) do
		child:Destroy()
	end
	Lines = {}
end

function TerminalSystem.DeleteLine(lineIndex)
	if Lines[lineIndex] then
		Lines[lineIndex]:Destroy()
		table.remove(Lines, lineIndex)
	end
end

function TerminalSystem.ReplaceLine(lineIndex, newText)
	if Lines[lineIndex] then
		Lines[lineIndex].Text = newText
	end
end

function TerminalSystem.ReplaceChar(lineIndex, charIndex, newChar)
	if Lines[lineIndex] then
		local currentText = Lines[lineIndex].Text
		if charIndex <= #currentText then
			local prefix = string.sub(currentText, 1, charIndex - 1)
			local suffix = string.sub(currentText, charIndex + 1)
			Lines[lineIndex].Text = prefix .. newChar .. suffix
		end
	end
end

function TerminalSystem.ToggleInput(enabled)
	InputBox.TextEditable = enabled
	if not enabled then
		InputBox.PlaceholderText = "[INPUT DISABLED]"
	else
		InputBox.PlaceholderText = "> Input command..."
	end
end

function TerminalSystem.Input()
	WaitingForInput = true
	InputBox:CaptureFocus()
	local result = InputSignal.Event:Wait()
	WaitingForInput = false
	return result
end

InputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		local text = InputBox.Text
		if WaitingForInput then
			InputSignal:Fire(text)
			InputBox.Text = ""
		else
			TerminalSystem.Print("> " .. text)
			InputBox.Text = ""
			-- Handle command parsing logic here if needed
		end
	end
end)

return TerminalSystem
