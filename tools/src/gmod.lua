-- The Garry's Mod side of the website: the GMod functions the gamemode uses, made on top of the
-- browser. Drawing is collected into one string per frame (fields split by \1) that the
-- JavaScript side (gmod.js) draws on a canvas. Everything else (files, sound, text sizes)
-- asks JavaScript directly through the JS_* functions it provides.
local SEP = "\1"
local buf, nb = {}, 0
local concat, floor, fmt = table.concat, math.floor, string.format
local function put1(a) nb = nb + 1 buf[nb] = a end

-- (the Lua engine gives all functions a __tostring that only works for JavaScript functions)
do
	local raw = tostring
	local ids = setmetatable({}, { __mode = "k" })
	local n = 0
	function tostring(v)
		if type(v) == "function" then
			local ok, s = pcall(raw, v)
			if ok then return s end
			if not ids[v] then n = n + 1 ids[v] = n end
			return "function: #" .. ids[v]
		end
		return raw(v)
	end
end

SCRW, SCRH = 1920, 1080
MX, MY, MDOWN, MRDOWN = 0, 0, false, false
NOW, FT = 0, 1 / 60
function ScrW() return SCRW end
function ScrH() return SCRH end
function RealTime() return NOW end
function CurTime() return NOW end
function SysTime() return NOW end
function UnPredictedCurTime() return NOW end
function FrameTime() return FT end
CLIENT, SERVER = true, false

-- the key numbers of Garry's Mod (enum KEY_)
local KEYNAMES = {
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"PAD_0", "PAD_1", "PAD_2", "PAD_3", "PAD_4", "PAD_5", "PAD_6", "PAD_7", "PAD_8", "PAD_9",
	"PAD_DIVIDE", "PAD_MULTIPLY", "PAD_MINUS", "PAD_PLUS", "PAD_ENTER", "PAD_DECIMAL",
	"LBRACKET", "RBRACKET", "SEMICOLON", "APOSTROPHE", "BACKQUOTE", "COMMA", "PERIOD", "SLASH", "BACKSLASH", "MINUS", "EQUAL",
	"ENTER", "SPACE", "BACKSPACE", "TAB", "CAPSLOCK", "NUMLOCK", "ESCAPE", "SCROLLLOCK", "INSERT", "DELETE", "HOME", "END",
	"PAGEUP", "PAGEDOWN", "BREAK", "LSHIFT", "RSHIFT", "LALT", "RALT", "LCONTROL", "RCONTROL", "LWIN", "RWIN", "APP",
	"UP", "LEFT", "DOWN", "RIGHT",
	"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
}
for i, n in ipairs(KEYNAMES) do _G["KEY_" .. n] = i end
KEY_NONE = 0
MOUSE_LEFT, MOUSE_RIGHT, MOUSE_MIDDLE = 107, 108, 109
KEYS = {}
-- from the browser: a key went down or up
function WEB_KEY(code, down) KEYS[code] = down or nil end

-- colours
local ColorMT = {}
ColorMT.__index = ColorMT
function ColorMT:Unpack() return self.r, self.g, self.b, self.a end
function ColorMT.__eq(a, b) return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a end
function ColorMT.__tostring(c) return fmt("%d %d %d %d", c.r, c.g, c.b, c.a) end
function Color(r, g, b, a) return setmetatable({ r = r or 255, g = g or 255, b = b or 255, a = a or 255 }, ColorMT) end
function IsColor(c) return getmetatable(c) == ColorMT end
color_white = Color(255, 255, 255)
color_black = Color(0, 0, 0)
color_transparent = Color(255, 255, 255, 0)

-- the small GMod extras to the standard library
function istable(t) return type(t) == "table" end
function isstring(t) return type(t) == "string" end
function isnumber(t) return type(t) == "number" end
function isfunction(t) return type(t) == "function" end
function isbool(t) return type(t) == "boolean" end
function IsValid(x)
	if x == nil or x == false then return false end
	if type(x) == "table" then
		if x.__removed then return false end
		if x.IsValid and type(x.IsValid) == "function" and x.IsValid ~= IsValid then return x:IsValid() end
	end
	return true
end
function Lerp(t, a, b) return a + (b - a) * t end
function math.Clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
function math.Round(v, d) local m = 10 ^ (d or 0) return floor(v * m + 0.5) / m end
function math.Rand(a, b) return a + math.random() * (b - a) end
function math.Approach(c, t, inc) if c < t then return math.min(c + inc, t) end return math.max(c - inc, t) end
function math.Remap(v, a, b, c, d) return c + (d - c) * (v - a) / (b - a) end
function math.Distance(x1, y1, x2, y2) return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end
function table.Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
function table.Copy(t, seen)
	seen = seen or {}
	if seen[t] then return seen[t] end
	local o = {}
	seen[t] = o
	for k, v in pairs(t) do o[k] = type(v) == "table" and table.Copy(v, seen) or v end
	return setmetatable(o, getmetatable(t))
end
function table.HasValue(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
function table.Random(t) return t[math.random(#t)] end
function table.Shuffle(t) for i = #t, 2, -1 do local j = math.random(i) t[i], t[j] = t[j], t[i] end end
function table.RemoveByValue(t, v) for i, x in ipairs(t) do if x == v then table.remove(t, i) return i end end return false end
function table.GetKeys(t) local o = {} for k in pairs(t) do o[#o + 1] = k end return o end
function table.IsEmpty(t) return next(t) == nil end
function table.Add(a, b) for _, v in ipairs(b) do a[#a + 1] = v end return a end
function table.Merge(a, b) for k, v in pairs(b) do a[k] = v end return a end
table.unpack = table.unpack or unpack
function string.Split(s, sep)
	local o = {}
	if sep == "" then for c in s:gmatch(".") do o[#o + 1] = c end return o end
	local i = 1
	while true do
		local a, b = string.find(s, sep, i, true)
		if not a then o[#o + 1] = s:sub(i) break end
		o[#o + 1] = s:sub(i, a - 1)
		i = b + 1
	end
	return o
end
function string.Explode(sep, s, pat)
	if not pat then return string.Split(s, sep) end
	local o, i = {}, 1
	while true do
		local a, b = string.find(s, sep, i)
		if not a then o[#o + 1] = s:sub(i) break end
		o[#o + 1] = s:sub(i, a - 1)
		i = b + 1
	end
	return o
end
function string.Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function string.StartWith(s, p) return s:sub(1, #p) == p end
function string.EndsWith(s, p) return p == "" or s:sub(-#p) == p end
function string.StripExtension(s) return (string.gsub(s, "%.[^%.]*$", "")) end
function string.GetFileFromFilename(s) return s:match("([^/]*)$") end
function string.Replace(s, a, b) return (s:gsub(a:gsub("%p", "%%%0"), (b:gsub("%%", "%%%%")))) end
function string.Comma(n) local s = tostring(n) local k repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0 return s end
function ErrorNoHalt(...) JS_log("error", concat({ ... }, " ")) end
function ErrorNoHaltWithStack(...) JS_log("error", concat({ ... }, " ") .. "\n" .. debug.traceback()) end
function Msg(...) JS_log("log", concat({ ... }, "")) end
function MsgN(...) JS_log("log", concat({ ... }, "")) end
function MsgC(...) local o = {} for _, v in ipairs({ ... }) do if type(v) ~= "table" then o[#o + 1] = tostring(v) end end JS_log("log", concat(o, "")) end
function print(...) local o = {} for i = 1, select("#", ...) do o[#o + 1] = tostring((select(i, ...))) end JS_log("log", concat(o, "\t")) end
function PrintTable(t) print(t) end
function AddCSLuaFile() end
function DeriveGamemode() end
function Vector(x, y, z) return { x = x or 0, y = y or 0, z = z or 0 } end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end
function DisableClipping() return false end

-- the player: there is only one, on this computer
local ply = {}
function ply:IsValid() return true end
function ply:Nick() return JS_name() end
function ply:Name() return JS_name() end
function ply:SteamID64() return "76561190000000001" end
function ply:SteamID() return "STEAM_0:0:1" end
function ply:IsListenServerHost() return true end
function ply:IsSuperAdmin() return true end
function ply:IsAdmin() return true end
function ply:UserID() return 1 end
function ply:EntIndex() return 1 end
function LocalPlayer() return ply end
player = { GetCount = function() return 1 end, GetAll = function() return { ply } end, GetHumans = function() return { ply } end }
game = { SinglePlayer = function() return true end, MaxPlayers = function() return 1 end, GetMap = function() return "gm_flatgrass" end }
engine = { ActiveGamemode = function() return "alletidersnisse" end }
system = { IsWindows = function() return true end, HasFocus = function() return true end }

-- hooks and timers
hook = { hooks = {} }
function hook.Add(ev, id, fn) hook.hooks[ev] = hook.hooks[ev] or {} hook.hooks[ev][id] = fn end
function hook.Remove(ev, id) if hook.hooks[ev] then hook.hooks[ev][id] = nil end end
function hook.Run(ev, ...)
	for _, f in pairs(hook.hooks[ev] or {}) do
		local a, b = f(...)
		if a ~= nil then return a, b end
	end
	local gm = GAMEMODE and GAMEMODE[ev]
	if gm then return gm(GAMEMODE, ...) end
end
hook.Call = function(ev, gm, ...) return hook.Run(ev, ...) end
local timers, simple = {}, {}
timer = {}
function timer.Create(id, delay, reps, fn) timers[id] = { delay = delay, reps = reps, fn = fn, at = NOW + delay, n = 0 } end
function timer.Remove(id) timers[id] = nil end
function timer.Exists(id) return timers[id] ~= nil end
function timer.Simple(delay, fn) simple[#simple + 1] = { at = NOW + delay, fn = fn } end
local function runTimers()
	for id, t in pairs(timers) do
		if NOW >= t.at then
			t.n = t.n + 1
			t.at = NOW + t.delay
			local ok, e = pcall(t.fn)
			if not ok then ErrorNoHalt(e) end
			if t.reps > 0 and t.n >= t.reps then timers[id] = nil end
		end
	end
	if #simple > 0 then
		local due = {}
		for i = #simple, 1, -1 do if NOW >= simple[i].at then due[#due + 1] = table.remove(simple, i) end end
		for i = #due, 1, -1 do local ok, e = pcall(due[i].fn) if not ok then ErrorNoHalt(e) end end
	end
end
concommand = { Add = function() end }
function RunConsoleCommand(cmd, ...)
	if cmd == "disconnect" then JS_quit() end
end
cvars = { AddChangeCallback = function() end }
function GetConVar() return { GetInt = function() return 0 end, GetBool = function() return false end, GetString = function() return "" end, GetFloat = function() return 0 end } end
function CreateClientConVar() return GetConVar() end

-- JSON (util.TableToJSON / util.JSONToTable)
local json = {}
do
	local esc = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
	local function str(s) return '"' .. s:gsub('[%c"\\]', function(c) return esc[c] or fmt("\\u%04x", c:byte()) end) .. '"' end
	local function num(n)
		if n ~= n or n == math.huge or n == -math.huge then return "0" end
		if n == floor(n) and math.abs(n) < 1e15 then return fmt("%d", n) end
		return fmt("%.17g", n)
	end
	local function isArray(t)
		local n = 0
		for k in pairs(t) do
			if type(k) ~= "number" or k < 1 or k ~= floor(k) then return false end
			n = n + 1
		end
		for i = 1, n do if t[i] == nil then return false end end
		return true, n
	end
	local enc
	function enc(v, out)
		local tv = type(v)
		if tv == "table" then
			local arr, n = isArray(v)
			if arr and n > 0 then
				out[#out + 1] = "["
				for i = 1, n do
					if i > 1 then out[#out + 1] = "," end
					enc(v[i], out)
				end
				out[#out + 1] = "]"
			else
				out[#out + 1] = "{"
				local first = true
				for k, x in pairs(v) do
					local tx = type(x)
					if tx ~= "function" and tx ~= "userdata" then
						if not first then out[#out + 1] = "," end
						first = false
						out[#out + 1] = str(tostring(k))
						out[#out + 1] = ":"
						enc(x, out)
					end
				end
				out[#out + 1] = "}"
			end
		elseif tv == "string" then out[#out + 1] = str(v)
		elseif tv == "number" then out[#out + 1] = num(v)
		elseif tv == "boolean" then out[#out + 1] = v and "true" or "false"
		else out[#out + 1] = "null" end
	end
	function json.encode(v) local out = {} enc(v, out) return concat(out) end
	local function utf8c(cp)
		if cp < 0x80 then return string.char(cp) end
		if cp < 0x800 then return string.char(0xC0 + floor(cp / 64), 0x80 + cp % 64) end
		return string.char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
	end
	function json.decode(s)
		local i = 1
		local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
		local val
		function val()
			ws()
			local c = s:sub(i, i)
			if c == "{" then
				i = i + 1
				local t = {}
				ws()
				if s:sub(i, i) == "}" then i = i + 1 return t end
				while true do
					ws()
					local k = val()
					ws()
					i = i + 1 -- :
					local v = val()
					-- keys that are whole numbers become numbers, like GMod does
					local nk = tonumber(k)
					if nk and tostring(nk) == k then k = nk end
					t[k] = v
					ws()
					local d = s:sub(i, i)
					i = i + 1
					if d == "}" then return t end
				end
			elseif c == "[" then
				i = i + 1
				local t = {}
				ws()
				if s:sub(i, i) == "]" then i = i + 1 return t end
				while true do
					t[#t + 1] = val()
					ws()
					local d = s:sub(i, i)
					i = i + 1
					if d == "]" then return t end
				end
			elseif c == '"' then
				local o = {}
				i = i + 1
				while true do
					local a = s:find('["\\]', i)
					o[#o + 1] = s:sub(i, a - 1)
					if s:sub(a, a) == '"' then i = a + 1 break end
					local e = s:sub(a + 1, a + 1)
					if e == "u" then
						o[#o + 1] = utf8c(tonumber(s:sub(a + 2, a + 5), 16))
						i = a + 6
					else
						o[#o + 1] = ({ b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" })[e] or e
						i = a + 2
					end
				end
				return concat(o)
			elseif s:sub(i, i + 3) == "true" then i = i + 4 return true
			elseif s:sub(i, i + 4) == "false" then i = i + 5 return false
			elseif s:sub(i, i + 3) == "null" then i = i + 4 return nil
			else
				local a, b = s:find("^-?[%d%.eE%+%-]+", i)
				i = b + 1
				return tonumber(s:sub(a, b))
			end
		end
		local ok, r = pcall(val)
		if ok then return r end
	end
end
util = {}
function util.AddNetworkString() end
function util.TableToJSON(t) return json.encode(t) end
function util.JSONToTable(s) if not s or s == "" then return nil end return json.decode(s) end
function util.Compress(s) return s end
function util.Decompress(s) return s end
function util.CRC(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return tostring(h) end

-- net: the server half runs in the same Lua; messages are handed over at once
net = {}
NET_SIDE = "client"
local RECV = { client = {}, server = {} }
local out, rd = nil, {}
function net.Receive(name, fn) RECV[NET_SIDE][name] = fn end
function net.Start(name) out = { name = name, v = {} } end
local function w(x) out.v[#out.v + 1] = x end
net.WriteString, net.WriteBool, net.WriteFloat, net.WriteTable, net.WriteEntity = w, w, w, w, w
net.WriteUInt = function(x) w(x) end
net.WriteInt = function(x) w(x) end
net.WriteData = function(x) w(x) end
local function r() local m = rd[#rd] m.i = m.i + 1 return m.v[m.i] end
net.ReadString, net.ReadBool, net.ReadUInt, net.ReadInt, net.ReadData, net.ReadFloat, net.ReadTable, net.ReadEntity = r, r, r, r, r, r, r, r
local function deliver(side, msg)
	local fn = RECV[side][msg.name]
	if not fn then return end
	rd[#rd + 1] = { v = msg.v, i = 0 }
	local ok, e = pcall(fn, 0, ply)
	rd[#rd] = nil
	if not ok then ErrorNoHalt(e) end
end
function net.SendToServer() local m = out deliver("server", m) end
function net.Send() local m = out deliver("client", m) end
function net.Broadcast() local m = out deliver("client", m) end
function net.SendOmit() end

-- files: kept in the browser (localStorage), under data/
file = {}
function file.Exists(p, where)
	if where == "LUA" then return JS_luaexists(p) end
	return JS_fileread(p) ~= nil
end
function file.Read(p, where)
	if where == "LUA" then return JS_luasrc(p) end
	return JS_fileread(p)
end
function file.Write(p, s) JS_filewrite(p, s) end
function file.Append(p, s) JS_filewrite(p, (JS_fileread(p) or "") .. s) end
function file.Delete(p) JS_filedelete(p) end
function file.IsDir() return true end
function file.CreateDir() end
function file.Time() return 0 end
local function split(s) local o = {} if s and s ~= "" then for x in (s .. SEP):gmatch("(.-)" .. SEP) do o[#o + 1] = x end end return o end
function file.Find(pat, where)
	if where == "LUA" then return split(JS_luafind(pat)), {} end
	return split(JS_filefind(pat)), {}
end

-- input
input = {}
function input.GetCursorPos() return MX, MY end
function input.IsMouseDown(b) if b == MOUSE_LEFT then return MDOWN end if b == MOUSE_RIGHT then return MRDOWN end return false end
function input.IsKeyDown(k) return KEYS[k] == true end
function input.IsShiftDown() return KEYS[KEY_LSHIFT] == true or KEYS[KEY_RSHIFT] == true end
function input.IsControlDown() return KEYS[KEY_LCONTROL] == true or KEYS[KEY_RCONTROL] == true end
gui = {}
function gui.EnableScreenClicker() end
function gui.MousePos() return MX, MY end
function gui.OpenURL(u) JS_openurl(u) end
function gui.IsGameUIVisible() return false end

-- sound: channels played by the browser
local CH = {}
local chans = {}
CH.__index = CH
function CH:IsValid() return not self.dead end
function CH:Play() JS_snd(self.id, "play", 0) end
function CH:Pause() JS_snd(self.id, "pause", 0) end
function CH:Stop() JS_snd(self.id, "stop", 0) self.dead = true chans[self.id] = nil end
function CH:SetVolume(v) JS_snd(self.id, "volume", v) end
function CH:EnableLooping(b) JS_snd(self.id, "loop", b and 1 or 0) end
function CH:SetPlaybackRate(r) JS_snd(self.id, "rate", r) end
function CH:SetTime(t) JS_snd(self.id, "time", t) end
function CH:GetTime() return JS_snd(self.id, "gettime", 0) or 0 end
function CH:GetLength() return JS_snd(self.id, "length", 0) or 0 end
function CH:GetState() return JS_snd(self.id, "state", 0) or 0 end
function CH:GetVolume() return JS_snd(self.id, "getvolume", 0) or 1 end
GMOD_CHANNEL_STOPPED, GMOD_CHANNEL_PLAYING, GMOD_CHANNEL_PAUSED, GMOD_CHANNEL_STALLED = 0, 1, 2, 3
local pending = {}
sound = {}
function sound.PlayFile(path, flags, cb)
	local id = JS_sndopen(path, flags or "")
	pending[id] = cb or false
end
-- from the browser: a sound has loaded (or failed)
function WEB_SOUND(id, ok)
	local cb = pending[id]
	pending[id] = nil
	if ok then
		local ch = setmetatable({ id = id }, CH)
		chans[id] = ch
		if cb then
			local good, e = pcall(cb, ch, 0, "")
			if not good then ErrorNoHalt(e) end
		else
			ch:Play()
		end
	elseif cb then
		pcall(cb, nil, 2, "not found")
	end
end
function WEB_SOUNDEND(id) local ch = chans[id] if ch then chans[id] = nil end end
function surface_sound() end

-- materials: the size of the picture file (from the website's list), drawn by the browser
local MatMT = {}
MatMT.__index = MatMT
function MatMT:Width() return self.w end
function MatMT:Height() return self.h end
function MatMT:IsError() return self.err end
function MatMT:GetName() return self.path end
function MatMT:GetTexture() return self end
function MatMT:SetFloat() end
function MatMT:SetVector() end
function MatMT:SetTexture() end
function Material(path, flags)
	local wh = JS_imgsize(path) or 0
	local w, h = floor(wh / 65536), wh % 65536
	return setmetatable({ path = path, w = w, h = h, err = (w == 0) }, MatMT)
end

-- drawing
surface = {}
local cr, cg, cb, ca = 255, 255, 255, 255
local tr, tg, tb, ta = 255, 255, 255, 255
local curMat, curFont, tx, ty = "", nil, 0, 0
local fonts = {}
function surface.CreateFont(name, t)
	fonts[name] = t
	JS_font(name, t.font or "Nunito ExtraBold", t.size or 13, t.weight or 500)
end
function surface.SetDrawColor(r, g, b, a)
	if type(r) == "table" then cr, cg, cb, ca = r.r, r.g, r.b, r.a or 255
	else cr, cg, cb, ca = r, g, b, a or 255 end
end
function surface.GetDrawColor() return Color(cr, cg, cb, ca) end
function surface.SetMaterial(m) curMat = m and m.path or "" end
function surface.SetTexture() curMat = "" end
function surface.GetTextureID(p) return 0 end
local function col() put1(cr) put1(cg) put1(cb) put1(ca) end
function surface.DrawRect(x, y, w, h) put1("R") put1(x) put1(y) put1(w) put1(h) col() end
function surface.DrawOutlinedRect(x, y, w, h, t)
	t = t or 1
	surface.DrawRect(x, y, w, t) surface.DrawRect(x, y + h - t, w, t)
	surface.DrawRect(x, y + t, t, h - 2 * t) surface.DrawRect(x + w - t, y + t, t, h - 2 * t)
end
function surface.DrawLine(a, b, c, d) put1("L") put1(a) put1(b) put1(c) put1(d) col() end
function surface.DrawTexturedRect(x, y, w, h)
	put1("T") put1(curMat) put1(x) put1(y) put1(w) put1(h) col() put1(0) put1(0) put1(1) put1(1)
end
function surface.DrawTexturedRectUV(x, y, w, h, u0, v0, u1, v1)
	put1("T") put1(curMat) put1(x) put1(y) put1(w) put1(h) col() put1(u0) put1(v0) put1(u1) put1(v1)
end
function surface.DrawTexturedRectRotated(x, y, w, h, rot)
	put1("O") put1(curMat) put1(x) put1(y) put1(w) put1(h) col() put1(rot or 0)
end
function surface.DrawPoly(p)
	put1("P") put1(curMat) col() put1(#p)
	for i = 1, #p do local v = p[i] put1(v.x) put1(v.y) put1(v.u or 0) put1(v.v or 0) end
end
function surface.SetFont(f) curFont = f end
function surface.GetFont() return curFont end
local tsize = {}
function surface.GetTextSize(s)
	s = tostring(s)
	local c = tsize[curFont]
	if not c then c = {} tsize[curFont] = c end
	local r = c[s]
	if not r then
		local wh = JS_textsize(curFont or "", s) or 0
		r = { floor(wh / 65536), wh % 65536 }
		c[s] = r
	end
	return r[1], r[2]
end
function surface.SetTextColor(r, g, b, a)
	if type(r) == "table" then tr, tg, tb, ta = r.r, r.g, r.b, r.a or 255
	else tr, tg, tb, ta = r, g, b, a or 255 end
end
function surface.SetTextPos(x, y) tx, ty = x, y end
function surface.GetTextPos() return tx, ty end
function surface.DrawText(s)
	s = tostring(s)
	put1("X") put1(curFont or "") put1(tx) put1(ty) put1(tr) put1(tg) put1(tb) put1(ta) put1(s)
	tx = tx + (surface.GetTextSize(s))
end
function surface.PlaySound(s) JS_sndopen("sound/" .. s, "auto") end
function surface.ScreenWidth() return SCRW end
function surface.ScreenHeight() return SCRH end
draw = {}
function draw.NoTexture() curMat = "" end
local function rbox(r, x, y, w, h, c, a, b, d, e)
	put1("B") put1(r) put1(x) put1(y) put1(w) put1(h) put1(c.r) put1(c.g) put1(c.b) put1(c.a or 255)
	put1(a and 1 or 0) put1(b and 1 or 0) put1(d and 1 or 0) put1(e and 1 or 0)
end
function draw.RoundedBox(r, x, y, w, h, c) rbox(r, x, y, w, h, c, true, true, true, true) end
function draw.RoundedBoxEx(r, x, y, w, h, c, a, b, d, e) rbox(r, x, y, w, h, c, a, b, d, e) end
TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, TEXT_ALIGN_BOTTOM = 0, 1, 2, 3, 4
function draw.SimpleText(s, font, x, y, c, ax, ay)
	s = tostring(s)
	surface.SetFont(font or "DermaDefault")
	local w, h = surface.GetTextSize(s)
	if ax == 1 then x = x - w / 2 elseif ax == 2 then x = x - w end
	if ay == 1 then y = y - h / 2 elseif ay == 4 then y = y - h end
	surface.SetTextColor(c or color_white)
	surface.SetTextPos(x, y)
	surface.DrawText(s)
	return w, h
end
function draw.DrawText(s, font, x, y, c, ax) return draw.SimpleText(s, font, x, y, c, ax) end
surface.CreateFont("DermaDefault", { font = "Nunito ExtraBold", size = 14 })

-- 2D matrices for cam.PushModelMatrix (translate, rotate round the z axis, scale)
local MM = {}
MM.__index = MM
function Matrix() return setmetatable({ a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0 }, MM) end
local function mul(m, a, b, c, d, x, y)
	m.a, m.b, m.c, m.d, m.tx, m.ty = m.a * a + m.c * b, m.b * a + m.d * b, m.a * c + m.c * d, m.b * c + m.d * d,
		m.a * x + m.c * y + m.tx, m.b * x + m.d * y + m.ty
end
function MM:Translate(v) mul(self, 1, 0, 0, 1, v.x, v.y) end
function MM:Rotate(an) local r = math.rad(an.y or 0) mul(self, math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0) end
function MM:Scale(v) mul(self, v.x, 0, 0, v.y, 0, 0) end
function MM:SetTranslation(v) self.tx, self.ty = v.x, v.y end
function MM:GetTranslation() return Vector(self.tx, self.ty, 0) end
cam = {}
local mstack = {}
function cam.PushModelMatrix(m, mult)
	local t = { m.a, m.b, m.c, m.d, m.tx, m.ty }
	local top = mstack[#mstack]
	if mult and top then
		local A = { a = top[1], b = top[2], c = top[3], d = top[4], tx = top[5], ty = top[6] }
		mul(A, m.a, m.b, m.c, m.d, m.tx, m.ty)
		t = { A.a, A.b, A.c, A.d, A.tx, A.ty }
	end
	mstack[#mstack + 1] = t
	put1("M") for i = 1, 6 do put1(t[i]) end
end
function cam.PopModelMatrix()
	mstack[#mstack] = nil
	local t = mstack[#mstack]
	if t then put1("M") for i = 1, 6 do put1(t[i]) end else put1("m") end
end
function cam.Start2D() end
function cam.End2D() end
render = {}
function render.SetScissorRect(a, b, c, d, on) put1("S") put1(a) put1(b) put1(c) put1(d) put1(on and 1 or 0) end
function render.PushFilterMag() end
function render.PushFilterMin() end
function render.PopFilterMag() end
function render.PopFilterMin() end
function render.ClearStencil() end
function render.SetStencilEnable() end
TEXFILTER = { NONE = 0, POINT = 1, LINEAR = 2, ANISOTROPIC = 3 }

-- panels: the gamemode makes one fullscreen DPanel; the browser sends it the mouse
vgui = {}
local PanelMT = {}
local noop = function() end
PanelMT.__index = function(t, k)
	local v = rawget(PanelMT, k)
	if v ~= nil then return v end
	-- panel methods we don't need do nothing; the panel's own hooks (Paint, Think, On...) and
	-- fields are only there when the gamemode sets them
	if type(k) == "string" and k:match("^[A-Z]") and not k:match("^On") and k ~= "Paint" and k ~= "Think" then return noop end
	return nil
end
function PanelMT:SetPos(x, y) self.x, self.y = x, y end
function PanelMT:SetSize(w, h) self.w, self.h = w, h end
function PanelMT:GetWide() return self.w end
function PanelMT:GetTall() return self.h end
function PanelMT:GetSize() return self.w, self.h end
function PanelMT:Remove() self.__removed = true if ROOT == self then ROOT = nil end end
function PanelMT:IsValid() return not self.__removed end
function PanelMT:IsVisible() return self.visible ~= false end
function PanelMT:SetVisible(b) self.visible = b end
ROOT = nil
function vgui.Create(cls, parent)
	local p = setmetatable({ w = 0, h = 0, x = 0, y = 0, cls = cls }, PanelMT)
	if cls == "DPanel" and not parent then ROOT = p end
	return p
end
function vgui.GetKeyboardFocus() return nil end
function vgui.GetHoveredPanel() return ROOT end
function vgui.CursorVisible() return true end

-- loading the gamemode's Lua files (the website has them all)
GM = { FolderName = "alletidersnisse", Name = "Alletiders Nisse" }
GAMEMODE = GM
local incDir = {}
function include(path)
	-- like GMod: relative to the including file's folder, else from the gamemode folder
	local cands = {}
	local d = incDir[#incDir]
	if d then cands[#cands + 1] = d .. path end
	cands[#cands + 1] = "alletidersnisse/gamemode/" .. path
	cands[#cands + 1] = path
	for _, p in ipairs(cands) do
		local src = JS_luasrc(p)
		if src then
			local f, err = loadstring(src, "@" .. p)
			if not f then error(err, 2) end
			incDir[#incDir + 1] = p:match("^(.*/)") or ""
			local res = { pcall(f) }
			incDir[#incDir] = nil
			if not res[1] then error(res[2], 0) end
			return unpack(res, 2)
		end
	end
	error("include: not found: " .. path, 2)
end

-- utf8 (GMod has it; Lua 5.1 does not)
utf8 = {}
do
	local function seqlen(b) if b < 0x80 then return 1 elseif b < 0xE0 then return 2 elseif b < 0xF0 then return 3 end return 4 end
	function utf8.codes(s)
		local i = 1
		return function()
			if i > #s then return nil end
			local b = s:byte(i)
			local n = seqlen(b)
			local cp = b
			if n == 2 then cp = (b % 0x20) * 64 + s:byte(i + 1) % 64
			elseif n == 3 then cp = (b % 0x10) * 4096 + (s:byte(i + 1) % 64) * 64 + s:byte(i + 2) % 64
			elseif n == 4 then cp = (b % 0x08) * 262144 + (s:byte(i + 1) % 64) * 4096 + (s:byte(i + 2) % 64) * 64 + s:byte(i + 3) % 64 end
			local p = i
			i = i + n
			return p, cp
		end
	end
	function utf8.char(...)
		local o = {}
		for _, cp in ipairs({ ... }) do
			if cp < 0x80 then o[#o + 1] = string.char(cp)
			elseif cp < 0x800 then o[#o + 1] = string.char(0xC0 + floor(cp / 64), 0x80 + cp % 64)
			elseif cp < 0x10000 then o[#o + 1] = string.char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
			else o[#o + 1] = string.char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64) end
		end
		return concat(o)
	end
	function utf8.len(s) local n = 0 for _ in utf8.codes(s) do n = n + 1 end return n end
	function utf8.offset(s, n) local k = 0 for p in utf8.codes(s) do k = k + 1 if k == n then return p end end return #s + 1 end
	function utf8.codepoint(s, i) i = i or 1 for p, cp in utf8.codes(s:sub(i)) do return cp end end
	utf8.charpattern = "[%z\1-\127\194-\244][\128-\191]*"
end

---------------------------------------------------------------------------
-- starting, and one frame
---------------------------------------------------------------------------
local function report(e) JS_log("error", tostring(e) .. "\n" .. debug.traceback()) end

function WEB_START(w, h)
	SCRW, SCRH = w, h
	include("cl_init.lua")
	NET_SIDE = "server"
	include("core/sv_save.lua")
	include("core/sv_versus.lua")
	NET_SIDE = "client"
	if GM.Initialize then GM:Initialize() end
	hook.Run("Initialize")
	GM:InitPostEntity()
end

function WEB_RESIZE(w, h)
	if w == SCRW and h == SCRH then return end
	local ow, oh = SCRW, SCRH
	SCRW, SCRH = w, h
	hook.Run("OnScreenSizeChanged", ow, oh)
end

-- the mouse buttons and wheel, from the browser
function WEB_MOUSE(code, down)
	if code == MOUSE_LEFT then MDOWN = down else MRDOWN = down end
	if ROOT and not rawget(ROOT, "__removed") then
		local fn = down and ROOT.OnMousePressed or ROOT.OnMouseReleased
		if fn then local ok, e = xpcall(function() fn(ROOT, code) end, report) end
	end
end
function WEB_WHEEL(d)
	if ROOT and ROOT.OnMouseWheeled then xpcall(function() ROOT:OnMouseWheeled(d) end, report) end
end

local function frame()
	runTimers()
	if ROOT and ROOT.Think then ROOT:Think() end
	hook.Run("Think")
	if ROOT and ROOT.Paint and ROOT.visible ~= false then ROOT:Paint(ROOT.w, ROOT.h) end
end
function WEB_FRAME(now, ft, mx, my)
	NOW, FT, MX, MY = now, ft, mx, my
	nb = 0
	mstack = {}
	xpcall(frame, report)
	return concat(buf, SEP, 1, nb)
end

-- for the touch controls: which game is being played ("game:<n>" or "split:<n>"), and the language
function WEB_STATE()
	local ui = AN and AN.UI
	local name = ui and ui.screenName or ""
	local st = ""
	local n = name:match("^game(%d+)$")
	if n then st = "game:" .. n
	elseif name == "vssplit" and ui.screen and ui.screen.n then st = "split:" .. ui.screen.n end
	local lang = AN and AN.Save and AN.Save.Get("lang") or "da"
	return st .. "|" .. tostring(lang)
end

-- the language chosen on the website's start page
function WEB_SETLANG(l)
	if not (AN and AN.Save) then return end
	if AN.Save.Get("lang") ~= l then
		AN.Save.Set("lang", l)
		if AN.UI and AN.UI.screenName == "main" then AN.UI.Open("main") end
	end
end
