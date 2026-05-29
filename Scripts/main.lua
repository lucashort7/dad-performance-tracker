print("[PerformanceTracker] ~>> BOOT: main.lua initiated")

local UEHelpers = require("UEHelpers")
local in_game_progress_hud = require("imgui.in_game_progress_hud")
local results_hud = require("imgui.results_hud")
local status_indicator_hud = require("imgui.status_indicator_hud")
local log = require("utils.log")
local cfg = require("config")
local abilities_catalog = require("domains.abilities_catalog")
local history_handler = require("handlers.history_handler")
local hud_utils = require("utils.hud_utils")

print("[PerformanceTracker] ~>> BOOT: All modules loaded successfully")

local pcall, ipairs, type, pairs = pcall, ipairs, type, pairs
local string_format = string.format


--[[ ============ STATEs ============  --]]
_G.__SessionAggAccuracy = _G.__SessionAggAccuracy or {
    TotalActions = 0,
    PerfectHits = 0,
    CurrentAccuracy = 100.0,
    MaxCombo = 0,
    TotalScore = 0,
    IsFullCombo = true,
    LastRank = "F", -- Persisted rank for the session
    SongName = "Unknown",
    SongSeed = 0,
    SongID = 0,
    SongHash = "",
    LastMusicTime = 0.0,
    LastActionWasPerfect = false,
    LastActionType = "None",
    GranularStats = {}, -- Stores actionType -> { Total, Perfect }
    IsTrackerVisible = true, -- Persistent visibility preference

    -- Hook Control Flags (Global for hot-reload safety)
    HooksInjected = false,
    IsInitialized = false,
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
    state.TotalScore = 0
    state.IsFullCombo = true
    state.SongName = "Unknown"
    state.SongSeed = 0
    state.SongID = 0
    state.SongHash = ""
    state.LastMusicTime = 0.0
    state.LastActionWasPerfect = false
    state.LastActionType = "Reset"
    state.GranularStats = {}
    
    in_game_progress_hud.Update({}, state)
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

    logf(log.debug, "Action: %s | Perfect: %s | Overall Acc: %.2f%%",
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
    logf(log.info, "Initializing Combat Hooks registration...")

    for abilityKey, data in pairs(abilities_catalog.ABILITIES) do
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

local function GameModeEndSongHook()
    local state = _G.__SessionAggAccuracy

    -- 1. Fetch native metrics (Combo, Score, Song Metadata)
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if PC and PC:IsValid() then
            -- Combat Metrics
            local ScoreComp = PC:GetScoreComponent()
            if ScoreComp and ScoreComp:IsValid() then
                state.MaxCombo = ScoreComp:GetMaxComboCount() or 0
                state.TotalScore = ScoreComp:GetCombatScore() or 0
            end

            -- Song Metadata via MusicSubsystem
            local musicInsts = FindAllOf("PagodaMusicSubsystem")
            if musicInsts and #musicInsts > 0 then
                local musicInst = musicInsts[1]
                local currentSong = musicInst:GetCurrentSong()
                if currentSong and currentSong:IsValid() then
                    state.SongName = currentSong.SongName:ToString()
                    state.SongSeed = currentSong.Seed or 0
                    state.SongID = currentSong.ImportedSongUniqueId or 0
                    state.SongHash = currentSong.OriginalAudioFileHash:ToString()
                end
            end
        end
    end)

    if state.TotalActions == 0 then return end

    -- 2. Logic: Calculate Final Rank before persistence
    state.LastRank, _ = results_hud.GetRank(state.CurrentAccuracy, state.TotalActions)

    -- 3. Persistence: Update Song History
    local isNewPB, pbData = history_handler.UpdateBestRun(state)

    -- 4. Logging
    logf(log.info, "================================================")
    logf(log.info, "           SONG SESSION FINAL STATS             ")
    logf(log.info, "================================================")
    logf(log.info, string_format("SONG: %s (ID: %d | Seed: %d)", state.SongName, state.SongID, state.SongSeed))
    logf(log.info, string_format("SCORE: %d %s", state.TotalScore, isNewPB and "[NEW PERSONAL BEST!]" or ""))
    logf(log.info, string_format("RANK: %s | ACCURACY: %.2f%% (%d/%d Hits)", 
        state.LastRank, state.CurrentAccuracy, state.PerfectHits, state.TotalActions))
    logf(log.info, string_format("MAX COMBO: %d (FC: %s)", state.MaxCombo, tostring(state.IsFullCombo)))
    logf(log.info, "================================================")
end

local function GameModeEntryPointHook()
    local state = _G.__SessionAggAccuracy
    if not state.HooksInjected then
        RegisterCombatHooks()

        -- Hook Combo changes for Full Combo tracking
        pcall(function()
            RegisterHook(GAME_STATE_PATHS.CombatScorePath .. ":HandleComboCountChanged", function(self, ComboCount)
                local innerState = _G.__SessionAggAccuracy
                local count = ComboCount:get()
                
                -- If combo resets to 0 and we already had some actions, it's not an FC
                if count == 0 and innerState.TotalActions > 0 then
                    innerState.IsFullCombo = false
                end
            end)
        end)

        state.HooksInjected = true
    end

    pcall(function()
        RegisterHook(GAME_STATE_PATHS.GameModePath .. ":ResetPlayerAttributesForRespawn", function(self, ...)
            local state = _G.__SessionAggAccuracy
            ResetSessionTracker()
            
            -- Respect user's visibility preference on respawn
            if state.IsTrackerVisible then
                in_game_progress_hud.SetVisibility(hud_utils.Visibility.HITTESTINVISIBLE)
            else
                in_game_progress_hud.SetVisibility(hud_utils.Visibility.HIDDEN)
            end
        end)
    end)

    pcall(function()
        RegisterHook(GAME_STATE_PATHS.HighScoresPath .. ":Construct", function(self, ...)
            GameModeEndSongHook()
            in_game_progress_hud.SetVisibility(hud_utils.Visibility.HIDDEN)
            results_hud.Show(_G.__SessionAggAccuracy.GranularStats, _G.__SessionAggAccuracy)
        end)
    end)

    return true
end

-- ============ INITIALIZATION ============
LoopAsync(2000, function()
    local state = _G.__SessionAggAccuracy
    if state.IsInitialized then return true end
    if GameModeEntryPointHook() then
        state.IsInitialized = true
        logf(log.info, "PerformanceTracker successfully initialized.")
        return true
    end
    return false
end)


-- ============ IMGUI HUD ============
LoopAsync(2000, function()
    local ok, s = pcall(function()
        RegisterHook("/Script/Engine.PlayerController:ClientRestart", function( ... )
            ExecuteInGameThread(function()
                if not status_indicator_hud.IsValid() then status_indicator_hud.Create() end
                if not in_game_progress_hud.IsValid() then in_game_progress_hud.Create() end
            end)
        end)
    end)
    return ok
end)


RegisterKeyBind(Key.F3, function() 
    local isOn = in_game_progress_hud.Toggle()
    status_indicator_hud.SetStatus(isOn)
    _G.__SessionAggAccuracy.IsTrackerVisible = isOn
end) 

RegisterKeyBind(Key.F4, function() 
    in_game_progress_hud.SetVisibility(hud_utils.Visibility.HITTESTINVISIBLE)
    status_indicator_hud.SetStatus(true)
    _G.__SessionAggAccuracy.IsTrackerVisible = true
end) 

RegisterKeyBind(Key.F5, function() 
    in_game_progress_hud.SetVisibility(hud_utils.Visibility.HIDDEN)
    status_indicator_hud.SetStatus(false)
    _G.__SessionAggAccuracy.IsTrackerVisible = false
end)

-- UI Update Loop
LoopAsync(cfg.HUD_UPDATE_INTERVAL_MS, function()
    pcall(function()
        if in_game_progress_hud.IsValid() then
            in_game_progress_hud.Update(_G.__SessionAggAccuracy.GranularStats, _G.__SessionAggAccuracy)
        end
    end)
    return false
end)
