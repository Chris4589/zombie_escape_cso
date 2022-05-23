#pragma compress 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <cstrike>
#include <zombie_escape_v1>


new variable;
#define ZITEM_CSW_NAME CSW_AUG
#define ZITEM_SC_NAME "events/aug.sc"
#define ZITEM_OLD_MODEL_NAME "models/w_aug.mdl"
#define ZITEM_WEAPON_NAME "weapon_aug"
#define ZITEM_DEATH_ICON_NAME "aug"

#define ENG_NULLENT -1
#define EV_INT_WEAPONKEY EV_INT_impulse
#define ZITEM_WEAPONKEY 1234512
#define MAX_PLAYERS 32
#define IsValidUser(%1) (1 <= %1 <= g_MaxPlayers)

const USE_STOPPED = 0
const OFFSET_ACTIVE_ITEM = 373
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX = 5
const OFFSET_LINUX_WEAPONS = 4

#define WEAP_LINUX_XTRA_OFF 4
#define m_fKnown 44
#define m_flNextPrimaryAttack 46
#define m_flTimeWeaponIdle 48
#define m_iClip 51
#define m_fInReload 54
#define PLAYER_LINUX_XTRA_OFF 5
#define m_flNextAttack 83

#define ANIM_RELOAD_TIME 3.03
#define ANIM_RELOAD 4
#define ANIM_DRAW 5

#define write_coord_f(%1) engfunc(EngFunc_WriteCoord, %1)

new const Fire_Sounds[][] = { "zmkod20/m4a1_plasma-1.wav" }

new ZITEM_V_MODEL[64] = "models/zmkod20/v_m4a1_plasma.mdl"
new ZITEM_P_MODEL[64] = "models/zmkod20/p_m4a1_plasma.mdl"
new ZITEM_W_MODEL[64] = "models/zmkod20/w_m4a1_plasma.mdl"

new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }

new g_DMG_ITEM, g_RECOIL_ITEM, g_ITEMID_ITEM, g_CLIP_ITEM, g_SPEED_ITEM, g_AMMO_ITEM
new g_MaxPlayers, g_orig_event, g_IsInPrimaryAttack
new Float: cl_pushangle[MAX_PLAYERS + 1][3], m_iBlood[2]
new g_ZITEM[33], g_clip_ammo[33], g_TmpClip[33], oldweap[33]

const PRIMARY_WEAPONS_BIT_SUM = 
(1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<
CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)

new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

public plugin_init() {
	register_plugin("[ZP] Extra: M4A1 Plasma", "1.0", "Crock / =) (Poprogun4ik) / LARS-DAY[BR]EAKER / MKOD")
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	register_event("CurWeapon", "CurrentWeapon", "be", "1=1")
	RegisterHam(Ham_Item_AddToPlayer, ZITEM_WEAPON_NAME, "FW_ZITEM_AddToPlayer")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	for(new i = 1; i < sizeof WEAPONENTNAMES; i++) {
		if(WEAPONENTNAMES[i][0])
			RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
	}
	RegisterHam(Ham_Weapon_PrimaryAttack, ZITEM_WEAPON_NAME, "FW_ZITEM_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, ZITEM_WEAPON_NAME, "FW_ZITEM_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_PostFrame, ZITEM_WEAPON_NAME, "FW_ZITEM_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, ZITEM_WEAPON_NAME, "FW_ZITEM_Reload")
	RegisterHam(Ham_Weapon_Reload, ZITEM_WEAPON_NAME, "FW_ZITEM_Reload_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fwPlaybackEvent")
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)
	
	g_DMG_ITEM = register_cvar("zp_dmg_m4a1plasma", "2.5")
	g_RECOIL_ITEM = register_cvar("zp_recoil_m4a1plasma", "1.15")
	g_CLIP_ITEM = register_cvar("zp_clip_m4a1plasma", "30")
	g_SPEED_ITEM = register_cvar("zp_speed_m4a1plasma", "1.0")
	g_AMMO_ITEM = register_cvar("zp_ammo_m4a1plasma", "200")
	//register_clcmd("get_plasma12", "FW_GIVE_ZITEM")
	variable = zp_arma("plasmagun m4a1", 6, 2, PRIMARIA, ADMIN_ALL, "")
	g_MaxPlayers = get_maxplayers()
}

public plugin_precache() {
	precache_model(ZITEM_V_MODEL)
	precache_model(ZITEM_P_MODEL)
	precache_model(ZITEM_W_MODEL)
	for(new i = 0; i < sizeof Fire_Sounds; i++)
		precache_sound(Fire_Sounds[i])
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")
	
	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
}

public fw_TraceAttack(iEnt, iAttacker, Float: flDamage, Float: fDir[3], ptr, iDamageType) {
	if(!is_user_alive(iAttacker))
		return
	
	new g_currentweapon = get_user_weapon(iAttacker)
	
	if(g_currentweapon != ZITEM_CSW_NAME)
		return
	if(!g_ZITEM[iAttacker])
		return
	
	static Float: flEnd[3], Float: WallVector[3], trace_color
	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, WallVector)
	
	new Float: vecEnd[3], Float: vecPlane[3]
	
	get_tr2(ptr, TR_vecEndPos, vecEnd)
	get_tr2(ptr, TR_vecPlaneNormal, vecPlane)
	
	xs_vec_mul_scalar(vecPlane, 5.0, vecPlane)
	
	new Float: Origin[3]
	
	get_weapon_position(iAttacker, Origin, .add_forward = 10.0, .add_right = 3.0, .add_up =- 2.5)
	
	new Float: Velo[3]
	Velo[0] = vecEnd[0] - Origin[0]
	Velo[1] = vecEnd[1] - Origin[1]
	Velo[2] = vecEnd[2] - Origin[2]
	
	xs_vec_normalize(Velo, Velo)
	xs_vec_mul_scalar(Velo, 4096.0, Velo)
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_USERTRACER)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Velo[0])
	engfunc(EngFunc_WriteCoord, Velo[1])
	engfunc(EngFunc_WriteCoord, Velo[2])
	write_byte(20)
	write_byte(2)
	write_byte(4)
	message_end()
	
	if(trace_color < 2000) {
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_STREAK_SPLASH)
		engfunc(EngFunc_WriteCoord, flEnd[0])
		engfunc(EngFunc_WriteCoord, flEnd[1])
		engfunc(EngFunc_WriteCoord, flEnd[2])
		engfunc(EngFunc_WriteCoord, WallVector[0] * random_float(25.0, 30.0))
		engfunc(EngFunc_WriteCoord, WallVector[1] * random_float(25.0, 30.0))
		engfunc(EngFunc_WriteCoord, WallVector[2] * random_float(25.0, 30.0))
		write_byte(2)
		write_short(50)
		write_short(3)
		write_short(90)	
		message_end()
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_short(iAttacker)
		write_byte(GUNSHOT_DECALS[random_num(0, sizeof GUNSHOT_DECALS -1)])
		message_end()
	}
}

stock get_weapon_position(id, Float: fOrigin[3], Float: add_forward = 0.0, Float: add_right = 0.0, Float: add_up = 0.0) {
	static Float: Angles[3], Float: ViewOfs[3], Float: vAngles[3]
	static Float: Forward[3], Float: Right[3], Float: Up[3]
	
	pev(id, pev_v_angle, vAngles)
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, ViewOfs)
	xs_vec_add(fOrigin, ViewOfs, fOrigin)
	
	pev(id, pev_v_angle, Angles)
	
	engfunc(EngFunc_MakeVectors, Angles)
	
	global_get(glb_v_forward, Forward)
	global_get(glb_v_right, Right)
	global_get(glb_v_up,  Up)
	
	xs_vec_mul_scalar(Forward, add_forward, Forward)
	xs_vec_mul_scalar(Right, add_right, Right)
	xs_vec_mul_scalar(Up, add_up, Up)
	
	fOrigin[0] = fOrigin[0] + Forward[0] + Right[0] + Up[0]
	fOrigin[1] = fOrigin[1] + Forward[1] + Right[1] + Up[1]
	fOrigin[2] = fOrigin[2] + Forward[2] + Right[2] + Up[2]
}

public zp_user_humanized_post(id)
	g_ZITEM[id] = false
public plugin_natives()
	register_native("native_plasmam", "native_give_weapon_add", 1)
public native_give_weapon_add(id)
	FW_GIVE_ZITEM(id)

public fwPrecacheEvent_Post(type, const name[]) {
	if(equal(ZITEM_SC_NAME, name)) {
		g_orig_event = get_orig_retval()
		
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public client_connect(id)
	g_ZITEM[id] = false
public client_disconnect(id)
	g_ZITEM[id] = false

public zp_user_infected_post(id) {
	if(zp_get_user_zombie(id))
		g_ZITEM[id] = false
}

public fw_SetModel(entity, model[]) {
	if(!is_valid_ent(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, ZITEM_OLD_MODEL_NAME)) {
		static iStoredAugID
		
		iStoredAugID = find_ent_by_owner(ENG_NULLENT, ZITEM_WEAPON_NAME, entity)
		
		if(!is_valid_ent(iStoredAugID))
			return FMRES_IGNORED
		
		if(g_ZITEM[iOwner]) {
			entity_set_int(iStoredAugID, EV_INT_WEAPONKEY, ZITEM_WEAPONKEY)
			
			g_ZITEM[iOwner] = false
			
			entity_set_model(entity, ZITEM_W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public FW_GIVE_ZITEM(id) {
	drop_weapons(id, 1)
	new iWep2 = give_item(id, ZITEM_WEAPON_NAME)
	
	if(iWep2 > 0) {
		cs_set_weapon_ammo(iWep2, get_pcvar_num(g_CLIP_ITEM))
		cs_set_user_bpammo(id, ZITEM_CSW_NAME, get_pcvar_num(g_AMMO_ITEM))
		UTIL_PlayWeaponAnimation(id, ANIM_DRAW)
		set_pdata_float(id, m_flNextAttack, 1.0, PLAYER_LINUX_XTRA_OFF)
	}
	g_ZITEM[id] = true
}

public zp_extra_item_selected(id, itemid) {
	if(itemid != g_ITEMID_ITEM)
		return
	
	FW_GIVE_ZITEM(id)
}

public FW_ZITEM_AddToPlayer(ZITEM, id) {
	if(!is_valid_ent(ZITEM) || !is_user_connected(id))
		return HAM_IGNORED
	
	if(entity_get_int(ZITEM, EV_INT_WEAPONKEY) == ZITEM_WEAPONKEY) {
		g_ZITEM[id] = true
		
		entity_set_int(ZITEM, EV_INT_WEAPONKEY, 0)
	}
	return HAM_IGNORED
}

public fw_UseStationary_Post(entity, caller, activator, use_type) {
	if(use_type == USE_STOPPED && is_user_connected(caller))
		replace_weapon_models(caller, get_user_weapon(caller))
}

public fw_Item_Deploy_Post(weapon_ent) {
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	
	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	replace_weapon_models(owner, weaponid)
}

public CurrentWeapon(id) {
	replace_weapon_models(id, read_data(2))
	
	if(read_data(2) != ZITEM_CSW_NAME || !g_ZITEM[id])
		return
	
	static Float: iSpeed
	
	if(g_ZITEM[id])
		iSpeed = get_pcvar_float(g_SPEED_ITEM)
	
	static weapon[32], Ent
	get_weaponname(read_data(2), weapon, 31)
	Ent = find_ent_by_owner(-1, weapon, id)
	
	if(Ent) {
		static Float: Delay
		Delay = get_pdata_float(Ent, 46, 4) * iSpeed
		
		if(Delay > 0.0)
			set_pdata_float(Ent, 46, Delay, 4)
	}
}

replace_weapon_models(id, weaponid) {
	switch(weaponid) {
		case ZITEM_CSW_NAME: {
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id))
				return
			
			if(g_ZITEM[id]) {
				set_pev(id, pev_viewmodel2, ZITEM_V_MODEL)
				set_pev(id, pev_weaponmodel2, ZITEM_P_MODEL)
				
				if(oldweap[id] != ZITEM_CSW_NAME) {
					UTIL_PlayWeaponAnimation(id, ANIM_DRAW)
					set_pdata_float(id, m_flNextAttack, 1.0, PLAYER_LINUX_XTRA_OFF)
				}
			}
		}
	}
	oldweap[id] = weaponid
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle) {
	if(!is_user_alive(Player) || (get_user_weapon(Player) != ZITEM_CSW_NAME || !g_ZITEM[Player]))
		return FMRES_IGNORED
	
	set_cd(CD_Handle, CD_flNextAttack, halflife_time() + 0.001)
	
	return FMRES_HANDLED
}

public FW_ZITEM_PrimaryAttack(Weapon) {
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	if(!g_ZITEM[Player])
		return
	
	g_IsInPrimaryAttack = 1
	pev(Player, pev_punchangle, cl_pushangle[Player])
	
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
}

public fwPlaybackEvent(flags, invoker, eventid, Float: delay, Float: origin[3], Float: angles[3], Float: fparam1, Float: fparam2, iParam1, iParam2, bParam1, bParam2) {
	if((eventid != g_orig_event) || !g_IsInPrimaryAttack)
		return FMRES_IGNORED
	if(!(1 <= invoker <= g_MaxPlayers))
		return FMRES_IGNORED
	
	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	return FMRES_SUPERCEDE
}

public FW_ZITEM_PrimaryAttack_Post(Weapon) {
	g_IsInPrimaryAttack = 0
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	new szClip, szAmmo
	get_user_weapon(Player, szClip, szAmmo)
	
	if(!is_user_alive(Player))
		return
	
	if(g_ZITEM[Player]) {
		if(!g_clip_ammo[Player])
			return
		
		new Float: push[3]
		pev(Player, pev_punchangle, push)
		xs_vec_sub(push, cl_pushangle[Player], push)
		
		xs_vec_mul_scalar(push, get_pcvar_float(g_RECOIL_ITEM), push)
		xs_vec_add(push, cl_pushangle[Player], push)
		set_pev(Player, pev_punchangle, push)
		
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		UTIL_PlayWeaponAnimation(Player, random_num(1, 3))
	}
}

public fw_TakeDamage(victim, inflictor, attacker, Float: damage) {
	if(victim != attacker && is_user_connected(attacker)) {
		if(get_user_weapon(attacker) == ZITEM_CSW_NAME) {
			if(g_ZITEM[attacker])
				SetHamParamFloat(4, damage * get_pcvar_float(g_DMG_ITEM))
		}
	}
}

public message_DeathMsg(msg_id, msg_dest, id) {
	static szTruncatedWeapon[33], iAttacker, iVictim
	
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE
	
	if(equal(szTruncatedWeapon, ZITEM_DEATH_ICON_NAME) && get_user_weapon(iAttacker) == ZITEM_CSW_NAME) {
		if(g_ZITEM[iAttacker])
			set_msg_arg_string(4, ZITEM_DEATH_ICON_NAME)
	}
	return PLUGIN_CONTINUE
}

stock fm_cs_get_current_weapon_ent(id)
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX)
stock fm_cs_get_weapon_ent_owner(ent)
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)

stock UTIL_PlayWeaponAnimation(const Player, const Sequence) {
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}

public FW_ZITEM_ItemPostFrame(weapon_entity) {
	new id = pev(weapon_entity, pev_owner)
	
	if(!is_user_connected(id))
		return HAM_IGNORED
	if(!g_ZITEM[id])
		return HAM_IGNORED
	
	static iClipExtra
	
	iClipExtra = get_pcvar_num(g_CLIP_ITEM)
	new Float: flNextAttack = get_pdata_float(id, m_flNextAttack, PLAYER_LINUX_XTRA_OFF)
	
	new iBpAmmo = cs_get_user_bpammo(id, ZITEM_CSW_NAME)
	new iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)
	
	new fInReload = get_pdata_int(weapon_entity, m_fInReload, WEAP_LINUX_XTRA_OFF)
	
	if(fInReload && flNextAttack <= 0.0) {
		new j = min(iClipExtra - iClip, iBpAmmo)
		
		set_pdata_int(weapon_entity, m_iClip, iClip + j, WEAP_LINUX_XTRA_OFF)
		cs_set_user_bpammo(id, ZITEM_CSW_NAME, iBpAmmo - j)
		
		set_pdata_int(weapon_entity, m_fInReload, 0, WEAP_LINUX_XTRA_OFF)
		fInReload = 0
	}
	return HAM_IGNORED
}

public FW_ZITEM_Reload(weapon_entity) {
	new id = pev(weapon_entity, pev_owner)
	
	if(!is_user_connected(id))
		return HAM_IGNORED
	if(!g_ZITEM[id])
		return HAM_IGNORED
	
	static iClipExtra
	
	if(g_ZITEM[id])
		iClipExtra = get_pcvar_num(g_CLIP_ITEM)
	
	g_TmpClip[id] = -1
	
	new iBpAmmo = cs_get_user_bpammo(id, ZITEM_CSW_NAME)
	new iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)
	
	if(iBpAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= iClipExtra)
		return HAM_SUPERCEDE
	
	g_TmpClip[id] = iClip
	
	return HAM_IGNORED
}

public FW_ZITEM_Reload_Post(weapon_entity) {
	new id = pev(weapon_entity, pev_owner)
	
	if(!is_user_connected(id))
		return HAM_IGNORED
	if(!g_ZITEM[id])
		return HAM_IGNORED
	if(g_TmpClip[id] == -1)
		return HAM_IGNORED
	
	set_pdata_int(weapon_entity, m_iClip, g_TmpClip[id], WEAP_LINUX_XTRA_OFF)
	
	set_pdata_float(weapon_entity, m_flTimeWeaponIdle, ANIM_RELOAD_TIME, WEAP_LINUX_XTRA_OFF)
	
	set_pdata_float(id, m_flNextAttack, ANIM_RELOAD_TIME, PLAYER_LINUX_XTRA_OFF)
	
	set_pdata_int(weapon_entity, m_fInReload, 1, WEAP_LINUX_XTRA_OFF)
	
	UTIL_PlayWeaponAnimation(id, ANIM_RELOAD)
	
	return HAM_IGNORED
}

stock drop_weapons(id, dropwhat) {
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
	
	for(i = 0; i < num; i++) {
		weaponid = weapons[i]
		
		if(dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) {
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}
public dar_arma(id, iItemID)
{
	if( iItemID!= variable ) return;
	{
		FW_GIVE_ZITEM(id);
		}
}