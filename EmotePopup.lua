-- Table to store active toasts
local activeToasts = {}

-- Capture the addon name and a table for saved variables
local addonName, addonTable = ...

-- Define SavedVariables with defaults
EmotePopupSavedVars = EmotePopupSavedVars or {
    scale = 1.0,
    glowColor = {1, 0.84, 0, 1},
    toastPosition = {x = 0, y = -100},
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

    print("Saved relative position to:", relativeX, relativeY)
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

    local playerOnlyName = playerName:match("^[^%-]+")
    local _, class = GetPlayerInfoByGUID(playerGUID)
    local classColor = RAID_CLASS_COLORS[class] or {r = 1, g = 1, b = 1}
    local xPos = addonTable.savedVariables.toastPosition.x
    local yPos = addonTable.savedVariables.toastPosition.y

    local toast = CreateFrame("Frame", nil, UIParent)
    toast:SetPoint("CENTER", UIParent, "CENTER", xPos, yPos)
    toast:SetHeight(80 * addonTable.savedVariables.scale)

    local text = toast:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    text:SetPoint("CENTER", toast, "CENTER")

    local playerNameColor = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, playerOnlyName)
    local finalMessage = message:gsub(playerName .. "%-?%w*", playerNameColor)
    finalMessage = finalMessage:gsub("(%a+%-[%a]+)", function(fullName)
        return fullName:match("^[^%-]+")
    end)

    text:SetText(finalMessage)
    text:SetTextColor(255/255, 128/255, 64/255)

    local textWidth = text:GetStringWidth() + 40
    toast:SetWidth(textWidth * addonTable.savedVariables.scale)

    local bg = toast:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\AddOns\\EmotePopup\\Images\\Background.png")
    bg:SetAllPoints()

    if isTargetedAtPlayer then
        local glow = toast:CreateTexture(nil, "BACKGROUND", nil, -1)
        glow:SetPoint("CENTER", toast, "CENTER")
        glow:SetSize(textWidth * 1.4 * addonTable.savedVariables.scale, 150 * addonTable.savedVariables.scale)
        glow:SetTexture("Interface\\GLUES\\MODELS\\UI_DRAENEI\\GenericGlow64")
        glow:SetBlendMode("ADD")

        local r, g, b, a = unpack(addonTable.savedVariables.glowColor)
        glow:SetVertexColor(r, g, b, a)
    end

    table.insert(activeToasts, 1, toast)
    AdjustActiveToasts()

    if not isMovable then
        C_Timer.After(3, function()
            UIFrameFadeOut(toast, 2, 1, 0)
            C_Timer.After(2, function()
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
    print("Opening Color Picker with values: ", r, g, b, a)

    if not ColorPickerFrame then
        print("Error: ColorPickerFrame is not available.")
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
    print("Saved glow color to:", newR, newG, newB, newA)
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
    ToastScaleSliderText:SetText("Size of Toast (" .. Round(addonTable.savedVariables.scale, 1) .. ")")
    ToastScaleSliderLow:SetText("0.5")
    ToastScaleSliderHigh:SetText("2.0")

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        local roundedValue = Round(value, 1)
        addonTable.savedVariables.scale = roundedValue
        ToastScaleSliderText:SetText("Size of Toast (" .. roundedValue .. ")")
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
    moveToastCheckbox.Text:SetText("Move Toast Popup")
    moveToastCheckbox:SetChecked(false)

    moveToastCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if not addonTable.tempToast or not addonTable.tempToast:IsShown() then
                addonTable.tempToast = ShowToast("Move Me!", false, true)
            end
        else
            if addonTable.tempToast then
                addonTable.tempToast:Hide()
                addonTable.tempToast = nil
            end
        end
    end)

    optionsPanel.okay = function() end
    optionsPanel.default = function()
        addonTable.savedVariables.scale = 1.0
        addonTable.savedVariables.glowColor = {1, 0.84, 0, 1}
        addonTable.savedVariables.toastPosition = {x = 0, y = -100}

        scaleSlider:SetValue(Round(addonTable.savedVariables.scale, 1))
        ToastScaleSliderText:SetText("Size of Toast (" .. Round(addonTable.savedVariables.scale, 1) .. ")")
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
