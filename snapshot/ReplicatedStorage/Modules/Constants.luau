-- Time unit conversions (used across analytics, ban, moderation). Kept as
-- locals so derived values (e.g. BAN_DURATIONS) can reference them while the
-- Constants table is still being constructed.
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR   = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY    = 24 * SECONDS_PER_HOUR
local HOURS_PER_DAY      = 24

local Constants = {
	-- Build version (sent to GameAnalytics; bump on each release)
	GAME_VERSION          = "0.6.0",

	-- Time unit conversions (used across analytics, ban, moderation)
	SECONDS_PER_MINUTE    = SECONDS_PER_MINUTE,
	SECONDS_PER_HOUR      = SECONDS_PER_HOUR,
	SECONDS_PER_DAY       = SECONDS_PER_DAY,
	HOURS_PER_DAY         = HOURS_PER_DAY,

	-- Drawing limits per player
	MAX_STROKES           = 80,
	MAX_PIXELS_PER_STROKE = 1200,
	MAX_TOTAL_PIXELS      = 15000,
	MAX_UNDO_STEPS        = 80,

	-- Player counta
	MIN_PLAYERS           = 2,

	-- Canvas
	CANVAS_SIZE           = 512,

	-- DrawRenderer.render yields after this many circle dabs so replaying a dense
	-- drawing (or 8 gallery slots back-to-back) cannot exhaust a single resumption
	-- point's execution time. Live drawing (CanvasController) is unaffected — it
	-- uses the dab primitives directly, not render().
	RENDER_DAB_YIELD_BUDGET = 200000,

	-- Character movement defaults
	DEFAULT_WALK_SPEED    = 16,
	DEFAULT_JUMP_POWER    = 50,

	-- Brush
	DEFAULT_BRUSH_SIZE    = 0.01,

	-- Mid-join: offer join if this many seconds remain
	MID_JOIN_MIN_SECONDS  = 60,

	-- Timing (seconds)
	LOADING_DURATION             = 5,
	DRAWING_DURATION             = 90,
	SUBMIT_BUTTON_DELAY          = 1,
	COLLECT_TIMEOUT              = 7,
	REVEAL_INTRO_DURATION        = 2,
	REVEAL_DRAWING_VIEW_DURATION = 5,
	ROUND_START_DELAY            = 15,
	-- Phase-transition screen (PassGui): how long it stays up, and the fade in/out
	-- length folded into it. The server delays the drawing/reveal start by
	-- PASS_DURATION so the stage screen is fully shown before the phase begins
	-- (see Round StartDrawingPhase / StartRevealPhase). PASS_SETUP_DELAY is how
	-- long after the screen opens the client scene (camera/CanvasGui) is set up, so
	-- it happens behind the fully shown screen rather than racing the fade-in; it
	-- must be < PASS_DURATION. The screen does not close on a timer alone: it waits
	-- for BOTH PASS_DURATION to elapse AND the scene setup to finish, so a slow
	-- setup never reveals a half-built scene. PASS_MAX_HOLD caps that wait so a
	-- missing scene-ready signal can never trap the player behind the screen.
	PASS_DURATION                = 3,
	PASS_FADE_DURATION           = 0.3,
	PASS_SETUP_DELAY             = 1.5,
	PASS_MAX_HOLD                = 8,

	-- Timer warning
	TIMER_WARNING_THRESHOLD  = 10,
	TIMER_BLINK_INTERVAL     = 0.5,
	TIMER_BLINK_COLOR_ON     = Color3.fromRGB(220, 50, 50),
	TIMER_BLINK_COLOR_OFF    = Color3.new(1, 1, 1),

	-- Emoji
	EMOJI_RISE_DURATION   = 2,
	EMOJI_RISE_AMOUNT     = 0.2,
	EMOJI_COOLDOWN        = 0.3,

	-- Emoji button affordance (client-side feel; see RoundClient emoji block). Every
	-- button's UIStroke thickness softly breathes between MIN and MAX so the bar reads
	-- as interactive; selecting any emoji stops it, a new round restarts it. The selected
	-- button rests at SELECTED_THICKNESS so the player's pick stays marked.
	EMOJI_BREATHE_MIN      = 1,
	EMOJI_BREATHE_MAX      = 2,
	EMOJI_BREATHE_DURATION = 1.4,
	EMOJI_SELECTED_THICKNESS = 2,

	-- Result screen (ResultGui) sequence, in order:
	--   1. EmojiContainer shows reaction counts for RESULT_EMOJI_VIEW_DURATION,
	--   2. it fades out over RESULT_CONTAINER_FADE_DURATION,
	--   3. StarContainer shows the Star breakdown for RESULT_STAR_VIEW_DURATION,
	--   4. the whole ResultFrame fades out over RESULT_FADE_DURATION, then disables.
	-- When a drawing got no reactions, steps 1-2 are skipped (see ResultController).
	RESULT_EMOJI_VIEW_DURATION     = 3,
	RESULT_CONTAINER_FADE_DURATION = 0.5,
	RESULT_STAR_VIEW_DURATION      = 3,
	RESULT_FADE_DURATION           = 0.5,

	-- One-step tutorial (TutorialGui). The server already gates the show until after the
	-- gallery teleport + Lobby transition fade (it fires on the same delayed thread as the
	-- result). This is only the client-side grace gap before opening for a player who has no
	-- "You Got" screen to chain off (their drawing was not revealed); players who do see the
	-- result open right after its fade-out instead. See TutorialController.
	TUTORIAL_OPEN_DELAY            = 0.5,

	-- Master switch for the one-step tutorial. While false, RoundManager.CleanRound never
	-- marks a player eligible, so TutorialRemote never fires and seenTutorial is never spent
	-- (every player stays eligible if this is flipped back on). The TutorialController/GUI
	-- wiring is left intact; flipping this gate open re-enables the tutorial.
	TUTORIAL_ENABLED               = true,

	-- Master switch for the theme system (the A/B "Draw X like <theme>" experiment). While
	-- false, the theme is bypassed and every player gets the plain "Draw <subject>" prompt
	-- regardless of A/B group (the old group-B arm, now the permanent default). The A-arm
	-- prompt code and the theme payload are left intact, so flipping this back on restores
	-- the experiment. See DrawingController:Enter.
	THEME_ENABLED                  = false,

	VALID_BRUSH_SIZES = { [0.01] = true, [0.04] = true, [0.08] = true },

	VALID_EMOJIS = {
		laugh   = true,
		skull   = true,
		shocked = true,
		normal  = true,
	},

	-- UI text
	TEXT_WAITING            = "Waiting for players",
	TEXT_ROUND_STARTING     = "Round starting",
	TEXT_PHASE_DRAWING      = "Drawing",
	TEXT_PHASE_SUBMITTED    = "Waiting for others",
	TEXT_PHASE_COLLECT      = "Collecting drawings",
	TEXT_PHASE_REVEAL_INTRO = "Get ready",
	TEXT_PHASE_REVEAL       = "Revealing",
	TEXT_PHASE_CLEAN        = "Round over",
	TEXT_TIMER              = "Time Left: ",

	-- Phase transition screen (PassGui): the visible stage name shown when a phase
	-- begins. Multiple internal phases fold into one visible stage, so the pass
	-- screen only re-shows when this name changes (see PassController).
	PHASE_PASS_LABELS = {
		WAITING_PHASE      = "Lobby",
		DRAWING_PHASE      = "Drawing",
		COLLECTING_PHASE   = "Reveal",
		REVEAL_INTRO_PHASE = "Reveal",
		REVEAL_PHASE       = "Reveal",
		CLEAN_ROUND_PHASE  = "Lobby",
	},

	-- UI selection highlight
	SELECTED_BORDER_COLOR     = Color3.fromRGB(85, 255, 0),
	SELECTED_BORDER_THICKNESS = 3,
	SELECTED_BUTTON_SCALE     = 1.05,

	-- Source of truth for the drawing palette. The client paints each color
	-- button's BackgroundColor3 FROM this table at boot (matched by button name),
	-- so the button color always equals the encoded color exactly — a button can
	-- no longer drift from VALID_COLORS in Studio. Array order = the color index
	-- (0-15) used by StrokeCodec/StrokeValidator; if it changes, client and server
	-- update together. `name` is the canonical (ASCII, case-insensitive) button
	-- name used for that match (see UIController color binding).
	VALID_COLORS = {
		{ name = "Siyah",      r = 26,  g = 26,  b = 26  },
		{ name = "Beyaz",      r = 255, g = 255, b = 255 },
		{ name = "Gri",        r = 158, g = 158, b = 158 },
		{ name = "Ten",        r = 245, g = 196, b = 161 },
		{ name = "Kirmizi",    r = 232, g = 57,  b = 46  },
		{ name = "Turuncu",    r = 249, g = 115, b = 22  },
		{ name = "Sari",       r = 250, g = 204, b = 21  },
		{ name = "Yesil",      r = 34,  g = 197, b = 94  },
		{ name = "Turkuaz",    r = 20,  g = 184, b = 166 },
		{ name = "Mavi",       r = 59,  g = 130, b = 246 },
		{ name = "Mor",        r = 139, g = 92,  b = 246 },
		{ name = "Pembe",      r = 236, g = 72,  b = 153 },
		{ name = "Kahve",      r = 146, g = 64,  b = 14  },
		{ name = "Koyu yesil", r = 22,  g = 101, b = 52  },
		{ name = "Lacivert",   r = 30,  g = 58,  b = 95  },
		{ name = "Bordo",      r = 190, g = 18,  b = 60  },
	},

	-- Per-round Star reward. Paid to a drawing's
	-- owner once their drawing has been revealed: a flat base plus a bonus for each
	-- positive reaction it received (each reacting player's LAST emoji counts once,
	-- so spamming cannot inflate the payout). normal is not a positive reaction.
	ROUND_REWARD_BASE         = 20,
	ROUND_REWARD_PER_REACTION = 1,
	POSITIVE_REACTIONS = {
		laugh   = true,
		skull   = true,
		shocked = true,
	},

	-- Subject-guarantee Developer Product: buying it queues the player to be the next
	-- round's subject (the drawn player). Consumable, so it can be bought repeatedly;
	-- two buyers form a FIFO queue. The id is the live Roblox product id; if it is 0 the
	-- client skips the purchase prompt and the server ignores the receipt (feature off).
	SUBJECT_GUARANTEE_PRODUCT_ID = 3606209956,

	-- Frame ids (shop keys). Single source for the strings both client and server key on
	-- (FrameShopService grant/equip, MarketController card binding, FRAME_DISPLAY lookup).
	-- The market cards are authored under number-prefixed nodes (1Cute, 2Gold, ...) so a
	-- UIGridLayout keeps them ordered; the node name is not the frame id. MarketController
	-- maps each node to the prefix-less id below (the string used everywhere else).
	CUTE_FRAME_NAME      = "Cute",
	GOLD_FRAME_NAME      = "Gold",
	GOOFY_FRAME_NAME     = "Goofy",
	DARK_FRAME_NAME      = "Dark",
	WOOD_FRAME_NAME      = "Wood",
	CARDBOARD_FRAME_NAME = "CardBoard",

	-- Gallery (lobby mini canvases of previous round's drawings)
	GALLERY_SLOT_COUNT    = 8,

	-- Frames (cosmetic borders around the reveal display)
	-- The frame border is a single authored ImageLabel named "Frame" living under
	-- Screen.DisplayPart > SurfaceGui, alongside the drawing "Image" (ImageLabel) and the
	-- "EmojiLayer" (a Frame container).
	-- On Apply, FrameController points that one ImageLabel at the equipped frame (Image /
	-- Position / Size from FRAME_DISPLAY below) and shows it. DEFAULT_FRAME_NAME means "no
	-- special frame": the ImageLabel is hidden, leaving just the bare drawing.
	-- FRAME_EQUIP_ATTRIBUTE is a temporary source for the equipped frame until the
	-- shop/ownership data reaches the reveal; FrameController reads it off the owning Player
	-- and this becomes a server payload field later.
	DEFAULT_FRAME_NAME    = "default",
	FRAME_EQUIP_ATTRIBUTE = "EquippedFrame",

	-- Per-frame border art, keyed by frame id (the EquippedFrame attribute string). On Apply
	-- the "Frame" ImageLabel's Image / Position / Size are set from the entry. Position and
	-- Size are Scale-based UDim2s authored per asset (each art has different internal margins,
	-- so each frame's values differ) so the border surrounds the drawing. DEFAULT_FRAME_NAME
	-- is never listed (it hides the ImageLabel).
	FRAME_DISPLAY = {
		Gold      = { image = "rbxassetid://71187499822046", position = UDim2.new(-0.07, 0, -0.07, 0),   size = UDim2.new(1.14, 0, 1.15, 0) },
		Cute      = { image = "rbxassetid://71908176717123", position = UDim2.new(-0.053, 0, -0.053, 0), size = UDim2.new(1.1, 0, 1.08, 0) },
		Dark      = { image = "rbxassetid://80941504992864", position = UDim2.new(-0.115, 0, -0.078, 0), size = UDim2.new(1.23, 0, 1.155, 0) },
		Wood      = { image = "rbxassetid://75348877897496", position = UDim2.new(-0.13, 0, -0.12, 0),   size = UDim2.new(1.26, 0, 1.25, 0) },
		CardBoard = { image = "rbxassetid://82405203994006", position = UDim2.new(-0.05, 0, -0.025, 0),  size = UDim2.new(1.1, 0, 1.05, 0) },
		Goofy     = { image = "rbxassetid://95083033117795", position = UDim2.new(-0.05, 0, -0.025, 0),  size = UDim2.new(1.1, 0, 1.05, 0) },
	},

	-- Frame shop prices in Stars, keyed by frame id. A frame listed here is bought with
	-- Stars (server-authoritative: FrameShopService reads the price from here, never from
	-- the client). Every shop frame has a Star price; the four premium frames also have a
	-- Robux Game Pass (FRAME_GAMEPASS_IDS below) as an alternate purchase path.
	-- DEFAULT_FRAME_NAME is never listed (no-special-frame fallback).
	FRAME_PRICES = {
		Cute      = 150,
		Gold      = 150,
		Goofy     = 150,
		Dark      = 150,
		Wood      = 20,
		CardBoard = 20,
	},

	-- Robux Game Pass ids, keyed by frame id. A frame listed here can also be bought for
	-- Robux via its Game Pass: the client prompts MarketplaceService:PromptGamePassPurchase
	-- and the server grants the frame on PromptGamePassPurchaseFinished / join-time
	-- UserOwnsGamePassAsync (FrameShopService). Game Passes are NOT consumable, so they do
	-- not go through ProcessReceipt (that stays owned solely by the subject-guarantee Dev
	-- Product). Wood and CardBoard are Star-only, so they are absent here.
	FRAME_GAMEPASS_IDS = {
		Cute  = 1891548320,
		Gold  = 1893605960,
		Goofy = 1893947553,
		Dark  = 1893282287,
	},

	-- Moderation: how many distinct reporters hide a drawing for everyone + persist it
	REPORT_THRESHOLD      = 4,

	-- Analytics clamps (seconds) — guard against absurd elapsed values
	ANALYTICS_MAX_ELAPSED        = 180,  -- drawing/submit/quit-wait cap
	ANALYTICS_MAX_PHASE_ELAPSED  = 600,  -- mid-round phase elapsed cap
	ANALYTICS_MAX_LOBBY_ELAPSED  = 120,  -- QuitAlone lobby-wait bin cap
	ANALYTICS_MAX_ROUNDS         = 20,
	ANALYTICS_MAX_STARS          = 100000,  -- session StarsEarned cap (clamps only absurd outliers)

	-- Ref/scene resolution timeouts (seconds)
	GUI_TIMEOUT           = 8,
	MAP_TIMEOUT           = 10,
	CHARACTER_WAIT_TIMEOUT = 3,

	--------------------------------------------------------------------------
	-- Admin / Moderation tunables
	--------------------------------------------------------------------------

	-- Anomaly counter: N anomalies within the window auto-kicks the player
	ANOMALY_KICK_THRESHOLD = 5,
	ANOMALY_WINDOW_SECONDS = 60,

	-- Per-admin command rate limit
	RATE_LIMIT_MAX_PER_MINUTE = 30,
	RATE_LIMIT_WINDOW_SECONDS = 60,

	-- Retry for moderation DataStore writes (UpdateAsync/SetAsync). The backoff
	-- exceeds the ~6s per-key UpdateAsync cooldown so a throttled second action on
	-- the same key (e.g. Dismiss then Ban) clears instead of failing the admin.
	DATASTORE_WRITE_RETRIES     = 2,
	DATASTORE_WRITE_BACKOFF_SEC = 7,

	-- Admin panel report fetching
	REPORT_FETCH_LIMIT    = 60,  -- how many index entries to pull
	REPORT_LIST_LIMIT     = 20,  -- how many rows to show per tab
	REPORT_LIST_MAX       = 100, -- hard cap on ReportIndex.listRecent

	-- How long the admin panel's title-bar error banner stays before clearing
	-- (see AdminPanelClient.flashError).
	ADMIN_ERROR_FLASH_SECONDS = 4,

	-- Ban duration options (seconds). "perm" is intentionally absent (nil = permanent).
	BAN_DURATIONS = {
		["1h"]  = SECONDS_PER_HOUR,
		["1d"]  = SECONDS_PER_DAY,
		["7d"]  = 7 * SECONDS_PER_DAY,
		["30d"] = 30 * SECONDS_PER_DAY,
	},

	-- DataStore / MessagingService identifiers (versioned)
	AUDIT_LOG_STORE       = "AdminAuditLog_v1",
	BAN_STORE             = "BannedPlayers_v1",
	REPORT_DETAIL_STORE   = "ReportedDrawings_v1",
	REPORT_INDEX_STORE    = "ReportIndex_v1",
	REPORT_AUDIT_STORE    = "ReportAuditLog_v1",  -- every individual report (audit trail), separate from active-report moderation
	BAN_TOPIC             = "AdminBan_v1",

	-- Drawing-quit research log (read externally via Open Cloud)
	QUITLOG_DETAIL_STORE  = "DrawingQuitLog_v1",       -- full per-quit entry
	QUITLOG_INDEX_STORE   = "DrawingQuitLogIndex_v1",  -- chronological index
	SESSION_COUNT_STORE   = "PlayerSessionCount_v1",   -- lifetime session counter

	-- First-time players' first finished drawing (admin panel "First-Timers" tab).
	-- One record per player (key = userId); only theme + drawing buffer.
	FIRSTDRAW_DETAIL_STORE = "FirstTimerDrawings_v1",      -- full entry (drawing buffer)
	FIRSTDRAW_INDEX_STORE  = "FirstTimerDrawingsIndex_v1", -- chronological index
	FIRSTDRAW_LIST_LIMIT   = 50,  -- how many rows to show in the First-Timers tab

	-- Drawing-analysis panel (/drawings): paginated browse of all first-timer
	-- drawings. The A/B experiment group is derived from the owner's UserId
	-- (even -> A, odd -> B), matching GroupService for the live game.
	DRAWINGS_PAGE_SIZE      = 50,          -- summaries fetched per page

	-- How often the client reports its live stroke/undo counts during drawing.
	-- Throttled so a full drawing session is only a handful of remote calls,
	-- yet a crash loses at most this many seconds of progress data.
	DRAW_PROGRESS_REPORT_INTERVAL = 2,
}

return Constants
