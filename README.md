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

- `QuorvynUI.lua` — main library module
- `Example.client.lua` — example usage script

## Setup

### Local setup in Roblox Studio
1. Put `QuorvynUI.lua` inside `ReplicatedStorage`
2. Put `Example.client.lua` inside `StarterPlayerScripts`
3. Edit the config values in the example
4. Run the game and open the UI

### Loadstring setup
If you are using a loadstring-enabled environment, host `QuorvynUI.lua` as a raw GitHub file and load it like this:

```lua
local Quorvyn = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumaWeave-altx/QuorvynUiLibrary/main/QuorvynUI.lua"))()
```