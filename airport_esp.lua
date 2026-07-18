--[[
	机场安全透视脚本 (Airport Security ESP)
	使用 WindUI 库制作界面
	功能：透视区分好人与坏人
	
	识别机制：
	- 好人 (Agent) → 绿色方框
	- 坏人 (NPC Template) → 红色方框
	
	仓库: https://github.com/mazihao62-beep/airport-security-esp
--]]

-- ===== 加载 WindUI =====
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- ===== 服务 =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ===== 创建窗口 =====
local Window = WindUI:CreateWindow({
	Title = "机场安全透视",
	Author = "Airport Security",
	Folder = "airport_security_esp",
	Icon = "solar:shield-warning-bold",
	Theme = "Dark",
	Size = UDim2.fromOffset(650, 480),
	MinSize = Vector2.new(560, 350),
	MaxSize = Vector2.new(850, 560),
	ToggleKey = Enum.KeyCode.RightShift,
	Resizable = true,
	NewElements = true,
	HideSearchBar = false,
	SideBarWidth = 200,
	Topbar = {
		Height = 44,
		ButtonsType = "Mac",
	},
})

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
	Desc = "单位：米，超出范围不显示",
	Step = 10,
	Value = {
		Min = 50,
		Max = 1000,
		Default = Settings.MaxDistance,
	},
	IsTooltip = true,
	IsTextbox = false,
	Width = 200,
	Callback = function(value)
		Settings.MaxDistance = value
	end,
})

-- ===== Tab 2: 信息统计 =====
local StatsTab = Window:Tab({
	Title = "信息统计",
	Icon = "solar:chart-2-bold",
})

-- 使用 Input Locked 方式显示统计数据
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
	Title = "机场安全透视系统 v1.0",
	TextSize = 24,
})

AboutTab:Section({
	Title = "基于 WindUI 库构建 | 自动区分好人与坏人",
	TextSize = 16,
	TextTransparency = 0.3,
})

AboutTab:Space()

AboutTab:Paragraph({
	Title = "使用说明",
	Desc = "本脚本自动扫描Workspace中的NPC角色，通过名字/路径检测自动区分好人与坏人。\n\nRightShift = 菜单开关\nF4 = 透视开关",
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

	-- 更新统计UI（使用 :Set() 方法）
	if GoodInput then GoodInput:Set(tostring(goodCount)) end
	if BadInput then BadInput:Set(tostring(badCount)) end
	if TotalInput then TotalInput:Set(tostring(goodCount + badCount)) end
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

-- ===== 启动通知 =====
WindUI:Notify({
	Title = "🛡️ 机场安全透视已加载",
	Content = "按 RightShift 开关菜单 | F4 切换透视",
	Icon = "solar:shield-warning-bold",
	Duration = 5,
})

-- ===== F4 热键 =====
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

print("🛡️ 机场安全透视脚本已加载! (WindUI)")
print("RightShift = 菜单 | F4 = 透视开关")
