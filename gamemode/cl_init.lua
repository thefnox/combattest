DEFINE_BASECLASS( "gamemode_base" )

include( "shared.lua" )
include( "player.lua" )


local hideHUD = {
	CHudAmmo = true,
	CHudDeathNotice = true,
	CHudSecondaryAmmo = true
}

net.Receive("SetPlayerLock", function()
	local ply = net.ReadEntity()
	if (net.ReadBool()) then
		ply.__MoveLimitOrigin = net.ReadVector()
	else
		ply.__MoveLimitOrigin = nil
	end
end)

net.Receive("SetPlayerFrozen", function()
	local ply = net.ReadEntity()
	ply.__MoveLocked = net.ReadBool()
end)

net.Receive("SetPlayerAllowedToFire", function()
	local ply = net.ReadEntity()
	ply.__NotAllowedToFire = net.ReadBool()
end)

net.Receive("SetPlayerCanEndCombat", function()
	local ply = net.ReadEntity()
	ply.__CanEndCombat = net.ReadBool()
end)

net.Receive("SetAttacking", function()
	local ply = LocalPlayer()
	ply.__Attacking = net.ReadTable()
end)

net.Receive("SetDefending", function()
	local ply = LocalPlayer()
	ply.__Attackers = net.ReadTable()
end)

net.Receive("SetPlayerDefeated", function()
	local ply = net.ReadEntity()
	local dead = net.ReadBool()
	ply.__Defeated = dead
	if (dead) then
		ply.__TimeDefeated = net.ReadDouble()
		ply.__DefeatedBy = net.ReadEntity()
	end
end)


function GM:HUDShouldDraw(name)
	if (hideHUD[name]) then return false end
	return true
end

function GM:CalcView(ply, pos, ang, fov, znear, zfar)
	local view = {}

	view.origin = pos-( ang:Forward()*100 + ang:Right() * 10 )
	view.angles = ang
	view.fov = fov
	view.znear = znear
	view.zfar = zfar
	view.drawviewer = true

	return view
end

function GM:PostDrawTranslucentRenderables( depth, skybox )
	if (LocalPlayer().__MoveLimitOrigin) then
		render.DrawWireframeSphere(LocalPlayer().__MoveLimitOrigin, __CombatRules.BaseMoveDistance, 36, 36, Color(255, 0, 0, 100), true)
	end
end