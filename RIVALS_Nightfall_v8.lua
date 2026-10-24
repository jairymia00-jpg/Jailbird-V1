-- RIVALS | Nightfall v8 | map radar, offscreen ESP, aim, movement
-- F1 menu | F2 aim lock | F10 unload
-- Camera aim only changes your view. A game's server controls actual hits.
-- The target resolver uses public character/team data and may need adjustment
-- if an experience uses custom, nonreplicated character or team objects.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer
assert(LP, "Run this on the client")
local PlayerGui = LP:WaitForChild("PlayerGui")
local ART_ASSET_ID = 0
-- Main experience page: https://www.roblox.com/games/17625359962/RIVALS
-- Subplaces may have different PlaceIds; this check is informational.
if game.PlaceId ~= 17625359962 then
    warn("RIVALS Nightfall: unexpected PlaceId " .. tostring(game.PlaceId) .. "; continuing for possible match subplace")
end

if type(_G.RivalsNightfallStop) == "function" then pcall(_G.RivalsNightfallStop) end
for _, oldName in ipairs({"RIVALS_Nightfall_v1", "RIVALS_Nightfall_v2",
    "RIVALS_Nightfall_v3", "RIVALS_Nightfall_v4",
    "RIVALS_Nightfall_v5", "RIVALS_Nightfall_v6", "RIVALS_Nightfall_v7",
    "RIVALS_Nightfall_v8"}) do
    local previous = PlayerGui:FindFirstChild(oldName)
    if previous then previous:Destroy() end
end

local C = {
    ESP = true, Allies = true, Boxes = true, Health = true, Names = true,
    Distance = true, Platform = false, Arrows = true, Radar = true,
    ESPVisibleCheck = false, Outlines = true, Skeleton = false, Tracers = false,
    FOV = true, TargetLine = false, Prediction = false,
    Indicator = true, StatusOverlay = true,
    Headshot = true, Aim = false, AutoFire = false, PauseInMenu = true,
    Sticky = true, NPCs = false, MatchFilter = false,
    CheckSight = true, Radius = 230, Range = 1200,
    SpeedEnabled = false, SpeedValue = 32,
    AimSpeed = 28, Strength = "Strong", AimMethod = "Camera", TargetPart = "Head",
}
local COL = {
    bg = Color3.fromRGB(14, 9, 13), card = Color3.fromRGB(28, 18, 24),
    raised = Color3.fromRGB(57, 16, 23), accent = Color3.fromRGB(255, 45, 70),
    text = Color3.fromRGB(250, 241, 243), muted = Color3.fromRGB(172, 152, 158),
    good = Color3.fromRGB(110, 230, 170), enemy = Color3.fromRGB(255, 75, 165),
    ally = Color3.fromRGB(75, 170, 255),
    unknown = Color3.fromRGB(190, 188, 197),
}
local ACCENTS = {
    Color3.fromRGB(255, 45, 70), Color3.fromRGB(255, 90, 150),
    Color3.fromRGB(170, 110, 255), Color3.fromRGB(110, 190, 255),
    Color3.fromRGB(225, 225, 240), Color3.fromRGB(255, 170, 60),
}
local running, connections, overlays, npcHumanoids = true, {}, {}, {}
local bestTarget, bestName, bestDistance, bestPlayer = nil, nil, nil, nil
local aimReason, aimWrites = "SEARCHING", 0
local aimCounts = {models = 0, rigs = 0, onScreen = 0,
    inside = 0, clear = 0, blocked = 0, unknown = 0, allies = 0}
local lockedHead, lockedPlayer = nil, nil
local matchStatus = "DUEL ID UNAVAILABLE"
local renderName, aimName = "RVN_v8_Render", "RVN_v8_Aim"
local accentBinds, accentFns = {}, {}

local function make(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, r)
    make("UICorner", {CornerRadius = UDim.new(0, r or 8)}, obj)
end
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end
local function show(obj, on)
    if obj.Visible ~= on then obj.Visible = on end
end
local function tween(obj, props, duration)
    if obj and obj.Parent then
        TweenService:Create(obj, TweenInfo.new(duration or .18, Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out), props):Play()
    end
end
local function label(parent, value, pos, size, color, font, textSize, align)
    return make("TextLabel", {BackgroundTransparency = 1, Text = value,
        Position = pos, Size = size, TextColor3 = color or COL.text,
        Font = font or Enum.Font.GothamMedium, TextSize = textSize or 12,
        TextXAlignment = align or Enum.TextXAlignment.Left}, parent)
end
local function bindAccent(obj, prop)
    obj[prop] = COL.accent
    table.insert(accentBinds, {obj, prop})
end
local function line(parent, width, color)
    return make("Frame", {AnchorPoint = Vector2.new(.5, .5),
        Size = UDim2.fromOffset(width, 1), BorderSizePixel = 0,
        BackgroundColor3 = color, Visible = false}, parent)
end
local function placeLine(obj, a, b, width)
    local dx, dy = b.X - a.X, b.Y - a.Y
    obj.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    obj.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), width)
    obj.Rotation = math.deg(math.atan2(dy, dx))
    show(obj, true)
end

local gui = make("ScreenGui", {Name = "RIVALS_Nightfall_v8", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, PlayerGui)
local menu = make("Frame", {Size = UDim2.fromOffset(752, 540),
    Position = UDim2.fromScale(.5, .5), AnchorPoint = Vector2.new(.5, .5),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    Active = true, ClipsDescendants = true, ZIndex = 20}, gui)
corner(menu, 18)
make("UIGradient", {Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 10, 22)),
    ColorSequenceKeypoint.new(.55, Color3.fromRGB(22, 10, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 8, 14)),
}), Rotation = 125}, menu)
local border = make("UIStroke", {Thickness = 1.4, Transparency = .35}, menu)
bindAccent(border, "Color")
TweenService:Create(border, TweenInfo.new(1.8, Enum.EasingStyle.Sine,
    Enum.EasingDirection.InOut, -1, true), {Transparency = .75}):Play()

local function fitScale()
    local camera = workspace.CurrentCamera
    if not camera then return 1 end
    local view = camera.ViewportSize
    return math.max(.2, math.min(1, (view.X - 24) / 752, (view.Y - 24) / 540))
end
local fit = fitScale()
local scale = make("UIScale", {Scale = fit * .9}, menu)
tween(scale, {Scale = fit}, .3)
local viewportConnection
local function watchCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
            fit = fitScale()
            tween(scale, {Scale = fit}, .2)
        end)
    end
    fit = fitScale()
    tween(scale, {Scale = fit}, .2)
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
watchCamera()

local topBar = make("Frame", {Size = UDim2.new(1, 0, 0, 3),
    BorderSizePixel = 0}, menu)
bindAccent(topBar, "BackgroundColor3")
local dragArea = make("Frame", {Size = UDim2.new(1, -70, 0, 72),
    BackgroundTransparency = 1, Active = true}, menu)
label(menu, "RIVALS  /  NIGHTFALL v8", UDim2.fromOffset(18, 10),
    UDim2.fromOffset(480, 38), COL.text, Enum.Font.GothamBlack, 19)
label(menu, "AIM   /   VISUALS   /   MOVEMENT",
    UDim2.fromOffset(19, 48), UDim2.fromOffset(500, 20),
    COL.muted, Enum.Font.Gotham, 10)
local buildTag = label(menu, "BUILD 06", UDim2.fromOffset(596, 24),
    UDim2.fromOffset(94, 18), COL.muted, Enum.Font.GothamBold, 10,
    Enum.TextXAlignment.Right)
local closeBtn = make("TextButton", {Text = "×",
    Position = UDim2.new(1, -49, 0, 13), Size = UDim2.fromOffset(32, 31),
    BackgroundColor3 = COL.card, BorderSizePixel = 0,
    TextColor3 = COL.text, Font = Enum.Font.GothamBold,
    TextSize = 20, AutoButtonColor = false, ZIndex = 3}, menu)
corner(closeBtn, 10)
connect(closeBtn.MouseEnter, function()
    tween(closeBtn, {BackgroundColor3 = COL.raised}, .12)
end)
connect(closeBtn.MouseLeave, function()
    tween(closeBtn, {BackgroundColor3 = COL.card}, .12)
end)

local rail = make("Frame", {Position = UDim2.fromOffset(12, 81),
    Size = UDim2.fromOffset(144, 405), BackgroundColor3 = COL.card,
    BackgroundTransparency = .35, BorderSizePixel = 0}, menu)
corner(rail, 14)
make("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = .88}, rail)
local logo = label(rail, "RV", UDim2.fromOffset(14, 15),
    UDim2.fromOffset(45, 40), COL.text, Enum.Font.GothamBlack,
    22, Enum.TextXAlignment.Center)
logo.BackgroundTransparency = 0
logo.BorderSizePixel = 0
corner(logo, 12)
bindAccent(logo, "BackgroundColor3")
label(rail, "CONTROL\nPANEL", UDim2.fromOffset(67, 15),
    UDim2.fromOffset(65, 40), COL.muted, Enum.Font.GothamBold, 10)
local selectedBg = make("Frame", {Position = UDim2.fromOffset(8, 76),
    Size = UDim2.fromOffset(128, 41), BackgroundColor3 = COL.raised,
    BorderSizePixel = 0}, rail)
corner(selectedBg, 10)
local selectedBar = make("Frame", {Position = UDim2.fromOffset(8, 80),
    Size = UDim2.fromOffset(3, 33), BorderSizePixel = 0}, rail)
bindAccent(selectedBar, "BackgroundColor3")
label(rail, "BLUE   TEAM", UDim2.fromOffset(16, 177),
    UDim2.fromOffset(115, 23), COL.ally, Enum.Font.GothamBold, 11)
label(rail, "PINK   ENEMY", UDim2.fromOffset(16, 205),
    UDim2.fromOffset(115, 23), COL.enemy, Enum.Font.GothamBold, 11)
label(rail, "UNKNOWN = GRAY", UDim2.fromOffset(16, 233),
    UDim2.fromOffset(115, 23), COL.muted, Enum.Font.GothamBold, 11)
local aimChip = label(rail, "AIM  OFF", UDim2.fromOffset(11, 371),
    UDim2.fromOffset(122, 23), COL.good, Enum.Font.GothamBold,
    10, Enum.TextXAlignment.Center)
aimChip.BackgroundTransparency = 0
aimChip.BackgroundColor3 = COL.raised
corner(aimChip, 11)

local card = make("Frame", {Position = UDim2.fromOffset(166, 81),
    Size = UDim2.fromOffset(347, 405), BackgroundColor3 = COL.card,
    BackgroundTransparency = .35, BorderSizePixel = 0}, menu)
corner(card, 14)
make("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = .88}, card)
local pageTitle = label(card, "AIM", UDim2.fromOffset(14, 9),
    UDim2.fromOffset(300, 27), COL.text, Enum.Font.GothamBold, 18)
local pageInfo = label(card, "TARGET ACQUISITION", UDim2.fromOffset(14, 36),
    UDim2.fromOffset(300, 18), COL.muted, Enum.Font.Gotham, 10)

local art = make("Frame", {Position = UDim2.fromOffset(523, 81),
    Size = UDim2.fromOffset(217, 405), BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0, ClipsDescendants = true}, menu)
corner(art, 14)
make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(70, 12, 26),
    Color3.fromRGB(16, 9, 13)), Rotation = 70,
    Transparency = NumberSequence.new(.45, .2)}, art)
local artStroke = make("UIStroke", {Transparency = .5}, art)
bindAccent(artStroke, "Color")
local artImage = make("ImageLabel", {Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
    Visible = false}, art)
local dashboard = make("Frame", {Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1}, art)
label(dashboard, "RIVALS  /  LIVE STATUS", UDim2.fromOffset(16, 16),
    UDim2.fromOffset(185, 24), COL.text, Enum.Font.GothamBold, 15)
local dashLine = make("Frame", {Position = UDim2.fromOffset(16, 49),
    Size = UDim2.fromOffset(184, 2), BorderSizePixel = 0}, dashboard)
bindAccent(dashLine, "BackgroundColor3")
label(dashboard, "TARGET", UDim2.fromOffset(16, 71),
    UDim2.fromOffset(185, 16), COL.muted, Enum.Font.GothamBold, 10)
local dashTarget = label(dashboard, "Searching", UDim2.fromOffset(16, 91),
    UDim2.fromOffset(185, 29), COL.text, Enum.Font.GothamBold, 15)
dashTarget.TextTruncate = Enum.TextTruncate.AtEnd
label(dashboard, "AIM STATE", UDim2.fromOffset(16, 143),
    UDim2.fromOffset(185, 16), COL.muted, Enum.Font.GothamBold, 10)
local dashAim = label(dashboard, "Menu open", UDim2.fromOffset(16, 164),
    UDim2.fromOffset(185, 27), COL.good, Enum.Font.GothamBold, 13)
dashAim.TextTruncate = Enum.TextTruncate.AtEnd
label(dashboard, "PINK TARGETS IN CIRCLE", UDim2.fromOffset(16, 216),
    UDim2.fromOffset(185, 16), COL.muted, Enum.Font.GothamBold, 10)
local dashCount = label(dashboard, "0 visible", UDim2.fromOffset(16, 237),
    UDim2.fromOffset(185, 28), COL.text, Enum.Font.GothamBold, 14)
local help = label(dashboard, "F1   HIDE / SHOW MENU\nF2   AIM ON / OFF\n       BLUE: TEAMMATES\n       PINK: ENEMIES\nF10  UNLOAD",
    UDim2.fromOffset(16, 282), UDim2.fromOffset(185, 82),
    COL.muted, Enum.Font.Gotham, 11)
help.TextYAlignment = Enum.TextYAlignment.Top
local artFooter = label(art, "RIVALS  /  NIGHTFALL v8",
    UDim2.new(0, 0, 1, -33), UDim2.new(1, 0, 0, 33),
    COL.text, Enum.Font.GothamBold, 10, Enum.TextXAlignment.Center)
artFooter.BackgroundTransparency = .2
artFooter.BackgroundColor3 = COL.bg
local function setArt(id)
    if id and tonumber(id) and tonumber(id) > 0 then
        artImage.Image = "rbxassetid://" .. tostring(id)
        artImage.Visible, dashboard.Visible = true, false
    else artImage.Visible, dashboard.Visible = false, true end
end
setArt(ART_ASSET_ID)

local status = label(menu, "Starting...", UDim2.new(0, 16, 1, -45),
    UDim2.new(1, -32, 0, 36), COL.muted, Enum.Font.Gotham, 11)
status.TextWrapped = true
local circle = make("Frame", {AnchorPoint = Vector2.new(.5, .5),
    BackgroundTransparency = 1, Visible = true}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, circle)
local circleStroke = make("UIStroke", {Color = COL.accent,
    Thickness = 1.5, Transparency = .2}, circle)
local targetLine = line(gui, 2, COL.enemy)
local radar = make("Frame", {Position = UDim2.new(1, -178, 0, 104),
    Size = UDim2.fromOffset(160, 160), BackgroundColor3 = COL.bg,
    BackgroundTransparency = .18, BorderSizePixel = 0,
    Visible = false, ZIndex = 5}, gui)
corner(radar, 80)
make("UIStroke", {Color = COL.enemy, Transparency = .25, Thickness = 1.2}, radar)
make("Frame", {Position = UDim2.fromOffset(79, 13),
    Size = UDim2.fromOffset(1, 134), BackgroundColor3 = COL.muted,
    BackgroundTransparency = .65, BorderSizePixel = 0, ZIndex = 6}, radar)
make("Frame", {Position = UDim2.fromOffset(13, 79),
    Size = UDim2.fromOffset(134, 1), BackgroundColor3 = COL.muted,
    BackgroundTransparency = .65, BorderSizePixel = 0, ZIndex = 6}, radar)
local radarCenter = make("Frame", {Position = UDim2.fromOffset(76, 76),
    Size = UDim2.fromOffset(8, 8), BackgroundColor3 = COL.text,
    BorderSizePixel = 0, ZIndex = 8}, radar)
corner(radarCenter, 4)
local radarScaleLabel = make("TextLabel", {Position = UDim2.fromOffset(12, 133),
    Size = UDim2.fromOffset(136, 18), BackgroundTransparency = 1,
    Text = "RADAR  300 studs", TextColor3 = COL.muted, TextSize = 9,
    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 9}, radar)
local indicator = make("TextLabel", {AnchorPoint = Vector2.new(.5, 0),
    Size = UDim2.fromOffset(250, 25), BackgroundColor3 = COL.card,
    BorderSizePixel = 0, TextColor3 = COL.text,
    Font = Enum.Font.GothamBold, TextSize = 11, Visible = false}, gui)
corner(indicator, 6)
local aimState = make("TextLabel", {AnchorPoint = Vector2.new(.5, 0),
    Position = UDim2.new(.5, 0, 0, 68), Size = UDim2.fromOffset(360, 27),
    BackgroundColor3 = COL.card, BackgroundTransparency = .18,
    BorderSizePixel = 0, TextColor3 = COL.muted,
    Font = Enum.Font.GothamBold, TextSize = 11, Text = "AIM OFF  •  F2 TO ENABLE",
    Visible = true, ZIndex = 4}, gui)
corner(aimState, 8)
aimState.TextTruncate = Enum.TextTruncate.AtEnd

local noticeHolder = make("Frame", {Size = UDim2.fromOffset(280, 400),
    Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1, ZIndex = 30}, gui)
make("UIListLayout", {Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder}, noticeHolder)

local Window = {}
local tabs, keybinds = {}, {}
local active = true
local listening = nil
local function setAccent(color)
    COL.accent = color
    COL.raised = color:Lerp(COL.bg, .82)
    for _, binding in ipairs(accentBinds) do
        if binding[1]:IsDescendantOf(gui) then
            tween(binding[1], {[binding[2]] = color}, .25)
        end
    end
    selectedBg.BackgroundColor3 = COL.raised
    aimChip.BackgroundColor3 = COL.raised
    for _, fn in ipairs(accentFns) do fn() end
end
function Window:SetAccent(color) setAccent(color) end
function Window:SetArt(id) setArt(id) end
function Window:SetStatus(value) status.Text = value end
function Window:SetChip(value, color)
    aimChip.Text, aimChip.TextColor3 = value, color or COL.good
end
function Window:Notify(title, body, duration)
    if not running then return end
    local wrapper = make("Frame", {Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1}, noticeHolder)
    local item = make("Frame", {Size = UDim2.fromScale(1, 1),
        Position = UDim2.new(1, 40, 0, 0), BackgroundColor3 = COL.card,
        BorderSizePixel = 0}, wrapper)
    corner(item, 10)
    local stroke = make("UIStroke", {Color = COL.accent, Transparency = .5}, item)
    bindAccent(stroke, "Color")
    label(item, title, UDim2.fromOffset(14, 8),
        UDim2.new(1, -25, 0, 19), COL.text, Enum.Font.GothamBold, 13)
    label(item, body or "", UDim2.fromOffset(14, 29),
        UDim2.new(1, -25, 0, 18), COL.muted, Enum.Font.Gotham, 11)
    tween(item, {Position = UDim2.fromOffset(0, 0)}, .35)
    task.delay(duration or 3, function()
        if not wrapper.Parent then return end
        tween(item, {Position = UDim2.new(1, 40, 0, 0)}, .25)
        task.wait(.3)
        if wrapper.Parent then wrapper:Destroy() end
    end)
end
function Window:SetVisible(on)
    active = on
    if on then
        menu.Visible = true
        scale.Scale = fit * .94
        tween(scale, {Scale = fit}, .22)
    else
        tween(scale, {Scale = fit * .94}, .15)
        task.delay(.16, function()
            if not active and menu.Parent then menu.Visible = false end
        end)
    end
end
function Window:Toggle() self:SetVisible(not active) end
function Window:Destroy()
    if type(_G.RivalsNightfallStop) == "function" then _G.RivalsNightfallStop()
    else gui:Destroy() end
end
connect(closeBtn.MouseButton1Click, function() Window:SetVisible(false) end)

-- Mouse and touch drag use the same input object until it ends.
local dragInput, dragStart, menuStart
connect(dragArea.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput, dragStart, menuStart = input, input.Position, menu.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if not dragInput then return end
    if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = (input.Position - dragStart) / math.max(scale.Scale, .2)
        menu.Position = UDim2.new(menuStart.X.Scale, menuStart.X.Offset + d.X,
            menuStart.Y.Scale, menuStart.Y.Offset + d.Y)
    end
end)
connect(UIS.InputEnded, function(input)
    if input == dragInput then dragInput = nil end
end)

local TAB_Y, TAB_STEP = 76, 49
local function selectTab(tab, immediate)
    pageTitle.Text, pageInfo.Text = string.upper(tab.name), string.upper(tab.info)
    for _, other in ipairs(tabs) do
        local selected = other == tab
        other.page.Visible = selected
        tween(other.button, {TextColor3 = selected and COL.text or COL.muted},
            immediate and 0 or .18)
    end
    local y = TAB_Y + (tab.index - 1) * TAB_STEP
    if immediate then
        selectedBg.Position = UDim2.fromOffset(8, y)
        selectedBar.Position = UDim2.fromOffset(8, y + 4)
    else
        tween(selectedBg, {Position = UDim2.fromOffset(8, y)}, .25)
        tween(selectedBar, {Position = UDim2.fromOffset(8, y + 4)}, .25)
    end
end
function Window:AddTab(name, info)
    local index = #tabs + 1
    local button = make("TextButton", {Text = "  " .. string.upper(name),
        Position = UDim2.fromOffset(8, TAB_Y + (index - 1) * TAB_STEP),
        Size = UDim2.fromOffset(128, 41), TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, TextColor3 = COL.muted,
        Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
        ZIndex = 2}, rail)
    local page = make("ScrollingFrame", {Position = UDim2.fromOffset(13, 61),
        Size = UDim2.new(1, -25, 1, -73), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 5,
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollingEnabled = true, Visible = false}, card)
    bindAccent(page, "ScrollBarImageColor3")
    local layout = make("UIListLayout", {Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder}, page)
    make("UIPadding", {PaddingRight = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8)}, page)
    connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
    end)
    local tab = {button = button, page = page, index = index,
        name = name, info = info or ""}
    table.insert(tabs, tab)
    connect(button.MouseButton1Click, function() selectTab(tab) end)
    if index == 1 then selectTab(tab, true) end

    local function row(height)
        local frame = make("Frame", {Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = COL.bg, BackgroundTransparency = .3,
            BorderSizePixel = 0}, page)
        corner(frame, 10)
        return frame
    end
    function tab:AddLabel(value)
        local frame = row(28)
        label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(1, -20, 1, 0), COL.muted, Enum.Font.Gotham, 11)
    end
    function tab:AddSection(value)
        local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1}, page)
        local mark = make("Frame", {Position = UDim2.fromOffset(2, 9),
            Size = UDim2.fromOffset(3, 14), BorderSizePixel = 0}, frame)
        bindAccent(mark, "BackgroundColor3")
        label(frame, string.upper(value), UDim2.fromOffset(13, 3),
            UDim2.new(1, -20, 0, 25), COL.text, Enum.Font.GothamBold, 11)
    end
    function tab:AddButton(value, callback)
        local frame = row(35)
        local hit = make("TextButton", {Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Text = value,
            TextColor3 = COL.text, Font = Enum.Font.GothamMedium,
            TextSize = 12}, frame)
        connect(hit.MouseButton1Click, function()
            frame.BackgroundColor3 = COL.accent
            tween(frame, {BackgroundColor3 = COL.bg}, .35)
            if callback then task.spawn(callback) end
        end)
    end
    function tab:AddToggle(value, initial, callback)
        local state = initial == true
        local frame = row(35)
        local txt = label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(1, -70, 1, 0), COL.text)
        local flag = make("TextLabel", {Position = UDim2.new(1, -51, .5, -11),
            Size = UDim2.fromOffset(42, 22), BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, TextSize = 10}, frame)
        corner(flag, 11)
        local function paint(animate)
            local speed = animate and .18 or 0
            tween(frame, {BackgroundColor3 = state and COL.raised or COL.bg}, speed)
            tween(txt, {TextColor3 = state and COL.text or COL.muted}, speed)
            tween(flag, {BackgroundColor3 = state and COL.accent or COL.card,
                TextColor3 = state and COL.text or COL.muted}, speed)
            flag.Text = state and "ON" or "OFF"
        end
        paint(false)
        table.insert(accentFns, function() paint(true) end)
        local hit = make("TextButton", {Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Text = ""}, frame)
        connect(hit.MouseButton1Click, function()
            state = not state
            paint(true)
            if callback then callback(state) end
        end)
        return {Set = function(_, on)
            state = on == true
            paint(true)
            if callback then callback(state) end
        end}
    end
    function tab:AddSlider(value, low, high, initial, callback, step)
        step = step or 1
        local current = initial or low
        local frame = row(52)
        label(frame, value, UDim2.fromOffset(10, 6),
            UDim2.new(1, -90, 0, 20), COL.text)
        local valueLabel = label(frame, tostring(current),
            UDim2.new(1, -72, 0, 6), UDim2.fromOffset(62, 20),
            COL.muted, Enum.Font.Gotham, 11, Enum.TextXAlignment.Right)
        local touchArea = make("Frame", {Size = UDim2.new(1, -20, 0, 20),
            Position = UDim2.fromOffset(10, 27), BackgroundTransparency = 1,
            Active = true}, frame)
        local bar = make("Frame", {Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.fromOffset(0, 7), BackgroundColor3 = COL.card,
            BorderSizePixel = 0}, touchArea)
        corner(bar, 3)
        local fill = make("Frame", {Size = UDim2.fromScale((current - low) / (high - low), 1),
            BorderSizePixel = 0}, bar)
        corner(fill, 3)
        bindAccent(fill, "BackgroundColor3")
        local knob = make("Frame", {Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(1, .5),
            BackgroundColor3 = COL.text, BorderSizePixel = 0}, fill)
        corner(knob, 6)
        local dragging, touchInput = false, nil
        local function setValue(value, animate)
            current = math.clamp(low + math.floor((value - low) / step + .5) * step,
                low, high)
            tween(fill, {Size = UDim2.fromScale((current - low) / (high - low), 1)},
                animate and .08 or 0)
            valueLabel.Text = step < 1 and string.format("%.2f", current) or tostring(current)
            if callback then callback(current) end
        end
        local function update(x)
            if touchArea.AbsoluteSize.X <= 0 then return end
            local amount = math.clamp((x - touchArea.AbsolutePosition.X)
                / touchArea.AbsoluteSize.X, 0, 1)
            setValue(low + (high - low) * amount, true)
        end
        connect(touchArea.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging, touchInput = true, input.UserInputType == Enum.UserInputType.Touch
                    and input or nil
                update(input.Position.X)
            end
        end)
        connect(UIS.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input == touchInput then dragging, touchInput = false, nil end
        end)
        connect(UIS.InputChanged, function(input)
            if dragging and (input == touchInput
                or (not touchInput and input.UserInputType == Enum.UserInputType.MouseMovement)) then
                update(input.Position.X)
            end
        end)
        return {Set = function(_, value) setValue(value, true) end,
            Get = function() return current end}
    end
    function tab:AddDropdown(value, options, initial, callback)
        local current = initial or options[1]
        local frame = row(35)
        frame.ClipsDescendants = true
        label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(.48, 0, 0, 35), COL.text)
        local choice = label(frame, tostring(current) .. "  ▾",
            UDim2.new(.42, 0, 0, 0), UDim2.new(.58, -10, 0, 35),
            COL.muted, Enum.Font.Gotham, 11, Enum.TextXAlignment.Right)
        local opened = false
        local function setOpen(on)
            opened = on
            tween(frame, {Size = UDim2.new(1, 0, 0,
                on and (41 + #options * 28) or 35)}, .22)
        end
        local header = make("TextButton", {Size = UDim2.new(1, 0, 0, 35),
            BackgroundTransparency = 1, Text = ""}, frame)
        connect(header.MouseButton1Click, function() setOpen(not opened) end)
        for i, option in ipairs(options) do
            local selected = option
            local item = make("TextButton", {Size = UDim2.new(1, -16, 0, 26),
                Position = UDim2.fromOffset(8, 35 + (i - 1) * 28),
                BackgroundColor3 = COL.card, Text = option, TextColor3 = COL.text,
                Font = Enum.Font.Gotham, TextSize = 11, AutoButtonColor = false}, frame)
            corner(item, 8)
            connect(item.MouseButton1Click, function()
                current, choice.Text = selected, selected .. "  ▾"
                setOpen(false)
                if callback then callback(selected) end
            end)
        end
        return {Set = function(_, value)
            if not table.find(options, value) then return end
            current, choice.Text = value, value .. "  ▾"
            setOpen(false)
            if callback then callback(value) end
        end, Get = function() return current end}
    end
    function tab:AddKeybind(value, key, callback)
        local entry = {key = key, callback = callback}
        table.insert(keybinds, entry)
        local frame = row(35)
        label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(1, -120, 1, 0), COL.text)
        local button = make("TextButton", {Size = UDim2.fromOffset(96, 23),
            Position = UDim2.new(1, -106, .5, -11),
            BackgroundColor3 = COL.card, Text = key.Name,
            TextColor3 = COL.muted, Font = Enum.Font.GothamBold,
            TextSize = 10, AutoButtonColor = false}, frame)
        corner(button, 11)
        connect(button.MouseButton1Click, function()
            listening = entry
            button.Text = "PRESS A KEY..."
            tween(button, {BackgroundColor3 = COL.accent, TextColor3 = COL.text})
        end)
        entry.paint = function()
            button.Text = entry.key.Name
            tween(button, {BackgroundColor3 = COL.card, TextColor3 = COL.muted})
        end
        return entry
    end
    function tab:AddAccentPicker(value)
        local frame = row(64)
        label(frame, value or "Accent color", UDim2.fromOffset(10, 6),
            UDim2.new(1, -20, 0, 20), COL.text)
        for i, color in ipairs(ACCENTS) do
            local x = 10 + (i - 1) * 36
            local swatch = make("TextButton", {Size = UDim2.fromOffset(28, 28),
                Position = UDim2.fromOffset(x, 28), BackgroundColor3 = color,
                Text = "", AutoButtonColor = false}, frame)
            corner(swatch, 14)
            connect(swatch.MouseButton1Click, function() setAccent(color) end)
        end
    end
    return tab
end

-- Three focused pages with scrolling; each requested feature has a control.
local aimTab = Window:AddTab("Aim", "Targets inside the FOV circle")
aimTab:AddSection("Aimbot")
local aimToggle = aimTab:AddToggle("Enable Aimbot  /  F2", C.Aim,
    function(on) C.Aim = on end)
aimTab:AddToggle("Prediction system", C.Prediction,
    function(on) C.Prediction = on end)
aimTab:AddToggle("Visible check", C.CheckSight,
    function(on) C.CheckSight = on end)
aimTab:AddToggle("Draw target line", C.TargetLine,
    function(on) C.TargetLine = on end)
aimTab:AddToggle("Draw FOV circle", C.FOV,
    function(on) C.FOV = on end)
aimTab:AddSlider("Adjustable FOV", 75, 400, C.Radius,
    function(value) C.Radius = value end, 5)
aimTab:AddDropdown("Aim feel", {"Smooth", "Strong", "Snap"}, C.Strength,
    function(value) C.Strength = value end)
aimTab:AddToggle("Strict duel ID filter", C.MatchFilter,
    function(on) C.MatchFilter = on end)
aimTab:AddSection("Optional firing")
aimTab:AddToggle("Auto fire", C.AutoFire,
    function(on) C.AutoFire = on end)
aimTab:AddLabel("F2 enables aim; F1 closes the menu to start aiming.")

local visualsTab = Window:AddTab("Visuals", "Blue allies  •  pink enemies  •  gray unknown")
visualsTab:AddSection("Player visuals")
visualsTab:AddToggle("Enable player ESP", C.ESP,
    function(on) C.ESP = on end)
for _, option in ipairs({
    {"Box", "Boxes"}, {"Distance", "Distance"},
    {"Player name", "Names"}, {"Platform", "Platform"},
    {"Directional arrows", "Arrows"}, {"2D radar", "Radar"},
    {"Visible check", "ESPVisibleCheck"},
}) do
    local key = option[2]
    visualsTab:AddToggle(option[1], C[key], function(on) C[key] = on end)
end
visualsTab:AddLabel("Platform shows Unknown unless RIVALS shares it.")
visualsTab:AddLabel("Gray = team unverified; never aimed or auto fired.")
visualsTab:AddLabel("Radar and arrows track replicated players at any distance.")

local moveTab = Window:AddTab("Movement", "Local character speed")
moveTab:AddSection("Speed")
moveTab:AddToggle("Speed boost", C.SpeedEnabled,
    function(on) C.SpeedEnabled = on end)
moveTab:AddSlider("WalkSpeed", 16, 50, C.SpeedValue,
    function(value) C.SpeedValue = value end, 1)
moveTab:AddLabel("Applied locally; the game may restore or reject it.")
moveTab:AddLabel("Turning it off restores the saved WalkSpeed.")

-- These input helpers vary by executor. When unavailable, the ESP and aim
-- still work; shots remain under the player's normal mouse control.
local function resolveMouseClick()
    local env
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then env = result end
    end
    local click = type(mouse1click) == "function" and mouse1click
        or env and type(env.mouse1click) == "function" and env.mouse1click
    if click then return click end
    local press = type(mouse1press) == "function" and mouse1press
        or env and type(env.mouse1press) == "function" and env.mouse1press
    local release = type(mouse1release) == "function" and mouse1release
        or env and type(env.mouse1release) == "function" and env.mouse1release
    if press and release then
        return function() press(); release() end
    end
    return nil
end
local fireClick, lastShot, shotCount = resolveMouseClick(), 0, 0
C.AimMethod = "Camera"
table.insert(keybinds, {key = Enum.KeyCode.F1,
    callback = function() Window:Toggle() end})
table.insert(keybinds, {key = Enum.KeyCode.F2,
    callback = function() aimToggle:Set(not C.Aim) end})

local function inputButton(input)
    if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode end
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2
        or t == Enum.UserInputType.MouseButton3 then return t end
    return nil
end
connect(UIS.InputBegan, function(input, processed)
    local pressed = inputButton(input)
    if listening then
        if pressed and pressed ~= Enum.KeyCode.F10
            and pressed ~= Enum.KeyCode.Escape then
            local old = listening.key
            for _, other in ipairs(keybinds) do
                if other ~= listening and other.key == pressed then
                    other.key = old
                    other.paint()
                end
            end
            listening.key = pressed
            listening.paint()
            listening = nil
        elseif pressed == Enum.KeyCode.Escape then
            listening.paint()
            listening = nil
        end
        return
    end
    if UIS:GetFocusedTextBox() then return end
    -- Keep F1/F2 usable if the FPS consumes keyboard input; ignore UI mouse clicks.
    if processed and input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if pressed == Enum.KeyCode.F10 then Window:Destroy(); return end
    for _, binding in ipairs(keybinds) do
        if pressed == binding.key then binding.callback(); return end
    end
end)

-- Upload optional RIVALS Nightfall artwork to Roblox and set ART_ASSET_ID above.
-- Keeping image bytes out of the Lua source makes remote loading much faster.

-- Backend begins below: player/NPC filtering, ESP, and head acquisition.
local bonesR15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
}
local bonesR6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function removeOverlay(model)
    local o = overlays[model]
    if not o then return end
    o.box:Destroy()
    o.name:Destroy()
    o.distance:Destroy()
    o.barBG:Destroy()
    o.tracer:Destroy()
    o.arrow:Destroy()
    o.offName:Destroy()
    o.dot:Destroy()
    for _, segment in ipairs(o.bones) do segment:Destroy() end
    if o.highlight then o.highlight:Destroy() end
    overlays[model] = nil
end

local function createOverlay(model)
    local box = make("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
    }, gui)
    local stroke = make("UIStroke", {Color = COL.enemy, Thickness = 1.5}, box)
    local name = make("TextLabel", {
        BackgroundTransparency = 1, TextColor3 = COL.text, TextStrokeTransparency = .25,
        Font = Enum.Font.GothamBold, TextSize = 12, Visible = false,
    }, gui)
    local distance = make("TextLabel", {
        BackgroundTransparency = 1, TextColor3 = COL.muted, TextStrokeTransparency = .2,
        Font = Enum.Font.Gotham, TextSize = 10, Visible = false,
    }, gui)
    local barBG = make("Frame", {
        BackgroundColor3 = COL.card, BorderSizePixel = 0, Visible = false,
    }, gui)
    local fill = make("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        BackgroundColor3 = COL.good,
    }, barBG)
    local tracer = line(gui, 1, COL.enemy)
    local arrow = make("TextLabel", {AnchorPoint = Vector2.new(.5, .5),
        Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1,
        Text = "▲", TextColor3 = COL.enemy, Font = Enum.Font.GothamBold,
        TextSize = 22, TextStrokeTransparency = .25,
        Visible = false, ZIndex = 4}, gui)
    local offName = make("TextLabel", {AnchorPoint = Vector2.new(.5, .5),
        Size = UDim2.fromOffset(140, 32), BackgroundColor3 = COL.bg,
        BackgroundTransparency = .32, TextColor3 = COL.text,
        Font = Enum.Font.GothamBold, TextSize = 10, TextWrapped = true,
        TextStrokeTransparency = .3, Visible = false, ZIndex = 4}, gui)
    corner(offName, 6)
    local dot = make("Frame", {AnchorPoint = Vector2.new(.5, .5),
        Size = UDim2.fromOffset(7, 7), BackgroundColor3 = COL.enemy,
        BorderSizePixel = 0, Visible = false, ZIndex = 7}, radar)
    corner(dot, 4)
    local bones = {}
    for i = 1, #bonesR15 do bones[i] = line(gui, 1, COL.enemy) end
    local o = {box = box, stroke = stroke, name = name, distance = distance,
        barBG = barBG, fill = fill, tracer = tracer, arrow = arrow,
        offName = offName,
        dot = dot, bones = bones, highlight = nil}
    overlays[model] = o
    return o
end
local function hideOverlay(o)
    show(o.box, false); show(o.name, false); show(o.distance, false)
    show(o.barBG, false); show(o.tracer, false)
    show(o.arrow, false); show(o.offName, false); show(o.dot, false)
    for _, segment in ipairs(o.bones) do show(segment, false) end
    if o.highlight then o.highlight.Enabled = false end
end

local matchKeys = {"MatchId", "DuelId", "ArenaId", "CurrentMatch", "CurrentDuel"}
local function matchToken(player, model)
    for _, key in ipairs(matchKeys) do
        local value = player:GetAttribute(key) or (model and model:GetAttribute(key))
        if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "0" then
            return key, tostring(value)
        end
    end
    return nil, nil
end

local teamAttributeKeys = {"Team", "TeamId", "TeamName", "TeamIndex",
    "TeamNumber", "Side", "Faction", "MatchTeam", "DuelTeam"}
local function relation(player, model)
    if not player then return "unknown" end
    if player == LP then return "self" end
    -- Roblox team objects are direct assignments, provided both players
    -- currently have a team instead of a stale/default TeamColor.
    if not LP.Neutral and not player.Neutral and LP.Team and player.Team then
        return LP.Team == player.Team and "ally" or "enemy"
    end
    local arenaKey, arenaToken = matchToken(LP, LP.Character)
    local function inOurMatch(other)
        if not arenaKey then return true end
        local value = other:GetAttribute(arenaKey)
        if value == nil and other.Character then
            value = other.Character:GetAttribute(arenaKey)
        end
        return value ~= nil and tostring(value) == arenaToken
    end
    local peers = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= LP and inOurMatch(other) then
            table.insert(peers, other)
        end
    end
    local function value(other, key, character)
        local token = other:GetAttribute(key)
        if token == nil and character then token = character:GetAttribute(key) end
        return token
    end
    -- A confirmed two-player duel cannot provide a second teammate for
    -- cross-checking. Only explicit team fields, paired with the same duel ID,
    -- are used to classify its single opponent.
    if arenaToken and #peers == 1 and peers[1] == player then
        for _, key in ipairs({"Team", "TeamId", "TeamName", "MatchTeam", "DuelTeam"}) do
            local ours, theirs = value(LP, key, LP.Character), value(player, key, model)
            if ours ~= nil and theirs ~= nil and tostring(ours) ~= ""
                and tostring(theirs) ~= "" then
                return tostring(ours) == tostring(theirs) and "ally" or "enemy"
            end
        end
    end
    -- Do not mistake a unique per-player ID for a team ID. Require a
    -- teammate with the same value and an opponent with a different value.
    for _, key in ipairs(teamAttributeKeys) do
        local ours = value(LP, key, LP.Character)
        local theirs = value(player, key, model)
        if ours ~= nil and theirs ~= nil then
            local same, different = false, false
            for _, other in ipairs(peers) do
                local token = value(other, key, other.Character)
                if token ~= nil then
                    if tostring(token) == tostring(ours) then same = true
                    else different = true end
                end
            end
            if same and different then
                return tostring(ours) == tostring(theirs) and "ally" or "enemy"
            end
        end
    end
    if not LP.Neutral and not player.Neutral then
        local same, different = false, false
        for _, other in ipairs(peers) do
            if not other.Neutral then
                if LP.TeamColor == other.TeamColor then same = true
                else different = true end
            end
        end
        if same and different then
            return LP.TeamColor == player.TeamColor and "ally" or "enemy"
        end
    end
    return "unknown"
end

local function screenPoint(camera, world)
    local v, visible = camera:WorldToViewportPoint(world)
    return Vector2.new(v.X, v.Y), visible and v.Z > 0
end
local function visibleHead(camera, model, head)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignored = {camera}
    if LP.Character then table.insert(ignored, LP.Character) end
    params.FilterDescendantsInstances = ignored
    params.IgnoreWater = true
    local delta = head.Position - camera.CFrame.Position
    local result = workspace:Raycast(camera.CFrame.Position, delta, params)
    return result == nil or result.Instance:IsDescendantOf(model)
end
local function feetPoint(model, root, hum)
    local left = model:FindFirstChild("LeftFoot") or model:FindFirstChild("Left Leg")
    local right = model:FindFirstChild("RightFoot") or model:FindFirstChild("Right Leg")
    if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
        local lowest = math.min(left.Position.Y - left.Size.Y / 2,
            right.Position.Y - right.Size.Y / 2)
        return Vector3.new(root.Position.X, lowest, root.Position.Z)
    end
    return root.Position - Vector3.new(0,
        root.Size.Y / 2 + (hum and hum.HipHeight or 2), 0)
end

local function rigRoot(model)
    local part = model:FindFirstChild("HumanoidRootPart", true)
        or model.PrimaryPart or model:FindFirstChild("UpperTorso", true)
        or model:FindFirstChild("Torso", true)
    return part and part:IsA("BasePart") and part or nil
end
local function rigHead(model)
    local part = model:FindFirstChild("Head", true)
        or model:FindFirstChild("UpperTorso", true)
        or model:FindFirstChild("Torso", true)
    return part and part:IsA("BasePart") and part or nil
end
local function livingModel(model)
    if not model or not model:IsDescendantOf(workspace) then return false, nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then return humanoid.Health > 0, humanoid end
    if model:GetAttribute("IsDead") == true
        or model:GetAttribute("Alive") == false then return false, nil end
    local health = model:GetAttribute("Health")
    if type(health) == "number" and health <= 0 then return false, nil end
    -- Some experiences replace Humanoids with custom rigs. Require a live
    -- Player.Character with both a head and root before considering it.
    return rigRoot(model) ~= nil, nil
end

local cachedList, cachedPresent, lastListBuild = nil, nil, 0
local function targetList()
    local now = os.clock()
    if cachedList and now - lastListBuild < .12 then
        return cachedList, cachedPresent
    end
    local result, present = {}, {}
    local aimEligible, unavailable = 0, 0
    local localKey, localToken = matchToken(LP, LP.Character)
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        local candidateToken = localKey and (player:GetAttribute(localKey)
            or (model and model:GetAttribute(localKey)))
        local mismatched = localToken and candidateToken ~= nil
            and tostring(candidateToken) ~= localToken
        local allowed = not mismatched and
            (not C.MatchFilter or not localToken or candidateToken ~= nil)
        if player ~= LP and model then
            local item = {player = player, model = model,
                name = player.DisplayName, aimAllowed = allowed}
            present[model] = true
            table.insert(result, item)
            if allowed then
                aimEligible += 1
            else
                unavailable += 1
            end
        end
    end
    local usedFallback = localToken and aimEligible == 0 and unavailable > 0
    -- Every replicated player may appear on ESP. Only confirmed match
    -- participants remain eligible for aim and auto fire.
    matchStatus = usedFallback and "MATCH ID MISMATCH - VISUAL ONLY"
        or localToken and (C.MatchFilter and "DUEL ID FOUND" or "DUEL FILTER OFF")
        or "DUEL ID UNAVAILABLE"
    if C.NPCs then
        for hum in pairs(npcHumanoids) do
            local model = hum.Parent
            if not hum:IsDescendantOf(workspace) then
                npcHumanoids[hum] = nil
            elseif model and model:IsA("Model") and not present[model]
                and not Players:GetPlayerFromCharacter(model) then
                present[model] = true
                table.insert(result, {model = model, name = model.Name, aimAllowed = true})
            end
        end
    end
    cachedList, cachedPresent, lastListBuild = result, present, now
    return result, present
end

-- Run this at aim priority, using the latest camera pose. ESP is updated
-- separately and can be disabled without affecting head acquisition.
local function targetPosition(camera, head)
    local position = head.Position
    if not C.Prediction then return position end
    local model = head.Parent
    local root = model and model:FindFirstChild("HumanoidRootPart")
    local movingPart = root and root:IsA("BasePart") and root or head
    local velocity = movingPart.AssemblyLinearVelocity
    local lead = math.clamp((position - camera.CFrame.Position).Magnitude / 3000,
        .02, .14)
    return position + velocity * lead
end
local function acquireHead(camera)
    local center = camera.ViewportSize / 2
    local candidate, name, distance, player, score
    local counts = {models = 0, rigs = 0, onScreen = 0,
        inside = 0, clear = 0, blocked = 0, unknown = 0, allies = 0}
    for _, item in ipairs(targetList()) do
        local model = item.model
        if item.aimAllowed then
        counts.models += 1
        local alive = livingModel(model)
        local head = model:FindFirstChild(C.TargetPart, true)
            or (C.TargetPart == "UpperTorso" and model:FindFirstChild("Torso", true))
            or model:FindFirstChild("Head", true)
        if alive and head and head:IsA("BasePart") then
            counts.rigs += 1
            local kind = relation(item.player, model)
            local point, projected = screenPoint(camera, targetPosition(camera, head))
            local dist = (head.Position - camera.CFrame.Position).Magnitude
            if projected and dist <= C.Range then
                counts.onScreen += 1
                if (point - center).Magnitude <= C.Radius then
                    counts.inside += 1
                    if kind == "ally" then counts.allies += 1
                    elseif kind == "unknown" then counts.unknown += 1
                    elseif kind == "enemy" then
                        if not C.CheckSight or visibleHead(camera, model, head) then
                            counts.clear += 1
                            local rank = (point - center).Magnitude + dist * .025
                            if C.Sticky and head == lockedHead and item.player == lockedPlayer then
                                rank -= 10000
                            end
                            if not score or rank < score then
                                candidate, name, distance, player, score =
                                    head, item.name, dist, item.player, rank
                            end
                        else counts.blocked += 1 end
                    end
                end
            end
        end
        end
    end
    return candidate, name, distance, player, counts
end

local function platformName(player)
    if not player then return "Unknown" end
    for _, key in ipairs({"Platform", "DeviceType", "Device", "InputType"}) do
        local value = player:GetAttribute(key)
        if value == nil then
            local child = player:FindFirstChild(key)
            if child and child:IsA("StringValue") then value = child.Value end
        end
        if type(value) == "string" and value ~= "" then
            return value:gsub("[%c]", ""):sub(1, 18)
        end
    end
    return "Unknown"
end

local function placeArrow(o, camera, root, viewport, center, color, point, item, distance)
    local delta = point - center
    if (root.Position - camera.CFrame.Position):Dot(camera.CFrame.LookVector) < 0 then
        local offset = root.Position - camera.CFrame.Position
        delta = Vector2.new(offset:Dot(camera.CFrame.RightVector),
            math.max(8, -offset:Dot(camera.CFrame.LookVector)))
    end
    if delta.Magnitude < 1 then delta = Vector2.new(0, 1) end
    local width = math.max(1, center.X - 26)
    local height = math.max(1, center.Y - 26)
    local amount = math.min(width / math.max(math.abs(delta.X), .001),
        height / math.max(math.abs(delta.Y), .001))
    local edge = center + delta * amount
    o.arrow.Position = UDim2.fromOffset(edge.X, edge.Y)
    o.arrow.Rotation = math.deg(math.atan2(delta.Y, delta.X)) + 90
    o.arrow.TextColor3 = color
    local inward = edge - delta.Unit * 37
    o.offName.Position = UDim2.fromOffset(
        math.clamp(inward.X, math.min(75, viewport.X / 2),
            math.max(viewport.X - 75, viewport.X / 2)),
        math.clamp(inward.Y, math.min(20, viewport.Y / 2),
            math.max(viewport.Y - 20, viewport.Y / 2)))
    o.offName.Text = string.format("%s\n%d studs",
        item.name:sub(1, 18), math.floor(distance + .5))
    o.offName.TextColor3 = color
    show(o.arrow, C.ESP and C.Arrows)
    show(o.offName, C.ESP and C.Arrows)
end

local radarRange = 300
local function placeRadarDot(o, camera, root, origin, color)
    local offset = root.Position - origin
    local right = offset:Dot(camera.CFrame.RightVector)
    local forward = offset:Dot(camera.CFrame.LookVector)
    local point = Vector2.new(right, -forward) * (66 / radarRange)
    if point.Magnitude > 66 then point = point.Unit * 66 end
    o.dot.Position = UDim2.fromOffset(80 + point.X, 80 + point.Y)
    o.dot.BackgroundColor3 = color
    show(o.dot, C.ESP and C.Radar)
end

local espStats = {drawn = 0, offscreen = 0, candidates = 0,
    noRig = 0, unknown = 0}
local function updateOverlay(item, camera, viewport, center, origin)
    local model, player = item.model, item.player
    local relationship = relation(player, model)
    local alive, hum = livingModel(model)
    local head, root = rigHead(model), rigRoot(model)
    local o = overlays[model]
    if relationship == "ally" and not C.Allies then
        if o then hideOverlay(o) end
        return
    end
    if not alive or not head or not root then
        espStats.noRig += 1
        if o then hideOverlay(o) end
        return
    end
    local dist = (root.Position - origin).Magnitude
    if not C.ESP or (C.ESPVisibleCheck and not visibleHead(camera, model, head)) then
        if o then hideOverlay(o) end
        return
    end
    if relationship == "unknown" then espStats.unknown += 1 end
    local color = relationship == "ally" and COL.ally
        or relationship == "enemy" and COL.enemy or COL.unknown
    local head2, onScreen = screenPoint(camera, head.Position)
    if not onScreen or head2.X < 0 or head2.X > viewport.X
        or head2.Y < 0 or head2.Y > viewport.Y then
        espStats.offscreen += 1
        if not o then o = createOverlay(model) end
        hideOverlay(o)
        placeRadarDot(o, camera, root, origin, color)
        placeArrow(o, camera, root, viewport, center, color, head2, item, dist)
        return
    end
    local top2 = screenPoint(camera, head.Position + Vector3.new(0, head.Size.Y / 2 + .35, 0))
    local foot2 = screenPoint(camera, feetPoint(model, root, hum))
    local h = math.max(16, math.abs(foot2.Y - top2.Y))
    local w = math.clamp(h * .52, 8, viewport.X)
    local x, y = head2.X - w / 2, top2.Y
    if y > viewport.Y or y + h < 0 then
        espStats.offscreen += 1
        if not o then o = createOverlay(model) end
        hideOverlay(o)
        placeRadarDot(o, camera, root, origin, color)
        placeArrow(o, camera, root, viewport, center, color, head2, item, dist)
        return
    end
    if not o then o = createOverlay(model) end
    show(o.arrow, false)
    show(o.offName, false)
    placeRadarDot(o, camera, root, origin, color)
    o.stroke.Color = color
    o.tracer.BackgroundColor3 = color
    o.box.Position = UDim2.fromOffset(x, y)
    o.box.Size = UDim2.fromOffset(w, h)
    show(o.box, C.Boxes)
    o.name.Text = (C.Names and item.name or "")
        .. (relationship == "unknown" and " [TEAM ?]" or "")
        .. (C.Platform and (" [" .. platformName(player) .. "]") or "")
    o.name.TextColor3 = color
    o.name.Position = UDim2.fromOffset(x - 45, y - 20)
    o.name.Size = UDim2.fromOffset(w + 90, 18)
    show(o.name, C.Names or C.Platform or relationship == "unknown")
    o.distance.Text = tostring(math.floor(dist + .5)) .. " studs"
    o.distance.TextColor3 = color
    o.distance.Position = UDim2.fromOffset(x - 20, y + h + 2)
    o.distance.Size = UDim2.fromOffset(w + 40, 16)
    show(o.distance, C.Distance)
    o.barBG.Position = UDim2.fromOffset(x - 7, y)
    o.barBG.Size = UDim2.fromOffset(4, h)
    local hp = hum and hum.Health or model:GetAttribute("Health")
    local maxHp = hum and hum.MaxHealth or model:GetAttribute("MaxHealth")
    local fraction = type(hp) == "number" and type(maxHp) == "number"
        and math.clamp(hp / math.max(maxHp, 1), 0, 1) or 1
    o.fill.Size = UDim2.fromScale(1, fraction)
    o.fill.BackgroundColor3 = COL.enemy:Lerp(COL.good, fraction)
    show(o.barBG, C.Health and type(hp) == "number" and type(maxHp) == "number")
    if C.Tracers then
        placeLine(o.tracer, Vector2.new(center.X, viewport.Y - 12), Vector2.new(head2.X, y + h), 1)
    else show(o.tracer, false) end
    espStats.drawn += 1
    if C.Outlines then
        if not o.highlight or o.highlight.Parent ~= model then
            if o.highlight then o.highlight:Destroy() end
            o.highlight = make("Highlight", {
                Adornee = model, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillColor = color, FillTransparency = .82,
                OutlineColor = color, OutlineTransparency = .05,
            }, model)
        end
        o.highlight.FillColor = color
        o.highlight.OutlineColor = color
        o.highlight.Enabled = true
    elseif o.highlight then o.highlight.Enabled = false end

    local pairsForRig = hum and hum.RigType == Enum.HumanoidRigType.R6
        and bonesR6 or bonesR15
    for i, segment in ipairs(o.bones) do
        segment.BackgroundColor3 = color
        local pair = C.Skeleton and pairsForRig[i]
        local a = pair and model:FindFirstChild(pair[1])
        local b = pair and model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local p1, v1 = screenPoint(camera, a.Position)
            local p2, v2 = screenPoint(camera, b.Position)
            if v1 and v2 then placeLine(segment, p1, p2, 1.5)
            else show(segment, false) end
        else show(segment, false) end
    end
end

connect(workspace.DescendantAdded, function(obj)
    if C.NPCs and obj:IsA("Humanoid") and obj.Parent:IsA("Model") then
        npcHumanoids[obj] = true
    end
end)
connect(Players.PlayerRemoving, function(player)
    if player.Character then removeOverlay(player.Character) end
end)

local speedHumanoid, originalSpeed, speedApplied = nil, nil, false
local speedState = "OFF"
local function restoreSpeed()
    if speedApplied and speedHumanoid and speedHumanoid.Parent
        and originalSpeed then
        pcall(function() speedHumanoid.WalkSpeed = originalSpeed end)
    end
    speedApplied = false
end
connect(RunService.Heartbeat, function()
    if not running then return end
    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid ~= speedHumanoid then
        restoreSpeed()
        speedHumanoid = humanoid
        originalSpeed = humanoid and humanoid.WalkSpeed or nil
    end
    if C.SpeedEnabled then
        if humanoid then
            if humanoid.WalkSpeed ~= C.SpeedValue then
                humanoid.WalkSpeed = C.SpeedValue
            end
            speedApplied = true
            speedState = tostring(C.SpeedValue) .. " LOCAL"
        else
            speedState = "NO HUMANOID"
        end
    else
        if speedApplied then restoreSpeed()
        elseif humanoid then originalSpeed = humanoid.WalkSpeed end
        speedState = "OFF"
    end
end)

local elapsed, statusElapsed = 0, 0
local function onRender(dt)
    if not running then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local center = viewport / 2
    circle.Position = UDim2.fromOffset(center.X, center.Y)
    circle.Size = UDim2.fromOffset(C.Radius * 2, C.Radius * 2)
    show(circle, C.FOV)
    show(radar, C.ESP and C.Radar)
    indicator.Position = UDim2.fromOffset(center.X, center.Y + C.Radius + 12)
    show(aimState, C.StatusOverlay)

    elapsed += dt
    if elapsed < 1 / 30 then return end
    elapsed = math.min(elapsed - 1 / 30, 1 / 30)
    local localRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local list, present = targetList()
    espStats.drawn, espStats.offscreen, espStats.candidates,
        espStats.noRig, espStats.unknown = 0, 0, #list, 0, 0
    local farthest = 300
    for _, item in ipairs(list) do
        local root = rigRoot(item.model)
        if root then
            farthest = math.max(farthest, (root.Position - origin).Magnitude * 1.08)
        end
    end
    -- Expand immediately when a distant player arrives, and contract gently
    -- after they leave so nearby dots do not jump across the radar.
    if farthest > radarRange then radarRange = farthest
    else radarRange += (farthest - radarRange) * math.clamp(dt * 3, 0, 1) end
    radarScaleLabel.Text = string.format("RADAR  %d studs", math.floor(radarRange))
    for model in pairs(overlays) do
        if not model:IsDescendantOf(workspace) or not present[model] then
            removeOverlay(model)
        end
    end
    for _, item in ipairs(list) do
        updateOverlay(item, camera, viewport, center, origin)
    end
    local held = C.Aim and (not active or not C.PauseInMenu)
    local head = bestTarget
    circleStroke.Color = head and COL.enemy or COL.accent
    if C.TargetLine and held and head and head.Parent
        and head:IsDescendantOf(workspace) then
        local point, onScreen = screenPoint(camera, targetPosition(camera, head))
        if onScreen then placeLine(targetLine, center, point, 1.5)
        else show(targetLine, false) end
    else show(targetLine, false) end
    if C.Indicator and head and head.Parent and head:IsDescendantOf(workspace) then
        local label = C.Aim and held and "LOCK" or "IN FOV"
        local headScreen = screenPoint(camera, head.Position)
        if C.Headshot and C.TargetPart == "Head"
            and (headScreen - center).Magnitude <= 12 then
            label = "HEAD ALIGNED"
        end
        indicator.Text = string.format("%s  %s  •  %d studs", label, bestName or "target",
            math.floor((bestDistance or 0) + .5))
        indicator.TextColor3 = C.Aim and held and COL.enemy or COL.text
        show(indicator, true)
    else show(indicator, false) end
    statusElapsed += 1 / 30
    if statusElapsed >= .25 then
        statusElapsed = 0
        aimState.Text = "AIM  " .. aimReason .. "  •  F2 TO TOGGLE"
        aimState.TextColor3 = C.Aim and bestTarget and COL.enemy or COL.muted
        aimChip.Text = C.Aim and "AIM  ON" or "AIM  OFF"
        aimChip.TextColor3 = C.Aim and COL.enemy or COL.muted
        aimChip.BackgroundColor3 = C.Aim and COL.raised or COL.card
        status.Text = string.format("AIM %s   ESP %s (%d/%d)   OFFSCREEN %d   FOV %d   FIRE %s\n%s   |   GRAY %d   NO RIG %d",
            C.Aim and "ON" or "OFF", C.ESP and "ON" or "OFF",
            espStats.drawn, espStats.candidates, espStats.offscreen, C.Radius,
            C.AutoFire and (fireClick and "READY" or "UNAVAILABLE") or "OFF",
            matchStatus, espStats.unknown, espStats.noRig)
        if active then
            dashTarget.Text = bestName or "Searching"
            dashAim.Text = aimReason
            dashAim.TextColor3 = bestTarget and COL.enemy or COL.muted
            dashCount.Text = string.format("%d pink / %d unknown",
                aimCounts.clear, aimCounts.unknown)
        end
    end
end

local lastAimError = nil
local function angleDegrees(a, b)
    return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end
local function fireAtEnemy(camera, player, head, errorAngle)
    if not C.AutoFire or not fireClick or active or errorAngle > .8 then return end
    if os.clock() - lastShot < .15 then return end
    local model = player and player.Character
    if not model or head.Parent ~= model or relation(player, model) ~= "enemy" then return end
    local center = camera.ViewportSize / 2
    local ray = camera:ViewportPointToRay(center.X, center.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {camera, LP.Character}
    params.IgnoreWater = true
    local hit = workspace:Raycast(ray.Origin, ray.Direction * C.Range, params)
    if not hit or not hit.Instance:IsDescendantOf(model) then return end
    lastShot = os.clock()
    local ok = pcall(fireClick)
    if ok then shotCount += 1 else fireClick = nil end
end
local function onAimStep(dt)
    if not running then return end
    local camera = workspace.CurrentCamera
    if not camera then aimReason = "NO CAMERA" return end
    local localCharacter = LP.Character
    local localAlive = livingModel(localCharacter)
    if not localAlive then
        bestTarget, bestName, bestDistance, bestPlayer = nil, nil, nil, nil
        lockedHead, lockedPlayer = nil, nil
        aimCounts = {models = 0, rigs = 0, onScreen = 0,
            inside = 0, clear = 0, blocked = 0, unknown = 0, allies = 0}
        aimReason = "WAITING FOR DUEL / RESPAWN"
        return
    end
    local head, name, distance, player, counts = acquireHead(camera)
    aimCounts = counts
    bestTarget, bestName, bestDistance, bestPlayer = head, name, distance, player
    if not C.Aim then
        lockedHead, lockedPlayer = nil, nil
        aimReason = "OFF"
        return
    end
    if active and C.PauseInMenu then
        lockedHead, lockedPlayer = nil, nil
        aimReason = "MENU OPEN - F1"
        return
    end
    if UIS:GetFocusedTextBox() then aimReason = "TEXT BOX FOCUSED" return end
    if not head then
        lockedHead, lockedPlayer = nil, nil
        aimReason = counts.unknown > 0 and "TEAM UNKNOWN"
            or counts.blocked > 0 and "TARGET BLOCKED"
            or counts.allies > 0 and "ONLY TEAMMATES"
            or counts.models == 0 and "NO PLAYERS IN MATCH"
            or counts.rigs == 0 and "NO CHARACTER HEAD/ROOT"
            or counts.onScreen == 0 and "NO TARGET ON SCREEN"
            or "NO TARGET IN CIRCLE"
        return
    end
    lockedHead, lockedPlayer = head, player
    local alpha = 1 - math.exp(-C.AimSpeed * math.clamp(dt, 0, .1))
    if C.Strength == "Snap" then
        alpha = 1
    elseif C.Strength == "Strong" then
        alpha = math.max(alpha, .3)
    end
    local desired = CFrame.lookAt(camera.CFrame.Position,
        targetPosition(camera, head))
    if angleDegrees(camera.CFrame.LookVector, desired.LookVector) <= 1.25 then
        alpha = 1
    end
    camera.CFrame = camera.CFrame:Lerp(desired, alpha)
    aimWrites += 1
    local errorAngle = angleDegrees(camera.CFrame.LookVector, desired.LookVector)
    aimReason = string.format("%s %s %.1f deg", C.Strength, C.TargetPart, errorAngle)
    fireAtEnemy(camera, player, head, errorAngle)
end
local function onAim(dt)
    local ok, err = pcall(onAimStep, dt)
    if not ok then
        local message = tostring(err)
        aimReason = "AIM ERROR: " .. message:sub(-65)
        if message ~= lastAimError then warn("RIVALS Nightfall v8 aim error: " .. message) end
        lastAimError = message
    end
end

local lastVisualError = nil
local function onVisualStep(dt)
    local ok, err = pcall(onRender, dt)
    if not ok then
        local message = tostring(err)
        status.Text = "VISUAL ERROR: " .. message:sub(-110)
        if message ~= lastVisualError then
            warn("RIVALS Nightfall v8 visual error: " .. message)
        end
        lastVisualError = message
    end
end

local function stop()
    if not running then return end
    running = false
    restoreSpeed()
    RunService:UnbindFromRenderStep(renderName)
    RunService:UnbindFromRenderStep(aimName)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for model in pairs(overlays) do removeOverlay(model) end
    gui:Destroy()
    table.clear(npcHumanoids)
    cachedList, cachedPresent = nil, nil
    if _G.RivalsNightfallStop == stop then _G.RivalsNightfallStop = nil end
end
_G.RivalsNightfallStop = stop
RunService:BindToRenderStep(aimName, Enum.RenderPriority.Last.Value, onAim)
RunService:BindToRenderStep(renderName, Enum.RenderPriority.Last.Value + 1, onVisualStep)
Window:Notify("RIVALS Nightfall v8 ready", "Map radar and arrows on; F2 aim, F1 closes menu", 4)

return Window
