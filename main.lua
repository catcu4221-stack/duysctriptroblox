-- ==========================================
-- 1. SERVICES & INITIALIZATION
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

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
    ShowEnemies = true,
    ShowTeammates = false,
    ShowName = false,
    ShowTracer = false,
    ShowSkeleton = false,
    ShowHealth = false,
    ShowDistance = false,
    MaxDistance = 2000
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
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = TargetParent

local UIScaleObj = Instance.new("UIScale")
UIScaleObj.Scale = Config.UIScale
UIScaleObj.Parent = ScreenGui

-- ==========================================
-- 4. UTILITY FUNCTIONS (DRAG & TOUCH)
-- ==========================================
local function MakeDraggable(guiObject, dragHandle)
    dragHandle = dragHandle or guiObject
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

    local currentValue = math.clamp(default, min, max)

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 40)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 18)
    label.Text = text
    label.TextColor3 = Config.TextColor
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Parent = sliderFrame

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.4, 0, 0, 18)
    valLabel.Position = UDim2.new(0.6, 0, 0, 0)
    valLabel.Text = tostring(currentValue)
    valLabel.TextColor3 = Config.SubTextColor
    valLabel.Font = Enum.Font.Gotham
    valLabel.TextSize = 12
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.BackgroundTransparency = 1
    valLabel.Parent = sliderFrame

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
    fill.Size = UDim2.new((currentValue - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Config.AccentColor
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(1, 0)
    fCorner.Parent = fill

    local dragging = false

    local function updateValue(inputPos)
        local percentage = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local rawValue = min + (max - min) * percentage
        currentValue = math.floor(rawValue / increment + 0.5) * increment
        currentValue = math.clamp(currentValue, min, max)

        fill.Size = UDim2.new((currentValue - min) / (max - min), 0, 1, 0)
        valLabel.Text = tostring(currentValue)
        callback(currentValue)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateValue(input.Position)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input.Position)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

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

local function createTargetESP(target)
    local data = {}

    data.character = target.Character
    data.info = createInfo()
    data.tracer = createScreenLine("ESPTracer")
    data.skeleton = {}

    local character = target.Character

    if character then
        local skeletonList

        if character:FindFirstChild("UpperTorso") then
            skeletonList = R15Skeleton
        else
            skeletonList = R6Skeleton
        end

        for _, connection in ipairs(skeletonList) do
            local line = createScreenLine("ESPSkeleton")
            line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

            table.insert(data.skeleton, {
                line = line,
                partA = connection[1],
                partB = connection[2]
            })
        end
    end

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
    local isTeammate = target.Team == LocalPlayer.Team
    local isEnemy = target.Team ~= LocalPlayer.Team

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

local function bindPlayerLifecycle(target)
    if target == LocalPlayer then
        return
    end

    -- Khi respawn, bỏ object của character cũ để RenderStepped rebuild.
    AddConnection(
        target.CharacterAdded:Connect(function()
            destroyTargetESP(target)
        end)
    )

    AddConnection(
        target.CharacterRemoving:Connect(function()
            destroyTargetESP(target)
        end)
    )
end

-- Players đã có sẵn khi script khởi động.
for _, target in ipairs(Players:GetPlayers()) do
    if target ~= LocalPlayer then
        bindPlayerLifecycle(target)
    end
end

-- PlayerAdded: player mới được nhận bởi ESP core ở RenderStepped kế tiếp.
AddConnection(
    Players.PlayerAdded:Connect(function(target)
        bindPlayerLifecycle(target)
    end)
)

-- PlayerRemoving: cleanup toàn bộ object của player rời game.
AddConnection(
    Players.PlayerRemoving:Connect(function(target)
        destroyTargetESP(target)
    end)
)

-- Chỉ một RenderStepped cho ESP core.
AddConnection(
    RunService.RenderStepped:Connect(function()
        updateESP()
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
    for target in pairs(espData) do
        destroyTargetESP(target)
    end
    for _, conn in ipairs(Connections) do
        conn:Disconnect()
    end
end)

-- Keybind Event (RightControl)
AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if Config.ToggleKeyEnabled and input.KeyCode == Config.ToggleKey then
        if GUIState.CurrentState == "Open" then
            SetMenuState("Minimized")
        elseif GUIState.CurrentState == "Minimized" or GUIState.CurrentState == "Closed" then
            ScreenGui.Enabled = true
            SetMenuState("Open")
        end
    end
end))

-- Expose UI Framework global variable
_G.MyGUIFramework = {
    PageManager = PageManager,
    UI = UI,
    ScreenGui = ScreenGui,
    MainWindow = MainWindow,
    Config = Config
}

print("[Hood Rivals Framework & ESP Integrated Successfully!]")
