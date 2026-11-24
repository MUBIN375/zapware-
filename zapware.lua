--[[
	Zap Public v2.0 (custom menu)
	- Chams: Neon Glow (layered bloom) or plain Highlight, with separate visible / hidden colours
	- Boxes (corner or full), name, distance, health bar + number, held item
	- NEW Camera tab: FOV changer + screen stretch
	- World tab: time changer, skybox presets + custom skybox, colour grading
	- Effects tab: bullet tracers that follow the real bullet, hitmarker
	- Configs tab: save / overwrite / rename / load / delete your settings, auto-load on start
	- Works from the autoexec folder: runs again by itself in every game you join
	Needs an executor with Drawing support for boxes/text/health bars/hitmarker,
	and writefile + readfile + isfile for saving configs (saved in workspace/AdvancedESP/configs/).
]]
 
-- wait for the game (needed when this runs from the autoexec folder)
if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait() until game:GetService("Players").LocalPlayer
repeat task.wait() until workspace.CurrentCamera
 
do -- running the script again (or autoexec + a manual run) replaces the old copy instead of doubling up
	local okG, genv = pcall(function() return getgenv() end)
	if okG and type(genv) == "table" and type(genv.AdvancedESP_Unload) == "function" then
		pcall(genv.AdvancedESP_Unload)
		genv.AdvancedESP_Unload = nil
	end
end
 
local USE_RAYFIELD = false -- set to true to use the old Rayfield menu instead of the new custom menu
local Rayfield -- the menu library, created below
 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
 
local HAS_DRAWING = typeof(Drawing) == "table" or typeof(Drawing) == "userdata"
local function protectedParent()
-- made by: _meht_
	if gethui then return gethui() end
	return game:GetService("CoreGui")
end
 
-- ================================================================ CUSTOM MENU LIBRARY
-- A hand-made menu that replaces Rayfield. It keeps Rayfield's function names (CreateWindow / CreateTab /
-- CreateToggle ...), so the rest of the script works unchanged. Set USE_RAYFIELD = true at the top to go back.
local function buildUILib()
	local TweenService = game:GetService("TweenService")
	local UIS = game:GetService("UserInputService")
	local RS = game:GetService("RunService")
	local Lib = { Theme = {} }
	local FONT, FONT_B = Enum.Font.GothamMedium, Enum.Font.GothamBold
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
 
	-- ------------------------------------------------------------ themes
	local function palette(accent, bg, light)
		local base = light and BLACK or WHITE
		local function sh(f) return bg:Lerp(base, f) end
		return {
			Background = bg,
			Topbar = sh(0.035),
			ElementBackground = sh(0.06),
			ElementBackgroundHover = sh(0.11),
			ElementStroke = sh(0.17),
			TextColor = light and Color3.fromRGB(28, 28, 38) or Color3.fromRGB(236, 236, 246),
			TabTextColor = light and Color3.fromRGB(90, 90, 110) or Color3.fromRGB(150, 150, 172),
			PlaceholderColor = light and Color3.fromRGB(130, 130, 150) or Color3.fromRGB(110, 110, 132),
			ToggleEnabled = accent,
			ToggleDisabled = light and Color3.fromRGB(185, 185, 198) or Color3.fromRGB(64, 64, 82),
			SliderBackground = accent:Lerp(bg, 0.6),
			InputBackground = sh(0.02),
			DropdownSelected = sh(0.14),
		}
	end
	Lib.Theme.Default = palette(Color3.fromRGB(0, 146, 214), Color3.fromRGB(24, 24, 28))
	Lib.Theme.DarkBlue = palette(Color3.fromRGB(50, 138, 220), Color3.fromRGB(15, 19, 30))
	Lib.Theme.Ocean = palette(Color3.fromRGB(40, 190, 210), Color3.fromRGB(12, 25, 31))
	Lib.Theme.Amethyst = palette(Color3.fromRGB(170, 90, 255), Color3.fromRGB(20, 15, 31))
	Lib.Theme.Bloom = palette(Color3.fromRGB(255, 120, 170), Color3.fromRGB(28, 17, 24))
	Lib.Theme.Green = palette(Color3.fromRGB(60, 210, 120), Color3.fromRGB(13, 26, 19))
	Lib.Theme.AmberGlow = palette(Color3.fromRGB(255, 160, 40), Color3.fromRGB(28, 22, 13))
	Lib.Theme.Serenity = palette(Color3.fromRGB(130, 170, 255), Color3.fromRGB(19, 23, 34))
	Lib.Theme.Light = palette(Color3.fromRGB(50, 138, 220), Color3.fromRGB(232, 232, 238), true)
 
	local THEME = {}
	local function resolve(P)
	-- made by: _meht_
		THEME.bg = P.Background or THEME.bg
		THEME.top = P.Topbar or THEME.top
		THEME.elem = P.ElementBackground or THEME.elem
		THEME.hover = P.ElementBackgroundHover or THEME.hover
		THEME.stroke = P.ElementStroke or THEME.stroke
		THEME.text = P.TextColor or THEME.text
		THEME.sub = P.TabTextColor or THEME.sub
		THEME.accent = P.ToggleEnabled or P.SliderProgress or THEME.accent
		THEME.deep = P.SliderBackground or THEME.deep
		THEME.off = P.ToggleDisabled or THEME.off
		THEME.input = P.InputBackground or THEME.input
		THEME.ph = P.PlaceholderColor or THEME.ph
		THEME.sel = P.DropdownSelected or THEME.sel
	end
	resolve(Lib.Theme.Default)
 
	-- ------------------------------------------------------------ helpers
	local bound, refreshers = {}, {}
 
	local function tw(inst, props, t, style, dir)
		if not inst or not inst.Parent then return end
		TweenService:Create(inst, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
	end
	local function bind(inst, prop, key)
		inst[prop] = THEME[key]
		table.insert(bound, { inst, prop, key })
	end
	local function onTheme(fn)
	-- made by: _meht_
		table.insert(refreshers, fn)
		fn(false)
	end
	local DISCORD_LINK = "https://discord.gg/QRG2E5vWhF"
	local function openDiscord()
		local copied = false
		if setclipboard then copied = pcall(setclipboard, DISCORD_LINK) end
		pcall(function() game:GetService("GuiService"):OpenBrowserWindow(DISCORD_LINK) end)
		Lib:Notify({ Title = "Discord", Content = (copied and "Link copied - " or "") .. DISCORD_LINK, Duration = 8 })
	end
	Lib.OpenDiscord = openDiscord
	local function applyTheme()
		for i = #bound, 1, -1 do
			local b = bound[i]
			if b[1].Parent then
				tw(b[1], { [b[2]] = THEME[b[3]] }, 0.25)
			else
				table.remove(bound, i)
			end
		end
		for _, fn in ipairs(refreshers) do pcall(fn, true) end
	end
 
	local function new(class, props, parent)
	-- made by: _meht_
		local i = Instance.new(class)
		for k, v in pairs(props or {}) do i[k] = v end
		if parent then i.Parent = parent end
		return i
	end
	local function corner(inst, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, inst) end
	local function stroke(inst, key, th)
		local s = new("UIStroke", { Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
		bind(s, "Color", key or "stroke")
		return s
	end
	local function pad(inst, l, r, t, b)
		return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
			PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b) }, inst)
	end
	local function label(parent, props, key)
	-- made by: _meht_
		local l = new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0 })
		for k, v in pairs(props) do l[k] = v end
		bind(l, "TextColor3", key or "text")
		l.Parent = parent
		return l
	end
	local function fmtNum(v, suffix)
		local s = string.format("%.3f", v)
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
		if suffix and suffix ~= "" then
			local sfx = string.gsub(suffix, "^%s+", "")
			s = s .. " " .. sfx
		end
		return s
	end
 
	-- one global drag system (sliders, colour picker, moving the window)
	local conns = {}
	local activeDrag = nil
	local function pointer()
		local p = UIS:GetMouseLocation()
		return p.X, p.Y
	end
	local function isPress(input)
	-- made by: _meht_
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	table.insert(conns, UIS.InputChanged:Connect(function(input)
		if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local x, y = pointer()
			activeDrag(x, y)
		end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(input)
		if isPress(input) then activeDrag = nil end
	end))
 
	-- ------------------------------------------------------------ state
	local gui, root, uiscale, notifyHolder
	local userScale, autoScale = 1, 1
	local visible = false
	local notifyCount = 0
 
	local function currentScale() return userScale * autoScale end
 
	function Lib:SetScale(s)
		userScale = math.clamp(tonumber(s) or 1, 0.5, 2)
		if uiscale and visible then tw(uiscale, { Scale = currentScale() }, 0.15) end
	end
 
	function Lib:Destroy()
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		conns = {}
		if gui then pcall(function() gui:Destroy() end) end
		gui = nil
	end
 
	-- ------------------------------------------------------------ notifications
	function Lib:Notify(o)
		if not notifyHolder then return end
		o = o or {}
		notifyCount = notifyCount + 1
		local kids = notifyHolder:GetChildren()
		local count = 0
		for _, k in ipairs(kids) do
			if k:IsA("CanvasGroup") then
				count = count + 1
				if count >= 5 then k:Destroy() end
			end
		end
		local toast = new("CanvasGroup", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0, GroupTransparency = 1, LayoutOrder = notifyCount, BackgroundColor3 = THEME.elem }, notifyHolder)
		corner(toast, 5)
		new("UIStroke", { Color = THEME.stroke, Thickness = 1 }, toast)
		new("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, BackgroundColor3 = THEME.accent }, toast)
		local inner = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 0),
			Size = UDim2.new(1, -3, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, toast)
		pad(inner, 12, 12, 9, 10)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, inner)
		new("TextLabel", { BackgroundTransparency = 1, Font = FONT_B, TextSize = 13, TextColor3 = THEME.text,
			Text = tostring(o.Title or "Notice"), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, inner)
		if o.Content and o.Content ~= "" then
			new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = THEME.sub,
				Text = tostring(o.Content), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, inner)
		end
		tw(toast, { GroupTransparency = 0 }, 0.25)
		task.delay(tonumber(o.Duration) or 4, function()
			if toast.Parent then
				tw(toast, { GroupTransparency = 1 }, 0.3)
				task.wait(0.35)
				pcall(function() toast:Destroy() end)
			end
		end)
	end
 
	-- ------------------------------------------------------------ small drawn icons (no image assets needed)
	local function makeIcon(kind, parent, pos)
		local box = new("Frame", { Position = pos or UDim2.new(), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1 }, parent)
		local parts = {}
		local function outline(w, h, r, th, px, py, rot)
			local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, px or 0, 0.5, py or 0),
				Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, BorderSizePixel = 0, Rotation = rot or 0 }, box)
			corner(f, r)
			local s = new("UIStroke", { Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
			table.insert(parts, { s, "Color" })
			return f
		end
		local function solid(w, h, r, px, py, rot)
		-- made by: _meht_
			local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, px or 0, 0.5, py or 0),
				Size = UDim2.fromOffset(w, h), BorderSizePixel = 0, Rotation = rot or 0 }, box)
			corner(f, r)
			table.insert(parts, { f, "BackgroundColor3" })
			return f
		end
		local function fixedSolid(w, h, r, color, px, py, rot)
			local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, px or 0, 0.5, py or 0),
				Size = UDim2.fromOffset(w, h), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = rot or 0 }, box)
			corner(f, r)
			return f
		end
		if kind == "eye" then
			outline(16, 10, 5, 1.5)
			solid(4, 4, 2)
		elseif kind == "target" then
			outline(14, 14, 7, 1.5)
			solid(4, 4, 2)
		elseif kind == "camera" then
			outline(15, 11, 3, 1.5)
			outline(5, 5, 3, 1.5)
		elseif kind == "user" then
			solid(7, 7, 4, 0, -4)
			solid(13, 6, 3, 0, 5)
		elseif kind == "sun" then
			outline(14, 14, 7, 1.5)
			outline(6, 14, 3, 1.2)
			solid(14, 1.2, 0)
		elseif kind == "sparkles" then
			outline(10, 10, 2, 1.5, 0, 1, 45)
			solid(3, 3, 2, 6, -6)
		elseif kind == "settings" then
			outline(12, 12, 6, 3)
			solid(4, 4, 2)
		elseif kind == "search" then
			outline(10, 10, 5, 1.5, -2, -2)
			solid(6, 1.6, 1, 5, 5, 45)
		elseif kind == "lock" then
			outline(9, 9, 3, 1.5, 0, -2)
			solid(12, 7, 2, 0, 3)
		elseif kind == "bolt" then
			solid(10, 3, 1, -2, -3, -28)
			solid(10, 3, 1, 2, 3, -28)
		elseif kind == "discord" then
			solid(16, 12, 6)
			fixedSolid(4, 5, 2, WHITE, -4, 0)
			fixedSolid(4, 5, 2, WHITE, 4, 0)
		else
			outline(12, 12, 6, 1.5)
		end
		local icon = {}
		function icon.paint(c)
			for _, p in ipairs(parts) do p[1][p[2]] = c end
		end
		return icon
	end

	-- a small "v" arrow
	local function chevron(parent, order)
		local box = new("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, LayoutOrder = order or 1 }, parent)
		for i = 1, 2 do
			local l = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(i == 1 and 0.3 or 0.7, 0, 0.5, 0),
				Size = UDim2.fromOffset(6, 1.6), BorderSizePixel = 0, Rotation = i == 1 and 45 or -45 }, box)
			bind(l, "BackgroundColor3", "sub")
		end
		return box
	end

	-- ------------------------------------------------------------ window
	function Lib:CreateWindow(cfg)
		cfg = cfg or {}
		if type(cfg.Theme) == "table" then
			resolve(cfg.Theme)
		elseif type(cfg.Theme) == "string" and Lib.Theme[cfg.Theme] then
			resolve(Lib.Theme[cfg.Theme])
		end

		gui = new("ScreenGui", { Name = "AE_" .. tostring(math.random(100000, 999999)), ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000, IgnoreGuiInset = true })
		gui.Parent = protectedParent()

		local vp = Workspace.CurrentCamera.ViewportSize
		autoScale = math.min(1, vp.X / 960, vp.Y / 640)

		root = new("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(900, 580), BackgroundTransparency = 1, Visible = false }, gui)
		uiscale = new("UIScale", { Scale = currentScale() * 0.94 }, root)

		local main = new("Frame", { Name = "Main", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 2,
			ClipsDescendants = true }, root)
		bind(main, "BackgroundColor3", "bg")
		corner(main, 12)
		stroke(main, "stroke", 1)

		-- made by: _meht_  (background watermark - faint, tiled, non-interactive, always behind everything else)
		do
			local wmLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1,
				ClipsDescendants = true }, main)
			for row = 0, 5 do
				for col = 0, 3 do
					new("TextLabel", { BackgroundTransparency = 1, Font = FONT_B, TextSize = 22, TextTransparency = 0.94,
						TextColor3 = Color3.new(1, 1, 1), Rotation = -22, Text = "made by _meht_",
						Position = UDim2.new(col * 0.36, -40, row * 0.2, 0), Size = UDim2.fromOffset(260, 30),
						TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 1 }, wmLayer)
				end
			end
		end

		local Window = {}
		local alive = true
		local function setVisible(v)
		-- made by: _meht_
			visible = v
			if v then
				root.Visible = true
				uiscale.Scale = currentScale() * 0.94
				tw(uiscale, { Scale = currentScale() }, 0.22, Enum.EasingStyle.Back)
			else
				tw(uiscale, { Scale = currentScale() * 0.94 }, 0.12)
				task.delay(0.12, function()
					if not visible and root then root.Visible = false end
				end)
			end
		end
		function Window.Toggle() setVisible(not visible) end
		function Window.IsAlive() return alive and gui ~= nil and gui.Parent ~= nil end

		-- ---- header: logo + name + version on the left, pills on the right
		local top = new("Frame", { Name = "Topbar", Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1 }, main)
		local left = new("Frame", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1 }, top)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, left)
		local logo = new("Frame", { Size = UDim2.fromOffset(30, 30), BorderSizePixel = 0, LayoutOrder = 1 }, left)
		bind(logo, "BackgroundColor3", "accent")
		corner(logo, 9)
		local logoDot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, logo)
		corner(logoDot, 6)
		label(left, { Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = tostring(cfg.Name or "Menu"),
			Font = FONT_B, TextSize = 17, LayoutOrder = 2 })
		local verPill = new("Frame", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0,
			LayoutOrder = 3 }, left)
		bind(verPill, "BackgroundColor3", "elem")
		corner(verPill, 6)
		stroke(verPill)
		pad(verPill, 8, 8, 0, 0)
		label(verPill, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = tostring(cfg.Version or "v1"),
			TextSize = 11, Font = FONT_B }, "sub")

		local right = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0.5, 0, 1, 0),
			BackgroundTransparency = 1 }, top)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, right)
		local function pill(parent, text, order, withChevron)
			local p = new("Frame", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0,
				LayoutOrder = order }, parent)
			bind(p, "BackgroundColor3", "elem")
			corner(p, 8)
			stroke(p)
			pad(p, 12, 12, 0, 0)
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, p)
			local l = label(p, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 13, LayoutOrder = 1 })
			if withChevron then chevron(p, 2) end
			return p, l
		end
		local okName, myName = pcall(function() return LocalPlayer.DisplayName end)
		pill(right, okName and tostring(myName) or "Player", 1, false)

		local closeBtn = new("TextButton", { Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "x", Font = FONT_B,
			TextSize = 18, AutoButtonColor = false, LayoutOrder = 2 }, right)
		bind(closeBtn, "TextColor3", "sub")
		corner(closeBtn, 8)
		closeBtn.MouseEnter:Connect(function() tw(closeBtn, { TextColor3 = Color3.fromRGB(240, 80, 90) }, 0.1) end)
		closeBtn.MouseLeave:Connect(function() tw(closeBtn, { TextColor3 = THEME.sub }, 0.1) end)
		closeBtn.MouseButton1Click:Connect(function()
			setVisible(false)
			Lib:Notify({ Title = "Menu hidden", Content = "Press " .. tostring(cfg.ToggleUIKeybind or "K") .. " to show it again.", Duration = 3 })
		end)

		-- drag the window by the header
		top.InputBegan:Connect(function(input)
			if isPress(input) then
				local mx, my = pointer()
				local startPos = root.Position
				activeDrag = function(x, y)
					root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (x - mx), startPos.Y.Scale, startPos.Y.Offset + (y - my))
				end
			end
		end)

		-- ---- body = sidebar card + content
		local body = new("Frame", { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), BackgroundTransparency = 1 }, main)
		local sidebar = new("Frame", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 208, 1, -14), BorderSizePixel = 0 }, body)
		bind(sidebar, "BackgroundColor3", "top")
		corner(sidebar, 12)
		stroke(sidebar)

		local searchBox = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 36), BorderSizePixel = 0 }, sidebar)
		bind(searchBox, "BackgroundColor3", "input")
		corner(searchBox, 9)
		stroke(searchBox)
		local searchIcon = makeIcon("search", searchBox, UDim2.fromOffset(10, 9))
		onTheme(function() searchIcon.paint(THEME.sub) end)
		local search = new("TextBox", { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -44, 1, 0), BackgroundTransparency = 1,
			Font = FONT, TextSize = 13, Text = "", PlaceholderText = "Search", ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0 }, searchBox)
		bind(search, "TextColor3", "text")
		bind(search, "PlaceholderColor3", "ph")

		local tabList = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -120), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, sidebar)
		pad(tabList, 10, 10, 4, 10)
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)
		local discordBtn = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -32),
			Size = UDim2.new(1, -20, 0, 34), BorderSizePixel = 0, Text = "", AutoButtonColor = false }, sidebar)
		bind(discordBtn, "BackgroundColor3", "elem")
		corner(discordBtn, 9)
		stroke(discordBtn)
		makeIcon("discord", discordBtn, UDim2.fromOffset(10, 8)).paint(THEME.accent)
		label(discordBtn, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), Text = "Join Discord",
			Font = FONT_B, TextSize = 13 })
		discordBtn.MouseEnter:Connect(function() tw(discordBtn, { BackgroundColor3 = THEME.hover }, 0.1) end)
		discordBtn.MouseLeave:Connect(function() tw(discordBtn, { BackgroundColor3 = THEME.elem }, 0.1) end)
		discordBtn.MouseButton1Click:Connect(openDiscord)
		label(sidebar, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 18),
			Text = tostring(cfg.ToggleUIKeybind or "K") .. "  =  hide / show", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center }, "sub")

		local content = new("Frame", { Position = UDim2.fromOffset(236, 0), Size = UDim2.new(1, -250, 1, -14), BackgroundTransparency = 1,
			ClipsDescendants = true }, body)

		-- notification stack (bottom right of the screen)
		notifyHolder = new("Frame", { Name = "Notifications", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.fromOffset(300, 500), BackgroundTransparency = 1 }, gui)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8) }, notifyHolder)

		-- keybind
		local keyCode
		if cfg.ToggleUIKeybind then
			local okK, kc = pcall(function() return Enum.KeyCode[cfg.ToggleUIKeybind] end)
			if okK then keyCode = kc end
		end
		table.insert(conns, UIS.InputBegan:Connect(function(input)
			if keyCode and input.KeyCode == keyCode and not UIS:GetFocusedTextBox() then
				Window.Toggle()
			end
		end))

		function Window.ModifyTheme(t)
			if type(t) == "string" then t = Lib.Theme[t] end
			if type(t) == "table" then
				resolve(t)
				applyTheme()
			end
		end

		-- ------------------------------------------------------------ tabs, sub-tabs, search
		local tabs, selectedTab = {}, nil
		local searchQuery = ""

		local function paintAll()
			for _, t in ipairs(tabs) do t.paint() end
		end
		local function selectTab(t)
		-- made by: _meht_
			selectedTab = t
			paintAll()
		end

		local function applySearch()
			searchQuery = string.lower(search.Text or "")
			for _, t in ipairs(tabs) do
				t.hits = 0
				for _, s in ipairs(t.subs) do
					s.hits = 0
					for _, c in ipairs(s.cards) do
						local shown = 0
						for _, e in ipairs(c.rows) do
							local ok = searchQuery == "" or string.find(e.name, searchQuery, 1, true) ~= nil
							e.frame.Visible = ok
							if e.divider then e.divider.Visible = ok and shown > 0 end
							if ok then shown = shown + 1 end
						end
						c.group.Visible = searchQuery == "" or shown > 0
						s.hits = s.hits + shown
					end
					t.hits = t.hits + s.hits
				end
			end
			if searchQuery ~= "" then
				if not selectedTab or selectedTab.hits == 0 then
					for _, t in ipairs(tabs) do
						if t.hits > 0 then selectedTab = t break end
					end
				end
				if selectedTab and selectedTab.sel and selectedTab.sel.hits == 0 then
					for _, s in ipairs(selectedTab.subs) do
						if s.hits > 0 then selectedTab.sel = s break end
					end
				end
			end
			paintAll()
		end
		search:GetPropertyChangedSignal("Text"):Connect(applySearch)

		function Window:CreateTab(name, icon)
			name = tostring(name)
			icon = tostring(icon or "")
			local lockedTab = false
			do
				local base = string.match(icon, "^(.-)%+lock$")
				if base then icon, lockedTab = base, true end
			end
			local Tab = { subs = {}, hits = 0 }
			local order = 0
			local function nextOrder()
				order = order + 1
				return order
			end

			-- sidebar button
			local btn = new("TextButton", { Name = name, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Text = "",
				AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = #tabs + 1 }, tabList)
			corner(btn, 9)
			local ic = makeIcon(icon, btn, UDim2.fromOffset(12, 10))
			if lockedTab then
				local badge = new("Frame", { Position = UDim2.fromOffset(21, 18), Size = UDim2.fromOffset(11, 11),
					BackgroundTransparency = 1 }, btn)
				local badgeBody = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.fromOffset(8, 5), BorderSizePixel = 0 }, badge)
				corner(badgeBody, 1)
				bind(badgeBody, "BackgroundColor3", "accent")
				local badgeShackle = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4),
					Size = UDim2.fromOffset(5, 5), BackgroundTransparency = 1, BorderSizePixel = 0 }, badge)
				corner(badgeShackle, 3)
				local badgeStroke = new("UIStroke", { Thickness = 1.2 }, badgeShackle)
				bind(badgeStroke, "Color", "accent")
			end
			local tl = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -42, 1, 0),
				Text = name, Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }, btn)

			-- page: big title, sub-tab bar, scrolling pages
			local tabPage = new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, content)
			label(tabPage, { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 0, 40), Text = name, Font = FONT_B, TextSize = 26 })
			local subbar = new("Frame", { Position = UDim2.fromOffset(6, 48), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X,
				BorderSizePixel = 0, Visible = false }, tabPage)
			bind(subbar, "BackgroundColor3", "top")
			corner(subbar, 10)
			stroke(subbar)
			pad(subbar, 4, 4, 4, 4)
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, subbar)
			local pages = new("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1 }, tabPage)

			local function layoutTab()
			-- made by: _meht_
				local multi = #Tab.subs > 1
				subbar.Visible = multi
				local topPx = multi and 98 or 52
				pages.Position = UDim2.fromOffset(0, topPx)
				pages.Size = UDim2.new(1, 0, 1, -topPx)
			end

			local function paintSub(s)
				local sel = (Tab.sel == s)
				local dim = searchQuery ~= "" and s.hits == 0
				s.btn.BackgroundColor3 = THEME.hover
				tw(s.btn, { BackgroundTransparency = sel and 0 or 1 }, 0.15)
				tw(s.lbl, { TextColor3 = sel and THEME.text or (dim and THEME.ph or THEME.sub) }, 0.15)
				s.page.Visible = sel
			end

			function Tab.paint()
				local sel = (selectedTab == Tab)
				local dim = searchQuery ~= "" and Tab.hits == 0
				btn.BackgroundColor3 = THEME.hover
				tw(btn, { BackgroundTransparency = sel and 0 or 1 }, 0.15)
				tw(tl, { TextColor3 = sel and THEME.text or (dim and THEME.ph or THEME.sub) }, 0.15)
				ic.paint(sel and THEME.accent or (dim and THEME.ph or THEME.sub))
				tl.Font = sel and FONT_B or FONT
				tabPage.Visible = sel
				for _, s in ipairs(Tab.subs) do paintSub(s) end
			end
			btn.MouseEnter:Connect(function()
				if selectedTab ~= Tab then
					btn.BackgroundColor3 = THEME.hover
					tw(btn, { BackgroundTransparency = 0.5 }, 0.1)
				end
			end)
			btn.MouseLeave:Connect(function()
				if selectedTab ~= Tab then tw(btn, { BackgroundTransparency = 1 }, 0.1) end
			end)
			btn.MouseButton1Click:Connect(function() selectTab(Tab) end)
			table.insert(tabs, Tab)
			onTheme(function() Tab.paint() end)
			if not selectedTab then selectedTab = Tab end

			-- sub-tabs (each one is its own two-column page)
			local function makeSub(subName, implicit)
				local s = { name = subName, implicit = implicit, cards = {}, heights = { 0, 0 }, order = 0, hits = 0 }
				local page = new("ScrollingFrame", { Name = subName, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
					ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false }, pages)
				bind(page, "ScrollBarImageColor3", "accent")
				pad(page, 6, 12, 6, 18)
				local cols = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, page)
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, cols)
				s.columns = {}
				for i = 1, 2 do
					local col = new("Frame", { Size = UDim2.new(0.5, -7, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
						LayoutOrder = i }, cols)
					new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) }, col)
					s.columns[i] = col
				end
				s.page = page
				local b = new("TextButton", { Name = subName, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = #Tab.subs + 1 }, subbar)
				corner(b, 8)
				pad(b, 16, 16, 0, 0)
				s.btn = b
				s.lbl = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
					Font = FONT, TextSize = 13, Text = subName, BorderSizePixel = 0 }, b)
				b.MouseButton1Click:Connect(function()
					Tab.sel = s
					paintAll()
				end)
				table.insert(Tab.subs, s)
				if not Tab.sel then Tab.sel = s end
				layoutTab()
				paintSub(s)
				return s
			end

			local function curSub()
			-- made by: _meht_
				if not Tab.cur then Tab.cur = makeSub(name, true) end
				return Tab.cur
			end

			function Tab:CreateSubTab(subName)
				local c = Tab.cur
				if c and c.implicit and #c.cards == 0 then
					for i, s in ipairs(Tab.subs) do
						if s == c then table.remove(Tab.subs, i) break end
					end
					pcall(function() c.page:Destroy() c.btn:Destroy() end)
					if Tab.sel == c then Tab.sel = nil end
					Tab.cur = nil
				end
				Tab.cur = makeSub(tostring(subName), false)
				if not Tab.sel then Tab.sel = Tab.cur end
				layoutTab()
				return {}
			end

			-- a titled card (group of rows); goes in whichever column is shorter so far
			local function newCard(s, title)
				local col = (s.heights[1] <= s.heights[2]) and 1 or 2
				s.order = s.order + 1
				local group = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
					LayoutOrder = s.order }, s.columns[col])
				new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, group)
				if title then
					local t = label(group, { Size = UDim2.new(1, 0, 0, 16), Text = tostring(title), TextSize = 12, Font = FONT_B, LayoutOrder = 1 }, "sub")
					pad(t, 4, 0, 0, 0)
				end
				local bodyF = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = 2 }, group)
				bind(bodyF, "BackgroundColor3", "top")
				corner(bodyF, 10)
				stroke(bodyF)
				pad(bodyF, 0, 0, 3, 3)
				new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, bodyF)
				local c = { group = group, body = bodyF, col = col, rows = {} }
				s.heights[col] = s.heights[col] + (title and 26 or 0) + 14
				table.insert(s.cards, c)
				s.card = c
				return c
			end

			-- one row inside the current card (with a thin divider above it, except the first)
			local function newRow(rowName, h, auto)
				local s = curSub()
				local c = s.card or newCard(s, nil)
				local lo = nextOrder()
				local dv
				if #c.rows > 0 then
					dv = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 1, LayoutOrder = lo }, c.body)
					local line = new("Frame", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BorderSizePixel = 0 }, dv)
					bind(line, "BackgroundColor3", "stroke")
					lo = nextOrder()
				end
				local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = lo,
					AutomaticSize = auto and Enum.AutomaticSize.Y or Enum.AutomaticSize.None }, c.body)
				table.insert(c.rows, { frame = f, divider = dv, name = string.lower(tostring(rowName or "")) })
				s.heights[c.col] = s.heights[c.col] + h + 1
				return f
			end

			local function callback(fn, ...)
			-- made by: _meht_
				if not fn then return end
				local ok, err = pcall(fn, ...)
				if not ok then warn("[Menu] callback error: " .. tostring(err)) end
			end
			local function rowLabel(f, text, width, y, h)
				return label(f, { Position = UDim2.fromOffset(14, y or 0), Size = width or UDim2.new(1, -28, h or 1, h and 0 or 0),
					Text = text, TextTruncate = Enum.TextTruncate.AtEnd })
			end
			local function pillBox(parent, props)
				local p = new("Frame", props, parent)
				bind(p, "BackgroundColor3", "input")
				corner(p, 7)
				stroke(p)
				return p
			end

			function Tab:CreateSection(text)
				newCard(curSub(), text)
				return {}
			end

			function Tab:CreateLabel(text)
				local f = newRow(text, 30, true)
				local inner = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, f)
				pad(inner, 14, 14, 8, 8)
				local l = label(inner, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(text),
					TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top }, "sub")
				return { Set = function(_, t) l.Text = tostring(t) end }
			end

			function Tab:CreateParagraph(o)
				local f = newRow((o.Title or "") .. " " .. (o.Content or ""), 40, true)
				local inner = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, f)
				pad(inner, 14, 14, 10, 10)
				new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, inner)
				label(inner, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(o.Title or ""),
					Font = FONT_B, TextWrapped = true, LayoutOrder = 1 })
				label(inner, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(o.Content or ""),
					TextSize = 12, TextWrapped = true, LayoutOrder = 2, TextYAlignment = Enum.TextYAlignment.Top }, "sub")
				return {}
			end

			function Tab:CreateButton(o)
				local name = tostring(o.Name or "Button")
				local f = newRow(name, 38)
				if o.Icon then
					makeIcon(o.Icon, f, UDim2.fromOffset(12, 10)).paint(THEME.accent)
					rowLabel(f, name, UDim2.new(1, -120, 1, 0), 0, 1).Position = UDim2.fromOffset(38, 0)
				else
					rowLabel(f, name, UDim2.new(1, -92, 1, 0))
				end
				local chip = pillBox(f, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(56, 24),
					BorderSizePixel = 0 })
				label(chip, { Size = UDim2.fromScale(1, 1), Text = "Run", TextSize = 12, Font = FONT_B, TextXAlignment = Enum.TextXAlignment.Center }, "sub")
				local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3 }, f)
				hit.MouseButton1Click:Connect(function()
					chip.BackgroundColor3 = THEME.accent
					tw(chip, { BackgroundColor3 = THEME.input }, 0.4)
					callback(o.Callback)
				end)
				return {}
			end

			function Tab:CreateToggle(o)
				local name = tostring(o.Name or "Toggle")
				local f = newRow(name, 38)
				rowLabel(f, name, UDim2.new(1, (o.Locked and -96 or -72), 1, 0))
				if o.Locked then
					local lockWrap = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -56, 0.5, 0),
						Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1 }, f)
					local lockIcon = makeIcon("lock", lockWrap, UDim2.fromScale(-0.11, -0.11))
					lockIcon.paint(THEME.sub)
					onTheme(function() lockIcon.paint(THEME.sub) end)
				end
				local track = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
					Size = UDim2.fromOffset(36, 20), BorderSizePixel = 0 }, f)
				corner(track, 10)
				local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
					Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, track)
				corner(knob, 7)
				local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3 }, f)
				local obj = { Type = "Toggle", CurrentValue = o.CurrentValue and true or false }
				local function paint(animate)
				-- made by: _meht_
					local on = obj.CurrentValue
					local col = on and THEME.accent or THEME.off
					local pos = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
					if animate then
						tw(track, { BackgroundColor3 = col }, 0.18)
						tw(knob, { Position = pos }, 0.18)
					else
						track.BackgroundColor3 = col
						knob.Position = pos
					end
				end
				function obj:Set(v)
					self.CurrentValue = v and true or false
					paint(true)
					callback(o.Callback, self.CurrentValue)
				end
				if o.Locked then
					hit.MouseButton1Click:Connect(function()
						obj.CurrentValue = true
						paint(true)
						Lib:Notify({ Title = "Zap Private", Content = "\"" .. name .. "\" is a Private-only feature.", Duration = 4 })
						task.delay(0.2, function() obj.CurrentValue = false paint(true) end)
					end)
				else
					hit.MouseButton1Click:Connect(function() obj:Set(not obj.CurrentValue) end)
				end
				onTheme(paint)
				return obj
			end

			function Tab:CreateSlider(o)
				local name = tostring(o.Name or "Slider")
				local lo, hi = o.Range[1], o.Range[2]
				local inc = o.Increment or 1
				local stacked = #name > 20
				local f = newRow(name, stacked and 56 or 38)
				if stacked then
					rowLabel(f, name, UDim2.new(1, -100, 0, 18), 8, 18)
				else
					rowLabel(f, name, UDim2.new(0.4, -14, 1, 0))
				end
				local valLbl = label(f, { AnchorPoint = Vector2.new(1, 0),
					Position = stacked and UDim2.new(1, -14, 0, 8) or UDim2.new(1, -14, 0.5, -8),
					Size = UDim2.fromOffset(stacked and 80 or 54, 16), TextXAlignment = Enum.TextXAlignment.Right, Font = FONT_B, TextSize = 12 }, "sub")
				local track = new("Frame", { Position = stacked and UDim2.fromOffset(14, 38) or UDim2.new(0.4, 0, 0.5, -2),
					Size = stacked and UDim2.new(1, -28, 0, 4) or UDim2.new(0.6, -78, 0, 4), BorderSizePixel = 0 }, f)
				bind(track, "BackgroundColor3", "off")
				corner(track, 2)
				local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
				bind(fill, "BackgroundColor3", "accent")
				corner(fill, 2)
				local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(11, 11),
					BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3 }, track)
				corner(knob, 6)
				local hit = new("TextButton", { Position = stacked and UDim2.fromOffset(0, 28) or UDim2.new(0.4, -6, 0, 0),
					Size = stacked and UDim2.new(1, 0, 0, 28) or UDim2.new(0.6, -66, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 4 }, f)

				local function snap(v)
					v = math.clamp(v, lo, hi)
					v = math.floor((v - lo) / inc + 0.5) * inc + lo
					v = math.clamp(v, lo, hi)
					return tonumber(string.format("%.4f", v))
				end
				local obj = { Type = "Slider", CurrentValue = snap(tonumber(o.CurrentValue) or lo) }
				local function paint()
					local frac = math.clamp((obj.CurrentValue - lo) / (hi - lo), 0, 1)
					fill.Size = UDim2.fromScale(frac, 1)
					knob.Position = UDim2.fromScale(frac, 0.5)
					valLbl.Text = fmtNum(obj.CurrentValue, o.Suffix)
				end
				function obj:Set(v)
					v = snap(tonumber(v) or lo)
					local changed = (v ~= self.CurrentValue)
					self.CurrentValue = v
					paint()
					if changed then callback(o.Callback, v) end
				end
				hit.InputBegan:Connect(function(input)
					if isPress(input) then
						local function upd(x)
						-- made by: _meht_
							local frac = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
							obj:Set(lo + frac * (hi - lo))
						end
						local x = pointer()
						upd(x)
						activeDrag = upd
					end
				end)
				paint()
				return obj
			end

			function Tab:CreateDropdown(o)
				local name = tostring(o.Name or "Dropdown")
				local multi = o.MultipleOptions and true or false
				local options = o.Options or {}
				local obj = { Type = "Dropdown", CurrentOption = {} }
				local function norm(v)
					if type(v) == "string" then return { v } end
					if type(v) ~= "table" then return {} end
					local r = {}
					for _, x in ipairs(v) do table.insert(r, tostring(x)) end
					return r
				end
				obj.CurrentOption = norm(o.CurrentOption)
				local function has(n)
					for _, x in ipairs(obj.CurrentOption) do
						if x == n then return true end
					end
					return false
				end
				local function copy()
				-- made by: _meht_
					local r = {}
					for _, x in ipairs(obj.CurrentOption) do table.insert(r, x) end
					return r
				end

				local stacked = #name > 18
				local headH = stacked and 66 or 38
				local f = newRow(name, headH, true)
				new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, f)
				local head = new("TextButton", { Size = UDim2.new(1, 0, 0, headH), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
					LayoutOrder = 1 }, f)
				if stacked then
					rowLabel(head, name, UDim2.new(1, -28, 0, 18), 8, 18)
				else
					rowLabel(head, name, UDim2.new(0.5, -14, 1, 0))
				end
				local box = pillBox(head, stacked and { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 26), BorderSizePixel = 0 }
					or { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0.5, -14, 0, 26), BorderSizePixel = 0 })
				local valLbl = label(box, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
					TextSize = 12 })
				local arrow = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(10, 10),
					BackgroundTransparency = 1 }, box)
				do
					local c = chevron(arrow, 1)
					c.Size = UDim2.fromScale(1, 1)
				end
				local optBox = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
					Visible = false, LayoutOrder = 2 }, f)
				pad(optBox, 8, 8, 0, 8)
				new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, optBox)

				local open = false
				local pick, refresh
				local function setOpen(v)
					open = v
					optBox.Visible = v
					tw(arrow, { Rotation = v and 180 or 0 }, 0.15)
				end
				local function buildOptions()
					for _, c in ipairs(optBox:GetChildren()) do
						if c:IsA("TextButton") then c:Destroy() end
					end
					for i, optName in ipairs(options) do
						local sel = has(optName)
						local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 28), Text = "", AutoButtonColor = false, BorderSizePixel = 0,
							LayoutOrder = i, BackgroundTransparency = sel and 0.8 or 1,
							BackgroundColor3 = sel and THEME.accent or THEME.hover }, optBox)
						corner(b, 6)
						new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
							Font = sel and FONT_B or FONT, TextSize = 12, Text = tostring(optName), TextXAlignment = Enum.TextXAlignment.Left,
							TextColor3 = sel and THEME.accent or THEME.text }, b)
						b.MouseEnter:Connect(function()
							if not has(optName) then
								b.BackgroundColor3 = THEME.hover
								tw(b, { BackgroundTransparency = 0.3 }, 0.1)
							end
						end)
						b.MouseLeave:Connect(function()
							if not has(optName) then tw(b, { BackgroundTransparency = 1 }, 0.1) end
						end)
						b.MouseButton1Click:Connect(function() pick(optName) end)
					end
				end
				refresh = function()
					valLbl.Text = (#obj.CurrentOption == 0) and "None" or table.concat(obj.CurrentOption, ", ")
					buildOptions()
				end
				pick = function(optName)
					if multi then
						local idx = nil
						for i, x in ipairs(obj.CurrentOption) do
							if x == optName then idx = i end
						end
						if idx then table.remove(obj.CurrentOption, idx) else table.insert(obj.CurrentOption, optName) end
					else
						obj.CurrentOption = { optName }
						setOpen(false)
					end
					refresh()
					callback(o.Callback, copy())
				end
				function obj:Set(v)
					self.CurrentOption = norm(v)
					refresh()
					callback(o.Callback, copy())
				end
				function obj:Refresh(list)
					options = list or {}
					refresh()
				end
				head.MouseButton1Click:Connect(function() setOpen(not open) end)
				onTheme(function() refresh() end)
				return obj
			end

			function Tab:CreateColorPicker(o)
				local name = tostring(o.Name or "Colour")
				local f = newRow(name, 38, true)
				new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, f)
				local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
					LayoutOrder = 1 }, f)
				rowLabel(head, name, UDim2.new(1, -80, 1, 0))
				local swatch = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
					Size = UDim2.fromOffset(36, 20), BorderSizePixel = 0 }, head)
				corner(swatch, 6)
				stroke(swatch)
				local panel = new("Frame", { Size = UDim2.new(1, 0, 0, 160), BackgroundTransparency = 1, Visible = false, LayoutOrder = 2 }, f)

				local sv = new("Frame", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -56, 0, 112), BorderSizePixel = 0 }, panel)
				corner(sv, 6)
				local whiteL = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, sv)
				corner(whiteL, 6)
				new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, whiteL)
				local blackL = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0 }, sv)
				corner(blackL, 6)
				new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, blackL)
				local cursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
					BorderSizePixel = 0, ZIndex = 3 }, sv)
				corner(cursor, 6)
				new("UIStroke", { Color = WHITE, Thickness = 2 }, cursor)
				local svHit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4 }, sv)

				local hue = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 6), Size = UDim2.fromOffset(18, 112),
					BorderSizePixel = 0, BackgroundColor3 = WHITE }, panel)
				corner(hue, 6)
				new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
				}) }, hue)
				local hueCur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = WHITE,
					BorderSizePixel = 0, ZIndex = 3 }, hue)
				corner(hueCur, 2)
				new("UIStroke", { Color = BLACK, Thickness = 1 }, hueCur)
				local hueHit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4 }, hue)

				local hex = new("TextBox", { Position = UDim2.fromOffset(14, 126), Size = UDim2.fromOffset(110, 26), Font = FONT, TextSize = 13,
					PlaceholderText = "#RRGGBB", ClearTextOnFocus = false, Text = "", BorderSizePixel = 0 }, panel)
				bind(hex, "BackgroundColor3", "input")
				bind(hex, "TextColor3", "text")
				bind(hex, "PlaceholderColor3", "ph")
				corner(hex, 7)
				stroke(hex)
				local rgbLbl = label(panel, { Position = UDim2.fromOffset(134, 131), Size = UDim2.new(1, -150, 0, 16), TextSize = 12 }, "sub")

				local obj = { Type = "ColorPicker", Color = o.Color or WHITE }
				local h, s, v = obj.Color:ToHSV()
				local function paint()
				-- made by: _meht_
					local c = Color3.fromHSV(h, s, v)
					obj.Color = c
					swatch.BackgroundColor3 = c
					sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
					cursor.Position = UDim2.fromScale(s, 1 - v)
					hueCur.Position = UDim2.fromScale(0.5, h)
					local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
					hex.Text = string.format("#%02X%02X%02X", r, g, b)
					rgbLbl.Text = r .. ", " .. g .. ", " .. b
				end
				local function fire() callback(o.Callback, obj.Color) end
				function obj:Set(c)
					if typeof(c) ~= "Color3" then return end
					h, s, v = c:ToHSV()
					paint()
					fire()
				end
				svHit.InputBegan:Connect(function(input)
					if isPress(input) then
						local function upd(x, y)
							s = math.clamp((x - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
							v = 1 - math.clamp((y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
							paint()
							fire()
						end
						local x, y = pointer()
						upd(x, y)
						activeDrag = upd
					end
				end)
				hueHit.InputBegan:Connect(function(input)
					if isPress(input) then
						local function upd(_, y)
							h = math.clamp((y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 0.999)
							paint()
							fire()
						end
						local x, y = pointer()
						upd(x, y)
						activeDrag = upd
					end
				end)
				hex.FocusLost:Connect(function()
					local r, g, b = string.match(hex.Text, "^#?(%x%x)(%x%x)(%x%x)$")
					if r then
						obj:Set(Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)))
					else
						paint()
					end
				end)
				head.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)
				paint()
				return obj
			end

			function Tab:CreateInput(o)
				local name = tostring(o.Name or "Input")
				local stacked = #name > 18
				local f = newRow(name, stacked and 66 or 38)
				if stacked then
					rowLabel(f, name, UDim2.new(1, -28, 0, 18), 8, 18)
				else
					rowLabel(f, name, UDim2.new(0.5, -14, 1, 0))
				end
				local boxF = pillBox(f, stacked and { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 26), BorderSizePixel = 0 }
					or { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0.5, -14, 0, 26), BorderSizePixel = 0 })
				local box = new("TextBox", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1,
					Font = FONT, TextSize = 12, Text = tostring(o.CurrentValue or ""), PlaceholderText = tostring(o.PlaceholderText or ""),
					ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd }, boxF)
				bind(box, "TextColor3", "text")
				bind(box, "PlaceholderColor3", "ph")
				local obj = { Type = "Input", CurrentValue = box.Text }
				function obj:Set(t)
					t = tostring(t or "")
					self.CurrentValue = t
					box.Text = t
					callback(o.Callback, t)
				end
				box.FocusLost:Connect(function()
					obj.CurrentValue = box.Text
					callback(o.Callback, box.Text)
					if o.RemoveTextAfterFocusLost then box.Text = "" end
				end)
				return obj
			end

			return Tab
		end

		-- opening animation
		task.defer(function() setVisible(true) end)
		return Window
	end

	return Lib
end


if USE_RAYFIELD then
	Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
else
	Rayfield = buildUILib()
end
 
-- ---------------------------------------------------------------- settings
local S = {
	Enabled = false,
	TeamCheck = false,
	NPCs = false,
	NpcFilter = "", -- only show NPCs whose name contains this (empty = all)
	NpcVisibleColor = Color3.fromRGB(255, 170, 40),
	NpcHiddenColor = Color3.fromRGB(60, 200, 255),
	MaxDistance = 1500,
 
	Boxes = true,
	BoxStyle = "Corner",
	BoxColor = Color3.fromRGB(255, 255, 255),
 
	Names = true,
	NameColor = Color3.fromRGB(255, 255, 255),
	Distance = true,
	HeldItem = false,
	TextSize = 13,
 
	HealthBar = true,
	HealthNumber = false,
 
}
 
-- ---------------------------------------------------------------- helpers
local function newDrawing(class, props)
-- made by: _meht_
	if not HAS_DRAWING then return nil end
	local ok, obj = pcall(Drawing.new, class)
	if not ok then return nil end
	for k, v in pairs(props or {}) do obj[k] = v end
	return obj
end
 
local function setVisible(list, state)
	for _, d in pairs(list) do
		if d then d.Visible = state end
	end
end
 
local function removeAll(list)
	for _, d in pairs(list) do
		if d then pcall(function() d:Remove() end) end
	end
end
 
local function isEnemy(player)
-- made by: _meht_
	if not S.TeamCheck then return true end
	if player.Team and LocalPlayer.Team then
		return player.Team ~= LocalPlayer.Team
	end
	return player.TeamColor ~= LocalPlayer.TeamColor
end
 
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
 
local function isVisible(character, targetPart)
	local origin = Camera.CFrame.Position
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character, character, Camera }
	local result = Workspace:Raycast(origin, targetPart.Position - origin, rayParams)
	return result == nil
end
 
local function getHeldItem(character)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then return tool.Name end
	-- some games keep the equipped weapon as a value/attribute
	local attr = character:GetAttribute("EquippedWeapon") or character:GetAttribute("Weapon")
	return attr and tostring(attr) or nil
end
 
-- projects the character's bounding box to a 2D rectangle
local function getBox(character)
-- made by: _meht_
	local cf, size = character:GetBoundingBox()
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local onScreen = false
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner = cf * CFrame.new(size.X / 2 * x, size.Y / 2 * y, size.Z / 2 * z)
				local pos, vis = Camera:WorldToViewportPoint(corner.Position)
				if pos.Z > 0 then
					onScreen = onScreen or vis
					minX, minY = math.min(minX, pos.X), math.min(minY, pos.Y)
					maxX, maxY = math.max(maxX, pos.X), math.max(maxY, pos.Y)
				end
			end
		end
	end
	if not onScreen or minX == math.huge then return nil end
	return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end
 
local function healthColor(pct)
	return Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), math.clamp(pct, 0, 1))
end
 
-- ---------------------------------------------------------------- per-player objects
local objects = {}
local chamsFolder = Instance.new("Folder")
chamsFolder.Name = "ESPChams"
chamsFolder.Parent = protectedParent()
 
local function createObjects(player)
	if objects[player] or player == LocalPlayer then return end
	local o = { drawings = {} }
 
	local d = o.drawings
	d.boxOutline = newDrawing("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), ZIndex = 1 })
	d.box = newDrawing("Square", { Thickness = 1, Filled = false, ZIndex = 2 })
	d.corners = {}
	for i = 1, 8 do
		d.corners[i] = newDrawing("Line", { Thickness = 1, ZIndex = 2 })
	end
	d.name = newDrawing("Text", { Center = true, Outline = true, Font = 2, ZIndex = 3 })
	d.info = newDrawing("Text", { Center = true, Outline = true, Font = 2, ZIndex = 3 })
	d.hpBack = newDrawing("Line", { Thickness = 4, Color = Color3.new(0, 0, 0), ZIndex = 1 })
	d.hpBar = newDrawing("Line", { Thickness = 2, ZIndex = 2 })
	d.hpText = newDrawing("Text", { Center = false, Outline = true, Font = 2, ZIndex = 3 })
 
	objects[player] = o
end
 
local function hideObjects(o)
-- made by: _meht_
	local d = o.drawings
	for key, v in pairs(d) do
		if key == "corners" then
			for _, l in ipairs(v) do if l then l.Visible = false end end
		elseif v then
			v.Visible = false
		end
	end
end
 
local function destroyObjects(player)
	local o = objects[player]
	if not o then return end
	for key, v in pairs(o.drawings) do
		if key == "corners" then removeAll(v) elseif v then pcall(function() v:Remove() end) end
	end
	objects[player] = nil
end
 
-- ---------------------------------------------------------------- render
local function drawCorners(o, pos, size, color)
	local c = o.drawings.corners
	local len = math.max(math.min(size.X, size.Y) * 0.25, 4)
	local tl, tr = pos, pos + Vector2.new(size.X, 0)
	local bl, br = pos + Vector2.new(0, size.Y), pos + size
	local segs = {
		{ tl, tl + Vector2.new(len, 0) }, { tl, tl + Vector2.new(0, len) },
		{ tr, tr - Vector2.new(len, 0) }, { tr, tr + Vector2.new(0, len) },
		{ bl, bl + Vector2.new(len, 0) }, { bl, bl - Vector2.new(0, len) },
		{ br, br - Vector2.new(len, 0) }, { br, br - Vector2.new(0, len) },
	}
	for i = 1, 8 do
		local l = c[i]
		if l then
			l.From, l.To, l.Color, l.Visible = segs[i][1], segs[i][2], color, true
		end
	end
end
 
local function update()
-- made by: _meht_
	Camera = Workspace.CurrentCamera
	local vp = Camera.ViewportSize
	local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
 
	for player, o in pairs(objects) do
		local isNpc = player:IsA("Model")
		if isNpc and not player:IsDescendantOf(Workspace) then
			destroyObjects(player)
			continue
		end
		local char = isNpc and player or player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
		local head = char and char:FindFirstChild("Head")
 
		local dist = (root and localRoot) and (root.Position - localRoot.Position).Magnitude or 0
		local allowed
		if isNpc then
			allowed = S.NPCs and (S.NpcFilter == ""
				or string.find(string.lower(player.Name), string.lower(S.NpcFilter), 1, true) ~= nil)
		else
			allowed = isEnemy(player)
		end
		local valid = S.Enabled and char and hum and root and hum.Health > 0
			and allowed and dist <= S.MaxDistance
 
		if not valid then
			hideObjects(o)
		else
			local d = o.drawings
 

			-- 2D stuff
			local pos, size = getBox(char)
			if not pos then
				for key, v in pairs(d) do
					if key == "corners" then
						for _, l in ipairs(v) do if l then l.Visible = false end end
					elseif v then
						v.Visible = false
					end
				end
			else
				local boxColor = S.BoxColor
 
				-- box
				if S.Boxes and d.box then
					if S.BoxStyle == "Full" then
						for _, l in ipairs(d.corners) do if l then l.Visible = false end end
						d.boxOutline.Position, d.boxOutline.Size, d.boxOutline.Visible = pos, size, true
						d.box.Position, d.box.Size, d.box.Color, d.box.Visible = pos, size, boxColor, true
					else
						d.boxOutline.Visible, d.box.Visible = false, false
						drawCorners(o, pos, size, boxColor)
					end
				else
					if d.box then d.box.Visible, d.boxOutline.Visible = false, false end
					for _, l in ipairs(d.corners) do if l then l.Visible = false end end
				end
 
				-- name
				if S.Names and d.name then
					if isNpc then
						d.name.Text = player.Name
					else
						d.name.Text = player.DisplayName ~= player.Name
							and (player.DisplayName .. " (@" .. player.Name .. ")") or player.Name
					end
					d.name.Size = S.TextSize
					d.name.Color = S.NameColor
					d.name.Position = Vector2.new(pos.X + size.X / 2, pos.Y - S.TextSize - 3)
					d.name.Visible = true
				elseif d.name then
					d.name.Visible = false
				end
 
				-- distance + held item under the box
				if d.info then
					local parts = {}
					if S.Distance then table.insert(parts, math.floor(dist) .. "m") end
					if S.HeldItem then
						local item = getHeldItem(char)
						if item then table.insert(parts, item) end
					end
					if #parts > 0 then
						d.info.Text = table.concat(parts, " | ")
						d.info.Size = S.TextSize
						d.info.Color = S.NameColor
						d.info.Position = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y + 2)
						d.info.Visible = true
					else
						d.info.Visible = false
					end
				end
 
				-- health bar
				if S.HealthBar and d.hpBar then
					local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					local x = pos.X - 5
					d.hpBack.From, d.hpBack.To = Vector2.new(x, pos.Y + size.Y + 1), Vector2.new(x, pos.Y - 1)
					d.hpBar.From = Vector2.new(x, pos.Y + size.Y)
					d.hpBar.To = Vector2.new(x, pos.Y + size.Y - size.Y * pct)
					d.hpBar.Color = healthColor(pct)
					d.hpBack.Visible, d.hpBar.Visible = true, true
					if S.HealthNumber and d.hpText then
						d.hpText.Text = tostring(math.floor(hum.Health))
						d.hpText.Size = S.TextSize - 2
						d.hpText.Color = Color3.new(1, 1, 1)
						d.hpText.Position = Vector2.new(x - 22, d.hpBar.To.Y - 6)
						d.hpText.Visible = true
					elseif d.hpText then
						d.hpText.Visible = false
					end
				elseif d.hpBar then
					d.hpBar.Visible, d.hpBack.Visible, d.hpText.Visible = false, false, false
				end
 
			end
		end
	end
end
 
-- ---------------------------------------------------------------- lifecycle
local connections = {}
local function track(c) table.insert(connections, c) end
 
for _, p in ipairs(Players:GetPlayers()) do createObjects(p) end
track(Players.PlayerAdded:Connect(createObjects))
track(Players.PlayerRemoving:Connect(destroyObjects))
track(RunService.RenderStepped:Connect(function()
	local ok, err = pcall(update)
	if not ok then warn("ESP error: " .. tostring(err)) end
end))
 
-- ---------------------------------------------------------------- NPCs / bots
-- Any Model with a Humanoid that is not a player's character counts as an NPC.
local npcConn
local function addNpc(humanoid)
	local model = humanoid.Parent
	if model and model:IsA("Model") and model ~= LocalPlayer.Character
		and not Players:GetPlayerFromCharacter(model) then
		createObjects(model)
	end
end
 
local function enableNpcs()
	if npcConn then return end
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Humanoid") then addNpc(d) end
	end
	npcConn = Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Humanoid") then task.defer(addNpc, d) end
	end)
end
 
local function disableNpcs()
-- made by: _meht_
	if npcConn then npcConn:Disconnect() npcConn = nil end
	for key in pairs(objects) do
		if key:IsA("Model") then destroyObjects(key) end
	end
end
 
-- ---------------------------------------------------------------- services for the new features
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
 
-- ================================================================ WORLD (time / skybox / grading)
local W = {
	Time = false, ClockTime = 14,
	Bright = false, BrightValue = 2,
	Grade = false, Tint = Color3.fromRGB(255, 255, 255), Saturation = 0, Contrast = 0,
	Sky = "Default", Stars = 3000, CustomIds = "",
}
local worldOrig = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness }
local savedSkies = {}          -- the game's own Sky objects, stashed while ours is active
local ourSky, ourCC, ourAtmo   -- instances we created
local atmoTarget, atmoSaved    -- the game's Atmosphere + its original values
local timeToggle, timeSlider, gradeToggle, tintPick, satSlider, conSlider, brightToggle -- UI refs (set later)
 
local SKY_FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
 
local SKY_PRESETS = {
	["Night Sky"]  = { time = 0, stars = 5000, bodies = true },
	["Space"]      = { time = 0, blank = true, stars = 9000, bodies = false, atmo = { density = 0 } },
	["Void"]       = { time = 0, blank = true, stars = 0, bodies = false, atmo = { density = 0 } },
	["Sunset"]     = { time = 17.7, stars = 3000, bodies = true,
		atmo = { color = Color3.fromRGB(255, 170, 100), decay = Color3.fromRGB(255, 110, 60), density = 0.35, haze = 1.5 },
		tint = Color3.fromRGB(255, 215, 175), sat = 0.15 },
	["Sunrise"]    = { time = 6.1, stars = 3000, bodies = true,
		atmo = { color = Color3.fromRGB(255, 190, 170), decay = Color3.fromRGB(255, 140, 120), density = 0.3, haze = 1.2 },
		tint = Color3.fromRGB(255, 230, 215), sat = 0.1 },
	["Pink Dream"] = { time = 17.9, stars = 6000, bodies = true,
		atmo = { color = Color3.fromRGB(255, 150, 220), decay = Color3.fromRGB(200, 80, 180), density = 0.4, haze = 2 },
		tint = Color3.fromRGB(255, 200, 245), sat = 0.25 },
	["Toxic Green"] = { time = 21, stars = 6000, bodies = true,
		atmo = { color = Color3.fromRGB(120, 255, 140), decay = Color3.fromRGB(40, 160, 70), density = 0.4, haze = 2 },
		tint = Color3.fromRGB(205, 255, 215), sat = 0.2 },
}
local SKY_LIST = { "Default", "Night Sky", "Space", "Void", "Sunset", "Sunrise", "Pink Dream", "Toxic Green", "Custom" }
 
local function removeOurSky()
	if ourSky then pcall(function() ourSky:Destroy() end) ourSky = nil end
	for _, s in ipairs(savedSkies) do
		if s then pcall(function() s.Parent = Lighting end) end
	end
	savedSkies = {}
end
 
local function stashSkies()
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Sky") and c ~= ourSky then
			table.insert(savedSkies, c)
			c.Parent = nil
		end
	end
end
 
local function getAtmo()
-- made by: _meht_
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a and a ~= ourAtmo and not atmoSaved then
		atmoTarget = a
		atmoSaved = { Color = a.Color, Decay = a.Decay, Density = a.Density, Offset = a.Offset,
			Glare = a.Glare, Haze = a.Haze }
	end
	if not a then
		a = Instance.new("Atmosphere")
		a.Name = "ESPAtmo"
		a.Parent = Lighting
		ourAtmo = a
	end
	return a
end
 
local function restoreAtmo()
	if ourAtmo then pcall(function() ourAtmo:Destroy() end) ourAtmo = nil end
	if atmoTarget and atmoSaved then
		for k, v in pairs(atmoSaved) do pcall(function() atmoTarget[k] = v end) end
	end
	atmoTarget, atmoSaved = nil, nil
end
 
local function updateGrade()
	if W.Grade then
		if not ourCC then
			ourCC = Instance.new("ColorCorrectionEffect")
			ourCC.Name = "ESPGrade"
			ourCC.Parent = Lighting
		end
		ourCC.TintColor, ourCC.Saturation, ourCC.Contrast = W.Tint, W.Saturation, W.Contrast
		ourCC.Enabled = true
	elseif ourCC then
		pcall(function() ourCC:Destroy() end)
		ourCC = nil
	end
end
 
local function setTime(hour)
-- made by: _meht_
	W.ClockTime, W.Time = hour, true
	Lighting.ClockTime = hour
	if timeToggle then pcall(function() timeToggle:Set(true) end) end
	if timeSlider then pcall(function() timeSlider:Set(hour) end) end
end
 
local function setTint(color, sat, contrast)
	W.Grade, W.Tint, W.Saturation, W.Contrast = true, color, sat or 0, contrast or 0
	updateGrade()
	if gradeToggle then pcall(function() gradeToggle:Set(true) end) end
	if tintPick then pcall(function() tintPick:Set(color) end) end
	if satSlider then pcall(function() satSlider:Set(W.Saturation) end) end
	if conSlider then pcall(function() conSlider:Set(W.Contrast) end) end
end
 
local function toAsset(id)
	if string.match(id, "^%d+$") then return "rbxassetid://" .. id end
	return id
end
 
local function applyCustomFaces(sky)
-- made by: _meht_
	local ids = {}
	for id in string.gmatch(W.CustomIds, "[^,%s]+") do table.insert(ids, toAsset(id)) end
	if #ids == 6 then
		for i, f in ipairs(SKY_FACES) do sky[f] = ids[i] end
	elseif #ids == 1 then
		for _, f in ipairs(SKY_FACES) do sky[f] = ids[1] end
	end
end
 
local function applySkyPreset(name)
	W.Sky = name
	if name == "Default" then
		removeOurSky()
		restoreAtmo()
		return
	end
	if #savedSkies == 0 then stashSkies() end
	if ourSky then pcall(function() ourSky:Destroy() end) end
	ourSky = Instance.new("Sky")
	ourSky.Name = "ESPSky"
 
	local p = SKY_PRESETS[name]
	if name == "Custom" then
		applyCustomFaces(ourSky)
		ourSky.StarCount = W.Stars
	elseif p then
		if p.blank then
			for _, f in ipairs(SKY_FACES) do ourSky[f] = "" end
		end
		ourSky.StarCount = p.stars or W.Stars
		ourSky.CelestialBodiesShown = p.bodies ~= false
	end
	ourSky.Parent = Lighting
 
	if p then
		if p.time then setTime(p.time) end
		if p.atmo then
			local a = getAtmo()
			a.Density = p.atmo.density or a.Density
			if p.atmo.color then a.Color = p.atmo.color end
			if p.atmo.decay then a.Decay = p.atmo.decay end
			if p.atmo.haze then a.Haze = p.atmo.haze end
		else
			restoreAtmo()
		end
		if p.tint then setTint(p.tint, p.sat, p.contrast) end
	end
end
 
local function resetWorld()
	W.Time, W.Bright, W.Grade = false, false, false
	pcall(function() Lighting.ClockTime = worldOrig.ClockTime end)
	pcall(function() Lighting.Brightness = worldOrig.Brightness end)
	removeOurSky()
	restoreAtmo()
	updateGrade()
	W.Sky = "Default"
end
 
local function updateWorld()
-- made by: _meht_
	if W.Time then Lighting.ClockTime = W.ClockTime end
	if W.Bright then Lighting.Brightness = W.BrightValue end
end
track(RunService.Heartbeat:Connect(function() pcall(updateWorld) end))
 
-- ================================================================ CONFIG SAVE SYSTEM
-- Saves every setting that has a Flag in the UI. Files live in workspace/AdvancedESP/configs/<name>.json
local HttpService = game:GetService("HttpService")
local okEnv, ENV = pcall(function() return getgenv() end)
if not okEnv or type(ENV) ~= "table" then ENV = getfenv() end
 
local CFG_DIR = "AdvancedESP/configs"
local CFG_INDEX = CFG_DIR .. "/_index.json"   -- list of config names (so we don't need listfiles)
local CFG_AUTO = CFG_DIR .. "/_autoload.txt"  -- name of the config to load on start
local HAS_FILES = typeof(ENV.writefile) == "function" and typeof(ENV.readfile) == "function"
	and typeof(ENV.isfile) == "function"
if HAS_FILES and typeof(ENV.isfolder) == "function" and typeof(ENV.makefolder) == "function" then
	pcall(function()
		if not ENV.isfolder("AdvancedESP") then ENV.makefolder("AdvancedESP") end
		if not ENV.isfolder(CFG_DIR) then ENV.makefolder(CFG_DIR) end
	end)
end
local CFG = { Selected = nil, NameInput = "", ListDrop = nil, Ready = false }
 
local function cfgNotify(msg)
	print("[Configs] " .. msg)
	pcall(function() Rayfield:Notify({ Title = "Configs", Content = msg, Duration = 5 }) end)
end
 
local function cleanName(n)
	n = tostring(n or "")
	n = string.gsub(n, "[^%w _%-]", "")
	n = string.gsub(n, "^%s+", "")
	n = string.gsub(n, "%s+$", "")
	return string.sub(n, 1, 30)
end
 
local function cfgPath(name) return CFG_DIR .. "/" .. name .. ".json" end
 
local function readJson(path)
-- made by: _meht_
	local ok, exists = pcall(ENV.isfile, path)
	if not (ok and exists) then return nil end
	local ok2, raw = pcall(ENV.readfile, path)
	if not ok2 then return nil end
	local ok3, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok3 then return data end
	return nil
end
 
local function ensureDirs()
	if typeof(ENV.makefolder) ~= "function" then return end
	for _, d in ipairs({ "AdvancedESP", CFG_DIR }) do
		local exists = false
		if typeof(ENV.isfolder) == "function" then
			local ok, r = pcall(ENV.isfolder, d)
			exists = ok and r and true or false
		end
		if not exists then pcall(ENV.makefolder, d) end
	end
end
 
local function writeJson(path, data)
	ensureDirs()
	return pcall(function() ENV.writefile(path, HttpService:JSONEncode(data)) end)
end
 
local function indexOf(list, name)
-- made by: _meht_
	for i, n in ipairs(list) do
		if n == name then return i end
	end
	return nil
end
 
-- names come from the index file AND from the real .json files in the folder (if listfiles exists)
local function loadIndex()
	local list = {}
	local d = readJson(CFG_INDEX)
	if type(d) == "table" then
		for _, n in ipairs(d) do
			if type(n) == "string" and not indexOf(list, n) then table.insert(list, n) end
		end
	end
	if typeof(ENV.listfiles) == "function" then
		local ok, files = pcall(ENV.listfiles, CFG_DIR)
		if ok and type(files) == "table" then
			for _, f in ipairs(files) do
				local n = string.match(f, "([^/\\]+)%.json$")
				if n and string.sub(n, 1, 1) ~= "_" and not indexOf(list, n) then table.insert(list, n) end
			end
		end
	end
	table.sort(list, function(a, b) return string.lower(a) < string.lower(b) end)
	return list
end
 
local function saveIndex(list)
	table.sort(list, function(a, b) return string.lower(a) < string.lower(b) end)
	return writeJson(CFG_INDEX, list)
end
 
local function refreshList(select)
-- made by: _meht_
	local list = loadIndex()
	if CFG.ListDrop then
		pcall(function() CFG.ListDrop:Refresh(list) end)
		if select then pcall(function() CFG.ListDrop:Set({ select }) end) end
	end
	return list
end
 
-- Every UI element that has a Flag is recorded here with its latest value, by wrapping the tab functions.
local REG = {}
 
local function wrapTab(tab)
	for _, kind in ipairs({ "Toggle", "Slider", "Dropdown", "ColorPicker", "Input" }) do
		local method = "Create" .. kind
		local orig = tab[method]
		tab[method] = function(self, opts)
			if opts and opts.Flag then
				local cb = opts.Callback
				local entry = { kind = kind, cb = cb }
				if kind == "ColorPicker" then
					entry.value = opts.Color
				elseif kind == "Dropdown" then
					entry.value = opts.CurrentOption
				else
					entry.value = opts.CurrentValue
				end
				opts.Callback = function(v)
					entry.value = v
					if cb then return cb(v) end
				end
				local el = orig(self, opts)
				entry.el = el
				REG[opts.Flag] = entry
				return el
			end
			return orig(self, opts)
		end
	end
	return tab
end
 
-- turns every registered setting into plain data
local function snapshot()
	local data = {}
	for flag, e in pairs(REG) do
		local v = e.value
		if e.kind == "ColorPicker" then
			if typeof(v) == "Color3" then
				data[flag] = { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
			end
		elseif e.kind == "Dropdown" then
			if type(v) == "string" then v = { v } end
			if type(v) == "table" then data[flag] = v end
		elseif v ~= nil then
			data[flag] = v
		end
	end
	return data
end
 
local function applySnapshot(data)
-- made by: _meht_
	local order = {}
	for flag in pairs(data) do table.insert(order, flag) end
	-- the skybox preset changes time/tint, so apply it first and let the saved values override afterwards
	table.sort(order, function(a, b)
		if a == "WorldSkyPreset" then return b ~= "WorldSkyPreset" end
		if b == "WorldSkyPreset" then return false end
		return a < b
	end)
	local count = 0
	for _, flag in ipairs(order) do
		local e, v = REG[flag], data[flag]
		if e and v ~= nil then
			local val = v
			if e.kind == "ColorPicker" and type(v) == "table" then
				val = Color3.fromRGB(v[1] or 255, v[2] or 255, v[3] or 255)
			end
			if e.el and e.el.Set then pcall(function() e.el:Set(val) end) end -- update what you see
			e.value = val
			if e.cb then pcall(e.cb, val) end                                  -- make sure the script follows too
			count = count + 1
			task.wait()
		end
	end
	return count
end
 
local function requireFiles()
	if HAS_FILES then return true end
	cfgNotify("Your executor can't read/write files (no writefile/readfile), so configs can't be saved.")
	return false
end
 
local function saveConfig(name)
	name = cleanName(name)
	if name == "" then
		cfgNotify("Pick or type a config name first.")
		return false
	end
	if not requireFiles() then return false end
	local data = snapshot()
	local count = 0
	for _ in pairs(data) do count = count + 1 end
	if count == 0 then
		cfgNotify("Nothing to save: no settings were registered.")
		return false
	end
	local ok, err = writeJson(cfgPath(name), data)
	if not ok then
		cfgNotify("Save failed: " .. tostring(err))
		return false
	end
	local back = readJson(cfgPath(name))
	if type(back) ~= "table" then
		cfgNotify("The file was written but can't be read back. Your executor may not keep files.")
		return false
	end
	local list = loadIndex()
	if not indexOf(list, name) then
		table.insert(list, name)
		saveIndex(list)
	end
	CFG.Selected = name
	refreshList(name)
	cfgNotify("Saved '" .. name .. "' (" .. count .. " settings) in workspace/" .. cfgPath(name))
	return true
end
 
local function loadConfig(name)
-- made by: _meht_
	if not name or name == "" then
		cfgNotify("Select a config in the list first.")
		return false
	end
	if not requireFiles() then return false end
	local data = readJson(cfgPath(name))
	if type(data) ~= "table" then
		cfgNotify("Couldn't read '" .. name .. "' (file missing or damaged).")
		return false
	end
	local n = applySnapshot(data)
	if n == 0 then
		cfgNotify("'" .. name .. "' loaded 0 settings. Save it again with this version of the script.")
		return false
	end
	cfgNotify("Loaded '" .. name .. "' (" .. n .. " settings).")
	return true
end
 
local function deleteConfig(name)
	if not name or name == "" then
		cfgNotify("Select a config in the list first.")
		return
	end
	if not requireFiles() then return end
	local list = loadIndex()
	local i = indexOf(list, name)
	if i then
		table.remove(list, i)
		saveIndex(list)
	end
	if typeof(ENV.delfile) == "function" then pcall(ENV.delfile, cfgPath(name)) end
	local ok, auto = pcall(ENV.readfile, CFG_AUTO)
	if ok and auto == name then pcall(ENV.writefile, CFG_AUTO, "") end
	CFG.Selected = nil
	refreshList()
	cfgNotify("Deleted '" .. name .. "'.")
end
 
local function renameConfig(old, new)
	new = cleanName(new)
	if not old or old == "" then
		cfgNotify("Select the config you want to rename first.")
		return
	end
	if new == "" then
		cfgNotify("Type the new name in the Config Name box first (press Enter).")
		return
	end
	if not requireFiles() then return end
	local list = loadIndex()
	if indexOf(list, new) then
		cfgNotify("A config named '" .. new .. "' already exists.")
		return
	end
	local data = readJson(cfgPath(old))
	if type(data) ~= "table" then
		cfgNotify("Couldn't read '" .. old .. "'.")
		return
	end
	local ok, err = writeJson(cfgPath(new), data)
	if not ok then
		cfgNotify("Rename failed: " .. tostring(err))
		return
	end
	local i = indexOf(list, old)
	if i then table.remove(list, i) end
	table.insert(list, new)
	saveIndex(list)
	if typeof(ENV.delfile) == "function" then pcall(ENV.delfile, cfgPath(old)) end
	local ok2, auto = pcall(ENV.readfile, CFG_AUTO)
	if ok2 and auto == old then pcall(ENV.writefile, CFG_AUTO, new) end
	CFG.Selected = new
	refreshList(new)
	cfgNotify("Renamed '" .. old .. "' to '" .. new .. "'.")
end
 
local function getAutoload()
-- made by: _meht_
	if not HAS_FILES then return nil end
	local ok, exists = pcall(ENV.isfile, CFG_AUTO)
	if not (ok and exists) then return nil end
	local ok2, raw = pcall(ENV.readfile, CFG_AUTO)
	if not ok2 or not raw or raw == "" then return nil end
	return raw
end
 
local function executorReport()
	local names = { "writefile", "readfile", "isfile", "isfolder", "makefolder", "delfile", "listfiles",
		"Drawing", "gethui" }
	local have, missing = {}, {}
	for _, n in ipairs(names) do
		if ENV[n] ~= nil then table.insert(have, n) else table.insert(missing, n) end
	end
	print("[Executor] available: " .. table.concat(have, ", "))
	print("[Executor] missing:   " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
	cfgNotify((HAS_FILES and "Configs can be saved. " or "Configs can NOT be saved. ")
		.. (HAS_DRAWING and "Drawing: yes. " or "Drawing: NO. ")
		.. (#missing > 0 and ("Missing: " .. table.concat(missing, ", ")) or ""))
end
 
-- ================================================================ CAMERA (FOV + screen stretch)
local CAM = {
	Fov = false, FovValue = 90, AllowZoom = true,
	Stretch = false, StretchX = 1, StretchY = 0.8,
	fovActive = false, fovOrig = nil, fovBase = nil, fovLast = nil, gameFov = nil, lastCF = nil,
}
 
local function sameCF(a, b)
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(ca[i] - cb[i]) > 1e-4 then return false end
	end
	return true
end
 
local function updateCamera()
-- made by: _meht_
	local cam = Workspace.CurrentCamera
	if not cam then return end
 
	-- field of view
	if CAM.Fov then
		if not CAM.fovActive then
			CAM.fovActive, CAM.fovOrig, CAM.fovBase = true, cam.FieldOfView, cam.FieldOfView
			CAM.fovLast, CAM.gameFov = nil, nil
		end
		local cur = cam.FieldOfView
		-- if the value isn't the one we wrote, the game changed it (for example zooming in while aiming)
		if CAM.fovLast == nil or math.abs(cur - CAM.fovLast) > 0.01 then CAM.gameFov = cur end
		local zooming = CAM.AllowZoom and CAM.gameFov and CAM.gameFov < CAM.fovBase - 5
		if zooming then
			CAM.fovLast = nil -- leave the game's zoom alone
		else
			cam.FieldOfView = CAM.FovValue
			CAM.fovLast = CAM.FovValue
		end
	elseif CAM.fovActive then
		cam.FieldOfView = CAM.fovOrig or 70
		CAM.fovActive = false
	end
 
	-- screen stretch: squash / widen the camera's axes. Only applied when the game wrote a fresh camera
	-- position this frame, so it never builds up on itself.
	if CAM.Stretch and (CAM.StretchX ~= 1 or CAM.StretchY ~= 1) then
		local cf = cam.CFrame
		if not (CAM.lastCF and sameCF(cf, CAM.lastCF)) then
			local new = cf * CFrame.new(0, 0, 0, CAM.StretchX, 0, 0, 0, CAM.StretchY, 0, 0, 0, 1)
			cam.CFrame = new
			CAM.lastCF = new
		end
	else
		CAM.lastCF = nil
	end
end
pcall(function() RunService:UnbindFromRenderStep("ESP_Camera") end)
RunService:BindToRenderStep("ESP_Camera", Enum.RenderPriority.Camera.Value + 1, function()
	pcall(updateCamera)
end)
 
-- ================================================================ SHOT TRACKING + HIT FEEDBACK
-- ================================================================ HUD (watermark + kill feed + compass + player list)
-- All custom-drawn, Instance-based GUI, independent of the menu so it can't be hidden by K.
local HUD = (function()
	local WM = { Enabled = false, ShowFPS = true, ShowPing = true, ShowTime = true }
	local KF = { Enabled = false, Duration = 6, MaxEntries = 8, ShowAllDeaths = true }
	local PL = { Enabled = false }
	local CP = { Enabled = false }

	local gui = Instance.new("ScreenGui")
	gui.Name = "ZapHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = protectedParent()

	local function newInst(class, props, parent)
		local i = Instance.new(class)
		for k, v in pairs(props or {}) do i[k] = v end
		if parent then i.Parent = parent end
		return i
	end

	-- ---------------------------------------------------------- watermark (draggable)
	local wmFrame = newInst("Frame", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(14, 16, 24),
		BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false }, gui)
	newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, wmFrame)
	newInst("UIStroke", { Color = Color3.fromRGB(60, 60, 80), Thickness = 1 }, wmFrame)
	newInst("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, wmFrame)
	local wmList = newInst("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, wmFrame)
	local wmLine = newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 13,
		TextColor3 = Color3.fromRGB(230, 230, 240), TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 16), Text = "ZapWare" }, wmFrame)
	do -- drag the watermark anywhere on screen
		local dragging, dragStart, startPos
		wmFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, dragStart, startPos = true, input.Position, wmFrame.Position
			end
		end)
		wmFrame.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				wmFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
	end
	local fpsFrames, lastFpsT = 0, tick()
	local fps = 0
	local function updateWatermark()
		wmFrame.Visible = WM.Enabled
		if not WM.Enabled then return end
		local parts = { "ZapWare" }
		if WM.ShowFPS then table.insert(parts, math.floor(fps) .. " fps") end
		if WM.ShowPing then
			local ok, p = pcall(function()
				local stat = game:GetService("Stats")
				return stat.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			if ok then table.insert(parts, math.floor(p) .. " ms") end
		end
		if WM.ShowTime then table.insert(parts, os.date("%H:%M:%S")) end
		wmLine.Text = table.concat(parts, "  |  ")
	end
	RunService.RenderStepped:Connect(function(dt)
		fpsFrames = fpsFrames + 1
		if tick() - lastFpsT >= 0.5 then
			fps = fpsFrames / (tick() - lastFpsT)
			fpsFrames, lastFpsT = 0, tick()
		end
	end)

	-- ---------------------------------------------------------- kill feed
	-- Self-built: this game's own kill feed (if it has one) is a GUI we can't reach or resize, so instead we
	-- watch every player's Humanoid for Health hitting 0 and build our own feed from that. That is also why its
	-- entry duration is fully adjustable here, which a game's own feed usually isn't.
	-- Row layout matches a standard "Killer  [weapon]  Victim" bar. We always know the VICTIM. We only know the
	-- KILLER when it's you (your own hit detection), or when this game happens to tag the Humanoid with a
	-- "creator" ObjectValue pointing at the killer (a common convention some FPS kits use) - that part is a
	-- best-effort guess and may not fire in every game. Otherwise the row falls back to just "Victim died".
	local kfFrame = newInst("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(340, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false }, gui)
	newInst("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Right }, kfFrame)
	local kfOrder = 0

	-- a small drawn rifle silhouette (no image asset needed) used between the two names
	local function weaponIcon(parent, color)
	-- made by: _meht_
		local box = newInst("Frame", { Size = UDim2.fromOffset(26, 14), BackgroundTransparency = 1 }, parent)
		local body = newInst("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.55),
			Size = UDim2.fromOffset(20, 3), BackgroundColor3 = color, BorderSizePixel = 0 }, box)
		newInst("UICorner", { CornerRadius = UDim.new(0, 1) }, body)
		local stock = newInst("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.68),
			Size = UDim2.fromOffset(9, 7), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = 20 }, box)
		newInst("UICorner", { CornerRadius = UDim.new(0, 1) }, stock)
		local mag = newInst("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.3, 0.55),
			Size = UDim2.fromOffset(4, 7), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = -16 }, box)
		newInst("UICorner", { CornerRadius = UDim.new(0, 1) }, mag)
		return box
	end

	-- full "Killer [weapon] Victim" row, or a plain centered row when there is no known killer
	local function killfeedRow(killer, weapon, victim, color, youAreKiller, youAreVictim)
		if not KF.Enabled then return end
		kfOrder = kfOrder + 1
		local row = newInst("Frame", { Size = UDim2.fromOffset(340, 28), BackgroundColor3 = Color3.fromRGB(16, 18, 26),
			BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = kfOrder }, kfFrame)
		newInst("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
		newInst("UIStroke", { Color = color or Color3.fromRGB(70, 70, 90), Thickness = 1 }, row)

		if killer then
			local killerLbl = newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = youAreKiller and Color3.fromRGB(120, 220, 140) or Color3.fromRGB(230, 230, 240),
				TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(0.4, -4, 1, 0), Position = UDim2.fromOffset(6, 0), Text = killer }, row)
			weaponIcon(row, Color3.fromRGB(190, 190, 205)).Position = UDim2.new(0.4, 6, 0.5, -7)
			newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = youAreVictim and Color3.fromRGB(235, 90, 90) or Color3.fromRGB(230, 230, 240),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(0.4, -4, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), Text = victim }, row)
			if weapon and weapon ~= "" then
				newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 9,
					TextColor3 = Color3.fromRGB(170, 170, 185), TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
					Text = weapon }, row)
			end
		else
			row.Size = UDim2.fromOffset(340, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			newInst("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, row)
			newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
				TextColor3 = youAreVictim and Color3.fromRGB(235, 90, 90) or Color3.fromRGB(230, 230, 240),
				TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = victim .. " died" }, row)
		end

		local rows = {}
		for _, c in ipairs(kfFrame:GetChildren()) do
			if c:IsA("Frame") then table.insert(rows, c) end
		end
		table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		while #rows > KF.MaxEntries do
			rows[1]:Destroy()
			table.remove(rows, 1)
		end
		task.delay(KF.Duration, function()
			if row.Parent then row:Destroy() end
		end)
	end

	-- opportunistic: some games tag a dead Humanoid with a "creator" ObjectValue pointing at the killer Player
	local function creatorOf(hum)
		local ok, tag = pcall(function() return hum:FindFirstChild("creator") end)
		if ok and tag and tag:IsA("ObjectValue") and tag.Value and tag.Value:IsA("Player") then
			return tag.Value.DisplayName
		end
		return nil
	end

	local killfeedHooked = {}
	local function hookKillfeed(player)
	-- made by: _meht_
		if killfeedHooked[player] then return end
		killfeedHooked[player] = true
		local function onChar(char)
			local hum = char:WaitForChild("Humanoid", 5)
			if not hum then return end
			hum.Died:Connect(function()
				local killer = creatorOf(hum) -- nil unless this game happens to set that tag
				local youAreVictim = (player == LocalPlayer)
				if killer then
					killfeedRow(killer, nil, youAreVictim and "You" or player.DisplayName, Color3.fromRGB(70, 70, 90),
						killer == LocalPlayer.DisplayName, youAreVictim)
				else
					killfeedRow(nil, nil, youAreVictim and "You" or player.DisplayName, Color3.fromRGB(70, 70, 90), false, youAreVictim)
				end
			end)
		end
		if player.Character then onChar(player.Character) end
		player.CharacterAdded:Connect(onChar)
	end
	for _, p in ipairs(Players:GetPlayers()) do hookKillfeed(p) end
	Players.PlayerAdded:Connect(hookKillfeed)


	-- ---------------------------------------------------------- compass (cardinal direction bar)
	local cpFrame = newInst("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(260, 22), BackgroundColor3 = Color3.fromRGB(14, 16, 24), BackgroundTransparency = 0.25,
		BorderSizePixel = 0, ClipsDescendants = true, Visible = false }, gui)
	newInst("UICorner", { CornerRadius = UDim.new(0, 5) }, cpFrame)
	local cpStrip = newInst("Frame", { Size = UDim2.new(4, 0, 1, 0), BackgroundTransparency = 1 }, cpFrame)
	local DIRS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW", "N", "NE", "E", "SE", "S" }
	for i, d in ipairs(DIRS) do
		newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = d == "N" and Color3.fromRGB(235, 90, 90) or Color3.fromRGB(220, 220, 230),
			Size = UDim2.new(1 / #DIRS, 0, 1, 0), Position = UDim2.new((i - 1) / #DIRS, 0, 0, 0), Text = d,
			TextXAlignment = Enum.TextXAlignment.Center }, cpStrip)
	end
	local cpMarker = newInst("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(2, 22), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0 }, cpFrame)
	local function updateCompass()
		cpFrame.Visible = CP.Enabled
		if not CP.Enabled then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local look = cam.CFrame.LookVector
		local yaw = math.deg(math.atan2(look.X, -look.Z)) -- 0 = north
		if yaw < 0 then yaw = yaw + 360 end
		-- the strip has 2 extra copies of N..S on each side so it can scroll without a seam
		local frac = yaw / 360
		cpStrip.Position = UDim2.new(-1 - frac, 0, 0, 0)
	end

	-- ---------------------------------------------------------- player list (name / distance / health)
	local plFrame = newInst("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(220, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(14, 16, 24),
		BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false }, gui)
	newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, plFrame)
	newInst("UIStroke", { Color = Color3.fromRGB(60, 60, 80), Thickness = 1 }, plFrame)
	newInst("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, plFrame)
	newInst("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, plFrame)
	local plRows = {}
	local function plRow(order)
		local f = newInst("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = order }, plFrame)
		local n = newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
			TextColor3 = Color3.fromRGB(230, 230, 240), TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.55, 0, 1, 0), Text = "" }, f)
		local d = newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 12,
			TextColor3 = Color3.fromRGB(170, 170, 185), TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(0.2, 0, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), Text = "" }, f)
		local h = newInst("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 12,
			TextColor3 = Color3.fromRGB(120, 220, 140), TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.25, 0, 1, 0), Position = UDim2.new(0.75, 0, 0, 0), Text = "" }, f)
		return { frame = f, name = n, dist = d, hp = h }
	end
	local function updatePlayerList()
		plFrame.Visible = PL.Enabled
		if not PL.Enabled then return end
		local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				local hum = p.Character:FindFirstChildOfClass("Humanoid")
				local root = p.Character:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 then
					local dist = localRoot and (root.Position - localRoot.Position).Magnitude or 0
					table.insert(list, { name = p.DisplayName, dist = dist, pct = hum.Health / math.max(hum.MaxHealth, 1) })
				end
			end
		end
		table.sort(list, function(a, b) return a.dist < b.dist end)
		for i = 1, math.min(#list, 12) do
			local r = plRows[i]
			if not r then r = plRow(i) plRows[i] = r end
			local e = list[i]
			r.name.Text, r.dist.Text, r.hp.Text = e.name, math.floor(e.dist) .. "m", math.floor(e.pct * 100) .. "%"
			r.hp.TextColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(120, 220, 140), e.pct)
			r.frame.Visible = true
		end
		for i = #list + 1, #plRows do plRows[i].frame.Visible = false end
	end

	RunService.Heartbeat:Connect(function()
		pcall(updateWatermark)
		pcall(updateCompass)
		pcall(updatePlayerList)
	end)

	return {
		WM = WM, KF = KF, PL = PL, CP = CP,
		killfeedEntry = killfeedEntry,
		unload = function() pcall(function() gui:Destroy() end) end,
	}
end)()

-- ---------------------------------------------------------------- unload
local function unload()
	HUD.unload()
	CAM.Fov, CAM.Stretch = false, false
	pcall(function() RunService:UnbindFromRenderStep("ESP_Camera") end)
	if CAM.fovActive then pcall(function() Workspace.CurrentCamera.FieldOfView = CAM.fovOrig or 70 end) end
	if npcConn then npcConn:Disconnect() npcConn = nil end
	for _, c in ipairs(connections) do c:Disconnect() end
	for p in pairs(objects) do destroyObjects(p) end
	resetWorld()
	chamsFolder:Destroy()
	Rayfield:Destroy()
end
 
-- ---------------------------------------------------------------- UI
pcall(function() getgenv().AdvancedESP_Unload = unload end)
 
-- ---------------------------------------------------------------- menu look
-- A dark theme whose accent colour (toggles, sliders, selected tab) you can change in Misc.
local MENU = { Theme = "Custom Accent", Accent = Color3.fromRGB(150, 90, 255), token = 0 }
 
local function makeTheme(over)
	local t = {}
	local base = Rayfield.Theme and Rayfield.Theme.Default
	if type(base) == "table" then
		for k, v in pairs(base) do t[k] = v end
	end
	for k, v in pairs(over) do t[k] = v end
	return t
end
 
local function accentTheme(accent)
	local h, s, v = accent:ToHSV()
	local deep = Color3.fromHSV(h, s, v * 0.55)
	return makeTheme({
		TextColor = Color3.fromRGB(236, 236, 246),
		Background = Color3.fromRGB(10, 13, 22),
		Topbar = Color3.fromRGB(17, 21, 35),
		Shadow = Color3.fromRGB(6, 6, 10),
		NotificationBackground = Color3.fromRGB(18, 18, 26),
		NotificationActionsBackground = accent,
		TabBackground = Color3.fromRGB(28, 28, 40),
		TabStroke = Color3.fromRGB(46, 46, 64),
		TabBackgroundSelected = accent,
		TabTextColor = Color3.fromRGB(190, 190, 206),
		SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
		ElementBackground = Color3.fromRGB(24, 29, 47),
		ElementBackgroundHover = Color3.fromRGB(30, 36, 58),
		SecondaryElementBackground = Color3.fromRGB(17, 17, 25),
		ElementStroke = Color3.fromRGB(33, 40, 62),
		SecondaryElementStroke = Color3.fromRGB(34, 34, 48),
		SliderBackground = deep,
		SliderProgress = accent,
		SliderStroke = accent,
		ToggleBackground = Color3.fromRGB(20, 20, 30),
		ToggleEnabled = accent,
		ToggleDisabled = Color3.fromRGB(58, 64, 88),
		ToggleEnabledStroke = accent,
		ToggleDisabledStroke = Color3.fromRGB(110, 110, 126),
		ToggleEnabledOuterStroke = deep,
		ToggleDisabledOuterStroke = Color3.fromRGB(55, 55, 70),
		DropdownSelected = Color3.fromRGB(33, 33, 47),
		DropdownUnselected = Color3.fromRGB(22, 22, 32),
		InputBackground = Color3.fromRGB(13, 17, 29),
		InputStroke = Color3.fromRGB(56, 56, 76),
		PlaceholderColor = Color3.fromRGB(150, 150, 170),
	})
end
MENU.Applied = "C" .. tostring(MENU.Accent)
 
local Window = Rayfield:CreateWindow({
	Name = "Zap Public",
	LoadingTitle = "Zap Public",
	LoadingSubtitle = "loading your menu...",
	Subtitle = "chams  |  esp  |  camera  |  world",
	Version = "v2.0",
	Theme = accentTheme(MENU.Accent),
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false },
	KeySystem = false,
})
do -- every tab created from here on records its flagged settings for the config system
	local origCreateTab = Window.CreateTab
	Window.CreateTab = function(self, ...)
		return wrapTab(origCreateTab(self, ...))
	end
end
 
-- debounced, and skipped when nothing changed, so dragging the colour picker doesn't spam notifications
local function applyTheme()
	local key = MENU.Theme == "Custom Accent" and ("C" .. tostring(MENU.Accent)) or MENU.Theme
	if key == MENU.Applied then return end
	MENU.token = MENU.token + 1
	local my = MENU.token
	task.delay(0.5, function()
		if my ~= MENU.token or key == MENU.Applied then return end
		MENU.Applied = key
		pcall(function()
			if MENU.Theme == "Custom Accent" then
				Window.ModifyTheme(accentTheme(MENU.Accent))
			else
				Window.ModifyTheme(MENU.Theme)
			end
		end)
	end)
end
 
local Main = Window:CreateTab("ESP", "eye")
local TabCombatLocked = Window:CreateTab("Combat", "target+lock")
local TabView = Window:CreateTab("Viewmodel", "camera+lock")
local TabChar = Window:CreateTab("Character", "user+lock")
local TabWorld = Window:CreateTab("World", "sun")
local TabFXLocked = Window:CreateTab("Effects", "sparkles+lock")
local TabSet = Window:CreateTab("Settings", "settings")

-- ================================================================ LOCKED PREVIEW TABS
-- Combat and Effects aren't in this build. These tabs exist so you can see what they look like;
-- every control here just shows a "Zap Private" notice and snaps back off - nothing on them actually runs.
TabCombatLocked:CreateSection("Combat  (Zap Private)")
TabCombatLocked:CreateParagraph({ Title = "Locked", Content = "Not available in Zap Public. Join the Discord for updates and access." })
TabCombatLocked:CreateButton({ Name = "Join the Discord to unlock this", Icon = "discord", Callback = function() Rayfield.OpenDiscord() end })

TabFXLocked:CreateSection("Effects  (Zap Private)")
TabFXLocked:CreateParagraph({ Title = "Locked", Content = "Not available in Zap Public. Join the Discord for updates and access." })
TabFXLocked:CreateButton({ Name = "Join the Discord to unlock this", Icon = "discord", Callback = function() Rayfield.OpenDiscord() end })

Main:CreateSubTab("General")
Main:CreateSection("General")
Main:CreateToggle({ Name = "Enable ESP", CurrentValue = false, Flag = "ESPEnabled",
	Callback = function(v) S.Enabled = v end })
Main:CreateToggle({ Name = "Team Check (enemies only)", CurrentValue = false, Flag = "TeamCheck",
	Callback = function(v) S.TeamCheck = v end })
Main:CreateSlider({ Name = "Max Distance", Range = { 50, 5000 }, Increment = 50, Suffix = "studs",
	CurrentValue = 1500, Flag = "MaxDist", Callback = function(v) S.MaxDistance = v end })
 
Main:CreateSubTab("NPCs")
Main:CreateSection("NPCs / Bots")
Main:CreateToggle({ Name = "Show NPCs", CurrentValue = false, Flag = "NPCs",
	Callback = function(v)
		S.NPCs = v
		if v then enableNpcs() else disableNpcs() end
	end })
Main:CreateInput({ Name = "NPC Name Filter (optional)", CurrentValue = "", PlaceholderText = "e.g. Zombie",
	RemoveTextAfterFocusLost = false, Flag = "NpcFilter", Callback = function(t) S.NpcFilter = t or "" end })
Main:CreateColorPicker({ Name = "NPC Visible Colour", Color = S.NpcVisibleColor, Flag = "NpcVis",
	Callback = function(v) S.NpcVisibleColor = v end })
Main:CreateColorPicker({ Name = "NPC Hidden Colour", Color = S.NpcHiddenColor, Flag = "NpcHid",
	Callback = function(v) S.NpcHiddenColor = v end })
 
local Draw = Main
Draw:CreateSubTab("Draw")
if not HAS_DRAWING then
	Draw:CreateLabel("Your executor has no Drawing library: only Chams will work.")
end
Draw:CreateSection("Boxes")
Draw:CreateToggle({ Name = "Boxes", CurrentValue = true, Flag = "Boxes",
	Callback = function(v) S.Boxes = v end })
Draw:CreateDropdown({ Name = "Box Style", Options = { "Corner", "Full" }, CurrentOption = { "Corner" },
	Flag = "BoxStyle", Callback = function(o) S.BoxStyle = o[1] end })
Draw:CreateColorPicker({ Name = "Box Colour", Color = S.BoxColor, Flag = "BoxColor",
	Callback = function(v) S.BoxColor = v end })
 
Draw:CreateSection("Text")
Draw:CreateToggle({ Name = "Names", CurrentValue = true, Flag = "Names",
	Callback = function(v) S.Names = v end })
Draw:CreateToggle({ Name = "Distance", CurrentValue = true, Flag = "Distance",
	Callback = function(v) S.Distance = v end })
Draw:CreateToggle({ Name = "Held Item", CurrentValue = false, Flag = "HeldItem",
	Callback = function(v) S.HeldItem = v end })
Draw:CreateColorPicker({ Name = "Text Colour", Color = S.NameColor, Flag = "TextColor",
	Callback = function(v) S.NameColor = v end })
Draw:CreateSlider({ Name = "Text Size", Range = { 10, 24 }, Increment = 1, CurrentValue = 13,
	Flag = "TextSize", Callback = function(v) S.TextSize = v end })
 
Draw:CreateSection("Health")
Draw:CreateToggle({ Name = "Health Bar", CurrentValue = true, Flag = "HealthBar",
	Callback = function(v) S.HealthBar = v end })
Draw:CreateToggle({ Name = "Health Number", CurrentValue = false, Flag = "HealthNum",
	Callback = function(v) S.HealthNumber = v end })
 
 
-- ================================================================ CAMERA TAB
local CamTab = TabWorld
CamTab:CreateSubTab("Camera")
CamTab:CreateSection("Field of View")
CamTab:CreateToggle({ Name = "Enable FOV Changer", CurrentValue = false, Flag = "FovOn",
	Callback = function(v) CAM.Fov = v end })
CamTab:CreateSlider({ Name = "Field of View", Range = { 30, 120 }, Increment = 1, CurrentValue = 90, Suffix = " deg",
	Flag = "FovValue", Callback = function(v) CAM.FovValue = v end })
CamTab:CreateToggle({ Name = "Let The Game Zoom When I Aim", CurrentValue = true, Flag = "FovAllowZoom",
	Callback = function(v) CAM.AllowZoom = v end })
 
CamTab:CreateSection("Screen Stretch")
CamTab:CreateToggle({ Name = "Enable Screen Stretch", CurrentValue = false, Flag = "StretchOn",
	Callback = function(v) CAM.Stretch = v end })
local stretchXSlider, stretchYSlider
stretchXSlider = CamTab:CreateSlider({ Name = "Horizontal (above 1 = wider)", Range = { 0.3, 1.5 }, Increment = 0.01,
	CurrentValue = 1, Flag = "StretchX", Callback = function(v) CAM.StretchX = v end })
stretchYSlider = CamTab:CreateSlider({ Name = "Vertical (below 1 = squashed, like 4:3 stretched)", Range = { 0.3, 1.5 },
	Increment = 0.01, CurrentValue = 0.8, Flag = "StretchY", Callback = function(v) CAM.StretchY = v end })
local STRETCH_PRESETS = {
	["Normal"] = { 1, 1 }, ["Slight"] = { 1, 0.85 }, ["Classic 4:3"] = { 1, 0.75 },
	["Heavy"] = { 1, 0.6 }, ["Wide"] = { 1.3, 1 },
}
CamTab:CreateDropdown({ Name = "Quick Presets", Options = { "Normal", "Slight", "Classic 4:3", "Heavy", "Wide" },
	CurrentOption = {}, Callback = function(o)
		local p = STRETCH_PRESETS[o[1]]
		if not p then return end
		CAM.StretchX, CAM.StretchY = p[1], p[2]
		pcall(function() stretchXSlider:Set(p[1]) end)
		pcall(function() stretchYSlider:Set(p[2]) end)
		CAM.StretchX, CAM.StretchY = p[1], p[2]
	end })
CamTab:CreateButton({ Name = "Reset Camera (FOV + Stretch off)", Callback = function()
	CAM.Fov, CAM.Stretch = false, false
	CAM.StretchX, CAM.StretchY = 1, 1
	pcall(function() stretchXSlider:Set(1) end)
	pcall(function() stretchYSlider:Set(1) end)
	CAM.StretchX, CAM.StretchY = 1, 1
end })
 
-- ================================================================ WORLD TAB
local World = TabWorld
World:CreateSubTab("Time & Sky")
World:CreateSection("Time Changer")
timeToggle = World:CreateToggle({ Name = "Override Time of Day", CurrentValue = false, Flag = "WorldTime",
	Callback = function(v)
		W.Time = v
		if not v then pcall(function() Lighting.ClockTime = worldOrig.ClockTime end) end
	end })
timeSlider = World:CreateSlider({ Name = "Clock Time (0 = midnight, 12 = noon)", Range = { 0, 24 }, Increment = 0.25,
	CurrentValue = 14, Suffix = "h", Flag = "WorldClock", Callback = function(v) W.ClockTime = v end })
World:CreateButton({ Name = "Day (14:00)", Callback = function() setTime(14) end })
World:CreateButton({ Name = "Night (0:00)", Callback = function() setTime(0) end })
World:CreateButton({ Name = "Sunset (17:45)", Callback = function() setTime(17.75) end })
World:CreateButton({ Name = "Sunrise (6:00)", Callback = function() setTime(6) end })
brightToggle = World:CreateToggle({ Name = "Override Brightness", CurrentValue = false, Flag = "WorldBright",
	Callback = function(v)
		W.Bright = v
		if not v then pcall(function() Lighting.Brightness = worldOrig.Brightness end) end
	end })
World:CreateSlider({ Name = "Brightness", Range = { 0, 6 }, Increment = 0.1, CurrentValue = 2,
	Flag = "WorldBrightVal", Callback = function(v) W.BrightValue = v end })
 
World:CreateSection("Skybox")
World:CreateDropdown({ Name = "Skybox Preset", Options = SKY_LIST, CurrentOption = { "Default" },
	Flag = "WorldSkyPreset", Callback = function(o) applySkyPreset(o[1]) end })
World:CreateSlider({ Name = "Star Count", Range = { 0, 10000 }, Increment = 250, CurrentValue = 3000,
	Flag = "WorldStars", Callback = function(v)
		W.Stars = v
		if ourSky then ourSky.StarCount = v end
	end })
World:CreateInput({ Name = "Custom Skybox IDs", CurrentValue = "",
	PlaceholderText = "1 id for all faces, or 6: BK,DN,FT,LF,RT,UP", RemoveTextAfterFocusLost = false,
	Flag = "WorldCustomIds", Callback = function(t) W.CustomIds = t or "" end })
World:CreateButton({ Name = "Apply Custom Skybox", Callback = function() applySkyPreset("Custom") end })
World:CreateLabel("Presets are built from lighting effects. For picture skyboxes, get image asset IDs from the Roblox Creator Store (search 'skybox') and use the custom box.")
 
World:CreateSubTab("Colour")
World:CreateSection("Colour Grading")
World:CreateButton({ Name = "Join the Discord to unlock this", Icon = "discord", Callback = function() Rayfield.OpenDiscord() end })
gradeToggle = World:CreateToggle({ Name = "Enable Colour Grading", CurrentValue = false, Flag = "WorldGrade",
	Callback = function(v)
		W.Grade = v
		updateGrade()
	end })
tintPick = World:CreateColorPicker({ Name = "Tint", Color = W.Tint, Flag = "WorldTint",
	Callback = function(v)
		W.Tint = v
		updateGrade()
	end })
satSlider = World:CreateSlider({ Name = "Saturation", Range = { -1, 1 }, Increment = 0.05, CurrentValue = 0,
	Flag = "WorldSat", Callback = function(v)
		W.Saturation = v
		updateGrade()
	end })
conSlider = World:CreateSlider({ Name = "Contrast", Range = { -1, 1 }, Increment = 0.05, CurrentValue = 0,
	Flag = "WorldCon", Callback = function(v)
		W.Contrast = v
		updateGrade()
	end })
World:CreateButton({ Name = "Reset World (restore original)", Callback = function()
	resetWorld()
	if timeToggle then pcall(function() timeToggle:Set(false) end) end
	if brightToggle then pcall(function() brightToggle:Set(false) end) end
	if gradeToggle then pcall(function() gradeToggle:Set(false) end) end
end })
 
-- ================================================================ VIEWMODEL TAB (locked preview)
TabView:CreateSection("Viewmodel  (Zap Private)")
TabView:CreateParagraph({ Title = "Locked", Content = "Not available in Zap Public. Join the Discord for updates and access." })
TabView:CreateButton({ Name = "Join the Discord to unlock this", Icon = "discord", Callback = function() Rayfield.OpenDiscord() end })

-- ================================================================ CHARACTER TAB (locked preview)
TabChar:CreateSection("Character  (Zap Private)")
TabChar:CreateParagraph({ Title = "Locked", Content = "Not available in Zap Public. Join the Discord for updates and access." })
TabChar:CreateButton({ Name = "Join the Discord to unlock this", Icon = "discord", Callback = function() Rayfield.OpenDiscord() end })

-- ================================================================ CONFIGS TAB
local CF = TabSet
CF:CreateSubTab("Configs")
CF:CreateSection("Configs")
CFG.ListDrop = CF:CreateDropdown({ Name = "Saved Configs", Options = loadIndex(), CurrentOption = {},
	Callback = function(o) CFG.Selected = o[1] end })
CF:CreateInput({ Name = "Config Name (type it, press Enter)", CurrentValue = "", PlaceholderText = "e.g. Night Hunter",
	RemoveTextAfterFocusLost = false, Callback = function(t) CFG.NameInput = t or "" end })
 
CF:CreateSection("Save / Load")
CF:CreateButton({ Name = "Save As New Config (uses the name above)", Callback = function()
	local name = cleanName(CFG.NameInput)
	if name == "" then
		cfgNotify("Type a name in the Config Name box and press Enter first.")
		return
	end
	if indexOf(loadIndex(), name) then
		cfgNotify("'" .. name .. "' already exists. Select it and press Overwrite, or pick another name.")
		return
	end
	saveConfig(name)
end })
CF:CreateButton({ Name = "Overwrite Selected Config (save current settings into it)", Callback = function()
	if not CFG.Selected then
		cfgNotify("Select a config in the list first.")
		return
	end
	saveConfig(CFG.Selected)
end })
CF:CreateButton({ Name = "Load Selected Config", Callback = function() loadConfig(CFG.Selected) end })
CF:CreateButton({ Name = "Rename Selected Config (to the name above)", Callback = function()
	renameConfig(CFG.Selected, CFG.NameInput)
end })
CF:CreateButton({ Name = "Delete Selected Config", Callback = function() deleteConfig(CFG.Selected) end })
CF:CreateButton({ Name = "Refresh List", Callback = function() refreshList(CFG.Selected) end })
 
CF:CreateSection("Auto-load")
CF:CreateToggle({ Name = "Auto-load Selected Config When The Script Starts", CurrentValue = getAutoload() ~= nil,
	Callback = function(v)
		if not CFG.Ready then return end
		if not requireFiles() then return end
		if v then
			if not CFG.Selected then
				cfgNotify("Select a config in the list first.")
				return
			end
			pcall(ENV.writefile, CFG_AUTO, CFG.Selected)
			cfgNotify("'" .. CFG.Selected .. "' will load automatically next time.")
		else
			pcall(ENV.writefile, CFG_AUTO, "")
			cfgNotify("Auto-load turned off.")
		end
	end })
CF:CreateButton({ Name = "Check My Executor (can it save files?)", Callback = executorReport })
 
CF:CreateSubTab("HUD")
CF:CreateSection("Watermark")
CF:CreateToggle({ Name = "Enable Watermark", CurrentValue = false, Flag = "HudWmOn",
	Callback = function(v) HUD.WM.Enabled = v end })
CF:CreateToggle({ Name = "Show FPS", CurrentValue = true, Flag = "HudWmFps", Callback = function(v) HUD.WM.ShowFPS = v end })
CF:CreateToggle({ Name = "Show Ping", CurrentValue = true, Flag = "HudWmPing", Callback = function(v) HUD.WM.ShowPing = v end })
CF:CreateToggle({ Name = "Show Clock", CurrentValue = true, Flag = "HudWmTime", Callback = function(v) HUD.WM.ShowTime = v end })
CF:CreateLabel("Drag the watermark anywhere on screen.")

CF:CreateSection("Kill Feed (built-in, adjustable)")
CF:CreateToggle({ Name = "Enable Kill Feed", CurrentValue = false, Flag = "HudKfOn",
	Callback = function(v) HUD.KF.Enabled = v end })
CF:CreateSlider({ Name = "Keep Entries For", Range = { 2, 30 }, Increment = 1, CurrentValue = 6, Suffix = "s",
	Flag = "HudKfDuration", Callback = function(v) HUD.KF.Duration = v end })
CF:CreateSlider({ Name = "Max Entries On Screen", Range = { 3, 15 }, Increment = 1, CurrentValue = 8,
	Flag = "HudKfMax", Callback = function(v) HUD.KF.MaxEntries = v end })
CF:CreateLabel("This is a feed Zapware builds itself (most games' own feed can't be resized or kept longer), so you choose how long entries stay and how many show at once.")

CF:CreateSection("Compass & Player List")
CF:CreateToggle({ Name = "Enable Compass", CurrentValue = false, Flag = "HudCompassOn",
	Callback = function(v) HUD.CP.Enabled = v end })
CF:CreateToggle({ Name = "Enable Player List", CurrentValue = false, Flag = "HudPlayersOn",
	Callback = function(v) HUD.PL.Enabled = v end })
CF:CreateLabel("Player list shows the 12 closest players by distance and current health.")

local Misc = TabSet
Misc:CreateSubTab("Menu")
Misc:CreateSection("Menu  (press K to hide / show)")
local themeDrop, accentPick
accentPick = Misc:CreateColorPicker({ Name = "Accent Colour (for the Custom Accent theme)", Color = MENU.Accent,
	Flag = "MenuAccent", Callback = function(v)
		MENU.Accent = v
		applyTheme()
	end })
local ACCENTS = {
	["Purple"] = Color3.fromRGB(150, 90, 255), ["Red"] = Color3.fromRGB(235, 60, 70),
	["Cyan"] = Color3.fromRGB(40, 200, 235), ["Green"] = Color3.fromRGB(60, 210, 110),
	["Orange"] = Color3.fromRGB(255, 140, 40), ["Pink"] = Color3.fromRGB(255, 100, 190),
	["Blue"] = Color3.fromRGB(70, 130, 255),
}
Misc:CreateDropdown({ Name = "Accent Presets", Options = { "Purple", "Red", "Cyan", "Green", "Orange", "Pink", "Blue" },
	CurrentOption = {}, Callback = function(o)
		local c = ACCENTS[o[1]]
		if not c then return end
		MENU.Theme, MENU.Accent = "Custom Accent", c
		pcall(function() themeDrop:Set({ "Custom Accent" }) end)
		pcall(function() accentPick:Set(c) end)
		MENU.Theme, MENU.Accent = "Custom Accent", c
		applyTheme()
	end })
Misc:CreateSlider({ Name = "Menu Size", Range = { 0.7, 1.4 }, Increment = 0.05, CurrentValue = 1, Suffix = "x",
	Flag = "MenuScale", Callback = function(v)
		if Rayfield.SetScale then Rayfield:SetScale(v) end
	end })
 

Misc:CreateSection("Advanced")
Misc:CreateLabel("The menu keybind (K) is fixed in this build; restart the script after changing the ToggleUIKeybind line near the top if you want a different key.")
Misc:CreateButton({ Name = "Server Hop (rejoin a fresh server)", Callback = function()
	local ok, err = QOL.serverHop()
	if not ok then
		pcall(function() Rayfield:Notify({ Title = "Server Hop", Content = "Failed: " .. tostring(err), Duration = 6 }) end)
	end
end })
Misc:CreateButton({ Name = "Unlock FPS Cap", Callback = function()
	local ok, msg = QOL.unlockFps()
	pcall(function() Rayfield:Notify({ Title = "FPS", Content = msg, Duration = 5 }) end)
end })

CF:CreateSection("Export / Import Config")
CF:CreateButton({ Name = "Export Current Settings (copies text)", Callback = function()
	local text, err = exportConfigText()
	if not text then
		cfgNotify(err or "Export failed.")
		return
	end
	local copied = false
	if setclipboard then copied = pcall(setclipboard, text) end
	print("---- exported config ----\n" .. text)
	cfgNotify(copied and "Copied to your clipboard - paste it to a friend." or "Can't copy automatically; press F9 and copy it from the console.")
end })
CF:CreateInput({ Name = "Import Config (paste text, press Enter)", CurrentValue = "", PlaceholderText = "paste exported text here",
	RemoveTextAfterFocusLost = false, Callback = function(t)
		if t == "" then return end
		local n, err = importConfigText(t)
		if err then cfgNotify(err) else cfgNotify("Imported " .. n .. " settings.") end
	end })

Misc:CreateButton({ Name = "Unload Script", Callback = unload })
 
-- auto-load the saved config (if one is set) once the UI has finished building
task.spawn(function()
	task.wait(1)
	local auto = getAutoload()
	if auto and indexOf(loadIndex(), auto) then
		CFG.Selected = auto
		refreshList(auto)
		loadConfig(auto)
	end
	CFG.Ready = true
end)