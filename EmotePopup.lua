-- Table to store active toasts
local activeToasts = {}

-- Capture the addon name and a table for saved variables
local addonName, addonTable = ...

-- Define SavedVariables to store settings, falling back to defaults if not available
EmotePopupSavedVars = EmotePopupSavedVars or {
    scale = 1.0,  -- Default scale
    glowColor = {1, 0.84, 0, 1},  -- Default glow color (gold)
    toastPosition = {x = 0, y = -100},  -- Default toast position (relative to center)
}

-- Alias the saved variables for easy use
addonTable.savedVariables = EmotePopupSavedVars

-- Ensure that the position is valid, and if not, set it to default
local function EnsureValidPosition()
    -- If there's no saved position, assign the default
    if not addonTable.savedVariables.toastPosition or not addonTable.savedVariables.toastPosition.x or not addonTable.savedVariables.toastPosition.y then
        addonTable.savedVariables.toastPosition = { x = 0, y = -100 }
    end
end

-- Save position after dragging
local function SavePosition(toast)
    -- Get the current position relative to the center of the screen
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    local x, y = toast:GetCenter()

    -- Convert the absolute position to relative to center
    local relativeX = x - screenWidth / 2
    local relativeY = y - screenHeight / 2

    -- Save relative position
    addonTable.savedVariables.toastPosition.x = relativeX
    addonTable.savedVariables.toastPosition.y = relativeY

    -- Debug print the values being saved
    print("Saved relative position to:", relativeX, relativeY)
end

-- Function to adjust the position of active toasts dynamically based on scale
local function AdjustActiveToasts()
    local yOffset = addonTable.savedVariables.toastPosition.y  -- Start from the last saved position
    local baseToastHeight = 60  -- The base height of the toast before scaling
    local scale = addonTable.savedVariables.scale  -- Get the user's scale setting
    local spacing = baseToastHeight * scale * 1.2  -- Spacing is based on the toast height and scale

    -- Iterate through each active toast and move it down by the calculated spacing
    for _, toast in ipairs(activeToasts) do
        toast:ClearAllPoints()
        toast:SetPoint("CENTER", UIParent, "CENTER", addonTable.savedVariables.toastPosition.x, yOffset)
        yOffset = yOffset - spacing  -- Move the next toast further down based on the scale-adjusted spacing
    end
end

-- Function to create toast with optional drag functionality for positioning
function ShowToast(message, isTargetedAtPlayer, playerName, playerGUID, isMovable)
    -- Default isMovable to false if not provided
    isMovable = isMovable or false

    -- Make sure we have a valid position
    EnsureValidPosition()

    -- Strip realm name from player names in the message (format: Player-Realm)
    local playerOnlyName = playerName:match("([^%-]+)")  -- Get player name without the realm

    -- Get the player's class to color their name
    local _, class = GetPlayerInfoByGUID(playerGUID)
    local classColor = RAID_CLASS_COLORS[class] or {r = 1, g = 1, b = 1}  -- Fallback to white if no class info

    -- Get the saved relative position and convert it back to screen position
    local xPos = addonTable.savedVariables.toastPosition.x
    local yPos = addonTable.savedVariables.toastPosition.y

    -- Create the toast frame
    local toast = CreateFrame("Frame", nil, UIParent)
    toast:SetPoint("CENTER", UIParent, "CENTER", xPos, yPos)  -- Start at the saved position
    toast:SetHeight(80 * addonTable.savedVariables.scale)  -- Fixed height

    -- Text (apply default emote color to the whole message)
    local text = toast:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    text:SetPoint("CENTER", toast, "CENTER")
    
    -- Set emote text with class-colored player name
    local playerNameColor = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, playerOnlyName)
    local finalMessage = message:gsub(playerOnlyName, playerNameColor)
    
    -- Set text with default emote color and the player name color
    text:SetText(finalMessage)
    text:SetTextColor(255/255, 128/255, 64/255)  -- Default emote text color

    -- Dynamically calculate the width based on the length of the text
    local textWidth = text:GetStringWidth() + 40  -- Add some padding around the text
    toast:SetWidth(textWidth * addonTable.savedVariables.scale)

    -- Set up the toast content (background, text, glow)
    -- Background
    local bg = toast:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\AddOns\\EmotePopup\\Images\\Background.png")
    bg:SetAllPoints()

    -- Glow effect if targeted
    if isTargetedAtPlayer then
        local glow = toast:CreateTexture(nil, "BACKGROUND", nil, -1)
        glow:SetPoint("CENTER", toast, "CENTER")
        glow:SetSize(textWidth * 1.2 * addonTable.savedVariables.scale, 130 * addonTable.savedVariables.scale)
        glow:SetTexture("Interface\\GLUES\\MODELS\\UI_DRAENEI\\GenericGlow64")
        glow:SetBlendMode("ADD")

        -- Use the saved glow color
        local r, g, b, a = unpack(addonTable.savedVariables.glowColor)
        glow:SetVertexColor(r, g, b, a)
    end

    -- Insert the new toast at the top of the active toasts table
    table.insert(activeToasts, 1, toast)

    -- Adjust all active toasts to move older ones down
    AdjustActiveToasts()

    -- If the toast is not movable, make it fade out and disappear after 5 seconds
    if not isMovable then
        C_Timer.After(3, function()
            -- Fade out the toast over 2 seconds
            UIFrameFadeOut(toast, 2, 1, 0)
            C_Timer.After(2, function()
                toast:Hide()

                -- Remove the toast from activeToasts once it fades out
                for i, activeToast in ipairs(activeToasts) do
                    if activeToast == toast then
                        table.remove(activeToasts, i)
                        break
                    end
                end

                -- Adjust remaining toasts after one is removed
                AdjustActiveToasts()
            end)
        end)
    end

    -- Return the toast object so we can track it if it's a temporary movable toast
    return toast
end

-- Function to round numbers to a specified number of decimal places
 local function Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Function to display the color picker using older, more compatible methods
local function ShowColorPicker(r, g, b, a, changedCallback)
    -- Debug print to verify color values being passed
    print("Opening Color Picker with values: ", r, g, b, a)

    -- Ensure that ColorPickerFrame is valid
    if not ColorPickerFrame then
        print("Error: ColorPickerFrame is not available.")
        return
    end

    -- Manually set the RGB values using older methods
    ColorPickerFrame.r, ColorPickerFrame.g, ColorPickerFrame.b = r, g, b
    ColorPickerFrame.hasOpacity = (a ~= nil)
    ColorPickerFrame.opacity = a or 1  -- Set to 1 if alpha is missing
    ColorPickerFrame.previousValues = {r, g, b, a}

    -- Set the callback functions
    ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = 
        changedCallback, changedCallback, changedCallback

    -- Hide and show the color picker to trigger the OnShow handler
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

-- Function to handle the color changes and save the new glow color
local function myColorCallback(restore)
    local newR, newG, newB, newA

    if restore then
        -- The user canceled the selection, restore the previous values
        newR, newG, newB, newA = unpack(restore)
    else
        -- The user selected a new color, get the new values from ColorPickerFrame
        newR, newG, newB = ColorPickerFrame:GetColorRGB()

        -- Check if OpacitySliderFrame is available and retrieve its value
        if ColorPickerFrame.hasOpacity then
            newA = OpacitySliderFrame and OpacitySliderFrame:GetValue() or 1
        else
            newA = 1  -- If opacity is not available, default to fully opaque
        end
    end

    -- Save the selected color in the saved variables
    addonTable.savedVariables.glowColor = {newR, newG, newB, newA}

    -- Debug print to check saved values
    print("Saved glow color to:", newR, newG, newB, newA)
end

-- Create the options panel function (but don't add it yet)
local function CreateOptionsPanel()
    -- Create options panel
    local optionsPanel = CreateFrame("Frame", addonName .. "Options", UIParent)
    optionsPanel.name = "EmotePopup"  -- The name that shows in the Interface AddOns list

    -- Title
    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Emote Popup Settings")

    -- Scale slider
    local scaleSlider = CreateFrame("Slider", "ToastScaleSlider", optionsPanel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -40)
    scaleSlider:SetMinMaxValues(0.5, 2)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetValue(Round(addonTable.savedVariables.scale, 1))  -- Round to 1 decimal place
    scaleSlider:SetObeyStepOnDrag(true)
    ToastScaleSliderText:SetText("Size of Toast (" .. Round(addonTable.savedVariables.scale, 1) .. ")")
    ToastScaleSliderLow:SetText("0.5")
    ToastScaleSliderHigh:SetText("2.0")

    -- When the slider value changes, round the scale value and save it
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        local roundedValue = Round(value, 1)  -- Round to 1 decimal place
        addonTable.savedVariables.scale = roundedValue
        ToastScaleSliderText:SetText("Size of Toast (" .. roundedValue .. ")")
    end)

    -- Glow Color picker button in the options panel
    local glowColorButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    glowColorButton:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -40)
    glowColorButton:SetSize(150, 22)
    glowColorButton:SetText("Choose Mention Color")
    glowColorButton:SetScript("OnClick", function()
        -- Get the current glow color from the saved variables
        local r, g, b, a = unpack(addonTable.savedVariables.glowColor)

        -- Show the color picker and pass the current color and the callback
        ShowColorPicker(r, g, b, a, myColorCallback)
    end)

    -- Move Toast Popup checkbox
    local moveToastCheckbox = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    moveToastCheckbox:SetPoint("TOPLEFT", glowColorButton, "BOTTOMLEFT", 0, -40)
    moveToastCheckbox.Text:SetText("Move Toast Popup")
    moveToastCheckbox:SetChecked(false)

    moveToastCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            -- Show the "Move Me!" toast only if it's not already shown
            if not addonTable.tempToast or not addonTable.tempToast:IsShown() then
                addonTable.tempToast = ShowToast("Move Me!", false, true)  -- Show a toast for positioning
            end
        else
            -- Hide and release the "Move Me!" toast if it exists
            if addonTable.tempToast then
                addonTable.tempToast:Hide()
                addonTable.tempToast = nil  -- Remove reference to the toast to prevent further interaction
            end
        end
    end)

    -- Hook into InterfaceOptions_ShowPanel to reload settings when opened
    optionsPanel.okay = function()
        -- Save all settings when user hits "Okay"
        -- This will automatically be handled by SavedVariables
    end

    optionsPanel.default = function()
        -- Reset all settings to default
        addonTable.savedVariables.scale = 1.0
        addonTable.savedVariables.glowColor = {1, 0.84, 0, 1}
        addonTable.savedVariables.toastPosition = {x = 0, y = -100}
    
        -- Update sliders, color pickers, and checkbox accordingly
        scaleSlider:SetValue(Round(addonTable.savedVariables.scale, 1))  -- Use the rounded value
        ToastScaleSliderText:SetText("Size of Toast (" .. Round(addonTable.savedVariables.scale, 1) .. ")")
        moveToastCheckbox:SetChecked(false)
    end    

    -- Register the panel with the new settings API
    local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Emote Popup")
    Settings.RegisterAddOnCategory(category)
end

-- Create the main frame and register the events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")  -- Add PLAYER_LOGIN event to wait until the interface is fully loaded
frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")

-- Event handler function
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        -- Set up saved variables here if needed
        -- Make sure saved variables are restored
        addonTable.savedVariables = EmotePopupSavedVars
    elseif event == "PLAYER_LOGIN" then
        -- Now the Blizzard UI is fully loaded, and we can safely add the options panel
        CreateOptionsPanel()
    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        -- Extract the arguments from the CHAT_MSG_TEXT_EMOTE event
        local text, playerName, _, _, _, _, _, _, _, _, _, senderGUID = ...

        -- Debug prints to ensure we're getting the right values
        print("playerName:", playerName)
        print("Emote Text:", text)

        -- Check if the playerName is valid
        if playerName and playerName ~= "" then
            local myName = UnitName("player")
            print("myName is set to:", myName)

            -- Check if the emote is directed at you (look for "you" in the emote text)
            local isTargetedAtPlayer = text:find("you") ~= nil
            print("test2 - isTargetedAtPlayer:", isTargetedAtPlayer)

            -- Show the toast notification for the emote and pass the playerName and GUID
            ShowToast(text, isTargetedAtPlayer, playerName, senderGUID)
        end
    end
end

frame:SetScript("OnEvent", OnEvent)
