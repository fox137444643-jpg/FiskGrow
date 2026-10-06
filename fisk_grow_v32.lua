--[[
    Fisk Grow v3.2
    - Красивый дизайн + сворачивание в маленькую панельку
    - Скорость: НЕ трогает WalkSpeed (анти-чит не детектит, не переносит назад)
    - ESP сущностей на всех этажах; этаж помечается ЦИФРОЙ в табличке [1] [2] [BD] [AR] [ST]
    - Выбор: какие сущности видны (поэтажные секции с галочками)
    - Авто-обнаружение неизвестных сущностей
    - Уведомления о появлении сущностей
    - Плавающая кнопка ◈ (тап) или RightShift: скрыть / показать меню
    - Работает на Xeno и Delta (мобильная версия)
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local lp = Players.LocalPlayer

-- ========= Настройки =========
local State = {
    speedOn = false,
    speed = 22,
    espOn = true,
    autoOn = true,
    notifyOn = true,
    entityVisible = {}, -- [отображаемое имя] = true/false
}
local MIN_SPEED, MAX_SPEED = 16, 80
local FULL_SIZE = UDim2.fromOffset(330, 430)
local COLLAPSED_SIZE = UDim2.fromOffset(330, 44)

-- ========= Этажи и сущности =========
-- Этаж: id помечается цифрой/тегом в ESP-табличке
local FLOORS = {
    { id = "1",  title = "1 · ОТЕЛЬ" },
    { id = "2",  title = "2 · ШАХТЫ" },
    { id = "BD", title = "BACKDOOR" },
    { id = "AR", title = "АРХИВЫ" },
    { id = "ST", title = "ЛЕСТНИЦЫ" },
}

-- [имя модели] = { отображаемое имя, этаж }
local ENTITIES = {
    -- Этаж 1: Отель
    RushMoving = {"Rush", "1"}, AmbushMoving = {"Ambush", "1"},
    A60 = {"A-60", "1"}, A120 = {"A-120", "1"}, A90 = {"A-90", "1"}, A200 = {"A-200", "1"},
    Eyes = {"Eyes", "1"}, Halt = {"Halt", "1"}, Screech = {"Screech", "1"},
    JeffTheKiller = {"Jeff", "1"}, Jack = {"Jack", "1"}, Snare = {"Snare", "1"},
    Dupe = {"Dupe", "1"}, Timothy = {"Timothy", "1"},
    Seek = {"Seek", "1"}, SeekMoving = {"Seek", "1"}, SeekMovingNewClone = {"Seek", "1"},
    FigureRig = {"Figure", "1"}, FigureRagdoll = {"Figure", "1"},
    Glitch = {"Glitch", "1"}, Void = {"Void", "1"}, Shadow = {"Shadow", "1"}, Surge = {"Surge", "1"},
    Dread = {"Dread", "1"}, Blitz = {"Blitz", "1"},
    -- Этаж 2: Шахты (включая Сад)
    Giggle = {"Giggle", "2"}, GiggleCeiling = {"Giggle", "2"},
    Grumble = {"Grumble", "2"}, GrumbleRig = {"Grumble", "2"},
    Gloombat = {"Gloombat", "2"}, GloombatSwarm = {"Gloombat", "2"},
    -- Backdoor
    BackdoorRush = {"Haste", "BD"}, Haste = {"Haste", "BD"},
    BackdoorLookman = {"Lookman", "BD"}, Lookman = {"Lookman", "BD"},
    Vacuum = {"Vacuum", "BD"},
    -- Архивы (бывшие Rooms)
    Honcho = {"Honcho", "AR"},
    Drone = {"Drone", "AR"}, Drones = {"Drone", "AR"},
    Bash = {"Bash", "AR"}, Ransom = {"Ransom", "AR"}, Scribbles = {"Scribbles", "AR"},
    Teller = {"Teller", "AR"},
    ForgetMeNot = {"Forget-Me-Not", "AR"}, ForgetMeNots = {"Forget-Me-Not", "AR"},
    Alma = {"Alma", "AR"}, Portrait = {"Portrait", "AR"}, Fih = {"Fih", "AR"},
    -- Лестницы (The Stairwell)
    Creak = {"Creak", "ST"}, Noise = {"Noise", "ST"}, Hijack = {"Hijack", "ST"},
    Stem = {"Stem", "ST"}, Stems = {"Stem", "ST"},
    CeramicStem = {"Stem", "ST"}, ClayStem = {"Stem", "ST"},
    Cobbler = {"Cobbler", "ST"}, Meld = {"Meld", "ST"}, Crusher = {"Crusher", "ST"},
}

-- уникальные сущности по этажам (для меню)
local floorEntities = {}
for id, _ in pairs(FLOORS) do floorEntities[FLOORS[id].id] = {} end
local seen = {}
for _, v in pairs(ENTITIES) do
    local name, fid = v[1], v[2]
    if not seen[name] then
        seen[name] = true
        table.insert(floorEntities[fid], name)
    end
end
for id, _ in pairs(FLOORS) do table.sort(floorEntities[FLOORS[id].id]) end
for name, _ in pairs(seen) do State.entityVisible[name] = true end

-- НЕ считать сущностями при авто-обнаружении
local IGNORE = {
    Camera = true, Terrain = true, CurrentRooms = true, Drops = true,
    DroppedItems = true, Pickups = true, Effects = true, Live = true,
    Entities = true, Rain = true, Ash = true, Generic = true,
}
local function isIgnoredName(name)
    if IGNORE[name] then return true end
    local n = name:lower()
    return n:find("door") or n:find("room") or n:find("drawer")
        or n:find("loot") or n:find("chest") or n:find("prop")
        or n:find("asset") or n:find("light") or n:find("lamp")
        or n:find("painting") or n:find("bed") or n:find("wardrobe")
        or n:find("railing") or n:find("wall") or n:find("decor")
end

-- ========= Родитель GUI =========
local function getParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local ok2 = pcall(function() return game:GetService("CoreGui"):GetChildren() end)
    if ok2 then return game:GetService("CoreGui") end
    return lp:WaitForChild("PlayerGui")
end

local parentGui = getParent()
pcall(function()
    local old = parentGui:FindFirstChild("DoorsHelper")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FiskGrow"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = parentGui

local espFolder = Instance.new("Folder")
espFolder.Name = "ESP"
espFolder.Parent = gui

local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

-- ========= Палитра =========
local COLORS = {
    bg       = Color3.fromRGB(16, 16, 24),
    bgTransp = 0.08,
    bar      = Color3.fromRGB(24, 24, 36),
    item     = Color3.fromRGB(30, 30, 44),
    itemHover= Color3.fromRGB(38, 38, 56),
    accent   = Color3.fromRGB(167, 139, 250),
    accent2  = Color3.fromRGB(99, 102, 241),
    accent3  = Color3.fromRGB(56, 189, 248),
    text     = Color3.fromRGB(240, 240, 250),
    sub      = Color3.fromRGB(140, 140, 165),
    off      = Color3.fromRGB(55, 55, 75),
    danger   = Color3.fromRGB(244, 63, 94),
    esp      = Color3.fromRGB(255, 80, 105),
    espText  = Color3.fromRGB(255, 140, 155),
    espUnk   = Color3.fromRGB(200, 205, 215),
}
local GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent),
    ColorSequenceKeypoint.new(0.55, COLORS.accent2),
    ColorSequenceKeypoint.new(1, COLORS.accent3),
})

-- ========= UI-хелперы =========
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, color, tr, th)
    local s = Instance.new("UIStroke")
    s.Color = color or COLORS.accent
    s.Transparency = tr or 0.6
    s.Thickness = th or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function label(parent, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size or 14
    l.TextColor3 = color or COLORS.text
    l.Font = font or Enum.Font.GothamMedium
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function smallButton(parent, text)
    local b = Instance.new("TextButton")
    b.Text = text
    b.TextSize = 16
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = COLORS.text
    b.BackgroundColor3 = COLORS.off
    b.AutoButtonColor = false
    b.Parent = parent
    corner(b, 6)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.itemHover }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.off }):Play()
    end)
    return b
end

local function smallBox(parent, text)
    local t = Instance.new("TextBox")
    t.Text = text
    t.TextSize = 14
    t.Font = Enum.Font.GothamBold
    t.TextColor3 = COLORS.accent
    t.PlaceholderColor3 = COLORS.sub
    t.BackgroundColor3 = COLORS.bg
    t.BackgroundTransparency = 0.3
    t.ClearTextOnFocus = false
    t.Parent = parent
    corner(t, 6)
    stroke(t, COLORS.accent2, 0.75, 1)
    return t
end

-- ========= Главное окно =========
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = FULL_SIZE
main.Position = UDim2.new(0.5, -165, 0.5, -215)
main.BackgroundColor3 = COLORS.bg
main.BackgroundTransparency = COLORS.bgTransp
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
corner(main, 14)
stroke(main, COLORS.accent2, 0.55, 1.2)

do
    local sh = Instance.new("Frame")
    sh.Name = "Shadow"
    sh.Size = UDim2.new(1, 18, 1, 18)
    sh.Position = UDim2.fromOffset(-9, -6)
    sh.BackgroundColor3 = Color3.new(0, 0, 0)
    sh.BackgroundTransparency = 0.55
    sh.BorderSizePixel = 0
    sh.ZIndex = 0
    sh.Parent = main
    corner(sh, 18)
end
main.ZIndex = 1

-- Заголовок
local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 44)
top.BackgroundColor3 = COLORS.bar
top.BackgroundTransparency = 0.15
top.BorderSizePixel = 0
top.ZIndex = 2
top.Parent = main
corner(top, 14)

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 14)
topFix.Position = UDim2.new(0, 0, 1, -14)
topFix.BackgroundColor3 = COLORS.bar
topFix.BackgroundTransparency = 0.15
topFix.BorderSizePixel = 0
topFix.ZIndex = 2
topFix.Parent = top

local topGrad = Instance.new("UIGradient")
topGrad.Color = GRADIENT
topGrad.Transparency = NumberSequence.new(0.86)
topGrad.Parent = top

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(24, 24)
logo.Position = UDim2.fromOffset(12, 10)
logo.BackgroundColor3 = COLORS.accent2
logo.BorderSizePixel = 0
logo.ZIndex = 3
logo.Parent = top
corner(logo, 7)
local lg = Instance.new("UIGradient")
lg.Color = GRADIENT
lg.Parent = logo
local logoIcon = label(logo, "◈", 14, Color3.new(1, 1, 1), Enum.Font.GothamBold)
logoIcon.Size = UDim2.fromScale(1, 1)
logoIcon.TextXAlignment = Enum.TextXAlignment.Center
logoIcon.ZIndex = 4

local title = label(top, "Fisk Grow", 15, COLORS.text, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(44, 0)
title.Size = UDim2.new(1, -130, 1, 0)
title.ZIndex = 3

local ver = label(top, "v3.2", 11, COLORS.sub, Enum.Font.GothamMedium)
ver.Position = UDim2.new(1, -128, 0, 0)
ver.Size = UDim2.fromOffset(30, 44)
ver.TextXAlignment = Enum.TextXAlignment.Center
ver.ZIndex = 3

local collapseBtn = Instance.new("TextButton")
collapseBtn.Size = UDim2.fromOffset(26, 26)
collapseBtn.Position = UDim2.new(1, -62, 0.5, -13)
collapseBtn.BackgroundColor3 = COLORS.off
collapseBtn.BackgroundTransparency = 0.2
collapseBtn.Text = "—"
collapseBtn.TextSize = 15
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextColor3 = COLORS.text
collapseBtn.ZIndex = 3
collapseBtn.Parent = top
corner(collapseBtn, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -32, 0.5, -13)
closeBtn.BackgroundColor3 = COLORS.danger
closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "×"
closeBtn.TextSize = 17
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = COLORS.text
closeBtn.ZIndex = 3
closeBtn.Parent = top
corner(closeBtn, 8)

for _, b in ipairs({collapseBtn, closeBtn}) do
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.3 }):Play()
    end)
end

-- Перетаскивание
do
    local dragging, dragStart, startPos
    connect(top.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Содержимое
local content = Instance.new("ScrollingFrame")
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Position = UDim2.fromOffset(12, 52)
content.Size = UDim2.new(1, -24, 1, -62)
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = COLORS.accent
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.ZIndex = 2
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local order = 0
local function nextOrder() order += 1 return order end

local function header(text)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, -4, 0, 20)
    row.LayoutOrder = nextOrder()
    row.Parent = content

    local l = label(row, text, 11, COLORS.accent, Enum.Font.GothamBold)
    l.Size = UDim2.fromOffset(200, 20)

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -l.TextBounds.X - 12, 0, 1)
    line.Position = UDim2.new(0, l.TextBounds.X + 8, 0.5, 0)
    line.BackgroundColor3 = COLORS.accent2
    line.BackgroundTransparency = 0.65
    line.BorderSizePixel = 0
    line.Parent = row
    return row
end

-- Компактный тумблер (для списка сущностей)
local function makeSmallToggle(text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 30)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.25
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = content
    corner(row, 8)

    local l = label(row, text, 13)
    l.Position = UDim2.fromOffset(10, 0)
    l.Size = UDim2.new(1, -56, 1, 0)

    local pill = Instance.new("TextButton")
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.Size = UDim2.fromOffset(36, 20)
    pill.Position = UDim2.new(1, -46, 0.5, -10)
    pill.BackgroundColor3 = default and COLORS.accent2 or COLORS.off
    pill.Parent = row
    corner(pill, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = default and UDim2.fromOffset(20, 3) or UDim2.fromOffset(2, 3)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    corner(knob, 7)

    local on = default
    connect(pill.MouseButton1Click, function()
        on = not on
        TweenService:Create(pill, TweenInfo.new(0.15), { BackgroundColor3 = on and COLORS.accent2 or COLORS.off }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Position = on and UDim2.fromOffset(20, 3) or UDim2.fromOffset(2, 3) }):Play()
        callback(on)
    end)
end

local function makeToggle(text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 42)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.1
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = content
    corner(row, 10)
    stroke(row, COLORS.accent2, 0.85, 0.8)

    local l = label(row, text, 14)
    l.Position = UDim2.fromOffset(12, 0)
    l.Size = UDim2.new(1, -70, 1, 0)

    local pill = Instance.new("TextButton")
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.Size = UDim2.fromOffset(44, 24)
    pill.Position = UDim2.new(1, -56, 0.5, -12)
    pill.BackgroundColor3 = default and COLORS.accent2 or COLORS.off
    pill.Parent = row
    corner(pill, 12)
    local pg = Instance.new("UIGradient")
    pg.Color = GRADIENT
    pg.Enabled = default
    pg.Parent = pill
    stroke(pill, Color3.new(1, 1, 1), default and 0.7 or 0.9, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = default and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    corner(knob, 9)

    local on = default
    connect(pill.MouseButton1Click, function()
        on = not on
        TweenService:Create(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quint), { BackgroundColor3 = on and COLORS.accent2 or COLORS.off }):Play()
        pg.Enabled = on
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Position = on and UDim2.fromOffset(24, 3) or UDim2.fromOffset(2, 3) }):Play()
        callback(on)
    end)
end

local function makeSpeedSlider(text, min, max, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 78)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.1
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = content
    corner(row, 10)
    stroke(row, COLORS.accent2, 0.85, 0.8)

    local l = label(row, text, 14)
    l.Position = UDim2.fromOffset(12, 10)
    l.Size = UDim2.new(1, -140, 0, 24)

    local minus = smallButton(row, "−")
    minus.Size = UDim2.fromOffset(26, 26)
    minus.Position = UDim2.new(1, -128, 0, 8)

    local box = smallBox(row, tostring(default))
    box.Size = UDim2.fromOffset(52, 26)
    box.Position = UDim2.new(1, -98, 0, 8)

    local plus = smallButton(row, "+")
    plus.Size = UDim2.fromOffset(26, 26)
    plus.Position = UDim2.new(1, -38, 0, 8)

    local track = Instance.new("TextButton")
    track.Text = ""
    track.AutoButtonColor = false
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 54)
    track.BackgroundColor3 = COLORS.off
    track.BackgroundTransparency = 0.15
    track.Parent = row
    corner(track, 5)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = COLORS.accent2
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, 5)
    local fg = Instance.new("UIGradient")
    fg.Color = GRADIENT
    fg.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = track
    corner(knob, 8)
    stroke(knob, COLORS.accent, 0.2, 1.5)

    local value = default
    local function setValue(v)
        v = math.clamp(math.floor(v + 0.5), min, max)
        value = v
        local a = (v - min) / (max - min)
        TweenService:Create(fill, TweenInfo.new(0.1), { Size = UDim2.new(a, 0, 1, 0) }):Play()
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        box.Text = tostring(v)
        callback(v)
    end
    setValue(default)

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        setValue(min + (max - min) * a)
    end
    connect(track.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(i.Position.X)
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromX(i.Position.X)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    connect(minus.MouseButton1Click, function() setValue(value - 1) end)
    connect(plus.MouseButton1Click, function() setValue(value + 1) end)
    connect(box.FocusLost, function()
        local n = tonumber(box.Text)
        if n then setValue(n) else box.Text = tostring(value) end
    end)
end

-- ========= Сворачивание =========
local collapsed = false
local function setCollapsed(v)
    collapsed = v
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = v and COLLAPSED_SIZE or FULL_SIZE
    }):Play()
    task.delay(0.12, function()
        content.Visible = not v
    end)
    collapseBtn.Text = v and "▢" or "—"
end

connect(collapseBtn.MouseButton1Click, function()
    setCollapsed(not collapsed)
end)

-- ========= Уведомления =========
local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 20)
toastHolder.Size = UDim2.fromOffset(340, 40)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui

local toast = label(toastHolder, "", 15, COLORS.text, Enum.Font.GothamBold)
toast.Size = UDim2.fromScale(1, 1)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.BackgroundColor3 = COLORS.bg
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
corner(toast, 12)
stroke(toast, COLORS.accent, 0.4, 1.2)

local toastIcon = label(toastHolder, "⚠", 16, Color3.fromRGB(255, 200, 100), Enum.Font.GothamBold)
toastIcon.Size = UDim2.fromOffset(30, 40)
toastIcon.Position = UDim2.fromOffset(8, 0)
toastIcon.TextTransparency = 1

local toastId = 0
local function notify(text)
    if not State.notifyOn then return end
    toastId += 1
    local id = toastId
    toast.Text = "   " .. text
    toastHolder.Position = UDim2.new(0.5, 0, 0, 12)
    TweenService:Create(toastHolder, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 20) }):Play()
    toast.BackgroundTransparency = 0.1
    toast.TextTransparency = 0
    toastIcon.TextTransparency = 0
    task.delay(3, function()
        if id == toastId then
            TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(toastIcon, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        end
    end)
end

-- ========= Скорость (без WalkSpeed) =========
connect(RunService.Heartbeat, function()
    if not State.speedOn then return end
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end
    local md = hum.MoveDirection
    if md.Magnitude > 0 then
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(md.X * State.speed, vel.Y, md.Z * State.speed)
    end
end)

-- ========= ESP =========
local tracked = {}
local live = false

local function getPart(model)
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function removeEsp(model)
    local t = tracked[model]
    if not t then return end
    tracked[model] = nil
    for _, o in ipairs(t.objects) do
        pcall(function() o:Destroy() end)
    end
end

-- Этаж помечается ЦИФРОЙ в табличке: [1] Rush [12m], [ST] Creak [30m]
local function addEsp(model, displayName, floorId, notifySpawn)
    if tracked[model] then return end
    tracked[model] = { objects = {}, name = displayName }
    if notifySpawn and live and State.notifyOn then notify(displayName .. " появился!") end

    task.spawn(function()
        local part
        for _ = 1, 50 do
            part = getPart(model)
            if part or not model.Parent then break end
            task.wait(0.1)
        end
        if not part or not tracked[model] then removeEsp(model) return end

        local hl = Instance.new("Highlight")
        hl.Adornee = model
        hl.FillColor = COLORS.esp
        hl.FillTransparency = 0.6
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = State.espOn
        hl.Parent = espFolder

        local bb = Instance.new("BillboardGui")
        bb.Adornee = part
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(160, 36)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.Enabled = State.espOn
        bb.Parent = espFolder

        local tl = Instance.new("TextLabel")
        tl.BackgroundTransparency = 1
        tl.Size = UDim2.fromScale(1, 1)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 14
        tl.TextColor3 = floorId == "?" and COLORS.espUnk or COLORS.espText
        tl.TextStrokeTransparency = 0.3
        tl.Text = displayName
        tl.Parent = bb

        local t = tracked[model]
        if not t then hl:Destroy() bb:Destroy() return end
        t.objects = { hl, bb }
        t.hl, t.bb, t.tl, t.part = hl, bb, tl, part
        t.floor = floorId
    end)

    model.AncestryChanged:Connect(function(_, parent)
        if not parent then removeEsp(model) end
    end)
end

local function check(inst)
    if not inst:IsA("Model") then return end
    local e = ENTITIES[inst.Name]
    if e then
        if State.entityVisible[e[1]] then
            addEsp(inst, e[1], e[2], true)
        end
    elseif live and State.autoOn
        and not isIgnoredName(inst.Name)
        and not Players:GetPlayerFromCharacter(inst)
        and getPart(inst) ~= nil
        and (inst.Parent == workspace
            or (inst.Parent and inst.Parent.Parent == workspace)
            or (inst.Parent and inst.Parent.Parent and inst.Parent.Parent.Parent == workspace)) then
        addEsp(inst, inst.Name, "?", true)
    end
end

task.spawn(function()
    for _, d in ipairs(workspace:GetDescendants()) do
        check(d)
    end
    live = true
end)
connect(workspace.DescendantAdded, check)

-- Дистанция и видимость
task.spawn(function()
    while gui.Parent do
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        for _, t in pairs(tracked) do
            if t.hl then
                t.hl.Enabled = State.espOn
                t.bb.Enabled = State.espOn
                if root and t.part and t.part.Parent then
                    local dist = (t.part.Position - root.Position).Magnitude
                    t.tl.Text = string.format("[%s] %s [%dm]", t.floor, t.name, dist)
                end
            end
        end
        task.wait(0.2)
    end
end)

-- ========= Меню =========
header("ИГРОК")
makeToggle("Изменение скорости", false, function(v)
    State.speedOn = v
end)
makeSpeedSlider("Скорость", MIN_SPEED, MAX_SPEED, State.speed, function(v)
    State.speed = v
end)

header("СУЩНОСТИ")
makeToggle("ESP сущностей", true, function(v) State.espOn = v end)
makeToggle("Авто-обнаружение новых", true, function(v) State.autoOn = v end)
makeToggle("Уведомления о спавне", true, function(v) State.notifyOn = v end)

for _, f in ipairs(FLOORS) do
    header(f.title)
    for _, name in ipairs(floorEntities[f.id]) do
        makeSmallToggle(name, true, function(v)
            State.entityVisible[name] = v
            if not v then
                -- убрать ESP у уже отслеживаемых экземпляров этой сущности
                for m, t in pairs(tracked) do
                    if t.name == name then removeEsp(m) end
                end
            else
                -- вернуть ESP, если сущность уже существует в мире
                for modelName, e in pairs(ENTITIES) do
                    if e[1] == name then
                        for _, d in ipairs(workspace:GetDescendants()) do
                            if d:IsA("Model") and d.Name == modelName then check(d) end
                        end
                    end
                end
            end
        end)
    end
end

header("СВЯЗЬ")
do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 46)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.1
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = content
    corner(row, 10)
    stroke(row, COLORS.accent2, 0.85, 0.8)

    local l = label(row, "ТГК разраба", 14)
    l.Position = UDim2.fromOffset(12, 5)
    l.Size = UDim2.new(1, -90, 0, 20)

    local link = label(row, "t.me/fiskgrov", 12, COLORS.accent3, Enum.Font.GothamBold)
    link.Position = UDim2.fromOffset(12, 24)
    link.Size = UDim2.new(1, -90, 0, 18)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(72, 28)
    btn.Position = UDim2.new(1, -82, 0.5, -14)
    btn.BackgroundColor3 = COLORS.accent2
    btn.Text = "Перейти"
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = COLORS.text
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 8)
    local bgrad = Instance.new("UIGradient")
    bgrad.Color = GRADIENT
    bgrad.Parent = btn
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.accent }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.accent2 }):Play()
    end)

    connect(btn.MouseButton1Click, function()
        local ok = pcall(function() setclipboard("https://t.me/fiskgrov") end)
        if ok then
            notify("Ссылка скопирована: t.me/fiskgrov")
        else
            notify("t.me/fiskgrov")
        end
    end)
end

local hint = label(content, "RightShift — скрыть / показать меню", 11, COLORS.sub)
hint.Size = UDim2.new(1, 0, 0, 16)
hint.TextXAlignment = Enum.TextXAlignment.Center
hint.LayoutOrder = nextOrder()


-- ========= Плавающая кнопка (для мобильных / Delta) =========
local fab = Instance.new("TextButton")
fab.Name = "Fab"
fab.Size = UDim2.fromOffset(44, 44)
fab.Position = UDim2.new(0, 16, 0.5, -22)
fab.BackgroundColor3 = COLORS.bar
fab.BackgroundTransparency = 0.1
fab.Text = "◈"
fab.TextSize = 20
fab.Font = Enum.Font.GothamBold
fab.TextColor3 = COLORS.accent
fab.BorderSizePixel = 0
fab.ZIndex = 5
fab.Parent = gui
corner(fab, 22)
stroke(fab, COLORS.accent2, 0.4, 1.2)
local fabGrad = Instance.new("UIGradient")
fabGrad.Color = GRADIENT
fabGrad.Transparency = NumberSequence.new(0.8)
fabGrad.Parent = fab

do
    local fabDragging, fabStart, fabPos, moved
    fab.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            fabDragging, moved = true, false
            fabStart, fabPos = i.Position, fab.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if fabDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - fabStart
            if d.Magnitude > 8 then moved = true end
            if moved then
                fab.Position = UDim2.new(fabPos.X.Scale, fabPos.X.Offset + d.X, fabPos.Y.Scale, fabPos.Y.Offset + d.Y)
            end
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if fabDragging and not moved then
                main.Visible = not main.Visible
            end
            fabDragging = false
        end
    end)
end

-- ========= Управление окном =========
connect(UIS.InputBegan, function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

connect(closeBtn.MouseButton1Click, function()
    State.speedOn = false
    for m in pairs(tracked) do removeEsp(m) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)
