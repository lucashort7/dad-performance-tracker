local M = {}
local in_game_progress_hud = require("imgui.in_game_progress_hud")
local results_hud = require("imgui.results_hud")
local status_indicator_hud = require("imgui.status_indicator_hud")
local hud_utils = require("utils.hud_utils")
local log = require("utils.log")

-- Enums for Mod State
M.States = {
	PRE_GAME = 1, -- Main Menu, Loading, Prep
	IN_GAME = 2, -- Countdown finished, actively playing
	RESULTS = 3, -- Song finished, HighScores screen visible
}

M.CurrentState = M.States.PRE_GAME

--- Global Setup: Recreate everything if needed (Boot/Map Change)
function M.EnsureUI()
	if not status_indicator_hud.IsValid() then
		status_indicator_hud.Create()
	end
	if not in_game_progress_hud.IsValid() then
		in_game_progress_hud.Create()
	end
	-- Note: ResultsHUD is created on-demand in .Show()
end

--- Primary Router for State Changes
---@param newState number One of M.States
function M.SetState(newState, sessionState)
	M.CurrentState = newState
	M.EnsureUI()

	if newState == M.States.PRE_GAME then
		in_game_progress_hud.SetVisibility(hud_utils.Visibility.HIDDEN)
		results_hud.Hide()
	elseif newState == M.States.IN_GAME then
		in_game_progress_hud.SetVisibility(hud_utils.Visibility.HITTESTINVISIBLE)
		results_hud.Hide()
	elseif newState == M.States.RESULTS then
		in_game_progress_hud.SetVisibility(hud_utils.Visibility.HIDDEN)
		if sessionState then
			results_hud.Show(sessionState.GranularStats, sessionState)
		end
	end
end

--- Heartbeat sync for the 400ms loop
function M.Sync(sessionState)
	M.EnsureUI()

	-- Ensure we use the absolute latest global state
	local liveState = sessionState or _G.__SessionAggAccuracy

	-- Sync Status Indicator (Always ON/OFF)
	status_indicator_hud.SetStatus(liveState.IsTrackerVisible)

	-- Enforce Visibility Logic
	if liveState.IsTrackerVisible and M.CurrentState == M.States.IN_GAME then
		-- TRIPLE CHECK: If we ARE in-game but the widget is NOT in viewport, force recreation
		if not in_game_progress_hud.IsValid() then
			in_game_progress_hud.Create()
		end

		in_game_progress_hud.Update(liveState)
		in_game_progress_hud.SetVisibility(hud_utils.Visibility.HITTESTINVISIBLE)
	else
		in_game_progress_hud.SetVisibility(hud_utils.Visibility.HIDDEN)
	end
end

return M
