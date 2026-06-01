local M = {}

local json = require("utils.json")
local log = require("utils.log")

-- History file path
local SAVE_PATH = "./ue4ss/Mods/PerformanceTracker/Data/performance_history.json"
local TMP_PATH = SAVE_PATH .. ".tmp"

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

--- INTERNAL FUNCTION: Centralizes and sanitizes Primary Key (PK) generation
local function _getCleanPrimaryKey(session)
	if session.SongUniqueID and session.SongUniqueID ~= 0 
      and session.SongUniqueID ~= "" and session.SongUniqueID ~= "0" then
		return tostring(session.SongUniqueID)
	end

	if session.AssetPath and session.AssetPath ~= "" then
		-- Applies the pattern to capture only what comes after the last dot
		-- Example: "/Game/Pagoda/Maps/Song_Disco.Song_Disco" becomes "Song_Disco"
		local clean = session.AssetPath:match("([^.]+)$")
		if clean and clean ~= "" then
			return clean
		end
		return session.AssetPath
	end

	if session.SongName and session.SongName ~= "" then
		return session.SongName
	end

	return nil
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

	-- 1. ATOMIC WRITE: Write first to a temporary file (.tmp)
	local f = io.open(TMP_PATH, "w")
	if f then
		log.debug("Writing Data to TMP: " .. _dmp_tbl(data))
		f:write(content)
		f:close()

		-- 2. SAFE SWAP (Windows Compatible):
		-- Windows blocks os.rename if the destination file already exists.
		-- To bypass this, we remove the old file and instantly rename the temporary one.
		os.remove(SAVE_PATH)
		local success, err = os.rename(TMP_PATH, SAVE_PATH)

		if success then
			log.debug("History saved atomically successfully.")
		else
			log.error("Atomic swap failed: " .. tostring(err) .. ". Executing fallback write.")
			-- Emergency fallback in case the OS locks the rename process
			local f_fallback = io.open(SAVE_PATH, "w")
			if f_fallback then
				f_fallback:write(content)
				f_fallback:close()
			end
		end
	else
		log.error("Could not open temporary history file for writing.")
	end
  log.trace("[history_handler.SaveHistory()] [END]")
end

--- Fetch the Personal Best without updating it
---@param session table The global state snapshot
---@return table|nil The PB data or nil if not found
function M.GetPB(session)
	local pk = _getCleanPrimaryKey(session)

	if not pk or pk == "" then
		return nil
	end

	local history = M.LoadHistory()
	return history[pk]
end

--- Core logic to update Personal Best
---@param session table The global state snapshot (__SessionAggAccuracy)
---@return boolean, table Returns whether it's a new record (isNewPB) and the updated PB data
function M.UpdateBestRun(session)
  log.debug("Updating best run for song: " .. (session.SongName or "Unknown"))

	-- Execute primary key sanitization
	local pk = _getCleanPrimaryKey(session)
	log.debug("Determined PK for history: " .. tostring(pk))
  
	if not pk or pk == "" then
		log.error("Could not determine a valid PK for history. Aborting update.")
		return false, nil
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
			songID = session.SongUniqueID or session.SongID or "Unknown",
			highScore = 0,
			bestAcc = 0,
			bestRank = "F",
			bestCombo = 0,
			playCount = 0,
			isFC = false,
		}
	log.debug("Local Personal Best: " .. _dmp_tbl(pb))

	-- Increment the play counter
	pb.playCount = pb.playCount + 1

	-- Business Rule: Update statistics if the current Score breaks the previous high score
	local isNewPB = false
	local currentScore = session.TotalScore or 0
	if currentScore > pb.highScore or (pb.highScore == 0 and currentScore > 0) then
		isNewPB = true
		pb.highScore = currentScore
		pb.bestAcc = session.CurrentAccuracy
		pb.bestRank = session.LastRank or "F"
		pb.bestCombo = session.MaxCombo
		pb.isFC = session.IsFullCombo
	end

	history[pk] = pb
	M.SaveHistory(history)

	return isNewPB, pb
end

return M