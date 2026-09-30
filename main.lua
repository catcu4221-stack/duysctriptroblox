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
local HttpService = game:GetService("HttpService")

-- Clean up the previous framework before rebuilding the current one.
-- This also prevents old Player runtime state from surviving a re-execution.
pcall(function()
    if type(_G.MyGUIFramework) == "table" and type(_G.MyGUIFramework.Cleanup) == "function" then
        _G.MyGUIFramework.Cleanup()
    end
end)

-- Clean up previous render bindings if the script is re-executed.
pcall(function()
    RunService:UnbindFromRenderStep("HoodRivalsUnifiedRender")
    RunService:UnbindFromRenderStep("HoodRivalsAimRender")
    RunService:UnbindFromRenderStep("HoodRivalsESPRender")
end)

local LocalPlayer = Players.LocalPlayer

-- Xác định container chứa GUI (Ưu tiên CoreGui, fallback PlayerGui)
local TargetParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if CoreGui then
        TargetParent = CoreGui
    end
end)

-- Dọn dẹp GUI cũ nếu đã tồn tại để tránh lặp GUI (Cleanup)
local GUI_NAME = "HoodRivals_GUI_Framework"
pcall(function()
    local old = TargetParent:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

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
    DarkBg = Color3.fromRGB(11, 16, 28),
    SidebarBg = Color3.fromRGB(14, 20, 34),
    CardBg = Color3.fromRGB(22, 30, 47),
    AccentColor = Color3.fromRGB(75, 190, 255),
    TextColor = Color3.fromRGB(237, 244, 255),
    SubTextColor = Color3.fromRGB(143, 163, 190),
    BorderColor = Color3.fromRGB(44, 62, 87),

    -- Interface preferences are separate from gameplay configuration.
    Interface = {
        Language = "EN",
        ReducedMotion = false,
        ClickEffects = true,
        SoundEffects = true,
        SoundVolume = 0.45,
        RememberLayout = true,
        CompactSidebar = false,
        Favorites = {},
        CollapsedSections = {},
        Window = {Width = 720, Height = 520},
        LastPage = "ESP"
    },

    StartPage = "ESP",
    AimPriority = "Crosshair",
    Classification = {Mode = "Auto", Attribute = "TeamId"},
    WeaponTuning = {InfiniteAmmo = false, SkipReload = false, RecoilEnabled = false,
        RecoilScale = 0, SpreadEnabled = false, SpreadScale = 0},
    Proximity = {Enabled = false, Radius = 35, IncludeNPC = false},

    -- OTHER / SETTINGS
    ThirdPersonLock = false,
    XRayEnabled = false,
    XRayTransparency = 0.5,
    HoldToSpamEnabled = false,
    HoldToSpamKey = Enum.KeyCode.E,
    AntiAFKEnabled = false,
    VirtualPetEnabled = true,
    SnowfallEnabled = true,

    -- FUNCTION 1 (camera helpers + developer-owned game combat bridge)
    DroneStrikeKey = Enum.KeyCode.V,
    MagicSilentEnabled = false,

    -- ESP Core Configuration
    Enabled = false,
    ShowEnemies = false,
    ShowTeammates = false,
    ShowName = false,
    ShowTracer = false,
    ShowSkeleton = false,
    ShowBox = false,
    ShowNPC = false,
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
    AimNPC = false,
    TargetAssistEnabled = false,
    AimSilentEnabled = false,
    HeadHitboxEnabled = false,
    HeadHitboxSize = 0,

    -- =========================================================
    -- TELEKILL CONFIGURATION
    -- =========================================================
    TelekillEnabled = false,
    -- Legacy field retained only for old profile compatibility.
    TelekillTarget = "Enemy",
    TelekillTargets = {
        Enemy = true,
        Team = false,
        NPC = false
    },
    TelekillDistanceMode = "Nearest",
    TelekillDistance = 3,
    TelekillSwitchKey = Enum.KeyCode.T,

    -- =========================================================
    -- PLAYER CONFIGURATION
    -- =========================================================
    Player = {
        CFrameSpeedEnabled = false,
        CFrameSpeed = 50,

        AirFlyEnabled = false,
        JumpPower = 50,
        JumpPowerOverrideEnabled = false,

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

local SetMenuState

local UIRefs = {
    Toggles = {},
    Sliders = {},
    Textboxes = {},
    Experience = {
        Controls = {},
        ByFrame = {},
        Sections = {},
        SectionByFrame = {},
        Pages = {},
        Query = "",
        FavoritesOnly = false,
        History = {},
        Errors = {},
        TweenSlots = setmetatable({}, {__mode = "k"}),
        DragResetters = {},
        OverlayOpen = false,
        Ready = false,
        RenderRunning = false,
        Destroyed = false,
        StatusAccumulator = 0,
        HighlightWasEnabled = false,
        ClosedSnapshot = nil,
        ProfileAction = nil
    }
}

-- NPC integration namespace.
-- The existing AIM/ESP engines are extended through this single state table;
-- no second AIM, ESP, FOV, or render engine is created.
local NPCSystem = {
    ValidNPCs = {},
    NPCPredictionTime = 0.02,
    Initialized = false,

    -- One shared classification-color source for the existing ESP renderer.
    ESPColors = {
        Enemy = Color3.fromRGB(255, 0, 0),
        Teammate = Color3.fromRGB(0, 255, 0),
        NPC = Color3.fromRGB(0, 170, 255)
    }
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
do
    local ok = pcall(function() ScreenGui.Parent = TargetParent end)
    if not ok then
        TargetParent = LocalPlayer:WaitForChild("PlayerGui")
        local old = TargetParent:FindFirstChild(GUI_NAME)
        if old then old:Destroy() end
        ScreenGui.Parent = TargetParent
    end
end

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

    if not Config.UseFOV
        or (not Config.AimEnabled and not Config.AimSilentEnabled)
    then
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
    local dragging, activeInput, endedConnection = false, nil, nil
    local dragStart, startPos
    local wasDragged = false
    local owned = {}

    local function stop()
        dragging = false
        activeInput = nil
        if endedConnection then endedConnection:Disconnect(); endedConnection = nil end
        if UIRefs.Experience.ClampFrame then UIRefs.Experience.ClampFrame(guiObject) end
    end

    local function own(connection)
        table.insert(owned, connection)
        if not cleanupOnDestroy then AddConnection(connection) end
        return connection
    end

    own(dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if UIRefs.Experience.OverlayOpen then return end
        if dragging then return end
        activeInput, dragging = input, true
        dragStart, startPos, wasDragged = input.Position, guiObject.Position, false
        endedConnection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then stop() end
        end)
    end))

    own(UserInputService.InputChanged:Connect(function(input)
        if not dragging or not guiObject.Parent then return end
        if input ~= activeInput and not (
            activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        ) then return end
        local delta = input.Position - dragStart
        if delta.Magnitude > 5 then wasDragged = true end
        local scale = math.max(UIScaleObj.Scale, 0.01)
        local parent = guiObject.Parent
        while parent and parent ~= ScreenGui do
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("UIScale") then scale = scale * math.max(child.Scale, 0.01) end
            end
            parent = parent.Parent
        end
        guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X / scale,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y / scale)
        if UIRefs.Experience.ClampFrame then UIRefs.Experience.ClampFrame(guiObject) end
    end))

    own(UserInputService.InputEnded:Connect(function(input)
        if input == activeInput then stop() end
    end))

    if cleanupOnDestroy then
        local cleanup
        cleanup = guiObject.AncestryChanged:Connect(function(_, parent)
            if parent ~= nil then return end
            stop()
            for _, connection in ipairs(owned) do connection:Disconnect() end
            cleanup:Disconnect()
        end)
    else
        table.insert(UIRefs.Experience.DragResetters, stop)
    end
    return function() return wasDragged end
end

local function AutoCanvasSize(scrollingFrame, _uiListLayout)
    scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollingFrame.CanvasSize = UDim2.new()
end


-- ==========================================
-- 5. MAIN WINDOW BUILD
-- ==========================================
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.fromOffset(720, 520)
MainWindow.Position = UDim2.new(0.5, -360, 0.5, -260)
MainWindow.BackgroundColor3 = Config.DarkBg
MainWindow.BackgroundTransparency = Config.BackgroundTransparency
MainWindow.BorderSizePixel = 0
MainWindow.ClipsDescendants = true
MainWindow.ZIndex = 60
MainWindow.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainWindow

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Thickness = 2
MainStroke.Transparency = 0.04
MainStroke.Parent = MainWindow

-- Animated neon-rainbow border for the existing MainWindow.
-- Reuses the shared UI-effects render update; no new render connection.
UIRefs.MainRainbowGradient = Instance.new("UIGradient")
UIRefs.MainRainbowGradient.Name = "MainWindowRainbowNeon"
UIRefs.MainRainbowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 45, 45)),
    ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 145, 35)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 235, 45)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(45, 255, 90)),
    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(40, 180, 255)),
    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(135, 70, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 60, 210))
})
UIRefs.MainRainbowGradient.Parent = MainStroke

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 64)
Header.BackgroundTransparency = 1
Header.Parent = MainWindow

-- Two-row header: the first row owns title/window controls and is the
-- draggable area.  The second row is a horizontal top-tab rail.
local TopRow = Instance.new("Frame")
TopRow.Name = "TopRow"
TopRow.Size = UDim2.new(1, 0, 0, 33)
TopRow.Position = UDim2.new(0, 0, 0, 0)
TopRow.BackgroundTransparency = 1
TopRow.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(0, 230, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.Text = Config.Title
TitleLabel.TextColor3 = Config.TextColor
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = TopRow

local ControlButtons = Instance.new("Frame")
ControlButtons.Size = UDim2.new(0, 90, 0, 31)
ControlButtons.Position = UDim2.new(1, -95, 0, 1)
ControlButtons.BackgroundTransparency = 1
ControlButtons.Parent = TopRow

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "Minimize"
MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
MinimizeBtn.Position = UDim2.new(0, 0, 0, 3)
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

UIRefs.NotificationButton = Instance.new("TextButton")
UIRefs.NotificationButton.Name = "Notification"
UIRefs.NotificationButton.Size = UDim2.new(0, 25, 0, 25)
UIRefs.NotificationButton.Position = UDim2.new(0, 30, 0, 3)
UIRefs.NotificationButton.Text = "🔔"
UIRefs.NotificationButton.TextColor3 = Config.SubTextColor
UIRefs.NotificationButton.TextSize = 13
UIRefs.NotificationButton.Font = Enum.Font.GothamBold
UIRefs.NotificationButton.BackgroundColor3 = Config.SidebarBg
UIRefs.NotificationButton.AutoButtonColor = false
UIRefs.NotificationButton.Parent = ControlButtons

local NotificationCorner = Instance.new("UICorner")
NotificationCorner.CornerRadius = UDim.new(0, 4)
NotificationCorner.Parent = UIRefs.NotificationButton

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "Close"
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(0, 60, 0, 3)
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

local TopTabBar = Instance.new("ScrollingFrame")
TopTabBar.Name = "TopTabBar"
TopTabBar.Size = UDim2.new(1, -16, 0, 26)
TopTabBar.Position = UDim2.new(0, 8, 0, 35)
TopTabBar.BackgroundTransparency = 1
TopTabBar.BorderSizePixel = 0
TopTabBar.ScrollBarThickness = 2
TopTabBar.ScrollBarImageColor3 = Config.SubTextColor
TopTabBar.ScrollingDirection = Enum.ScrollingDirection.X
TopTabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TopTabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TopTabBar.Parent = Header

local TopTabLayout = Instance.new("UIListLayout")
TopTabLayout.FillDirection = Enum.FillDirection.Horizontal
TopTabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TopTabLayout.Padding = UDim.new(0, 7)
TopTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TopTabLayout.Parent = TopTabBar

-- Drag only from the top row so horizontal tabs never fight the drag system.
MakeDraggable(MainWindow, TopRow)

-- Divider Line
local HeaderDivider = Instance.new("Frame")
HeaderDivider.Size = UDim2.new(1, 0, 0, 1)
HeaderDivider.Position = UDim2.new(0, 0, 0, 63)
HeaderDivider.BackgroundColor3 = Config.BorderColor
HeaderDivider.BorderSizePixel = 0
HeaderDivider.Parent = MainWindow

-- Sidebar Container
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 140, 1, -64)
Sidebar.Position = UDim2.new(0, 0, 0, 64)
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
local TabContainer = Instance.new("ScrollingFrame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, -16, 1, -58)
TabContainer.Position = UDim2.new(0, 8, 0, 10)
TabContainer.BackgroundTransparency = 1
TabContainer.BorderSizePixel = 0
TabContainer.ScrollBarThickness = 2
TabContainer.ScrollBarImageColor3 = Config.BorderColor
TabContainer.ScrollingDirection = Enum.ScrollingDirection.Y
TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabContainer.CanvasSize = UDim2.new()
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
AuthorLabel.Font = Enum.Font.GothamMedium
AuthorLabel.TextWrapped = true
AuthorLabel.BackgroundTransparency = 1
AuthorLabel.Parent = Sidebar

-- Content Area
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -141, 1, -64)
ContentArea.Position = UDim2.new(0, 141, 0, 64)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainWindow

-- Floating Open Button
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingOpenButton"
FloatingBtn.Size = UDim2.fromOffset(128, 42)
FloatingBtn.Position = UDim2.new(1, -148, 1, -62)
FloatingBtn.BackgroundColor3 = Config.DarkBg
FloatingBtn.BackgroundTransparency = 0.18
FloatingBtn.Text = "⚡ FPS: -- ⚡"
FloatingBtn.TextColor3 = Config.TextColor
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 13
FloatingBtn.AutoButtonColor = false
FloatingBtn.Visible = false
FloatingBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 9)
FloatCorner.Parent = FloatingBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Color3.fromRGB(255, 255, 255)
FloatStroke.Thickness = 2
FloatStroke.Transparency = 0.05
FloatStroke.Parent = FloatingBtn

UIRefs.FloatingRainbowGradient = Instance.new("UIGradient")
UIRefs.FloatingRainbowGradient.Name = "SevenColorBorder"
UIRefs.FloatingRainbowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 45, 45)),
    ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 145, 35)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 235, 45)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(45, 255, 90)),
    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(40, 180, 255)),
    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(135, 70, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 60, 210))
})
UIRefs.FloatingRainbowGradient.Parent = FloatStroke

local isFloatDragged = MakeDraggable(FloatingBtn, FloatingBtn)

-- =========================================================
-- OTHER TAB SYSTEM
-- Only the seven requested features live here.
-- =========================================================
local OtherSystem = {
    XRayCache = {},
    XRayActive = false,
    ActiveFireTouches = {},
    ServerActionBusy = false,
    MenuMouseState = nil,
    KeybindListening = false,
    KeybindBox = nil,
    KeybindCaptureMode = nil,
    ConsumeNextToggleInput = false,
    SettingsLoadChordLatched = false,
    TelekillToggleChordLatched = false,
    Generation = 0
}

local ExtraFeatures = {
    HeadHitboxCache = {},
    HeadHitboxAccumulator = 0,

    TargetAssist = {
        CurrentTarget = nil
    },

    AimSilent = {
        CurrentTarget = nil,
        CurrentPart = nil,
        TargetOptions = {
            AllowWhenAimDisabled = true,
            RequireFOV = true,
            RequireVisibility = true
        }
    },

    -- Developer-owned game combat bridge.
    -- The companion ServerScript validates and applies damage server-side.
    DeveloperCombat = {
        FolderName = "HoodRivalsDevCombat",
        RemoteName = "RequestShot",
        MissingWarned = false
    },

    AntiAFK = {
        Connection = nil,
        VirtualUser = nil
    },

    GamePass = {
        Active = false,
        TargetFunction = nil,
        OriginalFunction = nil
    },

    HoldSpamKeyHeld = false,
    HoldSpamRightHeld = false,
    HoldSpamListening = false,
    HoldSpamKeyBox = nil,
    HoldSpamAccumulator = 0,
    HoldSpamInterval = 0.12,
    HoldSpamInput = nil,

    Function1 = {
        DroneStrike = {
            Active = false,
            Original = nil,
            CFrame = nil,
            Pitch = 0,
            Yaw = 0,
            Speed = 60,
            Target = nil,
            TargetAccumulator = 0
        },

        MagicSilent = {
            Target = nil,
            Accumulator = 0
        },

        Marker = nil,
        MarkerText = nil
    },

    UIEffects = {
        VirtualPet = {
            Enabled = false,
            Instance = nil,
            Image = nil,
            Fallback = nil,
            State = "Idle",
            Generation = 0,
            Tween = nil,
            LastInput = os.clock(),
            VirtualPetImage = "rbxassetid://0",
            Reacting = false,
            ReactionToken = 0,
            ChatBubble = nil,
            MemeSound = nil,
            ReactionDuration = 1.5,
            Memes = {
                {
                    Text = "Bruh...",
                    SoundId = "rbxassetid://0"
                },
                {
                    Text = "Sheesh!",
                    SoundId = "rbxassetid://0"
                },
                {
                    Text = "Nà Ní???",
                    SoundId = "rbxassetid://0"
                }
            }
        },

        Snowfall = {
            Enabled = false,
            Container = nil,
            Generation = 0,
            Particles = {},
            MaxActive = 30
        },

        Bubble = {
            MainScale = nil,
            BubbleScale = nil,
            HoverTween = nil,
            ScaleTween = nil,
            MainTween = nil,
            MainFadeTween = nil,
            Token = 0,
            FPSAccumulator = 0,
            FPSFrames = 0,
            LastFPS = 0,
            LightningAccumulator = 0,
            NextLightning = 0.65,
            ChatToken = 0,
            ChatCloud = nil,
            Messages = {
                "Chúc thằng cu em có trải nghiệm tốt nhé!! YOU ARE COOKED 😂",
                "FPS căng thế này thì chiến thôi bro 😎",
                "Menu nghỉ tí, tay vẫn phải nhanh nha ⚡",
                "Chúc bro combat mượt như bơ 🧈",
                "Đừng quên uống nước rồi chiến tiếp nhé 😂",
                "FPS ổn, tinh thần cũng phải ổn nha 🔥"
            }
        },

        DynamicColor = {
            Tween = nil,
            CurrentColor = nil
        },

        ToggleFX = {
            Overlay = nil,
            Sound = nil,
            SoundId = "rbxassetid://0",
            ActiveParticles = {},
            MaxParticles = 28,
            ShakeBusy = false
        },

        Sliders = {
            Active = {}
        },

        AnimationBusy = false,
        InputTrackingReady = false,
        Initialized = false
    },

    NotificationText = "NHẬP THÔNG BÁO Ở ĐÂY",
    NotificationView = nil,
    NotificationPreviousPage = nil
}


-- =========================================================
-- ADVANCED UI EFFECTS
-- Dynamic tab color / explosive toggle / heavy slider / reactive pet.
-- These extend the existing UIEffects namespace and reuse the shared render
-- pipeline. No second PageManager, toggle engine, slider engine or ScreenGui.
-- =========================================================

-- Shared configuration and classification helpers; no new render loops.
ExtraFeatures.V8 = {
    Version = 8, OwnerUserId = LocalPlayer.UserId, CustomCharacters = {},
    Registry = setmetatable({}, {__mode = "k"}), TranslationGuard = false,
    InterfaceRevision = 0, ProfilesRevision = 0, SettingsRevision = 0,
    RequestSerial = 0, ServerReady = false, ServerStatus = "Not connected",
    WeaponStatus = "Controller not connected", WeaponAdapters = {},
    ScanAccumulator = 0, ProfileAccumulator = 0, JoinedAt = os.clock(),
    FavoriteChordLatched = false, Destroyed = false, Restoring = false
}

function ExtraFeatures.V8.Normalize(text)
    text = string.lower(tostring(text or ""))
    for _, group in ipairs({{"a", "àáạảãâầấậẩẫăằắặẳẵÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ"},
        {"e", "èéẹẻẽêềếệểễÈÉẸẺẼÊỀẾỆỂỄ"}, {"i", "ìíịỉĩÌÍỊỈĨ"},
        {"o", "òóọỏõôồốộổỗơờớợởỡÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ"},
        {"u", "ùúụủũưừứựửữÙÚỤỦŨƯỪỨỰỬỮ"}, {"y", "ỳýỵỷỹỲÝỴỶỸ"}, {"d", "đĐ"}}) do
        for character in string.gmatch(group[2], "[\1-\127\194-\244][\128-\191]*") do
            text = string.gsub(text, character, group[1])
        end
    end
    return text
end

function ExtraFeatures.V8.TeamValue(value)
    if typeof(value) == "Instance" and value:IsA("Team") then value = value.Name end
    if type(value) ~= "string" and type(value) ~= "number" then return nil end
    local token = string.lower(tostring(value):match("^%s*(.-)%s*$"))
    if token == "" or token == "0" or token == "none" or token == "neutral"
        or token == "unassigned" or token == "spectator" or token == "spectators"
        or token == "lobby" or token == "default" or token == "players" or token == "player" then return nil end
    return token
end

function ExtraFeatures.V8.ResolvePlayerModel(model)
    if not model or not model:IsA("Model") then return nil end
    local owner = Players:GetPlayerFromCharacter(model)
    if owner then return owner end
    local kind = string.lower(tostring(model:GetAttribute("EntityType") or model:GetAttribute("CharacterType") or ""))
    if kind == "npc" or kind == "dummy" or model:GetAttribute("IsNPC") == true then return nil end
    local id = model:GetAttribute("PlayerUserId") or model:GetAttribute("PlayerId")
    if id == nil and (kind == "player" or model:GetAttribute("IsPlayer") == true) then id = model:GetAttribute("UserId") end
    id = tonumber(id)
    if not id or id ~= id then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == id then
            ExtraFeatures.V8.CustomCharacters[player] = model
            return player
        end
    end
    return nil
end

function ExtraFeatures.V8.Character(player)
    local native = player.Character
    if native and native.Parent and native:IsDescendantOf(Workspace) then return native end
    local custom = ExtraFeatures.V8.CustomCharacters[player]
    if custom and custom.Parent and custom:IsDescendantOf(Workspace) then return custom end
    ExtraFeatures.V8.CustomCharacters[player] = nil
    return native
end

function ExtraFeatures.V8.TeamToken(player)
    if not NPCSystem.IsPlayer(player) then return nil, nil end
    local mode = Config.Classification.Mode
    if mode == "FFA" then return nil, nil end
    if type(ExtraFeatures.V8.TeamResolver) == "function" then
        local ok, token = pcall(ExtraFeatures.V8.TeamResolver, player, ExtraFeatures.V8.Character(player))
        token = ok and ExtraFeatures.V8.TeamValue(token) or nil
        if token then return "ADAPTER", token end
    end
    if mode ~= "RobloxTeams" then
        local names = {Config.Classification.Attribute, "CombatTeamId", "CombatTeam", "TeamId", "TeamID",
            "FactionId", "Faction", "TeamName", "Team", "Side", "SquadId"}
        local character = ExtraFeatures.V8.Character(player)
        for _, key in ipairs(names) do
            if type(key) == "string" and key ~= "" then
                local value = player:GetAttribute(key)
                if value == nil and character then value = character:GetAttribute(key) end
                if value == nil then
                    for _, parent in pairs({Player = player, Character = character}) do
                        local folder = parent:FindFirstChild("leaderstats") or parent:FindFirstChild("Stats")
                        local object = parent:FindFirstChild(key) or (folder and folder:FindFirstChild(key))
                        if object and (object:IsA("StringValue") or object:IsA("IntValue") or object:IsA("NumberValue")
                            or object:IsA("ObjectValue")) then value = object.Value; break end
                    end
                end
                local token = ExtraFeatures.V8.TeamValue(value)
                if token then return "CUSTOM:" .. string.lower(key), token end
            end
        end
    end
    if mode ~= "Custom" and player.Neutral ~= true then
        local team = player.Team
        local token = team and ExtraFeatures.V8.TeamValue(team.Name)
        if token then return "ROBLOX", token end
        local ok, teams = pcall(function() return game:GetService("Teams"):GetTeams() end)
        if ok and player.TeamColor ~= nil then
            for _, candidate in ipairs(teams) do
                if candidate.TeamColor == player.TeamColor then
                    token = ExtraFeatures.V8.TeamValue(candidate.Name)
                    if token then return "ROBLOX", token end
                end
            end
        end
    end
    return nil, nil
end

function ExtraFeatures.V8.AimMetric(target, screenDistance, part)
    local mode = Config.AimPriority
    if mode == "Nearest" then
        local character = ExtraFeatures.V8.Character(LocalPlayer)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return root and (part.Position - root.Position).Magnitude or math.huge
    elseif mode == "LowestHealth" then
        local character = NPCSystem.GetCharacter(target)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.Health or math.huge
    elseif mode == "PlayersFirst" then return NPCSystem.IsPlayer(target) and 0 or 1
    elseif mode == "NPCFirst" then return NPCSystem.IsNPCModel(target) and 0 or 1 end
    return screenDistance
end

function ExtraFeatures.V8.BetterAim(target, screenDistance, part, bestTarget, bestPart, bestScreenDistance)
    if Config.AimPriority == "Crosshair" then return screenDistance < bestScreenDistance end
    local value = ExtraFeatures.V8.AimMetric(target, screenDistance, part)
    local best = bestTarget and bestPart and ExtraFeatures.V8.AimMetric(bestTarget, bestScreenDistance, bestPart) or math.huge
    return value < best or (value == best and screenDistance < bestScreenDistance)
end


function ExtraFeatures.EnsureUIEffectOverlay()
    local effects = ExtraFeatures.UIEffects
    local state = effects.ToggleFX

    if state.Overlay and state.Overlay.Parent then
        return state.Overlay
    end

    local overlay = Instance.new("Frame")
    overlay.Name = "UIEffectOverlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.Position = UDim2.fromOffset(0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Active = false
    overlay.Selectable = false
    overlay.ZIndex = 90
    overlay.Parent = ScreenGui

    state.Overlay = overlay
    return overlay
end

function ExtraFeatures.EnsureToggleFXSound()
    local state = ExtraFeatures.UIEffects.ToggleFX

    if state.Sound and state.Sound.Parent then
        return state.Sound
    end

    local sound = Instance.new("Sound")
    sound.Name = "ToggleExplosionSound"
    sound.Volume = 0.45
    sound.SoundId = tostring(state.SoundId or "rbxassetid://0")
    sound.Parent = ScreenGui

    state.Sound = sound
    return sound
end

function ExtraFeatures.PlayToggleFXSound()
    if not Config.Interface.SoundEffects then return end
    local state = ExtraFeatures.UIEffects.ToggleFX
    local soundId = tostring(state.SoundId or "")

    if soundId == ""
        or soundId == "0"
        or soundId == "rbxassetid://0"
    then
        return
    end

    pcall(function()
        local sound = ExtraFeatures.EnsureToggleFXSound()
        sound:Stop()
        sound.Volume = Config.Interface.SoundVolume
        sound.SoundId = soundId
        sound.TimePosition = 0
        sound:Play()
    end)
end

function ExtraFeatures.CreateToggleExplosion(guiObject)
    if not guiObject
        or not guiObject.Parent
        or not guiObject.AbsolutePosition
    then
        return
    end

    local state = ExtraFeatures.UIEffects.ToggleFX
    local overlay = ExtraFeatures.EnsureUIEffectOverlay()

    local activeCount = 0
    local stale = {}

    for particle in pairs(state.ActiveParticles) do
        if particle and particle.Parent then
            activeCount = activeCount + 1
        else
            table.insert(stale, particle)
        end
    end

    for _, particle in ipairs(stale) do
        state.ActiveParticles[particle] = nil
    end

    local remaining = math.max(
        0,
        (tonumber(state.MaxParticles) or 28) - activeCount
    )
    local amount = math.min(math.random(5, 8), remaining)

    if amount <= 0 then
        return
    end

    local scale = math.max(UIScaleObj.Scale, 0.01)
    local centerX =
        (
            guiObject.AbsolutePosition.X
            + guiObject.AbsoluteSize.X * 0.5
            - overlay.AbsolutePosition.X
        ) / scale
    local centerY =
        (
            guiObject.AbsolutePosition.Y
            + guiObject.AbsoluteSize.Y * 0.5
            - overlay.AbsolutePosition.Y
        ) / scale

    for index = 1, amount do
        local particle = Instance.new("Frame")
        local size = math.random(2, 4)

        particle.Name = "ToggleSpark"
        particle.AnchorPoint = Vector2.new(0.5, 0.5)
        particle.Size = UDim2.fromOffset(size, size)
        particle.Position = UDim2.fromOffset(centerX, centerY)
        particle.BorderSizePixel = 0
        particle.BackgroundTransparency = 0
        particle.Active = false
        particle.Selectable = false
        particle.ZIndex = 91

        if index % 3 == 1 then
            particle.BackgroundColor3 = Color3.fromRGB(255, 214, 74)
        elseif index % 3 == 2 then
            particle.BackgroundColor3 = Color3.fromRGB(255, 145, 42)
        else
            particle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = particle

        particle.Parent = overlay
        state.ActiveParticles[particle] = true

        local angle = math.rad(math.random(0, 359))
        local radius = math.random(16, 32) / scale
        local targetX = centerX + math.cos(angle) * radius
        local targetY = centerY + math.sin(angle) * radius
        local duration = math.random(25, 35) / 100

        local tween = TweenService:Create(
            particle,
            TweenInfo.new(
                duration,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Position = UDim2.fromOffset(targetX, targetY),
                BackgroundTransparency = 1
            }
        )

        tween:Play()

        task.delay(duration + 0.05, function()
            state.ActiveParticles[particle] = nil

            if particle and particle.Parent then
                particle:Destroy()
            end
        end)
    end
end

function ExtraFeatures.ShakeToggle(guiObject)
    if not guiObject or not guiObject.Parent then
        return
    end

    local state = ExtraFeatures.UIEffects.ToggleFX

    if state.ShakeBusy then
        return
    end

    state.ShakeBusy = true

    task.spawn(function()
        local original = guiObject.Position

        for index = 1, 5 do
            if not guiObject or not guiObject.Parent then
                break
            end

            local x = math.random(-3, 3)
            local y = math.random(-2, 2)

            guiObject.Position = UDim2.new(
                original.X.Scale,
                original.X.Offset + x,
                original.Y.Scale,
                original.Y.Offset + y
            )

            task.wait(0.018)
        end

        if guiObject and guiObject.Parent then
            guiObject.Position = original
        end

        state.ShakeBusy = false
    end)
end

function ExtraFeatures.ReactVirtualPet()
    local state = ExtraFeatures.UIEffects.VirtualPet

    if not Config.VirtualPetEnabled
        or not state.Enabled
        or not state.Instance
        or not state.Instance.Parent
    then
        return
    end

    state.ReactionToken = (state.ReactionToken or 0) + 1
    local token = state.ReactionToken

    state.Reacting = true
    state.State = "React"
    state.LastInput = os.clock()

    if state.Tween then
        pcall(function()
            state.Tween:Cancel()
        end)
    end

    state.Tween = nil

    if state.ChatBubble and state.ChatBubble.Parent then
        state.ChatBubble:Destroy()
    end

    state.ChatBubble = nil

    if state.MemeSound and state.MemeSound.Parent then
        pcall(function()
            state.MemeSound:Stop()
        end)
    end

    if state.Fallback and state.Fallback.Parent then
        state.Fallback.Text = "🙀"
    end

    pcall(function()
        state.Instance.Rotation = 0
    end)

    local memes =
        type(state.Memes) == "table"
        and state.Memes
        or {}

    local selected = nil

    if #memes > 0 then
        selected = memes[math.random(1, #memes)]
    end

    local bubble = Instance.new("TextLabel")
    bubble.Name = "PetChatBubble"
    bubble.AnchorPoint = Vector2.new(0.5, 1)
    bubble.Size = UDim2.fromOffset(92, 26)
    bubble.Position = UDim2.new(0.5, 0, 0, -4)
    bubble.BackgroundColor3 = Config.CardBg
    bubble.BackgroundTransparency = 0.08
    bubble.BorderSizePixel = 0
    bubble.Text =
        selected and tostring(selected.Text or "!")
        or "!"
    bubble.TextColor3 = Config.TextColor
    bubble.Font = Enum.Font.GothamBold
    bubble.TextSize = 11
    bubble.TextWrapped = true
    bubble.Active = false
    bubble.Selectable = false
    bubble.ZIndex = 45
    bubble.Parent = state.Instance

    local bubbleCorner = Instance.new("UICorner")
    bubbleCorner.CornerRadius = UDim.new(0, 7)
    bubbleCorner.Parent = bubble

    local bubbleStroke = Instance.new("UIStroke")
    bubbleStroke.Color = Config.BorderColor
    bubbleStroke.Thickness = 1
    bubbleStroke.Transparency = 0.2
    bubbleStroke.Parent = bubble

    state.ChatBubble = bubble

    local soundId =
        selected
        and tostring(selected.SoundId or "")
        or ""

    if soundId ~= ""
        and soundId ~= "0"
        and soundId ~= "rbxassetid://0"
    then
        pcall(function()
            if not state.MemeSound
                or not state.MemeSound.Parent
            then
                state.MemeSound = Instance.new("Sound")
                state.MemeSound.Name = "VirtualPetMemeSound"
                state.MemeSound.Volume = 0.4
                state.MemeSound.Parent = ScreenGui
            end

            state.MemeSound:Stop()
            state.MemeSound.SoundId = soundId
            state.MemeSound.TimePosition = 0
            state.MemeSound:Play()
        end)
    end

    local duration =
        tonumber(state.ReactionDuration)
        or 1.5

    task.delay(duration, function()
        if token ~= state.ReactionToken then
            return
        end

        if state.ChatBubble and state.ChatBubble.Parent then
            local oldBubble = state.ChatBubble
            state.ChatBubble = nil

            pcall(function()
                local fade = TweenService:Create(
                    oldBubble,
                    TweenInfo.new(
                        0.15,
                        Enum.EasingStyle.Quad,
                        Enum.EasingDirection.Out
                    ),
                    {
                        BackgroundTransparency = 1,
                        TextTransparency = 1
                    }
                )

                fade:Play()
            end)

            task.delay(0.16, function()
                if oldBubble and oldBubble.Parent then
                    oldBubble:Destroy()
                end
            end)
        end

        if state.MemeSound and state.MemeSound.Parent then
            pcall(function()
                state.MemeSound:Stop()
            end)
        end

        if state.Fallback and state.Fallback.Parent then
            state.Fallback.Text = "🐱"
        end

        state.Reacting = false
        state.State = "Idle"
        state.LastInput = os.clock()
    end)
end

function ExtraFeatures.OnUserToggleClicked(guiObject)
    if not Config.Interface.ClickEffects then return end
    if Config.Interface.ReducedMotion then
        ExtraFeatures.PlayToggleFXSound()
        return
    end
    pcall(function()
        ExtraFeatures.PlayToggleFXSound()
    end)

    pcall(function()
        ExtraFeatures.CreateToggleExplosion(guiObject)
    end)

    pcall(function()
        ExtraFeatures.ShakeToggle(guiObject)
    end)

    pcall(function()
        ExtraFeatures.ReactVirtualPet()
    end)
end

function ExtraFeatures.OnTabChangedLegacy(previousPage, pageName)
    if previousPage == pageName then
        return
    end

    local state = ExtraFeatures.UIEffects.DynamicColor

    if state.Tween then
        pcall(function()
            state.Tween:Cancel()
        end)
    end

    local targetColor = Color3.fromHSV(
        math.random(),
        0.6,
        0.3
    )

    state.CurrentColor = targetColor
    state.Tween = TweenService:Create(
        MainWindow,
        TweenInfo.new(
            0.5,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.Out
        ),
        {
            BackgroundColor3 = targetColor
        }
    )

    state.Tween:Play()
end

function ExtraFeatures.UpdateHeavySliders(renderDt)
    local sliders = ExtraFeatures.UIEffects.Sliders.Active

    if type(sliders) ~= "table" then
        return
    end

    local dt = math.clamp(
        tonumber(renderDt) or (1 / 60),
        0,
        0.1
    )
    local factor =
        1 - math.pow(1 - 0.15, dt * 60)

    local stale = {}

    for frame, state in pairs(sliders) do
        if not frame
            or not frame.Parent
            or type(state) ~= "table"
            or not state.Fill
            or not state.Fill.Parent
        then
            table.insert(stale, frame)
        elseif state.ActiveVisual then
            local target =
                math.clamp(
                    tonumber(state.TargetPercentage) or 0,
                    0,
                    1
                )
            local visual =
                math.clamp(
                    tonumber(state.VisualPercentage) or target,
                    0,
                    1
                )

            visual =
                visual + (target - visual) * factor

            if math.abs(target - visual) <= 0.001 then
                visual = target
                state.ActiveVisual = false
            end

            state.VisualPercentage = visual
            state.Fill.Size =
                UDim2.new(visual, 0, 1, 0)

            if state.Knob
                and state.Knob.Parent
            then
                state.Knob.Position =
                    UDim2.new(visual, 0, 0.5, 0)
            end
        end
    end

    for _, frame in ipairs(stale) do
        sliders[frame] = nil
    end
end

function ExtraFeatures.ClearTargetAssist()
    ExtraFeatures.TargetAssist.CurrentTarget = nil

    if UIRefs.TargetAssistLabel
        and UIRefs.TargetAssistLabel.Parent
    then
        UIRefs.TargetAssistLabel.Text = "Target: None"
    end
end

function ExtraFeatures.ClearAimSilent()
    ExtraFeatures.AimSilent.CurrentTarget = nil
    ExtraFeatures.AimSilent.CurrentPart = nil
    FOVCircleStroke.Thickness = 2

    if UIRefs.AimSilentLabel
        and UIRefs.AimSilentLabel.Parent
    then
        UIRefs.AimSilentLabel.Text = "Target: None"
    end
end

function ExtraFeatures.StyleKeyButton(button)
    if not button then
        return
    end

    button.TextColor3 = Config.TextColor
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 12
    button.BackgroundColor3 = Config.DarkBg
    button.AutoButtonColor = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.BorderColor
    stroke.Thickness = 1
    stroke.Parent = button
end

function ExtraFeatures.RestoreHeadHitboxPart(part)
    local original = ExtraFeatures.HeadHitboxCache[part]
    if not original then
        return
    end

    ExtraFeatures.HeadHitboxCache[part] = nil

    if original.Visual then
        pcall(function()
            original.Visual:Destroy()
        end)
        original.Visual = nil
    end

    if part and part.Parent then
        pcall(function()
            part.Size = original.Size
            part.Transparency = original.Transparency
            part.CanCollide = original.CanCollide
            part.CanQuery = original.CanQuery
            part.CanTouch = original.CanTouch
        end)
    end
end

function ExtraFeatures.RestoreAllHeadHitboxes()
    local parts = {}

    for part in pairs(ExtraFeatures.HeadHitboxCache) do
        table.insert(parts, part)
    end

    for _, part in ipairs(parts) do
        ExtraFeatures.RestoreHeadHitboxPart(part)
    end

    table.clear(ExtraFeatures.HeadHitboxCache)
    ExtraFeatures.HeadHitboxAccumulator = 0
end

function ExtraFeatures.ApplyHeadHitboxPart(part)
    if not part
        or typeof(part) ~= "Instance"
        or not part:IsA("BasePart")
        or not part.Parent
    then
        return
    end

    if not ExtraFeatures.HeadHitboxCache[part] then
        ExtraFeatures.HeadHitboxCache[part] = {
            Size = part.Size,
            Transparency = part.Transparency,
            CanCollide = part.CanCollide,
            CanQuery = part.CanQuery,
            CanTouch = part.CanTouch,
            Visual = nil
        }
    end

    local original = ExtraFeatures.HeadHitboxCache[part]
    local amount = math.clamp(
        tonumber(Config.HeadHitboxSize) or 0,
        0,
        10
    )

    if not Config.HeadHitboxEnabled or amount <= 0 then
        ExtraFeatures.RestoreHeadHitboxPart(part)
        return
    end

    pcall(function()
        part.Size =
            original.Size
            + Vector3.new(amount, amount, amount)

        -- Visible enough to understand the expanded bounds while still
        -- remaining transparent enough not to obstruct the target.
        part.Transparency = math.max(original.Transparency, 0.65)
        part.CanCollide = false
        part.CanQuery = true
        part.CanTouch = original.CanTouch
    end)

    if not original.Visual or not original.Visual.Parent then
        pcall(function()
            local visual = Instance.new("SelectionBox")
            visual.Name = "__HoodRivals_HeadHitboxVisual"
            visual.Adornee = part
            visual.Color3 = Config.AccentColor
            visual.SurfaceColor3 = Config.AccentColor
            visual.SurfaceTransparency = 0.92
            visual.LineThickness = 0.03
            visual.Parent = part
            original.Visual = visual
        end)
    end
end

function ExtraFeatures.UpdateHeadHitboxes(dt, force)
    if not Config.HeadHitboxEnabled
        or (tonumber(Config.HeadHitboxSize) or 0) <= 0
    then
        if next(ExtraFeatures.HeadHitboxCache) ~= nil then
            ExtraFeatures.RestoreAllHeadHitboxes()
        end
        return
    end

    ExtraFeatures.HeadHitboxAccumulator =
        ExtraFeatures.HeadHitboxAccumulator
        + (tonumber(dt) or 0)

    if not force
        and ExtraFeatures.HeadHitboxAccumulator < 0.25
    then
        return
    end

    ExtraFeatures.HeadHitboxAccumulator = 0

    local seen = {}

    -- Head Hitbox remains restricted to the existing NPC/dummy registry.
    -- Real Player characters are never modified by this feature.
    for model in pairs(NPCSystem.ValidNPCs) do
        if model
            and model.Parent
            and Players:GetPlayerFromCharacter(model) == nil
        then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local head = model:FindFirstChild("Head")

            if humanoid
                and humanoid.Health > 0
                and head
                and head:IsA("BasePart")
            then
                seen[head] = true
                ExtraFeatures.ApplyHeadHitboxPart(head)
            end
        end
    end

    local stale = {}

    for part in pairs(ExtraFeatures.HeadHitboxCache) do
        if not seen[part] or not part or not part.Parent then
            table.insert(stale, part)
        end
    end

    for _, part in ipairs(stale) do
        ExtraFeatures.RestoreHeadHitboxPart(part)
    end
end

function ExtraFeatures.SetHeadHitboxEnabled(enabled)
    Config.HeadHitboxEnabled = enabled == true

    if not Config.HeadHitboxEnabled then
        ExtraFeatures.RestoreAllHeadHitboxes()
        return
    end

    ExtraFeatures.UpdateHeadHitboxes(0, true)
end

function ExtraFeatures.GetDeveloperCombatRemote()
    local state = ExtraFeatures.DeveloperCombat
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local folder = replicatedStorage:FindFirstChild(state.FolderName)
    local remote = folder and folder:FindFirstChild(state.RemoteName)

    if remote and remote:IsA("RemoteEvent") then
        state.MissingWarned = false
        return remote
    end

    if not state.MissingWarned then
        state.MissingWarned = true
        warn(
            "[Hood Rivals] Developer combat bridge not found. "
            .. "Install HoodRivals_DeveloperCombatBridge.server.lua "
            .. "in ServerScriptService for server-authorized damage."
        )
    end

    return nil
end

function ExtraFeatures.GetDeveloperShotTarget()
    if Config.AimSilentEnabled
        and ExtraFeatures.AimSilent.CurrentTarget
        and ExtraFeatures.AimSilent.CurrentPart
        and ExtraFeatures.AimSilent.CurrentPart.Parent
    then
        return
            "AimSilent",
            ExtraFeatures.AimSilent.CurrentTarget
    end

    if Config.MagicSilentEnabled
        and ExtraFeatures.Function1.MagicSilent.Target
    then
        return
            "MagicSilent",
            ExtraFeatures.Function1.MagicSilent.Target
    end

    return nil, nil
end

function ExtraFeatures.RequestDeveloperCombatShot(
    modeOverride,
    targetOverride
)
    local remote = ExtraFeatures.GetDeveloperCombatRemote()
    if not remote then
        return false
    end

    local mode, target

    if type(modeOverride) == "string"
        and modeOverride ~= ""
        and targetOverride ~= nil
    then
        mode = modeOverride
        target = targetOverride
    else
        mode, target = ExtraFeatures.GetDeveloperShotTarget()
    end

    if mode and target then
        remote:FireServer({
            Mode = mode,
            Target = target,
            HeadHitboxSize = math.clamp(
                tonumber(Config.HeadHitboxSize) or 0,
                0,
                10
            )
        })
        return true
    end

    if Config.HeadHitboxEnabled
        and (tonumber(Config.HeadHitboxSize) or 0) > 0
    then
        local camera = Workspace.CurrentCamera
        if not camera then
            return false
        end

        local mousePosition = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(
            mousePosition.X,
            mousePosition.Y
        )

        remote:FireServer({
            Mode = "HeadHitbox",
            RayDirection = ray.Direction,
            HeadHitboxSize = math.clamp(
                tonumber(Config.HeadHitboxSize) or 0,
                0,
                10
            )
        })

        return true
    end

    return false
end

function ExtraFeatures.SetAntiAFK(enabled)
    local state = ExtraFeatures.AntiAFK
    enabled = enabled == true

    if state.Connection then
        pcall(function()
            state.Connection:Disconnect()
        end)
        state.Connection = nil
    end

    Config.AntiAFKEnabled = enabled

    if not enabled then
        return true
    end

    if not state.VirtualUser then
        local ok, service = pcall(function()
            return game:GetService("VirtualUser")
        end)

        if ok then
            state.VirtualUser = service
        end
    end

    if not state.VirtualUser then
        Config.AntiAFKEnabled = false

        if ExtraFeatures.SetStatus then
            ExtraFeatures.SetStatus(
                "Anti-AFK unavailable: VirtualUser is not supported"
            )
        end

        return false
    end

    state.Connection =
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                state.VirtualUser:CaptureController()
                state.VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)

    return true
end

function ExtraFeatures.EnableGamePassSpoofer()
    local state = ExtraFeatures.GamePass

    if state.Active then
        if ExtraFeatures.SetStatus then
            ExtraFeatures.SetStatus(
                "Game Pass Spoofer is already active (client-side only)"
            )
        end
        return true
    end

    if type(hookfunction) ~= "function" then
        if ExtraFeatures.SetStatus then
            ExtraFeatures.SetStatus(
                "Game Pass Spoofer unavailable: hookfunction is not supported"
            )
        end
        return false
    end

    local marketplace =
        game:GetService("MarketplaceService")

    local original

    local ok, result =
        pcall(function()
            original =
                hookfunction(
                    marketplace.UserOwnsGamePassAsync,
                    function(self, userId, gamePassId)
                        if tonumber(userId) == LocalPlayer.UserId then
                            return true
                        end

                        return original(
                            self,
                            userId,
                            gamePassId
                        )
                    end
                )

            return original
        end)

    if not ok or type(result) ~= "function" then
        if ExtraFeatures.SetStatus then
            ExtraFeatures.SetStatus(
                "Game Pass Spoofer unavailable in this environment"
            )
        end
        return false
    end

    state.Active = true
    state.TargetFunction =
        marketplace.UserOwnsGamePassAsync
    state.OriginalFunction = result

    if ExtraFeatures.SetStatus then
        ExtraFeatures.SetStatus(
            "Game Pass Spoofer active (client-side only; server ownership unchanged)"
        )
    end

    return true
end

function ExtraFeatures.RestoreGamePassSpoofer()
    local state = ExtraFeatures.GamePass

    if state.Active
        and type(hookfunction) == "function"
        and type(state.TargetFunction) == "function"
        and type(state.OriginalFunction) == "function"
    then
        pcall(function()
            hookfunction(
                state.TargetFunction,
                state.OriginalFunction
            )
        end)
    end

    state.Active = false
    state.TargetFunction = nil
    state.OriginalFunction = nil
end

function ExtraFeatures.TriggerHoldSpamClick()
    if type(mouse1click) == "function" then
        local ok = pcall(mouse1click)

        if ok then
            return true
        end
    end

    if type(mouse1press) == "function"
        and type(mouse1release) == "function"
    then
        local ok = pcall(function()
            mouse1press()
            mouse1release()
        end)

        if ok then
            return true
        end
    end

    if not ExtraFeatures.HoldSpamInput then
        pcall(function()
            ExtraFeatures.HoldSpamInput =
                game:GetService("VirtualInputManager")
        end)
    end

    local inputManager =
        ExtraFeatures.HoldSpamInput

    if not inputManager then
        return false
    end

    local position =
        UserInputService:GetMouseLocation()

    local ok =
        pcall(function()
            inputManager:SendMouseButtonEvent(
                position.X,
                position.Y,
                0,
                true,
                game,
                0
            )

            inputManager:SendMouseButtonEvent(
                position.X,
                position.Y,
                0,
                false,
                game,
                0
            )
        end)

    return ok
end

function ExtraFeatures.UpdateHoldSpam(dt)
    if not Config.HoldToSpamEnabled
        or not ExtraFeatures.HoldSpamKeyHeld
        or not ExtraFeatures.HoldSpamRightHeld
    then
        ExtraFeatures.HoldSpamAccumulator = 0
        return
    end

    ExtraFeatures.HoldSpamAccumulator =
        ExtraFeatures.HoldSpamAccumulator
        + (tonumber(dt) or 0)

    if ExtraFeatures.HoldSpamAccumulator
        < ExtraFeatures.HoldSpamInterval
    then
        return
    end

    ExtraFeatures.HoldSpamAccumulator = 0

    if not ExtraFeatures.TriggerHoldSpamClick() then
        Config.HoldToSpamEnabled = false
        ExtraFeatures.HoldSpamKeyHeld = false
        ExtraFeatures.HoldSpamRightHeld = false

        if UIRefs.Toggles.HoldToSpam then
            UIRefs.Toggles.HoldToSpam.Set(false, true)
        end

        if ExtraFeatures.SetStatus then
            ExtraFeatures.SetStatus(
                "Hold to Spam unavailable: no supported click input API"
            )
        end
    end
end

function ExtraFeatures.Cleanup()
    ExtraFeatures.HoldSpamKeyHeld = false
    ExtraFeatures.HoldSpamRightHeld = false
    ExtraFeatures.HoldSpamListening = false
    ExtraFeatures.HoldSpamKeyBox = nil
    ExtraFeatures.HoldSpamAccumulator = 0

    ExtraFeatures.RestoreAllHeadHitboxes()
    ExtraFeatures.ClearTargetAssist()
    ExtraFeatures.ClearAimSilent()
    ExtraFeatures.SetAntiAFK(false)
    ExtraFeatures.RestoreGamePassSpoofer()

    if ExtraFeatures.CleanupFunction1 then
        pcall(function()
            ExtraFeatures.CleanupFunction1()
        end)
    end

    if ExtraFeatures.CleanupUIEffects then
        ExtraFeatures.CleanupUIEffects()
    end

    ExtraFeatures.NotificationPreviousPage = nil

    if ExtraFeatures.NotificationView
        and ExtraFeatures.NotificationView.Parent
    then
        ExtraFeatures.NotificationView:Destroy()
    end

    ExtraFeatures.NotificationView = nil
end

function OtherSystem.IsCharacterPart(part)
    if not part or typeof(part) ~= "Instance" then
        return true
    end

    local model = part:FindFirstAncestorOfClass("Model")
    if not model then
        return false
    end

    if Players:GetPlayerFromCharacter(model) then
        return true
    end

    if LocalPlayer.Character and model == LocalPlayer.Character then
        return true
    end

    return model:FindFirstChildOfClass("Humanoid") ~= nil
end

function OtherSystem.ApplyXRayPart(part)
    if
        not Config.XRayEnabled
        or not part
        or typeof(part) ~= "Instance"
        or not part:IsA("BasePart")
        or not part:IsDescendantOf(Workspace)
        or OtherSystem.IsCharacterPart(part)
    then
        return
    end

    if OtherSystem.XRayCache[part] == nil then
        OtherSystem.XRayCache[part] = part.Transparency
    end

    local originalTransparency = OtherSystem.XRayCache[part]
    part.Transparency =
        math.max(originalTransparency, Config.XRayTransparency)
end

function OtherSystem.EnableXRay()
    Config.XRayEnabled = true
    OtherSystem.XRayActive = true

    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("BasePart") then
            OtherSystem.ApplyXRayPart(instance)
        end
    end
end

function OtherSystem.DisableXRay()
    Config.XRayEnabled = false
    OtherSystem.XRayActive = false

    for part, originalTransparency in pairs(OtherSystem.XRayCache) do
        if part and part.Parent then
            pcall(function()
                part.Transparency = originalTransparency
            end)
        end
    end

    table.clear(OtherSystem.XRayCache)
end

function OtherSystem.UpdateXRayTransparency()
    if not Config.XRayEnabled then
        return
    end

    for part, originalTransparency in pairs(OtherSystem.XRayCache) do
        if part and part.Parent then
            pcall(function()
                part.Transparency =
                    math.max(
                        originalTransparency,
                        Config.XRayTransparency
                    )
            end)
        end
    end
end

function OtherSystem.SetXRay(enabled)
    enabled = enabled == true

    if enabled then
        if not OtherSystem.XRayActive then
            OtherSystem.EnableXRay()
        else
            Config.XRayEnabled = true
            OtherSystem.UpdateXRayTransparency()
        end
    else
        if OtherSystem.XRayActive or next(OtherSystem.XRayCache) ~= nil then
            OtherSystem.DisableXRay()
        else
            Config.XRayEnabled = false
        end
    end
end

function OtherSystem.SetThirdPerson(enabled)
    enabled = enabled == true
    Config.ThirdPersonLock = enabled

    if enabled then
        if not OtherSystem.ThirdPersonOriginal then
            OtherSystem.ThirdPersonOriginal = {
                CameraMode = LocalPlayer.CameraMode,
                CameraMinZoomDistance = LocalPlayer.CameraMinZoomDistance,
                CameraMaxZoomDistance = LocalPlayer.CameraMaxZoomDistance
            }
        end

        pcall(function()
            LocalPlayer.CameraMode = Enum.CameraMode.Classic

            local maximumZoom =
                math.max(
                    tonumber(LocalPlayer.CameraMaxZoomDistance) or 10,
                    0.5
                )

            LocalPlayer.CameraMinZoomDistance =
                math.min(10, maximumZoom)

            if LocalPlayer.CameraMaxZoomDistance
                < LocalPlayer.CameraMinZoomDistance
            then
                LocalPlayer.CameraMaxZoomDistance =
                    LocalPlayer.CameraMinZoomDistance
            end
        end)
    else
        local original = OtherSystem.ThirdPersonOriginal
        if not original then
            return
        end

        OtherSystem.ThirdPersonOriginal = nil

        pcall(function()
            LocalPlayer.CameraMode = original.CameraMode
            LocalPlayer.CameraMinZoomDistance =
                original.CameraMinZoomDistance
            LocalPlayer.CameraMaxZoomDistance =
                original.CameraMaxZoomDistance
        end)
    end
end

function OtherSystem.SetMenuMouseState(menuOpen)
    if menuOpen then
        if not OtherSystem.MenuMouseState then
            local savedState = {
                MouseBehavior = UserInputService.MouseBehavior,
                MouseIconEnabled = UserInputService.MouseIconEnabled
            }

            pcall(function()
                savedState.OverrideMouseIconBehavior =
                    UserInputService.OverrideMouseIconBehavior
            end)

            pcall(function()
                savedState.MinimizeModal = MinimizeBtn.Modal
                savedState.NotificationModal =
                    UIRefs.NotificationButton.Modal
                savedState.CloseModal = CloseBtn.Modal
            end)

            OtherSystem.MenuMouseState = savedState
        end

        -- Important:
        -- Do NOT force MouseBehavior every render frame. Camera/Shift-Lock
        -- controllers can also write this property and fighting them every frame
        -- may make the cursor appear frozen. A visible Modal GuiButton tells
        -- Roblox that GUI interaction owns the cursor while the menu is open.
        pcall(function()
            MinimizeBtn.Modal = true
            UIRefs.NotificationButton.Modal = true
            CloseBtn.Modal = true

            UserInputService.MouseBehavior =
                Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
            UserInputService.OverrideMouseIconBehavior =
                Enum.OverrideMouseIconBehavior.ForceShow
        end)

        return
    end

    local original = OtherSystem.MenuMouseState
    if not original then
        return
    end

    OtherSystem.MenuMouseState = nil

    pcall(function()
        MinimizeBtn.Modal =
            original.MinimizeModal == true
        UIRefs.NotificationButton.Modal =
            original.NotificationModal == true
        CloseBtn.Modal =
            original.CloseModal == true

        UserInputService.MouseBehavior = original.MouseBehavior
        UserInputService.MouseIconEnabled =
            original.MouseIconEnabled

        if original.OverrideMouseIconBehavior ~= nil then
            UserInputService.OverrideMouseIconBehavior =
                original.OverrideMouseIconBehavior
        else
            UserInputService.OverrideMouseIconBehavior =
                Enum.OverrideMouseIconBehavior.None
        end
    end)
end

function OtherSystem.UpdateMenuInput()
    if GUIState.CurrentState ~= "Open" then
        return
    end

    -- Keep only the GUI modal/icon ownership refreshed.
    -- MouseBehavior itself is intentionally not reassigned here.
    pcall(function()
        MinimizeBtn.Modal = true
        UIRefs.NotificationButton.Modal = true
        CloseBtn.Modal = true
        UserInputService.MouseIconEnabled = true
        UserInputService.OverrideMouseIconBehavior =
            Enum.OverrideMouseIconBehavior.ForceShow
    end)
end

function OtherSystem.IsSettingsLoadChordDown()
    local leftDown =
        UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
    local rightDown =
        UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

    -- Do not use whichever Control key is currently assigned to opening
    -- the menu, otherwise starting CTRL+C+V could toggle the menu first.
    if Config.ToggleKey == Enum.KeyCode.LeftControl then
        leftDown = false
    elseif Config.ToggleKey == Enum.KeyCode.RightControl then
        rightDown = false
    end

    return (leftDown or rightDown)
        and UserInputService:IsKeyDown(Enum.KeyCode.C)
        and UserInputService:IsKeyDown(Enum.KeyCode.V)
end

function OtherSystem.IsTelekillToggleChordDown()
    local leftDown =
        UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
    local rightDown =
        UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

    -- Preserve the existing menu ToggleKey. If one Control key is assigned
    -- to the menu, the other Control key is used for Ctrl + 1 + 2.
    if Config.ToggleKey == Enum.KeyCode.LeftControl then
        leftDown = false
    elseif Config.ToggleKey == Enum.KeyCode.RightControl then
        rightDown = false
    end

    return (leftDown or rightDown)
        and UserInputService:IsKeyDown(Enum.KeyCode.One)
        and UserInputService:IsKeyDown(Enum.KeyCode.Two)
end

function OtherSystem.BeginKeybindCapture(box, captureMode)
    local requestedMode = captureMode or "MenuToggle"

    if OtherSystem.KeybindListening then
        local oldBox = OtherSystem.KeybindBox
        local oldMode = OtherSystem.KeybindCaptureMode or "MenuToggle"

        OtherSystem.KeybindListening = false
        OtherSystem.KeybindCaptureMode = nil
        OtherSystem.KeybindBox = nil

        if oldBox and oldBox.Parent then
            if oldMode == "DroneStrike" then
                oldBox.Text = "Drone Strike Key: " .. Config.DroneStrikeKey.Name
            elseif oldMode == "TelekillSwitch" then
                oldBox.Text =
                    "Switch Target Key: "
                    .. Config.TelekillSwitchKey.Name
            else
                oldBox.Text = Config.ToggleKey.Name
            end
        end

        if oldBox == box then
            return
        end
    end

    OtherSystem.KeybindListening = true
    OtherSystem.KeybindCaptureMode = requestedMode
    OtherSystem.KeybindBox = box

    if box and box.Parent then
        box.Text = "Press Key..."
    end
end

function OtherSystem.HandleKeybindInput(input)
    if not OtherSystem.KeybindListening then
        return false
    end

    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return true
    end

    if input.KeyCode == Enum.KeyCode.Unknown then
        return true
    end

    local mode = OtherSystem.KeybindCaptureMode or "MenuToggle"
    if input.KeyCode ~= Enum.KeyCode.Escape and not ExtraFeatures.ValidateShortcut(input.KeyCode, mode) then
        OtherSystem.ConsumeNextToggleInput = true
        return true
    end
    local box = OtherSystem.KeybindBox

    if input.KeyCode == Enum.KeyCode.Escape then
        OtherSystem.KeybindListening = false
        OtherSystem.KeybindCaptureMode = nil
        OtherSystem.KeybindBox = nil
        OtherSystem.ConsumeNextToggleInput = true

        if box and box.Parent then
            if mode == "DroneStrike" then
                box.Text = "Drone Strike Key: " .. Config.DroneStrikeKey.Name
            elseif mode == "TelekillSwitch" then
                box.Text =
                    "Switch Target Key: "
                    .. Config.TelekillSwitchKey.Name
            else
                box.Text = Config.ToggleKey.Name
            end
        end

        return true
    end

    if mode == "DroneStrike" then
        if input.KeyCode == Enum.KeyCode.W
            or input.KeyCode == Enum.KeyCode.A
            or input.KeyCode == Enum.KeyCode.S
            or input.KeyCode == Enum.KeyCode.D
            or input.KeyCode == Enum.KeyCode.Q
            or input.KeyCode == Enum.KeyCode.E
        then
            if ExtraFeatures.SetStatus then
                ExtraFeatures.SetStatus(
                    "That key is reserved for Drone Strike freecam movement"
                )
            end

            if box and box.Parent then
                box.Text = "Drone Strike Key: " .. Config.DroneStrikeKey.Name
            end

            OtherSystem.KeybindListening = false
            OtherSystem.KeybindCaptureMode = nil
            OtherSystem.KeybindBox = nil
            OtherSystem.ConsumeNextToggleInput = true
            return true
        end

        if input.KeyCode == Config.ToggleKey then
            if ExtraFeatures.SetStatus then
                ExtraFeatures.SetStatus(
                    "Drone Strike key cannot match the menu ToggleKey"
                )
            end

            if box and box.Parent then
                box.Text = "Drone Strike Key: " .. Config.DroneStrikeKey.Name
            end

            OtherSystem.KeybindListening = false
            OtherSystem.KeybindCaptureMode = nil
            OtherSystem.KeybindBox = nil
            OtherSystem.ConsumeNextToggleInput = true
            return true
        end

        Config.DroneStrikeKey = input.KeyCode
    elseif mode == "TelekillSwitch" then
        if input.KeyCode == Config.ToggleKey
            or input.KeyCode == Config.DroneStrikeKey
            or input.KeyCode == Config.HoldToSpamKey
        then
            if ExtraFeatures.SetStatus then
                ExtraFeatures.SetStatus(
                    "Telekill switch key conflicts with another menu key"
                )
            end

            if box and box.Parent then
                box.Text =
                    "Switch Target Key: "
                    .. Config.TelekillSwitchKey.Name
            end

            OtherSystem.KeybindListening = false
            OtherSystem.KeybindCaptureMode = nil
            OtherSystem.KeybindBox = nil
            OtherSystem.ConsumeNextToggleInput = true
            return true
        end

        Config.TelekillSwitchKey = input.KeyCode
    else
        if input.KeyCode == Config.DroneStrikeKey then
            if ExtraFeatures.SetStatus then
                ExtraFeatures.SetStatus(
                    "Menu ToggleKey cannot match the Drone Strike key"
                )
            end

            if box and box.Parent then
                box.Text = Config.ToggleKey.Name
            end

            OtherSystem.KeybindListening = false
            OtherSystem.KeybindCaptureMode = nil
            OtherSystem.KeybindBox = nil
            OtherSystem.ConsumeNextToggleInput = true
            return true
        end

        Config.ToggleKey = input.KeyCode
    end

    OtherSystem.KeybindListening = false
    OtherSystem.KeybindCaptureMode = nil
    OtherSystem.ConsumeNextToggleInput = true

    if box and box.Parent then
        if mode == "DroneStrike" then
            box.Text = "Drone Strike Key: " .. Config.DroneStrikeKey.Name
        elseif mode == "TelekillSwitch" then
            box.Text =
                "Switch Target Key: "
                .. Config.TelekillSwitchKey.Name
        else
            box.Text = Config.ToggleKey.Name
        end
    end

    OtherSystem.KeybindBox = nil

    return true
end

function OtherSystem.Request(url)
    local requestFn

    if type(request) == "function" then
        requestFn = request
    elseif type(http_request) == "function" then
        requestFn = http_request
    elseif type(syn) == "table"
        and type(syn.request) == "function"
    then
        requestFn = syn.request
    elseif type(http) == "table"
        and type(http.request) == "function"
    then
        requestFn = http.request
    end

    if requestFn then
        local ok, response = pcall(function()
            return requestFn({
                Url = url,
                Method = "GET"
            })
        end)

        if ok
            and type(response) == "table"
            and type(response.Body) == "string"
            and (
                response.StatusCode == nil
                or response.StatusCode == 200
            )
        then
            return response.Body
        end
    end

    local ok, body = pcall(function()
        return HttpService:GetAsync(url)
    end)

    if ok and type(body) == "string" then
        return body
    end

    return nil
end

function OtherSystem.GetPublicServers(maxPages)
    maxPages =
        math.clamp(
            math.floor(tonumber(maxPages) or 3),
            1,
            3
        )

    local servers = {}
    local cursor = nil

    for _ = 1, maxPages do
        local url =
            "https://games.roblox.com/v1/games/"
            .. tostring(game.PlaceId)
            .. "/servers/Public?sortOrder=Asc&limit=100"

        if cursor and cursor ~= "" then
            local encodedCursor = cursor
            pcall(function()
                encodedCursor = HttpService:UrlEncode(cursor)
            end)

            url = url
                .. "&cursor="
                .. tostring(encodedCursor)
        end

        local body = OtherSystem.Request(url)
        if not body then
            break
        end

        local ok, data = pcall(function()
            return HttpService:JSONDecode(body)
        end)

        if not ok or type(data) ~= "table" then
            break
        end

        if type(data.data) == "table" then
            for _, server in ipairs(data.data) do
                if
                    type(server) == "table"
                    and type(server.id) == "string"
                    and server.id ~= ""
                then
                    table.insert(servers, server)
                end
            end
        end

        cursor = data.nextPageCursor
        if type(cursor) ~= "string" or cursor == "" then
            break
        end
    end

    return servers
end

function OtherSystem.IsUsablePublicServer(server)
    if type(server) ~= "table" then
        return false
    end

    if type(server.id) ~= "string"
        or server.id == ""
        or server.id == game.JobId
    then
        return false
    end

    local playing = tonumber(server.playing)
    local maxPlayers = tonumber(server.maxPlayers)

    if not playing or not maxPlayers then
        return false
    end

    return playing < maxPlayers
end

function OtherSystem.TeleportToServer(serverId)
    if type(serverId) ~= "string" or serverId == "" then
        return false
    end

    local teleportService =
        game:GetService("TeleportService")

    local teleportOptions
    local asyncOk = pcall(function()
        teleportOptions =
            Instance.new("TeleportOptions")

        teleportOptions.ServerInstanceId = serverId

        teleportService:TeleportAsync(
            game.PlaceId,
            {LocalPlayer},
            teleportOptions
        )
    end)

    if teleportOptions then
        pcall(function()
            teleportOptions:Destroy()
        end)
    end

    if asyncOk then
        return true
    end

    local legacyOk = pcall(function()
        teleportService:TeleportToPlaceInstance(
            game.PlaceId,
            serverId,
            LocalPlayer
        )
    end)

    return legacyOk
end

function OtherSystem.RunServerAction(action)
    if OtherSystem.ServerActionBusy then
        return
    end

    OtherSystem.ServerActionBusy = true
    local generation = OtherSystem.Generation

    task.spawn(function()
        pcall(function()
            local servers =
                OtherSystem.GetPublicServers(3)

            if generation ~= OtherSystem.Generation then
                return
            end

            local selectedServer = nil

            if action == "Change" then
                for _, server in ipairs(servers) do
                    if OtherSystem.IsUsablePublicServer(server) then
                        selectedServer = server
                        break
                    end
                end
            elseif action == "Small" then
                local bestPlaying = math.huge

                for _, server in ipairs(servers) do
                    if
                        OtherSystem.IsUsablePublicServer(server)
                    then
                        local playing = tonumber(server.playing)

                        if
                            playing
                            and playing < bestPlaying
                        then
                            bestPlaying = playing
                            selectedServer = server
                        end
                    end
                end
            elseif action == "Ping" then
                local bestPing = math.huge

                for _, server in ipairs(servers) do
                    if
                        OtherSystem.IsUsablePublicServer(server)
                    then
                        local ping = tonumber(server.ping)

                        if
                            ping
                            and ping >= 0
                            and ping < bestPing
                        then
                            bestPing = ping
                            selectedServer = server
                        end
                    end
                end
            end

            if selectedServer then
                OtherSystem.TeleportToServer(
                    selectedServer.id
                )
            end
        end)

        OtherSystem.ServerActionBusy = false
    end)
end

function OtherSystem.Rejoin()
    if type(game.JobId) ~= "string"
        or game.JobId == ""
    then
        return false
    end

    return OtherSystem.TeleportToServer(game.JobId)
end

function OtherSystem.OnWorkspaceDescendantAdded(instance)
    if Config.XRayEnabled
        and instance
        and typeof(instance) == "Instance"
        and instance:IsA("BasePart")
    then
        OtherSystem.ApplyXRayPart(instance)
    end
end

function OtherSystem.Cleanup()
    OtherSystem.Generation =
        OtherSystem.Generation + 1

    OtherSystem.KeybindListening = false
    OtherSystem.KeybindBox = nil
    OtherSystem.KeybindCaptureMode = nil
    OtherSystem.ConsumeNextToggleInput = false
    OtherSystem.ServerActionBusy = false

    OtherSystem.DisableXRay()
    OtherSystem.SetThirdPerson(false)
    OtherSystem.SetMenuMouseState(false)

    table.clear(OtherSystem.XRayCache)
end

AddConnection(
    Workspace.DescendantAdded:Connect(function(instance)
        OtherSystem.OnWorkspaceDescendantAdded(instance)
    end)
)

AddConnection(
    UserInputService.InputBegan:Connect(function(input)
        OtherSystem.HandleKeybindInput(input)
    end)
)

-- ==========================================
-- 6. PAGE MANAGER & TAB SYSTEM
-- ==========================================
local PageManager = {}

function PageManager:AddPage(pageName, options)
    options = options or {}
    local placement = options.Placement or "Sidebar"

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

    -- Both vertical and horizontal tabs reuse the same PageManager/GUIState.
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = pageName .. "Btn"

    if placement == "Top" then
        tabBtn.Size = UDim2.fromOffset(
            math.max(86, math.min(150, #pageName * 7 + 26)),
            24
        )
        tabBtn.TextSize = 12
        tabBtn.Parent = TopTabBar
    else
        tabBtn.Size = UDim2.new(1, 0, 0, 32)
        tabBtn.TextSize = 12
        tabBtn.Parent = TabContainer
    end

    tabBtn.Text = pageName
    tabBtn.TextColor3 = Config.SubTextColor
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.BackgroundColor3 = Config.DarkBg
    tabBtn.AutoButtonColor = false

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabBtn

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Color = Config.BorderColor
    tabStroke.Thickness = placement == "Top" and 1 or 0
    tabStroke.Transparency = placement == "Top" and 0.25 or 1
    tabStroke.Parent = tabBtn

    GUIState.Pages[pageName] = pageScroll
    GUIState.TabButtons[pageName] = tabBtn

    AddConnection(tabBtn.MouseButton1Click:Connect(function()
        PageManager:ShowPage(pageName)
    end))

    return pageScroll
end

function PageManager:ShowPage(pageName, suppressEffects)
    if not GUIState.Pages[pageName] then return false end
    if UIRefs.Experience.OverlayOpen then return false end
    if ExtraFeatures.NotificationView then
        ExtraFeatures.NotificationView.Visible = false
    end
    ExtraFeatures.NotificationPreviousPage = nil
    local previousPage = GUIState.ActivePage

    for name, page in pairs(GUIState.Pages) do
        local btn = GUIState.TabButtons[name]
        if name == pageName then
            page.Visible = true
            if btn then
                btn.BackgroundColor3 = Config.AccentColor
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
            GUIState.ActivePage = name
            Config.Interface.LastPage = name
        else
            page.Visible = false
            if btn then
                btn.BackgroundColor3 = Config.DarkBg
                btn.TextColor3 = Config.SubTextColor
            end
        end
    end

    if suppressEffects ~= true
        and previousPage ~= GUIState.ActivePage
        and ExtraFeatures.OnTabChanged
    then
        pcall(function()
            ExtraFeatures.OnTabChanged(
                previousPage,
                GUIState.ActivePage
            )
        end)
    end
end

function ExtraFeatures.BuildNotificationView()
    if ExtraFeatures.NotificationView and ExtraFeatures.NotificationView.Parent then
        return ExtraFeatures.NotificationView
    end
    local view = Instance.new("Frame")
    view.Name = "NotificationInternalView"
    view.Size = UDim2.fromScale(1, 1)
    view.BackgroundTransparency = 1
    view.Visible = false
    view.Parent = ContentArea
    local back = Instance.new("TextButton")
    back.Name = "Back"; back.Size = UDim2.fromOffset(36, 32)
    back.Position = UDim2.fromOffset(12, 10); back.Text = "←"
    back.TextColor3 = Config.TextColor; back.TextSize = 18; back.Font = Enum.Font.GothamBold
    back.BackgroundColor3 = Config.CardBg; back.AutoButtonColor = false; back.Parent = view
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 7); corner.Parent = back
    local heading = Instance.new("TextLabel")
    heading.Name = "Heading"; heading.Position = UDim2.fromOffset(58, 10)
    heading.Size = UDim2.new(1, -70, 0, 32); heading.BackgroundTransparency = 1
    heading.Text = "NOTIFICATIONS"; heading.TextSize = 14; heading.Font = Enum.Font.GothamBold
    heading.TextColor3 = Config.TextColor; heading.TextXAlignment = Enum.TextXAlignment.Left; heading.Parent = view
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "MessageScroll"; scroll.Position = UDim2.fromOffset(12, 52)
    scroll.Size = UDim2.new(1, -24, 1, -64); scroll.BackgroundColor3 = Config.CardBg
    scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Config.SubTextColor; scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = view
    local padding = Instance.new("UIPadding")
    padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
    padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12); padding.Parent = scroll
    local message = Instance.new("TextLabel")
    message.Name = "NotificationText"; message.Size = UDim2.new(1, -6, 0, 0)
    message.AutomaticSize = Enum.AutomaticSize.Y; message.BackgroundTransparency = 1
    message.Text = ""; message.TextColor3 = Config.TextColor; message.Font = Enum.Font.GothamMedium
    message.TextSize = 13; message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left; message.TextYAlignment = Enum.TextYAlignment.Top
    message.Parent = scroll
    UIRefs.Experience.NotificationLabel = message
    AddConnection(back.MouseButton1Click:Connect(function()
        local previous = ExtraFeatures.NotificationPreviousPage or Config.StartPage
        PageManager:ShowPage(previous, true)
    end))
    ExtraFeatures.NotificationView = view
    return view
end

function ExtraFeatures.OpenNotificationView(override, title)
    if UIRefs.Experience.OverlayOpen then return end
    local view = ExtraFeatures.BuildNotificationView()
    if not view.Visible then ExtraFeatures.NotificationPreviousPage = GUIState.ActivePage end
    for _, page in pairs(GUIState.Pages) do page.Visible = false end
    local text = override
    if text == nil then
        local lines = {tostring(ExtraFeatures.NotificationText or "")}
        local history = UIRefs.Experience.History
        if #history > 0 then
            table.insert(lines, "\nRECENT ACTIVITY")
            for index = #history, 1, -1 do
                local entry = history[index]
                table.insert(lines, os.date("%H:%M:%S", entry.Time) .. "  " .. entry.Text)
            end
        end
        text = table.concat(lines, "\n\n")
    end
    UIRefs.Experience.NotificationLabel.Text = tostring(text)
    view.Heading.Text = title or "NOTIFICATIONS"
    view.MessageScroll.CanvasPosition = Vector2.zero
    view.Visible = true
end



AddConnection(UIRefs.NotificationButton.MouseButton1Click:Connect(function()
    ExtraFeatures.OpenNotificationView()
end))

-- ==========================================
-- 7. COMPONENT ENGINE (MODULAR BUILDER)
-- ==========================================
local UI = {}

function UI:ConnectOwned(object, signal, callback)
    local connection = signal:Connect(callback)
    object.Destroying:Connect(function() connection:Disconnect() end)
    return connection
end

-- Define this before startup calls that can yield (for example game metadata).
function ExtraFeatures.ValidateShortcut(key, owner)
    local message
    if key == Enum.KeyCode.Unknown or key == Enum.KeyCode.F4 then
        message = "F4 is reserved for unloading the framework."
    else
        local keys = {MenuToggle = Config.ToggleKey, DroneStrike = Config.DroneStrikeKey,
            TelekillSwitch = Config.TelekillSwitchKey, HoldToSpam = Config.HoldToSpamKey}
        for name, assigned in pairs(keys) do
            if name ~= owner and key == assigned then message = "Key already assigned to " .. name .. "."; break end
        end
    end
    if message then
        if ExtraFeatures.Notify then ExtraFeatures.Notify(message)
        elseif ExtraFeatures.SetStatus then ExtraFeatures.SetStatus(message) end
        return false
    end
    return true
end

function UI:Invoke(callback, context, ...)
    if type(callback) ~= "function" then return true end
    local ok, result = pcall(callback, ...)
    if not ok then
        local message = tostring(context or "UI") .. ": " .. tostring(result)
        table.insert(UIRefs.Experience.Errors, {Time = os.time(), Text = message})
        if #UIRefs.Experience.Errors > 40 then table.remove(UIRefs.Experience.Errors, 1) end
        warn("[Hood Rivals UI] " .. message)
        if ExtraFeatures.Notify then ExtraFeatures.Notify("Action failed. See diagnostics.", "error") end
    end
    return ok, result
end

function UI:Tween(object, slot, duration, goals)
    if not object or not object.Parent then return end
    local slots = UIRefs.Experience.TweenSlots[object]
    if not slots then slots = {}; UIRefs.Experience.TweenSlots[object] = slots end
    if slots[slot] then slots[slot]:Cancel(); slots[slot] = nil end
    if Config.Interface.ReducedMotion then
        for key, value in pairs(goals) do object[key] = value end
        return
    end
    local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out), goals)
    slots[slot] = tween
    tween:Play()
end

function UI:RegisterControl(frame, text, kind, api, options)
    local parent, section, page = frame.Parent, nil, nil
    while parent and parent ~= ContentArea do
        if not section then section = UIRefs.Experience.SectionByFrame[parent] end
        for name, instance in pairs(GUIState.Pages) do
            if parent == instance then page = name; break end
        end
        parent = parent.Parent
    end
    if not page or not section then return nil end
    -- Nested player/profile list items stay dynamic and are not search controls.
    if frame.Parent ~= section.Frame then return nil end
    local record = {Frame = frame, Text = tostring(text or ""), Kind = kind, API = api,
        Options = options or {}, Section = section, Page = page}
    record.Id = page .. "/" .. section.Title .. "/" .. kind .. "/" .. record.Text
    record.Search = string.lower(page .. " " .. section.Title .. " " .. record.Text)
    table.insert(UIRefs.Experience.Controls, record)
    UIRefs.Experience.ByFrame[frame] = record
    return record
end

function UI:ApplyFilter()
    local state = UIRefs.Experience
    local query = ExtraFeatures.V8.Normalize(state.Query or "")
    local filtering = query ~= "" or state.FavoritesOnly
    local counts = {}
    for _, record in ipairs(state.Controls) do
        if record.Frame.Parent then
            local match = query == "" or string.find(record.SearchNormalized or ExtraFeatures.V8.Normalize(record.Search), query, 1, true) ~= nil
            if state.FavoritesOnly and not Config.Interface.Favorites[record.Id] then match = false end
            record.Matches = match
            counts[record.Page] = (counts[record.Page] or 0) + (match and 1 or 0)
            record.Frame.Visible = match
            if record.Star then
                record.Star.Text = Config.Interface.Favorites[record.Id] and "★" or "☆"
                record.Star.TextColor3 = Config.Interface.Favorites[record.Id]
                    and Color3.fromRGB(255, 206, 103) or Config.SubTextColor
            end
        end
    end
    -- Process nested sections before their parents, preserving user-opened panels.
    for index = #state.Sections, 1, -1 do
        local section = state.Sections[index]
        if not section.Frame.Parent then continue end
        local match = not filtering
        if filtering then
            for _, record in ipairs(state.Controls) do
                if record.Matches and record.Frame:IsDescendantOf(section.Frame) then match = true; break end
            end
        end
        if section.TopLevel then
            section.Frame.Visible = match
        elseif filtering then
            if section.SearchRestore == nil then section.SearchRestore = section.Frame.Visible end
            section.Frame.Visible = match
        elseif section.SearchRestore ~= nil then
            section.Frame.Visible = section.SearchRestore
            section.SearchRestore = nil
        end
        local collapsed = Config.Interface.CollapsedSections[section.Id] == true and not filtering
        if section.Header then section.Header.Text = (collapsed and "+  " or "−  ") .. section.Title end
        for _, child in ipairs(section.Frame:GetChildren()) do
            if child:IsA("GuiObject") and child ~= section.Header then
                if collapsed then
                    if section.Restore[child] == nil then section.Restore[child] = child.Visible end
                    child.Visible = false
                elseif section.Restore[child] ~= nil then
                    child.Visible = section.Restore[child]
                    section.Restore[child] = nil
                    local record = state.ByFrame[child]
                    if record then child.Visible = record.Matches end
                end
            end
        end
    end
    state.Counts = counts
    for page, record in pairs(state.Pages) do
        if record.Empty then record.Empty.Visible = filtering and (counts[page] or 0) == 0 end
    end
    if state.SearchCount then
        local total = 0
        for _, value in pairs(counts) do total = total + value end
        state.SearchCount.Text = filtering and (tostring(total) .. " results") or "ALL FEATURES"
    end
end

function UI:AddFavorite(record, anchor)
    if not record or record.Star then return end
    local star = Instance.new("TextButton")
    star.Name = "Favorite"
    star.Text = "☆"
    star.Font = Enum.Font.GothamBold
    star.TextSize = 18
    star.BackgroundTransparency = 1
    star.AutoButtonColor = false
    star.Size = UDim2.fromOffset(26, 28)
    star.Position = anchor or UDim2.new(1, -82, 0, 0)
    star.ZIndex = 5
    star.Parent = record.Frame
    record.Star = star
    AddConnection(star.MouseButton1Click:Connect(function()
        if UIRefs.Experience.OverlayOpen then return end
        Config.Interface.Favorites[record.Id] = not Config.Interface.Favorites[record.Id] or nil
        UI:ApplyFilter()
        if ExtraFeatures.V8.SaveInterface then ExtraFeatures.V8.SaveInterface() end

    end))
end


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
        local secTitle = Instance.new("TextButton")
        secTitle.Size = UDim2.new(1, 0, 0, 18)
        secTitle.Name = "SectionHeader"
        secTitle.Text = titleText
        secTitle.LayoutOrder = -1000
        secTitle.TextXAlignment = Enum.TextXAlignment.Left
        secTitle.AutoButtonColor = false
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
    label.Font = Enum.Font.GothamMedium
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

    local busy = false
    UI:ConnectOwned(btn, btn.MouseButton1Click, function()
        if busy or not btn.Parent then return end
        busy = true
        UI:Tween(btn, "Press", 0.12, {BackgroundColor3 = Config.AccentColor})
        UI:Invoke(callback, "Button: " .. tostring(text))
        if btn.Parent then
            UI:Tween(btn, "Press", 0.18, {BackgroundColor3 = Config.DarkBg})
        end
        busy = false
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
    toggleFrame.Size = UDim2.new(1, 0, 0, 30)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local rowScale = Instance.new("UIScale")
    rowScale.Name = "TogglePopScale"
    rowScale.Scale = 1
    rowScale.Parent = toggleFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -58, 1, 0)
    label.Text = text
    label.TextColor3 = Config.TextColor
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Parent = toggleFrame

    local switch = Instance.new("TextButton")
    switch.Name = "SmoothSwitch"
    switch.Size = UDim2.fromOffset(46, 24)
    switch.Position = UDim2.new(1, -46, 0.5, -12)
    switch.Text = ""
    switch.BackgroundColor3 =
        state
        and Config.AccentColor
        or Color3.fromRGB(55, 55, 64)
    switch.BorderSizePixel = 0
    switch.AutoButtonColor = false
    switch.Parent = toggleFrame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(1, 0)
    sCorner.Parent = switch

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = Config.BorderColor
    sStroke.Thickness = 1
    sStroke.Transparency = 0.25
    sStroke.Parent = switch

    local circle = Instance.new("Frame")
    circle.Name = "Indicator"
    circle.Size = UDim2.fromOffset(18, 18)
    circle.Position =
        state
        and UDim2.new(1, -21, 0.5, -9)
        or UDim2.new(0, 3, 0.5, -9)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.BorderSizePixel = 0
    circle.Parent = switch

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(1, 0)
    cCorner.Parent = circle

    local function pop(userInitiated)
        local downScale =
            userInitiated and 0.90 or 0.95

        TweenService:Create(
            rowScale,
            TweenInfo.new(
                0.06,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {Scale = downScale}
        ):Play()

        task.delay(0.06, function()
            if rowScale and rowScale.Parent then
                TweenService:Create(
                    rowScale,
                    TweenInfo.new(
                        userInitiated and 0.18 or 0.12,
                        Enum.EasingStyle.Back,
                        Enum.EasingDirection.Out
                    ),
                    {Scale = 1}
                ):Play()
            end
        end)
    end

    local function applyState(
        newState,
        invokeCallback,
        usePop,
        userInitiated
    )
        if type(newState) ~= "boolean" then
            return
        end

        state = newState

        local targetColor =
            state
            and Config.AccentColor
            or Color3.fromRGB(55, 55, 64)

        local targetPos =
            state
            and UDim2.new(1, -21, 0.5, -9)
            or UDim2.new(0, 3, 0.5, -9)

        local backgroundTweenInfo = TweenInfo.new(
            Config.Interface.ReducedMotion and 0 or 0.24,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        )

        local indicatorTweenInfo

        if userInitiated then
            indicatorTweenInfo = TweenInfo.new(
                Config.Interface.ReducedMotion and 0 or 0.34,
                Enum.EasingStyle.Bounce,
                Enum.EasingDirection.Out
            )
        else
            indicatorTweenInfo = backgroundTweenInfo
        end

        TweenService:Create(
            switch,
            backgroundTweenInfo,
            {BackgroundColor3 = targetColor}
        ):Play()

        TweenService:Create(
            circle,
            indicatorTweenInfo,
            {Position = targetPos}
        ):Play()

        if usePop and not Config.Interface.ReducedMotion then
            pop(userInitiated == true)
        end

        if userInitiated
            and ExtraFeatures.OnUserToggleClicked
        then
            pcall(function()
                ExtraFeatures.OnUserToggleClicked(switch)
            end)
        end

        if invokeCallback ~= false then
            UI:Invoke(callback, "Toggle: " .. text, state)
        end
    end

    AddConnection(
        switch.MouseButton1Click:Connect(function()
            applyState(
                not state,
                true,
                true,
                true
            )
        end)
    )

    return {
        Frame = toggleFrame,
        Label = label,
        Switch = switch,
        Default = default,
        Set = function(val, silent)
            if type(val) ~= "boolean" then
                return
            end

            if state ~= val then
                applyState(
                    val,
                    silent ~= true,
                    false,
                    false
                )
            elseif silent then
                -- Visual refresh only; callback must remain silent and must
                -- never trigger explosive FX / sound / pet reaction.
                applyState(
                    val,
                    false,
                    false,
                    false
                )
            end
        end,

        Get = function()
            return state
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

    -- currentValue is the single source of truth for gameplay/config data.
    -- Visual fill/knob position follows through the shared heavy-friction
    -- slider updater in HoodRivalsUnifiedRender.
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
        valueBox = Instance.new("TextBox")
        valueBox.Size = UDim2.new(0.40, 0, 0, 18)
        valueBox.Position = UDim2.new(0.60, 0, 0, 0)
        valueBox.Text = FormatValue(currentValue)
        valueBox.TextColor3 = Config.SubTextColor
        valueBox.PlaceholderText = FormatValue(currentValue)
        valueBox.PlaceholderColor3 = Config.SubTextColor
        valueBox.Font = Enum.Font.GothamMedium
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
        valueBox.Font = Enum.Font.GothamMedium
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

    local knob = Instance.new("Frame")
    knob.Name = "HeavyFrictionKnob"
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(12, 12)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = fill.ZIndex + 1
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = Config.AccentColor
    knobStroke.Thickness = 1
    knobStroke.Transparency = 0.15
    knobStroke.Parent = knob

    local dragging = false
    local activeInput = nil
    local hitArea = Instance.new("TextButton")
    hitArea.Name = "SliderHitArea"
    hitArea.Text = ""
    hitArea.BackgroundTransparency = 1
    hitArea.AutoButtonColor = false
    hitArea.Size = UDim2.new(1, 12, 0, 24)
    hitArea.Position = UDim2.new(0, -6, 1, -20)
    hitArea.ZIndex = knob.ZIndex + 1
    hitArea.Parent = sliderFrame

    local visualState = {
        Fill = fill,
        Knob = knob,
        TargetPercentage = 0,
        VisualPercentage = 0,
        ActiveVisual = false
    }

    ExtraFeatures.UIEffects.Sliders.Active[sliderFrame] =
        visualState

    local function GetPercentage()
        local visualMax = math.max(
            sliderMax,
            min + math.max(increment, 0.0001)
        )
        local denominator = visualMax - min

        if denominator <= 0 then
            return 0
        end

        return math.clamp(
            (currentValue - min) / denominator,
            0,
            1
        )
    end

    local function ApplyVisualPercentage(percentage)
        percentage = math.clamp(
            tonumber(percentage) or 0,
            0,
            1
        )

        visualState.VisualPercentage = percentage
        fill.Size = UDim2.new(percentage, 0, 1, 0)
        knob.Position = UDim2.new(
            percentage,
            0,
            0.5,
            0
        )
    end

    local function updateVisuals(immediate)
        local percentage = GetPercentage()

        valueBox.Text = FormatValue(currentValue)
        visualState.TargetPercentage = percentage

        if immediate == true or Config.Interface.ReducedMotion then
            visualState.ActiveVisual = false
            ApplyVisualPercentage(percentage)
        else
            visualState.ActiveVisual = true
        end
    end

    -- Slider input updates the real value immediately. Only the visual
    -- fill/knob has friction, so gameplay controls never inherit UI lag.
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

        updateVisuals(false)
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
            if enteredValue > sliderMax then
                sliderMax = enteredValue
            end

            currentValue = enteredValue
        else
            currentValue = math.clamp(
                enteredValue,
                min,
                sliderMax
            )

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

        updateVisuals(false)
        callback(currentValue)
    end

    local function SetValue(value, silent)
        if not IsFiniteNumber(value) then
            return false
        end

        if value < min then
            value = min
        end

        if allowTextInputBeyondRange and value > sliderMax then
            sliderMax = value
        end

        currentValue = math.clamp(value, min, sliderMax)
        updateVisuals(false)

        if silent ~= true then
            callback(currentValue)
        end

        return true
    end

    if editableValue then
        AddConnection(
            valueBox.FocusLost:Connect(function()
                updateFromText()
            end)
        )
    end

    AddConnection(
        hitArea.InputBegan:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                if dragging or UIRefs.Experience.OverlayOpen then return end
                dragging = true
                activeInput = input
                updateFromSlider(input.Position)
            end
        end)
    )

    AddConnection(
        UserInputService.InputChanged:Connect(function(input)
            if
                dragging
                and (input == activeInput or (activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement))
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
                input == activeInput
            then
                dragging = false
                activeInput = nil
            end
        end)
    )

    table.insert(UIRefs.Experience.DragResetters, function()
        dragging = false
        activeInput = nil
    end)
    updateVisuals(true)

    return {
        Frame = sliderFrame,
        Label = label,
        Value = valueBox,
        HitArea = hitArea,
        Default = currentValue,
        OriginalDefault = default,
        Min = min,
        Max = max,
        Set = SetValue,
        Get = function()
            return currentValue
        end
    }
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
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 12
    box.BackgroundColor3 = Config.DarkBg
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Parent = tbFrame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 5)
    bCorner.Parent = box

    AddConnection(box.FocusLost:Connect(function(enterPressed)
        local num = tonumber(box.Text)
        if num then
            callback(num, enterPressed)
        else
            callback(box.Text, enterPressed)
        end
    end))

    return box
end

-- Decorate the existing component API without replacing its gameplay callbacks.
UIRefs.Experience.BaseUI = {
    Section = UI.CreateSection,
    Toggle = UI.CreateToggle,
    Slider = UI.CreateSlider,
    Button = UI.CreateButton,
    Label = UI.CreateLabel,
    Textbox = UI.CreateTextbox
}

function UI:CreateSection(parent, titleText)
    local frame = UIRefs.Experience.BaseUI.Section(self, parent, titleText or "")
    local page = parent
    while page.Parent and page.Parent ~= ContentArea do page = page.Parent end
    local title = tostring(titleText or "")
    local record = {Frame = frame, Title = title, Header = frame:FindFirstChild("SectionHeader"),
        Id = page.Name .. "/" .. title, TopLevel = parent.Parent == ContentArea, Restore = {}}
    UIRefs.Experience.SectionByFrame[frame] = record
    table.insert(UIRefs.Experience.Sections, record)
    frame:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 9)
    local padding = frame:FindFirstChildOfClass("UIPadding")
    padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
    padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
    if record.Header then
        record.Header.Size = UDim2.new(1, 0, 0, 25)
        record.Header.TextSize = 13
        record.Header.TextColor3 = Config.AccentColor
        AddConnection(record.Header.MouseButton1Click:Connect(function()
            if UIRefs.Experience.OverlayOpen then return end
            Config.Interface.CollapsedSections[record.Id] = not Config.Interface.CollapsedSections[record.Id] or nil
            UI:ApplyFilter()
            if ExtraFeatures.V8.SaveInterface then ExtraFeatures.V8.SaveInterface() end
        end))
    end
    return frame
end

function UI:CreateToggle(parent, options)
    local api = UIRefs.Experience.BaseUI.Toggle(self, parent, options)
    local frame, label = api.Frame, api.Label
    local record = UI:RegisterControl(frame, (options or {}).Text, "Toggle", api, options)
    if record then
        frame.Size = UDim2.new(1, 0, 0, 46)
        label.Size = UDim2.new(1, -94, 0, 23)
        label.TextSize = 14
        label.TextTruncate = Enum.TextTruncate.AtEnd
        api.Switch.Position = UDim2.new(1, -46, 0, 2)
        local hint = Instance.new("TextLabel")
        hint.Name = "ControlHint"
        hint.BackgroundTransparency = 1
        hint.Size = UDim2.new(1, -4, 0, 17)
        hint.Position = UDim2.fromOffset(0, 25)
        hint.Text = ""
        hint.TextColor3 = Config.SubTextColor
        hint.Font = Enum.Font.GothamMedium
        hint.TextSize = 11
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.TextTruncate = Enum.TextTruncate.AtEnd
        hint.Parent = frame
        record.Hint = hint
        local hit = Instance.new("TextButton")
        hit.Name = "RowHitArea"
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.AutoButtonColor = false
        hit.Size = UDim2.new(1, -94, 1, 0)
        hit.ZIndex = 3
        hit.Parent = frame
        AddConnection(hit.MouseButton1Click:Connect(function()
            if UIRefs.Experience.OverlayOpen then return end
            api.Set(not api.Get())
            ExtraFeatures.OnUserToggleClicked(api.Switch)
        end))
        UI:AddFavorite(record)
    end
    return api
end

function UI:CreateSlider(parent, options)
    local api = UIRefs.Experience.BaseUI.Slider(self, parent, options)
    local record = UI:RegisterControl(api.Frame, (options or {}).Text, "Slider", api, options)
    if record then
        api.Frame.Size = UDim2.new(1, 0, 0, 62)
        api.Label.TextSize = 14
        api.Label.Size = UDim2.new(1, -160, 0, 22)
        api.Label.TextTruncate = Enum.TextTruncate.AtEnd
        api.Value.Size = UDim2.fromOffset(70, 22)
        api.Value.Position = UDim2.new(1, -150, 0, 0)
        api.Value.TextSize = 13
        local reset = Instance.new("TextButton")
        reset.Name = "ResetValue"
        reset.Text = "↺"
        reset.TextSize = 18
        reset.Font = Enum.Font.GothamBold
        reset.TextColor3 = Config.SubTextColor
        reset.BackgroundTransparency = 1
        reset.AutoButtonColor = false
        reset.Size = UDim2.fromOffset(28, 26)
        reset.Position = UDim2.new(1, -58, 0, -2)
        reset.Parent = api.Frame
        AddConnection(reset.MouseButton1Click:Connect(function() api.Set(api.OriginalDefault) end))
        local hint = Instance.new("TextLabel")
        hint.Name = "ControlHint"
        hint.Text = ""
        hint.BackgroundTransparency = 1
        hint.Size = UDim2.new(1, 0, 0, 17)
        hint.Position = UDim2.fromOffset(0, 24)
        hint.Font = Enum.Font.GothamMedium
        hint.TextSize = 11
        hint.TextColor3 = Config.SubTextColor
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.TextTruncate = Enum.TextTruncate.AtEnd
        hint.Parent = api.Frame
        record.Hint = hint
        UI:AddFavorite(record, UDim2.new(1, -28, 0, -2))
    end
    return api
end

function UI:CreateButton(parent, text, callback)
    local button = UIRefs.Experience.BaseUI.Button(self, parent, text, callback)
    local record = UI:RegisterControl(button, text, "Button", button)
    if record then
        button.Size = UDim2.new(1, 0, 0, 36)
        button.TextSize = 13
        button.TextTruncate = Enum.TextTruncate.AtEnd
    end
    UI:ConnectOwned(button, button.MouseEnter, function()
        UI:Tween(button, "Hover", 0.14, {BackgroundColor3 = Color3.fromRGB(30, 45, 67)})
    end)
    UI:ConnectOwned(button, button.MouseLeave, function()
        UI:Tween(button, "Hover", 0.14, {BackgroundColor3 = button:GetAttribute("Selected") and Config.AccentColor or Config.DarkBg})
    end)
    return button
end

function UI:CreateLabel(parent, text)
    local label = UIRefs.Experience.BaseUI.Label(self, parent, text)
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.TextSize = 12
    return label
end

function UI:CreateTextbox(parent, options)
    local box = UIRefs.Experience.BaseUI.Textbox(self, parent, options)
    box.Size = UDim2.new(0.5, 0, 1, 0)
    box.Position = UDim2.new(0.5, 0, 0, 0)
    box.TextSize = 13
    local label = box.Parent:FindFirstChildOfClass("TextLabel")
    if label then label.TextSize = 13 end
    UI:RegisterControl(box.Parent, (options or {}).Text, "Textbox", box, options)
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

    JumpPowerOriginal = nil,
    UseJumpPowerOriginal = nil,

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

local function CaptureOriginalJumpPower(humanoid)
    if not humanoid then
        PlayerRuntime.JumpPowerOriginal = nil
        PlayerRuntime.UseJumpPowerOriginal = nil
        return
    end

    PlayerRuntime.JumpPowerOriginal = humanoid.JumpPower
    PlayerRuntime.UseJumpPowerOriginal = humanoid.UseJumpPower
end

local function RestoreOriginalJumpPower(humanoid)
    if not humanoid then
        return
    end

    local originalJumpPower = PlayerRuntime.JumpPowerOriginal
    local originalUseJumpPower = PlayerRuntime.UseJumpPowerOriginal

    pcall(function()
        if originalJumpPower ~= nil then
            humanoid.JumpPower = originalJumpPower
        end

        if originalUseJumpPower ~= nil then
            humanoid.UseJumpPower = originalUseJumpPower
        end
    end)
end

local function RefreshPlayerCharacterReferences(character)
    PlayerRuntime.Character = character
    PlayerRuntime.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    PlayerRuntime.RootPart = character and character:FindFirstChild("HumanoidRootPart") or nil
    PlayerRuntime.NoclipOriginalCanCollide = {}

    CaptureOriginalJumpPower(PlayerRuntime.Humanoid)

    -- Preserve the game's native jump value until the user explicitly enables
    -- the Jump Power override control.
    if
        PlayerRuntime.Humanoid
        and not Config.Player.JumpPowerOverrideEnabled
    then
        local nativeJumpPower = PlayerRuntime.Humanoid.JumpPower

        if type(nativeJumpPower) == "number"
            and nativeJumpPower == nativeJumpPower
            and nativeJumpPower ~= math.huge
            and nativeJumpPower ~= -math.huge
        then
            Config.Player.JumpPower = nativeJumpPower
        end
    end
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

    if PlayerRuntime.Humanoid then
        RestoreOriginalJumpPower(PlayerRuntime.Humanoid)
    end

    PlayerRuntime.Character = nil
    PlayerRuntime.Humanoid = nil
    PlayerRuntime.RootPart = nil
    PlayerRuntime.AirFlyJumpRequested = false
    PlayerRuntime.JumpPowerOriginal = nil
    PlayerRuntime.UseJumpPowerOriginal = nil
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

    -- Never override the game's jump settings unless the user explicitly enables it.
    if Config.Player.JumpPowerOverrideEnabled then
        ApplyJumpPower(humanoid)
    end

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
    if ExtraFeatures.SetDroneStrikeActive then
        pcall(function()
            ExtraFeatures.SetDroneStrikeActive(false)
        end)
    end

    RefreshPlayerCharacterReferences(character)

    PlayerRuntime.AirFlyJumpRequested = false

    -- Remove only our previous fly objects from the new character, if any.
    DestroyFlyObjects(character)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and Config.Player.JumpPowerOverrideEnabled then
        ApplyJumpPower(humanoid)
    end
end

local function HandleLocalCharacterRemoving(character)
    if ExtraFeatures.SetDroneStrikeActive then
        pcall(function()
            ExtraFeatures.SetDroneStrikeActive(false)
        end)
    end

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

UIRefs.Toggles.CFrameSpeedEnabled = UI:CreateToggle(PlayerMovementSec, {
    Text = "CFrame Speed",
    Default = false,
    Callback = function(value)
        Config.Player.CFrameSpeedEnabled = value
    end
})

UIRefs.Sliders.CFrameSpeed = UI:CreateSlider(PlayerMovementSec, {
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

UIRefs.Toggles.JumpPowerOverrideEnabled = UI:CreateToggle(PlayerJumpSec, {
    Text = "Jump Power Override",
    Default = Config.Player.JumpPowerOverrideEnabled,
    Callback = function(value)
        Config.Player.JumpPowerOverrideEnabled = value

        local humanoid = PlayerRuntime.Humanoid

        if value then
            ApplyJumpPower(humanoid)
        else
            RestoreOriginalJumpPower(humanoid)
        end
    end
})

UIRefs.Toggles.AirFlyEnabled = UI:CreateToggle(PlayerJumpSec, {
    Text = "Air Fly",
    Default = false,
    Callback = function(value)
        Config.Player.AirFlyEnabled = value

        if not value then
            PlayerRuntime.AirFlyJumpRequested = false
        end
    end
})

UIRefs.Sliders.JumpPower = UI:CreateSlider(PlayerJumpSec, {
    Text = "Jump Power",
    Min = 20,
    Max = 200,
    Default = 50,
    Increment = 1,
    EditableValue = true,
    AllowTextInputBeyondRange = true,
    Callback = function(value)
        Config.Player.JumpPower = value

        if Config.Player.JumpPowerOverrideEnabled then
            ApplyJumpPower(PlayerRuntime.Humanoid)
        end
    end
})

local PlayerFlySec = UI:CreateSection(PlayerPage, "FLY")

UIRefs.Toggles.FlyEnabled = UI:CreateToggle(PlayerFlySec, {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        Config.Player.FlyEnabled = value

        if not value then
            DestroyFlyObjects(PlayerRuntime.Character or LocalPlayer.Character)
        end
    end
})

UIRefs.Sliders.FlySpeed = UI:CreateSlider(PlayerFlySec, {
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

UIRefs.Toggles.FullBrightEnabled = UI:CreateToggle(PlayerVisualSec, {
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

UIRefs.Toggles.NoclipEnabled = UI:CreateToggle(PlayerCharacterSec, {
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

UIRefs.Toggles.AimEnabled = UI:CreateToggle(AimMainSec, {
    Text = "Aim Enable",
    Default = Config.AimEnabled,
    Callback = function(value)
        Config.AimEnabled = value
    end
})

UIRefs.Toggles.TeamCheck = UI:CreateToggle(AimMainSec, {
    Text = "Team Check",
    Default = Config.TeamCheck,
    Callback = function(value)
        Config.TeamCheck = value
    end
})

UIRefs.Toggles.WallCheck = UI:CreateToggle(AimMainSec, {
    Text = "Wall Check",
    Default = Config.WallCheck,
    Callback = function(value)
        Config.WallCheck = value
    end
})

UIRefs.Toggles.IgnoreVisibility = UI:CreateToggle(AimMainSec, {
    Text = "Ignore Visibility",
    Default = Config.IgnoreVisibility,
    Callback = function(value)
        Config.IgnoreVisibility = value
    end
})

UIRefs.Toggles.AimNPC = UI:CreateToggle(AimMainSec, {
    Text = "AIM NPC",
    Default = Config.AimNPC,
    Callback = function(value)
        Config.AimNPC = value
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

UIRefs.Toggles.UseFOV = UI:CreateToggle(AimFovSec, {
    Text = "Use FOV",
    Default = Config.UseFOV,
    Callback = function(value)
        Config.UseFOV = value
    end
})

UIRefs.Sliders.FOV = UI:CreateSlider(AimFovSec, {
    Text = "FOV",
    Min = 0,
    Max = 600,
    Default = Config.FOV,
    Increment = 1,
    Callback = function(value)
        Config.FOV = math.clamp(value, 0, 600)
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

UIRefs.Textboxes.AimMaxDistance = AimMaxDistanceInput

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

UIRefs.Toggles.AlwaysAim = AimAlwaysToggle

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

UIRefs.Toggles.AimOnFire = AimOnFireToggle

local AimSettingsSec = UI:CreateSection(AimPage, "AIM Settings")

UIRefs.Sliders.Smoothness = UI:CreateSlider(AimSettingsSec, {
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

do
    local ok, err = pcall(function()
        UIRefs.TargetAssistSection =
            UI:CreateSection(
                AimPage,
                "TARGET ASSIST"
            )

        UIRefs.Toggles.TargetAssist =
            UI:CreateToggle(
                UIRefs.TargetAssistSection,
                {
                    Text = "Target Assist",
                    Default = Config.TargetAssistEnabled,
                    Callback = function(value)
                        Config.TargetAssistEnabled = value == true

                        if not Config.TargetAssistEnabled then
                            ExtraFeatures.ClearTargetAssist()
                        end
                    end
                }
            )

        UIRefs.TargetAssistLabel =
            UI:CreateLabel(
                UIRefs.TargetAssistSection,
                "Target: None"
            )

        UIRefs.AimSilentSection =
            UI:CreateSection(
                AimPage,
                "AIM SILENT"
            )

        UIRefs.Toggles.AimSilent =
            UI:CreateToggle(
                UIRefs.AimSilentSection,
                {
                    Text = "AimSilent",
                    Default = Config.AimSilentEnabled,
                    Callback = function(value)
                        Config.AimSilentEnabled = value == true

                        if not Config.AimSilentEnabled then
                            ExtraFeatures.ClearAimSilent()
                        end
                    end
                }
            )

        UIRefs.AimSilentLabel =
            UI:CreateLabel(
                UIRefs.AimSilentSection,
                "Target: None"
            )

        UIRefs.HeadHitboxSection =
            UI:CreateSection(
                AimPage,
                "HEAD HITBOX"
            )

        UIRefs.Toggles.HeadHitbox =
            UI:CreateToggle(
                UIRefs.HeadHitboxSection,
                {
                    Text = "Head Hitbox",
                    Default = Config.HeadHitboxEnabled,
                    Callback = function(value)
                        ExtraFeatures.SetHeadHitboxEnabled(value)
                    end
                }
            )

        UIRefs.Sliders.HeadHitboxSize =
            UI:CreateSlider(
                UIRefs.HeadHitboxSection,
                {
                    Text = "Head Size",
                    Min = 0,
                    Max = 10,
                    Default = Config.HeadHitboxSize,
                    Increment = 1,
                    EditableValue = true,
                    AllowTextInputBeyondRange = false,
                    Callback = function(value)
                        Config.HeadHitboxSize =
                            math.clamp(
                                tonumber(value) or 0,
                                0,
                                10
                            )

                        if Config.HeadHitboxSize <= 0 then
                            ExtraFeatures.RestoreAllHeadHitboxes()
                        elseif Config.HeadHitboxEnabled then
                            ExtraFeatures.UpdateHeadHitboxes(0, true)
                        end
                    end
                }
            )

    end)

    if not ok then
        warn("[Hood Rivals] AIM extra UI skipped: " .. tostring(err))
    end
end

-- Telekill state is kept in one table so the existing top-level local budget
-- is not expanded by a collection of separate helper locals.
local Telekill = {
    CurrentTarget = nil,
    OrbitAngle = 0,
    OrbitSpeed = math.rad(135),

    -- Telekill attacks through the developer-owned combat bridge instead of
    -- synthesizing MouseButton1 input, so normal user clicks remain untouched.
    AutoFireAccumulator = 0,
    AutoFireInterval = 0.08,

    -- Ctrl + 1 + 2 toggles Telekill as one chord.
    -- Target filters remain controlled only by the Target checklist UI.
}

function Telekill.EnsureAtLeastOneTarget()
    if type(Config.TelekillTargets) ~= "table" then
        Config.TelekillTargets = {
            Enemy = true,
            Team = false,
            NPC = false
        }
    end

    if Config.TelekillTargets.Enemy ~= true
        and Config.TelekillTargets.Team ~= true
        and Config.TelekillTargets.NPC ~= true
    then
        Config.TelekillTargets.Enemy = true
    end
end

function Telekill.GetTargetSummary()
    Telekill.EnsureAtLeastOneTarget()

    local labels = {}

    if Config.TelekillTargets.Enemy == true then
        table.insert(labels, "Enemy")
    end
    if Config.TelekillTargets.Team == true then
        table.insert(labels, "Aim Team")
    end
    if Config.TelekillTargets.NPC == true then
        table.insert(labels, "Aim NPC")
    end

    return #labels > 0
        and table.concat(labels, " + ")
        or "None"
end

function Telekill.RefreshTargetUI()
    Telekill.EnsureAtLeastOneTarget()

    if UIRefs.TelekillTargetButton then
        local arrow =
            UIRefs.TelekillTargetPanel
            and UIRefs.TelekillTargetPanel.Visible
            and " ▲"
            or " ▼"

        UIRefs.TelekillTargetButton.Text =
            "Target: " .. Telekill.GetTargetSummary() .. arrow
    end

    if UIRefs.TelekillSwitchKeyBox then
        UIRefs.TelekillSwitchKeyBox.Text =
            "Switch Target Key: "
            .. tostring(Config.TelekillSwitchKey.Name)
    end
end

function Telekill.ToggleTargetFilter(filterName)
    if filterName ~= "Enemy"
        and filterName ~= "Team"
        and filterName ~= "NPC"
    then
        return false
    end

    Telekill.EnsureAtLeastOneTarget()

    local current =
        Config.TelekillTargets[filterName] == true

    Config.TelekillTargets[filterName] = not current
    Telekill.EnsureAtLeastOneTarget()

    if UIRefs.Toggles.TelekillTargetEnemy then
        UIRefs.Toggles.TelekillTargetEnemy.Set(
            Config.TelekillTargets.Enemy == true,
            true
        )
    end

    if UIRefs.Toggles.TelekillTargetTeam then
        UIRefs.Toggles.TelekillTargetTeam.Set(
            Config.TelekillTargets.Team == true,
            true
        )
    end

    if UIRefs.Toggles.TelekillTargetNPC then
        UIRefs.Toggles.TelekillTargetNPC.Set(
            Config.TelekillTargets.NPC == true,
            true
        )
    end

    Telekill.CurrentTarget = nil
    Telekill.OrbitAngle = 0
    Telekill.AutoFireAccumulator = 0
    Telekill.RefreshTargetUI()

    return true
end

-- =========================================================
-- TELEKILL
-- Added directly to the existing AIM tab.
-- Uses the existing UI component engine only.
-- =========================================================
local TelekillSec = UI:CreateSection(AimPage, "TELEKILL")

UIRefs.Toggles.TelekillEnabled = UI:CreateToggle(TelekillSec, {
    Text = "Telekill",
    Default = Config.TelekillEnabled,
    Callback = function(value)
        Config.TelekillEnabled = value

        if not value then
            Telekill.CurrentTarget = nil
            Telekill.OrbitAngle = 0
            Telekill.AutoFireAccumulator = 0
        end
    end
})

UIRefs.TelekillTargetButton = UI:CreateButton(
    TelekillSec,
    "Target: " .. Telekill.GetTargetSummary() .. " ▼",
    function()
        if UIRefs.TelekillTargetPanel then
            UIRefs.TelekillTargetPanel.Visible =
                not UIRefs.TelekillTargetPanel.Visible
        end

        Telekill.RefreshTargetUI()
    end
)

UIRefs.TelekillTargetPanel =
    UI:CreateSection(TelekillSec, "TARGET FILTERS")
UIRefs.TelekillTargetPanel.Visible = false

UIRefs.Toggles.TelekillTargetEnemy =
    UI:CreateToggle(
        UIRefs.TelekillTargetPanel,
        {
            Text = "Enemy",
            Default = Config.TelekillTargets.Enemy == true,
            Callback = function(value)
                Config.TelekillTargets.Enemy = value == true
                Telekill.EnsureAtLeastOneTarget()

                if UIRefs.Toggles.TelekillTargetEnemy
                    and Config.TelekillTargets.Enemy ~= value
                then
                    UIRefs.Toggles.TelekillTargetEnemy.Set(
                        Config.TelekillTargets.Enemy,
                        true
                    )
                end

                if UIRefs.Toggles.TelekillTargetTeam then
                    UIRefs.Toggles.TelekillTargetTeam.Set(
                        Config.TelekillTargets.Team == true,
                        true
                    )
                end

                if UIRefs.Toggles.TelekillTargetNPC then
                    UIRefs.Toggles.TelekillTargetNPC.Set(
                        Config.TelekillTargets.NPC == true,
                        true
                    )
                end

                Telekill.CurrentTarget = nil
                Telekill.OrbitAngle = 0
                Telekill.AutoFireAccumulator = 0
                Telekill.RefreshTargetUI()
            end
        }
    )

UIRefs.Toggles.TelekillTargetTeam =
    UI:CreateToggle(
        UIRefs.TelekillTargetPanel,
        {
            Text = "Aim Team",
            Default = Config.TelekillTargets.Team == true,
            Callback = function(value)
                Config.TelekillTargets.Team = value == true
                Telekill.EnsureAtLeastOneTarget()

                if UIRefs.Toggles.TelekillTargetTeam
                    and Config.TelekillTargets.Team ~= value
                then
                    UIRefs.Toggles.TelekillTargetTeam.Set(
                        Config.TelekillTargets.Team,
                        true
                    )
                end

                if UIRefs.Toggles.TelekillTargetEnemy then
                    UIRefs.Toggles.TelekillTargetEnemy.Set(
                        Config.TelekillTargets.Enemy == true,
                        true
                    )
                end

                if UIRefs.Toggles.TelekillTargetNPC then
                    UIRefs.Toggles.TelekillTargetNPC.Set(
                        Config.TelekillTargets.NPC == true,
                        true
                    )
                end

                Telekill.CurrentTarget = nil
                Telekill.OrbitAngle = 0
                Telekill.AutoFireAccumulator = 0
                Telekill.RefreshTargetUI()
            end
        }
    )

UIRefs.Toggles.TelekillTargetNPC =
    UI:CreateToggle(
        UIRefs.TelekillTargetPanel,
        {
            Text = "Aim NPC",
            Default = Config.TelekillTargets.NPC == true,
            Callback = function(value)
                Config.TelekillTargets.NPC = value == true
                Telekill.EnsureAtLeastOneTarget()

                if UIRefs.Toggles.TelekillTargetNPC
                    and Config.TelekillTargets.NPC ~= value
                then
                    UIRefs.Toggles.TelekillTargetNPC.Set(
                        Config.TelekillTargets.NPC,
                        true
                    )
                end

                if UIRefs.Toggles.TelekillTargetEnemy then
                    UIRefs.Toggles.TelekillTargetEnemy.Set(
                        Config.TelekillTargets.Enemy == true,
                        true
                    )
                end

                if UIRefs.Toggles.TelekillTargetTeam then
                    UIRefs.Toggles.TelekillTargetTeam.Set(
                        Config.TelekillTargets.Team == true,
                        true
                    )
                end

                Telekill.CurrentTarget = nil
                Telekill.OrbitAngle = 0
                Telekill.AutoFireAccumulator = 0
                Telekill.RefreshTargetUI()
            end
        }
    )

UI:CreateLabel(
    TelekillSec,
    "Quick Targets: [1] Enemy   [2] Aim Team   [3] Aim NPC"
)

UIRefs.TelekillSwitchKeyBox = Instance.new("TextButton")
UIRefs.TelekillSwitchKeyBox.Name = "TelekillSwitchKeyBox"
UIRefs.TelekillSwitchKeyBox.Size = UDim2.new(1, 0, 0, 30)
UIRefs.TelekillSwitchKeyBox.Text =
    "Switch Target Key: " .. Config.TelekillSwitchKey.Name
UIRefs.TelekillSwitchKeyBox.Parent = TelekillSec
ExtraFeatures.StyleKeyButton(UIRefs.TelekillSwitchKeyBox)

AddConnection(
    UIRefs.TelekillSwitchKeyBox.MouseButton1Click:Connect(function()
        OtherSystem.BeginKeybindCapture(
            UIRefs.TelekillSwitchKeyBox,
            "TelekillSwitch"
        )
    end)
)

UIRefs.TelekillDistanceModeButton = UI:CreateButton(
    TelekillSec,
    "Distance: " .. tostring(Config.TelekillDistanceMode),
    function()
        if Config.TelekillDistanceMode == "Nearest" then
            Config.TelekillDistanceMode = "Farthest"
        else
            Config.TelekillDistanceMode = "Nearest"
        end

        Telekill.CurrentTarget = nil
        UIRefs.TelekillDistanceModeButton.Text =
            "Distance: " .. tostring(Config.TelekillDistanceMode)
    end
)

UIRefs.Sliders.TelekillDistance = UI:CreateSlider(TelekillSec, {
    Text = "Tele Distance",
    Min = 1,
    Max = 20,
    Default = Config.TelekillDistance,
    Increment = 1,
    EditableValue = true,
    AllowTextInputBeyondRange = false,
    Callback = function(value)
        if type(value) == "number"
            and value == value
            and value ~= math.huge
            and value ~= -math.huge
        then
            Config.TelekillDistance = math.clamp(value, 1, 20)
        end
    end
})

-- Tab 3: ESP
-- Đúng một tab ESP trong Sidebar, page chỉ tạo một lần.
-- Click ESP sẽ gọi PageManager:ShowPage("ESP") và ẩn các page khác.
local ESPPage = PageManager:AddPage("ESP")

-- Boot-safe: show the core default page immediately.
pcall(function()
    PageManager:ShowPage(Config.StartPage, true)
end)

local ESPMainSec = UI:CreateSection(ESPPage, "ESP Main")

UIRefs.Toggles.Enabled = UI:CreateToggle(ESPMainSec, {
    Text = "ESP Enable",
    Default = Config.Enabled,
    Callback = function(v)
        Config.Enabled = v
    end
})

UIRefs.Toggles.ShowEnemies = UI:CreateToggle(ESPMainSec, {
    Text = "ESP Enemy",
    Default = Config.ShowEnemies,
    Callback = function(v)
        Config.ShowEnemies = v
    end
})

UIRefs.Toggles.ShowTeammates = UI:CreateToggle(ESPMainSec, {
    Text = "ESP Team",
    Default = Config.ShowTeammates,
    Callback = function(v)
        Config.ShowTeammates = v
    end
})

local ESPVisualsSec = UI:CreateSection(ESPPage, "ESP Visuals")

UIRefs.Toggles.ShowName = UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Name",
    Default = Config.ShowName,
    Callback = function(v)
        Config.ShowName = v
    end
})

UIRefs.Toggles.ShowBox = UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Box",
    Default = Config.ShowBox,
    Callback = function(v)
        Config.ShowBox = v
        if not v then
            NPCSystem.HideESPBoxes()
        end
    end
})

UIRefs.Toggles.ShowTracer = UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Tracer",
    Default = Config.ShowTracer,
    Callback = function(v)
        Config.ShowTracer = v
    end
})

UIRefs.Toggles.ShowSkeleton = UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Skeleton",
    Default = Config.ShowSkeleton,
    Callback = function(v)
        Config.ShowSkeleton = v
    end
})

UIRefs.Toggles.ShowHealth = UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Health",
    Default = Config.ShowHealth,
    Callback = function(v)
        Config.ShowHealth = v
    end
})

UIRefs.Toggles.ShowDistance = UI:CreateToggle(ESPVisualsSec, {
    Text = "ESP Distance",
    Default = Config.ShowDistance,
    Callback = function(v)
        Config.ShowDistance = v
    end
})

UIRefs.Toggles.ESPHighlightEnabled = UI:CreateToggle(ESPVisualsSec, {
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

UIRefs.Textboxes.MaxDistance = ESPDistanceInput

-- =========================================================
-- TAB: NPC
-- Uses the existing PageManager/UI component system only.
-- =========================================================
PageManager:AddPage("NPC")

UIRefs.Toggles.ShowNPC = UI:CreateToggle(
    UI:CreateSection(GUIState.Pages["NPC"], "NPC"),
    {
        Text = "ESP NPC",
        Default = Config.ShowNPC,
        Callback = function(v)
            Config.ShowNPC = v
            if not v then
                NPCSystem.CleanupNPCESP()
            end
        end
    }
)

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

-- =========================================================
-- NPC TARGET REGISTRY / DETECTION
-- =========================================================
-- NPCs are stored as Model -> state entries.  No per-NPC render loop is used.
-- One optional Died connection per tracked NPC is used only for immediate
-- registry cleanup; all aiming/ESP updates still run through the existing
-- shared render stages.
function NPCSystem.IsNPCModel(target)
    return
        typeof(target) == "Instance"
        and target:IsA("Model")
        and target:IsDescendantOf(Workspace)
        and ExtraFeatures.V8.ResolvePlayerModel(target) == nil
end

function NPCSystem.GetHumanoid(model)
    if not model or not model:IsA("Model") then
        return nil
    end

    return model:FindFirstChildOfClass("Humanoid")
end

function NPCSystem.GetTargetPart(model)
    if not model or not model:IsA("Model") then
        return nil
    end

    return model:FindFirstChild("Head")
        or model:FindFirstChild("HumanoidRootPart")
end

function NPCSystem.IsValidNPC(model)
    if not NPCSystem.IsNPCModel(model) then
        return false
    end

    local humanoid = NPCSystem.GetHumanoid(model)
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    return NPCSystem.GetTargetPart(model) ~= nil
end

function NPCSystem.Unregister(model)
    local state = NPCSystem.ValidNPCs[model]

    if state and state.DiedConnection then
        pcall(function()
            state.DiedConnection:Disconnect()
        end)
    end

    NPCSystem.ValidNPCs[model] = nil
end

function NPCSystem.Register(model)
    if not NPCSystem.IsValidNPC(model) then
        NPCSystem.Unregister(model)
        return false
    end

    if NPCSystem.ValidNPCs[model] then
        return true
    end

    local humanoid = NPCSystem.GetHumanoid(model)
    if not humanoid then
        return false
    end

    local diedConnection
    diedConnection = humanoid.Died:Connect(function()
        NPCSystem.Unregister(model)
    end)

    NPCSystem.ValidNPCs[model] = {
        Humanoid = humanoid,
        DiedConnection = diedConnection
    }

    return true
end

function NPCSystem.RegisterCandidate(instance)
    if not instance or typeof(instance) ~= "Instance" then
        return
    end

    local model = nil

    if instance:IsA("Model") then
        model = instance
    else
        model = instance:FindFirstAncestorOfClass("Model")
    end

    if model then
        NPCSystem.Register(model)
    end
end

function NPCSystem.Refresh()
    local stale = {}

    for model in pairs(NPCSystem.ValidNPCs) do
        if not NPCSystem.IsValidNPC(model) then
            table.insert(stale, model)
        end
    end

    for _, model in ipairs(stale) do
        NPCSystem.Unregister(model)
    end

    -- One initial/event-driven scan.  It is never run every frame.
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("Model") and NPCSystem.IsValidNPC(instance) then
            NPCSystem.Register(instance)
        end
    end
end

function NPCSystem.Initialize()
    if NPCSystem.Initialized then
        return
    end

    NPCSystem.Initialized = true

    AddConnection(
        Workspace.DescendantAdded:Connect(function(descendant)
            NPCSystem.RegisterCandidate(descendant)
        end)
    )

    AddConnection(
        Workspace.DescendantRemoving:Connect(function(descendant)
            if typeof(descendant) ~= "Instance" then
                return
            end

            if descendant:IsA("Model") and NPCSystem.ValidNPCs[descendant] then
                NPCSystem.Unregister(descendant)
                return
            end

            local model = descendant:FindFirstAncestorOfClass("Model")
            if
                model
                and NPCSystem.ValidNPCs[model]
                and not NPCSystem.IsValidNPC(model)
            then
                NPCSystem.Unregister(model)
            end
        end)
    )

    -- Keep GUI initialization ahead of the workspace-wide initial scan.
    task.defer(function()
        pcall(function()
            NPCSystem.Refresh()
        end)
    end)
end

function NPCSystem.IsPlayer(target)
    return
        typeof(target) == "Instance"
        and target:IsA("Player")
end

function NPCSystem.GetCharacter(target)
    if NPCSystem.IsNPCModel(target) then
        return target
    end

    if NPCSystem.IsPlayer(target) then
        return ExtraFeatures.V8.Character(target)
    end

    return nil
end

function NPCSystem.GetPredictedPosition(model, targetPart)
    if
        not model
        or not model:IsA("Model")
        or not targetPart
        or not targetPart.Parent
    then
        return nil
    end

    local root = model:FindFirstChild("HumanoidRootPart")
    if not root then
        return targetPart.Position
    end

    -- Preserve the supplied NPC source logic: root velocity prediction +
    -- the current target-part offset from the root.
    local velocity = root.Velocity
    local predictionTime = NPCSystem.NPCPredictionTime
    local predictedRoot = root.Position + velocity * predictionTime
    local partOffset = targetPart.Position - root.Position

    return predictedRoot + partOffset
end

function NPCSystem.GetTargetWorldPosition(target, targetPart)
    if NPCSystem.IsNPCModel(target) then
        return
            NPCSystem.GetPredictedPosition(
                target,
                targetPart
            )
    end

    return targetPart and targetPart.Position or nil
end

-- ---------------------------------------------------------
-- Robust Player Team Classification
-- ---------------------------------------------------------
function NPCSystem.GetTeamToken(player)
    return ExtraFeatures.V8.TeamToken(player)
end

function NPCSystem.ClassifyPlayer(player)
    if not NPCSystem.IsPlayer(player) or player == LocalPlayer then
        return "Enemy"
    end

    local localType, localValue =
        NPCSystem.GetTeamToken(LocalPlayer)

    local targetType, targetValue =
        NPCSystem.GetTeamToken(player)

    -- Teammate is only asserted when BOTH sides expose comparable team data.
    -- Unknown/no-team games therefore remain enemy-eligible instead of
    -- incorrectly classifying everyone as a teammate.
    if
        localType
        and targetType
        and localType == targetType
    then
        if localValue == targetValue then
            return "Teammate"
        end

        return "Enemy"
    end

    return "Enemy"
end

-- ---------------------------------------------------------
-- Generic Aim-part helpers
-- ---------------------------------------------------------
local function GetAimPart(target)
    local character = NPCSystem.GetCharacter(target)
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
        or character:FindFirstChild("Head")
end

local function GetAimRoot(target)
    local character = NPCSystem.GetCharacter(target)
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
    local character = NPCSystem.GetCharacter(target)
    local humanoid =
        character and character:FindFirstChildOfClass("Humanoid")

    return humanoid ~= nil and humanoid.Health > 0
end

local function PassesAimTeamCheck(target)
    -- Team Check is strictly a PLAYER rule.  NPCs never become teammates
    -- because they are Models and do not expose Player.Team.
    if NPCSystem.IsNPCModel(target) then
        return true
    end

    if not Config.TeamCheck then
        return true
    end

    return NPCSystem.ClassifyPlayer(target) ~= "Teammate"
end

local function PassesVisibility(targetPart, worldPosition)
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
    local targetPosition =
        worldPosition
        or targetPart.Position
    local direction = targetPosition - origin

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

local function GetScreenDistance(targetPart, camera, worldPosition)
    local position =
        worldPosition
        or (targetPart and targetPart.Position)

    if not position then
        return math.huge, false, nil
    end

    local screenPosition, onScreen =
        camera:WorldToViewportPoint(position)

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
-- It accepts both Player and NPC Model targets and can also be reused by
-- non-camera AIM helpers without creating a second AIM engine.
local function IsValidTarget(target, options)
    if not Config.AimEnabled
        and not (options and options.AllowWhenAimDisabled == true)
    then
        return false
    end

    if not target or target == LocalPlayer then
        return false
    end

    local isPlayer = NPCSystem.IsPlayer(target)
    local isNPC = NPCSystem.IsNPCModel(target)

    if not isPlayer and not isNPC then
        return false
    end

    if isPlayer and not target:IsDescendantOf(Players) then
        return false
    end

    local allowNPC = options and options.AllowNPC
    if allowNPC == nil then
        allowNPC = Config.AimNPC
    end

    if isNPC and not allowNPC then
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

    local targetWorldPosition =
        NPCSystem.GetTargetWorldPosition(
            target,
            targetPart
        )

    local requireVisibility = options and options.RequireVisibility
    if requireVisibility == nil then
        requireVisibility = true
    end

    if requireVisibility
        and not PassesVisibility(
            targetPart,
            targetWorldPosition
        )
    then
        return false
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return false
    end

    local screenDistance, onScreen =
        GetScreenDistance(
            targetPart,
            camera,
            targetWorldPosition
        )

    if screenDistance == math.huge then
        return false
    end

    local requireFOV = options and options.RequireFOV
    if requireFOV == nil then
        requireFOV = Config.UseFOV
    end

    if requireFOV then
        if not onScreen then
            return false
        end

        if screenDistance > Config.FOV then
            return false
        end
    end

    return true
end

local function GetBestTarget(options)
    local camera = Workspace.CurrentCamera

    if not camera
        or (
            not Config.AimEnabled
            and not (options and options.AllowWhenAimDisabled == true)
        )
    then
        return nil, nil
    end

    local requireFOV = options and options.RequireFOV
    if requireFOV == nil then
        requireFOV = Config.UseFOV
    end

    local allowNPC = options and options.AllowNPC
    if allowNPC == nil then
        allowNPC = Config.AimNPC
    end

    local bestTarget = nil
    local bestAimPart = nil
    local bestScreenDistance = math.huge

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer
            and IsValidTarget(target, options)
        then
            local targetPart = GetAimPart(target)

            if targetPart then
                local screenDistance, onScreen =
                    GetScreenDistance(
                        targetPart,
                        camera,
                        targetPart.Position
                    )

                if screenDistance < math.huge
                    and ((not requireFOV) or onScreen)
                    and ExtraFeatures.V8.BetterAim(target, screenDistance, targetPart, bestTarget, bestAimPart, bestScreenDistance)
                then
                    bestScreenDistance = screenDistance
                    bestTarget = target
                    bestAimPart = targetPart
                end
            end
        end
    end

    if allowNPC then
        for npc in pairs(NPCSystem.ValidNPCs) do
            if IsValidTarget(npc, options) then
                local targetPart = GetAimPart(npc)

                if targetPart then
                    local predictedPosition =
                        NPCSystem.GetTargetWorldPosition(
                            npc,
                            targetPart
                        )

                    local screenDistance, onScreen =
                        GetScreenDistance(
                            targetPart,
                            camera,
                            predictedPosition
                        )

                    if screenDistance < math.huge
                        and ((not requireFOV) or onScreen)
                        and ExtraFeatures.V8.BetterAim(npc, screenDistance, targetPart, bestTarget, bestAimPart, bestScreenDistance)
                    then
                        bestScreenDistance = screenDistance
                        bestTarget = npc
                        bestAimPart = targetPart
                    end
                end
            end
        end
    end

    return bestTarget, bestAimPart
end


function ExtraFeatures.UpdateTargetAssist()
    if not Config.TargetAssistEnabled
        or not Config.AimEnabled
        or not Config.UseFOV
    then
        ExtraFeatures.ClearTargetAssist()
        return
    end

    local target = GetBestTarget()
    ExtraFeatures.TargetAssist.CurrentTarget = target

    if UIRefs.TargetAssistLabel
        and UIRefs.TargetAssistLabel.Parent
    then
        if target then
            UIRefs.TargetAssistLabel.Text =
                "Target: " .. tostring(target.Name or "Unknown")
        else
            UIRefs.TargetAssistLabel.Text = "Target: None"
        end
    end
end

function ExtraFeatures.UpdateAimSilent()
    if not Config.AimSilentEnabled
        or not Config.UseFOV
    then
        ExtraFeatures.ClearAimSilent()
        return
    end

    local target, targetPart =
        GetBestTarget(
            ExtraFeatures.AimSilent.TargetOptions
        )

    ExtraFeatures.AimSilent.CurrentTarget = target
    ExtraFeatures.AimSilent.CurrentPart = targetPart
    FOVCircleStroke.Thickness = target and 3 or 2

    if UIRefs.AimSilentLabel
        and UIRefs.AimSilentLabel.Parent
    then
        if target then
            UIRefs.AimSilentLabel.Text =
                "Target: " .. tostring(target.Name or "Unknown")
        else
            UIRefs.AimSilentLabel.Text = "Target: None"
        end
    end
end


-- =========================================================
-- FUNCTION 1 — SAFE CAMERA / TARGET VISUAL HELPERS
-- Reuses the existing input + unified render lifecycle. Drone Strike and
-- Magic Silent uses the optional developer-owned server combat bridge for validated damage.
-- =========================================================
function ExtraFeatures.EnsureFunction1Marker()
    local system = ExtraFeatures.Function1

    if system.Marker and system.Marker.Parent then
        return system.Marker
    end

    local marker = Instance.new("Frame")
    marker.Name = "Function1TargetMarker"
    marker.AnchorPoint = Vector2.new(0.5, 0.5)
    marker.Size = UDim2.fromOffset(12, 12)
    marker.BackgroundColor3 = Config.AccentColor
    marker.BackgroundTransparency = 0.08
    marker.BorderSizePixel = 0
    marker.Visible = false
    marker.Active = false
    marker.ZIndex = 85
    marker.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = marker

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.15
    stroke.Parent = marker

    local text = Instance.new("TextLabel")
    text.Name = "TargetText"
    text.Size = UDim2.fromOffset(150, 18)
    text.Position = UDim2.new(1, 7, 0.5, -9)
    text.BackgroundTransparency = 1
    text.TextColor3 = Config.TextColor
    text.TextStrokeTransparency = 0.45
    text.TextSize = 10
    text.Font = Enum.Font.GothamBold
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Text = ""
    text.Active = false
    text.ZIndex = 86
    text.Parent = marker

    system.Marker = marker
    system.MarkerText = text
    return marker
end

function ExtraFeatures.HideFunction1Marker()
    local system = ExtraFeatures.Function1
    if system.Marker and system.Marker.Parent then
        system.Marker.Visible = false
    end
end

function ExtraFeatures.ShowSilentShotFeedback()
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local targetPart = nil
    if Config.AimSilentEnabled
        and ExtraFeatures.AimSilent.CurrentPart
        and ExtraFeatures.AimSilent.CurrentPart.Parent
    then
        targetPart = ExtraFeatures.AimSilent.CurrentPart
    elseif Config.MagicSilentEnabled
        and ExtraFeatures.Function1.MagicSilent.Target
    then
        targetPart = ExtraFeatures.GetFunction1PlayerPart(
            ExtraFeatures.Function1.MagicSilent.Target
        )
    end

    if not targetPart then
        return
    end

    local point, onScreen = camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen or point.Z <= 0 then
        return
    end

    local scale = math.max(UIScaleObj.Scale, 0.01)
    local startPoint = Vector2.new(
        (camera.ViewportSize.X * 0.5) / scale,
        (camera.ViewportSize.Y * 0.5) / scale
    )
    local endPoint = Vector2.new(point.X / scale, point.Y / scale)
    local delta = endPoint - startPoint
    local length = delta.Magnitude

    if length <= 1 then
        return
    end

    local tracer = Instance.new("Frame")
    tracer.Name = "SilentShotFeedback"
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.Size = UDim2.fromOffset(length, 2)
    tracer.Position = UDim2.fromOffset(
        (startPoint.X + endPoint.X) * 0.5,
        (startPoint.Y + endPoint.Y) * 0.5
    )
    tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    tracer.BackgroundColor3 = Config.AccentColor
    tracer.BackgroundTransparency = 0.15
    tracer.BorderSizePixel = 0
    tracer.Active = false
    tracer.ZIndex = 84
    tracer.Parent = ScreenGui

    task.delay(0.16, function()
        if tracer and tracer.Parent then
            tracer:Destroy()
        end
    end)
end

function ExtraFeatures.GetFunction1PlayerPart(target)
    if not target or target == LocalPlayer then
        return nil
    end

    local character = NPCSystem.GetCharacter(target)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then
        return nil
    end

    if Config.TeamCheck and NPCSystem.ClassifyPlayer(target) == "Teammate" then
        return nil
    end

    return character:FindFirstChild("Head")
        or character:FindFirstChild("HumanoidRootPart")
end

function ExtraFeatures.FindFunction1VisualTarget(
    anchorPoint,
    requireFOV,
    useAimMaxDistance
)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local bestTarget = nil
    local bestDistance = math.huge

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer then
            local part = ExtraFeatures.GetFunction1PlayerPart(target)

            if part then
                local passesWorldDistance = true

                if useAimMaxDistance then
                    local character = NPCSystem.GetCharacter(target)
                    local targetRoot =
                        character and (
                            character:FindFirstChild("HumanoidRootPart")
                            or character.PrimaryPart
                            or character:FindFirstChild("UpperTorso")
                            or character:FindFirstChild("Torso")
                            or character:FindFirstChild("Head")
                        )

                    passesWorldDistance =
                        targetRoot ~= nil
                        and GetAimWorldDistance(targetRoot)
                            <= Config.AimMaxDistance
                end

                if passesWorldDistance then
                    local point, onScreen =
                        camera:WorldToViewportPoint(part.Position)

                    if point.Z > 0 and onScreen then
                        local distance = (
                            Vector2.new(point.X, point.Y) - anchorPoint
                        ).Magnitude

                        if (not requireFOV or distance <= Config.FOV)
                            and distance < bestDistance
                        then
                            bestDistance = distance
                            bestTarget = target
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

function ExtraFeatures.RenderFunction1Marker()
    local system = ExtraFeatures.Function1
    local target = nil
    local prefix = nil

    local part = nil

    if system.DroneStrike.Active and system.DroneStrike.Target then
        target = system.DroneStrike.Target
        prefix = "Drone"
        part = ExtraFeatures.GetFunction1PlayerPart(target)
    elseif Config.AimSilentEnabled
        and ExtraFeatures.AimSilent.CurrentTarget
        and ExtraFeatures.AimSilent.CurrentPart
    then
        target = ExtraFeatures.AimSilent.CurrentTarget
        prefix = "AimSilent"
        part = ExtraFeatures.AimSilent.CurrentPart
    elseif Config.MagicSilentEnabled and system.MagicSilent.Target then
        target = system.MagicSilent.Target
        prefix = "Magic"
        part = ExtraFeatures.GetFunction1PlayerPart(target)
    end

    local camera = Workspace.CurrentCamera

    if not part or not camera then
        ExtraFeatures.HideFunction1Marker()
        return
    end

    local point, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen or point.Z <= 0 then
        ExtraFeatures.HideFunction1Marker()
        return
    end

    local marker = ExtraFeatures.EnsureFunction1Marker()
    local uiScale = math.max(UIScaleObj.Scale, 0.01)
    marker.Position = UDim2.fromOffset(
        point.X / uiScale,
        point.Y / uiScale
    )
    marker.Visible = true

    if system.MarkerText and system.MarkerText.Parent then
        system.MarkerText.Text =
            tostring(prefix or "Target")
            .. ": "
            .. tostring(target.Name or "Unknown")
    end
end

function ExtraFeatures.SetDroneStrikeActive(enabled)
    local state = ExtraFeatures.Function1.DroneStrike
    enabled = enabled == true

    if state.Active == enabled then
        return true
    end

    local camera = Workspace.CurrentCamera

    if enabled then
        if not camera then
            return false
        end

        state.Original = {
            CameraType = camera.CameraType,
            CameraSubject = camera.CameraSubject,
            CFrame = camera.CFrame,
            MouseBehavior = UserInputService.MouseBehavior,
            MouseIconEnabled = UserInputService.MouseIconEnabled
        }

        state.CFrame = camera.CFrame
        local pitch, yaw = camera.CFrame:ToOrientation()
        state.Pitch = pitch
        state.Yaw = yaw
        state.Target = nil
        state.TargetAccumulator = 0
        state.Active = true

        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = state.CFrame

        if UIRefs.DroneStrikeStatus then
            UIRefs.DroneStrikeStatus.Text = "Drone Strike: ACTIVE"
        end

        return true
    end

    state.Active = false
    state.Target = nil
    state.TargetAccumulator = 0

    if camera and state.Original then
        pcall(function()
            camera.CameraType = state.Original.CameraType

            if state.Original.CameraSubject
                and state.Original.CameraSubject.Parent
            then
                camera.CameraSubject = state.Original.CameraSubject
            else
                local character = LocalPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    camera.CameraSubject = humanoid
                end
            end

            camera.CFrame = state.Original.CFrame
        end)
    end

    if state.Original then
        pcall(function()
            UserInputService.MouseBehavior = state.Original.MouseBehavior
            UserInputService.MouseIconEnabled = state.Original.MouseIconEnabled
        end)
    end

    state.Original = nil
    state.CFrame = nil

    if UIRefs.DroneStrikeStatus then
        UIRefs.DroneStrikeStatus.Text = "Drone Strike: OFF"
    end

    ExtraFeatures.RenderFunction1Marker()
    return true
end

function ExtraFeatures.UpdateDroneStrike(dt)
    local state = ExtraFeatures.Function1.DroneStrike
    if not state.Active then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera or not state.CFrame then
        ExtraFeatures.SetDroneStrikeActive(false)
        return
    end

    camera.CameraType = Enum.CameraType.Scriptable

    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    end)

    local mouseDelta = UserInputService:GetMouseDelta()
    local sensitivity = 0.0025
    state.Yaw = state.Yaw - mouseDelta.X * sensitivity
    state.Pitch = math.clamp(
        state.Pitch - mouseDelta.Y * sensitivity,
        -1.45,
        1.45
    )

    -- FPS / Minecraft-Creative style camera rotation:
    -- yaw around world Y first, then pitch around the camera's local X axis.
    local rotation =
        CFrame.Angles(0, state.Yaw, 0)
        * CFrame.Angles(state.Pitch, 0, 0)

    -- Camera-relative freecam movement.
    -- W/S follow the FULL LookVector, so looking up/down makes the drone
    -- climb/dive naturally just like flying in Minecraft Creative.
    -- A/D strafe relative to the camera. Q/E remain world-down/world-up.
    local move = Vector3.new(0, 0, 0)

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        move = move + rotation.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        move = move - rotation.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        move = move - rotation.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        move = move + rotation.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
        move = move - Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
        move = move + Vector3.new(0, 1, 0)
    end

    local position = state.CFrame.Position
    if move.Magnitude > 0 then
        -- Normalize combined directions so diagonal flight is not faster.
        position =
            position
            + move.Unit
            * state.Speed
            * (tonumber(dt) or 0)
    end

    state.CFrame = CFrame.new(position) * rotation
    camera.CFrame = state.CFrame

    state.TargetAccumulator = state.TargetAccumulator + (tonumber(dt) or 0)
    if state.TargetAccumulator >= 0.08 then
        state.TargetAccumulator = 0
        local center = Vector2.new(
            camera.ViewportSize.X * 0.5,
            camera.ViewportSize.Y * 0.5
        )
        state.Target = ExtraFeatures.FindFunction1VisualTarget(
            center,
            Config.UseFOV == true,
            true
        )

        if UIRefs.DroneTargetLabel then
            UIRefs.DroneTargetLabel.Text = state.Target
                and ("Target: " .. tostring(state.Target.Name))
                or "Target: None"
        end
    end
end

function ExtraFeatures.UpdateMagicSilent(dt)
    local state = ExtraFeatures.Function1.MagicSilent

    if not Config.MagicSilentEnabled then
        state.Target = nil
        state.Accumulator = 0
        if UIRefs.MagicSilentStatus then
            UIRefs.MagicSilentStatus.Text = "Target: None"
        end
        return
    end

    state.Accumulator = state.Accumulator + (tonumber(dt) or 0)
    if state.Accumulator < 0.08 then
        return
    end
    state.Accumulator = 0

    local camera = Workspace.CurrentCamera
    if not camera then
        state.Target = nil
        return
    end

    local anchor = UserInputService:GetMouseLocation()
    state.Target = ExtraFeatures.FindFunction1VisualTarget(
        anchor,
        Config.UseFOV == true,
        true
    )

    if UIRefs.MagicSilentStatus then
        UIRefs.MagicSilentStatus.Text = state.Target
            and ("Target: " .. tostring(state.Target.Name))
            or "Target: None"
    end
end

function ExtraFeatures.UpdateFunction1(dt)
    pcall(function()
        ExtraFeatures.UpdateDroneStrike(dt)
    end)

    pcall(function()
        ExtraFeatures.UpdateMagicSilent(dt)
    end)

    ExtraFeatures.RenderFunction1Marker()
end

function ExtraFeatures.CleanupFunction1()
    pcall(function()
        ExtraFeatures.SetDroneStrikeActive(false)
    end)

    local system = ExtraFeatures.Function1
    system.MagicSilent.Target = nil
    system.MagicSilent.Accumulator = 0

    if system.Marker and system.Marker.Parent then
        system.Marker:Destroy()
    end

    system.Marker = nil
    system.MarkerText = nil
end

-- FUNCTION 1 is the only horizontal top tab.  It still uses the same
-- PageManager, ContentArea, GUIState and UI component engine as every page.
UIRefs.Function1Page = PageManager:AddPage(
    "FUNCTION 1",
    {Placement = "Top"}
)

UIRefs.Function1DroneSection = UI:CreateSection(
    UIRefs.Function1Page,
    "DRONE STRIKE"
)

UIRefs.DroneStrikeKeyBox = Instance.new("TextButton")
UIRefs.DroneStrikeKeyBox.Name = "DroneStrikeKeyBox"
UIRefs.DroneStrikeKeyBox.Size = UDim2.new(1, 0, 0, 30)
UIRefs.DroneStrikeKeyBox.Text =
    "Drone Strike Key: " .. Config.DroneStrikeKey.Name
UIRefs.DroneStrikeKeyBox.Parent = UIRefs.Function1DroneSection
ExtraFeatures.StyleKeyButton(UIRefs.DroneStrikeKeyBox)

AddConnection(
    UIRefs.DroneStrikeKeyBox.MouseButton1Click:Connect(function()
        OtherSystem.BeginKeybindCapture(
            UIRefs.DroneStrikeKeyBox,
            "DroneStrike"
        )
    end)
)

UIRefs.DroneStrikeStatus = UI:CreateLabel(
    UIRefs.Function1DroneSection,
    "Drone Strike: OFF"
)
UIRefs.DroneTargetLabel = UI:CreateLabel(
    UIRefs.Function1DroneSection,
    "Target: None"
)
UI:CreateLabel(
    UIRefs.Function1DroneSection,
    "W/A/S/D/Q/E move the safe freecam. Target tracking is visual only."
)

UIRefs.Function1MagicSection = UI:CreateSection(
    UIRefs.Function1Page,
    "MAGIC SILENT"
)
UIRefs.Toggles.MagicSilent = UI:CreateToggle(
    UIRefs.Function1MagicSection,
    {
        Text = "Magic Silent",
        Default = Config.MagicSilentEnabled,
        Callback = function(value)
            Config.MagicSilentEnabled = value == true
            if not Config.MagicSilentEnabled then
                ExtraFeatures.Function1.MagicSilent.Target = nil
            end
        end
    }
)
UIRefs.MagicSilentStatus = UI:CreateLabel(
    UIRefs.Function1MagicSection,
    "Target: None"
)
UI:CreateLabel(
    UIRefs.Function1MagicSection,
    "Tracks the closest valid target and shows local shot feedback without changing the camera."
)


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
            OtherSystem.ActiveFireTouches[input] = true
            TouchFireActive = true
        end
    end)
)

AddConnection(
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            OtherSystem.ActiveFireTouches[input] = nil
            TouchFireActive = next(OtherSystem.ActiveFireTouches) ~= nil
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

local function AimAtTarget(targetPart, targetWorldPosition)
    if not targetPart or not targetPart.Parent then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    -- Player targets keep the original current-part behavior.
    -- NPC targets may supply the existing prediction result.
    local targetPosition =
        targetWorldPosition
        or targetPart.Position

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
    -- Telekill ON uses the existing AIM controller only for the final
    -- camera rotation. Telekill supplies the target; AimAtTarget() remains
    -- the existing camera-aim implementation.
    if Config.TelekillEnabled then
        local telekillTarget = Telekill.CurrentTarget

        if telekillTarget and Telekill.IsValidTarget(telekillTarget) then
            local telekillHead = GetAimPart(telekillTarget)

            if telekillHead and telekillHead.Parent then
                CurrentAimTarget = telekillTarget
                AimAtTarget(telekillHead)
                return
            end
        end

        Telekill.CurrentTarget = nil
        -- No valid Telekill target: fall through to the original AIM path.
        -- This preserves the existing AIM behavior whenever Telekill cannot
        -- provide a valid target.
    end

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

    local predictedPosition = nil
    if NPCSystem.IsNPCModel(target) then
        predictedPosition =
            NPCSystem.GetTargetWorldPosition(
                target,
                currentAimPart
            )
    end

    AimAtTarget(
        currentAimPart,
        predictedPosition
    )
end

-- ---------------------------------------------------------
-- TELEKILL TARGET / TELEPORT ENGINE
-- ---------------------------------------------------------
-- Telekill reuses the existing target/character helpers where possible.
-- It does not replace GetBestTarget() or the normal AIM target path when
-- Telekill is OFF.

function Telekill.IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

function Telekill.IsValidTarget(target)
    if not target then
        return false
    end

    if NPCSystem.IsNPCModel(target) then
        return NPCSystem.IsValidNPC(target)
    end

    if not NPCSystem.IsPlayer(target)
        or target == LocalPlayer
        or not target:IsDescendantOf(Players)
    then
        return false
    end

    local character = NPCSystem.GetCharacter(target)
    local humanoid =
        character and character:FindFirstChildOfClass("Humanoid")
    local root = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("Head")
    )

    return
        character ~= nil
        and humanoid ~= nil
        and humanoid.Health > 0
        and root ~= nil
end

function Telekill.IsEnemy(target)
    return
        NPCSystem.IsPlayer(target)
        and target ~= LocalPlayer
        and NPCSystem.ClassifyPlayer(target) == "Enemy"
end

function Telekill.IsTeam(target)
    return
        NPCSystem.IsPlayer(target)
        and target ~= LocalPlayer
        and NPCSystem.ClassifyPlayer(target) == "Teammate"
end

function Telekill.IsSelectedTarget(target)
    Telekill.EnsureAtLeastOneTarget()

    if NPCSystem.IsNPCModel(target) then
        return
            Config.TelekillTargets.NPC == true
            and NPCSystem.IsValidNPC(target)
    end

    if not NPCSystem.IsPlayer(target)
        or target == LocalPlayer
    then
        return false
    end

    local classification = NPCSystem.ClassifyPlayer(target)

    if classification == "Teammate" then
        return Config.TelekillTargets.Team == true
    end

    return Config.TelekillTargets.Enemy == true
end

function Telekill.GetLocalRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("Head")
end

function Telekill.GetTargetDistance(targetRoot, localRoot)
    if not targetRoot or not localRoot then
        return math.huge
    end

    local distance =
        (localRoot.Position - targetRoot.Position).Magnitude

    if not Telekill.IsFiniteNumber(distance) then
        return math.huge
    end

    return distance
end

function Telekill.GetCandidateList()
    local localRoot = Telekill.GetLocalRoot()
    local candidates = {}

    if not localRoot then
        return candidates
    end

    local function addCandidate(target)
        if not Telekill.IsValidTarget(target)
            or not Telekill.IsSelectedTarget(target)
        then
            return
        end

        local targetRoot = GetAimRoot(target)
        local distance =
            Telekill.GetTargetDistance(targetRoot, localRoot)

        if distance < math.huge then
            table.insert(
                candidates,
                {
                    Target = target,
                    Distance = distance
                }
            )
        end
    end

    if Config.TelekillTargets.Enemy == true
        or Config.TelekillTargets.Team == true
    then
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= LocalPlayer then
                addCandidate(target)
            end
        end
    end

    if Config.TelekillTargets.NPC == true then
        for npc in pairs(NPCSystem.ValidNPCs) do
            addCandidate(npc)
        end
    end

    table.sort(
        candidates,
        function(a, b)
            if Config.TelekillDistanceMode == "Farthest" then
                return a.Distance > b.Distance
            end

            return a.Distance < b.Distance
        end
    )

    return candidates
end

function Telekill.GetBestTarget()
    if not Config.TelekillEnabled then
        return nil
    end

    local candidates = Telekill.GetCandidateList()

    return
        candidates[1]
        and candidates[1].Target
        or nil
end

function Telekill.SwitchToNextTarget()
    if not Config.TelekillEnabled then
        return false
    end

    local candidates = Telekill.GetCandidateList()

    if #candidates == 0 then
        Telekill.CurrentTarget = nil
        CurrentAimTarget = nil
        return false
    end

    local currentIndex = 0

    if Telekill.CurrentTarget then
        for index, entry in ipairs(candidates) do
            if entry.Target == Telekill.CurrentTarget then
                currentIndex = index
                break
            end
        end
    end

    local nextIndex = currentIndex + 1

    if currentIndex == 0 or nextIndex > #candidates then
        nextIndex = 1
    end

    Telekill.CurrentTarget = candidates[nextIndex].Target
    Telekill.OrbitAngle = 0
    Telekill.AutoFireAccumulator = 0
    CurrentAimTarget = Telekill.CurrentTarget

    return true
end

function Telekill.GetPosition(targetRoot, teleDistance, angle)
    if not targetRoot then
        return nil
    end

    local distance = tonumber(teleDistance) or 3

    if not Telekill.IsFiniteNumber(distance) then
        distance = 3
    end

    distance = math.clamp(distance, 1, 20)

    local orbitAngle = tonumber(angle) or 0
    local offset = Vector3.new(
        math.cos(orbitAngle) * distance,
        0.35 + math.sin(orbitAngle * 2) * 0.20,
        math.sin(orbitAngle) * distance
    )

    local candidate =
        targetRoot.Position + offset

    if not Telekill.IsFiniteNumber(candidate.X)
        or not Telekill.IsFiniteNumber(candidate.Y)
        or not Telekill.IsFiniteNumber(candidate.Z)
    then
        return nil
    end

    return candidate
end

function Telekill.Teleport(target, renderDt)
    if not target
        or not Telekill.IsValidTarget(target)
        or not Telekill.IsSelectedTarget(target)
    then
        return false
    end

    local character = LocalPlayer.Character
    local localRoot = Telekill.GetLocalRoot()
    local targetRoot = GetAimRoot(target)

    if not character or not localRoot or not targetRoot then
        return false
    end

    Telekill.OrbitAngle =
        (
            Telekill.OrbitAngle
            + (
                math.max(
                    0,
                    tonumber(renderDt) or 0
                )
                * Telekill.OrbitSpeed
            )
        )
        % (math.pi * 2)

    local destination =
        Telekill.GetPosition(
            targetRoot,
            Config.TelekillDistance,
            Telekill.OrbitAngle
        )

    if not destination then
        return false
    end

    local lookTarget = Vector3.new(
        targetRoot.Position.X,
        destination.Y,
        targetRoot.Position.Z
    )

    local destinationCFrame =
        CFrame.lookAt(
            destination,
            lookTarget
        )

    local ok = pcall(function()
        character:PivotTo(destinationCFrame)
    end)

    return ok
end

function Telekill.UpdateAutoFire(renderDt, target)
    if not Config.TelekillEnabled
        or not target
        or not Telekill.IsValidTarget(target)
        or not Telekill.IsSelectedTarget(target)
    then
        Telekill.AutoFireAccumulator = 0
        return
    end

    Telekill.AutoFireAccumulator =
        Telekill.AutoFireAccumulator
        + math.max(0, tonumber(renderDt) or 0)

    if Telekill.AutoFireAccumulator
        < Telekill.AutoFireInterval
    then
        return
    end

    Telekill.AutoFireAccumulator =
        Telekill.AutoFireAccumulator
        % Telekill.AutoFireInterval

    pcall(function()
        ExtraFeatures.RequestDeveloperCombatShot(
            "Telekill",
            target
        )
    end)
end

function Telekill.Update(renderDt)
    if not Config.TelekillEnabled then
        Telekill.CurrentTarget = nil
        Telekill.OrbitAngle = 0
        Telekill.AutoFireAccumulator = 0
        return
    end

    Telekill.EnsureAtLeastOneTarget()

    local target = Telekill.CurrentTarget

    if not target
        or not Telekill.IsValidTarget(target)
        or not Telekill.IsSelectedTarget(target)
    then
        target = Telekill.GetBestTarget()
        Telekill.CurrentTarget = target
        Telekill.OrbitAngle = 0
    end

    if not target then
        CurrentAimTarget = nil
        Telekill.AutoFireAccumulator = 0
        return
    end

    if not Telekill.Teleport(target, renderDt) then
        CurrentAimTarget = target
        Telekill.UpdateAutoFire(renderDt, target)
        return
    end

    CurrentAimTarget = target
    Telekill.UpdateAutoFire(renderDt, target)
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

-- 2D screen-space rectangle used by ESP Box.
-- It is only a GUI overlay; no Part/Highlight/physics object is created.
function NPCSystem.CreateScreenBox()
    local box = Instance.new("Frame")
    box.Name = "ESPBox"
    box.Size = UDim2.fromOffset(0, 0)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.ZIndex = 19
    box.Parent = ScreenGui

    local stroke = Instance.new("UIStroke")
    stroke.Name = "ESPBoxStroke"
    stroke.Thickness = 1.5
    stroke.Transparency = 0
    stroke.Color = Color3.fromRGB(255, 0, 0)
    stroke.Parent = box

    return box
end

local function IsFiniteESPNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function ApplyESPScreenOffset(position)
    if not position then
        return nil
    end

    local scale = math.max(UIScaleObj.Scale, 0.01)
    return Vector2.new(
        position.X / scale,
        position.Y / scale
    )
end

-- Z is applied in camera-relative WORLD space BEFORE projection.
-- X/Y are deliberately NOT applied here, preventing double application.
local function ProjectESPWorldPosition(camera, worldPosition)
    if not camera or not worldPosition then
        return nil, false, nil
    end

    local adjustedWorldPosition = worldPosition

    local projected, onScreen =
        camera:WorldToViewportPoint(adjustedWorldPosition)

    if not IsFiniteESPNumber(projected.X)
        or not IsFiniteESPNumber(projected.Y)
        or not IsFiniteESPNumber(projected.Z)
    then
        return nil, false, nil
    end

    return Vector2.new(projected.X, projected.Y), onScreen, projected.Z
end

function NPCSystem.UpdateESPBox(box, character, camera)
    if
        not box
        or not box.Parent
        or not character
        or not character.Parent
        or not camera
    then
        if box then
            box.Visible = false
        end
        return
    end

    local ok, boundsCFrame, boundsSize =
        pcall(function()
            return character:GetBoundingBox()
        end)

    if
        not ok
        or not boundsCFrame
        or not boundsSize
    then
        box.Visible = false
        return
    end

    local half = boundsSize / 2
    local corners = {
        Vector3.new(-half.X, -half.Y, -half.Z),
        Vector3.new(-half.X, -half.Y,  half.Z),
        Vector3.new(-half.X,  half.Y, -half.Z),
        Vector3.new(-half.X,  half.Y,  half.Z),
        Vector3.new( half.X, -half.Y, -half.Z),
        Vector3.new( half.X, -half.Y,  half.Z),
        Vector3.new( half.X,  half.Y, -half.Z),
        Vector3.new( half.X,  half.Y,  half.Z)
    }

    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge
    local hasFrontPoint = false

    for _, corner in ipairs(corners) do
        local worldCorner =
            (boundsCFrame * CFrame.new(corner)).Position

        local projected, _, depth =
            ProjectESPWorldPosition(
                camera,
                worldCorner
            )

        if projected and depth and depth > 0 then
            hasFrontPoint = true

            minX = math.min(minX, projected.X)
            minY = math.min(minY, projected.Y)
            maxX = math.max(maxX, projected.X)
            maxY = math.max(maxY, projected.Y)
        end
    end

    if
        not hasFrontPoint
        or not IsFiniteESPNumber(minX)
        or not IsFiniteESPNumber(minY)
        or not IsFiniteESPNumber(maxX)
        or not IsFiniteESPNumber(maxY)
    then
        box.Visible = false
        return
    end

    local viewport = camera.ViewportSize

    -- Hide only when the whole projected rectangle is outside the viewport.
    if
        maxX < 0
        or maxY < 0
        or minX > viewport.X
        or minY > viewport.Y
    then
        box.Visible = false
        return
    end

    local position =
        ApplyESPScreenOffset(
            Vector2.new(minX, minY)
        )

    local width = math.max(maxX - minX, 1)
    local height = math.max(maxY - minY, 1)

    box.Position =
        UDim2.fromOffset(
            position.X,
            position.Y
        )

    box.Size =
        UDim2.fromOffset(
            width / math.max(UIScaleObj.Scale, 0.01),
            height / math.max(UIScaleObj.Scale, 0.01)
        )

    box.Visible = true
end

function NPCSystem.HideESPBoxes()
    for _, data in pairs(espData) do
        if data.box then
            data.box.Visible = false
        end
    end
end

local function updateScreenLine(line, from, to)
    if not line or not from or not to then
        return
    end

    -- Apply screen-space X/Y exactly once to the final line.
    from = ApplyESPScreenOffset(from)
    to = ApplyESPScreenOffset(to)

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
    healthLabel.Font = Enum.Font.GothamMedium
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
    distanceLabel.Font = Enum.Font.GothamMedium
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
    if data.skeletonCharacter == character and data.skeletonDefinition == skeletonList then return end
    data.skeletonCharacter = character
    data.skeletonDefinition = skeletonList
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

    data.kind =
        NPCSystem.IsNPCModel(target)
        and "NPC"
        or "Player"

    data.character = NPCSystem.GetCharacter(target)
    data.info = createInfo()
    data.tracer = createScreenLine("ESPTracer")
    data.box = NPCSystem.CreateScreenBox()
    data.skeleton = {}

    if Config.ShowSkeleton then EnsureSkeletonLines(data, data.character) end

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

    if data.box then
        data.box:Destroy()
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

    if data.box then
        data.box.Visible = false
    end

    for _, skeleton in ipairs(data.skeleton or {}) do
        if skeleton.line then
            skeleton.line.Visible = false
        end
    end
end

function NPCSystem.CleanupNPCESP()
    for target, data in pairs(espData) do
        if data and data.kind == "NPC" then
            if data.box then
                data.box.Visible = false
            end
            destroyTargetESP(target)
        end
    end
end

local function updateTargetESP(target, camera)
    -- Every ESP element in this frame uses the same CurrentCamera snapshot.
    if not camera then
        local staleData = espData[target]
        if staleData then
            hideTargetESP(staleData)
        end
        return
    end

    local isNPC = NPCSystem.IsNPCModel(target)
    local isPlayer = NPCSystem.IsPlayer(target)

    if not isNPC and not isPlayer then
        destroyTargetESP(target)
        return
    end

    -- Resolve the CURRENT target character and CURRENT parts every frame.
    local character = NPCSystem.GetCharacter(target)
    local humanoid =
        character and
        character:FindFirstChildOfClass("Humanoid")
    local root =
        character and
        character:FindFirstChild("HumanoidRootPart")
    local head =
        character and
        character:FindFirstChild("Head")

    local displayPart = head or root

    if
        not character
        or not humanoid
        or humanoid.Health <= 0
        or not displayPart
    then
        destroyTargetESP(target)
        return
    end

    local classification = "NPC"
    local targetColor = NPCSystem.ESPColors.NPC

    if isNPC then
        classification = "NPC"

        if not Config.ShowNPC then
            destroyTargetESP(target)
            return
        end

        -- NPC is always visually distinct from Player Enemy/Teammate.
        targetColor = NPCSystem.ESPColors.NPC
    else
        classification =
            NPCSystem.ClassifyPlayer(target)

        if classification == "Teammate" then
            if not Config.ShowTeammates then
                destroyTargetESP(target)
                return
            end

            targetColor =
                NPCSystem.ESPColors.Teammate
        else
            classification = "Enemy"

            if not Config.ShowEnemies then
                destroyTargetESP(target)
                return
            end

            targetColor =
                NPCSystem.ESPColors.Enemy
        end
    end

    local data = espData[target]

    -- Respawn/rebuild: discard old character-backed ESP.
    if
        data
        and (
            data.character ~= character
            or data.kind ~= (isNPC and "NPC" or "Player")
        )
    then
        destroyTargetESP(target)
        data = nil
    end

    if not data then
        data = createTargetESP(target)
        espData[target] = data
    elseif Config.ShowSkeleton then
        EnsureSkeletonLines(data, character)
    end

    -- Distance uses CURRENT root/display-part positions.
    local myRoot =
        LocalPlayer.Character and
        (
            LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            or LocalPlayer.Character.PrimaryPart
            or LocalPlayer.Character:FindFirstChild("UpperTorso")
            or LocalPlayer.Character:FindFirstChild("Torso")
            or LocalPlayer.Character:FindFirstChild("Head")
        )

    local distance =
        myRoot
        and displayPart
        and (myRoot.Position - displayPart.Position).Magnitude
        or math.huge

    if
        distance > Config.MaxDistance
        or not Config.Enabled
    then
        hideTargetESP(data)
        return
    end

    -- Apply the same classification color to all 2D ESP visuals.
    if data.tracer then
        data.tracer.BackgroundColor3 = targetColor
    end

    if data.box then
        local boxStroke =
            data.box:FindFirstChild("ESPBoxStroke")

        if boxStroke and boxStroke:IsA("UIStroke") then
            boxStroke.Color = targetColor
        end

        if Config.ShowBox then
            NPCSystem.UpdateESPBox(
                data.box,
                character,
                camera
            )
        else
            data.box.Visible = false
        end
    end

    for _, skeleton in ipairs(data.skeleton or {}) do
        if skeleton.line then
            skeleton.line.BackgroundColor3 = targetColor
        end
    end

    -- CURRENT world positions -> the SAME camera snapshot -> projection.
    local rootScreen, rootOnScreen, rootDepth
    if root then
        rootScreen, rootOnScreen, rootDepth =
            ProjectESPWorldPosition(
                camera,
                root.Position
            )
    end

    local headScreen, headOnScreen, headDepth
    if head then
        headScreen, headOnScreen, headDepth =
            ProjectESPWorldPosition(
                camera,
                head.Position
            )
    end

    local displayScreen, displayOnScreen, displayDepth =
        ProjectESPWorldPosition(
            camera,
            displayPart.Position
        )

    -- NAME / HEALTH / DISTANCE
    local showInfo =
        Config.ShowName
        or Config.ShowHealth
        or Config.ShowDistance

    if
        showInfo
        and displayScreen
        and displayOnScreen
        and displayDepth > 0
    then
        local info = data.info

        local infoPosition =
            ApplyESPScreenOffset(
                Vector2.new(
                    displayScreen.X,
                    displayScreen.Y - 8
                )
            )

        info.Position =
            UDim2.fromOffset(
                infoPosition.X,
                infoPosition.Y
            )

        info.Visible = true

        local nameLabel = info:FindFirstChild("Name")
        local healthLabel = info:FindFirstChild("Health")
        local distanceLabel = info:FindFirstChild("Distance")

        if nameLabel then
            nameLabel.Visible = Config.ShowName

            if isNPC then
                -- NPCs intentionally use a stable generic label.
                nameLabel.Text = "NPC"
            else
                nameLabel.Text =
                    target.DisplayName
                    .. "  @"
                    .. target.Name
            end

            -- All ESP visuals use the same classification color.
            nameLabel.TextColor3 = targetColor
        end

        if healthLabel then
            healthLabel.Visible = Config.ShowHealth

            local currentHP =
                math.floor(humanoid.Health)
            local maxHP =
                math.floor(humanoid.MaxHealth)

            if maxHP <= 0 then
                maxHP = 100
            end

            if ExtraFeatures.V8.StyleHealth then
                ExtraFeatures.V8.StyleHealth(data, humanoid, targetColor)
            else
                healthLabel.Text = "HP: " .. currentHP .. " / " .. maxHP
            end
        end

        if distanceLabel then
            distanceLabel.Visible = Config.ShowDistance
            distanceLabel.Text =
                math.floor(distance)
                .. " studs"
        end
    else
        data.info.Visible = false
    end

    -- TRACER
    if
        Config.ShowTracer
        and rootScreen
        and rootOnScreen
        and rootDepth > 0
    then
        local from =
            Vector2.new(
                camera.ViewportSize.X / 2,
                camera.ViewportSize.Y - 8
            )

        local to = rootScreen

        updateScreenLine(
            data.tracer,
            from,
            to
        )
    else
        data.tracer.Visible = false
    end

    -- SKELETON R6 / R15
    if Config.ShowSkeleton then
        -- Each endpoint re-reads the CURRENT part.Position every frame.
        for _, skeleton in ipairs(data.skeleton) do
            local partA =
                character:FindFirstChild(
                    skeleton.partA
                )
            local partB =
                character:FindFirstChild(
                    skeleton.partB
                )

            if partA and partB then
                local posA, visibleA, depthA =
                    ProjectESPWorldPosition(
                        camera,
                        partA.Position
                    )

                local posB, visibleB, depthB =
                    ProjectESPWorldPosition(
                        camera,
                        partB.Position
                    )

                if
                    posA
                    and posB
                    and visibleA
                    and visibleB
                    and depthA > 0
                    and depthB > 0
                then
                    updateScreenLine(
                        skeleton.line,
                        posA,
                        posB
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

local function updateESP(camera)
    -- One CurrentCamera snapshot for the entire ESP frame.
    if not camera then
        for _, data in pairs(espData) do
            hideTargetESP(data)
        end
        return
    end

    -- Master Toggle: tắt thì không render bất kỳ module nào.
    if not Config.Enabled then
        for target in pairs(espData) do
            destroyTargetESP(target)
        end
        return
    end

    -- First remove NPC ESP entries whose models have already left the registry.
    for target, data in pairs(espData) do
        if
            data
            and data.kind == "NPC"
            and not NPCSystem.ValidNPCs[target]
        then
            destroyTargetESP(target)
        end
    end

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer then
            updateTargetESP(target, camera)
        end
    end

    -- NPC ESP uses the same renderer and same frame/camera snapshot.
    for npc in pairs(NPCSystem.ValidNPCs) do
        updateTargetESP(npc, camera)
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

    local character = target and NPCSystem.GetCharacter(target)
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
        local character = NPCSystem.GetCharacter(target)
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

    local character = NPCSystem.GetCharacter(target)
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

    -- Reuse the same robust Player classification used by the main ESP
    -- renderer, so Highlight cannot disagree with Name/Box/Skeleton/Tracer.
    local classification =
        NPCSystem.ClassifyPlayer(target)

    if classification == "Teammate" then
        if not Config.ShowTeammates then
            return false
        end
    else
        classification = "Enemy"

        if not Config.ShowEnemies then
            return false
        end
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
    -- ESP Highlight follows the existing Master ESP switch too.
    if not Config.Enabled or not Config.ESPHighlightEnabled then
        if UIRefs.Experience.HighlightWasEnabled then destroyAllESPHighlights() end
        UIRefs.Experience.HighlightWasEnabled = false
        return
    end
    UIRefs.Experience.HighlightWasEnabled = true

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer then
            local valid, character =
                IsESPHighlightTargetValid(target)

            if not valid then
                destroyESPHighlight(target)
            else
                local classification =
                    NPCSystem.ClassifyPlayer(target)

                local highlightColor =
                    classification == "Teammate"
                    and NPCSystem.ESPColors.Teammate
                    or NPCSystem.ESPColors.Enemy

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
                    data.highlight.FillColor = highlightColor
                    data.highlight.OutlineColor = highlightColor
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
    nameLabel.Font = Enum.Font.GothamMedium
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
                -- Multiple floating controls are retained; only the active follow target is exclusive.
                for otherTarget, otherData in pairs(ActiveTpButtons) do
                    if otherTarget ~= target and otherData.active then
                        otherData.active = false
                        if otherData.button and otherData.button.Parent then
                            otherData.button.Text = "TP OFF"
                            otherData.button.BackgroundColor3 = Config.DarkBg
                        end
                    end
                end
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

            if ExtraFeatures.StylePlayerButton then ExtraFeatures.StylePlayerButton(button, target) end
            button:SetAttribute("Selected", Config.Teleport.SelectedPlayer == target)
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

    if ExtraFeatures.FilterPlayers then ExtraFeatures.FilterPlayers() end
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
            local targetCharacter = NPCSystem.GetCharacter(target)
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
-- SETTINGS TAB / SAVE-LOAD / MENU PROFILES
-- Uses the existing PageManager + UI component system.
-- =========================================================

local SettingsPage = PageManager:AddPage("SETTINGS")

local SettingsStatusLabel

local CONFIG_FILE = "HoodRivals_Settings_u" .. tostring(LocalPlayer.UserId) .. "_p" .. tostring(game.PlaceId) .. ".json"

local SessionConfigBackup = nil
local CurrentGameName = "Unknown"
local CurrentPlaceId = 0

local FileAPI = {
    Available = false,
    IsFile = nil,
    ReadFile = nil,
    WriteFile = nil
}

pcall(function()
    if type(isfile) == "function" then
        FileAPI.IsFile = isfile
    end

    if type(readfile) == "function" then
        FileAPI.ReadFile = readfile
    end

    if type(writefile) == "function" then
        FileAPI.WriteFile = writefile
    end

    FileAPI.Available =
        FileAPI.ReadFile ~= nil
        and FileAPI.WriteFile ~= nil
end)

local function IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function SafeEncodeJSON(data)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if not ok or type(result) ~= "string" or result == "" then
        return nil
    end

    return result
end

local function SafeDecodeJSON(raw)
    if type(raw) ~= "string" or raw == "" then
        return nil, "empty"
    end

    local ok, result = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not ok or type(result) ~= "table" then
        return nil, "invalid"
    end

    return result
end

local function FileExists(path)
    if not FileAPI.Available then
        return false
    end

    if FileAPI.IsFile then
        local ok, result = pcall(FileAPI.IsFile, path)
        if ok then
            return result == true
        end
    end

    local ok = pcall(FileAPI.ReadFile, path)
    return ok
end

local function SafeReadFile(path)
    if not FileAPI.Available or not FileExists(path) then
        return nil, "unavailable"
    end

    local ok, result = pcall(FileAPI.ReadFile, path)
    if not ok or type(result) ~= "string" then
        return nil, "read_error"
    end

    return result
end

local function SafeWriteFile(path, data)
    if not FileAPI.Available then
        return false, "unavailable"
    end

    local ok, err = pcall(FileAPI.WriteFile, path, data)
    if not ok then
        return false, tostring(err)
    end

    return true
end

local function SetSettingsStatus(message)
    if SettingsStatusLabel then SettingsStatusLabel.Text = tostring(message or "") end
    if ExtraFeatures.Notify then ExtraFeatures.Notify(message) end
end

ExtraFeatures.SetStatus = function(message)
    SetSettingsStatus(message)
end

local function TrimString(value)
    if type(value) ~= "string" then
        return ""
    end

    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")

    if #value > 60 then
        value = value:sub(1, 60)
    end

    return value
end

-- =========================================================
-- UI EFFECTS — VIRTUAL PET / SNOWFALL / FLOATING BUBBLE
-- Uses the existing ScreenGui, MainWindow, FloatingBtn and TweenService.
-- No second ScreenGui, PageManager, render engine or input engine is created.
-- =========================================================

function ExtraFeatures.MarkUIActivity()
    local effects = ExtraFeatures.UIEffects
    if not effects then
        return
    end

    effects.VirtualPet.LastInput = os.clock()

    if effects.VirtualPet.State == "Sleep" then
        effects.VirtualPet.State = "Idle"
        if effects.VirtualPet.Fallback
            and effects.VirtualPet.Fallback.Parent
        then
            effects.VirtualPet.Fallback.Text = "🐱"
        end
    end
end

function ExtraFeatures.EnsureVirtualPet()
    local state = ExtraFeatures.UIEffects.VirtualPet

    if state.Instance and state.Instance.Parent then
        return state.Instance
    end

    local pet = Instance.new("ImageLabel")
    pet.Name = "VirtualPet"
    pet.Size = UDim2.fromOffset(30, 30)
    pet.Position = UDim2.new(0, 8, 0, 42)
    pet.BackgroundTransparency = 1
    pet.BorderSizePixel = 0
    pet.Image = state.VirtualPetImage
    pet.ScaleType = Enum.ScaleType.Fit
    pet.Active = false
    pet.Selectable = false
    pet.ZIndex = 30
    pet.Parent = MainWindow

    local fallback = Instance.new("TextLabel")
    fallback.Name = "PetFallback"
    fallback.Size = UDim2.fromScale(1, 1)
    fallback.BackgroundTransparency = 1
    fallback.Text = "🐱"
    fallback.TextColor3 = Config.TextColor
    fallback.Font = Enum.Font.GothamBold
    fallback.TextScaled = true
    fallback.Active = false
    fallback.ZIndex = 31
    fallback.Visible =
        state.VirtualPetImage == ""
        or state.VirtualPetImage == "rbxassetid://0"
    fallback.Parent = pet

    state.Instance = pet
    state.Image = pet
    state.Fallback = fallback

    return pet
end

function ExtraFeatures.StopVirtualPet()
    local state = ExtraFeatures.UIEffects.VirtualPet
    state.Enabled = false
    state.Generation = state.Generation + 1
    state.ReactionToken = (state.ReactionToken or 0) + 1
    state.Reacting = false

    if state.Tween then
        pcall(function()
            state.Tween:Cancel()
        end)
    end

    state.Tween = nil
    state.State = "Idle"

    if state.ChatBubble and state.ChatBubble.Parent then
        state.ChatBubble:Destroy()
    end

    state.ChatBubble = nil

    if state.MemeSound and state.MemeSound.Parent then
        pcall(function()
            state.MemeSound:Stop()
        end)
        state.MemeSound:Destroy()
    end

    state.MemeSound = nil

    if state.Instance and state.Instance.Parent then
        state.Instance:Destroy()
    end

    state.Instance = nil
    state.Image = nil
    state.Fallback = nil
end


function ExtraFeatures.GetVirtualPetTarget()
    local state = ExtraFeatures.UIEffects.VirtualPet
    local pet = state.Instance

    if not pet or not pet.Parent then
        return UDim2.new(0, 8, 0, 42)
    end

    local absoluteSize = MainWindow.AbsoluteSize
    local width = math.max(absoluteSize.X, 560)
    local height = math.max(absoluteSize.Y, 360)
    local petSize = 30
    local left = 6
    local right = math.max(left, width - petSize - 6)
    local top = 40
    local bottom = math.max(top, height - petSize - 6)
    local edge = math.random(1, 4)

    if edge == 1 then
        return UDim2.fromOffset(
            math.random(left, math.max(left, right - 95)),
            top
        )
    elseif edge == 2 then
        return UDim2.fromOffset(
            math.random(left, right),
            bottom
        )
    elseif edge == 3 then
        return UDim2.fromOffset(
            left,
            math.random(top, bottom)
        )
    end

    return UDim2.fromOffset(
        right,
        math.random(math.min(bottom, top + 36), bottom)
    )
end

function ExtraFeatures.StartVirtualPet()
    local effects = ExtraFeatures.UIEffects
    local state = effects.VirtualPet

    ExtraFeatures.StopVirtualPet()

    if not Config.VirtualPetEnabled then
        return
    end

    state.Enabled = true
    state.LastInput = os.clock()
    state.Reacting = false
    state.Generation = state.Generation + 1
    local generation = state.Generation
    local pet = ExtraFeatures.EnsureVirtualPet()

    if not pet then
        state.Enabled = false
        return
    end

    task.spawn(function()
        while state.Enabled
            and Config.VirtualPetEnabled
            and generation == state.Generation
            and state.Instance
            and state.Instance.Parent
        do
            if state.Reacting then
                task.wait(0.10)
                continue
            end

            local inactiveFor =
                os.clock() - (state.LastInput or os.clock())

            if inactiveFor >= 120 then
                state.State = "Sleep"

                if state.Fallback and state.Fallback.Parent then
                    state.Fallback.Text = "😴"
                end

                pcall(function()
                    state.Instance.Rotation = 8
                end)

                task.wait(0.5)
            else
                state.State = "Walk"

                if state.Fallback and state.Fallback.Parent then
                    state.Fallback.Text = "🐱"
                end

                local target = ExtraFeatures.GetVirtualPetTarget()
                local currentX = state.Instance.AbsolutePosition.X
                local targetX =
                    MainWindow.AbsolutePosition.X
                    + target.X.Offset

                pcall(function()
                    state.Instance.Rotation =
                        targetX < currentX and -5 or 5
                end)

                local duration =
                    math.random(15, 40) / 10

                local tween = TweenService:Create(
                    state.Instance,
                    TweenInfo.new(
                        duration,
                        Enum.EasingStyle.Linear,
                        Enum.EasingDirection.Out
                    ),
                    {
                        Position = target
                    }
                )

                state.Tween = tween
                tween:Play()

                local elapsed = 0
                while elapsed < duration
                    and state.Enabled
                    and Config.VirtualPetEnabled
                    and generation == state.Generation
                    and not state.Reacting
                do
                    task.wait(0.2)
                    elapsed = elapsed + 0.2

                    if os.clock() - state.LastInput >= 120 then
                        pcall(function()
                            tween:Cancel()
                        end)
                        break
                    end
                end

                if generation ~= state.Generation
                    or not state.Enabled
                then
                    break
                end

                if state.Reacting then
                    pcall(function()
                        tween:Cancel()
                    end)

                    state.Tween = nil
                    task.wait(0.10)
                    continue
                end

                state.Tween = nil
                state.State = "Idle"

                pcall(function()
                    state.Instance.Rotation = 0
                end)

                local idleScale =
                    state.Instance:FindFirstChild(
                        "VirtualPetIdleScale"
                    )

                if not idleScale then
                    idleScale = Instance.new("UIScale")
                    idleScale.Name = "VirtualPetIdleScale"
                    idleScale.Scale = 1
                    idleScale.Parent = state.Instance
                end

                local breathe = TweenService:Create(
                    idleScale,
                    TweenInfo.new(
                        0.35,
                        Enum.EasingStyle.Quad,
                        Enum.EasingDirection.Out,
                        0,
                        true
                    ),
                    {
                        Scale = 1.07
                    }
                )
                breathe:Play()

                local idleTime = math.random(30, 50) / 10
                local idleElapsed = 0

                while idleElapsed < idleTime
                    and state.Enabled
                    and Config.VirtualPetEnabled
                    and generation == state.Generation
                    and not state.Reacting
                do
                    task.wait(0.2)
                    idleElapsed = idleElapsed + 0.2
                end
            end
        end
    end)
end


function ExtraFeatures.SetVirtualPetEnabled(enabled)
    Config.VirtualPetEnabled = enabled == true

    if Config.VirtualPetEnabled then
        local ok, err = pcall(function()
            ExtraFeatures.StartVirtualPet()
        end)

        if not ok then
            Config.VirtualPetEnabled = false
            ExtraFeatures.StopVirtualPet()
            warn("[Hood Rivals] Virtual Pet disabled: " .. tostring(err))
            return false
        end

        return true
    end

    ExtraFeatures.StopVirtualPet()
    return true
end

function ExtraFeatures.EnsureSnowContainer()
    local state = ExtraFeatures.UIEffects.Snowfall

    if state.Container and state.Container.Parent then
        return state.Container
    end

    local container = Instance.new("Frame")
    container.Name = "SnowContainer"
    container.Size = UDim2.fromScale(1, 1)
    container.Position = UDim2.fromScale(0, 0)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Active = false
    container.Selectable = false
    container.ClipsDescendants = true
    container.ZIndex = 0
    container.Parent = ScreenGui

    state.Container = container
    return container
end

function ExtraFeatures.DestroySnowfall()
    local state = ExtraFeatures.UIEffects.Snowfall
    state.Enabled = false
    state.Generation = state.Generation + 1

    for particle in pairs(state.Particles) do
        if particle and particle.Parent then
            particle:Destroy()
        end
        state.Particles[particle] = nil
    end

    if state.Container and state.Container.Parent then
        state.Container:Destroy()
    end

    state.Container = nil
end

function ExtraFeatures.SpawnSnowParticle()
    local state = ExtraFeatures.UIEffects.Snowfall

    if not state.Enabled
        or not Config.SnowfallEnabled
        or not ScreenGui.Enabled
    then
        return
    end

    local activeCount = 0
    for particle in pairs(state.Particles) do
        if particle and particle.Parent then
            activeCount = activeCount + 1
        else
            state.Particles[particle] = nil
        end
    end

    if activeCount >= state.MaxActive then
        return
    end

    local container = ExtraFeatures.EnsureSnowContainer()
    if not container then
        return
    end

    local size = math.random(2, 6)
    local startX = math.random(0, 1000) / 1000
    local drift = math.random(-12, 12) / 100
    local endX = math.clamp(startX + drift, -0.05, 1.05)
    local duration = math.random(30, 70) / 10

    local particle = Instance.new("Frame")
    particle.Name = "SnowParticle"
    particle.Size = UDim2.fromOffset(size, size)
    particle.Position = UDim2.new(startX, 0, -0.04, -size)
    particle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    particle.BackgroundTransparency =
        math.random(20, 80) / 100
    particle.BorderSizePixel = 0
    particle.Active = false
    particle.ZIndex = 0
    particle.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = particle

    state.Particles[particle] = true

    local tween = TweenService:Create(
        particle,
        TweenInfo.new(
            duration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        ),
        {
            Position = UDim2.new(endX, 0, 1.05, 0)
        }
    )

    tween:Play()

    task.delay(duration + 0.15, function()
        state.Particles[particle] = nil

        if particle and particle.Parent then
            particle:Destroy()
        end
    end)
end

function ExtraFeatures.StartSnowfall()
    local state = ExtraFeatures.UIEffects.Snowfall

    ExtraFeatures.DestroySnowfall()

    if not Config.SnowfallEnabled then
        return
    end

    state.Enabled = true
    state.Generation = state.Generation + 1
    local generation = state.Generation

    ExtraFeatures.EnsureSnowContainer()

    task.spawn(function()
        while state.Enabled
            and Config.SnowfallEnabled
            and generation == state.Generation
        do
            if ScreenGui.Enabled then
                pcall(function()
                    ExtraFeatures.SpawnSnowParticle()
                end)
            end

            task.wait(math.random(12, 30) / 100)
        end
    end)
end

function ExtraFeatures.SetSnowfallEnabled(enabled)
    Config.SnowfallEnabled = enabled == true

    if Config.SnowfallEnabled then
        local ok, err = pcall(function()
            ExtraFeatures.StartSnowfall()
        end)

        if not ok then
            Config.SnowfallEnabled = false
            ExtraFeatures.DestroySnowfall()
            warn("[Hood Rivals] Snowfall disabled: " .. tostring(err))
            return false
        end

        return true
    end

    ExtraFeatures.DestroySnowfall()
    return true
end

function ExtraFeatures.UpdateFloatingStatus(dt)
    local bubble = ExtraFeatures.UIEffects.Bubble
    local delta = math.max(0, tonumber(dt) or 0)

    bubble.FPSFrames = (bubble.FPSFrames or 0) + 1
    bubble.FPSAccumulator =
        (bubble.FPSAccumulator or 0) + delta
    bubble.LightningAccumulator =
        (bubble.LightningAccumulator or 0) + delta

    if bubble.FPSAccumulator >= 0.25 then
        local elapsed = math.max(
            bubble.FPSAccumulator,
            0.001
        )

        bubble.LastFPS =
            math.floor(
                (bubble.FPSFrames / elapsed) + 0.5
            )

        bubble.FPSFrames = 0
        bubble.FPSAccumulator = 0

        if FloatingBtn and FloatingBtn.Parent and not ExtraFeatures.V8.FPSLabel then
            FloatingBtn.Text =
                "⚡ FPS: "
                .. tostring(bubble.LastFPS)
                .. " ⚡"
        end
    end

    if UIRefs.FloatingRainbowGradient
        and UIRefs.FloatingRainbowGradient.Parent
    then
        UIRefs.FloatingRainbowGradient.Rotation =
            (os.clock() * 95) % 360
    end

    if UIRefs.MainRainbowGradient
        and UIRefs.MainRainbowGradient.Parent
    then
        local now = os.clock()
        UIRefs.MainRainbowGradient.Rotation =
            (now * 72) % 360

        -- Small neon breathing pulse; visual only.
        local neonPulse =
            (math.sin(now * 4.2) + 1) * 0.5

        MainStroke.Thickness =
            1.8 + (neonPulse * 0.8)
        MainStroke.Transparency =
            0.03 + ((1 - neonPulse) * 0.10)
    end

    if bubble.LightningAccumulator
        >= (bubble.NextLightning or 0.65)
    then
        bubble.LightningAccumulator = 0
        bubble.NextLightning =
            math.random(45, 105) / 100

        if FloatingBtn.Visible then
            pcall(function()
                FloatStroke.Thickness = 3.6
                FloatStroke.Transparency = 0

                TweenService:Create(
                    FloatStroke,
                    TweenInfo.new(
                        0.12,
                        Enum.EasingStyle.Quad,
                        Enum.EasingDirection.Out
                    ),
                    {
                        Thickness = 2,
                        Transparency = 0.05
                    }
                ):Play()
            end)
        end
    end
end

function ExtraFeatures.DestroyMinimizeChat()
    local bubble = ExtraFeatures.UIEffects.Bubble

    if bubble.ChatCloud
        and bubble.ChatCloud.Parent
    then
        bubble.ChatCloud:Destroy()
    end

    bubble.ChatCloud = nil
end

function ExtraFeatures.ShowMinimizeChat()
    local bubble = ExtraFeatures.UIEffects.Bubble
    local messages = bubble.Messages

    if type(messages) ~= "table"
        or #messages == 0
        or not FloatingBtn.Visible
    then
        return
    end

    ExtraFeatures.DestroyMinimizeChat()

    bubble.ChatToken = (bubble.ChatToken or 0) + 1
    local token = bubble.ChatToken
    local message =
        messages[math.random(1, #messages)]

    local cloud = Instance.new("TextLabel")
    cloud.Name = "MinimizeChatCloud"
    cloud.AnchorPoint = Vector2.new(0.5, 0.5)
    cloud.Size = UDim2.fromOffset(300, 74)
    cloud.BackgroundColor3 =
        Color3.fromRGB(242, 244, 250)
    cloud.BackgroundTransparency = 0.08
    cloud.BorderSizePixel = 0
    cloud.Text = tostring(message)
    cloud.TextColor3 = Color3.fromRGB(25, 25, 32)
    cloud.Font = Enum.Font.GothamBold
    cloud.TextSize = 13
    cloud.TextWrapped = true
    cloud.Active = false
    cloud.Selectable = false
    cloud.ZIndex = 120
    cloud.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = cloud

    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.AccentColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.20
    stroke.Parent = cloud

    local scale = math.max(UIScaleObj.Scale, 0.01)
    local startX =
        (
            FloatingBtn.AbsolutePosition.X
            + FloatingBtn.AbsoluteSize.X * 0.5
        ) / scale
    local startY =
        (
            FloatingBtn.AbsolutePosition.Y
            + FloatingBtn.AbsoluteSize.Y * 0.5
        ) / scale

    local camera = Workspace.CurrentCamera
    local viewport =
        camera
        and camera.ViewportSize
        or Vector2.new(800, 600)

    cloud.Position =
        UDim2.fromOffset(startX, startY)

    bubble.ChatCloud = cloud

    local moveTween = TweenService:Create(
        cloud,
        TweenInfo.new(
            0.90,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {
            Position = UDim2.fromOffset(
                (viewport.X * 0.5) / scale,
                (viewport.Y * 0.46) / scale
            )
        }
    )

    moveTween:Play()

    task.delay(1.10, function()
        if token ~= bubble.ChatToken
            or not cloud
            or not cloud.Parent
        then
            return
        end

        local fade = TweenService:Create(
            cloud,
            TweenInfo.new(
                0.42,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            ),
            {
                BackgroundTransparency = 1,
                TextTransparency = 1
            }
        )

        fade:Play()

        task.delay(0.45, function()
            if cloud and cloud.Parent then
                cloud:Destroy()
            end

            if bubble.ChatCloud == cloud then
                bubble.ChatCloud = nil
            end
        end)
    end)
end

function ExtraFeatures.PrepareBubble()
    local effects = ExtraFeatures.UIEffects
    local bubble = effects.Bubble

    if not bubble.MainScale or not bubble.MainScale.Parent then
        local scale = MainWindow:FindFirstChild("MenuAnimationScale")

        if not scale then
            scale = Instance.new("UIScale")
            scale.Name = "MenuAnimationScale"
            scale.Scale = 1
            scale.Parent = MainWindow
        end

        bubble.MainScale = scale
    end

    if not bubble.BubbleScale or not bubble.BubbleScale.Parent then
        local scale = FloatingBtn:FindFirstChild("BubbleScale")

        if not scale then
            scale = Instance.new("UIScale")
            scale.Name = "BubbleScale"
            scale.Scale = 1
            scale.Parent = FloatingBtn
        end

        bubble.BubbleScale = scale
    end
end

function ExtraFeatures.AnimateBubbleIn()
    ExtraFeatures.PrepareBubble()

    local bubble = ExtraFeatures.UIEffects.Bubble
    FloatingBtn.Visible = true
    FloatingBtn.BackgroundTransparency = 0.18
    bubble.BubbleScale.Scale = 0

    local grow = TweenService:Create(
        bubble.BubbleScale,
        TweenInfo.new(
            0.14,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        ),
        {
            Scale = 1.08
        }
    )
    grow:Play()

    task.delay(0.14, function()
        if bubble.BubbleScale and bubble.BubbleScale.Parent then
            TweenService:Create(
                bubble.BubbleScale,
                TweenInfo.new(
                    0.10,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    Scale = 1
                }
            ):Play()
        end
    end)
end

function ExtraFeatures.AnimateMenuOpen()
    local effects = ExtraFeatures.UIEffects
    local bubble = effects.Bubble

    ExtraFeatures.PrepareBubble()

    effects.AnimationBusy = true
    bubble.Token = bubble.Token + 1
    local token = bubble.Token

    ScreenGui.Enabled = true
    MainWindow.Visible = true
    FloatingBtn.Visible = false
    bubble.MainScale.Scale = 0.88
    MainWindow.BackgroundTransparency =
        math.min(1, Config.BackgroundTransparency + 0.20)

    if bubble.MainTween then
        pcall(function()
            bubble.MainTween:Cancel()
        end)
    end

    if bubble.MainFadeTween then
        pcall(function()
            bubble.MainFadeTween:Cancel()
        end)
    end

    bubble.MainTween = TweenService:Create(
        bubble.MainScale,
        TweenInfo.new(
            0.22,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
        {
            Scale = 1
        }
    )

    bubble.MainFadeTween = TweenService:Create(
        MainWindow,
        TweenInfo.new(
            0.22,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {
            BackgroundTransparency =
                Config.BackgroundTransparency
        }
    )

    bubble.MainTween:Play()
    bubble.MainFadeTween:Play()

    task.delay(0.24, function()
        if token == bubble.Token then
            effects.AnimationBusy = false
            bubble.MainTween = nil
            bubble.MainFadeTween = nil
        end
    end)
end

function ExtraFeatures.AnimateMenuMinimize()
    local effects = ExtraFeatures.UIEffects
    local bubble = effects.Bubble

    ExtraFeatures.PrepareBubble()

    effects.AnimationBusy = true
    bubble.Token = bubble.Token + 1
    local token = bubble.Token

    if bubble.MainTween then
        pcall(function()
            bubble.MainTween:Cancel()
        end)
    end

    if bubble.MainFadeTween then
        pcall(function()
            bubble.MainFadeTween:Cancel()
        end)
    end

    bubble.MainTween = TweenService:Create(
        bubble.MainScale,
        TweenInfo.new(
            0.18,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.In
        ),
        {
            Scale = 0.88
        }
    )

    bubble.MainFadeTween = TweenService:Create(
        MainWindow,
        TweenInfo.new(
            0.18,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In
        ),
        {
            BackgroundTransparency =
                math.min(1, Config.BackgroundTransparency + 0.25)
        }
    )

    bubble.MainTween:Play()
    bubble.MainFadeTween:Play()

    task.delay(0.19, function()
        if token ~= bubble.Token then
            return
        end

        MainWindow.Visible = false
        bubble.MainScale.Scale = 1
        MainWindow.BackgroundTransparency =
            Config.BackgroundTransparency

        ExtraFeatures.AnimateBubbleIn()
        ExtraFeatures.ShowMinimizeChat()
        effects.AnimationBusy = false
        bubble.MainTween = nil
        bubble.MainFadeTween = nil
    end)
end

function ExtraFeatures.InitializeUIEffects()
    local effects = ExtraFeatures.UIEffects

    if effects.Initialized then
        return
    end

    effects.Initialized = true
    ExtraFeatures.PrepareBubble()

    if not effects.InputTrackingReady then
        effects.InputTrackingReady = true

        AddConnection(
            UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType
                    == Enum.UserInputType.MouseMovement
                    or input.UserInputType
                    == Enum.UserInputType.Touch
                then
                    ExtraFeatures.MarkUIActivity()
                end
            end)
        )
    end

    AddConnection(
        FloatingBtn.MouseEnter:Connect(function()
            if not FloatingBtn.Visible then
                return
            end

            pcall(function()
                if effects.Bubble.HoverTween then
                    effects.Bubble.HoverTween:Cancel()
                end

                effects.Bubble.HoverTween =
                    TweenService:Create(
                        FloatingBtn,
                        TweenInfo.new(
                            0.16,
                            Enum.EasingStyle.Quad,
                            Enum.EasingDirection.Out
                        ),
                        {
                            BackgroundTransparency = 0.05
                        }
                    )

                effects.Bubble.HoverTween:Play()

                TweenService:Create(
                    FloatStroke,
                    TweenInfo.new(0.16),
                    {
                        Thickness = 2.2,
                        Transparency = 0
                    }
                ):Play()

                TweenService:Create(
                    effects.Bubble.BubbleScale,
                    TweenInfo.new(0.16),
                    {
                        Scale = 1.06
                    }
                ):Play()
            end)
        end)
    )

    AddConnection(
        FloatingBtn.MouseLeave:Connect(function()
            pcall(function()
                if effects.Bubble.HoverTween then
                    effects.Bubble.HoverTween:Cancel()
                end

                effects.Bubble.HoverTween =
                    TweenService:Create(
                        FloatingBtn,
                        TweenInfo.new(
                            0.16,
                            Enum.EasingStyle.Quad,
                            Enum.EasingDirection.Out
                        ),
                        {
                            BackgroundTransparency = 0.18
                        }
                    )

                effects.Bubble.HoverTween:Play()

                TweenService:Create(
                    FloatStroke,
                    TweenInfo.new(0.16),
                    {
                        Thickness = 1.5,
                        Transparency = 0.12
                    }
                ):Play()

                TweenService:Create(
                    effects.Bubble.BubbleScale,
                    TweenInfo.new(0.16),
                    {
                        Scale = 1
                    }
                ):Play()
            end)
        end)
    )

    pcall(function()
        ExtraFeatures.SetVirtualPetEnabled(
            Config.VirtualPetEnabled
        )
    end)

    pcall(function()
        ExtraFeatures.SetSnowfallEnabled(
            Config.SnowfallEnabled
        )
    end)
end

function ExtraFeatures.CleanupUIEffects()
    local effects = ExtraFeatures.UIEffects

    if not effects then
        return
    end

    effects.AnimationBusy = false

    pcall(function()
        ExtraFeatures.StopVirtualPet()
    end)

    pcall(function()
        ExtraFeatures.DestroySnowfall()
    end)

    local dynamic = effects.DynamicColor

    if dynamic and dynamic.Tween then
        pcall(function()
            dynamic.Tween:Cancel()
        end)

        dynamic.Tween = nil
    end

    local toggleFX = effects.ToggleFX

    if toggleFX then
        toggleFX.ShakeBusy = false

        for particle in pairs(toggleFX.ActiveParticles or {}) do
            if particle and particle.Parent then
                particle:Destroy()
            end
        end

        table.clear(toggleFX.ActiveParticles)

        if toggleFX.Sound and toggleFX.Sound.Parent then
            pcall(function()
                toggleFX.Sound:Stop()
            end)

            toggleFX.Sound:Destroy()
        end

        toggleFX.Sound = nil

        if toggleFX.Overlay and toggleFX.Overlay.Parent then
            toggleFX.Overlay:Destroy()
        end

        toggleFX.Overlay = nil
    end

    if effects.Sliders
        and type(effects.Sliders.Active) == "table"
    then
        table.clear(effects.Sliders.Active)
    end

    local bubble = effects.Bubble
    bubble.Token = bubble.Token + 1

    for _, tween in pairs({
        Hover = bubble.HoverTween,
        Scale = bubble.ScaleTween,
        Main = bubble.MainTween,
        Fade = bubble.MainFadeTween
    }) do
        if tween then
            pcall(function()
                tween:Cancel()
            end)
        end
    end

    bubble.HoverTween = nil
    bubble.ScaleTween = nil
    bubble.MainTween = nil
    bubble.MainFadeTween = nil

    if bubble.MainScale and bubble.MainScale.Parent then
        bubble.MainScale.Scale = 1
    end

    if bubble.BubbleScale and bubble.BubbleScale.Parent then
        bubble.BubbleScale.Scale = 1
    end

    bubble.ChatToken = (bubble.ChatToken or 0) + 1
    pcall(function()
        ExtraFeatures.DestroyMinimizeChat()
    end)

    FloatingBtn.Visible = false
end

local function GetCurrentGameMetadata()
    local name = "Unknown"
    local placeId = 0

    pcall(function()
        if type(game.Name) == "string" and game.Name ~= "" then
            name = game.Name
        end
    end)

    pcall(function()
        if IsFiniteNumber(game.PlaceId) then
            placeId = game.PlaceId
        end
    end)

    return name, placeId
end

CurrentGameName, CurrentPlaceId = GetCurrentGameMetadata()

local function BuildConfigPayload()
    return {
        version = 8,
        OwnerUserId = LocalPlayer.UserId,
        AimPriority = Config.AimPriority,
        Classification = {Mode = Config.Classification.Mode, Attribute = Config.Classification.Attribute},
        WeaponTuning = table.clone(Config.WeaponTuning),
        Proximity = table.clone(Config.Proximity),
        Interface = ExtraFeatures.BuildInterfacePayload(),

        -- AIM
        AimEnabled = Config.AimEnabled,
        TeamCheck = Config.TeamCheck,
        WallCheck = Config.WallCheck,
        IgnoreVisibility = Config.IgnoreVisibility,
        UseFOV = Config.UseFOV,
        FOV = Config.FOV,
        AlwaysAim = Config.AlwaysAim,
        AimOnFire = Config.AimOnFire,
        AimPart = Config.AimPart,
        Smoothness = Config.Smoothness,
        AimMaxDistance = Config.AimMaxDistance,
        AimNPC = Config.AimNPC,
        TargetAssistEnabled = Config.TargetAssistEnabled,
        AimSilentEnabled = Config.AimSilentEnabled,
        HeadHitboxEnabled = Config.HeadHitboxEnabled,
        HeadHitboxSize = Config.HeadHitboxSize,

        -- TELEKILL
        TelekillEnabled = Config.TelekillEnabled,
        TelekillTarget = Config.TelekillTarget,
        TelekillTargets = {
            Enemy = Config.TelekillTargets.Enemy == true,
            Team = Config.TelekillTargets.Team == true,
            NPC = Config.TelekillTargets.NPC == true
        },
        TelekillDistanceMode = Config.TelekillDistanceMode,
        TelekillDistance = Config.TelekillDistance,
        TelekillSwitchKey =
            Config.TelekillSwitchKey
            and Config.TelekillSwitchKey.Name
            or "T",

        -- ESP
        Enabled = Config.Enabled,
        ShowEnemies = Config.ShowEnemies,
        ShowTeammates = Config.ShowTeammates,
        ShowName = Config.ShowName,
        ShowTracer = Config.ShowTracer,
        ShowSkeleton = Config.ShowSkeleton,
        ShowBox = Config.ShowBox,
        ShowNPC = Config.ShowNPC,
        ShowHealth = Config.ShowHealth,
        ShowDistance = Config.ShowDistance,
        MaxDistance = Config.MaxDistance,
        ESPHighlightEnabled = Config.ESPHighlightEnabled,

        -- PLAYER
        Player = {
            CFrameSpeedEnabled = Config.Player.CFrameSpeedEnabled,
            CFrameSpeed = Config.Player.CFrameSpeed,
            AirFlyEnabled = Config.Player.AirFlyEnabled,
            JumpPower = Config.Player.JumpPower,
            JumpPowerOverrideEnabled = Config.Player.JumpPowerOverrideEnabled,
            FlyEnabled = Config.Player.FlyEnabled,
            FlySpeed = Config.Player.FlySpeed,
            FullBrightEnabled = Config.Player.FullBrightEnabled,
            NoclipEnabled = Config.Player.NoclipEnabled
        },

        -- MENU INPUT
        ToggleKeyEnabled = Config.ToggleKeyEnabled,
        ToggleKey = Config.ToggleKey and Config.ToggleKey.Name or nil,
        ThirdPersonLock = Config.ThirdPersonLock,
        XRayEnabled = Config.XRayEnabled,
        XRayTransparency = Config.XRayTransparency,
        AntiAFKEnabled = Config.AntiAFKEnabled,
        VirtualPetEnabled = Config.VirtualPetEnabled,
        SnowfallEnabled = Config.SnowfallEnabled,

        -- FUNCTION 1 DATA
        DroneStrikeKey = Config.DroneStrikeKey and Config.DroneStrikeKey.Name or nil,
        MagicSilentEnabled = Config.MagicSilentEnabled,

        HoldToSpamEnabled = Config.HoldToSpamEnabled,
        HoldToSpamKey = Config.HoldToSpamKey and Config.HoldToSpamKey.Name or nil,
        UIScale = Config.UIScale,
        BackgroundTransparency = Config.BackgroundTransparency
    }
end

local function SetBooleanField(source, key, target, targetKey)
    if type(source) ~= "table" then
        return
    end

    if type(source[key]) == "boolean" then
        target[targetKey or key] = source[key]
    end
end

local function SetNumberField(source, key, target, targetKey, minValue, maxValue)
    if type(source) ~= "table" then
        return
    end

    local value = source[key]
    if not IsFiniteNumber(value) then
        return
    end

    if minValue ~= nil then
        value = math.max(value, minValue)
    end

    if maxValue ~= nil then
        value = math.min(value, maxValue)
    end

    target[targetKey or key] = value
end

local function ApplyConfigPayload(payload)
    if type(payload) ~= "table" then
        return false, "Invalid config root"
    end

    if payload.OwnerUserId ~= nil and payload.OwnerUserId ~= LocalPlayer.UserId then
        return false, "Saved data belongs to another player"
    end
    if ExtraFeatures.V8.ApplyFeatures then ExtraFeatures.V8.ApplyFeatures(payload) end
    local oldFullBrightEnabled = Config.Player.FullBrightEnabled

    SetBooleanField(payload, "AimEnabled", Config)
    SetBooleanField(payload, "TeamCheck", Config)
    SetBooleanField(payload, "WallCheck", Config)
    SetBooleanField(payload, "IgnoreVisibility", Config)
    SetBooleanField(payload, "UseFOV", Config)
    SetNumberField(payload, "FOV", Config, nil, 0, 600)
    SetBooleanField(payload, "AlwaysAim", Config)
    SetBooleanField(payload, "AimOnFire", Config)

    if type(payload.AimPart) == "string" then
        if payload.AimPart == "Head" or payload.AimPart == "Body" then
            Config.AimPart = payload.AimPart
        end
    end

    SetNumberField(payload, "Smoothness", Config, nil, 0.2, 1)
    SetNumberField(payload, "AimMaxDistance", Config, nil, 50, 10000)
    SetBooleanField(payload, "AimNPC", Config)
    SetBooleanField(payload, "TargetAssistEnabled", Config)

    if type(payload.AimSilentEnabled) == "boolean" then
        Config.AimSilentEnabled = payload.AimSilentEnabled
    else
        Config.AimSilentEnabled = false
    end

    -- Backward compatibility: old Hitbox profile fields now map only to
    -- the safe NPC/dummy Head Hitbox implementation.
    if type(payload.HeadHitboxEnabled) == "boolean" then
        Config.HeadHitboxEnabled = payload.HeadHitboxEnabled
    elseif type(payload.HitboxExpanderEnabled) == "boolean" then
        Config.HeadHitboxEnabled = payload.HitboxExpanderEnabled
    end

    if IsFiniteNumber(payload.HeadHitboxSize) then
        Config.HeadHitboxSize =
            math.clamp(payload.HeadHitboxSize, 0, 10)
    elseif IsFiniteNumber(payload.HitboxSize) then
        Config.HeadHitboxSize =
            math.clamp(payload.HitboxSize, 0, 10)
    end

    SetBooleanField(payload, "TelekillEnabled", Config)

    if type(payload.TelekillTargets) == "table" then
        Config.TelekillTargets.Enemy =
            payload.TelekillTargets.Enemy == true
        Config.TelekillTargets.Team =
            payload.TelekillTargets.Team == true
        Config.TelekillTargets.NPC =
            payload.TelekillTargets.NPC == true
    elseif type(payload.TelekillTarget) == "string" then
        -- Backward compatibility with old single-target profiles.
        Config.TelekillTargets.Enemy =
            payload.TelekillTarget == "Enemy"
            or payload.TelekillTarget == "Nearest"
            or payload.TelekillTarget == "Farthest"
        Config.TelekillTargets.Team =
            payload.TelekillTarget == "Team"
        Config.TelekillTargets.NPC =
            payload.TelekillTarget == "NPC"

        if payload.TelekillTarget == "Nearest"
            or payload.TelekillTarget == "Farthest"
        then
            Config.TelekillDistanceMode =
                payload.TelekillTarget
        end
    end

    Telekill.EnsureAtLeastOneTarget()

    if type(payload.TelekillSwitchKey) == "string" then
        pcall(function()
            local enumItem =
                Enum.KeyCode[payload.TelekillSwitchKey]

            if enumItem
                and enumItem ~= Config.ToggleKey
                and enumItem ~= Config.DroneStrikeKey
                and enumItem ~= Config.HoldToSpamKey
            then
                Config.TelekillSwitchKey = enumItem
            end
        end)
    end

    if type(payload.TelekillDistanceMode) == "string" then
        if payload.TelekillDistanceMode == "Nearest"
            or payload.TelekillDistanceMode == "Farthest"
        then
            Config.TelekillDistanceMode = payload.TelekillDistanceMode
        end
    end

    SetNumberField(
        payload,
        "TelekillDistance",
        Config,
        nil,
        1,
        20
    )

    if Config.AlwaysAim and Config.AimOnFire then
        Config.AimOnFire = false
    end

    SetBooleanField(payload, "Enabled", Config)
    SetBooleanField(payload, "ShowEnemies", Config)
    SetBooleanField(payload, "ShowTeammates", Config)
    SetBooleanField(payload, "ShowName", Config)
    SetBooleanField(payload, "ShowTracer", Config)
    SetBooleanField(payload, "ShowSkeleton", Config)
    SetBooleanField(payload, "ShowBox", Config)
    SetBooleanField(payload, "ShowNPC", Config)
    SetBooleanField(payload, "ShowHealth", Config)
    SetBooleanField(payload, "ShowDistance", Config)
    SetNumberField(payload, "MaxDistance", Config, nil, 50, 10000)
    SetBooleanField(payload, "ESPHighlightEnabled", Config)
    if type(payload.Player) == "table" then
        SetBooleanField(
            payload.Player,
            "CFrameSpeedEnabled",
            Config.Player
        )
        SetNumberField(
            payload.Player,
            "CFrameSpeed",
            Config.Player,
            nil,
            20,
            10000
        )
        SetBooleanField(
            payload.Player,
            "AirFlyEnabled",
            Config.Player
        )
        SetNumberField(
            payload.Player,
            "JumpPower",
            Config.Player,
            nil,
            20,
            10000
        )
        SetBooleanField(
            payload.Player,
            "JumpPowerOverrideEnabled",
            Config.Player
        )
        SetBooleanField(
            payload.Player,
            "FlyEnabled",
            Config.Player
        )
        SetNumberField(
            payload.Player,
            "FlySpeed",
            Config.Player,
            nil,
            0,
            10000
        )
        SetBooleanField(
            payload.Player,
            "FullBrightEnabled",
            Config.Player
        )
        SetBooleanField(
            payload.Player,
            "NoclipEnabled",
            Config.Player
        )
    end

    SetBooleanField(payload, "ToggleKeyEnabled", Config)
    SetBooleanField(payload, "ThirdPersonLock", Config)
    SetBooleanField(payload, "XRayEnabled", Config)
    SetNumberField(
        payload,
        "XRayTransparency",
        Config,
        nil,
        0.3,
        1.0
    )
    SetBooleanField(payload, "AntiAFKEnabled", Config)
    SetBooleanField(payload, "VirtualPetEnabled", Config)
    SetBooleanField(payload, "SnowfallEnabled", Config)

    SetBooleanField(payload, "MagicSilentEnabled", Config)

    if type(payload.DroneStrikeKey) == "string" then
        pcall(function()
            local enumItem = Enum.KeyCode[payload.DroneStrikeKey]
            if enumItem and enumItem ~= Config.ToggleKey then
                Config.DroneStrikeKey = enumItem
            end
        end)
    end

    SetBooleanField(payload, "HoldToSpamEnabled", Config)

    if type(payload.HoldToSpamKey) == "string" then
        pcall(function()
            local enumItem =
                Enum.KeyCode[payload.HoldToSpamKey]
            if enumItem then
                Config.HoldToSpamKey = enumItem
            end
        end)
    end

    SetNumberField(payload, "UIScale", Config, nil, 0.25, 3)
    SetNumberField(
        payload,
        "BackgroundTransparency",
        Config,
        nil,
        0,
        1
    )

    if type(payload.ToggleKey) == "string" then
        pcall(function()
            local enumItem = Enum.KeyCode[payload.ToggleKey]
            if enumItem then
                Config.ToggleKey = enumItem
            end
        end)
    end

    if Config.DroneStrikeKey == Config.ToggleKey then
        Config.DroneStrikeKey = Enum.KeyCode.V
        if Config.DroneStrikeKey == Config.ToggleKey then
            Config.DroneStrikeKey = Enum.KeyCode.B
        end
    end

    if Config.TelekillSwitchKey == Config.ToggleKey
        or Config.TelekillSwitchKey == Config.DroneStrikeKey
        or Config.TelekillSwitchKey == Config.HoldToSpamKey
    then
        Config.TelekillSwitchKey = Enum.KeyCode.T

        if Config.TelekillSwitchKey == Config.ToggleKey
            or Config.TelekillSwitchKey == Config.DroneStrikeKey
            or Config.TelekillSwitchKey == Config.HoldToSpamKey
        then
            Config.TelekillSwitchKey = Enum.KeyCode.Y
        end
    end

    if oldFullBrightEnabled and not Config.Player.FullBrightEnabled then
        RestoreFullBright()
    elseif Config.Player.FullBrightEnabled then
        CaptureFullBrightState()
        ApplyFullBright()
    end

    if not Config.Player.AirFlyEnabled then
        PlayerRuntime.AirFlyJumpRequested = false
    end

    if Config.Player.JumpPowerOverrideEnabled then
        ApplyJumpPower(PlayerRuntime.Humanoid)
    else
        RestoreOriginalJumpPower(PlayerRuntime.Humanoid)
    end

    OtherSystem.SetThirdPerson(Config.ThirdPersonLock)
    OtherSystem.SetXRay(Config.XRayEnabled)
    OtherSystem.UpdateXRayTransparency()

    ExtraFeatures.SetHeadHitboxEnabled(
        Config.HeadHitboxEnabled
    )

    if not ExtraFeatures.SetAntiAFK(
        Config.AntiAFKEnabled
    ) then
        Config.AntiAFKEnabled = false
    end

    if ExtraFeatures.SetVirtualPetEnabled then
        pcall(function()
            ExtraFeatures.SetVirtualPetEnabled(
                Config.VirtualPetEnabled
            )
        end)
    end

    if ExtraFeatures.SetSnowfallEnabled then
        pcall(function()
            ExtraFeatures.SetSnowfallEnabled(
                Config.SnowfallEnabled
            )
        end)
    end

    if not Config.HoldToSpamEnabled then
        ExtraFeatures.HoldSpamKeyHeld = false
        ExtraFeatures.HoldSpamRightHeld = false
        ExtraFeatures.HoldSpamAccumulator = 0
    end

    ExtraFeatures.ApplyInterfacePayload(payload.Interface)

    -- Apply menu-level persistent values directly after validation.
    UIScaleObj.Scale = Config.UIScale
    MainWindow.BackgroundTransparency =
        Config.BackgroundTransparency
    if ExtraFeatures.ApplyInterfaceLayout then ExtraFeatures.ApplyInterfaceLayout(true) end

    return true
end

local function SyncSettingsUI()
    if UIRefs.Toggles.AimEnabled then
        UIRefs.Toggles.AimEnabled.Set(Config.AimEnabled, true)
    end
    if UIRefs.Toggles.TeamCheck then
        UIRefs.Toggles.TeamCheck.Set(Config.TeamCheck, true)
    end
    if UIRefs.Toggles.WallCheck then
        UIRefs.Toggles.WallCheck.Set(Config.WallCheck, true)
    end
    if UIRefs.Toggles.IgnoreVisibility then
        UIRefs.Toggles.IgnoreVisibility.Set(Config.IgnoreVisibility, true)
    end
    if UIRefs.Toggles.AimNPC then
        UIRefs.Toggles.AimNPC.Set(Config.AimNPC, true)
    end
    if UIRefs.Toggles.TargetAssist then
        UIRefs.Toggles.TargetAssist.Set(
            Config.TargetAssistEnabled,
            true
        )
    end
    if not Config.TargetAssistEnabled then
        ExtraFeatures.ClearTargetAssist()
    end
    if UIRefs.Toggles.AimSilent then
        UIRefs.Toggles.AimSilent.Set(
            Config.AimSilentEnabled,
            true
        )
    end
    if not Config.AimSilentEnabled then
        ExtraFeatures.ClearAimSilent()
    end
    if UIRefs.Toggles.HeadHitbox then
        UIRefs.Toggles.HeadHitbox.Set(
            Config.HeadHitboxEnabled,
            true
        )
    end
    if UIRefs.Sliders.HeadHitboxSize then
        UIRefs.Sliders.HeadHitboxSize.Set(
            Config.HeadHitboxSize,
            true
        )
    end
    if UIRefs.Toggles.UseFOV then
        UIRefs.Toggles.UseFOV.Set(Config.UseFOV, true)
    end
    if UIRefs.Toggles.AlwaysAim then
        UIRefs.Toggles.AlwaysAim.Set(Config.AlwaysAim, true)
    end
    if UIRefs.Toggles.AimOnFire then
        UIRefs.Toggles.AimOnFire.Set(Config.AimOnFire, true)
    end

    if UIRefs.Toggles.TelekillEnabled then
        UIRefs.Toggles.TelekillEnabled.Set(
            Config.TelekillEnabled,
            true
        )
    end
    if UIRefs.Toggles.TelekillTargetEnemy then
        UIRefs.Toggles.TelekillTargetEnemy.Set(
            Config.TelekillTargets.Enemy == true,
            true
        )
    end
    if UIRefs.Toggles.TelekillTargetTeam then
        UIRefs.Toggles.TelekillTargetTeam.Set(
            Config.TelekillTargets.Team == true,
            true
        )
    end
    if UIRefs.Toggles.TelekillTargetNPC then
        UIRefs.Toggles.TelekillTargetNPC.Set(
            Config.TelekillTargets.NPC == true,
            true
        )
    end
    Telekill.RefreshTargetUI()

    if UIRefs.TelekillDistanceModeButton then
        UIRefs.TelekillDistanceModeButton.Text =
            "Distance: " .. tostring(Config.TelekillDistanceMode)
    end
    if UIRefs.Sliders.TelekillDistance then
        UIRefs.Sliders.TelekillDistance.Set(
            Config.TelekillDistance,
            true
        )
    end

    if UIRefs.Sliders.FOV then
        UIRefs.Sliders.FOV.Set(Config.FOV, true)
    end
    if UIRefs.Sliders.Smoothness then
        UIRefs.Sliders.Smoothness.Set(Config.Smoothness, true)
    end
    if UIRefs.Textboxes.AimMaxDistance then
        UIRefs.Textboxes.AimMaxDistance.Text =
            tostring(Config.AimMaxDistance)
    end
    if AimPartButton then
        AimPartButton.Text = "Aim Part: " .. tostring(Config.AimPart)
    end

    if UIRefs.Toggles.Enabled then
        UIRefs.Toggles.Enabled.Set(Config.Enabled, true)
    end
    if UIRefs.Toggles.ShowEnemies then
        UIRefs.Toggles.ShowEnemies.Set(Config.ShowEnemies, true)
    end
    if UIRefs.Toggles.ShowTeammates then
        UIRefs.Toggles.ShowTeammates.Set(Config.ShowTeammates, true)
    end
    if UIRefs.Toggles.ShowName then
        UIRefs.Toggles.ShowName.Set(Config.ShowName, true)
    end
    if UIRefs.Toggles.ShowBox then
        UIRefs.Toggles.ShowBox.Set(Config.ShowBox, true)
    end
    if UIRefs.Toggles.ShowNPC then
        UIRefs.Toggles.ShowNPC.Set(Config.ShowNPC, true)
    end
    if UIRefs.Toggles.ShowTracer then
        UIRefs.Toggles.ShowTracer.Set(Config.ShowTracer, true)
    end
    if UIRefs.Toggles.ShowSkeleton then
        UIRefs.Toggles.ShowSkeleton.Set(Config.ShowSkeleton, true)
    end
    if UIRefs.Toggles.ShowHealth then
        UIRefs.Toggles.ShowHealth.Set(Config.ShowHealth, true)
    end
    if UIRefs.Toggles.ShowDistance then
        UIRefs.Toggles.ShowDistance.Set(Config.ShowDistance, true)
    end
    if UIRefs.Toggles.ESPHighlightEnabled then
        UIRefs.Toggles.ESPHighlightEnabled.Set(
            Config.ESPHighlightEnabled,
            true
        )
    end
    if UIRefs.Textboxes.MaxDistance then
        UIRefs.Textboxes.MaxDistance.Text =
            tostring(Config.MaxDistance)
    end

    if UIRefs.Toggles.CFrameSpeedEnabled then
        UIRefs.Toggles.CFrameSpeedEnabled.Set(
            Config.Player.CFrameSpeedEnabled,
            true
        )
    end
    if UIRefs.Sliders.CFrameSpeed then
        UIRefs.Sliders.CFrameSpeed.Set(
            Config.Player.CFrameSpeed,
            true
        )
    end
    if UIRefs.Toggles.JumpPowerOverrideEnabled then
        UIRefs.Toggles.JumpPowerOverrideEnabled.Set(
            Config.Player.JumpPowerOverrideEnabled,
            true
        )
    end
    if UIRefs.Toggles.AirFlyEnabled then
        UIRefs.Toggles.AirFlyEnabled.Set(
            Config.Player.AirFlyEnabled,
            true
        )
    end
    if UIRefs.Sliders.JumpPower then
        UIRefs.Sliders.JumpPower.Set(
            Config.Player.JumpPower,
            true
        )
    end
    if UIRefs.Toggles.FlyEnabled then
        UIRefs.Toggles.FlyEnabled.Set(
            Config.Player.FlyEnabled,
            true
        )
    end
    if UIRefs.Sliders.FlySpeed then
        UIRefs.Sliders.FlySpeed.Set(
            Config.Player.FlySpeed,
            true
        )
    end
    if UIRefs.Toggles.FullBrightEnabled then
        UIRefs.Toggles.FullBrightEnabled.Set(
            Config.Player.FullBrightEnabled,
            true
        )
    end
    if UIRefs.Toggles.NoclipEnabled then
        UIRefs.Toggles.NoclipEnabled.Set(
            Config.Player.NoclipEnabled,
            true
        )
    end

    if UIRefs.Toggles.ThirdPersonLock then
        UIRefs.Toggles.ThirdPersonLock.Set(
            Config.ThirdPersonLock,
            true
        )
    end

    if UIRefs.Toggles.XRayEnabled then
        UIRefs.Toggles.XRayEnabled.Set(
            Config.XRayEnabled,
            true
        )
    end

    if UIRefs.Sliders.XRayTransparency then
        UIRefs.Sliders.XRayTransparency.Set(
            Config.XRayTransparency,
            true
        )
    end

    if UIRefs.Toggles.AntiAFK then
        UIRefs.Toggles.AntiAFK.Set(
            Config.AntiAFKEnabled,
            true
        )
    end

    if UIRefs.Toggles.VirtualPet then
        UIRefs.Toggles.VirtualPet.Set(
            Config.VirtualPetEnabled,
            true
        )
    end

    if UIRefs.Toggles.Snowfall then
        UIRefs.Toggles.Snowfall.Set(
            Config.SnowfallEnabled,
            true
        )
    end

    if UIRefs.Toggles.MagicSilent then
        UIRefs.Toggles.MagicSilent.Set(
            Config.MagicSilentEnabled,
            true
        )
    end


    if UIRefs.DroneStrikeKeyBox then
        UIRefs.DroneStrikeKeyBox.Text =
            "Drone Strike Key: " .. Config.DroneStrikeKey.Name
    end

    if UIRefs.Toggles.HoldToSpam then
        UIRefs.Toggles.HoldToSpam.Set(
            Config.HoldToSpamEnabled,
            true
        )
    end

    if UIRefs.HoldToSpamKeyBox then
        UIRefs.HoldToSpamKeyBox.Text =
            "Hold to Spam Key: "
            .. Config.HoldToSpamKey.Name
    end

    if UIRefs.OtherToggleKeyBox then
        UIRefs.OtherToggleKeyBox.Text =
            Config.ToggleKey.Name
    end
end

local function SaveSettings()
    local payload = BuildConfigPayload()
    SessionConfigBackup = payload
    ExtraFeatures.SessionBackupPreferred = true
    local encoded = SafeEncodeJSON(payload)
    local saved = encoded and SafeWriteFile(CONFIG_FILE, encoded) == true or false
    ExtraFeatures.SessionBackupPreferred = not saved
    if ExtraFeatures.V8.SaveSettingsToStorage then ExtraFeatures.V8.SaveSettingsToStorage(payload) end
    if saved then SetSettingsStatus("Settings saved")
    elseif ExtraFeatures.V8.ServerReady then SetSettingsStatus("Saving settings on server...")
    else SetSettingsStatus("Settings saved for this session") end
end

local function LoadSettings()
    local function apply(payload)
        if type(payload) ~= "table" then SetSettingsStatus("No saved settings found"); return end
        local ok, reason = ApplyConfigPayload(payload)
        if not ok then SetSettingsStatus("Settings load failed: " .. tostring(reason)); return end
        SyncSettingsUI()
        if ExtraFeatures.V8.SyncControls then ExtraFeatures.V8.SyncControls() end
        if ExtraFeatures.V8.ApplyLanguage then ExtraFeatures.V8.ApplyLanguage() end
        SetSettingsStatus("Settings loaded")
    end
    if ExtraFeatures.SessionBackupPreferred and SessionConfigBackup then apply(SessionConfigBackup); return end
    local payload
    if FileAPI.Available and FileExists(CONFIG_FILE) then
        local raw = SafeReadFile(CONFIG_FILE); payload = raw and SafeDecodeJSON(raw)
    end
    if payload then apply(payload); return end
    local state = ExtraFeatures.V8
    if state.ServerReady and state.Request then
        state.Request("ReadSettings", {PlaceId = game.PlaceId}, function(ok, response)
            if ok and response.Ok then apply(response.Settings or SessionConfigBackup)
            else apply(SessionConfigBackup or (state.Session().Settings or {})[tostring(game.PlaceId)]) end
        end)
    else
        apply(SessionConfigBackup or (state.Session and state.Session().Settings[tostring(game.PlaceId)]))
    end
end


local MenuProfilesFile = "HoodRivals_MenuProfiles_u" .. tostring(LocalPlayer.UserId) .. ".json"
local MenuProfiles = {}
local MenuProfileConnections = {}
local MenuProfilePopupConnections = {}
local MenuProfileList
local MenuProfilePopup

local function GenerateMenuProfileId()
    local ok, value = pcall(function()
        return HttpService:GenerateGUID(false)
    end)

    if ok and type(value) == "string" and value ~= "" then
        return value
    end

    return tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
end

local function DisconnectMenuProfileConnections()
    for _, conn in ipairs(MenuProfileConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    table.clear(MenuProfileConnections)
end

local function DisconnectMenuProfilePopupConnections()
    for _, conn in ipairs(MenuProfilePopupConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    table.clear(MenuProfilePopupConnections)
end

local function SaveMenuProfiles()
    for _, profile in ipairs(MenuProfiles) do profile.OwnerUserId = LocalPlayer.UserId end
    if ExtraFeatures.V8.SaveProfilesToStorage then ExtraFeatures.V8.SaveProfilesToStorage() end
    local encoded = SafeEncodeJSON(MenuProfiles)

    if not encoded then
        SetSettingsStatus(
            "Profiles kept for this session; JSON unavailable"
        )
        return false
    end

    if not FileAPI.Available then
        SetSettingsStatus(
            "Profiles kept for this session; filesystem unavailable"
        )
        return false
    end

    local ok = SafeWriteFile(MenuProfilesFile, encoded)

    if not ok then
        SetSettingsStatus(
            "Profiles kept for this session; write failed"
        )
        return false
    end

    return true
end

local function LoadMenuProfiles()
    MenuProfiles = {}

    if not FileAPI.Available then
        return
    end

    if not FileExists(MenuProfilesFile) then
        return
    end

    local raw = SafeReadFile(MenuProfilesFile)

    if not raw then
        SetSettingsStatus(
            "Profile load skipped: file read failed"
        )
        return
    end

    local decoded = SafeDecodeJSON(raw)

    if type(decoded) ~= "table" then
        SetSettingsStatus(
            "Profile load skipped: invalid file"
        )
        return
    end

    local cleaned = {}
    local usedIds = {}

    for _, profile in ipairs(decoded) do
        if type(profile) == "table" and (profile.OwnerUserId == nil or profile.OwnerUserId == LocalPlayer.UserId) then
            local rawName =
                type(profile.ProfileName) == "string"
                and profile.ProfileName
                or profile.name

            local rawConfig =
                type(profile.ConfigData) == "table"
                and profile.ConfigData
                or profile.config

            if type(rawName) == "string"
                and type(rawConfig) == "table"
            then
                local name = TrimString(rawName)
                local gameName =
                    type(profile.GameName) == "string"
                    and profile.GameName
                    or (
                        type(profile.gameName) == "string"
                        and profile.gameName
                        or "Unknown"
                    )

                local placeId =
                    IsFiniteNumber(profile.PlaceId)
                    and profile.PlaceId
                    or (
                        IsFiniteNumber(profile.placeId)
                        and profile.placeId
                        or 0
                    )

                local version =
                    IsFiniteNumber(profile.Version)
                    and profile.Version
                    or (
                        IsFiniteNumber(profile.version)
                        and profile.version
                        or 1
                    )

                local createdAt =
                    IsFiniteNumber(profile.CreatedAt)
                    and profile.CreatedAt
                    or (
                        IsFiniteNumber(profile.createdAt)
                        and profile.createdAt
                        or 0
                    )

                local profileId =
                    type(profile.ProfileId) == "string"
                    and profile.ProfileId
                    or (
                        type(profile.profileId) == "string"
                        and profile.profileId
                        or GenerateMenuProfileId()
                    )

                if usedIds[profileId] then
                    profileId = GenerateMenuProfileId()
                end

                if name ~= "" then
                    table.insert(cleaned, {
                        OwnerUserId = LocalPlayer.UserId,
                        ProfileId = profileId,
                        ProfileName = name,
                        GameName = gameName,
                        PlaceId = placeId,
                        Version = version,
                        CreatedAt = createdAt,
                        ConfigData = rawConfig,

                        -- Legacy aliases kept for old code/profile compatibility.
                        profileId = profileId,
                        name = name,
                        gameName = gameName,
                        placeId = placeId,
                        version = version,
                        createdAt = createdAt,
                        config = rawConfig
                    })

                    usedIds[profileId] = true
                end
            end
        end
    end

    MenuProfiles = cleaned

    -- Persist migrated ProfileId fields when the filesystem is available.
    if #cleaned > 0 then
        pcall(function()
            SaveMenuProfiles()
        end)
    end
end

local function FindMenuProfile(identifier)
    local query = TrimString(tostring(identifier or ""))
    local lowered = string.lower(query)

    for _, profile in ipairs(MenuProfiles) do
        local profileId = tostring(profile.ProfileId or profile.profileId or "")
        if profileId ~= "" and profileId == query then
            return profile
        end
    end

    for _, profile in ipairs(MenuProfiles) do
        local name = TrimString(tostring(profile.ProfileName or profile.name or ""))
        if name ~= "" and string.lower(name) == lowered then
            return profile
        end
    end

    return nil
end

local function ApplyMenuProfile(profile)
    if type(profile) ~= "table"
        or type(profile.config) ~= "table"
    then
        SetSettingsStatus(
            "Profile apply failed: invalid profile"
        )
        return
    end

    local ok, err =
        ApplyConfigPayload(profile.config)

    if not ok then
        SetSettingsStatus(
            "Profile apply failed: "
            .. tostring(err)
        )
        return
    end

    SyncSettingsUI()
    SetSettingsStatus(
        "Profile loaded: "
        .. tostring(profile.name)
    )
end

local function DeleteMenuProfile(identifier)
    local query = TrimString(tostring(identifier or ""))
    local lowered = string.lower(query)
    local indexToRemove

    for index, profile in ipairs(MenuProfiles) do
        local profileId = tostring(profile.ProfileId or profile.profileId or "")
        if profileId ~= "" and profileId == query then
            indexToRemove = index
            break
        end
    end

    if not indexToRemove then
        for index, profile in ipairs(MenuProfiles) do
            local name = TrimString(tostring(profile.ProfileName or profile.name or ""))
            if name ~= "" and string.lower(name) == lowered then
                indexToRemove = index
                break
            end
        end
    end

    if not indexToRemove then
        return false
    end

    table.remove(MenuProfiles, indexToRemove)
    SaveMenuProfiles()

    return true
end

local function DestroyMenuProfilePopup()
    DisconnectMenuProfilePopupConnections()

    if MenuProfilePopup
        and MenuProfilePopup.Parent
    then
        MenuProfilePopup:Destroy()
    end

    MenuProfilePopup = nil
end

local function RefreshMenuProfileList()
    if not MenuProfileList then return end
    DisconnectMenuProfileConnections()
    for _, child in ipairs(MenuProfileList:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
    end
    for index, profile in ipairs(MenuProfiles) do
        local item = Instance.new("Frame")
        item.Name = "MenuProfile_" .. index
        item.Size = UDim2.new(1, -4, 0, 84)
        item.BackgroundColor3 = Config.DarkBg; item.BorderSizePixel = 0; item.Parent = MenuProfileList
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 7); corner.Parent = item
        local name = Instance.new("TextLabel")
        name.Name = "ProfileTitle"; name.Size = UDim2.new(1, -16, 0, 20); name.Position = UDim2.fromOffset(8, 5)
        name.BackgroundTransparency = 1; name.Text = tostring(profile.ProfileName or profile.name)
        name.Font = Enum.Font.GothamBold; name.TextSize = 13; name.TextColor3 = Config.TextColor
        name.TextXAlignment = Enum.TextXAlignment.Left; name.TextTruncate = Enum.TextTruncate.AtEnd; name.Parent = item
        local metadata = name:Clone()
        metadata.Name = "ProfileMetadata"; metadata.Position = UDim2.fromOffset(8, 25)
        metadata.Text = tostring(profile.GameName or profile.gameName) .. "  ·  Place " .. tostring(profile.PlaceId or profile.placeId)
        metadata.Font = Enum.Font.GothamMedium; metadata.TextSize = 10; metadata.TextColor3 = Config.SubTextColor
        metadata.Parent = item
        local run = UI:CreateButton(item, "RUN", function() ApplyMenuProfile(profile) end)
        run.Name = "RunProfile"; run.Size = UDim2.new(0.35, -8, 0, 28); run.Position = UDim2.fromOffset(8, 49)
        local options = UI:CreateButton(item, "…", function() ExtraFeatures.ProfileActions(profile) end)
        options.Name = "ProfileOptions"; options.Size = UDim2.new(0.2, -8, 0, 28); options.Position = UDim2.new(0.35, 4, 0, 49)
        local remove = UI:CreateButton(item, "DELETE", function() ExtraFeatures.ConfirmProfileDelete(profile) end)
        remove.Name = "DeleteProfile"; remove.Size = UDim2.new(0.45, -12, 0, 28); remove.Position = UDim2.new(0.55, 0, 0, 49)
        run.TextTruncate, remove.TextTruncate = Enum.TextTruncate.AtEnd, Enum.TextTruncate.AtEnd
        remove.TextColor3 = Color3.fromRGB(255, 147, 147)
    end
    MenuProfileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    MenuProfileList.CanvasSize = UDim2.new()
end


local function OpenSaveMenuProfilePopup()
    ExtraFeatures.OpenProfileEditor("Create")
end


LoadMenuProfiles()

UIRefs.ExtraSettingsSection =
    UI:CreateSection(
        SettingsPage,
        "FEATURE SETTINGS"
    )

do
    local ok, err = pcall(function()
        UIRefs.Toggles.AntiAFK =
            UI:CreateToggle(
                UIRefs.ExtraSettingsSection,
                {
                    Text = "Anti-AFK",
                    Default = Config.AntiAFKEnabled,
                    Callback = function(value)
                        local ok =
                            ExtraFeatures.SetAntiAFK(value)

                        if value and not ok
                            and UIRefs.Toggles.AntiAFK
                        then
                            UIRefs.Toggles.AntiAFK.Set(
                                false,
                                true
                            )
                        end
                    end
                }
            )    end)

    if not ok then
        Config.AntiAFKEnabled = false
        warn("[Hood Rivals] Anti-AFK UI skipped: " .. tostring(err))
    end
end

UIRefs.GamePassSpooferButton =
    UI:CreateButton(
        UIRefs.ExtraSettingsSection,
        "Game Pass Spoofer",
        function()
            ExtraFeatures.EnableGamePassSpoofer()
        end
    )

UI:CreateLabel(
    UIRefs.ExtraSettingsSection,
    "Game Pass Spoofer is client-side only; server ownership is unchanged."
)

UIRefs.Toggles.HoldToSpam =
    UI:CreateToggle(
        UIRefs.ExtraSettingsSection,
        {
            Text = "Hold to Spam",
            Default = Config.HoldToSpamEnabled,
            Callback = function(value)
                Config.HoldToSpamEnabled =
                    value == true

                if not Config.HoldToSpamEnabled then
                    ExtraFeatures.HoldSpamKeyHeld = false
                    ExtraFeatures.HoldSpamRightHeld = false
                    ExtraFeatures.HoldSpamAccumulator = 0
                end
            end
        }
    )

UIRefs.HoldToSpamKeyBox =
    Instance.new("TextButton")
UIRefs.HoldToSpamKeyBox.Name =
    "HoldToSpamKeyBox"
UIRefs.HoldToSpamKeyBox.Size =
    UDim2.new(1, 0, 0, 30)
UIRefs.HoldToSpamKeyBox.Text =
    "Hold to Spam Key: "
    .. Config.HoldToSpamKey.Name
UIRefs.HoldToSpamKeyBox.Parent =
    UIRefs.ExtraSettingsSection

ExtraFeatures.StyleKeyButton(
    UIRefs.HoldToSpamKeyBox
)

AddConnection(
    UIRefs.HoldToSpamKeyBox.MouseButton1Click:Connect(
        function()
            if ExtraFeatures.HoldSpamListening then
                ExtraFeatures.HoldSpamListening = false
                ExtraFeatures.HoldSpamKeyBox = nil

                UIRefs.HoldToSpamKeyBox.Text =
                    "Hold to Spam Key: "
                    .. Config.HoldToSpamKey.Name
                return
            end

            ExtraFeatures.HoldSpamListening = true
            ExtraFeatures.HoldSpamKeyBox =
                UIRefs.HoldToSpamKeyBox

            UIRefs.HoldToSpamKeyBox.Text =
                "Press Key..."
        end
    )
)

UIRefs.UIEffectsSection =
    UI:CreateSection(
        SettingsPage,
        "UI EFFECTS"
    )

UIRefs.Toggles.VirtualPet =
    UI:CreateToggle(
        UIRefs.UIEffectsSection,
        {
            Text = "Virtual Pet",
            Default = Config.VirtualPetEnabled,
            Callback = function(value)
                local ok =
                    ExtraFeatures.SetVirtualPetEnabled(value)

                if value and not ok
                    and UIRefs.Toggles.VirtualPet
                then
                    UIRefs.Toggles.VirtualPet.Set(
                        false,
                        true
                    )
                end
            end
        }
    )

UIRefs.Toggles.Snowfall =
    UI:CreateToggle(
        UIRefs.UIEffectsSection,
        {
            Text = "Snowfall",
            Default = Config.SnowfallEnabled,
            Callback = function(value)
                local ok =
                    ExtraFeatures.SetSnowfallEnabled(value)

                if value and not ok
                    and UIRefs.Toggles.Snowfall
                then
                    UIRefs.Toggles.Snowfall.Set(
                        false,
                        true
                    )
                end
            end
        }
    )

UIRefs.ConfigSaveLoadSec =
    UI:CreateSection(
        SettingsPage,
        "CONFIG SAVE / LOAD"
    )

UI:CreateButton(
    UIRefs.ConfigSaveLoadSec,
    "SAVE SETTINGS",
    function()
        SaveSettings()
    end
)

UI:CreateButton(
    UIRefs.ConfigSaveLoadSec,
    "LOAD SETTINGS",
    function()
        LoadSettings()
    end
)

UI:CreateLabel(
    UIRefs.ConfigSaveLoadSec,
    "Shortcut: hold CTRL + C + V to load settings"
)

SettingsStatusLabel =
    UI:CreateLabel(
        UIRefs.ConfigSaveLoadSec,
        "Ready"
    )


UIRefs.MenuProfileSec =
    UI:CreateSection(
        SettingsPage,
        "SAVE / LOAD MENU"
    )

UI:CreateLabel(
    UIRefs.MenuProfileSec,
    "YOUR MENU PROFILES"
        .. "\nCurrent Game: "
        .. tostring(CurrentGameName)
        .. "\nCurrent PlaceId: "
        .. tostring(CurrentPlaceId)
        .. "\nProfiles belong to your User ID."
)

UI:CreateButton(
    UIRefs.MenuProfileSec,
    "SAVE MENU",
    function()
        OpenSaveMenuProfilePopup()
    end
)

MenuProfileList =
    Instance.new("ScrollingFrame")

MenuProfileList.Name =
    "MenuProfileList"
MenuProfileList.Size =
    UDim2.new(1, 0, 0, 190)
MenuProfileList.BackgroundTransparency = 1
MenuProfileList.BorderSizePixel = 0
MenuProfileList.ScrollBarThickness = 3
MenuProfileList.ScrollBarImageColor3 =
    Config.SubTextColor
MenuProfileList.Parent = UIRefs.MenuProfileSec

UIRefs.MenuProfileListLayout =
    Instance.new("UIListLayout")

UIRefs.MenuProfileListLayout.SortOrder =
    Enum.SortOrder.LayoutOrder
UIRefs.MenuProfileListLayout.Padding =
    UDim.new(0, 6)
UIRefs.MenuProfileListLayout.Parent =
    MenuProfileList

UIRefs.MenuProfileListPadding =
    Instance.new("UIPadding")

UIRefs.MenuProfileListPadding.PaddingTop =
    UDim.new(0, 2)
UIRefs.MenuProfileListPadding.PaddingBottom =
    UDim.new(0, 2)
UIRefs.MenuProfileListPadding.Parent =
    MenuProfileList

RefreshMenuProfileList()

if not FileAPI.Available then
    SetSettingsStatus(
        "Connecting player storage..."
    )
end


-- Initialize optional UI decorations only after the base GUI,
-- PageManager and SETTINGS controls have been created.
pcall(function()
    ExtraFeatures.InitializeUIEffects()
end)

-- =========================================================
-- TAB: KHÁC
-- Existing OTHER features remain unchanged.
-- =========================================================
PageManager:AddPage("KHÁC")

UIRefs.Toggles.ThirdPersonLock =
    UI:CreateToggle(
        UI:CreateSection(
            GUIState.Pages["KHÁC"],
            "CAMERA / VISUAL"
        ),
        {
            Text = "Third Person Lock",
            Default = Config.ThirdPersonLock,
            Callback = function(value)
                OtherSystem.SetThirdPerson(value)
            end
        }
    )

UIRefs.Toggles.XRayEnabled =
    UI:CreateToggle(
        GUIState.Pages["KHÁC"]:FindFirstChild(
            "CAMERA / VISUALSection"
        ),
        {
            Text = "X-Ray",
            Default = Config.XRayEnabled,
            Callback = function(value)
                OtherSystem.SetXRay(value)
            end
        }
    )

UIRefs.Sliders.XRayTransparency =
    UI:CreateSlider(
        GUIState.Pages["KHÁC"]:FindFirstChild(
            "CAMERA / VISUALSection"
        ),
        {
            Text = "X-Ray Transparency",
            Min = 0.3,
            Max = 1.0,
            Default = Config.XRayTransparency,
            Increment = 0.01,
            EditableValue = true,
            AllowTextInputBeyondRange = false,
            Callback = function(value)
                Config.XRayTransparency =
                    math.clamp(value, 0.3, 1.0)
                OtherSystem.UpdateXRayTransparency()
            end
        }
    )

UI:CreateButton(
    UI:CreateSection(
        GUIState.Pages["KHÁC"],
        "SERVER"
    ),
    "↻  Đổi Server",
    function()
        OtherSystem.RunServerAction("Change")
    end
)

UI:CreateButton(
    GUIState.Pages["KHÁC"]:FindFirstChild(
        "SERVERSection"
    ),
    "⌁  Ping Thấp",
    function()
        OtherSystem.RunServerAction("Ping")
    end
)

UI:CreateButton(
    GUIState.Pages["KHÁC"]:FindFirstChild(
        "SERVERSection"
    ),
    "↓  Ít Người",
    function()
        OtherSystem.RunServerAction("Small")
    end
)

UI:CreateButton(
    UI:CreateSection(
        GUIState.Pages["KHÁC"],
        "REJOIN / MENU"
    ),
    "↩  Rejoin",
    function()
        OtherSystem.Rejoin()
    end
)

UIRefs.OtherHideRow = Instance.new("Frame")
UIRefs.OtherHideRow.Size = UDim2.new(1, 0, 0, 30)
UIRefs.OtherHideRow.BackgroundTransparency = 1
UIRefs.OtherHideRow.Parent =
    GUIState.Pages["KHÁC"]:FindFirstChild(
        "REJOIN / MENUSection"
    )

UIRefs.OtherHideButton =
    UI:CreateButton(
        UIRefs.OtherHideRow,
        "Hide GUI",
        function()
            if SetMenuState then
                SetMenuState("Minimized")
            end
        end
    )

UIRefs.OtherHideButton.TextXAlignment =
    Enum.TextXAlignment.Left

UIRefs.OtherToggleKeyBox = Instance.new("TextButton")
UIRefs.OtherToggleKeyBox.Name = "ToggleKeyBox"
UIRefs.OtherToggleKeyBox.Size = UDim2.new(0, 105, 0, 24)
UIRefs.OtherToggleKeyBox.Position =
    UDim2.new(1, -110, 0.5, -12)
UIRefs.OtherToggleKeyBox.Text =
    Config.ToggleKey.Name
UIRefs.OtherToggleKeyBox.TextColor3 = Config.TextColor
UIRefs.OtherToggleKeyBox.Font = Enum.Font.GothamMedium
UIRefs.OtherToggleKeyBox.TextSize = 11
UIRefs.OtherToggleKeyBox.BackgroundColor3 = Config.DarkBg
UIRefs.OtherToggleKeyBox.AutoButtonColor = false
UIRefs.OtherToggleKeyBox.ZIndex = 3
UIRefs.OtherToggleKeyBox.Parent = UIRefs.OtherHideRow

UIRefs.OtherKeybindCorner =
    Instance.new("UICorner")
UIRefs.OtherKeybindCorner.CornerRadius = UDim.new(0, 5)
UIRefs.OtherKeybindCorner.Parent = UIRefs.OtherToggleKeyBox

UIRefs.OtherKeybindStroke =
    Instance.new("UIStroke")
UIRefs.OtherKeybindStroke.Color = Config.BorderColor
UIRefs.OtherKeybindStroke.Thickness = 1
UIRefs.OtherKeybindStroke.Parent = UIRefs.OtherToggleKeyBox

AddConnection(
    UIRefs.OtherToggleKeyBox.MouseButton1Click:Connect(
        function()
            OtherSystem.BeginKeybindCapture(
                UIRefs.OtherToggleKeyBox
            )
        end
    )
)

-- Initialize NPC detection after the GUI/settings framework is ready.
pcall(function()
    NPCSystem.Initialize()
end)

-- =========================================================
-- RENDER PIPELINE
-- Keep Player/Teleport at the existing Character stage.
--
-- Camera pipeline:
--   game/weapon camera updates
--          ↓
--   AIM at Last - 1
--          ↓
--   ESP at Last
--
-- This makes ESP see the final same-frame camera after AIM,
-- while AIM itself runs after the normal/custom camera changes
-- made earlier in the frame.
-- =========================================================

function ExtraFeatures.SafeFrameStep(name, callback, ...)
    local ok, reason = pcall(callback, ...)
    if ok then return end
    local state = UIRefs.Experience
    state.LastRenderError = state.LastRenderError or {}
    local last = state.LastRenderError[name] or -math.huge
    if os.clock() - last < 5 then return end
    state.LastRenderError[name] = os.clock()
    local message = name .. ": " .. tostring(reason)
    table.insert(state.Errors, {Time = os.time(), Text = message})
    if #state.Errors > 40 then table.remove(state.Errors, 1) end
    warn("[Hood Rivals] " .. message)
end

function ExtraFeatures.StopRenderPipeline()
    UIRefs.Experience.RenderRunning = false
    RunService:UnbindFromRenderStep("HoodRivalsUnifiedRender")
    RunService:UnbindFromRenderStep("HoodRivalsAimRender")
    RunService:UnbindFromRenderStep("HoodRivalsESPRender")
end

function ExtraFeatures.StartRenderPipeline()
    if UIRefs.Experience.Destroyed or UIRefs.Experience.RenderRunning then return end
    ExtraFeatures.StopRenderPipeline()
    UIRefs.Experience.RenderRunning = true
    RunService:BindToRenderStep("HoodRivalsUnifiedRender", Enum.RenderPriority.Character.Value + 1,
        function(renderDt)
            ExtraFeatures.SafeFrameStep("PLAYER", UpdatePlayer, renderDt)
            ExtraFeatures.SafeFrameStep("TELEPORT", UpdateTeleport)
            ExtraFeatures.SafeFrameStep("Head Hitbox", ExtraFeatures.UpdateHeadHitboxes, renderDt, false)
            ExtraFeatures.SafeFrameStep("Hold to Spam", ExtraFeatures.UpdateHoldSpam, renderDt)
            ExtraFeatures.SafeFrameStep("Sliders", ExtraFeatures.UpdateHeavySliders, renderDt)
            ExtraFeatures.SafeFrameStep("FUNCTION 1", ExtraFeatures.UpdateFunction1, renderDt)
            ExtraFeatures.SafeFrameStep("UI effects", ExtraFeatures.UpdateFloatingStatus, renderDt)
            if ExtraFeatures.UpdateInterfaceStatus then
                ExtraFeatures.SafeFrameStep("Interface status", ExtraFeatures.UpdateInterfaceStatus, renderDt)
            end
        end)
    RunService:BindToRenderStep("HoodRivalsAimRender", Enum.RenderPriority.Last.Value - 1,
        function(renderDt)
            ExtraFeatures.SafeFrameStep("Telekill", Telekill.Update, renderDt)
            ExtraFeatures.SafeFrameStep("Target Assist", ExtraFeatures.UpdateTargetAssist)
            ExtraFeatures.SafeFrameStep("AimSilent", ExtraFeatures.UpdateAimSilent)
            if not ExtraFeatures.Function1.DroneStrike.Active then
                ExtraFeatures.SafeFrameStep("AIM", UpdateAim)
            end
            ExtraFeatures.SafeFrameStep("FOV", UpdateFOVCircle)
            ExtraFeatures.SafeFrameStep("Menu input", OtherSystem.UpdateMenuInput)
        end)
    RunService:BindToRenderStep("HoodRivalsESPRender", Enum.RenderPriority.Last.Value,
        function()
            local camera = Workspace.CurrentCamera
            ExtraFeatures.SafeFrameStep("ESP", updateESP, camera)
            ExtraFeatures.SafeFrameStep("Highlight", UpdateESPHighlight)
            if ExtraFeatures.V8.Update then ExtraFeatures.SafeFrameStep("V8 overlays", ExtraFeatures.V8.Update, camera) end
        end)
end

function ExtraFeatures.PauseRuntime()
    if UIRefs.Experience.ClosedSnapshot then return end
    local saved = {XRay = Config.XRayEnabled, ThirdPerson = Config.ThirdPersonLock,
        AntiAFK = Config.AntiAFKEnabled}
    UIRefs.Experience.ClosedSnapshot = saved
    ExtraFeatures.StopRenderPipeline()
    if ExtraFeatures.V8.Pause then ExtraFeatures.V8.Pause() end
    OtherSystem.Cleanup()
    ExtraFeatures.SetAntiAFK(false)
    ExtraFeatures.StopVirtualPet()
    ExtraFeatures.DestroySnowfall()
    Config.XRayEnabled, Config.ThirdPersonLock, Config.AntiAFKEnabled = saved.XRay, saved.ThirdPerson, saved.AntiAFK
    ExtraFeatures.HoldSpamKeyHeld, ExtraFeatures.HoldSpamRightHeld = false, false
    ExtraFeatures.HoldSpamListening, ExtraFeatures.HoldSpamKeyBox = false, nil
    table.clear(OtherSystem.ActiveFireTouches)
    TouchFireActive = false
    if MenuProfilePopup then DestroyMenuProfilePopup() end
    for _, reset in ipairs(UIRefs.Experience.DragResetters) do pcall(reset) end
end

function ExtraFeatures.ResumeRuntime()
    if UIRefs.Experience.Destroyed then return end
    if UIRefs.Experience.ClosedSnapshot then
        local character, humanoid, root = GetLocalCharacterParts()
        PlayerRuntime.Character, PlayerRuntime.Humanoid, PlayerRuntime.RootPart = character, humanoid, root
        CaptureOriginalJumpPower(humanoid)
        OtherSystem.SetThirdPerson(Config.ThirdPersonLock)
        OtherSystem.SetXRay(Config.XRayEnabled)
        ExtraFeatures.SetAntiAFK(Config.AntiAFKEnabled)
        if Config.VirtualPetEnabled and not ExtraFeatures.UIEffects.VirtualPet.Enabled then ExtraFeatures.StartVirtualPet() end
        if Config.SnowfallEnabled and not ExtraFeatures.UIEffects.Snowfall.Enabled then ExtraFeatures.StartSnowfall() end
        UIRefs.Experience.ClosedSnapshot = nil
    end
    ExtraFeatures.StartRenderPipeline()
    if ExtraFeatures.V8.SyncWeapon then ExtraFeatures.V8.SyncWeapon() end
end

ExtraFeatures.StartRenderPipeline()


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

            if ExtraFeatures.TargetAssist.CurrentTarget == target then
                ExtraFeatures.ClearTargetAssist()
            end

            if ExtraFeatures.AimSilent.CurrentTarget == target then
                ExtraFeatures.ClearAimSilent()
            end

            if Telekill.CurrentTarget == target then
                Telekill.CurrentTarget = nil
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

            if ExtraFeatures.TargetAssist.CurrentTarget == target then
                ExtraFeatures.ClearTargetAssist()
            end

            if ExtraFeatures.AimSilent.CurrentTarget == target then
                ExtraFeatures.ClearAimSilent()
            end

            if Telekill.CurrentTarget == target then
                Telekill.CurrentTarget = nil
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

        if ExtraFeatures.TargetAssist.CurrentTarget == target then
            ExtraFeatures.ClearTargetAssist()
        end

        if ExtraFeatures.AimSilent.CurrentTarget == target then
            ExtraFeatures.ClearAimSilent()
        end

        if Telekill.CurrentTarget == target then
            Telekill.CurrentTarget = nil
        end

        if ExtraFeatures.Function1 then
            if ExtraFeatures.Function1.DroneStrike.Target == target then
                ExtraFeatures.Function1.DroneStrike.Target = nil
            end
            if ExtraFeatures.Function1.MagicSilent.Target == target then
                ExtraFeatures.Function1.MagicSilent.Target = nil
            end
        end

        RefreshTeleportPlayerList()
    end)
)


-- Mở mặc định Tab ESP
pcall(function()
    PageManager:ShowPage(Config.StartPage, true)
end)

-- ==========================================
-- 10. EVENT CONTROLS & MINIMIZE / CLOSE
-- ==========================================

SetMenuState = function(newState)
    local effects = ExtraFeatures.UIEffects

    if newState ~= "Closed"
        and effects
        and effects.AnimationBusy
    then
        return
    end

    GUIState.CurrentState = newState

    if newState == "Open" then
        ExtraFeatures.ResumeRuntime()
        ScreenGui.Enabled = true
        OtherSystem.SetMenuMouseState(true)
        pcall(function()
            ExtraFeatures.DestroyMinimizeChat()
        end)

        local ok = pcall(function()
            ExtraFeatures.AnimateMenuOpen()
        end)

        if not ok then
            MainWindow.Visible = true
            FloatingBtn.Visible = false
        end
    elseif newState == "Minimized" then
        OtherSystem.SetMenuMouseState(false)

        local ok = pcall(function()
            ExtraFeatures.AnimateMenuMinimize()
        end)

        if not ok then
            MainWindow.Visible = false
            FloatingBtn.Visible = true
            pcall(function()
                ExtraFeatures.ShowMinimizeChat()
            end)
        end
    elseif newState == "Closed" then
        ExtraFeatures.PauseRuntime()
        if effects then
            effects.AnimationBusy = false
            effects.Bubble.Token =
                effects.Bubble.Token + 1
        end

        pcall(function()
            ExtraFeatures.DestroyMinimizeChat()
        end)
        ScreenGui.Enabled = false
        OtherSystem.SetMenuMouseState(false)
    end
end

-- Minimize Button
MinimizeBtn.MouseButton1Click:Connect(function()
    SetMenuState("Minimized")
end)

-- Floating FPS panel doubles as the compact re-open control.
-- Dragging it does not accidentally open the menu.
FloatingBtn.MouseButton1Click:Connect(function()
    if isFloatDragged and isFloatDragged() then
        return
    end

    if GUIState.CurrentState == "Minimized"
        or GUIState.CurrentState == "Closed"
    then
        ScreenGui.Enabled = true

        -- FloatingBtn only becomes clickable after the minimize animation,
        -- so clearing a stale busy flag here is safe and prevents a dead click.
        if ExtraFeatures.UIEffects then
            ExtraFeatures.UIEffects.AnimationBusy = false
        end

        SetMenuState("Open")
    end
end)

-- Close Button
CloseBtn.MouseButton1Click:Connect(function()
    SetMenuState("Closed")

    CleanupPlayerRuntime()
    ExtraFeatures.RestoreAllHeadHitboxes()
    ExtraFeatures.ClearAimSilent()
    if ExtraFeatures.CleanupFunction1 then
        pcall(function() ExtraFeatures.CleanupFunction1() end)
    end
    ExtraFeatures.HoldSpamKeyHeld = false
    ExtraFeatures.HoldSpamRightHeld = false
    ExtraFeatures.HoldSpamAccumulator = 0

    pcall(function()
        RunService:UnbindFromRenderStep("HoodRivalsUnifiedRender")
        RunService:UnbindFromRenderStep("HoodRivalsAimRender")
        RunService:UnbindFromRenderStep("HoodRivalsESPRender")
    end)

    FOVCircle.Visible = false
    Telekill.CurrentTarget = nil
    Telekill.OrbitAngle = 0
    Telekill.AutoFireAccumulator = 0

    for target in pairs(espData) do
        destroyTargetESP(target)
    end

    destroyAllESPHighlights()
end)

-- Keybind Event (RightControl)
AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if ExtraFeatures.MarkUIActivity then
        ExtraFeatures.MarkUIActivity()
    end

    if OtherSystem.ConsumeNextToggleInput then
        OtherSystem.ConsumeNextToggleInput = false
        return
    end

    if OtherSystem.KeybindListening then
        return
    end

    if ExtraFeatures.HoldSpamListening then
        if input.UserInputType ~= Enum.UserInputType.Keyboard
            or input.KeyCode == Enum.KeyCode.Unknown
        then
            return
        end

        if not ExtraFeatures.ValidateShortcut(input.KeyCode, "HoldToSpam") then return end
        Config.HoldToSpamKey = input.KeyCode
        ExtraFeatures.HoldSpamListening = false

        if ExtraFeatures.HoldSpamKeyBox
            and ExtraFeatures.HoldSpamKeyBox.Parent
        then
            ExtraFeatures.HoldSpamKeyBox.Text =
                "Hold to Spam Key: "
                .. Config.HoldToSpamKey.Name
        end

        ExtraFeatures.HoldSpamKeyBox = nil
        return
    end

    local focusedTextBox = UserInputService:GetFocusedTextBox()

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Config.HoldToSpamKey
            and Config.HoldToSpamEnabled
            and focusedTextBox == nil
            and not gameProcessed
            and GUIState.CurrentState ~= "Closed"
            and not UIRefs.Experience.OverlayOpen
        then
            ExtraFeatures.HoldSpamKeyHeld = true
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2
        and Config.HoldToSpamEnabled
        and focusedTextBox == nil
        and not gameProcessed
        and GUIState.CurrentState ~= "Closed"
        and not UIRefs.Experience.OverlayOpen
    then
        ExtraFeatures.HoldSpamRightHeld = true
    end

    if input.UserInputType == Enum.UserInputType.Keyboard
        and Config.HoldToSpamEnabled
        and input.KeyCode == Config.HoldToSpamKey
    then
        return
    end

    if focusedTextBox == nil and not gameProcessed and not UIRefs.Experience.OverlayOpen
        and (input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.V)
        and ExtraFeatures.V8.FavoriteChordDown and ExtraFeatures.V8.FavoriteChordDown() then
        if not ExtraFeatures.V8.FavoriteChordLatched then
            ExtraFeatures.V8.FavoriteChordLatched = true
            ExtraFeatures.V8.OpenFavorites()
        end
        return
    end
    -- CTRL + C + V: open SETTINGS and load the normal saved settings.
    -- The chord is ignored while typing in a TextBox so copy/paste remains safe.
    if focusedTextBox == nil
        and (
            input.KeyCode == Enum.KeyCode.C
            or input.KeyCode == Enum.KeyCode.V
        )
        and OtherSystem.IsSettingsLoadChordDown()
    then
        if not OtherSystem.SettingsLoadChordLatched then
            OtherSystem.SettingsLoadChordLatched = true

            pcall(function()
                LoadSettings()
                PageManager:ShowPage("SETTINGS", true)

                if GUIState.CurrentState ~= "Open" then
                    ScreenGui.Enabled = true

                    if ExtraFeatures.UIEffects then
                        ExtraFeatures.UIEffects.AnimationBusy = false
                    end

                    SetMenuState("Open")
                end
            end)
        end

        return
    end

    if focusedTextBox == nil
        and input.UserInputType == Enum.UserInputType.Keyboard
        and (
            input.KeyCode == Enum.KeyCode.LeftControl
            or input.KeyCode == Enum.KeyCode.RightControl
            or input.KeyCode == Enum.KeyCode.One
            or input.KeyCode == Enum.KeyCode.Two
        )
        and OtherSystem.IsTelekillToggleChordDown()
    then
        -- Ctrl + 1 + 2 toggles the whole Telekill feature.
        -- The latch prevents repeated ON/OFF while the chord is held.
        if not OtherSystem.TelekillToggleChordLatched then
            OtherSystem.TelekillToggleChordLatched = true

            local nextTelekillState =
                not Config.TelekillEnabled

            Config.TelekillEnabled =
                nextTelekillState

            if not nextTelekillState then
                Telekill.CurrentTarget = nil
                Telekill.OrbitAngle = 0
                Telekill.AutoFireAccumulator = 0
                CurrentAimTarget = nil
            end

            if UIRefs.Toggles.TelekillEnabled then
                UIRefs.Toggles.TelekillEnabled.Set(
                    nextTelekillState,
                    true
                )
            end
        end

        return
    end

    if gameProcessed then return end
    if UIRefs.Experience.OverlayOpen then return end
    if GUIState.CurrentState == "Closed" and input.KeyCode ~= Config.ToggleKey then return end

    if focusedTextBox == nil then
        if input.UserInputType == Enum.UserInputType.Keyboard
            and Config.TelekillEnabled
            and input.KeyCode == Config.TelekillSwitchKey
        then
            pcall(function()
                Telekill.SwitchToNextTarget()
            end)
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode == Config.DroneStrikeKey
        then
            pcall(function()
                ExtraFeatures.SetDroneStrikeActive(
                    not ExtraFeatures.Function1.DroneStrike.Active
                )
            end)
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            and (
                Config.AimSilentEnabled
                or Config.MagicSilentEnabled
                or (
                    Config.HeadHitboxEnabled
                    and (tonumber(Config.HeadHitboxSize) or 0) > 0
                )
            )
        then
            pcall(function()
                if Config.AimSilentEnabled
                    or Config.MagicSilentEnabled
                then
                    ExtraFeatures.ShowSilentShotFeedback()
                end

                ExtraFeatures.RequestDeveloperCombatShot()
            end)
        end
    end

    if Config.ToggleKeyEnabled and input.KeyCode == Config.ToggleKey then
        if GUIState.CurrentState == "Open" then
            SetMenuState("Minimized")
        elseif GUIState.CurrentState == "Minimized" or GUIState.CurrentState == "Closed" then
            ScreenGui.Enabled = true

            SetMenuState("Open")
        end
    end
end))

AddConnection(
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Config.HoldToSpamKey then
                ExtraFeatures.HoldSpamKeyHeld = false
                ExtraFeatures.HoldSpamAccumulator = 0
            end

            if input.KeyCode == Enum.KeyCode.C
                or input.KeyCode == Enum.KeyCode.V
                or input.KeyCode == Enum.KeyCode.LeftControl
                or input.KeyCode == Enum.KeyCode.RightControl
            then
                OtherSystem.SettingsLoadChordLatched = false
            end

            if input.KeyCode == Enum.KeyCode.One
                or input.KeyCode == Enum.KeyCode.Two
                or input.KeyCode == Enum.KeyCode.LeftControl
                or input.KeyCode == Enum.KeyCode.RightControl
            then
                OtherSystem.TelekillToggleChordLatched = false
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            ExtraFeatures.HoldSpamRightHeld = false
            ExtraFeatures.HoldSpamAccumulator = 0
        end
    end)
)

-- Expose UI Framework global variable
local function CleanupFramework()
    CleanupPlayerRuntime()
    OtherSystem.Cleanup()
    if ExtraFeatures.V8.Cleanup then ExtraFeatures.V8.Cleanup() end
    UIRefs.Experience.Destroyed = true
    UIRefs.Experience.RenderRunning = false
    if ExtraFeatures.DestroyInterface then ExtraFeatures.DestroyInterface() end

    pcall(function()
        RunService:UnbindFromRenderStep(
            "HoodRivalsUnifiedRender"
        )
        RunService:UnbindFromRenderStep(
            "HoodRivalsAimRender"
        )
        RunService:UnbindFromRenderStep(
            "HoodRivalsESPRender"
        )
    end)

    FOVCircle.Visible = false
    Telekill.CurrentTarget = nil
    Telekill.OrbitAngle = 0
    Telekill.AutoFireAccumulator = 0

    for target in pairs(espData) do
        destroyTargetESP(target)
    end

    destroyAllESPHighlights()

    for model in pairs(NPCSystem.ValidNPCs) do
        NPCSystem.Unregister(model)
    end

    NPCSystem.Initialized = false

    DisconnectMenuProfileConnections()
    DisconnectMenuProfilePopupConnections()
    DestroyMenuProfilePopup()
    ExtraFeatures.Cleanup()

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
    table.clear(Connections)
end

_G.MyGUIFramework = {
    PageManager = PageManager,
    UI = UI,
    ScreenGui = ScreenGui,
    MainWindow = MainWindow,
    Config = Config,

    Settings = {
        Page = SettingsPage,
        Save = SaveSettings,
        Load = LoadSettings,
        SaveProfile = OpenSaveMenuProfilePopup,
        GetProfiles = function()
            return MenuProfiles
        end
    },

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
        end,
        GetSilentTarget = function()
            return ExtraFeatures.AimSilent.CurrentTarget
        end
    },

    NPC = NPCSystem,

    Function1 = {
        SetDroneStrikeActive = ExtraFeatures.SetDroneStrikeActive,
        Cleanup = ExtraFeatures.CleanupFunction1
    },

    Notification = {
        Open = ExtraFeatures.OpenNotificationView,
        GetText = function()
            return ExtraFeatures.NotificationText
        end
    },

    Cleanup = CleanupFramework
}

AddConnection(
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode == Enum.KeyCode.F4
            and not OtherSystem.KeybindListening
            and not ExtraFeatures.HoldSpamListening
            and not UIRefs.Experience.OverlayOpen
            and UserInputService:GetFocusedTextBox() == nil
        then
            if type(CleanupFramework) == "function" then
                CleanupFramework()
            end

            GUIState.CurrentState = "Closed"

            pcall(function()
                if ScreenGui then
                    ScreenGui:Destroy()
                end
            end)

            _G.MyGUIFramework = nil
        end
    end)
)

print("[Hood Rivals Framework & ESP Integrated Successfully!]")


-- Interface upgrade: all gameplay engines above retain their established logic.

function ExtraFeatures.ViewBounds()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local scale = math.max(UIScaleObj.Scale, 0.01)
    local insetTop, insetBottom = Vector2.zero, Vector2.zero
    pcall(function() insetTop, insetBottom = game:GetService("GuiService"):GetGuiInset() end)
    local margin = 10 / scale
    return viewport.X / scale, viewport.Y / scale, margin,
        math.max(margin, insetTop.Y / scale + margin),
        math.max(margin, insetBottom.Y / scale + margin)
end

function ExtraFeatures.ClampInterfaceFrame(frame)
    if not frame or not frame.Parent then return end
    local width, height, margin, top, bottom = ExtraFeatures.ViewBounds()
    local fw = frame.Size.X.Scale * width + frame.Size.X.Offset
    local fh = frame.Size.Y.Scale * height + frame.Size.Y.Offset
    local x = frame.Position.X.Scale * width + frame.Position.X.Offset
    local y = frame.Position.Y.Scale * height + frame.Position.Y.Offset
    x = math.clamp(x, margin, math.max(margin, width - margin - fw))
    y = math.clamp(y, top, math.max(top, height - bottom - fh))
    frame.Position = UDim2.fromOffset(x, y)
    if frame == MainWindow then
        Config.Interface.Window.X = (x - margin) / math.max(1, width - margin * 2 - fw)
        Config.Interface.Window.Y = (y - top) / math.max(1, height - bottom - top - fh)
        if UIRefs.Experience.Shadow then
            UIRefs.Experience.Shadow.Position = UDim2.fromOffset(x + 4, y + 7)
            UIRefs.Experience.Shadow.Size = frame.Size
        end
    end
end

UIRefs.Experience.ClampFrame = ExtraFeatures.ClampInterfaceFrame

function ExtraFeatures.ApplyInterfaceLayout(resetPosition)
    local state = UIRefs.Experience
    if not state.Ready then return end
    local width, height, margin, top, bottom = ExtraFeatures.ViewBounds()
    local preferred = Config.Interface.Window
    local w = math.min(preferred.Width or 720, math.max(1, width - margin * 2))
    local h = math.min(preferred.Height or 520, math.max(1, height - top - bottom))
    MainWindow.Size = UDim2.fromOffset(w, h)
    if resetPosition then
        local nx = math.clamp(tonumber(preferred.X) or 0.5, 0, 1)
        local ny = math.clamp(tonumber(preferred.Y) or 0.5, 0, 1)
        MainWindow.Position = UDim2.fromOffset(margin + math.max(0, width - margin * 2 - w) * nx,
            top + math.max(0, height - top - bottom - h) * ny)
    end
    local compact = Config.Interface.CompactSidebar or w < 560
    local narrow = w < 400
    local sidebarWidth = compact and 80 or 154
    Header.Size = UDim2.new(1, 0, 0, 116)
    TopRow.Size = UDim2.new(1, 0, 0, 42)
    TitleLabel.Size = UDim2.new(1, -148, 1, 0)
    TitleLabel.Position = UDim2.fromOffset(16, 0)
    TitleLabel.TextSize = compact and 14 or 18
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    ControlButtons.Size = UDim2.fromOffset(120, 34)
    ControlButtons.Position = UDim2.new(1, -130, 0, 4)
    for index, button in ipairs({MinimizeBtn, UIRefs.NotificationButton, CloseBtn}) do
        button.Size = UDim2.fromOffset(32, 32)
        button.Position = UDim2.fromOffset((index - 1) * 40, 0)
        button.TextSize = 16
    end
    TopTabBar.Position = UDim2.fromOffset(16, 46)
    TopTabBar.Size = UDim2.new(1, -32, 0, 28)
    HeaderDivider.Position = UDim2.fromOffset(0, 115)
    Sidebar.Position = UDim2.fromOffset(0, 116)
    Sidebar.Size = UDim2.new(0, sidebarWidth, 1, -146)
    ContentArea.Position = UDim2.fromOffset(sidebarWidth + 1, 116)
    ContentArea.Size = UDim2.new(1, -sidebarWidth - 1, 1, -146)
    TabContainer.Position = UDim2.fromOffset(8, 12)
    TabContainer.Size = UDim2.new(1, -16, 1, -56)
    if narrow then
        Sidebar.Size = UDim2.new(1, 0, 0, 40)
        ContentArea.Position = UDim2.fromOffset(0, 156)
        ContentArea.Size = UDim2.new(1, 0, 1, -186)
        TabContainer.Position = UDim2.fromOffset(8, 4)
        TabContainer.Size = UDim2.new(1, -16, 1, -8)
    end
    TabContainer.ScrollingDirection = narrow and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
    TabContainer.AutomaticCanvasSize = narrow and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
    TabContainer:FindFirstChildOfClass("UIListLayout").FillDirection = narrow and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    AuthorLabel.Visible = not narrow
    AuthorLabel.TextSize = compact and 9 or 11
    local short = {OVERVIEW = "HOME", PLAYER = "PLAYER", AIM = "AIM", ESP = "ESP", NPC = "NPC",
        TELEPORT = "TP", SETTINGS = "SET", ["KHÁC"] = "KHÁC"}
    for name, button in pairs(GUIState.TabButtons) do
        if button.Parent == TabContainer then
            button.Size = narrow and UDim2.fromOffset(64, 32) or UDim2.new(1, 0, 0, compact and 38 or 36)
            button.TextSize = compact and 10 or 12
            button.Text = compact and (short[name] or name) or name
        end
    end
    if state.SearchBox then
        state.SearchBox.Size = UDim2.new(1, -108, 1, 0)
        state.SearchCount.Visible = not compact
        state.SearchBox.PlaceholderText = compact and "Search..." or "Search features..."
    end
    if state.FooterRight then
        state.FooterRight.Visible = not compact
        state.FooterLeft.Size = UDim2.new(compact and 1 or 0.56, -20, 1, 0)
    end
    local controlWidth = w - (narrow and 0 or sidebarWidth + 1) - 48
    local stacked = controlWidth < 270
    for _, record in ipairs(state.Controls) do
        if record.Kind == "Slider" then
            local api = record.API
            api.Frame.Size = UDim2.new(1, 0, 0, stacked and 84 or 62)
            api.Label.Size = UDim2.new(1, stacked and -60 or -160, 0, 22)
            api.Value.Size = stacked and UDim2.new(1, 0, 0, 22) or UDim2.fromOffset(70, 22)
            api.Value.Position = stacked and UDim2.fromOffset(0, 24) or UDim2.new(1, -150, 0, 0)
            if record.Hint then record.Hint.Position = UDim2.fromOffset(0, stacked and 47 or 24) end
        elseif record.Kind == "Toggle" then
            record.API.Label.Size = UDim2.new(1, stacked and -82 or -94, 0, 23)
        end
    end
    ExtraFeatures.ClampInterfaceFrame(MainWindow)
    ExtraFeatures.ClampInterfaceFrame(FloatingBtn)
    for _, data in pairs(ActiveTpButtons) do ExtraFeatures.ClampInterfaceFrame(data.frame) end
    if state.ModalCard then ExtraFeatures.ClampInterfaceFrame(state.ModalCard) end
end

function ExtraFeatures.BuildInterfacePayload()
    local source = Config.Interface
    local favorites, collapsed = {}, {}
    for key, value in pairs(source.Favorites) do if value == true then favorites[key] = true end end
    for key, value in pairs(source.CollapsedSections) do if value == true then collapsed[key] = true end end
    return {ReducedMotion = source.ReducedMotion, ClickEffects = source.ClickEffects,
        SoundEffects = source.SoundEffects, SoundVolume = source.SoundVolume,
        Language = source.Language, OwnerUserId = LocalPlayer.UserId,
        RememberLayout = source.RememberLayout, CompactSidebar = source.CompactSidebar,
        Favorites = favorites, CollapsedSections = collapsed, LastPage = GUIState.ActivePage,
        Window = source.RememberLayout and {Width = source.Window.Width, Height = source.Window.Height,
            X = source.Window.X, Y = source.Window.Y} or nil}
end

function ExtraFeatures.ApplyInterfacePayload(payload)
    if type(payload) ~= "table" then return end
    if payload.OwnerUserId ~= nil and payload.OwnerUserId ~= LocalPlayer.UserId then return end
    local target = Config.Interface
    if payload.Language == "EN" or payload.Language == "VI" then target.Language = payload.Language end
    for _, key in ipairs({"ReducedMotion", "ClickEffects", "SoundEffects", "RememberLayout", "CompactSidebar"}) do
        if type(payload[key]) == "boolean" then target[key] = payload[key] end
    end
    if IsFiniteNumber(payload.SoundVolume) then target.SoundVolume = math.clamp(payload.SoundVolume, 0, 1) end
    for _, key in ipairs({"Favorites", "CollapsedSections"}) do
        if type(payload[key]) == "table" then
            target[key] = {}
            local count = 0
            for id, enabled in pairs(payload[key]) do
                if type(id) == "string" and #id <= 300 and enabled == true and count < 500 then
                    target[key][id] = true; count = count + 1
                end
            end
        end
    end
    if type(payload.Window) == "table" and target.RememberLayout then
        local window = payload.Window
        if IsFiniteNumber(window.Width) then target.Window.Width = math.clamp(window.Width, 280, 1200) end
        if IsFiniteNumber(window.Height) then target.Window.Height = math.clamp(window.Height, 280, 900) end
        if IsFiniteNumber(window.X) then target.Window.X = math.clamp(window.X, 0, 1) end
        if IsFiniteNumber(window.Y) then target.Window.Y = math.clamp(window.Y, 0, 1) end
    end
    if type(payload.LastPage) == "string" and #payload.LastPage <= 32 then
        ExtraFeatures.V8.PendingLastPage = payload.LastPage
        if GUIState.Pages[payload.LastPage] then target.LastPage = payload.LastPage end
    end
    if UIRefs.Experience.Ready then
        UI:ApplyFilter()
        for key, api in pairs(UIRefs.Experience.PreferenceControls or {}) do api.Set(target[key], true) end
        if UIRefs.Experience.VolumeControl then UIRefs.Experience.VolumeControl.Set(target.SoundVolume, true) end
        if target.RememberLayout and type(payload.LastPage) == "string" then PageManager:ShowPage(target.LastPage, true) end
        if ExtraFeatures.V8.ApplyLanguage then ExtraFeatures.V8.ApplyLanguage() end
        if ExtraFeatures.V8.RefreshFavorites then ExtraFeatures.V8.RefreshFavorites() end
    end
end

function ExtraFeatures.Notify(message, level)
    local state = UIRefs.Experience
    message = tostring(message or "")
    if message == "" or state.Destroyed then return end
    if state.LastMessage == message and os.clock() - (state.LastMessageTime or 0) < 0.4 then return end
    state.LastMessage, state.LastMessageTime = message, os.clock()
    table.insert(state.History, {Time = os.time(), Text = message, Level = level or "info"})
    if #state.History > 30 then table.remove(state.History, 1) end
    if state.FooterStatus then state.FooterStatus.Text = message end
    if not state.Toast or not ScreenGui.Enabled then return end
    state.ToastToken = (state.ToastToken or 0) + 1
    local token = state.ToastToken
    state.Toast.Text = message
    state.Toast.TextColor3 = level == "error" and Color3.fromRGB(255, 147, 147) or Config.TextColor
    state.Toast.Visible = true
    task.delay(3.5, function()
        if not state.Destroyed and token == state.ToastToken and state.Toast.Parent then state.Toast.Visible = false end
    end)
end

function ExtraFeatures.OnTabChanged(previousPage, pageName)
    if previousPage == pageName then return end
    local state = ExtraFeatures.UIEffects.DynamicColor
    if state.Tween then state.Tween:Cancel(); state.Tween = nil end
    MainWindow.BackgroundColor3 = Config.DarkBg
    local page = GUIState.Pages[pageName]
    local padding = page and page:FindFirstChildOfClass("UIPadding")
    if padding and not Config.Interface.ReducedMotion then
        padding.PaddingTop = UDim.new(0, 18)
        UI:Tween(padding, "PageEntry", 0.18, {PaddingTop = UDim.new(0, 10)})
    end
end

function ExtraFeatures.NewDialog(title, subtitle, height)
    DestroyMenuProfilePopup()
    for _, reset in ipairs(UIRefs.Experience.DragResetters) do pcall(reset) end
    ExtraFeatures.HoldSpamKeyHeld, ExtraFeatures.HoldSpamRightHeld = false, false
    OtherSystem.KeybindListening = false
    OtherSystem.KeybindBox, OtherSystem.KeybindCaptureMode = nil, nil
    ExtraFeatures.HoldSpamListening, ExtraFeatures.HoldSpamKeyBox = false, nil
    SyncSettingsUI()
    local state = UIRefs.Experience
    local width, viewportHeight, margin, top, bottom = ExtraFeatures.ViewBounds()
    local root = Instance.new("Frame")
    root.Name = "ProfileModal"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundTransparency = 1
    root.ZIndex = 210
    root.Parent = ScreenGui
    local backdrop = Instance.new("TextButton")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.Text = ""
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.42
    backdrop.AutoButtonColor = false
    backdrop.Modal = true
    backdrop.ZIndex = 210
    backdrop.Parent = root
    local card = Instance.new("Frame")
    card.Name = "DialogCard"
    local cw = math.min(368, width - margin * 2)
    local ch = math.min(height or 236, viewportHeight - top - bottom)
    card.Size = UDim2.fromOffset(cw, ch)
    card.Position = UDim2.fromOffset((width - cw) * 0.5, top + (viewportHeight - top - bottom - ch) * 0.5)
    card.BackgroundColor3 = Config.CardBg
    card.BorderSizePixel = 0
    card.ZIndex = 211
    card.Parent = root
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = card
    local stroke = Instance.new("UIStroke"); stroke.Color = Config.AccentColor; stroke.Transparency = 0.4; stroke.Parent = card
    local heading = Instance.new("TextLabel")
    heading.Name = "Heading"; heading.Size = UDim2.new(1, -32, 0, 26); heading.Position = UDim2.fromOffset(16, 14)
    heading.BackgroundTransparency = 1; heading.Text = title; heading.Font = Enum.Font.GothamBold
    heading.TextSize = 17; heading.TextColor3 = Config.TextColor; heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.Parent = card
    local description = Instance.new("TextLabel")
    description.Name = "Description"; description.Size = UDim2.new(1, -32, 0, 34)
    description.Position = UDim2.fromOffset(16, 44); description.BackgroundTransparency = 1
    description.Text = subtitle or ""; description.TextWrapped = true; description.TextSize = 12
    description.Font = Enum.Font.GothamMedium; description.TextColor3 = Config.SubTextColor
    description.TextXAlignment = Enum.TextXAlignment.Left; description.Parent = card
    MenuProfilePopup = root
    state.ModalRoot, state.ModalCard, state.OverlayOpen = root, card, true
    AddConnection(root.AncestryChanged:Connect(function(_, parent)
        if parent == nil and state.ModalRoot == root then
            state.ModalRoot, state.ModalCard, state.OverlayOpen = nil, nil, false
        end
    end))
    return card
end

function ExtraFeatures.OpenProfileEditor(mode, source)
    local card = ExtraFeatures.NewDialog(mode == "Rename" and "RENAME PROFILE"
        or mode == "Duplicate" and "DUPLICATE PROFILE" or "SAVE MENU PROFILE",
        "Your existing gameplay settings and key bindings are kept.", 232)
    local box = Instance.new("TextBox")
    box.Name = "ProfileName"; box.Size = UDim2.new(1, -32, 0, 36)
    box.Position = UDim2.fromOffset(16, 88); box.BackgroundColor3 = Config.DarkBg
    box.TextColor3 = Config.TextColor; box.PlaceholderColor3 = Config.SubTextColor
    box.Font = Enum.Font.GothamMedium; box.TextSize = 14; box.ClearTextOnFocus = false
    box.Text = source and tostring(source.ProfileName or source.name) .. (mode == "Duplicate" and " copy" or "") or ""
    box.PlaceholderText = "Profile name..."; box.Parent = card
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 7); corner.Parent = box
    local errorLabel = Instance.new("TextLabel")
    errorLabel.Name = "Validation"; errorLabel.Position = UDim2.fromOffset(16, 130)
    errorLabel.Size = UDim2.new(1, -32, 0, 22); errorLabel.BackgroundTransparency = 1
    errorLabel.Text = ""; errorLabel.TextSize = 11; errorLabel.TextColor3 = Color3.fromRGB(255, 147, 147)
    errorLabel.Font = Enum.Font.GothamMedium; errorLabel.TextXAlignment = Enum.TextXAlignment.Left; errorLabel.Parent = card
    local saving = false
    local function save()
        if saving or not box.Parent then return end
        local name = TrimString(box.Text)
        if name == "" then errorLabel.Text = "Enter a profile name first."; return end
        if #name > 96 then errorLabel.Text = "Use a shorter profile name."; return end
        local existing = FindMenuProfile(name)
        if existing and existing ~= source then errorLabel.Text = "That profile name already exists."; return end
        if mode == "Duplicate" and existing then errorLabel.Text = "Choose a new name for the copy."; return end
        saving = true
        if mode == "Rename" and source then
            source.ProfileName, source.name, source.UpdatedAt = name, name, os.time()
        else
            local payload = BuildConfigPayload()
            if mode == "Duplicate" and source then
                payload = SafeDecodeJSON(SafeEncodeJSON(source.ConfigData or source.config)) or payload
            end
            local id, time = GenerateMenuProfileId(), os.time()
            table.insert(MenuProfiles, {ProfileId = id, ProfileName = name, GameName = CurrentGameName,
                PlaceId = CurrentPlaceId, ConfigData = payload, Version = 1, CreatedAt = time, UpdatedAt = time,
                profileId = id, name = name, gameName = CurrentGameName, placeId = CurrentPlaceId,
                config = payload, version = 1, createdAt = time})
        end
        local persisted = SaveMenuProfiles()
        RefreshMenuProfileList()
        DestroyMenuProfilePopup()
        SetSettingsStatus(persisted and ("Profile saved: " .. name) or ("Profile kept for this session: " .. name))
    end
    local saveButton = UI:CreateButton(card, "SAVE", save)
    saveButton.Name = "SaveProfile"; saveButton.Size = UDim2.new(0.5, -22, 0, 34)
    saveButton.Position = UDim2.new(0, 16, 1, -48)
    local cancel = UI:CreateButton(card, "CANCEL", DestroyMenuProfilePopup)
    cancel.Size = UDim2.new(0.5, -22, 0, 34); cancel.Position = UDim2.new(0.5, 6, 1, -48)
    UI:ConnectOwned(box, box.FocusLost, function(enterPressed) if enterPressed then save() end end)
    box:CaptureFocus()
end

function ExtraFeatures.ProfileActions(profile)
    local card = ExtraFeatures.NewDialog("PROFILE OPTIONS", tostring(profile.ProfileName or profile.name), 310)
    local body = Instance.new("ScrollingFrame")
    body.Position = UDim2.fromOffset(16, 84); body.Size = UDim2.new(1, -32, 1, -134)
    body.BackgroundTransparency = 1; body.BorderSizePixel = 0; body.ScrollBarThickness = 2
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y; body.CanvasSize = UDim2.new(); body.Parent = card
    local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 7); list.Parent = body
    UI:CreateButton(body, "Rename", function() ExtraFeatures.OpenProfileEditor("Rename", profile) end)
    UI:CreateButton(body, "Duplicate", function() ExtraFeatures.OpenProfileEditor("Duplicate", profile) end)
    UI:CreateButton(body, "Update with current settings", function()
        local payload = BuildConfigPayload()
        profile.ConfigData, profile.config, profile.UpdatedAt = payload, payload, os.time()
        local persisted = SaveMenuProfiles(); RefreshMenuProfileList(); DestroyMenuProfilePopup()
        SetSettingsStatus(persisted and "Profile updated." or "Profile updated for this session.")
    end)
    local cancel = UI:CreateButton(card, "CLOSE", DestroyMenuProfilePopup)
    cancel.Size = UDim2.new(1, -32, 0, 34); cancel.Position = UDim2.new(0, 16, 1, -48)
end

function ExtraFeatures.ConfirmProfileDelete(profile)
    local card = ExtraFeatures.NewDialog("DELETE PROFILE?", tostring(profile.ProfileName or profile.name), 190)
    local remove = UI:CreateButton(card, "DELETE", function()
        if DeleteMenuProfile(profile.ProfileId or profile.profileId or profile.name) then
            RefreshMenuProfileList(); DestroyMenuProfilePopup(); SetSettingsStatus("Profile deleted: " .. profile.name)
        end
    end)
    remove.Size = UDim2.new(0.5, -22, 0, 34); remove.Position = UDim2.new(0, 16, 1, -48)
    local cancel = UI:CreateButton(card, "CANCEL", DestroyMenuProfilePopup)
    cancel.Size = UDim2.new(0.5, -22, 0, 34); cancel.Position = UDim2.new(0.5, 6, 1, -48)
end

function ExtraFeatures.ShowTooltip(message, anchor)
    local state = UIRefs.Experience
    if state.Destroyed or state.OverlayOpen or not MainWindow.Visible then return end
    if not state.Tooltip then
        local tip = Instance.new("TextLabel")
        tip.Name = "FeatureTooltip"; tip.Size = UDim2.fromOffset(280, 64)
        tip.BackgroundColor3 = Config.CardBg; tip.TextColor3 = Config.TextColor
        tip.Font = Enum.Font.GothamMedium; tip.TextSize = 12; tip.TextWrapped = true
        tip.TextXAlignment = Enum.TextXAlignment.Left; tip.BorderSizePixel = 0; tip.ZIndex = 180
        tip.Parent = ScreenGui
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12); pad.Parent = tip
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = tip
        state.Tooltip = tip
    end
    local scale = math.max(UIScaleObj.Scale, 0.01)
    local position = anchor and anchor.AbsolutePosition or UserInputService:GetMouseLocation()
    state.Tooltip.Text = message
    state.Tooltip.Position = UDim2.fromOffset(position.X / scale + 12, position.Y / scale + 28)
    state.Tooltip.Visible = true
    ExtraFeatures.ClampInterfaceFrame(state.Tooltip)
end

function ExtraFeatures.BindTooltip(object, message)
    AddConnection(object.MouseEnter:Connect(function() ExtraFeatures.ShowTooltip(message, object) end))
    AddConnection(object.MouseLeave:Connect(function()
        if UIRefs.Experience.Tooltip then UIRefs.Experience.Tooltip.Visible = false end
    end))
end

function ExtraFeatures.FilterPlayers()
    local state = UIRefs.Experience
    local query = state.PlayerSearch and string.lower(state.PlayerSearch.Text) or ""
    for _, button in ipairs(TeleportList:GetChildren()) do
        if button:IsA("TextButton") then
            button.Visible = query == "" or string.find(string.lower(button.Text), query, 1, true) ~= nil
        end
    end
    TeleportList.CanvasSize = UDim2.new()
end

function ExtraFeatures.StylePlayerButton(button, target)
    local state = UIRefs.Experience
    button.Size = UDim2.new(1, 0, 0, 38)
    button.TextSize = 12; button.TextXAlignment = Enum.TextXAlignment.Left
    button.TextTruncate = Enum.TextTruncate.AtEnd
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 42); pad.Parent = button
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"; avatar.BackgroundColor3 = Config.CardBg; avatar.BorderSizePixel = 0
    avatar.Size = UDim2.fromOffset(28, 28); avatar.Position = UDim2.fromOffset(-36, 5); avatar.Parent = button
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = avatar
    state.Portraits = state.Portraits or {}
    local cached = state.Portraits[target.UserId]
    if cached then avatar.Image = cached else
        task.defer(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and type(content) == "string" then
                state.Portraits[target.UserId] = content
                if avatar.Parent then avatar.Image = content end
            end
        end)
    end
end

function ExtraFeatures.UpdateInterfaceStatus(dt)
    local state = UIRefs.Experience
    if not state.Ready or state.Destroyed then return end
    state.StatusAccumulator = state.StatusAccumulator + (tonumber(dt) or 0)
    if state.StatusAccumulator < 0.35 then return end
    state.StatusAccumulator = 0
    local enabled, npcCount = 0, 0
    for _, record in ipairs(state.Controls) do
        if record.Kind == "Toggle" and record.API.Get() then enabled = enabled + 1 end
    end
    for _ in pairs(NPCSystem.ValidNPCs) do npcCount = npcCount + 1 end
    if state.FooterLeft then state.FooterLeft.Text = tostring(GUIState.ActivePage or "MENU") .. "  ·  " .. enabled .. " toggles ON" end
    if state.FooterRight then state.FooterRight.Text = "FPS " .. ExtraFeatures.UIEffects.Bubble.LastFPS .. "  |  " .. Config.ToggleKey.Name end
    if state.Summary then
        state.Summary.Text = "MENU READY  ·  " .. enabled .. " toggles ON\n"
            .. tostring(#Players:GetPlayers()) .. " players  ·  " .. npcCount .. " NPCs tracked\n"
            .. "Press " .. Config.ToggleKey.Name .. " to open the menu. F4 unloads it."
    end
    local bridge = game:GetService("ReplicatedStorage"):FindFirstChild(ExtraFeatures.DeveloperCombat.FolderName)
    local remote = bridge and bridge:FindFirstChild(ExtraFeatures.DeveloperCombat.RemoteName)
    local hasBridge = remote ~= nil and remote:IsA("RemoteEvent")
    if state.BridgeStatus then state.BridgeStatus.Text = hasBridge and "Combat bridge: READY" or "Combat bridge: NOT CONNECTED" end
    for _, record in ipairs(state.Controls) do
        if record.Hint then
            local text = record.Description or ""
            if record.Key == "TargetAssist" and Config.TargetAssistEnabled then
                text = not Config.AimEnabled and "Waiting: enable AIM." or not Config.UseFOV and "Waiting: enable FOV."
                    or "Target: " .. (ExtraFeatures.TargetAssist.CurrentTarget and ExtraFeatures.TargetAssist.CurrentTarget.Name or "None")
            elseif record.Key == "AimSilent" and Config.AimSilentEnabled then
                text = not Config.UseFOV and "Waiting: enable FOV." or not hasBridge and "Waiting: combat bridge."
                    or "Target: " .. (ExtraFeatures.AimSilent.CurrentTarget and ExtraFeatures.AimSilent.CurrentTarget.Name or "None")
            elseif record.Key == "MagicSilent" and Config.MagicSilentEnabled and not hasBridge then text = "Waiting: combat bridge."
            elseif record.Key == "HeadHitbox" and Config.HeadHitboxEnabled and Config.HeadHitboxSize <= 0 then text = "Waiting: set Head Size above 0." end
            if record.Hint.Text ~= text then record.Hint.Text = text end
        end
    end
end

function ExtraFeatures.DestroyInterface()
    local state = UIRefs.Experience
    for _, object in pairs({Tooltip = state.Tooltip, Toast = state.Toast, Shadow = state.Shadow, Modal = state.ModalRoot}) do
        if object then pcall(function() object:Destroy() end) end
    end
    for _, slots in pairs(state.TweenSlots) do for _, tween in pairs(slots) do pcall(function() tween:Cancel() end) end end
    state.OverlayOpen = false
    state.ToastToken = (state.ToastToken or 0) + 1
    table.clear(state.DragResetters)
end

function ExtraFeatures.InitializeInterface()
    local state = UIRefs.Experience
    if state.Ready then return end
    state.Ready = true
    state.BaseAnimations = {Open = ExtraFeatures.AnimateMenuOpen, Minimize = ExtraFeatures.AnimateMenuMinimize}
    ExtraFeatures.AnimateMenuOpen = function()
        if not Config.Interface.ReducedMotion then return state.BaseAnimations.Open() end
        local effects = ExtraFeatures.UIEffects
        effects.Bubble.Token = effects.Bubble.Token + 1
        effects.AnimationBusy = false
        ExtraFeatures.PrepareBubble()
        effects.Bubble.MainScale.Scale = 1
        MainWindow.BackgroundTransparency = Config.BackgroundTransparency
        MainWindow.Visible, FloatingBtn.Visible = true, false
    end
    ExtraFeatures.AnimateMenuMinimize = function()
        if not Config.Interface.ReducedMotion then return state.BaseAnimations.Minimize() end
        local effects = ExtraFeatures.UIEffects
        effects.Bubble.Token = effects.Bubble.Token + 1
        effects.AnimationBusy = false
        MainWindow.Visible, FloatingBtn.Visible = false, true
        effects.Bubble.BubbleScale.Scale = 1
        ExtraFeatures.ShowMinimizeChat()
    end
    state.Shadow = Instance.new("Frame")
    state.Shadow.Name = "WindowShadow"; state.Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    state.Shadow.BackgroundTransparency = 0.56; state.Shadow.BorderSizePixel = 0
    state.Shadow.ZIndex = 59; state.Shadow.Parent = ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = state.Shadow
    AddConnection(MainWindow:GetPropertyChangedSignal("Visible"):Connect(function() state.Shadow.Visible = MainWindow.Visible end))
    AddConnection(UIScaleObj:GetPropertyChangedSignal("Scale"):Connect(function() ExtraFeatures.ApplyInterfaceLayout(true) end))
    MainStroke.Thickness = 1.5
    UIRefs.MainRainbowGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 198, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(132, 115, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 198, 255))})
    local toolbar = Instance.new("Frame")
    toolbar.Name = "SearchToolbar"; toolbar.BackgroundTransparency = 1
    toolbar.Position = UDim2.fromOffset(16, 79); toolbar.Size = UDim2.new(1, -32, 0, 27); toolbar.Parent = Header
    local search = Instance.new("TextBox")
    search.Name = "FeatureSearch"; search.Size = UDim2.new(1, -108, 1, 0)
    search.BackgroundColor3 = Config.CardBg; search.BorderSizePixel = 0
    search.Text = ""; search.PlaceholderText = "Search features..."; search.ClearTextOnFocus = false
    search.Font = Enum.Font.GothamMedium; search.TextSize = 12; search.TextColor3 = Config.TextColor
    search.PlaceholderColor3 = Config.SubTextColor; search.Parent = toolbar
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 7); sc.Parent = search
    state.SearchBox = search
    local favorites = Instance.new("TextButton")
    favorites.Name = "FavoritesOnly"; favorites.Size = UDim2.fromOffset(98, 27); favorites.Position = UDim2.new(1, -98, 0, 0)
    favorites.Text = "☆  Favorites"; favorites.BackgroundColor3 = Config.CardBg; favorites.AutoButtonColor = false
    favorites.TextSize = 11; favorites.Font = Enum.Font.GothamMedium; favorites.TextColor3 = Config.SubTextColor
    favorites.Parent = toolbar
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 7); fc.Parent = favorites
    state.SearchCount = Instance.new("TextLabel")
    state.SearchCount.Name = "SearchResultCount"; state.SearchCount.BackgroundTransparency = 1
    state.SearchCount.Size = UDim2.fromOffset(145, 28); state.SearchCount.Position = UDim2.new(1, -150, 0, 46)
    state.SearchCount.TextColor3 = Config.SubTextColor; state.SearchCount.Font = Enum.Font.GothamMedium
    state.SearchCount.TextSize = 10; state.SearchCount.TextXAlignment = Enum.TextXAlignment.Right
    state.SearchCount.Parent = Header
    AddConnection(search:GetPropertyChangedSignal("Text"):Connect(function()
        state.Query = search.Text; UI:ApplyFilter()
        if (state.Counts[GUIState.ActivePage] or 0) == 0 and state.Query ~= "" then
            for _, name in ipairs({"AIM", "ESP", "PLAYER", "NPC", "TELEPORT", "SETTINGS", "KHÁC", "FUNCTION 1", "PROFILE", "FAVORITES", "OVERVIEW"}) do
                if (state.Counts[name] or 0) > 0 then PageManager:ShowPage(name, true); break end
            end
        end
    end))
    AddConnection(favorites.MouseButton1Click:Connect(function()
        state.FavoritesOnly = not state.FavoritesOnly
        favorites.Text = state.FavoritesOnly and "★  Favorites" or "☆  Favorites"
        favorites.TextColor3 = state.FavoritesOnly and Color3.fromRGB(255, 206, 103) or Config.SubTextColor
        UI:ApplyFilter()
    end))
    local footer = Instance.new("Frame")
    footer.Name = "StatusBar"; footer.Size = UDim2.new(1, 0, 0, 30); footer.Position = UDim2.new(0, 0, 1, -30)
    footer.BackgroundColor3 = Config.SidebarBg; footer.BorderSizePixel = 0; footer.Parent = MainWindow
    state.FooterLeft = Instance.new("TextLabel")
    state.FooterLeft.BackgroundTransparency = 1; state.FooterLeft.Size = UDim2.new(0.56, -20, 1, 0)
    state.FooterLeft.Position = UDim2.fromOffset(12, 0); state.FooterLeft.Text = "MENU READY"
    state.FooterLeft.TextColor3 = Config.SubTextColor; state.FooterLeft.Font = Enum.Font.GothamMedium
    state.FooterLeft.TextSize = 10; state.FooterLeft.TextXAlignment = Enum.TextXAlignment.Left; state.FooterLeft.Parent = footer
    state.FooterRight = state.FooterLeft:Clone(); state.FooterRight.Size = UDim2.new(0.44, -20, 1, 0)
    state.FooterRight.Position = UDim2.new(0.56, 0, 0, 0); state.FooterRight.TextXAlignment = Enum.TextXAlignment.Right
    state.FooterRight.Parent = footer
    state.Toast = Instance.new("TextLabel")
    state.Toast.Name = "StatusToast"; state.Toast.Size = UDim2.new(1, -36, 0, 52)
    state.Toast.Position = UDim2.new(0, 18, 1, -88); state.Toast.BackgroundColor3 = Config.CardBg
    state.Toast.TextColor3 = Config.TextColor; state.Toast.Font = Enum.Font.GothamMedium
    state.Toast.TextSize = 12; state.Toast.TextWrapped = true; state.Toast.Visible = false
    state.Toast.ZIndex = 150; state.Toast.Parent = MainWindow
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 9); tc.Parent = state.Toast
    local resize = Instance.new("TextButton")
    resize.Name = "ResizeHandle"; resize.Text = "◢"; resize.Size = UDim2.fromOffset(20, 20)
    resize.Position = UDim2.new(1, -21, 1, -23); resize.BackgroundTransparency = 1
    resize.TextColor3 = Config.SubTextColor; resize.TextSize = 14; resize.ZIndex = 70; resize.Parent = MainWindow
    local resizeInput, resizeStart, resizeSize
    AddConnection(resize.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        resizeInput, resizeStart, resizeSize = input, input.Position, MainWindow.Size
    end))
    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not resizeInput or state.OverlayOpen then return end
        if input ~= resizeInput and not (resizeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
        local delta = (input.Position - resizeStart) / math.max(UIScaleObj.Scale, 0.01)
        Config.Interface.Window.Width = math.clamp(resizeSize.X.Offset + delta.X, 280, 1200)
        Config.Interface.Window.Height = math.clamp(resizeSize.Y.Offset + delta.Y, 280, 900)
        ExtraFeatures.ApplyInterfaceLayout(false)
    end))
    AddConnection(UserInputService.InputEnded:Connect(function(input) if input == resizeInput then resizeInput = nil end end))
    table.insert(state.DragResetters, function() resizeInput = nil end)

    local overview = PageManager:AddPage("OVERVIEW")
    GUIState.TabButtons.OVERVIEW.LayoutOrder = -10
    local summary = UI:CreateSection(overview, "SESSION OVERVIEW")
    state.Summary = UI:CreateLabel(summary, "MENU READY")
    state.BridgeStatus = UI:CreateLabel(summary, "Combat bridge: checking...")
    local shortcuts = UI:CreateSection(overview, "QUICK NAVIGATION")
    for _, name in ipairs({"AIM", "ESP", "PLAYER", "TELEPORT", "SETTINGS"}) do
        UI:CreateButton(shortcuts, "Open " .. name, function() PageManager:ShowPage(name) end)
    end
    local preferences = UI:CreateSection(SettingsPage, "INTERFACE")
    state.PreferenceControls = {}
    for _, entry in ipairs({{"ReducedMotion", "Reduced Motion"}, {"ClickEffects", "Toggle Effects"},
        {"SoundEffects", "UI Sounds"}, {"RememberLayout", "Remember Layout"}, {"CompactSidebar", "Compact Sidebar"}}) do
        local key = entry[1]
        state.PreferenceControls[key] = UI:CreateToggle(preferences, {Text = entry[2], Default = Config.Interface[key],
            Callback = function(value) Config.Interface[key] = value; ExtraFeatures.ApplyInterfaceLayout(false) end})
    end
    state.VolumeControl = UI:CreateSlider(preferences, {Text = "UI Volume", Min = 0, Max = 1,
        Default = Config.Interface.SoundVolume, Increment = 0.01, EditableValue = true,
        Callback = function(value) Config.Interface.SoundVolume = value end})
    UI:CreateButton(preferences, "Reset window layout", function()
        Config.Interface.Window = {Width = 720, Height = 520, X = 0.5, Y = 0.5}
        ExtraFeatures.ApplyInterfaceLayout(true)
    end)
    local diagnostics = UI:CreateSection(SettingsPage, "DIAGNOSTICS")
    UI:CreateButton(diagnostics, "Show recent errors", function()
        local lines = {}
        for _, entry in ipairs(state.Errors) do table.insert(lines, entry.Text) end
        ExtraFeatures.OpenNotificationView(#lines > 0 and table.concat(lines, "\n\n") or "No errors recorded.", "DIAGNOSTICS")
    end)
    local descriptions = {
        CFrameSpeedEnabled = "Move using the existing CFrame speed controller.", CFrameSpeed = "Speed value; typed values can expand the slider range.",
        JumpPowerOverrideEnabled = "Override jump power only while enabled.", JumpPower = "Applied by Jump Override / Air Fly as before.",
        AirFlyEnabled = "Use the existing airborne jump behavior.", FlyEnabled = "Use the existing camera-directed Fly controller.",
        FlySpeed = "Flight speed in studs per second.", FullBrightEnabled = "Temporarily apply the existing lighting preset.", NoclipEnabled = "Use the existing character collision controller.",
        AimEnabled = "Master switch for the existing AIM controller.", TeamCheck = "Apply the existing teammate filter.", WallCheck = "Check the path between camera and target.",
        IgnoreVisibility = "Use the existing visibility override.", AimNPC = "Allow tracked NPCs in the existing target selection.",
        UseFOV = "Limit targets by the existing screen-space FOV.", FOV = "Radius in screen pixels, not camera angle.", Smoothness = "Higher values rotate faster, matching the original behavior.",
        TargetAssist = "Requires AIM and FOV; original target selection is retained.", AimSilent = "Requires FOV and the existing developer combat bridge.",
        HeadHitbox = "Original NPC / dummy Head Hitbox implementation.", HeadHitboxSize = "Increase above 0 to show expanded head bounds.",
        TelekillEnabled = "Original target, orbit and auto-fire behavior.", TelekillDistance = "Existing orbit distance in studs.",
        Enabled = "Master switch for the existing ESP renderer.", ShowEnemies = "Display enemy targets.", ShowTeammates = "Display teammate targets.",
        ShowName = "Display the existing player / NPC name overlay.", ShowBox = "Display the existing projected bounding box.",
        ShowTracer = "Display screen-space tracer lines.", ShowSkeleton = "Display the existing R6 / R15 skeleton lines.",
        ShowHealth = "Display current and maximum health.", ShowDistance = "Display target distance in studs.", ESPHighlightEnabled = "Display the existing classification-colored Highlight.",
        ShowNPC = "Use the shared NPC registry and ESP renderer.", ThirdPersonLock = "Use the existing third-person camera setting.",
        XRayEnabled = "Restore map transparency when disabled or closed.", XRayTransparency = "Opacity setting for the existing X-Ray feature.",
        AntiAFK = "Use the existing environment-supported Anti-AFK implementation.", HoldToSpam = "Hold the assigned key and right mouse button as before.",
        VirtualPet = "Keep the existing reactive virtual pet.", Snowfall = "Keep the existing snowfall effect.", MagicSilent = "Use the existing FUNCTION 1 combat bridge behavior."
    }
    for _, registry in ipairs({UIRefs.Toggles, UIRefs.Sliders}) do
        for key, api in pairs(registry) do
            local record = api.Frame and state.ByFrame[api.Frame]
            if record then record.Key, record.Description = key, descriptions[key] or "" end
        end
    end
    for _, record in ipairs(state.Controls) do
        if record.Hint then record.Hint.Text = record.Description or "" end
        if record.Description and record.Description ~= "" then
            ExtraFeatures.BindTooltip(record.Frame, record.Text .. "\n" .. record.Description)
            record.Search = record.Search .. " " .. string.lower(record.Description)
        end
    end
    for name, page in pairs(GUIState.Pages) do
        local record = {}
        state.Pages[name] = record
        local empty = UI:CreateLabel(page, "No matching features. Try another search or clear Favorites.")
        empty.Name = "EmptySearch"; empty.LayoutOrder = -2000; empty.Visible = false
        record.Empty = empty
        ExtraFeatures.BindTooltip(GUIState.TabButtons[name], name)
    end
    state.PlayerSearch = Instance.new("TextBox")
    state.PlayerSearch.Name = "PlayerSearch"; state.PlayerSearch.Size = UDim2.new(1, 0, 0, 32)
    state.PlayerSearch.BackgroundColor3 = Config.DarkBg; state.PlayerSearch.Text = ""
    state.PlayerSearch.PlaceholderText = "Find a player..."; state.PlayerSearch.TextColor3 = Config.TextColor
    state.PlayerSearch.PlaceholderColor3 = Config.SubTextColor; state.PlayerSearch.ClearTextOnFocus = false
    state.PlayerSearch.Font = Enum.Font.GothamMedium; state.PlayerSearch.TextSize = 12
    state.PlayerSearch.LayoutOrder = -1; state.PlayerSearch.Parent = TeleportListSec
    AddConnection(state.PlayerSearch:GetPropertyChangedSignal("Text"):Connect(ExtraFeatures.FilterPlayers))
    TeleportList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TeleportList.Size = UDim2.new(1, 0, 0, 182)
    MenuProfileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    RefreshTeleportPlayerList()
    UI:ApplyFilter()
    ExtraFeatures.ApplyInterfaceLayout(true)
    SyncSettingsUI()
    OtherSystem.SetMenuMouseState(true)
    AddConnection(UserInputService.WindowFocusReleased:Connect(function()
        ExtraFeatures.HoldSpamKeyHeld, ExtraFeatures.HoldSpamRightHeld = false, false
        ExtraFeatures.HoldSpamAccumulator = 0
        table.clear(OtherSystem.ActiveFireTouches); TouchFireActive = false
        for _, reset in ipairs(state.DragResetters) do pcall(reset) end
    end))
    AddConnection(UserInputService.InputBegan:Connect(function(input)
        if state.OverlayOpen and input.KeyCode == Enum.KeyCode.Escape then DestroyMenuProfilePopup() end
    end))
    local cameraConnection
    local function bindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        local camera = Workspace.CurrentCamera
        if camera then cameraConnection = AddConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            ExtraFeatures.ApplyInterfaceLayout(true)
        end)) end
        ExtraFeatures.ApplyInterfaceLayout(true)
    end
    AddConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
    bindCamera()
    ExtraFeatures.UpdateInterfaceStatus(1)
end

_G.MyGUIFramework.Interface = {
    Notify = ExtraFeatures.Notify,
    ApplyLayout = ExtraFeatures.ApplyInterfaceLayout,
    Search = function(query) UIRefs.Experience.SearchBox.Text = tostring(query or "") end,
    GetDiagnostics = function() return UIRefs.Experience.Errors end
}

do
    local ok, reason = pcall(ExtraFeatures.InitializeInterface)
    if not ok then warn("[Hood Rivals] Interface upgrade: " .. tostring(reason)) end
end



ExtraFeatures.V8.Vietnamese = {
    ["OVERVIEW"] = "TỔNG QUAN", ["HOME"] = "TỔNG QUAN", ["PLAYER"] = "NHÂN VẬT", ["AIM"] = "NGẮM",
    ["FAVORITES"] = "YÊU THÍCH", ["YOUR FAVORITES"] = "MỤC YÊU THÍCH CỦA BẠN",
    ["AIM Main"] = "NGẮM CHÍNH", ["AIM Mode"] = "CHẾ ĐỘ NGẮM", ["AIM Target"] = "MỤC TIÊU NGẮM",
    ["AIM FOV"] = "VÙNG NGẮM", ["AIM Settings"] = "CÀI ĐẶT NGẮM", ["AIM SILENT"] = "NGẮM SILENT",
    ["ESP Main"] = "ESP CHÍNH", ["ESP Settings"] = "CÀI ĐẶT ESP", ["ESP Visuals"] = "HIỂN THỊ ESP",
    ["CHARACTER"] = "NHÂN VẬT", ["JUMP"] = "NHẢY", ["FEATURE SETTINGS"] = "CÀI ĐẶT CHỨC NĂNG",
    ["HEAD HITBOX"] = "VÙNG TRÚNG ĐẦU", ["SELECTED PLAYER"] = "NGƯỜI CHƠI ĐÃ CHỌN",
    ["TARGET ASSIST"] = "HỖ TRỢ MỤC TIÊU", ["TARGET FILTERS"] = "BỘ LỌC MỤC TIÊU", ["TELEKILL"] = "TELEKILL",
    ["UI EFFECTS"] = "HIỆU ỨNG GIAO DIỆN", ["Game Pass Spoofer"] = "Mô phỏng Game Pass",
    ["Quick Targets: [1] Enemy   [2] Aim Team   [3] Aim NPC"] = "Đổi nhanh: [1] Địch   [2] Đồng đội   [3] NPC",
    ["Tracks the closest valid target and shows local shot feedback without changing the camera."] = "Theo dõi mục tiêu hợp lệ và hiển thị phản hồi phát bắn.",
    ["W/A/S/D/Q/E move the safe freecam. Target tracking is visual only."] = "W/A/S/D/Q/E di chuyển camera tự do. Theo dõi mục tiêu bằng hiển thị.",
    ["Game Pass Spoofer is client-side only; server ownership is unchanged."] = "Mô phỏng Game Pass chỉ thay đổi hiển thị trên máy của bạn.",
    ["Master switch for the existing AIM controller."] = "Công tắc chính của chức năng ngắm.",
    ["Apply the existing teammate filter."] = "Dùng bộ lọc đồng đội đã chọn.",
    ["Check the path between camera and target."] = "Kiểm tra vật cản từ camera đến mục tiêu.",
    ["Use the existing visibility override."] = "Bỏ qua kiểm tra mục tiêu đang hiển thị.",
    ["Limit targets by the existing screen-space FOV."] = "Chỉ chọn mục tiêu trong vùng ngắm trên màn hình.",
    ["Allow tracked NPCs in the existing target selection."] = "Cho phép chọn NPC được theo dõi làm mục tiêu.",
    ["Higher values rotate faster, matching the original behavior."] = "Giá trị lớn hơn làm tốc độ xoay ngắm nhanh hơn.",
    ["Radius in screen pixels, not camera angle."] = "Bán kính vùng ngắm tính bằng pixel trên màn hình.",
    ["Requires AIM and FOV; original target selection is retained."] = "Cần bật ngắm và vùng ngắm; dùng bộ lọc mục tiêu hiện tại.",
    ["Requires FOV and the existing developer combat bridge."] = "Cần vùng ngắm và kết nối combat của game.",
    ["Increase above 0 to show expanded head bounds."] = "Đặt lớn hơn 0 để hiển thị vùng đầu mở rộng.",
    ["Original NPC / dummy Head Hitbox implementation."] = "Vùng trúng đầu dành cho NPC hoặc hình nộm.",
    ["Move using the existing CFrame speed controller."] = "Di chuyển bằng chức năng tốc độ CFrame.",
    ["Speed value; typed values can expand the slider range."] = "Tốc độ di chuyển; nhập số để mở rộng phạm vi thanh trượt.",
    ["Use the existing airborne jump behavior."] = "Dùng chức năng nhảy khi đang trên không.",
    ["Override jump power only while enabled."] = "Chỉ thay đổi lực nhảy khi bật tùy chọn này.",
    ["Applied by Jump Override / Air Fly as before."] = "Lực nhảy áp dụng cho tùy chỉnh nhảy hoặc bay trên không.",
    ["Use the existing camera-directed Fly controller."] = "Bay theo hướng camera.",
    ["Flight speed in studs per second."] = "Tốc độ bay tính bằng stud mỗi giây.",
    ["Use the existing character collision controller."] = "Điều chỉnh va chạm của nhân vật.",
    ["Temporarily apply the existing lighting preset."] = "Tạm thời áp dụng thiết lập ánh sáng đã chọn.",
    ["Original target, orbit and auto-fire behavior."] = "Dùng lựa chọn mục tiêu, quỹ đạo và tự bắn hiện tại.",
    ["Existing orbit distance in studs."] = "Khoảng cách quỹ đạo tính bằng stud.",
    ["Use the existing FUNCTION 1 combat bridge behavior."] = "Dùng kết nối combat của Chức năng 1.",
    ["Distance: Nearest"] = "Khoảng cách: Gần nhất", ["Distance: Farthest"] = "Khoảng cách: Xa nhất",
    ["Profiles saved"] = "Đã lưu các cấu hình",
    ["ESP"] = "ESP", ["NPC"] = "NPC", ["TELEPORT"] = "DỊCH CHUYỂN", ["TP"] = "DỊCH CHUYỂN",
    ["SETTINGS"] = "CÀI ĐẶT", ["SET"] = "CÀI ĐẶT", ["PROFILE"] = "HỒ SƠ", ["FUNCTION 1"] = "CHỨC NĂNG 1",
    ["Aim Enable"] = "Bật ngắm", ["Team Check"] = "Kiểm tra đội", ["Wall Check"] = "Kiểm tra vật cản",
    ["Ignore Visibility"] = "Bỏ qua kiểm tra hiển thị", ["Use FOV"] = "Dùng vùng ngắm", ["Always Aim"] = "Luôn ngắm",
    ["Aim On Fire"] = "Ngắm khi bắn", ["Smoothness"] = "Độ mượt", ["Max Distance"] = "Khoảng cách tối đa",
    ["Aim NPC"] = "Ngắm NPC", ["AIM NPC"] = "NGẮM NPC", ["Aim Team"] = "Ngắm đồng đội",
    ["Target Assist"] = "Hỗ trợ mục tiêu", ["AimSilent"] = "AimSilent", ["Head Hitbox"] = "Vùng trúng đầu",
    ["Head Size"] = "Kích thước đầu", ["CFrame Speed"] = "Tốc độ di chuyển", ["Air Fly"] = "Bay trên không",
    ["Jump Power"] = "Lực nhảy", ["Jump Power Override"] = "Tùy chỉnh lực nhảy", ["Fly"] = "Bay",
    ["Fly Speed"] = "Tốc độ bay", ["Full Bright"] = "Làm sáng bản đồ", ["Noclip"] = "Đi xuyên vật cản",
    ["ESP Enable"] = "Bật ESP", ["ESP Enemy"] = "ESP địch", ["ESP Team"] = "ESP đồng đội", ["ESP NPC"] = "ESP NPC",
    ["ESP Name"] = "Tên mục tiêu", ["ESP Box"] = "Khung mục tiêu", ["ESP Tracer"] = "Đường chỉ mục tiêu",
    ["ESP Skeleton"] = "Khung xương", ["ESP Health"] = "Thanh máu", ["ESP Distance"] = "Khoảng cách mục tiêu",
    ["ESP Highlight"] = "Viền mục tiêu", ["Enemy"] = "Địch", ["Team"] = "Đồng đội", ["Nearest"] = "Gần nhất",
    ["Farthest"] = "Xa nhất", ["Tele Distance"] = "Khoảng cách dịch chuyển", ["Telekill"] = "Telekill",
    ["Third Person Lock"] = "Khóa góc nhìn thứ ba", ["X-Ray"] = "X-Ray", ["X-Ray Transparency"] = "Độ trong suốt X-Ray",
    ["Hold to Spam"] = "Giữ phím để bấm liên tục", ["Virtual Pet"] = "Thú cưng ảo", ["Snowfall"] = "Hiệu ứng tuyết",
    ["Anti-AFK"] = "Chống AFK", ["Magic Silent"] = "Magic Silent", ["Drone Strike: ACTIVE"] = "Drone Strike: ĐANG BẬT",
    ["Drone Strike: OFF"] = "Drone Strike: ĐÃ TẮT", ["TP ON"] = "TP BẬT", ["TP OFF"] = "TP TẮT",
    ["Aim Part: Head"] = "Vị trí ngắm: Đầu", ["Aim Part: Body"] = "Vị trí ngắm: Thân",
    ["No player selected"] = "Chưa chọn người chơi", ["Target: None"] = "Mục tiêu: Chưa có",
    ["Search features..."] = "Tìm tính năng...", ["Search..."] = "Tìm kiếm...", ["Find a player..."] = "Tìm người chơi...",
    ["Profile name..."] = "Tên cấu hình...", ["Press Key..."] = "Nhấn phím...", ["ALL FEATURES"] = "TẤT CẢ TÍNH NĂNG",
    ["☆  Favorites"] = "☆  Yêu thích", ["★  Favorites"] = "★  Yêu thích",
    ["No matching features. Try another search or clear Favorites."] = "Không có tính năng phù hợp. Đổi từ khóa hoặc tắt lọc yêu thích.",
    ["No favorites yet. Click a star next to a feature."] = "Chưa có mục yêu thích. Nhấn ngôi sao cạnh tính năng để lưu.",
    ["SESSION OVERVIEW"] = "TỔNG QUAN PHIÊN", ["QUICK NAVIGATION"] = "ĐIỀU HƯỚNG NHANH", ["INTERFACE"] = "GIAO DIỆN",
    ["DIAGNOSTICS"] = "CHẨN ĐOÁN", ["NOTIFICATIONS"] = "THÔNG BÁO", ["RECENT ACTIVITY"] = "HOẠT ĐỘNG GẦN ĐÂY",
    ["Reduced Motion"] = "Giảm chuyển động", ["Toggle Effects"] = "Hiệu ứng bật/tắt", ["UI Sounds"] = "Âm thanh giao diện",
    ["Remember Layout"] = "Ghi nhớ bố cục", ["Compact Sidebar"] = "Thanh bên gọn", ["UI Volume"] = "Âm lượng giao diện",
    ["Reset window layout"] = "Đặt lại bố cục cửa sổ", ["Show recent errors"] = "Xem lỗi gần đây", ["No errors recorded."] = "Chưa ghi nhận lỗi.",
    ["CONFIG SAVE / LOAD"] = "LƯU / TẢI CÀI ĐẶT", ["SAVE SETTINGS"] = "LƯU CÀI ĐẶT", ["LOAD SETTINGS"] = "TẢI CÀI ĐẶT",
    ["SAVE / LOAD MENU"] = "LƯU / TẢI CẤU HÌNH", ["SAVE MENU"] = "LƯU CẤU HÌNH", ["Ready"] = "Sẵn sàng",
    ["Shortcut: hold CTRL + C + V to load settings"] = "Giữ CTRL + C + V để tải cài đặt",
    ["Shortcut: hold CTRL + S + V to open Favorites"] = "Giữ CTRL + S + V để mở mục yêu thích",
    ["SAVE MENU PROFILE"] = "LƯU CẤU HÌNH MENU", ["RENAME PROFILE"] = "ĐỔI TÊN CẤU HÌNH", ["DUPLICATE PROFILE"] = "NHÂN BẢN CẤU HÌNH",
    ["PROFILE OPTIONS"] = "TÙY CHỌN CẤU HÌNH", ["DELETE PROFILE?"] = "XÓA CẤU HÌNH?", ["Rename"] = "Đổi tên",
    ["Duplicate"] = "Nhân bản", ["Update with current settings"] = "Cập nhật bằng cài đặt hiện tại",
    ["RUN"] = "TẢI", ["SAVE"] = "LƯU", ["CANCEL"] = "HỦY", ["DELETE"] = "XÓA", ["CLOSE"] = "ĐÓNG",
    ["Your existing gameplay settings and key bindings are kept."] = "Lưu các thiết lập tính năng và phím tắt của bạn.",
    ["Enter a profile name first."] = "Nhập tên cấu hình trước.", ["Use a shorter profile name."] = "Tên cấu hình quá dài.",
    ["That profile name already exists."] = "Tên cấu hình đã tồn tại.", ["Choose a new name for the copy."] = "Chọn tên khác cho bản sao.",
    ["Settings saved"] = "Đã lưu cài đặt", ["Settings loaded"] = "Đã tải cài đặt", ["No saved settings found"] = "Chưa có cài đặt đã lưu",
    ["Settings saved for this session"] = "Đã lưu cài đặt trong phiên này", ["Saving settings on server..."] = "Đang lưu cài đặt...",
    ["Saved data belongs to another player"] = "Dữ liệu đã lưu thuộc tài khoản khác", ["Profile updated."] = "Đã cập nhật cấu hình.",
    ["Profile updated for this session."] = "Đã cập nhật cấu hình trong phiên này.", ["Connecting player storage..."] = "Đang kết nối dữ liệu người chơi...",
    ["Profiles kept for this session; JSON unavailable"] = "Cấu hình được giữ trong phiên này; chưa thể mã hóa dữ liệu",
    ["Profiles kept for this session; filesystem unavailable"] = "Cấu hình được giữ trong phiên này",
    ["Profiles kept for this session; write failed"] = "Chưa ghi được cấu hình; đã giữ bản trong phiên này",
    ["Combat bridge: checking..."] = "Kết nối combat: đang kiểm tra...", ["Combat bridge: READY"] = "Kết nối combat: SẴN SÀNG",
    ["Combat bridge: NOT CONNECTED"] = "Kết nối combat: CHƯA KẾT NỐI", ["Waiting: enable AIM."] = "Cần bật ngắm.",
    ["Waiting: enable FOV."] = "Cần bật vùng ngắm.", ["Waiting: combat bridge."] = "Đang chờ kết nối combat.",
    ["Waiting: set Head Size above 0."] = "Đặt kích thước đầu lớn hơn 0.",
    ["PLAYER IDENTITY"] = "THÔNG TIN NGƯỜI CHƠI", ["GAME / SERVER"] = "GAME / MÁY CHỦ", ["SESSION / STORAGE"] = "PHIÊN / DỮ LIỆU",
    ["Display Name"] = "Tên hiển thị", ["Username"] = "Tên tài khoản", ["User ID"] = "ID người chơi", ["Account Age"] = "Tuổi tài khoản",
    ["Current Team"] = "Đội hiện tại", ["Game"] = "Game", ["Place ID"] = "ID Place", ["Universe ID"] = "ID game",
    ["Server ID"] = "ID máy chủ", ["Server Type"] = "Loại máy chủ", ["Players"] = "Người chơi", ["Network Ping"] = "Ping mạng",
    ["Time in Session"] = "Thời gian trong phiên", ["Storage"] = "Nơi lưu", ["Public"] = "Công khai", ["Private / reserved"] = "Riêng / dành riêng",
    ["Saved on device"] = "Đã lưu trên thiết bị", ["Saved on server"] = "Đã lưu trên máy chủ", ["Session only"] = "Chỉ trong phiên này",
    ["Saving..."] = "Đang lưu...",
    ["Unknown / FFA"] = "Chưa xác định / FFA", ["Read-only player and server information."] = "Thông tin người chơi và máy chủ; chỉ xem.",
    ["LANGUAGE"] = "NGÔN NGỮ", ["Language"] = "Ngôn ngữ", ["English"] = "Tiếng Anh", ["Vietnamese"] = "Tiếng Việt",
    ["AIM PRIORITY"] = "ƯU TIÊN MỤC TIÊU", ["Aim Priority"] = "Ưu tiên ngắm", ["Crosshair (default)"] = "Gần tâm ngắm (mặc định)",
    ["Nearest to player"] = "Gần nhân vật nhất", ["Lowest health"] = "Ít máu nhất", ["Players first"] = "Ưu tiên người chơi", ["NPCs first"] = "Ưu tiên NPC",
    ["Priority still follows your team, wall, distance and NPC filters."] = "Ưu tiên vẫn tuân theo bộ lọc đội, vật cản, khoảng cách và NPC.",
    ["WEAPON TUNING"] = "TÙY CHỈNH SÚNG", ["Infinite Ammo"] = "Đạn vô hạn", ["Skip Reload"] = "Bỏ thời gian reload",
    ["Recoil Control"] = "Kiểm soát độ giật", ["Recoil Amount (%)"] = "Mức giật còn lại (%)", ["Spread Control"] = "Kiểm soát độ tản đạn",
    ["Spread Amount (%)"] = "Mức tản còn lại (%)", ["0% removes the effect; 100% keeps the weapon's default."] = "0% loại bỏ hiệu ứng; 100% giữ mức mặc định của súng.",
    ["Weapon: game adapter connected"] = "Súng: đã kết nối bộ điều khiển game", ["Weapon: controller connected"] = "Súng: đã kết nối bộ điều khiển",
    ["Weapon: admin permission required"] = "Súng: cần quyền admin", ["Weapon: waiting for a compatible equipped weapon"] = "Súng: đang chờ trang bị súng tương thích",
    ["Weapon: controller not connected"] = "Súng: chưa kết nối bộ điều khiển", ["Recoil and spread apply to shot direction, not just camera visuals."] = "Độ giật và tản được áp dụng vào hướng đạn thực tế.",
    ["NEARBY ENEMY ALERT"] = "CẢNH BÁO ĐỊCH Ở GẦN", ["Nearby Enemy Alert"] = "Cảnh báo địch ở gần", ["Scan Radius"] = "Bán kính quét",
    ["Include Hostile NPCs"] = "Quét cả NPC thù địch", ["Arrows show nearby living enemies. Alerts clear when the area is safe."] = "Mũi tên chỉ địch còn sống trong phạm vi. Cảnh báo tự ẩn khi không còn địch.",
    ["TEAM DETECTION"] = "NHẬN DIỆN ĐỘI", ["Team Detection"] = "Cách nhận diện đội", ["Auto"] = "Tự động", ["Free for all (FFA)"] = "Mọi người là đối thủ (FFA)",
    ["Roblox teams"] = "Đội Roblox", ["Custom team attribute"] = "Thuộc tính đội tùy chỉnh", ["Team Attribute"] = "Tên thuộc tính đội",
    ["Auto checks custom combat teams before Roblox teams. Use FFA for games without teams."] = "Tự động ưu tiên đội tùy chỉnh rồi đến đội Roblox. Chọn FFA cho game không chia đội.",
    ["Custom player rigs can expose PlayerUserId; NPCs remain a separate category."] = "Nhân vật tùy chỉnh có thể dùng PlayerUserId; NPC vẫn được phân loại riêng.",
    ["CAMERA / VISUAL"] = "CAMERA / HIỂN THỊ", ["SERVER"] = "MÁY CHỦ", ["REJOIN / MENU"] = "VÀO LẠI / MENU",
    ["PLAYER LIST"] = "DANH SÁCH NGƯỜI CHƠI", ["MOVEMENT"] = "DI CHUYỂN", ["FLY"] = "BAY", ["VISUAL"] = "HIỂN THỊ",
    ["ESP FILTERS"] = "BỘ LỌC ESP", ["ESP VISUALS"] = "HIỂN THỊ ESP", ["AIM SETTINGS"] = "CÀI ĐẶT NGẮM",
    ["DRONE STRIKE"] = "DRONE STRIKE", ["MAGIC SILENT"] = "MAGIC SILENT", ["Hide GUI"] = "Ẩn menu",
    ["Master switch for the existing ESP renderer."] = "Công tắc chính của ESP.", ["Display enemy targets."] = "Hiển thị mục tiêu địch.",
    ["Display teammate targets."] = "Hiển thị mục tiêu đồng đội.", ["Display current and maximum health."] = "Hiển thị máu hiện tại và tối đa, cảnh báo khi máu thấp.",
    ["Display target distance in studs."] = "Hiển thị khoảng cách tới mục tiêu.", ["Display screen-space tracer lines."] = "Hiển thị đường chỉ tới mục tiêu.",
    ["Display the existing player / NPC name overlay."] = "Hiển thị tên người chơi / NPC.", ["Display the existing projected bounding box."] = "Hiển thị khung quanh mục tiêu.",
    ["Display the existing R6 / R15 skeleton lines."] = "Hiển thị khung xương R6 / R15.", ["Display the existing classification-colored Highlight."] = "Hiển thị viền theo màu phân loại.",
    ["Use the shared NPC registry and ESP renderer."] = "Hiển thị NPC bằng hệ thống ESP chung.", ["Use the existing third-person camera setting."] = "Dùng góc nhìn camera thứ ba.",
    ["Restore map transparency when disabled or closed."] = "Khôi phục độ trong suốt bản đồ khi tắt hoặc đóng.",
    ["Opacity setting for the existing X-Ray feature."] = "Chỉnh độ trong suốt của X-Ray.", ["Use the existing environment-supported Anti-AFK implementation."] = "Chống AFK khi môi trường hỗ trợ.",
    ["Hold the assigned key and right mouse button as before."] = "Giữ phím đã chọn và nút chuột phải để thao tác.",
    ["Keep the existing reactive virtual pet."] = "Thú cưng ảo phản ứng theo thao tác.", ["Keep the existing snowfall effect."] = "Hiển thị hiệu ứng tuyết.",
    ["MENU READY"] = "MENU SẴN SÀNG", ["Action failed. See diagnostics."] = "Thao tác thất bại. Xem mục chẩn đoán.",
    ["F4 is reserved for unloading the framework."] = "F4 dành riêng để gỡ menu.", ["That key is reserved for Drone Strike freecam movement"] = "Phím này dùng để di chuyển camera Drone Strike.",
    ["NHẬP THÔNG BÁO Ở ĐÂY"] = "Chưa có thông báo mới.",
}

function ExtraFeatures.V8.Translate(text)
    text = tostring(text or "")
    if Config.Interface.Language ~= "VI" then
        if text == "NHẬP THÔNG BÁO Ở ĐÂY" then return "No new notifications." end
        local aliases = {["KHÁC"] = "OTHER", ["↓  Ít Người"] = "↓  Fewer Players", ["↩  Rejoin"] = "↩  Rejoin",
            ["↻  Đổi Server"] = "↻  Change Server", ["⌁  Ping Thấp"] = "⌁  Low Ping"}
        if aliases[text] then return aliases[text] end
        return text
    end
    local dictionary = ExtraFeatures.V8.Vietnamese
    if dictionary[text] then return dictionary[text] end
    local choice = text:match("^(.-)  ▾$")
    if choice then return ExtraFeatures.V8.Translate(choice) .. "  ▾" end
    local selected = text:match("^✓  (.*)$")
    if selected then return "✓  " .. ExtraFeatures.V8.Translate(selected) end
    local prefix, body = text:match("^(−%s+)(.*)$")
    if not prefix then prefix, body = text:match("^([+]%s+)(.*)$") end
    if prefix then return prefix .. (dictionary[body] or body) end
    if text:sub(1, #"YOUR MENU PROFILES") == "YOUR MENU PROFILES" then
        return text:gsub("YOUR MENU PROFILES", "CẤU HÌNH CỦA BẠN"):gsub("Current Game:", "Game hiện tại:")
            :gsub("Current PlaceId:", "ID Place hiện tại:"):gsub("Profiles belong to your User ID%.", "Cấu hình được lưu theo ID tài khoản của bạn.")
    end
    for _, rule in ipairs({{"Profile saved: ", "Đã lưu cấu hình: "}, {"Profile loaded: ", "Đã tải cấu hình: "},
        {"Profile deleted: ", "Đã xóa cấu hình: "}, {"Profile kept for this session: ", "Đã giữ cấu hình trong phiên: "},
        {"Settings load failed: ", "Tải cài đặt thất bại: "}, {"Selected: ", "Đã chọn: "}, {"Target: ", "Mục tiêu: "},
        {"Drone Strike Key: ", "Phím Drone Strike: "}, {"Switch Target Key: ", "Phím đổi mục tiêu: "},
        {"Hold to Spam Key: ", "Phím giữ để bấm: "}, {"Open ", "Mở "}, {"Key already assigned to ", "Phím đã được dùng cho "}}) do
        if text:sub(1, #rule[1]) == rule[1] then return rule[2] .. text:sub(#rule[1] + 1) end
    end
    local results = text:match("^(%d+) results$")
    if results then return results .. " kết quả" end
    if text:find("toggles ON", 1, true) or text:find("NPCs tracked", 1, true) then
        text = text:gsub("MENU READY", "MENU SẴN SÀNG"):gsub("toggles ON", "mục đang bật")
            :gsub("players", "người chơi"):gsub("NPCs tracked", "NPC đang theo dõi")
        text = text:gsub("Right Control / your assigned key opens the menu%. F4 unloads it%.", "Phím đã chọn mở menu. F4 gỡ menu.")
        text = text:gsub("Press (.-) to open the menu%. F4 unloads it%.", "Nhấn %1 để mở menu. F4 gỡ menu.")
    end
    return text
end

function ExtraFeatures.V8.ShouldTranslate(object)
    if not object or object:GetAttribute("MenuNoTranslate") == true then return false end
    if object.Name == "ProfileTitle" or object.Name == "ProfileMetadata" or object.Name == "ProfileValue" then return false end
    if object:IsDescendantOf(TeleportList) then return false end
    return object:IsDescendantOf(MainWindow) or (MenuProfilePopup and object:IsDescendantOf(MenuProfilePopup))
        or object.Name == "FeatureTooltip"
end

function ExtraFeatures.V8.TrackText(object)
    local state = ExtraFeatures.V8
    if state.Registry[object] or not state.ShouldTranslate(object) then return end
    local properties = object:IsA("TextBox") and {"PlaceholderText"}
        or (object:IsA("TextLabel") or object:IsA("TextButton")) and {"Text"} or nil
    if not properties then return end
    local record = {Sources = {}, Connections = {}, Busy = false}
    state.Registry[object] = record
    for _, property in ipairs(properties) do
        record.Sources[property] = object[property]
        local function render()
            if record.Busy or state.Destroyed then return end
            record.Busy = true
            object[property] = state.Translate(record.Sources[property])
            record.Busy = false
        end
        table.insert(record.Connections, object:GetPropertyChangedSignal(property):Connect(function()
            if record.Busy then return end
            record.Sources[property] = object[property]; render()
        end))
        render()
    end
    object.Destroying:Connect(function()
        for _, connection in ipairs(record.Connections) do connection:Disconnect() end
        state.Registry[object] = nil
    end)
end

function ExtraFeatures.V8.TrackTree(root)
    if not root then return end
    ExtraFeatures.V8.TrackText(root)
    for _, child in ipairs(root:GetDescendants()) do ExtraFeatures.V8.TrackText(child) end
end

function ExtraFeatures.V8.ApplyLanguage()
    local state = ExtraFeatures.V8
    for object, record in pairs(state.Registry) do
        if object.Parent then
            record.Busy = true
            for property, source in pairs(record.Sources) do object[property] = state.Translate(source) end
            record.Busy = false
        end
    end
    for _, record in ipairs(UIRefs.Experience.Controls) do
        record.SearchNormalized = state.Normalize(record.Search .. " " .. state.Translate(record.Text)
            .. " " .. state.Translate(record.Description or "") .. " " .. state.Translate(record.Section.Title))
    end
    UI:ApplyFilter()
    if state.SyncControls then state.SyncControls() end
    if state.UpdateProfile then state.UpdateProfile() end
end


function ExtraFeatures.V8.StyleHealth(data, humanoid, _classificationColor)
    local info = data.info
    local label = info and info:FindFirstChild("Health")
    if not label then return end
    local maximum = math.max(tonumber(humanoid.MaxHealth) or 100, 1)
    local health = math.max(tonumber(humanoid.Health) or 0, 0)
    local ratio = math.clamp(health / maximum, 0, 1)
    local critical = ratio <= 0.25
    local color = critical and Color3.fromRGB(255, 99, 113)
        or ratio <= 0.6 and Color3.fromRGB(255, 203, 87) or Color3.fromRGB(97, 239, 160)
    local suffix = critical and (Config.Interface.Language == "VI" and "  ! THẤP" or "  ! LOW") or ""
    label.Text = string.format("HP: %d / %d%s", math.floor(health), math.floor(maximum), suffix)
    label.TextColor3 = color
    label.TextStrokeColor3 = critical and Color3.fromRGB(255, 240, 240) or Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = critical and 0.6 or 0
    label.TextTransparency = critical and not Config.Interface.ReducedMotion and (0.06 + 0.12 * (1 + math.sin(os.clock() * 5)) / 2) or 0
    local track = info:FindFirstChild("HealthTrack")
    if not track then
        track = Instance.new("Frame"); track.Name = "HealthTrack"
        track.Size = UDim2.fromOffset(100, 4); track.Position = UDim2.new(0.5, -50, 0, 40)
        track.BackgroundColor3 = Color3.fromRGB(30, 37, 48); track.BackgroundTransparency = 0.15
        track.BorderSizePixel = 0; track.ZIndex = label.ZIndex; track.Parent = info
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = track
        local fill = Instance.new("Frame"); fill.Name = "Fill"; fill.BorderSizePixel = 0; fill.ZIndex = track.ZIndex + 1
        fill.Parent = track
        local fillCorner = corner:Clone(); fillCorner.Parent = fill
        local distance = info:FindFirstChild("Distance")
        if distance then distance.Position = UDim2.fromOffset(0, 48) end
    end
    track.Visible = Config.ShowHealth
    track.Fill.Size = UDim2.new(ratio, 0, 1, 0)
    track.Fill.BackgroundColor3 = color
end

function ExtraFeatures.V8.HideProximity()
    local state = ExtraFeatures.V8
    state.Nearby = {}
    if state.ProximitySummary then state.ProximitySummary.Visible = false end
    for _, arrow in ipairs(state.Arrows or {}) do arrow.Frame.Visible = false end
end

function ExtraFeatures.V8.CreateOverlays()
    local state = ExtraFeatures.V8
    state.Arrows = {}
    for index = 1, 4 do
        local frame = Instance.new("Frame"); frame.Name = "NearbyEnemy_" .. index
        frame.Size = UDim2.fromOffset(82, 48); frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundTransparency = 1; frame.Visible = false; frame.ZIndex = 42; frame.Parent = ScreenGui
        local pointer = Instance.new("TextLabel"); pointer.Name = "Direction"
        pointer.Size = UDim2.fromOffset(28, 28); pointer.Position = UDim2.fromOffset(27, 0)
        pointer.BackgroundTransparency = 1; pointer.Text = "▲"; pointer.Font = Enum.Font.GothamBold
        pointer.TextSize = 25; pointer.TextColor3 = Color3.fromRGB(255, 111, 114)
        pointer.TextStrokeTransparency = 0.3; pointer.ZIndex = 43; pointer.Parent = frame
        local caption = Instance.new("TextLabel"); caption.Name = "Distance"
        caption.Size = UDim2.new(1, 0, 0, 16); caption.Position = UDim2.fromOffset(0, 30)
        caption.BackgroundTransparency = 1; caption.Font = Enum.Font.GothamBold; caption.TextSize = 11
        caption.TextColor3 = Config.TextColor; caption.TextStrokeTransparency = 0.2; caption.ZIndex = 43; caption.Parent = frame
        state.Arrows[index] = {Frame = frame, Pointer = pointer, Caption = caption}
    end
    local summary = Instance.new("TextLabel"); summary.Name = "NearbyEnemySummary"
    summary.AnchorPoint = Vector2.new(0.5, 0); summary.Size = UDim2.fromOffset(242, 28)
    summary.BackgroundColor3 = Color3.fromRGB(49, 23, 34); summary.BackgroundTransparency = 0.12
    summary.TextColor3 = Color3.fromRGB(255, 176, 176); summary.Font = Enum.Font.GothamBold; summary.TextSize = 12
    summary.BorderSizePixel = 0; summary.ZIndex = 44; summary.Visible = false; summary.Parent = ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = summary
    state.ProximitySummary = summary
    local health = summary:Clone(); health.Name = "LocalLowHealth"
    health.AnchorPoint = Vector2.new(0.5, 1); health.Parent = ScreenGui; state.LocalHealth = health
end

function ExtraFeatures.V8.ScanNearby()
    local state = ExtraFeatures.V8
    local character = NPCSystem.GetCharacter(LocalPlayer)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not Config.Proximity.Enabled or not root or not humanoid or humanoid.Health <= 0
        or GUIState.CurrentState == "Closed" then state.HideProximity(); return end
    local nearby = {}
    local function consider(target, character)
        local part = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not part or not humanoid or humanoid.Health <= 0 then return end
        local distance = (part.Position - root.Position).Magnitude
        if distance <= Config.Proximity.Radius and distance > 0.01 then
            table.insert(nearby, {Target = target, Root = part, Distance = distance})
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and NPCSystem.ClassifyPlayer(player) == "Enemy" then
            consider(player, NPCSystem.GetCharacter(player))
        end
    end
    if Config.Proximity.IncludeNPC then
        for model in pairs(NPCSystem.ValidNPCs) do
            if NPCSystem.IsValidNPC(model) and (model:GetAttribute("Hostile") == true
                or string.lower(tostring(model:GetAttribute("Disposition") or "")) == "hostile") then consider(model, model) end
        end
    end
    table.sort(nearby, function(a, b) return a.Distance < b.Distance end)
    state.Nearby = nearby
end

function ExtraFeatures.V8.UpdateProximity(camera)
    local state = ExtraFeatures.V8
    if not Config.Proximity.Enabled or not camera or GUIState.CurrentState == "Closed" then state.HideProximity(); return end
    local viewport = camera.ViewportSize
    local scale = math.max(UIScaleObj.Scale, 0.01)
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local radius = math.min(110, math.max(58, math.min(viewport.X, viewport.Y) * 0.15))
    local count = 0
    for index, arrow in ipairs(state.Arrows or {}) do
        local entry = (state.Nearby or {})[index]
        if entry and entry.Root.Parent then
            local humanoid = entry.Root.Parent:FindFirstChildOfClass("Humanoid")
            local character = NPCSystem.GetCharacter(LocalPlayer)
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local validEnemy = NPCSystem.IsPlayer(entry.Target) and NPCSystem.ClassifyPlayer(entry.Target) == "Enemy"
                or NPCSystem.IsNPCModel(entry.Target) and Config.Proximity.IncludeNPC
            local distance = root and (entry.Root.Position - root.Position).Magnitude or math.huge
            if humanoid and humanoid.Health > 0 and validEnemy and distance <= Config.Proximity.Radius then
                local direction = camera.CFrame:VectorToObjectSpace(entry.Root.Position - root.Position)
                local angle = math.atan2(direction.X, -direction.Z)
                arrow.Frame.Position = UDim2.fromOffset((center.X + math.sin(angle) * radius) / scale,
                    (center.Y - math.cos(angle) * radius) / scale)
                arrow.Pointer.Rotation = math.deg(angle)
                arrow.Pointer.TextColor3 = distance < Config.Proximity.Radius * 0.35 and Color3.fromRGB(255, 88, 102) or Color3.fromRGB(255, 184, 89)
                arrow.Caption.Text = string.format("%d stud", math.floor(distance + 0.5))
                arrow.Frame.Visible = true; count += 1
            else arrow.Frame.Visible = false end
        else arrow.Frame.Visible = false end
    end
    if state.ProximitySummary then
        state.ProximitySummary.Visible = count > 0
        local inset = 36
        pcall(function() inset = game:GetService("GuiService"):GetGuiInset().Y end)
        state.ProximitySummary.Position = UDim2.fromOffset(center.X / scale, (inset + 12) / scale)
        state.ProximitySummary.Size = UDim2.fromOffset(math.min(242, viewport.X / scale - 20), 28)
        state.ProximitySummary.Text = Config.Interface.Language == "VI" and ("! " .. #(state.Nearby or {}) .. " địch ở gần")
            or ("! " .. #(state.Nearby or {}) .. " nearby enemies")
    end
end

function ExtraFeatures.V8.UpdateSelfHealth(camera)
    local state = ExtraFeatures.V8
    if not state.LocalHealth then return end
    local character = NPCSystem.GetCharacter(LocalPlayer)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local low = Config.Enabled and Config.ShowHealth and humanoid and humanoid.Health > 0
        and humanoid.Health / math.max(humanoid.MaxHealth, 1) <= 0.25 and GUIState.CurrentState ~= "Closed"
    state.LocalHealth.Visible = low == true
    if low and camera then
        local scale = math.max(UIScaleObj.Scale, 0.01)
        state.LocalHealth.Position = UDim2.fromOffset(camera.ViewportSize.X / (2 * scale), (camera.ViewportSize.Y - 18) / scale)
        state.LocalHealth.Size = UDim2.fromOffset(math.min(242, camera.ViewportSize.X / scale - 20), 28)
        local prefix = Config.Interface.Language == "VI" and "! MÁU CỦA BẠN THẤP: " or "! YOUR HEALTH IS LOW: "
        state.LocalHealth.Text = prefix .. math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
    end
end

function ExtraFeatures.V8.Update(camera)
    local state = ExtraFeatures.V8
    if state.Destroyed then return end
    local now = os.clock()
    if now - (state.LastScan or -math.huge) >= 0.15 then state.LastScan = now; state.ScanNearby() end
    state.UpdateProximity(camera); state.UpdateSelfHealth(camera)
    if state.FPSLabel then
        local fps = ExtraFeatures.UIEffects.Bubble.LastFPS or 0
        if fps ~= state.DisplayedFPS then
            state.DisplayedFPS = fps; state.FPSLabel.Text = "FPS  " .. tostring(fps)
            if state.FPSAccent then state.FPSAccent.BackgroundColor3 = fps >= 55 and Color3.fromRGB(71, 224, 184)
                or fps >= 30 and Color3.fromRGB(255, 195, 85) or Color3.fromRGB(255, 96, 121) end
        end
    end
    if state.UpdateProfile and now - (state.LastProfile or -math.huge) >= 1 then
        state.LastProfile = now; state.UpdateProfile(); state.UpdateWeaponStatus()
    end
end


function ExtraFeatures.V8.Session()
    _G.__HoodRivalsV8Sessions = _G.__HoodRivalsV8Sessions or {}
    local key = tostring(LocalPlayer.UserId)
    _G.__HoodRivalsV8Sessions[key] = _G.__HoodRivalsV8Sessions[key] or {Settings = {}, Profiles = {}}
    return _G.__HoodRivalsV8Sessions[key]
end

function ExtraFeatures.V8.ReadOwned(path)
    if not FileAPI.Available or not FileExists(path) then return nil end
    local raw = SafeReadFile(path)
    local payload = raw and SafeDecodeJSON(raw)
    if type(payload) == "table" and (payload.OwnerUserId == nil or payload.OwnerUserId == LocalPlayer.UserId) then return payload end
    return nil
end

function ExtraFeatures.V8.Request(action, data, callback)
    local state = ExtraFeatures.V8
    local folder = game:GetService("ReplicatedStorage"):FindFirstChild("HoodRivalsMenuService")
    local remote = folder and folder:FindFirstChild("Request")
    if not remote or not remote:IsA("RemoteFunction") then
        if callback then callback(false, {Reason = "Not connected"}) end
        return false
    end
    local finished = false
    local generation = state.SessionId
    local function complete(ok, response)
        if finished then return end
        finished = true
        if generation ~= state.SessionId then return end
        if state.Destroyed and action ~= "Close" and action ~= "Save" then return end
        if type(response) ~= "table" or response.OwnerUserId ~= LocalPlayer.UserId then
            ok, response = false, {Reason = "Invalid player storage response"}
        end
        if callback then callback(ok, response) end
    end
    task.delay(8, function() complete(false, {OwnerUserId = LocalPlayer.UserId, Reason = "Storage request timed out"}) end)
    task.spawn(function()
        local ok, response = pcall(function() return remote:InvokeServer(action, data, generation) end)
        if not ok then response = {OwnerUserId = LocalPlayer.UserId, Reason = tostring(response)} end
        complete(ok, response)
    end)
    return true
end

function ExtraFeatures.V8.QueueSave(section, payload, onSaved)
    local state = ExtraFeatures.V8
    state.PendingSaves = state.PendingSaves or {}
    state.PendingSaves[section] = {Payload = payload, Callback = onSaved, Attempts = 0}
    if state.ServerReady then state.ServerStatus = "Saving..." end
    state.SaveToken = (state.SaveToken or 0) + 1
    local token = state.SaveToken
    task.delay(0.65, function()
        if token ~= state.SaveToken or state.Destroyed then return end
        state.FlushSaves()
    end)
end

function ExtraFeatures.V8.FlushSaves()
    local state = ExtraFeatures.V8
    if not state.ServerReady or not state.PendingSaves or next(state.PendingSaves) == nil then return end
    local pending = state.PendingSaves; state.PendingSaves = {}
    local payload = {OwnerUserId = LocalPlayer.UserId, PlaceId = game.PlaceId}
    for section, item in pairs(pending) do payload[section] = item.Payload end
    state.Request("Save", payload, function(ok, response)
        if (response.RetryAfter or not ok) and not state.Destroyed then
            local retry = false
            for section, item in pairs(pending) do
                item.Attempts = (item.Attempts or 0) + 1
                if item.Attempts < 5 and not state.PendingSaves[section] then
                    state.PendingSaves[section] = item; retry = true
                end
            end
            state.ServerStatus = "Session only"
            if retry then
                task.delay(math.clamp(tonumber(response.RetryAfter) or 3, 0.8, 5), function() if not state.Destroyed then state.FlushSaves() end end)
                return
            end
        end
        state.ServerStatus = ok and response.Persisted and "Saved on server" or "Session only"
        for _, item in pairs(pending) do if item.Callback and not state.Destroyed then item.Callback(ok and response.Persisted == true) end end
        if state.UpdateProfile and not state.Destroyed then state.UpdateProfile() end
    end)
end

function ExtraFeatures.V8.SaveInterface()
    local state = ExtraFeatures.V8
    if state.Restoring or state.Destroyed then return end
    state.InterfaceRevision += 1
    local payload = ExtraFeatures.BuildInterfacePayload()
    state.Session().Interface = payload
    local encoded = SafeEncodeJSON(payload)
    state.InterfaceFileSaved = encoded and SafeWriteFile(state.InterfacePath, encoded) == true or false
    state.QueueSave("Interface", payload)
    if state.RefreshFavorites then state.RefreshFavorites() end
end

function ExtraFeatures.V8.SaveSettingsToStorage(payload)
    local state = ExtraFeatures.V8
    state.SettingsRevision += 1
    state.Session().Settings[tostring(game.PlaceId)] = payload
    state.QueueSave("Settings", payload, function(persisted)
        if persisted then SetSettingsStatus("Settings saved") end
    end)
end

function ExtraFeatures.V8.SaveProfilesToStorage()
    local state = ExtraFeatures.V8
    state.ProfilesRevision += 1
    for _, profile in ipairs(MenuProfiles) do profile.OwnerUserId = LocalPlayer.UserId end
    local snapshot = SafeDecodeJSON(SafeEncodeJSON(MenuProfiles)) or {}
    state.Session().Profiles = snapshot
    state.QueueSave("Profiles", snapshot, function(persisted)
        if persisted then SetSettingsStatus("Profiles saved") end
    end)
end

function ExtraFeatures.V8.ImportProfiles(profiles)
    if type(profiles) ~= "table" then return end
    local imported, ids, names = {}, {}, {}
    for _, profile in ipairs(profiles) do
        if #imported >= 80 then break end
        local owner = profile.OwnerUserId
        local name = type(profile.ProfileName or profile.name) == "string" and TrimString(profile.ProfileName or profile.name) or ""
        local config = profile.ConfigData or profile.config
        local id = type(profile.ProfileId or profile.profileId) == "string" and (profile.ProfileId or profile.profileId) or GenerateMenuProfileId()
        if (owner == nil or owner == LocalPlayer.UserId) and #name > 0 and #name <= 96 and type(config) == "table"
            and (config.OwnerUserId == nil or config.OwnerUserId == LocalPlayer.UserId) and not names[string.lower(name)] then
            if ids[id] then id = GenerateMenuProfileId() end
            profile.OwnerUserId, profile.ProfileId, profile.profileId = LocalPlayer.UserId, id, id
            profile.ProfileName, profile.name, profile.ConfigData, profile.config = name, name, config, config
            profile.GameName = profile.GameName or profile.gameName or "Unknown"
            profile.gameName = profile.GameName
            profile.PlaceId = tonumber(profile.PlaceId or profile.placeId) or 0; profile.placeId = profile.PlaceId
            table.insert(imported, profile); ids[id], names[string.lower(name)] = true, true
        end
    end
    MenuProfiles = imported
    RefreshMenuProfileList()
end

function ExtraFeatures.V8.ConnectStorage()
    local state = ExtraFeatures.V8
    if state.Destroyed or state.Connecting or state.ServerReady then return end
    state.Connecting = true
    local interfaceRevision, profileRevision = state.InterfaceRevision, state.ProfilesRevision
    local sent = state.Request("Load", {OwnerUserId = LocalPlayer.UserId, PlaceId = game.PlaceId}, function(ok, response)
        state.Connecting = false
        if not ok or response.Ok ~= true or response.Protocol ~= 8 then
            state.ServerStatus = FileAPI.Available and "Saved on device" or "Session only"
            state.UpdateWeaponStatus(); return
        end
        state.ServerReady, state.CanTune = true, response.CanTune == true
        state.ServerStatus = response.Persistent and "Saved on server" or "Session only"
        SetSettingsStatus(state.ServerStatus)
        local saved = response.Data or {}
        state.Restoring = true
        if interfaceRevision == state.InterfaceRevision and not state.HasLocalInterface and type(saved.Interface) == "table" then
            ExtraFeatures.ApplyInterfacePayload(saved.Interface); state.ApplyLanguage(); ExtraFeatures.ApplyInterfaceLayout(true)
        end
        if profileRevision == state.ProfilesRevision and #MenuProfiles == 0 and type(saved.Profiles) == "table" then state.ImportProfiles(saved.Profiles) end
        if type(saved.Settings) == "table" then state.ServerSettings = saved.Settings end
        state.Restoring = false
        if state.HasLocalInterface then state.QueueSave("Interface", ExtraFeatures.BuildInterfacePayload()) end
        if #MenuProfiles > 0 and profileRevision == state.ProfilesRevision then state.SaveProfilesToStorage() end
        state.FlushSaves(); state.SyncWeapon(); state.UpdateProfile()
    end)
    if not sent then
        state.Connecting = false
        state.ServerStatus = FileAPI.Available and "Saved on device" or "Session only"
        SetSettingsStatus(state.ServerStatus)
    end
end

function ExtraFeatures.V8.RestoreInterface()
    local state = ExtraFeatures.V8
    local saved = state.ReadOwned(state.InterfacePath) or state.Session().Interface
    state.HasLocalInterface = type(saved) == "table"
    if state.HasLocalInterface then
        state.Restoring = true; ExtraFeatures.ApplyInterfacePayload(saved); state.Restoring = false
    end
    if #MenuProfiles == 0 then state.ImportProfiles(state.Session().Profiles) end
end

function ExtraFeatures.V8.WeaponPayload(active)
    local source = Config.WeaponTuning
    return {Active = active == true, InfiniteAmmo = active and source.InfiniteAmmo == true or false,
        SkipReload = active and source.SkipReload == true or false,
        RecoilScale = active and source.RecoilEnabled and source.RecoilScale or 1,
        SpreadScale = active and source.SpreadEnabled and source.SpreadScale or 1}
end

function ExtraFeatures.V8.RegisterWeaponAdapter(name, adapter)
    if type(name) ~= "string" or type(adapter) ~= "table" or type(adapter.Apply) ~= "function" then
        return false, "Adapter requires a name and Apply(settings)"
    end
    ExtraFeatures.V8.WeaponAdapters[name] = adapter
    ExtraFeatures.V8.SyncWeapon()
    return true
end

function ExtraFeatures.V8.SyncWeapon()
    local state = ExtraFeatures.V8
    if state.Destroyed then return end
    local payload = state.WeaponPayload(GUIState.CurrentState ~= "Closed")
    for name, adapter in pairs(state.WeaponAdapters) do
        local ok, reason = pcall(adapter.Apply, table.clone(payload))
        if not ok then UI:Invoke(function() error(reason) end, "Weapon adapter: " .. name) end
    end
    state.WeaponSyncToken = (state.WeaponSyncToken or 0) + 1
    local token = state.WeaponSyncToken
    task.delay(0.12, function()
        if token ~= state.WeaponSyncToken or state.Destroyed or not state.ServerReady then return end
        state.Request("Weapon", payload, function(ok, response)
            if token ~= state.WeaponSyncToken or state.Destroyed then return end
            state.WeaponConfirmed = ok and response.Ok == true
            state.WeaponStatus = state.WeaponConfirmed and "Settings applied" or response.Reason or "Controller not connected"
            state.UpdateWeaponStatus()
        end)
    end)
    state.UpdateWeaponStatus()
end

function ExtraFeatures.V8.UpdateWeaponStatus()
    local state = ExtraFeatures.V8
    if not state.WeaponStatusLabel then return end
    local character = NPCSystem.GetCharacter(LocalPlayer)
    local tool = character and character:FindFirstChildOfClass("Tool")
    local supported = tool and tool:GetAttribute("HoodRivalsTuningVersion") == 1
    local adapter = next(state.WeaponAdapters) ~= nil
    local text
    if adapter then text = "Weapon: game adapter connected"
    elseif state.ServerReady and state.CanTune and supported then text = "Weapon: controller connected"
    elseif state.ServerReady and not state.CanTune then text = "Weapon: admin permission required"
    elseif state.ServerReady then text = "Weapon: waiting for a compatible equipped weapon"
    else text = "Weapon: controller not connected" end
    state.WeaponStatusLabel.Text = text
end

function ExtraFeatures.V8.Pause()
    local state = ExtraFeatures.V8
    state.HideProximity()
    if state.LocalHealth then state.LocalHealth.Visible = false end
    for _, adapter in pairs(state.WeaponAdapters) do pcall(adapter.Apply, state.WeaponPayload(false)) end
    if state.ServerReady then state.Request("Weapon", state.WeaponPayload(false)) end
    state.WeaponSyncToken = (state.WeaponSyncToken or 0) + 1
end

function ExtraFeatures.V8.Cleanup()
    local state = ExtraFeatures.V8
    state.SaveInterface(); state.FlushSaves(); state.Pause()
    if state.ServerReady then state.Request("Close", {}) end
    state.Destroyed = true
    for _, arrow in ipairs(state.Arrows or {}) do arrow.Frame:Destroy() end
    if state.ProximitySummary then state.ProximitySummary:Destroy() end
    if state.LocalHealth then state.LocalHealth:Destroy() end
    for object, record in pairs(state.Registry) do
        for _, connection in ipairs(record.Connections or {}) do connection:Disconnect() end
        state.Registry[object] = nil
    end
end


function UI:CreateChoice(parent, options)
    local frame = Instance.new("Frame"); frame.Name = "Choice_" .. options.Key
    frame.Size = UDim2.new(1, 0, 0, 62); frame.BackgroundTransparency = 1; frame.Parent = parent
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, 0, 0, 22)
    label.Text = options.Text; label.BackgroundTransparency = 1; label.Font = Enum.Font.GothamMedium
    label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextColor3 = Config.TextColor; label.Parent = frame
    local button = UI:CreateButton(frame, "", function() end)
    button.Name = "ChoiceValue"; button.Position = UDim2.fromOffset(0, 26); button.Size = UDim2.new(1, 0, 0, 32)
    button.TextXAlignment = Enum.TextXAlignment.Left; button.TextTruncate = Enum.TextTruncate.AtEnd
    local padding = Instance.new("UIPadding"); padding.PaddingLeft = UDim.new(0, 10); padding.Parent = button
    local api = {Frame = frame, Choices = options.Choices, Value = options.Default}
    function api.Get() return api.Value end
    function api.Refresh()
        for _, choice in ipairs(options.Choices) do if choice.Value == api.Value then button.Text = choice.Text .. "  ▾"; return end end
    end
    function api.Set(value, silent)
        for _, choice in ipairs(options.Choices) do
            if choice.Value == value then
                api.Value = value; api.Refresh()
                if silent ~= true then UI:Invoke(options.Callback, options.Text, value) end
                return true
            end
        end
        return false
    end
    UI:ConnectOwned(button, button.MouseButton1Click, function()
        local card = ExtraFeatures.NewDialog(options.Text, "", 300)
        local scroll = Instance.new("ScrollingFrame"); scroll.Size = UDim2.new(1, -32, 1, -108)
        scroll.Position = UDim2.fromOffset(16, 52); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(); scroll.ScrollBarThickness = 3; scroll.Parent = card
        local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 7); layout.Parent = scroll
        for _, choice in ipairs(options.Choices) do
            local item = UI:CreateButton(scroll, (choice.Value == api.Value and "✓  " or "") .. choice.Text, function()
                DestroyMenuProfilePopup(); api.Set(choice.Value)
            end)
            item.TextTruncate = Enum.TextTruncate.AtEnd
            if choice.Value == api.Value then item.TextColor3 = Config.AccentColor end
        end
        local cancel = UI:CreateButton(card, "CANCEL", DestroyMenuProfilePopup)
        cancel.Size = UDim2.new(1, -32, 0, 34); cancel.Position = UDim2.new(0, 16, 1, -48)
    end)
    api.Refresh()
    local record = UI:RegisterControl(frame, options.Text, "Choice", api, options)
    UI:AddFavorite(record, UDim2.new(1, -28, 0, -2))
    label.Size = UDim2.new(1, -35, 0, 22)
    return api
end

function ExtraFeatures.V8.ApplyFeatures(payload)
    local state = ExtraFeatures.V8
    if type(payload) ~= "table" then return end
    local priorities = {Crosshair = true, Nearest = true, LowestHealth = true, PlayersFirst = true, NPCFirst = true}
    if priorities[payload.AimPriority] then Config.AimPriority = payload.AimPriority end
    if type(payload.Classification) == "table" then
        local value = payload.Classification
        if value.Mode == "Auto" or value.Mode == "FFA" or value.Mode == "RobloxTeams" or value.Mode == "Custom" then Config.Classification.Mode = value.Mode end
        if type(value.Attribute) == "string" and #value.Attribute <= 64 then Config.Classification.Attribute = TrimString(value.Attribute) end
    end
    if type(payload.WeaponTuning) == "table" then
        for _, key in ipairs({"InfiniteAmmo", "SkipReload", "RecoilEnabled", "SpreadEnabled"}) do
            if type(payload.WeaponTuning[key]) == "boolean" then Config.WeaponTuning[key] = payload.WeaponTuning[key] end
        end
        for _, key in ipairs({"RecoilScale", "SpreadScale"}) do
            if IsFiniteNumber(payload.WeaponTuning[key]) then Config.WeaponTuning[key] = math.clamp(payload.WeaponTuning[key], 0, 1) end
        end
    end
    if type(payload.Proximity) == "table" then
        for _, key in ipairs({"Enabled", "IncludeNPC"}) do
            if type(payload.Proximity[key]) == "boolean" then Config.Proximity[key] = payload.Proximity[key] end
        end
        if IsFiniteNumber(payload.Proximity.Radius) then Config.Proximity.Radius = math.clamp(payload.Proximity.Radius, 10, 120) end
    end
    state.SyncControls(); state.SyncWeapon()
    if not Config.Proximity.Enabled then state.HideProximity() end
end

function ExtraFeatures.V8.SyncControls()
    local state = ExtraFeatures.V8
    for key, control in pairs(state.Controls or {}) do
        local value = key == "AimPriority" and Config.AimPriority or key == "Language" and Config.Interface.Language
            or key == "TeamMode" and Config.Classification.Mode or Config.WeaponTuning[key]
        if key == "RecoilScale" or key == "SpreadScale" then value = value * 100 end
        if value ~= nil then control.Set(value, true) end
    end
    if state.ProximityControl then state.ProximityControl.Set(Config.Proximity.Enabled, true) end
    if state.RadiusControl then state.RadiusControl.Set(Config.Proximity.Radius, true) end
    if state.IncludeNPCControl then state.IncludeNPCControl.Set(Config.Proximity.IncludeNPC, true) end
    if state.TeamAttributeBox then state.TeamAttributeBox.Text = Config.Classification.Attribute end
end

function ExtraFeatures.V8.FavoriteChordDown()
    return (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
        and UserInputService:IsKeyDown(Enum.KeyCode.S) and UserInputService:IsKeyDown(Enum.KeyCode.V)
end

function ExtraFeatures.V8.RefreshFavorites()
    local state = ExtraFeatures.V8
    if not state.FavoritesList then return end
    for _, child in ipairs(state.FavoritesList:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    state.FavoriteLinks = {}
    for _, record in ipairs(UIRefs.Experience.Controls) do
        if Config.Interface.Favorites[record.Id] and record.Frame.Parent then
            local function navigate()
                UIRefs.Experience.SearchBox.Text = ""; UIRefs.Experience.FavoritesOnly = false
                local section = record.Section.Frame
                while section and section ~= ContentArea do
                    local item = UIRefs.Experience.SectionByFrame[section]
                    if item then Config.Interface.CollapsedSections[item.Id] = nil end
                    section = section.Parent
                end
                UI:ApplyFilter(); PageManager:ShowPage(record.Page, true)
                local page = GUIState.Pages[record.Page]
                task.defer(function()
                    if state.Destroyed or not record.Frame.Parent then return end
                    page.CanvasPosition = Vector2.new(0, math.max(0, record.Frame.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y - 12))
                end)
                state.SaveInterface()
            end
            local text = state.Translate(record.Page) .. "  /  " .. state.Translate(record.Text)
            local button = UI:CreateButton(state.FavoritesList, text, navigate)
            button:SetAttribute("MenuNoTranslate", true)
            button.Size = UDim2.new(1, 0, 0, 42); button.TextXAlignment = Enum.TextXAlignment.Left
            button.TextSize = 12; button.TextTruncate = Enum.TextTruncate.AtEnd
            local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.Parent = button
            table.insert(state.FavoriteLinks, {Button = button, Record = record})
        end
    end
    state.FavoriteEmpty.Visible = #state.FavoriteLinks == 0
end

function ExtraFeatures.V8.OpenFavorites()
    local state = ExtraFeatures.V8
    if state.Destroyed or UIRefs.Experience.OverlayOpen then return end
    UIRefs.Experience.SearchBox.Text = ""; UIRefs.Experience.FavoritesOnly = false
    local button = MainWindow:FindFirstChild("FavoritesOnly", true)
    if button then button.Text = "☆  Favorites"; button.TextColor3 = Config.SubTextColor end
    if GUIState.CurrentState ~= "Open" then
        ExtraFeatures.UIEffects.AnimationBusy = false; SetMenuState("Open")
    end
    state.RefreshFavorites(); UI:ApplyFilter(); PageManager:ShowPage("FAVORITES", true)
end

function ExtraFeatures.V8.ProfileRow(parent, key)
    local row = Instance.new("Frame"); row.Name = "Info_" .. key; row.Size = UDim2.new(1, 0, 0, key == "Server ID" and 42 or 28)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1; row.Parent = parent
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.38, -4, 0, key == "Server ID" and 42 or 28)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1; label.Text = key; label.Font = Enum.Font.GothamMedium; label.TextSize = 11
    label.TextColor3 = Config.SubTextColor; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextWrapped = true; label.Parent = row
    local value = label:Clone(); value.Name = "ProfileValue"; value:SetAttribute("MenuNoTranslate", true)
    value.Size = UDim2.new(0.62, 0, 0, key == "Server ID" and 42 or 28); value.Position = UDim2.new(0.38, 0, 0, 0)
    value.TextColor3 = Config.TextColor; value.Text = "--"; value.Font = Enum.Font.GothamBold
    value.TextSize = 12; value.Parent = row
    ExtraFeatures.V8.ProfileValues[key] = value
    UI:RegisterControl(row, key, "Info", {}, {})
end

function ExtraFeatures.V8.UpdateProfile()
    local state = ExtraFeatures.V8
    if not state.ProfileValues then return end
    local function set(key, value)
        local label = state.ProfileValues[key]
        if label then label.Text = tostring(value == nil and "--" or value) end
    end
    set("Display Name", LocalPlayer.DisplayName); set("Username", "@" .. LocalPlayer.Name); set("User ID", LocalPlayer.UserId)
    set("Account Age", tostring(LocalPlayer.AccountAge or 0) .. (Config.Interface.Language == "VI" and " ngày" or " days"))
    local _, team = NPCSystem.GetTeamToken(LocalPlayer)
    set("Current Team", team or state.Translate("Unknown / FFA"))
    set("Game", CurrentGameName); set("Place ID", game.PlaceId); set("Universe ID", game.GameId)
    set("Server ID", game.JobId ~= "" and game.JobId or "Studio")
    local privateId = game.PrivateServerId
    set("Server Type", state.Translate(type(privateId) == "string" and privateId ~= "" and "Private / reserved" or "Public"))
    set("Players", tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers or "--"))
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    set("Network Ping", ok and type(ping) == "number" and (tostring(math.floor(ping * 1000 + 0.5)) .. " ms") or "--")
    local elapsed = math.max(0, math.floor(os.clock() - state.JoinedAt))
    set("Time in Session", string.format("%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60))
    set("Storage", state.Translate(state.ServerReady and state.ServerStatus or FileAPI.Available and "Saved on device" or "Session only"))
end

function ExtraFeatures.V8.BuildFPSBadge()
    local state = ExtraFeatures.V8
    FloatingBtn.Size = UDim2.fromOffset(146, 48)
    FloatingBtn.Text = ""; FloatingBtn.BackgroundColor3 = Color3.fromRGB(14, 24, 43)
    FloatingBtn.BackgroundTransparency = 0.06; FloatingBtn.BorderSizePixel = 0
    FloatCorner.CornerRadius = UDim.new(0, 11)
    FloatStroke.Color = Color3.fromRGB(108, 220, 255); FloatStroke.Thickness = 1.4; FloatStroke.Transparency = 0.22
    UIRefs.FloatingRainbowGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(51, 230, 205)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(87, 176, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 114, 255))})
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(Color3.fromRGB(18, 36, 57), Color3.fromRGB(20, 20, 39)); gradient.Rotation = 25; gradient.Parent = FloatingBtn
    local accent = Instance.new("Frame"); accent.Name = "PerformanceAccent"
    accent.Size = UDim2.fromOffset(3, 25); accent.Position = UDim2.fromOffset(10, 11)
    accent.BackgroundColor3 = Color3.fromRGB(71, 224, 184); accent.BorderSizePixel = 0; accent.Parent = FloatingBtn; state.FPSAccent = accent
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = accent
    local text = Instance.new("TextLabel"); text.Name = "FPSValue"
    text.Size = UDim2.new(1, -39, 1, 0); text.Position = UDim2.fromOffset(21, 0); text.BackgroundTransparency = 1
    text.Text = "FPS  --"; text.TextColor3 = Color3.fromRGB(235, 252, 255); text.Font = Enum.Font.GothamBold
    text.TextSize = 18; text.TextXAlignment = Enum.TextXAlignment.Left; text.Parent = FloatingBtn; state.FPSLabel = text
    local slash = text:Clone(); slash.Name = "GamingAccent"; slash.Size = UDim2.fromOffset(20, 24)
    slash.Position = UDim2.new(1, -24, 0.5, -12); slash.Text = "//"; slash.TextSize = 16
    slash.TextColor3 = Color3.fromRGB(99, 189, 226); slash.TextTransparency = 0.25; slash.Parent = FloatingBtn
    ExtraFeatures.ClampInterfaceFrame(FloatingBtn)
end

function ExtraFeatures.V8.Initialize()
    local state = ExtraFeatures.V8
    state.SessionId = GenerateMenuProfileId()
    state.InterfacePath = "HoodRivals_Interface_u" .. tostring(LocalPlayer.UserId) .. ".json"
    state.Controls = {}
    state.RestoreInterface()
    local aim = UI:CreateSection(GUIState.Pages.AIM, "AIM PRIORITY")
    state.Controls.AimPriority = UI:CreateChoice(aim, {Key = "AimPriority", Text = "Aim Priority", Default = Config.AimPriority,
        Choices = {{Value = "Crosshair", Text = "Crosshair (default)"}, {Value = "Nearest", Text = "Nearest to player"},
            {Value = "LowestHealth", Text = "Lowest health"}, {Value = "PlayersFirst", Text = "Players first"}, {Value = "NPCFirst", Text = "NPCs first"}},
        Callback = function(value) Config.AimPriority = value end})
    UI:CreateLabel(aim, "Priority still follows your team, wall, distance and NPC filters.")
    local weapon = UI:CreateSection(GUIState.Pages["FUNCTION 1"], "WEAPON TUNING")
    state.WeaponStatusLabel = UI:CreateLabel(weapon, "Weapon: controller not connected")
    for _, entry in ipairs({{"InfiniteAmmo", "Infinite Ammo"}, {"SkipReload", "Skip Reload"},
        {"RecoilEnabled", "Recoil Control"}, {"SpreadEnabled", "Spread Control"}}) do
        local key = entry[1]
        state.Controls[key] = UI:CreateToggle(weapon, {Text = entry[2], Default = Config.WeaponTuning[key],
            Callback = function(value) Config.WeaponTuning[key] = value; state.SyncWeapon() end})
    end
    for _, entry in ipairs({{"RecoilScale", "Recoil Amount (%)"}, {"SpreadScale", "Spread Amount (%)"}}) do
        local key = entry[1]
        state.Controls[key] = UI:CreateSlider(weapon, {Text = entry[2], Min = 0, Max = 100, Increment = 1,
            Default = Config.WeaponTuning[key] * 100, EditableValue = true,
            Callback = function(value) Config.WeaponTuning[key] = value / 100; state.SyncWeapon() end})
    end
    UI:CreateLabel(weapon, "0% removes the effect; 100% keeps the weapon's default.")
    UI:CreateLabel(weapon, "Recoil and spread apply to shot direction, not just camera visuals.")
    local proximity = UI:CreateSection(GUIState.Pages.ESP, "NEARBY ENEMY ALERT")
    state.ProximityControl = UI:CreateToggle(proximity, {Text = "Nearby Enemy Alert", Default = Config.Proximity.Enabled,
        Callback = function(value) Config.Proximity.Enabled = value; state.LastScan = nil; if not value then state.HideProximity() end end})
    state.RadiusControl = UI:CreateSlider(proximity, {Text = "Scan Radius", Min = 10, Max = 120, Default = Config.Proximity.Radius,
        Increment = 1, EditableValue = true, Callback = function(value) Config.Proximity.Radius = value; state.LastScan = nil end})
    state.IncludeNPCControl = UI:CreateToggle(proximity, {Text = "Include Hostile NPCs", Default = Config.Proximity.IncludeNPC,
        Callback = function(value) Config.Proximity.IncludeNPC = value; state.LastScan = nil end})
    UI:CreateLabel(proximity, "Arrows show nearby living enemies. Alerts clear when the area is safe.")
    local teams = UI:CreateSection(GUIState.Pages.ESP, "TEAM DETECTION")
    state.Controls.TeamMode = UI:CreateChoice(teams, {Key = "TeamMode", Text = "Team Detection", Default = Config.Classification.Mode,
        Choices = {{Value = "Auto", Text = "Auto"}, {Value = "FFA", Text = "Free for all (FFA)"},
            {Value = "RobloxTeams", Text = "Roblox teams"}, {Value = "Custom", Text = "Custom team attribute"}},
        Callback = function(value) Config.Classification.Mode = value; state.LastScan = nil; state.UpdateProfile() end})
    state.TeamAttributeBox = UI:CreateTextbox(teams, {Text = "Team Attribute", Default = Config.Classification.Attribute,
        Placeholder = "TeamId", Callback = function(value)
            value = TrimString(tostring(value)); if #value <= 64 then Config.Classification.Attribute = value end
            state.TeamAttributeBox.Text = Config.Classification.Attribute; state.LastScan = nil
        end})
    UI:CreateLabel(teams, "Auto checks custom combat teams before Roblox teams. Use FFA for games without teams.")
    UI:CreateLabel(teams, "Custom player rigs can expose PlayerUserId; NPCs remain a separate category.")
    local language = UI:CreateSection(SettingsPage, "LANGUAGE")
    state.Controls.Language = UI:CreateChoice(language, {Key = "Language", Text = "Language", Default = Config.Interface.Language,
        Choices = {{Value = "EN", Text = "English"}, {Value = "VI", Text = "Vietnamese"}},
        Callback = function(value) Config.Interface.Language = value; state.ApplyLanguage(); state.RefreshFavorites(); state.SaveInterface() end})
    UI:CreateLabel(language, "Shortcut: hold CTRL + S + V to open Favorites")
    local profile = PageManager:AddPage("PROFILE")
    GUIState.TabButtons.PROFILE.LayoutOrder = 90
    state.ProfileValues = {}
    local identity = UI:CreateSection(profile, "PLAYER IDENTITY")
    local avatar = Instance.new("ImageLabel"); avatar.Name = "ProfileAvatar"; avatar.Size = UDim2.fromOffset(84, 84)
    avatar.BackgroundColor3 = Config.DarkBg; avatar.BorderSizePixel = 0; avatar.Parent = identity
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 16); corner.Parent = avatar
    task.defer(function()
        local ok, image = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180) end)
        if ok and not state.Destroyed and avatar.Parent then avatar.Image = image end
    end)
    UI:CreateLabel(identity, "Read-only player and server information.")
    for _, key in ipairs({"Display Name", "Username", "User ID", "Account Age", "Current Team"}) do state.ProfileRow(identity, key) end
    local server = UI:CreateSection(profile, "GAME / SERVER")
    for _, key in ipairs({"Game", "Place ID", "Universe ID", "Server ID", "Server Type", "Players", "Network Ping"}) do state.ProfileRow(server, key) end
    local session = UI:CreateSection(profile, "SESSION / STORAGE")
    for _, key in ipairs({"Time in Session", "Storage"}) do state.ProfileRow(session, key) end
    local favorites = PageManager:AddPage("FAVORITES")
    GUIState.TabButtons.FAVORITES.LayoutOrder = -9
    state.FavoriteSection = UI:CreateSection(favorites, "YOUR FAVORITES")
    state.FavoriteEmpty = UI:CreateLabel(state.FavoriteSection, "No favorites yet. Click a star next to a feature.")
    state.FavoritesList = Instance.new("Frame"); state.FavoritesList.Size = UDim2.new(1, 0, 0, 0)
    state.FavoritesList.AutomaticSize = Enum.AutomaticSize.Y; state.FavoritesList.BackgroundTransparency = 1; state.FavoritesList.Parent = state.FavoriteSection
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.Parent = state.FavoritesList
    state.CreateOverlays(); state.BuildFPSBadge(); state.TrackTree(MainWindow)
    state.BaseDialog = ExtraFeatures.NewDialog
    ExtraFeatures.NewDialog = function(...)
        local card = state.BaseDialog(...); state.TrackTree(MenuProfilePopup); return card
    end
    state.BaseApplyFilter = UI.ApplyFilter
    UI.ApplyFilter = function(self)
        state.BaseApplyFilter(self)
        state.FavoriteSection.Visible = true
    end
    AddConnection(ScreenGui.DescendantAdded:Connect(state.TrackText))
    AddConnection(UserInputService.InputEnded:Connect(function()
        if not state.FavoriteChordDown() then state.FavoriteChordLatched = false end
    end))
    AddConnection(UserInputService.WindowFocusReleased:Connect(function() state.FavoriteChordLatched = false end))
    local replicated = game:GetService("ReplicatedStorage")
    AddConnection(replicated.DescendantAdded:Connect(function(item)
        if item.Name == "Request" or item.Name == "HoodRivalsMenuService" then task.defer(state.ConnectStorage) end
    end))
    state.ApplyLanguage(); state.RefreshFavorites(); state.UpdateProfile(); state.UpdateWeaponStatus()
    local lastPage = state.PendingLastPage or Config.Interface.LastPage
    if Config.Interface.RememberLayout and GUIState.Pages[lastPage] then
        PageManager:ShowPage(lastPage, true)
    end
    ExtraFeatures.ApplyInterfaceLayout(true)
    _G.MyGUIFramework.WeaponTuning = {RegisterAdapter = state.RegisterWeaponAdapter,
        GetSettings = function() return state.WeaponPayload(GUIState.CurrentState ~= "Closed") end, Sync = state.SyncWeapon}
    _G.MyGUIFramework.Classification = {RegisterTeamResolver = function(resolver)
        if resolver ~= nil and type(resolver) ~= "function" then return false end
        state.TeamResolver = resolver; state.LastScan = nil; return true
    end}
    _G.MyGUIFramework.Interface.OpenFavorites = state.OpenFavorites
    _G.MyGUIFramework.Interface.SetLanguage = function(value)
        if value ~= "EN" and value ~= "VI" then return false end
        Config.Interface.Language = value; state.ApplyLanguage(); state.RefreshFavorites(); state.SaveInterface(); return true
    end
    _G.MyGUIFramework.Settings.GetOwnerUserId = function() return LocalPlayer.UserId end
    state.ConnectStorage()
end

do
    local ok, reason = pcall(ExtraFeatures.V8.Initialize)
    if not ok then
        table.insert(UIRefs.Experience.Errors, {Time = os.time(), Text = "V8 initialization: " .. tostring(reason)})
        warn("[Hood Rivals V8] " .. tostring(reason))
    end
end

