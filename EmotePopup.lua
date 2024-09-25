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
function ShowToast(message, isTargetedAtPlayer, isMovable)
    -- Default isMovable to false if not provided
    isMovable = isMovable or false

    -- Make sure we have a valid position
    EnsureValidPosition()

    -- Get the saved relative position and convert it back to screen position
    local xPos = addonTable.savedVariables.toastPosition.x
    local yPos = addonTable.savedVariables.toastPosition.y

    -- Create the toast frame
    local toast = CreateFrame("Frame", nil, UIParent)
    toast:SetPoint("CENTER", UIParent, "CENTER", xPos, yPos)  -- Start at the saved position
    toast:SetSize(300 * addonTable.savedVariables.scale, 80 * addonTable.savedVariables.scale)

    -- Enable dragging functionality
    toast:SetMovable(isMovable)
    toast:EnableMouse(isMovable)
    if isMovable then
        toast:RegisterForDrag("LeftButton")
        toast:SetScript("OnDragStart", function() toast:StartMoving() end)
        toast:SetScript("OnDragStop", function()
            toast:StopMovingOrSizing()
            SavePosition(toast)  -- Call SavePosition to store the relative position
        end)
    end

    -- Set up the toast content (background, text, glow)
    -- Background
    local bg = toast:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\AddOns\\EmotePopup\\Images\\Background.png")
    bg:SetAllPoints()

    -- Text
    local text = toast:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    text:SetPoint("CENTER", toast, "CENTER")
    text:SetText(message)
    text:SetTextColor(1, 1, 1)

    -- Glow effect if targeted
    if isTargetedAtPlayer then
        local glow = toast:CreateTexture(nil, "BACKGROUND", nil, -1)
        glow:SetPoint("CENTER", toast, "CENTER")
        glow:SetSize(350 * addonTable.savedVariables.scale, 130 * addonTable.savedVariables.scale)
        glow:SetTexture("Interface\\GLUES\\MODELS\\UI_DRAENEI\\GenericGlow64")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(unpack(addonTable.savedVariables.glowColor))
    end

    -- Insert the new toast at the top of the active toasts table
    table.insert(activeToasts, 1, toast)

    -- Adjust all active toasts to move older ones down
    AdjustActiveToasts()

    -- Fade out after 5 seconds if not in movable mode
    if not isMovable then
        C_Timer.After(3, function()
            UIFrameFadeOut(toast, 2, 1, 0)
            C_Timer.After(2, function()
                toast:Hide()

                -- Remove toast from activeToasts when it fades out
                for i, activeToast in ipairs(activeToasts) do
                    if activeToast == toast then
                        table.remove(activeToasts, i)
                        break
                    end
                end

                -- Re-adjust the positions after removing the toast
                AdjustActiveToasts()
            end)
        end)
    end
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
    scaleSlider:SetValue(addonTable.savedVariables.scale)
    scaleSlider:SetObeyStepOnDrag(true)
    ToastScaleSliderText:SetText("Size of Toast (" .. addonTable.savedVariables.scale .. ")")
    ToastScaleSliderLow:SetText("0.5")
    ToastScaleSliderHigh:SetText("2.0")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        addonTable.savedVariables.scale = value
        ToastScaleSliderText:SetText("Size of Toast (" .. string.format("%.1f", value) .. ")")
    end)

    -- Glow Color picker
    local glowColorButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    glowColorButton:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -40)
    glowColorButton:SetSize(140, 22)
    glowColorButton:SetText("Choose Glow Color")
    glowColorButton:SetScript("OnClick", function()
        ColorPickerFrame:SetColorRGB(unpack(addonTable.savedVariables.glowColor))
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = addonTable.savedVariables.glowColor[4]
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = OpacitySliderFrame:GetValue()
            addonTable.savedVariables.glowColor = {r, g, b, a}
        end
        ColorPickerFrame:Show()
    end)

    -- Move Toast Popup checkbox
    local moveToastCheckbox = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    moveToastCheckbox:SetPoint("TOPLEFT", glowColorButton, "BOTTOMLEFT", 0, -40)
    moveToastCheckbox.Text:SetText("Move Toast Popup")
    moveToastCheckbox:SetChecked(false)
    moveToastCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ShowToast("Move Me!", false, true)  -- Show a toast for positioning
        else
            -- Hide temporary move toast
            if addonTable.tempToast then
                addonTable.tempToast:Hide()
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
        scaleSlider:SetValue(addonTable.savedVariables.scale)
        ToastScaleSliderText:SetText("Size of Toast (" .. addonTable.savedVariables.scale .. ")")
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

            -- Show the toast notification for the emote
            ShowToast(text, isTargetedAtPlayer)
        end
    end
end

frame:SetScript("OnEvent", OnEvent)
