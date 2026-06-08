
你好，陌生人，我最近注意到我在b站一个优质的up主下的开源项目有人在使用且改源，在此我不反对各位使用这个脚本已经改源，但需要注意的是，这个项目使用的国内豆包所做，并无法避免一些问题，所以您如果有需要，请优化部分例如自瞄的逻辑以及实现方式，因此如果您将此脚本传出去也请不要删除这段文字，谢谢！









local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TulipUI"
screenGui.Parent = PlayerGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999

local espOverlay = Instance.new("ScreenGui")
espOverlay.Name = "EspOverlay"
espOverlay.Parent = CoreGui
espOverlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espOverlay.DisplayOrder = 99999
espOverlay.Enabled = true

local correctKey = "tulip2026"

local Settings = {
    Esp = false,
    DynamicAimbot = false,
    CursorAimbot = false,
    AimPart = "Head",
    BlackHole = false,
}

local lockedPlayer = nil
local blackHoleConnection = nil

--=============================================
-- 黑洞：吸建筑、实体、墙体
--=============================================
local function StartBlackHole()
    if blackHoleConnection then blackHoleConnection:Disconnect() end
    blackHoleConnection = RunService.Heartbeat:Connect(function()
        if not Settings.BlackHole then return end
        local char = Player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local center = root.Position
        local maxRange = 20
        local maxRangeSq = maxRange * maxRange

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj:CanSetNetworkOwnership() then
                local success = pcall(function()
                    obj:SetNetworkOwner(Player)
                end)
                if not success then continue end

                local pos = obj.Position
                local delta = pos - center
                local distSq = delta.Magnitude

                if distSq < maxRangeSq then
                    local dir = delta.Unit
                    local pullForce = 25
                    local rotateForce = 30

                    local angle = tick() * 10
                    local orbit = Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * 12

                    obj.Velocity = (orbit - dir * pullForce)
                    obj.RotVelocity = Vector3.new(0, rotateForce, 0)
                end
            end
        end
    end)
end

local function StopBlackHole()
    Settings.BlackHole = false
    if blackHoleConnection then
        blackHoleConnection:Disconnect()
        blackHoleConnection = nil
    end
end

--=============================================
-- 动态自瞄绘制
--=============================================
local circle, line
local BASE = 50
local MIN = 25
local STICK_MARGIN = 1.3
local currentRadius = BASE
local currentTarget = nil
local hue = 0

local function initAimbotDrawing()
    if circle then circle:Remove() end
    if line then line:Remove() end

    circle = Drawing.new("Circle")
    circle.Visible = false
    circle.Color = Color3.new(1,0,0)
    circle.Thickness = 1
    circle.Filled = false
    circle.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y/2)
    circle.Radius = BASE

    line = Drawing.new("Line")
    line.Visible = false
    line.Color = Color3.new(1,0,0)
    line.Thickness = 1
    line.From = circle.Position
end

-- ==============================================
-- 跟枪速度优化
-- ==============================================
local function getAimStrength(distance)
    local d = math.floor(distance / 5) * 5
    if d <= 5 then
        return 0.58
    elseif d <= 10 then
        return 0.53
    elseif d <= 15 then
        return 0.48
    elseif d <= 20 then
        return 0.43
    elseif d <= 25 then
        return 0.38
    elseif d <= 30 then
        return 0.33
    elseif d <= 40 then
        return 0.28
    elseif d <= 50 then
        return 0.23
    elseif d <= 70 then
        return 0.18
    else
        return 0.14
    end
end

local function isVisible(target)
    local char = Player.Character
    if not char or not target then return false end
    local origin = workspace.CurrentCamera.CFrame.Position
    local dir = target.Position - origin
    local ray = Ray.new(origin, dir.Unit * dir.Magnitude)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {char, target.Parent})
    return hit == nil
end

local function getTargetInCircle()
    local cam = workspace.CurrentCamera
    if not cam then return nil end

    if lockedPlayer then
        if lockedPlayer.Character then
            local hum = lockedPlayer.Character:FindFirstChildOfClass("Humanoid")
            local part = lockedPlayer.Character:FindFirstChild(Settings.AimPart)
            if hum and part and hum.Health > 0 then
                if isVisible(part) then
                    return part
                end
            end
        end
        return nil
    end

    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local closest = nil
    local minDist = 9999

    for _, plr in pairs(Players:GetPlayers()) do
        if plr == Player then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local part = char:FindFirstChild(Settings.AimPart)
        if hum and part and hum.Health > 0 then
            local pos, onScreen = cam:WorldToViewportPoint(part.Position)
            if onScreen and pos.Z > 0 and isVisible(part) then
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if dist < currentRadius * STICK_MARGIN and dist < minDist then
                    minDist = dist
                    closest = part
                end
            end
        end
    end
    return closest
end

local function getTargetAtCursor()
    local cam = workspace.CurrentCamera
    if not cam then return nil end

    if lockedPlayer then
        if lockedPlayer.Character then
            local hum = lockedPlayer.Character:FindFirstChildOfClass("Humanoid")
            local part = lockedPlayer.Character:FindFirstChild(Settings.AimPart)
            if hum and part and hum.Health > 0 and isVisible(part) then
                return part
            end
        end
        return nil
    end

    local cursorPos = UserInputService:GetMouseLocation()
    local closest = nil
    local minDist = 200

    for _, plr in pairs(Players:GetPlayers()) do
        if plr == Player then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local part = char:FindFirstChild(Settings.AimPart)
        if hum and part and hum.Health > 0 then
            local pos, onScreen = cam:WorldToViewportPoint(part.Position)
            if onScreen and pos.Z > 0 and isVisible(part) then
                local dist = (Vector2.new(pos.X, pos.Y) - cursorPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = part
                end
            end
        end
    end
    return closest
end

local function aimbotLoop()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)

    while task.wait() do
        if not Settings.DynamicAimbot and not Settings.CursorAimbot then
            if circle then circle.Visible = false end
            if line then line.Visible = false end
            currentTarget = nil
            continue
        end

        if Settings.DynamicAimbot then
            circle.Position = center
            line.From = center
            currentTarget = getTargetInCircle()
        elseif Settings.CursorAimbot then
            local cursorPos = UserInputService:GetMouseLocation()
            circle.Position = cursorPos
            line.From = cursorPos
            currentTarget = getTargetAtCursor()
        end

        if currentTarget then
            local tpos, onScreen = cam:WorldToViewportPoint(currentTarget.Position)
            if not onScreen or tpos.Z < 0 or not isVisible(currentTarget) then
                currentTarget = nil
            end
        end

        if currentTarget then
            currentRadius = currentRadius + (MIN - currentRadius) * 0.12
            hue = (hue + 0.01) % 1
            circle.Color = Color3.fromHSV(hue, 0.9, 1)
            line.Color = circle.Color
            circle.Visible = true
            local tpos2 = cam:WorldToViewportPoint(currentTarget.Position)
            line.To = Vector2.new(tpos2.X, tpos2.Y)
            line.Visible = true
        else
            currentRadius = currentRadius + (BASE - currentRadius) * 0.12
            circle.Color = Color3.new(1,0,0)
            circle.Visible = true
            line.Visible = false
        end
        circle.Radius = currentRadius
    end
end

local function aimbotAimLoop()
    while task.wait() do
        if not Settings.DynamicAimbot and not Settings.CursorAimbot then continue end
        if not currentTarget then continue end
        if not isVisible(currentTarget) then
            currentTarget = nil
            continue
        end

        local cam = workspace.CurrentCamera
        local camPos = cam.CFrame.Position
        local tarPos = currentTarget.Position

        if lockedPlayer then
            cam.CFrame = CFrame.lookAt(camPos, tarPos)
        else
            local dist = (camPos - tarPos).Magnitude
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(camPos, tarPos), getAimStrength(dist))
        end
    end
end

initAimbotDrawing()
task.spawn(aimbotLoop)
task.spawn(aimbotAimLoop)

--=============================================
-- UI 工具
--=============================================
local function addHighlightToPlayer(p)
    if p == Player then return end
    if not p.Character then return end
    if p.Character:FindFirstChild("ESP") then p.Character.ESP:Destroy() end
    local e = Instance.new("Highlight")
    e.Name = "ESP"
    e.FillColor = Color3.new(1,0,0)
    e.OutlineColor = Color3.new(1,1,1)
    e.FillTransparency = 0.5
    e.OutlineTransparency = 0
    e.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    e.Adornee = p.Character
    e.Parent = p.Character
end

local function enableEsp()
    if Settings.Esp then return end
    Settings.Esp = true
    for _, p in pairs(Players:GetPlayers()) do addHighlightToPlayer(p) end
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function() task.wait(1) if Settings.Esp then addHighlightToPlayer(plr) end end)
    end)
end

local function disableEsp()
    if not Settings.Esp then return end
    Settings.Esp = false
    for _, p in pairs(Players:GetPlayers()) do if p.Character and p.Character:FindFirstChild("ESP") then p.Character.ESP:Destroy() end end
end

--=============================================
-- 登录界面
--=============================================
local card = Instance.new("Frame")
card.Name = "LoginCard"
card.Parent = screenGui
card.Size = UDim2.new(0,300,0,200)
card.Position = UDim2.new(0.5,0,0.5,0)
card.AnchorPoint = Vector2.new(0.5,0.5)
card.BackgroundColor3 = Color3.new(1,1,1)
Instance.new("UICorner", card).CornerRadius = UDim.new(0,16)

local titleText = Instance.new("TextLabel")
titleText.Parent = card
titleText.Size = UDim2.new(1,0,0,35)
titleText.Position = UDim2.new(0,0,0,15)
titleText.BackgroundTransparency = 1
titleText.RichText = true
titleText.Text = '<font color="rgb(255,105,180)">T</font>ulip郁金香'
titleText.TextColor3 = Color3.new(0,0,0)
titleText.TextSize = 28
titleText.Font = Enum.Font.SourceSansBold

local inputBox = Instance.new("TextBox")
inputBox.Parent = card
inputBox.Size = UDim2.new(0,260,0,40)
inputBox.Position = UDim2.new(0.5,0,0.5,-5)
inputBox.AnchorPoint = Vector2.new(0.5,0.5)
inputBox.BackgroundColor3 = Color3.fromRGB(245,245,245)
inputBox.PlaceholderText = "Enter the card PIN"
inputBox.Text = ""
inputBox.TextSize = 16
Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0,8)

local tipText = Instance.new("TextLabel")
tipText.Parent = card
tipText.Size = UDim2.new(0,260,0,25)
tipText.Position = UDim2.new(0.5,0,0.5,25)
tipText.AnchorPoint = Vector2.new(0.5,0.5)
tipText.BackgroundTransparency = 1
tipText.TextSize = 14
tipText.Visible = false

local enableBtn = Instance.new("TextButton")
enableBtn.Parent = card
enableBtn.Size = UDim2.new(0,120,0,40)
enableBtn.Position = UDim2.new(0,20,1,-60)
enableBtn.BackgroundColor3 = Color3.fromRGB(240,240,240)
enableBtn.Text = "Login"
enableBtn.TextSize = 16
Instance.new("UICorner", enableBtn).CornerRadius = UDim.new(0,8)

local closeBtn = Instance.new("TextButton")
closeBtn.Parent = card
closeBtn.Size = UDim2.new(0,120,0,40)
closeBtn.Position = UDim2.new(1,-140,1,-60)
closeBtn.BackgroundColor3 = Color3.fromRGB(240,240,240)
closeBtn.Text = "off"
closeBtn.TextSize = 16
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)

closeBtn.MouseButton1Click:Connect(function() card.Visible = false end)

--=============================================
-- 开关卡片
--=============================================
local function createCardSwitch(parent, text, y, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,-20,0,48)
    frame.Position = UDim2.new(0.5,0,0,y)
    frame.AnchorPoint = Vector2.new(0.5,0)
    frame.BackgroundColor3 = Color3.fromRGB(248,248,248)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)

    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.Size = UDim2.new(0.7,-20,1,0)
    label.Position = UDim2.new(0,18,0.5,0)
    label.AnchorPoint = Vector2.new(0,0.5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextSize = 18
    label.Font = Enum.Font.SourceSansSemibold

    local btn = Instance.new("TextButton")
    btn.Parent = frame
    btn.Size = UDim2.new(0,46,0,24)
    btn.Position = UDim2.new(1,-20,0.5,0)
    btn.AnchorPoint = Vector2.new(1,0.5)
    btn.BackgroundColor3 = Color3.fromRGB(220,220,220)
    btn.Text = ""
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,12)

    local dot = Instance.new("Frame")
    dot.Parent = btn
    dot.Size = UDim2.new(0,16,0,16)
    dot.Position = UDim2.new(0,4,0.5,0)
    dot.AnchorPoint = Vector2.new(0,0.5)
    dot.BackgroundColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0,8)

    local on = false
    local tw = TweenInfo.new(0.15)
    btn.MouseButton1Click:Connect(function()
        on = not on
        callback(on)
        if on then
            TweenService:Create(btn, tw, {BackgroundColor3 = Color3.fromRGB(255,105,180)}):Play()
            TweenService:Create(dot, tw, {Position = UDim2.new(1,-4,0.5,0), AnchorPoint = Vector2.new(1,0.5)}):Play()
        else
            TweenService:Create(btn, tw, {BackgroundColor3 = Color3.fromRGB(220,220,220)}):Play()
            TweenService:Create(dot, tw, {Position = UDim2.new(0,4,0.5,0), AnchorPoint = Vector2.new(0,0.5)}):Play()
        end
    end)
    return frame
end

--=============================================
-- 主窗口
--=============================================
local function createMainWindow()
    card.Visible = false

    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Parent = screenGui
    main.Size = UDim2.new(0,620,0,290)
    main.Position = UDim2.new(0.5,0,0.5,0)
    main.AnchorPoint = Vector2.new(0.5,0.5)
    main.BackgroundColor3 = Color3.new(1,1,1)
    main.Active = true
    main.Draggable = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0,16)

    local title = Instance.new("TextLabel")
    title.Parent = main
    title.Size = UDim2.new(1,0,0,40)
    title.Position = UDim2.new(0,0,0,0)
    title.BackgroundTransparency = 1
    title.RichText = true
    title.Text = '<font color="rgb(255,105,180)">T</font>ulip UI'
    title.TextSize = 24
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Center

    local sidebar = Instance.new("Frame")
    sidebar.Parent = main
    sidebar.Size = UDim2.new(0,140,1,-60)
    sidebar.Position = UDim2.new(0,15,0,45)
    sidebar.BackgroundColor3 = Color3.fromRGB(248,248,248)
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0,10)

    local function tab(txt, y)
        local b = Instance.new("TextButton")
        b.Parent = sidebar
        b.Size = UDim2.new(1,-16,0,36)
        b.Position = UDim2.new(0.5,0,0,y)
        b.AnchorPoint = Vector2.new(0.5,0)
        b.BackgroundColor3 = Color3.fromRGB(240,240,240)
        b.Text = txt
        b.TextSize = 15
        b.Font = Enum.Font.SourceSansSemibold
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
        return b
    end

    local t1 = tab("主页", 12)
    local t2 = tab("通用", 55)
    local t3 = tab("战斗", 98)
    local t4 = tab("用户", 141)

    local content = Instance.new("Frame")
    content.Parent = main
    content.Size = UDim2.new(1,-175,1,-90)
    content.Position = UDim2.new(0,160,0,40)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true

    local pages = {
        Home = Instance.new("Frame"),
        General = Instance.new("Frame"),
        Combat = Instance.new("Frame"),
        User = Instance.new("Frame")
    }
    for _, p in pairs(pages) do
        p.Size = UDim2.new(1,0,1,0)
        p.BackgroundTransparency = 1
        p.Parent = content
        p.Visible = false
    end
    pages.Home.Visible = true

    local function show(p)
        for _, k in pairs(pages) do k.Visible = false end
        p.Visible = true
    end
    t1.MouseButton1Click:Connect(function() show(pages.Home) end)
    t2.MouseButton1Click:Connect(function() show(pages.General) end)
    t3.MouseButton1Click:Connect(function() show(pages.Combat) end)
    t4.MouseButton1Click:Connect(function() show(pages.User) end)

    -- 主页
    local discordBtn = Instance.new("TextButton")
    discordBtn.Parent = pages.Home
    discordBtn.Size = UDim2.new(0, 220, 0, 50)
    discordBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
    discordBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    discordBtn.TextColor3 = Color3.new(1,1,1)
    discordBtn.Text = "加入 Discord 社区"
    discordBtn.TextSize = 18
    discordBtn.Font = Enum.Font.SourceSansBold
    discordBtn.BorderSizePixel = 0
    Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, 12)

    -- 通用
    createCardSwitch(pages.General, "加速", 20, function(v)
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v and 64 or 16 end
    end)

    createCardSwitch(pages.General, "黑洞", 70, function(v)
        Settings.BlackHole = v
        if v then
            StartBlackHole()
        else
            StopBlackHole()
        end
    end)

    -- 用户
    createCardSwitch(pages.User, "ESP透视", 20, function(v)
        if v then enableEsp() else disableEsp() end
    end)

    -- ===================== 战斗页面 =====================
    createCardSwitch(pages.Combat, "动态自瞄", 20, function(v)
        Settings.DynamicAimbot = v
        if v then
            Settings.CursorAimbot = false
        end
    end)

    createCardSwitch(pages.Combat, "光标自瞄", 70, function(v)
        Settings.CursorAimbot = v
        if v then
            Settings.DynamicAimbot = false
        end
    end)

    local modeCard = Instance.new("Frame")
    modeCard.Size = UDim2.new(1,-20,0,50)
    modeCard.Position = UDim2.new(0.5,0,0,125)
    modeCard.AnchorPoint = Vector2.new(0.5,0)
    modeCard.BackgroundColor3 = Color3.fromRGB(248,248,248)
    modeCard.Parent = pages.Combat
    Instance.new("UICorner", modeCard).CornerRadius = UDim.new(0,12)

    local btnAll = Instance.new("TextButton")
    btnAll.Size = UDim2.new(0.5,-5,1,0)
    btnAll.Position = UDim2.new(0,0,0,0)
    btnAll.BackgroundTransparency = 1
    btnAll.Text = "无差别锁敌"
    btnAll.TextSize = 16
    btnAll.Font = Enum.Font.SourceSansSemibold
    btnAll.Parent = modeCard

    local btnTarget = Instance.new("TextButton")
    btnTarget.Size = UDim2.new(0.5,-5,1,0)
    btnTarget.Position = UDim2.new(0.5,0,0,0)
    btnTarget.BackgroundTransparency = 1
    btnTarget.Text = "目标锁敌"
    btnTarget.TextSize = 16
    btnTarget.Font = Enum.Font.SourceSansSemibold
    btnTarget.Parent = modeCard

    local line = Instance.new("Frame")
    line.Size = UDim2.new(0,1,0.6,0)
    line.Position = UDim2.new(0.5,0,0.5,0)
    line.AnchorPoint = Vector2.new(0.5,0.5)
    line.BackgroundColor3 = Color3.fromRGB(210,210,210)
    line.Parent = modeCard

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1,-20,0,0)
    scrollFrame.Position = UDim2.new(0.5,0,1,-20)
    scrollFrame.AnchorPoint = Vector2.new(0.5,1)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(248,248,248)
    scrollFrame.BackgroundTransparency = 0
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ClipsDescendants = true
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200,200,200)
    scrollFrame.CanvasSize = UDim2.new(0,0,0,0)
    scrollFrame.Parent = pages.Combat
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0,12)
    scrollCorner.Parent = scrollFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = scrollFrame
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0,4)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Top

    local clickingList = false
    local expanded = false

    local function refreshList()
        for _,c in pairs(scrollFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local total = 0
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= Player then
                local item = Instance.new("TextButton")
                item.Size = UDim2.new(1,-12,0,30)
                item.BackgroundTransparency = 1
                item.Text = plr.Name
                item.TextSize = 14
                item.Font = Enum.Font.SourceSansSemibold
                item.TextColor3 = Color3.fromRGB(40,40,40)
                item.Parent = scrollFrame
                item.MouseButton1Click:Connect(function()
                    lockedPlayer = plr
                    btnTarget.Text = "目标: "..plr.Name
                    expanded = false
                    TweenService:Create(scrollFrame, TweenInfo.new(0.25), {Size = UDim2.new(1,-20,0,0)}):Play()
                end)
                item.MouseButton1Down:Connect(function()
                    clickingList = true
                end)
                item.MouseButton1Up:Connect(function()
                    task.wait(0.05)
                    clickingList = false
                end)
                total += 34
            end
        end
        scrollFrame.CanvasSize = UDim2.new(0,0,0,total)
    end

    btnTarget.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            refreshList()
            TweenService:Create(scrollFrame, TweenInfo.new(0.25), {Size = UDim2.new(1,-20,0,85)}):Play()
        else
            TweenService:Create(scrollFrame, TweenInfo.new(0.25), {Size = UDim2.new(1,-20,0,0)}):Play()
        end
    end)

    btnAll.MouseButton1Click:Connect(function()
        lockedPlayer = nil
        btnTarget.Text = "目标锁敌"
        expanded = false
        TweenService:Create(scrollFrame, TweenInfo.new(0.25), {Size = UDim2.new(1,-20,0,0)}):Play()
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if expanded and not clickingList then
                expanded = false
                TweenService:Create(scrollFrame, TweenInfo.new(0.25), {Size = UDim2.new(1,-20,0,0)}):Play()
            end
        end
    end)

    -- ============================================================
    -- 关闭与隐藏按钮
    -- ============================================================
    local closeWin = Instance.new("TextButton")
    closeWin.Parent = main
    closeWin.Size = UDim2.new(0,85,0,32)
    closeWin.Position = UDim2.new(1,-12,1,-12)
    closeWin.AnchorPoint = Vector2.new(1,1)
    closeWin.BackgroundColor3 = Color3.fromRGB(255,105,180)
    closeWin.Text = "关闭面板"
    closeWin.TextColor3 = Color3.new(1,1,1)
    closeWin.TextSize = 12
    closeWin.Font = Enum.Font.SourceSansBold
    Instance.new("UICorner", closeWin).CornerRadius = UDim.new(0,6)

    local hideWin = Instance.new("TextButton")
    hideWin.Parent = main
    hideWin.Size = UDim2.new(0,85,0,32)
    hideWin.Position = UDim2.new(1,-107,1,-12)
    hideWin.AnchorPoint = Vector2.new(1,1)
    hideWin.BackgroundColor3 = Color3.fromRGB(240,240,240)
    hideWin.Text = "隐藏"
    hideWin.TextSize = 12
    hideWin.Font = Enum.Font.SourceSansSemibold
    Instance.new("UICorner", hideWin).CornerRadius = UDim.new(0,6)

    local miniBtn = Instance.new("TextButton")
    miniBtn.Parent = screenGui
    miniBtn.Size = UDim2.new(0,200,0,40)
    miniBtn.Position = UDim2.new(0.5,0,0,-37)
    miniBtn.AnchorPoint = Vector2.new(0.5,0)
    miniBtn.BackgroundColor3 = Color3.new(1,1,1)
    miniBtn.RichText = true
    miniBtn.Text = '<font color="rgb(255,105,180)">T</font>ulip'
    miniBtn.TextSize = 20
    miniBtn.Font = Enum.Font.SourceSansBold
    miniBtn.Visible = false
    miniBtn.Active = true
    miniBtn.Draggable = true
    miniBtn.BorderSizePixel = 0
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0,16)

    -- ===================== 动画：隐藏 / 显示 / 关闭 =====================
    local origPos = main.Position
    local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local miniAnim = TweenInfo.new(0.25)

    local miniOrigSize = miniBtn.Size
    local miniOrigPos = miniBtn.Position

    -- 隐藏
    hideWin.MouseButton1Click:Connect(function()
        main.Visible = false
        miniBtn.Visible = true
        miniBtn.Size = UDim2.new(0,0,0,40)
        miniBtn.Position = UDim2.new(0.5,0,0,-37)
        miniBtn.BackgroundTransparency = 1
        miniBtn.TextTransparency = 1

        TweenService:Create(miniBtn, miniAnim, {
            Size = miniOrigSize,
            Position = miniOrigPos,
            BackgroundTransparency = 0,
            TextTransparency = 0
        }):Play()
    end)

    -- 点击小按钮显示
    miniBtn.MouseButton1Click:Connect(function()
        TweenService:Create(miniBtn, miniAnim, {
            Size = UDim2.new(0,0,0,40),
            Position = UDim2.new(0.5,0,0,-37),
            BackgroundTransparency = 1,
            TextTransparency = 1
        }):Play()
        task.wait(0.25)
        miniBtn.Visible = false
        main.Visible = true
    end)

    -- 关闭
    closeWin.MouseButton1Click:Connect(function()
        Settings.DynamicAimbot = false
        Settings.CursorAimbot = false
        Settings.BlackHole = false
        StopBlackHole()
        lockedPlayer = nil
        disableEsp()
        main.Visible = false
        miniBtn.Visible = false
    end)
end

enableBtn.MouseButton1Click:Connect(function()
    tipText.Visible = true
    if inputBox.Text == correctKey then
        tipText.Text = "验证成功"
        tipText.TextColor3 = Color3.new(0,0.8,0)
        task.wait(0.3)
        createMainWindow()
    else
        tipText.Text = "无效"
        tipText.TextColor3 = Color3.new(1,0,0)
    end
    task.wait(1)
    tipText.Visible = false
end)
