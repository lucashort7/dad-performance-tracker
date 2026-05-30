local cfg = {}

-- ~mod
cfg.MOD_NAME = "PerformanceTracker"

-- ~log
cfg.LOG_LEVEL = "trace"

-- ~timing
cfg.HUD_UPDATE_INTERVAL_MS = 400
cfg.TICK_INTERVAL_MS = 5000
cfg.HEARTBEAT_MS = 5000

--[[
    ============ ~hud cfg ============ 
--]]
cfg.HUD_MAIN_ALLIGNMENT = "midbottomright_test" -- 'upper_left'
cfg.HUD_LABEL_LAYOUT = "friendly" -- Can be "full", "friendly", or "shortname"

return cfg
