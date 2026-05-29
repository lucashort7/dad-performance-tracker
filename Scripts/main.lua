local UEHelpers = require("UEHelpers")
local progress_hud = require("imgui.in_game_progress_hud")
local results_hud = require("imgui.results_hud")
local status_hud = require("imgui.status_indicator_hud")
local _logger = require("log")
local cfg = require("config")
local abilities_helper = require("helpers.abilities_helper")
local helpers = require("helpers.hud_helpers")

local pcall, ipairs, type, pairs = pcall, ipairs, type, pairs
local string_format = string.format


--[[ ============ STATEs ============  --]]
_G.__SessionAggAccuracy = _G.__SessionAggAccuracy or {
    TotalActions = 0,
    PerfectHits = 0,
    CurrentAccuracy = 100.0,
    MaxCombo = 0,
    IsFullCombo = true,
    SongName = "Unknown",
    LastMusicTime = 0.0,
    LastActionWasPerfect = false,
    LastActionType = "None",
    GranularStats = {}, -- Stores actionType -> { Total, Perfect }
    IsTrackerVisible = true, -- Persistent visibility preference
}

--[[ ============ UTILS ============  --]]
local function logf(fLogLevel, fmt, ...)
    local ok, s = pcall(string_format, fmt, ...)
    if not ok then
        s = fmt
    end
    pcall(fLogLevel, "[" .. cfg.MOD_NAME .. "] ~>> " .. s)
end

-- Clear tracker metrics table
local function ResetSessionTracker()
    local state = _G.__SessionAggAccuracy
    state.TotalActions = 0
    state.PerfectHits = 0
    state.CurrentAccuracy = 100.0
    state.MaxCombo = 0
    state.IsFullCombo = true
    state.SongName = "Unknown"
    state.LastMusicTime = 0.0
    state.LastActionWasPerfect = false
    state.LastActionType = "Reset"
    state.GranularStats = {}
    
    progress_hud.Update({}, state)
    results_hud.Hide()
end


---@param isPerfect boolean
---@param musicTime number
---@param actionType string
--- Centralized data pipeline to process metrics
local function UpdateGlobalAccuracy(isPerfect, musicTime, actionType)
    local state = _G.__SessionAggAccuracy
    musicTime = musicTime or 0.0

    -- [PERFORMANCE] Time-gate/De-duplication check: 
    if state.LastActionType == actionType and state.LastMusicTime == musicTime then
        return
    end

    -- Initialize granular bucket
    if not state.GranularStats[actionType] then
        state.GranularStats[actionType] = { Total = 0, Perfect = 0 }
    end

    local gStats = state.GranularStats[actionType]
    gStats.Total = gStats.Total + 1
    if isPerfect then gStats.Perfect = gStats.Perfect + 1 end

    state.TotalActions = state.TotalActions + 1
    if isPerfect then
        state.PerfectHits = state.PerfectHits + 1
    end

    if state.TotalActions > 0 then
        state.CurrentAccuracy = (state.PerfectHits / state.TotalActions) * 100.0
    end

    state.LastActionWasPerfect = isPerfect
    state.LastMusicTime = musicTime
    state.LastActionType = actionType or "Unknown"

    logf(_logger.debug, "Action: %s | Perfect: %s | Overall Acc: %.2f%%",
        state.LastActionType, tostring(isPerfect), state.CurrentAccuracy)
end


--[[ ============ GAME STATE PATHS ============  --]]
local GAME_STATE_PATHS = {
    GameModePath = "/Game/Pagoda/Core/GameModes/BP_PagodaGameMode.BP_PagodaGameMode_C",
    HighScoresPath = "/Game/Pagoda/UI/Game/HighScores/WBP_HighScoresList.WBP_HighScoresList_C",
    CombatScorePath = "/Game/Pagoda/UI/Game/CombatScore/WBP_CombatScore.WBP_CombatScore_C",
}

--[[ ============ ABILITIES HOOKS ============  --]]
local function RegisterCombatHooks()
    logf(_logger.info, "Initializing Combat Hooks registration...")
    
    for abilityKey, data in pairs(abilities_helper.ABILITIES) do
        local hook_path = data.path
        if hook_path and hook_path ~= "" then
            pcall(function()
                RegisterHook(hook_path, function(wrappedSelf, Param1, ...)
                    local self = wrappedSelf:get()
                    if not self then return end

                    local isPerfect = false
                    if data.hasParam then
                        if Param1 then isPerfect = Param1:get() or false end
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
end

-- ============ ENGINE CORE ENTRY HOOK ============
local isAbilitiesHooksInjected = false

local function GameModeEndSongHook()
    local state = _G.__SessionAggAccuracy

    -- Fetch native MaxCombo and SongName
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if PC and PC:IsValid() then
            -- Max Combo
            local ScoreComp = PC:GetScoreComponent()
            if ScoreComp and ScoreComp:IsValid() then
                state.MaxCombo = ScoreComp:GetMaxComboCount() or 0
            end

            -- Song Name via MusicSubsystem
            local musicInsts = FindAllOf("PagodaMusicSubsystem")
            if musicInsts and #musicInsts > 0 then
                local musicInst = musicInsts[1]
                local currentSong = musicInst:GetCurrentSong()
                if currentSong and currentSong:IsValid() then
                    state.SongName = currentSong.SongName:ToString()
                end
            end
        end
    end)

    if state.TotalActions == 0 then return end

    logf(_logger.info, "================================================")
    logf(_logger.info, "           SONG SESSION FINAL STATS             ")
    logf(_logger.info, "================================================")
    logf(_logger.info, string_format("SONG: %s", state.SongName))
    logf(_logger.info, string_format("OVERALL ACCURACY: %.2f%% (%d/%d Hits)", 
        state.CurrentAccuracy, state.PerfectHits, state.TotalActions))
    logf(_logger.info, string_format("MAX COMBO: %d (FC: %s)", state.MaxCombo, tostring(state.IsFullCombo)))
    logf(_logger.info, "================================================")
end

local function GameModeEntryPointHook()
    if not isAbilitiesHooksInjected then
        RegisterCombatHooks()

        -- Hook Combo changes for Full Combo tracking
        pcall(function()
            RegisterHook(GAME_STATE_PATHS.CombatScorePath .. ":HandleComboCountChanged", function(self, ComboCount)
                local state = _G.__SessionAggAccuracy
                local count = ComboCount:get()
                
                -- If combo resets to 0 and we already had some actions, it's not an FC
                if count == 0 and state.TotalActions > 0 then
                    state.IsFullCombo = false
                end
            end)
        end)

        isAbilitiesHooksInjected = true
    end

    pcall(function()
        RegisterHook(GAME_STATE_PATHS.GameModePath .. ":ResetPlayerAttributesForRespawn", function(self, ...)
            local state = _G.__SessionAggAccuracy
            ResetSessionTracker()
            
            -- Respect user's visibility preference on respawn
            if state.IsTrackerVisible then
                progress_hud.SetVisibility(helpers.Visibility.HITTESTINVISIBLE)
            else
                progress_hud.SetVisibility(helpers.Visibility.HIDDEN)
            end
        end)
    end)

    pcall(function()
        RegisterHook(GAME_STATE_PATHS.HighScoresPath .. ":Construct", function(self, ...)
            GameModeEndSongHook()
            progress_hud.SetVisibility(helpers.Visibility.HIDDEN)
            results_hud.Show(_G.__SessionAggAccuracy.GranularStats, _G.__SessionAggAccuracy)
        end)
    end)

    return true
end

-- ============ INITIALIZATION ============
local isGameModeHooked = false

LoopAsync(2000, function()
    if isGameModeHooked then return true end
    if GameModeEntryPointHook() then
        isGameModeHooked = true
        logf(_logger.info, "PerformanceTracker successfully initialized.")
        return true
    end
    return false
end)


-- ============ IMGUI HUD ============
LoopAsync(2000, function()
    local ok, s = pcall(function()
        RegisterHook("/Script/Engine.PlayerController:ClientRestart", function( ... )
            ExecuteInGameThread(function()
                if not status_hud.IsValid() then status_hud.Create() end
                if not progress_hud.IsValid() then progress_hud.Create() end
            end)
        end)
    end)
    return ok
end)


RegisterKeyBind(Key.F3, function() 
    local isOn = progress_hud.Toggle()
    status_hud.SetStatus(isOn)
    _G.__SessionAggAccuracy.IsTrackerVisible = isOn
end) 

RegisterKeyBind(Key.F4, function() 
    progress_hud.SetVisibility(helpers.Visibility.HITTESTINVISIBLE)
    status_hud.SetStatus(true)
    _G.__SessionAggAccuracy.IsTrackerVisible = true
end) 

RegisterKeyBind(Key.F5, function() 
    progress_hud.SetVisibility(helpers.Visibility.HIDDEN)
    status_hud.SetStatus(false)
    _G.__SessionAggAccuracy.IsTrackerVisible = false
end)

-- UI Update Loop
LoopAsync(cfg.HUD_UPDATE_INTERVAL_MS, function()
    pcall(function()
        if progress_hud.IsValid() then
            progress_hud.Update(_G.__SessionAggAccuracy.GranularStats, _G.__SessionAggAccuracy)
        end
    end)
    return false
end)
