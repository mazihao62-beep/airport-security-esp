--[[
    机场安全透视 v15.9
    修复: isPC玩家检测增加CharacterAdded事件绑定
    功能: NPC透视+行李箱检测+自动工作(逮捕/击杀/放行)
    作者: b站英吉利超入_
]]
local P=game:GetService("Players");local U=game:GetService("UserInputService");local W=game:GetService("Workspace")
local C=game:GetService("CoreGui");local RS=game:GetService("ReplicatedStorage");local VIM=game:GetService("VirtualInputManager")
local LP=nil;for i=1,50 do LP=P.LocalPlayer;if LP then break end;task.wait(0.1)end
local IM=U.TouchEnabled and not U.KeyboardEnabled;if not IM then pcall(function()IM=U.TouchEnabled and not U.MouseEnabled end)end

-- 玩家角色集合(持续追踪,不受角色重生影响)
local PCSet={}
local function updatePCSet()
    for k in pairs(PCSet)do PCSet[k]=nil end
    for _,p in ipairs(P:GetPlayers())do
        local c=p.Character
        if c then PCSet[c]=true end
    end
end
updatePCSet()
P.PlayerAdded:Connect(updatePCSet)
P.PlayerRemoving:Connect(updatePCSet)

local function cln()
    local wc=0
    for _,g in ipairs(C:GetChildren())do
        if g:IsA("ScreenGui")then local n=g.Name
            if n:find("WindUI")then wc=wc+1;if wc>1 then pcall(function()g:Destroy()end)end
            elseif n=="A"or n:find("AirportESP")or n:find("ESP_Particles")then pcall(function()g:Destroy()end)end
        end
    end
end
cln()

-- 监听玩家角色事件(每个玩家加入时绑定CharacterAdded)
P.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function(c)PCSet[c]=true end)
    pl.CharacterRemoving:Connect(function(c)PCSet[c]=nil end)
end)
-- 给已有玩家绑定
for _,pl in ipairs(P:GetPlayers())do
    pl.CharacterAdded:Connect(function(c)PCSet[c]=true end)
    pl.CharacterRemoving:Connect(function(c)PCSet[c]=nil end)
end

local function rf(i,n)
    local f=i:FindFirstChild(n);if f then return f end
    for _,c in ipairs(i:GetChildren())do
        if c:IsA("Configuration")or c:IsA("Folder")then local r=rf(c,n);if r then return r end end
    end
    return nil
end

local function sp(m)
    if not m then return nil end;local pr=m:FindFirstChild("Properties");if not pr then return nil end
    local sv=rf(pr,"StatusVariables");if sv then local h=rf(sv,"Hostile");if h and h:IsA("BoolValue")and h.Value then return true end end
    local rv=rf(pr,"RandomVariables")
    if rv then
        local c=rf(rv,"ContrabandReal");if c and c:IsA("BoolValue")and c.Value then return true end
        local f=rf(rv,"FakePassport");if f and f:IsA("BoolValue")and f.Value then return true end
    end
    return nil
end

local function gnb(n)
    if not n then return false end;local pr=n:FindFirstChild("Properties");if not pr then return false end
    local rv=rf(pr,"RandomVariables")
    if rv then
        local c=rf(rv,"ContrabandReal");if c and c:IsA("BoolValue")and c.Value then return true end
        local f=rf(rv,"FakePassport");if f and f:IsA("BoolValue")and f.Value then return true end
    end
    return false
end

local function cl(m)
    if not m then return"Good"end;local nm=m.Name or"";local fp="";pcall(function()fp=m:GetFullName()end)
    local hum=m:FindFirstChildOfClass("Humanoid")
    if hum then
        for _,an in ipairs({"NPCType","Type","Faction","Team","Role"})do
            local v=nil;pcall(function()v=hum:GetAttribute(an)end)
            if v then local vs=tostring(v):lower()
                for _,g in ipairs({"agent","good","friendly","ally","police","guard","civilian","security"})do if vs:find(g,1,true)then return"Good"end end
                for _,b in ipairs({"enemy","bad","hostile","terrorist","criminal"})do if vs:find(b,1,true)then return"Bad"end end end end end
    local bad=sp(m);if bad~=nil then return bad and"Bad"or"Good"end
    local nl=nm:lower()
    for _,kw in ipairs({"警察","保安","警卫","police","guard","agent","officer","prisoner","store","npcstore","市民","商人"})do if nl:find(kw:lower(),1,true)then return"Good"end end
    for _,kw in ipairs({"恐怖","匪","敌人","坏","犯罪","terrorist","enemy","hostile","criminal","smuggler"})do if nl:find(kw:lower(),1,true)then return"Bad"end end
    local pl=fp:lower()
    for _,kw in ipairs({"agent","police","friendly","civilian","prisoner","store","jail"})do if pl:find(kw,1,true)then return"Good"end end
    for _,kw in ipairs({"enemy","terror","hostile","criminal","invader"})do if pl:find(kw,1,true)then return"Bad"end end
    return"Good"
end

local function cll(lug)
    if not lug then return"Suspicious"end;local pr=lug:FindFirstChild("Properties")
    if pr then local cb=rf(pr,"Contraband");if cb and cb:IsA("BoolValue")then return cb.Value and"Dangerous"or"Safe"end end
    return"Suspicious"
end

local function glp(lug)
    local pp=nil;pcall(function()pp=lug.PrimaryPart end)
    if not pp then for _,c in ipairs(lug:GetDescendants())do
        if c:IsA("BasePart")and(c.Name=="ColorFront"or c.Name=="ColorBack"or c.Name=="HumanoidRootPart")then pp=c;break end end end
    if not pp then for _,c in ipairs(lug:GetDescendants())do if c:IsA("BasePart")then pp=c;break end end end
    return pp
end

local JAIL_POS=nil
local function fj()
    if JAIL_POS then return JAIL_POS end
    local je=W:FindFirstChild("WorkspaceScriptable")and W.WorkspaceScriptable:FindFirstChild("JailEssentials")
    if je then
        local jd=je:FindFirstChild("JailDetect");if jd and jd:IsA("BasePart")then JAIL_POS=jd.Position;return JAIL_POS end
        for _,c in ipairs(je:GetChildren())do if c:IsA("BasePart")then JAIL_POS=c.Position;return JAIL_POS end end
    end
    return nil
end

local S={Enabled=false,BadOnly=false,ShowDist=false,ShowHP=false,Luggage=false,AutoWork=false,WorkMode="Arrest",WorkRange=20,MaxRange=500,Theme="Dark",Particles=true,PColor=Color3.fromRGB(80,170,255)}
local H={};local LG={};local GC=0;local BC=0;local LC=0;local LDC=0;local LSC=0;local SC=0
local WN=nil;local WI=nil;local PC=nil;local CT={};local KB={};local TE={};local ATE={};local PS={};local PR=false;local PP=false;local CF="default"

local function mHL(o,c)
    if not o then return end;local hl=Instance.new("Highlight")
    hl.FillColor=c;hl.FillTransparency=0.25;hl.OutlineColor=Color3.fromRGB(255,255,255);hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;hl.Adornee=o;hl.Parent=o;return hl
end

local function mNESP(c,nt)
    if not c or not c.Parent then return end
    -- 用PCSet玩家集合检测(持续追踪,比GetPlayerFromCharacter可靠)
    if PCSet[c]then return end
    if H[c]then return end
    local hrp=c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Torso")or c:FindFirstChildOfClass("Part");if not hrp then return end
    if LP and LP.Character then local mp=LP.Character:FindFirstChild("HumanoidRootPart")or LP.Character:FindFirstChild("Torso")
        if mp and(hrp.Position-mp.Position).Magnitude>S.MaxRange then return end end
    local col=nt=="Good"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,40,40);local tag=nt=="Good"and"👮 好人"or"💀 坏人"
    local hl=mHL(c,col);local head=c:FindFirstChild("Head")or hrp
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
    H[c]={bb=bb,lb=lb,hrp=hrp,nt=nt,tag=tag,hl=hl};SC=SC+1;if nt=="Good"then GC=GC+1 else BC=BC+1 end
end

local function mLESP(lug,lt)
    if not lug or not lug.Parent or lug.Name~="OpenableLuggage"then return end
    local pp=glp(lug);if not pp then return end;local key=pp
    if LG[key]then
        if LG[key].nt~=lt then
            LG[key].nt=lt;LG[key].tag=lt=="Dangerous"and"💣 危险行李"or(lt=="Safe"and"🧳 安全行李"or"❓ 可疑行李")
            if LG[key].lb then local col=lt=="Dangerous"and Color3.fromRGB(255,40,40)or(lt=="Safe"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,180,40))
                LG[key].lb.TextColor3=col;LG[key].lb.Text=LG[key].tag end
            if LG[key].hl then LG[key].hl.FillColor=col end end
        return end
    local col=lt=="Dangerous"and Color3.fromRGB(255,40,40)or(lt=="Safe"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,180,40))
    local tag=lt=="Dangerous"and"💣 危险行李"or(lt=="Safe"and"🧳 安全行李"or"❓ 可疑行李")
    local hl=mHL(lug,col);local bb=Instance.new("BillboardGui");bb.Adornee=pp;bb.Size=UDim2.new(0,220,0,56)
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
    LG[key]={bb=bb,lb=lb,pp=pp,nt=lt,tag=tag,hl=hl};LC=LC+1;if lt=="Dangerous"then LDC=LDC+1 elseif lt=="Safe"then LSC=LSC+1 end
end

local function doScan()
    updatePCSet()
    local seen={}
    for _,o in ipairs(W:GetDescendants())do
        if o:IsA("Humanoid")then local c=o.Parent
            if c and c:IsA("Model")and not seen[c]then seen[c]=true
                if not PCSet[c]then mNESP(c,cl(c))end end end end
end

local function rLBL()
    local wsf=W:FindFirstChild("WorkspaceScriptable")
    if wsf then local sto=wsf:FindFirstChild("Storage")
        if sto then local ns=sto:FindFirstChild("NormalStorage")
            if ns then
                for _,fn in ipairs({"LuggageWorkspace","LuggageOpenWorkspace","LuggageEndWorkspace"})do
                    local fw=ns:FindFirstChild(fn)
                    if fw then for _,lug in ipairs(fw:GetChildren())do
                        if lug:IsA("Model")and lug.Name=="OpenableLuggage"then local pp=glp(lug)
                            if pp then local key=pp;local lt=cll(lug)
                                if LG[key]then
                                    if LG[key].nt~=lt then
                                        LG[key].nt=lt;LG[key].tag=lt=="Dangerous"and"💣 危险行李"or(lt=="Safe"and"🧳 安全行李"or"❓ 可疑行李")
                                        if LG[key].lb then local col=lt=="Dangerous"and Color3.fromRGB(255,40,40)or(lt=="Safe"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,180,40))
                                            LG[key].lb.TextColor3=col;LG[key].lb.Text=LG[key].tag end
                                        if LG[key].hl then LG[key].hl.FillColor=col end end
                                else mLESP(lug,lt)end end end end end end end end end
end

local function iLS()
    for _,o in pairs(LG)do pcall(function()if o.bb then o.bb:Destroy()end;if o.hl then o.hl:Destroy()end end)end
    LG={};LC=0;LDC=0;LSC=0;local seenPP={}
    local wsf=W:FindFirstChild("WorkspaceScriptable")
    if wsf then local sto=wsf:FindFirstChild("Storage")
        if sto then local ns=sto:FindFirstChild("NormalStorage")
            if ns then
                for _,fn in ipairs({"LuggageWorkspace","LuggageOpenWorkspace","LuggageEndWorkspace"})do
                    local fw=ns:FindFirstChild(fn)
                    if fw then for _,lug in ipairs(fw:GetChildren())do
                        if lug:IsA("Model")and lug.Name=="OpenableLuggage"then local pp=glp(lug)
                            if pp and not seenPP[pp]then seenPP[pp]=true;mLESP(lug,cll(lug))end end end end end end end end
    if LC==0 then for _,o in ipairs(W:GetDescendants())do
        if o:IsA("Model")and o.Name=="OpenableLuggage"and o.Parent and o.Parent:IsA("Folder")then
            local pp=glp(o);if pp and not seenPP[pp]then seenPP[pp]=true;mLESP(o,cll(o))end end end end
end

local function rESP()
    for c,o in pairs(H)do
        if not c or not c.Parent then pcall(function()if o.bb then o.bb:Destroy()end;if o.hl then o.hl:Destroy()end end);H[c]=nil
        else local en=S.Enabled and(not S.BadOnly or o.nt=="Bad")
            if o.bb then o.bb.Enabled=en end;if o.hl then o.hl.Enabled=en end
            if o.lb then local txt=o.tag
                if S.ShowDist and LP and LP.Character then local mp=LP.Character:FindFirstChild("HumanoidRootPart")
                    if mp and o.hrp then txt=txt.." | "..math.floor((o.hrp.Position-mp.Position).Magnitude+0.5).."m"end end
                if S.ShowHP then local h2=c:FindFirstChildOfClass("Humanoid")
                    if h2 then txt=txt.." | HP:"..math.floor(h2.Health+0.5).."/"..math.floor(h2.MaxHealth+0.5)end end
                o.lb.Text=txt end end end
    for _,o in pairs(LG)do if o.bb then o.bb.Enabled=S.Luggage end;if o.hl then o.hl.Enabled=S.Luggage end end
end

local function uS()
    GC=0;BC=0;SC=0;LC=0;LDC=0;LSC=0
    for _,o in pairs(H)do SC=SC+1;if o.nt=="Good"then GC=GC+1 else BC=BC+1 end end
    for _,o in pairs(LG)do LC=LC+1;if o.nt=="Dangerous"then LDC=LDC+1 elseif o.nt=="Safe"then LSC=LSC+1 end end
    pcall(function()if TE.GP then TE.GP:SetTitle("🟢 好人: "..GC)end;if TE.BP then TE.BP:SetTitle("🔴 坏人: "..BC)end
        if TE.LP then TE.LP:SetTitle("🧳 行李: "..LC.." (💣"..LDC.." 🟢"..LSC..")")end;if TE.SP then TE.SP:SetTitle("📊 总计: "..SC)end end)
end

local WB={}
local function sNN()
    local rs={};if not LP or not LP.Character then return rs end
    local mp=LP.Character:FindFirstChild("HumanoidRootPart")or LP.Character:FindFirstChild("Torso");if not mp then return rs end
    for _,o in ipairs(W:GetDescendants())do
        if o:IsA("Humanoid")then local m=o.Parent
            if m and m:IsA("Model")and not PCSet[m]then local hrp=m:FindFirstChild("HumanoidRootPart")or m:FindFirstChild("Torso")
                if hrp then local d=(hrp.Position-mp.Position).Magnitude
                    if d<=S.WorkRange then table.insert(rs,{model=m,hrp=hrp,hum=o,dist=d,isBad=gnb(m)})end end end end end
    table.sort(rs,function(a,b)return a.dist<b.dist end);return rs
end

-- NPCArrest等事件引用
local NPCArrest,MarkArrest,MarkSearch,ProductArrest
pcall(function()NPCArrest=RS.Resources.Events.Client.NPCArrest end)
pcall(function()MarkArrest=RS.Resources.Events.Client.MarkArrest end)
pcall(function()MarkSearch=RS.Resources.Events.Client.MarkSearch end)
pcall(function()ProductArrest=RS.Resources.Events.Client.ProductArrestPlayer end)

local function eF(wn)
    if not LP then return false end;local back=LP:FindFirstChild("Backpack")
    local function fw()
        if back then for _,t in ipairs(back:GetChildren())do if t:IsA("Tool")and t.Name==wn then return t end end end
        if LP.Character then for _,t in ipairs(LP.Character:GetChildren())do if t:IsA("Tool")and t.Name==wn then return t end end end
        return nil
    end
    local t=fw();if not t then return false end
    pcall(function()t.Parent=LP.Character end);task.wait(0.15)
    pcall(function()t:Activate()end);task.wait(0.1)
    pcall(function()VIM:SendMouseButtonEvent(0,0,0,true,game,1)end);task.wait(0.05)
    pcall(function()VIM:SendMouseButtonEvent(0,0,0,false,game,1)end);return true
end

local function tJ(n)
    local p=fj();if not p then return false end
    local hrp=n:FindFirstChild("HumanoidRootPart")or n:FindFirstChild("Torso")
    if hrp then pcall(function()hrp.CFrame=CFrame.new(p)end);return true end;return false
end

local function dA(n)
    if MarkArrest then pcall(function()MarkArrest:FireServer(n)end);task.wait(0.3)end
    if NPCArrest then pcall(function()NPCArrest:FireServer(n)end);task.wait(0.5)end
    if ProductArrest then pcall(function()ProductArrest:FireServer(n)end);task.wait(0.3)end
    eF("Arrest");task.wait(0.5);tJ(n)
end

local function dR(n)
    if MarkSearch then pcall(function()MarkSearch:FireServer(n)end)
        local hum=n:FindFirstChildOfClass("Humanoid");if hum then pcall(function()MarkSearch:FireServer(hum)end)end end
    eF("Arrest");task.wait(0.2)
    local back=LP:FindFirstChild("Backpack")
    if back then for _,t in ipairs(back:GetChildren())do
        if t:IsA("Tool")and t.Name=="Arrest"then pcall(function()t.Parent=LP.Character end);task.wait(0.2);pcall(function()t:Activate()end);break end end end
end

local function dK(n)
    local hum=n:FindFirstChildOfClass("Humanoid");if hum and hum.Health<=0 then return end
    for _,wn in ipairs({"MP7A1","M1911","Taser"})do if eF(wn)then break end end
    for i=1,5 do task.wait(0.1);pcall(function()VIM:SendMouseButtonEvent(0,0,0,true,game,1)end);task.wait(0.05);pcall(function()VIM:SendMouseButtonEvent(0,0,0,false,game,1)end)end
end

local function aP()
    if not S.AutoWork then return end;local mode=S.WorkMode;local list=sNN()
    if#list==0 then pcall(function()if ATE.ST then ATE.ST:Set("[空闲] 附近无NPC")end end);return end
    for _,n in ipairs(list)do
        if WB[n.model]then continue end;local b=n.isBad
        if(mode=="Release"and not b)or((mode=="Arrest"or mode=="Kill")and not b)then continue end
        WB[n.model]=true;local nm=n.model.Name
        task.spawn(function()
            if b then
                if mode=="Kill"then pcall(function()if ATE.ST then ATE.ST:Set("[击杀] "..nm)end end);dK(n.model)
                else pcall(function()if ATE.ST then ATE.ST:Set("[逮捕] "..nm)end end);dA(n.model)
                    if mode=="Auto"then task.wait(1);if sp(n.model)then pcall(function()if ATE.ST then ATE.ST:Set("[反击] "..nm.." 击杀")end end);dK(n.model)end end end
            else pcall(function()if ATE.ST then ATE.ST:Set("[放行] "..nm.." ✅")end end);dR(n.model)end
            pcall(function()if ATE.ST then ATE.ST:Set("[完成] "..nm)end end);task.wait(1);WB[n.model]=nil
        end)
    end
end

local function sAWL()while true do task.wait(2);pcall(function()if S.AutoWork then aP()elseif ATE.ST then ATE.ST:Set("[停止] 自动工作已关闭")end end)end end

local function uPC()local col=S.PColor;for _,p in ipairs(PS)do if p.F and p.F.Parent then p.F.BackgroundColor3=col end end end

local function mkP()
    if not PP or PC then return end;task.wait(0.5)
    local sg=Instance.new("ScreenGui");sg.Name="ESP_Particles";sg.ResetOnSpawn=false;sg.DisplayOrder=999999;sg.IgnoreGuiInset=true;sg.Parent=C
    PC=Instance.new("Frame");PC.Size=UDim2.new(1,0,1,0);PC.BackgroundTransparency=1;PC.BorderSizePixel=0;PC.Active=false;PC.Parent=sg
    local col=S.PColor
    for i=1,50 do
        local d=Instance.new("Frame");local sz=math.random(5,10);d.Size=UDim2.new(0,sz,0,sz)
        local sx=0.2+math.random()*0.6;local sy=0.2+math.random()*0.6
        d.Position=UDim2.new(sx,0,sy,0);d.BackgroundColor3=col;d.BackgroundTransparency=0.3+math.random()*0.5;d.BorderSizePixel=0;d.Parent=PC
        Instance.new("UICorner",d).CornerRadius=UDim.new(0,10)
        local a=math.random()*6.28;local sp=0.0008+math.random()*0.002
        table.insert(PS,{F=d,Sx=sx,Sy=sy,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})
    end;PR=true
    task.spawn(function()
        local t=0
        while PR and PC do t=t+0.03
            pcall(function()local cc=S.PColor
                for _,p in ipairs(PS)do if p.F and p.F.Parent then
                    local sx=math.max(0.05,math.min(0.95,p.Sx+p.Vx));local sy=math.max(0.05,math.min(0.95,p.Sy+p.Vy))
                    if sx>=0.95 or sx<=0.05 then p.Vx=-p.Vx end;if sy>=0.95 or sy<=0.05 then p.Vy=-p.Vy end
                    p.Sx=sx;p.Sy=sy;p.F.Position=UDim2.new(sx,0,sy,0)
                    if cc~=p.F.BackgroundColor3 then p.F.BackgroundColor3=cc end
                    p.F.BackgroundTransparency=0.3+math.sin(t*0.8+p.Ph)*0.4
                    local bs=math.max(2,p.Sz+math.sin(t+p.Ph)*1.5);p.F.Size=UDim2.new(0,bs,0,bs)end end end)
            task.wait(0.03)end end)
end

local function kP()PR=false;if PC then pcall(function()local p=PC.Parent;if p then p:Destroy()end end);PC=nil end;PS={}end

local function gtc(n)
    if not n then return Color3.fromRGB(80,170,255)end;local l=n:lower()
    local m={dark=Color3.fromRGB(80,170,255),light=Color3.fromRGB(60,130,210),rose=Color3.fromRGB(255,130,170),plant=Color3.fromRGB(70,210,130),ocean=Color3.fromRGB(60,190,240),sunset=Color3.fromRGB(255,160,70),midnight=Color3.fromRGB(130,100,240),forest=Color3.fromRGB(60,180,90),lavender=Color3.fromRGB(190,140,255),coral=Color3.fromRGB(255,140,90),mint=Color3.fromRGB(80,230,190),sky=Color3.fromRGB(100,190,255),blood=Color3.fromRGB(230,90,80),lemon=Color3.fromRGB(230,210,70),cyber=Color3.fromRGB(0,235,210)}
    if m[l]then return m[l]end
    if l:find("dark")then return Color3.fromRGB(80,170,255)end;if l:find("rose")or l:find("pink")then return Color3.fromRGB(255,130,170)end
    if l:find("plant")or l:find("green")then return Color3.fromRGB(70,210,130)end;if l:find("ocean")or l:find("blue")or l:find("sky")then return Color3.fromRGB(60,190,240)end
    if l:find("sunset")or l:find("orange")then return Color3.fromRGB(255,160,70)end;if l:find("midnight")or l:find("purple")or l:find("lavender")then return Color3.fromRGB(130,100,240)end
    if l:find("blood")or l:find("red")then return Color3.fromRGB(230,90,80)end;if l:find("lemon")or l:find("yellow")then return Color3.fromRGB(230,210,70)end
    return Color3.fromRGB(80,170,255)
end

local function mW()
    local ok2,w=pcall(function()return WI:CreateWindow({
        Title="机场安全透视",Author="b站英吉利超入_",Icon="solar:shield-warning-bold",
        Size=UDim2.fromOffset(750,520),ToggleKey=Enum.KeyCode.RightShift,
        Folder="airport-esp",Acrylic=true,Transparent=true,Resizable=false,
        SideBarWidth=180,ScrollBarEnabled=true,HideSearchBar=true,
        OpenButton={Title="打开透视",Scale=0.5,Enabled=true,OnlyMobile=IM,Draggable=true,
            Color=ColorSequence.new(Color3.fromRGB(0,255,100),Color3.fromRGB(0,200,255)),CornerRadius=UDim.new(1,0),StrokeThickness=3},
        OnClose=function()S.Enabled=false;S.Luggage=false;S.AutoWork=false
            if CT.ESP then CT.ESP:Set(false)end;if CT.LT then CT.LT:Set(false)end;if CT.AW then CT.AW:Set(false)end;rESP();kP()end,
        OnOpen=function()if S.Particles then task.spawn(function()task.wait(0.5);mkP()end)end end})end)
    if not ok2 or not w then return end;WN=w
    local mt=WN:Tab({Title="主控面板",Icon="solar:slider-vertical-bold"})
    CT.ESP=mt:Toggle({Flag="ESP",Title="透视开关",Value=false,Callback=function(v)S.Enabled=v;rESP();if v then task.spawn(doScan)end end})
    CT.BO=mt:Toggle({Flag="BadOnly",Title="仅显示坏人",Value=false,Callback=function(v)S.BadOnly=v;rESP()end});mt:Divider()
    CT.LT=mt:Toggle({Flag="Luggage",Title="🧳 行李箱检测",Value=false,Callback=function(v)S.Luggage=v
        if v then task.spawn(iLS)else for _,o in pairs(LG)do pcall(function()if o.bb then o.bb:Destroy()end;if o.hl then o.hl:Destroy()end end)end;LG={};LC=0;LDC=0;LSC=0 end end})
    mt:Divider();CT.DT=mt:Toggle({Flag="Dist",Title="显示距离",Value=false,Callback=function(v)S.ShowDist=v end})
    CT.HT=mt:Toggle({Flag="Health",Title="显示血量",Value=false,Callback=function(v)S.ShowHP=v end})
    mt:Divider();CT.RS=mt:Slider({Flag="Range",Title="最大探测距离",Step=50,Value={Min=50,Max=1000,Default=500},Width=200,IsTextbox=true,Callback=function(v)S.MaxRange=v end})
    local ft=WN:Tab({Title="功能设置",Icon="solar:settings-bold"})
    CT.EK=ft:Keybind({Flag="ESPK",Title="透视开关快捷键",Value="",Callback=function(k)KB.ESP=k end})
    CT.BK=ft:Keybind({Flag="BadK",Title="仅坏人快捷键",Value="",Callback=function(k)KB.BadOnly=k end})
    local awt=WN:Tab({Title="自动工作",Icon="solar:police-car-bold"})
    CT.AW=awt:Toggle({Flag="AutoWork",Title="自动模式",Value=false,Callback=function(v)S.AutoWork=v end});awt:Divider()
    CT.WM=awt:Dropdown({Flag="WorkMode",Title="工作模式",Values={"Arrest","Kill","Release","Auto"},Value="Arrest",Callback=function(v)S.WorkMode=v end})
    CT.WR=awt:Slider({Flag="WorkRange",Title="工作范围(米)",Step=5,Value={Min=5,Max=50,Default=20},Width=180,IsTextbox=true,Callback=function(v)S.WorkRange=v end})
    awt:Divider();ATE.ST=awt:Input({Flag="WS",Title="状态",Value="[等待启动]",Locked=true,Icon="solar:info-circle-bold"})
    awt:Space();awt:Paragraph({Title="📋 工作说明",Desc="ContrabandReal+NPCType双通道检测"})
    local ut=WN:Tab({Title="UI设置",Icon="solar:monitor-bold"})
    CT.WK=ut:Keybind({Flag="WinK",Title="窗口开关",Value="RightShift",Callback=function(k)KB.Win=k end});ut:Divider()
    CT.PT=ut:Toggle({Flag="PT",Title="粒子背景",Value=true,Callback=function(v)S.Particles=v;if v then task.spawn(mkP)else kP()end end});ut:Divider()
    CT.AT=ut:Toggle({Flag="AT",Title="毛玻璃",Value=true,Callback=function(v)pcall(function()WI:ToggleAcrylic(v)end)end})
    CT.TT=ut:Toggle({Flag="TT",Title="透明背景",Value=true,Callback=function(v)pcall(function()if WN then WN:ToggleTransparency(v)end end)end});ut:Divider()
    local allT={};pcall(function()allT=WI:GetThemes()end);local tn={};for n,_ in pairs(allT)do table.insert(tn,n)end;table.sort(tn)
    CT.TD=ut:Dropdown({Flag="TD",Title="选择主题",Values=tn,Value="Dark",Callback=function(sl)if sl and type(sl)=="string"then S.Theme=sl;WI:SetTheme(sl);S.PColor=gtc(sl);uPC()end end})
    local st=WN:Tab({Title="信息统计",Icon="solar:chart-bold"})
    TE.GP=st:Paragraph({Title="🟢 好人: 0"});TE.BP=st:Paragraph({Title="🔴 坏人: 0"});TE.LP=st:Paragraph({Title="🧳 行李: 0"});TE.SP=st:Paragraph({Title="📊 总计: 0"})
    local ct=WN:Tab({Title="配置管理",Icon="solar:diskette-bold"})
    local cni=ct:Input({Flag="CN",Title="配置名称",Value="default",Icon="solar:file-text-bold",Callback=function(v)CF=v end});ct:Space()
    local CM=WN.ConfigManager;local AC={};pcall(function()AC=CM:AllConfigs()end)
    local DV=nil;pcall(function()for _,v in ipairs(AC)do if v=="default"then DV="default";break end end end)
    local ACD=ct:Dropdown({Title="已有配置",Values=AC,Value=DV,Callback=function(v)if v then CF=v;cni:Set(v)end end});ct:Space()
    ct:Button({Title="💾 保存",Icon="solar:check-circle-bold",Justify="Center",Color=Color3.fromHex("#305dff"),Callback=function()if not CM then return end;local c=CM:Config(CF);if c and c:Save()then WI:Notify({Title="✅ 已保存",Content="配置 '"..CF.."'",Duration=3,Icon="solar:check-circle-bold"});ACD:Refresh(CM:AllConfigs())end end});ct:Space()
    ct:Button({Title="📂 加载",Icon="solar:refresh-circle-bold",Justify="Center",Color=Color3.fromHex("#10C550"),Callback=function()if not CM then return end;local c=CM:CreateConfig(CF,false);if c and c:Load()then WI:Notify({Title="✅ 已加载",Content="配置 '"..CF.."'",Duration=3,Icon="solar:refresh-circle-bold"})end end});ct:Space()
    ct:Button({Title="🗑️ 删除",Icon="solar:trash-bin-trash-bold",Justify="Center",Color=Color3.fromHex("#ff3040"),Callback=function()if not CM then return end;local c=CM:Config(CF);if c and c:Delete()then WI:Notify({Title="🗑️ 已删除",Content="配置 '"..CF.."'",Duration=3,Icon="solar:trash-bin-trash-bold"});ACD:Refresh(CM:AllConfigs())end end})
    task.spawn(function()task.wait(1);pcall(function()CM:CreateConfig("default",true)end);task.spawn(mkP)end)
    local at=WN:Tab({Title="关于",Icon="solar:info-square-bold"})
    at:Paragraph({Title="机场安全透视 v15.9",Desc="PCSet持续追踪,角色重生不漏"})
    at:Divider();at:Paragraph({Title="👤 作者",Desc="b站英吉利超入_"});at:Divider()
    at:Paragraph({Title="💡 使用",Desc=IM and"手机:点击悬浮按钮"or"PC:RightShift打开菜单"})
    U.InputBegan:Connect(function(i,g)if g or i.UserInputType~=Enum.UserInputType.Keyboard then return end;local k=i.KeyCode.Name
        if KB.ESP and KB.ESP~=""and k==KB.ESP then S.Enabled=not S.Enabled;if CT.ESP then CT.ESP:Set(S.Enabled)end;rESP();if S.Enabled then task.spawn(doScan)end end
        if KB.BadOnly and KB.BadOnly~=""and k==KB.BadOnly then S.BadOnly=not S.BadOnly;if CT.BO then CT.BO:Set(S.BadOnly)end;rESP()end end)
    local function mL()while true do task.wait(5);pcall(function()doScan();rESP();uS();if S.Luggage then rLBL()end;uS()end)end end
    task.spawn(mL);task.spawn(sAWL)
end

local rC=0;local mR=3;local LO=false
while rC<mR and not LO do
    local ok,rv=pcall(function()return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()end)
    if ok and rv then WI=rv;LO=true else rC=rC+1;if rC<mR then task.wait(1)end end end

if LO then
    pcall(function()WI:SetTheme("Dark")end);S.PColor=gtc("Dark")
    WI:Popup({Title="机场安全透视 v15.9",Icon="solar:info-square-bold",
        Content="👁 NPC透视\n🔴🟢 红坏人/绿好人\n🧳 行李箱检测\n🚔 自动工作\n🌀 粒子背景\n⚠️ 功能默认关闭",
        Buttons={{Title="取消",Callback=function()end,Variant="Tertiary"},
            {Title="确认加载",Icon="solar:arrow-right-bold",Callback=function()PP=true
                WI:Notify({Title="✅ 已加载",Content="按RightShift打开菜单",Duration=4,Icon="solar:bell-bold"});task.spawn(mW)end,Variant="Primary"}}})
    while not PP do task.wait(0.5)end
else
    local msg=Instance.new("Message");msg.Text="⚠️ WindUI加载失败(已重试"..mR.."次)";msg.Parent=W
    task.delay(4,function()msg:Destroy()end)
end
