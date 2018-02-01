local ply = FindMetaTable("Player")

if SERVER then
	function ply:SetLockPos(pos)
		self.__MoveLimitOrigin = pos
		net.Start( "SetPlayerLock" )
			net.WriteEntity(self)
		if (pos) then
			net.WriteBool(true)
			net.WriteVector(pos)
		else
			net.WriteBool(false)
			net.WriteVector(Vector(0,0,0))
		end
		net.Broadcast()
	end

	function ply:SetMoveLocked(b)
		self.__MoveLocked = b
		net.Start( "SetPlayerFrozen" )
			net.WriteEntity(self)
			net.WriteBool(b)
		net.Broadcast()
	end

	function ply:SetAttack(target)
		self.__Attacking = self.__Attacking or {}
		target:ClearAttack(self)
		table.RemoveByValue(self.__Attacking, target)
		table.insert(self.__Attacking, target)
		net.Start( "SetAttacking" )
			net.WriteTable(self.__Attacking)
		net.Send(self)
	end

	function ply:SetDefend(attacker)
		self.__Attackers = self.__Attackers or {}
		table.insert(self.__Attackers, target)
		net.Start( "SetDefending" )
			net.WriteTable(self.__Attackers)
		net.Send(self)
	end

	function ply:ClearAttack(target)
		self.__Attacking = self.__Attacking or {}
		if (target) then
			table.RemoveByValue(self.__Attacking, target)
		else
			self.__Attacking = {}
		end
		net.Start( "SetAttacking" )
			net.WriteTable(self.__Attacking)
		net.Send(self)
	end

	function ply:CanAttackAgain(target)
		for _, pl in pairs(self.__CanAttackAgain or {}) do
			if (pl == target) then return true end
		end
		return false
	end

	function ply:SetAttackAgain(target)
		self.__CanAttackAgain = self.__CanAttackAgain or {}
		table.RemoveByValue(self.__CanAttackAgain, target) 
		table.insert(self.__CanAttackAgain, target)
	end

	function ply:ClearAttackAgain(target)
		if (target) then
			table.RemoveByValue(self.__CanAttackAgain or {}, target)
		else
			self.__CanAttackAgain = {}
		end
	end

	function ply:ClearCombat()
		self.__Attacking = self.__Attacking or {}
		for _, target in pairs(self.__Attacking) do
			if (!target:IsInCombat()) then
				target:ClearCombat()
			end
		end
		self.__CanAttackAgain = {}
		self.__MustReply = {}
		self:ClearAttack()
		self:ClearLockPos()
		self:SetMoveLocked(false)
		self:SetAllowedToFire(true)
		self:ChatPrint("You're no longer in combat.")
	end

	function ply:SetCanEndCombat(b)
		self.__CanEndCombat = b
		net.Start( "SetPlayerCanEndCombat" )
			net.WriteBool(b)
		net.Broadcast()
	end

	function ply:SetAllowedToFire(b)
		if (self.__NotAllowedToFire and b) then
			self:ChatPrint("You're allowed to attack again")
		end
		self.__NotAllowedToFire = !b
		net.Start( "SetPlayerAllowedToFire" )
			net.WriteEntity(self)
			net.WriteBool(!b)
		net.Broadcast()
	end

	function ply:SetDefeated(killer, time)
		if (killer == false and self.__Defeated) then
			self.__Defeated = false
			self:ChatPrint("You're no longer defeated")
			if timer.Exists(self:SteamID() .. "DeathTimer") then
				timer.Destroy(self:SteamID() .. "DeathTimer")
			end
			self:SetHealth(self:GetMaxHealth() / 4)
			net.Start( "SetPlayerDefeated" )
				net.WriteEntity(self)
				net.WriteBool(true)
			net.Broadcast()
		elseif (killer) then
			self:ClearCombat()
			for _, pl in pairs(player.GetAll()) do
				pl:ClearAttack(self)
				if (!pl:IsInCombat()) then
					pl:ClearCombat()
				end
			end
			self.__DefeatedBy = killer
			self.__TimeDefeated = time
			self.__Defeated = true
			timer.Create( self:SteamID() .. "DeathTimer", __CombatRules.DefeatCooldown, 1, function()
				self:SetDefeated(false)
			end)
			net.Start( "SetPlayerDefeated" )
				net.WriteEntity(self)
				net.WriteBool(true)
				net.WriteDouble(self.__TimeDefeated)
				net.WriteEntity(self.__DefeatedBy)
			net.Broadcast()
		end
	end
end

function ply:CanEndCombat()
	return self.__CanEndCombat
end

function ply:IsMoveLocked()
	return self.__MoveLocked
end

function ply:ClearLockPos()
	self:SetLockPos()
end

function ply:IsAttacking(target)
	if (self.__Attacking) then
		if (!target) then return #self.__Attacking > 0
		else return table.HasValue(self.__Attacking, target) end
	end
	return false
end

function ply:IsDefending(target)
	for _, pl in pairs(player.GetAll()) do
		if pl:IsAttacking(self) then
			return true
		end 
	end
	return false
end


function ply:IsInCombat()
	return self:IsDefending() or self:IsAttacking()
end

function ply:IsAllowedToFire()
	return !self.__NotAllowedToFire 
end

function ply:IsDefeated()
	if (self.__TimeDefeated and (self.__TimeDefeated + __CombatRules.DefeatCooldown < CurTime())) then
		self:SetDefeated(false)
	end
	return self.__Defeated
end