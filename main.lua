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
    Title = "[VIP] PDuyz",
    Author = "Made By Pduyor_AI_",
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

    -- OTHER / SETTINGS
    ThirdPersonLock = false,
    XRayEnabled = false,
    XRayTransparency = 0.5,
    HoldToSpamEnabled = false,
    HoldToSpamKey = Enum.KeyCode.E,
    AntiAFKEnabled = false,
    VirtualPetEnabled = true,
    SnowfallEnabled = true,

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
    HeadHitboxEnabled = false,
    HeadHitboxSize = 0,

    -- =========================================================
    -- TELEKILL CONFIGURATION
    -- =========================================================
    TelekillEnabled = false,
    TelekillTarget = "Enemy",
    TelekillDistanceMode = "Nearest",
    TelekillDistance = 3,

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
    Textboxes = {}
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
ControlButtons.Size = UDim2.new(0, 90, 1, 0)
ControlButtons.Position = UDim2.new(1, -95, 0, 0)
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

UIRefs.NotificationButton = Instance.new("TextButton")
UIRefs.NotificationButton.Name = "Notification"
UIRefs.NotificationButton.Size = UDim2.new(0, 25, 0, 25)
UIRefs.NotificationButton.Position = UDim2.new(0, 30, 0.5, -12)
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
CloseBtn.Position = UDim2.new(0, 60, 0.5, -12)
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
FloatingBtn.Size = UDim2.fromOffset(48, 48)
FloatingBtn.Position = UDim2.new(1, -68, 1, -68)
FloatingBtn.BackgroundColor3 = Config.DarkBg
FloatingBtn.BackgroundTransparency = 0.35
FloatingBtn.Text = "Menu"
FloatingBtn.TextColor3 = Config.TextColor
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 15
FloatingBtn.AutoButtonColor = false
FloatingBtn.Visible = false
FloatingBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatingBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Config.AccentColor
FloatStroke.Thickness = 1.5
FloatStroke.Transparency = 0.12
FloatStroke.Parent = FloatingBtn

local isFloatDragged = MakeDraggable(FloatingBtn, FloatingBtn)

-- =========================================================
-- OTHER TAB SYSTEM
-- Only the seven requested features live here.
-- =========================================================
local OtherSystem = {
    XRayCache = {},
    ServerActionBusy = false,
    MenuMouseState = nil,
    KeybindListening = false,
    KeybindBox = nil,
    ConsumeNextToggleInput = false,
    Generation = 0
}

local ExtraFeatures = {
    HeadHitboxCache = {},
    HeadHitboxAccumulator = 0,

    TargetAssist = {
        CurrentTarget = nil
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
            Token = 0
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

    NotificationText = "Thông báo cái con Cặc, tự mò mà chơi",
    NotificationView = nil,
    NotificationPreviousPage = nil
}


-- =========================================================
-- ADVANCED UI EFFECTS
-- Dynamic tab color / explosive toggle / heavy slider / reactive pet.
-- These extend the existing UIEffects namespace and reuse the shared render
-- pipeline. No second PageManager, toggle engine, slider engine or ScreenGui.
-- =========================================================

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

function ExtraFeatures.OnTabChanged(previousPage, pageName)
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

    if part and part.Parent then
        pcall(function()
            part.Size = original.Size
            part.Transparency = original.Transparency
            part.CanCollide = original.CanCollide
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
            CanCollide = part.CanCollide
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
        part.Transparency =
            math.max(original.Transparency, 0.8)
        part.CanCollide = false
    end)
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

    -- Head Hitbox is intentionally restricted to the existing NPC registry.
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
    ExtraFeatures.SetAntiAFK(false)
    ExtraFeatures.RestoreGamePassSpoofer()

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

    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("BasePart") then
            OtherSystem.ApplyXRayPart(instance)
        end
    end
end

function OtherSystem.DisableXRay()
    Config.XRayEnabled = false

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
        if not Config.XRayEnabled then
            OtherSystem.EnableXRay()
        else
            OtherSystem.UpdateXRayTransparency()
        end
    else
        if Config.XRayEnabled then
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
            OtherSystem.MenuMouseState = {
                MouseBehavior = UserInputService.MouseBehavior,
                MouseIconEnabled = UserInputService.MouseIconEnabled
            }
        end

        pcall(function()
            UserInputService.MouseBehavior =
                Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
        return
    end

    local original = OtherSystem.MenuMouseState
    if not original then
        return
    end

    OtherSystem.MenuMouseState = nil

    pcall(function()
        UserInputService.MouseBehavior = original.MouseBehavior
        UserInputService.MouseIconEnabled =
            original.MouseIconEnabled
    end)
end

function OtherSystem.UpdateMenuInput()
    if GUIState.CurrentState == "Open" then
        OtherSystem.SetMenuMouseState(true)
    end
end

function OtherSystem.BeginKeybindCapture(box)
    if OtherSystem.KeybindListening then
        OtherSystem.KeybindListening = false
        OtherSystem.KeybindBox = nil

        if box and box.Parent then
            box.Text = Config.ToggleKey.Name
        end
        return
    end

    OtherSystem.KeybindListening = true
    OtherSystem.KeybindBox = box

    if box and box.Parent then
        box.Text = "Press Key"
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

    Config.ToggleKey = input.KeyCode
    OtherSystem.KeybindListening = false
    OtherSystem.ConsumeNextToggleInput = true

    if OtherSystem.KeybindBox
        and OtherSystem.KeybindBox.Parent
    then
        OtherSystem.KeybindBox.Text = Config.ToggleKey.Name
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

function PageManager:ShowPage(pageName, suppressEffects)
    local previousPage = GUIState.ActivePage

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
    if ExtraFeatures.NotificationView
        and ExtraFeatures.NotificationView.Parent
    then
        return ExtraFeatures.NotificationView
    end

    local view = Instance.new("Frame")
    view.Name = "NotificationInternalView"
    view.Size = UDim2.new(1, 0, 1, 0)
    view.BackgroundTransparency = 1
    view.Visible = false
    view.Parent = ContentArea

    local backButton = Instance.new("TextButton")
    backButton.Name = "Back"
    backButton.Size = UDim2.new(0, 38, 0, 28)
    backButton.Position = UDim2.new(0, 12, 0, 10)
    backButton.Text = "←"
    backButton.TextColor3 = Config.TextColor
    backButton.TextSize = 18
    backButton.Font = Enum.Font.GothamBold
    backButton.BackgroundColor3 = Config.CardBg
    backButton.AutoButtonColor = false
    backButton.Parent = view

    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(0, 6)
    backCorner.Parent = backButton

    local backStroke = Instance.new("UIStroke")
    backStroke.Color = Config.BorderColor
    backStroke.Thickness = 1
    backStroke.Parent = backButton

    local messageLabel = Instance.new("TextLabel")
    messageLabel.Name = "NotificationText"
    messageLabel.Size = UDim2.new(1, -24, 1, -58)
    messageLabel.Position = UDim2.new(0, 12, 0, 48)
    messageLabel.BackgroundColor3 = Config.CardBg
    messageLabel.BorderSizePixel = 0
    messageLabel.Text = ExtraFeatures.NotificationText
    messageLabel.TextColor3 = Config.TextColor
    messageLabel.TextSize = 13
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextWrapped = true
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextYAlignment = Enum.TextYAlignment.Top
    messageLabel.Parent = view

    local messageCorner = Instance.new("UICorner")
    messageCorner.CornerRadius = UDim.new(0, 6)
    messageCorner.Parent = messageLabel

    local messagePadding = Instance.new("UIPadding")
    messagePadding.PaddingTop = UDim.new(0, 12)
    messagePadding.PaddingLeft = UDim.new(0, 12)
    messagePadding.PaddingRight = UDim.new(0, 12)
    messagePadding.PaddingBottom = UDim.new(0, 12)
    messagePadding.Parent = messageLabel

    AddConnection(backButton.MouseButton1Click:Connect(function()
        view.Visible = false
        local previousPage = ExtraFeatures.NotificationPreviousPage
        ExtraFeatures.NotificationPreviousPage = nil

        if previousPage and GUIState.Pages[previousPage] then
            PageManager:ShowPage(previousPage, true)
        elseif Config.StartPage and GUIState.Pages[Config.StartPage] then
            PageManager:ShowPage(Config.StartPage, true)
        end
    end))

    ExtraFeatures.NotificationView = view
    return view
end

function ExtraFeatures.OpenNotificationView()
    local view = ExtraFeatures.BuildNotificationView()
    ExtraFeatures.NotificationPreviousPage = GUIState.ActivePage

    for _, page in pairs(GUIState.Pages) do
        page.Visible = false
    end

    local messageLabel = view:FindFirstChild("NotificationText")
    if messageLabel then
        messageLabel.Text = ExtraFeatures.NotificationText
    end

    view.Visible = true
end

AddConnection(UIRefs.NotificationButton.MouseButton1Click:Connect(function()
    ExtraFeatures.OpenNotificationView()
end))

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
            0.24,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        )

        local indicatorTweenInfo

        if userInitiated then
            indicatorTweenInfo = TweenInfo.new(
                0.34,
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

        if usePop then
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
            callback(state)
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

        if immediate == true then
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

    updateVisuals(true)

    return {
        Frame = sliderFrame,
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
    end
})

UIRefs.TelekillTargetButton = UI:CreateButton(
    TelekillSec,
    "Target: " .. tostring(Config.TelekillTarget),
    function()
        if Config.TelekillTarget == "Enemy" then
            Config.TelekillTarget = "Nearest"
        elseif Config.TelekillTarget == "Nearest" then
            Config.TelekillTarget = "Farthest"
        else
            Config.TelekillTarget = "Enemy"
        end

        UIRefs.TelekillTargetButton.Text =
            "Target: " .. tostring(Config.TelekillTarget)
    end
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

-- Telekill state is kept in one table so the existing top-level local budget
-- is not expanded by a collection of separate helper locals.
local Telekill = {
    CurrentTarget = nil
}

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
        and Players:GetPlayerFromCharacter(target) == nil
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
        return target.Character
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
    if not NPCSystem.IsPlayer(player) then
        return nil, nil
    end

    if player.Team ~= nil then
        return "TEAM", player.Team
    end

    -- TeamColor is used only when the game actually exposes Teams and the
    -- player is non-neutral, avoiding the common "all white = teammate" bug.
    local hasTeams = false
    pcall(function()
        hasTeams = #game:GetService("Teams"):GetTeams() > 0
    end)

    if hasTeams and player.Neutral == false and player.TeamColor ~= nil then
        return "TEAMCOLOR", player.TeamColor
    end

    -- Conservative fallback for games that expose custom team/faction state.
    local attributeNames = {
        "Team",
        "TeamName",
        "Faction"
    }

    for _, name in ipairs(attributeNames) do
        local value = player:GetAttribute(name)
        if value ~= nil then
            return "ATTRIBUTE:" .. name, tostring(value)
        end
    end

    local character = player.Character
    if character then
        for _, name in ipairs(attributeNames) do
            local valueObject = character:FindFirstChild(name)
            if valueObject and valueObject:IsA("StringValue") then
                return
                    "CHARACTER:" .. name,
                    valueObject.Value
            end
        end
    end

    return nil, nil
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
-- It now accepts both Player and NPC Model targets while preserving the same
-- validation chain and existing player behavior.
local function IsValidTarget(target)
    if not Config.AimEnabled then
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

    if isNPC and not Config.AimNPC then
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

    if
        not PassesVisibility(
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
                        camera,
                        targetPart.Position
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

    -- NPC targets are evaluated by the SAME target-selection pipeline.
    if Config.AimNPC then
        for npc in pairs(NPCSystem.ValidNPCs) do
            if IsValidTarget(npc) then
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

                    if screenDistance < math.huge then
                        if (not Config.UseFOV) or onScreen then
                            if screenDistance < bestScreenDistance then
                                bestScreenDistance = screenDistance
                                bestTarget = npc
                                bestAimPart = targetPart
                            end
                        end
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
    if not target or target == LocalPlayer then
        return false
    end

    if not target:IsDescendantOf(Players) then
        return false
    end

    local character = target.Character
    local humanoid =
        character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or humanoid.Health <= 0 or not root then
        return false
    end

    return true
end

function Telekill.IsEnemy(target)
    if not target or target == LocalPlayer then
        return false
    end

    local localTeam = LocalPlayer.Team
    local targetTeam = target.Team

    -- When the game does not expose Teams, keep the target eligible instead
    -- of incorrectly rejecting everyone because both Team values are nil.
    if localTeam and targetTeam then
        return targetTeam ~= localTeam
    end

    return true
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

function Telekill.GetBestTarget()
    if not Config.TelekillEnabled then
        return nil
    end

    local localRoot = Telekill.GetLocalRoot()
    if not localRoot then
        return nil
    end

    local mode = Config.TelekillTarget
    local distanceMode = Config.TelekillDistanceMode

    local bestTarget = nil
    local bestDistance =
        (mode == "Farthest" or (mode == "Enemy" and distanceMode == "Farthest"))
        and -math.huge
        or math.huge

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer and Telekill.IsValidTarget(target) then
            local eligible = false

            if mode == "Enemy" then
                eligible = Telekill.IsEnemy(target)
            else
                -- "Nearest" and "Farthest" intentionally consider all
                -- other valid players, independent of Team Check.
                eligible = true
            end

            if eligible then
                local targetRoot = GetAimRoot(target)
                local distance =
                    Telekill.GetTargetDistance(targetRoot, localRoot)

                if mode == "Farthest"
                    or (mode == "Enemy" and distanceMode == "Farthest")
                then
                    if distance < math.huge and distance > bestDistance then
                        bestDistance = distance
                        bestTarget = target
                    end
                elseif distance < bestDistance then
                    bestDistance = distance
                    bestTarget = target
                end
            end
        end
    end

    return bestTarget
end

function Telekill.GetPosition(targetRoot, teleDistance)
    if not targetRoot then
        return nil
    end

    local distance = tonumber(teleDistance) or 3
    if not Telekill.IsFiniteNumber(distance) then
        distance = 3
    end
    distance = math.clamp(distance, 1, 20)

    local localRoot = Telekill.GetLocalRoot()
    local away = Vector3.zero

    if localRoot then
        away = localRoot.Position - targetRoot.Position
    end

    away = Vector3.new(away.X, 0, away.Z)

    if away.Magnitude < 0.001 then
        local look = targetRoot.CFrame.LookVector
        away = Vector3.new(look.X, 0, look.Z)
    end

    if away.Magnitude < 0.001 then
        away = Vector3.new(0, 0, 1)
    else
        away = away.Unit
    end

    -- Keep the player's vertical level aligned with the target root instead
    -- of constructing an arbitrary downward position. This prevents the
    -- Telekill offset itself from sending the character below the target.
    local candidate =
        targetRoot.Position
        + (away * distance)

    if not Telekill.IsFiniteNumber(candidate.X)
        or not Telekill.IsFiniteNumber(candidate.Y)
        or not Telekill.IsFiniteNumber(candidate.Z)
    then
        return nil
    end

    return candidate
end

function Telekill.Teleport(target)
    if not target or not Telekill.IsValidTarget(target) then
        return false
    end

    local character = LocalPlayer.Character
    local localRoot = Telekill.GetLocalRoot()
    local targetRoot = GetAimRoot(target)

    if not character or not localRoot or not targetRoot then
        return false
    end

    local destination =
        Telekill.GetPosition(
            targetRoot,
            Config.TelekillDistance
        )

    if not destination then
        return false
    end

    local currentPivot = character:GetPivot()
    local destinationCFrame =
        CFrame.new(destination) * currentPivot.Rotation

    local ok = pcall(function()
        character:PivotTo(destinationCFrame)
    end)

    if not ok then
        return false
    end

    return true
end

function Telekill.Update()
    if not Config.TelekillEnabled then
        Telekill.CurrentTarget = nil
        return
    end

    -- Re-evaluate the requested target mode from CURRENT player positions.
    -- The target reference is only a context handle; no position is cached.
    local target = Telekill.GetBestTarget()
    Telekill.CurrentTarget = target

    if not target then
        CurrentAimTarget = nil
        return
    end

    -- Re-read the current target root at the moment of teleport.
    local targetRoot = GetAimRoot(target)
    if not targetRoot then
        Telekill.CurrentTarget = nil
        CurrentAimTarget = nil
        return
    end

    if not Telekill.Teleport(target) then
        -- Target remains eligible for the next render update; no stale
        -- position is cached and no error is allowed to break the script.
        CurrentAimTarget = target
        return
    end

    -- Supply the same target context to the existing AIM controller.
    CurrentAimTarget = target
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

    return Vector2.new(
        position.X,
        position.Y
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
            width,
            height
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

    data.kind =
        NPCSystem.IsNPCModel(target)
        and "NPC"
        or "Player"

    data.character = NPCSystem.GetCharacter(target)
    data.info = createInfo()
    data.tracer = createScreenLine("ESPTracer")
    data.box = NPCSystem.CreateScreenBox()
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
    else
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

            healthLabel.Text =
                "HP: "
                .. currentHP
                .. " / "
                .. maxHP
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
        destroyAllESPHighlights()
        return
    end

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
-- SETTINGS TAB / SAVE-LOAD / MENU PROFILES
-- Uses the existing PageManager + UI component system.
-- =========================================================

local SettingsPage = PageManager:AddPage("SETTINGS")

local SettingsStatusLabel

local CONFIG_FILE = "HoodRivals_Settings.json"

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
    if SettingsStatusLabel then
        SettingsStatusLabel.Text = tostring(message or "")
    end
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
    FloatingBtn.BackgroundTransparency = 0.35
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
                            BackgroundTransparency = 0.35
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

    for _, tween in ipairs({
        bubble.HoverTween,
        bubble.ScaleTween,
        bubble.MainTween,
        bubble.MainFadeTween
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
        version = 4,

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
        HeadHitboxEnabled = Config.HeadHitboxEnabled,
        HeadHitboxSize = Config.HeadHitboxSize,

        -- TELEKILL
        TelekillEnabled = Config.TelekillEnabled,
        TelekillTarget = Config.TelekillTarget,
        TelekillDistanceMode = Config.TelekillDistanceMode,
        TelekillDistance = Config.TelekillDistance,

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

    local oldFullBrightEnabled = Config.Player.FullBrightEnabled

    SetBooleanField(payload, "AimEnabled", Config)
    SetBooleanField(payload, "TeamCheck", Config)
    SetBooleanField(payload, "WallCheck", Config)
    SetBooleanField(payload, "IgnoreVisibility", Config)
    SetBooleanField(payload, "UseFOV", Config)
    SetNumberField(payload, "FOV", Config, nil, 0, 180)
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

    if type(payload.TelekillTarget) == "string" then
        if payload.TelekillTarget == "Enemy"
            or payload.TelekillTarget == "Nearest"
            or payload.TelekillTarget == "Farthest"
        then
            Config.TelekillTarget = payload.TelekillTarget
        end
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

    -- Apply menu-level persistent values directly after validation.
    UIScaleObj.Scale = Config.UIScale
    MainWindow.BackgroundTransparency =
        Config.BackgroundTransparency

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
    if UIRefs.TelekillTargetButton then
        UIRefs.TelekillTargetButton.Text =
            "Target: " .. tostring(Config.TelekillTarget)
    end
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

    local encoded = SafeEncodeJSON(payload)
    if not encoded then
        SetSettingsStatus(
            "Settings saved for this session; JSON encoding unavailable"
        )
        return
    end

    local ok = false
    if FileAPI.Available then
        ok = SafeWriteFile(CONFIG_FILE, encoded)
    end

    if ok then
        SetSettingsStatus("Settings saved")
    else
        SetSettingsStatus(
            "Settings saved for this session; filesystem unavailable or write failed"
        )
    end
end

local function LoadSettings()
    local payload = nil

    if FileAPI.Available and FileExists(CONFIG_FILE) then
        local raw, readReason = SafeReadFile(CONFIG_FILE)

        if not raw then
            SetSettingsStatus("Settings load failed: " .. tostring(readReason))
            return
        end

        local decoded, decodeReason = SafeDecodeJSON(raw)
        if not decoded then
            SetSettingsStatus(
                "Settings load failed: " .. tostring(decodeReason)
            )
            return
        end

        payload = decoded
    elseif SessionConfigBackup then
        -- Session backup is also used when file persistence is unavailable
        -- or the previous write failed.
        payload = SessionConfigBackup
    else
        SetSettingsStatus("No saved settings found")
        return
    end

    local ok, err = ApplyConfigPayload(payload)
    if not ok then
        SetSettingsStatus(
            "Settings load failed: " .. tostring(err)
        )
        return
    end

    SyncSettingsUI()
    SetSettingsStatus("Settings loaded")
end


local MenuProfilesFile = "HoodRivals_MenuProfiles.json"
local MenuProfiles = {}
local MenuProfileConnections = {}
local MenuProfilePopupConnections = {}
local MenuProfileList
local MenuProfilePopup

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
    local names = {}

    for _, profile in ipairs(decoded) do
        if type(profile) == "table" then
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

                local profileKey =
                    tostring(placeId)
                    .. "|"
                    .. tostring(gameName)
                    .. "|"
                    .. name

                if name ~= "" and not names[profileKey] then
                    table.insert(cleaned, {
                        ProfileName = name,
                        GameName = gameName,
                        PlaceId = placeId,
                        Version = version,
                        CreatedAt = createdAt,
                        ConfigData = rawConfig,

                        -- Legacy aliases kept for old code/profile compatibility.
                        name = name,
                        gameName = gameName,
                        placeId = placeId,
                        version = version,
                        createdAt = createdAt,
                        config = rawConfig
                    })

                    names[profileKey] = true
                end
            end
        end
    end

    MenuProfiles = cleaned
end

local function FindMenuProfile(name)
    for _, profile in ipairs(MenuProfiles) do
        if profile.name == name
            and profile.placeId == CurrentPlaceId
            and profile.gameName == CurrentGameName
        then
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

local function DeleteMenuProfile(profileName)
    local indexToRemove

    for index, profile in ipairs(MenuProfiles) do
        if profile.name == profileName
            and profile.placeId == CurrentPlaceId
            and profile.gameName == CurrentGameName
        then
            indexToRemove = index
            break
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
    if not MenuProfileList then
        return
    end

    DisconnectMenuProfileConnections()

    for _, child in ipairs(MenuProfileList:GetChildren()) do
        if not child:IsA("UIListLayout")
            and not child:IsA("UIPadding")
        then
            child:Destroy()
        end
    end

    local visibleProfiles = {}

    for _, profile in ipairs(MenuProfiles) do
        if profile.placeId == CurrentPlaceId
            and profile.gameName == CurrentGameName
        then
            table.insert(
                visibleProfiles,
                profile
            )
        end
    end

    for index, profile in ipairs(visibleProfiles) do
        local item = Instance.new("Frame")
        item.Name =
            "MenuProfile_" .. tostring(index)
        item.Size =
            UDim2.new(1, -4, 0, 56)
        item.BackgroundColor3 = Config.DarkBg
        item.BorderSizePixel = 0
        item.Parent = MenuProfileList

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = item

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size =
            UDim2.new(1, -155, 0, 22)
        nameLabel.Position =
            UDim2.new(0, 8, 0, 5)
        nameLabel.Text = profile.name
        nameLabel.TextColor3 = Config.TextColor
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment =
            Enum.TextXAlignment.Left
        nameLabel.TextTruncate =
            Enum.TextTruncate.AtEnd
        nameLabel.BackgroundTransparency = 1
        nameLabel.Parent = item

        local gameLabel = Instance.new("TextLabel")
        gameLabel.Size =
            UDim2.new(1, -155, 0, 18)
        gameLabel.Position =
            UDim2.new(0, 8, 0, 28)
        gameLabel.Text =
            tostring(profile.gameName)
            .. " | PlaceId: "
            .. tostring(profile.placeId)
        gameLabel.TextColor3 =
            Config.SubTextColor
        gameLabel.Font = Enum.Font.Gotham
        gameLabel.TextSize = 9
        gameLabel.TextXAlignment =
            Enum.TextXAlignment.Left
        gameLabel.TextTruncate =
            Enum.TextTruncate.AtEnd
        gameLabel.BackgroundTransparency = 1
        gameLabel.Parent = item

        local runButton =
            UI:CreateButton(
                item,
                "RUN",
                function()
                    ApplyMenuProfile(profile)
                end
            )

        runButton.Size =
            UDim2.new(0, 58, 0, 24)
        runButton.Position =
            UDim2.new(1, -132, 0, 16)

        local deleteButton =
            UI:CreateButton(
                item,
                "DELETE",
                function()
                    if DeleteMenuProfile(profile.name) then
                        RefreshMenuProfileList()
                        SetSettingsStatus(
                            "Profile deleted: "
                            .. tostring(profile.name)
                        )
                    end
                end
            )

        deleteButton.Size =
            UDim2.new(0, 66, 0, 24)
        deleteButton.Position =
            UDim2.new(1, -70, 0, 16)

        
    end

    MenuProfileList.CanvasSize =
        UDim2.new(
            0,
            0,
            0,
            #visibleProfiles * 62 + 4
        )
end

local function OpenSaveMenuProfilePopup()
    DestroyMenuProfilePopup()

    local popup = Instance.new("Frame")
    MenuProfilePopup = popup
    popup.Name =
        "SaveMenuProfilePopup"
    popup.Size =
        UDim2.new(0, 300, 0, 150)
    popup.AnchorPoint =
        Vector2.new(0.5, 0.5)
    popup.Position =
        UDim2.new(0.5, 0, 0.5, 0)
    popup.BackgroundColor3 =
        Config.CardBg
    popup.BorderSizePixel = 0
    popup.ZIndex = 200
    popup.Parent = MainWindow

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = popup

    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.BorderColor
    stroke.Thickness = 1
    stroke.Parent = popup

    local title = Instance.new("TextLabel")
    title.Size =
        UDim2.new(1, -20, 0, 24)
    title.Position =
        UDim2.new(0, 10, 0, 9)
    title.Text = "SAVE MENU"
    title.TextColor3 =
        Config.TextColor
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment =
        Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.ZIndex = 201
    title.Parent = popup

    local nameBox = Instance.new("TextBox")
    nameBox.Size =
        UDim2.new(1, -20, 0, 32)
    nameBox.Position =
        UDim2.new(0, 10, 0, 38)
    nameBox.PlaceholderText =
        "Nhập tên profile..."
    nameBox.Text = ""
    nameBox.TextColor3 =
        Config.TextColor
    nameBox.PlaceholderColor3 =
        Config.SubTextColor
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 12
    nameBox.BackgroundColor3 =
        Config.DarkBg
    nameBox.BorderSizePixel = 0
    nameBox.ClearTextOnFocus = false
    nameBox.ZIndex = 201
    nameBox.Parent = popup

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius =
        UDim.new(0, 5)
    boxCorner.Parent = nameBox

    local saveButton =
        UI:CreateButton(
            popup,
            "SAVE",
            function()
                local profileName =
                    TrimString(nameBox.Text)

                if profileName == "" then
                    SetSettingsStatus(
                        "Enter a profile name first"
                    )
                    return
                end

                local profile =
                    FindMenuProfile(profileName)
                local payload =
                    BuildConfigPayload()

                if profile then
                    SetSettingsStatus(
                        "Profile already exists in this game. DELETE it first or use another name."
                    )
                    return
                end

                table.insert(
                    MenuProfiles,
                    {
                        ProfileName = profileName,
                        GameName = CurrentGameName,
                        PlaceId = CurrentPlaceId,
                        ConfigData = payload,
                        Version = 1,
                        CreatedAt = os.time(),

                        -- Compatibility aliases for older profile readers.
                        name = profileName,
                        gameName = CurrentGameName,
                        placeId = CurrentPlaceId,
                        config = payload,
                        version = 1,
                        createdAt = os.time()
                    }
                )

                SaveMenuProfiles()
                RefreshMenuProfileList()
                DestroyMenuProfilePopup()

                SetSettingsStatus(
                    "Profile saved: "
                    .. profileName
                )
            end
        )

    saveButton.Size =
        UDim2.new(0, 120, 0, 30)
    saveButton.Position =
        UDim2.new(0, 18, 1, -40)

    local cancelButton =
        UI:CreateButton(
            popup,
            "CANCEL",
            function()
                DestroyMenuProfilePopup()
            end
        )

    cancelButton.Size =
        UDim2.new(0, 120, 0, 30)
    cancelButton.Position =
        UDim2.new(1, -138, 1, -40)

    table.insert(
        MenuProfilePopupConnections,
        nameBox.FocusLost:Connect(
            function(enterPressed)
                if enterPressed then
                    saveButton:Activate()
                end
            end
        )
    )

    pcall(function()
        nameBox:CaptureFocus()
    end)
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
    "Current Game: "
        .. tostring(CurrentGameName)
        .. "\nPlaceId: "
        .. tostring(CurrentPlaceId)
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
        "Filesystem persistence unavailable; session-only profiles"
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
    "🗿  Đổi Server",
    function()
        OtherSystem.RunServerAction("Change")
    end
)

UI:CreateButton(
    GUIState.Pages["KHÁC"]:FindFirstChild(
        "SERVERSection"
    ),
    "⚡️  Ping Thấp",
    function()
        OtherSystem.RunServerAction("Ping")
    end
)

UI:CreateButton(
    GUIState.Pages["KHÁC"]:FindFirstChild(
        "SERVERSection"
    ),
    "🫃  Ít Người",
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
UIRefs.OtherToggleKeyBox.Font = Enum.Font.Gotham
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

pcall(function()
    RunService:UnbindFromRenderStep("HoodRivalsUnifiedRender")
    RunService:UnbindFromRenderStep("HoodRivalsAimRender")
    RunService:UnbindFromRenderStep("HoodRivalsESPRender")
end)

-- Existing Player + Teleport runtime remains isolated from AIM/ESP timing.
RunService:BindToRenderStep(
    "HoodRivalsUnifiedRender",
    Enum.RenderPriority.Character.Value + 1,
    function(renderDt)
        UpdatePlayer(renderDt)
        UpdateTeleport()
        pcall(function()
            ExtraFeatures.UpdateHeadHitboxes(renderDt, false)
        end)
        ExtraFeatures.UpdateHoldSpam(renderDt)
        pcall(function()
            ExtraFeatures.UpdateHeavySliders(renderDt)
        end)
        OtherSystem.UpdateMenuInput()
    end
)

-- AIM runs late enough to observe the final weapon/camera state,
-- and one stage before ESP so ESP can project from the post-AIM camera.
RunService:BindToRenderStep(
    "HoodRivalsAimRender",
    Enum.RenderPriority.Last.Value - 1,
    function()
        Telekill.Update()
        pcall(function()
            ExtraFeatures.UpdateTargetAssist()
        end)
        UpdateAim()
        UpdateFOVCircle()
    end
)

-- ESP is the final projection stage and reads one CurrentCamera snapshot
-- for the whole frame.
RunService:BindToRenderStep(
    "HoodRivalsESPRender",
    Enum.RenderPriority.Last.Value,
    function()
        local camera = Workspace.CurrentCamera
        updateESP(camera)
        UpdateESPHighlight()
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

            if ExtraFeatures.TargetAssist.CurrentTarget == target then
                ExtraFeatures.ClearTargetAssist()
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

        if Telekill.CurrentTarget == target then
            Telekill.CurrentTarget = nil
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
        ScreenGui.Enabled = true
        OtherSystem.SetMenuMouseState(true)

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
        end
    elseif newState == "Closed" then
        if effects then
            effects.AnimationBusy = false
            effects.Bubble.Token =
                effects.Bubble.Token + 1
        end

        ScreenGui.Enabled = false
        OtherSystem.SetMenuMouseState(false)
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
    ExtraFeatures.RestoreAllHeadHitboxes()
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

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Config.HoldToSpamKey
            and Config.HoldToSpamEnabled
        then
            ExtraFeatures.HoldSpamKeyHeld = true
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2
        and Config.HoldToSpamEnabled
    then
        ExtraFeatures.HoldSpamRightHeld = true
    end

    if input.UserInputType == Enum.UserInputType.Keyboard
        and Config.HoldToSpamEnabled
        and input.KeyCode == Config.HoldToSpamKey
    then
        return
    end

    if gameProcessed then return end
    if Config.ToggleKeyEnabled and input.KeyCode == Config.ToggleKey then
        if GUIState.CurrentState == "Open" then
            SetMenuState("Minimized")
        elseif GUIState.CurrentState == "Minimized" or GUIState.CurrentState == "Closed" then
            ScreenGui.Enabled = true

            -- Rebind the render pipeline safely.
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

            RunService:BindToRenderStep(
                "HoodRivalsUnifiedRender",
                Enum.RenderPriority.Character.Value + 1,
                function(renderDt)
                    UpdatePlayer(renderDt)
                    UpdateTeleport()
                    ExtraFeatures.UpdateHeadHitboxes(renderDt, false)
                    ExtraFeatures.UpdateHoldSpam(renderDt)
                    pcall(function()
                        ExtraFeatures.UpdateHeavySliders(renderDt)
                    end)
                    OtherSystem.UpdateMenuInput()
                end
            )

            RunService:BindToRenderStep(
                "HoodRivalsAimRender",
                Enum.RenderPriority.Last.Value - 1,
                function()
                    Telekill.Update()
                    ExtraFeatures.UpdateTargetAssist()
                    UpdateAim()
                    UpdateFOVCircle()
                end
            )

            RunService:BindToRenderStep(
                "HoodRivalsESPRender",
                Enum.RenderPriority.Last.Value,
                function()
                    local camera = Workspace.CurrentCamera
                    updateESP(camera)
                    UpdateESPHighlight()
                end
            )

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
        end
    },

    NPC = NPCSystem,

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
