#include <amxmodx>
#include <zombieplague>
#include <fakemeta>
#include <engine>
#include <fun>
#include <hamsandwich>

/*                      L4D2 Spitter Zombie
				by x[L]eoNNN & Hidanz300
	
	#Description :
	
		Este Zombie Esta Originalmente Creado Por : x[L]eoNNN , Solo Lo Edite Para Que Fuera Parecido Al ZM Spitter .. Y Esto Quiere Decir Que No Sea Nada Por
                            El Estilo "Pirateador" O Como Uds Quieran Llamarlo .. Saben Yo No Soy El Unico.
	
	#Cvars :
	
		zp_tank_rockspeed 700 // Rock Speed Launched by Tank
		zp_tank_rockdamage 25 // damage done by the rock
		zp_tank_rockreward 1 // Ammo Pack's Reward by touching the enemy with the rock
		zp_tank_rockmode 1 // Rock Mode :
					1 = Take Damage
					2 = Killing
					3 = Infect
					4 = Bad Aim
		zp_tank_rock_energynesesary 40 // energy nesesary to launch a rock

*/
new const zclass_name[] = { "Spitter" } 
new const zclass_info[] = { "Lanza Un Acido" } 
const zclass_health = 1111 
const zclass_speed = 240
const Float:zclass_gravity = 1.0 
const Float:zclass_knockback = 1.0  

new g_L4dTank

new g_trailSprite
new g_trail[] = "sprites/xbeam3.spr"
new rock_model[] = "models/spit.mdl"
new tank_rocklaunch[] = "zombie_plague/spitter_vomit1.wav"


new g_power[33]

new cvar_rock_damage, cvar_rock_reward, cvar_rockmode, cvar_rockEnergyNesesary, cvar_rock_speed

public plugin_init()
{
	register_plugin("[ZP] Zombie Class:  L4D2 Spitter Zombie", "1.0", "x[L]eoNNN & Hidanz300") 
 
	cvar_rock_speed = register_cvar("zp_tank_rockspeed", "700")
	cvar_rock_damage = register_cvar("zp_tank_rockdamage", "25")
	cvar_rock_reward = register_cvar("zp_tank_rockreward", "1")
	cvar_rockmode = register_cvar("zp_tank_rockmode", "1")
	cvar_rockEnergyNesesary = register_cvar("zp_tank_rock_energynesesary", "0")
	register_touch("rock_ent","*","RockTouch")
	register_forward(FM_CmdStart, "CmdStart" )
} 

public plugin_precache()
{
	g_L4dTank = zp_register_zombie_class(zclass_name, zclass_info, 14 , zclass_health, zclass_speed, zclass_gravity, zclass_knockback) 
	g_trailSprite = precache_model(g_trail)
	precache_model(rock_model)
	precache_sound(tank_rocklaunch)
}
	
public zp_user_infected_post ( id, infector )
{
             if (zp_get_user_zombie_class(id) == g_L4dTank)
             {
		print_chatColor(id, "\g[ZP]\n Ahora Eres El Zombie \gSpitter\n, Puedes Lanzar Acido Con Tu \t+use") 
		g_power[id] = get_pcvar_num(cvar_rockEnergyNesesary)
             }
}  

public CmdStart( const id, const uc_handle, random_seed )
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED;
	
	if(!zp_get_user_zombie(id) || zp_get_user_nemesis(id))
		return FMRES_IGNORED;
		
	new button = pev(id, pev_button)
	new oldbutton = pev(id, pev_oldbuttons)
	
	if (zp_get_user_zombie(id) && (zp_get_user_zombie_class(id) == g_L4dTank))
		if(oldbutton & IN_USE )
		{
			if(g_power[id] >= get_pcvar_num(cvar_rockEnergyNesesary))
			{
				MakeRock(id)
				emit_sound(id, CHAN_STREAM, tank_rocklaunch, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
			else
				print_chatColor(id, "\g[ZP]\n Necesitar Esperar \t[%d]\n || Llevas \t[%d]", get_pcvar_num(cvar_rockEnergyNesesary), g_power[id])
			
		}
			
	return FMRES_IGNORED
}

public power1(id)
{
	g_power[id] += 1
	
	if( g_power[id] > get_pcvar_num(cvar_rockEnergyNesesary) )
	{
		g_power[id] = get_pcvar_num(cvar_rockEnergyNesesary)
	}
}

public RockTouch( RockEnt, Touched )
{
	if ( !pev_valid ( RockEnt ) || !is_valid_ent(Touched) )
		return
		
	static Class[ 32 ]
	entity_get_string( Touched, EV_SZ_classname, Class, charsmax( Class ) )
	new Float:origin[3]
		
	pev(Touched,pev_origin,origin)
	
	if( equal( Class, "player" ) )
		if (is_user_alive(Touched))
		{
			if(!zp_get_user_zombie(Touched))
			{
				new TankKiller = entity_get_edict( RockEnt, EV_ENT_owner )
				
				switch(get_pcvar_num(cvar_rockmode))
				{
					case 1: // Health
					{
						new iHealth = get_user_health(Touched)

						if( iHealth >= 1 && iHealth <= get_pcvar_num(cvar_rock_damage))
						{
							ExecuteHamB( Ham_Killed, Touched, TankKiller, 0 )
							print_chatColor(TankKiller, "\g[ZP]\n Has Recivido \t%d\n Ammo Packs Por Lanzar Un Escupitajo A Un Humano", get_pcvar_num(cvar_rock_reward))
							zp_set_user_ammo_packs(TankKiller, zp_get_user_ammo_packs(TankKiller) + get_pcvar_num(cvar_rock_reward))
						}
						else
						{
							set_user_health(Touched, get_user_health(Touched) - get_pcvar_num(cvar_rock_damage))
							print_chatColor(TankKiller, "\g[ZP]\n Has Recivido \t%d\n Ammo Packs Por Lanzar Un Escupitajo A Un Humano", get_pcvar_num(cvar_rock_reward))
							zp_set_user_ammo_packs(TankKiller, zp_get_user_ammo_packs(TankKiller) + get_pcvar_num(cvar_rock_reward))
						}
					}
					case 2: // Kill
					{
						ExecuteHamB( Ham_Killed, Touched, TankKiller, 0 )
						zp_set_user_ammo_packs(TankKiller, zp_get_user_ammo_packs(TankKiller) + get_pcvar_num(cvar_rock_reward))
						print_chatColor(TankKiller, "\g[ZP]\n Has Recivido \t%d\n Ammo Packs Por Lanzar Un Escupitajo A Un Humano", get_pcvar_num(cvar_rock_reward))
					}
					case 3: //infect
					{
						zp_infect_user(Touched, TankKiller, 1, 1)
						print_chatColor(TankKiller, "\g[ZP]\n Has Recivido \t%d\n Ammo Packs Por Lanzar Un Escupitajo A Un Humano", get_pcvar_num(cvar_rock_reward))
						zp_set_user_ammo_packs(TankKiller, zp_get_user_ammo_packs(TankKiller) + get_pcvar_num(cvar_rock_reward))

					}
					case 4: //BadAim
					{
						new Float:vec[3] = {100.0,100.0,100.0}
						
						entity_set_vector(Touched,EV_VEC_punchangle,vec)  
						entity_set_vector(Touched,EV_VEC_punchangle,vec)
						entity_set_vector(Touched,EV_VEC_punchangle,vec) 
						
						print_chatColor(TankKiller, "\g[ZP]\n Has Recivido \t%d\n Ammo Packs Por Lanzar Un Escupitajo A Un Humano", get_pcvar_num(cvar_rock_reward))
						zp_set_user_ammo_packs(TankKiller, zp_get_user_ammo_packs(TankKiller) + get_pcvar_num(cvar_rock_reward))
						set_task(1.50, "EndVictimAim", Touched)
					}
				}
			}
		}
	remove_entity(RockEnt)
}

public EndVictimAim(Touched)
{
	new Float:vec[3] = {-100.0,-100.0,-100.0}
	entity_set_vector(Touched,EV_VEC_punchangle,vec)  
	entity_set_vector(Touched,EV_VEC_punchangle,vec)
	entity_set_vector(Touched,EV_VEC_punchangle,vec)
}

public MakeRock(id)
{
	g_power[id] = 0
	set_task(1.0, "power1", id, _, _, "b")
			
	new Float:Origin[3]
	new Float:Velocity[3]
	new Float:vAngle[3]

	new RockSpeed = get_pcvar_num(cvar_rock_speed)

	entity_get_vector(id, EV_VEC_origin , Origin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle)

	new NewEnt = create_entity("info_target")

	entity_set_string(NewEnt, EV_SZ_classname, "rock_ent")

	entity_set_model(NewEnt, rock_model)

	entity_set_size(NewEnt, Float:{-1.5, -1.5, -1.5}, Float:{1.5, 1.5, 1.5})

	entity_set_origin(NewEnt, Origin)
	entity_set_vector(NewEnt, EV_VEC_angles, vAngle)
	entity_set_int(NewEnt, EV_INT_solid, 2)

	entity_set_int(NewEnt, EV_INT_rendermode, 5)
	entity_set_float(NewEnt, EV_FL_renderamt, 200.0)
	entity_set_float(NewEnt, EV_FL_scale, 1.00)

	entity_set_int(NewEnt, EV_INT_movetype, 5)
	entity_set_edict(NewEnt, EV_ENT_owner, id)

	velocity_by_aim(id, RockSpeed  , Velocity)
	entity_set_vector(NewEnt, EV_VEC_velocity ,Velocity)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) 
	write_short(NewEnt) 
	write_short(g_trailSprite) 
	write_byte(10) 
	write_byte(10) 
	write_byte(0) 
	write_byte(250) 
	write_byte(0) 
	write_byte(200) 
	message_end()
	
	return PLUGIN_HANDLED
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
