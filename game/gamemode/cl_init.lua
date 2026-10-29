include("shared.lua")

include("core/cl_imgsizes.lua")
include("core/cl_wraplayout.lua")
include("core/cl_util.lua")
include("core/cl_lang.lua")
include("core/sh_progress.lua")
include("core/cl_save.lua")
include("core/cl_voicelist.lua")
include("core/cl_audio.lua")
include("core/cl_orncaps.lua")
include("core/cl_deco.lua")
include("core/cl_ui.lua")
include("core/cl_games.lua")
include("core/cl_minigame.lua")
include("core/cl_timeline.lua")
include("core/cl_flash.lua")

include("screens/cl_main.lua")
include("screens/cl_kalender.lua")
include("screens/cl_pyntekasse.lua")
include("screens/cl_gamewrap.lua")
include("screens/cl_saesoner.lua")
include("screens/cl_scrapbog.lua")
include("screens/cl_indstillinger.lua")
include("screens/cl_profil.lua")
include("screens/cl_classic.lua")
include("screens/cl_tv2.lua")
include("screens/cl_classicopts.lua")
include("core/cl_versus.lua")
include("core/cl_split.lua")
include("core/cl_summer.lua")

local gameFiles = file.Find(GM.FolderName .. "/gamemode/games/*.lua", "LUA")
for _, f in ipairs(gameFiles or {}) do include("games/" .. f) end

-- The whole game lives in a fullscreen panel; the 3D world behind it is never seen.
function GM:HUDShouldDraw(name) return false end
function GM:HUDDrawTargetID() end
function GM:HUDDrawPickupHistory() end
function GM:DrawDeathNotice() end
function GM:PlayerBindPress(ply, bind, pressed)
	-- block movement, chat-free keys etc. while the menu is up; Escape still opens GMod's own menu
	if string.find(bind, "messagemode") then return false end
	return true
end

function GM:InitPostEntity()
	AN.Save.Load()
	AN.UpdateScale()
	AN.UI.Start()
end

concommand.Add("an_menu", function() AN.UI.Start() end)
