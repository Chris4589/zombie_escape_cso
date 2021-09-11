 // Слито для zombie-amxx.ru

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>

// Base Include
#include <zombieplague>
#include <zp43_armas>
#define PLUGIN "[CSO Like] BrickPiace Machinegun / ZP"
#define VERSION "1.0"
#define AUTHOR "AsepKhairulAnam / Lakerovich"

// CONFIGURATION WEAPON
#define system_name		"blockmg"
#define system_base		"m249"
#define CSW_BASE		CSW_M249
#define WEAPON_KEY 		41412221
#define ANIMEXT			"m249"
#define ANIMEXT_2		"carbine"
#define DRAW_TIME		1.0
#define RELOAD_TIME		4.7

// ALL MACRO
#define MODE_A			0
#define MODE_B			1
#define TASK_CHANGE		102040
#define TASK_RELOAD		183212
#define ENG_NULLENT		-1
#define EV_INT_WEAPONKEY	EV_INT_impulse
#define write_coord_f(%1)	engfunc(EngFunc_WriteCoord,%1)
new variable;
// ALL ANIM
#define ANIM_IDLE		0
#define ANIM_IDLE2_B		5
#define ANIM_SHOOT1_A		1
#define ANIM_SHOOT2_A		2
#define ANIM_RELOAD_A		3
#define ANIM_DRAW_A		4
#define ANIM_CHANGE_B		5
#define ANIM_CHANGE_A_COMPLETE	6
#define ANIM_SHOOT_B		1
#define ANIM_SHOOT_B_EMPTY	6
#define ANIM_DRAW_B		2
#define ANIM_CHANGE_A		3
#define ANIM_CHANGE_B_COMPLETE	4

// Configuration Extra Items
#define NAME_EXTRA_ITEMS	"Brick Piece MG"
#define TEAM_EXTRA_ITEMS	ZP_TEAM_HUMAN
#define COST_EXTRA_ITEMS	50

// All Models Of The Weapon
new const V_MODEL[][] =
{
	"models/v_blockmg1.mdl",
	"models/v_blockmg2.mdl",
	"models/v_blockchange_fix.mdl"
}

new const P_MODEL[][] =
{
	"models/p_blockmg1.mdl",
	"models/p_blockmg2.mdl"
}


new const S_MODEL[][] =
{
	"models/block_shell.mdl",
	"models/blockmg_missile.mdl"
}

new const SPRITES[][] =
{
	"sprites/blockmg/640hud14_2.spr",
	"sprites/blockmg/640hud130_2.spr",
	"sprites/laserbeam.spr",
	"sprites/effects/rainsplash.spr",
	"sprites/steam1.spr",
	"sprites/eexplo.spr",
	"sprites/fexplo.spr",
	"sprites/dexplo.spr"
	
}

// You Can Add Fire Sound Here
new const Fire_Sounds[][] = { "weapons/blockmg1-1.wav", "weapons/blockmg2-1.wav", "weapons/blockmg2_shoot_empty.wav" }

// All Vars Here
new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }
new cvar_dmg, cvar_recoil, cvar_clip, cvar_spd, cvar_ammo, cvar_radius, cvar_dmg_2, cvar_trace_color, cvar_trail[2]
new g_MaxPlayers, g_orig_event, g_IsInPrimaryAttack[33], g_attack_type[33], Float:cl_pushangle[33][3], g_weapon_TmpClip[33]
new g_has_weapon[33], g_clip_ammo[33], oldweap[33], g_mode[33], g_ammo_special[33], sTrail[2], sExplo[3], default_ammo[33][2]
new bool:g_change_mode[33], shell_block, sSmoke, g_item

// Macros Again
new weapon_name_buffer_1[512]
new weapon_name_buffer_2[512]
new weapon_base_buffer[512]
		
const PRIMARY_WEAPONS_BIT_SUM = 
(1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<
CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

// START TO CREATE PLUGINS || AMXMODX FORWARD
public plugin_init()
{
	formatex(weapon_name_buffer_1, sizeof(weapon_name_buffer_1), "weapon_%s_1", system_name)
	formatex(weapon_name_buffer_2, sizeof(weapon_name_buffer_2), "weapon_%s_2", system_name)
	formatex(weapon_base_buffer, sizeof(weapon_base_buffer), "weapon_%s", system_base)
	
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Event And Message
	register_event("CurWeapon", "Event_CurrentWeapon", "be", "1=1")
	register_message(get_user_msgid("DeathMsg"), "Message_DeathMsg")

	// Ham Forward (Entity) || Ham_Use
	RegisterHam(Ham_Use, "func_tank", "Forward_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "Forward_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "Forward_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "Forward_UseStationary_Post", 1)
	
	// Ham Forward (Entity) || Ham_TraceAttack
	RegisterHam(Ham_TraceAttack, "player", "Forward_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "worldspawn", "Forward_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "Forward_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "Forward_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "Forward_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "Forward_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "Forward_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "Forward_TraceAttack", 1)
	
	// Ham Forward (Weapon)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_base_buffer, "Weapon_Idle")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_base_buffer, "Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_base_buffer, "Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_base_buffer, "Weapon_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, weapon_base_buffer, "Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_base_buffer, "Weapon_Reload_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_base_buffer, "Weapon_AddToPlayer")
	
	// Ham Forward (Player)
	RegisterHam(Ham_TakeDamage, "player", "Forward_TakeDamage")
	
	for(new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if(WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "Weapon_Deploy_Post", 1)
	
	// Fakemeta Forward
	register_forward(FM_SetModel, "Forward_SetModel")
	register_forward(FM_PlaybackEvent, "Forward_PlaybackEvent")
	register_forward(FM_UpdateClientData, "Forward_UpdateClientData_Post", 1)
	register_forward(FM_AddToFullPack, "Forward_AddToFullPack", 1)
	register_forward(FM_CheckVisibility, "Forward_CheckVisibility")
	
	// Touch And Think
	register_touch("block_missile", "*", "Forward_TouchMissile")
	register_think("block_missile", "Forward_ThinkMissile")
	
	// All Some Cvar
	cvar_clip = register_cvar("blockmg_clip", "100")
	cvar_spd = register_cvar("blockmg_speed", "1.2")
	cvar_ammo = register_cvar("blockmg_ammo", "200")
	cvar_dmg = register_cvar("blockmg_damage", "1.25")
	cvar_recoil = register_cvar("blockmg_recoil", "0.6")
	cvar_dmg_2 = register_cvar("blockmg_rocket_damage", "120")
	cvar_radius = register_cvar("blockmg_rocket_radius", "80")
	cvar_trace_color = register_cvar("blockmg_trace_color", "5")
	cvar_trail[0] = register_cvar("blockmg_laser_trail", "0")
	cvar_trail[1] = register_cvar("blockmg_smoke_trail", "1")
	
	g_MaxPlayers = get_maxplayers()
	variable = zp_arma("lego MG50", 29, 0, PRIMARIA, ADMIN_ALL, "")
}

public plugin_precache()
{
	formatex(weapon_name_buffer_1, sizeof(weapon_name_buffer_1), "weapon_%s_1", system_name)
	formatex(weapon_name_buffer_2, sizeof(weapon_name_buffer_2), "weapon_%s_2", system_name)
	formatex(weapon_base_buffer, sizeof(weapon_base_buffer), "weapon_%s", system_base)
	
	for(new i = 0; i < sizeof V_MODEL; i++)
	{
		precache_model(V_MODEL[i])
		precache_viewmodel_sound(V_MODEL[i])
	}
	for(new i = 0; i < sizeof P_MODEL; i++)
		precache_model(P_MODEL[i])
	
	new Buffer[512], Buffer2[512]
	formatex(Buffer2, sizeof(Buffer2), "sprites/%s.txt", weapon_name_buffer_2)
	formatex(Buffer, sizeof(Buffer), "sprites/%s.txt", weapon_name_buffer_1)
	precache_generic(Buffer)
	precache_generic(Buffer2)
	
	for(new i = 0; i < sizeof Fire_Sounds; i++)
		precache_sound(Fire_Sounds[i])
	for(new i = 0; i < sizeof S_MODEL; i++)
	{
		if(i == 0) shell_block = precache_model(S_MODEL[i])
		else precache_model(S_MODEL[i])
	}
	for(new i = 0; i < sizeof SPRITES; i++)
	{
		if(i == 2) sTrail[0] = precache_model(SPRITES[i])
		else if(i == 3) sTrail[1] = precache_model(SPRITES[i])
		else if(i == 4) sSmoke = precache_model(SPRITES[i])
		else if(i == 5) sExplo[0] = precache_model(SPRITES[i])
		else if(i == 6) sExplo[1] = precache_model(SPRITES[i])
		else if(i == 7) sExplo[2] = precache_model(SPRITES[i])
		else precache_model(SPRITES[i])
	}
	
	register_clcmd(weapon_name_buffer_1, "weapon_hook")
	register_clcmd(weapon_name_buffer_2, "weapon_hook")
	register_forward(FM_PrecacheEvent, "Forward_PrecacheEvent_Post", 1)
}

public plugin_natives()
{
	new Buffer[512]
	formatex(Buffer, sizeof(Buffer), "get_%s", system_name)
	register_native(Buffer, "give_item", 1)
	formatex(Buffer, sizeof(Buffer), "remove_%s", system_name)
	register_native(Buffer, "remove_item", 1)
}

public zp_extra_item_selected(id, itemid)
{
	if(itemid != g_item)
		return

	give_item(id)
}

// Reset Bitvar (Fix Bug) If You Connect Or Disconnect Server
public client_connect(id) remove_item(id)
public client_disconnect(id) remove_item(id)
public zp_user_infected_post(id) remove_item(id)
public zp_user_humanized_post(id) remove_item(id)
/* ========= START OF REGISTER HAM TO SUPPORT BOTS FUNC ========= */
new g_HamBot
public client_putinserver(id)
{
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_RegisterHam", id)
	}
}

public Do_RegisterHam(id)
{
	RegisterHamFromEntity(Ham_TakeDamage, id, "Forward_TakeDamage")
	RegisterHamFromEntity(Ham_TraceAttack, id, "Forward_TraceAttack", 1)
}

/* ======== END OF REGISTER HAM TO SUPPORT BOTS FUNC ============= */
/* ============ START OF ALL FORWARD (FAKEMETA) ================== */
public Forward_PrecacheEvent_Post(type, const name[])
{
	new Buffer[512]
	formatex(Buffer, sizeof(Buffer), "events/%s.sc", system_base)
	if(equal(Buffer, name, 0))
	{
		g_orig_event = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public Forward_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
		
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	{
		static iStoredWeaponID
		iStoredWeaponID = find_ent_by_owner(ENG_NULLENT, weapon_base_buffer, entity)
			
		if(!is_valid_ent(iStoredWeaponID))
			return FMRES_IGNORED

		if(g_has_weapon[iOwner])
		{
			entity_set_int(iStoredWeaponID, EV_INT_WEAPONKEY, WEAPON_KEY)
			g_has_weapon[iOwner] = 0
			
			if(g_mode[iOwner] == MODE_B)
			{
				set_pev(iStoredWeaponID, pev_iuser3, default_ammo[iOwner][0])
				set_pev(iStoredWeaponID, pev_iuser4, default_ammo[iOwner][1])
			}
			
			set_pev(iStoredWeaponID, pev_iuser2, g_ammo_special[iOwner])
			set_pev(iStoredWeaponID, pev_iuser1, g_mode[iOwner])
			
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public Forward_UseStationary_Post(entity, caller, activator, use_type)
{
	if(!use_type && is_user_connected(caller))
		replace_weapon_models(caller, get_user_weapon(caller))
}

public Forward_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if(!is_user_alive(Player) || (get_user_weapon(Player) != CSW_BASE || !g_has_weapon[Player]))
		return FMRES_IGNORED
	
	set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.001)
	return FMRES_HANDLED
}

public Forward_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if((eventid != g_orig_event) || !g_IsInPrimaryAttack[invoker])
		return FMRES_IGNORED
	if(!(1 <= invoker <= g_MaxPlayers))
		return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

/* ================= END OF ALL FAKEMETA FORWARD ================= */
/* ================= START OF ALL MESSAGE FORWARD ================ */
public Message_DeathMsg(msg_id, msg_dest, id)
{
	static szTruncatedWeapon[33], iAttacker, iVictim
	
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE
	
	if(equal(szTruncatedWeapon, system_base) && get_user_weapon(iAttacker) == CSW_BASE)
	{
		if(g_has_weapon[iAttacker])
			set_msg_arg_string(4, system_name)
	}
	return PLUGIN_CONTINUE
}

/* ================== END OF ALL MESSAGE FORWARD ================ */
/* ================== START OF ALL ENGINE FORWARD ================ */
public Forward_TouchMissile(toucher, touched)
{
	if(!pev_valid(toucher))
		return
		
	new touch
	touch = pev(toucher, pev_iuser1)
	if(!touch) Missile_Explode(toucher)
}

public Forward_ThinkMissile(ent)
{
	if(!pev_valid(ent))
		return
	
	new touch, execute_smoke, Float:origin[3]
	touch = pev(ent, pev_iuser1)
	execute_smoke = pev(ent, pev_iuser2)
	pev(ent, pev_origin, origin)
	
	if(!execute_smoke)
	{
		if(!touch)
		{
			if(get_pcvar_num(cvar_trail[0]))
			{
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_BEAMFOLLOW)
				write_short(ent)
				write_short(sTrail[0])
				write_byte(3)
				write_byte(2)
				write_byte(255)
				write_byte(255)
				write_byte(255)
				write_byte(150)
				message_end()
			}
			
			if(get_pcvar_num(cvar_trail[1]))
			{
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_SPRITE)
				engfunc(EngFunc_WriteCoord, origin[0])
				engfunc(EngFunc_WriteCoord, origin[1])
				engfunc(EngFunc_WriteCoord, origin[2])
				write_short(sTrail[1]) 
				write_byte(3) 
				write_byte(200)
				message_end()
			}
			
			set_pev(ent, pev_nextthink, get_gametime() + 0.1)
		}
		else
		{
			set_pev(ent, pev_iuser2, 1)
			set_pev(ent, pev_nextthink, get_gametime() + 1.0)
		}
	}
	else
	{
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0)
		write_byte(TE_SMOKE)
		engfunc(EngFunc_WriteCoord, origin[0])
		engfunc(EngFunc_WriteCoord, origin[1])
		engfunc(EngFunc_WriteCoord, origin[2] + 55.0)
		write_short(sSmoke)
		write_byte(40)
		write_byte(12)
		message_end()
		remove_entity(ent)
	}
}
/* ================== END OF ALL ENGINE FORWARD ================== */
/* ================== START OF ALL EVENT FORWARD ================ */
public Event_CurrentWeapon(id)
{
	if(!is_user_alive(id))
		return
		
	replace_weapon_models(id, read_data(2))
     
	if(read_data(2) != CSW_BASE || !g_has_weapon[id] || g_mode[id] == MODE_B)
		return
     
	static Float:Speed
	if(g_has_weapon[id])
		Speed = get_pcvar_float(cvar_spd)
	
	static weapon[32], Ent
	get_weaponname(read_data(2), weapon, 31)
	Ent = find_ent_by_owner(-1, weapon, id)
	if(pev_valid(Ent))
	{
		static Float:Delay
		Delay = get_pdata_float(Ent, 46, 4) * Speed
		if(Delay > 0.0) set_pdata_float(Ent, 46, Delay, 4)
	}
}
/* ================== END OF ALL EVENT FORWARD =================== */
/* ================== START OF ALL HAM FORWARD =================== */
public Forward_TakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if(victim != attacker && is_user_connected(attacker))
	{
		if(get_user_weapon(attacker) == CSW_BASE)
		{
			if(g_has_weapon[attacker] && (damagebits & DMG_BULLET))
				SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmg))
		}
	}
}

public Forward_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(iAttacker) || !is_user_connected(iAttacker))
		return HAM_IGNORED
	if(get_user_weapon(iAttacker) != CSW_BASE || !g_has_weapon[iAttacker])
		return HAM_IGNORED
	if(g_mode[iAttacker] == MODE_B)
	{
		return HAM_SUPERCEDE
	}
	
	static Float:flEnd[3], Float:WallVector[3], trace_color
	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, WallVector)
	
	if(iEnt)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_DECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		write_short(iEnt)
		message_end()
	}
	else
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		message_end()
	}
	
	if(g_mode[iAttacker] == MODE_A)
	{
		if(!is_user_alive(iEnt)) trace_color = get_pcvar_num(cvar_trace_color)
		else if(is_user_alive(iEnt)) trace_color = 2000
	}
	
	if(trace_color < 2000)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_STREAK_SPLASH)
		engfunc(EngFunc_WriteCoord, flEnd[0])
		engfunc(EngFunc_WriteCoord, flEnd[1])
		engfunc(EngFunc_WriteCoord, flEnd[2])
		engfunc(EngFunc_WriteCoord, WallVector[0] * random_float(25.0,30.0))
		engfunc(EngFunc_WriteCoord, WallVector[1] * random_float(25.0,30.0))
		engfunc(EngFunc_WriteCoord, WallVector[2] * random_float(25.0,30.0))
		write_byte(trace_color)
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
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		message_end()
	}
	
	return HAM_IGNORED
}

public Weapon_Deploy_Post(weapon_entity)
{
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_entity)
	
	static weaponid
	weaponid = cs_get_weapon_id(weapon_entity)
	
	replace_weapon_models(owner, weaponid)
}

public Weapon_AddToPlayer(weapon_entity, id)
{
	if(!is_valid_ent(weapon_entity) || !is_user_connected(id))
		return HAM_IGNORED
	
	if(entity_get_int(weapon_entity, EV_INT_WEAPONKEY) == WEAPON_KEY)
	{
		g_has_weapon[id] = true
		g_mode[id] = pev(weapon_entity, pev_iuser1)
		g_ammo_special[id] = pev(weapon_entity, pev_iuser2)
		g_change_mode[id] = false
		
		if(pev(weapon_entity, pev_iuser1) == MODE_B)
		{
			default_ammo[id][0] = pev(weapon_entity, pev_iuser3)
			default_ammo[id][1] = pev(weapon_entity, pev_iuser4)
		}
		
		entity_set_int(weapon_entity, EV_INT_WEAPONKEY, 0)
		set_weapon_list(id, true, 1)
		
		return HAM_HANDLED
	}
	else
	{
		set_weapon_list(id, false, 0)
	}
	
	return HAM_IGNORED
}

public Weapon_Idle(weapon_entity)
{
	new id = fm_cs_get_weapon_ent_owner(weapon_entity)
	
	if(!is_user_alive(id) || !is_user_connected(id))
		return HAM_IGNORED
	if(g_mode[id] != MODE_B)
		return HAM_IGNORED
	if(get_pdata_float(weapon_entity, 48, 4) > 0.0)
		return HAM_IGNORED
	
	set_pdata_float(weapon_entity, 48, 6.0, 4)
	new random_anim = random_num(0, 1)
	if(!random_anim) set_weapon_anim(id, ANIM_IDLE)
	else set_weapon_anim(id, ANIM_IDLE2_B)
	
	return HAM_SUPERCEDE
}


public Weapon_PrimaryAttack(weapon_entity)
{
	new Player = fm_cs_get_weapon_ent_owner(weapon_entity)
	
	if(!g_has_weapon[Player])
		return
	
	g_IsInPrimaryAttack[Player] = 1
	pev(Player,pev_punchangle,cl_pushangle[Player])
	
	g_clip_ammo[Player] = cs_get_weapon_ammo(weapon_entity)
}

public Weapon_PrimaryAttack_Post(weapon_entity)
{
	new Player = fm_cs_get_weapon_ent_owner(weapon_entity)
	
	new szClip, szAmmo
	get_user_weapon(Player, szClip, szAmmo)
	
	if(!is_user_alive(Player))
		return HAM_IGNORED
	
	g_IsInPrimaryAttack[Player] = 0
	
	if(g_has_weapon[Player] && g_mode[Player] == MODE_A)
	{
		if(!g_clip_ammo[Player])
		{
			ExecuteHam(Ham_Weapon_PlayEmptySound, weapon_entity)
			return HAM_IGNORED
		}
		
		new Float:push[3]
		pev(Player,pev_punchangle,push)
		xs_vec_sub(push,cl_pushangle[Player],push)
		xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil),push)
		xs_vec_add(push,cl_pushangle[Player],push)
		set_pev(Player,pev_punchangle,push)
		
		set_weapon_shoot_anim(Player)
		emit_sound(Player, CHAN_AUTO, Fire_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		for(new i = 0; i < 5; i++)
		{
			set_pdata_int(weapon_entity, 57, shell_block, 4)
			set_pdata_float(Player, 111, get_gametime() + 0.01)
			eject_shell(Player, shell_block, 0)
			eject_shell(Player, shell_block, 1)
		}
	}
	
	if(g_has_weapon[Player] && g_mode[Player] == MODE_B)
	{
		return HAM_SUPERCEDE
	}
	
	return HAM_IGNORED
}

public Weapon_ItemPostFrame(weapon_entity) 
{
	new id = pev(weapon_entity, pev_owner)
	if(!is_user_connected(id))
		return HAM_IGNORED
	if(!g_has_weapon[id])
		return HAM_IGNORED
	
	static iClipExtra
	iClipExtra = get_pcvar_num(cvar_clip)
	new Float:flNextAttack = get_pdata_float(id, 83, 5)
	new iBpAmmo = cs_get_user_bpammo(id, CSW_BASE)
	new iClip = get_pdata_int(weapon_entity, 51, 4)
	new fInReload = get_pdata_int(weapon_entity, 54, 4) 
	
	if(fInReload && flNextAttack <= 0.0)
	{
		new j = min(iClipExtra - iClip, iBpAmmo)
	
		set_pdata_int(weapon_entity, 51, iClip + j, 4)
		cs_set_user_bpammo(id, CSW_BASE, iBpAmmo-j)
		
		set_pdata_int(weapon_entity, 54, 0, 4)
		fInReload = 0
	}
	else if(!fInReload && !get_pdata_int(weapon_entity, 74, 4))
	{
		if(get_pdata_float(id, 83, 5) <= 0.0 && get_pdata_float(weapon_entity, 46, 4) <= 0.0 ||
		get_pdata_float(weapon_entity, 47, 4) <= 0.0 || get_pdata_float(weapon_entity, 48, 4) <= 0.0)
		{
			if(pev(id, pev_button) & IN_ATTACK)
			{
				if(g_change_mode[id])
					return HAM_IGNORED
				if(g_mode[id] != MODE_B)
					return HAM_IGNORED
				
				Shoot_Special(id)
			}
			else if(pev(id, pev_button) & IN_ATTACK2)
			{
				if(g_change_mode[id])
					return HAM_IGNORED
				
				set_weapon_anim(id, g_mode[id] == MODE_B ? ANIM_CHANGE_A : ANIM_CHANGE_B)
				set_weapons_timeidle(id, CSW_BASE, 4.7)
				set_player_nextattackx(id, 4.7)
				g_change_mode[id] = true
				
				set_task(1.3, "AnimBlockChange", id+TASK_CHANGE)
			}
		}
	}
	
	return HAM_IGNORED
}

public Weapon_Reload(weapon_entity) 
{
	new id = pev(weapon_entity, pev_owner)
	if(!is_user_connected(id))
		return HAM_IGNORED
	if(!g_has_weapon[id])
		return HAM_IGNORED
	if(g_mode[id] != MODE_A)
		return HAM_SUPERCEDE
		
	static iClipExtra
	if(g_has_weapon[id])
		iClipExtra = get_pcvar_num(cvar_clip)

	g_weapon_TmpClip[id] = -1

	new iBpAmmo = cs_get_user_bpammo(id, CSW_BASE)
	new iClip = get_pdata_int(weapon_entity, 51, 4)

	if(iBpAmmo <= 0)
		return HAM_SUPERCEDE

	if(iClip >= iClipExtra)
		return HAM_SUPERCEDE

	g_weapon_TmpClip[id] = iClip

	return HAM_IGNORED
}

public Weapon_Reload_Post(weapon_entity) 
{
	new id = pev(weapon_entity, pev_owner)
	if(!is_user_connected(id))
		return HAM_IGNORED
	if(!g_has_weapon[id])
		return HAM_IGNORED
	if(g_weapon_TmpClip[id] == -1)
		return HAM_IGNORED
	if(g_mode[id] != MODE_A)
		return HAM_SUPERCEDE
	
	set_pdata_int(weapon_entity, 51, g_weapon_TmpClip[id], 4)
	set_pdata_float(weapon_entity, 48, RELOAD_TIME, 4)
	set_pdata_float(id, 83, RELOAD_TIME, 5)
	set_pdata_int(weapon_entity, 54, 1, 4)
	
	set_weapon_anim(id, ANIM_RELOAD_A)
	set_pdata_string(id, (492) * 4, ANIMEXT, -1 , 20)
	
	return HAM_IGNORED
}

/* ===================== END OF ALL HAM FORWARD ====================== */
/* ================= START OF OTHER PUBLIC FUNCTION  ================= */
public give_item(id)
{
	drop_weapons(id, 1)
	
	new iWeapon = fm_give_item(id, weapon_base_buffer)
	if(iWeapon > 0)
	{
		cs_set_weapon_ammo(iWeapon, get_pcvar_num(cvar_clip))
		cs_set_user_bpammo(id, CSW_BASE, get_pcvar_num(cvar_ammo))
		emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM,0,PITCH_NORM)
		
		set_weapon_anim(id, ANIM_DRAW_A)
		set_pdata_float(id, 83, DRAW_TIME, 5)
		
		set_weapon_list(id, true, 1)
		
		set_pdata_string(id, (492) * 4, ANIMEXT, -1 , 20)
		set_pdata_int(iWeapon, 74, MODE_A)
	}
	
	default_ammo[id][0] = get_pcvar_num(cvar_clip)
	default_ammo[id][1] = get_pcvar_num(cvar_ammo)
	g_has_weapon[id] = true
	g_ammo_special[id] = 10
	g_mode[id] = MODE_A
	g_change_mode[id] = false
}

public remove_item(id)
{
	g_has_weapon[id] = false
	g_mode[id] = MODE_A
	g_attack_type[id] = 0
	g_ammo_special[id] = 0
	g_change_mode[id] = false
}

public weapon_hook(id)
{
	engclient_cmd(id, weapon_base_buffer)
	return PLUGIN_HANDLED
}

public replace_weapon_models(id, weaponid)
{	
	switch(weaponid)
	{
		case CSW_BASE:
		{
			if(g_has_weapon[id])
			{
				set_pev(id, pev_viewmodel2, V_MODEL[g_mode[id]])
				set_pev(id, pev_weaponmodel2, P_MODEL[g_mode[id]])
				
				if(oldweap[id] != CSW_BASE) 
				{
					if(!g_ammo_special[id]) set_weapon_list(id, true, 0)
					else set_weapon_list(id, true, 1)
					
					if(task_exists(id+TASK_RELOAD))
					{
						g_ammo_special[id] --
						remove_task(id+TASK_RELOAD)
					}
					
					set_weapon_anim(id, g_mode[id] == MODE_B ? ANIM_DRAW_B : ANIM_DRAW_A)
					set_player_nextattackx(id, DRAW_TIME)
					set_weapons_timeidle(id, CSW_BASE, DRAW_TIME)
					set_pdata_string(id, (492) * 4, g_mode[id] == MODE_B ? ANIMEXT_2 : ANIMEXT, -1 , 20)
				}
			}
		}
	}
	
	if(weaponid != CSW_BASE && g_has_weapon[id])
	{
		set_crosshair(id, 0)
	}
	
	oldweap[id] = weaponid
}

public AnimBlockChange(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_connected(id) || !is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_BASE || !g_has_weapon[id])
		return
	if(!g_change_mode[id])
		return
		
	set_weapon_anim(id, 0)
	set_pev(id, pev_viewmodel2, V_MODEL[2])
	set_task(2.36, "AnimBlockChange_2", id+TASK_CHANGE)
}

public AnimBlockChange_2(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_connected(id) || !is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_BASE || !g_has_weapon[id])
		return
	if(!g_change_mode[id])
		return
		
	if(g_mode[id] == MODE_A)
	{
		set_crosshair(id, 1)
		set_pev(id, pev_viewmodel2, V_MODEL[1])
		set_weapon_anim(id, ANIM_CHANGE_B_COMPLETE)
	}
	else
	{
		set_crosshair(id, 0)
		set_pev(id, pev_viewmodel2, V_MODEL[0])
		set_weapon_anim(id, ANIM_CHANGE_A_COMPLETE)
	}
	
	g_mode[id] = g_mode[id] == MODE_B ? MODE_A : MODE_B
	set_task(1.36, "AnimBlockChange_Complete", id+TASK_CHANGE)
}

public AnimBlockChange_Complete(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_connected(id) || !is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_BASE || !g_has_weapon[id])
		return
	if(!g_change_mode[id])
		return
		
	static weapon_entity
	weapon_entity = fm_get_user_weapon_entity(id, CSW_BASE)
	if(!pev_valid(weapon_entity))
		return
	
	if(g_mode[id] == MODE_B)
	{
		default_ammo[id][0] = cs_get_weapon_ammo(weapon_entity)
		default_ammo[id][1] = cs_get_user_bpammo(id, CSW_BASE)
	}
	else
	{
		set_crosshair(id, 0)
		cs_set_weapon_ammo(weapon_entity, default_ammo[id][0])
		cs_set_user_bpammo(id, CSW_BASE, default_ammo[id][1])
	}
	
	g_change_mode[id] = false
	set_weapon_list(id, true, 1)
}

public Missile_Explode(ent)
{
	if(!pev_valid(ent))
		return
	
	new Float:MissileOrigin[3]
	pev(ent, pev_origin, MissileOrigin)
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, MissileOrigin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, MissileOrigin[0])
	engfunc(EngFunc_WriteCoord, MissileOrigin[1])
	engfunc(EngFunc_WriteCoord, MissileOrigin[2] + 20.0)
	write_short(sExplo[0])
	write_byte(25)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NOSOUND)
	message_end()
		
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, MissileOrigin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, MissileOrigin[0] + random_float(-64.0, 64.0))
	engfunc(EngFunc_WriteCoord, MissileOrigin[1] + random_float(-64.0, 64.0))
	engfunc(EngFunc_WriteCoord, MissileOrigin[2] + random_float(30.0, 35.0))
	write_short(sExplo[1])
	write_byte(30)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NONE)
	message_end()
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, MissileOrigin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, MissileOrigin[0] + random_float(-64.0, 64.0))
	engfunc(EngFunc_WriteCoord, MissileOrigin[1] + random_float(-64.0, 64.0))
	engfunc(EngFunc_WriteCoord, MissileOrigin[2] + random_float(30.0, 35.0))
	write_short(sExplo[2])
	write_byte(30)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NOSOUND)
	message_end()
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_BREAKMODEL)
	engfunc(EngFunc_WriteCoord, MissileOrigin[0])
	engfunc(EngFunc_WriteCoord, MissileOrigin[1])
	engfunc(EngFunc_WriteCoord, MissileOrigin[2])
	engfunc(EngFunc_WriteCoord, 150)
	engfunc(EngFunc_WriteCoord, 150)
	engfunc(EngFunc_WriteCoord, 150)
	engfunc(EngFunc_WriteCoord, random_num(-50, 50))
	engfunc(EngFunc_WriteCoord, random_num(-50, 50))
	engfunc(EngFunc_WriteCoord, random_num(-50, 50))
	write_byte(30)
	write_short(shell_block)
	write_byte(random_num(30, 40))
	write_byte(20)
	write_byte(0)
	message_end()
	
	new a = FM_NULLENT
	while((a = find_ent_in_sphere(a, MissileOrigin, float(get_pcvar_num(cvar_radius)))) != 0)
	{
		if(pev(ent, pev_owner) == a)
			continue
			
		if(pev(a, pev_takedamage) != DAMAGE_NO)
		{
			ExecuteHamB(Ham_TakeDamage, a, 0, pev(ent, pev_owner), float(get_pcvar_num(cvar_dmg_2)), DMG_GENERIC)
		}
	}
	
	set_pev(ent, pev_rendermode, kRenderTransAdd)
	set_pev(ent, pev_renderamt, 0.0)
	set_pev(ent, pev_iuser1, 1)
	set_pev(ent, pev_velocity, {0.0, 0.0, 0.0})
}

public Shoot_Special(id)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return
	if(get_user_weapon(id) != CSW_BASE || !g_has_weapon[id])
		return
	if(g_mode[id] != MODE_B)
		return
	
	static weapon_entity
	weapon_entity = fm_find_ent_by_owner(-1, weapon_base_buffer, id)
	if(!g_ammo_special[id])
	{
		set_weapon_anim(id, ANIM_SHOOT_B_EMPTY)
		emit_sound(id, CHAN_WEAPON, Fire_Sounds[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		set_player_nextattackx(id, 4.0)
		set_weapons_timeidle(id, CSW_BASE, 4.0)
		cs_set_weapon_ammo(weapon_entity, 0)
		
		return
	}
	
	cs_set_weapon_ammo(weapon_entity, 0)
		
	set_player_nextattackx(id, 4.0)
	set_weapons_timeidle(id, CSW_BASE, 4.0)
	
	set_weapon_anim(id, ANIM_SHOOT_B)
	emit_sound(id, CHAN_WEAPON, Fire_Sounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	Shoot_Rocket(id)
	set_weapon_list(id, true, 0)
	
	set_task(4.0, "Reload_Rocket", id+TASK_RELOAD)
}

public Reload_Rocket(id)
{
	id -= TASK_RELOAD
	
	g_ammo_special[id] --
	set_weapon_list(id, true, 1)
}

public Shoot_Rocket(id)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return
	if(get_user_weapon(id) != CSW_BASE || !g_has_weapon[id] || g_mode[id] != MODE_B)
		return
	
	set_pev(id, pev_punchangle, 4.0)
	
	static Float:StartOrigin[3], Float:TargetOrigin[3], Float:angles[3], Float:angles_fix[3]
	get_position(id, 2.0, 0.0, 0.0, StartOrigin)

	pev(id, pev_v_angle, angles)
	
	static ent
	ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	
	if(!pev_valid(ent))
		return
		
	static weapon_entity
	weapon_entity = fm_get_user_weapon_entity(id, CSW_BASE)
	
	if(!pev_valid(weapon_entity))
		return
		
	angles_fix[0] = 360.0 - angles[0]
	angles_fix[1] = angles[1]
	angles_fix[2] = angles[2]

	set_pev(ent, pev_movetype, MOVETYPE_TOSS)
	set_pev(ent, pev_owner, id)
	
	entity_set_string(ent, EV_SZ_classname, "block_missile")
	engfunc(EngFunc_SetModel, ent, S_MODEL[1])
	set_pev(ent, pev_mins,{ -0.1, -0.1, -0.1 })
	set_pev(ent, pev_maxs,{ 0.1, 0.1, 0.1 })
	set_pev(ent, pev_origin, StartOrigin)
	set_pev(ent, pev_angles, angles_fix)
	set_pev(ent, pev_gravity, 0.01)
	set_pev(ent, pev_solid, SOLID_BBOX)
	set_pev(ent, pev_frame, 0.0)
	set_pev(ent, pev_iuser1, 0)
	set_pev(ent, pev_iuser2, 0)
	set_pev(ent, pev_nextthink, get_gametime() + 0.1)
	
	static Float:Velocity[3]
	fm_get_aim_origin(id, TargetOrigin)
	get_speed_vector(StartOrigin, TargetOrigin, 1500.0, Velocity)
	set_pev(ent, pev_velocity, Velocity)
	
	if(get_pcvar_num(cvar_trail[0]))
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(ent)
		write_short(sTrail[0])
		write_byte(3)
		write_byte(2)
		write_byte(255)
		write_byte(255)
		write_byte(255)
		write_byte(150)
		message_end()
	}
	
	emit_sound(id, CHAN_WEAPON, Fire_Sounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	eject_shell(id, shell_block, 0)
	eject_shell(id, shell_block, 1)
}

public set_weapon_shoot_anim(id)
{
	if(g_mode[id] == MODE_A)
	{
		if(!g_attack_type[id])
		{
			set_weapon_anim(id, ANIM_SHOOT1_A)
			g_attack_type[id] = 1
		}
		else if(g_attack_type[id] == 1)
		{
			set_weapon_anim(id, ANIM_SHOOT2_A)
			g_attack_type[id] = 0
		}
	}
}

public eject_shell(id, ShellID, Right)
{
	static Float:player_origin[3], Float:origin[3], Float:origin2[3], Float:gunorigin[3], Float:oldangles[3], Float:v_forward[3], Float:v_forward2[3], Float:v_up[3], Float:v_up2[3], Float:v_right[3], Float:v_right2[3], Float:viewoffsets[3];
	
	pev(id,pev_v_angle, oldangles); pev(id,pev_origin,player_origin); pev(id, pev_view_ofs, viewoffsets);

	engfunc(EngFunc_MakeVectors, oldangles)
	
	global_get(glb_v_forward, v_forward); global_get(glb_v_up, v_up); global_get(glb_v_right, v_right);
	global_get(glb_v_forward, v_forward2); global_get(glb_v_up, v_up2); global_get(glb_v_right, v_right2);
	xs_vec_add(player_origin, viewoffsets, gunorigin);
	
	if(!Right)
	{
		xs_vec_mul_scalar(v_forward, 20.0, v_forward); xs_vec_mul_scalar(v_right, -2.5, v_right);
		xs_vec_mul_scalar(v_up, -1.5, v_up);
		xs_vec_mul_scalar(v_forward2, 19.9, v_forward2); xs_vec_mul_scalar(v_right2, -2.0, v_right2);
		xs_vec_mul_scalar(v_up2, -2.0, v_up2);
	} else {
		xs_vec_mul_scalar(v_forward, 20.0, v_forward); xs_vec_mul_scalar(v_right, 2.5, v_right);
		xs_vec_mul_scalar(v_up, -1.5, v_up);
		xs_vec_mul_scalar(v_forward2, 19.9, v_forward2); xs_vec_mul_scalar(v_right2, 2.0, v_right2);
		xs_vec_mul_scalar(v_up2, -2.0, v_up2);
	}
	
	xs_vec_add(gunorigin, v_forward, origin);
	xs_vec_add(gunorigin, v_forward2, origin2);
	xs_vec_add(origin, v_right, origin);
	xs_vec_add(origin2, v_right2, origin2);
	xs_vec_add(origin, v_up, origin);
	xs_vec_add(origin2, v_up2, origin2);

	static Float:velocity[3]
	get_speed_vector(origin2, origin, random_float(140.0, 160.0), velocity)

	static angle; angle = random_num(0, 360)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_MODEL)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2] - 16.0)
	engfunc(EngFunc_WriteCoord,velocity[0])
	engfunc(EngFunc_WriteCoord,velocity[1])
	engfunc(EngFunc_WriteCoord,velocity[2])
	write_angle(angle)
	write_short(ShellID)
	write_byte(2)
	write_byte(20)
	message_end()
}

/* ============= END OF OTHER PUBLIC FUNCTION (Weapon) ============= */
/* ================= START OF ALL STOCK TO MACROS ================== */
stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	static Float:num; num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs, vUp) //for player
	xs_vec_add(vOrigin, vUp, vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle, ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock set_weapon_list(id, bool:set, ammo)
{
	if(!is_user_connected(id))
		return
	
	message_begin(MSG_ONE, get_user_msgid("WeaponList"), _, id)
	if(!g_mode[id]) write_string(!set ? weapon_base_buffer : weapon_name_buffer_1)
	else write_string(!set ? weapon_base_buffer : weapon_name_buffer_2)
	write_byte(3)
	write_byte(200)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(4)
	write_byte(CSW_BASE)
	write_byte(0)
	message_end()
	
	if(g_mode[id] == MODE_B)
	{
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), _, id)
		write_byte(1)
		write_byte(CSW_BASE)
		write_byte(ammo)
		message_end()
	
		static weapon_ent
		weapon_ent = fm_get_user_weapon_entity(id, CSW_BASE)
		
		if(!pev_valid(weapon_ent))
			return
		
		cs_set_weapon_ammo(weapon_ent, ammo)
		cs_set_user_bpammo(id, CSW_BASE, g_ammo_special[id])
		
		set_crosshair(id, 1)
	}
}

stock set_crosshair(id, hide)
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("HideWeapon"), _, id)
	write_byte(hide == 1 ? (1<<6) : (1>>6))
	message_end()
}

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num = 0, i, weaponid
	get_user_weapons(id, weapons, num)
     
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]
          
		if(dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM))
		{
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock set_player_nextattackx(id, Float:nexttime)
{
	if(!is_user_alive(id))
		return
		
	set_pdata_float(id, 83, nexttime, 5)
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	if(!is_user_alive(id))
		return
		
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 1.0, 4)
}

stock set_weapon_anim(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}

stock precache_viewmodel_sound(const model[]) // I Get This From BTE
{
	new file, i, k
	if((file = fopen(model, "rt")))
	{
		new szsoundpath[64], NumSeq, SeqID, Event, NumEvents, EventID
		fseek(file, 164, SEEK_SET)
		fread(file, NumSeq, BLOCK_INT)
		fread(file, SeqID, BLOCK_INT)
		
		for(i = 0; i < NumSeq; i++)
		{
			fseek(file, SeqID + 48 + 176 * i, SEEK_SET)
			fread(file, NumEvents, BLOCK_INT)
			fread(file, EventID, BLOCK_INT)
			fseek(file, EventID + 176 * i, SEEK_SET)
			
			// The Output Is All Sound To Precache In ViewModels (GREAT :V)
			for(k = 0; k < NumEvents; k++)
			{
				fseek(file, EventID + 4 + 76 * k, SEEK_SET)
				fread(file, Event, BLOCK_INT)
				fseek(file, 4, SEEK_CUR)
				
				if(Event != 5004)
					continue
				
				fread_blocks(file, szsoundpath, 64, BLOCK_CHAR)
				
				if(strlen(szsoundpath))
				{
					strtolower(szsoundpath)
					engfunc(EngFunc_PrecacheSound, szsoundpath)
				}
			}
		}
	}
	fclose(file)
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, 41, 4)
}

/* ================= END OF ALL STOCK AND PLUGINS CREATED ================== */
public dar_arma(id, ItemID)
{
	if( ItemID!= variable ) return;
	{
		give_item(id);
//si te das cuenta usa la variable anterior donde registramos el item para ver si es igual a la que vera el plugin y le da el item
}
}
