--[[
    机场安全透视脚本 v9.0
    作者: b站英吉利超入_
    功能: ESP透视 + 好人/坏人识别 + 配置保存 + 毛玻璃效果
]]

-- ========== 服务 ==========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

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
local Keybinds = {}
local PopupConfirmed = false
local TabElements = {}
local ConfigName = "default"

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
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == character then return true end
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
        if obj.Highlight then obj.Highlight.FillColor = color; obj.Highlight.Enabled = show end
        if obj.Billboard then obj.Billboard.Enabled = show end
        return true
    end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChildOfClass("Part")
    if not root then return false end

    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if myRoot and root and (root.Position - myRoot.Position).Magnitude > Settings.MaxRange then return false end

    local show = Settings.Enabled and (not Settings.BadOnly or npcType == "Bad")
    local color = npcType == "Good" and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,50)

    local hl = Instance.new("Highlight")
    hl.Adornee = character; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.4; hl.OutlineTransparency = 0.2
    hl.FillColor = color; hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.Enabled = show; hl.Parent = CoreGui

    local head = character:FindFirstChild("Head") or character:FindFirstChild("Torso") or root
    local bb = Instance.new("BillboardGui")
    bb.Adornee = head; bb.Size = UDim2.new(0,160,0,50); bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true; bb.Enabled = show; bb.Parent = CoreGui; bb.ClipsDescendants = false

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency = 0.4; bg.BorderSizePixel = 0; bg.Parent = bb
    local bgc = Instance.new("UICorner"); bgc.CornerRadius = UDim.new(0,4); bgc.Parent = bg

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-4,0.55,0); lbl.Position = UDim2.new(0,2,0,2)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = color
    lbl.TextScaled = true; lbl.Font = Enum.Font.SourceSansBold
    lbl.Text = npcType == "Good" and "👮 好人" or "💀 坏人"; lbl.BorderSizePixel = 0; lbl.Parent = bg

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1,-4,0.4,0); info.Position = UDim2.new(0,2,0.55,2)
    info.BackgroundTransparency = 1; info.TextColor3 = Color3.fromRGB(255,255,255)
    info.TextScaled = true; info.Font = Enum.Font.SourceSans; info.Text = ""; info.BorderSizePixel = 0; info.Parent = bg

    ESPObjects[character] = {Highlight=hl, Billboard=bb, Label=lbl, InfoLine=info, Head=head, Root=root}
    if npcType == "Good" then Stats.Good = Stats.Good + 1 else Stats.Bad = Stats.Bad + 1 end
    Stats.Total = Stats.Total + 1; TrackedNPCs[character] = npcType
    return true
end

-- ========== 移除 ESP ==========
local function removeESP(character)
    if ESPObjects[character] then
        local obj = ESPObjects[character]
        pcall(function() obj.Highlight:Destroy() end); pcall(function() obj.Billboard:Destroy() end)
        ESPObjects[character] = nil
        local nt = TrackedNPCs[character]
        if nt == "Good" then Stats.Good = math.max(0, Stats.Good - 1)
        elseif nt == "Bad" then Stats.Bad = math.max(0, Stats.Bad - 1) end
        Stats.Total = math.max(0, Stats.Total - 1); TrackedNPCs[character] = nil
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
                if hum then table.insert(parts, "HP:" .. math.floor(hum.Health + 0.5) .. "/" .. math.floor(hum.MaxHealth + 0.5)) end
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
                s.ScrollBarImageColor3 = Color3.fromRGB(220, 220, 220)
                s.ScrollBarImageTransparency = 0.1
            end
        end
    end)
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
        Title = "机场安全透视 v9.0",
        Icon = "solar:info-square-bold",
        Content = "👁 透视高亮 - Highlight穿墙显示所有NPC\n🔍 自动识别 - 区分好人(绿)与坏人(红)\n🏷 头顶标签 - 显示类型/距离/血量\n🔧 自定义快捷键 - 自由绑定按键\n💾 配置保存 - 自动保存/读取设置\n✨ 毛玻璃效果 - 支持透明/Acrylic\n\n⚠️ 加载后所有功能默认关闭，需手动开启",
        Buttons = {
            { Title = "取消", Callback = function() end, Variant = "Tertiary" },
            { Title = "确认加载", Icon = "solar:arrow-right-bold", Callback = function()
                PopupConfirmed = true
                pcall(function()
                    WindUI:Notify({
                        Title = "✅ 已加载",
                        Content = "⌨️ 按 RightShift 打开菜单\n所有功能默认关闭",
                        Duration = 4, Icon = "solar:bell-bold",
                    })
                end)
                task.spawn(function()
                    createWindow()
                    task.wait(0.3)
                    scanNPCs()
                end)
            end, Variant = "Primary" }
        }
    })

    -- ===== 等待确认后启动 =====
    task.spawn(function()
        while not PopupConfirmed do task.wait(0.5) end
        task.wait(1.5)
        beautifyUI()

        task.spawn(function()
            while true do
                pcall(function() cleanESP(); scanNPCs() end)
                task.wait(3)
            end
        end)

        task.spawn(function()
            while true do
                pcall(function()
                    if TabElements.GoodP then
                        TabElements.GoodP:SetTitle("🟢 好人: " .. Stats.Good)
                        TabElements.BadP:SetTitle("🔴 坏人: " .. Stats.Bad)
                        TabElements.TotalP:SetTitle("📊 总计: " .. Stats.Total)
                    end
                    if TabElements.ScanI then
                        TabElements.ScanI:Set(IsScanning and "📡 扫描中..." or "✅ 就绪")
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
            local keyName = input.KeyCode.Name

            if Keybinds.ESP and Keybinds.ESP ~= "" and keyName == Keybinds.ESP then
                Settings.Enabled = not Settings.Enabled
                pcall(function()
                    if Controls.ESPToggle then Controls.ESPToggle:Set(Settings.Enabled) end
                end)
                updateAllESP()
                if Settings.Enabled then task.spawn(scanNPCs) end
                return
            end

            if Keybinds.BadOnly and Keybinds.BadOnly ~= "" and keyName == Keybinds.BadOnly then
                Settings.BadOnly = not Settings.BadOnly
                pcall(function()
                    if Controls.BadOnlyToggle then Controls.BadOnlyToggle:Set(Settings.BadOnly) end
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
            return WindUI:CreateWindow({
                Title = "机场安全透视",
                Author = "b站英吉利超入_",
                Icon = "solar:shield-warning-bold",
                Size = UDim2.fromOffset(750, 520),
                ToggleKey = Enum.KeyCode.RightShift,
                Folder = "airport-esp",  -- 配置保存必需
                Acrylic = true,          -- 毛玻璃效果
                Resizable = false,
                SideBarWidth = 180,
                ScrollBarEnabled = true,
                HideSearchBar = true,
            })
        end)
        if not ok or not win then
            print("[机场安全透视] 窗口创建失败:", ok)
            return
        end
        WindowRef = win

        -- ===== 主控面板 =====
        local mainTab = win:Tab({Title="主控面板", Icon="solar:slider-vertical-bold"})
        mainTab:Paragraph({Title="👁 透视控制"})
        Controls.ESPToggle = mainTab:Toggle({
            Flag = "ESPToggle",
            Title = "透视开关", Value = false,
            Callback = function(v) Settings.Enabled = v; updateAllESP(); if v then task.spawn(scanNPCs) end end
        })
        Controls.BadOnlyToggle = mainTab:Toggle({
            Flag = "BadOnlyToggle",
            Title = "仅显示坏人", Value = false,
            Callback = function(v) Settings.BadOnly = v; updateAllESP() end
        })
        mainTab:Divider()
        mainTab:Paragraph({Title="📐 显示设置"})
        Controls.DistanceToggle = mainTab:Toggle({
            Flag = "DistanceToggle",
            Title = "显示距离", Value = false,
            Callback = function(v) Settings.ShowDistance = v end
        })
        Controls.HealthToggle = mainTab:Toggle({
            Flag = "HealthToggle",
            Title = "显示血量", Value = false,
            Callback = function(v) Settings.ShowHealth = v end
        })
        mainTab:Divider()
        Controls.RangeSlider = mainTab:Slider({
            Flag = "RangeSlider",
            Title = "最大探测距离",
            Step = 50,
            Value = { Min = 50, Max = 1000, Default = 500 },
            Width = 200,
            IsTextbox = true,
            Callback = function(v) Settings.MaxRange = v end
        })

        -- ===== 功能设置 =====
        local funcTab = win:Tab({Title="功能设置", Icon="solar:settings-bold"})
        funcTab:Paragraph({Title="🔑 快捷键设置（点击后按键盘绑定）"})
        Controls.ESPKeybind = funcTab:Keybind({
            Flag = "ESPKeybind",
            Title = "透视开关快捷键", Value = "",
            Callback = function(key) Keybinds.ESP = key end
        })
        Controls.BadOnlyKeybind = funcTab:Keybind({
            Flag = "BadOnlyKeybind",
            Title = "仅坏人模式快捷键", Value = "",
            Callback = function(key) Keybinds.BadOnly = key end
        })
        funcTab:Divider()
        funcTab:Paragraph({Title="💡 提示", Desc="窗口快捷键在UI设置中绑定（默认 RightShift）"})

        -- ===== UI设置 =====
        local uiTab = win:Tab({Title="UI设置", Icon="solar:monitor-bold"})
        uiTab:Paragraph({Title="⚙️ 界面设置"})
        Controls.WindowKeybind = uiTab:Keybind({
            Flag = "WindowKeybind",
            Title = "窗口开关快捷键", Value = "RightShift",
            Callback = function(key)
                Keybinds.Window = key
                if WindowRef then pcall(function() WindowRef:SetToggleKey(Enum.KeyCode[key]) end) end
            end
        })
        Controls.FloatingBtnToggle = uiTab:Toggle({
            Flag = "FloatingBtnToggle",
            Title = "显示悬浮按钮", Value = IsMobile,
            Callback = function(v) if FloatingButtonGui then FloatingButtonGui.Enabled = v end end
        })
        uiTab:Divider()
        uiTab:Paragraph({Title="✨ 视觉效果"})
        Controls.AcrylicToggle = uiTab:Toggle({
            Flag = "AcrylicToggle",
            Title = "毛玻璃效果 (Acrylic)", Value = true,
            Callback = function(v)
                pcall(function()
                    WindUI:ToggleAcrylic(v)
                end)
            end
        })
        Controls.TransparencyToggle = uiTab:Toggle({
            Flag = "TransparencyToggle",
            Title = "透明背景", Value = false,
            Callback = function(v)
                if WindowRef then
                    pcall(function() WindowRef:ToggleTransparency(v) end)
                end
            end
        })
        uiTab:Divider()
        uiTab:Paragraph({Title="💡 提示", Desc="窗口默认隐藏，按 RightShift 打开"})

        -- ===== 信息统计 =====
        local statsTab = win:Tab({Title="信息统计", Icon="solar:chart-bold"})
        TabElements.GoodP = statsTab:Paragraph({Title="🟢 好人: 0"})
        TabElements.BadP = statsTab:Paragraph({Title="🔴 坏人: 0"})
        TabElements.TotalP = statsTab:Paragraph({Title="📊 总计: 0"})
        statsTab:Divider()
        TabElements.ScanI = statsTab:Input({
            Title = "扫描状态", Value = "等待中...", Locked = true
        })

        -- ===== 配置管理 (Config Saving) =====
        local configTab = win:Tab({Title="配置管理", Icon="solar:diskette-bold"})
        configTab:Paragraph({Title="💾 配置管理", Desc="保存/加载你的所有设置"})

        local ConfigNameInput = configTab:Input({
            Flag = "ConfigNameInput",
            Title = "配置名称",
            Value = "default",
            Icon = "solar:file-text-bold",
            Callback = function(value)
                ConfigName = value
            end
        })

        configTab:Space()

        local ConfigManager = WindowRef.ConfigManager
        local AllConfigs = {}
        pcall(function() AllConfigs = ConfigManager:AllConfigs() end)
        local DefaultValue = nil
        pcall(function()
            for _, v in ipairs(AllConfigs) do
                if v == "default" then DefaultValue = "default"; break end
            end
        end)

        local AllConfigsDropdown = configTab:Dropdown({
            Title = "已有配置",
            Desc = "选择要加载的配置",
            Values = AllConfigs,
            Value = DefaultValue,
            Callback = function(value)
                if value then
                    ConfigName = value
                    pcall(function() ConfigNameInput:Set(value) end)
                end
            end
        })

        configTab:Space()

        configTab:Button({
            Title = "💾 保存配置",
            Icon = "solar:check-circle-bold",
            Justify = "Center",
            Color = Color3.fromHex("#305dff"),
            Callback = function()
                if not ConfigManager then
                    pcall(function() WindUI:Notify({Title="错误", Content="配置系统不可用", Duration=3}) end)
                    return
                end
                pcall(function()
                    local config = ConfigManager:Config(ConfigName)
                    if config and config:Save() then
                        WindUI:Notify({
                            Title = "✅ 配置已保存",
                            Content = "配置 '" .. ConfigName .. "' 已保存",
                            Icon = "solar:check-circle-bold", Duration = 3,
                        })
                        AllConfigsDropdown:Refresh(ConfigManager:AllConfigs())
                    end
                end)
            end
        })

        configTab:Space()

        configTab:Button({
            Title = "📂 加载配置",
            Icon = "solar:refresh-circle-bold",
            Justify = "Center",
            Color = Color3.fromHex("#10C550"),
            Callback = function()
                if not ConfigManager then
                    pcall(function() WindUI:Notify({Title="错误", Content="配置系统不可用", Duration=3}) end)
                    return
                end
                pcall(function()
                    local config = ConfigManager:CreateConfig(ConfigName, false)
                    if config and config:Load() then
                        WindUI:Notify({
                            Title = "✅ 配置已加载",
                            Content = "配置 '" .. ConfigName .. "' 已加载",
                            Icon = "solar:refresh-circle-bold", Duration = 3,
                        })
                    end
                end)
            end
        })

        configTab:Space()

        configTab:Button({
            Title = "🗑️ 删除配置",
            Icon = "solar:trash-bin-trash-bold",
            Justify = "Center",
            Color = Color3.fromHex("#ff3040"),
            Callback = function()
                if not ConfigManager then return end
                pcall(function()
                    local config = ConfigManager:Config(ConfigName)
                    if config and config:Delete() then
                        WindUI:Notify({
                            Title = "🗑️ 配置已删除",
                            Content = "配置 '" .. ConfigName .. "' 已删除",
                            Icon = "solar:trash-bin-trash-bold", Duration = 3,
                        })
                        AllConfigsDropdown:Refresh(ConfigManager:AllConfigs())
                    end
                end)
            end
        })

        configTab:Divider()

        configTab:Paragraph({
            Title = "💡 提示",
            Desc = "所有带 Flag 的元素会自动保存/恢复\n包括：透视开关、快捷键、滑块、颜色等"
        })

        -- ===== 自动加载配置 =====
        task.spawn(function()
            task.wait(1)
            pcall(function()
                if ConfigManager then
                    local config = ConfigManager:CreateConfig("default", true)
                    if config then
                        print("[机场安全透视] 自动加载配置: default")
                    end
                end
            end)
        end)

        -- ===== 关于 =====
        local aboutTab = win:Tab({Title="关于", Icon="solar:info-square-bold"})
        aboutTab:Paragraph({Title="机场安全透视 v9.0", Desc="用于分辨好人与坏人的透视脚本"})
        aboutTab:Divider()
        aboutTab:Paragraph({Title="👤 作者", Desc="b站英吉利超入_"})
        aboutTab:Divider()
        local usage = IsMobile and "手机: 点击悬浮按钮" or "PC: 按 RightShift 打开菜单"
        aboutTab:Paragraph({Title="💡 使用说明", Desc=usage})
        aboutTab:Paragraph({Title="⚠️ 提示", Desc="所有功能默认关闭，请在菜单中手动开启"})
        aboutTab:Paragraph({Title="✨ 高级功能", Desc="配置保存 | 毛玻璃效果 | Solar图标"})
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
                        if WindowRef then
                            pcall(function() WindowRef:Toggle() end)
                        end
                    end)
                end)
            end)
        end
    end

    print("[机场安全透视] v9.0 已加载 | 作者: b站英吉利超入_")
else
    -- ===== WindUI 加载失败，原生模式 =====
    print("[机场安全透视] WindUI 加载失败，使用原生模式")
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
        if Settings.Enabled then task.spawn(scanNPCs) end
    end)

    task.spawn(function()
        while true do
            pcall(function() cleanESP(); scanNPCs() end)
            task.wait(3)
        end
    end)
end

print("[机场安全透视] 脚本加载完成")
