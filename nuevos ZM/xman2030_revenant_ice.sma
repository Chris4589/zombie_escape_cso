#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>
#include <cstrike>
#include <xs>

#define SOUND								"xman2030/akshazombi_skill_exp.wav"

new const ball_name[] = "paralize_ball"
new const ball_model[] = "models/YouTuber/w_hiddentail2.mdl"
new const ball_soundtouch[] = { "xman2030/frostnova.wav" }

new const zclass_name[] = { "xman2030 Ice" } // name
new const zclass_info[] = { "Ice" } // description
new const zclass_model[] = { "b7_15471_rev_ice" } // model
new const zclass_clawmodel[] = { "v_b7_15471_rev_ice.mdl" } // claw model
const zclass_health = 8000 // health
const zclass_speed = 300 // speed
const Float:zclass_gravity = 0.7 // gravity
const Float:zclass_knockback = 1.0 // knockback

#define OFFSET_MODELINDEX 491
#define OFFSET_LINUX 5 

new index, defaultindex

new g_zclassparalize
new cvar_paralizedelay , cvar_paralizevelocity  , cvar_paralizeballhealth , cvar_paralizeballparalizetime
new sTrail , g_touchs[512] , g_can[33] , g_paralizen[33]

public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Paralize Zombie", "0.1", "=), LARS-BLOODLIKER")

	cvar_paralizedelay = register_cvar("zp_classparalize_delay","15")
	cvar_paralizevelocity = register_cvar("zp_classparalizeball_velocity","1300")
	cvar_paralizeballhealth = register_cvar("zp_classparalizeball_health","5")
	cvar_paralizeballparalizetime = register_cvar ( "zp_classparalizeball_paralizetime", "7.0" )

	register_touch(ball_name, "worldspawn",		"touchWorld")
	register_touch(ball_name, "func_wall",			"touchWorld")
	register_touch(ball_name, "func_door",			"touchWorld")
	register_touch(ball_name, "func_door_rotating", "touchWorld")
	register_touch(ball_name, "func_wall_toggle",	"touchWorld")
	register_touch(ball_name, "func_breakable",	"touchWorld")
	register_touch(ball_name, "player",			"touchPlayer")
	register_think(ball_name,"ball_think")

	register_clcmd("drop","paralize_cmd")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_forward(FM_PlayerPreThink, "fw_PreThink")

	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")

	RegisterHam(Ham_Player_Duck, "player", "Player_Duck", 1)
}

public plugin_precache()
{
	precache_sound(SOUND);
	precache_model(ball_model)
	sTrail = precache_model("sprites/laserbeam.spr")



	g_zclassparalize = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 
		0, 0, ADMIN_ALL, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback);
	index = precache_model("models/player/b7_15471_rev_ice/b7_15471_rev_ice.mdl")
    	defaultindex = precache_model("models/player.mdl")
	precache_sound("xman2030/frostnova.wav")
}

public paralize_cmd( id )
{
	if( !is_user_alive(id) || !zp_get_user_zombie(id) || zp_get_user_zombie_class(id) != g_zclassparalize || zp_get_user_nemesis(id) )
		return PLUGIN_HANDLED;

	if(g_can[id]) 
	{
		client_print(id,print_center,"Espera otros %d segundos",g_can[id])
		return PLUGIN_HANDLED;
	}

	UTIL_SendAudio(0, _, SOUND);

	static Float:origin[3], Float:angles[3], Float:v_forward[3], Float:v_right[3], Float:v_up[3], Float:gun_position[3], Float:player_origin[3], Float:player_view_offset[3];
	static Float:OriginX[3]
	pev(id, pev_v_angle, angles);
	pev(id, pev_origin, OriginX);
	engfunc(EngFunc_MakeVectors, angles);

	global_get(glb_v_forward, v_forward);
	global_get(glb_v_right, v_right);
	global_get(glb_v_up, v_up);

	//m_pPlayer->GetGunPosition( ) = pev->origin + pev->view_ofs
	pev(id, pev_origin, player_origin);
	pev(id, pev_view_ofs, player_view_offset);
	xs_vec_add(player_origin, player_view_offset, gun_position);

	xs_vec_mul_scalar(v_forward, 13.0, v_forward);
	xs_vec_mul_scalar(v_right, 0.0, v_right);
	xs_vec_mul_scalar(v_up, 5.0, v_up);

	xs_vec_add(gun_position, v_forward, origin);
	xs_vec_add(origin, v_right, origin);
	xs_vec_add(origin, v_up, origin);

	new Float:StartOrigin[3]
			
	StartOrigin[0] = origin[0];
	StartOrigin[1] = origin[1];
	StartOrigin[2] = origin[2];


	new Float:fVelocity[3] , Float:flOrigin[3] , Float:flAngle[3]
	pev(id,pev_origin,flOrigin)
	pev(id,pev_angles,flAngle)

	new ball = create_entity("info_target")
	
	if (!ball) return PLUGIN_HANDLED

	g_touchs[ball] = 0

	entity_set_string(ball, EV_SZ_classname, ball_name)
	
	entity_set_model(ball, ball_model)
	
	entity_set_origin(ball, StartOrigin)
	
	entity_set_vector(ball, EV_VEC_angles, flAngle)
	
	new Float:MinBox[3] = {-1.0, -1.0, -1.0}
	new Float:MaxBox[3] = {1.0, 1.0, 1.0}
	entity_set_vector(ball, EV_VEC_mins, MinBox)
	entity_set_vector(ball, EV_VEC_maxs, MaxBox)
	
	entity_set_int(ball, EV_INT_solid, SOLID_SLIDEBOX)
	
	entity_set_int(ball, EV_INT_movetype, MOVETYPE_BOUNCEMISSILE)
	
	entity_set_edict(ball, EV_ENT_owner, id)
	
	entity_set_int(ball, EV_INT_effects, EF_BRIGHTLIGHT)
	
	VelocityByAim(id, get_pcvar_num(cvar_paralizevelocity ), fVelocity)
	entity_set_vector(ball , EV_VEC_velocity, fVelocity)

	fm_set_rendering(ball, kRenderFxGlowShell,255, 255, 255, kRenderNormal, 16)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // Temporary entity ID
	write_short(ball) // Entity
	write_short(sTrail) // Sprite index
	write_byte(10) // Life
	write_byte(3) // Line width
	write_byte(100) // Red
	write_byte(255) // Green
	write_byte(255) // Blue
	write_byte(255) // Alpha
	message_end() 

	UTIL_PlayPlayerAnimation(id,10)
	UTIL_PlayWeaponAnimation(id,8)

	g_can[id] = get_pcvar_num(cvar_paralizedelay)
	set_task(1.0,"ability_zero",id)

	entity_set_float(ball, EV_FL_health , get_pcvar_float(cvar_paralizeballhealth))

	entity_set_float(ball, EV_FL_nextthink, get_gametime() + 0.1) 
	
	return PLUGIN_HANDLED;
}

public touchWorld(ball, world) {

	if (!ball || !is_valid_ent(ball) || is_user_alive(world) )
        return PLUGIN_HANDLED;

	emit_sound(ball, CHAN_WEAPON, ball_soundtouch, 1.0, ATTN_NORM, 0, PITCH_NORM)
	g_touchs[ball] += 1
	if(g_touchs[ball] == get_pcvar_num(cvar_paralizeballhealth)) remove_entity(ball)
	
	return PLUGIN_HANDLED
}

public touchPlayer(ball, player) {
	if (!ball || !is_valid_ent(ball) || is_user_alive(player) )
        return PLUGIN_HANDLED;

	client_print(0,print_chat,"touch %d",player)
	remove_task(player)
	paralize(player)
	//set_task(get_pcvar_float(cvar_paralizeballparalizetime),"unparalize_player",player)
	
	return PLUGIN_HANDLED
}

public event_round_start()
{
	new iEnt = FM_NULLENT;
	while( (iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", ball_name)) > 0 )
	{
		if(is_valid_ent(iEnt))
		engfunc(EngFunc_RemoveEntity,iEnt)
	}	

	for(new i;i<=32;i++)
	{
		if(g_paralizen[i]) fm_set_rendering(i)
		g_can[i] = 0
		g_paralizen[i] = 0
		remove_task(i)
	}
}

public ball_think(ball)
{
	if(!is_valid_ent(ball))
		return;

	new Float:oldangles[3],Float:angles[3]
	pev(ball,pev_angles,oldangles)
	angles[0] = oldangles[0] + random_float(20.0,100.0)
	angles[1] = oldangles[1] + random_float(10.0,80.0)
	angles[2] = oldangles[2] + random_float(10.0,80.0)
	set_pev(ball,pev_angles,angles)

	new Float:Velocity[3]
	pev(ball,pev_velocity,Velocity)

	if(Velocity[0] < 1.0 && Velocity[2] < 1.0 && Velocity[1] < 1.0) remove_entity(ball)

	entity_set_float(ball, EV_FL_nextthink, get_gametime() + 0.1) 

}

public paralize(id)
{
	if(!is_user_alive(id) || zp_get_user_zombie(id))
		return;

	g_paralizen[id] = 1
	fm_set_rendering(id, kRenderFxGlowShell,100, 255, 255, kRenderNormal, 16)
	set_task(get_pcvar_float(cvar_paralizeballparalizetime),"unparalize_player",id)
}

public unparalize_player(id)
{
	if(!is_user_alive(id) || zp_get_user_zombie(id))
		return;

	g_paralizen[id] = 0
	fm_set_rendering(id)
}

public remove_values(id)
{
	remove_task(id)
	g_can[id] = 0
}

public ability_zero(id) 
{
	g_can[id] -= 1
	if(!g_can[id]) client_print(id,print_center,"Habilidad lista. presione G")
	if(g_can[id]) set_task(1.0,"ability_zero",id)
}

public fw_PreThink(id)
{
	if( !is_user_alive(id) || zp_get_user_zombie(id) || !g_paralizen[id])
		return PLUGIN_CONTINUE;

	set_pev( id, pev_button, pev(id,pev_button) & ~IN_ATTACK );

	set_pev(id, pev_maxspeed, 0.0)		

	new Float:vel[3]
	set_pev(id,pev_velocity,vel)

	return PLUGIN_HANDLED
}

public zp_user_humanized_post(id)
{
	fm_set_user_model_index(id, defaultindex)

 	remove_values(id)
}
public fw_PlayerKilled(id, attacker, shouldgib) remove_values(id)
public client_connect(id)  remove_values(id)

public zp_user_infected_post(id) 
{
	if((zp_get_user_zombie_class(id) == g_zclassparalize) && (zp_get_user_zombie(id)))
	{
		fm_set_user_model_index(id, index)
	}
	remove_values(id)
}

public zp_user_infected_pre(id) 
{ 
    	if(!(get_user_flags(id) & ADMIN_LEVEL_G)) 
	{ 
        	if(zp_get_user_next_class(id) == g_zclassparalize) 
		{ 
            		zp_set_user_zombie_class(id, 0) 
			client_print(id, print_chat, "Esta clase es solo para Osiris")
        	}     
    	}	 
} 

stock fm_set_rendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16)
{
	static Float:color[3]
	color[0] = float(r)
	color[1] = float(g)
	color[2] = float(b)
	
	set_pev(entity, pev_renderfx, fx)
	set_pev(entity, pev_rendercolor, color)
	set_pev(entity, pev_rendermode, render)
	set_pev(entity, pev_renderamt, float(amount))
}

stock UTIL_PlayWeaponAnimation(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}

stock UTIL_PlayPlayerAnimation(const id, const Sequence , Float:frame = 1.0 , Float:framerate = 1.0)
{
	entity_set_int(id, EV_INT_sequence, Sequence)
	entity_set_int(id, EV_INT_gaitsequence, 1)
	entity_set_float(id, EV_FL_frame, frame)
	entity_set_float(id, EV_FL_framerate, framerate)
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
       
	return 1
} 

stock fm_cs_set_user_deaths(id, value)
{
	set_pdata_int(id, 444, value, 5)
}

stock fm_cs_get_user_team(id)
{
	return get_pdata_int(id, 114, 5);
}

public Player_Duck(id)
{
	if(!is_user_alive(id) || !zp_get_user_zombie(id))
		return;
		
	if(zp_get_user_zombie_class(id) == g_zclassparalize && zp_get_user_zombie(id))
	{
   		static button, ducking
   		button = pev(id, pev_button)
		ducking = pev(id, pev_flags) & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND)

   		if(button & IN_DUCK || ducking)
		{
			set_pev(id, pev_view_ofs, {0.0, 0.0, 20.0})   
   		}
	}
}

stock fm_set_user_model_index(id, value)
{
    set_pdata_int(id, OFFSET_MODELINDEX, value, OFFSET_LINUX)
} 

stock UTIL_SendAudio(iPlayer, iPitch = 100, const szPathSound[], any:...) { 
	
	new szBuffer[128]; 
	if(numargs() > 3) vformat(szBuffer, charsmax(szBuffer), szPathSound, 4); 
	else copy(szBuffer, charsmax(szBuffer), szPathSound); 
	switch(iPlayer) { 
		
		case 0: { 
			
			message_begin(MSG_BROADCAST, 100); 
			write_byte(iPlayer); 
			write_string(szBuffer); 
			write_short(iPitch); 
			message_end(); 
			
		} 
		
		default: { 
			
			engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, 100, {0.0, 0.0, 0.0}, iPlayer); 
			write_byte(iPlayer); 
			write_string(szBuffer); 
			write_short(iPitch); 
			message_end(); 
			
		} 
		
	} 
	
}

