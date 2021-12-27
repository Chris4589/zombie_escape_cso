#include <amxmodx>
#include <zombieplague>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <cstrike>
#include <xs>

// Task offsets
enum (+= 100) {
	TASK_BURN
}

// IDs inside tasks
#define ID_BURN (taskid - TASK_BURN)

#define is_user_valid_alive(%1) (1 <= %1 <= g_maxplayers && is_user_alive(%1))

new const zclass_name[] = { "Zombie Husk" } 
new const zclass_info[] = { "Throw a FireBall" } 
new const zclass_model[] = { "Husk" } 
new const zclass_clawmodel[] = { "v_husk_hands.mdl" }
const zclass_health = 1700
const zclass_speed = 200
const Float:zclass_gravity = 0.7 
const Float:zclass_knockback = 1.0 

new g_Husk
new g_trailSpr
new const fire_model[] = "sprites/3dmflared.spr"

// Cooldown hook
new Float:g_iLastFire[33]

new cvar_firespeed, cvar_firecooldown, cvar_firedamage, cvar_fireduration, cvar_fireslowdown, cvar_fireradius, cvar_firesurvivor
new g_smokeSpr, g_flameSpr, g_exploSpr
new g_burning_duration[33] // burning task duration
new g_maxplayers
new attacker
new g_bHusk[33], g_itemid;
public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Zombie Husk", "0.2", "DJHD!") 
	
	cvar_firespeed = register_cvar("zp_husk_fire_speed", "700")
	cvar_firecooldown = register_cvar("zp_husk_fire_cooldown", "30.0")
	cvar_firedamage = register_cvar("zp_husk_fire_damage", "2")
	cvar_fireduration = register_cvar("zp_husk_fire_duration", "5")
	cvar_fireslowdown = register_cvar("zp_husk_fire_slowdown", "0.5")
	cvar_fireradius = register_cvar("zp_husk_fire_radius", "220.0")
	cvar_firesurvivor = register_cvar("zp_husk_fire_survivor", "1")
	
	register_forward(FM_Touch, "fw_Touch")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	g_itemid = zp_register_extra_item("Anti Husk", 12, 150, ZP_TEAM_HUMAN);
	// HAM Forwards
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	register_event("HLTV", "event_RoundStart", "a", "1=0", "2=0")
	g_maxplayers = get_maxplayers()
} 

public plugin_precache()
{
	g_Husk = zp_register_class(CLASS_ZOMBIE, zclass_name, zclass_info, zclass_model, zclass_clawmodel, 
		15, 0, ADMIN_BAN, zclass_health, 0, zclass_speed, zclass_gravity, zclass_knockback)
	
	engfunc(EngFunc_PrecacheModel, fire_model)
	
	g_trailSpr = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
	g_smokeSpr = engfunc(EngFunc_PrecacheModel, "sprites/black_smoke3.spr")
	g_flameSpr = engfunc(EngFunc_PrecacheModel, "sprites/flame.spr")
	g_exploSpr = engfunc(EngFunc_PrecacheModel, "sprites/zerogxplode.spr")
	
	engfunc(EngFunc_PrecacheSound, "zombie_plague/husk_pre_fire.wav")
	engfunc(EngFunc_PrecacheSound, "zombie_plague/husk_wind_down.wav")
	engfunc(EngFunc_PrecacheSound, "zombie_plague/husk_fireball_fire.wav")
	engfunc(EngFunc_PrecacheSound, "zombie_plague/husk_fireball_loop.wav")
	engfunc(EngFunc_PrecacheSound, "zombie_plague/husk_fireball_explode.wav")
}
public zp_extra_item_selected(player, itemid)
{
    if ( itemid == g_itemid )
    {
        g_bHusk[player] = true;
    }
}
public event_RoundStart(){
	for(new i = 1; i <=g_maxplayers; ++i)
		g_bHusk[i] = false;
}
public zp_user_infected_post(id, infector)
{
	g_bHusk[id] = false;//7 n 10
	if (zp_get_user_zombie_class(id) == g_Husk && NINJA <= zp_get_class(id) <= LAST_ZOMBIE)
	{
		g_iLastFire[id] = 0.0
		
		print_chatColor(id, "\g[ZP]\n To launch a \gFireBall\n press \g^"R^"\n.") 
	}
}

public fw_PlayerPreThink(id)
{
	if(!is_user_alive(id))
		return;
	
	static iButton; iButton = pev(id, pev_button)
	static iOldButton; iOldButton = pev(id, pev_oldbuttons)
	
	if(zp_get_user_zombie(id) && (zp_get_user_zombie_class(id) == g_Husk) && zp_get_class(id) < NEMESIS)
	{
		if((iButton & IN_RELOAD) && !(iOldButton & IN_RELOAD))
		{			
			if(get_gametime() - g_iLastFire[id] < get_pcvar_float(cvar_firecooldown))
			{
				print_chatColor(id, "\g[ZP]\n Wait \g%.1f\n seconds, to re-launch another \gFireBall\n", get_pcvar_float(cvar_firecooldown)-(get_gametime() - g_iLastFire[id]))
				return;
			}
			
			g_iLastFire[id] = get_gametime()
			
			message_begin(MSG_ONE, get_user_msgid("BarTime"), _, id)
			write_byte(1)
			write_byte(0)
			message_end()
			
			emit_sound(id, CHAN_ITEM, "zombie_plague/husk_pre_fire.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			set_task(1.0, "MakeFire", id)
		}
		
		if(iOldButton & IN_RELOAD && !(iButton & IN_RELOAD))
		{
			if(task_exists(id))
			{
				print_chatColor(id, "\g[ZP]\n To throw a \gFireBall\n you hold down the \g^"R^"\n.")
				g_iLastFire[id] = 0.0
				emit_sound(id, CHAN_ITEM, "zombie_plague/husk_wind_down.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
			
			message_begin(MSG_ONE, get_user_msgid("BarTime"), _, id)
			write_byte(0)
			write_byte(0)
			message_end()
			
			remove_task(id)
		}
	}
}

// Ham Player Spawn Post Forward
public fw_PlayerSpawn_Post(id)
{
	// Not alive or didn't join a team yet
	if (!is_user_alive(id) || !cs_get_user_team(id))
		return;
	
	// Remove previous tasks
	remove_task(id+TASK_BURN)
}

// Ham Player Killed Forward
public fw_PlayerKilled(victim, attacker, shouldgib)
{	
	// Stop burning
	if (!zp_get_user_zombie(victim))
		remove_task(victim+TASK_BURN)
}

public client_disconnected(id)
	remove_task(id+TASK_BURN)

public MakeFire(id)
{
	new Float:Origin[3]
	new Float:vAngle[3]
	new Float:flVelocity[3]
	
	// Get position from eyes
	get_user_eye_position(id, Origin)
	
	// Get View Angles
	entity_get_vector(id, EV_VEC_v_angle, vAngle)
	
	new NewEnt = create_entity("info_target")
	
	entity_set_string(NewEnt, EV_SZ_classname, "fireball")
	
	entity_set_model(NewEnt, fire_model)
	
	entity_set_size(NewEnt, Float:{ -1.5, -1.5, -1.5 }, Float:{ 1.5, 1.5, 1.5 })
	
	entity_set_origin(NewEnt, Origin)
	
	// Set Entity Angles (thanks to Arkshine)
	make_vector(vAngle)
	entity_set_vector(NewEnt, EV_VEC_angles, vAngle)
	
	entity_set_int(NewEnt, EV_INT_solid, SOLID_BBOX)
	
	entity_set_float(NewEnt, EV_FL_scale, 0.3)
	entity_set_int(NewEnt, EV_INT_spawnflags, SF_SPRITE_STARTON)
	entity_set_float(NewEnt, EV_FL_framerate, 25.0)
	set_rendering(NewEnt, kRenderFxNone, 0, 0, 0, kRenderTransAdd, 255)
	
	entity_set_int(NewEnt, EV_INT_movetype, MOVETYPE_FLY)
	entity_set_edict(NewEnt, EV_ENT_owner, id)
	
	// Set Entity Velocity
	velocity_by_aim(id, get_pcvar_num(cvar_firespeed), flVelocity)
	entity_set_vector(NewEnt, EV_VEC_velocity, flVelocity)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // TE id
	write_short(NewEnt) // entity
	write_short(g_trailSpr) // sprite
	write_byte(5) // life
	write_byte(6) // width
	write_byte(255) // r
	write_byte(0) // g
	write_byte(0) // b
	write_byte(255) // brightness
	message_end()
	
	set_task(0.2, "effect_fire", NewEnt, _, _, "b") 
	
	emit_sound(id, CHAN_ITEM, "zombie_plague/husk_fireball_fire.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(NewEnt, CHAN_ITEM, "zombie_plague/husk_fireball_loop.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public effect_fire(entity)
{
	if (!pev_valid(entity))
	{
		remove_task(entity)
		return;
	}
	
	// Get origin
	static Float:originF[3]
	pev(entity, pev_origin, originF)
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(17)
	engfunc(EngFunc_WriteCoord, originF[0]) 		// x
	engfunc(EngFunc_WriteCoord, originF[1]) 		// y
	engfunc(EngFunc_WriteCoord, originF[2]+30) 		// z
	write_short(g_flameSpr)
	write_byte(5) 						// byte (scale in 0.1's) 188 - era 65
	write_byte(200) 					// byte (framerate)
	message_end()
	
	// Smoke
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(5)
	engfunc(EngFunc_WriteCoord, originF[0]) 	// x
	engfunc(EngFunc_WriteCoord, originF[1]) 	// y
	engfunc(EngFunc_WriteCoord, originF[2]) 	// z
	write_short(g_smokeSpr)				// short (sprite index)
	write_byte(13) 					// byte (scale in 0.1's)
	write_byte(15) 					// byte (framerate)
	message_end()	
	
	// Colored Aura
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_DLIGHT) 			// TE id
	engfunc(EngFunc_WriteCoord, originF[0])	// x
	engfunc(EngFunc_WriteCoord, originF[0])	// y
	engfunc(EngFunc_WriteCoord, originF[0])	// z
	write_byte(25) 				// radius
	write_byte(255) 			// r
	write_byte(128) 			// g
	write_byte(0) 				// b
	write_byte(2) 				// life
	write_byte(3) 				// decay rate
	message_end()
}

// Touch Forward
public fw_Touch(ent, id)
{
	if (!pev_valid(ent)) 
		return PLUGIN_HANDLED
	
	new class[32]
	pev(ent, pev_classname, class, charsmax(class))
	
	if(equal(class, "fireball"))
	{
		attacker = entity_get_edict(ent, EV_ENT_owner)
		husk_touch(ent)
		engfunc(EngFunc_RemoveEntity, ent)
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public husk_touch(ent)
{
	if (!pev_valid(ent)) 
		return;
	
	// Get origin
	static Float:originF[3]
	pev(ent, pev_origin, originF)
	
	// Explosion
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	write_short(g_exploSpr)
	write_byte(40) 		// byte (scale in 0.1's) 188 - era 65
	write_byte(25) 		// byte (framerate)
	write_byte(TE_EXPLFLAG_NOSOUND) // byte flags
	message_end()
	
	emit_sound(ent, CHAN_ITEM, "zombie_plague/husk_fireball_explode.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Collisions
	static victim
	victim = -1
	
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, originF, get_pcvar_float(cvar_fireradius))) != 0)
	{
		// Only effect alive zombies
		if (!is_user_valid_alive(victim) || zp_get_user_zombie(victim) || g_bHusk[victim] || !get_pcvar_num(cvar_firesurvivor) && zp_get_user_survivor(victim))
			continue;
		
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("Damage"), _, victim)
		write_byte(0) // damage save
		write_byte(0) // damage take
		write_long(DMG_BURN) // damage type
		write_coord(0) // x
		write_coord(0) // y
		write_coord(0) // z
		message_end()
		
		g_burning_duration[victim] += get_pcvar_num(cvar_fireduration) * 5
		
		// Set burning task on victim if not present
		if (!task_exists(victim+TASK_BURN))
			set_task(0.2, "burning_flame", victim+TASK_BURN, _, _, "b")
	}
}

// Burning Flames
public burning_flame(taskid)
{
	// Get player origin and flags
	static origin[3], flags
	get_user_origin(ID_BURN, origin)
	flags = pev(ID_BURN, pev_flags)
	
	// in water - burning stopped
	if (zp_get_user_zombie(ID_BURN) || (flags & FL_INWATER) || g_burning_duration[ID_BURN] < 1)
	{
		// Smoke sprite
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_SMOKE) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]-50) // z
		write_short(g_smokeSpr) // sprite
		write_byte(random_num(15, 20)) // scale
		write_byte(random_num(10, 20)) // framerate
		message_end()
		
		// Task not needed anymore
		remove_task(taskid);
		return;
	}
	
	if ((pev(ID_BURN, pev_flags) & FL_ONGROUND) && get_pcvar_float(cvar_fireslowdown) > 0.0)
	{
		static Float:velocity[3]
		pev(ID_BURN, pev_velocity, velocity)
		xs_vec_mul_scalar(velocity, get_pcvar_float(cvar_fireslowdown), velocity)
		set_pev(ID_BURN, pev_velocity, velocity)
	}
	
	// Get player's health
	static health
	health = pev(ID_BURN, pev_health)
	
	if (health > get_pcvar_float(cvar_firedamage))
		fm_set_user_health(ID_BURN, health - floatround(get_pcvar_float(cvar_firedamage)))
	else
		death_message(attacker, ID_BURN, "fireball", 1)
	
	// Flame sprite
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_SPRITE) // TE id
	write_coord(origin[0]+random_num(-5, 5)) // x
	write_coord(origin[1]+random_num(-5, 5)) // y
	write_coord(origin[2]+random_num(-10, 10)) // z
	write_short(g_flameSpr) // sprite
	write_byte(random_num(5, 10)) // scale
	write_byte(200) // brightness
	message_end()
	
	// Decrease burning duration counter
	g_burning_duration[ID_BURN]--
}


// Death message
public death_message(Killer, Victim, const Weapon [], ScoreBoard)
{
	// Block death msg
	set_msg_block(get_user_msgid("DeathMsg"), BLOCK_SET)
	ExecuteHamB(Ham_Killed, Victim, Killer, 0)
	set_msg_block(get_user_msgid("DeathMsg"), BLOCK_NOT)
	
	// Death
	make_deathmsg(Killer, Victim, 0, Weapon)
	
	// Update score board
	if (ScoreBoard)
	{
		message_begin(MSG_BROADCAST, get_user_msgid("ScoreInfo"))
		write_byte(Killer) // id
		write_short(pev(Killer, pev_frags)) // frags
		write_short(cs_get_user_deaths(Killer)) // deaths
		write_short(0) // class?
		write_short(get_user_team(Killer)) // team
		message_end()
		
		message_begin(MSG_BROADCAST, get_user_msgid("ScoreInfo"))
		write_byte(Victim) // id
		write_short(pev(Victim, pev_frags)) // frags
		write_short(cs_get_user_deaths(Victim)) // deaths
		write_short(0) // class?
		write_short(get_user_team(Victim)) // team
		message_end()
	}
}

/*================================================================================
[Stocks]
=================================================================================*/

// Color Chat
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

stock get_user_eye_position(id, Float:flOrigin[3])
{
	static Float:flViewOffs[3]
	entity_get_vector(id, EV_VEC_view_ofs, flViewOffs)
	entity_get_vector(id, EV_VEC_origin, flOrigin)
	xs_vec_add(flOrigin, flViewOffs, flOrigin)
}

stock make_vector(Float:flVec[3])
{
	flVec[0] -= 30.0
	engfunc(EngFunc_MakeVectors, flVec)
	flVec[0] = -(flVec[0] + 30.0)
}

// Set player's health (from fakemeta_util)
stock fm_set_user_health(id, health)
{
	(health > 0) ? set_pev(id, pev_health, float(health)) : dllfunc(DLLFunc_ClientKill, id);
}