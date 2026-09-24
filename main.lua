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

    -- OTHER TAB
    ThirdPersonLock = false,
    XRayEnabled = false,
    XRayTransparency = 0.5,

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
    ESPOffsetX = 0,
    ESPOffsetY = 0,
    ESPOffsetZ = 0,

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

    local function applyState(newState, invokeCallback)
        if type(newState) ~= "boolean" then
            return
        end

        state = newState
        local targetColor = state and Config.AccentColor or Config.DarkBg
        local targetPos = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)

        TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = targetPos}):Play()

        if invokeCallback ~= false then
            callback(state)
        end
    end

    local function toggle()
        applyState(not state, true)
    end

    switch.MouseButton1Click:Connect(toggle)
    return {
        Set = function(val, silent)
            if type(val) ~= "boolean" then
                return
            end

            if state ~= val then
                applyState(val, silent ~= true)
            elseif silent then
                -- Force a visual refresh without firing the callback.
                applyState(val, false)
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
        updateVisuals()

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

    updateVisuals()

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

    local offsetX = tonumber(Config.ESPOffsetX) or 0
    local offsetY = tonumber(Config.ESPOffsetY) or 0

    -- X positive = right / negative = left.
    -- Y positive = up / negative = down.
    return Vector2.new(
        position.X + offsetX,
        position.Y - offsetY
    )
end

-- Z is applied in camera-relative WORLD space BEFORE projection.
-- X/Y are deliberately NOT applied here, preventing double application.
local function ProjectESPWorldPosition(camera, worldPosition)
    if not camera or not worldPosition then
        return nil, false, nil
    end

    local zOffset = tonumber(Config.ESPOffsetZ) or 0

    -- Config +Z = closer to the camera, -Z = farther away.
    -- Roblox Camera.LookVector points forward into the scene, so subtracting
    -- it makes positive Z move the ESP projection toward the camera.
    local adjustedWorldPosition =
        worldPosition - camera.CFrame.LookVector * zOffset

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
-- SETTINGS TAB / SAVE-LOAD / ESP OFFSET PROFILES
-- Uses the existing PageManager + UI component system.
-- =========================================================

local SettingsPage = PageManager:AddPage("SETTINGS")

local SettingsStatusLabel

local CONFIG_FILE = "HoodRivals_Settings.json"
local ESP_PROFILES_FILE = "HoodRivals_ESP_Offset_Profiles.json"

local SessionConfigBackup = nil
local ESPProfiles = {}
local ProfileConnections = {}
local ProfilePopupConnections = {}
local ProfileNameInput
local ProfileList
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
        version = 2,

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
        ESPOffsetX = Config.ESPOffsetX,
        ESPOffsetY = Config.ESPOffsetY,
        ESPOffsetZ = Config.ESPOffsetZ,

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
    SetNumberField(payload, "ESPOffsetX", Config, nil, -200, 200)
    SetNumberField(payload, "ESPOffsetY", Config, nil, -200, 200)
    SetNumberField(payload, "ESPOffsetZ", Config, nil, -200, 200)

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

    if UIRefs.Sliders.ESPOffsetX then
        UIRefs.Sliders.ESPOffsetX.Set(Config.ESPOffsetX, true)
    end
    if UIRefs.Sliders.ESPOffsetY then
        UIRefs.Sliders.ESPOffsetY.Set(Config.ESPOffsetY, true)
    end
    if UIRefs.Sliders.ESPOffsetZ then
        UIRefs.Sliders.ESPOffsetZ.Set(Config.ESPOffsetZ, true)
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

local function DisconnectProfileConnections()
    for _, conn in ipairs(ProfileConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    table.clear(ProfileConnections)
end

local function AddProfileConnection(conn)
    if conn then
        table.insert(ProfileConnections, conn)
    end

    return conn
end

local function SaveESPProfiles()
    local encoded = SafeEncodeJSON(ESPProfiles)

    if not encoded then
        SetSettingsStatus(
            "Profile updated for this session; JSON encoding unavailable"
        )
        return false
    end

    if not FileAPI.Available then
        SetSettingsStatus(
            "Profile updated for this session; filesystem unavailable"
        )
        return false
    end

    local ok = SafeWriteFile(ESP_PROFILES_FILE, encoded)
    if not ok then
        SetSettingsStatus(
            "Profile updated for this session; filesystem unavailable or write failed"
        )
        return false
    end

    return true
end

local function LoadESPProfiles()
    if not FileAPI.Available then
        return
    end

    if not FileExists(ESP_PROFILES_FILE) then
        return
    end

    local raw = SafeReadFile(ESP_PROFILES_FILE)
    if not raw then
        SetSettingsStatus("Profile load skipped: file read failed")
        return
    end

    local decoded = SafeDecodeJSON(raw)
    if type(decoded) ~= "table" then
        SetSettingsStatus("Profile load skipped: invalid profile file")
        return
    end

    local loadedProfiles = {}
    local names = {}

    for _, profile in ipairs(decoded) do
        if type(profile) == "table" then
            local name = TrimString(profile.name)
            local x = profile.x
            local y = profile.y
            local z = profile.z

            -- Legacy profiles have only X/Y; Z defaults to 0.
            if z == nil then
                z = 0
            end

            if name ~= ""
                and IsFiniteNumber(x)
                and IsFiniteNumber(y)
                and IsFiniteNumber(z)
            then
                x = math.clamp(x, -200, 200)
                y = math.clamp(y, -200, 200)
                z = math.clamp(z, -200, 200)

                if not names[name] then
                    local placeId = 0
                    local gameName = "Unknown"

                    if IsFiniteNumber(profile.placeId) then
                        placeId = profile.placeId
                    end

                    if type(profile.gameName) == "string" then
                        gameName = profile.gameName
                    end

                    local cleaned = {
                        name = name,
                        x = x,
                        y = y,
                        z = z,
                        placeId = placeId,
                        gameName = gameName
                    }

                    table.insert(loadedProfiles, cleaned)
                    names[name] = true
                end
            end
        end
    end

    ESPProfiles = loadedProfiles
end

local function FindProfileByName(name)
    for _, profile in ipairs(ESPProfiles) do
        if profile.name == name then
            return profile
        end
    end

    return nil
end

local function ApplyESPProfile(profile)
    if type(profile) ~= "table" then
        return
    end

    local x = profile.x
    local y = profile.y
    local z = profile.z

    -- Legacy profiles implicitly use Z = 0.
    if z == nil then
        z = 0
    end

    if
        not IsFiniteNumber(x)
        or not IsFiniteNumber(y)
        or not IsFiniteNumber(z)
    then
        SetSettingsStatus("Profile apply failed: invalid offset data")
        return
    end

    x = math.clamp(x, -200, 200)
    y = math.clamp(y, -200, 200)
    z = math.clamp(z, -200, 200)

    Config.ESPOffsetX = x
    Config.ESPOffsetY = y
    Config.ESPOffsetZ = z

    if UIRefs.Sliders.ESPOffsetX then
        UIRefs.Sliders.ESPOffsetX.Set(x, true)
    end

    if UIRefs.Sliders.ESPOffsetY then
        UIRefs.Sliders.ESPOffsetY.Set(y, true)
    end

    if UIRefs.Sliders.ESPOffsetZ then
        UIRefs.Sliders.ESPOffsetZ.Set(z, true)
    end

    SetSettingsStatus("Profile applied: " .. tostring(profile.name))
end

local function CreateProfileApplyButton(parent, profile)
    local button = Instance.new("TextButton")
    button.Name = "Apply"
    button.Size = UDim2.new(0, 68, 0, 24)
    button.Position = UDim2.new(1, -74, 0, 9)
    button.Text = "APPLY"
    button.TextColor3 = Config.TextColor
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 10
    button.BackgroundColor3 = Config.DarkBg
    button.AutoButtonColor = false
    button.ZIndex = 5
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.BorderColor
    stroke.Thickness = 1
    stroke.Parent = button

    AddProfileConnection(
        button.MouseButton1Click:Connect(function()
            ApplyESPProfile(profile)
        end)
    )

    return button
end

local function RefreshProfileList()
    if not ProfileList then
        return
    end

    DisconnectProfileConnections()

    for _, child in ipairs(ProfileList:GetChildren()) do
        if not child:IsA("UIListLayout")
            and not child:IsA("UIPadding")
        then
            child:Destroy()
        end
    end

    for index, profile in ipairs(ESPProfiles) do
        local item = Instance.new("Frame")
        item.Name = "Profile_" .. tostring(index)
        item.Size = UDim2.new(1, -4, 0, 58)
        item.BackgroundColor3 = Config.DarkBg
        item.BorderSizePixel = 0
        item.Parent = ProfileList

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = item

        local stroke = Instance.new("UIStroke")
        stroke.Color = Config.BorderColor
        stroke.Thickness = 1
        stroke.Parent = item

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -86, 0, 19)
        nameLabel.Position = UDim2.new(0, 8, 0, 5)
        nameLabel.Text = tostring(profile.name)
        nameLabel.TextColor3 = Config.TextColor
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.ZIndex = 4
        nameLabel.Parent = item

        local offsetLabel = Instance.new("TextLabel")
        offsetLabel.Size = UDim2.new(1, -86, 0, 16)
        offsetLabel.Position = UDim2.new(0, 8, 0, 25)
        offsetLabel.Text =
            "X: "
            .. tostring(profile.x)
            .. "    Y: "
            .. tostring(profile.y)
            .. "    Z: "
            .. tostring(profile.z or 0)
        offsetLabel.TextColor3 = Config.SubTextColor
        offsetLabel.Font = Enum.Font.Gotham
        offsetLabel.TextSize = 10
        offsetLabel.TextXAlignment = Enum.TextXAlignment.Left
        offsetLabel.BackgroundTransparency = 1
        offsetLabel.ZIndex = 4
        offsetLabel.Parent = item

        local metadataLabel = Instance.new("TextLabel")
        metadataLabel.Size = UDim2.new(1, -86, 0, 13)
        metadataLabel.Position = UDim2.new(0, 8, 0, 41)
        metadataLabel.Text =
            tostring(profile.gameName or "Unknown")
            .. " | PlaceId: "
            .. tostring(profile.placeId or 0)
        metadataLabel.TextColor3 = Config.SubTextColor
        metadataLabel.Font = Enum.Font.Gotham
        metadataLabel.TextSize = 9
        metadataLabel.TextXAlignment = Enum.TextXAlignment.Left
        metadataLabel.BackgroundTransparency = 1
        metadataLabel.TextTruncate = Enum.TextTruncate.AtEnd
        metadataLabel.ZIndex = 4
        metadataLabel.Parent = item

        CreateProfileApplyButton(item, profile)
    end

    ProfileList.CanvasSize =
        UDim2.new(
            0,
            0,
            0,
            #ESPProfiles * 64 + 4
        )
end

local function DisconnectProfilePopupConnections()
    for _, conn in ipairs(ProfilePopupConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    table.clear(ProfilePopupConnections)
end

local function DestroyProfilePopup(popup)
    DisconnectProfilePopupConnections()

    if not popup then
        popup = MainWindow:FindFirstChild("ESPProfileConfirmPopup")
    end

    if popup and popup.Parent then
        popup:Destroy()
    end
end

local function OpenProfileConfirmPopup(rawName)
    local profileName = TrimString(rawName)

    if profileName == "" then
        SetSettingsStatus("Enter a profile name first")
        return
    end

    DestroyProfilePopup(nil)

    local popup = Instance.new("Frame")
    popup.Name = "ESPProfileConfirmPopup"
    popup.Size = UDim2.new(0, 300, 0, 188)
    popup.AnchorPoint = Vector2.new(0.5, 0.5)
    popup.Position = UDim2.new(0.5, 0, 0.5, 0)
    popup.BackgroundColor3 = Config.CardBg
    popup.BorderSizePixel = 0
    popup.ZIndex = 200
    popup.Parent = MainWindow

    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 8)
    pCorner.Parent = popup

    local pStroke = Instance.new("UIStroke")
    pStroke.Color = Config.BorderColor
    pStroke.Thickness = 1
    pStroke.Parent = popup

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.Text = "CONFIRM PROFILE"
    title.TextColor3 = Config.TextColor
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.ZIndex = 201
    title.Parent = popup

    local profileLabel = Instance.new("TextLabel")
    profileLabel.Size = UDim2.new(1, -20, 0, 20)
    profileLabel.Position = UDim2.new(0, 10, 0, 38)
    profileLabel.Text = "Profile Name: " .. profileName
    profileLabel.TextColor3 = Config.SubTextColor
    profileLabel.Font = Enum.Font.Gotham
    profileLabel.TextSize = 11
    profileLabel.TextXAlignment = Enum.TextXAlignment.Left
    profileLabel.BackgroundTransparency = 1
    profileLabel.ZIndex = 201
    profileLabel.TextTruncate = Enum.TextTruncate.AtEnd
    profileLabel.Parent = popup

    local offsetLabel = Instance.new("TextLabel")
    offsetLabel.Size = UDim2.new(1, -20, 0, 38)
    offsetLabel.Position = UDim2.new(0, 10, 0, 64)
    offsetLabel.Text =
        "Save current ESP offset:\n"
        .. "X: "
        .. tostring(Config.ESPOffsetX)
        .. "    Y: "
        .. tostring(Config.ESPOffsetY)
        .. "    Z: "
        .. tostring(Config.ESPOffsetZ)
    offsetLabel.TextColor3 = Config.TextColor
    offsetLabel.Font = Enum.Font.GothamMedium
    offsetLabel.TextSize = 11
    offsetLabel.TextXAlignment = Enum.TextXAlignment.Left
    offsetLabel.BackgroundTransparency = 1
    offsetLabel.ZIndex = 201
    offsetLabel.Parent = popup

    local okButton = Instance.new("TextButton")
    okButton.Size = UDim2.new(0, 120, 0, 30)
    okButton.Position = UDim2.new(0, 18, 1, -42)
    okButton.Text = "OK"
    okButton.TextColor3 = Config.TextColor
    okButton.Font = Enum.Font.GothamMedium
    okButton.TextSize = 12
    okButton.BackgroundColor3 = Config.DarkBg
    okButton.AutoButtonColor = false
    okButton.ZIndex = 202
    okButton.Parent = popup

    local okCorner = Instance.new("UICorner")
    okCorner.CornerRadius = UDim.new(0, 5)
    okCorner.Parent = okButton

    local cancelButton = Instance.new("TextButton")
    cancelButton.Size = UDim2.new(0, 120, 0, 30)
    cancelButton.Position = UDim2.new(1, -138, 1, -42)
    cancelButton.Text = "CANCEL"
    cancelButton.TextColor3 = Config.TextColor
    cancelButton.Font = Enum.Font.GothamMedium
    cancelButton.TextSize = 12
    cancelButton.BackgroundColor3 = Config.DarkBg
    cancelButton.AutoButtonColor = false
    cancelButton.ZIndex = 202
    cancelButton.Parent = popup

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 5)
    cancelCorner.Parent = cancelButton

    table.insert(
        ProfilePopupConnections,
        okButton.MouseButton1Click:Connect(function()
            local existingProfile = FindProfileByName(profileName)

            if existingProfile then
                existingProfile.x = math.clamp(
                    tonumber(Config.ESPOffsetX) or 0,
                    -200,
                    200
                )
                existingProfile.y = math.clamp(
                    tonumber(Config.ESPOffsetY) or 0,
                    -200,
                    200
                )
                existingProfile.z = math.clamp(
                    tonumber(Config.ESPOffsetZ) or 0,
                    -200,
                    200
                )
                existingProfile.placeId = CurrentPlaceId
                existingProfile.gameName = CurrentGameName

                local persisted = SaveESPProfiles()
                RefreshProfileList()

                if persisted then
                    SetSettingsStatus("Profile updated: " .. profileName)
                end
            else
                local newProfile = {
                    name = profileName,
                    x = math.clamp(
                        tonumber(Config.ESPOffsetX) or 0,
                        -200,
                        200
                    ),
                    y = math.clamp(
                        tonumber(Config.ESPOffsetY) or 0,
                        -200,
                        200
                    ),
                    z = math.clamp(
                        tonumber(Config.ESPOffsetZ) or 0,
                        -200,
                        200
                    ),
                    placeId = CurrentPlaceId,
                    gameName = CurrentGameName
                }

                table.insert(ESPProfiles, newProfile)
                local persisted = SaveESPProfiles()
                RefreshProfileList()

                if persisted then
                    SetSettingsStatus("Profile added: " .. profileName)
                end
            end

            ProfileNameInput.Text = ""
            DestroyProfilePopup(popup)
        end)
    )

    table.insert(
        ProfilePopupConnections,
        cancelButton.MouseButton1Click:Connect(function()
            DestroyProfilePopup(popup)
        end)
    )
end

local ConfigSaveLoadSec =
    UI:CreateSection(
        SettingsPage,
        "CONFIG SAVE / LOAD"
    )

UI:CreateButton(
    ConfigSaveLoadSec,
    "SAVE SETTINGS",
    function()
        SaveSettings()
    end
)

UI:CreateButton(
    ConfigSaveLoadSec,
    "LOAD SETTINGS",
    function()
        LoadSettings()
    end
)

SettingsStatusLabel =
    UI:CreateLabel(
        ConfigSaveLoadSec,
        "Ready"
    )

local ESPOffsetSec =
    UI:CreateSection(
        SettingsPage,
        "ESP OFFSET"
    )

UIRefs.Sliders.ESPOffsetX =
    UI:CreateSlider(
        ESPOffsetSec,
        {
            Text = "ESP X",
            Min = -200,
            Max = 200,
            Default = Config.ESPOffsetX,
            Increment = 1,
            EditableValue = true,
            AllowTextInputBeyondRange = false,
            Callback = function(value)
                if IsFiniteNumber(value) then
                    Config.ESPOffsetX =
                        math.clamp(value, -200, 200)
                end
            end
        }
    )

UIRefs.Sliders.ESPOffsetY =
    UI:CreateSlider(
        ESPOffsetSec,
        {
            Text = "ESP Y",
            Min = -200,
            Max = 200,
            Default = Config.ESPOffsetY,
            Increment = 1,
            EditableValue = true,
            AllowTextInputBeyondRange = false,
            Callback = function(value)
                if IsFiniteNumber(value) then
                    Config.ESPOffsetY =
                        math.clamp(value, -200, 200)
                end
            end
        }
    )

UIRefs.Sliders.ESPOffsetZ =
    UI:CreateSlider(
        ESPOffsetSec,
        {
            Text = "ESP Z",
            Min = -200,
            Max = 200,
            Default = Config.ESPOffsetZ,
            Increment = 1,
            EditableValue = true,
            AllowTextInputBeyondRange = false,
            Callback = function(value)
                if IsFiniteNumber(value) then
                    Config.ESPOffsetZ =
                        math.clamp(value, -200, 200)
                end
            end
        }
    )

local ESPProfileSec =
    UI:CreateSection(
        SettingsPage,
        "ESP OFFSET PROFILES"
    )

local CurrentGameLabel =
    UI:CreateLabel(
        ESPProfileSec,
        "Current Game: "
            .. tostring(CurrentGameName)
            .. "\nPlaceId: "
            .. tostring(CurrentPlaceId)
    )

ProfileNameInput =
    UI:CreateTextbox(
        ESPProfileSec,
        {
            Text = "Profile Name",
            Placeholder = "Nhập tên game/profile...",
            Default = "",
            Callback = function()
                -- Confirmation is handled by the + button below.
            end
        }
    )

UI:CreateButton(
    ESPProfileSec,
    "[ + ]",
    function()
        OpenProfileConfirmPopup(ProfileNameInput.Text)
    end
)

ProfileList =
    Instance.new("ScrollingFrame")

ProfileList.Name = "ESPProfileList"
ProfileList.Size = UDim2.new(1, 0, 0, 190)
ProfileList.BackgroundTransparency = 1
ProfileList.BorderSizePixel = 0
ProfileList.ScrollBarThickness = 3
ProfileList.ScrollBarImageColor3 = Config.SubTextColor
ProfileList.Parent = ESPProfileSec

local ProfileListLayout =
    Instance.new("UIListLayout")

ProfileListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ProfileListLayout.Padding = UDim.new(0, 6)
ProfileListLayout.Parent = ProfileList

local ProfileListPadding =
    Instance.new("UIPadding")

ProfileListPadding.PaddingTop = UDim.new(0, 2)
ProfileListPadding.PaddingBottom = UDim.new(0, 2)
ProfileListPadding.Parent = ProfileList

LoadESPProfiles()
RefreshProfileList()

if not FileAPI.Available then
    SetSettingsStatus(
        "Filesystem persistence unavailable; session-only save"
    )
end

-- =========================================================
-- TAB: KHÁC
-- Exactly the seven requested features only.
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
NPCSystem.Initialize()

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

        if Telekill.CurrentTarget == target then
            Telekill.CurrentTarget = nil
        end

        RefreshTeleportPlayerList()
    end)
)


-- Mở mặc định Tab ESP
PageManager:ShowPage(Config.StartPage)

-- ==========================================
-- 10. EVENT CONTROLS & MINIMIZE / CLOSE
-- ==========================================

SetMenuState = function(newState)
    GUIState.CurrentState = newState

    if newState == "Open" then
        ScreenGui.Enabled = true
        MainWindow.Visible = true
        FloatingBtn.Visible = false
        OtherSystem.SetMenuMouseState(true)
    elseif newState == "Minimized" then
        MainWindow.Visible = false
        FloatingBtn.Visible = true
        OtherSystem.SetMenuMouseState(false)
    elseif newState == "Closed" then
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
    if OtherSystem.ConsumeNextToggleInput then
        OtherSystem.ConsumeNextToggleInput = false
        return
    end

    if OtherSystem.KeybindListening then
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
                    OtherSystem.UpdateMenuInput()
                end
            )

            RunService:BindToRenderStep(
                "HoodRivalsAimRender",
                Enum.RenderPriority.Last.Value - 1,
                function()
                    Telekill.Update()
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

    DisconnectProfileConnections()
    DisconnectProfilePopupConnections()

    pcall(function()
        local popup = MainWindow:FindFirstChild("ESPProfileConfirmPopup")
        if popup then
            popup:Destroy()
        end
    end)

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
        ApplyESPProfile = ApplyESPProfile,
        GetProfiles = function()
            return ESPProfiles
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

    Cleanup = CleanupFramework
}

print("[Hood Rivals Framework & ESP Integrated Successfully!]")
