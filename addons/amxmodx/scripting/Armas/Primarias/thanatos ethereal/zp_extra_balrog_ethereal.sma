/*================================================================================
 
			--------------------------------
			[ZP] Extra Item: Balrog Ethereal
			--------------------------------

		Balrog Ethereal
		Copyright (C) 2017 by Crazy

		-------------------
		-*- Description -*-
		-------------------

		This plugin add a new weapon into your zombie plague mod with
		the name of Balrog Ethereal. That weapon launch a powerfull beams!
		When the laser hit any object, a explosion effect with red color appers.

		----------------
		-*- Commands -*-
		----------------

		* zp_give_balrog_ethereal <target> - Give the item to target.

		-------------
		-*- Cvars -*-
		-------------

		* zp_balrog_ethereal_ammo <number> - Ammo amout.
		* zp_balrog_ethereal_clip <number> - Clip amout. (Max: 100)
		* zp_balrog_ethereal_one_round <0/1> - Only one round.
		* zp_balrog_ethereal_damage <number> - Damage multiplier.
		* zp_balrog_ethereal_unlimited <0/1> - Unlimited ammunition.

		------------------
		-*- Change Log -*-
		------------------

		* v1.5: (Mar 2017)
			- Updated all the code, added explosion effect, added new cvars;

		* v1.6: (Mar 2017)
			- Added custom weapon hud;

		---------------
		-*- Credits -*-
		---------------

		* MeRcyLeZZ: for the nice zombie plague mod.
		* Crazy: created the extra item code.
		* deanamx: for the nice weapon model.
		* And all zombie-mod players that use this weapon.


=================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <zombie_escape_v1>


/*================================================================================
 [Plugin Customization]
=================================================================================*/

// Item Name
#define ITEM_NAME "Balrog Ethereal"

// Item Cost
#define ITEM_COST 70

/*================================================================================
 Customization ends here! Yes, that's it. Editing anything beyond
 here is not officially supported. Proceed at your own risk...
=================================================================================*/

new const PLUGIN_VERSION[] = "v1.6";

new const V_BALROG_MDL[64] = "models/zombie_plague/v_balrog_ethereal.mdl";
new const P_BALROG_MDL[64] = "models/zombie_plague/p_balrog_ethereal.mdl";
new const W_BALROG_MDL[64] = "models/zombie_plague/w_balrog_ethereal.mdl";

new const BALROG_SOUNDS[][] = { "weapons/ethereal_shoot.wav", "weapons/ethereal_reload.wav", "weapons/ethereal_idle1.wav", "weapons/ethereal_draw.wav" };

new g_has_balrog[33], g_laser_sprite, g_balrog_exp, g_balrog, g_event_balrog, g_playername[33][32], g_maxplayers, g_primary_attack, g_balrog_reload_clip[33], cvar_balrog_clip, cvar_balrog_ammo, cvar_balrog_damage, cvar_balrog_oneround, cvar_balrog_unlimited;

const BALROG_KEY = 0982478;

const m_iClip = 51;
const m_flNextAttack = 83;
const m_fInReload = 54;

const OFFSET_WEAPON_OWNER = 41;
const OFFSET_LINUX_WEAPONS = 4;
const OFFSET_LINUX = 5;
const OFFSET_ACTIVE_ITEM = 373;

const WEAPON_BITSUM = ((1<<CSW_SCOUT) | (1<<CSW_XM1014) | (1<<CSW_MAC10) | (1<<CSW_AUG) | (1<<CSW_UMP45) | (1<<CSW_SG550) | (1<<CSW_P90) | (1<<CSW_FAMAS) | (1<<CSW_AWP) | (1<<CSW_MP5NAVY) | (1<<CSW_M249) | (1<<CSW_M3) | (1<<CSW_M4A1) | (1<<CSW_TMP) | (1<<CSW_G3SG1) | (1<<CSW_SG552) | (1<<CSW_AK47) | (1<<CSW_GALIL));

enum
{
	idle = 0,
	reload,
	draw,
	shoot1,
	shoot2,
	shoot3
}

public plugin_init()
{
	/* Plugin register */
	register_plugin("[ZP] Extra Item: Balrog Ethereal", PLUGIN_VERSION, "Crazy");

	/* Item register */
	//g_balrog = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN);
	g_balrog = zp_arma(ITEM_NAME, 0, 3, PRIMARIA, ADMIN_ALL, "[SILVER]" );
	/* Events */
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");

	/* Messages */
	register_message(get_user_msgid("CurWeapon"), "message_cur_weapon");

	/* Admin command */
	//register_concmd("zp_give_balrog_ethereal", "cmd_give_balrog", 0);

	/* Forwards */
	register_forward(FM_UpdateClientData, "fw_UpdateData_Post", 1);
	register_forward(FM_SetModel, "fw_SetModel");
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent");

	/* Ham Forwards */
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_ump45", "fw_Item_Deploy_Post", 1);
	RegisterHam(Ham_Item_AddToPlayer, "weapon_ump45", "fw_Item_AddToPlayer_Post", 1);
	RegisterHam(Ham_Item_PostFrame, "weapon_ump45", "fw_Item_PostFrame");
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_ump45", "fw_PrimaryAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_ump45", "fw_PrimaryAttack_Post", 1);
	RegisterHam(Ham_Weapon_Reload, "weapon_ump45", "fw_Reload");
	RegisterHam(Ham_Weapon_Reload, "weapon_ump45", "fw_Reload_Post", 1);
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage");
	//RegisterHamBots(Ham_TakeDamage, "fw_TakeDamage");

	/* Cvars */
	cvar_balrog_clip = register_cvar("zp_balrog_minigun_clip", "50");
	cvar_balrog_ammo = register_cvar("zp_balrog_minigun_ammo", "200");
	cvar_balrog_damage = register_cvar("zp_balrog_minigun_damage", "3.2");
	cvar_balrog_oneround = register_cvar("zp_balrog_minigun_one_round", "0");
	cvar_balrog_unlimited = register_cvar("zp_balrog_minigun_unlimited", "0");

	/* Max Players */
	g_maxplayers = get_maxplayers()
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_BALROG_MDL);
	//engfunc(EngFunc_PrecacheModel, P_BALROG_MDL);
	engfunc(EngFunc_PrecacheModel, W_BALROG_MDL);

	engfunc(EngFunc_PrecacheGeneric, "sprites/weapon_bethereal.txt");
	engfunc(EngFunc_PrecacheGeneric, "sprites/640hud2_bethereal.spr");
	engfunc(EngFunc_PrecacheGeneric, "sprites/640hud10_bethereal.spr");
	engfunc(EngFunc_PrecacheGeneric, "sprites/640hud74_bethereal.spr");

	for (new i = 0; i < sizeof BALROG_SOUNDS; i++)
	engfunc(EngFunc_PrecacheSound, BALROG_SOUNDS[i]);

	g_laser_sprite = precache_model("sprites/laserbeam.spr");
	g_balrog_exp = precache_model("sprites/zombie_plague/balrog_ethereal_exp.spr");

	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1);
	register_clcmd("weapon_bethereal", "cmd_balrog_selected");
}

public zp_user_infected_post(id)
{
	g_has_balrog[id] = false;
}

public zp_user_humanized_post(id)
{
	g_has_balrog[id] = false;
}

public client_putinserver(id)
{
	g_has_balrog[id] = false;

	get_user_name(id, g_playername[id], charsmax(g_playername[]));
}

public event_round_start()
{
	for (new id = 0; id <= g_maxplayers; id++)
	{
		if (get_pcvar_num(cvar_balrog_oneround))
		g_has_balrog[id] = false;
	}
}

public cmd_give_balrog(id, level, cid)
{
	if ((get_user_flags(id) & level) != level)
		return PLUGIN_HANDLED;

	static arg[32], player;
	read_argv(1, arg, charsmax(arg));
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF));
	
	if (!player)
		return PLUGIN_HANDLED;

	if (g_has_balrog[player])
	{
		client_print(id, print_chat, "[ZP] The %s already have the %s.", g_playername[player], ITEM_NAME);
		return PLUGIN_HANDLED;
	}

	give_balrog(player);
	
	client_print(player, print_chat, "[ZP] You won a %s from %s!", ITEM_NAME, g_playername[id]);

	return PLUGIN_HANDLED;
}

public cmd_balrog_selected(client)
{
	engclient_cmd(client, "weapon_ump45");
	return PLUGIN_HANDLED;
}

public message_cur_weapon(msg_id, msg_dest, msg_entity)
{
	if (!is_user_alive(msg_entity))
		return;

	if (!g_has_balrog[msg_entity])
		return;

	if (get_user_weapon(msg_entity) != CSW_UMP45)
		return;

	if (get_msg_arg_int(1) != 1)
		return;

	if (get_pcvar_num(cvar_balrog_unlimited))
	{
		static ent;
		ent = fm_cs_get_current_weapon_ent(msg_entity);

		if (!pev_valid(ent))
			return;

		cs_set_weapon_ammo(ent, get_pcvar_num(cvar_balrog_clip));
		set_msg_arg_int(3, get_msg_argtype(3), get_pcvar_num(cvar_balrog_clip));
	}
}

public dar_arma(id, itemid)
{
	if (itemid != g_balrog)
		return;

	if (g_has_balrog[id])
	{
		client_print(id, print_chat, "[ZP] You already have the %s.", ITEM_NAME);
		return;
	}

	give_balrog(id);

	client_print(id, print_chat, "[ZP] You bought the %s.", ITEM_NAME);
}

public fw_UpdateData_Post(id, sendweapons, cd_handle)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED;

	if (!g_has_balrog[id])
		return FMRES_IGNORED;

	if (get_user_weapon(id) != CSW_UMP45)
		return FMRES_IGNORED;

	set_cd(cd_handle, CD_flNextAttack, halflife_time() + 0.001);

	return FMRES_IGNORED;
}

public fw_SetModel(ent, const model[])
{
	if (!pev_valid(ent))
		return FMRES_IGNORED;

	if (!equal(model, "models/w_ump45.mdl"))
		return HAM_IGNORED;

	static class_name[33];
	pev(ent, pev_classname, class_name, charsmax(class_name));

	if (!equal(class_name, "weaponbox"))
		return FMRES_IGNORED;

	static owner, weapon;
	owner = pev(ent, pev_owner);
	weapon = find_ent_by_owner(-1, "weapon_ump45", ent);

	if (!g_has_balrog[owner] || !pev_valid(weapon))
		return FMRES_IGNORED;

	g_has_balrog[owner] = false;

	set_pev(weapon, pev_impulse, BALROG_KEY);

	engfunc(EngFunc_SetModel, ent, W_BALROG_MDL);

	return FMRES_SUPERCEDE;
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if ((eventid != g_event_balrog) || !g_primary_attack)
		return FMRES_IGNORED;

	if (!(1 <= invoker <= g_maxplayers))
		return FMRES_IGNORED;

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2);

	return FMRES_SUPERCEDE;
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if (!equal("events/ump45.sc", name))
		return HAM_IGNORED;

	g_event_balrog = get_orig_retval()

	return FMRES_HANDLED;
}

public fw_Item_Deploy_Post(ent)
{
	if (!pev_valid(ent))
		return HAM_IGNORED;

	new id = get_pdata_cbase(ent, OFFSET_WEAPON_OWNER, OFFSET_LINUX_WEAPONS);

	if (!is_user_alive(id))
		return HAM_IGNORED;

	if (!g_has_balrog[id])
		return HAM_IGNORED;

	set_pev(id, pev_viewmodel2, V_BALROG_MDL);
	//set_pev(id, pev_weaponmodel2, P_BALROG_MDL);

	play_weapon_anim(id, draw);

	return HAM_IGNORED;
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if (!pev_valid(ent))
		return HAM_IGNORED;

	if (!is_user_alive(id))
		return HAM_IGNORED;

	if (pev(ent, pev_impulse) == BALROG_KEY)
	{
		g_has_balrog[id] = true;
		set_pev(ent, pev_impulse, 0);
	}

	message_begin(MSG_ONE, get_user_msgid("WeaponList"), _, id)
	write_string((g_has_balrog[id] ? "weapon_bethereal" : "weapon_ump45"))
	write_byte(6)
	write_byte(100)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(15)
	write_byte(CSW_UMP45)
	write_byte(0)
	message_end()

	return HAM_IGNORED;
}

public fw_Item_PostFrame(ent)
{
	if (!pev_valid(ent))
		return HAM_IGNORED;

	new id = get_pdata_cbase(ent, OFFSET_WEAPON_OWNER, OFFSET_LINUX_WEAPONS);

	if (!is_user_alive(id))
		return HAM_IGNORED;

	if (!g_has_balrog[id])
		return HAM_IGNORED;

	static cvar_clip; cvar_clip = get_pcvar_num(cvar_balrog_clip);

	new clip = get_pdata_int(ent, m_iClip, OFFSET_LINUX_WEAPONS);
	new bpammo = cs_get_user_bpammo(id, CSW_UMP45);

	new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, OFFSET_LINUX);
	new fInReload = get_pdata_int(ent, m_fInReload, OFFSET_LINUX_WEAPONS);

	if (fInReload && flNextAttack <= 0.0)
	{
		new temp_clip = min(cvar_clip - clip, bpammo);

		set_pdata_int(ent, m_iClip, clip + temp_clip, OFFSET_LINUX_WEAPONS);

		cs_set_user_bpammo(id, CSW_UMP45, bpammo-temp_clip);

		set_pdata_int(ent, m_fInReload, 0, OFFSET_LINUX_WEAPONS);

		fInReload = 0;
	}

	return HAM_IGNORED;
}

public fw_PrimaryAttack(ent)
{
	if (!pev_valid(ent))
		return HAM_IGNORED;

	new id = get_pdata_cbase(ent, OFFSET_WEAPON_OWNER, OFFSET_LINUX_WEAPONS);

	if (!is_user_alive(id))
		return HAM_IGNORED;

	if (!g_has_balrog[id])
		return HAM_IGNORED;

	if (!cs_get_weapon_ammo(ent))
		return HAM_IGNORED;

	g_primary_attack = true;

	return HAM_IGNORED;
}

public fw_PrimaryAttack_Post(ent)
{
	if (!pev_valid(ent))
		return HAM_IGNORED;

	new id = get_pdata_cbase(ent, OFFSET_WEAPON_OWNER, OFFSET_LINUX_WEAPONS);

	if (!is_user_alive(id))
		return HAM_IGNORED;

	if (!g_has_balrog[id])
		return HAM_IGNORED;

	if (!cs_get_weapon_ammo(ent))
		return HAM_IGNORED;

	g_primary_attack = false;

	play_weapon_anim(id, random_num(shoot1, shoot3));

	emit_sound(id, CHAN_WEAPON, BALROG_SOUNDS[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

	make_laser_beam(id, 7, 100, 0, 0);

	return HAM_IGNORED;
}

public fw_Reload(ent)
{
	if (!pev_valid(ent))
		return HAM_IGNORED;

	new id = get_pdata_cbase(ent, OFFSET_WEAPON_OWNER, OFFSET_LINUX_WEAPONS);

	if (!is_user_alive(id))
		return HAM_IGNORED;

	if (!g_has_balrog[id])
		return HAM_IGNORED;

	static cvar_clip;

	if (g_has_balrog[id])
		cvar_clip = get_pcvar_num(cvar_balrog_clip);

	g_balrog_reload_clip[id] = -1;

	new clip = get_pdata_int(ent, m_iClip, OFFSET_LINUX_WEAPONS);
	new bpammo = cs_get_user_bpammo(id, CSW_UMP45);

	if (bpammo <= 0)
		return HAM_SUPERCEDE;

	if (clip >= cvar_clip)
		return HAM_SUPERCEDE;
	
	g_balrog_reload_clip[id] = clip;

	return HAM_IGNORED;
}

public fw_Reload_Post(ent)
{
	if (!pev_valid(ent))
		return HAM_IGNORED;

	new id = get_pdata_cbase(ent, OFFSET_WEAPON_OWNER, OFFSET_LINUX_WEAPONS);

	if (!is_user_alive(id))
		return HAM_IGNORED;

	if (!g_has_balrog[id])
		return HAM_IGNORED;

	if (g_balrog_reload_clip[id] == -1)
		return HAM_IGNORED;

	set_pdata_int(ent, m_iClip, g_balrog_reload_clip[id], OFFSET_LINUX_WEAPONS);
	set_pdata_int(ent, m_fInReload, 1, OFFSET_LINUX_WEAPONS);

	play_weapon_anim(id, reload);

	return HAM_IGNORED;
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, dmg_bits)
{
	if (!is_user_alive(attacker))
		return HAM_IGNORED;

	if (!g_has_balrog[attacker])
		return HAM_IGNORED;

	if (get_user_weapon(attacker) != CSW_UMP45)
		return HAM_IGNORED;

	SetHamParamFloat(OFFSET_LINUX_WEAPONS, damage * get_pcvar_float(cvar_balrog_damage));

	make_explosion_effect(attacker);

	return HAM_IGNORED;
}

public fw_TraceAttack_Post(ent, attacker, Float:damage, Float:dir[3], ptr, dmg_bits)
{
	if (!is_user_alive(attacker))
		return HAM_IGNORED;

	if (get_user_weapon(attacker) != CSW_UMP45)
		return HAM_IGNORED;

	if (!g_has_balrog[attacker])
		return HAM_IGNORED;

	make_explosion_effect(attacker);

	return HAM_IGNORED;
}

give_balrog(id)
{
	drop_primary(id);

	g_has_balrog[id] = true;

	new weapon = fm_give_item(id, "weapon_ump45");

	cs_set_weapon_ammo(weapon, get_pcvar_num(cvar_balrog_clip));
	cs_set_user_bpammo(id, CSW_UMP45, get_pcvar_num(cvar_balrog_ammo));
}

play_weapon_anim(id, frame)
{
	set_pev(id, pev_weaponanim, frame);

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = id)
	write_byte(frame)
	write_byte(pev(id, pev_body))
	message_end()
}

make_laser_beam(id, Size, R, G, B) 
{
    static End[3];
    get_user_origin(id, End, 3);
	
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte (TE_BEAMENTPOINT)
    write_short( id |0x1000 )
    write_coord(End[0])
    write_coord(End[1])
    write_coord(End[2])
    write_short(g_laser_sprite)
    write_byte(0)
    write_byte(1)
    write_byte(1)
    write_byte(Size)
    write_byte(4)
    write_byte(R)
    write_byte(G)
    write_byte(B)
    write_byte(255)
    write_byte(0)
    message_end()
}

make_explosion_effect(id)
{
	static end[3];
	get_user_origin(id, end, 3);

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(3)
	write_coord(end[0])
	write_coord(end[1])
	write_coord(end[2])
	write_short(g_balrog_exp)
	write_byte(10)
	write_byte(15)
	write_byte(4)
	message_end()
}

drop_primary(id)
{
	static weapons[32], num;
	get_user_weapons(id, weapons, num);

	for (new i = 0; i < num; i++)
	{
		if (WEAPON_BITSUM & (1<<weapons[i]))
		{
			static wname[32];
			get_weaponname(weapons[i], wname, sizeof wname - 1);

			engclient_cmd(id, "drop", wname);
		}
	}
}

stock fm_give_item(index, const item[])
{
	if (!equal(item, "weapon_", 7) && !equal(item, "ammo_", 5) && !equal(item, "item_", 5) && !equal(item, "tf_weapon_", 10))
		return 0;

	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, item));
	if (!pev_valid(ent))
		return 0;

	new Float:origin[3];
	pev(index, pev_origin, origin);
	set_pev(ent, pev_origin, origin);
	set_pev(ent, pev_spawnflags, pev(ent, pev_spawnflags) | SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn, ent);

	new save = pev(ent, pev_solid);
	dllfunc(DLLFunc_Touch, ent, index);
	if (pev(ent, pev_solid) != save)
		return ent;

	engfunc(EngFunc_RemoveEntity, ent);

	return -1;
}

stock fm_cs_get_current_weapon_ent(id)
{
	if (pev_valid(id) != 2)
		return -1;
	
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX);
}