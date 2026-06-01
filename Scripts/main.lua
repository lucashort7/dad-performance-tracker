print("[PerformanceTracker] ~>> BOOT: main.lua initiated")

local UEHelpers = require("UEHelpers")
local log = require("utils.log")
local cfg = require("config")
local abilities_catalog = require("domains.abilities_catalog")
local history_handler = require("handlers.history_handler")
local hud_utils = require("utils.hud_utils")
local hud_handler = require("handlers.hud_handler")

print("[PerformanceTracker] ~>> BOOT: All modules loaded successfully")

local pcall, string_format = pcall, string.format

--[[ ============ STATEs ============  --]]
_G.__SessionAggAccuracy = _G.__SessionAggAccuracy or {
  TotalActions = 0,
  PerfectHits = 0,
  CurrentAccuracy = 100.0,
  MaxCombo = 0,
  -- innacurate but helps to determine if we had a combo at all without waiting for end of song
  internalMaxCombo = 0, 
  TotalScore = 0,
  IsFullCombo = true,
  LastRank = "F",
  SongName = "Unknown",
  AssetPath = "",
  LastMusicTime = 0.0,
  LastActionType = "None",
  GranularStats = {},
  IsTrackerVisible = true,
  IsNewPB = false,

  -- Hook Control Flags
  __setup_hooks = false,
  __hb_hooks = false,
  __reg_hooks = {
    Combat = false,
    Combo = false,
    Lifecycle = false,
    Scores = false,
  },
}

--[[ ============ UTILS ============  --]]

local function ResetSessionTracker()
	local state = _G.__SessionAggAccuracy
	state.TotalActions = 0
	state.PerfectHits = 0
	state.CurrentAccuracy = 100.0
	state.MaxCombo = 0
	state.internalMaxCombo = 0
	state.TotalScore = 0
	state.IsFullCombo = true
	state.SongName = "Unknown"
	state.AssetPath = ""
  state.SongUniqueID = ""
	state.LastMusicTime = 0.0
	state.LastActionType = "Reset"
	state.GranularStats = {}
	state.IsNewPB = false
end

local function CaptureSongMetadata()
	local state = _G.__SessionAggAccuracy
	pcall(function()
		local musicInsts = FindAllOf("PagodaMusicSubsystem")
		if musicInsts and #musicInsts > 0 then
			local currentSong = musicInsts[1]:GetCurrentSong()
			if currentSong and currentSong:IsValid() then
				state.SongName = currentSong.SongName:ToString()
				state.AssetPath = currentSong:GetFullName()
        state.SongUniqueID = currentSong:GetImportedSongUniqueID()
				log.debug(
          string_format(
            "CURRENT SONG METADATA:  %s | %s | %s ",
            tostring(state.SongUniqueID),
            state.SongName,
            state.AssetPath
          )
        )
			end
		end
	end)
end

--[[ ============ CORE PIPELINE ============  --]]

local function UpdateGlobalAccuracy(isPerfect, musicTime, actionType)
	local state = _G.__SessionAggAccuracy
	musicTime = musicTime or 0.0
	if state.LastActionType == actionType and state.LastMusicTime == musicTime then
		return
	end

	-- FALLBACK: If we are hitting things but not in IN_GAME state, force it now.
	if hud_handler.CurrentState ~= hud_handler.States.IN_GAME then
		hud_handler.SetState(hud_handler.States.IN_GAME, state)
		log.debug("Gameplay Started via Combat Fallback (Step 4)")
	end

	if not state.GranularStats[actionType] then
		state.GranularStats[actionType] = {
			Total = 0,
			Perfect = 0,
		}
	end

	local gStats = state.GranularStats[actionType]
	gStats.Total = gStats.Total + 1
	if isPerfect then
		gStats.Perfect = gStats.Perfect + 1
	end

	state.TotalActions = state.TotalActions + 1
	if isPerfect then
		state.PerfectHits = state.PerfectHits + 1
	end

	if state.TotalActions > 0 then
		state.CurrentAccuracy = (state.PerfectHits / state.TotalActions) * 100.0
	end

	-- -- Poll Score/Combo to keep state updated even if we die later
	-- pcall(function()
	-- 	local PC = UEHelpers.GetPlayerController()
	-- 	if PC and PC:IsValid() then
	-- 		local ScoreComp = PC:GetScoreComponent()
	-- 		if ScoreComp and ScoreComp:IsValid() then
	-- 			state.TotalScore = ScoreComp:GetCombatScore() or state.TotalScore
	-- 			state.MaxCombo = ScoreComp:GetMaxComboCount() or state.MaxCombo
	-- 		end
	-- 	end
	-- end)

	state.LastActionWasPerfect = isPerfect
	state.LastMusicTime = musicTime
	state.LastActionType = actionType or "Unknown"
end

local GAME_STATE_PATHS = {
	HighScoresPath = "/Game/Pagoda/UI/Game/HighScores/WBP_HighScoresList.WBP_HighScoresList_C",
	CombatScorePath = "/Game/Pagoda/UI/Game/CombatScore/WBP_CombatScore.WBP_CombatScore_C",
	CountdownPath = "/Game/Pagoda/Core/GameModes/BP_PagodaGameState.BP_PagodaGameState_C",
}

local function RegisterCombatHooks()
	log.debug("Injecting Combat Hooks...")
	for abilityKey, data in pairs(abilities_catalog.ABILITIES) do
		local hook_path = data.path
		if hook_path and hook_path ~= "" then
			pcall(function()
				RegisterHook(hook_path, function(wrappedSelf, Param1, ...)
					local self = wrappedSelf:get()
					if not self then
						return
					end
					local isPerfect = false
					if data.hasParam then
						if Param1 then
							isPerfect = Param1:get() or false
						end
					else
						pcall(function()
							if self.WasActivatedWithPerfectInputTiming then
								isPerfect = self:WasActivatedWithPerfectInputTiming()
							end
						end)
					end
					UpdateGlobalAccuracy(isPerfect, self.MusicTimeActivated or 0.0, abilityKey)
				end)
			end)
		end
	end
	return true
end

local function GameModeEndSongHook()
	local state = _G.__SessionAggAccuracy

	pcall(function()
		local PC = UEHelpers.GetPlayerController()
		if PC and PC:IsValid() then
			local ScoreComp = PC:GetScoreComponent()
			if ScoreComp and ScoreComp:IsValid() then
				-- Use current state as fallback to avoid overwriting with 0 on death
				state.MaxCombo = ScoreComp:GetMaxComboCount() or state.MaxCombo
				state.TotalScore = ScoreComp:GetCombatScore() or state.TotalScore
			end
		end
	end)

	if state.TotalActions > 0 then
		state.LastRank, _ = require("imgui.results_hud").GetRank(state.CurrentAccuracy, state.TotalActions)
		-- Just update the history, UI will handle the "New PB" detection independently
		history_handler.UpdateBestRun(state)
		log.info(string.format("Match Ended: Score=%d", state.TotalScore))
	end
end

local function GameModeEntryPointHook()
	local state = _G.__SessionAggAccuracy
	local rh = state.__reg_hooks

	if not rh.Combat then
		rh.Combat = RegisterCombatHooks()
	end

	if not rh.Combo then
		local okCombo, _ = pcall(function()
			RegisterHook(GAME_STATE_PATHS.CombatScorePath .. ":HandleComboCountChanged", function(self, ComboCount)
				local innerState = _G.__SessionAggAccuracy
        local combo = ComboCount:get()
        innerState.internalMaxCombo = combo >= innerState.internalMaxCombo and combo or innerState.internalMaxCombo

        if ComboCount:get() == 0 and innerState.internalMaxCombo > 0 then
					innerState.IsFullCombo = false
          log.debug("isFullCombo: false (Combo broke at " .. 
                      tostring(innerState.LastMusicTime) .. 
                      "s -> MaxCombo: " .. tostring(innerState.internalMaxCombo) .. ")"
                    )
				end
			end)
		end)
		rh.Combo = okCombo
	end

	if not rh.Lifecycle then
		local okLifecycle, _ = pcall(function()

      RegisterHook("/Game/Pagoda/Characters/Player/BP_PagodaPlayerController.BP_PagodaPlayerController_C:ReceiveEndPlay", function( self, EndPlayReason  )
        hud_handler.SetState(hud_handler.States.PRE_GAME, state)
        log.debug("EndPlayReason: " .. tostring(EndPlayReason:get()))
      end)

			RegisterHook("/Game/Pagoda/Levels/Test/BP_InfiniteDisco.BP_InfiniteDisco_C:InitPlayerAttributes", function()
				local innerState = _G.__SessionAggAccuracy
				-- ALWAYS reset on start gestures to handle retries properly
				ResetSessionTracker()
				CaptureSongMetadata()
				innerState.CachedPB = history_handler.GetPB(innerState)
				hud_handler.SetState(hud_handler.States.IN_GAME, innerState)
				log.debug("Gameplay Started/Reset! (Step 4) -> BP_InfiniteDisco_C:InitPlayerAttributes")
      end)

      
		end)

		rh.Lifecycle = okLifecycle
	end

	if not rh.Scores then
		local okScores, _ = pcall(function()
			RegisterHook(GAME_STATE_PATHS.HighScoresPath .. ":Construct", function(self, ...)
				local innerState = _G.__SessionAggAccuracy
				GameModeEndSongHook()
				hud_handler.SetState(hud_handler.States.RESULTS, innerState)
				log.debug("Gameplay End detected (Results)")
			end)

      RegisterHook("/Game/Pagoda/UI/Game/WBP_LevelEndScreen.WBP_LevelEndScreen_C:Destruct", function()
				hud_handler.HideResultsUI()
				log.debug("WBP_LevelEndScreen_C:Destruct")
      end)
		end)
		rh.Scores = okScores
	end

	return rh.Combat and rh.Combo and rh.Lifecycle and rh.Scores
end

-- ============ INITIALIZATION ============

LoopAsync(cfg.HEARTBEAT_MS, function() 
  local state = _G.__SessionAggAccuracy
  if state.__hb_hooks then return true end

  local status, _ = pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, ...)
      log.trace("PlayerController:ClientRestart")
      ExecuteInGameThread(function()
        hud_handler.EnsureUI()
      end)    
    end)
  end)
  if status then 
    state.__hb_hooks = true
  end
  return status

end)

LoopAsync(cfg.HEARTBEAT_MS, function()
	local state = _G.__SessionAggAccuracy
	if state.__setup_hooks then
		return true
	end
	if GameModeEntryPointHook() then
		state.__setup_hooks = true
		log.debug("All hooks initialized succesfully!!!")

    pcall(function()
      ExecuteInGameThread(function()
        hud_handler.EnsureUI()
      end)  
    end)
		return true
	end
	return false
end)


-- ============ UI SYNC LOOP ============
LoopAsync(cfg.HUD_UPDATE_INTERVAL_MS, function()
	ExecuteInGameThread(function()
		hud_handler.Sync(_G.__SessionAggAccuracy)
	end)
	return false
end)

-- ============ KEYBINDS ============
RegisterKeyBind(Key.F3, function()
	_G.__SessionAggAccuracy.IsTrackerVisible = not _G.__SessionAggAccuracy.IsTrackerVisible
  hud_handler.UpdateModStatus(_G.__SessionAggAccuracy)
end)
RegisterKeyBind(Key.F4, function()
	_G.__SessionAggAccuracy.IsTrackerVisible = true
  hud_handler.UpdateModStatus(_G.__SessionAggAccuracy)
end)
RegisterKeyBind(Key.F5, function()
	_G.__SessionAggAccuracy.IsTrackerVisible = false
  hud_handler.UpdateModStatus(_G.__SessionAggAccuracy)
end)

-- ============ DEBUG / SANDBOX KEYBINDS ============
RegisterKeyBind(Key.F6, function()
    log.info("[DEBUG] Triggering Mock Results Screen...")
    local mockState = {
        SongName = "DEBUG SONG (SANDBOX)",
        TotalActions = 100,
        PerfectHits = 95,
        CurrentAccuracy = 95.0,
        MaxCombo = 42,
        TotalScore = 999999, -- High enough to trigger PB badge
        IsFullCombo = false,
        IsNewPB = true,
        GranularStats = {
            Attack = { Total = 50, Perfect = 48 },
            Dodge = { Total = 30, Perfect = 28 },
            Special = { Total = 20, Perfect = 19 },
        },
        CachedPB = { highScore = 1000 } -- Lower than mock score
    }
    hud_handler.SetState(hud_handler.States.RESULTS, mockState)
end)
