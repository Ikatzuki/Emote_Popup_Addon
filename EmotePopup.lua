-- Table to store active toasts
local activeToasts = {}

-- Capture the addon name and a table for saved variables
local addonName, addonTable = ...

-- Define SavedVariables with defaults
EmotePopupSavedVars = EmotePopupSavedVars or {
    scale = 1.0,
    glowColor = {1, 0.84, 0, 1},
    toastPosition = {x = 0, y = 600},
    toastDuration = 3
}

-- Alias the saved variables for easy use
addonTable.savedVariables = EmotePopupSavedVars

-- Ensure that the position is valid, and if not, set it to default
local function EnsureValidPosition()
    if not addonTable.savedVariables.toastPosition or not addonTable.savedVariables.toastPosition.x or not addonTable.savedVariables.toastPosition.y then
        addonTable.savedVariables.toastPosition = {x = 0, y = -100}
    end
end

-- Save position after dragging
local function SavePosition(toast)
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    local x, y = toast:GetCenter()
    local relativeX = x - screenWidth / 2
    local relativeY = y - screenHeight / 2

    addonTable.savedVariables.toastPosition.x = relativeX
    addonTable.savedVariables.toastPosition.y = relativeY

end

-- Adjust the position of active toasts based on scale
local function AdjustActiveToasts()
    local yOffset = addonTable.savedVariables.toastPosition.y
    local baseToastHeight = 60
    local scale = addonTable.savedVariables.scale
    local spacing = baseToastHeight * scale * 1.2

    for _, toast in ipairs(activeToasts) do
        toast:ClearAllPoints()
        toast:SetPoint("CENTER", UIParent, "CENTER", addonTable.savedVariables.toastPosition.x, yOffset)
        yOffset = yOffset - spacing
    end
end

-- Create toast with optional drag functionality for positioning
function ShowToast(message, isTargetedAtPlayer, playerName, playerGUID, isMovable)
    isMovable = isMovable or false
    EnsureValidPosition()

    -- Strip realm name from player names in the message (format: Player-Realm)
    local playerOnlyName = playerName and playerName:match("^[^%-]+") or ""

    -- Get the player's class to color their name
    local classColor = {r = 1, g = 1, b = 1}  -- Default to white if class is not found
    if playerGUID then
        local _, class = GetPlayerInfoByGUID(playerGUID)
        if class then
            classColor = RAID_CLASS_COLORS[class] or classColor
        end
    end

    -- Get the saved relative position and convert it back to screen position
    local xPos = addonTable.savedVariables.toastPosition.x
    local yPos = addonTable.savedVariables.toastPosition.y

    -- Create the toast frame
    local toast = CreateFrame("Frame", nil, UIParent)
    toast:SetPoint("CENTER", UIParent, "CENTER", xPos, yPos)
    toast:SetHeight(80 * addonTable.savedVariables.scale)

    -- Text (apply default emote color to the whole message)
    local text = toast:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    text:SetPoint("CENTER", toast, "CENTER")

    -- Set emote text with class-colored player name
    if playerName then
        local playerNameColor = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, playerOnlyName)

        -- Replace the full player name (with or without the realm) in the message with the colored playerOnlyName
        local finalMessage = message:gsub(playerName .. "%-?%w*", playerNameColor)

        -- Now, additionally strip any remaining realm names from any other player references in the message
        finalMessage = finalMessage:gsub("(%a+%-[%a]+)", function(fullName)
            return fullName:match("^[^%-]+")
        end)

        -- Set the text with default emote color and the class-colored player name
        text:SetText(finalMessage)
    else
        -- Fallback if playerName is nil (for "Move Me!" or other system messages)
        text:SetText(message)
    end

    text:SetTextColor(255 / 255, 128 / 255, 64 / 255)  -- Default emote text color

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
        glow:SetSize(textWidth * 1.4 * addonTable.savedVariables.scale, 150 * addonTable.savedVariables.scale)
        glow:SetTexture("Interface\\GLUES\\MODELS\\UI_DRAENEI\\GenericGlow64")
        glow:SetBlendMode("ADD")

        -- Use the saved glow color
        local r, g, b, a = unpack(addonTable.savedVariables.glowColor)
        glow:SetVertexColor(r, g, b, a)
    end

    -- Make toast movable if isMovable is true
    if isMovable then
        toast:SetMovable(true)
        toast:EnableMouse(true)
        toast:RegisterForDrag("LeftButton")
        toast:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        toast:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SavePosition(self)  -- Call SavePosition to store the new position
        end)
    end

    -- Insert the new toast at the top of the active toasts table
    table.insert(activeToasts, 1, toast)

    -- Adjust all active toasts to move older ones down
    AdjustActiveToasts()

    -- If not movable, fade out after the customizable duration
    if not isMovable then
        C_Timer.After(addonTable.savedVariables.toastDuration, function()  -- Use the customizable duration here
            UIFrameFadeOut(toast, addonTable.savedVariables.toastFadeoutDuration, 1, 0)  -- Use customizable fadeout duration
            C_Timer.After(addonTable.savedVariables.toastFadeoutDuration, function()  -- Use the fadeout duration here as well    
                toast:Hide()
                for i, activeToast in ipairs(activeToasts) do
                    if activeToast == toast then
                        table.remove(activeToasts, i)
                        break
                    end
                end
                AdjustActiveToasts()
            end)
        end)
    end

    return toast
end

-- Round numbers to a specified number of decimal places
local function Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Display the color picker using older methods
local function ShowColorPicker(r, g, b, a, changedCallback)

    if not ColorPickerFrame then
        return
    end

    ColorPickerFrame.r, ColorPickerFrame.g, ColorPickerFrame.b = r, g, b
    ColorPickerFrame.hasOpacity = (a ~= nil)
    ColorPickerFrame.opacity = a or 1
    ColorPickerFrame.previousValues = {r, g, b, a}

    ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = 
        changedCallback, changedCallback, changedCallback

    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

-- Handle color changes and save the new glow color
local function myColorCallback(restore)
    local newR, newG, newB, newA

    if restore then
        newR, newG, newB, newA = unpack(restore)
    else
        newR, newG, newB = ColorPickerFrame:GetColorRGB()
        newA = ColorPickerFrame.hasOpacity and (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 1) or 1
    end

    addonTable.savedVariables.glowColor = {newR, newG, newB, newA}
end

-- Create the options panel
local function CreateOptionsPanel()
    local optionsPanel = CreateFrame("Frame", addonName .. "Options", UIParent)
    optionsPanel.name = "EmotePopup"

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Emote Popup Settings")

    local scaleSlider = CreateFrame("Slider", "ToastScaleSlider", optionsPanel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -40)
    scaleSlider:SetMinMaxValues(0.5, 2)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetValue(Round(addonTable.savedVariables.scale, 1))
    scaleSlider:SetObeyStepOnDrag(true)
    ToastScaleSliderText:SetText("Size of Popup (" .. Round(addonTable.savedVariables.scale, 1) .. ")")
    ToastScaleSliderLow:SetText("0.5")
    ToastScaleSliderHigh:SetText("2.0")

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        local roundedValue = Round(value, 1)
        addonTable.savedVariables.scale = roundedValue
        ToastScaleSliderText:SetText("Size of Popup (" .. roundedValue .. ")")
    end)

    local glowColorButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    glowColorButton:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -40)
    glowColorButton:SetSize(150, 22)
    glowColorButton:SetText("Choose Mention Color")
    glowColorButton:SetScript("OnClick", function()
        local r, g, b, a = unpack(addonTable.savedVariables.glowColor)
        ShowColorPicker(r, g, b, a, myColorCallback)
    end)

    local moveToastCheckbox = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    moveToastCheckbox:SetPoint("TOPLEFT", glowColorButton, "BOTTOMLEFT", 0, -40)
    moveToastCheckbox.Text:SetText("Move Popup Position")
    moveToastCheckbox:SetChecked(false)

    moveToastCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if not addonTable.tempToast or not addonTable.tempToast:IsShown() then
                addonTable.tempToast = ShowToast("Move Me!", false, nil, nil, true)
            end
        else
            if addonTable.tempToast then
                addonTable.tempToast:Hide()
                addonTable.tempToast = nil
            end
        end
    end)

    -- Duration slider for how long the toast stays on screen
    local durationSlider = CreateFrame("Slider", "ToastDurationSlider", optionsPanel, "OptionsSliderTemplate")
    -- Place it below the moveToastCheckbox or adjust as needed
    durationSlider:SetPoint("TOPLEFT", moveToastCheckbox, "BOTTOMLEFT", 0, -60)
    durationSlider:SetMinMaxValues(1, 10)  -- Allowing a duration range between 1 to 10 seconds
    durationSlider:SetValueStep(1)

    -- Use saved value or default to 3 if nil
    addonTable.savedVariables.toastDuration = addonTable.savedVariables.toastDuration or 3
    durationSlider:SetValue(addonTable.savedVariables.toastDuration)

    -- Create a label for the duration slider above the slider
    local durationSliderText = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    durationSliderText:SetPoint("BOTTOMLEFT", durationSlider, "TOPLEFT", 0, 5)
    durationSliderText:SetText("Popup Duration (" .. math.floor(addonTable.savedVariables.toastDuration) .. " sec)")

    -- Update duration text and saved value when slider value changes, rounding to whole number
    durationSlider:SetScript("OnValueChanged", function(self, value)
        addonTable.savedVariables.toastDuration = math.floor(value)
        durationSliderText:SetText("Popup Duration (" .. math.floor(value) .. " sec)")
    end)

    -- Fadeout duration slider for how long the toast takes to fade out
    local fadeoutSlider = CreateFrame("Slider", "ToastFadeoutSlider", optionsPanel, "OptionsSliderTemplate")
    -- Position it below the durationSlider or adjust as needed
    fadeoutSlider:SetPoint("TOPLEFT", durationSlider, "BOTTOMLEFT", 0, -60)
    fadeoutSlider:SetMinMaxValues(1, 5)  -- Allowing fadeout duration between 1 to 5 seconds
    fadeoutSlider:SetValueStep(1)

    -- Use saved value or default to 2 if nil
    addonTable.savedVariables.toastFadeoutDuration = addonTable.savedVariables.toastFadeoutDuration or 2
    fadeoutSlider:SetValue(addonTable.savedVariables.toastFadeoutDuration)

    -- Create a label for the fadeout slider above the slider
    local fadeoutSliderText = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fadeoutSliderText:SetPoint("BOTTOMLEFT", fadeoutSlider, "TOPLEFT", 0, 5)
    fadeoutSliderText:SetText("Popup Fadeout Duration (" .. math.floor(addonTable.savedVariables.toastFadeoutDuration) .. " sec)")

    -- Update fadeout text and saved value when slider value changes, rounding to whole number
    fadeoutSlider:SetScript("OnValueChanged", function(self, value)
        addonTable.savedVariables.toastFadeoutDuration = math.floor(value)  -- Round to nearest integer
        fadeoutSliderText:SetText("Popup Fadeout Duration (" .. math.floor(value) .. " sec)")
    end)

    optionsPanel.okay = function() end
    optionsPanel.default = function()
        addonTable.savedVariables.scale = 1.0
        addonTable.savedVariables.glowColor = {1, 0.84, 0, 1}
        addonTable.savedVariables.toastPosition = {x = 0, y = 600}
        addonTable.savedVariables.toastDuration = 3
        addonTable.savedVariables.toastFadeoutDuration = 2
    
        -- Update the sliders and texts with the default values
        scaleSlider:SetValue(Round(addonTable.savedVariables.scale, 1))
        ToastScaleSliderText:SetText("Size of Popup (" .. Round(addonTable.savedVariables.scale, 1) .. ")")
        
        durationSlider:SetValue(addonTable.savedVariables.toastDuration)
        durationSliderText:SetText("Popup Duration (" .. addonTable.savedVariables.toastDuration .. " sec)")
        
        fadeoutSlider:SetValue(addonTable.savedVariables.toastFadeoutDuration)
        fadeoutSliderText:SetText("Fadeout Duration (" .. addonTable.savedVariables.toastFadeoutDuration .. " sec)")
    
        moveToastCheckbox:SetChecked(false)
    end    

    local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Emote Popup")
    Settings.RegisterAddOnCategory(category)
end

-- Create the main frame and register the events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        addonTable.savedVariables = EmotePopupSavedVars
    elseif event == "PLAYER_LOGIN" then
        CreateOptionsPanel()
    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        local text, playerName, _, _, _, _, _, _, _, _, _, senderGUID = ...
        if playerName and playerName ~= "" then
            local isTargetedAtPlayer = text:find("you") ~= nil
            ShowToast(text, isTargetedAtPlayer, playerName, senderGUID)
        end
    end
end

frame:SetScript("OnEvent", OnEvent)
