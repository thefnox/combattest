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

	function ply:SetTurnQueue(a)
		self.__TurnQueue = a
		net.Start( "SetTurnQueue" )
			net.WriteTable(self.__TurnQueue)
		net.Send(self)
	end

	function ply:PushTurnQueue(a)
		self.__TurnQueue = self.__TurnQueue or {}
		print("Pushing " .. tostring(a))
		if (type(a) == "table") then
			for _, v in ipairs(self:GetTurnQueue()) do
				v:SetTurnQueue(a)
				v:RemoveFromTurnQueue(v)
				table.insert(v:GetTurnQueue(), v)
				print("Added " .. tostring(v))
			end
			self:SetTurnQueue(a)
		elseif (IsValid(a)) then
			print("Pushing " .. tostring(a))
			self:RemoveFromTurnQueue(a)
			table.insert(self:GetTurnQueue(), a)
			print("Added " .. tostring(a))
			self:SetTurnQueue(self:GetTurnQueue())
		end
		for _, v in ipairs(self:GetTurnQueue()) do
			//Update all queues clientside
			v:SetTurnQueue(self:GetTurnQueue())
		end
	end

	function ply:RemoveFromTurnQueue(a)
		a = a or self
		local index = table.KeyFromValue(self:GetTurnQueue(), a)
		if (index) then
			table.remove(self:GetTurnQueue(), index)
			print("Removed index " .. index .. ": " .. tostring(a))
			self:SetTurnQueue(self.__TurnQueue)
		end
		for _, v in ipairs(self:GetTurnQueue()) do
			//Update all queues clientside
			v:SetTurnQueue(self:GetTurnQueue())
		end
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

	function ply:ClearCombat()
		self.__Attacking = self.__Attacking or {}
		for _, target in pairs(self.__Attacking) do
			if (!target:IsInCombat()) then
				target:ClearCombat()
			end
		end
		self.__CanAttackAgain = {}
		self.__MustReply = {}
		self.__SkippedTurn = false
		self:RemoveFromTurnQueue()
		self:ClearAttack()
		self:ClearLockPos()
		self:SetMoveLocked(false)
		self:SetAllowedToFire(true)
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
			self:SetWalkSpeed(200)
			self:SetRunSpeed(500)
			self:ChatPrint("[COMBAT] You're no longer defeated")
			if timer.Exists(self:SteamID() .. "DeathTimer") then
				timer.Destroy(self:SteamID() .. "DeathTimer")
			end
			self:SetHealth(self:GetMaxHealth() / 4)
			net.Start( "SetPlayerDefeated" )
				net.WriteEntity(self)
				net.WriteBool(false)
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
			self:SetWalkSpeed(100)
			self:SetRunSpeed(self:GetWalkSpeed())
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

function ply:IsInTurnQueue(a)
	return table.KeyFromValue(self:GetTurnQueue(), a)
end

function ply:PopTurnQueue()
	return self:GetTurnQueue()[1]
end

function ply:CanEndCombat()
	return self.__CanEndCombat
end

function ply:IsMoveLocked()
	return self.__MoveLocked
end

function ply:IsPosLocked()
	return self.__MoveLimitOrigin
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

function ply:GetTurnQueue()
	return self.__TurnQueue or {}
end

function ply:IsInCombat()
	return self:IsDefending() or self:IsAttacking()
end

function ply:IsAllowedToFire()
	return !self.__NotAllowedToFire 
end

function ply:IsDefeated()
	if (SERVER and self.__TimeDefeated and (self.__TimeDefeated + __CombatRules.DefeatCooldown < CurTime())) then
		self:SetDefeated(false)
	end
	return self.__Defeated
end