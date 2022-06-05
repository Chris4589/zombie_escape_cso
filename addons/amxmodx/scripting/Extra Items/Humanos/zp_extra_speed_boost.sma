/*================================================================================
	
	----------------------------------------
	-*- [ZP] Extra Item: Speed Boost 1.2 -*-
	----------------------------------------
	
	~~~~~~~~~~~~~~~
	- Description -
	~~~~~~~~~~~~~~~
	
	This item gives humans/zombies a short speed boost, configurable
	by cvars: zp_boost_amount and zp_boost_duration.
	
	ZP 4.3 Fix 5 or later required.
	
	~~~~~~~~~~~~~
	- Changelog -
	~~~~~~~~~~~~~
	
	* v1.0: (Jun 21, 2011)
	   - First release
	
	* v1.1: (Jun 22, 2011)
	   - Fixed speed not properly restored if player gets frozen after
	      buying the speed boost (high zp_frost_duration settings)
	
	* v1.2: (Jul 02, 2011)
	   - Changed speed setting method to be compatible with ZP 4.3 Fix5
	
================================================================================*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <zombie_escape_v1>

const TASK_SPEED_BOOST = 100
#define ID_SPEED_BOOST (taskid - TASK_SPEED_BOOST)

// Hack to be able to use Ham_Player_ResetMaxSpeed (by joaquimandrade)
new Ham:Ham_Player_ResetMaxSpeed = Ham_Item_PreFrame

new g_itemid_boost
new cvar_boost_amount
new cvar_boost_duration
new g_has_speed_boost[33]

public plugin_init()
{
	register_plugin("[ZP] Extra Item Speed Boost", "1.2", "MeRcyLeZZ")
	
	g_itemid_boost = zp_register_extra_item("Speed Boost", 5, 0, ZP_TEAM_HUMAN | ZP_TEAM_ZOMBIE)
	cvar_boost_amount = register_cvar("zp_boost_amount", "100.0")
	cvar_boost_duration = register_cvar("zp_boost_duration", "10.0")
	
	RegisterHam(Ham_Player_ResetMaxSpeed, "player", "fw_ResetMaxSpeed_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_itemid_boost)
	{
		// Player frozen (or CS freezetime)
		if (pev(player, pev_maxspeed) <= 1)
		{
			client_print(player, print_chat, "[ZP] You can't use this item when frozen.")
			return ZP_PLUGIN_HANDLED;
		}
		
		// Already using speed boost
		if (g_has_speed_boost[player])
		{
			client_print(player, print_chat, "[ZP] You already have the speed boost.")
			return ZP_PLUGIN_HANDLED;
		}
		
		// Enable speed boost
		g_has_speed_boost[player] = true
		client_print(player, print_chat, "[ZP] Speed boost enabled!")
		
		// Set the restore speed task
		set_task(get_pcvar_float(cvar_boost_duration), "restore_maxspeed", player+TASK_SPEED_BOOST)
		
		// Update player's maxspeed
		ExecuteHamB(Ham_Player_ResetMaxSpeed, player)
	}
	return PLUGIN_CONTINUE;
}

public restore_maxspeed(taskid)
{
	if(!is_user_alive(ID_SPEED_BOOST))
		return;
	// Disable speed boost
	g_has_speed_boost[ID_SPEED_BOOST] = false
	client_print(ID_SPEED_BOOST, print_chat, "[ZP] Speed boost is over.")
	
	// Update player's maxspeed
	ExecuteHamB(Ham_Player_ResetMaxSpeed, ID_SPEED_BOOST)
}

// Remove speed boost task when infected, humanized, killed, or disconnected
public zp_user_infected_pre(id, infector, nemesis)
{
	g_has_speed_boost[id] = false
	remove_task(id+TASK_SPEED_BOOST)
}
public zp_user_humanized_pre(id, survivor)
{
	g_has_speed_boost[id] = false
	remove_task(id+TASK_SPEED_BOOST)
}
public fw_PlayerKilled(victim)
{
	g_has_speed_boost[victim] = false
	remove_task(victim+TASK_SPEED_BOOST)
}
public client_disconnect(id)
{
	g_has_speed_boost[id] = false
	remove_task(id+TASK_SPEED_BOOST)
}

// Remove speed boost at round start
public event_round_start()
{
	new id
	for (id = 1; id <= get_maxplayers(); id++)
	{
		g_has_speed_boost[id] = false
		remove_task(id+TASK_SPEED_BOOST)
	}
}

public fw_ResetMaxSpeed_Post(id)
{
	if (!is_user_alive(id) || !g_has_speed_boost[id])
		return;
	
	// Apply speed boost
	new Float:current_maxspeed
	pev(id, pev_maxspeed, current_maxspeed)
	set_pev(id, pev_maxspeed, current_maxspeed + get_pcvar_float(cvar_boost_amount))
}