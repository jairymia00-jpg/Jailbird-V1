-- JAILBIRD V3 | Enhanced tabbed control center (experimental)
-- Experimental: replicated character data only; no live-game validation.
-- Aim lock: enable in the menu, then hold Right Mouse (default). F1 shows/hides the menu.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then error('Client context required') end
local pg = LocalPlayer:WaitForChild('PlayerGui')
if type(_G.JailbirdV3Stop) == 'function' then pcall(_G.JailbirdV3Stop) end
if type(_G.JailbirdV33Stop) == 'function' then pcall(_G.JailbirdV33Stop) end
if type(_G.JailbirdV1Stop) == 'function' then pcall(_G.JailbirdV1Stop) end




local old = pg:FindFirstChild('JailbirdV1Visual')
if old then old:Destroy() end
local alive = true
local connections, visuals = {}, {}
local cfg = {ESP=true, Boxes=true, Skeleton=true, Health=true, Names=true, Distance=true, FOV=true, Target=true, TeamCheck=true, Radius=160, Range=1800, TargetBone='Head', VisibilityCheck=true, TargetHighlight=true}
cfg.AimLock=false
cfg.AimKey=Enum.UserInputType.MouseButton2
cfg.AimSmooth=36 -- Faster default response per second; 0 gives an instant lock.
cfg.LockRadiusScale=1.35 -- Acquisition uses the circle; held targets have a small release margin.
cfg.LockGrace=.15 -- Retain the target briefly while blocked/missing/outside, without aiming.
cfg.SwitchDelay=.08 -- Require a replacement target to stay valid before switching.
local aimHeld=false
local hotkeyCount=0
local aimNotice='Ready'
local lockedPlayer,lockedCharacter=nil,nil
local lockedPart=nil
local pendingPlayer,pendingCharacter,pendingFor=nil,nil,0
local hasAcquired=false
local lostFor=0
local lockTracking=false
local renderName='JailbirdV33AimLock'
local function clearLock()
    lockedPlayer=nil
    lockedCharacter=nil
    lockedPart=nil
    lostFor=0
    lockTracking=false
end
local function clearPending()
    pendingPlayer=nil
    pendingCharacter=nil
    pendingFor=0
end
local function releaseAim()
    aimHeld=false
    hasAcquired=false
    clearLock()
    clearPending()
end
local purple = Color3.fromRGB(170,105,255)
local red = Color3.fromRGB(255,90,115)
local white = Color3.fromRGB(244,241,255)
local function make(class, props, parent)
    local inst=Instance.new(class)
    for k,v in pairs(props or {}) do inst[k]=v end
    inst.Parent=parent
    return inst
end
local gui=make('ScreenGui',{Name='JailbirdV1Visual',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=900},pg)
-- V2 UI: glass-like dark panel, purple accent, improved spacing and hover states.
local menu=make('Frame',{Size=UDim2.fromOffset(410,560),Position=UDim2.fromOffset(25,90),BackgroundColor3=Color3.fromRGB(15,16,27),BorderSizePixel=0,ClipsDescendants=true},gui)
make('UICorner',{CornerRadius=UDim.new(0,16)},menu)
make('UIStroke',{Color=Color3.fromRGB(108,79,180),Thickness=1.5,Transparency=.12},menu)
make('UIGradient',{Color=ColorSequence.new(Color3.fromRGB(28,23,48),Color3.fromRGB(12,15,25)),Rotation=110},menu)
local accent=make('Frame',{Size=UDim2.new(1,0,0,4),BackgroundColor3=purple,BorderSizePixel=0},menu)
make('UIGradient',{Color=ColorSequence.new(Color3.fromRGB(107,77,255),Color3.fromRGB(231,92,255))},accent)
local title=make('TextLabel',{Active=true,Position=UDim2.fromOffset(17,12),Size=UDim2.new(1,-72,0,27),BackgroundTransparency=1,Text='JAILBIRD  /  V3.1',TextXAlignment=Enum.TextXAlignment.Left,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=20},menu)
local subtitle=make('TextLabel',{Position=UDim2.fromOffset(18,39),Size=UDim2.new(1,-40,0,18),BackgroundTransparency=1,Text='NEBULA EDITION   /   F1 TO TOGGLE',TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.fromRGB(157,146,184),Font=Enum.Font.GothamMedium,TextSize=10},menu)
local minimize=make('TextButton',{Position=UDim2.new(1,-44,0,15),Size=UDim2.fromOffset(28,26),BackgroundColor3=Color3.fromRGB(48,39,70),Text='–',TextColor3=white,Font=Enum.Font.GothamBold,TextSize=19,BorderSizePixel=0},menu)
make('UICorner',{CornerRadius=UDim.new(0,7)},minimize)
local scroll=make('ScrollingFrame',{Position=UDim2.fromOffset(13,116),Size=UDim2.new(1,-26,1,-130),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=purple,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},menu)
make('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},scroll)
local collapsed=false
local function setCollapsed(value)
    collapsed=value
    scroll.Visible=not value
    menu.Size=value and UDim2.fromOffset(410,66) or UDim2.fromOffset(410,560)
    minimize.Text=value and '+' or '–'
end
table.insert(connections,minimize.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end))
local currentTab='Visuals'
local tabItems={Visuals={},Targeting={},Aim={},Status={}}
local tabButtons={}
local activeSection='Visuals'
local function registerTabItem(obj)
    table.insert(tabItems[activeSection],obj)
    obj.Visible=(activeSection==currentTab)
    return obj
end
local tabBar=make('Frame',{Position=UDim2.fromOffset(13,72),Size=UDim2.new(1,-26,0,36),BackgroundTransparency=1},menu)
make('UIListLayout',{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},tabBar)
local function selectTab(name)
    currentTab=name
    for tab,items in pairs(tabItems) do
        for _,obj in ipairs(items) do obj.Visible=(tab==name) end
    end
    for tab,b in pairs(tabButtons) do
        b.BackgroundColor3=(tab==name) and Color3.fromRGB(112,71,205) or Color3.fromRGB(37,34,57)
        b.TextColor3=(tab==name) and white or Color3.fromRGB(184,172,208)
    end
    scroll.CanvasPosition=Vector2.new(0,0)
end
for _,tab in ipairs({'Visuals','Targeting','Aim','Status'}) do
    local b=make('TextButton',{Size=UDim2.new(.25,-4,1,0),BackgroundColor3=Color3.fromRGB(37,34,57),Text=tab,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,AutoButtonColor=false},tabBar)
    make('UICorner',{CornerRadius=UDim.new(0,8)},b)
    tabButtons[tab]=b
    table.insert(connections,b.MouseButton1Click:Connect(function() selectTab(tab) end))
end
local function section(name)
    return registerTabItem(make('TextLabel',{Size=UDim2.new(1,-6,0,25),BackgroundTransparency=1,Text='  '..name:upper(),TextColor3=Color3.fromRGB(174,141,255),Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left},scroll))
end
local function button(txt)
    local b=make('TextButton',{Size=UDim2.new(1,-6,0,35),BackgroundColor3=Color3.fromRGB(39,36,59),TextColor3=white,Text=txt,Font=Enum.Font.GothamMedium,TextSize=12,BorderSizePixel=0,AutoButtonColor=false},scroll)
    make('UICorner',{CornerRadius=UDim.new(0,9)},b)
    make('UIStroke',{Color=Color3.fromRGB(91,75,133),Thickness=1,Transparency=.55},b)
    table.insert(connections,b.MouseEnter:Connect(function() b.BackgroundColor3=Color3.fromRGB(59,48,89) end))
    table.insert(connections,b.MouseLeave:Connect(function() b.BackgroundColor3=Color3.fromRGB(39,36,59) end))
    return registerTabItem(b)
end
section('Player visuals')
for _,entry in ipairs({{'Enemy ESP','ESP'},{'Boxes','Boxes'},{'Skeleton','Skeleton'},{'Health','Health'},{'Names','Names'},{'Distance','Distance'},{'FOV circle','FOV'},{'Aim assist indicator','Target'},{'Target highlight','TargetHighlight'},{'Visibility check','VisibilityCheck'},{'Team filter','TeamCheck'}}) do
    local label,key=entry[1],entry[2]
    local b=button('')
    local function refresh() b.Text=label..': '..(cfg[key] and 'ON' or 'OFF'); b.TextColor3=cfg[key] and purple or white end
    refresh()
    table.insert(connections,b.MouseButton1Click:Connect(function() cfg[key]=not cfg[key];refresh() end))
end
activeSection='Targeting'
section('Display and targeting')
local radius=button('')
local function radiusText() radius.Text='FOV radius: '..cfg.Radius..' px (click)' end
radiusText()
table.insert(connections,radius.MouseButton1Click:Connect(function() cfg.Radius=cfg.Radius+25; if cfg.Radius>350 then cfg.Radius=75 end;radiusText() end))
local boneButton=button('')
local function boneText() boneButton.Text='Target bone: '..cfg.TargetBone..' (click)' end
boneText()
table.insert(connections,boneButton.MouseButton1Click:Connect(function()
    cfg.TargetBone=cfg.TargetBone=='Head' and 'Body' or (cfg.TargetBone=='Body' and 'Auto' or 'Head')
    lockedPart=nil
    clearPending()
    boneText()
end))
local range=button('')
local function rangeText() range.Text='ESP / aim range: '..cfg.Range..' studs (click)' end
rangeText()
table.insert(connections,range.MouseButton1Click:Connect(function() cfg.Range=cfg.Range+400;if cfg.Range>3000 then cfg.Range=600 end;rangeText() end))
-- Add aim controls after the existing controls; keep the original panel and visual settings.
activeSection='Aim'
section('Aim settings')
local aimToggle=button('')
local function aimToggleText()
    aimToggle.Text='Aim lock: '..(cfg.AimLock and 'ON (click to toggle)' or 'OFF')
    aimToggle.TextColor3=cfg.AimLock and purple or white
end
aimToggleText()
table.insert(connections,aimToggle.MouseButton1Click:Connect(function()
    cfg.AimLock=not cfg.AimLock
    releaseAim()
    aimToggleText()
end))
local aimKeys={
    {value=Enum.UserInputType.MouseButton2,label='Right Mouse'},
    {value=Enum.KeyCode.Q,label='Q'},
    {value=Enum.KeyCode.E,label='E'},
    {value=Enum.KeyCode.LeftAlt,label='Left Alt'}
}
local aimKeyIndex=1
local aimKeyButton=button('')
local function aimKeyText() aimKeyButton.Text='Toggle key: '..aimKeys[aimKeyIndex].label..' (click)' end
aimKeyText()
table.insert(connections,aimKeyButton.MouseButton1Click:Connect(function()
    aimKeyIndex=aimKeyIndex%#aimKeys+1
    cfg.AimKey=aimKeys[aimKeyIndex].value
    releaseAim()
    aimKeyText()
end))
local aimSpeeds={{value=6,label='Smooth'},{value=18,label='Medium'},{value=36,label='Fast'},{value=0,label='Instant'}}
local aimSpeedIndex=3
local aimSpeedButton=button('')
local function aimSpeedText() aimSpeedButton.Text='Lock response: '..aimSpeeds[aimSpeedIndex].label..' (click)' end
aimSpeedText()
table.insert(connections,aimSpeedButton.MouseButton1Click:Connect(function()
    aimSpeedIndex=aimSpeedIndex%#aimSpeeds+1
    cfg.AimSmooth=aimSpeeds[aimSpeedIndex].value
    aimSpeedText()
end))
local switchDelays={0,.08,.15,.25}
local switchDelayIndex=2
local switchDelayButton=button('')
local function switchDelayText()
    switchDelayButton.Text='Target switch delay: '..math.floor(cfg.SwitchDelay*1000+.5)..' ms (click)'
end
switchDelayText()
table.insert(connections,switchDelayButton.MouseButton1Click:Connect(function()
    switchDelayIndex=switchDelayIndex%#switchDelays+1
    cfg.SwitchDelay=switchDelays[switchDelayIndex]
    clearPending()
    switchDelayText()
end))
local function isAimInput(input)
    return input.UserInputType==cfg.AimKey or input.KeyCode==cfg.AimKey
end
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if not alive or UIS:GetFocusedTextBox() then return end
    if cfg.AimLock and isAimInput(input) then
        -- MouseButton2 can be marked processed by camera controls.
        if processed and input.UserInputType~=Enum.UserInputType.MouseButton2 then return end
        if aimHeld then
            releaseAim()
            aimNotice='Toggle OFF'
        else
            aimHeld=true
            aimNotice='Toggle ON: seeking target'
        end
        hotkeyCount=hotkeyCount+1
    end
end))
-- Aim input is toggle-based: releasing the button does not disable aim.
table.insert(connections,UIS.WindowFocusReleased:Connect(releaseAim))
table.insert(connections,UIS.TextBoxFocused:Connect(releaseAim))
table.insert(connections,LocalPlayer.CharacterRemoving:Connect(releaseAim))
activeSection='Status'
section('Live status')
local status=registerTabItem(make('TextLabel',{Size=UDim2.new(1,-6,0,105),BackgroundTransparency=1,Text='Waiting for players...',TextWrapped=true,TextColor3=white,TextSize=12},scroll))
-- Drag the menu by its title.
local dragging=false;local startInput;local startPos;local dragTouch=nil
local function clampMenu()
    local cam=workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize
    local pos=menu.AbsolutePosition
    local sz=menu.AbsoluteSize
    local x=math.clamp(pos.X,0,math.max(0,vp.X-sz.X))
    local y=math.clamp(pos.Y,0,math.max(0,vp.Y-sz.Y))
    menu.Position=UDim2.fromOffset(menu.Position.X.Offset+x-pos.X,menu.Position.Y.Offset+y-pos.Y)
end
local function dragStart(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;startInput=input.Position;startPos=menu.Position;dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
    end
end
table.insert(connections,title.InputBegan:Connect(dragStart))
table.insert(connections,UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input==dragTouch then dragging=false;dragTouch=nil end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if dragging and ((dragTouch and input==dragTouch) or (not dragTouch and input.UserInputType==Enum.UserInputType.MouseMovement)) then
        local delta=input.Position-startInput
        menu.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        clampMenu()
    end
end))
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.F1 then
        menu.Visible=not menu.Visible
        if menu.Visible then clampMenu() end
    end
end))
local circle=make('Frame',{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1},gui)
make('UICorner',{CornerRadius=UDim.new(1,0)},circle)
make('UIStroke',{Color=purple,Thickness=1.5},circle)
local marker=make('Frame',{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,Visible=false},gui)
make('UICorner',{CornerRadius=UDim.new(1,0)},marker)
make('UIStroke',{Color=purple,Thickness=2},marker)
local target=make('TextLabel',{AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(290,26),BackgroundColor3=Color3.fromRGB(30,24,47),TextColor3=white,Font=Enum.Font.GothamBold,TextSize=12,Visible=false},gui)
make('UICorner',{CornerRadius=UDim.new(0,7)},target)
local BONE_PAIRS={
    {'Head','UpperTorso'},{'UpperTorso','LowerTorso'},
    {'UpperTorso','LeftUpperArm'},{'LeftUpperArm','LeftLowerArm'},{'LeftLowerArm','LeftHand'},
    {'UpperTorso','RightUpperArm'},{'RightUpperArm','RightLowerArm'},{'RightLowerArm','RightHand'},
    {'LowerTorso','LeftUpperLeg'},{'LeftUpperLeg','LeftLowerLeg'},{'LeftLowerLeg','LeftFoot'},
    {'LowerTorso','RightUpperLeg'},{'RightUpperLeg','RightLowerLeg'},{'RightLowerLeg','RightFoot'},
    {'Head','Torso'},{'Torso','Left Arm'},{'Torso','Right Arm'},{'Torso','Left Leg'},{'Torso','Right Leg'}
}
local function line(parent,thickness)
    return make('Frame',{AnchorPoint=Vector2.new(.5,.5),BorderSizePixel=0,BackgroundColor3=red,Size=UDim2.fromOffset(0,thickness or 1),Visible=false},parent)
end
local function drawLine(frame,a,b,thickness)
    local diff=b-a
    frame.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    frame.Size=UDim2.fromOffset(diff.Magnitude,thickness or 1)
    frame.Rotation=math.deg(math.atan2(diff.Y,diff.X))
    frame.Visible=true
end
local function clear(p)
    local v=visuals[p]
    if not v then return end
    for _,obj in ipairs(v.instances) do pcall(function() obj:Destroy() end) end
    visuals[p]=nil
end
local function create(p,char)
    local inst={}
    local function own(obj) table.insert(inst,obj);return obj end
    local box=own(make('Frame',{BackgroundTransparency=1,BorderSizePixel=0,Visible=false},gui))
    make('UIStroke',{Color=red,Thickness=1.3},box)
    local hpBack=own(make('Frame',{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(60,30,35),Visible=false},gui))
    local hpFill=make('Frame',{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(75,230,110)},hpBack)
    local label=own(make('TextLabel',{BackgroundTransparency=1,TextColor3=white,TextStrokeTransparency=.2,Font=Enum.Font.GothamBold,TextSize=12,Visible=false},gui))
    local bones={}
    for i=1,#BONE_PAIRS do bones[i]=own(line(gui,1.4)) end
    local v={char=char,box=box,hpBack=hpBack,hpFill=hpFill,label=label,bones=bones,instances=inst}
    visuals[p]=v
    return v
end
local function hide(v)
    v.box.Visible=false;v.hpBack.Visible=false;v.label.Visible=false
    for _,b in ipairs(v.bones) do b.Visible=false end
end
local function isEnemy(p)
    if p==LocalPlayer then return false end
    if not cfg.TeamCheck then return true end
    local ourTeam=LocalPlayer:GetAttribute('TeamID')
    local theirTeam=p:GetAttribute('TeamID')
    if ourTeam~=nil and theirTeam~=nil then return ourTeam~=theirTeam end
    if LocalPlayer.Team and p.Team then return LocalPlayer.Team~=p.Team end
    if not LocalPlayer.Neutral and not p.Neutral then return LocalPlayer.TeamColor~=p.TeamColor end
    return true
end
local HEAD_PARTS={'Head'}
local BODY_PARTS={'UpperTorso','Torso','HumanoidRootPart'}
local AUTO_PARTS={'Head','UpperTorso','Torso','HumanoidRootPart'}
local function firstPart(char,names)
    if not char then return nil end
    for _,name in ipairs(names) do
        local part=char:FindFirstChild(name)
        if part and part:IsA('BasePart') then return part end
    end
end
local function lineOfSight(cam,char,head)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=LocalPlayer.Character and {LocalPlayer.Character,cam} or {cam}
    params.IgnoreWater=true
    local origin=cam.CFrame.Position
    local hit=workspace:Raycast(origin,head.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(char)
end
-- New targets must be inside the circle. Held targets have a separate release boundary.
local function aimCandidate(p,cam,center,localRoot,radiusLimit,preferredPart)
    if p.Parent~=Players or not isEnemy(p) then return nil,nil,nil,'invalid' end
    local char=p.Character
    if not char or not char.Parent then return nil,nil,nil,'invalid' end
    local hum=char and char:FindFirstChildOfClass('Humanoid')
    local root=char and char:FindFirstChild('HumanoidRootPart')
    if hum and hum.Health<=0 then return nil,nil,char,'invalid' end
    if not hum or not root or not root:IsA('BasePart') then return nil,nil,char,'missing' end
    if (root.Position-localRoot.Position).Magnitude>cfg.Range then return nil,nil,char,'invalid' end
    local names=cfg.TargetBone=='Auto' and AUTO_PARTS or (cfg.TargetBone=='Body' and BODY_PARTS or HEAD_PARTS)
    local reason='missing'
    local function check(part)
        if not part or not part:IsA('BasePart') then return nil end
        local pos,screen=cam:WorldToViewportPoint(part.Position)
        if not screen or pos.Z<=0 then reason='outside';return nil end
        local distance=(Vector2.new(pos.X,pos.Y)-center).Magnitude
        if distance>(radiusLimit or cfg.Radius) then reason='outside';return nil end
        if cfg.VisibilityCheck and not lineOfSight(cam,char,part) then reason='blocked';return nil end
        return distance
    end
    -- Auto retains its current visible hitbox, avoiding head/body flicker.
    if cfg.TargetBone=='Auto' and preferredPart and preferredPart.Parent==char then
        for _,name in ipairs(names) do
            if char:FindFirstChild(name)==preferredPart then
                local distance=check(preferredPart)
                if distance then return preferredPart,distance,char end
                break
            end
        end
    end
    for _,name in ipairs(names) do
        local part=char:FindFirstChild(name)
        local distance=check(part)
        if distance then return part,distance,char end
    end
    return nil,nil,char,reason
end
local function updateAim(dt)
    local cam=workspace.CurrentCamera
    local char=LocalPlayer.Character
    local hum=char and char:FindFirstChildOfClass('Humanoid')
    local localRoot=char and char:FindFirstChild('HumanoidRootPart')
    if not cfg.AimLock or not aimHeld or UIS:GetFocusedTextBox() or not cam or not hum or hum.Health<=0 or not localRoot or not localRoot:IsA('BasePart') then
        if not cfg.AimLock or not aimHeld then
            return
        end
        clearLock()
        clearPending()
        aimNotice='Waiting for living character / camera'
        return
    end
    local center=cam.ViewportSize/2
    local part
    if lockedPlayer and lockedPlayer.Character==lockedCharacter then
        local candidate,distance,candidateChar,reason=aimCandidate(lockedPlayer,cam,center,localRoot,cfg.Radius*cfg.LockRadiusScale,lockedPart)
        part=candidate
        if not part and (reason=='blocked' or reason=='outside' or reason=='missing') then
            lostFor=lostFor+math.max(dt,0)
            lockTracking=false
            -- Wait for this target instead of jumping to another player on a one-frame miss.
            -- No camera adjustment occurs while the visibility/FOV/parts check is failing.
            if lostFor<=cfg.LockGrace then return end
        end
    end
    if not part then
        clearLock()
        local closest=cfg.Radius+1
        local nextPlayer,nextCharacter
        for _,p in ipairs(Players:GetPlayers()) do
            local candidate,distance,candidateChar=aimCandidate(p,cam,center,localRoot)
            if candidate and distance<closest then
                part=candidate
                closest=distance
                nextPlayer=p
                nextCharacter=candidateChar
            end
        end
        if not nextPlayer then clearPending();return end
        if hasAcquired and cfg.SwitchDelay>0 then
            if pendingPlayer~=nextPlayer or pendingCharacter~=nextCharacter then
                pendingPlayer=nextPlayer
                pendingCharacter=nextCharacter
                pendingFor=0
            else
                pendingFor=pendingFor+math.max(dt,0)
            end
            if pendingFor+1e-6<cfg.SwitchDelay then return end
        end
        lockedPlayer=nextPlayer
        lockedCharacter=nextCharacter
        clearPending()
    end
    if not part then return end
    lockedPart=part
    hasAcquired=true
    lostFor=0
    lockTracking=true
    local origin=cam.CFrame.Position
    local direction=part.Position-origin
    if direction.Magnitude<.001 then return end
    local up=Vector3.new(0,1,0)
    if math.abs(direction.Unit:Dot(up))>.999 then up=cam.CFrame.RightVector end
    local desired=CFrame.lookAt(origin,part.Position,up)
    local alpha=cfg.AimSmooth==0 and 1 or 1-math.exp(-cfg.AimSmooth*math.max(dt,0))
    cam.CFrame=cam.CFrame:Lerp(desired,alpha)
end
local function render()
    local cam=workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize;local center=Vector2.new(vp.X/2,vp.Y/2)
    if menu.Visible then clampMenu() end
    circle.Position=UDim2.fromOffset(center.X,center.Y)
    circle.Size=UDim2.fromOffset(cfg.Radius*2,cfg.Radius*2)
    circle.Visible=cfg.FOV
    target.Position=UDim2.fromOffset(center.X,center.Y+cfg.Radius+12)
    target.Visible=false
    marker.Visible=false
    local localRoot=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    local shown,unknown,missing=0,0,0
    local best,bestD,bestPos,bestPart=nil,cfg.Radius,nil,nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then
            local char=p.Character
            local head=firstPart(char,HEAD_PARTS)
            local root=char and char:FindFirstChild('HumanoidRootPart')
            local hum=char and char:FindFirstChildOfClass('Humanoid')
            local valid=isEnemy(p) and char and char.Parent and head and root and root:IsA('BasePart') and hum and hum.Health>0
            if (not LocalPlayer.Team or not p.Team) then unknown=unknown+1 end
            if not head or not root or not hum then missing=missing+1 end
            local v=visuals[p]
            if v and (v.char~=char or not valid) then clear(p);v=nil end
            if valid then
                if not v then v=create(p,char) end
                hide(v)
                local dist=localRoot and (root.Position-localRoot.Position).Magnitude or math.huge
                if cfg.ESP and dist<=cfg.Range then
                    -- Use head and root anchors rather than animated weapon/accessory bounding boxes.
                    local headTop=cam:WorldToViewportPoint(head.Position+Vector3.new(0,head.Size.Y*0.65,0))
                    local feet=cam:WorldToViewportPoint(root.Position-Vector3.new(0,hum.HipHeight+2.2,0))
                    if headTop.Z>.05 and feet.Z>.05 then
                        local height=feet.Y-headTop.Y
                        local width=height*.48
                        local x=(headTop.X+feet.X)/2-width/2
                        local y=math.min(headTop.Y,feet.Y)
                        local onScreen=x+width>=0 and x<=vp.X and y+height>=0 and y<=vp.Y and height>0
                        if onScreen and height>=3 and height<vp.Y*2 then
                            shown=shown+1
                            if cfg.Boxes then
                                v.box.Position=UDim2.fromOffset(x,y)
                                v.box.Size=UDim2.fromOffset(width,height)
                                v.box.Visible=true
                            end
                            if cfg.Health then
                                local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                                v.hpBack.Position=UDim2.fromOffset(x-9,y)
                                v.hpBack.Size=UDim2.fromOffset(5,height)
                                v.hpFill.AnchorPoint=Vector2.new(0,1)
                                v.hpFill.Position=UDim2.fromScale(0,1)
                                v.hpFill.Size=UDim2.fromScale(1,ratio)
                                v.hpFill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(255*ratio),55)
                                v.hpBack.Visible=true
                            end
                            if cfg.Names or cfg.Distance or cfg.Health then
                                local pieces={}
                                if cfg.Names then table.insert(pieces,p.DisplayName) end
                                if cfg.Distance and dist<math.huge then table.insert(pieces,math.floor(dist)..' studs') end
                                if cfg.Health then table.insert(pieces,math.ceil(hum.Health)..' HP') end
                                v.label.Text=table.concat(pieces,' | ')
                                v.label.Position=UDim2.fromOffset(x-45,y-22)
                                v.label.Size=UDim2.fromOffset(width+90,20)
                                v.label.Visible=true
                            end
                            if cfg.Skeleton then
                                for i,pair in ipairs(BONE_PAIRS) do
                                    local a=char:FindFirstChild(pair[1]);local b=char:FindFirstChild(pair[2])
                                    if a and b and a:IsA('BasePart') and b:IsA('BasePart') then
                                        local sa=cam:WorldToViewportPoint(a.Position)
                                        local sb=cam:WorldToViewportPoint(b.Position)
                                        if sa.Z>.05 and sb.Z>.05 then
                                            drawLine(v.bones[i],Vector2.new(sa.X,sa.Y),Vector2.new(sb.X,sb.Y),1.4)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            -- The preview uses exactly the same eligibility checks as acquisition.
            if cfg.Target and localRoot and localRoot:IsA('BasePart') then
                local aimPart,d=aimCandidate(p,cam,center,localRoot)
                if aimPart and d<=bestD then
                    local pos=cam:WorldToViewportPoint(aimPart.Position)
                    bestD=d;best=p;bestPart=aimPart;bestPos=Vector2.new(pos.X,pos.Y)
                end
            end
        end
    end
    if cfg.Target and lockedPlayer then
        best=nil;bestPos=nil
        if lockTracking and lockedPlayer.Character==lockedCharacter then
            local part=lockedPart
            if part and part.Parent==lockedCharacter then
                local pos=cam:WorldToViewportPoint(part.Position)
                best=lockedPlayer
                bestPart=part
                bestPos=Vector2.new(pos.X,pos.Y)
            end
        end
    end
    if best then
        target.Text=(best==lockedPlayer and 'LOCKED: ' or 'TARGET: ')..best.DisplayName..' | '..(bestPart and bestPart.Name or cfg.TargetBone)
        target.Visible=true
        if cfg.TargetHighlight and bestPos then
            marker.Position=UDim2.fromOffset(bestPos.X,bestPos.Y)
            marker.Visible=true
        end
    end
    local aimState='Aim lock: OFF'
    if cfg.AimLock then
        aimState=lockedPlayer and ((lockTracking and 'Locked: ' or 'Waiting: ')..lockedPlayer.DisplayName) or (pendingPlayer and ('Switching: '..pendingPlayer.DisplayName) or (aimHeld and 'Aim lock: searching inside FOV' or ('Click '..aimKeys[aimKeyIndex].label..' to toggle')))
    end
    status.Text='ESP visible: '..shown..' | Unknown teams: '..unknown..' | Missing parts: '..missing..'\n'..aimState..'\nHotkey presses: '..hotkeyCount..' | '..aimNotice
end
local stopButton=button('Unload / remove UI')
table.insert(connections,stopButton.MouseButton1Click:Connect(function()
    if type(_G.JailbirdV1Stop)=='function' then _G.JailbirdV1Stop() end
end))
local function stop()
    if not alive then return end
    alive=false
    releaseAim()
    RunService:UnbindFromRenderStep(renderName)
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for p in pairs(visuals) do clear(p) end
    gui:Destroy()
end




table.insert(connections,Players.PlayerRemoving:Connect(function(p)
    if p==lockedPlayer then clearLock() end
    if p==pendingPlayer then clearPending() end
    clear(p)
end))
_G.JailbirdV1Stop=stop
_G.JailbirdV3Stop=stop
_G.JailbirdV33Stop=stop
-- Run late in the frame to reduce conflicts with custom camera updates; project visuals afterward.
RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value-1,function(dt)
    if not alive then return end
    local ok,err=pcall(function() updateAim(dt);render() end)
    if not ok then
        releaseAim()
        if status.Parent then status.Text='Render error: '..tostring(err) end
        warn('[JAILBIRD V3.3 runtime]', tostring(err), debug and debug.traceback and debug.traceback() or '')
    end
end)
selectTab('Visuals')
print('JAILBIRD V3.3 loaded | F1 menu | Right-click toggles aim when enabled')
