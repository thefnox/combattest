DEFINE_BASECLASS( "gamemode_base" )

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "player.lua" )

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

GM.__ChatCommands = {
	["/me"] = function(ply, msg)
		gamemode.Call("PlayerEmote", ply, msg)
		return "**" .. ply:GetName() .. " " .. msg
	end,
	["/fuckme"] = function(ply, msg)
		return "No, fuck you!"
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
		for _, pl in pairs(player.GetAll()) do
			if pl:IsAttacking(ply) then
				table.RemoveByValue(pl.__MustReply, ply)
			end 
		end
		if (ply:IsDefending()) then
			ply:SetAllowedToFire(!ply:IsAttacking())
			ply:SetMoveLocked(ply:IsAttacking())
		end
		if (ply:IsAttacking()) then
			if (ply.__MustReply and #ply.__MustReply == 0) then
				ply:SetLockPos(ply:GetPos())
				ply:SetMoveLocked(false)
				ply:SetAllowedToFire(true)
				if (!ply:IsDefending()) then
					if (ply:CanEndCombat()) then
						ply:ClearCombat()
						ply:SetCanEndCombat(false);
					else
						ply:SetCanEndCombat(true);
						for _, target in pairs(ply.__Attacking) do
							if (!target:IsAttacking()) then
								ply:SetAttackAgain(target)
							end
						end
					end
				end
			end
		end
	elseif (ply:IsInCombat()) then
		ply:ChatPrint("The emote wasn't long enough according to combat rules, try again.")
	end
end

function GM:PlayerDisconnected(ply)
	if (ply:IsInCombat()) then
		ply:SetDefeated(ply, CurTime())
	end
end

function GM:OnPlayerAttack(ply, target)
	print(ply:GetName() .. " has attacked " .. target:GetName())
	ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 5))
	ply:SetCanEndCombat(false);
	ply:SetMoveLocked(true)
	ply:ClearAttackAgain(target)
	ply.__MustReply = ply.__MustReply or {}
	table.RemoveByValue(ply.__MustReply, target)
	table.insert(ply.__MustReply, target)
	if !timer.Exists(ply:SteamID() .. "AttackTimer") then
		timer.Create( ply:SteamID() .. "AttackTimer", __CombatRules.ShootTime, 1, function()
			ply:SetAllowedToFire(false)
		end)
	end
	if (!ply:IsInCombat()) then
		ply:ChatPrint("You've attacked " .. target:GetName() .. ", you will be allowed to attack again after they emote.")
	end
	ply:SetAttack(target)
end

function GM:OnPlayerDefend(ply, attacker)
	print(ply:GetName() .. " is being attacked by" .. attacker:GetName())
	ply:SetLockPos(ply:GetPos())
	ply:SetMoveLocked(ply:IsAttacking() and (ply.__MustReply and #ply.__MustReply > 0))
	ply:SetAllowedToFire(false)
	if (!ply:IsInCombat()) then
		ply:ChatPrint("You've been attacked by " .. attacker:GetName() .. ", you will be allowed to attack again after emoting.")
	end
end

function GM:CalcDamage(target, attacker, dmginfo)
	//Baseline formula doubles damage as damage is generally way too low since the default doesn't account for misses
	dmginfo:ScaleDamage(2)
	local wep = attacker:GetActiveWeapon()
	local holdtype = wep:GetHoldType()
	local distance = target:GetPos():Distance(attacker:GetPos())
	//50% chance to hit is the default
	local critChance = 0
	local hitChance = 50

	print(dmginfo:GetDamageType())

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
				dmginfo:ScaleDamage(__CombatRules.CloseRange / distance)
			elseif (distance >= __CombatRules.LongRange) then
				//Long range
				dmginfo:ScaleDamage((__CombatRules.LongRange / distance) * 2)
				hitChance = 30
			else
				//Medium range
				critChance = 10
				hitChance = 75
			end
		elseif (holdtype == "ar2") then
			//Rifles are better at longer ranges, become less effective in short range
			hitChance = 90
			if (distance <= __CombatRules.CloseRange) then
				dmginfo:ScaleDamage(math.max((distance / __CombatRules.CloseRange), 0.66666))
				//Close range
			elseif (distance >= __CombatRules.LongRange) then
				//Long range
				dmginfo:ScaleDamage(math.max((distance / __CombatRules.LongRange), 2))
				critChance = 33
			else
				//Medium range
				critChance = 10 
			end
		elseif (holdtype == "pistol") then
			//Pistols fall off at longer ranges, but are effective in close range
			if (distance <= __CombatRules.CloseRange) then
				//Close range
				critChance = 20
				hitChance = 90
				dmginfo:ScaleDamage(1.25)
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
		elseif (dmginfo:IsDamageType(DMG_CLUB)) then
			//This is for crowbars, stunbatons and melee weapons
			hitChance = 80
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
		attacker:ChatPrint("CRITICAL DAMAGE!")
	end

	dmginfo:SetDamage(math.Round(dmginfo:GetDamage()))

	print("Damage has been calculated as " .. dmginfo:GetDamage())
	attacker:ChatPrint("You deal " .. dmginfo:GetDamage() .. " damage.")
	target:ChatPrint("You take " .. dmginfo:GetDamage() .. " damage from " .. attacker:GetName() .. ".")
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
	local canAttack = isPlayer and (!attacker:IsAttacking(target) or attacker:CanAttackAgain(target)) and attacker:IsAllowedToFire()

	if (validTarget and canAttack and !dmginfo:IsDamageType(DMG_CRUSH)) then
		gamemode.Call("CalcDamage", target, attacker, dmginfo)

		if (dmginfo:GetDamage() >= target:Health()) then
			target:SetHealth(1)
			target:SetDefeated(attacker, CurTime())
			attacker:ChatPrint("You've defeated " .. target:GetName())
			target:ChatPrint("You've been defeated by " .. attacker:GetName())
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