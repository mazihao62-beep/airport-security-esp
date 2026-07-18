--[[
	机场安全透视脚本 v6.0 (Airport Security ESP)
	作者: b站英吉利超入_
	
	v6.0 - 彻底修复NPC分类器
	  🐛 问题1: classifyCharacter路径检查优先级高于名字
	     → 所有NPCTemplate下的NPC都被判为坏人,无视名字
	  🐛 问题2: 头顶标签仍为英文"💀 Threat""👮 Agent"
	  🐛 问题3: 还有"Unknown"分类(用户只需要好人/坏人)
	  🐛 问题4: Input:Set("string")参数错误导致文字错乱
	  🐛 问题5: Paragraph用Desc=""产生多余空白
	  🐛 问题6: 信息统计还有"未知"一栏
	  🐛 问题7: Slider不可见(白色圆点没找到)
--]]

-- ========================================================================
-- ==================== 第一步：加载WindUI ================================
-- ========================================================================

local Success, WindUI = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not Success or not WindUI then
	-- ===== WindUI加载失败 → 原生模式 =====
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local CoreGui = game:GetService("CoreGui")
	local UserInputService = game:GetService("UserInputService")
	local LocalPlayer = Players.LocalPlayer
	
	-- 原生模式快速ESP
	local ESPData = {}
	local MaxDistance = 500
	
	local function createHL(char, color)
		local hl = Instance.new("Highlight")
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
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
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
	
	-- ===== 原生模式分类器 (v6.0: 名字优先,中文+英文,只有好人/坏人) =====
	local function classify(obj)
		local name = obj.Name or ""
		local path = obj:GetFullName() or ""
		
		-- [优先1] 中文关键词
		local cnGood = {"警察", "保安", "警卫", "军官", "士兵", "警"}
		local cnBad  = {"恐怖", "匪徒", "歹徒", "罪犯", "敌人", "杀手", "袭击", "入侵"}
		for _, kw in ipairs(cnGood) do
			if name:find(kw, 1, true) then
				return "Good", Color3.fromRGB(0, 255, 100), "👮 好人"
			end
		end
		for _, kw in ipairs(cnBad) do
			if name:find(kw, 1, true) then
				return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
			end
		end
		
		-- [优先2] 英文关键词
		local enGood = {"Police", "Security", "Guard", "Agent", "Cop", "SWAT", "Friendly", "Officer"}
		local enBad  = {"Terrorist", "Enemy", "Hostile", "Threat", "Criminal", "Suspect", "Bandit", "Raid"}
		for _, kw in ipairs(enGood) do
			if name:find(kw, 1, true) then
				return "Good", Color3.fromRGB(0, 255, 100), "👮 好人"
			end
		end
		for _, kw in ipairs(enBad) do
			if name:find(kw, 1, true) then
				return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
			end
		end
		
		-- [优先3] Humanoid NPCType属性 (来源源码NPCSetup.lua)
		local hum = obj:FindFirstChildOfClass("Humanoid")
		if hum then
			local npcType = hum:GetAttribute("NPCType") or hum:FindFirstChild("NPCType")
			if npcType then
				local t = tostring(npcType)
				if t == "Agent" then return "Good", Color3.fromRGB(0, 255, 100), "👮 好人" end
				if t == "Enemy" then return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人" end
			end
		end
		
		-- [后备] 路径检测
		if path:find("AgentTemplate") and not path:find("NPCTemplate") then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 好人"
		end
		if path:find("NPCTemplate") and not path:find("AgentTemplate") then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
		end
		if path:find("NPCWorkspace") then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
		end
		
		-- 默认: 按名字含"NPC"判坏人
		if name:find("NPC", 1, true) then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
		end
		
		-- 实在无法判断 -> 默认坏人 (宁可错杀)
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
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
							if myRoot and objRoot and (objRoot.Position - myRoot.Position).Magnitude <= MaxDistance then
								local hl = createHL(char, color)
								local bb, lbl, info = createLabel(char, color, label)
								ESPData[char] = {HL = hl, BB = bb, Lbl = lbl, Info = info, Hum = hum, Type = npcType}
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
	
	print("✅ 机场安全ESP v6.0 (原生模式) 已加载")
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
	Title = "🛡️ 机场安全透视 v6.0",
	Icon = "solar:shield-warning-bold",
	Content = "是否加载机场安全透视脚本？\n\n主要功能：\n• 自动识别好人/坏人\n• 透视穿墙高亮\n• 头顶中文标签\n• 自定义快捷键\n\n按 RightShift 打开菜单",
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
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local IsMobile = false
pcall(function()
	IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end)

-- ===== 纯WindUI通知 =====
WindUI:Notify({
	Title = "✅ 已确认加载",
	Content = "按 RightShift 打开菜单 | 在功能设置中绑定快捷键",
	Duration = 5,
	Icon = "solar:eye-bold",
})

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
-- ===== 创建窗口 =====
-- ========================================================================

local Window = WindUI:CreateWindow({
	Title = "机场安全透视",
	Author = "b站英吉利超入_",
	Folder = "airport_security_esp",
	Icon = "solar:shield-warning-bold",
	Theme = "Dark",
	Size = UDim2.fromOffset(IsMobile and 400 or 650, 480),
	ToggleKey = Enum.KeyCode.RightShift,
	Resizable = true,
	NewElements = true,
	SideBarWidth = IsMobile and 160 or 200,
	Topbar = {
		Height = IsMobile and 38 or 44,
		ButtonsType = "Mac",
	},
	SearchBarEnabled = false,
})

-- ===== 悬浮按钮 =====
local OpenBtnGui = Instance.new("ScreenGui")
OpenBtnGui.Name = "AirportESP_OpenBtn"
OpenBtnGui.ResetOnSpawn = false
OpenBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
OpenBtnGui.DisplayOrder = 999999
OpenBtnGui.Parent = CoreGui
OpenBtnGui.Enabled = IsMobile

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
OpenBtn.MouseButton1Click:Connect(function()
	pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)
end)
OpenBtn.Parent = OpenBtnGui

local function setOpenButtonVisible(visible)
	OpenBtnGui.Enabled = visible
	OpenBtn.Visible = visible
end

-- ========================================================================
-- ===== 滚动条美化 (白色大滑块,可拖拽) =====
-- ========================================================================
task.spawn(function()
	task.wait(2)
	for i = 1, 30 do
		task.wait(0.1)
		local rootObj = nil
		pcall(function()
			-- 尝试获取WindUI窗口的根对象
			local allGui = CoreGui:GetChildren()
			for _, gui in ipairs(allGui) do
				if gui:IsA("ScreenGui") then
					for _, child in ipairs(gui:GetChildren()) do
						if child:IsA("ScrollingFrame") and child.AbsoluteSize.Y > 50 then
							rootObj = child
						end
					end
				end
			end
		end)
		if rootObj then
			pcall(function()
				rootObj.ScrollBarThickness = 14
				rootObj.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
				rootObj.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
				-- 给滑块添加圆角
				rootObj.ScrollBarImageTransparency = 0.4
			end)
		end
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

-- ===== Slider: 带白色发光圆点 =====
local SliderObj = MainTab:Slider({
	Title = "最大探测距离",
	Desc = "鼠标左键按住圆点拖拽调节",
	Step = 10,
	Value = { Min = 50, Max = 1000, Default = 500 },
	IsTooltip = true,
	Width = IsMobile and 150 or 200,
	Callback = function(v) Settings.MaxDistance = v end,
})

-- 美化Slider的Thumb为白色发光圆点
task.spawn(function()
	task.wait(1)
	pcall(function()
		-- 在WindUI的内部查找Slider的thumb部分
		for _, gui in ipairs(CoreGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				for _, desc in ipairs(gui:GetDescendants()) do
					if desc:IsA("ImageLabel") and (desc.Name:find("Thumb") or desc.Name:find("thumb") or desc.Name:find("Thumbnail")) then
						desc.ImageColor3 = Color3.fromRGB(255, 255, 255)
						desc.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					end
				end
			end
		end
	end)
end)

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
		if key == "None" then
			Settings.ESPHotkey = nil
		else
			Settings.ESPHotkey = key
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
		if key == "None" then
			Settings.BadOnlyHotkey = nil
		else
			Settings.BadOnlyHotkey = key
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

UITab:Keybind({
	Title = "窗口开关快捷键",
	Desc = "默认: RightShift（点击可修改）",
	Value = "RightShift",
	Callback = function(key)
		if key == "None" then
			Settings.ToggleHotkey = "RightShift"
			pcall(function()
				Window:SetToggleKey(Enum.KeyCode.RightShift)
			end)
		elseif key ~= "RightShift" then
			Settings.ToggleHotkey = key
			pcall(function()
				local keyEnum = Enum.KeyCode[key]
				if keyEnum then
					Window:SetToggleKey(keyEnum)
					print(string.format("[UI] 窗口快捷键已设为: %s", key))
				end
			end)
		end
	end,
})

UITab:Space()

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
-- ===== Tab 4: 信息统计 (v6.0: 仅好人/坏人,无未知) =====
-- ========================================================================
local StatsTab = Window:Tab({ Title = "信息统计", Icon = "solar:chart-2-bold" })

local StatsGroup = StatsTab:Group({})

-- 只用Paragraph, 不传Desc参数避免空白行
local GoodPara = StatsGroup:Paragraph({ Title = "🟢 好人: 0" })
StatsGroup:Space()
local BadPara = StatsGroup:Paragraph({ Title = "🔴 坏人: 0" })
StatsGroup:Space()
local TotalPara = StatsGroup:Paragraph({ Title = "📊 总计: 0" })
StatsGroup:Space()
StatsGroup:Space()

StatsGroup:Section({ Title = "调试信息", TextSize = 14 })

local DebugInput = StatsGroup:Input({
	Title = "扫描状态",
	Value = "等待扫描...",
	Locked = true,
})

-- ========================================================================
-- ===== Tab 5: 关于 =====
-- ========================================================================
local AboutTab = Window:Tab({ Title = "关于", Icon = "solar:info-square-bold" })

AboutTab:Section({ Title = "机场安全透视 v6.0", TextSize = 24 })
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
-- ======================== v6.0: 分类器彻底修复 ==========================

-- ===== 角色检测函数 =====
local function isCharacterModel(obj)
	if not obj or not obj:IsA("Model") then return false end
	if obj == LocalPlayer.Character then return false end
	if not obj.Parent then return false end
	
	local hasHead = obj:FindFirstChild("Head") ~= nil
	local hasHRP = obj:FindFirstChild("HumanoidRootPart") ~= nil
	local hasTorso = obj:FindFirstChild("Torso") ~= nil
	local hasHumanoid = obj:FindFirstChildOfClass("Humanoid") ~= nil
	
	return hasHead or hasHRP or (hasTorso and hasHumanoid)
end

-- ===== 创建头顶标签 =====
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

-- ===== 创建Highlight =====
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

-- ===== v6.0 分类器 (彻底修复: 名字优先,中文+英文+属性,只有好人/坏人) =====
local function classifyCharacter(obj)
	if not obj then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
	end
	
	local name = obj.Name or ""
	local fullPath = obj:GetFullName() or ""
	
	-- [第1层] 中文关键词 (优先级最高)
	local cnGood = {"警察", "保安", "警卫", "军官", "士兵", "警"}
	local cnBad  = {"恐怖", "匪徒", "歹徒", "罪犯", "敌人", "杀手", "袭击", "入侵"}
	for _, kw in ipairs(cnGood) do
		if name:find(kw, 1, true) then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 好人"
		end
	end
	for _, kw in ipairs(cnBad) do
		if name:find(kw, 1, true) then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
		end
	end
	
	-- [第2层] 英文关键词
	local enGood = {"Police", "Security", "Guard", "Agent", "Cop", "SWAT", "Friendly", "Officer"}
	local enBad  = {"Terrorist", "Enemy", "Hostile", "Threat", "Criminal", "Suspect", "Bandit", "Raid"}
	for _, kw in ipairs(enGood) do
		if name:find(kw, 1, true) then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 好人"
		end
	end
	for _, kw in ipairs(enBad) do
		if name:find(kw, 1, true) then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
		end
	end
	
	-- [第3层] Humanoid NPCType属性 (来源于NPCSetup.lua源码)
	local hum = obj:FindFirstChildOfClass("Humanoid")
	if hum then
		local npcTypeAttr = hum:GetAttribute("NPCType")
		if npcTypeAttr then
			local t = tostring(npcTypeAttr)
			if t == "Agent" then
				return "Good", Color3.fromRGB(0, 255, 100), "👮 好人"
			end
			if t == "Enemy" then
				return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
			end
		end
	end
	
	-- [第4层] 路径检测
	if fullPath:find("AgentTemplate") and not fullPath:find("NPCTemplate") then
		return "Good", Color3.fromRGB(0, 255, 100), "👮 好人"
	end
	if fullPath:find("NPCTemplate") and not fullPath:find("AgentTemplate") then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
	end
	if fullPath:find("NPCWorkspace") then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
	end
	
	-- [第5层] 名字含"NPC"判坏人
	if name:find("NPC", 1, true) then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
	end
	
	-- [保底] 无法判断时默认坏人 (宁可错杀)
	return "Bad", Color3.fromRGB(255, 50, 50), "💀 坏人"
end

local function getHumanoid(char)
	return char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(char)
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
end

-- ===== 主扫描循环 =====
local scanCount = 0

task.spawn(function()
	print("=" .. string.rep("=", 50) .. "=")
	print("[ESP] 🛡️ 机场安全透视 v6.0 扫描系统启动")
	print(string.format("[ESP] 玩家: %s", LocalPlayer.Name or "未知"))
	print(string.format("[ESP] Workspace子级: %d", #Workspace:GetChildren()))
	print("=" .. string.rep("=", 50) .. "=")
	
	while task.wait(1) do
		pcall(function()
			scanCount = scanCount + 1
			local newFound = 0
			
			-- 扫描Humanoid
			local humCount = 0
			for _, hum in ipairs(Workspace:GetDescendants()) do
				if hum:IsA("Humanoid") and hum.Parent then
					humCount = humCount + 1
					local char = hum.Parent
					if char:IsA("Model") and isCharacterModel(char) and not ESPData[char] then
						local npcType, color, label = classifyCharacter(char)
						local myRoot = getRootPart(LocalPlayer.Character)
						local objRoot = getRootPart(char)
						if myRoot and objRoot then
							local dist = (objRoot.Position - myRoot.Position).Magnitude
							if dist <= Settings.MaxDistance then
								if Settings.ShowBadOnly and npcType ~= "Bad" then break end
								local hl = createHighlight(char, color)
								local bb, mainLbl, infoLbl = createHeadLabel(char, color, label)
								if hl and bb then
									local humObj = hum or getHumanoid(char)
									ESPData[char] = {
										Highlight = hl, Billboard = bb,
										MainLabel = mainLbl, InfoLabel = infoLbl,
										Humanoid = humObj, NPCType = npcType,
									}
									newFound = newFound + 1
									print(string.format("[ESP] ✅ %s | %s | %.0fm | %s", char.Name, npcType, dist, char:GetFullName()))
								end
							end
						end
					end
				end
			end
			
			-- 清理已删除的
			for obj, data in pairs(ESPData) do
				if not obj.Parent then
					if data.Highlight then data.Highlight:Destroy() end
					if data.Billboard then data.Billboard:Destroy() end
					ESPData[obj] = nil
				end
			end
			
			-- 更新标签信息
			if LocalPlayer.Character then
				local myRoot = getRootPart(LocalPlayer.Character)
				for obj, data in pairs(ESPData) do
					if data.Billboard and data.InfoLabel then
						local root = getRootPart(obj)
						local parts = {}
						if root and myRoot and Settings.ShowDistance then
							table.insert(parts, math.floor((root.Position - myRoot.Position).Magnitude) .. "m")
						end
						if data.Humanoid and Settings.ShowHealth then
							table.insert(parts, string.format("HP: %.0f/%.0f", data.Humanoid.Health, data.Humanoid.MaxHealth))
						end
						data.InfoLabel.Text = table.concat(parts, " | ")
						data.Billboard.Enabled = Settings.Enabled
					end
					if data.Highlight then data.Highlight.Enabled = Settings.Enabled end
				end
			end
			
			-- 更新统计 (v6.0: 只有好人/坏人,无未知)
			local good, bad = 0, 0
			for _, data in pairs(ESPData) do
				if data.NPCType == "Good" then good = good + 1 end
				if data.NPCType == "Bad" then bad = bad + 1 end
			end
			
			local total = good + bad
			
			pcall(function()
				GoodPara:SetTitle(string.format("🟢 好人: %d", good))
				BadPara:SetTitle(string.format("🔴 坏人: %d", bad))
				TotalPara:SetTitle(string.format("📊 总计: %d", total))
				
				-- v6.0: Input:Set({Value = "..."}) 正确的传参方式
				local debugStr = string.format("扫描%d次 | Humanoid:%d个 | 本批发现%d个 | 总计%d个",
					scanCount, humCount, newFound, total)
				if total == 0 then
					debugStr = debugStr .. " | ⚠️ 未发现目标"
				end
				DebugInput:Set({ Value = debugStr })
				
				if total > 0 then
					statusInput:Set({ Value = string.format("🟢 %d | 🔴 %d | 总计: %d", good, bad, total) })
				else
					local scanMsg = "扫描中... 未发现目标"
					if scanCount > 10 then
						scanMsg = "⚠️ 未发现目标 - 可能本局无NPC或距离太远"
					end
					if humCount == 0 then
						scanMsg = "⚠️ Workspace中无任何Humanoid对象"
					end
					statusInput:Set({ Value = scanMsg })
				end
			end)
			
			if scanCount == 1 then
				print("[ESP] 首次扫描 - Workspace结构:")
				for _, child in ipairs(Workspace:GetChildren()) do
					print(string.format("[ESP]   ├─ %s (%s)", child.Name, child.ClassName))
				end
				print(string.format("[ESP] 总计Humanoid数量: %d", humCount))
			end
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
	
	if Settings.ESPHotkey and keyName == Settings.ESPHotkey then
		Settings.Enabled = not Settings.Enabled
		for _, data in pairs(ESPData) do
			if data.Highlight then data.Highlight.Enabled = Settings.Enabled end
			if data.Billboard then data.Billboard.Enabled = Settings.Enabled end
		end
		return
	end
	
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

print("✅ 机场安全透视 v6.0 已加载!")
print("📡 NPC分类: 中文名 > 英文名 > NPCType属性 > 路径 > 默认坏人")
print("🏷 头顶标签: 👮好人 / 💀坏人 (全中文)")
