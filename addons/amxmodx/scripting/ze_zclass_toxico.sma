#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <fun>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN_NAME	"[ZP] ZCLASS = L4D spitter"
#define PLUGIN_VERSION	"1.5"
#define PLUGIN_AUTHOR	"snaker-beatter"

#define SPIT_CHEAT_BLOCK	// Disallow some cheatty trick
#define BETTER_COOLDOWN		// Than the old buggy cooldown this works more better

#if defined BETTER_COOLDOWN
	new Float:g_LastSpitTime[33]
	new cvar_spit_cooldown
#endif
/*
new const zclass_name[] = { "Toxico" } 
new const zclass_info[] = { "Lanzar Acido \r[R]" } 
new const zclass_model[] = { "dlc_toxico_warz" } 
new const zclass_clawmodel[] = { "dlc_toxico_warz/v_toxico_warz.mdl" } 
const zclass_health = 2500
const zclass_speed = 267
const Float:zclass_gravity = 0.8 
const Float:zclass_knockback = 0.8  */

//new g_L4dSpitter

new g_trailSprite
new const g_trail[] = "sprites/xbeam3.spr"
new const spit_model[] = "models/spit.mdl" // HAlF-Life model
new const bubble_model_const[] = "sprites/bubble.spr"
//new const Spitter_spitlaunch[] = "zombie_plague/zm_spells_warz/toxico_vomit.wav"
new const Spitter_spithit[] = "bullchicken/bc_spithit2.wav" // HAlF-Life model

//new const Spitter_dieacid_start[] = "bullchicken/bc_acid1.wav"
new const g_ringspr[] = "sprites/shockwave.spr"
new g_ring, bubble_model

new cvar_spit_damage, cvar_spitmode, cvar_spit_speed
new cvar_dthacid_damage, cvar_dthacid_distance

/******************************************************
		[Main event]
******************************************************/

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR) 
	register_event("DeathMsg", "spitter_death", "a")

	cvar_spit_speed = register_cvar("zp_Spitter_spit_speed", "700")
	cvar_spit_damage = register_cvar("zp_Spitter_spit_damage", "500")
	cvar_spitmode = register_cvar("zp_Spitter_spit_mode", "1")
	
#if defined BETTER_COOLDOWN
	cvar_spit_cooldown = register_cvar("zp_Spitter_spit_cooldown", "2.0")
#endif

	cvar_dthacid_damage = register_cvar("zp_Spitter_death_acid_damage", "100")
	cvar_dthacid_distance = register_cvar("zp_Spitter_death_acid_distance", "50")
	
	register_clcmd("spitter_spit", "clcmd_spit")
	register_touch("spit_ent","*","spitTouch")
	register_forward(FM_PlayerPreThink, "CmdStart")
	register_event("HLTV", "event_roundStart", "a", "1=0", "2=0");
} 
public event_roundStart( )
{
	new ent = -1;
	while((ent = find_ent_by_class(ent, "spit_ent")))
	{
		if (pev_valid(ent))
		{
			remove_entity(ent)
		}
	}
}
/****************************************************
		[Events]
****************************************************/

public plugin_precache()
{
	//g_L4dSpitter = zp_register_zombie_class(zclass_name, zclass_info, zclass_model, zclass_clawmodel, zclass_health, zclass_speed, zclass_gravity, zclass_knockback) 
	g_trailSprite = precache_model(g_trail)
	g_ring = precache_model(g_ringspr)
	bubble_model = precache_model(bubble_model_const)
	precache_model(spit_model)
	//precache_sound(Spitter_spitlaunch)
	precache_sound(Spitter_spithit)
	//precache_sound(Spitter_dieacid_start)
}

public zp_user_infected_post(id, infector)
{
	if ( zp_get_class(id) == ALIEN )
	{
		print_chatColor(id, "^x04[ZE]^x01 Para usar tu Habilidad Presiona:^x04 [R]") 
	}
}  

public CmdStart(id)
{		
	new button = pev(id, pev_button)
	new oldbutton = pev(id, pev_oldbuttons)
	
	if ( zp_get_class(id) == ALIEN && !zp_get_user_nemesis(id) )
	{
		if ((oldbutton & IN_RELOAD) && !(button & IN_RELOAD))
		{
			clcmd_spit(id)
		}
	}
	return FMRES_IGNORED
}

public clcmd_spit(id)
{
	if(!is_user_alive(id))
	{
		print_chatColor(id, "^x04[ZE]^x01 No Puedes Lanzar Acido Si Estas Muerto")
		return PLUGIN_HANDLED
	}
	
	if (zp_get_user_zombie(id))
	{
		if ( zp_get_class(id) == ALIEN && !zp_get_user_nemesis(id) )
		{	
			if (get_gametime() < g_LastSpitTime[id])
			{
				print_chatColor(id, "^x04[ZE]^x01 Debes esperar \t%.f \nsegundos. para volver a usar tu habilidad", (g_LastSpitTime[id]-get_gametime()))
				return PLUGIN_HANDLED;
			}
			
			Makespit(id)
			//emit_sound(id, CHAN_STREAM, Spitter_spitlaunch, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			g_LastSpitTime[id] = get_gametime() + get_pcvar_float(cvar_spit_cooldown);
			
			static origin1[3]
			get_user_origin(id, origin1)
			bubble_break(id, origin1)
			
		}
	}
	return FMRES_IGNORED
}

public spitTouch(spitEnt, Touched)
{
	if (!pev_valid(spitEnt) || !(1 <= Touched <= 32 && is_user_alive(Touched)) )
		return
		
	static Class[ 32 ]
	entity_get_string(Touched, EV_SZ_classname, Class, charsmax(Class) )
	new Float:origin[3]
		
	pev(Touched,pev_origin,origin)
	
	if(equal(Class, "player"))
	{
		if (is_user_alive(Touched))
		{
			if(!zp_get_user_zombie(Touched))
			{
				new SpitterKiller = entity_get_edict(spitEnt, EV_ENT_owner)
				
				switch(get_pcvar_num(cvar_spitmode))
				{
					case 1: // Health mode
					{
						new iHealth = get_user_health(Touched)

						if(iHealth >= 1 && iHealth <= get_pcvar_num(cvar_spit_damage))
						{
							emit_sound(Touched, CHAN_BODY, Spitter_spithit, 1.0, ATTN_NORM, 0, PITCH_NORM)
							ExecuteHamB(Ham_Killed, Touched, SpitterKiller, 0)
							
							static origin1[3]
							get_user_origin(Touched, origin1)
							bubble_break(Touched, origin1)
						}
						else
						{	
							emit_sound(Touched, CHAN_BODY, Spitter_spithit, 1.0, ATTN_NORM, 0, PITCH_NORM)
							set_user_health(Touched, get_user_health(Touched) - get_pcvar_num(cvar_spit_damage))
							
							static origin1[3]
							get_user_origin(Touched, origin1)
							bubble_break(Touched, origin1)
						}
					}
					case 2: // Kill mode
					{	
						emit_sound(Touched, CHAN_BODY, Spitter_spithit, 1.0, ATTN_NORM, 0, PITCH_NORM)
						ExecuteHamB(Ham_Killed, Touched, SpitterKiller, 0)
						
						static origin1[3]
						get_user_origin(Touched, origin1)
						bubble_break(Touched, origin1)
					}
					case 3: //infect mode
					{
						emit_sound(Touched, CHAN_BODY, Spitter_spithit, 1.0, ATTN_NORM, 0, PITCH_NORM)
						zp_infect_user(Touched, SpitterKiller, 1, 1)
						
						static origin1[3]
						get_user_origin(Touched, origin1)
						bubble_break(Touched, origin1)
					}
				}
			}
			else
			{
				emit_sound(Touched, CHAN_BODY, Spitter_spithit, 1.0, ATTN_NORM, 0, PITCH_NORM)
			
				static origin1[3]
				get_user_origin(Touched, origin1)
				bubble_break(Touched, origin1)
				
			}
		}
	}
	/* func_breakable entity support */
	if(equal(Class, "func_breakable") && entity_get_int(Touched, EV_INT_solid) != SOLID_NOT)
	{
		force_use(spitEnt, Touched)
	}
	
	remove_entity(spitEnt)
}

public bubble_break(id, origin1[3])
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY, origin1)
	write_byte(TE_BREAKMODEL) 
	write_coord(origin1[0])  
	write_coord(origin1[1])
	write_coord(origin1[2] + 24) 
	write_coord(16) 
	write_coord(16) 
	write_coord(16) 
	write_coord(random_num(-50,50)) 
	write_coord(random_num(-50,50)) 
	write_coord(25)
	write_byte(10) 
	write_short(bubble_model) 
	write_byte(10) 
	write_byte(38)
	write_byte(0x01) 
	message_end();
}

public Makespit(id)
{			
	new Float:Origin[3]
	new Float:Velocity[3]
	new Float:vAngle[3]

	new spitSpeed = get_pcvar_num(cvar_spit_speed)

	entity_get_vector(id, EV_VEC_origin , Origin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle)

	new NewEnt = create_entity("info_target")

	entity_set_string(NewEnt, EV_SZ_classname, "spit_ent")
	entity_set_model(NewEnt, spit_model)
	entity_set_size(NewEnt, Float:{-1.5, -1.5, -1.5}, Float:{1.5, 1.5, 1.5})
	entity_set_origin(NewEnt, Origin)
	entity_set_vector(NewEnt, EV_VEC_angles, vAngle)
	entity_set_int(NewEnt, EV_INT_solid, 2)
	entity_set_int(NewEnt, EV_INT_rendermode, 5)
	entity_set_float(NewEnt, EV_FL_renderamt, 200.0)
	entity_set_float(NewEnt, EV_FL_scale, 1.00)
	entity_set_int(NewEnt, EV_INT_movetype, 5)
	entity_set_edict(NewEnt, EV_ENT_owner, id)
	velocity_by_aim(id, spitSpeed  , Velocity)
	entity_set_vector(NewEnt, EV_VEC_velocity ,Velocity)
	
	spit_trail(id, NewEnt)
	return PLUGIN_HANDLED
}

public spit_trail(id, Entity)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) 
	write_short(Entity) 
	write_short(g_trailSprite) 
	write_byte(10) 
	write_byte(10) 
	write_byte(0) 
	write_byte(250) 
	write_byte(0) 
	write_byte(200) 
	message_end()
}

public spitter_death()
{
	new id = read_data(2)
	if (zp_get_user_zombie(id) && is_user_alive(id))
	{
		if ( zp_get_class(id) == ALIEN )
		{
			new Float:originF[3]
			pev(id, pev_origin, originF);
			spit_death(id, originF)
		}
	}
}

public spit_death(id, const Float:originF[3])
{
	if (zp_get_user_zombie(id) && is_user_alive(id))
	{
		if ( zp_get_class(id) == ALIEN )
		{
			spit_death_effect(id, originF)
			ring_effect(id)
		}
	}
	
	return PLUGIN_HANDLED
}

public ring_effect(id)
{
	new Float:origin[3]
	pev(id, pev_origin, origin)
	ring(origin)
}

public spit_death_effect(id, const Float:originF[3])
{
	for(new i = 1; i <= get_maxplayers(); i ++)
	{
		if (zp_get_user_zombie(i) || get_entity_distance(id, i) > get_pcvar_num(cvar_dthacid_distance))
		{
			return PLUGIN_HANDLED
		}
		new origin1[3]
		get_user_origin(id, origin1)
		bubble_break(id, origin1)
		
		//emit_sound(id, CHAN_BODY, Spitter_dieacid_start, 1.0, ATTN_NORM, 0, PITCH_NORM)
		print_chatColor(id, "^x04[ZE]^x01 \nHas Ganado \t2 Ammo Packs Por Una Victima")
		zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + 2)
		
		new Float:dam = get_pcvar_float(cvar_dthacid_damage);
		if(get_user_health(i) - get_pcvar_float(cvar_dthacid_damage) > 0)
		{
			emit_sound(i, CHAN_BODY, Spitter_spithit, 1.0, ATTN_NORM, 0, PITCH_NORM)
			print_chatColor(i, "^x04[ZE]^x01 \nHas Sido \tDaño Por El Acido De Una Spitter Muerta")
			fakedamage(i, "Spit acid", dam, 256);
			
			new origin1[3]
			get_user_origin(i, origin1)
			bubble_break(i, origin1)
		}
		if(get_user_health(i) - get_pcvar_float(cvar_dthacid_damage) == 0)
		{
			#if defined SPIT_CHEAT_BLOCK
				ExecuteHamB(Ham_Killed, i, id, 0)
			#else
				//ExecuteHamB(Ham_Killed, i, id, 0)
			#endif
			emit_sound(i, CHAN_BODY, Spitter_spithit, 1.0, ATTN_NORM, 0, PITCH_NORM)
			print_chatColor(i, "^x04[ZE]^x01 \nHas Sido \tAsesinado Por El Acido De Una Spitter Muerta")
			
			new origin1[3]
			get_user_origin(i, origin1)
			bubble_break(i, origin1)
		}
	}
	
	return PLUGIN_HANDLED
}

public ring(const Float:originF[3])
{
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+385.0) // z axis
	write_short(g_ring) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(200) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}

stock print_chatColor(id,const input[], any:...)
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3082\\ f0\\ fs16 \n\\ par }
*/
