--[[
    Fisk Grow v3.6
    - ГОРИЗОНТАЛЬНОЕ прямоугольное меню: слева пункты (вкладки), справа содержимое
    - ESP только на сущностях; комнаты и объекты НЕ подсвечиваются
    - Подсвечивается только дверной проём, в который нужно идти (следующая дверь)
    - Seek: глаза на стенах больше не подсвечиваются
    - Screech: подсвечивается одной целой сущностью (без отдельных деталей)
    - Floor 2: подсвечиваются яйца Gloombat там, где они лежат
    - Все кнопки работают через Activated (тап/мышь)
    - v3.6: оформление Material You (чёрно-белое), фото-лого рядом с названием
    - v3.6: вкладка ГОЛОВОЛОМКИ (предметы, библиотека, генераторы, рычаги)
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
    doorOn = true,
    entityVisible = {},
}
local MIN_SPEED, MAX_SPEED = 16, 80
local FULL_SIZE = UDim2.fromOffset(580, 340)
local COLLAPSED_SIZE = UDim2.fromOffset(580, 52)

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
local EGG_NAME = "Яйцо Gloombat"
table.insert(floorEntities["2"], EGG_NAME)
for _, f in ipairs(FLOORS) do table.sort(floorEntities[f.id]) end
for name in pairs(seen) do State.entityVisible[name] = true end
State.entityVisible[EGG_NAME] = true
State.entityVisible["Gloombat"] = false -- рой не подсвечиваем, только яйца

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

-- ========= Логотип (фото встроено в скрипт) =========
-- Если хочешь свой rbxassetid — вставь сюда, например "rbxassetid://123456789"
local LOGO_ASSET_ID = ""
local LOGO_B64 = [==[
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
]==]

local function b64decode(s)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for i = 1, #alphabet do map[alphabet:byte(i)] = i - 1 end
    local out, buf, bits = {}, 0, 0
    for i = 1, #s do
        local v = map[s:byte(i)]
        if v then
            buf = buf * 64 + v
            bits += 6
            if bits >= 8 then
                bits -= 8
                local p = 2 ^ bits
                local byte = math.floor(buf / p)
                out[#out + 1] = string.char(byte)
                buf = buf % p
            end
        end
    end
    return table.concat(out)
end

local function getLogoImage()
    if LOGO_ASSET_ID ~= "" then return LOGO_ASSET_ID end
    local ok, res = pcall(function()
        local gca = getcustomasset or getsynasset
        if not (gca and writefile) then return nil end
        writefile("fiskgrow_logo.jpg", b64decode(LOGO_B64))
        return gca("fiskgrow_logo.jpg")
    end)
    if ok and type(res) == "string" and res ~= "" then return res end
    return nil
end

local logoImage = getLogoImage()

-- ========= Палитра (Material You · чёрно-белая) =========
local COLORS = {
    bg        = Color3.fromRGB(17, 17, 18),    -- surface
    bar       = Color3.fromRGB(26, 26, 28),    -- surface container low
    item      = Color3.fromRGB(36, 36, 38),    -- surface container
    itemHover = Color3.fromRGB(48, 48, 51),    -- surface container high
    highest   = Color3.fromRGB(60, 60, 64),    -- surface container highest
    selected  = Color3.fromRGB(74, 74, 79),    -- secondary container
    accent    = Color3.fromRGB(255, 255, 255), -- primary
    accent2   = Color3.fromRGB(226, 226, 230),
    accent3   = Color3.fromRGB(190, 190, 196),
    onAccent  = Color3.fromRGB(20, 20, 22),    -- on primary
    text      = Color3.fromRGB(236, 236, 238),
    sub       = Color3.fromRGB(165, 165, 171),
    off       = Color3.fromRGB(60, 60, 64),
    outline   = Color3.fromRGB(122, 122, 128),
    danger    = Color3.fromRGB(244, 63, 94),
    -- цвета подсветки в игре (оставлены для читаемости ESP)
    esp      = Color3.fromRGB(255, 80, 105),
    espText  = Color3.fromRGB(255, 140, 155),
    espUnk   = Color3.fromRGB(200, 205, 215),
    door     = Color3.fromRGB(74, 222, 128),
    egg      = Color3.fromRGB(250, 204, 21),
    eggText  = Color3.fromRGB(254, 240, 138),
    doorText = Color3.fromRGB(190, 255, 215),
}

-- ========= UI-хелперы =========
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = parent
    return c
end

local function stroke(parent, color, tr, th)
    local s = Instance.new("UIStroke")
    s.Color = color or COLORS.outline
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

-- ========= Главное окно =========
local TOP_H = 52

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = FULL_SIZE
main.Position = UDim2.new(0.5, -290, 0.5, -170)
main.BackgroundColor3 = COLORS.bg
main.BackgroundTransparency = 0.02
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Active = true
main.ZIndex = 1
main.Parent = gui
corner(main, 28)
stroke(main, COLORS.outline, 0.65, 1)

-- Заголовок (top app bar)
local top = Instance.new("Frame")
top.Name = "TopBar"
top.Size = UDim2.new(1, 0, 0, TOP_H)
top.BackgroundColor3 = COLORS.bg
top.BackgroundTransparency = 1
top.BorderSizePixel = 0
top.Active = true
top.ZIndex = 2
top.Parent = main

-- Лого: твоё фото в круге, рядом с названием
local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.Size = UDim2.fromOffset(38, 38)
logo.Position = UDim2.fromOffset(14, 7)
logo.BackgroundColor3 = COLORS.item
logo.BorderSizePixel = 0
logo.Image = logoImage or ""
logo.ScaleType = Enum.ScaleType.Crop
logo.ZIndex = 3
logo.Parent = top
corner(logo, 19)
stroke(logo, COLORS.accent, 0.55, 1.5)
if not logoImage then
    local logoIcon = label(logo, "◈", 18, COLORS.accent, Enum.Font.GothamBold)
    logoIcon.Size = UDim2.fromScale(1, 1)
    logoIcon.TextXAlignment = Enum.TextXAlignment.Center
    logoIcon.ZIndex = 4
end

local title = label(top, "Fisk Grow", 17, COLORS.text, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(62, 0)
title.Size = UDim2.fromOffset(88, TOP_H)
title.ZIndex = 3

local verChip = Instance.new("Frame")
verChip.Size = UDim2.fromOffset(40, 20)
verChip.Position = UDim2.new(0, 154, 0.5, -10)
verChip.BackgroundColor3 = COLORS.item
verChip.BorderSizePixel = 0
verChip.ZIndex = 3
verChip.Parent = top
corner(verChip, 10)
local ver = label(verChip, "v3.6", 11, COLORS.sub, Enum.Font.GothamMedium)
ver.Size = UDim2.fromScale(1, 1)
ver.TextXAlignment = Enum.TextXAlignment.Center
ver.ZIndex = 4

-- Кнопка сворачивания (tonal icon button)
local collapseBtn = makeBtn(top)
collapseBtn.Size = UDim2.fromOffset(34, 34)
collapseBtn.Position = UDim2.new(1, -86, 0.5, -17)
collapseBtn.BackgroundColor3 = COLORS.item
collapseBtn.Text = "▾"
collapseBtn.TextSize = 15
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextColor3 = COLORS.text
collapseBtn.ZIndex = 3
corner(collapseBtn, 17)
hoverFx(collapseBtn, COLORS.item, COLORS.highest)

-- Кнопка закрытия (белая filled)
local closeBtn = makeBtn(top)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.Position = UDim2.new(1, -46, 0.5, -17)
closeBtn.BackgroundColor3 = COLORS.accent
closeBtn.Text = "✕"
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = COLORS.onAccent
closeBtn.ZIndex = 3
corner(closeBtn, 17)
hoverFx(closeBtn, COLORS.accent, COLORS.accent3)

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

-- Тело окна: слева навигация, справа карточка с содержимым
local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(0, TOP_H)
body.Size = UDim2.new(1, 0, 1, -TOP_H)
body.Active = true
body.ZIndex = 2
body.Parent = main

local SIDE_W = 156

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.BackgroundTransparency = 1
sidebar.BorderSizePixel = 0
sidebar.Size = UDim2.new(0, SIDE_W, 1, 0)
sidebar.Active = true
sidebar.ZIndex = 2
sidebar.Parent = body

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 4)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Parent = sidebar
local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 4)
sidePad.PaddingLeft = UDim.new(0, 10)
sidePad.PaddingRight = UDim.new(0, 6)
sidePad.Parent = sidebar

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = COLORS.bar
panel.BorderSizePixel = 0
panel.Position = UDim2.fromOffset(SIDE_W, 0)
panel.Size = UDim2.new(1, -(SIDE_W + 12), 1, -12)
panel.ClipsDescendants = true
panel.Active = true
panel.ZIndex = 2
panel.Parent = body
corner(panel, 22)

local pages, tabs = {}, {}

local function selectTab(id)
    for k, p in pairs(pages) do p.Visible = (k == id) end
    for k, t in pairs(tabs) do
        local on = (k == id)
        TweenService:Create(t.btn, TweenInfo.new(0.15), { BackgroundTransparency = on and 0 or 1 }):Play()
        t.ic.TextColor3 = on and COLORS.accent or COLORS.sub
        t.lbl.TextColor3 = on and COLORS.accent or COLORS.sub
    end
end

local tabOrder = 0
local function makeTab(id, text, icon)
    tabOrder += 1
    local btn = makeBtn(sidebar)
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = COLORS.selected
    btn.BackgroundTransparency = 1
    btn.LayoutOrder = tabOrder
    btn.ZIndex = 3
    corner(btn, 21)

    local ic = label(btn, icon, 15, COLORS.sub, Enum.Font.GothamBold)
    ic.Position = UDim2.fromOffset(14, 0)
    ic.Size = UDim2.fromOffset(20, 42)
    ic.TextXAlignment = Enum.TextXAlignment.Center
    ic.ZIndex = 4

    local lbl = label(btn, text, 12, COLORS.sub, Enum.Font.GothamBold)
    lbl.Position = UDim2.fromOffset(42, 0)
    lbl.Size = UDim2.new(1, -46, 1, 0)
    lbl.ZIndex = 4

    tabs[id] = { btn = btn, ic = ic, lbl = lbl }
    connect(btn.Activated, function() selectTab(id) end)
end

local function makePage(id)
    local p = Instance.new("ScrollingFrame")
    p.Name = "Page_" .. id
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.Position = UDim2.fromOffset(10, 10)
    p.Size = UDim2.new(1, -20, 1, -20)
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = COLORS.outline
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.CanvasSize = UDim2.new()
    p.Visible = false
    p.ZIndex = 2
    p.Parent = panel

    local pl = Instance.new("UIListLayout")
    pl.Padding = UDim.new(0, 8)
    pl.SortOrder = Enum.SortOrder.LayoutOrder
    pl.Parent = p
    local pp = Instance.new("UIPadding")
    pp.PaddingRight = UDim.new(0, 6)
    pp.Parent = p

    pages[id] = p
    return p
end

makeTab("player", "ИГРОК", "◆")
makeTab("esp", "ESP", "◉")
makeTab("ent", "СУЩНОСТИ", "☰")
makeTab("pz", "ГОЛОВОЛОМКИ", "✦")
makeTab("link", "СВЯЗЬ", "✉")

makePage("player")
makePage("esp")
makePage("ent")
makePage("pz")
makePage("link")

local content = pages.player

local order = 0
local function nextOrder() order += 1 return order end

-- ========= Раздел-аккордеон =========
local function makeSection(titleText, defaultOpen, parent)
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 0)
    wrap.AutomaticSize = Enum.AutomaticSize.Y
    wrap.LayoutOrder = nextOrder()
    wrap.Parent = parent or content

    local wl = Instance.new("UIListLayout")
    wl.Padding = UDim.new(0, 4)
    wl.SortOrder = Enum.SortOrder.LayoutOrder
    wl.Parent = wrap

    local headerBtn = makeBtn(wrap)
    headerBtn.Size = UDim2.new(1, 0, 0, 38)
    headerBtn.BackgroundColor3 = COLORS.item
    headerBtn.LayoutOrder = nextOrder()
    headerBtn.ZIndex = 3
    corner(headerBtn, 14)
    hoverFx(headerBtn, COLORS.item, COLORS.itemHover)

    local ttl = label(headerBtn, titleText, 12, COLORS.text, Enum.Font.GothamBold)
    ttl.Position = UDim2.fromOffset(16, 0)
    ttl.Size = UDim2.new(1, -48, 1, 0)
    ttl.ZIndex = 4

    local chevron = label(headerBtn, defaultOpen and "▾" or "▸", 14, COLORS.accent, Enum.Font.GothamBold)
    chevron.Size = UDim2.fromOffset(24, 38)
    chevron.Position = UDim2.new(1, -34, 0, 0)
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

-- ========= Переключатель Material 3 =========
local function makeSwitch(row, big, default, callback)
    local W, H = big and 48 or 40, big and 28 or 22
    local onSz, offSz = big and 20 or 14, big and 12 or 10
    local pad = big and 4 or 4

    local track = makeBtn(row)
    track.Size = UDim2.fromOffset(W, H)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -14, 0.5, 0)
    track.ZIndex = 4
    corner(track, H)
    local st = stroke(track, COLORS.outline, 0, 2)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = track
    corner(knob, 30)

    local function apply(on, instant)
        local info = TweenInfo.new(instant and 0 or 0.18, Enum.EasingStyle.Quint)
        local sz = on and onSz or offSz
        local x = on and (W - pad - onSz) or (pad + (onSz - offSz) / 2 + 1)
        TweenService:Create(track, info, { BackgroundColor3 = on and COLORS.accent or COLORS.bg }):Play()
        TweenService:Create(st, info, { Transparency = on and 1 or 0 }):Play()
        TweenService:Create(knob, info, {
            Size = UDim2.fromOffset(sz, sz),
            Position = UDim2.new(0, x, 0.5, 0),
            BackgroundColor3 = on and COLORS.onAccent or COLORS.outline,
        }):Play()
    end

    local on = default
    apply(on, true)
    connect(track.Activated, function()
        on = not on
        apply(on, false)
        callback(on)
    end)
end

-- ========= Тумблер (большой) =========
local function makeToggle(text, default, callback, parent)
    parent = parent or content
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = COLORS.item
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = parent
    corner(row, 16)

    local l = label(row, text, 14)
    l.Position = UDim2.fromOffset(16, 0)
    l.Size = UDim2.new(1, -86, 1, 0)
    l.ZIndex = 4

    makeSwitch(row, true, default, callback)
end

-- ========= Тумблер (компактный, для списка сущностей) =========
local function makeSmallToggle(text, default, callback, parent)
    parent = parent or content
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = COLORS.item
    row.BackgroundTransparency = 0.45
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = parent
    corner(row, 12)

    local l = label(row, text, 12)
    l.Position = UDim2.fromOffset(14, 0)
    l.Size = UDim2.new(1, -72, 1, 0)
    l.ZIndex = 4

    makeSwitch(row, false, default, callback)
end

-- ========= Слайдер скорости (Material 3) =========
local function makeSpeedSlider(text, min, max, default, callback, parent)
    parent = parent or content
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 88)
    row.BackgroundColor3 = COLORS.item
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = parent
    corner(row, 16)

    local l = label(row, text, 14)
    l.Position = UDim2.fromOffset(16, 10)
    l.Size = UDim2.new(1, -170, 0, 28)
    l.ZIndex = 4

    local minus = makeBtn(row)
    minus.Size = UDim2.fromOffset(28, 28)
    minus.Position = UDim2.new(1, -146, 0, 10)
    minus.Text = "−"
    minus.TextSize = 16
    minus.Font = Enum.Font.GothamBold
    minus.TextColor3 = COLORS.text
    minus.BackgroundColor3 = COLORS.highest
    minus.ZIndex = 4
    corner(minus, 14)
    hoverFx(minus, COLORS.highest, COLORS.selected)

    local box = Instance.new("TextBox")
    box.Text = tostring(default)
    box.TextSize = 13
    box.Font = Enum.Font.GothamBold
    box.TextColor3 = COLORS.accent
    box.PlaceholderColor3 = COLORS.sub
    box.BackgroundColor3 = COLORS.bg
    box.ClearTextOnFocus = false
    box.Size = UDim2.fromOffset(54, 28)
    box.Position = UDim2.new(1, -112, 0, 10)
    box.ZIndex = 4
    box.Parent = row
    corner(box, 14)
    stroke(box, COLORS.outline, 0.5, 1)

    local plus = makeBtn(row)
    plus.Size = UDim2.fromOffset(28, 28)
    plus.Position = UDim2.new(1, -52, 0, 10)
    plus.Text = "+"
    plus.TextSize = 16
    plus.Font = Enum.Font.GothamBold
    plus.TextColor3 = COLORS.text
    plus.BackgroundColor3 = COLORS.highest
    plus.ZIndex = 4
    corner(plus, 14)
    hoverFx(plus, COLORS.highest, COLORS.selected)

    -- большая невидимая зона нажатия + тонкая дорожка
    local hit = makeBtn(row)
    hit.Size = UDim2.new(1, -32, 0, 34)
    hit.Position = UDim2.new(0, 16, 0, 46)
    hit.BackgroundTransparency = 1
    hit.ZIndex = 4

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 12)
    track.AnchorPoint = Vector2.new(0, 0.5)
    track.Position = UDim2.new(0, 0, 0.5, 0)
    track.BackgroundColor3 = COLORS.highest
    track.BorderSizePixel = 0
    track.ZIndex = 4
    track.Parent = hit
    corner(track, 6)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = COLORS.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    fill.Parent = track
    corner(fill, 6)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(6, 28)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = COLORS.accent
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = track
    corner(knob, 3)
    stroke(knob, COLORS.item, 0, 3)

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
    connect(hit.InputBegan, function(i)
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
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = v and COLLAPSED_SIZE or FULL_SIZE
    }):Play()
    task.delay(0.1, function()
        body.Visible = not v
    end)
    collapseBtn.Text = v and "▸" or "▾"
end

connect(collapseBtn.Activated, function()
    setCollapsed(not collapsed)
end)

-- ========= Уведомления (snackbar Material 3) =========
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
    card.Size = UDim2.fromOffset(300, 42)
    card.BackgroundColor3 = COLORS.text
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.LayoutOrder = notifOrder
    card.Parent = notifHolder
    corner(card, 14)

    local txt = label(card, text, 13, COLORS.onAccent, Enum.Font.GothamMedium)
    txt.Position = UDim2.fromOffset(16, 0)
    txt.Size = UDim2.new(1, -24, 1, 0)
    txt.TextTransparency = 1

    TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.03 }):Play()
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
    if model:IsA("BasePart") then return model end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end


-- ========= ESP дверного проёма (только следующая дверь) =========
local RS = game:GetService("ReplicatedStorage")
local doorState = nil -- { door, hl, bb, tl, part }

local function clearDoor()
    if doorState then
        for _, o in ipairs({ doorState.hl, doorState.bb }) do
            pcall(function() o:Destroy() end)
        end
        doorState = nil
    end
end

local function getNextDoor()
    local gd = RS:FindFirstChild("GameData")
    local lr = gd and gd:FindFirstChild("LatestRoom")
    if not lr then return nil end
    local rooms = workspace:FindFirstChild("CurrentRooms")
    local room = rooms and rooms:FindFirstChild(tostring(lr.Value))
    local door = room and room:FindFirstChild("Door")
    return door, lr.Value
end

local function updateDoor()
    if not State.doorOn then clearDoor() return end
    local door, num = getNextDoor()
    if doorState and doorState.door == door and door and door.Parent then return end
    clearDoor()
    if not door then return end

    local part = door:FindFirstChild("Door")
    if not (part and part:IsA("BasePart")) then
        part = door:IsA("BasePart") and door or getPart(door)
    end
    if not part then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = door
    hl.FillColor = COLORS.door
    hl.FillTransparency = 0.45
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = espFolder

    local bb = Instance.new("BillboardGui")
    bb.Adornee = part
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(160, 36)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.Parent = espFolder

    local tl = Instance.new("TextLabel")
    tl.BackgroundTransparency = 1
    tl.Size = UDim2.fromScale(1, 1)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 14
    tl.TextColor3 = COLORS.doorText
    tl.TextStrokeTransparency = 0.3
    tl.Text = "ДВЕРЬ " .. tostring((tonumber(num) or 0) + 1)
    tl.Parent = bb

    doorState = { door = door, hl = hl, bb = bb, tl = tl, part = part, num = (tonumber(num) or 0) + 1 }
end

local function removeEsp(model)
    local t = tracked[model]
    if not t then return end
    tracked[model] = nil
    for _, o in ipairs(t.objects) do
        pcall(function() o:Destroy() end)
    end
end

local function addEsp(model, displayName, floorId, notifySpawn, style)
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
        hl.FillColor = style and style.fill or COLORS.esp
        hl.FillTransparency = 0.6
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = State.espOn
        hl.Parent = espFolder

        local bb = Instance.new("BillboardGui")
        bb.Adornee = part
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(160, 36)
        bb.StudsOffset = Vector3.new(0, style and style.offset or 2.5, 0)
        bb.Enabled = State.espOn
        bb.Parent = espFolder

        local tl = Instance.new("TextLabel")
        tl.BackgroundTransparency = 1
        tl.Size = UDim2.fromScale(1, 1)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 14
        tl.TextColor3 = style and style.text or (floorId == "?" and COLORS.espUnk or COLORS.espText)
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

local function isGloomEgg(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return false end
    local n = inst.Name:lower()
    if not n:find("egg", 1, true) then return false end
    if n:find("gloom", 1, true) or n:find("moth", 1, true) or n:find("bat", 1, true) then return true end
    return (n == "egg" or n == "eggs") and inst:FindFirstAncestor("CurrentRooms") ~= nil
end

local function hasAncestor(inst, pred)
    local p = inst.Parent
    while p and p ~= workspace do
        if pred(p) then return true end
        p = p.Parent
    end
    return false
end

local function isEntityModel(p)
    return p:IsA("Model") and (tracked[p] ~= nil or ENTITIES[p.Name] ~= nil)
end

local EGG_STYLE = { fill = COLORS.egg, text = COLORS.eggText, offset = 1.5 }

local function check(inst)
    local isModel = inst:IsA("Model")
    if not isModel and not inst:IsA("BasePart") then return end

    -- яйца Gloombat (подсвечиваем сам объект яйца на земле)
    if isGloomEgg(inst) then
        if State.entityVisible[EGG_NAME] and not hasAncestor(inst, isGloomEgg) then
            addEsp(inst, EGG_NAME, "2", false, EGG_STYLE)
        end
        return
    end
    if not isModel then return end

    -- детали внутри уже найденной сущности (Screech и т.п.) — не отдельные ESP
    if hasAncestor(inst, isEntityModel) then return end

    local n = inst.Name:lower()
    local inRooms = inst:FindFirstAncestor("CurrentRooms") ~= nil

    -- глаза на стенах у Seek и прочий декор Seek внутри комнат — игнорируем
    local isSeekMover = inst.Name == "SeekMoving" or inst.Name == "SeekMovingNewClone"
    if inRooms and not isSeekMover and (n:find("seek", 1, true) or n:find("eye", 1, true)) then
        return
    end

    local e = ENTITIES[inst.Name]
    if e then
        if State.entityVisible[e[1]] then
            addEsp(inst, e[1], e[2], true)
        end
    elseif live and State.autoOn
        and not inRooms
        and not inst:FindFirstAncestorOfClass("Model")
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
        pcall(updateDoor)
        if doorState and root and doorState.part and doorState.part.Parent then
            local dist = (doorState.part.Position - root.Position).Magnitude
            doorState.tl.Text = string.format("ДВЕРЬ %d [%dm]", doorState.num, dist)
        end
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

-- ========= ПРЕДМЕТЫ И ГОЛОВОЛОМКИ (отдельный пункт, по умолчанию ВЫКЛ) =========
State.pzOn = false
State.pz = { loot = true, library = true, gen = true, lever = true }

local PZ = {}          -- публичные функции модуля (используются в меню)
PZ.codeLabel = nil     -- сюда меню положит TextLabel с кодом библиотеки

do
    local COL = {
        loot      = { Color3.fromRGB(96, 190, 255),  Color3.fromRGB(190, 232, 255) },
        container = { Color3.fromRGB(80, 230, 190),  Color3.fromRGB(190, 255, 235) },
        library   = { Color3.fromRGB(176, 140, 255), Color3.fromRGB(226, 210, 255) },
        gen       = { Color3.fromRGB(255, 160, 50),  Color3.fromRGB(255, 224, 170) },
        lever     = { Color3.fromRGB(255, 110, 190), Color3.fromRGB(255, 200, 232) },
    }
    local GROUP = { loot = "loot", container = "loot", library = "library", gen = "gen", lever = "lever" }

    local ITEM_RU = {
        key = "Ключ", skeletonkey = "Скелетный ключ", lighter = "Зажигалка", lockpicks = "Отмычки",
        vitamins = "Витамины", flashlight = "Фонарик", battery = "Батарейка", bandage = "Бинт",
        candle = "Свеча", crucifix = "Распятие", smoothie = "Смузи", compass = "Компас",
        shears = "Ножницы", goldpile = "Золото", gold = "Золото", glowsticks = "Светящиеся палочки",
        holygrenade = "Святая граната", guidinglight = "Путеводный свет", straplight = "Налобный фонарь",
        bulklight = "Лампа", firstaid = "Аптечка", lockpick = "Отмычка",
    }

    local WORD_RU = {
        livehintbook = "КНИГА-ПОДСКАЗКА", hintbook = "КНИГА-ПОДСКАЗКА", hintpaper = "ПОДСКАЗКА",
        libraryhint = "ПОДСКАЗКА", padlock = "ЗАМОК",
        lever = "РЫЧАГ", switch = "ПЕРЕКЛЮЧАТЕЛЬ", button = "КНОПКА", furnace = "ПЕЧЬ · СЖЕЧЬ",
        incinerat = "ПЕЧЬ · СЖЕЧЬ", burn = "СЖЕЧЬ", fireplace = "КАМИН",
        generator = "ГЕНЕРАТОР", lamp = "ЛАМПОЧКА", bulb = "ЛАМПОЧКА", fuse = "ПРЕДОХРАНИТЕЛЬ",
        valve = "ВЕНТИЛЬ", breaker = "РУБИЛЬНИК", cable = "КАБЕЛЬ", wire = "ПРОВОД",
        gear = "ШЕСТЕРНЯ", wheel = "КОЛЕСО", pipe = "ТРУБА",
        drawer = "ТУМБА", chest = "СУНДУК", dresser = "КОМОД", nightstand = "ТУМБОЧКА",
        toolbox = "ЯЩИК", shelf = "ПОЛКА", crate = "ЯЩИК", cabinet = "ШКАФ", cupboard = "ШКАФ",
        locker = "ШКАФЧИК", toolshed = "ЯЩИК С ИНСТР.",
    }

    local LIB_WORDS   = { "livehintbook", "hintbook", "hintpaper", "libraryhint", "padlock" }
    local LEVER_WORDS = { "lever", "switch", "button", "furnace", "incinerat", "burn", "fireplace" }
    local GEN_WORDS   = { "generator", "lamp", "bulb", "fuse", "valve", "breaker", "cable", "wire", "gear", "wheel", "pipe" }
    local CONT_WORDS  = { "drawer", "chest", "dresser", "nightstand", "toolbox", "shelf", "crate",
                          "cabinet", "cupboard", "locker", "toolshed" }

    local function hasAny(str, words)
        for _, w in ipairs(words) do
            if str:find(w, 1, true) then return w end
        end
        return nil
    end

    -- определяем, что это за объект, по ProximityPrompt и имени модели
    local function classify(prompt, target)
        local pn = prompt.Name:lower()
        local act = (prompt.ActionText or ""):lower()
        local tn = target.Name:lower()
        local parentName = target.Parent and target.Parent.Name:lower() or ""

        if pn:find("hide", 1, true) or act:find("hide", 1, true) then return nil end

        local w = hasAny(tn .. " " .. parentName, LIB_WORDS)
        if w then return "library", w end

        if tn:find("door", 1, true) then return nil end

        if pn == "moduleprompt" or pn == "lootprompt"
            or act:find("take", 1, true) or act:find("collect", 1, true)
            or act:find("loot", 1, true) or act:find("grab", 1, true) then
            return "loot", nil
        end

        w = hasAny(tn, LEVER_WORDS) or hasAny(pn, LEVER_WORDS)
        if w then return "lever", w end

        w = hasAny(tn, GEN_WORDS)
        if w then return "gen", w end

        -- сами тумбы, шкафы и сундуки не показываем, только предметы

        return nil
    end

    local tracked = {}
    local hlCount = 0
    local HL_CAP = 8 -- у Roblox лимит на количество Highlight, оставляем запас для сущностей

    local function remove(prompt)
        local e = tracked[prompt]
        if not e then return end
        tracked[prompt] = nil
        if e.hl and e.cat ~= "loot" then hlCount -= 1 end
        if e.hl then pcall(function() e.hl:Destroy() end) end
        if e.bb then pcall(function() e.bb:Destroy() end) end
    end

    local function add(prompt)
        if tracked[prompt] or not State.pzOn then return end
        local target = prompt.Parent
        if target and target:IsA("Attachment") then target = target.Parent end
        if not target then return end
        if target:IsA("BasePart") then
            local m = target.Parent
            if m and m:IsA("Model") and m.Parent and m.Parent.Name ~= "CurrentRooms" then
                target = m
            end
        end

        local cat, word = classify(prompt, target)
        if not cat or not State.pz[GROUP[cat]] then return end

        -- выдвижные части и сами тумбы/шкафы пропускаем: нужны только предметы внутри
        if cat == "loot" and hasAny(target.Name:lower(), CONT_WORDS) then return end

        local part = target:IsA("BasePart") and target or getPart(target)
        if not part then return end

        local raw = target.Name
        local text
        if cat == "loot" then
            text = ITEM_RU[(raw:lower():gsub("%s+", ""))] or raw
        elseif word == "padlock" then
            text = "ЗАМОК"
        else
            text = (WORD_RU[word] or tostring(word):upper()) .. " (" .. raw .. ")"
        end

        local colors = COL[cat]
        local e = { cat = cat, word = word, text = text, part = part }

        if cat == "loot" or hlCount < HL_CAP then
            local hl = Instance.new("Highlight")
            hl.Adornee = target
            hl.FillColor = colors[1]
            hl.FillTransparency = cat == "loot" and 0.45 or 0.6
            hl.OutlineColor = Color3.new(1, 1, 1)
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Enabled = cat ~= "loot" -- предметы включаем по расстоянию в цикле
            hl.Parent = espFolder
            e.hl = hl
            if cat ~= "loot" then hlCount += 1 end
        end

        if cat ~= "loot" then
            local bb = Instance.new("BillboardGui")
            bb.Adornee = part
            bb.AlwaysOnTop = true
            bb.Size = UDim2.fromOffset(220, 30)
            bb.StudsOffset = Vector3.new(0, 2, 0)
            bb.Parent = espFolder

            local tl = Instance.new("TextLabel")
            tl.BackgroundTransparency = 1
            tl.Size = UDim2.fromScale(1, 1)
            tl.Font = Enum.Font.GothamBold
            tl.TextSize = 13
            tl.TextColor3 = colors[2]
            tl.TextStrokeTransparency = 0.3
            tl.Text = text
            tl.Parent = bb
            e.bb, e.tl = bb, tl
        end

        tracked[prompt] = e
    end

    function PZ.clearAll()
        for prompt in pairs(tracked) do remove(prompt) end
        hlCount = 0
    end

    function PZ.scanAll()
        local rooms = workspace:FindFirstChild("CurrentRooms")
        if not rooms then return end
        task.spawn(function()
            for i, d in ipairs(rooms:GetDescendants()) do
                if not State.pzOn then return end
                if d:IsA("ProximityPrompt") then pcall(add, d) end
                if i % 300 == 0 then task.wait() end
            end
        end)
    end

    function PZ.refresh()
        PZ.clearAll()
        if State.pzOn then PZ.scanAll() end
    end

    -- новые комнаты подгружаются по мере продвижения
    connect(workspace.DescendantAdded, function(inst)
        if State.pzOn and inst:IsA("ProximityPrompt") and inst:FindFirstAncestor("CurrentRooms") then
            task.delay(0.35, function()
                if inst.Parent then pcall(add, inst) end
            end)
        end
    end)

    -- код замка библиотеки: иконки на бумаге-подсказке сопоставляются с цифрами из книг
    local function libraryCode()
        local pg = lp:FindFirstChild("PlayerGui")
        local perm = pg and pg:FindFirstChild("PermUI")
        local hints = perm and perm:FindFirstChild("Hints")
        if not hints then return nil end

        local paper
        for _, holder in ipairs({ lp.Character, lp:FindFirstChild("Backpack") }) do
            if holder then
                paper = holder:FindFirstChild("LibraryHintPaper")
                if paper then break end
            end
        end
        local ui = paper and paper:FindFirstChild("UI")
        if not ui then return nil end

        local code, known = { "_", "_", "_", "_", "_" }, 0
        for _, icon in ipairs(ui:GetChildren()) do
            local idx = tonumber(icon.Name)
            if idx and idx >= 1 and idx <= 5 and icon:IsA("ImageLabel") then
                for _, h in ipairs(hints:GetChildren()) do
                    if h:IsA("ImageLabel") and h.ImageRectOffset == icon.ImageRectOffset then
                        local tl = h:FindFirstChildWhichIsA("TextLabel")
                        if tl and tl.Text ~= "" then
                            code[idx] = tl.Text
                            known += 1
                        end
                    end
                end
            end
        end
        return table.concat(code, " "), known
    end

    task.spawn(function()
        local lastCode = ""
        while gui.Parent do
            if State.pzOn then
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")

                local lootList = {}
                for prompt, e in pairs(tracked) do
                    local gone = not prompt.Parent or not e.part.Parent
                    if gone then
                        remove(prompt)
                    elseif root then
                        local d = (e.part.Position - root.Position).Magnitude
                        if e.tl then
                            e.tl.Text = string.format("%s [%dm]", e.text, d)
                        elseif e.cat == "loot" and e.hl then
                            lootList[#lootList + 1] = { hl = e.hl, d = d }
                        end
                    end
                end
                table.sort(lootList, function(a, b) return a.d < b.d end)
                for i, it in ipairs(lootList) do
                    it.hl.Enabled = i <= 20 and it.d <= 200
                end

                if State.pz.library then
                    local ok, text, known = pcall(libraryCode)
                    if ok and text then
                        if PZ.codeLabel then PZ.codeLabel.Text = text end
                        for _, e in pairs(tracked) do
                            if e.word == "padlock" then e.text = "ЗАМОК: " .. text end
                        end
                        if text ~= lastCode then
                            lastCode = text
                            if known and known > 0 then notify("Код библиотеки: " .. text) end
                        end
                    elseif PZ.codeLabel then
                        PZ.codeLabel.Text = "нет бумаги-подсказки"
                    end
                end
            end
            task.wait(0.3)
        end
    end)
end

-- ========= Меню: пункты слева, функции справа =========
-- ИГРОК
makeToggle("Изменение скорости", false, function(v)
    State.speedOn = v
end, pages.player)
makeSpeedSlider("Скорость", MIN_SPEED, MAX_SPEED, State.speed, function(v)
    State.speed = v
end, pages.player)

-- ESP
makeToggle("ESP сущностей", true, function(v) State.espOn = v end, pages.esp)
makeToggle("Подсветка нужной двери", true, function(v)
    State.doorOn = v
    if not v then clearDoor() end
end, pages.esp)
makeToggle("Авто-обнаружение новых", true, function(v) State.autoOn = v end, pages.esp)
makeToggle("Уведомления о спавне", true, function(v) State.notifyOn = v end, pages.esp)

-- ГОЛОВОЛОМКИ (всё выключено по умолчанию)
makeToggle("Предметы и головоломки", false, function(v)
    State.pzOn = v
    if v then PZ.scanAll() else PZ.clearAll() end
end, pages.pz)

do
    local sec = makeSection("ЧТО ПОКАЗЫВАТЬ", true, pages.pz)
    makeSmallToggle("Предметы (только лежащие)", true, function(v)
        State.pz.loot = v
        PZ.refresh()
    end, sec)
    makeSmallToggle("Библиотека: книги, замок, код", true, function(v)
        State.pz.library = v
        PZ.refresh()
    end, sec)
    makeSmallToggle("Шахты: генераторы и лампочки", true, function(v)
        State.pz.gen = v
        PZ.refresh()
    end, sec)
    makeSmallToggle("Рычаги и огонь (лестницы)", true, function(v)
        State.pz.lever = v
        PZ.refresh()
    end, sec)

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = COLORS.item
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = pages.pz
    corner(row, 16)

    local cap = label(row, "Код библиотеки", 12, COLORS.sub, Enum.Font.GothamMedium)
    cap.Position = UDim2.fromOffset(16, 8)
    cap.Size = UDim2.new(1, -32, 0, 16)
    cap.ZIndex = 4

    local val = label(row, "—", 18, COLORS.accent, Enum.Font.GothamBold)
    val.Position = UDim2.fromOffset(16, 26)
    val.Size = UDim2.new(1, -32, 0, 24)
    val.ZIndex = 4
    PZ.codeLabel = val
end

-- СУЩНОСТИ (по этажам)
for _, f in ipairs(FLOORS) do
    if #floorEntities[f.id] > 0 then
        local sec = makeSection(f.title, f.id == "1", pages.ent)
        for _, name in ipairs(floorEntities[f.id]) do
            makeSmallToggle(name, State.entityVisible[name], function(v)
                State.entityVisible[name] = v
                task.spawn(function()
                    if not v then
                        for m, t in pairs(tracked) do
                            if t.name == name then removeEsp(m) end
                        end
                    else
                        for _, d in ipairs(workspace:GetDescendants()) do
                            check(d)
                        end
                    end
                end)
            end, sec)
        end
    end
end

-- СВЯЗЬ
do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 60)
    row.BackgroundColor3 = COLORS.item
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = pages.link
    corner(row, 16)

    local l = label(row, "ТГК разраба", 14)
    l.Position = UDim2.fromOffset(16, 9)
    l.Size = UDim2.new(1, -120, 0, 20)
    l.ZIndex = 4

    local link = label(row, "t.me/fiskgrov", 12, COLORS.sub, Enum.Font.GothamMedium)
    link.Position = UDim2.fromOffset(16, 31)
    link.Size = UDim2.new(1, -120, 0, 18)
    link.ZIndex = 4

    local btn = makeBtn(row)
    btn.Size = UDim2.fromOffset(86, 36)
    btn.Position = UDim2.new(1, -100, 0.5, -18)
    btn.BackgroundColor3 = COLORS.accent
    btn.Text = "Перейти"
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = COLORS.onAccent
    btn.ZIndex = 4
    corner(btn, 18)
    hoverFx(btn, COLORS.accent, COLORS.accent3)

    connect(btn.Activated, function()
        local ok = pcall(function() setclipboard("https://t.me/fiskgrov") end)
        if ok then
            notify("Ссылка скопирована: t.me/fiskgrov")
        else
            notify("t.me/fiskgrov")
        end
    end)
end

local hint = label(pages.link, "RightShift — скрыть / показать меню", 11, COLORS.sub)
hint.Size = UDim2.new(1, 0, 0, 16)
hint.TextXAlignment = Enum.TextXAlignment.Center
hint.LayoutOrder = nextOrder()
hint.ZIndex = 2

selectTab("player")

-- ========= Плавающая кнопка (круг с лого) =========
local fab = Instance.new("TextButton")
fab.Name = "Fab"
fab.Size = UDim2.fromOffset(56, 56)
fab.Position = UDim2.new(0, 16, 0.5, -28)
fab.BackgroundColor3 = COLORS.item
fab.Text = logoImage and "" or "◈"
fab.TextSize = 22
fab.Font = Enum.Font.GothamBold
fab.TextColor3 = COLORS.accent
fab.AutoButtonColor = false
fab.Active = true
fab.BorderSizePixel = 0
fab.ZIndex = 5
fab.Parent = gui
corner(fab, 28)
stroke(fab, COLORS.accent, 0.4, 1.5)
if logoImage then
    local fi = Instance.new("ImageLabel")
    fi.Size = UDim2.fromScale(1, 1)
    fi.BackgroundTransparency = 1
    fi.Image = logoImage
    fi.ScaleType = Enum.ScaleType.Crop
    fi.ZIndex = 6
    fi.Parent = fab
    corner(fi, 28)
end

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
    State.pzOn = false
    PZ.clearAll()
    clearDoor()
    for m in pairs(tracked) do removeEsp(m) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)
