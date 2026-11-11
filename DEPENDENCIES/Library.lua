--// Custom UI library -- API-compatible with the calls used by the SGW Hub / hydroxide script
local cloneref = cloneref or function(x) return x end
local function svc(n) return cloneref(game:GetService(n)) end
local uis, rs, hs, cg = svc("UserInputService"), svc("RunService"), svc("HttpService"), svc("CoreGui")

local function camera() return workspace.CurrentCamera end
local LEFT, TOUCH, M1 = Enum.TextXAlignment.Left, Enum.UserInputType.Touch, Enum.UserInputType.MouseButton1
local AY, AX, AXY = Enum.AutomaticSize.Y, Enum.AutomaticSize.X, Enum.AutomaticSize.XY

local library = {
    Toggles = {}, Options = {}, Labels = {}, Registry = {}, Connections = {},
    KeyPickers = {}, KeybindLabels = {}, Windows = {},
    Unloaded = false, Toggled = false, PickingKey = false,
    Font = Enum.Font.Gotham, CornerRadius = 4,
    TweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad),
    StatusFrameEnabled = false, HideInactiveStatus = true,
    KeybindFrameEnabled = false, HideInactiveKeybinds = false,
    NotifySide = "Left",
    Scheme = {
        BackgroundColor = Color3.fromRGB(15, 15, 15),
        MainColor = Color3.fromRGB(25, 25, 25),
        AccentColor = Color3.fromRGB(125, 85, 255),
        OutlineColor = Color3.fromRGB(45, 45, 45),
        FontColor = Color3.fromRGB(240, 240, 240),
        Red = Color3.fromRGB(255, 80, 80),
    },
}
pcall(function() getgenv().Library = library end)

------------------------------------------------------------------ helpers
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(library.Connections, c)
    return c
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[UI] callback error: " .. tostring(err)) end
end

local function fire(list, ...)
    for _, fn in ipairs(list) do safe(fn, ...) end
end

function library:Reg(inst, prop, key)
    local r = self.Registry[inst]
    if not r then
        r = {}
        self.Registry[inst] = r
        inst.Destroying:Connect(function() library.Registry[inst] = nil end)
    end
    r[prop] = key
    if type(key) == "string" and self.Scheme[key] then inst[prop] = self.Scheme[key] end
end

function library:UpdateColorsUsingRegistry()
    for inst, props in pairs(self.Registry) do
        for prop, key in pairs(props) do
            if type(key) == "string" and self.Scheme[key] then pcall(function() inst[prop] = self.Scheme[key] end) end
        end
    end
end

local TEXT = { TextLabel = true, TextButton = true, TextBox = true }
local function new(class, props, reg)
    local o = Instance.new(class)
    local parent
    if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
    if TEXT[class] then
        o.Font = library.Font
        o.TextSize = 13
        if not (props and props.TextColor3) then library:Reg(o, "TextColor3", "FontColor") end
    end
    if class == "TextButton" then o.AutoButtonColor = false end
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    for p, key in pairs(reg or {}) do library:Reg(o, p, key) end
    o.Parent = parent
    return o
end

local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or library.CornerRadius), Parent = p }) end
local function stroke(p, key)
    return new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Parent = p }, { Color = key or "OutlineColor" })
end
local function pad(p, l, t, r, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l),
        PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l), Parent = p,
    })
end
local function list(p, padding, order)
    return new("UIListLayout", { Padding = UDim.new(0, padding or 0), SortOrder = order or Enum.SortOrder.LayoutOrder, Parent = p })
end

local function makeDraggable(handle, target)
    handle.InputBegan:Connect(function(i)
        if i.UserInputType ~= M1 then return end
        local start, origin = uis:GetMouseLocation(), target.Position
        local conn
        conn = rs.RenderStepped:Connect(function()
            if not uis:IsMouseButtonPressed(M1) or library.Unloaded then conn:Disconnect() return end
            local d = uis:GetMouseLocation() - start
            target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
        end)
    end)
end

-- calls fn(mousePos) every frame while the left mouse button is held
local function dragLoop(fn)
    local conn
    conn = rs.RenderStepped:Connect(function()
        if not uis:IsMouseButtonPressed(M1) or library.Unloaded then conn:Disconnect() return end
        fn(uis:GetMouseLocation())
    end)
    fn(uis:GetMouseLocation())
end

function library:MakeLine(frame, info)
    info = info or {}
    return new("Frame", {
        Size = info.Size or UDim2.new(1, 0, 0, 1),
        Position = info.Position or UDim2.new(0, 0, 1, 0),
        ZIndex = info.ZIndex or 1, Parent = frame,
    }, { BackgroundColor3 = "OutlineColor" })
end

------------------------------------------------------------------ root gui
local gui = Instance.new("ScreenGui")
gui.Name = "UI_" .. hs:GenerateGUID(false):sub(1, 8)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
gui.Parent = (gethui and gethui()) or cg
library.ScreenGui = gui

-- tooltip
local tipFrame = new("Frame", { Visible = false, AutomaticSize = AXY, Size = UDim2.new(), ZIndex = 300, Parent = gui }, { BackgroundColor3 = "BackgroundColor" })
corner(tipFrame, 3); stroke(tipFrame); pad(tipFrame, 5, 3)
local tipLabel = new("TextLabel", { AutomaticSize = AXY, Size = UDim2.new(), BackgroundTransparency = 1, ZIndex = 301, Text = "", Parent = tipFrame })
connect(rs.RenderStepped, function()
    if tipFrame.Visible then
        local m = uis:GetMouseLocation()
        tipFrame.Position = UDim2.fromOffset(m.X + 14, m.Y + 14)
    end
end)
local function addTooltip(obj, text)
    if not text or text == "" then return end
    obj.MouseEnter:Connect(function() tipLabel.Text = text; tipFrame.Visible = true end)
    obj.MouseLeave:Connect(function() tipFrame.Visible = false end)
end

-- notifications
local notifyHolder = new("Frame", { Size = UDim2.new(0, 280, 1, -20), Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 100, Parent = gui })
list(notifyHolder, 6)

function library:Notify(a, b)
    local title, desc, time, color
    if type(a) == "table" then title, desc, time = a.Title, (a.Description or a.Text), a.Time else desc = tostring(a) end
    if type(b) == "number" then time = b elseif typeof(b) == "Color3" then color = b end
    time = time or 4

    local frames = {}
    for _, c in ipairs(notifyHolder:GetChildren()) do if c:IsA("Frame") then table.insert(frames, c) end end
    if #frames >= 8 then frames[1]:Destroy() end

    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, ZIndex = 100, Parent = notifyHolder }, { BackgroundColor3 = "MainColor" })
    corner(f); stroke(f)
    new("Frame", { Size = UDim2.new(0, 3, 1, 0), ZIndex = 102, BackgroundColor3 = color or self.Scheme.AccentColor, Parent = f }, color and nil or { BackgroundColor3 = "AccentColor" })
    local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, ZIndex = 101, Parent = f })
    list(body, 2); pad(body, 12, 6, 8, 6)
    if title then
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = tostring(title), Font = Enum.Font.GothamBold, TextXAlignment = LEFT, ZIndex = 102, Parent = body })
    end
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, Text = tostring(desc or ""), TextWrapped = true, TextXAlignment = LEFT, ZIndex = 102, LayoutOrder = 1, Parent = body })
    task.delay(time, function() if f then f:Destroy() end end)
    return f
end

------------------------------------------------------------------ floating frames (status / keybinds)
local function makeFloat(title, pos)
    local f = new("Frame", { Size = UDim2.fromOffset(190, 0), AutomaticSize = AY, Position = pos, Visible = false, ZIndex = 20, Parent = gui }, { BackgroundColor3 = "MainColor" })
    corner(f); stroke(f); list(f)
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = title, Font = Enum.Font.GothamBold, LayoutOrder = 0, ZIndex = 21, Parent = f })
    new("Frame", { Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 1, ZIndex = 21, Parent = f }, { BackgroundColor3 = "AccentColor" })
    makeDraggable(f, f)
    return f
end
library.StatusFrame = makeFloat("Status", UDim2.fromOffset(10, 200))
library.KeybindFrame = makeFloat("Keybinds", UDim2.fromOffset(10, 330))

function library:StatusWindow()
    local obj = { Items = {} }
    function obj:Clear()
        for _, l in ipairs(self.Items) do l:Destroy() end
        self.Items = {}
    end
    function obj:AddItem(text, color)
        local l = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = tostring(text),
            TextColor3 = color or Color3.new(1, 1, 1), TextXAlignment = LEFT, LayoutOrder = #self.Items + 2,
            ZIndex = 21, Parent = library.StatusFrame,
        })
        pad(l, 8, 0, 8, 0)
        table.insert(self.Items, l)
    end
    self.StatusObj = obj
    return obj
end

function library:UpdateStatusFrame()
    local n = self.StatusObj and #self.StatusObj.Items or 0
    self.StatusFrame.Visible = self.StatusFrameEnabled and (not self.HideInactiveStatus or n > 0)
end

function library:UpdateKeybindFrame()
    for _, l in ipairs(self.KeybindLabels) do l:Destroy() end
    self.KeybindLabels = {}
    if self.KeybindFrameEnabled then
        for _, kp in ipairs(self.KeyPickers) do
            local active = kp:GetState()
            if not kp.NoUI and kp.Value ~= "None" and (not self.HideInactiveKeybinds or active) then
                local l = new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextXAlignment = LEFT,
                    Text = ("[%s] %s (%s)"):format(kp.Value, kp.Text, kp.Mode), LayoutOrder = #self.KeybindLabels + 2,
                    TextColor3 = active and self.Scheme.AccentColor or self.Scheme.FontColor, ZIndex = 21, Parent = self.KeybindFrame,
                })
                pad(l, 8, 0, 8, 0)
                table.insert(self.KeybindLabels, l)
            end
        end
    end
    self.KeybindFrame.Visible = self.KeybindFrameEnabled
end
function library:RefreshKeybindVisibility() self:UpdateKeybindFrame() end

function library:Toggle(v)
    if v == nil then v = not self.Toggled end
    self.Toggled = v
    for _, w in ipairs(self.Windows) do w.Main.Visible = v end
    if not v then tipFrame.Visible = false end
end

function library:Unload()
    if self.Unloaded then return end
    self.Unloaded = true
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    pcall(function() gui:Destroy() end)
    pcall(function() if getgenv().Library == self then getgenv().Library = nil end end)
end

------------------------------------------------------------------ elements
local Funcs, Addon = {}, {}
Funcs.__index = Funcs
Addon.__index = Addon

local function getAddons(obj)
    if obj.Addons then return obj.Addons end
    local a = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, BackgroundTransparency = 1, ZIndex = 3, Parent = obj.Row })
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = a })
    obj.Addons = a
    return a
end

local function row(self, h)
    return new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, Parent = self.Container })
end

function Funcs:AddLabel(a, b)
    local idx, cfg
    if type(b) == "table" then idx, cfg = a, b else cfg = { Text = a } end
    local lbl = setmetatable({ Type = "Label" }, Addon)
    lbl.Row = new("Frame", { Size = UDim2.new(1, 0, 0, 16), AutomaticSize = AY, BackgroundTransparency = 1, Parent = self.Container })
    lbl.TextLabel = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), AutomaticSize = AY, BackgroundTransparency = 1, Text = tostring(cfg.Text or ""),
        TextWrapped = cfg.DoesWrap == true, TextXAlignment = LEFT, Parent = lbl.Row,
    })
    function lbl:SetText(t) self.TextLabel.Text = tostring(t) end
    function lbl:SetVisible(v) self.Row.Visible = v end
    if idx then library.Labels[idx] = lbl end
    return lbl
end

function Funcs:AddDivider()
    local r = row(self, 9)
    library:MakeLine(r, { Position = UDim2.new(0, 0, 0.5, 0) })
end

function Funcs:AddButton(a, b)
    local cfg
    if type(a) == "table" then cfg = a
    elseif type(b) == "function" then cfg = { Text = a, Func = b }
    elseif type(b) == "table" then cfg = b; cfg.Text = cfg.Text or a
    else cfg = { Text = tostring(a) } end

    local btn = { Type = "Button", Row = row(self, 24) }
    btn.Base = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), Text = cfg.Text or "Button", AutoButtonColor = true, Parent = btn.Row }, { BackgroundColor3 = "BackgroundColor" })
    corner(btn.Base); stroke(btn.Base)
    addTooltip(btn.Base, cfg.Tooltip)
    local armed = false
    btn.Base.MouseButton1Click:Connect(function()
        if btn.Disabled then return end
        if cfg.DoubleClick and not armed then
            armed = true
            btn.Base.Text = "Are you sure?"
            task.delay(2, function() armed = false; btn.Base.Text = btn.Text end)
            return
        end
        armed = false
        btn.Base.Text = btn.Text
        safe(cfg.Func or cfg.Callback)
    end)
    btn.Text = cfg.Text or "Button"
    function btn:SetText(t) self.Text = tostring(t); self.Base.Text = self.Text end
    function btn:SetVisible(v) self.Row.Visible = v end
    function btn:SetDisabled(v) self.Disabled = v; self.Base.TextTransparency = v and 0.5 or 0 end
    return btn
end

function Funcs:AddToggle(idx, cfg)
    cfg = cfg or {}
    local t = setmetatable({ Type = "Toggle", Value = cfg.Default == true, Disabled = cfg.Disabled == true, Callbacks = {}, Risky = cfg.Risky, KeyPickers = {}, Text = cfg.Text or idx }, Addon)
    t.Row = row(self, 18)
    t.Box = new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 0, 0.5, -7), Parent = t.Row }, { BackgroundColor3 = "BackgroundColor" })
    corner(t.Box, 3); stroke(t.Box)
    t.TextLabel = new("TextLabel", { Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(22, 0), BackgroundTransparency = 1, Text = t.Text, TextXAlignment = LEFT, Parent = t.Row })
    local hit = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 2, Parent = t.Row })
    addTooltip(hit, cfg.Tooltip)

    function t:_refresh()
        library:Reg(self.Box, "BackgroundColor3", self.Value and "AccentColor" or "BackgroundColor")
        if self.Risky then library:Reg(self.TextLabel, "TextColor3", "Red") end
        self.TextLabel.TextTransparency = self.Disabled and 0.5 or 0
    end
    function t:SetValue(v)
        v = v == true
        if v == self.Value then return end
        self.Value = v
        for _, kp in ipairs(self.KeyPickers) do if kp.SyncToggleState then kp.Toggled = v end end
        self:_refresh()
        safe(cfg.Callback, v)
        fire(self.Callbacks, v)
        library:UpdateKeybindFrame()
    end
    function t:OnChanged(fn) table.insert(self.Callbacks, fn); return self end
    function t:SetDisabled(v) self.Disabled = v == true; self:_refresh() end
    function t:SetText(s) self.Text = tostring(s); self.TextLabel.Text = self.Text end
    function t:SetVisible(v) self.Row.Visible = v end
    hit.MouseButton1Click:Connect(function() if not t.Disabled then t:SetValue(not t.Value) end end)
    t:_refresh()
    if idx then library.Toggles[idx] = t end
    return t
end

function Funcs:AddSlider(idx, cfg)
    cfg = cfg or {}
    local s = { Type = "Slider", Min = cfg.Min or 0, Max = cfg.Max or 100, Rounding = cfg.Rounding or 0, Suffix = cfg.Suffix or "", Callbacks = {}, Text = cfg.Text or idx }
    local mult = 10 ^ s.Rounding
    local function fix(v) return math.floor(math.clamp(v, s.Min, s.Max) * mult + 0.5) / mult end
    s.Value = fix(cfg.Default or s.Min)

    local compact = cfg.Compact == true
    s.Row = row(self, compact and 20 or 36)
    if not compact then
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = s.Text or "", TextXAlignment = LEFT, Parent = s.Row })
    end
    local bar = new("Frame", { Size = UDim2.new(1, 0, 0, compact and 20 or 18), Position = UDim2.new(0, 0, 1, compact and -20 or -18), Parent = s.Row }, { BackgroundColor3 = "BackgroundColor" })
    corner(bar, 3); stroke(bar)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = bar }, { BackgroundColor3 = "AccentColor" })
    corner(fill, 3)
    local valLbl = new("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 3, Parent = bar, TextColor3 = Color3.new(1, 1, 1) })
    new("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = valLbl })
    addTooltip(bar, cfg.Tooltip)

    function s:_refresh()
        local a = (self.Max == self.Min) and 0 or (self.Value - self.Min) / (self.Max - self.Min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        local txt
        if cfg.FormatDisplayValue then
            local ok, r = pcall(cfg.FormatDisplayValue, self, self.Value)
            txt = ok and tostring(r) or tostring(self.Value)
        else
            txt = tostring(self.Value) .. self.Suffix
            if not cfg.HideMax then txt = txt .. " / " .. tostring(self.Max) .. self.Suffix end
        end
        valLbl.Text = compact and ((self.Text or "") .. ": " .. txt) or txt
    end
    function s:SetValue(v)
        v = tonumber(v)
        if not v then return end
        v = fix(v)
        if v == self.Value then return end
        self.Value = v
        self:_refresh()
        safe(cfg.Callback, v)
        fire(self.Callbacks, v)
    end
    function s:OnChanged(fn) table.insert(self.Callbacks, fn); return self end
    function s:SetMax(m) self.Max = m; self.Value = fix(self.Value); self:_refresh() end
    function s:SetMin(m) self.Min = m; self.Value = fix(self.Value); self:_refresh() end
    function s:SetVisible(v) self.Row.Visible = v end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType ~= M1 then return end
        dragLoop(function(m)
            local a = math.clamp((m.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            s:SetValue(s.Min + (s.Max - s.Min) * a)
        end)
    end)
    s:_refresh()
    if idx then library.Options[idx] = s end
    return s
end

function Funcs:AddInput(idx, cfg)
    cfg = cfg or {}
    local i = { Type = "Input", Value = tostring(cfg.Default or ""), Numeric = cfg.Numeric, Finished = cfg.Finished, Callbacks = {}, Text = cfg.Text }
    i.Row = row(self, cfg.Text and 40 or 22)
    if cfg.Text then
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = cfg.Text, TextXAlignment = LEFT, Parent = i.Row })
    end
    i.Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), Parent = i.Row }, { BackgroundColor3 = "BackgroundColor" })
    corner(i.Holder); stroke(i.Holder)
    local tb = new("TextBox", {
        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), BackgroundTransparency = 1, Text = i.Value,
        PlaceholderText = cfg.Placeholder or "", PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
        ClearTextOnFocus = cfg.ClearTextOnFocus == true, TextXAlignment = LEFT, ClipsDescendants = true, Parent = i.Holder,
    })
    i.TextBox = tb
    addTooltip(i.Holder, cfg.Tooltip)

    function i:SetValue(v)
        v = tostring(v == nil and "" or v)
        if v == self.Value then return end
        self.Value = v
        if tb.Text ~= v then tb.Text = v end
        safe(cfg.Callback, v)
        fire(self.Callbacks, v)
    end
    function i:OnChanged(fn) table.insert(self.Callbacks, fn); return self end
    function i:SetVisible(v) self.Row.Visible = v end

    tb:GetPropertyChangedSignal("Text"):Connect(function()
        if i.Numeric then
            local cleaned = (tb.Text:gsub("[^%d%.%-]", ""))
            if cleaned ~= tb.Text then tb.Text = cleaned return end
        end
        if not i.Finished then i:SetValue(tb.Text) end
    end)
    tb.FocusLost:Connect(function() i:SetValue(tb.Text) end)
    if idx then library.Options[idx] = i end
    return i
end

function Funcs:AddActionList(cfg)
    cfg = cfg or {}
    local a = { Type = "ActionList" }
    a.Row = row(self, cfg.Height or 100)
    local sc = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ScrollBarThickness = 3, Parent = a.Row }, { BackgroundColor3 = "BackgroundColor" })
    corner(sc); stroke(sc); list(sc, 1); pad(sc, 4)
    local function describe(act, n)
        local t = act.type or "?"
        if t == "keybind" then return ("%d. %s -> %s"):format(n, tostring(act.key), tostring(act.tool)) end
        local extra = act.tool or act.duration or act.amount or act.file or act.keycode
        return ("%d. %s%s"):format(n, t, extra and (": " .. tostring(extra)) or "")
    end
    function a:SetActions(actions)
        for _, c in ipairs(sc:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        if #actions == 0 then
            new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "No actions added", TextXAlignment = LEFT, Parent = sc })
        end
        for n, act in ipairs(actions) do
            new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = describe(act, n), TextXAlignment = LEFT, LayoutOrder = n, Parent = sc })
        end
    end
    a:SetActions({})
    return a
end

-- dropdown ----------------------------------------------------------------
function Funcs:AddDropdown(idx, cfg)
    cfg = cfg or {}
    local d = { Type = "Dropdown", Values = cfg.Values or {}, Multi = cfg.Multi == true, AllowNull = cfg.AllowNull == true, Callbacks = {}, Text = cfg.Text }
    d.Value = d.Multi and {} or nil

    local function resolve(def)
        local out = {}
        if def == nil then return out end
        if type(def) == "number" then if d.Values[def] ~= nil then table.insert(out, d.Values[def]) end
        elseif type(def) == "string" then table.insert(out, def)
        elseif type(def) == "table" then
            for k, v in pairs(def) do
                if type(k) == "number" then
                    if type(v) == "number" then if d.Values[v] ~= nil then table.insert(out, d.Values[v]) end
                    elseif type(v) == "string" then table.insert(out, v) end
                elseif type(k) == "string" and v == true then table.insert(out, k) end
            end
        end
        return out
    end

    d.Row = row(self, cfg.Text and 42 or 22)
    if cfg.Text then
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = cfg.Text, TextXAlignment = LEFT, Parent = d.Row })
    end
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), TextXAlignment = LEFT, Text = "", Parent = d.Row }, { BackgroundColor3 = "BackgroundColor" })
    corner(btn); stroke(btn); pad(btn, 6, 0, 18, 0)
    new("TextLabel", { Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, 12, 0, 0), BackgroundTransparency = 1, Text = "v", Parent = btn })
    addTooltip(btn, cfg.Tooltip)

    local function isSel(v) if d.Multi then return d.Value[v] == true end return d.Value == v end
    function d:_text()
        if self.Multi then
            local t = {}
            for _, v in ipairs(self.Values) do if self.Value[v] then table.insert(t, tostring(v)) end end
            return #t > 0 and table.concat(t, ", ") or "---"
        end
        return self.Value ~= nil and tostring(self.Value) or "---"
    end
    function d:_refresh()
        btn.Text = self:_text()
        if self._paint then self._paint() end
    end
    function d:_close()
        if self._pop then self._pop:Destroy(); self._pop = nil end
        if self._blk then self._blk:Destroy(); self._blk = nil end
        self._paint = nil
    end
    function d:_changed()
        self:_refresh()
        safe(cfg.Callback, self.Value)
        fire(self.Callbacks, self.Value)
    end
    function d:SetValue(v)
        if self.Multi then
            local new_ = {}
            for _, name in ipairs(resolve(v)) do new_[name] = true end
            self.Value = new_
        else
            local r = resolve(v)[1]
            if r == self.Value then return end
            self.Value = r
        end
        self:_changed()
    end
    function d:SetValues(vals)
        self:_close()
        self.Values = vals or {}
        local set = {}
        for _, v in ipairs(self.Values) do set[v] = true end
        if self.Multi then for k in pairs(self.Value) do if not set[k] then self.Value[k] = nil end end
        elseif self.Value ~= nil and not set[self.Value] then self.Value = nil end
        self:_refresh()
    end
    function d:OnChanged(fn) table.insert(self.Callbacks, fn); return self end
    function d:SetVisible(v) self.Row.Visible = v end

    function d:_open()
        self:_close()
        if #self.Values == 0 then return end
        local blk = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 49, Parent = gui })
        blk.MouseButton1Down:Connect(function() self:_close() end)
        self._blk = blk
        local bp, bs = btn.AbsolutePosition, btn.AbsoluteSize
        local h = math.min(#self.Values, 8) * 20 + 4
        local y = bp.Y + bs.Y + 2
        if y + h > camera().ViewportSize.Y then y = bp.Y - h - 2 end
        local pop = new("ScrollingFrame", {
            Position = UDim2.fromOffset(bp.X, y), Size = UDim2.fromOffset(bs.X, h), CanvasSize = UDim2.new(),
            AutomaticCanvasSize = AY, ScrollBarThickness = 3, ZIndex = 50, Parent = gui,
        }, { BackgroundColor3 = "BackgroundColor" })
        stroke(pop); list(pop); pad(pop, 2)
        self._pop = pop
        local items = {}
        for n, val in ipairs(self.Values) do
            local it = new("TextButton", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "  " .. tostring(val), TextXAlignment = LEFT, ZIndex = 51, LayoutOrder = n, Parent = pop })
            items[val] = it
            it.MouseButton1Click:Connect(function()
                if self.Multi then
                    self.Value[val] = (not self.Value[val]) or nil
                    self:_changed()
                else
                    if self.Value == val and self.AllowNull then self.Value = nil else self.Value = val end
                    self:_changed()
                    self:_close()
                end
            end)
        end
        self._paint = function()
            for val, it in pairs(items) do library:Reg(it, "TextColor3", isSel(val) and "AccentColor" or "FontColor") end
        end
        self._paint()
    end
    btn.MouseButton1Click:Connect(function() if d._pop then d:_close() else d:_open() end end)

    if cfg.Default ~= nil then
        local r = resolve(cfg.Default)
        if d.Multi then for _, v in ipairs(r) do d.Value[v] = true end else d.Value = r[1] end
    end
    d:_refresh()
    if idx then library.Options[idx] = d end
    return d
end

-- addons: key picker / color picker --------------------------------------
local function keyName(input)
    local t = input.UserInputType
    if t == M1 then return "MB1" elseif t == Enum.UserInputType.MouseButton2 then return "MB2" elseif t == Enum.UserInputType.MouseButton3 then return "MB3" end
    if t == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode.Name end
end

local MODES = { "Toggle", "Hold", "Press", "Always" }

function Addon:AddKeyPicker(idx, cfg)
    cfg = cfg or {}
    local kp = {
        Type = "KeyPicker", Value = cfg.Default or "None", Mode = cfg.Mode or "Toggle", Text = cfg.Text or idx or "Keybind",
        NoUI = cfg.NoUI, Toggled = false, Callbacks = {}, Clicked = {}, Parent = self, SyncToggleState = cfg.SyncToggleState,
    }
    if self.Type == "Toggle" then table.insert(self.KeyPickers, kp); if kp.SyncToggleState then kp.Toggled = self.Value end end

    local btn = new("TextButton", { Size = UDim2.new(0, 0, 0, 16), AutomaticSize = AX, ZIndex = 3, Text = "", Parent = getAddons(self) }, { BackgroundColor3 = "BackgroundColor" })
    corner(btn, 3); stroke(btn); pad(btn, 5, 0)
    addTooltip(btn, "Click to bind, right click to change mode")

    function kp:GetState()
        if self.Mode == "Always" then return true end
        if self.Mode == "Press" then return false end
        return self.Toggled
    end
    function kp:_text() btn.Text = "[" .. self.Value .. "]" end
    function kp:SetValue(v)
        local key, mode = self.Value, self.Mode
        if type(v) == "table" then key, mode = v[1] or key, v[2] or mode elseif type(v) == "string" then key = v end
        local changed = key ~= self.Value
        self.Value, self.Mode = key, mode
        self:_text()
        library:UpdateKeybindFrame()
        if changed then fire(self.Callbacks, key) end
    end
    function kp:OnChanged(fn) table.insert(self.Callbacks, fn); return self end
    function kp:OnClick(fn) table.insert(self.Clicked, fn); return self end
    function kp:_fire(state)
        safe(cfg.Callback, state)
        fire(self.Clicked, state)
        library:UpdateKeybindFrame()
    end
    function kp:_input(input, down)
        if self.Value == "None" or keyName(input) ~= self.Value then return end
        if library.ToggleKeybind == self then
            if down then library:Toggle() end
            return
        end
        local parent = self.Parent
        local sync = self.SyncToggleState and parent and parent.Type == "Toggle"
        if self.Mode == "Toggle" and down then
            self.Toggled = not self.Toggled
            if sync then parent:SetValue(self.Toggled) end
            self:_fire(self.Toggled)
        elseif self.Mode == "Hold" then
            if self.Toggled ~= down then
                self.Toggled = down
                if sync then parent:SetValue(down) end
                self:_fire(down)
            end
        elseif self.Mode == "Press" and down then
            self:_fire(true)
        end
    end

    btn.MouseButton1Click:Connect(function()
        if library.PickingKey then return end
        library.PickingKey = true
        btn.Text = "[...]"
        task.wait()
        local conn
        conn = uis.InputBegan:Connect(function(input)
            local name = keyName(input)
            if not name then return end
            conn:Disconnect()
            library.PickingKey = false
            kp:SetValue(name == "Escape" and "None" or name)
            kp:_text()
        end)
    end)
    btn.MouseButton2Click:Connect(function()
        local n = table.find(MODES, kp.Mode) or 1
        kp.Mode = MODES[n % #MODES + 1]
        library:Notify(kp.Text .. " mode: " .. kp.Mode, 2)
        library:UpdateKeybindFrame()
    end)

    kp:_text()
    table.insert(library.KeyPickers, kp)
    library:UpdateKeybindFrame()
    if idx then library.Options[idx] = kp end
    return kp
end

function Addon:AddColorPicker(idx, cfg)
    cfg = cfg or {}
    local cp = { Type = "ColorPicker", Value = cfg.Default or Color3.new(1, 1, 1), Transparency = cfg.Transparency or 0, Callbacks = {}, Title = cfg.Title }
    local h, s, v = cp.Value:ToHSV()
    local sw = new("TextButton", { Size = UDim2.fromOffset(22, 12), Text = "", BackgroundColor3 = cp.Value, ZIndex = 3, Parent = getAddons(self) })
    corner(sw, 3); stroke(sw)

    local pop, blk, svBox, svKnob, hueKnob
    local function repaint()
        sw.BackgroundColor3 = cp.Value
        if svBox and svBox.Parent then svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            svKnob.Position = UDim2.new(s, -3, 1 - v, -3)
            hueKnob.Position = UDim2.new(0, -2, h, -2)
        end
    end
    local function apply()
        cp.Value = Color3.fromHSV(h, s, v)
        repaint()
        safe(cfg.Callback, cp.Value)
        fire(cp.Callbacks, cp.Value)
    end
    function cp:SetValue(c)
        if typeof(c) ~= "Color3" then return end
        h, s, v = c:ToHSV()
        self.Value = c
        repaint()
        safe(cfg.Callback, c)
        fire(self.Callbacks, c)
    end
    cp.SetValueRGB = cp.SetValue
    function cp:OnChanged(fn) table.insert(self.Callbacks, fn); return self end

    local function close() if pop then pop:Destroy() pop = nil end if blk then blk:Destroy() blk = nil end end
    sw.MouseButton1Click:Connect(function()
        if pop then close() return end
        blk = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 59, Parent = gui })
        blk.MouseButton1Down:Connect(close)
        local sp = sw.AbsolutePosition
        local vp = camera().ViewportSize
        pop = new("Frame", {
            Size = UDim2.fromOffset(190, 158), ZIndex = 60, Parent = gui,
            Position = UDim2.fromOffset(math.min(sp.X, vp.X - 200), math.min(sp.Y + 18, vp.Y - 168)),
        }, { BackgroundColor3 = "MainColor" })
        corner(pop); stroke(pop)
        if cp.Title then
            new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(8, 2), BackgroundTransparency = 1, Text = cp.Title, TextXAlignment = LEFT, ZIndex = 61, Parent = pop })
        end
        svBox = new("Frame", { Position = UDim2.fromOffset(8, 20), Size = UDim2.fromOffset(150, 130), BackgroundColor3 = Color3.fromHSV(h, 1, 1), ZIndex = 61, Parent = pop })
        local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 62, Parent = svBox })
        new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
        local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 63, Parent = svBox })
        new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
        svKnob = new("Frame", { Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 65, Parent = svBox })
        corner(svKnob, 3); stroke(svKnob, "BackgroundColor")
        local hueBar = new("Frame", { Position = UDim2.fromOffset(164, 20), Size = UDim2.fromOffset(18, 130), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 61, Parent = pop })
        local seq = {}
        for i = 0, 6 do table.insert(seq, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))) end
        new("UIGradient", { Rotation = 90, Color = ColorSequence.new(seq), Parent = hueBar })
        hueKnob = new("Frame", { Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 65, Parent = hueBar })
        stroke(hueKnob, "BackgroundColor")

        svBox.InputBegan:Connect(function(i)
            if i.UserInputType ~= M1 then return end
            dragLoop(function(m)
                s = math.clamp((m.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
                v = 1 - math.clamp((m.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
                apply()
            end)
        end)
        hueBar.InputBegan:Connect(function(i)
            if i.UserInputType ~= M1 then return end
            dragLoop(function(m)
                h = math.clamp((m.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 0.999)
                apply()
            end)
        end)
        repaint()
    end)

    if idx then library.Options[idx] = cp end
    return cp
end

setmetatable(Addon, { __index = nil })

------------------------------------------------------------------ groupboxes
local function makeGroupbox(parent, name)
    local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, Parent = parent }, { BackgroundColor3 = "MainColor" })
    corner(box); stroke(box); list(box)
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = name or "", Font = Enum.Font.GothamBold, TextXAlignment = LEFT, LayoutOrder = 0, Parent = box })
    local title = box:FindFirstChildOfClass("TextLabel"); pad(title, 8, 0, 8, 0)
    library:MakeLine(box, { Position = UDim2.new(), }).LayoutOrder = 1
    local container = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = 2, Parent = box })
    list(container, 5); pad(container, 8)
    return setmetatable({ Frame = box, Container = container }, Funcs)
end

local function makeTabbox(parent)
    local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, Parent = parent }, { BackgroundColor3 = "MainColor" })
    corner(box); stroke(box); list(box)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0, Parent = box })
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Parent = head })
    library:MakeLine(box).LayoutOrder = 1
    local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = 2, Parent = box })
    local tb = { Tabs = {}, Frame = box }
    local function show(t)
        for _, o in ipairs(tb.Tabs) do
            o.Container.Visible = o == t
            library:Reg(o.Button, "TextColor3", o == t and "AccentColor" or "FontColor")
        end
    end
    function tb:AddTab(name)
        local t = setmetatable({}, Funcs)
        t.Container = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, Visible = false, Parent = body })
        list(t.Container, 5); pad(t.Container, 8)
        t.Button = new("TextButton", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, BackgroundTransparency = 1, Text = name, Font = Enum.Font.GothamBold, Parent = head })
        pad(t.Button, 10, 0)
        t.Button.MouseButton1Click:Connect(function() show(t) end)
        table.insert(self.Tabs, t)
        if #self.Tabs == 1 then show(t) end
        return t
    end
    return tb
end

------------------------------------------------------------------ window
function library:CreateWindow(cfg)
    cfg = cfg or {}
    self.NotifySide = cfg.NotifySide or "Left"
    if self.NotifySide == "Right" then
        notifyHolder.AnchorPoint = Vector2.new(1, 0)
        notifyHolder.Position = UDim2.new(1, -10, 0, 10)
    end

    local W, H = cfg.Width or 640, cfg.Height or 500
    local vp = camera().ViewportSize
    local window = { Tabs = {}, Library = self }
    local main = new("Frame", {
        Name = "Main", Size = UDim2.fromOffset(W, H), ClipsDescendants = true, Visible = cfg.AutoShow == true, Parent = gui,
        Position = cfg.Center and UDim2.fromOffset(vp.X / 2 - W / 2, vp.Y / 2 - H / 2) or UDim2.fromOffset(60, 60),
    }, { BackgroundColor3 = "BackgroundColor" })
    corner(main); stroke(main)
    window.Main, window.MainFrame = main, main
    self.Toggled = cfg.AutoShow == true
    table.insert(self.Windows, window)

    local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 28), Parent = main }, { BackgroundColor3 = "MainColor" })
    new("TextLabel", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = cfg.Title or "UI", Font = Enum.Font.GothamBold, TextXAlignment = LEFT, Parent = bar })
    new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), Parent = bar }, { BackgroundColor3 = "AccentColor" })
    makeDraggable(bar, main)

    local side = new("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(0, 120, 1, -50), Parent = main }, { BackgroundColor3 = "MainColor" })
    list(side, 2); pad(side, 4)
    new("Frame", { Position = UDim2.fromOffset(120, 28), Size = UDim2.new(0, 1, 1, -50), Parent = main }, { BackgroundColor3 = "OutlineColor" })
    local content = new("Frame", { Position = UDim2.fromOffset(121, 28), Size = UDim2.new(1, -121, 1, -50), BackgroundTransparency = 1, ClipsDescendants = true, Parent = main })

    local bottom = new("Frame", { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22), Parent = main }, { BackgroundColor3 = "MainColor" })
    library:MakeLine(bottom, { Position = UDim2.new() })
    local ci = new("TextButton", { Name = "CommitIndicator", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, BackgroundTransparency = 1, Text = "", Parent = bottom })
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ci })
    local dot = new("Frame", { Name = "CommitDot", Size = UDim2.fromOffset(6, 6), LayoutOrder = 1, BackgroundColor3 = Color3.fromRGB(46, 204, 113), Parent = ci })
    corner(dot, 3)
    local cl = new("TextLabel", { Name = "CommitLabel", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, BackgroundTransparency = 1, LayoutOrder = 2, Text = "", TextColor3 = Color3.fromRGB(150, 150, 150), Parent = ci })
    window.CommitIndicator, window.CommitLabel = ci, cl
    function window:SetCommitStatus(id, latest, date, msg)
        cl.Text = tostring(id):sub(1, 7)
        dot.BackgroundColor3 = latest and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(239, 68, 68)
        ci:SetAttribute("CommitId", id); ci:SetAttribute("CommitDate", date); ci:SetAttribute("CommitMsg", msg)
    end
    new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 0), Size = UDim2.new(0, 200, 1, 0), BackgroundTransparency = 1, Text = cfg.Footer or "", TextXAlignment = Enum.TextXAlignment.Right, Parent = bottom })

    if cfg.Resizable ~= false then
        local grip = new("TextButton", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1, Text = "◢", TextSize = 10, ZIndex = 10, Parent = main })
        grip.InputBegan:Connect(function(i)
            if i.UserInputType ~= M1 then return end
            dragLoop(function(m)
                local p = main.AbsolutePosition
                main.Size = UDim2.fromOffset(math.max(460, m.X - p.X + 4), math.max(340, m.Y - p.Y + 4))
            end)
        end)
    end

    function window:_select(tab)
        for _, t in ipairs(self.Tabs) do
            local on = t == tab
            t.Page.Visible = on
            t.Mark.Visible = on
            library:Reg(t.Button, "BackgroundColor3", on and "BackgroundColor" or "MainColor")
            library:Reg(t.Button, "TextColor3", on and "AccentColor" or "FontColor")
        end
        self.ActiveTab = tab
    end

    function window:AddTab(name)
        local tab = { Name = name, Window = window }
        tab.Button = new("TextButton", { Size = UDim2.new(1, 0, 0, 26), Text = "   " .. name, TextXAlignment = LEFT, Parent = side }, { BackgroundColor3 = "MainColor" })
        corner(tab.Button, 3)
        tab.Mark = new("Frame", { Size = UDim2.new(0, 2, 1, -8), Position = UDim2.fromOffset(0, 4), Visible = false, Parent = tab.Button }, { BackgroundColor3 = "AccentColor" })

        tab.Page = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = content })
        tab.Warning = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 44), Visible = false, Parent = tab.Page }, { BackgroundColor3 = "MainColor" })
        corner(tab.Warning); new("UIStroke", { Color = library.Scheme.Red, Thickness = 1, Parent = tab.Warning })
        local wt = new("TextLabel", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(8, 3), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = library.Scheme.Red, TextXAlignment = LEFT, Text = "", Parent = tab.Warning })
        local wb = new("TextLabel", { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 21), BackgroundTransparency = 1, TextXAlignment = LEFT, TextWrapped = true, Text = "", Parent = tab.Warning })

        tab.Scroll = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ScrollBarThickness = 3, Parent = tab.Page })
        local left = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(0.5, -9, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, Parent = tab.Scroll })
        local right = new("Frame", { Position = UDim2.new(0.5, 3, 0, 6), Size = UDim2.new(0.5, -9, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, Parent = tab.Scroll })
        list(left, 6); list(right, 6)

        function tab:AddLeftGroupbox(n) return makeGroupbox(left, n) end
        function tab:AddRightGroupbox(n) return makeGroupbox(right, n) end
        function tab:AddLeftTabbox() return makeTabbox(left) end
        function tab:AddRightTabbox() return makeTabbox(right) end
        function tab:UpdateWarningBox(info)
            info = info or {}
            wt.Text, wb.Text = info.Title or "", info.Text or ""
            tab.Warning.Visible = info.Visible == true
            local y = tab.Warning.Visible and 56 or 0
            tab.Scroll.Position = UDim2.fromOffset(0, y)
            tab.Scroll.Size = UDim2.new(1, 0, 1, -y)
        end
        function tab:Show() window:_select(tab) end

        tab.Button.MouseButton1Click:Connect(function() window:_select(tab) end)
        table.insert(window.Tabs, tab)
        if #window.Tabs == 1 then window:_select(tab) end
        return tab
    end

    function window:Toggle(v) library:Toggle(v) end
    return window
end

------------------------------------------------------------------ global key handling
connect(uis.InputBegan, function(input)
    if library.Unloaded or library.PickingKey or uis:GetFocusedTextBox() then return end
    if not library.ToggleKeybind and input.KeyCode == Enum.KeyCode.RightShift then library:Toggle() return end
    for _, kp in ipairs(library.KeyPickers) do kp:_input(input, true) end
end)
connect(uis.InputEnded, function(input)
    if library.Unloaded or library.PickingKey then return end
    for _, kp in ipairs(library.KeyPickers) do kp:_input(input, false) end
end)

return library
