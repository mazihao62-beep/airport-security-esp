--[[
    机场安全透视脚本 v12.7
    作者: b站英吉利超入_
    
    v12.7 修复4个Bug:
    1. NPC检测不到 → 分成2次扫描(先快速扫头/根部件，再详细查Humanoid属性)
    2. 无法判断 → 默认坏人（宁可错杀不可放过）
    3. 悬浮按钮 → 立即创建无需等待+WN就绪后再绑定点击
    4. 透明背景 → 改用 CreateWindow 时控制 +/- 窗口重建
]]
local Players=game:GetService("Players");local UIS=game:GetService("UserInputService");local WS=game:GetService("Workspace");local CG=game:GetService("CoreGui");local VIM=game:GetService("VirtualInputManager");local RS=game:GetService("RunService")
local IM=UIS.TouchEnabled and not UIS.KeyboardEnabled;if not IM then pcall(function()IM=UIS.TouchEnabled and not UIS.MouseEnabled end)end
local TAG="AirportESP"
local function clean()
    local c=0;pcall(function()
        for _,v in ipairs(CG:GetDescendants())do local ok,a=pcall(function()return v:GetAttribute(TAG)end);if ok and a then pcall(function()v:Destroy()end);c=c+1 end end
        local wc=0;for _,g in ipairs(CG:GetChildren())do if g:IsA("ScreenGui")then local n=g.Name;if n:find("WindUI")then wc=wc+1;if wc>1 then pcall(function()g:Destroy()end);c=c+1 end elseif n:find("AirportESP")then pcall(function()g:Destroy()end);c=c+1 end end end
    end);if c>0 then print("[清理]"..c.."个")end
end
clean()
_G.CleanupESP=function()clean()end
local function tg(v)if v then pcall(function()v:SetAttribute(TAG,true)end)end;return v end

local S={Enabled=false,BadOnly=false,ShowDistance=false,ShowHealth=false,MaxRange=500,Particles=true,CurrentTheme="Dark",ParticleColor=Color3.fromRGB(80,170,255),DebugMode=false}
local TC={dark=Color3.fromRGB(80,170,255),light=Color3.fromRGB(60,130,210),rose=Color3.fromRGB(255,130,170),plant=Color3.fromRGB(70,210,130),ocean=Color3.fromRGB(60,190,240),sunset=Color3.fromRGB(255,160,70),midnight=Color3.fromRGB(130,100,240),forest=Color3.fromRGB(60,180,90),lavender=Color3.fromRGB(190,140,255),coral=Color3.fromRGB(255,140,90),mint=Color3.fromRGB(80,230,190),peanut=Color3.fromRGB(210,180,90),sky=Color3.fromRGB(100,190,255),blood=Color3.fromRGB(230,90,80),lemon=Color3.fromRGB(230,210,70),cyber=Color3.fromRGB(0,235,210)}
local function n2c(n)local h=0;for i=1,#n do h=h+string.byte(n,i)end;return Color3.fromRGB(math.floor(80+math.sin(h*137.5)*0.5*175+0.5),math.floor(100+math.sin(h*73.1+50)*0.5*155+0.5),math.floor(130+math.sin(h*41.7)*0.5*125+0.5))end
local function gtc(n)
    if not n then return Color3.fromRGB(80,170,255)end;local l=n:lower()
    local t=nil;pcall(function()t=WindUI:GetThemes()end)
    if t and t[n]then local d=t[n];local c=nil;pcall(function()if type(d)=="table"then c=d.Primary or d.Accent or d.Color or d.Main end end);if c then return c end end
    local m=TC[l];if m then return m end
    if l:find("dark")or l:find("night")then return Color3.fromRGB(80,170,255)end;if l:find("light")then return Color3.fromRGB(60,130,210)end;if l:find("rose")or l:find("pink")then return Color3.fromRGB(255,130,170)end;if l:find("plant")or l:find("green")or l:find("forest")or l:find("mint")then return Color3.fromRGB(70,210,130)end;if l:find("ocean")or l:find("blue")or l:find("sky")then return Color3.fromRGB(60,190,240)end;if l:find("sunset")or l:find("orange")or l:find("coral")then return Color3.fromRGB(255,160,70)end;if l:find("midnight")or l:find("purple")or l:find("lavender")then return Color3.fromRGB(130,100,240)end;if l:find("blood")or l:find("red")then return Color3.fromRGB(230,90,80)end;if l:find("lemon")or l:find("yellow")then return Color3.fromRGB(230,210,70)end;return n2c(n)
end

local EO={};local TR={};local IS=false;local WN=nil;local FB=nil;local PC=nil;local ST={G=0,B=0,S=0};local CT={};local KB={};local PP=false;local TE={};local CF="default";local DL={}
local PR=false;local PS={};local WF=nil;local PH=nil

-- Bug3修复: mt()轮询等待WN就绪
local function mt()
    local tries=0;while not WN and tries<20 do task.wait(0.1);tries=tries+1 end
    if WN then pcall(function()VIM:SendKeyEvent(true,Enum.KeyCode.RightShift,false,game);task.wait(0.05);VIM:SendKeyEvent(false,Enum.KeyCode.RightShift,false,game)end)end
end
local function dp(m)table.insert(DL,m);if #DL>20 then table.remove(DL,1)end;print("[D]"..m)end

-- 粒子
local function fw()WF=nil;pcall(function()for _,g in ipairs(CG:GetChildren())do if g:IsA("ScreenGui")then for _,f in ipairs(g:GetChildren())do if f:IsA("Frame")and f:FindFirstChild("UICorner")then local u=f:FindFirstChild("UICorner");if u and u.CornerRadius==UDim.new(0,8)and f.AbsoluteSize.X>700 then WF=f;return end end end end end end);if not WF then pcall(function()for _,g in ipairs(CG:GetChildren())do if g:IsA("ScreenGui")and g.Name:find("WindUI")then local bs=0;local b=nil;for _,f in ipairs(g:GetChildren())do if f:IsA("Frame")and f.AbsoluteSize.X>bs then bs=f.AbsoluteSize.X;b=f end end;if b then WF=b end end end end)end;return WF end
local function cp()
    if PC then pcall(function()PC:Destroy()end);PC=nil end;PS={};PR=false;if PH then pcall(function()PH:Disconnect()end);PH=nil end;if not S.Particles then return end;fw()
    if not WF then task.spawn(function()task.wait(1);fw();if WF then cp()end end);return end
    pcall(function()
        local sg=Instance.new("ScreenGui");sg.Name="AirportESP_PC";sg.DisplayOrder=-9999;sg.ResetOnSpawn=false;sg.Parent=CG;tg(sg)
        PC=Instance.new("Frame");PC.BackgroundTransparency=1;PC.BorderSizePixel=0;PC.ClipsDescendants=true;PC.Parent=sg;tg(PC)
        local p=WF.AbsolutePosition;local s=WF.AbsoluteSize;PC.Position=UDim2.fromOffset(p.X,p.Y);PC.Size=UDim2.fromOffset(s.X,s.Y)
        PH=RS.Heartbeat:Connect(function()if not PC or not PC.Parent then if PH then PH:Disconnect();PH=nil end;return end;if WF and WF.Parent then local a=WF.AbsolutePosition;local b=WF.AbsoluteSize;PC.Position=UDim2.fromOffset(a.X,a.Y);PC.Size=UDim2.fromOffset(b.X,b.Y);PC.Visible=WF.Visible else PC.Visible=false;fw()end end)
        local col=gtc(S.CurrentTheme);local w=s.X;local h=s.Y
        for i=1,50 do local d=Instance.new("Frame");local sz=math.random(4,8);d.Size=UDim2.new(0,sz,0,sz);d.Position=UDim2.fromOffset(math.random(10,math.max(20,w-10)),math.random(10,math.max(20,h-10)));d.BackgroundColor3=col;d.BackgroundTransparency=0.4+math.random()*0.4;d.BorderSizePixel=0;d.ZIndex=0;d.Parent=PC;tg(d);local cn=Instance.new("UICorner");cn.CornerRadius=UDim.new(0,10);cn.Parent=d;local a=math.random()*6.28;local sp=0.08+math.random()*0.2;table.insert(PS,{F=d,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})end
        PR=true
        task.spawn(function()local t=0;while PR and PC and PC.Parent do t=t+0.03;pcall(function()local cw=PC.AbsoluteSize.X;local ch=PC.AbsoluteSize.Y;if cw<=0 or ch<=0 then task.wait(0.03);return end;for _,p in ipairs(PS)do if not p.F or not p.F.Parent then continue end;local x=p.F.Position.X.Offset+p.Vx;local y=p.F.Position.Y.Offset+p.Vy;local sz=p.F.AbsoluteSize.X;if x+sz>=cw then x=cw-sz;p.Vx=-p.Vx*0.95 elseif x<0 then x=0;p.Vx=-p.Vx*0.95 end;if y+sz>=ch then y=ch-sz;p.Vy=-p.Vy*0.95 elseif y<0 then y=0;p.Vy=-p.Vy*0.95 end;p.F.Position=UDim2.fromOffset(x,y);p.F.BackgroundTransparency=0.4+math.sin(t*0.8+p.Ph)*0.25;local bs=math.max(1,p.Sz+math.sin(t+p.Ph)*0.8);p.F.Size=UDim2.new(0,bs,0,bs)end end);task.wait(0.03)end end)
    end)
end
local function upc()local c=gtc(S.CurrentTheme);if not c or #PS==0 then return end;pcall(function()for _,p in ipairs(PS)do if p.F and p.F.Parent then p.F.BackgroundColor3=c end end end)end
local function dp2()PR=false;if PH then pcall(function()PH:Disconnect()end);PH=nil end;if PC then pcall(function()local p=PC.Parent;if p then pcall(function()p:Destroy()end)end end);PC=nil end;PS={}end

-- 分类器 (属性->名字->路径→默认坏人)
local AN={"NPCType","Type","Faction","Team","Role","Kind","Affiliation","Alignment","Side"}
local AG={"agent","good","friendly","ally","police","friend","guard","civilian","security","law","team"}
local AB={"enemy","bad","hostile","terrorist","criminal","danger","evil","suspect","threat","invader","rogue"}
local NG={"警察","保安","警卫","警","守卫","士兵","军官","特工","巡逻","安全","安保","护卫","卫兵","公安","武警","police","guard","agent","officer","soldier","patrol","cop","friendly","safety"}
local NB={"恐怖","匪徒","匪","敌人","坏","犯罪","袭击","暴徒","杀手","叛军","劫匪","歹徒","绑匪","terrorist","enemy","hostile","criminal","danger","suspect","invader","attacker"}
local PG={"agent","police","friendly","good","blue","safe","civilian","defender","guardian"}
local PB={"enemy","terror","hostile","criminal","danger","invader","attack","suspect"}

-- v12.7: 属性即检查Humanoid也检查Model本身
local function classify(c)
    if not c then return "Bad" end
    local nm=c.Name or"";local fp="";pcall(function()fp=c:GetFullName()end);dp(string.format("[%s] %s",nm,fp))
    -- 1. 属性(Model + Humanoid全查)
    local h=c:FindFirstChildOfClass("Humanoid")
    for _,obj in ipairs({c,h})do if obj then
        for _,an in ipairs(AN)do local v=nil;pcall(function()v=obj:GetAttribute(an)end);if v then local vs=tostring(v):lower();for _,g in ipairs(AG)do if vs:find(g,1,true)then dp("  A+ "..an.."="..tostring(v));return"Good"end end;for _,b in ipairs(AB)do if vs:find(b,1,true)then dp("  A- "..an.."="..tostring(v));return"Bad"end end end end
        pcall(function()for _,a in ipairs(obj:GetAttributes())do dp("  ATTR "..a.."="..tostring(obj:GetAttribute(a)))end end)
    end end
    -- 2. 名字
    local nl=nm:lower()
    for _,kw in ipairs(NG)do if nl:find(kw:lower(),1,true)then dp("  N+ "..kw);return"Good"end end
    for _,kw in ipairs(NB)do if nl:find(kw:lower(),1,true)then dp("  N- "..kw);return"Bad"end end
    -- 3. 路径
    local pl=fp:lower()
    for _,kw in ipairs(PG)do if pl:find(kw,1,true)then dp("  P+ "..kw);return"Good"end end
    for _,kw in ipairs(PB)do if pl:find(kw,1,true)then dp("  P- "..kw);return"Bad"end end
    -- 4. 无法判断 → 默认坏人 (v12.7改回: 宁可错杀)
    dp("  ? 默认坏人");return "Bad"
end

local function isP(c)if not c then return false end;for _,p in ipairs(Players:GetPlayers())do if p.Character==c then return true end end;return false end

-- v12.7: Bug1修复 - 高效扫描，先用FindFirstChild快速定位
local function sc()
    if IS then return end;IS=true;ST.G=0;ST.B=0;ST.S=0;dp("=====SCAN=====")
    local viewed={}
    pcall(function()
        -- 方法1: 扫所有Humanoid
        for _,o in ipairs(WS:GetDescendants())do
            if o:IsA("Humanoid")then
                local c=o.Parent;if c and not TR[c]and not isP(c)and not viewed[c]then
                    viewed[c]=true;local nt=classify(c)
                    if nt=="Good"then ST.G=ST.G+1 else ST.B=ST.B+1 end
                    if not EO[c]then me(c,nt)end
                end
            end
        end
        -- 方法2: 扫所有带Head的Model(没有Humanoid也能找到)
        for _,o in ipairs(WS:GetDescendants())do
            if o:IsA("BasePart")and o.Name=="Head"then
                local c=o.Parent
                if c and c:IsA("Model")and not TR[c]and not isP(c)and not viewed[c]then
                    viewed[c]=true;local nt=classify(c)
                    if nt=="Good"then ST.G=ST.G+1 else ST.B=ST.B+1 end
                    if not EO[c]then me(c,nt)end
                end
            end
        end
    end)
    dp(string.format("=====END G:%d B:%d=====",ST.G,ST.B));IS=false
end

local function bu()pcall(function()for _,s in ipairs(CG:GetDescendants())do if s:IsA("ScrollingFrame")then s.ScrollBarThickness=14;s.ScrollBarImageColor3=Color3.fromRGB(220,220,220);s.ScrollBarImageTransparency=0.1 end end end)end
task.spawn(function()while true do task.wait(3);bu()end end)

local function us()
    pcall(function()
        if TE.GP then TE.GP:SetTitle("🟢 好人: "..ST.G)end;if TE.BP then TE.BP:SetTitle("🔴 坏人: "..ST.B)end;if TE.SP then TE.SP:SetTitle("📊 总计: "..ST.S)end;if TE.SI then TE.SI:Set(IS and"📡 扫描中..."or"✅ 就绪")end
        if TE.DI then local ls={};for i=math.max(1,#DL-3),#DL do table.insert(ls,DL[i])end;TE.DI:Set(table.concat(ls,"\n"))end
        local mc=Players.LocalPlayer and Players.LocalPlayer.Character;local mr=mc and(mc:FindFirstChild("HumanoidRootPart")or mc:FindFirstChild("Torso"))
        for c,o in pairs(EO)do
            if not S.DebugMode and o.Inf then
                local pts={}
                if S.ShowDistance and mr and o.RT then table.insert(pts,math.floor((o.RT.Position-mr.Position).Magnitude+0.5).."m")end
                if S.ShowHealth then local h2=c:FindFirstChildOfClass("Humanoid");if h2 then table.insert(pts,"HP:"..math.floor(h2.Health+0.5).."/"..math.floor(h2.MaxHealth+0.5))end end
                o.Inf.Text=table.concat(pts," | ")
            else
                o.Inf.Text=""
            end
        end
    end)
end

-- 悬浮按钮创建 (v12.7: 立即创建，无需等待)
local function createFloatBtn()
    pcall(function()
        FB=tg(Instance.new("ScreenGui"));FB.Name="AirportESP_Btn";FB.ResetOnSpawn=false;FB.Parent=CG
        local btn=tg(Instance.new("ImageButton"));btn.Size=UDim2.new(0,50,0,50);btn.Position=UDim2.new(0.9,-25,0.8,-25);btn.BackgroundColor3=Color3.fromRGB(0,180,80);btn.BackgroundTransparency=0.2;btn.BorderSizePixel=0;btn.Parent=FB
        tg(Instance.new("UICorner"));btn.UICorner.CornerRadius=UDim.new(0,25)
        local t=tg(Instance.new("TextLabel"));t.Size=UDim2.new(1,0,1,0);t.BackgroundTransparency=1;t.Text="👁";t.TextScaled=true;t.Font=Enum.Font.SourceSansBold;t.TextColor3=Color3.fromRGB(255,255,255);t.Parent=btn
        local d,ds,sp=false,nil,nil
        btn.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then d=true;ds=i.Position;sp=btn.Position end end)
        btn.InputChanged:Connect(function(i)if d and(i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement)then local nx=sp.X.Scale+(i.Position.X-ds.X)/800;local ny=sp.Y.Scale+(i.Position.Y-ds.Y)/600;nx=math.max(0.02,math.min(0.95,nx));ny=math.max(0.02,math.min(0.95,ny));btn.Position=UDim2.new(nx,0,ny,0)end end)
        btn.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end end)
        btn.MouseButton1Click:Connect(mt)
    end)
end
createFloatBtn() -- 立即创建

-- WindUI
local WI=nil;local ok,rv=pcall(function()return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()end)
if ok and rv then
    WI=rv;pcall(function()WI:SetTheme("Dark")end);S.ParticleColor=gtc("Dark")
    WI:Popup({Title="机场安全透视 v12.7",Icon="solar:info-square-bold",Content="👁 透视高亮 + 头顶标签\n🔍 双扫描: Humanoid+Head全覆盖\n⚡ 快速检测 默认标记坏人\n⚠️ 所有功能默认关闭",
        Buttons={{Title="取消",Callback=function()end,Variant="Tertiary"},{Title="确认加载",Icon="solar:arrow-right-bold",Callback=function()PP=true;pcall(function()WI:Notify({Title="✅ 已加载",Content="按RightShift打开菜单",Duration=4,Icon="solar:bell-bold"})end);task.spawn(function()cw();task.wait(1);sc()end)end,Variant="Primary"}}})
    task.spawn(function()
        while not PP do task.wait(0.5)end;task.wait(0.5);bu()
        task.spawn(function()while true do pcall(function()for c,_ in pairs(EO)do if not c or not c.Parent then local o=EO[c];if o then pcall(function()o.HL:Destroy()end);pcall(function()o.BB:Destroy()end);EO[c]=nil;TR[c]=nil;ST.G=0;ST.B=0;ST.S=0 end end end;if S.Enabled and not IS then sc()end end);task.wait(3)end end)
        task.spawn(function()while true do pcall(function()us()end);task.wait(0.5)end end)
        UIS.InputBegan:Connect(function(i,g)if g then return end;if i.UserInputType~=Enum.UserInputType.Keyboard then return end;local kn=i.KeyCode.Name
            if KB.ESP and KB.ESP~=""and kn==KB.ESP then S.Enabled=not S.Enabled;pcall(function()if CT.ESP then CT.ESP:Set(S.Enabled)end end);for _,o in pairs(EO)do local s=S.Enabled and(not S.BadOnly or o.NT=="Bad");if o.HL then o.HL.Enabled=s end;if o.BB then o.BB.Enabled=s end end;if S.Enabled and not IS then sc()end end
            if KB.BadOnly and KB.BadOnly~=""and kn==KB.BadOnly then S.BadOnly=not S.BadOnly;pcall(function()if CT.BO then CT.BO:Set(S.BadOnly)end end);for _,o in pairs(EO)do local s=S.Enabled and(not S.BadOnly or o.NT=="Bad");if o.HL then o.HL.Enabled=s end;if o.BB then o.BB.Enabled=s end end end end)
    end)

    function cw()
        if WN then return end;local ok2,w=pcall(function()return WI:CreateWindow({Title="机场安全透视",Author="b站英吉利超入_",Icon="solar:shield-warning-bold",Size=UDim2.fromOffset(750,520),ToggleKey=Enum.KeyCode.RightShift,Folder="airport-esp",Acrylic=true,Transparent=true,Resizable=false,SideBarWidth=180,ScrollBarEnabled=true,HideSearchBar=true})end)
        if not ok2 or not w then print("[错误] 窗口创建失败");return end;WN=w;pcall(function()WI.TransparencyValue=0.22 end)
        -- Bug4: 透明控制
        local trState=true
        CT.TT=ut:Toggle({Flag="TransToggle",Title="透明背景",Value=true,Callback=function(v)
            trState=v
            if v then pcall(function()WI.TransparencyValue=0.22 end)
            else pcall(function()WI.TransparencyValue=0 end)end
        end})
        task.spawn(function()local wv=nil;while WN do task.wait(0.5);pcall(function()local ok3,v=pcall(function()return WN.Visible end);if ok3 then if wv==nil then wv=v end;if wv~=v then if v then if S.Particles then cp()end else dp2()end;wv=v end end end)end end)

        local mt=WN:Tab({Title="主控面板",Icon="solar:slider-vertical-bold"})
        mt:Paragraph({Title="👁 透视控制"})
        CT.ESP=mt:Toggle({Flag="ESPToggle",Title="透视开关",Value=false,Callback=function(v)S.Enabled=v;for _,o in pairs(EO)do local s=v and(not S.BadOnly or o.NT=="Bad");if o.HL then o.HL.Enabled=s end;if o.BB then o.BB.Enabled=s end end;if v and not IS then sc()end end})
        CT.BO=mt:Toggle({Flag="BadOnlyToggle",Title="仅显示坏人",Value=false,Callback=function(v)S.BadOnly=v;for _,o in pairs(EO)do local s=S.Enabled and(not v or o.NT=="Bad");if o.HL then o.HL.Enabled=s end;if o.BB then o.BB.Enabled=s end end end})
        mt:Divider();mt:Paragraph({Title="📐 显示设置"})
        CT.DT=mt:Toggle({Flag="DistToggle",Title="显示距离",Value=false,Callback=function(v)S.ShowDistance=v end})
        CT.HT=mt:Toggle({Flag="HealthToggle",Title="显示血量",Value=false,Callback=function(v)S.ShowHealth=v end});mt:Divider()
        CT.RS=mt:Slider({Flag="RangeSlider",Title="最大探测距离",Step=50,Value={Min=50,Max=1000,Default=500},Width=200,IsTextbox=true,Callback=function(v)S.MaxRange=v end})
        mt:Divider();CT.DM=mt:Toggle({Flag="DebugToggle",Title="Debug 模式",Value=false,Callback=function(v)S.DebugMode=v end})

        local ft=WN:Tab({Title="功能设置",Icon="solar:settings-bold"})
        ft:Paragraph({Title="🔑 快捷键"});CT.EK=ft:Keybind({Flag="ESPKeybind",Title="透视开关",Value="",Callback=function(k)KB.ESP=k end});CT.BK=ft:Keybind({Flag="BadKeybind",Title="仅坏人模式",Value="",Callback=function(k)KB.BadOnly=k end})

        local ut=WN:Tab({Title="UI设置",Icon="solar:monitor-bold"})
        ut:Paragraph({Title="⚙️ 界面"});CT.WK=ut:Keybind({Flag="WinKeybind",Title="窗口开关",Value="RightShift",Callback=function(k)KB.Window=k;if WN then pcall(function()WN:SetToggleKey(Enum.KeyCode[k])end)end end})
        CT.FB=ut:Toggle({Flag="FloatBtn",Title="悬浮按钮",Value=true,Callback=function(v)if FB then FB.Enabled=v end end})
        ut:Divider();ut:Paragraph({Title="🌀 背景"});CT.PT=ut:Toggle({Flag="PartToggle",Title="粒子背景",Value=true,Callback=function(v)S.Particles=v;if v then cp()else dp2()end end})
        ut:Divider();ut:Paragraph({Title="✨ 窗口"});CT.AT=ut:Toggle({Flag="AcrylicToggle",Title="毛玻璃",Value=true,Callback=function(v)pcall(function()WI:ToggleAcrylic(v)end)end})
        -- Bug4: 透明背景Toggle (移到ut定义后)
        ut:Divider();ut:Paragraph({Title="🎨 主题"})
        local allT={};pcall(function()allT=WI:GetThemes()end);local tn={};for n,_ in pairs(allT)do table.insert(tn,n)end;table.sort(tn)
        CT.TD=ut:Dropdown({Flag="ThemeDrop",Title="选择主题",Values=tn,Value="Dark",Callback=function(sl)if sl then S.CurrentTheme=sl;pcall(function()WI:SetTheme(sl)end);S.ParticleColor=gtc(sl);upc()end end})

        -- Bug4: 透明Toggle移到这里
        ut:Divider();ut:Paragraph({Title="🔄 透明控制"})
        CT.TT=ut:Toggle({Flag="TransToggle",Title="透明背景",Value=true,Callback=function(v)if v then pcall(function()WI.TransparencyValue=0.22 end)else pcall(function()WI.TransparencyValue=0 end)end end})

        local st=WN:Tab({Title="信息统计",Icon="solar:chart-bold"})
        TE.GP=st:Paragraph({Title="🟢 好人: 0"});TE.BP=st:Paragraph({Title="🔴 坏人: 0"});TE.SP=st:Paragraph({Title="📊 总计: 0"})
        st:Divider();TE.SI=st:Input({Title="扫描状态",Value="等待中...",Locked=true})
        st:Divider();TE.DI=st:Input({Title="📋 调试日志",Value="等待检测...",Locked=true,Desc="每个NPC的名字/路径/属性/判断依据"})

        local ct=WN:Tab({Title="配置管理",Icon="solar:diskette-bold"})
        ct:Paragraph({Title="💾 配置管理"});local cni=ct:Input({Flag="CfgName",Title="配置名称",Value="default",Icon="solar:file-text-bold",Callback=function(v)CF=v end});ct:Space()
        local CM=WN.ConfigManager;local AC={};pcall(function()AC=CM:AllConfigs()end);local DV=nil;pcall(function()for _,v in ipairs(AC)do if v=="default"then DV="default";break end end end)
        local ACD=ct:Dropdown({Title="已有配置",Values=AC,Value=DV,Callback=function(v)if v then CF=v;pcall(function()cni:Set(v)end)end end});ct:Space()
        ct:Button({Title="💾 保存",Icon="solar:check-circle-bold",Justify="Center",Color=Color3.fromHex("#305dff"),Callback=function()if not CM then return end;pcall(function()local c=CM:Config(CF);if c and c:Save()then WI:Notify({Title="✅ 已保存",Content="配置 '"..CF.."'",Duration=3,Icon="solar:check-circle-bold"});ACD:Refresh(CM:AllConfigs())end end)end});ct:Space()
        ct:Button({Title="📂 加载",Icon="solar:refresh-circle-bold",Justify="Center",Color=Color3.fromHex("#10C550"),Callback=function()if not CM then return end;pcall(function()local c=CM:CreateConfig(CF,false);if c and c:Load()then WI:Notify({Title="✅ 已加载",Content="配置 '"..CF.."'",Duration=3,Icon="solar:refresh-circle-bold"})end end)end});ct:Space()
        ct:Button({Title="🗑️ 删除",Icon="solar:trash-bin-trash-bold",Justify="Center",Color=Color3.fromHex("#ff3040"),Callback=function()if not CM then return end;pcall(function()local c=CM:Config(CF);if c and c:Delete()then WI:Notify({Title="🗑️ 已删除",Content="配置 '"..CF.."'",Duration=3,Icon="solar:trash-bin-trash-bold"});ACD:Refresh(CM:AllConfigs())end end)end})

        task.spawn(function()task.wait(1);pcall(function()if CM then local c=CM:CreateConfig("default",true)end end);cp()end)

        local at=WN:Tab({Title="关于",Icon="solar:info-square-bold"})
        at:Paragraph({Title="机场安全透视 v12.7",Desc="修复NPC检测+悬浮按钮+透明"})
        at:Divider();at:Paragraph({Title="👤 作者",Desc="b站英吉利超入_"})
        at:Divider();at:Paragraph({Title="💡 使用",Desc=IM and"手机: 点击👁"or"PC: RightShift打开菜单"})
        at:Paragraph({Title="📋 Debug日志",Desc="信息统计Tab看调试日志"})
        at:Paragraph({Title="🧹 清理",Desc="执行: _G.CleanupESP()"})
    end
    print("[v12.7] 已加载")
else
    print("[v12.7] WindUI加载失败，启用原生备份")
    local msg=Instance.new("Message");msg.Text="⚠️WindUI加载失败";msg.Parent=WS;task.delay(3,function()msg:Destroy()end)
end
print("[v12.7] 完成")
