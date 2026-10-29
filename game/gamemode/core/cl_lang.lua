-- Language: every string in the game lives in lang/da.lua and lang/en.lua.
-- AN.L("key", ...) returns the text in the chosen language, formatted with string.format.
AN = AN or {}
AN.Lang = AN.Lang or {}
local base = (GM or GAMEMODE).FolderName .. "/gamemode/"
AN.Lang.da = include(base .. "lang/da.lua")
AN.Lang.en = include(base .. "lang/en.lua")
include(base .. "lang/subs.lua")

function AN.LangCode()
	local l = AN.Save and AN.Save.Get("lang") or "da"
	if not AN.Lang[l] then l = "da" end
	return l
end

function AN.L(key, ...)
	local t = AN.Lang[AN.LangCode()]
	local s = t[key] or AN.Lang.da[key] or key
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		if ok then return out end
	end
	return s
end

function AN.GameName(n)
	if n > 100 and AN.Summer then return AN.Summer.Name(n) end
	return AN.L(string.format("game_%02d", n))
end
