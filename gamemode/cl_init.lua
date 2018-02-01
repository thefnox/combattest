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

net.Receive("SetTurnQueue", function()
	local ply = LocalPlayer()
	ply.__TurnQueue = net.ReadTable()
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

function GM:ScalePlayerDamage(ply, hitgroup, dmginfo)
	return true
end

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

local rt_Store = render.GetScreenEffectTexture( 0 )
local lockedMat = Material("playerlocked.png", "mips noclamp smooth")
hook.Add("PreDrawEffects", "DrawBlackOutline", function( depth, skybox )
	local rt_Scene = render.GetRenderTarget()
	render.CopyRenderTargetToTexture( rt_Store )
	cam.Start3D()
		render.SetStencilEnable( true )
			render.SuppressEngineLighting(true)
				render.SetStencilWriteMask( 1 )
				render.SetStencilTestMask( 1 )
				render.SetStencilReferenceValue( 1 )

				render.SetStencilCompareFunction( STENCIL_ALWAYS )
				render.SetStencilPassOperation( STENCIL_REPLACE )
				render.SetStencilFailOperation( STENCIL_KEEP )
				render.SetStencilZFailOperation( STENCIL_KEEP )
				for _, ply in pairs(player.GetAll()) do
					if (ply:IsMoveLocked() and !ply:IsAllowedToFire()) then
						ply:DrawModel()
					end
				end
			render.SuppressEngineLighting(false)
		render.SetStencilEnable( false )
	cam.End3D()

	render.SetRenderTarget( rt_Scene )

	render.SetStencilEnable( true )
		render.SetStencilCompareFunction( STENCIL_EQUAL )
		render.SetMaterial( lockedMat )
		render.DrawScreenQuad()
	render.SetStencilEnable( false )

	render.SetStencilTestMask( 0 )
	render.SetStencilWriteMask( 0 )
	render.SetStencilReferenceValue( 0 )
end)

hook.Add("HUDPaint", "CombatHUD", function()
	if (LocalPlayer():PopTurnQueue() == LocalPlayer()) then
		draw.SimpleTextOutlined("Your turn!", "DermaLarge", ScrW()/2, 10, Color(50, 205, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0, 100))
		if (LocalPlayer():IsMoveLocked() and !LocalPlayer():IsAllowedToFire()) then
			draw.SimpleTextOutlined("You must emote to end your turn", "DermaLarge", ScrW()/2, 45, Color(50, 205, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0, 100))
		end
	end
	if (LocalPlayer():IsDefeated()) then
		draw.SimpleTextOutlined("DEFEATED", "DermaLarge", ScrW()/2, 10, Color(178, 34, 34), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0, 100))
	end

	if (#LocalPlayer():GetTurnQueue() > 0) then
		draw.SimpleTextOutlined("Turn Queue: ", "Trebuchet24", 10, 10, Color(255, 248, 22), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, Color(0,0,0, 244))
		for k, v in ipairs(LocalPlayer():GetTurnQueue()) do
			draw.SimpleTextOutlined(v:GetName(), "Trebuchet24", 10, 10 + k * 26, Color(255, 248, 22), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 3, Color(0,0,0, 244))
		end
	end
end)