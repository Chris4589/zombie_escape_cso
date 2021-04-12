//Special Thank to:
//Bim Bim Cay: Code Optimized
//Asdian DX: FakeHand/View Entity (Velocity Way)
//Nexon: Resources

#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <zombieplague>
#include <zp43_armas>

#define PLUGIN "[Luna's Weapon] Dual Beretta Gunslinger"
#define VERSION "2.0.37"
#define AUTHOR "Celena Luna/Aoki Melodia"

#define V_MODEL "models/zombie_plague/v_gunkatav2.mdl"
#define P_MODEL "models/zombie_plague/p_gunkatav2.mdl"
#define W_MODEL "models/zombie_plague/w_gunkatav2.mdl"
#define EF_HOLE "models/zombie_plague/ef_hole.mdl"
#define EF_GUNKATA_SHADOW "models/zombie_plague/ef_gunkata_man2.mdl"

#define EXP_CLASSNAME "ef_hole_cso"

#define S_Shoot "weapons/gunkata-1.wav"

#define WeaponMuzzle "sprites/muzzleflash77.spr"

new const WeaponSkillSounds[7][] =
{
	"weapons/gunkata_skill_01.wav",
	"weapons/gunkata_skill_02.wav",
	"weapons/gunkata_skill_03.wav",
	"weapons/gunkata_skill_04.wav",
	"weapons/gunkata_skill_05.wav",
	"weapons/gunkata_skill_last.wav",
	"weapons/gunkata_skill_last_exp.wav"

}

#define SECRET_CODE 312512

#define CSW_GUNKATA CSW_USP

const PDATA_SAFE = 2
const OFFSET_LINUX_WEAPONS = 4
const OFFSET_WEAPONOWNER = 41

enum
{
	ANIM_IDLE = 0,
	ANIM_IDLE2,
	ANIM_SHOOT,
	ANIM_SHOOT_LAST,
	ANIM_SHOOT2,
	ANIM_SHOOT2_LAST,
	ANIM_RELOAD,
	ANIM_RELOAD2,
	ANIM_DRAW,
	ANIM_DRAW2,
	ANIM_SKILL1,
	ANIM_SKILL2,
	ANIM_SKILL3,
	ANIM_SKILL4,
	ANIM_SKILL5,
	ANIM_SKILL_END
}

#define DRAW_TIME 0.75
#define RELOAD_TIME 2.0

#define DAMAGEA 50
#define DAMAGEB 40
#define CLIP 36
#define SPEED 0.07
#define BPAMMO 400
#define SPEED_B 0.07
#define RECOIL 0.05
#define ATTACK_DISTANCE 200.0
#define KNOCKBACK_POWER 40.0

#define WEAPON_EVENT "events/usp.sc"
#define OLD_W_MODEL "models/w_usp.mdl"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_shoot_counter[33], g_Clip[33], g_skill_counter[33], Float:g_Recoil[33], g_Weapon
new g_dbg_event
new g_Had_Beretta, g_Shoot_R, g_InSpecial, g_StartSpecial, g_BlockReload, g_InSpecialReload, g_StopSpecial, g_Effect_Fake
new g_SmokePuff_SprId, g_Msg_AmmoX, g_Msg_CurWeapon, g_Msg_WeaponList, g_MaxPlayers
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_AddToFullPack, "Fw_AddToFullPack_Post", 1);
	register_forward(FM_SetModel, "fw_SetModel")

	RegisterHam(Ham_Item_Deploy, "weapon_usp", "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, "weapon_usp", "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, "weapon_usp", "fw_Item_PostFrame")
	RegisterHam(Ham_Weapon_Reload, "weapon_usp", "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, "weapon_usp", "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_usp", "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "fw_Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_usp", "fw_Weapon_SecondaryAttack")
	RegisterHam(Ham_Item_Holster, "weapon_usp", "fw_Item_Holster_Post", 1)
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World", 1)
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player", 1)
	register_logevent("event_round_start", 2, "1=Round_Start")
	register_forward(FM_Think, "Entity_Think")

	register_clcmd("weapon_gunkata", "Hook_Weapon")

	g_Msg_AmmoX = get_user_msgid("AmmoX")
	g_Msg_CurWeapon = get_user_msgid("CurWeapon")
	g_Msg_WeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()

	g_Weapon = zp_arma("Dual Beretta GunSlinger", 10, 5, SECUNDARIA, ADMIN_RESERVATION, "[STAFF]");
	//g_Weapon = zp_register_extra_item("Dual Beretta GunSlinger", COST, 0, ZP_TEAM_HUMAN)
}

public zp_player_spawn_post(id) Remove_Beretta(id)
public zp_user_infect_attempt(id) Remove_Beretta(id)

public event_round_start(){
	for(new i=1; i<= g_MaxPlayers; ++i)
		Remove_Beretta(i)
}
public Entity_Think(iEnt)
{
	if (!pev_valid(iEnt))
		return;
	if (pev(iEnt, pev_flags) & FL_KILLME)
		return;

	new classname[32], iOwner, Float:fEndTime, Float:fRenderAmount, Float:fFrame, Float:fOrigin[3];
	pev(iEnt, pev_classname, classname, 31);

	if(equal(classname, EXP_CLASSNAME))
	{
		fm_remove_entity(iEnt)
		return
	}

	if(equal(classname, "dbg_fakehand"))
	{
		iOwner = pev(iEnt, pev_owner)
		pev(iEnt, pev_fuser3, fEndTime)

		if(!is_user_alive(iOwner) || !is_user_connected(iOwner) || zp_get_user_zombie(iOwner) || get_user_weapon(iOwner) != CSW_GUNKATA || fEndTime == get_gametime())
		{
			fm_remove_entity(iEnt)
			return
		}

		new Float:vecAngle[3];
		Stock_Get_Postion(iOwner, 0.0, 0.0, 0.0, fOrigin);

		pev(iOwner, pev_v_angle, vecAngle);
		vecAngle[0] = -vecAngle[0];

		set_pev(iEnt, pev_origin, fOrigin);
		set_pev(iEnt, pev_angles, vecAngle);

		set_pev(iEnt, pev_nextthink, get_gametime() + 0.01)
	}

	if(equal(classname, "dbg_shadow"))
	{
		pev(iEnt, pev_fuser1, fEndTime)
		pev(iEnt, pev_renderamt, fRenderAmount);
		fRenderAmount -= 4.5;
		if (fRenderAmount <= 5.0)
		{
			fm_remove_entity(iEnt)
			return;
		}
		set_pev(iEnt, pev_renderamt, fRenderAmount);

		set_pev(iEnt, pev_nextthink, get_gametime()+0.01)
	}

	if(equal(classname, "weapon_muzzleflash"))
	{
		iOwner = pev(iEnt, pev_owner)
		pev(iEnt, pev_fuser1, fEndTime)

		if(!pev_valid(iEnt))
			return
		if(!Get_BitVar(g_Had_Beretta,iOwner) || get_user_weapon(iOwner) != CSW_GUNKATA || fEndTime <= get_gametime())
		{
			fm_remove_entity(iEnt)
			return
		}

		pev(iEnt, pev_frame, fFrame)

		pev(iOwner, pev_origin, fOrigin)

		engfunc(EngFunc_MessageBegin, MSG_ALL, SVC_TEMPENTITY, fOrigin, 0)
		write_byte(TE_DLIGHT)
		engfunc(EngFunc_WriteCoord,fOrigin[0])
		engfunc(EngFunc_WriteCoord,fOrigin[1])
		engfunc(EngFunc_WriteCoord,fOrigin[2])
		write_byte(3)
		write_byte(255)
		write_byte(187)
		write_byte(0)
		write_byte(2)
		write_byte(0)
		message_end()

		// effect exp
		fFrame += 1.0
		if(fFrame > 15.0) fFrame = 0.0

		set_pev(iEnt, pev_frame, fFrame)
		set_pev(iEnt, pev_scale, 0.06)
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.01)
	}
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	engfunc(EngFunc_PrecacheModel, EF_HOLE)
	engfunc(EngFunc_PrecacheModel, EF_GUNKATA_SHADOW)
	engfunc(EngFunc_PrecacheModel, WeaponMuzzle)


	precache_sound(S_Shoot)

	for(new i = 0; i < sizeof(WeaponSkillSounds); i++)
		precache_sound(WeaponSkillSounds[i])

	/*for(new i = 0; i < sizeof(Sub_Resources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, Sub_Resources[i])
		else  engfunc(EngFunc_PrecacheModel, Sub_Resources[i])
	}*/

	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")

	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(WEAPON_EVENT, name))
		g_dbg_event = get_orig_retval()
}

public Fw_AddToFullPack_Post(esState, iE, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
	if (!pev_valid(iEnt))
		return;
	if (pev(iEnt, pev_flags) & FL_KILLME)
		return;

	new classname[32];
	pev(iEnt, pev_classname, classname, 31);

	if (equal(classname,"dbg_fakehand"))
	{
		if (iHost != pev(iEnt, pev_owner))
			set_es(esState, ES_Effects, (get_es(esState, ES_Effects) | EF_NODRAW));
	}

	if (equal(classname,"dbg_shadow"))
	{
		if (iHost == pev(iEnt, pev_owner))
			set_es(esState, ES_Effects, (get_es(esState, ES_Effects) | EF_NODRAW));
	}
}

public dar_arma(id, itemid)
{
	if(itemid == g_Weapon)
		Get_Beretta(id)
}

public Get_Beretta(id)
{
	if(!is_user_alive(id))
		return

	Set_BitVar(g_Had_Beretta, id)
	UnSet_BitVar(g_InSpecial, id)
	UnSet_BitVar(g_StartSpecial, id)
	UnSet_BitVar(g_BlockReload, id)
	UnSet_BitVar(g_Effect_Fake, id)
	give_item(id, "weapon_usp")

	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_USP)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	cs_set_user_bpammo(id, CSW_USP, BPAMMO)

	g_skill_counter[id] = 0
	//update_ammo_hud(id)
}

public Remove_Beretta(id)
{
	UnSet_BitVar(g_Had_Beretta, id)
	UnSet_BitVar(g_Shoot_R, id)
	UnSet_BitVar(g_BlockReload, id)
	UnSet_BitVar(g_InSpecial, id)
	UnSet_BitVar(g_StartSpecial, id)
	g_skill_counter[id] = 0
	g_shoot_counter[id] = 0
	UnSet_BitVar(g_Effect_Fake, id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, "weapon_usp")
	return PLUGIN_HANDLED
}

public Get_Beretta2(id)
{
	//Make_FakeHand(id, ANIM_SKILL5, 5.0)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) == CSW_USP && Get_BitVar(g_Had_Beretta, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)

	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_alive(invoker))
		return FMRES_IGNORED
	if(!Get_BitVar(g_Had_Beretta, invoker))
		return FMRES_IGNORED

	if(eventid == g_dbg_event)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		if(!Get_BitVar(g_InSpecial, invoker))
		{
			if(Get_BitVar(g_Shoot_R, invoker))
			{
				if(g_shoot_counter[invoker] == 2) set_weapon_anim(invoker, ANIM_SHOOT2_LAST)
				else set_weapon_anim(invoker, ANIM_SHOOT2)
				Stock_Muzzle(invoker, 3)
			}
			else
			{
				if(g_shoot_counter[invoker] == 2) set_weapon_anim(invoker, ANIM_SHOOT_LAST)
				else set_weapon_anim(invoker, ANIM_SHOOT)
				Stock_Muzzle(invoker, 1)
			}

			emit_sound(invoker, CHAN_WEAPON, S_Shoot, 1.0, 0.4, 0, 94 + random_num(0, 15))
		}
		else
		{
			static ent
			ent = fm_get_user_weapon_entity(invoker, CSW_USP)
			if(g_shoot_counter[invoker] == 2) Weapon_Skill(invoker, ent)
		}

		if(g_shoot_counter[invoker] == 2)
		{
			g_shoot_counter[invoker] = 0
			if(Get_BitVar(g_Shoot_R, invoker))	UnSet_BitVar(g_Shoot_R, invoker)
			else Set_BitVar(g_Shoot_R, invoker)
		}
		else
		{
			g_shoot_counter[invoker] += 1
		}

		return FMRES_SUPERCEDE
	}

	return FMRES_HANDLED
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Beretta, id))
		return HAM_IGNORED

	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_USP)

	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)

	if(fInReload)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		if(Get_BitVar(g_InSpecial, id) && get_pdata_int(ent, 51, 4) == 0)
		{
			Explode(id)
			UnSet_BitVar(g_InSpecial, id)
		}

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_USP, bpammo - temp1)

		set_pdata_int(ent, 54, 0, 4)

	}


	new iButton = pev(id, pev_button)

	if((iButton & IN_ATTACK2))
	{
		ExecuteHamB(Ham_Weapon_SecondaryAttack, ent)

		iButton &= ~IN_ATTACK2
		set_pev(id, pev_button, iButton)
	} else if((iButton & IN_ATTACK))
	{
		if(Get_BitVar(g_InSpecial, id))
		{
			Set_BitVar(g_StopSpecial, id)
			iButton &= ~IN_ATTACK
			set_pev(id, pev_button, iButton)
		}
	}

	return HAM_IGNORED
}

public Weapon_Skill(id, iEnt)
{
	if(Get_BitVar(g_Effect_Fake, id))
	{
		MultiHand_Effect(id, iEnt, g_skill_counter[id])
		UnSet_BitVar(g_Effect_Fake, id)
	}
	else
	{
		set_weapon_anim(id, g_skill_counter[id])
		Set_BitVar(g_Effect_Fake, id)
	}

	g_skill_counter[id] = random_num(ANIM_SKILL1, ANIM_SKILL5)
	static shadow_anim; shadow_anim = g_skill_counter[id]-9
	new iButton = pev(id, pev_button)
	if( iButton & IN_DUCK ) shadow_anim += 5
	Shadow_Ent(id, shadow_anim)


	emit_sound(id, CHAN_AUTO, WeaponSkillSounds[g_skill_counter[id]-10], 1.0, 0.4, 0, 94 + random_num(0, 15))
}

Explode_Exp(id)
{
	static Float:fOrigin[3]

	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

	set_pev(Ent, pev_classname, EXP_CLASSNAME)
	pev(id, pev_origin, fOrigin)
	set_pev(Ent, pev_origin, fOrigin)
	set_pev(Ent, pev_scale, 0.05)
	set_entity_anim(Ent, 1, 1)
	set_pev(Ent, pev_owner, id)
	set_pev(Ent, pev_nextthink, get_gametime()+0.5)
	engfunc(EngFunc_SetModel, Ent, EF_HOLE)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Beretta, Id))
		return

	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)

	static Draw; Draw = Get_BitVar(g_Shoot_R, Id) ? ANIM_DRAW2 : ANIM_DRAW
	if(Draw != -1) set_weapon_anim(Id, Get_BitVar(g_Shoot_R, Id) ? ANIM_DRAW2 : ANIM_DRAW)

	UnSet_BitVar(g_InSpecial, Id)
	UnSet_BitVar(g_StartSpecial, Id)
	UnSet_BitVar(g_BlockReload, Id)
	UnSet_BitVar(g_Effect_Fake, Id)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED

	if(pev(Ent, pev_impulse) == SECRET_CODE)
	{
		Set_BitVar(g_Had_Beretta, id)

		set_pev(Ent, pev_impulse, 0)
	}

	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Beretta, id) ? "weapon_gunkata" : "weapon_usp")
	write_byte(6) // PrimaryAmmoID
	write_byte(100) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(1) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Beretta, id) ? CSW_GUNKATA : CSW_USP) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Beretta, id))
		return HAM_IGNORED
	if(Get_BitVar(g_BlockReload, id))
		return HAM_SUPERCEDE

	g_Clip[id] = -1

	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_USP)
	static iClip; iClip = get_pdata_int(ent, 51, 4)

	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE

	g_Clip[id] = iClip

	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Beretta, id))
		return HAM_IGNORED

	if(Get_BitVar(g_InSpecial, id) && get_pdata_int(ent, 51, 4) == 0)
	{
		set_pdata_int(ent, 54, 2, 4)
		Set_BitVar(g_InSpecialReload, id)
	}

	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED

		set_pdata_int(ent, 51, g_Clip[id], 4)

		if(!Get_BitVar(g_InSpecial, id))
		{
			if(random_num(0, 1) == 1) set_weapon_anim(id, ANIM_RELOAD)
			else set_weapon_anim(id, ANIM_RELOAD2)
			set_weapon_timeidle(id, CSW_USP, RELOAD_TIME)
			set_player_nextattack(id, RELOAD_TIME)
		}
		g_shoot_counter[id] = 0
		UnSet_BitVar(g_Shoot_R, id)
	}

	if(get_pdata_int(ent, 54, 4) == 2)
	{
		set_weapon_anim(id, ANIM_SKILL_END)
		set_weapon_timeidle(id, CSW_USP, 1.0)
		set_player_nextattack(id, 0.5)
		g_shoot_counter[id] = 0
		UnSet_BitVar(g_Shoot_R, id)
		UnSet_BitVar(g_Effect_Fake, id)
	}

	ClearMultiHand(id)

	return HAM_HANDLED
}

public fw_Weapon_WeaponIdle_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Beretta, id))
		return HAM_IGNORED

	if(get_pdata_float(ent, 48, 4) <= 0.1)
	{
		if(Get_BitVar(g_InSpecial, id) || Get_BitVar(g_InSpecialReload, id)) Draw_AnimWeapon(id)
		else
		{
			if(Get_BitVar(g_Shoot_R, id)) set_weapon_anim(id, ANIM_IDLE2)
			else set_weapon_anim(id, ANIM_IDLE)
		}
		set_pdata_float(ent, 48, 20.0, 4)
	}

	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Pre(Ent)
{
	new id = get_pdata_cbase(Ent, 41, 4)

	if (!Get_BitVar(g_Had_Beretta, id))
		return HAM_IGNORED
	if(Get_BitVar(g_StopSpecial, id))
		return HAM_SUPERCEDE

	pev(id, pev_punchangle, g_Recoil[id])

	set_pdata_int(Ent, 64, -1)

	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	new id = get_pdata_cbase(Ent, 41, 4)

	if (!Get_BitVar(g_Had_Beretta, id))
		return

	static Float:Push[3]
	pev(id, pev_punchangle, Push)
	xs_vec_sub(Push, g_Recoil[id], Push)

	xs_vec_mul_scalar(Push, RECOIL, Push)
	xs_vec_add(Push, g_Recoil[id], Push)

	Push[1] *= 0.5
	set_pev(id, pev_punchangle, Push)

	if(Get_BitVar(g_InSpecial,id))
	{
		g_Recoil[0] = 0.0
		g_Recoil[1] = 0.0
		g_Recoil[2] = 0.0
		set_pev(id, pev_punchangle, g_Recoil)
		set_pdata_float(Ent, 62, 0.0, 4)
		HamRadiusDamage(id, ATTACK_DISTANCE, float(DAMAGEB))
		set_pdata_float(Ent, 46, SPEED_B, 4)
		set_pdata_float(Ent, 47, SPEED_B, 4)
		set_pdata_float(Ent, 48, SPEED_B+1.0, 4)
	}

	if(!Get_BitVar(g_InSpecial, id))
	{
		if(g_shoot_counter[id] == 0)
		{
			set_pdata_float(Ent, 46, 0.4, 4)
			set_pdata_float(Ent, 47, 0.4, 4)
		}
		else
		{
			set_pdata_float(Ent, 46, SPEED, 4)
			set_pdata_float(Ent, 47, SPEED, 4)
		}
	}
}

public fw_Weapon_SecondaryAttack(ent)
{
	static id; id = get_pdata_cbase(ent, 41, 4)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static Float:flNextSecondaryAttack; flNextSecondaryAttack = get_pdata_float(ent, 47, 4)

	if(!is_user_alive(id))
		return HAM_IGNORED;

	if (!Get_BitVar(g_Had_Beretta, id))
		return HAM_IGNORED;

	if(flNextAttack <= 0 && flNextSecondaryAttack <= 0 && iClip)
	{
		Set_BitVar(g_InSpecial, id)
		if(!Get_BitVar(g_StartSpecial, id))
		{
			g_shoot_counter[id] = 0
			g_skill_counter[id] = ANIM_SKILL1
			Set_BitVar(g_StartSpecial, id)
		}
		ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
		Set_BitVar(g_BlockReload, id)
	}
	else
	{
		if(!iClip && Get_BitVar(g_InSpecial, id) && !Get_BitVar(g_InSpecialReload, id))
		{
			UnSet_BitVar(g_BlockReload, id)
			ExecuteHamB(Ham_Weapon_Reload, ent)
			return HAM_SUPERCEDE
		}
	}

	return HAM_SUPERCEDE
}

public fw_Item_Holster_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return

	new id = get_pdata_cbase(Ent, 41, 4)

	if(!Get_BitVar(g_Had_Beretta,id))
		return

	UnSet_BitVar(g_InSpecial, id)
	UnSet_BitVar(g_StartSpecial, id)
	ClearMultiHand(id)
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_alive(Attacker))
		return HAM_IGNORED
	if(get_user_weapon(Attacker) != CSW_USP || !Get_BitVar(g_Had_Beretta, Attacker))
		return HAM_IGNORED
	if(Get_BitVar(g_InSpecial, Attacker))
		return HAM_SUPERCEDE

	SetHamParamFloat(3, float(DAMAGEA))

	return HAM_IGNORED
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_alive(Attacker))
		return HAM_IGNORED
	if(get_user_weapon(Attacker) != CSW_USP || !Get_BitVar(g_Had_Beretta, Attacker))
		return HAM_IGNORED
	if(Get_BitVar(g_InSpecial, Attacker))
		return HAM_SUPERCEDE

	static Float:flEnd[3], Float:vecPlane[3]

	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)

	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	return HAM_IGNORED
}


stock HamRadiusDamage(id, Float:radius, Float:damage)
{
	new i = -1, Float:origin[3]
	pev(id, pev_origin, origin)
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_USP)

	while(( i = fm_find_ent_in_sphere(i, origin, radius) ))
	{
		if(!is_user_alive(i))
			continue
		if(id == i)
			continue
		if(fm_entity_range(id, i) > radius)
			continue

		ExecuteHamB(Ham_TakeDamage, i, Ent, id, damage, HIT_GENERIC, DMG_BULLET)
	}
}

stock RadiusKB(id, Float:radius, Float:Power)
{
	new i = -1, Float:origin[3]
	pev(id, pev_origin, origin)
	//static Ent; Ent = fm_get_user_weapon_entity(id, CSW_USP)

	while(( i = fm_find_ent_in_sphere(i, origin, radius) ))
	{
		if(!is_user_alive(i))
			continue
		if(id == i)
			continue
		if(fm_entity_range(id, i) > radius)
			continue

		Stock_Fake_KnockBack(id, i, Power)
	}

}

stock set_weapon_timeidle(id, CSWID, Float:TimeIdle)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSWID)
	if(!pev_valid(Ent))
		return

	set_pdata_float(Ent, 46, TimeIdle, 4)
	set_pdata_float(Ent, 47, TimeIdle, 4)
	set_pdata_float(Ent, 48, TimeIdle + 1.0, 4)
}

stock set_player_nextattack(id, Float:Time) set_pdata_float(id, 83, Time, 5)
stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	if (pev_valid(ent) != PDATA_SAFE)
		return -1

	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)
}

public Draw_AnimWeapon(Id)
{
	set_weapon_anim(Id, ANIM_DRAW)
	UnSet_BitVar(g_BlockReload, Id)
	UnSet_BitVar(g_InSpecial, Id)
	UnSet_BitVar(g_InSpecialReload, Id)
	UnSet_BitVar(g_StartSpecial, Id)
	UnSet_BitVar(g_StopSpecial, Id)
	UnSet_BitVar(g_Effect_Fake, Id)
	ClearMultiHand(Id)
}

public Explode(id)
{
	Explode_Exp(id)
	RadiusKB(id, ATTACK_DISTANCE, KNOCKBACK_POWER)
	emit_sound(id, CHAN_WEAPON, WeaponSkillSounds[6], 1.0, 0.4, 0, 94 + random_num(0, 15))

}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
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

stock set_entity_anim(ent, anim, reset_frame)
{
	if(!pev_valid(ent)) return

	set_pev(ent, pev_animtime, get_gametime())
	set_pev(ent, pev_framerate, 1.0)
	if(reset_frame) set_pev(ent, pev_frame, 0.0)

	set_pev(ent, pev_sequence, anim)
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

public Make_BulletSmoke(id, TrResult)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG

	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)

	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(TrResult, TR_vecEndPos, vecSrc)
	get_tr2(TrResult, TR_vecPlaneNormal, vecEnd)

	xs_vec_mul_scalar(vecEnd, 2.5, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES

	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vecEnd[0])
	engfunc(EngFunc_WriteCoord, vecEnd[1])
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0)
	write_short(g_SmokePuff_SprId)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}

public Stock_Fake_KnockBack(id, iVic, Float:iKb)
{
	if(iVic > 32) return
	if(is_user_alive(iVic) && !zp_get_user_zombie(iVic))
		return

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

public update_ammo_hud(id)
{
	if(!is_user_alive(id))
		return

	static weapon_ent; weapon_ent = fm_get_user_weapon_entity(id, CSW_GUNKATA)
	if(!pev_valid(weapon_ent)) return

	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_Msg_CurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_GUNKATA)
	write_byte(cs_get_weapon_ammo(weapon_ent))
	message_end()

	message_begin(MSG_ONE_UNRELIABLE, g_Msg_AmmoX, _, id)
	write_byte(1)
	write_byte(cs_get_user_bpammo(id, CSW_GUNKATA))
	message_end()
}

stock ClearMultiHand(id)
{
	new ent = -1
	new owner
	while((ent = fm_find_ent_by_class(ent, "dbg_fakehand")))
	{
		owner = pev(ent, pev_owner)
		if(id != owner)
			continue

		if (pev_valid(ent))
		{
			fm_remove_entity(ent)
		}
	}
}

public Shadow_Ent(id, iAnim)
{
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
	static Origin[3], Float:fOrigin[3]

	get_user_origin(id, Origin, 1)
	IVecFVec(Origin, fOrigin)
	set_pev(Ent, pev_owner, id)
	set_pev(Ent, pev_origin, fOrigin)

	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0});
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0});
	set_pev(Ent, pev_classname, "dbg_shadow");

	set_pev(Ent, pev_solid, SOLID_NOT)
	engfunc(EngFunc_SetModel, Ent, EF_GUNKATA_SHADOW)

	set_pev(Ent, pev_sequence, iAnim)
	set_pev(Ent, pev_animtime, get_gametime());
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_rendermode, kRenderTransAlpha)
	set_pev(Ent, pev_renderamt, 255.0);
	set_pev(Ent, pev_fuser1, get_gametime()+2.0)

	set_pev(Ent, pev_nextthink, get_gametime()+0.01)
}

public fw_Shadow_Think(iEnt)
{
	if(!pev_valid(iEnt))
		return

	new Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)

	new Float:fRenderAmount;
	pev(iEnt, pev_renderamt, fRenderAmount);
	fRenderAmount -= 4.5;
	if (fRenderAmount <= 5.0)
	{
		fm_remove_entity(iEnt);
		return;
	}
	set_pev(iEnt, pev_renderamt, fRenderAmount);

	set_pev(iEnt, pev_nextthink, get_gametime()+0.01)
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

	if(equal(model, OLD_W_MODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, "weapon_usp", entity)

		if(!pev_valid(weapon))
			return FMRES_IGNORED;

		if(Get_BitVar(g_Had_Beretta, iOwner))
		{
			Remove_Beretta(iOwner)

			set_pev(weapon, pev_impulse, SECRET_CODE)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			set_pev(entity, pev_body, 0)

			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

stock Stock_Muzzle(id, body)
{
	//if(pev_valid(g_Muzzle[id])) fm_remove_entity(g_Muzzle[id])
	new Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"));


	engfunc(EngFunc_SetModel, Ent, WeaponMuzzle);
	set_pev(Ent, pev_classname, "weapon_muzzleflash")
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01);
	set_pev(Ent, pev_body, body);
	set_pev(Ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(Ent, pev_rendermode, kRenderTransAdd);
	set_pev(Ent, pev_renderamt, 250.0);
	set_pev(Ent, pev_aiment, id);
	set_pev(Ent, pev_owner, id);

	set_pev(Ent, pev_scale, 0.0075);
	set_pev(Ent, pev_frame, 0.0);
	set_pev(Ent, pev_fuser1, get_gametime()+0.15)

	set_pev(Ent, pev_solid, SOLID_NOT);
	dllfunc(DLLFunc_Spawn, Ent);
}

public fw_Muzzle_Think(iEnt)
{
	new id = pev(iEnt, pev_owner)
	new Float:endtime
	pev(iEnt, pev_fuser1, endtime)

	if(!pev_valid(iEnt))
		return
	if(!Get_BitVar(g_Had_Beretta,id) || get_user_weapon(id) != CSW_GUNKATA)
	{
		set_pev(iEnt, pev_flags, FL_KILLME)
		return
	}

	if(endtime <= get_gametime())
	{
		set_pev(iEnt, pev_flags, FL_KILLME)
		return
	}

	new Float:fFrame, Float:fNextThink
	pev(iEnt, pev_frame, fFrame)

	new Float:fOrigin[3]
	pev(id, pev_origin, fOrigin)

	engfunc(EngFunc_MessageBegin, MSG_ALL, SVC_TEMPENTITY, fOrigin, 0)
	write_byte(TE_DLIGHT)
	engfunc(EngFunc_WriteCoord,fOrigin[0])
	engfunc(EngFunc_WriteCoord,fOrigin[1])
	engfunc(EngFunc_WriteCoord,fOrigin[2])
	write_byte(3)
	write_byte(255)
	write_byte(187)
	write_byte(0)
	write_byte(2)
	write_byte(0)
	message_end()

	// effect exp
	fNextThink = 0.01
	fFrame += 1.0
	if(fFrame > 15.0) fFrame = 0.0

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_scale, 0.06)
	set_pev(iEnt, pev_nextthink, get_gametime() + fNextThink)
}


//==============================================
//      Fake Hand/Entity Hand by Asdian DX    //
//==============================================

stock DPS_Entites(id, models[], Float:Start[3], Float:End[3], Float:speed, solid, seq, move=MOVETYPE_FLY)
{
	new pEntity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

	// Set info for ent
	set_pev(pEntity, pev_movetype, move);
	set_pev(pEntity, pev_owner, id);
	engfunc(EngFunc_SetModel, pEntity, models);
	set_pev(pEntity, pev_classname, "dbg_fakehand");
	set_pev(pEntity, pev_mins, Float:{-1.0, -1.0, -1.0});
	set_pev(pEntity, pev_maxs, Float:{1.0, 1.0, 1.0});
	set_pev(pEntity, pev_origin, Start);
	set_pev(pEntity, pev_gravity, 0.01);
	set_pev(pEntity, pev_solid, solid);

	static Float:Velocity[3];
	Stock_Get_Speed_Vector(Start, End, speed, Velocity);
	set_pev(pEntity, pev_velocity, Velocity);

	new Float:vecVAngle[3]; pev(id, pev_v_angle, vecVAngle);
	vector_to_angle(Velocity, vecVAngle)

	if(vecVAngle[0] > 90.0) vecVAngle[0] = -(360.0 - vecVAngle[0]);
	set_pev(pEntity, pev_angles, vecVAngle);
	set_pev(pEntity, pev_sequence, seq)
	set_pev(pEntity, pev_animtime, get_gametime());
	set_pev(pEntity, pev_framerate, 1.0)
	return pEntity;
}

stock Stock_Get_Speed_Vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	xs_vec_sub(origin2, origin1, new_velocity)
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	xs_vec_mul_scalar(new_velocity, num, new_velocity)
}

stock GetGunPosition(id, Float:vecSrc[3])
{
	new Float:vecViewOfs[3];
	pev(id, pev_origin, vecSrc);
	pev(id, pev_view_ofs, vecViewOfs);
	xs_vec_add(vecSrc, vecViewOfs, vecSrc);
}

stock Stock_Get_Postion(id,Float:forw,Float:right,Float:up,Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp)
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_v_angle, vAngle)

	engfunc(EngFunc_AngleVectors, vAngle, vForward, vRight, vUp)

	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

public MultiHand_Effect(id, iEnt, seq)
{
	new Float:vecOrigin[3], Float:vecAngle[3];
	GetGunPosition(id, vecOrigin);
	pev(id, pev_v_angle, vecAngle);
	vecAngle[0] = -vecAngle[0];

	new pEntity = DPS_Entites(id, V_MODEL,vecOrigin,vecOrigin,0.01,SOLID_NOT,seq)

	// Set info for ent
	set_pev(pEntity, pev_scale, 0.1);
	set_pev(pEntity, pev_fuser3, get_gametime()+0.5);
	set_pev(pEntity, pev_velocity, Float:{0.01,0.01,0.01});
	set_pev(pEntity, pev_angles, vecAngle);
	set_pev(pEntity, pev_nextthink, get_gametime()+0.01);
}
