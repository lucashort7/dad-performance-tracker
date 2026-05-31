local M = {}

local json = require("utils.json")
local log = require("utils.log")

-- Constant file path in mod directory
local SAVE_PATH = "./ue4ss/Mods/PerformanceTracker/Data/performance_history.json"

local function _dmp_tbl(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. _dmp_tbl(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

---@return table
function M.LoadHistory()
  log.trace("[history_handler.LoadHistory()] [START]")
	local f = io.open(SAVE_PATH, "r")
	if not f then
    log.trace("[history_handler.open()] [EMPTY FILE?]")
		return {}
	end

	local content = f:read("*all")
  log.trace("[history_handler.content] " .. _dmp_tbl(content))
	f:close()

	if not content or content == "" then
    log.trace("[history_handler.LoadHistory()] [EMPTY FILE?]")
		return {}
	end

	local ok, data = pcall(json.decode, content)
	if not ok then
		log.debug("Error decoding JSON history. Starting fresh.")
		return {}
	end

  log.trace("[history_handler.LoadHistory()] [END]")
	return data or {}
end

---@param data table
function M.SaveHistory(data)
  log.trace("[history_handler.SaveHistory()] [START]")
	local ok, content = pcall(json.encode, data)
	if not ok then
		log.error("Error encoding JSON history.")
		return
	end

	local f = io.open(SAVE_PATH, "w")
	if f then
    log.debug("Writing Data: " .. _dmp_tbl(data))
    -- TODO: review this -> writing in a long run can be costly and 
    --        we might want to consider a more efficient storage solution 
    --        if the data grows significantly
		f:write(content)
		f:close()
	else
		log.error("Could not open history file for writing.")
	end
  log.trace("[history_handler.SaveHistory()] [END]")
end

--- Fetch the Personal Best without updating it
---@param session table The global state snapshot
---@return table|nil The PB data or nil if not found
function M.GetPB(session)
	local pk = nil
	if session.SongUniqueID and session.SongUniqueID ~= 0 and session.SongUniqueID ~= "" then
		pk = tostring(session.SongUniqueID)
	elseif session.AssetPath and session.AssetPath ~= "" then
		pk = session.AssetPath
	elseif session.SongName and session.SongName ~= "" then
		pk = session.SongName
	end

	if not pk or pk == "" then
		return nil
	end

	local history = M.LoadHistory()
	return history[pk]
end

--- Core logic to update Personal Best
---@param session table The global state snapshot (__SessionAggAccuracy)
function M.UpdateBestRun(session)
  log.debug("Updating best run for song: " .. (session.SongName or "Unknown"))
	-- PK is SongHash, fallback to SongID, then AssetPath, then Name
  -- TODO: SongHash doesn't exist...
	-- local pk = session.SongHash
  local pk = nil
  if not pk or pk == "" then
    log.trace("session.SongUniqueID")
    if session.SongUniqueID and session.SongUniqueID ~= 0 then
		  pk = tostring(session.SongUniqueID)
    end
	end
  if not pk or pk == "0" then
    -- TODO: maybe we get only the last part of 
    --        the AssetPath as PK? string too long
    log.trace("session.AssetPath")
		pk = session.AssetPath
	end
	
	if not pk or pk == "" then
    log.trace("session.SongName")
		pk = session.SongName
	end
  log.debug("Determined PK for history: " .. tostring(pk))
  if not pk or pk == "" then
    log.error("Could not determine a valid PK for history. Aborting update.")
    return
  end

	local history = M.LoadHistory()
  local hist_count = 0
  for _ in pairs(history) do
      hist_count = hist_count + 1
  end
  log.debug("Current history entries: " .. tostring(hist_count))
	local pb = history[pk]
		or {
			songName = session.SongName,
			songID = session.SongID,
			highScore = 0,
			bestAcc = 0,
			bestRank = "F",
			bestCombo = 0,
			playCount = 0,
			isFC = false,
		}
  log.debug("Local Personal Best: " .. _dmp_tbl(pb))

	-- Increment play count
	pb.playCount = pb.playCount + 1

	-- Success Metric: Compare by TotalScore (CombatScore)
	local isNewPB = false
	local currentScore = session.TotalScore or 0
	if currentScore > pb.highScore or (pb.highScore == 0 and currentScore > 0) then
		isNewPB = true
		pb.highScore = currentScore
		pb.bestAcc = session.CurrentAccuracy
		pb.bestRank = session.LastRank or "F" -- We might need to store the rank in state
		pb.bestCombo = session.MaxCombo
		pb.isFC = session.IsFullCombo
	end

	history[pk] = pb
	M.SaveHistory(history)

	return isNewPB, pb
end

return M
