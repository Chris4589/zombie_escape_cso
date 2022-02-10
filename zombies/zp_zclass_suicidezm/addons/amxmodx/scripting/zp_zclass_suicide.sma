#include <amxmodx>
#include <zombieplague>
#include <fakemeta>
#include <hamsandwich>
#include <fun>

#define TASK_BARTIME 5000

new const zclass_name[] = { "Suicide Zombie" } 
new const zclass_info[] = { "Cant Explode Killing Humans" } 
new const zclass4_model[] = { "zombie_source" }
const zclass_health = 800 
const zclass_speed = 200 
const Float:zclass_gravity = 0.6 
const Float:zclass_knockback = 0.6 

new const EXPLO_SPRITE[] = "sprites/zerogxplode.spr"

new g_SuicideZ, g_msgBarTime, cvar_explotime, cvar_respawn, cvar_respawntime, cvar_explobody,
g_ExpSpr, cvar_radius, cvar_reward, cvar_enablereward, cvar_rewarddmg, cvar_survivordmg;

public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Suicide Zombie", "1.1", "xLeoNNN") 
        
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
    
	register_forward(FM_CmdStart, "CmdStart" )
    
	cvar_respawn = register_cvar("zp_suicide_respawn", "0")
	cvar_respawntime = register_cvar("zp_suicide_respawn_time", "60.0")
	cvar_radius = register_cvar("zp_suicide_radius", "50.0")
	cvar_explobody = register_cvar("zp_suicide_explobody", "1")
	cvar_explotime = register_cvar("zp_suicide_explotime", "3")
	g_msgBarTime = get_user_msgid("BarTime")
	cvar_survivordmg = register_cvar("zp_suicide_survdamage", "15")
	cvar_reward = register_cvar("zp_suicide_reward", "3")
	cvar_rewarddmg = register_cvar("zp_suicide_rewarddmg", "1")
	cvar_enablereward = register_cvar("zp_suicide_reward_enable", "1")
}  

public plugin_precache()
{
	g_SuicideZ = zp_register_zombie_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass4_model, 23, zclass_health, zclass_speed, zclass_gravity, zclass_knockback) 
	g_ExpSpr = precache_model(EXPLO_SPRITE)
}

public remove_bartime(id)
{
	message_begin(MSG_ONE, g_msgBarTime, _, id)
	write_byte(0) 
	write_byte(0) 
	message_end()
	remove_task(id+TASK_BARTIME)
}

public zp_user_infected_post ( id, infector )
	if (zp_get_user_zombie_class(id) == g_SuicideZ)
		print_chatColor(id, "\g[ZP]\n Вы выбрали класс \gSuicide\n! Нажмите \g[E]\n что взорваться!") 

public CmdStart(id)
{
	static button, oldbutton
	button = pev(id, pev_button)
	oldbutton = pev(id, pev_oldbuttons)
    
	if(is_user_alive(id))
		if (zp_get_user_zombie(id) && (zp_get_user_zombie_class(id) == g_SuicideZ))
		{
			if(button & IN_USE)
			{
				message_begin(MSG_ONE, g_msgBarTime, _, id)
				write_byte(get_pcvar_num(cvar_explotime))
				write_byte(0) 
				message_end()
                
				set_task(get_pcvar_float(cvar_explotime), "Explo", id+TASK_BARTIME)
			}
            
			if(oldbutton & IN_USE && !(button & IN_USE))
				set_task(0.1, "remove_bartime", id)
		}
            
	return PLUGIN_HANDLED
}

public client_disconnect(id) set_task(0.1, "remove_bartime", id)

public Explo(id)
{
	id -= TASK_BARTIME
    
	new Float:origin[3]
	pev(id, pev_origin, origin)
    
	/*message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_short(g_ExpSpr)
	write_byte(10) 
	write_byte(15) 
	write_byte(0)
	message_end()*/
    
	user_silentkill(id)
	if(get_pcvar_num(cvar_respawn) == 1)
		set_task(get_pcvar_float(cvar_respawntime), "respawn", id)
        
	static victim
	victim = -1
    
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, origin, get_pcvar_float(cvar_radius))) != 0)
		if (is_user_alive(victim) && !zp_get_user_zombie(victim))
		{
			if(get_pcvar_num(cvar_enablereward))
			{
				if (zp_get_user_survivor(victim))
				{
					print_chatColor(id, "\g[ZP]\n Вы получили \t%d\n пак., за нанесённый урон врагу!", get_pcvar_num(cvar_rewarddmg))
					zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + get_pcvar_num(cvar_rewarddmg))
				}
				else
				{
					print_chatColor(id, "\g[ZP]\n Вы получаете \t%d\n пак., за убийство врага!", get_pcvar_num(cvar_reward))
					zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + get_pcvar_num(cvar_reward))
				}
			}
            
			new health = get_user_health(victim)
				
			if (health > get_pcvar_num(cvar_survivordmg))
				set_user_health(victim, health-get_pcvar_num(cvar_survivordmg))
			else
				log_kill(id, victim, "Suicide Zombie", 0)
			


		}
}	

public respawn(id)
{
	if(!is_user_alive(id))
	{
		ExecuteHamB(Ham_CS_RoundRespawn, id)
		zp_infect_user(id, 0, 0, 0)
	}
}

stock log_kill(killer, victim, weapon[],headshot) 
{
	user_silentkill( victim );
    
	message_begin( MSG_ALL, get_user_msgid( "DeathMsg" ), {0,0,0}, 0 );
	write_byte( killer );
	write_byte( victim );
	write_byte( headshot );
	write_string( weapon );
	message_end();
    
	new kfrags = get_user_frags( killer );
	set_user_frags( killer, kfrags + 1 );
	new vfrags = get_user_frags( victim );
	set_user_frags( victim, vfrags - 1 );
    
	return  PLUGIN_CONTINUE
}  

stock print_chatColor(const id,const input[], any:...)
{
	new msg[191], players[32], count = 1;
	vformat(msg,190,input,3);
	replace_all(msg,190,"\g","^4");// green
	replace_all(msg,190,"\n","^1");// normal
	replace_all(msg,190,"\t","^3");// team
    
	if (id) players[0] = id; else get_players(players,count,"ch");
	for (new i=0;i<count;i++)
	if (is_user_connected(players[i]))
	{
		message_begin(MSG_ONE_UNRELIABLE,get_user_msgid("SayText"),_,players[i]);
		write_byte(players[i]);
		write_string(msg);
		message_end();
	}
} 

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	if(zp_get_user_zombie_class(victim) == g_SuicideZ)
	{
		if(get_pcvar_num(cvar_explobody))
		SetHamParamInteger(3, 2)

		set_task(0.10, "remove_bartime", victim)
	}
}
        
public fw_PlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return;
    
	set_task(0.10, "remove_bartime", id)
}  
