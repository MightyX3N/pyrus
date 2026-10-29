-- Plays back an original Flash timeline exported by timeline_export.py (stage coordinates, drawn
-- through the minigame stage). Pictures, texts in the player's language, dynamic text fields, and
-- "slots" the game code draws itself (anything a script moves or animates).
AN = AN or {}
AN.TL = AN.TL or {}
local TL = AN.TL
local MG = AN.MG

-- the draw colour for a picture: white (or the Flash player's tint) with the alpha
function TL.SetColor(alpha)
	local t = AN.FL and AN.FL.tint
	if t then
		surface.SetDrawColor(255 * t[1], 255 * t[2], 255 * t[3], 255 * (alpha or 1))
	else
		surface.SetDrawColor(255, 255, 255, 255 * (alpha or 1))
	end
end

-- a picture placed by a matrix without rotation (a, d may be negative = mirrored), optionally clipped
-- to a stage rectangle
function TL.Pic(path, x, y, w, h, m, alpha, clip, uv)
	local a, b, c, d, tx, ty = m[1], m[2], m[3], m[4], m[5], m[6]
	local x0, x1 = a * x + tx, a * (x + w) + tx
	local y0, y1 = d * y + ty, d * (y + h) + ty
	local u0, u1, v0, v1 = 0, 1, 0, 1
	if uv then u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4] end
	if x1 < x0 then x0, x1 = x1, x0; u0, u1 = u1, u0 end
	if y1 < y0 then y0, y1 = y1, y0; v0, v1 = v1, v0 end
	if clip then
		local cx0, cy0, cx1, cy1 = clip[1], clip[2], clip[3], clip[4]
		if x1 <= cx0 or x0 >= cx1 or y1 <= cy0 or y0 >= cy1 then return end
		local W, H = x1 - x0, y1 - y0
		local nx0, nx1 = math.max(x0, cx0), math.min(x1, cx1)
		local ny0, ny1 = math.max(y0, cy0), math.min(y1, cy1)
		local du, dv = u1 - u0, v1 - v0
		u0, u1 = u0 + du * (nx0 - x0) / W, u0 + du * (nx1 - x0) / W
		v0, v1 = v0 + dv * (ny0 - y0) / H, v0 + dv * (ny1 - y0) / H
		x0, x1, y0, y1 = nx0, nx1, ny0, ny1
	end
	if math.abs(b) > 0.001 or math.abs(c) > 0.001 then
		-- turned (or skewed / mirrored and turned): the four corners through the matrix (no clipping)
		uv = uv or { 0, 0, 1, 1 }
		local function pt(px, py, u, v)
			return { x = AN.PX(MG.X(a * px + c * py + tx)), y = AN.SY(MG.Y(b * px + d * py + ty)), u = u, v = v }
		end
		local ua, va, ub, vb = uv[1], uv[2], uv[3], uv[4]
		local p = { pt(x, y, ua, va), pt(x + w, y, ub, va), pt(x + w, y + h, ub, vb), pt(x, y + h, ua, vb) }
		if a * d - b * c < 0 then p = { p[4], p[3], p[2], p[1] } end
		TL.SetColor(alpha)
		surface.SetMaterial(AN.Mat(path))
		surface.DrawPoly(p)
		return
	end
	if math.abs(b) > 0.001 or math.abs(c) > 0.001 then
		-- turned: draw around the middle (no clipping)
		local mx, my = (x + w / 2), (y + h / 2)
		local cx, cy = a * mx + c * my + tx, b * mx + d * my + ty
		local sx, sy = math.sqrt(a * a + b * b), math.sqrt(c * c + d * d)
		TL.SetColor(alpha)
		surface.SetMaterial(AN.Mat(path))
		surface.DrawTexturedRectRotated(AN.PX(MG.X(cx)), AN.SY(MG.Y(cy)), AN.SX(MG.S(w * sx)), AN.SX(MG.S(h * sy)), -math.deg(math.atan2(b, a)))
		return
	end
	TL.SetColor(alpha)
	surface.SetMaterial(AN.Mat(path))
	local px, py = AN.PX(MG.X(x0)), AN.SY(MG.Y(y0))
	surface.DrawTexturedRectUV(px, py, AN.PX(MG.X(x1)) - px, AN.SY(MG.Y(y1)) - py, u0, v0, u1, v1)
end

-- text centred on a stage point, turned and scaled by a matrix (like a Flash text placement)
function TL.Text(str, face, em, cx, cy, m, col, alpha, maxW, leftAnchor)
	local a, b = m and m[1] or 1, m and m[2] or 0
	local s = math.sqrt(a * a + b * b)
	local ang = math.deg(math.atan2(b, a))
	local f = AN.Font(face, math.max(6, math.floor(MG.S(em))))
	surface.SetFont(f)
	local tw, th = surface.GetTextSize(str)
	-- a translation that is longer than the original is made smaller to fit
	if maxW then
		local lim = AN.SX(MG.S(maxW))
		if tw * s > lim then s = lim / tw end
	end
	local sx, sy = AN.PX(MG.X(cx)), AN.SY(MG.Y(cy))
	surface.SetTextColor(col.r, col.g, col.b, 255 * (alpha or 1))
	local ax = leftAnchor == "right" and tw or (leftAnchor and 0 or tw / 2)
	if math.abs(ang) < 0.05 and math.abs(s - 1) < 0.01 then
		surface.SetTextPos(math.floor(sx - ax), math.floor(sy - th / 2))
		surface.DrawText(str)
		return
	end
	local mt = Matrix()
	mt:Translate(Vector(sx, sy, 0))
	mt:Rotate(Angle(0, ang, 0))
	mt:Scale(Vector(s, s, 1))
	-- (the panel's clipping is tested before the matrix: text left of / above the origin would be cut off)
	local was = DisableClipping(true)
	cam.PushModelMatrix(mt, true)
	surface.SetTextPos(math.floor(-ax), math.floor(-th / 2))
	surface.DrawText(str)
	cam.PopModelMatrix()
	DisableClipping(was)
end

local function apply(m, x, y)
	return m[1] * x + m[3] * y + m[5], m[2] * x + m[4] * y + m[6]
end
TL.Apply = apply

-- draw one frame. hooks.slot(name, m, alpha), hooks.value(var) -> string, hooks.text(key) -> string (optional)
-- parent: an optional matrix the whole timeline is placed with (a sprite inside the stage)
function TL.Mul(P, C)
	return { P[1] * C[1] + P[3] * C[2], P[2] * C[1] + P[4] * C[2], P[1] * C[3] + P[3] * C[4], P[2] * C[3] + P[4] * C[4],
		P[1] * C[5] + P[3] * C[6] + P[5], P[2] * C[5] + P[4] * C[6] + P[6] }
end

function TL.Draw(tl, frame, hooks, parent)
	local items = tl.frames[frame]
	if not items then return end
	hooks = hooks or {}
	for _, it in ipairs(items) do
		local key = it[1]
		local m = { it[2], it[3], it[4], it[5], it[6], it[7] }
		if parent then m = TL.Mul(parent, m) end
		local alpha = it[8]
		local clip = it[9] and { it[9], it[10], it[11], it[12] } or nil
		if clip and parent then clip = { clip[1] * parent[1] + parent[5], clip[2] * parent[4] + parent[6], clip[3] * parent[1] + parent[5], clip[4] * parent[4] + parent[6] } end
		if alpha > 0.004 then
			if string.sub(key, 1, 5) == "slot:" then
				if hooks.slot then hooks.slot(string.sub(key, 6), m, alpha) end
			else
				local ch = tl.chars[key]
				if ch and hooks.item then hooks.item(key, m, ch) end
				if ch then
					local kind = ch[1]
					if kind == "img" then
						TL.Pic(ch[2], ch[3], ch[4], ch[5], ch[6], m, alpha, clip)
					elseif kind == "text" then
						local str = hooks.text and hooks.text(ch[2]) or AN.L(ch[2])
						local col = Color(ch[6], ch[7], ch[8])
						if (ch[11] or 1) > 1 or string.find(str, "\n", 1, true) then
							-- several lines: spaced like the original, left aligned or centred
							local lines = string.Explode("\n", str)
							local lh = ch[10] or ch[5]
							for i, line in ipairs(lines) do
								local ly = ch[4] + (i - (#lines + 1) / 2) * lh
								local lx = ch[12] == 0 and ch[9] or ch[3]
								local px, py = apply(m, lx, ly)
								TL.Text(line, "title", ch[5], px, py, m, col, alpha, (MG.sw or 400) - 10, ch[12] == 0)
							end
						else
							local cx, cy = apply(m, ch[3], ch[4])
							TL.Text(str, "title", ch[5], cx, cy, m, col, alpha, (MG.sw or 400) - 10)
						end
					elseif kind == "dyn" then
						local v = hooks.value and hooks.value(ch[2])
						if v and v ~= "" then
							-- the text box (x, y, w, h), font size, align (0 left, 1 right, 2 centre)
							local s = math.sqrt(m[1] * m[1] + m[2] * m[2])
							local al = ch[8]
							local ax = al == 1 and (ch[3] + ch[5] - 2) or (al == 2 and (ch[3] + ch[5] / 2) or (ch[3] + 2))
							local px, py = apply(m, ax, ch[4] + 2)
							local f = AN.Font("title", math.max(6, math.floor(MG.S(ch[7] * s))))
							surface.SetFont(f)
							local tw = surface.GetTextSize(v)
							local sx = AN.PX(MG.X(px))
							if al == 1 then sx = sx - tw elseif al == 2 then sx = sx - tw / 2 end
							surface.SetTextColor(ch[9], ch[10], ch[11], 255 * alpha)
							surface.SetTextPos(math.floor(sx), math.floor(AN.SY(MG.Y(py))))
							surface.DrawText(v)
						end
					end
				end
			end
		end
	end
end

-- one frame of an animation exported with "trim" (anim_export.py), origin at (ox, oy) in stage
-- coordinates, scaled by k (default 1)
function TL.Cell(group, idx, ox, oy, alpha, k)
	local fr = group.frames[idx]
	if not fr then return end
	k = k or 1
	local at = group.atlases[fr[1]]
	local sc = group.scale
	TL.SetColor(alpha)
	surface.SetMaterial(AN.Mat(at[1]))
	local x, y = ox + fr[6] * k, oy + fr[7] * k
	local px, py = AN.PX(MG.X(x)), AN.SY(MG.Y(y))
	local px1, py1 = AN.PX(MG.X(x + fr[4] / sc * k)), AN.SY(MG.Y(y + fr[5] / sc * k))
	surface.DrawTexturedRectUV(px, py, px1 - px, py1 - py, fr[2] / at[2], fr[3] / at[3], (fr[2] + fr[4]) / at[2], (fr[3] + fr[5]) / at[3])
end

-- the same, placed by a matrix (mirrored / scaled)
function TL.CellM(group, idx, m, alpha, clip)
	local fr = group.frames[idx]
	if not fr then return end
	local at = group.atlases[fr[1]]
	local sc = group.scale
	TL.Pic(at[1], fr[6], fr[7], fr[4] / sc, fr[5] / sc, m, alpha, clip,
		{ fr[2] / at[2], fr[3] / at[3], (fr[2] + fr[4]) / at[2], (fr[3] + fr[5]) / at[3] })
end

-- the texts that belong to an animation frame (drawn by the game, in the player's language)
function TL.CellTexts(group, anim, f, ox, oy, alpha, col, k)
	local t = group.texts and group.texts[anim] and group.texts[anim][f]
	if not t then return end
	k = k or 1
	for _, x in ipairs(t) do
		local m = { x[4] * k, x[5] * k, x[6] * k, x[7] * k, 0, 0 }
		TL.Text(AN.L(x[1]), "title", x[8], ox + x[2] * k, oy + x[3] * k, m, col or Color(102, 0, 51), (alpha or 1) * x[9])
	end
end
