local M = {}
local Factory = require("imgui.umg_factory")
local helpers = require("helpers.hud_helpers")

M.statusIndicatorWidget = nil
M.statusIndicatorValue = nil

function M.Create()
    local hud = Factory.CreateHUD("ModStatusHUD")
    if not hud then return end

    local canvas = Factory.CreateCanvas(hud.WidgetTree, "ModStatusCanvas")
    
    local hBox = Factory.CreateHorizontalBox(canvas, "StatusHBox")
    
    Factory.CreateTextBlock(hBox, "StatusLabel", {
        size = 8,
        text = "AccuracyTracker: ",
        color = helpers.FSlateColor(1, 1, 1, 0.6)
    })
    
    M.statusIndicatorValue = Factory.CreateTextBlock(hBox, "StatusValue", {
        size = 8,
        text = "ON",
        color = helpers.FSlateColor(0, 1, 0, 0.8)
    })

    local border = Factory.CreateBorder(canvas, "StatusBorder", {
        content = hBox,
        padding = {Left = 8, Top = 2, Right = 8, Bottom = 2},
        brushColor = helpers.FLinearColor(0, 0, 0, 0.4)
    })

    Factory.ApplyAlignment(canvas, border, "bottom")

    hud.Visibility = helpers.Visibility.HITTESTINVISIBLE
    hud:AddToViewport(999)
    M.statusIndicatorWidget = hud
end

function M.SetStatus(isOn)
    if not M.statusIndicatorValue or not M.statusIndicatorValue:IsValid() then return end
    pcall(function()
        if isOn then
            M.statusIndicatorValue:SetText(Factory.ToFText("ON"))
            M.statusIndicatorValue:SetColorAndOpacity(helpers.FSlateColor(0, 1, 0, 0.8))
        else
            M.statusIndicatorValue:SetText(Factory.ToFText("OFF"))
            M.statusIndicatorValue:SetColorAndOpacity(helpers.FSlateColor(1, 0, 0, 0.8))
        end
    end)
end

function M.IsValid()
    return M.statusIndicatorWidget and M.statusIndicatorWidget:IsValid()
end

return M
