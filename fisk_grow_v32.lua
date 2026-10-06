--[[
    Fisk Grow v3.3
    - ПРЯМОУГОЛЬНАЯ панель с разделами-аккордеонами (все функции внутри пунктов)
    - ФИКС кликабельности: все кнопки работают через Activated + Active (тап/мышь)
    - Уведомления: чистые карточки, полностью удаляются, без следов
    - Новые кнопки: сворачивание ▾ / закрытие ⏻, плавающая кнопка — градиентный круг
    - Скорость без WalkSpeed; ESP сущностей на всех этажах
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
    entityVisible = {},
}
local MIN_SPEED, MAX_SPEED = 16, 80
local FULL_SIZE = UDim2.fromOffset(340, 480)
local COLLAPSED_SIZE = UDim2.fromOffset(340, 42)

-- ========= Этажи и сущности =========
local FLOORS = {
    { id = "1",  title = "ЭТАЖ 1 · ОТЕЛЬ" },
    { id = "2",  title = "ЭТАЖ 2 · ШАХТЫ" },
    { id = "BD", title = "BACKDOOR" },
    { id = "AR", title = "АРХИВЫ" },
    { id = "ST", title = "ЛЕСТНИЦЫ" },
}

-- [имя модели] = { отображаемое имя, этаж }
local ENTITIES = {
    RushMoving = {"Rush", "1"}, AmbushMoving = {"Ambush", "1"},
    A60 = {"A-60", "1"}, A120 = {"A-120", "1"}, A90 = {"A-90", "1"}, A200 = {"A-200", "1"},
    Eyes = {"Eyes", "1"}, Halt = {"Halt", "1"}, Screech = {"Screech", "1"},
    JeffTheKiller = {"Jeff", "1"}, Jack = {"Jack", "1"}, Snare = {"Snare", "1"},
    Dupe = {"Dupe", "1"}, Timothy = {"Timothy", "1"},
    Seek = {"Seek", "1"}, SeekMoving = {"Seek", "1"}, SeekMovingNewClone = {"Seek", "1"},
    FigureRig = {"Figure", "1"}, FigureRagdoll = {"Figure", "1"},
    Glitch = {"Glitch", "1"}, Void = {"Void", "1"}, Shadow = {"Shadow", "1"}, Surge = {"Surge", "1"},
    Dread = {"Dread", "1"}, Blitz = {"Blitz", "1"},
    Giggle = {"Giggle", "2"}, GiggleCeiling = {"Giggle", "2"},
    Grumble = {"Grumble", "2"}, GrumbleRig = {"Grumble", "2"},
    Gloombat = {"Gloombat", "2"}, GloombatSwarm = {"Gloombat", "2"},
    BackdoorRush = {"Haste", "BD"}, Haste = {"Haste", "BD"},
    BackdoorLookman = {"Lookman", "BD"}, Lookman = {"Lookman", "BD"},
    Vacuum = {"Vacuum", "BD"},
    Honcho = {"Honcho", "AR"},
    Drone = {"Drone", "AR"}, Drones = {"Drone", "AR"},
    Bash = {"Bash", "AR"}, Ransom = {"Ransom", "AR"}, Scribbles = {"Scribbles", "AR"},
    Teller = {"Teller", "AR"},
    ForgetMeNot = {"Forget-Me-Not", "AR"}, ForgetMeNots = {"Forget-Me-Not", "AR"},
    Alma = {"Alma", "AR"}, Portrait = {"Portrait", "AR"}, Fih = {"Fih", "AR"},
    Creak = {"Creak", "ST"}, Noise = {"Noise", "ST"}, Hijack = {"Hijack", "ST"},
    Stem = {"Stem", "ST"}, Stems = {"Stem", "ST"},
    CeramicStem = {"Stem", "ST"}, ClayStem = {"Stem", "ST"},
    Cobbler = {"Cobbler", "ST"}, Meld = {"Meld", "ST"}, Crusher = {"Crusher", "ST"},
}

local floorEntities = {}
for _, f in ipairs(FLOORS) do floorEntities[f.id] = {} end
local seen = {}
for _, v in pairs(ENTITIES) do
    local name, fid = v[1], v[2]
    if not seen[name] then
        seen[name] = true
        table.insert(floorEntities[fid], name)
    end
end
for _, f in ipairs(FLOORS) do table.sort(floorEntities[f.id]) end
for name in pairs(seen) do State.entityVisible[name] = true end

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
    local old = parentGui:FindFirstChild("FiskGrow")
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
    bg       = Color3.fromRGB(14, 14, 20),
    bar      = Color3.fromRGB(22, 22, 32),
    item     = Color3.fromRGB(28, 28, 40),
    itemHover= Color3.fromRGB(36, 36, 52),
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
    c.CornerRadius = UDim.new(0, r or 4)
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

local function makeBtn(parent)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.Active = true
    b.Text = ""
    b.BackgroundColor3 = COLORS.item
    b.BorderSizePixel = 0
    b.Parent = parent
    return b
end

local function hoverFx(b, from, to)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = to }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = from }):Play()
    end)
end

-- ========= Главное окно (прямоугольное) =========
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = FULL_SIZE
main.Position = UDim2.new(0.5, -170, 0.5, -240)
main.BackgroundColor3 = COLORS.bg
main.BackgroundTransparency = 0.06
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
corner(main, 0)
stroke(main, COLORS.accent2, 0.5, 1.2)

do
    local sh = Instance.new("Frame")
    sh.Name = "Shadow"
    sh.Size = UDim2.new(1, 16, 1, 16)
    sh.Position = UDim2.fromOffset(-8, -5)
    sh.BackgroundColor3 = Color3.new(0, 0, 0)
    sh.BackgroundTransparency = 0.55
    sh.BorderSizePixel = 0
    sh.ZIndex = 0
    sh.Parent = main
    corner(sh, 0)
end
main.ZIndex = 1

-- Заголовок
local top = Instance.new("Frame")
top.Name = "TopBar"
top.Size = UDim2.new(1, 0, 0, 42)
top.BackgroundColor3 = COLORS.bar
top.BorderSizePixel = 0
top.ZIndex = 2
top.Parent = main
corner(top, 0)

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, 0, 0, 2)
topLine.Position = UDim2.new(0, 0, 1, -2)
topLine.BorderSizePixel = 0
topLine.ZIndex = 2
topLine.Parent = top
local tlGrad = Instance.new("UIGradient")
tlGrad.Color = GRADIENT
tlGrad.Parent = topLine

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(22, 22)
logo.Position = UDim2.fromOffset(10, 10)
logo.BorderSizePixel = 0
logo.ZIndex = 3
logo.Parent = top
corner(logo, 0)
local lg = Instance.new("UIGradient")
lg.Color = GRADIENT
lg.Parent = logo
local logoIcon = label(logo, "◈", 13, Color3.new(1, 1, 1), Enum.Font.GothamBold)
logoIcon.Size = UDim2.fromScale(1, 1)
logoIcon.TextXAlignment = Enum.TextXAlignment.Center
logoIcon.ZIndex = 4

local title = label(top, "Fisk Grow", 14, COLORS.text, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(40, 0)
title.Size = UDim2.new(1, -150, 1, 0)
title.ZIndex = 3

local ver = label(top, "v3.3", 11, COLORS.sub)
ver.Position = UDim2.new(1, -120, 0, 0)
ver.Size = UDim2.fromOffset(30, 42)
ver.TextXAlignment = Enum.TextXAlignment.Center
ver.ZIndex = 3

-- Кнопка сворачивания: акцентный квадрат со стрелкой
local collapseBtn = makeBtn(top)
collapseBtn.Size = UDim2.fromOffset(26, 26)
collapseBtn.Position = UDim2.new(1, -64, 0.5, -13)
collapseBtn.BackgroundColor3 = COLORS.off
collapseBtn.Text = "▾"
collapseBtn.TextSize = 14
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextColor3 = COLORS.accent
collapseBtn.ZIndex = 3
corner(collapseBtn, 0)
stroke(collapseBtn, COLORS.accent2, 0.5, 1)
hoverFx(collapseBtn, COLORS.off, COLORS.itemHover)

-- Кнопка закрытия: красная с иконкой питания
local closeBtn = makeBtn(top)
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -32, 0.5, -13)
closeBtn.BackgroundColor3 = COLORS.danger
closeBtn.Text = "⏻"
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.ZIndex = 3
corner(closeBtn, 0)
hoverFx(closeBtn, COLORS.danger, Color3.fromRGB(255, 100, 120))

-- Перетаскивание за заголовок
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
content.Name = "Content"
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Position = UDim2.fromOffset(10, 50)
content.Size = UDim2.new(1, -20, 1, -58)
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

-- ========= Раздел-аккордеон =========
local function makeSection(titleText, defaultOpen)
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 0)
    wrap.AutomaticSize = Enum.AutomaticSize.Y
    wrap.LayoutOrder = nextOrder()
    wrap.Parent = content

    local wl = Instance.new("UIListLayout")
    wl.Padding = UDim.new(0, 4)
    wl.SortOrder = Enum.SortOrder.LayoutOrder
    wl.Parent = wrap

    local headerBtn = makeBtn(wrap)
    headerBtn.Size = UDim2.new(1, 0, 0, 32)
    headerBtn.BackgroundColor3 = COLORS.item
    headerBtn.LayoutOrder = nextOrder()
    headerBtn.ZIndex = 3
    hoverFx(headerBtn, COLORS.item, COLORS.itemHover)

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.fromOffset(3, 32)
    accentBar.BackgroundColor3 = COLORS.accent2
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 4
    accentBar.Parent = headerBtn
    local abg = Instance.new("UIGradient")
    abg.Color = GRADIENT
    abg.Parent = accentBar

    local ttl = label(headerBtn, titleText, 12, COLORS.text, Enum.Font.GothamBold)
    ttl.Position = UDim2.fromOffset(14, 0)
    ttl.Size = UDim2.new(1, -40, 1, 0)
    ttl.ZIndex = 4

    local chevron = label(headerBtn, defaultOpen and "▾" or "▸", 13, COLORS.accent, Enum.Font.GothamBold)
    chevron.Size = UDim2.fromOffset(24, 32)
    chevron.Position = UDim2.new(1, -28, 0, 0)
    chevron.TextXAlignment = Enum.TextXAlignment.Center
    chevron.ZIndex = 4

    local container = Instance.new("Frame")
    container.Name = "Items"
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 0, 0)
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.Visible = defaultOpen
    container.LayoutOrder = nextOrder()
    container.ZIndex = 2
    container.Parent = wrap

    local cl = Instance.new("UIListLayout")
    cl.Padding = UDim.new(0, 4)
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Parent = container

    connect(headerBtn.Activated, function()
        container.Visible = not container.Visible
        chevron.Text = container.Visible and "▾" or "▸"
    end)

    return container
end

-- ========= Тумблер (большой) =========
local function makeToggle(text, default, callback, parent)
    parent = parent or content
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = parent
    corner(row, 0)
    stroke(row, COLORS.accent2, 0.85, 0.8)

    local l = label(row, text, 13)
    l.Position = UDim2.fromOffset(12, 0)
    l.Size = UDim2.new(1, -70, 1, 0)
    l.ZIndex = 4

    local pill = makeBtn(row)
    pill.Size = UDim2.fromOffset(42, 22)
    pill.Position = UDim2.new(1, -54, 0.5, -11)
    pill.BackgroundColor3 = default and COLORS.accent2 or COLORS.off
    pill.ZIndex = 4
    corner(pill, 0)
    local pg = Instance.new("UIGradient")
    pg.Color = GRADIENT
    pg.Enabled = default
    pg.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = default and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = pill
    corner(knob, 0)

    local on = default
    connect(pill.Activated, function()
        on = not on
        TweenService:Create(pill, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundColor3 = on and COLORS.accent2 or COLORS.off }):Play()
        pg.Enabled = on
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { Position = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) }):Play()
        callback(on)
    end)
end

-- ========= Тумблер (компактный, для списка сущностей) =========
local function makeSmallToggle(text, default, callback, parent)
    parent = parent or content
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = parent
    corner(row, 0)

    local l = label(row, text, 12)
    l.Position = UDim2.fromOffset(10, 0)
    l.Size = UDim2.new(1, -56, 1, 0)
    l.ZIndex = 4

    local pill = makeBtn(row)
    pill.Size = UDim2.fromOffset(34, 18)
    pill.Position = UDim2.new(1, -44, 0.5, -9)
    pill.BackgroundColor3 = default and COLORS.accent2 or COLORS.off
    pill.ZIndex = 4
    corner(pill, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.Position = default and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = pill
    corner(knob, 0)

    local on = default
    connect(pill.Activated, function()
        on = not on
        TweenService:Create(pill, TweenInfo.new(0.13), { BackgroundColor3 = on and COLORS.accent2 or COLORS.off }):Play()
        TweenService:Create(knob, TweenInfo.new(0.13, Enum.EasingStyle.Quint), { Position = on and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3) }):Play()
        callback(on)
    end)
end

-- ========= Слайдер скорости =========
local function makeSpeedSlider(text, min, max, default, callback, parent)
    parent = parent or content
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 74)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = parent
    corner(row, 0)
    stroke(row, COLORS.accent2, 0.85, 0.8)

    local l = label(row, text, 13)
    l.Position = UDim2.fromOffset(12, 8)
    l.Size = UDim2.new(1, -140, 0, 22)
    l.ZIndex = 4

    local minus = makeBtn(row)
    minus.Size = UDim2.fromOffset(24, 24)
    minus.Position = UDim2.new(1, -124, 0, 8)
    minus.Text = "−"
    minus.TextSize = 16
    minus.Font = Enum.Font.GothamBold
    minus.TextColor3 = COLORS.text
    minus.BackgroundColor3 = COLORS.off
    minus.ZIndex = 4
    corner(minus, 0)
    hoverFx(minus, COLORS.off, COLORS.itemHover)

    local box = Instance.new("TextBox")
    box.Text = tostring(default)
    box.TextSize = 13
    box.Font = Enum.Font.GothamBold
    box.TextColor3 = COLORS.accent
    box.PlaceholderColor3 = COLORS.sub
    box.BackgroundColor3 = COLORS.bg
    box.BackgroundTransparency = 0.2
    box.ClearTextOnFocus = false
    box.Size = UDim2.fromOffset(48, 24)
    box.Position = UDim2.new(1, -96, 0, 8)
    box.ZIndex = 4
    box.Parent = row
    corner(box, 0)
    stroke(box, COLORS.accent2, 0.7, 1)

    local plus = makeBtn(row)
    plus.Size = UDim2.fromOffset(24, 24)
    plus.Position = UDim2.new(1, -40, 0, 8)
    plus.Text = "+"
    plus.TextSize = 16
    plus.Font = Enum.Font.GothamBold
    plus.TextColor3 = COLORS.text
    plus.BackgroundColor3 = COLORS.off
    plus.ZIndex = 4
    corner(plus, 0)
    hoverFx(plus, COLORS.off, COLORS.itemHover)

    local track = makeBtn(row)
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 52)
    track.BackgroundColor3 = COLORS.off
    track.BackgroundTransparency = 0.1
    track.ZIndex = 4
    corner(track, 0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = COLORS.accent2
    fill.BorderSizePixel = 0
    fill.ZIndex = 4
    fill.Parent = track
    corner(fill, 0)
    local fg = Instance.new("UIGradient")
    fg.Color = GRADIENT
    fg.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = track
    corner(knob, 0)
    stroke(knob, COLORS.accent, 0.2, 1.5)

    local value = default
    local function setValue(v)
        v = math.clamp(math.floor(v + 0.5), min, max)
        value = v
        local a = (v - min) / (max - min)
        TweenService:Create(fill, TweenInfo.new(0.08), { Size = UDim2.new(a, 0, 1, 0) }):Play()
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
    connect(minus.Activated, function() setValue(value - 1) end)
    connect(plus.Activated, function() setValue(value + 1) end)
    connect(box.FocusLost, function()
        local n = tonumber(box.Text)
        if n then setValue(n) else box.Text = tostring(value) end
    end)
end

-- ========= Сворачивание =========
local collapsed = false
local function setCollapsed(v)
    collapsed = v
    TweenService:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = v and COLLAPSED_SIZE or FULL_SIZE
    }):Play()
    task.delay(0.1, function()
        content.Visible = not v
    end)
    collapseBtn.Text = v and "▸" or "▾"
end

connect(collapseBtn.Activated, function()
    setCollapsed(not collapsed)
end)

-- ========= Уведомления (чистые карточки, без следов) =========
local notifHolder = Instance.new("Frame")
notifHolder.Name = "Notifications"
notifHolder.AnchorPoint = Vector2.new(0.5, 0)
notifHolder.Position = UDim2.new(0.5, 0, 0, 14)
notifHolder.Size = UDim2.fromOffset(320, 0)
notifHolder.AutomaticSize = Enum.AutomaticSize.Y
notifHolder.BackgroundTransparency = 1
notifHolder.Parent = gui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 6)
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifLayout.Parent = notifHolder

local notifOrder = 0
local function notify(text)
    if not State.notifyOn then return end
    notifOrder += 1

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(300, 34)
    card.BackgroundColor3 = COLORS.bar
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.LayoutOrder = notifOrder
    card.Parent = notifHolder
    corner(card, 0)
    local cs = stroke(card, COLORS.accent2, 0.35, 1)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromOffset(3, 34)
    bar.BackgroundColor3 = COLORS.accent
    bar.BorderSizePixel = 0
    bar.Parent = card
    local bg2 = Instance.new("UIGradient")
    bg2.Color = GRADIENT
    bg2.Parent = bar

    local txt = label(card, text, 13, COLORS.text, Enum.Font.GothamBold)
    txt.Position = UDim2.fromOffset(14, 0)
    txt.Size = UDim2.new(1, -20, 1, 0)
    txt.TextTransparency = 1

    TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.04 }):Play()
    TweenService:Create(txt, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()

    task.delay(2.6, function()
        if not card.Parent then return end
        local t1 = TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
        local t2 = TweenService:Create(txt, TweenInfo.new(0.3), { TextTransparency = 1 })
        t1:Play()
        t2:Play()
        t1.Completed:Connect(function()
            card:Destroy()
        end)
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

-- ========= Меню: разделы со всеми функциями =========
local playerSec = makeSection("ИГРОК", true)
makeToggle("Изменение скорости", false, function(v)
    State.speedOn = v
end, playerSec)
makeSpeedSlider("Скорость", MIN_SPEED, MAX_SPEED, State.speed, function(v)
    State.speed = v
end, playerSec)

local espSec = makeSection("СУЩНОСТИ", true)
makeToggle("ESP сущностей", true, function(v) State.espOn = v end, espSec)
makeToggle("Авто-обнаружение новых", true, function(v) State.autoOn = v end, espSec)
makeToggle("Уведомления о спавне", true, function(v) State.notifyOn = v end, espSec)

for _, f in ipairs(FLOORS) do
    if #floorEntities[f.id] > 0 then
        local sec = makeSection(f.title, false)
        for _, name in ipairs(floorEntities[f.id]) do
            makeSmallToggle(name, true, function(v)
                State.entityVisible[name] = v
                task.spawn(function()
                    if not v then
                        for m, t in pairs(tracked) do
                            if t.name == name then removeEsp(m) end
                        end
                    else
                        for modelName, e in pairs(ENTITIES) do
                            if e[1] == name then
                                for _, d in ipairs(workspace:GetDescendants()) do
                                    if d:IsA("Model") and d.Name == modelName then check(d) end
                                end
                            end
                        end
                    end
                end)
            end, sec)
        end
    end
end

local linkSec = makeSection("СВЯЗЬ", false)
do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = linkSec
    corner(row, 0)
    stroke(row, COLORS.accent2, 0.85, 0.8)

    local l = label(row, "ТГК разраба", 13)
    l.Position = UDim2.fromOffset(12, 4)
    l.Size = UDim2.new(1, -90, 0, 18)
    l.ZIndex = 4

    local link = label(row, "t.me/fiskgrov", 11, COLORS.accent3, Enum.Font.GothamBold)
    link.Position = UDim2.fromOffset(12, 22)
    link.Size = UDim2.new(1, -90, 0, 16)
    link.ZIndex = 4

    local btn = makeBtn(row)
    btn.Size = UDim2.fromOffset(70, 26)
    btn.Position = UDim2.new(1, -80, 0.5, -13)
    btn.BackgroundColor3 = COLORS.accent2
    btn.Text = "Перейти"
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = COLORS.text
    btn.ZIndex = 4
    corner(btn, 0)
    local bgrad = Instance.new("UIGradient")
    bgrad.Color = GRADIENT
    bgrad.Parent = btn
    hoverFx(btn, COLORS.accent2, COLORS.accent)

    connect(btn.Activated, function()
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
hint.ZIndex = 2

-- ========= Плавающая кнопка (градиентный круг) =========
local fab = Instance.new("TextButton")
fab.Name = "Fab"
fab.Size = UDim2.fromOffset(48, 48)
fab.Position = UDim2.new(0, 16, 0.5, -24)
fab.BackgroundColor3 = COLORS.accent2
fab.Text = "◈"
fab.TextSize = 20
fab.Font = Enum.Font.GothamBold
fab.TextColor3 = Color3.new(1, 1, 1)
fab.AutoButtonColor = false
fab.Active = true
fab.BorderSizePixel = 0
fab.ZIndex = 5
fab.Parent = gui
corner(fab, 24)
stroke(fab, COLORS.accent, 0.3, 1.5)
local fabGrad = Instance.new("UIGradient")
fabGrad.Color = GRADIENT
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

connect(closeBtn.Activated, function()
    State.speedOn = false
    for m in pairs(tracked) do removeEsp(m) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)
