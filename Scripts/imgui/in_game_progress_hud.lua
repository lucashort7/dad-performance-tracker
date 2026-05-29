local M = {}
local UEHelpers = require("UEHelpers")
local cfg = require("config")
local helpers = require("helpers.hud_helpers")
local Factory = require("imgui.umg_factory")
local abilities_helper = require("helpers.abilities_helper")

M.progressWidget = nil
M.textControls = {}
M.summaryControls = {}

local function GetAccuracyColor(acc)
    if acc >= 100 then
        return helpers.FSlateColor(0, 1, 0, 0.9) -- Bright Green
    elseif acc >= 85 then
        return helpers.FSlateColor(0.8, 0, 1, 0.9) -- Pink
    elseif acc >= 70 then
        return helpers.FSlateColor(0, 0.8, 1, 0.9) -- Cyan
    elseif acc >= 40 then
        return helpers.FSlateColor(0.65, 1, 0, 0.9) -- Yellow
    else
        return helpers.FSlateColor(1, 0.033, 0.033, 0.9) -- Lightly Red
    end
end

function M.Create()
    local hud = Factory.CreateHUD("InGameProgressHUD")
    if not hud then return end

    local canvas = Factory.CreateCanvas(hud.WidgetTree, "InGameProgressCanvas")
    local vBox = Factory.CreateVerticalBox(canvas, "StatsVerticalBox")

    -- Session Summary Line
    local summaryHBox = Factory.CreateHorizontalBox(vBox, "HBox_InGame_Summary")
    vBox:AddChild(summaryHBox)
    
    Factory.CreateTextBlock(summaryHBox, "TextBlock_Summary_Label", {
        size = 11,
        text = "Session: ",
        color = helpers.FSlateColor(1, 1, 1, 0.7)
    })
    
    local summaryTotalText = Factory.CreateTextBlock(summaryHBox, "TextBlock_Summary_Total", {
        size = 11,
        text = "0 hits "
    })
    
    local summaryAccText = Factory.CreateTextBlock(summaryHBox, "TextBlock_Summary_Acc", {
        size = 11,
        text = "(100%)",
        color = GetAccuracyColor(100)
    })

    M.summaryControls = {
        Total = summaryTotalText,
        Accuracy = summaryAccText
    }

    Factory.CreateTextBlock(vBox, "Spacer", { size = 4, text = " " })

    for abilityKey, _ in pairs(abilities_helper.ABILITIES) do
        local hBox = Factory.CreateHorizontalBox(vBox, "HBox_InGame_" .. abilityKey)
        vBox:AddChild(hBox)

        local label = abilities_helper.GetLabel(abilityKey, cfg.HUD_LABEL_LAYOUT)
        
        Factory.CreateTextBlock(hBox, "TextBlock_Label_" .. abilityKey, {
            size = 10,
            text = string.format("%s: ", label),
            skew = 0.176
        })
        
        local statsText = Factory.CreateTextBlock(hBox, "TextBlock_Stats_" .. abilityKey, {
            size = 10,
            text = "[0/0] "
        })
        
        local accText = Factory.CreateTextBlock(hBox, "TextBlock_Acc_" .. abilityKey, {
            size = 9,
            text = "(100%)",
            color = GetAccuracyColor(100)
        })

        M.textControls[abilityKey] = {
            Stats = statsText,
            Accuracy = accText,
        }
    end
    
    local border = Factory.CreateBorder(canvas, "InGameProgressBorder", {
        content = vBox
    })

    Factory.ApplyAlignment(canvas, border, cfg.HUD_MAIN_ALLIGNMENT)

    hud.Visibility = helpers.Visibility.HIDDEN
    hud:AddToViewport(999)
    M.progressWidget = hud
end

function M.Update(granularStats, sessionSummary)
    if not M.textControls then return end

    if sessionSummary and M.summaryControls.Total and M.summaryControls.Total:IsValid() then
        pcall(function()
            M.summaryControls.Total:SetText(Factory.ToFText(string.format("%d hits ", sessionSummary.TotalActions)))
            M.summaryControls.Accuracy:SetText(Factory.ToFText(string.format("(%.1f%%)", sessionSummary.CurrentAccuracy)))
            M.summaryControls.Accuracy:SetColorAndOpacity(GetAccuracyColor(sessionSummary.CurrentAccuracy))
        end)
    end

    for abilityKey, _ in pairs(abilities_helper.ABILITIES) do
        local controls = M.textControls[abilityKey]
        if controls and controls.Stats:IsValid() and controls.Accuracy:IsValid() then
            local stats = granularStats[abilityKey] or {Total = 0, Perfect = 0}
            local acc = (stats.Total > 0) and (stats.Perfect / stats.Total * 100.0) or 100.0
            
            pcall(function()
                controls.Stats:SetText(Factory.ToFText(string.format("[%d/%d] ", stats.Perfect, stats.Total)))
                controls.Accuracy:SetText(Factory.ToFText(string.format("(%.f%%)", acc)))
                controls.Accuracy:SetColorAndOpacity(GetAccuracyColor(acc))
            end)
        end
    end
end

function M.SetVisibility(visibility)
    if not M.progressWidget or not M.progressWidget:IsValid() then return end
    if M.progressWidget:GetVisibility() == visibility then return end
    pcall(function() M.progressWidget:SetVisibility(visibility) end)
end

function M.Toggle()
    if not M.progressWidget or not M.progressWidget:IsValid() then return end
    local current = M.progressWidget:GetVisibility()
    local nextVisibility = (current == helpers.Visibility.HITTESTINVISIBLE and 
                helpers.Visibility.HIDDEN or helpers.Visibility.HITTESTINVISIBLE)
    M.SetVisibility(nextVisibility)
    return nextVisibility == helpers.Visibility.HITTESTINVISIBLE
end

function M.IsValid()
    return M.progressWidget and M.progressWidget:IsValid()
end

return M
