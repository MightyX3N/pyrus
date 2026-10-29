-- Pyrus' voice and the menu music, working like the original sound modules.
--   AN.Speak(id)      plays one of the lines for that id (random if there are several),
--                     stopping whatever Pyrus was saying (like pyrusspeak.stopAllSound + playSound)
--   AN.StopSpeech()
--   AN.SoundMode()    0 = all on, 1 = music off, 2 = everything muted (the original Lyd button)
AN = AN or {}
AN.Audio = AN.Audio or {}
local A = AN.Audio

function AN.SoundMode() return (AN.Save and AN.Save.Get("soundmode")) or 0 end

---------------------------------------------------------------------------
-- Voice
---------------------------------------------------------------------------
A.speechId = nil
A.speechCh = nil
A.speechReq = 0

function AN.StopSpeech()
	A.queue = nil
	A.speechLoading = false
	A.speechReq = A.speechReq + 1
	if IsValid(A.speechCh) then A.speechCh:Stop() end
	A.speechCh = nil
	A.speechId = nil
end

function AN.Speak(id, onlyIfQuiet)
	id = string.lower(id)
	local list = AN.VoiceList and AN.VoiceList[id]
	if not list then return end
	if onlyIfQuiet and AN.IsSpeaking() then return end
	AN.StopSpeech()
	if AN.SoundMode() == 2 then return end
	local file = list[math.random(#list)]
	local vol = (AN.Save.Get("vol_voice") or 100) / 100
	if vol <= 0 then return end
	local req = A.speechReq
	A.speechId = id
	A.speechLoading = true
	sound.PlayFile("sound/alletidersnisse/voice/" .. file .. ".mp3", "noplay", function(ch)
		if req == A.speechReq then A.speechLoading = false end
		if not IsValid(ch) then return end
		if req ~= A.speechReq then ch:Stop() return end   -- something else was said meanwhile
		ch:SetVolume(vol)
		ch:Play()
		A.speechCh = ch
	end)
	if AN.ShowSubtitle then AN.ShowSubtitle(file) end
end

---------------------------------------------------------------------------
-- Subtitles: what the line says, at the bottom of the screen while it plays (setting "subs").
-- The texts are in AN.Subs[lang][file] (lang/subs.lua), written down from the original recordings.
---------------------------------------------------------------------------
AN.Subs = AN.Subs or { da = {}, en = {} }
function AN.SubText(file)
	local lang = AN.LangCode and AN.LangCode() or "da"
	local t = AN.Subs[lang] and AN.Subs[lang][file]
	if (not t or t == "") and lang ~= "da" then t = AN.Subs.da[file] end
	return t
end
function AN.ShowSubtitle(file)
	A.sub = { file = file, t = RealTime() }
end
function AN.DrawSubtitle()
	local s = A.sub
	if not s or not AN.Save.Get("subs") then return end
	local txt = AN.SubText(s.file)
	if not txt or txt == "" then return end
	-- shown while the line plays (and a moment after); at most 12 s if the sound never starts
	local playing = A.speechLoading or (IsValid(A.speechCh) and A.speechCh:GetState() == GMOD_CHANNEL_PLAYING)
	if playing then s.last = RealTime() end
	local since = RealTime() - (s.last or s.t)
	if since > 0.6 or RealTime() - s.t > 30 then return end
	local a = math.Clamp((0.6 - since) / 0.3, 0, 1)
	local maxw = math.min(1300, AN.VW - 160)
	local lines = AN.Wrap(txt, "bold", 30, maxw)
	local w = 0
	for _, l in ipairs(lines) do w = math.max(w, AN.TextSize(l, "bold", 30)) end
	local h = #lines * 40 + 24
	local x, y = AN.VW / 2 - w / 2 - 28, AN.VH - (AN.OY or 0) - 70 - h
	AN.Box(x, y, w + 56, h, Color(0, 0, 0, 170 * a), 14)
	for i, l in ipairs(lines) do
		AN.Text(l, "bold", 30, AN.VW / 2, y + 12 + (i - 1) * 40 + 20, Color(255, 255, 255, 255 * a), 1, 1)
	end
end

-- say several lines one after the other (e.g. a game's intro, then how it is played)
function AN.SpeakChain(ids)
	AN.Speak(ids[1])
	local rest = {}
	for i = 2, #ids do rest[#rest + 1] = ids[i] end
	A.queue = #rest > 0 and rest or nil
end

-- is Pyrus saying something, or about to (a chain still has lines left)?
function AN.VoiceBusy()
	return A.speechLoading or AN.IsSpeaking() or (A.queue ~= nil)
end

function AN.IsSpeaking(id)
	if not IsValid(A.speechCh) then return false end
	if A.speechCh:GetState() ~= GMOD_CHANNEL_PLAYING then return false end
	return id == nil or A.speechId == string.lower(id)
end

---------------------------------------------------------------------------
-- Music: one of the three songs, a new random one each time it ends
---------------------------------------------------------------------------
local SONGS = { "sig_ikke_mere", "glad_i_bad", "drillerigtighed" }
A.musicCh = nil
A.musicWanted = false

-- a season's screens play its song over and over: the summer "Glad i bad" (the bath song),
-- Halloween "Drillerigtighed"
local function summerNow()
	local scr, name = AN.UI and AN.UI.screen, AN.UI and AN.UI.screenName or ""
	local SU = AN.Summer
	if not SU or not SU.SEASONS then return false end
	if scr and scr.season and SU.SEASONS[scr.season] then return SU.SEASONS[scr.season].song end
	local n = scr and scr.n or 0
	if (name == "sgame" or n > 100) and SU.BY[n] then return SU.SEASONS[SU.SeasonOf(n)].song end
	if name == "sgame" or n > 100 then return "glad_i_bad" end
	return false
end
A.summer = false
local function playSong()
	A.summer = summerNow()
	local song = A.summer or SONGS[math.random(#SONGS)]
	A.loadingSong = true
	sound.PlayFile("sound/alletidersnisse/music/" .. song .. ".mp3", "noplay", function(ch)
		A.loadingSong = false
		if not IsValid(ch) then return end
		if not A.musicWanted or AN.SoundMode() ~= 0 then ch:Stop() return end
		ch:SetVolume((AN.Save.Get("vol_music") or 70) / 100 * 0.6)
		ch:Play()
		A.musicCh = ch
	end)
end

function AN.MusicOn()
	A.musicWanted = true
end

function AN.MusicOff()
	A.musicWanted = false
	if IsValid(A.musicCh) then A.musicCh:Stop() end
	A.musicCh = nil
end

hook.Add("Think", "AN_SpeechQueue", function()
	if not A.queue or A.speechLoading or AN.IsSpeaking() then return end
	local nxt = table.remove(A.queue, 1)
	if #A.queue == 0 then A.queue = nil end
	local q = A.queue
	AN.Speak(nxt)
	A.queue = q
end)

hook.Add("Think", "AN_Music", function()
	local want = A.musicWanted and AN.SoundMode() == 0
	if not want then
		if IsValid(A.musicCh) then A.musicCh:Stop() A.musicCh = nil end
		return
	end
	if A.loadingSong then return end
	if not IsValid(A.musicCh) or A.musicCh:GetState() == GMOD_CHANNEL_STOPPED then
		playSong()
	else
		A.musicCh:SetVolume((AN.Save.Get("vol_music") or 70) / 100 * 0.6)
		-- into or out of the summer: change the song
		if summerNow() ~= A.summer then A.musicCh:Stop() A.musicCh = nil end
	end
	-- mute everything in mode 2
	if IsValid(A.speechCh) and AN.SoundMode() == 2 then A.speechCh:Stop() end
end)

-- the Lyd button cycles: all on -> music off -> mute -> all on
function AN.CycleSoundMode()
	local m = (AN.SoundMode() + 1) % 3
	AN.Save.Set("soundmode", m)
	if m == 2 then AN.StopSpeech() end
end
