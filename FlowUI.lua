--[[
    ═══════════════════════════════════════════════════════════════════════════
    BulletTrain UI Library  v1.0
    A reusable dark-themed Roblox GUI library with a glowing window border,
    sidebar navigation, tabbed pages, and animated notifications.
    ═══════════════════════════════════════════════════════════════════════════

    USAGE:
        local UI = loadstring(game:HttpGet("..."))()

        local Window = UI.new({
            Title          = "My Hub",
            Subtitle       = "v1.0",
            Logo           = "rbxassetid://114345069590059",  -- optional
            Width          = 520,
            Height         = 380,
            ShowPlayerCard = true,
            LoadingAnimation = true,
            LoadTime       = 1.4,
        })

        local Tab = Window:Tab("Main")
        Tab:Section("General")
        Tab:Toggle("Feature", "description", false, function(state) print(state) end)
        Tab:Slider("Speed", 16, 250, 100, function(v) print(v) end)
        Tab:Button("Click me", function() print("clicked") end)
        Tab:Paragraph("Some long paragraph.")
        Tab:Divider()

        UI.Notify({ Title = "Hi", Content = "Loaded!", Type = "success", Duration = 3 })
        -- or short form:
        UI.Notify("Hello world!")

        -- Cleanup
        Window:Destroy()
        -- or unload everything:
        UI.Unload()

    LICENSING: MIT — do whatever.
]]

local UI = {}
UI.Version = "1.0.0"

-- ─── Services ───────────────────────────────────────────────────────────────
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local LP               = Players.LocalPlayer

-- ─── Re-execution guard ─────────────────────────────────────────────────────
do
    local prev = _G.BulletTrainUI
    if prev and type(prev.Unload) == "function" then
        pcall(prev.Unload)
    end
end
_G.BulletTrainUI = UI

-- ─── Theme ──────────────────────────────────────────────────────────────────
UI.Theme = {
    WindowBg     = Color3.fromRGB(20, 20, 20),
    CardBg       = Color3.fromRGB(24, 24, 24),
    Border       = Color3.fromRGB(35, 35, 35),
    Element      = Color3.fromRGB(31, 31, 31),
    ElementHover = Color3.fromRGB(38, 38, 38),
    PillActive   = Color3.fromRGB(36, 36, 36),
    White        = Color3.fromRGB(255, 255, 255),
    TextGray     = Color3.fromRGB(154, 154, 154),
    TextDim      = Color3.fromRGB(139, 139, 139),
    Accent       = Color3.fromRGB(167, 200, 244),
    AccentText   = Color3.fromRGB(10, 16, 26),
    Green        = Color3.fromRGB(105, 166, 124),
    Red          = Color3.fromRGB(190, 99, 99),
    Orange       = Color3.fromRGB(190, 154, 84),
}
local C = UI.Theme

UI.DefaultLogo = "rbxassetid://114345069590059"

-- ─── Internal state ─────────────────────────────────────────────────────────
UI._connections = {}
UI._windows     = {}
UI._notifGui    = nil
UI._notifHolder = nil
UI._notifOrder  = 0
UI._dead        = false

local TWEEN        = TweenInfo.new(0.15, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local NOTIFY_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local NOTIFICATION_STYLES = {
    info    = { Name = "Info",    Color = Color3.fromRGB(118, 151, 194) },
    success = { Name = "Success", Color = Color3.fromRGB(105, 166, 124) },
    warning = { Name = "Warning", Color = Color3.fromRGB(190, 154, 84)  },
    error   = { Name = "Error",   Color = Color3.fromRGB(190, 99, 99)   },
}

-- ─── Forward declarations ───────────────────────────────────────────────────
local Window, Tab

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITIES  (exposed as UI.Utils for advanced usage)
-- ═══════════════════════════════════════════════════════════════════════════
local Utils = {}
UI.Utils = Utils

function Utils.track(conn)
    table.insert(UI._connections, conn)
    return conn
end
local track = Utils.track

function Utils.tween(inst, props)
    TweenService:Create(inst, TWEEN, props):Play()
end
local tween = Utils.tween

function Utils.make(className, props)
    local inst = Instance.new(className)
    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
        inst.BackgroundColor3 = C.WindowBg
    end
    if inst:IsA("GuiButton") then
        inst.AutoButtonColor = false
    end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inst.Font = Enum.Font.Gotham
        inst.TextColor3 = C.White
        inst.TextSize = 13
    end
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    inst.Parent = props.Parent
    return inst
end
local make = Utils.make

function Utils.corner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end
local corner = Utils.corner

function Utils.circle(parent)
    return make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end
local circle = Utils.circle

function Utils.stroke(parent, color)
    return make("UIStroke", {
        Color = color or C.Border,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end
local stroke = Utils.stroke

function Utils.pad(parent, t, b, l, r)
    return make("UIPadding", {
        PaddingTop    = UDim.new(0, t),
        PaddingBottom = UDim.new(0, b),
        PaddingLeft   = UDim.new(0, l),
        PaddingRight  = UDim.new(0, r),
        Parent        = parent,
    })
end
local pad = Utils.pad

function Utils.isInside(gui, pos)
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end
local isInside = Utils.isInside

function Utils.guiVisible(gui)
    local node = gui
    while node and node:IsA("GuiObject") do
        if not node.Visible then return false end
        node = node.Parent
    end
    return true
end
local guiVisible = Utils.guiVisible

function Utils.copyToClipboard(text)
    local clip = setclipboard or toclipboard or writeclipboard
    if not clip then return false end
    return pcall(clip, text)
end
local copyToClipboard = Utils.copyToClipboard

function Utils.getParent()
    local target
    pcall(function() target = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not target then target = LP:WaitForChild("PlayerGui") end
    return target
end
local getParent = Utils.getParent

function Utils.makeDraggable(frame, blockers)
    local dragging, dragStart, startPos = false, nil, nil
    track(frame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        for _, gui in ipairs(blockers) do
            if guiVisible(gui) and isInside(gui, pos) then return end
        end
        dragging  = true
        dragStart = input.Position
        startPos  = frame.Position
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end
local makeDraggable = Utils.makeDraggable

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
local function ensureNotifGui()
    if UI._notifGui and UI._notifGui.Parent then return end
    UI._notifGui = make("ScreenGui", {
        Name = "BulletTrainNotifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 20,
        Parent = getParent(),
    })
    UI._notifHolder = make("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.fromOffset(260, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 200,
        Parent = UI._notifGui,
    })
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = UI._notifHolder,
    })
end

function UI.Notify(opts)
    ensureNotifGui()
    if type(opts) == "string" then opts = { Content = opts } end
    opts = opts or {}
    local styleKey = string.lower(tostring(opts.Type or "info"))
    local style    = NOTIFICATION_STYLES[styleKey] or NOTIFICATION_STYLES.info
    local dur      = math.max(tonumber(opts.Duration) or 2.5, 0)
    UI._notifOrder = UI._notifOrder + 1

    local title = tostring(opts.Title or style.Name)
    local body  = tostring(opts.Content or opts.Message or "Notification")

    local slot = make("Frame", {
        Name = "NotificationSlot",
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
        LayoutOrder = UI._notifOrder,
        ZIndex = 200,
        Parent = UI._notifHolder,
    })
    local nCard = make("CanvasGroup", {
        Name = "NCard",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 12, 0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.CardBg,
        GroupTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 201,
        Parent = slot,
    })
    corner(nCard, 6); stroke(nCard, C.Border)

    make("TextLabel", {
        Text = title, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 9), Size = UDim2.new(1, -42, 0, 16),
        ZIndex = 202, Parent = nCard,
    })
    make("TextLabel", {
        Text = body, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 29),
        Size = UDim2.new(1, -24, 0, 24), ZIndex = 202, Parent = nCard,
    })
    local xb = make("TextButton", {
        Text = "×", Font = Enum.Font.Gotham, TextSize = 14,
        TextColor3 = C.TextDim, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -7, 0, 5), Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1, ZIndex = 204, Parent = nCard,
    })

    local closed = false
    local function closeNotif()
        if closed then return end
        closed = true
        TweenService:Create(nCard, NOTIFY_TWEEN, {
            Position = UDim2.new(1, 12, 0, 0), GroupTransparency = 1,
        }):Play()
        task.delay(0.2, function()
            if slot and slot.Parent then slot:Destroy() end
        end)
    end

    xb.MouseEnter:Connect(function() tween(xb, { TextColor3 = C.White }) end)
    xb.MouseLeave:Connect(function() tween(xb, { TextColor3 = C.TextDim }) end)
    xb.MouseButton1Click:Connect(closeNotif)

    TweenService:Create(nCard, NOTIFY_TWEEN, {
        Position = UDim2.new(1, 0, 0, 0), GroupTransparency = 0,
    }):Play()
    if dur > 0 then task.delay(dur, closeNotif) end
    return closeNotif
end

-- ═══════════════════════════════════════════════════════════════════════════
-- WINDOW CLASS
-- ═══════════════════════════════════════════════════════════════════════════
Window = {}
Window.__index = Window

function UI.new(opts)
    opts = opts or {}
    local W        = tonumber(opts.Width)  or 520
    local H        = tonumber(opts.Height) or 380
    local logo     = opts.Logo     or UI.DefaultLogo
    local title    = opts.Title    or "UI"
    local subtitle = opts.Subtitle or ""

    local self = setmetatable({
        Width = W, Height = H,
        Logo = logo, Title = title, Subtitle = subtitle,
        Tabs = {}, TabButtons = {}, TabPages = {},
        NoDrag = {},
        _conns = {},
    }, Window)

    -- ScreenGui
    local screenGui = make("ScreenGui", {
        Name = opts.Name or "BulletTrainUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = opts.DisplayOrder or 10,
        Parent = getParent(),
    })
    self.ScreenGui = screenGui

    -- Container (draggable)
    local container = make("Frame", {
        Name = "BTSContainer",
        Size = UDim2.fromOffset(W, H),
        Position = opts.Position or UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = screenGui,
    })
    self.Container = container

    -- Loading animation
    local loadingLayer
    if opts.LoadingAnimation ~= false then
        loadingLayer = make("CanvasGroup", {
            Name = "StartupLoader",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 1,
            GroupTransparency = 0,
            ZIndex = 500,
            Parent = screenGui,
        })
        local lc = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(320, 120),
            BackgroundTransparency = 1, ZIndex = 508,
            Parent = loadingLayer,
        })
        local lLogo = make("ImageLabel", {
            Image = logo, BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.fromOffset(48, 48), ScaleType = Enum.ScaleType.Fit,
            ImageTransparency = 1, ZIndex = 509, Parent = lc,
        })
        local lTitle = make("TextLabel", {
            Text = string.upper(title), Font = Enum.Font.GothamBlack, TextSize = 26,
            TextColor3 = C.White, BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54),
            Size = UDim2.fromOffset(240, 30), TextTransparency = 1,
            ZIndex = 509, Parent = lc,
        })
        local lSub = make("TextLabel", {
            Text = subtitle, Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = C.Accent, BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88),
            Size = UDim2.fromOffset(240, 16), TextTransparency = 1,
            ZIndex = 509, Parent = lc,
        })
        self._loadingRefs = { layer = loadingLayer, logo = lLogo, title = lTitle, sub = lSub }
    end

    -- Main window
    local main = make("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = C.WindowBg,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 2,
        Parent = container,
    })
    corner(main, 12); stroke(main, C.Border)
    self.Frame = main

    -- Glow border
    local glowStroke = make("UIStroke", {
        Color = C.Accent, Thickness = 1.6,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Transparency = 0, Parent = main,
    })
    local glowGrad = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, C.Accent),
            ColorSequenceKeypoint.new(0.42, C.Accent),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.58, C.Accent),
            ColorSequenceKeypoint.new(1.00, C.Accent),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1.0),
            NumberSequenceKeypoint.new(0.36, 1.0),
            NumberSequenceKeypoint.new(0.50, 0.0),
            NumberSequenceKeypoint.new(0.64, 1.0),
            NumberSequenceKeypoint.new(1.00, 1.0),
        }),
        Parent = glowStroke,
    })
    local glowT = 0
    table.insert(self._conns, RunService.RenderStepped:Connect(function(dt)
        if not main.Parent then return end
        glowT = (glowT + dt * 0.35) % 1
        glowGrad.Offset = Vector2.new(glowT * 2 - 1, 0)
    end))

    -- Close button
    local controls = make("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 8),
        Size = UDim2.fromOffset(36, 16), BackgroundTransparency = 1,
        ZIndex = 10, Parent = main,
    })
    local closeBtn = make("TextButton", {
        Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(190, 60, 60),
        ZIndex = 12, Parent = controls,
    })
    circle(closeBtn); table.insert(self.NoDrag, closeBtn)
    closeBtn.MouseButton1Click:Connect(function() self:Destroy() end)

    -- Sidebar
    local sidebar = make("Frame", {
        Size = UDim2.new(0, 160, 1, 0),
        BackgroundTransparency = 1, Parent = main,
    })
    self.Sidebar = sidebar

    -- Brand card
    local brand = make("Frame", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -24, 0, 50),
        BackgroundColor3 = C.CardBg, Parent = sidebar,
    })
    corner(brand, 10); stroke(brand, C.Border)
    make("ImageLabel", {
        Image = logo, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(34, 34),
        ScaleType = Enum.ScaleType.Fit, Parent = brand,
    })
    make("TextLabel", {
        Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 7),
        Size = UDim2.new(1, -56, 0, 16), Parent = brand,
    })
    make("TextLabel", {
        Text = subtitle, Font = Enum.Font.GothamMedium, TextSize = 9,
        TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 25),
        Size = UDim2.new(1, -56, 0, 14), Parent = brand,
    })

    -- Player card
    local showPlayerCard = opts.ShowPlayerCard ~= false
    if showPlayerCard then
        local pcard = make("Frame", {
            Position = UDim2.fromOffset(12, 72),
            Size = UDim2.new(1, -24, 0, 48),
            BackgroundColor3 = C.CardBg, Parent = sidebar,
        })
        corner(pcard, 10); stroke(pcard, C.Border)
        local avH = make("Frame", {
            Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(34, 34),
            BackgroundColor3 = C.Element, Parent = pcard,
        })
        corner(avH, 8)
        make("ImageLabel", {
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150",
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Crop, Parent = avH,
        })
        make("TextLabel", {
            Text = LP.DisplayName, Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(47, 8),
            Size = UDim2.new(1, -54, 0, 14), Parent = pcard,
        })
        make("TextLabel", {
            Text = "@" .. LP.Name, Font = Enum.Font.Gotham, TextSize = 9,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(47, 24),
            Size = UDim2.new(1, -54, 0, 12), Parent = pcard,
        })
        self._playerCard = pcard
    end

    -- Watermark
    make("ImageLabel", {
        Image = logo, BackgroundTransparency = 1, ImageTransparency = 0.92,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 24),
        Size = UDim2.fromOffset(118, 118), ScaleType = Enum.ScaleType.Fit,
        ZIndex = 0, Parent = sidebar,
    })

    -- Status dot
    local statusDot = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 1, -19),
        Size = UDim2.fromOffset(6, 6), BackgroundColor3 = C.Green, Parent = sidebar,
    }); circle(statusDot)
    self.StatusDot = statusDot
    self._statusLabel = make("TextLabel", {
        Text = opts.StatusText or "Loaded", Font = Enum.Font.GothamMedium,
        TextSize = 10, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Position = UDim2.new(0, 28, 1, -27),
        Size = UDim2.new(1, -40, 0, 16), Parent = sidebar,
    })

    -- Vertical divider
    local divLine = make("Frame", {
        Position = UDim2.fromOffset(160, 0), Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = C.Accent, Parent = main,
    })
    make("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.5),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = divLine,
    })

    -- Content area
    local content = make("Frame", {
        Position = UDim2.fromOffset(160, 0),
        Size = UDim2.new(1, -160, 1, 0),
        BackgroundTransparency = 1, Parent = main,
    })
    self.Content = content

    -- Tab list
    local tabY = showPlayerCard and 130 or 72
    local tabHolder = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, tabY),
        Size = UDim2.new(1, 0, 1, -(tabY + 6)),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.Border,
        Parent = sidebar,
    })
    self._tabHolder = tabHolder

    -- Enable dragging
    makeDraggable(container, self.NoDrag)

    table.insert(UI._windows, self)

    -- Play loading
    if loadingLayer then
        self:_playLoading(opts.LoadTime or 1.4, opts.OnLoaded)
    else
        main.Visible = true
        if opts.OnLoaded then task.spawn(opts.OnLoaded) end
    end

    return self
end

function Window:_playLoading(loadTime, onLoaded)
    local refs = self._loadingRefs
    if not refs then
        if onLoaded then task.spawn(onLoaded) end
        return
    end
    task.spawn(function()
        TweenService:Create(refs.layer, TweenInfo.new(0.34, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.35 }):Play()
        TweenService:Create(refs.logo,  TweenInfo.new(0.30, Enum.EasingStyle.Quad), { ImageTransparency = 0 }):Play()
        task.wait(0.2)
        TweenService:Create(refs.title, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
        task.wait(0.15)
        TweenService:Create(refs.sub,   TweenInfo.new(0.25, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
        task.wait(loadTime)
        TweenService:Create(refs.layer, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
        task.wait(0.35)
        self.Frame.Visible = true
        if refs.layer and refs.layer.Parent then refs.layer:Destroy() end
        self._loadingRefs = nil
        if onLoaded then pcall(onLoaded) end
    end)
end

function Window:SetVisible(v)
    if self.Frame then self.Frame.Visible = v and true or false end
end

function Window:NoDrag(gui)
    table.insert(self.NoDrag, gui)
end

function Window:SetStatus(text, color)
    if self._statusLabel then self._statusLabel.Text = text end
    if self.StatusDot and color then self.StatusDot.BackgroundColor3 = color end
end

function Window:SelectTab(idx)
    for j, b in ipairs(self.TabButtons) do
        if j == idx then
            tween(b, { BackgroundColor3 = C.PillActive, TextColor3 = C.White })
        else
            tween(b, { BackgroundColor3 = C.CardBg, TextColor3 = C.TextGray })
        end
    end
    for j, pg in ipairs(self.TabPages) do pg.Visible = (j == idx) end
end

function Window:Destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    table.clear(self._conns)
    if self.ScreenGui and self.ScreenGui.Parent then self.ScreenGui:Destroy() end
    for i, w in ipairs(UI._windows) do
        if w == self then table.remove(UI._windows, i); break end
    end
end

function Window:Tab(name)
    -- Create page
    local page = make("Frame", {
        Name = name .. "Page", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Visible = false, Parent = self.Content,
    })
    local hdr = make("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1, Parent = page,
    })
    make("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Border, Parent = hdr,
    })
    make("TextLabel", {
        Text = name, Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -32, 1, 0), Parent = hdr,
    })
    local scroll = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 1, -36),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.Border,
        Parent = page,
    })
    pad(scroll, 12, 16, 16, 16)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8), Parent = scroll,
    })

    -- Create tab button
    local idx = #self.TabPages + 1
    local btn = make("TextButton", {
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = (idx == 1) and C.White or C.TextGray,
        BackgroundColor3 = (idx == 1) and C.PillActive or C.CardBg,
        Size = UDim2.new(1, -12, 0, 30),
        Position = UDim2.fromOffset(12, (idx - 1) * 33),
        Parent = self._tabHolder,
    })
    corner(btn, 7)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    pad(btn, 0, 0, 12, 0)
    table.insert(self.NoDrag, btn)
    btn.MouseButton1Click:Connect(function() self:SelectTab(idx) end)

    self.TabButtons[idx] = btn
    self.TabPages[idx] = page
    if idx == 1 then self:SelectTab(1) end

    local tab = setmetatable({
        _window = self,
        _scroll = scroll,
        _page = page,
        _index = idx,
    }, Tab)
    return tab
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB CLASS + COMPONENTS
-- ═══════════════════════════════════════════════════════════════════════════
Tab = {}
Tab.__index = Tab

--- Add a section header.
function Tab:Section(text)
    local sh = make("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1, Parent = self._scroll,
    })
    local stripe = make("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -4),
        Size = UDim2.fromOffset(3, 11), BackgroundColor3 = C.Accent, Parent = sh,
    })
    corner(stripe, 2)
    make("TextLabel", {
        Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = C.TextGray, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Bottom, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -9, 1, -3),
        Parent = sh,
    })
    return sh
end

--- Add a card with wrapped text.
function Tab:Paragraph(text)
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.CardBg, Parent = self._scroll,
    })
    corner(card, 10); stroke(card); pad(card, 10, 10, 12, 12)
    make("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 10,
        TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Parent = card,
    })
    return card
end

--- Add a simple text label.
function Tab:Label(text)
    return make("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.TextGray, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        Parent = self._scroll,
    })
end

--- Add a horizontal divider.
function Tab:Divider()
    return make("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.Border, Parent = self._scroll,
    })
end

--- Add a button. callback() fires on click.
function Tab:Button(text, callback)
    local btn = make("TextButton", {
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = C.White, BackgroundColor3 = C.Element,
        Size = UDim2.new(1, 0, 0, 30), Parent = self._scroll,
    })
    corner(btn, 6)
    table.insert(self._window.NoDrag, btn)
    btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = C.ElementHover }) end)
    btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = C.Element }) end)
    btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)
    return btn
end

--- Add a toggle switch. callback(state) fires on change.
--- Returns an object with :Set(v) and :Get() methods.
function Tab:Toggle(label, desc, default, callback)
    default = default and true or false
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.CardBg, Parent = self._scroll,
    })
    corner(card, 10); stroke(card); pad(card, 10, 10, 12, 12)
    make("TextLabel", {
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Size = UDim2.new(1, -50, 0, 16), Parent = card,
    })
    if desc then
        make("TextLabel", {
            Text = desc, Font = Enum.Font.Gotham, TextSize = 10,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, -50, 0, 0),
            Parent = card,
        })
    end

    local state = default
    local toggle = make("TextButton", {
        Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 0),
        Size = UDim2.fromOffset(36, 18),
        BackgroundColor3 = state and C.Green or C.Red, Parent = card,
    })
    corner(toggle, 9)
    table.insert(self._window.NoDrag, toggle)

    local knob = make("Frame", {
        AnchorPoint = Vector2.new(state and 1 or 0, 0.5),
        Position = UDim2.new(state and 1 or 0, state and -3 or 3, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = C.White, Parent = toggle,
    })
    circle(knob)

    local function setState(v, silent)
        state = v and true or false
        tween(toggle, { BackgroundColor3 = state and C.Green or C.Red })
        tween(knob, {
            AnchorPoint = Vector2.new(state and 1 or 0, 0.5),
            Position = UDim2.new(state and 1 or 0, state and -3 or 3, 0.5, 0),
        })
        if not silent and callback then pcall(callback, state) end
    end

    toggle.MouseButton1Click:Connect(function() setState(not state) end)

    return {
        Set = function(_, v) setState(v) end,
        Get = function() return state end,
        _instance = toggle,
    }
end

--- Add a slider. callback(value) fires on change.
--- Returns an object with :Set(v) and :Get() methods.
function Tab:Slider(label, min, max, default, callback)
    min     = min or 0
    max     = max or 100
    default = default or min
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = C.CardBg, Parent = self._scroll,
    })
    corner(card, 10); stroke(card); pad(card, 10, 6, 12, 12)

    local valLabel = make("TextLabel", {
        Text = label .. ": " .. tostring(default),
        Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Parent = card,
    })
    local current = default
    local bar = make("Frame", {
        Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = C.Element, Parent = card,
    })
    corner(bar, 3)
    local fill = make("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = C.Accent, Parent = bar,
    })
    corner(fill, 3)
    table.insert(self._window.NoDrag, bar)

    local dragging = false
    local function updateFromPos(x)
        local pos = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        current = math.floor(min + (max - min) * pos)
        current = math.clamp(current, min, max)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        valLabel.Text = label .. ": " .. tostring(current)
        if callback then pcall(callback, current) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromPos(input.Position.X)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromPos(input.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    return {
        Set = function(_, v)
            v = math.clamp(v, min, max)
            current = v
            local p = (v - min) / (max - min)
            fill.Size = UDim2.new(p, 0, 1, 0)
            valLabel.Text = label .. ": " .. tostring(v)
            if callback then pcall(callback, v) end
        end,
        Get = function() return current end,
        _instance = bar,
    }
end

--- Escape hatch: build a custom card with your own content inside.
function Tab:Card(height)
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, height or 60),
        BackgroundColor3 = C.CardBg, Parent = self._scroll,
    })
    corner(card, 10); stroke(card); pad(card, 10, 10, 12, 12)
    return card
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GLOBAL UNLOAD
-- ═══════════════════════════════════════════════════════════════════════════
function UI.Unload()
    if UI._dead then return end
    UI._dead = true
    for _, c in ipairs(UI._connections) do pcall(function() c:Disconnect() end) end
    table.clear(UI._connections)
    for _, w in ipairs(UI._windows) do pcall(function() w:Destroy() end) end
    table.clear(UI._windows)
    if UI._notifGui and UI._notifGui.Parent then UI._notifGui:Destroy() end
    _G.BulletTrainUI = nil
end

return UI