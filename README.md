# Quorvyn UI Library

Quorvyn UI Library is a clean, modern Roblox UI library made for both PC and mobile. It includes a smooth loading screen, a draggable main window, a minimize-to-corner mode, and a simple tab-based API for building interfaces fast.

## Created by

**AltALPX**

## What it includes

- Custom loading screen
- Smooth transition into the main window
- Draggable window support
- Minimize button with corner toggle
- Mobile and PC friendly interactions
- Clean tab system
- Easy-to-use element API
- Loadstring-compatible module design

## Included elements

- Button
- Label
- Paragraph
- Toggle
- Textbox
- Slider
- Dropdown with search
- Multi-dropdown with search

## Files

- `Source.lua` — main library module
- `Example.client.lua` — example usage script

## Setup

### Local setup in Roblox Studio
1. Put `Source.lua` inside `ReplicatedStorage`
2. Put `Example.client.lua` inside `StarterPlayerScripts`
3. Edit the config values in the example
4. Run the game and open the UI

### Loadstring setup
If you are using a loadstring-enabled environment, host `Source.lua` as a raw GitHub file and load it like this:

```lua
local Quorvyn = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumaWeave-altx/QuorvynUiLibrary/refs/heads/main/Source.lua"))()
```

## Example Script

Here is a simple example script using loadstring to get you started with Quorvyn UI Library:

```lua
-- Example.client.lua
local Quorvyn = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumaWeave-altx/QuorvynUiLibrary/refs/heads/main/Source.lua"))()

local window = Quorvyn:CreateWindow({
    Name = "Example UI",
    Team = "Your Team",
    Accent = Color3.fromRGB(120, 154, 255),
    Background = Color3.fromRGB(18, 20, 28),
    Secondary = Color3.fromRGB(26, 29, 40),
    Text = Color3.fromRGB(240, 243, 255),
    Corner = UDim.new(0, 16),
    UnloadKey = Enum.KeyCode.RightShift
})

local mainTab = window:CreateTab("Main")

mainTab:AddLabel("Welcome", "This is a simple example of Quorvyn UI Library.")

mainTab:AddButton("Click Me", function()
    print("Button clicked!")
end)

mainTab:AddToggle("Toggle Example", false, function(state)
    print("Toggle state:", state)
end)

mainTab:AddTextbox("Textbox Example", "Enter text here", function(text)
    print("Textbox text:", text)
end)

mainTab:AddSlider("Slider Example", 0, 100, 50, function(value)
    print("Slider value:", value)
end)

mainTab:AddDropdown("Dropdown Example", {"Option 1", "Option 2", "Option 3"}, function(selected)
    print("Dropdown selected:", selected)
end)

mainTab:AddMultiDropdown("Multi-Dropdown Example", {"Option A", "Option B", "Option C"}, function(selected)
    print("Multi-Dropdown selected:", table.concat(selected, ", "))
end)

mainTab:AddParagraph("Paragraph Example", "This is a sample paragraph. You can put any text here to display in your UI.")
```