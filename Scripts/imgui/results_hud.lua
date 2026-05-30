local M = {}
local umg_factory = require("utils.umg_factory")
local hud_utils = require("utils.hud_utils")
local abilities_catalog = require("domains.abilities_catalog")
local cfg = require("config")

M.resultsWidget = nil

--[[ ============ UTILS ============ --]]

function M.GetRank(acc, totalActions)
	if totalActions == 0 then
		return "F", hud_utils.FSlateColor(0.4, 0, 0, 1)
	end -- Dark Red failure

	if acc >= 100 then
		return "SS", hud_utils.FSlateColor(0.69, 0.15, 1, 1) -- Electric Purple (#B026FF)
	elseif acc >= 98 then
		return "S+", hud_utils.FSlateColor(1, 0, 1, 1) -- Bright Magenta
	elseif acc >= 95 then
		return "S", hud_utils.FSlateColor(1, 1, 0, 1) -- Yellow
	elseif acc >= 90 then
		return "A+", hud_utils.FSlateColor(0, 1, 0.5, 1) -- Emerald Green
	elseif acc >= 85 then
		return "A", hud_utils.FSlateColor(0, 1, 0, 1) -- Green
	elseif acc >= 80 then
		return "B+", hud_utils.FSlateColor(0, 1, 1, 1) -- Cyan
	elseif acc >= 70 then
		return "B", hud_utils.FSlateColor(0, 0.4, 1, 1) -- Blue
	elseif acc >= 60 then
		return "C", hud_utils.FSlateColor(1, 0.5, 0, 1) -- Orange
	else
		return "D", hud_utils.FSlateColor(1, 0, 0, 1) -- Red
	end
end

--[[ ============ RENDERERS ============ --]]

local function renderHeader(container, songName)
	umg_factory.CreateTextBlock(container, "ResultsTitle", {
		size = 30,
		text = "PERFORMANCE REPORT",
		color = hud_utils.FSlateColor(1, 1, 1, 1), -- white
		fontPath = "/Game/Pagoda/UI/Fonts/Primary_Font.Primary_Font",
	})

	umg_factory.CreateTextBlock(container, "SongName", {
		size = 18,
		text = songName or "Unknown Song",
		color = hud_utils.FSlateColor(1, 1, 1, 0.8),
		fontPath = "/Game/Pagoda/UI/Fonts/Primary_Font.Primary_Font",
	})

	umg_factory.CreateTextBlock(container, "Spacer_Header", { size = 15, text = " " })
end

local function renderLeftColumn(container, stats, summary)
	local leftVBox = umg_factory.CreateVerticalBox(container, "LeftVBox")
	container:AddChild(leftVBox)

	-- 1. Accuracy Row
	local displayAcc = (summary.TotalActions > 0) and summary.CurrentAccuracy or 0.0
	umg_factory.CreateTextBlock(leftVBox, "SummaryText", {
		size = 14,
		text = string.format(
			"Overall Accuracy: %.2f%% (%d/%d Hits)",
			displayAcc,
			summary.PerfectHits,
			summary.TotalActions
		),
		color = hud_utils.FSlateColor(1, 1, 1, 1), -- white
	})

	-- 2. Max Combo Row
	local comboText = string.format("Max Combo: %d", summary.MaxCombo or 0)
	local comboColor = hud_utils.FSlateColor(1, 1, 1, 1) -- white
  
	if summary.IsFullCombo and summary.TotalActions > 0 then
		comboText = comboText .. " [FULL COMBO]"
		if summary.CurrentAccuracy >= 100 then
			comboText = comboText .. " (PERFECT!)"
			comboColor = hud_utils.FSlateColor(0.69, 0.15, 1, 1) -- Electric Purple
		end
	end

	umg_factory.CreateTextBlock(leftVBox, "MaxComboText", {
		size = 14,
		text = comboText,
		color = comboColor,
	})

	umg_factory.CreateTextBlock(leftVBox, "Spacer_Left1", { size = 8, text = " " })
	umg_factory.CreateTextBlock(leftVBox, "BreakdownTitle", {
		size = 10,
		text = "BREAKDOWN:",
		color = hud_utils.FSlateColor(0, 1, 1, 0.5),
	})

	-- 3. Abilities Breakdown
	for abilityKey, _ in pairs(abilities_catalog.ABILITIES) do
		local aStats = stats[abilityKey] or { Total = 0, Perfect = 0 }
		local acc = (aStats.Total > 0) and (aStats.Perfect / aStats.Total * 100) or 0.0

		local hBox = umg_factory.CreateHorizontalBox(leftVBox, "HBox_" .. abilityKey)
		leftVBox:AddChild(hBox)

		umg_factory.CreateTextBlock(hBox, "Label_" .. abilityKey, {
			size = 10,
			text = string.format("%s: ", abilities_catalog.GetLabel(abilityKey, cfg.HUD_LABEL_LAYOUT)),
		})

		umg_factory.CreateTextBlock(hBox, "Stats_" .. abilityKey, {
			size = 10,
			color = hud_utils.FSlateColor(1, 1, 1, 1), -- white
			text = string.format("[%d/%d] ", aStats.Perfect, aStats.Total),
		})

		umg_factory.CreateTextBlock(hBox, "Acc_" .. abilityKey, {
			size = 10,
			color = hud_utils.FSlateColor(1, 1, 1, 0.6),
			text = string.format("(%.f%%)", acc),
		})
	end
end

local function renderRightColumn(container, summary)
	local rightVBox = umg_factory.CreateVerticalBox(container, "RightVBox")
	container:AddChild(rightVBox)

	umg_factory.CreateTextBlock(rightVBox, "RankLabel", {
		size = 18,
		text = "FINAL RANK",
		color = hud_utils.FSlateColor(1, 1, 1, 0.5),
		fontPath = "/Game/Pagoda/UI/Fonts/Primary_Font.Primary_Font",
	})

	local rankChar, rankColor = M.GetRank(summary.CurrentAccuracy, summary.TotalActions)

	umg_factory.CreateTextBlock(rightVBox, "RankValue", {
		size = 86,
		text = rankChar,
		color = rankColor,
		fontPath = "/Game/Pagoda/UI/Fonts/Visual_Font.Visual_Font",
		skewAmount = 0.15,
		shadowOffset = { X = 4, Y = 4 },
		shadowColor = hud_utils.FLinearColor(0, 0, 0, 1),
	})
end

--[[ ============ CORE ============ --]]

function M.Show(granularStats, sessionSummary)
	if M.resultsWidget and M.resultsWidget:IsValid() then
		M.resultsWidget:RemoveFromParent()
	end

	local hud = umg_factory.CreateHUD("ResultsHUD")
	if not hud then
		return
	end

	local canvas = umg_factory.CreateCanvas(hud.WidgetTree, "ResultsCanvas")
	local mainVBox = umg_factory.CreateVerticalBox(canvas, "ResultsMainVBox")

	-- 1. Header
	renderHeader(mainVBox, sessionSummary.SongName)

	-- 2. Content Columns
	local columnsHBox = umg_factory.CreateHorizontalBox(mainVBox, "ColumnsHBox")
	mainVBox:AddChild(columnsHBox)

	renderLeftColumn(columnsHBox, granularStats, sessionSummary)
	umg_factory.CreateTextBlock(columnsHBox, "ColumnSpacer", { size = 40, text = "      " }) -- Spacer
	renderRightColumn(columnsHBox, sessionSummary)

	-- 3. Container Polish
	local border = umg_factory.CreateBorder(canvas, "ResultsBorder", {
		content = mainVBox,
		brushColor = hud_utils.FLinearColor(0, 0, 0, 0.1),
		padding = { Left = 40, Top = 20, Right = 40, Bottom = 20 },
	})

	umg_factory.ApplyAlignment(canvas, border, "top", { X = 100, Y = 60 })

	hud.Visibility = hud_utils.Visibility.HITTESTINVISIBLE
	hud:AddToViewport(1000)
	M.resultsWidget = hud
end

function M.Hide()
	if M.resultsWidget and M.resultsWidget:IsValid() then
		pcall(function()
			M.resultsWidget:SetVisibility(hud_utils.Visibility.HIDDEN)
		end)
	end
end

return M
