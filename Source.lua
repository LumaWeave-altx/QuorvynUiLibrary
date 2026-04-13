--!strict
-- Quorvyn UI Library v2.0
-- A robust, modular, and mobile-optimized UI library for Roblox

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Quorvyn = {}
Quorvyn.__index = Quorvyn

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

type Callback<T> = (T) -> ()
type Element = { Destroy: (Element) -> () }

--// Utility Functions
local function create(className: string, props: {[any]: any}?): Instance
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
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
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		Parent = instance,
	})
end

local function listLayout(parent: Instance, sortOrder: Enum.SortOrder?, paddingValue: number?)
	create("UIListLayout", {
		SortOrder = sortOrder or Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, paddingValue or 8),
		Parent = parent,
	})
end

local function gradient(parent: Instance, c1: Color3, c2: Color3, rotation: number?)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(1, c2),
		}),
		Rotation = rotation or 0,
		Parent = parent,
	})
end

local function Tween(object: Instance, info: TweenInfo, goal: {[string]: any})
	local t = TweenService:Create(object, info, goal)
	t:Play()
	return t
end

local function makeDraggable(dragHandle: GuiObject, target: GuiObject)
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos = UDim2.new()

	local function update(input: InputObject)
		local delta = input.Position - dragStart
		target.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			update(input)
		end
	end)
end

local function makeClickable(button: GuiButton, scaleAmount: number?)
	local scale = create("UIScale", {Scale = 1, Parent = button})
	button.AutoButtonColor = false
	button.MouseEnter:Connect(function()
		Tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = scaleAmount or 1.03})
	end)
	button.MouseLeave:Connect(function()
		Tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
	end)
	button.MouseButton1Down:Connect(function()
		Tween(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.97})
	end)
	button.MouseButton1Up:Connect(function()
		Tween(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = scaleAmount or 1.03})
	end)
end

local function formatPlayerName()
	if LocalPlayer.DisplayName and LocalPlayer.DisplayName ~= "" then
		return LocalPlayer.DisplayName
	end
	return LocalPlayer.Name
end

--// Window Management
function Quorvyn:CreateWindow(config: WindowConfig?)
	config = config or {}
	local self = setmetatable({}, Quorvyn)

	self.Name = config.Name or "Quorvyn"
	self.Team = config.Team or "Velora Forge"
	self.Accent = config.Accent or Color3.fromRGB(120, 154, 255)
	self.Background = config.Background or Color3.fromRGB(18, 20, 28)
	self.Secondary = config.Secondary or Color3.fromRGB(26, 29, 40)
	self.Text = config.Text or Color3.fromRGB(240, 243, 255)
	self.Corner = config.Corner or UDim.new(0, 16)
	self.UnloadKey = config.UnloadKey or Enum.KeyCode.RightShift

	self._connections = {}
	self._destroyed = false
	self._elements = {}

	local gui = create("ScreenGui", {
		Name = "Quorvyn_" .. self.Name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = PlayerGui,
	})
	self.Gui = gui

	local loader = create("Frame", {
		Name = "Loader",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(310, 145),
		BackgroundColor3 = self.Background,
		BorderSizePixel = 0,
		Parent = gui,
	})
	round(loader, 18)
	stroke(loader, self.Accent, 1, 0.55)
	gradient(loader, self.Background, self.Secondary, 45)

	local loaderScale = create("UIScale", {Scale = 0.96, Parent = loader})

	local title = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(1, -36, 0, 30),
		Font = Enum.Font.GothamSemibold,
		Text = self.Name,
		TextColor3 = self.Text,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = loader,
	})

	local team = create("TextLabel", {
		Name = "Team",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 46),
		Size = UDim2.new(1, -36, 0, 18),
		Font = Enum.Font.Gotham,
		Text = "Made by " .. self.Team,
		TextColor3 = Color3.fromRGB(170, 176, 196),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = loader,
	})

	local barBack = create("Frame", {
		Name = "ProgressBack",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -20),
		Size = UDim2.new(1, -36, 0, 10),
		BackgroundColor3 = Color3.fromRGB(35, 38, 52),
		BorderSizePixel = 0,
		Parent = loader,
	})
	round(barBack, 999)

	local barFill = create("Frame", {
		Name = "ProgressFill",
		Size = UDim2.new(0.22, 0, 1, 0),
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		Parent = barBack,
	})
	round(barFill, 999)
	gradient(barFill, self.Accent, Color3.fromRGB(255, 255, 255), 0)

	local spinner = create("Frame", {
		Name = "Spinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -44, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		Parent = loader,
	})

	local spinnerStroke = create("UIStroke", {
		Color = self.Accent,
		Thickness = 3,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = spinner,
	})
	create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = spinner})
	create("Frame", {
		Name = "Gap",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -1),
		Size = UDim2.new(0.3, 0, 0.15, 0),
		BackgroundColor3 = self.Background,
		BorderSizePixel = 0,
		Rotation = 20,
		Parent = spinner,
	})
	local spinnerRotation = 0
	table.insert(self._connections, RunService.RenderStepped:Connect(function(dt)
		if self._destroyed then return end
		spinnerRotation += dt * 280
		spinner.Rotation = spinnerRotation
	end))

	local loadingTip = create("TextLabel", {
		Name = "Tip",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 76),
		Size = UDim2.new(1, -86, 0, 26),
		Font = Enum.Font.Gotham,
		Text = "Starting interface...",
		TextColor3 = Color3.fromRGB(194, 200, 220),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = loader,
	})

	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < 1.1 do
			local progress = math.clamp((os.clock() - start) / 1.1, 0, 1)
			barFill.Size = UDim2.new(0.18 + progress * 0.82, 0, 1, 0)
			task.wait()
		end
		Tween(loaderScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
		task.wait(0.1)
		Tween(loader, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		Tween(title, TweenInfo.new(0.22), {TextTransparency = 1})
		Tween(team, TweenInfo.new(0.22), {TextTransparency = 1})
		Tween(loadingTip, TweenInfo.new(0.22), {TextTransparency = 1})
		Tween(barBack, TweenInfo.new(0.22), {BackgroundTransparency = 1})
		Tween(barFill, TweenInfo.new(0.22), {BackgroundTransparency = 1})
		Tween(spinner, TweenInfo.new(0.22), {BackgroundTransparency = 1})
		task.wait(0.26)
		if loader then
			loader:Destroy()
		end
	end)

	local cornerButton = create("TextButton", {
		Name = "MinimizedToggle",
		Visible = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(120, 42),
		BackgroundColor3 = self.Secondary,
		BorderSizePixel = 0,
		Text = "",
		Parent = gui,
	})
	round(cornerButton, 999)
	stroke(cornerButton, self.Accent, 1, 0.25)
	gradient(cornerButton, self.Secondary, self.Background, 0)

	local cornerLabel = create("TextLabel", {
		Name = "CornerLabel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamSemibold,
		Text = self.Name,
		TextColor3 = self.Text,
		TextSize = 13,
		TextWrapped = false,
		Parent = cornerButton,
	})
	makeClickable(cornerButton, 1.02)

	local main = create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 420),
		BackgroundColor3 = self.Background,
		BorderSizePixel = 0,
		Visible = true,
		Parent = gui,
	})
	round(main, 18)
	stroke(main, self.Accent, 1, 0.6)
	gradient(main, self.Background, self.Secondary, 45)

	local mainScale = create("UIScale", {Scale = 1, Parent = main})

	local top = create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 88),
		BackgroundTransparency = 1,
		Parent = main,
	})
	padding(top, 16, 16, 16, 12)

	local avatar = create("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = Color3.fromRGB(36, 39, 56),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(46, 46),
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
		Parent = top,
	})
	round(avatar, 999)
	stroke(avatar, self.Accent, 1, 0.8)

	local playerName = create("TextLabel", {
		Name = "PlayerName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(58, 24),
		Size = UDim2.new(1, -180, 0, 18),
		Font = Enum.Font.GothamMedium,
		Text = formatPlayerName(),
		TextColor3 = Color3.fromRGB(214, 219, 232),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})

	local scriptTitle = create("TextLabel", {
		Name = "ScriptTitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.new(1, -180, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = self.Name,
		TextColor3 = self.Text,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})

	local minimize = create("TextButton", {
		Name = "Minimize",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -42, 0, 2),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(34, 37, 50),
		BorderSizePixel = 0,
		Text = "—",
		TextColor3 = self.Text,
		TextSize = 22,
		Font = Enum.Font.GothamSemibold,
		Parent = top,
	})
	round(minimize, 999)
	stroke(minimize, self.Accent, 1, 0.75)
	makeClickable(minimize, 1.05)

	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(55, 28, 36),
		BorderSizePixel = 0,
		Text = "×",
		TextColor3 = Color3.fromRGB(255, 225, 229),
		TextSize = 22,
		Font = Enum.Font.GothamSemibold,
		Parent = top,
	})
	round(close, 999)
	stroke(close, Color3.fromRGB(255, 105, 130), 1, 0.8)
	makeClickable(close, 1.05)

	local body = create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 1, -88),
		BackgroundTransparency = 1,
		Parent = main,
	})
	padding(body, 16, 16, 0, 16)

	local tabsBar = create("Frame", {
		Name = "TabsBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(24, 27, 37),
		BorderSizePixel = 0,
		Parent = body,
	})
	round(tabsBar, 14)
	stroke(tabsBar, self.Accent, 1, 0.9)

	local tabsBarPad = create("ScrollingFrame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = tabsBar,
	})
	local tabLayout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabsBarPad,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = tabsBarPad,
	})

	local pagesHost = create("Frame", {
		Name = "PagesHost",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		Parent = body,
	})

	local function selectPage(page, tabButtons)
		for _, child in ipairs(pagesHost:GetChildren()) do
			if child:IsA("Frame") then
				child.Visible = false
			end
		end
		page.Visible = true
		for _, b in ipairs(tabButtons) do
			local active = b:GetAttribute("Active") == true
			if b ~= tabButtons and b:IsA("TextButton") then
				-- no-op
			end
		end
	end

	function self:MinimizeState(enabled: boolean)
		main.Visible = not enabled
		cornerButton.Visible = enabled
	end

	local minimized = false
	local function toggleMinimize()
		minimized = not minimized
		self:MinimizeState(minimized)
	end

	minimize.MouseButton1Click:Connect(toggleMinimize)
	cornerButton.MouseButton1Click:Connect(toggleMinimize)
	close.MouseButton1Click:Connect(function()
		self:Destroy()
	end)

	makeDraggable(top, main)
	makeDraggable(cornerButton, cornerButton)

	self.Main = main
	self.CornerButton = cornerButton
	self.PagesHost = pagesHost
	self.TabsBar = tabsBarPad
	self._tabs = {}
	self._activeTab = nil

	function self:CreateTab(tabName: string)
		local tabButton = create("TextButton", {
			Name = tabName .. "TabButton",
			Size = UDim2.fromOffset(110, 32),
			BackgroundColor3 = Color3.fromRGB(30, 34, 47),
			BorderSizePixel = 0,
			Text = tabName,
			TextColor3 = Color3.fromRGB(217, 223, 240),
			TextSize = 13,
			Font = Enum.Font.GothamSemibold,
			Parent = tabsBarPad,
		})
		round(tabButton, 999)
		stroke(tabButton, self.Accent, 1, 0.86)
		makeClickable(tabButton, 1.03)

		local page = create("ScrollingFrame", {
			Name = tabName .. "Page",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = self.Accent,
			Visible = false,
			Parent = pagesHost,
		})

		local pagePad = create("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 8),
			Parent = page,
		})

		local pageLayout = create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			Parent = page,
		})

		local container = create("Frame", {
			Name = tabName .. "Container",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = page,
		})
		local containerLayout = create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			Parent = container,
		})

		local tab = {}
		tab.Name = tabName
		tab.Page = page
		tab.Container = container
		tab.Button = tabButton
		tab.Elements = {}

		local function elementCard(height: number, titleText: string?, subtitleText: string?)
			local card = create("Frame", {
				BackgroundColor3 = Color3.fromRGB(24, 27, 37),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -4, 0, height),
				AutomaticSize = Enum.AutomaticSize.None,
				Parent = container,
			})
			round(card, 16)
			stroke(card, self.Accent, 1, 0.92)
			local cardPad = create("UIPadding", {
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				Parent = card,
			})
			if titleText then
				create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -8, 0, 18),
					Font = Enum.Font.GothamSemibold,
					Text = titleText,
					TextColor3 = self.Text,
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
			end
			if subtitleText then
				create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 20),
					Size = UDim2.new(1, -8, 0, 16),
					Font = Enum.Font.Gotham,
					Text = subtitleText,
					TextColor3 = Color3.fromRGB(160, 167, 184),
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
			end
			return card
		end

		local function addBody(card: Frame, offsetY: number?)
			local bodyFrame = create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, offsetY or 38),
				Size = UDim2.new(1, 0, 1, -(offsetY or 38)),
				Parent = card,
			})
			return bodyFrame
		end

		function tab:AddLabel(text: string, description: string?)
			local card = elementCard(description and 82 or 64, text, description)
			return card
		end

		function tab:AddButton(text: string, callback: (() -> ())?)
			local card = elementCard(70, text, nil)
			local bodyFrame = addBody(card, 34)
			local btn = create("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = self.Accent,
				BorderSizePixel = 0,
				Text = text,
				TextColor3 = Color3.new(1,1,1),
				TextSize = 14,
				Font = Enum.Font.GothamSemibold,
				Parent = bodyFrame,
			})
			round(btn, 14)
			gradient(btn, self.Accent, Color3.fromRGB(255,255,255), 0)
			makeClickable(btn, 1.02)
			btn.MouseButton1Click:Connect(function()
				if callback then callback() end
			end)
			return btn
		end

		function tab:AddToggle(text: string, defaultValue: boolean?, callback: Callback<boolean>?)
			local card = elementCard(74, text, "iOS-style switch")
			local bodyFrame = addBody(card, 36)
			local switch = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(54, 30),
				BackgroundColor3 = defaultValue and self.Accent or Color3.fromRGB(57, 61, 79),
				BorderSizePixel = 0,
				Text = "",
				Parent = bodyFrame,
			})
			round(switch, 999)
			local knob = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = defaultValue and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 15, 0.5, 0),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Color3.fromRGB(255,255,255),
				BorderSizePixel = 0,
				Parent = switch,
			})
			round(knob, 999)
			local state = defaultValue == true
			local function setState(value: boolean)
				state = value
				Tween(switch, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = value and self.Accent or Color3.fromRGB(57, 61, 79)
				})
				Tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = value and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 15, 0.5, 0)
				})
				if callback then callback(value) end
			end
			switch.MouseButton1Click:Connect(function()
				setState(not state)
			end)
			return { Set = setState, Get = function() return state end }
		end

		function tab:AddTextbox(text: string, placeholder: string?, callback: Callback<string>?)
			local card = elementCard(84, text, "Text input")
			local bodyFrame = addBody(card, 36)
			local box = create("TextBox", {
				Size = UDim2.new(1, 0, 0, 34),
				Position = UDim2.fromOffset(0, 2),
				BackgroundColor3 = Color3.fromRGB(30, 34, 47),
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				Text = "",
				PlaceholderText = placeholder or "Enter text...",
				TextColor3 = self.Text,
				PlaceholderColor3 = Color3.fromRGB(135, 141, 156),
				TextSize = 14,
				Font = Enum.Font.Gotham,
				Parent = bodyFrame,
			})
			round(box, 12)
			stroke(box, self.Accent, 1, 0.9)
			box.FocusLost:Connect(function(enterPressed)
				if callback then
					callback(box.Text)
				end
			end)
			return box
		end

		function tab:AddSlider(text: string, minValue: number, maxValue: number, defaultValue: number?, callback: Callback<number>?)
			local card = elementCard(92, text, string.format("%s - %s", minValue, maxValue))
			local bodyFrame = addBody(card, 42)
			local track = create("Frame", {
				Position = UDim2.fromOffset(0, 16),
				Size = UDim2.new(1, 0, 0, 8),
				BackgroundColor3 = Color3.fromRGB(38, 42, 56),
				BorderSizePixel = 0,
				Parent = bodyFrame,
			})
			round(track, 999)
			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = self.Accent,
				BorderSizePixel = 0,
				Parent = track,
			})
			round(fill, 999)
			local knob = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Color3.fromRGB(255,255,255),
				BorderSizePixel = 0,
				Parent = track,
			})
			round(knob, 999)
			stroke(knob, self.Accent, 1, 0.85)
			local valueLabel = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, -26),
				Size = UDim2.fromOffset(70, 18),
				Font = Enum.Font.GothamSemibold,
				Text = tostring(defaultValue or minValue),
				TextColor3 = self.Text,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = bodyFrame,
			})
			local value = defaultValue or minValue
			local dragging = false

			local function setValue(num: number)
				value = math.clamp(math.floor(num + 0.5), minValue, maxValue)
				local alpha = (value - minValue) / math.max(1, (maxValue - minValue))
				fill.Size = UDim2.new(alpha, 0, 1, 0)
				knob.Position = UDim2.new(alpha, 0, 0.5, 0)
				valueLabel.Text = tostring(value)
				if callback then callback(value) end
			end

			local function updateFromX(x: number)
				local absPos = track.AbsolutePosition.X
				local absSize = track.AbsoluteSize.X
				local alpha = math.clamp((x - absPos) / absSize, 0, 1)
				setValue(minValue + ((maxValue - minValue) * alpha))
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					updateFromX(input.Position.X)
				end
			end)

			track.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateFromX(input.Position.X)
				end
			end)

			setValue(value)
			return { Set = setValue, Get = function() return value end }
		end

		function tab:AddDropdown(text: string, options: {string}, callback: Callback<string>?, defaultValue: string?)
			local card = elementCard(112, text, "Dropdown with search")
			local bodyFrame = addBody(card, 36)

			local selected = defaultValue or options[1] or ""
			local open = false

			local button = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.fromRGB(30, 34, 47),
				BorderSizePixel = 0,
				Text = selected == "" and "Select..." or selected,
				TextColor3 = self.Text,
				TextSize = 14,
				Font = Enum.Font.Gotham,
				Parent = bodyFrame,
			})
			round(button, 12)
			stroke(button, self.Accent, 1, 0.9)

			local listHolder = create("Frame", {
				Visible = false,
				ClipsDescendants = true,
				BackgroundColor3 = Color3.fromRGB(24, 27, 37),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 64),
				Parent = bodyFrame,
			})
			round(listHolder, 12)
			stroke(listHolder, self.Accent, 1, 0.9)

			local search = create("TextBox", {
				Size = UDim2.new(1, -10, 0, 26),
				Position = UDim2.fromOffset(5, 6),
				BackgroundColor3 = Color3.fromRGB(31, 35, 48),
				BorderSizePixel = 0,
				Text = "",
				PlaceholderText = "Search...",
				PlaceholderColor3 = Color3.fromRGB(135, 141, 156),
				TextColor3 = self.Text,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				ClearTextOnFocus = false,
				Parent = listHolder,
			})
			round(search, 10)

			local scrolling = create("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 38),
				Size = UDim2.new(1, 0, 1, -38),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = self.Accent,
				Parent = listHolder,
			})
			local layout = create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
				Parent = scrolling,
			})
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				Parent = scrolling,
			})

			local function rebuild(filterText: string)
				for _, child in ipairs(scrolling:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				local count = 0
				for _, option in ipairs(options) do
					if filterText == "" or string.find(string.lower(option), string.lower(filterText), 1, true) then
						count += 1
						local opt = create("TextButton", {
							Size = UDim2.new(1, 0, 0, 28),
							BackgroundColor3 = option == selected and self.Accent or Color3.fromRGB(30, 34, 47),
							BorderSizePixel = 0,
							Text = option,
							TextColor3 = Color3.new(1,1,1),
							TextSize = 13,
							Font = Enum.Font.GothamSemibold,
							Parent = scrolling,
						})
						round(opt, 10)
						opt.MouseButton1Click:Connect(function()
							selected = option
							button.Text = selected
							listHolder.Visible = false
							open = false
							if callback then callback(selected) end
						end)
					end
				end
				listHolder.Size = UDim2.new(1, 0, 0, math.clamp(38 + (count * 33) + 6, 64, 220))
			end

			search:GetPropertyChangedSignal("Text"):Connect(function()
				rebuild(search.Text)
			end)

			button.MouseButton1Click:Connect(function()
				open = not open
				listHolder.Visible = open
				if open then
					rebuild(search.Text)
				end
			end)

			rebuild("")
			return { Set = function(v: string) selected = v; button.Text = v; if callback then callback(v) end end, Get = function() return selected end }
		end

		function tab:AddMultiDropdown(text: string, options: {string}, callback: Callback<{string}>?, defaultValues: {string}?)
			local card = elementCard(136, text, "Multi-dropdown with search")
			local bodyFrame = addBody(card, 36)
			local selectedSet: {[string]: boolean} = {}
			if defaultValues then
				for _, v in ipairs(defaultValues) do selectedSet[v] = true end
			end

			local button = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.fromRGB(30, 34, 47),
				BorderSizePixel = 0,
				Text = "Select...",
				TextColor3 = self.Text,
				TextSize = 14,
				Font = Enum.Font.Gotham,
				Parent = bodyFrame,
			})
			round(button, 12)
			stroke(button, self.Accent, 1, 0.9)

			local listHolder = create("Frame", {
				Visible = false,
				ClipsDescendants = true,
				BackgroundColor3 = Color3.fromRGB(24, 27, 37),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 104),
				Parent = bodyFrame,
			})
			round(listHolder, 12)
			stroke(listHolder, self.Accent, 1, 0.9)

			local search = create("TextBox", {
				Size = UDim2.new(1, -10, 0, 26),
				Position = UDim2.fromOffset(5, 6),
				BackgroundColor3 = Color3.fromRGB(31, 35, 48),
				BorderSizePixel = 0,
				Text = "",
				PlaceholderText = "Search...",
				PlaceholderColor3 = Color3.fromRGB(135, 141, 156),
				TextColor3 = self.Text,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				ClearTextOnFocus = false,
				Parent = listHolder,
			})
			round(search, 10)

			local scrolling = create("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 38),
				Size = UDim2.new(1, 0, 1, -38),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = self.Accent,
				Parent = listHolder,
			})
			create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
				Parent = scrolling,
			})
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				Parent = scrolling,
			})

			local function refreshText()
				local list = {}
				for _, option in ipairs(options) do
					if selectedSet[option] then
						table.insert(list, option)
					end
				end
				button.Text = (#list > 0) and table.concat(list, ", ") or "Select..."
			end

			local function getSelectedArray()
				local arr = {}
				for _, option in ipairs(options) do
					if selectedSet[option] then table.insert(arr, option) end
				end
				return arr
			end

			local function rebuild(filterText: string)
				for _, child in ipairs(scrolling:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				for _, option in ipairs(options) do
					if filterText == "" or string.find(string.lower(option), string.lower(filterText), 1, true) then
						local opt = create("TextButton", {
							Size = UDim2.new(1, 0, 0, 28),
							BackgroundColor3 = selectedSet[option] and self.Accent or Color3.fromRGB(30, 34, 47),
							BorderSizePixel = 0,
							Text = (selectedSet[option] and "✓ " or "") .. option,
							TextColor3 = Color3.new(1,1,1),
							TextSize = 13,
							Font = Enum.Font.GothamSemibold,
							Parent = scrolling,
						})
						round(opt, 10)
						opt.MouseButton1Click:Connect(function()
							selectedSet[option] = not selectedSet[option]
							refreshText()
							rebuild(search.Text)
							if callback then callback(getSelectedArray()) end
						end)
					end
				end
			end

			search:GetPropertyChangedSignal("Text"):Connect(function()
				rebuild(search.Text)
			end)

			button.MouseButton1Click:Connect(function()
				listHolder.Visible = not listHolder.Visible
				if listHolder.Visible then
					rebuild(search.Text)
				end
			end)

			refreshText()
			rebuild("")
			return { Get = getSelectedArray }
		end

		function tab:AddParagraph(text: string, content: string)
			local card = elementCard(96, text, nil)
			create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, 0, 1, -34),
				Font = Enum.Font.Gotham,
				Text = content,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(191, 196, 210),
				TextSize = 13,
				Parent = card,
			})
			return card
		end

		tabButton.MouseButton1Click:Connect(function()
			for _, t in ipairs(self._tabs) do
				t.Page.Visible = false
				t.Button.BackgroundColor3 = Color3.fromRGB(30, 34, 47)
				t.Button:SetAttribute("Active", false)
			end
			page.Visible = true
			tabButton.BackgroundColor3 = self.Accent
			tabButton:SetAttribute("Active", true)
			self._activeTab = tab
		end)

		table.insert(self._tabs, tab)
		if not self._activeTab then
			page.Visible = true
			tabButton.BackgroundColor3 = self.Accent
			tabButton:SetAttribute("Active", true)
			self._activeTab = tab
		end

		return tab
	end

	function self:Destroy()
		if self._destroyed then return end
		self._destroyed = true
		for _, conn in ipairs(self._connections) do
			conn:Disconnect()
		end
		if self.Gui then
			self.Gui:Destroy()
		end
	end

	return self
end

return Quorvyn