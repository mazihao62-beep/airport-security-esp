--[[
	机场安全透视脚本 v5.2 (Airport Security ESP)
	作者: b站英吉利超入_
	
	更新日志:
	v5.2 - 默认RightShift开关窗口,彻底解决闪烁问题
	  🐛 问题: 窗口闪一下消失
	  🔧 方案: ToggleKey = RightShift,窗口默认隐藏
	  ✅ 其他快捷键仍为None,用户自行配置
	  📱 手机端保留手工悬浮按钮
	v5.1 - 修复窗口闪一下后自动最小化
	v5.0 - 自定义快捷键系统 + 全面Bug修复
--]]

-- ========================================================================
-- ==================== 第一步：加载WindUI ================================
-- ========================================================================

local Success, WindUI = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not Success or not WindUI then
	-- ===== WindUI加载失败 → 原生模式 =====
	local StarterGui = game:GetService("StarterGui")
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local CoreGui = game:GetService("CoreGui")
	local UserInputService = game:GetService("UserInputService")
	local LocalPlayer = Players.LocalPlayer
	
	local msg = Instance.new("Message")
	msg.Text = "🛡️ 机场安全透视 - 加载中... (WindUI加载失败,使用原生模式)"
	msg.Parent = CoreGui
	task.wait(1)
	msg:Destroy()
	
	local ESPData = {}
	local ESPEnabled = true
	local MaxDistance = 500
	
	StarterGui:SetCore("SendNotification", {
		Title = "🛡️ 机场安全透视 (原生模式)",
		Text = "脚本已加载 | 按RightShift开菜单",
		Duration = 5,
	})
	
	local function createHL(char, color)
		local hl = Instance.new("Highlight")
		hl.Name = "ESP_Highlight"
		hl.Adornee = char
		hl.FillColor = color
		hl.FillTransparency = 0.55
		hl.OutlineColor = color
		hl.OutlineTransparency = 0.2
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Enabled = true
		hl.Parent = char
		return hl
	end
	
	local function createLabel(char, color, text)
		local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
		if not head then return nil end
		
		local bb = Instance.new("BillboardGui")
		bb.Name = "ESP_HeadTag"
		bb.AlwaysOnTop = true
		bb.Size = UDim2.new(0, 200, 0, 60)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.Adornee = head
		bb.Enabled = true
		bb.ClipsDescendants = false
		bb.Parent = head
		
		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		bg.BackgroundTransparency = 0.35
		bg.BorderSizePixel = 0
		local bgc = Instance.new("UICorner", bg)
		bgc.CornerRadius = UDim.new(0, 6)
		bg.Parent = bb
		
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -8, 0, 28)
		lbl.Position = UDim2.new(0, 4, 0, 2)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 16
		lbl.TextStrokeTransparency = 0
		lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.Parent = bb
		
		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -8, 0, 22)
		info.Position = UDim2.new(0, 4, 0, 30)
		info.BackgroundTransparency = 1
		info.Text = ""
		info.TextColor3 = Color3.fromRGB(220, 220, 220)
		info.Font = Enum.Font.Gotham
		info.TextSize = 13
		info.TextStrokeTransparency = 0.2
		info.TextStrokeColor3 = Color3.new(0, 0, 0)
		info.TextXAlignment = Enum.TextXAlignment.Center
		info.Parent = bb
		
		return bb, lbl, info
	end
	
	local function classify(obj)
		local ok, result = pcall(function()
			local name = obj.Name
			local path = obj:GetFullName()
			
			if path:find("AgentTemplate") then return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent" end
			if path:find("NPCTemplate") then return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat" end
			
			local goodNames = {"Agent", "Police", "Security", "Guard", "Cop", "SWAT", "Friendly", "Helper", "Patrol"}
			local badNames = {"Terrorist", "Enemy", "Hostile", "Threat", "Criminal", "Suspect", "Bandit", "Robber", "Bomber", "Invader", "Killer", "Raid"}
			
			for _, p in ipairs(badNames) do
				if name:find(p) then return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat" end
			end
			for _, p in ipairs(goodNames) do
				if name:find(p) then return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent" end
			end
			
			local hasNPC, hasAgent = false, false
			for _, c in ipairs(obj:GetDescendants()) do
				if c:IsA("ModuleScript") then
					local cp = c:GetFullName()
					if cp:find("NPCTemplate") then hasNPC = true end
					if cp:find("AgentTemplate") then hasAgent = true end
				end
			end
			if hasNPC and not hasAgent then return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat" end
			if hasAgent and not hasNPC then return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent" end
			
			return "Unknown", Color3.fromRGB(180, 180, 180), "❓ Unknown"
		end)
		if ok then return result end
		return "Unknown", Color3.fromRGB(180, 180, 180), "❓ Unknown"
	end
	
	task.spawn(function()
		while task.wait(1.5) do
			pcall(function()
				for _, hum in ipairs(Workspace:GetDescendants()) do
					if hum:IsA("Humanoid") and hum.Parent and hum.Health > 0 then
						local char = hum.Parent
						if char ~= LocalPlayer.Character and char:IsA("Model") and not ESPData[char] then
							local npcType, color, label = classify(char)
							local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
							local objRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
							if myRoot and objRoot then
								if (objRoot.Position - myRoot.Position).Magnitude <= MaxDistance then
									local hl = createHL(char, color)
									local bb, lbl, info = createLabel(char, color, label)
									ESPData[char] = {HL = hl, BB = bb, Lbl = lbl, Info = info, Hum = hum, Type = npcType}
								end
							end
						end
					end
				end
				for obj, data in pairs(ESPData) do
					if not obj.Parent then
						if data.HL then data.HL:Destroy() end
						if data.BB then data.BB:Destroy() end
						ESPData[obj] = nil
					end
				end
			end)
		end
	end)
	
	print("✅ 机场安全ESP v5.2 (原生模式) 已加载")
	return
end

-- ========================================================================
-- ======================== WindUI 完整模式 ===============================
-- ========================================================================

print("✅ WindUI 加载成功! 准备弹出确认框...")

-- ===== Popup 确认弹窗 =====
local loadConfirmed = false
local popupClosed = false

WindUI:Popup({
	Title = "🛡️ 机场安全透视 v5.2",
	Icon = "solar:shield-warning-bold",
	Content = "是否加载机场安全透视脚本？\n\n主要功能：\n• 自动识别好人/坏人\n• 透视穿墙高亮\n• 头顶标签显示\n• 自定义快捷键\n\n按 RightShift 打开菜单",
	Buttons = {
		{
			Title = "❌ 不加载",
			Variant = "Tertiary",
			Callback = function()
				loadConfirmed = false
				popupClosed = true
			end,
		},
		{
			Title = "✅ 确认加载",
			Icon = "arrow-right",
			Variant = "Primary",
			Callback = function()
				loadConfirmed = true
				popupClosed = true
			end,
		},
	},
})

-- 等待用户选择
while not popupClosed do
	task.wait(0.1)
end

if not loadConfirmed then
	WindUI:Notify({
		Title = "已取消",
		Content = "脚本已停止加载",
		Duration = 3,
		Icon = "solar:forbidden-circle-bold",
	})
	return
end

-- ===== 加载游戏服务 =====
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- 检测平台
local IsMobile = pcall(function()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end) and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled or false

-- ===== 通知 =====
WindUI:Notify({
	Title = "✅ 已确认加载",
	Content = "按 RightShift 打开菜单...",
	Duration = 2,
	Icon = "solar:eye-bold",
})

pcall(function()
	StarterGui:SetCore("SendNotification", {
		Title = "🛡️ 机场安全透视 v5.2",
		Text = "按 RightShift 打开菜单 | 在功能设置中绑定快捷键",
		Duration = 10,
	})
end)

-- ===== 状态设置 =====
local Settings = {
	Enabled = true,
	ShowBadOnly = false,
	ShowDistance = true,
	ShowHealth = true,
	MaxDistance = 500,
	ESPHotkey = nil,
	BadOnlyHotkey = nil,
	ToggleHotkey = "RightShift",
	ShowOpenButton = false,
}

local ESPData = {}

-- ========================================================================
-- ===== 创建窗口 (默认隐藏, 按RightShift打开) =====
-- ========================================================================
-- v5.2 关键改动:
-- 窗口默认隐藏(不闪烁), 用 RightShift 打开
-- 其他快捷键用户自行配置
-- 手机端用悬浮按钮

local Window = WindUI:CreateWindow({
	Title = "机场安全透视",
	Author = "b站英吉利超入_",
	Folder = "airport_security_esp",
	Icon = "solar:shield-warning-bold",
	Theme = "Dark",
	Size = UDim2.fromOffset(IsMobile and 400 or 650, 480),
	
	-- ✅ 默认RightShift开关窗口 (WindUI原生支持,不会闪烁)
	ToggleKey = Enum.KeyCode.RightShift,
	
	-- 不传OpenButton,手工做
	Resizable = true,
	NewElements = true,
	SideBarWidth = IsMobile and 160 or 200,
	Topbar = {
		Height = IsMobile and 38 or 44,
		ButtonsType = "Mac",
	},
	SearchBarEnabled = false,
})

-- ===== 手工创建悬浮按钮 (仅手机显示) =====
local OpenBtnGui = Instance.new("ScreenGui")
OpenBtnGui.Name = "AirportESP_OpenBtn"
OpenBtnGui.ResetOnSpawn = false
OpenBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
OpenBtnGui.DisplayOrder = 999999
OpenBtnGui.Parent = CoreGui
OpenBtnGui.Enabled = IsMobile -- 仅手机端默认显示

local OpenBtn = Instance.new("ImageButton")
OpenBtn.Name = "FloatingButton"
OpenBtn.Size = UDim2.new(0, 50, 0, 50)
OpenBtn.Position = UDim2.new(0.95, -55, 0.5, -25)
OpenBtn.BackgroundColor3 = Color3.fromRGB(30, 220, 80)
OpenBtn.BackgroundTransparency = 0.15
OpenBtn.BorderSizePixel = 0
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 14)

local IconLbl = Instance.new("TextLabel")
IconLbl.Size = UDim2.new(1, 0, 1, 0)
IconLbl.BackgroundTransparency = 1
IconLbl.Text = "👁"
IconLbl.TextSize = 22
IconLbl.Font = Enum.Font.GothamBold
IconLbl.TextColor3 = Color3.new(1, 1, 1)
IconLbl.Parent = OpenBtn

-- 拖拽
local dragging = false
local dragStart, btnStart
OpenBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		btnStart = OpenBtn.Position
	end
end)
OpenBtn.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		OpenBtn.Position = UDim2.new(btnStart.X.Scale, btnStart.X.Offset + delta.X, btnStart.Y.Scale, btnStart.Y.Offset + delta.Y)
	end
end)
OpenBtn.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- 手机按钮: 模拟RightShift切换窗口
OpenBtn.MouseButton1Click:Connect(function()
	pcall(function()
		Window:SetToggleKey(Enum.KeyCode.RightShift)
	end)
end)

OpenBtn.Parent = OpenBtnGui

local function setOpenButtonVisible(visible)
	OpenBtnGui.Enabled = visible
	OpenBtn.Visible = visible
end

-- ===== 白色粗滚动条 =====
task.spawn(function()
	task.wait(2)
	for i = 1, 40 do
		task.wait(0.1)
		local found = false
		local rootObj = Window._Object or Window.Window or Window.Instance
		if not rootObj then
			for _, gui in ipairs(CoreGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					for _, desc in ipairs(gui:GetDescendants()) do
						if desc:IsA("ScrollingFrame") and desc.AbsoluteSize.Y > 10 then
							desc.ScrollBarThickness = 14
							desc.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
							desc.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
							found = true
						end
					end
				end
			end
		else
			for _, desc in ipairs(rootObj:GetDescendants()) do
				if desc:IsA("ScrollingFrame") and desc.AbsoluteSize.Y > 10 then
					desc.ScrollBarThickness = 14
					desc.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
					desc.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
					found = true
				end
			end
		end
		if found then break end
	end
end)

-- ========================================================================
-- ======================== UI 控件 ======================================
-- ========================================================================

local statusInput = nil

-- ===== Tab 1: 主控面板 =====
local MainTab = Window:Tab({ Title = "主控面板", Icon = "solar:home-2-bold" })

MainTab:Section({ Title = "透视控制", TextSize = 18 })

MainTab:Toggle({
	Title = "透视开关",
	Desc = "开启/关闭所有透视和头顶标签",
	Value = true,
	Callback = function(state)
		Settings.Enabled = state
		for _, data in pairs(ESPData) do
			if data.Highlight then data.Highlight.Enabled = state end
			if data.Billboard then data.Billboard.Enabled = state end
		end
	end,
})

MainTab:Space()
local StatusGroup = MainTab:Group({})
statusInput = StatusGroup:Input({
	Title = "📡 状态",
	Value = "扫描中... 等待发现目标",
	Locked = true,
})

MainTab:Space()

MainTab:Toggle({
	Title = "仅显示坏人",
	Desc = "隐藏好人，只看威胁目标",
	Value = false,
	Callback = function(state)
		Settings.ShowBadOnly = state
		for _, data in pairs(ESPData) do
			if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
			if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
		end
		ESPData = {}
	end,
})

MainTab:Space()
MainTab:Section({ Title = "显示选项", TextSize = 18 })

MainTab:Toggle({
	Title = "显示距离", Desc = "头顶标签显示距离", Value = true,
	Callback = function(s) Settings.ShowDistance = s end,
})
MainTab:Toggle({
	Title = "显示血量", Desc = "头顶标签显示血量", Value = true,
	Callback = function(s) Settings.ShowHealth = s end,
})

MainTab:Slider({
	Title = "最大探测距离", Desc = "鼠标左键拖拽滑块调节",
	Step = 10,
	Value = { Min = 50, Max = 1000, Default = 500 },
	IsTooltip = true,
	Width = IsMobile and 150 or 200,
	Callback = function(v) Settings.MaxDistance = v end,
})

-- ========================================================================
-- ===== Tab 2: 功能设置 =====
-- ========================================================================
local FuncTab = Window:Tab({ Title = "功能设置", Icon = "solar:settings-bold" })

FuncTab:Section({ Title = "快捷键设置", TextSize = 18 })
FuncTab:Space()

FuncTab:Keybind({
	Title = "透视开关快捷键",
	Desc = "点击后按下键盘按键即可绑定",
	Value = "None",
	Callback = function(key)
		Settings.ESPHotkey = key
		if key and key ~= "None" then
			print(string.format("[ESP] 透视快捷键已设为: %s", key))
		end
	end,
})

FuncTab:Space()

FuncTab:Keybind({
	Title = "仅坏人模式快捷键",
	Desc = "点击后按下键盘按键即可绑定",
	Value = "None",
	Callback = function(key)
		Settings.BadOnlyHotkey = key
		if key and key ~= "None" then
			print(string.format("[ESP] 仅坏人快捷键已设为: %s", key))
		end
	end,
})

FuncTab:Space()
FuncTab:Section({ Title = "快捷键说明", TextSize = 14 })
FuncTab:Paragraph({
	Title = "📖 使用方法",
	Desc = "1. 点击上面的快捷键输入框\n2. 按下键盘上的任意键\n3. 自动绑定成功！\n\n绑定后：\n• 透视开关 = 切换显示/隐藏\n• 仅坏人模式 = 切换只看坏人",
})

-- ========================================================================
-- ===== Tab 3: UI设置 =====
-- ========================================================================
local UITab = Window:Tab({ Title = "UI设置", Icon = "solar:palette-bold" })

UITab:Section({ Title = "窗口控制", TextSize = 18 })

-- 显示当前快捷键
UITab:Keybind({
	Title = "窗口开关快捷键",
	Desc = "默认: RightShift（请勿修改，仅查看）",
	Value = "RightShift",
	Callback = function(key)
		if key and key ~= "None" and key ~= "RightShift" then
			-- 允许用户修改
			Settings.ToggleHotkey = key
			pcall(function()
				Window:SetToggleKey(Enum.KeyCode[key])
				print(string.format("[UI] 窗口快捷键已设为: %s", key))
			end)
		end
	end,
})

UITab:Space()

-- 悬浮按钮开关
UITab:Toggle({
	Title = "悬浮按钮（手机）",
	Desc = "显示/隐藏屏幕上的绿色按钮",
	Value = IsMobile,
	Callback = function(state)
		Settings.ShowOpenButton = state
		setOpenButtonVisible(state)
	end,
})

UITab:Space()
UITab:Section({ Title = "UI说明", TextSize = 14 })
UITab:Paragraph({
	Title = "💡 提示",
	Desc = IsMobile
		and "• 点击绿色👁按钮打开菜单\n• 按钮可拖拽移动\n• 在功能设置中绑定快捷键"
		or "• 按 RightShift 打开/关闭菜单\n• 在功能设置中绑定快捷键\n• 支持自定义窗口快捷键",
})

-- ========================================================================
-- ===== Tab 4: 信息统计 =====
-- ========================================================================
local StatsTab = Window:Tab({ Title = "信息统计", Icon = "solar:chart-2-bold" })

local SG = StatsTab:Group({})
local GoodInput = SG:Input({ Title = "🟢 好人", Value = "0", Locked = true })
SG:Space()
local BadInput = SG:Input({ Title = "🔴 坏人", Value = "0", Locked = true })
SG:Space()
local UnknownInput = SG:Input({ Title = "❓ 未知", Value = "0", Locked = true })
SG:Space()
local TotalInput = SG:Input({ Title = "📊 总计", Value = "0", Locked = true })
SG:Space()
SG:Section({ Title = "调试信息", TextSize = 14 })
local DebugInput = SG:Input({
	Title = "最近发现",
	Value = "等待扫描...",
	Locked = true,
})

-- ========================================================================
-- ===== Tab 5: 关于 =====
-- ========================================================================
local AboutTab = Window:Tab({ Title = "关于", Icon = "solar:info-square-bold" })

AboutTab:Section({ Title = "机场安全透视 v5.2", TextSize = 24 })
AboutTab:Space()
AboutTab:Paragraph({
	Title = "👤 作者",
	Desc = "作者: b站英吉利超入_",
})
AboutTab:Space()
AboutTab:Paragraph({
	Title = "📖 使用说明",
	Desc = [[
💻 PC: 按 RightShift 打开菜单
📱 手机: 点击绿色👁按钮

1️⃣ 在「功能设置」中绑定快捷键
2️⃣ 开启透视后NPC自动高亮

💡 右侧白色滑块可拖拽滚动
]],
})

-- ========================================================================
-- ======================== ESP 核心系统 ================================
-- ========================================================================

-- 创建头顶标签
local function createHeadLabel(char, color, mainText)
	local ok, head = pcall(function()
		return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	end)
	if not ok or not head then return nil, nil, nil end
	
	local bb = Instance.new("BillboardGui")
	bb.Name = "ESP_HeadTag"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 200, 0, 60)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.Adornee = head
	bb.Enabled = Settings.Enabled
	bb.ClipsDescendants = false
	bb.Parent = head
	
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
	bg.Parent = bb
	
	local mainLbl = Instance.new("TextLabel")
	mainLbl.Size = UDim2.new(1, -8, 0, 28)
	mainLbl.Position = UDim2.new(0, 4, 0, 2)
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
	infoLbl.Position = UDim2.new(0, 4, 0, 30)
	infoLbl.BackgroundTransparency = 1
	infoLbl.Text = ""
	infoLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
	infoLbl.Font = Enum.Font.Gotham
	infoLbl.TextSize = 13
	infoLbl.TextStrokeTransparency = 0.2
	infoLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	infoLbl.TextXAlignment = Enum.TextXAlignment.Center
	infoLbl.Parent = bb
	
	return bb, mainLbl, infoLbl
end

-- 创建Highlight
local function createHighlight(char, color)
	local hl = Instance.new("Highlight")
	hl.Name = "ESP_Highlight"
	hl.Adornee = char
	hl.FillColor = color
	hl.FillTransparency = 0.55
	hl.OutlineColor = color
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = Settings.Enabled
	hl.Parent = char
	return hl
end

-- ===== 分类器 =====
local function classifyCharacter(obj)
	local ok, result = pcall(function()
		if not obj then return "Unknown", Color3.fromRGB(180, 180, 180), "❓ Unknown" end
		
		local name = obj.Name or ""
		local fullPath = obj:GetFullName() or ""
		
		-- 1) 路径精确匹配
		if fullPath:find("NPCTemplate") and not fullPath:find("AgentTemplate") then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		end
		if fullPath:find("AgentTemplate") and not fullPath:find("NPCTemplate") then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		end
		
		-- 2) 名字匹配 (坏人优先)
		local badPatterns = {"Terrorist", "Enemy", "Hostile", "Threat", "Criminal", "Suspect", "Bandit", "Robber", "Bomber", "Invader", "Killer", "Raid"}
		local goodPatterns = {"Police", "Security", "Guard", "Agent", "Cop", "SWAT", "Friendly", "Helper", "Patrol"}
		
		for _, pat in ipairs(badPatterns) do
			if name:find(pat) then return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat" end
		end
		for _, pat in ipairs(goodPatterns) do
			if name:find(pat) then return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent" end
		end
		
		-- 3) Descendant扫描
		local foundAgent, foundNPC = false, false
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("ModuleScript") or child:IsA("Script") or child:IsA("LocalScript") then
				local cp = child:GetFullName()
				if cp:find("NPCTemplate") and not cp:find("AgentTemplate") then foundNPC = true end
				if cp:find("AgentTemplate") and not cp:find("NPCTemplate") then foundAgent = true end
			end
		end
		
		if foundNPC and not foundAgent then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		elseif foundAgent and not foundNPC then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		end
		
		return "Unknown", Color3.fromRGB(180, 180, 180), "❓ Unknown"
	end)
	
	if ok then return result end
	return "Unknown", Color3.fromRGB(180, 180, 180), "❓ Unknown"
end

-- ===== 主扫描循环 =====
local lastDebugMsg = "无"
local scanCount = 0

task.spawn(function()
	print(string.format("[ESP] 开始扫描, 玩家: %s", LocalPlayer.Name or "未知"))
	print(string.format("[ESP] Workspace子级数: %d", #Workspace:GetChildren()))
	
	while task.wait(1) do
		pcall(function()
			scanCount = scanCount + 1
			
			for _, hum in ipairs(Workspace:GetDescendants()) do
				if hum:IsA("Humanoid") and hum.Parent and hum.Health > 0 then
					local char = hum.Parent
					if char == LocalPlayer.Character then continue end
					if ESPData[char] then continue end
					if not char:IsA("Model") then continue end
					
					local npcType, color, label = classifyCharacter(char)
					
					local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
					local objRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char:FindFirstChild("Torso")
					if not myRoot or not objRoot then continue end
					
					local dist = (objRoot.Position - myRoot.Position).Magnitude
					if dist > Settings.MaxDistance then continue end
					
					if Settings.ShowBadOnly and npcType ~= "Bad" then continue end
					
					local hl = createHighlight(char, color)
					local bb, mainLbl, infoLbl = createHeadLabel(char, color, label)
					
					if not hl or not bb then
						if hl then hl:Destroy() end
						if bb then bb:Destroy() end
						continue
					end
					
					ESPData[char] = {
						Highlight = hl,
						Billboard = bb,
						MainLabel = mainLbl,
						InfoLabel = infoLbl,
						Humanoid = hum,
						NPCType = npcType,
					}
					
					lastDebugMsg = string.format("%s | %s | %.0fm", char.Name, npcType, dist)
					print(string.format("[ESP] ✅ 发现: %s | 类型: %s | 距离: %.0fm | 路径: %s",
						char.Name, npcType, dist, char:GetFullName()))
				end
			end
			
			-- 清理
			for obj, data in pairs(ESPData) do
				if not obj.Parent then
					if data.Highlight then data.Highlight:Destroy() end
					if data.Billboard then data.Billboard:Destroy() end
					ESPData[obj] = nil
				end
			end
			
			-- 更新标签
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local myRoot = LocalPlayer.Character.HumanoidRootPart
				for obj, data in pairs(ESPData) do
					if data.Billboard and data.InfoLabel then
						local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
						local parts = {}
						if root and Settings.ShowDistance then
							table.insert(parts, math.floor((root.Position - myRoot.Position).Magnitude) .. "m")
						end
						if Settings.ShowHealth then
							table.insert(parts, string.format("HP: %.0f/%.0f", data.Humanoid.Health, data.Humanoid.MaxHealth))
						end
						data.InfoLabel.Text = table.concat(parts, " | ")
						data.Billboard.Enabled = Settings.Enabled
					end
					if data.Highlight then
						data.Highlight.Enabled = Settings.Enabled
					end
				end
			end
			
			-- 更新统计
			local good, bad, unknown = 0, 0, 0
			for _, data in pairs(ESPData) do
				if data.NPCType == "Good" then good = good + 1 end
				if data.NPCType == "Bad" then bad = bad + 1 end
				if data.NPCType == "Unknown" then unknown = unknown + 1 end
			end
			
			local total = good + bad + unknown
			pcall(function()
				GoodInput:Set(tostring(good))
				BadInput:Set(tostring(bad))
				UnknownInput:Set(tostring(unknown))
				TotalInput:Set(tostring(total))
				DebugInput:Set(lastDebugMsg)
				
				if total > 0 then
					pcall(function() statusInput:Set(string.format("🟢 %d | 🔴 %d | 总计: %d", good, bad, total)) end)
				else
					pcall(function()
						local scanMsg = "扫描中... 未发现目标"
						if scanCount > 5 then
							scanMsg = "扫描中... 本局可能无NPC或距离太远"
						end
						statusInput:Set(scanMsg)
					end)
				end
			end)
		end)
	end
end)

-- ========================================================================
-- ======================== 快捷键系统 ===================================
-- ========================================================================

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	
	local keyName = input.KeyCode and input.KeyCode.Name or ""
	if keyName == "" then return end
	
	-- 透视开关快捷键
	if Settings.ESPHotkey and keyName == Settings.ESPHotkey then
		Settings.Enabled = not Settings.Enabled
		for _, data in pairs(ESPData) do
			if data.Highlight then data.Highlight.Enabled = Settings.Enabled end
			if data.Billboard then data.Billboard.Enabled = Settings.Enabled end
		end
		return
	end
	
	-- 仅坏人模式快捷键
	if Settings.BadOnlyHotkey and keyName == Settings.BadOnlyHotkey then
		Settings.ShowBadOnly = not Settings.ShowBadOnly
		for _, data in pairs(ESPData) do
			if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
			if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
		end
		ESPData = {}
		return
	end
end)

print("✅ 机场安全透视 v5.2 已加载!")
print("⌨️ 按 RightShift 打开/关闭菜单")
print("🔑 其他快捷键请到UI中自行设置")
