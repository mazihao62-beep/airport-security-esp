--[[
    机场安全透视脚本 v12.1
    作者: b站英吉利超入_
    
    v12.1 UI Bug审查修复:
    B1: 手机按钮调用 WindowRef:Toggle() 不存在 → 改用 VirtualInputManager 模拟ToggleKey
    B2: ThemeColors[selected] 可能为 nil → 备用蓝色
    B3: TweenService/RunService 未使用 → 移除
    B4: beautifyUI 只运行一次 → 改为每3秒持续运行
    B5: 手机悬浮按钮拖拽越界 → 边界钳制
    B6: 手机检测 IsMobile 不可靠 → 增加 MouseEnabled 检测
]]

-- ========== 服务 ==========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- B6: 改进的移动端检测
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if not IsMobile then
    pcall(function() IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled end)
end

-- ========== 脚本Tag清理系统 ==========
local TAG_NAME = "AirportESP"

local function tagAndTrack(instance)
    if not instance then return nil end
    pcall(function() instance:SetAttribute(TAG_NAME, true) end)
    return instance
end

-- 启动时彻底清除上一次运行的残留
task.spawn(function()
    task.wait(0.1)
    local count = 0
    pcall(function()
        for _, inst in ipairs(CoreGui:GetDescendants()) do
            local s, attr = pcall(function() return inst:GetAttribute(TAG_NAME) end)
            if s and attr then pcall(function() inst:Destroy() end); count = count + 1 end
        end
    end)
    if count > 0 then print("[清理] 已清除 " .. count .. " 个旧实例") end
end)

-- ========== 配置 ==========
local Settings = {
    Enabled = false, BadOnly = false, ShowDistance = false, ShowHealth = false,
    MaxRange = 500, Particles = true, CurrentTheme = "Dark",
    ParticleColor = Color3.fromRGB(100, 180, 255),
}

-- ========== 主题色映射表 ==========
local ThemeColors = {
    Dark = Color3.fromRGB(100, 180, 255), Light = Color3.fromRGB(80, 140, 200),
    Rose = Color3.fromRGB(255, 120, 160), Plant = Color3.fromRGB(100, 200, 120),
    Ocean = Color3.fromRGB(80, 180, 230), Sunset = Color3.fromRGB(255, 150, 80),
    Midnight = Color3.fromRGB(120, 100, 220), Forest = Color3.fromRGB(80, 170, 80),
    Lavender = Color3.fromRGB(180, 130, 255), Coral = Color3.fromRGB(255, 130, 100),
    Mint = Color3.fromRGB(100, 220, 180), Peanut = Color3.fromRGB(200, 170, 100),
    Sky = Color3.fromRGB(130, 180, 255), Blood = Color3.fromRGB(220, 80, 80),
    Lemon = Color3.fromRGB(220, 200, 80), Cyber = Color3.fromRGB(0, 220, 200),
}

local ESPObjects = {}; local TrackedNPCs = {}; local IsScanning = false
local WindowRef = nil; local FloatingButtonGui = nil; local ParticleGui = nil
local Stats = {Good = 0, Bad = 0, Total = 0}; local Controls = {}; local Keybinds = {}
local PopupConfirmed = false; local TabElements = {}; local ConfigName = "default"
local DebugLog = {}; local ParticleRunning = false; local Particles = {}

-- B1: 手机浏览器窗口切换（模拟 ToggleKey 按键）
-- 不依赖 WindowRef:Toggle()（不存在）
-- 改用 VirtualInputManager 发送 RightShift 键事件
local function mobileToggleWindow()
    if not WindowRef then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
    end)
end

local function debugPrint(msg)
    table.insert(DebugLog, msg); if #DebugLog > 100 then table.remove(DebugLog, 1) end; print("[ESP调试] " .. msg)
end

-- ========== 粒子背景系统 ==========
local function getParticleColor()
    return Settings.ParticleColor or Color3.fromRGB(100, 180, 255)
end

local function createParticles()
    if ParticleGui then pcall(function() ParticleGui:Destroy() end); ParticleGui = nil end; Particles = {}
    if not Settings.Particles then return end
    pcall(function()
        ParticleGui = tagAndTrack(Instance.new("ScreenGui"))
        ParticleGui.Name = "AirportESP_Particles"; ParticleGui.ResetOnSpawn = false; ParticleGui.DisplayOrder = -999
        ParticleGui.IgnoreGuiInset = true; ParticleGui.Parent = CoreGui
        local particleColor = getParticleColor()
        for i = 1, 50 do
            local dot = tagAndTrack(Instance.new("Frame")); local size = math.random(4, 8)
            dot.Size = UDim2.new(0, size, 0, size)
            dot.Position = UDim2.new(0.28 + math.random() * 0.30, 0, 0.18 + math.random() * 0.32, 0)
            dot.BackgroundColor3 = particleColor; dot.BackgroundTransparency = 0.4 + math.random() * 0.4
            dot.BorderSizePixel = 0; dot.Parent = ParticleGui
            local c = tagAndTrack(Instance.new("UICorner")); c.CornerRadius = UDim.new(0, 10); c.Parent = dot
            local angle = math.random() * 6.28; local speed = 0.0002 + math.random() * 0.0006
            table.insert(Particles, {Frame = dot, Vx = math.cos(angle) * speed, Vy = math.sin(angle) * speed, Phase = math.random() * 6.28, SizeBase = size, MinBoundX = 0.28, MaxBoundX = 0.58, MinBoundY = 0.18, MaxBoundY = 0.50})
        end
        ParticleRunning = true
        task.spawn(function()
            local time = 0
            while ParticleRunning and ParticleGui and ParticleGui.Parent do
                time = time + 0.03
                pcall(function()
                    for _, p in ipairs(Particles) do
                        if not p.Frame or not p.Frame.Parent then continue end
                        local x = p.Frame.Position.X.Scale + p.Vx; local y = p.Frame.Position.Y.Scale + p.Vy
                        if x > p.MaxBoundX then x = p.MaxBoundX; p.Vx = -p.Vx + (math.random() - 0.5) * 0.0001 elseif x < p.MinBoundX then x = p.MinBoundX; p.Vx = -p.Vx + (math.random() - 0.5) * 0.0001 end
                        if y > p.MaxBoundY then y = p.MaxBoundY; p.Vy = -p.Vy + (math.random() - 0.5) * 0.0001 elseif y < p.MinBoundY then y = p.MinBoundY; p.Vy = -p.Vy + (math.random() - 0.5) * 0.0001 end
                        p.Frame.Position = UDim2.new(x, 0, y, 0)
                        p.Frame.BackgroundTransparency = 0.4 + math.sin(time * 0.8 + p.Phase) * 0.25
                        local s = math.max(1, p.SizeBase + math.sin(time + p.Phase) * 0.8)
                        p.Frame.Size = UDim2.new(0, s, 0, s)
                    end
                end)
                task.wait(0.03)
            end
        end)
    end)
end

local function updateParticleColor()
    local color = getParticleColor(); if not color or #Particles == 0 then return end
    pcall(function() for _, p in ipairs(Particles) do if p.Frame and p.Frame.Parent then p.Frame.BackgroundColor3 = color end end end)
end

local function destroyParticles() ParticleRunning = false; if ParticleGui then pcall(function() ParticleGui:Destroy() end); ParticleGui = nil end; Particles = {} end

-- ========== NPC 分类器 ==========
local function getAllAttributes(obj) local attrs = {}; if not obj then return attrs end; pcall(function() for _, attr in ipairs(obj:GetAttributes()) do attrs[attr] = obj:GetAttribute(attr) end end); return attrs end

local function classifyNPC(character, humanoid)
    local name = character.Name or ""; local path = ""; pcall(function() path = character:GetFullName() end)
    if humanoid then local attrs = getAllAttributes(humanoid); for k, v in pairs(attrs) do debugPrint(string.format("  属性: Humanoid.%s = %s", k, tostring(v))) end end
    local charAttrs = getAllAttributes(character); for k, v in pairs(charAttrs) do debugPrint(string.format("  属性: Character.%s = %s", k, tostring(v))) end
    local tool = character:FindFirstChildOfClass("Tool"); debugPrint(string.format("检测到: %s | 路径: %s", name, path))
    local attributeChecks = {"NPCType", "Type", "Team", "Faction", "Role", "Class", "Group", "Kind", "Identity"}
    for _, attrName in ipairs(attributeChecks) do
        local val = nil; if humanoid then pcall(function() val = humanoid:GetAttribute(attrName) end) end
        if val == nil then pcall(function() val = character:GetAttribute(attrName) end) end
        if val ~= nil then
            local vs = tostring(val):lower(); debugPrint(string.format("  属性[%s] = %s", attrName, tostring(val)))
            for _, good in ipairs({"agent", "good", "friendly", "ally", "police", "friend", "blue", "guard", "clean"}) do if vs:find(good) then debugPrint("  → 属性好人"); return "Good" end end
            for _, bad in ipairs({"enemy", "bad", "hostile", "terrorist", "criminal", "foe", "enem", "red", "danger"}) do if vs:find(bad) then debugPrint("  → 属性坏人"); return "Bad" end end
        end
    end
    debugPrint(string.format("  名字: %s", name))
    for _, kw in ipairs({"警察", "保安", "警卫", "警", "守卫", "士兵", "军官", "长官", "巡逻", "特工", "安全", "安保", "护卫", "卫兵", "军队", "公安", "辅警", "Police", "Security", "Guard", "Agent", "Officer", "Sheriff", "Soldier", "Patrol", "Cop", "Marshal", "Blue", "Friendly", "Ally", "Good"}) do if name:find(kw, 1, true) or name:lower():find(kw:lower(), 1, true) then debugPrint(string.format("  → 名字匹配好人关键词: %s", kw)); return "Good" end end
    for _, kw in ipairs({"恐怖", "匪徒", "匪", "敌人", "坏", "犯罪", "袭击", "暴徒", "杀手", "叛军", "武装", "劫匪", "入侵", "歹徒", "黑帮", "毒贩", "绑匪", "Terrorist", "Enemy", "Hostile", "Criminal", "Threat", "Suspect", "Bandit", "Mercenary", "Attacker", "Red", "Danger", "Bad"}) do if name:find(kw, 1, true) or name:lower():find(kw:lower(), 1, true) then debugPrint(string.format("  → 名字匹配坏人关键词: %s", kw)); return "Bad" end end
    local partColors = {}; for _, part in ipairs(character:GetChildren()) do if part:IsA("BasePart") then local cname = part.BrickColor.Name; partColors[cname] = (partColors[cname] or 0) + 1 end end
    local gcc = 0; local bcc = 0; for c, n in pairs(partColors) do if c:lower():find("blue") or c:lower():find("green") or c:find("White") then gcc = gcc + n end; if c:lower():find("red") or c:lower():find("black") or c:lower():find("brown") or c:lower():find("grey") then bcc = bcc + n end end
    if gcc > bcc and gcc >= 3 then debugPrint(string.format("  → 颜色判断: 好人(蓝绿%d>红黑%d)", gcc, bcc)); return "Good" end
    if bcc > gcc and bcc >= 3 then debugPrint(string.format("  → 颜色判断: 坏人(红黑%d>蓝绿%d)", bcc, gcc)); return "Bad" end
    if character.Parent then local pn = character.Parent.Name; for _, kw in ipairs({"警察", "保安", "Police", "Guard", "Agent"}) do if pn:find(kw, 1, true) then debugPrint("  → 父级好人"); return "Good" end end; for _, kw in ipairs({"恐怖", "匪", "敌人", "Terror", "Enemy"}) do if pn:find(kw, 1, true) then debugPrint("  → 父级坏人"); return "Bad" end end end
    if tool then local tn = tool.Name; for _, kw in ipairs({"Arrest", "Taser", "Bat", "Radio", "Handcuff", "警", "盾", "枪"}) do if tn:find(kw, 1, true) then debugPrint("  → 工具好人"); return "Good" end end; for _, kw in ipairs({"Knife", "Bomb", "Grenade", "RPG", "Explosive", "刀", "炸"}) do if tn:find(kw, 1, true) then debugPrint("  → 工具坏人"); return "Bad" end end end
    local pl = path:lower(); if pl:find("agent") or pl:find("police") or pl:find("friendly") then debugPrint("  → 路径好人"); return "Good" end; if pl:find("npc") or pl:find("enemy") or pl:find("terror") then debugPrint("  → 路径坏人"); return "Bad" end
    debugPrint("  → 无法判断，跳过"); return nil
end

local function isRealPlayer(character)
    if not character or not character:IsA("Model") then return false end
    for _, p in ipairs(Players:GetPlayers()) do if p.Character == character then return true end end; return false
end

local function createESP(character, npcType)
    if not character or not character.Parent then return false end; if isRealPlayer(character) then return false end
    if ESPObjects[character] then
        local color = npcType == "Good" and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
        local obj = ESPObjects[character]; local show = Settings.Enabled and (not Settings.BadOnly or npcType == "Bad")
        if obj.Highlight then obj.Highlight.FillColor = color; obj.Highlight.Enabled = show end; if obj.Billboard then obj.Billboard.Enabled = show end; return true
    end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChildOfClass("Part"); if not root then return false end
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character; local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if myRoot and root and (root.Position - myRoot.Position).Magnitude > Settings.MaxRange then return false end
    local show = Settings.Enabled and (not Settings.BadOnly or npcType == "Bad"); local color = npcType == "Good" and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
    local hl = tagAndTrack(Instance.new("Highlight")); hl.Adornee = character; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.FillTransparency = 0.4; hl.OutlineTransparency = 0.2; hl.FillColor = color; hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.Enabled = show; hl.Parent = CoreGui
    local head = character:FindFirstChild("Head") or character:FindFirstChild("Torso") or root
    local bb = tagAndTrack(Instance.new("BillboardGui")); bb.Adornee = head; bb.Size = UDim2.new(0, 160, 0, 50); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Enabled = show; bb.Parent = CoreGui
    local bg = tagAndTrack(Instance.new("Frame")); bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0); bg.BackgroundTransparency = 0.4; bg.BorderSizePixel = 0; bg.Parent = bb
    local bgc = tagAndTrack(Instance.new("UICorner")); bgc.CornerRadius = UDim.new(0, 4); bgc.Parent = bg
    local lbl = tagAndTrack(Instance.new("TextLabel")); lbl.Size = UDim2.new(1, -4, 0.55, 0); lbl.Position = UDim2.new(0, 2, 0, 2); lbl.BackgroundTransparency = 1; lbl.TextColor3 = color; lbl.TextScaled = true; lbl.Font = Enum.Font.SourceSansBold; lbl.Text = npcType == "Good" and "👮 好人" or "💀 坏人"; lbl.BorderSizePixel = 0; lbl.Parent = bg
    local info = tagAndTrack(Instance.new("TextLabel")); info.Size = UDim2.new(1, -4, 0.4, 0); info.Position = UDim2.new(0, 2, 0.55, 2); info.BackgroundTransparency = 1; info.TextColor3 = Color3.fromRGB(255, 255, 255); info.TextScaled = true; info.Font = Enum.Font.SourceSans; info.Text = ""; info.BorderSizePixel = 0; info.Parent = bg
    ESPObjects[character] = {Highlight = hl, Billboard = bb, Label = lbl, InfoLine = info, Head = head, Root = root}
    if npcType == "Good" then Stats.Good = Stats.Good + 1 else Stats.Bad = Stats.Bad + 1 end; Stats.Total = Stats.Total + 1; TrackedNPCs[character] = npcType; return true
end

local function removeESP(ch) if ESPObjects[ch] then local o = ESPObjects[ch]; pcall(function() o.Highlight:Destroy() end); pcall(function() o.Billboard:Destroy() end); ESPObjects[ch] = nil; local nt = TrackedNPCs[ch]; if nt == "Good" then Stats.Good = math.max(0, Stats.Good - 1) elseif nt == "Bad" then Stats.Bad = math.max(0, Stats.Bad - 1) end; Stats.Total = math.max(0, Stats.Total - 1); TrackedNPCs[ch] = nil end end

local function cleanESP() for ch, _ in pairs(ESPObjects) do if not ch or not ch.Parent then removeESP(ch) end end end

local function updateLabels()
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character; local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    for ch, o in pairs(ESPObjects) do if o.Billboard and o.Billboard.Enabled and o.InfoLine then local pts = {}; if Settings.ShowDistance and myRoot and o.Root then local d = math.floor((o.Root.Position - myRoot.Position).Magnitude + 0.5); table.insert(pts, d .. "m") end; if Settings.ShowHealth then local h = ch:FindFirstChildOfClass("Humanoid"); if h then table.insert(pts, "HP:" .. math.floor(h.Health + 0.5) .. "/" .. math.floor(h.MaxHealth + 0.5)) end end; o.InfoLine.Text = table.concat(pts, " | ") end end
end

local function updateAllESP() for ch, o in pairs(ESPObjects) do local nt = TrackedNPCs[ch]; local s = Settings.Enabled and (not Settings.BadOnly or nt == "Bad"); if o.Highlight then o.Highlight.Enabled = s end; if o.Billboard then o.Billboard.Enabled = s end end end

local function scanNPCs()
    if IsScanning then return end; IsScanning = true; debugPrint("===== 开始扫描 =====")
    pcall(function()
        for _, o in ipairs(Workspace:GetDescendants()) do
            local h, c = nil, nil; if o:IsA("Humanoid") then h = o; c = o.Parent end
            if c and h and not TrackedNPCs[c] and not isRealPlayer(c) then
                if c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") then
                    debugPrint(string.format("发现NPC (Humanoid): %s", c.Name)); local nt = classifyNPC(c, h); if nt then createESP(c, nt) end
                end
            end; task.wait()
        end
    end)
    debugPrint(string.format("===== 扫描结束: 好人%d 坏人%d =====", Stats.Good, Stats.Bad)); IsScanning = false
end

-- B4: beautifyUI 每3秒运行一次，覆盖新创建的ScrollingFrame
local function beautifyUI()
    pcall(function() for _, s in ipairs(CoreGui:GetDescendants()) do if s:IsA("ScrollingFrame") then s.ScrollBarThickness = 14; s.ScrollBarImageColor3 = Color3.fromRGB(220, 220, 220); s.ScrollBarImageTransparency = 0.1 end end end)
end

task.spawn(function() while true do task.wait(3); beautifyUI() end end)

-- ========== 加载 WindUI ==========
local WindUI = nil
local s, r = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))() end)

if s and r then
    WindUI = r; pcall(function() WindUI:SetTheme("Dark") end)

    WindUI:Popup({
        Title = "机场安全透视 v12.1",
        Icon = "solar:info-square-bold",
        Content = "👁 透视高亮 - Highlight穿墙显示所有NPC\n🔍 智能识别 - 多维度区分好人(绿)与坏人(红)\n🏷 头顶标签 - 显示类型/距离/血量\n🔧 自定义快捷键 - 自由绑定按键\n💾 配置保存 - 自动保存/读取设置\n🎨 主题系统 - 16种内置主题\n✨ 粒子背景 - 紧约束窗口内飘浮 + 主题色适配\n🧹 脚本Tag清理 - 重启自动清除所有残留\n\n⚠️ 加载后所有功能默认关闭，需手动开启",
        Buttons = {
            { Title = "取消", Callback = function() end, Variant = "Tertiary" },
            { Title = "确认加载", Icon = "solar:arrow-right-bold", Callback = function()
                PopupConfirmed = true
                pcall(function() WindUI:Notify({Title = "✅ 已加载", Content = "⌨️ 按 RightShift 打开菜单", Duration = 4, Icon = "solar:bell-bold"}) end)
                task.spawn(function() createWindow(); task.wait(0.3); scanNPCs() end)
            end, Variant = "Primary" }
        }
    })

    task.spawn(function()
        while not PopupConfirmed do task.wait(0.5) end; task.wait(0.5); beautifyUI()
        task.spawn(function() while true do pcall(function() cleanESP(); scanNPCs() end) task.wait(5) end end)
        task.spawn(function()
            while true do
                pcall(function()
                    if TabElements.GoodP then TabElements.GoodP:SetTitle("🟢 好人: " .. Stats.Good); TabElements.BadP:SetTitle("🔴 坏人: " .. Stats.Bad); TabElements.TotalP:SetTitle("📊 总计: " .. Stats.Total) end
                    if TabElements.ScanI then TabElements.ScanI:Set(IsScanning and "📡 扫描中..." or "✅ 就绪") end
                    if TabElements.DebugI then local ls = {}; for i = math.max(1, #DebugLog - 4), #DebugLog do table.insert(ls, DebugLog[i]) end; TabElements.DebugI:Set(table.concat(ls, "\n")) end
                    updateLabels()
                end)
                task.wait(0.5)
            end
        end)
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end; if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local kn = input.KeyCode.Name
            if Keybinds.ESP and Keybinds.ESP ~= "" and kn == Keybinds.ESP then Settings.Enabled = not Settings.Enabled; pcall(function() if Controls.ESPToggle then Controls.ESPToggle:Set(Settings.Enabled) end end); updateAllESP(); if Settings.Enabled then task.spawn(scanNPCs) end end
            if Keybinds.BadOnly and Keybinds.BadOnly ~= "" and kn == Keybinds.BadOnly then Settings.BadOnly = not Settings.BadOnly; pcall(function() if Controls.BadOnlyToggle then Controls.BadOnlyToggle:Set(Settings.BadOnly) end end); updateAllESP() end
        end)
    end)

    function createWindow()
        if WindowRef then return end
        local ok, win = pcall(function() return WindUI:CreateWindow({Title = "机场安全透视", Author = "b站英吉利超入_", Icon = "solar:shield-warning-bold", Size = UDim2.fromOffset(750, 520), ToggleKey = Enum.KeyCode.RightShift, Folder = "airport-esp", Acrylic = true, Transparent = true, Resizable = false, SideBarWidth = 180, ScrollBarEnabled = true, HideSearchBar = true}) end)
        if not ok or not win then print("[机场安全透视] 窗口创建失败:", ok); return end
        WindowRef = win; pcall(function() WindUI.TransparencyValue = 0.22 end)

        local mainTab = win:Tab({Title = "主控面板", Icon = "solar:slider-vertical-bold"})
        mainTab:Paragraph({Title = "👁 透视控制"})
        Controls.ESPToggle = mainTab:Toggle({Flag = "ESPToggle", Title = "透视开关", Value = false, Callback = function(v) Settings.Enabled = v; updateAllESP(); if v then task.spawn(scanNPCs) end end})
        Controls.BadOnlyToggle = mainTab:Toggle({Flag = "BadOnlyToggle", Title = "仅显示坏人", Value = false, Callback = function(v) Settings.BadOnly = v; updateAllESP() end})
        mainTab:Divider(); mainTab:Paragraph({Title = "📐 显示设置"})
        Controls.DistanceToggle = mainTab:Toggle({Flag = "DistanceToggle", Title = "显示距离", Value = false, Callback = function(v) Settings.ShowDistance = v end})
        Controls.HealthToggle = mainTab:Toggle({Flag = "HealthToggle", Title = "显示血量", Value = false, Callback = function(v) Settings.ShowHealth = v end})
        mainTab:Divider()
        Controls.RangeSlider = mainTab:Slider({Flag = "RangeSlider", Title = "最大探测距离", Step = 50, Value = {Min = 50, Max = 1000, Default = 500}, Width = 200, IsTextbox = true, Callback = function(v) Settings.MaxRange = v end})

        local funcTab = win:Tab({Title = "功能设置", Icon = "solar:settings-bold"})
        funcTab:Paragraph({Title = "🔑 快捷键设置"})
        Controls.ESPKeybind = funcTab:Keybind({Flag = "ESPKeybind", Title = "透视开关快捷键", Value = "", Callback = function(k) Keybinds.ESP = k end})
        Controls.BadOnlyKeybind = funcTab:Keybind({Flag = "BadOnlyKeybind", Title = "仅坏人模式快捷键", Value = "", Callback = function(k) Keybinds.BadOnly = k end})
        funcTab:Divider(); funcTab:Paragraph({Title = "💡 提示", Desc = "窗口快捷键在UI设置中绑定（默认 RightShift）"})

        local uiTab = win:Tab({Title = "UI设置", Icon = "solar:monitor-bold"})
        uiTab:Paragraph({Title = "⚙️ 界面设置"})
        Controls.WindowKeybind = uiTab:Keybind({Flag = "WindowKeybind", Title = "窗口开关快捷键", Value = "RightShift", Callback = function(k) Keybinds.Window = k; if WindowRef then pcall(function() WindowRef:SetToggleKey(Enum.KeyCode[k]) end) end end})
        Controls.FloatingBtnToggle = uiTab:Toggle({Flag = "FloatingBtnToggle", Title = "显示悬浮按钮", Value = IsMobile, Callback = function(v) if FloatingButtonGui then FloatingButtonGui.Enabled = v end end})
        uiTab:Divider(); uiTab:Paragraph({Title = "🌀 背景效果"})
        Controls.ParticlesToggle = uiTab:Toggle({Flag = "ParticlesToggle", Title = "浮动粒子背景", Value = true, Callback = function(v) Settings.Particles = v; if v then createParticles() else destroyParticles() end end})
        uiTab:Divider(); uiTab:Paragraph({Title = "✨ 窗口效果"})
        Controls.AcrylicToggle = uiTab:Toggle({Flag = "AcrylicToggle", Title = "毛玻璃效果", Value = true, Callback = function(v) pcall(function() WindUI:ToggleAcrylic(v) end) end})
        Controls.TransparencyToggle = uiTab:Toggle({Flag = "TransparencyToggle", Title = "透明背景增强毛玻璃", Value = true, Callback = function(v) if WindowRef then pcall(function() WindowRef:ToggleTransparency(v) end) end end})
        uiTab:Divider(); uiTab:Paragraph({Title = "🎨 主题系统", Desc = "切换主题时粒子颜色自动适配"})
        local allThemes = {}; pcall(function() allThemes = WindUI:GetThemes() end)
        local themeNames = {}; for n, _ in pairs(allThemes) do table.insert(themeNames, n) end; table.sort(themeNames)
        Controls.ThemeDropdown = uiTab:Dropdown({Flag = "ThemeDropdown", Title = "选择主题", Values = themeNames, Value = "Dark", Callback = function(selected)
            if selected then Settings.CurrentTheme = selected; pcall(function() WindUI:SetTheme(selected) end); local c = ThemeColors[selected]; Settings.ParticleColor = c or Color3.fromRGB(100, 180, 255); updateParticleColor() end
        end})
        uiTab:Divider(); uiTab:Paragraph({Title = "💡 提示", Desc = "粒子在窗口区域内飘浮，速度柔和\n切换主题→粒子颜色同步更新"})

        local statsTab = win:Tab({Title = "信息统计", Icon = "solar:chart-bold"})
        TabElements.GoodP = statsTab:Paragraph({Title = "🟢 好人: 0"}); TabElements.BadP = statsTab:Paragraph({Title = "🔴 坏人: 0"}); TabElements.TotalP = statsTab:Paragraph({Title = "📊 总计: 0"})
        statsTab:Divider(); TabElements.ScanI = statsTab:Input({Title = "扫描状态", Value = "等待中...", Locked = true})
        statsTab:Divider(); TabElements.DebugI = statsTab:Input({Title = "📋 调试日志", Value = "等待检测...", Locked = true, Desc = "每次扫描会显示NPC的属性信息"})

        local configTab = win:Tab({Title = "配置管理", Icon = "solar:diskette-bold"})
        configTab:Paragraph({Title = "💾 配置管理", Desc = "保存/加载你的所有设置"})
        local ConfigNameInput = configTab:Input({Flag = "ConfigNameInput", Title = "配置名称", Value = "default", Icon = "solar:file-text-bold", Callback = function(v) ConfigName = v end})
        configTab:Space()
        local CM = WindowRef.ConfigManager; local AC = {}; pcall(function() AC = CM:AllConfigs() end)
        local DV = nil; pcall(function() for _, v in ipairs(AC) do if v == "default" then DV = "default"; break end end end)
        local ACD = configTab:Dropdown({Title = "已有配置", Desc = "选择要加载的配置", Values = AC, Value = DV, Callback = function(v) if v then ConfigName = v; pcall(function() ConfigNameInput:Set(v) end) end end})
        configTab:Space()
        configTab:Button({Title = "💾 保存配置", Icon = "solar:check-circle-bold", Justify = "Center", Color = Color3.fromHex("#305dff"), Callback = function() if not CM then return end; pcall(function() local c = CM:Config(ConfigName); if c and c:Save() then WindUI:Notify({Title = "✅ 配置已保存", Content = "配置 '" .. ConfigName .. "' 已保存", Icon = "solar:check-circle-bold", Duration = 3}); ACD:Refresh(CM:AllConfigs()) end end) end})
        configTab:Space()
        configTab:Button({Title = "📂 加载配置", Icon = "solar:refresh-circle-bold", Justify = "Center", Color = Color3.fromHex("#10C550"), Callback = function() if not CM then return end; pcall(function() local c = CM:CreateConfig(ConfigName, false); if c and c:Load() then WindUI:Notify({Title = "✅ 配置已加载", Content = "配置 '" .. ConfigName .. "' 已加载", Icon = "solar:refresh-circle-bold", Duration = 3}) end end) end})
        configTab:Space()
        configTab:Button({Title = "🗑️ 删除配置", Icon = "solar:trash-bin-trash-bold", Justify = "Center", Color = Color3.fromHex("#ff3040"), Callback = function() if not CM then return end; pcall(function() local c = CM:Config(ConfigName); if c and c:Delete() then WindUI:Notify({Title = "🗑️ 配置已删除", Content = "配置 '" .. ConfigName .. "' 已删除", Icon = "solar:trash-bin-trash-bold", Duration = 3}); ACD:Refresh(CM:AllConfigs()) end end) end})
        configTab:Divider()
        configTab:Paragraph({Title = "💡 提示", Desc = "所有带 Flag 的元素自动保存/恢复\n脚本Tag清理: 重启脚本自动清除全部残留"})

        task.spawn(function() task.wait(1); pcall(function() if CM then local c = CM:CreateConfig("default", true) end end); createParticles() end)

        local aboutTab = win:Tab({Title = "关于", Icon = "solar:info-square-bold"})
        aboutTab:Paragraph({Title = "机场安全透视 v12.1", Desc = "7个UI Bug彻底修复"})
        aboutTab:Divider(); aboutTab:Paragraph({Title = "👤 作者", Desc = "b站英吉利超入_"})
        aboutTab:Divider(); aboutTab:Paragraph({Title = "💡 使用说明", Desc = IsMobile and "手机: 点击悬浮按钮" or "PC: 按 RightShift 打开菜单"})
        aboutTab:Paragraph({Title = "⚠️ 提示", Desc = "所有功能默认关闭，请在菜单中手动开启"})
        aboutTab:Paragraph({Title = "🧹 清理", Desc = "重启脚本自动清除所有残留 (脚本Tag系统)"})

        if IsMobile then
            task.spawn(function()
                task.wait(1)
                pcall(function()
                    FloatingButtonGui = tagAndTrack(Instance.new("ScreenGui"))
                    FloatingButtonGui.Name = "AirportESP_Btn"; FloatingButtonGui.Enabled = true; FloatingButtonGui.ResetOnSpawn = false; FloatingButtonGui.Parent = CoreGui
                    local btn = tagAndTrack(Instance.new("ImageButton"))
                    btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.9, -25, 0.8, -25)
                    btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80); btn.BackgroundTransparency = 0.2; btn.BorderSizePixel = 0; btn.Parent = FloatingButtonGui
                    local c = tagAndTrack(Instance.new("UICorner")); c.CornerRadius = UDim.new(0, 25); c.Parent = btn
                    local t = tagAndTrack(Instance.new("TextLabel"))
                    t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = "👁"; t.TextScaled = true; t.Font = Enum.Font.SourceSansBold; t.TextColor3 = Color3.fromRGB(255, 255, 255); t.Parent = btn
                    local dragging, dragStart, startPos = false, nil, nil
                    btn.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = inp.Position; startPos = btn.Position end
                    end)
                    btn.InputChanged:Connect(function(inp)
                        if dragging and (inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseMovement) then
                            local newX = startPos.X.Scale + (inp.Position.X - dragStart.X) / 800; local newY = startPos.Y.Scale + (inp.Position.Y - dragStart.Y) / 600
                            -- B5: 钳制按钮位置，不超出屏幕
                            newX = math.max(0.02, math.min(0.95, newX)); newY = math.max(0.02, math.min(0.95, newY))
                            btn.Position = UDim2.new(newX, 0, newY, 0)
                        end
                    end)
                    btn.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
                    -- B1: 使用 VirtualInputManager 模拟按键，替代不存在的 WindowRef:Toggle()
                    btn.MouseButton1Click:Connect(mobileToggleWindow)
                end)
            end)
        end
    end

    print("[机场安全透视] v12.1 已加载 | 作者: b站英吉利超入_")
else
    print("[机场安全透视] WindUI 加载失败，使用原生模式")
    local msg = Instance.new("Message"); msg.Text = "⚠️ WindUI 加载失败，使用原生模式"; msg.Parent = Workspace; task.delay(5, function() msg:Destroy() end)
    local btnGui = tagAndTrack(Instance.new("ScreenGui")); btnGui.Name = "AirportESP_Btn"; btnGui.ResetOnSpawn = false; btnGui.Parent = CoreGui
    local btn = tagAndTrack(Instance.new("ImageButton")); btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.9, -25, 0.8, -25); btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80); btn.BackgroundTransparency = 0.2; btn.BorderSizePixel = 0; btn.Parent = btnGui
    local c = tagAndTrack(Instance.new("UICorner")); c.CornerRadius = UDim.new(0, 25); c.Parent = btn
    local t = tagAndTrack(Instance.new("TextLabel")); t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = "👁"; t.TextScaled = true; t.Font = Enum.Font.SourceSansBold; t.TextColor3 = Color3.fromRGB(255, 255, 255); t.Parent = btn
    btn.MouseButton1Click:Connect(function() Settings.Enabled = not Settings.Enabled; updateAllESP(); btn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 180, 80); if Settings.Enabled then task.spawn(scanNPCs) end end)
    task.spawn(function() while true do pcall(function() cleanESP(); scanNPCs() end) task.wait(3) end end)
end

print("[机场安全透视] v12.1 脚本加载完成")
