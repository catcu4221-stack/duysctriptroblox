-- ==========================================
-- 1. SERVICES & INITIALIZATION
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

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
    
    StartPage = "Information"
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

local SidebarList = Instance.new("UIListLayout")
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 6)
SidebarList.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 10)
SidebarPadding.PaddingLeft = UDim.new(0, 8)
SidebarPadding.PaddingRight = UDim.new(0, 8)
SidebarPadding.Parent = Sidebar

-- Author Label bottom sidebar
local AuthorLabel = Instance.new("TextLabel")
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
    tabBtn.Parent = Sidebar

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
        callback(box.Text, enterPressed)
    end)

    return box
end

function UI:CreateDropdown(parent, options)
    options = options or {}
    local text = options.Text or "Dropdown"
    local list = options.Options or {}
    local default = options.Default or list[1] or ""
    local callback = options.Callback or function() end

    local isOpened = false

    local dropFrame = Instance.new("Frame")
    dropFrame.Size = UDim2.new(1, 0, 0, 32)
    dropFrame.BackgroundColor3 = Config.DarkBg
    dropFrame.BorderSizePixel = 0
    dropFrame.ClipsDescendants = true
    dropFrame.Parent = parent

    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(0, 5)
    dCorner.Parent = dropFrame

    local titleBtn = Instance.new("TextButton")
    titleBtn.Size = UDim2.new(1, 0, 0, 32)
    titleBtn.Text = "  " .. text .. ": " .. default
    titleBtn.TextColor3 = Config.TextColor
    titleBtn.Font = Enum.Font.GothamMedium
    titleBtn.TextSize = 12
    titleBtn.TextXAlignment = Enum.TextXAlignment.Left
    titleBtn.BackgroundTransparency = 1
    titleBtn.Parent = dropFrame

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 32, 0, 32)
    arrow.Position = UDim2.new(1, -32, 0, 0)
    arrow.Text = "▼"
    arrow.TextColor3 = Config.SubTextColor
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 10
    arrow.BackgroundTransparency = 1
    arrow.Parent = dropFrame

    local optContainer = Instance.new("Frame")
    optContainer.Size = UDim2.new(1, 0, 0, #list * 25)
    optContainer.Position = UDim2.new(0, 0, 0, 32)
    optContainer.BackgroundTransparency = 1
    optContainer.Parent = dropFrame

    local oList = Instance.new("UIListLayout")
    oList.SortOrder = Enum.SortOrder.LayoutOrder
    oList.Parent = optContainer

    for _, optText in ipairs(list) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 25)
        optBtn.Text = "  " .. optText
        optBtn.TextColor3 = Config.SubTextColor
        optBtn.Font = Enum.Font.Gotham
        optBtn.TextSize = 11
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.BackgroundTransparency = 1
        optBtn.Parent = optContainer

        optBtn.MouseButton1Click:Connect(function()
            titleBtn.Text = "  " .. text .. ": " .. optText
            isOpened = false
            TweenService:Create(dropFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 32)}):Play()
            arrow.Text = "▼"
            callback(optText)
        end)
    end

    titleBtn.MouseButton1Click:Connect(function()
        isOpened = not isOpened
        local targetSize = isOpened and UDim2.new(1, 0, 0, 32 + (#list * 25)) or UDim2.new(1, 0, 0, 32)
        arrow.Text = isOpened and "▲" or "▼"
        TweenService:Create(dropFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()
    end)

    return dropFrame
end

-- ==========================================
-- 8. INITIALIZE PAGES & DEFAULT CONTENT
-- ==========================================

-- Tab 1: Information
local InfoPage = PageManager:AddPage("Information")

local WelcomeSec = UI:CreateSection(InfoPage, "Information")
UI:CreateLabel(WelcomeSec, "Welcome, Brothers!")
UI:CreateLabel(WelcomeSec, "TAO LA BỐ CỦA CHÚNG MÀY OK ")
UI:CreateLabel(WelcomeSec, "HACK ANTI CHO TỚI LÚC BAN ")

local CreditsSec = UI:CreateSection(InfoPage, "Credits")
UI:CreateLabel(CreditsSec, "- Dev: @Duyhoccode")
UI:CreateLabel(CreditsSec, "- UI: hehe tự copy ")

-- Tab 2: Settings
local SettingsPage = PageManager:AddPage("Settings")

local ConfigSec = UI:CreateSection(SettingsPage, "Configuration")
UI:CreateLabel(ConfigSec, "You can change the menu color, background, and keybinds.")

UI:CreateSlider(ConfigSec, {
    Text = "Background Transparency",
    Min = 0,
    Max = 100,
    Default = math.floor(Config.BackgroundTransparency * 100),
    Increment = 5,
    Callback = function(val)
        Config.BackgroundTransparency = val / 100
        MainWindow.BackgroundTransparency = Config.BackgroundTransparency
    end
})

UI:CreateSlider(ConfigSec, {
    Text = "UI Scale",
    Min = 8,
    Max = 14,
    Default = 10,
    Increment = 1,
    Callback = function(val)
        UIScaleObj.Scale = val / 10
    end
})

local KeybindSec = UI:CreateSection(SettingsPage, "Keybind Menu (PC)")
UI:CreateLabel(KeybindSec, "For PC users, you can use this keybind as a shortcut to open/close the menu.")

UI:CreateToggle(KeybindSec, {
    Text = "Enable Keybind Toggle",
    Default = Config.ToggleKeyEnabled,
    Callback = function(state)
        Config.ToggleKeyEnabled = state
    end
})

local ActionsSec = UI:CreateSection(SettingsPage, "Actions")

UI:CreateButton(ActionsSec, "Reset UI Position", function()
    MainWindow.Position = UDim2.new(0.5, -280, 0.5, -180)
end)

UI:CreateButton(ActionsSec, "Reset Settings", function()
    MainWindow.BackgroundTransparency = 0.15
    UIScaleObj.Scale = 1.0
    MainWindow.Position = UDim2.new(0.5, -280, 0.5, -180)
end)

-- Mở mặc định Tab Information
PageManager:ShowPage(Config.StartPage)

-- ==========================================
-- 9. EVENT CONTROLS & MINIMIZE / CLOSE
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

-- Expose UI Framework global variable để dễ dàng gọi thêm về sau
_G.MyGUIFramework = {
    PageManager = PageManager,
    UI = UI,
    ScreenGui = ScreenGui,
    MainWindow = MainWindow
}

print("[GUI Framework Loaded Successfully!]")
