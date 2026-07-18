--[[
	机场安全透视脚本 (Airport Security ESP)
	功能：透视区分好人与坏人
	
	识别机制：
	- 好人 (Agent) → 绿色方框
	- 坏人 (NPC Template) → 红色方框
	
	热键:
	F4 = 开关
	F5 = 仅显示坏人
	F6 = 显示全部
--]]

-- ===== 配置区 =====
local Settings = {
	Enabled = true,
	ShowBadOnly = false,
	ShowName = true,
	ShowDistance = true,
	ShowHealth = true,
	MaxDistance = 500,
	BoxColor_Good = Color3.fromRGB(0, 255, 100),
	BoxColor_Bad = Color3.fromRGB(255, 50, 50),
	BoxColor_Unknown = Color3.fromRGB(255, 255, 255),
	Thickness = 2,
}

-- ===== 服务 =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ===== 创建UI =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AirportSecurityESP"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

-- 主悬浮窗
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 140)
MainFrame.Position = UDim2.new(0, 20, 0, 200)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BackgroundTransparency = 0.15
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- 彩虹边框
local RainbowFrame = Instance.new("Frame")
RainbowFrame.Size = UDim2.new(1, 4, 1, 4)
RainbowFrame.Position = UDim2.new(0, -2, 0, -2)
RainbowFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
RainbowFrame.BackgroundTransparency = 0
RainbowFrame.BorderSizePixel = 0
RainbowFrame.ZIndex = -1
RainbowFrame.Parent = MainFrame

-- 标题
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "🛡️ Airport Security"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

-- 状态指示
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 25)
StatusLabel.Position = UDim2.new(0, 0, 0, 35)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "[ESP] 已开启"
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
StatusLabel.TextScaled = true
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Parent = MainFrame

-- 坏人计数
local BadCount = Instance.new("TextLabel")
BadCount.Size = UDim2.new(1, 0, 0, 25)
BadCount.Position = UDim2.new(0, 0, 0, 60)
BadCount.BackgroundTransparency = 1
BadCount.Text = "🔴 Threat: 0"
BadCount.TextColor3 = Color3.fromRGB(255, 100, 100)
BadCount.TextScaled = true
BadCount.Font = Enum.Font.GothamBold
BadCount.Parent = MainFrame

-- 好人计数
local GoodCount = Instance.new("TextLabel")
GoodCount.Size = UDim2.new(1, 0, 0, 25)
GoodCount.Position = UDim2.new(0, 0, 0, 85)
GoodCount.BackgroundTransparency = 1
GoodCount.Text = "🟢 Friendly: 0"
GoodCount.TextColor3 = Color3.fromRGB(100, 255, 100)
GoodCount.TextScaled = true
GoodCount.Font = Enum.Font.GothamBold
GoodCount.Parent = MainFrame

-- 底部提示
local Hint = Instance.new("TextLabel")
Hint.Size = UDim2.new(1, 0, 0, 20)
Hint.Position = UDim2.new(0, 0, 0, 115)
Hint.BackgroundTransparency = 1
Hint.Text = "F4:Toggle | F5:Threats Only"
Hint.TextColor3 = Color3.fromRGB(180, 180, 180)
Hint.TextScaled = true
Hint.Font = Enum.Font.Gotham
Hint.Parent = MainFrame

-- ===== 彩虹边框动画 =====
coroutine.wrap(function()
	local hue = 0
	while true do
		hue = (hue + 0.005) % 1
		RainbowFrame.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		task.wait(0.03)
	end
end)()

-- ===== ESP渲染系统 =====
local ESPObjects = {}

local function createESP(character, color, label)
	-- BoxHandleAdornment 方框
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
	
	-- BillboardGui 标签
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
	local fullName = character:GetFullName()
	
	-- 检查父级路径中是否包含AgentTemplate或NPCTemplate
	local parent = character.Parent
	while parent do
		local pName = parent.Name
		if pName == "AgentTemplate" then
			return "Good", Settings.BoxColor_Good, "👮 Agent"
		elseif pName == "NPCTemplate" then
			return "Bad", Settings.BoxColor_Bad, "💀 Threat"
		end
		local pClass = parent.ClassName
		parent = parent.Parent
	end
	
	-- 通过名字前缀判断
	if name:match("^Agent") or name:match("Police") or name:match("Guard") or name:match("Security") then
		return "Good", Settings.BoxColor_Good, "👮 Agent"
	elseif name:match("^NPC") or name:match("Terrorist") or name:match("Suspect") or name:match("Enemy") or name:match("Hostile") or name:match("Criminal") or name:match("Threat") or name:match("Bad") then
		return "Bad", Settings.BoxColor_Bad, "💀 Threat"
	end
	
	-- 检查Descendants中是否有标识性模块
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
	
	for _, obj in ipairs(workspace:GetChildren()) do
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
		
		-- 距离检查
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
		
		-- 更新信息文字
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
	
	-- 清理
	for char, esp in pairs(ESPObjects) do
		if not char.Parent then
			removeESP(char)
		end
	end
	
	BadCount.Text = "🔴 Threat: " .. badCount
	GoodCount.Text = "🟢 Friendly: " .. goodCount
end

-- ===== 主循环 =====
RunService.RenderStepped:Connect(function()
	if Settings.Enabled then
		updateESP()
	end
end)

-- ===== 热键控制 =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.F4 then
		Settings.Enabled = not Settings.Enabled
		if Settings.Enabled then
			StatusLabel.Text = "[ESP] ON"
			StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
		else
			StatusLabel.Text = "[ESP] OFF"
			StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			for char, esp in pairs(ESPObjects) do
				esp.Box.Visible = false
				esp.Billboard.Enabled = false
			end
			BadCount.Text = "🔴 Threat: 0"
			GoodCount.Text = "🟢 Friendly: 0"
		end
		
	elseif input.KeyCode == Enum.KeyCode.F5 then
		Settings.ShowBadOnly = not Settings.ShowBadOnly
		if Settings.ShowBadOnly then
			StatusLabel.Text = "[MODE] Threats Only"
			StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		else
			StatusLabel.Text = "[ESP] ON"
			StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
		end
		for char, esp in pairs(ESPObjects) do
			esp.Box:Destroy()
			esp.Billboard:Destroy()
		end
		ESPObjects = {}
	end
end)

-- ===== 玩家退出清理 =====
Players.PlayerRemoving:Connect(function()
	for char, esp in pairs(ESPObjects) do
		removeESP(char)
	end
end)

print("🛡️ Airport Security ESP Loaded!")
print("[F4] Toggle ESP | [F5] Threats Only")
