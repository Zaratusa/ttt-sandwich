--[[Author informations]]--
SWEP.Author = "Zaratusa"
SWEP.Contact = "http://steamcommunity.com/profiles/76561198032479768"

local detectiveEnabled = CreateConVar("ttt_sandwich_detective", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should Detectives be able to use the Sandwich?", 0, 1)
local traitorEnabled = CreateConVar("ttt_sandwich_traitor", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should Traitors be able to use the Sandwich?", 0, 1)

local defaultClipSize = CreateConVar("ttt_sandwich_bought", 4, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Amount of sandwiches you receive, when you buy a Sandwich.", 1)
local clipSize = CreateConVar("ttt_sandwich_max", 4, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Maximum amount of sandwiches you can carry.", 1)
local hasLimitedStock = CreateConVar("ttt_sandwich_limited_stock", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Can you buy the Sandwich only once per round?", 0, 1)

local healAmount = CreateConVar("ttt_sandwich_heal_amount", 25, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Amount of health being restored upon consumption.", 1)

if SERVER then
	AddCSLuaFile()
	resource.AddWorkshop("645663146")
else
	LANG.AddToLanguage("english", "sandwich_name", "Sandwich")
	LANG.AddToLanguage("english", "sandwich_desc", "Have a snack\nand heal yourself or others.\nBe careful when you throw it\non the ground, it can spoil.")
	
	LANG.AddToLanguage("Русский", "sandwich_name", "Бутерброд")
	LANG.AddToLanguage("Русский", "sandwich_desc", "Перекусите\nи исцелите себя или других.\nБудьте осторожны, когда бросаете это\nна землю, оно может испортиться.")

	SWEP.PrintName = "sandwich_name"
	SWEP.Slot = 7
	SWEP.Icon = "vgui/ttt/icon_sandwich"

	-- client side model settings
	SWEP.UseHands = true -- should the hands be displayed
	SWEP.ViewModelFlip = false -- should the weapon be hold with the left or the right hand
	SWEP.ViewModelFOV = 70

	-- Equipment menu information is only needed on the client
	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "sandwich_desc"
	}

	hook.Add("TTT2ScoreboardAddPlayerRow", "ZaratusasTTTMod", function(ply)
		local ID64 = ply:SteamID64()
		local ID64String = tostring(ID64)

		if (ID64String == "76561198032479768") then
			AddTTT2AddonDev(ID64)
		end
	end)
end

-- always derive from weapon_tttbase
SWEP.Base = "weapon_tttbase"

--[[Default GMod values]]--
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 2
SWEP.Primary.Automatic = false
SWEP.Primary.DefaultClip = defaultClipSize:GetInt()
SWEP.Primary.ClipSize = clipSize:GetInt()

SWEP.HealAmount = healAmount:GetInt()

--[[Model settings]]--
SWEP.HoldType = "slam"
SWEP.ViewModel = Model("models/weapons/zaratusa/sandwich/v_sandwich.mdl")
SWEP.WorldModel = Model("models/weapons/zaratusa/sandwich/w_sandwich.mdl")

--[[TTT config values]]--

-- Kind specifies the category this weapon is in. Players can only carry one of
-- each. Can be: WEAPON_... MELEE, PISTOL, HEAVY, NADE, CARRY, EQUIP1, EQUIP2 or ROLE.
-- Matching SWEP.Slot values: 0      1       2     3      4      6       7        8
SWEP.Kind = WEAPON_EQUIP2

-- If AutoSpawnable is true and SWEP.Kind is not WEAPON_EQUIP1/2,
-- then this gun can be spawned as a random weapon.
SWEP.AutoSpawnable = false

-- The AmmoEnt is the ammo entity that can be picked up when carrying this gun.
SWEP.AmmoEnt = "none"

-- CanBuy is a table of ROLE_* entries like ROLE_TRAITOR and ROLE_DETECTIVE. If
-- a role is in this table, those players can buy this.
SWEP.CanBuy = {}

if (detectiveEnabled:GetBool()) then
	table.insert(SWEP.CanBuy, ROLE_DETECTIVE)
end
if (traitorEnabled:GetBool()) then
	table.insert(SWEP.CanBuy, ROLE_TRAITOR)
end

-- If LimitedStock is true, you can only buy one per round.
SWEP.LimitedStock = hasLimitedStock:GetBool()

-- If AllowDrop is false, players can't manually drop the gun with Q
SWEP.AllowDrop = true

-- If IsSilent is true, victims will not scream upon death.
SWEP.IsSilent = false

-- If NoSights is true, the weapon won't have ironsights
SWEP.NoSights = false

local HealSound = Sound("weapons/sandwich/eat.wav")

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "Permanency")
end

function SWEP:Initialize()
	self.FirstCheck = true
	self:SetPermanency(100)
end

function SWEP:PrimaryAttack()
	if (SERVER and self:CanPrimaryAttack() and self:GetNextPrimaryFire() <= CurTime()) then
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

		local owner = self:GetOwner()
		if (IsValid(owner)) then
			local tr = util.TraceLine({
				start = owner:GetShootPos(),
				endpos = owner:GetShootPos() + owner:GetAimVector() * 80,
				filter = owner,
				mask = MASK_SOLID
			})
			local ent = tr.Entity
			if (IsValid(ent) and ent:IsPlayer()) then
				self:Heal(ent)
			end
		end
	end
end

function SWEP:SecondaryAttack()
	if (SERVER and self:CanSecondaryAttack() and self:GetNextSecondaryFire() <= CurTime()) then
		self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

		local owner = self:GetOwner()
		if (IsValid(owner)) then
			self:Heal(owner)
		end
	end
end

-- heals or damages the given player, depending on the permanency
function SWEP:Heal(player)
	-- get a value between -1.0 and 1.0
	local perm = (self:GetPermanency() - 50) / 50
	if (self:GetPermanency() < 50) then
		local damage = -1 * perm * self.HealAmount
		-- random change of 25% to die, due to the sandwich
		if ((player:Health() - damage) <= 0 and math.random() > 0.25) then
			damage = (1 - player:Health()) * -1 -- decreases life to 1
		end

		local dmg = DamageInfo()
		dmg:SetDamage(damage)
		dmg:SetAttacker(self:GetOwner())
		dmg:SetInflictor(self)
		dmg:SetDamageType(DMG_PARALYZE)
		dmg:SetDamagePosition(player:GetPos())
		player:TakeDamageInfo(dmg)
	else
		player:SetHealth(math.min(player:GetMaxHealth(), player:Health() + (perm * self.HealAmount)))
	end
	player:EmitSound(HealSound)
	player:SetAnimation(PLAYER_ATTACK1)

	self:TakePrimaryAmmo(1)
	if (self:Clip1() < 1) then
		self:Remove()
	end
end

function SWEP:OnDrop()
	if (IsValid(self) and self:GetPermanency() > 0) then
		if (self.FirstCheck) then
			timer.Simple(3, function()
				if (IsValid(self) and self.FirstCheck) then
					self:SetPermanency(50)
					self.FirstCheck = false
				end
			end)
		end

		local ID = self:EntIndex()
		timer.Create("SandwichPermDec" .. ID, 2, 0, function()
			if (IsValid(self) and self:GetPermanency() > 0) then
				self:SetPermanency(self:GetPermanency() - 5)
			else
				timer.Remove("SandwichPermDec" .. ID)
			end
		end)
	end
end

function SWEP:Deploy()
	timer.Remove("SandwichPermDec" .. self:EntIndex())
	return true
end

function SWEP:OnRemove()
	if (CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive()) then
		RunConsoleCommand("lastinv")
	end
end

function SWEP:DrawHUD()
	local x = ScrW() / 2.0
	local y = ScrH() * 0.995

	draw.SimpleText("Primary attack to feed someone else.", "Default", x, y - 20, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	draw.SimpleText("Secondary attack to eat.", "Default", x, y, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

	return self.BaseClass.DrawHUD(self)
end
