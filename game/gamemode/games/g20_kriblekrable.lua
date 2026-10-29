-- Låge 20: Kriblekrable-ord
-- Rebuilt from the original scarabgame.swf. Beetles carrying letters crawl around the table;
-- pick them up with the mouse and drop them in the right holes of the type case to spell the
-- word. Some letters are shown, the rest you have to work out. Same rules as the original
-- engine: 37 levels from 2 to 11 letters, (6 + 2 per letter) seconds a level, 25 points for a
-- finished word plus one per second left, the beetles crawl at 4 pixels a frame (24 a second).
-- The original also has code for beetles crawling out of their hole again after 10 seconds, but it
-- was never called (a typo in its name). With "Hidden content" turned on in the settings it is
-- used here, exactly as it was written; with it off, a placed beetle stays put like in the original.
-- In English the words are English (same lengths); in Danish they are the original list.
local UI, MG, TL = AN.UI, AN.MG, AN.TL
local unpack = unpack or table.unpack
local DIR = (GM or GAMEMODE).FolderName .. "/gamemode/games/data/"
for _, f in ipairs({ "pos", "root", "letters", "hole", "scarab", "body1", "body2", "legA", "legB", "eyes1", "eyes2", "msg", "fade" }) do
	include(DIR .. "g20_" .. f .. ".lua")
end
local P = AN.G20Pos

local G = {
	scoreType = "score",
	goal = 800,       -- the original coolScore
	worst = 0,
	descKey = "desc_20",
	howKey = "how_20",
}

local STAGE_W, STAGE_H = 740, 420
local STEP = 1 / 24
local SPEED = 4
local LEVEL_TIME, EXTRA_PER_LETTER = 6, 2
local FINISHED_SCORE, PER_SECOND = 25, 1
local GAME_X = -9.2                       -- the game clip on the stage
local MSG_X, MSG_Y = 268.75, -20.95       -- the messages clip
local BOT1 = { 147, 173 }                 -- regpointbottom1 / 2: where the beetles crawl
local BOT2 = { 600.85, 361.8 }
local ENGINE = { -1, -1 }                 -- the engine clip (the shadows live in it)
local HOLE_HIT = { -37.4, -40.8, 34.1, 41.7 }   -- a hole's shapes + its letter box
local AUTO_CONTINUE = 3

-- the original levels: { letters, letters shown }
local DIFF = {
	{ 2, 2 }, { 2, 1 }, { 3, 3 }, { 4, 4 }, { 5, 4 }, { 4, 2 }, { 3, 1 }, { 4, 2 }, { 4, 1 }, { 5, 2 },
	{ 3, 0 }, { 4, 0 }, { 5, 1 }, { 5, 0 }, { 6, 2 }, { 6, 1 }, { 6, 0 }, { 7, 3 }, { 7, 2 }, { 7, 1 },
	{ 7, 0 }, { 8, 3 }, { 8, 2 }, { 8, 1 }, { 8, 0 }, { 9, 3 }, { 9, 2 }, { 9, 1 }, { 9, 0 }, { 10, 3 },
	{ 10, 2 }, { 10, 1 }, { 10, 1 }, { 11, 4 }, { 11, 4 }, { 11, 3 }, { 11, 2 },
}

-- the original word list (in its original order; sorted by length below, like the original)
local WORDS_DA = {
	"ko", "æv", "år", "øv", "vi", "nu", "bæ", "by", "bo", "ro", "se", "må", "ry", "tø", "tå", "sy", "læ",
	"dyt", "kys", "hyl", "lyd", "lyv", "død", "tyv", "tyr", "ben", "bid", "bud", "hår", "hæs", "jul", "elg", "elv",
	"hår", "lys", "abe", "ost", "orm", "far", "ris", "det", "men", "ord", "mad", "sut", "mor", "ide", "får",
	"hest", "hund", "luft", "gris", "æsel", "vand", "saft", "ring", "bore", "ekko", "fane", "fedt", "film", "fisk",
	"gips", "glat", "glød", "hane", "heks",
	"trumf", "træer", "tunge", "træde", "træls", "trøst", "trøje", "breve", "Asien", "besøg", "bille", "bonus",
	"brise", "dyppe", "ensom", "fumle", "fylde", "giraf",
	"rakker", "rampen", "bageri", "tyveri", "ananas", "bedøve", "bildæk", "biltur", "tagpap", "tosset", "nisser",
	"skinke", "plasma",
	"grødris", "stjerne", "beostær", "næsebor", "sejlbåd", "bageovn", "bagdele", "fakiren", "Faderen", "fjolser",
	"fjumrer", "fodbold",
	"ymerdrys", "jordhule", "teltlejr", "næsehorn", "salatbar", "sejlskib", "indlæser", "intriger", "zoologer",
	"gabestok", "gevaldig", "grovæder",
	"risengrød", "sparegris", "kaffeklub", "kaffepose", "drømmehat", "gifttønde", "politibil", "postbunke",
	"agurketid", "ridelærer", "agurkerne",
	"afstivning", "dagdrivere", "djævlespil", "drikkevand", "drillepind", "femkantede", "feriebolig", "filterpose",
	"filmverden", "hajfiskeri", "halmballer", "kattekasse", "afkalkeren", "abonnement", "dumdristig", "mælkevejen",
	"hakkebøffen", "helbredelse", "idolbillede", "indrømmelse", "Internettet", "isterninger", "iterationer",
	"delfinarium", "boremaskine",
}
local WORDS_EN = {
	"go", "up", "it", "me", "no", "at", "on", "in", "be", "do", "so", "we", "hi", "ox", "my",
	"cat", "dog", "sun", "hat", "elf", "toy", "box", "cup", "red", "pie", "jam", "ice", "bug", "owl", "fox",
	"bee", "hen", "pig", "cow", "egg", "ant", "bat", "bus", "map",
	"star", "tree", "gift", "bell", "snow", "cake", "fish", "book", "duck", "frog", "lamb", "milk", "rice",
	"sock", "kite", "ring", "wolf", "bear", "goat", "drum",
	"candy", "house", "mouse", "horse", "train", "clock", "bread", "robot", "sheep", "tiger", "apple", "lemon",
	"pizza", "chair", "cloud",
	"candle", "rocket", "turkey", "mitten", "cookie", "ginger", "parrot", "castle", "pencil", "garden", "rabbit",
	"monkey", "winter", "butter", "spider",
	"present", "snowman", "pudding", "blanket", "chimney", "kitchen", "penguin", "giraffe", "lantern", "cabbage",
	"pumpkin", "trumpet", "crystal", "dolphin",
	"reindeer", "snowball", "ornament", "stocking", "chestnut", "elephant", "dinosaur", "mountain", "sandwich",
	"football", "pancakes", "umbrella",
	"christmas", "snowflake", "chocolate", "butterfly", "pineapple", "crocodile", "telephone", "adventure",
	"marmalade", "carpenter",
	"strawberry", "watermelon", "basketball", "nutcracker", "blackboard", "skateboard", "helicopter", "toothbrush",
	"microphone", "evergreens",
	"gingerbread", "candlelight", "grasshopper", "storyteller", "caterpillar", "nightingale", "motorcycles",
}

local function chars(s)
	local out = {}
	for _, c in utf8.codes(s) do out[#out + 1] = utf8.char(c) end
	return out
end

local function wordList()
	local src = AN.LangCode() == "da" and WORDS_DA or WORDS_EN
	local list = {}
	for i, w in ipairs(src) do list[i] = { word = AN.Upper(w), len = utf8.len(w) } end
	-- the original bubble sort by length (keeps the order within a length)
	local swap = true
	while swap do
		swap = false
		for i = 1, #list - 1 do
			if list[i].len > list[i + 1].len then
				list[i], list[i + 1] = list[i + 1], list[i]
				swap = true
			end
		end
	end
	return list
end

local function rotM(deg, x, y, sx, sy)
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	sx, sy = sx or 1, sy or sx or 1
	return { c * sx, s * sx, -s * sy, c * sy, x, y }
end

local function inv(m)
	local det = m[1] * m[4] - m[2] * m[3]
	if math.abs(det) < 1e-9 then return nil end
	local a, b, c, d = m[4] / det, -m[2] / det, -m[3] / det, m[1] / det
	return { a, b, c, d, -(a * m[5] + c * m[6]), -(b * m[5] + d * m[6]) }
end

local function slotName(name)
	local base, inst = string.match(name, "^([^#]+)#?(.*)$")
	return base, inst
end

function G:Status()
	return AN.L("g20_status", (self.curlevel or 0) + 1, #DIFF, self.score or 0)
end

function G:Open(args)
	self.finished = false
	self.acc = 0
	self.tick = 0
	self.clock = 0
	self.words = wordList()
	self.scarabs = {}
	self.holes = {}
	self.score, self.showscore, self.curlevel = 0, 0, 0
	self.msgFrame = 1
	self.autoAt = nil
	self.fadeF = 1
	self.drag = nil
	self.txt = { txtscore = "0", txttime = "" }
	self:InitWord()
	self:ScarabsInit()
	self.gameState = "playgame"
	self:WalkSound(true)
end

function G:Close()
	self:WalkSound(false)
	self:LooseSound(false)
end

-- the "getting loose" sound of a beetle about to crawl out (cut content)
function G:LooseSound(on)
	if IsValid(self.looseCh) then self.looseCh:Stop() end
	self.looseCh = nil
	self.looseReq = (self.looseReq or 0) + 1
	if not on then return end
	local v = (AN.Save.Get("vol_fx") or 85) / 100
	if v <= 0 or AN.SoundMode() == 2 then return end
	local req = self.looseReq
	sound.PlayFile("sound/alletidersnisse/g20/getloose.mp3", "noplay", function(ch)
		if not IsValid(ch) then return end
		if req ~= self.looseReq then ch:Stop() return end
		ch:SetVolume(v)
		ch:Play()
		self.looseCh = ch
	end)
end

-- the beetles' crawling sound (one loop while any of them crawls)
function G:WalkSound(on)
	if not on then
		if IsValid(self.walkCh) then self.walkCh:Stop() end
		self.walkCh = nil
		self.walkWanted = false
		return
	end
	self.walkWanted = true
	if self.walkCh or self.walkLoading then return end
	local v = (AN.Save.Get("vol_fx") or 85) / 100 * 0.35
	if v <= 0 or AN.SoundMode() == 2 then return end
	self.walkLoading = true
	sound.PlayFile("sound/alletidersnisse/g20/bugwalk.mp3", "noplay", function(ch)
		self.walkLoading = false
		if not IsValid(ch) then return end
		if not self.walkWanted then ch:Stop() return end
		ch:EnableLooping(true)
		ch:SetVolume(v)
		ch:Play()
		self.walkCh = ch
	end)
end

---------------------------------------------------------------------------
-- the original engine
---------------------------------------------------------------------------
function G:Now() return self.clock * 1000 end   -- getTimer()

function G:InitWord()
	local d = DIFF[self.curlevel + 1]
	local n = d[1]
	local first, count = nil, 0
	for i, w in ipairs(self.words) do
		if w.len == n then
			first = first or i
			count = count + 1
		end
	end
	-- the words of this length, the longest unused last; pick one of the 5 oldest
	local now = self:Now()
	local oldest = {}
	for t = 0, count - 1 do
		local id = first + t
		local age = now - (self.words[id].lastUse or 0)
		local inserted = false
		for tt = 1, #oldest do
			local a2 = now - (self.words[oldest[tt]].lastUse or 0)
			if a2 >= age then
				table.insert(oldest, tt, id)
				inserted = true
				break
			end
		end
		if not inserted then oldest[#oldest + 1] = id end
	end
	local rand = math.floor(math.random() * 5)
	local id = oldest[math.max(1, #oldest - rand)]
	self.curword = chars(self.words[id].word)
	self.words[id].lastUse = now
	-- the holes, and the letters shown in them
	local tmp = {}
	for i = 1, #self.curword do
		self.holes[i] = self.holes[i] or {}
		self.holes[i].char = self.curword[i]
		self.holes[i].displayChar = ""
		tmp[#tmp + 1] = i
	end
	for _ = 1, d[2] do
		local r = math.floor(math.random() * #tmp) + 1
		local h = self.holes[tmp[r]]
		h.displayChar = h.char
		table.remove(tmp, r)
	end
	self.scarabAmount = #self.curword
	self.timeLeft = (LEVEL_TIME + EXTRA_PER_LETTER * #self.curword) * 25
	self.txt.txttime = tostring(math.floor(self.timeLeft / 25))
end

function G:ScarabsInit()
	local arr = self.scarabs
	for i = 1, self.scarabAmount do
		local s = arr[i]
		if not s then
			s = { x = 0, y = 0 }
			arr[i] = s
		end
		self.holes[i].filled = false
		s.dirX, s.dirY = 0, 0
		s.rotation = math.random() * 360
		s.mcRot = s.rotation
		s.rotationspeed = 0
		s.holeId = -1
		-- a free spot, at least ~70 pixels from every beetle
		local tx, ty
		for _ = 1, 5000 do
			tx = math.floor(math.random() * (BOT2[1] - BOT1[1])) + BOT1[1]
			ty = math.floor(math.random() * (BOT2[2] - BOT1[2])) + BOT1[2]
			local ok = true
			for t = 1, #arr do
				local o = arr[t]
				local dx, dy = tx - o.x, ty - o.y
				if dx * dx + dy * dy < 5000 then ok = false break end
			end
			if ok then break end
		end
		s.x, s.y = tx, ty
		s.char = self.curword[i]
		s.kind = math.floor(math.random() * 2) + 1
		s.state = "free"
		s.body = "crawling"
		s.scale = 1
		s.born = self.tick
		s.shX, s.shY, s.shRot = s.x + 4, s.y + 4, s.rotation
	end
	while #arr > self.scarabAmount do table.remove(arr) end
end

local function fixRotation(angle, target)
	local d = target - angle
	if d > 180 then d = d - 360 elseif d < -180 then d = d + 360 end
	return d / 15
end

function G:MoveAllScarabs()
	for _, s in ipairs(self.scarabs) do
		if s.state == "free" or s.state == "outside" then
			s.x = s.x + s.dirX
			s.y = s.y + s.dirY
			s.mcRot = s.rotation + (math.random() - 0.5) * 6
		elseif s.state == "dragging" then
			s.jx, s.jy = (math.random() - 0.5) * 5, (math.random() - 0.5) * 5
			s.mcRot = s.rotation + (math.random() - 0.5) * 20
		end
	end
end

function G:MoveAllShadows()
	for _, s in ipairs(self.scarabs) do
		if s.state == "free" or s.state == "outside" then
			s.shX, s.shY, s.shRot = s.x + 4, s.y + 4, s.rotation
		elseif s.state == "dragging" then
			s.shX, s.shY, s.shRot = s.x + 20, s.y + 20, s.mcRot
		elseif s.state == "locked" then
			s.shX, s.shY, s.shRot = s.x, s.y, s.mcRot
		end
	end
end

function G:ScarabDirection()
	for _, s in ipairs(self.scarabs) do
		if s.state ~= "dragging" and s.state ~= "locked" then
			local inX = s.x > BOT1[1] and s.x < BOT2[1]
			local inY = s.y > BOT1[2] and s.y < BOT2[2]
			if inX and inY then
				s.rotationspeed = (math.random() - 0.5) * 10.8
			else
				s.state = "outside"
				if s.x < BOT1[1] then
					if s.y < BOT1[2] then s.rotationspeed = fixRotation(s.rotation, 45)
					elseif s.y > BOT1[2] and s.y < BOT2[2] then s.rotationspeed = fixRotation(s.rotation, 0)
					elseif s.y > BOT2[2] then s.rotationspeed = fixRotation(s.rotation, 315) end
				elseif s.x > BOT1[1] and s.x < BOT2[1] then
					if s.y < BOT1[2] then s.rotationspeed = fixRotation(s.rotation, 90)
					elseif s.y > BOT2[2] then s.rotationspeed = fixRotation(s.rotation, 270) end
				elseif s.x > BOT2[1] then
					if s.y < BOT1[2] then s.rotationspeed = fixRotation(s.rotation, 135)
					elseif s.y > BOT1[2] and s.y < BOT2[2] then s.rotationspeed = fixRotation(s.rotation, 180)
					elseif s.y > BOT2[2] then s.rotationspeed = fixRotation(s.rotation, 225) end
				end
			end
			s.rotation = s.rotation + s.rotationspeed
			if s.rotation > 360 then s.rotation = s.rotation - 360 elseif s.rotation < 0 then s.rotation = s.rotation + 360 end
			s.dirX = math.cos(math.rad(s.rotation)) * SPEED
			s.dirY = math.sin(math.rad(s.rotation)) * SPEED
		end
	end
end

-- the original scarabEscape (cut content): a placed beetle sits still for a while, starts to wriggle,
-- then turns and crawls out of its hole, faster and faster, and the hole is empty again
local RELEASE = 10 * 24
function G:ScarabEscape()
	if AN.Save.Get("hidden") == false then return end
	for i, s in ipairs(self.scarabs) do
		if s.state == "locked" then
			s.time = (s.time or RELEASE) - 1
			if s.time == 0 then
				s.state = "free"
				s.body = "crawling"
				local h = self.holes[s.holeId]
				if h then h.filled = false end
				self:WalkSound(true)
				self:LooseSound(false)
				s.loosening = false
			elseif s.time < RELEASE / 3 then
				local accel = (s.time + RELEASE) / (RELEASE / 2)
				accel = accel * accel
				s.rotationspeed = fixRotation(s.mcRot, 90) / accel
				s.rotation = s.rotation + s.rotationspeed
				s.dirX = math.cos(math.rad(s.mcRot)) * (SPEED / accel)
				s.dirY = math.sin(math.rad(s.mcRot)) * (SPEED / accel)
				s.mcRot = s.rotation
				s.x = s.x + s.dirX + (math.random() - 0.5)
				s.y = s.y + s.dirY + (math.random() - 0.5)
				s.body = "crawling"
				if not s.loosening then self:LooseSound(true) end
				self.lastLoose = i
				s.loosening = true
			elseif s.time < RELEASE * 2 / 3 then
				s.x = s.x + (math.random() - 0.5) / 2
				s.y = s.y + (math.random() - 0.5) / 2
			end
		end
	end
end

function G:GameStatus()
	local locked = 0
	for i = 1, #self.holes do
		if not self.holes[i].filled then return end
		locked = locked + 1
		if locked == self.scarabAmount then
			self.gameState = "finished"
			self:LevelFinished()
			return
		end
	end
end

function G:LevelFinished()
	self:WalkSound(false)
	self:LooseSound(false)
	local secs = math.floor(self.timeLeft / 25)
	self.score = self.score + FINISHED_SCORE + PER_SECOND * secs
	AN.LevelScore(20, self.curlevel + 1, FINISHED_SCORE + PER_SECOND * secs, { total = self.score })
	if self.curlevel == #DIFF - 1 then
		self:Message(50)
	else
		self:Message(10)
		AN.Speak("godt")
	end
end

-- hint: one of the hidden letters is shown in its hole (and the hole glows for a moment)
function G:CanHint()
	if self.gameState ~= "playgame" then return false end
	for i = 1, #(self.curword or {}) do
		local h = self.holes[i]
		if h and not h.filled and h.displayChar == "" then return true end
	end
	return false
end
function G:Hint(cost)
	local free = {}
	for i = 1, #self.curword do
		local h = self.holes[i]
		if not h.filled and h.displayChar == "" then free[#free + 1] = i end
	end
	if #free == 0 then return false end
	local i = free[math.random(#free)]
	self.holes[i].displayChar = self.holes[i].char
	self.hintHole, self.hintT = i, 1.5
	self.score = math.max(0, self.score - cost)
	self.showscore = math.min(self.showscore, self.score)
	MG.Pop("-" .. cost, false, 400, 60)
end
function G:HintDraw(gm)
	if not self.hintT then return end
	self.hintT = self.hintT - FrameTime()
	if self.hintT <= 0 then self.hintT = nil return end
	local m = self:HoleMatrices()[self.hintHole]
	if not m then return end
	local x, y = TL.Apply(gm, m[5], m[6])
	MG.HintRing(x, y, 26, MG.HINT_GOLD, math.min(1, self.hintT * 2), 4)
end

function G:TimeRanOut()
	self:WalkSound(false)
	self:LooseSound(false)
	self:Message(30)
end

-- the messages clip: 1 nothing, 10 next level, 30 game over, 50 all words done
function G:Message(f)
	self.msgFrame = f
	if f == 30 or f == 50 then
		AN.Speak("gameover")
		self.autoAt = self.clock + AUTO_CONTINUE
	end
end

function G:NextLevelClick()
	self.curlevel = self.curlevel + 1
	self:InitWord()
	self:ScarabsInit()
	self.gameState = "playgame"
	self.msgFrame = 1
	self:WalkSound(true)
end

function G:RestartGameClick()
	AN.NewRun(20)
	self.autoAt = nil
	self.curlevel = 0
	self.score, self.showscore = 0, 0
	self.txt.txtscore = "0"
	self:InitWord()
	self:ScarabsInit()
	self.gameState = "playgame"
	self.msgFrame = 1
	self:WalkSound(true)
end

-- picking a beetle up / letting go (the beetle's button)
function G:Pickup(i, gx, gy)
	local s = self.scarabs[i]
	s.state = "dragging"
	local h = self.holes[s.holeId]
	if h then h.filled = false end
	s.loosening = false
	if self.lastLoose == i then self:LooseSound(false) end
	s.scale = 1.2
	s.x, s.y = gx, gy
	MG.Sound("g20", "pickup")
	self.drag = i
	UI.BeginDrag({ release = function() self:Drop(i) end })
end

function G:Drop(i)
	local s = self.scarabs[i]
	self.drag = nil
	if not s or s.state ~= "dragging" then return end
	MG.Sound("g20", "drop")
	s.scale = 1
	s.jx, s.jy = 0, 0
	local mx, my = MG.Mouse()
	local gx, gy = mx - GAME_X, my
	local correct = false
	local holeM = self:HoleMatrices()
	for h = 1, #self.holes do
		local hole = self.holes[h]
		local m = holeM[h]
		if not hole.filled and m then
			local im = inv(m)
			local lx, ly = TL.Apply(im, gx, gy)
			if lx >= HOLE_HIT[1] and lx <= HOLE_HIT[3] and ly >= HOLE_HIT[2] and ly <= HOLE_HIT[4] then
				correct = s.char == hole.char
				if correct then
					s.state = "locked"
					hole.filled = true
					s.mcRot, s.rotation = 270, 270
					s.holeId = h
					s.scale = 0.95
					s.x, s.y = m[5], m[6]
					s.body = "stand"
					break
				end
			end
		end
	end
	if not correct then
		s.state = "free"
	end
end

-- the holes' matrices in game coordinates (from the letter holder's frame)
function G:HoleMatrices()
	local out = {}
	local fr = AN.G20Letters.frames[#self.curword]
	for _, it in ipairs(fr or {}) do
		local _, inst = slotName(it[1])
		local n = tonumber(string.match(inst or "", "l(%d+)"))
		if n then out[n] = { it[2], it[3], it[4], it[5], it[6], it[7] } end
	end
	return out
end

function G:Step()
	self.tick = self.tick + 1
	self.clock = self.clock + STEP
	if self.fadeF < 18 then self.fadeF = self.fadeF + 1 end
	if self.gameState == "playgame" then
		self:MoveAllScarabs()
		self:MoveAllShadows()
		self:ScarabDirection()
		self:ScarabEscape()
		self:GameStatus()
		self.timeLeft = self.timeLeft - 1
		if self.timeLeft < 0 then
			self.gameState = "gameover"
			self:TimeRanOut()
		else
			local secs = math.floor(self.timeLeft / 25)
			if tostring(secs) ~= self.txt.txttime then
				self.txt.txttime = tostring(secs)
				if secs < 4 then MG.Sound("g20", "beep") end
			end
		end
	end
	if self.showscore < self.score then
		if self.showscore < self.score - 5 then self.showscore = self.showscore + 3 else self.showscore = self.showscore + 1 end
		self.txt.txtscore = tostring(self.showscore)
	end
	if self.autoAt and self.clock >= self.autoAt then self:Finish() end
end

function G:Think(dt)
	self.acc = self.acc + math.min(dt, 0.25)
	while self.acc >= STEP do
		self.acc = self.acc - STEP
		self:Step()
	end
	-- startDrag(true): the beetle's middle follows the mouse
	if self.drag and MG.k then
		local s = self.scarabs[self.drag]
		if s then
			local mx, my = MG.Mouse()
			s.x, s.y = mx - GAME_X + (s.jx or 0), my + (s.jy or 0)
		end
	end
end

function G:Finish()
	if self.finished then return end
	self.finished = true
	self.autoAt = nil
	self:WalkSound(false)
	self:LooseSound(false)
	AN.FinishGame(20, self.score)
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local function pic(name, m, alpha)
	local r = P[name]
	if r then TL.Pic("g20/" .. name .. ".png", r[1], r[2], r[3], r[4], m, alpha) end
end

-- a beetle: body (standing or crawling, legs and eyes moving on their own), its letter
function G:DrawScarab(s, gameM)
	local m = TL.Mul(gameM, rotM(s.mcRot, s.x, s.y, s.scale))
	local age = self.tick - (s.born or 0)
	local body = s.body == "stand" and 1 or 12
	TL.Draw(AN.G20Scarab, s.kind, {
		slot = function(name, bm)
			local base = slotName(name)
			local tl = base == "body1" and AN.G20Body1 or AN.G20Body2
			local eyes = base == "body1" and AN.G20Eyes1 or AN.G20Eyes2
			TL.Draw(tl, body, {
				slot = function(n2, lm)
					local b2 = slotName(n2)
					if b2 == "legA" then TL.Draw(AN.G20LegA, age % 9 + 1, nil, lm)
					elseif b2 == "legB" then TL.Draw(AN.G20LegB, age % 5 + 1, nil, lm)
					elseif b2 == "eyes" then
						local n = #eyes.frames
						TL.Draw(eyes, age % n + 1, nil, lm)
					end
				end,
			}, bm)
		end,
		value = function() return nil end,
	}, m)
	-- the letter, turned with the beetle (the "char" text field)
	local e = AN.G20Scarab.chars.e73
	local tm = TL.Mul(m, { 0, 1, -1, 0, 16.45, -32.5 })
	local cx, cy = TL.Apply(tm, e[3] + e[5] / 2, e[4] + e[6] / 2)
	TL.Text(s.char or "", "title", e[7] * 0.82, cx, cy, tm, Color(e[9], e[10], e[11]))
end

function G:DrawGame(gm)
	-- the engine clip: the shadows
	local em = TL.Mul(gm, { 1, 0, 0, 1, ENGINE[1], ENGINE[2] })
	for _, s in ipairs(self.scarabs) do
		pic("shadow", TL.Mul(em, rotM(s.shRot or 0, s.shX or s.x, s.shY or s.y, s.scale)), 0.3)
	end
	-- the type case with its holes
	local n = #self.curword
	TL.Draw(AN.G20Letters, n, {
		slot = function(name, hm)
			local _, inst = slotName(name)
			local h = self.holes[tonumber(string.match(inst or "", "l(%d+)")) or 0]
			TL.Draw(AN.G20Hole, 1, { value = function() return h and h.displayChar or "" end }, hm)
		end,
	}, gm)
	-- the beetles, on top
	for _, s in ipairs(self.scarabs) do self:DrawScarab(s, gm) end
	-- their buttons (the topmost beetle under the mouse wins)
	if self.gameState == "playgame" and not self.drag then
		UI.Button("g20_table", MG.X(0), MG.Y(0), MG.S(STAGE_W), MG.S(STAGE_H), nil, { silent = true, press = function()
			local mx, my = MG.Mouse()
			for i = #self.scarabs, 1, -1 do
				local s = self.scarabs[i]
				local bm = TL.Mul(TL.Mul(gm, rotM(s.mcRot, s.x, s.y, s.scale)), { 0, 0.78, -1.01, 0, -9.85, -0.25 })
				local im = inv(bm)
				if im then
					local lx, ly = TL.Apply(im, mx, my)
					local r = P.hit43
					if lx >= r[1] and lx <= r[1] + r[3] and ly >= r[2] and ly <= r[2] + r[4] then
						self:Pickup(i, mx - GAME_X, my)
						return
					end
				end
			end
		end })
	end
end

function G:DrawMessages(mm)
	if self.msgFrame == 1 then return end
	local en = AN.LangCode() ~= "da"
	TL.Draw(AN.G20Msg, self.msgFrame, {
		slot = function(name, bm)
			local base = slotName(name)
			local shape, fn
			if base == "btnNext" then
				shape = en and "btn108_notext" or "btn108"
				fn = function() self:NextLevelClick() end
			elseif base == "btnAgain" then
				shape, fn = "btn110", function() self:RestartGameClick() end
			elseif base == "btnContinue" then
				shape, fn = "btn115", function() self:Finish() end
			elseif base == "btnDone" then
				shape, fn = "btn110", function() self:Finish() end
			end
			if not shape then return end
			local r = P[shape]
			local hot = false
			-- the button: its plank's box, through its matrix
			local xs, ys = {}, {}
			for _, c in ipairs({ { r[1], r[2] }, { r[1] + r[3], r[2] }, { r[1], r[2] + r[4] }, { r[1] + r[3], r[2] + r[4] } }) do
				local x, y = TL.Apply(bm, c[1], c[2])
				xs[#xs + 1], ys[#ys + 1] = x, y
			end
			local x0, y0 = math.min(unpack(xs)), math.min(unpack(ys))
			local x1, y1 = math.max(unpack(xs)), math.max(unpack(ys))
			hot = UI.Button("g20_" .. base, MG.X(x0), MG.Y(y0), MG.S(x1 - x0), MG.S(y1 - y0), fn, { silent = true })
			local sm = bm
			if hot then sm = TL.Mul(bm, { 1.04, 0, 0, 1.04, 0, 0 }) end
			pic(shape, sm)
			if base == "btnNext" and en then
				local col = Color(255, 236, 200)
				local ax, ay = TL.Apply(sm, -14, -30)
				TL.Text(AN.L("g20_next1"), "title", 44, ax, ay, sm, col, 1, 200)
				ax, ay = TL.Apply(sm, -2, 12)
				TL.Text(AN.L("g20_next2"), "title", 44, ax, ay, sm, col, 1, 200)
				ax, ay = TL.Apply(sm, 50, 46)
				TL.Text(AN.L("g20_next3"), "title", 17, ax, ay, sm, col, 1, 120)
			end
		end,
	}, mm)
end

function G:Paint()
	MG.Stage(STAGE_W, STAGE_H)
	TL.Draw(AN.G20Root, 1, {
		slot = function(name, m)
			local base = slotName(name)
			if base == "game" then self:DrawGame(m) self:HintDraw(m)
			elseif base == "messages" then self:DrawMessages(m)
			elseif base == "fade" then
				if self.fadeF < 18 then TL.Draw(AN.G20Fade, self.fadeF, nil, m) end
			end
		end,
		value = function(var) return self.txt[var] end,
	})
	MG.DrawPops()
	MG.Chrome(20)
end

G.levels = #DIFF   -- every word is a level
AN.RegisterGame(20, G)
