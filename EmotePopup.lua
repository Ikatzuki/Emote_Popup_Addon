-- Table to store active toasts
local activeToasts = {}

-- Capture the addon name and a table for saved variables
local addonName, addonTable = ...

-- Define SavedVariables to store settings, falling back to defaults if not available
EmotePopupSavedVars = EmotePopupSavedVars or {
    scale = 1.0,  -- Default scale
    glowColor = {1, 0.84, 0, 1},  -- Default glow color (gold)
    toastPosition = {x = 0, y = -100},  -- Default toast position
}

-- Alias the saved variables for easy use
addonTable.savedVariables = EmotePopupSavedVars

-- Debugging function to ensure position values are valid
local function ClampPosition(x, y)
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    x = math.min(math.max(x, 0), screenWidth - 300)  -- Clamp within screen width minus the toast width
    y = math.min(math.max(y, 0), screenHeight - 80)  -- Clamp within screen height minus the toast height
    return x, y
end

-- Save position after dragging
local function SavePosition(toast)
    local x = toast:GetLeft()
    local y = toast:GetTop()

    -- Debug print the values being saved
    print("Saving position:", x, y)

    -- Save clamped position
    addonTable.savedVariables.toastPosition.x, addonTable.savedVariables.toastPosition.y = ClampPosition(x, y)
end

-- Function to create toast with optional drag functionality for positioning
function ShowToast(message, isTargetedAtPlayer, isMovable)
    -- Default isMovable to false if not provided
    isMovable = isMovable or false

    -- Get the clamped position to avoid off-screen placement
    local xPos, yPos = ClampPosition(addonTable.savedVariables.toastPosition.x, addonTable.savedVariables.toastPosition.y)

    -- Debug print to verify position before setting the toast
    print("Setting toast position to:", xPos, yPos)

    -- Create the toast frame
    local toast = CreateFrame("Frame", nil, UIParent)
    addonTable.tempToast = toast
    toast:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", xPos, yPos)
    toast:SetSize(300 * addonTable.savedVariables.scale, 80 * addonTable.savedVariables.scale)

    -- Enable dragging functionality
    toast:SetMovable(isMovable)
    toast:EnableMouse(isMovable)
    if isMovable then
        toast:RegisterForDrag("LeftButton")
        toast:SetScript("OnDragStart", function() toast:StartMoving() end)
        toast:SetScript("OnDragStop", function()
            toast:StopMovingOrSizing()
            SavePosition(toast)  -- Call SavePosition to store the position
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

    -- Fade out after 5 seconds if not in movable mode
    if not isMovable then
        C_Timer.After(3, function()
            UIFrameFadeOut(toast, 2, 1, 0)
            C_Timer.After(2, function() toast:Hide() end)
        end)
    end
end

-- Save position after dragging
local function SavePosition(frame)
    local x, y = frame:GetCenter()
    local scale = frame:GetEffectiveScale()
    addonTable.savedVariables.toastPosition.x = x * scale - GetScreenWidth() / 2
    addonTable.savedVariables.toastPosition.y = y * scale - GetScreenHeight() / 2
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