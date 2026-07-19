--[[
    机场安全透视 v14.9
    功能: NPC透视+行李箱检测 | 纯BillboardGui
    修复: 粒子用Scale坐标永不卡边界 + 回调直接刷新颜色
    作者: b站英吉利超入_
]]
local P=game:GetService("Players")
local U=game:GetService("UserInputService")
local W=game:GetService("Workspace")
local C=game:GetService("CoreGui")
local LP=P.LocalPlayer
local IM=U.TouchEnabled and not U.KeyboardEnabled
if not IM then pcall(function()IM=U.TouchEnabled and not U.MouseEnabled end)end

local function clean()
    local wc=0
    for _,g in ipairs(C:GetChildren())do
        if g:IsA("ScreenGui")then
            local n=g.Name
            if n:find("WindUI")then wc=wc+1;if wc>1 then pcall(function()g:Destroy()end)end
            elseif n=="A"or n:find("AirportESP")or n:find("ESP_Particles")then pcall(function()g:Destroy()end)end
        end
    end
end
clean()

local function rFind(inst,name)
    local f=inst:FindFirstChild(name)
    if f then return f end
    for _,c in ipairs(inst:GetChildren())do
        if c:IsA("Configuration")or c:IsA("Folder")then
            local r=rFind(c,name)
            if r then return r end
        end
    end
    return nil
end

local function scanProps(m)
    if not m then return nil end
    local pr=m:FindFirstChild("Properties")
    if not pr then return nil end
    local sv=rFind(pr,"StatusVariables")
    if sv then local h=rFind(sv,"Hostile");if h and h:IsA("BoolValue")and h.Value then return true end end
    local rv=rFind(pr,"RandomVariables")
    if rv then local c=rFind(rv,"ContrabandReal");if c and c:IsA("BoolValue")and c.Value then return true end
        local f=rFind(rv,"FakePassport");if f and f:IsA("BoolValue")and f.Value then return true end end
    return nil
end

local function classify(c)
    if not c then return"Good"end
    local nm=c.Name or"";local fp="";pcall(function()fp=c:GetFullName()end)
    local hum=c:FindFirstChildOfClass("Humanoid")
    if hum then
        for _,an in ipairs({"NPCType","Type","Faction","Team","Role"})do
            local v=nil;pcall(function()v=hum:GetAttribute(an)end)
            if v then local vs=tostring(v):lower()
                for _,g in ipairs({"agent","good","friendly","ally","police","guard","civilian","security"})do if vs:find(g,1,true)then return"Good"end end
                for _,b in ipairs({"enemy","bad","hostile","terrorist","criminal"})do if vs:find(b,1,true)then return"Bad"end end
            end
        end
    end
    local bad=scanProps(c);if bad~=nil then return bad and"Bad"or"Good"end
    local nl=nm:lower()
    for _,kw in ipairs({"警察","保安","警卫","police","guard","agent","officer","prisoner","store","npcstore","市民","商人"})do if nl:find(kw:lower(),1,true)then return"Good"end end
    for _,kw in ipairs({"恐怖","匪","敌人","坏","犯罪","terrorist","enemy","hostile","criminal","smuggler"})do if nl:find(kw:lower(),1,true)then return"Bad"end end
    local pl=fp:lower()
    for _,kw in ipairs({"agent","police","friendly","civilian","prisoner","store","jail"})do if pl:find(kw,1,true)then return"Good"end end
    for _,kw in ipairs({"enemy","terror","hostile","criminal","invader"})do if pl:find(kw,1,true)then return"Bad"end end
    return"Good"
end

local function classifyLuggage(lug)
    if not lug then return"Suspicious"end
    local pr=lug:FindFirstChild("Properties")
    if pr then
        local cb=rFind(pr,"Contraband")
        if cb and cb:IsA("BoolValue")then
            return cb.Value and"Dangerous"or"Safe"
        end
    end
    return"Suspicious"
end

local S={Enabled=false,BadOnly=false,ShowDist=false,ShowHP=false,Luggage=false,MaxRange=500,Theme="Dark",Particles=true,PColor=Color3.fromRGB(80,170,255)}
local H={}
local LG={}
local GC=0;local BC=0;local LC=0;local LDC=0;local LSC=0;local SC=0
local WN=nil;local WI=nil;local PC=nil;local CT={};local KB={};local TE={};local PS={};local PR=false;local PP=false;local CF="default"

-- NPC 头顶标签（纯BillboardGui，无Highlight）
local function makeNPC_ESP(c,nt)
    if not c or not c.Parent then return end
    for _,p in ipairs(P:GetPlayers())do if p.Character==c then return end end
    if H[c]then return end
    local hrp=c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Torso")or c:FindFirstChildOfClass("Part")
    if not hrp then return end
    if LP and LP.Character then
        local mp=LP.Character:FindFirstChild("HumanoidRootPart")or LP.Character:FindFirstChild("Torso")
        if mp and(hrp.Position-mp.Position).Magnitude>S.MaxRange then return end
    end
    local col=nt=="Good"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,40,40)
    local tag=nt=="Good"and"👮 好人"or"💀 坏人"
    local head=c:FindFirstChild("Head")or hrp
    local bb=Instance.new("BillboardGui");bb.Adornee=head;bb.Size=UDim2.new(0,220,0,56)
    bb.StudsOffset=Vector3.new(0,5,0);bb.AlwaysOnTop=true;bb.MaxDistance=S.MaxRange
    bb.Enabled=S.Enabled and(not S.BadOnly or nt=="Bad");bb.Parent=C
    local ob=Instance.new("Frame");ob.Size=UDim2.new(1,4,1,4);ob.Position=UDim2.new(0,-2,0,-2)
    ob.BackgroundColor3=Color3.fromRGB(255,255,255);ob.BackgroundTransparency=0.85;ob.BorderSizePixel=0;ob.Parent=bb
    Instance.new("UICorner",ob).CornerRadius=UDim.new(0,8)
    local bg=Instance.new("Frame");bg.Size=UDim2.new(1,0,1,0);bg.BackgroundColor3=Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency=0.55;bg.BorderSizePixel=0;bg.Parent=bb
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
    local lb=Instance.new("TextLabel");lb.Size=UDim2.new(1,-6,1,0);lb.Position=UDim2.new(0,3,0,0)
    lb.BackgroundTransparency=1;lb.TextColor3=col;lb.Font=Enum.Font.SourceSansBold
    lb.TextScaled=true;lb.Text=tag;lb.BorderSizePixel=0;lb.Parent=bg
    H[c]={bb=bb,lb=lb,hrp=hrp,nt=nt,tag=tag}
    SC=SC+1;if nt=="Good"then GC=GC+1 else BC=BC+1 end
end

local function makeLuggage_ESP(lug,lt)
    if not lug or not lug.Parent then return end
    if LG[lug]then return end
    local pp=nil;pcall(function()pp=lug.PrimaryPart end)
    if not pp then for _,c in ipairs(lug:GetDescendants())do if c:IsA("BasePart")then pp=c;break end end end
    if not pp then return end
    local col=lt=="Dangerous"and Color3.fromRGB(255,40,40)or(lt=="Safe"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,180,40))
    local tag=lt=="Dangerous"and"💣 危险行李"or(lt=="Safe"and"🧳 安全行李"or"❓ 可疑行李")
    local bb=Instance.new("BillboardGui");bb.Adornee=pp;bb.Size=UDim2.new(0,220,0,56)
    bb.StudsOffset=Vector3.new(0,3,0);bb.AlwaysOnTop=true;bb.MaxDistance=S.MaxRange
    bb.Enabled=S.Luggage;bb.Parent=C
    local ob=Instance.new("Frame");ob.Size=UDim2.new(1,4,1,4);ob.Position=UDim2.new(0,-2,0,-2)
    ob.BackgroundColor3=Color3.fromRGB(255,255,255);ob.BackgroundTransparency=0.85;ob.BorderSizePixel=0;ob.Parent=bb
    Instance.new("UICorner",ob).CornerRadius=UDim.new(0,8)
    local bg=Instance.new("Frame");bg.Size=UDim2.new(1,0,1,0);bg.BackgroundColor3=Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency=0.55;bg.BorderSizePixel=0;bg.Parent=bb
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
    local lb=Instance.new("TextLabel");lb.Size=UDim2.new(1,-6,1,0);lb.Position=UDim2.new(0,3,0,0)
    lb.BackgroundTransparency=1;lb.TextColor3=col;lb.Font=Enum.Font.SourceSansBold
    lb.TextScaled=true;lb.Text=tag;lb.BorderSizePixel=0;lb.Parent=bg
    LG[lug]={bb=bb,lb=lb,nt=lt,tag=tag}
    LC=LC+1;if lt=="Dangerous"then LDC=LDC+1 elseif lt=="Safe"then LSC=LSC+1 end
end

local function doScan()
    local seen={}
    for _,o in ipairs(W:GetDescendants())do
        if o:IsA("Humanoid")then
            local c=o.Parent
            if c and c:IsA("Model")and not seen[c]then
                seen[c]=true
                local isPl=false
                for _,p in ipairs(P:GetPlayers())do if p.Character==c then isPl=true;break end end
                if not isPl then local nt=classify(c);makeNPC_ESP(c,nt)end
            end
        end
    end
end

local function doLuggageScan()
    local seen={}
    local wsf=W:FindFirstChild("WorkspaceScriptable")
    if wsf then
        local sto=wsf:FindFirstChild("Storage")
        if sto then
            local ns=sto:FindFirstChild("NormalStorage")
            if ns then
                for _,fn in ipairs({"LuggageWorkspace","LuggageOpenWorkspace","LuggageEndWorkspace"})do
                    local fw=ns:FindFirstChild(fn)
                    if fw then
                        for _,lug in ipairs(fw:GetDescendants())do
                            if lug:IsA("Model")and not seen[lug]then
                                seen[lug]=true
                                local lt=classifyLuggage(lug);makeLuggage_ESP(lug,lt)
                            end
                        end
                    end
                end
            end
        end
    end
    if LC==0 then
        for _,o in ipairs(W:GetDescendants())do
            if o:IsA("Model")and o.Name=="OpenableLuggage"and not seen[o]then
                seen[o]=true
                local lt=classifyLuggage(o);makeLuggage_ESP(o,lt)
            end
        end
    end
end

local function refreshESP()
    for c,o in pairs(H)do
        if not c or not c.Parent then pcall(function()o.bb:Destroy()end);H[c]=nil
        else
            local en=S.Enabled and(not S.BadOnly or o.nt=="Bad")
            if o.bb then o.bb.Enabled=en end
            if o.lb then
                local txt=o.tag
                if S.ShowDist and LP.Character then
                    local mp=LP.Character:FindFirstChild("HumanoidRootPart")
                    if mp and o.hrp then txt=txt.."\n"..math.floor((o.hrp.Position-mp.Position).Magnitude+0.5).."m"end
                end
                if S.ShowHP then local h2=c:FindFirstChildOfClass("Humanoid")
                    if h2 then txt=txt.."\nHP:"..math.floor(h2.Health+0.5).."/"..math.floor(h2.MaxHealth+0.5)end end
                o.lb.Text=txt
            end
        end
    end
    for lug,o in pairs(LG)do
        if not lug or not lug.Parent then pcall(function()o.bb:Destroy()end);LG[lug]=nil
        else
            if o.bb then o.bb.Enabled=S.Luggage end
        end
    end
end

local function updateStats()
    GC=0;BC=0;SC=0;LC=0;LDC=0;LSC=0
    for _,o in pairs(H)do SC=SC+1;if o.nt=="Good"then GC=GC+1 else BC=BC+1 end end
    for _,o in pairs(LG)do LC=LC+1;if o.nt=="Dangerous"then LDC=LDC+1 elseif o.nt=="Safe"then LSC=LSC+1 end end
    pcall(function()
        if TE.GP then TE.GP:SetTitle("🟢 好人: "..GC)end
        if TE.BP then TE.BP:SetTitle("🔴 坏人: "..BC)end
        if TE.LP then TE.LP:SetTitle("🧳 行李: "..LC.." (💣"..LDC.." 🟢"..LSC..")")end
        if TE.SP then TE.SP:SetTitle("📊 总计: "..SC)end
    end)
end

-- 粒子系统：用Scale坐标（0~1范围），永不卡边界
local function updateParticleColors()
    local col=S.PColor
    for _,p in ipairs(PS)do
        if p.F and p.F.Parent then
            p.F.BackgroundColor3=col
        end
    end
end

local function mkParts()
    if not PP then return end
    if PC then return end
    task.wait(0.5)
    local sg=Instance.new("ScreenGui");sg.Name="ESP_Particles";sg.ResetOnSpawn=false
    sg.DisplayOrder=999999;sg.IgnoreGuiInset=true;sg.Parent=C
    PC=Instance.new("Frame");PC.Size=UDim2.new(1,0,1,0);PC.BackgroundTransparency=1
    PC.BorderSizePixel=0;PC.Active=false;PC.Parent=sg
    local col=S.PColor
    for i=1,50 do
        local d=Instance.new("Frame");local sz=math.random(5,10);d.Size=UDim2.new(0,sz,0,sz)
        -- 用Scale坐标（0.2~0.8范围），永远在容器内部
        local sx=0.2+math.random()*0.6;local sy=0.2+math.random()*0.6
        d.Position=UDim2.new(sx,0,sy,0)
        d.BackgroundColor3=col;d.BackgroundTransparency=0.3+math.random()*0.5;d.BorderSizePixel=0;d.Parent=PC
        Instance.new("UICorner",d).CornerRadius=UDim.new(0,10)
        local a=math.random()*6.28;local sp=0.0008+math.random()*0.002 -- Scale/帧速度
        table.insert(PS,{F=d,Sx=sx,Sy=sy,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})
    end
    PR=true
    task.spawn(function()
        local t=0
        while PR and PC do t=t+0.03
            pcall(function()
                local curCol=S.PColor
                for _,p in ipairs(PS)do
                    if p.F and p.F.Parent then
                        local sx=math.max(0.05,math.min(0.95,p.Sx+p.Vx))
                        local sy=math.max(0.05,math.min(0.95,p.Sy+p.Vy))
                        -- 如果被边界限制，说明撞墙了→反弹
                        if sx>=0.95 or sx<=0.05 then p.Vx=-p.Vx end
                        if sy>=0.95 or sy<=0.05 then p.Vy=-p.Vy end
                        p.Sx=sx;p.Sy=sy
                        p.F.Position=UDim2.new(sx,0,sy,0)
                        -- 颜色每帧跟踪S.PColor
                        if curCol~=p.F.BackgroundColor3 then p.F.BackgroundColor3=curCol end
                        p.F.BackgroundTransparency=0.3+math.sin(t*0.8+p.Ph)*0.4
                        local bs=math.max(2,p.Sz+math.sin(t+p.Ph)*1.5);p.F.Size=UDim2.new(0,bs,0,bs)
                    end
                end
            end)
            task.wait(0.03)
        end
    end)
end

local function killParts()
    PR=false;if PC then pcall(function()local p=PC.Parent;if p then p:Destroy()end end);PC=nil end;PS={}
end

local function gtc(n)
    if not n then return Color3.fromRGB(80,170,255)end;local l=n:lower()
    local m={dark=Color3.fromRGB(80,170,255),light=Color3.fromRGB(60,130,210),rose=Color3.fromRGB(255,130,170),plant=Color3.fromRGB(70,210,130),ocean=Color3.fromRGB(60,190,240),sunset=Color3.fromRGB(255,160,70),midnight=Color3.fromRGB(130,100,240),forest=Color3.fromRGB(60,180,90),lavender=Color3.fromRGB(190,140,255),coral=Color3.fromRGB(255,140,90),mint=Color3.fromRGB(80,230,190),sky=Color3.fromRGB(100,190,255),blood=Color3.fromRGB(230,90,80),lemon=Color3.fromRGB(230,210,70),cyber=Color3.fromRGB(0,235,210)}
    if m[l]then return m[l]end
    if l:find("dark")then return Color3.fromRGB(80,170,255)end
    if l:find("rose")or l:find("pink")then return Color3.fromRGB(255,130,170)end
    if l:find("plant")or l:find("green")then return Color3.fromRGB(70,210,130)end
    if l:find("ocean")or l:find("blue")or l:find("sky")then return Color3.fromRGB(60,190,240)end
    if l:find("sunset")or l:find("orange")then return Color3.fromRGB(255,160,70)end
    if l:find("midnight")or l:find("purple")or l:find("lavender")then return Color3.fromRGB(130,100,240)end
    if l:find("blood")or l:find("red")then return Color3.fromRGB(230,90,80)end
    if l:find("lemon")or l:find("yellow")then return Color3.fromRGB(230,210,70)end
    return Color3.fromRGB(80,170,255)
end

local function makeWindow()
    local ok2,w=pcall(function()return WI:CreateWindow({
        Title="机场安全透视",Author="b站英吉利超入_",Icon="solar:shield-warning-bold",
        Size=UDim2.fromOffset(750,520),ToggleKey=Enum.KeyCode.RightShift,
        Folder="airport-esp",Acrylic=true,Transparent=true,Resizable=false,
        SideBarWidth=180,ScrollBarEnabled=true,HideSearchBar=true,
        OpenButton={Title="打开透视",Scale=0.5,Enabled=true,OnlyMobile=IM,Draggable=true,
            Color=ColorSequence.new(Color3.fromRGB(0,255,100),Color3.fromRGB(0,200,255)),
            CornerRadius=UDim.new(1,0),StrokeThickness=3},
        OnClose=function()S.Enabled=false;S.Luggage=false;if CT.ESP then CT.ESP:Set(false)end;if CT.LT then CT.LT:Set(false)end;refreshESP();killParts()end,
        OnOpen=function()if S.Particles then task.spawn(function()task.wait(0.5);mkParts()end)end end
    })end)
    if not ok2 or not w then return end
    WN=w
    
    local mt=WN:Tab({Title="主控面板",Icon="solar:slider-vertical-bold"})
    CT.ESP=mt:Toggle({Flag="ESP",Title="透视开关",Value=false,
        Callback=function(v)S.Enabled=v;refreshESP();if v then task.spawn(doScan)end end})
    CT.BO=mt:Toggle({Flag="BadOnly",Title="仅显示坏人",Value=false,Callback=function(v)S.BadOnly=v;refreshESP()end})
    mt:Divider()
    CT.LT=mt:Toggle({Flag="Luggage",Title="🧳 行李箱检测",Value=false,
        Callback=function(v)S.Luggage=v;refreshESP();if v then task.spawn(doLuggageScan)end end})
    mt:Divider()
    CT.DT=mt:Toggle({Flag="Dist",Title="显示距离",Value=false,Callback=function(v)S.ShowDist=v end})
    CT.HT=mt:Toggle({Flag="Health",Title="显示血量",Value=false,Callback=function(v)S.ShowHP=v end})
    mt:Divider()
    CT.RS=mt:Slider({Flag="Range",Title="最大探测距离",Step=50,Value={Min=50,Max=1000,Default=500},Width=200,IsTextbox=true,Callback=function(v)S.MaxRange=v end})
    
    local ft=WN:Tab({Title="功能设置",Icon="solar:settings-bold"})
    CT.EK=ft:Keybind({Flag="ESPK",Title="透视开关快捷键",Value="",Callback=function(k)KB.ESP=k end})
    CT.BK=ft:Keybind({Flag="BadK",Title="仅坏人快捷键",Value="",Callback=function(k)KB.BadOnly=k end})
    
    local ut=WN:Tab({Title="UI设置",Icon="solar:monitor-bold"})
    CT.WK=ut:Keybind({Flag="WinK",Title="窗口开关",Value="RightShift",Callback=function(k)KB.Win=k end})
    ut:Divider()
    CT.PT=ut:Toggle({Flag="PT",Title="粒子背景",Value=true,Callback=function(v)S.Particles=v;if v then task.spawn(mkParts)else killParts()end end})
    ut:Divider()
    CT.AT=ut:Toggle({Flag="AT",Title="毛玻璃(Acrylic)",Value=true,Callback=function(v)pcall(function()WI:ToggleAcrylic(v)end)end})
    CT.TT=ut:Toggle({Flag="TT",Title="透明背景(Transparent)",Value=true,Callback=function(v)pcall(function()if WN then pcall(function()WN:ToggleTransparency(v)end)end end)end})
    ut:Divider()
    local allT={};pcall(function()allT=WI:GetThemes()end);local tn={};for n,_ in pairs(allT)do table.insert(tn,n)end;table.sort(tn)
    CT.TD=ut:Dropdown({Flag="TD",Title="选择主题",Values=tn,Value="Dark",
        Callback=function(sl)if sl and type(sl)=="string"then
            S.Theme=sl;WI:SetTheme(sl);S.PColor=gtc(sl)
            -- 立即刷新所有粒子颜色
            updateParticleColors()
        end end})
    
    local st=WN:Tab({Title="信息统计",Icon="solar:chart-bold"})
    TE.GP=st:Paragraph({Title="🟢 好人: 0"});TE.BP=st:Paragraph({Title="🔴 坏人: 0"})
    TE.LP=st:Paragraph({Title="🧳 行李: 0"});TE.SP=st:Paragraph({Title="📊 总计: 0"})
    
    local ct=WN:Tab({Title="配置管理",Icon="solar:diskette-bold"})
    local cni=ct:Input({Flag="CN",Title="配置名称",Value="default",Icon="solar:file-text-bold",Callback=function(v)CF=v end});ct:Space()
    local CM=WN.ConfigManager;local AC={};pcall(function()AC=CM:AllConfigs()end)
    local DV=nil;pcall(function()for _,v in ipairs(AC)do if v=="default"then DV="default";break end end end)
    local ACD=ct:Dropdown({Title="已有配置",Values=AC,Value=DV,Callback=function(v)if v then CF=v;cni:Set(v)end end});ct:Space()
    ct:Button({Title="💾 保存",Icon="solar:check-circle-bold",Justify="Center",Color=Color3.fromHex("#305dff"),
        Callback=function()if not CM then return end;local c=CM:Config(CF);if c and c:Save()then WI:Notify({Title="✅ 已保存",Content="配置 '"..CF.."'",Duration=3,Icon="solar:check-circle-bold"});ACD:Refresh(CM:AllConfigs())end end});ct:Space()
    ct:Button({Title="📂 加载",Icon="solar:refresh-circle-bold",Justify="Center",Color=Color3.fromHex("#10C550"),
        Callback=function()if not CM then return end;local c=CM:CreateConfig(CF,false);if c and c:Load()then WI:Notify({Title="✅ 已加载",Content="配置 '"..CF.."'",Duration=3,Icon="solar:refresh-circle-bold"})end end});ct:Space()
    ct:Button({Title="🗑️ 删除",Icon="solar:trash-bin-trash-bold",Justify="Center",Color=Color3.fromHex("#ff3040"),
        Callback=function()if not CM then return end;local c=CM:Config(CF);if c and c:Delete()then WI:Notify({Title="🗑️ 已删除",Content="配置 '"..CF.."'",Duration=3,Icon="solar:trash-bin-trash-bold"});ACD:Refresh(CM:AllConfigs())end end})
    task.spawn(function()task.wait(1);pcall(function()CM:CreateConfig("default",true)end);task.spawn(mkParts)end)
    
    local at=WN:Tab({Title="关于",Icon="solar:info-square-bold"})
    at:Paragraph({Title="机场安全透视 v14.9",Desc="粒子Scale坐标+回调直接刷新颜色"})
    at:Divider();at:Paragraph({Title="👤 作者",Desc="b站英吉利超入_"})
    at:Divider();at:Paragraph({Title="💡 使用",Desc=IM and"手机: 点击悬浮按钮"or"PC: RightShift打开菜单"})
    
    U.InputBegan:Connect(function(i,g)if g then return end;if i.UserInputType~=Enum.UserInputType.Keyboard then return end;local k=i.KeyCode.Name
        if KB.ESP and KB.ESP~=""and k==KB.ESP then S.Enabled=not S.Enabled;if CT.ESP then CT.ESP:Set(S.Enabled)end;refreshESP();if S.Enabled then task.spawn(doScan)end end
        if KB.BadOnly and KB.BadOnly~=""and k==KB.BadOnly then S.BadOnly=not S.BadOnly;if CT.BO then CT.BO:Set(S.BadOnly)end;refreshESP()end end)
    
    task.spawn(function()while true do task.wait(3);pcall(function()doScan();doLuggageScan();refreshESP();updateStats()end)end end)
end

local ok,rv=pcall(function()return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()end)
if ok and rv then
    WI=rv;WI:SetTheme("Dark");S.PColor=gtc("Dark")
    WI:Popup({Title="机场安全透视 v14.9",Icon="solar:info-square-bold",
        Content="👁 NPC透视+分类\n🧳 行李Contraband检测\n📛 纯BillboardGui无重叠\n🌀 粒子Scale坐标永不卡边\n⚠️ 功能默认关闭",
        Buttons={{Title="取消",Callback=function()end,Variant="Tertiary"},
            {Title="确认加载",Icon="solar:arrow-right-bold",Callback=function()
                PP=true
                WI:Notify({Title="✅ 已加载",Content="按RightShift打开菜单",Duration=4,Icon="solar:bell-bold"})
                task.spawn(makeWindow)
            end,Variant="Primary"}}})
    while not PP do task.wait(0.5)end
else
    warn("WindUI加载失败")
end