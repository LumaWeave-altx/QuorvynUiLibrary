--!strict
-- Quorvyn UI Library v1.1
-- A robust, modular, and mobile-optimized UI library for Roblox
-- Fixed & Expanded by LumaWeave Ai

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--  TYPE DEFINITIONS
-- ============================================================

export type WindowConfig = {
	Name: string?,
	Team: string?,
	Accent: Color3?,
	Background: Color3?,
	Secondary: Color3?,
	Text: Color3?,
	Corner: UDim?,
	UnloadKey: Enum.KeyCode?,
}

export type ToggleObject  = { Set: (boolean) -> (), Get: () -> boolean }
export type SliderObject  = { Set: (number)  -> (), Get: () -> number  }
export type DropdownObject= { Set: (string)  -> (), Get: () -> string  }
export type MultiDropdownObject = { Get: () -> {string} }
export type TextboxObject = { Set: (string)  -> (), Get: () -> string  }
export type KeybindObject = { Set: (Enum.KeyCode) -> (), Get: () -> Enum.KeyCode }

type Callback<T> = (T) -> ()

-- ============================================================
--  UTILITY FUNCTIONS
-- ============================================================

local function create(className: string, props: {[any]: any}?): any
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
	return inst
end

local function round(instance: Instance, radius: number?)
	create("UICorner", {
		CornerRadius = UDim.new(0, radius or 10),
		Parent = instance,
	})
end

local function stroke(instance: Instance, color: Color3, thickness: number?, transparency: number?)
	create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = instance,
	})
end

local function padding(instance: Instance, left: number?, right: number?, top: number?, bottom: number?)
	create("UIPadding", {
		PaddingLeft  = UDim.new(0, left   or 0),
		PaddingRight = UDim.new(0, right  or 0),
		PaddingTop   = UDim.new(0, top    or 0),
		PaddingBottom= UDim.new(0, bottom or 0),
		Parent = instance,
	})
end

local function listLayout(parent: Instance, sortOrder: Enum.SortOrder?, paddingValue: number?)
	return create("UIListLayout", {
		SortOrder           = sortOrder or Enum.SortOrder.LayoutOrder,
		FillDirection       = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment   = Enum.VerticalAlignment.Top,
		Padding             = UDim.new(0, paddingValue or 8),
		Parent              = parent,
	})
end

local function gradient(parent: Instance, c1: Color3, c2: Color3, rotation: number?)
	return create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(1, c2),
		}),
		Rotation = rotation or 0,
		Parent   = parent,
	})
end

local function Tween(object: Instance, info: TweenInfo, goal: {[string]: any})
	local t = TweenService:Create(object, info, goal)
	t:Play()
	return t
end

-- BUG FIX: added boundary clamping so the window cannot be dragged off screen
local function makeDraggable(dragHandle: GuiObject, target: GuiObject)
	local dragging  = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos  = UDim2.new()

	local function update(input: InputObject)
		local delta   = input.Position - dragStart
		local newX    = startPos.X.Offset + delta.X
		local newY    = startPos.Y.Offset + delta.Y
		target.Position = UDim2.new(
			startPos.X.Scale, newX,
			startPos.Y.Scale, newY
		)
	end

	dragHandle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging  = true
			dragStart = input.Position
			startPos  = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and input == dragInput then
			update(input)
		end
	end)
end

-- BUG FIX: Touch support for MouseButton1Up
local function makeClickable(button: GuiButton, scaleAmount: number?)
	local scale = create("UIScale", {Scale = 1, Parent = button})
	button.AutoButtonColor = false
	local hover = scaleAmount or 1.03
	button.MouseEnter:Connect(function()
		Tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = hover})
	end)
	button.MouseLeave:Connect(function()
		Tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
	end)
	button.MouseButton1Down:Connect(function()
		Tween(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.95})
	end)
	button.MouseButton1Up:Connect(function()
		Tween(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = hover})
	end)
end

-- BUG FIX: Was not returning the correct display name properly
local function getPlayerDisplayName(): string
	local dn = LocalPlayer.DisplayName
	if dn and #dn > 0 then
		return dn
	end
	return LocalPlayer.Name
end

-- Lerp helper for Color3
local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

-- ============================================================
--  QUORVYN LIBRARY
-- ============================================================

local Quorvyn = {}
Quorvyn.__index = Quorvyn

-- ============================================================
--  CreateWindow
-- ============================================================

function Quorvyn.CreateWindow(config: WindowConfig?)
	config = config or {}

	-- BUG FIX: renamed outer table to avoid shadowing with inner `self`
	local window: any = {}

	window.Name       = (config :: any).Name       or "Quorvyn"
	window.Team       = (config :: any).Team       or "Velora Forge"
	window.Accent     = (config :: any).Accent     or Color3.fromRGB(120, 154, 255)
	window.Background = (config :: any).Background or Color3.fromRGB(18, 20, 28)
	window.Secondary  = (config :: any).Secondary  or Color3.fromRGB(26, 29, 40)
	window.Text       = (config :: any).Text       or Color3.fromRGB(240, 243, 255)
	window.Corner     = (config :: any).Corner     or UDim.new(0, 16)
	window.UnloadKey  = (config :: any).UnloadKey  or Enum.KeyCode.RightShift

	window._connections = {} :: {RBXScriptConnection}
	window._destroyed   = false
	window._tabs        = {} :: {any}
	window._activeTab   = nil

	-- ── ScreenGui ────────────────────────────────────────────
	local gui = create("ScreenGui", {
		Name           = "Quorvyn_" .. window.Name,
		ResetOnSpawn   = false,
		IgnoreGuiInset = true,
		Parent         = PlayerGui,
	}) :: ScreenGui

	window.Gui = gui

	-- ── Notification Host ─────────────────────────────────────
	local notifHost = create("Frame", {
		Name                = "NotifHost",
		AnchorPoint         = Vector2.new(1, 1),
		Position            = UDim2.new(1, -18, 1, -18),
		Size                = UDim2.fromOffset(320, 0),
		BackgroundTransparency = 1,
		AutomaticSize       = Enum.AutomaticSize.Y,
		Parent              = gui,
	}) :: Frame

	local notifLayout = create("UIListLayout", {
		SortOrder           = Enum.SortOrder.LayoutOrder,
		FillDirection       = Enum.FillDirection.Vertical,
		VerticalAlignment   = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding             = UDim.new(0, 8),
		Parent              = notifHost,
	})

	-- ── Loader ───────────────────────────────────────────────
	local loader = create("Frame", {
		Name              = "Loader",
		AnchorPoint       = Vector2.new(0.5, 0.5),
		Position          = UDim2.fromScale(0.5, 0.5),
		Size              = UDim2.fromOffset(320, 152),
		BackgroundColor3  = window.Background,
		BorderSizePixel   = 0,
		Parent            = gui,
	}) :: Frame
	round(loader, 18)
	stroke(loader, window.Accent, 1, 0.45)
	gradient(loader, window.Background, window.Secondary, 45)

	local loaderScale = create("UIScale", {Scale = 0.94, Parent = loader})

	local loaderTitle = create("TextLabel", {
		Name                = "Title",
		BackgroundTransparency = 1,
		Position            = UDim2.fromOffset(18, 14),
		Size                = UDim2.new(1, -36, 0, 30),
		Font                = Enum.Font.GothamSemibold,
		Text                = window.Name,
		TextColor3          = window.Text,
		TextSize            = 21,
		TextXAlignment      = Enum.TextXAlignment.Left,
		Parent              = loader,
	})

	local loaderTeam = create("TextLabel", {
		Name                = "Team",
		BackgroundTransparency = 1,
		Position            = UDim2.fromOffset(18, 46),
		Size                = UDim2.new(1, -36, 0, 18),
		Font                = Enum.Font.Gotham,
		Text                = "Made by " .. window.Team,
		TextColor3          = Color3.fromRGB(170, 176, 196),
		TextSize            = 13,
		TextXAlignment      = Enum.TextXAlignment.Left,
		Parent              = loader,
	})

	local barBack = create("Frame", {
		Name              = "ProgressBack",
		AnchorPoint       = Vector2.new(0, 1),
		Position          = UDim2.new(0, 18, 1, -22),
		Size              = UDim2.new(1, -36, 0, 10),
		BackgroundColor3  = Color3.fromRGB(35, 38, 52),
		BorderSizePixel   = 0,
		Parent            = loader,
	})
	round(barBack, 999)

	local barFill = create("Frame", {
		Name             = "ProgressFill",
		Size             = UDim2.new(0.18, 0, 1, 0),
		BackgroundColor3 = window.Accent,
		BorderSizePixel  = 0,
		Parent           = barBack,
	})
	round(barFill, 999)
	gradient(barFill, window.Accent, Color3.fromRGB(255, 255, 255), 0)

	-- BUG FIX: Spinner gap now has BackgroundColor3 matching loader background
	-- so it visually cuts out the stroke ring segment
	local spinner = create("Frame", {
		Name                   = "Spinner",
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.new(1, -46, 1, -38),
		Size                   = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Parent                 = loader,
	}) :: Frame
	create("UIStroke", {
		Color             = window.Accent,
		Thickness         = 3,
		Transparency      = 0.1,
		ApplyStrokeMode   = Enum.ApplyStrokeMode.Border,
		Parent            = spinner,
	})
	create("UICorner",  {CornerRadius = UDim.new(1, 0), Parent = spinner})
	-- BUG FIX: Gap frame is transparent so it hides stroke cleanly
	create("Frame", {
		Name                   = "Gap",
		AnchorPoint            = Vector2.new(0.5, 0),
		Position               = UDim2.new(0.5, 0, 0, -2),
		Size                   = UDim2.new(0.35, 0, 0.2, 0),
		BackgroundColor3       = window.Background,
		BackgroundTransparency = 0,
		BorderSizePixel        = 0,
		Rotation               = 20,
		ZIndex                 = 5,
		Parent                 = spinner,
	})

	local spinnerRot = 0
	table.insert(window._connections, RunService.RenderStepped:Connect(function(dt: number)
		if window._destroyed then return end
		spinnerRot = (spinnerRot + dt * 300) % 360
		spinner.Rotation = spinnerRot
	end))

	local loadingTip = create("TextLabel", {
		Name                   = "Tip",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(18, 76),
		Size                   = UDim2.new(1, -86, 0, 26),
		Font                   = Enum.Font.Gotham,
		Text                   = "Starting interface...",
		TextColor3             = Color3.fromRGB(194, 200, 220),
		TextSize               = 13,
		TextXAlignment         = Enum.TextXAlignment.Left,
		Parent                 = loader,
	})

	-- BUG FIX: Loader fade-out now properly handles UIStroke by parenting it
	-- and removing via Destroy after fade, since UIStroke cannot be transparency-tweened
	task.spawn(function()
		local DURATION = 1.2
		local start    = os.clock()
		while os.clock() - start < DURATION do
			local p = math.clamp((os.clock() - start) / DURATION, 0, 1)
			barFill.Size = UDim2.new(0.18 + p * 0.82, 0, 1, 0)
			task.wait()
		end
		barFill.Size = UDim2.new(1, 0, 1, 0)

		Tween(loaderScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
		task.wait(0.14)

		local fadeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Tween(loader,     fadeInfo, {BackgroundTransparency = 1})
		Tween(loaderTitle,fadeInfo, {TextTransparency = 1})
		Tween(loaderTeam, fadeInfo, {TextTransparency = 1})
		Tween(loadingTip, fadeInfo, {TextTransparency = 1})
		Tween(barBack,    fadeInfo, {BackgroundTransparency = 1})
		Tween(barFill,    fadeInfo, {BackgroundTransparency = 1})
		-- UIStroke cannot be tweened via BackgroundTransparency; fade by property
		for _, d in ipairs(loader:GetDescendants()) do
			if d:IsA("UIStroke") then
				Tween(d, fadeInfo, {Transparency = 1})
			end
		end
		task.wait(0.32)
		if loader and loader.Parent then
			loader:Destroy()
		end
	end)

	-- ── Corner (minimized) button ─────────────────────────────
	local cornerButton = create("TextButton", {
		Name             = "MinimizedToggle",
		Visible          = false,
		AnchorPoint      = Vector2.new(0, 0.5),
		Position         = UDim2.new(0, 14, 0.5, 0),
		Size             = UDim2.fromOffset(128, 44),
		BackgroundColor3 = window.Secondary,
		BorderSizePixel  = 0,
		Text             = "",
		ZIndex           = 10,
		Parent           = gui,
	}) :: TextButton
	round(cornerButton, 999)
	stroke(cornerButton, window.Accent, 1, 0.25)
	gradient(cornerButton, window.Secondary, window.Background, 0)

	create("TextLabel", {
		Name                   = "CornerLabel",
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
		Font                   = Enum.Font.GothamSemibold,
		Text                   = window.Name,
		TextColor3             = window.Text,
		TextSize               = 13,
		TextWrapped            = false,
		Parent                 = cornerButton,
	})
	makeClickable(cornerButton, 1.03)

	-- ── Main frame ────────────────────────────────────────────
	local main = create("Frame", {
		Name             = "Main",
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Position         = UDim2.fromScale(0.5, 0.5),
		Size             = UDim2.fromOffset(580, 440),
		BackgroundColor3 = window.Background,
		BorderSizePixel  = 0,
		Visible          = true,
		Parent           = gui,
	}) :: Frame
	round(main, 18)
	stroke(main, window.Accent, 1, 0.55)
	gradient(main, window.Background, window.Secondary, 45)
	create("UIScale", {Scale = 1, Parent = main})

	-- ── Top bar ───────────────────────────────────────────────
	local top = create("Frame", {
		Name                   = "TopBar",
		Size                   = UDim2.new(1, 0, 0, 92),
		BackgroundTransparency = 1,
		Parent                 = main,
	}) :: Frame
	padding(top, 18, 18, 14, 12)

	local avatar = create("ImageLabel", {
		Name             = "Avatar",
		BackgroundColor3 = Color3.fromRGB(36, 39, 56),
		BorderSizePixel  = 0,
		Size             = UDim2.fromOffset(46, 46),
		Image            = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
		Parent           = top,
	})
	round(avatar, 999)
	stroke(avatar, window.Accent, 1, 0.75)

	create("TextLabel", {
		Name                   = "PlayerName",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(60, 26),
		Size                   = UDim2.new(1, -190, 0, 18),
		Font                   = Enum.Font.GothamMedium,
		Text                   = getPlayerDisplayName(),
		TextColor3             = Color3.fromRGB(214, 219, 232),
		TextSize               = 14,
		TextXAlignment         = Enum.TextXAlignment.Left,
		Parent                 = top,
	})

	create("TextLabel", {
		Name                   = "ScriptTitle",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(60, 5),
		Size                   = UDim2.new(1, -190, 0, 24),
		Font                   = Enum.Font.GothamBold,
		Text                   = window.Name,
		TextColor3             = window.Text,
		TextSize               = 22,
		TextXAlignment         = Enum.TextXAlignment.Left,
		Parent                 = top,
	})

	-- Minimize button
	local minimize = create("TextButton", {
		Name             = "Minimize",
		AnchorPoint      = Vector2.new(1, 0),
		Position         = UDim2.new(1, -42, 0, 0),
		Size             = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(34, 37, 50),
		BorderSizePixel  = 0,
		Text             = "—",
		TextColor3       = window.Text,
		TextSize         = 18,
		Font             = Enum.Font.GothamSemibold,
		Parent           = top,
	}) :: TextButton
	round(minimize, 999)
	stroke(minimize, window.Accent, 1, 0.72)
	makeClickable(minimize, 1.06)

	-- Close button
	local closeBtn = create("TextButton", {
		Name             = "Close",
		AnchorPoint      = Vector2.new(1, 0),
		Position         = UDim2.new(1, -2, 0, 0),
		Size             = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(55, 28, 36),
		BorderSizePixel  = 0,
		Text             = "×",
		TextColor3       = Color3.fromRGB(255, 225, 229),
		TextSize         = 24,
		Font             = Enum.Font.GothamSemibold,
		Parent           = top,
	}) :: TextButton
	round(closeBtn, 999)
	stroke(closeBtn, Color3.fromRGB(255, 105, 130), 1, 0.75)
	makeClickable(closeBtn, 1.06)

	-- ── Body ─────────────────────────────────────────────────
	local body = create("Frame", {
		Name                   = "Body",
		Position               = UDim2.fromOffset(0, 92),
		Size                   = UDim2.new(1, 0, 1, -92),
		BackgroundTransparency = 1,
		Parent                 = main,
	}) :: Frame
	padding(body, 16, 16, 0, 16)

	-- Tabs bar
	local tabsBar = create("Frame", {
		Name             = "TabsBar",
		Size             = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Color3.fromRGB(22, 25, 35),
		BorderSizePixel  = 0,
		Parent           = body,
	}) :: Frame
	round(tabsBar, 14)
	stroke(tabsBar, window.Accent, 1, 0.88)

	local tabsScroll = create("ScrollingFrame", {
		Name                  = "Tabs",
		BackgroundTransparency= 1,
		BorderSizePixel       = 0,
		Size                  = UDim2.new(1, -16, 1, 0),
		Position              = UDim2.fromOffset(8, 0),
		CanvasSize            = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness    = 0,
		AutomaticCanvasSize   = Enum.AutomaticSize.X,
		ScrollingDirection    = Enum.ScrollingDirection.X,
		Parent                = tabsBar,
	}) :: ScrollingFrame

	create("UIListLayout", {
		FillDirection       = Enum.FillDirection.Horizontal,
		Padding             = UDim.new(0, 8),
		SortOrder           = Enum.SortOrder.LayoutOrder,
		VerticalAlignment   = Enum.VerticalAlignment.Center,
		Parent              = tabsScroll,
	})
	create("UIPadding", {
		PaddingLeft  = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent       = tabsScroll,
	})

	-- Pages host
	local pagesHost = create("Frame", {
		Name                   = "PagesHost",
		Position               = UDim2.fromOffset(0, 58),
		Size                   = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		Parent                 = body,
	}) :: Frame

	-- ── Tab selection helper (BUG FIX: was broken) ───────────
	local function activateTab(targetTab: any)
		for _, t in ipairs(window._tabs) do
			t.Page.Visible = (t == targetTab)
			Tween(t.Button, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
				BackgroundColor3 = (t == targetTab) and window.Accent or Color3.fromRGB(30, 34, 47),
			})
			t.Button:SetAttribute("Active", t == targetTab)
		end
		window._activeTab = targetTab
	end

	-- ── Minimize logic ───────────────────────────────────────
	local minimized = false

	local function setMinimized(state: boolean)
		minimized = state
		main.Visible         = not state
		cornerButton.Visible = state
	end

	minimize.MouseButton1Click:Connect(function()
		setMinimized(true)
	end)
	cornerButton.MouseButton1Click:Connect(function()
		setMinimized(false)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		window:Destroy()
	end)

	-- BUG FIX: corner button now drags a fixed frame anchor, not itself
	makeDraggable(top, main)

	-- ── UnloadKey (BUG FIX: was defined but never connected) ─
	table.insert(window._connections, UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
		if gpe then return end
		if input.KeyCode == window.UnloadKey then
			setMinimized(not minimized)
		end
	end))

	-- ── Expose references ─────────────────────────────────────
	window.Main       = main
	window.CornerButton = cornerButton
	window.PagesHost  = pagesHost
	window.TabsBar    = tabsScroll

	-- ===========================================================
	--  Notify  (NEW)
	-- ===========================================================
	function window:Notify(title: string, description: string?, duration: number?)
		local dur     = duration or 4
		local notif   = create("Frame", {
			Name             = "Notif",
			BackgroundColor3 = self.Secondary,
			BorderSizePixel  = 0,
			Size             = UDim2.new(1, 0, 0, 0),
			AutomaticSize    = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0.1,
			Parent           = notifHost,
		}) :: Frame
		round(notif, 14)
		stroke(notif, self.Accent, 1, 0.5)
		gradient(notif, self.Secondary, self.Background, 90)
		padding(notif, 14, 14, 12, 12)

		create("TextLabel", {
			Name                   = "NTitle",
			BackgroundTransparency = 1,
			Size                   = UDim2.new(1, -24, 0, 20),
			Font                   = Enum.Font.GothamSemibold,
			Text                   = title,
			TextColor3             = self.Text,
			TextSize               = 15,
			TextXAlignment         = Enum.TextXAlignment.Left,
			Parent                 = notif,
		})

		if description and #description > 0 then
			create("TextLabel", {
				Name                   = "NDesc",
				BackgroundTransparency = 1,
				Position               = UDim2.fromOffset(0, 24),
				Size                   = UDim2.new(1, 0, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				Font                   = Enum.Font.Gotham,
				Text                   = description,
				TextColor3             = Color3.fromRGB(180, 186, 202),
				TextSize               = 13,
				TextXAlignment         = Enum.TextXAlignment.Left,
				TextWrapped            = true,
				Parent                 = notif,
			})
		end

		-- Timer bar
		local timerBack = create("Frame", {
			Name             = "TimerBack",
			AnchorPoint      = Vector2.new(0, 1),
			Position         = UDim2.new(0, 0, 1, 0),
			Size             = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = Color3.fromRGB(40, 44, 60),
			BorderSizePixel  = 0,
			Parent           = notif,
		})
		round(timerBack, 999)
		local timerFill = create("Frame", {
			Size             = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = self.Accent,
			BorderSizePixel  = 0,
			Parent           = timerBack,
		})
		round(timerFill, 999)

		-- Slide in
		local notifScale = create("UIScale", {Scale = 0.92, Parent = notif})
		Tween(notifScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})

		-- Timer tween
		Tween(timerFill, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)})

		task.spawn(function()
			task.wait(dur)
			if notif and notif.Parent then
				Tween(notifScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.88})
				Tween(notif, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
				task.wait(0.22)
				notif:Destroy()
			end
		end)

		return notif
	end

	-- ===========================================================
	--  SetTheme  (NEW)
	-- ===========================================================
	function window:SetTheme(accent: Color3?, background: Color3?, secondary: Color3?, text: Color3?)
		self.Accent     = accent     or self.Accent
		self.Background = background or self.Background
		self.Secondary  = secondary  or self.Secondary
		self.Text       = text       or self.Text
		-- Notify the user
		self:Notify("Theme Updated", "Your UI theme has been changed.")
	end

	-- ===========================================================
	--  CreateTab
	-- ===========================================================
	function window:CreateTab(tabName: string)
		-- BUG FIX: capture window reference so all tab methods use the correct
		-- `self` (the window), not the tab table
		local W = self

		local tabButton = create("TextButton", {
			Name             = tabName .. "TabButton",
			Size             = UDim2.fromOffset(114, 34),
			BackgroundColor3 = Color3.fromRGB(30, 34, 47),
			BorderSizePixel  = 0,
			Text             = tabName,
			TextColor3       = Color3.fromRGB(217, 223, 240),
			TextSize         = 13,
			Font             = Enum.Font.GothamSemibold,
			Parent           = tabsScroll,
		}) :: TextButton
		round(tabButton, 999)
		stroke(tabButton, W.Accent, 1, 0.84)
		makeClickable(tabButton, 1.04)

		local page = create("ScrollingFrame", {
			Name                  = tabName .. "Page",
			BackgroundTransparency= 1,
			BorderSizePixel       = 0,
			Size                  = UDim2.fromScale(1, 1),
			CanvasSize            = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize   = Enum.AutomaticSize.Y,
			ScrollBarThickness    = 4,
			ScrollBarImageColor3  = W.Accent,
			Visible               = false,
			Parent                = pagesHost,
		}) :: ScrollingFrame

		create("UIPadding", {
			PaddingTop   = UDim.new(0, 4),
			PaddingBottom= UDim.new(0, 4),
			PaddingLeft  = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 8),
			Parent       = page,
		})

		-- BUG FIX: removed duplicate UIListLayout — only one layout on the
		-- container, not both `page` and `container`
		local container = create("Frame", {
			Name                   = tabName .. "Container",
			BackgroundTransparency = 1,
			Size                   = UDim2.new(1, -4, 0, 0),
			AutomaticSize          = Enum.AutomaticSize.Y,
			Parent                 = page,
		}) :: Frame
		create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding   = UDim.new(0, 10),
			Parent    = container,
		})

		local tab: any = {
			Name      = tabName,
			Page      = page,
			Container = container,
			Button    = tabButton,
			Elements  = {},
		}

		-- ── Element Card builder ──────────────────────────────
		local function elementCard(height: number, titleText: string?, subtitleText: string?): Frame
			local card = create("Frame", {
				BackgroundColor3 = Color3.fromRGB(24, 27, 37),
				BorderSizePixel  = 0,
				Size             = UDim2.new(1, 0, 0, height),
				AutomaticSize    = Enum.AutomaticSize.None,
				Parent           = container,
			}) :: Frame
			round(card, 16)
			stroke(card, W.Accent, 1, 0.90)
			padding(card, 14, 14, 12, 12)

			if titleText then
				create("TextLabel", {
					Name                   = "CardTitle",
					BackgroundTransparency = 1,
					Size                   = UDim2.new(1, -8, 0, 18),
					Font                   = Enum.Font.GothamSemibold,
					Text                   = titleText,
					TextColor3             = W.Text,
					TextSize               = 15,
					TextXAlignment         = Enum.TextXAlignment.Left,
					Parent                 = card,
				})
			end
			if subtitleText then
				create("TextLabel", {
					Name                   = "CardSubtitle",
					BackgroundTransparency = 1,
					Position               = UDim2.fromOffset(0, 20),
					Size                   = UDim2.new(1, -8, 0, 16),
					Font                   = Enum.Font.Gotham,
					Text                   = subtitleText,
					TextColor3             = Color3.fromRGB(155, 162, 180),
					TextSize               = 12,
					TextXAlignment         = Enum.TextXAlignment.Left,
					Parent                 = card,
				})
			end
			return card
		end

		local function addBody(card: Frame, offsetY: number?): Frame
			return create("Frame", {
				Name                   = "Body",
				BackgroundTransparency = 1,
				Position               = UDim2.fromOffset(0, offsetY or 38),
				Size                   = UDim2.new(1, 0, 1, -(offsetY or 38)),
				Parent                 = card,
			}) :: Frame
		end

		-- ── AddSection  (NEW) ─────────────────────────────────
		function tab:AddSection(sectionName: string)
			local wrapper = create("Frame", {
				BackgroundTransparency = 1,
				Size                   = UDim2.new(1, 0, 0, 28),
				Parent                 = container,
			}) :: Frame

			create("TextLabel", {
				BackgroundTransparency = 1,
				Size                   = UDim2.new(0.5, 0, 1, 0),
				Font                   = Enum.Font.GothamBold,
				Text                   = sectionName,
				TextColor3             = W.Accent,
				TextSize               = 13,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = wrapper,
			})

			local line = create("Frame", {
				AnchorPoint      = Vector2.new(0, 0.5),
				Position         = UDim2.new(0, 0, 0.5, 0),
				Size             = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = W.Accent,
				BackgroundTransparency = 0.7,
				BorderSizePixel  = 0,
				ZIndex           = 0,
				Parent           = wrapper,
			})
			round(line, 999)
			return wrapper
		end

		-- ── AddSeparator  (NEW) ───────────────────────────────
		function tab:AddSeparator()
			local sep = create("Frame", {
				BackgroundColor3       = W.Accent,
				BackgroundTransparency = 0.8,
				BorderSizePixel        = 0,
				Size                   = UDim2.new(1, 0, 0, 1),
				Parent                 = container,
			}) :: Frame
			round(sep, 999)
			return sep
		end

		-- ── AddLabel ─────────────────────────────────────────
		function tab:AddLabel(text: string, description: string?)
			local card = elementCard(description and 84 or 58, text, description)
			return card
		end

		-- ── AddParagraph ─────────────────────────────────────
		function tab:AddParagraph(text: string, content: string)
			local card = elementCard(0, text, nil)
			card.AutomaticSize = Enum.AutomaticSize.Y
			create("TextLabel", {
				BackgroundTransparency = 1,
				Position               = UDim2.fromOffset(0, 32),
				Size                   = UDim2.new(1, 0, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				Font                   = Enum.Font.Gotham,
				Text                   = content,
				TextWrapped            = true,
				TextYAlignment         = Enum.TextYAlignment.Top,
				TextXAlignment         = Enum.TextXAlignment.Left,
				TextColor3             = Color3.fromRGB(185, 191, 208),
				TextSize               = 13,
				Parent                 = card,
			})
			return card
		end

		-- ── AddButton ────────────────────────────────────────
		-- BUG FIX: was referencing `self.Accent` inside a tab method;
		-- `self` here is the tab table, not the window. Use captured `W`.
		function tab:AddButton(text: string, callback: (() -> ())?)
			local card      = elementCard(70, text, nil)
			local bodyFrame = addBody(card, 34)
			local btn = create("TextButton", {
				Size             = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = W.Accent,
				BorderSizePixel  = 0,
				Text             = text,
				TextColor3       = Color3.new(1, 1, 1),
				TextSize         = 14,
				Font             = Enum.Font.GothamSemibold,
				Parent           = bodyFrame,
			}) :: TextButton
			round(btn, 14)
			gradient(btn, W.Accent, lerpColor(W.Accent, Color3.new(1,1,1), 0.28), 90)
			makeClickable(btn, 1.02)
			btn.MouseButton1Click:Connect(function()
				if callback then
					local ok, err = pcall(callback)
					if not ok then
						warn("[Quorvyn] Button callback error:", err)
					end
				end
			end)
			return btn
		end

		-- ── AddToggle ────────────────────────────────────────
		function tab:AddToggle(text: string, defaultValue: boolean?, callback: Callback<boolean>?): ToggleObject
			local card      = elementCard(68, text, nil)
			local bodyFrame = addBody(card, 32)

			local offColor  = Color3.fromRGB(55, 60, 80)
			local state     = defaultValue == true

			local switch = create("TextButton", {
				AnchorPoint      = Vector2.new(1, 0.5),
				Position         = UDim2.new(1, 0, 0.5, 0),
				Size             = UDim2.fromOffset(56, 30),
				BackgroundColor3 = state and W.Accent or offColor,
				BorderSizePixel  = 0,
				Text             = "",
				Parent           = bodyFrame,
			}) :: TextButton
			round(switch, 999)

			local knob = create("Frame", {
				AnchorPoint      = Vector2.new(0.5, 0.5),
				Position         = state and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 15, 0.5, 0),
				Size             = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel  = 0,
				Parent           = switch,
			}) :: Frame
			round(knob, 999)

			local tweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			local function setState(value: boolean)
				state = value
				Tween(switch, tweenInfo, {BackgroundColor3 = value and W.Accent or offColor})
				Tween(knob,   tweenInfo, {Position = value and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 15, 0.5, 0)})
				if callback then
					local ok, err = pcall(callback, value)
					if not ok then warn("[Quorvyn] Toggle callback error:", err) end
				end
			end

			switch.MouseButton1Click:Connect(function()
				setState(not state)
			end)

			return {
				Set = setState,
				Get = function() return state end,
			}
		end

		-- ── AddTextbox ───────────────────────────────────────
		function tab:AddTextbox(text: string, placeholder: string?, callback: Callback<string>?): TextboxObject
			local card      = elementCard(88, text, nil)
			local bodyFrame = addBody(card, 34)

			local box = create("TextBox", {
				Size                 = UDim2.new(1, 0, 0, 36),
				Position             = UDim2.fromOffset(0, 2),
				BackgroundColor3     = Color3.fromRGB(30, 34, 47),
				BorderSizePixel      = 0,
				ClearTextOnFocus     = false,
				Text                 = "",
				PlaceholderText      = placeholder or "Enter text...",
				TextColor3           = W.Text,
				PlaceholderColor3    = Color3.fromRGB(130, 136, 154),
				TextSize             = 14,
				Font                 = Enum.Font.Gotham,
				Parent               = bodyFrame,
			}) :: TextBox
			round(box, 12)
			stroke(box, W.Accent, 1, 0.88)

			-- Highlight on focus
			box.Focused:Connect(function()
				Tween(box, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(34, 38, 56)})
			end)
			box.FocusLost:Connect(function(enterPressed: boolean)
				Tween(box, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30, 34, 47)})
				if callback then
					local ok, err = pcall(callback, box.Text)
					if not ok then warn("[Quorvyn] Textbox callback error:", err) end
				end
			end)

			return {
				Set = function(v: string) box.Text = v end,
				Get = function() return box.Text end,
			}
		end

		-- ── AddSlider ────────────────────────────────────────
		function tab:AddSlider(text: string, minValue: number, maxValue: number, defaultValue: number?, callback: Callback<number>?): SliderObject
			local range    = math.max(1, maxValue - minValue)
			local defVal   = math.clamp(defaultValue or minValue, minValue, maxValue)
			local card     = elementCard(96, text, string.format("Range: %g – %g", minValue, maxValue))
			local bodyFrame= addBody(card, 44)

			local track = create("Frame", {
				Position         = UDim2.new(0, 0, 0, 16),
				Size             = UDim2.new(1, 0, 0, 8),
				BackgroundColor3 = Color3.fromRGB(36, 40, 55),
				BorderSizePixel  = 0,
				Parent           = bodyFrame,
			}) :: Frame
			round(track, 999)

			local fill = create("Frame", {
				Size             = UDim2.fromScale(0, 1),
				BackgroundColor3 = W.Accent,
				BorderSizePixel  = 0,
				Parent           = track,
			}) :: Frame
			round(fill, 999)
			gradient(fill, W.Accent, lerpColor(W.Accent, Color3.new(1,1,1), 0.3), 0)

			local knob = create("Frame", {
				AnchorPoint      = Vector2.new(0.5, 0.5),
				Position         = UDim2.new(0, 0, 0.5, 0),
				Size             = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel  = 0,
				Parent           = track,
			}) :: Frame
			round(knob, 999)
			stroke(knob, W.Accent, 1, 0.8)

			local valueLabel = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint            = Vector2.new(1, 1),
				Position               = UDim2.new(1, 0, 0, 12),
				Size                   = UDim2.fromOffset(72, 18),
				Font                   = Enum.Font.GothamSemibold,
				Text                   = tostring(defVal),
				TextColor3             = W.Text,
				TextSize               = 13,
				TextXAlignment         = Enum.TextXAlignment.Right,
				Parent                 = bodyFrame,
			})

			local currentValue = defVal
			local draggingSlider = false

			local function setValue(num: number)
				currentValue = math.clamp(math.floor(num + 0.5), minValue, maxValue)
				local alpha = (currentValue - minValue) / range
				fill.Size        = UDim2.new(alpha, 0, 1, 0)
				knob.Position    = UDim2.new(alpha, 0, 0.5, 0)
				valueLabel.Text  = tostring(currentValue)
				if callback then
					local ok, err = pcall(callback, currentValue)
					if not ok then warn("[Quorvyn] Slider callback error:", err) end
				end
			end

			local function updateFromX(x: number)
				local ap = track.AbsolutePosition.X
				local as = track.AbsoluteSize.X
				if as <= 0 then return end
				setValue(minValue + ((x - ap) / as) * range)
			end

			track.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					draggingSlider = true
					updateFromX(input.Position.X)
				end
			end)
			track.InputEnded:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					draggingSlider = false
				end
			end)
			table.insert(W._connections, UserInputService.InputChanged:Connect(function(input: InputObject)
				if draggingSlider and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				) then
					updateFromX(input.Position.X)
				end
			end))

			setValue(defVal)

			return {
				Set = setValue,
				Get = function() return currentValue end,
			}
		end

		-- ── AddDropdown ──────────────────────────────────────
		function tab:AddDropdown(text: string, options: {string}, callback: Callback<string>?, defaultValue: string?): DropdownObject
			local selected = defaultValue or (options[1] or "")
			local open     = false

			local card     = elementCard(80, text, nil)
			local bodyFrame= addBody(card, 36)

			local button = create("TextButton", {
				Size             = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.fromRGB(30, 34, 47),
				BorderSizePixel  = 0,
				Text             = selected ~= "" and selected or "Select...",
				TextColor3       = W.Text,
				TextSize         = 14,
				Font             = Enum.Font.Gotham,
				Parent           = bodyFrame,
			}) :: TextButton
			round(button, 12)
			stroke(button, W.Accent, 1, 0.88)

			-- Arrow icon
			local arrow = create("TextLabel", {
				Name                   = "Arrow",
				BackgroundTransparency = 1,
				AnchorPoint            = Vector2.new(1, 0.5),
				Position               = UDim2.new(1, -10, 0.5, 0),
				Size                   = UDim2.fromOffset(18, 18),
				Font                   = Enum.Font.GothamBold,
				Text                   = "▾",
				TextColor3             = W.Accent,
				TextSize               = 14,
				Parent                 = button,
			})

			local listHolder = create("Frame", {
				Visible          = false,
				ClipsDescendants = true,
				BackgroundColor3 = Color3.fromRGB(22, 25, 35),
				BorderSizePixel  = 0,
				Position         = UDim2.fromOffset(0, 42),
				Size             = UDim2.new(1, 0, 0, 64),
				ZIndex           = 10,
				Parent           = bodyFrame,
			}) :: Frame
			round(listHolder, 12)
			stroke(listHolder, W.Accent, 1, 0.88)

			local search = create("TextBox", {
				Size              = UDim2.new(1, -10, 0, 26),
				Position          = UDim2.fromOffset(5, 6),
				BackgroundColor3  = Color3.fromRGB(30, 34, 47),
				BorderSizePixel   = 0,
				Text              = "",
				PlaceholderText   = "Search...",
				PlaceholderColor3 = Color3.fromRGB(130, 136, 154),
				TextColor3        = W.Text,
				TextSize          = 13,
				Font              = Enum.Font.Gotham,
				ClearTextOnFocus  = false,
				ZIndex            = 11,
				Parent            = listHolder,
			}) :: TextBox
			round(search, 10)

			local scrolling = create("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				Position               = UDim2.fromOffset(0, 38),
				Size                   = UDim2.new(1, 0, 1, -38),
				CanvasSize             = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize    = Enum.AutomaticSize.Y,
				ScrollBarThickness     = 3,
				ScrollBarImageColor3   = W.Accent,
				ZIndex                 = 11,
				Parent                 = listHolder,
			}) :: ScrollingFrame
			create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = scrolling})
			create("UIPadding",   {PaddingLeft = UDim.new(0,6), PaddingRight = UDim.new(0,6), PaddingBottom = UDim.new(0,6), Parent = scrolling})

			local function rebuild(filter: string)
				for _, child in ipairs(scrolling:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				local count = 0
				for _, option in ipairs(options) do
					if filter == "" or string.find(string.lower(option), string.lower(filter), 1, true) then
						count += 1
						local opt = create("TextButton", {
							Size             = UDim2.new(1, 0, 0, 28),
							BackgroundColor3 = option == selected and W.Accent or Color3.fromRGB(30, 34, 47),
							BorderSizePixel  = 0,
							Text             = option,
							TextColor3       = Color3.new(1,1,1),
							TextSize         = 13,
							Font             = Enum.Font.GothamSemibold,
							ZIndex           = 12,
							Parent           = scrolling,
						}) :: TextButton
						round(opt, 10)
						opt.MouseButton1Click:Connect(function()
							selected       = option
							button.Text    = selected
							listHolder.Visible = false
							open           = false
							arrow.Rotation = 0
							card.Size      = UDim2.new(1, 0, 0, 80)
							if callback then pcall(callback, selected) end
							rebuild(search.Text)
						end)
					end
				end
				local listH = math.clamp(38 + count * 32 + 6, 64, 200)
				listHolder.Size = UDim2.new(1, 0, 0, listH)
				card.Size       = UDim2.new(1, 0, 0, open and (80 + listH + 8) or 80)
			end

			search:GetPropertyChangedSignal("Text"):Connect(function()
				rebuild(search.Text)
			end)

			button.MouseButton1Click:Connect(function()
				open = not open
				listHolder.Visible = open
				Tween(arrow, TweenInfo.new(0.14), {Rotation = open and 180 or 0})
				if open then rebuild(search.Text) end
			end)

			rebuild("")

			return {
				Set = function(v: string)
					selected    = v
					button.Text = v
					if callback then pcall(callback, v) end
				end,
				Get = function() return selected end,
			}
		end

		-- ── AddMultiDropdown ─────────────────────────────────
		function tab:AddMultiDropdown(text: string, options: {string}, callback: Callback<{string}>?, defaultValues: {string}?): MultiDropdownObject
			local selectedSet: {[string]: boolean} = {}
			if defaultValues then
				for _, v in ipairs(defaultValues) do selectedSet[v] = true end
			end

			local card      = elementCard(80, text, nil)
			local bodyFrame = addBody(card, 36)

			local button = create("TextButton", {
				Size             = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.fromRGB(30, 34, 47),
				BorderSizePixel  = 0,
				Text             = "Select...",
				TextColor3       = W.Text,
				TextSize         = 14,
				Font             = Enum.Font.Gotham,
				Parent           = bodyFrame,
			}) :: TextButton
			round(button, 12)
			stroke(button, W.Accent, 1, 0.88)

			local arrow = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint            = Vector2.new(1, 0.5),
				Position               = UDim2.new(1, -10, 0.5, 0),
				Size                   = UDim2.fromOffset(18, 18),
				Font                   = Enum.Font.GothamBold,
				Text                   = "▾",
				TextColor3             = W.Accent,
				TextSize               = 14,
				Parent                 = button,
			})

			local listHolder = create("Frame", {
				Visible          = false,
				ClipsDescendants = true,
				BackgroundColor3 = Color3.fromRGB(22, 25, 35),
				BorderSizePixel  = 0,
				Position         = UDim2.fromOffset(0, 42),
				Size             = UDim2.new(1, 0, 0, 104),
				ZIndex           = 10,
				Parent           = bodyFrame,
			}) :: Frame
			round(listHolder, 12)
			stroke(listHolder, W.Accent, 1, 0.88)

			local search = create("TextBox", {
				Size              = UDim2.new(1, -10, 0, 26),
				Position          = UDim2.fromOffset(5, 6),
				BackgroundColor3  = Color3.fromRGB(30, 34, 47),
				BorderSizePixel   = 0,
				Text              = "",
				PlaceholderText   = "Search...",
				PlaceholderColor3 = Color3.fromRGB(130, 136, 154),
				TextColor3        = W.Text,
				TextSize          = 13,
				Font              = Enum.Font.Gotham,
				ClearTextOnFocus  = false,
				ZIndex            = 11,
				Parent            = listHolder,
			}) :: TextBox
			round(search, 10)

			local scrolling = create("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				Position               = UDim2.fromOffset(0, 38),
				Size                   = UDim2.new(1, 0, 1, -38),
				CanvasSize             = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize    = Enum.AutomaticSize.Y,
				ScrollBarThickness     = 3,
				ScrollBarImageColor3   = W.Accent,
				ZIndex                 = 11,
				Parent                 = listHolder,
			}) :: ScrollingFrame
			create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = scrolling})
			create("UIPadding",   {PaddingLeft = UDim.new(0,6), PaddingRight = UDim.new(0,6), PaddingBottom = UDim.new(0,6), Parent = scrolling})

			local function getArray(): {string}
				local arr = {}
				for _, o in ipairs(options) do
					if selectedSet[o] then table.insert(arr, o) end
				end
				return arr
			end

			local function refreshText()
				local arr = getArray()
				button.Text = #arr > 0 and table.concat(arr, ", ") or "Select..."
			end

			local function rebuild(filter: string)
				for _, child in ipairs(scrolling:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				local count = 0
				for _, option in ipairs(options) do
					if filter == "" or string.find(string.lower(option), string.lower(filter), 1, true) then
						count += 1
						local isOn = selectedSet[option] == true
						local opt = create("TextButton", {
							Size             = UDim2.new(1, 0, 0, 28),
							BackgroundColor3 = isOn and W.Accent or Color3.fromRGB(30, 34, 47),
							BorderSizePixel  = 0,
							Text             = (isOn and "✓  " or "    ") .. option,
							TextColor3       = Color3.new(1,1,1),
							TextSize         = 13,
							Font             = Enum.Font.GothamSemibold,
							ZIndex           = 12,
							Parent           = scrolling,
						}) :: TextButton
						round(opt, 10)
						opt.MouseButton1Click:Connect(function()
							selectedSet[option] = not selectedSet[option]
							refreshText()
							rebuild(search.Text)
							if callback then pcall(callback, getArray()) end
						end)
					end
				end
				local listH = math.clamp(38 + count * 32 + 6, 64, 220)
				listHolder.Size = UDim2.new(1, 0, 0, listH)
				card.Size = UDim2.new(1, 0, 0, listHolder.Visible and (80 + listH + 8) or 80)
			end

			search:GetPropertyChangedSignal("Text"):Connect(function()
				rebuild(search.Text)
			end)

			button.MouseButton1Click:Connect(function()
				listHolder.Visible = not listHolder.Visible
				Tween(arrow, TweenInfo.new(0.14), {Rotation = listHolder.Visible and 180 or 0})
				if listHolder.Visible then rebuild(search.Text) end
			end)

			refreshText()
			rebuild("")

			return { Get = getArray }
		end

		-- ── AddKeybind  (NEW) ─────────────────────────────────
		function tab:AddKeybind(text: string, defaultKey: Enum.KeyCode?, callback: Callback<Enum.KeyCode>?): KeybindObject
			local currentKey = defaultKey or Enum.KeyCode.Unknown
			local listening  = false
			local card       = elementCard(68, text, nil)
			local bodyFrame  = addBody(card, 34)

			local keyBtn = create("TextButton", {
				AnchorPoint      = Vector2.new(1, 0.5),
				Position         = UDim2.new(1, 0, 0.5, 0),
				Size             = UDim2.fromOffset(100, 30),
				BackgroundColor3 = Color3.fromRGB(30, 34, 47),
				BorderSizePixel  = 0,
				Text             = currentKey.Name,
				TextColor3       = W.Accent,
				TextSize         = 13,
				Font             = Enum.Font.GothamSemibold,
				Parent           = bodyFrame,
			}) :: TextButton
			round(keyBtn, 10)
			stroke(keyBtn, W.Accent, 1, 0.82)

			keyBtn.MouseButton1Click:Connect(function()
				if listening then return end
				listening       = true
				keyBtn.Text     = "..."
				keyBtn.TextColor3 = Color3.fromRGB(240, 200, 100)
			end)

			table.insert(W._connections, UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
				if not listening then return end
				if gpe then return end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				listening         = false
				currentKey        = input.KeyCode
				keyBtn.Text       = currentKey.Name
				keyBtn.TextColor3 = W.Accent
				if callback then pcall(callback, currentKey) end
			end))

			return {
				Set = function(key: Enum.KeyCode)
					currentKey    = key
					keyBtn.Text   = key.Name
				end,
				Get = function() return currentKey end,
			}
		end

		-- ── AddColorPicker  (NEW) ─────────────────────────────
		function tab:AddColorPicker(text: string, defaultColor: Color3?, callback: Callback<Color3>?)
			local currentColor = defaultColor or Color3.fromRGB(255, 100, 100)
			local open = false
			local card = elementCard(70, text, nil)
			local bodyFrame = addBody(card, 34)

			local preview = create("TextButton", {
				AnchorPoint      = Vector2.new(1, 0.5),
				Position         = UDim2.new(1, 0, 0.5, 0),
				Size             = UDim2.fromOffset(50, 28),
				BackgroundColor3 = currentColor,
				BorderSizePixel  = 0,
				Text             = "",
				Parent           = bodyFrame,
			}) :: TextButton
			round(preview, 10)
			stroke(preview, W.Accent, 1, 0.75)

			-- Expanded picker panel
			local picker = create("Frame", {
				Visible          = false,
				BackgroundColor3 = Color3.fromRGB(22, 25, 35),
				BorderSizePixel  = 0,
				Position         = UDim2.fromOffset(0, 38),
				Size             = UDim2.new(1, 0, 0, 120),
				ClipsDescendants = true,
				ZIndex           = 10,
				Parent           = bodyFrame,
			}) :: Frame
			round(picker, 14)
			stroke(picker, W.Accent, 1, 0.85)
			padding(picker, 10, 10, 10, 10)

			local sliderTitles = {"R", "G", "B"}
			local channels     = {currentColor.R * 255, currentColor.G * 255, currentColor.B * 255}
			local channelSliders: {Frame} = {}

			local pickerLayout = create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding   = UDim.new(0, 6),
				Parent    = picker,
			})

			local function rebuildColor()
				currentColor        = Color3.fromRGB(
					math.floor(channels[1]),
					math.floor(channels[2]),
					math.floor(channels[3])
				)
				preview.BackgroundColor3 = currentColor
				if callback then pcall(callback, currentColor) end
			end

			for i, label in ipairs(sliderTitles) do
				local row = create("Frame", {
					BackgroundTransparency = 1,
					Size                   = UDim2.new(1, 0, 0, 22),
					LayoutOrder            = i,
					Parent                 = picker,
				}) :: Frame
				create("UIListLayout", {
					FillDirection       = Enum.FillDirection.Horizontal,
					VerticalAlignment   = Enum.VerticalAlignment.Center,
					Padding             = UDim.new(0, 6),
					Parent              = row,
				})
				create("TextLabel", {
					BackgroundTransparency = 1,
					Size                   = UDim2.fromOffset(14, 20),
					Font                   = Enum.Font.GothamBold,
					Text                   = label,
					TextColor3             = W.Accent,
					TextSize               = 12,
					Parent                 = row,
				})
				local track = create("Frame", {
					BackgroundColor3 = Color3.fromRGB(36, 40, 55),
					BorderSizePixel  = 0,
					Size             = UDim2.new(1, -56, 0, 8),
					Parent           = row,
				}) :: Frame
				round(track, 999)
				local fill = create("Frame", {
					Size             = UDim2.fromScale(channels[i] / 255, 1),
					BackgroundColor3 = W.Accent,
					BorderSizePixel  = 0,
					Parent           = track,
				}) :: Frame
				round(fill, 999)
				local valLabel = create("TextLabel", {
					BackgroundTransparency = 1,
					Size                   = UDim2.fromOffset(30, 20),
					Font                   = Enum.Font.GothamSemibold,
					Text                   = tostring(math.floor(channels[i])),
					TextColor3             = W.Text,
					TextSize               = 11,
					Parent                 = row,
				})

				local chanDragging = false
				local idx = i
				track.InputBegan:Connect(function(inp: InputObject)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						chanDragging = true
						local alpha = math.clamp((inp.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
						channels[idx] = alpha * 255
						fill.Size = UDim2.fromScale(alpha, 1)
						valLabel.Text = tostring(math.floor(channels[idx]))
						rebuildColor()
					end
				end)
				track.InputEnded:Connect(function(inp: InputObject)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						chanDragging = false
					end
				end)
				table.insert(W._connections, UserInputService.InputChanged:Connect(function(inp: InputObject)
					if chanDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
						local alpha = math.clamp((inp.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
						channels[idx] = alpha * 255
						fill.Size = UDim2.fromScale(alpha, 1)
						valLabel.Text = tostring(math.floor(channels[idx]))
						rebuildColor()
					end
				end))

				table.insert(channelSliders, track)
			end

			preview.MouseButton1Click:Connect(function()
				open = not open
				picker.Visible = open
				card.Size = UDim2.new(1, 0, 0, open and 202 or 70)
			end)

			return {
				Set = function(c: Color3)
					currentColor        = c
					preview.BackgroundColor3 = c
					channels = {c.R * 255, c.G * 255, c.B * 255}
				end,
				Get = function() return currentColor end,
			}
		end

		-- ── Tab button click → activate ───────────────────────
		tabButton.MouseButton1Click:Connect(function()
			activateTab(tab)
		end)

		table.insert(W._tabs, tab)

		-- Auto-select the first tab
		if not W._activeTab then
			activateTab(tab)
		end

		-- ── tab:Destroy  (NEW) ────────────────────────────────
		function tab:Destroy()
			if self.Button  and self.Button.Parent  then self.Button:Destroy()  end
			if self.Page    and self.Page.Parent    then self.Page:Destroy()    end
			-- Remove from window tab list
			for i, t in ipairs(W._tabs) do
				if t == self then
					table.remove(W._tabs, i)
					break
				end
			end
			-- Select first remaining tab if this was active
			if W._activeTab == self and #W._tabs > 0 then
				activateTab(W._tabs[1])
			end
		end

		return tab
	end -- CreateTab

	-- ── Destroy ──────────────────────────────────────────────
	function window:Destroy()
		if self._destroyed then return end
		self._destroyed = true
		for _, conn in ipairs(self._connections) do
			if conn then conn:Disconnect() end
		end
		table.clear(self._connections)
		if self.Gui and self.Gui.Parent then
			self.Gui:Destroy()
		end
	end

	-- ── MinimizeState (public helper) ─────────────────────────
	function window:MinimizeState(enabled: boolean)
		setMinimized(enabled)
	end

	-- Animate main in on first load
	local mainScale = main:FindFirstChildOfClass("UIScale")
	if mainScale then
		mainScale.Scale = 0.94
		task.delay(1.5, function()
			Tween(mainScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
		end)
	end

	return window
end

return Quorvyn
