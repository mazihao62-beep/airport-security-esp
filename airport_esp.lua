--[[
	机场安全透视脚本 v3.0 (Airport Security ESP)
	使用 WindUI 库制作界面
	功能：透视 + 头顶标签区分好人与坏人
	
	修复问题：
	- ✅ 使用 Highlight 替代 BoxHandleAdornment（更稳定可见）
	- ✅ 头顶标签（显示名字+类型+血量+距离）
	- ✅ 更广的NPC搜索范围
	- ✅ 跳过确认弹窗直接运行（避免回调问题）
	- ✅ 错误保护，防止崩溃
--]]

-- ===== 安全加载 =====
local Success, WindUI = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not Success or not WindUI then
	-- WindUI 加载失败，使用纯原生UI
	print("⚠️ WindUI 加载失败，使用原生UI模式")
	
	-- 原生模式脚本（简化的ESP）
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")
	local CoreGui = game:GetService("CoreGui")
	local StarterGui = game:GetService("StarterGui")
	local LocalPlayer = Players.LocalPlayer
	
	local ESPEnabled = true
	local MaxDistance = 500
	
	-- 创建UI
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "AirportESPGui"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Parent = CoreGui
	
	local MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, 200, 0, 120)
	MainFrame.Position = UDim2.new(0, 10, 0.5, -60)
	MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	MainFrame.BackgroundTransparency = 0.2
	MainFrame.BorderSizePixel = 0
	local MFC = Instance.new("UICorner", MainFrame)
	MFC.CornerRadius = UDim.new(0, 8)
	MainFrame.Parent = ScreenGui
	
	local Toggle = Instance.new("TextButton")
	Toggle.Size = UDim2.new(1, -20, 0, 36)
	Toggle.Position = UDim2.new(0, 10, 0, 10)
	Toggle.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
	Toggle.Text = "透视: ON"
	Toggle.TextColor3 = Color3.new(1, 1, 1)
	Toggle.Font = Enum.Font.GothamBold
	Toggle.TextSize = 16
	local TC = Instance.new("UICorner", Toggle)
	TC.CornerRadius = UDim.new(0, 6)
	Toggle.Parent = MainFrame
	
	Toggle.MouseButton1Click:Connect(function()
		ESPEnabled = not ESPEnabled
		Toggle.Text = ESPEnabled and "透视: ON" or "透视: OFF"
		Toggle.BackgroundColor3 = ESPEnabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
	end)
	
	-- 通知
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "🛡️ 机场透视已启动",
			Text = "左侧面板控制开关 | 头顶显示标签",
			Duration = 8,
		})
	end)
	
	-- 创建ESP
	local ESPData = {}
	
	local function createHeadLabel(char, color, mainLabel)
		local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
		if not head then return nil end
		
		-- 头顶标签
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "HeadESP"
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.new(0, 180, 0, 60)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.Adornee = head
		billboard.Enabled = ESPEnabled
		billboard.Parent = head
		
		local mainLbl = Instance.new("TextLabel")
		mainLbl.Size = UDim2.new(1, 0, 0, 28)
		mainLbl.BackgroundTransparency = 1
		mainLbl.Text = mainLabel
		mainLbl.TextColor3 = color
		mainLbl.Font = Enum.Font.GothamBold
		mainLbl.TextSize = 18
		mainLbl.TextStrokeTransparency = 0.2
		mainLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
		mainLbl.Parent = billboard
		
		local infoLbl = Instance.new("TextLabel")
		infoLbl.Size = UDim2.new(1, 0, 0, 20)
		infoLbl.Position = UDim2.new(0, 0, 0, 28)
		infoLbl.BackgroundTransparency = 1
		infoLbl.Text = ""
		infoLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
		infoLbl.Font = Enum.Font.Gotham
		infoLbl.TextSize = 14
		infoLbl.TextStrokeTransparency = 0.3
		infoLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
		infoLbl.Parent = billboard
		
		return billboard, mainLbl, infoLbl
	end
	
	local function createHighlight(char, color)
		local highlight = Instance.new("Highlight")
		highlight.Name = "ESP_Highlight"
		highlight.Adornee = char
		highlight.FillColor = color
		highlight.FillTransparency = 0.5
		highlight.OutlineColor = color
		highlight.OutlineTransparency = 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Enabled = ESPEnabled
		highlight.Parent = char
		return highlight
	end
	
	local function classifyChar(char)
		local name = char.Name or ""
		
		-- 检查父级路径
		local parent = char.Parent
		while parent do
			local pn = parent.Name
			if pn == "AgentTemplate" or pn == "Agent" then
				return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
			elseif pn == "NPCTemplate" or pn == "NPC" then
				return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
			end
			parent = parent.Parent
		end
		
		-- 按名字检测
		local goodNames = {"Agent", "Police", "Guard", "Security", "Friendly", "Good", "Cop", "Sniper", "SWAT"}
		local badNames = {"NPC", "Terrorist", "Suspect", "Enemy", "Hostile", "Criminal", "Threat", "Bad", "Bandit", "Robber", "Bomb", "Rogue"}
		
		for _, gName in ipairs(goodNames) do
			if name:find(gName) then
				return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
			end
		end
		
		for _, bName in ipairs(badNames) do
			if name:find(bName) then
				return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
			end
		end
		
		-- 检查路径中的关键字
		local fullPath = char:GetFullName()
		if fullPath:find("AgentTemplate") or fullPath:find("Agent") then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		elseif fullPath:find("NPCTemplate") or fullPath:find("NPC") then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		end
		
		-- 检查有无 Gun_Settings 及其类型
		local hasGun = false
		local hasBadScript = false
		local hasGoodScript = false
		for _, child in ipairs(char:GetDescendants()) do
			if child:IsA("ModuleScript") and child.Name:find("Gun_Settings") then
				hasGun = true
			end
			local cPath = child:GetFullName()
			if cPath:find("NPCTemplate") then hasBadScript = true end
			if cPath:find("AgentTemplate") then hasGoodScript = true end
		end
		
		if hasBadScript and not hasGoodScript then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		elseif hasGoodScript and not hasBadScript then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		end
		
		return nil
	end
	
	-- 扫描函数
	local function scanNPCs()
		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj == LocalPlayer.Character then continue end
			if ESPData[obj] then continue end
			
			local humanoid = obj:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then continue end
			
			local npcType, color, label = classifyChar(obj)
			if not npcType then continue end
			
			-- 创建 Highlight
			local hl = createHighlight(obj, color)
			local bb, mainLbl, infoLbl = createHeadLabel(obj, color, label)
			
			if bb then
				ESPData[obj] = {
					Highlight = hl,
					Billboard = bb,
					MainLabel = mainLbl,
					InfoLabel = infoLbl,
					NPCType = npcType,
					Color = color,
					Label = label,
					Humanoid = humanoid,
				}
			end
		end
		
		-- 清理已移除的对象
		for obj, data in pairs(ESPData) do
			if not obj.Parent or not obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid").Health <= 0 then
				if data.Highlight then data.Highlight:Destroy() end
				if data.Billboard then data.Billboard:Destroy() end
				ESPData[obj] = nil
			end
		end
	end
	
	-- 更新信息
	local function updateInfo()
		if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
		local myRoot = LocalPlayer.Character.HumanoidRootPart
		
		for obj, data in pairs(ESPData) do
			if data.Billboard and data.InfoLabel then
				local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
				local distText = ""
				local healthText = ""
				
				if root then
					distText = math.floor((root.Position - myRoot.Position).Magnitude) .. "m"
				end
				healthText = "HP: " .. math.floor(data.Humanoid.Health) .. "/" .. math.floor(data.Humanoid.MaxHealth)
				
				data.InfoLabel.Text = distText .. " | " .. healthText
				data.Billboard.Enabled = ESPEnabled
			end
			if data.Highlight then
				data.Highlight.Enabled = ESPEnabled
			end
		end
	end
	
	-- 主循环
	task.spawn(function()
		while task.wait(0.3) do
			pcall(function()
				scanNPCs()
				updateInfo()
			end)
		end
	end)
	
	-- 热键
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.F4 then
			ESPEnabled = not ESPEnabled
			Toggle.Text = ESPEnabled and "透视: ON" or "透视: OFF"
			Toggle.BackgroundColor3 = ESPEnabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
		end
	end)
	
	print("✅ 机场安全透视 v3.0 (原生模式) 已加载!")
	print("F4 = 开关透视 | 左侧面板控制")
	return
end

-- ===== 以下是 WindUI 模式 =====
print("✅ WindUI 加载成功! 启动完整版...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ===== 状态变量 =====
local Settings = {
	Enabled = true,
	ShowBadOnly = false,
	ShowDistance = true,
	ShowHealth = true,
	MaxDistance = 500,
	BoxColor_Good = Color3.fromRGB(0, 255, 100),
	BoxColor_Bad = Color3.fromRGB(255, 50, 50),
}

local ESPData = {}

-- ===== 显示原生通知 =====
pcall(function()
	StarterGui:SetCore("SendNotification", {
		Title = "🛡️ 机场安全透视已启动",
		Text = IsMobile and "📱 点击绿色悬浮按钮打开菜单" or "💻 RightShift = 菜单 | F4 = 透视开关",
		Duration = 10,
	})
end)

-- ===== 创建窗口 =====
local Window = WindUI:CreateWindow({
	Title = "机场安全透视",
	Author = "Airport Security",
	Folder = "airport_security_esp",
	Icon = "solar:shield-warning-bold",
	Theme = "Dark",
	Size = UDim2.fromOffset(IsMobile and 400 or 650, 480),
	MinSize = Vector2.new(IsMobile and 350 or 560, 350),
	MaxSize = Vector2.new(IsMobile and 500 or 850, 560),
	ToggleKey = IsMobile and nil or Enum.KeyCode.RightShift,
	Resizable = true,
	NewElements = true,
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
		Scale = IsMobile and 0.45 or 0.5,
		Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#00D4FF")),
	},
})

-- ===== 强制打开窗口 =====
task.spawn(function()
	task.wait(1)
	local opened = false
	-- 尝试多种方法
	if Window.Toggle then
		pcall(function() Window:Toggle() opened = true end)
	end
	if not opened and Window.Open then
		pcall(function() Window:Open() opened = true end)
	end
	if not opened then
		pcall(function()
			local btn = Window._OpenButton or Window.OpenButtonObj
			if btn then btn:Click() end
		end)
	end
end)

-- ===== 给窗口加粗的滚动条（鼠标左键拖拽） =====
task.spawn(function()
	task.wait(2)
	local found = false
	for _ = 1, 30 do
		task.wait(0.1)
		if not Window._Object and not Window.Window and not Window.Instance then break end
		local obj = Window._Object or Window.Window or Window.Instance
		for _, desc in ipairs(obj:GetDescendants()) do
			if desc:IsA("ScrollingFrame") and desc.AbsoluteSize.Y > 0 then
				desc.ScrollBarThickness = 12
				desc.VerticalScrollBarInset = Enum.ScrollBarInset.Always
				found = true
				break
			end
		end
		if found then break end
	end
end)

-- ===== Tab 1: 主控面板 =====
local MainTab = Window:Tab({
	Title = "主控面板",
	Icon = "solar:home-2-bold",
})

MainTab:Section({ Title = "状态控制", TextSize = 18 })

MainTab:Toggle({
	Flag = "ESPToggle",
	Title = "透视开关",
	Desc = "开启/关闭所有ESP透视",
	Value = Settings.Enabled,
	Callback = function(state)
		Settings.Enabled = state
		for obj, data in pairs(ESPData) do
			if data.Highlight then data.Highlight.Enabled = state end
			if data.Billboard then data.Billboard.Enabled = state end
		end
		WindUI:Notify({
			Title = state and "透视已开启" or "透视已关闭",
			Content = state and "开始扫描目标..." or "所有标记已隐藏",
			Icon = state and "solar:eye-bold" or "solar:eye-closed-bold",
			Duration = 3,
		})
	end,
})

MainTab:Toggle({
	Flag = "BadOnlyMode",
	Title = "仅显示坏人",
	Desc = "隐藏好人标记，只显示威胁目标",
	Value = false,
	Callback = function(state)
		Settings.ShowBadOnly = state
		-- 清除所有并重建
		for obj, data in pairs(ESPData) do
			if data.Highlight then data.Highlight:Destroy() end
			if data.Billboard then data.Billboard:Destroy() end
		end
		ESPData = {}
	end,
})

MainTab:Space()
MainTab:Section({ Title = "显示选项", TextSize = 18 })

MainTab:Toggle({
	Flag = "ShowDist",
	Title = "显示距离",
	Desc = "在头顶标签上显示距离",
	Value = true,
	Callback = function(state) Settings.ShowDistance = state end,
})

MainTab:Toggle({
	Flag = "ShowHP",
	Title = "显示血量",
	Desc = "在头顶标签上显示血量",
	Value = true,
	Callback = function(state) Settings.ShowHealth = state end,
})

MainTab:Slider({
	Flag = "MaxDist",
	Title = "最大探测距离",
	Desc = "单位：米 | 可用鼠标拖拽",
	Step = 10,
	Value = { Min = 50, Max = 1000, Default = 500 },
	IsTooltip = true,
	Width = IsMobile and 150 or 200,
	Callback = function(v) Settings.MaxDistance = v end,
})

-- ===== Tab 2: 统计 =====
local StatsTab = Window:Tab({
	Title = "信息统计",
	Icon = "solar:chart-2-bold",
})

local SG = StatsTab:Group({})
local GoodInput = SG:Input({ Title = "🟢 好人", Value = "0", Locked = true })
SG:Space()
local BadInput = SG:Input({ Title = "🔴 坏人", Value = "0", Locked = true })
SG:Space()
local TotalInput = SG:Input({ Title = "📊 总数", Value = "0", Locked = true })

-- ===== Tab 3: 关于 =====
local AboutTab = Window:Tab({
	Title = "关于",
	Icon = "solar:info-square-bold",
})

AboutTab:Section({ Title = "机场安全透视系统 v3.0", TextSize = 24 })
AboutTab:Section({ Title = "基于 WindUI 构建 | 自动识别好/坏人", TextSize = IsMobile and 14 or 16, TextTransparency = 0.3 })
AboutTab:Space()
AboutTab:Paragraph({
	Title = "📖 使用说明",
	Desc = IsMobile
		and "📱 点击绿色悬浮按钮 -> 打开菜单\nToggle开关控制透视"
		and "💻 RightShift = 菜单\nF4 = 透视开关\n🖱 右侧滑块可拖拽"
		or "💻 RightShift = 菜单 | F4 = 透视开关\n🖱 右侧黑色滑块可拖拽滚动",
})

-- ===== ESP函数 =====

-- 创建头顶标签
local function createHeadLabel(char, color, mainText)
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return nil, nil, nil end
	
	local bb = Instance.new("BillboardGui")
	bb.Name = "ESP_HeadTag"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 200, 0, 65)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.Adornee = head
	bb.Enabled = Settings.Enabled
	bb.ClipsDescendants = false
	bb.Parent = head
	
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	local bgc = Instance.new("UICorner", bg)
	bgc.CornerRadius = UDim.new(0, 6)
	bg.Parent = bb
	
	local mainLbl = Instance.new("TextLabel")
	mainLbl.Size = UDim2.new(1, -8, 0, 30)
	mainLbl.Position = UDim2.new(0, 4, 0, 3)
	mainLbl.BackgroundTransparency = 1
	mainLbl.Text = mainText
	mainLbl.TextColor3 = color
	mainLbl.Font = Enum.Font.GothamBold
	mainLbl.TextSize = 16
	mainLbl.TextStrokeTransparency = 0
	mainLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	mainLbl.TextXAlignment = Enum.TextXAlignment.Center
	mainLbl.Parent = bb
	
	local infoLbl = Instance.new("TextLabel")
	infoLbl.Size = UDim2.new(1, -8, 0, 22)
	infoLbl.Position = UDim2.new(0, 4, 0, 33)
	infoLbl.BackgroundTransparency = 1
	infoLbl.Text = ""
	infoLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
	infoLbl.Font = Enum.Font.Gotham
	infoLbl.TextSize = 12
	infoLbl.TextStrokeTransparency = 0.2
	infoLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	infoLbl.TextXAlignment = Enum.TextXAlignment.Center
	infoLbl.Parent = bb
	
	return bb, mainLbl, infoLbl
end

-- 创建 Highlight
local function createHighlight(char, color)
	local hl = Instance.new("Highlight")
	hl.Name = "ESP_Highlight"
	hl.Adornee = char
	hl.FillColor = color
	hl.FillTransparency = 0.5
	hl.OutlineColor = color
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = Settings.Enabled
	hl.Parent = char
	return hl
end

-- 多级NPC类型识别
local function classifyCharacter(char)
	local name = char.Name or ""
	
	-- 1) 检查父级
	local p = char.Parent
	while p do
		if p.Name == "AgentTemplate" or p.Name == "Agent" or p.Name == "Good" then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		elseif p.Name == "NPCTemplate" or p.Name == "NPC" or p.Name == "Bad" or p.Name == "Enemy" then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		end
		p = p.Parent
	end
	
	-- 2) 名字匹配
	local goodPatterns = {"^Agent", "Police", "Guard", "Security", "Friendly", "Cop", "SWAT", "Sniper", "Good"}
	local badPatterns = {"NPC", "Terrorist", "Suspect", "Enemy", "Hostile", "Criminal", "Threat", "Bad", "Bandit", "Robber", "Rogue", "Bomber", "Invader"}
	
	for _, pat in ipairs(goodPatterns) do
		if name:find(pat) then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		end
	end
	for _, pat in ipairs(badPatterns) do
		if name:find(pat) then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		end
	end
	
	-- 3) 路径检查
	local fullPath = char:GetFullName()
	if fullPath:find("AgentTemplate") or fullPath:find("Agent") or fullPath:find("Good") then
		return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
	elseif fullPath:find("NPCTemplate") or fullPath:find("NPC") or fullPath:find("Enemy") or fullPath:find("Bad") then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
	end
	
	-- 4) Descendant模块扫描
	local hasAgentScript, hasNPCScript = false, false
	for _, child in ipairs(char:GetDescendants()) do
		local cPath = child:GetFullName()
		if cPath:find("AgentTemplate") then hasAgentScript = true end
		if cPath:find("NPCTemplate") then hasNPCScript = true end
	end
	
	if hasNPCScript and not hasAgentScript then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
	elseif hasAgentScript and not hasNPCScript then
		return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
	elseif hasAgentScript and hasNPCScript then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
	end
	
	-- 5) 无法识别 - 也显示为白色未知
	return "Unknown", Color3.fromRGB(200, 200, 200), "❓ Unknown"
end

-- 扫描函数
local function scanCharacters()
	local scanned = {} -- track what we've seen
	
	-- 搜索范围：Workspace直接子级 + 更深层级
	local searchRoots = {Workspace}
	-- 检查特殊文件夹
	local wsScriptable = Workspace:FindFirstChild("WorkspaceScriptable")
	if wsScriptable then table.insert(searchRoots, wsScriptable) end
	
	for _, root in ipairs(searchRoots) do
		for _, obj in ipairs(root:GetChildren()) do
			if obj == LocalPlayer.Character then continue end
			if ESPData[obj] then 
				scanned[obj] = true
				continue 
			end
			
			local humanoid = obj:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then continue end
			
			local npcType, color, label = classifyCharacter(obj)
			if Settings.ShowBadOnly and npcType ~= "Bad" then continue end
			
			-- 距离检测
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
				local myRoot = LocalPlayer.Character.HumanoidRootPart
				if root and myRoot then
					local dist = (root.Position - myRoot.Position).Magnitude
					if dist > Settings.MaxDistance then continue end
				end
			end
			
			-- 创建ESP
			local hl = createHighlight(obj, color)
			local bb, mainLbl, infoLbl = createHeadLabel(obj, color, label)
			
			if bb then
				ESPData[obj] = {
					Highlight = hl,
					Billboard = bb,
					MainLabel = mainLbl,
					InfoLabel = infoLbl,
					NPCType = npcType,
					Humanoid = humanoid,
				}
				scanned[obj] = true
			end
		end
	end
	
	-- 清理已移除的对象
	for obj, data in pairs(ESPData) do
		if not scanned[obj] or not obj.Parent then
			if data.Highlight then data.Highlight:Destroy() end
			if data.Billboard then data.Billboard:Destroy() end
			ESPData[obj] = nil
		end
	end
end

-- 更新信息
local function updateESPInfo()
	if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
	local myRoot = LocalPlayer.Character.HumanoidRootPart
	
	local goodCount = 0
	local badCount = 0
	
	for obj, data in pairs(ESPData) do
		if not obj.Parent then continue end
		
		if data.NPCType == "Good" then goodCount = goodCount + 1 end
		if data.NPCType == "Bad" then badCount = badCount + 1 end
		
		if data.Billboard and data.InfoLabel then
			local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
			local distText = ""
			local healthText = ""
			
			if root and Settings.ShowDistance then
				distText = math.floor((root.Position - myRoot.Position).Magnitude) .. "m"
			end
			if Settings.ShowHealth then
				healthText = "HP: " .. math.floor(data.Humanoid.Health) .. "/" .. math.floor(data.Humanoid.MaxHealth)
			end
			
			local parts = {}
			if distText ~= "" then table.insert(parts, distText) end
			if healthText ~= "" then table.insert(parts, healthText) end
			data.InfoLabel.Text = table.concat(parts, " | ")
			
			data.Billboard.Enabled = Settings.Enabled
		end
		
		if data.Highlight then
			data.Highlight.Enabled = Settings.Enabled
		end
	end
	
	-- 更新统计
	pcall(function()
		GoodInput:Set(tostring(goodCount))
		BadInput:Set(tostring(badCount))
		TotalInput:Set(tostring(goodCount + badCount))
	end)
end

-- ===== 主循环 =====
task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			scanCharacters()
			updateESPInfo()
		end)
	end
end)

-- ===== F4 热键 =====
if not IsMobile then
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.F4 then
			Settings.Enabled = not Settings.Enabled
		end
	end)
end

-- ===== 玩家离开清理 =====
Players.PlayerRemoving:Connect(function()
	for obj, data in pairs(ESPData) do
		if data.Highlight then data.Highlight:Destroy() end
		if data.Billboard then data.Billboard:Destroy() end
	end
	ESPData = {}
end)

print("✅ 机场安全透视 v3.0 已加载!")
print(IsMobile and "📱 手机模式" or "💻 PC模式: RightShift=菜单 | F4=透视")
print("👁 检测范围: Workspace + WorkspaceScriptable")
print("🏷 头顶标签 + Highlight 已启用")
