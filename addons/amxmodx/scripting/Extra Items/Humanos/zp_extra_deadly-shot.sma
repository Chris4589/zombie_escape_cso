#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <zombie_escape_v1>

#define TASK_HUD 5345634
#define TASK_REMOVE 2423423

new bool:has_item[33]
new bool:using_item[33]

new sync_hud1
new cvar_deadlyshot_cost
new cvar_deadlyshot_time

new g_deadlyshot, human_deadly;

new const hclass1_name[] = { "Deadly Human" }
new const hclass1_info[] = { "Only HS con E" }
new const hclass1_model[] = { "cso_davidblack" }
const hclass1_health = 100
const hclass1_speed = 300
const Float:hclass1_gravity = 0.8
const Float:hclass1_knockback = 1.0
const Float:g_coulDown = 30.0;

new Float:g_fHab[33];

public plugin_init()
{
	register_plugin("[ZP] Extra Item: Deadly Shot (Human)", "1.0", "Dias")
	
	register_event("HLTV", "event_newround", "a", "1=0", "2=0")
	RegisterHam(Ham_TraceAttack, "player", "fw_traceattack")
	
	cvar_deadlyshot_cost = register_cvar("ds_cost", "300")
	cvar_deadlyshot_time = register_cvar("ds_time", "10.0")
	
	sync_hud1 = CreateHudSyncObj(random_num(1, 10))
	g_deadlyshot = zp_register_extra_item("Deadly Shot", get_pcvar_num(cvar_deadlyshot_cost), 0, ZP_TEAM_HUMAN)
}
public plugin_precache()
{
	human_deadly = zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 13, 0, ADMIN_BAN, hclass1_health, 100, hclass1_speed, hclass1_gravity, hclass1_knockback)
}

public event_newround(id)
{
	if(zp_get_user_human_class(id) != human_deadly)
		remove_ds(id)
}

public zp_user_humanized_post(id)
{
	remove_ds(id);
	
	if(zp_get_user_human_class(id) != human_deadly)
		return;

	if(zp_get_class(id) < SURVIVOR)
	{
		g_fHab[id] = 0.0;
		has_item[id] = true
		using_item[id] = false

		set_task(0.1, "show_hud", id+TASK_HUD, _, _, "b");
	}
}

public zp_extra_item_selected(id, itemid)
{
	if(itemid != g_deadlyshot)
		return PLUGIN_HANDLED
		
	if(!has_item[id] || using_item[id])
	{
		client_print(id, print_chat, "[ZP] You bought Deadly Shot !!!")
		
		has_item[id] = true
		using_item[id] = false
		
		set_task(0.1, "show_hud", id+TASK_HUD, _, _, "b")
	} else {
		client_print(id, print_chat, "[ZP] You can't buy Deadly Shot at this time...")
		zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + get_pcvar_num(cvar_deadlyshot_cost))
	}
	
	return PLUGIN_CONTINUE
}

public zp_user_infected_post(id)
{
	remove_ds(id);
}

public show_hud(id)
{
	id -= TASK_HUD;

	set_hudmessage(0, 255, 0, -1.0, 0.88, 0, 2.0, 1.0)	;
	
	if(has_item[id])
	{
		if(zp_get_user_human_class(id) == human_deadly)
			ShowSyncHudMsg(id, sync_hud1, "[E] -> Active Deadly Shot in %f", g_fHab[id] > get_gametime() ? g_fHab[id] - get_gametime() : 0.0);
		else
			ShowSyncHudMsg(id, sync_hud1, "[E] -> Active Deadly Shot");
	} else if(using_item[id]) {
		ShowSyncHudMsg(id, sync_hud1, "Deadly Shot - Actived");	
	} else {
		set_hudmessage(0, 255, 0, -1.0, 0.88, 0, 2.0, 5.0);
		ShowSyncHudMsg(id, sync_hud1, "Deadly Shot - Disable");
		if(task_exists(id+TASK_HUD)) remove_task(id+TASK_HUD);
	}
}

public client_PostThink(id)
{
	if(!is_user_alive(id) || zp_get_class(id) >= SURVIVOR)
		return;

	static Button;
	Button = get_user_button(id);
	
	if(Button & IN_USE)
	{
		if(has_item[id] && !using_item[id])
		{
			has_item[id] = false;
			using_item[id] = true;
			
			set_task(get_pcvar_float(cvar_deadlyshot_time), "remove_headshot_mode", id+TASK_REMOVE);
		}
		if(g_fHab[id] < get_gametime() && zp_get_user_human_class(id) == human_deadly)
		{
			g_fHab[id] = get_gametime() + g_coulDown;
			has_item[id] = false;
			using_item[id] = true;
			
			set_task(get_pcvar_float(cvar_deadlyshot_time), "remove_headshot_mode", id+TASK_REMOVE);
		}
	}
}

public fw_traceattack(victim, attacker, Float:damage, direction[3], traceresult, dmgbits)
{
	if(!is_user_alive(attacker) || zp_get_class(attacker) >= SURVIVOR)
		return;
	if(using_item[attacker])
	{
		set_tr2(traceresult, TR_iHitgroup, HIT_HEAD);
	}
}

public remove_ds(id)
{
	if(has_item[id] || using_item[id])
	{
		has_item[id] = false
		using_item[id] = false		
		
		if(task_exists(id+TASK_HUD)) remove_task(id+TASK_HUD)
		if(task_exists(id+TASK_REMOVE)) remove_task(id+TASK_REMOVE)
	}	
}

public remove_headshot_mode(id)
{
	id -= TASK_REMOVE
	
	has_item[id] = false
	using_item[id] = false
	
	if(task_exists(id+TASK_HUD)) remove_task(id+TASK_HUD)
}
