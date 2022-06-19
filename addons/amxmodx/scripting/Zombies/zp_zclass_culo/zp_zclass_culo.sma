/*================================================
Name: Quark Zombie
Description: Can Make a Trap. And Trap the Human.
Author: Dias
For: Zombie Plague Mod 4.3
================================================*/

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <fun>
#include <hamsandwich>
#include <zombie_escape_v1>
#include <xs>
#include <cstrike>

new const zclass_name[] = "Quark Zombie"
new const zclass_info[] = "(G) To Put a Trap"
new const zclass_model[] = "zombie_classic1"
new const zclass_clawmodel[] = "v_knife_cosspeed1.mdl"
const zclass_health = 2000
const zclass_speed = 250
const Float:zclass_gravity = 1.0
const Float:zclass_knockback = 1.0

const Float:NORMAL_SPEED = 80.0 // Velocidad normal
const Float:PURSUIT_SPEED = 220.0 // Velocidad de persecucion
const Float:VIDA = 10.0 // Demasiada vida = cucarachas mutantes (?
const Float:SALTO = 100.0 // Maxima altura que puede saltar una cucaracha.
const Float:RADIO = 500.0 // Radio de vision de la cucaracha
const CANTIDAD_BLOOD = 4 // Cantidad de 'sangre' (?
const Float:TRACE_DIST = 5.0 // Distancia maxima entre la cucaracha y una pared para cambiar de direccion

new g_repel[33];

new Ham:Ham_Player_ResetMaxSpeed = Ham_Item_PreFrame
// Main Trap Vars
new g_zquark
new bool:can_make_trap[33]
new bool:player_trapped[33]

new const trap_string[] = "trampa_culo"
new const trap_model[] = "models/zombie_plague/zombie_trap.mdl"

new cvar_cooldown
new cvar_trap_hp
new cvar_trap_time

new g_maxplayers
public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Quark", "1.2", "Dias")
	register_clcmd("drop", "use_skill")
	register_logevent("event_roundend", 2, "1=Round_End")
	register_touch(trap_string, "*", "fw_touch")
	register_think( trap_string, "Culo_think" );
	register_forward(FM_PlayerPreThink, "fw_think", 0);
	RegisterHam(Ham_Killed, "player", "fw_player_killed")

	g_maxplayers = get_maxplayers()

	cvar_register()
}

public cvar_register()
{
	cvar_cooldown = register_cvar("qz_cooldown", "3")
	cvar_trap_time = register_cvar("qz_trap_time", "25")
	cvar_trap_hp = register_cvar("qz_trap_hp", "2500")
}

public plugin_precache()
{
	g_zquark = 	zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 0, 0, ADMIN_ALL, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)
	precache_model(trap_model)
}

public fw_player_killed(victim, attacker, shouldgib)
{
	remove_trap(victim)
}

public event_roundend(id)
{
	can_make_trap[id] = false
	player_trapped[id] = false
	
	remove_entity_name(trap_string)

	for(new id = 1; id <= g_maxplayers; id++)
	{
		if(is_user_connected(id))
			remove_trap(id)
	}

}

public zp_user_infected_post(victim, attacker)
{
	if(zp_get_user_zombie_class(victim) == g_zquark && zp_get_class(victim) < NEMESIS)
	{
		client_print(victim, print_chat, "[Quark Zombie] Press (G) to Put a Trap !!!")
		can_make_trap[victim] = true
	}
	if(player_trapped[victim] == true)
	{
		player_trapped[victim] = false
		remove_entity_name(trap_string)
		remove_task(victim)
	}
}

public use_skill(id)
{
	if(is_user_alive(id) && zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_zquark && zp_get_class(id) < NEMESIS)
	{
		if(can_make_trap[id])
		{
			create_trap(id)
			} else {
			client_print(id, print_chat, "[Quark Zombie] You can't put the trap Now. Please Wait For %i", get_pcvar_num(cvar_cooldown))
		}
	}
}

public create_trap(id)
{

	new Float:Origin[3]
	entity_get_vector(id, EV_VEC_origin, Origin)
	
	Origin[2] += 35.0
	
	new trap = create_entity("info_target")
	entity_set_vector(trap, EV_VEC_origin, Origin)
	//Origin[2] += 70.0
	//entity_set_vector(id, EV_VEC_origin, Origin)
	
	entity_set_float(trap, EV_FL_takedamage, 1.0)
	entity_set_float(trap, EV_FL_health, get_pcvar_float(cvar_trap_hp))
	entity_set_float(trap, EV_FL_gravity, 0.6);
	entity_set_float(trap, EV_FL_friction, 0.8);
	
	entity_set_string(trap, EV_SZ_classname, trap_string)
	entity_set_model(trap, trap_model)	
	//entity_set_int(trap, EV_INT_solid, 1)
	entity_set_int(trap, EV_INT_movetype, MOVETYPE_BOUNCE);
	entity_set_int(trap, EV_INT_solid, SOLID_TRIGGER);
	
	entity_set_byte(trap,EV_BYTE_controller1,125);
	entity_set_byte(trap,EV_BYTE_controller2,125);
	entity_set_byte(trap,EV_BYTE_controller3,125);
	entity_set_byte(trap,EV_BYTE_controller4,125);
	
	new Float:size_max[3] = {5.0,5.0,5.0}
	new Float:size_min[3] = {-5.0,-5.0,-5.0}
	entity_set_size(trap, size_min, size_max)
	
	entity_set_float(trap, EV_FL_animtime, 2.0)
	entity_set_float(trap, EV_FL_framerate, 1.0)
	entity_set_int(trap, EV_INT_sequence, 0)

	entity_set_float(trap, EV_FL_nextthink, halflife_time() + 0.1)
	
	drop_to_floor(trap)
	
	can_make_trap[id] = false
	set_task(get_pcvar_float(cvar_cooldown), "reset_cooldown", id)

}

public reset_cooldown(id)
{
	if(is_user_alive(id) && zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_zquark && zp_get_class(id) < NEMESIS)
	{
		if(can_make_trap[id] == false)
		{
			can_make_trap[id] = true
			client_print(id, print_chat, "[Quark Zombie] Now you can use your ability. Press (G)")
		}
	}	
}

public fw_touch(trap, id)
{
	if(!pev_valid(trap))
		return	
	
	if(is_user_alive(id) && !zp_get_user_zombie(id))
	{

		new ent = find_ent_by_class(0, trap_string)
		entity_set_int(ent, EV_INT_sequence, 1)
		player_trapped[id] = true
		set_task(get_pcvar_float(cvar_trap_time), "remove_trap", id)
	}
}

public remove_trap(id)
{
	if(is_user_connected(id))
		ExecuteHamB(Ham_Player_ResetMaxSpeed, id)

	player_trapped[id] = false
	
	new ent = find_ent_by_class(0, trap_string)
	
	if(is_valid_ent(ent))
		remove_entity(ent)

	remove_task(id)

}

public spawn_post(id)
{
    if(is_user_alive(id))
    {
         player_trapped[id] = false
         
    }
}  

public fw_think(id)
{
	if(is_user_alive(id) && player_trapped[id] == true)
	{
		set_pev(id, pev_velocity, Float:{0.0,0.0,0.0}) // stop motion
		set_pev(id, pev_maxspeed, 1.0) 
	}
}

public Culo_think(ent)
{
	if (!is_valid_ent(ent))
		return PLUGIN_CONTINUE;
	
	static Float:velocity[3], Float:origin[3], Float:originT[3], Float:angles[3], Float:Stoped[3] = {0.0, 0.0, 0.0};
	static Float:spd, Float:fraction, trace;
	static victim, lastjump;
	entity_get_vector(ent, EV_VEC_origin, origin);
	lastjump = entity_get_int(ent, EV_INT_iuser1);
	
	// Recordando un poco de fisica
	// Vf^2 = Vo^2 + 2.a.d
	// En un salto, velocidad final = 0
	// Despejando: Vo = raiz(2.a.d)
	// La aceleracion del cs es 800, como el gravity de las cucas es 0.6
	// 800 * 2 * 0.6 = 960
	// Le puse 1000 para asegurarme que la cuca salte un poco mas de lo debido
	const Float:JUMP_CONST = 1000.0;
	
	if (lastjump > 0)
		entity_set_int(ent, EV_INT_iuser1, --lastjump);
	
	//if (g_canattack)
	//{
	if ((victim = entity_get_int(ent, EV_INT_iuser2)) == -1)
	{
		victim = get_closest_player(ent);
	}
	else
	{
		entity_set_int(ent, EV_INT_iuser2, --victim);
		victim = 0;
	}
	//}
	//else victim = 0;
	
	if (!(1 <= victim <= 32))
	{
 

		if(player_trapped[victim])
		{
			entity_set_vector(ent, EV_VEC_velocity, Stoped)
		}
		else
		entity_get_vector(ent, EV_VEC_velocity, velocity);


		
		//angle_vector(velocity, ANGLEVECTOR_FORWARD, angles);
		xs_vec_normalize(velocity, angles);
		angles[2] = 0.0;
		xs_vec_mul_scalar(angles, TRACE_DIST, angles);
		
		xs_vec_add(origin, angles, originT);
		//origin[0] = origin[0] - (3.0 * origin[0] / lenght);
		//origin[1] = origin[1] - (3.0 * origin[1] / lenght);
		
		engfunc(EngFunc_TraceLine, origin, originT, DONT_IGNORE_MONSTERS, ent, trace);
		
		get_tr2(trace, TR_flFraction, fraction);
		
		if (fraction == 1.0)
		{
			spd = random_float(0.0, NORMAL_SPEED/4.0);
			velocity[0] = velocity[0] + random_float(-NORMAL_SPEED/4.0, NORMAL_SPEED/4.0);
			velocity[1] = velocity[1] > 0.0 ? floatsqroot(NORMAL_SPEED*NORMAL_SPEED - spd*spd) : 0.0 - floatsqroot(NORMAL_SPEED*NORMAL_SPEED - spd*spd);
			
			//velocity[2] = random(25) ? 0.0 : SALTO;
			
			entity_set_vector(ent, EV_VEC_velocity, velocity);
			
			vector_to_angle(velocity, velocity);
			entity_set_vector(ent, EV_VEC_angles, velocity);
		}
		else
		{
			roach_random_move(ent, velocity);
		}
	}
	else
	{
		entity_get_vector(victim, EV_VEC_origin, originT);
		entity_get_vector(ent, EV_VEC_velocity, velocity);
		
		//origin[0] = origin[0] - (2.0 * origin[0] / lenght);
		//origin[1] = origin[1] - (2.0 * origin[1] / lenght);
		//origin[2] = origin[2] - 1.0;
		
		engfunc(EngFunc_TraceLine, origin, originT, IGNORE_MONSTERS, ent, trace);
	
		get_tr2(trace, TR_flFraction, fraction);
		
		static Float:backup;
		
		if (fraction == 1.0)
		{
			backup = velocity[2];
			
			xs_vec_sub(originT, origin, velocity);
			vector_to_angle(velocity, velocity);
			
			entity_set_vector(ent, EV_VEC_angles, velocity);
			
			angle_vector(velocity, ANGLEVECTOR_FORWARD, velocity);
			xs_vec_normalize(velocity, velocity);
			xs_vec_mul_scalar(velocity, PURSUIT_SPEED, velocity);
			
			if (!lastjump && get_distance_f(origin, originT) < 50.0 && originT[2] > origin[2] && !player_trapped[victim])
			{
				velocity[2] = floatsqroot(JUMP_CONST*floatmin(SALTO, (originT[2]-origin[2])));
				entity_set_int(ent, EV_INT_iuser1, 10);
			}
			else
				velocity[2] = backup;
			
			entity_set_vector(ent, EV_VEC_velocity, velocity);
		}
		else
		{
			if (originT[2] > origin[2])
			{
				backup = origin[2];
				origin[2] = originT[2];
				
				engfunc(EngFunc_TraceLine, origin, originT, IGNORE_MONSTERS, ent, trace);
				get_tr2(trace, TR_flFraction, fraction);
				
				if (fraction == 1.0)
				{
					origin[2] = backup;
					backup = velocity[2];
					
					xs_vec_sub(originT, origin, velocity);
					
					vector_to_angle(velocity, velocity);
					entity_set_vector(ent, EV_VEC_angles, velocity);
					
					angle_vector(velocity, ANGLEVECTOR_FORWARD, velocity);
					xs_vec_normalize(velocity, velocity);
					xs_vec_mul_scalar(velocity, PURSUIT_SPEED, velocity);
					
					if (!lastjump)
					{
						velocity[2] = floatsqroot(JUMP_CONST*floatmin(SALTO, (originT[2]-origin[2])));
						entity_set_int(ent, EV_INT_iuser1, 10);
					}
					else
						velocity[2] = backup;
					
					entity_set_vector(ent, EV_VEC_velocity, velocity);
				}
				else
				{
					origin[2] = backup + SALTO;
					backup = originT[2];
					originT[2] = origin[2];
					
					engfunc(EngFunc_TraceLine, origin, originT, IGNORE_MONSTERS, ent, trace);
					get_tr2(trace, TR_flFraction, fraction);
					
					if (fraction == 1.0)
					{
						originT[2] = backup;
						backup = velocity[2];
						
						xs_vec_sub(originT, origin, velocity);
						
						vector_to_angle(velocity, velocity);
						entity_set_vector(ent, EV_VEC_angles, velocity);
						
						angle_vector(velocity, ANGLEVECTOR_FORWARD, velocity);
						xs_vec_normalize(velocity, velocity);
						xs_vec_mul_scalar(velocity, PURSUIT_SPEED, velocity);
						
						if (!lastjump)
						{
							velocity[2] = floatsqroot(JUMP_CONST*SALTO);
							entity_set_int(ent, EV_INT_iuser1, 10);
						}
						else
							velocity[2] = backup;
						
						entity_set_vector(ent, EV_VEC_velocity, velocity);
					}
					else
					{
						roach_random_move(ent, velocity);
					}
				}
			}
			else
			{
				backup = originT[2];
				originT[2] = origin[2];
				
				engfunc(EngFunc_TraceLine, origin, originT, IGNORE_MONSTERS, ent, trace);
				get_tr2(trace, TR_flFraction, fraction);
				
				if (fraction == 1.0)
				{
					originT[2] = backup;
					backup = velocity[2];
					
					xs_vec_sub(originT, origin, velocity);
					
					vector_to_angle(velocity, velocity);
					entity_set_vector(ent, EV_VEC_angles, velocity);
					
					angle_vector(velocity, ANGLEVECTOR_FORWARD, velocity);
					xs_vec_normalize(velocity, velocity);
					xs_vec_mul_scalar(velocity, PURSUIT_SPEED, velocity);
					
					velocity[2] = backup;
					
					entity_set_vector(ent, EV_VEC_velocity, velocity);
				}
				else
				{
					roach_random_move(ent, velocity);
				}
			}
		}
	}
	
	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.2);
	
	return PLUGIN_CONTINUE;
}


roach_random_move(ent, Float:velocity[3])
{
	static Float:spd;
	spd = random_float(0.0, NORMAL_SPEED);
	velocity[0] = random_num(0, 1) ? spd : -spd; // Por alguna razon, random() sale casi siempre 0, es mejor random_num
	velocity[1] = random_num(0, 1) ? floatsqroot(NORMAL_SPEED*NORMAL_SPEED - spd*spd) : 0.0 - floatsqroot(NORMAL_SPEED*NORMAL_SPEED - spd*spd);
	//velocity[2] = random(25) ? 0.0 : SALTO;
				
	entity_set_vector(ent, EV_VEC_velocity, velocity);
		
	vector_to_angle(velocity, velocity);
	entity_set_vector(ent, EV_VEC_angles, velocity);
}
/*
bool:is_hull_vacant(Float:origin[3], hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0);
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}*/

get_closest_player( iEntity )
{
    // iEntity = entity you are finding players closest to
    
    new iPlayers[ 32 ], iNum;
    get_players( iPlayers, iNum, "a" );
    
    new iClosestPlayer = 0;
    new iPlayer, Float:flDist, Float:flClosestDist = RADIO;
    
    for( new i = 0; i < iNum; i++ )
    {
        iPlayer = iPlayers[ i ];

        if (g_repel[iPlayer] || zp_get_user_zombie(iPlayer))
                continue;
	
        flDist = entity_range( iPlayer, iEntity );
        
        if( flDist <= flClosestDist )
        {
            iClosestPlayer = iPlayer;
            flClosestDist = flDist;
        }
    }
    
    return iClosestPlayer;
}