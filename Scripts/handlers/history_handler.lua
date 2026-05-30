local json = require("utils.json")
local M = {}

-- Constant file path in mod directory
local SAVE_PATH = "./ue4ss/Mods/PerformanceTracker/Data/performance_history.json"

---@return table
function M.LoadHistory()
	local f = io.open(SAVE_PATH, "r")
	if not f then
		return {}
	end

	local content = f:read("*all")
	f:close()

	if not content or content == "" then
		return {}
	end

	local ok, data = pcall(json.decode, content)
	if not ok then
		print("[PerformanceTracker] >> Error decoding JSON history. Starting fresh.")
		return {}
	end

	return data or {}
end

---@param data table
function M.SaveHistory(data)
	local ok, content = pcall(json.encode, data)
	if not ok then
		print("[PerformanceTracker] >> Error encoding JSON history.")
		return
	end

	local f = io.open(SAVE_PATH, "w")
	if f then
		f:write(content)
		f:close()
	else
		print("[PerformanceTracker] >> Could not open history file for writing.")
	end
end

--- Core logic to update Personal Best
---@param session table The global state snapshot (__SessionAggAccuracy)
function M.UpdateBestRun(session)
	-- PK is SongHash, fallback to SongID, then AssetPath, then Name
	local pk = session.SongHash
	if not pk or pk == "" then
		pk = tostring(session.SongID)
	end
	if not pk or pk == "0" then
		pk = session.AssetPath
	end
	if not pk or pk == "" then
		pk = session.SongName
	end

	local history = M.LoadHistory()
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

	-- Increment play count
	pb.playCount = pb.playCount + 1

	-- Success Metric: Compare by TotalScore (CombatScore)
	local isNewPB = false
	if session.TotalScore > pb.highScore then
		isNewPB = true
		pb.highScore = session.TotalScore
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
