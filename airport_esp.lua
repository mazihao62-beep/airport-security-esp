--[[
    机场安全透视脚本 v7.0
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

-- ========== 配置（所有功能默认关闭） ==========
local Settings = {
    Enabled = false, BadOnly = false, ShowDistance = false, ShowHealth = false,
    MaxRange = 500,
}

local ESPObjects = {}
local TrackedNPCs = {}
local IsScanning = false
local WindowRef = nil
local FloatingButtonGui = nil
local Stats = {Good = 0, Bad = 0, Total = 0}
local Controls = {}
local Keybinds = {Window = Enum.KeyCode.RightShift, ESP = nil, BadOnly = nil}
local PopupConfirmed = false
local TabElements = {}

-- ========== NPC 分类器 ==========
local function classifyNPC(character, humanoid)
    local name = character.Name or ""
    -- 1: NPCType 属性 (NPCSetup.lua 源码确认)
    local npcType = nil
    if humanoid then pcall(function() npcType = humanoid:GetAttribute("NPCType") end) end
    if npcType == "Agent" then return "Good" end
    if npcType == "Enemy" then return "Bad" end
    -- 2: 中文关键词（优先级高）
    for _, kw in ipairs({"警察","保安","警卫","警","守卫","士兵","军官","长官","巡逻","特工","安全","安保","护卫","卫兵"}) do
        if name:find(kw) then return "Good" end
    end
    for _, kw in ipairs({"恐怖","匪徒","匪","敌人","坏","犯罪","袭击","暴徒","杀手","叛军","武装","劫匪","入侵"}) do
        if name:find(kw) then return "Bad" end
    end
    -- 3: 英文关键词
    for _, kw in ipairs({"Police","Security","Guard","Agent","Officer","Sheriff","Soldier","Patrol","Cop","Marshal"}) do
        if name:find(kw,1,true) then return "Good" end
    end
    for _, kw in ipairs({"Terrorist","Enemy","Hostile","Criminal","Threat","Suspect","Bandit","Mercenary","Attacker"}) do
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
    -- 6: 工具检测
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        local tn = tool.Name
        if tn:find("Arrest") or tn:find("Taser") or tn:find("Bat") or tn:find("Radio") then return "Good" end
    end
    return nil  -- 无法判断则跳过
end

-- ========== 判断真实玩家 ==========
local function isRealPlayer(character)
    if not character then return false end
    if not character:IsA("Model") then return false end
    local lp = Players.LocalPlayer
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == character then return true end
    end
    -- 额外检查本地玩家的角色
    if lp and lp.Character then
        local myRoot = lp.Character:FindFirstChild("HumanoidRootPart") or lp.Character:FindFirstChild("Torso")
        local theirRoot = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
        if myRoot and theirRoot and myRoot == theirRoot then return true end
    end
    return false
end

-- ========== 创建 ESP ==========
local function createESP(character, npcType)
    if not character or not character.Parent then return false end
    if isRealPlayer(character) then return false end
    if ESPObjects[character] then
        local color = npcType == "Good" and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,50)
        local obj = ESPObjects[character]
        local show = Settings.Enabled and (not Settings.BadOnly or npcType == "Bad")
        if obj.Highlight then
            obj.Highlight.FillColor = color
            obj.Highlight.Enabled = show
        end
        if obj.Billboard then obj.Billboard.Enabled = show end
        return true
    end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChildOfClass("Part")
    if not root then return false end

    -- 距离检查
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if myRoot and root and (root.Position - myRoot.Position).Magnitude > Settings.MaxRange then return false end

    local show = Settings.Enabled and (not Settings.BadOnly or npcType == "Bad")

    local hl = Instance.new("Highlight")
    hl.Adornee = character
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.4
    hl.OutlineTransparency = 0.2
    hl.FillColor = npcType == "Good" and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,50)
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.Enabled = show
    hl.Parent = CoreGui

    local head = character:FindFirstChild("Head") or character:FindFirstChild("Torso") or root
    local bb = Instance.new("BillboardGui")
    bb.Adornee = head
    bb.Size = UDim2.new(0,160,0,50)
    bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true
    bb.Enabled = show
    bb.Parent = CoreGui
    bb.ClipsDescendants = false

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency = 0.4
    bg.BorderSizePixel = 0
    bg.Parent = bb
    local bgc = Instance.new("UICorner")
    bgc.CornerRadius = UDim.new(0,4)
    bgc.Parent = bg

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-4,0.55,0)
    lbl.Position = UDim2.new(0,2,0,2)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = npcType == "Good" and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,50)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.SourceSansBold
    lbl.Text = npcType == "Good" and "👮 好人" or "💀 坏人"
    lbl.BorderSizePixel = 0
    lbl.Parent = bg

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1,-4,0.4,0)
    info.Position = UDim2.new(0,2,0.55,2)
    info.BackgroundTransparency = 1
    info.TextColor3 = Color3.fromRGB(255,255,255)
    info.TextScaled = true
    info.Font = Enum.Font.SourceSans
    info.Text = ""
    info.BorderSizePixel = 0
    info.Parent = bg

    ESPObjects[character] = {Highlight=hl, Billboard=bb, Label=lbl, InfoLine=info, Head=head, Root=root}
    if npcType == "Good" then Stats.Good = Stats.Good + 1 else Stats.Bad = Stats.Bad + 1 end
    Stats.Total = Stats.Total + 1
    TrackedNPCs[character] = npcType
    return true
end

-- ========== 移除 ESP ==========
local function removeESP(character)
    if ESPObjects[character] then
        local obj = ESPObjects[character]
        pcall(function() obj.Highlight:Destroy() end)
        pcall(function() obj.Billboard:Destroy() end)
        ESPObjects[character] = nil
        local nt = TrackedNPCs[character]
        if nt == "Good" then Stats.Good = math.max(0, Stats.Good - 1)
        elseif nt == "Bad" then Stats.Bad = math.max(0, Stats.Bad - 1) end
        Stats.Total = math.max(0, Stats.Total - 1)
        TrackedNPCs[character] = nil
    end
end

-- ========== 清理 ==========
local function cleanESP()
    for char, _ in pairs(ESPObjects) do
        if not char or not char.Parent then removeESP(char) end
    end
end

-- ========== 更新头顶标签 ==========
local function updateLabels()
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    for char, obj in pairs(ESPObjects) do
        if obj.Billboard and obj.Billboard.Enabled and obj.InfoLine then
            local parts = {}
            if Settings.ShowDistance and myRoot and obj.Root then
                local dist = math.floor((obj.Root.Position - myRoot.Position).Magnitude + 0.5)
                table.insert(parts, dist .. "m")
            end
            if Settings.ShowHealth then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    table.insert(parts, "HP:" .. math.floor(hum.Health + 0.5) .. "/" .. math.floor(hum.MaxHealth + 0.5))
                end
            end
            obj.InfoLine.Text = table.concat(parts, " | ")
        end
    end
end

-- ========== 更新所有ESP显隐 ==========
local function updateAllESP()
    for char, obj in pairs(ESPObjects) do
        local npcType = TrackedNPCs[char]
        local show = Settings.Enabled and (not Settings.BadOnly or npcType == "Bad")
        if obj.Highlight then obj.Highlight.Enabled = show end
        if obj.Billboard then obj.Billboard.Enabled = show end
    end
end

-- ========== 扫描 NPC（核心修复：永远运行，不依赖开关状态） ==========
local function scanNPCs()
    if IsScanning then return end
    IsScanning = true

    local success = pcall(function()
        -- 第一遍：找 Humanoid
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local humanoid = nil
            local character = nil
            if obj:IsA("Humanoid") then
                humanoid = obj
                character = obj.Parent
            end
            if character and humanoid and not TrackedNPCs[character] then
                if not isRealPlayer(character) then
                    local npcType = classifyNPC(character, humanoid)
                    if npcType then createESP(character, npcType) end
                end
            end
            task.wait()
        end
        -- 第二遍：找没有Humanoid但带Head的模型
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Head" and obj:IsA("BasePart") and not obj:IsA("Tool") then
                local model = obj.Parent
                if model and model:IsA("Model") and not TrackedNPCs[model] then
                    if not isRealPlayer(model) then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        if not hum then
                            local npcType = classifyNPC(model, nil)
                            if npcType then createESP(model, npcType) end
                        end
                    end
                end
            end
            task.wait()
        end
    end)

    IsScanning = false
end

-- ========== 加载 WindUI ==========
local WindUI = nil
local s, r = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if s and r then
    WindUI = r
    pcall(function() WindUI:SetTheme("Dark") end)

    -- ===== Popup 确认弹窗 =====
    WindUI:Popup({
        Title = "机场安全透视 v7.0",
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
                -- 立即开始扫描和创建窗口
                task.spawn(function()
                    createWindow()
                    task.wait(0.3)
                    scanNPCs()  -- 立即扫一次
                end)
            end, Variant = "Primary" }
        }
    })

    -- ===== 等待确认后启动 =====
    task.spawn(function()
        while not PopupConfirmed do task.wait(0.5) end
        task.wait(1.5)

        -- 主扫描循环（核心修复：永远运行，不依赖Settings.Enabled）
        task.spawn(function()
            while true do
                pcall(function()
                    cleanESP()
                    scanNPCs()  -- 始终扫描！
                end)
                task.wait(3)
            end
        end)

        -- 统计UI更新循环
        task.spawn(function()
            while true do
                pcall(function()
                    if TabElements.GoodP then
                        TabElements.GoodP:SetTitle("🟢 好人: " .. Stats.Good)
                        TabElements.BadP:SetTitle("🔴 坏人: " .. Stats.Bad)
                        TabElements.TotalP:SetTitle("📊 总计: " .. Stats.Total)
                    end
                    if TabElements.ScanI then
                        TabElements.ScanI:Set({Value = IsScanning and "📡 扫描中..." or "✅ 就绪"})
                    end
                    updateLabels()
                end)
                task.wait(0.5)
            end
        end)

        -- ===== 快捷键监听 =====
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local key = input.KeyCode

            -- 窗口开关（默认 RightShift）— 用WindUI的ToggleKey处理
            -- 这里不需要额外处理，WindUI已接管

            -- 透视开关快捷键
            if Keybinds.ESP and key == Keybinds.ESP then
                Settings.Enabled = not Settings.Enabled
                pcall(function()
                    if Controls.ESPToggle then Controls.ESPToggle:Set({Value = Settings.Enabled}) end
                end)
                updateAllESP()
                if Settings.Enabled then task.spawn(scanNPCs) end
                return
            end

            -- 仅坏人模式快捷键
            if Keybinds.BadOnly and key == Keybinds.BadOnly then
                Settings.BadOnly = not Settings.BadOnly
                pcall(function()
                    if Controls.BadOnlyToggle then Controls.BadOnlyToggle:Set({Value = Settings.BadOnly}) end
                end)
                updateAllESP()
                return
            end
        end)
    end)

    -- ===== 创建窗口 =====
    function createWindow()
        if WindowRef then return end

        local ok, win = pcall(function()
            return WindUI:Window({
                Title = "机场安全透视 - b站英吉利超入_",
                Size = Vector2.new(750, 520),
                ToggleKey = Enum.KeyCode.RightShift,  -- WindUI 管理 RightShift
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

        -- 美化UI
        task.spawn(function()
            task.wait(0.5)
            pcall(function()
                for _, s in ipairs(CoreGui:GetDescendants()) do
                    if s:IsA("ScrollingFrame") then
                        s.ScrollBarThickness = 14
                        s.ScrollBarImageColor3 = Color3.fromRGB(220, 220, 220)
                        s.ScrollBarImageTransparency = 0.1
                    end
                end
            end)
            pcall(function()
                for _, o in ipairs(CoreGui:GetDescendants()) do
                    if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Size.X.Offset <= 30 and o.Size.X.Offset > 0 then
                        local p = o.Parent
                        if p and p:IsA("Frame") then
                            o.ImageColor3 = Color3.fromRGB(255, 255, 255)
                            o.ImageTransparency = 0.1
                        end
                    end
                end
            end)
        end)

        -- 主控面板
        local mainTab = win:Tab("主控面板")
        mainTab:Paragraph("👁 透视控制")
        Controls.ESPToggle = mainTab:Toggle({
            Title = "透视开关",
            Value = false,
            Callback = function(v)
                Settings.Enabled = v
                updateAllESP()
                if v then task.spawn(scanNPCs) end
            end
        })
        Controls.BadOnlyToggle = mainTab:Toggle({
            Title = "仅显示坏人",
            Value = false,
            Callback = function(v)
                Settings.BadOnly = v
                updateAllESP()
            end
        })
        mainTab:Divider()
        mainTab:Paragraph("📐 显示设置")
        Controls.DistanceToggle = mainTab:Toggle({
            Title = "显示距离",
            Value = false,
            Callback = function(v) Settings.ShowDistance = v end
        })
        Controls.HealthToggle = mainTab:Toggle({
            Title = "显示血量",
            Value = false,
            Callback = function(v) Settings.ShowHealth = v end
        })
        mainTab:Divider()
        Controls.RangeSlider = mainTab:Slider({
            Title = "最大探测距离",
            Value = 500,
            Min = 50,
            Max = 1000,
            Increment = 50,
            Callback = function(v) Settings.MaxRange = v end
        })

        -- 功能设置
        local funcTab = win:Tab("功能设置")
        funcTab:Paragraph("🔑 快捷键设置（点击后按键盘绑定）")
        Controls.ESPKeybind = funcTab:Keybind({
            Title = "透视开关快捷键",
            Value = nil,
            Callback = function(key) Keybinds.ESP = key end
        })
        Controls.BadOnlyKeybind = funcTab:Keybind({
            Title = "仅坏人模式快捷键",
            Value = nil,
            Callback = function(key) Keybinds.BadOnly = key end
        })
        funcTab:Divider()
        funcTab:Paragraph("💡 提示: 窗口快捷键在UI设置中绑定（默认 RightShift）")

        -- UI设置
        local uiTab = win:Tab("UI设置")
        uiTab:Paragraph("⚙️ 界面设置")
        Controls.WindowKeybind = uiTab:Keybind({
            Title = "窗口开关快捷键",
            Value = Enum.KeyCode.RightShift,
            Callback = function(key) Keybinds.Window = key end
        })
        Controls.FloatingBtnToggle = uiTab:Toggle({
            Title = "显示悬浮按钮",
            Value = IsMobile,
            Callback = function(v)
                Settings.ShowFloatingButton = v
                if FloatingButtonGui then FloatingButtonGui.Enabled = v end
            end
        })
        uiTab:Divider()
        uiTab:Paragraph("💡 提示: 窗口默认隐藏，按 RightShift 打开")

        -- 信息统计
        local statsTab = win:Tab("信息统计")
        TabElements.GoodP = statsTab:Paragraph("🟢 好人: 0")
        TabElements.BadP = statsTab:Paragraph("🔴 坏人: 0")
        TabElements.TotalP = statsTab:Paragraph("📊 总计: 0")
        statsTab:Divider()
        TabElements.ScanI = statsTab:Input({
            Title = "扫描状态",
            Value = "等待中...",
            Multiline = false,
            Locked = true
        })

        -- 关于
        local aboutTab = win:Tab("关于")
        aboutTab:Paragraph({Title = "机场安全透视 v7.0", Desc = "用于分辨好人与坏人的透视脚本"})
        aboutTab:Divider()
        aboutTab:Paragraph({Title = "👤 作者", Desc = "b站英吉利超入_"})
        aboutTab:Divider()
        local usage = IsMobile and "手机: 点击悬浮按钮" or "PC: 按 RightShift 打开菜单"
        aboutTab:Paragraph({Title = "💡 使用说明", Desc = usage})
        aboutTab:Paragraph({Title = "⚠️ 提示", Desc = "所有功能默认关闭，请在菜单中手动开启"})
        aboutTab:Button({
            Title = "📦 GitHub",
            Callback = function()
                pcall(function() WindUI:Notify({Title="仓库地址", Content="github.com/mazihao62-beep/airport-security-esp", Duration=3}) end)
            end
        })

        -- 手机悬浮按钮
        if IsMobile then
            task.spawn(function()
                task.wait(1)
                pcall(function()
                    FloatingButtonGui = Instance.new("ScreenGui")
                    FloatingButtonGui.Name = "AirportESP_Btn"
                    FloatingButtonGui.Enabled = true
                    FloatingButtonGui.ResetOnSpawn = false
                    FloatingButtonGui.Parent = CoreGui
                    local btn = Instance.new("ImageButton")
                    btn.Size = UDim2.new(0,50,0,50)
                    btn.Position = UDim2.new(0.9,-25,0.8,-25)
                    btn.BackgroundColor3 = Color3.fromRGB(0,180,80)
                    btn.BackgroundTransparency = 0.2
                    btn.BorderSizePixel = 0
                    btn.Parent = FloatingButtonGui
                    local c = Instance.new("UICorner")
                    c.CornerRadius = UDim.new(0,25)
                    c.Parent = btn
                    local t = Instance.new("TextLabel")
                    t.Size = UDim2.new(1,0,1,0)
                    t.BackgroundTransparency = 1
                    t.Text = "👁"
                    t.TextScaled = true
                    t.Font = Enum.Font.SourceSansBold
                    t.TextColor3 = Color3.fromRGB(255,255,255)
                    t.Parent = btn
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
                        -- 手机按钮模拟RightShift切换窗口
                    end)
                end)
            end)
        end
    end

    print("[机场安全透视] v7.0 已加载 | 作者: b站英吉利超入_")
else
    -- ===== WindUI 加载失败，原生模式 =====
    print("[机场安全透视] WindUI 加载失败，使用原生模式")
    local msg = Instance.new("Message")
    msg.Text = "⚠️ WindUI 加载失败，使用原生模式 | 点击绿色按钮开关透视"
    msg.Parent = Workspace
    task.delay(5, function() msg:Destroy() end)

    local btnGui = Instance.new("ScreenGui")
    btnGui.Name = "AirportESP_Btn"
    btnGui.ResetOnSpawn = false
    btnGui.Parent = CoreGui
    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(0,50,0,50)
    btn.Position = UDim2.new(0.9,-25,0.8,-25)
    btn.BackgroundColor3 = Color3.fromRGB(0,180,80)
    btn.BackgroundTransparency = 0.2
    btn.BorderSizePixel = 0
    btn.Parent = btnGui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,25)
    c.Parent = btn
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,1,0)
    t.BackgroundTransparency = 1
    t.Text = "👁"
    t.TextScaled = true
    t.Font = Enum.Font.SourceSansBold
    t.TextColor3 = Color3.fromRGB(255,255,255)
    t.Parent = btn

    btn.MouseButton1Click:Connect(function()
        Settings.Enabled = not Settings.Enabled
        updateAllESP()
        btn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(255,50,50) or Color3.fromRGB(0,180,80)
        if Settings.Enabled then task.spawn(scanNPCs) end
    end)

    -- 原生模式也永远运行扫描
    task.spawn(function()
        while true do
            pcall(function() cleanESP(); scanNPCs() end)  -- 永远扫描！
            task.wait(3)
        end
    end)
end

-- ===== 保底：无论Popup是否确认，3秒后都开始扫描 =====
task.spawn(function()
    task.wait(3)
    if not PopupConfirmed then
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Humanoid") then
                    local char = obj.Parent
                    if char and not isRealPlayer(char) and not TrackedNPCs[char] then
                        local nt = classifyNPC(char, obj)
                        if nt then createESP(char, nt) end
                    end
                end
                task.wait()
            end
        end)
    end
end)

print("[机场安全透视] 脚本加载完成")
