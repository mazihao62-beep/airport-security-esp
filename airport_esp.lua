--[[
    机场安全透视 v15.3
    修复: 自动工作v3 - 只处理检查中NPC + 逮捕送监狱 + 武器自动开火
    作者: b站英吉利超入_
]]
local P=game:GetService("Players");local U=game:GetService("UserInputService");local W=game:GetService("Workspace");local C=game:GetService("CoreGui");local RS=game:GetService("ReplicatedStorage");local VIM=game:GetService("VirtualInputManager")
local LP=P.LocalPlayer;local IM=U.TouchEnabled and not U.KeyboardEnabled
if not IM then pcall(function()IM=U.TouchEnabled and not U.MouseEnabled end)end
local function isPlayerChar(m)if not m then return false end;local p=P:GetPlayerFromCharacter(m);if p then return true end;for _,pl in ipairs(P:GetPlayers())do if pl.Character==m then return true end;if pl.Name==m.Name then return true end end;return false end
local NPCArrest=nil;local MarkArrest=nil;local MarkSearch=nil;local ProductArrest=nil
pcall(function()NPCArrest=RS.Resources.Events.Client.NPCArrest end)
pcall(function()MarkArrest=RS.Resources.Events.Client.MarkArrest end)
pcall(function()MarkSearch=RS.Resources.Events.Client.MarkSearch end)
pcall(function()ProductArrest=RS.Resources.Events.Client.ProductArrestPlayer end)
local function clean()local wc=0;for _,g in ipairs(C:GetChildren())do if g:IsA("ScreenGui")then local n=g.Name;if n:find("WindUI")then wc=wc+1;if wc>1 then pcall(function()g:Destroy()end)end elseif n=="A"or n:FindFirstChild("AirportESP")or n:FindFirstChild("ESP_Particles")then pcall(function()g:Destroy()end)end end end end;clean()
local function rFind(inst,name)local f=inst:FindFirstChild(name);if f then return f end;for _,c in ipairs(inst:GetChildren())do if c:IsA("Configuration")or c:IsA("Folder")then local r=rFind(c,name);if r then return r end end end;return nil end
local function scanProps(m)if not m then return nil end;local pr=m:FindFirstChild("Properties");if not pr then return nil end;local sv=rFind(pr,"StatusVariables");if sv then local h=rFind(sv,"Hostile");if h and h:IsA("BoolValue")and h.Value then return true end end;local rv=rFind(pr,"RandomVariables");if rv then local c=rFind(rv,"ContrabandReal");if c and c:IsA("BoolValue")and c.Value then return true end;local f=rFind(rv,"FakePassport");if f and f:IsA("BoolValue")and f.Value then return true end end;return nil end
local function classify(c)if not c then return"Good"end;local nm=c.Name or"";local fp="";pcall(function()fp=c:GetFullName()end);local hum=c:FindFirstChildOfClass("Humanoid");if hum then for _,an in ipairs({"NPCType","Type","Faction","Team","Role"})do local v=nil;pcall(function()v=hum:GetAttribute(an)end);if v then local vs=tostring(v):lower();for _,g in ipairs({"agent","good","friendly","ally","police","guard","civilian","security"})do if vs:find(g,1,true)then return"Good"end end;for _,b in ipairs({"enemy","bad","hostile","terrorist","criminal"})do if vs:find(b,1,true)then return"Bad"end end end end end;local bad=scanProps(c);if bad~=nil then return bad and"Bad"or"Good"end;local nl=nm:lower();for _,kw in ipairs({"警察","保安","警卫","police","guard","agent","officer","prisoner","store","npcstore","市民","商人"})do if nl:find(kw:lower(),1,true)then return"Good"end end;for _,kw in ipairs({"恐怖","匪","敌人","坏","犯罪","terrorist","enemy","hostile","criminal","smuggler"})do if nl:find(kw:lower(),1,true)then return"Bad"end end;local pl=fp:lower();for _,kw in ipairs({"agent","police","friendly","civilian","prisoner","store","jail"})do if pl:find(kw,1,true)then return"Good"end end;for _,kw in ipairs({"enemy","terror","hostile","criminal","invader"})do if pl:find(kw,1,true)then return"Bad"end end;return"Good"end
local function classifyLuggage(lug)if not lug then return"Suspicious"end;local pr=lug:FindFirstChild("Properties");if pr then local cb=rFind(pr,"Contraband");if cb and cb:IsA("BoolValue")then return cb.Value and"Dangerous"or"Safe"end end;return"Suspicious"end
local function getLuggagePP(lug)local pp=nil;pcall(function()pp=lug.PrimaryPart end);if not pp then for _,c in ipairs(lug:GetDescendants())do if c:IsA("BasePart")and(c.Name=="ColorFront"or c.Name=="ColorBack"or c.Name=="HumanoidRootPart")then pp=c;break end end end;if not pp then for _,c in ipairs(lug:GetDescendants())do if c:IsA("BasePart")then pp=c;break end end end;return pp end

-- 查找监狱位置
local JAIL_POS=nil
local function findJail()
    if JAIL_POS then return JAIL_POS end
    local je=W:FindFirstChild("WorkspaceScriptable")and W.WorkspaceScriptable:FindFirstChild("JailEssentials")
    if je then
        local jd=je:FindFirstChild("JailDetect")
        if jd and jd:IsA("BasePart")then JAIL_POS=jd.Position;return JAIL_POS end
        for _,c in ipairs(je:GetChildren())do if c:IsA("BasePart")then JAIL_POS=c.Position;return JAIL_POS end end
    end
    return nil
end

local S={Enabled=false,BadOnly=false,ShowDist=false,ShowHP=false,Luggage=false,AutoWork=false,WorkMode="Arrest",WorkRange=20,MaxRange=500,Theme="Dark",Particles=true,PColor=Color3.fromRGB(80,170,255)}
local H={};local LG={};local GC=0;local BC=0;local LC=0;local LDC=0;local LSC=0;local SC=0;local WN=nil;local WI=nil;local PC=nil;local CT={};local KB={};local TE={};local ATE={};local PS={};local PR=false;local PP=false;local CF="default"
local function makeHL(obj,col)if not obj then return end;local hl=Instance.new("Highlight");hl.FillColor=col;hl.FillTransparency=0.25;hl.OutlineColor=Color3.fromRGB(255,255,255);hl.OutlineTransparency=0;hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;hl.Adornee=obj;hl.Parent=obj;return hl end
local function makeNPC_ESP(c,nt)if not c or not c.Parent then return end;if isPlayerChar(c)then return end;if H[c]then return end;local hrp=c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Torso")or c:FindFirstChildOfClass("Part");if not hrp then return end;if LP and LP.Character then local mp=LP.Character:FindFirstChild("HumanoidRootPart")or LP.Character:FindFirstChild("Torso");if mp and(hrp.Position-mp.Position).Magnitude>S.MaxRange then return end end;local col=nt=="Good"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,40,40);local tag=nt=="Good"and"👮 好人"or"💀 坏人";local hl=makeHL(c,col);local head=c:FindFirstChild("Head")or hrp;local bb=Instance.new("BillboardGui");bb.Adornee=head;bb.Size=UDim2.new(0,220,0,56);bb.StudsOffset=Vector3.new(0,5,0);bb.AlwaysOnTop=true;bb.MaxDistance=S.MaxRange;bb.Enabled=S.Enabled and(not S.BadOnly or nt=="Bad");bb.Parent=C;local ob=Instance.new("Frame");ob.Size=UDim2.new(1,4,1,4);ob.Position=UDim2.new(0,-2,0,-2);ob.BackgroundColor3=Color3.fromRGB(255,255,255);ob.BackgroundTransparency=0.85;ob.BorderSizePixel=0;ob.Parent=bb;Instance.new("UICorner",ob).CornerRadius=UDim.new(0,8);local bg=Instance.new("Frame");bg.Size=UDim2.new(1,0,1,0);bg.BackgroundColor3=Color3.fromRGB(0,0,0);bg.BackgroundTransparency=0.55;bg.BorderSizePixel=0;bg.Parent=bb;Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8);local lb=Instance.new("TextLabel");lb.Size=UDim2.new(1,-6,1,0);lb.Position=UDim2.new(0,3,0,0);lb.BackgroundTransparency=1;lb.TextColor3=col;lb.Font=Enum.Font.SourceSansBold;lb.TextScaled=true;lb.Text=tag;lb.BorderSizePixel=0;lb.Parent=bg;H[c]={bb=bb,lb=lb,hrp=hrp,nt=nt,tag=tag,hl=hl};SC=SC+1;if nt=="Good"then GC=GC+1 else BC=BC+1 end end
local function makeLuggage_ESP(lug,lt)if not lug or not lug.Parent then return end;if lug.Name~="OpenableLuggage"then return end;local pp=getLuggagePP(lug);if not pp then return end;local key=pp;if LG[key]then if LG[key].nt~=lt then LG[key].nt=lt;LG[key].tag=lt=="Dangerous"and"💣 危险行李"or(lt=="Safe"and"🧳 安全行李"or"❓ 可疑行李");if LG[key].lb then local col=lt=="Dangerous"and Color3.fromRGB(255,40,40)or(lt=="Safe"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,180,40));LG[key].lb.TextColor3=col;LG[key].lb.Text=LG[key].tag end;if LG[key].hl then LG[key].hl.FillColor=col end end;return end;local col=lt=="Dangerous"and Color3.fromRGB(255,40,40)or(lt=="Safe"and Color3.fromRGB(0,255,80)or Color3.fromRGB(255,180,40));local tag=lt=="Dangerous"and"💣 危险行李"or(lt=="Safe"and"🧳 安全行李"or"❓ 可疑行李");local hl=makeHL(lug,col);local bb=Instance.new("BillboardGui");bb.Adornee=pp;bb.Size=UDim2.new(0,220,0,56);bb.StudsOffset=Vector3.new(0,3,0);bb.AlwaysOnTop=true;bb.MaxDistance=S.MaxRange;bb.Enabled=S.Luggage;bb.Parent=C;local ob=Instance.new("Frame");ob.Size=UDim2.new(1,4,1,4);ob.Position=UDim2.new(0,-2,0,-2);ob.BackgroundColor3=Color3.fromRGB(255,255,255);ob.BackgroundTransparency=0.85;ob.BorderSizePixel=0;ob.Parent=bb;Instance.new("UICorner",ob).CornerRadius=UDim.new(0,8);local bg=Instance.new("Frame");bg.Size=UDim2.new(1,0,1,0);bg.BackgroundColor3=Color3.fromRGB(0,0,0);bg.BackgroundTransparency=0.55;bg.BorderSizePixel=0;bg.Parent=bb;Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8);local lb=Instance.new("TextLabel");lb.Size=UDim2.new(1,-6,1,0);lb.Position=UDim2.new(0,3,0,0);lb.BackgroundTransparency=1;lb.TextColor3=col;lb.Font=Enum.Font.SourceSansBold;lb.TextScaled=true;lb.Text=tag;lb.BorderSizePixel=0;lb.Parent=bg;LG[key]={bb=bb,lb=lb,pp=pp,nt=lt,tag=tag,hl=hl};LC=LC+1;if lt=="Dangerous"then LDC=LDC+1 elseif lt=="Safe"then LSC=LSC+1 end end
local function doScan()local seen={};for _,o in ipairs(W:GetDescendants())do if o:IsA("Humanoid")then local c=o.Parent;if c and c:IsA("Model")and not seen[c]then seen[c]=true;if not isPlayerChar(c)then local nt=classify(c);makeNPC_ESP(c,nt)end end end end end
local function rescanLuggage()for _,o in pairs(LG)do pcall(function()if o.bb then o.bb:Destroy()end;if o.hl then o.hl:Destroy()end end)end;LG={};LC=0;LDC=0;LSC=0;local seenPP={};local wsf=W:FindFirstChild("WorkspaceScriptable");if wsf then local sto=wsf:FindFirstChild("Storage");if sto then local ns=sto:FindFirstChild("NormalStorage");if ns then for _,fn in ipairs({"LuggageWorkspace","LuggageOpenWorkspace","LuggageEndWorkspace"})do local fw=ns:FindFirstChild(fn);if fw then for _,lug in ipairs(fw:GetChildren())do if lug:IsA("Model")and lug.Name=="OpenableLuggage"then local pp=getLuggagePP(lug);if pp and not seenPP[pp]then seenPP[pp]=true;local lt=classifyLuggage(lug);makeLuggage_ESP(lug,lt)end end end end end end end end;if LC==0 then for _,o in ipairs(W:GetDescendants())do if o:IsA("Model")and o.Name=="OpenableLuggage"and o.Parent and o.Parent:IsA("Folder")then local pp=getLuggagePP(o);if pp and not seenPP[pp]then seenPP[pp]=true;local lt=classifyLuggage(o);makeLuggage_ESP(o,lt)end end end end end
local function refreshESP()for c,o in pairs(H)do if not c or not c.Parent then pcall(function()if o.bb then o.bb:Destroy()end;if o.hl then o.hl:Destroy()end end);H[c]=nil else local en=S.Enabled and(not S.BadOnly or o.nt=="Bad");if o.bb then o.bb.Enabled=en end;if o.hl then o.hl.Enabled=en end;if o.lb then local txt=o.tag;if S.ShowDist and LP.Character then local mp=LP.Character:FindFirstChild("HumanoidRootPart");if mp and o.hrp then txt=txt.." | "..math.floor((o.hrp.Position-mp.Position).Magnitude+0.5).."m"end end;if S.ShowHP then local h2=c:FindFirstChildOfClass("Humanoid");if h2 then txt=txt.." | HP:"..math.floor(h2.Health+0.5).."/"..math.floor(h2.MaxHealth+0.5)end end;o.lb.Text=txt end end end;for _,o in pairs(LG)do if o.bb then o.bb.Enabled=S.Luggage end;if o.hl then o.hl.Enabled=S.Luggage end end end
local function updateStats()GC=0;BC=0;SC=0;LC=0;LDC=0;LSC=0;for _,o in pairs(H)do SC=SC+1;if o.nt=="Good"then GC=GC+1 else BC=BC+1 end end;for _,o in pairs(LG)do LC=LC+1;if o.nt=="Dangerous"then LDC=LDC+1 elseif o.nt=="Safe"then LSC=LSC+1 end end;pcall(function()if TE.GP then TE.GP:SetTitle("🟢 好人: "..GC)end;if TE.BP then TE.BP:SetTitle("🔴 坏人: "..BC)end;if TE.LP then TE.LP:SetTitle("🧳 行李: "..LC.." (💣"..LDC.." 🟢"..LSC..")")end;if TE.SP then TE.SP:SetTitle("📊 总计: "..SC)end end)end

-- ====== 自动工作 v3 ======
local WORK_BUSY={}

-- 查找NPC的行李箱在OpenWorkspace中(正在被检查)
local function getNPCLuggage(npc)
    if not npc then return nil end
    local wsf=W:FindFirstChild("WorkspaceScriptable")
    if not wsf then return nil end
    local sto=wsf:FindFirstChild("Storage")
    if not sto then return nil end
    local ns=sto:FindFirstChild("NormalStorage")
    if not ns then return nil end
    -- 重点查OpenWorkspace（正在被检查的行李箱）
    local ow=ns:FindFirstChild("LuggageOpenWorkspace")
    if not ow then return nil end
    for _,lug in ipairs(ow:GetChildren())do
        if lug:IsA("Model")and lug.Name=="OpenableLuggage"then
            -- 检查是否属于这个NPC（LinkedLuggage指向NPC）
            local pr=lug:FindFirstChild("Properties")
            if pr then
                local ll=rFind(pr,"LinkedLuggage")
                if ll and ll:IsA("ObjectValue")and ll.Value==npc then return lug end
            end
        end
    end
    return nil
end

-- 扫描附近NPC(找正在接受检查的)
local function scanCheckedNPCs()
    local results={}
    if not LP or not LP.Character then return results end
    local mp=LP.Character:FindFirstChild("HumanoidRootPart")or LP.Character:FindFirstChild("Torso")
    if not mp then return results end
    for _,o in ipairs(W:GetDescendants())do
        if o:IsA("Humanoid")then
            local m=o.Parent
            if m and m:IsA("Model")and not isPlayerChar(m)then
                local hrp=m:FindFirstChild("HumanoidRootPart")or m:FindFirstChild("Torso")
                if hrp then
                    local d=(hrp.Position-mp.Position).Magnitude
                    if d<=S.WorkRange then
                        local luggage=getNPCLuggage(m)
                        if luggage then
                            local lt=classifyLuggage(luggage)
                            table.insert(results,{model=m,hrp=hrp,hum=o,dist=d,nt=lt=="Dangerous"and"Bad"or"Good",luggage=luggage})
                        end
                    end
                end
            end
        end
    end
    table.sort(results,function(a,b)return a.dist<b.dist end)
    return results
end

-- 取武器并开火
local function equipAndFire(weaponName)
    if not LP then return end
    local back=LP:FindFirstChild("Backpack")
    local function findW()
        if back then for _,t in ipairs(back:GetChildren())do if t:IsA("Tool")and t.Name==weaponName then return t end end end
        if LP.Character then for _,t in ipairs(LP.Character:GetChildren())do if t:IsA("Tool")and t.Name==weaponName then return t end end end
        return nil
    end
    local t=findW()
    if not t then return false end
    pcall(function()t.Parent=LP.Character end)
    task.wait(0.15)
    pcall(function()t:Activate()end)
    task.wait(0.1)
    -- 模拟鼠标左键点击
    pcall(function()VIM:SendMouseButtonEvent(0,0,0,true,game,1)end)
    task.wait(0.05)
    pcall(function()VIM:SendMouseButtonEvent(0,0,0,false,game,1)end)
    return true
end

-- 传送NPC到监狱
local function tpToJail(npc)
    local pos=findJail()
    if not pos then return false end
    local hrp=npc:FindFirstChild("HumanoidRootPart")or npc:FindFirstChild("Torso")
    if hrp then
        pcall(function()hrp.CFrame=CFrame.new(pos)end)
        return true
    end
    return false
end

-- 逮捕
local function doArrest(npc)
    local hum=npc:FindFirstChildOfClass("Humanoid")
    -- 通道1: MarkArrest
    if MarkArrest then pcall(function()MarkArrest:FireServer(npc)end);task.wait(0.3)end
    -- 通道2: NPCArrest
    if NPCArrest then pcall(function()NPCArrest:FireServer(npc)end);task.wait(0.5)end
    -- 通道3: ProductArrest
    if ProductArrest then pcall(function()ProductArrest:FireServer(npc)end);task.wait(0.3)end
    -- 通道4: Arrest工具
    equipAndFire("Arrest")
    task.wait(0.5)
    -- 通道5: 直接传送
    tpToJail(npc)
end

-- 放行
local function doRelease(npc)
    if MarkSearch then
        pcall(function()MarkSearch:FireServer(npc)end)
        local hum=npc:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function()MarkSearch:FireServer(hum)end)end
    end
    equipAndFire("Arrest")
    task.wait(0.2)
    -- 尝试用物品栏
    local back=LP:FindFirstChild("Backpack")
    if back then
        for _,t in ipairs(back:GetChildren())do
            if t:IsA("Tool")and t.Name=="Arrest"then
                pcall(function()t.Parent=LP.Character end)
                task.wait(0.2)
                pcall(function()t:Activate()end)
                break
            end
        end
    end
end

-- 击杀
local function doKill(npc)
    local hum=npc:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health<=0 then return end
    -- 换武器射击
    for _,wn in ipairs({"MP7A1","M1911","Taser"})do
        if equipAndFire(wn)then break end
    end
    -- 连续射击
    for i=1,5 do
        task.wait(0.1)
        pcall(function()VIM:SendMouseButtonEvent(0,0,0,true,game,1)end)
        task.wait(0.05)
        pcall(function()VIM:SendMouseButtonEvent(0,0,0,false,game,1)end)
    end
end

-- 主处理
local function autoProcess()
    if not S.AutoWork then return end
    local mode=S.WorkMode
    if mode=="Release"then
        -- 只放行
        local list=scanCheckedNPCs()
        for _,n in ipairs(list)do
            if n.nt=="Good"and not WORK_BUSY[n.model]then
                WORK_BUSY[n.model]=true
                task.spawn(function()
                    pcall(function()if ATE.ST then ATE.ST:Set("[放行] "..n.model.Name.." ✅")end end)
                    doRelease(n.model)
                    task.wait(0.5);WORK_BUSY[n.model]=nil
                end)
            end
        end
        return
    end
    
    local list=scanCheckedNPCs()
    if #list==0 then
        pcall(function()if ATE.ST then ATE.ST:Set("[空闲] 附近无正在检查的NPC")end end)
        return
    end
    
    for _,n in ipairs(list)do
        if WORK_BUSY[n.model]then continue end
        WORK_BUSY[n.model]=true
        local nm=n.model.Name
        task.spawn(function()
            local nt=n.nt
            if nt=="Bad"then
                if mode=="Kill"then
                    pcall(function()if ATE.ST then ATE.ST:Set("[击杀] "..nm)end end)
                    doKill(n.model)
                else -- Arrest/Auto
                    pcall(function()if ATE.ST then ATE.ST:Set("[逮捕] "..nm)end end)
                    doArrest(n.model)
                    if mode=="Auto"then
                        task.wait(1)
                        local hostile=scanProps(n.model)
                        if hostile then
                            pcall(function()if ATE.ST then ATE.ST:Set("[反击] "..nm.." 击杀")end end)
                            doKill(n.model)
                        end
                    end
                end
                -- 检查Done
                if nt=="Good"and(mode=="Auto")then
                    pcall(function()if ATE.ST then ATE.ST:Set("[放行] "..nm.." ✅")end end)
                    doRelease(n.model)
                end
            end
            pcall(function()if ATE.ST then ATE.ST:Set("[完成] "..nm)end end)
            task.wait(1);WORK_BUSY[n.model]=nil
        end)
    end
    
    -- Auto模式下也放行好人
    if mode=="Auto"then
        for _,n in ipairs(list)do
            if n.nt=="Good"and not WORK_BUSY[n.model]then
                WORK_BUSY[n.model]=true
                task.spawn(function()
                    pcall(function()if ATE.ST then ATE.ST:Set("[放行] "..n.model.Name.." ✅")end end)
                    doRelease(n.model)
                    task.wait(0.5);WORK_BUSY[n.model]=nil
                end)
            end
        end
    end
end

local function startAutoWorkLoop()
    while true do
        task.wait(2)
        pcall(function()
            if S.AutoWork then autoProcess()
            elseif ATE.ST then ATE.ST:Set("[停止] 自动工作已关闭")end
        end)
    end
end

-- 粒子
local function updateParticleColors()local col=S.PColor;for _,p in ipairs(PS)do if p.F and p.F.Parent then p.F.BackgroundColor3=col end end end
local function mkParts()if not PP then return end;if PC then return end;task.wait(0.5);local sg=Instance.new("ScreenGui");sg.Name="ESP_Particles";sg.ResetOnSpawn=false;sg.DisplayOrder=999999;sg.IgnoreGuiInset=true;sg.Parent=C;PC=Instance.new("Frame");PC.Size=UDim2.new(1,0,1,0);PC.BackgroundTransparency=1;PC.BorderSizePixel=0;PC.Active=false;PC.Parent=sg;local col=S.PColor;for i=1,50 do local d=Instance.new("Frame");local sz=math.random(5,10);d.Size=UDim2.new(0,sz,0,sz);local sx=0.2+math.random()*0.6;local sy=0.2+math.random()*0.6;d.Position=UDim2.new(sx,0,sy,0);d.BackgroundColor3=col;d.BackgroundTransparency=0.3+math.random()*0.5;d.BorderSizePixel=0;d.Parent=PC;Instance.new("UICorner",d).CornerRadius=UDim.new(0,10);local a=math.random()*6.28;local sp=0.0008+math.random()*0.002;table.insert(PS,{F=d,Sx=sx,Sy=sy,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})end;PR=true;task.spawn(function()local t=0;while PR and PC do t=t+0.03;pcall(function()local curCol=S.PColor;for _,p in ipairs(PS)do if p.F and p.F.Parent then local sx=math.max(0.05,math.min(0.95,p.Sx+p.Vx));local sy=math.max(0.05,math.min(0.95,p.Sy+p.Vy));if sx>=0.95 or sx<=0.05 then p.Vx=-p.Vx end;if sy>=0.95 or sy<=0.05 then p.Vy=-p.Vy end;p.Sx=sx;p.Sy=sy;p.F.Position=UDim2.new(sx,0,sy,0);if curCol~=p.F.BackgroundColor3 then p.F.BackgroundColor3=curCol end;p.F.BackgroundTransparency=0.3+math.sin(t*0.8+p.Ph)*0.4;local bs=math.max(2,p.Sz+math.sin(t+p.Ph)*1.5);p.F.Size=UDim2.new(0,bs,0,bs)end end end);task.wait(0.03)end end)end
local function killParts()PR=false;if PC then pcall(function()local p=PC.Parent;if p then p:Destroy()end end);PC=nil end;PS={}end
local function gtc(n)if not n then return Color3.fromRGB(80,170,255)end;local l=n:lower();local m={dark=Color3.fromRGB(80,170,255),light=Color3.fromRGB(60,130,210),rose=Color3.fromRGB(255,130,170),plant=Color3.fromRGB(70,210,130),ocean=Color3.fromRGB(60,190,240),sunset=Color3.fromRGB(255,160,70),midnight=Color3.fromRGB(130,100,240),forest=Color3.fromRGB(60,180,90),lavender=Color3.fromRGB(190,140,255),coral=Color3.fromRGB(255,140,90),mint=Color3.fromRGB(80,230,190),sky=Color3.fromRGB(100,190,255),blood=Color3.fromRGB(230,90,80),lemon=Color3.fromRGB(230,210,70),cyber=Color3.fromRGB(0,235,210)};if m[l]then return m[l]end;if l:find("dark")then return Color3.fromRGB(80,170,255)end;if l:find("rose")or l:find("pink")then return Color3.fromRGB(255,130,170)end;if l:find("plant")or l:find("green")then return Color3.fromRGB(70,210,130)end;if l:find("ocean")or l:find("blue")or l:find("sky")then return Color3.fromRGB(60,190,240)end;if l:find("sunset")or l:find("orange")then return Color3.fromRGB(255,160,70)end;if l:find("midnight")or l:find("purple")or l:find("lavender")then return Color3.fromRGB(130,100,240)end;if l:find("blood")or l:find("red")then return Color3.fromRGB(230,90,80)end;if l:find("lemon")or l:find("yellow")then return Color3.fromRGB(230,210,70)end;return Color3.fromRGB(80,170,255)end

local function makeWindow()
    local ok2,w=pcall(function()return WI:CreateWindow({Title="机场安全透视",Author="b站英吉利超入_",Icon="solar:shield-warning-bold",Size=UDim2.fromOffset(750,520),ToggleKey=Enum.KeyCode.RightShift,Folder="airport-esp",Acrylic=true,Transparent=true,Resizable=false,SideBarWidth=180,ScrollBarEnabled=true,HideSearchBar=true,OpenButton={Title="打开透视",Scale=0.5,Enabled=true,OnlyMobile=IM,Draggable=true,Color=ColorSequence.new(Color3.fromRGB(0,255,100),Color3.fromRGB(0,200,255)),CornerRadius=UDim.new(1,0),StrokeThickness=3},OnClose=function()S.Enabled=false;S.Luggage=false;S.AutoWork=false;if CT.ESP then CT.ESP:Set(false)end;if CT.LT then CT.LT:Set(false)end;if CT.AW then CT.AW:Set(false)end;refreshESP();killParts()end,OnOpen=function()if S.Particles then task.spawn(function()task.wait(0.5);mkParts()end)end end})end)
    if not ok2 or not w then return end;WN=w
    local mt=WN:Tab({Title="主控面板",Icon="solar:slider-vertical-bold"})
    CT.ESP=mt:Toggle({Flag="ESP",Title="透视开关",Value=false,Callback=function(v)S.Enabled=v;refreshESP();if v then task.spawn(doScan)end end})
    CT.BO=mt:Toggle({Flag="BadOnly",Title="仅显示坏人",Value=false,Callback=function(v)S.BadOnly=v;refreshESP()end});mt:Divider()
    CT.LT=mt:Toggle({Flag="Luggage",Title="🧳 行李箱检测",Value=false,Callback=function(v)S.Luggage=v;if v then task.spawn(rescanLuggage)else for _,o in pairs(LG)do pcall(function()if o.bb then o.bb:Destroy()end;if o.hl then o.hl:Destroy()end end)end;LG={};LC=0;LDC=0;LSC=0 end end})
    mt:Divider();CT.DT=mt:Toggle({Flag="Dist",Title="显示距离",Value=false,Callback=function(v)S.ShowDist=v end});CT.HT=mt:Toggle({Flag="Health",Title="显示血量",Value=false,Callback=function(v)S.ShowHP=v end});mt:Divider()
    CT.RS=mt:Slider({Flag="Range",Title="最大探测距离",Step=50,Value={Min=50,Max=1000,Default=500},Width=200,IsTextbox=true,Callback=function(v)S.MaxRange=v end})
    local ft=WN:Tab({Title="功能设置",Icon="solar:settings-bold"})
    CT.EK=ft:Keybind({Flag="ESPK",Title="透视开关快捷键",Value="",Callback=function(k)KB.ESP=k end});CT.BK=ft:Keybind({Flag="BadK",Title="仅坏人快捷键",Value="",Callback=function(k)KB.BadOnly=k end})
    local awt=WN:Tab({Title="自动工作",Icon="solar:police-car-bold"})
    CT.AW=awt:Toggle({Flag="AutoWork",Title="自动模式",Value=false,Callback=function(v)S.AutoWork=v end});awt:Divider()
    CT.WM=awt:Dropdown({Flag="WorkMode",Title="工作模式",Values={"Arrest","Kill","Release","Auto"},Value="Arrest",Callback=function(v)S.WorkMode=v end})
    CT.WR=awt:Slider({Flag="WorkRange",Title="工作范围(米)",Step=5,Value={Min=5,Max=50,Default=20},Width=180,IsTextbox=true,Callback=function(v)S.WorkRange=v end});awt:Divider()
    ATE.ST=awt:Input({Flag="WS",Title="状态",Value="[等待启动]",Locked=true,Icon="solar:info-circle-bold"});awt:Space()
    awt:Paragraph({Title="📋 工作说明",Desc="只处理正在接受检查的NPC\nArrest=逮捕+送监狱\nKill=击杀\nRelease=放行好人\nAuto=全自动"})
    local ut=WN:Tab({Title="UI设置",Icon="solar:monitor-bold"})
    CT.WK=ut:Keybind({Flag="WinK",Title="窗口开关",Value="RightShift",Callback=function(k)KB.Win=k end});ut:Divider()
    CT.PT=ut:Toggle({Flag="PT",Title="粒子背景",Value=true,Callback=function(v)S.Particles=v;if v then task.spawn(mkParts)else killParts()end end});ut:Divider()
    CT.AT=ut:Toggle({Flag="AT",Title="毛玻璃",Value=true,Callback=function(v)pcall(function()WI:ToggleAcrylic(v)end)end})
    CT.TT=ut:Toggle({Flag="TT",Title="透明背景",Value=true,Callback=function(v)pcall(function()if WN then WN:ToggleTransparency(v)end end)end});ut:Divider()
    local allT={};pcall(function()allT=WI:GetThemes()end);local tn={};for n,_ in pairs(allT)do table.insert(tn,n)end;table.sort(tn)
    CT.TD=ut:Dropdown({Flag="TD",Title="选择主题",Values=tn,Value="Dark",Callback=function(sl)if sl and type(sl)=="string"then S.Theme=sl;WI:SetTheme(sl);S.PColor=gtc(sl);updateParticleColors()end end})
    local st=WN:Tab({Title="信息统计",Icon="solar:chart-bold"})
    TE.GP=st:Paragraph({Title="🟢 好人: 0"});TE.BP=st:Paragraph({Title="🔴 坏人: 0"});TE.LP=st:Paragraph({Title="🧳 行李: 0"});TE.SP=st:Paragraph({Title="📊 总计: 0"})
    local ct=WN:Tab({Title="配置管理",Icon="solar:diskette-bold"})
    local cni=ct:Input({Flag="CN",Title="配置名称",Value="default",Icon="solar:file-text-bold",Callback=function(v)CF=v end});ct:Space()
    local CM=WN.ConfigManager;local AC={};pcall(function()AC=CM:AllConfigs()end);local DV=nil;pcall(function()for _,v in ipairs(AC)do if v=="default"then DV="default";break end end end)
    local ACD=ct:Dropdown({Title="已有配置",Values=AC,Value=DV,Callback=function(v)if v then CF=v;cni:Set(v)end end});ct:Space()
    ct:Button({Title="💾 保存",Icon="solar:check-circle-bold",Justify="Center",Color=Color3.fromHex("#305dff"),Callback=function()if not CM then return end;local c=CM:Config(CF);if c and c:Save()then WI:Notify({Title="✅ 已保存",Content="配置'"..CF.."'",Duration=3,Icon="solar:check-circle-bold"});ACD:Refresh(CM:AllConfigs())end end});ct:Space()
    ct:Button({Title="📂 加载",Icon="solar:refresh-circle-bold",Justify="Center",Color=Color3.fromHex("#10C550"),Callback=function()if not CM then return end;local c=CM:CreateConfig(CF,false);if c and c:Load()then WI:Notify({Title="✅ 已加载",Content="配置'"..CF.."'",Duration=3,Icon="solar:refresh-circle-bold"})end end});ct:Space()
    ct:Button({Title="🗑️ 删除",Icon="solar:trash-bin-trash-bold",Justify="Center",Color=Color3.fromHex("#ff3040"),Callback=function()if not CM then return end;local c=CM:Config(CF);if c and c:Delete()then WI:Notify({Title="🗑️ 已删除",Content="配置'"..CF.."'",Duration=3,Icon="solar:trash-bin-trash-bold"});ACD:Refresh(CM:AllConfigs())end end})
    task.spawn(function()task.wait(1);pcall(function()CM:CreateConfig("default",true)end);task.spawn(mkParts)end)
    local at=WN:Tab({Title="关于",Icon="solar:info-square-bold"});at:Paragraph({Title="机场安全透视 v15.3",Desc="智能检查AutoWork"});at:Divider();at:Paragraph({Title="👤 作者",Desc="b站英吉利超入_"});at:Divider();at:Paragraph({Title="💡 使用",Desc=IM and"手机:点击悬浮按钮"or"PC:RightShift打开菜单"})
    U.InputBegan:Connect(function(i,g)if g then return end;if i.UserInputType~=Enum.UserInputType.Keyboard then return end;local k=i.KeyCode.Name;if KB.ESP and KB.ESP~=""and k==KB.ESP then S.Enabled=not S.Enabled;if CT.ESP then CT.ESP:Set(S.Enabled)end;refreshESP();if S.Enabled then task.spawn(doScan)end end;if KB.BadOnly and KB.BadOnly~=""and k==KB.BadOnly then S.BadOnly=not S.BadOnly;if CT.BO then CT.BO:Set(S.BadOnly)end;refreshESP()end end)
    task.spawn(function()while true do task.wait(3);pcall(function()doScan();refreshESP();updateStats()end)end end)
    task.spawn(startAutoWorkLoop)
end
local retryCount=0;local maxRetries=3;local loaded=false
while retryCount<maxRetries and not loaded do local ok,rv=pcall(function()return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()end);if ok and rv then WI=rv;loaded=true else retryCount=retryCount+1;if retryCount<maxRetries then task.wait(1)end end end
if loaded then pcall(function()WI:SetTheme("Dark")end);S.PColor=gtc("Dark");WI:Popup({Title="机场安全透视 v15.3",Icon="solar:info-square-bold",Content="👁 NPC透视\n🔴🟢 红坏人/绿好人\n🧳 行李箱检测\n🚔 智能检查:逮捕/击杀/放行/全自动\n🌀 粒子背景\n⚠️ 功能默认关闭",Buttons={{Title="取消",Callback=function()end,Variant="Tertiary"},{Title="确认加载",Icon="solar:arrow-right-bold",Callback=function()PP=true;WI:Notify({Title="✅ 已加载",Content="按RightShift打开菜单",Duration=4,Icon="solar:bell-bold"});task.spawn(makeWindow)end,Variant="Primary"}}})
 while not PP do task.wait(0.5)end
else local msg=Instance.new("Message");msg.Text="⚠️ WindUI加载失败(已重试"..maxRetries.."次)";msg.Parent=W;task.delay(4,function()msg:Destroy()end)end
