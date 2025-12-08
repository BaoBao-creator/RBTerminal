local TerminalLib = {}

-- Hàm tạo cửa sổ Terminal mới
function TerminalLib:New()
	-- 1. Xử lý nơi chứa UI (Hỗ trợ Executor an toàn)
	local guiService = game:GetService("CoreGui")
	pcall(function() guiService = gethui() end) -- Nếu có gethui thì dùng (an toàn hơn)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Terminal_Instance_" .. math.random(1000, 9999)
	screenGui.Parent = guiService
	
	-- ResetOnSpawn = false để khi nhân vật chết UI không mất
	if screenGui:IsA("ScreenGui") then screenGui.ResetOnSpawn = false end

	-- 2. MAIN FRAME (Hình chữ nhật đen, 1/2 màn hình)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0.5, 0, 0.5, 0) -- Dài rộng bằng nửa màn hình
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0) -- Căn giữa màn hình
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5) -- Điểm neo ở giữa
	mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15) -- Màu đen (hơi xám nhẹ cho sang)
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = true -- Cho phép kéo thả cửa sổ
	mainFrame.Parent = screenGui

	-- Cấu hình chiều cao cho các phần (Pixels)
	local topHeight = 30
	local bottomHeight = 35
	local lineWidth = 2 -- Độ dày đường kẻ trắng

	-- === PHẦN 1: TOP BAR (Chứa nút chức năng) ===
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, topHeight)
	topBar.BackgroundTransparency = 1
	topBar.Parent = mainFrame
	
	-- Ví dụ thêm một nút Close đỏ ở góc trên
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Size = UDim2.new(0, topHeight, 1, 0)
	closeBtn.Position = UDim2.new(1, -topHeight, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.TextColor3 = Color3.new(1,1,1)
	closeBtn.Parent = topBar
	closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

	-- === ĐƯỜNG KẺ TRẮNG 1 ===
	local line1 = Instance.new("Frame")
	line1.Name = "Separator1"
	line1.Size = UDim2.new(1, 0, 0, lineWidth)
	line1.Position = UDim2.new(0, 0, 0, topHeight)
	line1.BackgroundColor3 = Color3.new(1, 1, 1) -- Màu trắng
	line1.BorderSizePixel = 0
	line1.Parent = mainFrame

	-- === PHẦN 3: BOTTOM BAR (Input TextBox) - Làm cái này trước để tính toán phần giữa ===
	local bottomBar = Instance.new("TextBox")
	bottomBar.Name = "InputBox"
	bottomBar.Size = UDim2.new(1, -10, 0, bottomHeight - 10) -- Trừ lề một chút cho đẹp
	bottomBar.Position = UDim2.new(0, 5, 1, -bottomHeight + 5)
	bottomBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bottomBar.TextColor3 = Color3.new(1, 1, 1)
	bottomBar.Text = ""
	bottomBar.PlaceholderText = "Nhập lệnh vào đây..."
	bottomBar.Font = Enum.Font.Code -- Font kiểu terminal
	bottomBar.TextSize = 14
	bottomBar.TextXAlignment = Enum.TextXAlignment.Left
	bottomBar.Parent = mainFrame

	-- === ĐƯỜNG KẺ TRẮNG 2 ===
	local line2 = Instance.new("Frame")
	line2.Name = "Separator2"
	line2.Size = UDim2.new(1, 0, 0, lineWidth)
	line2.Position = UDim2.new(0, 0, 1, -bottomHeight - lineWidth) -- Nằm ngay trên bottom bar
	line2.BackgroundColor3 = Color3.new(1, 1, 1) -- Màu trắng
	line2.BorderSizePixel = 0
	line2.Parent = mainFrame

	-- === PHẦN 2: MIDDLE (Hiển thị Text - Lấp đầy khoảng trống) ===
	-- Chiều cao = Tổng - (Top + Line1 + Line2 + Bottom)
	local middleFrame = Instance.new("ScrollingFrame")
	middleFrame.Name = "OutputLog"
	-- Tính toán kích thước còn lại cho phần giữa
	-- Position: Bắt đầu từ dưới Line 1
	middleFrame.Position = UDim2.new(0, 5, 0, topHeight + lineWidth + 5)
	-- Size: 100% chiều rộng, Chiều cao = 100% - (phần trên + phần dưới + padding)
	middleFrame.Size = UDim2.new(1, -10, 1, -(topHeight + bottomHeight + lineWidth*2 + 10))
	middleFrame.BackgroundTransparency = 1
	middleFrame.ScrollBarThickness = 4
	middleFrame.Parent = mainFrame
	
	-- Layout cho text bên trong tự xuống dòng
	local layout = Instance.new("UIListLayout")
	layout.Parent = middleFrame
	
	-- TẠO OBJECT ĐIỀU KHIỂN (Để trả về cho người dùng)
	local WindowObj = {}
	
	-- Hàm để in chữ ra màn hình giữa
	function WindowObj:Log(text)
		local label = Instance.new("TextLabel")
		label.Text = text
		label.Size = UDim2.new(1, 0, 0, 20) -- Chiều cao mỗi dòng
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(0, 1, 0) -- Chữ xanh lá cây hacker
		label.Font = Enum.Font.Code
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = middleFrame
		
		-- Tự động cuộn xuống dưới cùng
		middleFrame.CanvasPosition = Vector2.new(0, 99999)
	end
	
	-- Xử lý khi người dùng Enter trong TextBox
	bottomBar.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			local text = bottomBar.Text
			WindowObj:Log("> " .. text) -- In lại lệnh vừa nhập
			bottomBar.Text = "" -- Xóa ô nhập
			
			-- Ở đây bạn có thể thêm logic xử lý lệnh (callback)
			if WindowObj.OnCommand then
				WindowObj.OnCommand(text)
			end
		end
	end)

	return WindowObj
end

return TerminalLib
