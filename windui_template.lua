--[[
    WindUI 通用脚本模板 v1.0
    基于: 机场安全透视 v11.0 UI 结构
    作者: b站英吉利超入_
    说明: 以后所有 WindUI 脚本都用这个模板
]]

-- ===================== 模板说明 =====================
-- 此模板包含 WindUI 脚本的完整标准结构：
-- ✅ WindUI 加载 + Popup 确认弹窗
-- ✅ 6 个标准 Tab: 主控面板 / 功能设置 / UI设置 / 信息统计 / 配置管理 / 关于
-- ✅ 粒子背景系统 (35个呼吸粒子)
-- ✅ 增强毛玻璃 (Acrylic + Transparent)
-- ✅ 16种内置主题 (下拉选择器)
-- ✅ 配置保存系统 (保存/加载/删除 + 下拉选择)
-- ✅ 手机/PC 自适应 (悬浮按钮 + 快捷键)
-- ✅ 快捷键监听系统 (窗口/功能快捷键分离)
-- ✅ 带 Flag 的控件自动接入配置保存
--
-- 使用方法:
-- 1. 复制此文件到你的项目
-- 2. 搜索 "【你的功能】" 替换为实际功能
-- 3. 修改 Window 标题/作者/Size
-- 4. 在 主控面板/功能设置/信息统计 添加你的控件
-- 5. 去掉你不需要的 Tab
-- ===================================================

-- ===================== 服务 =====================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- ===================== 平台检测 =====================
local IsMobile = false
pcall(function()
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end)

-- ===================== 设置 =====================
-- 【自定义】在这里添加你的功能设置项
local Settings = {
    -- 内置设置（不要删）
    Particles = true,
    CurrentTheme = "Dark",
    -- 【你的功能】在此添加默认值
    -- Example: Enabled = false, Value = 100,
}

-- ===================== 内部变量 =====================
local WindowRef = nil
local FloatingButtonGui = nil
local ParticleGui = nil
local ParticleRunning = false
local PopupConfirmed = false
local Controls = {}
local Keybinds = {}
local TabElements = {}
local ConfigName = "default"

-- ===================== 粒子背景系统 =====================
local function createParticles()
    if ParticleGui then
        pcall(function() ParticleGui:Destroy() end)
        ParticleGui = nil
    end
    if not Settings.Particles then return end

    pcall(function()
        ParticleGui = Instance.new("ScreenGui")
        ParticleGui.Name = "Template_Particles"
        ParticleGui.ResetOnSpawn = false
        ParticleGui.DisplayOrder = -999
        ParticleGui.IgnoreGuiInset = true
        ParticleGui.Parent = CoreGui

        local numParticles = 35
        local particles = {}

        for i = 1, numParticles do
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, math.random(2, 5), 0, math.random(2, 5))
            dot.Position = UDim2.new(math.random(), 0, math.random(), 0)
            dot.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
            dot.BackgroundTransparency = math.random(30, 70) / 100
            dot.BorderSizePixel = 0
            dot.Parent = ParticleGui

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 10)
            c.Parent = dot

            table.insert(particles, {
                Frame = dot,
                SpeedX = (math.random() - 0.5) * 0.015,
                SpeedY = (math.random() - 0.5) * 0.015,
                DriftX = (math.random() - 0.5) * 0.002,
                DriftY = (math.random() - 0.5) * 0.002,
                Phase = math.random() * 6.28,
                SizeBase = math.random(2, 5),
            })
        end

        ParticleRunning = true
        task.spawn(function()
            local time = 0
            while ParticleRunning and ParticleGui and ParticleGui.Parent do
                time = time + 0.03
                pcall(function()
                    for _, p in ipairs(particles) do
                        if not p.Frame or not p.Frame.Parent then continue end
                        local x = p.Frame.Position.X.Scale + p.SpeedX + math.sin(time + p.Phase) * p.DriftX
                        local y = p.Frame.Position.Y.Scale + p.SpeedY + math.cos(time + p.Phase) * p.DriftY
                        if x > 1 then x = -0.05 end
                        if x < -0.05 then x = 1 end
                        if y > 1 then y = -0.05 end
                        if y < -0.05 then y = 1 end
                        p.Frame.Position = UDim2.new(x, 0, y, 0)
                        local breathe = 0.5 + math.sin(time * 1.5 + p.Phase) * 0.3
                        p.Frame.BackgroundTransparency = breathe
                        local sizeBase = p.SizeBase
                        p.Frame.Size = UDim2.new(0, sizeBase + math.sin(time + p.Phase) * 1.5, 0, sizeBase + math.sin(time + p.Phase) * 1.5)
                    end
                end)
                task.wait(0.03)
            end
        end)
    end)
end

local function destroyParticles()
    ParticleRunning = false
    if ParticleGui then
        pcall(function() ParticleGui:Destroy() end)
        ParticleGui = nil
    end
end

-- ===================== 美化UI =====================
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

-- ===================== 加载 WindUI =====================
local WindUI = nil
local s, r = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if s and r then
    WindUI = r
    pcall(function() WindUI:SetTheme("Dark") end)

    -- ===================== Popup 确认弹窗 =====================
    WindUI:Popup({
        Title = "【你的脚本名】v1.0",
        Icon = "solar:info-square-bold",
        Content = "📋 功能1 - 说明1\n📋 功能2 - 说明2\n📋 功能3 - 说明3\n💾 配置保存 - 自动保存/读取设置\n🎨 主题系统 - 16种内置主题\n✨ 粒子背景 - 动态浮动粒子\n🌀 增强毛玻璃 - Acrylic+透明叠加\n\n⚠️ 加载后所有功能默认关闭，需手动开启",
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
                    -- 【自定义】加载后需要执行的操作
                end)
            end, Variant = "Primary" }
        }
    })

    -- ===================== 等待确认后启动 =====================
    task.spawn(function()
        while not PopupConfirmed do task.wait(0.5) end
        task.wait(1.5)
        beautifyUI()

        -- 【自定义】后台循环
        -- task.spawn(function()
        --     while true do
        --         pcall(function()
        --             -- 你的功能循环
        --         end)
        --         task.wait(你的间隔)
        --     end
        -- end)

        -- 信息统计更新循环
        task.spawn(function()
            while true do
                pcall(function()
                    -- 【自定义】更新统计信息
                    -- if TabElements.xxx then TabElements.xxx:SetTitle("...") end
                end)
                task.wait(0.5)
            end
        end)

        -- ===================== 快捷键监听 =====================
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local keyName = input.KeyCode.Name

            -- 【自定义】功能快捷键
            -- if Keybinds.XXX and Keybinds.XXX ~= "" and keyName == Keybinds.XXX then
            --     Settings.XXX = not Settings.XXX
            --     pcall(function()
            --         if Controls.XXX then Controls.XXX:Set(Settings.XXX) end
            --     end)
            --     -- 执行操作
            -- end
        end)
    end)

    -- ===================== 创建窗口 =====================
    function createWindow()
        if WindowRef then return end

        local ok, win = pcall(function()
            return WindUI:CreateWindow({
                Title = "【你的脚本名】",
                Author = "b站英吉利超入_",
                Icon = "solar:shield-warning-bold",
                Size = UDim2.fromOffset(750, 520),
                ToggleKey = Enum.KeyCode.RightShift,
                Folder = "【你的项目名-folder】",  -- 配置保存用
                Acrylic = true,
                Transparent = true,
                Resizable = false,
                SideBarWidth = 180,
                ScrollBarEnabled = true,
                HideSearchBar = true,
            })
        end)
        if not ok or not win then
            print("[模板] 窗口创建失败:", ok)
            return
        end
        WindowRef = win

        -- 毛玻璃透明度
        pcall(function() WindUI.TransparencyValue = 0.22 end)

        -- ===================== Tab 1: 主控面板 =====================
        local mainTab = win:Tab({Title="主控面板", Icon="solar:slider-vertical-bold"})

        -- Section: 功能控制
        mainTab:Paragraph({Title="🎯 功能控制"})

        -- 【自定义】添加 Toggle
        -- Controls.YourToggle = mainTab:Toggle({
        --     Flag = "YourToggle", Title = "功能开关", Value = false,
        --     Callback = function(v) Settings.YourSetting = v end
        -- })

        mainTab:Divider()

        -- Section: 参数设置
        mainTab:Paragraph({Title="⚙️ 参数设置"})

        -- 【自定义】添加 Slider
        -- Controls.YourSlider = mainTab:Slider({
        --     Flag = "YourSlider", Title = "参数名", Step = 1,
        --     Value = { Min = 0, Max = 100, Default = 50 },
        --     Width = 200, IsTextbox = true,
        --     Callback = function(v) Settings.YourParam = v end
        -- })

        -- 【自定义】添加 Dropdown
        -- Controls.YourDropdown = mainTab:Dropdown({
        --     Flag = "YourDropdown", Title = "选项名",
        --     Values = {"A", "B", "C"}, Value = "A",
        --     Callback = function(v) Settings.YourOption = v end
        -- })

        -- 【自定义】添加 Input
        -- Controls.YourInput = mainTab:Input({
        --     Flag = "YourInput", Title = "输入框名", Value = "默认值",
        --     Callback = function(v) Settings.YourText = v end
        -- })

        -- ===================== Tab 2: 功能设置 =====================
        local funcTab = win:Tab({Title="功能设置", Icon="solar:settings-bold"})
        funcTab:Paragraph({Title="🔑 快捷键设置（点击后按键盘绑定）"})

        -- 【自定义】功能快捷键
        -- Controls.YourKeybind = funcTab:Keybind({
        --     Flag = "YourKeybind", Title = "功能快捷键", Value = "",
        --     Callback = function(key) Keybinds.YourFunc = key end
        -- })

        funcTab:Divider()
        funcTab:Paragraph({Title="💡 提示", Desc="窗口快捷键在UI设置中绑定（默认 RightShift）"})

        -- ===================== Tab 3: UI 设置 =====================
        local uiTab = win:Tab({Title="UI设置", Icon="solar:monitor-bold"})

        -- Section: 界面设置
        uiTab:Paragraph({Title="⚙️ 界面设置"})
        Controls.WindowKeybind = uiTab:Keybind({
            Flag = "WindowKeybind", Title = "窗口开关快捷键", Value = "RightShift",
            Callback = function(key)
                Keybinds.Window = key
                if WindowRef then pcall(function() WindowRef:SetToggleKey(Enum.KeyCode[key]) end) end
            end
        })
        Controls.FloatingBtnToggle = uiTab:Toggle({
            Flag = "FloatingBtnToggle", Title = "显示悬浮按钮", Value = IsMobile,
            Callback = function(v) if FloatingButtonGui then FloatingButtonGui.Enabled = v end end
        })
        uiTab:Divider()

        -- Section: 背景效果
        uiTab:Paragraph({Title="🌀 背景效果"})
        Controls.ParticlesToggle = uiTab:Toggle({
            Flag = "ParticlesToggle", Title = "浮动粒子背景", Value = true,
            Callback = function(v)
                Settings.Particles = v
                if v then createParticles() else destroyParticles() end
            end
        })
        uiTab:Divider()

        -- Section: 窗口效果
        uiTab:Paragraph({Title="✨ 窗口效果"})
        Controls.AcrylicToggle = uiTab:Toggle({
            Flag = "AcrylicToggle", Title = "毛玻璃效果", Value = true,
            Callback = function(v) pcall(function() WindUI:ToggleAcrylic(v) end) end
        })
        Controls.TransparencyToggle = uiTab:Toggle({
            Flag = "TransparencyToggle", Title = "透明背景增强毛玻璃", Value = true,
            Callback = function(v) if WindowRef then pcall(function() WindowRef:ToggleTransparency(v) end) end end
        })
        uiTab:Divider()

        -- Section: 主题系统
        uiTab:Paragraph({Title="🎨 主题系统", Desc="16种内置主题，自由切换"})
        local allThemes = {}
        pcall(function() allThemes = WindUI:GetThemes() end)
        local themeNames = {}
        for name, _ in pairs(allThemes) do
            table.insert(themeNames, name)
        end
        table.sort(themeNames)

        Controls.ThemeDropdown = uiTab:Dropdown({
            Flag = "ThemeDropdown",
            Title = "选择主题",
            Values = themeNames,
            Value = "Dark",
            Callback = function(selected)
                if selected then
                    Settings.CurrentTheme = selected
                    pcall(function() WindUI:SetTheme(selected) end)
                end
            end
        })
        uiTab:Divider()
        uiTab:Paragraph({Title="💡 提示", Desc="粒子背景 + 毛玻璃 + 透明背景叠加效果最佳"})

        -- ===================== Tab 4: 信息统计 =====================
        local statsTab = win:Tab({Title="信息统计", Icon="solar:chart-bold"})

        -- 【自定义】统计信息
        -- TabElements.Stat1 = statsTab:Paragraph({Title="📊 统计1: 0"})
        -- TabElements.Stat2 = statsTab:Paragraph({Title="📊 统计2: 0"})
        -- statsTab:Divider()
        -- TabElements.Status = statsTab:Input({
        --     Title = "状态", Value = "等待中...", Locked = true
        -- })

        -- ===================== Tab 5: 配置管理 =====================
        local configTab = win:Tab({Title="配置管理", Icon="solar:diskette-bold"})
        configTab:Paragraph({Title="💾 配置管理", Desc="保存/加载你的所有设置"})

        local ConfigNameInput = configTab:Input({
            Flag = "ConfigNameInput", Title = "配置名称", Value = "default",
            Icon = "solar:file-text-bold",
            Callback = function(value) ConfigName = value end
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
            Title = "已有配置", Desc = "选择要加载的配置",
            Values = AllConfigs, Value = DefaultValue,
            Callback = function(value)
                if value then ConfigName = value; pcall(function() ConfigNameInput:Set(value) end) end
            end
        })
        configTab:Space()

        -- 保存按钮
        configTab:Button({
            Title = "💾 保存配置", Icon = "solar:check-circle-bold", Justify = "Center",
            Color = Color3.fromHex("#305dff"),
            Callback = function()
                if not ConfigManager then
                    pcall(function() WindUI:Notify({Title="错误", Content="配置系统不可用", Duration=3}) end)
                    return
                end
                pcall(function()
                    local config = ConfigManager:Config(ConfigName)
                    if config and config:Save() then
                        WindUI:Notify({Title="✅ 配置已保存", Content="配置 '" .. ConfigName .. "' 已保存", Icon="solar:check-circle-bold", Duration=3})
                        AllConfigsDropdown:Refresh(ConfigManager:AllConfigs())
                    end
                end)
            end
        })
        configTab:Space()

        -- 加载按钮
        configTab:Button({
            Title = "📂 加载配置", Icon = "solar:refresh-circle-bold", Justify = "Center",
            Color = Color3.fromHex("#10C550"),
            Callback = function()
                if not ConfigManager then
                    pcall(function() WindUI:Notify({Title="错误", Content="配置系统不可用", Duration=3}) end)
                    return
                end
                pcall(function()
                    local config = ConfigManager:CreateConfig(ConfigName, false)
                    if config and config:Load() then
                        WindUI:Notify({Title="✅ 配置已加载", Content="配置 '" .. ConfigName .. "' 已加载", Icon="solar:refresh-circle-bold", Duration=3})
                    end
                end)
            end
        })
        configTab:Space()

        -- 删除按钮
        configTab:Button({
            Title = "🗑️ 删除配置", Icon = "solar:trash-bin-trash-bold", Justify = "Center",
            Color = Color3.fromHex("#ff3040"),
            Callback = function()
                if not ConfigManager then return end
                pcall(function()
                    local config = ConfigManager:Config(ConfigName)
                    if config and config:Delete() then
                        WindUI:Notify({Title="🗑️ 配置已删除", Content="配置 '" .. ConfigName .. "' 已删除", Icon="solar:trash-bin-trash-bold", Duration=3})
                        AllConfigsDropdown:Refresh(ConfigManager:AllConfigs())
                    end
                end)
            end
        })
        configTab:Divider()
        configTab:Paragraph({Title="💡 提示", Desc="所有带 Flag 的元素会自动保存/恢复\n包括：Toggle、快捷键、滑块、Dropdown、Input 等"})

        -- 自动加载配置 + 启动粒子
        task.spawn(function()
            task.wait(1)
            pcall(function()
                if ConfigManager then
                    local config = ConfigManager:CreateConfig("default", true)
                end
            end)
            createParticles()
        end)

        -- ===================== Tab 6: 关于 =====================
        local aboutTab = win:Tab({Title="关于", Icon="solar:info-square-bold"})
        aboutTab:Paragraph({Title="【你的脚本名】v1.0", Desc="功能简述"})
        aboutTab:Divider()
        aboutTab:Paragraph({Title="👤 作者", Desc="b站英吉利超入_"})
        aboutTab:Divider()
        local usage = IsMobile and "手机: 点击悬浮按钮" or "PC: 按 RightShift 打开菜单"
        aboutTab:Paragraph({Title="💡 使用说明", Desc=usage})
        aboutTab:Paragraph({Title="⚠️ 提示", Desc="所有功能默认关闭，请在菜单中手动开启"})

        -- ===================== 手机悬浮按钮 =====================
        if IsMobile then
            task.spawn(function()
                task.wait(1)
                pcall(function()
                    FloatingButtonGui = Instance.new("ScreenGui")
                    FloatingButtonGui.Name = "Template_Btn"
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

                    -- 拖拽
                    local dragging, dragStart, startPos = false, nil, nil
                    btn.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = true
                            dragStart = input.Position
                            startPos = btn.Position
                        end
                    end)
                    btn.InputChanged:Connect(function(input)
                        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                            btn.Position = UDim2.new(
                                startPos.X.Scale, startPos.X.Offset + input.Position.X - dragStart.X,
                                startPos.Y.Scale, startPos.Y.Offset + input.Position.Y - dragStart.Y
                            )
                        end
                    end)
                    btn.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = false
                        end
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

    print("[模板] v1.0 已加载 | 作者: b站英吉利超入_")
else
    -- WindUI 加载失败
    print("[模板] WindUI 加载失败")
    local msg = Instance.new("Message")
    msg.Text = "⚠️ WindUI 加载失败，请重试"
    msg.Parent = Workspace
    task.delay(5, function() msg:Destroy() end)
end

print("[模板] 脚本加载完成")
