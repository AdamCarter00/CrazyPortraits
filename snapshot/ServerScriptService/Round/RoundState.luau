local Players = game:GetService("Players")

local RoundState = {}
RoundState.__index = RoundState

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function RoundState.new()
	return setmetatable({
		-- [player] = { drawingData, currentTheme, bannedThemes, lastEmojiTime, currentVote }
		players        = {},
		readyPlayers   = {},
		lobbyEnterTime = {},
		round = {
			token               = 0,
			phase               = "Waiting",
			phaseStartTime      = nil,
			currentSubject      = nil,
			currentPlayers      = {},
			-- Subset of currentPlayers who joined too late to draw and are only
			-- watching this round. They see the reveal and can react, but produce no
			-- analytics/round-completion (see RoundManager). [player] = true.
			spectators          = {},
			startTime           = nil,
			currentDrawingOwner = nil,
			drawingVotes        = {},
		},
	}, RoundState)
end

--------------------------------------------------------------------------------
-- Player Lifecycle
--------------------------------------------------------------------------------

function RoundState:AddPlayer(player)
	self.players[player] = {
		drawingData             = nil,
		currentTheme            = nil,
		bannedThemes            = {},
		lastEmojiTime           = 0,
		currentVote             = nil,
		group                   = nil,
		submittedDuringDrawing  = false,
		submitElapsed           = nil,
		-- Live drawing progress, reported by the client during the drawing
		-- phase. Reset each round (see resetPlayerStates). Used by the
		-- drawing-quit research log.
		strokesDrawn            = 0,
		undoCount               = 0,
		-- Lifetime session count, loaded once on join (does not reset per round).
		lifetimeSession         = -1,
	}
end

function RoundState:RemovePlayer(player)
	self.players[player]        = nil
	self.readyPlayers[player]   = nil
	self.lobbyEnterTime[player] = nil
	self.round.spectators[player] = nil
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function RoundState:NewRound()
	self.round.token               += 1
	self.round.phase                = "Waiting"
	self.round.phaseStartTime       = nil
	self.round.currentSubject       = nil
	self.round.currentPlayers       = {}
	self.round.spectators           = {}
	self.round.startTime            = nil
	self.round.currentDrawingOwner  = nil
	self.round.drawingVotes         = {}
	return self.round.token
end

function RoundState:IsTokenValid(token)
	return self.round.token == token
end

function RoundState:GetReadyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if self.readyPlayers[player] then
			table.insert(list, player)
		end
	end
	return list
end

return RoundState
