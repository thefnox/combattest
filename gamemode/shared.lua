DEFINE_BASECLASS( "gamemode_base" )

GM.Name 	= "Combat Test"
GM.Author 	= "fnox"
GM.Email 	= "thefnox@gmail.com"
GM.Website  = ""

__CombatRules = {
	BaseMoveDistance = 300,
	CloseRange = 400,
	LongRange = 1000,
	ShootTime = 1,
	DefeatCooldown = 60 * 60,
	EmoteLimit = 5
}

function GM:FinishMove(ply, mv)

	if (ply.__MoveLocked) then
		ply:SetPos(ply:GetPos())
		return true
	elseif (ply.__MoveLimitOrigin) then
		local distance = ply.__MoveLimitOrigin:Distance(mv:GetOrigin())
		local vec = ply:GetPos() - ply.__MoveLimitOrigin
		local limit = __CombatRules.BaseMoveDistance
		if (distance >= limit) then
			local ang = mv:GetMoveAngles()
			local moveVec = Vector(ang:Forward(), ang)
			ply:SetPos(ply.__MoveLimitOrigin + vec:GetNormalized() * (limit - 10))
			if SERVER then
				if (ply.__CanEndCombat) then
					ply:ClearCombat()
					ply.__CanEndCombat = false;
				end
			end
			return true
		end
	end
end

function GM:StartCommand(ply, cmd)
	if !ply:IsAllowedToFire() then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	end
end