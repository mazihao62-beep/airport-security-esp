--[[
	机场安全透视脚本 v3.1 (Airport Security ESP)
	使用 WindUI + Highlight + 头顶标签
	功能：透视 + 头顶标签区分好人与坏人
	
	修复：
	- 修复 About 页面的文本显示逻辑
	- 增加加载确认对话框（Window:Dialog）
	- 窗口自动打开（Window:Open）
	- 递归扫描所有NPC层级
	- 头顶标签 + Highlight 双重标记
--]]

-- ===== 安全加载 WindUI =====
local Success, WindUI = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

-- ===== 服务 =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ===== 备份方案：WindUI 加载失败 =====
if not Success or not WindUI then
	print("WindUI 加载失败，启动原生模式")
	
	local ESPEnabled = true
	local MaxDistance = 500
	local ESPData = {}

	-- 原生 UI
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "AirportESPNative"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Parent = CoreGui

	local MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, 200, 0, 140)
	MainFrame.Position = UDim2.new(0, 10, 0.5, -70)
	MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	MainFrame.BackgroundTransparency = 0.15
	MainFrame.BorderSizePixel = 0
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
	MainFrame.Parent = ScreenGui

	local ToggleBtn = Instance.new("TextButton")
	ToggleBtn.Size = UDim2.new(1, -20, 0, 36)
	ToggleBtn.Position = UDim2.new(0, 10, 0, 10)
	ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
	ToggleBtn.Text = "ESP: ON"
	ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
	ToggleBtn.Font = Enum.Font.GothamBold
	ToggleBtn.TextSize = 16
	Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)
	ToggleBtn.Parent = MainFrame

	local StatusText = Instance.new("TextLabel")
	StatusText.Size = UDim2.new(1, -20, 0, 30)
	StatusText.Position = UDim2.new(0, 10, 0, 50)
	StatusText.BackgroundTransparency = 1
	StatusText.Text = "F4 = 开关 | NPC扫描中..."
	StatusText.TextColor3 = Color3.fromRGB(200, 200, 200)
	StatusText.Font = Enum.Font.Gotham
	StatusText.TextSize = 14
	StatusText.Parent = MainFrame

	local CountText = Instance.new("TextLabel")
	CountText.Size = UDim2.new(1, -20, 0, 30)
	CountText.Position = UDim2.new(0, 10, 0, 82)
	CountText.BackgroundTransparency = 1
	CountText.Text = "Good: 0 | Bad: 0"
	CountText.TextColor3 = Color3.fromRGB(150, 150, 150)
	CountText.Font = Enum.Font.Gotham
	CountText.TextSize = 14
	CountText.Parent = MainFrame

	ToggleBtn.MouseButton1Click:Connect(function()
		ESPEnabled = not ESPEnabled
		ToggleBtn.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
		ToggleBtn.BackgroundColor3 = ESPEnabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
	end)

	-- 通知
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Airport Security ESP",
			Text = "F4 = Toggle | Head labels active",
			Duration = 8,
		})
	end)

	-- 创建头顶标签
	local function createTag(char, color, mainText)
		local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
		if not head then return end

		local bb = Instance.new("BillboardGui")
		bb.Name = "ESP_Tag"
		bb.AlwaysOnTop = true
		bb.Size = UDim2.new(0, 180, 0, 60)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.Adornee = head
		bb.Enabled = ESPEnabled
		bb.Parent = head

		local main = Instance.new("TextLabel")
		main.Size = UDim2.new(1, 0, 0, 28)
		main.BackgroundTransparency = 1
		main.Text = mainText
		main.TextColor3 = color
		main.Font = Enum.Font.GothamBold
		main.TextSize = 18
		main.TextStrokeTransparency = 0.1
		main.TextStrokeColor3 = Color3.new(0, 0, 0)
		main.Parent = bb

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, 0, 0, 20)
		info.Position = UDim2.new(0, 0, 0, 28)
		info.BackgroundTransparency = 1
		info.Text = ""
		info.TextColor3 = Color3.fromRGB(200, 200, 200)
		info.Font = Enum.Font.Gotham
		info.TextSize = 14
		info.TextStrokeTransparency = 0.2
		info.TextStrokeColor3 = Color3.new(0, 0, 0)
		info.Parent = bb

		local hl = Instance.new("Highlight")
		hl.Name = "ESP_HL"
		hl.Adornee = char
		hl.FillColor = color
		hl.FillTransparency = 0.5
		hl.OutlineColor = color
		hl.OutlineTransparency = 0.2
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Enabled = ESPEnabled
		hl.Parent = char

		return bb, main, info, hl
	end

	local function classifyChar(char)
		local name = char.Name or ""
		local p = char.Parent
		while p do
			if p.Name == "AgentTemplate" or p.Name == "Agent" then
				return "Good", Color3.fromRGB(0, 255, 100), "Agent"
			elseif p.Name == "NPCTemplate" or p.Name == "NPC" then
				return "Bad", Color3.fromRGB(255, 50, 50), "Threat"
			end
			p = p.Parent
		end

		local gk = {"Agent","Police","Guard","Security","Friendly","Cop","SWAT","Sniper","Good","Officer","Soldier"}
		local bk = {"NPC","Terrorist","Suspect","Enemy","Hostile","Criminal","Threat","Bad","Bandit","Rogue","Bomber","Invader","Combatant","Mercenary"}
		for _, k in ipairs(gk) do if name:find(k) then return "Good", Color3.fromRGB(0, 255, 100), "Agent" end end
		for _, k in ipairs(bk) do if name:find(k) then return "Bad", Color3.fromRGB(255, 50, 50), "Threat" end end

		local fp = char:GetFullName()
		if fp:find("AgentTemplate") then return "Good", Color3.fromRGB(0, 255, 100), "Agent"
		elseif fp:find("NPCTemplate") then return "Bad", Color3.fromRGB(255, 50, 50), "Threat" end

		local ha, hn = false, false
		for _, c in ipairs(char:GetDescendants()) do
			local cp = c:GetFullName()
			if cp:find("AgentTemplate") then ha = true end
			if cp:find("NPCTemplate") then hn = true end
		end
		if hn then return "Bad", Color3.fromRGB(255, 50, 50), "Threat"
		elseif ha then return "Good", Color3.fromRGB(0, 255, 100), "Agent" end

		return nil
	end

	-- 递归扫描
	local function scanAll()
		local function scan(inst)
			if inst == LocalPlayer.Character then return end
			local hum = inst:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local root = inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("Torso") or inst:FindFirstChild("UpperTorso")
				if root then
					local npcType, color, label = classifyChar(inst)
					if npcType and not ESPData[inst] then
						createTag(inst, color, label)
						ESPData[inst] = { Type = npcType, Humanoid = hum, Color = color }
					end
					return
				end
			end
			for _, child in ipairs(inst:GetChildren()) do
				if not child:IsA("Tool") and not child:IsA("PlayerGui") and not child:IsA("BillboardGui") then
					scan(child)
				end
			end
		end
		for _, obj in ipairs(Workspace:GetChildren()) do scan(obj) end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then scan(plr.Character) end
		end
	end

	local function updateAll()
		if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
		local myRoot = LocalPlayer.Character.HumanoidRootPart
		local good, bad = 0, 0
		for obj, data in pairs(ESPData) do
			if not obj.Parent then
				local hl = obj:FindFirstChild("ESP_HL")
				if hl then hl:Destroy() end
				local head = obj:FindFirstChild("Head") or obj:FindFirstChild("HumanoidRootPart")
				if head then
					local bb = head:FindFirstChild("ESP_Tag")
					if bb then bb:Destroy() end
				end
				ESPData[obj] = nil
			else
				if data.Type == "Good" then good = good + 1 end
				if data.Type == "Bad" then bad = bad + 1 end
				local head = obj:FindFirstChild("Head") or obj:FindFirstChild("HumanoidRootPart")
				if head then
					local bb = head:FindFirstChild("ESP_Tag")
					if bb then
						local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
						local dist = root and math.floor((root.Position - myRoot.Position).Magnitude) .. "m" or ""
						local hp = "HP: " .. math.floor(data.Humanoid.Health) .. "/" .. math.floor(data.Humanoid.MaxHealth)
						for _, lbl in ipairs(bb:GetChildren()) do
							if lbl:IsA("TextLabel") and lbl.Position == UDim2.new(0, 0, 0, 28) then
								lbl.Text = dist .. " | " .. hp
							end
						end
						bb.Enabled = ESPEnabled
					end
				end
				local hl = obj:FindFirstChild("ESP_HL")
				if hl then hl.Enabled = ESPEnabled end
			end
		end
		CountText.Text = "Good: " .. good .. " | Bad: " .. bad
	end

	task.spawn(function()
		while task.wait(0.3) do
			pcall(function() scanAll() updateAll() end)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.F4 then
			ESPEnabled = not ESPEnabled
			ToggleBtn.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
			ToggleBtn.BackgroundColor3 = ESPEnabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
		end
	end)

	print("Airport Security ESP (Native Mode) loaded!")
	print("F4 = Toggle ESP")
	return
end

-- =====================================================================
-- WindUI 模式
-- =====================================================================
print("WindUI loaded! Starting full version...")

local Settings = {
	Enabled = true,
	ShowBadOnly = false,
	ShowDistance = true,
	ShowHealth = true,
	MaxDistance = 500,
}

local ESPData = {}

-- ===== 通知 =====
pcall(function()
	StarterGui:SetCore("SendNotification", {
		Title = "Airport Security ESP Loading...",
		Text = "Please confirm the dialog to start",
		Duration = 5,
	})
end)

-- ===== 创建窗口 =====
local Window = WindUI:CreateWindow({
	Title = "Airport Security",
	Author = "ESP v3.1",
	Folder = "airport_security_esp",
	Icon = "shield",
	Theme = "Dark",
	Size = UDim2.fromOffset(IsMobile and 400 or 620, 450),
	MinSize = Vector2.new(IsMobile and 350 or 520, 350),
	MaxSize = Vector2.new(800, 560),
	ToggleKey = IsMobile and nil or Enum.KeyCode.RightShift,
	Resizable = true,
	NewElements = true,
	HideSearchBar = false,
	SideBarWidth = IsMobile and 150 or 190,
	Topbar = {
		Height = IsMobile and 38 or 44,
		ButtonsType = "Mac",
	},
	OpenButton = {
		Title = "Open ESP",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 3,
		Enabled = true,
		Draggable = true,
		Scale = IsMobile and 0.42 or 0.5,
		Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#00D4FF")),
	},
})

if not Window then
	warn("Failed to create WindUI window!")
	return
end

-- ===== Tab 1 =====
local MainTab = Window:Tab({ Title = "Control", Icon = "home" })
MainTab:Section({ Title = "Status", TextSize = 18 })

MainTab:Toggle({
	Flag = "ESPToggle", Title = "ESP Toggle", Desc = "Enable/disable all ESP",
	Value = Settings.Enabled,
	Callback = function(state)
		Settings.Enabled = state
		for obj, data in pairs(ESPData) do
			if data.Highlight then data.Highlight.Enabled = state end
			if data.Billboard then data.Billboard.Enabled = state end
		end
	end,
})

MainTab:Toggle({
	Flag = "BadOnly", Title = "Bad Only", Desc = "Only show threats",
	Value = false,
	Callback = function(state)
		Settings.ShowBadOnly = state
		for obj, d in pairs(ESPData) do
			if d.Highlight then d.Highlight:Destroy() end
			if d.Billboard then d.Billboard:Destroy() end
		end
		ESPData = {}
	end,
})

MainTab:Space()
MainTab:Section({ Title = "Display", TextSize = 18 })

MainTab:Toggle({ Flag = "ShowDist", Title = "Show Distance", Value = true, Callback = function(s) Settings.ShowDistance = s end })
MainTab:Toggle({ Flag = "ShowHP", Title = "Show Health", Value = true, Callback = function(s) Settings.ShowHealth = s end })

MainTab:Space()
MainTab:Section({ Title = "Range", TextSize = 18 })

MainTab:Slider({
	Flag = "MaxDist", Title = "Max Distance", Desc = "Meters | Drag with mouse",
	Step = 10,
	Value = { Min = 50, Max = 1000, Default = 500 },
	IsTooltip = true,
	Width = IsMobile and 140 or 200,
	Callback = function(v) Settings.MaxDistance = v end,
})

-- ===== Tab 2 =====
local StatsTab = Window:Tab({ Title = "Stats", Icon = "bar-chart-3" })
local SG = StatsTab:Group({})
local GoodInput = SG:Input({ Title = "Good", Value = "0", Locked = true })
SG:Space()
local BadInput = SG:Input({ Title = "Bad", Value = "0", Locked = true })
SG:Space()
local TotalInput = SG:Input({ Title = "Total", Value = "0", Locked = true })

-- ===== Tab 3 =====
local AboutTab = Window:Tab({ Title = "About", Icon = "info" })
AboutTab:Section({ Title = "Airport Security ESP v3.1", TextSize = 24 })
AboutTab:Section({ Title = "WindUI + Highlight + Head Tags", TextSize = IsMobile and 14 or 16, TextTransparency = 0.3 })
AboutTab:Space()
AboutTab:Paragraph({
	Title = "How to Use",
	Desc = IsMobile
		and "Tap the floating green button to open menu\nUse Toggle switches to control ESP"
		or "RightShift = Toggle Menu\nF4 = Toggle ESP\nDrag the scrollbar on the right",
})

-- ===== 创建 ESP =====
local function createESP(char, color, label)
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return nil end

	local bb = Instance.new("BillboardGui")
	bb.Name = "ESP_Tag"
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
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
	bg.Parent = bb

	local mlbl = Instance.new("TextLabel")
	mlbl.Size = UDim2.new(1, -8, 0, 30)
	mlbl.Position = UDim2.new(0, 4, 0, 3)
	mlbl.BackgroundTransparency = 1
	mlbl.Text = label
	mlbl.TextColor3 = color
	mlbl.Font = Enum.Font.GothamBold
	mlbl.TextSize = 16
	mlbl.TextStrokeTransparency = 0
	mlbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	mlbl.TextXAlignment = Enum.TextXAlignment.Center
	mlbl.Parent = bb

	local ilbl = Instance.new("TextLabel")
	ilbl.Size = UDim2.new(1, -8, 0, 22)
	ilbl.Position = UDim2.new(0, 4, 0, 34)
	ilbl.BackgroundTransparency = 1
	ilbl.Text = ""
	ilbl.TextColor3 = Color3.fromRGB(220, 220, 220)
	ilbl.Font = Enum.Font.Gotham
	ilbl.TextSize = 12
	ilbl.TextStrokeTransparency = 0.2
	ilbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	ilbl.TextXAlignment = Enum.TextXAlignment.Center
	ilbl.Parent = bb

	local hl = Instance.new("Highlight")
	hl.Name = "ESP_HL"
	hl.Adornee = char
	hl.FillColor = color
	hl.FillTransparency = 0.5
	hl.OutlineColor = color
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = Settings.Enabled
	hl.Parent = char

	return { Billboard = bb, MainLabel = mlbl, InfoLabel = ilbl, Highlight = hl }
end

-- ===== NPC分类 =====
local function classifyChar(char)
	local name = char.Name or ""
	local p = char.Parent
	while p do
		if p.Name == "AgentTemplate" or p.Name == "Agent" then return "Good", Color3.fromRGB(0, 255, 100), "Agent"
		elseif p.Name == "NPCTemplate" or p.Name == "NPC" then return "Bad", Color3.fromRGB(255, 50, 50), "Threat" end
		p = p.Parent
	end

	local gk = {"Agent","Police","Guard","Security","Friendly","Cop","SWAT","Sniper","Good","Officer","Soldier"}
	local bk = {"NPC","Terrorist","Suspect","Enemy","Hostile","Criminal","Threat","Bad","Bandit","Rogue","Bomber"}
	for _, k in ipairs(gk) do if name:find(k) then return "Good", Color3.fromRGB(0, 255, 100), "Agent" end end
	for _, k in ipairs(bk) do if name:find(k) then return "Bad", Color3.fromRGB(255, 50, 50), "Threat" end end

	local fp = char:GetFullName()
	if fp:find("AgentTemplate") then return "Good", Color3.fromRGB(0, 255, 100), "Agent"
	elseif fp:find("NPCTemplate") then return "Bad", Color3.fromRGB(255, 50, 50), "Threat" end

	local ha, hn = false, false
	for _, c in ipairs(char:GetDescendants()) do
		local cp = c:GetFullName()
		if cp:find("AgentTemplate") then ha = true end
		if cp:find("NPCTemplate") then hn = true end
	end
	if hn then return "Bad", Color3.fromRGB(255, 50, 50), "Threat"
	elseif ha then return "Good", Color3.fromRGB(0, 255, 100), "Agent" end

	return nil
end

-- ===== 递归扫描 =====
local function scanNPCs()
	local function scan(inst)
		if inst == LocalPlayer.Character then return end
		local hum = inst:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local root = inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("Torso") or inst:FindFirstChild("UpperTorso")
			if root then
				if Settings.ShowBadOnly then
					local t, _, _ = classifyChar(inst)
					if t ~= "Bad" then return end
				end
				if not ESPData[inst] then
					local typ, col, lbl = classifyChar(inst)
					if typ then
						local esp = createESP(inst, col, lbl)
						if esp then
							ESPData[inst] = { ESP = esp, Type = typ, Humanoid = hum, Color = col, Label = lbl }
						end
					end
				end
				return
			end
		end
		for _, child in ipairs(inst:GetChildren()) do
			if not child:IsA("Tool") and not child:IsA("PlayerGui") and not child:IsA("BillboardGui") then
				scan(child)
			end
		end
	end
	for _, obj in ipairs(Workspace:GetChildren()) do scan(obj) end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then scan(plr.Character) end
	end
end

-- ===== 更新 ESP =====
local function updateESP()
	if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
	local myRoot = LocalPlayer.Character.HumanoidRootPart
	local good, bad = 0, 0

	for obj, data in pairs(ESPData) do
		if not obj.Parent then
			if data.ESP then
				if data.ESP.Highlight then data.ESP.Highlight:Destroy() end
				if data.ESP.Billboard then data.ESP.Billboard:Destroy() end
			end
			ESPData[obj] = nil
		else
			if data.Type == "Good" then good = good + 1 end
			if data.Type == "Bad" then bad = bad + 1 end

			if data.ESP and data.ESP.InfoLabel then
				local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
				local dist = ""
				local health = ""
				if root and Settings.ShowDistance then dist = math.floor((root.Position - myRoot.Position).Magnitude) .. "m" end
				if Settings.ShowHealth then health = "HP: " .. math.floor(data.Humanoid.Health) .. "/" .. math.floor(data.Humanoid.MaxHealth) end
				local parts = {}
				if dist ~= "" then table.insert(parts, dist) end
				if health ~= "" then table.insert(parts, health) end
				data.ESP.InfoLabel.Text = table.concat(parts, " | ")
				data.ESP.Billboard.Enabled = Settings.Enabled
			end
			if data.ESP and data.ESP.Highlight then
				data.ESP.Highlight.Enabled = Settings.Enabled
			end
		end
	end

	pcall(function()
		GoodInput:Set(tostring(good))
		BadInput:Set(tostring(bad))
		TotalInput:Set(tostring(good + bad))
	end)
end

-- ===== 主循环 =====
task.spawn(function()
	while task.wait(0.3) do
		pcall(function() scanNPCs() updateESP() end)
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

-- ===== 清理 =====
Players.PlayerRemoving:Connect(function()
	for obj, data in pairs(ESPData) do
		if data.ESP then
			if data.ESP.Highlight then data.ESP.Highlight:Destroy() end
			if data.ESP.Billboard then data.ESP.Billboard:Destroy() end
		end
	end
	ESPData = {}
end)

print("Airport Security ESP v3.1 loaded!")

-- ===== 加载确认对话框 =====
Window:Dialog({
	Title = "Airport Security ESP",
	Icon = "shield",
	Content = "Load Airport Security ESP?\n\n"
		.. "Features:\n"
		.. "  Highlight ESP + Head Tags\n"
		.. "  Good/Bad auto detection\n"
		.. "  Real-time distance & HP\n"
		.. "  PC & Mobile support",
	Width = 340,
	Buttons = {
		{
			Title = "Load",
			Variant = "Primary",
			Callback = function()
				Window:Open()
				task.spawn(function()
					task.wait(0.3)
					WindUI:Notify({
						Title = "ESP Active",
						Content = IsMobile and "Tap button to reopen menu" or "RightShift=Menu | F4=Toggle",
						Icon = "shield-check",
						Duration = 5,
					})
				end)
			end,
		},
		{
			Title = "Cancel",
			Variant = "Secondary",
			Callback = function()
				Window:Destroy()
			end,
		},
	},
})
