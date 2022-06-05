#include <amxmodx>
#include <fakemeta>
#include <zombie_escape_v1>


#define PREFIX "[ZP]"
#define TASK_COOLDOWN 1403432+10219999

new const regeneration_name[] = "Regeneration Zombie";
new const regeneration_info[] = "Regenerate its HP";
new const regeneration_model[] = "regeneration_zombie";
new const regeneration_clawmodel[] = "v_regeneration_zombie.mdl";
const regeneration_health = 10000;
const regeneration_speed = 280;
const Float:regeneration_gravity = 0.9;
const Float:regeneration_knockback = 3.0;

new const heal_sound[] = "zombie_regeneration/zombie_heal.wav";

new zclass_regeneration, cvar_regen_time, cvar_regen_times, cvar_regen_amount, cvar_regen_cooldown;
new Float:g_regenered_health[33], g_regen_times[33];
new g_heal_sprite;

public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Regeneration Zombie", "1.0", "kapitana");
	
	register_event("Damage", "SetRegeneration", "be", "2>0");
	
	cvar_regen_time = register_cvar("zp_regen_time", "1.5"); // After how much time the zombie will heal
	cvar_regen_times = register_cvar("zp_regen_times", "35"); // How many times it can heal before cooldown
	cvar_regen_amount = register_cvar("zp_regen_amount", "57.3"); // How much HP the zombie recovers from every heal
	cvar_regen_cooldown = register_cvar("zp_regen_cooldown", "15.0"); // How long is the cooldown
}

public plugin_precache()
{
	zclass_regeneration = zp_register_class(CLASS_ZOMBIE, regeneration_name, regeneration_info, regeneration_model, 
		regeneration_clawmodel, 13, 0, ADMIN_ALL, regeneration_health, 0, regeneration_speed, regeneration_gravity, regeneration_knockback);
	
	g_heal_sprite = engfunc(EngFunc_PrecacheModel, "sprites/zombie_regeneration/heal.spr");
	
	engfunc(EngFunc_PrecacheSound, heal_sound);
}

public zp_user_infected_post(player)
{
	if(zp_get_user_zombie_class(player) != zclass_regeneration || zp_get_class(player) >= NEMESIS)
		return;
	
	
	g_regen_times[player] = 0;
	g_regenered_health[player] = 0.0;
}

public SetRegeneration(player)
{
	if(!is_user_alive(player) || zp_get_user_zombie_class(player) != zclass_regeneration || !zp_get_user_zombie(player) || zp_get_class(player) >= NEMESIS || task_exists(player+TASK_COOLDOWN))
		return;
	
	if(task_exists(player)) remove_task(player)
	
	static Float:g_health;
	pev(player, pev_health, g_health);
	
	if(g_health < zp_get_zombie_maxhealth(player))
		set_task(get_pcvar_float(cvar_regen_time), "Regenerate", player);
}

public Regenerate(player)
{
	if(!is_user_alive(player) || !zp_get_user_zombie(player) || zp_get_class(player) >= NEMESIS || zp_get_user_zombie_class(player) != zclass_regeneration)
		return;

	
	if(g_regen_times[player] >= get_pcvar_num(cvar_regen_times))
	{
		set_task(get_pcvar_float(cvar_regen_cooldown), "RegenerationCooldown", player+TASK_COOLDOWN);
		client_print(player, print_center, "Please wait %.1f second[s]", get_pcvar_float(cvar_regen_cooldown));
		ChatColor(player, "!g%s!y Please wait !g%.1f!y second[s] for the recharge of your !gRegeneration!y abilities!", PREFIX, get_pcvar_float(cvar_regen_cooldown));
		
		return;
	}
	
	static Float:g_health;
	pev(player, pev_health, g_health);
	
	if(g_health >= zp_get_zombie_maxhealth(player))
	{
		set_hudmessage(0, 230, 0, -1.0, 0.28, 1, 0.00, 1.8, 2.5, 2.5, -1);
		show_hudmessage(player, "Regeneration Complete!^nYou have successfully regenerated %.1f HP!", g_regenered_health[player]);
		
		engfunc(EngFunc_EmitSound, player, CHAN_BODY, heal_sound, 1.0, ATTN_NORM, 0, PITCH_NORM);
		g_regenered_health[player] = 0.0;
		
		return;
	}
	
	static origin[3];
	get_user_origin(player, origin);
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_SPRITE);
	write_coord(origin[0]);
	write_coord(origin[1]);
	write_coord(origin[2]+=40);
	write_short(g_heal_sprite);
	write_byte(8);
	write_byte(255);
	message_end();
	
	g_regen_times[player] += 1;
	g_regenered_health[player] += get_pcvar_float(cvar_regen_amount);
	
	set_pev(player, pev_health, g_health + get_pcvar_float(cvar_regen_amount));
	engfunc(EngFunc_EmitSound, player, CHAN_BODY, heal_sound, 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	set_task(get_pcvar_float(cvar_regen_time), "Regenerate", player);
}

public RegenerationCooldown(player)
{
	player-=TASK_COOLDOWN
	
	if(!is_user_alive(player) || !zp_get_user_zombie(player) || zp_get_class(player) >= NEMESIS || zp_get_user_zombie_class(player) != zclass_regeneration)
		return;
	
	g_regen_times[player] = 0;
	
	client_print(player, print_center, "Recharge Complete!");
	ChatColor(player, "!g%s!y The recharge of your !gRegeneration!y abilities is complete!", PREFIX);
	
	set_task(0.5, "Regenerate", player);
}

stock ChatColor(const id, const input[], any:...)
{
	new count = 1, players[32];
	static msg[191];
	vformat(msg, 190, input, 3);
	
	replace_all(msg, 190, "!g", "^4"); // Green Color
	replace_all(msg, 190, "!y", "^1"); // Default Color
	replace_all(msg, 190, "!t", "^3"); // Team Color
	replace_all(msg, 190, "!w", "^0"); // Team2 Color
	
	if (id) players[0] = id; else get_players(players, count, "ch")
	{
		for (new i = 0; i < count; i++)
		{
			if (is_user_connected(players[i]))
			{
				message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i]);
				write_byte(players[i]);
				write_string(msg);
				message_end();
			}
		}
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1026\\ f0\\ fs16 \n\\ par }
*/
