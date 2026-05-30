local M = {}
local UEHelpers = require("UEHelpers")
local cfg = require("config")
local hud_utils = require("utils.hud_utils")
local umg_factory = require("utils.umg_factory")
local abilities_catalog = require("domains.abilities_catalog")

M.progressWidget = nil
M.textControls = {}
M.summaryControls = {}

local function GetAccuracyColor(acc)
	if acc >= 100 then
		return hud_utils.FSlateColor(0, 1, 0, 0.9) -- Bright Green
	elseif acc >= 85 then
		return hud_utils.FSlateColor(0.8, 0, 1, 0.9) -- Pink
	elseif acc >= 70 then
		return hud_utils.FSlateColor(0, 0.8, 1, 0.9) -- Cyan
	elseif acc >= 40 then
		return hud_utils.FSlateColor(0.65, 1, 0, 0.9) -- Yellow
	else
		return hud_utils.FSlateColor(1, 0.033, 0.033, 0.9) -- Lightly Red
	end
end

function M.Create()
	local hud = umg_factory.CreateHUD("InGameProgressHUD")
	if not hud then
		return
	end

	local canvas = umg_factory.CreateCanvas(hud.WidgetTree, "InGameProgressCanvas")
	local vBox = umg_factory.CreateVerticalBox(canvas, "StatsVerticalBox")

	-- Session Summary Line
	local summaryHBox = umg_factory.CreateHorizontalBox(vBox, "HBox_InGame_Summary")
	vBox:AddChild(summaryHBox)

	umg_factory.CreateTextBlock(summaryHBox, "TextBlock_Summary_Label", {
		size = 11,
		text = "Session: ",
		color = hud_utils.FSlateColor(1, 1, 1, 0.7),
	})

	local summaryTotalText = umg_factory.CreateTextBlock(summaryHBox, "TextBlock_Summary_Total", {
		size = 11,
		text = "0 hits ",
	})

	local summaryAccText = umg_factory.CreateTextBlock(summaryHBox, "TextBlock_Summary_Acc", {
		size = 11,
		text = "(100%)",
		color = GetAccuracyColor(100),
	})

	M.summaryControls = {
		Total = summaryTotalText,
		Accuracy = summaryAccText,
	}

	umg_factory.CreateTextBlock(vBox, "Spacer", { size = 4, text = " " })

	for abilityKey, _ in pairs(abilities_catalog.ABILITIES) do
		local hBox = umg_factory.CreateHorizontalBox(vBox, "HBox_InGame_" .. abilityKey)
		vBox:AddChild(hBox)

		local label = abilities_catalog.GetLabel(abilityKey, cfg.HUD_LABEL_LAYOUT)

		umg_factory.CreateTextBlock(hBox, "TextBlock_Label_" .. abilityKey, {
			size = 10,
			text = string.format("%s: ", label),
			skew = 0.176,
		})

		local statsText = umg_factory.CreateTextBlock(hBox, "TextBlock_Stats_" .. abilityKey, {
			size = 10,
			text = "[0/0] ",
		})

		local accText = umg_factory.CreateTextBlock(hBox, "TextBlock_Acc_" .. abilityKey, {
			size = 9,
			text = "(100%)",
			color = GetAccuracyColor(100),
		})

		M.textControls[abilityKey] = {
			Stats = statsText,
			Accuracy = accText,
		}
	end

	local border = umg_factory.CreateBorder(canvas, "InGameProgressBorder", {
		content = vBox,
	})

	umg_factory.ApplyAlignment(canvas, border, cfg.HUD_MAIN_ALLIGNMENT)

	hud.Visibility = hud_utils.Visibility.HIDDEN
	hud:AddToViewport(999)
	M.progressWidget = hud
end

function M.Update(state)
	if not M.progressWidget or not M.progressWidget:IsValid() then
		M.Create()
	end
	if not M.textControls then
		return
	end

	if state and M.summaryControls.Total and M.summaryControls.Total:IsValid() then
		pcall(function()
			M.summaryControls.Total:SetText(
				umg_factory.ToFText(string.format("[%d/%d] ", state.PerfectHits, state.TotalActions))
			)
			M.summaryControls.Accuracy:SetText(umg_factory.ToFText(string.format("(%.1f%%)", state.CurrentAccuracy)))
			M.summaryControls.Accuracy:SetColorAndOpacity(GetAccuracyColor(state.CurrentAccuracy))
		end)
	end

	for abilityKey, _ in pairs(abilities_catalog.ABILITIES) do
		local controls = M.textControls[abilityKey]
		if controls and controls.Stats:IsValid() and controls.Accuracy:IsValid() then
			local stats = state.GranularStats[abilityKey] or { Total = 0, Perfect = 0 }
			local acc = (stats.Total > 0) and (stats.Perfect / stats.Total * 100.0) or 100.0

			pcall(function()
				controls.Stats:SetText(umg_factory.ToFText(string.format("[%d/%d] ", stats.Perfect, stats.Total)))
				controls.Accuracy:SetText(umg_factory.ToFText(string.format("(%.f%%)", acc)))
				controls.Accuracy:SetColorAndOpacity(GetAccuracyColor(acc))
			end)
		end
	end
end

function M.SetVisibility(visibility)
	if not M.progressWidget or not M.progressWidget:IsValid() then
		M.Create()
	end
	if not M.progressWidget or not M.progressWidget:IsValid() then
		return
	end
	if M.progressWidget:GetVisibility() == visibility then
		return
	end
	pcall(function()
		M.progressWidget:SetVisibility(visibility)
	end)
end

function M.Toggle()
	if not M.progressWidget or not M.progressWidget:IsValid() then
		M.Create()
	end
	if not M.progressWidget or not M.progressWidget:IsValid() then
		return false
	end
	local current = M.progressWidget:GetVisibility()
	local nextVisibility = (
		current == hud_utils.Visibility.HITTESTINVISIBLE and hud_utils.Visibility.HIDDEN
		or hud_utils.Visibility.HITTESTINVISIBLE
	)
	M.SetVisibility(nextVisibility)
	return nextVisibility == hud_utils.Visibility.HITTESTINVISIBLE
end

function M.IsValid()
	local isValid = M.progressWidget and M.progressWidget:IsValid()
	if isValid then
		local ok, inView = pcall(function()
			return M.progressWidget:IsInViewport()
		end)
		if ok and not inView then
			return false
		end
	end
	return isValid
end

return M
