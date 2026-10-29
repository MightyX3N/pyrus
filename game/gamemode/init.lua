AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

local clientFiles = {
	"core/cl_imgsizes.lua", "core/cl_wraplayout.lua", "screens/cl_gamewrap.lua", "core/cl_util.lua", "core/cl_lang.lua", "core/cl_save.lua", "core/sh_progress.lua", "screens/cl_profil.lua", "core/cl_voicelist.lua", "core/cl_audio.lua", "core/cl_orncaps.lua", "core/cl_deco.lua", "core/cl_ui.lua", "core/cl_games.lua", "core/cl_minigame.lua", "core/cl_timeline.lua", "core/cl_flash.lua",
	"lang/da.lua", "lang/en.lua", "lang/subs.lua",
	"screens/cl_main.lua", "screens/cl_kalender.lua", "screens/cl_pyntekasse.lua",
	"screens/cl_saesoner.lua", "screens/cl_scrapbog.lua", "screens/cl_indstillinger.lua", "screens/cl_classic.lua", "screens/cl_tv2.lua", "screens/cl_classicopts.lua", "core/cl_versus.lua", "core/cl_split.lua", "core/cl_summer.lua",
}
for _, f in ipairs(clientFiles) do AddCSLuaFile(f) end

local gameFiles = file.Find(GM.FolderName .. "/gamemode/games/*.lua", "LUA")
for _, f in ipairs(gameFiles or {}) do AddCSLuaFile("games/" .. f) end
local dataFiles = file.Find(GM.FolderName .. "/gamemode/games/data/*.lua", "LUA")
for _, f in ipairs(dataFiles or {}) do AddCSLuaFile("games/data/" .. f) end

include("shared.lua")
include("core/sh_progress.lua")
include("core/sv_save.lua")
include("core/sv_versus.lua")

-- Send the gamemode's own content (materials, sounds, fonts) to clients on a server.
local function addContent(dir)
	local files, dirs = file.Find("gamemodes/" .. GM.FolderName .. "/content/" .. dir .. "/*", "GAME")
	for _, f in ipairs(files or {}) do resource.AddSingleFile(dir .. "/" .. f) end
	for _, d in ipairs(dirs or {}) do addContent(dir .. "/" .. d) end
end
addContent("materials/alletidersnisse")
addContent("sound/alletidersnisse")
addContent("resource/fonts")

-- The game is played entirely in a fullscreen 2D menu, so the player just idles in the map.
function GM:PlayerLoadout(ply) return true end

function GM:PlayerSpawn(ply)
	player_manager.SetPlayerClass(ply, "player_default")
	ply:SetMoveType(MOVETYPE_NONE)
	ply:SetNoDraw(true)
	ply:DrawShadow(false)
	ply:Freeze(true)
end

function GM:PlayerShouldTakeDamage() return false end
function GM:CanPlayerSuicide() return false end
