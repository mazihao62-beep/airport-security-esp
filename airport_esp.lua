--[[
    机场安全透视脚本 v6.4
    作者: b站英吉利超入_
    功能: ESP透视 + 好人/坏人识别 + 自定义快捷键
]]

-- ========== 配置区 ==========
local Settings = {
    Enabled = false,        -- 透视总开关 (默认关闭)
    BadOnly = false,        -- 仅显示坏人
    ShowDistance = false,   -- 显示距离 (默认关闭)
    ShowHealth = false,     -- 显示血量 (默认关闭)
    MaxRange = 500,         -- 最大探测距离
    WindowKey = Enum.KeyCode.RightShift,  -- 窗口快捷键
    ESPKey = nil,           -- 透视快捷键
    BadOnlyKey = nil,       -- 仅坏人快捷键
    ShowFloatingButton = true, -- 显示悬浮按钮
}

-- ========== 加载 WindUI ==========
local WindUI, WindUIReady, LoadSuccess
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

-- 检测平台
local IsMobile = pcall(function() return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end) and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ========== WindUI 加载 ==========
local loadWindUI = function()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/footagesus/WindUI/main/module"))()
    end)
    return success, result
end

local s, w = loadWindUI()
if s and w then
    WindUI = w
    WindUIReady = true
    LoadSuccess = true
    pcall(function() WindUI:SetTheme("Dark") end)
else
    WindUIReady = false
    LoadSuccess = false
end

-- ========== WindUI 加载失败则回退到原生 UI ==========
if not LoadSuccess then
    -- 简单确认弹窗
    local msg = Instance.new("Message")
    msg.Text = "⚠️ WindUI 加载失败，已切换为原生模式"
    msg.Parent = Workspace
    task.delay(3, function() msg:Destroy() end)
end

-- ========== 变量 ==========
local ESPObjects = {} -- {Character = {Highlight = ..., Billboard = ...}}
local TrackedNPCs = {} -- {[Character] = Type}
local IsScanning = false
local WindowVisible = false
local FloatingButton = nil
local FloatingButtonGui = nil
local WindowRef = nil
local IsMobileMode = IsMobile

-- 统计
local Stats = {Good = 0, Bad = 0, Total = 0}

-- UI 控件引用
local Controls = {}

-- 快捷键绑定
local Keybinds = {
    Window = Settings.WindowKey,
    ESP = nil,
    BadOnly = nil,
}

-- ========== NPC 分类器 ==========
local function classifyNPC(character, humanoid)
    local name = character.Name or ""
    
    -- 方法1: NPCType 属性 (最可靠)
    local npcType = nil
    if humanoid then
        pcall(function() npcType = humanoid:GetAttribute("NPCType") end)
    end
    if npcType == "Agent" then
        return "Good"
    elseif npcType == "Enemy" then
        return "Bad"
    end
    
    -- 方法2: 中文名称匹配
    local goodKeywordsCN = {"警察", "保安", "警卫", "警", "守卫", "士兵", "军官", "长官", "巡逻"}
    local badKeywordsCN = {"恐怖", "匪徒", "匪", "敌人", "坏", "犯罪", "袭击", "暴徒", "杀手"}
    
    for _, kw in ipairs(goodKeywordsCN) do
        if name:find(kw) then return "Good" end
    end
    for _, kw in ipairs(badKeywordsCN) do
        if name:find(kw) then return "Bad" end
    end
    
    -- 方法3: 英文名称匹配
    local goodKeywordsEN = {"Police", "Security", "Guard", "Agent", "Officer", "Sheriff", "Soldier", "Patrol"}
    local badKeywordsEN = {"Terrorist", "Enemy", "Hostile", "Criminal", "Threat", "Suspect", "Bandit"}
    
    for _, kw in ipairs(goodKeywordsEN) do
        if name:find(kw, 1, true) then return "Good" end
    end
    for _, kw in ipairs(badKeywordsEN) do
        if name:find(kw, 1, true) then return "Bad" end
    end
    
    -- 方法4: 路径检测
    local path = ""
    pcall(function() 
        local p = character:GetFullName()
        path = p
    end)
    
    if path:find("AgentTemplate") then
        return "Good"
    end
    if path:find("NPCTemplate") then
        return "Bad"
    end
    
    -- 方法5: TeamColor
    if humanoid then
        local tc = humanoid.TeamColor
        if tc then
            if tc.Name == "Bright blue" or tc.Name == "Bright green" or tc.Name == "White" then
                return "Good"
            elseif tc.Name == "Bright red" or tc.Name == "Bright orange" or tc.Name == "Brown" then
                return "Bad"
            end
        end
    end
    
    -- 方法6: 工具检测
    if character:FindFirstChildOfClass("Tool") then
        local tool = character:FindFirstChildOfClass("Tool")
        local tName = tool.Name or ""
        if tName:find("Arrest") or tName:find("Taser") or tName:find("Bat") or tName:find("Gun") then
            return "Good"
        end
    end
    
    -- 无法判断则跳过
    return nil
end

-- ========== 判断是否为真实玩家 ==========
local function isRealPlayer(character)
    if not character then return false end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == character then
            return true
        end
    end
    return false
end

-- ========== 创建/更新 ESP ==========
local function createESP(character, npcType)
    if not character or not character.Parent then return end
    
    -- 过滤真实玩家
    if isRealPlayer(character) then return end
    
    -- 检查是否已存在
    if ESPObjects[character] then
        -- 更新颜色
        local color = npcType == "Good" and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
        if ESPObjects[character].Highlight then
            ESPObjects[character].Highlight.FillColor = color
            ESPObjects[character].Highlight.Enabled = Settings.Enabled
        end
        if ESPObjects[character].Billboard then
            ESPObjects[character].Billboard.Enabled = Settings.Enabled
        end
        return
    end
    
    -- 检查范围
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChildOfClass("Part")
    if not root then return end
    
    local myRoot = nil
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    if myChar then
        myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso")
    end
    
    if myRoot and root then
        local dist = (root.Position - myRoot.Position).Magnitude
        if dist > Settings.MaxRange then return end
    end
    
    -- 创建 Highlight
    local highlight = Instance.new("Highlight")
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.4
    highlight.OutlineTransparency = 0.2
    highlight.FillColor = npcType == "Good" and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Enabled = Settings.Enabled
    highlight.Parent = CoreGui
    
    -- 创建 Billboard (头顶标签)
    local head = character:FindFirstChild("Head") or character:FindFirstChild("Torso") or root
    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 160, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = Settings.Enabled
    billboard.Parent = CoreGui
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.6, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.BackgroundTransparency = 0.5
    label.TextColor3 = npcType == "Good" and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Text = npcType == "Good" and "👮 好人" or "💀 坏人"
    label.BorderSizePixel = 0
    label.Parent = billboard
    
    local infoLine = Instance.new("TextLabel")
    infoLine.Size = UDim2.new(1, 0, 0.4, 0)
    infoLine.Position = UDim2.new(0, 0, 0.6, 0)
    infoLine.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    infoLine.BackgroundTransparency = 0.5
    infoLine.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoLine.TextScaled = true
    infoLine.Font = Enum.Font.SourceSans
    infoLine.Text = ""
    infoLine.BorderSizePixel = 0
    infoLine.Parent = billboard
    
    -- 存储
    ESPObjects[character] = {
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        InfoLine = infoLine,
        Head = head,
        Root = root,
    }
    
    -- 更新统计
    if npcType == "Good" then
        Stats.Good = Stats.Good + 1
    else
        Stats.Bad = Stats.Bad + 1
    end
    Stats.Total = Stats.Total + 1
    TrackedNPCs[character] = npcType
end

-- ========== 移除 ESP ==========
local function removeESP(character)
    if ESPObjects[character] then
        local obj = ESPObjects[character]
        if obj.Highlight then pcall(function() obj.Highlight:Destroy() end) end
        if obj.Billboard then pcall(function() obj.Billboard:Destroy() end) end
        ESPObjects[character] = nil
        
        local npcType = TrackedNPCs[character]
        if npcType == "Good" then
            Stats.Good = math.max(0, Stats.Good - 1)
        elseif npcType == "Bad" then
            Stats.Bad = math.max(0, Stats.Bad - 1)
        end
        Stats.Total = math.max(0, Stats.Total - 1)
        TrackedNPCs[character] = nil
    end
end

-- ========== 清理无效 ESP ==========
local function cleanESP()
    for char, _ in pairs(ESPObjects) do
        if not char or not char.Parent then
            removeESP(char)
        end
    end
end

-- ========== 更新标签信息 ==========
local function updateLabels()
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    
    for char, obj in pairs(ESPObjects) do
        if obj.Billboard and obj.Billboard.Enabled then
            local infoParts = {}
            
            if Settings.ShowDistance and myRoot and obj.Root then
                local dist = math.floor((obj.Root.Position - myRoot.Position).Magnitude + 0.5)
                table.insert(infoParts, dist .. "m")
            end
            
            if Settings.ShowHealth then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local hp = math.floor(hum.Health + 0.5)
                    local maxHp = math.floor(hum.MaxHealth + 0.5)
                    table.insert(infoParts, "HP:" .. hp .. "/" .. maxHp)
                end
            end
            
            obj.InfoLine.Text = table.concat(infoParts, " | ")
        end
    end
end

-- ========== 更新所有 ESP 状态 ==========
local function updateAllESP()
    for char, obj in pairs(ESPObjects) do
        if obj.Highlight then
            obj.Highlight.Enabled = Settings.Enabled
        end
        if obj.Billboard then
            obj.Billboard.Enabled = Settings.Enabled
        end
    end
end

-- ========== 更新仅显示坏人模式 ==========
local function updateBadOnlyMode()
    for char, npcType in pairs(TrackedNPCs) do
        if ESPObjects[char] and ESPObjects[char].Highlight then
            if Settings.Enabled then
                if Settings.BadOnly then
                    ESPObjects[char].Highlight.Enabled = (npcType == "Bad")
                    if ESPObjects[char].Billboard then
                        ESPObjects[char].Billboard.Enabled = (npcType == "Bad")
                    end
                else
                    ESPObjects[char].Highlight.Enabled = true
                    if ESPObjects[char].Billboard then
                        ESPObjects[char].Billboard.Enabled = true
                    end
                end
            else
                ESPObjects[char].Highlight.Enabled = false
                if ESPObjects[char].Billboard then
                    ESPObjects[char].Billboard.Enabled = false
                end
            end
        end
    end
end

-- ========== 扫描 NPC ==========
local function scanNPCs()
    if IsScanning then return end
    IsScanning = true
    
    local scanSuccess, _ = pcall(function()
        local descendants = Workspace:GetDescendants()
        
        for _, obj in ipairs(descendants) do
            if not LoadSuccess then break end
            
            local humanoid = nil
            local character = nil
            
            if obj:IsA("Humanoid") then
                humanoid = obj
                character = obj.Parent
            end
            
            if character and humanoid then
                -- 检查是否已经在追踪列表中
                if not TrackedNPCs[character] then
                    -- 过滤真实玩家
                    if not isRealPlayer(character) then
                        local npcType = classifyNPC(character, humanoid)
                        if npcType then
                            createESP(character, npcType)
                            pcall(function()
                                print("[ESP] " .. (npcType == "Good" and "🟢" or "🔴") .. " " .. character.Name .. " | " .. (npcType == "Good" and "好人" or "坏人"))
                            end)
                        end
                    end
                end
            end
            
            task.wait()
        end
    end)
    
    -- 第二遍: 找 Head 部件但没 Humanoid 的角色
    pcall(function()
        local allHeads = Workspace:FindFirstChildOfClass("Model") and Workspace:GetDescendants() or {}
        for _, obj in ipairs(descendants) do
            if obj.Name == "Head" and obj:IsA("BasePart") and not obj:IsA("Tool") then
                local model = obj.Parent
                if model and model:IsA("Model") and not TrackedNPCs[model] and not isRealPlayer(model) then
                    local humanoid = model:FindFirstChildOfClass("Humanoid")
                    if not humanoid then
                        -- 有头但没人形，尝试分类
                        local npcType = classifyNPC(model, nil)
                        if npcType then
                            createESP(model, npcType)
                            pcall(function()
                                print("[ESP] " .. (npcType == "Good" and "🟢" or "🔴") .. " " .. model.Name .. " | Head-only | " .. (npcType == "Good" and "好人" or "坏人"))
                            end)
                        end
                    end
                end
            end
            task.wait()
        end
    end)
    
    IsScanning = false
end

-- ========== 美化滚动条和滑块 ==========
local function beautifyUI()
    -- 白色滚动条
    pcall(function()
        for _, scrl in ipairs(CoreGui:GetDescendants()) do
            if scrl:IsA("ScrollingFrame") then
                scrl.ScrollBarThickness = 14
                scrl.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
                scrl.ScrollBarImageTransparency = 0.2
            end
        end
    end)
    
    -- 白色Slider圆点
    pcall(function()
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                local s = obj.Size
                if s.X.Offset <= 30 and s.X.Offset > 0 and s.Y.Offset <= 30 and s.Y.Offset > 0 then
                    local parent = obj.Parent
                    if parent and parent:IsA("Frame") then
                        obj.ImageColor3 = Color3.fromRGB(255, 255, 255)
                        obj.ImageTransparency = 0.1
                        obj.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        obj.BackgroundTransparency = 0.1
                    end
                end
            end
        end
    end)
end

-- ========== 创建 WindUI 界面 ==========
if LoadSuccess then
    -- 先确认一下 Popup 和 Notify 是否可用
    pcall(function()
        -- Popup 确认弹窗
        WindUI:Popup({
            Title = "机场安全透视",
            Text = "是否加载透视脚本？",
            Type = "Accept",
            Callback = function(v)
                if v then
                    -- 用户确认加载
                    pcall(function()
                        WindUI:Notify({
                            Title = "✅ 已加载",
                            Text = "按 RightShift 打开/关闭菜单",
                            Time = 3,
                        })
                    end)
                else
                    -- 用户取消加载
                    return
                end
            end
        })
    end)
    
    -- 等待弹窗响应
    task.wait(1)
    
    -- 创建窗口
    local win = WindUI:Window({
        Title = "机场安全透视 - b站英吉利超入_",
        Size = Vector2.new(750, 520),
        ToggleKey = Settings.WindowKey,
        Toggle = false, -- 默认关闭
        CanClose = true,
        CanMinimize = false,
        Resizable = false,
        Mobile = IsMobileMode,
    })
    WindowRef = win
    
    -- 主控面板 Tab
    local mainTab = win:Tab("主控面板")
    
    mainTab:Paragraph("👁 透视控制")
    
    Controls.ESPToggle = mainTab:Toggle({
        Title = "透视开关",
        Value = false,
        Callback = function(v)
            Settings.Enabled = v
            updateAllESP()
            if not v then
                updateBadOnlyMode()
            end
        end
    })
    
    Controls.BadOnlyToggle = mainTab:Toggle({
        Title = "仅显示坏人",
        Value = false,
        Callback = function(v)
            Settings.BadOnly = v
            updateBadOnlyMode()
        end
    })
    
    mainTab:Divider()
    mainTab:Paragraph("📐 显示设置")
    
    Controls.DistanceToggle = mainTab:Toggle({
        Title = "显示距离",
        Value = false,
        Callback = function(v)
            Settings.ShowDistance = v
        end
    })
    
    Controls.HealthToggle = mainTab:Toggle({
        Title = "显示血量",
        Value = false,
        Callback = function(v)
            Settings.ShowHealth = v
        end
    })
    
    mainTab:Divider()
    
    Controls.RangeSlider = mainTab:Slider({
        Title = "最大探测距离",
        Value = 500,
        Min = 50,
        Max = 1000,
        Increment = 50,
        Callback = function(v)
            Settings.MaxRange = v
        end
    })
    
    -- 功能设置 Tab
    local funcTab = win:Tab("功能设置")
    
    funcTab:Paragraph("🔑 快捷键设置（点击后按键盘绑定）")
    
    Controls.ESPKeybind = funcTab:Keybind({
        Title = "透视开关快捷键",
        Value = nil,
        Callback = function(key)
            Keybinds.ESP = key
            Settings.ESPKey = key
        end
    })
    
    Controls.BadOnlyKeybind = funcTab:Keybind({
        Title = "仅坏人模式快捷键",
        Value = nil,
        Callback = function(key)
            Keybinds.BadOnly = key
            Settings.BadOnlyKey = key
        end
    })
    
    funcTab:Divider()
    funcTab:Paragraph("💡 提示: 在UI设置中可绑定窗口开关快捷键")
    
    -- UI设置 Tab
    local uiTab = win:Tab("UI设置")
    
    uiTab:Paragraph("⚙️ 界面设置")
    
    Controls.WindowKeybind = uiTab:Keybind({
        Title = "窗口开关快捷键",
        Value = Settings.WindowKey,
        Callback = function(key)
            Keybinds.Window = key
            Settings.WindowKey = key
            pcall(function() win:Update({ToggleKey = key}) end)
        end
    })
    
    Controls.FloatingBtnToggle = uiTab:Toggle({
        Title = "显示悬浮按钮",
        Value = IsMobileMode,
        Callback = function(v)
            Settings.ShowFloatingButton = v
            if FloatingButtonGui then
                FloatingButtonGui.Enabled = v
            end
        end
    })
    
    uiTab:Divider()
    uiTab:Paragraph("💡 提示: 窗口默认隐藏，请设置快捷键或使用悬浮按钮")
    
    -- 信息统计 Tab
    local statsTab = win:Tab("信息统计")
    
    local goodCountP = statsTab:Paragraph("🟢 好人: 0")
    local badCountP = statsTab:Paragraph("🔴 坏人: 0")
    local totalCountP = statsTab:Paragraph("📊 总计: 0")
    
    statsTab:Divider()
    
    local scanStatusI = statsTab:Input({
        Title = "扫描状态",
        Value = "等待扫描...",
        Multiline = false,
        Locked = true,
    })
    
    local debugI = statsTab:Input({
        Title = "最近发现",
        Value = "无",
        Multiline = false,
        Locked = true,
    })
    
    -- 关于 Tab
    local aboutTab = win:Tab("关于")
    
    aboutTab:Paragraph({
        Title = "机场安全透视 v6.4",
        Desc = "用于分辨好人与坏人的透视脚本"
    })
    
    aboutTab:Divider()
    
    aboutTab:Paragraph({
        Title = "👤 作者",
        Desc = "b站英吉利超入_"
    })
    
    aboutTab:Divider()
    
    aboutTab:Paragraph({
        Title = "💡 使用说明",
        Desc = IsMobileMode and "手机: 点击悬浮按钮打开菜单" or "PC: 按 RightShift 打开/关闭菜单"
    })
    
    aboutTab:Paragraph({
        Title = "⚠️ 提示",
        Desc = "所有功能默认关闭，请在菜单中手动开启"
    })
    
    aboutTab:Button({
        Title = "📦 GitHub",
        Callback = function()
            pcall(function()
                WindUI:Notify({Title = "仓库地址", Text = "github.com/mazihao62-beep/airport-security-esp", Time = 3})
            end)
        end
    })
    
    -- 更新信息统计主循环
    task.spawn(function()
        while LoadSuccess do
            pcall(function()
                goodCountP:SetTitle("🟢 好人: " .. Stats.Good)
                badCountP:SetTitle("🔴 坏人: " .. Stats.Bad)
                totalCountP:SetTitle("📊 总计: " .. Stats.Total)
                
                scanStatusI:Set({Value = IsScanning and "📡 扫描中..." or "✅ 就绪"})
                
                updateLabels()
            end)
            task.wait(0.5)
        end
    end)
    
    -- 美化 UI
    task.spawn(function()
        task.wait(1)
        beautifyUI()
    end)
    
    -- 生成手机悬浮按钮
    if IsMobileMode or Settings.ShowFloatingButton then
        task.spawn(function()
            task.wait(1.5)
            pcall(function()
                FloatingButtonGui = Instance.new("ScreenGui")
                FloatingButtonGui.Name = "AirportESPFloatingBtn"
                FloatingButtonGui.Enabled = true
                FloatingButtonGui.Parent = CoreGui
                FloatingButtonGui.ResetOnSpawn = false
                
                FloatingButton = Instance.new("ImageButton")
                FloatingButton.Size = UDim2.new(0, 50, 0, 50)
                FloatingButton.Position = UDim2.new(0.9, -25, 0.8, -25)
                FloatingButton.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
                FloatingButton.BackgroundTransparency = 0.2
                FloatingButton.BorderSizePixel = 0
                FloatingButton.Image = "rbxassetid://0"  -- 纯色
                FloatingButton.Parent = FloatingButtonGui
                
                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 25)
                btnCorner.Parent = FloatingButton
                
                local btnText = Instance.new("TextLabel")
                btnText.Size = UDim2.new(1, 0, 1, 0)
                btnText.BackgroundTransparency = 1
                btnText.Text = "👁"
                btnText.TextScaled = true
                btnText.Font = Enum.Font.SourceSansBold
                btnText.TextColor3 = Color3.fromRGB(255, 255, 255)
                btnText.Parent = FloatingButton
                
                -- 拖拽功能
                local dragging = false
                local dragStart = nil
                local startPos = nil
                
                FloatingButton.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        dragStart = input.Position
                        startPos = FloatingButton.Position
                    end
                end)
                
                FloatingButton.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                        local delta = input.Position - dragStart
                        FloatingButton.Position = UDim2.new(
                            startPos.X.Scale, startPos.X.Offset + delta.X,
                            startPos.Y.Scale, startPos.Y.Offset + delta.Y
                        )
                    end
                end)
                
                FloatingButton.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                
                -- 点击切换窗口
                FloatingButton.MouseButton1Click:Connect(function()
                    if WindowRef then
                        WindowVisible = not WindowVisible
                        pcall(function()
                            if WindowVisible then
                                win:Open()
                            else
                                win:Close()
                            end
                        end)
                    end
                end)
            end)
        end)
    end
    
    -- 主循环
    task.spawn(function()
        while LoadSuccess do
            pcall(function()
                cleanESP()
                if Settings.Enabled then
                    scanNPCs()
                end
            end)
            task.wait(2)
        end
    end)
    
    -- 快捷键监听
    task.spawn(function()
        while LoadSuccess do
            local input = UserInputService.InputBegan:Wait()
            pcall(function()
                -- 窗口快捷键
                if Keybinds.Window and input.KeyCode == Keybinds.Window then
                    WindowVisible = not WindowVisible
                    if WindowVisible then
                        win:Open()
                    else
                        win:Close()
                    end
                end
                
                -- 透视快捷键
                if Keybinds.ESP and input.KeyCode == Keybinds.ESP then
                    Settings.Enabled = not Settings.Enabled
                    if Controls.ESPToggle then
                        pcall(function() Controls.ESPToggle:Set(Settings.Enabled) end)
                    end
                    updateAllESP()
                    if not Settings.Enabled then
                        updateBadOnlyMode()
                    end
                end
                
                -- 仅坏人快捷键
                if Keybinds.BadOnly and input.KeyCode == Keybinds.BadOnly then
                    Settings.BadOnly = not Settings.BadOnly
                    if Controls.BadOnlyToggle then
                        pcall(function() Controls.BadOnlyToggle:Set(Settings.BadOnly) end)
                    end
                    updateBadOnlyMode()
                end
            end)
        end
    end)
    
    -- Roblox 原生通知（提示操作方式）
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "机场安全透视 v6.4",
            Text = IsMobileMode and "👆 点击绿色悬浮按钮打开菜单" or "⌨️ 按 RightShift 打开/关闭菜单\n所有功能默认关闭，请手动开启",
            Duration = 5,
        })
    end)
end

-- ========== 原生模式（WindUI加载失败时使用） ==========
if not LoadSuccess then
    -- 悬浮按钮
    local btnGui = Instance.new("ScreenGui")
    btnGui.Name = "AirportESP_Btn"
    btnGui.ResetOnSpawn = false
    btnGui.Parent = CoreGui
    
    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(0, 50, 0, 50)
    btn.Position = UDim2.new(0.9, -25, 0.8, -25)
    btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    btn.BackgroundTransparency = 0.2
    btn.BorderSizePixel = 0
    btn.Parent = btnGui
    
    local btnC = Instance.new("UICorner")
    btnC.CornerRadius = UDim.new(0, 25)
    btnC.Parent = btn
    
    local bt = Instance.new("TextLabel")
    bt.Size = UDim2.new(1, 0, 1, 0)
    bt.BackgroundTransparency = 1
    bt.Text = "👁"
    bt.TextScaled = true
    bt.Font = Enum.Font.SourceSansBold
    bt.TextColor3 = Color3.fromRGB(255, 255, 255)
    bt.Parent = btn
    
    -- 提示
    local msg = Instance.new("Message")
    msg.Text = "⚠️ WindUI 加载失败，已启用原生模式\n按 F4 开关透视"
    msg.Parent = Workspace
    task.delay(4, function() msg:Destroy() end)
    
    -- F4切换
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F4 then
            Settings.Enabled = not Settings.Enabled
            updateAllESP()
        end
    end)
    
    -- 原生模式也用 NPC 扫描
    task.spawn(function()
        while true do
            pcall(function()
                cleanESP()
                if Settings.Enabled then
                    scanNPCs()
                end
            end)
            task.wait(2)
        end
    end)
end