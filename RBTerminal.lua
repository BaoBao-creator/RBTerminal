-- TerminalModule.lua
-- Phiên bản: 1.0
-- Mô-đun Terminal GUI cho Roblox (procedural) — triển khai dựa trên tài liệu thiết kế đi kèm.
-- Tác vụ: tạo cửa sổ draggable/resizable, minimize/icon, fullscreen, slider chỉnh cỡ chữ, buffer, input() đồng bộ, runCode sandboxed.

local Terminal = {}
Terminal.__index = Terminal

-- Services
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Config mặc định
local DEFAULTS = {
    START_POS = UDim2.new(0, 100, 0, 100),
    START_SIZE = UDim2.new(0, 600, 0, 400),
    MIN_WIDTH = 220,
    MIN_HEIGHT = 120,
    DRAG_THRESHOLD = 5,
    MAX_LINES = 500,
    DEFAULT_FONT_SIZE = 14,
    DISPLAY_ORDER = 10000,
}

-- Helper utilities
local function clamp(val, a, b) return math.clamp(val, a, b) end
local function isMouse(input) return input.UserInputType == Enum.UserInputType.MouseButton1 end

-- Create a new Terminal instance; optional parent (ScreenGui). If no parent, put into CoreGui when possible.
function Terminal.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Terminal)

    self.config = {}
    for k,v in pairs(DEFAULTS) do self.config[k] = opts[k] or v end

    self.Buffer = {}
    self.UIMap = {}
    self.WaitingInputs = {} -- list of coroutines waiting for input
    self.CurrentFontSize = self.config.DEFAULT_FONT_SIZE
    self.IsInputEnabled = true
    self._connections = {}

    -- build GUI
    self:_buildUI(opts.Parent)

    return self
end

-- Internal: build procedural UI
function Terminal:_buildUI(parent)
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TerminalScreen"
    screenGui.ResetOnSpawn = false
    -- Try to put into CoreGui if allowed (executors). Fallback to PlayerGui.
    local success, err = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not success then
        local localPlayer = Players.LocalPlayer
        if localPlayer and localPlayer:FindFirstChild("PlayerGui") then
            screenGui.Parent = localPlayer.PlayerGui
        else
            screenGui.Parent = parent or game:GetService("StarterGui")
        end
    end
    screenGui.DisplayOrder = self.config.DISPLAY_ORDER

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = self.config.START_SIZE
    mainFrame.Position = self.config.START_POS
    mainFrame.AnchorPoint = Vector2.new(0,0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    -- UI Corner for rounded look
    local uiCorner = Instance.new("UICorner") uiCorner.CornerRadius = UDim.new(0,8) uiCorner.Parent = mainFrame

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1,0,0,30)
    titleBar.Position = UDim2.new(0,0,0,0)
    titleBar.Parent = mainFrame
    titleBar.BackgroundTransparency = 1

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1,-120,1,0)
    titleLabel.Position = UDim2.new(0,8,0,0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Terminal"
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextColor3 = Color3.fromRGB(220,220,220)
    titleLabel.Font = Enum.Font.Code
    titleLabel.TextSize = 14
    titleLabel.Parent = titleBar

    -- Control group (minimize, maximize, close)
    local controlGroup = Instance.new("Frame")
    controlGroup.Name = "ControlGroup"
    controlGroup.Size = UDim2.new(0,110,1,0)
    controlGroup.Position = UDim2.new(1,-110,0,0)
    controlGroup.BackgroundTransparency = 1
    controlGroup.Parent = titleBar

    local function makeControlButton(name, text, posOffset)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0,30,0,22)
        btn.Position = UDim2.new(0,posOffset,0,4)
        btn.AnchorPoint = Vector2.new(0,0)
        btn.BackgroundTransparency = 1
        btn.Text = text
        btn.Font = Enum.Font.Code
        btn.TextSize = 16
        btn.TextColor3 = Color3.fromRGB(200,200,200)
        btn.Parent = controlGroup
        return btn
    end

    local btnMin = makeControlButton("MinimizeBtn", "-", 0)
    local btnMax = makeControlButton("MaximizeBtn", "⬜", 36)
    local btnClose = makeControlButton("CloseBtn", "×", 72)

    -- Slider button "..."
    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Name = "SettingsBtn"
    settingsBtn.Size = UDim2.new(0,28,0,22)
    settingsBtn.Position = UDim2.new(0.5, -14, 0.5, -11)
    settingsBtn.AnchorPoint = Vector2.new(0.5,0.5)
    settingsBtn.Parent = titleBar
    settingsBtn.BackgroundTransparency = 1
    settingsBtn.Text = "..."
    settingsBtn.Font = Enum.Font.Code
    settingsBtn.TextSize = 18
    settingsBtn.TextColor3 = Color3.fromRGB(200,200,200)

    -- Slider container
    local sliderContainer = Instance.new("Frame")
    sliderContainer.Name = "SliderContainer"
    sliderContainer.Size = UDim2.new(0,160,0,26)
    sliderContainer.Position = UDim2.new(0.5, -80, 0, 30)
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.Visible = false
    sliderContainer.Parent = mainFrame

    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "Bg"
    sliderBg.Size = UDim2.new(1,0,1,0)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = sliderContainer
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0,6)

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "Knob"
    sliderKnob.Size = UDim2.new(0,12,1,-6)
    sliderKnob.Position = UDim2.new(0.5, -6, 0, 3)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(200,200,200)
    sliderKnob.Parent = sliderBg
    Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(0,6)

    -- Content area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1,0,1,-30)
    contentArea.Position = UDim2.new(0,0,0,30)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    -- Scrolling frame for text
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, -8, 1, -8)
    scroll.Position = UDim2.new(0,4,0,4)
    scroll.Parent = contentArea
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

    -- UIListLayout for lines
    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = scroll
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0,2)

    -- Input line
    local inputBox = Instance.new("TextBox")
    inputBox.Name = "InputBox"
    inputBox.Size = UDim2.new(1, -8, 0, 26)
    inputBox.Position = UDim2.new(0,4,1,-34)
    inputBox.AnchorPoint = Vector2.new(0,0)
    inputBox.Parent = mainFrame
    inputBox.BackgroundColor3 = Color3.fromRGB(18,18,18)
    inputBox.BorderSizePixel = 0
    inputBox.TextColor3 = Color3.fromRGB(220,220,220)
    inputBox.Font = Enum.Font.Code
    inputBox.TextSize = self.CurrentFontSize
    inputBox.ClearTextOnFocus = false
    inputBox.MultiLine = false

    -- Resize handle
    local resizeHandle = Instance.new("Frame")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.new(0,18,0,18)
    resizeHandle.AnchorPoint = Vector2.new(1,1)
    resizeHandle.Position = UDim2.new(1,0,1,0)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Parent = mainFrame

    local resizeGrip = Instance.new("ImageLabel")
    resizeGrip.Size = UDim2.new(1,0,1,0)
    resizeGrip.Parent = resizeHandle
    resizeGrip.BackgroundTransparency = 1
    resizeGrip.Image = "rbxassetid://6778319374" -- subtle grip (fallback)
    resizeGrip.ImageTransparency = 0.8

    -- Minimized icon
    local minimizedIcon = Instance.new("ImageButton")
    minimizedIcon.Name = "MinimizedIcon"
    minimizedIcon.Size = UDim2.new(0,48,0,48)
    minimizedIcon.Position = UDim2.new(0,20,1,-68)
    minimizedIcon.AnchorPoint = Vector2.new(0,0)
    minimizedIcon.Visible = false
    minimizedIcon.Parent = screenGui
    minimizedIcon.BackgroundTransparency = 1

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1,0,1,0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "#"
    iconLabel.Font = Enum.Font.Code
    iconLabel.TextSize = 20
    iconLabel.TextColor3 = Color3.fromRGB(230,230,230)
    iconLabel.Parent = minimizedIcon

    -- Store refs
    self._gui = screenGui
    self._main = mainFrame
    self._title = titleBar
    self._titleLabel = titleLabel
    self._btnMin = btnMin
    self._btnMax = btnMax
    self._btnClose = btnClose
    self._settingsBtn = settingsBtn
    self._sliderContainer = sliderContainer
    self._sliderBg = sliderBg
    self._sliderKnob = sliderKnob
    self._content = contentArea
    self._scroll = scroll
    self._inputBox = inputBox
    self._resizeHandle = resizeHandle
    self._minimizedIcon = minimizedIcon
    self._listLayout = listLayout

    -- Connect behavior
    self:_connectWindowDrag()
    self:_connectResize()
    self:_connectControls()
    self:_connectSettings()
    self:_connectInputBox()

end

-- Internal: connect dragging
function Terminal:_connectWindowDrag()
    local title = self._title
    local frame = self._main

    local dragging = false
    local dragStartMouse = Vector2.new()
    local dragStartPos = UDim2.new()
    local dragConn1, dragConn2

    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
            dragStartPos = frame.Position
            -- capture changed input
            dragConn2 = input.Changed:Connect(function(prop)
                if prop == "UserInputState" then
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end
            end)
        end
    end

    local function onInputChanged(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            -- compute delta
            local mouse = UserInputService:GetMouseLocation()
            -- GetMouseLocation returns screen coordinates in pixels
            local delta = Vector2.new(mouse.X, mouse.Y) - dragStartMouse
            -- compute new absolute position
            local absPos = frame.AbsolutePosition
            local newX = dragStartPos.X.Offset + delta.X
            local newY = dragStartPos.Y.Offset + delta.Y
            -- clamp to viewport
            local viewportSize = workspace.CurrentCamera.ViewportSize
            newX = clamp(newX, 0, viewportSize.X - frame.AbsoluteSize.X)
            newY = clamp(newY, 0, viewportSize.Y - frame.AbsoluteSize.Y)
            frame.Position = UDim2.new(0, newX, 0, newY)
        end
    end

    -- Use InputBegan on the title bar
    table.insert(self._connections, title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- start pending and set up threshold detection
            local startPos = Vector2.new(input.Position.X, input.Position.Y)
            local isClick = true
            local changedConn
            local function onChanged(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement then
                    local cur = UserInputService:GetMouseLocation()
                    local dist = (Vector2.new(cur.X, cur.Y) - startPos).Magnitude
                    if dist > self.config.DRAG_THRESHOLD then
                        isClick = false
                        changedConn:Disconnect()
                        dragging = true
                        dragStartMouse = Vector2.new(startPos.X, startPos.Y)
                        -- record startPos for frame
                        dragStartPos = frame.Position
                    end
                end
            end
            changedConn = UserInputService.InputChanged:Connect(onChanged)

            local endedConn
            endedConn = UserInputService.InputEnded:Connect(function(i)
                if i == input then
                    -- input ended
                    if isClick then
                        -- treat as click (focus)
                        frame.Parent.DisplayOrder = self.config.DISPLAY_ORDER + 1
                    end
                    if changedConn and changedConn.Connected then changedConn:Disconnect() end
                    endedConn:Disconnect()
                end
            end)
        end
    end))

    table.insert(self._connections, UserInputService.InputChanged:Connect(onInputChanged))
    -- Also ensure we stop dragging on mouse up
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
end

-- Internal: connect resize using bottom-right handle
function Terminal:_connectResize()
    local handle = self._resizeHandle
    local frame = self._main
    local resizing = false
    local startMouse = Vector2.new()
    local startSize = UDim2.new()

    table.insert(self._connections, handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            local mp = UserInputService:GetMouseLocation()
            startMouse = Vector2.new(mp.X, mp.Y)
            startSize = frame.Size
        end
    end))

    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not resizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local mp = UserInputService:GetMouseLocation()
            local delta = Vector2.new(mp.X, mp.Y) - startMouse
            -- compute new size -- use AbsoluteSize then convert to offset
            local newW = frame.AbsoluteSize.X + delta.X
            local newH = frame.AbsoluteSize.Y + delta.Y
            newW = math.max(newW, self.config.MIN_WIDTH)
            newH = math.max(newH, self.config.MIN_HEIGHT)
            frame.Size = UDim2.new(0, newW, 0, newH)
        end
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end))
end

-- Internal: control buttons and minimize/maximize
function Terminal:_connectControls()
    local btnMin, btnMax, btnClose = self._btnMin, self._btnMax, self._btnClose
    local frame = self._main
    local minimizedIcon = self._minimizedIcon
    local gui = self._gui
    local savedState = {}
    
    btnClose.MouseButton1Click:Connect(function()
        -- hide and clean up
        gui:Destroy()
        for _,c in ipairs(self._connections) do
            if c and c.Connected then pcall(function() c:Disconnect() end) end
        end
    end)

    btnMin.MouseButton1Click:Connect(function()
        -- Tween to minimized icon position/size
        savedState.Position = frame.Position
        savedState.Size = frame.Size
        minimizedIcon.Position = UDim2.new(0, frame.AbsolutePosition.X, 0, frame.AbsolutePosition.Y)
        minimizedIcon.Visible = true
        -- Tween main frame to icon
        local targetPos = minimizedIcon.Position
        local targetSize = UDim2.new(0, minimizedIcon.AbsoluteSize.X, 0, minimizedIcon.AbsoluteSize.Y)
        local tween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPos, Size = targetSize, BackgroundTransparency = 1})
        tween:Play()
        tween.Completed:Connect(function()
            frame.Visible = false
        end)
    end)

    minimizedIcon.MouseButton1Click:Connect(function()
        -- restore
        frame.Visible = true
        minimizedIcon.Visible = false
        local restorePos = savedState.Position or UDim2.new(0,100,0,100)
        local restoreSize = savedState.Size or self.config.START_SIZE
        -- start at icon transform
        frame.Position = minimizedIcon.Position
        frame.Size = UDim2.new(0, minimizedIcon.AbsoluteSize.X, 0, minimizedIcon.AbsoluteSize.Y)
        local tween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Position = restorePos, Size = restoreSize, BackgroundTransparency = 0})
        tween:Play()
    end)

    local isFullscreen = false
    btnMax.MouseButton1Click:Connect(function()
        if not isFullscreen then
            -- save
            savedState.Position = frame.Position
            savedState.Size = frame.Size
            -- tween to full
            frame.Size = UDim2.new(1,0,1,0)
            frame.Position = UDim2.new(0,0,0,0)
            -- disable drag/resize by temporarily clearing connections related to input
            -- we'll simply set a flag
            isFullscreen = true
        else
            -- restore
            frame.Position = savedState.Position or self.config.START_POS
            frame.Size = savedState.Size or self.config.START_SIZE
            isFullscreen = false
        end
    end)
end

-- Internal: settings slider (hold + drag)
function Terminal:_connectSettings()
    local btn = self._settingsBtn
    local slider = self._sliderContainer
    local knob = self._sliderKnob
    local dragging = false
    local startMouseX = 0
    local startKnobX = 0
    local bg = self._sliderBg

    local function showSlider()
        slider.Visible = true
        slider.Position = UDim2.new(0.5, -80, 0, 30)
        -- fade in
        slider.BackgroundTransparency = 1
        TweenService:Create(slider, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end
    local function hideSlider()
        TweenService:Create(slider, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        delay(0.18, function() if slider then slider.Visible = false end end)
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            showSlider()
            dragging = true
            startMouseX = UserInputService:GetMouseLocation().X
            startKnobX = knob.AbsolutePosition.X
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- if not moved, still show briefly
            -- We'll hide when mouse releases after dragging
        end
    end)

    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local mp = UserInputService:GetMouseLocation()
            local delta = mp.X - startMouseX
            -- compute knob position within slider
            local bgAbs = bg.AbsoluteSize.X
            local newKnobX = clamp((startKnobX - bg.AbsolutePosition.X) + delta, 0, bgAbs - knob.AbsoluteSize.X)
            knob.Position = UDim2.new(0, newKnobX, 0, 3)
            -- normalize 0..1
            local val = newKnobX / (bgAbs - knob.AbsoluteSize.X)
            local newSize = math.floor( clamp(8 + val * 28, 8, 36) )
            self.CurrentFontSize = newSize
            -- apply to all visible lines and input box
            self._inputBox.TextSize = newSize
            for _,lbl in pairs(self._scroll:GetChildren()) do
                if lbl:IsA("TextLabel") then lbl.TextSize = newSize end
            end
        end
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            hideSlider()
        end
    end))
end

-- Internal: connect input box and synchronous input mechanic
function Terminal:_connectInputBox()
    local inputBox = self._inputBox

    -- When Enter pressed, resume waiting coroutine(s) in FIFO order
    inputBox.FocusLost:Connect(function(enterPressed)
        local text = inputBox.Text
        inputBox.Text = ""
        if enterPressed then
            -- print to terminal
            self:print(text)
            -- resume first waiting coroutine if any
            if #self.WaitingInputs > 0 then
                local co = table.remove(self.WaitingInputs, 1)
                if coroutine.status(co) == 'suspended' then
                    local ok, err = coroutine.resume(co, text)
                    if not ok then
                        self:print("[Terminal] Error resuming coroutine: "..tostring(err))
                    end
                end
            end
        end
    end)
end

-- Public API: print
function Terminal:print(...)
    local args = {...}
    local parts = {}
    for i,v in ipairs(args) do parts[i] = tostring(v) end
    local line = table.concat(parts, "\t")
    table.insert(self.Buffer, line)

    -- enforce max lines
    while #self.Buffer > self.config.MAX_LINES do
        table.remove(self.Buffer, 1)
        -- remove first UI child if exists
        local children = self._scroll:GetChildren()
        for _,c in ipairs(children) do
            if c:IsA("TextLabel") then
                c:Destroy()
                break
            end
        end
    end

    -- create TextLabel for new line
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -8, 0, 18)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Code
    lbl.TextSize = self.CurrentFontSize
    lbl.TextColor3 = Color3.fromRGB(220,220,220)
    lbl.TextWrapped = true
    lbl.RichText = true
    lbl.Text = line
    lbl.Parent = self._scroll

    -- auto scroll to bottom unless user actively scrolled up
    pcall(function()
        self._scroll.CanvasPosition = Vector2.new(0, self._scroll.AbsoluteCanvasSize.Y)
    end)
end

-- Public API: clear
function Terminal:clear()
    self.Buffer = {}
    for _,v in pairs(self._scroll:GetChildren()) do
        if v:IsA("TextLabel") then v:Destroy() end
    end
end

-- Public API: replace_line
function Terminal:replace_line(lineNumber, newContent)
    if lineNumber < 1 or lineNumber > #self.Buffer then return false end
    self.Buffer[lineNumber] = tostring(newContent)
    -- attempt to find corresponding UI element (approx by layout order)
    local idx = 0
    for _,c in ipairs(self._scroll:GetChildren()) do
        if c:IsA("TextLabel") then
            idx = idx + 1
            if idx == (lineNumber - (#self.Buffer - #self._scroll:GetChildren())) then
                c.Text = newContent
                return true
            end
        end
    end
    return true
end

-- Public API: replace_char
function Terminal:replace_char(lineNumber, position, newChar)
    if lineNumber < 1 or lineNumber > #self.Buffer then return false end
    local line = tostring(self.Buffer[lineNumber])
    if position < 1 or position > #line then return false end
    local prefix = string.sub(line, 1, position - 1)
    local suffix = string.sub(line, position + 1)
    local newLine = prefix .. tostring(newChar) .. suffix
    self.Buffer[lineNumber] = newLine
    -- update UI if visible (best-effort)
    for _,c in pairs(self._scroll:GetChildren()) do
        if c:IsA("TextLabel") and c.Text == line then
            c.Text = newLine
            break
        end
    end
    return true
end

-- Public API: input (synchronous style)
function Terminal:input(prompt)
    if prompt then self:print(prompt) end
    local co = coroutine.running()
    if not co then
        -- spawn a coroutine to yield
        co = coroutine.create(function() end)
    end
    table.insert(self.WaitingInputs, co)
    -- yield the current coroutine
    return coroutine.yield()
end

-- Public API: enable/disable user input
function Terminal:SetInputEnabled(enabled)
    self.IsInputEnabled = enabled and true or false
    self._inputBox.ClearTextOnFocus = not enabled and true or false
    self._inputBox.TextEditable = enabled
    if enabled then
        self._inputBox.TextColor3 = Color3.fromRGB(220,220,220)
    else
        self._inputBox.TextColor3 = Color3.fromRGB(150,150,150)
    end
end

-- Public API: run code string in sandbox
function Terminal:runCode(code)
    if type(code) ~= 'string' then self:print('[Terminal] runCode expects string') return end

    -- prepare sandbox env
    local env = {
        print = function(...) self:print(...) end,
        input = function(p) return self:input(p) end,
        clear = function() self:clear() end,
        Terminal = self,
        math = math,
        string = string,
        table = table,
        pairs = pairs,
        ipairs = ipairs,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        os = {clock = os.clock},
        -- intentionally limit network/game access
    }

    local loader = loadstring or load
    if not loader then
        self:print('[Terminal] No loadstring/load available in this environment')
        return
    end

    local func, err
    -- try load with environment if supported
    if load then
        local ok
        -- Luau: load(code, chunkname, mode, env)
        -- pcall to avoid runtime errors
        local success, f = pcall(function() return load(code, "TerminalUserChunk", "t", env) end)
        if success and type(f) == 'function' then
            func = f
        else
            -- fallback to loadstring or load without env
            func, err = loader(code)
        end
    else
        func, err = loader(code)
    end

    if not func then
        self:print('[Terminal] Error compiling code: ' .. tostring(err))
        return
    end

    -- if function compiled without env, try setfenv (Luau may not support)
    if debug and type(setfenv) == 'function' then
        pcall(function() setfenv(func, env) end)
    end

    -- run in separate coroutine
    local co = coroutine.create(function()
        local ok, ret = pcall(func)
        if not ok then
            self:print('[Terminal] Runtime Error: '..tostring(ret))
        end
    end)
    coroutine.resume(co)
end

-- Clean up (destroy GUI and disconnect)
function Terminal:Destroy()
    if self._gui and self._gui.Parent then self._gui:Destroy() end
    for _,c in ipairs(self._connections) do
        if c and c.Disconnect then pcall(function() c:Disconnect() end) end
    end
    self._connections = {}
end

return Terminal
