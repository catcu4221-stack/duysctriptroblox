--[[
    TPD VIP PRO MENU - FIRE ULTIMATE EDITION (XENO LAPTOP/PC EDITION)
    Author: Gemini AI (Customized for TPD)
    Optimized for Xeno Executor & PC Mouse/Keyboard
--]]

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCameraS

-- Xóa GUI cũ tránh lặp
local targetParent = gethui and gethui() or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
if targetParent:FindFirstChild("TPDVipMenu") then
    targetParent.TPDVipMenu:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TPDVipMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = targetParent

local ESPFolder = Instance.new("Folder", ScreenGui)
ESPFolder.Name = "ESP_Container"

-- ================= TÙY CHỈNH MÀU SẮC =================
local ThemeColor = Color3.fromRGB(255, 45, 45)
local UIStrokesList = {}
local ParticleList = {}
local ActiveTpButtons = {}

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end

local function addStroke(parent)
    local stroke = Instance.new("UIStroke")
    stroke.Color = ThemeColor
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    table.insert(UIStrokesList, stroke)
    return stroke
end

-- ================= KHUNG KÉO THẢ (WRAPPER) =================
local Wrapper = Instance.new("Frame", ScreenGui)
Wrapper.Name = "Wrapper"
Wrapper.Size = UDim2.new(0, 360, 0, 260)
Wrapper.Position = UDim2.new(0.5, -180, 0.4, -130)
Wrapper.BackgroundTransparency = 1

-- ================= LOGO CHỮ "A" NỔI VÀ NGỌN LỬA =================
local LogoBtn = Instance.new("TextButton", Wrapper)
LogoBtn.Name = "LogoBtn"
LogoBtn.Size = UDim2.new(0, 55, 0, 55)
LogoBtn.Position = UDim2.new(0.5, -27, 0.5, -27)
LogoBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
LogoBtn.Text = "A"
LogoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoBtn.Font = Enum.Font.GothamBold
LogoBtn.TextSize = 28
LogoBtn.AutoButtonColor = false
addCorner(LogoBtn, 28)

local LogoStroke = addStroke(LogoBtn)
LogoStroke.Thickness = 3

local LogoGradient = Instance.new("UIGradient", LogoStroke)
LogoGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.5, ThemeColor),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 0))
})

local FlameContainer = Instance.new("Frame", LogoBtn)
FlameContainer.Size = UDim2.new(1, 0, 1, 0)
FlameContainer.BackgroundTransparency = 1
FlameContainer.ZIndex = 0

for i = 1, 8 do
    local p = Instance.new("Frame", FlameContainer)
    p.Size = UDim2.new(0, math.random(5, 8), 0, math.random(5, 8))
    p.BackgroundColor3 = ThemeColor
    p.BorderSizePixel = 0
    p.BackgroundTransparency = 0.3
    addCorner(p, 4)
    
    local pGradient = Instance.new("UIGradient", p)
    pGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
        ColorSequenceKeypoint.new(1, ThemeColor)
    })

    table.insert(ParticleList, {
        frame = p,
        angle = (math.pi * 2 / 8) * i,
        speed = math.random(15, 30) / 10,
        dist = math.random(22, 28)
    })
end

local FOVCircle = Drawing.new("Circle")

local function updateTheme(newColor)
    ThemeColor = newColor
    for _, stroke in ipairs(UIStrokesList) do
        if stroke and stroke.Parent then stroke.Color = newColor end
    end
    LogoGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, ThemeColor),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 0))
    })
    for _, item in ipairs(ParticleList) do
        item.frame.BackgroundColor3 = newColor
    end
    if FOVCircle then
        FOVCircle.Color = newColor
    end
end

RunService.RenderStepped:Connect(function()
    LogoGradient.Rotation = (LogoGradient.Rotation + 4) % 360
    for _, item in ipairs(ParticleList) do
        item.angle = item.angle + 0.05
        local radius = item.dist + math.sin(tick() * item.speed) * 4
        local x = math.cos(item.angle) * radius
        local y = math.sin(item.angle) * radius - 4
        item.frame.Position = UDim2.new(0.5, x - 4, 0.5, y - 4)
    end
end)

-- ================= MAIN FRAME & HEADER =================
local MainFrame = Instance.new("Frame", Wrapper)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
MainFrame.Visible = false
addCorner(MainFrame, 12)
addStroke(MainFrame)

local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🔥 TPD VIP PRO HUB (XENO PC)"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -31, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
addCorner(CloseBtn, 6)

-- ================= THANH ĐỔI TAB =================
local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size = UDim2.new(1, -16, 0, 30)
TabBar.Position = UDim2.new(0, 8, 0, 38)
TabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
addCorner(TabBar, 6)

local TabListLayout = Instance.new("UIListLayout", TabBar)
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Padding = UDim.new(0, 2)

local Container = Instance.new("Frame", MainFrame)
Container.Size = UDim2.new(1, -16, 1, -78)
Container.Position = UDim2.new(0, 8, 0, 72)
Container.BackgroundTransparency = 1

local Tabs = {}
local TabButtons = {}

local function createTab(tabName)
    local Button = Instance.new("TextButton", TabBar)
    Button.Size = UDim2.new(0.2, -1, 1, 0)
    Button.BackgroundTransparency = 1
    Button.Text = tabName
    Button.TextColor3 = Color3.fromRGB(150, 150, 160)
    Button.Font = Enum.Font.GothamSemibold
    Button.TextSize = 11

    local Page = Instance.new("ScrollingFrame", Container)
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 3
    Page.Visible = false

    local Layout = Instance.new("UIListLayout", Page)
    Layout.Padding = UDim.new(0, 8)
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Page.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 10)
    end)

    Button.MouseButton1Click:Connect(function()
        for name, page in pairs(Tabs) do page.Visible = (name == tabName) end
        for name, btn in pairs(TabButtons) do
            btn.TextColor3 = (name == tabName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160)
        end
    end)

    Tabs[tabName] = Page
    TabButtons[tabName] = Button
    return Page
end

local PlayerPage = createTab("Player")
local CombatPage = createTab("Combat")
local VisualPage = createTab("Visuals")
local TeleportPage = createTab("Teleport")
local SettingsPage = createTab("Settings")

Tabs["Player"].Visible = true
TabButtons["Player"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ================= HELPER ELEMENTS =================
local function createInput(page, name, defaultVal, callback)
    local Frame = Instance.new("Frame", page)
    Frame.Size = UDim2.new(1, -6, 0, 36)
    Frame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    addCorner(Frame, 6)

    local Label = Instance.new("TextLabel", Frame)
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 220, 225)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local Input = Instance.new("TextBox", Frame)
    Input.Size = UDim2.new(0.3, -5, 0.7, 0)
    Input.Position = UDim2.new(0.7, 0, 0.15, 0)
    Input.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    Input.Text = tostring(defaultVal)
    Input.TextColor3 = Color3.fromRGB(255, 255, 255)
    Input.Font = Enum.Font.GothamBold
    Input.TextSize = 12
    addCorner(Input, 4)

    Input.FocusLost:Connect(function()
        local val = tonumber(Input.Text)
        if val then callback(val) else Input.Text = tostring(defaultVal) end
    end)
end

local function createToggle(page, name, defaultState, callback)
    local state = defaultState
    local Frame = Instance.new("Frame", page)
    Frame.Size = UDim2.new(1, -6, 0, 36)
    Frame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    addCorner(Frame, 6)

    local Label = Instance.new("TextLabel", Frame)
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 220, 225)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local Btn = Instance.new("TextButton", Frame)
    Btn.Size = UDim2.new(0.3, -5, 0.7, 0)
    Btn.Position = UDim2.new(0.7, 0, 0.15, 0)
    Btn.BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(200, 50, 50)
    Btn.Text = state and "ON" or "OFF"
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    addCorner(Btn, 4)

    local function updateUI(newState)
        state = newState
        Btn.Text = state and "ON" or "OFF"
        Btn.BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(200, 50, 50)
    end

    Btn.MouseButton1Click:Connect(function()
        state = not state
        updateUI(state)
        callback(state, updateUI)
    end)

    return updateUI
end

local function createButton(page, name, callback)
    local Btn = Instance.new("TextButton", page)
    Btn.Size = UDim2.new(1, -6, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Btn.Text = name
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    addCorner(Btn, 6)

    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

-- ================= LOGIC KÉO THẢ MƯỢT MÀ CHO PC MOUSE =================
local function makeDraggable(dragHandle, targetObject)
    local Dragging, DragInput, DragStart, StartPosition
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = input.Position
            StartPosition = targetObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then Dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then DragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == DragInput and Dragging then
            local Delta = input.Position - DragStart
            targetObject.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
        end
    end)
end

makeDraggable(LogoBtn, Wrapper)
makeDraggable(Title, Wrapper)

LogoBtn.MouseButton1Click:Connect(function() LogoBtn.Visible = false; MainFrame.Visible = true end)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; LogoBtn.Visible = true end)

-- PHÍM TẮT TRÊN LAPTOP (Dùng RightControl để Bật/Tắt Menu nhanh)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
        if MainFrame.Visible then
            MainFrame.Visible = false
            LogoBtn.Visible = true
        else
            MainFrame.Visible = true
            LogoBtn.Visible = false
        end
    end
end)

-- ================= BIẾN TRẠNG THÁI HỆ THỐNG =================
local _CFrameSpeedVal, _JumpPower, _FlySpeed = 50, 50, 50
local _HitboxHeadSize, _HitboxTorsoSize = 15, 15
local _HitboxTransparency = 0.5
local _AimbotFovAngle = 60
local _AimbotSmoothness = 0.35
local _TeleKillRange = 500

local _CFrameSpeed, _AirJump, _Fly, _Noclip = false, false, false, false
local _HitboxHead, _HitboxTorso = false, false
local _AimbotHead, _AimbotTorso, _ShowFov = false, false, false
local _AimlockEnabled = false
local _AimlockTarget = nil
local _TeleKill, _AutoFire = false, false
local _EspHighlight, _EspBox = false, false
local _FullBright = false

local updateAimHeadUI, updateAimTorsoUI

-- ================= 1. TAB PLAYER =================
createInput(PlayerPage, "CFrame Speed", 50, function(v) _CFrameSpeedVal = v end)
createInput(PlayerPage, "Jump Power (Lực Nhảy)", 50, function(v) _JumpPower = v end)
createInput(PlayerPage, "Fly Speed", 50, function(v) _FlySpeed = v end)

createToggle(PlayerPage, "CFrame Speed (Bypass)", false, function(s) _CFrameSpeed = s end)
createToggle(PlayerPage, "AirJump (Nhảy cao liên tục)", false, function(s) _AirJump = s end)
createToggle(PlayerPage, "Fly (Theo Camera)", false, function(s) _Fly = s end)
createToggle(PlayerPage, "Noclip (Xuyên tường)", false, function(s) _Noclip = s end)
createToggle(PlayerPage, "Full Bright (Sáng map)", false, function(s) _FullBright = s end)

-- AUTO ANTI-AFK CHẠY TỰ ĐỘNG
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
end)

-- ================= 2. TAB COMBAT =================
createInput(CombatPage, "Hitbox ĐẦU Size", 15, function(v) _HitboxHeadSize = v end)
createInput(CombatPage, "Hitbox THÂN Size", 15, function(v) _HitboxTorsoSize = v end)
createInput(CombatPage, "Hitbox Độ Trong Suốt (0-1)", 0.5, function(v) _HitboxTransparency = math.clamp(v, 0, 1) end)
createInput(CombatPage, "Aimbot FOV Angle (0-180 Độ)", 60, function(v) _AimbotFovAngle = math.clamp(v, 1, 180) end)
createInput(CombatPage, "Aimbot Smooth (0.1-0.5)", 0.35, function(v) _AimbotSmoothness = math.clamp(v, 0.05, 1) end)
createInput(CombatPage, "Phạm Vi Tele-Kill (Studs)", 500, function(v) _TeleKillRange = math.max(v, 10) end)

createToggle(CombatPage, "Hitbox ĐẦU", false, function(s) _HitboxHead = s end)
createToggle(CombatPage, "Hitbox THÂN", false, function(s) _HitboxTorso = s end)
createToggle(CombatPage, "Hiện Vòng FOV Menu Color", false, function(s) _ShowFov = s end)

updateAimHeadUI = createToggle(CombatPage, "Aim ĐẦU (Dynamic FOV)", false, function(s)
    _AimbotHead = s
    if s and _AimbotTorso then
        _AimbotTorso = false
        if updateAimTorsoUI then updateAimTorsoUI(false) end
    end
end)

updateAimTorsoUI = createToggle(CombatPage, "Aim THÂN (Dynamic FOV)", false, function(s)
    _AimbotTorso = s
    if s and _AimbotHead then
        _AimbotHead = false
        if updateAimHeadUI then updateAimHeadUI(false) end
    end
end)

createToggle(CombatPage, "Aimlock (Khóa 1 Mục Tiêu Cố Định)", false, function(s)
    _AimlockEnabled = s
    if not s then _AimlockTarget = nil end
end)

createButton(CombatPage, "🔄 Chuyển Mục Tiêu Aimlock", function()
    _AimlockTarget = nil
end)

createToggle(CombatPage, "Tele-Kill (Dịch chuyển diệt địch)", false, function(s) _TeleKill = s end)
createToggle(CombatPage, "Tự Động Bắn (Auto Attack)", false, function(s) _AutoFire = s end)

-- ================= 3. TAB VISUALS =================
createToggle(VisualPage, "ESP Highlight", false, function(s) _EspHighlight = s end)
createToggle(VisualPage, "Box ESP (Khung 2D)", false, function(s) _EspBox = s end)

-- ================= 4. TAB TELEPORT =================
local SelectedPlayer = nil

local PlrListFrame = Instance.new("Frame", TeleportPage)
PlrListFrame.Size = UDim2.new(1, -6, 0, 100)
PlrListFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
addCorner(PlrListFrame, 6)

local PlrScroll = Instance.new("ScrollingFrame", PlrListFrame)
PlrScroll.Size = UDim2.new(1, -8, 1, -8)
PlrScroll.Position = UDim2.new(0, 4, 0, 4)
PlrScroll.BackgroundTransparency = 1
PlrScroll.BorderSizePixel = 0
PlrScroll.ScrollBarThickness = 3

local PlrListLayout = Instance.new("UIListLayout", PlrScroll)
PlrListLayout.Padding = UDim.new(0, 4)

local CreateTpBtn = Instance.new("TextButton", TeleportPage)
CreateTpBtn.Size = UDim2.new(1, -6, 0, 36)
CreateTpBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
CreateTpBtn.Text = "TẠO NÚT TP (Vui lòng chọn người chơi)"
CreateTpBtn.TextColor3 = Color3.fromRGB(160, 160, 170)
CreateTpBtn.Font = Enum.Font.GothamBold
CreateTpBtn.TextSize = 11
CreateTpBtn.AutoButtonColor = false
addCorner(CreateTpBtn, 6)

local function refreshPlayerList()
    for _, child in ipairs(PlrScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local Btn = Instance.new("TextButton", PlrScroll)
            Btn.Size = UDim2.new(1, 0, 0, 24)
            Btn.BackgroundColor3 = (SelectedPlayer == p) and ThemeColor or Color3.fromRGB(35, 35, 45)
            Btn.Text = "  " .. p.DisplayName .. " (@" .. p.Name .. ")"
            Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            Btn.Font = Enum.Font.GothamSemibold
            Btn.TextSize = 11
            Btn.TextXAlignment = Enum.TextXAlignment.Left
            addCorner(Btn, 4)

            Btn.MouseButton1Click:Connect(function()
                SelectedPlayer = p
                refreshPlayerList()
                CreateTpBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                CreateTpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                CreateTpBtn.Text = "TẠO NÚT TP TELEPORT ➔ " .. p.DisplayName
                CreateTpBtn.AutoButtonColor = true
            end)
        end
    end
    PlrScroll.CanvasSize = UDim2.new(0, 0, 0, PlrListLayout.AbsoluteContentSize.Y)
end

refreshPlayerList()
Players.PlayerAdded:Connect(refreshPlayerList)

Players.PlayerRemoving:Connect(function(p)
    if SelectedPlayer == p then SelectedPlayer = nil end
    if _AimlockTarget == p then _AimlockTarget = nil end
    if ActiveTpButtons[p] then
        if ActiveTpButtons[p].Parent then
            ActiveTpButtons[p]:Destroy()
        end
        ActiveTpButtons[p] = nil
    end
    refreshPlayerList()
end)

CreateTpBtn.MouseButton1Click:Connect(function()
    if not SelectedPlayer then return end
    local targetPlr = SelectedPlayer

    if ActiveTpButtons[targetPlr] and ActiveTpButtons[targetPlr].Parent then
        ActiveTpButtons[targetPlr]:Destroy()
    end

    local FloatFrame = Instance.new("Frame", ScreenGui)
    FloatFrame.Size = UDim2.new(0, 95, 0, 60)
    FloatFrame.Position = UDim2.new(0.1, 0, 0.4, 0)
    FloatFrame.BackgroundTransparency = 1
    ActiveTpButtons[targetPlr] = FloatFrame

    local DeleteBtn = Instance.new("TextButton", FloatFrame)
    DeleteBtn.Size = UDim2.new(0, 20, 0, 20)
    DeleteBtn.Position = UDim2.new(1, -15, 0, -6)
    DeleteBtn.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
    DeleteBtn.Text = "✕"
    DeleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DeleteBtn.Font = Enum.Font.GothamBold
    DeleteBtn.TextSize = 11
    DeleteBtn.ZIndex = 5
    addCorner(DeleteBtn, 10)

    local FloatBtn = Instance.new("TextButton", FloatFrame)
    FloatBtn.Size = UDim2.new(1, 0, 0, 36)
    FloatBtn.Position = UDim2.new(0, 0, 0, 8)
    FloatBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    FloatBtn.Text = "TP OFF"
    FloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatBtn.Font = Enum.Font.GothamBold
    FloatBtn.TextSize = 12
    addCorner(FloatBtn, 8)
    addStroke(FloatBtn)

    local NameLabel = Instance.new("TextLabel", FloatFrame)
    NameLabel.Size = UDim2.new(1.4, 0, 0, 18)
    NameLabel.Position = UDim2.new(-0.2, 0, 1, 10)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = targetPlr.DisplayName
    NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.TextSize = 11

    makeDraggable(FloatBtn, FloatFrame)

    local isTpActive = false
    FloatBtn.MouseButton1Click:Connect(function()
        isTpActive = not isTpActive
        FloatBtn.Text = isTpActive and "TP ON" or "TP OFF"
        FloatBtn.BackgroundColor3 = isTpActive and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(200, 50, 50)
    end)

    DeleteBtn.MouseButton1Click:Connect(function()
        isTpActive = false
        ActiveTpButtons[targetPlr] = nil
        FloatFrame:Destroy()
    end)

    task.spawn(function()
        while FloatFrame and FloatFrame.Parent do
            if isTpActive and targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart") then
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = targetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                end
            end
            task.wait(0.05)
        end
    end)
end)

-- ================= 5. TAB SETTINGS =================
local Colors = {
    {"Đỏ Lửa (Fire Red)", Color3.fromRGB(255, 45, 45)},
    {"Xanh Cyan (Cyan Neon)", Color3.fromRGB(0, 170, 255)},
    {"Xanh Lục (Emerald Green)", Color3.fromRGB(46, 204, 113)},
    {"Tím Hoàng Gia (Purple Royal)", Color3.fromRGB(155, 89, 182)},
    {"Vàng Hoàng Kim (Gold Yellow)", Color3.fromRGB(241, 196, 15)}
}

for _, colorData in ipairs(Colors) do
    local Btn = Instance.new("TextButton", SettingsPage)
    Btn.Size = UDim2.new(1, -6, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    Btn.Text = "Đổi Màu Menu: " .. colorData[1]
    Btn.TextColor3 = colorData[2]
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    addCorner(Btn, 6)

    Btn.MouseButton1Click:Connect(function()
        updateTheme(colorData[2])
        refreshPlayerList()
    end)
end

-- ================= CÁC CHỨC NĂNG CORE (SYSTEM LOGIC) =================

-- 1. AIRJUMP
UserInputService.JumpRequest:Connect(function()
    if _AirJump and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            local boostPower = (_JumpPower and _JumpPower > 0) and _JumpPower or 50
            rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, boostPower, rootPart.AssemblyLinearVelocity.Z)
        end
    end
end)

-- 2. TÍNH GÓC FOV & TEAM CHECK
local function getScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

FOVCircle.Color = ThemeColor
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Transparency = 1

local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end
    return true
end

local function getAngleToTarget(targetPos)
    local camPos = Camera.CFrame.Position
    local lookVector = Camera.CFrame.LookVector
    local targetDir = (targetPos - camPos).Unit
    local dot = math.clamp(lookVector:Dot(targetDir), -1, 1)
    return math.deg(math.acos(dot))
end

local function getBestEnemyInFOV(partName)
    local bestTargetPart = nil
    local minAngle = _AimbotFovAngle / 2

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character and p.Character:FindFirstChild(partName) and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local part = p.Character[partName]
            local angle = getAngleToTarget(part.Position)
            if angle <= minAngle then
                minAngle = angle
                bestTargetPart = part
            end
        end
    end
    return bestTargetPart
end

local function getNearestEnemyForTeleKill()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    local nearestPlr = nil
    local minDist = _TeleKillRange

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local enemyHrp = p.Character.HumanoidRootPart
            local dist = (enemyHrp.Position - myPos).Magnitude
            if dist <= minDist then
                minDist = dist
                nearestPlr = p
            end
        end
    end
    return nearestPlr
end

-- 3. BOX ESP 2D
local BoxContainer = {}

local function updateBoxESP()
    if not _EspBox then
        for _, frame in pairs(BoxContainer) do frame.Visible = false end
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local root = p.Character.HumanoidRootPart
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)

            if onScreen then
                local box = BoxContainer[p]
                if not box then
                    box = Instance.new("Frame", ESPFolder)
                    box.BackgroundTransparency = 1
                    box.BorderSizePixel = 0
                    local s = Instance.new("UIStroke", box)
                    s.Name = "UIStroke"
                    s.Color = ThemeColor
                    s.Thickness = 1.5
                    BoxContainer[p] = box
                else
                    if box:FindFirstChild("UIStroke") then
                        box.UIStroke.Color = ThemeColor
                    end
                end

                local dist = screenPos.Z
                local height = (Camera.ViewportSize.Y / dist) * 4.2
                local width = height * 0.65

                box.Size = UDim2.new(0, width, 0, height)
                box.Position = UDim2.new(0, screenPos.X - width / 2, 0, screenPos.Y - height / 2)
                box.Visible = true
            else
                if BoxContainer[p] then BoxContainer[p].Visible = false end
            end
        else
            if BoxContainer[p] then BoxContainer[p].Visible = false end
        end
    end
end

-- 4. HITBOX EXPANDER
task.spawn(function()
    while task.wait(0.5) do
        for _, p in ipairs(Players:GetPlayers()) do
            if isEnemy(p) and p.Character then
                if _HitboxHead and p.Character:FindFirstChild("Head") then
                    local head = p.Character.Head
                    head.Size = Vector3.new(_HitboxHeadSize, _HitboxHeadSize, _HitboxHeadSize)
                    head.Transparency = _HitboxTransparency
                    head.Color = ThemeColor
                    head.Massless = true
                    head.CanCollide = false
                end
                if _HitboxTorso and p.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = p.Character.HumanoidRootPart
                    hrp.Size = Vector3.new(_HitboxTorsoSize, _HitboxTorsoSize, _HitboxTorsoSize)
                    hrp.Transparency = _HitboxTransparency
                    hrp.Color = ThemeColor
                    hrp.Massless = true
                    hrp.CanCollide = false
                end
            end
        end
    end
end)

-- 5. RENDER LOOP
RunService.RenderStepped:Connect(function(dt)
    updateBoxESP()

    if _ShowFov then
        local fovRad = math.rad(_AimbotFovAngle / 2)
        local camFovRad = math.rad(Camera.FieldOfView / 2)
        local radiusPixels = (math.tan(fovRad) / math.tan(camFovRad)) * (Camera.ViewportSize.Y / 2)

        FOVCircle.Radius = radiusPixels
        FOVCircle.Position = getScreenCenter()
        FOVCircle.Color = ThemeColor
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    if _AimlockEnabled then
        local partName = _AimbotHead and "Head" or "HumanoidRootPart"
        
        if not _AimlockTarget or not _AimlockTarget.Parent or not _AimlockTarget:FindFirstChild("Humanoid") or _AimlockTarget.Humanoid.Health <= 0 then
            local targetPart = getBestEnemyInFOV(partName)
            _AimlockTarget = targetPart and targetPart.Parent or nil
        else
            local lockPart = _AimlockTarget:FindFirstChild(partName)
            if lockPart and getAngleToTarget(lockPart.Position) > (_AimbotFovAngle / 2) then
                _AimlockTarget = nil
            end
        end

        if _AimlockTarget and _AimlockTarget:FindFirstChild(partName) then
            local lockPart = _AimlockTarget[partName]
            local currentPos = Camera.CFrame.Position
            local targetLookAt = CFrame.lookAt(currentPos, lockPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetLookAt, _AimbotSmoothness)
        end
    elseif _AimbotHead or _AimbotTorso then
        local partName = _AimbotHead and "Head" or "HumanoidRootPart"
        local targetPart = getBestEnemyInFOV(partName)
        
        if targetPart then
            local currentPos = Camera.CFrame.Position
            local targetLookAt = CFrame.lookAt(currentPos, targetPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetLookAt, _AimbotSmoothness)
        end
    end

    if _TeleKill then
        local enemyPlr = getNearestEnemyForTeleKill()
        if enemyPlr and enemyPlr.Character then
            local enemyHrp = enemyPlr.Character:FindFirstChild("HumanoidRootPart")
            local enemyHead = enemyPlr.Character:FindFirstChild("Head")
            
            if enemyHrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = enemyHrp.CFrame * CFrame.new(0, 1, 3)
                if enemyHead then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, enemyHead.Position)
                end
                if _AutoFire then
                    VirtualUser:ClickButton1(Vector2.new())
                end
            end
        end
    elseif _AutoFire and (_AimbotHead or _AimbotTorso or _AimlockEnabled) then
        VirtualUser:ClickButton1(Vector2.new())
    end
end)

-- 6. PHYSICAL LOGIC
RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not (humanoid and rootPart) then return end

    if _CFrameSpeed and humanoid.MoveDirection.Magnitude > 0 then
        rootPart.CFrame = rootPart.CFrame + (humanoid.MoveDirection * (_CFrameSpeedVal * dt))
    end
    if _JumpPower ~= 50 then humanoid.UseJumpPower = true; humanoid.JumpPower = _JumpPower end

    local bv = rootPart:FindFirstChild("FlyVelocity")
    local bg = rootPart:FindFirstChild("FlyGyro")
    if _Fly then
        if not bv then bv = Instance.new("BodyVelocity", rootPart); bv.Name = "FlyVelocity"; bv.MaxForce = Vector3.new(9e9, 9e9, 9e9) end
        if not bg then bg = Instance.new("BodyGyro", rootPart); bg.Name = "FlyGyro"; bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9); bg.P = 9e4 end

        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z).Unit
            local flatRight = Vector3.new(Camera.CFrame.RightVector.X, 0, Camera.CFrame.RightVector.Z).Unit
            bv.Velocity = (Camera.CFrame.LookVector * flatLook:Dot(moveDir) + Camera.CFrame.RightVector * flatRight:Dot(moveDir)) * _FlySpeed
        else bv.Velocity = Vector3.new(0, 0, 0) end
        bg.CFrame = Camera.CFrame
    else
        if bv then bv:Destroy() end; if bg then bg:Destroy() end
    end

    if _Noclip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end

    if _FullBright then
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 100000; Lighting.GlobalShadows = false
    end

    if _EspHighlight then
        for _, p in ipairs(Players:GetPlayers()) do
            if isEnemy(p) and p.Character then
                local hl = p.Character:FindFirstChild("ESPHighlight")
                if not hl then
                    hl = Instance.new("Highlight", p.Character)
                    hl.Name = "ESPHighlight"
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.5
                end
            end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("ESPHighlight") then
                p.Character.ESPHighlight:Destroy()
            end
        end
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "🔥 TPD VIP PRO XENO LOADED",
    Text = "Nút chữ 'A' nổi đã kích hoạt. Nhấn nút A hoặc phím RightControl để đóng/mở menu!",
    Duration = 4
})
