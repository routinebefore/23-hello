--// obsidian_skin.lua
--// Visual-only skin for the Obsidian-style UI library.
--// Usage (after creating the window):
--//   local Skin = loadstring(readfile("obsidian_skin.lua"))()   -- or paste this file inline
--//   Skin(Library, { Preset = "Violet" })
--// For best results create the window with:
--//   Library:CreateWindow({ Title = "...", CornerRadius = 8, Font = Enum.Font.GothamMedium })

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Presets = {
    Violet = {
        Accent = Color3.fromRGB(139, 92, 246),
        Background = Color3.fromRGB(11, 11, 16),
        Main = Color3.fromRGB(22, 22, 31),
        Outline = Color3.fromRGB(42, 42, 58),
    },
    Cyan = {
        Accent = Color3.fromRGB(34, 211, 238),
        Background = Color3.fromRGB(9, 13, 17),
        Main = Color3.fromRGB(18, 26, 33),
        Outline = Color3.fromRGB(34, 50, 62),
    },
    Crimson = {
        Accent = Color3.fromRGB(244, 63, 94),
        Background = Color3.fromRGB(14, 10, 12),
        Main = Color3.fromRGB(27, 19, 23),
        Outline = Color3.fromRGB(54, 36, 44),
    },
    Mint = {
        Accent = Color3.fromRGB(52, 211, 153),
        Background = Color3.fromRGB(9, 14, 12),
        Main = Color3.fromRGB(18, 28, 24),
        Outline = Color3.fromRGB(34, 54, 46),
    },
}

local function Shift(Color, Amount)
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV((H + Amount) % 1, S, V)
end

return function(Library, Options)
    Options = Options or {}
    local Preset = Presets[Options.Preset or "Violet"] or Presets.Violet
    local Radius = Options.Radius or 6

    local Skin = { Gradients = {} }

    local Main = Library.ScreenGui:FindFirstChild("Main")
    assert(Main, "Call Skin after Library:CreateWindow().")

    ----------------------------------------------------------------
    -- 1. Palette + font
    ----------------------------------------------------------------
    local function BuildAccentSequence()
        local A = Library.Scheme.AccentColor
        local B = Shift(A, 0.08)
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, A),
            ColorSequenceKeypoint.new(0.5, B),
            ColorSequenceKeypoint.new(1, A),
        })
    end

    function Skin:SetPreset(Name)
        local P = Presets[Name]
        if not P then
            return
        end
        local S = Library.Scheme
        S.AccentColor = P.Accent
        S.BackgroundColor = P.Background
        S.MainColor = P.Main
        S.OutlineColor = P.Outline
        Library:UpdateColorsUsingRegistry()
        for _, G in ipairs(Skin.Gradients) do
            G.Color = BuildAccentSequence()
        end
    end

    Library:SetFont(Options.Font or Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium))
    Skin:SetPreset(Options.Preset or "Violet")

    ----------------------------------------------------------------
    -- 2. Window chrome: soft gradient, accent glow stroke, shimmer bar
    ----------------------------------------------------------------
    local BodyGradient = Instance.new("UIGradient")
    BodyGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 215))
    BodyGradient.Rotation = 90
    BodyGradient.Parent = Main

    local Glow = Instance.new("UIStroke")
    Glow.Thickness = 1.5
    Glow.Transparency = 0.55
    Glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Glow.Color = Library.Scheme.AccentColor
    Glow.Parent = Main
    Library:AddToRegistry(Glow, { Color = "AccentColor" })

    local Bar = Instance.new("Frame")
    Bar.Name = "AccentBar"
    Bar.BorderSizePixel = 0
    Bar.BackgroundColor3 = Color3.new(1, 1, 1)
    Bar.Position = UDim2.fromOffset(0, 47)
    Bar.Size = UDim2.new(1, 0, 0, 2)
    Bar.ZIndex = 5
    Bar.Parent = Main

    local BarGradient = Instance.new("UIGradient")
    BarGradient.Color = BuildAccentSequence()
    BarGradient.Parent = Bar
    table.insert(Skin.Gradients, BarGradient)

    -- slow shimmer
    local T0 = os.clock()
    Library:GiveSignal(RunService.Heartbeat:Connect(function()
        if not Library.Toggled then
            return
        end
        BarGradient.Offset = Vector2.new(math.sin((os.clock() - T0) * 0.9) * 0.5, 0)
    end))

    ----------------------------------------------------------------
    -- 3. Open / close animation (scale pop)
    ----------------------------------------------------------------
    local Scale = Instance.new("UIScale")
    Scale.Parent = Main

    local OldToggle = Library.Toggle
    Library.Toggle = function(...)
        OldToggle(...)
        if Library.Toggled then
            Scale.Scale = 0.94
            TweenService:Create(Scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Scale = 1,
            }):Play()
        end
    end

    ----------------------------------------------------------------
    -- 4. Polish for every control (existing + future)
    ----------------------------------------------------------------
    local Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function Polish(Obj)
        if Obj == Main then
            return
        end

        task.defer(function()
            if not Obj.Parent then
                return
            end

            if Obj:IsA("TextBox") and not Obj:FindFirstChildOfClass("UICorner") then
                local C = Instance.new("UICorner")
                C.CornerRadius = UDim.new(0, Radius)
                C.Parent = Obj
            end

            if Obj:IsA("TextButton") then
                local Stroke = Obj:FindFirstChildOfClass("UIStroke")
                if Stroke and not Obj:FindFirstChildOfClass("UICorner") then
                    local C = Instance.new("UICorner")
                    C.CornerRadius = UDim.new(0, Radius)
                    C.Parent = Obj

                    -- accent outline on hover
                    Obj.MouseEnter:Connect(function()
                        TweenService:Create(Stroke, Hover, { Color = Library.Scheme.AccentColor }):Play()
                    end)
                    Obj.MouseLeave:Connect(function()
                        TweenService:Create(Stroke, Hover, { Color = Library.Scheme.OutlineColor }):Play()
                    end)
                end
            end
        end)
    end

    for _, D in ipairs(Library.ScreenGui:GetDescendants()) do
        Polish(D)
    end
    Library:GiveSignal(Library.ScreenGui.DescendantAdded:Connect(Polish))

    ----------------------------------------------------------------
    -- 5. Notifications: re-tint timer bar gradient (cheap touch-up)
    ----------------------------------------------------------------
    Library:GiveSignal(Library.ScreenGui.DescendantAdded:Connect(function(Obj)
        if Obj:IsA("Frame") and Obj.Parent and Obj.Parent.Name ~= "AccentBar" and Obj.BackgroundColor3 == Library.Scheme.AccentColor and Obj.Size.Y.Offset == 0 and Obj.Size.Y.Scale == 1 then
            local G = Instance.new("UIGradient")
            G.Color = BuildAccentSequence()
            G.Parent = Obj
            table.insert(Skin.Gradients, G)
        end
    end))

    return Skin
end
