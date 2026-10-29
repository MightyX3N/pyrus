-- Scaling, fonts, colours, images, drawing helpers and sounds.
-- All layout is written in a virtual 1920x1080 space (like the design canvas).
-- S is the scale to real pixels; VW is the virtual width (wider than 1920 on 21:9).
-- Things that sit on the right side of a screen add AN.R (extra width) to their x.

AN = AN or {}

AN.Col = {
	cream   = Color(255, 241, 207),
	gold    = Color(255, 215, 106),
	sand    = Color(217, 194, 154),
	wheat   = Color(233, 214, 178),
	white   = Color(255, 255, 255),
	dark    = Color(20, 8, 2),
	brown   = Color(59, 26, 8),
	red     = Color(200, 32, 45),
	redDark = Color(125, 15, 23),
	shadow  = Color(90, 29, 4),
	bad     = Color(224, 90, 90),
	badText = Color(255, 176, 168),
}

local function rgba(c, a) return Color(c.r, c.g, c.b, a) end
AN.Alpha = rgba

function AN.UpdateScale()
	local sw, sh = ScrW(), ScrH()
	AN.S = math.min(sh / 1080, sw / 1920)
	AN.VW = sw / AN.S
	AN.VH = sh / AN.S
	AN.OX = 0
	-- One layout for every screen: designed at 1920 x 1080 and scaled by height.
	-- On wider screens the extra width is split: things anchored to the screen edges
	-- (menu panel, corner buttons) stay at the edges, and the scene content is anchored
	-- to the centre with AN.C, so nothing gets pulled apart. Backgrounds fill the width.
	AN.R = math.max(0, AN.VW - 1920)    -- extra width beyond 16:9
	AN.C = AN.R / 2                     -- shift for centre-anchored content
	AN.OY = (AN.VH - 1080) / 2          -- vertical centring on 4:3 / 16:10
	AN.FontCache = AN.FontCache or {}
end
AN.UpdateScale()

hook.Add("OnScreenSizeChanged", "AN_Scale", function() AN.UpdateScale() end)

-- virtual -> screen
local function SX(v) return math.floor(v * AN.S + 0.5) end           -- sizes
local function PX(v) return math.floor((v + AN.OX) * AN.S + 0.5) end  -- x positions
local function SY(v) return math.floor((v + AN.OY) * AN.S + 0.5) end
AN.SX, AN.SY, AN.PX = SX, SY, PX

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------
-- face: "title" (Spumoni), "bold" (Nunito ExtraBold), "black" (Nunito Black)
local faces = {
	title = "Spumoni LP",
	bold  = "Nunito ExtraBold",
	black = "Nunito Black",
}

function AN.Font(face, size)
	local key = face .. size .. ":" .. ScrH()
	local name = AN.FontCache[key]
	if name then return name end
	name = "AN_" .. face .. "_" .. size .. "_" .. ScrH()
	surface.CreateFont(name, {
		font = faces[face] or faces.bold,
		size = math.max(8, math.floor(size * AN.S + 0.5)),
		weight = 800,
		antialias = true,
		extended = true,
	})
	AN.FontCache[key] = name
	return name
end

---------------------------------------------------------------------------
-- Images
---------------------------------------------------------------------------
local mats = {}
function AN.Mat(path)
	local m = mats[path]
	if not m then
		m = Material("alletidersnisse/" .. path, "smooth mips")
		mats[path] = m
	end
	return m
end

-- natural aspect ratio (height / width) of a material
function AN.Ratio(path)
	local real = AN.ImgSize and AN.ImgSize[path]
	if real then return real[2] / real[1] end
	local m = AN.Mat(path)
	local w, h = m:Width(), m:Height()
	if w <= 0 then return 1 end
	return h / w
end

-- draw image by width (height from aspect) or explicit w,h
function AN.Img(path, x, y, w, h, alpha, col)
	local m = AN.Mat(path)
	h = h or w * AN.Ratio(path)
	local c = col or color_white
	surface.SetDrawColor(c.r, c.g, c.b, alpha or 255)
	surface.SetMaterial(m)
	surface.DrawTexturedRect(PX(x), SY(y), SX(w), SX(h))
	return h
end

-- image fitted inside a box, centred, keeping aspect
function AN.ImgFit(path, x, y, w, h, alpha)
	local r = AN.Ratio(path)
	local iw, ih = w, w * r
	if ih > h then ih = h; iw = h / r end
	AN.Img(path, x + (w - iw) / 2, y + (h - ih) / 2, iw, ih, alpha)
end

-- image cropped to cover a box (like object-fit: cover)
function AN.ImgCover(path, x, y, w, h, alpha)
	local m = AN.Mat(path)
	local r = AN.Ratio(path)
	local boxR = h / w
	local u0, v0, u1, v1 = 0, 0, 1, 1
	if r > boxR then
		local vis = boxR / r
		v0 = (1 - vis) / 2; v1 = 1 - v0
	else
		local vis = r / boxR
		u0 = (1 - vis) / 2; u1 = 1 - u0
	end
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.SetMaterial(m)
	surface.DrawTexturedRectUV(PX(x), SY(y), SX(w), SX(h), u0, v0, u1, v1)
end

function AN.ImgRotated(path, cx, cy, w, h, deg, alpha)
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.SetMaterial(AN.Mat(path))
	surface.DrawTexturedRectRotated(PX(cx), SY(cy), SX(w), SX(h), deg)
end

-- Soft "blur" for images GMod can't filter: draw the image several times
-- in a small ring with low alpha. radius in virtual px.
function AN.ImgSoft(path, x, y, w, h, radius, alpha, col)
	alpha = alpha or 255
	local n = 8
	local a = math.min(255, alpha * 0.32)
	for i = 0, n - 1 do
		local ang = i / n * math.pi * 2
		AN.Img(path, x + math.cos(ang) * radius, y + math.sin(ang) * radius, w, h, a, col)
	end
	AN.Img(path, x, y, w, h, alpha * 0.25, col)
end

---------------------------------------------------------------------------
-- Shapes
---------------------------------------------------------------------------
function AN.Box(x, y, w, h, col, radius)
	draw.RoundedBox(SX(radius or 0), PX(x), SY(y), SX(w), SX(h), col)
end

function AN.BoxEx(x, y, w, h, col, radius, tl, tr, bl, br)
	draw.RoundedBoxEx(SX(radius or 0), PX(x), SY(y), SX(w), SX(h), col, tl, tr, bl, br)
end

-- rounded outline: border colour box, then inner fill (or the background colour)
function AN.Outline(x, y, w, h, col, radius, thick, inner)
	thick = thick or 2
	radius = radius or 0
	local sx, sy, sw, sh, t = PX(x), SY(y), SX(w), SX(h), math.max(1, SX(thick))
	if inner then
		draw.RoundedBox(SX(radius), sx, sy, sw, sh, col)
		draw.RoundedBox(math.max(0, SX(radius) - t), sx + t, sy + t, sw - t * 2, sh - t * 2, inner)
	else
		-- transparent inside: draw the four edges with rounded caps approximated
		local r = SX(radius)
		surface.SetDrawColor(col)
		surface.DrawRect(sx + r, sy, sw - r * 2, t)
		surface.DrawRect(sx + r, sy + sh - t, sw - r * 2, t)
		surface.DrawRect(sx, sy + r, t, sh - r * 2)
		surface.DrawRect(sx + sw - t, sy + r, t, sh - r * 2)
		if r > 0 then
			local seg = 10
			local function arc(cx, cy, a0)
				for i = 0, seg - 1 do
					local a1 = a0 + (i / seg) * math.pi / 2
					local a2 = a0 + ((i + 1) / seg) * math.pi / 2
					for k = 0, t - 1 do
						local rr = r - k
						surface.DrawLine(cx + math.cos(a1) * rr, cy + math.sin(a1) * rr, cx + math.cos(a2) * rr, cy + math.sin(a2) * rr)
					end
				end
			end
			arc(sx + r, sy + r, math.pi)
			arc(sx + sw - r - 1, sy + r, math.pi * 1.5)
			arc(sx + sw - r - 1, sy + sh - r - 1, 0)
			arc(sx + r, sy + sh - r - 1, math.pi * 0.5)
		end
	end
end

-- own gradient textures so the direction is certain:
-- grad_l: opaque on the left, clear on the right. grad_d: clear at the top, opaque at the bottom.
local gradL = Material("alletidersnisse/ui/grad_l.png", "smooth")
local gradD = Material("alletidersnisse/ui/grad_d.png", "smooth")

-- horizontal fade: colour at alpha a0 on the left to a1 on the right (one draw, linear alpha).
-- grad_l alpha is 1 - u, so drawing u in [0, 1 - a1/a0] with alpha a0 gives a0 -> a1.
function AN.HGrad(x, y, w, h, col, a0, a1)
	local sx, sy, sw, sh = PX(x), SY(y), SX(w), SX(h)
	if a0 == a1 then
		surface.SetDrawColor(col.r, col.g, col.b, a0)
		surface.DrawRect(sx, sy, sw, sh)
		return
	end
	local hi = math.max(a0, a1)
	local k = math.min(a0, a1) / hi
	surface.SetDrawColor(col.r, col.g, col.b, hi)
	surface.SetMaterial(gradL)
	if a0 > a1 then
		surface.DrawTexturedRectUV(sx, sy, sw, sh, 0, 0, 1 - k, 1)
	else
		surface.DrawTexturedRectUV(sx, sy, sw, sh, 1 - k, 0, 0, 1)
	end
end

-- vertical fade: alpha a0 at the top to a1 at the bottom. grad_d alpha is v.
function AN.VGrad(x, y, w, h, col, a0, a1)
	local sx, sy, sw, sh = PX(x), SY(y), SX(w), SX(h)
	if a0 == a1 then
		surface.SetDrawColor(col.r, col.g, col.b, a0)
		surface.DrawRect(sx, sy, sw, sh)
		return
	end
	local hi = math.max(a0, a1)
	local k = math.min(a0, a1) / hi
	surface.SetDrawColor(col.r, col.g, col.b, hi)
	surface.SetMaterial(gradD)
	if a1 > a0 then
		surface.DrawTexturedRectUV(sx, sy, sw, sh, 0, k, 1, 1)
	else
		surface.DrawTexturedRectUV(sx, sy, sw, sh, 0, 1, 1, k)
	end
end

-- two-colour vertical gradient
function AN.VGrad2(x, y, w, h, c1, c2)
	AN.Box(x, y, w, h, c1)
	local sx, sy, sw, sh = PX(x), SY(y), SX(w), SX(h)
	surface.SetDrawColor(c2.r, c2.g, c2.b, c2.a or 255)
	surface.SetMaterial(gradD)
	surface.DrawTexturedRect(sx, sy, sw, sh)
end

-- filled circle
local circleCache = {}
function AN.Circle(cx, cy, r, col)
	local sx, sy, sr = PX(cx), SY(cy), SX(r)
	local key = sx .. ":" .. sy .. ":" .. sr
	local poly = circleCache[key]
	if not poly then
		poly = {}
		local seg = math.Clamp(math.floor(sr / 2), 16, 64)
		for i = 0, seg - 1 do
			local a = i / seg * math.pi * 2
			poly[#poly + 1] = { x = sx + math.cos(a) * sr, y = sy + math.sin(a) * sr }
		end
		circleCache[key] = poly
		if table.Count(circleCache) > 400 then circleCache = {} end
	end
	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly(poly)
end

-- soft round glow (radial gradient texture)
function AN.Glow(cx, cy, r, col, strength)
	strength = strength or 1
	surface.SetDrawColor(col.r, col.g, col.b, math.Clamp((col.a or 255) * 0.55 * strength, 0, 255))
	surface.SetMaterial(AN.Mat("ui/radial.png"))
	surface.DrawTexturedRect(PX(cx - r), SY(cy - r), SX(r * 2), SX(r * 2))
end

-- soft ellipse shadow under objects
function AN.Shadow(x, y, w, h, a)
	surface.SetDrawColor(15, 5, 0, a or 150)
	surface.SetMaterial(AN.Mat("ui/radial.png"))
	surface.DrawTexturedRect(PX(x - w * 0.15), SY(y - h * 0.3), SX(w * 1.3), SX(h * 1.6))
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
-- align: 0 left, 1 centre, 2 right ; valign: 0 top, 1 centre
function AN.Text(str, face, size, x, y, col, align, valign, alpha)
	local f = AN.Font(face, size)
	surface.SetFont(f)
	local tw, th = surface.GetTextSize(str)
	local sx, sy = PX(x), SY(y)
	if align == 1 then sx = sx - tw / 2 elseif align == 2 then sx = sx - tw end
	if valign == 1 then sy = sy - th / 2 end
	surface.SetTextColor(col.r, col.g, col.b, alpha or col.a or 255)
	surface.SetTextPos(math.floor(sx), math.floor(sy))
	surface.DrawText(str)
	return tw / AN.S, th / AN.S
end

-- text with a hard drop shadow (like text-shadow: 0 6px 0 colour)
function AN.TextShadow(str, face, size, x, y, col, shadowCol, off, align)
	AN.Text(str, face, size, x, y + (off or 5), shadowCol, align)
	return AN.Text(str, face, size, x, y, col, align)
end

function AN.TextSize(str, face, size)
	surface.SetFont(AN.Font(face, size))
	local w, h = surface.GetTextSize(str)
	return w / AN.S, h / AN.S
end

-- word-wrap to a virtual width, returns list of lines
function AN.Wrap(str, face, size, maxw)
	surface.SetFont(AN.Font(face, size))
	local lines = {}
	for para in string.gmatch(str .. "\n", "(.-)\n") do
		local line = ""
		for word in string.gmatch(para, "%S+") do
			local test = line == "" and word or (line .. " " .. word)
			local w = surface.GetTextSize(test) / AN.S
			if w > maxw and line ~= "" then
				lines[#lines + 1] = line
				line = word
			else
				line = test
			end
		end
		lines[#lines + 1] = line
	end
	return lines
end

-- draws wrapped text, returns total height
function AN.TextWrap(str, face, size, x, y, maxw, col, lineH, align)
	local lines = AN.Wrap(str, face, size, maxw)
	lineH = lineH or size * 1.45
	for i, l in ipairs(lines) do
		local lx = x
		if align == 1 then lx = x + maxw / 2 elseif align == 2 then lx = x + maxw end
		AN.Text(l, face, size, lx, y + (i - 1) * lineH, col, align)
	end
	return #lines * lineH
end

-- text shrunk to fit a width
function AN.TextFit(str, face, size, x, y, maxw, col, align, valign)
	local s = size
	while s > 10 do
		local w = AN.TextSize(str, face, s)
		if w <= maxw then break end
		s = s - 2
	end
	return AN.Text(str, face, s, x, y, col, align, valign)
end

-- a single line cut to a width with "..." (player names)
function AN.TextEllipsis(str, face, size, x, y, maxw, col, align, valign)
	str = tostring(str or "")
	if AN.TextSize(str, face, size) > maxw then
		local n = utf8 and utf8.len(str) or #str
		while n > 1 do
			n = n - 1
			local cut = utf8 and utf8.offset and string.sub(str, 1, (utf8.offset(str, n + 1) or (#str + 1)) - 1) or string.sub(str, 1, n)
			local test = cut .. "..."
			if AN.TextSize(test, face, size) <= maxw then str = test break end
		end
	end
	return AN.Text(str, face, size, x, y, col, align, valign)
end

-- the small mark next to a result that was helped by a hint
function AN.HintMark(cx, cy, r)
	AN.Circle(cx, cy, r, Color(214, 150, 30))
	AN.Circle(cx, cy, r * 0.78, Color(255, 215, 106))
	AN.Text("?", "black", math.max(8, math.floor(r * 1.5)), cx, cy, Color(90, 40, 8), 1, 1)
end

---------------------------------------------------------------------------
-- Sounds
---------------------------------------------------------------------------
function AN.Sound(name)
	local vol = (AN.Save and AN.Save.Get("vol_fx") or 85) / 100
	if vol <= 0 then return end
	if AN.SoundMode and AN.SoundMode() == 2 then return end
	sound.PlayFile("sound/alletidersnisse/ui/" .. name .. ".mp3", "noplay", function(ch)
		if IsValid(ch) then ch:SetVolume(vol) ch:Play() end
	end)
end

function AN.FormatTime(sec)
	sec = math.max(0, math.floor(sec + 0.5))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- upper-case that also handles æ ø å é
function AN.Upper(str)
	str = string.upper(str)
	str = string.gsub(str, "æ", "Æ")
	str = string.gsub(str, "ø", "Ø")
	str = string.gsub(str, "å", "Å")
	str = string.gsub(str, "é", "É")
	return str
end
