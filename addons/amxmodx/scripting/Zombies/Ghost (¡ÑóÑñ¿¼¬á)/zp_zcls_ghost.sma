#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <zombie_escape_v1>
#include <engine>

#define PLUGIN "[ZP] Class - Ghost"
#define VERSION "1.3"
#define AUTHOR "HoRRoR, Fry!"

// Zombie Attributes
new g_zclass_ghost
new const zclass_name[] = "Ghost" // name
new const zclass_info[] = "Press G To invisible" // description
new const zclass4_model[] = { "zombie_ghost" }
new const zclass4_clawmodel[] = { "v_zombie.mdl" }
const zclass_health = 7700 // health
const zclass_speed = 295 // speed
const Float:zclass_gravity = 0.65 // gravity
const Float:zclass_knockback = 4.2// knockback

new i_stealth_time_hud[33]
new g_cooldown[33]
new g_infections[33]
new Float:g_stealth_time[33]
new i_cooldown_time[33]
new g_maxplayers

// --- config ------------------------ //
new Float:g_stealth_time_standart = 5.0 //first stealth time
new Float:g_stealth_cooldown_standart = 45.0 //cooldown time
new const sound_ghost_stealth[] = "zombie_plague/zp_fz_translucent.wav" //stealth sound
new const sound_ghost_stealth_end[] = "zombie_plague/ghos111.wav" //end stealth sound
// ----------------------------------- //

new g_ghost_active[33], fw_archivement_ghost;

public plugin_init()
{	
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("zp_zclass_ghost_zombie",VERSION,FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY)
	register_clcmd("ability1", "use_ability_one")
	register_concmd("ability1", "use_ability_one")
	register_concmd("drop", "use_ability_one")
	//register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	register_logevent("roundStart", 2, "1=Round_Start")
	g_maxplayers = get_maxplayers()
	fw_archivement_ghost = CreateMultiForward("archivement_lusty", ET_STOP, FP_CELL)
}

public plugin_precache()
{
	g_zclass_ghost = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass4_model, zclass4_clawmodel, 12, 0, ADMIN_ALL, 
		zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)
	precache_sound(sound_ghost_stealth)
	precache_sound(sound_ghost_stealth_end)
}

public roundStart()
{
	for (new i = 1; i <= g_maxplayers; i++)
	{
		i_cooldown_time[i] = floatround(g_stealth_cooldown_standart)
		g_cooldown[i] = 0
		remove_task(i)
	}
}

public use_ability_one(id)
{
	if(is_valid_ent(id) && is_user_alive(id) && zp_get_user_zombie(id) && zp_get_class(id) < NEMESIS && zp_get_user_zombie_class(id) == g_zclass_ghost)
	{
		if(g_cooldown[id] == 0)
		{
			zp_set_ghost(id, 1);
			//set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0)
			emit_sound(id, CHAN_STREAM, sound_ghost_stealth, 1.0, ATTN_NORM, 0, PITCH_NORM)
			set_task(g_stealth_time[id],"ghost_make_visible",id)
			set_task(g_stealth_cooldown_standart,"reset_cooldown",id)
			g_cooldown[id] = 1
			
			i_cooldown_time[id] = floatround(g_stealth_cooldown_standart)
			i_stealth_time_hud[id] = floatround(g_stealth_time[id])
			
			set_task(1.0, "ShowHUD", id, _, _, "a",i_cooldown_time[id])
			set_task(1.0, "ShowHUDstealthes", id, _, _, "a",i_stealth_time_hud[id])
			g_ghost_active[id] = 1;
		}
	}
}


public ShowHUD(id)
{
	if(is_valid_ent(id) && is_user_alive(id))
	{
		i_cooldown_time[id] = i_cooldown_time[id] - 1;
		set_hudmessage(200, 100, 0, 0.75, 0.92, 0, 1.0, 1.1, 0.0, 0.0, -1)
		show_hudmessage(id, "Stealth cooldown: %d",i_cooldown_time[id])
	}else{
		remove_task(id)
	}
}

public ShowHUDstealthes(id)
{
	if(is_valid_ent(id) && is_user_alive(id))
	{
		i_stealth_time_hud[id] = i_stealth_time_hud[id] - 1;
		set_hudmessage(200, 100, 0, -1.0, 0.92, 0, 1.0, 1.1, 0.0, 0.0, -1)
		show_hudmessage(id, "Stealth time: %d",i_stealth_time_hud[id])
	}else{
		remove_task(id)
	}
}

public ghost_make_visible(id)
{
	if(is_valid_ent(id) && zp_get_user_zombie(id) && zp_get_class(id) < NEMESIS && zp_get_user_zombie_class(id) == g_zclass_ghost)
	{
		zp_set_ghost(id, 0);
		//set_user_rendering(id, kRenderFxHologram, 0, 0, 0, kRenderTransAlpha, 125)
		emit_sound(id, CHAN_STREAM, sound_ghost_stealth_end, 1.0, ATTN_NORM, 0, PITCH_NORM)
		g_ghost_active[id] = 0;
	}
}

public reset_cooldown(id)
{
	if(is_valid_ent(id) && zp_get_user_zombie(id) && zp_get_class(id) < NEMESIS && zp_get_user_zombie_class(id) == g_zclass_ghost)
	{
		g_cooldown[id] = 0
		
		new text[100]
		format(text,99,"^x04[ZP]^x01 Your ability ^x04Stealth^x01 is ready.")
		message_begin(MSG_ONE,get_user_msgid("SayText"),{0,0,0},id) 
		write_byte(id) 
		write_string(text) 
		message_end()
	}
}

public zp_user_infected_post(id, infector)
{
	if ((zp_get_user_zombie_class(id) == g_zclass_ghost) &&  zp_get_class(id) < NEMESIS)
	{
		zp_set_ghost(id, 0);
		//set_user_rendering(id, kRenderFxHologram, 0, 0, 0, kRenderTransAlpha, 125)
		g_ghost_active[id] = 0;
		
		new text[100]
		new note_cooldown = floatround(g_stealth_cooldown_standart)
		new note_stealthtime = floatround(g_stealth_time_standart)
		format(text,99,"^x04[ZP]^x01 Your ability is ^x04Stealth^x01. Cooldown:^x04 %d ^x01sec. Stealth time: ^x04%d^x01sec, Use letter ^x04 G.",note_cooldown,note_stealthtime)
		message_begin(MSG_ONE,get_user_msgid("SayText"),{0,0,0},id) 
		write_byte(id) 
		write_string(text) 
		message_end()
		
		i_cooldown_time[id] = floatround(g_stealth_cooldown_standart)
		remove_task(id)
		
		g_stealth_time[id] = g_stealth_time_standart
		g_cooldown[id] = 0
		g_infections[id] = 0
		
		client_cmd(id,"bind F1 ability1")
	}
	
	if((zp_get_user_zombie_class(infector) == g_zclass_ghost) && zp_get_class(id) < NEMESIS)
	{
		g_stealth_time[infector] = g_stealth_time[infector] + 1;
		infections_hud(infector)
	}
	if(g_ghost_active[infector])
	{
		new ret
		ExecuteForward(fw_archivement_ghost, ret, infector)
	}
		
}

public infections_hud(id)
{
	if(is_valid_ent(id) && zp_get_user_zombie(id) && !zp_get_user_nemesis(id) && zp_get_user_zombie_class(id) == g_zclass_ghost)
	{
		new i_stealth_time = floatround(g_stealth_time[id])
		new text[100]
		format(text,99,"^x04[ZP]^x01 Your stealth time is^x04 %d ^x01seconds.",i_stealth_time)
		message_begin(MSG_ONE,get_user_msgid("SayText"),{0,0,0},id) 
		write_byte(id) 
		write_string(text) 
		message_end() 
	}
}

public zp_user_humanized_post(id)
{
	zp_set_ghost(id, 0);
	//set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 255)
	remove_task(id)
	g_ghost_active[id] = 0;
}

public zp_user_unfrozen(id)
{
	if(is_valid_ent(id) && is_user_alive(id) && zp_get_user_zombie(id) && zp_get_class(id) < NEMESIS && zp_get_user_zombie_class(id) == g_zclass_ghost)
	{
		zp_set_ghost(id, 0);
		//set_user_rendering(id, kRenderFxHologram, 0, 0, 0, kRenderTransAlpha, 125)
		g_ghost_active[id] = 0;
	}
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if (!(damage_type & DMG_FALL) || !zp_get_user_zombie(victim) || zp_get_user_zombie_class(victim) != g_zclass_ghost)
		return HAM_IGNORED
	
	SetHamParamFloat(4, 0.0)
	return HAM_HANDLED
}

public fw_PlayerPreThink(player)
{
	if(!is_user_alive(player))
		return FMRES_IGNORED
		
	if(zp_get_user_zombie(player) && zp_get_user_zombie_class(player) == g_zclass_ghost && zp_get_class(player) < NEMESIS)
		set_pev(player, pev_flTimeStepSound, 999)
		
	return FMRES_IGNORED
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
