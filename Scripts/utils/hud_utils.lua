local M = {}

local UEHelpers = require("UEHelpers")

M.Visibility = {
	VISIBLE = 0,
	COLLAPSED = 1,
	HIDDEN = 2,
	HITTESTINVISIBLE = 3,
	SELFHITTESTINVISIBLE = 4,
	ALL = 5,
}

M.Alignments = {
	center = { anchor = { 0.5, 0.5 }, align = { 0.5, 0.5 }, pos = { 0, 0 } },
	top = { anchor = { 0.5, 0.0 }, align = { 0.5, 0.0 }, pos = { 0, 0 } },
	top_center_right = { anchor = { 0.5, 0.0 }, align = { 0.5, 0.0 }, pos = { 60, 20 } },

	bottom = { anchor = { 0.5, 1 }, align = { 0.5, 1 }, pos = { 0, -10 } },
	topleft = { anchor = { 0, 0 }, align = { 0, 0 }, pos = { 10, 10 } },
	topright = { anchor = { 1, 0 }, align = { 1, 0 }, pos = { -10, 10 } },
	bottomleft = { anchor = { 0, 1 }, align = { 0, 1 }, pos = { 10, -10 } },
	bottomright = { anchor = { 1, 1 }, align = { 1, 1 }, pos = { -10, -10 } },

	-- only for testing
	upper_left = { anchor = { 0, 0.25 }, align = { 0, 0.25 }, pos = { 10, 7.5 } },
	topmidleft_test = { anchor = { 0.25, 0 }, align = { 0.25, 0 }, pos = { 7, 10 } },
	midbottomleft_test = { anchor = { 0.25, 1 }, align = { 0.25, 1 }, pos = { -7.5, -10 } },
	midbottomright_test = { anchor = { 1, 0.95 }, align = { 1, 0.95 }, pos = { -9, -9 } },
}

M.KTextLib = UEHelpers.GetKismetTextLibrary()

function M.FLinearColor(R, G, B, A)
	return { R = R, G = G, B = B, A = A }
end
function M.FSlateColor(R, G, B, A)
	return { SpecifiedColor = M.FLinearColor(R, G, B, A), ColorUseRule = 0 }
end

return M
