-- MODULE 01: BOOTSTRAP

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
if not LP then warn("[WOG] LocalPlayer missing"); return end
if game.GameId ~= 125223108 then warn("[WOG] Wrong experience:", game.GameId, game.PlaceId); return end

local PlayerScripts = LP:WaitForChild("PlayerScripts")
local ClientCore = PlayerScripts:WaitForChild("ClientCore", 10)
local Framework = ClientCore and ClientCore:WaitForChild("Framework", 10)
local Modules = Framework and Framework:WaitForChild("Modules", 10)
if not Modules then warn("[WOG] Framework modules missing"); return end

local function safeRequire(obj, name)
    if not obj then warn("[WOG] Missing module:", name); return nil end
    local ok, result = pcall(require, obj)
    if not ok then warn("[WOG] Failed require:", name, result); return nil end
    return result
end

local Weapon = safeRequire(Modules:FindFirstChild("Weapon"), "Weapon")
local Controls = safeRequire(Modules:FindFirstChild("Controls"), "Controls")
local CameraModule = safeRequire(Modules:FindFirstChild("Camera"), "Camera")
local Plane = safeRequire(Modules:FindFirstChild("Plane"), "Plane")
local ProjectileCompute = safeRequire(ReplicatedStorage.Shared:FindFirstChild("ProjectileParallelCompute"), "ProjectileParallelCompute")
local ArmamentData = safeRequire(ReplicatedStorage.Assets.Modules.Essentials:FindFirstChild("ArmamentData"), "ArmamentData")

if not (Weapon and Controls and CameraModule and Plane and ProjectileCompute and ArmamentData) then return end
if type(Weapon.new_bullet) ~= "function" then warn("[WOG] Weapon.new_bullet unavailable"); return end
if type(Controls.lock_on_plane) ~= "function" then warn("[WOG] Controls.lock_on_plane unavailable"); return end

local ConditionService
pcall(function() ConditionService = _G:require("ConditionService") end)

local ENV = getgenv and getgenv() or _G
if ENV.WOG_TRACER and ENV.WOG_TRACER.Unload then pcall(ENV.WOG_TRACER.Unload) end











-- MODULE 02: DRAWING CORE

local DrawPool = { lines = {}, circles = {}, squares = {}, texts = {} }
local DrawIdx = { lines = 1, circles = 1, squares = 1, texts = 1 }

local function GetLine(from, to, color, thickness, transparency)
    local idx = DrawIdx.lines; DrawIdx.lines = idx + 1
    local obj = DrawPool.lines[idx]
    if not obj then
        local ok, created = pcall(function() return Drawing.new("Line") end)
        if not ok or not created then return nil end
        obj = created; DrawPool.lines[idx] = obj
    end
    obj.From = from; obj.To = to; obj.Color = color; obj.Thickness = thickness; obj.Transparency = transparency; obj.Visible = true
    return obj
end

local function GetCircle(position, radius, color, filled, thickness, transparency)
    local idx = DrawIdx.circles; DrawIdx.circles = idx + 1
    local obj = DrawPool.circles[idx]
    if not obj then
        local ok, created = pcall(function() return Drawing.new("Circle") end)
        if not ok or not created then return nil end
        obj = created; DrawPool.circles[idx] = obj
    end
    obj.Position = position; obj.Radius = radius; obj.Color = color; obj.Filled = filled; obj.Thickness = thickness; obj.Transparency = transparency; obj.Visible = true
    return obj
end

local function GetSquare(position, size, color, filled, thickness, transparency)
    local idx = DrawIdx.squares; DrawIdx.squares = idx + 1
    local obj = DrawPool.squares[idx]
    if not obj then
        local ok, created = pcall(function() return Drawing.new("Square") end)
        if not ok or not created then return nil end
        obj = created; DrawPool.squares[idx] = obj
    end
    obj.Position = position; obj.Size = size; obj.Color = color; obj.Filled = filled; obj.Thickness = thickness; obj.Transparency = transparency; obj.Visible = true
    return obj
end

local function GetText(position, text, color, size, center, outline)
    local idx = DrawIdx.texts; DrawIdx.texts = idx + 1
    local obj = DrawPool.texts[idx]
    if not obj then
        local ok, created = pcall(function() return Drawing.new("Text") end)
        if not ok or not created then return nil end
        obj = created; DrawPool.texts[idx] = obj
    end
    obj.Position = position; obj.Text = text; obj.Color = color; obj.Size = size; obj.Center = center; obj.Outline = outline; obj.Transparency = 0; obj.Visible = true
    return obj
end

local function BeginFrame()
    DrawIdx.lines = 1; DrawIdx.circles = 1; DrawIdx.squares = 1; DrawIdx.texts = 1
end

local function EndFrame()
    for i = DrawIdx.lines, #DrawPool.lines do DrawPool.lines[i].Visible = false end
    for i = DrawIdx.circles, #DrawPool.circles do DrawPool.circles[i].Visible = false end
    for i = DrawIdx.squares, #DrawPool.squares do DrawPool.squares[i].Visible = false end
    for i = DrawIdx.texts, #DrawPool.texts do DrawPool.texts[i].Visible = false end
end

local function RemoveAllDrawings()
    for _, list in pairs(DrawPool) do
        for _, obj in ipairs(list) do pcall(function() if obj and obj.Remove then obj:Remove() end end) end
        table.clear(list)
    end
    DrawIdx.lines = 1; DrawIdx.circles = 1; DrawIdx.squares = 1; DrawIdx.texts = 1
end

local function hsvToRgb(h, s, v) return Color3.fromHSV(h % 1, s, v) end

local function FormatDistance(m)
    m = math.abs(tonumber(m) or 0)
    if m >= 1000 then return string.format("%.1fk", m / 1000) end
    return string.format("%.0f", m)
end

local function DrawArrowTriangle(cx, cy, size, dirX, dirY, color, alpha, thickness)
    local mag = math.sqrt(dirX * dirX + dirY * dirY)
    if mag < 0.01 then dirX, dirY, mag = 0, -1, 1 end
    dirX, dirY = dirX / mag, dirY / mag
    local px, py = -dirY, dirX
    local tipX, tipY = cx + dirX * size, cy + dirY * size
    local blX = cx - dirX * size * 0.55 + px * size * 0.7
    local blY = cy - dirY * size * 0.55 + py * size * 0.7
    local brX = cx - dirX * size * 0.55 - px * size * 0.7
    local brY = cy - dirY * size * 0.55 - py * size * 0.7
    GetLine(Vector2.new(tipX, tipY), Vector2.new(blX, blY), color, thickness, alpha)
    GetLine(Vector2.new(blX, blY), Vector2.new(brX, brY), color, thickness, alpha)
    GetLine(Vector2.new(brX, brY), Vector2.new(tipX, tipY), color, thickness, alpha)
end

local function clipSegmentToCamera(p1, p2, cam)
    local cf = cam.CFrame
    local o1 = cf:PointToObjectSpace(p1)
    local o2 = cf:PointToObjectSpace(p2)
    if o1.Z >= -0.2 and o2.Z >= -0.2 then return nil, nil end
    if o1.Z < -0.2 and o2.Z < -0.2 then return p1, p2 end
    local denom = o2.Z - o1.Z
    if math.abs(denom) < 1e-4 then return nil, nil end
    local t = math.clamp((-0.25 - o1.Z) / denom, 0, 1)
    local clipped = cf:PointToWorldSpace(o1:Lerp(o2, t))
    return o1.Z >= -0.2 and clipped or p1, o1.Z >= -0.2 and p2 or clipped
end











-- MODULE 03: CONFIG AND STATE

local Config = {
    SilentAimEnabled = true, PredictionEnabled = true, DynamicFOV = true,
    FOVRadius = 100, MaxDistance = 100000, BallisticCompensation = true,
    TeamCheck = true, VisibilityCheck = false, TargetMode = "Nearest Center",
    HitPart = "Fuselage", TargetHoldTime = 1.25, TargetSwitchCooldown = 0.35, DrawFOV = true,

    -- Aimbot (Mouse & Camera)
    AimbotEnabled = false, AimbotMethod = "Mouse", AimbotSensitivity = 35, AimbotFOV = 150,
    AimbotPrediction = true, AimbotDrawCircle = true, AimbotDrawFOV = false,
    AimbotActivation = "Right Mouse Hold",

    -- Bullet Tracer (Simplified)
    TracerEnabled = true, TracerStyle = "Neon",
    TracerColorA = Color3.fromRGB(0, 255, 230),
    TracerLifetime = 0.75, TracerThickness = 1.2,
    MaxTracers = 25, TracerTarget = "Local Only", NotifyOnHit = true,

    -- Aim Line (Thin)
    AimLineEnabled = false, AimLineColor = Color3.fromRGB(255, 60, 60), AimLineThickness = 1,

    MasterHitbox = false, SmartHitbox = false, HitboxDebug = false,
    HitboxMethod = "Scale",
    HitboxScaleMul = 2, HitboxFuselageMul = 2, HitboxWingMul = 2,

    AutoApplyConfig = true,
    FPSBoostEnabled = false, PotatoModeEnabled = false,
}

local State = {
    Running = true,
    CurrentTarget = nil, CurrentTargetModel = nil,
    LastTargetChange = 0, LastAcquire = 0,
    TargetDistance = math.huge, ScreenDistance = math.huge,
    LastInterceptTime = 0, LastProjectileSpeed = 0, LastTargetSpeed = 0,
    LastPredictedPosition = nil, LastShotDirection = nil, LastAimPoint = nil,
    RedirectedShots = 0, RejectedReason = "None",
    Connections = {}, History = {}, ActiveTracers = {},
    OriginalSizes = setmetatable({}, { __mode = "k" }),
    FOVPosition = nil, FOVRadius = 100, FOVColor = Color3.fromRGB(255, 60, 60),
}

local OriginalNewBullet = Weapon.new_bullet

local ConfigFolder = "WOG_Configs"
pcall(function() if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end end)
local ConfigPath = function(name) return ConfigFolder .. "/" .. name .. ".json" end
local LatestConfigPath = ConfigFolder .. "/latest_config.json"
local LatestNamePath = ConfigFolder .. "/latest_name.txt"

local function SerializeColor(c) return { __type = "Color3", r = c.R, g = c.G, b = c.B } end

local function SerializeConfig()
    local out = {}
    for k, v in pairs(Config) do out[k] = (typeof(v) == "Color3") and SerializeColor(v) or v end
    local ok, json = pcall(function() return HttpService:JSONEncode(out) end)
    if ok then return json end
    return nil
end

local function DeserializeInto(target, json)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        if type(v) == "table" and v.__type == "Color3" then target[k] = Color3.new(v.r, v.g, v.b)
        else target[k] = v end
    end
    return true
end

local function SaveLatestConfig(sourceName)
    pcall(function()
        local json = SerializeConfig()
        if json then
            writefile(LatestConfigPath, json)
            if sourceName and sourceName ~= "" then
                writefile(LatestNamePath, tostring(sourceName))
            end
        end
    end)
end

local function LoadLatestConfig()
    local exists = false
    pcall(function() exists = isfile(LatestConfigPath) end)
    if not exists then return false, nil end
    local ok, data = pcall(function() return readfile(LatestConfigPath) end)
    if not ok or not data then return false, nil end
    local success = DeserializeInto(Config, data)
    local lastName = "Latest AutoSave"
    pcall(function()
        if isfile(LatestNamePath) then
            lastName = readfile(LatestNamePath)
        end
    end)
    return success, lastName
end

local function SaveConfig(name)
    if not name or name == "" then return false end
    local json = SerializeConfig()
    if not json then return false end
    local ok = pcall(function() writefile(ConfigPath(name), json) end)
    if ok then SaveLatestConfig(name) end
    return ok
end

local function LoadConfig(name)
    if not name or name == "" then return false end
    local path = ConfigPath(name)
    local exists = false
    pcall(function() exists = isfile(path) end)
    if not exists then return false end
    local ok, data = pcall(function() return readfile(path) end)
    if not ok or not data then return false end
    local success = DeserializeInto(Config, data)
    if success then SaveLatestConfig(name) end
    return success
end

local function DeleteConfig(name)
    if not name or name == "" then return false end
    local ok = pcall(function() delfile(ConfigPath(name)) end)
    return ok
end

local function ListConfigs()
    local names = {}
    pcall(function()
        for _, path in ipairs(listfiles(ConfigFolder)) do
            local n = path:match("([^/\\]+)%.json$")
            if n then table.insert(names, n) end
        end
    end)
    table.sort(names)
    return names
end











-- MODULE 04: NOTIFICATION

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "WOG_Notify"
notifGui.ResetOnSpawn = false
notifGui.IgnoreGuiInset = true
notifGui.DisplayOrder = 9999
local notifParent = LP:FindFirstChild("PlayerGui")
if notifParent then notifGui.Parent = notifParent
else pcall(function() notifGui.Parent = CoreGui end) end

local notifHolder = Instance.new("Frame")
notifHolder.AnchorPoint = Vector2.new(0.5, 0)
notifHolder.Position = UDim2.new(0.5, 0, 0, 20)
notifHolder.Size = UDim2.new(0, 320, 0, 60)
notifHolder.BackgroundTransparency = 1
notifHolder.Parent = notifGui

local _lastNotifyAt = 0

local function Notify(title, subtitle, color)
    local now = os.clock()
    if now - _lastNotifyAt < 0.25 then return end
    _lastNotifyAt = now
    color = color or Color3.fromRGB(255, 190, 60)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 46)
    card.Position = UDim2.new(0, 0, 0, -60)
    card.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = notifHolder

    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = card
    local stroke = Instance.new("UIStroke"); stroke.Color = color; stroke.Thickness = 1.5; stroke.Transparency = 0.2; stroke.Parent = card

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -12); accent.Position = UDim2.new(0, 0, 0, 6)
    accent.BackgroundColor3 = color; accent.BorderSizePixel = 0; accent.Parent = card
    local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0, 2); ac.Parent = accent

    local star = Instance.new("TextLabel")
    star.Size = UDim2.fromOffset(24, 24); star.Position = UDim2.new(0, 12, 0.5, -12)
    star.BackgroundTransparency = 1; star.Text = "✦"; star.TextColor3 = color; star.TextSize = 18
    star.Font = Enum.Font.GothamBold; star.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -50, 0, 18); titleLbl.Position = UDim2.new(0, 42, 0, 6)
    titleLbl.BackgroundTransparency = 1; titleLbl.Text = title; titleLbl.TextColor3 = Color3.fromRGB(240, 240, 245)
    titleLbl.TextSize = 12; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = card

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -50, 0, 14); subLbl.Position = UDim2.new(0, 42, 0, 24)
    subLbl.BackgroundTransparency = 1; subLbl.Text = subtitle; subLbl.TextColor3 = Color3.fromRGB(150, 155, 168)
    subLbl.TextSize = 10; subLbl.Font = Enum.Font.Code; subLbl.TextXAlignment = Enum.TextXAlignment.Left; subLbl.Parent = card

    TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()

    task.delay(2.5, function()
        if card and card.Parent then
            TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Position = UDim2.new(0, 0, 0, -60), BackgroundTransparency = 1 }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
            TweenService:Create(titleLbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            TweenService:Create(subLbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            TweenService:Create(star, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            task.delay(0.35, function() if card and card.Parent then card:Destroy() end end)
        end
    end)
end

-- COMBAT HIT NOTIFICATION SYSTEM
local HitFeedback = {
    time = 0,
    target = "",
    dist = 0,
    streak = 0,
    lastToast = 0,
}

local function TriggerHitNotification(targetName, distance)
    local now = os.clock()
    if now - HitFeedback.time < 1.0 then
        HitFeedback.streak = HitFeedback.streak + 1
    else
        HitFeedback.streak = 1
    end
    HitFeedback.time = now
    HitFeedback.target = targetName or "Target"
    HitFeedback.dist = distance or 0

    -- UI Toast notification with debounce
    if now - HitFeedback.lastToast >= 0.4 then
        HitFeedback.lastToast = now
        local distText = (distance and distance > 0) and string.format(" (%.0fm)", distance) or ""
        local streakText = HitFeedback.streak > 1 and string.format("HIT x%d", HitFeedback.streak) or "HIT"
        local contentText = string.format("✦ Locked & Hit: %s%s", tostring(HitFeedback.target), distText)
        local col = HitFeedback.streak > 1 and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 190, 60)

        if Rayfield and Rayfield.Notify then
            pcall(function()
                Rayfield:Notify({
                    Title = streakText,
                    Content = contentText,
                    Duration = 1.2,
                    Image = 4483362458
                })
            end)
        end
        pcall(Notify, streakText, contentText, col)
    end
end

local function DrawHitFeedback(cam, center)
    if not Config.NotifyOnHit then return end
    local now = os.clock()
    local elapsed = now - HitFeedback.time
    if elapsed >= 0.85 then return end

    local streak = HitFeedback.streak or 1
    local col = streak > 1 and Color3.fromRGB(255, 65, 65) or Color3.fromRGB(255, 215, 65)

    -- 1. Hitmarker Ticks (\ / & / \) around center crosshair
    if elapsed < 0.22 then
        local tickCol = streak > 1 and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 255, 255)
        local gap = 6
        local len = 8
        GetLine(center + Vector2.new(-gap, -gap), center + Vector2.new(-gap - len, -gap - len), tickCol, 1.5, 0.9)
        GetLine(center + Vector2.new(gap, -gap), center + Vector2.new(gap + len, -gap - len), tickCol, 1.5, 0.9)
        GetLine(center + Vector2.new(-gap, gap), center + Vector2.new(-gap - len, gap + len), tickCol, 1.5, 0.9)
        GetLine(center + Vector2.new(gap, gap), center + Vector2.new(gap + len, gap + len), tickCol, 1.5, 0.9)
    end

    -- 2. Floating Combat Text below crosshair
    local distText = HitFeedback.dist > 0 and string.format(" (%.0fm)", HitFeedback.dist) or ""
    local comboText = streak > 1 and string.format("x%d ", streak) or ""
    local text = string.format("✦ HIT %s[%s]%s", comboText, tostring(HitFeedback.target), distText)
    local textPos = Vector2.new(center.X, center.Y + 30 - (elapsed * 6))
    GetText(textPos, text, col, 14, true)
end











-- MODULE 05: PLANE CACHE

local cachedPlaneParts = {}
local cachedPlaneModels = {}
local lastPartCacheUpdate = 0

local function modelHasPlaneParts(m)
    if not m or not m:IsA("Model") then return false end
    if m:FindFirstChild("Fuselage") then return true end
    if m.PrimaryPart then return true end
    return false
end

local function playerPlaneModel(plr)
    local direct = Workspace:FindFirstChild(plr.Name)
    if modelHasPlaneParts(direct) then return direct end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == plr.Name and modelHasPlaneParts(obj) then return obj end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and modelHasPlaneParts(obj) then
            if obj.Name == plr.Name or obj.Name:find(plr.Name, 1, true) then return obj end
        end
    end
    return nil
end

local function FindAllPlaneParts()
    local now = os.clock()
    if now - lastPartCacheUpdate > 0.5 then
        lastPartCacheUpdate = now
        table.clear(cachedPlaneParts); table.clear(cachedPlaneModels)
        local seen, seenModels = {}, {}
        local named = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.Name
                if n == "Fuselage" or n == "LeftWing" or n == "RightWing" or n == "Engine" then
                    local m = obj:FindFirstAncestorWhichIsA("Model")
                    if m then
                        named[m] = named[m] or { model = m, fuselage = nil, wings = {}, engines = {}, isBot = false }
                        if n == "Fuselage" then named[m].fuselage = obj end
                        if n == "LeftWing" or n == "RightWing" then table.insert(named[m].wings, obj) end
                        if n == "Engine" then table.insert(named[m].engines, obj) end
                    end
                    if not seen[obj] then seen[obj] = true; table.insert(cachedPlaneParts, obj) end
                end
            end
        end
        for m, data in pairs(named) do
            if not seenModels[m] then
                seenModels[m] = true
                if not data.fuselage and m.PrimaryPart then data.fuselage = m.PrimaryPart end
                table.insert(cachedPlaneModels, data)
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local m = playerPlaneModel(plr)
                if m and not seenModels[m] then
                    seenModels[m] = true
                    local data = { model = m, fuselage = m:FindFirstChild("Fuselage") or m.PrimaryPart, wings = {}, engines = {}, isBot = false }
                    for _, n in ipairs({ "LeftWing", "RightWing" }) do
                        local p = m:FindFirstChild(n)
                        if p and p:IsA("BasePart") then
                            table.insert(data.wings, p)
                            if not seen[p] then seen[p] = true; table.insert(cachedPlaneParts, p) end
                        end
                    end
                    for _, p in ipairs(m:GetChildren()) do
                        if p:IsA("BasePart") and p.Name == "Engine" then
                            table.insert(data.engines, p)
                            if not seen[p] then seen[p] = true; table.insert(cachedPlaneParts, p) end
                        end
                    end
                    if data.fuselage and not seen[data.fuselage] then
                        seen[data.fuselage] = true; table.insert(cachedPlaneParts, data.fuselage)
                    end
                    table.insert(cachedPlaneModels, data)
                end
            end
        end
        pcall(function()
            if CameraModule then
                for _, fn in ipairs({ "plane_viewmodels", "plane_part_viewmodels", "bot_plane_viewmodels" }) do
                    local f = CameraModule[fn]
                    if f then
                        for _, child in ipairs(f:GetChildren()) do
                            if child:IsA("Model") and not seenModels[child] then
                                seenModels[child] = true
                                local data = { model = child, fuselage = child:FindFirstChild("Fuselage") or child.PrimaryPart, wings = {}, engines = {}, isBot = (fn == "bot_plane_viewmodels") }
                                for _, n in ipairs({ "LeftWing", "RightWing" }) do
                                    local p = child:FindFirstChild(n)
                                    if p and p:IsA("BasePart") then table.insert(data.wings, p) end
                                end
                                for _, p in ipairs(child:GetChildren()) do
                                    if p:IsA("BasePart") and p.Name == "Engine" then table.insert(data.engines, p) end
                                end
                                if data.fuselage then table.insert(cachedPlaneModels, data) end
                            end
                        end
                    end
                end
            end
        end)
    end
    return cachedPlaneParts, cachedPlaneModels
end

local function getOwningPlayer(m)
    if not m then return nil end
    local p = Players:FindFirstChild(m.Name)
    if p and p:IsA("Player") then return p end
    for _, plr in ipairs(Players:GetPlayers()) do if plr.Name == m.Name then return plr end end
    for _, plr in ipairs(Players:GetPlayers()) do if m.Name:find(plr.Name, 1, true) then return plr end end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and (m == plr.Character or m:IsDescendantOf(plr.Character)) then return plr end
    end
    return nil
end

local function isBotByServer(model)
    if not model then return true end
    if Players:FindFirstChild(model.Name) then return false end
    return true
end

local function IsMyPlane(model)
    if not model then return false end
    local myModel = Workspace.Camera:FindFirstChild("plane_model")
    if myModel and (model == myModel or model:IsDescendantOf(myModel)) then return true end
    if model.Name == LP.Name then return true end
    if model.Name == tostring(LP.UserId) then return true end
    return false
end

local function ShouldShowModel(model, isBot)
    if not model then return false end
    if IsMyPlane(model) then return false end
    if isBot then return true end
    if not Config.TeamCheck then return true end
    local owner = getOwningPlayer(model)
    if not owner then return true end
    if owner == LP then return false end
    if owner.Team and LP.Team and owner.Team == LP.Team then return false end
    if owner.TeamColor and LP.TeamColor and owner.TeamColor == LP.TeamColor then return false end
    return true
end











-- MODULE 06: UI WINDOW

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Radius Client | WOG",
    LoadingTitle = "Radius Client",
    LoadingSubtitle = "Wing Of Glory",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local CombatTab = Window:CreateTab("Combat", 4483362458)
local VisualTab = Window:CreateTab("Visual", 4483362458)
local ConfigTab = Window:CreateTab("Config", 4483362458)
local SessionTab = Window:CreateTab("Session", 4483362458)

local RefreshFns = {}
local function RegRefresh(fn) table.insert(RefreshFns, fn) end
local function RefreshUI() for _, fn in ipairs(RefreshFns) do pcall(fn) end end

local function SafeSelectTab(tab)
    pcall(function() Window:SelectTab(tab) end)
    task.wait(0.05)
end











-- MODULE 07: COMBAT TAB

local function solveInterceptTime(shooterPos, targetPos, targetDir, targetSpeed, projectileSpeed, projectileMass)
    local speed = math.max(projectileSpeed, 0.001)
    local dragFactor = 0.02 / math.max(projectileMass, 1e-6)
    local delta = targetPos - shooterPos
    local t = delta.Magnitude / speed
    for _ = 1, 6 do
        local futureDistance = (delta + (targetDir * targetSpeed * t)).Magnitude
        local dragDistance = dragFactor * futureDistance
        local newTime
        if dragDistance > 1e-4 then newTime = (math.exp(math.min(dragDistance, 30)) - 1) / (dragFactor * speed)
        else newTime = futureDistance / speed end
        t = newTime
        if newTime >= 2.4 then return 2.4 end
    end
    return t
end

local function getViewModelFolder() return CameraModule.plane_part_viewmodels end
local function getBotFolder() return CameraModule.bot_plane_viewmodels end

local function resolveTargetModel(name)
    if not name then return nil end
    local pf = getViewModelFolder(); if pf then local p = pf:FindFirstChild(name); if p then return p end end
    local bf = getBotFolder(); if bf then local b = bf:FindFirstChild(name); if b then return b end end
    local pv = CameraModule.plane_viewmodels; if pv then local m = pv:FindFirstChild(name); if m then return m end end
    return nil
end

local function getTargetPart(model)
    if not model then return nil end
    local mode = Config.HitPart
    if mode == "Random Body Part" then
        local choices = { model:FindFirstChild("Fuselage"), model:FindFirstChild("Engine"), model:FindFirstChild("LeftWing"), model:FindFirstChild("RightWing") }
        local valid = {}
        for _, part in ipairs(choices) do if part and part:IsA("BasePart") then table.insert(valid, part) end end
        if #valid > 0 then return valid[math.random(1, #valid)] end
    else
        local chosen = model:FindFirstChild(mode)
        if chosen and chosen:IsA("BasePart") then return chosen end
    end
    if model:IsA("Model") and model.PrimaryPart then return model.PrimaryPart end
    if model:IsA("BasePart") then return model end
    return nil
end

local function enemyCheck(name)
    if not Config.TeamCheck then return true end
    local player = Players:FindFirstChild(name)
    if not player then return true end
    return player.TeamColor ~= LP.TeamColor
end

local function targetAlive(name)
    if ConditionService then
        local ok, destroyed = pcall(function() return ConditionService:getConditionValue(name, "destroyed") end)
        if ok and destroyed then return false end
    end
    return true
end

local function insideFOV(worldPos)
    local cam = Workspace.CurrentCamera
    if not cam then return false, math.huge end
    local p, visible = cam:WorldToViewportPoint(worldPos)
    if not visible or p.Z <= 0 then return false, math.huge end
    local center = cam.ViewportSize * 0.5
    local screenPos = Vector2.new(p.X, p.Y)
    local distCenter = (screenPos - center).Magnitude

    if Config.DynamicFOV and State.CurrentTarget and State.FOVPosition then
        local distFromRing = (screenPos - State.FOVPosition).Magnitude
        local effectiveR = math.max(State.FOVRadius or 50, 40)
        return (distFromRing <= effectiveR * 1.5 or distCenter <= Config.FOVRadius), distCenter
    end

    return distCenter <= Config.FOVRadius, distCenter
end

local function visibleCheck(origin, part)
    if not Config.VisibilityCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if Plane and Plane.model then table.insert(ignore, Plane.model) end
    if Workspace:FindFirstChild("nodes") then table.insert(ignore, Workspace.nodes) end
    params.FilterDescendantsInstances = ignore
    local result = Workspace:Raycast(origin, part.Position - origin, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(part.Parent)
end

local function updateTargetMotion(name, position)
    local now = os.clock()
    local h = State.History[name]
    if not h then h = { pos = position, time = now, smoothVelocity = Vector3.zero }; State.History[name] = h; return Vector3.zero, 0 end
    local dt = math.clamp(now - h.time, 1 / 240, 0.25)
    local rawVelocity = (position - h.pos) / dt
    local alpha = 1 - math.exp(-dt / 0.15)
    h.smoothVelocity = h.smoothVelocity:Lerp(rawVelocity, alpha)
    h.pos = position; h.time = now
    local direction = h.smoothVelocity.Magnitude > 1e-4 and h.smoothVelocity.Unit or Vector3.zero
    local targetSpeed
    if ConditionService then
        local ok, speed = pcall(function() return ConditionService:getConditionValue(name, "speed") end)
        if ok and tonumber(speed) then targetSpeed = tonumber(speed) / 14.4 end
    end
    if not targetSpeed then targetSpeed = h.smoothVelocity.Magnitude end
    return direction, targetSpeed
end

local function getTargetCandidates()
    local cam = Workspace.CurrentCamera
    if not cam then return {} end
    local center = cam.ViewportSize * 0.5
    local list = {}
    local _, models = FindAllPlaneParts()
    local seenNames = {}
    for _, data in ipairs(models) do
        local m = data.model
        if m and m.Parent and ShouldShowModel(m, data.isBot) and not seenNames[m.Name] then
            seenNames[m.Name] = true
            local part = getTargetPart(m)
            if part then
                local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen and pos.Z > 0 then
                    local screenDist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    local worldDist = (part.Position - cam.CFrame.Position).Magnitude
                    if screenDist <= Config.FOVRadius and worldDist <= Config.MaxDistance then
                        table.insert(list, { name = m.Name, model = m, part = part, screenDist = screenDist, worldDist = worldDist })
                    end
                end
            end
        end
    end
    return list
end

local function pickTargetByMode(list)
    if #list == 0 then return nil end
    local mode = Config.TargetMode or "Nearest Center"
    local best = list[1]
    if mode == "Nearest Distance" then
        for _, t in ipairs(list) do if t.worldDist < best.worldDist then best = t end end
    else
        for _, t in ipairs(list) do if t.screenDist < best.screenDist then best = t end end
    end
    return best
end

local function acquireGameTarget(force)
    local now = os.clock()
    if not force and now - State.LastAcquire < Config.TargetSwitchCooldown then return end
    State.LastAcquire = now
    local list = getTargetCandidates()
    local chosen = pickTargetByMode(list)
    if chosen then
        if State.CurrentTarget ~= chosen.name then
            if State.CurrentTarget and now - State.LastTargetChange < Config.TargetHoldTime and not force then return end
            State.CurrentTarget = chosen.name
            State.CurrentTargetModel = chosen.model
            State.LastTargetChange = now
        else State.CurrentTargetModel = chosen.model end
    else
        pcall(function() Controls:lock_on_plane("auto") end)
        local name = Controls.AimAssistTarget or Controls.PlayerLocked
        if name and name ~= false and name ~= "" then
            name = tostring(name)
            if State.CurrentTarget ~= name then
                State.CurrentTarget = name
                State.CurrentTargetModel = resolveTargetModel(name)
                State.LastTargetChange = now
            end
        end
    end
end

local function validateTarget(origin)
    if not State.CurrentTarget then State.RejectedReason = "No target"; return nil end
    if not enemyCheck(State.CurrentTarget) then State.RejectedReason = "Friendly"; return nil end
    if not targetAlive(State.CurrentTarget) then State.RejectedReason = "Destroyed"; return nil end
    local model = State.CurrentTargetModel or resolveTargetModel(State.CurrentTarget)
    State.CurrentTargetModel = model
    if not model then State.RejectedReason = "Target model missing"; return nil end
    local part = getTargetPart(model)
    if not part then State.RejectedReason = "Hit part missing"; return nil end
    local distance = (part.Position - origin).Magnitude
    State.TargetDistance = distance
    if distance > Config.MaxDistance then State.RejectedReason = "Out of range"; return nil end
    local inFov, screenDistance = insideFOV(part.Position)
    State.ScreenDistance = screenDistance
    if not inFov then State.RejectedReason = "Outside FOV"; return nil end
    if not visibleCheck(origin, part) then State.RejectedReason = "Not visible"; return nil end
    State.RejectedReason = "None"
    return part
end

local function simulateProjectile(startCF, velocity, mass, flightTime)
    if typeof(startCF) ~= "CFrame" then return nil end
    velocity = tonumber(velocity); mass = tonumber(mass); flightTime = tonumber(flightTime)
    if not velocity or not mass or not flightTime or flightTime <= 0 then return nil end
    local cf, speed = startCF, velocity
    local startPos = startCF.Position
    local elapsed = 0
    while elapsed < flightTime do
        local dt = math.min(1 / 120, flightTime - elapsed)
        local ok, newCF, _, newVelocity = pcall(ProjectileCompute.integrate, cf, 0, -0.12, speed, mass, startPos, dt)
        if not ok or typeof(newCF) ~= "CFrame" or type(newVelocity) ~= "number" then return nil end
        cf, speed = newCF, newVelocity
        elapsed = elapsed + dt
    end
    return cf.Position
end

local function computeAimPoint(shooterPos, targetPart, usePrediction, bulletData)
    if not targetPart then return nil, nil end
    local targetPos = targetPart.Position
    local predictedPos = targetPos
    local targetDirection, targetSpeed = Vector3.zero, 0

    local bData = bulletData or State.LastBulletData
    local projectile = bData and bData.projectile
    local baseVelocity = projectile and tonumber(projectile.velocity) or 2800
    local projectileMass = projectile and tonumber(projectile.mass) or 0.05
    local planeSpeed = (Plane and tonumber(Plane.total_speed)) or 0
    local projectileSpeed = ((baseVelocity * 3.6) + planeSpeed) / 14.4

    if usePrediction and State.CurrentTarget then
        targetDirection, targetSpeed = updateTargetMotion(State.CurrentTarget, targetPos)
        local interceptTime = solveInterceptTime(shooterPos, targetPos, targetDirection, targetSpeed, projectileSpeed, projectileMass)
        predictedPos = targetPos + (targetDirection * targetSpeed * interceptTime)
        State.LastInterceptTime = interceptTime
        State.LastProjectileSpeed = projectileSpeed
        State.LastTargetSpeed = targetSpeed
    end

    local flightTime = State.LastInterceptTime
    if not flightTime or flightTime <= 0 then
        flightTime = (predictedPos - shooterPos).Magnitude / math.max(projectileSpeed, 0.001)
    end

    local aimPoint = predictedPos
    if Config.BallisticCompensation then
        for _ = 1, 4 do
            local delta = aimPoint - shooterPos
            if delta.Magnitude <= 1e-4 then break end
            local testCF = CFrame.lookAt(shooterPos, aimPoint)
            local simPos = simulateProjectile(testCF, projectileSpeed, projectileMass, flightTime)
            if not simPos then break end
            local err = predictedPos - simPos
            aimPoint = aimPoint + err
            if err.Magnitude < 0.5 then break end
        end
    end

    return aimPoint, predictedPos
end

local function buildSilentAimCFrame(originalCFrame, bulletData, gunType)
    if not Config.SilentAimEnabled then return originalCFrame end
    if typeof(originalCFrame) ~= "CFrame" then return originalCFrame end

    acquireGameTarget(false)
    local targetPart = validateTarget(originalCFrame.Position)

    local gunData = gunType and ArmamentData[gunType]
    if targetPart and gunData and tonumber(gunData.DistLimit) then
        if State.TargetDistance > tonumber(gunData.DistLimit) then
            State.RejectedReason = "Beyond gun DistLimit"
            return originalCFrame
        end
    end

    if not targetPart then
        State.CurrentTarget = nil; State.CurrentTargetModel = nil
        acquireGameTarget(true)
        targetPart = validateTarget(originalCFrame.Position)
        if not targetPart then return originalCFrame end
    end

    if bulletData then State.LastBulletData = bulletData end
    local aimPoint, predictedPos = computeAimPoint(originalCFrame.Position, targetPart, Config.PredictionEnabled, bulletData)
    if not aimPoint then return originalCFrame end

    State.LastPredictedPosition = predictedPos
    State.LastAimPoint = aimPoint

    local finalDir = aimPoint - originalCFrame.Position
    if finalDir.Magnitude <= 1e-4 then return originalCFrame end
    State.LastShotDirection = finalDir.Unit
    return CFrame.lookAt(originalCFrame.Position, aimPoint, originalCFrame.UpVector)
end

Weapon.new_bullet = function(self, a2, a3, a4, a5, a6, a7, a8, a9)
    local shotCFrame = a6
    local isLocal = (a2 == LP.Name)
    local enemyShot = not isLocal
    if isLocal and a5 then
        State.LastBulletData = a5
        State.LastGunType = a7
    end
    if State.Running and typeof(a6) == "CFrame" then
        local gunName = tostring(a7 or ""):lower()
        local isMissile = gunName:find("missile") or gunName:find("rocket") or gunName:find("bomb") or gunName:find("torpedo") or gunName:find("homing") or gunName:find("guided")
        local tracerEnd = a6.Position + (a6.LookVector * 3000)
        local hasHit = false
        local targetName = nil
        if isLocal and Config.SilentAimEnabled then
            State.LastAimPoint = nil
            local ok, redirected = pcall(buildSilentAimCFrame, a6, a5, a7)
            if ok and typeof(redirected) == "CFrame" then
                if redirected ~= a6 then State.RedirectedShots += 1; targetName = State.CurrentTarget end
                shotCFrame = redirected
                if State.LastAimPoint then tracerEnd = State.LastAimPoint; hasHit = true end
            elseif not ok then State.RejectedReason = tostring(redirected) end
        end
        if hasHit and isLocal and Config.NotifyOnHit then
            local tname = targetName and tostring(targetName) or (State.CurrentTarget and tostring(State.CurrentTarget)) or "Target"
            local dist = (State.TargetDistance and State.TargetDistance < math.huge) and State.TargetDistance or 0
            TriggerHitNotification(tname, dist)
        end
        local shouldTrace = false
        if Config.TracerEnabled and not isMissile then
            if isLocal then shouldTrace = true
            elseif enemyShot and Config.TracerTarget == "Enemy" then shouldTrace = true end
        end
        if shouldTrace then
            if #State.ActiveTracers >= (Config.MaxTracers or 25) then table.remove(State.ActiveTracers, 1) end
            table.insert(State.ActiveTracers, {
                from = shotCFrame.Position, to = tracerEnd, created = os.clock(),
                isLocal = isLocal, hit = hasHit, star = hasHit, seed = math.random() * 1000,
            })
        end
    end
    return OriginalNewBullet(self, a2, a3, a4, a5, shotCFrame, a7, a8, a9)
end

task.spawn(function()
    while State.Running do
        task.wait(0.25)
        if Config.SilentAimEnabled then
            local targetValid = State.CurrentTarget and State.CurrentTargetModel and State.CurrentTargetModel.Parent
            if not targetValid then
                State.CurrentTarget = nil; State.CurrentTargetModel = nil
                acquireGameTarget(false)
            end
        end
    end
end)

local debugHighlights = {}

local function ClearDebugHighlights()
    for _, h in pairs(debugHighlights) do if h and h.Parent then h:Destroy() end end
    table.clear(debugHighlights)
end

local function ApplyRealHitbox()
    if not Config.MasterHitbox then return end
    local isMouseDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local col = Color3.fromRGB(255, 220, 60)

    for _, part in ipairs(FindAllPlaneParts()) do
        local n = part.Name
        local model = part:FindFirstAncestorWhichIsA("Model")
        local show = model and ShouldShowModel(model)
        local tracked = (n == "Fuselage" or n == "LeftWing" or n == "RightWing")
        if tracked and show then
            local shouldExpand = true
            if Config.SmartHitbox and not isMouseDown then shouldExpand = false end
            local mul = Config.HitboxScaleMul or ((n == "Fuselage") and Config.HitboxFuselageMul or Config.HitboxWingMul)
            if shouldExpand then
                if not State.OriginalSizes[part] then State.OriginalSizes[part] = part.Size end
                local orig = State.OriginalSizes[part]
                part.Size = Vector3.new(orig.X * mul, orig.Y, orig.Z * mul)
                if Config.HitboxDebug and not debugHighlights[part] then
                    local h = Instance.new("Highlight")
                    h.Adornee = part; h.FillColor = col
                    h.OutlineColor = col:Lerp(Color3.new(1, 1, 1), 0.4)
                    h.FillTransparency = 0.7; h.OutlineTransparency = 0
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Parent = part
                    debugHighlights[part] = h
                elseif Config.HitboxDebug and debugHighlights[part] then
                    debugHighlights[part].FillColor = col
                    debugHighlights[part].OutlineColor = col:Lerp(Color3.new(1, 1, 1), 0.4)
                end
            else
                if State.OriginalSizes[part] then part.Size = State.OriginalSizes[part] end
                if debugHighlights[part] then debugHighlights[part]:Destroy(); debugHighlights[part] = nil end
            end
        end
    end
    if not Config.HitboxDebug then ClearDebugHighlights() end
end

local function RestoreHitbox()
    for part, orig in pairs(State.OriginalSizes) do if part and part.Parent then part.Size = orig end end
    table.clear(State.OriginalSizes)
    ClearDebugHighlights()
end

task.spawn(function()
    while State.Running do
        RunService.Heartbeat:Wait()
        if Config.MasterHitbox then ApplyRealHitbox() end
    end
end)

-- UI
SafeSelectTab(CombatTab)
pcall(function()
    CombatTab:CreateSection("Silent Aim")
    local SilentAimToggle = CombatTab:CreateToggle({
        Name = "Silent Aim", CurrentValue = Config.SilentAimEnabled, Flag = "SilentAim",
        Callback = function(v) Config.SilentAimEnabled = v; if v then acquireGameTarget(true) end end,
    })
    RegRefresh(function() SilentAimToggle:Set(Config.SilentAimEnabled) end)

    local DynamicFOVToggle = CombatTab:CreateToggle({
        Name = "Dynamic FOV", CurrentValue = Config.DynamicFOV, Flag = "DynamicFOV",
        Callback = function(v) Config.DynamicFOV = v end,
    })
    RegRefresh(function() DynamicFOVToggle:Set(Config.DynamicFOV) end)

    local FOVSlider = CombatTab:CreateSlider({
        Name = "FOV Radius", Range = { 25, 500 }, Increment = 25, Suffix = "px",
        CurrentValue = Config.FOVRadius, Flag = "FOVRadius",
        Callback = function(v) Config.FOVRadius = v end,
    })
    RegRefresh(function() FOVSlider:Set(Config.FOVRadius) end)

    local DrawFOVToggle = CombatTab:CreateToggle({
        Name = "Draw FOV", CurrentValue = Config.DrawFOV, Flag = "DrawFOV",
        Callback = function(v) Config.DrawFOV = v end,
    })
    RegRefresh(function() DrawFOVToggle:Set(Config.DrawFOV) end)

    CombatTab:CreateSection("Aimbot")
    local AimbotToggle = CombatTab:CreateToggle({
        Name = "Enable Aimbot", CurrentValue = Config.AimbotEnabled, Flag = "AimbotEnabled",
        Callback = function(v) Config.AimbotEnabled = v end,
    })
    RegRefresh(function() AimbotToggle:Set(Config.AimbotEnabled) end)

    local AimbotMethodDropdown = CombatTab:CreateDropdown({
        Name = "Aimbot Method", Options = { "Mouse", "Camera" },
        CurrentOption = { Config.AimbotMethod }, Flag = "AimbotMethod",
        Callback = function(opt) Config.AimbotMethod = type(opt) == "table" and opt[1] or opt end,
    })
    RegRefresh(function() AimbotMethodDropdown:Set({ Config.AimbotMethod }) end)

    local AimbotActDropdown = CombatTab:CreateDropdown({
        Name = "Activation Mode", Options = { "Right Mouse Hold", "Always On", "Left Mouse Hold" },
        CurrentOption = { Config.AimbotActivation }, Flag = "AimbotActivation",
        Callback = function(opt) Config.AimbotActivation = type(opt) == "table" and opt[1] or opt end,
    })
    RegRefresh(function() AimbotActDropdown:Set({ Config.AimbotActivation }) end)

    local AimbotSensiSlider = CombatTab:CreateSlider({
        Name = "Sensitivity", Range = { 1, 100 }, Increment = 1, Suffix = "%",
        CurrentValue = Config.AimbotSensitivity, Flag = "AimbotSensitivity",
        Callback = function(v) Config.AimbotSensitivity = v end,
    })
    RegRefresh(function() AimbotSensiSlider:Set(Config.AimbotSensitivity) end)

    local AimbotFOVSlider = CombatTab:CreateSlider({
        Name = "Aimbot FOV Radius", Range = { 25, 600 }, Increment = 25, Suffix = "px",
        CurrentValue = Config.AimbotFOV, Flag = "AimbotFOV",
        Callback = function(v) Config.AimbotFOV = v end,
    })
    RegRefresh(function() AimbotFOVSlider:Set(Config.AimbotFOV) end)

    local AimbotPredictionToggle = CombatTab:CreateToggle({
        Name = "Prediction", CurrentValue = Config.AimbotPrediction, Flag = "AimbotPrediction",
        Callback = function(v) Config.AimbotPrediction = v end,
    })
    RegRefresh(function() AimbotPredictionToggle:Set(Config.AimbotPrediction) end)

    local AimbotCircleToggle = CombatTab:CreateToggle({
        Name = "Show Prediction Circle", CurrentValue = Config.AimbotDrawCircle, Flag = "AimbotDrawCircle",
        Callback = function(v) Config.AimbotDrawCircle = v end,
    })
    RegRefresh(function() AimbotCircleToggle:Set(Config.AimbotDrawCircle) end)

    local AimbotDrawFOVToggle = CombatTab:CreateToggle({
        Name = "Aimbot FOV", CurrentValue = Config.AimbotDrawFOV, Flag = "AimbotDrawFOV",
        Callback = function(v) Config.AimbotDrawFOV = v end,
    })
    RegRefresh(function() AimbotDrawFOVToggle:Set(Config.AimbotDrawFOV) end)

    CombatTab:CreateSection("Hitbox Expander")
    local MasterHitboxToggle = CombatTab:CreateToggle({
        Name = "Enable Hitbox", CurrentValue = Config.MasterHitbox, Flag = "MasterHitbox",
        Callback = function(v) Config.MasterHitbox = v; if not v then RestoreHitbox() end end,
    })
    RegRefresh(function() MasterHitboxToggle:Set(Config.MasterHitbox) end)

    local SmartHitboxToggle = CombatTab:CreateToggle({
        Name = "Only on mouse hold", CurrentValue = Config.SmartHitbox, Flag = "SmartHitbox",
        Callback = function(v) Config.SmartHitbox = v end,
    })
    RegRefresh(function() SmartHitboxToggle:Set(Config.SmartHitbox) end)

    local HitboxDebugToggle = CombatTab:CreateToggle({
        Name = "Highlight", CurrentValue = Config.HitboxDebug, Flag = "HitboxDebug",
        Callback = function(v) Config.HitboxDebug = v; if not v then ClearDebugHighlights() end end,
    })
    RegRefresh(function() HitboxDebugToggle:Set(Config.HitboxDebug) end)

    local HitboxScaleSlider = CombatTab:CreateSlider({
        Name = "Hitbox Multiplier", Range = { 0, 100 }, Increment = 1, Suffix = "x0.1",
        CurrentValue = math.floor((Config.HitboxScaleMul or Config.HitboxFuselageMul or 2) * 10), Flag = "HitboxScaleMul",
        Callback = function(v)
            Config.HitboxScaleMul = v / 10
            Config.HitboxFuselageMul = v / 10
            Config.HitboxWingMul = v / 10
        end,
    })
    RegRefresh(function() HitboxScaleSlider:Set(math.floor((Config.HitboxScaleMul or Config.HitboxFuselageMul or 2) * 10)) end)
end)

pcall(acquireGameTarget, true)











-- MODULE 08: TRACER TAB

local function DrawTracers(cam)
    if not Config.TracerEnabled then return end
    local now = os.clock()
    local maxLife = Config.TracerLifetime or 0.75
    local bt = Config.TracerThickness or 1.2
    local style = Config.TracerStyle or "Neon"
    local colA = Config.TracerColorA or Color3.fromRGB(0, 255, 230)
    local invMax = 1 / math.max(maxLife, 0.01)

    for i = #State.ActiveTracers, 1, -1 do
        local tr = State.ActiveTracers[i]
        local age = now - tr.created
        if age > maxLife then
            table.remove(State.ActiveTracers, i)
        else
            local alpha = math.clamp(1 - age * invMax, 0, 1)
            local pS, pE = tr.from, tr.to
            local trCol = tr.isLocal and colA or Color3.fromRGB(255, 120, 60)
            local c1, c2 = clipSegmentToCamera(pS, pE, cam)
            if c1 and c2 then
                local s1 = cam:WorldToViewportPoint(c1)
                local s2 = cam:WorldToViewportPoint(c2)
                if s1.Z > 0 and s2.Z > 0 then
                    local v1 = Vector2.new(s1.X, s1.Y)
                    local v2 = Vector2.new(s2.X, s2.Y)
                    if style == "Line" then
                        GetLine(v1, v2, trCol, bt, alpha)
                    elseif style == "Beam" then
                        GetLine(v1, v2, trCol, bt * 1.5, alpha * 0.5)
                        GetLine(v1, v2, Color3.new(1, 1, 1), math.max(bt * 0.5, 1), alpha * 0.9)
                    else -- "Neon"
                        GetLine(v1, v2, trCol, bt * 1.8, alpha * 0.35)
                        GetLine(v1, v2, trCol, bt, alpha * 0.9)
                        GetLine(v1, v2, Color3.new(1, 1, 1), math.max(bt * 0.35, 1), alpha)
                    end
                end
            end
        end
    end
end

-- MODULE 09: VISUAL TAB

local function DrawFOV(center)
    if not Config.DrawFOV or not Config.SilentAimEnabled then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end

    if not State.FOVPosition then
        State.FOVPosition = center
        State.FOVRadius = Config.FOVRadius or 100
        State.FOVColor = Color3.fromRGB(255, 60, 60)
    end

    local targetScreenPos = center
    local targetRadius = Config.FOVRadius or 100
    local isSilentActive = false

    if Config.DynamicFOV then
        local validPart = nil
        if State.CurrentTarget and State.CurrentTargetModel and State.CurrentTargetModel.Parent then
            validPart = validateTarget(cam.CFrame.Position)
        end

        if validPart then
            local pos, onScreen = cam:WorldToViewportPoint(validPart.Position)
            if onScreen and pos.Z > 0 then
                targetScreenPos = Vector2.new(pos.X, pos.Y)

                -- Tự thu nhỏ phóng to kích thước phù hợp theo cự ly
                local dist = math.max(State.TargetDistance or 100, 10)
                local dynamicR = (35 / dist) * (cam.ViewportSize.Y * 0.5)
                targetRadius = math.clamp(dynamicR, 25, Config.FOVRadius or 100)

                -- Kiểm tra vào tầm bắn và silent aim sẵn sàng
                local inDistLimit = true
                if State.LastGunType and ArmamentData and ArmamentData[State.LastGunType] then
                    local gData = ArmamentData[State.LastGunType]
                    if tonumber(gData.DistLimit) and dist > tonumber(gData.DistLimit) then
                        inDistLimit = false
                    end
                end

                if inDistLimit and dist <= Config.MaxDistance and State.RejectedReason == "None" then
                    isSilentActive = true
                end
            end
        else
            targetScreenPos = center
            targetRadius = Config.FOVRadius or 100
        end
    else
        targetScreenPos = center
        targetRadius = Config.FOVRadius or 100
    end

    -- Chuyển đổi giữa các mục tiêu mượt mà bằng Lerp
    local lerpSpeed = 0.22
    State.FOVPosition = State.FOVPosition:Lerp(targetScreenPos, lerpSpeed)
    State.FOVRadius = State.FOVRadius + (targetRadius - State.FOVRadius) * lerpSpeed

    -- Màu đỏ khi chưa/ngoài tầm, đổi sang xanh lá khi vào tầm bắn mà silent được active
    local desiredColor = isSilentActive and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 60, 60)
    State.FOVColor = State.FOVColor:Lerp(desiredColor, 0.2)

    -- Hiển thị vòng tròn FOV Dynamic
    GetCircle(State.FOVPosition, State.FOVRadius, State.FOVColor, false, 1.5, 0.6)
    GetCircle(State.FOVPosition, 2, State.FOVColor, true, 1, 0.8)
end

local function DrawAimLine(cam, vpSize, center)
    if not Config.AimLineEnabled then return end
    if not State.CurrentTargetModel or not State.CurrentTargetModel.Parent then return end
    local part = getTargetPart(State.CurrentTargetModel)
    if not part then return end
    local pos, onScreen = cam:WorldToViewportPoint(part.Position)
    if not onScreen or pos.Z <= 0 then return end
    local targetScreen = Vector2.new(pos.X, pos.Y)
    local startPos = center
    if Plane and Plane.model and Plane.model.PrimaryPart then
        local p2, on2 = cam:WorldToViewportPoint(Plane.model.PrimaryPart.Position)
        if on2 and p2.Z > 0 then startPos = Vector2.new(p2.X, p2.Y) end
    end
    local col = Config.AimLineColor
    local th = Config.AimLineThickness or 1
    GetLine(startPos, targetScreen, col, th * 1.5, 0.25)
    GetLine(startPos, targetScreen, col, th, 0.9)
    GetCircle(targetScreen, 2.5, col, true, 1, 0.9)
end

local function ProcessAimbotAndLeadCircle(cam)
    local targetPart = validateTarget(cam.CFrame.Position)
    if not targetPart then
        acquireGameTarget(false)
        targetPart = validateTarget(cam.CFrame.Position)
    end

    local mousePos = UserInputService:GetMouseLocation()
    local center = cam.ViewportSize * 0.5
    local fovOrigin = (Config.AimbotMethod == "Camera") and center or mousePos

    if Config.AimbotDrawFOV and Config.AimbotEnabled then
        GetCircle(fovOrigin, Config.AimbotFOV, Color3.fromRGB(0, 255, 180), false, 1, 0.4)
    end

    -- Only show lead circle and run aimbot when target is in valid range
    if not targetPart then return end

    local aimPoint, _ = computeAimPoint(cam.CFrame.Position, targetPart, Config.AimbotPrediction)
    if not aimPoint then return end

    local screenPos, onScreen = cam:WorldToViewportPoint(aimPoint)
    if not onScreen or screenPos.Z <= 0 then return end

    local aimScreenPos = Vector2.new(screenPos.X, screenPos.Y)

    -- Display calculated aim point as a small circle (only when in valid range)
    if Config.AimbotDrawCircle then
        GetCircle(aimScreenPos, 6, Color3.fromRGB(0, 255, 180), false, 1.5, 0.9)
        GetCircle(aimScreenPos, 2, Color3.fromRGB(255, 255, 255), true, 1, 1)
    end

    -- Aimbot execution (Mouse movement OR Camera rotation)
    if Config.AimbotEnabled then
        local delta = aimScreenPos - fovOrigin
        local dist = delta.Magnitude

        if dist <= Config.AimbotFOV then
            local shouldAim = false
            if Config.AimbotActivation == "Always On" then
                shouldAim = true
            elseif Config.AimbotActivation == "Right Mouse Hold" then
                shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            elseif Config.AimbotActivation == "Left Mouse Hold" then
                shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            end

            if shouldAim then
                local sensi = math.clamp((Config.AimbotSensitivity or 35) / 100, 0.01, 1)
                if Config.AimbotMethod == "Camera" then
                    local targetCF = CFrame.lookAt(cam.CFrame.Position, aimPoint)
                    cam.CFrame = cam.CFrame:Lerp(targetCF, sensi)
                else
                    local moveX = delta.X * sensi
                    local moveY = delta.Y * sensi
                    if typeof(mousemoverel) == "function" then
                        mousemoverel(moveX, moveY)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while State.Running do
        RunService.RenderStepped:Wait()
        if not State.Running then break end
        local cam = Workspace.CurrentCamera
        if not cam then continue end
        BeginFrame()
        local vpSize = cam.ViewportSize
        local center = Vector2.new(vpSize.X / 2, vpSize.Y / 2)
        local ok1, e1 = pcall(DrawTracers, cam)
        local ok2, e2 = pcall(DrawFOV, center)
        local ok3, e3 = pcall(DrawAimLine, cam, vpSize, center)
        local ok4, e4 = pcall(ProcessAimbotAndLeadCircle, cam)
        local ok5, e5 = pcall(DrawHitFeedback, cam, center)
        if not ok1 then warn("[WOG] Tracers:", e1) end
        if not ok2 then warn("[WOG] FOV:", e2) end
        if not ok3 then warn("[WOG] AimLine:", e3) end
        if not ok4 then warn("[WOG] Aimbot:", e4) end
        if not ok5 then warn("[WOG] HitFeedback:", e5) end
        EndFrame()
    end
end)

-- UI
SafeSelectTab(VisualTab)
pcall(function()
    VisualTab:CreateSection("Bullet Tracer")
    local TracerEnabledToggle = VisualTab:CreateToggle({
        Name = "Enable Tracers", CurrentValue = Config.TracerEnabled, Flag = "TracerEnabled",
        Callback = function(v) Config.TracerEnabled = v end,
    })
    RegRefresh(function() TracerEnabledToggle:Set(Config.TracerEnabled) end)

    local TracerTargetDropdown = VisualTab:CreateDropdown({
        Name = "Tracer Target", Options = { "Local Only", "Enemy" },
        CurrentOption = { Config.TracerTarget }, Flag = "TracerTarget",
        Callback = function(opt) Config.TracerTarget = type(opt) == "table" and opt[1] or opt end,
    })
    RegRefresh(function() TracerTargetDropdown:Set({ Config.TracerTarget }) end)

    local TracerStyleDropdown = VisualTab:CreateDropdown({
        Name = "Style", Options = { "Neon", "Beam", "Line" },
        CurrentOption = { Config.TracerStyle }, Flag = "TracerStyle",
        Callback = function(opt) Config.TracerStyle = type(opt) == "table" and opt[1] or opt end,
    })
    RegRefresh(function() TracerStyleDropdown:Set({ Config.TracerStyle }) end)

    local TracerColorAPicker = VisualTab:CreateColorPicker({
        Name = "Tracer Color", Color = Config.TracerColorA, Flag = "TracerColorA",
        Callback = function(c) Config.TracerColorA = c end,
    })
    RegRefresh(function() TracerColorAPicker:Set(Config.TracerColorA) end)

    local TracerLifetimeSlider = VisualTab:CreateSlider({
        Name = "Lifetime", Range = { 1, 30 }, Increment = 1, Suffix = "x0.1s",
        CurrentValue = math.floor(Config.TracerLifetime * 10), Flag = "TracerLifetime",
        Callback = function(v) Config.TracerLifetime = v / 10 end,
    })
    RegRefresh(function() TracerLifetimeSlider:Set(math.floor(Config.TracerLifetime * 10)) end)

    local TracerThicknessSlider = VisualTab:CreateSlider({
        Name = "Thickness", Range = { 5, 40 }, Increment = 1, Suffix = "x0.1",
        CurrentValue = math.floor(Config.TracerThickness * 10), Flag = "TracerThickness",
        Callback = function(v) Config.TracerThickness = v / 10 end,
    })
    RegRefresh(function() TracerThicknessSlider:Set(math.floor(Config.TracerThickness * 10)) end)

    local NotifyOnHitToggle = VisualTab:CreateToggle({
        Name = "Notify On Hit", CurrentValue = Config.NotifyOnHit, Flag = "NotifyOnHit",
        Callback = function(v) Config.NotifyOnHit = v end,
    })
    RegRefresh(function() NotifyOnHitToggle:Set(Config.NotifyOnHit) end)

    VisualTab:CreateSection("Aim Line")
    local AimLineToggle = VisualTab:CreateToggle({
        Name = "Aim Line", CurrentValue = Config.AimLineEnabled, Flag = "AimLineEnabled",
        Callback = function(v) Config.AimLineEnabled = v end,
    })
    RegRefresh(function() AimLineToggle:Set(Config.AimLineEnabled) end)

    local AimLineColorPicker = VisualTab:CreateColorPicker({
        Name = "Aim Line Color", Color = Config.AimLineColor, Flag = "AimLineColor",
        Callback = function(c) Config.AimLineColor = c end,
    })
    RegRefresh(function() AimLineColorPicker:Set(Config.AimLineColor) end)
end)

-- MODULE 10: PERFORMANCE TAB

local PerfState = {
    saved = false, globalShadows = nil, quality = nil, fogEnd = nil, brightness = nil,
    postFx = {}, parts = {}, decals = {}, particles = {},
}

local function SavePerfBase()
    if PerfState.saved then return end
    PerfState.saved = true
    PerfState.globalShadows = Lighting.GlobalShadows
    pcall(function() PerfState.quality = settings().Rendering.QualityLevel end)
    PerfState.fogEnd = Lighting.FogEnd
    PerfState.brightness = Lighting.Brightness
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") or obj:IsA("Atmosphere") then PerfState.postFx[obj] = obj.Enabled end
    end
end

local function SaveForPotato()
    if next(PerfState.parts) ~= nil then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            PerfState.parts[obj] = { castShadow = obj.CastShadow, material = obj.Material, reflectance = obj.Reflectance }
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            PerfState.decals[obj] = obj.Transparency
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            PerfState.particles[obj] = obj.Enabled
        end
    end
end

local function RestorePerfAll()
    if not PerfState.saved then return end
    PerfState.saved = false
    pcall(function() Lighting.GlobalShadows = PerfState.globalShadows end)
    pcall(function() settings().Rendering.QualityLevel = PerfState.quality end)
    pcall(function() Lighting.FogEnd = PerfState.fogEnd end)
    pcall(function() Lighting.Brightness = PerfState.brightness end)
    for obj, state in pairs(PerfState.postFx) do
        if obj and obj.Parent then pcall(function() obj.Enabled = state end) end
    end
    for obj, state in pairs(PerfState.parts) do
        if obj and obj.Parent then
            pcall(function()
                obj.CastShadow = state.castShadow
                obj.Material = state.material
                obj.Reflectance = state.reflectance
            end)
        end
    end
    for obj, state in pairs(PerfState.decals) do
        if obj and obj.Parent then pcall(function() obj.Transparency = state end) end
    end
    for obj, state in pairs(PerfState.particles) do
        if obj and obj.Parent then pcall(function() obj.Enabled = state end) end
    end
    PerfState.postFx = {}; PerfState.parts = {}; PerfState.decals = {}; PerfState.particles = {}
end

local function ApplyPerfState()
    RestorePerfAll()
    if Config.PotatoModeEnabled then
        SavePerfBase()
        SaveForPotato()
        pcall(function() Lighting.GlobalShadows = false end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level1 end)
        pcall(function() Lighting.FogEnd = 200 end)
        pcall(function() Lighting.Brightness = 1 end)
        for obj in pairs(PerfState.postFx) do if obj and obj.Parent then pcall(function() obj.Enabled = false end) end end
        for obj in pairs(PerfState.parts) do
            if obj and obj.Parent then
                pcall(function()
                    obj.CastShadow = false
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                end)
            end
        end
        for obj in pairs(PerfState.decals) do if obj and obj.Parent then pcall(function() obj.Transparency = 1 end) end end
        for obj in pairs(PerfState.particles) do if obj and obj.Parent then pcall(function() obj.Enabled = false end) end end
    elseif Config.FPSBoostEnabled then
        SavePerfBase()
        pcall(function() Lighting.GlobalShadows = false end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level1 end)
        for obj in pairs(PerfState.postFx) do if obj and obj.Parent then pcall(function() obj.Enabled = false end) end end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then pcall(function() obj.CastShadow = false end) end
        end
    end
end

-- UI
SafeSelectTab(PerformanceTab)
pcall(function()
    PerformanceTab:CreateSection("Performance")
    local FPSBoostToggle = PerformanceTab:CreateToggle({
        Name = "FPS Boost", CurrentValue = Config.FPSBoostEnabled, Flag = "FPSBoostEnabled",
        Callback = function(v) Config.FPSBoostEnabled = v; ApplyPerfState() end,
    })
    RegRefresh(function() FPSBoostToggle:Set(Config.FPSBoostEnabled) end)

    local PotatoToggle = PerformanceTab:CreateToggle({
        Name = "Potato Graphics", CurrentValue = Config.PotatoModeEnabled, Flag = "PotatoModeEnabled",
        Callback = function(v) Config.PotatoModeEnabled = v; ApplyPerfState() end,
    })
    RegRefresh(function() PotatoToggle:Set(Config.PotatoModeEnabled) end)
end)











-- MODULE 11: CONFIG TAB

SafeSelectTab(ConfigTab)
pcall(function()
    ConfigTab:CreateSection("Auto-Apply Config")
    local AutoApplyToggle = ConfigTab:CreateToggle({
        Name = "Auto Apply Last Used Config", CurrentValue = Config.AutoApplyConfig, Flag = "AutoApplyConfig",
        Callback = function(v)
            Config.AutoApplyConfig = v
            if v then SaveLatestConfig("Current Session") end
        end,
    })
    RegRefresh(function() AutoApplyToggle:Set(Config.AutoApplyConfig) end)

    ConfigTab:CreateSection("Save Config")

    local ConfigNameValue = ""
    ConfigTab:CreateInput({
        Name = "Config Name", PlaceholderText = "Enter config name",
        RemoveTextAfterFocusLost = false, Flag = "ConfigNameInput",
        Callback = function(txt) ConfigNameValue = txt end,
    })

    local RefreshConfigDropdown
    local ConfigDropdown
    local SelectedConfig = ""

    ConfigTab:CreateButton({
        Name = "Save Current Config",
        Callback = function()
            if ConfigNameValue == "" then Notify("Config", "Enter a name first", Color3.fromRGB(255, 120, 60)); return end
            if SaveConfig(ConfigNameValue) then
                Notify("Config Saved", ConfigNameValue, Color3.fromRGB(80, 210, 130))
                if RefreshConfigDropdown then RefreshConfigDropdown() end
            else Notify("Config Save Failed", ConfigNameValue, Color3.fromRGB(255, 80, 80)) end
        end,
    })

    ConfigTab:CreateSection("Load / Delete Config")
    ConfigDropdown = ConfigTab:CreateDropdown({
        Name = "Saved Configs", Options = ListConfigs(), CurrentOption = { "" }, Flag = "SelectedConfig",
        Callback = function(opt) SelectedConfig = type(opt) == "table" and opt[1] or opt end,
    })

    RefreshConfigDropdown = function()
        local names = ListConfigs()
        if #names == 0 then names = { "<empty>" } end
        pcall(function() ConfigDropdown:Refresh(names, { SelectedConfig ~= "" and SelectedConfig or names[1] }) end)
    end
    RefreshConfigDropdown()

    ConfigTab:CreateButton({
        Name = "Load Selected Config",
        Callback = function()
            if SelectedConfig == "" or SelectedConfig == "<empty>" then Notify("Config", "Select a config first", Color3.fromRGB(255, 120, 60)); return end
            if LoadConfig(SelectedConfig) then
                RefreshUI(); ApplyPerfState()
                Notify("Config Loaded", SelectedConfig, Color3.fromRGB(80, 210, 130))
            else Notify("Config Load Failed", SelectedConfig, Color3.fromRGB(255, 80, 80)) end
        end,
    })

    ConfigTab:CreateButton({
        Name = "Delete Selected Config",
        Callback = function()
            if SelectedConfig == "" or SelectedConfig == "<empty>" then Notify("Config", "Select a config first", Color3.fromRGB(255, 120, 60)); return end
            if DeleteConfig(SelectedConfig) then
                Notify("Config Deleted", SelectedConfig, Color3.fromRGB(255, 190, 60))
                SelectedConfig = ""; RefreshConfigDropdown()
            else Notify("Delete Failed", SelectedConfig, Color3.fromRGB(255, 80, 80)) end
        end,
    })

    ConfigTab:CreateButton({
        Name = "Refresh List",
        Callback = function()
            RefreshConfigDropdown()
            Notify("Config", "List refreshed", Color3.fromRGB(80, 210, 130))
        end,
    })

    ConfigTab:CreateSection("About")
    ConfigTab:CreateParagraph({ Title = "Config Storage", Content = "Configs stored in folder: WOG_Configs." })

    task.spawn(function()
        task.wait(0.6)
        if Config.AutoApplyConfig then
            local ok, lastName = LoadLatestConfig()
            if ok then
                RefreshUI()
                ApplyPerfState()
                Notify("Auto Config", "Applied: " .. tostring(lastName or "Recent"), Color3.fromRGB(80, 210, 130))
            end
        end
        while State.Running do
            task.wait(10)
            if Config.AutoApplyConfig then
                SaveLatestConfig()
            end
        end
    end)
end)











-- MODULE 12: SESSION TAB

local API = {}

function API.SetEnabled(value)
    Config.SilentAimEnabled = not not value
    if Config.SilentAimEnabled then acquireGameTarget(true) end
end
function API.SetFOV(value) Config.FOVRadius = math.clamp(tonumber(value) or Config.FOVRadius, 25, 2000) end
function API.SetTracer(value) Config.TracerEnabled = not not value end

function API.Unload()
    State.Running = false
    Config.TracerEnabled = false; Config.DrawFOV = false
    Config.MasterHitbox = false; Config.AimbotEnabled = false; Config.AimLineEnabled = false
    if Weapon.new_bullet ~= OriginalNewBullet then Weapon.new_bullet = OriginalNewBullet end
    for _, connection in ipairs(State.Connections) do pcall(function() connection:Disconnect() end) end
    table.clear(State.Connections)
    State.ActiveTracers = {}
    RestoreHitbox()
    RemoveAllDrawings()
    RestorePerfAll()
    if type(Controls.clear_aim_assist) == "function" then pcall(function() Controls.clear_aim_assist() end) end
    pcall(function() Rayfield:Destroy() end)
    pcall(function()
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui.Name == "Rayfield" or gui.Name:find("Rayfield") then gui:Destroy() end
        end
    end)
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui.Name == "Rayfield" or gui.Name:find("Rayfield") then gui:Destroy() end
            end
        end
    end)
    if notifGui and notifGui.Parent then notifGui:Destroy() end
    ENV.WOG_TRACER = nil
end

API.Config = Config
API.State = State
API.Weapon = Weapon
API.Controls = Controls
ENV.WOG_TRACER = API

SafeSelectTab(SessionTab)
pcall(function()
    SessionTab:CreateSection("Session")
    SessionTab:CreateButton({
        Name = "Unload Script",
        Callback = function()
            if ENV.WOG_TRACER and ENV.WOG_TRACER.Unload then ENV.WOG_TRACER.Unload() end
        end,
    })
end)

SafeSelectTab(CombatTab)
