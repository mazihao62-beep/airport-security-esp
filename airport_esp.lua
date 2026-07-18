--[[
    机场安全透视脚本 v12.6
    作者: b站英吉利超入_
    
    v12.6 分类器全面简化: 移除不可靠的颜色/血量/工具检查
    只保留属性 + 名字 + 路径 三层检查
    + 新增 Debug Mode: 头顶显示NPC原始名字
    + 无法判断 → 跳过（不再默认为坏人）
]]

-- ========== 服务 ==========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if not IsMobile then pcall(function() IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled end) end

-- ========== 清理 ==========
local TAG = "AirportESP"
local function immediateCleanup()
    local c = 0
    pcall(function()
        for _, v in ipairs(CoreGui:GetDescendants()) do
            local ok, attr = pcall(function() return v:GetAttribute(TAG) end)
            if ok and attr then pcall(function() v:Destroy() end); c = c + 1 end
        end
        for _, g in ipairs(CoreGui:GetChildren()) do
            if g:IsA("ScreenGui") then
                local n = g.Name
                if n:find("AirportESP") or n:find("WindUI") then
                    local wc = 0
                    if n:find("WindUI") then wc = wc + 1; if wc > 1 then pcall(function() g:Destroy() end); c = c + 1 end
                    else pcall(function() g:Destroy() end); c = c + 1 end
                end
            end
        end
    end)
    if c > 0 then print("[清理] "..c.." 个") end
end
immediateCleanup()
_G.CleanupESP = function() immediateCleanup() end

local function tag(v)
    if v then pcall(function() v:SetAttribute(TAG, true) end) end
    return v
end

-- ========== 设置 ==========
local Settings = {
    Enabled = false, BadOnly = false, ShowDistance = false, ShowHealth = false,
    MaxRange = 500, Particles = true, CurrentTheme = "Dark",
    ParticleColor = Color3.fromRGB(80, 170, 255), DebugMode = false,
}

-- ========== 主题色 ==========
local ThemeColors = {
    dark=Color3.fromRGB(80,170,255), light=Color3.fromRGB(60,130,210),
    rose=Color3.fromRGB(255,130,170), plant=Color3.fromRGB(70,210,130),
    ocean=Color3.fromRGB(60,190,240), sunset=Color3.fromRGB(255,160,70),
    midnight=Color3.fromRGB(130,100,240), forest=Color3.fromRGB(60,180,90),
    lavender=Color3.fromRGB(190,140,255), coral=Color3.fromRGB(255,140,90),
    mint=Color3.fromRGB(80,230,190), peanut=Color3.fromRGB(210,180,90),
    sky=Color3.fromRGB(100,190,255), blood=Color3.fromRGB(230,90,80),
    lemon=Color3.fromRGB(230,210,70), cyber=Color3.fromRGB(0,235,210),
}

local function n2c(n) local h=0;for i=1,#n do h=h+string.byte(n,i)end;return Color3.fromRGB(math.floor(80+math.sin(h*137.5)*0.5*175+0.5),math.floor(100+math.sin(h*73.1+50)*0.5*155+0.5),math.floor(130+math.sin(h*41.7)*0.5*125+0.5)) end

local function getThemeColor(name)
    if not name then return Color3.fromRGB(80,170,255) end;local l=name:lower()
    local t=nil;pcall(function()t=WindUI:GetThemes()end)
    if t and t[name] then local d=t[name];local c=nil;pcall(function()if type(d)=="table" then c=d.Primary or d.Accent or d.Color or d.Main end end);if c then return c end end
    local m=ThemeColors[l];if m then return m end
    if l:find("dark")or l:find("night")then return Color3.fromRGB(80,170,255)end;if l:find("light")then return Color3.fromRGB(60,130,210)end;if l:find("rose")or l:find("pink")then return Color3.fromRGB(255,130,170)end;if l:find("plant")or l:find("green")or l:find("forest")or l:find("mint")then return Color3.fromRGB(70,210,130)end;if l:find("ocean")or l:find("blue")or l:find("sky")then return Color3.fromRGB(60,190,240)end;if l:find("sunset")or l:find("orange")or l:find("coral")then return Color3.fromRGB(255,160,70)end;if l:find("midnight")or l:find("purple")or l:find("lavender")then return Color3.fromRGB(130,100,240)end;if l:find("blood")or l:find("red")then return Color3.fromRGB(230,90,80)end;if l:find("lemon")or l:find("yellow")then return Color3.fromRGB(230,210,70)end
    return n2c(name)
end

-- ========== 变量 ==========
local ESPObjects={};local Tracked={};local IsScanning=false
local win=nil;local FloatBtn=nil;local PC=nil;local Stat={G=0,B=0,S=0};local Ctl={};local KB={}
local Pop=false;local TE={};local CFG="default";local DL={};local PR=false;local PS={};local WMF=nil;local PH=nil

local function mt() if not win then return end;pcall(function()VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.RightShift,false,game);task.wait(0.05);VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.RightShift,false,game)end) end
local function dp(m) table.insert(DL,m);if #DL>50 then table.remove(DL,1)end;print("[D]"..m) end

-- ========== 粒子 ==========
local function fw() WMF=nil;pcall(function()for _,g in ipairs(CoreGui:GetChildren())do if g:IsA("ScreenGui")then for _,f in ipairs(g:GetChildren())do if f:IsA("Frame")and f:FindFirstChild("UICorner")then local u=f:FindFirstChild("UICorner");if u and u.CornerRadius==UDim.new(0,8)and f.AbsoluteSize.X>700 then WMF=f;return end end end end end end);if not WMF then pcall(function()for _,g in ipairs(CoreGui:GetChildren())do if g:IsA("ScreenGui")and g.Name:find("WindUI")then local bs=0;local b=nil;for _,f in ipairs(g:GetChildren())do if f:IsA("Frame")and f.AbsoluteSize.X>bs then bs=f.AbsoluteSize.X;b=f end end;if b then WMF=b end end end end)end;return WMF end
local function gc() return Settings.ParticleColor or Color3.fromRGB(80,170,255) end

local function cp()
    if PC then pcall(function()PC:Destroy()end);PC=nil end;PS={};PR=false;if PH then pcall(function()PH:Disconnect()end);PH=nil end;if not Settings.Particles then return end;fw()
    if not WMF then task.spawn(function()task.wait(1);fw();if WMF then cp()end end);return end
    pcall(function()
        local sg=Instance.new("ScreenGui");sg.Name="AirportESP_PC";sg.DisplayOrder=-9999;sg.ResetOnSpawn=false;sg.Parent=CoreGui;tag(sg)
        PC=Instance.new("Frame");PC.BackgroundTransparency=1;PC.BorderSizePixel=0;PC.ClipsDescendants=true;PC.Parent=sg;tag(PC)
        local p=WMF.AbsolutePosition;local s=WMF.AbsoluteSize;PC.Position=UDim2.fromOffset(p.X,p.Y);PC.Size=UDim2.fromOffset(s.X,s.Y)
        PH=RunService.Heartbeat:Connect(function()if not PC or not PC.Parent then if PH then PH:Disconnect();PH=nil end;return end;if WMF and WMF.Parent then local a=WMF.AbsolutePosition;local b=WMF.AbsoluteSize;PC.Position=UDim2.fromOffset(a.X,a.Y);PC.Size=UDim2.fromOffset(b.X,b.Y);PC.Visible=WMF.Visible else PC.Visible=false;fw()end end)
        local c=gc();local w=s.X;local h=s.Y
        for i=1,50 do local d=Instance.new("Frame");local sz=math.random(4,8);d.Size=UDim2.new(0,sz,0,sz);d.Position=UDim2.fromOffset(math.random(10,math.max(20,w-10)),math.random(10,math.max(20,h-10)));d.BackgroundColor3=c;d.BackgroundTransparency=0.4+math.random()*0.4;d.BorderSizePixel=0;d.ZIndex=0;d.Parent=PC;tag(d);local cn=Instance.new("UICorner");cn.CornerRadius=UDim.new(0,10);cn.Parent=d;local a=math.random()*6.28;local sp=0.08+math.random()*0.2;table.insert(PS,{F=d,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})end
        PR=true
        task.spawn(function()local t=0;while PR and PC and PC.Parent do t=t+0.03;pcall(function()local cw=PC.AbsoluteSize.X;local ch=PC.AbsoluteSize.Y;if cw<=0 or ch<=0 then task.wait(0.03);return end;for _,p in ipairs(PS)do if not p.F or not p.F.Parent then continue end;local x=p.F.Position.X.Offset+p.Vx;local y=p.F.Position.Y.Offset+p.Vy;local sz=p.F.AbsoluteSize.X;if x+sz>=cw then x=cw-sz;p.Vx=-p.Vx*0.95 elseif x<0 then x=0;p.Vx=-p.Vx*0.95 end;if y+sz>=ch then y=ch-sz;p.Vy=-p.Vy*0.95 elseif y<0 then y=0;p.Vy=-p.Vy*0.95 end;p.F.Position=UDim2.fromOffset(x,y);p.F.BackgroundTransparency=0.4+math.sin(t*0.8+p.Ph)*0.25;local bs=math.max(1,p.Sz+math.sin(t+p.Ph)*0.8);p.F.Size=UDim2.new(0,bs,0,bs)end end);task.wait(0.03)end end)
    end)
end

local function upc() local c=gc();if not c or #PS==0 then return end;pcall(function()for _,p in ipairs(PS)do if p.F and p.F.Parent then p.F.BackgroundColor3=c end end end) end
local function dp2() PR=false;if PH then pcall(function()PH:Disconnect()end);PH=nil end;if PC then pcall(function()local p=PC.Parent;if p then pcall(function()p:Destroy()end)end end);PC=nil end;PS={} end

-- ========== v12.6 简化分类器 ==========
-- 仅保留: 属性→名字→路径，移除不可靠的颜色/血量/工具检查
-- 无法判断 → 跳过

local ATTR_NAMES = {"NPCType","Type","Faction","Team","Role","Kind","Affiliation","Alignment","Side"}
local ATTR_GOOD = {"agent","good","friendly","ally","police","friend","guard","civilian","security","law","team"}
local ATTR_BAD = {"enemy","bad","hostile","terrorist","criminal","danger","evil","suspect","threat","invader","rogue"}

local NAME_GOOD = {"警察","保安","警卫","警","守卫","士兵","军官","特工","巡逻","安全","安保","护卫","卫兵","公安","武警","官兵","police","guard","agent","officer","soldier","patrol","cop","friendly","safety","civil"}
local NAME_BAD = {"恐怖","匪徒","匪","敌人","坏","犯罪","袭击","暴徒","杀手","叛军","劫匪","歹徒","绑匪","terrorist","enemy","hostile","criminal","danger","suspect","invader","attacker","bad"}

local PATH_GOOD = {"agent","police","friendly","good","blue","safe","civilian","defender","guardian"}
local PATH_BAD = {"enemy","terror","hostile","criminal","danger","invader","attack","suspect","unsafe"}

local function classify(c, h)
    local name = c.Name or ""; local path = ""; pcall(function() path = c:GetFullName() end)
    dp(string.format("NPC: %s | %s", name, path))
    
    -- 1. 属性
    if h then
        for _, an in ipairs(ATTR_NAMES) do
            local val = nil; pcall(function() val = h:GetAttribute(an) end)
            if val then
                local vs = tostring(val):lower()
                for _, g in ipairs(ATTR_GOOD) do if vs == g or vs:find(g) then dp("  ✅属性好人["..an.."="..tostring(val).."]"); return "Good" end end
                for _, b in ipairs(ATTR_BAD) do if vs:find(b) then dp("  ❌属性坏人["..an.."="..tostring(val).."]"); return "Bad" end end
            end
        end
        -- 打印所有属性供调试
        pcall(function() for _, a in ipairs(h:GetAttributes()) do dp("   属性: "..a.."="..tostring(h:GetAttribute(a))) end end)
    end
    
    -- 2. 名字
    local nl = name:lower()
    for _, kw in ipairs(NAME_GOOD) do if nl:find(kw:lower(), 1, true) then dp("  ✅名字好人["..kw.."]"); return "Good" end end
    for _, kw in ipairs(NAME_BAD) do if nl:find(kw:lower(), 1, true) then dp("  ❌名字坏人["..kw.."]"); return "Bad" end end
    
    -- 3. 路径
    local pl = path:lower()
    for _, kw in ipairs(PATH_GOOD) do if pl:find(kw, 1, true) then dp("  ✅路径好人["..kw.."]"); return "Good" end end
    -- 注意：刻意排除"npc"关键词——它太宽泛
    for _, kw in ipairs(PATH_BAD) do if pl:find(kw, 1, true) then dp("  ❌路径坏人["..kw.."]"); return "Bad" end end
    
    -- 4. 无法判断 → 跳过
    dp("  ⚠️无法判断，跳过")
    return nil
end

-- ========== ESP ==========
local function isPlayer(c) if not c then return false end;for _, p in ipairs(Players:GetPlayers()) do if p.Character == c then return true end end;return false end

local function makeESP(c, nt)
    if not c or not c.Parent then return end; if isPlayer(c) then return end
    if ESPObjects[c] then return end
    local root = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChildOfClass("Part")
    if not root then return end
    local mc = Players.LocalPlayer and Players.LocalPlayer.Character
    local mr = mc and (mc:FindFirstChild("HumanoidRootPart") or mc:FindFirstChild("Torso"))
    if mr and root and (root.Position - mr.Position).Magnitude > Settings.MaxRange then return end
    
    local enabled = Settings.Enabled and (not Settings.BadOnly or nt == "Bad")
    local col = nt == "Good" and Color3.fromRGB(0, 255, 80) or Color3.fromRGB(255, 40, 40)
    
    local hl = tag(Instance.new("Highlight"))
    hl.Adornee = c; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.35; hl.OutlineTransparency = 0.15
    hl.FillColor = col; hl.OutlineColor = Color3.fromRGB(255,255,255); hl.Enabled = enabled; hl.Parent = CoreGui
    
    local head = c:FindFirstChild("Head") or root
    local bb = tag(Instance.new("BillboardGui"))
    bb.Adornee = head; bb.Size = UDim2.new(0, 180, 0, 60); bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true; bb.Enabled = enabled; bb.Parent = CoreGui
    
    local bg = tag(Instance.new("Frame"))
    bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency = 0.3; bg.BorderSizePixel = 0; bg.Parent = bb
    tag(Instance.new("UICorner")); bg.UICorner.CornerRadius = UDim.new(0,4)
    
    local lbl = tag(Instance.new("TextLabel"))
    lbl.Size = UDim2.new(1,-4,0.5,0); lbl.Position = UDim2.new(0,2,0,1)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = col; lbl.TextScaled = true
    lbl.Font = Enum.Font.SourceSansBold; lbl.Text = nt == "Good" and "👮 好人" or "💀 坏人"
    lbl.BorderSizePixel = 0; lbl.Parent = bg
    
    -- v12.6: Debug Mode — 头顶显示NPC原始名字
    local info = tag(Instance.new("TextLabel"))
    info.Size = UDim2.new(1,-4,0.4,0); info.Position = UDim2.new(0,2,0.5,2)
    info.BackgroundTransparency = 1; info.TextColor3 = Color3.fromRGB(220,220,220)
    info.TextScaled = true; info.Font = Enum.Font.SourceSans; info.Text = ""; info.BorderSizePixel = 0; info.Parent = bg
    
    if Settings.DebugMode then
        -- Debug模式: 显示原始名字
        local attrs = ""; pcall(function() for _, a in ipairs(c:GetAttributes()) do attrs = attrs..a.."="..tostring(c:GetAttribute(a)).." " end end)
        if c:FindFirstChildOfClass("Humanoid") then
            pcall(function() for _, a in ipairs(c:FindFirstChildOfClass("Humanoid"):GetAttributes()) do attrs = attrs..a.."="..tostring(c:FindFirstChildOfClass("Humanoid"):GetAttribute(a)).." " end end)
        end
        info.Text = c.Name .. (attrs ~= "" and (" | "..attrs) or "")
    else
        info.Text = ""
    end
    
    ESPObjects[c] = {HL=hl,BB=bb,LB=lbl,Inf=info,HD=head,RT=root,NT=nt}
    if nt == "Good" then Stat.G = Stat.G + 1 else Stat.B = Stat.B + 1 end
    Stat.S = Stat.S + 1; Tracked[c] = nt
end

local function remESP(c)
    if ESPObjects[c] then
        local o = ESPObjects[c]
        pcall(function() o.HL:Destroy() end); pcall(function() o.BB:Destroy() end)
        ESPObjects[c] = nil
        if o.NT == "Good" then Stat.G = math.max(0, Stat.G - 1) elseif o.NT == "Bad" then Stat.B = math.max(0, Stat.B - 1) end
