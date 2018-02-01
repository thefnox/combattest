DEFINE_BASECLASS( "gamemode_base" )

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "player.lua" )

resource.AddFile("materials/playerlocked.png")

include( "player.lua" )
include( "shared.lua" )

util.AddNetworkString( "SetPlayerLock" )
util.AddNetworkString( "SetPlayerFrozen" )
util.AddNetworkString( "SetPlayerDefending" )
util.AddNetworkString( "SetPlayerAttacking" )
util.AddNetworkString( "SetPlayerAllowedToFire" )
util.AddNetworkString( "SetAttacking" )
util.AddNetworkString( "SetDefending" )
util.AddNetworkString( "SetPlayerCanEndCombat" )
util.AddNetworkString( "SetPlayerDefeated" )
util.AddNetworkString( "SetTurnQueue" )

GM.__ChatCommands = {
	["/me"] = function(ply, msg)
		gamemode.Call("PlayerEmote", ply, msg)
		return "**" .. ply:GetName() .. " " .. msg
	end,
	["/lockme"] = function(ply)
		ply:SetLockPos(ply:GetPos())
		return false
	end,
	["/unlockme"] = function(ply)
		ply:ClearLockPos()
		ply:SetMoveLocked(false)
		return false
	end,
	["/reviveme"] = function(ply)
		ply:SetDefeated(false)
		ply:SetHealth(100)
		return false
	end,
	["/fireblock"] = function(ply)
		ply:SetAllowedToFire(false)
		return false
	end,
	["/fireallow"] = function(ply)
		ply:SetAllowedToFire(true)
		return false
	end,
	["/surrender"] = function(ply)
		if (!ply:IsDefeated()) then
			for _, pl in pairs(player.GetAll()) do
				if pl:IsAttacking(self) then
					ply:SetDefeated(pl, CurTime())
					return ply:GetName() .. " surrenders to " .. pl:GetName()
				end 
			end
			ply:ChatPrint("You cannot surrender while out of combat.")
		else
			ply:ChatPrint("You cannot surrender while defeated.")
		end
		return false
	end,
	["/removedefeat"] = function(ply)
		ply:SetDefeated(false)
		ply:SetHealth(ply:GetMaxHealth())
		return false
	end,
	["/botemote"] = function(ply)
		for _, pl in pairs(player.GetBots()) do
			gamemode.Call("PlayerSay", pl, "/me says some really stupid shit", false)
		end
		return false
	end,
	["/botrevive"] = function(ply)
		for _, pl in pairs(player.GetBots()) do
			pl:SetDefeated(false)
			pl:SetHealth(100)
		end
		return false
	end,
	["/reviveall"] = function(ply)
		for _, pl in pairs(player.GetAll()) do
			pl:SetDefeated(false)
			pl:SetHealth(100)
		end
		return false
	end
}

GM.__PlayerModels = {
	"models/player/group01/female_01.mdl",
	"models/player/group01/female_02.mdl",
	"models/player/group01/female_03.mdl",
	"models/player/group01/female_04.mdl",
	"models/player/group01/female_05.mdl",
	"models/player/group01/male_01.mdl",
	"models/player/group01/male_02.mdl",
	"models/player/group01/male_03.mdl",
	"models/player/group01/male_04.mdl",
	"models/player/group01/male_05.mdl",
	"models/player/group01/male_06.mdl",
	"models/player/group01/male_07.mdl",
	"models/player/group01/male_08.mdl",
	"models/player/group01/male_09.mdl",
}

function GM:PlayerSpawn(ply)

	BaseClass.PlayerSpawn( self, ply )
end

function GM:PlayerLoadout(ply)
	ply:Give( "weapon_crowbar" )
	ply:Give( "weapon_pistol" )
	ply:Give( "weapon_smg1" )
	ply:Give( "weapon_frag" )
	ply:Give( "weapon_ar2" )
	ply:Give( "weapon_shotgun" )
	ply:GiveAmmo( 999999,	"Pistol", true )
	ply:GiveAmmo( 999999, "SMG1", true )
	ply:GiveAmmo( 999, "grenade", true )
	ply:GiveAmmo( 999999, "Buckshot", true )
	ply:GiveAmmo( 999999, "AR2", true )
end
function GM:PlayerSetModel(ply)
	ply:SetModel(table.Random(self.__PlayerModels))
end

function GM:DoPlayerDeath(ply, inflictor, attacker)
	BaseClass.DoPlayerDeath( self, ply, inflictor, attacker )
end

function GM:PlayerEmote(ply, emote)
	print(ply:GetName() .. " emoted.")

	if (ply:IsInCombat() and #emote >= __CombatRules.EmoteLimit) then
		//If it was the player's turn, then process the turn queue
		gamemode.Call("ProcessTurnQueue", ply)
	elseif (ply:IsInCombat()) then
		ply:ChatPrint("[COMBAT] The emote wasn't long enough according to combat rules, try again.")
	end
end

function GM:PlayerDisconnected(ply)
	if (ply:IsInCombat()) then
		ply:SetDefeated(ply, CurTime())
	end
end

function GM:ProcessTurnQueue(ply)
	local queue = ply:GetTurnQueue()
	if (ply:PopTurnQueue() == ply) then
		//Turn ended for player, process the queue
		if (ply.__SkippedTurn) then
			//If the player has skipped twice, remove them from combat
			ply:ChatPrint("[COMBAT] You have skipped your turn twice, so you're now set as a non-combatant.")
			for _, pl in pairs(player.GetAll()) do
				if (pl:IsAttacking(ply)) then
					pl:ChatPrint("[COMBAT] " .. ply:GetName() .. " has skipped their turn twice, so they're now set as a non-combatant")
				end
			end
			ply:ClearCombat()
		else
			if (!ply:IsAttacking()) then
				//If the player didn't attack when they could, it means they skipped their turn
				ply.__SkippedTurn = true
				ply:ChatPrint("[COMBAT] You have skipped your turn to attack.")
			end
			//Lock the player, and forbid them from firing
			ply:ClearLockPos()
			ply:SetMoveLocked(true)
			ply:SetAllowedToFire(false)
			//Remove the player from the beginning of the queue, add them back at the end
			ply:PushTurnQueue(ply)
		end
		//If the queue is still not empty, allow the next person in the queue to attack and move
		local next = queue[1]
		if (next) then
			//If there's only one person left in the queue, have them exit combat
			if (#queue == 1) then
				next:ClearCombat()
			else
				gamemode.Call("BeginTurn", next)
			end
		end
	end
end

function GM:BeginTurn(ply)
	ply:SetMoveLocked(false)
	ply:SetAllowedToFire(true)
	ply:ClearAttack()
	if (!ply:IsPosLocked()) then
		//Player wasn't hit, lock them to their last position
		ply:SetLockPos(ply:GetPos())
	end
end

function GM:OnPlayerAttack(ply, target)
	print(ply:GetName() .. " has attacked " .. target:GetName())
	ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 5))
	//If you attacked it means you didn't skip your turn
	ply.__SkippedTurn = false
	//You're locked in the position where you fired from
	ply:SetMoveLocked(true)

	if (!ply:IsInTurnQueue(target)) then
		//The target is not in the queue already
		if (#target:GetTurnQueue() > 0) then
			//The target is already in a queue, merge that queue with ours
			ply:PushTurnQueue(target:GetTurnQueue())
		else
			//The target is not in a queue, add it to ours, and set their queue to ours
			ply:PushTurnQueue(target)
			target:SetTurnQueue(ply:GetTurnQueue())
		end
		//Push the attacker to the end of the queue
		ply:PushTurnQueue(ply)
	end
	
	if !timer.Exists(ply:SteamID() .. "AttackTimer") then
		//This is to control spraying and automatic weapons, you can only attack the people you can hit within a specified time (1 second, for example)
		timer.Create( ply:SteamID() .. "AttackTimer", __CombatRules.ShootTime, 1, function()
			ply:SetAllowedToFire(false)
		end)
	end
	if (!ply:IsInCombat()) then
		ply:ChatPrint("[COMBAT] You've attacked " .. target:GetName() .. ", you will be allowed to attack again after they emote.")
	end
	ply:SetAttack(target)
end

function GM:OnPlayerDefend(ply, attacker)
	print(ply:GetName() .. " is being attacked by" .. attacker:GetName())
	if (ply:PopTurnQueue() == ply) then
		//If you're also the first in the queue after being attacked, it's your turn
		gamemode.Call("BeginTurn", ply)
	end
	if (!ply:IsInCombat()) then
		ply:ChatPrint("[COMBAT] You've been attacked by " .. attacker:GetName() .. ", you will be allowed to attack again after emoting.")
	end
end

function GM:CalcDamage(target, attacker, dmginfo)
	//Baseline formula doubles damage as damage is generally way too low since the default doesn't account for misses
	dmginfo:ScaleDamage(2)
	local wep = attacker:GetActiveWeapon()
	local holdtype = wep:GetHoldType()
	local distance = target:GetPos():Distance(attacker:GetPos())
	local hitgroup = target:LastHitGroup() 
	//50% chance to hit is the default
	local critChance = 0
	local hitChance = 50
	local isBackstab = math.abs(target:GetAimVector():Angle().y - attacker:GetAimVector():Angle().y) <= 30

	print(target:WorldToLocal(dmginfo:GetDamagePosition()))

	if (dmginfo:IsExplosionDamage()) then
		//Damage is guaranteed with explosives, as they're meant to be of limited use
		hitChance = 100
		critChance = 25
	elseif (dmginfo:IsBulletDamage()) then
		//Damage with bullets is localized, unlike other types of damage, other rules also apply
		//Shotguns scale inversely with scale
		if (dmginfo:IsDamageType(DMG_BUCKSHOT)) then
			if (distance <= __CombatRules.CloseRange) then
				//Close range
				critChance = 50
				hitChance = 99
				dmginfo:ScaleDamage(math.max(__CombatRules.CloseRange / distance, 1.75))
			elseif (distance >= __CombatRules.LongRange) then
				//Long range
				dmginfo:ScaleDamage((__CombatRules.LongRange / distance) * 2)
				hitChance = 30
			else
				//Medium range
				critChance = 10
				hitChance = 60
			end
		elseif (holdtype == "ar2") then
			//Rifles are better at longer ranges, become less effective in short range
			hitChance = 90
			if (distance <= __CombatRules.CloseRange) then
				hitChance = 60
				dmginfo:ScaleDamage(math.max((distance / __CombatRules.CloseRange), 0.8))
				//Close range
			elseif (distance >= __CombatRules.LongRange) then
				//Long range
				dmginfo:ScaleDamage(math.min((distance / __CombatRules.LongRange), 2))
				critChance = 40
				//Guaranteed hits on a long range headshot
				if hitgroup == HITGROUP_HEAD then
					hitChance = 100
				end
			else
				//Medium range
				critChance = 25 
			end
			//Double crit chance if  you hit them in the head
			if hitgroup == HITGROUP_HEAD then
				critChance = critChance * 2
			end
		elseif (holdtype == "pistol") then
			//Pistols fall off at longer ranges, but are effective in close range
			if (distance <= __CombatRules.CloseRange) then
				//Close range
				critChance = 10
				hitChance = 90
				dmginfo:ScaleDamage(1.25)
				//Guaranteed hits on a close range headshot
				if hitgroup == HITGROUP_HEAD then
					hitChance = 100
					critChance = 40
				end
			elseif (distance >= __CombatRules.LongRange) then
				//Long range
				hitChance = 60
				dmginfo:ScaleDamage(0.666)
			else
				//Medium range
				hitChance = 80
				critChance = 5
			end
		else
			hitChance = 90
			critChance = 5
		end
	else
		//Damage of other type, assumed to be melee
		if (dmginfo:IsDamageType(DMG_SLASH)) then
			//This is for knives and swords
			//You could apply a bleed effect here
			critChance = 10
			hitChance = 90
			if (isBackstab) then
				critChance = 65
				if hitgroup == HITGROUP_HEAD then
					dmginfo:ScaleDamage(1.5)
				end
			end
		elseif (dmginfo:IsDamageType(DMG_CLUB)) then
			//This is for crowbars, stunbatons and melee weapons
			hitChance = 80
			if (isBackstab) then
				critChance = 50
			end
		elseif (dmginfo:IsDamageType(DMG_CRUSH)) then
			//This is for hand-to-hand and non-weapon objects
			critChance = 15
			hitChance = 75
		end
	end

	//Applies armor reduction here
	dmginfo:ScaleDamage(100 / (100 + math.max(target:Armor(), 0)))

	if (math.random(1, 100) >= hitChance) then
		//If the number is greater than the hit chance, the hit misses
		dmginfo:SetDamage(0)
	end

	if (dmginfo:GetDamage() > 0 and math.random(1, 100) < critChance ) then
		//If the number is greater than the crit chance, then it doesn't crit
		dmginfo:ScaleDamage(2)
		attacker:ChatPrint("[COMBAT] CRITICAL DAMAGE!")
		target:ChatPrint("[COMBAT] CRITICAL DAMAGE!")
	end

	dmginfo:SetDamage(math.Round(dmginfo:GetDamage()))

	print("Damage has been calculated as " .. dmginfo:GetDamage())
	attacker:ChatPrint("[COMBAT] You deal " .. dmginfo:GetDamage() .. " damage.")
	target:ChatPrint("[COMBAT] You take " .. dmginfo:GetDamage() .. " damage from " .. attacker:GetName() .. ".")
end

function GM:PlayerSwitchWeapon( ply, oldWeapon, newWeapon )
	if (ply:IsDefeated() or !ply:IsAllowedToFire()) then
		return true
	end
	BaseClass.PlayerSwitchWeapon(self, oldWeapon, newWeapon)
end

function GM:EntityTakeDamage(target, dmginfo)

	local attacker = dmginfo:GetAttacker()
	local isPlayer = target:IsPlayer() and IsValid(attacker) and attacker:IsPlayer()
	local validTarget = isPlayer and !target:IsDefeated() and !attacker:IsDefeated() and target != attacker
	local canAttack = isPlayer and !attacker:IsAttacking(target) and attacker:IsAllowedToFire()

	if (validTarget and canAttack and !dmginfo:IsDamageType(DMG_CRUSH)) then
		gamemode.Call("CalcDamage", target, attacker, dmginfo)

		if (dmginfo:GetDamage() >= target:Health()) then
			target:SetHealth(1)
			target:SetDefeated(attacker, CurTime())
			attacker:ChatPrint("[COMBAT] You've defeated " .. target:GetName())
			target:ChatPrint("[COMBAT] You've been defeated by " .. attacker:GetName())
			dmginfo:SetDamage(0)
		else
			gamemode.Call("OnPlayerAttack", attacker, target)
			gamemode.Call("OnPlayerDefend", target, attacker)
		end
	else
		return true
	end

end

function GM:PlayerSay(ply, txt, t)
	local split = string.Split(txt, " ")
	local command = split[1]
	local message = txt
	if command[1] == "/" then
		message = table.concat(split, " ", 2)
		local func = self.__ChatCommands[command]
		if (func) then
			message = func(ply, message)
		else
			ply:ChatPrint("Unknown command: " .. command)
			return false;
		end
	else
		message = ply:GetName() .. " says: " .. txt
	end

	if (message) then
		for _, pl in pairs( player.GetAll() ) do
			pl:ChatPrint(message)
		end
	end

	return false
end