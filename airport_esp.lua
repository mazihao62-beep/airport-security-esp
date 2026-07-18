--[[
	机场安全透视脚本 v2.0 (Airport Security ESP)
	使用 WindUI 库制作界面
	功能：透视区分好人与坏人
	
	更新内容：
	1. ✅ 加载前弹出确认对话框
	2. ✅ Roblox原生弹窗提示操作方式
	3. ✅ 窗口默认开启
	4. ✅ 可拖拽的粗滚动条（兼容鼠标滚轮损坏）
	
	识别机制：
	- 好人 (Agent) → 绿色方框
	- 坏人 (NPC Template) → 红色方框
--]]

-- ===== 加载 WindUI =====
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- ===== 服务 =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ===== 判断平台 =====
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ===== 加载确认 =====
local function showConfirmation(callback)
	-- 先创建确认弹窗（Popup是全局的，不需要Window）
	WindUI:Popup({
		Title = "🛡️ 机场安全透视",
		Icon = "solar:shield-warning-bold",
		Content = "确认加载 机场安全透视 脚本？\n\n📋 功能列表：\n• 👁 透视区分好人与坏人\n• 📏 实时距离与血量显示\n• 🎨 彩色标记框\n• 📱 支持PC / 手机端\n\n是否继续加载？",
		Buttons = {
			{
				Title = "✅ 确认加载",
				Icon = "check",
				Variant = "Primary",
				Callback = function()
					callback(true)
				end,
			},
			{
				Title = "❌ 取消",
				Icon = "x",
				Variant = "Tertiary",
				Callback = function()
					callback(false)
				end,
			},
		},
	})
end

-- ===== Roblox原生弹窗 =====
local function showNativeNotification()
	local success, err = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "🛡️ 机场安全透视已启动",
			Text = IsMobile 
				and "📱 点击屏幕上的绿色悬浮按钮打开菜单\n🔄 用Toggle开关控制透视"
				or "💻 RightShift = 开/关菜单\n🔘 F4 = 切换透视\n📌 右侧黑色滑块可拖拽滚动",
			Duration = 10,
		})
	end)
	if not success then
		-- 备用方案：使用普通通知
		local notifyGui = Instance.new("ScreenGui")
		notifyGui.Name = "StartupNotify"
		notifyGui.ResetOnSpawn = false
		notifyGui.Parent = CoreGui
		
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0, 320, 0, 180)
		frame.Position = UDim2.new(0.5, -160, 0.5, -90)
		frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 0.15
		local fc = Instance.new("UICorner", frame)
		fc.CornerRadius = UDim.new(0, 12)
		
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -20, 0, 35)
		titleLbl.Position = UDim2.new(0, 10, 0, 10)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = "🛡️ 机场安全透视已启动"
		titleLbl.TextColor3 = Color3.fromRGB(0, 255, 150)
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextSize = 18
		titleLbl.Parent = frame
		
		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(1, -20, 0, 100)
		descLbl.Position = UDim2.new(0, 10, 0, 50)
		descLbl.BackgroundTransparency = 1
		descLbl.Text = IsMobile 
			and "📱 点击绿色悬浮按钮打开菜单"
			or "💻 RightShift = 菜单\n🔘 F4 = 透视开关\n📌 右侧黑色滑块可拖拽"
		descLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
		descLbl.Font = Enum.Font.Gotham
		descLbl.TextSize = 15
		descLbl.TextXAlignment = Enum.TextXAlignment.Center
		descLbl.Parent = frame
		
		-- 3秒后自动消失
		coroutine.wrap(function()
			task.wait(5)
			for i = 1, 20 do
				frame.BackgroundTransparency = frame.BackgroundTransparency + 0.05
				titleLbl.TextTransparency = titleLbl.TextTransparency + 0.05
				descLbl.TextTransparency = descLbl.TextTransparency + 0.05
				task.wait(0.03)
			end
			notifyGui:Destroy()
		end)()
		
		frame.Parent = notifyGui
	end
end

-- ===== 创建自定义滑块（可左键拖拽，像QQ聊天右侧滑块） =====
local ScrollBar = {}
function ScrollBar:AttachToWindow(window)
	-- 等待窗口加载完毕
	task.spawn(function()
		local success = false
		local contentFrame = nil
		
		-- 不断尝试找到窗口的内容滚动区域
		for i = 1, 50 do
			task.wait(0.1)
			-- 搜索窗口下的 ScrollingFrame
			local windowObj = window._Object or window.Window or window.Instance
			if windowObj and windowObj.Parent then
				for _, descendant in ipairs(windowObj:GetDescendants()) do
					if descendant:IsA("ScrollingFrame") and descendant.AbsoluteSize.Y > 0 then
						contentFrame = descendant
						success = true
						break
					end
				end
			end
		end
		
		if not success or not contentFrame then
			warning("未找到窗口滚动区域")
			return
		end
		
		-- 设置滚动条宽度变大（方便鼠标拖拽）
		contentFrame.ScrollBarThickness = 12
		contentFrame.ScrollBarImageColor3 = Color3.fromRGB(40, 40, 50)
		contentFrame.BottomImage = "rbxasset://textures/ui/ScrollBar/scrollbar.png"
		contentFrame.TopImage = "rbxasset://textures/ui/ScrollBar/scrollbar.png"
		contentFrame.MidImage = "rbxasset://textures/ui/ScrollBar/scrollbar.png"
		contentFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
		
		-- 额外创建一个粗的滑块遮罩，确保可点击区域足够大
		local parentFrame = contentFrame.Parent
		if parentFrame then
			local scrollOverlay = Instance.new("Frame")
			scrollOverlay.Name = "ScrollDragOverlay"
			scrollOverlay.Size = UDim2.new(0, 14, 1, 0)
			scrollOverlay.Position = UDim2.new(1, -16, 0, 0)
			scrollOverlay.BackgroundTransparency = 1
			scrollOverlay.BorderSizePixel = 0
			scrollOverlay.ZIndex = 100
			scrollOverlay.Parent = parentFrame
			
			-- 滑块指示条（黑色半透明，像QQ那种）
			local scrollIndicator = Instance.new("Frame")
			scrollIndicator.Name = "ScrollIndicator"
			scrollIndicator.Size = UDim2.new(1, -4, 0, 60)
			scrollIndicator.Position = UDim2.new(0, 2, 0, 0)
			scrollIndicator.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
			scrollIndicator.BackgroundTransparency = 0.4
			scrollIndicator.BorderSizePixel = 0
			scrollIndicator.ZIndex = 101
			local sic = Instance.new("UICorner", scrollIndicator)
			sic.CornerRadius = UDim.new(0, 6)
			scrollIndicator.Parent = scrollOverlay
			
			-- 更新滑块位置
			local function updateIndicator()
				local canvasSize = contentFrame.CanvasSize.Y
				local frameSize = contentFrame.AbsoluteWindowSize.Y
				if canvasSize <= frameSize then
					scrollIndicator.Visible = false
					return
				end
				scrollIndicator.Visible = true
				
				local scrollPercent = contentFrame.ScrollBarPosition / (canvasSize - frameSize)
				if scrollPercent ~= scrollPercent then scrollPercent = 0 end -- NaN check
				
				local indicatorHeight = math.max(30, (frameSize / canvasSize) * contentFrame.AbsoluteSize.Y)
				local maxOffset = contentFrame.AbsoluteSize.Y - indicatorHeight
				scrollIndicator.Size = UDim2.new(1, -4, 0, indicatorHeight)
				scrollIndicator.Position = UDim2.new(0, 2, 0, math.clamp(scrollPercent * maxOffset, 0, maxOffset))
			end
			
			-- 拖拽功能
			local dragging = false
			local dragStart = nil
			local indicatorStart = nil
			
			scrollIndicator.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					dragStart = input.Position
					indicatorStart = scrollIndicator.Position
					scrollIndicator.BackgroundTransparency = 0.2
				end
			end)
			
			local inputConnection
			inputConnection = UserInputService.InputChanged:Connect(function(input)
				if not dragging then return end
				if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
				
				local delta = input.Position - dragStart
				local maxOffset = contentFrame.AbsoluteSize.Y - scrollIndicator.AbsoluteSize.Y
				local newY = math.clamp(indicatorStart.Y.Offset + delta.Y, 0, maxOffset)
				
				-- 映射到滚动位置
				local canvasSize = contentFrame.CanvasSize.Y
				local frameSize = contentFrame.AbsoluteWindowSize.Y
				local scrollPercent = newY / maxOffset
				local targetScroll = scrollPercent * (canvasSize - frameSize)
				
				-- 使用 CanvasPosition
				contentFrame.CanvasPosition = Vector2.new(0, math.clamp(targetScroll, 0, canvasSize - frameSize))
			end)
			
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
					scrollIndicator.BackgroundTransparency = 0.4
				end
			end)
			
			-- 监听滚动变化
			contentFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(updateIndicator)
			contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateIndicator)
			contentFrame:GetPropertyChangedSignal("CanvasSize"):Connect(updateIndicator)
			
			task.wait(1)
			updateIndicator()
		end
	end)
end

-- ===== 加载主流程 =====
local function startScript()
	-- ===== 状态变量 =====
	local Settings = {
		Enabled = true,
		ShowBadOnly = false,
		ShowDistance = true,
		ShowHealth = true,
		MaxDistance = 500,
		BoxColor_Good = Color3.fromRGB(0, 255, 100),
		BoxColor_Bad = Color3.fromRGB(255, 50, 50),
		BoxColor_Unknown = Color3.fromRGB(255, 255, 255),
	}

	local ESPObjects = {}

	-- ===== 创建窗口 =====
	local Window = WindUI:CreateWindow({
		Title = "机场安全透视",
		Author = "Airport Security",
		Folder = "airport_security_esp",
		Icon = "solar:shield-warning-bold",
		Theme = "Dark",
		Size = UDim2.fromOffset(650, 480),
		MinSize = Vector2.new(IsMobile and 380 or 560, 350),
		MaxSize = Vector2.new(850, 560),
		ToggleKey = IsMobile and nil or Enum.KeyCode.RightShift,
		Resizable = true,
		NewElements = true,
		HideSearchBar = false,
		SideBarWidth = IsMobile and 160 or 200,
		Topbar = {
			Height = IsMobile and 38 or 44,
			ButtonsType = "Mac",
		},
		OpenButton = {
			Title = "打开透视",
			CornerRadius = UDim.new(1, 0),
			StrokeThickness = 3,
			Enabled = true,
			Draggable = true,
			OnlyMobile = false,
			Scale = IsMobile and 0.45 or 0.5,
			Color = ColorSequence.new(
				Color3.fromHex("#30FF6A"),
				Color3.fromHex("#00D4FF")
			),
		},
	})
	
	-- ===== 立即打开窗口（默认开启） =====
	task.spawn(function()
		task.wait(0.5)
		-- 尝试多种方法打开窗口
		local openSuccess = false
		if Window.Toggle then
			pcall(function() Window:Toggle() openSuccess = true end)
		end
		if not openSuccess and Window.Open then
			pcall(function() Window:Open() openSuccess = true end)
		end
		if not openSuccess then
			-- 模拟点击OpenButton
			pcall(function()
				local btn = Window._OpenButton or Window.OpenButtonObj
				if btn and btn:IsA("ImageButton") then
					btn:Click()
				end
			end)
		end
	end)
	
	-- ===== 附加自定义滚动条 =====
	ScrollBar:AttachToWindow(Window)

	-- ===== Roblox原生弹窗提示 =====
	task.spawn(function()
		task.wait(1)
		showNativeNotification()
	end)

	-- ===== Tab 1: 主控面板 =====
	local MainTab = Window:Tab({
		Title = "主控面板",
		Icon = "solar:home-2-bold",
	})

	MainTab:Section({
		Title = "状态控制",
		TextSize = 18,
	})

	MainTab:Toggle({
		Flag = "ESPToggle",
		Title = "透视开关",
		Desc = "开启/关闭所有ESP透视",
		Value = Settings.Enabled,
		Callback = function(state)
			Settings.Enabled = state
			for char, esp in pairs(ESPObjects) do
				if esp.Box then esp.Box.Visible = state end
				if esp.Billboard then esp.Billboard.Enabled = state end
			end
			WindUI:Notify({
				Title = state and "透视已开启" or "透视已关闭",
				Content = state and "开始扫描目标..." or "所有ESP标记已隐藏",
				Icon = state and "solar:eye-bold" or "solar:eye-closed-bold",
				Duration = 3,
			})
		end,
	})

	MainTab:Toggle({
		Flag = "BadOnlyMode",
		Title = "仅显示坏人",
		Desc = "隐藏好人标记，只显示威胁目标",
		Value = Settings.ShowBadOnly,
		Callback = function(state)
			Settings.ShowBadOnly = state
			for char, esp in pairs(ESPObjects) do
				if esp.Box then esp.Box:Destroy() end
				if esp.Billboard then esp.Billboard:Destroy() end
			end
			ESPObjects = {}
			if state then
				WindUI:Notify({
					Title = "模式切换",
					Content = "现在仅显示坏人/威胁目标",
					Icon = "solar:danger-triangle-bold",
					Duration = 3,
				})
			end
		end,
	})

	MainTab:Space()

	MainTab:Section({
		Title = "显示选项",
		TextSize = 18,
	})

	MainTab:Toggle({
		Flag = "ShowDistance",
		Title = "显示距离",
		Desc = "在标记上显示距离（米）",
		Value = Settings.ShowDistance,
		Callback = function(state)
			Settings.ShowDistance = state
		end,
	})

	MainTab:Toggle({
		Flag = "ShowHealth",
		Title = "显示血量",
		Desc = "在标记上显示血量信息",
		Value = Settings.ShowHealth,
		Callback = function(state)
			Settings.ShowHealth = state
		end,
	})

	MainTab:Slider({
		Flag = "MaxDistance",
		Title = "最大探测距离",
		Desc = "单位：米，超出范围不显示 | 可用鼠标左键拖拽滑块",
		Step = 10,
		Value = {
			Min = 50,
			Max = 1000,
			Default = Settings.MaxDistance,
		},
		IsTooltip = true,
		IsTextbox = false,
		Width = IsMobile and 150 or 200,
		Callback = function(value)
			Settings.MaxDistance = value
		end,
	})

	-- ===== Tab 2: 信息统计 =====
	local StatsTab = Window:Tab({
		Title = "信息统计",
		Icon = "solar:chart-2-bold",
	})

	local StatsGroup = StatsTab:Group({})

	local GoodInput = StatsGroup:Input({
		Title = "🟢 好人",
		Value = "0",
		Locked = true,
	})
	StatsGroup:Space()

	local BadInput = StatsGroup:Input({
		Title = "🔴 坏人",
		Value = "0",
		Locked = true,
	})
	StatsGroup:Space()

	local TotalInput = StatsGroup:Input({
		Title = "📊 总数",
		Value = "0",
		Locked = true,
	})

	-- ===== Tab 3: 关于 =====
	local AboutTab = Window:Tab({
		Title = "关于",
		Icon = "solar:info-square-bold",
	})

	AboutTab:Section({
		Title = "机场安全透视系统 v2.0",
		TextSize = 24,
	})

	AboutTab:Section({
		Title = "基于 WindUI 库构建 | 自动区分好人与坏人",
		TextSize = IsMobile and 14 or 16,
		TextTransparency = 0.3,
	})

	AboutTab:Space()

	AboutTab:Paragraph({
		Title = "📖 使用说明",
		Desc = "本脚本自动扫描角色，通过名字/路径检测自动区分好人与坏人。\n\n"
			.. (IsMobile
			and "📱 手机端: 点击悬浮按钮打开菜单，使用Toggle开关控制"
			or "💻 PC端: RightShift = 菜单开关 | F4 = 透视开关"),
	})

	AboutTab:Space()

	AboutTab:Button({
		Title = "GitHub 仓库",
		Icon = "github",
		Color = Color3.fromHex("#1c1c1c"),
		Callback = function()
			WindUI:Notify({
				Title = "GitHub",
				Content = "github.com/mazihao62-beep/airport-security-esp",
				Icon = "github",
				Duration = 5,
			})
		end,
	})

	-- ===== ESP渲染系统 =====
	local function createESP(character, color, label)
		local box = Instance.new("BoxHandleAdornment")
		box.Name = "ESPBox"
		box.AdornCullingMode = Enum.AdornCullingMode.Never
		box.AlwaysOnTop = true
		box.ZIndex = 10
		box.Size = Vector3.new(4, 5, 4)
		box.Color3 = color
		box.Transparency = 0.3
		box.Visible = Settings.Enabled
		box.Parent = character

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ESPTag"
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
		billboard.Enabled = Settings.Enabled
		billboard.Parent = character

		local labelText = Instance.new("TextLabel")
		labelText.Size = UDim2.new(1, 0, 0, 25)
		labelText.BackgroundTransparency = 1
		labelText.Text = label
		labelText.TextColor3 = color
		labelText.TextScaled = true
		labelText.Font = Enum.Font.GothamBold
		labelText.TextStrokeTransparency = 0.3
		labelText.TextStrokeColor3 = Color3.new(0, 0, 0)
		labelText.Parent = billboard

		local infoText = Instance.new("TextLabel")
		infoText.Size = UDim2.new(1, 0, 0, 20)
		infoText.Position = UDim2.new(0, 0, 0, 25)
		infoText.BackgroundTransparency = 1
		infoText.Text = ""
		infoText.TextColor3 = Color3.fromRGB(200, 200, 200)
		infoText.TextScaled = true
		infoText.Font = Enum.Font.Gotham
		infoText.TextStrokeTransparency = 0.4
		infoText.TextStrokeColor3 = Color3.new(0, 0, 0)
		infoText.Parent = billboard

		return {Box = box, Billboard = billboard, Label = labelText, Info = infoText}
	end

	local function removeESP(character)
		local box = character:FindFirstChild("ESPBox")
		local billboard = character:FindFirstChild("ESPTag")
		if box then box:Destroy() end
		if billboard then billboard:Destroy() end
		ESPObjects[character] = nil
	end

	-- ===== NPC类型判断 =====
	local function classifyCharacter(character)
		local name = character.Name or ""

		local parent = character.Parent
		while parent do
			local pName = parent.Name
			if pName == "AgentTemplate" then
				return "Good", Settings.BoxColor_Good, "👮 Agent"
			elseif pName == "NPCTemplate" then
				return "Bad", Settings.BoxColor_Bad, "💀 Threat"
			end
			parent = parent.Parent
		end

		if name:match("^Agent") or name:match("Police") or name:match("Guard") or name:match("Security") then
			return "Good", Settings.BoxColor_Good, "👮 Agent"
		elseif name:match("^NPC") or name:match("Terrorist") or name:match("Suspect") or name:match("Enemy") or name:match("Hostile") or name:match("Criminal") or name:match("Threat") or name:match("Bad") then
			return "Bad", Settings.BoxColor_Bad, "💀 Threat"
		end

		local foundAgent = false
		local foundNPC = false
		for _, child in ipairs(character:GetDescendants()) do
			if child:IsA("ModuleScript") or child:IsA("LocalScript") then
				local cPath = child:GetFullName()
				if cPath:find("AgentTemplate") then
					foundAgent = true
				elseif cPath:find("NPCTemplate") then
					foundNPC = true
				end
			end
		end

		if foundAgent and not foundNPC then
			return "Good", Settings.BoxColor_Good, "👮 Agent"
		elseif foundNPC and not foundAgent then
			return "Bad", Settings.BoxColor_Bad, "💀 Threat"
		elseif foundAgent and foundNPC then
			return "Bad", Settings.BoxColor_Bad, "💀 Threat"
		end

		return nil
	end

	-- ===== 更新ESP =====
	local function updateESP()
		local badCount = 0
		local goodCount = 0

		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj == LocalPlayer.Character then continue end

			local humanoid = obj:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				if ESPObjects[obj] then removeESP(obj) end
				continue
			end

			local npcType, color, label = classifyCharacter(obj)
			if not npcType then
				if ESPObjects[obj] then removeESP(obj) end
				continue
			end

			if Settings.ShowBadOnly and npcType ~= "Bad" then
				if ESPObjects[obj] then removeESP(obj) end
				continue
			end

			if npcType == "Bad" then badCount = badCount + 1 end
			if npcType == "Good" then goodCount = goodCount + 1 end

			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
				local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if root and myRoot then
					local dist = (root.Position - myRoot.Position).Magnitude
					if dist > Settings.MaxDistance then
						if ESPObjects[obj] then removeESP(obj) end
						continue
					end
				end
			end

			if not ESPObjects[obj] then
				ESPObjects[obj] = createESP(obj, color, label or "")
			else
				ESPObjects[obj].Box.Color3 = color
				ESPObjects[obj].Label.TextColor3 = color
				ESPObjects[obj].Label.Text = label or ""
			end

			if ESPObjects[obj] and ESPObjects[obj].Info then
				local distText = ""
				local healthText = ""
				local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
				local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

				if root and myRoot and Settings.ShowDistance then
					distText = math.floor((root.Position - myRoot.Position).Magnitude) .. "m"
				end
				if Settings.ShowHealth then
					healthText = "HP: " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
				end

				local infoParts = {}
				if distText ~= "" then table.insert(infoParts, distText) end
				if healthText ~= "" then table.insert(infoParts, healthText) end
				ESPObjects[obj].Info.Text = table.concat(infoParts, " | ")

				ESPObjects[obj].Box.Visible = Settings.Enabled
				ESPObjects[obj].Billboard.Enabled = Settings.Enabled
			end
		end

		for char, esp in pairs(ESPObjects) do
			if not char.Parent then
				removeESP(char)
			end
		end

		-- 更新统计UI
		if GoodInput then pcall(function() GoodInput:Set(tostring(goodCount)) end) end
		if BadInput then pcall(function() BadInput:Set(tostring(badCount)) end) end
		if TotalInput then pcall(function() TotalInput:Set(tostring(goodCount + badCount)) end) end
	end

	-- ===== 主循环 =====
	RunService.RenderStepped:Connect(function()
		if Settings.Enabled then
			updateESP()
		end
	end)

	-- ===== 玩家退出清理 =====
	Players.PlayerRemoving:Connect(function()
		for char, esp in pairs(ESPObjects) do
			removeESP(char)
		end
	end)

	-- ===== F4 热键（仅PC） =====
	if not IsMobile then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == Enum.KeyCode.F4 then
				Settings.Enabled = not Settings.Enabled
				for char, esp in pairs(ESPObjects) do
					if esp.Box then esp.Box.Visible = Settings.Enabled end
					if esp.Billboard then esp.Billboard.Enabled = Settings.Enabled end
				end
			end
		end)
	end

	print("🛡️ 机场安全透视脚本 v2.0 已加载! (WindUI)")
	print(IsMobile and "📱 手机模式: 点击悬浮按钮打开" or "💻 PC模式: RightShift = 菜单 | F4 = 透视开关")
end

-- ===== 流程启动：确认对话框 → 加载 → 通知 =====
showConfirmation(function(confirmed)
	if confirmed then
		startScript()
	else
		WindUI:Notify({
			Title = "已取消加载",
			Content = "机场安全透视脚本已取消。如需重新加载，请重新执行脚本。",
			Icon = "solar:info-circle-bold",
			Duration = 4,
		})
	end
end)
