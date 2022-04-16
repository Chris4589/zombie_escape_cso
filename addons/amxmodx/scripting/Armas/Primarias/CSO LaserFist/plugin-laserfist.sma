#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>

#define PLUGIN "Infinity Laser Fist"
#define VERSION "Counter Strike 1.6"
#define AUTHOR "Mellowzy (fixed by Asdian)"

#define CLIP 500
#define BPAMMO 1500
#define SPEED 0.01

#define CSW_LASERFIST CSW_M249
#define weapon_laserfist "weapon_m249"
#define PLAYER_ANIMEXT "dualpistols"
#define LASERFIST_OLDMODEL "models/w_m249.mdl"
#define weapon_event "events/m249.sc"

#define MUZZLE_FLASH "sprites/muzzleflash92.spr"
#define MUZZLE_FLASH_CH "sprites/muzzleflash87.spr"

#define EF_CHARGE "sprites/ef_laserfist_charge.spr"
#define EF_CHARGE2 "sprites/ef_laserfist_charge_left.spr"

#define V_MODEL "models/v_laserfist.mdl"
#define V_MODEL2 "models/v_laserfist2.mdl"
#define P_MODEL "models/p_laserfist.mdl"
#define W_MODEL "models/w_laserfist.mdl"

new const laserfist_Sounds[][] = 
{
	"weapons/laserfist_b1.wav",
	"weapons/laserfist_clipin1.wav",
	"weapons/laserfist_clipin2.wav",
	"weapons/laserfist_clipout.wav",
	"weapons/laserfist_draw.wav",
	"weapons/laserfist_idle.wav",
	"weapons/laserfist_shoota_empty_end.wav",
	"weapons/laserfist_shoota_empty_loop.wav",
	"weapons/laserfist_shoota-1.wav",
	"weapons/laserfist_shootb_exp.wav",
	"weapons/laserfist_shootb_loop.wav",
	"weapons/laserfist_shootb_ready.wav",
	"weapons/laserfist_shootb_shoot.wav",
	"weapons/laserfist_shootb-1.wav"
}

new const laserfist_Resources[][] = 
{
	"sprites/weapon_laserfist.txt",
	"sprites/640hud36.spr",	
	"sprites/640hud44.spr",
	"sprites/640hud188.spr",
	"sprites/ef_laserfist_laser.spr",
	"sprites/ef_laserfist_laser_explosion.spr",
	"sprites/muzzleflash86.spr",
	"sprites/muzzleflash89.spr",
	"sprites/muzzleflash91.spr",
	"sprites/muzzleflash92.spr"
}

enum _:Anim
{
	ANIM_IDLE = 0,
	ANIM_SHOOTA_EMPTY_LOOP,
	ANIM_SHOOTA_EMPTY_END,
	ANIM_SHOOTA_LOOP,
	ANIM_SHOOTA_END,
	ANIM_SHOOTB_READY,
	ANIM_SHOOTB_LOOP,
	ANIM_SHOOTB_SHOOT,
	ANIM_RELOAD,
	ANIM_DRAW
}


// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

new g_Had_Laserfist, g_Laserfist_Clip[33], AmmoLimit[33], Float:g_End[3], g_Mode[33]
new g_Event_Laserfist, g_Msg_WeaponList, g_SmokePuff_SprId, g_ham_bot, g_Beam_SprID,g_Beam_SprID_blue, g_exp2
new cvar_dmg_a, cvar_dmg_b, cvar_dmg_kb, Float:g_Recoil[33][3], spr_blood_spray, spr_blood_drop

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	
	RegisterHam(Ham_Spawn, "player", "fw_Spawn_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_laserfist, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_laserfist, "fw_Weapon_PrimaryAttack_Post", 1)	
	RegisterHam(Ham_Item_Deploy, weapon_laserfist, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_laserfist, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_laserfist, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_laserfist, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_laserfist, "fw_Weapon_Reload_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack_World", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack_World", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack_World", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack_World", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack_World", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack_World", 1)

	register_forward(FM_UpdateClientData,"fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_Think, "fw_MF_Think")
	register_forward(FM_Touch, "fw_MF_Touch")
	
	cvar_dmg_a = register_cvar("laserfist_dmg_a", "50.0")
	cvar_dmg_b = register_cvar("laserfist_dmg_b", "750.0")
	cvar_dmg_kb = register_cvar("laserfist_dmg_b", "30.0")
	
	register_clcmd("lf", "Get_Laserfist")
	g_Msg_WeaponList = get_user_msgid("WeaponList")
	register_clcmd("weapon_laserfist", "Hook_Weapon")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, V_MODEL2)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	new i
	for(i = 0; i < sizeof(laserfist_Sounds); i++)
		engfunc(EngFunc_PrecacheSound, laserfist_Sounds[i])
	for(i = 0; i < sizeof(laserfist_Resources); i++)
	{
		if(!i) engfunc(EngFunc_PrecacheGeneric, laserfist_Resources[i])
		else engfunc(EngFunc_PrecacheModel, laserfist_Resources[i])
	}
	
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	g_Beam_SprID = engfunc(EngFunc_PrecacheModel, "sprites/ef_laserfist_laserbeam.spr")
	g_Beam_SprID_blue = engfunc(EngFunc_PrecacheModel, "sprites/ef_laserfist_laser.spr")
	spr_blood_spray = precache_model("sprites/bloodspray.spr")
	spr_blood_drop = precache_model("sprites/blood.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	
	// Muzzleflash
	g_exp2 = precache_model("sprites/ef_laserfist_laser_explosion.spr")
	
	precache_model(MUZZLE_FLASH_CH)
	precache_model(EF_CHARGE)
	precache_model(EF_CHARGE2)
	precache_model("models/w_usp.mdl")
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(weapon_event, name)) g_Event_Laserfist = get_orig_retval()		
}

public client_putinserver(id)
{
	if(!g_ham_bot && is_user_bot(id))
	{
		g_ham_bot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")
}

public plugin_natives()
{
	register_native("get_lfist", "native_get_lfist", 1)
	register_native("remove_lfist", "native_remove_lfist", 1)
}

public native_get_lfist(id) Get_Laserfist(id)
public native_remove_lfist(id)Remove_Laserfist(id)
public fw_Spawn_Post(id) Remove_Laserfist(id)

public client_connect(id)Remove_Laserfist(id)
public client_disconnected(id)Remove_Laserfist(id)

public Get_Laserfist(id)
{
	if(!is_user_alive(id))
		return
	
	drop_weapons(id, 1)
	fm_give_item(id, weapon_laserfist)
	Set_BitVar(g_Had_Laserfist, id)
	
	AmmoLimit[id] = 0
	g_Mode[id] = 0
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_LASERFIST)
	if(!pev_valid(Ent)) return
	
	set_pev(Ent, pev_iuser1, 0)
	set_pev(Ent, pev_iuser2, 0)
	set_pev(Ent, pev_iuser3, 0)
	
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	cs_set_user_bpammo(id, CSW_LASERFIST, BPAMMO)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_LASERFIST)
	write_byte(CLIP)
	message_end()
	
	ExecuteHamB(Ham_Item_Deploy, Ent)
}

public Remove_Laserfist(id)
{
	UnSet_BitVar(g_Had_Laserfist, id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_laserfist)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	static CSW; CSW = read_data(2)
	if(CSW != CSW_LASERFIST)
		return
	if(!Get_BitVar(g_Had_Laserfist, id))	
		return 
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_LASERFIST)
	if(!pev_valid(Ent)) return
	
	set_pdata_float(Ent, 46, SPEED, 4)
	set_pdata_float(Ent, 47, SPEED, 4)
	set_pdata_float(Ent, 48, 1.0, 4)
}

public message_DeathMsg(msg_id, msg_dest, msg_ent)
{
	new szWeapon[64]
	get_msg_arg_string(4, szWeapon, charsmax(szWeapon))
	
	if (strcmp(szWeapon, "m249"))
		return PLUGIN_CONTINUE

	new iEntity = get_pdata_cbase(get_msg_arg_int(1), 373)
	if (!pev_valid(iEntity) || get_pdata_int(iEntity, 43, 4) != CSW_LASERFIST || !Get_BitVar(g_Had_Laserfist, get_msg_arg_int(1)))
		return PLUGIN_CONTINUE

	set_msg_arg_string(4, "laserfist")
	return PLUGIN_CONTINUE
}

public Draw_NewWeapon(id, CSW_ID)
{
	if(CSW_ID == CSW_ELITE)
	{
		static ent
		ent = fm_get_user_weapon_entity(id, CSW_LASERFIST)
		
		if(pev_valid(ent) && Get_BitVar(g_Had_Laserfist, id))
			set_pev(ent, pev_effects, pev(ent, pev_effects) &~ EF_NODRAW) 
	} else {
		static ent
		ent = fm_get_user_weapon_entity(id, CSW_LASERFIST)
		
		if(pev_valid(ent)) set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW) 			
	}
	
}
public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_LASERFIST && Get_BitVar(g_Had_Laserfist, id))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		set_cd(cd_handle, CD_PunchAngle, {0.0,0.0,0.0})
	}
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_LASERFIST || !Get_BitVar(g_Had_Laserfist, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Laserfist)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_IGNORED
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_LASERFIST || !Get_BitVar(g_Had_Laserfist, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)

	g_End = flEnd
	SetHamParamFloat(3, get_pcvar_float(cvar_dmg_a))
	return HAM_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_LASERFIST || !Get_BitVar(g_Had_Laserfist, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, get_pcvar_float(cvar_dmg_a))
	return HAM_IGNORED
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, LASERFIST_OLDMODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_laserfist, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Laserfist, iOwner))
		{
			Remove_Laserfist(iOwner)
			
			set_pev(weapon, pev_impulse, 1712015)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public laserfist_controlcharge(id, Ent)
{
	if(!is_user_alive(id))
		return	
	if(!Get_BitVar(g_Had_Laserfist, id) || get_user_weapon(id) != CSW_LASERFIST)	
		return
		
	if(AmmoLimit[id] < 100) AmmoLimit[id] ++
	
	if(AmmoLimit[id] >= 100)
	{
		set_pev(id, pev_viewmodel2, V_MODEL2)
		set_pev(Ent, pev_iuser2, 1)
	}
}

public fw_Weapon_PrimaryAttack(Ent)
{
	static id; id = pev(Ent, pev_owner)
	new iClip = get_pdata_int(Ent, 51, 4)
	if(!Get_BitVar(g_Had_Laserfist, id)) return HAM_IGNORED
	
	if(!iClip)
		return HAM_SUPERCEDE
	
	pev(id, pev_punchangle, g_Recoil[id])
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	if(!Get_BitVar(g_Had_Laserfist, id)) return HAM_IGNORED
	
	static Float:Push[3]
	pev(id, pev_punchangle, Push)
	xs_vec_sub(Push, g_Recoil[id], Push)
	
	xs_vec_mul_scalar(Push, 0.08, Push)
	xs_vec_add(Push, g_Recoil[id], Push)
	set_pev(id, pev_punchangle, Push)
	
	set_pdata_string(id, (492) * 4, PLAYER_ANIMEXT, -1 , 20)
	return HAM_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Laserfist, Id))
		return
	
	new iState2 = pev(Ent, pev_iuser2)
	set_pev(Id, pev_viewmodel2, iState2 == 1? V_MODEL2 : V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	g_Mode[Id] = 0
	set_weapon_anim(Id, ANIM_DRAW)
	Sprite(Id)
	set_pdata_string(Id, (492) * 4, PLAYER_ANIMEXT, -1 , 20)
		
	set_pdata_float(Ent, 46, 1.7, 4)
	set_pdata_float(Ent, 48, 1.7, 4)
	set_pdata_float(Id, 83, 1.7, 5)
	
	static iClip
	iClip = get_pdata_int(Ent, 51, 4)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, Id)
	write_byte(1)
	write_byte(CSW_LASERFIST)
	write_byte(iClip)
	message_end()
	
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 1712015)
	{
		Set_BitVar(g_Had_Laserfist, id)
		set_pev(Ent, pev_impulse, 0)
	}		
	
	Sprite(id)
	return HAM_HANDLED	
}

public Sprite(id)
{
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Laserfist, id) ? "weapon_laserfist" : weapon_laserfist)
	write_byte(3) // PrimaryAmmoID
	write_byte(200) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Laserfist, id) ? CSW_LASERFIST : CSW_M249) // WeaponID
	write_byte(0) // Flags
	message_end()
}

public client_PostThink(id)
{
	if(!is_user_connected(id))
		return 	
	if(!Get_BitVar(g_Had_Laserfist, id))
		return 
	
	static Wpn; Wpn = get_pdata_cbase(id, 373)
	if(!pev_valid(Wpn)) return
	
	static iClip, iBp
	iClip = get_pdata_int(Wpn, 51, 4)
	iBp = cs_get_user_bpammo(id, CSW_LASERFIST)
	
	if(iClip > 255 || iBp > 255)
	{
		set_hudmessage(200, 100, 0, 1.0, 1.0)
		show_hudmessage(id, "%d | %d", iClip, iBp)
	}
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Laserfist, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_LASERFIST)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_LASERFIST, bpammo - temp1)		
		
		set_pdata_int(ent, 54, 0, 4)
		fInReload = 0
	}		
	
	return WE_LaserFist(id, ent, iClip, pev(id, pev_button))
}

// need to move to postframe
public WE_LaserFist(id, Ent, iClip, iButton)
{
	new iState = pev(Ent, pev_iuser1)
	new iState2 = pev(Ent, pev_iuser2)
	new iState3 = pev(Ent, pev_iuser3)
	new Float:flTime; pev(Ent, pev_fuser2, flTime)
	new Float:flTime2; pev(Ent, pev_fuser3, flTime2)
	
	if(iState3 == 1)
	{
		if(flTime2 && flTime2 < get_gametime())
		{
			MakeMuzzleFlash(id, 3, 0.05, "mf2", EF_CHARGE)
			MakeMuzzleFlash(id, 4, 0.05, "mf2", EF_CHARGE2)
			set_pev(Ent, pev_fuser3, 0.0)
		}
		
		if(flTime && flTime < get_gametime())
		{
			MakeMuzzleFlash(id, 1, 0.2, "mf1", "sprites/muzzleflash91.spr")
			MakeMuzzleFlash(id, 2, 0.2, "mf1", "sprites/muzzleflash91.spr")
			set_pev(Ent, pev_fuser2, 0.0)
		}
	}
	
	if(get_pdata_float(Ent, 46, 4) > 0.0)
		return HAM_IGNORED
	
	if(!(iButton & IN_ATTACK) && g_Mode[id] == 1)
	{
		g_Mode[id] = 0
		
		set_weapon_anim(id, !iClip ? ANIM_SHOOTA_EMPTY_END : ANIM_SHOOTA_END)
		set_pdata_float(Ent, 46, 0.5, 4)
		set_pdata_float(Ent, 48, 1.0, 4)
	}
	
	if(!(iButton & IN_ATTACK2) && g_Mode[id] == 2)
	{
		set_weapon_anim(id, ANIM_SHOOTB_SHOOT)
		MakeMuzzleFlash(id, 1, 0.08,  "mf2", MUZZLE_FLASH_CH)
		MakeMuzzleFlash(id, 2, 0.08,  "mf2", MUZZLE_FLASH_CH)
		
		Check_Damage(id, 1, 0)
		Check_Damage(id, 0, 0)
		
		remove_entity_name("mf1")
		set_pev(id, pev_viewmodel2, V_MODEL)
		
		AmmoLimit[id] = 0
		g_Mode[id] = 0
		
		set_pev(Ent, pev_iuser1, 0)
		set_pev(Ent, pev_iuser2, 0)
		set_pev(Ent, pev_iuser3, 0)
		set_pev(Ent, pev_iuser4, 0)
		
		set_pdata_float(Ent, 46, 1.72, 4)
		set_pdata_float(Ent, 48, 1.75, 4)
		set_pdata_float(id, 83, 1.75, 5)
		emit_sound(id, CHAN_WEAPON, "weapons/laserfist_shootb-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	new Float:flNextPrimaryAttack, Float:fCurTime, Float:flNextSound
	global_get(glb_time, fCurTime)
	pev(Ent, pev_fuser2, flNextPrimaryAttack)
	pev(Ent, pev_fuser4, flNextSound)
	
	if((iButton & IN_ATTACK) && g_Mode[id] != 2)
	{
		if(iClip)
		{
			laserfist_controlcharge(id, Ent)
			set_pdata_float(Ent, 46, SPEED, 4)
			set_pdata_float(Ent, 48, SPEED, 4)
			
			MakeMuzzleFlash(id, 1, 0.05,  "mff", MUZZLE_FLASH)
			MakeMuzzleFlash(id, 2, 0.05,  "mff", MUZZLE_FLASH)
			
			g_Mode[id] = 1
			TempEntity(id, 0)
			TempEntity(id, 1)
			
			if(flNextSound < fCurTime)
			{
				emit_sound(id, CHAN_WEAPON, "weapons/laserfist_shoota-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
				set_pev(Ent, pev_fuser4, fCurTime + 0.03)
			}
			
			if(flNextPrimaryAttack < fCurTime)
			{
				set_weapon_anim(id, ANIM_SHOOTA_LOOP)
				set_pev(Ent, pev_fuser2, fCurTime + 0.75)
			}
			
			ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
		}
		
		if(!iClip)
		{
			if(flNextPrimaryAttack < fCurTime)
			{
				set_weapon_anim(id, ANIM_SHOOTA_EMPTY_LOOP)
				set_pev(Ent, pev_fuser2, fCurTime + 0.75)
				emit_sound(id, CHAN_WEAPON, "weapons/laserfist_shoota_empty_loop.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
			laserfist_controlcharge(id, Ent)
		}
	}
	
	if((iButton & IN_ATTACK2) && iState2 && g_Mode[id] != 1)
	{
		g_Mode[id] = 2
		set_pev(Ent, pev_iuser1, 0)
				
		switch(iState)
		{
			case 0:
			{
				set_weapon_anim(id, ANIM_SHOOTB_READY)
					
				set_pev(Ent, pev_iuser1, 1)
				set_pev(Ent, pev_iuser3, 1)
				set_pev(Ent, pev_fuser2, get_gametime() + 1.35)
				set_pev(Ent, pev_fuser3, get_gametime() + 1.0)
				
				set_pdata_float(Ent ,46, 1.3, 4)
				set_pdata_float(Ent ,48, 1.35, 4)
			}
			case 1, 2:
			{
				remove_entity_name("mff")
				
				if(iState == 1)
				{
					MakeMuzzleFlash(id, 1, 0.2, "mf1", "sprites/muzzleflash91.spr")
					MakeMuzzleFlash(id, 2, 0.2, "mf1", "sprites/muzzleflash91.spr")
				}
				
				set_pev(Ent, pev_iuser1, 2)
				set_pev(Ent, pev_iuser3, 0)
				
				if(flNextPrimaryAttack < fCurTime)
				{
					set_weapon_anim(id, ANIM_SHOOTB_LOOP)
					set_pev(Ent, pev_fuser2, fCurTime + 1.05)
				}
				set_pdata_float(Ent, 48, 1.05, 4)
			}
		}
	}
	return HAM_IGNORED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Laserfist, id))
		return HAM_IGNORED	

	g_Laserfist_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_LASERFIST)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(g_Mode[id] == 2)
		return HAM_SUPERCEDE
	if(BPAmmo <= 0 || iClip >= CLIP)
		return HAM_SUPERCEDE
			
	g_Laserfist_Clip[id] = iClip
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Laserfist, id))
		return HAM_IGNORED	
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Laserfist_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Laserfist_Clip[id], 4)
		set_weapon_anim(id, ANIM_RELOAD)
		set_pdata_string(id, (492) * 4, PLAYER_ANIMEXT, -1 , 20)
		
		set_pdata_float(ent, 46, 3.0, 4)
		set_pdata_float(ent, 48, 3.0, 4)
		set_pdata_float(id, 83, 3.0, 5)
	}
	
	return HAM_HANDLED
}

public fw_MF_Think(ent)
{
	if(!pev_valid(ent))
		return
	
	static Classname[32]
	pev(ent, pev_classname, Classname, sizeof(Classname))
	
	new id = pev(ent, pev_owner)
	
	if(equal(Classname, "mf1") || equal(Classname, "mf2") || equal(Classname, "mff"))
	{
		if(!is_user_alive(id) || get_user_weapon(id) != CSW_LASERFIST)
		{
			set_pev(ent, pev_flags, FL_KILLME)
			return
		}
		
		static Float:fFrame, Float:fFrameMax
		pev(ent, pev_frame, fFrame)
		fFrameMax = float(engfunc(EngFunc_ModelFrames, pev(ent, pev_modelindex)))
		
		if(equal(Classname, "mf1")) fFrame += 0.2
		else if(equal(Classname, "mf2")) fFrame += 0.5
		else if(equal(Classname, "mff")) fFrame += 1.5
		set_pev(ent, pev_frame, fFrame)
		
		if(fFrame >= fFrameMax)
		{
			if(equal(Classname, "mf1")) fFrame = 0.0;
			else
			{
				set_pev(ent, pev_flags, FL_KILLME)
				return
			}
		}
		set_pev(ent, pev_nextthink, get_gametime() + 0.01)
	}
	
	if(equal(Classname, "anjeeeeenngg"))
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(ent)
		write_short(g_Beam_SprID_blue)
		write_byte(1)
		write_byte(2)
		write_byte(200)
		write_byte(200)
		write_byte(200)
		write_byte(200)
		message_end()
		
		set_pev(ent, pev_nextthink, get_gametime() + 0.01)
	}
}

public fw_MF_Touch(iEnt,iPtd)
{
	if(!pev_valid(iEnt))
		return HAM_IGNORED
	
	static Classname[32]
	pev(iEnt, pev_classname, Classname, sizeof(Classname))
	
	if(equal(Classname, "anjeeeeenngg"))
	{
		new id, Float:Origin[3]
		id = pev(iEnt, pev_owner)
		pev(iEnt, pev_origin, Origin)
		
		if(!iPtd)
		{
			Make_BulletHole(id, Origin, get_pcvar_float(cvar_dmg_a))
			
			engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, Origin, 0)
			write_byte(TE_EXPLOSION)
			engfunc(EngFunc_WriteCoord, Origin[0])
			engfunc(EngFunc_WriteCoord, Origin[1])
			engfunc(EngFunc_WriteCoord, Origin[2] - 10.0)
			write_short(g_SmokePuff_SprId)
			write_byte(2)
			write_byte(50)
			write_byte(TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOPARTICLES|TE_EXPLFLAG_NOSOUND)
			message_end()
		}
		set_pev(iEnt, pev_flags, FL_KILLME)
	}
	return HAM_IGNORED
}

public MakeMuzzleFlash(id, iBody, Float:iSize, szclassname[], cache_muf[]) //Thx Asdian DX
{
	static iMuz
	iMuz = Stock_CreateEntityBase(id, "env_sprite", MOVETYPE_FOLLOW, cache_muf, szclassname, SOLID_BBOX,0.01)
	set_pev(iMuz, pev_body, iBody)
	set_pev(iMuz, pev_owner, id)
	set_pev(iMuz, pev_rendermode, kRenderTransAdd)
	set_pev(iMuz, pev_renderamt, 255.0)
	set_pev(iMuz, pev_aiment, id)
	set_pev(iMuz, pev_scale, iSize)
	set_pev(iMuz, pev_frame, 0.0)
	dllfunc(DLLFunc_Spawn, iMuz)
}

public Check_Damage(id, right, blue)
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:EndOrigin2[3], Float:EndOrigin3[3]
	Stock_Get_Postion(id, 24.0, right ? 7.5 : -7.5, -3.0, StartOrigin)
	Stock_Get_Postion(id, 4096.0, right ? 5.5 : -5.5, 6.0, EndOrigin)
	fm_get_aim_origin(id, EndOrigin3)
	
	static TrResult; TrResult = create_tr2()
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, IGNORE_MONSTERS, id, TrResult) 
	get_tr2(TrResult, TR_vecEndPos, EndOrigin2)
	free_tr2(TrResult)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, StartOrigin[0])
	engfunc(EngFunc_WriteCoord, StartOrigin[1])
	engfunc(EngFunc_WriteCoord, StartOrigin[2])
	engfunc(EngFunc_WriteCoord, EndOrigin3[0])
	engfunc(EngFunc_WriteCoord, EndOrigin3[1])
	engfunc(EngFunc_WriteCoord, EndOrigin3[2])
	write_short(g_Beam_SprID)
	write_byte(5)		// byte (starting frame) 
	write_byte(480)		// byte (frame rate in 0.1's) 
	write_byte(5)		// byte (life in 0.1's) 
	write_byte(100)		// byte (line width in 0.1's) 
	write_byte(0)		// byte (noise amplitude in 0.01's) 
	write_byte(200)		// byte,byte,byte (color) (R)
	write_byte(200)		// (G)
	write_byte(200)		// (B)
	write_byte(200)		// byte (brightness)
	write_byte(0)		// byte (scroll speed in 0.1's)
	message_end()
	
	if(!right)
	{
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, EndOrigin2, 0)
		write_byte(TE_EXPLOSION)
		engfunc(EngFunc_WriteCoord, EndOrigin3[0])
		engfunc(EngFunc_WriteCoord, EndOrigin3[1])
		engfunc(EngFunc_WriteCoord, EndOrigin3[2])
		write_short(g_exp2)
		write_byte(10)//size
		write_byte(35)//framerate
		write_byte(TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NOPARTICLES)
		message_end()
	}
	
	new pEntity = -1
	while((pEntity = engfunc(EngFunc_FindEntityInSphere, pEntity, EndOrigin3, 10.0)) != 0)
	{
		if(pev(pEntity, pev_takedamage) == DAMAGE_NO) continue
		if(is_user_connected(pEntity) && pEntity != id)
			if(!can_damage(pEntity, id)) continue
		if(pEntity == id) continue
		
		if(pev_valid(pEntity))
		{
			ExecuteHamB(Ham_TakeDamage, pEntity, id, id, get_pcvar_float(cvar_dmg_b), DMG_BULLET)
				
			Stock_Fake_KnockBack(id, pEntity, get_pcvar_float(cvar_dmg_kb))
			if(is_user_alive(pEntity)) SpawnBlood(EndOrigin3, get_pdata_int(pEntity,89), floatround(get_pcvar_float(cvar_dmg_b)/5.0))
		}
	}
}
stock can_damage(id1, id2)
{
	if(id1 <= 0 || id1 >= 33 || id2 <= 0 || id2 >= 33)
		return 1
		
	// Check team
	return(get_pdata_int(id1, 114) != get_pdata_int(id2, 114))
}
stock SpawnBlood(const Float:vecOrigin[3], iColor, iAmount)
{
	if(iAmount == 0)
		return

	if (!iColor)
		return

	iAmount *= 2
	if(iAmount > 255) iAmount = 255
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin)
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, vecOrigin[0])
	engfunc(EngFunc_WriteCoord, vecOrigin[1])
	engfunc(EngFunc_WriteCoord, vecOrigin[2])
	write_short(spr_blood_spray)
	write_short(spr_blood_drop)
	write_byte(iColor)
	write_byte(min(max(3, iAmount / 10), 16))
	message_end()
}

public Stock_Fake_KnockBack(id, iVic, Float:iKb)
{
	if(iVic > 32) return
	
	new Float:vAttacker[3], Float:vVictim[3], Float:vVelocity[3], flags
	pev(id, pev_origin, vAttacker)
	pev(iVic, pev_origin, vVictim)
	vAttacker[2] = vVictim[2] = 0.0
	flags = pev(id, pev_flags)
	
	xs_vec_sub(vVictim, vAttacker, vVictim)
	new Float:fDistance
	fDistance = xs_vec_len(vVictim)
	xs_vec_mul_scalar(vVictim, 1 / fDistance, vVictim)
	
	pev(iVic, pev_velocity, vVelocity)
	xs_vec_mul_scalar(vVictim, iKb, vVictim)
	xs_vec_mul_scalar(vVictim, 50.0, vVictim)
	vVictim[2] = xs_vec_len(vVictim) * 0.15
	
	if(flags &~ FL_ONGROUND)
	{
		xs_vec_mul_scalar(vVictim, 1.2, vVictim)
		vVictim[2] *= 0.4
	}
	if(xs_vec_len(vVictim) > xs_vec_len(vVelocity)) set_pev(iVic, pev_velocity, vVictim)
}	

stock TempEntity(id, body)
{
	static Float:vAvel[3], Float:vAngle[3], Float:vVelocity[3],Float:fOrigin2[3], Float:vPlayerVelocity[3];
	if(body) Stock_Get_Postion(id, -14.0, random_float(5.5, 9.5), random_float(-7.5, -2.0), fOrigin2)
	else Stock_Get_Postion(id, -14.0, random_float(-5.5, -9.5), random_float(-7.5, -2.0), fOrigin2)
	pev(id, pev_velocity, vPlayerVelocity);
	
	Stock_GetSpeedVector(fOrigin2, g_End, 3499.8, vVelocity);
	xs_vec_add(vVelocity, vPlayerVelocity, vVelocity);
	
	vector_to_angle(vVelocity, vAngle)
	if(vAngle[0] > 90.0) vAngle[0] = -(360.0 - vAngle[0]);
	
	new iFlame = Stock_CreateEntityBase(id, "info_target", MOVETYPE_FLY, "models/w_usp.mdl", "anjeeeeenngg", SOLID_BBOX, 0.01)
	set_pev(iFlame ,pev_origin, fOrigin2)
	set_pev(iFlame ,pev_angles, vAngle)
	set_pev(iFlame, pev_rendermode, kRenderTransAdd)
	
	vAvel[2] = random_float(-200.0, 200.0)
	set_pev(iFlame, pev_avelocity, vAvel)
	set_pev(iFlame, pev_velocity, vVelocity)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(iFlame)
	write_short(g_Beam_SprID_blue)
	write_byte(1) // life
	write_byte(2) // width
	write_byte(200) // rgba
	write_byte(200)
	write_byte(200)
	write_byte(200)
	message_end()
}

stock Stock_CreateEntityBase(id, classtype[], mvtyp, mdl[], class[], solid, Float:fNext)
{
	new pEntity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, classtype))
	set_pev(pEntity, pev_movetype, mvtyp);
	set_pev(pEntity, pev_owner, id);
	engfunc(EngFunc_SetModel, pEntity, mdl);
	set_pev(pEntity, pev_classname, class);
	set_pev(pEntity, pev_solid, solid);
	set_pev(pEntity, pev_nextthink, get_gametime() + fNext)
	return pEntity
}

stock Stock_GetSpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	xs_vec_sub(origin2, origin1, new_velocity)
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	xs_vec_mul_scalar(new_velocity, num, new_velocity)
}

stock Stock_Get_Postion(id,Float:forw,Float:right, Float:up,Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
} 

// Drop primary/secondary weapons
stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32]; get_weaponname(weaponid, wname, charsmax(wname))
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Make_BulletHole(id, Float:Origin[3], Float:Damage)
{
	// Find target
	static Decal; Decal = random_num(41, 45)
	static LoopTime; 
	
	if(Damage > 100.0) LoopTime = 2
	else LoopTime = 1
	
	for(new i = 0; i < LoopTime; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(Decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(Decal)
		message_end()
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
