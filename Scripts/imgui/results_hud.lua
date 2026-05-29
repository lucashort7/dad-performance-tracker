local M = {}
local Factory = require("imgui.umg_factory")
local helpers = require("helpers.hud_helpers")
local abilities_helper = require("helpers.abilities_helper")
local cfg = require("config")

M.resultsWidget = nil

function M.GetRank(acc, totalActions)
    if totalActions == 0 then return "F", helpers.FSlateColor(1, 0, 0, 1) end

    if acc >= 100 then return "S", helpers.FSlateColor(1, 1, 0, 1) -- Bright Yellow
    elseif acc >= 95 then return "A", helpers.FSlateColor(1, 0, 1, 1) -- Bright Pink
    elseif acc >= 85 then return "B", helpers.FSlateColor(0, 1, 1, 1) -- Cyan
    elseif acc >= 70 then return "C", helpers.FSlateColor(1, 0.5, 0, 1) -- Orange
    else return "D", helpers.FSlateColor(1, 0, 0, 1) -- Red
    end
end

function M.Show(granularStats, sessionSummary)
    local hud = Factory.CreateHUD("ResultsHUD")
    if not hud then return end

    local canvas = Factory.CreateCanvas(hud.WidgetTree, "ResultsCanvas")
    
    -- Main Container (Overall Vertical)
    local mainVBox = Factory.CreateVerticalBox(canvas, "ResultsMainVBox")
    
    -- HEADER
    Factory.CreateTextBlock(mainVBox, "ResultsTitle", {
        size = 30,
        text = "PERFORMANCE REPORT",
        color = helpers.FSlateColor(1, 1, 1, 1),
        fontPath = "/Game/Pagoda/UI/Fonts/Primary_Font.Primary_Font"
    })

    -- SONG NAME
    Factory.CreateTextBlock(mainVBox, "SongName", {
        size = 18,
        text = sessionSummary.SongName or "Unknown Song",
        color = helpers.FSlateColor(1, 1, 1, 0.6),
        fontPath = "/Game/Pagoda/UI/Fonts/Primary_Font.Primary_Font"
    })

    Factory.CreateTextBlock(mainVBox, "Spacer_Header", { size = 15, text = " " })

    -- TWO COLUMN LAYOUT
    local columnsHBox = Factory.CreateHorizontalBox(mainVBox, "ColumnsHBox")
    mainVBox:AddChild(columnsHBox)

    -- LEFT COLUMN: BREAKDOWN
    local leftVBox = Factory.CreateVerticalBox(columnsHBox, "LeftVBox")
    columnsHBox:AddChild(leftVBox)
    
    -- Overall Summary in Left Column
    local displayAcc = (sessionSummary.TotalActions > 0) and sessionSummary.CurrentAccuracy or 0.0
    local summaryText = string.format("Overall Accuracy: %.2f%% (%d/%d Hits)", 
        displayAcc, sessionSummary.PerfectHits, sessionSummary.TotalActions)
    
    Factory.CreateTextBlock(leftVBox, "SummaryText", {
        size = 14,
        text = summaryText,
        color = helpers.FSlateColor(1, 1, 1, 1)
    })

    -- MAX COMBO & FC
    local comboText = string.format("Max Combo: %d", sessionSummary.MaxCombo or 0)
    local comboColor = helpers.FSlateColor(1, 0.8, 0, 1) -- Golden
    
    if sessionSummary.IsFullCombo and sessionSummary.TotalActions > 0 then
        comboText = comboText .. " [FULL COMBO]"
        if sessionSummary.CurrentAccuracy >= 100 then
            comboText = comboText .. " (PERFECT!)"
            comboColor = helpers.FSlateColor(0, 1, 1, 1) -- Cyan for Perfect FC
        end
    end

    Factory.CreateTextBlock(leftVBox, "MaxComboText", {
        size = 14,
        text = comboText,
        color = comboColor
    })

    Factory.CreateTextBlock(leftVBox, "Spacer_Left1", { size = 8, text = " " })
    Factory.CreateTextBlock(leftVBox, "BreakdownTitle", { size = 10, text = "BREAKDOWN:", color = helpers.FSlateColor(1, 1, 1, 0.4) })

    for abilityKey, _ in pairs(abilities_helper.ABILITIES) do
        local stats = granularStats[abilityKey] or {Total = 0, Perfect = 0}
        local acc = (stats.Total > 0) and (stats.Perfect / stats.Total * 100) or 0.0
        
        local hBox = Factory.CreateHorizontalBox(leftVBox, "HBox_" .. abilityKey)
        leftVBox:AddChild(hBox)

        Factory.CreateTextBlock(hBox, "Label_" .. abilityKey, {
            size = 10,
            text = string.format("%s: ", abilities_helper.GetLabel(abilityKey, cfg.HUD_LABEL_LAYOUT))
        })

        Factory.CreateTextBlock(hBox, "Stats_" .. abilityKey, {
            size = 10,
            text = string.format("[%d/%d] ", stats.Perfect, stats.Total)
        })

        Factory.CreateTextBlock(hBox, "Acc_" .. abilityKey, {
            size = 10,
            color = helpers.FSlateColor(1, 1, 1, 0.8),
            text = string.format("(%.f%%)", acc)
        })
    end

    -- SPACER BETWEEN COLUMNS
    Factory.CreateTextBlock(columnsHBox, "ColumnSpacer", { size = 40, text = "      " })

    -- RIGHT COLUMN: RANK
    local rightVBox = Factory.CreateVerticalBox(columnsHBox, "RightVBox")
    columnsHBox:AddChild(rightVBox)

    Factory.CreateTextBlock(rightVBox, "RankLabel", { 
        size = 18, 
        text = "FINAL RANK", 
        color = helpers.FSlateColor(1, 1, 1, 0.5),
        fontPath = "/Game/Pagoda/UI/Fonts/Primary_Font.Primary_Font"
    })

    local rankChar, rankColor = M.GetRank(sessionSummary.CurrentAccuracy, sessionSummary.TotalActions)

    Factory.CreateTextBlock(rightVBox, "RankValue", {
        size = 86, -- Even bigger for impact!
        text = rankChar,
        color = rankColor,
        fontPath = "/Game/Pagoda/UI/Fonts/Visual_Font.Visual_Font",
        shadowOffset = {X = 4, Y = 4},
        shadowColor = helpers.FLinearColor(0, 0, 0, 1) -- Solid black shadow for readability
    })

    local border = Factory.CreateBorder(canvas, "ResultsBorder", {
        content = mainVBox,
        brushColor = helpers.FLinearColor(0, 0, 0, 0.1), -- Nearly transparent
        padding = {Left = 40, Top = 20, Right = 40, Bottom = 20}
    })

    -- Surgical positioning: Offset to the right (X:100) and down (Y:60)
    Factory.ApplyAlignment(canvas, border, "top", {X = 100, Y = 60})

    hud.Visibility = helpers.Visibility.HITTESTINVISIBLE
    hud:AddToViewport(1000)
    M.resultsWidget = hud
end

function M.Hide()
    if M.resultsWidget and M.resultsWidget:IsValid() then
        pcall(function() M.resultsWidget:SetVisibility(helpers.Visibility.HIDDEN) end)
    end
end

return M
