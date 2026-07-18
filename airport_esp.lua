--[[
    机场安全透视脚本 v12.4
    作者: b站英吉利超入_
    
    v12.4 全面修复8个UI Bug:
    A: findWindowMainFrame() 双保险搜索窗口Frame
    B: win.OnClose/OnOpen 改用轮询检测窗口可见性
    C: 初始粒子颜色与Dark主题一致
    D: 透明度改用 WindUI.TransparencyValue
    E: PC端也创建半透明悬浮按钮（默认隐藏）
    F: 清理旧WindUI实例
    G: 移除无用变量 scriptStartTime
    I: 扫描循环可停止
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

-- ========== B3: 启动时立即清理所有残留（不等待）==========
local TAG_NAME = "AirportESP"

local function immediateCleanup()
    local count = 0
    pcall(function()
        -- 按Attribute标记清理
        for _, inst in ipairs(CoreGui:GetDescendants()) do
            local s, attr = pcall(function() return inst:GetAttribute(TAG_NAME) end)
            if s and attr then pcall(function() inst:Destroy() end); count = count + 1 end
        end
        -- 另外按名称清理（兼容旧版无Tag的残留）
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name
                if n:find("AirportESP") or n:find("Template_") or n:find("Particle") then
                    pcall(function() gui:Destroy() end); count = count + 1
                end
            end
        end
        -- Bug F: 清理旧WindUI实例（保留最新的）
        local winduiCount = 0
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name:find("WindUI") then
                winduiCount = winduiCount + 1
                if winduiCount > 1 then
                    pcall(function() gui:Destroy() end); count = count + 1
                end
            end
        end
    end)
    if count > 0 then print("[清理] 启动时已清除 " .. count .. " 个残留实例") end
end
immediateCleanup()

-- ========== BindToClose清理（脚本被强制停止时）==========
game:BindToClose(function()
    pcall(function()
        for _, inst in ipairs(CoreGui:GetDescendants()) do
            local s, attr = pcall(function() return inst:GetAttribute(TAG_NAME) end)
            if s and attr then pcall(function() inst:Destroy() end) end
        end
    end)
end)

-- ========== 暴露外部清理函数 ==========
_G.CleanupAirportESP = function()
    immediateCleanup()
    print("[清理] 手动清理完成")
end

-- ========== tagTrack ==========
local function tagTrack(instance)
    if not instance then return nil end
    pcall(function() instance:SetAttribute(TAG_NAME, true) end)
    return instance
end

-- ========== 配置 ==========
local Settings = {
    Enabled = false, BadOnly = false, ShowDistance = false, ShowHealth = false,
    MaxRange = 500, Particles = true, CurrentTheme = "Dark",
    ParticleColor = Color3.fromRGB(80, 170, 255), -- Bug C: 初始即匹配Dark主题
}

-- ========== B1: 重新设计主题色方案 ==========
-- 所有颜色经过手动挑选，确保在深色背景下清晰可见且柔和
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
local Stats={Good=0,Bad=0,Total=0};local Controls={};local Keybinds={}
local PopupConfirmed=false;local TabElements={};local ConfigName="default"
local DebugLog={};local ParticleRunning=false;local Particles={}
local WindowMainFrame=nil;local ParticleHeartbeat=nil
local WindowVisiblePoll=false -- Bug B: 窗口可见性轮询

local function mobileToggleWindow()
    if not WindowRef then return end;pcall(function()VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.RightShift,false,game);task.wait(0.05);VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.RightShift,false,game)end)
end

local function debugPrint(msg) table.insert(DebugLog,msg);if #DebugLog>100 then table.remove(DebugLog,1)end;print("[ESP调试]"..msg)end

-- ========== B2: 粒子系统重写 ==========
-- 新方案: 粒子放在一个Frame容器中,该容器动态追踪窗口位置,ClipsDescendants=true
-- 粒子只在窗口区域内可见,不会穿透到UI控件上方

-- Bug A: 双保险搜索窗口主Frame
local function findWindowMainFrame()
    WindowMainFrame = nil
    -- 方法1: 遍历CoreGui找Frame+UICorner+Size>700
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
    -- 方法2: 如果没找到，尝试找WindUI窗口内最大的Frame
    if not WindowMainFrame then
        pcall(function()
            for _, gui in ipairs(CoreGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name:find("WindUI") then
                    local bestSize = 0; local bestFrame = nil
                    for _, f in ipairs(gui:GetChildren()) do
                        if f:IsA("Frame") and f.AbsoluteSize.X > bestSize then
                            bestSize = f.AbsoluteSize.X; bestFrame = f
                        end
                    end
                    if bestFrame then WindowMainFrame = bestFrame; return end
                end
            end
        end)
    end
    return WindowMainFrame
end

local function getParticleColor() return Settings.ParticleColor or Color3.fromRGB(80,170,255) end

local function createParticles()
    -- 先销毁旧的
    if ParticleContainer then pcall(function()ParticleContainer:Destroy()end);ParticleContainer=nil end
    Particles={};ParticleRunning=false
    if ParticleHeartbeat then pcall(function()ParticleHeartbeat:Disconnect()end);ParticleHeartbeat=nil end
    if not Settings.Particles then return end
    
    -- 找到窗口主Frame
    findWindowMainFrame()
    if not WindowMainFrame then
        -- 等一会再试
        task.spawn(function()task.wait(1);findWindowMainFrame();if WindowMainFrame then createParticles()end end)
        return
    end
    
    pcall(function()
        -- 在CoreGui中创建一个ScreenGui用于粒子容器
        local particleScreenGui = Instance.new("ScreenGui")
        particleScreenGui.Name = "AirportESP_ParticleContainer"
        particleScreenGui.DisplayOrder = -9999  -- 在窗口后面
        particleScreenGui.ResetOnSpawn = false
        particleScreenGui.Parent = CoreGui
        tagTrack(particleScreenGui)
        
        -- 粒子容器Frame，ClipsDescendants=true确保粒子不超出窗口
        ParticleContainer = Instance.new("Frame")
        ParticleContainer.BackgroundTransparency = 1
        ParticleContainer.BorderSizePixel = 0
        ParticleContainer.ClipsDescendants = true
        ParticleContainer.Parent = particleScreenGui
        tagTrack(ParticleContainer)
        
        -- 初始位置匹配窗口
        local pos = WindowMainFrame.AbsolutePosition
        local size = WindowMainFrame.AbsoluteSize
        ParticleContainer.Position = UDim2.fromOffset(pos.X, pos.Y)
        ParticleContainer.Size = UDim2.fromOffset(size.X, size.Y)
        
        -- 每帧追踪窗口位置
        ParticleHeartbeat = RunService.Heartbeat:Connect(function()
            if not ParticleContainer or not ParticleContainer.Parent then
                if ParticleHeartbeat then ParticleHeartbeat:Disconnect();ParticleHeartbeat=nil end;return
            end
            if WindowMainFrame and WindowMainFrame.Parent then
                local absPos = WindowMainFrame.AbsolutePosition
                local absSize = WindowMainFrame.AbsoluteSize
                ParticleContainer.Position = UDim2.fromOffset(absPos.X, absPos.Y)
                ParticleContainer.Size = UDim2.fromOffset(absSize.X, absSize.Y)
                ParticleContainer.Visible = WindowMainFrame.Visible
            else
                ParticleContainer.Visible = false
                findWindowMainFrame()
            end
        end)
        
        -- 创建粒子（相对于容器，用Offset定位）
        local particleColor = getParticleColor()
        local w = size.X; local h = size.Y
        for i = 1, 50 do
            local dot = Instance.new("Frame"); local sz = math.random(4, 8)
            dot.Size = UDim2.new(0, sz, 0, sz)
            dot.Position = UDim2.fromOffset(math.random(10, math.max(20, w-10)), math.random(10, math.max(20, h-10)))
            dot.BackgroundColor3 = particleColor
            dot.BackgroundTransparency = 0.4 + math.random() * 0.4
            dot.BorderSizePixel = 0
            dot.ZIndex = 0
            dot.Parent = ParticleContainer
            tagTrack(dot)
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = dot
            local angle = math.random() * 6.28
            local speed = 0.1 + math.random() * 0.3
            table.insert(Particles, {
                Frame = dot, Vx = math.cos(angle) * speed, Vy = math.sin(angle) * speed,
                Phase = math.random() * 6.28, SizeBase = sz, ContainerW = w, ContainerH = h,
            })
        end
        
        ParticleRunning = true
        task.spawn(function()
            local time = 0
            while ParticleRunning and ParticleContainer and ParticleContainer.Parent do
                time = time + 0.03
                pcall(function()
                    local cw = ParticleContainer.AbsoluteSize.X
                    local ch = ParticleContainer.AbsoluteSize.Y
                    if cw <= 0 or ch <= 0 then task.wait(0.03); return end
                    for _, p in ipairs(Particles) do
                        if not p.Frame or not p.Frame.Parent then continue end
                        local pos = p.Frame.Position
                        local x = pos.X.Offset + p.Vx
                        local y = pos.Y.Offset + p.Vy
                        local sz = p.Frame.AbsoluteSize.X
                        -- 严格边界反弹
                        if x + sz >= cw then x = cw - sz; p.Vx = -p.Vx * 0.95
                        elseif x < 0 then x = 0; p.Vx = -p.Vx * 0.95 end
                        if y + sz >= ch then y = ch - sz; p.Vy = -p.Vy * 0.95
                        elseif y < 0 then y = 0; p.Vy = -p.Vy * 0.95 end
                        p.Frame.Position = UDim2.fromOffset(x, y)
                        -- 呼吸动画
                        p.Frame.BackgroundTransparency = 0.4 + math.sin(time * 0.8 + p.Phase) * 0.25
                        local breathe = math.max(1, p.SizeBase + math.sin(time + p.Phase) * 0.8)
                        p.Frame.Size = UDim2.new(0, breathe, 0, breathe)
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
        pcall(function()
            local parent = ParticleContainer.Parent
            if parent then pcall(function() parent:Destroy() end) end
        end)
        ParticleContainer = nil
    end
    Particles = {}
end

-- Bug B: 窗口可见性轮询（替代不可靠的win.OnClose/OnOpen）
local function startWindowVisibilityPoll()
    WindowVisiblePoll = true
    task.spawn(function()
        local wasVisible = nil
        while WindowVisiblePoll do
            task.wait(0.5)
            pcall(function()
                if not WindowRef then WindowVisiblePoll = false; return end
                local isVisible = false
                -- 尝试多种方式判断窗口可见性
                local ok1, v1 = pcall(function() return WindowRef.Visible end)
                if ok1 then isVisible = v1 end
                if wasVisible == nil then wasVisible = isVisible end
                if wasVisible ~= isVisible then
                    if isVisible then
                        -- 窗口打开了
                        if Settings.Particles then createParticles() end
                    else
                        -- 窗口关闭了
                        destroyParticles()
                    end
                    wasVisible = isVisible
                end
            end)
        end
    end)
end

-- ========== NPC 分类器 ==========
local function getAllAttributes(obj) local attrs={};if not obj then return attrs end;pcall(function()for _,a in ipairs(obj:GetAttributes())do attrs[a]=obj:GetAttribute(a)end end);return attrs end

local function classifyNPC(character,humanoid)
    local name=character.Name or"";local path="";pcall(function()path=character:GetFullName()end)
    if humanoid then local attrs=getAllAttributes(humanoid);for k,v in pairs(attrs)do debugPrint(string.format("  属性: Humanoid.%s=%s",k,tostring(v)))end end
    local charAttrs=getAllAttributes(character);for k,v in pairs(charAttrs)do debugPrint(string.format("  属性: Character.%s=%s",k,tostring(v)))end;local tool=character:FindFirstChildOfClass("Tool");debugPrint(string.format("检测到:%s|路径:%s",name,path))
    local ac={"NPCType","Type","Team","Faction","Role","Class","Group","Kind","Identity"}
    for _,an in ipairs(ac)do local val=nil;if humanoid then pcall(function()val=humanoid:GetAttribute(an)end)end;if val==nil then pcall(function()val=character:GetAttribute(an)end)end;if val~=nil then local vs=tostring(val):lower();debugPrint(string.format("  属性[%s]=%s",an,tostring(val)));for _,g in ipairs({"agent","good","friendly","ally","police","friend","blue","guard","clean"})do if vs:find(g)then debugPrint("  →属性好人");return"Good"end end;for _,b in ipairs({"enemy","bad","hostile","terrorist","criminal","foe","enem","red","danger"})do if vs:find(b)then debugPrint("  →属性坏人");return"Bad"end end end end
    debugPrint(string.format("  名字:%s",name))
    for _,kw in ipairs({"警察","保安","警卫","警","守卫","士兵","军官","长官","巡逻","特工","安全","安保","护卫","卫兵","军队","公安","辅警","Police","Security","Guard","Agent","Officer","Sheriff","Soldier","Patrol","Cop","Marshal","Blue","Friendly","Ally","Good"})do if name:find(kw,1,true)or name:lower():find(kw:lower(),1,true)then debugPrint(string.format("  →名字匹配好人:%s",kw));return"Good"end end
    for _,kw in ipairs({"恐怖","匪徒","匪","敌人","坏","犯罪","袭击","暴徒","杀手","叛军","武装","劫匪","入侵","歹徒","黑帮","毒贩","绑匪","Terrorist","Enemy","Hostile","Criminal","Threat","Suspect","Bandit","Mercenary","Attacker","Red","Danger","Bad"})do if name:find(kw,1,true)or name:lower():find(kw:lower(),1,true)then debugPrint(string.format("  →名字匹配坏人:%s",kw));return"Bad"end end
    local pc={};for _,p in ipairs(character:GetChildren())do if p:IsA("BasePart")then local cn=p.BrickColor.Name;pc[cn]=(pc[cn] or 0)+1 end end;local gc=0;local bc=0;for c,n in pairs(pc)do if c:lower():find("blue")or c:lower():find("green")or c:find("White")then gc=gc+n end;if c:lower():find("red")or c:lower():find("black")or c:lower():find("brown")or c:lower():find("grey")then bc=bc+n end end
    if gc>bc and gc>=3 then debugPrint(string.format("  →颜色好人(%d>%d)",gc,bc));return"Good"end;if bc>gc and bc>=3 then debugPrint(string.format("  →颜色坏人(%d>%d)",bc,gc));return"Bad"end
    if character.Parent then local pn=character.Parent.Name;for _,kw in ipairs({"警察","保安","Police","Guard","Agent"})do if pn:find(kw,1,true)then debugPrint("  →父级好人");return"Good"end end;for _,kw in ipairs({"恐怖","匪","敌人","Terror","Enemy"})do if pn:find(kw,1,true)then debugPrint("  →父级坏人");return"Bad"end end end
    if tool then local tn=tool.Name;for _,kw in ipairs({"Arrest","Taser","Bat","Radio","Handcuff","警","盾","枪"})do if tn:find(kw,1,true)then debugPrint("  →工具好人");return"Good"end end;for _,kw in ipairs({"Knife","Bomb","Grenade","RPG","Explosive","刀","炸"})do if tn:find(kw,1,true)then debugPrint("  →工具坏人");return"Bad"end end end
    local pl=path:lower();if pl:find("agent")or pl:find("police")or pl:find("friendly")then debugPrint("  →路径好人");return"Good"end;if pl:find("npc")or pl:find("enemy")or pl:find("terror")then debugPrint("  →路径坏人");return"Bad"end
    debugPrint("  →无法判断，跳过");return nil
end

local function isRealPlayer(c)if not c or not c:IsA("Model")then return false end;for _,p in ipairs(Players:GetPlayers())do if p.Character==c then return true end end;return false end

local function createESP(c,nt)
    if not c or not c.Parent then return false end;if isRealPlayer(c)then return false end
    if ESPObjects[c]then local col=nt=="Good"and Color3.fromRGB(0,255,100)or Color3.fromRGB(255,50,50);local o=ESPObjects[c];local s=Settings.Enabled and(not Settings.BadOnly or nt=="Bad");if o.Highlight then o.Highlight.FillColor=col;o.Highlight.Enabled=s end;if o.Billboard then o.Billboard.Enabled=s end;return true end
    local root=c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Torso")or c:FindFirstChildOfClass("Part");if not root then return false end;local myChar=Players.LocalPlayer and Players.LocalPlayer.Character;local myRoot=myChar and(myChar:FindFirstChild("HumanoidRootPart")or myChar:FindFirstChild("Torso"))
    if myRoot and root and(root.Position-myRoot.Position).Magnitude>Settings.MaxRange then return false end;local s=Settings.Enabled and(not Settings.BadOnly or nt=="Bad");local col=nt=="Good"and Color3.fromRGB(0,255,100)or Color3.fromRGB(255,50,50)
    local hl=tagTrack(Instance.new("Highlight"));hl.Adornee=c;hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;hl.FillTransparency=0.4;hl.OutlineTransparency=0.2;hl.FillColor=col;hl.OutlineColor=Color3.fromRGB(255,255,255);hl.Enabled=s;hl.Parent=CoreGui
    local head=c:FindFirstChild("Head")or c:FindFirstChild("Torso")or root;local bb=tagTrack(Instance.new("BillboardGui"));bb.Adornee=head;bb.Size=UDim2.new(0,160,0,50);bb.StudsOffset=Vector3.new(0,3,0);bb.AlwaysOnTop=true;bb.Enabled=s;bb.Parent=CoreGui
    local bg=tagTrack(Instance.new("Frame"));bg.Size=UDim2.new(1,0,1,0);bg.BackgroundColor3=Color3.fromRGB(0,0,0);bg.BackgroundTransparency=0.4;bg.BorderSizePixel=0;bg.Parent=bb;tagTrack(Instance.new("UICorner"));bg.UICorner.CornerRadius=UDim.new(0,4)
    local lbl=tagTrack(Instance.new("TextLabel"));lbl.Size=UDim2.new(1,-4,0.55,0);lbl.Position=UDim2.new(0,2,0,2);lbl.BackgroundTransparency=1;lbl.TextColor3=col;lbl.TextScaled=true;lbl.Font=Enum.Font.SourceSansBold;lbl.Text=nt=="Good"and"👮 好人"or"💀 坏人";lbl.BorderSizePixel=0;lbl.Parent=bg
    local info=tagTrack(Instance.new("TextLabel"));info.Size=UDim2.new(1,-4,0.4,0);info.Position=UDim2.new(0,2,0.55,2);info.BackgroundTransparency=1;info.TextColor3=Color3.fromRGB(255,255,255);info.TextScaled=true;info.Font=Enum.Font.SourceSans;info.Text="";info.BorderSizePixel=0;info.Parent=bg
    ESPObjects[c]={Highlight=hl,Billboard=bb,Label=lbl,InfoLine=info,Head=head,Root=root};if nt=="Good"then Stats.Good=Stats.Good+1 else Stats.Bad=Stats.Bad+1 end;Stats.Total=Stats.Total+1;TrackedNPCs[c]=nt;return true
end

local function removeESP(ch)if ESPObjects[ch]then local o=ESPObjects[ch];pcall(function()o.Highlight:Destroy()end);pcall(function()o.Billboard:Destroy()end);ESPObjects[ch]=nil;local nt=TrackedNPCs[ch];if nt=="Good"then Stats.Good=math.max(0,Stats.Good-1)elseif nt=="Bad"then Stats.Bad=math.max(0,Stats.Bad-1)end;Stats.Total=math.max(0,Stats.Total-1);TrackedNPCs[ch]=nil end end

local function cleanESP()for ch,_ in pairs(ESPObjects)do if not ch or not ch.Parent then removeESP(ch)end end end

local function updateLabels()local myChar=Players.LocalPlayer and Players.LocalPlayer.Character;local myRoot=myChar and(myChar:FindFirstChild("HumanoidRootPart")or myChar:FindFirstChild("Torso"));for ch,o in pairs(ESPObjects)do if o.Billboard and o.Billboard.Enabled and o.InfoLine then local pts={};if Settings.ShowDistance and myRoot and o.Root then local d=math.floor((o.Root.Position-myRoot.Position).Magnitude+0.5);table.insert(pts,d.."m")end;if Settings.ShowHealth then local h=ch:FindFirstChildOfClass("Humanoid");if h then table.insert(pts,"HP:"..math.floor(h.Health+0.5).."/"..math.floor(h.MaxHealth+0.5))end end;o.InfoLine.Text=table.concat(pts," | ")end end end

local function updateAllESP()for ch,o in pairs(ESPObjects)do local nt=TrackedNPCs[ch];local s=Settings.Enabled and(not Settings.BadOnly or nt=="Bad");if o.Highlight then o.Highlight.Enabled=s end;if o.Billboard then o.Billboard.Enabled=s end end end

-- Bug I: 扫描循环可停止
local function scanNPCs()if IsScanning then return end;IsScanning=true;debugPrint("=====开始扫描=====");pcall(function()for _,o in ipairs(Workspace:GetDescendants())do local h,c=nil,nil;if o:IsA("Humanoid")then h=o;c=o.Parent end;if c and h and not TrackedNPCs[c]and not isRealPlayer(c)then if c:FindFirstChild("Head")or c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Torso")then debugPrint(string.format("发现NPC(Humanoid):%s",c.Name));local nt=classifyNPC(c,h);if nt then createESP(c,nt)end end end;task.wait()end end);debugPrint(string.format("=====扫描结束:好人%d坏人%d=====",Stats.Good,Stats.Bad));IsScanning=false end

local function beautifyUI()pcall(function()for _,s in ipairs(CoreGui:GetDescendants())do if s:IsA("ScrollingFrame")then s.ScrollBarThickness=14;s.ScrollBarImageColor3=Color3.fromRGB(220,220,220);s.ScrollBarImageTransparency=0.1 end end end)end

task.spawn(function()while true do task.wait(3);beautifyUI()end end)

-- ========== 加载 WindUI ==========
local WindUI=nil;local s,r=pcall(function()return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()end)

if s and r then
    WindUI=r;pcall(function()WindUI:SetTheme("Dark")end)
    -- Bug C: 加载后立即计算Dark主题色
    Settings.ParticleColor = getThemePrimaryColor("Dark")
    
    WindUI:Popup({Title="机场安全透视 v12.4",Icon="solar:info-square-bold",Content="👁 透视高亮 - Highlight穿墙显示所有NPC\n🔍 智能识别 - 多维度区分好人(绿)与坏人(红)\n🏷 头顶标签 - 显示类型/距离/血量\n🔧 自定义快捷键 - 自由绑定按键\n💾 配置保存 - 自动保存/读取设置\n🎨 主题系统 - 粒子颜色动态适配\n✨ 粒子背景 - 窗口内Clips裁剪+追踪窗口位置\n🧹 即时清理 - 启动时+关闭时自动清除所有残留\n\n⚠️ 加载后所有功能默认关闭，需手动开启",
        Buttons={{Title="取消",Callback=function()end,Variant="Tertiary"},{Title="确认加载",Icon="solar:arrow-right-bold",Callback=function()PopupConfirmed=true;pcall(function()WindUI:Notify({Title="✅ 已加载",Content="⌨️ 按 RightShift 打开菜单",Duration=4,Icon="solar:bell-bold"})end);task.spawn(function()createWindow();task.wait(1);scanNPCs()end)end,Variant="Primary"}}})
    task.spawn(function()
        while not PopupConfirmed do task.wait(0.5)end;task.wait(0.5);beautifyUI()
        -- Bug I: 扫描循环只会运行当 Settings.Enabled = true 时
        task.spawn(function()while true do pcall(function()cleanESP();if Settings.Enabled then scanNPCs()end end)task.wait(5)end end)
        task.spawn(function()
            while true do pcall(function()if TabElements.GoodP then TabElements.GoodP:SetTitle("🟢 好人: "..Stats.Good);TabElements.BadP:SetTitle("🔴 坏人: "..Stats.Bad);TabElements.TotalP:SetTitle("📊 总计: "..Stats.Total)end;if TabElements.ScanI then TabElements.ScanI:Set(IsScanning and"📡 扫描中..."or"✅ 就绪")end;if TabElements.DebugI then local ls={};for i=math.max(1,#DebugLog-4),#DebugLog do table.insert(ls,DebugLog[i])end;TabElements.DebugI:Set(table.concat(ls,"\n"))end;updateLabels()end)task.wait(0.5)end end)
        UserInputService.InputBegan:Connect(function(input,gp)if gp then return end;if input.UserInputType~=Enum.UserInputType.Keyboard then return end;local kn=input.KeyCode.Name;if Keybinds.ESP and Keybinds.ESP~=""and kn==Keybinds.ESP then Settings.Enabled=not Settings.Enabled;pcall(function()if Controls.ESPToggle then Controls.ESPToggle:Set(Settings.Enabled)end end);updateAllESP();if Settings.Enabled then task.spawn(scanNPCs)end end;if Keybinds.BadOnly and Keybinds.BadOnly~=""and kn==Keybinds.BadOnly then Settings.BadOnly=not Settings.BadOnly;pcall(function()if Controls.BadOnlyToggle then Controls.BadOnlyToggle:Set(Settings.BadOnly)end end);updateAllESP()end end)
    end)

    function createWindow()
        if WindowRef then return end
        local ok,win=pcall(function()return WindUI:CreateWindow({Title="机场安全透视",Author="b站英吉利超入_",Icon="solar:shield-warning-bold",Size=UDim2.fromOffset(750,520),ToggleKey=Enum.KeyCode.RightShift,Folder="airport-esp",Acrylic=true,Transparent=true,Resizable=false,SideBarWidth=180,ScrollBarEnabled=true,HideSearchBar=true})end)
        if not ok or not win then print("[机场安全透视] 窗口创建失败:",ok);return end;WindowRef=win
        -- Bug D: 使用 WindUI.TransparencyValue 而不是 WindowRef:ToggleTransparency
        pcall(function() WindUI.TransparencyValue = 0.22 end)
        
        -- Bug B: 启动窗口可见性轮询
        startWindowVisibilityPoll()

        local mt=win:Tab({Title="主控面板",Icon="solar:slider-vertical-bold"});mt:Paragraph({Title="👁 透视控制"});Controls.ESPToggle=mt:Toggle({Flag="ESPToggle",Title="透视开关",Value=false,Callback=function(v)Settings.Enabled=v;updateAllESP();if v then task.spawn(scanNPCs)end end});Controls.BadOnlyToggle=mt:Toggle({Flag="BadOnlyToggle",Title="仅显示坏人",Value=false,Callback=function(v)Settings.BadOnly=v;updateAllESP()end})
        mt:Divider();mt:Paragraph({Title="📐 显示设置"});Controls.DistanceToggle=mt:Toggle({Flag="DistanceToggle",Title="显示距离",Value=false,Callback=function(v)Settings.ShowDistance=v end});Controls.HealthToggle=mt:Toggle({Flag="HealthToggle",Title="显示血量",Value=false,Callback=function(v)Settings.ShowHealth=v end})
        mt:Divider();Controls.RangeSlider=mt:Slider({Flag="RangeSlider",Title="最大探测距离",Step=50,Value={Min=50,Max=1000,Default=500},Width=200,IsTextbox=true,Callback=function(v)Settings.MaxRange=v end})

        local ft=win:Tab({Title="功能设置",Icon="solar:settings-bold"});ft:Paragraph({Title="🔑 快捷键设置"});Controls.ESPKeybind=ft:Keybind({Flag="ESPKeybind",Title="透视开关快捷键",Value="",Callback=function(k)Keybinds.ESP=k end});Controls.BadOnlyKeybind=ft:Keybind({Flag="BadOnlyKeybind",Title="仅坏人模式快捷键",Value="",Callback=function(k)Keybinds.BadOnly=k end});ft:Divider();ft:Paragraph({Title="💡 提示",Desc="窗口快捷键在UI设置中绑定（默认 RightShift）"})

        local ut=win:Tab({Title="UI设置",Icon="solar:monitor-bold"});ut:Paragraph({Title="⚙️ 界面设置"});Controls.WindowKeybind=ut:Keybind({Flag="WindowKeybind",Title="窗口开关快捷键",Value="RightShift",Callback=function(k)Keybinds.Window=k;if WindowRef then pcall(function()WindowRef:SetToggleKey(Enum.KeyCode[k])end)end end});Controls.FloatingBtnToggle=ut:Toggle({Flag="FloatingBtnToggle",Title="显示悬浮按钮",Value=IsMobile,Callback=function(v)if FloatingButtonGui then FloatingButtonGui.Enabled=v end end})
        ut:Divider();ut:Paragraph({Title="🌀 背景效果"});Controls.ParticlesToggle=ut:Toggle({Flag="ParticlesToggle",Title="浮动粒子背景(50个)",Value=true,Callback=function(v)Settings.Particles=v;if v then createParticles()else destroyParticles()end end})
        ut:Divider();ut:Paragraph({Title="✨ 窗口效果"});Controls.AcrylicToggle=ut:Toggle({Flag="AcrylicToggle",Title="毛玻璃效果",Value=true,Callback=function(v)pcall(function()WindUI:ToggleAcrylic(v)end)end});Controls.TransparencyToggle=ut:Toggle({Flag="TransparencyToggle",Title="透明背景",Value=true,Callback=function(v)if v then pcall(function()WindUI.TransparencyValue=0.22 end)else pcall(function()WindUI.TransparencyValue=0 end)end end})
        ut:Divider();ut:Paragraph({Title="🎨 主题系统",Desc="切换主题时粒子颜色自动适配（手动精选配色）"})
        local allThemes={};pcall(function()allThemes=WindUI:GetThemes()end);local themeNames={};for n,_ in pairs(allThemes)do table.insert(themeNames,n)end;table.sort(themeNames)
        Controls.ThemeDropdown=ut:Dropdown({Flag="ThemeDropdown",Title="选择主题",Values=themeNames,Value="Dark",Callback=function(selected)if selected then Settings.CurrentTheme=selected;pcall(function()WindUI:SetTheme(selected)end);Settings.ParticleColor=getThemePrimaryColor(selected);updateParticleColor()end end})
        ut:Divider();ut:Paragraph({Title="💡 提示",Desc="粒子在窗口区域内浮动(Clips裁剪)\n粒子容器每帧追踪窗口位置\n关闭/切换窗口时粒子自动销毁"})

        local st=win:Tab({Title="信息统计",Icon="solar:chart-bold"});TabElements.GoodP=st:Paragraph({Title="🟢 好人: 0"});TabElements.BadP=st:Paragraph({Title="🔴 坏人: 0"});TabElements.TotalP=st:Paragraph({Title="📊 总计: 0"});st:Divider();TabElements.ScanI=st:Input({Title="扫描状态",Value="等待中...",Locked=true});st:Divider();TabElements.DebugI=st:Input({Title="📋 调试日志",Value="等待检测...",Locked=true,Desc="每次扫描会显示NPC的属性信息"})

        local ct=win:Tab({Title="配置管理",Icon="solar:diskette-bold"});ct:Paragraph({Title="💾 配置管理",Desc="保存/加载你的所有设置"});local cni=ct:Input({Flag="ConfigNameInput",Title="配置名称",Value="default",Icon="solar:file-text-bold",Callback=function(v)ConfigName=v end});ct:Space();local CM=WindowRef.ConfigManager;local AC={};pcall(function()AC=CM:AllConfigs()end);local DV=nil;pcall(function()for _,v in ipairs(AC)do if v=="default"then DV="default";break end end end);local ACD=ct:Dropdown({Title="已有配置",Desc="选择要加载的配置",Values=AC,Value=DV,Callback=function(v)if v then ConfigName=v;pcall(function()cni:Set(v)end)end end});ct:Space();ct:Button({Title="💾 保存配置",Icon="solar:check-circle-bold",Justify="Center",Color=Color3.fromHex("#305dff"),Callback=function()if not CM then return end;pcall(function()local c=CM:Config(ConfigName);if c and c:Save()then WindUI:Notify({Title="✅ 配置已保存",Content="配置 '"..ConfigName.."' 已保存",Icon="solar:check-circle-bold",Duration=3});ACD:Refresh(CM:AllConfigs())end end)end});ct:Space();ct:Button({Title="📂 加载配置",Icon="solar:refresh-circle-bold",Justify="Center",Color=Color3.fromHex("#10C550"),Callback=function()if not CM then return end;pcall(function()local c=CM:CreateConfig(ConfigName,false);if c and c:Load()then WindUI:Notify({Title="✅ 配置已加载",Content="配置 '"..ConfigName.."' 已加载",Icon="solar:refresh-circle-bold",Duration=3})end end)end});ct:Space();ct:Button({Title="🗑️ 删除配置",Icon="solar:trash-bin-trash-bold",Justify="Center",Color=Color3.fromHex("#ff3040"),Callback=function()if not CM then return end;pcall(function()local c=CM:Config(ConfigName);if c and c:Delete()then WindUI:Notify({Title="🗑️ 配置已删除",Content="配置 '"..ConfigName.."' 已删除",Icon="solar:trash-bin-trash-bold",Duration=3});ACD:Refresh(CM:AllConfigs())end end)end});ct:Divider();ct:Paragraph({Title="💡 提示",Desc="所有带 Flag 的元素自动保存/恢复\n手动清理: 执行 _G.CleanupAirportESP()"})

        task.spawn(function()task.wait(1);pcall(function()if CM then local c=CM:CreateConfig("default",true)end end);createParticles()end)

        local at=win:Tab({Title="关于",Icon="solar:info-square-bold"});at:Paragraph({Title="机场安全透视 v12.4",Desc="全面修复8个UI Bug"});at:Divider();at:Paragraph({Title="👤 作者",Desc="b站英吉利超入_"});at:Divider();at:Paragraph({Title="💡 使用说明",Desc=IsMobile and"手机: 点击悬浮按钮"or"PC: 按 RightShift 打开菜单"});at:Paragraph({Title="⚠️ 提示",Desc="所有功能默认关闭，请在菜单中手动开启"});at:Paragraph({Title="🧹 清理",Desc="脚本启动时自动清理上次残留\n执行: _G.CleanupAirportESP()"})

        -- Bug E: PC端也创建半透明悬浮按钮（默认隐藏，可在UI设置中开启）
        task.spawn(function()
            task.wait(1);pcall(function()
                FloatingButtonGui=tagTrack(Instance.new("ScreenGui"));FloatingButtonGui.Name="AirportESP_Btn";
                -- 默认：手机显示，PC隐藏
                FloatingButtonGui.Enabled=IsMobile;FloatingButtonGui.ResetOnSpawn=false;FloatingButtonGui.Parent=CoreGui
                local btn=tagTrack(Instance.new("ImageButton"));btn.Size=UDim2.new(0,50,0,50);btn.Position=UDim2.new(0.9,-25,0.8,-25);btn.BackgroundColor3=Color3.fromRGB(0,180,80);btn.BackgroundTransparency=0.2;btn.BorderSizePixel=0;btn.Parent=FloatingButtonGui
                tagTrack(Instance.new("UICorner"));btn.UICorner.CornerRadius=UDim.new(0,25);local t=tagTrack(Instance.new("TextLabel"));t.Size=UDim2.new(1,0,1,0);t.BackgroundTransparency=1;t.Text="👁";t.TextScaled=true;t.Font=Enum.Font.SourceSansBold;t.TextColor3=Color3.fromRGB(255,255,255);t.Parent=btn
                local d,ds,sp=false,nil,nil
                btn.InputBegan:Connect(function(inp)if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then d=true;ds=inp.Position;sp=btn.Position end end)
                btn.InputChanged:Connect(function(inp)if d and(inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseMovement)then local nx=sp.X.Scale+(inp.Position.X-ds.X)/800;local ny=sp.Y.Scale+(inp.Position.Y-ds.Y)/600;nx=math.max(0.02,math.min(0.95,nx));ny=math.max(0.02,math.min(0.95,ny));btn.Position=UDim2.new(nx,0,ny,0)end end)
                btn.InputEnded:Connect(function(inp)if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then d=false end end)
                btn.MouseButton1Click:Connect(mobileToggleWindow)
            end)
        end)
    end
    print("[机场安全透视] v12.4 已加载 | 作者: b站英吉利超入_")
else
    print("[机场安全透视] WindUI 加载失败，使用原生模式")
    local msg=Instance.new("Message");msg.Text="⚠️ WindUI 加载失败，使用原生模式";msg.Parent=Workspace;task.delay(5,function()msg:Destroy()end)
    local btnGui=tagTrack(Instance.new("ScreenGui"));btnGui.Name="AirportESP_Btn";btnGui.ResetOnSpawn=false;btnGui.Parent=CoreGui
    local btn=tagTrack(Instance.new("ImageButton"));btn.Size=UDim2.new(0,50,0,50);btn.Position=UDim2.new(0.9,-25,0.8,-25);btn.BackgroundColor3=Color3.fromRGB(0,180,80);btn.BackgroundTransparency=0.2;btn.BorderSizePixel=0;btn.Parent=btnGui
    tagTrack(Instance.new("UICorner"));btn.UICorner.CornerRadius=UDim.new(0,25);local t=tagTrack(Instance.new("TextLabel"));t.Size=UDim2.new(1,0,1,0);t.BackgroundTransparency=1;t.Text="👁";t.TextScaled=true;t.Font=Enum.Font.SourceSansBold;t.TextColor3=Color3.fromRGB(255,255,255);t.Parent=btn
    btn.MouseButton1Click:Connect(function()Settings.Enabled=not Settings.Enabled;updateAllESP();btn.BackgroundColor3=Settings.Enabled and Color3.fromRGB(255,50,50)or Color3.fromRGB(0,180,80);if Settings.Enabled then task.spawn(scanNPCs)end end)
    task.spawn(function()while true do pcall(function()cleanESP();if Settings.Enabled then scanNPCs()end end)task.wait(3)end end)
end
print("[机场安全透视] v12.4 脚本加载完成")
