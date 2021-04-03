#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>
#include <cstrike>
#include <fun>
#include <xs>

#define SOUND								"xman2030/akshazombi_skill_exp.wav"

new const ball_name[] = "dragon_ball"
new const ball_model[] = "models/xman2030/w_fire_ball.mdl"
new const ball_firespritemdl[] = "sprites/xman2030/ef_red_flame.spr"
new const ball_spriteexplodemdl[] = "sprites/YouTuber/zerogxplode-fire.spr"

new const zclass_name[] = { "Reva fire" } // name
new const zclass_info[] = { "Reva fire" } // description
new const zclass_model[] = { "b7_15471_rev_fire" } // model
new const zclass_clawmodel[] = { "v_b7_15471_rev_fire.mdl" } // claw model
const zclass_health = 6000 // health
const zclass_speed = 300 // speed
const Float:zclass_gravity = 0.8 // gravity
const Float:zclass_knockback = 0.10 // knockback
//new const v_zombie_bomb_model[64] = "revenant"

//new g_CurWeapon[33]//, g_bombmodelwpn[64]

#define OFFSET_MODELINDEX 491
#define OFFSET_LINUX 5 

new index, defaultindex

new sprFlame, sprSmoke

new g_zclassdragon
new cvar_dragondmg, cvar_dragondelay, cvar_dragonvelocity, cvar_dragonballhealth, cvar_dragonballradius, cvar_dragonballpower, cvar_burndmg, cvar_burntime, cvar_burn
new g_msgScreenShake, g_smoke, sTrail, ball_firesprite, ball_spriteexplode, g_explode[512], g_can[33], g_msgScoreInfo, g_roundend, bool:g_AlreadyBurn[33], Time[33]


public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Dragon Zombie", "0.1", "=), LARS-BLOODLIKER")

	cvar_dragondelay = register_cvar("zp_classdragon_delay","15")
	cvar_dragondmg = register_cvar("zp_classdragonball_dmg","70.0")
	cvar_dragonvelocity = register_cvar("zp_classdragonball_velocity","1200")
	cvar_dragonballhealth = register_cvar("zp_classdragonball_health","1.0")
	cvar_dragonballradius = register_cvar("zp_classdragonball_radius","300.0")
	cvar_dragonballpower = register_cvar ( "zp_classdragonball_power", "800" )
	cvar_burn = register_cvar ( "zp_classdragonball_enable", "1" )
	cvar_burntime = register_cvar ( "zp_classdragonball_burntime", "5" )
	cvar_burndmg = register_cvar ( "zp_classdragonball_burndmg", "20" )

	register_touch(ball_name, "worldspawn",		"touchWorld")
	register_touch(ball_name, "func_wall",			"touchWorld")
	register_touch(ball_name, "func_door",			"touchWorld")
	register_touch(ball_name, "func_door_rotating", "touchWorld")
	register_touch(ball_name, "func_wall_toggle",	"touchWorld")
	register_touch(ball_name, "func_breakable",	"touchWorld")
	register_think(ball_name,"ball_think")

	register_clcmd("drop","dragon_cmd")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")

	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")

	g_msgScoreInfo = get_user_msgid("ScoreInfo")
	g_msgScreenShake = get_user_msgid("ScreenShake")

	//register_event("CurWeapon", "Event_CurrentWeapon", "be", "1=1")
	
	//for(new i = 1; i < sizeof WeaponNames; i++)
	//if(WeaponNames[i][0]) RegisterHam(Ham_Item_Deploy, WeaponNames[i], "fw_Weapon_Deploy_Post", 1)

	RegisterHam(Ham_Player_Duck, "player", "Player_Duck", 1)
}

public plugin_precache()
{
	precache_sound(SOUND);
	precache_model(ball_model)
	g_smoke = precache_model("sprites/steam1.spr")
	sTrail = precache_model("sprites/laserbeam.spr")
	ball_firesprite = precache_model(ball_firespritemdl)
	ball_spriteexplode  = precache_model(ball_spriteexplodemdl)

	sprFlame = precache_model("sprites/xman2030/ef_red_flame.spr")
	sprSmoke = precache_model("sprites/YouTuber/black_smoke3.spr")

	g_zclassdragon = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 
		0, 0, ADMIN_ALL, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback);

	//formatex(g_bombmodelwpn, charsmax(g_bombmodelwpn), "models/zombie_plague/v_bomb_%s.mdl", v_zombie_bomb_model)
	//engfunc(EngFunc_PrecacheModel, g_bombmodelwpn)

	index = precache_model("models/player/b7_15471_rev_fire/b7_15471_rev_fire.mdl")
    	defaultindex = precache_model("models/player.mdl")
}

public dragon_cmd( id )
{
	if(!is_user_alive(id) || !zp_get_user_zombie(id) || zp_get_user_zombie_class(id) != g_zclassdragon || zp_get_user_nemesis(id))
		return PLUGIN_HANDLED

	if(g_can[id]) 
	{
		client_print(id,print_center,"Востановление через %d секунд",g_can[id])
		return PLUGIN_HANDLED
	}
	
	UTIL_SendAudio(0, _, SOUND);
	
	static Float:origin[3], Float:angles[3], Float:v_forward[3], Float:v_right[3], Float:v_up[3], Float:gun_position[3], Float:player_origin[3], Float:player_view_offset[3];
	static Float:OriginX[3]
	pev(id, pev_v_angle, angles)
	pev(id, pev_origin, OriginX)
	engfunc(EngFunc_MakeVectors, angles)

	global_get(glb_v_forward, v_forward)
	global_get(glb_v_right, v_right)
	global_get(glb_v_up, v_up)

	pev(id, pev_origin, player_origin)
	pev(id, pev_view_ofs, player_view_offset)
	xs_vec_add(player_origin, player_view_offset, gun_position)

	xs_vec_mul_scalar(v_forward, 13.0, v_forward)
	xs_vec_mul_scalar(v_right, 0.0, v_right)
	xs_vec_mul_scalar(v_up, 5.0, v_up)

	xs_vec_add(gun_position, v_forward, origin)
	xs_vec_add(origin, v_right, origin)
	xs_vec_add(origin, v_up, origin)

	new Float:StartOrigin[3]
			
	StartOrigin[0] = origin[0]
	StartOrigin[1] = origin[1]
	StartOrigin[2] = origin[2]

	new Float:fVelocity[3] , Float:flOrigin[3] , Float:flAngle[3]
	pev(id,pev_origin,flOrigin)
	pev(id,pev_angles,flAngle)

	new ball = create_entity("info_target")
	
	if(!ball) return PLUGIN_HANDLED

	g_explode[ball] = 0
	
	entity_set_string(ball, EV_SZ_classname, ball_name)
	
	entity_set_model(ball, ball_model)
	
	entity_set_origin(ball, StartOrigin)
	
	entity_set_vector(ball, EV_VEC_angles, flAngle)
	
	new Float:MinBox[3] = {-1.0, -1.0, -1.0}
	new Float:MaxBox[3] = {1.0, 1.0, 1.0}
	entity_set_vector(ball, EV_VEC_mins, MinBox)
	entity_set_vector(ball, EV_VEC_maxs, MaxBox)
	
	entity_set_int(ball, EV_INT_solid, SOLID_SLIDEBOX)
	
	entity_set_int(ball, EV_INT_movetype, MOVETYPE_TOSS)
	
	entity_set_edict(ball, EV_ENT_owner, id)
	
	entity_set_int(ball, EV_INT_effects, EF_BRIGHTLIGHT)
	
	VelocityByAim(id, get_pcvar_num(cvar_dragonvelocity), fVelocity)
	entity_set_vector(ball , EV_VEC_velocity, fVelocity)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // Temporary entity ID
	write_short(ball) // Entity
	write_short(sTrail) // Sprite index
	write_byte(10) // Life
	write_byte(3) // Line width
	write_byte(255) // Red
	write_byte(150) // Green
	write_byte(20) // Blue
	write_byte(255) // Alpha
	message_end() 

	entity_set_int(id, EV_INT_sequence, 10)
	//UTIL_PlayPlayerAnimation(id,10)
	UTIL_PlayWeaponAnimation(id,8)

	g_can[id] = get_pcvar_num(cvar_dragondelay)
	set_task(1.0,"ability_zero",id)

	entity_set_float(ball, EV_FL_health , get_pcvar_float(cvar_dragonballhealth))

	entity_set_float(ball, EV_FL_nextthink, get_gametime() + 0.1) 
	
	return PLUGIN_HANDLED
}

public touchWorld(ball, world) 
{
	if (!ball || !is_valid_ent(ball) || is_user_alive(world) )
        return PLUGIN_HANDLED;

	new Float:v[3]
	entity_get_vector(ball, EV_VEC_velocity, v)

	v[0] = (v[0] * 0.85)
	v[1] = (v[1] * 0.85)
	v[2] = (v[2] * 0.85)
	entity_set_vector(ball, EV_VEC_velocity, v)
	
	return PLUGIN_HANDLED
}

public event_round_start()
{
	new iEnt = FM_NULLENT
	while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", ball_name)) > 0)
	{
		if(is_valid_ent(ball))
			engfunc(EngFunc_RemoveEntity,iEnt)
	}	
	for(new i;i<=32;i++)
	{
		remove_task(i)
		g_can[i] = 0
		Time[i] = 0 
		g_AlreadyBurn[i] = false
	}
	g_roundend = 0
}

public ball_think(ball)
{
	if(!is_valid_ent(ball))
		return

	new Float:oldangles[3],Float:angles[3]
	pev(ball,pev_angles,oldangles)
	angles[0] = oldangles[0] + random_float(20.0,100.0)
	angles[1] = oldangles[1] + random_float(10.0,80.0)
	angles[2] = oldangles[2] + random_float(10.0,80.0)
	set_pev(ball,pev_angles,angles)

	new Float:v[3]
	entity_get_vector(ball, EV_VEC_velocity, v)

	if(v[2] < 40.0 && v[1] < 40.0 && v[0] < 40.0) 
	{
		if(!g_explode[ball])
		{
			set_task(0.5,"firesprite_ball",ball)
			g_explode[ball] = 1
		}

		entity_set_float(ball, EV_FL_health, entity_get_float(ball,EV_FL_health) - 0.2) 

		if(entity_get_float(ball,EV_FL_health) <= 0.0) 
		{
			ball_explode(ball)
			remove_entity(ball)
			g_explode[ball] = 0
			return;
		}
	}
	entity_set_float(ball, EV_FL_nextthink, get_gametime() + 0.1) 
}

public firesprite_ball(ball)
{
	if(!is_valid_ent(ball))
		return

	new Float:flOrigin[3]
	pev(ball,pev_origin,flOrigin)

	engfunc ( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0 )
	write_byte ( TE_SPRITE )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 0 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 1 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 2 ] + 45.0 )
	write_short ( ball_firesprite )
	write_byte ( 5 )
	write_byte ( 185 )
	message_end ( )

	message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
	write_byte( TE_SMOKE );
	engfunc ( EngFunc_WriteCoord, flOrigin [ 0 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 1 ] )
	engfunc ( EngFunc_WriteCoord, flOrigin [ 2 ] + 45.0 )
	write_short( g_smoke );
	write_byte( 10 );
	write_byte( 10 );
	message_end();

	if(entity_get_float(ball,EV_FL_health) >= 1.0) set_task(0.5,"firesprite_ball",ball)
}
public ball_explode ( Entity )
{
	if ( Entity < 0 )
		return
       
	static Float:flOrigin [ 3 ]
	pev ( Entity, pev_origin, flOrigin )
       
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION) // Temporary entity ID
	engfunc(EngFunc_WriteCoord, flOrigin[0]) // engfunc because float
	engfunc(EngFunc_WriteCoord, flOrigin[1])
	engfunc(EngFunc_WriteCoord, flOrigin[2])
	write_short(ball_spriteexplode) // Sprite index
	write_byte(50) // Scale
	write_byte(15) // Framerate
	write_byte(0) // Flags
	message_end()
	
     	new iOwner = entity_get_edict ( Entity, EV_ENT_owner )
       
      	for ( new i = 1; i <= 32 ; i++ )
	{
		if ( !is_user_alive  ( i ) || zp_get_user_zombie( i ))
			continue
          
		new Float:flVictimOrigin [ 3 ]
		pev ( i, pev_origin, flVictimOrigin )
           
		new Float:flDistance = get_distance_f ( flOrigin, flVictimOrigin )   
           
		if ( flDistance <= get_pcvar_float(cvar_dragonballradius) )
		{
			static Float:flSpeed
			flSpeed = get_pcvar_float ( cvar_dragonballpower )
               
			static Float:flNewSpeed
			flNewSpeed = flSpeed * ( 1.0 - ( flDistance / get_pcvar_float(cvar_dragonballradius) ) )
               
			static Float:flVelocity [ 3 ]
			get_speed_vector ( flOrigin, flVictimOrigin, flNewSpeed, flVelocity )
               
			set_pev ( i, pev_velocity,flVelocity )

			message_begin(MSG_ONE, g_msgScreenShake, {0,0,0}, i)
			write_short(1<<14) // Amount
			write_short(1<<14) // Duration
			write_short(1<<14) // Frequency
			message_end()

			radius_damage_ab( flVictimOrigin, flOrigin , i , iOwner)

			if(!g_AlreadyBurn[ i ] && get_pcvar_num(cvar_burn ) == 1 ) 
			{
				// Burn / ON
				g_AlreadyBurn[ i ] = true
		
				// Set burn time
				Time[ i ] = get_pcvar_num(cvar_burntime)
		
				// Burn victim
				Burn( i )
			}
		}
	}
}       

public radius_damage_ab(Float:originF[3] , Float:flOrigin[3] , iVictim , iAttacker)
{
	if(g_roundend || !is_user_connected(iAttacker) || !is_user_connected(iVictim))
		return;

	new Float:dist = get_distance_f(originF, flOrigin);
	new Float:dmg = get_pcvar_float(cvar_dragondmg) - ( get_pcvar_float(cvar_dragondmg) / get_pcvar_float(cvar_dragonballradius) ) * dist;

	if(pev(iVictim,pev_health) - dmg <= 0) 
	{
		new headshot
		if(dist < 20.0) headshot = 1
		if(dist >= 20.0) headshot = 0
		message_begin( MSG_ALL, get_user_msgid("DeathMsg"),{0,0,0},0)
		write_byte(iAttacker)
		write_byte(iVictim)
		write_byte(headshot)
		write_string("dragon")
		message_end()

		user_silentkill(iVictim)

		set_pev(iAttacker, pev_frags, float(pev(iAttacker, pev_frags) + 1))
		zp_set_user_ammo_packs(iAttacker, zp_get_user_ammo_packs(iAttacker) + 1)
		fm_cs_set_user_deaths(iVictim, cs_get_user_deaths(iVictim) + 1)

		message_begin(MSG_BROADCAST, g_msgScoreInfo)
		write_byte(iAttacker) // id
		write_short(pev(iAttacker, pev_frags)) // frags
		write_short(cs_get_user_deaths(iAttacker)) // deaths
		write_short(0) // class?
		write_short(fm_cs_get_user_team(iAttacker)) // team
		message_end()
		
		message_begin(MSG_BROADCAST, g_msgScoreInfo)
		write_byte(iVictim) // id
		write_short(pev(iVictim, pev_frags)) // frags
		write_short(cs_get_user_deaths(iVictim)) // deaths
		write_short(0) // class?
		write_short(fm_cs_get_user_team(iVictim)) // team
		message_end()

	}else{
		if(dmg > 0) set_pev(iVictim , pev_health , pev(iVictim,pev_health) - dmg)
		if(dmg <= 0) set_pev(iVictim , pev_health , pev(iVictim,pev_health) + dmg)
	}
}

public remove_values(id)
{
	remove_task(id)
	g_can[id] = 0
}

public ability_zero(id) 
{
	g_can[id] -= 1
	if(!g_can[id]) client_print(id,print_center,"Способность активна!")
	if(g_can[id]) set_task(1.0,"ability_zero",id)
}

public Burn( victim )
{
	if(!is_user_alive( victim ))
		return
	// Get user origin
	static Origin[ 3 ] ; get_user_origin( victim, Origin )
	
	// If burn time is over or victim are in water
	if( Time[ victim ] <= 0 || get_entity_flags( victim ) & FL_INWATER )
	{	
		// Show Smoke sprite	
		message_begin( MSG_PVS, SVC_TEMPENTITY, Origin )
		write_byte( TE_SMOKE ) // TE id
		write_coord( Origin[0] ) // x
		write_coord( Origin[1] ) // y
		write_coord( Origin[2]-50 ) // z
		write_short( sprSmoke ) // sprite
		write_byte( random_num(15, 20) ) // scale
		write_byte( random_num(10, 20) ) // framerate
		message_end( )
		
		// Delay to allow burn again
		set_task( float(get_pcvar_num(cvar_burntime)), "Stop", victim )
		
		// Exit
		return
	}
	else
	{		
		// Flame sprite	
		message_begin( MSG_PVS, SVC_TEMPENTITY, Origin )
		write_byte( TE_SPRITE ) // TE id
		write_coord( Origin[0]+random_num(-5, 5) ) // x
		write_coord( Origin[1]+random_num(-5, 5) ) // y
		write_coord( Origin[2]+random_num(-10, 10) ) // z
		write_short( sprFlame ) // sprite
		write_byte( random_num(5, 10) ) // scale
		write_byte( 200 ) // brightness
		message_end( )
			
		// Decrease Time
		Time[ victim ]--
		
		// Decrease life (random)
		if(get_user_health(victim) -  get_pcvar_num(cvar_burndmg) > 0) set_user_health( victim, get_user_health( victim ) -  get_pcvar_num(cvar_burndmg))
		
		// Stop fire if health <= min health.
		if( get_user_health( victim ) <=  get_pcvar_num(cvar_burndmg))
		{
			g_AlreadyBurn[ victim ] = false
			return
		}
		
		// Repeat
		set_task( 0.5, "Burn", victim )
	}
}

public Stop( victim )
	g_AlreadyBurn[ victim ] = false // Allow burn again

public zp_user_humanized_post(id) 
{
	fm_set_user_model_index(id, defaultindex)

	remove_values(id)
}
public fw_PlayerKilled(id, attacker, shouldgib) remove_values(id)
public client_connect(id)  remove_values(id)
public zp_round_ended() g_roundend = 1

public zp_user_infected_post(id)	
{
	//set_wpnmodel(id)
	if((zp_get_user_zombie_class(id) == g_zclassdragon) && (zp_get_user_zombie(id)))
	{
		fm_set_user_model_index(id, index)
	}
	Time[ id ] = 0 
	g_AlreadyBurn[ id ] = false
	remove_task(id)
}

public zp_user_infected_pre(id) 
{ 
    	if(!(get_user_flags(id) & ADMIN_LEVEL_H)) 
	{ 
        	if(zp_get_user_next_class(id) == g_zclassdragon) 
		{ 
            		zp_set_user_zombie_class(id, 0) 
	    		client_print(id, print_chat, "Данный класс только для VIP")
        	}     
    	}	 
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
       
	return 1;
} 

stock fm_cs_set_user_deaths(id, value)
{
	set_pdata_int(id, 444, value, 5)
}

stock fm_cs_get_user_team(id)
{
	return get_pdata_int(id, 114, 5);
}
/*
public Event_CurrentWeapon(id) g_CurWeapon[id] = read_data(2)

public fw_Weapon_Deploy_Post(weapon_ent)
{
	static id; id = get_pdata_cbase(weapon_ent, 41, 4)

	static weaponid ; weaponid = cs_get_weapon_id(weapon_ent)

	g_CurWeapon[id] = weaponid
	
	replace_weapon_models(id, weaponid)
}
*/
public Player_Duck(id)
{
	if(!is_user_alive(id))
		return;
		
	if (zp_get_user_zombie_class(id) == g_zclassdragon && zp_get_user_zombie(id))
	{
   		static button, ducking
   		button = pev(id, pev_button)
		ducking = pev(id, pev_flags) & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND)

   		if (button & IN_DUCK || ducking)
		{
			set_pev(id, pev_view_ofs, {0.0, 0.0, 20.0})   
   		}
	}
}
/*
set_wpnmodel(id)
{
	if (!is_user_alive(id)) return

	new wpn = get_user_weapon(id)

	if (wpn == CSW_HEGRENADE || wpn == CSW_FLASHBANG || wpn == CSW_SMOKEGRENADE)
	{
    		set_pev(id, pev_viewmodel2, g_bombmodelwpn)
	}
}

replace_weapon_models(id, weaponid)
{
	if (zp_get_user_zombie_class(id) == g_zclassdragon && zp_get_user_zombie(id))
	{
		switch(weaponid)
		{
			case CSW_HEGRENADE:
			{
				set_pev(id, pev_viewmodel2, g_bombmodelwpn)
			}
			case CSW_SMOKEGRENADE:
			{
				set_pev(id, pev_viewmodel2, g_bombmodelwpn)
			}
			case CSW_FLASHBANG:
			{
				set_pev(id, pev_viewmodel2, g_bombmodelwpn)
			}
		}
	}
}
*/
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