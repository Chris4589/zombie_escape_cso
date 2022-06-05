#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <zombie_escape_v1>

new const hclass1_name[] = { "Paratropper" }
new const hclass1_info[] = { "Paracaidas con E" }
new const hclass1_model[] = { "ze_paratroper" }
const hclass1_health = 300
const hclass1_speed = 330
const Float:hclass1_gravity = 0.8
const Float:hclass1_knockback = 1.0

new const MODEL_PARACHUTE[] = "models/zombie_plague/parachute.mdl"

new g_has_parachute[33], g_para_ent[33];

new  g_cvar_fallspeed, g_cvar_detach, Float:g_FallSpeed, g_paratrooper

public plugin_init()
{
	register_plugin("Human Class Paratrooper", "1.0", "Randro")
	
	RegisterHam(Ham_Spawn, "player", "fwHamSpawnPlayer", 1)
	RegisterHam(Ham_Killed, "player", "fwHamKilledPlayer", 1)

	g_cvar_fallspeed =	register_cvar("zpnm_parachute_fallspeed", "60")
	g_cvar_detach =		register_cvar("zpnm_parachute_detach", "1")
}

public plugin_precache()
{
	precache_model(MODEL_PARACHUTE)
	g_paratrooper = zp_register_class(CLASS_HUMAN, hclass1_name, hclass1_info, hclass1_model, "default", 25,  0,ADMIN_ALL, hclass1_health, 40, hclass1_speed, hclass1_gravity, hclass1_knockback)
	
}

public plugin_cfg()
	set_task(1.57, "cache_settings")

public cache_settings()
{
	g_FallSpeed =	get_pcvar_float(g_cvar_fallspeed) * -1.0
	g_cvar_detach =	get_pcvar_num(g_cvar_detach)
}

public client_disconnect(id)
	parachute_reset(id, 1)

parachute_reset(id, remove = 0)
{
	if (g_para_ent[id] > 0 && is_valid_ent(g_para_ent[id]))
	{
		remove_entity(g_para_ent[id]);
		g_para_ent[id] = 0
	}
	
	if (!remove)
		g_has_parachute[id] = true
	else
		g_has_parachute[id] = false
}

public fwHamSpawnPlayer(id)
{

	if (!is_user_alive(id))
		return;
	if(zp_get_user_human_class(id) != g_paratrooper)
		return;
	if(zp_get_class(id) >= SURVIVOR)
	return;

	parachute_reset(id)
}

public zp_user_infected_post(id, infector, nemesis)
{
		parachute_reset(id, 1)
}

public zp_user_humanized_post(id, survivor)
{
	if(zp_get_user_human_class(id) != g_paratrooper)
	return;
	if(zp_get_class(id) >= SURVIVOR)
	{
	parachute_reset(id, 1)
	return;
	}
	parachute_reset(id)
}

public fwHamKilledPlayer(id)
	parachute_reset(id, 1)

public client_PreThink(id)
{
	//Parachute model animation information
	//0 - deploy - 84 frames
	//1 - idle - 39 frames
	//2 - detach - 29 frames
	
	if (!g_has_parachute[id])
		return;
	if(zp_get_user_human_class(id) != g_paratrooper)
		return;
	static flags, Float:frame, button, oldbutton
	button = get_user_button(id)
	oldbutton = get_user_oldbutton(id)
	flags = get_entity_flags(id)
	
	if (g_para_ent[id] > 0 && (flags & FL_ONGROUND))
	{
		if (g_cvar_detach)
		{
			if (entity_get_int(g_para_ent[id],EV_INT_sequence) != 2)
			{
				entity_set_int(g_para_ent[id], EV_INT_sequence, 2)
				entity_set_int(g_para_ent[id], EV_INT_gaitsequence, 1)
				entity_set_float(g_para_ent[id], EV_FL_frame, 0.0)
				entity_set_float(g_para_ent[id], EV_FL_fuser1, 0.0)
				entity_set_float(g_para_ent[id], EV_FL_animtime, 0.0)
				return;
			}
			
			frame = entity_get_float(g_para_ent[id],EV_FL_fuser1) + 2.0
			entity_set_float(g_para_ent[id],EV_FL_fuser1,frame)
			entity_set_float(g_para_ent[id],EV_FL_frame,frame)

			if (frame > 254.0)
				parachute_reset(id)
		}
		else
			parachute_reset(id)
		
		return;
	}
	
	if (button & IN_USE)
	{
		new Float:velocity[3];
		entity_get_vector(id, EV_VEC_velocity, velocity);
		
		if (velocity[2] < 0.0)
		{
			if(g_para_ent[id] <= 0)
			{
				g_para_ent[id] = create_entity("info_target")
				
				if(g_para_ent[id] > 0)
				{
					entity_set_string(g_para_ent[id],EV_SZ_classname,"parachute")
					entity_set_edict(g_para_ent[id], EV_ENT_aiment, id)
					entity_set_edict(g_para_ent[id], EV_ENT_owner, id)
					entity_set_int(g_para_ent[id], EV_INT_movetype, MOVETYPE_FOLLOW)
					entity_set_model(g_para_ent[id], MODEL_PARACHUTE)
					entity_set_int(g_para_ent[id], EV_INT_sequence, 0)
					entity_set_int(g_para_ent[id], EV_INT_gaitsequence, 1)
					entity_set_float(g_para_ent[id], EV_FL_frame, 0.0)
					entity_set_float(g_para_ent[id], EV_FL_fuser1, 0.0)
				}
			}
			else if (g_para_ent[id] > 0)
			{
				entity_set_int(id, EV_INT_sequence, 3)
				entity_set_int(id, EV_INT_gaitsequence, 1)
				entity_set_float(id, EV_FL_frame, 1.0)
				entity_set_float(id, EV_FL_framerate, 1.0)

				velocity[2] = (velocity[2] + 40.0 < g_FallSpeed) ? velocity[2] + 40.0 : g_FallSpeed
				entity_set_vector(id, EV_VEC_velocity, velocity)

				if (entity_get_int(g_para_ent[id],EV_INT_sequence) == 0)
				{

					frame = entity_get_float(g_para_ent[id],EV_FL_fuser1) + 1.0
					entity_set_float(g_para_ent[id],EV_FL_fuser1,frame)
					entity_set_float(g_para_ent[id],EV_FL_frame,frame)

					if (frame > 100.0)
					{
						entity_set_float(g_para_ent[id], EV_FL_animtime, 0.0)
						entity_set_float(g_para_ent[id], EV_FL_framerate, 0.4)
						entity_set_int(g_para_ent[id], EV_INT_sequence, 1)
						entity_set_int(g_para_ent[id], EV_INT_gaitsequence, 1)
						entity_set_float(g_para_ent[id], EV_FL_frame, 0.0)
						entity_set_float(g_para_ent[id], EV_FL_fuser1, 0.0)
					}
				}
			}
		}
		else if (g_para_ent[id] > 0)
			parachute_reset(id)
	}
	else if ((oldbutton & IN_USE) && g_para_ent[id] > 0)
		parachute_reset(id)
}
