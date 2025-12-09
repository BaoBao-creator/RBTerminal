local TerminalLib = {}
TerminalLib.__index = TerminalLib

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local PROTECT_GUI = true 

local function GetContainer()
    if PROTECT_GUI and syn and syn.protect_gui then
        local sg = Instance.new("ScreenGui")
        syn.protect_gui(sg)
        sg.Parent = CoreGui
        return sg
    elseif gethui then
        local sg = Instance.new("ScreenGui")
        sg.Parent = gethui()
        return sg
    else
        local sg = Instance.new("ScreenGui")
        sg.Parent = CoreGui
        return sg
    end
end

local function MakeDraggable(object, dragHandle)
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = object.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

local function MakeResizable(object, grip, minSize)
    local resizing, resizeStart, startSize
    grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeStart = input.Position
            startSize = object.AbsoluteSize
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then resizing = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStart
            object.Size = UDim2.new(0, math.max(minSize.X, startSize.X + delta.X), 0, math.max(minSize.Y, startSize.Y + delta.Y))
        end
    end)
end

function TerminalLib.new()
    local self = setmetatable({}, TerminalLib)
    
    self.Gui = GetContainer()
    self.IsMinimized = false
    self.IsMaximized = false
    self.SavedRect = {Pos = UDim2.new(0.5,-250, 0.5,-150), Size = UDim2.new(0, 500, 0, 300)}
    self.CmdEnabled = false
    self.InputEnabled = true
    self.FontSize = 14
    self.Lines = {}
    self.WaitingForInput = false
    self.InputBindable = Instance.new("BindableEvent")
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainTerminal"
    MainFrame.Size = self.SavedRect.Size
    MainFrame.Position = self.SavedRect.Pos
    MainFrame.BackgroundColor3 = Color3.new(0,0,0)
    MainFrame.BorderSizePixel = 1
    MainFrame.BorderColor3 = Color3.new(1,1,1)
    MainFrame.Parent = self.Gui
    self.MainFrame = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 25)
    TitleBar.BackgroundColor3 = Color3.new(0,0,0)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleLine = Instance.new("Frame")
    TitleLine.Size = UDim2.new(1,0,0,1)
    TitleLine.Position = UDim2.new(0,0,1,0)
    TitleLine.BackgroundColor3 = Color3.new(1,1,1)
    TitleLine.BorderSizePixel = 0
    TitleLine.Parent = TitleBar
    
    MakeDraggable(MainFrame, TitleBar)

    local IconFrame = Instance.new("Frame")
    IconFrame.Size = UDim2.new(0, 50, 0, 50)
    IconFrame.Position = UDim2.new(0.9, 0, 0.9, 0)
    IconFrame.BackgroundColor3 = Color3.new(0,0,0)
    IconFrame.Visible = false
    IconFrame.Parent = self.Gui
    
    local IconCorner = Instance.new("UICorner")
    IconCorner.CornerRadius = UDim.new(0.5, 0)
    IconCorner.Parent = IconFrame
    
    local IconText = Instance.new("TextButton")
    IconText.Size = UDim2.new(1,0,1,0)
    IconText.BackgroundTransparency = 1
    IconText.Text = "#"
    IconText.TextColor3 = Color3.new(1,1,1)
    IconText.TextSize = 24
    IconText.Font = Enum.Font.Code
    IconText.Parent = IconFrame
    
    local IconResize = Instance.new("Frame")
    IconResize.Size = UDim2.new(0,10,0,10)
    IconResize.Position = UDim2.new(1,-10,1,-10)
    IconResize.BackgroundTransparency = 1
    IconResize.Parent = IconFrame
    
    MakeDraggable(IconFrame, IconFrame)
    MakeResizable(IconFrame, IconResize, Vector2.new(30,30))
    self.IconFrame = IconFrame

    local ContentScroll = Instance.new("ScrollingFrame")
    ContentScroll.Name = "Content"
    ContentScroll.Position = UDim2.new(0, 5, 0, 30)
    ContentScroll.Size = UDim2.new(1, -10, 1, -60)
    ContentScroll.BackgroundTransparency = 1
    ContentScroll.ScrollBarThickness = 4
    ContentScroll.ScrollBarImageColor3 = Color3.new(1,1,1)
    ContentScroll.BorderSizePixel = 0
    ContentScroll.Parent = MainFrame
    self.ContentScroll = ContentScroll
    
    local UIList = Instance.new("UIListLayout")
    UIList.SortOrder = Enum.SortOrder.LayoutOrder
    UIList.Parent = ContentScroll
    self.UIList = UIList
    
    UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ContentScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
        ContentScroll.CanvasPosition = Vector2.new(0, UIList.AbsoluteContentSize.Y)
    end)

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1, -10, 0, 25)
    InputBox.Position = UDim2.new(0, 5, 1, -30)
    InputBox.BackgroundColor3 = Color3.new(0,0,0)
    InputBox.TextColor3 = Color3.new(1,1,1)
    InputBox.BorderColor3 = Color3.new(1,1,1)
    InputBox.Font = Enum.Font.Code
    InputBox.TextSize = self.FontSize
    InputBox.Text = ""
    InputBox.ClearTextOnFocus = false
    InputBox.TextXAlignment = Enum.TextXAlignment.Left
    InputBox.Parent = MainFrame
    self.InputBox = InputBox

local function CreateBtn(text, order)
        local btn = Instance.new("TextButton")
        btn.Name = "Btn_" .. text -- Đặt tên để dễ debug nếu cần
        btn.Size = UDim2.new(0, 30, 1, 0)
        btn.Position = UDim2.new(1, -30 * order, 0, 0)
        btn.BackgroundTransparency = 1
        btn.Text = text
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.Code
        btn.TextSize = 14
        btn.ZIndex = 10 -- [QUAN TRỌNG] Đưa nút lên lớp cao nhất để nhận click
        btn.Active = true -- Đảm bảo nút nhận tín hiệu input
        btn.Parent = TitleBar -- TitleBar vẫn là cha, nhưng ZIndex con cao hơn sẽ nổi lên
        
        btn.MouseEnter:Connect(function() 
            btn.BackgroundTransparency = 0 
            btn.BackgroundColor3 = Color3.new(1,1,1)
            btn.TextColor3 = Color3.new(0,0,0)
        end)
        btn.MouseLeave:Connect(function() 
            btn.BackgroundTransparency = 1
            btn.TextColor3 = Color3.new(1,1,1)
        end)
        return btn
    end

    local BtnClose = CreateBtn("X", 1)
    local BtnMax = CreateBtn("□", 2)
    local BtnMin = CreateBtn("-", 3)
    local BtnSet = CreateBtn("...", 4)
    self.BtnClose = BtnClose

    BtnClose.MouseButton1Click:Connect(function()
        self:close()
    end)

    BtnMax.MouseButton1Click:Connect(function()
        if self.IsMaximized then
            local tw = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = self.SavedRect.Size, Position = self.SavedRect.Pos})
            tw:Play()
            self.IsMaximized = false
            TitleBar.Active = true 
        else
            self.SavedRect.Size = MainFrame.Size
            self.SavedRect.Pos = MainFrame.Position
            local tw = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,0)})
            tw:Play()
            self.IsMaximized = true
            TitleBar.Active = false
        end
    end)

    BtnMin.MouseButton1Click:Connect(function()
        if self.IsMinimized then return end
        self.IsMinimized = true
        self.SavedRect.Size = MainFrame.Size
        self.SavedRect.Pos = MainFrame.Position
        
        local targetSize = UDim2.new(0, IconFrame.AbsoluteSize.X, 0, IconFrame.AbsoluteSize.Y)
        local targetPos = UDim2.new(0, IconFrame.AbsolutePosition.X, 0, IconFrame.AbsolutePosition.Y)
        
        local tw = TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = targetSize, Position = targetPos, BackgroundTransparency = 1})
        
        for _,v in pairs(MainFrame:GetDescendants()) do
            if v:IsA("GuiObject") then
                TweenService:Create(v, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextTransparency = 1, ScrollBarImageTransparency = 1}):Play()
            end
        end
        
        tw:Play()
        tw.Completed:Connect(function()
            MainFrame.Visible = false
            IconFrame.Visible = true
            local iconPop = TweenService:Create(IconFrame, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {Size = UDim2.new(0,50,0,50)})
            IconFrame.Size = UDim2.new(0,0,0,0)
            iconPop:Play()
        end)
    end)

    IconText.MouseButton1Click:Connect(function()
        IconFrame.Visible = false
        MainFrame.Visible = true
        MainFrame.Position = UDim2.new(0, IconFrame.AbsolutePosition.X, 0, IconFrame.AbsolutePosition.Y)
        MainFrame.Size = UDim2.new(0, IconFrame.AbsoluteSize.X, 0, IconFrame.AbsoluteSize.Y)
        
        local tw = TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = self.SavedRect.Size, Position = self.SavedRect.Pos, BackgroundTransparency = 0})
        
        for _,v in pairs(MainFrame:GetDescendants()) do
            if v:IsA("GuiObject") and v.Name ~= "Shadow" then 
                 local props = {BackgroundTransparency = (v.Name == "MainTerminal" or v.Name == "TitleBar" or v == InputBox) and 0 or 1}
                 if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then props.TextTransparency = 0 end
                 if v:IsA("ScrollingFrame") then props.ScrollBarImageTransparency = 0 end
                 TweenService:Create(v, TweenInfo.new(0.3), props):Play()
            end
        end
        TitleLine.BackgroundTransparency = 0
        
        tw:Play()
        tw.Completed:Connect(function()
            self.IsMinimized = false
        end)
    end)

    local DraggingSet = false
    local SetStart = 0
    local FontSizeLabel = Instance.new("TextLabel")
    FontSizeLabel.Size = UDim2.new(0, 100, 0, 20)
    FontSizeLabel.AnchorPoint = Vector2.new(0.5, 1)
    FontSizeLabel.Position = UDim2.new(0.5, 0, 0, -5)
    FontSizeLabel.BackgroundTransparency = 1
    FontSizeLabel.Text = "Size: 14"
    FontSizeLabel.TextColor3 = Color3.new(1,1,1)
    FontSizeLabel.TextTransparency = 1
    FontSizeLabel.Parent = BtnSet

    BtnSet.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            DraggingSet = true
            SetStart = inp.Position.X
            TweenService:Create(FontSizeLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then DraggingSet = false TweenService:Create(FontSizeLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play() end end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(inp)
        if DraggingSet and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position.X - SetStart
            if math.abs(delta) > 5 then
                local change = delta > 0 and 1 or -1
                self.FontSize = math.clamp(self.FontSize + change, 8, 32)
                SetStart = inp.Position.X
                FontSizeLabel.Text = "Size: "..self.FontSize
                InputBox.TextSize = self.FontSize
                for _, line in pairs(self.Lines) do line.TextSize = self.FontSize end
            end
        end
    end)
    
    local MainResizer = Instance.new("Frame")
    MainResizer.Size = UDim2.new(0,15,0,15)
    MainResizer.Position = UDim2.new(1,-15,1,-15)
    MainResizer.BackgroundTransparency = 1
    MainResizer.Parent = MainFrame
    MakeResizable(MainFrame, MainResizer, Vector2.new(200,100))

-- Tìm đoạn InputBox.FocusLost cũ và thay bằng đoạn này:
    InputBox.FocusLost:Connect(function(enter)
        if enter then
            local txt = InputBox.Text
            
            -- 1. Ưu tiên: Nếu script đang đợi input từ hàm :input()
            if self.WaitingForInput then
                self.InputBindable:Fire(txt)
                InputBox.Text = ""
                return
            end

            self:print("> "..txt) -- In lại dòng người dùng vừa nhập

            -- 2. Xử lý các LỆNH TẮT (Custom Commands)
            local command = txt:lower() -- Chuyển về chữ thường để không phân biệt hoa thường
            
            if command == "clear" or command == "cls" then
                self:clear()
                InputBox.Text = ""
                task.delay(0.1, function() InputBox:CaptureFocus() end) -- Giữ focus để nhập tiếp
                return
            elseif command == "exit" then
                self:close()
                return
            end

            -- 3. Xử lý chạy code Lua (Nếu CmdEnabled = true)
            if self.CmdEnabled then
                local func, err = loadstring(txt)
                if func then
                    -- Tạo môi trường để script có thể gọi 'print' hoặc 'clear' trực tiếp trong code
                    local env = getgenv() 
                    setfenv(func, setmetatable({
                        print = function(...) self:print(...) end,
                        clear = function() self:clear() end,
                        wait = task.wait
                    }, {__index = env}))
                    
                    local s, e = pcall(func)
                    if not s then self:print("Error: "..e) end
                else
                    self:print("Syntax: "..err)
                end
            end
            
            InputBox.Text = ""
            task.delay(0.1, function() InputBox:CaptureFocus() end)
        end
    end)

    return self
end

function TerminalLib:print(text)
    local str = tostring(text)
    str = str:gsub("\\n", "\n")
    local label = Instance.new("TextLabel")
    label.Text = str
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.Code
    label.TextSize = self.FontSize
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Size = UDim2.new(1, 0, 0, 0)
    label.TextWrapped = true
    label.Parent = self.ContentScroll
    table.insert(self.Lines, label)
end

function TerminalLib:clear()
    for _, v in pairs(self.Lines) do v:Destroy() end
    self.Lines = {}
end

function TerminalLib:deleteLine(idx)
    if self.Lines[idx] then
        self.Lines[idx]:Destroy()
        table.remove(self.Lines, idx)
    end
end

function TerminalLib:replaceLine(idx, text)
    if self.Lines[idx] then
        self.Lines[idx].Text = text
    end
end

function TerminalLib:replaceAt(lineIdx, charIdx, text)
    if self.Lines[lineIdx] then
        local old = self.Lines[lineIdx].Text
        local pre = string.sub(old, 1, charIdx - 1)
        local post = string.sub(old, charIdx + #text)
        self.Lines[lineIdx].Text = pre .. text .. post
    end
end

function TerminalLib:input()
    self.WaitingForInput = true
    self.InputBox.PlaceholderText = "Waiting for input..."
    self.InputBox:CaptureFocus()
    local val = self.InputBindable.Event:Wait()
    self.WaitingForInput = false
    self.InputBox.PlaceholderText = ""
    return val
end

function TerminalLib:setInputEnabled(bool)
    self.InputEnabled = bool
    self.InputBox.TextEditable = bool
    self.InputBox.Visible = bool
    if not bool then self.ContentScroll.Size = UDim2.new(1,-10,1,-10) else self.ContentScroll.Size = UDim2.new(1,-10,1,-60) end
end

function TerminalLib:setCmdEnabled(bool)
    self.CmdEnabled = bool
end

function TerminalLib:setCloseEnabled(bool)
    self.BtnClose.Visible = bool
end

function TerminalLib:close()
    self.Gui:Destroy()
end

getgenv().TerminalLib = TerminalLib
return TerminalLib
