#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>
#include <zombieplague>
#include <zp43_armas>

#define PLUGIN "Infinity Laser Fist"
#define VERSION "Counter Strike 1.6"
#define AUTHOR "Mellowzy"

#define CLIP 100
#define BPAMMO 1500
#define SPEED 0.04

#define CSW_LASERFIST CSW_M249
#define weapon_laserfist "weapon_m249"
#define PLAYER_ANIMEXT "dualpistols"
#define LASERFIST_OLDMODEL "models/w_m249.mdl"
#define weapon_event "events/m249.sc"

#define V_MODEL "models/v_laserfist.mdl"
#define V_MODEL2 "models/v_laserfist2.mdl"
#define P_MODEL "models/p_laserfist.mdl"
#define W_MODEL "models/w_laserfist.mdl"

new const laserfist_Sounds[][] = 
{
	"weapons/laserfist_clipin1.wav",
	"weapons/laserfist_shoota_empty_end.wav",
	"weapons/laserfist_shoota_empty_loop.wav",
	"weapons/laserfist_shoota-1.wav",
	"weapons/laserfist_shootb_exp.wav",
	"weapons/laserfist_shootb_ready.wav",
	"weapons/laserfist_shootb_shoot.wav",
	"weapons/laserfist_shootb-1.wav"
}

#define MUZZLE_FLASH "sprites/muzzleflash92.spr"

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

new g_Had_Laserfist, g_Laserfist_Clip[33], AmmoLimit[33]
new g_Event_Laserfist, g_Msg_WeaponList, g_Beam_SprID,g_Beam_SprID_blue, g_exp2
new cvar_dmg_a, cvar_dmg_b, g_item

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	
	register_forward(FM_UpdateClientData,"fw_UpdateClientData_Post", 1)	//
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	//
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")//

	RegisterHam(Ham_Spawn, "player", "player_spawn", 1);
	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_laserfist, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Think, "env_sprite", "fw_MF_Think")
	//register_think("env_sprite", "fw_MF_Think");
	//RegisterHam(Ham_Weapon_PrimaryAttack, weapon_laserfist, "fw_Weapon_PrimaryAttack")
	//RegisterHam(Ham_Weapon_PrimaryAttack, weapon_laserfist, "fw_Weapon_PrimaryAttack_Post", 1)	
	RegisterHam(Ham_Item_Deploy, weapon_laserfist, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_laserfist, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_laserfist, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_laserfist, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_laserfist, "fw_Weapon_Reload_Post", 1)	
	register_logevent("event_round_start", 2, "1=Round_Start")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	cvar_dmg_a = register_cvar("laserfist_dmg_a", "35.0")
	cvar_dmg_b = register_cvar("laserfist_dmg_b", "400.0")
	
	g_Msg_WeaponList = get_user_msgid("WeaponList")
	register_clcmd(weapon_laserfist, "Hook_Weapon")

	g_item = zp_arma("CSO LaserInfinity", 0, 10, PRIMARIA, ADMIN_IMMUNITY, "[ GOLD ]")
}

public player_spawn( id )
{
	Remove_Laserfist(id)
}

public event_round_start()
{
	for(new i=1; i<= 32; ++i)
		Remove_Laserfist(i)

}
public zp_user_humanized_post(id, survivor){
	Remove_Laserfist(id)
}
public zp_user_infected_post(id, infector, nemesis){
	Remove_Laserfist(infector)
}

public dar_arma(id, item)
{
	if( g_item != item )
		return;

	Get_Laserfist(id)
}
public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, V_MODEL2)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, MUZZLE_FLASH)
	
	new i
	for(i = 0; i < sizeof(laserfist_Sounds); i++)
		engfunc(EngFunc_PrecacheSound, laserfist_Sounds[i])
	g_Beam_SprID = engfunc(EngFunc_PrecacheModel, "sprites/ef_laserfist_laserbeam.spr")
	g_Beam_SprID_blue = engfunc(EngFunc_PrecacheModel, "sprites/ef_laserfist_laser.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	
	// Muzzleflash
	g_exp2 = precache_model("sprites/ef_laserfist_laser_explosion.spr")
	precache_model("sprites/muzzleflash91.spr")
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(weapon_event, name)) g_Event_Laserfist = get_orig_retval()		
}

public plugin_natives()
{
	register_native("get_lfist", "native_get_lfist", 1)
	register_native("remove_lfist", "native_remove_lfist", 1)
}
public native_get_lfist(id) Get_Laserfist(id)
public native_remove_lfist(id)Remove_Laserfist(id)

public client_connect(id)Remove_Laserfist(id)
public client_disconnected(id)Remove_Laserfist(id)
public Get_Laserfist(id)
{
	if(!is_user_alive(id))
		return
	
	drop_weapons(id, 1)
	Set_BitVar(g_Had_Laserfist, id)
	fm_give_item(id, weapon_laserfist)
	AmmoLimit[id] = 0
	static Ent;
	Ent = fm_get_user_weapon_entity(id, CSW_LASERFIST)
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
	
	/*new const szTargetNames[ ][ ] =
	{
	    "mff",
	    "mf1",
	    "mf2"
	}

	new iEnt;

	for( new i = 0; i < sizeof( szTargetNames ); i++ )
	{
	    iEnt = -1;
	    
	    while( (iEnt = find_ent_by_class(iEnt, szTargetNames[i])) )
	    {
	    	set_pev(iEnt, pev_flags, FL_KILLME)
	    	remove_entity(iEnt);
	        //....
	    } 
	}*/

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
	if(get_user_weapon(id) == CSW_LASERFIST && Get_BitVar(g_Had_Laserfist, id)){
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
			engfunc(EngFunc_SetModel, entity, LASERFIST_OLDMODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	static Ent;
	Ent = fm_get_user_weapon_entity(id, CSW_LASERFIST)
	if(!is_user_alive(id) || !pev_valid(Ent))
		return FMRES_IGNORED	
	if(!Get_BitVar(g_Had_Laserfist, id) || get_user_weapon(id) != CSW_LASERFIST)	
		return FMRES_IGNORED
		
	static PressButton; PressButton = get_uc(uc_handle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	new iClip = get_pdata_int(Ent, 51, 4)
	new iState = pev(Ent, pev_iuser1)
	new iState2 = pev(Ent, pev_iuser2)
	new iState3 = pev(Ent, pev_iuser3)
	new Float:flTime; pev(Ent, pev_fuser2, flTime)
	
	if(iState3 == 1 && flTime && flTime < get_gametime())
	{
		MakeMuzzleFlash(id, 1, 0.2, "mf1", "sprites/muzzleflash91.spr")
		MakeMuzzleFlash(id, 2, 0.2, "mf1", "sprites/muzzleflash91.spr")
		set_pev(Ent, pev_fuser2, 0.0)
	}

	if(PressButton & IN_ATTACK)
	{
		if(get_pdata_float(Ent, 46, 4) > 0.0 || get_pdata_float(Ent, 47, 4) > 0.0)
			return FMRES_IGNORED
			
		if(iClip){
			laserfist_controlcharge(id)
			MakeMuzzleFlash(id, 1, 0.05,  "mff", MUZZLE_FLASH)
			MakeMuzzleFlash(id, 2, 0.05,  "mff", MUZZLE_FLASH)
			Check_Damage(id, 1, 1)
			Check_Damage(id, 0, 1)
			if(get_pdata_float(id, 83, 5) <= 0.1)
			{
				set_weapon_anim(id, ANIM_SHOOTA_LOOP)
				set_pdata_float(id, 83, 0.75, 5)
			}
			emit_sound(id, CHAN_WEAPON, "weapons/laserfist_shoota-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
			set_pev(id, pev_punchangle, Float:{0.0, 0.0, 0.0 })
		}
		
		if(!iClip){
			if(get_pdata_float(id, 83, 5) <= 0.1)
			{
				set_weapon_anim(id, ANIM_SHOOTA_EMPTY_LOOP)
				set_pdata_float(id, 83, 0.75, 5)
				emit_sound(id, CHAN_WEAPON, "weapons/laserfist_shoota_empty_loop.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
			laserfist_controlcharge(id)
			return FMRES_IGNORED
		}
	} else {
		if(OldButton & IN_ATTACK)
		{
			set_weapon_anim(id, !iClip ? ANIM_SHOOTA_EMPTY_END : ANIM_SHOOTA_END)
			set_pdata_float(Ent, 46, 0.5, 4)
			set_pdata_float(Ent, 48, 1.0, 4)
		}
	}
	if(PressButton & IN_ATTACK2){
		if(get_pdata_float(id, 83, 5) > 0.0) return FMRES_IGNORED
		if(!iState2) return FMRES_IGNORED
		
		switch(iState)
		{
			case 0:
			{
				set_pdata_float(id, 83, 0.22, 5)
				set_pdata_float(Ent ,48, 2.0, 4)
				set_pev(Ent, pev_iuser1, 1)
			}
			case 1:
			{
				set_weapon_anim(id, ANIM_SHOOTB_READY)
				set_pev(Ent, pev_iuser3, 1)
				set_pev(Ent, pev_fuser2, get_gametime() + get_pdata_float(id, 83)+1.0)
				set_pdata_float(id, 83, 2.0, 5)
				set_pdata_float(Ent ,48, 2.0, 4)
				set_pev(Ent, pev_iuser1, 2)
			}
			case 2:
			{
				set_weapon_anim(id, ANIM_SHOOTB_LOOP)
				remove_entity_name("mff")
				set_pev(Ent, pev_iuser3, 0)
				MakeMuzzleFlash(id, 1, 0.2, "mf1", "sprites/muzzleflash91.spr")
				MakeMuzzleFlash(id, 2, 0.2, "mf1", "sprites/muzzleflash91.spr")
				set_pdata_float(id, 83, 120.0, 5)
				set_pdata_float(Ent ,48, 2.0, 4)
			}
		}
	} else {
		if(OldButton & IN_ATTACK2)
		{
			if(!iState2)
				return FMRES_IGNORED
			
			if(iState == 2){
					
				set_weapon_anim(id, ANIM_SHOOTB_SHOOT)
				MakeMuzzleFlash(id, 1, 0.08,  "mf2", "sprites/ef_laserfist_laser_explosion.spr")
				MakeMuzzleFlash(id, 2, 0.08,  "mf2", "sprites/ef_laserfist_laser_explosion.spr")
				
				Check_Damage(id, 1, 0)
				Check_Damage(id, 0, 0)
				remove_entity_name("mf1")
				set_pev(id, pev_viewmodel2, V_MODEL)
				AmmoLimit[id] = 0
				set_pev(Ent, pev_iuser1, 0)
				set_pev(Ent, pev_iuser2, 0)
				set_pev(Ent, pev_iuser3, 0)
				Set_Player_NextAttack(id, CSW_LASERFIST, 1.7)
				emit_sound(id, CHAN_WEAPON, "weapons/laserfist_shootb-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
	}
			
			
	PressButton &= ~IN_ATTACK
	PressButton &= ~IN_ATTACK2
	set_uc(uc_handle, UC_Buttons, PressButton)
	return FMRES_HANDLED;
}
public laserfist_controlcharge(id)
{
	static Ent;
	Ent = fm_get_user_weapon_entity(id, CSW_LASERFIST)
	if(!is_user_alive(id) || !pev_valid(Ent))
		return	
	if(!Get_BitVar(g_Had_Laserfist, id) || get_user_weapon(id) != CSW_LASERFIST)	
		return
		
	if(AmmoLimit[id] < 40)
	{
		AmmoLimit[id] ++
	}
	if(AmmoLimit[id] >= 40){
		set_pev(id, pev_viewmodel2, V_MODEL2)
		set_pev(Ent, pev_iuser2, 1)
	}
}

public fw_MF_Think(ent)
{
	if(!is_valid_ent(ent))
		return
	
	static Classname[32]
	//entity_get_string(touched, EV_SZ_classname, szClass, 9)
	pev(ent, pev_classname, Classname, sizeof(Classname))
	static Owner; Owner = pev(ent, pev_owner)

	if(!Get_BitVar(g_Had_Laserfist, Owner) && equal(Classname, "mf1")
		|| !Get_BitVar(g_Had_Laserfist, Owner) && equal(Classname, "mf2")
		|| !Get_BitVar(g_Had_Laserfist, Owner) && equal(Classname, "mff")){
		set_pev(ent, pev_flags, FL_KILLME)
		return;
	}
		
	
	if(!Get_BitVar(g_Had_Laserfist, Owner))
		return;

	if(!is_user_alive(Owner) || get_user_weapon(Owner) != CSW_LASERFIST)
	{
		set_pev(ent, pev_flags, FL_KILLME)
		return
	}

	if(equal(Classname, "mf1"))
	{
		static Float:fFrame, Float:fFrameMax
		pev(ent, pev_frame, fFrame)
		
		fFrameMax = 29.0
		
		fFrame += 0.2
		set_pev(ent, pev_frame, fFrame)
		
		if(fFrame >= fFrameMax) 
		{
			fFrame = 0.0;
		}
	}
	if(equal(Classname, "mf2"))
	{
		static Float:fFrame, Float:fFrameMax
		pev(ent, pev_frame, fFrame)
		
		fFrameMax = 29.0
		
		fFrame += 0.5
		set_pev(ent, pev_frame, fFrame)
		
		if(fFrame >= fFrameMax) 
		{
			set_pev(ent, pev_flags, FL_KILLME)
			return
		}
	}
	if(equal(Classname, "mff"))
	{
		static Float:fFrame, Float:fFrameMax
		pev(ent, pev_frame, fFrame)
		
		fFrameMax = 14.0
		
		fFrame += 1.5
		set_pev(ent, pev_frame, fFrame)
		
		if(fFrame >= fFrameMax) 
		{
			set_pev(ent, pev_flags, FL_KILLME)
			return
		}
	}
	set_pev(ent, pev_nextthink, get_gametime() + 0.01)
}
public MakeMuzzleFlash(id, iBody, Float:iSize, szclassname[], cache_muf[])//Thx Asdian DX
{
	static iMuz
	iMuz = Stock_CreateEntityBase(id, "env_sprite", MOVETYPE_FOLLOW, cache_muf, szclassname, SOLID_NOT,0.01)
	set_pev(iMuz, pev_body, iBody)
	set_pev(iMuz, pev_owner, id)
	set_pev(iMuz, pev_rendermode, kRenderTransAdd)
	set_pev(iMuz, pev_renderamt, 255.0)
	set_pev(iMuz, pev_aiment, id)
	set_pev(iMuz, pev_scale, iSize)
	set_pev(iMuz, pev_frame, 0.0)
	dllfunc(DLLFunc_Spawn, iMuz)
}

public fw_Weapon_PrimaryAttack(Ent)
{
	static id; id = pev(Ent, pev_owner)
	new iClip = get_pdata_int(Ent, 51, 4)
	if(!iClip)
		return 
	if(!Get_BitVar(g_Had_Laserfist, id)) return 
	
	/*if(!iClip)
		return HAM_IGNORED*/
	
	//return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	if(!Get_BitVar(g_Had_Laserfist, id)) return/* HAM_IGNORED*/
	
	//return HAM_IGNORED
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED	
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED	
	if(!Get_BitVar(g_Had_Laserfist, Id))
		return HAM_IGNORED	
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		set_weapon_anim(Id, ANIM_IDLE)
		
		set_pdata_float(Ent, 48, 4.0, 4)
		set_pdata_string(Id, (492) * 4, PLAYER_ANIMEXT, -1 , 20)
	}
	
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
	
	set_weapon_anim(Id, ANIM_DRAW)
	Set_Player_NextAttack(Id, CSW_LASERFIST, 1.7)
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, .player = Id)
	write_string(Get_BitVar(g_Had_Laserfist, Id) ? weapon_laserfist : weapon_laserfist)
	write_byte(3) // PrimaryAmmoID
	write_byte(200) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Laserfist, Id) ? CSW_LASERFIST : CSW_M249) // WeaponID
	write_byte(0) // Flags
	message_end()
	
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
		return
		
	if(pev(Ent, pev_impulse) == 1712015)
	{
		Set_BitVar(g_Had_Laserfist, id)
		set_pev(Ent, pev_impulse, 0)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Laserfist, id) ? weapon_laserfist : weapon_laserfist)
	write_byte(3) // PrimaryAmmoID
	write_byte(200) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Laserfist, id) ? CSW_LASERFIST : CSW_M249) // WeaponID
	write_byte(0) // Flags
	message_end()

	//return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return
	if(!Get_BitVar(g_Had_Laserfist, id))
		return	
	
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
	
	//return
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
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Laserfist_Clip[id] = iClip	
	
	return HAM_IGNORED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return/* HAM_IGNORED*/
	if(!Get_BitVar(g_Had_Laserfist, id))
		return/* HAM_IGNORED*/	
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Laserfist_Clip[id] == -1)
			return/* HAM_IGNORED*/
		
		set_pdata_int(ent, 51, g_Laserfist_Clip[id], 4)
		set_weapon_anim(id, ANIM_RELOAD)
		Set_Player_NextAttack(id, CSW_LASERFIST, 3.0)
	}
	
	//return/* HAM_HANDLED*/
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

	SetHamParamFloat(3, get_pcvar_float(cvar_dmg_a))
	
	return HAM_SUPERCEDE
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_LASERFIST || !Get_BitVar(g_Had_Laserfist, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, get_pcvar_float(cvar_dmg_a))
	
	return HAM_SUPERCEDE
}
public Check_Damage(id, right, blue)
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:EndOrigin2[3]
	
	if(right)
	{
		Stock_Get_Postion(id, 30.0, 7.5, -3.0, StartOrigin)
		Stock_Get_Postion(id, 4096.0, 5.5, 6.0, EndOrigin)
	} else {
		Stock_Get_Postion(id, 30.0, -7.5, -3.0, StartOrigin)
		Stock_Get_Postion(id, 4096.0, -5.5, 6.0, EndOrigin)
	}
	
	static TrResult; TrResult = create_tr2()
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, IGNORE_MONSTERS, id, TrResult) 
	get_tr2(TrResult, TR_vecEndPos, EndOrigin2)
	free_tr2(TrResult)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, StartOrigin[0])
	engfunc(EngFunc_WriteCoord, StartOrigin[1])
	engfunc(EngFunc_WriteCoord, StartOrigin[2])
	engfunc(EngFunc_WriteCoord, EndOrigin2[0])
	engfunc(EngFunc_WriteCoord, EndOrigin2[1])
	engfunc(EngFunc_WriteCoord, EndOrigin2[2])
	write_short(blue == 1 ? g_Beam_SprID_blue : g_Beam_SprID)
	write_byte(0)		// byte (starting frame) 
	write_byte(blue == 1 ? 10 : 500)		// byte (frame rate in 0.1's) 
	write_byte(blue == 1 ? 1 : 7)		// byte (life in 0.1's) 
	write_byte(blue == 1 ? 15 : 100)		// byte (line width in 0.1's) 
	write_byte(0)		// byte (noise amplitude in 0.01's) 
	write_byte(200)		// byte,byte,byte (color) (R)
	write_byte(200)		// (G)
	write_byte(200)		// (B)
	write_byte(200)		// byte (brightness)
	write_byte(blue == 1 ? 50 : 0)		// byte (scroll speed in 0.1's)
	message_end()
	
	if(!blue){
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, EndOrigin2, 0)
		write_byte(TE_EXPLOSION)
		engfunc(EngFunc_WriteCoord, EndOrigin2[0])
		engfunc(EngFunc_WriteCoord, EndOrigin2[1])
		engfunc(EngFunc_WriteCoord, EndOrigin2[2])
		write_short(g_exp2)
		write_byte(10)//size
		write_byte(35)//framerate
		write_byte(TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NOPARTICLES)
		message_end()
		
		DealDamage(id, StartOrigin, EndOrigin2, 1)
	}
	DealDamage(id, StartOrigin, EndOrigin2, 0)
}
public DealDamage(id, Float:Start[3], Float:End[3], dmgtype)
{
	static TrResult; TrResult = create_tr2()
	new iWeapon = fm_get_user_weapon_entity(id, CSW_LASERFIST)
	if(!pev_valid(iWeapon)) return
	// Trace First Time
	engfunc(EngFunc_TraceLine, Start, End, DONT_IGNORE_MONSTERS, id, TrResult) 
	new pHit1; pHit1 = get_tr2(TrResult, TR_pHit)
	static Float:End1[3]; get_tr2(TrResult, TR_vecEndPos, End1)
	
	if(is_user_alive(pHit1)) 
	{
		do_attack(id, pHit1, iWeapon, dmgtype == 1 ? get_pcvar_float(cvar_dmg_b) : get_pcvar_float(cvar_dmg_a))
		engfunc(EngFunc_TraceLine, End1, End, DONT_IGNORE_MONSTERS, pHit1, TrResult) 
	} else engfunc(EngFunc_TraceLine, End1, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Second Time
	new pHit2; pHit2 = get_tr2(TrResult, TR_pHit)
	static Float:End2[3]; get_tr2(TrResult, TR_vecEndPos, End2)
	
	if(is_user_alive(pHit2)) 
	{
		do_attack(id, pHit2, iWeapon, dmgtype == 1 ? get_pcvar_float(cvar_dmg_b) : get_pcvar_float(cvar_dmg_a))
		engfunc(EngFunc_TraceLine, End2, End, DONT_IGNORE_MONSTERS, pHit2, TrResult) 
	} else engfunc(EngFunc_TraceLine, End2, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Third Time
	new pHit3; pHit3 = get_tr2(TrResult, TR_pHit)
	static Float:End3[3]; get_tr2(TrResult, TR_vecEndPos, End3)
	
	if(is_user_alive(pHit3)) 
	{
		do_attack(id, pHit3, iWeapon, dmgtype == 1 ? get_pcvar_float(cvar_dmg_b) : get_pcvar_float(cvar_dmg_a))
		engfunc(EngFunc_TraceLine, End3, End, DONT_IGNORE_MONSTERS, pHit3, TrResult) 
	} else engfunc(EngFunc_TraceLine, End3, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Fourth Time
	new pHit4; pHit4 = get_tr2(TrResult, TR_pHit)
	if(is_user_alive(pHit4)) do_attack(id, pHit4, iWeapon, dmgtype == 1 ? get_pcvar_float(cvar_dmg_b) : get_pcvar_float(cvar_dmg_a))

	free_tr2(TrResult)
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
stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
}
do_attack(Attacker, Victim, Inflictor, Float:fDamage)
{
	fake_player_trace_attack(Attacker, Victim, fDamage)
	fake_take_damage(Attacker, Victim, fDamage, Inflictor)
}

fake_player_trace_attack(iAttacker, iVictim, &Float:fDamage)
{
	// get fDirection
	new Float:fAngles[3], Float:fDirection[3]
	pev(iAttacker, pev_angles, fAngles)
	angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection)
	
	// get fStart
	new Float:fStart[3], Float:fViewOfs[3]
	pev(iAttacker, pev_origin, fStart)
	pev(iAttacker, pev_view_ofs, fViewOfs)
	xs_vec_add(fViewOfs, fStart, fStart)
	
	// get aimOrigin
	new iAimOrigin[3], Float:fAimOrigin[3]
	get_user_origin(iAttacker, iAimOrigin, 3)
	IVecFVec(iAimOrigin, fAimOrigin)
	
	// TraceLine from fStart to AimOrigin
	new ptr; ptr = create_tr2() 
	engfunc(EngFunc_TraceLine, fStart, fAimOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr)
	new pHit; pHit = get_tr2(ptr, TR_pHit)
	new iHitgroup; iHitgroup = get_tr2(ptr, TR_iHitgroup)
	new Float:fEndPos[3]
	get_tr2(ptr, TR_vecEndPos, fEndPos)

	// get target & body at aiming
	new iTarget, iBody
	get_user_aiming(iAttacker, iTarget, iBody)
	
	// if aiming find target is iVictim then update iHitgroup
	if (iTarget == iVictim)
	{
		iHitgroup = iBody
	}
	
	// if ptr find target not is iVictim
	else if (pHit != iVictim)
	{
		// get AimOrigin in iVictim
		new Float:fVicOrigin[3], Float:fVicViewOfs[3], Float:fAimInVictim[3]
		pev(iVictim, pev_origin, fVicOrigin)
		pev(iVictim, pev_view_ofs, fVicViewOfs) 
		xs_vec_add(fVicViewOfs, fVicOrigin, fAimInVictim)
		fAimInVictim[2] = fStart[2]
		fAimInVictim[2] += get_distance_f(fStart, fAimInVictim) * floattan( fAngles[0] * 2.0, degrees )
		
		// check aim in size of iVictim
		new iAngleToVictim; iAngleToVictim = get_angle_to_target(iAttacker, fVicOrigin)
		iAngleToVictim = abs(iAngleToVictim)
		new Float:fDis; fDis = 2.0 * get_distance_f(fStart, fAimInVictim) * floatsin( float(iAngleToVictim) * 0.5, degrees )
		new Float:fVicSize[3]
		pev(iVictim, pev_size , fVicSize)
		if ( fDis <= fVicSize[0] * 0.5 )
		{
			// TraceLine from fStart to aimOrigin in iVictim
			new ptr2; ptr2 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fAimInVictim, DONT_IGNORE_MONSTERS, iAttacker, ptr2)
			new pHit2; pHit2 = get_tr2(ptr2, TR_pHit)
			new iHitgroup2; iHitgroup2 = get_tr2(ptr2, TR_iHitgroup)
			
			// if ptr2 find target is iVictim
			if ( pHit2 == iVictim && (iHitgroup2 != HIT_HEAD || fDis <= fVicSize[0] * 0.25) )
			{
				pHit = iVictim
				iHitgroup = iHitgroup2
				get_tr2(ptr2, TR_vecEndPos, fEndPos)
			}
			
			free_tr2(ptr2)
		}
		
		// if pHit still not is iVictim then set default HitGroup
		if (pHit != iVictim)
		{
			// set default iHitgroup
			iHitgroup = HIT_GENERIC
			
			new ptr3; ptr3 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fVicOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr3)
			get_tr2(ptr3, TR_vecEndPos, fEndPos)
			
			// free ptr3
			free_tr2(ptr3)
		}
	}
	
	// set new Hit & Hitgroup & EndPos
	set_tr2(ptr, TR_pHit, iVictim)
	set_tr2(ptr, TR_iHitgroup, iHitgroup)
	set_tr2(ptr, TR_vecEndPos, fEndPos)

	// ExecuteHam
	fake_trake_attack(iAttacker, iVictim, fDamage, fDirection, ptr)
	
	// free ptr
	free_tr2(ptr)
}

stock fake_trake_attack(iAttacker, iVictim, Float:fDamage, Float:fDirection[3], iTraceHandle, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TraceAttack, iVictim, iAttacker, fDamage, fDirection, iTraceHandle, iDamageBit)
}

stock fake_take_damage(iAttacker, iVictim, Float:fDamage, iInflictor, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TakeDamage, iVictim, iInflictor, iAttacker, fDamage, iDamageBit)
}

stock get_angle_to_target(id, const Float:fTarget[3], Float:TargetSize = 0.0)
{
	new Float:fOrigin[3], iAimOrigin[3], Float:fAimOrigin[3], Float:fV1[3]
	pev(id, pev_origin, fOrigin)
	get_user_origin(id, iAimOrigin, 3) // end position from eyes
	IVecFVec(iAimOrigin, fAimOrigin)
	xs_vec_sub(fAimOrigin, fOrigin, fV1)
	
	new Float:fV2[3]
	xs_vec_sub(fTarget, fOrigin, fV2)
	
	new iResult; iResult = get_angle_between_vectors(fV1, fV2)
	
	if (TargetSize > 0.0)
	{
		new Float:fTan; fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		new fAngleToTargetSize; fAngleToTargetSize = floatround( floatatan(fTan, degrees) )
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
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
stock get_angle_between_vectors(const Float:fV1[3], const Float:fV2[3])
{
	new Float:fA1[3], Float:fA2[3]
	engfunc(EngFunc_VecToAngles, fV1, fA1)
	engfunc(EngFunc_VecToAngles, fV2, fA2)
	
	new iResult; iResult = floatround(fA1[1] - fA2[1])
	iResult = iResult % 360
	iResult = (iResult > 180) ? (iResult - 360) : iResult
	
	return iResult
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

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock Set_Player_NextAttack(id, CSWID, Float:NextTime)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSWID)
	if(!pev_valid(Ent)) return
	
	set_pdata_float(id, 83, NextTime, 5)
	
	set_pdata_float(Ent, 46 , NextTime, 4)
	set_pdata_float(Ent, 47, NextTime, 4)
	set_pdata_float(Ent, 48, NextTime, 4)
}
