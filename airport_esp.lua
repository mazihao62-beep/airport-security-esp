--[[
    机场安全透视脚本 v12.5
    作者: b站英吉利超入_
    
    v12.5 核心修复: 全部NPC判为坏人的Bug彻底修复
    根因: classifyNPC中路径检查 pl:find("npc") 匹配所有路径含"npc"的角色
          所有NPC都在NPCWorkspace/NPCTemplate下，全部命中→全部Bad
    修复: 移除"npc"路径关键词，加强名字/属性/颜色匹配
]]

-- ========== 服务 ==========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if not IsMobile then pcall(function() IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled end) end

-- ========== 启动时立即清理所有残留 ==========
local TAG_NAME = "AirportESP"

local function immediateCleanup()
    local count = 0
    pcall(function()
        for _, inst in ipairs(CoreGui:GetDescendants()) do
            local s, attr = pcall(function() return inst:GetAttribute(TAG_NAME) end)
            if s and attr then pcall(function() inst:Destroy() end); count = count + 1 end
        end
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name
                if n:find("AirportESP") or n:find("Template_") or n:find("Particle") then
                    pcall(function() gui:Destroy() end); count = count + 1
                end
            end
        end
        -- 清理旧WindUI实例
        local wc = 0
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name:find("WindUI") then
                wc = wc + 1; if wc > 1 then pcall(function() gui:Destroy() end); count = count + 1 end
            end
        end
    end)
    if count > 0 then print("[清理] 启动时已清除 " .. count .. " 个残留实例") end
end
immediateCleanup()

game:BindToClose(function()
    pcall(function()
        for _, inst in ipairs(CoreGui:GetDescendants()) do
            local s, attr = pcall(function() return inst:GetAttribute(TAG_NAME) end)
            if s and attr then pcall(function() inst:Destroy() end) end
        end
    end)
end)

_G.CleanupAirportESP = function()
    immediateCleanup()
    print("[清理] 手动清理完成")
end

local function tagTrack(instance)
    if not instance then return nil end
    pcall(function() instance:SetAttribute(TAG_NAME, true) end)
    return instance
end

-- ========== 配置 ==========
local Settings = {
    Enabled = false, BadOnly = false, ShowDistance = false, ShowHealth = false,
    MaxRange = 500, Particles = true, CurrentTheme = "Dark",
    ParticleColor = Color3.fromRGB(80, 170, 255),
}

-- ========== 主题色方案 ==========
local ThemeColors = {
    dark = Color3.fromRGB(80, 170, 255), light = Color3.fromRGB(60, 130, 210),
    rose = Color3.fromRGB(255, 130, 170), plant = Color3.fromRGB(70, 210, 130),
    ocean = Color3.fromRGB(60, 190, 240), sunset = Color3.fromRGB(255, 160, 70),
    midnight = Color3.fromRGB(130, 100, 240), forest = Color3.fromRGB(60, 180, 90),
    lavender = Color3.fromRGB(190, 140, 255), coral = Color3.fromRGB(255, 140, 90),
    mint = Color3.fromRGB(80, 230, 190), peanut = Color3.fromRGB(210, 180, 90),
    sky = Color3.fromRGB(100, 190, 255), blood = Color3.fromRGB(230, 90, 80),
    lemon = Color3.fromRGB(230, 210, 70), cyber = Color3.fromRGB(0, 235, 210),
}

local function nameToColor(n) local h=0;for i=1,#n do h=h+string.byte(n,i)end;local s=math.sin(h*137.5)*0.5+0.5;local s2=math.sin(h*73.1+50)*0.5+0.5;return Color3.fromRGB(math.floor(80+s*175),math.floor(100+s2*155),math.floor(130+math.sin(h*41.7)*0.5*125)) end

local function getThemePrimaryColor(name)
    if not name then return Color3.fromRGB(80,170,255) end;local l=name:lower()
    local themes=nil;pcall(function()themes=WindUI:GetThemes()end)
    if themes and themes[name] then local d=themes[name];local c=nil;pcall(function()if type(d)=="table" then c=d.Primary or d.Accent or d.Color or d.Main end end);if c then return c end end
    local m=ThemeColors[l];if m then return m end
    if l:find("dark")or l:find("night")then return Color3.fromRGB(80,170,255)end;if l:find("light")then return Color3.fromRGB(60,130,210)end;if l:find("rose")or l:find("pink")then return Color3.fromRGB(255,130,170)end;if l:find("plant")or l:find("green")or l:find("forest")or l:find("mint")then return Color3.fromRGB(70,210,130)end;if l:find("ocean")or l:find("blue")or l:find("sky")then return Color3.fromRGB(60,190,240)end;if l:find("sunset")or l:find("orange")or l:find("coral")then return Color3.fromRGB(255,160,70)end;if l:find("midnight")or l:find("purple")or l:find("lavender")then return Color3.fromRGB(130,100,240)end;if l:find("blood")or l:find("red")then return Color3.fromRGB(230,90,80)end;if l:find("lemon")or l:find("yellow")then return Color3.fromRGB(230,210,70)end
    return nameToColor(name)
end

-- ========== 内部变量 ==========
local ESPObjects={};local TrackedNPCs={};local IsScanning=false
local WindowRef=nil;local FloatingButtonGui=nil;local ParticleContainer=nil
local Stats={Good=0,Bad=0,Total=0,Unknown=0};local Controls={};local Keybinds={}
local PopupConfirmed=false;local TabElements={};local ConfigName="default"
local DebugLog={};local ParticleRunning=false;local Particles={}
local WindowMainFrame=nil;local ParticleHeartbeat=nil

local function mobileToggleWindow()
    if not WindowRef then return end;pcall(function()VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.RightShift,false,game);task.wait(0.05);VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.RightShift,false,game)end)
end

local function debugPrint(msg) table.insert(DebugLog,msg);if #DebugLog>100 then table.remove(DebugLog,1)end;print("[ESP调试]"..msg)end

-- ========== 粒子系统 ==========
local function findWindowMainFrame()
    WindowMainFrame = nil
    pcall(function()
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, f in ipairs(gui:GetChildren()) do
                    if f:IsA("Frame") and f:FindFirstChild("UICorner") then
                        local uc = f:FindFirstChild("UICorner")
                        if uc and uc.CornerRadius == UDim.new(0, 8) and f.AbsoluteSize.X > 700 then
                            WindowMainFrame = f; return
                        end
                    end
                end
            end
        end
    end)
    if not WindowMainFrame then
        pcall(function()
            for _, gui in ipairs(CoreGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name:find("WindUI") then
                    local bs = 0; local bf = nil
                    for _, f in ipairs(gui:GetChildren()) do
                        if f:IsA("Frame") and f.AbsoluteSize.X > bs then bs = f.AbsoluteSize.X; bf = f end
                    end
                    if bf then WindowMainFrame = bf; return end
                end
            end
        end)
    end
    return WindowMainFrame
end

local function getParticleColor() return Settings.ParticleColor or Color3.fromRGB(80,170,255) end

local function createParticles()
    if ParticleContainer then pcall(function()ParticleContainer:Destroy()end);ParticleContainer=nil end
    Particles={};ParticleRunning=false
    if ParticleHeartbeat then pcall(function()ParticleHeartbeat:Disconnect()end);ParticleHeartbeat=nil end
    if not Settings.Particles then return end
    findWindowMainFrame()
    if not WindowMainFrame then
        task.spawn(function()task.wait(1);findWindowMainFrame();if WindowMainFrame then createParticles()end end)
        return
    end
    pcall(function()
        local psg = Instance.new("ScreenGui"); psg.Name = "AirportESP_ParticleContainer"
        psg.DisplayOrder = -9999; psg.ResetOnSpawn = false; psg.Parent = CoreGui; tagTrack(psg)
        ParticleContainer = Instance.new("Frame")
        ParticleContainer.BackgroundTransparency = 1; ParticleContainer.BorderSizePixel = 0
        ParticleContainer.ClipsDescendants = true; ParticleContainer.Parent = psg; tagTrack(ParticleContainer)
        local pos = WindowMainFrame.AbsolutePosition; local size = WindowMainFrame.AbsoluteSize
        ParticleContainer.Position = UDim2.fromOffset(pos.X, pos.Y)
        ParticleContainer.Size = UDim2.fromOffset(size.X, size.Y)
        ParticleHeartbeat = RunService.Heartbeat:Connect(function()
            if not ParticleContainer or not ParticleContainer.Parent then
                if ParticleHeartbeat then ParticleHeartbeat:Disconnect();ParticleHeartbeat=nil end;return
            end
            if WindowMainFrame and WindowMainFrame.Parent then
                local ap = WindowMainFrame.AbsolutePosition; local as = WindowMainFrame.AbsoluteSize
                ParticleContainer.Position = UDim2.fromOffset(ap.X, ap.Y)
                ParticleContainer.Size = UDim2.fromOffset(as.X, as.Y)
                ParticleContainer.Visible = WindowMainFrame.Visible
            else ParticleContainer.Visible = false; findWindowMainFrame() end
        end)
        local pc = getParticleColor(); local w = size.X; local h = size.Y
        for i = 1, 50 do
            local dot = Instance.new("Frame"); local sz = math.random(4, 8)
            dot.Size = UDim2.new(0, sz, 0, sz)
            dot.Position = UDim2.fromOffset(math.random(10, math.max(20, w-10)), math.random(10, math.max(20, h-10)))
            dot.BackgroundColor3 = pc; dot.BackgroundTransparency = 0.4 + math.random() * 0.4
            dot.BorderSizePixel = 0; dot.ZIndex = 0; dot.Parent = ParticleContainer; tagTrack(dot)
            local cn = Instance.new("UICorner"); cn.CornerRadius = UDim.new(0, 10); cn.Parent = dot
            local ang = math.random() * 6.28; local sp = 0.1 + math.random() * 0.3
            table.insert(Particles, {Frame=dot,Vx=math.cos(ang)*sp,Vy=math.sin(ang)*sp,Phase=math.random()*6.28,SizeBase=sz})
        end
        ParticleRunning = true
        task.spawn(function()
            local t = 0
            while ParticleRunning and ParticleContainer and ParticleContainer.Parent do
                t = t + 0.03
                pcall(function()
                    local cw = ParticleContainer.AbsoluteSize.X; local ch = ParticleContainer.AbsoluteSize.Y
                    if cw <= 0 or ch <= 0 then task.wait(0.03); return end
                    for _, p in ipairs(Particles) do
                        if not p.Frame or not p.Frame.Parent then continue end
                        local x = p.Frame.Position.X.Offset + p.Vx; local y = p.Frame.Position.Y.Offset + p.Vy
                        local sz = p.Frame.AbsoluteSize.X
                        if x + sz >= cw then x = cw - sz; p.Vx = -p.Vx * 0.95 elseif x < 0 then x = 0; p.Vx = -p.Vx * 0.95 end
                        if y + sz >= ch then y = ch - sz; p.Vy = -p.Vy * 0.95 elseif y < 0 then y = 0; p.Vy = -p.Vy * 0.95 end
                        p.Frame.Position = UDim2.fromOffset(x, y)
                        p.Frame.BackgroundTransparency = 0.4 + math.sin(t * 0.8 + p.Phase) * 0.25
                        local bs = math.max(1, p.SizeBase + math.sin(t + p.Phase) * 0.8)
                        p.Frame.Size = UDim2.new(0, bs, 0, bs)
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

local function destroyParticles()
    ParticleRunning = false
    if ParticleHeartbeat then pcall(function()ParticleHeartbeat:Disconnect()end);ParticleHeartbeat=nil end
    if ParticleContainer then
        pcall(function() local pa = ParticleContainer.Parent; if pa then pcall(function()pa:Destroy()end) end end)
        ParticleContainer = nil
    end
    Particles = {}
end

-- ========== NPC 分类器（v12.5完全重写）==========
-- 核心修复：不再使用 "npc" 作为路径坏人关键词（太宽泛，匹配所有NPC）
-- 优先级：属性→名字→颜色→父级→工具→路径→Humanoid状态→跳过

local function getAllAttributes(obj)
    local attrs = {}; if not obj then return attrs end
    pcall(function() for _, a in ipairs(obj:GetAttributes()) do attrs[a] = obj:GetAttribute(a) end end)
    return attrs
end

local function findAttrIn(obj, names, goods, bads)
    if not obj then return nil end
    for _, an in ipairs(names) do
        local val = nil; pcall(function() val = obj:GetAttribute(an) end)
        if val ~= nil then
            local vs = tostring(val):lower()
            for _, gv in ipairs(goods) do if vs:find(gv, 1, true) then return "Good" end end
            for _, bv in ipairs(bads) do if vs:find(bv, 1, true) then return "Bad" end end
        end
    end
    return nil
end

local function matchName(str, keywords)
    local sl = str:lower()
    for _, kw in ipairs(keywords) do
        if sl:find(kw:lower(), 1, true) then return true end
    end
    return false
end

local ATTRS = {"NPCType","Type","Team","Faction","Role","Class","Group","Kind","Identity","TeamColor","Affiliation","Alignment","Side","GroupID"}
local GOOD_ATTR = {"agent","good","friendly","ally","police","friend","blue","guard","clean","white","law","justice","protector","security","safe","civilian","team"}
local BAD_ATTR = {"enemy","bad","hostile","terrorist","criminal","foe","enem","red","danger","evil","dark","suspect","agitator","invader","rogue","intruder","threat"}

local GOOD_NAME = {"警察","保安","警卫","警","守卫","士兵","军官","长官","巡逻","特工","安全","安保","护卫","卫兵","军队","公安","辅警","武警","官兵","police","security","guard","agent","officer","sheriff","soldier","patrol","cop","marshal","blue","friendly","ally","good","duty","protector","guardian","guar","civil","defender","safety","peace","uniform","spawn","neutral"}
local BAD_NAME = {"恐怖","匪徒","匪","敌人","坏","犯罪","袭击","暴徒","杀手","叛军","武装","劫匪","入侵","歹徒","黑帮","毒贩","绑匪","terrorist","enemy","hostile","criminal","threat","suspect","bandit","mercenary","attacker","red","danger","bad","invader","rogue","intruder","hijack","hacker","sniper","aggressor","assailant","fugitive","outlaw"}

local GOOD_PARENT = {"警察","保安","police","guard","agent","friendly","good","blue","spawn","safe","team"}
local BAD_PARENT = {"恐怖","匪","敌人","terror","enemy","hostile","criminal","danger","unsafe","attack"}

local GOOD_TOOL = {"arrest","taser","bat","radio","handcuff","警","盾","枪","stun","shield","badge","arrestgun"}
local BAD_TOOL = {"knife","bomb","grenade","rpg","explosive","刀","炸","gun","pistol","rifle","shotgun","sniper","axe","sword","melee","machete"}

local function classifyNPC(character, humanoid)
    local name = character.Name or ""
    local path = ""; pcall(function() path = character:GetFullName() end)
    local tool = character:FindFirstChildOfClass("Tool")
    
    debugPrint(string.format("检测到: %s | 路径: %s", name, path))
    
    -- 打印所有属性
    if humanoid then for k, v in pairs(getAllAttributes(humanoid)) do debugPrint(string.format("  Humanoid属性: %s=%s", k, tostring(v))) end end
    for k, v in pairs(getAllAttributes(character)) do debugPrint(string.format("  Character属性: %s=%s", k, tostring(v))) end
    
    -- 第1层: 属性检查（最高优先级）
    local ar = findAttrIn(humanoid, ATTRS, GOOD_ATTR, BAD_ATTR)
    if ar then debugPrint("  →属性判定: " .. (ar == "Good" and "好人" or "坏人")); return ar end
    ar = findAttrIn(character, ATTRS, GOOD_ATTR, BAD_ATTR)
    if ar then debugPrint("  →属性判定: " .. (ar == "Good" and "好人" or "坏人")); return ar end
    
    -- 第2层: 名字检查
    debugPrint(string.format("  名字: %s", name))
    if matchName(name, GOOD_NAME) then debugPrint("  →名字匹配好人"); return "Good" end
    if matchName(name, BAD_NAME) then debugPrint("  →名字匹配坏人"); return "Bad" end
    
    -- 第3层: 颜色检查
    local pc = {}; for _, p in ipairs(character:GetChildren()) do if p:IsA("BasePart") then local cn = p.BrickColor.Name; pc[cn] = (pc[cn] or 0) + 1 end end
    local gc = 0; local bc = 0
    for c, n in pairs(pc) do
        local cl = c:lower()
        if cl:find("blue") or cl:find("green") or cl:find("white") or cl:find("grey") or cl:find("gray") or cl:find("silver") then gc = gc + n end
        if cl:find("red") or cl:find("black") or cl:find("brown") or cl:find("dark") or cl:find("maroon") then bc = bc + n end
    end
    if gc > bc and gc >= 3 then debugPrint(string.format("  →颜色好人(%d>%d)", gc, bc)); return "Good" end
    if bc > gc and bc >= 3 then debugPrint(string.format("  →颜色坏人(%d>%d)", bc, gc)); return "Bad" end
    
    -- 第4层: 父级名字
    if character.Parent then
        local pn = character.Parent.Name
        if matchName(pn, GOOD_PARENT) then debugPrint("  →父级好人"); return "Good" end
        if matchName(pn, BAD_PARENT) then debugPrint("  →父级坏人"); return "Bad" end
    end
    
    -- 第5层: 工具检查
    if tool then
        local tn = tool.Name
        if matchName(tn, GOOD_TOOL) then debugPrint("  →工具好人"); return "Good" end
        if matchName(tn, BAD_TOOL) then debugPrint("  →工具坏人"); return "Bad" end
    end
    
    -- 第6层: 路径检查（v12.5关键修复：移除"npc"关键词！）
    local pl = path:lower()
    if pl:find("agent") or pl:find("police") or pl:find("friendly") or pl:find("friendly") or pl:find("good") or pl:find("blue") or pl:find("spawn") or pl:find("defender") or pl:find("guardian") or pl:find("civilian") then
        debugPrint("  →路径好人"); return "Good"
    end
    -- 注意："npc"被刻意排除！它太宽泛，会匹配所有路径含NPC的角色
    if pl:find("enemy") or pl:find("terror") or pl:find("hostile") or pl:find("criminal") or pl:find("danger") or pl:find("invader") or pl:find("attack") or pl:find("suspect") then
        debugPrint("  →路径坏人"); return "Bad"
    end
    
    -- 第7层: Humanoid状态检查
    if humanoid then
        local h = humanoid.Health; local mh = humanoid.MaxHealth
        if mh > 0 then
            local ratio = h / mh
            if ratio >= 0.95 then debugPrint("  →满血(可能是好人)"); return "Good" end
            if ratio <= 0.5 then debugPrint("  →低血(可能是坏人)"); return "Bad" end
        end
    end
    
    -- 无法判断：跳过
    Stats.Unknown = Stats.Unknown + 1
    debugPrint("  →无法判断，跳过")
    return nil
end

-- ========== ESP创建/管理 ==========
local function isRealPlayer(c)
    if not c or not c:IsA("Model") then return false end
    for _, p in ipairs(Players:GetPlayers()) do if p.Character == c then return true end end
    return false
end

local function createESP(c, nt)
    if not c or not c.Parent then return false end
    if isRealPlayer(c) then return false end
    if ESPObjects[c] then
        local col = nt == "Good" and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
        local o = ESPObjects[c]; local s = Settings.Enabled and (not Settings.BadOnly or nt == "Bad")
        if o.Highlight then o.Highlight.FillColor = col; o.Highlight.Enabled = s end
        if o.Billboard then o.Billboard.Enabled = s end
        return true
    end
    local root = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChildOfClass("Part")
    if not root then return false end
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if myRoot and root and (root.Position - myRoot.Position).Magnitude > Settings.MaxRange then return false end
    local s = Settings.Enabled and (not Settings.BadOnly or nt == "Bad")
    local col = nt == "Good" and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
    local hl = tagTrack(Instance.new("Highlight"))
    hl.Adornee = c; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.4; hl.OutlineTransparency = 0.2
    hl.FillColor = col; hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.Enabled = s; hl.Parent = CoreGui
    local head = c:FindFirstChild("Head") or c:FindFirstChild("Torso") or root
    local bb = tagTrack(Instance.new("BillboardGui"))
    bb.Adornee = head; bb.Size = UDim2.new(0, 160, 0, 50); bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true; bb.Enabled = s; bb.Parent = CoreGui
    local bg = tagTrack(Instance.new("Frame"))
    bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.4; bg.BorderSizePixel = 0; bg.Parent = bb
    tagTrack(Instance.new("UICorner")); bg.UICorner.CornerRadius = UDim.new(0, 4)
    local lbl = tagTrack(Instance.new("TextLabel"))
    lbl.Size = UDim2.new(1, -4, 0.55, 0); lbl.Position = UDim2.new(0, 2, 0, 2)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = col; lbl.TextScaled = true
    lbl.Font = Enum.Font.SourceSansBold
    lbl.Text = nt == "Good" and "👮 好人" or "💀 坏人"
    lbl.BorderSizePixel = 0; lbl.Parent = bg
    local info = tagTrack(Instance.new("TextLabel"))
    info.Size = UDim2.new(1, -4, 0.4, 0); info.Position = UDim2.new(0, 2, 0.55, 2)
    info.BackgroundTransparency = 1; info.TextColor3 = Color3.fromRGB(255, 255, 255)
    info.TextScaled = true; info.Font = Enum.Font.SourceSans; info.Text = ""; info.BorderSizePixel = 0; info.Parent = bg
    ESPObjects[c] = {Highlight = hl, Billboard = bb, Label = lbl, InfoLine = info, Head = head, Root = root}
    if nt == "Good" then Stats.Good = Stats.Good + 1 else Stats.Bad = Stats.Bad + 1 end
    Stats.Total = Stats.Total + 1; TrackedNPCs[c] = nt
    return true
end

local function removeESP(ch)
    if ESPObjects[ch] then
        local o = ESPObjects[ch]
        pcall(function() o.Highlight:Destroy() end); pcall(function() o.Billboard:Destroy() end)
        ESPObjects[ch] = nil
        local nt = TrackedNPCs[ch]
        if nt == "Good" then Stats.Good = math.max(0, Stats.Good - 1)
        elseif nt == "Bad" then Stats.Bad = math.max(0, Stats.Bad - 1) end
        Stats.Total = math.max(0, Stats.Total - 1); TrackedNPCs[ch] = nil
    end
end

local function cleanESP()
    for ch, _ in pairs(ESPObjects) do if not ch or not ch.Parent then removeESP(ch) end end
end

local function updateLabels()
    local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    for ch, o in pairs(ESPObjects) do
        if o.Billboard and o.Billboard.Enabled and o.InfoLine then
            local pts = {}
            if Settings.ShowDistance and myRoot and o.Root then
                table.insert(pts, math.floor((o.Root.Position - myRoot.Position).Magnitude + 0.5) .. "m")
            end
            if Settings.ShowHealth then
                local h = ch:FindFirstChildOfClass("Humanoid")
                if h then table.insert(pts, "HP:" .. math.floor(h.Health + 0.5) .. "/" .. math.floor(h.MaxHealth + 0.5)) end
            end
            o.InfoLine.Text = table.concat(pts, " | ")
        end
    end
end

local function updateAllESP()
    for ch, o in pairs(ESPObjects) do
        local nt = TrackedNPCs[ch]; local s = Settings.Enabled and (not Settings.BadOnly or nt == "Bad")
        if o.Highlight then o.Highlight.Enabled = s end
        if o.Billboard then o.Billboard.Enabled = s end
    end
end

-- ========== 扫描系统 ==========
local function scanNPCs()
    if IsScanning then return end
    IsScanning = true; debugPrint("=====开始扫描=====")
    pcall(function()
        local found = 0
        for _, o in ipairs(Workspace:GetDescendants()) do
            local h, c = nil, nil
            if o:IsA("Humanoid") then h = o; c = o.Parent end
            if c and h and not TrackedNPCs[c] and not isRealPlayer(c) then
                if c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") then
                    found = found + 1
                    debugPrint(string.format("发现NPC(%d): %s", found, c.Name))
                    local nt = classifyNPC(c, h)
                    if nt then createESP(c, nt) end
                end
            end
            task.wait()
        end
    end)
    debugPrint(string.format("=====扫描结束: 好人%d 坏人%d 未知%d=====", Stats.Good, Stats.Bad, Stats.Unknown))
    IsScanning = false
end

-- ========== UI美化 ==========
local function beautifyUI()
    pcall(function()
        for _, s in ipairs(CoreGui:GetDescendants()) do
            if s:IsA("ScrollingFrame") then s.ScrollBarThickness = 14; s.ScrollBarImageColor3 = Color3.fromRGB(220, 220, 220); s.ScrollBarImageTransparency = 0.1 end
        end
    end)
end

task.spawn(function() while true do task.wait(3); beautifyUI() end end)

-- ========== 更新统计UI ==========
local function updateStatsUI()
    pcall(function()
        if TabElements.GoodP then TabElements.GoodP:SetTitle("🟢 好人: " .. Stats.Good) end
        if TabElements.BadP then TabElements.BadP:SetTitle("🔴 坏人: " .. Stats.Bad) end
        if TabElements.TotalP then TabElements.TotalP:SetTitle("📊 总计: " .. Stats.Total) end
        if TabElements.UnknownP then TabElements.UnknownP:SetTitle("❓ 跳过: " .. Stats.Unknown) end
        if TabElements.ScanI then TabElements.ScanI:Set(IsScanning and "📡 扫描中..." or "✅ 就绪") end
        if TabElements.DebugI then
            local lines = {}
            for i = math.max(1, #DebugLog - 4), #DebugLog do table.insert(lines, DebugLog[i]) end
            TabElements.DebugI:Set(table.concat(lines, "\n"))
        end
    end)
end

-- ========== 加载 WindUI ==========
local WindUI = nil; local s, r = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if s and r then
    WindUI = r; pcall(function() WindUI:SetTheme("Dark") end)
    Settings.ParticleColor = getThemePrimaryColor("Dark")
    
    WindUI:Popup({
        Title = "机场安全透视 v12.5",
        Icon = "solar:info-square-bold",
        Content = "👁 透视高亮 - Highlight穿墙显示所有NPC\n🔍 智能识别 - 全面检查属性/名字/颜色/工具\n🏷 头顶标签 - 显示类型/距离/血量\n🔧 自定义快捷键 - 自由绑定按键\n💾 配置保存 - 自动保存/读取设置\n🎨 主题系统 - 粒子颜色动态适配\n✨ 粒子背景 - 窗口内Clips裁剪+追踪窗口位置\n🧹 即时清理 - 启动时+关闭时自动清除所有残留\n\n⚠️ 加载后所有功能默认关闭，需手动开启",
        Buttons = {
            {Title = "取消", Callback = function() end, Variant = "Tertiary"},
            {Title = "确认加载", Icon = "solar:arrow-right-bold", Callback = function()
                PopupConfirmed = true
                pcall(function() WindUI:Notify({Title = "✅ 已加载", Content = "⌨️ 按 RightShift 打开菜单\n调试日志在【信息统计】Tab查看", Duration = 5, Icon = "solar:bell-bold"}) end)
                task.spawn(function() createWindow(); task.wait(1); scanNPCs() end)
            end, Variant = "Primary"}
        }
    })
    
    task.spawn(function()
        while not PopupConfirmed do task.wait(0.5) end
        task.wait(0.5); beautifyUI()
        -- 定时扫描
        task.spawn(function()
            while true do
                pcall(function() cleanESP(); if Settings.Enabled then scanNPCs() end end)
                task.wait(5)
            end
        end)
        -- 定时更新UI
        task.spawn(function()
            while true do pcall(function() updateStatsUI(); updateLabels() end); task.wait(0.5) end
        end)
        -- 快捷键
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local kn = input.KeyCode.Name
            if Keybinds.ESP and Keybinds.ESP ~= "" and kn == Keybinds.ESP then
                Settings.Enabled = not Settings.Enabled
                pcall(function() if Controls.ESPToggle then Controls.ESPToggle:Set(Settings.Enabled) end end)
                updateAllESP()
                if Settings.Enabled then task.spawn(scanNPCs) end
            end
            if Keybinds.BadOnly and Keybinds.BadOnly ~= "" and kn == Keybinds.BadOnly then
                Settings.BadOnly = not Settings.BadOnly
                pcall(function() if Controls.BadOnlyToggle then Controls.BadOnlyToggle:Set(Settings.BadOnly) end end)
                updateAllESP()
            end
        end)
    end)
    
    function createWindow()
        if WindowRef then return end
        local ok, win = pcall(function()
            return WindUI:CreateWindow({Title = "机场安全透视", Author = "b站英吉利超入_", Icon = "solar:shield-warning-bold", Size = UDim2.fromOffset(750, 520), ToggleKey = Enum.KeyCode.RightShift, Folder = "airport-esp", Acrylic = true, Transparent = true, Resizable = false, SideBarWidth = 180, ScrollBarEnabled = true, HideSearchBar = true})
        end)
        if not ok or not win then print("[机场安全透视] 窗口创建失败:", ok); return end
        WindowRef = win
        pcall(function() WindUI.TransparencyValue = 0.22 end)
        
        -- 窗口可见性轮询
        task.spawn(function()
            local wasVisible = nil
            while WindowRef do
                task.wait(0.5)
                pcall(function()
                    local ok2, v = pcall(function() return WindowRef.Visible end)
                    if ok2 then
                        if wasVisible == nil then wasVisible = v end
                        if wasVisible ~= v then
                            if v then if Settings.Particles then createParticles() end
                            else destroyParticles() end
                            wasVisible = v
                        end
                    end
                end)
            end
        end)
        
        local mt = win:Tab({Title = "主控面板", Icon = "solar:slider-vertical-bold"})
        mt:Paragraph({Title = "👁 透视控制"})
        Controls.ESPToggle = mt:Toggle({Flag = "ESPToggle", Title = "透视开关", Value = false, Callback = function(v) Settings.Enabled = v; updateAllESP(); if v then task.spawn(scanNPCs) end end})
        Controls.BadOnlyToggle = mt:Toggle({Flag = "BadOnlyToggle", Title = "仅显示坏人", Value = false, Callback = function(v) Settings.BadOnly = v; updateAllESP() end})
        mt:Divider()
        mt:Paragraph({Title = "📐 显示设置"})
        Controls.DistanceToggle = mt:Toggle({Flag = "DistanceToggle", Title = "显示距离", Value = false, Callback = function(v) Settings.ShowDistance = v end})
        Controls.HealthToggle = mt:Toggle({Flag = "HealthToggle", Title = "显示血量", Value = false, Callback = function(v) Settings.ShowHealth = v end})
        mt:Divider()
        Controls.RangeSlider = mt:Slider({Flag = "RangeSlider", Title = "最大探测距离", Step = 50, Value = {Min = 50, Max = 1000, Default = 500}, Width = 200, IsTextbox = true, Callback = function(v) Settings.MaxRange = v end})
        
        local ft = win:Tab({Title = "功能设置", Icon = "solar:settings-bold"})
        ft:Paragraph({Title = "🔑 快捷键设置"})
        Controls.ESPKeybind = ft:Keybind({Flag = "ESPKeybind", Title = "透视开关快捷键", Value = "", Callback = function(k) Keybinds.ESP = k end})
        Controls.BadOnlyKeybind = ft:Keybind({Flag = "BadOnlyKeybind", Title = "仅坏人模式快捷键", Value = "", Callback = function(k) Keybinds.BadOnly = k end})
        ft:Divider()
        ft:Paragraph({Title = "💡 提示", Desc = "窗口快捷键在UI设置中绑定（默认 RightShift）"})
        
        local ut = win:Tab({Title = "UI设置", Icon = "solar:monitor-bold"})
        ut:Paragraph({Title = "⚙️ 界面设置"})
        Controls.WindowKeybind = ut:Keybind({Flag = "WindowKeybind", Title = "窗口开关快捷键", Value = "RightShift", Callback = function(k) Keybinds.Window = k; if WindowRef then pcall(function() WindowRef:SetToggleKey(Enum.KeyCode[k]) end) end end})
        Controls.FloatingBtnToggle = ut:Toggle({Flag = "FloatingBtnToggle", Title = "显示悬浮按钮", Value = IsMobile, Callback = function(v) if FloatingButtonGui then FloatingButtonGui.Enabled = v end end})
        ut:Divider()
        ut:Paragraph({Title = "🌀 背景效果"})
        Controls.ParticlesToggle = ut:Toggle({Flag = "ParticlesToggle", Title = "浮动粒子背景(50个)", Value = true, Callback = function(v) Settings.Particles = v; if v then createParticles() else destroyParticles() end end})
        ut:Divider()
        ut:Paragraph({Title = "✨ 窗口效果"})
        Controls.AcrylicToggle = ut:Toggle({Flag = "AcrylicToggle", Title = "毛玻璃效果", Value = true, Callback = function(v) pcall(function() WindUI:ToggleAcrylic(v) end) end})
        Controls.TransparencyToggle = ut:Toggle({Flag = "TransparencyToggle", Title = "透明背景", Value = true, Callback = function(v) if v then pcall(function() WindUI.TransparencyValue = 0.22 end) else pcall(function() WindUI.TransparencyValue = 0 end) end end})
        ut:Divider()
        ut:Paragraph({Title = "🎨 主题系统", Desc = "切换主题时粒子颜色自动适配"})
        local allThemes = {}; pcall(function() allThemes = WindUI:GetThemes() end)
        local themeNames = {}; for n, _ in pairs(allThemes) do table.insert(themeNames, n) end; table.sort(themeNames)
        Controls.ThemeDropdown = ut:Dropdown({Flag = "ThemeDropdown", Title = "选择主题", Values = themeNames, Value = "Dark", Callback = function(selected) if selected then Settings.CurrentTheme = selected; pcall(function() WindUI:SetTheme(selected) end); Settings.ParticleColor = getThemePrimaryColor(selected); updateParticleColor() end end})
        ut:Divider()
        ut:Paragraph({Title = "💡 提示", Desc = "粒子在窗口区域内浮动(Clips裁剪)"})
        
        local st = win:Tab({Title = "信息统计", Icon = "solar:chart-bold"})
        TabElements.GoodP = st:Paragraph({Title = "🟢 好人: 0"})
        TabElements.BadP = st:Paragraph({Title = "🔴 坏人: 0"})
        TabElements.TotalP = st:Paragraph({Title = "📊 总计: 0"})
        TabElements.UnknownP = st:Paragraph({Title = "❓ 跳过: 0"})
        st:Divider()
        TabElements.ScanI = st:Input({Title = "扫描状态", Value = "等待中...", Locked = true})
        st:Divider()
        TabElements.DebugI = st:Input({Title = "📋 调试日志", Value = "等待检测...", Locked = true, Desc = "每次扫描显示NPC属性信息"})
        
        local ct = win:Tab({Title = "配置管理", Icon = "solar:diskette-bold"})
        ct:Paragraph({Title = "💾 配置管理", Desc = "保存/加载你的所有设置"})
        local cni = ct:Input({Flag = "ConfigNameInput", Title = "配置名称", Value = "default", Icon = "solar:file-text-bold", Callback = function(v) ConfigName = v end})
        ct:Space()
        local CM = WindowRef.ConfigManager
        local AC = {}; pcall(function() AC = CM:AllConfigs() end)
        local DV = nil; pcall(function() for _, v in ipairs(AC) do if v == "default" then DV = "default"; break end end end)
        local ACD = ct:Dropdown({Title = "已有配置", Desc = "选择要加载的配置", Values = AC, Value = DV, Callback = function(v) if v then ConfigName = v; pcall(function() cni:Set(v) end) end end})
        ct:Space()
        ct:Button({Title = "💾 保存配置", Icon = "solar:check-circle-bold", Justify = "Center", Color = Color3.fromHex("#305dff"), Callback = function() if not CM then return end; pcall(function() local c = CM:Config(ConfigName); if c and c:Save() then WindUI:Notify({Title = "✅ 配置已保存", Content = "配置 '" .. ConfigName .. "' 已保存", Icon = "solar:check-circle-bold", Duration = 3}); ACD:Refresh(CM:AllConfigs()) end end) end})
        ct:Space()
        ct:Button({Title = "📂 加载配置", Icon = "solar:refresh-circle-bold", Justify = "Center", Color = Color3.fromHex("#10C550"), Callback = function() if not CM then return end; pcall(function() local c = CM:CreateConfig(ConfigName, false); if c and c:Load() then WindUI:Notify({Title = "✅ 配置已加载", Content = "配置 '" .. ConfigName .. "' 已加载", Icon = "solar:refresh-circle-bold", Duration = 3}) end end) end})
        ct:Space()
        ct:Button({Title = "🗑️ 删除配置", Icon = "solar:trash-bin-trash-bold", Justify = "Center", Color = Color3.fromHex("#ff3040"), Callback = function() if not CM then return end; pcall(function() local c = CM:Config(ConfigName); if c and c:Delete() then WindUI:Notify({Title = "🗑️ 配置已删除", Content = "配置 '" .. ConfigName .. "' 已删除", Icon = "solar:trash-bin-trash-bold", Duration = 3}); ACD:Refresh(CM:AllConfigs()) end end) end})
        ct:Divider()
        ct:Paragraph({Title = "💡 提示", Desc = "所有带 Flag 的元素自动保存/恢复\n手动清理: _G.CleanupAirportESP()"})
        
        task.spawn(function() task.wait(1); pcall(function() if CM then local c = CM:CreateConfig("default", true) end end); createParticles() end)
        
        local at = win:Tab({Title = "关于", Icon = "solar:info-square-bold"})
        at:Paragraph({Title = "机场安全透视 v12.5", Desc = "NPC分类器完全重写 - 修复全部坏人Bug"})
        at:Divider()
        at:Paragraph({Title = "👤 作者", Desc = "b站英吉利超入_"})
        at:Divider()
        at:Paragraph({Title = "💡 使用说明", Desc = IsMobile and "手机: 点击悬浮按钮" or "PC: 按 RightShift 打开菜单"})
        at:Paragraph({Title = "⚠️ 提示", Desc = "所有功能默认关闭，请在菜单中手动开启\n打开透视后查看【信息统计】Tab了解NPC分布"})
        at:Paragraph({Title = "🧹 清理", Desc = "脚本启动时自动清理上次残留\n执行: _G.CleanupAirportESP()"})
        
        -- 悬浮按钮（手机显示，PC可手动开）
        task.spawn(function()
            task.wait(1); pcall(function()
                FloatingButtonGui = tagTrack(Instance.new("ScreenGui")); FloatingButtonGui.Name = "AirportESP_Btn"
                FloatingButtonGui.Enabled = IsMobile; FloatingButtonGui.ResetOnSpawn = false; FloatingButtonGui.Parent = CoreGui
                local btn = tagTrack(Instance.new("ImageButton")); btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.9, -25, 0.8, -25)
                btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80); btn.BackgroundTransparency = 0.2; btn.BorderSizePixel = 0; btn.Parent = FloatingButtonGui
                tagTrack(Instance.new("UICorner")); btn.UICorner.CornerRadius = UDim.new(0, 25)
                local t = tagTrack(Instance.new("TextLabel")); t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = "👁"
                t.TextScaled = true; t.Font = Enum.Font.SourceSansBold; t.TextColor3 = Color3.fromRGB(255, 255, 255); t.Parent = btn
                local d, ds, sp = false, nil, nil
                btn.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then d = true; ds = inp.Position; sp = btn.Position end end)
                btn.InputChanged:Connect(function(inp) if d and (inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseMovement) then local nx = sp.X.Scale + (inp.Position.X - ds.X) / 800; local ny = sp.Y.Scale + (inp.Position.Y - ds.Y) / 600; nx = math.max(0.02, math.min(0.95, nx)); ny = math.max(0.02, math.min(0.95, ny)); btn.Position = UDim2.new(nx, 0, ny, 0) end end)
                btn.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)
                btn.MouseButton1Click:Connect(mobileToggleWindow)
            end)
        end)
    end
    print("[机场安全透视] v12.5 已加载 | 作者: b站英吉利超入_")
else
    print("[机场安全透视] WindUI 加载失败，使用原生模式")
    local msg = Instance.new("Message"); msg.Text = "⚠️ WindUI 加载失败，使用原生模式"; msg.Parent = Workspace; task.delay(5, function() msg:Destroy() end)
    local btnGui = tagTrack(Instance.new("ScreenGui")); btnGui.Name = "AirportESP_Btn"; btnGui.ResetOnSpawn = false; btnGui.Parent = CoreGui
    local btn = tagTrack(Instance.new("ImageButton")); btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.9, -25, 0.8, -25)
    btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80); btn.BackgroundTransparency = 0.2; btn.BorderSizePixel = 0; btn.Parent = btnGui
    tagTrack(Instance.new("UICorner")); btn.UICorner.CornerRadius = UDim.new(0, 25)
    local t = tagTrack(Instance.new("TextLabel")); t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = "👁"
    t.TextScaled = true; t.Font = Enum.Font.SourceSansBold; t.TextColor3 = Color3.fromRGB(255, 255, 255); t.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Settings.Enabled = not Settings.Enabled; updateAllESP()
        btn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 180, 80)
        if Settings.Enabled then task.spawn(scanNPCs) end
    end)
    task.spawn(function() while true do pcall(function() cleanESP(); if Settings.Enabled then scanNPCs() end end); task.wait(3) end end)
end
print("[机场安全透视] v12.5 脚本加载完成")
