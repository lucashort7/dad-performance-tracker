local M = {}
local umg_factory = require("utils.umg_factory")
local hud_utils = require("utils.hud_utils")
local cfg = require("config")

M.statusIndicatorWidget = nil
M.statusIndicatorValue = nil

function M.Create()
	local hud = umg_factory.CreateHUD("ModStatusHUD")
	if not hud then
		return
	end

	local canvas = umg_factory.CreateCanvas(hud.WidgetTree, "ModStatusCanvas")

	local hBox = umg_factory.CreateHorizontalBox(canvas, "StatusHBox")

	umg_factory.CreateTextBlock(hBox, "StatusLabel", {
		size = 8,
		text = cfg.MOD_NAME .. ": ",
		color = hud_utils.FSlateColor(1, 1, 1, 0.6),
	})

	M.statusIndicatorValue = umg_factory.CreateTextBlock(hBox, "StatusValue", {
		size = 8,
		text = "ON",
		color = hud_utils.FSlateColor(0, 1, 0, 0.8),
	})

	local border = umg_factory.CreateBorder(canvas, "StatusBorder", {
		content = hBox,
		padding = { Left = 8, Top = 2, Right = 8, Bottom = 2 },
		brushColor = hud_utils.FLinearColor(0, 0, 0, 0.4),
	})

	umg_factory.ApplyAlignment(canvas, border, "bottom")

	hud.Visibility = hud_utils.Visibility.HITTESTINVISIBLE
	hud:AddToViewport(999)
	M.statusIndicatorWidget = hud
end

function M.SetStatus(isOn)
  -- TODO: review with gemy why this breaks logic...
	-- if not M.statusIndicatorWidget or not M.statusIndicatorWidget:IsValid() then
	-- 	M.Create()
	-- end
	-- if not M.statusIndicatorValue or not M.statusIndicatorValue:IsValid() then
	-- 	return
	-- end
	pcall(function()
		if isOn then
			M.statusIndicatorValue:SetText(umg_factory.ToFText("ON"))
			M.statusIndicatorValue:SetColorAndOpacity(hud_utils.FSlateColor(0, 1, 0, 0.8))
		else
			M.statusIndicatorValue:SetText(umg_factory.ToFText("OFF"))
			M.statusIndicatorValue:SetColorAndOpacity(hud_utils.FSlateColor(1, 0, 0, 0.8))
		end
	end)
end

function M.IsValid()
	local isValid = M.statusIndicatorWidget and M.statusIndicatorWidget:IsValid()
	if isValid then
		local ok, inView = pcall(function()
			return M.statusIndicatorWidget:IsInViewport()
		end)
		if ok and not inView then
			return false
		end
	end
	return isValid
end

return M
