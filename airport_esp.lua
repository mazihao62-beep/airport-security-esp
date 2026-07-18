--[[
    机场安全透视脚本 v6.8
    作者: b站英吉利超入_
    功能: ESP透视 + 好人/坏人识别 + 自定义快捷键
]]

-- ========== 服务 ==========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- 检测平台
local IsMobile = false
pcall(function() IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end)

-- ========== 配置 ==========
local Settings = {
    Enabled = false, BadOnly = false, ShowDistance = false, ShowHealth = false,
    MaxRange = 500,
}

local ESPObjects = {}
local TrackedNPCs = {}
local IsScanning = false
local WindowRef = nil
local Stats = {Good = 0, Bad = 0, Total = 0}
local Controls = {}
local Keybinds = {Window = nil, ESP = nil, BadOnly = nil}
local PopupConfirmed = false
local FloatingButtonGui = nil

-- ========== NPC 分类器 ==========
local function classifyNPC(character, humanoid)
    local name = character.Name or ""
    -- 1: NPCType 属性 (NPCSetup.lua)
    local npcType = nil
    if humanoid then pcall(function() npcType = humanoid:GetAttribute("NPCType") end) end
    if npcType == "Agent" then return "Good" end
    if npcType == "Enemy" then return "Bad" end
    -- 2: 中文关键词
    for _, kw in ipairs({"警察","保安","警卫","警","守卫","士兵","军官","长官","巡逻","特工","安全","安保","卫兵"}) do
        if name:find(kw) then return "Good" end
    end
    for _, kw in ipairs({"恐怖","匪徒","匪","敌人","坏","犯罪","袭击","暴徒","杀手","叛军","武装","入侵"}) do
        if name:find(kw) then return "Bad" end
    end
    -- 3: 英文关键词
    for _, kw in ipairs({"Police","Security","Guard","Agent","Officer","Sheriff","Soldier","Patrol","Cop"}) do
        if name:find(kw,1,true) then return "Good" end
    end
    for _, kw in ipairs({"Terrorist","Enemy","Hostile","Criminal","Threat","Suspect","Bandit","Mercenary"}) do
        if name:find(kw,1,true) then return "Bad" end
    end
    -- 4: 路径检测
    local path = ""
    pcall(function() path = character:GetFullName() end)
    if path:find("AgentTemplate") then return "Good" end
    if path:find("NPCTemplate") then return "Bad" end
    -- 5: TeamColor
    if humanoid then
        local ok, tc = pcall(function() return humanoid.TeamColor end)
        if ok and tc and tc.Name then
            if tc.Name:find("Bright blue") or tc.Name:find("Bright green") or tc.Name:find("White") then return "Good" end
            if tc.Name:find("Bright red") or tc.Name:find("Bright orange") or tc.Name:find("Brown") then return "Bad" end
        end
    end
    return nil
end

-- ========== 判断真实玩家 ==========
local function isRealPlayer(character)
    if not character then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == character then return true end
        if p == Players.LocalPlayer and p.Character then
            if character:IsDescendantOf(p) or p.Character:IsDescendantOf(character) then return true end
        end
    end
    return false
end

-- ========== 创建 ESP ==========
local function createESP(character, npcType)
    if not character or not character.Parent then return end
    if isRealPlayer(character) then return end
    if ESPObjects[character] then
        local color = npcType == "Good" and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,50)
        local obj = ESPObjects[character]
        if obj.Highlight then obj.Highlight.FillColor = color; obj.Highlight.Enabled = Settings.Enabled end
        if obj.Billboard then obj.Billboard.Enabled = Settings.Enabled end
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChildOfClass("Part")
    if not root then return end
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if myRoot and root and (root.Position - myRoot.Position).Magnitude > Settings.MaxRange then return end
    
    local hl = Instance.new("Highlight")
    hl.Adornee = character; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.4; hl.OutlineTransparency = 0.2
    hl.FillColor = npcType == "Good" and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,50)
    hl.OutlineColor = Color3.fromRGB(255,255,255); hl.Enabled = Settings.Enabled; hl.Parent = CoreGui
    
    local head = character:FindFirstChild("Head") or character:FindFirstChild("Torso") or root
    local bb = Instance.new("BillboardGui")
    bb.Adornee = head; bb.Size = UDim2.new(0,160,0,50); bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true; bb.Enabled = Settings.Enabled; bb.Parent = CoreGui
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0.6,0); lbl.BackgroundColor3 = Color3.fromRGB(0,0,0); lbl.BackgroundTransparency = 0.5
    lbl.TextColor3 = npcType == "Good" and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,50)
    lbl.TextScaled = true; lbl.Font = Enum.Font.SourceSansBold
    lbl.Text = npcType == "Good" and "👮 好人" or "💀 坏人"; lbl.BorderSizePixel = 0; lbl.Parent = bb
    
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1,0,0.4,0); info.Position = UDim2.new(0,0,0.6,0)
    info.BackgroundColor3 = Color3.fromRGB(0,0,0); info.BackgroundTransparency = 0.5
    info.TextColor3 = Color3.fromRGB(255,255,255); info.TextScaled = true; info.Font = Enum.Font.SourceSans
    info.Text = ""; info.BorderSizePixel = 0; info.Parent = bb
    
    ESPObjects[character] = {Highlight=hl, Billboard=bb, Label=lbl, InfoLine=info, Head=head, Root=root}
    if npcType == "Good" then Stats.Good = Stats.Good+1 else Stats.Bad = Stats.Bad+1 end
    Stats.Total = Stats.Total+1; TrackedNPCs[character] = npcType
end

-- ========== 移除 ESP ==========
local function removeESP(character)
    if ESPObjects[character] then
        local obj = ESPObjects[character]
        pcall(function() obj.Highlight:Destroy() end); pcall(function() obj.Billboard:Destroy() end)
        ESPObjects[character] = nil
        local nt = TrackedNPCs[character]
        if nt == "Good" then Stats.Good = math.max(0,Stats.Good-1)
        elseif nt == "Bad" then Stats.Bad = math.max(0,Stats.Bad-1) end
        Stats.Total = math.max(0,Stats.Total-1); TrackedNPCs[character] = nil
    end
end

-- ========== 清理 ==========
local function cleanESP()
    for char,_ in pairs(ESPObjects) do
        if not char or not char.Parent then removeESP(char) end
    end
end

-- ========== 更新头顶标签 ==========
local function updateLabels()
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    for char, obj in pairs(ESPObjects) do
        if obj.Billboard and obj.Billboard.Enabled then
            local parts = {}
            if Settings.ShowDistance and myRoot and obj.Root then
                table.insert(parts, math.floor((obj.Root.Position-myRoot.Position).Magnitude+0.5).."m")
            end
            if Settings.ShowHealth then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then table.insert(parts, "HP:"..math.floor(hum.Health+0.5).."/"..math.floor(hum.MaxHealth+0.5)) end
            end
            obj.InfoLine.Text = table.concat(parts, " | ")
        end
    end
end

-- ========== 更新高亮状态 ==========
local function updateAllESP()
    for _,obj in pairs(ESPObjects) do
        if obj.Highlight then obj.Highlight.Enabled = Settings.Enabled end
        if obj.Billboard then obj.Billboard.Enabled = Settings.Enabled end
    end
end

local function updateBadOnlyMode()
    for char, npcType in pairs(TrackedNPCs) do
        if ESPObjects[char] then
            local show = Settings.Enabled and (not Settings.BadOnly or npcType == "Bad")
            if ESPObjects[char].Highlight then ESPObjects[char].Highlight.Enabled = show end
            if ESPObjects[char].Billboard then ESPObjects[char].Billboard.Enabled = show end
        end
    end
end

-- ========== 扫描 NPC ==========
local function scanNPCs()
    if IsScanning then return end; IsScanning = true
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local humanoid, character = nil, nil
            if obj:IsA("Humanoid") then humanoid = obj; character = obj.Parent end
            if character and humanoid and not TrackedNPCs[character] and not isRealPlayer(character) then
                local npcType = classifyNPC(character, humanoid)
                if npcType then createESP(character, npcType) end
            end
            task.wait()
        end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Head" and obj:IsA("BasePart") and not obj:IsA("Tool") then
                local model = obj.Parent
                if model and model:IsA("Model") and not TrackedNPCs[model] and not isRealPlayer(model) then
                    if not model:FindFirstChildOfClass("Humanoid") then
                        local npcType = classifyNPC(model, nil)
                        if npcType then createESP(model, npcType) end
                    end
                end
            end
            task.wait()
        end
    end)
    IsScanning = false
end

-- ========== 美化 UI ==========
local function beautifyUI()
    pcall(function()
        for _, s in ipairs(CoreGui:GetDescendants()) do
            if s:IsA("ScrollingFrame") then
                s.ScrollBarThickness = 14
                s.ScrollBarImageColor3 = Color3.fromRGB(220,220,220)
                s.ScrollBarImageTransparency = 0.1
            end
        end
    end)
    pcall(function()
        for _, o in ipairs(CoreGui:GetDescendants()) do
            if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Size.X.Offset <= 30 and o.Size.X.Offset > 0 then
                local p = o.Parent
                if p and p:IsA("Frame") then
                    o.ImageColor3 = Color3.fromRGB(255,255,255)
                    o.ImageTransparency = 0.1
                end
            end
        end
    end)
end

-- ========== 加载 WindUI ==========
local WindUI = nil
local LoadSuccess = false

local s, r = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if s and r then
    WindUI = r; LoadSuccess = true
    pcall(function() WindUI:SetTheme("Dark") end)
    
    -- Popup 确认弹窗 - 带详细功能描述
    WindUI:Popup({
        Title = "机场安全透视 v6.8",
        Icon = "info",
        Content = "👁 透视高亮 - Highlight穿墙显示所有NPC\n🔍 自动识别 - 区分好人(绿)与坏人(红)\n🏷 头顶标签 - 显示类型/距离/血量\n🔧 自定义快捷键 - 自由绑定按键\n📱 手机适配 - 支持触屏操作\n\n⚠️ 加载后所有功能默认关闭，需手动开启",
        Buttons = {
            { Title = "取消", Callback = function() end, Variant = "Tertiary" },
            { Title = "确认加载", Icon = "arrow-right", Callback = function()
                PopupConfirmed = true
                pcall(function()
                    WindUI:Notify({
                        Title = "✅ 已加载",
                        Content = IsMobile and "👆 点击悬浮按钮打开菜单\n所有功能默认关闭" or "⌨️ 按 RightShift 打开菜单\n所有功能默认关闭",
                        Duration = 4, Icon = "bird",
                    })
                end)
                task.spawn(function() createWindow() end)
            end, Variant = "Primary" }
        }
    })
    
    -- 等待确认
    task.spawn(function()
        while not PopupConfirmed do task.wait(0.5) end
        task.wait(1.5)
        beautifyUI()
        
        -- 主扫描循环
        task.spawn(function()
            while true do
                pcall(function() cleanESP(); if Settings.Enabled then scanNPCs() end end)
                task.wait(2)
            end
        end)
        
        -- 快捷键监听
        -- 注意: 窗口显隐由 WindUI 的 ToggleKey 自动管理
        -- 我们不需要手动调用 showWindow/hideWindow
        task.spawn(function()
            while true do
                local ok, input = pcall(function() return UserInputService.InputBegan:Wait() end)
                if ok and input and input.UserInputType == Enum.UserInputType.Keyboard then
                    pcall(function()
                        if Keybinds.ESP and input.KeyCode == Keybinds.ESP then
                            Settings.Enabled = not Settings.Enabled
                            pcall(function() if Controls.ESPToggle then Controls.ESPToggle:Set({Value=Settings.Enabled}) end end)
                            updateAllESP()
                        end
                        if Keybinds.BadOnly and input.KeyCode == Keybinds.BadOnly then
                            Settings.BadOnly = not Settings.BadOnly
                            pcall(function() if Controls.BadOnlyToggle then Controls.BadOnlyToggle:Set({Value=Settings.BadOnly}) end end)
                            updateBadOnlyMode()
                        end
                    end)
                end
            end
        end)
    end)
    
    -- 创建窗口
    function createWindow()
        if WindowRef then return end
        local ok, win = pcall(function()
            return WindUI:Window({
                Title = "机场安全透视 - b站英吉利超入_",
                Size = Vector2.new(750, 520),
                ToggleKey = Enum.KeyCode.RightShift,
                CanClose = true,
                CanMinimize = false,
                Resizable = false,
                Mobile = IsMobile,
            })
        end)
        if not ok or not win then
            print("[机场安全透视] 窗口创建失败")
            return
        end
        WindowRef = win
        
        -- 主控面板
        local mainTab = win:Tab("主控面板")
        mainTab:Paragraph("👁 透视控制")
        Controls.ESPToggle = mainTab:Toggle({Title="透视开关", Value=false, Callback=function(v) Settings.Enabled=v; updateAllESP(); if not v then updateBadOnlyMode() end end})
        Controls.BadOnlyToggle = mainTab:Toggle({Title="仅显示坏人", Value=false, Callback=function(v) Settings.BadOnly=v; updateBadOnlyMode() end})
        mainTab:Divider()
        mainTab:Paragraph("📐 显示设置")
        Controls.DistanceToggle = mainTab:Toggle({Title="显示距离", Value=false, Callback=function(v) Settings.ShowDistance=v end})
        Controls.HealthToggle = mainTab:Toggle({Title="显示血量", Value=false, Callback=function(v) Settings.ShowHealth=v end})
        mainTab:Divider()
        Controls.RangeSlider = mainTab:Slider({Title="最大探测距离", Value=500, Min=50, Max=1000, Increment=50, Callback=function(v) Settings.MaxRange=v end})
        
        -- 功能设置
        local funcTab = win:Tab("功能设置")
        funcTab:Paragraph("🔑 快捷键设置（点击后按键盘绑定）")
        Controls.ESPKeybind = funcTab:Keybind({Title="透视开关快捷键", Value=nil, Callback=function(key) Keybinds.ESP=key end})
        Controls.BadOnlyKeybind = funcTab:Keybind({Title="仅坏人模式快捷键", Value=nil, Callback=function(key) Keybinds.BadOnly=key end})
        funcTab:Divider()
        funcTab:Paragraph("💡 提示: 在UI设置中可绑定窗口开关快捷键")
        
        -- UI设置
        local uiTab = win:Tab("UI设置")
        uiTab:Paragraph("⚙️ 界面设置")
        Controls.WindowKeybind = uiTab:Keybind({Title="窗口开关快捷键", Value=Enum.KeyCode.RightShift, Callback=function(key) Keybinds.Window=key end})
        Controls.FloatingBtnToggle = uiTab:Toggle({Title="显示悬浮按钮", Value=IsMobile, Callback=function(v) if FloatingButtonGui then FloatingButtonGui.Enabled=v end end})
        uiTab:Divider()
        uiTab:Paragraph("💡 提示: 窗口默认隐藏，按 RightShift 打开")
        
        -- 信息统计
        local statsTab = win:Tab("信息统计")
        local goodP = statsTab:Paragraph("🟢 好人: 0")
        local badP = statsTab:Paragraph("🔴 坏人: 0")
        local totalP = statsTab:Paragraph("📊 总计: 0")
        statsTab:Divider()
        local scanI = statsTab:Input({Title="扫描状态", Value="等待中...", Multiline=false, Locked=true})
        
        -- 关于
        local aboutTab = win:Tab("关于")
        aboutTab:Paragraph({Title="机场安全透视 v6.8", Desc="用于分辨好人与坏人的透视脚本"})
        aboutTab:Divider()
        aboutTab:Paragraph({Title="👤 作者", Desc="b站英吉利超入_"})
        aboutTab:Divider()
        aboutTab:Paragraph({Title="💡 使用说明", Desc=IsMobile and "手机: 点击悬浮按钮" or "PC: 按 RightShift 打开菜单"})
        aboutTab:Paragraph({Title="⚠️ 提示", Desc="所有功能默认关闭，请在菜单中手动开启"})
        aboutTab:Button({Title="📦 GitHub", Callback=function() pcall(function() WindUI:Notify({Title="仓库地址", Content="github.com/mazihao62-beep/airport-security-esp", Duration=3}) end) end})
        
        -- 统计更新循环
        task.spawn(function()
            while true do
                pcall(function()
                    goodP:SetTitle("🟢 好人: "..Stats.Good)
                    badP:SetTitle("🔴 坏人: "..Stats.Bad)
                    totalP:SetTitle("📊 总计: "..Stats.Total)
                    scanI:Set({Value=IsScanning and "📡 扫描中..." or "✅ 就绪"})
                    updateLabels()
                end)
                task.wait(0.5)
            end
        end)
        
        -- 手机悬浮按钮
        if IsMobile then
            task.spawn(function()
                task.wait(1)
                pcall(function()
                    FloatingButtonGui = Instance.new("ScreenGui")
                    FloatingButtonGui.Name = "AirportESP_Btn"; FloatingButtonGui.Enabled = true
                    FloatingButtonGui.ResetOnSpawn = false; FloatingButtonGui.Parent = CoreGui
                    local btn = Instance.new("ImageButton")
                    btn.Size = UDim2.new(0,50,0,50); btn.Position = UDim2.new(0.9,-25,0.8,-25)
                    btn.BackgroundColor3 = Color3.fromRGB(0,180,80); btn.BackgroundTransparency = 0.2
                    btn.BorderSizePixel = 0; btn.Parent = FloatingButtonGui
                    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,25); c.Parent = btn
                    local t = Instance.new("TextLabel")
                    t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1; t.Text = "👁"
                    t.TextScaled = true; t.Font = Enum.Font.SourceSansBold; t.TextColor3 = Color3.fromRGB(255,255,255); t.Parent = btn
                    local dragging,dragStart,startPos = false,nil,nil
                    btn.InputBegan:Connect(function(input)
                        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
                            dragging=true; dragStart=input.Position; startPos=btn.Position
                        end
                    end)
                    btn.InputChanged:Connect(function(input)
                        if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
                            btn.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+input.Position.X-dragStart.X,startPos.Y.Scale,startPos.Y.Offset+input.Position.Y-dragStart.Y)
                        end
                    end)
                    btn.InputEnded:Connect(function(input)
                        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
                    end)
                    btn.MouseButton1Click:Connect(function()
                        -- 手机按钮点击：触发 RightShift 切换窗口
                        -- WindUI 的 ToggleKey 会自动处理
                    end)
                end)
            end)
        end
    end
else
    -- ========== 原生模式 ==========
    LoadSuccess = false
    local msg = Instance.new("Message")
    msg.Text = "⚠️ WindUI 加载失败，使用原生模式 | 点击绿色按钮开关透视"
    msg.Parent = Workspace
    task.delay(5, function() msg:Destroy() end)
    
    local btnGui = Instance.new("ScreenGui")
    btnGui.Name = "AirportESP_Btn"; btnGui.ResetOnSpawn = false; btnGui.Parent = CoreGui
    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(0,50,0,50); btn.Position = UDim2.new(0.9,-25,0.8,-25)
    btn.BackgroundColor3 = Color3.fromRGB(0,180,80); btn.BackgroundTransparency = 0.2; btn.BorderSizePixel = 0; btn.Parent = btnGui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,25); c.Parent = btn
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1; t.Text = "👁"
    t.TextScaled = true; t.Font = Enum.Font.SourceSansBold; t.TextColor3 = Color3.fromRGB(255,255,255); t.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        Settings.Enabled = not Settings.Enabled; updateAllESP()
        btn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(255,50,50) or Color3.fromRGB(0,180,80)
    end)
    
    task.spawn(function()
        while true do
            pcall(function() cleanESP(); if Settings.Enabled then scanNPCs() end end)
            task.wait(2)
        end
    end)
end

print("[机场安全透视] v6.8 已加载 | 作者: b站英吉利超入_")
