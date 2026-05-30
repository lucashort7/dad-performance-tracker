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
    TotalScore = 0,
    IsFullCombo = true,
    LastRank = "F", 
    SongName = "Unknown",
    AssetPath = "",
    LastMusicTime = 0.0,
    LastActionType = "None",
    GranularStats = {}, 
    IsTrackerVisible = true, 

    -- Hook Control Flags
    IsInitialized = false,
    RegisteredHooks = {
        Combat = false,
        Combo = false,
        Lifecycle = false,
        Scores = false
    }
}

--[[ ============ UTILS ============  --]]

local function ResetSessionTracker()
    local state = _G.__SessionAggAccuracy
    state.TotalActions = 0
    state.PerfectHits = 0
    state.CurrentAccuracy = 100.0
    state.MaxCombo = 0
    state.TotalScore = 0
    state.IsFullCombo = true
    state.SongName = "Unknown"
    state.AssetPath = ""
    state.LastMusicTime = 0.0
    state.LastActionType = "Reset"
    state.GranularStats = {}
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
                log.debug("Metadata captured:", state.SongName)
            end
        end
    end)
end

--[[ ============ CORE PIPELINE ============  --]]

local function UpdateGlobalAccuracy(isPerfect, musicTime, actionType)
    local state = _G.__SessionAggAccuracy
    musicTime = musicTime or 0.0
    if state.LastActionType == actionType and state.LastMusicTime == musicTime then return end

    -- FALLBACK: If we are hitting things but not in IN_GAME state, force it now.
    if hud_handler.CurrentState ~= hud_handler.States.IN_GAME then
        ResetSessionTracker()
        CaptureSongMetadata()
        hud_handler.SetState(hud_handler.States.IN_GAME, state)
        log.debug("Gameplay Started via Combat Fallback (Step 4)")
    end

    if not state.GranularStats[actionType] then
        state.GranularStats[actionType] = { Total = 0, Perfect = 0 }
    end

    local gStats = state.GranularStats[actionType]
    gStats.Total = gStats.Total + 1
    if isPerfect then gStats.Perfect = gStats.Perfect + 1 end

    state.TotalActions = state.TotalActions + 1
    if isPerfect then state.PerfectHits = state.PerfectHits + 1 end

    if state.TotalActions > 0 then
        state.CurrentAccuracy = (state.PerfectHits / state.TotalActions) * 100.0
    end

    state.LastActionWasPerfect = isPerfect
    state.LastMusicTime = musicTime
    state.LastActionType = actionType or "Unknown"
    
    log.debug(string_format("METRIC UPDATE: %s | Total: %d | Perfect: %d | Acc: %.2f%%", 
        actionType, state.TotalActions, state.PerfectHits, state.CurrentAccuracy))
end

local GAME_STATE_PATHS = {
    HighScoresPath = "/Game/Pagoda/UI/Game/HighScores/WBP_HighScoresList.WBP_HighScoresList_C",
    CombatScorePath = "/Game/Pagoda/UI/Game/CombatScore/WBP_CombatScore.WBP_CombatScore_C",
    CountdownPath = "/Game/Pagoda/Core/GameModes/BP_PagodaGameState.BP_PagodaGameState_C"
}

local function RegisterCombatHooks()
    log.debug("Injecting Combat Hooks...")
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
                        pcall(function() if self.WasActivatedWithPerfectInputTiming then isPerfect = self:WasActivatedWithPerfectInputTiming() end end)
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
                state.MaxCombo = ScoreComp:GetMaxComboCount() or 0
                state.TotalScore = ScoreComp:GetCombatScore() or 0
            end
        end
    end)
    if state.TotalActions > 0 then
        state.LastRank, _ = require("imgui.results_hud").GetRank(state.CurrentAccuracy, state.TotalActions)
        history_handler.UpdateBestRun(state)
    end
end

local function GameModeEntryPointHook()
    local state = _G.__SessionAggAccuracy
    local rh = state.RegisteredHooks
    
    if not rh.Combat then rh.Combat = RegisterCombatHooks() end

    if not rh.Combo then
        local okCombo, _ = pcall(function()
            RegisterHook(GAME_STATE_PATHS.CombatScorePath .. ":HandleComboCountChanged", function(self, ComboCount)
                local innerState = _G.__SessionAggAccuracy
                if ComboCount:get() == 0 and innerState.TotalActions > 0 then innerState.IsFullCombo = false end
            end)
        end)
        rh.Combo = okCombo
    end

    if not rh.Lifecycle then
        local okLifecycle, _ = pcall(function()
            -- THE SENTINEL: ClientRestart handles Map/Session changes
            RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
                local state = _G.__SessionAggAccuracy
                
                -- Check if we are in a match by looking for the Score widget
                local combatScoreWidget = StaticFindObject(GAME_STATE_PATHS.CombatScorePath)
                if combatScoreWidget and combatScoreWidget:IsValid() then
                    -- If ClientRestart fires and we have a score widget, it's a RESTART/RETRY
                    ResetSessionTracker()
                    CaptureSongMetadata()
                    hud_handler.SetState(hud_handler.States.IN_GAME, state)
                    log.debug("Gameplay Reset via ClientRestart (Sentinel)")
                else
                    -- No score widget? We are back in menu.
                    hud_handler.SetState(hud_handler.States.PRE_GAME, state)
                    log.debug("Mod Ready in Menu (Sentinel)")
                end
            end)

            -- THE "GO!": Step 4. Countdown Complete (or UI Appeared).
            local onStart = function()
                local innerState = _G.__SessionAggAccuracy
                -- ALWAYS reset on start gestures to handle retries properly
                ResetSessionTracker()
                CaptureSongMetadata()
                hud_handler.SetState(hud_handler.States.IN_GAME, innerState)
                log.debug("Gameplay Started/Reset! (Step 4)")
            end

            RegisterHook(GAME_STATE_PATHS.CountdownPath .. ":NotifyLevelStartCountdownComplete", onStart)
            RegisterHook(GAME_STATE_PATHS.CombatScorePath .. ":Construct", onStart)
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
        end)
        rh.Scores = okScores
    end

    return rh.Combat and rh.Combo and rh.Lifecycle and rh.Scores
end

-- ============ INITIALIZATION ============
LoopAsync(5000, function()
    local state = _G.__SessionAggAccuracy
    if state.IsInitialized then return true end
    if GameModeEntryPointHook() then
        state.IsInitialized = true
        log.debug("PerformanceTracker Solution Initialized.")
        
        -- HOT RELOAD CONTINGENCY
        pcall(function()
            local PC = UEHelpers.GetPlayerController()
            if PC and PC:IsValid() and PC:GetPawn() and PC:GetPawn():IsValid() then
                -- Check if we are mid-game
                if StaticFindObject(GAME_STATE_PATHS.CombatScorePath) then
                    CaptureSongMetadata()
                    hud_handler.SetState(hud_handler.States.IN_GAME, state)
                end
            end
        end)
        return true
    end
    return false
end)

-- ============ UI SYNC LOOP ============
LoopAsync(cfg.HUD_UPDATE_INTERVAL_MS, function()
    pcall(function() hud_handler.Sync(_G.__SessionAggAccuracy) end)
    return false
end)

-- ============ KEYBINDS ============
RegisterKeyBind(Key.F3, function() _G.__SessionAggAccuracy.IsTrackerVisible = not _G.__SessionAggAccuracy.IsTrackerVisible end) 
RegisterKeyBind(Key.F4, function() _G.__SessionAggAccuracy.IsTrackerVisible = true end) 
RegisterKeyBind(Key.F5, function() _G.__SessionAggAccuracy.IsTrackerVisible = false end)
