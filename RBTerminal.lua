local Terminal = {}
Terminal.__index = Terminal

-- Services
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- Configuration
local DEFAULT_FONT_SIZE = 14
local DEFAULT_BG_COLOR = Color3.fromRGB(0, 0, 0)
local DEFAULT_BG_TRANSPARENCY = 0.5
local TITLEBAR_COLOR = Color3.fromRGB(50, 50, 50)
local TITLEBAR_HEIGHT = 30
local CONTROL_BTN_SIZE = UDim2.new(0, 30, 1, 0)
local SETTINGS_BTN_SIZE = UDim2.new(0, 30, 1, 0)
local ICON_SIZE = UDim2.new(0, 50, 0, 50)
local MIN_WIDTH = 100
local MIN_HEIGHT = 50
local ZINDEX_BASE = 10000
Terminal._globalZIndex = ZINDEX_BASE

-- Create a new Terminal instance
function Terminal:New()
    local self = setmetatable({}, Terminal)
    self.Buffer = {}
    self.UI_Map = {}
    self.MaxLines = 500
    self.IsInputBlocked = false
    self.CurrentFontSize = DEFAULT_FONT_SIZE

    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TerminalScreenGui"
    screenGui.Parent = CoreGui
    screenGui.DisplayOrder = Terminal._globalZIndex
    Terminal._globalZIndex = Terminal._globalZIndex + 1
    self.ScreenGui = screenGui

    -- Main Frame (window)
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Name = "TerminalWindow"
    mainFrame.BackgroundColor3 = DEFAULT_BG_COLOR
    mainFrame.BackgroundTransparency = DEFAULT_BG_TRANSPARENCY
    mainFrame.BorderSizePixel = 1
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -150)
    mainFrame.Size = UDim2.new(0, 500, 0, 300)
    mainFrame.AnchorPoint = Vector2.new(0, 0)
    mainFrame.Active = true
    mainFrame.Draggable = false
    mainFrame.ZIndex = screenGui.DisplayOrder
    self.Frame = mainFrame
    self._savedPosition = mainFrame.Position
    self._savedSize = mainFrame.Size

    -- Fix initial absolute position (to avoid using scale afterward)
    RunService.Heartbeat:Wait()
    local absPos = mainFrame.AbsolutePosition
    mainFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y)

    -- TitleBar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Name = "TitleBar"
    titleBar.BackgroundColor3 = TITLEBAR_COLOR
    titleBar.BorderSizePixel = 0
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.Size = UDim2.new(1, 0, 0, TITLEBAR_HEIGHT)
    titleBar.ZIndex = mainFrame.ZIndex + 1
    self.TitleBar = titleBar

    -- Control Buttons (minimize, maximize, close)
    local controlGroup = Instance.new("Frame", titleBar)
    controlGroup.Name = "ControlGroup"
    controlGroup.Size = UDim2.new(0, 90, 1, 0)
    controlGroup.AnchorPoint = Vector2.new(1, 0)
    controlGroup.Position = UDim2.new(1, 0, 0, 0)
    controlGroup.BackgroundTransparency = 1

    -- Minimize button
    local btnMin = Instance.new("TextButton", controlGroup)
    btnMin.Name = "MinimizeButton"
    btnMin.Size = CONTROL_BTN_SIZE
    btnMin.Position = UDim2.new(1, -90, 0, 0)
    btnMin.Text = "-"
    btnMin.BackgroundColor3 = Color3.fromRGB(200, 200, 0)
    btnMin.TextColor3 = Color3.new(1,1,1)
    btnMin.BorderSizePixel = 0
    self.MinButton = btnMin

    -- Maximize button
    local btnMax = Instance.new("TextButton", controlGroup)
    btnMax.Name = "MaximizeButton"
    btnMax.Size = CONTROL_BTN_SIZE
    btnMax.Position = UDim2.new(1, -60, 0, 0)
    btnMax.Text = "◻"
    btnMax.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    btnMax.TextColor3 = Color3.new(1,1,1)
    btnMax.BorderSizePixel = 0
    self.MaxButton = btnMax

    -- Close button
    local btnClose = Instance.new("TextButton", controlGroup)
    btnClose.Name = "CloseButton"
    btnClose.Size = CONTROL_BTN_SIZE
    btnClose.Position = UDim2.new(1, -30, 0, 0)
    btnClose.Text = "X"
    btnClose.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    btnClose.TextColor3 = Color3.new(1,1,1)
    btnClose.BorderSizePixel = 0
    self.CloseButton = btnClose

    -- Settings button "..."
    local settingsBtn = Instance.new("TextButton", titleBar)
    settingsBtn.Name = "SettingsButton"
    settingsBtn.Size = SETTINGS_BTN_SIZE
    settingsBtn.AnchorPoint = Vector2.new(1, 0)
    settingsBtn.Position = UDim2.new(1, -120, 0, 0)
    settingsBtn.Text = "..."
    settingsBtn.BackgroundColor3 = TITLEBAR_COLOR
    settingsBtn.TextColor3 = Color3.new(1,1,1)
    settingsBtn.BorderSizePixel = 0
    self.SettingsButton = settingsBtn

    -- Slider Container (hidden by default)
    local sliderContainer = Instance.new("Frame", mainFrame)
    sliderContainer.Name = "SliderContainer"
    sliderContainer.Size = UDim2.new(0, 100, 0, 10)
    sliderContainer.Position = UDim2.new(1, -110, 0, TITLEBAR_HEIGHT + 5)
    sliderContainer.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    sliderContainer.Visible = false
    sliderContainer.ZIndex = titleBar.ZIndex
    self.SliderContainer = sliderContainer

    -- Slider track & knob
    local sliderTrack = Instance.new("Frame", sliderContainer)
    sliderTrack.Name = "Track"
    sliderTrack.Size = UDim2.new(1, -10, 0, 4)
    sliderTrack.Position = UDim2.new(0, 5, 0, 3)
    sliderTrack.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    sliderTrack.BorderSizePixel = 0

    local knob = Instance.new("Frame", sliderContainer)
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = UDim2.new(0, 0, 0, 0)
    knob.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    knob.BorderSizePixel = 0
    knob.ZIndex = sliderContainer.ZIndex + 1
    self.SliderKnob = knob

    -- Content area (scroll + input)
    local contentArea = Instance.new("Frame", mainFrame)
    contentArea.Name = "ContentArea"
    contentArea.BackgroundTransparency = 1
    contentArea.Position = UDim2.new(0, 0, 0, TITLEBAR_HEIGHT)
    contentArea.Size = UDim2.new(1, 0, 1, -TITLEBAR_HEIGHT - 20)
    self.ContentArea = contentArea

    -- Scrolling frame for text buffer
    local scrollFrame = Instance.new("ScrollingFrame", contentArea)
    scrollFrame.Name = "ScrollContainer"
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.Position = UDim2.new(0, 0, 0, 0)
    scrollFrame.Size = UDim2.new(1, 0, 1, -20)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
    scrollFrame.ZIndex = contentArea.ZIndex + 1
    self.ScrollingFrame = scrollFrame

    local uiList = Instance.new("UIListLayout", scrollFrame)
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Padding = UDim.new(0, 2)
    self.UIListLayout = uiList

    -- Input line
    local inputBox = Instance.new("TextBox", contentArea)
    inputBox.Name = "InputLine"
    inputBox.AnchorPoint = Vector2.new(0, 1)
    inputBox.Position = UDim2.new(0, 0, 1, 0)
    inputBox.Size = UDim2.new(1, 0, 0, 20)
    inputBox.BackgroundColor3 = DEFAULT_BG_COLOR
    inputBox.BackgroundTransparency = 0.5
    inputBox.TextColor3 = Color3.new(1,1,1)
    inputBox.Text = ""
    inputBox.PlaceholderText = ""
    inputBox.ClearTextOnFocus = false
    inputBox.TextSize = self.CurrentFontSize
    inputBox.Font = Enum.Font.SourceSans
    inputBox.TextWrapped = false
    inputBox.ZIndex = scrollFrame.ZIndex + 1
    self.InputLine = inputBox

    -- Minimized icon
    local iconBtn = Instance.new("ImageButton", screenGui)
    iconBtn.Name = "MinimizedIcon"
    iconBtn.Size = ICON_SIZE
    iconBtn.Position = UDim2.new(0, 10, 0, 10)
    iconBtn.BackgroundColor3 = TITLEBAR_COLOR
    iconBtn.BackgroundTransparency = 0.5
    iconBtn.BorderSizePixel = 0
    iconBtn.Visible = false
    iconBtn.ZIndex = mainFrame.ZIndex
    self.MinimizedIcon = iconBtn

    local iconLabel = Instance.new("TextLabel", iconBtn)
    iconLabel.Name = "IconLabel"
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "#"
    iconLabel.TextColor3 = Color3.new(1,1,1)
    iconLabel.Font = Enum.Font.SourceSans
    iconLabel.TextSize = 24
    iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    iconLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    iconLabel.Size = UDim2.new(1, 0, 1, 0)

    -- Store references
    self.ResizeHandles = {}
    -- Define resize handles
    local function makeHandle(name, anchor, position, size)
        local f = Instance.new("Frame", mainFrame)
        f.Name = name
        f.Size = size
        f.AnchorPoint = anchor
        f.Position = position
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        return f
    end
    -- Actually create folder for handles
    local handleFolder = Instance.new("Folder", mainFrame)
    handleFolder.Name = "ResizeHandles"
    self.HandleFolder = handleFolder
    -- Corners
    local hTL = makeHandle("TL", Vector2.new(0,0), UDim2.new(0, 0, 0, 0), UDim2.new(0,10,0,10))
    local hTR = makeHandle("TR", Vector2.new(1,0), UDim2.new(1, 0, 0, 0), UDim2.new(0,10,0,10))
    local hBL = makeHandle("BL", Vector2.new(0,1), UDim2.new(0, 0, 1, 0), UDim2.new(0,10,0,10))
    local hBR = makeHandle("BR", Vector2.new(1,1), UDim2.new(1, 0, 1, 0), UDim2.new(0,10,0,10))
    -- Edges
    local hT = makeHandle("T", Vector2.new(0.5,0), UDim2.new(0.5, 0, 0, 0), UDim2.new(1, -20, 0,10))
    local hB = makeHandle("B", Vector2.new(0.5,1), UDim2.new(0.5, 0, 1, 0), UDim2.new(1, -20, 0,10))
    local hL = makeHandle("L", Vector2.new(0,0.5), UDim2.new(0, 0, 0.5, 0), UDim2.new(0,10,1, -20))
    local hR = makeHandle("R", Vector2.new(1,0.5), UDim2.new(1, 0, 0.5, 0), UDim2.new(0,10,1, -20))
    self.ResizeHandles = {TL=hTL, TR=hTR, BL=hBL, BR=hBR, T=hT, B=hB, L=hL, R=hR}

    -- State variables for dragging/resizing
    self._isDragging = false
    self._dragStartMouse = Vector2.new()
    self._startPos = Vector2.new()
    self._startSize = Vector2.new()
    self._resizeDir = nil
    self._isMaximized = false
    self._isMinimized = false
    self.waiting = {}

    -- Input focus
    inputBox.Focused:Connect(function()
        self.IsInputBlocked = false
    end)

    -- Input handling (Enter key)
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and not self.IsInputBlocked then
            local text = inputBox.Text
            if text ~= "" then
                self:print("> " .. text)
            end
            -- resume waiting coroutine if any
            if #self.waiting > 0 then
                local thread = table.remove(self.waiting, 1)
                coroutine.resume(thread, text)
            end
            inputBox.Text = ""
        end
    end)

    -- Toggle slider visibility
    settingsBtn.MouseButton1Click:Connect(function()
        sliderContainer.Visible = not sliderContainer.Visible
    end)

    -- Slider knob dragging
    local sliderDragging = false
    local knobStartX = 0
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = true
            knobStartX = input.Position.X - knob.AbsolutePosition.X
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local posX = input.Position.X - knobStartX
            local minX = sliderContainer.AbsolutePosition.X
            local maxX = sliderContainer.AbsolutePosition.X + sliderContainer.AbsoluteSize.X - knob.AbsoluteSize.X
            posX = math.clamp(posX, minX, maxX)
            knob.Position = UDim2.new(0, posX - sliderContainer.AbsolutePosition.X, 0, 0)
            -- adjust font size based on knob position
            local fraction = (posX - minX) / (sliderContainer.AbsoluteSize.X - knob.AbsoluteSize.X)
            local minSize, maxSize = 10, 30
            local newSize = math.floor(minSize + (maxSize - minSize) * fraction + 0.5)
            self.CurrentFontSize = newSize
            -- update all existing labels
            for _, lbl in ipairs(self.UI_Map) do
                lbl.TextSize = newSize
            end
            inputBox.TextSize = newSize
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = false
        end
    end)

    -- Bring window to front on click
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            mainFrame.ZIndex = Terminal._globalZIndex
            Terminal._globalZIndex = Terminal._globalZIndex + 1
        end
    end)

    -- Drag window
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._isDragging = true
            self._dragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
            self._startPos = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if self._isDragging and input.UserInputType == Enum.UserInputType.MouseMovement and not self._isMaximized and not self._isMinimized then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - self._dragStartMouse
            local newX = self._startPos.X + delta.X
            local newY = self._startPos.Y + delta.Y
            mainFrame.Position = UDim2.new(0, newX, 0, newY)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._isDragging = false
            self._resizeDir = nil
        end
    end)

    -- Resize window
    for name, handle in pairs(self.ResizeHandles) do
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self._resizeDir = name
                self._dragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
                self._startPos = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
                self._startSize = Vector2.new(mainFrame.Size.X.Offset, mainFrame.Size.Y.Offset)
            end
        end)
    end
    UserInputService.InputChanged:Connect(function(input)
        if self._resizeDir and input.UserInputType == Enum.UserInputType.MouseMovement and not self._isMaximized and not self._isMinimized then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - self._dragStartMouse
            local newPos = self._startPos
            local newSize = self._startSize
            local dir = self._resizeDir
            local minW, minH = MIN_WIDTH, MIN_HEIGHT
            if dir == "L" or dir == "TL" or dir == "BL" then
                local newWidth = self._startSize.X - delta.X
                if newWidth < minW then
                    newPos = Vector2.new(self._startPos.X + (self._startSize.X - minW), newPos.Y)
                    newWidth = minW
                else
                    newPos = Vector2.new(self._startPos.X + delta.X, newPos.Y)
                end
                newSize = Vector2.new(newWidth, newSize.Y)
            end
            if dir == "R" or dir == "TR" or dir == "BR" then
                local newWidth = self._startSize.X + delta.X
                if newWidth < minW then
                    newWidth = minW
                end
                newSize = Vector2.new(newWidth, newSize.Y)
            end
            if dir == "T" or dir == "TL" or dir == "TR" then
                local newHeight = self._startSize.Y - delta.Y
                if newHeight < minH then
                    newPos = Vector2.new(newPos.X, self._startPos.Y + (self._startSize.Y - minH))
                    newHeight = minH
                else
                    newPos = Vector2.new(newPos.X, self._startPos.Y + delta.Y)
                end
                newSize = Vector2.new(newSize.X, newHeight)
            end
            if dir == "B" or dir == "BL" or dir == "BR" then
                local newHeight = self._startSize.Y + delta.Y
                if newHeight < minH then
                    newHeight = minH
                end
                newSize = Vector2.new(newSize.X, newHeight)
            end
            mainFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
            mainFrame.Size = UDim2.new(0, newSize.X, 0, newSize.Y)
        end
    end)

    -- Close, Minimize, Maximize events
    btnClose.MouseButton1Click:Connect(function()
        self:Close()
    end)
    btnMin.MouseButton1Click:Connect(function()
        self:Minimize()
    end)
    btnMax.MouseButton1Click:Connect(function()
        self:Maximize()
    end)
    iconBtn.MouseButton1Click:Connect(function()
        self:Restore()
    end)

    return self
end

-- Print a line of text (supports RichText color formatting)
function Terminal:print(text)
    if not self.Frame or not self.Frame.Parent then return end
    table.insert(self.Buffer, text)
    local index = #self.Buffer
    -- Create label
    local label = Instance.new("TextLabel", self.ScrollingFrame)
    label.BackgroundTransparency = 1
    label.Text = text
    label.RichText = true
    label.TextColor3 = Color3.new(1,1,1)
    label.TextSize = self.CurrentFontSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.SourceSans
    label.TextWrapped = false
    label.LayoutOrder = index
    self.UI_Map[index] = label
    -- Scroll to bottom
    self.ScrollingFrame.CanvasPosition = Vector2.new(0, math.huge)
    -- Trim buffer if needed
    if #self.Buffer > self.MaxLines then
        local diff = #self.Buffer - self.MaxLines
        for i = 1, diff do
            if self.UI_Map[1] then
                self.UI_Map[1]:Destroy()
            end
            table.remove(self.UI_Map, 1)
            table.remove(self.Buffer, 1)
        end
        for i, lbl in ipairs(self.UI_Map) do
            lbl.LayoutOrder = i
        end
    end
end

-- Clear all text
function Terminal:clear()
    for _, lbl in ipairs(self.UI_Map) do
        if lbl then lbl:Destroy() end
    end
    self.Buffer = {}
    self.UI_Map = {}
    self.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
end

-- Replace entire line text by index
function Terminal:replace_line(lineIndex, newText)
    if self.Buffer[lineIndex] then
        self.Buffer[lineIndex] = newText
        if self.UI_Map[lineIndex] then
            self.UI_Map[lineIndex].Text = newText
        end
    end
end

-- Replace one character in a line
function Terminal:replace_char(lineIndex, charIndex, newChar)
    local line = self.Buffer[lineIndex]
    if line and charIndex >= 1 and charIndex <= #line then
        local updated = line:sub(1, charIndex-1) .. newChar .. line:sub(charIndex+1)
        self.Buffer[lineIndex] = updated
        if self.UI_Map[lineIndex] then
            self.UI_Map[lineIndex].Text = updated
        end
    end
end

-- Enable or disable user input (toggle TextBox)
function Terminal:toggle_input(enabled)
    self.IsInputBlocked = not enabled
    if enabled then
        self.InputLine.TextEditable = true
        self.InputLine.ClearTextOnFocus = true
        self.InputLine.TextColor3 = Color3.new(1,1,1)
    else
        self.InputLine.TextEditable = false
        self.InputLine.ClearTextOnFocus = false
        self.InputLine.TextColor3 = Color3.fromRGB(150,150,150)
    end
end

-- Synchronous input: prints prompt and yields until Enter pressed
function Terminal:input(prompt)
    self:print(prompt)
    self:toggle_input(true)
    local thread = coroutine.running()
    table.insert(self.waiting, thread)
    return coroutine.yield()
end

-- Execute code via loadstring (executor environment)
function Terminal:run(code)
    local loadf = loadstring or (getgenv and getgenv().loadstring)
    if loadf then
        local func, err = loadf(code)
        if func then
            local success, runtimeError = pcall(function()
                func()
            end)
            if not success then
                self:print("Error: " .. tostring(runtimeError))
            end
        else
            self:print("Syntax error: " .. tostring(err))
        end
    else
        self:print("Error: environment doesn't support loadstring!")
    end
end

-- Minimize window to icon
function Terminal:Minimize()
    if self._isMinimized then return end
    self._savedPosition = self.Frame.Position
    self._savedSize = self.Frame.Size
    self.Frame.Visible = false
    self.MinimizedIcon.Visible = true
    self.MinimizedIcon.Position = UDim2.new(0, self._savedPosition.X.Offset, 0, self._savedPosition.Y.Offset)
    self.MinimizedIcon.Size = ICON_SIZE
    self._isMinimized = true
end

-- Restore from minimized or maximized
function Terminal:Restore()
    if self._isMinimized then
        self.Frame.Visible = true
        self.Frame.Position = self._savedPosition
        self.Frame.Size = self._savedSize
        self.MinimizedIcon.Visible = false
        self._isMinimized = false
    elseif self._isMaximized then
        self:Maximize()
    end
end

-- Maximize or restore window
function Terminal:Maximize()
    if not self._isMaximized then
        self._savedPosition = self.Frame.Position
        self._savedSize = self.Frame.Size
        local goalPos = UDim2.new(0, 0, 0, 0)
        local goalSize = UDim2.new(1, 0, 1, 0)
        TweenService:Create(self.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = goalPos, Size = goalSize}):Play()
        self._isMaximized = true
    else
        TweenService:Create(self.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = self._savedPosition, Size = self._savedSize}):Play()
        self._isMaximized = false
    end
end

-- Close terminal (destroy UI and resume any waiting coroutines)
function Terminal:Close()
    for _, thread in ipairs(self.waiting) do
        coroutine.resume(thread, "")
    end
    self.waiting = {}
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
    self.Frame = nil
end

return Terminal
