--[[
    Fisk Grow v4.0
    - ГОРИЗОНТАЛЬНОЕ прямоугольное меню: слева пункты (вкладки), справа содержимое
    - ESP только на сущностях; комнаты и объекты НЕ подсвечиваются
    - Подсвечивается только дверной проём, в который нужно идти (следующая дверь)
    - Seek: глаза на стенах больше не подсвечиваются
    - Screech: подсвечивается одной целой сущностью (без отдельных деталей)
    - Floor 2: подсвечиваются яйца Gloombat там, где они лежат
    - Все кнопки работают через Activated (тап/мышь)
    - v3.6: оформление Material You (чёрно-белое), фото-лого рядом с названием
    - v3.6: вкладка ГОЛОВОЛОМКИ (предметы, библиотека, генераторы, рычаги)
    - v3.6: локальные стрелки пути и отсчёт прыжка при погоне Seek
    - v3.7: тумблер диагностики Seek; маршрут к двери по кнопке (фиксированный); компактное свёрнутое меню; уведомления справа как достижения
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
    speed = 0, -- величина буста (прибавляется к скорости игры)
    espOn = true,
    autoOn = true,
    notifyOn = true,
    doorOn = true,
    entityVisible = {},
}
local MIN_SPEED, MAX_SPEED = 0, 100
local MV = {} -- движение: буст скорости, третье лицо, перенос хитбокса (см. блок ниже)
local FULL_SIZE = UDim2.fromOffset(580, 340)
local COLLAPSED_SIZE = UDim2.fromOffset(236, 52)

-- ========= Этажи и сущности =========
local FLOORS = {
    { id = "1",  title = "ЭТАЖ 1 - ОТЕЛЬ" },
    { id = "2",  title = "ЭТАЖ 2 - ШАХТЫ" },
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
-- Если хочешь свой rbxassetid - вставь сюда, например "rbxassetid://123456789"
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

-- ========= Палитра (Material You - чёрно-белая) =========
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

-- ========= Иконки (рисуются фигурами, шрифты не нужны) =========
local function iconBar(parent, w, h, x, y, rot, color)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.fromOffset(w, h)
    f.Position = UDim2.fromOffset(x, y)
    f.Rotation = rot or 0
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = 6
    f.Parent = parent
    corner(f, math.min(w, h) / 2)
    return f
end

local function iconRing(parent, w, h, x, y, th, color, r)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.fromOffset(w, h)
    f.Position = UDim2.fromOffset(x, y)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.ZIndex = 6
    f.Parent = parent
    corner(f, r)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = th
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = f
    return f
end

-- kind: close, chevdown, chevright, plus, minus, player, esp, ent, pz, link
local function makeIcon(parent, kind, color, size)
    local c = Instance.new("Frame")
    c.AnchorPoint = Vector2.new(0.5, 0.5)
    c.Size = UDim2.fromOffset(20, 20)
    c.BackgroundTransparency = 1
    c.BorderSizePixel = 0
    c.ZIndex = 6
    c.Parent = parent
    local sc = Instance.new("UIScale")
    sc.Scale = (size or 20) / 20
    sc.Parent = c

    if kind == "close" then
        iconBar(c, 16, 2.4, 10, 10, 45, color)
        iconBar(c, 16, 2.4, 10, 10, -45, color)
    elseif kind == "chevdown" then
        iconBar(c, 10, 2.4, 6.5, 9.5, 45, color)
        iconBar(c, 10, 2.4, 13.5, 9.5, -45, color)
    elseif kind == "chevright" then
        iconBar(c, 10, 2.4, 10.5, 6.5, 45, color)
        iconBar(c, 10, 2.4, 10.5, 13.5, -45, color)
    elseif kind == "plus" then
        iconBar(c, 12, 2.4, 10, 10, 0, color)
        iconBar(c, 2.4, 12, 10, 10, 0, color)
    elseif kind == "minus" then
        iconBar(c, 12, 2.4, 10, 10, 0, color)
    elseif kind == "player" then
        iconBar(c, 7, 7, 10, 6, 0, color)
        iconBar(c, 14, 8, 10, 15, 0, color)
    elseif kind == "esp" then
        iconRing(c, 18, 11, 10, 10, 2, color, 6)
        iconBar(c, 5, 5, 10, 10, 0, color)
    elseif kind == "ent" then
        for i = 0, 2 do
            local y = 4.5 + i * 5.5
            iconBar(c, 3, 3, 3.5, y, 0, color)
            iconBar(c, 11, 2.2, 13, y, 0, color)
        end
    elseif kind == "pz" then
        iconRing(c, 11, 11, 8.5, 8.5, 2, color, 6)
        iconBar(c, 8, 2.6, 15.5, 15.5, 45, color)
    elseif kind == "link" then
        iconRing(c, 18, 13, 10, 9, 2, color, 5)
        iconBar(c, 9, 2, 10, 7, 0, color)
        iconBar(c, 6, 2, 8.5, 11, 0, color)
    end
    return c
end

local function setIconColor(icon, color)
    for _, d in ipairs(icon:GetDescendants()) do
        if d:IsA("UIStroke") then
            d.Color = color
        elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
            d.BackgroundColor3 = color
        end
    end
end

-- ========= Язык: выбор при первом запуске, дальше запоминается =========
local LANG_FILE = "fiskgrow_lang.txt"
local LANG = nil
pcall(function()
    if isfile and readfile and isfile(LANG_FILE) then
        local v = readfile(LANG_FILE)
        if v == "ru" or v == "en" then LANG = v end
    end
end)

local EN_STRINGS = {
    ["ИГРОК"] = "PLAYER",
    ["СУЩНОСТИ"] = "ENTITIES",
    ["ГОЛОВОЛОМКИ"] = "PUZZLES",
    ["СВЯЗЬ"] = "CONTACT",
    ["ДВЕРЬ "] = "DOOR ",
    [" появился!"] = " spawned!",
    ["ДВЕРЬ %d [%dm]"] = "DOOR %d [%dm]",
    ["Ключ"] = "Key",
    ["Скелетный ключ"] = "Skeleton Key",
    ["Зажигалка"] = "Lighter",
    ["Отмычки"] = "Lockpicks",
    ["Витамины"] = "Vitamins",
    ["Фонарик"] = "Flashlight",
    ["Батарейка"] = "Battery",
    ["Бинт"] = "Bandage",
    ["Свеча"] = "Candle",
    ["Распятие"] = "Crucifix",
    ["Смузи"] = "Smoothie",
    ["Компас"] = "Compass",
    ["Ножницы"] = "Shears",
    ["Золото"] = "Gold",
    ["Светящиеся палочки"] = "Glowsticks",
    ["Святая граната"] = "Holy Grenade",
    ["Путеводный свет"] = "Guiding Light",
    ["Налобный фонарь"] = "Strap Light",
    ["Лампа"] = "Lamp",
    ["Аптечка"] = "First Aid",
    ["Отмычка"] = "Lockpick",
    ["КНИГА-ПОДСКАЗКА"] = "HINT BOOK",
    ["ПОДСКАЗКА"] = "HINT",
    ["ЗАМОК"] = "PADLOCK",
    ["РЫЧАГ"] = "LEVER",
    ["ПЕРЕКЛЮЧАТЕЛЬ"] = "SWITCH",
    ["КНОПКА"] = "BUTTON",
    ["ПЕЧЬ - СЖЕЧЬ"] = "FURNACE - BURN",
    ["СЖЕЧЬ"] = "BURN",
    ["КАМИН"] = "FIREPLACE",
    ["ГЕНЕРАТОР"] = "GENERATOR",
    ["ЛАМПОЧКА"] = "BULB",
    ["ПРЕДОХРАНИТЕЛЬ"] = "FUSE",
    ["ВЕНТИЛЬ"] = "VALVE",
    ["РУБИЛЬНИК"] = "BREAKER",
    ["КАБЕЛЬ"] = "CABLE",
    ["ПРОВОД"] = "WIRE",
    ["ШЕСТЕРНЯ"] = "GEAR",
    ["КОЛЕСО"] = "WHEEL",
    ["ТРУБА"] = "PIPE",
    ["ТУМБА"] = "DRAWER",
    ["СУНДУК"] = "CHEST",
    ["КОМОД"] = "DRESSER",
    ["ТУМБОЧКА"] = "NIGHTSTAND",
    ["ЯЩИК"] = "BOX",
    ["ПОЛКА"] = "SHELF",
    ["ШКАФ"] = "CABINET",
    ["ШКАФЧИК"] = "LOCKER",
    ["ЯЩИК С ИНСТР."] = "TOOLBOX",
    ["ЗАМОК: "] = "PADLOCK: ",
    ["Код библиотеки: "] = "Library code: ",
    ["нет бумаги-подсказки"] = "no hint paper",
    ["Изменение скорости"] = "Speed change",
    ["Скорость"] = "Speed",
    ["СКОРОСТЬ"] = "SPEED",
    ["ОБХОД"] = "BYPASS",
    ["УДАЛЕНИЕ СУЩНОСТЕЙ"] = "REMOVE ENTITIES",
    ["БЕЗ УРОНА"] = "NO DAMAGE",
    ["Удалить Screech"] = "Remove Screech",
    ["Удалить Halt"] = "Remove Halt",
    ["Удалить A-90"] = "Remove A-90",
    ["Удалить Dread"] = "Remove Dread",
    ["Удалить Surge"] = "Remove Surge",
    ["Без урона от Screech"] = "No Screech damage",
    ["Без урона от Halt"] = "No Halt damage",
    ["Без урона от A-90"] = "No A-90 damage",
    ["Без урона от Surge"] = "No Surge damage",
    ["Обход Giggle"] = "Bypass Giggle",
    ["Обход Dupe (фейковые двери)"] = "Bypass Dupe (fake doors)",
    ["Обход Eyes"] = "Bypass Eyes",
    ["Обход Lookman"] = "Bypass Lookman",
    ["Обход яиц Gloombat"] = "Bypass Gloombat eggs",
    ["Обход преград Seek"] = "Bypass Seek obstacles",
    ["Обход Vacuum"] = "Bypass Vacuum",
    ["Обход лавы"] = "Bypass lava",
    ["Обход Seeking Wall"] = "Bypass Seeking Wall",
    ["Обход Snare"] = "Bypass Snare",
    ["Обход банана"] = "Bypass banana peel",
    ["Обход Jeff"] = "Bypass Jeff",
    ["ЛЮДИ"] = "USERS",
    ["Показывать меня другим пользователям скрипта"] = "Show me to other script users",
    ["Метка над игроками со скриптом"] = "Tag above players using the script",
    ["Адрес сервера не задан (переменная FISK_API в скрипте)"] = "Server address not set (FISK_API variable in the script)",
    ["Со скриптом на этом сервере: "] = "Using the script on this server: ",
    ["всего онлайн: "] = "total online: ",
    ["использует скрипт"] = "is using the script",
    ["Введите код доступа"] = "Enter access code",
    ["Код выдаётся в Telegram-канале Fisk Grow"] = "The code is posted in the Fisk Grow Telegram channel",
    ["Код"] = "Code",
    ["Войти"] = "Enter",
    ["Копировать ссылку на Telegram"] = "Copy Telegram link",
    ["Неверный код"] = "Wrong code",
    ["Закрыть"] = "Close",
    ["ПОЛЁТ"] = "FLY",
    ["Полёт (Fly)"] = "Fly",
    ["Скорость полёта"] = "Fly speed",
    ["Убрать ускорение (без скольжения)"] = "Remove acceleration (no sliding)",
    ["ТРЕТЬЕ ЛИЦО"] = "THIRD PERSON",
    ["Вид от третьего лица"] = "Third person view",
    ["Клавиша"] = "Key",
    ["Смещение X"] = "X offset",
    ["Смещение Y"] = "Y offset",
    ["Смещение Z"] = "Z offset",
    ["Проверка стен"] = "Wall check",
    ["ХИТБОКС"] = "HITBOX",
    ["Перенос хитбокса"] = "Move hitbox",
    ["Всегда приседать (Crouch Spoof)"] = "Always crouch (Crouch Spoof)",
    ["Перенос хитбокса не работает на этом этаже"] = "Hitbox move is not supported on this floor",
    ["ESP сущностей"] = "Entity ESP",
    ["Подсветка нужной двери"] = "Highlight next door",
    ["Авто-обнаружение новых"] = "Auto-detect new ones",
    ["Уведомления о спавне"] = "Spawn notifications",
    ["Предметы и головоломки"] = "Items & puzzles",
    ["ЧТО ПОКАЗЫВАТЬ"] = "WHAT TO SHOW",
    ["Предметы (только лежащие)"] = "Items (loose only)",
    ["Библиотека: книги, замок, код"] = "Library: books, padlock, code",
    ["Шахты: генераторы и лампочки"] = "Mines: generators & bulbs",
    ["Рычаги и огонь (лестницы)"] = "Levers & fire (stairs)",
    ["Код библиотеки"] = "Library code",
    ["ТГК разраба"] = "Dev's Telegram",
    ["Перейти"] = "Copy",
    ["Ссылка скопирована: t.me/fiskgrov"] = "Link copied: t.me/fiskgrov",
    ["RightShift - скрыть / показать меню"] = "RightShift - hide / show menu",
    ["Разрешить прыжок"] = "Allow jumping",
    ["Разрешить слайд"] = "Allow sliding",
    ["Маршрут на Seek (стрелки)"] = "Seek chase route (arrows)",
    ["Предупреждение Screech (поворот)"] = "Screech warning (turn)",
    ["ПОВЕРНИСЬ НАЛЕВО"] = "TURN LEFT",
    ["ПОВЕРНИСЬ НАПРАВО"] = "TURN RIGHT",
    ["ПОВЕРНИСЬ НАЗАД"] = "TURN AROUND",
    ["СМОТРИ НА НЕГО"] = "LOOK AT IT",
    ["СКРИПУН"] = "SCREECH",
    ["Отсчёт прыжка на маршруте"] = "Jump countdown on route",
    ["Диагностика Seek (лог в буфер)"] = "Seek diagnostics (log to clipboard)",
    ["ПРЫГАЙ!"] = "JUMP!",
    ["ПРЫГАЙ"] = "JUMP",
    ["ПРИСЯДЬ!"] = "CROUCH!",
    ["ПРИСЯДЬ"] = "CROUCH",
    ["Маршрут не найден"] = "Route not found",
    ["Маршрут частичный"] = "Partial route",
    ["Подсказки приседания на маршруте"] = "Crouch hints on route",
    ["Язык интерфейса"] = "Interface language",
    ["Сменить"] = "Change",
    ["Язык будет выбран при следующем запуске"] = "Language will be asked on next launch",
    ["ЭТАЖ 1 - ОТЕЛЬ"] = "FLOOR 1 - HOTEL",
    ["ЭТАЖ 2 - ШАХТЫ"] = "FLOOR 2 - MINES",
    ["АРХИВЫ"] = "ARCHIVES",
    ["ЛЕСТНИЦЫ"] = "STAIRS",
    ["Яйцо Gloombat"] = "Gloombat egg",
}

local function T(str)
    if LANG == "en" then return EN_STRINGS[str] or str end
    return str
end

if not LANG then
    local overlay = Instance.new("Frame")
    overlay.Name = "LanguagePicker"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.BorderSizePixel = 0
    overlay.Active = true
    overlay.ZIndex = 50
    overlay.Parent = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(340, 260)
    card.BackgroundColor3 = COLORS.bg
    card.BorderSizePixel = 0
    card.Active = true
    card.ZIndex = 51
    card.Parent = overlay
    corner(card, 28)
    stroke(card, COLORS.outline, 0.65, 1)

    local pl = Instance.new("ImageLabel")
    pl.AnchorPoint = Vector2.new(0.5, 0)
    pl.Position = UDim2.new(0.5, 0, 0, 22)
    pl.Size = UDim2.fromOffset(64, 64)
    pl.BackgroundColor3 = COLORS.item
    pl.BorderSizePixel = 0
    pl.Image = logoImage or ""
    pl.ScaleType = Enum.ScaleType.Crop
    pl.ZIndex = 52
    pl.Parent = card
    corner(pl, 32)
    stroke(pl, COLORS.accent, 0.55, 1.5)
    if not logoImage then
        local f = label(pl, "F", 28, COLORS.accent, Enum.Font.GothamBold)
        f.Size = UDim2.fromScale(1, 1)
        f.TextXAlignment = Enum.TextXAlignment.Center
        f.ZIndex = 53
    end

    local t1 = label(card, "Fisk Grow", 20, COLORS.text, Enum.Font.GothamBold)
    t1.Position = UDim2.fromOffset(0, 94)
    t1.Size = UDim2.new(1, 0, 0, 26)
    t1.TextXAlignment = Enum.TextXAlignment.Center
    t1.ZIndex = 52

    local t2 = label(card, "Выберите язык / Choose language", 13, COLORS.sub, Enum.Font.GothamMedium)
    t2.Position = UDim2.fromOffset(0, 122)
    t2.Size = UDim2.new(1, 0, 0, 20)
    t2.TextXAlignment = Enum.TextXAlignment.Center
    t2.ZIndex = 52

    local chosen = false
    local function option(text, x, code, filled)
        local b = makeBtn(card)
        b.Size = UDim2.fromOffset(144, 50)
        b.Position = UDim2.fromOffset(x, 170)
        b.BackgroundColor3 = filled and COLORS.accent or COLORS.highest
        b.Text = text
        b.TextSize = 15
        b.Font = Enum.Font.GothamBold
        b.TextColor3 = filled and COLORS.onAccent or COLORS.text
        b.ZIndex = 52
        corner(b, 25)
        hoverFx(b, filled and COLORS.accent or COLORS.highest, filled and COLORS.accent3 or COLORS.selected)
        b.Activated:Connect(function()
            if chosen then return end
            chosen = true
            LANG = code
            pcall(function() if writefile then writefile(LANG_FILE, code) end end)
            overlay:Destroy()
        end)
    end
    option("Русский", 20, "ru", true)
    option("English", 176, "en", false)

    while not chosen and gui.Parent do
        task.wait(0.05)
    end
    if not LANG then LANG = "ru" end
end

-- ========= Код доступа: спрашивается при первом запуске, дальше запоминается =========
local ACCESS_CODE = "SERHFISKTT"
local ACCESS_FILE = "fiskgrow_key.txt"
local TG_LINK = "https://t.me/fiskgrov"
local function normCode(str)
    return (tostring(str or ""):gsub("%s+", "")):upper()
end

local accessOk = false
pcall(function()
    if isfile and readfile and isfile(ACCESS_FILE) and normCode(readfile(ACCESS_FILE)) == ACCESS_CODE then
        accessOk = true
    end
end)

if not accessOk then
    local overlay = Instance.new("Frame")
    overlay.Name = "AccessGate"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.35
    overlay.BorderSizePixel = 0
    overlay.Active = true
    overlay.ZIndex = 60
    overlay.Parent = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(340, 392)
    card.BackgroundColor3 = COLORS.bg
    card.BorderSizePixel = 0
    card.Active = true
    card.ZIndex = 61
    card.Parent = overlay
    corner(card, 28)
    stroke(card, COLORS.outline, 0.65, 1)

    local pl = Instance.new("ImageLabel")
    pl.AnchorPoint = Vector2.new(0.5, 0)
    pl.Position = UDim2.new(0.5, 0, 0, 22)
    pl.Size = UDim2.fromOffset(64, 64)
    pl.BackgroundColor3 = COLORS.item
    pl.BorderSizePixel = 0
    pl.Image = logoImage or ""
    pl.ScaleType = Enum.ScaleType.Crop
    pl.ZIndex = 62
    pl.Parent = card
    corner(pl, 32)
    stroke(pl, COLORS.accent, 0.55, 1.5)
    if not logoImage then
        local f = label(pl, "F", 28, COLORS.accent, Enum.Font.GothamBold)
        f.Size = UDim2.fromScale(1, 1)
        f.TextXAlignment = Enum.TextXAlignment.Center
        f.ZIndex = 63
    end

    local function centered(text, size, color, font, y, h)
        local l = label(card, text, size, color, font)
        l.Position = UDim2.fromOffset(16, y)
        l.Size = UDim2.new(1, -32, 0, h)
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextWrapped = true
        l.ZIndex = 62
        return l
    end
    centered("Fisk Grow", 20, COLORS.text, Enum.Font.GothamBold, 94, 26)
    centered(T("Введите код доступа"), 14, COLORS.text, Enum.Font.GothamMedium, 124, 20)
    centered(T("Код выдаётся в Telegram-канале Fisk Grow"), 12, COLORS.sub, Enum.Font.GothamMedium, 146, 34)

    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(300, 46)
    box.Position = UDim2.fromOffset(20, 190)
    box.BackgroundColor3 = COLORS.item
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = T("Код")
    box.PlaceholderColor3 = COLORS.sub
    box.TextColor3 = COLORS.accent
    box.Font = Enum.Font.GothamBold
    box.TextSize = 17
    box.ClearTextOnFocus = false
    box.ZIndex = 62
    box.Parent = card
    corner(box, 23)
    stroke(box, COLORS.outline, 0.5, 1)

    local status = centered("", 12, COLORS.danger, Enum.Font.GothamMedium, 242, 18)

    local function bigBtn(text, x, y, w, filled)
        local b = makeBtn(card)
        b.Size = UDim2.fromOffset(w, 46)
        b.Position = UDim2.fromOffset(x, y)
        b.BackgroundColor3 = filled and COLORS.accent or COLORS.highest
        b.Text = text
        b.TextSize = 14
        b.Font = Enum.Font.GothamBold
        b.TextColor3 = filled and COLORS.onAccent or COLORS.text
        b.ZIndex = 62
        corner(b, 23)
        hoverFx(b, filled and COLORS.accent or COLORS.highest, filled and COLORS.accent3 or COLORS.selected)
        return b
    end
    local okBtn = bigBtn(T("Войти"), 20, 270, 300, true)
    local copyBtn = bigBtn(T("Копировать ссылку на Telegram"), 20, 322, 300, false)
    copyBtn.TextSize = 13

    local closed = false
    local function tryCode()
        if normCode(box.Text) == ACCESS_CODE then
            accessOk = true
            pcall(function() if writefile then writefile(ACCESS_FILE, ACCESS_CODE) end end)
        else
            status.TextColor3 = COLORS.danger
            status.Text = T("Неверный код")
        end
    end
    okBtn.Activated:Connect(tryCode)
    box.FocusLost:Connect(function(enter) if enter then tryCode() end end)
    copyBtn.Activated:Connect(function()
        local copied = false
        pcall(function() if setclipboard then setclipboard(TG_LINK) copied = true end end)
        status.TextColor3 = COLORS.accent
        status.Text = copied and T("Ссылка скопирована: t.me/fiskgrov") or TG_LINK
    end)

    local closeLbl = makeBtn(card)
    closeLbl.Size = UDim2.fromOffset(300, 28)
    closeLbl.Position = UDim2.fromOffset(20, 358)
    closeLbl.BackgroundTransparency = 1
    closeLbl.Text = T("Закрыть")
    closeLbl.TextSize = 12
    closeLbl.Font = Enum.Font.GothamMedium
    closeLbl.TextColor3 = COLORS.sub
    closeLbl.ZIndex = 62
    closeLbl.Activated:Connect(function() closed = true end)

    while not accessOk and not closed and gui.Parent do
        task.wait(0.05)
    end
    if not accessOk then
        pcall(function() gui:Destroy() end)
        return
    end
    overlay:Destroy()
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
    local logoIcon = label(logo, "F", 20, COLORS.accent, Enum.Font.GothamBold)
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
local ver = label(verChip, "v4.0", 11, COLORS.sub, Enum.Font.GothamMedium)
ver.Size = UDim2.fromScale(1, 1)
ver.TextXAlignment = Enum.TextXAlignment.Center
ver.ZIndex = 4

-- Кнопка сворачивания (tonal icon button)
local collapseBtn = makeBtn(top)
collapseBtn.Size = UDim2.fromOffset(34, 34)
collapseBtn.Position = UDim2.new(1, -86, 0.5, -17)
collapseBtn.BackgroundColor3 = COLORS.item
collapseBtn.Text = ""
collapseBtn.TextSize = 15
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextColor3 = COLORS.text
collapseBtn.ZIndex = 3
corner(collapseBtn, 17)
hoverFx(collapseBtn, COLORS.item, COLORS.highest)

local collapseIcon
local function setCollapseIcon(kind)
    if collapseIcon then collapseIcon:Destroy() end
    collapseIcon = makeIcon(collapseBtn, kind, COLORS.text, 16)
    collapseIcon.Position = UDim2.fromScale(0.5, 0.5)
end
setCollapseIcon("chevdown")

-- Кнопка закрытия (белая filled)
local closeBtn = makeBtn(top)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.Position = UDim2.new(1, -46, 0.5, -17)
closeBtn.BackgroundColor3 = COLORS.accent
closeBtn.Text = ""
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = COLORS.onAccent
closeBtn.ZIndex = 3
corner(closeBtn, 17)
hoverFx(closeBtn, COLORS.accent, COLORS.accent3)
do
    local ci = makeIcon(closeBtn, "close", COLORS.onAccent, 15)
    ci.Position = UDim2.fromScale(0.5, 0.5)
end

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
        setIconColor(t.ic, on and COLORS.accent or COLORS.sub)
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

    local ic = makeIcon(btn, icon, COLORS.sub, 18)
    ic.Position = UDim2.fromOffset(25, 21)

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

makeTab("player", T("ИГРОК"), "player")
makeTab("esp", "ESP", "esp")
makeTab("pz", T("ГОЛОВОЛОМКИ"), "pz")
makeTab("bypass", T("ОБХОД"), "ent")
makeTab("users", T("ЛЮДИ"), "player")
makeTab("link", T("СВЯЗЬ"), "link")

makePage("player")
makePage("esp")
makePage("pz")
makePage("bypass")
makePage("users")
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

    local chevron
    local function drawChevron(open)
        if chevron then chevron:Destroy() end
        chevron = makeIcon(headerBtn, open and "chevdown" or "chevright", COLORS.accent, 16)
        chevron.Position = UDim2.new(1, -24, 0.5, 0)
    end
    drawChevron(defaultOpen)

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
        drawChevron(container.Visible)
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
    local function set(v, silent)
        v = v and true or false
        if v == on then return end
        on = v
        apply(on, false)
        if not silent then callback(on) end
    end
    connect(track.Activated, function() set(not on) end)
    return set
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

    return makeSwitch(row, true, default, callback)
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
local function makeSpeedSlider(text, min, max, default, callback, parent, step)
    parent = parent or content
    step = step or 1
    local decimals = step < 1 and 1 or 0
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
    minus.Text = ""
    minus.TextSize = 16
    minus.Font = Enum.Font.GothamBold
    minus.TextColor3 = COLORS.text
    minus.BackgroundColor3 = COLORS.highest
    minus.ZIndex = 4
    corner(minus, 14)
    hoverFx(minus, COLORS.highest, COLORS.selected)
    do
        local mi = makeIcon(minus, "minus", COLORS.text, 14)
        mi.Position = UDim2.fromScale(0.5, 0.5)
    end

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
    plus.Text = ""
    plus.TextSize = 16
    plus.Font = Enum.Font.GothamBold
    plus.TextColor3 = COLORS.text
    plus.BackgroundColor3 = COLORS.highest
    plus.ZIndex = 4
    corner(plus, 14)
    hoverFx(plus, COLORS.highest, COLORS.selected)
    do
        local pi = makeIcon(plus, "plus", COLORS.text, 14)
        pi.Position = UDim2.fromScale(0.5, 0.5)
    end

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
        v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
        v = tonumber(string.format("%." .. decimals .. "f", v))
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
    connect(minus.Activated, function() setValue(value - step) end)
    connect(plus.Activated, function() setValue(value + step) end)
    connect(box.FocusLost, function()
        local n = tonumber(box.Text)
        if n then setValue(n) else box.Text = tostring(value) end
    end)
end

-- ========= Выбор клавиши (кнопка: нажми и затем нажми нужную клавишу, Esc - отмена) =========
local function makeKeyBind(text, stateKey, parent)
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
    l.Size = UDim2.new(1, -130, 1, 0)
    l.ZIndex = 4

    local btn = makeBtn(row)
    btn.Size = UDim2.fromOffset(92, 30)
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, -14, 0.5, 0)
    btn.BackgroundColor3 = COLORS.highest
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextColor3 = COLORS.accent
    btn.Text = State[stateKey].Name
    btn.ZIndex = 4
    corner(btn, 15)
    hoverFx(btn, COLORS.highest, COLORS.selected)

    connect(btn.Activated, function()
        btn.Text = "..."
        MV.binding = function(code)
            if code then State[stateKey] = code end
            btn.Text = State[stateKey].Name
        end
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
    setCollapseIcon(v and "chevright" or "chevdown")
    if v then
        verChip.Visible = false
    else
        task.delay(0.15, function() if not collapsed then verChip.Visible = true end end)
    end
end

connect(collapseBtn.Activated, function()
    setCollapsed(not collapsed)
end)

-- ========= Уведомления (как достижения: выезжают справа) =========
local notifHolder = Instance.new("Frame")
notifHolder.Name = "Notifications"
notifHolder.AnchorPoint = Vector2.new(1, 0)
notifHolder.Position = UDim2.new(1, -12, 0, 64)
notifHolder.Size = UDim2.fromOffset(270, 0)
notifHolder.AutomaticSize = Enum.AutomaticSize.Y
notifHolder.BackgroundTransparency = 1
notifHolder.Parent = gui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 6)
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifLayout.Parent = notifHolder

local notifOrder = 0
local function notify(text)
    if not State.notifyOn then return end
    notifOrder += 1

    -- обёртка занимает место в списке, карточка внутри выезжает справа
    local slot = Instance.new("Frame")
    slot.Size = UDim2.fromOffset(270, 50)
    slot.BackgroundTransparency = 1
    slot.LayoutOrder = notifOrder
    slot.Parent = notifHolder

    local card = Instance.new("Frame")
    card.Size = UDim2.fromScale(1, 1)
    card.Position = UDim2.fromOffset(300, 0)
    card.BackgroundColor3 = COLORS.bg
    card.BackgroundTransparency = 0.04
    card.BorderSizePixel = 0
    card.Parent = slot
    corner(card, 14)
    stroke(card, COLORS.outline, 0.55, 1)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(30, 30)
    dot.Position = UDim2.fromOffset(10, 10)
    dot.BackgroundColor3 = COLORS.item
    dot.BorderSizePixel = 0
    dot.Parent = card
    corner(dot, 15)
    local mark = label(dot, "F", 14, COLORS.accent, Enum.Font.GothamBold)
    mark.Size = UDim2.fromScale(1, 1)
    mark.TextXAlignment = Enum.TextXAlignment.Center

    local head = label(card, "Fisk Grow", 11, COLORS.sub, Enum.Font.GothamMedium)
    head.Position = UDim2.fromOffset(50, 6)
    head.Size = UDim2.new(1, -58, 0, 14)

    local txt = label(card, text, 13, COLORS.text, Enum.Font.GothamBold)
    txt.Position = UDim2.fromOffset(50, 21)
    txt.Size = UDim2.new(1, -58, 0, 22)
    txt.TextTruncate = Enum.TextTruncate.AtEnd

    TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = UDim2.fromOffset(0, 0) }):Play()

    task.delay(3.2, function()
        if not card.Parent then return end
        local t = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            { Position = UDim2.fromOffset(300, 0) })
        t:Play()
        t.Completed:Connect(function()
            slot:Destroy()
        end)
    end)
end

-- ========= Движение =========
-- Буст скорости + "убрать ускорение", вид от третьего лица, перенос хитбокса (Position Spoof)
State.noAccel = false
State.crouchSpoof = false
State.tpOn, State.tpX, State.tpY, State.tpZ, State.tpWall = false, 1.5, 1, 5, false
State.hbOn = false
State.tpKey, State.hbKey = Enum.KeyCode.T, Enum.KeyCode.B
State.flyOn, State.flySpeed, State.flyKey = false, 20, Enum.KeyCode.F
MV.flyBody = Instance.new("BodyVelocity")
MV.flyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
MV.flyBody.Velocity = Vector3.zero

MV.ready, MV.unloaded = false, false
MV.tpParts, MV.partProps = {}, {}
MV.rayParams = RaycastParams.new()
MV.rayParams.FilterType = Enum.RaycastFilterType.Exclude
MV.lastCrouch, MV.lastFloor, MV.fl, MV.tpWasOn = 0, 0, "", false
MV.hbApplied = false

local HB_DEPTH = 2.346 -- на столько хитбокс уходит под землю (значение из оригинала)

function MV.remotes()
    local rs = game:GetService("ReplicatedStorage")
    return rs:FindFirstChild("RemotesFolder") or rs:FindFirstChild("EntityInfo") or rs:FindFirstChild("Bricks")
end

function MV.floor()
    local ok, v = pcall(function()
        return game:GetService("ReplicatedStorage").GameData.Floor.Value
    end)
    local f = ok and v or ""
    local r = MV.remotes()
    if f == "Hotel" and r and r.Name == "Bricks" then f = "OldHotel" end
    return f
end

function MV.special()
    return MV.fl == "Fools" or MV.fl == "OldHotel"
end

function MV.fireCrouch(v)
    local folder = MV.remotes()
    local r = folder and folder:FindFirstChild("Crouch")
    if r then pcall(function() r:FireServer(v, true) end) end
end

function MV.isCrouching()
    if MV.special() then
        return MV.char and MV.char:GetAttribute("Crouching") or false
    end
    return MV.collisionPart ~= nil and MV.collisionPart.CollisionGroup == "PlayerCrouching"
end

-- Базовая скорость игры (как её считает сама игра) - к ней прибавляется буст
function MV.getSpeed()
    local char, hum = MV.char, MV.hum
    local lm = game:GetService("ReplicatedStorage"):FindFirstChild("LiveModifiers")
    local function has(n) return lm ~= nil and lm:FindFirstChild(n) ~= nil end
    local s = 15
    s += char:GetAttribute("SpeedBoost") or 0
    s += char:GetAttribute("SpeedBoostBehind") or 0
    s += char:GetAttribute("SpeedBoostExtra") or 0
    if MV.fl == "Party" then s += 10 end
    if has("PlayerFast") then s += 3 end
    if has("PlayerFaster") then s += 6 end
    if has("PlayerFastest") then s += 20 end
    if has("PlayerSlow") then s -= 3 end
    if has("PlayerSlowHealth") then s -= 0.075 * (hum.MaxHealth - hum.Health) end
    if MV.isCrouching() then
        if has("PlayerCrouchSlow") then s -= 8
        elseif has("PlayerSlow") then s -= 8
        else s -= 5 end
    end
    return s
end

-- "Убрать ускорение": тяжёлые физ. свойства, персонаж не скользит
function MV.applyAccel(on)
    for part, old in pairs(MV.partProps) do
        if part.Parent then
            pcall(function()
                local restore = old ~= false and old or nil
                part.CustomPhysicalProperties = on and MV.customPhysics or restore
            end)
        end
    end
end

-- Направление полёта: куда смотрит камера (с наклоном вверх/вниз) + стрелки движения
function MV.flyDir(cam)
    local md = MV.hum.MoveDirection
    if md == Vector3.zero or not cam then return Vector3.zero end
    local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
    local flat = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + look)
    local v = (cam.CFrame * CFrame.new(flat:VectorToObjectSpace(md))).Position - cam.CFrame.Position
    if v == Vector3.zero then return v end
    return v.Unit
end

-- ---- Перенос хитбокса (Position Spoof) ----
function MV.hbEnable()
    if MV.hbApplied or not MV.ready then return end
    if MV.special() then
        notify(T("Перенос хитбокса не работает на этом этаже"))
        if MV.uiHB then MV.uiHB(false) end
        return
    end
    local c, cp = MV.collision, MV.collisionPart
    if not (c and cp) then
        if MV.uiHB then MV.uiHB(false) end
        return
    end
    MV.hbApplied = true
    local cc = c:FindFirstChild("CollisionCrouch")
    MV.orig = { col = c.CanCollide, ccrouch = cc and cc.CanCollide, root = MV.root.CanCollide }
    local ok = pcall(function()
        MV.cclone = c:Clone()
        MV.cclone.Name = "CollisionClone"
        MV.cclone.Massless = true
        MV.cclone.Parent = MV.char
        MV.cpclone = cp:Clone()
        MV.cpclone.Name = "CollisionPartClone"
        MV.cpclone.CanCollide = false
        MV.cpclone.Massless = true
        MV.cpclone.Parent = MV.char
        local x = MV.cpclone:FindFirstChild("CollisionCrouch")
        if x then x:Destroy() end
    end)
    if not ok or not MV.cclone then
        MV.hbApplied = false
        if MV.cclone then MV.cclone:Destroy() MV.cclone = nil end
        if MV.cpclone then MV.cpclone:Destroy() MV.cpclone = nil end
        if MV.uiHB then MV.uiHB(false) end
        return
    end
    MV.root.CFrame = MV.root.CFrame * CFrame.new(0, -HB_DEPTH, 0)
    MV.hum.HipHeight = 0.05
    MV.fireCrouch(true)
end

function MV.hbDisable()
    if not MV.hbApplied then return end
    MV.hbApplied = false
    local root, hum, c, cp = MV.root, MV.hum, MV.collision, MV.collisionPart
    if root and root.Parent then
        root.CFrame = root.CFrame * CFrame.new(0, HB_DEPTH, 0)
        if c and c.Parent then
            local rp = root.Position
            c.Position = rp + Vector3.new(0, 0.18, 0)
            if cp and cp.Parent then cp.Position = rp + Vector3.new(0, 0.18, 0) end
            local cc = c:FindFirstChild("CollisionCrouch")
            if cc then cc.Position = rp + Vector3.new(0, -0.982, 0) end
            if MV.orig then
                c.CanCollide = MV.orig.col
                if cc and MV.orig.ccrouch ~= nil then cc.CanCollide = MV.orig.ccrouch end
            end
        end
        if MV.orig then root.CanCollide = MV.orig.root end
        local ls = MV.char and MV.char:FindFirstChild("LowerTorso")
        local rj = ls and ls:FindFirstChild("Root")
        if rj and MV.originalC1 then rj.C1 = MV.originalC1 end
    end
    if hum and hum.Parent then hum.HipHeight = 2.396 end
    if MV.cclone then MV.cclone:Destroy() MV.cclone = nil end
    if MV.cpclone then MV.cpclone:Destroy() MV.cpclone = nil end
    MV.fireCrouch(MV.isCrouching())
end

function MV.hbStep(cam)
    local char, root, c, cp, cclone = MV.char, MV.root, MV.collision, MV.collisionPart, MV.cclone
    if not (cclone and cclone.Parent and c and c.Parent) then return end

    if not (cam and cam:FindFirstChild("MinecartRig")) then root.CanCollide = false end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    c.CanCollide = false
    local ccrouch = c:FindFirstChild("CollisionCrouch")
    if ccrouch then ccrouch.CanCollide = false end
    local clcrouch = cclone:FindFirstChild("CollisionCrouch")
    if clcrouch then
        local crouch = MV.isCrouching()
        cclone.CanCollide = not crouch
        clcrouch.CanCollide = crouch and true or false
    else
        root.CanCollide = true
    end

    local ls = char:FindFirstChild("LowerTorso")
    local rj = ls and ls:FindFirstChild("Root")
    if rj and MV.originalC1 then rj.C1 = MV.originalC1 * CFrame.new(0, -HB_DEPTH, 0) end

    local pos = root.Position
    c.Position = pos + Vector3.new(0, 2.328, 0)
    if cp then cp.Position = pos + Vector3.new(0, 2.328, 0) end
    if ccrouch and clcrouch then
        ccrouch.Position = pos + Vector3.new(0, 1.328, 0)
        clcrouch.CollisionGroup = ccrouch.CollisionGroup
    end
    if clcrouch then clcrouch.Position = pos + Vector3.new(0, 0.75, 0) end
    cclone.CollisionGroup = c.CollisionGroup
    cclone.Position = pos + Vector3.new(0, 1.75, 0)
end

-- ---- Персонаж ----
function MV.setup(char)
    MV.ready = false
    MV.char, MV.hum, MV.root = char, nil, nil
    MV.collision, MV.collisionPart, MV.cclone, MV.cpclone = nil, nil, nil, nil
    MV.hbApplied, MV.originalC1 = false, nil
    MV.flyBody.Parent = nil
    MV.tpParts, MV.partProps = {}, {}
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 15)
        local root = char:WaitForChild("HumanoidRootPart", 15)
        if not hum or not root or MV.char ~= char then return end
        MV.hum, MV.root = hum, root
        MV.fl = MV.floor()
        MV.collision = char:WaitForChild("Collision", 8)
        MV.collisionPart = char:FindFirstChild("CollisionPart") or MV.collision

        local ls = char:FindFirstChild("LowerTorso")
        local rj = ls and ls:FindFirstChild("Root")
        MV.originalC1 = rj and rj.C1 or nil

        for _, o in ipairs(char:GetDescendants()) do
            if o:IsA("Accessory") and o:FindFirstChild("Handle") then
                table.insert(MV.tpParts, o.Handle)
            end
        end
        local head = char:WaitForChild("Head", 5)
        if head then table.insert(MV.tpParts, head) end

        for _, n in ipairs({ "SpeedBoost", "SpeedBoostBehind", "SpeedBoostExtra" }) do
            if char:GetAttribute(n) == nil then char:SetAttribute(n, 0) end
        end

        local base = root.CustomPhysicalProperties or PhysicalProperties.new(Enum.Material.Plastic)
        MV.customPhysics = PhysicalProperties.new(100, base.Friction, base.Elasticity, base.FrictionWeight, base.ElasticityWeight)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                MV.partProps[part] = part.CustomPhysicalProperties or false
            end
        end
        if State.noAccel then MV.applyAccel(true) end

        MV.ready = true
        if State.hbOn then
            task.wait(1)
            if MV.char == char then MV.hbEnable() end
        end
    end)
end

function MV.step()
    if MV.unloaded or not MV.ready then return end
    local char, hum, root = MV.char, MV.hum, MV.root
    if not (char and char.Parent and hum and hum.Parent and root and root.Parent) then return end
    if hum.Health <= 0 then return end
    local cam = workspace.CurrentCamera

    if tick() - MV.lastFloor > 1 then
        MV.lastFloor = tick()
        MV.fl = MV.floor()
    end

    -- Буст скорости: база игры + ползунок
    if State.speedOn then
        hum.WalkSpeed = MV.getSpeed() + State.speed
    end

    -- Перенос хитбокса
    if MV.hbApplied then MV.hbStep(cam) end

    -- Сообщаем серверу состояние приседания (как в оригинале)
    if (State.speedOn or State.hbOn or State.crouchSpoof) and tick() - MV.lastCrouch > 0.1 then
        MV.lastCrouch = tick()
        local crouch = MV.isCrouching()
        if State.crouchSpoof or State.hbOn then crouch = true end
        MV.fireCrouch(crouch)
    end

    -- Полёт
    if State.flyOn then
        MV.flyBody.Parent = root
        MV.flyBody.Velocity = MV.flyDir(cam) * State.flySpeed
    elseif MV.flyBody.Parent then
        MV.flyBody.Parent = nil
    end

    -- Вид от третьего лица
    if cam then
        if State.tpOn then
            local off = CFrame.new(State.tpX, State.tpY, State.tpZ)
            local moved = false
            if State.tpWall then
                MV.rayParams.FilterDescendantsInstances = { char }
                local dir = (cam.CFrame * off).Position - cam.CFrame.Position
                if dir.Magnitude > 0 then
                    local res = workspace:Spherecast(cam.CFrame.Position, 0.2, dir, MV.rayParams)
                    if res and res.Instance.CanCollide then
                        local np = cam.CFrame.Position + dir.Unit * res.Distance
                        cam.CFrame = CFrame.new(np, np + cam.CFrame.LookVector)
                        moved = true
                    end
                end
            end
            if not moved then cam.CFrame = cam.CFrame * off end
        end
        if State.tpOn or MV.tpWasOn then
            local t = State.tpOn and 0 or 1
            for _, part in ipairs(MV.tpParts) do
                if part.Parent then
                    part.Transparency = t
                    part.LocalTransparencyModifier = t
                end
            end
        end
        MV.tpWasOn = State.tpOn
    end
end

function MV.unload()
    MV.unloaded = true
    if MV.onUnload then pcall(MV.onUnload) end
    pcall(MV.hbDisable)
    pcall(function() MV.flyBody:Destroy() end)
    pcall(MV.applyAccel, false)
    pcall(function()
        if MV.hum and MV.hum.Parent then MV.hum.WalkSpeed = MV.getSpeed() end
    end)
    pcall(function()
        for _, part in ipairs(MV.tpParts) do
            part.Transparency = 1
            part.LocalTransparencyModifier = 1
        end
    end)
end

-- Хук Crouch (как в оригинале: второй аргумент всегда true, при спуфе - приседание всегда)
pcall(function()
    local hm, nc, gn = hookmetamethod, newcclosure, getnamecallmethod
    if type(hm) == "function" and type(nc) == "function" and type(gn) == "function" then
        local old
        old = hm(game, "__namecall", nc(function(self, ...)
            if not MV.unloaded then
                local method = gn()
                if method == "FireServer" and typeof(self) == "Instance" then
                    local nm = self.Name
                    if nm == "Crouch" then
                        local a1 = ...
                        if State.crouchSpoof or State.hbOn then a1 = true end
                        return old(self, a1, true, select(3, ...))
                    elseif nm == "MotorReplication" and MV.eyesActive then
                        if MV.special() then return old(self, 0, -65, 0, false) end
                        return old(self, -650)
                    end
                end
            end
            return old(self, ...)
        end))
    end
end)

connect(RunService.RenderStepped, function()
    local ok, err = pcall(MV.step)
    if not ok and not MV.warned then
        MV.warned = true
        warn("[FiskGrow] MV.step: " .. tostring(err))
    end
end)

connect(lp.CharacterAdded, MV.setup)
if lp.Character then MV.setup(lp.Character) end

-- Горячие клавиши + назначение клавиш из меню
connect(UIS.InputBegan, function(i, gpe)
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if MV.binding then
        local cb = MV.binding
        MV.binding = nil
        cb(i.KeyCode ~= Enum.KeyCode.Escape and i.KeyCode or nil)
        return
    end
    if gpe then return end
    if i.KeyCode == State.tpKey and MV.uiTP then MV.uiTP(not State.tpOn) end
    if i.KeyCode == State.hbKey and MV.uiHB then MV.uiHB(not State.hbOn) end
    if i.KeyCode == State.flyKey and MV.uiFly then MV.uiFly(not State.flyOn) end
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
    tl.Text = T("ДВЕРЬ ") .. tostring((tonumber(num) or 0) + 1)
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
    if notifySpawn and live and State.notifyOn then notify(T(displayName) .. T(" появился!")) end

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
        tl.Text = T(displayName)
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

    -- детали внутри уже найденной сущности (Screech и т.п.) - не отдельные ESP
    if hasAncestor(inst, isEntityModel) then return end

    local n = inst.Name:lower()
    local inRooms = inst:FindFirstAncestor("CurrentRooms") ~= nil

    -- глаза на стенах у Seek и прочий декор Seek внутри комнат - игнорируем
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
            doorState.tl.Text = string.format(T("ДВЕРЬ %d [%dm]"), doorState.num, dist)
        end
        for _, t in pairs(tracked) do
            if t.hl then
                t.hl.Enabled = State.espOn
                t.bb.Enabled = State.espOn
                if root and t.part and t.part.Parent then
                    local dist = (t.part.Position - root.Position).Magnitude
                    t.tl.Text = string.format("[%s] %s [%dm]", t.floor, T(t.name), dist)
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
        key = T("Ключ"), skeletonkey = T("Скелетный ключ"), lighter = T("Зажигалка"), lockpicks = T("Отмычки"),
        vitamins = T("Витамины"), flashlight = T("Фонарик"), battery = T("Батарейка"), bandage = T("Бинт"),
        candle = T("Свеча"), crucifix = T("Распятие"), smoothie = T("Смузи"), compass = T("Компас"),
        shears = T("Ножницы"), goldpile = T("Золото"), gold = T("Золото"), glowsticks = T("Светящиеся палочки"),
        holygrenade = T("Святая граната"), guidinglight = T("Путеводный свет"), straplight = T("Налобный фонарь"),
        bulklight = T("Лампа"), firstaid = T("Аптечка"), lockpick = T("Отмычка"),
    }

    local WORD_RU = {
        livehintbook = T("КНИГА-ПОДСКАЗКА"), hintbook = T("КНИГА-ПОДСКАЗКА"), hintpaper = T("ПОДСКАЗКА"),
        libraryhint = T("ПОДСКАЗКА"), padlock = T("ЗАМОК"),
        lever = T("РЫЧАГ"), switch = T("ПЕРЕКЛЮЧАТЕЛЬ"), button = T("КНОПКА"), furnace = T("ПЕЧЬ - СЖЕЧЬ"),
        incinerat = T("ПЕЧЬ - СЖЕЧЬ"), burn = T("СЖЕЧЬ"), fireplace = T("КАМИН"),
        generator = T("ГЕНЕРАТОР"), lamp = T("ЛАМПОЧКА"), bulb = T("ЛАМПОЧКА"), fuse = T("ПРЕДОХРАНИТЕЛЬ"),
        valve = T("ВЕНТИЛЬ"), breaker = T("РУБИЛЬНИК"), cable = T("КАБЕЛЬ"), wire = T("ПРОВОД"),
        gear = T("ШЕСТЕРНЯ"), wheel = T("КОЛЕСО"), pipe = T("ТРУБА"),
        drawer = T("ТУМБА"), chest = T("СУНДУК"), dresser = T("КОМОД"), nightstand = T("ТУМБОЧКА"),
        toolbox = T("ЯЩИК"), shelf = T("ПОЛКА"), crate = T("ЯЩИК"), cabinet = T("ШКАФ"), cupboard = T("ШКАФ"),
        locker = T("ШКАФЧИК"), toolshed = T("ЯЩИК С ИНСТР."),
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
            text = T("ЗАМОК")
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
                            if e.word == "padlock" then e.text = T("ЗАМОК: ") .. text end
                        end
                        if text ~= lastCode then
                            lastCode = text
                            if known and known > 0 then notify(T("Код библиотеки: ") .. text) end
                        end
                    elseif PZ.codeLabel then
                        PZ.codeLabel.Text = T("нет бумаги-подсказки")
                    end
                end
            end
            task.wait(0.3)
        end
    end)
end

-- ========= Seek =========
-- Маршрут и стрелки на Seek удалены. Оставлено только определение погони (нужно для диагностики).
local SK = {}
do
    local seekModels = {}
    local function trackSeek(inst)
        if inst:IsA("Model") and (inst.Name == "SeekMoving" or inst.Name == "SeekMovingNewClone")
            and not seekModels[inst] then
            seekModels[inst] = true
            inst.AncestryChanged:Connect(function(_, parent)
                if not parent then seekModels[inst] = nil end
            end)
        end
    end
    task.spawn(function()
        for _, d in ipairs(workspace:GetDescendants()) do trackSeek(d) end
    end)
    connect(workspace.DescendantAdded, trackSeek)

    function SK.chaseActive()
        for m in pairs(seekModels) do
            if m.Parent then return true end
            seekModels[m] = nil
        end
        return false
    end

    function SK.clear() end
end

-- ========= Предупреждение Screech: куда поворачиваться =========
State.screechWarn = true
do
    local models = {}
    local function trackScreech(inst)
        if inst:IsA("Model") and inst.Name == "Screech" and not models[inst] then
            models[inst] = true
            inst.AncestryChanged:Connect(function(_, parent)
                if not parent then models[inst] = nil end
            end)
        end
    end
    task.spawn(function()
        for _, d in ipairs(workspace:GetDescendants()) do trackScreech(d) end
    end)
    connect(workspace.DescendantAdded, trackScreech)

    -- индикатор: кольцо по центру экрана, указатель смотрит на Screech
    local holder = Instance.new("Frame")
    holder.Name = "ScreechWarn"
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.42)
    holder.Size = UDim2.fromOffset(240, 240)
    holder.BackgroundTransparency = 1
    holder.Visible = false
    holder.ZIndex = 50
    holder.Parent = gui

    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.5)
    ring.Size = UDim2.fromOffset(190, 190)
    ring.BackgroundTransparency = 1
    ring.ZIndex = 50
    ring.Parent = holder
    corner(ring, 95)
    local ringStroke = stroke(ring, COLORS.outline, 0.6, 2)

    local pointerBox = Instance.new("Frame")
    pointerBox.AnchorPoint = Vector2.new(0.5, 0.5)
    pointerBox.Position = UDim2.fromScale(0.5, 0.5)
    pointerBox.Size = UDim2.fromOffset(190, 190)
    pointerBox.BackgroundTransparency = 1
    pointerBox.ZIndex = 51
    pointerBox.Parent = holder

    local pointer = Instance.new("Frame")
    pointer.AnchorPoint = Vector2.new(0.5, 0.5)
    pointer.Position = UDim2.fromScale(0.5, 0)
    pointer.Size = UDim2.fromOffset(26, 26)
    pointer.Rotation = 45
    pointer.BackgroundColor3 = COLORS.danger
    pointer.BorderSizePixel = 0
    pointer.ZIndex = 52
    pointer.Parent = pointerBox
    corner(pointer, 6)

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(150, 52)
    card.BackgroundColor3 = COLORS.bg
    card.BackgroundTransparency = 0.08
    card.BorderSizePixel = 0
    card.ZIndex = 52
    card.Parent = holder
    corner(card, 14)
    stroke(card, COLORS.outline, 0.55, 1)

    local head = label(card, "", 11, COLORS.sub, Enum.Font.GothamMedium)
    head.Position = UDim2.fromOffset(0, 6)
    head.Size = UDim2.new(1, 0, 0, 14)
    head.TextXAlignment = Enum.TextXAlignment.Center
    head.ZIndex = 53
    local msg = label(card, "", 13, COLORS.text, Enum.Font.GothamBold)
    msg.Position = UDim2.fromOffset(0, 22)
    msg.Size = UDim2.new(1, 0, 0, 22)
    msg.TextXAlignment = Enum.TextXAlignment.Center
    msg.ZIndex = 53

    connect(RunService.RenderStepped, function()
        local cam = workspace.CurrentCamera
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local target, best = nil, 80
        if State.screechWarn and cam and root then
            for m in pairs(models) do
                local part = m.Parent and getPart(m)
                if part then
                    local d = (part.Position - root.Position).Magnitude
                    if d < best then target, best = part, d end
                end
            end
        end
        if not target then
            holder.Visible = false
            return
        end
        holder.Visible = true

        local look = cam.CFrame.LookVector
        local to = target.Position - cam.CFrame.Position
        local a1 = math.atan2(look.X, look.Z)
        local a2 = math.atan2(to.X, to.Z)
        -- угол от направления взгляда: >0 вправо, <0 влево
        local diff = math.deg(a1 - a2)
        diff = (diff + 180) % 360 - 180
        pointerBox.Rotation = diff

        local abs = math.abs(diff)
        head.Text = T("СКРИПУН") .. string.format(" [%dm]", best)
        if abs < 25 then
            msg.Text = T("СМОТРИ НА НЕГО")
            pointer.BackgroundColor3 = COLORS.door
            ringStroke.Color = COLORS.door
        else
            pointer.BackgroundColor3 = COLORS.danger
            ringStroke.Color = COLORS.danger
            if abs > 135 then
                msg.Text = T("ПОВЕРНИСЬ НАЗАД")
            elseif diff > 0 then
                msg.Text = T("ПОВЕРНИСЬ НАПРАВО")
            else
                msg.Text = T("ПОВЕРНИСЬ НАЛЕВО")
            end
        end
    end)
end

-- ========= Диагностика Seek: что появляется в workspace во время погони =========
State.seekDiag = false
local DIAG = { lines = {}, seenKey = {}, conn = nil }

function DIAG.start()
    DIAG.lines, DIAG.seenKey = {}, {}
    if DIAG.conn then DIAG.conn:Disconnect() end
    DIAG.conn = workspace.DescendantAdded:Connect(function(inst)
        if not (State.seekDiag and SK.chaseActive and SK.chaseActive()) then return end
        local cam = workspace.CurrentCamera
        if (cam and inst:IsDescendantOf(cam)) or inst:IsDescendantOf(gui) then return end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character and inst:IsDescendantOf(pl.Character) then return end
        end
        if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
        local key = inst.Name .. "|" .. inst.ClassName .. "|" .. (inst.Parent and inst.Parent.Name or "?")
        if DIAG.seenKey[key] or #DIAG.lines > 400 then return end
        DIAG.seenKey[key] = true
        local pos = ""
        pcall(function()
            local p = inst:IsA("Model") and inst:GetPivot().Position or inst.Position
            pos = string.format(" @ %.0f, %.0f, %.0f", p.X, p.Y, p.Z)
        end)
        DIAG.lines[#DIAG.lines + 1] = inst.ClassName .. " | " .. inst:GetFullName() .. pos
    end)
    table.insert(connections, DIAG.conn)
end

function DIAG.stop()
    if DIAG.conn then DIAG.conn:Disconnect() DIAG.conn = nil end
    local text = table.concat(DIAG.lines, "\n")
    print("[FiskGrow Seek diag] " .. #DIAG.lines .. " lines\n" .. text)
    pcall(function() setclipboard(text) end)
end

-- ========= Обход сущностей: удаление, отключение урона, обходы =========
State.bp = {}
local BP = {}

do
    local Rep = game:GetService("ReplicatedStorage")
    local bpState = State.bp

    -- ---------- Подмена ремоутов (отключение урона) ----------
    local REMOTE_NAME = { NoScreech = "Screech", NoHalt = "ShadeResult", NoA90 = "A90", NoSurge = "SurgeRemote" }
    local fakeRemotes, realRemotes, remoteApplied = {}, {}, {}

    local function swapRemote(key, on)
        local folder = MV.remotes()
        if not folder then return end
        local name = REMOTE_NAME[key]
        if on then
            if remoteApplied[key] then return end
            local real = realRemotes[key] or folder:FindFirstChild(name)
            if not real then return end -- на этом этаже такого ремоута нет, повторим позже
            realRemotes[key] = real
            local fake = fakeRemotes[key]
            if not fake then
                fake = Instance.new("RemoteEvent")
                fake.Name = name
                fakeRemotes[key] = fake
            end
            fake.Parent = folder
            real.Parent = nil
            remoteApplied[key] = true
        else
            if not remoteApplied[key] then return end
            remoteApplied[key] = nil
            local real, fake = realRemotes[key], fakeRemotes[key]
            if real then real.Parent = folder end
            if fake then fake.Parent = nil end
        end
    end

    -- ---------- Удаление сущностей (отключаем их клиентские модули) ----------
    local MODULE_KEYS = { RemoveScreech = "Screech", RemoveHalt = "Shade", RemoveA90 = "A90", RemoveDread = "Dread" }

    local function findModule(orig)
        local container
        if orig == "Shade" then
            local mc = Rep:FindFirstChild("ModulesClient") or Rep:FindFirstChild("ClientModules")
            container = mc and mc:FindFirstChild("EntityModules")
        else
            local ui = lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("MainUI")
            local init = ui and ui:FindFirstChild("Initiator")
            local mg = init and init:FindFirstChild("Main_Game")
            local rl = mg and mg:FindFirstChild("RemoteListener")
            container = rl and rl:FindFirstChild("Modules")
        end
        if not container then return nil end
        return container:FindFirstChild(orig) or container:FindFirstChild(orig .. "_Disabled")
    end

    local function applyModules(force)
        for key, orig in pairs(MODULE_KEYS) do
            if bpState[key] or force then
                local m = findModule(orig)
                if m then m.Name = bpState[key] and (orig .. "_Disabled") or orig end
            end
        end
    end

    local function applySurge(force)
        if not (bpState.RemoveSurge or force) then return end
        local ui = lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("MainUI")
        local mf = ui and ui:FindFirstChild("MainFrame")
        local f = mf and (mf:FindFirstChild("SurgeVignette") or mf:FindFirstChild("SurgeVignette_Disabled"))
        if f then f.Name = bpState.RemoveSurge and "SurgeVignette_Disabled" or "SurgeVignette" end
    end

    local function applyGlitchScreech(force)
        local fr = Rep:FindFirstChild("FloorReplicated")
        if not fr then return end
        for _, o in ipairs(fr:GetDescendants()) do
            if o.Name == "GlitchScreech" and bpState.RemoveScreech then
                o.Name = "GlitchScreech_Disabled"
            elseif o.Name == "GlitchScreech_Disabled" and not bpState.RemoveScreech then
                o.Name = "GlitchScreech"
            end
        end
    end
    do
        local fr = Rep:FindFirstChild("FloorReplicated")
        if fr then
            connect(fr.DescendantAdded, function(o)
                if o.Name == "GlitchScreech" and bpState.RemoveScreech then o.Name = "GlitchScreech_Disabled" end
            end)
        end
    end

    -- ---------- Обходы (отключаем касания/коллизии опасных объектов) ----------
    local function eachPart(o, f)
        for _, p in ipairs(o:GetDescendants()) do
            if p:IsA("BasePart") then f(p) end
        end
    end

    local bridges = {}
    local hooked = setmetatable({}, { __mode = "k" })
    local function once(o, tag, fn)
        hooked[o] = hooked[o] or {}
        if not hooked[o][tag] then
            hooked[o][tag] = true
            fn()
        end
    end

    local APPLY = {}
    APPLY.Giggle = function(o, on)
        local h = o:WaitForChild("Hitbox", 5)
        if h then h.CanTouch = not on end
    end
    APPLY.Dupe = function(o, on)
        local h = o:WaitForChild("Hidden", 5)
        if h then h.CanTouch = not on end
        local lock = o:FindFirstChild("Lock")
        local pr = lock and lock:FindFirstChild("UnlockPrompt")
        if pr then pr.Enabled = not on end
    end
    APPLY.Gloom = function(o, on)
        eachPart(o, function(p) p.CanTouch = not on end)
        once(o, "da", function()
            connect(o.DescendantAdded, function(p)
                if p:IsA("BasePart") and bpState.Gloom then p.CanTouch = false end
            end)
        end)
    end
    APPLY.Vacuum = function(o, on)
        local c = o:WaitForChild("Collision", 5)
        if c then
            c.CanCollide = on
            c.CanTouch = not on
        end
    end
    APPLY.Snare = function(o, on)
        eachPart(o, function(p) p.CanTouch = not on end)
        once(o, "da", function()
            connect(o.DescendantAdded, function(p)
                if p:IsA("BasePart") then p.CanTouch = not bpState.Snare end
            end)
        end)
    end
    APPLY.SeekArm = function(o, on)
        eachPart(o, function(p) p.CanTouch = not on end)
    end
    APPLY.SeekFlood = function(o, on)
        o.CanCollide = on
        once(o, "cc", function()
            connect(o:GetPropertyChangedSignal("CanCollide"), function()
                if bpState.Seek and not o.CanCollide then o.CanCollide = true end
            end)
        end)
    end
    APPLY.SeekBridge = function(o, on)
        bridges[o] = bridges[o] or {}
        if on and #bridges[o] == 0 then
            for _, child in ipairs(o:GetChildren()) do
                if child.Name == "PlayerBarrier" and child:IsA("BasePart") and child.Size.Y == 2.75
                    and (child.Rotation.X == 0 or child.Rotation.X == 180) then
                    local nb = child:Clone()
                    nb.CFrame = nb.CFrame * CFrame.new(0, 0, -5)
                    nb.Name = "B" .. math.random(100000, 999999)
                    nb.Size = Vector3.new(nb.Size.X, nb.Size.Y, 11)
                    nb.Color = Color3.fromRGB(0, 255, 255)
                    nb.Material = Enum.Material.ForceField
                    nb.Parent = o
                    table.insert(bridges[o], nb)
                end
            end
        end
        for _, b in ipairs(bridges[o]) do
            if b.Parent then
                b.CanCollide = on
                b.Transparency = on and 0 or 1
            end
        end
    end
    APPLY.Lava = function(o, on) o.CanTouch = not on end
    APPLY.Wall = function(o, on)
        eachPart(o, function(p)
            p.CanTouch = not on
            p.CanCollide = not on
            once(p, "sig", function()
                connect(p:GetPropertyChangedSignal("CanTouch"), function()
                    if bpState.Wall and p.CanTouch then p.CanTouch = false end
                end)
                connect(p:GetPropertyChangedSignal("CanCollide"), function()
                    if bpState.Wall and p.CanCollide then p.CanCollide = false end
                end)
            end)
        end)
    end
    APPLY.Banana = function(o, on) o.CanTouch = not on end
    APPLY.Jeff = function(o, on)
        eachPart(o, function(p)
            p.CanCollide = not on
            p.CanTouch = not on
        end)
        if on then
            local hum = o:WaitForChild("Humanoid", 5)
            if hum then hum.Health = 0 end
        end
    end

    -- имя объекта -> { ключ тумблера, функция }
    local RULES = {
        GiggleCeiling = { "Giggle", APPLY.Giggle },
        DoorFake = { "Dupe", APPLY.Dupe },
        FakeDoor = { "Dupe", APPLY.Dupe },
        GloomPile = { "Gloom", APPLY.Gloom },
        SideroomSpace = { "Vacuum", APPLY.Vacuum },
        Snare = { "Snare", APPLY.Snare },
        Seek_Arm = { "Seek", APPLY.SeekArm },
        ChandelierObstruction = { "Seek", APPLY.SeekArm },
        SeekFloodline = { "Seek", APPLY.SeekFlood },
        Bridge = { "Seek", APPLY.SeekBridge },
        Lava = { "Lava", APPLY.Lava },
        ScaryWall = { "Wall", APPLY.Wall },
        BananaPeel = { "Banana", APPLY.Banana },
        JeffTheKiller = { "Jeff", APPLY.Jeff },
    }

    local registry = setmetatable({}, { __mode = "k" }) -- объект -> правило
    local touched = setmetatable({}, { __mode = "k" })  -- объекты, которые мы уже меняли

    local function run(o, rule, on)
        if on then touched[o] = true
        elseif not touched[o] then return end
        pcall(rule[2], o, on)
    end

    local function handle(o)
        local rule = RULES[o.Name]
        if not rule or registry[o] then return end
        registry[o] = rule
        if bpState[rule[1]] then task.spawn(run, o, rule, true) end
    end

    local function setObjects(key, v)
        for o, rule in pairs(registry) do
            if rule[1] == key and o.Parent then task.spawn(run, o, rule, v) end
        end
    end

    task.spawn(function()
        local rooms = workspace:WaitForChild("CurrentRooms", 60)
        if not rooms or MV.unloaded then return end
        connect(rooms.DescendantAdded, handle)
        local n = 0
        for _, d in ipairs(rooms:GetDescendants()) do
            handle(d)
            n += 1
            if n % 400 == 0 then task.wait() end
        end
    end)

    -- ---------- Eyes / Lookman: сообщаем серверу, что мы смотрим вниз ----------
    connect(RunService.RenderStepped, function()
        if MV.unloaded then return end
        local isEyes = workspace:FindFirstChild("Eyes") ~= nil or workspace:FindFirstChild("Lookman") ~= nil
        local isLook = workspace:FindFirstChild("BackdoorLookman") ~= nil
        local active = (bpState.Eyes and isEyes) or (bpState.Lookman and isLook) or false
        MV.eyesActive = active
        if active then
            local folder = MV.remotes()
            local r = folder and folder:FindFirstChild("MotorReplication")
            if r then
                if MV.special() then pcall(function() r:FireServer(0, -65, 0, false) end)
                else pcall(function() r:FireServer(-650) end) end
            end
        end
        if bpState.RemoveScreech then
            local cam = workspace.CurrentCamera
            local sc = cam and cam:FindFirstChild("Screech")
            if sc then sc:Destroy() end
        end
    end)

    -- ---------- Включение / выключение ----------
    local OBJ_KEYS = { Giggle = true, Dupe = true, Gloom = true, Vacuum = true, Snare = true, Seek = true,
        Lava = true, Wall = true, Banana = true, Jeff = true }

    function BP.set(key, v)
        v = v and true or false
        bpState[key] = v
        if MODULE_KEYS[key] then
            applyModules(true)
            if key == "RemoveScreech" then applyGlitchScreech() end
        elseif key == "RemoveSurge" then
            applySurge(true)
        elseif REMOTE_NAME[key] then
            swapRemote(key, v)
        elseif OBJ_KEYS[key] then
            setObjects(key, v)
        end
    end

    -- повторяем попытки: ремоуты/модули появляются не сразу и пересоздаются при респавне
    task.spawn(function()
        while gui.Parent and not MV.unloaded do
            pcall(applyModules, false)
            pcall(applySurge, false)
            for key in pairs(REMOTE_NAME) do
                if bpState[key] and not remoteApplied[key] then pcall(swapRemote, key, true) end
            end
            task.wait(1)
        end
    end)

    MV.onUnload = function()
        MV.eyesActive = false
        for key in pairs(REMOTE_NAME) do pcall(swapRemote, key, false) end
        for key in pairs(MODULE_KEYS) do bpState[key] = false end
        bpState.RemoveSurge = false
        pcall(applyModules, true)
        pcall(applySurge, true)
        pcall(applyGlitchScreech)
        for key in pairs(OBJ_KEYS) do bpState[key] = false end
        for o, rule in pairs(registry) do
            if o.Parent then pcall(run, o, rule, false) end
        end
        for _, list in pairs(bridges) do
            for _, b in ipairs(list) do pcall(function() b:Destroy() end) end
        end
        bridges = {}
    end

    -- ---------- Меню ----------
    local function tg(sec, text, key)
        makeToggle(T(text), false, function(v) BP.set(key, v) end, sec)
    end

    local secRemove = makeSection(T("УДАЛЕНИЕ СУЩНОСТЕЙ"), true, pages.bypass)
    tg(secRemove, "Удалить Screech", "RemoveScreech")
    tg(secRemove, "Удалить Halt", "RemoveHalt")
    tg(secRemove, "Удалить A-90", "RemoveA90")
    tg(secRemove, "Удалить Dread", "RemoveDread")
    tg(secRemove, "Удалить Surge", "RemoveSurge")

    local secDmg = makeSection(T("БЕЗ УРОНА"), false, pages.bypass)
    tg(secDmg, "Без урона от Screech", "NoScreech")
    tg(secDmg, "Без урона от Halt", "NoHalt")
    tg(secDmg, "Без урона от A-90", "NoA90")
    tg(secDmg, "Без урона от Surge", "NoSurge")

    local secBp = makeSection(T("ОБХОД"), false, pages.bypass)
    tg(secBp, "Обход Giggle", "Giggle")
    tg(secBp, "Обход Dupe (фейковые двери)", "Dupe")
    tg(secBp, "Обход Eyes", "Eyes")
    tg(secBp, "Обход Lookman", "Lookman")
    tg(secBp, "Обход яиц Gloombat", "Gloom")
    tg(secBp, "Обход преград Seek", "Seek")
    tg(secBp, "Обход Vacuum", "Vacuum")
    tg(secBp, "Обход лавы", "Lava")
    tg(secBp, "Обход Seeking Wall", "Wall")
    tg(secBp, "Обход Snare", "Snare")
    tg(secBp, "Обход банана", "Banana")
    tg(secBp, "Обход Jeff", "Jeff")
end

-- ========= Люди: кто ещё использует скрипт (через сервер бота) =========
-- Впиши сюда адрес своего приложения на Vercel, например: "https://my-bot.vercel.app/api/fisk"
local FISK_API = ""

State.shareMe = true
State.tagUsers = true

do
    local HttpService = game:GetService("HttpService")
    local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
    local users, tags, known = {}, {}, {}
    local onlineTotal = 0
    local statusLbl, listBox

    local function fetch(action)
        local url = string.format("%s?action=%s&uid=%d&name=%s&job=%s&place=%d",
            FISK_API, action, lp.UserId, HttpService:UrlEncode(lp.Name),
            HttpService:UrlEncode(game.JobId), game.PlaceId)
        local body
        if reqFn then
            local r = reqFn({ Url = url, Method = "GET" })
            body = r and r.Body
        else
            body = game:HttpGet(url)
        end
        return body and HttpService:JSONDecode(body)
    end

    local function clearTag(uid)
        local t = tags[uid]
        if t then pcall(function() t:Destroy() end) tags[uid] = nil end
    end

    local function updateTags()
        for uid in pairs(tags) do
            if not (State.tagUsers and users[uid]) then clearTag(uid) end
        end
        if not State.tagUsers then return end
        for uid in pairs(users) do
            local pl = Players:GetPlayerByUserId(uid)
            local head = pl and pl.Character and pl.Character:FindFirstChild("Head")
            local tag = tags[uid]
            if head and (not tag or not tag.Parent or tag.Adornee ~= head) then
                clearTag(uid)
                local bb = Instance.new("BillboardGui")
                bb.Name = "FiskUserTag"
                bb.Adornee = head
                bb.AlwaysOnTop = true
                bb.Size = UDim2.fromOffset(120, 20)
                bb.StudsOffset = Vector3.new(0, 2.6, 0)
                bb.Parent = espFolder
                local tl = label(bb, "Fisk Grow", 12, COLORS.accent, Enum.Font.GothamBold)
                tl.Size = UDim2.fromScale(1, 1)
                tl.TextXAlignment = Enum.TextXAlignment.Center
                tl.TextStrokeTransparency = 0.4
                tags[uid] = bb
            end
        end
    end

    local function render()
        if not statusLbl then return end
        if FISK_API == "" then
            statusLbl.Text = T("Адрес сервера не задан (переменная FISK_API в скрипте)")
        else
            local n = 0
            for _ in pairs(users) do n += 1 end
            statusLbl.Text = T("Со скриптом на этом сервере: ") .. n .. "   |   " .. T("всего онлайн: ") .. onlineTotal
        end
        for _, c in ipairs(listBox:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local order = 0
        for uid, info in pairs(users) do
            order += 1
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 36)
            row.BackgroundColor3 = COLORS.item
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 3
            row.Parent = listBox
            corner(row, 14)
            local l = label(row, info.name .. "   (" .. uid .. ")", 13)
            l.Position = UDim2.fromOffset(14, 0)
            l.Size = UDim2.new(1, -28, 1, 0)
            l.ZIndex = 4
        end
    end

    -- UI
    makeToggle(T("Показывать меня другим пользователям скрипта"), true, function(v) State.shareMe = v end, pages.users)
    makeToggle(T("Метка над игроками со скриптом"), true, function(v)
        State.tagUsers = v
        updateTags()
    end, pages.users)

    statusLbl = label(pages.users, "", 12, COLORS.sub)
    statusLbl.Size = UDim2.new(1, 0, 0, 36)
    statusLbl.TextWrapped = true
    statusLbl.LayoutOrder = nextOrder()
    statusLbl.ZIndex = 3

    listBox = Instance.new("Frame")
    listBox.BackgroundTransparency = 1
    listBox.BorderSizePixel = 0
    listBox.Size = UDim2.new(1, 0, 0, 0)
    listBox.AutomaticSize = Enum.AutomaticSize.Y
    listBox.LayoutOrder = nextOrder()
    listBox.ZIndex = 3
    listBox.Parent = pages.users
    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 6)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = listBox
    render()

    -- опрос сервера раз в 15 секунд
    task.spawn(function()
        while gui.Parent and not MV.unloaded do
            if FISK_API ~= "" then
                local ok, data = pcall(fetch, State.shareMe and "ping" or "list")
                if ok and type(data) == "table" and data.ok then
                    local new = {}
                    for _, pl in ipairs(data.players or {}) do
                        local uid = tonumber(pl.uid)
                        if uid then
                            new[uid] = { name = tostring(pl.name or uid) }
                            if not known[uid] then
                                pcall(notify, new[uid].name .. " " .. T("использует скрипт"))
                            end
                        end
                    end
                    known, users = new, new
                    onlineTotal = tonumber(data.online) or 0
                    pcall(render)
                    pcall(updateTags)
                end
            end
            task.wait(15)
        end
    end)
    -- метки переживают респавн игроков
    task.spawn(function()
        while gui.Parent and not MV.unloaded do
            task.wait(3)
            pcall(updateTags)
        end
    end)
end

-- ========= Меню: пункты слева, функции справа =========
-- ИГРОК
-- Скорость
do
    local sec = makeSection(T("СКОРОСТЬ"), true, pages.player)
    makeToggle(T("Изменение скорости"), false, function(v)
        State.speedOn = v
        if not v and MV.ready and MV.hum then pcall(function() MV.hum.WalkSpeed = MV.getSpeed() end) end
    end, sec)
    makeSpeedSlider(T("Скорость"), MIN_SPEED, MAX_SPEED, State.speed, function(v)
        State.speed = v
        if State.speedOn then MV.fireCrouch(true) end
    end, sec)
    makeToggle(T("Убрать ускорение (без скольжения)"), false, function(v)
        State.noAccel = v
        MV.applyAccel(v)
    end, sec)
end

-- Полёт
do
    local sec = makeSection(T("ПОЛЁТ"), false, pages.player)
    MV.uiFly = makeToggle(T("Полёт (Fly)"), false, function(v) State.flyOn = v end, sec)
    makeKeyBind(T("Клавиша"), "flyKey", sec)
    makeSpeedSlider(T("Скорость полёта"), 0, 115, State.flySpeed, function(v) State.flySpeed = v end, sec)
end

-- Вид от третьего лица
do
    local sec = makeSection(T("ТРЕТЬЕ ЛИЦО"), false, pages.player)
    MV.uiTP = makeToggle(T("Вид от третьего лица"), false, function(v) State.tpOn = v end, sec)
    makeKeyBind(T("Клавиша"), "tpKey", sec)
    makeSpeedSlider(T("Смещение X"), -10, 10, State.tpX, function(v) State.tpX = v end, sec, 0.1)
    makeSpeedSlider(T("Смещение Y"), -10, 10, State.tpY, function(v) State.tpY = v end, sec, 0.1)
    makeSpeedSlider(T("Смещение Z"), -10, 10, State.tpZ, function(v) State.tpZ = v end, sec, 0.1)
    makeToggle(T("Проверка стен"), false, function(v) State.tpWall = v end, sec)
end

-- Перенос хитбокса
do
    local sec = makeSection(T("ХИТБОКС"), false, pages.player)
    MV.uiHB = makeToggle(T("Перенос хитбокса"), false, function(v)
        State.hbOn = v
        if v then MV.hbEnable() else MV.hbDisable() end
    end, sec)
    makeKeyBind(T("Клавиша"), "hbKey", sec)
    makeToggle(T("Всегда приседать (Crouch Spoof)"), false, function(v)
        State.crouchSpoof = v
        MV.fireCrouch(v and true or MV.isCrouching())
    end, sec)
end

-- Разрешить прыжок / слайд (атрибуты персонажа CanJump / CanSlide, локально)
State.allowJump, State.allowSlide = false, false
local origAttr = {}
local function applyMoveAttrs()
    local char = lp.Character
    if not char then return end
    for _, a in ipairs({ { "CanJump", State.allowJump }, { "CanSlide", State.allowSlide } }) do
        local name, on = a[1], a[2]
        if on then
            if origAttr[name] == nil then origAttr[name] = char:GetAttribute(name) or false end
            if char:GetAttribute(name) ~= true then char:SetAttribute(name, true) end
        elseif origAttr[name] ~= nil then
            char:SetAttribute(name, origAttr[name])
            origAttr[name] = nil
        end
    end
end
task.spawn(function()
    while gui.Parent do
        pcall(applyMoveAttrs)
        task.wait(0.5)
    end
end)
connect(lp.CharacterAdded, function() origAttr = {} end)
makeToggle(T("Разрешить прыжок"), false, function(v)
    State.allowJump = v
    pcall(applyMoveAttrs)
end, pages.player)
makeToggle(T("Разрешить слайд"), false, function(v)
    State.allowSlide = v
    pcall(applyMoveAttrs)
end, pages.player)

-- ESP
makeToggle(T("ESP сущностей"), true, function(v) State.espOn = v end, pages.esp)
makeToggle(T("Подсветка нужной двери"), true, function(v)
    State.doorOn = v
    if not v then clearDoor() end
end, pages.esp)
makeToggle(T("Авто-обнаружение новых"), true, function(v) State.autoOn = v end, pages.esp)
makeToggle(T("Уведомления о спавне"), true, function(v) State.notifyOn = v end, pages.esp)
makeToggle(T("Предупреждение Screech (поворот)"), true, function(v) State.screechWarn = v end, pages.esp)
makeToggle(T("Диагностика Seek (лог в буфер)"), false, function(v)
    State.seekDiag = v
    if v then DIAG.start() else DIAG.stop() end
end, pages.esp)

-- ГОЛОВОЛОМКИ (всё выключено по умолчанию)
makeToggle(T("Предметы и головоломки"), false, function(v)
    State.pzOn = v
    if v then PZ.scanAll() else PZ.clearAll() end
end, pages.pz)

do
    local sec = makeSection(T("ЧТО ПОКАЗЫВАТЬ"), true, pages.pz)
    makeSmallToggle(T("Предметы (только лежащие)"), true, function(v)
        State.pz.loot = v
        PZ.refresh()
    end, sec)
    makeSmallToggle(T("Библиотека: книги, замок, код"), true, function(v)
        State.pz.library = v
        PZ.refresh()
    end, sec)
    makeSmallToggle(T("Шахты: генераторы и лампочки"), true, function(v)
        State.pz.gen = v
        PZ.refresh()
    end, sec)
    makeSmallToggle(T("Рычаги и огонь (лестницы)"), true, function(v)
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

    local cap = label(row, T("Код библиотеки"), 12, COLORS.sub, Enum.Font.GothamMedium)
    cap.Position = UDim2.fromOffset(16, 8)
    cap.Size = UDim2.new(1, -32, 0, 16)
    cap.ZIndex = 4

    local val = label(row, "-", 18, COLORS.accent, Enum.Font.GothamBold)
    val.Position = UDim2.fromOffset(16, 26)
    val.Size = UDim2.new(1, -32, 0, 24)
    val.ZIndex = 4
    PZ.codeLabel = val
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

    local l = label(row, T("ТГК разраба"), 14)
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
    btn.Text = T("Перейти")
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = COLORS.onAccent
    btn.ZIndex = 4
    corner(btn, 18)
    hoverFx(btn, COLORS.accent, COLORS.accent3)

    connect(btn.Activated, function()
        local ok = pcall(function() setclipboard("https://t.me/fiskgrov") end)
        if ok then
            notify(T("Ссылка скопирована: t.me/fiskgrov"))
        else
            notify("t.me/fiskgrov")
        end
    end)
end

do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = COLORS.item
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 3
    row.Parent = pages.link
    corner(row, 16)

    local l = label(row, T("Язык интерфейса"), 14)
    l.Position = UDim2.fromOffset(16, 0)
    l.Size = UDim2.new(1, -130, 1, 0)
    l.ZIndex = 4

    local btn = makeBtn(row)
    btn.Size = UDim2.fromOffset(96, 34)
    btn.Position = UDim2.new(1, -110, 0.5, -17)
    btn.BackgroundColor3 = COLORS.highest
    btn.Text = T("Сменить")
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = COLORS.text
    btn.ZIndex = 4
    corner(btn, 17)
    hoverFx(btn, COLORS.highest, COLORS.selected)

    connect(btn.Activated, function()
        pcall(function()
            if delfile and isfile and isfile(LANG_FILE) then
                delfile(LANG_FILE)
            elseif writefile then
                writefile(LANG_FILE, "")
            end
        end)
        notify(T("Язык будет выбран при следующем запуске"))
    end)
end

local hint = label(pages.link, T("RightShift - скрыть / показать меню"), 11, COLORS.sub)
hint.LayoutOrder = nextOrder()
hint.Size = UDim2.new(1, 0, 0, 22)
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
fab.Text = logoImage and "" or "F"
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
    MV.unload()
    State.pzOn = false
    PZ.clearAll()
    SK.clear()
    clearDoor()
    for m in pairs(tracked) do removeEsp(m) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)
