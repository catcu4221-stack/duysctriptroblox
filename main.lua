-- ==========================================
-- 1. SERVICES & INITIALIZATION
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- Clean up the previous framework before rebuilding the current one.
-- This also prevents old Player runtime state from surviving a re-execution.
pcall(function()
    if type(_G.MyGUIFramework) == "table" and type(_G.MyGUIFramework.Cleanup) == "function" then
        _G.MyGUIFramework.Cleanup()
    end
end)

-- Clean up a previous render binding if the script is re-executed.
pcall(function()
    RunService:UnbindFromRenderStep("HoodRivalsUnifiedRender")
end)

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Xác định container chứa GUI (Ưu tiên CoreGui, fallback PlayerGui)
local TargetParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if CoreGui then
        TargetParent = CoreGui
    end
end)

-- Dọn dẹp GUI cũ nếu đã tồn tại để tránh lặp GUI (Cleanup)
local GUI_NAME = "HoodRivals_GUI_Framework"
if TargetParent:FindFirstChild(GUI_NAME) then
    TargetParent[GUI_NAME]:Destroy()
end

-- Remove highlight objects left by previous reference versions.
pcall(function()
    for _, target in ipairs(Players:GetPlayers()) do
        local character = target.Character
        if character then
            local legacyHighlight = character:FindFirstChild("ESPHighlight")
            if legacyHighlight and legacyHighlight:IsA("Highlight") then
                legacyHighlight:Destroy()
            end

            local currentHighlight =
                character:FindFirstChild("__HoodRivals_ESPHighlight")
            if currentHighlight and currentHighlight:IsA("Highlight") then
                currentHighlight:Destroy()
            end
        end
    end
end)

-- Quản lý Event Connections
local Connections = {}
local function AddConnection(conn)
    table.insert(Connections, conn)
    return conn
end

-- ==========================================
-- 2. CONFIGURATION & STATE
-- ==========================================
local Config = {
    Title = "[UPD] Hood Rivals",
    Author = "Made By @rullzsy_",
    ToggleKey = Enum.KeyCode.RightControl,
    ToggleKeyEnabled = true,
    UIScale = 1.0,
    BackgroundTransparency = 0.15,

    -- Color Palette
    DarkBg = Color3.fromRGB(15, 15, 18),
    SidebarBg = Color3.fromRGB(20, 20, 24),
    CardBg = Color3.fromRGB(26, 26, 32),
    AccentColor = Color3.fromRGB(0, 140, 255),
    TextColor = Color3.fromRGB(240, 240, 245),
    SubTextColor = Color3.fromRGB(160, 160, 170),
    BorderColor = Color3.fromRGB(45, 45, 55),

    StartPage = "ESP",

    -- ESP Core Configuration
    Enabled = false,
    ShowEnemies = false,
    ShowTeammates = false,
    ShowName = false,
    ShowTracer = false,
    ShowSkeleton = false,
    ShowHealth = false,
    ShowDistance = false,
    MaxDistance = 2000,
    ESPHighlightEnabled = false,

    -- =========================================================
    -- AIM CONFIGURATION
    -- =========================================================
    AimEnabled = false,
    TeamCheck = false,
    WallCheck = false,
    IgnoreVisibility = false,
    UseFOV = false,
    FOV = 90,
    AlwaysAim = false,
    AimOnFire = false,
    AimPart = "Head",
    Smoothness = 0.20,
    AimMaxDistance = 2000,

    -- =========================================================
    -- PLAYER CONFIGURATION
    -- =========================================================
    Player = {
        CFrameSpeedEnabled = false,
        CFrameSpeed = 50,

        AirFlyEnabled = false,
        JumpPower = 50,

        FlyEnabled = false,
        FlySpeed = 50,

        FullBrightEnabled = false,

        NoclipEnabled = false
    },

    Teleport = {
        SelectedPlayer = nil
    }
}

local GUIState = {
    CurrentState = "Open", -- "Open", "Minimized", "Closed"
    ActivePage = nil,
    Pages = {},
    TabButtons = {}
}

-- ==========================================
-- 3. CORE SCREEN GUI SETUP
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
-- Camera:WorldToViewportPoint() trả tọa độ theo viewport.
-- IgnoreGuiInset = true giúp ESP overlay khớp chính xác với tọa độ camera,
-- tránh toàn bộ Name/Health/Distance/Tracer/Skeleton bị lệch xuống.
ScreenGui.IgnoreGuiInset = true
-- Keep viewport-based ESP coordinates aligned with the full render viewport.
pcall(function()
    ScreenGui.ScreenInsets = Enum.ScreenInsets.None
end)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = TargetParent

local UIScaleObj = Instance.new("UIScale")
UIScaleObj.Scale = Config.UIScale
UIScaleObj.Parent = ScreenGui

-- =========================================================
-- AIM FOV CIRCLE
-- The circle uses screen-pixel FOV units and follows the
-- camera viewport center. Color continuously cycles through
-- the full HSV spectrum to create a rainbow effect.
-- =========================================================
local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "AimFOVCircle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.Visible = false
FOVCircle.ZIndex = 0
FOVCircle.Parent = ScreenGui

local FOVCircleCorner = Instance.new("UICorner")
FOVCircleCorner.CornerRadius = UDim.new(1, 0)
FOVCircleCorner.Parent = FOVCircle

local FOVCircleStroke = Instance.new("UIStroke")
FOVCircleStroke.Thickness = 2
FOVCircleStroke.Transparency = 0
FOVCircleStroke.Color = Color3.fromRGB(255, 0, 0)
FOVCircleStroke.Parent = FOVCircle

local function UpdateFOVCircle()
    local camera = Workspace.CurrentCamera

    if not camera then
        FOVCircle.Visible = false
        return
    end

    if not Config.AimEnabled or not Config.UseFOV then
        FOVCircle.Visible = false
        return
    end

    local viewport = camera.ViewportSize
    local scale = math.max(UIScaleObj.Scale, 0.01)
    local diameter = (Config.FOV * 2) / scale

    FOVCircle.Size = UDim2.fromOffset(diameter, diameter)
    FOVCircle.Position = UDim2.fromOffset(
        (viewport.X / 2) / scale,
        (viewport.Y / 2) / scale
    )

    -- Continuous 7-color rainbow cycle.
    local hue = (os.clock() * 0.20) % 1
    FOVCircleStroke.Color = Color3.fromHSV(hue, 1, 1)

    FOVCircle.Visible = true
end

-- ==========================================
-- 4. UTILITY FUNCTIONS (DRAG & TOUCH)
-- ==========================================
local function MakeDraggable(guiObject, dragHandle, cleanupOnDestroy)
    dragHandle = dragHandle or guiObject
    cleanupOnDestroy = cleanupOnDestroy == true

    local dragging = false
    local dragInput, dragStart, startPos
    local wasDragged = false

    local conn1 = dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            wasDragged = false

            local connEnded
            connEnded = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    connEnded:Disconnect()
                end
            end)
        end
    end)

    local conn2 = dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    local conn3 = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then
                wasDragged = true
            end
            guiObject.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    AddConnection(conn1)
    AddConnection(conn2)
    AddConnection(conn3)

    -- Optional per-object cleanup used by transient floating controls.
    -- Existing drag behavior is unchanged for all existing callers.
    if cleanupOnDestroy then
        local cleanupConn
        cleanupConn = guiObject.AncestryChanged:Connect(
            function(_, parent)
                if parent == nil then
                    pcall(function() conn1:Disconnect() end)
                    pcall(function() conn2:Disconnect() end)
                    pcall(function() conn3:Disconnect() end)
                    pcall(function() cleanupConn:Disconnect() end)
                end
            end
        )

        AddConnection(cleanupConn)
    end

    return function() return wasDragged end
end

-- Auto Update Canvas Size cho ScrollingFrame
local function AutoCanvasSize(scrollingFrame, uiListLayout)
    local function update()
        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 15)
    end
    uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
    update()
end

-- ==========================================
-- 5. MAIN WINDOW BUILD
-- ==========================================
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 560, 0, 360)
MainWindow.Position = UDim2.new(0.5, -280, 0.5, -180)
MainWindow.BackgroundColor3 = Config.DarkBg
MainWindow.BackgroundTransparency = Config.BackgroundTransparency
MainWindow.BorderSizePixel = 0
MainWindow.ClipsDescendants = true
MainWindow.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainWindow

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Config.BorderColor
MainStroke.Thickness = 1
MainStroke.Parent = MainWindow

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundTransparency = 1
Header.Parent = MainWindow

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(0, 200, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.Text = Config.Title
TitleLabel.TextColor3 = Config.TextColor
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = Header

local ControlButtons = Instance.new("Frame")
ControlButtons.Size = UDim2.new(0, 60, 1, 0)
ControlButtons.Position = UDim2.new(1, -65, 0, 0)
ControlButtons.BackgroundTransparency = 1
ControlButtons.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "Minimize"
MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
MinimizeBtn.Position = UDim2.new(0, 0, 0.5, -12)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Config.SubTextColor
MinimizeBtn.TextSize = 16
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.BackgroundColor3 = Config.SidebarBg
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = ControlButtons

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 4)
MinCorner.Parent = MinimizeBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "Close"
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(0, 30, 0.5, -12)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Config.SubTextColor
CloseBtn.TextSize = 13
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BackgroundColor3 = Config.SidebarBg
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = ControlButtons

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseBtn

-- Kéo thả MainWindow qua Header
MakeDraggable(MainWindow, Header)

-- Divider Line
local HeaderDivider = Instance.new("Frame")
HeaderDivider.Size = UDim2.new(1, 0, 0, 1)
HeaderDivider.Position = UDim2.new(0, 0, 0, 35)
HeaderDivider.BackgroundColor3 = Config.BorderColor
HeaderDivider.BorderSizePixel = 0
HeaderDivider.Parent = MainWindow

-- Sidebar Container
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 140, 1, -36)
Sidebar.Position = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3 = Config.SidebarBg
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainWindow

local SidebarDivider = Instance.new("Frame")
SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
SidebarDivider.Position = UDim2.new(1, -1, 0, 0)
SidebarDivider.BackgroundColor3 = Config.BorderColor
SidebarDivider.BorderSizePixel = 0
SidebarDivider.Parent = Sidebar

-- Khung riêng cho các TAB.
-- Tách khỏi SidebarList để Divider/Author không chiếm chỗ của tab buttons.
local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, -16, 1, -58)
TabContainer.Position = UDim2.new(0, 8, 0, 10)
TabContainer.BackgroundTransparency = 1
TabContainer.BorderSizePixel = 0
TabContainer.Parent = Sidebar

local SidebarList = Instance.new("UIListLayout")
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 6)
SidebarList.Parent = TabContainer

-- Author Label bottom sidebar
local AuthorLabel = Instance.new("TextLabel")
AuthorLabel.Name = "AuthorLabel"
AuthorLabel.Size = UDim2.new(1, -16, 0, 30)
AuthorLabel.Position = UDim2.new(0, 8, 1, -35)
AuthorLabel.Text = Config.Author
AuthorLabel.TextColor3 = Config.SubTextColor
AuthorLabel.TextSize = 11
AuthorLabel.Font = Enum.Font.Gotham
AuthorLabel.TextWrapped = true
AuthorLabel.BackgroundTransparency = 1
AuthorLabel.Parent = Sidebar

-- Content Area
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -141, 1, -36)
ContentArea.Position = UDim2.new(0, 141, 0, 36)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainWindow

-- Floating Open Button
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingOpenButton"
FloatingBtn.Size = UDim2.new(0, 75, 0, 35)
FloatingBtn.Position = UDim2.new(1, -95, 1, -55)
FloatingBtn.BackgroundColor3 = Config.DarkBg
FloatingBtn.Text = "Open"
FloatingBtn.TextColor3 = Config.TextColor
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 13
FloatingBtn.Visible = false
FloatingBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 6)
FloatCorner.Parent = FloatingBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Config.AccentColor
FloatStroke.Thickness = 1.5
FloatStroke.Parent = FloatingBtn

local isFloatDragged = MakeDraggable(FloatingBtn, FloatingBtn)

-- ==========================================
-- 6. PAGE MANAGER & TAB SYSTEM
-- ==========================================
local PageManager = {}

function PageManager:AddPage(pageName)
    local pageScroll = Instance.new("ScrollingFrame")
    pageScroll.Name = pageName .. "Page"
    pageScroll.Size = UDim2.new(1, 0, 1, 0)
    pageScroll.BackgroundTransparency = 1
    pageScroll.BorderSizePixel = 0
    pageScroll.ScrollBarThickness = 3
    pageScroll.ScrollBarImageColor3 = Config.SubTextColor
    pageScroll.Visible = false
    pageScroll.Parent = ContentArea

    local pageList = Instance.new("UIListLayout")
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Padding = UDim.new(0, 10)
    pageList.Parent = pageScroll

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 10)
    pagePadding.PaddingLeft = UDim.new(0, 12)
    pagePadding.PaddingRight = UDim.new(0, 12)
    pagePadding.PaddingBottom = UDim.new(0, 10)
    pagePadding.Parent = pageScroll

    AutoCanvasSize(pageScroll, pageList)

    -- Tab Button
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = pageName .. "Btn"
    tabBtn.Size = UDim2.new(1, 0, 0, 32)
    tabBtn.Text = pageName
    tabBtn.TextColor3 = Config.SubTextColor
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.TextSize = 13
    tabBtn.BackgroundColor3 = Config.DarkBg
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = TabContainer

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabBtn

    GUIState.Pages[pageName] = pageScroll
    GUIState.TabButtons[pageName] = tabBtn

    tabBtn.MouseButton1Click:Connect(function()
        PageManager:ShowPage(pageName)
    end)

    return pageScroll
end

function PageManager:ShowPage(pageName)
    for name, page in pairs(GUIState.Pages) do
        local btn = GUIState.TabButtons[name]
        if name == pageName then
            page.Visible = true
            btn.BackgroundColor3 = Config.AccentColor
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            GUIState.ActivePage = name
        else
            page.Visible = false
            btn.BackgroundColor3 = Config.DarkBg
            btn.TextColor3 = Config.SubTextColor
        end
    end
end

-- ==========================================
-- 7. COMPONENT ENGINE (MODULAR BUILDER)
-- ==========================================
local UI = {}

function UI:CreateSection(parent, titleText)
    local sectionFrame = Instance.new("Frame")
    sectionFrame.Name = titleText .. "Section"
    sectionFrame.Size = UDim2.new(1, 0, 0, 0)
    sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
    sectionFrame.BackgroundColor3 = Config.CardBg
    sectionFrame.BorderSizePixel = 0
    sectionFrame.Parent = parent

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 6)
    sCorner.Parent = sectionFrame

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = Config.BorderColor
    sStroke.Thickness = 1
    sStroke.Parent = sectionFrame

    local sLayout = Instance.new("UIListLayout")
    sLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sLayout.Padding = UDim.new(0, 8)
    sLayout.Parent = sectionFrame

    local sPadding = Instance.new("UIPadding")
    sPadding.PaddingTop = UDim.new(0, 8)
    sPadding.PaddingLeft = UDim.new(0, 10)
    sPadding.PaddingRight = UDim.new(0, 10)
    sPadding.PaddingBottom = UDim.new(0, 10)
    sPadding.Parent = sectionFrame

    if titleText and titleText ~= "" then
        local secTitle = Instance.new("TextLabel")
        secTitle.Size = UDim2.new(1, 0, 0, 18)
        secTitle.Text = "-=" .. titleText .. "=-"
        secTitle.TextColor3 = Config.TextColor
        secTitle.Font = Enum.Font.GothamBold
        secTitle.TextSize = 12
        secTitle.BackgroundTransparency = 1
        secTitle.Parent = sectionFrame
    end

    return sectionFrame
end

function UI:CreateLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Text = text
    label.TextColor3 = Config.SubTextColor
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.BackgroundTransparency = 1
    label.Parent = parent
    return label
end

function UI:CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Text = text
    btn.TextColor3 = Config.TextColor
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.BackgroundColor3 = Config.DarkBg
    btn.AutoButtonColor = false
    btn.Parent = parent

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 5)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Config.BorderColor
    bStroke.Thickness = 1
    bStroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Config.AccentColor}):Play()
        task.wait(0.1)
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Config.DarkBg}):Play()
        if callback then callback() end
    end)

    return btn
end

function UI:CreateToggle(parent, options)
    options = options or {}
    local text = options.Text or "Toggle"
    local default = options.Default or false
    local callback = options.Callback or function() end

    local state = default

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 28)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Text = text
    label.TextColor3 = Config.TextColor
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Parent = toggleFrame

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 42, 0, 20)
    switch.Position = UDim2.new(1, -42, 0.5, -10)
    switch.Text = ""
    switch.BackgroundColor3 = state and Config.AccentColor or Config.DarkBg
    switch.AutoButtonColor = false
    switch.Parent = toggleFrame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(1, 0)
    sCorner.Parent = switch

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 14, 0, 14)
    circle.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    circle.BackgroundColor3 = Config.TextColor
    circle.BorderSizePixel = 0
    circle.Parent = switch

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(1, 0)
    cCorner.Parent = circle

    local function toggle()
        state = not state
        local targetColor = state and Config.AccentColor or Config.DarkBg
        local targetPos = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)

        TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = targetPos}):Play()

        callback(state)
    end

    switch.MouseButton1Click:Connect(toggle)
    return {
        Set = function(val)
            if state ~= val then toggle() end
        end
    }
end

function UI:CreateSlider(parent, options)
    options = options or {}
    local text = options.Text or "Slider"
    local min = options.Min or 0
    local max = options.Max or 100
    local default = options.Default or min
    local increment = options.Increment or 1
    local callback = options.Callback or function() end
    local allowTextInputBeyondRange =
        options.AllowTextInputBeyondRange == true
    local editableValue =
        options.EditableValue == true

    -- currentValue is the single source of truth.
    local currentValue = default
    local sliderMax = max

    local function IsFiniteNumber(value)
        return type(value) == "number"
            and value == value
            and value ~= math.huge
            and value ~= -math.huge
    end

    if not IsFiniteNumber(currentValue) then
        currentValue = min
    end

    currentValue = math.clamp(currentValue, min, max)

    local function FormatValue(value)
        if increment < 1 then
            return string.format("%.2f", value)
        end
        return tostring(value)
    end

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 40)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.58, 0, 0, 18)
    label.Text = text
    label.TextColor3 = Config.TextColor
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Parent = sliderFrame

    local valueBox

    if editableValue then
        -- The original value label becomes an editable TextBox only
        -- for sliders that explicitly request direct numeric input.
        valueBox = Instance.new("TextBox")
        valueBox.Size = UDim2.new(0.40, 0, 0, 18)
        valueBox.Position = UDim2.new(0.60, 0, 0, 0)
        valueBox.Text = FormatValue(currentValue)
        valueBox.TextColor3 = Config.SubTextColor
        valueBox.PlaceholderText = FormatValue(currentValue)
        valueBox.PlaceholderColor3 = Config.SubTextColor
        valueBox.Font = Enum.Font.Gotham
        valueBox.TextSize = 12
        valueBox.TextXAlignment = Enum.TextXAlignment.Right
        valueBox.BackgroundColor3 = Config.DarkBg
        valueBox.BorderSizePixel = 0
        valueBox.ClearTextOnFocus = false
        valueBox.Parent = sliderFrame

        local vCorner = Instance.new("UICorner")
        vCorner.CornerRadius = UDim.new(0, 4)
        vCorner.Parent = valueBox
    else
        valueBox = Instance.new("TextLabel")
        valueBox.Size = UDim2.new(0.40, 0, 0, 18)
        valueBox.Position = UDim2.new(0.60, 0, 0, 0)
        valueBox.Text = FormatValue(currentValue)
        valueBox.TextColor3 = Config.SubTextColor
        valueBox.Font = Enum.Font.Gotham
        valueBox.TextSize = 12
        valueBox.TextXAlignment = Enum.TextXAlignment.Right
        valueBox.BackgroundTransparency = 1
        valueBox.Parent = sliderFrame
    end

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 1, -8)
    track.BackgroundColor3 = Config.DarkBg
    track.BorderSizePixel = 0
    track.Parent = sliderFrame

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Config.AccentColor
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(1, 0)
    fCorner.Parent = fill

    local dragging = false

    local function updateVisuals()
        local visualMax = math.max(sliderMax, min + increment)
        local denominator = visualMax - min

        local percentage = 0
        if denominator > 0 then
            percentage = math.clamp(
                (currentValue - min) / denominator,
                0,
                1
            )
        end

        fill.Size = UDim2.new(percentage, 0, 1, 0)
        valueBox.Text = FormatValue(currentValue)
    end

    -- Slider input intentionally stays inside the configured range.
    local function updateFromSlider(inputPos)
        local percentage = math.clamp(
            (inputPos.X - track.AbsolutePosition.X) /
                math.max(track.AbsoluteSize.X, 1),
            0,
            1
        )

        local rawValue =
            min + (sliderMax - min) * percentage

        currentValue =
            math.floor(rawValue / increment + 0.5) * increment

        currentValue = math.clamp(
            currentValue,
            min,
            sliderMax
        )

        updateVisuals()
        callback(currentValue)
    end

    local function updateFromText()
        local enteredValue = tonumber(valueBox.Text)

        if not IsFiniteNumber(enteredValue) then
            valueBox.Text = FormatValue(currentValue)
            return
        end

        if enteredValue < min then
            valueBox.Text = FormatValue(currentValue)
            return
        end

        if allowTextInputBeyondRange then
            -- Player values can exceed the original visual slider range.
            -- Expand the slider range so the textbox and track remain
            -- synchronized instead of hard-clamping the typed value.
            if enteredValue > sliderMax then
                sliderMax = enteredValue
            end

            currentValue = enteredValue
        else
            -- Preserve the configured slider range for existing sliders.
            currentValue = math.clamp(
                enteredValue,
                min,
                sliderMax
            )

            -- Respect the configured increment for regular sliders.
            if increment > 0 then
                currentValue =
                    math.floor(
                        ((currentValue - min) / increment) + 0.5
                    ) * increment + min

                currentValue = math.clamp(
                    currentValue,
                    min,
                    sliderMax
                )
            end
        end

        updateVisuals()
        callback(currentValue)
    end

    if editableValue then
        AddConnection(
            valueBox.FocusLost:Connect(function()
                updateFromText()
            end)
        )
    end

    AddConnection(
        track.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            updateFromSlider(input.Position)
        end
        end)
    )

    AddConnection(
        UserInputService.InputChanged:Connect(function(input)
        if
            dragging
            and (
                input.UserInputType
                    == Enum.UserInputType.MouseMovement
                or input.UserInputType
                    == Enum.UserInputType.Touch
            )
        then
            updateFromSlider(input.Position)
        end
        end)
    )

    AddConnection(
        UserInputService.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = false
        end
        end)
    )

    updateVisuals()

    return sliderFrame
end

function UI:CreateTextbox(parent, options)
    options = options or {}
    local text = options.Text or "Input"
    local placeholder = options.Placeholder or "Enter text..."
    local callback = options.Callback or function() end

    local tbFrame = Instance.new("Frame")
    tbFrame.Size = UDim2.new(1, 0, 0, 32)
    tbFrame.BackgroundTransparency = 1
    tbFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.Text = text
    label.TextColor3 = Config.TextColor
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Parent = tbFrame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.58, 0, 1, 0)
    box.Position = UDim2.new(0.42, 0, 0, 0)
    box.PlaceholderText = placeholder
    box.Text = options.Default or ""
    box.TextColor3 = Config.TextColor
    box.PlaceholderColor3 = Config.SubTextColor
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.BackgroundColor3 = Config.DarkBg
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Parent = tbFrame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 5)
    bCorner.Parent = box

    box.FocusLost:Connect(function(enterPressed)
        local num = tonumber(box.Text)
        if num then
            callback(num, enterPressed)
        else
            callback(box.Text, enterPressed)
        end
    end)

    return box
end

-- ==========================================
-- 8. INITIALIZE PAGES & DEFAULT CONTENT
-- ==========================================

-- ==========================================
-- 9. ESP CORE & ESP TAB INTEGRATION
-- ==========================================

-- =========================================================
-- PLAYER CONFIG / CORE / CHARACTER HANDLER
-- =========================================================

local PlayerRuntime = {
    Character = nil,
    Humanoid = nil,
    RootPart = nil,

    AirFlyJumpRequested = false,

    NoclipOriginalCanCollide = {},

    FullBrightSaved = nil
}

local PLAYER_FLY_VELOCITY_NAME = "__HoodRivals_PlayerFlyVelocity"
local PLAYER_FLY_GYRO_NAME = "__HoodRivals_PlayerFlyGyro"

local FULL_BRIGHT_VALUES = {
    Brightness = 2,
    ClockTime = 14,
    FogEnd = 100000,
    GlobalShadows = false
}

local function GetLocalCharacterParts()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    return character, humanoid, rootPart
end

local function RefreshPlayerCharacterReferences(character)
    PlayerRuntime.Character = character
    PlayerRuntime.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    PlayerRuntime.RootPart = character and character:FindFirstChild("HumanoidRootPart") or nil
    PlayerRuntime.NoclipOriginalCanCollide = {}
end

-- =========================
-- PLAYER CLEANUP HELPERS
-- =========================

local function RestoreNoclip(character)
    local originalStates = PlayerRuntime.NoclipOriginalCanCollide

    for part, originalCanCollide in pairs(originalStates) do
        if part and part.Parent and part:IsA("BasePart") then
            pcall(function()
                part.CanCollide = originalCanCollide
            end)
        end
    end

    PlayerRuntime.NoclipOriginalCanCollide = {}
end

local function DestroyFlyObjects(character)
    if not character then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local velocity = rootPart:FindFirstChild(PLAYER_FLY_VELOCITY_NAME)
    if velocity then
        velocity:Destroy()
    end

    local gyro = rootPart:FindFirstChild(PLAYER_FLY_GYRO_NAME)
    if gyro then
        gyro:Destroy()
    end
end

local function CaptureFullBrightState()
    if PlayerRuntime.FullBrightSaved then
        return
    end

    PlayerRuntime.FullBrightSaved = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows
    }
end

local function ApplyFullBright()
    for propertyName, propertyValue in pairs(FULL_BRIGHT_VALUES) do
        if Lighting[propertyName] ~= propertyValue then
            Lighting[propertyName] = propertyValue
        end
    end
end

local function RestoreFullBright()
    local saved = PlayerRuntime.FullBrightSaved
    if not saved then
        return
    end

    for propertyName, propertyValue in pairs(saved) do
        pcall(function()
            Lighting[propertyName] = propertyValue
        end)
    end

    PlayerRuntime.FullBrightSaved = nil
end

local function CleanupPlayerRuntime()
    local character = PlayerRuntime.Character or LocalPlayer.Character

    if character then
        RestoreNoclip(character)
        DestroyFlyObjects(character)
    else
        PlayerRuntime.NoclipOriginalCanCollide = {}
    end

    RestoreFullBright()

    PlayerRuntime.Character = nil
    PlayerRuntime.Humanoid = nil
    PlayerRuntime.RootPart = nil
    PlayerRuntime.AirFlyJumpRequested = false
end

-- =========================
-- PLAYER CORE
-- =========================

local function ApplyJumpPower(humanoid)
    if not humanoid then
        return
    end

    pcall(function()
        humanoid.UseJumpPower = true
        local jumpPower = tonumber(Config.Player.JumpPower) or 50

        if jumpPower == jumpPower
            and jumpPower ~= math.huge
            and jumpPower ~= -math.huge
        then
            humanoid.JumpPower = math.max(jumpPower, 0)
        end
    end)
end

local function UpdateCFrameSpeed(dt, humanoid, rootPart)
    if not Config.Player.CFrameSpeedEnabled then
        return
    end

    if not humanoid or not rootPart then
        return
    end

    local moveDirection = humanoid.MoveDirection
    if moveDirection.Magnitude <= 0 then
        return
    end

    rootPart.CFrame =
        rootPart.CFrame
        + (moveDirection * (Config.Player.CFrameSpeed * dt))
end

local function UpdateAirFly()
    if not Config.Player.AirFlyEnabled then
        PlayerRuntime.AirFlyJumpRequested = false
        return
    end

    if not PlayerRuntime.AirFlyJumpRequested then
        return
    end

    PlayerRuntime.AirFlyJumpRequested = false

    local character, humanoid, rootPart = GetLocalCharacterParts()
    if not character or not humanoid or not rootPart then
        return
    end

    pcall(function()
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

        local boostPower = tonumber(Config.Player.JumpPower) or 50

        if boostPower ~= boostPower
            or boostPower == math.huge
            or boostPower == -math.huge
        then
            boostPower = 50
        end

        boostPower = math.max(boostPower, 0)

        local velocity = rootPart.AssemblyLinearVelocity

        rootPart.AssemblyLinearVelocity = Vector3.new(
            velocity.X,
            boostPower,
            velocity.Z
        )
    end)
end

local function UpdateFly(humanoid, rootPart)
    if not Config.Player.FlyEnabled then
        if rootPart then
            DestroyFlyObjects(PlayerRuntime.Character or LocalPlayer.Character)
        end
        return
    end

    if not humanoid or not rootPart then
        return
    end

    local bodyVelocity = rootPart:FindFirstChild(PLAYER_FLY_VELOCITY_NAME)
    local bodyGyro = rootPart:FindFirstChild(PLAYER_FLY_GYRO_NAME)

    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = PLAYER_FLY_VELOCITY_NAME
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Parent = rootPart
    end

    if not bodyGyro then
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.Name = PLAYER_FLY_GYRO_NAME
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.P = 9e4
        bodyGyro.Parent = rootPart
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        bodyVelocity.Velocity = Vector3.zero
        return
    end

    local moveDirection = humanoid.MoveDirection

    if moveDirection.Magnitude > 0 then
        local flatLook =
            Vector3.new(
                camera.CFrame.LookVector.X,
                0,
                camera.CFrame.LookVector.Z
            )

        local flatRight =
            Vector3.new(
                camera.CFrame.RightVector.X,
                0,
                camera.CFrame.RightVector.Z
            )

        if flatLook.Magnitude > 0 then
            flatLook = flatLook.Unit
        end

        if flatRight.Magnitude > 0 then
            flatRight = flatRight.Unit
        end

        bodyVelocity.Velocity =
            (
                camera.CFrame.LookVector * flatLook:Dot(moveDirection)
                + camera.CFrame.RightVector * flatRight:Dot(moveDirection)
            ) * Config.Player.FlySpeed
    else
        bodyVelocity.Velocity = Vector3.zero
    end

    bodyGyro.CFrame = camera.CFrame
end

local function UpdateNoclip(character)
    if not Config.Player.NoclipEnabled then
        RestoreNoclip(character)
        return
    end

    if not character then
        return
    end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if PlayerRuntime.NoclipOriginalCanCollide[part] == nil then
                PlayerRuntime.NoclipOriginalCanCollide[part] =
                    part.CanCollide
            end

            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end

local function UpdatePlayer(dt)
    local character, humanoid, rootPart = GetLocalCharacterParts()

    if character ~= PlayerRuntime.Character then
        PlayerRuntime.NoclipOriginalCanCollide = {}
    end

    PlayerRuntime.Character = character
    PlayerRuntime.Humanoid = humanoid
    PlayerRuntime.RootPart = rootPart

    if not character or not humanoid or not rootPart then
        return
    end

    -- Jump Power is independent from Air Fly and has no toggle.
    ApplyJumpPower(humanoid)

    UpdateCFrameSpeed(dt, humanoid, rootPart)
    UpdateAirFly()
    UpdateFly(humanoid, rootPart)
    UpdateNoclip(character)

    if Config.Player.FullBrightEnabled then
        CaptureFullBrightState()
        ApplyFullBright()
    end
end

-- =========================
-- PLAYER CHARACTER HANDLER
-- =========================

local function HandleLocalCharacterAdded(character)
    RefreshPlayerCharacterReferences(character)

    PlayerRuntime.AirFlyJumpRequested = false

    -- Remove only our previous fly objects from the new character, if any.
    DestroyFlyObjects(character)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        ApplyJumpPower(humanoid)
    end
end

local function HandleLocalCharacterRemoving(character)
    PlayerRuntime.AirFlyJumpRequested = false

    RestoreNoclip(character)
    DestroyFlyObjects(character)

    if PlayerRuntime.Character == character then
        PlayerRuntime.Character = nil
        PlayerRuntime.Humanoid = nil
        PlayerRuntime.RootPart = nil
    end
end

RefreshPlayerCharacterReferences(LocalPlayer.Character)

AddConnection(
    LocalPlayer.CharacterAdded:Connect(function(character)
        HandleLocalCharacterAdded(character)
    end)
)

AddConnection(
    LocalPlayer.CharacterRemoving:Connect(function(character)
        HandleLocalCharacterRemoving(character)
    end)
)

-- One JumpRequest connection for the whole script.
-- The actual jump is consumed by UpdateAirFly() inside the unified render lifecycle.
AddConnection(
    UserInputService.JumpRequest:Connect(function()
        if Config.Player.AirFlyEnabled
            and GUIState.CurrentState ~= "Closed"
        then
            PlayerRuntime.AirFlyJumpRequested = true
        end
    end)
)

-- =========================
-- PLAYER UI
-- Uses the existing PageManager + UI component engine only.
-- =========================

local PlayerPage = PageManager:AddPage("PLAYER")

local PlayerMovementSec = UI:CreateSection(PlayerPage, "MOVEMENT")

UI:CreateToggle(PlayerMovementSec, {
    Text = "CFrame Speed",
    Default = false,
    Callback = function(value)
        Config.Player.CFrameSpeedEnabled = value
    end
})

UI:CreateSlider(PlayerMovementSec, {
    Text = "CFrame Speed",
    Min = 20,
    Max = 200,
    Default = 50,
    Increment = 1,
    EditableValue = true,
    AllowTextInputBeyondRange = true,
    Callback = function(value)
        Config.Player.CFrameSpeed = value
    end
})

local PlayerJumpSec = UI:CreateSection(PlayerPage, "JUMP")

UI:CreateToggle(PlayerJumpSec, {
    Text = "Air Fly",
    Default = false,
    Callback = function(value)
        Config.Player.AirFlyEnabled = value

        if not value then
            PlayerRuntime.AirFlyJumpRequested = false
        end
    end
})

UI:CreateSlider(PlayerJumpSec, {
    Text = "Jump Power",
    Min = 20,
    Max = 200,
    Default = 50,
    Increment = 1,
    EditableValue = true,
    AllowTextInputBeyondRange = true,
    Callback = function(value)
        Config.Player.JumpPower = value
        ApplyJumpPower(PlayerRuntime.Humanoid)
    end
})

local PlayerFlySec = UI:CreateSection(PlayerPage, "FLY")

UI:CreateToggle(PlayerFlySec, {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        Config.Player.FlyEnabled = value

        if not value then
            DestroyFlyObjects(PlayerRuntime.Character or LocalPlayer.Character)
        end
    end
})

UI:CreateSlider(PlayerFlySec, {
    Text = "Fly Speed",
    Min = 0,
    Max = 200,
    Default = 50,
    Increment = 1,
    EditableValue = true,
    AllowTextInputBeyondRange = true,
    Callback = function(value)
        Config.Player.FlySpeed = value
    end
})

local PlayerVisualSec = UI:CreateSection(PlayerPage, "VISUAL")

UI:CreateToggle(PlayerVisualSec, {
    Text = "Full Bright",
    Default = false,
    Callback = function(value)
        Config.Player.FullBrightEnabled = value

        if value then
            CaptureFullBrightState()
            ApplyFullBright()
        else
            RestoreFullBright()
        end
    end
})

local PlayerCharacterSec = UI:CreateSection(PlayerPage, "CHARACTER")

UI:CreateToggle(PlayerCharacterSec, {
    Text = "Noclip",
    Default = false,
    Callback = function(value)
        Config.Player.NoclipEnabled = value

        if value then
            -- The unified Player update will capture per-part collision state.
            return
        end

        RestoreNoclip(PlayerRuntime.Character or LocalPlayer.Character)
    end
})

-- =========================================================
-- TAB: AIM
-- Created exactly once in the existing PageManager.
-- Future tabs can be registered in this section.
-- =========================================================
local AimPage = PageManager:AddPage("AIM")

local AimMainSec = UI:CreateSection(AimPage, "AIM Main")

UI:CreateToggle(AimMainSec, {
    Text = "Aim Enable",
    Default = Config.AimEnabled,
    Callback = function(value)
        Config.AimEnabled = value
    end
})

UI:CreateToggle(AimMainSec, {
    Text = "Team Check",
    Default = Config.TeamCheck,
    Callback = function(value)
        Config.TeamCheck = value
    end
})

UI:CreateToggle(AimMainSec, {
    Text = "Wall Check",
    Default = Config.WallCheck,
    Callback = function(value)
        Config.WallCheck = value
    end
})

UI:CreateToggle(AimMainSec, {
    Text = "Ignore Visibility",
    Default = Config.IgnoreVisibility,
    Callback = function(value)
        Config.IgnoreVisibility = value
    end
})

local AimTargetSec = UI:CreateSection(AimPage, "AIM Target")

local AimPartButton
AimPartButton = UI:CreateButton(
    AimTargetSec,
    "Aim Part: " .. Config.AimPart,
    function()
        Config.AimPart =
            (Config.AimPart == "Head") and "Body" or "Head"

        AimPartButton.Text = "Aim Part: " .. Config.AimPart
    end
)

local AimFovSec = UI:CreateSection(AimPage, "AIM FOV")

UI:CreateToggle(AimFovSec, {
    Text = "Use FOV",
    Default = Config.UseFOV,
    Callback = function(value)
        Config.UseFOV = value
    end
})

UI:CreateSlider(AimFovSec, {
    Text = "FOV",
    Min = 0,
    Max = 180,
    Default = Config.FOV,
    Increment = 1,
    Callback = function(value)
        Config.FOV = math.clamp(value, 0, 180)
    end
})

local AimMaxDistanceInput
AimMaxDistanceInput = UI:CreateTextbox(AimFovSec, {
    Text = "Max Distance",
    Placeholder = "50 - 10000",
    Default = tostring(Config.AimMaxDistance),
    Callback = function(value)
        local oldValue = Config.AimMaxDistance
        local numberValue = tonumber(value)

        if numberValue then
            Config.AimMaxDistance = math.clamp(numberValue, 50, 10000)
            AimMaxDistanceInput.Text = tostring(Config.AimMaxDistance)
        else
            Config.AimMaxDistance = oldValue
            AimMaxDistanceInput.Text = tostring(oldValue)
        end
    end
})

local AimModeSec = UI:CreateSection(AimPage, "AIM Mode")

local AimAlwaysToggle
local AimOnFireToggle

AimAlwaysToggle = UI:CreateToggle(AimModeSec, {
    Text = "Always Aim",
    Default = false,
    Callback = function(value)
        Config.AlwaysAim = value
        if value then
            Config.AimOnFire = false
            if AimOnFireToggle then
                AimOnFireToggle.Set(false)
            end
        end
    end
})

AimOnFireToggle = UI:CreateToggle(AimModeSec, {
    Text = "Aim On Fire",
    Default = false,
    Callback = function(value)
        Config.AimOnFire = value
        if value then
            Config.AlwaysAim = false
            if AimAlwaysToggle then
                AimAlwaysToggle.Set(false)
            end
        end
    end
})

local AimSettingsSec = UI:CreateSection(AimPage, "AIM Settings")

UI:CreateSlider(AimSettingsSec, {
    Text = "Smoothness",
    Min = 0.2,
    Max = 1,
    Default = 0.20,
    Increment = 0.01,
    EditableValue = false,
    Callback = function(value)
        Config.Smoothness = math.clamp(value, 0.2, 1)
    end
})

-- Tab 3: ESP
-- Đúng một tab ESP trong Sidebar, page chỉ tạo một lần.
-- Click ESP sẽ gọi PageManager:ShowPage("ESP") và ẩn các page khác.
local ESPPage = PageManager:AddPage("ESP")

local ESPMainSec = UI:CreateSection(ESPPage, "ESP Main")

UI:CreateToggle(ESPMainSec, {
    Text = "ESP Enable",
    Default = Config.Enabled,
    Callback = function(v)
        Config.Enabled = v
    end
})

UI:CreateToggle(ESPMainSec, {
    Text = "ESP Enemy",
    Default = Config.ShowEnemies,
    Callback = function(v)
        Config.ShowEnemies = v
    end
})

UI:CreateToggle(ESPMainSec, {
    Text = "ESP Team",
    Default = Config.ShowTeammates,
    Callback = function(v)
        Config.ShowTeammates = v
    end
})

local ESPVisualsSec = UI:CreateSection(ESPPage, "ESP Visuals")

UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Name",
    Default = Config.ShowName,
    Callback = function(v)
        Config.ShowName = v
    end
})

UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Tracer",
    Default = Config.ShowTracer,
    Callback = function(v)
        Config.ShowTracer = v
    end
})

UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Skeleton",
    Default = Config.ShowSkeleton,
    Callback = function(v)
        Config.ShowSkeleton = v
    end
})

UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Health",
    Default = Config.ShowHealth,
    Callback = function(v)
        Config.ShowHealth = v
    end
})

UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Distance",
    Default = Config.ShowDistance,
    Callback = function(v)
        Config.ShowDistance = v
    end
})

UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Highlight",
    Default = Config.ESPHighlightEnabled,
    Callback = function(v)
        Config.ESPHighlightEnabled = v
    end
})

local ESPSettingsSec = UI:CreateSection(ESPPage, "ESP Settings")

local ESPDistanceInput

ESPDistanceInput = UI:CreateTextbox(ESPSettingsSec, {
    Text = "ESP Distance",
    Placeholder = "50 - 10000",
    Default = tostring(Config.MaxDistance),
    Callback = function(value)
        local oldValue = Config.MaxDistance
        local numberValue = tonumber(value)

        if numberValue then
            Config.MaxDistance = math.clamp(numberValue, 50, 10000)
            ESPDistanceInput.Text = tostring(Config.MaxDistance)
        else
            Config.MaxDistance = oldValue
            ESPDistanceInput.Text = tostring(oldValue)
        end
    end
})

-- =========================================================
-- AIM CORE
--
-- MENU -> CONFIG -> TARGET VALIDATION -> TARGET SELECTION
--      -> AIM CONTROLLER -> CAMERA RENDER
--
-- AIM is independent from ESP.
-- It does not read ESPData, tracer objects, or skeleton objects.
-- =========================================================

local CurrentAimTarget = nil

local function GetAimPart(target)
    local character = target and target.Character
    if not character then
        return nil
    end

    if Config.AimPart == "Head" then
        return character:FindFirstChild("Head")
    end

    -- Body follows the actual rig structure:
    -- R15 -> UpperTorso
    -- R6  -> Torso
    -- fallback -> HumanoidRootPart
    return character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function GetAimRoot(target)
    local character = target and target.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("Head")
end

local function IsAliveAimTarget(target)
    local character = target and target.Character
    local humanoid =
        character and character:FindFirstChildOfClass("Humanoid")

    return humanoid ~= nil and humanoid.Health > 0
end

local function PassesAimTeamCheck(target)
    if not Config.TeamCheck then
        return true
    end

    -- In games without Roblox Teams, Team may be nil for both players.
    -- Do not reject every target just because both Team values are nil.
    local localTeam = LocalPlayer.Team
    local targetTeam = target.Team

    if localTeam and targetTeam and localTeam == targetTeam then
        return false
    end

    return true
end

local function PassesVisibility(targetPart)
    if Config.IgnoreVisibility then
        return true
    end

    if not Config.WallCheck then
        return true
    end

    local camera = Workspace.CurrentCamera
    if not camera or not targetPart or not targetPart.Parent then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin

    if direction.Magnitude <= 0 then
        return true
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local ignoreList = {}

    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end

    local targetCharacter = targetPart:FindFirstAncestorOfClass("Model")
    if targetCharacter then
        table.insert(ignoreList, targetCharacter)
    end

    rayParams.FilterDescendantsInstances = ignoreList

    -- The target character is excluded so the ray only reports
    -- a blocking object between camera and target.
    local result = Workspace:Raycast(
        origin,
        direction,
        rayParams
    )

    return result == nil
end

local function GetAimWorldDistance(targetRoot)
    local localCharacter = LocalPlayer.Character
    local localRoot =
        localCharacter and (
            localCharacter:FindFirstChild("HumanoidRootPart")
            or localCharacter.PrimaryPart
            or localCharacter:FindFirstChild("UpperTorso")
            or localCharacter:FindFirstChild("Torso")
            or localCharacter:FindFirstChild("Head")
        )

    if not localRoot or not targetRoot then
        return math.huge
    end

    return (
        localRoot.Position - targetRoot.Position
    ).Magnitude
end

local function GetScreenDistance(targetPart, camera)
    local screenPosition, onScreen =
        camera:WorldToViewportPoint(
            targetPart.Position
        )

    if screenPosition.Z <= 0 then
        return math.huge, false, screenPosition
    end

    local screenCenter = Vector2.new(
        camera.ViewportSize.X / 2,
        camera.ViewportSize.Y / 2
    )

    local target2D = Vector2.new(
        screenPosition.X,
        screenPosition.Y
    )

    local screenDistance =
        (target2D - screenCenter).Magnitude

    return screenDistance, onScreen, screenPosition
end

-- Single validation function for AIM.
local function IsValidTarget(target)
    if not Config.AimEnabled then
        return false
    end

    if not target or target == LocalPlayer then
        return false
    end

    if not target:IsDescendantOf(Players) then
        return false
    end

    if not IsAliveAimTarget(target) then
        return false
    end

    if not PassesAimTeamCheck(target) then
        return false
    end

    local targetRoot = GetAimRoot(target)
    if not targetRoot then
        return false
    end

    local targetPart = GetAimPart(target)
    if not targetPart then
        return false
    end

    local worldDistance = GetAimWorldDistance(targetRoot)
    if worldDistance > Config.AimMaxDistance then
        return false
    end

    if not PassesVisibility(targetPart) then
        return false
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return false
    end

    local screenDistance, onScreen =
        GetScreenDistance(targetPart, camera)

    if screenDistance == math.huge then
        return false
    end

    if Config.UseFOV then
        if not onScreen then
            return false
        end

        if screenDistance > Config.FOV then
            return false
        end
    end

    return true
end

local function GetBestTarget()
    local camera = Workspace.CurrentCamera

    if not camera or not Config.AimEnabled then
        return nil, nil
    end

    local bestTarget = nil
    local bestAimPart = nil
    local bestScreenDistance = math.huge

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer and IsValidTarget(target) then
            -- Re-read the CURRENT target part on every frame.
            local targetPart = GetAimPart(target)

            if targetPart then
                local screenDistance, onScreen =
                    GetScreenDistance(
                        targetPart,
                        camera
                    )

                if screenDistance < math.huge then
                    if (not Config.UseFOV) or onScreen then
                        if screenDistance < bestScreenDistance then
                            bestScreenDistance = screenDistance
                            bestTarget = target
                            bestAimPart = targetPart
                        end
                    end
                end
            end
        end
    end

    return bestTarget, bestAimPart
end

-- ---------------------------------------------------------
-- Fire-state input
-- This only supplies an input-state check for "Aim On Fire".
-- It does not implement, replace, or spoof the game's weapon.
-- ---------------------------------------------------------
local TouchFireActive = false

AddConnection(
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.Touch then
            TouchFireActive = true
        end
    end)
)

AddConnection(
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            TouchFireActive = false
        end
    end)
)

local function IsFiring()
    if UserInputService:IsMouseButtonPressed(
        Enum.UserInputType.MouseButton1
    ) then
        return true
    end

    return TouchFireActive
end

local function IsAimAllowed()
    if Config.AlwaysAim then
        return true
    end

    if Config.AimOnFire then
        return IsFiring()
    end

    return false
end

local function AimAtTarget(targetPart)
    if not targetPart or not targetPart.Parent then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    -- Use the CURRENT world position from the current skeleton part.
    local targetPosition = targetPart.Position

    local currentCFrame = camera.CFrame

    local targetCFrame =
        CFrame.lookAt(
            currentCFrame.Position,
            targetPosition
        )

    local smoothness = math.clamp(
        tonumber(Config.Smoothness) or 0.20,
        0.2,
        1
    )

    camera.CFrame =
        currentCFrame:Lerp(
            targetCFrame,
            smoothness
        )
end

local function UpdateAim()
    if not Config.AimEnabled then
        CurrentAimTarget = nil
        return
    end

    if not IsAimAllowed() then
        CurrentAimTarget = nil
        return
    end

    local target, targetPart = GetBestTarget()

    if not target or not targetPart then
        CurrentAimTarget = nil
        return
    end

    -- Re-validate immediately before camera movement.
    if not IsValidTarget(target) then
        CurrentAimTarget = nil
        return
    end

    -- Re-acquire from the current character, avoiding stale part refs.
    local currentAimPart = GetAimPart(target)

    if not currentAimPart or not currentAimPart.Parent then
        CurrentAimTarget = nil
        return
    end

    CurrentAimTarget = target
    AimAtTarget(currentAimPart)
end

-- ---------------------------------------------------------
-- Future AIM features
-- ---------------------------------------------------------
-- Prediction
-- Target Priority
-- Switch Target
-- Sticky Aim
-- Velocity Prediction
-- Distance Priority

-- ------------------------------------------
-- ESP RENDER ENGINE CORE
-- ------------------------------------------

local espData = {}

local R6Skeleton = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local R15Skeleton = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},

    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},

    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},

    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},

    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local function createScreenLine(name)
    local line = Instance.new("Frame")
    line.Name = name
    line.Size = UDim2.fromOffset(0, 2)
    line.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    line.BorderSizePixel = 0
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Visible = false
    line.ZIndex = 20
    line.Parent = ScreenGui
    return line
end

local function updateScreenLine(line, from, to)
    if not line then
        return
    end

    local delta = to - from
    local length = delta.Magnitude

    if length <= 0 then
        line.Visible = false
        return
    end

    local midpoint = (from + to) / 2

    line.Position = UDim2.fromOffset(midpoint.X, midpoint.Y)
    line.Size = UDim2.fromOffset(length, 2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.Visible = true
end

local function createInfo()
    local holder = Instance.new("Frame")
    holder.Name = "ESPInfo"
    holder.Size = UDim2.fromOffset(200, 75)
    holder.AnchorPoint = Vector2.new(0.5, 1)
    holder.BackgroundTransparency = 1
    holder.Visible = false
    holder.ZIndex = 25
    holder.Parent = ScreenGui

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.ZIndex = 26
    nameLabel.Parent = holder

    local healthLabel = Instance.new("TextLabel")
    healthLabel.Name = "Health"
    healthLabel.Size = UDim2.new(1, 0, 0, 18)
    healthLabel.Position = UDim2.fromOffset(0, 20)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(70, 255, 100)
    healthLabel.TextStrokeTransparency = 0
    healthLabel.Font = Enum.Font.GothamSemibold
    healthLabel.TextSize = 12
    healthLabel.ZIndex = 26
    healthLabel.Parent = holder

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "Distance"
    distanceLabel.Size = UDim2.new(1, 0, 0, 18)
    distanceLabel.Position = UDim2.fromOffset(0, 38)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    distanceLabel.TextStrokeTransparency = 0
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextSize = 11
    distanceLabel.ZIndex = 26
    distanceLabel.Parent = holder

    return holder
end

local function GetSkeletonDefinition(character)
    if not character then
        return R6Skeleton
    end

    if character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("LowerTorso")
        or character:FindFirstChild("LeftUpperArm")
        or character:FindFirstChild("RightUpperArm") then
        return R15Skeleton
    end

    return R6Skeleton
end

local function EnsureSkeletonLines(data, character)
    if not data or not character then
        return
    end

    local skeletonList = GetSkeletonDefinition(character)
    local existing = {}

    for _, skeleton in ipairs(data.skeleton or {}) do
        existing[skeleton.partA .. "|" .. skeleton.partB] = skeleton
    end

    for _, connection in ipairs(skeletonList) do
        local key = connection[1] .. "|" .. connection[2]

        if not existing[key] then
            local line = createScreenLine("ESPSkeleton")
            line.BackgroundColor3 =
                Color3.fromRGB(255, 255, 255)

            table.insert(data.skeleton, {
                line = line,
                partA = connection[1],
                partB = connection[2]
            })
        end
    end
end

local function createTargetESP(target)
    local data = {}

    data.character = target.Character
    data.info = createInfo()
    data.tracer = createScreenLine("ESPTracer")
    data.skeleton = {}

    EnsureSkeletonLines(data, data.character)

    return data
end

local function destroyTargetESP(target)
    local data = espData[target]

    if not data then
        return
    end

    if data.info then
        data.info:Destroy()
    end

    if data.tracer then
        data.tracer:Destroy()
    end

    for _, skeleton in ipairs(data.skeleton or {}) do
        if skeleton.line then
            skeleton.line:Destroy()
        end
    end

    espData[target] = nil
end

local function hideTargetESP(data)
    if not data then
        return
    end

    if data.info then
        data.info.Visible = false
    end

    if data.tracer then
        data.tracer.Visible = false
    end

    for _, skeleton in ipairs(data.skeleton or {}) do
        if skeleton.line then
            skeleton.line.Visible = false
        end
    end
end

local function updateTargetESP(target)
    local character = target.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")

    if not character or not humanoid or humanoid.Health <= 0 or not root then
        destroyTargetESP(target)
        return
    end

    -- Team / Enemy hoàn toàn độc lập với Aim.
    -- In games without Roblox Teams, both Team values can be nil;
    -- treat those players as enemies instead of teammates.
    local hasTeams = LocalPlayer.Team ~= nil and target.Team ~= nil
    local isTeammate = hasTeams and (target.Team == LocalPlayer.Team)
    local isEnemy = not isTeammate

    if isEnemy then
        if not Config.ShowEnemies then
            destroyTargetESP(target)
            return
        end
    elseif isTeammate then
        if not Config.ShowTeammates then
            destroyTargetESP(target)
            return
        end
    end

    local data = espData[target]

    -- Respawn: character cũ bị xóa và rebuild theo character mới.
    if data and data.character ~= character then
        destroyTargetESP(target)
        data = nil
    end

    if not data then
        data = createTargetESP(target)
        espData[target] = data
    else
        EnsureSkeletonLines(data, character)
    end

    local camera = Workspace.CurrentCamera

    if not camera then
        return
    end

    -- Khoảng cách 3D.
    local myRoot =
        LocalPlayer.Character and
        LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    local distance =
        myRoot and
        (myRoot.Position - root.Position).Magnitude or
        math.huge

    if distance > Config.MaxDistance or not Config.Enabled then
        hideTargetESP(data)
        return
    end

    -- Tọa độ màn hình.
    local rootScreen, rootOnScreen =
        camera:WorldToViewportPoint(root.Position)

    local headScreen
    local headOnScreen = false

    if head then
        headScreen, headOnScreen =
            camera:WorldToViewportPoint(head.Position)
    end

    -- NAME / HEALTH / DISTANCE
    local showInfo =
        Config.ShowName or
        Config.ShowHealth or
        Config.ShowDistance

    if
        showInfo and
        headOnScreen and
        headScreen.Z > 0
    then
        local info = data.info

        -- AnchorPoint = (0.5, 1) => info nằm phía trên đầu.
        info.Position =
            UDim2.fromOffset(
                headScreen.X,
                headScreen.Y - 8
            )

        info.Visible = true

        local nameLabel = info:FindFirstChild("Name")
        local healthLabel = info:FindFirstChild("Health")
        local distanceLabel = info:FindFirstChild("Distance")

        if nameLabel then
            nameLabel.Visible = Config.ShowName
            nameLabel.Text =
                target.DisplayName ..
                "  @" ..
                target.Name
        end

        if healthLabel then
            healthLabel.Visible = Config.ShowHealth

            local currentHP = math.floor(humanoid.Health)
            local maxHP = math.floor(humanoid.MaxHealth)

            if maxHP <= 0 then
                maxHP = 100
            end

            healthLabel.Text =
                "HP: " ..
                currentHP ..
                " / " ..
                maxHP
        end

        if distanceLabel then
            distanceLabel.Visible = Config.ShowDistance
            distanceLabel.Text = math.floor(distance) .. " studs"
        end
    else
        data.info.Visible = false
    end

    -- TRACER
    if
        Config.ShowTracer and
        rootOnScreen and
        rootScreen.Z > 0
    then
        -- Bottom Center -> HumanoidRootPart của frame hiện tại.
        local from =
            Vector2.new(
                camera.ViewportSize.X / 2,
                camera.ViewportSize.Y - 8
            )

        local to =
            Vector2.new(
                rootScreen.X,
                rootScreen.Y
            )

        updateScreenLine(
            data.tracer,
            from,
            to
        )
    else
        data.tracer.Visible = false
    end

    -- SKELETON R6 / R15.
    if Config.ShowSkeleton then
        -- Lấy lại Position từng part mỗi frame để bám animation.
        for _, skeleton in ipairs(data.skeleton) do
            local partA = character:FindFirstChild(skeleton.partA)
            local partB = character:FindFirstChild(skeleton.partB)

            if partA and partB then
                local posA, visibleA =
                    camera:WorldToViewportPoint(partA.Position)

                local posB, visibleB =
                    camera:WorldToViewportPoint(partB.Position)

                if
                    visibleA and
                    visibleB and
                    posA.Z > 0 and
                    posB.Z > 0
                then
                    updateScreenLine(
                        skeleton.line,
                        Vector2.new(posA.X, posA.Y),
                        Vector2.new(posB.X, posB.Y)
                    )
                else
                    skeleton.line.Visible = false
                end
            else
                skeleton.line.Visible = false
            end
        end
    else
        for _, skeleton in ipairs(data.skeleton) do
            skeleton.line.Visible = false
        end
    end
end

local function updateESP()
    -- Master Toggle: tắt thì không render bất kỳ module nào.
    if not Config.Enabled then
        for target in pairs(espData) do
            destroyTargetESP(target)
        end
        return
    end

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer then
            updateTargetESP(target)
        end
    end
end

-- =========================================================
-- ESP HIGHLIGHT ADD-ON
-- Independent of the existing ESP render objects.
-- Uses one shared rainbow color for every Highlight.
-- =========================================================

local espHighlightData = {}
local ESPHighlightName = "__HoodRivals_ESPHighlight"

local function destroyESPHighlight(target)
    local data = espHighlightData[target]

    if data then
        if data.highlight and data.highlight.Parent then
            data.highlight:Destroy()
        end

        espHighlightData[target] = nil
        return
    end

    local character = target and target.Character
    if character then
        local orphan = character:FindFirstChild(ESPHighlightName)
        if orphan and orphan:IsA("Highlight") then
            orphan:Destroy()
        end
    end
end

local function destroyAllESPHighlights()
    local targets = {}

    for target in pairs(espHighlightData) do
        table.insert(targets, target)
    end

    for _, target in ipairs(targets) do
        destroyESPHighlight(target)
    end

    -- Also remove orphaned objects from any character.
    for _, target in ipairs(Players:GetPlayers()) do
        local character = target.Character
        if character then
            local orphan = character:FindFirstChild(ESPHighlightName)
            if orphan and orphan:IsA("Highlight") then
                orphan:Destroy()
            end
        end
    end
end

local function IsESPHighlightTargetValid(target)
    if not target or target == LocalPlayer then
        return false
    end

    local character = target.Character
    local humanoid =
        character and
        character:FindFirstChildOfClass("Humanoid")
    local root =
        character and
        character:FindFirstChild("HumanoidRootPart")

    if
        not character
        or not humanoid
        or humanoid.Health <= 0
        or not root
    then
        return false
    end

    -- Match the existing ESP team/enemy classification.
    local hasTeams =
        LocalPlayer.Team ~= nil
        and target.Team ~= nil

    local isTeammate =
        hasTeams
        and target.Team == LocalPlayer.Team

    local isEnemy = not isTeammate

    if isEnemy and not Config.ShowEnemies then
        return false
    end

    if isTeammate and not Config.ShowTeammates then
        return false
    end

    local myRoot =
        LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if myRoot then
        local distance =
            (myRoot.Position - root.Position).Magnitude

        if distance > Config.MaxDistance then
            return false
        end
    end

    return true, character
end

local function UpdateESPHighlight()
    if not Config.ESPHighlightEnabled then
        destroyAllESPHighlights()
        return
    end

    -- One shared rainbow state for ALL highlight instances.
    local rainbowColor =
        Color3.fromHSV(
            (os.clock() * 0.20) % 1,
            1,
            1
        )

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer then
            local valid, character =
                IsESPHighlightTargetValid(target)

            if not valid then
                destroyESPHighlight(target)
            else
                local data = espHighlightData[target]

                if data and data.character ~= character then
                    destroyESPHighlight(target)
                    data = nil
                end

                if not data then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = ESPHighlightName
                    highlight.Adornee = character
                    highlight.FillTransparency = 0.50
                    highlight.OutlineTransparency = 0
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = ScreenGui

                    data = {
                        character = character,
                        highlight = highlight
                    }

                    espHighlightData[target] = data
                end

                if
                    data.highlight
                    and data.highlight.Parent
                then
                    data.highlight.Adornee = character
                    data.highlight.FillColor = rainbowColor
                    data.highlight.OutlineColor = rainbowColor
                end
            end
        end
    end
end

-- =========================================================
-- TELEPORT TAB ADD-ON
-- Uses the existing PageManager/UI components.
-- Floating controls live directly under ScreenGui, outside MainWindow.
-- =========================================================

local TeleportPage = PageManager:AddPage("TELEPORT")
local ActiveTpButtons = {}

local TeleportListSec =
    UI:CreateSection(
        TeleportPage,
        "PLAYER LIST"
    )

local TeleportList =
    Instance.new("ScrollingFrame")

TeleportList.Name = "TeleportPlayerList"
TeleportList.Size = UDim2.new(1, 0, 0, 150)
TeleportList.BackgroundTransparency = 1
TeleportList.BorderSizePixel = 0
TeleportList.ScrollBarThickness = 3
TeleportList.ScrollBarImageColor3 = Config.SubTextColor
TeleportList.Parent = TeleportListSec

local TeleportListLayout =
    Instance.new("UIListLayout")

TeleportListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TeleportListLayout.Padding = UDim.new(0, 6)
TeleportListLayout.Parent = TeleportList

local TeleportSelectedSec =
    UI:CreateSection(
        TeleportPage,
        "SELECTED PLAYER"
    )

local SelectedPlayerLabel =
    UI:CreateLabel(
        TeleportSelectedSec,
        "No player selected"
    )

local function UpdateSelectedPlayerLabel()
    local selected = Config.Teleport.SelectedPlayer

    if selected and selected.Parent == Players then
        SelectedPlayerLabel.Text =
            "Selected: "
            .. selected.DisplayName
            .. " (@"
            .. selected.Name
            .. ")"
    else
        SelectedPlayerLabel.Text = "No player selected"
        Config.Teleport.SelectedPlayer = nil
    end
end

local function DestroyTeleportButton(target)
    local data = ActiveTpButtons[target]

    if not data then
        return
    end

    data.active = false

    if data.tpConnection then
        pcall(function()
            data.tpConnection:Disconnect()
        end)
        data.tpConnection = nil
    end

    if data.closeConnection then
        pcall(function()
            data.closeConnection:Disconnect()
        end)
        data.closeConnection = nil
    end

    if data.frame and data.frame.Parent then
        data.frame:Destroy()
    end

    ActiveTpButtons[target] = nil
end

local function GetTeleportButtonIndex()
    local count = 0

    for target, data in pairs(ActiveTpButtons) do
        if
            target
            and target.Parent == Players
            and data
            and data.frame
            and data.frame.Parent
        then
            count += 1
        end
    end

    return count
end

local function CreateTeleportButton(target)
    local existing = ActiveTpButtons[target]

    if
        existing
        and existing.frame
        and existing.frame.Parent
    then
        return existing
    end

    local frame = Instance.new("Frame")
    frame.Name = "Teleport_" .. target.Name
    frame.Size = UDim2.new(0, 155, 0, 58)
    frame.Position =
        UDim2.new(
            1,
            -180,
            0.12,
            GetTeleportButtonIndex() * 68
        )
    frame.BackgroundColor3 = Config.CardBg
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ZIndex = 50
    frame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.BorderColor
    stroke.Thickness = 1
    stroke.Parent = frame

    local tpButton = Instance.new("TextButton")
    tpButton.Name = "TPButton"
    tpButton.Size = UDim2.new(1, -30, 0, 30)
    tpButton.Position = UDim2.new(0, 6, 0, 5)
    tpButton.Text = "TP OFF"
    tpButton.TextColor3 = Config.TextColor
    tpButton.Font = Enum.Font.GothamMedium
    tpButton.TextSize = 12
    tpButton.BackgroundColor3 = Config.DarkBg
    tpButton.AutoButtonColor = false
    tpButton.ZIndex = 51
    tpButton.Parent = frame

    local tpCorner = Instance.new("UICorner")
    tpCorner.CornerRadius = UDim.new(0, 5)
    tpCorner.Parent = tpButton

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "TargetName"
    nameLabel.Size = UDim2.new(1, -12, 0, 16)
    nameLabel.Position = UDim2.new(0, 6, 0, 37)
    nameLabel.Text =
        target.DisplayName .. "  @" .. target.Name
    nameLabel.TextColor3 = Config.SubTextColor
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 10
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.BackgroundTransparency = 1
    nameLabel.ZIndex = 51
    nameLabel.Parent = frame

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "Close"
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -24, 0, 3)
    closeButton.Text = "X"
    closeButton.TextColor3 = Config.TextColor
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 10
    closeButton.BackgroundColor3 = Config.DarkBg
    closeButton.AutoButtonColor = false
    closeButton.ZIndex = 52
    closeButton.Parent = frame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton

    local data = {
        frame = frame,
        button = tpButton,
        active = false
    }

    ActiveTpButtons[target] = data

    -- Reuse the menu's existing drag utility for the floating control.
    MakeDraggable(frame, nameLabel, true)

    data.tpConnection =
        tpButton.MouseButton1Click:Connect(function()
            if not target or target.Parent ~= Players then
                DestroyTeleportButton(target)
                return
            end

            data.active = not data.active

            if data.active then
                tpButton.Text = "TP ON"
                tpButton.BackgroundColor3 = Config.AccentColor
            else
                tpButton.Text = "TP OFF"
                tpButton.BackgroundColor3 = Config.DarkBg
            end
        end)

    data.closeConnection =
        closeButton.MouseButton1Click:Connect(function()
            DestroyTeleportButton(target)
        end)

    return data
end

local function RefreshTeleportPlayerList()
    for _, child in ipairs(TeleportList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local players = Players:GetPlayers()

    for _, target in ipairs(players) do
        if target ~= LocalPlayer then
            local button =
                UI:CreateButton(
                    TeleportList,
                    target.DisplayName
                        .. "  (@"
                        .. target.Name
                        .. ")",
                    function()
                        if target.Parent ~= Players then
                            return
                        end

                        Config.Teleport.SelectedPlayer = target
                        UpdateSelectedPlayerLabel()

                        -- Click = select + create/reuse floating TP control.
                        CreateTeleportButton(target)

                        RefreshTeleportPlayerList()
                    end
                )

            if Config.Teleport.SelectedPlayer == target then
                button.BackgroundColor3 =
                    Config.AccentColor
                button.TextColor3 =
                    Color3.fromRGB(255, 255, 255)
            end
        end
    end

    TeleportList.CanvasSize =
        UDim2.new(
            0,
            0,
            0,
            TeleportListLayout.AbsoluteContentSize.Y + 8
        )

    UpdateSelectedPlayerLabel()
end

local function UpdateTeleport()
    local localCharacter = LocalPlayer.Character
    local localRoot =
        localCharacter
        and localCharacter:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return
    end

    local invalidTargets = {}

    for target, data in pairs(ActiveTpButtons) do
        if
            not target
            or target.Parent ~= Players
            or not data
            or not data.frame
            or not data.frame.Parent
        then
            table.insert(invalidTargets, target)
        elseif data.active then
            local targetCharacter = target.Character
            local targetRoot =
                targetCharacter
                and targetCharacter:FindFirstChild(
                    "HumanoidRootPart"
                )

            if targetRoot then
                localRoot.CFrame =
                    targetRoot.CFrame
                    * CFrame.new(0, 0, 3)
            end
        end
    end

    for _, target in ipairs(invalidTargets) do
        DestroyTeleportButton(target)
    end
end

RefreshTeleportPlayerList()

-- =========================================================
-- UNIFIED RENDER LOOP
-- One frame pipeline for AIM + FOV + ESP.
-- Bound to Enum.RenderPriority.Last.Value + 100 to guarantee
-- execution AFTER Hood Rivals updates its custom shoulder camera/scope CFrame.
-- =========================================================
pcall(function()
    RunService:UnbindFromRenderStep("HoodRivalsUnifiedRender")
end)

RunService:BindToRenderStep(
    "HoodRivalsUnifiedRender",
    Enum.RenderPriority.Last.Value + 100,
    function(renderDt)
        UpdateAim()
        UpdateFOVCircle()
        updateESP()
        UpdateESPHighlight()
        UpdatePlayer(renderDt)
        UpdateTeleport()
    end
)

-- =========================================================
-- SHARED PLAYER LIFECYCLE
-- =========================================================

local function BindPlayerLifecycle(target)
    if target == LocalPlayer then
        return
    end

    AddConnection(
        target.CharacterAdded:Connect(function()
            -- ESP rebuilds from the new character.
            destroyTargetESP(target)
            destroyESPHighlight(target)

            -- AIM must never retain the old target state.
            if CurrentAimTarget == target then
                CurrentAimTarget = nil
            end
        end)
    )

    AddConnection(
        target.CharacterRemoving:Connect(function()
            destroyTargetESP(target)
            destroyESPHighlight(target)

            if CurrentAimTarget == target then
                CurrentAimTarget = nil
            end
        end)
    )
end

for _, target in ipairs(Players:GetPlayers()) do
    if target ~= LocalPlayer then
        BindPlayerLifecycle(target)
    end
end

AddConnection(
    Players.PlayerAdded:Connect(function(target)
        BindPlayerLifecycle(target)
        RefreshTeleportPlayerList()
    end)
)

AddConnection(
    Players.PlayerRemoving:Connect(function(target)
        destroyTargetESP(target)
        destroyESPHighlight(target)
        DestroyTeleportButton(target)

        if Config.Teleport.SelectedPlayer == target then
            Config.Teleport.SelectedPlayer = nil
            UpdateSelectedPlayerLabel()
        end

        if CurrentAimTarget == target then
            CurrentAimTarget = nil
        end

        RefreshTeleportPlayerList()
    end)
)


-- Mở mặc định Tab ESP
PageManager:ShowPage(Config.StartPage)

-- ==========================================
-- 10. EVENT CONTROLS & MINIMIZE / CLOSE
-- ==========================================

local function SetMenuState(newState)
    GUIState.CurrentState = newState
    if newState == "Open" then
        MainWindow.Visible = true
        FloatingBtn.Visible = false
    elseif newState == "Minimized" then
        MainWindow.Visible = false
        FloatingBtn.Visible = true
    elseif newState == "Closed" then
        ScreenGui.Enabled = false
    end
end

-- Minimize Button
MinimizeBtn.MouseButton1Click:Connect(function()
    SetMenuState("Minimized")
end)

-- Floating Open Button Click Logic
FloatingBtn.MouseButton1Click:Connect(function()
    if not isFloatDragged() then
        SetMenuState("Open")
    end
end)

-- Close Button
CloseBtn.MouseButton1Click:Connect(function()
    SetMenuState("Closed")

    CleanupPlayerRuntime()

    pcall(function()
        RunService:UnbindFromRenderStep("HoodRivalsUnifiedRender")
    end)

    FOVCircle.Visible = false

    for target in pairs(espData) do
        destroyTargetESP(target)
    end

    destroyAllESPHighlights()
end)

-- Keybind Event (RightControl)
AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if Config.ToggleKeyEnabled and input.KeyCode == Config.ToggleKey then
        if GUIState.CurrentState == "Open" then
            SetMenuState("Minimized")
        elseif GUIState.CurrentState == "Minimized" or GUIState.CurrentState == "Closed" then
            ScreenGui.Enabled = true

            -- Rebind the single unified render callback safely.
            pcall(function()
                RunService:UnbindFromRenderStep(
                    "HoodRivalsUnifiedRender"
                )
            end)

            RunService:BindToRenderStep(
                "HoodRivalsUnifiedRender",
                Enum.RenderPriority.Last.Value + 100,
                function(renderDt)
                    UpdateAim()
                    UpdateFOVCircle()
                    updateESP()
                    UpdateESPHighlight()
                    UpdatePlayer(renderDt)
                    UpdateTeleport()
                end
            )

            SetMenuState("Open")
        end
    end
end))

-- Expose UI Framework global variable
local function CleanupFramework()
    CleanupPlayerRuntime()

    pcall(function()
        RunService:UnbindFromRenderStep(
            "HoodRivalsUnifiedRender"
        )
    end)

    FOVCircle.Visible = false

    for target in pairs(espData) do
        destroyTargetESP(target)
    end

    destroyAllESPHighlights()

    local teleportTargetsToCleanup = {}

    for target in pairs(ActiveTpButtons) do
        table.insert(teleportTargetsToCleanup, target)
    end

    for _, target in ipairs(teleportTargetsToCleanup) do
        DestroyTeleportButton(target)
    end

    Config.Teleport.SelectedPlayer = nil

    for _, conn in ipairs(Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
end

_G.MyGUIFramework = {
    PageManager = PageManager,
    UI = UI,
    ScreenGui = ScreenGui,
    MainWindow = MainWindow,
    Config = Config,

    Player = {
        Cleanup = CleanupPlayerRuntime,
        Update = UpdatePlayer
    },

    Aim = {
        IsValidTarget = IsValidTarget,
        GetBestTarget = GetBestTarget,
        Update = UpdateAim,
        GetCurrentTarget = function()
            return CurrentAimTarget
        end
    },

    Cleanup = CleanupFramework
}

print("[Hood Rivals Framework & ESP Integrated Successfully!]")
