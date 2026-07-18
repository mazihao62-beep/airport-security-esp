--[[
	机场安全透视脚本 v4.0 (Airport Security ESP)
	彻底修复NPC检测问题 + WindUI Popup弹窗 + 白色滚动条
--]]

-- ===== 第一步：加载前弹出确认弹窗 =====
local Success, WindUI = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not Success or not WindUI then
	-- WindUI加载失败，弹原生确认框
	local YesNo = syn and syn.protect_gui or function() end
	local msg = Instance.new("Message")
	msg.Text = "🛡️ 机场安全透视脚本 - 是否加载？ (F4=透视开关)"
	msg.Parent = game:GetService("CoreGui")
	
	task.wait(0.5)
	
	-- 简化的原生模式
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local CoreGui = game:GetService("CoreGui")
	local StarterGui = game:GetService("StarterGui")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local LocalPlayer = Players.LocalPlayer
	
	local ESPEnabled = true
	local MaxDistance = 500
	
	-- 原生通知
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "🛡️ 机场安全透视",
			Text = "F4 = 开关 | 自动扫描NPC",
			Duration = 5,
		})
	end)
	
	-- 创建ESP存储
	local ESPData = {}
	local highlightFolder = Instance.new("Folder")
	highlightFolder.Name = "ESP_Folder"
	highlightFolder.Parent = CoreGui
	
	-- 创建头顶标签
	local function createHeadLabel(char, color, mainText)
		local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
		if not head then return nil end
		
		local bb = Instance.new("BillboardGui")
		bb.Name = "ESP_HeadTag"
		bb.AlwaysOnTop = true
		bb.Size = UDim2.new(0, 180, 0, 55)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.Adornee = head
		bb.Enabled = true
		bb.ClipsDescendants = false
		bb.Parent = head
		
		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		bg.BackgroundTransparency = 0.35
		bg.BorderSizePixel = 0
		local bgc = Instance.new("UICorner", bg)
		bgc.CornerRadius = UDim.new(0, 6)
		bg.Parent = bb
		
		local mainLbl = Instance.new("TextLabel")
		mainLbl.Size = UDim2.new(1, -8, 0, 26)
		mainLbl.Position = UDim2.new(0, 4, 0, 2)
		mainLbl.BackgroundTransparency = 1
		mainLbl.Text = mainText
		mainLbl.TextColor3 = color
		mainLbl.Font = Enum.Font.GothamBold
		mainLbl.TextSize = 15
		mainLbl.TextStrokeTransparency = 0
		mainLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
		mainLbl.TextXAlignment = Enum.TextXAlignment.Center
		mainLbl.Parent = bb
		
		local infoLbl = Instance.new("TextLabel")
		infoLbl.Size = UDim2.new(1, -8, 0, 20)
		infoLbl.Position = UDim2.new(0, 4, 0, 28)
		infoLbl.BackgroundTransparency = 1
		infoLbl.Text = ""
		infoLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
		infoLbl.Font = Enum.Font.Gotham
		infoLbl.TextSize = 12
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
		hl.FillTransparency = 0.6
		hl.OutlineColor = color
		hl.OutlineTransparency = 0.3
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Enabled = true
		hl.Parent = char
		return hl
	end
	
	-- 深度分类（更全面）
	local function classify(obj)
		local name = obj.Name or ""
		local fullPath = obj:GetFullName() or ""
		
		-- 检查整条路径
		if fullPath:find("AgentTemplate") or fullPath:find("Agent") or fullPath:find("Police") or fullPath:find("Security") or fullPath:find("Guard") or fullPath:find("Friendly") then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		end
		if fullPath:find("NPCTemplate") or fullPath:find("NPC") or fullPath:find("Terrorist") or fullPath:find("Enemy") or fullPath:find("Hostile") or fullPath:find("Threat") or fullPath:find("Criminal") or fullPath:find("Suspect") then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		end
		
		-- 按名字
		if name:find("Agent") or name:find("Police") or name:find("Security") or name:find("Guard") or name:find("Cop") or name:find("SWAT") or name:find("Friendly") or name:find("Good") then
			return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
		end
		if name:find("NPC") or name:find("Terrorist") or name:find("Enemy") or name:find("Hostile") or name:find("Threat") or name:find("Criminal") or name:find("Suspect") or name:find("Bad") or name:find("Bandit") or name:find("Robber") or name:find("Rogue") or name:find("Bomb") then
			return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
		end
		
		-- Descendant扫描脚本模块
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("ModuleScript") or child:IsA("LocalScript") or child:IsA("Script") then
				local cPath = child:GetFullName()
				if cPath:find("NPCTemplate") and not cPath:find("AgentTemplate") then
					return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
				elseif cPath:find("AgentTemplate") and not cPath:find("NPCTemplate") then
					return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
				end
			end
		end
		
		return "Unknown", Color3.fromRGB(180, 180, 180), "❓ Unknown"
	end
	
	-- ===== 深度扫描函数 =====
	local scannedObjs = {}
	
	local function deepScan(container, depth)
		depth = depth or 0
		if depth > 8 then return end
		
		for _, obj in ipairs(container:GetChildren()) do
			if obj == LocalPlayer.Character or obj:IsA("Cameras") or obj:IsA("Terrain") then continue end
			if scannedObjs[obj] then 
				deepScan(obj, depth + 1)
				continue 
			end
			
			local humanoid = obj:FindFirstChild("Humanoid") or obj:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid:IsA("Humanoid") then
				if humanoid.Health <= 0 then 
					deepScan(obj, depth + 1)
					continue 
				end
				
				local npcType, color, label = classify(obj)
				
				-- 距离检查
				local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local objRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head")
				if myRoot and objRoot then
					local dist = (objRoot.Position - myRoot.Position).Magnitude
					if dist > MaxDistance then 
						deepScan(obj, depth + 1)
						continue 
					end
				end
				
				-- 创建ESP
				local hl = createHighlight(obj, color)
				local bb, mainLbl, infoLbl = createHeadLabel(obj, color, label)
				
				scannedObjs[obj] = {
					Highlight = hl,
					Billboard = bb,
					MainLabel = mainLbl,
					InfoLabel = infoLbl,
					Humanoid = humanoid,
					NPCType = npcType,
				}
				
				print(string.format("[ESP] 发现目标: %s | 类型: %s | 路径: %s", obj.Name, npcType, obj:GetFullName()))
			end
			
			deepScan(obj, depth + 1)
		end
	end
	
	-- 清理
	local function cleanup()
		for obj, data in pairs(scannedObjs) do
			if not obj.Parent or not obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChildOfClass("Humanoid").Health <= 0 then
				if data.Highlight then data.Highlight:Destroy() end
				if data.Billboard then data.Billboard:Destroy() end
				scannedObjs[obj] = nil
			end
		end
	end
	
	-- 更新标签
	local function updateLabels()
		if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
		local myRoot = LocalPlayer.Character.HumanoidRootPart
		
		for obj, data in pairs(scannedObjs) do
			if not obj.Parent then continue end
			if data.Billboard and data.InfoLabel then
				local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
				local info = {}
				if root then
					table.insert(info, math.floor((root.Position - myRoot.Position).Magnitude) .. "m")
				end
				table.insert(info, "HP: " .. math.floor(data.Humanoid.Health) .. "/" .. math.floor(data.Humanoid.MaxHealth))
				data.InfoLabel.Text = table.concat(info, " | ")
			end
		end
	end
	
	-- 主循环
	task.spawn(function()
		print("[ESP] 深度扫描启动...")
		while task.wait(1) do
			pcall(function()
				-- 扫描所有容器
				local containers = {
					Workspace,
				}
				local wsScriptable = Workspace:FindFirstChild("WorkspaceScriptable")
				if wsScriptable then table.insert(containers, wsScriptable) end
				
				-- 也搜索所有其他根级容器
				for _, container in ipairs(Workspace:GetChildren()) do
					if container:IsA("Model") or container:IsA("Folder") then
						table.insert(containers, container)
					end
				end
				
				for _, c in ipairs(containers) do
					deepScan(c, 0)
				end
				
				-- 额外：直接在Workspace找所有带Humanoid的
				for _, obj in ipairs(Workspace:GetDescendants()) do
					if obj:IsA("Humanoid") and obj.Parent and obj.Parent ~= LocalPlayer.Character and not scannedObjs[obj.Parent] then
						local char = obj.Parent
						if char:IsA("Model") and obj.Health > 0 then
							local npcType, color, label = classify(char)
							local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
							local objRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
							if myRoot and objRoot then
								local dist = (objRoot.Position - myRoot.Position).Magnitude
								if dist <= MaxDistance then
									local hl = createHighlight(char, color)
									local bb, mainLbl, infoLbl = createHeadLabel(char, color, label)
									scannedObjs[char] = {
										Highlight = hl,
										Billboard = bb,
										MainLabel = mainLbl,
										InfoLabel = infoLbl,
										Humanoid = obj,
										NPCType = npcType,
									}
									print(string.format("[ESP] Descendant找到: %s | %s", char.Name, npcType))
								end
							end
						end
					end
				end
				
				cleanup()
				updateLabels()
				
				-- 打印调试信息
				local good, bad, unknown = 0, 0, 0
				for _, data in pairs(scannedObjs) do
					if data.NPCType == "Good" then good = good + 1 end
					if data.NPCType == "Bad" then bad = bad + 1 end
					if data.NPCType == "Unknown" then unknown = unknown + 1 end
				end
				print(string.format("[ESP] 统计: 🟢好人=%d | 🔴坏人=%d | ❓未知=%d | 总计=%d", good, bad, unknown, good + bad + unknown))
			end)
		end
	end)
	
	-- F4热键
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.F4 then
			ESPEnabled = not ESPEnabled
			for obj, data in pairs(scannedObjs) do
				if data.Highlight then data.Highlight.Enabled = ESPEnabled end
				if data.Billboard then data.Billboard.Enabled = ESPEnabled end
			end
		end
	end)
	
	print("✅ 机场安全透视 v4.0 (原生模式) 已加载!")
	return
end

-- =====================================================================
-- ======================== WindUI 完整模式 =============================
-- =====================================================================

print("✅ WindUI 加载成功!")

-- ===== 第二步：Popup弹窗让用户决定要不要加载 =====
local shouldLoad = false
local loadComplete = false

WindUI:Popup({
	Title = "🛡️ 机场安全透视",
	Icon = "solar:shield-warning-bold",
	Content = "是否加载机场安全透视脚本？\n\n功能：\n• 自动识别好人/坏人\n• 透视穿墙显示\n• 头顶标签 + 高亮\n• PC按 RightShift 开菜单",
	Buttons = {
		{
			Title = "❌ 不加载",
			Variant = "Tertiary",
			Callback = function()
				shouldLoad = false
				loadComplete = true
			end,
		},
		{
			Title = "✅ 确认加载",
			Icon = "arrow-right",
			Variant = "Primary",
			Callback = function()
				shouldLoad = true
				loadComplete = true
			end,
		},
	},
})

-- 等待用户选择
while not loadComplete do
	task.wait(0.1)
end

if not shouldLoad then
	WindUI:Notify({
		Title = "已取消",
		Content = "脚本已停止加载",
		Duration = 3,
		Icon = "solar:forbidden-circle-bold",
	})
	return
end

-- ===== 用户确认加载，继续 =====
WindUI:Notify({
	Title = "✅ 已确认加载",
	Content = "正在启动透视系统...",
	Duration = 2,
	Icon = "solar:eye-bold",
})

-- 显示原生通知
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "🛡️ 机场安全透视",
		Text = "RightShift = 菜单 | F4 = 透视开关",
		Duration = 8,
	})
end)

-- ===== 加载游戏服务 =====
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ===== 状态 =====
local Settings = {
	Enabled = true,
	ShowBadOnly = false,
	ShowDistance = true,
	ShowHealth = true,
	MaxDistance = 500,
}

local ESPData = {}

-- ===== 创建窗口（默认打开） =====
local Window = WindUI:CreateWindow({
	Title = "机场安全透视",
	Author = "v4.0",
	Folder = "airport_security_esp",
	Icon = "solar:shield-warning-bold",
	Theme = "Dark",
	Size = UDim2.fromOffset(IsMobile and 400 or 650, 480),
	ToggleKey = IsMobile and nil or Enum.KeyCode.RightShift,
	OpenButton = {
		Title = "打开透视",
		Enabled = true,
		Draggable = true,
		Scale = IsMobile and 0.45 or 0.5,
		Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#00D4FF")),
	},
	Resizable = true,
	NewElements = true,
	SideBarWidth = IsMobile and 160 or 200,
	Topbar = {
		Height = IsMobile and 38 or 44,
		ButtonsType = "Mac",
	},
})

-- 默认打开窗口
task.spawn(function()
	task.wait(0.5)
	pcall(function()
		if Window.Toggle then
			Window:Toggle()
		end
	end)
end)

-- ===== 白色滚动条 + 滚动条样式 =====
task.spawn(function()
	task.wait(1.5)
	for _ = 1, 50 do
		task.wait(0.1)
		local found = false
		local obj = Window._Object or Window.Window or Window.Instance
		if obj then
			for _, desc in ipairs(obj:GetDescendants()) do
				if desc:IsA("ScrollingFrame") and desc.AbsoluteSize.Y > 0 then
					-- 白色粗滑块
					desc.ScrollBarThickness = 14
					desc.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
					desc.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200) -- 浅灰色
					-- 修改滚动条背景
					desc.BottomImage = "rbxasset://textures/ui/Scroll/scroll-bottom.png"
					desc.TopImage = "rbxasset://textures/ui/Scroll/scroll-top.png"
					found = true
					break
				end
			end
		end
		if found then break end
	end
end)

-- ===== Tab 1: 主控 =====
local MainTab = Window:Tab({ Title = "主控面板", Icon = "solar:home-2-bold" })

MainTab:Section({ Title = "透视控制", TextSize = 18 })

MainTab:Toggle({
	Flag = "ESPToggle",
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

-- 状态标签
local statusTag = MainTab:Tag({
	Title = "扫描中...",
	Color = Color3.fromRGB(255, 200, 0),
})

MainTab:Toggle({
	Flag = "BadOnlyMode",
	Title = "仅显示坏人",
	Desc = "隐藏好人，只看威胁目标",
	Value = false,
	Callback = function(state)
		Settings.ShowBadOnly = state
		-- 重建ESP
		for _, data in pairs(ESPData) do
			if data.Highlight then data.Highlight:Destroy() end
			if data.Billboard then data.Billboard:Destroy() end
		end
		ESPData = {}
	end,
})

MainTab:Space()
MainTab:Section({ Title = "显示选项", TextSize = 18 })

MainTab:Toggle({
	Flag = "ShowDist", Title = "显示距离", Desc = "头顶标签显示距离", Value = true,
	Callback = function(s) Settings.ShowDistance = s end,
})
MainTab:Toggle({
	Flag = "ShowHP", Title = "显示血量", Desc = "头顶标签显示血量", Value = true,
	Callback = function(s) Settings.ShowHealth = s end,
})

MainTab:Slider({
	Flag = "MaxDist", Title = "最大探测距离", Desc = "鼠标左键拖拽滑块调节",
	Step = 10, Value = { Min = 50, Max = 1000, Default = 500 },
	IsTooltip = true,
	Width = IsMobile and 150 or 200,
	Callback = function(v) Settings.MaxDistance = v end,
})

-- ===== Tab 2: 统计 =====
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

-- ===== Tab 3: 关于 =====
local AboutTab = Window:Tab({ Title = "关于", Icon = "solar:info-square-bold" })

AboutTab:Section({ Title = "机场安全透视 v4.0", TextSize = 24 })
AboutTab:Space()
AboutTab:Paragraph({
	Title = "📖 使用说明",
	Desc = IsMobile
		and "📱 点击绿色按钮打开菜单\nToggle控制透视"
		or "💻 RightShift = 菜单\nF4 = 快速开关透视\n🖱 右侧白色滑块可拖拽",
})

-- =============================================================
-- ======================== ESP 核心 ============================
-- =============================================================

local function createHeadLabel(char, color, mainText)
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	if not head then return nil, nil, nil end
	
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
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	local bgc = Instance.new("UICorner", bg)
	bgc.CornerRadius = UDim.new(0, 6)
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

-- ===== 深度分类器 =====
local function classifyCharacter(obj)
	local name = obj.Name or ""
	local fullPath = obj:GetFullName() or ""
	
	-- 1) 路径匹配（最可靠）
	if fullPath:find("AgentTemplate") or fullPath:find("Agent") then
		return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
	end
	if fullPath:find("NPCTemplate") or fullPath:find("NPC") then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
	end
	
	-- 2) 名字匹配
	local goodPatterns = {"Agent", "Police", "Security", "Guard", "Cop", "SWAT", "Sniper", "Friendly", "Good", "Helper", "Patrol"}
	local badPatterns = {"NPC", "Terrorist", "Enemy", "Hostile", "Threat", "Criminal", "Suspect", "Bad", "Bandit", "Robber", "Rogue", "Bomber", "Invader", "Killer", "Murderer", "Raid"}
	
	for _, pat in ipairs(goodPatterns) do
		if name:find(pat) then return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent" end
	end
	for _, pat in ipairs(badPatterns) do
		if name:find(pat) then return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat" end
	end
	
	-- 3) 扫描所有子级Script对象中的路径
	local foundAgent = false
	local foundNPC = false
	for _, child in ipairs(obj:GetDescendants()) do
		if child:IsA("ModuleScript") or child:IsA("Script") or child:IsA("LocalScript") then
			local cPath = child:GetFullName()
			if cPath:find("NPCTemplate") then foundNPC = true end
			if cPath:find("AgentTemplate") then foundAgent = true end
		end
	end
	
	if foundNPC and not foundAgent then
		return "Bad", Color3.fromRGB(255, 50, 50), "💀 Threat"
	elseif foundAgent and not foundNPC then
		return "Good", Color3.fromRGB(0, 255, 100), "👮 Agent"
	end
	
	-- 默认显示为Unknown
	return "Unknown", Color3.fromRGB(180, 180, 180), "❓ Unknown"
end

-- ===== 深度扫描 =====
local lastDebugMsg = "无"

local function deepScanCharacters(container, depth)
	depth = depth or 0
	if depth > 10 then return end
	
	for _, obj in ipairs(container:GetChildren()) do
		if obj == LocalPlayer.Character then continue end
		if obj:IsA("Terrain") or obj:IsA("Cameras") or obj:IsA("Lighting") then continue end
		
		if ESPData[obj] then
			deepScanCharacters(obj, depth + 1)
			continue
		end
		
		local humanoid = obj:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local npcType, color, label = classifyCharacter(obj)
			
			-- 距离检测
			local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local objRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head") or obj:FindFirstChild("Torso")
			if myRoot and objRoot then
				local dist = (objRoot.Position - myRoot.Position).Magnitude
				if dist > Settings.MaxDistance then
					deepScanCharacters(obj, depth + 1)
					continue
				end
			end
			
			if Settings.ShowBadOnly and npcType ~= "Bad" then
				deepScanCharacters(obj, depth + 1)
				continue
			end
			
			-- 创建ESP
			local hl = createHighlight(obj, color)
			local bb, mainLbl, infoLbl = createHeadLabel(obj, color, label)
			
			ESPData[obj] = {
				Highlight = hl,
				Billboard = bb,
				MainLabel = mainLbl,
				InfoLabel = infoLbl,
				Humanoid = humanoid,
				NPCType = npcType,
			}
			
			lastDebugMsg = obj.Name .. " | " .. npcType
			print(string.format("[ESP] ✅ 发现: %s | 类型: %s | 深度: %d", obj.Name, npcType, depth))
		end
		
		-- 继续递归
		deepScanCharacters(obj, depth + 1)
	end
end

-- ===== 主循环 =====
task.spawn(function()
	print("[ESP] 开始深度扫描...")
	print("[ESP] 玩家: " .. (LocalPlayer.Name or "未知"))
	
	-- 打印Workspace结构
	print(string.format("[ESP] Workspace子级数: %d", #Workspace:GetChildren()))
	
	while task.wait(1) do
		pcall(function()
			-- 扫描Workspace所有层级
			deepScanCharacters(Workspace, 0)
			
			-- 额外：找所有Humanoid的父级（不管藏多深）
			for _, hum in ipairs(Workspace:GetDescendants()) do
				if hum:IsA("Humanoid") and hum.Parent and hum.Health > 0 then
					local char = hum.Parent
					if char:IsA("Model") and char ~= LocalPlayer.Character and not ESPData[char] then
						local npcType, color, label = classifyCharacter(char)
						
						local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						local objRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char:FindFirstChild("Torso")
						if myRoot and objRoot then
							local dist = (objRoot.Position - myRoot.Position).Magnitude
							if dist <= Settings.MaxDistance then
								if Settings.ShowBadOnly and npcType ~= "Bad" then continue end
								
								local hl = createHighlight(char, color)
								local bb, mainLbl, infoLbl = createHeadLabel(char, color, label)
								
								ESPData[char] = {
									Highlight = hl,
									Billboard = bb,
									MainLabel = mainLbl,
									InfoLabel = infoLbl,
									Humanoid = hum,
									NPCType = npcType,
								}
								
								lastDebugMsg = char.Name .. " | " .. npcType
								print(string.format("[ESP] ✅ Descendant发现: %s | %s | 路径: %s", char.Name, npcType, char:GetFullName()))
							end
						end
					end
				end
			end
			
			-- 清理死亡/移除的对象
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
							table.insert(parts, "HP: " .. math.floor(data.Humanoid.Health) .. "/" .. math.floor(data.Humanoid.MaxHealth))
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
			
			pcall(function()
				GoodInput:Set(tostring(good))
				BadInput:Set(tostring(bad))
				UnknownInput:Set(tostring(unknown))
				TotalInput:Set(tostring(good + bad + unknown))
				DebugInput:Set(lastDebugMsg)
				
				-- 更新状态标签
				local total = good + bad + unknown
				if total > 0 then
					pcall(function() statusTag:Update({ Title = string.format("运行中 | %d个目标", total), Color = Color3.fromRGB(0, 255, 100) }) end)
				else
					pcall(function() statusTag:Update({ Title = "扫描中... 未发现目标", Color = Color3.fromRGB(255, 200, 0) }) end)
				end
			end)
		end)
	end
end)

-- ===== F4热键 =====
if not IsMobile then
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.F4 then
			Settings.Enabled = not Settings.Enabled
		end
	end)
end

print("✅ 机场安全透视 v4.0 已加载!")
print("💻 RightShift = 菜单 | F4 = 透视开关")
print("👁 深度扫描模式: 所有子层级 + Descendants")
